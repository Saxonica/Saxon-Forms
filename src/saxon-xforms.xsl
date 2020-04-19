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
    xmlns:xf="http://www.w3.org/2002/xforms"
    xmlns:js="http://saxonica.com/ns/globalJS" 
    xmlns:ixsl="http://saxonica.com/ns/interactiveXSLT"
    xmlns:sfl="http://saxonica.com/ns/forms-local"
    xmlns:sfp="http://saxon.sf.net/ns/packages" 
    
    xmlns:in="http://www.w3.org/2002/xforms-instance"
    xmlns:fn="http://www.w3.org/2005/xpath-functions"
    xmlns:map="http://www.w3.org/2005/xpath-functions/map"
    xmlns:array="http://www.w3.org/2005/xpath-functions/array"
    xmlns:saxon="http://saxon.sf.net/"
    xmlns:ev="http://www.w3.org/2001/xml-events"
        
    exclude-result-prefixes="xs math xforms sfl sfp"
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
    <xsl:include href="xforms-javascript-library.xsl"/>
    
    <xsl:output method="html" encoding="utf-8" omit-xml-declaration="no" indent="no"
        doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN"
        doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"/>
    
    <!-- use case where saxon-forms.xsl is imported means we can't yet use a package -->
    <!--<xsl:use-package name="http://saxon.sf.net/packages/logger.xsl" package-version="1.0">
        <xsl:override>
            <xsl:variable name="sfp:LOGLEVEL" select="$LOGLEVEL_INT" as="xs:integer"/>
        </xsl:override>
    </xsl:use-package>-->
    
    <xsl:param name="LOGLEVEL" as="xs:string" select="'40'" required="no"/>
    <xsl:variable name="LOGLEVEL_INT" as="xs:integer" select="if ($LOGLEVEL castable as xs:integer) then xs:integer($LOGLEVEL) else 100"/>

    <xsl:param name="xforms-instance-id" select="'xforms-jinstance'" as="xs:string" required="no"/>
    <xsl:param name="xforms-cache-id" select="'xforms-cache'" as="xs:string" required="no"/>
    
    <!-- @id attribute of HTML div element into which the XForm is to be rendered on the page -->
    <xsl:param name="xform-html-id" as="xs:string" select="'xForm'" required="no"/>
    
    <xsl:param name="xforms-file-global" as="xs:string?"/>
    
    <xsl:param name="xforms-doc-global" as="document-node()?" required="no" select="if (exists($xforms-file-global) and fn:doc-available($xforms-file-global)) then fn:doc($xforms-file-global) else (if (exists(/) and namespace-uri(/*) = 'http://www.w3.org/2002/xforms') then (/) else ())"/>

    <xsl:variable static="yes" name="debugMode" select="true()"/>
    <xsl:variable static="yes" name="debugTiming" select="false()"/>
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
    </xd:doc>
    <xsl:template name="xformsjs-main">
        <xsl:param name="xforms-doc" as="document-node()?" required="no" select="()"/>
        <xsl:param name="xforms-file" as="xs:string?" required="no"/>
        <xsl:param name="instance-docs" as="map(*)?" required="no"/>   
        <xsl:param name="xFormsId" select="$xform-html-id" as="xs:string" required="no"/>
        
        <xsl:message use-when="$debugMode">[xformsjs-main] START</xsl:message>
<!--        <xsl:sequence select="sfp:logInfo('[xformsjs-main] START')"/>-->
        
       
        <xsl:apply-templates select="ixsl:page()//*:head" mode="set-js"/>
        
       
        <!-- 
            Populate $xforms-doci (local to this template) 
            using explicit parameter values if present
            (since this template can be called from an importing stylesheet),
            then falling back to global parameters
        -->
        <xsl:variable name="xforms-doci" as="document-node()?">
            <xsl:choose>
                <xsl:when test="$xforms-doc">
                    <xsl:sequence select="$xforms-doc"/>
                </xsl:when>
                <xsl:when test="fn:doc-available($xforms-file)">
                    <xsl:sequence select="fn:doc($xforms-file)"/>
                </xsl:when>
                <xsl:when test="$xforms-doc-global">
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
        
        
        <xsl:variable name="xform" as="element(xforms:xform)" select="xforms:addNamespaceDeclarations($xforms-doci/*)"/>  
        
        <xsl:variable name="first-model" as="element(xforms:model)" select="$xforms-doci/xforms:xform/xforms:model[1]"/>
        <xsl:variable name="first-model-id" as="attribute()?" select="$first-model/@id"/>
        <xsl:variable name="first-instance" as="element(xforms:instance)" select="$first-model/xforms:instance[1]"/>
        <xsl:variable name="first-instance-id" as="attribute()?" select="$first-instance/@id"/>
        <xsl:variable name="default-instance-id" as="xs:string" select="if (exists($first-instance-id)) then $first-instance-id else $global-default-instance-id"/>
        
        
        <xsl:variable name="models" as="element(xforms:model)*" select="$xforms-doci/xforms:xform/xforms:model"/>
        
        <xsl:if test="count($models[not(@id)]) gt 1">
            <xsl:variable name="message" as="xs:string" select="'[xformsjs-main] FATAL ERROR: The XForm contains more than one model with no ID. At most one model may have no ID.'"/>
            <xsl:message terminate="yes" select="$message"/>
        </xsl:if>
        <xsl:for-each select="$models">
            <xsl:message use-when="$debugMode">[xformsjs-main] Construct model ...</xsl:message>
            <xsl:call-template name="xforms-model-construct">
                <xsl:with-param name="model" select="." tunnel="yes"/>
                <xsl:with-param name="default-model-id" select="if (exists($first-model-id)) then $first-model-id else $global-default-model-id" tunnel="yes"/>
                <xsl:with-param name="default-instance-id" select="$default-instance-id" tunnel="yes"/>
            </xsl:call-template>                       
        </xsl:for-each>    
        
        
        <!-- populate Javascript variables -->
        <xsl:sequence select="js:setXFormsDoc($xforms-doci)"/>
        <xsl:sequence select="js:setXForm($xform)"/>
        <!-- clear deferred update flags only if we're building from scratch -->
        <xsl:if test="empty($instance-docs)">
            <xsl:sequence select="js:clearDeferredUpdateFlags()" />    
        </xsl:if>
        
        

        <!-- register submissions in a map -->
        <xsl:variable name="submissions" as="map(xs:string, map(*))">
            <xsl:map>
                <xsl:for-each select="$xforms-doci/xforms:xform/xforms:model/xforms:submission">
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
        

        <xsl:variable name="time-id" select="generate-id()"/>
        <xsl:sequence use-when="$debugTiming" select="js:startTime(concat('XForms Main-Build', $time-id))" />
        
        
        <!-- Write HTML to placeholder <div id="xForm"> -->
        <xsl:result-document href="#{$xFormsId}" method="ixsl:replace-content">
            <xsl:apply-templates select="$xforms-doci/xforms:xform">
                <xsl:with-param name="bindings-js" select="js:getBindings()" as="element(xforms:bind)*" tunnel="yes"/>
                <xsl:with-param name="submissions" select="$submissions" as="map(xs:string, map(*))" tunnel="yes"/>
                <!-- clear nodeset when (re)building  -->
                <xsl:with-param name="nodeset" select="''" as="xs:string" tunnel="yes"/>
                <xsl:with-param name="default-instance-id" select="$default-instance-id" tunnel="yes"/>
            </xsl:apply-templates>
        </xsl:result-document>
        
        <xsl:sequence use-when="$debugTiming" select="js:endTime(concat('XForms Main-Build', $time-id))" />

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
                </script>
            </xsl:result-document>   
        </xsl:if>
        
     </xsl:template>
    


    
    <xd:doc scope="component">
        <xd:desc>Handle incremental change to HTML input</xd:desc>
    </xd:doc>
    <xsl:template match="*:input[xforms:hasClass(.,'incremental')]" mode="ixsl:onkeyup">
        <xsl:call-template name="action-setvalue-form-control">
            <xsl:with-param name="form-control" select="."/>
        </xsl:call-template>
        <xsl:call-template name="outermost-action-handler"/>
    </xsl:template>


    <xd:doc scope="component">
        <xd:desc>Handle change to HTML form control value</xd:desc>
    </xd:doc>
    <xsl:template match="*:input | *:select | *:textarea" mode="ixsl:onchange">
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
        <xsl:sequence select="js:highlightClicked( string(@id) )"/>
                
        <!-- update repeat index of ancestors (we may have clicked on a repeat item within a repeat item) -->
        <xsl:for-each select="./ancestor::*:div[@data-repeat-item = 'true']">
            <xsl:variable name="repeat-id" as="xs:string" select="./ancestor::*:div[exists(@data-repeatable-context)][1]/@id"/>
            <xsl:variable name="item-position" as="xs:integer" select="count(./preceding-sibling::*:div[@data-repeat-item = 'true']) + 1"/>
            
<!--            <xsl:message use-when="$debugMode">[div onclick] Setting repeat index '<xsl:value-of select="$repeat-id"/>' to value '<xsl:value-of select="$item-position"/>'</xsl:message>-->
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
        <xd:desc>get-binding mode: return xforms:bind element(s) relevant to context XForm element.</xd:desc>
        <xd:param name="nodeset">XPath binding expression</xd:param>
        <xd:param name="instance-id">ID of context instance.</xd:param>
        <xd:param name="bindings-js">Node set of xforms:bind elements</xd:param>   
    </xd:doc>
    <xsl:template match="xforms:*" mode="get-binding">
        <xsl:param name="instance-id" as="xs:string" required="no" select="$global-default-instance-id" tunnel="yes"/>
        <xsl:param name="nodeset" as="xs:string" required="no" select="''" tunnel="yes"/>
        <xsl:param name="bindings-js" as="element(xforms:bind)*" required="no" select="()" tunnel="yes"/>
        
<!--        <xsl:message use-when="$debugMode">[get-binding mode for <xsl:sequence select="name()"/>] START</xsl:message>-->

        <xsl:choose>
            <xsl:when test="exists(@bind)">
                <xsl:variable name="bind" as="xs:string" select="xs:string(@bind)"/>
                <xsl:variable name="this-binding" as="element(xforms:bind)?" select="ancestor::xforms:xform//xforms:bind[@id = $bind]"/>
                <xsl:choose>
                    <xsl:when test="exists($this-binding)">
                        <xsl:apply-templates select="$this-binding" mode="add-context"/>
                    </xsl:when>
                    <xsl:otherwise>                        
                        <!-- 
                            TO DO: xforms-binding-exception
                            
                            https://www.w3.org/TR/xforms11/#evt-bindingException
                        -->
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <xsl:when test="$nodeset != '' and exists($bindings-js)">
                
                <xsl:variable name="nodeset-mod" as="xs:string" select="xforms:impose($nodeset)"/>
                <xsl:variable name="instanceXML" as="element()" select="js:getInstance($instance-id)"/>
                <xsl:variable name="context-node" as="node()*">
                    <xsl:evaluate xpath="$nodeset-mod" context-item="$instanceXML" namespace-context="$instanceXML"/>
                </xsl:variable>
               
<!--                <xsl:message use-when="$debugMode">[get-binding mode for <xsl:value-of select="name(.)"/>] context node: <xsl:sequence select="fn:serialize($context-node)"/></xsl:message>-->
                
                <xsl:for-each select="$bindings-js">
                    <!-- only start check if the instance ID matches -->
                    <xsl:if test="@instance-context = $instance-id">
                        <!-- could do a string check here of $nodeset-mod = $binding-nodeset-mod (as a shortcut) -->                        
                        <xsl:variable name="binding-nodeset-mod" as="xs:string" select="xforms:impose(xs:string(@nodeset))"/>
                        
                        <xsl:variable name="binding-context-node" as="node()*">
                            <xsl:evaluate xpath="$binding-nodeset-mod" context-item="$instanceXML" namespace-context="$instanceXML"/>
                        </xsl:variable>
                                                
                        <xsl:if test="some $n in $binding-context-node satisfies $n is $context-node">
<!--                            <xsl:message use-when="$debugMode">[get-binding mode for <xsl:value-of select="name(.)"/>] Binding found: <xsl:value-of select="serialize(.)"/></xsl:message>-->
                            <xsl:sequence select="."/>
                        </xsl:if>
                    </xsl:if>
                   
                </xsl:for-each>
            </xsl:when>
            <xsl:otherwise>
                
                
            </xsl:otherwise>
        </xsl:choose>
        
    </xsl:template>
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>get-context-instance-id mode: return ID of instance that is the context of an XForms element.</xd:p>
        </xd:desc>
        <xd:param name="default-instance-id">ID of default instance in XForm.</xd:param>
        <xd:param name="nodeset">XPath binding expression</xd:param>
    </xd:doc>
    <xsl:template match="xforms:*" mode="get-context-instance-id" as="xs:string">
        <xsl:param name="default-instance-id" as="xs:string" required="no" select="$global-default-instance-id" tunnel="yes"/>
        <xsl:param name="nodeset" as="xs:string" required="no" select="''"/>
        
        <!-- use $nodeset if present -->
        <xsl:variable name="referenced-instance-id" as="xs:string?">
            <xsl:choose>
                <xsl:when test="exists(@bind)">
                    <xsl:variable name="bind" as="xs:string" select="xs:string(@bind)"/>
                    <xsl:variable name="this-binding" as="element(xforms:bind)?" select="ancestor::xforms:xform//xforms:bind[@id = $bind]"/>
                    <xsl:choose>
                        <xsl:when test="exists($this-binding)">
                            <xsl:apply-templates select="$this-binding" mode="get-context-instance-id">
                                <xsl:with-param name="nodeset" select="if (@nodeset) then xs:string(@nodeset) else ''"/>
                            </xsl:apply-templates>
                        </xsl:when>
                        <xsl:otherwise>                        
                            <!-- 
                            TO DO: xforms-binding-exception
                            
                            https://www.w3.org/TR/xforms11/#evt-bindingException
                        -->
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:when>
                <xsl:when test="$nodeset != ''">
                    <xsl:sequence select="xforms:getInstanceId($nodeset)"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="$default-instance-id"/>
                </xsl:otherwise>
           </xsl:choose>
        </xsl:variable>
        
