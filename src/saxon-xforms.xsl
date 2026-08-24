<!-- This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/. -->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl"
    xmlns:math="http://www.w3.org/2005/xpath-functions/math"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:xforms="http://www.w3.org/2002/xforms" 
    xmlns:xhtml="http://www.w3.org/1999/xhtml"
    xmlns:js="http://saxonica.com/ns/globalJS" 
    xmlns:ixsl="http://saxonica.com/ns/interactiveXSLT"
    xmlns:xsdh="http://saxonica.com/ns/xsd-helpers"
    xmlns:sfl="http://saxonica.com/ns/forms-local"
    xmlns:sfp="http://saxon.sf.net/ns/packages" 
    
    xmlns:in="http://www.w3.org/2002/xforms-instance"
    xmlns:fn="http://www.w3.org/2005/xpath-functions"
    xmlns:map="http://www.w3.org/2005/xpath-functions/map"
    xmlns:array="http://www.w3.org/2005/xpath-functions/array"
    xmlns:saxon="http://saxon.sf.net/"
    xmlns:ev="http://www.w3.org/2001/xml-events"
    xmlns:err="http://www.w3.org/2005/xqt-errors"
        
    exclude-result-prefixes="xs math xforms xsdh sfl sfp err"
    extension-element-prefixes="ixsl saxon" version="3.0">
    
    <!-- 
        
        General TO DO list:
    
    
    A proper test suite/demo
    
    Error detection and messaging
    
    Improve messaging around missing/invalid fields
    
    Handlers for more events
        
    Proper handling of @if, @while (I haven't used this before, so need to generate an example to develop against)
    
    Handle more xforms:submission options
    
    Is @targetref handled properly in HTTPsubmit?
    
    Apply improved performance to action-setvalue (i.e. remove use of form-check)
    
    Various other XForms elements and attributes still to be handled
    
    Improve performance (I think some of the simplifications may have slowed down performance, e.g. triggering xforms-rebuild after an insert or delete action rather than granular handling of the HTML)
    
    Improved xforms-value-changed handling, e.g. an <xforms:output> bound to a node and with @ev:event="value-changed" is not handled
    -   when instance value is changed (by setvalue or recalculate), update actions tagged with this event?

    -->
    
    <xsl:include href="xforms-function-library.xsl"/>
    <xsl:include href="xsd-helpers.xsl"/>
    <xsl:include href="xforms-javascript-library.xsl"/>
    <xsl:include href="web-components.xsl"/>
    <xsl:include href="xforms-xpath-functions.xsl"/>
    
    <xsl:output method="html" encoding="utf-8" omit-xml-declaration="no" indent="no"
        doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN"
        doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"/>
    
    
    <xd:doc scope="component">
        <xd:desc>Shallow copy by default, e.g. for passing through HTML elements within the XForm.</xd:desc>
    </xd:doc>
    <xsl:mode on-no-match="shallow-copy"/>
    <xsl:mode name="trim-cdata-sections" on-no-match="shallow-copy"/>
    
    <!-- use case where saxon-forms.xsl is imported means we can't yet use a package -->
    <!--<xsl:use-package name="http://saxon.sf.net/packages/logger.xsl" package-version="1.0">
        <xsl:override>
            <xsl:variable name="sfp:LOGLEVEL" select="$LOGLEVEL_INT" as="xs:integer"/>
        </xsl:override>
    </xsl:use-package>-->
    
    <xsl:param name="LOGLEVEL" as="xs:string" select="'40'" required="no"/>
    <xsl:variable name="LOGLEVEL_INT" as="xs:integer" select="if ($LOGLEVEL castable as xs:integer) then xs:integer($LOGLEVEL) else 100"/>
    <xsl:param name="sequence-template-trace" as="xs:string" select="'false'" required="no"/>
    <xsl:variable
        name="sequence-template-trace-enabled"
        as="xs:boolean"
        select="lower-case(normalize-space($sequence-template-trace)) = ('1','true','yes','on')"/>

    <xsl:param name="xforms-instance-id" select="'xforms-jinstance'" as="xs:string" required="no"/>
    <xsl:param name="xforms-cache-id" select="'xforms-cache'" as="xs:string" required="no"/>
    
    <!-- @id attribute of HTML div element into which the XForm is to be rendered on the page -->
    <xsl:param name="xform-html-id" as="xs:string" select="'xForm'" required="no"/>
    
    <xsl:param name="xforms-file-global" as="xs:string?"/>
    <!-- TEST-TRACE: base URI for resolving relative @src/@resource on xf:instance;
         falls back to base-uri($xforms-doc-global) when not supplied;
         helps tests/w3c/ch03.spec.ts "3.2.2.a", "3.3.2.c", "3.3.2.f", tests/w3c/appendix.spec.ts "h.2" -->
    <xsl:param name="source-base-uri" as="xs:string?" required="no" select="()"/>
    
    <xsl:param name="xforms-doc-global" as="document-node()?" required="no" select="if (exists($xforms-file-global) and fn:doc-available($xforms-file-global)) then fn:doc($xforms-file-global) else (if (exists(/) and namespace-uri(/*) = ('http://www.w3.org/2002/xforms','http://www.w3.org/1999/xhtml')) then (/) else ())"/>

    <xsl:variable static="yes" name="debugMode" select="false()"/>
    <xsl:variable static="yes" name="debugTiming" select="true()"/>
    <xsl:variable static="yes" name="global-default-model-id" select="'saxon-forms-default-model'" as="xs:string"/>
    <xsl:variable static="yes" name="global-default-instance-id" select="'saxon-forms-default-instance'" as="xs:string"/>
    <xsl:variable static="yes" name="global-default-submission-id" select="'saxon-forms-default-submission'" as="xs:string"/>
    
    <!-- https://www.w3.org/TR/xforms11/#action -->
    <xsl:variable static="yes" name="xforms-actions" select="(
        'setvalue', 
        'insert', 
        'delete',
        'setindex',
        'toggle',
        'setfocus',
        'dispatch',
        'rebuild',
        'recalculate',
        'revalidate',
        'refresh',
        'reset',
        'load',
        'send',
        'message'
        )" as="xs:string+"/>
    
    <!-- 
        https://www.w3.org/TR/xforms11/#controls 
        exclude 'submit' - its handler is different to the rest
    -->
    <xsl:variable static="yes" name="xforms-controls" as="xs:string+" select="(
        'input',
        'secret',
        'textarea',
        'output',
        'upload',
        'range',
        'trigger',
        'select',
        'select1'
        )"/>
    
    <xsl:variable name="models-global" as="element(xforms:model)*" select="//xforms:model"/>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Main initial template.</xd:p>
            <xd:p>Writes Javascript code into HTML page.</xd:p>
            <xd:p>Sets instances in Javascript variables and as a map.</xd:p>
            <xd:p>Registers bindings and submissions as maps.</xd:p>
        </xd:desc>
        <xd:param name="xforms-doc">Complete XForms document.</xd:param>
        <xd:param name="xforms-file">File path to XForms document.</xd:param>
        <xd:param name="instance-docs">All instances in the XForms document. (When completely refreshing the form from JS set parameters, bypassing the need to go back to an original XForm.)</xd:param>
        <xd:param name="xFormsId">The @id of an HTML div on the page into which the XForm will be rendered.</xd:param>
        <xd:param name="reset">Boolean indicating whether this template is being called in a xforms-reset event. If true, we don't call the xforms-ready event</xd:param>
    </xd:doc>
    <xsl:template name="xformsjs-main">
        <xsl:param name="xforms-doc" as="document-node()?" required="no" select="()"/>
        <xsl:param name="xforms-file" as="xs:string?" required="no"/>
        <xsl:param name="instance-docs" as="map(*)?" required="no"/>   
        <xsl:param name="xFormsId" select="$xform-html-id" as="xs:string" required="no"/>
        <xsl:param name="reset" as="xs:boolean" select="false()"/>
        
        <xsl:message use-when="$debugMode">[xformsjs-main] START</xsl:message>
        <xsl:if test="$sequence-template-trace-enabled">
            <xsl:message>[SEQTRACE] template=xformsjs-main phase=enter reset=<xsl:value-of select="$reset"/></xsl:message>
        </xsl:if>

        <!-- $xforms-doc-local helps to support XForms in an iframe -->
        <xsl:variable name="xforms-doc-local" as="document-node()" select="ixsl:page()"/>

        <xsl:apply-templates select="$xforms-doc-local/*:html/*:head" mode="set-js"/>
        <!-- TEST-TRACE: clear cached bindings/actions before each fresh render so repeated
             xforms-fiddle refreshes don't duplicate xf:bind registrations (XTTE0570 on 2nd refresh);
             helps tests/supplemental/xforms-fiddle.spec.ts "refreshing same bind-heavy source twice does not fail". -->
        <xsl:if test="not($reset)">
            <xsl:sequence select="js:reset()"/>
        </xsl:if>
        
       
        <!-- 
            Populate $xforms-doci (local to this template) 
            using explicit parameter values if present
            (since this template can be called from an importing stylesheet),
            then falling back to global parameters
        -->
        <xsl:variable name="xforms-doci" as="document-node()?">
            <xsl:choose>
                <xsl:when test="$reset">
                    <xsl:message use-when="$debugMode">[xformsjs-main] Using document stored in Javascript XFormsDoc variable</xsl:message>
                    <xsl:sequence select="js:getXFormsDoc()"/>
                </xsl:when>
                <xsl:when test="$xforms-doc">
                    <xsl:message use-when="$debugMode">[xformsjs-main] Using document supplied with $xforms-doc parameter</xsl:message>
                    <xsl:sequence select="$xforms-doc"/>
                </xsl:when>
                <xsl:when test="fn:doc-available($xforms-file)">
                    <xsl:message use-when="$debugMode">[xformsjs-main] Using document supplied with $xforms-file parameter</xsl:message>
                    <xsl:sequence select="fn:doc($xforms-file)"/>
                </xsl:when>
                <!-- if the "global" xforms doc is HTML we take this (iframe) HTML  -->
                <xsl:when test="exists($xforms-doc-global/xhtml:html)">
                    <xsl:message use-when="$debugMode">[xformsjs-main] Using $xforms-doc-global HTML document</xsl:message>
                    <xsl:sequence select="$xforms-doc-local"/>
                </xsl:when>
                <xsl:when test="$xforms-doc-global">
                    <xsl:message use-when="$debugMode">[xformsjs-main] Using $xforms-doc-global document with root <xsl:sequence select="name($xforms-doc-global/*)"/></xsl:message>
                    
                    <xsl:sequence select="$xforms-doc-global"/>
                </xsl:when>
                <xsl:when test="exists($xforms-file)">
                    <xsl:message terminate="yes">[xformsjs-main] Unable to locate XForm file at <xsl:sequence select="$xforms-file"/></xsl:message>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:message terminate="yes">[xformsjs-main] Unable to locate XForm!</xsl:message>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        
        <xsl:variable name="xform-doc-ns" as="document-node()" select="xforms:addNamespaceDeclarationsToDocument($xforms-doci)"/>  
        <xsl:variable name="xform" as="element()" select="$xform-doc-ns/*"/>  
        
        <!-- populate Javascript variables -->
        <xsl:sequence select="js:setXFormsDoc($xform-doc-ns)"/>
        <xsl:sequence select="js:setXForm($xform)"/>
        
        <xsl:variable name="models" as="element(xforms:model)*" select="$xform-doc-ns/(xforms:xform|xhtml:html/xhtml:head)/xforms:model"/>
        <xsl:variable name="first-model" as="element(xforms:model)?" select="$models[1]"/>
        <xsl:variable name="first-model-id" as="attribute()?" select="$first-model/@id"/>
        <!-- TEST-TRACE: allow empty first-instance when model has no instance child;
             helps tests/w3c/ch08.spec.ts "8.1.8.a" -->
        <xsl:variable name="first-instance" as="element(xforms:instance)?" select="$first-model/xforms:instance[1]"/>
        <xsl:variable name="first-instance-id" as="attribute()?" select="$first-instance/@id"/>
        <xsl:variable name="default-model-id" as="xs:string" select="if (exists($first-model-id)) then $first-model-id else $global-default-model-id"/>
        <xsl:variable name="default-instance-id" as="xs:string" select="if (exists($first-instance-id)) then $first-instance-id else $global-default-instance-id"/>
        
        
        
        <!-- TEST-TRACE: downgrade multi-model-no-ID from terminate to warning;
             W3C tests like 4.2.1.a have multiple anonymous models;
             helps tests/w3c/ch04.spec.ts "4.2.1.a" -->
        <xsl:if test="count($models[not(@id)]) gt 1">
            <xsl:message>[xformsjs-main] WARNING: Multiple models with no ID. Only the first unnamed model is addressable by default.</xsl:message>
        </xsl:if>
        <xsl:for-each select="$models">
            <xsl:message use-when="$debugMode">[xformsjs-main] Construct model ...</xsl:message>
            <!-- bindings are set here -->
            <xsl:call-template name="xforms-model-construct">
                <xsl:with-param name="model" select="." tunnel="yes"/>
                <xsl:with-param name="all-models" select="$models" tunnel="yes"/>
                <xsl:with-param name="default-model-id" select="$default-model-id" tunnel="yes"/>
                <xsl:with-param name="default-instance-id" select="$default-instance-id" tunnel="yes"/>
                <xsl:with-param name="default-namespace-context" select="$xform-doc-ns/*" tunnel="yes"/>
            </xsl:call-template>   
            
            <!-- register actions for model (before dispatching xforms-model-construct event) -->
            <xsl:apply-templates select=".">
                <xsl:with-param name="bindings-js" select="js:getBindings()" as="element(xforms:bind)*" tunnel="yes"/>
                <xsl:with-param name="model-key" select="(@id,$default-model-id)[1]" tunnel="yes"/>
                <xsl:with-param name="default-instance-id" select="$default-instance-id" tunnel="yes"/>
                <xsl:with-param name="default-namespace-context" select="$xform-doc-ns/*" tunnel="yes"/>
            </xsl:apply-templates>
            
            <xsl:call-template name="xforms-event-handler">
                <xsl:with-param name="event-name" select="'xforms-model-construct'" as="xs:string" tunnel="yes"/>
            </xsl:call-template>
        </xsl:for-each> 
        
        <xsl:call-template name="xforms-event-handler">
            <xsl:with-param name="event-name" select="'xforms-model-construct-done'" as="xs:string" tunnel="yes"/>
        </xsl:call-template>        
        
         <!-- clear deferred update flags only if we're building from scratch -->
        <xsl:if test="empty($instance-docs)">
            <xsl:sequence select="js:clearDeferredUpdateFlags()" />    
            <xsl:sequence select="js:clearDirtyInstances()"/>
            <xsl:sequence select="js:clearPendingMutations()"/>
        </xsl:if>
        
        <!-- register submissions in a map -->
        <xsl:variable name="submissions" as="map(xs:string, map(*))">
            <xsl:map>
                <xsl:for-each select="$models/xforms:submission">
                    <xsl:variable name="map-key" as="xs:string" select="
                        if (@id) then xs:string(@id)
                        else if (@ref) then xs:string(@ref) 
                        else $global-default-submission-id
                        "/>
                    <xsl:variable name="map-value" as="map(*)">
                        <xsl:call-template name="setSubmission">
                            <xsl:with-param name="this" select="."/>
                            <xsl:with-param name="submission-id" select="$map-key"/>
                            <xsl:with-param name="default-instance-id" select="$default-instance-id" tunnel="yes"/>
                            <xsl:with-param name="default-namespace-context" select="$xform-doc-ns/*" tunnel="yes"/>
                        </xsl:call-template>
                    </xsl:variable>
                    <xsl:map-entry key="$map-key" select="$map-value"/>
                </xsl:for-each>
            </xsl:map>
        </xsl:variable>
        
        
        <!-- add each submission to the Javascript variable -->
        <xsl:variable name="submissionKeys" select="map:keys($submissions)" as="xs:string*"/>
        
        <xsl:for-each select="$submissionKeys">
            <xsl:variable name="submission" select="map:get($submissions, .)" as="map(*)" />  
            <xsl:sequence select="js:addSubmission(.,$submission)"/>
        </xsl:for-each>
        

        <xsl:variable name="log-label" as="xs:string" select="'XForms Main Build'"/>
        <xsl:variable name="time-id" select="concat($log-label, ' ', generate-id())"/>
        <xsl:sequence use-when="$debugTiming" select="js:startTime($time-id)" />
                
        <xsl:choose>
            <xsl:when test="exists($xform-doc-ns/xhtml:html)">
                <xsl:message use-when="$debugMode">[xformsjs-main] Replacing HTML body</xsl:message>
                <xsl:apply-templates select="ixsl:page()/xhtml:html/xhtml:body">
                    <xsl:with-param name="bindings-js" select="js:getBindings()" as="element(xforms:bind)*" tunnel="yes"/>
                    <xsl:with-param name="submissions" select="$submissions" as="map(xs:string, map(*))" tunnel="yes"/>
                    <xsl:with-param name="model-key" select="$default-model-id" tunnel="yes"/>
                    <xsl:with-param name="default-instance-id" select="$default-instance-id" tunnel="yes"/>
                    <xsl:with-param name="default-namespace-context" select="$xform-doc-ns/*" tunnel="yes"/>
                </xsl:apply-templates>
            </xsl:when>
            <xsl:otherwise>
                <!-- 
                    Write HTML to placeholder <div id="xForm"> 
                    
                    For XForms embedded in HTML:
                    "If the href supplied does not match an existing element in the HTML page, the xsl:result-document instruction is ignored and the transform will continue to completion."
                    https://www.saxonica.com/saxon-js/documentation2/index.html#!browser/result-documents
                -->
                <xsl:result-document href="#{$xFormsId}" method="ixsl:replace-content">
                    <xsl:apply-templates select="$xform-doc-ns/xforms:xform">
                    <!--<xsl:apply-templates select="$xform-doc-ns/xforms:xform, $xform-doc-ns/xhtml:html/xhtml:head/xforms:model, $xform-doc-ns/xhtml:html/xhtml:body/*">-->
                        <xsl:with-param name="bindings-js" select="js:getBindings()" as="element(xforms:bind)*" tunnel="yes"/>
                        <xsl:with-param name="submissions" select="$submissions" as="map(xs:string, map(*))" tunnel="yes"/>
                        <xsl:with-param name="model-key" select="$default-model-id" tunnel="yes"/>
                        <xsl:with-param name="default-instance-id" select="$default-instance-id" tunnel="yes"/>
                        <xsl:with-param name="default-namespace-context" select="$xform-doc-ns/*" tunnel="yes"/>
                    </xsl:apply-templates>
                </xsl:result-document>
            </xsl:otherwise>
        </xsl:choose>
        
        
        <xsl:sequence use-when="$debugTiming" select="js:endTime($time-id)" />
        
        <!-- 
            MJD 2025-10-17 need to pass bindings at least
        -->
        <xsl:if test="not($reset)">
            <xsl:call-template name="xforms-event-handler">
                <xsl:with-param name="event-name" select="'xforms-ready'" as="xs:string" tunnel="yes"/>
                <xsl:with-param name="bindings-js" select="js:getBindings()" as="element(xforms:bind)*" tunnel="yes"/>
                <xsl:with-param name="submissions" select="$submissions" as="map(xs:string, map(*))" tunnel="yes"/>
                <xsl:with-param name="model-key" select="$default-model-id" tunnel="yes"/>
                <xsl:with-param name="default-instance-id" select="$default-instance-id" tunnel="yes"/>
                <xsl:with-param name="default-namespace-context" select="$xform-doc-ns/*" tunnel="yes"/>
            </xsl:call-template>
        </xsl:if>
        
    </xsl:template>
    
    <xsl:template match="*:select[not(xforms:hasClass(.,'incremental'))]" mode="ixsl:onblur">
        <xsl:message use-when="$debugMode">[ixsl:onblur mode] non-incremental HTML form control '<xsl:sequence select="name()"/>' lost focus</xsl:message>
        <xsl:call-template name="outermost-action-handler"/>
    </xsl:template>
    
    <xsl:template match="*:select[not(xforms:hasClass(.,'incremental'))]" mode="ixsl:onfocusout">
        <xsl:message use-when="$debugMode">[ixsl:onfocusout mode] non-incremental HTML form control '<xsl:sequence select="name()"/>' lost focus</xsl:message>
        <xsl:call-template name="outermost-action-handler"/>
    </xsl:template>
    
    <xsl:template match="*:select[not(xforms:hasClass(.,'incremental'))]" mode="ixsl:onfocus">
        <xsl:message use-when="$debugMode">[ixsl:onfocus mode] non-incremental HTML form control '<xsl:sequence select="name()"/>' focused</xsl:message>
        <xsl:call-template name="outermost-action-handler"/>
    </xsl:template>


    <xd:doc scope="component">
        <xd:desc>Add Javascript to HTML head element</xd:desc>
    </xd:doc>
    <xsl:template match="*:head" mode="set-js">
        <!-- 
            for ixsl:page() 
            see http://www.saxonica.com/saxon-js/documentation/index.html#!ixsl-extension/functions/page
                    
            "the document node of the HTML DOM document"
            
            for href="?." 
            see http://www.saxonica.com/saxon-js/documentation/index.html#!development/result-documents
                        
            "the current context item as the target for inserting a generated fragment of HTML"
        -->
        
        <xsl:if test="not(ixsl:page()//script/@id = $xforms-cache-id)">
            <xsl:result-document href="?.">
                <script type="text/javascript" id="{$xforms-cache-id}">
                    <xsl:sequence select="$saxon-forms-javascript"/>
                    <!-- 
                        error "Cross origin requests are only supported for HTTP." when trying to load .js file
                    -->
                    <!--<xsl:sequence select="unparsed-text('xforms-javascript-library.js')"/>-->
                </script>
            </xsl:result-document>   
        </xsl:if>
        
     </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>Replace content of HTML body element, when XForm is embedded within XHTML.</xd:desc>
        <xd:param name="default-namespace-context">The HTML element that contains the XForm.</xd:param>
    </xd:doc>
    <xsl:template match="*:body">
        <xsl:param name="default-namespace-context" as="element()" tunnel="yes"/>
        <xsl:result-document href="?." method="ixsl:replace-content">
            <xsl:comment>Replacing HTML body with processed XForm</xsl:comment>
            <xsl:apply-templates select="$default-namespace-context/xhtml:head/xhtml:model, $default-namespace-context/xhtml:body/*"/>
        </xsl:result-document>   
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>If an attribute value is wrapper for evaluation in {}, register it as an output.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template match="@*[starts-with(normalize-space(.),'{')]">
        <xsl:variable name="myid" as="xs:string" select="if (exists(../@id)) then ../@id else generate-id()"/>
        <xsl:variable name="nodeset" as="xs:string" select="
            substring-before(
                substring-after(
                    normalize-space(.), '{'
                ), '}'    
            )"/>
        
        <xsl:call-template name="registerOutput">
            <xsl:with-param name="id" select="$myid" tunnel="yes"/>
            <xsl:with-param name="nodeset" select="$nodeset" tunnel="yes"/>
        </xsl:call-template>
    </xsl:template>
    
    
    
    <xd:doc scope="component">
        <xd:desc>Handle incremental change to HTML input</xd:desc>
    </xd:doc>
    <xsl:template match="*:input[xforms:hasClass(.,'incremental')][not(@type=('range','date','time'))]" mode="ixsl:onkeyup">
        <!-- TEST-TRACE: exclude native date/time controls from keyup-driven incremental updates;
             helps tests/examples/booking-form-blur.spec.ts "date/time controls do not blur while editing internal segments". -->
        <xsl:call-template name="action-setvalue-form-control">
            <xsl:with-param name="form-control" select="."/>
        </xsl:call-template>
        <xsl:call-template name="outermost-action-handler"/>
    </xsl:template>

    <xd:doc scope="component">
        <xd:desc>Handle incremental change to HTML5 range input rendered from xf:range.</xd:desc>
    </xd:doc>
    <xsl:template match="*:input[@type='range'][xforms:hasClass(.,'incremental')]" mode="ixsl:oninput">
        <!-- TEST-TRACE: drive xf:range incremental updates via native input event;
             helps tests/w3c/ch08.spec.ts "8.1.7.d", "8.1.7.e" -->
        <xsl:call-template name="action-setvalue-form-control">
            <xsl:with-param name="form-control" select="."/>
        </xsl:call-template>
        <xsl:call-template name="outermost-action-handler"/>
    </xsl:template>


    <xd:doc scope="component">
        <xd:desc>Handle file selection on an xf:upload-rendered file input.
            Reads the file as XML, parses it, and replaces the bound instance.</xd:desc>
    </xd:doc>
    <xsl:template match="*:input[@type='file'][exists(@data-ref)]" mode="ixsl:onchange">
        <xsl:variable name="instance-id" as="xs:string" select="xforms:getInstanceId(string(@data-ref))"/>
        <xsl:variable name="file-input" select="." as="element()"/>
        <xsl:variable name="files" select="ixsl:get($file-input, 'files')"/>
        <xsl:variable name="file" select="ixsl:call($files, 'item', [0])"/>
        
        <xsl:if test="exists($file)">
            <xsl:message use-when="$debugMode">[xf:upload onchange] File selected for instance '<xsl:value-of select="$instance-id"/>'</xsl:message>
            <!-- Call JS helper: reads file async, sets instance, then clicks hidden refresh trigger -->
            <xsl:sequence select="ixsl:call(ixsl:window(), 'readFileAsXML', [$file, $instance-id])"/>
        </xsl:if>
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>Handle change to HTML form control value (except when control has "incremental" set)</xd:desc>
    </xd:doc>
    <xsl:template match="*:select[xforms:hasClass(.,'incremental')]" mode="ixsl:onchange">
        <xsl:message use-when="$debugMode">[ixsl:onchange mode] incremental HTML form control '<xsl:sequence select="name()"/>' value changed</xsl:message>
        <xsl:call-template name="action-setvalue-form-control">
            <xsl:with-param name="form-control" select="."/>
        </xsl:call-template>
        <xsl:call-template name="outermost-action-handler"/>
    </xsl:template>
    
    <xsl:template match="*:select[not(xforms:hasClass(.,'incremental'))]" mode="ixsl:oninput">
        <xsl:message use-when="$debugMode">[ixsl:oninput mode] non-incremental HTML form control '<xsl:sequence select="name()"/>' value changed</xsl:message>
        <xsl:call-template name="action-setvalue-form-control">
            <xsl:with-param name="form-control" select="."/>
        </xsl:call-template>
        <!-- Keep select/deselect event tracker UI in sync without triggering
             the deferred update cycle (recalculate/revalidate/refresh) until blur. -->
        <xsl:call-template name="refreshRepeats-JS"/>
        <!-- Apply relevance visibility updates immediately for controls whose
             @relevant depends on the select/select1 value (e.g. Chapt02/2.3.a). -->
        <xsl:call-template name="refreshRelevantFields-JS"/>
        <!-- Keep bound outputs in sync for non-incremental select/select1 controls
             when user agents dispatch input before change. -->
        <xsl:call-template name="refreshOutputs-JS"/>
    </xsl:template>
    
    <xsl:template match="*:select[not(xforms:hasClass(.,'incremental'))]" mode="ixsl:onchange">
        <xsl:message use-when="$debugMode">[ixsl:onchange mode] non-incremental HTML form control '<xsl:sequence select="name()"/>' value changed (deferred cycle on blur)</xsl:message>
        <xsl:call-template name="action-setvalue-form-control">
            <xsl:with-param name="form-control" select="."/>
        </xsl:call-template>
        <!-- Keep select/deselect event tracker UI in sync without triggering
             the deferred update cycle (recalculate/revalidate/refresh) until blur. -->
        <xsl:call-template name="refreshRepeats-JS"/>
        <!-- Apply relevance visibility updates immediately for controls whose
             @relevant depends on the select/select1 value (e.g. Chapt02/2.3.a). -->
        <xsl:call-template name="refreshRelevantFields-JS"/>
        <!-- TEST-TRACE: keep bound outputs in sync on select/select1 change even when
             non-incremental deferred cycle waits for blur; helps tests/w3c/ch08.spec.ts "8.3.3.b". -->
        <xsl:call-template name="refreshOutputs-JS"/>
        <!-- Do not run deferred update cycle here; for non-incremental controls this
             must happen on focus change / blur (4.6.3.b/c sequencing). -->
    </xsl:template>
    
    <xsl:template match="*:input[not(xforms:hasClass(.,'incremental'))][not(@type=('file','date','time'))] | *:textarea" mode="ixsl:onchange">
        <!-- TEST-TRACE: keep native date/time off generic onchange input path so transient segment edits
             do not overwrite bound values before explicit field exit; helps tests/examples/booking-form-blur.spec.ts booking form date/time regression. -->
        <xsl:message use-when="$debugMode">[ixsl:onchange mode] HTML form control '<xsl:sequence select="name()"/>' value changed</xsl:message>
        <xsl:call-template name="action-setvalue-form-control">
            <xsl:with-param name="form-control" select="."/>
        </xsl:call-template>
        <xsl:call-template name="outermost-action-handler"/>
    </xsl:template>
    <xsl:template match="*:input[xforms:hasClass(.,'incremental')][@type=('date','time')][exists(@data-ref)]" mode="ixsl:onchange">
        <!-- TEST-TRACE: commit incremental date/time values on native change event (field-level commit),
             avoiding blur-time writes during internal segment navigation in native editors;
             helps tests/examples/booking-form-blur.spec.ts "date/time controls do not blur while editing internal segments". -->
        <xsl:call-template name="action-setvalue-form-control">
            <xsl:with-param name="form-control" select="."/>
            <!-- keep focused native commits enabled so valid date/time changes persist before submit;
                 action-setvalue-form-control still blocks implausible partial date segment values. -->
            <xsl:with-param name="allow-focused-native-date-time" select="true()"/>
        </xsl:call-template>
        <!-- TEST-TRACE: avoid running full outermost deferred cycle on native date/time onchange,
             which can recreate controls and drop focus while editing internal segments. -->
    </xsl:template>
    
    <xsl:template match="*:input[exists(@data-ref)][not(@type='file')] | *:select[exists(@data-ref)] | *:textarea[exists(@data-ref)]" mode="ixsl:onblur">
        <xsl:sequence select="js:markControlVisited(normalize-space(string(@instance-context)), normalize-space(string(@data-ref)))"/>
        <!-- TEST-TRACE: commit blurred control values before refresh so invalid/valid projection uses current instance data; helps tests/supplemental/demo-schema-validation.spec.ts "orderId pattern facet marks invalid then valid". -->
        <xsl:call-template name="action-setvalue-form-control">
            <xsl:with-param name="form-control" select="."/>
        </xsl:call-template>
        <xsl:call-template name="outermost-action-handler"/>
    </xsl:template>
    <xsl:template match="*:input[exists(@data-ref)][not(@type='file')] | *:textarea[exists(@data-ref)]" mode="ixsl:onfocusout">
        <!-- TEST-TRACE: mirror blur-time control commit on focusout for UA/event-order variants where focusout fires without a usable blur hook; helps tests/supplemental/demo-schema-validation.spec.ts "orderId pattern facet marks invalid then valid". -->
        <xsl:sequence select="js:markControlVisited(normalize-space(string(@instance-context)), normalize-space(string(@data-ref)))"/>
        <xsl:call-template name="action-setvalue-form-control">
            <xsl:with-param name="form-control" select="."/>
        </xsl:call-template>
        <xsl:call-template name="outermost-action-handler"/>
    </xsl:template>
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Highlight repeat item when selected</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template match="*:div[@data-repeat-item = 'true']//*[self::*:span or self::*:input]" mode="ixsl:onclick">
        <xsl:if test="exists(@id) and not(@id = '')">
            <xsl:sequence select="js:highlightClicked( string(@id) )"/>
        </xsl:if>
        
                
        <!-- update repeat index of ancestors (we may have clicked on a repeat item within a repeat item) -->
        <xsl:for-each select="./ancestor::*:div[@data-repeat-item = 'true']">
            <xsl:variable name="repeat-id" as="xs:string" select="./ancestor::*:div[exists(@data-repeatable-context)][1]/@id"/>
            <xsl:variable name="item-position" as="xs:integer" select="count(./preceding-sibling::*:div[@data-repeat-item = 'true']) + 1"/>
            
            <xsl:message use-when="$debugMode">[div onclick] Setting repeat index '<xsl:value-of select="$repeat-id"/>' to value '<xsl:value-of select="$item-position"/>'</xsl:message>
            <xsl:sequence select="js:setRepeatIndex($repeat-id,$item-position)"/>                        
        </xsl:for-each>
        
        <xsl:if test="self::*:span">
            <xsl:call-template name="refreshElementsUsingIndexFunction-JS"/>     
        </xsl:if>
       
        
       <!-- <xsl:if test="self::input">
            <xsl:sequence select="js:setFocus( xs:string(@id) )"/>    
        </xsl:if>-->
        

    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>get-context-instance-id mode: return ID of instance that is the context of an XForms element.</xd:p>
            <xd:p>Called from xforms:bind match template (add-context mode)</xd:p>
        </xd:desc>
        <xd:param name="model-key">ID of context model (xforms:model/@id value or default value).</xd:param>
        <xd:param name="default-instance-id">ID of default instance in XForm.</xd:param>
        <xd:param name="nodeset">XPath binding expression</xd:param>
    </xd:doc>
    <xsl:template match="xforms:*" mode="get-context-instance-id" as="xs:string">
        <xsl:param name="model-key" as="xs:string" required="no" select="$global-default-model-id" tunnel="yes"/>        
        <xsl:param name="default-instance-id" as="xs:string" required="no" select="$global-default-instance-id" tunnel="yes"/>
        <xsl:param name="nodeset" as="xs:string" required="no" select="''"/>
        
        <xsl:variable name="log-label" as="xs:string" select="concat('[get-context-instance-id mode for ', name(), ']')"/>
        <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> START</xsl:message>
        <xsl:variable name="time-id" select="concat($log-label, ' ', generate-id())"/>
        <xsl:sequence use-when="$debugTiming" select="js:startTime($time-id)" />    

        <xsl:variable name="model-ref" as="xs:string">
            <xsl:choose>
                <xsl:when test="exists(@model)">
                    <xsl:sequence select="string(@model)"/>
                </xsl:when>
                <xsl:when test="self::xforms:bind">
                    <xsl:variable name="bind-model-id" select="./ancestor::xforms:model/@id"/>
                    <xsl:sequence select="if (exists($bind-model-id)) then string($bind-model-id) else $model-key"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="$model-key"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <!-- use $nodeset if present -->
        <xsl:variable name="referenced-instance-id" as="xs:string?" select="if ($nodeset ne '') then xforms:getInstanceId($nodeset) else ()"/>
        
        <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> $referenced-instance-id = <xsl:sequence select="$referenced-instance-id"/></xsl:message>
          
        <xsl:choose>
            <!-- take non-default instance ID if it is made explicit -->
            <xsl:when test="exists($referenced-instance-id) and not($referenced-instance-id = $global-default-instance-id)">
                <xsl:sequence select="$referenced-instance-id"/>
            </xsl:when>
            <xsl:otherwise>
                <!-- take first available of: model explicitly referenced with @model, ancestor model, default model -->
                <xsl:variable name="context-model" as="element(xforms:model)" select="
                    ($models-global[@id = $model-ref], ./ancestor::xforms:model, $models-global[1])[1]"/>
                <xsl:variable name="context-model-id" as="xs:string" select="
                    if (exists($context-model/@id))
                    then string($context-model/@id)
                    else $global-default-model-id"/>
                <xsl:variable name="local-default-instance" as="element(xforms:instance)?" select="$context-model/xforms:instance[1]"/>
                <xsl:variable name="context-default-instance-id" as="xs:string" select="
                    if (exists($local-default-instance/@id))
                    then xs:string($local-default-instance/@id)
                    else xforms:get-model-implicit-default-instance-id($context-model-id)"/>
                <xsl:choose>
                    <xsl:when test="exists($local-default-instance)">
                        <xsl:sequence select="$context-default-instance-id"/>
                    </xsl:when>
                    <!-- use default instance of XForm if there is nothing else to go on -->
                    <xsl:otherwise>
                        <xsl:sequence select="$default-instance-id"/>
                    </xsl:otherwise>
                </xsl:choose>
                
            </xsl:otherwise>
        </xsl:choose>
        
        <xsl:sequence use-when="$debugTiming" select="js:endTime($time-id)" />
        
        <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> END</xsl:message>
        
    </xsl:template>
    
    
    <xd:doc scope="component">
        <xd:desc>get-properties mode: return map containing the properties associated with an XForms element (taken from its binding if present)</xd:desc>
        <xd:param name="nodeset">XPath binding expression</xd:param>
        <xd:param name="model-key">ID of context model (xforms:model/@id value or default value).</xd:param>
        <xd:param name="bindings-js">Node set of xforms:bind elements</xd:param>   
        <xd:param name="default-instance-id">Context instance ID</xd:param>
        <xd:param name="default-namespace-context">Root element containing all namespace declarations</xd:param>
    </xd:doc>
    <xsl:template match="xforms:*" mode="get-properties">
        <xsl:param name="nodeset" as="xs:string" select="''" tunnel="yes"/>
        <xsl:param name="model-key" as="xs:string" required="no" select="$global-default-model-id" tunnel="yes"/>        
        <xsl:param name="bindings-js" as="element(xforms:bind)*" required="no" select="()" tunnel="yes"/>
        <xsl:param name="default-instance-id" as="xs:string" required="no" select="$global-default-instance-id" tunnel="yes"/>
        <xsl:param name="default-namespace-context" as="element()" required="yes" tunnel="yes"/>
        
        <xsl:variable name="log-label" as="xs:string" select="concat('[get-properties mode for ', name(), ']')"/>
        <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> START</xsl:message>
        
        <!-- TEST-TRACE: guard against zero models in document;
             return minimal property map so body rendering can proceed without crashing;
             helps tests/w3c/ch03.spec.ts "3.3.1.a2", "3.3.2.a",
             tests/w3c/ch04.spec.ts "4.2.1.a", "4.2.1.d", "4.2.2.a" -->
        <xsl:if test="empty($models-global)">
            <xsl:map>
                <xsl:map-entry key="'nodeset'" select="''"/>
                <xsl:map-entry key="'context-nodeset'" select="''"/>
                <xsl:map-entry key="'instance-context'" select="$global-default-instance-id"/>
                <xsl:map-entry key="'model-id'" select="$global-default-model-id"/>
            </xsl:map>
        </xsl:if>
        <xsl:if test="exists($models-global)">
        
        <xsl:variable name="time-id" select="concat($log-label, ' ', generate-id())"/>
        <xsl:sequence use-when="$debugTiming" select="js:startTime($time-id)" />   
        
        <xsl:variable name="binding-referenced-by-id" as="element(xforms:bind)?">
            <xsl:choose>
                <xsl:when test="exists(@bind)">
                    <xsl:variable name="bind" as="xs:string" select="xs:string(@bind)"/>
                    <xsl:sequence select="$bindings-js[@id = $bind]"/>
                </xsl:when>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:variable name="model-ref" as="xs:string">
            <xsl:choose>
                <xsl:when test="exists(@model)">
                    <xsl:sequence select="string(@model)"/>
                </xsl:when>
                <xsl:when test="exists($binding-referenced-by-id)">
                    <xsl:sequence select="string($binding-referenced-by-id/@model-context)"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="$model-key"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:variable name="context-model" as="element(xforms:model)" select="
            ($models-global[@id = $model-ref], ./ancestor::xforms:model, $models-global[1])[1]"/>
        <xsl:variable name="context-model-id" as="xs:string" select="
            if (exists($context-model/@id))
            then string($context-model/@id)
            else $global-default-model-id"/>
        <xsl:variable name="context-default-instance-id" as="xs:string" select="
            if (exists($context-model/xforms:instance[1]/@id))
            then string($context-model/xforms:instance[1]/@id)
            else xforms:get-model-implicit-default-instance-id($context-model-id)"/>
        <xsl:variable name="context-default-nodeset" as="xs:string" select="concat('instance(''', $context-default-instance-id, ''')')"/>
        
        <xsl:variable name="context-nodeset" as="xs:string" select="
            if (exists(@context))
            then xforms:resolveXPathStrings($nodeset,@context)
            else (
                if (exists(@model))
                then $context-default-nodeset
                else (
                    if ($nodeset ne '')
                    then $nodeset
                    else $context-default-nodeset
                )
            )"/>
        
        <!-- empty if @iterate not set (so we only set the 'iterate' property when there is iteration) -->
        <xsl:variable name="context-nodeset-iterate" as="xs:string?" select="if (exists(@iterate)) then xforms:resolveXPathStrings($context-nodeset,@iterate) else ()"/>
        
        <xsl:variable name="this-ref" as="xs:string?" select="
            if ( exists(@ref) ) 
            then normalize-space( xs:string(@ref) ) 
            else if ( exists(@nodeset) )
            then  normalize-space( xs:string(@nodeset) )
            else ()"/>
        
        <xsl:variable name="refi" as="xs:string">
            <xsl:choose>
                <xsl:when test="exists($binding-referenced-by-id)">
                    <xsl:sequence select="string($binding-referenced-by-id/@nodeset)"/>
                </xsl:when>
                <xsl:when test="exists($this-ref)">
                    <!-- context is iterate context if set, fall back to context-nodeset -->
                    <xsl:sequence select="xforms:resolveXPathStrings(($context-nodeset-iterate,$context-nodeset)[1],$this-ref)"/>
                </xsl:when>
                <xsl:when test="$nodeset != ''">
                    <xsl:sequence select="$nodeset"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="$context-default-nodeset"/>
                </xsl:otherwise>
            </xsl:choose>           
        </xsl:variable>
        
        <xsl:variable name="instance-context" as="xs:string">
            <xsl:choose>
                <xsl:when test="exists($binding-referenced-by-id)">
                    <xsl:sequence select="string($binding-referenced-by-id/@instance-context)"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="xforms:getInstanceId($refi)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:variable name="bindings-this-instance" as="element(xforms:bind)*" select="$bindings-js[@instance-context = $instance-context]"/>
                
         
        <xsl:variable name="binding-matching-nodeset" as="element(xforms:bind)?">
            <xsl:choose>
                <xsl:when test="exists($binding-referenced-by-id)"/>
                <xsl:when test="$refi != '' and exists($bindings-this-instance)">
                    <xsl:variable name="nodeset-mod" as="xs:string" select="xforms:impose($refi)"/>
                    <xsl:variable name="instanceXML" as="element()?">
                        <xsl:variable name="instanceXMLFromJS" as="element()?" select="xforms:instance($instance-context)"/>
                        <xsl:variable name="intanceXMLWithID" as="element()?" select="$context-model/xforms:instance[@id = $instance-context]"/>
                        <xsl:choose>
                            <xsl:when test="exists($instanceXMLFromJS)">
                                <xsl:sequence select="$instanceXMLFromJS"/>
                            </xsl:when>
                            <xsl:when test="exists($intanceXMLWithID)">
                                <xsl:sequence select="$intanceXMLWithID"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:sequence select="$context-model/xforms:instance[1]"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:variable>
                    
                    <xsl:for-each select="$bindings-this-instance[exists($instanceXML)]">
                        <xsl:variable name="binding-nodeset-mod" as="xs:string" select="xforms:impose(xs:string(@nodeset))"/>
                        
                        <xsl:variable name="context-node" as="node()*" select="xforms:evaluate-xpath-with-context-node($nodeset-mod,$instanceXML,$default-namespace-context)"/>
                        
                        <xsl:choose>
                            <!-- do a string check here of $nodeset-mod = $binding-nodeset-mod (as a shortcut before performing XPath evaluation) -->
                            <xsl:when test="$nodeset-mod = $binding-nodeset-mod">
                                <xsl:sequence select="."/>
                                <xsl:message use-when="$debugMode">[get-properties mode] Binding found by matching nodeset path '<xsl:sequence select="$nodeset-mod"/>'</xsl:message>
                            </xsl:when>
                            <!-- 
                                ignore when context is a nodeset
                            -->
                            <xsl:when test="count($context-node) > 1"/>
                            <xsl:otherwise>
                                <xsl:variable name="binding-context-node" as="node()*" select="xforms:evaluate-xpath-with-context-node($binding-nodeset-mod,$instanceXML,$default-namespace-context)"/>
                                
                                <xsl:if test="some $n in $binding-context-node satisfies $n is $context-node">
                                    <xsl:message use-when="$debugMode">[get-properties mode for <xsl:value-of select="name(.)"/>] Binding found by matching nodeset: <xsl:value-of select="serialize(.)"/></xsl:message>
                                    <xsl:sequence select="."/>
                                </xsl:if>        
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:for-each>
                </xsl:when>
                <xsl:otherwise>
                    <!--<xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> No binding found matching nodeset</xsl:message>-->
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        
        <xsl:variable name="binding" as="element(xforms:bind)?" select="($binding-referenced-by-id,$binding-matching-nodeset)[1]"/>
        
        <xsl:variable name="context-nodeset" as="xs:string" select="if (exists($binding)) then string($binding/@nodeset) else $nodeset"/>
                
                 
        <xsl:map>
            <xsl:map-entry key="'nodeset'" select="$refi"/>
            <xsl:map-entry key="'context-nodeset'" select="$context-nodeset"/>
            <xsl:map-entry key="'instance-context'" select="$instance-context"/>
            <xsl:map-entry key="'model-id'" select="$model-ref"/>
            <xsl:if test="exists($binding)">
                <xsl:map-entry key="'binding'" select="$binding"/>
            </xsl:if>
            <xsl:if test="exists($context-nodeset-iterate)">
                <xsl:map-entry key="'iterate'" select="$context-nodeset-iterate"/>
            </xsl:if>
        </xsl:map>
        
        <xsl:sequence use-when="$debugTiming" select="js:endTime($time-id)" />
        
        <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> END</xsl:message>
        
        </xsl:if>
    </xsl:template>
    

    <xd:doc scope="component">
        <xd:desc>set-actions mode: create map of actions relevant to XForm control element</xd:desc>
    </xd:doc>
    <xsl:template match="xforms:*" mode="set-actions">
        <xsl:apply-templates select=" xforms:action | xforms:*[local-name() = $xforms-actions] | xforms:show | xforms:hide | xforms:script | xforms:unload"/>
    </xsl:template>
    
    <!-- Web components have no nested XForms actions -->
    <xsl:template match="*[not(self::xforms:*)][exists(@xforms:ref)]" mode="set-actions" priority="10"/>
    
    <xd:doc scope="component">
        <xd:desc>set-action mode: create map of an action relevant to XForm action element</xd:desc>
        <xd:param name="default-instance-id">ID of context instance.</xd:param>
        <xd:param name="nodeset">XPath binding expression</xd:param>
        <xd:param name="handler-status">String value 'outermost' (default) or 'inner' to determine whether the action produces <xd:a href="https://www.w3.org/TR/xforms11/#action-deferred-update-behavior">deferred updates</xd:a></xd:param>
    </xd:doc>
    <xsl:template match="xforms:*" mode="set-action">
        <xsl:param name="default-instance-id" as="xs:string" required="no" select="$global-default-instance-id" tunnel="yes"/>
        <xsl:param name="nodeset" as="xs:string" select="''" tunnel="yes"/>
        <xsl:param name="handler-status" select="'outermost'" required="no" tunnel="yes"/>
        
        <xsl:variable name="log-label" as="xs:string" select="concat('[set-action mode for ', name(), ']')"/>
        <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> START</xsl:message>
        <xsl:variable name="time-id" select="concat($log-label, ' ', generate-id())"/>
        <xsl:sequence use-when="$debugTiming" select="js:startTime($time-id)" />    
        
        <xsl:variable name="this-properties" as="map(*)">
            <xsl:apply-templates select="." mode="get-properties"/>  
        </xsl:variable>
        
        <xsl:variable name="refi" as="xs:string" select="map:get($this-properties,'nodeset')"/>
        <xsl:variable name="context-nodeset" as="xs:string" select="map:get($this-properties,'context-nodeset')"/>
        <xsl:variable name="this-instance-id" as="xs:string" select="map:get($this-properties,'instance-context')"/>
        <xsl:variable name="default-observer-id" as="xs:string?" select="
            if (exists((ancestor-or-self::*[@id])[1]/@id))
            then string((ancestor-or-self::*[@id])[1]/@id)
            else ()"/>
        <xsl:variable name="resolved-observer-id" as="xs:string?" select="
            if (exists(@*:observer))
            then string(@*:observer)
            else $default-observer-id"/>
        <xsl:variable name="resolved-default-action" as="xs:string?" select="
            if (exists((@*:defaultAction, ancestor-or-self::*[@*:defaultAction][1]/@*:defaultAction)[1]))
            then string((@*:defaultAction, ancestor-or-self::*[@*:defaultAction][1]/@*:defaultAction)[1])
            else ()"/>
                
        <xsl:variable name="action-map" as="map(*)">
            <xsl:map>
                <xsl:map-entry key="'name'" select="local-name()"/>            
                <xsl:map-entry key="'handler-status'" select="$handler-status"/>            
                <xsl:map-entry key="'instance-context'" select="$this-instance-id"/>
                
                <xsl:if test="exists(@value)">
                    <xsl:map-entry key="'@value'" select="xforms:resolveContext(string(@value),$nodeset)" />                          
                </xsl:if>
                
                <xsl:if test="empty(@value) and exists(./text()) and not(self::xforms:message) and not(self::xforms:script)">
                    <xsl:map-entry key="'value'" select="string(.)" />                         
                </xsl:if>
                
                <!-- Capture xf:script body text as 'script-body' -->
                <xsl:if test="self::xforms:script">
                    <xsl:map-entry key="'script-body'" select="string(.)" />
                </xsl:if>
                
                <!-- TEST-TRACE: only persist @ref when explicitly declared on the action;
                     prevents context-only insert actions from inheriting ambient nodesets
                     and replacing root instances; helps tests/w3c/appendix.spec.ts "B.1", "B.4". -->
                <xsl:variable name="ref-local-raw" as="xs:string?" select="
                    if (exists(@ref) or exists(@nodeset))
                    then normalize-space(xs:string((@ref,@nodeset)[1]))
                    else ()"/>
                <xsl:variable name="effective-action-ref" as="xs:string?" select="
                    if (exists($ref-local-raw) and matches($ref-local-raw, '^event\s*\('))
                    then $ref-local-raw
                    else $refi"/>
                <xsl:if test="exists(@ref) or exists(@nodeset) or exists(@bind)">
                    <xsl:map-entry key="'@ref'" select="$effective-action-ref"/>
                </xsl:if>
                
                <!-- local ref used in conjunction with node set returned by @iterate -->
                <xsl:if test="exists(@ref) or exists(@nodeset) or exists(@bind)">
                    <xsl:map-entry key="'@ref-local'" select="$ref-local-raw"/>
                </xsl:if>
                <xsl:if test="exists(@bind)">
                    <xsl:map-entry key="'@bind'" select="string(@bind)"/>
                </xsl:if>
                
                <!-- 
                for @at and @position,
                see https://www.w3.org/TR/xforms11/#action-insert
            -->
                <xsl:if test="exists(@position)">
                    <xsl:map-entry key="'@position'" select="string(@position)" />
                </xsl:if>
                <xsl:if test="exists(@at)">
                    <xsl:map-entry key="'@at'" select="string(@at)" />
                </xsl:if>
                
                <!-- https://www.w3.org/TR/xforms11/#action-conditional -->
                <xsl:if test="exists(@if)">
                    <xsl:map-entry key="'@if'" select="string(@if)" />
                </xsl:if>
                
                <!-- https://www.w3.org/TR/xforms11/#action-iterated -->
                <xsl:if test="exists(@while)">
                    <xsl:map-entry key="'@while'" select="string(@while)" />
                </xsl:if>
                
                <!-- https://www.w3.org/community/xformsusers/wiki/XForms_2.0#The_iterate_attribute -->
                <xsl:if test="exists(@iterate)">
                    <xsl:map-entry key="'@iterate'" select="map:get($this-properties,'iterate')" />
                </xsl:if>
                
                <xsl:if test="exists(@*:event)">
                    <xsl:map-entry key="'@event'" select="string(@*:event)" />
                </xsl:if>
                <xsl:if test="exists($resolved-observer-id)">
                    <xsl:map-entry key="'@observer'" select="$resolved-observer-id" />
                </xsl:if>
                <xsl:if test="exists($resolved-default-action)">
                    <xsl:map-entry key="'@defaultAction'" select="$resolved-default-action" />
                </xsl:if>
                
                <!-- attributes of dispatch action -->
                <xsl:if test="exists(@name)">
                    <xsl:map-entry key="'@name'" select="string(@name)" />
                </xsl:if>
                <xsl:if test="exists(@targetid)">
                    <xsl:map-entry key="'@targetid'" select="string(@targetid)" />
                </xsl:if>
                <xsl:if test="exists(@bubbles)">
                    <xsl:map-entry key="'@bubbles'" select="string(@bubbles)" />
                </xsl:if>
                <xsl:if test="exists(@cancelable)">
                    <xsl:map-entry key="'@cancelable'" select="string(@cancelable)" />
                </xsl:if>
                <xsl:if test="exists(@delay)">
                    <xsl:map-entry key="'@delay'" select="string(@delay)" />
                </xsl:if>
                
                
                <xsl:if test="exists(@submission)">
                    <xsl:map-entry key="'@submission'" select="string(@submission)" />
                </xsl:if>
                
                <xsl:if test="exists(@model)">
                    <xsl:map-entry key="'@model'" select="string(@model)" />
                </xsl:if>
                
                <xsl:if test="exists(@control)">
                    <xsl:map-entry key="'@control'" select="string(@control)" />
                </xsl:if>
                
                <xsl:if test="exists(@repeat)">
                    <xsl:map-entry key="'@repeat'" select="string(@repeat)" />
                </xsl:if>
                
                <xsl:if test="exists(@index)">
                    <xsl:map-entry key="'@index'" select="string(@index)" />
                </xsl:if>
                
                <xsl:if test="exists(@level)">
                    <xsl:map-entry key="'@level'" select="string(@level)" />
                </xsl:if>
                
                <xsl:if test="exists(@origin)">
                    <xsl:variable name="origin-context" as="xs:string" select="
                        if (exists(@context)) 
                        then xforms:resolveXPathStrings($nodeset,@context)
                        else $nodeset"/>
                    <xsl:variable name="origin" as="xs:string" select="string(@origin)"/>
                    <xsl:variable name="origin-ref" as="xs:string" select="
                        if (matches(normalize-space($origin), '^event\s*\('))
                        then $origin
                        else xforms:resolveXPathStrings($origin-context,$origin)"/>
                    
                    <xsl:map-entry key="'@origin'" select="$origin-ref" /> 
                </xsl:if>
                
                <xsl:map-entry key="'@context'" select="if (exists(@context)) then xforms:resolveXPathStrings($nodeset,@context) else $nodeset" />   
                <xsl:if test="exists(@context)">
                    <xsl:map-entry key="'@context-explicit'" select="true()"/>
                </xsl:if>
                
                <!--<xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> @context = <xsl:sequence select="xforms:resolveXPathStrings($nodeset,@context)"/></xsl:message>-->
                
                <!-- https://www.w3.org/TR/xforms11/#action-toggle -->
                <xsl:if test="exists(@case)">
                    <xsl:map-entry key="'@case'" select="string(@case)"/>
                </xsl:if>
                <xsl:if test="exists(child::xforms:case)">
                    <xsl:map-entry key="'case'" select="if (xforms:case/text()[normalize-space() ne '']) then xforms:case/text() else string(xforms:case/@value)"/>
                </xsl:if>
                
                <!-- Capture xf:load @resource and @show -->
                <xsl:if test="exists(@resource)">
                    <xsl:map-entry key="'@resource'" select="string(@resource)" />
                </xsl:if>
                <xsl:if test="exists(@show)">
                    <xsl:map-entry key="'@show'" select="string(@show)" />
                </xsl:if>
                
                <!-- need to apply nested actions in order! -->            
                <xsl:if test="(child::* and not(self::xforms:toggle) and not(self::xforms:script)) or (self::xforms:message and child::text())">
                    <xsl:map-entry key="'nested-actions'">
                        <xsl:variable name="array" as="map(*)*">
                            <xsl:for-each select="child::node()[self::* or self::text()[parent::xforms:message]]">
                                <xsl:apply-templates select="." mode="set-action">
                                    <xsl:with-param name="default-instance-id" select="$this-instance-id" tunnel="yes"/>
                                    <xsl:with-param name="nodeset" select="$refi" tunnel="yes"/>
                                    <xsl:with-param name="handler-status" select="'inner'" tunnel="yes"/>
                                </xsl:apply-templates>
                            </xsl:for-each>
                        </xsl:variable>
                        <xsl:sequence select="array{$array}" />
                    </xsl:map-entry>
                </xsl:if>
                
            </xsl:map>
        </xsl:variable>
        
       
        
        
        <xsl:sequence select="$action-map"/>
        <xsl:if test="exists(@*:event)">
            <xsl:variable name="event-actions" as="map(*)*" select="js:getEventAction(string(@*:event))"/>
            <xsl:sequence select="js:addEventAction( string(@*:event), ($event-actions,$action-map) )"/>    
        </xsl:if>

        <xsl:sequence use-when="$debugTiming" select="js:endTime($time-id)" />
        <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> END</xsl:message>
        
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Turn a text node (inside xforms:message) into an action.</xd:p>
            <xd:p>Enables handling of mixed text() and xforms:output children of xforms:message.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template match="text()" mode="set-action">
        <xsl:map>
            <xsl:map-entry key="'name'" select="'text'"/>    
            <xsl:map-entry key="'instance-context'" select="$global-default-instance-id"/>    
            <xsl:map-entry key="'handler-status'" select="'inner'"/>    
            <xsl:map-entry key="'@value'" select="string(.)" />
        </xsl:map>
    </xsl:template>
    
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Function to get the ID of a repeat from a string containing an XForms index() function</xd:p>
        </xd:desc>
        <xd:param name="string-to-parse">A String</xd:param>
        <xd:return>Value of repeat ID (if present)</xd:return>
    </xd:doc>
    <xsl:function name="xforms:getRepeatID" as="xs:string?">
        <xsl:param name="string-to-parse" as="xs:string"/>
        
        <xsl:analyze-string select="$string-to-parse" regex="^.*index\s*\(\s*&apos;([^&apos;]+)&apos;\s*\).*$">
            <xsl:matching-substring>
                <xsl:sequence select="regex-group(1)"/>
            </xsl:matching-substring>
            <xsl:non-matching-substring>
                <xsl:message>[xforms:getRepeatID] No repeat identifiable from value '<xsl:value-of select="$string-to-parse"/>'</xsl:message>
            </xsl:non-matching-substring>
        </xsl:analyze-string>
        
        

    </xsl:function>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Parse a boolean-like event property with a default fallback.</xd:p>
        </xd:desc>
        <xd:param name="value">Event property value.</xd:param>
        <xd:param name="default-value">Fallback value if the property is absent or invalid.</xd:param>
    </xd:doc>
    <xsl:function name="xforms:event-flag" as="xs:boolean">
        <xsl:param name="value" as="item()*"/>
        <xsl:param name="default-value" as="xs:boolean"/>
        <xsl:variable name="normalized" as="xs:string?" select="
            if (exists($value))
            then lower-case(normalize-space(string($value[1])))
            else ()"/>
        <xsl:choose>
            <xsl:when test="empty($normalized) or $normalized = ''">
                <xsl:sequence select="$default-value"/>
            </xsl:when>
            <xsl:when test="$normalized = ('true','1')">
                <xsl:sequence select="true()"/>
            </xsl:when>
            <xsl:when test="$normalized = ('false','0')">
                <xsl:sequence select="false()"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:sequence select="$default-value"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
    <xsl:function name="xforms:safe-map-get" as="item()*">
        <xsl:param name="candidate" as="item()*"/>
        <xsl:param name="key" as="xs:string"/>
        <xsl:try>
            <xsl:sequence select="
                if ($candidate[1] instance of map(*))
                then map:get($candidate[1],$key)
                else ()"/>
            <xsl:catch>
                <xsl:sequence select="()"/>
            </xsl:catch>
        </xsl:try>
    </xsl:function>
    <xsl:function name="xforms:response-headers-to-nodes" as="element()*">
        <xsl:param name="headers" as="map(*)?"/>
        <xsl:for-each select="if (exists($headers)) then map:keys($headers) else ()">
            <xsl:sort select="."/>
            <header xmlns="">
                <name>
                    <xsl:value-of select="."/>
                </name>
                <value>
                    <xsl:value-of select="string(map:get($headers,.))"/>
                </value>
            </header>
        </xsl:for-each>
    </xsl:function>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Get the effective default model ID from the loaded XForm.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:function name="xforms:get-default-model-id" as="xs:string">
        <xsl:sequence select="
            if (exists($models-global[1]/@id))
            then string($models-global[1]/@id)
            else $global-default-model-id"/>
    </xsl:function>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Get the implicit default instance ID for a model.</xd:p>
        </xd:desc>
        <xd:param name="model-id">Model identifier.</xd:param>
    </xd:doc>
    <xsl:function name="xforms:get-model-implicit-default-instance-id" as="xs:string">
        <xsl:param name="model-id" as="xs:string"/>
        <xsl:sequence select="
            if ($model-id = xforms:get-default-model-id())
            then $global-default-instance-id
            else concat($model-id, '-', $global-default-instance-id)"/>
    </xsl:function>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Resolve registered instance IDs for a model.</xd:p>
        </xd:desc>
        <xd:param name="model-id">Model identifier.</xd:param>
    </xd:doc>
    <xsl:function name="xforms:get-model-instance-ids" as="xs:string*">
        <xsl:param name="model-id" as="xs:string"/>
        <xsl:variable name="model-node" as="element(xforms:model)?" select="
            (
                $models-global[@id = $model-id],
                if ($model-id = xforms:get-default-model-id()) then $models-global[1] else (),
                if ($model-id = $global-default-model-id) then $models-global[1] else ()
            )[1]"/>
        <xsl:variable name="implicit-default-instance-id" as="xs:string"
            select="xforms:get-model-implicit-default-instance-id($model-id)"/>
        <xsl:sequence select="
            for $pos in 1 to count($model-node/xforms:instance)
            return
                if (exists($model-node/xforms:instance[$pos]/@id))
                then string($model-node/xforms:instance[$pos]/@id)
                else
                    if ($pos = 1)
                    then $implicit-default-instance-id
                    else concat($implicit-default-instance-id, '-', $pos)
            "/>
    </xsl:function>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Get event target observer path (target then ancestors) from the source XForm document.</xd:p>
        </xd:desc>
        <xd:param name="target-id">Dispatched target ID.</xd:param>
        <xd:param name="bubbles">Whether event bubbling is enabled.</xd:param>
    </xd:doc>
    <xsl:function name="xforms:get-event-target-path" as="xs:string*">
        <xsl:param name="target-id" as="xs:string?"/>
        <xsl:param name="bubbles" as="xs:boolean"/>
        <xsl:variable name="normalized-target" as="xs:string?" select="
            if (exists($target-id) and normalize-space($target-id) != '')
            then normalize-space($target-id)
            else ()"/>
        <xsl:variable name="base-target" as="xs:string?" select="
            if (exists($normalized-target))
            then replace($normalized-target, '-[0-9]+$', '')
            else ()"/>
        <xsl:variable name="xforms-doc" as="document-node()?" select="js:getXFormsDoc()"/>
        <xsl:variable name="target-node" as="element()?" select="
            if (exists($xforms-doc) and exists($normalized-target))
            then (
                $xforms-doc//*[@id = $normalized-target],
                if (exists($base-target) and $base-target != $normalized-target) then $xforms-doc//*[@id = $base-target] else ()
            )[1]
            else ()"/>
        <xsl:variable name="path-from-doc" as="xs:string*" select="
            if (exists($target-node))
            then $target-node/ancestor-or-self::*[@id]/@id ! string(.)
            else ()"/>
        <xsl:choose>
            <xsl:when test="empty($normalized-target)">
                <xsl:sequence select="()"/>
            </xsl:when>
            <xsl:when test="$bubbles">
                <xsl:sequence select="distinct-values(($path-from-doc, $normalized-target, if ($base-target != $normalized-target) then $base-target else ()))"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:sequence select="(($path-from-doc[1], $normalized-target, if ($base-target != $normalized-target) then $base-target else ()))[1]"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Check whether an event action matches the current event target path.</xd:p>
        </xd:desc>
        <xd:param name="action-map">Event action map.</xd:param>
        <xd:param name="target-path">Target path (self/ancestors with @id).</xd:param>
        <xd:param name="target-id">Direct target ID.</xd:param>
    </xd:doc>
    <xsl:function name="xforms:event-action-matches-target" as="xs:boolean">
        <xsl:param name="action-map" as="map(*)"/>
        <xsl:param name="target-path" as="xs:string*"/>
        <xsl:param name="target-id" as="xs:string?"/>
        <xsl:variable name="observer" as="xs:string?" select="
            if (exists(map:get($action-map, '@observer')) and normalize-space(string(map:get($action-map, '@observer'))) != '')
            then normalize-space(string(map:get($action-map, '@observer')))
            else ()"/>
        <xsl:sequence select="
            if (empty($observer))
            then true()
            else (
                if (exists($target-path))
                then $observer = $target-path
                else (
                    if (exists($target-id))
                    then $observer = $target-id
                    else true()
                )
            )
            "/>
    </xsl:function>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Get event actions matching event name and observer/target constraints.</xd:p>
        </xd:desc>
        <xd:param name="event-name">Name of event.</xd:param>
        <xd:param name="event-context">Event context map.</xd:param>
    </xd:doc>
    <xsl:function name="xforms:get-matching-event-actions" as="map(*)*">
        <xsl:param name="event-name" as="xs:string"/>
        <xsl:param name="event-context" as="map(*)?"/>
        <xsl:variable name="context" as="map(*)" select="($event-context, map{})[1]"/>
        <xsl:variable name="target-id" as="xs:string?" select="
            if (exists((map:get($context, 'targetid'), map:get($context, 'target-id'))[1]) and normalize-space(string((map:get($context, 'targetid'), map:get($context, 'target-id'))[1])) != '')
            then normalize-space(string((map:get($context, 'targetid'), map:get($context, 'target-id'))[1]))
            else ()"/>
        <xsl:variable name="bubbles" as="xs:boolean" select="xforms:event-flag(map:get($context, 'bubbles'), true())"/>
        <xsl:variable name="target-path" as="xs:string*" select="xforms:get-event-target-path($target-id, $bubbles)"/>
        <xsl:variable name="actions" as="map(*)*" select="js:getEventAction($event-name)"/>
        <xsl:sequence select="$actions[xforms:event-action-matches-target(., $target-path, $target-id)]"/>
    </xsl:function>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Determine whether a cancelable event's default action is cancelled.</xd:p>
        </xd:desc>
        <xd:param name="event-name">Name of event.</xd:param>
        <xd:param name="event-context">Event context map.</xd:param>
    </xd:doc>
    <xsl:function name="xforms:is-event-default-cancelled" as="xs:boolean">
        <xsl:param name="event-name" as="xs:string"/>
        <xsl:param name="event-context" as="map(*)?"/>
        <xsl:variable name="context" as="map(*)" select="($event-context, map{})[1]"/>
        <xsl:variable name="cancelable" as="xs:boolean" select="xforms:event-flag(map:get($context, 'cancelable'), false())"/>
        <xsl:variable name="matching-actions" as="map(*)*" select="xforms:get-matching-event-actions($event-name, $context)"/>
        <xsl:sequence select="
            $cancelable and
            exists($matching-actions[lower-case(normalize-space(string(map:get(., '@defaultAction')))) = 'cancel'])
            "/>
    </xsl:function>
    

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Function to get 'if' statement from an action map</xd:p>
        </xd:desc>
        <xd:return>Value of map entry for @if (XPath expression)</xd:return>
        <xd:param name="map">Action map</xd:param>
    </xd:doc>
    <xsl:function name="xforms:getIfStatement" as="xs:string?">
        <xsl:param name="map" as="map(*)"/>
        <xsl:sequence select="map:get($map, '@if')"/>
    </xsl:function>

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Function to get 'while' statemenmt from an action map</xd:p>
        </xd:desc>
        <xd:return>Value of map entry for @while (XPath expression)</xd:return>
        <xd:param name="map">Action map</xd:param>
    </xd:doc>
    <xsl:function name="xforms:getWhileStatement" as="xs:string?">
        <xsl:param name="map" as="map(*)"/>
        <xsl:sequence select="map:get($map, '@while')"/>
    </xsl:function>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Function to get 'iterate' statemenmt from an action map</xd:p>
        </xd:desc>
        <xd:return>Value of map entry for @iterate (XPath expression)</xd:return>
        <xd:param name="map">Action map</xd:param>
    </xd:doc>
    <xsl:function name="xforms:getIterateStatement" as="xs:string?">
        <xsl:param name="map" as="map(*)"/>
        <xsl:sequence select="map:get($map, '@iterate')"/>
    </xsl:function>

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Function to resolve @ref relative to a context XPath</xd:p>
            <xd:p>Handles parent '..' steps in relative XPath</xd:p>
            <xd:p>OND comment: "Only to use this function on simple path cases"</xd:p>
        </xd:desc>
        <xd:return>Resolved XPath statement combining base and relative</xd:return>
        <xd:param name="base">Context XPath.</xd:param>
        <xd:param name="relative">XPath relative to base.</xd:param>
    </xd:doc>
    <xsl:function name="xforms:resolveXPathStrings" as="xs:string">
        <xsl:param name="base" as="xs:string"/>
        <xsl:param name="relative" as="xs:string"/>
        
        <!-- first get full path -->
        <xsl:variable name="full-path" as="xs:string">
            <xsl:choose>
                <xsl:when test="matches($relative,'^/[^/]*$')">
                    <!-- remove root element from XPath (when XPath is just root element) -->
                    <xsl:sequence select="$base"/>
                </xsl:when>
                <xsl:when test="starts-with($relative,'/')">
                    <!-- remove root element from XPath -->
                    <xsl:analyze-string select="$relative" regex="^/[^/]+/(.*)$">
                        <xsl:matching-substring>
                            <xsl:choose>
                                <!-- When base is empty (top-level bind with absolute XPath),
                                     just return the path after the root element -->
                                <xsl:when test="$base = ''">
                                    <xsl:sequence select="regex-group(1)"/>
                                </xsl:when>
                                <xsl:otherwise>
                                    <!-- TEST-TRACE: for absolute refs, use instance prefix
                                         (not full repeat path) to avoid mangling;
                                         helps tests/w3c/ch09.spec.ts "9.3.1.f" -->
                                    <xsl:variable name="instance-prefix" as="xs:string" select="
                                        if (matches($base, '^instance\s*\('))
                                        then replace($base, '^(instance\s*\([^)]+\)).*$', '$1')
                                        else $base"/>
                                    <xsl:sequence select="$instance-prefix || '/' || regex-group(1)"/>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:matching-substring>
                        <xsl:non-matching-substring>
                            <xsl:message>[xforms:resolveXPathStrings] Invalid XPath: '<xsl:value-of select="$relative"/>' ($base = <xsl:sequence select="$base"/>)</xsl:message>
                        </xsl:non-matching-substring>
                    </xsl:analyze-string>
                </xsl:when>
                <xsl:when test="starts-with($relative,'instance(')">
                    <xsl:sequence select="$relative"/>
                </xsl:when>
                <xsl:when test="$base = ''">
                    <xsl:sequence select="$relative"/>
                </xsl:when>
                <xsl:when test="$relative = '' or $relative = '.'">
                    <xsl:sequence select="$base"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="concat($base,'/',$relative)"/>                    
                </xsl:otherwise>
            </xsl:choose>            
        </xsl:variable>
                
        <xsl:sequence select="$full-path"/>

    </xsl:function>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Function to resolve XForms 'context()' function in an XPath expression</xd:p>
            <xd:p>See <xd:a href="https://www.w3.org/TR/xforms11/#fn-context">7.10.4 The context() Function</xd:a></xd:p>
        </xd:desc>
        <xd:return>Resolved XPath statement</xd:return>
        <xd:param name="xpath">Context XPath.</xd:param>
        <xd:param name="context">XPath expression for context node set.</xd:param>
    </xd:doc>
    <xsl:function name="xforms:resolveContext" as="xs:string">
        <xsl:param name="xpath" as="xs:string"/>
        <xsl:param name="context" as="xs:string"/>
        
        <xsl:sequence select="replace($xpath,'context\(\)',$context)"/>
        
    </xsl:function>
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Evaluate XPath relative to a context node</xd:p>
        </xd:desc>
        <xd:param name="xpath">XPath expression</xd:param>
        <xd:param name="context-node">XML node to use as context for the XPath expression.</xd:param>
        <xd:param name="namespace-context">Element containing all namespace declarations</xd:param>  
    </xd:doc>
    <!-- TEST-TRACE: context-node made optional (node()?) to handle models without instances;
         helps tests/w3c/ch04.spec.ts "4.2.1.a", "4.2.1.d", "4.2.2.a", "4.2.3.a", "4.5.2.a" -->
    <xsl:function name="xforms:evaluate-xpath-with-context-node">
        <!-- TEST-TRACE: tolerate empty-sequence XPath callers and treat as empty expression
             (no-op) instead of raising cardinality errors; helps tests/supplemental/xforms-fiddle.spec.ts
             "refreshing same bind-heavy source twice does not fail". -->
        <xsl:param name="xpath" as="xs:string?"/>
        <xsl:param name="context-node" as="node()?"/>
        <xsl:param name="namespace-context" as="element()?"/>
        <xsl:variable name="xpath-normalized" as="xs:string" select="($xpath,'')[1]"/>
        
        <xsl:variable name="namespace-context-item" as="element()?" select="
            if (exists($namespace-context))
            then $namespace-context
            else (
                if (exists(js:getXForm()))
                then js:getXForm()
                else (
                    if (exists($context-node) and $context-node[not(self::*)])
                    then $context-node/parent::*
                    else $context-node
                )
            )"/>
        
        <xsl:choose>
            <xsl:when test="$xpath-normalized ne '' and exists($context-node) and exists($namespace-context-item)">
                <xsl:evaluate xpath="xforms:impose($xpath-normalized)" context-item="$context-node" namespace-context="$namespace-context-item"/>
            </xsl:when>
            <xsl:when test="$xpath-normalized ne '' and exists($context-node)">
                <xsl:evaluate xpath="xforms:impose($xpath-normalized)" context-item="$context-node"/>
            </xsl:when>
            <xsl:otherwise/>
        </xsl:choose>
        
             
        
    </xsl:function>
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Evaluate XPath relative to an instance.</xd:p>
        </xd:desc>
        <xd:param name="xpath">XPath expression</xd:param>
        <xd:param name="instance-id">ID of instance to use as context node.</xd:param>    
        <xd:param name="namespace-context">Element containing all namespace declarations</xd:param>  
    </xd:doc>
    <!-- TEST-TRACE: guard against empty instance (model with no instance child);
         helps tests/w3c/ch08.spec.ts "8.1.8.a" -->
    <xsl:function name="xforms:evaluate-xpath-with-instance-id">
        <xsl:param name="xpath" as="xs:string"/>
        <xsl:param name="instance-id" as="xs:string?"/>
        <xsl:param name="namespace-context" as="element()?"/>
        
        <xsl:variable name="instanceXML" as="element()?" select="xforms:instance($instance-id)"/>
        <xsl:variable name="xpath-normalized" as="xs:string" select="normalize-space($xpath)"/>
        
        <xsl:choose>
            <xsl:when test="exists($instanceXML)">
                <!-- Use namespace-enriched XForm element as default namespace context -->
                <xsl:variable name="namespace-context-item" as="element()" select="
                    if (exists($namespace-context))
                    then $namespace-context
                    else (
                        if (exists(js:getXForm()))
                        then js:getXForm()
                        else $instanceXML
                    )"/>
                
                <!-- TEST-TRACE: wrap xsl:evaluate in xsl:try so bad XPath doesn't crash;
                     helps tests/w3c/ch04.spec.ts "4.5.1.a5", "4.5.2.a" -->
                <xsl:try>
                    <xsl:evaluate xpath="xforms:impose($xpath)" context-item="$instanceXML" namespace-context="$namespace-context-item"/>
                    <xsl:catch>
                        <xsl:message>[evaluate-xpath-with-instance-id] xforms-compute-exception: failed to evaluate '<xsl:value-of select="$xpath"/>'</xsl:message>
                    </xsl:catch>
                </xsl:try>
            </xsl:when>
            <xsl:otherwise/>
        </xsl:choose>
        
    </xsl:function>
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Return string or evaluate as XPath.</xd:p>
        </xd:desc>
        <xd:param name="string">String to check</xd:param>
        <xd:param name="context">XPath expression for context node set.</xd:param>
        <xd:param name="instance-id">ID of instance to use as context node.</xd:param>    
    </xd:doc>
    <xsl:function name="xforms:evaluate-string" as="xs:string?">
        <xsl:param name="string" as="xs:string"/>
        <xsl:param name="context" as="xs:string"/>
        <xsl:param name="instance-id" as="xs:string?"/>
        
        <xsl:message use-when="$debugMode">[xforms:evaluate-string] Evaluating '<xsl:sequence select="$string"/>' in context '<xsl:sequence select="$context"/>'</xsl:message>
        
        
        <!-- 
            components needed in case of complex values, e.g. class="dc-{@pass}"
        -->
        <xsl:variable name="components" as="xs:string*">
            <xsl:analyze-string select="$string" regex="\{{([^\}}]+)\}}">
                <xsl:matching-substring>
                    <xsl:message use-when="$debugMode">[xforms:evaluate-string] Evaluating XPath '<xsl:sequence select="regex-group(1)"/>' in context <xsl:sequence select="$context"/></xsl:message>
                    <xsl:variable name="xpath" select="normalize-space(regex-group(1))" />
                    
                    <!-- TEST-TRACE: [1] applies XForms first-node rule for duplicate siblings;
             helps tests/w3c/ch03.spec.ts "3.2.3.g" -->
        <xsl:variable name="instanceField" as="node()?" select="xforms:evaluate-xpath-with-instance-id($context,$instance-id,())[1]"/>
                    
                    <xsl:value-of select="xforms:evaluate-xpath-with-context-node($xpath,$instanceField,())"/>
                </xsl:matching-substring>
                <xsl:non-matching-substring>
                    <xsl:sequence select="$string"/>
                </xsl:non-matching-substring>
            </xsl:analyze-string>
        </xsl:variable>
        <xsl:sequence select="fn:string-join($components,'')"/>
        
    </xsl:function>
   
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Check whether each required field is populated.</xd:p>
        </xd:desc>
        <xd:return>Sequence of each HTML field that is required</xd:return>
        <xd:param name="instanceXML">Instance to check</xd:param>
    </xd:doc>
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Resolve a schema document from an instance node's xsi:schemaLocation.</xd:p>
        </xd:desc>
        <xd:param name="validation-node">Bound instance node used for validation</xd:param>
    </xd:doc>
    <xsl:function name="xforms:resolve-schema-doc" as="document-node()?">
        <xsl:param name="validation-node" as="node()?"/>
        <xsl:variable name="instance-root" as="element()?" select="
            if (exists($validation-node))
            then (root($validation-node)/*)[1]
            else ()"/>
        <xsl:variable name="schema-location-lexical" as="xs:string" select="
            if (exists($instance-root))
            then normalize-space(string(($instance-root/@*[local-name() = 'schemaLocation' and (namespace-uri() = '' or namespace-uri() = 'http://www.w3.org/2001/XMLSchema-instance')][1])))
            else ''"/>
        <xsl:variable name="schema-tokens" as="xs:string*" select="tokenize($schema-location-lexical,'\s+')"/>
        <xsl:variable name="schema-namespace-uri" as="xs:string?" select="if (count($schema-tokens) ge 1) then $schema-tokens[1] else ()"/>
        <xsl:variable name="schema-relative-uri" as="xs:string?" select="if (count($schema-tokens) ge 2) then $schema-tokens[2] else ()"/>
        <xsl:variable name="inline-schema-doc" as="document-node()?">
            <!-- TEST-TRACE: prefer inline xs:schema in source XForm before dereferencing schemaLocation URLs;
                 helps tests/w3c/nist-facets-engine.spec.ts "NIST subset through engine". -->
            <xsl:variable name="inline-schema" as="element(xs:schema)?" select="
                if (exists($xforms-doc-global))
                then (
                    if (exists($schema-namespace-uri) and $schema-namespace-uri != '')
                    then ($xforms-doc-global//xs:schema[@targetNamespace = $schema-namespace-uri])[1]
                    else ($xforms-doc-global//xs:schema)[1]
                )
                else ()"/>
            <xsl:choose>
                <xsl:when test="exists($inline-schema)">
                    <xsl:document>
                        <xsl:sequence select="$inline-schema"/>
                    </xsl:document>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="()"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="base-uri" as="xs:string" select="
            if (exists($source-base-uri) and normalize-space($source-base-uri) ne '')
            then string($source-base-uri)
            else (
                if (exists($xforms-doc-global))
                then string(base-uri($xforms-doc-global))
                else (if (exists($instance-root)) then string(base-uri($instance-root)) else '')
            )"/>
        <xsl:variable name="schema-uri" as="xs:anyURI?" select="
            if (exists($schema-relative-uri))
            then resolve-uri($schema-relative-uri,$base-uri)
            else ()"/>
        <xsl:variable name="schema-doc-from-uri" as="document-node()?">
            <!-- TEST-TRACE: load schema from xsi:schemaLocation for named simpleType facet checks;
                 helps tests/w3c/nist-facets-engine.spec.ts "NIST subset through engine". -->
            <xsl:choose>
                <xsl:when test="exists($schema-uri)">
                    <xsl:try>
                        <xsl:sequence select="doc($schema-uri)"/>
                        <xsl:catch>
                            <xsl:sequence select="()"/>
                        </xsl:catch>
                    </xsl:try>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="()"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:sequence select="($inline-schema-doc,$schema-doc-from-uri)[1]"/>
    </xsl:function>

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Validate lexical value against bind/xsi type, using schema-derived facets when available.</xd:p>
        </xd:desc>
        <xd:param name="binding-type">Datatype string from bind metadata or xsi:type</xd:param>
        <xd:param name="typed-value">Current lexical value</xd:param>
        <xd:param name="validation-node">Bound instance node</xd:param>
    </xd:doc>
    <xsl:function name="xforms:is-type-valid-with-schema" as="xs:boolean">
        <xsl:param name="binding-type" as="xs:string?"/>
        <xsl:param name="typed-value" as="xs:string?"/>
        <xsl:param name="validation-node" as="node()?"/>
        <xsl:variable name="type-name" as="xs:string" select="normalize-space(string($binding-type))"/>
        <xsl:variable name="schema-doc" as="document-node()?" select="xforms:resolve-schema-doc($validation-node)"/>
        <xsl:sequence select="
            if ($type-name = '')
            then true()
            else if (exists($schema-doc))
            then xsdh:is-type-valid-against-schema($type-name,$typed-value,$schema-doc)
            else xsdh:is-type-valid($type-name,$typed-value)"/>
    </xsl:function>

    <xsl:function name="xforms:check-required-fields" as="item()*">
        <xsl:param name="instanceXML" as="element()"/>

        <xsl:variable name="required-fieldsi" select="ixsl:page()//*[@data-required]" as="element()*"/>
        <!--
            Required checks must run against bound instance nodes (not DOM nodes),
            and only for currently relevant controls, so hidden/non-relevant fields
            do not block submit.
        -->

        <xsl:for-each select="$required-fieldsi">
            <xsl:variable name="control-instance-id" as="xs:string?" select="normalize-space(string(@instance-context))"/>
            <xsl:variable name="contexti" as="node()?" select="
                if (exists(@data-ref))
                then (
                    if ($control-instance-id != '')
                    then (xforms:evaluate-xpath-with-instance-id(string(@data-ref),$control-instance-id,()))[1]
                    else (xforms:evaluate-xpath-with-context-node(string(@data-ref),$instanceXML,()))[1]
                )
                else ()"/>
            <xsl:variable name="relevanti" as="xs:boolean" select="
                if (exists(@data-relevant))
                then (
                    if (exists($contexti))
                    then boolean(xforms:evaluate-xpath-with-context-node(string(@data-relevant),$contexti,()))
                    else false()
                )
                else true()"/>
            <xsl:variable name="requiredi" as="xs:boolean" select="
                if (exists(@data-required))
                then (
                    if (exists($contexti))
                    then boolean(xforms:evaluate-xpath-with-context-node(string(@data-required),$contexti,()))
                    else false()
                )
                else false()"/>
            <xsl:variable name="has-value" as="xs:boolean" select="
                if (exists($contexti))
                then (exists($contexti/*) or string-length(normalize-space(string($contexti))) gt 0)
                else false()"/>
            <xsl:message use-when="$debugMode">[xforms:check-required-fields] ref=<xsl:value-of select="@data-ref"/> relevant=<xsl:value-of select="$relevanti"/> required=<xsl:value-of select="$requiredi"/> hasValue=<xsl:value-of select="$has-value"/></xsl:message>
            <xsl:sequence select="if ($relevanti and $requiredi and not($has-value)) then . else ()"/>
        </xsl:for-each>

    </xsl:function>
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Check whether each field satisfies any constraints.</xd:p>
            <xd:p>TODO: check logic here</xd:p>
        </xd:desc>
        <xd:return>Sequence of each HTML field that is not valid wrt its constraints</xd:return>
        <xd:param name="instanceXML">Instance to check</xd:param>
    </xd:doc>
    <xsl:function name="xforms:check-constraints-on-fields" as="item()*">
        <xsl:param name="instanceXML" as="element()"/>
        <!--
            Include controls carrying explicit @data-constraint and controls that
            only provide bind type metadata; both can participate in submit validity.
        -->
        <xsl:variable name="constraint-fieldsi" select="ixsl:page()//*[@data-constraint or @data-binding-type]" as="element()*"/>

        <xsl:for-each select="$constraint-fieldsi">
            <xsl:variable name="control-instance-id" as="xs:string?" select="normalize-space(string(@instance-context))"/>
            <xsl:variable name="contexti" as="node()?" select="
                if (exists(@data-ref))
                then (
                    if ($control-instance-id != '')
                    then (xforms:evaluate-xpath-with-instance-id(string(@data-ref),$control-instance-id,()))[1]
                    else (xforms:evaluate-xpath-with-context-node(string(@data-ref),$instanceXML,()))[1]
                )
                else ()"/>
            <xsl:variable name="relevanti" as="xs:boolean" select="
                if (exists(@data-relevant))
                then (
                    if (exists($contexti))
                    then boolean(xforms:evaluate-xpath-with-context-node(string(@data-relevant),$contexti,()))
                    else false()
                )
                else true()"/>
            <xsl:variable name="constraint-resulti" as="xs:boolean" select="
                if (exists(@data-constraint))
                then (
                    if (exists($contexti))
                    then boolean(xforms:evaluate-xpath-with-context-node(string(@data-constraint),$contexti,()))
                    else false()
                )
                else true()"/>
            <xsl:variable name="typed-value" as="xs:string" select="
                if (exists($contexti))
                then string($contexti)
                else ''"/>
            <xsl:variable name="binding-type" as="xs:string" select="normalize-space(string(@data-binding-type))"/>
            <!-- TEST-TRACE: prefer schema-derived facets (xsi:schemaLocation) for named types during submit checks;
                 helps tests/w3c/nist-facets-engine.spec.ts "NIST subset through engine". -->
            <xsl:variable name="type-validi" as="xs:boolean" select="xforms:is-type-valid-with-schema($binding-type,$typed-value,$contexti)"/>
            <xsl:variable name="resulti" as="xs:boolean" select="$constraint-resulti and $type-validi"/>
            <xsl:message use-when="$debugMode">[xforms:check-constraints-on-fields] ref=<xsl:value-of select="@data-ref"/> relevant=<xsl:value-of select="$relevanti"/> bindingType=<xsl:value-of select="$binding-type"/> constraintResult=<xsl:value-of select="$constraint-resulti"/> typeValid=<xsl:value-of select="$type-validi"/></xsl:message>
            <xsl:sequence select="if ($relevanti and not($resulti)) then . else ()"/>
        </xsl:for-each>
    </xsl:function>
    <xsl:function name="xforms:is-node-in-submission-scope" as="xs:boolean">
        <xsl:param name="candidate-node" as="node()"/>
        <xsl:param name="submission-context-nodes" as="item()*"/>
        <xsl:sequence select="
            if (empty($submission-context-nodes[. instance of node()]))
            then true()
            else (
                some $scope-node in $submission-context-nodes[. instance of node()]
                satisfies (
                    $candidate-node is $scope-node
                    or exists($candidate-node/ancestor::node()[. is $scope-node])
                )
            )"/>
    </xsl:function>
    <xsl:function name="xforms:check-required-bindings" as="item()*">
        <xsl:param name="instanceXML" as="element()"/>
        <xsl:param name="instance-id" as="xs:string"/>
        <xsl:param name="submission-context-nodes" as="item()*"/>
        <xsl:variable name="required-bindings" as="element(xforms:bind)*" select="js:getBindings()[@instance-context = $instance-id][exists(@required)]"/>
        <xsl:for-each select="$required-bindings">
            <xsl:variable name="binding" as="element(xforms:bind)" select="."/>
            <xsl:variable name="bound-nodes" as="item()*" select="xforms:evaluate-xpath-with-instance-id(string($binding/@nodeset),$instance-id,())"/>
            <xsl:for-each select="$bound-nodes[. instance of node()]">
                <xsl:variable name="bound-node" as="node()" select="."/>
                <xsl:variable name="in-submission-scope" as="xs:boolean" select="xforms:is-node-in-submission-scope($bound-node,$submission-context-nodes)"/>
                <xsl:variable name="validation-context" as="node()" select="if ($bound-node[self::attribute()]) then $bound-node/parent::* else $bound-node"/>
                <xsl:variable name="requiredi" as="xs:boolean">
                    <xsl:try>
                        <xsl:sequence select="boolean(xforms:evaluate-xpath-with-context-node(string($binding/@required),$validation-context,()))"/>
                        <xsl:catch>
                            <xsl:sequence select="false()"/>
                        </xsl:catch>
                    </xsl:try>
                </xsl:variable>
                <xsl:variable name="has-value" as="xs:boolean" select="exists($bound-node/*) or string-length(normalize-space(string($bound-node))) gt 0"/>
                <xsl:sequence select="if ($in-submission-scope and $requiredi and not($has-value)) then $bound-node else ()"/>
            </xsl:for-each>
        </xsl:for-each>
    </xsl:function>
    <xsl:function name="xforms:check-instance-xsi-types" as="item()*">
        <xsl:param name="submission-context-nodes" as="item()*"/>
        <xsl:variable name="scoped-elements" as="element()*" select="
            for $scope-node in $submission-context-nodes
            return (
                if ($scope-node instance of document-node())
                then $scope-node/descendant-or-self::*
                else (
                    if ($scope-node instance of element())
                    then $scope-node/descendant-or-self::*
                    else ()
                )
            )"/>
        <xsl:for-each select="$scoped-elements[@*[local-name() = 'type' and namespace-uri() = 'http://www.w3.org/2001/XMLSchema-instance']]">
            <xsl:variable name="declared-type" as="xs:string" select="normalize-space(string(@*[local-name() = 'type' and namespace-uri() = 'http://www.w3.org/2001/XMLSchema-instance'][1]))"/>
            <xsl:variable name="typed-value" as="xs:string" select="string(.)"/>
            <!-- TEST-TRACE: apply schema-derived facets for xsi:type values when schemaLocation is present;
                 helps tests/w3c/nist-facets-engine.spec.ts "NIST subset through engine". -->
            <xsl:if test="$declared-type != '' and not(xforms:is-type-valid-with-schema($declared-type,$typed-value,.))">
                <xsl:sequence select="."/>
            </xsl:if>
        </xsl:for-each>
    </xsl:function>
    <xsl:function name="xforms:check-constraints-on-bindings" as="item()*">
        <xsl:param name="instanceXML" as="element()"/>
        <xsl:param name="instance-id" as="xs:string"/>
        <xsl:param name="submission-context-nodes" as="item()*"/>
        <xsl:variable name="constraint-bindings" as="element(xforms:bind)*" select="js:getBindings()[@instance-context = $instance-id][exists(@constraint) or exists(@type)]"/>
        <xsl:for-each select="$constraint-bindings">
            <xsl:variable name="binding" as="element(xforms:bind)" select="."/>
            <xsl:variable name="bound-nodes" as="item()*" select="xforms:evaluate-xpath-with-instance-id(string($binding/@nodeset),$instance-id,())"/>
            <xsl:for-each select="$bound-nodes[. instance of node()]">
                <xsl:variable name="bound-node" as="node()" select="."/>
                <xsl:variable name="in-submission-scope" as="xs:boolean" select="xforms:is-node-in-submission-scope($bound-node,$submission-context-nodes)"/>
                <xsl:variable name="validation-context" as="node()" select="if ($bound-node[self::attribute()]) then $bound-node/parent::* else $bound-node"/>
                <xsl:variable name="relevanti" as="xs:boolean">
                    <xsl:choose>
                        <xsl:when test="exists($binding/@relevant)">
                            <xsl:try>
                                <xsl:sequence select="boolean(xforms:evaluate-xpath-with-context-node(string($binding/@relevant),$validation-context,()))"/>
                                <xsl:catch>
                                    <xsl:sequence select="true()"/>
                                </xsl:catch>
                            </xsl:try>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:sequence select="true()"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <xsl:variable name="constraint-resulti" as="xs:boolean">
                    <xsl:choose>
                        <xsl:when test="exists($binding/@constraint)">
                            <xsl:try>
                                <xsl:sequence select="boolean(xforms:evaluate-xpath-with-context-node(string($binding/@constraint),$validation-context,()))"/>
                                <xsl:catch>
                                    <xsl:sequence select="false()"/>
                                </xsl:catch>
                            </xsl:try>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:sequence select="true()"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <xsl:variable name="typed-value" as="xs:string" select="string($bound-node)"/>
                <xsl:variable name="binding-type" as="xs:string" select="normalize-space(string($binding/@type))"/>
                <!-- TEST-TRACE: prefer schema-derived facets (xsi:schemaLocation) for bind type checks;
                     helps tests/w3c/nist-facets-engine.spec.ts "NIST subset through engine". -->
                <xsl:variable name="type-validi" as="xs:boolean" select="xforms:is-type-valid-with-schema($binding-type,$typed-value,$bound-node)"/>
                <xsl:variable name="resulti" as="xs:boolean" select="$constraint-resulti and $type-validi"/>
                <xsl:sequence select="if ($in-submission-scope and $relevanti and not($resulti)) then $bound-node else ()"/>
            </xsl:for-each>
        </xsl:for-each>
    </xsl:function>



    <xd:doc scope="component">
        <xd:desc>Handle HTML submission</xd:desc>
    </xd:doc>
    <xsl:template match="*:button[exists(@data-submit)]" mode="ixsl:onclick">
        
        <xsl:call-template name="xforms-submit">
            <xsl:with-param name="submission" select="string(./@data-submit)"/>
        </xsl:call-template>

    </xsl:template>

    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template called by ixsl:schedule-action in template for xforms-submit event</xd:p>
            <xd:p>The context item should be an <xd:a href="https://www.saxonica.com/saxon-js/documentation/index.html#!development/http">HTTP response map</xd:a>, i.e. Saxon-JS representation of an HTTP response as an XDM map. </xd:p>
        </xd:desc>
        <xd:param name="instance-id">Identifier of instance affected by submission</xd:param>
        <xd:param name="targetref">XPath to identify node within target instance</xd:param>
        <xd:param name="replace">String to identify whether to replace the node or just the text content</xd:param>
    </xd:doc>
    <xsl:template name="HTTPsubmit">
         
        <xsl:context-item as="map(*)" use="required"/>
                
        <xsl:param name="instance-id" as="xs:string" required="no" select="$global-default-instance-id"/>
        <xsl:param name="resource-uri" as="xs:string?" required="no"/>
        <xsl:param name="submission-id" as="xs:string?" required="no"/>
        <xsl:param name="targetref" as="xs:string?" required="no"/>
        <xsl:param name="replace" as="xs:string?" required="no"/>
        <xsl:if test="$sequence-template-trace-enabled">
            <xsl:message>[SEQTRACE] template=HTTPsubmit submission=<xsl:value-of select="$submission-id"/> replace=<xsl:value-of select="$replace"/></xsl:message>
        </xsl:if>
        
        <xsl:variable name="refi" as="xs:string" select="concat('instance(''', $instance-id, ''')/')"/>
        <xsl:variable name="submission-id-normalized" as="xs:string?" select="
            if (exists($submission-id) and normalize-space($submission-id) != '')
            then normalize-space($submission-id)
            else ()"/>
        
        <!-- 
            https://www.saxonica.com/saxon-js/documentation2/index.html#!development/http
        -->
        <xsl:variable name="response-headers" select="(?headers, map{})[1]" as="map(*)"/>
        <xsl:message use-when="$debugMode">[HTTPsubmit] response content type: <xsl:sequence select="map:get($response-headers,'content-type')"/></xsl:message>
        
        <!-- 
            Type of response may vary, so using generic item() type
            
            '?' is the lookup operator: https://www.w3.org/TR/xpath-31/#id-lookup
            Here it acts on the context item, i.e. the HTTP response map
        -->
        <xsl:variable name="response" select="?body" as="item()?"/>  
        <xsl:variable name="response-status" as="item()?" select="?status"/>
        <xsl:variable name="response-message" as="item()?" select="?message"/>
        <xsl:variable name="response-status-code" as="xs:integer?" select="
            if (exists($response-status) and normalize-space(string($response-status)) castable as xs:integer)
            then xs:integer(normalize-space(string($response-status)))
            else ()"/>
        <xsl:variable name="response-is-success" as="xs:boolean" select="
            if (exists($response-status-code))
            then ($response-status-code ge 200 and $response-status-code lt 300)
            else true()"/>
        <xsl:variable name="replace-normalized" as="xs:string" select="lower-case(normalize-space(string($replace)))"/>
        <xsl:variable name="response-headers-nodes" as="element()*" select="xforms:response-headers-to-nodes($response-headers)"/>
        <xsl:variable name="response-kind" as="xs:string" select="
            if (empty($response))
            then 'empty'
            else (
                if ($response instance of document-node())
                then 'document-node'
                else (
                    if ($response instance of map(*))
                    then 'map'
                    else (
                        if ($response instance of array(*))
                        then 'array'
                        else (
                            if ($response instance of node())
                            then concat('node:',name($response))
                            else (
                                if ($response instance of xs:anyAtomicType)
                                then 'atomic'
                                else 'item'
                            )
                        )
                    )
                )
            )
            "/>
        <xsl:variable name="response-instance-root" as="element()?">
            <xsl:choose>
                <xsl:when test="$response instance of document-node()">
                    <xsl:sequence select="$response/*[1]"/>
                </xsl:when>
                <xsl:when test="$response instance of element()">
                    <xsl:sequence select="$response"/>
                </xsl:when>
                <xsl:when test="$response instance of xs:string and starts-with(normalize-space($response),'<')">
                    <xsl:try>
                        <xsl:sequence select="parse-xml($response)/*[1]"/>
                        <xsl:catch/>
                    </xsl:try>
                </xsl:when>
                <xsl:otherwise/>
            </xsl:choose>
        </xsl:variable>
        <xsl:message use-when="$debugMode">[HTTPsubmit-trace] replace=<xsl:value-of select="$replace"/> replace-normalized=<xsl:value-of select="$replace-normalized"/> instance=<xsl:value-of select="$instance-id"/> targetref=<xsl:value-of select="$targetref"/> response-kind=<xsl:value-of select="$response-kind"/> has-response-root=<xsl:value-of select="exists($response-instance-root)"/></xsl:message>
        <!-- TEST-TRACE: phase-1 Option C instrumentation for submission response path; helps tests/w3c/ch11.spec.ts "11.1.s1 [phase1]", "11.10.c [phase1]". -->
        <xsl:message use-when="$debugMode">[HTTPsubmit] response diagnostics: status=<xsl:sequence select="$response-status"/> message=<xsl:sequence select="$response-message"/> replace=<xsl:sequence select="$replace"/> targetref=<xsl:sequence select="$targetref"/> instance=<xsl:sequence select="$instance-id"/> response-kind=<xsl:sequence select="$response-kind"/></xsl:message>
         
        <xsl:choose>
              <xsl:when test="not($response-is-success)">
                  <xsl:message>++++++++++++ ERROR +++++++++++++</xsl:message>
                  <xsl:if test="exists($submission-id-normalized)">
                      <xsl:sequence select="js:clearSubmissionInProgress($submission-id-normalized)"/>
                  </xsl:if>
                  <xsl:call-template name="dispatch-submit-error">
                      <xsl:with-param name="submission-id" select="$submission-id-normalized"/>
                      <xsl:with-param name="error-type" select="'resource-error'"/>
                      <xsl:with-param name="resource-uri" select="$resource-uri"/>
                      <xsl:with-param name="response-status-code" select="if (exists($response-status-code)) then string($response-status-code) else ()"/>
                      <xsl:with-param name="response-headers" select="$response-headers"/>
                  </xsl:call-template>
              </xsl:when>
              <xsl:when test="empty($response)">
                  <xsl:message>++++++++++++ ERROR +++++++++++++</xsl:message>
                  <xsl:if test="exists($submission-id-normalized)">
                      <xsl:sequence select="js:clearSubmissionInProgress($submission-id-normalized)"/>
                  </xsl:if>
                  <xsl:call-template name="dispatch-submit-error">
                      <xsl:with-param name="submission-id" select="$submission-id-normalized"/>
                      <xsl:with-param name="error-type" select="'resource-error'"/>
                      <xsl:with-param name="resource-uri" select="$resource-uri"/>
                      <xsl:with-param name="response-status-code" select="if (exists($response-status)) then string($response-status) else ()"/>
                      <xsl:with-param name="response-headers" select="$response-headers"/>
                  </xsl:call-template>
              </xsl:when>


              <xsl:otherwise>
                  <!-- MD 2018: comment out replaceDocument for testing
                  The action here depends on the type of submission...
                  -->
<!--                  <xsl:sequence select="js:replaceDocument(serialize($responseXML))" />-->
                  
                  <xsl:choose>
                      <xsl:when test="$replace-normalized = 'instance' and exists($response-instance-root)">
                          <xsl:choose>
                              <xsl:when test="exists($targetref) and normalize-space($targetref) != ''">
                                  <xsl:variable name="instanceItem" as="item()?" select="xforms:instance($instance-id)"/>
                                  <xsl:variable name="instanceXML" as="element()?" select="
                                      if ($instanceItem instance of element())
                                      then $instanceItem
                                      else (
                                          if ($instanceItem instance of document-node())
                                          then $instanceItem/*[1]
                                          else ()
                                      )"/>
                                  <xsl:message use-when="$debugMode">[HTTPsubmit-trace] targetref-eval instance-exists=<xsl:value-of select="exists($instanceXML)"/> instance-kind=<xsl:value-of select="
                                      if (empty($instanceItem))
                                      then 'empty'
                                      else (
                                          if ($instanceItem instance of document-node())
                                          then 'document-node'
                                          else (
                                              if ($instanceItem instance of element())
                                              then concat('element:',name($instanceItem))
                                              else (
                                                  if ($instanceItem instance of node())
                                                  then concat('node:',name($instanceItem))
                                                  else (
                                                      if ($instanceItem instance of map(*))
                                                      then 'map'
                                                      else (
                                                          if ($instanceItem instance of array(*))
                                                          then 'array'
                                                          else (
                                                              if ($instanceItem instance of xs:anyAtomicType)
                                                              then 'atomic'
                                                              else 'item'
                                                          )
                                                      )
                                                  )
                                              )
                                          )
                                      )
                                      "/></xsl:message>
                                  <xsl:choose>
                                      <xsl:when test="exists($instanceXML)">
                                          <xsl:variable name="targetref-normalized" as="xs:string" select="normalize-space($targetref)"/>
                                          <xsl:variable name="target-node" as="item()?" select="
                                              if (
                                                  $targetref-normalized = concat('/',name($instanceXML))
                                                  or $targetref-normalized = concat('/',local-name($instanceXML))
                                              )
                                              then $instanceXML
                                              else (xforms:evaluate-xpath-with-context-node($targetref,$instanceXML,()))[1]
                                              "/>
                                          <xsl:message use-when="$debugMode">[HTTPsubmit-trace] targetref-eval target-node-exists=<xsl:value-of select="$target-node instance of node()"/> instance-root=<xsl:value-of select="name($instanceXML)"/></xsl:message>
                                          <xsl:choose>
                                              <xsl:when test="$target-node instance of node()">
                                                  <xsl:variable name="updatedInstanceXML" as="element()">
                                                      <xsl:apply-templates select="$instanceXML" mode="replace-node">
                                                          <xsl:with-param name="replace-node" select="$target-node" tunnel="yes"/>
                                                          <xsl:with-param name="replacement-node" select="$response-instance-root" tunnel="yes"/>
                                                      </xsl:apply-templates>
                                                  </xsl:variable>
                                                  <xsl:sequence select="js:setInstance($instance-id,$updatedInstanceXML)"/>
                                                  <xsl:sequence select="js:addDirtyInstance($instance-id)"/>
                                                  <xsl:sequence select="js:setDeferredUpdateFlags(('rebuild','recalculate','revalidate','refresh'))"/>
                                                  <xsl:message use-when="$debugMode">[HTTPsubmit-trace] setInstance targetref-branch updated-root=<xsl:value-of select="name($updatedInstanceXML)"/> updated-xml=<xsl:value-of select="serialize($updatedInstanceXML)"/></xsl:message>
                                              </xsl:when>
                                              <xsl:otherwise>
                                                  <xsl:message use-when="$debugMode">[HTTPsubmit-trace] targetref-invalid dispatching-submit-error error-type=target-error targetref=<xsl:value-of select="$targetref"/></xsl:message>
                                                  <xsl:call-template name="dispatch-submit-error">
                                                      <xsl:with-param name="submission-id" select="$submission-id-normalized"/>
                                                      <xsl:with-param name="error-type" select="'target-error'"/>
                                                      <xsl:with-param name="resource-uri" select="$resource-uri"/>
                                                      <xsl:with-param name="response-status-code" select="if (exists($response-status)) then string($response-status) else ()"/>
                                                      <xsl:with-param name="response-headers" select="$response-headers"/>
                                                  </xsl:call-template>
                                              </xsl:otherwise>
                                          </xsl:choose>
                                      </xsl:when>
                                      <xsl:otherwise>
                                          <xsl:sequence select="js:setInstance($instance-id,$response-instance-root)"/>
                                          <xsl:sequence select="js:addDirtyInstance($instance-id)"/>
                                          <xsl:sequence select="js:setDeferredUpdateFlags(('rebuild','recalculate','revalidate','refresh'))"/>
                                          <xsl:message use-when="$debugMode">[HTTPsubmit-trace] setInstance missing-instance-fallback response-root=<xsl:value-of select="name($response-instance-root)"/> response-xml=<xsl:value-of select="serialize($response-instance-root)"/></xsl:message>
                                      </xsl:otherwise>
                                  </xsl:choose>
                              </xsl:when>
                              <xsl:otherwise>
                                  <xsl:sequence select="js:setInstance($instance-id,$response-instance-root)"/>
                                  <xsl:sequence select="js:addDirtyInstance($instance-id)"/>
                                  <xsl:sequence select="js:setDeferredUpdateFlags(('rebuild','recalculate','revalidate','refresh'))"/>
                                  <xsl:message use-when="$debugMode">[HTTPsubmit-trace] setInstance direct-instance-replace response-root=<xsl:value-of select="name($response-instance-root)"/> response-xml=<xsl:value-of select="serialize($response-instance-root)"/></xsl:message>
                              </xsl:otherwise>
                          </xsl:choose>
                          
<!--                         <xsl:message use-when="$debugMode">[HTTPsubmit] response body: <xsl:value-of select="serialize($response)"/></xsl:message>-->
                      </xsl:when>
                      <xsl:when test="$replace-normalized = 'text' and exists($targetref) and $response castable as xs:string">
                          <xsl:message use-when="$debugMode">[HTTPsubmit] response text: <xsl:sequence select="$response"/></xsl:message>
                          <xsl:variable name="instanceXML" as="element()" select="xforms:instance($instance-id)"/>
                          <xsl:variable name="instanceDoc" as="document-node()">
                              <xsl:document>
                                  <xsl:sequence select="$instanceXML"/>
                              </xsl:document>
                          </xsl:variable>
                          <xsl:variable name="updatedNode" as="node()?" select="(xforms:evaluate-xpath-with-context-node($targetref,$instanceXML,()))[1]"/>
                          <xsl:variable name="updatedInstanceXML" as="element()">
                              <xsl:choose>
                                  <xsl:when test="exists($updatedNode) and $instanceDoc//node()[. is $updatedNode]">
                                      <xsl:apply-templates select="$instanceDoc" mode="recalculate">
                                          <xsl:with-param name="updated-nodes" select="$updatedNode" tunnel="yes"/>
                                          <xsl:with-param name="updated-value" select="string($response)" tunnel="yes"/>
                                      </xsl:apply-templates>
                                  </xsl:when>
                                  <xsl:when test="exists($updatedNode)">
                                      <xsl:apply-templates select="$instanceXML" mode="recalculate">
                                          <xsl:with-param name="updated-nodes" select="$updatedNode" tunnel="yes"/>
                                          <xsl:with-param name="updated-value" select="string($response)" tunnel="yes"/>
                                      </xsl:apply-templates>
                                  </xsl:when>
                                  <xsl:otherwise>
                                      <xsl:sequence select="$instanceXML"/>
                                  </xsl:otherwise>
                              </xsl:choose>
                          </xsl:variable>
                          
                          <!--        <xsl:message use-when="$debugMode">[xforms-value-changed] Updated XML: <xsl:sequence select="serialize($updatedInstanceXML)"/></xsl:message>-->
                          
                          <xsl:sequence select="js:setInstance($instance-id,$updatedInstanceXML)"/>
                          <xsl:sequence select="js:addDirtyInstance($instance-id)"/>
                          <xsl:sequence select="js:setDeferredUpdateFlags(('recalculate','revalidate','refresh'))"/>

                      </xsl:when>
                      <!-- TO DO: replace node or text within instance; replace entire page -->
                      <xsl:otherwise>
                          <xsl:message use-when="$debugMode">[HTTPsubmit] response = <xsl:sequence select="serialize($response)"/></xsl:message>
                       </xsl:otherwise>
                  </xsl:choose>
                  <xsl:if test="exists($submission-id-normalized)">
                      <xsl:sequence select="js:clearSubmissionInProgress($submission-id-normalized)"/>
                  </xsl:if>
                  <xsl:variable name="submit-done-context" as="map(*)">
                      <xsl:map>
                          <xsl:if test="exists($submission-id-normalized)">
                              <xsl:map-entry key="'targetid'" select="$submission-id-normalized"/>
                          </xsl:if>
                          <xsl:if test="exists($response-status)">
                              <xsl:map-entry key="'response-status-code'" select="string($response-status)"/>
                          </xsl:if>
                          <xsl:if test="exists($response-message) and normalize-space(string($response-message)) != ''">
                              <xsl:map-entry key="'response-reason-phrase'" select="string($response-message)"/>
                          </xsl:if>
                          <xsl:if test="exists($response-headers-nodes)">
                              <xsl:map-entry key="'response-headers'" select="$response-headers-nodes"/>
                          </xsl:if>
                      </xsl:map>
                  </xsl:variable>
                  <xsl:call-template name="xforms-event-handler">
                      <xsl:with-param name="event-name" select="'xforms-submit-done'" as="xs:string" tunnel="yes"/>
                      <xsl:with-param name="event-context" select="$submit-done-context" as="map(*)" tunnel="yes"/>
                  </xsl:call-template>
                  <!-- Ensure submission-driven deferred updates are processed even when no explicit
                       xforms-submit-done actions are registered. -->
                  <xsl:call-template name="outermost-action-handler"/>
                  
              </xsl:otherwise>
          </xsl:choose>
      </xsl:template>


    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Send server error message to console log</xd:p>
        </xd:desc>
        <xd:param name="responseMap">HTTP response map, per <a href="http://www.saxonica.com/saxon-js/documentation/index.html#!development/http">Saxon HTTP client</a></xd:param>
    </xd:doc>
    <xsl:template name="serverError">
        <xsl:param name="responseMap" as="map(*)"/>
        <xsl:message>Server side error HTTP response - <xsl:value-of select="concat($responseMap?status, ' ', $responseMap?message)"/></xsl:message>
    </xsl:template>


    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Pass through xforms:form when rendering.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template match="xforms:xform">
        <!-- TEST-TRACE: avoid re-processing xforms:model during render; model actions are
             already registered in xformsjs-main, and double-registration replays xforms-ready
             inserts (e.g. Appendix B.8 Copy Nodeset). -->
        <xsl:apply-templates select="node()[not(self::xforms:model)]"/>
    </xsl:template>

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Ignore xforms:model when rendering, except for setting actions defined there.</xd:p>
            <xd:p>Its instances, bindings, submissions are registered separately in the "xformsjs-main" template.</xd:p>
        </xd:desc>
        <xd:param name="model-key">ID of context model (xforms:model/@id value or default value).</xd:param>
    </xd:doc>
    <xsl:template match="xforms:model">
        <xsl:param name="model-key" as="xs:string" required="no" select="$global-default-model-id" tunnel="yes"/>

        <xsl:message use-when="$debugMode">[xforms:model] START</xsl:message>
        
        <xsl:variable name="model-ref" as="xs:string" select="if (exists(@id)) then string(@id) else $model-key"/>
        
        <xsl:variable name="actions" as="map(*)*">
            <xsl:apply-templates select="xforms:action | xforms:*[local-name() = $xforms-actions]" mode="set-action">
                <xsl:with-param name="model-key" select="$model-ref" tunnel="yes"/>
            </xsl:apply-templates>
        </xsl:variable>
        
        <xsl:if test="exists($actions)">
            <xsl:sequence select="js:addAction($model-ref, $actions)" />
            <xsl:message use-when="$debugMode">[xforms:model] actions within model have been set</xsl:message>
        </xsl:if>
        <xsl:if test="exists(@*:event)">
            <xsl:variable name="model-default-instance-id" as="xs:string"
                select="(xforms:get-model-instance-ids($model-ref), xforms:get-model-implicit-default-instance-id($model-ref))[1]"/>
            <xsl:variable name="model-event-action" as="map(*)">
                <xsl:map>
                    <xsl:map-entry key="'name'" select="'action'"/>
                    <xsl:map-entry key="'handler-status'" select="'inner'"/>
                    <xsl:map-entry key="'instance-context'" select="$model-default-instance-id"/>
                    <xsl:map-entry key="'@event'" select="string(@*:event)"/>
                    <xsl:if test="exists(@id)">
                        <xsl:map-entry key="'@observer'" select="string(@id)"/>
                    </xsl:if>
                    <xsl:if test="exists(@*:defaultAction)">
                        <xsl:map-entry key="'@defaultAction'" select="string(@*:defaultAction)"/>
                    </xsl:if>
                </xsl:map>
            </xsl:variable>
            <xsl:variable name="event-actions" as="map(*)*" select="js:getEventAction(string(@*:event))"/>
            <xsl:sequence select="js:addEventAction(string(@*:event), ($event-actions, $model-event-action))"/>
        </xsl:if>
        
        <xsl:message use-when="$debugMode">[xforms:model] END</xsl:message>
        
    </xsl:template>

    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for XForms root element (xforms:xform).</xd:p>
            <xd:p>Passes XForm to xformsjs-main template</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template match="/">
        <xsl:message use-when="$debugMode">[document node] Root element of <xsl:sequence select="base-uri()"/> is <xsl:sequence select="name(*)"/></xsl:message>
        <xsl:call-template name="xformsjs-main" >
            <xsl:with-param name="xFormsId" select="$xform-html-id" />
        </xsl:call-template>
    </xsl:template>
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Identify context instance, nodeset, and bindings for <xd:a href="https://www.w3.org/TR/xforms11/#controls">XForm controls</xd:a>.</xd:p>
        </xd:desc>
        <xd:param name="model-key">ID of context model (xforms:model/@id value or default value).</xd:param>
        <xd:param name="nodeset">An XPath binding expression. Stored in Javascript variable to support recalculation of repeats.</xd:param>
        <xd:param name="position">Integer representing position of item (in a repeat list for example).</xd:param>
        <xd:param name="context-position">String representing position of item in a hierarchy (e.g. in nested repeat)</xd:param>
    </xd:doc>
    <xsl:template match="xforms:*[local-name() = $xforms-controls] | xforms:group | xforms:case ">
        <xsl:param name="model-key" as="xs:string" required="no" select="$global-default-model-id" tunnel="yes"/>        
        <xsl:param name="nodeset" as="xs:string" required="no" select="''" tunnel="yes"/>
        <xsl:param name="position" as="xs:integer" required="no" select="0"/>
        <xsl:param name="context-position" as="xs:string" required="no" select="''"/>
        <xsl:param name="bindings-js" as="element(xforms:bind)*" required="no" select="()" tunnel="yes"/>
        
        <xsl:variable name="log-label" as="xs:string" select="concat('[',name(),' match template]')"/>
        <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> START</xsl:message>
        
        <xsl:variable name="time-id" as="xs:string" select="concat('XForms ', local-name(), ' ', generate-id())"/>
        <xsl:sequence use-when="$debugTiming" select="js:startTime($time-id)" />
        
        <xsl:variable name="string-position" as="xs:string" select="if ($context-position != '') then $context-position else string($position)"/>
        <xsl:variable name="myid" as="xs:string" select="
            if (exists(@id)) 
            then concat(@id, '-', $string-position)
            else concat( generate-id(), '-', $string-position )"/>
        
       
        <xsl:variable name="properties" as="map(*)">
            <xsl:apply-templates select="." mode="get-properties"/>
        </xsl:variable>
        
        <xsl:variable name="refi" as="xs:string" select="map:get($properties,'nodeset')"/>
        <xsl:variable name="this-instance-id" as="xs:string" select="map:get($properties,'instance-context')"/>
        <xsl:variable name="model-ref" as="xs:string" select="map:get($properties,'model-id')"/>
        <xsl:variable name="bindingi" as="element(xforms:bind)?" select="map:get($properties,'binding')"/>
        
        <xsl:if test="xforms:usesIndexFunction(.) and not(ancestor::*[xforms:usesIndexFunction(.)])">
            <xsl:sequence select="js:setElementUsingIndexFunction($myid,.)"/>
            <xsl:sequence select="js:setElementContextUsingIndexFunction($myid,$refi)"/>
        </xsl:if>
        
        
        <!--<xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> $refi = <xsl:sequence select="$refi"/></xsl:message>-->
        
        <!-- set actions relevant to this -->
        <xsl:variable name="time-id-set-actions" as="xs:string" select="concat('XForms ', local-name(), ' set actions ', generate-id())"/>
        <xsl:sequence use-when="$debugTiming" select="js:startTime($time-id-set-actions)" />
        
        <xsl:variable name="actions" as="map(*)*">
            <xsl:apply-templates select="." mode="set-actions">
                <xsl:with-param name="model-key" select="$model-ref" tunnel="yes"/>
                <xsl:with-param name="instance-key" select="$this-instance-id" tunnel="yes"/>
                <xsl:with-param name="nodeset" select="$refi" tunnel="yes"/>
                <xsl:with-param name="properties" select="$properties" tunnel="yes"/>
            </xsl:apply-templates>
        </xsl:variable>
        <xsl:sequence use-when="$debugTiming" select="js:endTime($time-id-set-actions)" />
        
        <xsl:if test="exists($actions)">
            <xsl:sequence select="js:addAction($myid, $actions)" />
        </xsl:if>
        
        <xsl:apply-templates select="." mode="get-html">
            <xsl:with-param name="id" as="xs:string" select="$myid" tunnel="yes"/>
            <xsl:with-param name="model-key" select="$model-ref" tunnel="yes"/>
            <xsl:with-param name="nodeset" as="xs:string" select="$refi" tunnel="yes"/>
            <xsl:with-param name="context-nodeset" as="xs:string" select="$nodeset" tunnel="yes"/>
            <xsl:with-param name="instance-context" as="xs:string" select="$this-instance-id" tunnel="yes"/>
            <xsl:with-param name="binding" as="element(xforms:bind)*" select="$bindingi" tunnel="yes"/>
            <xsl:with-param name="actions" as="map(*)*" select="$actions"/>
        </xsl:apply-templates>
        
        <xsl:sequence use-when="$debugTiming" select="js:endTime($time-id)" />
        <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> END</xsl:message>
    </xsl:template>
    


    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of XForms <a href="https://www.w3.org/TR/xforms11/#ui-output">output element</a>  </xd:p>          
            <xd:p>Generates HTML output field and registers actions.</xd:p>
        </xd:desc>
        <xd:param name="id">ID of HTML element.</xd:param>
        <xd:param name="nodeset">XPath binding expression</xd:param>
        <xd:param name="context-nodeset">XPath binding expression for context node (used if @value contains context() function)</xd:param>
        <xd:param name="instance-context">ID of XForms instance relevant to this control</xd:param>
        <xd:param name="binding">xforms:bind elements relevant to this control</xd:param>
    </xd:doc>
    <xsl:template match="xforms:output" mode="get-html">
        <xsl:param name="id" as="xs:string" tunnel="yes"/>
        <xsl:param name="nodeset" as="xs:string" tunnel="yes"/>
        <xsl:param name="context-nodeset" as="xs:string" tunnel="yes"/>
        <xsl:param name="instance-context" as="xs:string" tunnel="yes"/>
        <xsl:param name="binding" as="element(xforms:bind)*" tunnel="yes"/>
        
        <xsl:variable name="log-label" as="xs:string" select="concat('[',name(),' get-html mode]')"/>
        <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> START</xsl:message>
        
        <!--<xsl:variable name="instanceXML" as="element()" select="xforms:instance($instance-context)"/>   
        <xsl:variable name="instanceDoc" as="document-node()">
            <xsl:document>
                <xsl:sequence select="$instanceXML"/>
            </xsl:document>
        </xsl:variable>-->
        
        
        <xsl:variable name="time-id-instance-field" as="xs:string" select="concat('XForms ', local-name(), ' get instance field ', generate-id())"/>
        <xsl:sequence use-when="$debugTiming" select="js:startTime($time-id-instance-field)" />
        <xsl:variable name="instanceField" as="node()?">
            <xsl:choose>
                <!-- 
                    Override default instance if @value specifies an instance,
                    BUT NOT when inside a repeat ($nodeset != '') because
                    current() needs the repeat item as context.
                -->
                <!-- TEST-TRACE: skip instance() shortcut inside repeats so current()
                     resolves to the repeat item; helps tests/w3c/ch07.spec.ts "7.10.2.b" -->
                <xsl:when test="starts-with(@value,'instance(') and $nodeset = ''">
                    <xsl:sequence select="xforms:evaluate-xpath-with-instance-id(@value,xforms:getInstanceId(string(@value)),())[1]"/>
                </xsl:when>
                <xsl:when test="$nodeset != ''">
                    <xsl:sequence select="xforms:evaluate-xpath-with-instance-id($nodeset,$instance-context,())[1]"/>
                </xsl:when>
                <xsl:otherwise/>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:sequence use-when="$debugTiming" select="js:endTime($time-id-instance-field)" />
        
        
        <xsl:variable name="time-id-get-value" as="xs:string" select="concat('XForms ', local-name(), ' get value ', generate-id())"/>
        <xsl:sequence use-when="$debugTiming" select="js:startTime($time-id-get-value)" />
        
        <xsl:variable name="valueExecuted" as="xs:string">
            <xsl:choose>
                <!-- TEST-TRACE: try/catch guards XPath 3.1 type errors on calculate;
                     also substitutes position()/last() with actual values;
                     helps tests/w3c/ch06.spec.ts "6.1.5.a", tests/w3c/ch07.spec.ts "7.2.e" -->
                <xsl:when test="exists($binding/@calculate) and exists($instanceField)">
                    <xsl:variable name="__init-calc" as="xs:string" select="string($binding/@calculate)"/>
                    <xsl:variable name="__init-calc-fixed" as="xs:string">
                        <xsl:choose>
                            <xsl:when test="contains($__init-calc, 'position()') or contains($__init-calc, 'last()')">
                                <xsl:variable name="__bind-nodes" as="node()*">
                                    <xsl:try>
                                        <xsl:variable name="__inst" select="xforms:instance($instance-context)"/>
                                        <xsl:evaluate xpath="xforms:impose(string($binding/@nodeset))" context-item="$__inst" namespace-context="$__inst"/>
                                        <xsl:catch/>
                                    </xsl:try>
                                </xsl:variable>
                                <xsl:variable name="__pos" as="xs:integer" select="
                                    (for $i in 1 to count($__bind-nodes) return
                                        if ($__bind-nodes[$i] is $instanceField) then $i else ()
                                    , 1)[1]"/>
                                <xsl:sequence select="replace(replace($__init-calc,
                                    'last\s*\(\s*\)', string(count($__bind-nodes))),
                                    'position\s*\(\s*\)', string($__pos))"/>
                            </xsl:when>
                            <xsl:otherwise><xsl:sequence select="$__init-calc"/></xsl:otherwise>
                        </xsl:choose>
                    </xsl:variable>
                    <xsl:try>
                        <xsl:sequence select="xforms:evaluate-xpath-with-context-node('string(' || $__init-calc-fixed || ')',$instanceField,())"/>
                        <xsl:catch><xsl:sequence select="''"/></xsl:catch>
                    </xsl:try>
                </xsl:when>
                <!-- 
                    XForms 1.1 §8.1.5: When @bind is present, the single-node
                    binding takes precedence over @value for determining the
                    displayed value.  Use the bound node's string value directly.
                -->
                <xsl:when test="exists(@bind) and exists($instanceField)">
                    <xsl:value-of select="$instanceField"/>
                </xsl:when>
                <xsl:when test="exists(@value) and exists($instanceField)">
                    <xsl:sequence select="xforms:evaluate-xpath-with-context-node('string(' || xforms:resolveContext(@value,$context-nodeset) || ')',$instanceField,())"/>
                </xsl:when>
                <xsl:when test="exists(@value) and $nodeset = ''">
                    <!-- No instance binding, but @value may be a literal expression (e.g. arithmetic) -->
                    <xsl:variable name="instanceXML" as="element()?" select="xforms:instance($instance-context)"/>
                    <xsl:choose>
                        <xsl:when test="exists($instanceXML)">
                            <xsl:sequence select="xforms:evaluate-xpath-with-context-node('string(' || xforms:resolveContext(@value,$context-nodeset) || ')',$instanceXML,())"/>
                        </xsl:when>
                        <xsl:otherwise><xsl:sequence select="''"/></xsl:otherwise>
                    </xsl:choose>
                </xsl:when>
                <xsl:when test="exists($instanceField)">
                    <xsl:value-of select="$instanceField"/>
                </xsl:when>
                <xsl:otherwise><xsl:sequence select="''"/></xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:sequence use-when="$debugTiming" select="js:endTime($time-id-get-value)" />
        
        <xsl:variable name="time-id-get-relevant" as="xs:string" select="concat('XForms ', local-name(), ' get relevant status ', generate-id())"/>
        <xsl:sequence use-when="$debugTiming" select="js:startTime($time-id-get-relevant)" />
        
        <xsl:variable name="relevantStatus" as="xs:boolean">
            <xsl:call-template name="getRelevantStatus">
                <xsl:with-param name="xformsControl" as="element()" select="."/>
                <xsl:with-param name="instanceField" as="node()?" select="$instanceField"/>
            </xsl:call-template>
        </xsl:variable>
        
        <xsl:variable name="additional-class-values" as="xs:string+" select="('xforms-output')"/>
       
        <xsl:variable name="htmlClass" as="xs:string">
            <xsl:call-template name="getHtmlClass">
                <xsl:with-param name="source-class" as="xs:string?" select="@class"/>
                <xsl:with-param name="additional-values" as="xs:string*" select="$additional-class-values"/>
                <xsl:with-param name="incremental" as="xs:string?" select="@incremental"/>
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="hint-text" as="xs:string" select="normalize-space(string-join(xforms:hint/text(), ' '))"/>
        <xsl:variable name="hint-id" as="xs:string" select="concat($id, '-hint')"/>
        <xsl:sequence use-when="$debugTiming" select="js:endTime($time-id-get-relevant)" />
        
       
        <!-- GENERATE HTML -->
        <xsl:variable name="time-id-get-html" as="xs:string" select="concat('XForms ', local-name(), ' get HTML ', generate-id())"/>
        <xsl:sequence use-when="$debugTiming" select="js:startTime($time-id-get-html)" />
        <span>    
            <xsl:call-template name="copy-custom-data-attributes"/>
            <xsl:attribute name="style" select="if($relevantStatus) then 'display:inline' else 'display:none'" />
            <xsl:apply-templates select="xforms:label"/>            
            <span>
                <xsl:attribute name="id" select="$id"/>
                <xsl:attribute name="class" select="$htmlClass"/>
                <xsl:attribute name="instance-context" select="$instance-context"/>
                <xsl:attribute name="data-ref" select="$nodeset"/>
                <xsl:if test="exists(@value)">
                    <xsl:attribute name="data-value" select="xforms:resolveContext(@value,$context-nodeset)"/>
                </xsl:if>
                <xsl:if test="exists($binding) and exists($binding/@relevant)">
                    <xsl:attribute name="data-relevant" select="$binding/@relevant"/>
                </xsl:if>
               
                <xsl:sequence select="$valueExecuted" />
            </span>
        </span>
        <xsl:sequence use-when="$debugTiming" select="js:endTime($time-id-get-html)" />
        
        <!-- register outputs (except those inside a repeat) -->
        <xsl:variable name="time-id-register-outputs" as="xs:string" select="concat('XForms ', local-name(), ' get relevant status ', generate-id())"/>
        
        <xsl:call-template name="registerOutput">
            <xsl:with-param name="additional-class-values" select="$additional-class-values"/>
        </xsl:call-template>
               
        <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> END</xsl:message>
    </xsl:template>

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of XForms <a href="https://www.w3.org/TR/xforms11/#ui-upload">upload element</a></xd:p>
            <xd:p>Generates HTML file input. File content is read via the readFileAsXML JS helper and set as instance data.</xd:p>
        </xd:desc>
        <xd:param name="id">ID of HTML element.</xd:param>
        <xd:param name="nodeset">XPath binding expression</xd:param>
        <xd:param name="instance-context">ID of XForms instance relevant to this control</xd:param>
        <xd:param name="actions">Map(s) of actions relevant to this control</xd:param>
    </xd:doc>
    <xsl:template match="xforms:upload" mode="get-html">
        <xsl:param name="id" as="xs:string" tunnel="yes"/>
        <xsl:param name="nodeset" as="xs:string" tunnel="yes"/>
        <xsl:param name="instance-context" as="xs:string" tunnel="yes"/>
        <xsl:param name="actions" as="map(*)*"/>
        
        <xsl:message use-when="$debugMode">[xforms:upload get-html] START (instance: <xsl:value-of select="$instance-context"/>, ref: <xsl:value-of select="$nodeset"/>)</xsl:message>
        
        <xsl:variable name="additional-class-values" as="xs:string+" select="('xforms-upload')"/>
        <xsl:variable name="htmlClass" as="xs:string">
            <xsl:call-template name="getHtmlClass">
                <xsl:with-param name="source-class" as="xs:string?" select="@class"/>
                <xsl:with-param name="additional-values" as="xs:string*" select="$additional-class-values"/>
                <xsl:with-param name="incremental" as="xs:string?" select="@incremental"/>
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="hint-text" as="xs:string" select="normalize-space(string-join(xforms:hint/text(), ' '))"/>
        <xsl:variable name="hint-id" as="xs:string" select="concat($id, '-hint')"/>
        
        <div>
            <xsl:call-template name="copy-custom-data-attributes"/>
            <xsl:attribute name="class" select="$htmlClass"/>
            <xsl:apply-templates select="xforms:label"/>
            <input type="file">
                <xsl:attribute name="id" select="$id"/>
                <xsl:attribute name="data-ref" select="$nodeset"/>
                <xsl:attribute name="instance-context" select="$instance-context"/>
                <xsl:if test="exists(@accept)">
                    <xsl:attribute name="accept" select="string(@accept)"/>
                </xsl:if>
                <xsl:if test="exists(@mediatype)">
                    <xsl:attribute name="data-mediatype" select="string(@mediatype)"/>
                </xsl:if>
                <xsl:if test="exists($actions)">
                    <xsl:attribute name="data-action" select="$id"/>
                </xsl:if>
                <xsl:if test="$hint-text ne ''">
                    <xsl:attribute name="title" select="$hint-text"/>
                    <xsl:attribute name="aria-describedby" select="$hint-id"/>
                </xsl:if>
            </input>
            <xsl:call-template name="render-control-hint">
                <xsl:with-param name="hint-id" select="$hint-id"/>
                <xsl:with-param name="hint-text" select="$hint-text"/>
            </xsl:call-template>
        </div>
        
        <xsl:message use-when="$debugMode">[xforms:upload get-html] END</xsl:message>
    </xsl:template>

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of XForms <a href="https://www.w3.org/TR/xforms11/#ui-input">input element</a></xd:p>
            <xd:p>Generates HTML input field and registers actions.</xd:p>
        </xd:desc>
        <xd:param name="id">ID of HTML element.</xd:param>
        <xd:param name="nodeset">XPath binding expression</xd:param>
        <xd:param name="instance-context">ID of XForms instance relevant to this control</xd:param>
        <xd:param name="binding">xforms:bind elements relevant to this control</xd:param>
        <xd:param name="actions">Map(s) of actions relevant to this control</xd:param>
    </xd:doc>
    <xsl:template match="xforms:input" mode="get-html">
        <xsl:param name="id" as="xs:string" tunnel="yes"/>
        <xsl:param name="nodeset" as="xs:string" tunnel="yes"/>
        <xsl:param name="instance-context" as="xs:string" tunnel="yes"/>
        <xsl:param name="binding" as="element(xforms:bind)*" tunnel="yes"/>
        <xsl:param name="actions" as="map(*)*"/>
               
        <xsl:message use-when="$debugMode">[xforms:input in get-html mode] nodeset: <xsl:sequence select="$nodeset"/></xsl:message>
        
        <!-- TEST-TRACE: [1] applies XForms first-node rule for duplicate siblings;
             helps tests/w3c/ch03.spec.ts "3.2.3.g" -->
        <xsl:variable name="instanceField" as="node()?" select="xforms:evaluate-xpath-with-instance-id($nodeset,$instance-context,())[1]"/>                   
        <xsl:variable name="relevantStatus" as="xs:boolean">
            <xsl:call-template name="getRelevantStatus">
                <xsl:with-param name="xformsControl" as="element()" select="."/>
                <xsl:with-param name="instanceField" as="node()?" select="$instanceField"/>
            </xsl:call-template>
        </xsl:variable>
        
        <xsl:variable name="additional-class-values" as="xs:string+" select="('xforms-input')"/>
        
        <xsl:variable name="htmlClass" as="xs:string">
            <xsl:call-template name="getHtmlClass">
                <xsl:with-param name="source-class" as="xs:string?" select="@class"/>
                <xsl:with-param name="additional-values" as="xs:string*" select="$additional-class-values"/>
                <xsl:with-param name="incremental" as="xs:string?" select="@incremental"/>
            </xsl:call-template>
        </xsl:variable>
        
             
        <div>
            <xsl:call-template name="copy-custom-data-attributes"/>
            <xsl:attribute name="class" select="$htmlClass"/>
            <xsl:if test="not($relevantStatus)">
                <xsl:attribute name="style" select="'display:none'"/>
            </xsl:if>
            <xsl:apply-templates select="xforms:label"/>
            
            <xsl:variable name="hint-text" as="xs:string" select="normalize-space(string-join(xforms:hint/text(), ' '))"/>
            <xsl:variable name="hint-id" as="xs:string" select="concat($id, '-hint')"/>
            
            <input>
                <xsl:attribute name="id" select="$id"/>
                <xsl:attribute name="class" select="$htmlClass"/>
                <xsl:attribute name="instance-context" select="$instance-context"/>
                <xsl:attribute name="data-ref" select="$nodeset"/>
                <!-- TEST-TRACE: map xf:input @navindex/@accesskey to native focus attrs; helps tests/w3c/ch08.spec.ts "8.1.a" -->
                <xsl:if test="exists(@navindex) and normalize-space(string(@navindex)) ne ''">
                    <xsl:attribute name="tabindex" select="string(@navindex)"/>
                </xsl:if>
                <xsl:if test="exists(@accesskey) and normalize-space(string(@accesskey)) ne ''">
                    <xsl:attribute name="accesskey" select="string(@accesskey)"/>
                </xsl:if>
               
                <xsl:if test="exists($binding) and exists($binding/@constraint)">
                    <xsl:attribute name="data-constraint" select="$binding/@constraint"/>
                </xsl:if>
                <xsl:if test="exists($binding) and exists($binding/@relevant)">
                    <xsl:attribute name="data-relevant" select="$binding/@relevant"/>
                </xsl:if>
                <xsl:if test="exists($binding) and exists($binding/@required)">
                    <xsl:attribute name="data-required" select="$binding/@required"/>
                </xsl:if>
                <!-- TEST-TRACE: propagate readonly MIP (direct or inherited) to HTML input;
                     XForms §6.1.2: ancestor readonly="true()" overrides any child readonly;
                     helps tests/w3c/ch06.spec.ts "6.1.2.a", "6.1.2.b" -->
                <xsl:if test="exists($instanceField) and $instanceField[self::* or self::text() or self::attribute()]">
                    <xsl:variable name="all-bindings-ro" as="element(xforms:bind)*" select="js:getBindings()"/>
                    <xsl:variable name="ns-ctx-ro" as="node()" select="
                        if ($instanceField[self::attribute() or self::text()])
                        then ($instanceField/parent::*, /*)[1]
                        else $instanceField"/>
                    <xsl:variable name="instance-root-ro" as="element()" select="root($instanceField)"/>
                    <!-- Walk ancestor-or-self to find any readonly binding (ancestor wins per spec) -->
                    <xsl:variable name="readonly-status" as="xs:boolean">
                        <xsl:iterate select="reverse($instanceField/ancestor-or-self::*)">
                            <xsl:param name="found" as="xs:boolean" select="false()"/>
                            <xsl:on-completion select="$found"/>
                            <xsl:variable name="anc" as="element()" select="."/>
                            <xsl:variable name="ro-bind" as="element(xforms:bind)?" select="
                                ($all-bindings-ro[exists(@readonly)][
                                    let $bn := xforms:impose(string(@nodeset))
                                    return (some $n in xforms:evaluate-xpath-with-context-node($bn, $instance-root-ro, ())
                                            satisfies $n is $anc)
                                ])[1]"/>
                            <xsl:choose>
                                <xsl:when test="exists($ro-bind)">
                                    <xsl:variable name="ro-val" as="xs:boolean">
                                        <xsl:try>
                                            <xsl:evaluate xpath="xforms:impose($ro-bind/@readonly)" context-item="$anc" namespace-context="$ns-ctx-ro"/>
                                            <xsl:catch><xsl:sequence select="false()"/></xsl:catch>
                                        </xsl:try>
                                    </xsl:variable>
                                    <xsl:choose>
                                        <!-- Ancestor readonly=true wins unconditionally -->
                                        <xsl:when test="$ro-val"><xsl:break select="true()"/></xsl:when>
                                        <xsl:otherwise><xsl:next-iteration><xsl:with-param name="found" select="$found"/></xsl:next-iteration></xsl:otherwise>
                                    </xsl:choose>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:next-iteration><xsl:with-param name="found" select="$found"/></xsl:next-iteration>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:iterate>
                    </xsl:variable>
                    <xsl:if test="$readonly-status">
                        <xsl:attribute name="data-readonly" select="'true'"/>
                    </xsl:if>
                </xsl:if>
                <!--
                    Persist bind @type on the rendered control so submit-time validation
                    can enforce typed binds even when no explicit @constraint exists.
                -->
                <xsl:if test="exists($binding[@type])">
                    <xsl:attribute name="data-binding-type" select="string(($binding[@type][1]/@type)[1])"/>
                </xsl:if>
                
                <xsl:if test="exists($actions)">
                    <xsl:attribute name="data-action" select="$id"/>
                </xsl:if>
                
                <xsl:if test="$hint-text ne ''">
                    <xsl:attribute name="title" select="$hint-text"/>
                    <xsl:attribute name="aria-describedby" select="$hint-id"/>
                </xsl:if>
                
                <xsl:attribute name="size" select="if (exists(@size)) then @size else '50'"/>
                                
                <xsl:variable name="input-value" as="xs:string">
                    <xsl:choose>
                        <xsl:when test="exists($instanceField)">
                            <xsl:value-of select="$instanceField"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:sequence select="''"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <xsl:variable name="binding-type" as="xs:string" select="if (exists($binding) and exists($binding/@type)) then lower-case(normalize-space(string($binding/@type))) else ''"/>
                
                <xsl:variable name="input-type" as="xs:string">
                    <xsl:choose>
                        <xsl:when test="$binding-type = ('xs:date','xsd:date')">
                            <xsl:sequence select="'date'"/>
                        </xsl:when>
                        <xsl:when test="$binding-type = ('xs:time','xsd:time')">
                            <xsl:sequence select="'time'"/>
                        </xsl:when>
                        <xsl:when test="$binding-type = ('xs:boolean','xsd:boolean')">
                            <xsl:sequence select="'checkbox'"/>
                        </xsl:when>
                        
                        <xsl:otherwise>
                            <xsl:sequence select="'text'"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                
                <xsl:attribute name="data-type" select="$input-type"/>
                <xsl:attribute name="type" select="$input-type"/>
                
                <xsl:choose>
                    <xsl:when test="$input-type eq 'date'">
                        <xsl:attribute name="value" select="$input-value"/>
                    </xsl:when>
                    <xsl:when test="$input-type eq 'time'">
                        <xsl:attribute name="value" select="$input-value"/>
                    </xsl:when>
                    <xsl:when test="$input-type eq 'checkbox'">
                        <xsl:if test="exists($instanceField)">
                            <xsl:if test="string-length($input-value) > 0 and xs:boolean($input-value)">
                                <xsl:attribute name="checked" select="$input-value"/>
                            </xsl:if>
                        </xsl:if>
                    </xsl:when>
                    
                    <xsl:otherwise>
                        <xsl:attribute name="value" select="$input-value"/>
                    </xsl:otherwise>
                </xsl:choose>
                
                
                <xsl:call-template name="registerOutput">
                    <xsl:with-param name="additional-class-values" select="$additional-class-values"/>
                    <xsl:with-param name="data-type" as="xs:string" select="$input-type"/>
                </xsl:call-template>
                
            </input>
            <xsl:call-template name="render-control-hint">
                <xsl:with-param name="hint-id" select="$hint-id"/>
                <xsl:with-param name="hint-text" select="$hint-text"/>
            </xsl:call-template>
        </div> 
        
        
        
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of XForms <a href="https://www.w3.org/TR/xforms11/#ui-range">range element</a></xd:p>
            <xd:p>Generates a native HTML5 range input and maps start/end/step attributes.</xd:p>
        </xd:desc>
        <xd:param name="id">ID of HTML element.</xd:param>
        <xd:param name="nodeset">XPath binding expression</xd:param>
        <xd:param name="instance-context">ID of XForms instance relevant to this control</xd:param>
        <xd:param name="binding">xforms:bind elements relevant to this control</xd:param>
        <xd:param name="actions">Map(s) of actions relevant to this control</xd:param>
    </xd:doc>
    <xsl:template match="xforms:range" mode="get-html">
        <xsl:param name="id" as="xs:string" tunnel="yes"/>
        <xsl:param name="nodeset" as="xs:string" tunnel="yes"/>
        <xsl:param name="instance-context" as="xs:string" tunnel="yes"/>
        <xsl:param name="binding" as="element(xforms:bind)*" tunnel="yes"/>
        <xsl:param name="actions" as="map(*)*"/>
        
        <!-- TEST-TRACE: render xf:range as native HTML5 slider with start/end/step wiring;
             helps tests/w3c/ch08.spec.ts "8.1.7.a", "8.1.7.b", "8.1.7.c", "8.1.7.d", "8.1.7.e" -->
        <xsl:variable name="instanceField" as="node()?" select="xforms:evaluate-xpath-with-instance-id($nodeset,$instance-context,())[1]"/>
        <xsl:variable name="relevantStatus" as="xs:boolean">
            <xsl:call-template name="getRelevantStatus">
                <xsl:with-param name="xformsControl" as="element()" select="."/>
                <xsl:with-param name="instanceField" as="node()?" select="$instanceField"/>
            </xsl:call-template>
        </xsl:variable>
        
        <xsl:variable name="additional-class-values" as="xs:string+" select="('xforms-range')"/>
        <xsl:variable name="htmlClass" as="xs:string">
            <xsl:call-template name="getHtmlClass">
                <xsl:with-param name="source-class" as="xs:string?" select="@class"/>
                <xsl:with-param name="additional-values" as="xs:string*" select="$additional-class-values"/>
                <xsl:with-param name="incremental" as="xs:string?" select="@incremental"/>
            </xsl:call-template>
        </xsl:variable>
        
        <xsl:variable name="hint-text" as="xs:string" select="normalize-space(string-join(xforms:hint/text(), ' '))"/>
        <xsl:variable name="hint-id" as="xs:string" select="concat($id, '-hint')"/>
        <xsl:variable name="range-value" as="xs:string" select="
            if (exists($instanceField))
            then string($instanceField)
            else (if (exists(@start)) then string(@start) else '0')"/>
        <xsl:variable name="range-min" as="xs:string?" select="
            if (exists(@start) and normalize-space(string(@start)) ne '')
            then string(@start)
            else ()"/>
        <xsl:variable name="range-max" as="xs:string?" select="
            if (exists(@end) and normalize-space(string(@end)) ne '')
            then string(@end)
            else (
                if (exists(@start) and normalize-space(string(@start)) ne '')
                then string(@start)
                else ()
            )"/>
        <xsl:variable name="range-step" as="xs:string?" select="
            if (exists(@step) and normalize-space(string(@step)) ne '')
            then string(@step)
            else ()"/>
        
        <div>
            <xsl:call-template name="copy-custom-data-attributes"/>
            <xsl:attribute name="class" select="$htmlClass"/>
            <xsl:if test="not($relevantStatus)">
                <xsl:attribute name="style" select="'display:none'"/>
            </xsl:if>
            <xsl:apply-templates select="xforms:label"/>
            <input type="range">
                <xsl:attribute name="id" select="$id"/>
                <xsl:attribute name="class" select="$htmlClass"/>
                <xsl:attribute name="instance-context" select="$instance-context"/>
                <xsl:attribute name="data-ref" select="$nodeset"/>
                
                <xsl:if test="exists($binding) and exists($binding/@constraint)">
                    <xsl:attribute name="data-constraint" select="$binding/@constraint"/>
                </xsl:if>
                <xsl:if test="exists($binding) and exists($binding/@relevant)">
                    <xsl:attribute name="data-relevant" select="$binding/@relevant"/>
                </xsl:if>
                <xsl:if test="exists($binding) and exists($binding/@required)">
                    <xsl:attribute name="data-required" select="$binding/@required"/>
                </xsl:if>
                <xsl:if test="exists($binding[@type])">
                    <xsl:attribute name="data-binding-type" select="string(($binding[@type][1]/@type)[1])"/>
                </xsl:if>
                <xsl:if test="exists($actions)">
                    <xsl:attribute name="data-action" select="$id"/>
                </xsl:if>
                <xsl:if test="$hint-text ne ''">
                    <xsl:attribute name="title" select="$hint-text"/>
                    <xsl:attribute name="aria-describedby" select="$hint-id"/>
                </xsl:if>
                <xsl:if test="exists($range-min)">
                    <xsl:attribute name="min" select="$range-min"/>
                </xsl:if>
                <xsl:if test="exists($range-max)">
                    <xsl:attribute name="max" select="$range-max"/>
                </xsl:if>
                <xsl:if test="exists($range-step)">
                    <xsl:attribute name="step" select="$range-step"/>
                </xsl:if>
                <xsl:attribute name="value" select="$range-value"/>
                
                <xsl:call-template name="registerOutput">
                    <xsl:with-param name="additional-class-values" select="$additional-class-values"/>
                    <xsl:with-param name="data-type" as="xs:string" select="'range'"/>
                </xsl:call-template>
            </input>
            <xsl:call-template name="render-control-hint">
                <xsl:with-param name="hint-id" select="$hint-id"/>
                <xsl:with-param name="hint-text" select="$hint-text"/>
            </xsl:call-template>
        </div>
    </xsl:template>
    

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of XForms <a href="https://www.w3.org/TR/xforms11/#ui-textarea">textarea element</a>  </xd:p>          
            <xd:p>Generates HTML output field and registers actions.</xd:p>
        </xd:desc>
        <xd:param name="id">ID of HTML element.</xd:param>
        <xd:param name="nodeset">XPath binding expression</xd:param>
        <xd:param name="instance-context">ID of XForms instance relevant to this control</xd:param>
        <xd:param name="binding">xforms:bind elements relevant to this control</xd:param>
        <xd:param name="actions">Map(s) of actions relevant to this control</xd:param>
    </xd:doc>
    <xsl:template match="xforms:textarea" mode="get-html">
        <xsl:param name="id" as="xs:string" tunnel="yes"/>
        <xsl:param name="nodeset" as="xs:string" tunnel="yes"/>
        <xsl:param name="instance-context" as="xs:string" tunnel="yes"/>
        <xsl:param name="binding" as="element(xforms:bind)*" tunnel="yes"/>
        <xsl:param name="actions" as="map(*)*"/>

        <!-- TEST-TRACE: [1] applies XForms first-node rule for duplicate siblings;
             helps tests/w3c/ch03.spec.ts "3.2.3.g" -->
        <xsl:variable name="instanceField" as="node()?" select="xforms:evaluate-xpath-with-instance-id($nodeset,$instance-context,())[1]"/>
        
        <xsl:variable name="relevantStatus" as="xs:boolean">
            <xsl:call-template name="getRelevantStatus">
                <xsl:with-param name="xformsControl" as="element()" select="."/>
                <xsl:with-param name="instanceField" as="node()?" select="$instanceField"/>
            </xsl:call-template>
        </xsl:variable>
        
        <xsl:variable name="additional-class-values" as="xs:string+" select="('xforms-textarea')"/>
        <xsl:variable name="htmlClass" as="xs:string">
            <xsl:call-template name="getHtmlClass">
                <xsl:with-param name="source-class" as="xs:string?" select="@class"/>
                <xsl:with-param name="additional-values" as="xs:string*" select="$additional-class-values"/>
                <xsl:with-param name="incremental" as="xs:string?" select="@incremental"/>
            </xsl:call-template>
        </xsl:variable>
        
        <xsl:variable name="hint-text" as="xs:string" select="normalize-space(string-join(xforms:hint/text(), ' '))"/>
        <xsl:variable name="hint-id" as="xs:string" select="concat($id, '-hint')"/>
        
        <div>
            <xsl:call-template name="copy-custom-data-attributes"/>
            <xsl:attribute name="class" select="$htmlClass"/>
            <xsl:if test="not($relevantStatus)">
                <xsl:attribute name="style" select="'display:none'"/>
            </xsl:if>
            <xsl:apply-templates select="xforms:label"/>
            <textarea>
                <xsl:attribute name="id" select="$id"/>
                <xsl:attribute name="class" select="$htmlClass"/>
                <xsl:attribute name="instance-context" select="$instance-context" />
                <xsl:attribute name="data-ref" select="$nodeset"/>
                
                <xsl:if test="exists($binding) and exists($binding/@constraint)">
                    <xsl:attribute name="data-constraint" select="$binding/@constraint"/>
                </xsl:if>
                <xsl:if test="exists($binding) and exists($binding/@relevant)">
                    <xsl:attribute name="data-relevant" select="$binding/@relevant"/>
                </xsl:if>
                <xsl:if test="exists($binding) and exists($binding/@required)">
                    <xsl:attribute name="data-required" select="$binding/@required"/>
                </xsl:if>
                <!-- Keep bind @type available for submit validation over textarea bindings. -->
                <xsl:if test="exists($binding[@type])">
                    <xsl:attribute name="data-binding-type" select="string(($binding[@type][1]/@type)[1])"/>
                </xsl:if>
                
                <xsl:if test="exists($actions)">
                    <xsl:attribute name="data-action" select="$id"/>
                </xsl:if>
                
                <xsl:if test="$hint-text ne ''">
                    <xsl:attribute name="title" select="$hint-text"/>
                    <xsl:attribute name="aria-describedby" select="$hint-id"/>
                </xsl:if>
                
                <xsl:if test="exists(@size)">
                    <xsl:attribute name="size" select="@size"/>
                </xsl:if>
                
                <xsl:choose>
                    <xsl:when test="exists($instanceField)">
                        <xsl:value-of select="$instanceField"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:sequence select="'&#xA0;'"/>
                    </xsl:otherwise>
                </xsl:choose>
            </textarea>       
            <xsl:call-template name="render-control-hint">
                <xsl:with-param name="hint-id" select="$hint-id"/>
                <xsl:with-param name="hint-text" select="$hint-text"/>
            </xsl:call-template>
        </div>
    </xsl:template>


    <xsl:template name="render-control-hint">
        <xsl:param name="hint-id" as="xs:string"/>
        <xsl:param name="hint-text" as="xs:string"/>
        <xsl:if test="$hint-text ne ''">
            <div class="xforms-hint" id="{$hint-id}">
                <xsl:value-of select="$hint-text"/>
            </div>
        </xsl:if>
    </xsl:template>
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Ignore xforms:hint when rendering the XForm into HTML.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template match="xforms:hint"/>

    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of XForms <a href="https://www.w3.org/TR/xforms11/#ui-selectMany">select</a> and <a href="https://www.w3.org/TR/xforms11/#ui-selectOne">select1</a> elements</xd:p>          
            <xd:p>Generates HTML select field and registers actions.</xd:p>
        </xd:desc>
        <xd:param name="id">ID of HTML element.</xd:param>
        <xd:param name="nodeset">XPath binding expression</xd:param>
        <xd:param name="instance-context">ID of XForms instance relevant to this control</xd:param>
        <xd:param name="binding">xforms:bind elements relevant to this control</xd:param>
        <xd:param name="actions">Map(s) of actions relevant to this control</xd:param>
    </xd:doc>
    <xsl:template match="xforms:select1 | xforms:select" mode="get-html">
        <xsl:param name="id" as="xs:string" tunnel="yes"/>
        <xsl:param name="nodeset" as="xs:string" tunnel="yes"/>
        <xsl:param name="instance-context" as="xs:string" tunnel="yes"/>
        <xsl:param name="binding" as="element(xforms:bind)*" tunnel="yes"/>
        <xsl:param name="actions" as="map(*)*"/>
        
        <!-- TEST-TRACE: [1] applies XForms first-node rule for duplicate siblings;
             helps tests/w3c/ch03.spec.ts "3.2.3.g" -->
        <xsl:variable name="instanceField" as="node()?" select="xforms:evaluate-xpath-with-instance-id($nodeset,$instance-context,())[1]"/>                
        
        <xsl:variable name="selectedValue" as="xs:string">
            <xsl:choose>
                <xsl:when test="exists($instanceField)">
                    <xsl:value-of select="$instanceField"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="''"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:variable name="relevantStatus" as="xs:boolean">
            <xsl:call-template name="getRelevantStatus">
                <xsl:with-param name="xformsControl" as="element()" select="."/>
                <xsl:with-param name="instanceField" as="node()?" select="$instanceField"/>
            </xsl:call-template>
        </xsl:variable>
        
        <xsl:variable name="additional-class-values" as="xs:string+" select="('xforms-select')"/>
        
        <xsl:variable name="htmlClass" as="xs:string">
            <xsl:call-template name="getHtmlClass">
                <xsl:with-param name="source-class" as="xs:string?" select="@class"/>
                <xsl:with-param name="additional-values" as="xs:string*" select="$additional-class-values"/>
                <xsl:with-param name="incremental" as="xs:string?" select="@incremental"/>
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="appearance-requested-raw" as="xs:string" select="lower-case(normalize-space(string(@appearance)))"/>
        <xsl:variable name="appearance-requested" as="xs:string" select="
            if ($appearance-requested-raw = ('full','compact','minimal'))
            then $appearance-requested-raw
            else (if (local-name() = 'select') then 'full' else 'minimal')"/>
        <xsl:variable name="appearance-effective" as="xs:string" select="
            if (local-name() = 'select' and $appearance-requested = 'minimal')
            then 'compact'
            else $appearance-requested"/>
        <xsl:variable name="option-count" as="xs:integer" select="
            if (count(descendant::xforms:item) gt 0)
            then count(descendant::xforms:item)
            else 1"/>
        <xsl:variable name="compact-size" as="xs:integer" select="
            if ($option-count gt 1)
            then 2
            else 1"/>
                         
        <div>
            <xsl:call-template name="copy-custom-data-attributes"/>
            <xsl:attribute name="class" select="$htmlClass"/>
            <xsl:if test="not($relevantStatus)">
                <xsl:attribute name="style" select="'display:none'"/>
            </xsl:if>
            <xsl:apply-templates select="xforms:label"/>
            <xsl:variable name="hint-text" as="xs:string" select="normalize-space(string-join(xforms:hint/text(), ' '))"/>
            <xsl:variable name="hint-id" as="xs:string" select="concat($id, '-hint')"/>
            
            <select>
                <xsl:attribute name="id" select="$id"/>
                <xsl:attribute name="class" select="$htmlClass"/>
                <xsl:attribute name="instance-context" select="$instance-context"/>
                <xsl:attribute name="data-ref" select="$nodeset"/>
                <xsl:attribute name="data-appearance-requested" select="$appearance-requested"/>
                <xsl:attribute name="data-appearance" select="$appearance-effective"/>
                <xsl:if test="local-name() = 'select' and $appearance-requested = 'minimal'">
                    <!-- TEST-TRACE: native HTML has no true minimal multi-select widget,
                         so enforce minimal->compact degradation for xf:select; helps tests/w3c/ch08.spec.ts "8.1.10.c". -->
                    <xsl:attribute name="data-appearance-degraded" select="'true'"/>
                </xsl:if>
                
                <xsl:if test="exists($binding) and exists($binding/@constraint)">
                    <xsl:attribute name="data-constraint" select="$binding/@constraint"/>
                </xsl:if>
                <xsl:if test="exists($binding) and exists($binding/@relevant)">
                    <xsl:attribute name="data-relevant" select="$binding/@relevant"/>
                </xsl:if>
                <xsl:if test="exists($binding) and exists($binding/@required)">
                    <xsl:attribute name="data-required" select="$binding/@required"/>
                </xsl:if>
                <!-- Keep bind @type available for submit validation over select bindings. -->
                <xsl:if test="exists($binding[@type])">
                    <xsl:attribute name="data-binding-type" select="string(($binding[@type][1]/@type)[1])"/>
                </xsl:if>
                
                <xsl:if test="exists($actions)">
                    <xsl:attribute name="data-action" select="$id"/>
                </xsl:if>
                
                <xsl:if test="$hint-text ne ''">
                    <xsl:attribute name="title" select="$hint-text"/>
                    <xsl:attribute name="aria-describedby" select="$hint-id"/>
                </xsl:if>
                
                
                <xsl:if test="local-name() = 'select'">
                    <xsl:attribute name="multiple">true</xsl:attribute>
                    <xsl:attribute name="size" select="
                        if ($appearance-effective = 'full')
                        then string($option-count)
                        else string($compact-size)"/>
                </xsl:if>
                <xsl:if test="local-name() = 'select1' and $appearance-effective = ('full','compact')">
                    <xsl:attribute name="size" select="
                        if ($appearance-effective = 'full')
                        then string($option-count)
                        else string($compact-size)"/>
                </xsl:if>
                 
                <!-- TEST-TRACE: include xforms:choices in select/select1 native option rendering order;
                     helps tests/w3c/ch08.spec.ts "8.3.1.a", "8.3.2.a" -->
                <xsl:apply-templates select="xforms:item | xforms:itemset | xforms:choices" mode="#current">
                    <xsl:with-param name="selectedValue" select="$selectedValue"/>
                </xsl:apply-templates>
                
            </select>
            <xsl:call-template name="render-control-hint">
                <xsl:with-param name="hint-id" select="$hint-id"/>
                <xsl:with-param name="hint-text" select="$hint-text"/>
            </xsl:call-template>
            
        </div>
        
        <xsl:call-template name="registerOutput">
            <xsl:with-param name="additional-class-values" select="$additional-class-values"/>
        </xsl:call-template>

    </xsl:template>





    <xd:doc scope="component">
        <xd:desc>Ignore text in model (REDUNDANT?)</xd:desc>
    </xd:doc>
    <xsl:template match="text()[((ancestor::xforms:model))]"/>



    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Render xforms:label as HTML label</xd:p>
            <xd:p>TODO: implement @for</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template match="xforms:label">
         
        <xsl:variable name="properties" as="map(*)">
            <xsl:apply-templates select="." mode="get-properties"/>
        </xsl:variable>
        
        <xsl:variable name="refi" as="xs:string" select="map:get($properties,'nodeset')"/>
        <xsl:variable name="this-instance-id" as="xs:string" select="map:get($properties,'instance-context')"/>
        <xsl:variable name="bindingi" as="element(xforms:bind)?" select="map:get($properties,'binding')"/>
                
        <!-- TEST-TRACE: [1] applies XForms first-node rule for duplicate siblings;
             helps tests/w3c/ch03.spec.ts "3.2.3.g" -->
        <xsl:variable name="instanceField" as="node()?">
            <xsl:if test="$refi ne ''">
                <xsl:sequence select="xforms:evaluate-xpath-with-instance-id($refi,$this-instance-id,())[1]"/>
            </xsl:if>
        </xsl:variable>
        
        <xsl:variable name="label" as="item()*">
            <xsl:choose>
                <xsl:when test="exists(@bind) and exists($bindingi/@calculate)">
                    <xsl:sequence select="xforms:evaluate-xpath-with-context-node('string(' || $bindingi/@calculate || ')',$instanceField,())"/>
                </xsl:when>
                <xsl:when test="exists(@ref) and exists($instanceField)">
                    <!-- @ref on label: the resolved XPath evaluates to the label text node -->
                    <xsl:value-of select="$instanceField"/>
                </xsl:when>
                <xsl:when test="count(./node()) &gt; 0">
                    <xsl:apply-templates select="node()"/>
                </xsl:when>
                <xsl:otherwise>
                    <!-- no-break space &#x00a0; -->
                    <xsl:text>&#xA0;</xsl:text>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:choose>
            <xsl:when test="parent::xforms:item or parent::xforms:itemset">
                <xsl:value-of select="$label"/>
            </xsl:when>
            <xsl:otherwise>
                <label>
                    <xsl:copy-of select="@class"/>
                    <xsl:sequence select="$label"/>
                </label>
            </xsl:otherwise>
        </xsl:choose>
        
    </xsl:template>

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Render xforms:value as HTML option/@value attribute</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template match="xforms:value">
        
        <xsl:variable name="properties" as="map(*)">
            <xsl:apply-templates select="." mode="get-properties"/>
        </xsl:variable>
        
        <xsl:variable name="refi" as="xs:string" select="map:get($properties,'nodeset')"/>
        <xsl:variable name="this-instance-id" as="xs:string" select="map:get($properties,'instance-context')"/>
        <xsl:variable name="bindingi" as="element(xforms:bind)?" select="map:get($properties,'binding')"/>
        
        <xsl:variable name="instanceField" as="node()?">
            <xsl:choose>
                <!-- 
                    Override default instance if @value specifies an instance
                -->
                <xsl:when test="starts-with(@value,'instance(')">
                    <xsl:sequence select="xforms:evaluate-xpath-with-instance-id(@value,xforms:getInstanceId(string(@value)),())"/>
                </xsl:when>
                <xsl:when test="$refi != ''">
                    <xsl:sequence select="xforms:evaluate-xpath-with-instance-id($refi,$this-instance-id,())[1]"/>
                </xsl:when>
                <xsl:otherwise/>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:variable name="value" as="xs:string">
            <xsl:choose>
                <xsl:when test="exists(@bind) and exists($bindingi/@calculate)">
                    <xsl:sequence select="xforms:evaluate-xpath-with-context-node('string(' || $bindingi/@calculate || ')',$instanceField,())"/>
                </xsl:when>
                <xsl:when test="exists(@ref) and exists($instanceField)">
                    <!-- @ref on value takes precedence over inline content -->
                    <xsl:value-of select="$instanceField"/>
                </xsl:when>
                <xsl:when test="exists(@value)">
                    <xsl:sequence select="xforms:evaluate-xpath-with-context-node('string(' || @value || ')',$instanceField,())"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="."/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:attribute name="value" select="$value"/>
    </xsl:template>

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for xforms:item element.</xd:p>
            <xd:p>Generates HTML option element.</xd:p>
        </xd:desc>
        <xd:param name="selectedValue">String consisting of the current selection in the list. (If it matches the value of the xforms:item, the HTML option will be marked as selected.)</xd:param>
    </xd:doc>
    <xsl:template match="xforms:item" mode="get-html">
        <xsl:param name="selectedValue" as="xs:string" select="''"/>
        <xsl:variable name="option-value-attribute" as="attribute(value)?">
            <xsl:apply-templates select="xforms:value[1]"/>
        </xsl:variable>
        
        <option>
            <xsl:if test="exists($option-value-attribute)">
                <xsl:sequence select="$option-value-attribute"/>
            </xsl:if>
            <xsl:if test="$selectedValue = string($option-value-attribute)">
                <xsl:attribute name="selected" select="'selected'"/>
            </xsl:if>

            <xsl:apply-templates select="xforms:label"/>
        </option>

    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for xforms:choices element.</xd:p>
            <xd:p>Generates native HTML optgroup and renders nested items/itemsets.</xd:p>
        </xd:desc>
        <xd:param name="selectedValue">Current selection used by nested xforms:item rendering.</xd:param>
    </xd:doc>
    <xsl:template match="xforms:choices" mode="get-html">
        <xsl:param name="selectedValue" as="xs:string" select="''"/>
        <!-- TEST-TRACE: render xforms:choices as HTML5 optgroup to preserve group labels and nested values;
             helps tests/w3c/ch08.spec.ts "8.3.1.a", "8.3.2.a" -->
        <xsl:variable name="rendered-choice-label" as="item()*">
            <xsl:apply-templates select="xforms:label[1]"/>
        </xsl:variable>
        <xsl:variable name="choice-group-label" as="xs:string" select="normalize-space(string($rendered-choice-label))"/>
        <optgroup>
            <xsl:attribute name="label" select="if ($choice-group-label != '') then $choice-group-label else ' '"/>
            <xsl:apply-templates select="xforms:item | xforms:itemset" mode="#current">
                <xsl:with-param name="selectedValue" select="$selectedValue"/>
            </xsl:apply-templates>
        </optgroup>
    </xsl:template>
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for xforms:itemset element.</xd:p>
            <xd:p>Generates HTML option elements according to evaluation of @ref.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template match="xforms:itemset" mode="get-html">
        <xsl:message use-when="$debugMode">[xforms:itemset] Generate HTML for itemset</xsl:message>
        
        <xsl:variable name="properties" as="map(*)">
            <xsl:apply-templates select="." mode="get-properties"/>
        </xsl:variable>
        
        <xsl:variable name="refi" as="xs:string" select="map:get($properties,'nodeset')"/>
        <xsl:variable name="this-instance-id" as="xs:string" select="map:get($properties,'instance-context')"/>
        <xsl:variable name="model-ref" as="xs:string" select="map:get($properties,'model-id')"/>
        
        
        <xsl:variable name="options" as="item()*" select="xforms:evaluate-xpath-with-instance-id($refi,$this-instance-id,())"/>
        
        <!-- TEST-TRACE: allow xforms:copy as alternative to xforms:value in itemset;
             XForms 1.1 9.3.7 defines xf:copy for deep-copy selection;
             helps tests/w3c/ch09.spec.ts "9.3.7.a", "9.3.7.b", "9.3.6.a" -->
        <xsl:variable name="xforms-value" as="element(xforms:value)?" select="child::xforms:value"/>
        <xsl:variable name="xforms-copy" as="element(xforms:copy)?" select="child::xforms:copy"/>
        <xsl:variable name="xforms-label" as="element(xforms:label)?" select="child::xforms:label"/>
        
        <xsl:for-each select="$options">
            <xsl:variable name="pos-nodeset" select="concat($refi, '[', position(), ']')"/>
            <option>
                <xsl:choose>
                    <xsl:when test="exists($xforms-value)">
                        <xsl:apply-templates select="$xforms-value,$xforms-label">
                            <xsl:with-param name="nodeset" select="$pos-nodeset" tunnel="yes"/>
                            <xsl:with-param name="instance-context" select="$this-instance-id" tunnel="yes"/>
                        </xsl:apply-templates>
                    </xsl:when>
                    <xsl:when test="exists($xforms-copy)">
                        <!-- xf:copy: use the copy ref to derive the option value -->
                        <xsl:variable name="copy-ref" as="xs:string" select="
                            if (exists($xforms-copy/@ref))
                            then concat($pos-nodeset, '/', $xforms-copy/@ref)
                            else $pos-nodeset"/>
                        <xsl:attribute name="value" select="
                            string(xforms:evaluate-xpath-with-instance-id($copy-ref, $this-instance-id, ()))"/>
                        <xsl:attribute name="data-copy-ref" select="$copy-ref"/>
                        <xsl:if test="exists($xforms-label)">
                            <xsl:apply-templates select="$xforms-label">
                                <xsl:with-param name="nodeset" select="$pos-nodeset" tunnel="yes"/>
                                <xsl:with-param name="instance-context" select="$this-instance-id" tunnel="yes"/>
                            </xsl:apply-templates>
                        </xsl:if>
                    </xsl:when>
                </xsl:choose>
            </option>
        </xsl:for-each>
        
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Handle XForms switch element. Register cases as a group for toggling.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template match="xforms:switch">
        <xsl:param name="position" as="xs:integer" required="no" select="0"/>
        <xsl:param name="context-position" as="xs:string" required="no" select="''"/>
        
        <xsl:variable name="base-switch-id" as="xs:string" select="if (exists(@id)) then string(@id) else generate-id()"/>
        <xsl:variable name="case-id-suffix" as="xs:string?" select="if ($context-position != '') then $context-position else ()"/>
        <xsl:variable name="myid" as="xs:string" select="if (exists($case-id-suffix)) then concat($base-switch-id, '-', $case-id-suffix) else $base-switch-id"/>
        <xsl:variable name="cases" as="xs:string*">
            <xsl:for-each select="child::xforms:case">
                <xsl:variable name="base-case-id" as="xs:string" select="if (exists(@id)) then string(@id) else generate-id()"/>
                <xsl:sequence select="if (exists($case-id-suffix)) then concat($base-case-id, '-', $case-id-suffix) else $base-case-id"/>
            </xsl:for-each>
        </xsl:variable>
        <xsl:sequence select="js:addSwitch($myid,$cases)"/>
        
        <xsl:variable name="additional-class-values" as="xs:string+" select="('xforms-switch')"/>
        <xsl:variable name="htmlClass" as="xs:string">
            <xsl:call-template name="getHtmlClass">
                <xsl:with-param name="source-class" as="xs:string?" select="@class"/>
                <xsl:with-param name="additional-values" as="xs:string*" select="$additional-class-values"/>
            </xsl:call-template>
        </xsl:variable>
        
        <div>
            <xsl:call-template name="copy-custom-data-attributes"/>
            <xsl:attribute name="id" select="$myid"/>
            <xsl:attribute name="class" select="$htmlClass"/>
            <xsl:attribute name="data-switch-id" select="$myid"/>
            <xsl:apply-templates>
                <xsl:with-param name="switch-id" as="xs:string" select="$myid" tunnel="yes"/>
                <xsl:with-param name="case-id-suffix" as="xs:string?" select="$case-id-suffix" tunnel="yes"/>
                <xsl:with-param name="context-position" select="$context-position"/>
                <xsl:with-param name="position" select="$position"/>
            </xsl:apply-templates>
        </div>
    </xsl:template>
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of XForms <a href="https://www.w3.org/TR/xforms11/#ui-case">case element</a></xd:p>
            <xd:p>Generates an HTML div and is set to display or not according to its selected status.</xd:p>
        </xd:desc>
        <xd:param name="switch-id">ID of parent switch of a case element, used to support toggle behaviour.</xd:param>
    </xd:doc>
    <xsl:template match="xforms:case" mode="get-html">
        <xsl:param name="switch-id" as="xs:string?" required="no" tunnel="yes"/>
        <xsl:param name="case-id-suffix" as="xs:string?" required="no" tunnel="yes"/>
        
        <xsl:variable name="base-case-id" as="xs:string" select="if (exists(@id)) then string(@id) else generate-id()"/>
        <xsl:variable name="id" as="xs:string" select="if (exists($case-id-suffix)) then concat($base-case-id, '-', $case-id-suffix) else $base-case-id"/>
        <xsl:variable name="additional-class-values" as="xs:string+" select="('xforms-case')"/>
        <xsl:variable name="htmlClass" as="xs:string">
            <xsl:call-template name="getHtmlClass">
                <xsl:with-param name="source-class" as="xs:string?" select="@class"/>
                <xsl:with-param name="additional-values" as="xs:string*" select="$additional-class-values"/>
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="isRelevant" as="xs:boolean">
            <xsl:call-template name="getCaseRelevantStatus"/>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="$isRelevant">
                <xsl:sequence select="js:setCaseStatus($id,'true')"/>
                <xsl:sequence select="js:setSwitchSelection($switch-id,$id)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:sequence select="js:setCaseStatus($id,'false')"/>
            </xsl:otherwise>
        </xsl:choose>
        <xsl:sequence select="js:setCaseSwitch($id,$switch-id)"/>
        
        <div>
            <xsl:call-template name="copy-custom-data-attributes"/>
            <xsl:attribute name="id" select="$id"/>
            <xsl:attribute name="class" select="$htmlClass"/>
            <xsl:attribute name="data-switch-id" select="$switch-id"/>
            <xsl:attribute name="data-case-id-base" select="$base-case-id"/>
            <xsl:if test="not($isRelevant)">
                <xsl:attribute name="style" select="'display:none'"/>
            </xsl:if>
            <!-- TEST-TRACE: exclude event-bound action children (same as group fix);
                 helps tests/w3c/ch09.spec.ts "9.2.1.a2", tests/w3c/ch10.spec.ts "10.5.a", "10.6.a" -->
            <xsl:apply-templates select="child::node()
                [not(self::xforms:*[@ev:event][local-name() = ('message','setvalue','insert','delete','setindex','toggle','setfocus','dispatch','rebuild','recalculate','revalidate','refresh','reset','load','send')])]
                [not(self::xforms:action[@ev:event])]"/>
        </div>
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of XForms <a href="https://www.w3.org/TR/xforms11/#ui-group">group element</a></xd:p>
            <xd:p>Generates an HTML div and passes @ref or @nodeset to descendants.</xd:p>
            <xd:p>When the group uses @bind and the binding has a @relevant MIP that evaluates to false(), the group is hidden (display:none).</xd:p>
        </xd:desc>
        <xd:param name="id">ID of HTML element.</xd:param>
        <xd:param name="nodeset">XPath binding expression</xd:param>
        <xd:param name="instance-context">ID of XForms instance relevant to this control</xd:param>
        <xd:param name="binding">xforms:bind elements relevant to this control</xd:param>
    </xd:doc>
    <xsl:template match="xforms:group" mode="get-html">
        <xsl:param name="id" as="xs:string" required="yes" tunnel="yes"/>
        <xsl:param name="nodeset" as="xs:string" required="yes" tunnel="yes"/>
        <xsl:param name="instance-context" as="xs:string" required="no" select="$global-default-instance-id" tunnel="yes"/>
        <xsl:param name="binding" as="element(xforms:bind)*" required="no" select="()" tunnel="yes"/>
        
        <!-- Resolve relevance from binding when @bind is used -->
        <xsl:variable name="instanceField" as="node()?" select="
            if ($nodeset != '')
            then xforms:evaluate-xpath-with-instance-id($nodeset, $instance-context, ())
            else ()"/>
        
        <xsl:variable name="relevantStatus" as="xs:boolean">
            <xsl:call-template name="getRelevantStatus">
                <xsl:with-param name="xformsControl" as="element()" select="."/>
                <xsl:with-param name="instanceField" as="node()?" select="$instanceField"/>
            </xsl:call-template>
        </xsl:variable>
        
        <xsl:variable name="additional-class-values" as="xs:string+" select="('xforms-group')"/>
        <xsl:variable name="htmlClass" as="xs:string">
            <xsl:call-template name="getHtmlClass">
                <xsl:with-param name="source-class" as="xs:string?" select="@class"/>
                <xsl:with-param name="additional-values" as="xs:string*" select="$additional-class-values"/>
            </xsl:call-template>
        </xsl:variable>
        
        <div>
            <xsl:call-template name="copy-custom-data-attributes"/>
            <xsl:attribute name="id" select="$id"/>
            <xsl:attribute name="class" select="$htmlClass"/>
            <xsl:if test="$nodeset != ''">
                <xsl:attribute name="data-group-ref" select="$nodeset" />
                <xsl:attribute name="data-instance-context" select="$instance-context" />
            </xsl:if>
            <xsl:if test="not($relevantStatus)">
                <xsl:attribute name="style" select="'display:none'"/>
            </xsl:if>
            <!-- TEST-TRACE: exclude event-bound action children from HTML rendering;
                 they are already collected by set-actions in the control template;
                 helps tests/w3c/ch09.spec.ts "9.1.1.a2" and tests/w3c/ch10.spec.ts "10.4.a" -->
            <xsl:apply-templates select="child::node()
                [not(self::xforms:*[@ev:event][local-name() = ('message','setvalue','insert','delete','setindex','toggle','setfocus','dispatch','rebuild','recalculate','revalidate','refresh','reset','load','send')])]
                [not(self::xforms:action[@ev:event])]"/>
        </div>
    </xsl:template>
    
    

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of XForms <a href="https://www.w3.org/TR/xforms11/#ui-repeat">repeat element</a></xd:p>
            <xd:p>Generates HTML div and iterates over items within.</xd:p>
        </xd:desc>
        <xd:param name="model-key">ID of context model (xforms:model/@id value or default value).</xd:param>
        <xd:param name="nodeset">An XPath binding expression. Stored in Javascript variable to support recalculation of repeats.</xd:param>
        <xd:param name="position">Integer representing position of item (in a repeat list for example).</xd:param>
        <xd:param name="context-position">String representing position of item in a hierarchy (e.g. in nested repeat)</xd:param>
        <xd:param name="recalculate">Boolean parameter. A true value means we are recalculating and do not output the top-level div</xd:param>
        <xd:param name="refreshRepeats">Boolean parameter. A true value means we are calling it from the refreshRepeats-JS template - we are replacing the content of the div wrapper and don't need to recreate it (otherwise there will be duplicate IDs)</xd:param>
    </xd:doc>
    <xsl:template match="xforms:repeat">
        <xsl:param name="model-key" as="xs:string" required="no" select="$global-default-model-id" tunnel="yes"/>        
        <xsl:param name="nodeset" as="xs:string" required="no" select="''" tunnel="yes"/>
        <xsl:param name="position" as="xs:integer" required="no" select="0"/>
        <xsl:param name="context-position" as="xs:string" required="no" select="''"/>
        <xsl:param name="recalculate" as="xs:boolean" required="no" select="fn:false()" tunnel="yes"/>
        <xsl:param name="refreshRepeats" as="xs:boolean" required="no" select="fn:false()" tunnel="yes"/>
        <!-- PERF-6b: when set, render only the item at this 1-based position (splice mode) -->
        <xsl:param name="splice-position" as="xs:integer?" required="no" select="()" tunnel="yes"/>
        
<!--        <xsl:message>[xforms:repeat] Handling: <xsl:sequence select="fn:serialize(.)"/></xsl:message>-->        
        <xsl:variable name="model-ref" as="xs:string" select="if (exists(@model)) then string(@model) else $model-key"/>
        
        <xsl:variable name="string-position" as="xs:string" select="if ($context-position != '') then $context-position else string($position)"/>
        <xsl:variable name="myid" as="xs:string" select="
            if (exists(@id)) 
            then @id
            else concat( generate-id(), '-', $string-position )"/>
                
        <xsl:variable name="properties" as="map(*)">
            <xsl:apply-templates select="." mode="get-properties"/>
        </xsl:variable>
        
        <xsl:variable name="refi" as="xs:string" select="map:get($properties,'nodeset')"/>
        <xsl:variable name="this-instance-id" as="xs:string" select="map:get($properties,'instance-context')"/>
        
        <!-- set the starting index value -->        
        <xsl:choose>
            <xsl:when test="$recalculate">
<!--                <xsl:message use-when="$debugMode">[xforms:repeat] Index of item '<xsl:sequence select="$myid"/>' is <xsl:value-of select="js:getRepeatIndex($myid)"/></xsl:message>-->
            </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="this-index" as="xs:double">
                    <xsl:choose>
                        <xsl:when test="not(exists(@startindex))">
                            <xsl:sequence select="1"/>
                        </xsl:when>
                        <xsl:when test="@startindex castable as xs:double">
                            <xsl:value-of select="number(@startindex)"/>
                        </xsl:when>
                        <xsl:otherwise>
<!--                            <xsl:message>[xforms:repeat] value of @startindex ('<xsl:value-of select="@startindex"/>') is not a number. Setting the index to '1'</xsl:message>-->
                            <xsl:value-of select="1"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
<!--                <xsl:message>[xforms:repeat] Setting index of <xsl:sequence select="$myid"/> to '<xsl:sequence select="$this-index"/>'</xsl:message>-->
                <xsl:sequence select="js:setRepeatIndex($myid, $this-index)"/>
            </xsl:otherwise>
        </xsl:choose>
        

        <!-- identify instance fields corresponding to this -->
        <xsl:variable name="selectedRepeatVar" as="element()*" select="xforms:evaluate-xpath-with-instance-id($refi,$this-instance-id,())"/>
        
        <!--<xsl:message use-when="$debugMode">
            <xsl:choose>
                <xsl:when test="exists($selectedRepeatVar)">
                    [xforms:repeat] ref = <xsl:sequence select="$refi" />
                    count = <xsl:sequence select="count($selectedRepeatVar)" />
                </xsl:when>
                <xsl:otherwise>[xforms:repeat] No repeat found for ref <xsl:sequence select="$refi" /></xsl:otherwise>
            </xsl:choose>
        </xsl:message>-->
        
        <xsl:variable name="repeat-items" as="element()*">
            <xsl:variable name="this" as="element(xforms:repeat)" select="."/>
            <!-- PERF-6b: when splice-position is set, render only that single item -->
            <xsl:for-each select="if (exists($splice-position))
                                   then $selectedRepeatVar[$splice-position]
                                   else $selectedRepeatVar">
                <xsl:variable name="item-pos" as="xs:integer" select="if (exists($splice-position)) then $splice-position else position()"/>
                <xsl:variable name="string-position" as="xs:string" select="string($item-pos)"/>
                <xsl:variable name="new-context-position" as="xs:string" select="if ($context-position != '') then concat($context-position, '.', $string-position) else $string-position"/>
                <div data-repeat-item="true">
                    <xsl:apply-templates select="$this/child::node()">
                        <xsl:with-param name="nodeset" select="concat($refi, '[', $item-pos, ']')" tunnel="yes"/>
                        <xsl:with-param name="context-nodeset" select="concat($refi, '[', $item-pos, ']')" tunnel="yes"/>
                        <xsl:with-param name="position" select="$item-pos"/>
                        <xsl:with-param name="context-position" select="$new-context-position"/>
                        <!-- PERF-6b: clear splice-position so nested repeats render all their items -->
                        <xsl:with-param name="splice-position" select="()" tunnel="yes"/>
                    </xsl:apply-templates>
                </div>
            </xsl:for-each>
        </xsl:variable>
           
        <!-- Write HTML -->   
        <xsl:choose>
            <xsl:when test="$refreshRepeats and not(ancestor::xforms:repeat)">
                <xsl:sequence select="$repeat-items"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="additional-class-values" as="xs:string+" select="('xforms-repeat')"/>
                
                <xsl:variable name="htmlClass" as="xs:string">
                    <xsl:call-template name="getHtmlClass">
                        <xsl:with-param name="source-class" as="xs:string?" select="@class"/>
                        <xsl:with-param name="context-nodeset" select="$nodeset" tunnel="yes"/>
                        <xsl:with-param name="instance-context" select="$this-instance-id" tunnel="yes"/>
                        <xsl:with-param name="additional-values" as="xs:string*" select="$additional-class-values"/>
                    </xsl:call-template>
                </xsl:variable>
                <div>
                    <xsl:attribute name="id" select="$myid"/>
                    <xsl:attribute name="class" select="$htmlClass"/>
                    
                    <xsl:attribute name="data-repeatable-context" select="$refi" />
                    <xsl:attribute name="data-count" select="count($selectedRepeatVar)" />
                    
                    <xsl:sequence select="$repeat-items"/>
                </div>
            </xsl:otherwise>
        </xsl:choose>
        
        
        <!-- register repeats (top-level only and not when recalculating) -->
        <xsl:if test="not($recalculate) and not(ancestor::xforms:repeat)">
            <!--<xsl:message use-when="$debugMode">
                <xsl:sequence select="concat('[xforms:repeat] Registering repeat with ID ', $myid, ' and parsed nodeset ', $refi)"/>
            </xsl:message>-->
            <xsl:sequence select="js:addRepeat($myid , .)" />    
            
<!--            <xsl:message use-when="$debugMode">[xforms:repeat] setting context nodeset '<xsl:sequence select="$nodeset"/>'</xsl:message>-->
            <xsl:sequence select="js:addRepeatContext($myid , $nodeset)" /> 
            <xsl:sequence select="js:addRepeatModelContext($myid , $model-ref)" /> 
            <!-- PERF-6a: store resolved instance ID for dirty-repeat guard -->
            <xsl:sequence select="js:setRepeatInstanceId($myid, $this-instance-id)"/>
            <!-- PERF-6b: store resolved nodeset for splice-path matching -->
            <xsl:sequence select="js:setRepeatRef($myid, $refi)"/>
        </xsl:if>
        
        <!-- register size of repeat -->
        <xsl:sequence select="js:setRepeatSize($myid,count($selectedRepeatVar))"/>
        
        
    </xsl:template>

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for xforms:submit element.</xd:p>
        </xd:desc>
        <xd:param name="submissions">Map of submissions.</xd:param>
    </xd:doc>
    <xsl:template match="xforms:submit">
        <xsl:param name="submissions" select="map{}" as="map(xs:string, map(*))" tunnel="yes"/>
        
        <!-- same logic as in xformsjs-main for setting submission map based on xforms:submission elements -->
        <xsl:variable name="submission-id" as="xs:string" select="
            if (@submission) then xs:string(@submission)
            else if (@id) then xs:string(@id)
            else $global-default-submission-id
            "/>
        
<!--        <xsl:message use-when="$debugMode">[xforms:submit] Generating form control for submission ID '<xsl:sequence select="string(@submission)"/>'</xsl:message>-->
        
<!--        <xsl:message use-when="$debugMode">[xforms:submit] Comparing ID with submissions map '<xsl:sequence select="serialize($submissions)"/>'</xsl:message>-->
        
        <xsl:variable name="innerbody">
            <xsl:apply-templates select="xforms:label"/>
        </xsl:variable>

        <xsl:choose>
            <xsl:when test="@appearance = 'minimal'">
                <a>
                    <xsl:copy-of select="$innerbody"/>
                </a>
            </xsl:when>
            <xsl:otherwise>
                <button type="button">
                    <xsl:copy-of select="@*[local-name() != 'submission']"/>
                    
                    <xsl:if test="map:contains($submissions, $submission-id)">
<!--                        <xsl:message use-when="$debugMode">[xforms:submit] Submission found</xsl:message>-->
                        <xsl:attribute name="data-submit" select="$submission-id"/>
                    </xsl:if>
                    <xsl:copy-of select="$innerbody"/>
                </button>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>


    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for updating instance XML based on node added with xforms:insert control</xd:p>
        </xd:desc>
        <xd:param name="insert-node-location">Node where insert is to take place</xd:param>
        <xd:param name="nodes-to-insert">Node set to be inserted</xd:param>
        <xd:param name="position-relative">"before" or "after"</xd:param>
    </xd:doc>
    <xsl:template match="*" mode="insert-node">
        <xsl:param name="insert-node-location" as="node()" tunnel="yes"/>
        <xsl:param name="nodes-to-insert" as="node()*" tunnel="yes"/>
        <xsl:param name="position-relative" as="xs:string?" select="'after'" required="no" tunnel="yes"/>
        
        <!--<xsl:message use-when="$debugMode">[insert-node mode] Checking whether <xsl:sequence select="name()"/> is the insert location</xsl:message>-->
        
        <xsl:if test=". is $insert-node-location and $position-relative = 'before'">
            <!--<xsl:message>[insert-node mode] Found! (inserting before) <xsl:value-of select="serialize($insert-node-location)"/></xsl:message>-->
            <xsl:copy-of select="$nodes-to-insert"/>
        </xsl:if>
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <!-- 
            From XForms 1.1 spec:
            If the Node Set Binding node-set is not specified or empty, then the insert location node provided by the context attribute is intended to be the parent of the cloned node.
            -->
            <xsl:if test=". is $insert-node-location and $position-relative = 'child'">
                <!--<xsl:message>[insert-node mode] Found! (inserting as child) <xsl:value-of select="serialize($insert-node-location)"/></xsl:message>-->
                <!-- Handle attribute nodes: add as attributes of this element -->
                <xsl:for-each select="$nodes-to-insert[self::attribute()]">
                    <xsl:copy-of select="."/>
                </xsl:for-each>
                <!-- Handle element/text nodes: add as children -->
                <xsl:copy-of select="$nodes-to-insert[not(self::attribute())]"/>
            </xsl:if>
            <xsl:apply-templates select="node()" mode="insert-node"/>
        </xsl:copy>
        <xsl:if test=". is $insert-node-location and $position-relative = 'after'">
            <!--<xsl:message>[insert-node mode] Found! (inserting after) <xsl:value-of select="serialize($insert-node-location)"/></xsl:message>-->
            <xsl:copy-of select="$nodes-to-insert"/>
        </xsl:if>
        
    </xsl:template>


    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for updating instance XML based on node deleted with xforms:delete control</xd:p>
        </xd:desc>
        <xd:param name="delete-node">Node(s) to be deleted</xd:param>
     </xd:doc>
    <xsl:template match="*" mode="delete-node">
        <xsl:param name="delete-node" as="node()*" tunnel="yes"/>
        
        <xsl:choose>
            <xsl:when test="some $n in $delete-node satisfies $n is .">
                <!-- This element is marked for deletion — suppress it -->
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy>
                    <!-- Copy attributes, excluding any targeted for deletion -->
                    <xsl:for-each select="@*">
                        <xsl:if test="not(some $n in $delete-node satisfies $n is .)">
                            <xsl:copy-of select="."/>
                        </xsl:if>
                    </xsl:for-each>
                    <xsl:apply-templates select="node()" mode="delete-node"/>
                </xsl:copy>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for replacing a target node in instance XML with a replacement node.</xd:p>
        </xd:desc>
        <xd:param name="replace-node">Node to replace</xd:param>
        <xd:param name="replacement-node">Replacement node</xd:param>
    </xd:doc>
    <xsl:template match="*" mode="replace-node">
        <xsl:param name="replace-node" as="node()" tunnel="yes"/>
        <xsl:param name="replacement-node" as="node()" tunnel="yes"/>
        <xsl:choose>
            <xsl:when test=". is $replace-node">
                <xsl:sequence select="$replacement-node"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy>
                    <xsl:copy-of select="@*"/>
                    <xsl:apply-templates select="node()" mode="replace-node"/>
                </xsl:copy>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="text() | comment() | processing-instruction()" mode="replace-node">
        <xsl:copy/>
    </xsl:template>
    
    <xsl:template match="@*" mode="replace-node">
        <xsl:copy-of select="."/>
    </xsl:template>
    <xsl:template match="text()" mode="trim-cdata-sections">
        <xsl:param name="cdata-element-qnames" as="xs:QName*" tunnel="yes"/>
        <xsl:value-of select="
            if (exists(parent::*) and node-name(parent::*) = $cdata-element-qnames)
            then normalize-space(.)
            else ."/>
    </xsl:template>
    
 
    <xd:doc scope="component">
        <xd:desc>Handle HTML button click</xd:desc>
    </xd:doc>
    <xsl:template match="(*:a|*:button)[exists(@data-action)]" mode="ixsl:onclick">      
        <xsl:call-template name="DOMActivate">
            <xsl:with-param name="form-control" select="."/>
        </xsl:call-template>       
    </xsl:template>



    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of XForms <a href="https://www.w3.org/TR/xforms11/#ui-trigger">trigger element</a></xd:p>
            <xd:p>Generates HTML link or button and registers actions.</xd:p>
        </xd:desc>
        <xd:param name="id">ID of HTML element.</xd:param>
        <xd:param name="nodeset">XPath binding expression</xd:param>
    </xd:doc>
    <xsl:template match="xforms:trigger" mode="get-html">
        <xsl:param name="id" as="xs:string" tunnel="yes"/>
        <xsl:param name="nodeset" as="xs:string" tunnel="yes"/>
        
        <xsl:variable name="additional-class-values" as="xs:string+" select="('xforms-trigger')"/>
        <xsl:variable name="htmlClass" as="xs:string">
            <xsl:call-template name="getHtmlClass">
                <xsl:with-param name="source-class" as="xs:string?" select="@class"/>
                <xsl:with-param name="additional-values" as="xs:string*" select="$additional-class-values"/>
            </xsl:call-template>
        </xsl:variable>
        
        <xsl:variable name="innerbody">
            <xsl:choose>
                <xsl:when test="child::xforms:label">
                    <xsl:apply-templates select="xforms:label"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="'&#x00a0;'"/>
                </xsl:otherwise>
            </xsl:choose>
            
        </xsl:variable>
        
        <!--<span class="xforms-trigger">-->
            <xsl:variable name="html-element" as="xs:string">
                <xsl:choose>
                    <xsl:when test="@appearance = 'minimal'">
                        <xsl:sequence select="'a'"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:sequence select="'button'"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:variable>
        <xsl:element name="{$html-element}">
                <xsl:if test="@appearance = 'minimal'">
                    <xsl:attribute name="type" select="'button'"/>
                </xsl:if>
                <xsl:attribute name="class" select="$htmlClass"/>
                <xsl:call-template name="copy-custom-data-attributes"/>
                
                <xsl:attribute name="data-ref" select="$nodeset"/>
                <xsl:attribute name="data-action" select="$id"/>
                <xsl:copy-of select="$innerbody"/>            
            </xsl:element>
        <!--</span>-->        
    </xsl:template>

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for XForms Action elements (xforms:action, xforms:setvalue, etc.)</xd:p>
            <xd:p>Generates map of this and descendant actions.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template match="xforms:*[local-name() = $xforms-actions] | xforms:action | xforms:show | xforms:hide | xforms:script | xforms:unload">
        <xsl:variable name="myid" as="xs:string" select="if (exists(@id)) then @id else generate-id()"/>
        <xsl:variable name="log-label" as="xs:string" select="concat('[',name(),' match template]')"/>
        <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> START</xsl:message>
        <xsl:variable name="time-id" select="concat($log-label, ' ', generate-id())"/>
        <xsl:sequence use-when="$debugTiming" select="js:startTime($time-id)" />        
        
        
  
        <xsl:variable name="action-map" as="map(*)">
            <xsl:apply-templates select="." mode="set-action"/>
        </xsl:variable>
        
        <!--<xsl:message use-when="$debugMode">
            [XForms Action] found action!
            node       = <xsl:value-of select="serialize(.)"/>, 
            id         = <xsl:value-of select="@id"/>,
            myid       = <xsl:value-of select="$myid"/>, 
            event      = <xsl:value-of select="map:get($action-map,'@event')"/>
        </xsl:message>-->

        <xsl:if test="exists($action-map)">
            <xsl:choose>
                <!-- TEST-TRACE: top-level event actions (e.g. XHTML head/body children) are
                     registration-only; emitting map items into the HTML result tree causes
                     XPTY0004 \"A map can't be a child of an XML node\". -->
                <xsl:when test="exists(@*:event) and (not(parent::xforms:*) or parent::xforms:xform)">
                    <xsl:sequence select="js:addAction($myid, $action-map)"/>
                </xsl:when>
                <!-- TEST-TRACE: body-level actions with ev:observer must be registered via JS,
                     not output as map values (which would fail inside xsl:result-document);
                     helps tests/w3c/ch10.spec.ts "10.3.a", "10.4.a" -->
                <xsl:when test="exists(@ev:observer)">
                    <xsl:sequence select="js:addAction($myid, $action-map)"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="$action-map" />
                </xsl:otherwise>
            </xsl:choose>
        </xsl:if>

        <xsl:sequence use-when="$debugTiming" select="js:endTime($time-id)" />
        <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> END</xsl:message>
    </xsl:template>
    

   
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for updating element within instance XML based on new value in binding calculation (xforms:bind/@calculate)</xd:p>
        </xd:desc>
        <xd:param name="updated-nodes">Nodes within instance that are affected by binding calculations</xd:param>
        <xd:param name="updated-value">Value of those nodes</xd:param>
    </xd:doc>

    <xsl:template match="*" mode="recalculate">
        <xsl:param name="updated-nodes" as="node()*" tunnel="yes"/>
        <xsl:param name="updated-value" as="item()?" tunnel="yes"/>
        
        <xsl:variable name="updated-node" as="element()?" select="$updated-nodes[. is fn:current()]"/>
        
<!--        <xsl:message use-when="$debugMode">[recalculate mode] comparing instance node <xsl:sequence select="fn:serialize(.)"/> with updated node <xsl:sequence select="fn:serialize($updated-nodes)"/></xsl:message> -->
        <xsl:copy>
            <xsl:apply-templates select="@*" mode="recalculate"/>
            
            <xsl:choose>
                <xsl:when test="exists($updated-node)">
                    <!--<xsl:message use-when="$debugMode">[recalculate mode] MATCHED <xsl:value-of select="name()"/></xsl:message> -->
                    <xsl:sequence select="$updated-value"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates select="child::node()" mode="recalculate"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:copy>
    </xsl:template>

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for updating attribute within instance XML based on new value in binding calculation (xforms:bind/@calculate)</xd:p>
        </xd:desc>
        <xd:param name="updated-nodes">Nodes within instance that are affected by binding calculations</xd:param>
        <xd:param name="updated-value">Value of those nodes</xd:param>
    </xd:doc>
    <xsl:template match="@*" mode="recalculate">
        <xsl:param name="updated-nodes" as="node()*" tunnel="yes"/>
        <xsl:param name="updated-value" as="xs:string?" tunnel="yes"/>
        
        <xsl:variable name="updated-node" as="attribute()?" select="$updated-nodes[. is fn:current()]"/>
        
        <xsl:choose>
            <xsl:when test="exists($updated-node)">
                <xsl:attribute name="{name(.)}" select="$updated-value"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy-of select="."/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
           
    
    <xd:doc scope="component">
        <xd:desc>Ensures namespaces are declared at instance level</xd:desc>
    </xd:doc>
    <xsl:template match="*" mode="namespace-fix">
        <xsl:variable name="current-namespace" as="xs:anyURI" select="namespace-uri()"/>
        <xsl:variable name="new-name" as="xs:QName" select="QName($current-namespace, name())"/>
        <xsl:element name="{$new-name}" namespace="{$current-namespace}">
            <!-- TEST-TRACE: keep canonical function prefixes resolvable when instance-root is namespace-context; helps tests/supplemental/issues.spec.ts "Issue #33". -->
            <xsl:namespace name="xforms" select="'http://www.w3.org/2002/xforms'"/>
            <xsl:namespace name="fn" select="'http://www.w3.org/2005/xpath-functions'"/>
            <xsl:copy-of select="namespace::*"/>
            <xsl:apply-templates select="@*,node()" mode="namespace-fix"/>
        </xsl:element>
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>Copy attributes in namespace-fix mode</xd:desc>
    </xd:doc>
    <xsl:template match="@*" mode="namespace-fix">
        <xsl:copy-of select="."/>
    </xsl:template>



    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Return value of HTML form field</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template match="*:input" mode="get-field">

        <xsl:choose>
            <xsl:when test="exists(@type) and @type = 'checkbox'">
                <xsl:sequence select="if (ixsl:get(., 'checked') = true()) then 'true' else ''"/>
            </xsl:when>
            <xsl:when test="exists(@type) and @type = 'time'">
                <xsl:variable name="raw-time-value" as="xs:string" select="string(ixsl:get(., 'value'))"/>
                <xsl:sequence select="
                    if ($raw-time-value = '')
                    then ''
                    else (
                        if (matches($raw-time-value,'^[0-9]{2}:[0-9]{2}$'))
                        then concat($raw-time-value, ':00')
                        else $raw-time-value
                    )"/>
            </xsl:when>
            <xsl:when test="exists(@type) and @type = 'datetime-local'">
                <xsl:variable name="raw-datetime-value" as="xs:string" select="string(ixsl:get(., 'value'))"/>
                <xsl:sequence select="
                    if ($raw-datetime-value = '')
                    then ''
                    else (
                        if (matches($raw-datetime-value,'^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}$'))
                        then concat($raw-datetime-value, ':00')
                        else $raw-datetime-value
                    )"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:sequence select="ixsl:get(., 'value')"/>
            </xsl:otherwise>
        </xsl:choose>

    </xsl:template>

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Return value of HTML form field</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template match="*:select" mode="get-field">
        <!-- TEST-TRACE: rely on native HTMLSelectElement.value for stable select/select1
             change handling; helps tests/w3c/ch08.spec.ts "8.3.3.b", "8.3.3.c". -->
        <xsl:sequence select="ixsl:get(., 'value')"/>
    </xsl:template>

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Return value of HTML form field</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template match="*:textarea" mode="get-field">

        <xsl:sequence select="ixsl:get(., 'value')"/>
    </xsl:template>


    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Set value of HTML form field</xd:p>
        </xd:desc>
        <xd:param name="value">Value to set</xd:param>
    </xd:doc>
    <xsl:template match="*:input" mode="set-field">
        <xsl:param name="value" select="''" tunnel="yes"/>

        <xsl:choose>
            <xsl:when test="exists(@type) and @type = 'checkbox'">                
                <ixsl:set-property name="checked" select="if($value='true') then $value else ''" object="."/>
            </xsl:when>
            <xsl:otherwise>
                <ixsl:set-property name="value" select="$value" object="."/>
            </xsl:otherwise>
        </xsl:choose>

    </xsl:template>

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Set value of HTML form field</xd:p>
        </xd:desc>
        <xd:param name="value">Value to set</xd:param>
    </xd:doc>
    <xsl:template match="*:select" mode="set-field">
        <xsl:param name="value" select="''" tunnel="yes"/>
        <!-- TEST-TRACE: include nested option descendants so refresh can reselect values
             when choices render via optgroup; helps tests/w3c/ch08.spec.ts "8.1.10.c". -->
        <xsl:for-each select=".//option[@value = $value]">
            <ixsl:set-property name="selected" select="true()" object="."/>
        </xsl:for-each>
    </xsl:template>

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Set value of HTML form field</xd:p>
        </xd:desc>
        <xd:param name="value">Value to set</xd:param>
    </xd:doc>
    <xsl:template match="*:textarea" mode="set-field">
        <xsl:param name="value" select="''" tunnel="yes" />
        <ixsl:set-property name="value" select="$value" object="."/>
    </xsl:template>
    
   
    <!-- 
    MD 2018
    
    Helper functions and templates
    
    -->
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Determine if an XForms element has a reference to the index() function.</xd:p>
            <xd:p>(If so, it will be added to a Javascript variable to support the xforms-recalculate event)</xd:p>
        </xd:desc>
        <xd:param name="this">Element to be checked</xd:param>
    </xd:doc>
    <xsl:function name="xforms:usesIndexFunction" as="xs:boolean">
        <xsl:param name="this" as="element()"/>
        <xsl:variable name="index-function-match" as="xs:string*" >
            <!-- 
            \i = "initial name character"
            \c = "name character"
            
            https://www.w3.org/TR/xmlschema11-2/#Name
            https://www.mulberrytech.com/quickref/regex.pdf
            
            -->
            <xsl:analyze-string select="$this/@ref" regex="\i\c*\(">
                <xsl:matching-substring>
                    <xsl:choose>
                        <xsl:when test="substring-before(.,'(')= 'index'">
                            <xsl:sequence select="'i'" />
                        </xsl:when>
                        <xsl:otherwise/>
                    </xsl:choose>
                </xsl:matching-substring>
                <xsl:non-matching-substring/>
            </xsl:analyze-string>
            
            <xsl:analyze-string select="$this/@nodeset" regex="\i\c*\(">
                <xsl:matching-substring>
                    <xsl:choose>
                        <xsl:when test="substring-before(.,'(')= 'index'">
                            <xsl:sequence select="'i'" />
                        </xsl:when>
                        <xsl:otherwise/>
                    </xsl:choose>
                </xsl:matching-substring>
                <xsl:non-matching-substring/>
            </xsl:analyze-string>
        </xsl:variable>
        
        <xsl:sequence select="if (exists($index-function-match)) then true() else false()"/>
        
    </xsl:function>
    
    <xd:doc scope="component">
        <xd:desc>Add all relevant namespace declarations to the xform element, to help with xsl:evaluation</xd:desc>
        <xd:param name="this">Document for which namespaces are needed</xd:param>
    </xd:doc>
    <xsl:function name="xforms:addNamespaceDeclarationsToDocument" as="document-node()">
        <xsl:param name="this" as="document-node()"/>
        <xsl:message use-when="$debugMode">[xforms:addNamespaceDeclarationsToDocument] URI: <xsl:value-of select="base-uri($this)"/></xsl:message>
        <xsl:document>
            <xsl:variable name="default-namespace" as="xs:anyURI" select="$this/*/namespace-uri()"/>
            <xsl:message use-when="$debugMode">[xforms:addNamespaceDeclarationsToDocument] <xsl:sequence select="if (name($this/*) eq 'html') then '&quot;' || string($this/*/*:head/*:title) || '&quot; ' else ()"/>Default namespace of root <xsl:sequence select="name($this/*)"/>: <xsl:sequence select="$default-namespace"/></xsl:message>
            <xsl:copy select="$this/*" copy-namespaces="yes">
                <!-- TEST-TRACE: bind canonical fn/xforms prefixes on evaluation root; helps tests/supplemental/issues.spec.ts "Issue #33". -->
                <xsl:namespace name="xforms" select="'http://www.w3.org/2002/xforms'"/>
                <xsl:namespace name="fn" select="'http://www.w3.org/2005/xpath-functions'"/>
                <xsl:for-each select="$this//*[not(namespace-uri() = ('','http://www.w3.org/2002/xforms',$default-namespace))][not(namespace-uri() = (ancestor::*/namespace-uri(),preceding::*/namespace-uri()))]">
                    <xsl:variable name="new-namespace" select="namespace-uri(.)"/>
                    <xsl:variable name="new-prefix-1" as="xs:string" select="substring-before(name(),':')"/>
                    <xsl:variable name="new-prefix" as="xs:string" select="if ($new-prefix-1 ne '') then $new-prefix-1 else ('ns' || fn:position())"/><xsl:namespace name="{$new-prefix}" select="$new-namespace"/>
                </xsl:for-each>
                <xsl:sequence select="$this/*/@*,$this/*/node()"/>
            </xsl:copy>
            
        </xsl:document>    
    </xsl:function>
    
    
    <xd:doc scope="component">
        <xd:desc>Write message to HTML page for the user. (Tried this as a function but got an error message relating to a "temporary output state")</xd:desc>
        <xd:param name="message">String message.</xd:param>
        <xd:param name="level">Optional string indicating level of severity, e.g. "error". Default value is "info".</xd:param>
    </xd:doc>
    <xsl:template name="logToPage">
        <xsl:param name="message" as="xs:string"/>
        <xsl:param name="level" as="xs:string" required="no" select="'info'"/>
        
        <xsl:result-document href="#{$xform-html-id}" method="ixsl:append-content">
            <div class="message-{$level}">
                <p>
                    <b>
                        <xsl:sequence select="concat(upper-case($level),': ')"/>
                    </b>
                    <xsl:sequence select="$message"/>
                </p>
            </div>
        </xsl:result-document>
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>Find string in HTML @class attribute.</xd:desc>
        <xd:return>True if $string is one of the values of $class</xd:return>
        <xd:param name="element">HTML element that may have a @class attribute (e.g. class="block incremental")</xd:param>
        <xd:param name="string">String to match in class (e.g. "incremental")</xd:param>
    </xd:doc>
    <xsl:function name="xforms:hasClass" as="xs:boolean">
        <xsl:param name="element" as="element()"/>
        <xsl:param name="string" as="xs:string"/>
        
        <xsl:variable name="class" as="xs:string?" select="$element/@class"/>
        <xsl:variable name="classes" as="xs:string*" select="tokenize($class)"/>
        <xsl:choose>
            <xsl:when test="$string = $classes">
                <xsl:value-of select="true()"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="false()"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>From an XPath binding expression, return the ID of the referenced instance.</xd:p>
            <xd:p>If the expression starts instance('xxxx') the value is 'xxxx'.</xd:p>
            <xd:p>Otherwise, the value is the $default-instance-id</xd:p>
        </xd:desc>
        <xd:param name="nodeset">XPath binding expression</xd:param>
    </xd:doc>
    <xsl:function name="xforms:getInstanceId" as="xs:string">
        <!-- TEST-TRACE: accept empty-sequence callers and fall back to default instance ID
             instead of raising a cardinality error; helps tests/supplemental/xforms-fiddle.spec.ts
             "refreshing same bind-heavy source twice does not fail". -->
        <xsl:param name="nodeset" as="xs:string?"/>
        
        <xsl:variable name="nodeset-normalized" as="xs:string" select="normalize-space(($nodeset,'')[1])"/>
        
        <xsl:choose>
            <xsl:when test="$nodeset-normalized = ''">
                <xsl:sequence select="$global-default-instance-id"/>
            </xsl:when>
            <xsl:when test="matches($nodeset-normalized, &quot;^instance\s*\(\s*'[^']+'\s*\).*&quot;)">
                <xsl:sequence select="replace($nodeset-normalized, &quot;^instance\s*\(\s*'([^']+)'\s*\).*$&quot;, '$1')"/>
            </xsl:when>
            <xsl:when test="matches($nodeset-normalized, '^instance\s*\(\s*&quot;[^&quot;]+&quot;\s*\).*')">
                <xsl:sequence select="replace($nodeset-normalized, '^instance\s*\(\s*&quot;([^&quot;]+)&quot;\s*\).*$', '$1')"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:sequence select="$global-default-instance-id"/>
            </xsl:otherwise>
        </xsl:choose>
       
    </xsl:function>
    
    <xd:doc scope="component">
        <xd:desc>Get HTML @class for rendering by combining @class set on XForms control and values determined by relevant status etc.  
            This template may be called during initial evaluation of the form or when refreshing outputs. In the latter case the original form control is lostd, so we need to use parameters for some fields. These are supplied either from the original form control, or from its registered properties when refreshing outputs.
        </xd:desc>
        <xd:param name="context-nodeset">XPath for context of class, in case class contains relative XPath</xd:param>
        <xd:param name="instance-context">Context instance ID, for XPath evaluation</xd:param>
        <xd:param name="source-class">Initial @class value from form control. If present, we will override an existing @class. This happens when refreshing outputs, where this template is applied to an HTML element instead of a form control.</xd:param>
        <xd:param name="additional-values">Optional sequence of strings to be included in the output as class values</xd:param>
        <xd:param name="incremental">Value of form control's @incremental attribute</xd:param>
    </xd:doc>
    <xsl:template name="getHtmlClass" as="xs:string">
        <xsl:param name="context-nodeset" as="xs:string?" tunnel="yes"/>
        <xsl:param name="instance-context" as="xs:string?" tunnel="yes"/>
        <xsl:param name="source-class" as="xs:string?"/>
        <xsl:param name="additional-values" as="xs:string*"/>
        <xsl:param name="incremental" as="xs:string?"/>
        
        <xsl:message use-when="$debugMode">[getHtmlClass] START</xsl:message>
        
        
        
        <xsl:message use-when="$debugMode">[getHtmlClass] Evaluating @class attribute: '<xsl:value-of select="$source-class"/>'</xsl:message>
        
        <xsl:variable name="class" as="xs:string?" select="if (exists($source-class) and exists($instance-context) and $instance-context ne '') then xforms:evaluate-string($source-class,$context-nodeset,$instance-context) else $source-class"/>
        
        
        <xsl:message use-when="$debugMode">[getHtmlClass] @class = '<xsl:sequence select="$class"/>'</xsl:message>
        
        <!-- TEST-TRACE: when refreshed validation classes are supplied, drop stale mutually-exclusive validation tokens from class-source; helps tests/supplemental/saxon-forms-validation.spec.ts "correcting invalid value removes xforms-invalid". -->
        <xsl:variable name="replace-validity-state" as="xs:boolean" select="some $v in $additional-values satisfies $v = ('xforms-valid','xforms-invalid')"/>
        <xsl:variable name="replace-required-state" as="xs:boolean" select="some $v in $additional-values satisfies $v = ('xforms-required','xforms-optional')"/>
        <xsl:variable name="source-class-values" as="xs:string*" select="
            for $token in fn:tokenize($class,'\s+')
            return
                if (normalize-space($token) = '')
                then ()
                else (
                    if ($replace-validity-state and $token = ('xforms-valid','xforms-invalid'))
                    then ()
                    else (
                        if ($replace-required-state and $token = ('xforms-required','xforms-optional'))
                        then ()
                        else $token
                    )
                )"/>
        <xsl:variable name="class-mod-raw" as="xs:string*">
            <xsl:sequence select="$source-class-values"/>
            <!-- include any additional "seed" values -->
            <xsl:sequence select="$additional-values"/>
            <xsl:if test="$incremental eq 'true'">
                <xsl:sequence select="'incremental'"/>
            </xsl:if>
         </xsl:variable>
        <!-- TEST-TRACE: keep refresh class composition stable by removing duplicate class tokens while preserving first-seen order; helps tests/supplemental/demo-schema-validation.spec.ts "repeated submit keeps validation class tokens unique". -->
        <xsl:variable name="class-mod" as="xs:string*" select="
            let $filtered := $class-mod-raw[normalize-space(.) ne '']
            return
                for $pos in 1 to count($filtered)
                return
                    if (some $prev in subsequence($filtered,1,$pos - 1) satisfies $prev = $filtered[$pos])
                    then ()
                    else $filtered[$pos]"/>
        
        <xsl:sequence select="string-join($class-mod,' ')"/>
        
        <xsl:message use-when="$debugMode">[getHtmlClass] END</xsl:message>
        
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Copy custom data-* attributes from an XForms control to its rendered HTML element.</xd:p>
            <xd:p>Internal Saxon-Forms data-* attributes are excluded to avoid duplicate-name collisions.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template name="copy-custom-data-attributes">
        <xsl:copy-of select="@*[starts-with(local-name(), 'data-')][not(local-name() = ('data-ref','data-action','data-relevant','data-required','data-constraint','data-binding-type','data-type','data-mediatype','data-group-ref','data-instance-context','data-repeatable-context','data-count','data-repeat-item','data-switch-id','data-case-id-base'))]"/>
    </xsl:template>
    
    
    <xd:doc scope="component">
        <xd:desc>Identify when an XForms case (the context node) is "relevant". Supports the XForms <xd:a href="https://www.w3.org/TR/xforms11/#ui-switch-module">Switch module</xd:a>: "If multiple cases within a switch are marked as selected="true", the first selected case remains and all others are deselected. If none are selected, the first becomes selected."</xd:desc>
    </xd:doc>
    <xsl:template name="getCaseRelevantStatus" as="xs:boolean">
        <xsl:choose>
            <!-- If none are selected, the first becomes selected -->
            <xsl:when test="empty(../xforms:case[@selected eq 'true']) and empty(./preceding-sibling::xforms:case)">
                <xsl:sequence select="true()"/>
            </xsl:when>
            <!-- If multiple cases within a switch are marked as selected="true", the first selected case remain -->
            <xsl:when test=".[@selected eq 'true'] and empty(./preceding-sibling::xforms:case[@selected eq 'true'])">
                <xsl:sequence select="true()"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:sequence select="false()"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>Identify when an XForms control is "relevant".</xd:desc>
        <xd:param name="xformsControl">XForms control element, e.g. input, output. NOTE: could be an HTML rendering of such an element.</xd:param>
        <xd:param name="instanceField">XForms instance or instance field relevant to the control</xd:param>
        <xd:param name="binding">xforms:bind elements relevant to this control</xd:param>
    </xd:doc>
    <xsl:template name="getRelevantStatus" as="xs:boolean">
        <xsl:param name="xformsControl" as="element()" required="yes"/>
        <xsl:param name="instanceField" as="node()?"/>
        <xsl:param name="binding" as="element(xforms:bind)*" tunnel="yes"/>
        
        <xsl:variable name="time-id-ns-context" as="xs:string" select="concat('getRelevantStatus (get namespace context)) ', generate-id())"/>
        <xsl:sequence use-when="$debugTiming" select="js:startTime($time-id-ns-context)" />
        
        <xsl:variable name="namespace-context-item" as="node()" select="
            if (exists($instanceField))
            then (
            if ($instanceField[self::text() or self::attribute()])
            then ($instanceField/parent::*, /*)[1]
            else $instanceField
            )
            else /*"/>
        <!-- fallback was xforms:addNamespaceDeclarations(/*) which is SLOW -->
        
        <xsl:sequence use-when="$debugTiming" select="js:endTime($time-id-ns-context)" />
        
        <xsl:variable name="time-id-evaluate" as="xs:string" select="concat('getRelevantStatus (evaluate)) ', generate-id())"/>
        <xsl:sequence use-when="$debugTiming" select="js:startTime($time-id-evaluate)" />
        <xsl:choose>
            <xsl:when test="exists($binding) and exists($binding/@relevant) and exists($instanceField)">
                <!-- For attribute nodes, use the parent element as context for relevant evaluation -->
                <xsl:variable name="eval-context" as="node()" select="
                    if ($instanceField[self::attribute()])
                    then $instanceField/parent::*
                    else $instanceField"/>
                <!-- TEST-TRACE: try/catch guards XPath 3.1 type errors on relevant;
                     helps tests/w3c/ch06.spec.ts "6.1.5.a", "6.1.4.b" -->
                <xsl:try>
                    <xsl:evaluate xpath="xforms:impose($binding/@relevant)" context-item="$eval-context" namespace-context="$namespace-context-item"/>
                    <xsl:catch><xsl:sequence select="true()"/></xsl:catch>
                </xsl:try>
            </xsl:when>
            <!-- 
                No direct binding with @relevant found.  Walk up the instance
                tree and check whether any ANCESTOR node is bound with
                relevant="false()".  XForms 1.1 §6.1.4: "The default value of
                relevant is true(), and a node is only relevant when all of
                its ancestors are also relevant."
            -->
            <xsl:when test="exists($instanceField) and $instanceField[self::*]">
                <xsl:variable name="all-bindings" as="element(xforms:bind)*" select="js:getBindings()"/>
                <xsl:variable name="instance-root" as="element()" select="root($instanceField)"/>
                <!-- Check the node itself AND its ancestors for non-relevant bindings -->
                <xsl:variable name="ancestor-irrelevant" as="xs:boolean">
                    <xsl:iterate select="$instanceField/ancestor-or-self::*">
                        <xsl:param name="found" as="xs:boolean" select="false()"/>
                        <xsl:on-completion select="$found"/>
                        <xsl:variable name="anc" as="element()" select="."/>
                        <xsl:variable name="matching-bind" as="element(xforms:bind)?" select="
                            ($all-bindings[exists(@relevant)][
                                let $bn := xforms:impose(string(@nodeset))
                                return (some $n in xforms:evaluate-xpath-with-context-node($bn, $instance-root, ())
                                        satisfies $n is $anc)
                            ])[1]"/>
                        <xsl:choose>
                            <xsl:when test="exists($matching-bind)">
                                <xsl:variable name="rel" as="xs:boolean">
                                    <xsl:try>
                                        <xsl:evaluate xpath="xforms:impose($matching-bind/@relevant)" context-item="$anc" namespace-context="$namespace-context-item"/>
                                        <xsl:catch>
                                            <xsl:sequence select="true()"/>
                                        </xsl:catch>
                                    </xsl:try>
                                </xsl:variable>
                                <xsl:choose>
                                    <xsl:when test="not($rel)">
                                        <xsl:break select="true()"/>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:next-iteration>
                                            <xsl:with-param name="found" select="false()"/>
                                        </xsl:next-iteration>
                                    </xsl:otherwise>
                                </xsl:choose>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:next-iteration>
                                    <xsl:with-param name="found" select="$found"/>
                                </xsl:next-iteration>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:iterate>
                </xsl:variable>
                <xsl:sequence select="not($ancestor-irrelevant)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:sequence select="true()"/>
            </xsl:otherwise>
        </xsl:choose>
        
        <xsl:sequence use-when="$debugTiming" select="js:endTime($time-id-evaluate)" />
        
    </xsl:template>

    <xd:doc scope="component">
        <xd:desc>Update HTML display elements corresponding to xforms:output elements</xd:desc>
    </xd:doc>
    <xsl:template name="refreshOutputs-JS">
        <xsl:message use-when="$debugMode">[refreshOutputs-JS] START</xsl:message>
        
        <xsl:variable name="namespace-context-item" as="element()" select="js:getXForm()"/>
        
        <!-- get all registered outputs -->
        <!-- MD 2018-06-30 : want to use as="xs:string*" but get a cardinality error!? 
        JS data typing thing?
        -->
        <xsl:variable name="output-keys-raw" select="js:getOutputKeys()" as="item()*"/>
        <!-- TEST-TRACE: Saxon-JS may surface JS arrays as XDM arrays (function items);
             normalize to plain string key sequence before iteration;
             helps tests/supplemental/issues.spec.ts "Issue #29", "Issue #30", "Issue #31". -->
        <xsl:variable name="output-keys" as="xs:string*" select="
            for $k in $output-keys-raw
            return
                if ($k instance of array(*))
                then (
                    for $m in $k?*
                    return
                        if ($m instance of function(*))
                        then ()
                        else string($m)
                )
                else (
                    if ($k instance of function(*))
                    then ()
                    else string($k)
                )"/>
        
        <xsl:for-each select="$output-keys">
            <xsl:variable name="this-key" as="xs:string" select="."/>
            <xsl:variable name="this-output-raw" as="item()*" select="js:getOutput($this-key)"/>
            <!-- TEST-TRACE: Saxon-JS may wrap XDM maps crossing JS boundaries as {'value': <map>};
                 unwrap so refresh metadata lookups (@value/@ref/etc.) continue to work.
                 Helps tests/supplemental/issues.spec.ts "Issue #29", "Issue #31". -->
            <xsl:variable name="this-output" as="item()*" select="
                let $wrapped := xforms:safe-map-get($this-output-raw,'value')
                return
                    if ($wrapped instance of map(*))
                    then $wrapped
                    else (
                        if ($wrapped instance of array(*))
                        then ((for $m in $wrapped?* return if ($m instance of map(*)) then $m else ())[1], $this-output-raw)[1]
                        else $this-output-raw
                    )"/>
            <xsl:try>
            
            <xsl:variable name="log-label" as="xs:string" select="'[refreshOutputs-JS]'"/>
            <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> Refreshing output ID = '<xsl:sequence select="$this-key"/>'</xsl:message>
            
            <xsl:variable name="associated-form-control" select="ixsl:page()//*[@id = $this-key]" as="node()?"/>
            
            
            <xsl:variable name="value-expression-item" as="item()*" select="xforms:safe-map-get($this-output,'@value')"/>
            <xsl:variable name="value-expression-map" as="xs:string?" select="
                if (empty($value-expression-item))
                then ()
                else (
                    if ($value-expression-item[1] instance of function(*))
                    then ()
                    else string($value-expression-item[1])
                )"/>
            <xsl:variable name="value-expression-dom" as="xs:string?" select="
                if (exists($associated-form-control/@data-value) and normalize-space(string($associated-form-control/@data-value)) ne '')
                then string($associated-form-control/@data-value)
                else ()"/>
            <xsl:variable name="value-expression" as="xs:string?" select="($value-expression-map,$value-expression-dom)[1]"/>
            <xsl:variable name="ref-expression-item" as="item()*" select="xforms:safe-map-get($this-output,'@ref')"/>
            <xsl:variable name="ref-expression-map" as="xs:string?" select="
                if (empty($ref-expression-item))
                then ()
                else (
                    if ($ref-expression-item[1] instance of function(*))
                    then ()
                    else string($ref-expression-item[1])
                )"/>
            <xsl:variable name="ref-expression-dom" as="xs:string?" select="
                if (exists($associated-form-control/@data-ref) and normalize-space(string($associated-form-control/@data-ref)) ne '')
                then string($associated-form-control/@data-ref)
                else ()"/>
            <xsl:variable name="ref-expression" as="xs:string?" select="($ref-expression-map,$ref-expression-dom)[1]"/>
            <xsl:variable name="value-expression-mod" as="xs:string?" select="
                if (exists($value-expression) and normalize-space($value-expression) ne '')
                then 'string(' || $value-expression || ')'
                else ()"/>
            
            <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> @value = '<xsl:sequence select="$value-expression"/>'; @ref = '<xsl:sequence select="$ref-expression"/>'</xsl:message>
                                    
            <xsl:variable name="this-instance-id-item" as="item()*" select="xforms:safe-map-get($this-output,'@instance-context')"/>
            <xsl:variable name="this-instance-id-dom" as="xs:string?" select="
                if (exists($associated-form-control/@instance-context) and normalize-space(string($associated-form-control/@instance-context)) ne '')
                then string($associated-form-control/@instance-context)
                else ()"/>
            <xsl:variable name="this-instance-id" as="xs:string" select="
                if (exists($this-instance-id-item[1]) and not($this-instance-id-item[1] instance of function(*)))
                then string($this-instance-id-item[1])
                else (
                    if (exists($this-instance-id-dom))
                    then $this-instance-id-dom
                    else $global-default-instance-id
                )"/>
            
            <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> $this-instance-id = '<xsl:sequence select="$this-instance-id"/>'</xsl:message>            
            <!-- 
                If value returned from unmodified XPath is a boolean
                the string value is '' for false() or 'true' for true()
            -->
            <xsl:variable name="ref-evaluated-items" as="item()*" select="
                if (exists($ref-expression) and normalize-space($ref-expression) ne '')
                then xforms:evaluate-xpath-with-instance-id($ref-expression,$this-instance-id,())
                else ()"/>
            <xsl:variable name="value-primary" as="xs:string?" select="
                if (exists($value-expression-mod))
                then xforms:evaluate-xpath-with-instance-id($value-expression-mod,$this-instance-id,())
                else (
                    if (exists($ref-expression) and normalize-space($ref-expression) ne '')
                    then (
                        if (($ref-evaluated-items)[1] instance of function(*))
                        then ''
                        else string(($ref-evaluated-items)[1])
                    )
                    else ''
                )"/>
            <!-- TEST-TRACE: fallback for output refresh when instance()-qualified refs
                 cannot be evaluated in-place; resolve relative to the instance root.
                 Helps tests/w3c/ch08.spec.ts "8.3.3.b", "8.3.3.c". -->
            <!-- TEST-TRACE: fix instance() prefix stripping regex escaping so fallback
                 removes instance('...') correctly; helps tests/w3c/ch08.spec.ts "8.3.3.b", "8.3.3.c". -->
            <xsl:variable name="ref-for-fallback" as="xs:string?" select="$ref-expression"/>
            <xsl:variable name="ref-local-fallback" as="xs:string?" select="
                if (exists($ref-for-fallback))
                then
                    replace(
                        replace(normalize-space($ref-for-fallback),
                            '^instance\s*\(\s*''[^'']+''\s*\)\s*/?', ''),
                        '^instance\s*\(\s*&quot;[^&quot;]+&quot;\s*\)\s*/?', '')
                else ()"/>
            <xsl:variable name="value-fallback" as="xs:string?" select="
                if (exists($ref-local-fallback) and $ref-local-fallback ne '' and exists(xforms:instance($this-instance-id)))
                then xforms:evaluate-xpath-with-context-node('string(' || $ref-local-fallback || ')', xforms:instance($this-instance-id), ())
                else ()"/>
            <xsl:variable name="value" as="xs:string?" select="
                if (exists($value-primary) and string($value-primary) ne '')
                then $value-primary
                else (
                    if (exists($value-fallback))
                    then $value-fallback
                    else $value-primary
                )"/>
            
            <xsl:variable name="data-type-item" as="item()*" select="xforms:safe-map-get($this-output,'@data-type')"/>
            <xsl:variable name="data-type" as="xs:string?" select="
                if (empty($data-type-item))
                then (
                    if (exists($associated-form-control/@data-type))
                    then string($associated-form-control/@data-type)
                    else ()
                )
                else (
                    if ($data-type-item[1] instance of function(*))
                    then ()
                    else string($data-type-item[1])
                )"/>
            
            <xsl:variable name="itemset-item" as="item()*" select="xforms:safe-map-get($this-output,'itemset')"/>
            <xsl:variable name="itemset" as="element(xforms:itemset)?" select="if ($itemset-item[1] instance of element(xforms:itemset)) then $itemset-item[1] else ()"/>
                        
            <xsl:choose>
                <xsl:when test="exists($associated-form-control) and local-name($associated-form-control) = ('input') and $data-type eq 'checkbox'">
                    <xsl:sequence select="js:setCheckboxValue($this-key,$value)"/>
                </xsl:when>
                
                <xsl:when test="exists($associated-form-control) and local-name($associated-form-control) = ('input','select','select1')">
                    <!-- update itemset before calling js:setValue -->
                    <xsl:if test="exists($itemset)">
                        <xsl:result-document href="#{$this-key}" method="ixsl:replace-content">
                            <xsl:apply-templates select="$itemset" mode="get-html">
                                <xsl:with-param name="default-namespace-context" select="$namespace-context-item" tunnel="yes"/>
                            </xsl:apply-templates>
                        </xsl:result-document>
                    </xsl:if>
                    
                    <xsl:sequence select="js:setValue($this-key,$value)"/>
                    
                    
                    
                </xsl:when>
                <xsl:when test="exists($associated-form-control) and $associated-form-control/@data-xf-component = 'true'">
                    <xsl:sequence select="js:setValue($this-key,$value)"/>
                </xsl:when>
                <xsl:when test="exists($associated-form-control) and local-name($associated-form-control) = ('iframe')">
                    <xsl:sequence select="js:setSrc($this-key,$value)"/>
                </xsl:when>
                <xsl:when test="exists($associated-form-control)">
                    <ixsl:set-property name="textContent" select="string($value)" object="$associated-form-control"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:message use-when="$debugMode">[refreshOutputs-JS] Can't find form control with ID '<xsl:sequence select="$this-key"/>'</xsl:message>
                    <xsl:sequence select="js:removeOutput($this-key)"/>
                </xsl:otherwise>
            </xsl:choose>
            
            <!-- update class (value may include XPath) -->
            
            <xsl:variable name="xforms-class-item" as="item()*" select="xforms:safe-map-get($this-output,'@class')"/>
            <xsl:variable name="xforms-class" as="xs:string?" select="
                if (empty($xforms-class-item))
                then (
                    if (exists($associated-form-control/@class))
                    then string($associated-form-control/@class)
                    else ()
                )
                else (
                    if ($xforms-class-item[1] instance of function(*))
                    then ()
                    else string($xforms-class-item[1])
                )"/>
            <xsl:variable name="context-nodeset-item" as="item()*" select="xforms:safe-map-get($this-output,'@context-nodeset')"/>
            <xsl:variable name="context-nodeset" as="xs:string?" select="
                if (empty($context-nodeset-item))
                then (
                    if (exists($associated-form-control/@data-ref))
                    then string($associated-form-control/@data-ref)
                    else ()
                )
                else (
                    if ($context-nodeset-item[1] instance of function(*))
                    then ()
                    else string($context-nodeset-item[1])
                )"/>
            <!-- TEST-TRACE: @additional-class-values may roundtrip via JS as an XDM array;
                 flatten and ignore callable items before distinct-values/class rebuild. -->
            <xsl:variable name="additional-class-values" as="xs:string*" select="
                for $v in xforms:safe-map-get($this-output,'@additional-class-values')
                return
                    if ($v instance of array(*))
                    then (
                        for $m in $v?*
                        return
                            if ($m instance of function(*))
                            then ()
                            else string($m)
                    )
                    else (
                        if ($v instance of function(*))
                        then ()
                        else string($v)
                    )"/>
            <xsl:variable name="incremental-item" as="item()*" select="xforms:safe-map-get($this-output,'@incremental')"/>  
            <xsl:variable name="incremental" as="xs:string?" select="
                if (empty($incremental-item))
                then (
                    if (exists($associated-form-control/@class) and contains(concat(' ', string($associated-form-control/@class), ' '), ' incremental '))
                    then 'true'
                    else ()
                )
                else (
                    if ($incremental-item[1] instance of function(*))
                    then ()
                    else string($incremental-item[1])
                )"/>
            <xsl:variable name="ref-for-mips" as="xs:string?" select="$ref-expression"/>
            <xsl:variable name="mip-valid-token" as="xs:string?" select="
                if (exists($ref-for-mips) and normalize-space($ref-for-mips) ne '')
                then normalize-space(string(js:getValidationMIPValid($this-instance-id,normalize-space($ref-for-mips))))
                else ()"/>
            <xsl:variable name="mip-valid" as="xs:boolean?" select="
                if (exists($mip-valid-token) and $mip-valid-token = ('true','false'))
                then xs:boolean($mip-valid-token)
                else ()"/>
            <xsl:variable name="mip-required-token" as="xs:string?" select="
                if (exists($ref-for-mips) and normalize-space($ref-for-mips) ne '')
                then normalize-space(string(js:getValidationMIPRequired($this-instance-id,normalize-space($ref-for-mips))))
                else ()"/>
            <xsl:variable name="mip-required" as="xs:boolean?" select="
                if (exists($mip-required-token) and $mip-required-token = ('true','false'))
                then xs:boolean($mip-required-token)
                else ()"/>
            <xsl:variable name="control-visited" as="xs:boolean" select="
                if (exists($ref-for-mips) and normalize-space($ref-for-mips) ne '')
                then js:isControlVisited($this-instance-id,normalize-space($ref-for-mips))
                else false()"/>
            <xsl:variable name="show-full-feedback" as="xs:boolean" select="js:isForceFullValidationFeedback()"/>
            <xsl:variable name="show-validation-feedback" as="xs:boolean" select="$show-full-feedback or $control-visited"/>
            <xsl:variable name="validation-class-values" as="xs:string*" select="
                if ($show-validation-feedback)
                then (
                    if (exists($mip-valid)) then (if ($mip-valid) then 'xforms-valid' else 'xforms-invalid') else (),
                    if (exists($mip-required)) then (if ($mip-required) then 'xforms-required' else 'xforms-optional') else ()
                )
                else ()"/>
            <xsl:variable name="effective-additional-class-values" as="xs:string*" select="distinct-values(($additional-class-values,$validation-class-values))"/>
            
            <xsl:variable name="htmlClass" as="xs:string?">
                <xsl:call-template name="getHtmlClass">
                    <xsl:with-param name="context-nodeset" select="$context-nodeset" tunnel="yes"/>
                    <xsl:with-param name="instance-context" select="$this-instance-id" tunnel="yes"/>
                    <xsl:with-param name="source-class" select="$xforms-class"/>
                    <xsl:with-param name="additional-values" select="$effective-additional-class-values"/>
                    <xsl:with-param name="incremental" select="$incremental"/>
                </xsl:call-template>
            </xsl:variable>
            
            <xsl:if test="exists($associated-form-control)">
                <ixsl:set-attribute name="class" select="$htmlClass" object="$associated-form-control"/>
                <xsl:if test="exists($associated-form-control/parent::*) and matches(local-name($associated-form-control), '^(input|select|textarea)$')">
                    <ixsl:set-attribute name="class" select="$htmlClass" object="$associated-form-control/parent::*"/>
                </xsl:if>
            </xsl:if>
            <xsl:catch>
                <xsl:message>[refreshOutputs-JS] WARNING: skipping output key '<xsl:value-of select="$this-key"/>' due to refresh error code=<xsl:value-of select="$err:code"/> description=<xsl:value-of select="$err:description"/></xsl:message>
                <xsl:sequence select="js:removeOutput($this-key)"/>
            </xsl:catch>
            </xsl:try>
            
        </xsl:for-each>
        
        <xsl:message use-when="$debugMode">[refreshOutputs-JS] END</xsl:message>
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>Update HTML display elements corresponding to xforms:repeat elements</xd:desc>
    </xd:doc>
    <xsl:template name="refreshRepeats-JS">      
        <xsl:variable name="log-label" as="xs:string" select="'[refreshRepeats-JS]'"/>
        <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> START</xsl:message>
              
        <xsl:variable name="repeat-keys-raw" select="js:getRepeatKeys()" as="item()*"/>
        <!-- TEST-TRACE: normalize potential XDM-array return from JS Object.keys() -->
        <xsl:variable name="repeat-keys" as="xs:string*" select="
            for $k in $repeat-keys-raw
            return
                if ($k instance of array(*))
                then (
                    for $m in $k?*
                    return
                        if ($m instance of function(*))
                        then ()
                        else string($m)
                )
                else (
                    if ($k instance of function(*))
                    then ()
                    else string($k)
                )"/>
        
        <xsl:variable name="namespace-context-item" as="element()" select="js:getXForm()"/>
        
        <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> $namespace-context-item: <xsl:sequence select="name($namespace-context-item)"/></xsl:message>
        
        <xsl:for-each select="$repeat-keys">
            <xsl:variable name="this-key" as="xs:string" select="."/>
            <xsl:variable name="this-repeat" as="element()" select="js:getRepeat($this-key)"/>
            <xsl:variable name="this-repeat-nodeset" as="xs:string" select="js:getRepeatContext($this-key)"/>
            <xsl:variable name="this-repeat-model" as="xs:string" select="js:getRepeatModelContext($this-key)"/>
            
            <!-- TEST-TRACE: PERF-6a – skip repeats bound to instances that were not
                 mutated in this action cycle.  When no dirty instances are recorded
                 (e.g. after a full reset) we fall back to refreshing every repeat. -->
            <xsl:variable name="this-repeat-instance-id" as="xs:string"
                select="js:getRepeatInstanceId($this-key)"/>
            <xsl:if test="not(js:hasDirtyInstances()) or js:isDirtyInstance($this-repeat-instance-id)">
            
            <xsl:variable name="page-element" select="ixsl:page()//*[@id = $this-key]" as="node()?"/>
            
            <!-- PERF-6b: check for a pending append mutation on this repeat's instance -->
            <xsl:variable name="pending-append-pos" as="xs:double"
                select="js:getPendingAppendForInstance($this-repeat-instance-id)"/>
            <xsl:variable name="current-repeat-size" as="xs:double"
                select="(js:getRepeatSize($this-key), 0)[1]"/>
            <xsl:variable name="this-repeat-ref" as="xs:string?"
                select="js:getRepeatRef($this-key)"/>
            <xsl:variable name="live-repeat-size" as="xs:double"
                select="
                    if (exists($this-repeat-ref) and $this-repeat-ref ne '')
                    then count(xforms:evaluate-xpath-with-instance-id($this-repeat-ref,$this-repeat-instance-id,()))
                    else 0"/>
            
            <xsl:choose>
                <!-- PERF-6b fast path: only valid for a single-item append.
                     If multiple appends occurred in one action cycle, fall back
                     to full re-render to avoid dropping intermediate items. -->
                <xsl:when test="exists($page-element)
                                and $pending-append-pos = $current-repeat-size + 1
                                and $live-repeat-size = $current-repeat-size + 1">
                    <xsl:result-document href="#{$this-key}" method="ixsl:append-content">
                        <xsl:apply-templates select="$this-repeat">
                            <xsl:with-param name="model-key" select="$this-repeat-model" tunnel="yes"/>
                            <xsl:with-param name="nodeset" select="$this-repeat-nodeset" tunnel="yes"/>
                            <xsl:with-param name="recalculate" select="true()" tunnel="yes"/>
                            <xsl:with-param name="refreshRepeats" select="fn:true()" tunnel="yes"/>
                            <xsl:with-param name="default-namespace-context" select="$namespace-context-item" tunnel="yes"/>
                            <xsl:with-param name="splice-position" select="xs:integer($pending-append-pos)" tunnel="yes"/>
                        </xsl:apply-templates>
                    </xsl:result-document>
                    <!-- Update data-count attribute on the repeat container -->
                    <ixsl:set-attribute name="data-count"
                        select="string(xs:integer($pending-append-pos))"
                        object="$page-element"/>
                    <xsl:sequence select="js:setRepeatSize($this-key, xs:integer($pending-append-pos))"/>
                </xsl:when>
                <!-- Full re-render (non-append mutations or no pending mutation) -->
                <xsl:when test="exists($page-element)">
                    <xsl:result-document href="#{$this-key}" method="ixsl:replace-content">
                        <xsl:apply-templates select="$this-repeat">
                            <xsl:with-param name="model-key" select="$this-repeat-model" tunnel="yes"/>
                            <xsl:with-param name="nodeset" select="$this-repeat-nodeset" tunnel="yes"/>
                            <xsl:with-param name="recalculate" select="true()" tunnel="yes"/>
                            <xsl:with-param name="refreshRepeats" select="fn:true()" tunnel="yes"/>
                            <xsl:with-param name="default-namespace-context" select="$namespace-context-item" tunnel="yes"/>
                        </xsl:apply-templates>
                    </xsl:result-document>
                </xsl:when>
                <xsl:otherwise/>
            </xsl:choose>
            
            </xsl:if>
        </xsl:for-each>
        
        <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> END</xsl:message>
    </xsl:template>
 
 
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Check fields with @relevant binding (part of a xforms-refresh event.)</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template name="refreshRelevantFields-JS">
        <xsl:message use-when="$debugMode">[refreshRelevantFields-JS] START</xsl:message>
        
        <!-- go through all form controls where @data-relevant has been set -->
        <xsl:for-each select="ixsl:page()//*[@data-relevant]">
            <xsl:variable name="context-node" as="node()?" select="xforms:evaluate-xpath-with-instance-id(string(@data-ref),string(@instance-context),())"/>
            <xsl:variable name="relevantStatus" as="xs:boolean" select="if (exists($context-node)) then xforms:evaluate-xpath-with-context-node(string(@data-relevant),$context-node,()) else false()"/>
            <!-- 
                div containing span, input, etc. with its label (HTML <label> generated from <xforms:label>)
            -->
            <xsl:variable name="htmlWrapper" as="element()?" select="./parent::*"/>
            
            <!--<xsl:variable name="htmlClass" as="xs:string?">
                <xsl:call-template name="getHtmlClass">
                    
                </xsl:call-template>
            </xsl:variable>-->
            
           <!-- <ixsl:set-attribute name="class" select="$htmlClass" object="."/>
            <xsl:if test="exists($htmlWrapper)">
                <ixsl:set-attribute name="class" select="$htmlClass" object="$htmlWrapper"/>
            </xsl:if>-->
            
            <xsl:choose>
                <xsl:when test="$relevantStatus">
                    <xsl:if test="ixsl:style(.)?display = 'none'">
                        <xsl:message use-when="$debugMode">[refreshRelevantFields-JS] removing display="none"</xsl:message>
                        <ixsl:remove-property name="style.display" object="."/>
                        <ixsl:remove-attribute name="style" object="."/>
                    </xsl:if>
                    <!-- 
                        Change setting on parent as well
                        HTML for <xf:output> includes parent <span> containing rendering of label
                    -->
                    <xsl:if test="exists($htmlWrapper) and ixsl:style($htmlWrapper)?display = 'none'">
                        <xsl:message use-when="$debugMode">[refreshRelevantFields-JS] removing display="none" from parent</xsl:message>
                        <ixsl:remove-property name="style.display" object="$htmlWrapper"/>
                        <ixsl:remove-attribute name="style" object="$htmlWrapper"/>
                    </xsl:if>
                </xsl:when>
                <xsl:otherwise>
                    <ixsl:set-style name="display" select="'none'" object="."/>
                    <xsl:if test="exists($htmlWrapper)">
                        <ixsl:set-style name="display" select="'none'" object="$htmlWrapper"/>
                    </xsl:if>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
        
        <!-- reevaluate xf:group wrappers that rely on @ref existence -->
        <xsl:for-each select="ixsl:page()//*[@data-group-ref and @data-instance-context]">
            <xsl:variable name="group-ref" as="xs:string" select="string(@data-group-ref)"/>
            <xsl:variable name="group-instance-context" as="xs:string" select="string(@data-instance-context)"/>
            <xsl:variable name="group-context-nodes" as="item()*" select="xforms:evaluate-xpath-with-instance-id($group-ref,$group-instance-context,())"/>
            <xsl:variable name="group-relevant" as="xs:boolean" select="exists($group-context-nodes)"/>
            <xsl:choose>
                <xsl:when test="$group-relevant">
                    <xsl:if test="ixsl:style(.)?display = 'none'">
                        <ixsl:remove-property name="style.display" object="."/>
                        <ixsl:remove-attribute name="style" object="."/>
                    </xsl:if>
                </xsl:when>
                <xsl:otherwise>
                    <ixsl:set-style name="display" select="'none'" object="."/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
        
        <xsl:message use-when="$debugMode">[refreshRelevantFields-JS] END</xsl:message>
        
     </xsl:template>
    
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Update HTML display elements corresponding to XForms elements that use the index() function</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template name="refreshElementsUsingIndexFunction-JS">
        <xsl:message use-when="$debugMode">[refreshElementsUsingIndexFunction-JS] START</xsl:message>
        
        <xsl:variable name="ElementsUsingIndexFunction-keys-raw" select="js:getElementsUsingIndexFunctionKeys()" as="item()*"/>    
        <!-- TEST-TRACE: normalize potential XDM-array return from JS Object.keys() -->
        <xsl:variable name="ElementsUsingIndexFunction-keys" as="xs:string*" select="
            for $k in $ElementsUsingIndexFunction-keys-raw
            return
                if ($k instance of array(*))
                then (
                    for $m in $k?*
                    return
                        if ($m instance of function(*))
                        then ()
                        else string($m)
                )
                else (
                    if ($k instance of function(*))
                    then ()
                    else string($k)
                )"/>
        
        <xsl:variable name="namespace-context-item" as="element()" select="js:getXForm()"/>
        
                
        <xsl:for-each select="$ElementsUsingIndexFunction-keys">
            <xsl:variable name="this-key" as="xs:string" select="."/>
            
            <xsl:message use-when="$debugMode">[refreshElementsUsingIndexFunction-JS] Refreshing item with key '<xsl:sequence select="$this-key"/>'</xsl:message>
            
            <xsl:variable name="this-element" as="element()" select="js:getElementUsingIndexFunction($this-key)"/>
            
            <xsl:variable name="this-element-refi" as="xs:string" select="js:getElementContextUsingIndexFunction($this-key)"/>
            
            <xsl:message use-when="$debugMode">[refreshElementsUsingIndexFunction-JS] $this-element-refi = '<xsl:sequence select="$this-element-refi"/>'</xsl:message>
            <xsl:result-document href="#{$this-key}" method="ixsl:replace-content">
                <xsl:apply-templates select="$this-element/*">
                    <xsl:with-param name="nodeset" select="$this-element-refi" tunnel="yes"/>
                    <xsl:with-param name="recalculate" select="true()" tunnel="yes"/>
                    <xsl:with-param name="default-namespace-context" select="$namespace-context-item" tunnel="yes"/>
                </xsl:apply-templates>
            </xsl:result-document>
            
        </xsl:for-each>
        
    </xsl:template>
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Apply actions by calling the template appropriate to each action.</xd:p>
        </xd:desc>
        <xd:param name="action-map">Action map</xd:param>
    </xd:doc>
    <xsl:template name="applyActions">
        <xsl:param name="action-map" required="yes" as="map(*)" tunnel="yes"/>
        <xsl:param name="source-control" as="node()?" required="no" tunnel="yes"/>
        
        <xsl:variable name="log-label" select="'[applyActions]'"/>
        <xsl:message>[DIAG applyActions] name=<xsl:value-of select="map:get($action-map,'name')"/> handler-status=<xsl:value-of select="map:get($action-map,'handler-status')"/> event=<xsl:value-of select="map:get($action-map,'@event')"/></xsl:message>
        <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> START <xsl:sequence select="if(exists(map:get($action-map, '@event'))) then '(event ' || map:get($action-map, '@event') || ')' else ''"/><xsl:sequence select="'(action name ' || map:get($action-map, 'name') || ')'"/></xsl:message>
        
        <xsl:variable name="instance-context" select="map:get($action-map, 'instance-context')" as="xs:string"/>
        <xsl:variable name="handler-status" select="map:get($action-map, 'handler-status')" as="xs:string"/>
        <xsl:variable name="ref" select="map:get($action-map, '@ref')" as="xs:string?"/>
        <xsl:variable name="at" select="map:get($action-map, '@at')" as="xs:string?"/>
        <xsl:variable name="position" select="(map:get($action-map, '@position'),'after')[1]" as="xs:string"/>
        <xsl:variable name="context" select="map:get($action-map, '@context')" as="xs:string?"/>
        <xsl:variable name="event" select="map:get($action-map, '@event')" as="xs:string?"/>
        <xsl:if test="$sequence-template-trace-enabled">
            <xsl:message>[SEQTRACE] template=applyActions action=<xsl:value-of select="map:get($action-map,'name')"/> event=<xsl:value-of select="$event"/> handler=<xsl:value-of select="$handler-status"/></xsl:message>
        </xsl:if>
        
 
        <!--<xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> $action-map @ref = <xsl:sequence select="$ref"/></xsl:message>
        <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> $action-map @at = <xsl:sequence select="$at"/></xsl:message>
        <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> $action-map @position = <xsl:sequence select="$position"/></xsl:message>
        <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> $action-map @context = <xsl:sequence select="$context"/></xsl:message>-->
        
        
        <xsl:variable name="ref-qualified" as="xs:string?" select="
            if (exists($ref) and $ref != '')
            then (
                if (exists($at))
                then concat($ref, '[', $at, ']')
                else $ref
            )
            else ()
            "/>
        
        <xsl:variable name="instanceXML" as="element()?" select="xforms:instance($instance-context)"/>        
       
        <xsl:variable name="context-nodeset" as="node()*">
            <xsl:choose>
                <!-- try evaluating @context first -->
                <xsl:when test="exists($context) and not($context = '')">
                    <!--<xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> context node: <xsl:sequence select="fn:serialize($context)"/></xsl:message>-->
                    <xsl:sequence select="xforms:evaluate-xpath-with-context-node($context,$instanceXML,())"/>
                </xsl:when>
                <!-- then try evaluating @ref (qualified with @at) -->
                <xsl:when test="exists($ref-qualified) and not($ref-qualified = '')">
                    <xsl:sequence select="xforms:evaluate-xpath-with-context-node($ref-qualified,$instanceXML,())"/>
                </xsl:when>
                <!-- fall back to instance XML -->
                <xsl:otherwise>
                    <xsl:sequence select="$instanceXML"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:variable name="context-node" as="element()?">
            <xsl:variable name="context-first-item" as="node()?" select="$context-nodeset[1]"/>
            <xsl:sequence select="if ($context-first-item[not(self::*)]) then $context-first-item/parent::* else $context-first-item"/>
        </xsl:variable>
        
        <!--<xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> context node: <xsl:sequence select="fn:serialize($context)"/></xsl:message>-->
        
        <!-- TODO error testing of incorrect ref given in the xform (i.e. context would be empty in this case) -->

        <xsl:variable name="ifVar" as="xs:string?" select="xforms:getIfStatement($action-map)"/>      
        <xsl:variable name="whileVar" as="xs:string?" select="xforms:getWhileStatement($action-map)"/>
        <xsl:variable name="iterate-ref" as="xs:string?" select="xforms:getIterateStatement($action-map)"/>
        
        <!-- TODO if the action does not contain an if or while it should execute action -->
        <xsl:variable name="ifExecuted" as="xs:boolean">
            <xsl:choose>
                <xsl:when test="exists($ifVar) and exists($context-node) and empty($iterate-ref)">
                    <!-- don't evaluate 'if' statement if there's an iterate -->
                    <xsl:message use-when="$debugMode">[applyActions] applying @if = <xsl:sequence select="$ifVar"/> in context <xsl:sequence select="fn:serialize($context-node)"/></xsl:message>
                    <xsl:variable name="evaluation-result" select="xforms:evaluate-xpath-with-context-node($ifVar,$context-node,())"/>
                    <xsl:sequence select="boolean($evaluation-result)"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="true()" />
                </xsl:otherwise>
            </xsl:choose>                    
        </xsl:variable>
        
        <!--<xsl:message use-when="$debugMode">[applyActions] $ifExecuted = <xsl:sequence select="$ifExecuted"/></xsl:message>-->
                
        <xsl:variable name="isWhileTrue" as="xs:boolean">
            <xsl:choose>
                <xsl:when test="exists($whileVar) and exists($context-node)">
                    <xsl:variable name="evaluation-result" select="xforms:evaluate-xpath-with-context-node($whileVar,$context-node,())"/>
                    <xsl:sequence select="boolean($evaluation-result)"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="true()" />
                </xsl:otherwise>
            </xsl:choose>                    
        </xsl:variable>
        
        <!-- https://www.w3.org/TR/xforms11/#action -->
        <xsl:if test="$ifExecuted and $isWhileTrue">
            <xsl:variable name="action-name" as="xs:string" select="map:get($action-map,'name')"/>
            
            <xsl:choose>
                <xsl:when test="$action-name = 'action'">
                    <!-- xforms:action is just a wrapper -->
                </xsl:when>
                <xsl:when test="$action-name = 'setvalue'">
                    <xsl:call-template name="action-setvalue"/>
                </xsl:when>
                <xsl:when test="$action-name = 'insert'">
                     
                    <xsl:call-template name="action-insert"/>
                </xsl:when>
                <xsl:when test="$action-name = 'delete'">
                    <xsl:call-template name="action-delete"/>
                </xsl:when>
                <xsl:when test="$action-name = 'setindex'">
                    <xsl:call-template name="action-setindex"/>
                </xsl:when>
                <xsl:when test="$action-name = 'toggle'">
                    <xsl:call-template name="action-toggle">
                        <xsl:with-param name="context-node" select="$context-node"/>
                        <xsl:with-param name="source-control" select="$source-control"/>
                    </xsl:call-template>
                </xsl:when>
                <xsl:when test="$action-name = 'setfocus'">
                    <xsl:call-template name="action-setfocus"/>
                </xsl:when>
                <xsl:when test="$action-name = 'dispatch'">
                    <xsl:call-template name="action-dispatch"/>
                </xsl:when>
                <xsl:when test="$action-name = 'rebuild'">
                    <xsl:call-template name="xforms-rebuild"/>
                </xsl:when>
                <xsl:when test="$action-name = 'recalculate'">
                    <xsl:call-template name="xforms-recalculate"/>
                </xsl:when>
                <xsl:when test="$action-name = 'revalidate'">
                    <xsl:call-template name="action-revalidate"/>
                </xsl:when>
                <xsl:when test="$action-name = 'refresh'">
                    <xsl:call-template name="action-refresh"/>
                </xsl:when>
                <xsl:when test="$action-name = 'reset'">
                    <xsl:call-template name="action-reset"/>
                </xsl:when>
                <xsl:when test="$action-name = 'load'">
                    <xsl:call-template name="action-load"/>
                </xsl:when>
                <xsl:when test="$action-name = 'send'">
                    <xsl:call-template name="action-send"/>
                </xsl:when>
                <xsl:when test="$action-name = 'message'">
                    <xsl:call-template name="action-message"/>
                </xsl:when>
                <xsl:when test="$action-name = 'script'">
                    <xsl:call-template name="action-script"/>
                </xsl:when>
                <xsl:when test="$action-name = 'output'">
                    <xsl:call-template name="action-output">
                        <xsl:with-param name="context-node" select="$context-node"/>
                    </xsl:call-template>
                </xsl:when>
                <!-- special action for text content of xforms:message -->
                <xsl:when test="$action-name = 'text'">
                    <xsl:call-template name="action-text"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:message use-when="$debugMode">[applyActions] action '<xsl:value-of select="$action-name"/>' not yet handled!</xsl:message>
                </xsl:otherwise>
            </xsl:choose>
             
            
            <xsl:variable name="nested-actions-array" select="map:get($action-map, 'nested-actions')" as="array(map(*))?"/>
            <xsl:variable name="nested-actions" as="item()*">
                <xsl:sequence select="array:flatten($nested-actions-array)"/>
            </xsl:variable>
            
            <xsl:choose>
                <xsl:when test="$action-name = 'message'">
                    <!-- 
                        ignoring nested actions of xforms:message here - they are dealt with under action-message
                    -->
                </xsl:when>
                <xsl:otherwise>
                    <xsl:for-each select="$nested-actions">
                        <xsl:call-template name="applyActions">
                            <xsl:with-param name="action-map" select="." tunnel="yes"/>
                        </xsl:call-template>
                    </xsl:for-each>
                </xsl:otherwise>
            </xsl:choose>
            
            
            <xsl:variable name="isWhileStillTrue" as="xs:boolean">
                <xsl:choose>
                    <xsl:when test="exists($whileVar) and exists($context-node)">
                        <xsl:variable name="evaluation-result" select="xforms:evaluate-xpath-with-context-node($whileVar,$context-node,())"/>
                        <xsl:sequence select="boolean($evaluation-result)"/>
                     </xsl:when>
                    <xsl:otherwise>
                        <!-- 
                            don't go back round the loop unless there is a @while
                            and it is still true
                        -->
                        <xsl:sequence select="false()" />
                    </xsl:otherwise>
                </xsl:choose>                    
            </xsl:variable>
            
            <!-- TO DO: mitigate risk of recursion if possible -->
            <xsl:if test="$isWhileStillTrue">
                <xsl:call-template name="applyActions"/>
            </xsl:if>
            <xsl:if test="$handler-status = 'outermost' and not($event = ('xforms-rebuild','xforms-recalculate','xforms-revalidate','xforms-refresh','xforms-reset'))">
                <xsl:message>[DIAG outermost-call] from action=<xsl:value-of select="$action-name"/> handler-status=<xsl:value-of select="$handler-status"/> event=<xsl:value-of select="$event"/></xsl:message>
                <xsl:call-template name="outermost-action-handler"/>
            </xsl:if>
            
            
        </xsl:if>
       
        
        <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> END <xsl:sequence select="if(exists(map:get($action-map, '@event'))) then '(event ' || map:get($action-map, '@event') || ')' else ''"/><xsl:sequence select="'(action name ' || map:get($action-map, 'name') || ')'"/></xsl:message>
        
    </xsl:template>
    
    

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>registerOutput: create map of an xforms:output (or xforms:input) whose value may be updated e.g. during an xforms-refresh. This element is the context node.</xd:p>
        </xd:desc>
        <xd:param name="id">ID of HTML element.</xd:param>
        <xd:param name="nodeset">XPath binding expression</xd:param>
        <xd:param name="context-nodeset">XPath binding expression for context node (used if @value contains context() function)</xd:param>
        <xd:param name="instance-context">ID of XForms instance relevant to this control</xd:param>
        <xd:param name="data-type">String identifying data type of an input. Required to support setting its value in the appropriate way</xd:param>
        <xd:param name="additional-class-values">Any additional class values we want to set. Need to register them here so they can be applied again when refreshing outputs.</xd:param>
    </xd:doc>
    <xsl:template name="registerOutput">
        <xsl:param name="id" as="xs:string" tunnel="yes"/>
        <xsl:param name="nodeset" as="xs:string" tunnel="yes"/>
        <xsl:param name="context-nodeset" as="xs:string" tunnel="yes"/>
        <xsl:param name="instance-context" as="xs:string" tunnel="yes"/>
        <xsl:param name="data-type" as="xs:string" required="no" select="''"/>
        <xsl:param name="additional-class-values" as="xs:string*"/>
        <xsl:variable name="time-id-register-outputs" as="xs:string" select="concat('registerOutput ', generate-id())"/>
        
        <xsl:sequence use-when="$debugTiming" select="js:startTime($time-id-register-outputs)" />
        
        <xsl:if test="not(ancestor::xforms:repeat)">
            <xsl:variable name="output-map" as="map(*)">
                <xsl:map>
                    <xsl:map-entry key="'@instance-context'" select="$instance-context"/>
                    <xsl:map-entry key="'@context-nodeset'" select="$context-nodeset"/>
                    
                    <xsl:if test="$nodeset != ''">
                        <xsl:map-entry key="'@ref'" select="xs:string($nodeset)" />
                    </xsl:if>
                    
                    <xsl:if test="exists(@value)">
                        <xsl:map-entry key="'@value'" select="xforms:resolveContext(xs:string(@value),$context-nodeset)" />
                    </xsl:if>
                    
                    <xsl:if test="$data-type ne ''">
                        <xsl:map-entry key="'@data-type'" select="$data-type"/>
                    </xsl:if>
                    
                    <xsl:if test="exists(@incremental)">
                        <xsl:map-entry key="'@incremental'" select="string(@incremental)"/>
                    </xsl:if>
                    
                    <xsl:if test="exists(@class)">
                        <xsl:map-entry key="'@class'" select="string(@class)"/>
                    </xsl:if>
                    <xsl:if test="exists($additional-class-values)">
                        <xsl:map-entry key="'@additional-class-values'" select="$additional-class-values"/>
                    </xsl:if>
                    
                    <xsl:if test="exists(child::xforms:itemset)">
                        <xsl:map-entry key="'itemset'" select="child::xforms:itemset"/>
                    </xsl:if>
                </xsl:map>
            </xsl:variable>
            
            <xsl:message use-when="$debugMode">
                <xsl:sequence select="concat('[registerOutput] Registering output with ID ', $id)"/>
            </xsl:message>
            <xsl:sequence select="js:addOutput($id , $output-map)" />
        </xsl:if>
        
        <xsl:sequence use-when="$debugTiming" select="js:endTime($time-id-register-outputs)" />
        
    </xsl:template>
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>setSubmission: create map of an  xforms:submission</xd:p>
            <xd:p>See <a href="https://www.w3.org/TR/xforms11/#submit-submission-element">XForms spec 11.1 The submission Element</a></xd:p>
        </xd:desc>
        <xd:param name="this">An XForms Submission element (i.e. xforms:submission).</xd:param>
        <xd:param name="submission-id">Identifier for the xforms:submission element (or the default ID).</xd:param>
    </xd:doc>
    <xsl:template name="setSubmission">
        <xsl:param name="this" as="element()"/>
        <xsl:param name="submission-id" as="xs:string"/>
        
        <xsl:message use-when="$debugMode">[setSubmission] START (submission ID '<xsl:sequence select="$submission-id"/>')</xsl:message>
                
        <xsl:variable name="properties" as="map(*)">
            <xsl:apply-templates select="." mode="get-properties">
                <xsl:with-param name="bindings-js" select="js:getBindings()" as="element(xforms:bind)*" tunnel="yes"/>
            </xsl:apply-templates>
        </xsl:variable>
        
        <xsl:variable name="refi" as="xs:string" select="map:get($properties,'nodeset')"/>
        <xsl:variable name="this-instance-id" as="xs:string" select="map:get($properties,'instance-context')"/>
        
        <!-- set actions relevant to this -->
        <xsl:variable name="actions"  as="map(*)*">
            <xsl:apply-templates select="." mode="set-actions">
                <xsl:with-param name="instance-key" select="$this-instance-id" tunnel="yes"/>
                <xsl:with-param name="nodeset" select="$refi" tunnel="yes"/>
                <xsl:with-param name="properties" select="$properties" tunnel="yes"/>
            </xsl:apply-templates>
        </xsl:variable>
        
        <xsl:if test="exists($actions)">
            <xsl:sequence select="js:addAction($submission-id, $actions)" />
        </xsl:if>
        <xsl:variable name="method-element-value-expr" as="xs:string?" select="
            if (exists($this/xforms:method[1]/@value) and normalize-space(string($this/xforms:method[1]/@value)) != '')
            then normalize-space(string($this/xforms:method[1]/@value))
            else ()"/>
        <xsl:variable name="method-element-text" as="xs:string?" select="
            if (exists($this/xforms:method[1]) and normalize-space(string($this/xforms:method[1])) != '')
            then normalize-space(string($this/xforms:method[1]))
            else ()"/>
        <xsl:variable name="resource-element-value-expr" as="xs:string?" select="
            if (exists($this/xforms:resource[1]/@value) and normalize-space(string($this/xforms:resource[1]/@value)) != '')
            then normalize-space(string($this/xforms:resource[1]/@value))
            else ()"/>
        <xsl:variable name="resource-element-text" as="xs:string?" select="
            if (exists($this/xforms:resource[1]) and normalize-space(string($this/xforms:resource[1])) != '')
            then normalize-space(string($this/xforms:resource[1]))
            else ()"/>
        <xsl:variable name="submission-header-definitions" as="array(*)?">
            <xsl:if test="exists($this/xforms:header)">
                <xsl:variable name="header-maps" as="map(*)*">
                    <xsl:for-each select="$this/xforms:header">
                        <xsl:map>
                            <xsl:if test="exists(@nodeset) and normalize-space(string(@nodeset)) != ''">
                                <xsl:map-entry key="'@nodeset'" select="normalize-space(string(@nodeset))"/>
                            </xsl:if>
                            <xsl:if test="exists(@combine) and normalize-space(string(@combine)) != ''">
                                <xsl:map-entry key="'@combine'" select="normalize-space(string(@combine))"/>
                            </xsl:if>
                            <xsl:if test="exists(xforms:name[1]/@value) and normalize-space(string(xforms:name[1]/@value)) != ''">
                                <xsl:map-entry key="'name-value'" select="normalize-space(string(xforms:name[1]/@value))"/>
                            </xsl:if>
                            <xsl:if test="exists(xforms:name[1]) and normalize-space(string(xforms:name[1])) != ''">
                                <xsl:map-entry key="'name-text'" select="normalize-space(string(xforms:name[1]))"/>
                            </xsl:if>
                            <xsl:map-entry key="'values'">
                                <xsl:variable name="value-maps" as="map(*)*">
                                    <xsl:for-each select="xforms:value">
                                        <xsl:map>
                                            <xsl:if test="exists(@value) and normalize-space(string(@value)) != ''">
                                                <xsl:map-entry key="'@value'" select="normalize-space(string(@value))"/>
                                            </xsl:if>
                                            <xsl:if test="normalize-space(string(.)) != ''">
                                                <xsl:map-entry key="'text'" select="normalize-space(string(.))"/>
                                            </xsl:if>
                                        </xsl:map>
                                    </xsl:for-each>
                                </xsl:variable>
                                <xsl:sequence select="array { $value-maps }"/>
                            </xsl:map-entry>
                        </xsl:map>
                    </xsl:for-each>
                </xsl:variable>
                <xsl:sequence select="array { $header-maps }"/>
            </xsl:if>
        </xsl:variable>
        
        <!-- default values bases on XForms spec section 11: https://www.w3.org/TR/xforms11/#submit -->
        <xsl:map>
            <xsl:if test="exists($this/@resource)">
                <xsl:map-entry key="'@resource'" select="xs:string($this/@resource)" />
            </xsl:if>
            <xsl:if test="exists($resource-element-value-expr)">
                <xsl:map-entry key="'@resource-element-value'" select="$resource-element-value-expr"/>
            </xsl:if>
            <xsl:if test="exists($resource-element-text)">
                <xsl:map-entry key="'@resource-element-text'" select="$resource-element-text"/>
            </xsl:if>
            <!-- Depricated in XForms 1.1 but needed to meet the test suite -->
            <xsl:if test="exists($this/@action)">
                <xsl:map-entry key="'@action'" select="xs:string($this/@action)" />
            </xsl:if>
            
            <xsl:map-entry key="'@id'" select="if (exists($this/@id)) then $this/@id else $submission-id"/>
            
            <xsl:map-entry key="'@ref'" select="if (exists($refi)) then $refi else '/'"/>
            
            <xsl:if test="exists($this/@bind)">
                <xsl:map-entry key="'@bind'" select="xs:string($this/@bind)" />
            </xsl:if>
            
            <xsl:map-entry key="'@mode'" select="if (exists($this/@mode)) then xs:string($this/@mode) else 'asynchronous'" />
            <xsl:if test="exists($method-element-value-expr)">
                <xsl:map-entry key="'@method-element-value'" select="$method-element-value-expr"/>
            </xsl:if>
            <xsl:if test="exists($method-element-text)">
                <xsl:map-entry key="'@method-element-text'" select="$method-element-text"/>
            </xsl:if>
            
            <xsl:variable name="submission-method" as="xs:string">
                <xsl:choose>
                    <xsl:when test="exists($method-element-text)">
                        <xsl:sequence select="$method-element-text"/>
                    </xsl:when>
                    <xsl:when test="$this/xforms:method/@value">
                        <xsl:value-of select="$this/xforms:method/@value"/>
                    </xsl:when>
                    <xsl:when test="exists($this/@method)">
                        <xsl:sequence select="string($this/@method)"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <!-- default 'POST' method -->
                        <xsl:sequence select="'POST'"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:variable>
            <xsl:map-entry key="'@method'" select="$submission-method"/>
            
            <!-- https://www.w3.org/TR/xforms11/#submit-options -->
            <xsl:variable name="serialization" as="xs:string">
                <xsl:choose>
                    <xsl:when test="exists($this/@serialization)">
                        <xsl:value-of select="$this/@serialization"/>
                    </xsl:when>
                    <xsl:when test="$submission-method = ('post','POST','put','PUT')">
                        <xsl:sequence select="'application/xml'"/>
                    </xsl:when>
                    <xsl:when test="$submission-method = ('get','GET','delete','DELETE','urlencoded-post','URLENCODED-POST')">
                        <xsl:sequence select="'application/x-www-form-urlencoded'"/>
                    </xsl:when>
                    <xsl:when test="$submission-method = ('multipart-post','MULTIPART-POST')">
                        <xsl:sequence select="'multipart/related'"/>
                    </xsl:when>
                    <xsl:when test="$submission-method = ('form-data-post','FORM-DATA-POST')">
                        <xsl:sequence select="'multipart/form-data'"/>
                    </xsl:when>
                    <xsl:when test="$submission-method = ('post','POST')">
                        <xsl:sequence select="'application/xml'"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:sequence select="'application/xml'"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:variable>
            
            <xsl:map-entry key="'@validate'" select="if ($this/@validate) then string($this/@validate)
                else if ($serialization = 'none') then 'false' 
                else 'true'" />
            
            
            <xsl:map-entry key="'@relevant'" select="if ($this/@relevant) then string($this/@relevant) 
                else if ($serialization = 'none') then 'false' 
                else 'true'" />
            
            <xsl:map-entry key="'@serialization'" select="$serialization" />
            
            <xsl:map-entry key="'@version'" select="if ($this/@version) then string($this/@version) else '1.0'" />
            
            <xsl:map-entry key="'@indent'" select="if ($this/@indent) then string($this/@indent) else 'false'" />
            
            
            <xsl:map-entry key="'@mediatype'" select="
                if ($this/@mediatype)
                then string($this/@mediatype)
                else (
                    if ($submission-method = ('multipart-post','MULTIPART-POST'))
                    then 'multipart/related'
                    else (
                        if ($submission-method = ('form-data-post','FORM-DATA-POST'))
                        then 'multipart/form-data'
                        else (
                            if ($submission-method = ('urlencoded-post','URLENCODED-POST'))
                            then 'application/x-www-form-urlencoded'
                            else 'application/xml'
                        )
                    )
                )"/>
            
            
            <xsl:map-entry key="'@encoding'" select="if ($this/@encoding) then string($this/@encoding) else 'UTF-8'" />
            
            <xsl:map-entry key="'@omit-xml-declaration'" select="if ($this/@omit-xml-declaration) then string($this/@omit-xml-declaration) else 'false'" />
            
            <xsl:if test="exists($this/@standalone )">
                <xsl:map-entry key="'@standalone'" select="string($this/@standalone)" />
            </xsl:if>
            
            <xsl:map-entry key="'@cdata-section-elements'" select="if ($this/@cdata-section-elements) then string($this/@cdata-section-elements) else ''" />
            
            <xsl:map-entry key="'@replace'" select="if ($this/@replace) then string($this/@replace) else 'all'"/>
            
            <xsl:map-entry key="'@instance'" select="if ($this/@instance) then string($this/@instance) else $this-instance-id" />
           
            
            <xsl:if test="exists($this/@targetref )">
                <xsl:map-entry key="'@targetref'" select="string($this/@targetref)" />
            </xsl:if>
            
            <xsl:map-entry key="'@separator'" select="if ($this/@separator) then string($this/@separator) else '&amp;'" />
            
            <xsl:if test="exists($this/@includenamespaceprefixes)">
                <xsl:map-entry key="'@includenamespaceprefixes'" select="string($this/@includenamespaceprefixes)" />
            </xsl:if>
            <xsl:if test="exists($submission-header-definitions)">
                <xsl:map-entry key="'headers'" select="$submission-header-definitions"/>
            </xsl:if>
            
           
        </xsl:map>
        
        <xsl:message use-when="$debugMode">[setSubmission] END (submission ID '<xsl:sequence select="$submission-id"/>')</xsl:message>
        
    </xsl:template>
   
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of <a href="https://www.w3.org/TR/xforms11/#evt-modelConstruct">xforms-model-construct event</a></xd:p>
            <xd:p>"Perform the behaviors of xforms-rebuild, xforms-recalculate, and xforms-revalidate in sequence on this model element without dispatching events to invoke the behaviors"</xd:p>
            <xd:p>TO DO: handle instances with data provided at an external URI.</xd:p>
        </xd:desc>
        <xd:param name="model">xforms:model element to be processed.</xd:param>
        <xd:param name="default-model-id">Identifier for first model in XForm. The first instance in this model is the default instance.</xd:param>
    </xd:doc>
    <xsl:template name="xforms-model-construct">
        <xsl:param name="model" as="element(xforms:model)" required="yes" tunnel="yes"/>
        <xsl:param name="default-model-id" as="xs:string" required="no" select="$global-default-model-id" tunnel="yes"/>
        
        <xsl:variable name="model-key" as="xs:string" select="if (exists($model/@id)) then xs:string($model/@id) else $default-model-id"/>
        <xsl:if test="$sequence-template-trace-enabled">
            <xsl:message>[SEQTRACE] template=xforms-model-construct model=<xsl:value-of select="$model-key"/></xsl:message>
        </xsl:if>
        
        <xsl:variable name="instances" as="element(xforms:instance)*" select="$model/xforms:instance"/>       
        <xsl:variable name="implicit-instance-key-base" as="xs:string"
            select="xforms:get-model-implicit-default-instance-id($model-key)"/>
        <xsl:variable name="instance-keys" as="xs:string*" select="xforms:get-model-instance-ids($model-key)"/>
        
        <xsl:for-each select="$instances">
            <!-- TEST-TRACE: widen type from element()? to element()* so multi-root inline
                 instances don't crash; take only first child if multiple roots;
                 helps tests/w3c/ch03.spec.ts "3.3.2.g", "3.3.2.h" -->
            <xsl:variable name="instance-data" as="element()*">
                <xsl:choose>
                    <xsl:when test="child::*">
                        <xsl:sequence select="child::*"/>
                    </xsl:when>
                    <!-- TEST-TRACE: wrap doc() in xsl:try so missing @src files don't crash;
                         helps tests/w3c/ch04.spec.ts "4.5.4.a", "4.2.1.c3" -->
                    <xsl:when test="@src">
                        <xsl:variable name="instance-path" as="xs:anyURI" select="resolve-uri(@src, if (exists($source-base-uri)) then $source-base-uri else string(base-uri($xforms-doc-global)))"/>
                        <xsl:try>
                            <xsl:sequence select="doc($instance-path)/*"/>
                            <xsl:catch>
                                <xsl:message>[xforms-model-construct] xforms-link-exception: failed to load instance from @src '<xsl:value-of select="@src"/>'</xsl:message>
                            </xsl:catch>
                        </xsl:try>
                    </xsl:when>
                    <!-- TEST-TRACE: handle @resource on xf:instance (same as @src);
                         helps tests/w3c/ch03.spec.ts "3.3.2.c", tests/w3c/appendix.spec.ts "h.2" -->
                    <xsl:when test="@resource">
                        <xsl:variable name="instance-path" as="xs:anyURI" select="resolve-uri(@resource, if (exists($source-base-uri)) then $source-base-uri else string(base-uri($xforms-doc-global)))"/>
                        <xsl:try>
                            <xsl:sequence select="doc($instance-path)/*"/>
                            <xsl:catch>
                                <xsl:message>[xforms-model-construct] xforms-link-exception: failed to load instance from @resource '<xsl:value-of select="@resource"/>'</xsl:message>
                            </xsl:catch>
                        </xsl:try>
                    </xsl:when>
                    <xsl:otherwise/>
                </xsl:choose>
            </xsl:variable>
            <xsl:variable name="instance-data-single" as="element()?" select="$instance-data[1]"/>
            <!-- TEST-TRACE: skip instance registration when doc() load failed (empty result);
                 helps tests/w3c/ch04.spec.ts "4.5.4.a" -->
            <xsl:if test="exists($instance-data-single)">
            <xsl:variable name="instance-with-explicit-namespaces" as="element()">
                <xsl:apply-templates select="$instance-data-single" mode="namespace-fix"/>
            </xsl:variable>
            <xsl:variable name="instance-position" as="xs:integer" select="position()"/>
            <xsl:variable name="instance-key" as="xs:string" select="$instance-keys[$instance-position]"/>
            <!--<xsl:message use-when="$debugMode">[xforms-model-construct] Setting instance with ID '<xsl:sequence select="$instance-key"/>': <xsl:sequence select="fn:serialize($instance-with-explicit-namespaces)"/></xsl:message>-->
            <xsl:sequence select="js:setInstance($instance-key,$instance-with-explicit-namespaces)"/>
            <!-- TEST-TRACE: snapshot initial instance for xf:reset;
                 helps tests/w3c/ch10.spec.ts "10.a", "10.13.b" -->
            <xsl:sequence select="js:saveInitialInstance($instance-key,$instance-with-explicit-namespaces)"/>
            <!-- TEST-TRACE: alias first instance under implicit default key when it has an explicit @id,
                 so that default-instance lookups (instance() with no arg, plain XPaths) find it;
                 helps tests/w3c/ch07.spec.ts "7.4.6.a", "7.10.1.a" -->
            <xsl:if test="position() = 1 and exists(@id) and $instance-key != $implicit-instance-key-base">
                <xsl:sequence select="js:setInstance($implicit-instance-key-base,$instance-with-explicit-namespaces)"/>
            </xsl:if>
            <xsl:if test="position() = 1">
                <xsl:sequence select="js:setModelDefaultInstanceKey($model-key,$instance-key)"/>
                <xsl:if test="$model-key = $default-model-id">
                    <xsl:sequence select="js:setDefaultInstance($instance-with-explicit-namespaces)"/>
                </xsl:if>
            </xsl:if>
            </xsl:if>
        </xsl:for-each>
                        
        <xsl:call-template name="xforms-rebuild">
            <xsl:with-param name="get-bindings" as="xs:boolean" select="true()"/>
            <xsl:with-param name="model-key" as="xs:string" select="$model-key" tunnel="yes"/>
        </xsl:call-template>
        
        <xsl:call-template name="xforms-recalculate"/>
        
    </xsl:template>

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of <a href="https://www.w3.org/TR/xforms11/#evt-rebuild">xforms-rebuild event</a></xd:p>
            <xd:p>[MD 2020-04-13] I think the way Saxon-Forms works means that the bindings need to be constructed only once. Subsequently they are applied on the fly. </xd:p>
        </xd:desc>
        <xd:param name="get-bindings">Boolean, only true when model is being constructed.</xd:param>
        <xd:param name="model">xforms:model element to build.</xd:param>
    </xd:doc>
    <xsl:template name="xforms-rebuild">
        <xsl:param name="get-bindings" as="xs:boolean" select="false()" required="no"/>
        <xsl:param name="model" as="element(xforms:model)?" required="no" tunnel="yes"/>
        <xsl:if test="$sequence-template-trace-enabled">
            <xsl:message>[SEQTRACE] template=xforms-rebuild get-bindings=<xsl:value-of select="$get-bindings"/></xsl:message>
        </xsl:if>
        
        <xsl:if test="$get-bindings">
            <xsl:variable name="parsed-bindings" as="element(xforms:bind)*">
                <xsl:apply-templates select="$model/xforms:bind" mode="add-context"/>
            </xsl:variable>
            <xsl:for-each select="$parsed-bindings">
                <xsl:sequence select="js:setBinding(.)"/>
            </xsl:for-each>
        </xsl:if>
      
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Add context to xforms:bind element. The relevant model and instance IDs are added, and the @nodeset is set (if absent) or expanded based on the $nodeset tunnel parameter</xd:p>
            <xd:p>Called from xforms-rebuild event.</xd:p>
            <xd:p>In the <xd:a href="https://www.w3.org/community/xformsusers/wiki/XForms_2.0#The_bind_Element">XForms 2.0 spec for bind</xd:a>, @ref is the preferred synonym for @nodeset</xd:p>
        </xd:desc>
        <xd:param name="nodeset">XPath binding expression</xd:param>
        <xd:param name="model-key">ID of context model (xforms:model/@id value or default value).</xd:param>
        <xd:param name="default-instance-id">Context instance ID</xd:param>
    </xd:doc>
    <xsl:template match="xforms:bind" mode="add-context">
        <xsl:param name="nodeset" as="xs:string" select="''" tunnel="yes"/>
        <xsl:param name="model-key" as="xs:string" required="no" select="$global-default-model-id" tunnel="yes"/> 
        <xsl:param name="default-instance-id" as="xs:string" required="no" select="$global-default-instance-id" tunnel="yes"/>
        
        <!--<xsl:message use-when="$debugMode">[xforms:bind in add-context mode] handling binding <xsl:sequence select="fn:serialize(.)"/></xsl:message>-->
        <!-- 
            XForms test suite uses @ref on <bind> elements,
            even though XForms 1.1 spec mentions only @nodeset
        -->
        <xsl:variable name="this-ref" as="xs:string?" select="
            if ( exists(@ref) ) 
            then normalize-space( xs:string(@ref) ) 
            else if ( exists(@nodeset) )
            then  normalize-space( xs:string(@nodeset) )
            else ()"/>
        
        <!-- resolve @nodeset to the current instance context -->
        <xsl:variable name="ref" as="xs:string">
            <xsl:choose>
                <xsl:when test="exists($this-ref)">
                    <xsl:sequence select="xforms:resolveXPathStrings($nodeset,$this-ref)"/>
                </xsl:when>
                <xsl:when test="$nodeset != ''">
                    <xsl:sequence select="$nodeset"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="concat('instance(''',$default-instance-id,''')')"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:variable name="instance-context" as="xs:string">
            <xsl:apply-templates select="." mode="get-context-instance-id">
                <xsl:with-param name="nodeset" select="$ref"/>
            </xsl:apply-templates>
        </xsl:variable>
        
        <!-- set @nodeset to the current instance context -->
        <xsl:variable name="expanded-nodeset" as="xs:string">
            <xsl:choose>
                <xsl:when test="$ref != ''">
                    <xsl:sequence select="$ref"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="concat( 'instance(''', $instance-context ,''')' )"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:attribute name="model-context" select="$model-key"/>
            <xsl:attribute name="instance-context" select="$instance-context"/>
            <xsl:attribute name="nodeset" select="$expanded-nodeset"/>
        </xsl:copy>
        
        <!-- create a denested xforms:bind for a nested bind element -->
        <xsl:apply-templates select="xforms:bind" mode="add-context">
            <xsl:with-param name="nodeset" select="$expanded-nodeset" tunnel="yes"/>
            <xsl:with-param name="default-instance-id" select="$instance-context" tunnel="yes"/>
        </xsl:apply-templates>
    </xsl:template>
    
    

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of <a href="https://www.w3.org/TR/xforms11/#evt-recalculate">xforms-recalculate event</a></xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template name="xforms-recalculate">
        <xsl:message use-when="$debugMode">[xforms-recalculate] START</xsl:message>
        <xsl:if test="$sequence-template-trace-enabled">
            <xsl:message>[SEQTRACE] template=xforms-recalculate</xsl:message>
        </xsl:if>
        
        <xsl:variable name="bindings" as="element(xforms:bind)*" select="js:getBindings()"/>
        
        <xsl:variable name="instance-keys-raw" select="js:getInstanceKeys()" as="item()*"/>
        <!-- TEST-TRACE: normalize potential XDM-array return from JS Object.keys() -->
        <xsl:variable name="instance-keys" as="xs:string*" select="
            for $k in $instance-keys-raw
            return
                if ($k instance of array(*))
                then (
                    for $m in $k?*
                    return
                        if ($m instance of function(*))
                        then ()
                        else string($m)
                )
                else (
                    if ($k instance of function(*))
                    then ()
                    else string($k)
                )"/>
        <xsl:for-each select="$instance-keys">
            <xsl:variable name="instance-id" as="xs:string" select="."/>
<!--            <xsl:variable name="instanceXML" select="xforms:instance(.)"/>-->
            <xsl:variable name="instance-calculation-bindings" as="element(xforms:bind)*" select="$bindings[@instance-context = $instance-id][exists(@calculate)]"/>
            <xsl:if test="exists($instance-calculation-bindings)">
                <xsl:variable name="updatedInstanceXML" as="element()">
                    <xsl:call-template name="xforms-recalculate-binding">
                        <xsl:with-param name="instance-id" as="xs:string" select="." tunnel="yes"/>
                        <!--                    <xsl:with-param name="instanceXML" as="element()" select="$instanceXML"/>-->
                        <xsl:with-param name="calculation-bindings" as="element(xforms:bind)*" select="$instance-calculation-bindings" tunnel="yes"/>
                        <xsl:with-param name="counter" as="xs:integer" select="1"/>
                    </xsl:call-template>
                </xsl:variable>
                
                <xsl:sequence select="js:setInstance($instance-id,$updatedInstanceXML)"/>
            </xsl:if>
            
            
        </xsl:for-each>
    
        <xsl:message use-when="$debugMode">[xforms-recalculate] END</xsl:message>
    </xsl:template>
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Update instance with one calculated binding, and move on to the next</xd:p>
        </xd:desc>
        <xd:param name="instance-id">ID of instance in XForm to be updated.</xd:param>
        <xd:param name="calculation-bindings">xforms:bind elements with @calculate that are relevant to this instance</xd:param>
        <xd:param name="counter">Integer identifying the binding to process in this iteration</xd:param>
        <xd:param name="match-counter">Integer identifying the node in the list matched by the binding to process in this iteration</xd:param>
    </xd:doc>
    <xsl:template name="xforms-recalculate-binding">
        <xsl:param name="instance-id" as="xs:string" required="yes" tunnel="yes"/>
        <xsl:param name="calculation-bindings" as="element(xforms:bind)*" tunnel="yes"/>
        <xsl:param name="counter" as="xs:integer" required="yes"/>
        <xsl:param name="match-counter" as="xs:integer" required="no" select="1"/>
        
        <xsl:message use-when="$debugMode">[xforms-recalculate-binding] START</xsl:message>
        
        <xsl:variable name="instanceXML" as="element()" select="xforms:instance($instance-id)"/>
        
        <xsl:variable name="this-binding" as="element(xforms:bind)?" select="$calculation-bindings[$counter]"/>
        
        <xsl:variable name="calculated-nodes" as="node()*">
            <xsl:evaluate xpath="xforms:impose($this-binding/@nodeset)" context-item="$instanceXML" namespace-context="$instanceXML"/> 
        </xsl:variable>
        <!--
            In XForms Test Suite
            <bind ref="prev" calculate="../index - 1" readonly=". &lt; 1"/>
            
            The $calculated-nodes may be empty,
            e.g. if there is an insert happening after the model is constructed
        
        -->
        <xsl:variable name="evaluation-context" as="node()?" select="$calculated-nodes[$match-counter]"/>
        
        <xsl:message use-when="$debugMode">[xforms-recalculate-binding] bound node: <xsl:sequence select="if ($evaluation-context[self::*]) then fn:serialize($evaluation-context) else if ($evaluation-context[self::attribute()]) then '@'||name($evaluation-context) else 'UNKNOWN'"/></xsl:message>
        <!-- 
                    Wrap @xpath expression in string()
                    in case calculation returns a node(set)
                -->
        <xsl:variable name="updatedInstanceXML" as="element()">
            <xsl:choose>
                <xsl:when test="exists($evaluation-context)">
                    <!-- TEST-TRACE: try/catch guards XPath 3.1 type errors (e.g. empty string
                         in arithmetic); helps tests/w3c/ch06.spec.ts "6.1.5.a" -->
                    <!-- TEST-TRACE: substitute position()/last() with actual nodeset values;
                         xsl:evaluate sets context size=1, but XForms calculate needs
                         position within the bind nodeset;
                         helps tests/w3c/ch07.spec.ts "7.2.e" -->
                    <xsl:variable name="__calc-expr" as="xs:string" select="$this-binding/@calculate"/>
                    <xsl:variable name="__calc-with-pos" as="xs:string" select="
                        if (contains($__calc-expr, 'position()') or contains($__calc-expr, 'last()'))
                        then replace(replace($__calc-expr,
                            'last\s*\(\s*\)', string(count($calculated-nodes))),
                            'position\s*\(\s*\)', string($match-counter))
                        else $__calc-expr"/>
                    <xsl:variable name="value" as="xs:string?">
                        <xsl:try>
                            <xsl:evaluate xpath="xforms:impose('string(' || $__calc-with-pos || ')')" context-item="$evaluation-context" namespace-context="$instanceXML"/>
                            <xsl:catch><xsl:sequence select="''"/></xsl:catch>
                        </xsl:try>
                    </xsl:variable>
                    <xsl:message use-when="$debugMode">[xforms-recalculate-binding] New value for <xsl:value-of select="$this-binding/@nodeset"/> (match #<xsl:value-of select="$match-counter"/>) (<xsl:value-of select="$this-binding/@calculate"/>) is <xsl:sequence select="$value"/></xsl:message>
                    
                    <xsl:apply-templates select="$instanceXML" mode="recalculate">
                        <xsl:with-param name="updated-nodes" select="$evaluation-context" tunnel="yes"/>
                        <xsl:with-param name="updated-value" select="$value" tunnel="yes"/>
                    </xsl:apply-templates>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="$instanceXML"/>
                </xsl:otherwise>
            </xsl:choose>
            
        </xsl:variable>
        <!-- 
                    move on to next calculation 
                    BUT don't just pass $updatedInstanceXML
                    Need to set it and get it
                    so that the updated node has a match
                -->
        <xsl:choose>
            <xsl:when test="$match-counter &lt; count($calculated-nodes)">
                <!-- move to next match for this binding -->
                <xsl:sequence select="js:setInstance($instance-id,$updatedInstanceXML)"/>
                <xsl:call-template name="xforms-recalculate-binding">
                    <xsl:with-param name="counter" select="$counter"/>
                    <xsl:with-param name="match-counter" select="$match-counter + 1"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$counter &lt; count($calculation-bindings)">
                <!-- move to next binding -->
                <xsl:sequence select="js:setInstance($instance-id,$updatedInstanceXML)"/>
                <xsl:call-template name="xforms-recalculate-binding">
                    <xsl:with-param name="counter" select="$counter + 1"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
                <xsl:sequence select="$updatedInstanceXML"/>
            </xsl:otherwise>
        </xsl:choose>
        
        <xsl:message use-when="$debugMode">[xforms-recalculate-binding] END</xsl:message>
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of <a href="https://www.w3.org/TR/xforms11/#evt-revalidate">xforms-revalidate event</a></xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template name="xforms-revalidate">
        <xsl:message use-when="$debugMode">[xforms-revalidate] START</xsl:message>
        <xsl:if test="$sequence-template-trace-enabled">
            <xsl:message>[SEQTRACE] template=xforms-revalidate</xsl:message>
        </xsl:if>
        <!-- TEST-TRACE: clear+rebuild validation MIP registry each revalidate cycle;
             helps tests/supplemental/saxon-forms-validation.spec.ts. -->
        <xsl:sequence select="js:clearValidationMIPs()"/>

        <xsl:variable name="valid-actions" as="map(*)*" select="js:getEventAction('xforms-valid')"/>
        <xsl:variable name="invalid-actions" as="map(*)*" select="js:getEventAction('xforms-invalid')"/>
        <xsl:variable name="bindings" as="element(xforms:bind)*" select="js:getBindings()"/>
        <xsl:variable name="validation-controls" as="element()*" select="ixsl:page()//*[@data-ref and @instance-context]"/>

        <xsl:for-each select="$validation-controls">
            <xsl:variable name="control-ref" as="xs:string" select="normalize-space(string(@data-ref))"/>
            <xsl:variable name="control-instance-id" as="xs:string" select="normalize-space(string(@instance-context))"/>
            <xsl:variable name="context-item" as="node()?" select="(xforms:evaluate-xpath-with-instance-id($control-ref,$control-instance-id,()))[1]"/>
            <xsl:variable name="context-node" as="node()?" select="
                if (exists($context-item))
                then (if ($context-item[self::attribute()]) then $context-item/parent::* else $context-item)
                else ()"/>
            <xsl:variable name="typed-value" as="xs:string" select="if (exists($context-item)) then string($context-item) else ''"/>
            <xsl:variable name="binding-type-attr" as="xs:string?" select="normalize-space(string(@data-binding-type))"/>
            <xsl:variable name="binding-type-from-instance" as="xs:string?" select="
                if (exists($context-item))
                then string(($context-item/@*[local-name() = 'type' and namespace-uri() = 'http://www.w3.org/2001/XMLSchema-instance'])[1])
                else ()"/>
            <xsl:variable name="binding-type-from-bind" as="xs:string?" select="string(($bindings[@instance-context = $control-instance-id][@nodeset = $control-ref][1]/@type)[1])"/>
            <xsl:variable name="binding-type" as="xs:string" select="(($binding-type-attr,$binding-type-from-bind,$binding-type-from-instance)[. ne ''],'')[1]"/>
            <xsl:variable name="is-type-valid" as="xs:boolean" select="if (exists($context-item)) then xforms:is-type-valid-with-schema($binding-type,$typed-value,$context-item) else false()"/>
            <xsl:variable name="is-constraint-valid" as="xs:boolean">
                <xsl:choose>
                    <xsl:when test="exists(@data-constraint) and exists($context-node)">
                        <xsl:try>
                            <xsl:sequence select="boolean(xforms:evaluate-xpath-with-context-node(string(@data-constraint),$context-node,()))"/>
                            <xsl:catch><xsl:sequence select="false()"/></xsl:catch>
                        </xsl:try>
                    </xsl:when>
                    <xsl:otherwise><xsl:sequence select="true()"/></xsl:otherwise>
                </xsl:choose>
            </xsl:variable>
            <xsl:variable name="is-required" as="xs:boolean">
                <xsl:choose>
                    <xsl:when test="exists(@data-required) and exists($context-node)">
                        <xsl:try>
                            <xsl:sequence select="boolean(xforms:evaluate-xpath-with-context-node(string(@data-required),$context-node,()))"/>
                            <xsl:catch><xsl:sequence select="false()"/></xsl:catch>
                        </xsl:try>
                    </xsl:when>
                    <xsl:otherwise><xsl:sequence select="false()"/></xsl:otherwise>
                </xsl:choose>
            </xsl:variable>
            <xsl:variable name="has-value" as="xs:boolean" select="exists($context-item/*) or string-length($typed-value) gt 0"/>
            <xsl:variable name="required-valid" as="xs:boolean" select="not($is-required) or $has-value"/>
            <xsl:variable name="is-valid" as="xs:boolean" select="$required-valid and $is-type-valid and $is-constraint-valid"/>
            <xsl:sequence select="js:setValidationMIP($control-instance-id,$control-ref,$is-valid,$is-required)"/>
        </xsl:for-each>

        <xsl:variable name="context-refs" as="xs:string*">
            <xsl:for-each select="($valid-actions,$invalid-actions)">
                <xsl:variable name="context-ref" as="xs:string?" select="map:get(.,'@context')"/>
                <xsl:if test="exists($context-ref) and normalize-space($context-ref) ne ''">
                    <xsl:sequence select="normalize-space($context-ref)"/>
                </xsl:if>
            </xsl:for-each>
        </xsl:variable>

        <xsl:for-each select="distinct-values($context-refs)">
            <xsl:variable name="context-ref" as="xs:string" select="."/>
            <xsl:variable name="context-instance-id" as="xs:string" select="xforms:getInstanceId($context-ref)"/>
            <xsl:variable name="context-ref-local" as="xs:string" select="replace(normalize-space($context-ref), &quot;^instance\s*\(\s*'[^']+'\s*\)\s*/\s*&quot;, '')"/>
            <xsl:variable name="context-instance-xml" as="element()?" select="xforms:instance($context-instance-id)"/>
            <xsl:variable name="context-items" as="item()*" select="xforms:evaluate-xpath-with-instance-id($context-ref,$context-instance-id,())"/>
            <xsl:variable name="context-node" as="node()?" select="(for $i in $context-items return if ($i instance of node()) then $i else ())[1]"/>
            <xsl:variable name="binding-type-from-bind-exact" as="xs:string?" select="string(($bindings[@instance-context = $context-instance-id][@nodeset = ($context-ref,$context-ref-local)][1]/@type)[1])"/>
            <xsl:variable name="binding-by-node" as="element(xforms:bind)?">
                <xsl:for-each select="$bindings[@instance-context = $context-instance-id][exists(@type)]">
                    <xsl:variable name="binding-nodes" as="node()*">
                        <xsl:choose>
                            <xsl:when test="exists($context-instance-xml)">
                                <xsl:evaluate xpath="xforms:impose(string(@nodeset))" context-item="$context-instance-xml" namespace-context="$context-instance-xml"/>
                            </xsl:when>
                            <xsl:otherwise/>
                        </xsl:choose>
                    </xsl:variable>
                    <xsl:if test="exists($context-node) and (some $n in $binding-nodes satisfies $n is $context-node)">
                        <xsl:sequence select="."/>
                    </xsl:if>
                </xsl:for-each>
            </xsl:variable>
            <xsl:variable name="binding-type-from-bind-node" as="xs:string?" select="string(($binding-by-node[1]/@type)[1])"/>
            <xsl:variable name="binding-type-from-instance" as="xs:string?" select="
                if (exists($context-node))
                then string(($context-node/@*[local-name() = 'type' and namespace-uri() = 'http://www.w3.org/2001/XMLSchema-instance'])[1])
                else ()"/>
            <xsl:variable name="binding-type" as="xs:string" select="((normalize-space($binding-type-from-bind-exact),normalize-space($binding-type-from-bind-node),normalize-space($binding-type-from-instance))[. ne ''],'')[1]"/>
            <xsl:variable name="typed-value" as="xs:string" select="if (exists($context-node)) then string($context-node) else ''"/>
            <!-- TEST-TRACE: use schema-derived facets for xforms-revalidate context checks when schemaLocation is available;
                 helps tests/w3c/nist-facets-engine.spec.ts "NIST subset through engine". -->
            <xsl:variable name="is-type-valid" as="xs:boolean" select="if (exists($context-node)) then xforms:is-type-valid-with-schema($binding-type,$typed-value,$context-node) else false()"/>
            <!-- TEST-TRACE: evaluate bind @constraint (not just type);
                 helps tests/w3c/ch06.spec.ts "6.1.6.a" -->
            <xsl:variable name="constraint-bind" as="element(xforms:bind)?" select="
                ($bindings[@instance-context = $context-instance-id][exists(@constraint)][
                    let $bn := xforms:impose(string(@nodeset))
                    return exists($context-instance-xml) and
                           (some $n in xforms:evaluate-xpath-with-context-node($bn, $context-instance-xml, ())
                            satisfies exists($context-node) and $n is $context-node)
                ])[1]"/>
            <xsl:variable name="is-constraint-valid" as="xs:boolean">
                <xsl:choose>
                    <xsl:when test="exists($constraint-bind) and exists($context-node)">
                        <xsl:try>
                            <xsl:evaluate xpath="xforms:impose(string($constraint-bind/@constraint))" context-item="$context-node" namespace-context="$context-instance-xml"/>
                            <xsl:catch><xsl:sequence select="false()"/></xsl:catch>
                        </xsl:try>
                    </xsl:when>
                    <xsl:otherwise><xsl:sequence select="true()"/></xsl:otherwise>
                </xsl:choose>
            </xsl:variable>
            <xsl:variable name="is-valid" as="xs:boolean" select="$is-type-valid and $is-constraint-valid"/>

            <xsl:message use-when="$debugMode">[xforms-revalidate] ref=<xsl:value-of select="$context-ref"/> instance=<xsl:value-of select="$context-instance-id"/> type=<xsl:value-of select="$binding-type"/> value='<xsl:value-of select="$typed-value"/>' valid=<xsl:value-of select="$is-valid"/></xsl:message>

            <xsl:variable name="actions-to-apply" as="map(*)*" select="
                if ($is-valid)
                then $valid-actions[map:get(.,'@context') = $context-ref]
                else $invalid-actions[map:get(.,'@context') = $context-ref]"/>

            <xsl:for-each select="$actions-to-apply">
                <xsl:call-template name="applyActions">
                    <xsl:with-param name="action-map" as="map(*)" select="map:put(.,'handler-status','inner')" tunnel="yes"/>
                </xsl:call-template>
            </xsl:for-each>
        </xsl:for-each>

        <xsl:message use-when="$debugMode">[xforms-revalidate] END</xsl:message>
    </xsl:template>

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of <a href="https://www.w3.org/TR/xforms11/#evt-refresh">xforms-refresh event</a></xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template name="xforms-refresh">
        <xsl:if test="$sequence-template-trace-enabled">
            <xsl:message>[SEQTRACE] template=xforms-refresh</xsl:message>
        </xsl:if>
        <xsl:call-template name="refreshOutputs-JS"/>
        <xsl:call-template name="refreshRepeats-JS"/>
        <xsl:call-template name="refreshElementsUsingIndexFunction-JS"/>
        <xsl:call-template name="refreshRelevantFields-JS"/>
        <xsl:sequence select="js:clearForceFullValidationFeedback()"/>
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of <a href="https://www.w3.org/TR/xforms11/#evt-valueChanged">xforms-value-changed event</a></xd:p>
        </xd:desc>
        <xd:param name="when-value-changed">Action maps to apply (@ev:event = 'xforms-value-changed')</xd:param>
    </xd:doc>
    <xsl:template name="xforms-value-changed">
        <xsl:param name="when-value-changed" as="map(*)*" required="no" tunnel="yes"/>
        
        <xsl:for-each select="$when-value-changed">
            <xsl:variable name="action-map" select="."/>
            
            <xsl:call-template name="applyActions">
                <xsl:with-param name="action-map" select="$action-map" tunnel="yes"/>
            </xsl:call-template>
        </xsl:for-each> 
       
        
    </xsl:template>
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Dispatch an xforms-submit-error event with normalized context fields.</xd:p>
        </xd:desc>
        <xd:param name="submission-id">Submission identifier for event target matching.</xd:param>
        <xd:param name="error-type">Submit error type (for example no-data, validation-error, resource-error, target-error, submission-in-progress).</xd:param>
        <xd:param name="resource-uri">Submission resource URI when available.</xd:param>
        <xd:param name="response-status-code">HTTP status code when available.</xd:param>
        <xd:param name="response-headers">HTTP response headers when available.</xd:param>
    </xd:doc>
    <xsl:template name="dispatch-submit-error">
        <xsl:param name="submission-id" as="xs:string?" required="no"/>
        <xsl:param name="error-type" as="xs:string" required="yes"/>
        <xsl:param name="resource-uri" as="xs:string?" required="no"/>
        <xsl:param name="response-status-code" as="item()?" required="no"/>
        <xsl:param name="response-headers" as="map(*)?" required="no"/>
        <xsl:if test="$sequence-template-trace-enabled">
            <xsl:message>[SEQTRACE] template=dispatch-submit-error submission=<xsl:value-of select="$submission-id"/> error-type=<xsl:value-of select="$error-type"/></xsl:message>
        </xsl:if>
        <xsl:variable name="response-headers-nodes" as="element()*" select="xforms:response-headers-to-nodes($response-headers)"/>
        <xsl:variable name="submit-error-context" as="map(*)">
            <xsl:map>
                <xsl:map-entry key="'error-type'" select="$error-type"/>
                <xsl:if test="exists($resource-uri) and normalize-space($resource-uri) != ''">
                    <xsl:map-entry key="'resource-uri'" select="$resource-uri"/>
                </xsl:if>
                <xsl:if test="exists($submission-id) and normalize-space($submission-id) != ''">
                    <xsl:map-entry key="'targetid'" select="$submission-id"/>
                </xsl:if>
                <xsl:if test="exists($response-status-code)">
                    <xsl:map-entry key="'response-status-code'" select="string($response-status-code)"/>
                </xsl:if>
                <xsl:if test="exists($response-headers-nodes)">
                    <xsl:map-entry key="'response-headers'" select="$response-headers-nodes"/>
                </xsl:if>
            </xsl:map>
        </xsl:variable>
        <xsl:call-template name="xforms-event-handler">
            <xsl:with-param name="event-name" select="'xforms-submit-error'" as="xs:string" tunnel="yes"/>
            <xsl:with-param name="event-context" select="$submit-error-context" as="map(*)" tunnel="yes"/>
        </xsl:call-template>
    </xsl:template>
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of <a href="https://www.w3.org/TR/xforms11/#evt-focus">xforms-focus event</a></xd:p>
        </xd:desc>
        <xd:param name="control">Identifier of a form control to give focus to.</xd:param>
    </xd:doc>
    <xsl:template name="xforms-focus">
        <xsl:param name="control" as="xs:string"/>
        
        <xsl:variable name="xforms-control" as="element()" select="js:getXFormsDoc()//*[@id = $control]"/>
        
        <!-- if control is a repeated item, get the index of the repeat -->
         
        <xsl:choose>
            <xsl:when test="$xforms-control/ancestor::xforms:repeat">
                <xsl:variable name="context-indexes" as="xs:double*">
                    <xsl:for-each select="$xforms-control/ancestor::xforms:repeat">
                        <xsl:sort select="position()" data-type="number" order="descending"/>
                        <xsl:sequence select="js:getRepeatIndex( xs:string(@id) )"/>
                    </xsl:for-each>
                </xsl:variable>
                
                <xsl:variable name="control-index" as="xs:string" select="string-join($context-indexes,'.')"/>
<!--                <xsl:message use-when="$debugMode">[xforms-focus] Control '<xsl:sequence select="$control"/>' has index '<xsl:sequence select="$control-index"/>'</xsl:message>-->
                <xsl:sequence select="js:setFocus( concat($control, '-', $control-index ) )"/>    
            </xsl:when>
            <xsl:otherwise>
                <xsl:sequence select="js:setFocus( $control )"/>    
            </xsl:otherwise>
        </xsl:choose>
        
         
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of <a href="https://www.w3.org/TR/xforms11/#submit-evt-submit">xforms-submit event</a></xd:p>
        </xd:desc>
        <xd:param name="submission">Identifier of a registered submission.</xd:param>
    </xd:doc>
    <xsl:template name="xforms-submit">
        <xsl:param name="submission" as="xs:string"/>
        <xsl:variable name="active-form-control" as="element()?">
            <xsl:variable name="active-element" as="item()*" select="ixsl:get(ixsl:page(), 'activeElement')"/>
            <xsl:sequence select="$active-element[1][self::element()[local-name() = ('input','select','textarea')][exists(@data-ref)]]"/>
        </xsl:variable>
        <!-- ensure pending edits in a still-focused bound control are committed before submit-time validation
             and serialization; this is especially important for native date/time controls where change/blur
             sequencing can lag behind submit click handling. -->
        <xsl:if test="exists($active-form-control)">
            <xsl:call-template name="action-setvalue-form-control">
                <xsl:with-param name="form-control" select="$active-form-control"/>
                <xsl:with-param name="allow-focused-native-date-time" select="true()"/>
            </xsl:call-template>
        </xsl:if>
        
        <xsl:variable name="submission-map" select="js:getSubmission($submission)" as="map(*)"/>
        <xsl:variable name="submission-id" as="xs:string" select="
            if (exists(map:get($submission-map,'@id')))
            then normalize-space(string(map:get($submission-map,'@id')))
            else ''"/>
        <xsl:variable name="actions" select="js:getAction($submission)" as="map(*)*"/>
        
        <xsl:variable name="submit-message" as="xs:string" select="
            concat('[xforms-submit] Submitting ', map:get($submission-map,'@id') )"/>
        <xsl:message use-when="$debugMode"><xsl:sequence select="$submit-message"/> START</xsl:message>
        <xsl:if test="$sequence-template-trace-enabled">
            <xsl:message>[SEQTRACE] template=xforms-submit submission=<xsl:value-of select="$submission"/> submission-id=<xsl:value-of select="$submission-id"/></xsl:message>
        </xsl:if>
        <xsl:sequence select="js:setForceFullValidationFeedback(true())"/>
        <xsl:call-template name="xforms-revalidate"/>
        <xsl:call-template name="xforms-refresh"/>
        
        <xsl:variable name="refi" as="xs:string?" select="map:get($submission-map,'@ref')"/>
        <xsl:variable name="instance-id-submit" as="xs:string" select="xforms:getInstanceId($refi)"/>
        <xsl:variable name="instance-id-update" as="xs:string" select="map:get($submission-map,'@instance')"/>
        <xsl:variable name="instanceXML-submit" as="element()?" select="xforms:instance($instance-id-submit)"/>
        <xsl:variable name="submission-context-nodes" as="item()*" select="
            if (exists($instanceXML-submit))
            then xforms:evaluate-xpath-with-context-node($refi,$instanceXML-submit,())
            else ()"/>
        
        <!-- 
                    MD 2020-04-05: I think this is "the rebuild operation is performed without dispatching an event to invoke the operation."
                    
                    https://www.w3.org/TR/xforms11/#submit-evt-submit
                -->
        <xsl:variable name="required-fields-check" as="item()*" select="
            if (exists($instanceXML-submit))
            then (
                xforms:check-required-fields($instanceXML-submit),
                xforms:check-required-bindings($instanceXML-submit,$instance-id-submit,$submission-context-nodes)
            )
            else ()"/>
        <xsl:variable name="constrained-fields-check" as="item()*" select="
            if (exists($instanceXML-submit))
            then (
                xforms:check-constraints-on-fields($instanceXML-submit),
                xforms:check-constraints-on-bindings($instanceXML-submit,$instance-id-submit,$submission-context-nodes),
                xforms:check-instance-xsi-types($submission-context-nodes)
            )
            else ()"/>
        
        <!--                <xsl:message use-when="$debugMode">[xforms-submit] Submitting instance XML: <xsl:value-of select="serialize($instanceXML-submit)"/></xsl:message>                -->
        
        <xsl:choose>
            <xsl:when test="$submission-id != '' and js:isSubmissionInProgress($submission-id)">
                <xsl:call-template name="dispatch-submit-error">
                    <xsl:with-param name="submission-id" select="$submission-id"/>
                    <xsl:with-param name="error-type" select="'submission-in-progress'"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="empty($required-fields-check) and empty($constrained-fields-check) and empty($instanceXML-submit)">
                <xsl:call-template name="dispatch-submit-error">
                    <xsl:with-param name="submission-id" select="$submission-id"/>
                    <xsl:with-param name="error-type" select="'no-data'"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="empty($required-fields-check) and empty($constrained-fields-check) and empty($submission-context-nodes)">
                <xsl:call-template name="dispatch-submit-error">
                    <xsl:with-param name="submission-id" select="$submission-id"/>
                    <xsl:with-param name="error-type" select="'no-data'"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="empty($required-fields-check) and empty($constrained-fields-check)">
                
                <xsl:variable name="requestBody" as="node()?" select="xforms:evaluate-xpath-with-context-node($refi,$instanceXML-submit,())"/>
                
                <xsl:variable name="submission-relevant" as="xs:boolean" select="xforms:event-flag(map:get($submission-map,'@relevant'), true())"/>
                <xsl:variable name="irrelevant-request-nodes" as="node()*">
                    <xsl:if test="$submission-relevant and exists($requestBody[self::element()]) and exists($instanceXML-submit)">
                        <xsl:for-each select="js:getBindings()[@instance-context = $instance-id-submit][exists(@relevant)]">
                            <xsl:variable name="binding" as="element(xforms:bind)" select="."/>
                            <xsl:variable name="bound-nodes" as="item()*" select="xforms:evaluate-xpath-with-context-node(string($binding/@nodeset),$instanceXML-submit,())"/>
                            <xsl:for-each select="$bound-nodes[. instance of node()]">
                                <xsl:variable name="this-node" as="node()" select="."/>
                                <xsl:variable name="is-node-relevant" as="xs:boolean">
                                    <xsl:try>
                                        <xsl:sequence select="boolean(xforms:evaluate-xpath-with-context-node(string($binding/@relevant),$this-node,()))"/>
                                        <xsl:catch>
                                            <xsl:sequence select="true()"/>
                                        </xsl:catch>
                                    </xsl:try>
                                </xsl:variable>
                                <xsl:if test="not($is-node-relevant) and (some $n in $requestBody/descendant-or-self::node() satisfies $n is $this-node)">
                                    <xsl:sequence select="$this-node"/>
                                </xsl:if>
                            </xsl:for-each>
                        </xsl:for-each>
                    </xsl:if>
                </xsl:variable>
                
                <xsl:variable name="requestBodyEffective" as="item()?">
                    <xsl:choose>
                        <xsl:when test="exists($requestBody[self::element()]) and exists($irrelevant-request-nodes)">
                            <xsl:apply-templates select="$requestBody" mode="delete-node">
                                <xsl:with-param name="delete-node" select="$irrelevant-request-nodes" tunnel="yes"/>
                            </xsl:apply-templates>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:sequence select="$requestBody"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <xsl:variable name="submission-evaluation-context" as="node()?">
                    <xsl:choose>
                        <xsl:when test="$requestBodyEffective instance of document-node()">
                            <xsl:sequence select="$requestBodyEffective/*[1]"/>
                        </xsl:when>
                        <xsl:when test="$requestBodyEffective instance of element()">
                            <xsl:sequence select="$requestBodyEffective"/>
                        </xsl:when>
                        <xsl:when test="$requestBodyEffective instance of attribute() or $requestBodyEffective instance of text()">
                            <xsl:sequence select="$requestBodyEffective/parent::*"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:sequence select="$instanceXML-submit"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <xsl:variable name="request-body-root-element" as="element()?">
                    <xsl:choose>
                        <xsl:when test="$requestBodyEffective instance of document-node()">
                            <xsl:sequence select="$requestBodyEffective/*[1]"/>
                        </xsl:when>
                        <xsl:when test="$requestBodyEffective instance of element()">
                            <xsl:sequence select="$requestBodyEffective"/>
                        </xsl:when>
                        <xsl:otherwise/>
                    </xsl:choose>
                </xsl:variable>
                
                <xsl:variable name="requestBodyDoc" as="document-node()?">
                    <xsl:choose>
                        <xsl:when test="$requestBodyEffective instance of document-node()">
                            <xsl:sequence select="$requestBodyEffective"/>
                        </xsl:when>
                        <xsl:when test="exists($request-body-root-element)">
                            <xsl:document>
                                <xsl:sequence select="$request-body-root-element"/>
                            </xsl:document>
                        </xsl:when>
                    </xsl:choose>
                </xsl:variable>
                
                <xsl:variable name="method-element-value-expr" as="xs:string?" select="
                    if (exists(map:get($submission-map,'@method-element-value')))
                    then normalize-space(string(map:get($submission-map,'@method-element-value')))
                    else ()"/>
                <xsl:variable name="method-element-from-value" as="xs:string?">
                    <xsl:choose>
                        <xsl:when test="exists($method-element-value-expr) and $method-element-value-expr != '' and exists($submission-evaluation-context)">
                            <xsl:try>
                                <xsl:sequence select="normalize-space(string(xforms:evaluate-xpath-with-context-node($method-element-value-expr,$submission-evaluation-context,())))"/>
                                <xsl:catch>
                                    <xsl:sequence select="()"/>
                                </xsl:catch>
                            </xsl:try>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:sequence select="()"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <xsl:variable name="method-element-text" as="xs:string?" select="
                    if (exists(map:get($submission-map,'@method-element-text')))
                    then normalize-space(string(map:get($submission-map,'@method-element-text')))
                    else ()"/>
                <xsl:variable name="method-attribute" as="xs:string?" select="
                    if (exists(map:get($submission-map,'@method')))
                    then normalize-space(string(map:get($submission-map,'@method')))
                    else ()"/>
                <xsl:variable name="method" as="xs:string" select="($method-element-from-value[normalize-space(.) != ''], $method-element-text[normalize-space(.) != ''], $method-attribute[normalize-space(.) != ''], 'post')[1]"/>
                <xsl:variable name="method-normalized" as="xs:string" select="lower-case(normalize-space($method))"/>
                <xsl:variable name="http-method" as="xs:string" select="
                    if ($method-normalized = ('get','delete'))
                    then upper-case($method-normalized)
                    else (
                        if ($method-normalized = 'put')
                        then 'PUT'
                        else (
                            if ($method-normalized = ('post','urlencoded-post','multipart-post','form-data-post'))
                            then 'POST'
                            else 'POST'
                        )
                    )"/>
                
                <xsl:variable name="serialization-from-map" as="xs:string?" select="
                    if (exists(map:get($submission-map,'@serialization')))
                    then normalize-space(string(map:get($submission-map,'@serialization')))
                    else ()"/>
                <xsl:variable name="serialization" as="xs:string" select="
                    if (exists($serialization-from-map) and $serialization-from-map != '')
                    then $serialization-from-map
                    else (
                        if ($method-normalized = ('get','delete','urlencoded-post'))
                        then 'application/x-www-form-urlencoded'
                        else (
                            if ($method-normalized = 'multipart-post')
                            then 'multipart/related'
                            else (
                                if ($method-normalized = 'form-data-post')
                                then 'multipart/form-data'
                                else 'application/xml'
                            )
                        )
                    )"/>
                <xsl:variable name="replace-mode" as="xs:string?" select="map:get($submission-map,'@replace')"/>
                
                <xsl:variable name="separator" as="xs:string" select="
                    if (exists(map:get($submission-map,'@separator')) and normalize-space(string(map:get($submission-map,'@separator'))) != '')
                    then string(map:get($submission-map,'@separator'))
                    else '&amp;'"/>
                
                <xsl:variable name="form-parameter-nodes" as="element()*" select="
                    if (exists($request-body-root-element))
                    then (
                        if (exists($request-body-root-element/*))
                        then $request-body-root-element/*
                        else $request-body-root-element
                    )
                    else ()"/>
                <xsl:variable name="query-parameters" as="xs:string?">
                    <xsl:if test="$serialization = 'application/x-www-form-urlencoded' and exists($form-parameter-nodes)">
                        <xsl:variable name="parts" as="xs:string*">
                            <xsl:for-each select="$form-parameter-nodes">
                                <xsl:variable name="query-part" as="xs:string" select="concat(encode-for-uri(local-name()),'=',encode-for-uri(normalize-space(string(.))))"/>
                                <xsl:sequence select="$query-part"/>
                            </xsl:for-each>
                        </xsl:variable>
                        <xsl:if test="exists($parts)">
                            <xsl:sequence select="string-join($parts,$separator)"/>
                        </xsl:if>
                    </xsl:if>
                </xsl:variable>
                
                <xsl:variable name="resource-element-value-expr" as="xs:string?" select="
                    if (exists(map:get($submission-map,'@resource-element-value')))
                    then normalize-space(string(map:get($submission-map,'@resource-element-value')))
                    else ()"/>
                <xsl:variable name="resource-element-from-value" as="xs:string?">
                    <xsl:choose>
                        <xsl:when test="exists($resource-element-value-expr) and $resource-element-value-expr != '' and exists($submission-evaluation-context)">
                            <xsl:try>
                                <xsl:sequence select="normalize-space(string(xforms:evaluate-xpath-with-context-node($resource-element-value-expr,$submission-evaluation-context,())))"/>
                                <xsl:catch>
                                    <xsl:sequence select="()"/>
                                </xsl:catch>
                            </xsl:try>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:sequence select="()"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <xsl:variable name="resource-element-text" as="xs:string?" select="
                    if (exists(map:get($submission-map,'@resource-element-text')))
                    then normalize-space(string(map:get($submission-map,'@resource-element-text')))
                    else ()"/>
                <xsl:variable name="resource-attribute" as="xs:string?" select="
                    if (exists(map:get($submission-map,'@resource')))
                    then normalize-space(string(map:get($submission-map,'@resource')))
                    else ()"/>
                <xsl:variable name="action-attribute" as="xs:string?" select="
                    if (exists(map:get($submission-map,'@action')))
                    then normalize-space(string(map:get($submission-map,'@action')))
                    else ()"/>
                <xsl:variable name="href-base" as="xs:string?" select="($resource-element-from-value[normalize-space(.) != ''], $resource-element-text[normalize-space(.) != ''], $resource-attribute[normalize-space(.) != ''], $action-attribute[normalize-space(.) != ''])[1]"/>
                <xsl:message use-when="$debugMode">[xforms-submit] submission map keys: <xsl:value-of select="map:keys($submission-map)"/></xsl:message>
                <xsl:variable name="href" as="xs:string?">
                    <xsl:choose>
                        <xsl:when test="not(exists($href-base))"/>
                        <xsl:when test="$method-normalized = ('get','delete') and exists($query-parameters)">
                            <xsl:sequence select="concat($href-base, if (contains($href-base,'?')) then $separator else '?', $query-parameters)"/>
                        </xsl:when>
                        <xsl:when test="$requestBodyEffective[self::text()] and not($method-normalized = ('urlencoded-post','get','delete'))">
                            <xsl:message use-when="$debugMode">[xforms-submit] adding path '/<xsl:sequence select="$requestBodyEffective"/>' to href</xsl:message>
                            <xsl:sequence select="concat($href-base,'/',$requestBodyEffective)"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:sequence select="$href-base"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <xsl:variable name="href-resolved-candidate" as="xs:string?">
                    <xsl:choose>
                        <xsl:when test="empty($href)"/>
                        <xsl:when test="matches($href,'^[A-Za-z][A-Za-z0-9+.\-]*:')">
                            <xsl:sequence select="$href"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:sequence select="string(resolve-uri($href, if (exists($source-base-uri) and $source-base-uri != '') then $source-base-uri else string(base-uri($xforms-doc-global))))"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <xsl:variable name="href-final" as="xs:string?" select="
                    if (exists($href-resolved-candidate) and $href-resolved-candidate != '')
                    then $href-resolved-candidate
                    else $href"/>
                <xsl:variable name="href-scheme" as="xs:string?" select="
                    if (exists($href-final) and matches($href-final,'^[A-Za-z][A-Za-z0-9+.\-]*:'))
                    then lower-case(replace($href-final,'^([A-Za-z][A-Za-z0-9+.\-]*):.*$','$1'))
                    else ()"/>
                <xsl:variable name="is-supported-http-scheme" as="xs:boolean" select="
                    empty($href-scheme) or $href-scheme = ('http','https')"/>
                <xsl:message use-when="$debugMode">[xforms-submit] submitting href '<xsl:sequence select="$href"/>'</xsl:message>
                <!-- TEST-TRACE: phase-1 Option C instrumentation for submit request construction; helps tests/w3c/ch11.spec.ts "11.1.s1 [phase1]", "11.10.c [phase1]". -->
                <xsl:message use-when="$debugMode">[xforms-submit] request diagnostics: submission=<xsl:sequence select="map:get($submission-map,'@id')"/> method-raw=<xsl:sequence select="$method"/> method-normalized=<xsl:sequence select="$method-normalized"/> http-method=<xsl:sequence select="$http-method"/> serialization=<xsl:sequence select="$serialization"/> replace=<xsl:sequence select="$replace-mode"/> href-base=<xsl:sequence select="$href-base"/> href-derived=<xsl:sequence select="$href"/> href-resolved-candidate=<xsl:sequence select="$href-resolved-candidate"/></xsl:message>
                
                <xsl:variable name="encoding" as="xs:string" select="
                    if (exists(map:get($submission-map,'@encoding')) and normalize-space(string(map:get($submission-map,'@encoding'))) != '')
                    then string(map:get($submission-map,'@encoding'))
                    else 'UTF-8'"/>
                <xsl:variable name="omit-xml-declaration" as="xs:boolean" select="xforms:event-flag(map:get($submission-map,'@omit-xml-declaration'), false())"/>
                <xsl:variable name="indent-output" as="xs:boolean" select="xforms:event-flag(map:get($submission-map,'@indent'), false())"/>
                <xsl:variable name="cdata-section-elements" as="xs:string" select="
                    if (exists(map:get($submission-map,'@cdata-section-elements')))
                    then normalize-space(string(map:get($submission-map,'@cdata-section-elements')))
                    else ''"/>
                <xsl:variable name="cdata-element-tokens" as="xs:string*" select="
                    tokenize(normalize-space($cdata-section-elements), '\s+')[. != '']"/>
                <xsl:variable name="cdata-element-qnames" as="xs:QName*">
                    <xsl:for-each select="$cdata-element-tokens">
                        <xsl:variable name="token" as="xs:string" select="."/>
                        <xsl:choose>
                            <xsl:when test="contains($token,':') and exists($request-body-root-element)">
                                <xsl:try>
                                    <xsl:sequence select="resolve-QName($token,$request-body-root-element)"/>
                                    <xsl:catch/>
                                </xsl:try>
                            </xsl:when>
                            <xsl:when test="contains($token,':')"/>
                            <xsl:otherwise>
                                <xsl:try>
                                    <xsl:sequence select="QName('',$token)"/>
                                    <xsl:catch/>
                                </xsl:try>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:for-each>
                </xsl:variable>
                <xsl:variable name="request-body-doc-for-serialization" as="document-node()?">
                    <xsl:choose>
                        <xsl:when test="exists($requestBodyDoc) and exists($cdata-element-qnames)">
                            <xsl:apply-templates select="$requestBodyDoc" mode="trim-cdata-sections">
                                <xsl:with-param name="cdata-element-qnames" select="$cdata-element-qnames" tunnel="yes"/>
                            </xsl:apply-templates>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:sequence select="$requestBodyDoc"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <xsl:variable name="serialized-xml-body" as="xs:string?">
                    <xsl:if test="exists($requestBodyDoc) and not($serialization = 'application/x-www-form-urlencoded')">
                        <xsl:variable name="serialization-params" as="map(*)">
                            <xsl:map>
                                <xsl:map-entry key="'method'" select="'xml'"/>
                                <xsl:map-entry key="'encoding'" select="$encoding"/>
                                <xsl:map-entry key="'indent'" select="$indent-output"/>
                                <xsl:map-entry key="'omit-xml-declaration'" select="$omit-xml-declaration"/>
                                <xsl:if test="exists($cdata-element-qnames)">
                                    <xsl:map-entry key="'cdata-section-elements'" select="$cdata-element-qnames"/>
                                </xsl:if>
                            </xsl:map>
                        </xsl:variable>
                        <xsl:try>
                            <xsl:sequence select="serialize($request-body-doc-for-serialization,$serialization-params)"/>
                            <xsl:catch>
                                <xsl:try>
                                    <xsl:sequence select="serialize($request-body-doc-for-serialization)"/>
                                    <xsl:catch/>
                                </xsl:try>
                            </xsl:catch>
                        </xsl:try>
                    </xsl:if>
                </xsl:variable>
                <xsl:variable name="submission-target-id" as="xs:string" select="if ($submission-id != '') then $submission-id else $submission"/>
                <xsl:variable name="default-submission-body" as="xs:string?">
                    <xsl:choose>
                        <xsl:when test="$method-normalized = 'urlencoded-post'">
                            <xsl:sequence select="$query-parameters"/>
                        </xsl:when>
                        <xsl:when test="exists($serialized-xml-body)">
                            <xsl:sequence select="$serialized-xml-body"/>
                        </xsl:when>
                        <xsl:when test="exists($requestBodyDoc)">
                            <xsl:try>
                                <xsl:sequence select="serialize($requestBodyDoc)"/>
                                <xsl:catch/>
                            </xsl:try>
                        </xsl:when>
                    </xsl:choose>
                </xsl:variable>
                <xsl:sequence select="js:clearSubmitSerializeBodyOverride()"/>
                <xsl:variable name="submit-serialize-context" as="map(*)">
                    <xsl:map>
                        <xsl:map-entry key="'targetid'" select="$submission-target-id"/>
                        <xsl:if test="exists($default-submission-body)">
                            <xsl:map-entry key="'submission-body'" select="$default-submission-body"/>
                        </xsl:if>
                    </xsl:map>
                </xsl:variable>
                <xsl:call-template name="xforms-event-handler">
                    <xsl:with-param name="event-name" select="'xforms-submit-serialize'" as="xs:string" tunnel="yes"/>
                    <xsl:with-param name="event-context" select="$submit-serialize-context" as="map(*)" tunnel="yes"/>
                </xsl:call-template>
                <xsl:variable name="submission-body-override" as="item()*" select="js:getSubmitSerializeBodyOverride()"/>
                <xsl:sequence select="js:clearSubmitSerializeBodyOverride()"/>
                
                <xsl:variable name="request-body-for-http" as="item()?">
                    <xsl:choose>
                        <xsl:when test="$method-normalized = ('get','delete')"/>
                        <xsl:when test="$method-normalized = 'urlencoded-post'">
                            <xsl:sequence select="if (exists($submission-body-override)) then string($submission-body-override[1]) else $query-parameters"/>
                        </xsl:when>
                        <xsl:when test="exists($submission-body-override)">
                            <xsl:sequence select="string($submission-body-override[1])"/>
                        </xsl:when>
                        <xsl:when test="exists($serialized-xml-body)">
                            <xsl:sequence select="$serialized-xml-body"/>
                        </xsl:when>
                        <xsl:when test="exists($requestBodyDoc)">
                            <xsl:sequence select="$requestBodyDoc"/>
                        </xsl:when>
                        <xsl:otherwise/>
                    </xsl:choose>
                </xsl:variable>
                <xsl:variable name="mediatype-base-initial" as="xs:string" select="
                    if (exists(map:get($submission-map,'@mediatype')) and normalize-space(string(map:get($submission-map,'@mediatype'))) != '')
                    then string(map:get($submission-map,'@mediatype'))
                    else (
                        if ($method-normalized = 'urlencoded-post' or $serialization = 'application/x-www-form-urlencoded')
                        then 'application/x-www-form-urlencoded'
                        else (
                            if ($method-normalized = 'multipart-post')
                            then 'multipart/related'
                            else (
                                if ($method-normalized = 'form-data-post')
                                then 'multipart/form-data'
                                else 'application/xml'
                            )
                        )
                    )"/>
                <xsl:variable name="mediatype-lower-initial" as="xs:string" select="lower-case(normalize-space($mediatype-base-initial))"/>
                <xsl:variable name="mediatype-main-initial" as="xs:string" select="tokenize($mediatype-lower-initial,';')[1]"/>
                <xsl:variable name="mediatype-params-initial" as="xs:string*" select="
                    for $token in subsequence(tokenize($mediatype-base-initial,';'),2)
                    return normalize-space($token)"/>
                <!-- TEST-TRACE: unescape SOAP mediatype facet regexes so charset/action
                     parameters are detected and projected into headers; helps tests/w3c/ch11.spec.ts "11.11.3.c". -->
                <xsl:variable name="mediatype-charset-param" as="xs:string?" select="
                    ($mediatype-params-initial[matches(lower-case(.),'^charset\s*=')])[1]"/>
                <xsl:variable name="mediatype-charset-value-raw" as="xs:string?" select="
                    if (exists($mediatype-charset-param))
                    then normalize-space(substring-after($mediatype-charset-param,'='))
                    else ()"/>
                <xsl:variable name="mediatype-charset-value" as="xs:string?" select="
                    if (exists($mediatype-charset-value-raw))
                    then replace(replace($mediatype-charset-value-raw,'^[''&quot;]',''),'[''&quot;]$','')
                    else ()"/>
                <xsl:variable name="mediatype-action-param" as="xs:string?" select="
                    ($mediatype-params-initial[matches(lower-case(.),'^action\s*=')])[1]"/>
                <xsl:variable name="mediatype-action-value-raw" as="xs:string?" select="
                    if (exists($mediatype-action-param))
                    then normalize-space(substring-after($mediatype-action-param,'='))
                    else ()"/>
                <xsl:variable name="mediatype-action-value" as="xs:string?" select="
                    if (exists($mediatype-action-value-raw))
                    then replace(replace($mediatype-action-value-raw,'^[''&quot;]',''),'[''&quot;]$','')
                    else ()"/>
                <xsl:variable name="mediatype-base" as="xs:string" select="
                    if ($http-method = 'POST' and $mediatype-main-initial = 'application/soap+xml' and exists($mediatype-action-value))
                    then concat('text/xml', if (exists($mediatype-charset-value) and normalize-space($mediatype-charset-value) != '') then concat('; charset=', $mediatype-charset-value) else '')
                    else $mediatype-base-initial"/>
                <xsl:variable name="mediatype-lower" as="xs:string" select="lower-case(normalize-space($mediatype-base))"/>
                <xsl:variable name="mediatype-main" as="xs:string" select="tokenize($mediatype-lower,';')[1]"/>
                <xsl:variable name="soap-accept-charset" as="xs:string?" select="
                    if (exists($mediatype-charset-value) and normalize-space($mediatype-charset-value) != '')
                    then $mediatype-charset-value
                    else (
                        if (
                            exists(map:get($submission-map,'@mediatype'))
                            and matches(lower-case(string(map:get($submission-map,'@mediatype'))), 'charset\s*=')
                        )
                        then replace(
                            string(map:get($submission-map,'@mediatype')),
                            '^.*charset\s*=\s*[''&quot;]?([^;''&quot;\s]+).*$',
                            '$1'
                        )
                        else (
                            if ($method-normalized = 'get' and exists($encoding) and normalize-space($encoding) != '')
                            then $encoding
                            else ()
                        )
                    )"/>
                <xsl:variable name="soap-accept-header" as="xs:string?" select="
                    if ($method-normalized = 'get' and $mediatype-main-initial = 'application/soap+xml')
                    then concat('application/soap+xml', if (exists($soap-accept-charset) and normalize-space($soap-accept-charset) != '') then concat('; charset=', $soap-accept-charset) else '')
                    else ()"/>
                <xsl:variable name="soapaction-header" as="xs:string?" select="
                    if ($http-method = 'POST' and exists($mediatype-action-value) and normalize-space($mediatype-action-value) != '')
                    then $mediatype-action-value
                    else ()"/>
                <xsl:variable name="mediatype" as="xs:string" select="
                    if ($method-normalized = 'urlencoded-post' or $serialization = 'application/x-www-form-urlencoded')
                    then $mediatype-base
                    else (
                        if (
                            $request-body-for-http instance of xs:string
                            and ($mediatype-main = ('application/xml','text/xml') or ends-with($mediatype-main,'+xml'))
                            and not(matches($mediatype-lower,';\s*charset='))
                        )
                        then concat($mediatype-base,'; charset=',$encoding)
                        else $mediatype-base
                    )"/>
                
                <!-- TEST-TRACE: evaluate xf:header definitions per XForms 1.1 §11.8 and emit
                     concrete HTTP headers in the request map; helps tests/w3c/ch11.spec.ts
                     "11.8.a", "11.8.b", "11.8.c", "11.8.1.a", "11.8.2.a". -->
                <xsl:variable name="submission-header-definitions" as="array(*)?" select="map:get($submission-map,'headers')"/>
                <xsl:variable name="submission-headers-instance" as="element()?" select="
                    if (exists($submission-evaluation-context))
                    then $submission-evaluation-context
                    else $instanceXML-submit"/>
                <xsl:variable name="resolved-header-pairs" as="array(*)*">
                    <xsl:if test="exists($submission-header-definitions) and exists($submission-headers-instance)">
                        <xsl:for-each select="1 to array:size($submission-header-definitions)">
                            <xsl:variable name="header-def" as="map(*)" select="array:get($submission-header-definitions,.)"/>
                            <xsl:variable name="nodeset-expr" as="xs:string?" select="map:get($header-def,'@nodeset')"/>
                            <xsl:variable name="combine" as="xs:string" select="
                                if (exists(map:get($header-def,'@combine')) and normalize-space(string(map:get($header-def,'@combine'))) != '')
                                then lower-case(normalize-space(string(map:get($header-def,'@combine'))))
                                else 'append'"/>
                            <xsl:variable name="name-value-expr" as="xs:string?" select="map:get($header-def,'name-value')"/>
                            <xsl:variable name="name-text" as="xs:string?" select="map:get($header-def,'name-text')"/>
                            <xsl:variable name="value-defs" as="array(*)?" select="map:get($header-def,'values')"/>
                            <xsl:variable name="context-nodeset-eval" as="node()*">
                                <xsl:choose>
                                    <xsl:when test="exists($nodeset-expr) and $nodeset-expr != ''">
                                        <xsl:try>
                                            <xsl:variable name="resolved-nodes" as="item()*" select="xforms:evaluate-xpath-with-context-node($nodeset-expr,$submission-headers-instance,())"/>
                                            <xsl:sequence select="$resolved-nodes[. instance of node()]"/>
                                            <xsl:catch>
                                                <xsl:sequence select="()"/>
                                            </xsl:catch>
                                        </xsl:try>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:sequence select="$submission-headers-instance"/>
                                    </xsl:otherwise>
                                </xsl:choose>
                            </xsl:variable>
                            <xsl:if test="exists($context-nodeset-eval)">
                                <xsl:for-each select="$context-nodeset-eval">
                                    <xsl:variable name="header-context-node" as="node()" select="."/>
                                    <xsl:variable name="header-name" as="xs:string?">
                                        <xsl:choose>
                                            <xsl:when test="exists($name-value-expr) and $name-value-expr != ''">
                                                <xsl:try>
                                                    <xsl:variable name="computed" as="item()?">
                                                        <xsl:evaluate xpath="xforms:impose($name-value-expr)" context-item="$header-context-node" namespace-context="$submission-headers-instance"/>
                                                    </xsl:variable>
                                                    <xsl:sequence select="if (exists($computed)) then normalize-space(string($computed)) else ()"/>
                                                    <xsl:catch>
                                                        <xsl:sequence select="()"/>
                                                    </xsl:catch>
                                                </xsl:try>
                                            </xsl:when>
                                            <xsl:when test="exists($name-text) and $name-text != ''">
                                                <xsl:sequence select="$name-text"/>
                                            </xsl:when>
                                            <xsl:otherwise>
                                                <xsl:sequence select="()"/>
                                            </xsl:otherwise>
                                        </xsl:choose>
                                    </xsl:variable>
                                    <xsl:variable name="header-values" as="xs:string*">
                                        <xsl:if test="exists($value-defs)">
                                            <xsl:for-each select="1 to array:size($value-defs)">
                                                <xsl:variable name="value-def" as="map(*)" select="array:get($value-defs,.)"/>
                                                <xsl:variable name="value-expr" as="xs:string?" select="map:get($value-def,'@value')"/>
                                                <xsl:variable name="value-text" as="xs:string?" select="map:get($value-def,'text')"/>
                                                <xsl:choose>
                                                    <xsl:when test="exists($value-expr) and $value-expr != ''">
                                                        <xsl:try>
                                                            <xsl:variable name="computed-value" as="item()?">
                                                                <xsl:evaluate xpath="xforms:impose($value-expr)" context-item="$header-context-node" namespace-context="$submission-headers-instance"/>
                                                            </xsl:variable>
                                                            <xsl:sequence select="if (exists($computed-value)) then string($computed-value) else ()"/>
                                                            <xsl:catch>
                                                                <xsl:sequence select="()"/>
                                                            </xsl:catch>
                                                        </xsl:try>
                                                    </xsl:when>
                                                    <xsl:when test="exists($value-text)">
                                                        <xsl:sequence select="$value-text"/>
                                                    </xsl:when>
                                                </xsl:choose>
                                            </xsl:for-each>
                                        </xsl:if>
                                    </xsl:variable>
                                    <xsl:if test="exists($header-name) and $header-name != '' and exists($header-values)">
                                        <xsl:sequence select="[$header-name, $combine, string-join($header-values, ',')]"/>
                                    </xsl:if>
                                </xsl:for-each>
                            </xsl:if>
                        </xsl:for-each>
                    </xsl:if>
                </xsl:variable>
                <xsl:variable name="header-names-distinct" as="xs:string*" select="distinct-values(
                    for $pair in $resolved-header-pairs return string(array:get($pair,1))
                    )"/>
                <xsl:variable name="http-headers-map" as="map(*)?">
                    <xsl:if test="exists($resolved-header-pairs)">
                        <xsl:map>
                            <xsl:for-each select="$header-names-distinct">
                                <xsl:variable name="hname" as="xs:string" select="."/>
                                <xsl:variable name="matching-pairs" as="array(*)*" select="
                                    $resolved-header-pairs[string(array:get(.,1)) = $hname]"/>
                                <xsl:variable name="effective-combine" as="xs:string" select="
                                    if (exists($matching-pairs[string(array:get(.,2)) = 'replace']))
                                    then 'replace'
                                    else (
                                        if (exists($matching-pairs[string(array:get(.,2)) = 'prepend']))
                                        then 'prepend'
                                        else 'append'
                                    )"/>
                                <xsl:variable name="values-in-order" as="xs:string*" select="
                                    for $pair in $matching-pairs return string(array:get($pair,3))"/>
                                <xsl:variable name="value-joined" as="xs:string" select="
                                    if ($effective-combine = 'replace')
                                    then string($values-in-order[last()])
                                    else string-join($values-in-order, ',')"/>
                                <xsl:map-entry key="$hname" select="$value-joined"/>
                            </xsl:for-each>
                        </xsl:map>
                    </xsl:if>
                </xsl:variable>
                <xsl:variable name="auto-http-headers-map" as="map(*)?">
                    <xsl:if test="
                        (exists($soap-accept-header) and normalize-space($soap-accept-header) != '')
                        or
                        (exists($soapaction-header) and normalize-space($soapaction-header) != '')
                        ">
                        <xsl:map>
                            <xsl:if test="exists($soap-accept-header) and normalize-space($soap-accept-header) != ''">
                                <xsl:map-entry key="'accept'" select="$soap-accept-header"/>
                            </xsl:if>
                            <xsl:if test="exists($soapaction-header) and normalize-space($soapaction-header) != ''">
                                <xsl:map-entry key="'soapaction'" select="$soapaction-header"/>
                            </xsl:if>
                        </xsl:map>
                    </xsl:if>
                </xsl:variable>
                <xsl:variable name="effective-http-headers-map" as="map(*)?">
                    <xsl:choose>
                        <xsl:when test="exists($auto-http-headers-map) and exists($http-headers-map)">
                            <xsl:sequence select="map:merge(($auto-http-headers-map,$http-headers-map), map{'duplicates':'use-last'})"/>
                        </xsl:when>
                        <xsl:when test="exists($http-headers-map)">
                            <xsl:sequence select="$http-headers-map"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:sequence select="$auto-http-headers-map"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                
                <!-- http://www.saxonica.com/saxon-js/documentation/index.html#!development/http -->
                <xsl:variable name="HTTPrequest" as="map(*)">
                    <xsl:map>
                        <xsl:if test="not($http-method = ('GET','DELETE'))">
                            <xsl:if test="exists($request-body-for-http)">
                                <xsl:map-entry key="'body'" select="$request-body-for-http"/>
                            </xsl:if>
                            <xsl:map-entry key="'media-type'" select="$mediatype"/>
                        </xsl:if>
                        <xsl:map-entry key="'method'" select="$http-method"/>
                        <xsl:map-entry key="'href'" select="$href-final"/>
                        <xsl:if test="exists($effective-http-headers-map) and map:size($effective-http-headers-map) gt 0">
                            <xsl:map-entry key="'headers'" select="$effective-http-headers-map"/>
                        </xsl:if>
                    </xsl:map>
                </xsl:variable>
                
                <!-- 
                    SaxonJS 3 migration: use ixsl:promise instead of deprecated ixsl:schedule-action.
                    The xforms:HTTPsubmit function handles the response; xforms:serverError handles failures.
                    All needed parameters are captured as function arguments (no tunnel parameters needed).
                    See https://www.saxonica.com/saxonjs/documentation3/index.html#!ixsl-extension/instructions/promise
                -->
                <!--<ixsl:promise select="ixsl:http-request($HTTPrequest)"
                    on-completion="xforms:HTTPsubmit(?, $instance-id-update, $submission-map, $actions)"
                    on-failure="xforms:serverError#1"/>-->
                
                <xsl:choose>
                    <xsl:when test="exists($href-final) and normalize-space($href-final) != '' and $is-supported-http-scheme">
                        <xsl:if test="$submission-id != ''">
                            <xsl:sequence select="js:setSubmissionInProgress($submission-id, true())"/>
                        </xsl:if>
                        <ixsl:schedule-action http-request="$HTTPrequest">
                            <!-- The value of @http-request is an XPath expression, which evaluates to an 'HTTP request
                                    map' - i.e. our representation of an HTTP request as an XDM map -->                    
                            <xsl:call-template name="HTTPsubmit">
                                <xsl:with-param name="instance-id" select="$instance-id-update" as="xs:string"/>
                                <xsl:with-param name="resource-uri" select="$href-final"/>
                                <xsl:with-param name="submission-id" select="$submission-id"/>
                                <xsl:with-param name="targetref" select="map:get($submission-map,'@targetref')"/>
                                <xsl:with-param name="replace" select="map:get($submission-map,'@replace')"/>
                                <xsl:with-param name="when-done" select="$actions[map:get(.,'@event') = 'xforms-submit-done']" tunnel="yes"/>
                            </xsl:call-template>
                        </ixsl:schedule-action>
                    </xsl:when>
                    <xsl:when test="exists($href-final) and normalize-space($href-final) != ''">
                        <xsl:call-template name="dispatch-submit-error">
                            <xsl:with-param name="submission-id" select="$submission-id"/>
                            <xsl:with-param name="error-type" select="'resource-error'"/>
                            <xsl:with-param name="resource-uri" select="$href-final"/>
                        </xsl:call-template>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:call-template name="dispatch-submit-error">
                            <xsl:with-param name="submission-id" select="$submission-id"/>
                            <xsl:with-param name="error-type" select="'resource-error'"/>
                            <xsl:with-param name="resource-uri" select="$href-base"/>
                        </xsl:call-template>
                    </xsl:otherwise>
                </xsl:choose>
                
            </xsl:when>
            
            <xsl:otherwise>
                <xsl:call-template name="dispatch-submit-error">
                    <xsl:with-param name="submission-id" select="$submission-id"/>
                    <xsl:with-param name="error-type" select="'validation-error'"/>
                </xsl:call-template>
            </xsl:otherwise>
        </xsl:choose>
        
        <xsl:message use-when="$debugMode"><xsl:sequence select="$submit-message"/> END</xsl:message>
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Function xforms:HTTPsubmit() is the on-completion action of the ixsl:promise instruction in the xforms-submit tenmplate.</xd:p>
            <xd:p>Previously the code used ixsl:schedule-action with the call-template here as its child. Saxon-JS 3 deprecates ixsl:scheduled-action in favour of ixsl:promise.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:function name="xforms:HTTPsubmit">
        <xsl:param name="http-response" as="map(*)"/>
        <xsl:param name="instance-id" as="xs:string?"/>
        <xsl:param name="submission-map" as="map(*)"/>
        <xsl:param name="actions" as="map(*)*"/>
        <xsl:message>Debug xforms:HTTPsubmit retrieve</xsl:message>
        <xsl:call-template name="HTTPsubmit">
            <xsl:with-param name="instance-id" select="$instance-id" as="xs:string"/>
            <xsl:with-param name="targetref" select="map:get($submission-map,'@targetref')"/>
            <xsl:with-param name="replace" select="map:get($submission-map,'@replace')"/>
            <xsl:with-param name="when-done" select="$actions[map:get(.,'@event') = 'xforms-submit-done']" tunnel="yes"/>
        </xsl:call-template>
    </xsl:function>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Completion handler for xf:upload file read. Triggers the deferred update cycle (rebuild/recalculate/refresh).</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:function name="xforms:uploadComplete">
        <xsl:param name="instance-id" as="item()"/>
        <xsl:message use-when="$debugMode">[xforms:uploadComplete] File upload complete for instance '<xsl:value-of select="$instance-id"/>'</xsl:message>
        <xsl:call-template name="outermost-action-handler"/>
    </xsl:function>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Error handler for xf:upload file read.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:function name="xforms:uploadError">
        <xsl:param name="error" as="item()"/>
        <xsl:sequence select="ixsl:call(ixsl:window(), 'alert', [concat('Upload error: ', string($error))])"/>
    </xsl:function>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Function xforms:dispatchEvent() sends an event to the event handler template.</xd:p>
            <xd:p>Can't always (ever?) use this. Saxon-JS error: "Cannot call xsl:result-document while evaluating function".</xd:p>
        </xd:desc>
        <xd:param name="event-name">Name of event.</xd:param>
    </xd:doc>
    <xsl:function name="xforms:dispatchEvent">
        <xsl:param name="event-name" as="xs:string"/>
        <xsl:call-template name="xforms-event-handler">
            <xsl:with-param name="event-name" select="$event-name" as="xs:string" tunnel="yes"/>
        </xsl:call-template>
    </xsl:function>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Function xforms:serverError() is the on-failure action of the ixsl:promise instruction in the xforms-submit tenmplate.</xd:p>
            <xd:p>Previously the code used ixsl:schedule-action with the call-template here as part of the HTTPsubmit tenmplate. Saxon-JS 3 deprecates ixsl:scheduled-action in favour of ixsl:promise.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:function name="xforms:serverError">
        <xsl:param name="http-response" as="map(*)"/>
        <xsl:call-template name="serverError">
            <xsl:with-param name="responseMap" select="$http-response"/>
        </xsl:call-template>
    </xsl:function>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of <xd:a href="https://www.w3.org/TR/xforms11/#submit-evt-submit-done">xforms-submit-done event</xd:a></xd:p>
        </xd:desc>
        <xd:param name="when-done">Action maps to apply (@ev:event = 'xforms-submit-done')</xd:param>
    </xd:doc>
    <xsl:template name="xforms-submit-done">
        <xsl:param name="when-done" as="map(*)*" required="no" tunnel="yes"/>
        <xsl:message use-when="$debugMode">[xforms-submit-done] START</xsl:message>
        
        <xsl:for-each select="$when-done">
            <xsl:variable name="action-map" select="."/>
            
            <xsl:call-template name="applyActions">
                <xsl:with-param name="action-map" select="$action-map" tunnel="yes"/>
            </xsl:call-template>
        </xsl:for-each> 

        <xsl:message use-when="$debugMode">[xforms-submit-done] END</xsl:message>
        
    </xsl:template>
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of <xd:a href="https://www.w3.org/TR/xforms11/#evt-select">xforms-select</xd:a> event (notification only).</xd:p>
        </xd:desc>
        <xd:param name="case-id">ID of case that is now selected.</xd:param>
    </xd:doc>
    <xsl:template name="xforms-select">
        <xsl:param name="case-id" as="xs:string"/>
        <xsl:message use-when="$debugMode">[xforms-select] case ID: <xsl:sequence select="$case-id"/></xsl:message>
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of <xd:a href="https://www.w3.org/TR/xforms11/#evt-select">xforms-deselect</xd:a> event (notification only).</xd:p>
        </xd:desc>
        <xd:param name="case-id">ID of case that is now selected.</xd:param>
    </xd:doc>
    <xsl:template name="xforms-deselect">
        <xsl:param name="case-id" as="xs:string"/>
        <xsl:message use-when="$debugMode">[xforms-deselect] case ID: <xsl:sequence select="$case-id"/></xsl:message>
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of <xd:a href="https://www.w3.org/TR/xforms11/#action-deferred-update-behavior">deferred update behaviour</xd:a></xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template name="outermost-action-handler">
        <xsl:variable name="deferred-update-flags" as="map(*)?" select="js:getDeferredUpdateFlags()"/>
        <xsl:message>[DIAG outermost-entry] rebuild=<xsl:value-of select="map:get($deferred-update-flags,'rebuild')"/> recalculate=<xsl:value-of select="map:get($deferred-update-flags,'recalculate')"/> revalidate=<xsl:value-of select="map:get($deferred-update-flags,'revalidate')"/> refresh=<xsl:value-of select="map:get($deferred-update-flags,'refresh')"/></xsl:message>
        <xsl:if test="$sequence-template-trace-enabled">
            <xsl:message>[SEQTRACE] template=outermost-action-handler recalculate=<xsl:value-of select="map:get($deferred-update-flags,'recalculate')"/> revalidate=<xsl:value-of select="map:get($deferred-update-flags,'revalidate')"/> refresh=<xsl:value-of select="map:get($deferred-update-flags,'refresh')"/></xsl:message>
        </xsl:if>
        
        <xsl:message use-when="$debugMode">[outermost-action-handler] START</xsl:message>
        <xsl:message use-when="$debugMode">[outermost-action-handler] Recalculate: <xsl:sequence select="map:get($deferred-update-flags,'recalculate') "/></xsl:message>
        <xsl:message use-when="$debugMode">[outermost-action-handler] Revalidate: <xsl:sequence select="map:get($deferred-update-flags,'revalidate') "/></xsl:message>
        <xsl:message use-when="$debugMode">[outermost-action-handler] Refresh: <xsl:sequence select="map:get($deferred-update-flags,'refresh') "/></xsl:message>
        
        <xsl:if test="map:get($deferred-update-flags,'rebuild') = 'true'">
            <xsl:message>[DIAG outermost-branch] rebuild</xsl:message>
            <!--<xsl:call-template name="xforms-rebuild"/>-->
            <xsl:call-template name="xforms-event-handler">
                <xsl:with-param name="event-name" select="'xforms-rebuild'" as="xs:string" tunnel="yes"/>
            </xsl:call-template>
        </xsl:if>
        <xsl:if test="map:get($deferred-update-flags,'recalculate') = 'true'">
            <xsl:message>[DIAG outermost-branch] recalculate</xsl:message>
            <xsl:message use-when="$debugMode">[outermost-action-handler] triggering xforms-recalculate</xsl:message>
            <xsl:call-template name="xforms-event-handler">
                <xsl:with-param name="event-name" select="'xforms-recalculate'" as="xs:string" tunnel="yes"/>
            </xsl:call-template>
            <xsl:call-template name="xforms-recalculate"/>
        </xsl:if>
        <xsl:if test="map:get($deferred-update-flags,'revalidate') = 'true'">
            <xsl:message>[DIAG outermost-branch] revalidate</xsl:message>
            <xsl:message use-when="$debugMode">[outermost-action-handler] triggering xforms-revalidate</xsl:message>
            <xsl:call-template name="xforms-event-handler">
                <xsl:with-param name="event-name" select="'xforms-revalidate'" as="xs:string" tunnel="yes"/>
            </xsl:call-template>
            <xsl:call-template name="xforms-revalidate"/>
        </xsl:if>
        <xsl:if test="map:get($deferred-update-flags,'refresh') = 'true'">
            <xsl:message>[DIAG outermost-branch] refresh</xsl:message>
            <xsl:message use-when="$debugMode">[outermost-action-handler] triggering xforms-refresh</xsl:message>
            <!-- handle actions for this event before performing the refresh -->
            <xsl:call-template name="xforms-event-handler">
                <xsl:with-param name="event-name" select="'xforms-refresh'" as="xs:string" tunnel="yes"/>
            </xsl:call-template>
            <xsl:call-template name="xforms-refresh"/>
            
        </xsl:if>
       
        
        <xsl:sequence select="js:clearDeferredUpdateFlags()"/>
        <xsl:message>[DIAG outermost-clear] done</xsl:message>
        <!-- TEST-TRACE: PERF-6a – clear dirty-instance set after refresh cycle completes -->
        <xsl:sequence select="js:clearDirtyInstances()"/>
        <xsl:sequence select="js:clearPendingMutations()"/>
        
        <xsl:message use-when="$debugMode">[outermost-action-handler] END</xsl:message>
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of <xd:a href="https://www.w3.org/TR/xforms11/#evt-bindingException">xforms-binding-exception</xd:a></xd:p>
        </xd:desc>
        <xd:param name="message">String to output as the error message.</xd:param>
    </xd:doc>
    <xsl:template name="xforms-binding-exception">
        <xsl:param name="message" as="xs:string" required="yes"/>
        <xsl:sequence select="ixsl:call(ixsl:window(), 'alert', [concat('[xforms-binding-exception] ', $message)] )"/>
    </xsl:template>
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of a generic XForms event handler.</xd:p>
            <xd:p>See <xd:a href="https://www.w3.org/TR/xforms20/#Events_Overview">Events overview</xd:a> in the spec, but also caters for custom events.</xd:p>
        </xd:desc>
        <xd:param name="event-name">Name of event.</xd:param>
    </xd:doc>
    <xsl:template name="xforms-event-handler">
        <xsl:param name="event-name" as="xs:string" tunnel="yes"/>
        <xsl:param name="event-context" as="map(*)?" required="no" select="map{}" tunnel="yes"/>
        <xsl:variable name="safe-event-context" as="map(*)" select="($event-context, map{})[1]"/>
        <xsl:variable name="log-label" as="xs:string" select="'[xforms-event-handler for ' || $event-name || ']'"/>
        <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> START</xsl:message>
        <xsl:if test="$sequence-template-trace-enabled">
            <xsl:message>[SEQTRACE] template=xforms-event-handler event=<xsl:value-of select="$event-name"/></xsl:message>
        </xsl:if>
        <xsl:sequence select="js:recordDispatchedEvent($event-name, $safe-event-context)"/>
        <xsl:sequence select="js:pushCurrentEventContext($safe-event-context)"/>
        
        <xsl:variable name="cancelable" as="xs:boolean" select="xforms:event-flag(map:get($safe-event-context, 'cancelable'), false())"/>
        <xsl:variable name="actions" as="map(*)*" select="xforms:get-matching-event-actions($event-name, $safe-event-context)"/>
        <xsl:variable name="actions-to-run" as="map(*)*" select="
            if ($cancelable)
            then $actions[lower-case(normalize-space(string(map:get(., '@defaultAction')))) != 'cancel']
            else $actions"/>
                
        <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> Number of actions: <xsl:sequence select="count($actions-to-run)"/></xsl:message>
        
        <xsl:for-each select="$actions-to-run">
            <xsl:variable name="action-map" select="."/>
            <xsl:call-template name="applyActions">
                <xsl:with-param name="action-map" select="$action-map" tunnel="yes"/>
            </xsl:call-template>
        </xsl:for-each>                
        <xsl:sequence select="js:popCurrentEventContext()"/>
        
        <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> END</xsl:message>
        
    </xsl:template>
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of a DOMActivate event</xd:p>
        </xd:desc>
        <xd:param name="form-control">HTML form control with a @data-action attribute referencing registered actions.</xd:param>
    </xd:doc>
    <xsl:template name="DOMActivate">
        <xsl:param name="form-control" as="node()"/>
        <xsl:message use-when="$debugMode">[DOMActivate] START</xsl:message>
        <xsl:if test="$sequence-template-trace-enabled">
            <xsl:message>[SEQTRACE] template=DOMActivate control=<xsl:value-of select="name($form-control)"/> action=<xsl:value-of select="$form-control/@data-action"/></xsl:message>
        </xsl:if>
        
        <!-- TEST-TRACE: update ancestor repeat indices before processing actions so that
             index() calls inside action handlers (e.g. xf:insert @origin) resolve to the
             position of the clicked item, not the stale/default index.
             Helps rabet-v-oscal-ui smoke.spec.ts "each added control has a distinct control ID". -->
        <xsl:for-each select="$form-control/ancestor::*:div[@data-repeat-item = 'true']">
            <xsl:variable name="repeat-id" as="xs:string" select="./ancestor::*:div[exists(@data-repeatable-context)][1]/@id"/>
            <xsl:variable name="item-position" as="xs:integer" select="count(./preceding-sibling::*:div[@data-repeat-item = 'true']) + 1"/>
            <xsl:message use-when="$debugMode">[DOMActivate] Setting repeat index '<xsl:value-of select="$repeat-id"/>' to value '<xsl:value-of select="$item-position"/>'</xsl:message>
            <xsl:sequence select="js:setRepeatIndex($repeat-id,$item-position)"/>
        </xsl:for-each>
        
        <xsl:variable name="actions" select="js:getAction(string($form-control/@data-action))" as="map(*)*"/>
        
        <xsl:variable name="refi" as="xs:string" select="if (exists($form-control/@data-ref)) then xs:string($form-control/@data-ref) else ''"/>
        
        <xsl:variable name="instance-id" as="xs:string" select="xforms:getInstanceId($refi)"/>
                
        <!-- MD 2020-02-22 -->
        <xsl:variable name="instanceXML" as="element()?" select="xforms:instance($instance-id)"/>
        <xsl:variable name="instanceDoc" as="document-node()">
            <xsl:document>
                <xsl:sequence select="$instanceXML"/>
            </xsl:document>
        </xsl:variable>
        
        <xsl:variable name="updatedInstanceXML" as="element()?">
            <xsl:choose>
                <!-- TEST-TRACE: avoid cardinality errors when DOMActivate source controls
                     have no data-ref (e.g. action-only buttons in xforms-fiddle). -->
                <xsl:when test="$refi ne ''">
                    <xsl:variable name="ref-local" as="xs:string" select="
                        if (matches(normalize-space($refi), '^instance\s*\(\s*(''[^'']+''|&quot;[^&quot;]+&quot;)\s*\)\s*/?\s*'))
                        then replace(normalize-space($refi), '^instance\s*\(\s*(''[^'']+''|&quot;[^&quot;]+&quot;)\s*\)\s*/?\s*', '')
                        else normalize-space($refi)"/>
                    <xsl:variable name="updatedNode" as="node()?" select="
                        if ($ref-local = '')
                        then $instanceXML
                        else (xforms:evaluate-xpath-with-context-node($ref-local,$instanceXML,()))[1]"/>
                    <xsl:variable name="new-value" as="xs:string">
                        <xsl:apply-templates select="$form-control" mode="get-field"/>
                    </xsl:variable>
                    
                    <xsl:choose>
                        <xsl:when test="exists($updatedNode) and $instanceDoc//node()[. is $updatedNode]">
                            <xsl:apply-templates select="$instanceDoc" mode="recalculate">
                                <xsl:with-param name="updated-nodes" select="$updatedNode" tunnel="yes"/>
                                <xsl:with-param name="updated-value" select="$new-value" tunnel="yes"/>
                            </xsl:apply-templates>
                        </xsl:when>
                        <xsl:when test="exists($updatedNode)">
                            <xsl:apply-templates select="$instanceXML" mode="recalculate">
                                <xsl:with-param name="updated-nodes" select="$updatedNode" tunnel="yes"/>
                                <xsl:with-param name="updated-value" select="$new-value" tunnel="yes"/>
                            </xsl:apply-templates>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:sequence select="$instanceXML"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="$instanceXML"/>
                </xsl:otherwise>
            </xsl:choose>
            
        </xsl:variable>
        
        
        <xsl:for-each select="$actions">
            <xsl:variable name="action-map" select="."/>
                      
            <!-- https://www.w3.org/TR/xslt-30/#func-map-contains -->
            <xsl:if test="map:contains($action-map,'@event')">
                <xsl:if test="map:get($action-map,'@event') = 'DOMActivate'">
                    <xsl:call-template name="applyActions">
                        <xsl:with-param name="action-map" select="$action-map" tunnel="yes"/>
                        <xsl:with-param name="source-control" select="$form-control" tunnel="yes"/>
                    </xsl:call-template>
                </xsl:if>
            </xsl:if>
        </xsl:for-each>                
        <!-- TEST-TRACE: run one deferred-update pass after DOMActivate action processing,
             even when action-map metadata does not trigger outermost handling inside
             applyActions; helps tests/supplemental/issues.spec.ts "Issue #29 — group
             relevance refresh", "Issue #30 — delete current repeat row", and
             "Issue #31 — insert fallback on empty nodeset". -->
        <xsl:if test="exists($actions)">
            <xsl:call-template name="outermost-action-handler"/>
        </xsl:if>
        
        <xsl:message use-when="$debugMode">[DOMActivate] END</xsl:message>
        
    </xsl:template>
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for applying setvalue action. See <a href="https://www.w3.org/TR/xforms11/#action-setvalue">10.2 The setvalue Element</a></xd:p>
        </xd:desc>
        <xd:param name="action-map">Action map</xd:param>
    </xd:doc>
    <xsl:template name="action-setvalue">
        <xsl:param name="action-map" required="yes" as="map(*)" tunnel="yes"/>
        
        <xsl:variable name="log-label" as="xs:string" select="'[action-setvalue]'"/>
        <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> START</xsl:message>
        <xsl:if test="$sequence-template-trace-enabled">
            <xsl:message>[SEQTRACE] template=action-setvalue</xsl:message>
        </xsl:if>
        
        <xsl:variable name="instance-context" select="map:get($action-map, 'instance-context')" as="xs:string"/>
        
        <!-- TEST-TRACE: route setvalue with @ref=event('submission-body') to the
             submit-serialize body override (per XForms 1.1 §11.3 xforms-submit-serialize);
             helps tests/w3c/ch11.spec.ts "11.3.b". -->
        <xsl:variable name="ref-local-raw" as="xs:string?" select="map:get($action-map,'@ref-local')"/>
        <xsl:variable name="ref-raw" as="xs:string?" select="map:get($action-map,'@ref')"/>
        <xsl:variable name="ref-candidate" as="xs:string?" select="
            if (exists($ref-local-raw) and normalize-space($ref-local-raw) != '')
            then normalize-space($ref-local-raw)
            else (
                if (exists($ref-raw) and normalize-space($ref-raw) != '')
                then normalize-space($ref-raw)
                else ()
            )"/>
        <xsl:variable name="is-submission-body-target" as="xs:boolean" select="
            exists($ref-candidate) and matches($ref-candidate,
            '^event\s*\(\s*[''&quot;]submission-body[''&quot;]\s*\)\s*$')"/>
        
        <xsl:choose>
            <xsl:when test="$is-submission-body-target">
                <xsl:variable name="updated-value" as="xs:string">
                    <xsl:choose>
                        <xsl:when test="map:contains($action-map,'@value')">
                            <xsl:variable name="context-instance" as="element()?" select="xforms:instance($instance-context)"/>
                            <xsl:variable name="value-expr" as="xs:string" select="string(map:get($action-map,'@value'))"/>
                            <xsl:try>
                                <xsl:variable name="computed" as="item()?">
                                    <xsl:evaluate xpath="xforms:impose($value-expr)" context-item="$context-instance" namespace-context="$context-instance"/>
                                </xsl:variable>
                                <xsl:sequence select="if (exists($computed)) then string($computed) else ''"/>
                                <xsl:catch>
                                    <xsl:sequence select="''"/>
                                </xsl:catch>
                            </xsl:try>
                        </xsl:when>
                        <xsl:when test="map:contains($action-map,'value')">
                            <xsl:sequence select="string(map:get($action-map,'value'))"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:sequence select="''"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <xsl:sequence select="js:setSubmitSerializeBodyOverride($updated-value)"/>
                <xsl:sequence select="js:setCurrentEventProperty('submission-body',$updated-value)"/>
                <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> wrote submission-body override (length <xsl:value-of select="string-length($updated-value)"/>)</xsl:message>
            </xsl:when>
            <xsl:otherwise>
                <xsl:call-template name="action-setvalue-inner">
                    <xsl:with-param name="instance-id" select="$instance-context" tunnel="yes"/>
                </xsl:call-template>
            </xsl:otherwise>
        </xsl:choose>
        
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Set value for a node in an instance</xd:p>
            <xd:p>We might be iterating over a node set. Need to update one node at a time (value may not be the same for all nodes in the set), so need to calculate the node set each time from the updated instance.</xd:p>
        </xd:desc>
        <xd:param name="instance-id">ID of instance in XForm to be updated.</xd:param>
        <xd:param name="node-counter">Integer identifying the node to update in this iteration</xd:param>
        <xd:param name="action-map">Action map</xd:param>
    </xd:doc>
    <xsl:template name="action-setvalue-inner">
        <xsl:param name="instance-id" as="xs:string" required="yes" tunnel="yes"/>
        <xsl:param name="node-counter" as="xs:integer" required="no" select="1"/>
        <xsl:param name="action-map" required="yes" as="map(*)" tunnel="yes"/>
        
        <xsl:variable name="instanceXML" as="element()" select="xforms:instance($instance-id)"/>
        <xsl:variable name="refz" select="map:get($action-map,'@ref')"/>
        <xsl:variable name="iterate-ref" select="map:get($action-map,'@iterate')"/>
        
        
        <xsl:variable name="updated-nodeset" as="node()*">
            <xsl:choose>
                <xsl:when test="exists($iterate-ref)">
                    <xsl:message use-when="$debugMode">[action-setvalue-inner] Applying action @iterate '<xsl:sequence select="$iterate-ref"/>'; @ref-local = <xsl:sequence select="map:get($action-map,'@ref-local')"/></xsl:message>
                    
                    <xsl:variable name="ref-local" as="xs:string?" select="map:get($action-map,'@ref-local')"/>
                    
                    <xsl:choose>
                        <xsl:when test="exists($ref-local)">
                            <!-- evaluate @ref relative to @iterate context -->
                            <xsl:variable name="ref" as="xs:string" select="xforms:resolveXPathStrings($iterate-ref,$ref-local)"/>
                            <xsl:evaluate xpath="xforms:impose($ref)" context-item="$instanceXML" namespace-context="$instanceXML"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:evaluate xpath="xforms:impose($iterate-ref)" context-item="$instanceXML" namespace-context="$instanceXML"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:when>
                <xsl:when test="exists($refz)">
                    <xsl:message use-when="$debugMode">[action-setvalue-inner] Applying action @ref '<xsl:sequence select="$refz"/>'</xsl:message>
                    <xsl:evaluate xpath="xforms:impose($refz)" context-item="$instanceXML" namespace-context="$instanceXML"/>
                </xsl:when>
            </xsl:choose>
            
        </xsl:variable>
        
        <!-- the node set over which we are iterating -->
        <xsl:variable name="iterate-nodeset" as="node()*">
            <xsl:choose>
                <xsl:when test="exists($iterate-ref)">
                    <xsl:evaluate xpath="xforms:impose($iterate-ref)" context-item="$instanceXML" namespace-context="$instanceXML"/>
                </xsl:when>
            </xsl:choose>
        </xsl:variable>
 
        
        <xsl:choose>
            <xsl:when test="exists($updated-nodeset)">
                <xsl:message use-when="$debugMode">[action-setvalue-inner]  Updating <xsl:value-of select="count($updated-nodeset)"/> matched nodes</xsl:message>
                
                <xsl:variable name="updated-node" as="node()?" select="$updated-nodeset[$node-counter]"/>
                <xsl:variable name="iterate-node" as="node()?" select="$iterate-nodeset[$node-counter]"/>
                
                <xsl:variable name="ifVar" as="xs:string?" select="xforms:getIfStatement($action-map)"/>      
                
                <xsl:variable name="ifExecuted" as="xs:boolean">
                    <xsl:choose>
                        <xsl:when test="exists($iterate-nodeset) and exists($ifVar)">
                            <xsl:message use-when="$debugMode">[action-setvalue-inner] applying @if = <xsl:sequence select="$ifVar"/> in context <xsl:sequence select="fn:serialize($iterate-node)"/></xsl:message>
                            <xsl:sequence select="xforms:evaluate-xpath-with-context-node($ifVar,$iterate-node,())"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:sequence select="true()" />
                        </xsl:otherwise>
                    </xsl:choose>                    
                </xsl:variable>
                
                <xsl:choose>
                    <xsl:when test="exists($updated-node)">
                        <xsl:message use-when="$debugMode">[action-setvalue-inner] Updating node <xsl:value-of select="$node-counter"/> of <xsl:value-of select="count($updated-nodeset)"/></xsl:message>
                        
                        <xsl:if test="$ifExecuted">
                            <xsl:variable name="updated-value" as="xs:string">
                                <xsl:choose>
                                    <xsl:when test="map:contains($action-map,'@value')">
                                        <!--                        <xsl:message use-when="$debugMode">[action-setvalue] evaluating @value '<xsl:sequence select="map:get($action-map,'@value')"/>'</xsl:message>-->
                                        
                                        <xsl:variable name="updated-item" as="item()">
                                            <xsl:evaluate xpath="xforms:impose(map:get($action-map,'@value'))" context-item="$updated-node" namespace-context="$instanceXML" />
                                        </xsl:variable>
                                        <!--                        <xsl:message use-when="$debugMode">[action-setvalue] updated item '<xsl:sequence select="serialize($updated-item)"/>'</xsl:message>-->
                                        <xsl:choose>
                                            <!-- 
                                Handle case where @value evaluates to a boolean.
                                Logic mirrors that in template for HTML input (mode="get-field")
                                
                                TO DO: handle other possible data types of @value?
                            -->
                                            <xsl:when test="xs:string($updated-item) = 'true'">
                                                <xsl:sequence select="'true'"/>
                                            </xsl:when>
                                            <!-- handle boolean false() value-->
                                            <xsl:when test="xs:string($updated-item) = 'false' and not($updated-item)">
                                                <xsl:sequence select="''"/>
                                            </xsl:when>
                                            <xsl:otherwise>
                                                <xsl:sequence select="xs:string($updated-item)"/>
                                            </xsl:otherwise>
                                        </xsl:choose>
                                    </xsl:when>
                                    <xsl:when test="map:contains(.,'value')">
                                        <xsl:sequence select="map:get($action-map,'value')"/>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:sequence select="''"/> 
                                    </xsl:otherwise>
                                </xsl:choose>                
                            </xsl:variable>
                            
                            <xsl:message use-when="$debugMode">[action-setvalue-inner] updated value (in iterate) '<xsl:sequence select="serialize($updated-value)"/>'</xsl:message>
                            
                            <xsl:variable name="updatedInstanceXML" as="element()">
                                <xsl:apply-templates select="$instanceXML" mode="recalculate">
                                    <xsl:with-param name="updated-nodes" select="$updated-node" tunnel="yes"/>
                                    <xsl:with-param name="updated-value" select="$updated-value" tunnel="yes"/>
                                </xsl:apply-templates>
                            </xsl:variable>
                            
                            <!--<xsl:message use-when="$debugMode">[action-setvalue-inner] updated instance <xsl:sequence select="serialize($updatedInstanceXML)"/></xsl:message>-->
                            <xsl:sequence select="js:setInstance($instance-id,$updatedInstanceXML)"/>
                            
                        </xsl:if>
                        
                        
                        <xsl:choose>
                            <xsl:when test="$node-counter &lt; count($updated-nodeset)">
                                <!-- move to next match for this binding -->
                                <xsl:call-template name="action-setvalue-inner">
                                    <xsl:with-param name="node-counter" select="$node-counter + 1"/>
                                </xsl:call-template>
                            </xsl:when>
                            <xsl:otherwise>
                                <!-- TEST-TRACE: PERF-6a – mark mutated instance so refreshRepeats-JS can skip unaffected repeats -->
                                <xsl:sequence select="js:addDirtyInstance($instance-id)"/>
                                <xsl:sequence select="js:setDeferredUpdateFlags(('recalculate','revalidate','refresh'))" />
                            </xsl:otherwise>
                        </xsl:choose>
                        
                        
                    </xsl:when>
                </xsl:choose>
                
            </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="error-message" as="xs:string" select="'[setvalue] unable to find node at XPath ' || $refz"/>
                <xsl:message>
                    <xsl:sequence select="'ERROR: ' || $error-message"/>
                </xsl:message>
                <xsl:call-template name="logToPage">
                    <xsl:with-param name="level" select="'error'"/>
                    <xsl:with-param name="message" select="$error-message"/>
                </xsl:call-template>
            </xsl:otherwise>
        </xsl:choose>
        
    </xsl:template>
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Update instance from value of form control</xd:p>
        </xd:desc>
        <xd:param name="form-control">HTML form control containing new value for updating an instance etc.</xd:param>
    </xd:doc>
    <xsl:template name="action-setvalue-form-control">
        <xsl:param name="form-control" as="node()"/>
        <xsl:param name="allow-focused-native-date-time" as="xs:boolean" required="no" select="false()"/>
        <xsl:variable name="is-native-date-time-incremental" as="xs:boolean" select="
            local-name($form-control) = 'input'
            and $form-control/@type = ('date','time')
            and xforms:hasClass($form-control,'incremental')"/>
        <xsl:variable name="is-focused-native-date-time" as="xs:boolean" select="
            $is-native-date-time-incremental
            and exists($form-control/@id)
            and js:isActiveElement(string($form-control/@id))"/>
        
        <!-- TEST-TRACE: skip value update when readonly MIP is active;
             helps tests/w3c/ch06.spec.ts "6.1.2.a", "6.1.2.b" -->
        <xsl:if test="$form-control/@data-readonly = 'true'">
            <xsl:variable name="ro-instance-id" as="xs:string" select="xforms:getInstanceId($form-control/@data-ref)"/>
            <xsl:variable name="ro-instanceXML" as="element()" select="xforms:instance($ro-instance-id)"/>
            <xsl:variable name="ro-ref-local" as="xs:string" select="
                if (matches(normalize-space(string($form-control/@data-ref)), '^instance\s*\(\s*(''[^'']+''|&quot;[^&quot;]+&quot;)\s*\)\s*/?\s*'))
                then replace(normalize-space(string($form-control/@data-ref)), '^instance\s*\(\s*(''[^'']+''|&quot;[^&quot;]+&quot;)\s*\)\s*/?\s*', '')
                else normalize-space(string($form-control/@data-ref))"/>
            <xsl:variable name="ro-current" as="node()?" select="
                if ($ro-ref-local = '')
                then $ro-instanceXML
                else (xforms:evaluate-xpath-with-context-node($ro-ref-local,$ro-instanceXML,()))[1]"/>
            <ixsl:set-property name="value" select="string($ro-current)" object="$form-control"/>
        </xsl:if>
        <xsl:if test="not($form-control/@data-readonly = 'true') and (not($is-focused-native-date-time) or $allow-focused-native-date-time)">
        <!-- TEST-TRACE: defer incremental native date/time writes while the same control remains focused;
             transient segment edits (e.g. typing month/hour) must not mutate instance until true field exit;
             helps tests/examples/booking-form-blur.spec.ts booking form date/time regression. -->
        
        <xsl:variable name="refi" select="$form-control/@data-ref"/>
        <xsl:variable name="refElement" select="$form-control/@data-element"/>
        
        <xsl:variable name="instance-id" as="xs:string" select="xforms:getInstanceId($refi)"/>
        <xsl:variable name="actions-raw" as="item()*" select="js:getAction(string($form-control/@data-action))"/>
        <xsl:variable name="actions" as="map(*)*" select="array:flatten($actions-raw)"/>
        
        <!--        <xsl:sequence select="sfp:logInfo(concat('[xforms-value-changed] Evaluating data ref: ', $refi))"/>-->
        
        <!-- MD 2020-02-22 -->
        <xsl:variable name="instanceXML" as="element()" select="xforms:instance($instance-id)"/>
        <xsl:variable name="instanceDoc" as="document-node()">
            <xsl:document>
                <xsl:sequence select="$instanceXML"/>
            </xsl:document>
        </xsl:variable>
        <!-- TEST-TRACE: tolerate empty @data-ref lookups during control updates so
             refresh/event sequencing does not raise cardinality errors on empty matches;
             helps tests/supplemental/xforms-fiddle.spec.ts "refreshing same bind-heavy source twice does not fail". -->
        <xsl:variable name="ref-local" as="xs:string" select="
            if (matches(normalize-space(string($refi)), '^instance\s*\(\s*(''[^'']+''|&quot;[^&quot;]+&quot;)\s*\)\s*/?\s*'))
            then replace(normalize-space(string($refi)), '^instance\s*\(\s*(''[^'']+''|&quot;[^&quot;]+&quot;)\s*\)\s*/?\s*', '')
            else normalize-space(string($refi))"/>
        <xsl:variable name="updatedNode" as="node()?" select="
            if ($ref-local = '')
            then $instanceXML
            else (xforms:evaluate-xpath-with-context-node($ref-local,$instanceXML,()))[1]"/>
        <xsl:variable name="old-value" as="xs:string" select="string($updatedNode)"/>
        <xsl:variable name="new-value" as="xs:string">
            <xsl:apply-templates select="$form-control" mode="get-field"/>
        </xsl:variable>
        <xsl:variable name="skip-native-date-segment-commit" as="xs:boolean" select="
            $is-native-date-time-incremental
            and $form-control/@type = 'date'
            and matches($new-value,'^[0-9]{4}-[0-9]{2}-[0-9]{2}$')
            and xs:integer(substring($new-value,1,4)) lt 1000"/>
        <xsl:if test="not($skip-native-date-segment-commit)">
        <xsl:variable name="is-select-control" as="xs:boolean" select="local-name($form-control) = 'select'"/>
        <xsl:variable name="selection-changed" as="xs:boolean" select="$is-select-control and $old-value ne $new-value"/>
        <xsl:variable name="updatedInstanceXML" as="element()">
            <xsl:choose>
                <xsl:when test="exists($updatedNode) and $instanceDoc//node()[. is $updatedNode]">
                    <xsl:apply-templates select="$instanceDoc" mode="recalculate">
                        <xsl:with-param name="updated-nodes" select="$updatedNode" tunnel="yes"/>
                        <xsl:with-param name="updated-value" select="$new-value" tunnel="yes"/>
                    </xsl:apply-templates>
                </xsl:when>
                <xsl:when test="exists($updatedNode)">
                    <xsl:apply-templates select="$instanceXML" mode="recalculate">
                        <xsl:with-param name="updated-nodes" select="$updatedNode" tunnel="yes"/>
                        <xsl:with-param name="updated-value" select="$new-value" tunnel="yes"/>
                    </xsl:apply-templates>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="$instanceXML"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
<!--        <xsl:message use-when="$debugMode">[xforms-value-changed] Updated XML: <xsl:sequence select="serialize($updatedInstanceXML)"/></xsl:message>-->
        
        <xsl:sequence select="js:setInstance($instance-id,$updatedInstanceXML)"/>

        <!-- TEST-TRACE: PERF-6a – mark mutated instance so refreshRepeats-JS can skip unaffected repeats -->
        <xsl:sequence select="js:addDirtyInstance($instance-id)"/>
        <xsl:sequence select="js:setDeferredUpdateFlags(('recalculate','revalidate','refresh'))" />    
        <xsl:if test="$selection-changed">
            <xsl:variable name="deselect-actions-adjusted" as="map(*)*">
                <xsl:for-each select="$actions[map:get(.,'@event') = 'xforms-deselect']">
                    <xsl:sequence select="map:put(.,'handler-status','inner')"/>
                </xsl:for-each>
            </xsl:variable>
            <xsl:variable name="select-actions-adjusted" as="map(*)*">
                <xsl:for-each select="$actions[map:get(.,'@event') = 'xforms-select']">
                    <xsl:sequence select="map:put(.,'handler-status','inner')"/>
                </xsl:for-each>
            </xsl:variable>
            <xsl:if test="normalize-space($old-value) ne ''">
                <xsl:for-each select="$deselect-actions-adjusted">
                    <xsl:call-template name="applyActions">
                        <xsl:with-param name="action-map" select="." tunnel="yes"/>
                    </xsl:call-template>
                </xsl:for-each>
            </xsl:if>
            <xsl:if test="normalize-space($new-value) ne ''">
                <xsl:for-each select="$select-actions-adjusted">
                    <xsl:call-template name="applyActions">
                        <xsl:with-param name="action-map" select="." tunnel="yes"/>
                    </xsl:call-template>
                </xsl:for-each>
            </xsl:if>
        </xsl:if>

        <!-- 
            MD 2020-04-13 
            this event should be dispatched during xforms-refresh 
            but need to flag this somehow
            https://www.w3.org/TR/xforms11/#evt-valueChanged
        -->
        <xsl:variable name="value-changed-actions" as="map(*)*" select="$actions[map:get(.,'@event') = 'xforms-value-changed']"/>
        <xsl:variable name="is-non-incremental-select" as="xs:boolean" select="
            $is-select-control
            and not(xforms:hasClass($form-control,'incremental'))"/>
        <xsl:variable name="value-changed-actions-adjusted" as="map(*)*">
            <xsl:choose>
                <xsl:when test="$is-select-control">
                    <!-- Keep select/select1 sequencing from auto-dispatching
                         the outermost deferred update cycle via wrapper actions. -->
                    <xsl:for-each select="$value-changed-actions">
                        <xsl:sequence select="map:put(.,'handler-status','inner')"/>
                    </xsl:for-each>
                </xsl:when>
                <xsl:when test="$is-native-date-time-incremental">
                    <!-- TEST-TRACE: keep native date/time incremental value-changed handlers inner-only
                         to avoid focus churn during cross-field transitions from native editor segments;
                         helps tests/examples/booking-form-blur.spec.ts booking form time blur regression. -->
                    <xsl:for-each select="$value-changed-actions">
                        <xsl:sequence select="map:put(.,'handler-status','inner')"/>
                    </xsl:for-each>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="$value-changed-actions"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:if test="not($is-non-incremental-select) and (not($is-select-control) or $selection-changed)">
            <xsl:call-template name="xforms-value-changed">
                <xsl:with-param name="when-value-changed" select="$value-changed-actions-adjusted" tunnel="yes"/>
            </xsl:call-template>
        </xsl:if>
        </xsl:if>
        
        </xsl:if><!-- end not(data-readonly) guard -->
              
    </xsl:template>
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for applying insert action</xd:p>
        </xd:desc>
        <xd:param name="action-map">Action map</xd:param>
    </xd:doc>
    <xsl:template name="action-insert">
        <xsl:param name="action-map" required="yes" as="map(*)" tunnel="yes"/>
        
        <xsl:variable name="log-label" as="xs:string" select="'[action-insert]'"/>
        <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> START</xsl:message>
        
        <xsl:variable name="instance-context" select="map:get($action-map, 'instance-context')" as="xs:string"/>
        <xsl:variable name="ref" select="map:get($action-map,'@ref')" />
        <xsl:variable name="ref-local" select="map:get($action-map,'@ref-local')" as="xs:string?"/>
        <xsl:variable name="at" select="map:get($action-map, '@at')" as="xs:string?"/>
        <xsl:variable name="position" select="(map:get($action-map, '@position'),'after')[1]" as="xs:string?"/>
        <xsl:variable name="origin-ref" select="map:get($action-map, '@origin')" as="xs:string?"/>
        <xsl:variable name="context" select="map:get($action-map, '@context')" as="xs:string?"/>
        <xsl:variable name="context-explicit" as="xs:boolean" select="boolean(map:get($action-map, '@context-explicit'))"/>
        <!-- TEST-TRACE: keep bind-driven insert instance resolution anchored to bind/model context (ignore @context override); helps tests/w3c/ch10.spec.ts "10.3.b". -->
        <xsl:variable name="has-bind" as="xs:boolean" select="exists(map:get($action-map, '@bind'))"/>
        <xsl:variable name="effective-instance-context" as="xs:string" select="
            if (not($has-bind) and $context-explicit and exists($context) and matches(normalize-space($context), '^instance\s*\('))
            then xforms:getInstanceId($context)
            else $instance-context"/>
        <!-- TEST-TRACE: fix context prefix normalization regex escaping in insert action
             so instance('...') context local paths are resolved consistently; helps tests/w3c/ch10.spec.ts "10.3.a", "10.3.c". -->
        <xsl:variable name="context-local" as="xs:string?" select="
            if (exists($context))
            then
                replace(
                    replace(normalize-space($context),
                        '^instance\s*\(\s*''[^'']+''\s*\)\s*/?', ''),
                    '^instance\s*\(\s*&quot;[^&quot;]+&quot;\s*\)\s*/?', '')
            else ()"/>
        
        
        <xsl:variable name="ref-qualified" as="xs:string?" select="
            if (exists($ref) and $ref != '')
            then (
            if (exists($at))
            then concat($ref, '[', $at, ']')
            else $ref
            )
            else ()
            "/>
        <xsl:variable name="ref-qualified-local" as="xs:string?" select="
            if (exists($ref-local) and $ref-local != '')
            then (
            if (exists($at))
            then concat($ref-local, '[', $at, ']')
            else $ref-local
            )
            else ()
            "/>
        
        <xsl:variable name="instanceXML" as="element()" select="xforms:instance($effective-instance-context)"/>
        <xsl:variable name="binding-context-node" as="node()?" select="
            if (exists($context-local) and $context-local ne '')
            then (xforms:evaluate-xpath-with-context-node($context-local,$instanceXML,()))[1]
            else $instanceXML"/>
        
        <!--<xsl:message use-when="$debugMode">[action-insert] $ref = '<xsl:value-of select="$ref"/>'; inserting node at XPath <xsl:value-of select="$ref-qualified"/></xsl:message>-->
               
        
        <xsl:variable name="instance-id-origin" as="xs:string?" select="if(exists($origin-ref)) then xforms:getInstanceId($origin-ref) else ()"/>
        <xsl:variable name="instanceXML-origin" as="element()?" select="if(exists($instance-id-origin)) then xforms:instance($instance-id-origin) else ()"/>
        
        <!-- TEST-TRACE: prefer @ref-local against resolved context node to preserve
             node identity across sequential startup actions (insert/delete chains),
             while retaining absolute @ref fallback when local evaluation returns empty
             (e.g. inherited @context from a different model scope).
             Also guard empty ref-qualified (insert with @context only, no @nodeset);
             helps tests/w3c/appendix.spec.ts "B.1", "B.3", "B.4", "B.10",
             tests/w3c/ch04.spec.ts "4.6.3.a", "4.6.3.b", "4.6.3.c". -->
        <xsl:variable name="binding-nodeset-local" as="node()*" select="
            if (exists($ref-qualified-local) and $ref-qualified-local ne '')
            then xforms:evaluate-xpath-with-context-node($ref-qualified-local,$binding-context-node,())
            else ()"/>
        <xsl:variable name="binding-nodeset" as="node()*" select="
            if (exists($binding-nodeset-local))
            then $binding-nodeset-local
            else (
                if (exists($ref-qualified) and $ref-qualified ne '')
                then xforms:evaluate-xpath-with-context-node($ref-qualified,$instanceXML,())
                else ()
            )"/>
        
        <xsl:variable name="origin-items" as="item()*">
            <xsl:choose>
                <xsl:when test="exists($origin-ref)">
                    <xsl:try>
                        <!--<xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> $origin-ref = <xsl:sequence select="$origin-ref"/></xsl:message>-->
                        <xsl:sequence select="xforms:evaluate-xpath-with-context-node($origin-ref,
                            if (exists($instanceXML-origin)) then $instanceXML-origin else $instanceXML,
                            ())"/>
                        <xsl:catch/>
                    </xsl:try>
                </xsl:when>
                <xsl:otherwise>
                    <!-- fall back to using "Node Set Binding node-set" context -->
                    <xsl:sequence select="$binding-nodeset[last()]"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="origin-nodeset" as="node()*" select="$origin-items[. instance of node()]"/>
        
        <!--<xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> $origin-nodeset = <xsl:sequence select="serialize($origin-nodeset)"/></xsl:message>
        <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> $binding-nodeset = <xsl:sequence select="serialize($binding-nodeset)"/></xsl:message>-->
        
        <xsl:variable name="insert-node-location" as="node()?" select="$binding-nodeset[last()]"/> 
        
        <xsl:variable name="context-nodeset" as="node()*" select="
            if (exists($context-local) and $context-local ne '')
            then xforms:evaluate-xpath-with-context-node($context-local,$instanceXML,())
            else ()"/>
        
        <xsl:variable name="context-node" as="node()?" select="$context-nodeset[1]"/>
        <xsl:variable name="context-node-in-instance" as="node()?" select="
            if (exists($context-node) and ($instanceXML is $context-node or $instanceXML//*[. is $context-node]))
            then $context-node
            else ()"/>
        
        
        <xsl:variable name="nodes-to-insert" as="node()*">
            <xsl:choose>
                <xsl:when test="exists($origin-nodeset)">
                    <xsl:copy-of select="$origin-nodeset"/>
                </xsl:when>
                <!-- empty node set if origin returns empty node set -->
                <xsl:when test="exists($origin-ref)"/>
                <xsl:otherwise>
                    <xsl:copy-of select="$insert-node-location"/>
                </xsl:otherwise>
            </xsl:choose>
            
        </xsl:variable>
        
        <!--<xsl:message use-when="$debugMode">[action-insert] $insert-node-location = <xsl:value-of select="fn:serialize($insert-node-location)"/></xsl:message>
        <xsl:message use-when="$debugMode">[action-insert] $origin-nodeset = <xsl:value-of select="fn:serialize($origin-nodeset)"/></xsl:message>-->
        
        <xsl:if test="exists($nodes-to-insert)">
            <!-- Determine effective insert target and position -->
            <xsl:variable name="effective-insert-location" as="node()?" select="
                if (exists($insert-node-location))
                then $insert-node-location
                else (
                    if (exists($context-node-in-instance))
                    then $context-node-in-instance
                    else $instanceXML
                )"/>
            <xsl:variable name="effective-position" as="xs:string" select="if (exists($insert-node-location)) then $position else 'child'"/>
            
            <!-- Apply insert-node mode directly to $instanceXML (no document wrapping;
                 all XPath-evaluated nodes have identity tied to $instanceXML tree) -->
            <xsl:variable name="instance-with-insert" as="element()">
                <xsl:choose>
                    <!-- When insert-location IS the root element and origin exists,
                         this is an instance replacement (XForms 1.1 B.12 pattern) -->
                    <xsl:when test="exists($origin-nodeset) and exists($effective-insert-location) and $instanceXML is $effective-insert-location and $effective-position ne 'child'">
                        <xsl:copy-of select="$origin-nodeset[1]"/>
                    </xsl:when>
                    <!-- Normal insert: location is within the instance tree -->
                    <xsl:when test="exists($effective-insert-location) and ($instanceXML is $effective-insert-location or $instanceXML//*[. is $effective-insert-location])">
                        <xsl:apply-templates select="$instanceXML" mode="insert-node">
                            <xsl:with-param name="insert-node-location" select="$effective-insert-location" tunnel="yes"/>
                            <xsl:with-param name="nodes-to-insert" select="$nodes-to-insert" tunnel="yes"/>
                            <xsl:with-param name="position-relative" select="$effective-position" tunnel="yes"/>
                        </xsl:apply-templates>
                    </xsl:when>
                    <xsl:otherwise>
                        <!-- the instance node is being replaced -->
                        <xsl:sequence select="$origin-nodeset"/>
                    </xsl:otherwise>
                </xsl:choose>
                
            </xsl:variable>
            
            <!--                <xsl:message use-when="$debugMode">[action-insert] Updated instance: <xsl:sequence select="fn:serialize($instance-with-insert)"/></xsl:message>-->
            
            <xsl:sequence select="js:setInstance($effective-instance-context,$instance-with-insert)"/>
            
            
            <!-- update repeat index to that of inserted node -->
            <xsl:if test="matches($at,'index\s*\(')">
                <xsl:variable name="repeat-id" as="xs:string?" select="xforms:getRepeatID($at)"/>
                <xsl:variable name="at-position" as="xs:integer">
                    <xsl:evaluate xpath="xforms:impose($at)"/>
                </xsl:variable>
                <!--<xsl:message use-when="$debugMode">[action-insert] $repeat-id = <xsl:value-of select="$repeat-id"/></xsl:message>
            <xsl:message use-when="$debugMode">[action-insert] $at-position evaluated as <xsl:value-of select="$at-position"/></xsl:message>-->
                
                <xsl:if test="exists($repeat-id)">
                    <xsl:choose>
                        <xsl:when test="$position = 'before'">
                            <xsl:sequence select="js:setRepeatIndex($repeat-id, $at-position)"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:sequence select="js:setRepeatIndex($repeat-id, $at-position + 1)"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:if>
                
            </xsl:if>
            
            <!-- TEST-TRACE: PERF-6a – mark mutated instance so refreshRepeats-JS can skip unaffected repeats -->
            <xsl:sequence select="js:addDirtyInstance($effective-instance-context)"/>
            <!-- TEST-TRACE: PERF-6b – record pending append so refreshRepeats-JS can use
                 the splice fast-path instead of full re-render.
                 Guard against predicate-filtered refs (e.g. paragraph[2]) where count($ref)
                 is not the full list size; helps tests/w3c/appendix.spec.ts "B.3". -->
            <xsl:if test="$effective-position = 'after'
                          and exists($ref)
                          and not(exists($at))
                          and not(contains($ref,'['))
                          and ($insert-node-location is $binding-nodeset[last()])
                          and not($instanceXML is $effective-insert-location)">
                <!-- Use the unqualified $ref (without @at predicate) against the
                     post-insert instance to get the true new item count. $binding-nodeset
                     may be filtered by @at (e.g. [last()]) so its count is unreliable. -->
                <xsl:variable name="post-insert-items" as="node()*"
                    select="xforms:evaluate-xpath-with-context-node($ref, xforms:instance($effective-instance-context), ())"/>
                <xsl:sequence select="js:addPendingMutation('append', $effective-instance-context, count($post-insert-items))"/>
            </xsl:if>
            <xsl:sequence select="js:setDeferredUpdateFlags(('rebuild','recalculate','revalidate','refresh'))"/>
            <xsl:variable name="insert-event-context" as="map(*)">
                <xsl:map>
                    <xsl:map-entry key="'position'" select="$effective-position"/>
                    <xsl:map-entry key="'inserted-nodes'" select="$nodes-to-insert"/>
                </xsl:map>
            </xsl:variable>
            
            <xsl:call-template name="xforms-event-handler">
                <xsl:with-param name="event-name" select="'xforms-insert'" as="xs:string" tunnel="yes"/>
                <xsl:with-param name="event-context" select="$insert-event-context" as="map(*)" tunnel="yes"/>
            </xsl:call-template>
            
        </xsl:if>
        
        <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> END</xsl:message>
        
    </xsl:template>
    
 
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for applying delete action</xd:p>
        </xd:desc>
        <xd:param name="action-map">Action map</xd:param>
    </xd:doc>
    <xsl:template name="action-delete">
        <xsl:param name="action-map" required="yes" as="map(*)" tunnel="yes"/>
        
        <xsl:variable name="log-label" as="xs:string" select="'[action-delete]'"/>
        <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> START</xsl:message>
        
        <xsl:variable name="instance-context" select="map:get($action-map, 'instance-context')" as="xs:string"/>
        <xsl:variable name="ref" select="map:get($action-map,'@ref')"/>
        <xsl:variable name="ref-local" select="map:get($action-map,'@ref-local')" as="xs:string?"/>
        <xsl:variable name="at" select="map:get($action-map, '@at')" as="xs:string?"/>
        <xsl:variable name="context" select="map:get($action-map, '@context')" as="xs:string?"/>
        <xsl:variable name="context-explicit" as="xs:boolean" select="boolean(map:get($action-map, '@context-explicit'))"/>
        <!-- TEST-TRACE: keep bind-driven delete instance resolution anchored to bind/model context (ignore @context override); helps tests/w3c/ch10.spec.ts "10.4.b". -->
        <xsl:variable name="has-bind" as="xs:boolean" select="exists(map:get($action-map, '@bind'))"/>
        <xsl:variable name="effective-instance-context" as="xs:string" select="
            if (not($has-bind) and $context-explicit and exists($context) and matches(normalize-space($context), '^instance\s*\('))
            then xforms:getInstanceId($context)
            else $instance-context"/>
        <!-- TEST-TRACE: fix context prefix normalization regex escaping in delete action
             so instance('...') context local paths are resolved consistently; helps tests/w3c/ch10.spec.ts "10.4.a", "10.4.c". -->
        <xsl:variable name="context-local" as="xs:string?" select="
            if (exists($context))
            then
                replace(
                    replace(normalize-space($context),
                        '^instance\s*\(\s*''[^'']+''\s*\)\s*/?', ''),
                    '^instance\s*\(\s*&quot;[^&quot;]+&quot;\s*\)\s*/?', '')
            else ()"/>
        
        <xsl:variable name="ref-qualified" as="xs:string?" select="
            if (exists($ref))
            then (
            if (exists($at))
            then concat($ref, '[', $at, ']')
            else $ref
            )
            else ()
            "/>
        <xsl:variable name="ref-qualified-local" as="xs:string?" select="
            if (exists($ref-local) and $ref-local != '')
            then (
            if (exists($at))
            then concat($ref-local, '[', $at, ']')
            else $ref-local
            )
            else ()
            "/>
        
        <xsl:variable name="instanceXML" as="element()" select="xforms:instance($effective-instance-context)"/>
        <xsl:variable name="context-node-local" as="node()?" select="
            if (exists($context-local) and $context-local ne '')
            then (xforms:evaluate-xpath-with-context-node($context-local,$instanceXML,()))[1]
            else $instanceXML"/>
        <!-- TEST-TRACE: for bind-driven delete, ignore @context and target the
             bind-resolved @ref directly against the bound instance; for non-bind
             delete, evaluate @ref-local against context first, then fall back to
             resolved @ref. Helps tests/w3c/ch10.spec.ts "10.4.b". -->
        <xsl:variable name="delete-node-bind" as="node()*" select="
            if ($has-bind and exists($ref-qualified) and $ref-qualified ne '')
            then xforms:evaluate-xpath-with-context-node($ref-qualified,$instanceXML,())
            else ()"/>
        <xsl:variable name="delete-node-context" as="node()*" select="
            if (not($has-bind) and exists($ref-qualified-local) and $ref-qualified-local ne '')
            then xforms:evaluate-xpath-with-context-node($ref-qualified-local,$context-node-local,())
            else ()"/>
        <xsl:variable name="delete-node-ref" as="node()*" select="
            if (not($has-bind) and exists($ref-qualified) and $ref-qualified ne '')
            then xforms:evaluate-xpath-with-context-node($ref-qualified,$instanceXML,())
            else ()"/>
        <xsl:variable name="delete-node" as="node()*" select="
            if (exists($delete-node-bind))
            then $delete-node-bind
            else (
                if (exists($delete-node-context))
                then $delete-node-context
                else $delete-node-ref
            )"/>
        <xsl:variable name="delete-location" as="xs:integer?" select="
            if (exists($delete-node))
            then (
                if ($delete-node[1] instance of attribute())
                then ()
                else count($delete-node[1]/preceding-sibling::*) + 1
            )
            else ()"/>
        <xsl:variable name="delete-event-context" as="map(*)">
            <xsl:map>
                <xsl:if test="exists($delete-location)">
                    <xsl:map-entry key="'delete-location'" select="$delete-location"/>
                </xsl:if>
                <xsl:map-entry key="'deleted-nodes'" select="$delete-node"/>
            </xsl:map>
        </xsl:variable>
         
        <!--<xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> ref-qualified = <xsl:sequence select="$ref-qualified"/>; delete-node = <xsl:sequence select="fn:serialize($delete-node)"/></xsl:message>-->
        
            <!-- Apply delete-node mode directly to $instanceXML (no document wrapping needed;
                 $delete-node was evaluated against $instanceXML so identity always matches) -->
            <xsl:variable name="instance-with-delete" as="element()">
                <xsl:apply-templates select="$instanceXML" mode="delete-node">
                    <xsl:with-param name="delete-node" select="$delete-node" tunnel="yes"/>
                </xsl:apply-templates>
            </xsl:variable>
            
        <!--            <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> Updated instance: <xsl:sequence select="fn:serialize($instance-with-delete)"/></xsl:message>-->
            
            <xsl:sequence select="js:setInstance($effective-instance-context,$instance-with-delete)"/>    
            
            <!-- set index -->
            <xsl:if test="matches($at,'index\s*\(')">
                <xsl:variable name="repeat-id" as="xs:string?" select="xforms:getRepeatID($at)"/>
                <xsl:variable name="at-position" as="xs:integer">
                    <xsl:evaluate xpath="xforms:impose($at)"/>
                </xsl:variable>
                
                <xsl:if test="exists($repeat-id)">
                    <xsl:variable name="repeat-size" as="xs:double" select="js:getRepeatSize($repeat-id)"/>
                    
<!--                    <xsl:message use-when="$debugMode">[action-delete] Size of repeat '<xsl:value-of select="$repeat-id"/>' is <xsl:value-of select="$repeat-size"/>, index is <xsl:value-of select="$at-position"/></xsl:message>-->
                    
                    <!--
                        Let XForm take care of out of bounds indexes
                        
                        <xsl:choose>
                        <xsl:when test="$at-position = $repeat-size">
                            <!-\- adjust index if it is now out of bounds -\->
                            <xsl:sequence select="js:setRepeatIndex($repeat-id, $repeat-size - 1)"/>
                        </xsl:when>
                        <xsl:otherwise/>
                    </xsl:choose>-->
                </xsl:if>
                
            </xsl:if>
            
            <!-- TEST-TRACE: PERF-6a – mark mutated instance so refreshRepeats-JS can skip unaffected repeats -->
            <xsl:sequence select="js:addDirtyInstance($effective-instance-context)"/>
            <!-- PERF-6b: invalidate any pending insert splices — a delete in the same
                 action cycle makes the splice position unreliable -->
            <xsl:sequence select="js:clearPendingMutations()"/>
            <xsl:sequence select="js:setDeferredUpdateFlags(('rebuild','recalculate','revalidate','refresh'))"/>
        
        <xsl:call-template name="xforms-event-handler">
            <xsl:with-param name="event-name" select="'xforms-delete'" as="xs:string" tunnel="yes"/>
            <xsl:with-param name="event-context" select="$delete-event-context" as="map(*)" tunnel="yes"/>
        </xsl:call-template>
        
        <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> END</xsl:message>
        
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for applying dispatch action</xd:p>
            <xd:p>XForms 2.0 spec <xd:a href="https://www.w3.org/TR/xforms20/#The_dispatch_Element">dispatch element</xd:a></xd:p>
        </xd:desc>
        <xd:param name="action-map">Action map</xd:param>
    </xd:doc>
    <xsl:template name="action-dispatch">
        <xsl:param name="action-map" required="yes" as="map(*)" tunnel="yes"/>
        <xsl:if test="$sequence-template-trace-enabled">
            <xsl:message>[SEQTRACE] template=action-dispatch</xsl:message>
        </xsl:if>
        
        <xsl:variable name="nested-actions-array" select="map:get($action-map, 'nested-actions')" as="array(map(*))?"/>
        <xsl:variable name="nested-actions" as="map(*)*">
            <xsl:sequence select="array:flatten($nested-actions-array)"/>
        </xsl:variable>
        <xsl:variable name="name-action" as="map(*)?" select="($nested-actions[map:get(., 'name') = 'name'])[1]"/>
        <xsl:variable name="targetid-action" as="map(*)?" select="($nested-actions[map:get(., 'name') = 'targetid'])[1]"/>
        <xsl:variable name="delay-action" as="map(*)?" select="($nested-actions[map:get(., 'name') = 'delay'])[1]"/>
        
        <xsl:variable name="instance-context" as="xs:string" select="map:get($action-map, 'instance-context')"/>
        <xsl:variable name="instanceXML" as="element()?" select="xforms:instance($instance-context)"/>
        <xsl:variable name="dispatch-context-ref" as="xs:string?" select="map:get($action-map, '@context')"/>
        <xsl:variable name="dispatch-context-node" as="node()?" select="
            if (exists($dispatch-context-ref) and $dispatch-context-ref != '' and exists($instanceXML))
            then (xforms:evaluate-xpath-with-context-node($dispatch-context-ref,$instanceXML,()))[1]
            else $instanceXML"/>
        
        <xsl:variable name="name-from-child" as="xs:string?">
            <xsl:choose>
                <xsl:when test="exists($name-action) and exists(map:get($name-action, '@value')) and exists($dispatch-context-node)">
                    <xsl:try>
                        <xsl:sequence select="string(xforms:evaluate-xpath-with-context-node(map:get($name-action, '@value'),$dispatch-context-node,()))"/>
                        <xsl:catch>
                            <xsl:sequence select="string(map:get($name-action, '@value'))"/>
                        </xsl:catch>
                    </xsl:try>
                </xsl:when>
                <xsl:when test="exists($name-action) and exists(map:get($name-action, '@value'))">
                    <xsl:sequence select="string(map:get($name-action, '@value'))"/>
                </xsl:when>
                <xsl:when test="exists($name-action)">
                    <xsl:sequence select="normalize-space(string(map:get($name-action, 'value')))"/>
                </xsl:when>
                <xsl:otherwise/>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="targetid-from-child" as="xs:string?">
            <xsl:choose>
                <xsl:when test="exists($targetid-action) and exists(map:get($targetid-action, '@value')) and exists($dispatch-context-node)">
                    <xsl:try>
                        <xsl:sequence select="string(xforms:evaluate-xpath-with-context-node(map:get($targetid-action, '@value'),$dispatch-context-node,()))"/>
                        <xsl:catch>
                            <xsl:sequence select="string(map:get($targetid-action, '@value'))"/>
                        </xsl:catch>
                    </xsl:try>
                </xsl:when>
                <xsl:when test="exists($targetid-action) and exists(map:get($targetid-action, '@value'))">
                    <xsl:sequence select="string(map:get($targetid-action, '@value'))"/>
                </xsl:when>
                <xsl:when test="exists($targetid-action)">
                    <xsl:sequence select="normalize-space(string(map:get($targetid-action, 'value')))"/>
                </xsl:when>
                <xsl:otherwise/>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:variable name="event-name" as="xs:string?" select="
            if (exists(($name-from-child, map:get($action-map, '@name'))[1]) and normalize-space(string(($name-from-child, map:get($action-map, '@name'))[1])) != '')
            then normalize-space(string(($name-from-child, map:get($action-map, '@name'))[1]))
            else ()"/>
        <xsl:variable name="event-targetid" as="xs:string?" select="
            if (exists(($targetid-from-child, map:get($action-map, '@targetid'))[1]) and normalize-space(string(($targetid-from-child, map:get($action-map, '@targetid'))[1])) != '')
            then normalize-space(string(($targetid-from-child, map:get($action-map, '@targetid'))[1]))
            else ()"/>
        <xsl:variable name="event-bubbles" as="xs:boolean" select="xforms:event-flag(map:get($action-map, '@bubbles'), true())"/>
        <xsl:variable name="event-cancelable" as="xs:boolean" select="xforms:event-flag(map:get($action-map, '@cancelable'), false())"/>
        <xsl:variable name="delay-from-child" as="xs:string?">
            <xsl:choose>
                <xsl:when test="exists($delay-action) and exists(map:get($delay-action, '@value')) and exists($dispatch-context-node)">
                    <xsl:try>
                        <xsl:sequence select="string(xforms:evaluate-xpath-with-context-node(map:get($delay-action, '@value'),$dispatch-context-node,()))"/>
                        <xsl:catch>
                            <xsl:sequence select="string(map:get($delay-action, '@value'))"/>
                        </xsl:catch>
                    </xsl:try>
                </xsl:when>
                <xsl:when test="exists($delay-action) and exists(map:get($delay-action, '@value'))">
                    <xsl:sequence select="string(map:get($delay-action, '@value'))"/>
                </xsl:when>
                <xsl:when test="exists($delay-action)">
                    <xsl:sequence select="normalize-space(string(map:get($delay-action, 'value')))"/>
                </xsl:when>
                <xsl:otherwise/>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="delay-raw" as="xs:string?" select="
            if (exists($delay-from-child) and normalize-space($delay-from-child) != '')
            then normalize-space($delay-from-child)
            else (if (exists(map:get($action-map, '@delay'))) then normalize-space(string(map:get($action-map, '@delay'))) else ())"/>
        <!-- TEST-TRACE: apply xf:dispatch delay semantics with child xf:delay precedence,
             including xf:delay/@value precedence over child text; helps tests/w3c/ch10.spec.ts
             "10.8.c", "10.8.3.c". -->
        <xsl:variable name="delay-ms" as="xs:integer" select="
            if (exists($delay-raw) and $delay-raw castable as xs:double and xs:double($delay-raw) gt 0)
            then xs:integer(round(xs:double($delay-raw)))
            else 0"/>
        <xsl:variable name="dispatch-event-context" as="map(*)">
            <xsl:map>
                <xsl:if test="exists($event-targetid)">
                    <xsl:map-entry key="'targetid'" select="$event-targetid"/>
                </xsl:if>
                <xsl:map-entry key="'bubbles'" select="$event-bubbles"/>
                <xsl:map-entry key="'cancelable'" select="$event-cancelable"/>
            </xsl:map>
        </xsl:variable>
        
        <xsl:if test="exists($event-name)">
            <xsl:message use-when="$debugMode">[action-dispatch] action map: 
                name      = <xsl:value-of select="$event-name"/>
                targetid  = <xsl:value-of select="$event-targetid"/>
                bubbles   = <xsl:value-of select="$event-bubbles"/>
                cancelable= <xsl:value-of select="$event-cancelable"/>
            </xsl:message>
            <xsl:choose>
                <xsl:when test="$delay-ms gt 0">
                    <ixsl:schedule-action wait="$delay-ms">
                        <xsl:call-template name="xforms-event-handler">
                            <xsl:with-param name="event-name" select="$event-name" as="xs:string" tunnel="yes"/>
                            <xsl:with-param name="event-context" select="$dispatch-event-context" as="map(*)" tunnel="yes"/>
                        </xsl:call-template>
                    </ixsl:schedule-action>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:call-template name="xforms-event-handler">
                        <xsl:with-param name="event-name" select="$event-name" as="xs:string" tunnel="yes"/>
                        <xsl:with-param name="event-context" select="$dispatch-event-context" as="map(*)" tunnel="yes"/>
                    </xsl:call-template>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:if>
        
    </xsl:template>
   
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for applying message action</xd:p>
            <xd:p>XForms 1.1 spec <xd:a href="https://www.w3.org/TR/xforms11/#action-message">message element</xd:a></xd:p>
        </xd:desc>
        <xd:param name="action-map">Action map</xd:param>
    </xd:doc>
    <xsl:template name="action-message">
        <xsl:param name="action-map" required="yes" as="map(*)" tunnel="yes"/>
        
        <xsl:variable name="nested-actions-array" select="map:get($action-map, 'nested-actions')" as="array(map(*))?"/>
        <xsl:variable name="nested-actions" as="item()*">
            <xsl:sequence select="array:flatten($nested-actions-array)"/>
        </xsl:variable>
        
        <xsl:variable name="message-components" as="xs:string*">
            <!--<xsl:variable name="message-value" as="xs:string" select="map:get($action-map,'value')">
            -->
            <xsl:for-each select="$nested-actions">
                <xsl:call-template name="applyActions">
                    <xsl:with-param name="action-map" select="." tunnel="yes"/>
                </xsl:call-template>
            </xsl:for-each>
        </xsl:variable>
        
        <xsl:variable name="message-value" as="xs:string" select="string-join($message-components)"/>
        
        <!-- XForms 1.1 spec: The default is "modal" if the attribute is not specified -->
        <xsl:variable name="message-level" as="xs:string" select="(map:get($action-map,'@level'), 'modal')[1]"/>
        
<!--        <xsl:message use-when="$debugMode">[action-message] Message (level '<xsl:value-of select="$message-level"/>') reads "<xsl:value-of select="$message-value"/>"</xsl:message>-->
        
        <!-- TO DO: implement remainder of this action -->
        <xsl:choose>
            <xsl:when test="$message-level = 'ephemeral'">
                <xsl:call-template name="logToPage">
                    <xsl:with-param name="message" select="$message-value"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$message-level = 'modal'">
                <xsl:sequence select="ixsl:call(ixsl:window(), 'alert', [$message-value])"/>
            </xsl:when>
            <xsl:when test="$message-level = 'modeless'">
                <xsl:call-template name="logToPage">
                    <xsl:with-param name="message" select="$message-value"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:otherwise/>
        </xsl:choose>
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for applying output action (i.e. return a string value)</xd:p>
        </xd:desc>
        <xd:param name="action-map">Action map</xd:param>
        <xd:param name="context-node">Context node identified in applyActions template</xd:param>
    </xd:doc>
    <xsl:template name="action-output">
        <xsl:param name="action-map" required="yes" as="map(*)" tunnel="yes"/>
        <xsl:param name="context-node" as="node()?"/>
        
        <xsl:variable name="log-label" as="xs:string" select="'[action-output]'"/>
        <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> START</xsl:message>
        
        <xsl:variable name="instance-id" as="xs:string" select="map:get($action-map,'instance-context')"/>
        
        <!--<xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> context instance ID = <xsl:sequence select="$instance-id"/></xsl:message>-->
        
        <xsl:variable name="ref" as="xs:string?">
            <xsl:choose>
                <xsl:when test="map:get($action-map,'@value')">
                    <xsl:sequence select="map:get($action-map,'@value')"/>
                </xsl:when>
                <xsl:when test="map:get($action-map,'@ref')">
                    <xsl:sequence select="map:get($action-map,'@ref')"/>
                </xsl:when>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:variable name="value" as="item()?">
            <xsl:choose>
                <xsl:when test="exists($ref) and exists($context-node)">
                    <!--<xsl:message use-when="$debugMode">[action-output] evaluating <xsl:sequence select="$ref"/> against context node <xsl:sequence select="fn:serialize($context-node)"/></xsl:message>-->
                    <xsl:sequence select="xforms:evaluate-xpath-with-context-node($ref,$context-node,())"/>
                </xsl:when>
                <xsl:when test="exists($ref)">
                    <!--<xsl:message use-when="$debugMode">[action-output] evaluating <xsl:sequence select="$ref"/> against context instance</xsl:message>-->
                    <xsl:sequence select="xforms:evaluate-xpath-with-instance-id($ref,$instance-id,())"/>
                </xsl:when>
                <xsl:otherwise/>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:sequence select="string($value)"/>
        
        <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> END</xsl:message>
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for applying 'text' action (i.e. return a string value)</xd:p>
        </xd:desc>
        <xd:param name="action-map">Action map</xd:param>
    </xd:doc>
    <xsl:template name="action-text">
        <xsl:param name="action-map" required="yes" as="map(*)" tunnel="yes"/>
        <xsl:sequence select="map:get($action-map,'@value')"/>        
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for applying script action (XForms 2.0).</xd:p>
            <xd:p>Evaluates the text content of xf:script as JavaScript via window.eval().</xd:p>
        </xd:desc>
        <xd:param name="action-map">Action map</xd:param>
    </xd:doc>
    <xsl:template name="action-script">
        <xsl:param name="action-map" required="yes" as="map(*)" tunnel="yes"/>
        
        <xsl:variable name="log-label" as="xs:string" select="'[action-script]'"/>
        <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> START</xsl:message>
        
        <xsl:variable name="js-code" as="xs:string?" select="map:get($action-map, 'script-body')"/>
        
        <xsl:if test="exists($js-code) and $js-code ne ''">
            <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> Evaluating script: <xsl:value-of select="substring($js-code, 1, 100)"/></xsl:message>
            <xsl:sequence select="ixsl:call(ixsl:window(), 'eval', [$js-code])"/>
        </xsl:if>
        
        <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> END</xsl:message>
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for applying load action.</xd:p>
            <xd:p>See <xd:a href="https://www.w3.org/TR/xforms11/#action-load">XForms 1.1 §10.1.8 The load Element</xd:a></xd:p>
        </xd:desc>
        <xd:param name="action-map">Action map</xd:param>
    </xd:doc>
    <xsl:template name="action-load">
        <xsl:param name="action-map" required="yes" as="map(*)" tunnel="yes"/>
        
        <xsl:variable name="log-label" as="xs:string" select="'[action-load]'"/>
        <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> START</xsl:message>
        
        <xsl:variable name="resource" as="xs:string?" select="map:get($action-map, '@resource')"/>
        <xsl:variable name="show" as="xs:string" select="(map:get($action-map, '@show'), 'replace')[1]"/>
        
        <xsl:if test="exists($resource) and $resource ne ''">
            <xsl:choose>
                <!-- javascript: URI scheme - eval the expression -->
                <xsl:when test="starts-with($resource, 'javascript:')">
                    <xsl:variable name="js-expr" as="xs:string" select="substring-after($resource, 'javascript:')"/>
                    <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> Evaluating javascript: <xsl:value-of select="$js-expr"/></xsl:message>
                    <xsl:sequence select="ixsl:call(ixsl:window(), 'eval', [$js-expr])"/>
                </xsl:when>
                <!-- show="new" - open in new window/tab -->
                <xsl:when test="$show = 'new'">
                    <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> Opening '<xsl:value-of select="$resource"/>' in new window</xsl:message>
                    <xsl:sequence select="ixsl:call(ixsl:window(), 'open', [$resource])"/>
                </xsl:when>
                <!-- show="replace" (default) - navigate current window -->
                <xsl:otherwise>
                    <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> Navigating to '<xsl:value-of select="$resource"/>'</xsl:message>
                    <ixsl:set-property name="href" select="$resource" object="ixsl:get(ixsl:window(), 'location')"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:if>
        
        <xsl:message use-when="$debugMode"><xsl:sequence select="$log-label"/> END</xsl:message>
    </xsl:template>
    

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for applying setfocus action</xd:p>
        </xd:desc>
        <xd:param name="action-map">Action map</xd:param>
    </xd:doc>
    <xsl:template name="action-setfocus">
        <xsl:param name="action-map" required="yes" as="map(*)" tunnel="yes"/>

        <!-- first apply deferred update behaviour -->
        <xsl:call-template name="outermost-action-handler"/>
        
        <xsl:variable name="control" as="xs:string" select="map:get($action-map,'@control')"/>
        
        <xsl:call-template name="xforms-focus">
            <xsl:with-param name="control" select="$control"/>
        </xsl:call-template>
        
    </xsl:template>
    

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for applying send action</xd:p>
        </xd:desc>
        <xd:param name="action-map">Action map</xd:param>
    </xd:doc>
    <xsl:template name="action-send">
        <xsl:param name="action-map" required="yes" as="map(*)" tunnel="yes"/>
                
<!--        <xsl:message use-when="$debugMode">[action-send] $action-map = <xsl:value-of select="serialize($action-map)"/></xsl:message>-->
        
        <xsl:variable name="submission" as="xs:string" select="map:get($action-map,'@submission')"/>
        <xsl:if test="$sequence-template-trace-enabled">
            <xsl:message>[SEQTRACE] template=action-send submission=<xsl:value-of select="$submission"/></xsl:message>
        </xsl:if>
        
        <xsl:call-template name="xforms-submit">
            <xsl:with-param name="submission" select="$submission"/>
        </xsl:call-template>
         
    </xsl:template>
    

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for applying setindex action</xd:p>
        </xd:desc>
        <xd:param name="action-map">Action map</xd:param>
    </xd:doc>
    <xsl:template name="action-setindex">
        <xsl:param name="action-map" required="yes" as="map(*)" tunnel="yes"/>
        
        <!-- first apply deferred update behaviour -->
        <xsl:call-template name="outermost-action-handler"/>

        <xsl:variable name="repeatID" as="xs:string" select="map:get($action-map,'@repeat')"/>
        <xsl:variable name="new-index-ref" as="xs:string" select="map:get($action-map,'@index')"/>
        
                
        <xsl:variable name="new-index" as="xs:integer">
            <xsl:evaluate xpath="xforms:impose($new-index-ref)"/>
        </xsl:variable>
        <xsl:variable name="repeat-size-cached" as="xs:integer" select="xs:integer(js:getRepeatSize($repeatID))"/>
        <xsl:variable name="repeat-ref" as="xs:string" select="string(js:getRepeatRef($repeatID))"/>
        <xsl:variable name="repeat-instance-id" as="xs:string" select="string(js:getRepeatInstanceId($repeatID))"/>
        <xsl:variable name="repeat-size-live" as="xs:integer" select="
            if ($repeat-size-cached gt 0)
            then $repeat-size-cached
            else (
                if ($repeat-ref != '' and $repeat-instance-id != '')
                then count(xforms:evaluate-xpath-with-instance-id($repeat-ref,$repeat-instance-id,()))
                else 0
            )"/>
        <xsl:variable name="repeat-size" as="xs:integer" select="$repeat-size-live"/>
        <xsl:variable name="effective-index" as="xs:integer" select="
            if ($repeat-size lt 1)
            then 0
            else (
                if ($new-index lt 1)
                then 1
                else (
                    if ($new-index gt $repeat-size)
                    then $repeat-size
                    else $new-index
                )
            )"/>
        
<!--        <xsl:message use-when="$debugMode">[action-setindex] $action-map = <xsl:value-of select="serialize($action-map)"/></xsl:message>-->
        
        <xsl:sequence select="js:setRepeatIndex($repeatID,$effective-index)"/>
        <xsl:call-template name="refreshOutputs-JS"/>
        <xsl:call-template name="refreshElementsUsingIndexFunction-JS"/>
        <xsl:if test="$repeat-size gt 0 and $new-index lt 1">
            <xsl:variable name="scroll-first-context" as="map(*)">
                <xsl:map>
                    <xsl:map-entry key="'targetid'" select="$repeatID"/>
                    <xsl:map-entry key="'bubbles'" select="false()"/>
                    <xsl:map-entry key="'cancelable'" select="false()"/>
                </xsl:map>
            </xsl:variable>
            <xsl:call-template name="xforms-event-handler">
                <xsl:with-param name="event-name" select="'xforms-scroll-first'" as="xs:string" tunnel="yes"/>
                <xsl:with-param name="event-context" select="$scroll-first-context" as="map(*)" tunnel="yes"/>
            </xsl:call-template>
        </xsl:if>
        <xsl:if test="$repeat-size gt 0 and $new-index gt $repeat-size">
            <xsl:variable name="scroll-last-context" as="map(*)">
                <xsl:map>
                    <xsl:map-entry key="'targetid'" select="$repeatID"/>
                    <xsl:map-entry key="'bubbles'" select="false()"/>
                    <xsl:map-entry key="'cancelable'" select="false()"/>
                </xsl:map>
            </xsl:variable>
            <xsl:call-template name="xforms-event-handler">
                <xsl:with-param name="event-name" select="'xforms-scroll-last'" as="xs:string" tunnel="yes"/>
                <xsl:with-param name="event-context" select="$scroll-last-context" as="map(*)" tunnel="yes"/>
            </xsl:call-template>
        </xsl:if>
        
    </xsl:template>
    
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for applying recalculate action</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template name="action-recalculate">
        <xsl:message use-when="$debugMode">[action-recalculate] START</xsl:message>
        
        <xsl:call-template name="xforms-recalculate"/>
        <xsl:sequence select="js:clearDeferredUpdateFlag('recalculate')"/>
        
        <xsl:message use-when="$debugMode">[action-recalculate] END</xsl:message>
    </xsl:template>

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for applying revalidate action</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template name="action-revalidate">
        <!-- TEST-TRACE: ensure explicit xf:revalidate executes the same validation pipeline as deferred updates;
             helps tests/supplemental/saxon-forms-validation.spec.ts. -->
        <xsl:message use-when="$debugMode">[action-revalidate] START</xsl:message>
        <xsl:sequence select="js:setForceFullValidationFeedback(true())"/>
        <xsl:call-template name="xforms-revalidate"/>
        <xsl:call-template name="xforms-refresh"/>
        <xsl:sequence select="js:clearDeferredUpdateFlag('revalidate')"/>
        
        <xsl:message use-when="$debugMode">[action-revalidate] END</xsl:message>
    </xsl:template>

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for applying refresh action</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template name="action-refresh">
        <xsl:message use-when="$debugMode">[action-refresh] START</xsl:message>
        
        <xsl:call-template name="xforms-refresh"/>
        <xsl:sequence select="js:clearDeferredUpdateFlag('refresh')"/>
        <xsl:sequence select="js:clearDirtyInstances()"/>
        <xsl:sequence select="js:clearPendingMutations()"/>
        
        <xsl:message use-when="$debugMode">[action-refresh] END</xsl:message>
    </xsl:template>

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for applying reset action</xd:p>
            <xd:p>Resets all stored javascript variables to their initial values.</xd:p>
            <xd:p>TO DO: apply this on a per-model basis.</xd:p>
        </xd:desc>
        <xd:param name="action-map">Action map</xd:param>
    </xd:doc>
    <!-- TEST-TRACE: restore initial instance snapshots on reset instead of full re-init;
         helps tests/w3c/ch10.spec.ts "10.a", "10.13.b" -->
    <xsl:template name="action-reset">
        <xsl:param name="action-map" required="yes" as="map(*)" tunnel="yes"/>
        
        <xsl:variable name="requested-model-id" as="xs:string?" select="map:get($action-map, '@model')"/>
        <xsl:variable name="target-model-id" as="xs:string" select="
            if (exists($requested-model-id) and normalize-space($requested-model-id) != '')
            then normalize-space($requested-model-id)
            else xforms:get-default-model-id()"/>
        <xsl:variable name="target-instance-ids" as="xs:string*" select="xforms:get-model-instance-ids($target-model-id)"/>
        <xsl:variable name="implicit-default-instance-id" as="xs:string"
            select="xforms:get-model-implicit-default-instance-id($target-model-id)"/>
        <xsl:variable name="reset-event-context" as="map(*)">
            <xsl:map>
                <xsl:map-entry key="'targetid'" select="$target-model-id"/>
                <xsl:map-entry key="'bubbles'" select="false()"/>
                <xsl:map-entry key="'cancelable'" select="true()"/>
            </xsl:map>
        </xsl:variable>
        <xsl:variable name="default-action-cancelled" as="xs:boolean"
            select="xforms:is-event-default-cancelled('xforms-reset', $reset-event-context)"/>
        
        <xsl:message use-when="$debugMode">[action-reset] Reset triggered for model '<xsl:value-of select="$target-model-id"/>' (cancelled=<xsl:value-of select="$default-action-cancelled"/>)</xsl:message>
        
        <xsl:call-template name="xforms-event-handler">
            <xsl:with-param name="event-name" select="'xforms-reset'" as="xs:string" tunnel="yes"/>
            <xsl:with-param name="event-context" select="$reset-event-context" as="map(*)" tunnel="yes"/>
        </xsl:call-template>
        
        <xsl:if test="not($default-action-cancelled)">
            <xsl:for-each select="$target-instance-ids">
                <xsl:variable name="instance-id" as="xs:string" select="."/>
                <xsl:variable name="initial-instance" as="element()?" select="js:getInitialInstance($instance-id)"/>
                <xsl:if test="exists($initial-instance)">
                    <xsl:sequence select="js:setInstance($instance-id,$initial-instance)"/>
                </xsl:if>
            </xsl:for-each>
            <xsl:if test="$target-model-id = xforms:get-default-model-id() and exists($target-instance-ids[1])">
                <xsl:variable name="primary-instance-id" as="xs:string" select="$target-instance-ids[1]"/>
                <xsl:variable name="primary-instance" as="element()?" select="js:getInitialInstance($primary-instance-id)"/>
                <xsl:if test="exists($primary-instance)">
                    <xsl:sequence select="js:setDefaultInstance($primary-instance)"/>
                    <xsl:if test="$implicit-default-instance-id != $primary-instance-id">
                        <xsl:sequence select="js:setInstance($implicit-default-instance-id,$primary-instance)"/>
                    </xsl:if>
                </xsl:if>
            </xsl:if>
            <xsl:sequence select="js:setDeferredUpdateFlags(('rebuild','recalculate','revalidate','refresh'))"/>
        </xsl:if>
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for applying toggle action</xd:p>
        </xd:desc>
        <xd:param name="action-map">Action map</xd:param>
        <xd:param name="context-node">Context node identified in applyActions template</xd:param>
    </xd:doc>
    <xsl:template name="action-toggle">
        <xsl:param name="action-map" required="yes" as="map(*)" tunnel="yes"/>
        <xsl:param name="context-node" as="node()?"/>
        <xsl:param name="source-control" as="node()?" required="no"/>
        
        <xsl:message use-when="$debugMode">[action-toggle] START</xsl:message>
        
        <!-- first apply deferred update behaviour -->
        <xsl:call-template name="outermost-action-handler"/>
        
        <xsl:variable name="case-id-fixed" as="xs:string?" select="map:get($action-map,'@case')"/>
        <xsl:variable name="case-id-evaluated" as="xs:string?" select="map:get($action-map,'case')"/>
        
        <!-- "The case to be selected by the toggle action is given by the case attribute or the case element. If both are given, the element takes precedence." -->
        <xsl:variable name="requested-case-id" as="xs:string?">
            <xsl:choose>
                <xsl:when test="exists($case-id-evaluated) and normalize-space($case-id-evaluated) != '' and exists($context-node)">
                    <xsl:sequence select="string(xforms:evaluate-xpath-with-context-node($case-id-evaluated,$context-node,()))"/>
                </xsl:when>
                <xsl:when test="exists($case-id-fixed) and normalize-space($case-id-fixed) != ''">
                    <xsl:sequence select="$case-id-fixed"/>
                </xsl:when>
                <xsl:otherwise/>
            </xsl:choose>
        </xsl:variable>
        
        <!-- scope to nearest rendered switch when toggle is inside repeat -->
        <xsl:variable name="switch-id-scoped" as="xs:string?" select="
            if (exists($source-control))
            then ((($source-control/ancestor-or-self::*[@data-switch-id])[1]/@data-switch-id) ! string(.))[1]
            else ()"/>
        <xsl:variable name="case-id-scoped" as="xs:string?" select="
            if (exists($switch-id-scoped) and normalize-space($switch-id-scoped) != '' and exists($requested-case-id) and normalize-space($requested-case-id) != '')
            then ((ixsl:page()//*[@data-switch-id = $switch-id-scoped and @data-case-id-base = $requested-case-id][1]/@id) ! string(.))[1]
            else ()"/>
        <xsl:variable name="case-id" as="xs:string?" select="(($case-id-scoped,$requested-case-id)[normalize-space(.) != ''])[1]"/>
        <xsl:variable name="switch-id" as="xs:string?" select="
            if (exists($switch-id-scoped) and normalize-space($switch-id-scoped) != '')
            then $switch-id-scoped
            else (if (exists($case-id) and normalize-space($case-id) != '') then js:getCaseSwitch($case-id) else ())"/>
        <xsl:variable name="current-switch-selection" as="xs:string?" select="if (exists($switch-id) and normalize-space($switch-id) != '') then js:getSwitchSelection($switch-id) else ()"/>
        <xsl:variable name="current-case-base" as="xs:string?" select="
            if (normalize-space($current-switch-selection) != '')
            then (
                string((ixsl:page()//*[@id eq $current-switch-selection][1]/@data-case-id-base)[1]),
                replace($current-switch-selection, '-[0-9]+$', '')
            )[1]
            else ()"/>
        <xsl:variable name="selected-case-base" as="xs:string?" select="
            if (exists($case-id))
            then (
                $requested-case-id,
                string((ixsl:page()//*[@id eq $case-id][1]/@data-case-id-base)[1]),
                replace($case-id, '-[0-9]+$', '')
            )[1]
            else ()"/>
        
        <xsl:if test="exists($switch-id) and normalize-space($switch-id) != '' and exists($case-id) and normalize-space($case-id) != ''">
            <xsl:if test="exists($current-case-base)">
                <xsl:variable name="deselect-event-context" as="map(*)">
                    <xsl:map>
                        <xsl:map-entry key="'targetid'" select="$current-case-base"/>
                        <xsl:map-entry key="'bubbles'" select="false()"/>
                        <xsl:map-entry key="'cancelable'" select="false()"/>
                    </xsl:map>
                </xsl:variable>
                <xsl:call-template name="xforms-event-handler">
                    <xsl:with-param name="event-name" select="'xforms-deselect'" as="xs:string" tunnel="yes"/>
                    <xsl:with-param name="event-context" select="$deselect-event-context" as="map(*)" tunnel="yes"/>
                </xsl:call-template>
            </xsl:if>
            
            <xsl:if test="exists($current-switch-selection) and normalize-space($current-switch-selection) != ''">
                <xsl:sequence select="js:deselectCase($current-switch-selection)"/>
            </xsl:if>
            <xsl:sequence select="js:selectCase($case-id)"/>
            <xsl:sequence select="js:setSwitchSelection($switch-id,$case-id)"/>
            
            <xsl:variable name="case-off" as="element()?" select="ixsl:page()//*[@id eq $current-switch-selection]"/>
            <xsl:if test="exists($case-off)">
                <ixsl:set-style name="display" select="'none'" object="$case-off"/>
            </xsl:if>
            
            <xsl:variable name="case-on" as="element()?" select="ixsl:page()//*[@id eq $case-id]"/>
            <xsl:if test="exists($case-on)">
                <ixsl:remove-property name="style.display" object="$case-on"/>
                <ixsl:remove-attribute name="style" object="$case-on"/>
            </xsl:if>
            
            <xsl:if test="exists($selected-case-base)">
                <xsl:variable name="select-event-context" as="map(*)">
                    <xsl:map>
                        <xsl:map-entry key="'targetid'" select="$selected-case-base"/>
                        <xsl:map-entry key="'bubbles'" select="false()"/>
                        <xsl:map-entry key="'cancelable'" select="false()"/>
                    </xsl:map>
                </xsl:variable>
                <xsl:call-template name="xforms-event-handler">
                    <xsl:with-param name="event-name" select="'xforms-select'" as="xs:string" tunnel="yes"/>
                    <xsl:with-param name="event-context" select="$select-event-context" as="map(*)" tunnel="yes"/>
                </xsl:call-template>
            </xsl:if>
        </xsl:if>
        <xsl:message use-when="$debugMode">[action-toggle] END</xsl:message>
    </xsl:template>
</xsl:stylesheet>
