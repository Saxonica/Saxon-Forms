<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl"
    xmlns:xforms="http://www.w3.org/2002/xforms"
    xmlns:ixsl="http://saxonica.com/ns/interactiveXSLT"
    xmlns:js="http://saxonica.com/ns/globalJS"
    xmlns:map="http://www.w3.org/2005/xpath-functions/map"
    exclude-result-prefixes="xs xforms map"
    extension-element-prefixes="ixsl"
    version="3.0">
    <!-- ══════════════════════════════════════════════════════════════════════
         Web Component Binding Support
         
         Any non-XForms element that carries @xforms:ref (e.g. xf:ref in the
         source XForm) is treated as a bound web component control. Saxon-Forms
         renders it as-is, adds data-binding attributes, and manages its .value
         property for model synchronisation.
         
         Example usage in an XForm:
           <tinymce-editor xf:ref="o:p" height="300" toolbar="bold italic"/>
         ══════════════════════════════════════════════════════════════════════ -->
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Process a non-XForms element with @xforms:ref as a bound web component control.</xd:p>
            <xd:p>Resolves binding context identically to native XForms controls, then delegates
            to mode="get-html" for rendering.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template match="*[not(self::xforms:*)][exists(@xforms:ref)]" priority="10">
        <xsl:param name="model-key" as="xs:string" required="no" select="$global-default-model-id" tunnel="yes"/>
        <xsl:param name="nodeset" as="xs:string" required="no" select="''" tunnel="yes"/>
        <xsl:param name="position" as="xs:integer" required="no" select="0"/>
        <xsl:param name="context-position" as="xs:string" required="no" select="''"/>
        <xsl:param name="bindings-js" as="element(xforms:bind)*" required="no" select="()" tunnel="yes"/>
        <xsl:param name="default-namespace-context" as="element()" required="yes" tunnel="yes"/>
        <xsl:param name="default-instance-id" as="xs:string" required="no" select="$global-default-instance-id" tunnel="yes"/>
        
        <xsl:variable name="string-position" as="xs:string" select="if ($context-position != '') then $context-position else string($position)"/>
        <xsl:variable name="myid" as="xs:string" select="
            if (exists(@id)) 
            then concat(@id, '-', $string-position)
            else concat( generate-id(), '-', $string-position )"/>
        
        <!-- Resolve ref the same way get-properties does for xforms:* -->
        <xsl:variable name="this-ref" as="xs:string" select="normalize-space(string(@xforms:ref))"/>
        <xsl:variable name="context-default-instance-id" as="xs:string" select="$default-instance-id"/>
        <xsl:variable name="context-default-nodeset" as="xs:string" select="concat('instance(''', $context-default-instance-id, ''')')"/>
        
        <xsl:variable name="refi" as="xs:string" select="
            if ($this-ref != '')
            then xforms:resolveXPathStrings(
                (if ($nodeset ne '') then $nodeset else $context-default-nodeset),
                $this-ref)
            else (if ($nodeset ne '') then $nodeset else $context-default-nodeset)"/>
        
        <xsl:variable name="this-instance-id" as="xs:string" select="xforms:getInstanceId($refi)"/>
        
        <!-- Resolve binding if one matches -->
        <xsl:variable name="bindingi" as="element(xforms:bind)?" select="
            $bindings-js[@instance-context = $this-instance-id]
                [xforms:impose(@nodeset) = xforms:impose($refi)][1]"/>
        
        <!-- Register actions (for xf:incremental etc.) -->
        <xsl:variable name="actions" as="map(*)*">
            <xsl:apply-templates select="." mode="set-actions">
                <xsl:with-param name="model-key" select="$model-key" tunnel="yes"/>
                <xsl:with-param name="instance-key" select="$this-instance-id" tunnel="yes"/>
                <xsl:with-param name="nodeset" select="$refi" tunnel="yes"/>
                <xsl:with-param name="properties" select="map{
                    'nodeset': $refi,
                    'instance-context': $this-instance-id,
                    'model-id': $model-key
                }" tunnel="yes"/>
            </xsl:apply-templates>
        </xsl:variable>
        
        <xsl:if test="exists($actions)">
            <xsl:sequence select="js:addAction($myid, $actions)"/>
        </xsl:if>
        
        <!-- Render the web component with binding attributes -->
        <xsl:apply-templates select="." mode="get-html">
            <xsl:with-param name="id" as="xs:string" select="$myid" tunnel="yes"/>
            <xsl:with-param name="nodeset" as="xs:string" select="$refi" tunnel="yes"/>
            <xsl:with-param name="context-nodeset" as="xs:string" select="$refi" tunnel="yes"/>
            <xsl:with-param name="instance-context" as="xs:string" select="$this-instance-id" tunnel="yes"/>
            <xsl:with-param name="binding" as="element(xforms:bind)*" select="$bindingi" tunnel="yes"/>
            <xsl:with-param name="actions" as="map(*)*" select="$actions"/>
        </xsl:apply-templates>
        
    </xsl:template>
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Render a bound web component: output the element as-is with all its
            non-XForms attributes, and inject data-binding attributes for Saxon-Forms.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template match="*[not(self::xforms:*)][exists(@xforms:ref)]" mode="get-html" priority="10">
        <xsl:param name="id" as="xs:string" tunnel="yes"/>
        <xsl:param name="nodeset" as="xs:string" tunnel="yes"/>
        <xsl:param name="context-nodeset" as="xs:string" tunnel="yes"/>
        <xsl:param name="instance-context" as="xs:string" tunnel="yes"/>
        <xsl:param name="binding" as="element(xforms:bind)*" tunnel="yes"/>
        <xsl:param name="actions" as="map(*)*"/>
        
        <xsl:variable name="instanceField" as="node()?" select="xforms:evaluate-xpath-with-instance-id($nodeset,$instance-context,())[1]"/>
        
        <!-- Determine the event attribute for value-change notification.
             Default is "change"; override with @xforms:event on the element. -->
        <xsl:variable name="change-event" as="xs:string" select="
            if (exists(@xforms:event)) then string(@xforms:event) else 'change'"/>
        
        <xsl:copy>
            <!-- Copy all non-XForms attributes from the source element -->
            <xsl:copy-of select="@*[not(namespace-uri() = 'http://www.w3.org/2002/xforms')]"/>
            
            <!-- Inject Saxon-Forms binding attributes -->
            <xsl:attribute name="id" select="$id"/>
            <xsl:attribute name="data-ref" select="$nodeset"/>
            <xsl:attribute name="instance-context" select="$instance-context"/>
            <xsl:attribute name="data-xf-component" select="'true'"/>
            <xsl:attribute name="data-xf-change-event" select="$change-event"/>
            
            <xsl:if test="exists($binding) and exists($binding/@constraint)">
                <xsl:attribute name="data-constraint" select="$binding/@constraint"/>
            </xsl:if>
            <xsl:if test="exists($binding) and exists($binding/@relevant)">
                <xsl:attribute name="data-relevant" select="$binding/@relevant"/>
            </xsl:if>
            <xsl:if test="exists($binding) and exists($binding/@required)">
                <xsl:attribute name="data-required" select="$binding/@required"/>
            </xsl:if>
            
            <xsl:if test="exists($actions)">
                <xsl:attribute name="data-action" select="$id"/>
            </xsl:if>
            
            <!-- Set initial content as text content of the element (web components
                 typically read textContent for initial value) -->
            <xsl:if test="exists($instanceField)">
                <xsl:attribute name="value" select="string($instanceField)"/>
                <xsl:value-of select="$instanceField"/>
            </xsl:if>
        </xsl:copy>
        
        <!-- Register for refresh so xforms-refresh can update the value -->
        <xsl:call-template name="registerOutput">
            <xsl:with-param name="context-nodeset" as="xs:string" select="$context-nodeset" tunnel="yes"/>
        </xsl:call-template>
    </xsl:template>
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Read value from a bound web component via its .value property.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template match="*[@data-xf-component]" mode="get-field">
        <xsl:sequence select="ixsl:get(., 'value')"/>
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Set value on a bound web component via its .value property.</xd:p>
        </xd:desc>
        <xd:param name="value">Value to set</xd:param>
    </xd:doc>
    <xsl:template match="*[@data-xf-component]" mode="set-field">
        <xsl:param name="value" select="''" tunnel="yes"/>
        <ixsl:set-property name="value" select="$value" object="."/>
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Handle change event from a bound web component.
            This template fires when the web component dispatches a native 'change' event.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template match="*[@data-xf-component]" mode="ixsl:onchange">
        <xsl:call-template name="action-setvalue-form-control">
            <xsl:with-param name="form-control" select="."/>
        </xsl:call-template>
        <xsl:call-template name="outermost-action-handler"/>
    </xsl:template>
    
    <xsl:variable name="saxon-forms-web-components-javascript" as="xs:string">
        /* ── Web Component Binding Support ──
         * Observes DOM for elements with data-xf-component attribute and wires
         * their custom change-event to dispatch a native 'change' event so that
         * SaxonJS ixsl:onchange templates can pick it up.
         *
         * The attribute data-xf-change-event names the event to listen for
         * (default: "change"). For web components that don't fire native change
         * events (e.g. TinyMCE fires "Change" on the editor object), a small
         * bridge is needed in the host page—see below.
         */
        var xfComponentObserver = new MutationObserver(function(mutations) {
            mutations.forEach(function(m) {
                m.addedNodes.forEach(function(node) {
                    if (node.nodeType === 1) {
                        _initXfComponents(node);
                    }
                });
            });
        });
        
        var _initXfComponents = function(root) {
            var els = root.querySelectorAll ? root.querySelectorAll('[data-xf-component]') : [];
            els.forEach(function(el) { _wireXfComponent(el); });
            if (root.hasAttribute &amp;&amp; root.hasAttribute('data-xf-component')) {
                _wireXfComponent(root);
            }
        };
        
        var _xfComponentSeq = 0;
        var _wireXfComponent = function(el) {
            if (el._xfWired) return;
            el._xfWired = true;
            
            /* Deduplicate element IDs for web components inside repeats.
               Saxon-Forms may assign the same generate-id based ID to multiple
               repeat items when context-position is lost. TinyMCE and other
               web components need unique IDs to initialize properly.
               We suffix duplicates with a sequence number. */
            if (el.id) {
                var sameId = document.querySelectorAll('[id="' + el.id + '"]');
                if (sameId.length > 1) {
                    el.id = el.id + '--wc' + (++_xfComponentSeq);
                }
            }
            
            var evtName = el.getAttribute('data-xf-change-event') || 'change';
            
            /* If the web component itself dispatches native 'change', we are done—
               SaxonJS will catch it via ixsl:onchange. Otherwise we listen for the
               component's custom event and re-dispatch a native change. */
            if (evtName !== 'change') {
                el.addEventListener(evtName, function() {
                    el.dispatchEvent(new Event('change', {bubbles: true}));
                });
            }
        };
        
        /* Global bridge function for web components that use attribute-based
         * event callbacks (e.g. TinyMCE's on-Change="functionName").
         * The function finds the host custom element and dispatches native change.
         * Usage: &lt;tinymce-editor on-Change="xfComponentChanged" ...>
         */
        var xfComponentChanged = function(evt) {
            /* evt is the component's internal event (e.g. TinyMCE editor event).
             * We need to find the host element. For shadow-DOM based components,
             * traverse from evt.target.getContainer() → shadowRoot → host.
             * For simpler components, evt.target may be the host itself. */
            var host = null;
            if (evt &amp;&amp; evt.target &amp;&amp; evt.target.getContainer) {
                var container = evt.target.getContainer();
                if (container &amp;&amp; container.getRootNode &amp;&amp; container.getRootNode().host) {
                    host = container.getRootNode().host;
                }
            }
            if (!host) {
                /* Fallback: search for the closest xf-component ancestor */
                var editors = document.querySelectorAll('[data-xf-component]');
                for (var i = 0; i &lt; editors.length; i++) {
                    if (editors[i].contains &amp;&amp; editors[i]._editor === evt.target) {
                        host = editors[i]; break;
                    }
                }
            }
            if (host) {
                host.dispatchEvent(new Event('change', {bubbles: true}));
            }
        };
        
        /* Start observing once DOM is ready */
        if (typeof document !== 'undefined') {
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', function() {
                    _initXfComponents(document.body);
                    xfComponentObserver.observe(document.body, {childList: true, subtree: true});
                });
            } else {
                _initXfComponents(document.body);
                xfComponentObserver.observe(document.body, {childList: true, subtree: true});
            }
        }
    </xsl:variable>
</xsl:stylesheet>