<!--        <xsl:message use-when="$debugMode">[get-context-instance-id mode for <xsl:sequence select="name()"/>] ID derived from nodeset = <xsl:sequence select="$referenced-instance-id"/></xsl:message>-->
        <xsl:choose>
            <xsl:when test="exists($referenced-instance-id)">
                <xsl:sequence select="$referenced-instance-id"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="local-default-instance" as="element(xforms:instance)?" select="
                    if (./ancestor::xforms:model) 
                    then ancestor::xforms:model/xforms:instance[1]
                    else ancestor::xforms:xform/xforms:model[1]/xforms:instance[1]"/>
                <xsl:choose>
                    <xsl:when test="exists($local-default-instance)">
                        <xsl:sequence select="if (exists($local-default-instance/@id)) then xs:string($local-default-instance/@id) else $default-instance-id"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:sequence select="$default-instance-id"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:otherwise>
            
        </xsl:choose>
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>get-data-ref mode: return XPath binding expression relevant to context XForm element</xd:p>
        </xd:desc>
        <xd:param name="nodeset">An XPath binding expression. If it exists, $this/@ref is evaluated relative to it.</xd:param>
    </xd:doc>
    <xsl:template match="xforms:*" mode="get-data-ref" as="xs:string">
        <xsl:param name="nodeset" as="xs:string" select="''" tunnel="yes"/>
        
        <xsl:choose>
            <xsl:when test="exists(@bind)">
                <xsl:variable name="bind" as="xs:string" select="xs:string(@bind)"/>
                <xsl:variable name="this-binding" as="element(xforms:bind)?" select="ancestor::xforms:xform//xforms:bind[@id = $bind]"/>
                <xsl:choose>
                    <xsl:when test="exists($this-binding)">
                        <xsl:apply-templates select="$this-binding" mode="get-data-ref">
                            <xsl:with-param name="nodeset" select="if (@nodeset) then xs:string(@nodeset) else ''"/>
                        </xsl:apply-templates>
                    </xsl:when>
                    <xsl:otherwise>             
                        <xsl:call-template name="xforms-binding-exception">
                            <xsl:with-param name="message" select="concat('No binding found with ID ', $bind)"/>
                        </xsl:call-template>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="this-ref" as="xs:string?" select="
                    if ( exists(@nodeset) )
                    then  normalize-space( xs:string(@nodeset) )
                    else if ( exists(@ref) ) 
                    then normalize-space( xs:string(@ref) ) 
                    else ()"/>
                
                <xsl:variable name="this-context" as="xs:string?" select="
                    if ( exists(@context) )
                    then  normalize-space( xs:string(@context) )
                    else '.'"/>
                
                <xsl:variable name="data-ref" as="xs:string">
                    <xsl:choose>
                        <xsl:when test="exists($this-ref) and $nodeset = ''">
                            <xsl:sequence select="xforms:resolveXPathStrings($this-context,$this-ref)"/>
                        </xsl:when>
                        <xsl:when test="exists($this-ref)">
                            <xsl:sequence select="xforms:resolveXPathStrings($nodeset,$this-ref)"/>
                        </xsl:when>
                        <xsl:when test="$nodeset != ''">
                            <xsl:sequence select="xforms:resolveXPathStrings('',$nodeset)"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="$nodeset"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                
<!--                <xsl:message use-when="$debugMode">[get-data-ref for <xsl:sequence select="name(.)"/>] $data-ref = '<xsl:value-of select="$data-ref"/>'</xsl:message>-->

                <xsl:sequence select="$data-ref"/>
            </xsl:otherwise>
        </xsl:choose>
        
        
        
        
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>set-actions mode: create map of actions relevant to XForm control element</xd:desc>
    </xd:doc>
    <xsl:template match="xforms:*" mode="set-actions">
        <xsl:apply-templates select=" xforms:action | xforms:*[local-name() = $xforms-actions] | xforms:show | xforms:hide | xforms:script | xforms:unload"/>
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>set-action mode: create map of an action relevant to XForm action element</xd:desc>
        <xd:param name="instance-id">ID of context instance.</xd:param>
        <xd:param name="nodeset">XPath binding expression</xd:param>
        <xd:param name="handler-status">String value 'outermost' (default) or 'inner' to determine whether the action produces <xd:a href="https://www.w3.org/TR/xforms11/#action-deferred-update-behavior">deferred updates</xd:a></xd:param>
    </xd:doc>
    <xsl:template match="xforms:*" mode="set-action">
        <xsl:param name="instance-id" as="xs:string" required="no" select="$global-default-instance-id" tunnel="yes"/>
        <xsl:param name="nodeset" as="xs:string" select="''" tunnel="yes"/>
        <xsl:param name="handler-status" select="'outermost'" required="no" tunnel="yes"/>
        
<!--        <xsl:message use-when="$debugMode">[set-action mode for <xsl:sequence select="name()"/>] START</xsl:message>-->
                                     
        <xsl:variable name="refi" as="xs:string">
            <xsl:apply-templates select="." mode="get-data-ref">
                <xsl:with-param name="nodeset" select="$nodeset"/>
            </xsl:apply-templates>
        </xsl:variable>
        
        <xsl:variable name="this-instance-id" as="xs:string">
            <xsl:apply-templates select="." mode="get-context-instance-id">
                <xsl:with-param name="nodeset" select="$refi"/>
            </xsl:apply-templates>
        </xsl:variable>

        <xsl:variable name="bindingi" as="element(xforms:bind)*">
            <xsl:apply-templates select="." mode="get-binding">
                <xsl:with-param name="instance-id" select="$this-instance-id" tunnel="yes"/>
                <xsl:with-param name="nodeset" select="$refi" tunnel="yes"/>
            </xsl:apply-templates>
        </xsl:variable>
        
        <xsl:map>
            <xsl:map-entry key="'name'" select="local-name()"/>            
            <xsl:map-entry key="'handler-status'" select="$handler-status"/>            
            <xsl:map-entry key="'instance-context'" select="$this-instance-id"/>
            
            <xsl:if test="exists(@value)">
                <xsl:map-entry key="'@value'" select="string(@value)" />                          
            </xsl:if>
            <xsl:if test="empty(@value) and exists(./text())">
                <xsl:map-entry key="'value'" select="string(.)" />                         
            </xsl:if>
            
            <xsl:map-entry key="'@ref'" select="$refi"/>
            
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
            
            <xsl:if test="exists(@*:event)">
                <xsl:map-entry key="'@event'" select="string(@*:event)" />
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
                
                <xsl:variable name="origin-ref" as="xs:string" select="xforms:resolveXPathStrings($origin-context,@origin)"/>
                
                <xsl:map-entry key="'@origin'" select="$origin-ref" />    
            </xsl:if>
            
            <xsl:if test="exists(@context)">
                <xsl:map-entry key="'@context'" select="xforms:resolveXPathStrings($nodeset,@context)" />    
            </xsl:if>
            
            <!-- need to apply nested actions in order! -->            
            <xsl:if test="child::*">
                <xsl:map-entry key="'nested-actions'">
                    <xsl:variable name="array" as="map(*)*">
                        <xsl:for-each select="child::*">
                            <xsl:apply-templates select="." mode="#default">
                                <xsl:with-param name="handler-status" select="'inner'" tunnel="yes"/>
                            </xsl:apply-templates>
                        </xsl:for-each>
                    </xsl:variable>
                    <xsl:sequence select="array{$array}" />
                </xsl:map-entry>
            </xsl:if>
            
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
            <xd:p>Function to get 'if' statement from an action map</xd:p>
        </xd:desc>
        <xd:return>Value of map entry for @if (XPath expression)</xd:return>
        <xd:param name="map">Action map</xd:param>
    </xd:doc>
    <xsl:function name="xforms:getIfStatement" as="xs:string?">
        <xsl:param name="map" as="map(*)"/>
        <xsl:choose>
            <xsl:when test="map:contains($map, '@if')">
                <xsl:sequence select="map:get($map, '@if')"/>
            </xsl:when>
            <xsl:otherwise>
<!--                <xsl:sequence select="map:get($map, '@if')"/>-->
            </xsl:otherwise>
        </xsl:choose>
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
        <xsl:choose>
            <xsl:when test="map:contains($map, '@while')">
                <xsl:sequence select="map:get($map, '@while')"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:sequence select="map:get($map?*, '@while')"/>
            </xsl:otherwise>
        </xsl:choose>
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
                <xsl:when test="starts-with($relative,'/')">
                    <xsl:sequence select="$relative"/>
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
                    
                    <!-- MD 2020-04-11 REDUNDANT? if we're not comparing strings but nodes -->
                   <!-- <xsl:variable name="parentCallCount" select="if(contains($relative, '/')) then count(tokenize($relative, '/')[. ='..']) else if(contains($relative, '..')) then 1 else 0"/>
                    <xsl:variable name="slashes"
                        select="if(contains($base, '/')) then index-of(string-to-codepoints($base), string-to-codepoints('/')) else 0"
                        as="xs:integer*"/>
                    
                    <!-\-                <xsl:message use-when="$debugMode">resolveXPathString base =<xsl:value-of select="$base"/> 
                    relative <xsl:value-of select="$relative"/>
                    parentCallCount = <xsl:value-of select="$parentCallCount"/>
                    slashes = <xsl:value-of select="$slashes"/>
                </xsl:message>
-\->                
                    <xsl:variable name="parentSlash"
                        as="xs:integer">
                        <xsl:choose>
                            <xsl:when test="(count($slashes) >= $parentCallCount) and ($parentCallCount>0)">
                                <xsl:sequence select="$slashes[last() - ($parentCallCount - 1)]" />
                            </xsl:when>
                          <xsl:when test="(count($slashes) = ($parentCallCount - 1)) and ($parentCallCount>0)">
                                <!-\-OND Fix on Apr 2020:  Here we are at the context node -\->
                                <xsl:sequence select="0" />
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:sequence select="$slashes[last()]" />
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:variable>
                    
                    <!-\- <xsl:message use-when="$debugMode">[xforms:resolveXPathStrings] base =<xsl:value-of select="$base"/> 
                    lastSlash = <xsl:value-of select="$parentSlash"/> 
                    relative = <xsl:value-of select="$relative"/> 
                    countparent = <xsl:value-of select="$parentCallCount"/>
                    <xsl:if test="$parentCallCount > 0">
                        base without parent nodes = <xsl:value-of select="substring($base, 1, $parentSlash)" />
                        relativeCut = <xsl:value-of select="replace($relative, '\.\./', '')"/>
                    </xsl:if>
                    
                </xsl:message>-\->
                    
                    <xsl:choose>
                        <xsl:when test="$parentCallCount gt 0">

                          <!-\- TODO - need to resolve path. This does not work properly -\->  
                          <!-\- OND Apr 2020: This fix is an attempt to complex paths not resolving properly 
                              We now have the second when clause to handle going back up to the root and down
                              some other part of the tree. -\->
                            <xsl:sequence
                                select="concat(substring($base, 1, $parentSlash), replace($relative, '\.\./', ''))"
                            />
                        </xsl:when>
                        <xsl:when test="$parentCallCount eq 0">
                          <!-\- OND apr 2020: In addition to the above comment, this fix allows us to go back up the root 
                            and navigate soem other branch without giving some incorrect path. -\->
                            <xsl:sequence
                                select="replace($relative, '\.\./', '')"
                            />
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:sequence select="concat($base, '/', $relative)"/>
                        </xsl:otherwise>
                    </xsl:choose>-->
                    
                </xsl:otherwise>
            </xsl:choose>            
        </xsl:variable>
                
        <xsl:sequence select="$full-path"/>

    </xsl:function>



    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Check whether each required field is populated.</xd:p>
        </xd:desc>
        <xd:return>Sequence of each HTML field that is required</xd:return>
        <xd:param name="instanceXML">Instance to check</xd:param>
    </xd:doc>
    <xsl:function name="xforms:check-required-fields" as="item()*">
        <xsl:param name="instanceXML" as="element()"/>

        <xsl:variable name="required-fieldsi" select="ixsl:page()//*[@data-required]" as="item()*"/>

        <xsl:for-each select="$required-fieldsi">
            <xsl:variable name="resulti" as="xs:boolean">
                <xsl:evaluate
                    xpath="'child::node() or string-length() gt 0'"
                    context-item="." namespace-context="$instanceXML"/>

            </xsl:variable>
            <xsl:message use-when="$debugMode">[xforms:check-required-fields] Evaluating XPath: <xsl:sequence select="'child::node() or string-length() gt 0'"/></xsl:message>
            <xsl:message use-when="$debugMode">[xforms:check-required-fields] XPath result: <xsl:sequence select="$resulti"/></xsl:message>
            <xsl:sequence select="if (not($resulti)) then . else ()"/>
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
        
        <xsl:variable name="constraint-fieldsi" select="ixsl:page()//*[@data-constraint]" as="item()*"/>
        
        <xsl:for-each select="$constraint-fieldsi">
            <xsl:variable name="contexti" as="node()">
                <xsl:evaluate xpath="xforms:impose(@data-ref)" context-item="$instanceXML" namespace-context="$instanceXML"/>
            </xsl:variable>
            <xsl:message use-when="$debugMode">[xforms:check-constraints-on-fields] Evaluating XPath: <xsl:sequence select="serialize(@data-ref)"/></xsl:message>
            
            <xsl:variable name="resulti" as="xs:boolean">
                <xsl:evaluate xpath="xforms:impose(@data-constraint)" context-item="$contexti" namespace-context="$instanceXML"/>
            </xsl:variable>
            <xsl:sequence select="if (not($resulti)) then . else ()"/>
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
        <xsl:param name="targetref" as="xs:string?" required="no"/>
        <xsl:param name="replace" as="xs:string?" required="no"/>
        
        <xsl:variable name="refi" as="xs:string" select="concat('instance(''', $instance-id, ''')/')"/>
        
        <!-- 
            Type of response may vary, so using generic item() type
            
            '?' is the lookup operator: https://www.w3.org/TR/xpath-31/#id-lookup
            Here it acts on the context item, i.e. the HTTP response map
        -->
        <xsl:variable name="response" select="?body" as="item()?"/>  
         
        <xsl:choose>
              <xsl:when test="empty($response)">
                  <xsl:call-template name="serverError">
                      <xsl:with-param name="responseMap" select="."/>
                  </xsl:call-template>
              </xsl:when>


              <xsl:otherwise>
                  <!-- MD 2018: comment out replaceDocument for testing
                  The action here depends on the type of submission...
                  -->
<!--                  <xsl:sequence select="js:replaceDocument(serialize($responseXML))" />-->
                  
                  <xsl:choose>
                      <xsl:when test="$replace = 'instance' and $response[self::document-node()]">
                          <xsl:sequence select="js:setInstance($instance-id,$response/*)"/>
                          
                          <xsl:call-template name="xforms-submit-done"/>
                          
<!--                         <xsl:message use-when="$debugMode">[HTTPsubmit] response body: <xsl:value-of select="serialize($response)"/></xsl:message>-->
                      </xsl:when>
                      <!-- TO DO: replace node or text within instance; replace entire page -->
                      <xsl:otherwise/>
                  </xsl:choose>
                  
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
        <xsl:apply-templates select="node()"/>
    </xsl:template>

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Ignore xforms:model when rendering.</xd:p>
            <xd:p>Its instances, bindings, submissions are registered separately in the "xformsjs-main" template.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template match="xforms:model"/>

    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for XForms root element (xforms:xform).</xd:p>
            <xd:p>Passes XForm to xformsjs-main template</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template match="/">
        <xsl:call-template name="xformsjs-main" >
            <xsl:with-param name="xFormsId" select="$xform-html-id" />
        </xsl:call-template>
    </xsl:template>
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Identify context instance, nodeset, and bindings for <xd:a href="https://www.w3.org/TR/xforms11/#controls">XForm controls</xd:a>.</xd:p>
        </xd:desc>
        <xd:param name="position">Integer representing position of item (in a repeat list for example).</xd:param>
        <xd:param name="context-position">String representing position of item in a hierarchy (e.g. in nested repeat)</xd:param>
    </xd:doc>
    <xsl:template match="xforms:*[local-name() = $xforms-controls] | xforms:group ">
        <xsl:param name="position" as="xs:integer" required="no" select="0"/>
        <xsl:param name="context-position" as="xs:string" required="no" select="''"/>
        
<!--        <xsl:message>[<xsl:sequence select="name()"/>] START</xsl:message>-->
        
        <xsl:variable name="time-id" as="xs:string" select="concat('xforms-', local-name(), '-', generate-id())"/>
        <xsl:sequence use-when="$debugTiming" select="js:startTime($time-id)" />
        
        <xsl:variable name="string-position" as="xs:string" select="if ($context-position != '') then $context-position else string($position)"/>
        <xsl:variable name="myid" as="xs:string" select="
            if (exists(@id)) 
            then concat(@id, '-', $string-position)
            else concat( generate-id(), '-', $string-position )"/>
        
        <xsl:if test="xforms:usesIndexFunction(.) and not(ancestor::*[xforms:usesIndexFunction(.)])">
            <xsl:sequence select="js:setElementUsingIndexFunction($myid,.)"/>
        </xsl:if>
        
        
        <xsl:variable name="refi" as="xs:string">
            <xsl:apply-templates select="." mode="get-data-ref"/>
        </xsl:variable>
        
        <xsl:variable name="this-instance-id" as="xs:string">
            <xsl:apply-templates select="." mode="get-context-instance-id">
                <xsl:with-param name="nodeset" select="$refi"/>
            </xsl:apply-templates>
        </xsl:variable>
        
        <xsl:variable name="bindingi" as="element(xforms:bind)*">
            <xsl:apply-templates select="." mode="get-binding">
                <xsl:with-param name="instance-id" select="$this-instance-id" tunnel="yes"/>
                <xsl:with-param name="nodeset" select="$refi" tunnel="yes"/>
            </xsl:apply-templates>
        </xsl:variable>
        
        <!-- set actions relevant to this -->
        <xsl:variable name="time-id-set-sctions" as="xs:string" select="concat('xforms-', local-name(), '-actions-', generate-id())"/>
        <xsl:sequence use-when="$debugTiming" select="js:startTime($time-id-set-sctions)" />
        <xsl:variable name="actions" as="map(*)*">
            <xsl:apply-templates select="." mode="set-actions">
                <xsl:with-param name="instance-key" select="$this-instance-id" tunnel="yes"/>
                <xsl:with-param name="nodeset" select="$refi" tunnel="yes"/>
            </xsl:apply-templates>
        </xsl:variable>
        <xsl:sequence use-when="$debugTiming" select="js:endTime($time-id-set-sctions)" />
        
        <xsl:if test="exists($actions)">
            <xsl:sequence select="js:addAction($myid, $actions)" />
        </xsl:if>
        
        <xsl:apply-templates select="." mode="get-html">
            <xsl:with-param name="id" as="xs:string" select="$myid"/>
            <xsl:with-param name="nodeset" as="xs:string" select="$refi" tunnel="yes"/>
            <xsl:with-param name="instance-context" as="xs:string" select="$this-instance-id"/>
            <xsl:with-param name="binding" as="element(xforms:bind)*" select="$bindingi"/>
            <xsl:with-param name="actions" as="map(*)*" select="$actions"/>
        </xsl:apply-templates>
        
        <xsl:sequence use-when="$debugTiming" select="js:endTime($time-id)" />
    </xsl:template>
    

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of XForms <a href="https://www.w3.org/TR/xforms11/#ui-output">output element</a>  </xd:p>          
            <xd:p>Generates HTML output field and registers actions.</xd:p>
        </xd:desc>
        <xd:param name="id">ID of HTML element.</xd:param>
        <xd:param name="nodeset">XPath binding expression</xd:param>
        <xd:param name="instance-context">ID of XForms instance relevant to this control</xd:param>
        <xd:param name="binding">xforms:bind elements relevant to this control</xd:param>
    </xd:doc>
    <xsl:template match="xforms:output" mode="get-html">
        <xsl:param name="id" as="xs:string"/>
        <xsl:param name="nodeset" as="xs:string" tunnel="yes"/>
        <xsl:param name="instance-context" as="xs:string"/>
        <xsl:param name="binding" as="element(xforms:bind)*"/>
        
        <xsl:variable name="instanceField" as="node()?">
            <xsl:choose>
                <xsl:when test="$nodeset != ''">
                    <xsl:variable name="instanceXML" as="element()" select="js:getInstance($instance-context)"/>            
                    <xsl:evaluate xpath="xforms:impose($nodeset)" context-item="$instanceXML" namespace-context="$instanceXML"/>     
                </xsl:when>
                <xsl:when test="exists($binding)">
                    <xsl:sequence select="js:getInstance(xs:string($binding/@instance-context))"/>
                </xsl:when>
                <xsl:otherwise/>
            </xsl:choose>
        </xsl:variable>
        
        
        <xsl:variable name="namespace-context-item" as="node()" select="
            if (exists($instanceField))
            then (
                if ($instanceField[self::text()])
                then $instanceField/parent::*
                else $instanceField
            )
            else xforms:addNamespaceDeclarations(/*)"/>
             
        <xsl:variable name="valueExecuted" as="xs:string">
            <xsl:choose>
                <xsl:when test="exists(@value)">
                   <xsl:evaluate xpath="xforms:impose(@value)" context-item="$instanceField" namespace-context="$namespace-context-item" as="xs:string" /> 
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="$instanceField"/>
                </xsl:otherwise>
            </xsl:choose>
            
        </xsl:variable>
        
        <xsl:variable name="relevantVar" as="xs:boolean">
            <xsl:choose>
                <xsl:when test="exists($binding) and exists($binding/@relevant)">
                    <xsl:evaluate xpath="xforms:impose($binding/@relevant)" context-item="$instanceField" namespace-context="$namespace-context-item"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="true()"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        


        <!-- GENERATE HTML -->
        <div>
            <xsl:sequence select="xforms:getClass(.)"/>
            
            <xsl:apply-templates select="xforms:label"/>
            
            <span>
                <xsl:attribute name="id" select="$id"/>
                <xsl:attribute name="style" select="if($relevantVar) then 'display:inline' else 'display:none'" />
                <xsl:attribute name="instance-context" select="$instance-context"/>
                <xsl:attribute name="data-ref" select="$nodeset"/>
                
                <xsl:if test="exists($binding) and exists($binding/@relevant)">
                    <xsl:attribute name="data-relevant" select="$binding/@relevant"/>
                </xsl:if>
                
                
                <xsl:sequence select="$valueExecuted" />
            </span>
        </div>
        
        <!-- register outputs (except those inside a repeat) -->
        <xsl:if test="not(ancestor::xforms:repeat)">
            <xsl:variable name="output-map" as="map(*)">
                <xsl:map>
                    <xsl:map-entry key="'@instance-context'" select="$instance-context"/>
                    
                    <xsl:if test="$nodeset != ''">
                        <xsl:map-entry key="'@ref'" select="xs:string($nodeset)" />
                    </xsl:if>
                    
                    <xsl:if test="exists(@value)">
                        <xsl:map-entry key="'@value'" select="xs:string(@value)" />
                    </xsl:if>
                </xsl:map>
            </xsl:variable>
            
            <!--<xsl:sequence select="sfp:logInfo(
            concat('[xforms:output] Registering output with ID ', $myid)
            )"/>-->
            <!--<xsl:message use-when="$debugMode">
                <xsl:sequence select="concat('[xforms:output] Registering output with ID ', $myid)"/>
            </xsl:message>-->
            <xsl:sequence select="js:addOutput($id , $output-map)" />
        </xsl:if>
 
        
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
        <xsl:param name="id" as="xs:string"/>
        <xsl:param name="nodeset" as="xs:string" tunnel="yes"/>
        <xsl:param name="instance-context" as="xs:string"/>
        <xsl:param name="binding" as="element(xforms:bind)*"/>
        <xsl:param name="actions" as="map(*)*"/>
        
        <xsl:variable name="instanceField" as="node()?">
            <xsl:if test="$nodeset != ''">
                <xsl:variable name="instanceXML" as="element()" select="js:getInstance($instance-context)"/>            
                <xsl:evaluate xpath="xforms:impose($nodeset)" context-item="$instanceXML" namespace-context="$instanceXML"/>                
            </xsl:if>
        </xsl:variable>
                            
        <xsl:variable name="namespace-context-item" as="node()" select="
            if (exists($instanceField))
            then $instanceField
            else xforms:addNamespaceDeclarations(/*)"/>
               
               
        <!-- check whether this input is relevant -->
        <xsl:variable name="relevantVar" as="xs:boolean">
            <xsl:choose>
                <xsl:when test="exists($binding) and exists($binding/@relevant) and exists($instanceField)">
                    <!-- TO DO: could be more than one binding element with @relevant (should be an error) -->
                    <xsl:evaluate xpath="xforms:impose($binding/@relevant)" context-item="$instanceField" namespace-context="$namespace-context-item"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="true()"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
             
        <div class="xforms-input">
            <xsl:attribute name="style" select="if($relevantVar) then 'display:block' else 'display:none'" />
            
            <xsl:apply-templates select="xforms:label"/>
            
            <xsl:variable name="hints" select="xforms:hint/text()"/>
            
            <input>
                <xsl:sequence select="xforms:getClass(.)"/>
                <xsl:attribute name="id" select="$id"/>
                
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
                
                <xsl:if test="exists($actions)">
                    <xsl:attribute name="data-action" select="$id"/>
                </xsl:if>
                
                <xsl:if test="exists($hints)">
                    <xsl:attribute name="title" select="$hints"/>
                </xsl:if>
                
                <xsl:if test="exists(@size)">
                    <xsl:attribute name="size" select="@size"/>
                </xsl:if>
                                
                <xsl:variable name="input-value" as="xs:string">
                    <xsl:choose>
                        <xsl:when test="exists($instanceField)">
                            <xsl:value-of select="$instanceField"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="''"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                
                <xsl:choose>
                    <xsl:when
                        test="
                        if (exists($binding)) then
                        xs:QName($binding/@type) eq xs:QName('xs:date')
                        else
                        false()">
                        <xsl:attribute name="data-type" select="'date'"/>
                        <!--<xsl:if test="$relevantVar">-->
                        <xsl:attribute name="type" select="'date'"/>
                        <!--</xsl:if>-->
                        <xsl:attribute name="value" select="$input-value"/>
                    </xsl:when>
                    <xsl:when
                        test="
                        if (exists($binding)) then
                        xs:QName($binding/@type) eq xs:QName('xs:time')
                        else
                        false()">
                        <xsl:attribute name="data-type" select="'time'"/>
                        <!--<xsl:if test="$relevantVar">-->
                        <xsl:attribute name="type" select="'time'"/>
                        <!--</xsl:if>-->
                        
                        <xsl:attribute name="value" select="$input-value"/>
                    </xsl:when>
                    <xsl:when
                        test="
                        if (exists($binding)) then
                        xs:QName($binding/@type) eq xs:QName('xs:boolean')
                        else
                        false()">
                        <xsl:attribute name="data-type" select="'checkbox'"/>
                        <!--<xsl:if test="$relevantVar">-->
                        <xsl:attribute name="type" select="'checkbox'"/>
                        <!--</xsl:if>-->
                                               
                        <xsl:if test="exists($instanceField)">
                            <xsl:if test="string-length($input-value) > 0 and xs:boolean($input-value)">
                                <xsl:attribute name="checked" select="$input-value"/>
                            </xsl:if>
                        </xsl:if>
                    </xsl:when>
                    
                    <xsl:otherwise>
                        <xsl:if test="$relevantVar">
                            <xsl:attribute name="type" select="'text'"/>
                        </xsl:if>
                        <xsl:attribute name="value" select="$input-value"/>
                    </xsl:otherwise>
                </xsl:choose>
                
            </input>
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
        <xsl:param name="id" as="xs:string"/>
        <xsl:param name="nodeset" as="xs:string" tunnel="yes"/>
        <xsl:param name="instance-context" as="xs:string"/>
        <xsl:param name="binding" as="element(xforms:bind)*"/>
        <xsl:param name="actions" as="map(*)*"/>

        <xsl:variable name="instanceField" as="node()?">
            <xsl:if test="$nodeset != ''">
                <xsl:variable name="instanceXML" as="element()" select="js:getInstance($instance-context)"/>            
                <xsl:evaluate xpath="xforms:impose($nodeset)" context-item="$instanceXML" namespace-context="$instanceXML"/>                
            </xsl:if>
        </xsl:variable>
        
        <xsl:variable name="hints" select="xforms:hint/text()"/>
        
        <div class="xforms-textarea">
            <xsl:apply-templates select="xforms:label"/>
            <textarea>
                <xsl:sequence select="xforms:getClass(.)"/>
                <xsl:attribute name="id" select="$id"/>
                
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
                
                <xsl:if test="exists($actions)">
                    <xsl:attribute name="data-action" select="$id"/>
                </xsl:if>
                
                <xsl:if test="exists($hints)">
                    <xsl:attribute name="title" select="$hints"/>
                </xsl:if>
                
                <xsl:if test="exists(@size)">
                    <xsl:attribute name="size" select="@size"/>
                </xsl:if>
                
                <xsl:choose>
                    <xsl:when test="exists($instanceField)">
                        <xsl:value-of select="$instanceField"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:text/>&#xA0; </xsl:otherwise>
                </xsl:choose>
            </textarea>       
        </div>
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
        <xsl:param name="id" as="xs:string"/>
        <xsl:param name="nodeset" as="xs:string" tunnel="yes"/>
        <xsl:param name="instance-context" as="xs:string"/>
        <xsl:param name="binding" as="element(xforms:bind)*"/>
        <xsl:param name="actions" as="map(*)*"/>
        
        <xsl:variable name="instanceField" as="node()?">
            <xsl:if test="$nodeset != ''">
                <xsl:variable name="instanceXML" as="element()" select="js:getInstance($instance-context)"/>            
                <xsl:evaluate xpath="xforms:impose($nodeset)" context-item="$instanceXML" namespace-context="$instanceXML"/>                
            </xsl:if>
        </xsl:variable>                
        
        <xsl:variable name="selectedValue" as="xs:string">
            <xsl:choose>
                <xsl:when test="exists($instanceField)">
                    <xsl:value-of select="$instanceField"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="''"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
                         
        <div class="xforms-select">
            <xsl:apply-templates select="xforms:label"/>
            <xsl:variable name="hints" select="xforms:hint/text()"/>
            
            <select>
                <xsl:sequence select="xforms:getClass(.)"/>
                
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
                
                <xsl:if test="exists($actions)">
                    <xsl:attribute name="data-action" select="$id"/>
                </xsl:if>
                
                <xsl:if test="exists($hints)">
                    <xsl:attribute name="title" select="$hints"/>
                </xsl:if>
                
                
                <xsl:if test="local-name() = 'select'">
                    <xsl:attribute name="multiple">true</xsl:attribute>
                    <xsl:attribute name="size">
                        <xsl:value-of select="count(descendant::xforms:item)"/>
                    </xsl:attribute>
                </xsl:if>
                 
                <xsl:apply-templates select="xforms:item">
                    <xsl:with-param name="selectedValue" select="$selectedValue"/>
                </xsl:apply-templates>
                
            </select>
            
        </div>
        
        
        <xsl:sequence use-when="$debugTiming" select="js:endTime(concat('XForms-select', $time-id))" />

    </xsl:template>


    <xd:doc scope="component">
        <xd:desc>Identity template, e.g. for passing through HTML elements within the XForm.</xd:desc>
    </xd:doc>
    <xsl:template match="(node() | @*)">
        <xsl:copy>
            <xsl:apply-templates select="@*,node()"/>
        </xsl:copy>
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
        <label>
            <xsl:copy-of select="@class"/>
            <xsl:choose>
                <xsl:when test="count(./node()) &gt; 0">
                    <xsl:apply-templates select="node()"/>
                </xsl:when>
                <xsl:otherwise><xsl:text>&#xA0;</xsl:text></xsl:otherwise>
            </xsl:choose>
        </label>
    </xsl:template>

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for xforms:item element.</xd:p>
            <xd:p>Generates HTML option element.</xd:p>
        </xd:desc>
        <xd:param name="selectedValue">String consisting of the current selection in the list. (If it matches the value of the xforms:item, the HTML option will be marked as selected.)</xd:param>
    </xd:doc>
    <xsl:template match="xforms:item">
        <xsl:param name="selectedValue" as="xs:string" select="''"/>
        
        <option value="{xforms:value}">
            <xsl:if test="$selectedValue = xs:string(xforms:value/text())">
                <xsl:attribute name="selected" select="$selectedValue"/>
            </xsl:if>

            <xsl:value-of select="xforms:label"/>
        </option>

    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of XForms <a href="https://www.w3.org/TR/xforms11/#ui-group">group element</a></xd:p>
            <xd:p>Generates an HTML div and passes @ref or @nodeset to descendants.</xd:p>
        </xd:desc>
        <xd:param name="id">ID of HTML element.</xd:param>
        <xd:param name="nodeset">XPath binding expression</xd:param>
    </xd:doc>
    <xsl:template match="xforms:group" mode="get-html">
        <xsl:param name="id" as="xs:string" required="yes"/>
        <xsl:param name="nodeset" as="xs:string" required="yes" tunnel="yes"/>
        
        <div>
            <xsl:attribute name="id" select="$id"/>
            <xsl:if test="$nodeset != ''">
                <xsl:attribute name="data-group-ref" select="$nodeset" />
            </xsl:if>
            <xsl:apply-templates select="child::*"/>
        </div>
    </xsl:template>
    
    

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of XForms <a href="https://www.w3.org/TR/xforms11/#ui-repeat">repeat element</a></xd:p>
            <xd:p>Generates HTML div and iterates over items within.</xd:p>
        </xd:desc>
        <xd:param name="nodeset">An XPath binding expression. Stored in Javascript variable to support recalculation of repeats.</xd:param>
        <xd:param name="position">Integer representing position of item (in a repeat list for example).</xd:param>
        <xd:param name="context-position">String representing position of item in a hierarchy (e.g. in nested repeat)</xd:param>
        <xd:param name="recalculate">Boolean parameter. A true value means we are recalculating and do not output the top-level div</xd:param>
        <xd:param name="refreshRepeats">Boolean parameter. A true value means we are calling it from the refreshRepeats-JS template - we are replacing the content of the div wrapper and don't need to recreate it (otherwise there will be duplicate IDs)</xd:param>
    </xd:doc>
    <xsl:template match="xforms:repeat">
        <xsl:param name="nodeset" as="xs:string" required="no" select="''" tunnel="yes"/>
        <xsl:param name="position" as="xs:integer" required="no" select="0"/>
        <xsl:param name="context-position" as="xs:string" required="no" select="''"/>
        <xsl:param name="recalculate" as="xs:boolean" required="no" select="fn:false()" tunnel="yes"/>
        <xsl:param name="refreshRepeats" as="xs:boolean" required="no" select="fn:false()" tunnel="yes"/>
        
<!--        <xsl:message>[xforms:repeat] Handling: <xsl:sequence select="fn:serialize(.)"/></xsl:message>-->
        
        <xsl:variable name="string-position" as="xs:string" select="if ($context-position != '') then $context-position else string($position)"/>
        <xsl:variable name="myid" as="xs:string" select="
            if (exists(@id)) 
            then @id
            else concat( generate-id(), '-', $string-position )"/>
                
        <xsl:variable name="refi" as="xs:string">
            <xsl:apply-templates select="." mode="get-data-ref"/>
        </xsl:variable>
        
        <xsl:variable name="this-instance-id" as="xs:string">
            <xsl:apply-templates select="." mode="get-context-instance-id">
                <xsl:with-param name="nodeset" select="$refi"/>
            </xsl:apply-templates>
        </xsl:variable>

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
                            <!--<xsl:message>[xforms:repeat] value of @startindex ('<xsl:value-of select="@startindex"/>') is not a number. Setting the index to '1'</xsl:message>-->
                            <xsl:value-of select="1"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
<!--                <xsl:message>[xforms:repeat] Setting index of <xsl:sequence select="$myid"/> to '<xsl:sequence select="$this-index"/>'</xsl:message>-->
                <xsl:sequence select="js:setRepeatIndex($myid, $this-index)"/>
                
            </xsl:otherwise>
        </xsl:choose>
        

        <!-- identify instance fields corresponding to this -->
        <xsl:variable name="selectedRepeatVar" as="element()*">
            <xsl:sequence use-when="$debugTiming" select="js:startTime(concat('XForms-repeat-evaluate', $time-id))" />
            <xsl:variable name="instanceXML" as="element()" select="js:getInstance($this-instance-id)"/>            
            <xsl:evaluate xpath="xforms:impose($refi)" context-item="$instanceXML" namespace-context="$instanceXML"/>
            <xsl:sequence use-when="$debugTiming" select="js:endTime(concat('XForms-repeat-evaluate', $time-id))" />
        </xsl:variable>
        
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
            <xsl:for-each select="$selectedRepeatVar">
                <xsl:variable name="string-position" as="xs:string" select="string(position())"/>
                <xsl:variable name="new-context-position" as="xs:string" select="if ($context-position != '') then concat($context-position, '.', $string-position) else $string-position"/>
                <div data-repeat-item="true">
                    <xsl:apply-templates select="$this/child::*">
                        <xsl:with-param name="nodeset" select="concat($refi, '[', position(), ']')" tunnel="yes"/>
                        <xsl:with-param name="position" select="position()"/>
                        <xsl:with-param name="context-position" select="$new-context-position"/>
                    </xsl:apply-templates>
                </div>
            </xsl:for-each>
        </xsl:variable>
           
        <!-- Write HTML -->   
        <xsl:choose>
            <xsl:when test="$refreshRepeats">
                <xsl:sequence select="$repeat-items"/>
            </xsl:when>
            <xsl:otherwise>
                <div>
                    <xsl:sequence select="xforms:getClass(.)"/>
                    
                    <xsl:attribute name="data-repeatable-context" select="$refi" />
                    <xsl:attribute name="data-count" select="count($selectedRepeatVar)" />
                    <xsl:attribute name="id" select="$myid"/>
                    
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
        <xd:param name="node-to-insert">Node to be inserted</xd:param>
        <xd:param name="position-relative">"before" or "after"</xd:param>
    </xd:doc>
    <xsl:template match="*" mode="insert-node">
        <xsl:param name="insert-node-location" as="node()" tunnel="yes"/>
        <xsl:param name="node-to-insert" as="node()" tunnel="yes"/>
        <xsl:param name="position-relative" as="xs:string?" select="'after'" required="no" tunnel="yes"/>
        
        
        <xsl:if test=". is $insert-node-location and $position-relative = 'before'">
<!--            <xsl:message>[insert-node mode] Found! <xsl:value-of select="serialize($insert-node-location)"/></xsl:message>-->
            <xsl:copy-of select="$node-to-insert"/>
        </xsl:if>
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <!-- 
            From XForms 1.1 spec:
            If the Node Set Binding node-set is not specified or empty, then the insert location node provided by the context attribute is intended to be the parent of the cloned node.
            -->
            <xsl:if test=". is $insert-node-location and $position-relative = 'child'">
                <xsl:copy-of select="$node-to-insert"/>
            </xsl:if>
            <xsl:apply-templates select="node()" mode="insert-node"/>
        </xsl:copy>
        <xsl:if test=". is $insert-node-location and $position-relative = 'after'">
            <xsl:copy-of select="$node-to-insert"/>
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

            </xsl:when>
            <xsl:otherwise>
                <xsl:copy>
                    <xsl:copy-of select="@*"/>
                    <xsl:apply-templates select="node()" mode="delete-node"/>
                </xsl:copy>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
 
    <xd:doc scope="component">
        <xd:desc>Handle HTML button click</xd:desc>
    </xd:doc>
    <xsl:template match="*:button[exists(@data-action)]" mode="ixsl:onclick">       
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
        <xsl:param name="id" as="xs:string"/>
        <xsl:param name="nodeset" as="xs:string" tunnel="yes"/>

        <xsl:variable name="innerbody">
            <xsl:choose>
                <xsl:when test="child::xforms:label">
                    <xsl:apply-templates select="xforms:label"/>
                </xsl:when>
                <xsl:otherwise>&#xA0;</xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <span style="display:'inline'">
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
                
                <xsl:attribute name="data-ref" select="$nodeset"/>
                <xsl:attribute name="data-action" select="$id"/>
                <xsl:copy-of select="$innerbody"/>               
            </xsl:element>
        </span>        
    </xsl:template>

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for XForms Action elements (xforms:action, xforms:setvalue, etc.)</xd:p>
            <xd:p>Generates map of this and descendant actions.</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template match="xforms:*[local-name() = $xforms-actions] | xforms:action | xforms:show | xforms:hide | xforms:script | xforms:unload">
        <xsl:variable name="myid" as="xs:string" select="if (exists(@id)) then @id else generate-id()"/>
        
        <xsl:variable name="time-id" select="generate-id()"/>
        <xsl:sequence use-when="$debugTiming" select="js:startTime(concat('XForms-action', $time-id))" />        
        
        
  
        <xsl:variable name="action-map" as="map(*)">
            <xsl:apply-templates select="." mode="set-action"/>
        </xsl:variable>
        
        <!--<xsl:message use-when="$debugMode">
            [XForms Action] found action!
            node       = <xsl:value-of select="serialize(.)"/>, 
            id         = <xsl:value-of select="@id"/>,
            myid       = <xsl:value-of select="$myid"/>, 
            action map = <xsl:value-of select="serialize($action-map)"/>
        </xsl:message>-->

        <xsl:if test="exists($action-map)">
            <xsl:sequence select="$action-map" />
        </xsl:if>

        <xsl:sequence use-when="$debugTiming" select="js:endTime(concat('XForms-action', $time-id))" />
    </xsl:template>
    

   
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for updating element within instance XML based on new value in binding calculation (xforms:bind/@calculate)</xd:p>
        </xd:desc>
        <xd:param name="updated-nodes">Nodes within instance that are affected by binding calculations</xd:param>
        <xd:param name="updated-values">Values of those nodes</xd:param>
    </xd:doc>

    <xsl:template match="*" mode="recalculate">
        <xsl:param name="updated-nodes" as="node()*" tunnel="yes"/>
        <xsl:param name="updated-values" as="xs:string*" tunnel="yes"/>
        
        <xsl:variable name="updated-node" as="element()?" select="$updated-nodes[. is fn:current()]"/>
        
<!--        <xsl:message use-when="$debugMode">[recalculate mode] comparing instance node <xsl:sequence select="fn:serialize(.)"/> with updated node <xsl:sequence select="fn:serialize($updated-nodes)"/></xsl:message> -->
        <xsl:copy>
            <xsl:apply-templates select="@*" mode="recalculate"/>
            
            <xsl:choose>
                <xsl:when test="exists($updated-node)">
                    <xsl:variable name="updated-node-position" as="xs:integer" select="$updated-nodes[. is fn:current()]/position()"/>
<!--                    <xsl:message use-when="$debugMode">[recalculate mode] setting new value <xsl:sequence select="$updated-values[$updated-node-position]"/></xsl:message>-->
                    <xsl:sequence select="$updated-values[$updated-node-position]"/>
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
        <xd:param name="updated-values">Values of those nodes</xd:param>
    </xd:doc>
    <xsl:template match="@*" mode="recalculate">
        <xsl:param name="updated-nodes" as="node()*" tunnel="yes"/>
        <xsl:param name="updated-values" as="xs:string*" tunnel="yes"/>
        
        <xsl:variable name="updated-node" as="attribute()?" select="$updated-nodes[. is fn:current()]"/>
        
        <xsl:choose>
            <xsl:when test="exists($updated-node)">
                <xsl:variable name="updated-node-position" as="xs:integer" select="$updated-nodes[. is fn:current()]/position()"/>
                <xsl:attribute name="{name(.)}" select="$updated-values[$updated-node-position]"/>
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
            <xsl:namespace name="xforms" select="'http://www.w3.org/2002/xforms'"/>
            
            <xsl:apply-templates select="@*,node()" mode="namespace-fix"/>
        </xsl:element>
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

        <xsl:sequence select="ixsl:get(./option[ixsl:get(., 'selected') = true()], 'value')"/>
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

        <xsl:for-each select="./option[@value = $value]">
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
        <!-- select="ixsl:get(ixsl:page()//*[@id=$updatedPath],'value')" -->
        
        <!-- TO DO: (MD 2020-03-14) I don't think this is correct -->
        <xsl:sequence select="ixsl:get(., 'value')"/>
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
        <xd:param name="this">Element for which namespaces are needed</xd:param>
    </xd:doc>
    <xsl:function name="xforms:addNamespaceDeclarations" as="element()">
        <xsl:param name="this" as="element()"/>
        <xsl:element name="{name($this)}">
            <xsl:namespace name="xforms" select="'http://www.w3.org/2002/xforms'"/>
            <xsl:for-each select="$this//*[namespace-uri() != ''][not(namespace-uri() = (ancestor::*/namespace-uri(),preceding::*/namespace-uri()))]">
                <xsl:variable name="new-namespace" select="namespace-uri(.)"/>
                <xsl:variable name="new-prefix" select="substring-before(name(),':')"/>
                <xsl:namespace name="{$new-prefix}" select="$new-namespace"/>
            </xsl:for-each>
            <xsl:copy-of select="$this/@*,$this/node()"/>
        </xsl:element>
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
        <xd:desc>Take @class attribute and append "incremental" if the XForms control has @incremental.</xd:desc>
        <xd:return>HTML @class attribute</xd:return>
        <xd:param name="element">XForms element which may have a class in its HTML representation</xd:param>
    </xd:doc>
    <xsl:function name="xforms:getClass" as="attribute(class)?">
        <xsl:param name="element" as="element()"/>
        
        <xsl:variable name="class" as="xs:string?">
            <xsl:if test="exists($element/@class)">
                <xsl:value-of select="$element/@class"/>
            </xsl:if>
        </xsl:variable>
        <xsl:variable name="class-mod" as="xs:string?">
            <xsl:choose>
                <xsl:when test="exists($element/@incremental)">
                    <xsl:value-of select="string-join(($class,'incremental'), ' ' )"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="$class"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:if test="exists($class-mod)">
            <xsl:attribute name="class" select="$class-mod"/>
        </xsl:if>
    </xsl:function>

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>From an XPath binding expression, return the ID of the referenced instance.</xd:p>
            <xd:p>If the expression starts instance('xxxx') the value is 'xxxx'.</xd:p>
            <xd:p>Otherwise, the value is ther $default-instance-id</xd:p>
        </xd:desc>
        <xd:param name="nodeset">XPath binding expression</xd:param>
    </xd:doc>
    <xsl:function name="xforms:getInstanceId" as="xs:string">
        <xsl:param name="nodeset" as="xs:string"/>
        
        <xsl:choose>
            <xsl:when test="$nodeset = ''">
                <xsl:sequence select="$global-default-instance-id"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:analyze-string select="normalize-space($nodeset)"
                    regex="^instance\s*\(\s*&apos;([^&apos;]+)&apos;\s*\)\s*(/\s*(.*)|)$"
                    >
                    <xsl:matching-substring>
                        <xsl:sequence select="regex-group(1)"/>
                    </xsl:matching-substring>
                    <xsl:non-matching-substring>
                        <xsl:sequence select="$global-default-instance-id"/>
                    </xsl:non-matching-substring>
                </xsl:analyze-string>
            </xsl:otherwise>
        </xsl:choose>
       
    </xsl:function>
    

    <xd:doc scope="component">
        <xd:desc>Update HTML display elements corresponding to xforms:output elements</xd:desc>
    </xd:doc>
    <xsl:template name="refreshOutputs-JS">
        <xsl:message use-when="$debugMode">[refreshOutputs-JS] START</xsl:message>
        
        <!-- get all registered outputs -->
        <!-- MD 2018-06-30 : want to use as="xs:string*" but get a cardinality error!? 
        JS data typing thing?
        -->
        <xsl:variable name="output-keys" select="js:getOutputKeys()" as="item()*"/>
        
        <xsl:for-each select="$output-keys">
            <xsl:variable name="this-key" as="xs:string" select="."/>
            <xsl:variable name="this-output" as="map(*)" select="js:getOutput($this-key)"/>
            
<!--            <xsl:message use-when="$debugMode">[refreshOutputs-JS] Refreshing output ID = '<xsl:sequence select="$this-key"/>'</xsl:message>-->
            
            
            <xsl:variable name="xpath" as="xs:string">
                <xsl:choose>
                    <xsl:when test="map:get($this-output,'@value')">
                        <xsl:sequence select="map:get($this-output,'@value')"/>
                    </xsl:when>
                    <xsl:when test="map:get($this-output,'@ref')">
                        <xsl:sequence select="map:get($this-output,'@ref')"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:sequence select="''"/>
                        <!-- TO DO: error condition -->
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:variable>
            <xsl:variable name="xpath-mod" as="xs:string" select="xforms:impose($xpath)"/>
            
<!--            <xsl:message use-when="$debugMode">[refreshOutputs-JS] $xpath-mod = '<xsl:sequence select="$xpath-mod"/>'</xsl:message>-->
                                    
            <xsl:variable name="this-instance-id" as="xs:string" select="map:get($this-output,'@instance-context')"/>
                        
            <xsl:variable name="contexti" as="element()?">
                <xsl:sequence select="xforms:instance($this-instance-id)"/>
            </xsl:variable>
            
            <xsl:variable name="namespace-context-item" as="element()" select="
                if (exists($contexti))
                then $contexti
                else js:getXForm()
                "/>
            
            <xsl:variable name="value" as="xs:string?">
                <xsl:evaluate xpath="$xpath-mod" context-item="$contexti" namespace-context="$namespace-context-item"/>
            </xsl:variable>
                        
            <xsl:variable name="associated-form-control" select="ixsl:page()//*[@id = $this-key]" as="node()?"/>
                        
            <xsl:choose>
                <xsl:when test="exists($associated-form-control)">
                    <xsl:result-document href="#{$this-key}" method="ixsl:replace-content">
                        <xsl:value-of select="$value"/>
                    </xsl:result-document>
                </xsl:when>
                <xsl:otherwise/>
            </xsl:choose>
        </xsl:for-each>
        
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>Update HTML display elements corresponding to xforms:repeat elements</xd:desc>
    </xd:doc>
    <xsl:template name="refreshRepeats-JS">               
        <xsl:message use-when="$debugMode">[refreshRepeats-JS] START</xsl:message>
              
        <xsl:variable name="repeat-keys" select="js:getRepeatKeys()" as="item()*"/>
        
        <xsl:for-each select="$repeat-keys">
            <xsl:variable name="this-key" as="xs:string" select="."/>
            <xsl:variable name="this-repeat" as="element()" select="js:getRepeat($this-key)"/>
            <xsl:variable name="this-repeat-nodeset" as="xs:string" select="js:getRepeatContext($this-key)"/>
            
                        
            <xsl:variable name="page-element" select="ixsl:page()//*[@id = $this-key]" as="node()?"/>
            
            <xsl:choose>
                <xsl:when test="exists($page-element)">
                    <xsl:result-document href="#{$this-key}" method="ixsl:replace-content">
                        <xsl:apply-templates select="$this-repeat">
                            <xsl:with-param name="nodeset" select="$this-repeat-nodeset" tunnel="yes"/>
                            <xsl:with-param name="recalculate" select="true()" tunnel="yes"/>
                            <xsl:with-param name="refreshRepeats" select="fn:true()" tunnel="yes"/>
                        </xsl:apply-templates>
                    </xsl:result-document>
                </xsl:when>
                <xsl:otherwise/>
            </xsl:choose>
        </xsl:for-each>
        
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
            <xsl:variable name="instanceXML" select="js:getInstance(string(@instance-context))" as="element()"/>
            <xsl:variable name="context-node" as="node()?">
                <xsl:evaluate xpath="string(xforms:impose(@data-ref))" context-item="$instanceXML" namespace-context="$instanceXML"/>
            </xsl:variable>
            <xsl:variable name="relevantCheck" as="xs:boolean">
                <xsl:evaluate xpath="string(xforms:impose(@data-relevant))" context-item="$context-node" namespace-context="$instanceXML"/>
            </xsl:variable>
            <xsl:choose>
                <!-- display property on parent ...? -->
                <xsl:when test="$relevantCheck">
                    <ixsl:set-property name="style.display" select="'inline'" object="."/>
                </xsl:when>
                <xsl:otherwise>
                    <ixsl:set-property name="style.display" select="'none'" object="."/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
        
     </xsl:template>
    
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Update HTML display elements corresponding to XForms elements that use the index() function</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template name="refreshElementsUsingIndexFunction-JS">
        <xsl:message use-when="$debugMode">[refreshElementsUsingIndexFunction-JS] START</xsl:message>
        
        <xsl:variable name="ElementsUsingIndexFunction-keys" select="js:getElementsUsingIndexFunctionKeys()" as="item()*"/>        
                
        <xsl:for-each select="$ElementsUsingIndexFunction-keys">
            <xsl:variable name="this-key" as="xs:string" select="."/>
            
            <xsl:message use-when="$debugMode">[refreshElementsUsingIndexFunction-JS] Refreshing item with key '<xsl:sequence select="$this-key"/>'</xsl:message>
            
            <xsl:variable name="this-element" as="element()" select="js:getElementUsingIndexFunction($this-key)"/>
            
            <xsl:variable name="this-element-refi" as="xs:string">
                <xsl:apply-templates select="$this-element" mode="get-data-ref"/>
            </xsl:variable>
            
            <xsl:result-document href="#{$this-key}" method="ixsl:replace-content">
                <xsl:apply-templates select="$this-element/*">
                    <xsl:with-param name="nodeset" select="$this-element-refi" tunnel="yes"/>
                    <xsl:with-param name="recalculate" select="true()" tunnel="yes"/>
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
        
        <xsl:variable name="instance-context" select="map:get($action-map, 'instance-context')" as="xs:string"/>
        <xsl:variable name="handler-status" select="map:get($action-map, 'handler-status')" as="xs:string"/>
        <xsl:variable name="ref" select="map:get($action-map, '@ref')" as="xs:string?"/>
        <xsl:variable name="at" select="map:get($action-map, '@at')" as="xs:string?"/>
        <xsl:variable name="position" select="map:get($action-map, '@position')" as="xs:string?"/>
        <xsl:variable name="context" select="map:get($action-map, '@context')" as="xs:string?"/>
        
        
        <xsl:variable name="ref-qualified" as="xs:string?" select="
            if (exists($ref) and $ref != '')
            then (
                if (exists($at))
                then concat($ref, '[', $at, ']')
                else $ref
            )
            else ()
            "/>
        
        <xsl:variable name="instanceXML2" as="element()?" select="js:getInstance($instance-context)"/>
        
<!--        <xsl:message use-when="$debugMode">[applyActions] evaluating action = <xsl:value-of select="serialize($action-map)"/></xsl:message>-->
        
        <xsl:variable name="ref-node" as="node()*">
            <xsl:choose>
                <xsl:when test="exists($ref-qualified) and not($ref-qualified = '') and exists($instanceXML2)">
                    <xsl:evaluate xpath="xforms:impose($ref-qualified)" context-item="$instanceXML2" namespace-context="$instanceXML2"/>
                </xsl:when>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:variable name="context-node" as="node()?">
            <xsl:choose>
                <xsl:when test="exists($context) and not($context = '') and exists($instanceXML2)">
                    <xsl:evaluate xpath="xforms:impose($context)" context-item="$instanceXML2" namespace-context="$instanceXML2"/>                    
                </xsl:when>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:variable name="context" as="node()?" select="($context-node,$ref-node,$instanceXML2)[1]"/>
        
         
        
        <!-- TODO error testing of incorrect ref given in the xform (i.e. context would be empty in this case) -->

        <xsl:variable name="ifVar" select="xforms:getIfStatement($action-map)"/>      
        <xsl:variable name="whileVar" select="xforms:getWhileStatement($action-map)"/>
        
        <!-- TODO if the action does not contain an if or while it should execute action -->
        <xsl:variable name="ifExecuted" as="xs:boolean">
            <xsl:choose>
                <xsl:when test="exists($ifVar) and exists($context)">
                    <xsl:evaluate xpath="xforms:impose($ifVar)" context-item="$context" namespace-context="$instanceXML2"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="true()" />
                </xsl:otherwise>
            </xsl:choose>                    
        </xsl:variable>
        
        
        <!-- https://www.w3.org/TR/xforms11/#action -->
        <xsl:if test="$ifExecuted">
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
                <!--<xsl:when test="$action-name = 'toggle'">
                    <xsl:call-template name="action-toggle"/>
                </xsl:when>-->
                <xsl:when test="$action-name = 'setfocus'">
                    <xsl:call-template name="action-setfocus"/>
                </xsl:when>
                <!--<xsl:when test="$action-name = 'dispatch'">
                    <xsl:call-template name="action-dispatch"/>
                </xsl:when>-->
                <xsl:when test="$action-name = 'rebuild'">
                    <xsl:call-template name="xforms-rebuild"/>
                </xsl:when>
                <xsl:when test="$action-name = 'recalculate'">
                    <xsl:call-template name="xforms-recalculate"/>
                </xsl:when>
                <!--<xsl:when test="$action-name = 'revalidate'">
                    <xsl:call-template name="xforms-revalidate"/>
                </xsl:when>-->
                <xsl:when test="$action-name = 'refresh'">
                    <xsl:call-template name="action-refresh"/>
                </xsl:when>
                <xsl:when test="$action-name = 'reset'">
                    <xsl:call-template name="action-reset"/>
                </xsl:when>
                <!--<xsl:when test="$action-name = 'load'">
                    <xsl:call-template name="action-load"/>
                </xsl:when>-->
                <xsl:when test="$action-name = 'send'">
                    <xsl:call-template name="action-send"/>
                </xsl:when>
                <xsl:when test="$action-name = 'message'">
                    <xsl:call-template name="action-message"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:message use-when="$debugMode">[applyActions] action '<xsl:value-of select="$action-name"/>' not yet handled!</xsl:message>
                </xsl:otherwise>
            </xsl:choose>
            
            
            <xsl:variable name="nested-actions-array" select="map:get($action-map, 'nested-actions')" as="array(map(*))?"/>
            <xsl:variable name="nested-actions" as="item()*">
                <xsl:sequence select="array:flatten($nested-actions-array)"/>
            </xsl:variable>
            <xsl:for-each select="$nested-actions">
                <xsl:call-template name="applyActions">
                    <xsl:with-param name="action-map" select="." tunnel="yes"/>
                </xsl:call-template>
            </xsl:for-each>
            
            <xsl:if test="$handler-status = 'outermost'">
                <xsl:call-template name="outermost-action-handler"/>
            </xsl:if>
            
            
        </xsl:if>
        
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
        
<!--        <xsl:message use-when="$debugMode">[setSubmission] setting submission for <xsl:sequence select="fn:serialize($this)"/></xsl:message>-->
                
        <xsl:variable name="refi" as="xs:string">
            <xsl:apply-templates select="." mode="get-data-ref"/>
        </xsl:variable>
        
        <xsl:variable name="this-instance-id" as="xs:string">
            <xsl:apply-templates select="." mode="get-context-instance-id">
                <xsl:with-param name="nodeset" select="$refi"/>
            </xsl:apply-templates>
        </xsl:variable>
        
        <xsl:variable name="bindingi" as="element(xforms:bind)*">
            <xsl:apply-templates select="." mode="get-binding">
                <xsl:with-param name="instance-id" select="$this-instance-id" tunnel="yes"/>
                <xsl:with-param name="nodeset" select="$refi" tunnel="yes"/>
            </xsl:apply-templates>
        </xsl:variable>
        
        <!-- set actions relevant to this -->
        <xsl:variable name="actions"  as="map(*)*">
            <xsl:apply-templates select="." mode="set-actions">
                <xsl:with-param name="instance-key" select="$this-instance-id" tunnel="yes"/>
                <xsl:with-param name="nodeset" select="$refi" tunnel="yes"/>
            </xsl:apply-templates>
        </xsl:variable>
        
        <xsl:if test="exists($actions)">
            <xsl:sequence select="js:addAction($submission-id, $actions)" />
        </xsl:if>
        
        <!-- default values bases on XForms spec section 11: https://www.w3.org/TR/xforms11/#submit -->
        <xsl:map>
            <xsl:if test="exists($this/@resource)">
                <xsl:map-entry key="'@resource'" select="xs:string($this/@resource)" />
            </xsl:if>
            
            <xsl:map-entry key="'@ref'" select="if (exists($refi)) then $refi else '/'"/>
            
            <xsl:if test="exists($this/@bind)">
                <xsl:map-entry key="'@bind'" select="xs:string($this/@bind)" />
            </xsl:if>
            
            <xsl:map-entry key="'@mode'" select="if (exists($this/@mode)) then xs:string($this/@mode) else 'asynchronous'" />
            
            <xsl:variable name="submission-method" as="xs:string">
                <xsl:choose>
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
            
            
            <xsl:map-entry key="'@mediatype'" select="if ($this/@mediatype) then string($this/@mediatype) else 'application/xml'"/>
            
            
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
            
           
        </xsl:map>
        
        
        
    </xsl:template>
   
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of <a href="https://www.w3.org/TR/xforms11/#evt-modelConstruct">xforms-model-construct event</a></xd:p>
            <xd:p>"Perform the behaviors of xforms-rebuild, xforms-recalculate, and xforms-revalidate in sequence on this model element without dispatching events to invoke the behaviors"</xd:p>
            <xd:p>TO DO: handle instances with data provided at an external URI.</xd:p>
        </xd:desc>
        <xd:param name="model">xforms:model element to be processed.</xd:param>
    </xd:doc>
    <xsl:template name="xforms-model-construct">
        <xsl:param name="model" as="element(xforms:model)" required="yes" tunnel="yes"/>
        
        <xsl:variable name="model-key" as="xs:string" select="if (exists($model/@id)) then xs:string($model/@id) else $global-default-model-id"/>
        
        <xsl:variable name="instances" as="element(xforms:instance)*" select="$model/xforms:instance"/>       
        
        <xsl:for-each select="$instances">
            <xsl:variable name="instance-with-explicit-namespaces" as="element()">
                <xsl:apply-templates select="./*" mode="namespace-fix"/>
            </xsl:variable>
            <xsl:variable name="instance-key" as="xs:string" select="if (exists(@id)) then xs:string(@id) else $global-default-instance-id"/>
            <xsl:map-entry key="$instance-key" select="$instance-with-explicit-namespaces"/>
            <xsl:sequence select="js:setInstance($instance-key,$instance-with-explicit-namespaces)"/>
            <xsl:if test="position() = 1">
                <xsl:sequence select="js:setDefaultInstance($instance-with-explicit-namespaces)"/>
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
        <xsl:param name="model" as="element(xforms:model)" required="yes" tunnel="yes"/>
        
        <xsl:if test="$get-bindings">
            <xsl:for-each select="$model/xforms:bind">
                <xsl:variable name="parsed-binding" as="element()">
                    <xsl:apply-templates select="." mode="add-context"/>
                </xsl:variable>
                
                <xsl:sequence select="js:setBinding($parsed-binding)"/>
            </xsl:for-each>
        </xsl:if>
      
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Add context to xforms:bind element. The relevant model and instance IDs are added, and the @nodeset is set (if absent) or expanded based on the $nodeset tunnel parameter</xd:p>
        </xd:desc>
        <xd:param name="model-key">ID of context model (xforms:model/@id value or default value).</xd:param>
    </xd:doc>
    <xsl:template match="xforms:bind" mode="add-context">
        <xsl:param name="model-key" as="xs:string" required="no" select="$global-default-model-id" tunnel="yes"/>        
        
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:attribute name="model-context" select="$model-key"/>
            
            <xsl:variable name="instance-context" as="xs:string">
                <xsl:apply-templates select="." mode="get-context-instance-id">
                    <xsl:with-param name="nodeset" select="if (@nodeset) then xs:string(@nodeset) else ''"/>
                </xsl:apply-templates>
            </xsl:variable>
            
            <xsl:attribute name="instance-context" select="$instance-context"/>
            
            <!-- set @nodeset to the current instance context -->
            
            <xsl:choose>
                <xsl:when test="exists(@nodeset)">
                    <xsl:attribute name="nodeset">
                        <xsl:apply-templates select="." mode="get-data-ref"/>
                    </xsl:attribute>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:attribute name="nodeset" select="concat( 'instance(', $instance-context ,')' )"/>
                </xsl:otherwise>
            </xsl:choose>
            
            
            <!-- TO DO: descendant elements? -->
        </xsl:copy>
    </xsl:template>
    
    

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of <a href="https://www.w3.org/TR/xforms11/#evt-recalculate">xforms-recalculate event</a></xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template name="xforms-recalculate">
        <xsl:message use-when="$debugMode">[xforms-recalculate] START</xsl:message>
        
        <xsl:variable name="bindings" as="element(xforms:bind)*" select="js:getBindings()"/>

        <xsl:variable name="instance-keys" select="js:getInstanceKeys()" as="item()*"/>
        <xsl:for-each select="$instance-keys">
            <xsl:variable name="instance-id" as="xs:string" select="."/>
            <xsl:variable name="instanceXML" select="js:getInstance(.)"/>
            <xsl:variable name="instance-calculation-bindings" as="element(xforms:bind)*" select="$bindings[@instance-context = $instance-id][exists(@calculate)]"/>
            
<!--            <xsl:message use-when="$debugMode">[xforms-recalculate] Calculation bindings relevant to model instance '<xsl:sequence select="$instance-id"/>': <xsl:sequence select="fn:serialize($instance-calculation-bindings)"/></xsl:message>-->
            
            <!-- sequence of nodes affected by calculations -->
            <xsl:variable name="calculated-nodes" as="node()*">
                <xsl:for-each select="$instance-calculation-bindings">
                    <xsl:evaluate xpath="xforms:impose(@nodeset)" context-item="$instanceXML" namespace-context="$instanceXML"/>    
                </xsl:for-each>
            </xsl:variable>
            
            <!-- sequence of new values for those nodes -->
            <xsl:variable name="calculated-values" as="xs:string*">
                <xsl:for-each select="$instance-calculation-bindings">
                    <!-- handle possibility that evaluation will return null -->
                    <xsl:variable name="value" as="xs:string?">
                        <xsl:evaluate xpath="xforms:impose(@calculate)" context-item="$instanceXML" namespace-context="$instanceXML"/>
                    </xsl:variable>
                    <!-- 
                        return at least an empty string
                        need to preserve sequence in step with calculated-nodes
                        
                        TO DO: what if a calculation binding references a set of nodes, not just a single node?
                    -->
                    <xsl:sequence select="($value,'')[1]"/>
                </xsl:for-each>
            </xsl:variable>
            
            <xsl:variable name="updatedInstanceXML" as="element()">
                <xsl:apply-templates select="$instanceXML" mode="recalculate">
                    <xsl:with-param name="updated-nodes" select="$calculated-nodes" tunnel="yes"/>
                    <xsl:with-param name="updated-values" select="$calculated-values" tunnel="yes"/>
                </xsl:apply-templates>
            </xsl:variable>
            
            <xsl:sequence select="js:setInstance($instance-id,$updatedInstanceXML)"/>
        </xsl:for-each>

    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of <a href="https://www.w3.org/TR/xforms11/#evt-revalidate">xforms-revalidate event</a></xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template name="xforms-revalidate">
        
    </xsl:template>

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of <a href="https://www.w3.org/TR/xforms11/#evt-refresh">xforms-refresh event</a></xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template name="xforms-refresh">
        <xsl:call-template name="refreshOutputs-JS"/>
        <xsl:call-template name="refreshRepeats-JS"/>
        <xsl:call-template name="refreshElementsUsingIndexFunction-JS"/>
        <xsl:call-template name="refreshRelevantFields-JS"/>
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
                <xsl:message use-when="$debugMode">[xforms-focus] Control '<xsl:sequence select="$control"/>' has index '<xsl:sequence select="$control-index"/>'</xsl:message>
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
        
        <xsl:variable name="submission-map" select="js:getSubmission($submission)" as="map(*)"/>
        <xsl:variable name="actions" select="js:getAction($submission)" as="map(*)*"/>
        
<!--        <xsl:message use-when="$debugMode">[xforms-submit] Submitting: <xsl:value-of select="serialize($submission-map)"/></xsl:message>-->
        <xsl:variable name="submit-message" as="xs:string" select="
            concat('[xforms-submit] Submitting ', serialize($submission-map) )"/>
        
        
        <xsl:variable name="refi" as="xs:string?" select="map:get($submission-map,'@ref')"/>
        
        <xsl:variable name="instance-id" as="xs:string" select="map:get($submission-map,'@instance')"/>
        
        
        <xsl:variable name="instanceXML" as="element()?" select="js:getInstance($instance-id)"/>
               
        <xsl:choose>
            <xsl:when test="exists($instanceXML)">
                
                <xsl:variable name="updatedInstanceXML" as="element()">
                    <xsl:choose>
                        <xsl:when test="js:getDeferredUpdateFlag('recalculate') = 'true'">
                            <xsl:variable name="data-fields" as="element()*" select="ixsl:page()//*[self::input or self::select or self::textarea][exists(@data-ref)][xforms:getInstanceId(@data-ref) = $instance-id]"/>
                            
                            <!-- sequence of nodes involved in submission -->
                            <xsl:variable name="calculated-nodes" as="node()*">
                                <xsl:for-each select="$data-fields">
                                    <xsl:evaluate xpath="xforms:impose(fn:string(@data-ref))" context-item="$instanceXML" namespace-context="$instanceXML"/>
                                </xsl:for-each>
                            </xsl:variable>
                            
                            <!-- sequence of new values for those nodes -->
                            <xsl:variable name="calculated-values" as="xs:string*">
                                <xsl:for-each select="$data-fields">
                                    <!-- handle possibility that evaluation will return null -->
                                    <xsl:variable name="value" as="xs:string?">
                                        <xsl:value-of>
                                            <xsl:apply-templates select="." mode="get-field"/>
                                        </xsl:value-of>
                                    </xsl:variable>
                                    <!-- 
                        return at least an empty string
                        need to preserve sequence in step with calculated-nodes
                    -->
                                    <xsl:sequence select="($value,'')[1]"/>
                                </xsl:for-each>
                            </xsl:variable>
                            
                            <xsl:apply-templates select="$instanceXML" mode="recalculate">
                                <xsl:with-param name="updated-nodes" select="$calculated-nodes" tunnel="yes"/>
                                <xsl:with-param name="updated-values" select="$calculated-values" tunnel="yes"/>
                            </xsl:apply-templates>
                            
                            <xsl:sequence select="js:clearDeferredUpdateFlag('recalculate')"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:sequence select="$instanceXML"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                
                                
                <!-- 
                    MD 2020-04-05: I think this is "the rebuild operation is performed without dispatching an event to invoke the operation."
                    
                    https://www.w3.org/TR/xforms11/#submit-evt-submit
                -->
                <xsl:variable name="required-fields-check" as="item()*" select="xforms:check-required-fields($updatedInstanceXML)"/>
                <xsl:variable name="constrained-fields-check" as="item()*" select="xforms:check-constraints-on-fields($updatedInstanceXML)"/>
               
               <!-- <xsl:message use-when="$debugMode">[xforms-submit] Submitting instance XML: <xsl:value-of select="serialize($instanceXML)"/></xsl:message>
                <xsl:message use-when="$debugMode">[xforms-submit] Updated instance XML: <xsl:value-of select="serialize($updatedInstanceXML)"/></xsl:message>
                -->
                
                <xsl:choose>
                    <xsl:when test="empty($required-fields-check) and empty($constrained-fields-check)">
                        
                        <xsl:variable name="requestBody" as="node()?">
                            <xsl:choose>
                                <xsl:when test="$refi">
                                    <xsl:evaluate xpath="xforms:impose($refi)" context-item="$instanceXML" namespace-context="$instanceXML"/>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:sequence select="$updatedInstanceXML"/>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:variable>
                        
<!--                        <xsl:message use-when="$debugMode">[xforms-submit] Request body: <xsl:sequence select="fn:serialize($requestBody)"/></xsl:message>-->
                        
                        <xsl:variable name="requestBodyDoc" as="document-node()?">
                            <xsl:if test="$requestBody[self::element()]">
                                <xsl:document>
                                    <xsl:sequence select="$requestBody"/>
                                </xsl:document>
                            </xsl:if>
                        </xsl:variable>
                        
                        <xsl:variable name="method" as="xs:string" select="map:get($submission-map,'@method')"/>
                        
                        <xsl:variable name="serialization" as="xs:string?" select="map:get($submission-map,'@serialization')"/>
                        
                        <xsl:variable name="query-parameters" as="xs:string?">
                            <xsl:if test="exists($serialization) and $serialization = 'application/x-www-form-urlencoded'">
                                <!--                        <xsl:message use-when="$debugMode">[xforms-submit] Deriving form data from $requestBodyXML: <xsl:value-of select="serialize($requestBody)"/></xsl:message>-->
                                <xsl:variable name="parts" as="xs:string*">
                                    <xsl:choose>
                                        <xsl:when test="exists($requestBodyDoc)">
                                            <xsl:for-each select="$requestBody/*">
                                                <xsl:variable name="query-part" as="xs:string" select="concat(local-name(),'=',string())"/>
                                                <xsl:sequence select="$query-part"/>
                                                <!--                                        <xsl:message use-when="$debugMode">[xforms-submit] Query part: <xsl:value-of select="$query-part"/></xsl:message>-->
                                                
                                            </xsl:for-each>
                                        </xsl:when>
                                        <xsl:otherwise/>
                                    </xsl:choose>
                                    
                                </xsl:variable>
                                <xsl:sequence select="
                                    string-join($parts,'&amp;') 
                                    "/>
                            </xsl:if>
                        </xsl:variable>
                        
                        <xsl:variable name="href-base" as="xs:string" select="map:get($submission-map,'@resource')"/>
                        
                        <xsl:variable name="href" as="xs:string">
                            <xsl:choose>
                                <xsl:when test="exists($query-parameters)">
                                    <xsl:sequence select="concat($href-base,'?',$query-parameters)"/>
                                </xsl:when>
                                <xsl:when test="$requestBody[self::text()]">
                                    <xsl:sequence select="concat($href-base,'/',$requestBody)"/>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:sequence select="$href-base"/>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:variable>
                        
                        <xsl:variable name="mediatype" as="xs:string" select="map:get($submission-map,'@mediatype')"/>      
                        
                        <!-- http://www.saxonica.com/saxon-js/documentation/index.html#!development/http -->
                        <xsl:variable name="HTTPrequest" as="map(*)">
                            <xsl:map>
                                <xsl:if test="not( upper-case($method) = 'GET')">
                                    <xsl:choose>
                                        <xsl:when test="exists($requestBodyDoc)">
                                            <xsl:map-entry key="'body'" select="$requestBodyDoc"/>       
                                        </xsl:when>
                                        <xsl:otherwise>
                                            <xsl:map-entry key="'body'" select="$requestBody"/>
                                        </xsl:otherwise>
                                    </xsl:choose>
                                    <xsl:map-entry key="'media-type'" select="$mediatype"/>
                                    <!--                            <xsl:map-entry key="'body'" select="$requestBodyDoc"/>  -->
                                </xsl:if>
                                <xsl:map-entry key="'method'" select="$method"/>
                                <xsl:map-entry key="'href'" select="$href"/>
                                
                            </xsl:map>
                        </xsl:variable>
                        
                        <!--                <xsl:message use-when="$debugMode">[xforms-submit] Sending HTTP request '<xsl:sequence select="fn:serialize($HTTPrequest)"/>'</xsl:message>-->
                        
                        
                        <ixsl:schedule-action http-request="$HTTPrequest">
                            <!-- The value of @http-request is an XPath expression, which evaluates to an 'HTTP request
                            map' - i.e. our representation of an HTTP request as an XDM map -->
                            <xsl:call-template name="HTTPsubmit">
                                <xsl:with-param name="instance-id" select="$instance-id" as="xs:string"/>
                                <xsl:with-param name="targetref" select="map:get($submission-map,'@targetref')"/>
                                <xsl:with-param name="replace" select="map:get($submission-map,'@replace')"/>
                                <xsl:with-param name="when-done" select="$actions[map:get(.,'@event') = 'xforms-submit-done']" tunnel="yes"/>
                            </xsl:call-template>
                        </ixsl:schedule-action>
                        
                                       
                    </xsl:when>
                    
                    <xsl:otherwise>
                        <xsl:variable name="error-message">
                            <xsl:for-each select="$constrained-fields-check">
                                <xsl:variable name="curNode" select="."/>
                                <xsl:value-of select="concat('Invalid field value: ', serialize($curNode/@data-ref), '&#10;')"/>
                            </xsl:for-each>
                            <xsl:for-each select="$required-fields-check">
                                <xsl:variable name="curNode" select="."/>
                                <xsl:value-of select="concat('Required field is empty: ', serialize($curNode/@data-ref), '&#10;')"/>
                            </xsl:for-each>
                        </xsl:variable>
                        <xsl:sequence select="ixsl:call(ixsl:window(), 'alert', [serialize($error-message)])"/>
                    </xsl:otherwise>
                </xsl:choose>
                
            </xsl:when>
            <xsl:otherwise>
                <xsl:call-template name="logToPage">
                    <xsl:with-param name="message" select="concat('Unable to locate XForms instance relating to submission ', serialize($submission-map))"/>
                    <xsl:with-param name="level" select="'error'"/>
                </xsl:call-template>
            </xsl:otherwise>
        </xsl:choose>
        
        
    </xsl:template>
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of <xd:a href="https://www.w3.org/TR/xforms11/#submit-evt-submit-done">xforms-submit-done event</xd:a></xd:p>
        </xd:desc>
        <xd:param name="when-done">Action maps to apply (@ev:event = 'xforms-submit-done')</xd:param>
    </xd:doc>
    <xsl:template name="xforms-submit-done">
        <xsl:param name="when-done" as="map(*)*" required="no" tunnel="yes"/>
        
        <xsl:for-each select="$when-done">
            <xsl:variable name="action-map" select="."/>
            
            <xsl:call-template name="applyActions">
                <xsl:with-param name="action-map" select="$action-map" tunnel="yes"/>
            </xsl:call-template>
        </xsl:for-each> 
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of <xd:a href="https://www.w3.org/TR/xforms11/#action-deferred-update-behavior">deferred update behaviour</xd:a></xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template name="outermost-action-handler">
        <xsl:variable name="deferred-update-flags" as="map(*)?" select="js:getDeferredUpdateFlags()"/>
        
        <xsl:message use-when="$debugMode">[outermost-action-handler] START</xsl:message>
        
        <!-- not convinced there's anything to do in the xforms-rebuild event -->
        <!--<xsl:if test="map:get($deferred-update-flags,'rebuild') = 'true'">
            <xsl:call-template name="xforms-rebuild"/>
        </xsl:if>-->
        <xsl:if test="map:get($deferred-update-flags,'recalculate') = 'true'">
            <xsl:message use-when="$debugMode">[outermost-action-handler] triggering xforms-recalculate</xsl:message>
            <xsl:call-template name="xforms-recalculate"/>
        </xsl:if>
        <xsl:if test="map:get($deferred-update-flags,'revalidate') = 'true'">
            <xsl:message use-when="$debugMode">[outermost-action-handler] triggering xforms-revalidate</xsl:message>
            <xsl:call-template name="xforms-revalidate"/>
        </xsl:if>
        <xsl:if test="map:get($deferred-update-flags,'refresh') = 'true'">
            <xsl:message use-when="$debugMode">[outermost-action-handler] triggering xforms-refresh</xsl:message>
            <xsl:call-template name="xforms-refresh"/>
        </xsl:if>
       
        
        <xsl:sequence select="js:clearDeferredUpdateFlags()"/>
        
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
            <xd:p>Implementation of a DOMActivate event</xd:p>
        </xd:desc>
        <xd:param name="form-control">HTML form control with a @data-action attribute referencing registered actions.</xd:param>
    </xd:doc>
    <xsl:template name="DOMActivate">
        <xsl:param name="form-control" as="node()"/>
        
        <xsl:variable name="actions" select="js:getAction(string($form-control/@data-action))" as="map(*)*"/>
        
        <xsl:variable name="refi" as="xs:string" select="if (exists($form-control/@data-ref)) then xs:string($form-control/@data-ref) else ''"/>
        
        <xsl:variable name="instance-id" as="xs:string" select="xforms:getInstanceId($refi)"/>
                
        <!-- MD 2020-02-22 -->
        <xsl:variable name="instanceXML" as="element()?" select="xforms:instance($instance-id)"/>
        
        <xsl:variable name="updatedInstanceXML" as="element()?">
            <xsl:choose>
                <xsl:when test="exists($refi) and exists($instanceXML)">
                    <xsl:variable name="updatedNode" as="node()">
                        <xsl:evaluate xpath="xforms:impose($refi)" context-item="$instanceXML" namespace-context="$instanceXML"/>
                    </xsl:variable>
                    <xsl:variable name="new-value" as="xs:string">
                        <xsl:apply-templates select="$form-control" mode="get-field"/>
                    </xsl:variable>
                    <xsl:apply-templates select="$instanceXML" mode="recalculate">
                        <xsl:with-param name="instance-id" select="$instance-id"/>
                        <xsl:with-param name="updated-nodes" select="$updatedNode" tunnel="yes"/>
                        <xsl:with-param name="updated-values" select="$new-value" tunnel="yes"/>
                    </xsl:apply-templates>
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
                    </xsl:call-template>
                </xsl:if>
            </xsl:if>
        </xsl:for-each>                
        
    </xsl:template>
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for applying setvalue action. See <a href="https://www.w3.org/TR/xforms11/#action-setvalue">10.2 The setvalue Element</a></xd:p>
        </xd:desc>
        <xd:param name="action-map">Action map</xd:param>
    </xd:doc>
    <xsl:template name="action-setvalue">
        <xsl:param name="action-map" required="yes" as="map(*)" tunnel="yes"/>
        
        <xsl:message use-when="$debugMode">[action-setvalue] START</xsl:message>
        
        <xsl:variable name="instance-context" select="map:get($action-map, 'instance-context')" as="xs:string"/>
        <xsl:variable name="ifVari" select="xforms:getIfStatement($action-map)"/>
        <xsl:variable name="whileVari" select="xforms:getWhileStatement($action-map)"/>

        
        <!--OND Apr 2020: The $nodeset path should have already been resolved. Therefore just set $refz to the $nodeset-->
        <xsl:variable name="refz" select="map:get($action-map,'@ref')"/>

        
        <xsl:variable name="instanceXML2" as="element()" select="js:getInstance($instance-context)"/>
        
<!--        <xsl:message use-when="$debugMode">[action-setvalue] Applying action '<xsl:sequence select="serialize($action-map)"/>'</xsl:message>-->
        
        
        <!-- TODO: use ifVari and WhileVari -->
        <xsl:if test="exists($refz)">
            <xsl:variable name="updated-node" as="node()">
                <xsl:evaluate xpath="xforms:impose($refz)" context-item="$instanceXML2" namespace-context="$instanceXML2" as="node()" />
            </xsl:variable>
            
            <xsl:variable name="updated-value" as="xs:string">
                <xsl:choose>
                    <xsl:when test="map:contains($action-map,'@value')">
                        <xsl:variable name="updated-item" as="item()">
                            <xsl:evaluate xpath="xforms:impose(map:get($action-map,'@value'))" context-item="$updated-node" namespace-context="$updated-node" />
                        </xsl:variable>
<!--                        <xsl:message use-when="$debugMode">[action-setvalue] updated item '<xsl:sequence select="serialize($updated-item)"/>'</xsl:message>-->
                        <xsl:choose>
                            <!-- 
                                Handle case where @value evaluates to a boolean.
                                Logic mirrors that in template for HTML input (mode="get-field")
                                
                                TO DO: handle other possible data types of @value?
                            -->
                            <xsl:when test="$updated-item = true()">
                                <xsl:sequence select="'true'"/>
                            </xsl:when>
                            <xsl:when test="$updated-item = false()">
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
<!--            <xsl:message use-when="$debugMode">[action-setvalue] updated value '<xsl:sequence select="serialize($updated-value)"/>'</xsl:message>-->
            
            
            <xsl:variable name="updatedInstanceXML" as="element()">
                <xsl:apply-templates select="$instanceXML2" mode="recalculate">
                    <xsl:with-param name="updated-nodes" select="$updated-node" tunnel="yes"/>
                    <xsl:with-param name="updated-values" select="$updated-value" tunnel="yes"/>
                </xsl:apply-templates>
            </xsl:variable>
            
<!--            <xsl:message use-when="$debugMode">[action-setvalue] updated instance <xsl:sequence select="serialize($updatedInstanceXML)"/></xsl:message>-->
            
            <xsl:sequence select="js:setInstance($instance-context,$updatedInstanceXML)"/>
            
            <xsl:sequence select="js:setDeferredUpdateFlags(('recalculate','revalidate','refresh'))" />    
            
         </xsl:if>
        
       
    </xsl:template>
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Update instance from value of form control</xd:p>
        </xd:desc>
        <xd:param name="form-control">HTML form control containing new value for updating an instance etc.</xd:param>
    </xd:doc>
    <xsl:template name="action-setvalue-form-control">
        <xsl:param name="form-control" as="node()"/>
        
        <xsl:variable name="refi" select="$form-control/@data-ref"/>
        <xsl:variable name="refElement" select="$form-control/@data-element"/>
        
        <xsl:variable name="instance-id" as="xs:string" select="xforms:getInstanceId($refi)"/>
        <xsl:variable name="actions" select="js:getAction(string($form-control/@data-action))"/>
        
        <!--        <xsl:sequence select="sfp:logInfo(concat('[xforms-value-changed] Evaluating data ref: ', $refi))"/>-->
        
        <!-- MD 2020-02-22 -->
        <xsl:variable name="instanceXML" as="element()" select="xforms:instance($instance-id)"/>
        <xsl:variable name="updatedNode" as="node()">
            <xsl:evaluate xpath="xforms:impose($refi)" context-item="$instanceXML" namespace-context="$instanceXML"/>
        </xsl:variable>
        <xsl:variable name="new-value" as="xs:string">
            <xsl:apply-templates select="$form-control" mode="get-field"/>
        </xsl:variable>
        <xsl:variable name="updatedInstanceXML" as="element()">
            <xsl:apply-templates select="$instanceXML" mode="recalculate">
                <xsl:with-param name="instance-id" select="$instance-id"/>
                <xsl:with-param name="updated-nodes" select="$updatedNode" tunnel="yes"/>
                <xsl:with-param name="updated-values" select="$new-value" tunnel="yes"/>
            </xsl:apply-templates>
        </xsl:variable>
        
        <!--        <xsl:message use-when="$debugMode">[xforms-value-changed] Updated XML: <xsl:sequence select="serialize($updatedInstanceXML)"/></xsl:message>-->
        
        <xsl:sequence select="js:setInstance($instance-id,$updatedInstanceXML)"/>

        <xsl:sequence select="js:setDeferredUpdateFlags(('recalculate','revalidate','refresh'))" />    

        <!-- 
            MD 2020-04-13 
            this event should be dispatched during xfroms-refresh 
        -->
        <xsl:call-template name="xforms-value-changed">
            <xsl:with-param name="when-value-changed" select="$actions[map:get(.,'@event') = 'xforms-value-changed']" tunnel="yes"/>
        </xsl:call-template>
              
    </xsl:template>
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for applying insert action</xd:p>
        </xd:desc>
        <xd:param name="action-map">Action map</xd:param>
    </xd:doc>
    <xsl:template name="action-insert">
        <xsl:param name="action-map" required="yes" as="map(*)" tunnel="yes"/>
                
        <xsl:variable name="instance-context" select="map:get($action-map, 'instance-context')" as="xs:string"/>
        <xsl:variable name="handler-status" select="map:get($action-map, 'handler-status')" as="xs:string"/>
        <xsl:variable name="ref" select="map:get($action-map,'@ref')" />
        <xsl:variable name="at" select="map:get($action-map, '@at')" as="xs:string?"/>
        <xsl:variable name="position" select="map:get($action-map, '@position')" as="xs:string?"/>
        <xsl:variable name="origin-ref" select="map:get($action-map, '@origin')" as="xs:string?"/>
        <xsl:variable name="context" select="map:get($action-map, '@context')" as="xs:string?"/>
        
        
        <xsl:variable name="ref-qualified" as="xs:string?" select="
            if (exists($ref) and $ref != '')
            then (
            if (exists($at))
            then concat($ref, '[', $at, ']')
            else $ref
            )
            else ()
            "/>
        
        <xsl:variable name="instanceXML2" as="element()" select="js:getInstance($instance-context)"/>
        
         
                 
<!--        <xsl:message use-when="$debugMode">[action-insert] $nodeset = '<xsl:value-of select="$nodeset"/>'; $ref = '<xsl:value-of select="$ref"/>'; inserting node at XPath <xsl:value-of select="$ref-qualified"/></xsl:message>-->
       
        
        <!--<xsl:message use-when="$debugMode">[action-insert] $insert-node-location = <xsl:value-of select="fn:serialize($insert-node-location)"/></xsl:message>
        <xsl:message use-when="$debugMode">[action-insert] $origin-node = <xsl:value-of select="fn:serialize($origin-node)"/></xsl:message>-->
        
        <xsl:variable name="instance-id-origin" as="xs:string" select="xforms:getInstanceId($origin-ref)"/>
        <xsl:variable name="instanceXML-origin" as="element()" select="js:getInstance($instance-id-origin)"/>
        
        <xsl:variable name="origin-node" as="node()?">
            <xsl:evaluate xpath="xforms:impose($origin-ref)" context-item="$instanceXML-origin" namespace-context="$instanceXML-origin"/>
        </xsl:variable>
        
        <xsl:variable name="insert-node-location" as="node()?">
            <xsl:evaluate xpath="xforms:impose($ref-qualified)" context-item="$instanceXML2" namespace-context="$instanceXML2"/>
        </xsl:variable> 
        
        <xsl:variable name="context-node" as="node()">
            <xsl:evaluate xpath="xforms:impose($context)" context-item="$instanceXML2" namespace-context="$instanceXML2"/>
        </xsl:variable>
        
        
        <xsl:variable name="node-to-insert" as="node()?">
            <xsl:choose>
                <xsl:when test="exists($origin-node)">
                    <xsl:copy-of select="$origin-node"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:copy-of select="$insert-node-location"/>
                </xsl:otherwise>
            </xsl:choose>
            
        </xsl:variable>
        
        
        <xsl:variable name="instance-with-insert" as="element()">
            <xsl:apply-templates select="$instanceXML2" mode="insert-node">
                <xsl:with-param name="insert-node-location" select="if (exists($insert-node-location)) then $insert-node-location else $context-node" tunnel="yes"/>
                <xsl:with-param name="node-to-insert" select="$node-to-insert" tunnel="yes"/>
                <xsl:with-param name="position-relative" select="if (exists($insert-node-location)) then $position else 'child'" tunnel="yes"/>
            </xsl:apply-templates>
        </xsl:variable>
        
        <!--        <xsl:message use-when="$debugMode">[action-insert] Updated instance: <xsl:sequence select="fn:serialize($instance-with-insert)"/></xsl:message>-->
        
        <xsl:sequence select="js:setInstance($instance-context,$instance-with-insert)"/>
        
        
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
                     
        <xsl:if test="$handler-status = 'inner'">
            <xsl:sequence select="js:setDeferredUpdateFlags(('rebuild','recalculate','revalidate','refresh'))"/>
        </xsl:if>
    </xsl:template>
    
 
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for applying delete action</xd:p>
        </xd:desc>
        <xd:param name="action-map">Action map</xd:param>
    </xd:doc>
    <xsl:template name="action-delete">
        <xsl:param name="action-map" required="yes" as="map(*)" tunnel="yes"/>
        
        <xsl:variable name="instance-context" select="map:get($action-map, 'instance-context')" as="xs:string"/>
        <xsl:variable name="handler-status" select="map:get($action-map, 'handler-status')" as="xs:string"/>
        <xsl:variable name="ref" select="map:get($action-map,'@ref')"/>
        <xsl:variable name="at" select="map:get($action-map, '@at')" as="xs:string?"/>
        
        <xsl:variable name="ref-qualified" as="xs:string?" select="
            if (exists($ref))
            then (
            if (exists($at))
            then concat($ref, '[', $at, ']')
            else $ref
            )
            else ()
            "/>
        
        <xsl:variable name="instanceXML2" as="element()" select="js:getInstance($instance-context)"/>
        
        <xsl:variable name="ifVar" select="xforms:getIfStatement($action-map)"/>
        <xsl:variable name="whileVar" select="xforms:getWhileStatement($action-map)"/>
         
        <xsl:variable name="delete-node" as="node()*">
            <xsl:choose>
                <xsl:when test="exists($ref-qualified) and not($ref-qualified = '')">
                    <xsl:evaluate xpath="xforms:impose($ref-qualified)" context-item="$instanceXML2" namespace-context="$instanceXML2"/>
                </xsl:when>
            </xsl:choose>
        </xsl:variable>
                
        <xsl:variable name="ifExecuted" as="xs:boolean">
            <xsl:choose>
                <xsl:when test="exists($ifVar)">
                    <xsl:evaluate xpath="xforms:impose($ifVar)" context-item="$delete-node" namespace-context="$delete-node"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="true()" />
                </xsl:otherwise>
            </xsl:choose>                    
        </xsl:variable>
                       
        <xsl:if test="$ifExecuted">
            <xsl:variable name="instance-with-delete" as="element()">
                <xsl:apply-templates select="$instanceXML2" mode="delete-node">
                    <xsl:with-param name="delete-node" select="$delete-node" tunnel="yes"/>
                </xsl:apply-templates>
            </xsl:variable> 
            
<!--            <xsl:message use-when="$debugMode">[action-delete] Updated instance: <xsl:sequence select="fn:serialize($instance-with-delete)"/></xsl:message>-->
            
            <xsl:sequence select="js:setInstance($instance-context,$instance-with-delete)"/>    
            
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
            
            <xsl:if test="$handler-status = 'inner'">
                <xsl:sequence select="js:setDeferredUpdateFlags(('rebuild','recalculate','revalidate','refresh'))"/>
            </xsl:if>
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
        
        <xsl:variable name="message-value" as="xs:string" select="map:get($action-map,'value')"/>
        <!-- XForms 1.1 spec: The default is "modal" if the attribute is not specified -->
        <xsl:variable name="message-level" as="xs:string" select="(map:get($action-map,'@level'), 'modal')[1]"/>
        
        <xsl:message use-when="$debugMode">[action-message] Message (level '<xsl:value-of select="$message-level"/>') reads "<xsl:value-of select="$message-value"/>"</xsl:message>
        
        <!-- TO DO: implement remainder of this action -->
        <xsl:choose>
            <xsl:when test="$message-level = 'ephemeral'">
                <xsl:call-template name="logToPage">
                    <xsl:with-param name="message" select="$message-value"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$message-level = 'modal'"/>
            <xsl:when test="$message-level = 'modeless'"/>
            <xsl:otherwise/>
        </xsl:choose>
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
        
<!--        <xsl:message use-when="$debugMode">[action-setindex] $action-map = <xsl:value-of select="serialize($action-map)"/></xsl:message>-->
        
        <xsl:sequence select="js:setRepeatIndex($repeatID,$new-index)"/>
        
    </xsl:template>
    
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for applying recalculate action</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template name="action-recalculate">
        <xsl:message>[action-recalculate] START</xsl:message>
        
        <xsl:call-template name="xforms-recalculate"/>
        <xsl:sequence select="js:clearDeferredUpdateFlag('recalculate')"/>
    </xsl:template>

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for applying refresh action</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template name="action-refresh">
        <xsl:message>[action-refresh] START</xsl:message>
        
        <xsl:call-template name="xforms-refresh"/>
        <xsl:sequence select="js:clearDeferredUpdateFlag('refresh')"/>
    </xsl:template>

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for applying reset action</xd:p>
        </xd:desc>
        <xd:param name="action-map">Action map</xd:param>
    </xd:doc>
    <xsl:template name="action-reset">
        <xsl:param name="action-map" required="yes" as="map(*)" tunnel="yes"/>
        
        <xsl:message>[action-reset] Reset triggered!</xsl:message>
        <!-- TO DO: implement remainder of this action -->
        <xsl:sequence select="js:clearDeferredUpdateFlags()"/>
    </xsl:template>
    
</xsl:stylesheet>
