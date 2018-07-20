<!-- This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/. -->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl"
    xmlns:math="http://www.w3.org/2005/xpath-functions/math"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:xforms="http://www.w3.org/2002/xforms" xmlns:xhtml="http://www.w3.org/1999/xhtml"
    xmlns:xf="http://www.w3.org/2002/xforms"
    xmlns:js="http://saxonica.com/ns/globalJS" xmlns:ixsl="http://saxonica.com/ns/interactiveXSLT"
    xmlns:sfl="http://saxonica.com/ns/forms-local"
    xmlns:in="http://www.w3.org/2002/xforms-instance"
    xmlns:fn="http://www.w3.org/2005/xpath-functions"
    xmlns:map="http://www.w3.org/2005/xpath-functions/map"
    xmlns:array="http://www.w3.org/2005/xpath-functions/array"
    xmlns:saxon="http://saxon.sf.net/"
    xmlns:ev="http://www.w3.org/2001/xml-events"
    
    xmlns:r="http://ns.datacraft.co.uk/recipe"
    
    exclude-result-prefixes="xs math xforms sfl"
    extension-element-prefixes="ixsl saxon" version="3.0">
    
    <!-- TO DO: dynamically recognize namespaces in XForms document when evaluating XPaths -->
    <!--  xmlns:r="http://ns.datacraft.co.uk/recipe" -->
    <xsl:include href="xforms-function-library.xsl"/>

    <xsl:output method="html" encoding="utf-8" omit-xml-declaration="no" indent="no"
        doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN"
        doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"/>

    <xsl:param name="xforms-instance-id" select="'xforms-jinstance'"/>
    <xsl:param name="xforms-cache-id" select="'xforms-cache'"/>
    
    <!-- @id attribute of HTML div element into which the XForm is to be rendered on the page -->
    <xsl:param name="xform-html-id" as="xs:string" select="'xForm'"/>
    
    <xsl:param name="xforms-file" as="xs:string?"/>

    <xsl:variable static="yes" name="debugMode" select="true()"/>
    <xsl:variable static="yes" name="debugTiming" select="false()"/>
    <xsl:variable static="yes" name="default-instance-id" select="'saxon-forms-default'" as="xs:string"/>
    <xsl:variable static="yes" name="default-submission-id" select="'saxon-forms-default-submission'" as="xs:string"/>
    
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
    

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Main initial template.</xd:p>
            <xd:p>Writes Javascript code into HTML page.</xd:p>
            <xd:p>Sets instances in Javascript variables and as a map.</xd:p>
            <xd:p>Registers bindings and submissions as maps.</xd:p>
        </xd:desc>
        <xd:param name="xforms-doc">Complete XForms document.</xd:param>
        <xd:param name="xforms-file">File path to XForms document.</xd:param>
        <xd:param name="instance-xml">A single instance from the XForms document. (REDUNDANT?)</xd:param>
        <xd:param name="instance-docs">All instances in the XForms document. (When completely refreshing the form from JS set parameters)</xd:param>
        <xd:param name="xFormsId">The @id of an HTML div on the page into which the XForm will be rendered.</xd:param>
    </xd:doc>
    <xsl:template name="xformsjs-main">
        <xsl:param name="xforms-doc" as="document-node()?" select="()"/>
        <xsl:param name="xforms-file" as="xs:string?"/>
        <!-- 
            MD 2018
            The XForm may have more than one instance
            ant it is an element not a document node (?)
            (but gives compile error on line 2227)
            
            REDUNDANT?
        -->
        <xsl:param name="instance-xml" as="document-node()*"/>
        <xsl:param name="instance-docs" as="map(*)?"/>
        
        <xsl:param name="xFormsId" select="$xform-html-id" as="xs:string"/>

        <xsl:variable name="xforms-doci"
            select="
                if (empty($xforms-doc)) then
                    doc($xforms-file)
                else
                    $xforms-doc"
            as="document-node()?"/>
        
        <xsl:message use-when="$debugMode">instance-docs: <xsl:value-of select="serialize($instance-docs)"/></xsl:message>

        <!-- all xforms:instance elements in the XForm -->
        <xsl:variable name="xforms-instances" as="map(xs:string, element())">
            <xsl:choose>
                <xsl:when test="empty($instance-docs)">
                    <xsl:map>
                        <xsl:choose>
                            <xsl:when test="empty($instance-xml)">
                                <xsl:for-each select="$xforms-doci/xforms:xform/xforms:model/xforms:instance">
                                    <xsl:map-entry key="
                                        xs:string(
                                        if (exists(@id)) 
                                        then @id 
                                        else $default-instance-id
                                        )"
                                        select="./*"/>
                                </xsl:for-each>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:map-entry key="
                                    xs:string(
                                    if (exists($instance-xml/*/@id)) 
                                    then $instance-xml/*/@id 
                                    else $default-instance-id
                                    )"
                                    select="$instance-xml/*"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:map>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="$instance-docs"/>
                </xsl:otherwise>
            </xsl:choose> 
        </xsl:variable>
        
        <!-- first instance (use as default if all instances have @id) -->
        <xsl:variable name="default-instance" as="element()">
            <xsl:choose>
                <xsl:when test="empty($instance-docs)">
                    <xsl:choose>
                        <xsl:when test="$xforms-doci/xforms:xform/xforms:model/xforms:instance[not(@id)]">
                            <xsl:sequence select="$xforms-doci/xforms:xform/xforms:model/xforms:instance[not(@id)][1]/*"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:sequence select="$xforms-doci/xforms:xform/xforms:model/xforms:instance[1]/*"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:when>
                <!-- instance doc already set in first build... -->
                <xsl:otherwise>
                    <xsl:sequence select="js:getDefaultInstance()"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <!-- register all bindings in model as a map -->
        <xsl:variable name="bindings" as="map(xs:string, node())">
            <xsl:map>
                <xsl:for-each select="$xforms-doci/xforms:xform/xforms:model/xforms:bind">
                    <!-- [exists(@type)] -->
                    <xsl:map-entry
                        key="
                            xs:string(if (exists(@id)) 
                            then @id
                            else @nodeset)"
                        select="."/>
                </xsl:for-each>
            </xsl:map>
        </xsl:variable>
        
        <!-- $orig-instance-doc (for an xforms-reset event?) -->
        <xsl:variable name="orig-instance-doc">
            <wrapper>
                <xsl:sequence select="$xforms-doci/xforms:xform/xforms:model/xforms:instance/*"/>
            </wrapper>
        </xsl:variable>
        
        
        <!-- set relevant bindings -->
        <xsl:variable name="bindingKeys" select="map:keys($bindings)" as="item()*"/>
        
        <xsl:variable name="RelevantBindings" as="map(xs:string, xs:string)">
            <xsl:map>
                <xsl:for-each select="$bindingKeys">
                    <xsl:variable name="bindingNode" select="map:get($bindings, xs:string(.))" as="node()" />                    
                    
                    <xsl:if test="$bindingNode[exists(@relevant)]">
                        <xsl:variable name="keyi" select="xs:string($bindingNode/@nodeset)" as="xs:string"/>
                        <xsl:map-entry key="$keyi" select="xs:string($bindingNode/@relevant)" />
                    </xsl:if>
                </xsl:for-each>
            </xsl:map>  
        </xsl:variable>
        
        <xsl:message use-when="$debugMode">
            RelevantBindings = <xsl:sequence select="serialize($RelevantBindings)"/>
        </xsl:message>


        <!-- copy xform-doc to HTML page -->
        <xsl:choose>
            <!-- when Javascript section already exists... (i.e. page is being re-rendered? REDUNDANT?) -->
            <xsl:when test="ixsl:page()//script/@id = $xforms-cache-id">
                <xsl:sequence select="js:setXFormsDoc($xforms-doc)"/>
                <xsl:sequence select="js:setXFormsID($xFormsId)"/>
                <xsl:sequence select="js:setRelevantMap($RelevantBindings)" />
            </xsl:when>
            <xsl:otherwise>
                <!-- 
                    MD 2018
                    
                    for ixsl:page() 
                    see http://www.saxonica.com/saxon-js/documentation/index.html#!ixsl-extension/functions/page
                    
                    "the document node of the HTML DOM document"
                -->
                <xsl:for-each select="ixsl:page()//head">
                    <!-- 
                        MD 2018
                        
                        for href="?." 
                        see http://www.saxonica.com/saxon-js/documentation/index.html#!development/result-documents
                        
                        "the current context item as the target for inserting a generated fragment of HTML"
                    -->
                    <xsl:result-document href="?.">
                        <script type="text/javascript" id="{$xforms-cache-id}">                
                            var XFormsDoc = null;
                            var defaultInstanceDoc = null;
                            
                            // MD 2018: OND's suggestion for multiple instances
                            var instanceDocs = {};
                            
                            var pendingUpdatesMap = null;
                            var updatesMap = null;
                            var XFormsID = '<xsl:value-of select="$xFormsId"/>';
                            var actions = {};
                            var submissions = {};
                            var outputs = {};
                            var relevantMap = {};
                            
                            var getCurrentDate = function(){
                                var today = new Date();
                                var dd = today.getDate();
                                var mm = today.getMonth()+1; //January is 0!
                                var yyyy = today.getFullYear();
                            
                                if(dd &lt; 10) {
                                    dd = '0' + dd;
                                } 
                            
                                if(mm &lt; 10) {
                                    mm = '0' + mm;
                                } 
                            
                                today = yyyy + '-' + mm + '-' + dd;
                                return today;
                            }
                            
                            
                            var setXFormsDoc = function(doc) {
                                XFormsDoc = doc;
                            }
                            
                            var getXFormsDoc = function() {
                                return XFormsDoc;
                            }
                            var setXFormsID = function(id) {
                                XFormsID = id;
                            }
                            
                            var getXFormsID = function() {
                                return XFormsID;
                            }
                            
                            
                            var setInstance = function(name, value) {
                                instanceDocs[name] = value;
                            } 
                            
                            var getInstance = function(name) {
                                return instanceDocs[name];
                            }
                            
                            
                            //[OND] Maybe we can just set the key-> value without having to copy the entire instanceDocs object.
                            var updateInstance = function(instanceDocs, key, value){
                                instanceDocs[key] = value;
                                return instanceDocs;
                            }
                            
                            
                            var setDefaultInstance = function(doc) {
                                defaultInstanceDoc = doc;
                            }
                            
                            var getDefaultInstance = function() {
                                return defaultInstanceDoc;
                            }
                            
                           
                            var getInstanceKeys = function() {
                                return Object.keys(instanceDocs);
                            }
                            
                            var setPendingUpdates = function(map1) {
                                pendingUpdatesMap = map1;
                            }
                            
                            var clearPendingUpdates = function() {
                                pendingUpdatesMap = null;
                            }
                            
                            var getPendingUpdates = function() {
                                return pendingUpdatesMap;
                            }
                            
                            var setUpdates = function(map1) {
                                updatesMap = map1;
                            }
                            
                            var clearUpdates = function() {
                                updatesMap = null;
                            }
                            
                            var getUpdates = function() {
                                return updatesMap;
                            }
                            
                            var addAction = function(name, value){
                                actions[name] = value;
                            }

                            var getAction = function(name){
                                return actions[name];
                            }
                            
                            var updateAction = function(actioni, key, value){
                                actioni[key] = value;
                                return actioni;
                            }
                            
                            var addSubmission = function(name, value){
                                submissions[name] = value;
                            }
                            
                            var getSubmission = function(name){
                                return submissions[name];
                            }     
                            
                            var addOutput = function(name, value){
                                outputs[name] = value;
                            }
                            
                            var getOutput = function(name){
                                return outputs[name];
                            }
                            
                            var getOutputKeys = function() {
                                return Object.keys(outputs);
                            }
                            
                            var setRelevantMap = function(map1) {
                                relevantMap = map1;                            
                            }
                            
                            var getRelevantMap = function() {
                                return relevantMap;
                            }
                            
  
                            var startTime = function(name) {
                                console.time(name);
                            }
                            
                            var endTime = function(name) {
                                console.timeEnd(name);
                            }
                            
                        </script>
                    </xsl:result-document>
                </xsl:for-each>

                <xsl:sequence select="js:setXFormsDoc($xforms-doc)"/>
                <xsl:sequence select="js:setDefaultInstance($default-instance)"/>
                <xsl:sequence select="js:setRelevantMap($RelevantBindings)" />
                
                <xsl:variable name="pendingInstanceUpdates" as="map(xs:string, xs:string)" select="map{}"/>       
                <xsl:variable name="instanceUpdates" as="map(xs:string, xs:string)" select="map{}"/>
                
                <xsl:sequence select="js:setPendingUpdates($pendingInstanceUpdates)"/>
                <xsl:sequence select="js:setUpdates($instanceUpdates)"/>
                
            </xsl:otherwise>
        </xsl:choose>

        
        <!-- add each instance to the Javascript variable -->
        <xsl:variable name="instanceKeys" select="map:keys($xforms-instances)" as="xs:string*"/>
        
        <xsl:for-each select="$instanceKeys">
            <xsl:variable name="instance" select="map:get($xforms-instances, .)" as="element()" />  
            <xsl:message use-when="$debugMode">Setting instance with ID '<xsl:value-of select="."/>'; instance = <xsl:value-of select="serialize($instance)"/></xsl:message>
            <xsl:sequence select="js:setInstance(.,$instance)"/>
        </xsl:for-each>
        

        <!-- register submissions in a map -->
        <xsl:variable name="submissions" as="map(xs:string, map(*))">
            <xsl:map>
                <xsl:for-each select="$xforms-doci/xforms:xform/xforms:model/xforms:submission">
                    <xsl:variable name="map-key" as="xs:string" select="
                        if (@id) then xs:string(@id)
                        else $default-submission-id
                        "/>
                    <xsl:variable name="map-value" as="map(*)">
                        <xsl:call-template name="setSubmission">
                            <xsl:with-param name="this" select="."/>
                            <xsl:with-param name="submission-id" select="$map-key"/>
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
            <xsl:message use-when="$debugMode">Setting submission with ID '<xsl:value-of select="."/>'</xsl:message>
            <xsl:sequence select="js:addSubmission(.,$submission)"/>
        </xsl:for-each>
        

        <xsl:variable name="time-id" select="generate-id()"/>
        <xsl:sequence use-when="$debugTiming" select="js:startTime(concat('XForms Main-Build', $time-id))" />
        
        <xsl:result-document href="#{$xFormsId}" method="ixsl:replace-content">
            <xsl:apply-templates select="$xforms-doci/xforms:xform">
                <xsl:with-param name="instances" select="$xforms-instances" as="map(xs:string, element())" tunnel="yes"/>
                <xsl:with-param name="bindings" select="$bindings" as="map(xs:string, node())" tunnel="yes"/>
                <xsl:with-param name="submissions" select="$submissions" as="map(xs:string, map(*))" tunnel="yes"/>
                <!-- clear nodeset when (re)building  -->
                <xsl:with-param name="nodeset" select="''" as="xs:string" tunnel="yes"/>
            </xsl:apply-templates>
        </xsl:result-document>
        
        <xsl:sequence use-when="$debugTiming" select="js:endTime(concat('XForms Main-Build', $time-id))" />

    </xsl:template>

    <xsl:function name="xforms:checkRelevantFields">
        <xsl:param name="refElement" as="xs:string" />
     
        <xsl:variable name="pendingUpdatesi" select="js:getPendingUpdates()" as="map(xs:string,xs:string)?"/>
        <xsl:variable name="pendingUpdateKeys" select="if(exists($pendingUpdatesi)) then map:keys($pendingUpdatesi) else ()"/>
        
        <xsl:variable name="updatesi" select="js:getUpdates()" as="map(xs:string,xs:string)?"/>
        <xsl:variable name="updateKeys" select="if(exists($updatesi)) then map:keys($updatesi) else ()"/>
        
        <xsl:message use-when="$debugMode">
            pendingKeys <xsl:value-of select="serialize($pendingUpdateKeys)"/>
        </xsl:message>
        
        <xsl:message use-when="$debugMode">
            UpdateKeys <xsl:value-of select="serialize($updateKeys)"/>
        </xsl:message>
        
        <xsl:variable name="relevantMap" select="js:getRelevantMap()" as="map(xs:string, xs:string)" />
        <xsl:variable name="mapKeys" select="map:keys($relevantMap)" as="item()*"/>
        
        <xsl:variable name="relevantFields" as="item()*">
            <xsl:for-each select="$mapKeys">
                <xsl:if test="matches(map:get($relevantMap, .), $refElement)">
                    <xsl:sequence select="." />
                </xsl:if>
                
            </xsl:for-each>
            
            <xsl:for-each select="$pendingUpdateKeys">
                <xsl:variable name="keyi" select="tokenize(., '/')[last()]"/>
                <xsl:for-each select="$mapKeys">
                    
                    <xsl:if test="matches(map:get($relevantMap, .), $keyi)">
                        <xsl:sequence select="." />
                    </xsl:if>
                    
                </xsl:for-each>
                
                
            </xsl:for-each>
            <xsl:for-each select="$updateKeys">
                <xsl:variable name="keyi" select="tokenize(., '/')[last()]"/>
                <xsl:for-each select="$mapKeys">
                    
                    <xsl:if test="matches(map:get($relevantMap, .), $keyi)">
                        <xsl:sequence select="." />
                    </xsl:if>
                </xsl:for-each> 
            </xsl:for-each>
        </xsl:variable>
        
       
        <xsl:message use-when="$debugMode">
            refi = <xsl:value-of select="$refElement" />
            
            
            relevant Fields, fields = <xsl:value-of select="serialize($relevantFields)"/>
            relevant Fields count = <xsl:value-of select="count($relevantFields)"/>
        </xsl:message>
        
         
        <xsl:for-each select="$relevantFields">
            <xsl:variable name="keyi" select="."/>
            <xsl:variable name="context" select="ixsl:page()//*[@data-ref = $keyi]"/>
            <xsl:variable name="updatedInstanceXML4" select="xforms:getInstance-JS($keyi)"/>
            
            <xsl:variable name="relevantCheck" as="xs:boolean">
                <xsl:evaluate xpath="concat(.,'/',map:get($relevantMap, .))" context-item="$updatedInstanceXML4" />
            </xsl:variable>
            <xsl:choose>
                <xsl:when test="$relevantCheck">
                    
                    <!--<ixsl:set-property name="type" select="if(exists(@data-type)) then string(@data-type) else 'text'" object="."/>-->
                    <ixsl:set-property name="style.display" select="'inline'" object="$context/.."/>
                </xsl:when>
                <xsl:otherwise>
                    <ixsl:set-property name="style.display" select="'none'" object="$context/.."/>
                </xsl:otherwise>
            </xsl:choose>
            
            
        </xsl:for-each>
        <xsl:sequence select="js:clearPendingUpdates()" />
        <xsl:sequence select="js:clearUpdates()" />
    </xsl:function>
    
    
    <xd:doc scope="component">
        <xd:desc>Handle incremental change to HTML input</xd:desc>
    </xd:doc>
    <xsl:template match="input[exists(@class) and xforms:hasClass(@class,'incremental')]" mode="ixsl:onkeyup">
        
        <xsl:call-template name="xforms-value-changed">
            <xsl:with-param name="form-control" select="."/>
        </xsl:call-template>
    </xsl:template>


    <xd:doc scope="component">
        <xd:desc>Handle change to HTML input</xd:desc>
    </xd:doc>
    <xsl:template match="input" mode="ixsl:onchange">
        <xsl:call-template name="xforms-value-changed">
            <xsl:with-param name="form-control" select="."/>
        </xsl:call-template>
    </xsl:template>
    
  
    <xd:doc scope="component">
        <xd:desc>Handle change to HTML select</xd:desc>
    </xd:doc>
    <xsl:template match="select" mode="ixsl:onchange">
        <xsl:call-template name="xforms-value-changed">
            <xsl:with-param name="form-control" select="."/>
        </xsl:call-template>
    </xsl:template>
    
    

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Function to get 'if' statemenmt from an action map</xd:p>
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
            <xsl:when test="$relative = ''">
                <xsl:sequence select="$base"/>
            </xsl:when>
            <xsl:otherwise>
                
                <xsl:variable name="parentCallCount" select="if(contains($relative, '/')) then count(tokenize($relative, '/')[. ='..']) else if(contains($relative, '..')) then 1 else 0"/>
                <xsl:variable name="slashes"
                    select="if(contains($base, '/')) then index-of(string-to-codepoints($base), string-to-codepoints('/')) else 0"
                    as="xs:integer*"/>
                
                <xsl:message use-when="$debugMode">resolveXPathString base =<xsl:value-of select="$base"/> 
                    relative <xsl:value-of select="$relative"/>
                    parentCallCount = <xsl:value-of select="$parentCallCount"/>
                    slashes = <xsl:value-of select="$slashes"/>
                </xsl:message>
                
                <xsl:variable name="parentSlash"
                    as="xs:integer">
                    <xsl:choose>
                        <xsl:when test="(count($slashes) >= $parentCallCount) and ($parentCallCount>0)">
                            <xsl:sequence select="$slashes[last() - ($parentCallCount - 1)]" />
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:sequence select="$slashes[last()]" />
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                
                <xsl:message use-when="$debugMode">[xforms:resolveXPathStrings] base =<xsl:value-of select="$base"/> 
                    lastSlash = <xsl:value-of select="$parentSlash"/> 
                    relative = <xsl:value-of select="$relative"/> 
                    countparent = <xsl:value-of select="$parentCallCount"/>
                    <xsl:if test="$parentCallCount > 0">
                        base without parent nodes = <xsl:value-of select="substring($base, 1, $parentSlash)" />
                        relativeCut = <xsl:value-of select="replace($relative, '\.\./', '')"/>
                    </xsl:if>
                    
                </xsl:message>
                
                <xsl:choose>
                    <xsl:when test="$parentCallCount gt 0">
                        <!-- TODO - need to resolve path. This does not work properly -->
                        <xsl:sequence
                            select="concat(substring($base, 1, $parentSlash), replace($relative, '\.\./', ''))"
                        />
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:sequence select="concat($base, '/', $relative)"/>
                    </xsl:otherwise>
                </xsl:choose>
                
            </xsl:otherwise>
        </xsl:choose>

    </xsl:function>



    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Check whether each required field is populated.</xd:p>
            <xd:p>TODO: check logic here</xd:p>
        </xd:desc>
        <xd:return>Sequence of each HTML field that is required</xd:return>
        <xd:param name="instanceXML">Instance to check</xd:param>
    </xd:doc>
    <xsl:function name="xforms:check-required-fields" as="item()*">
        <xsl:param name="instanceXML" as="element()"/>

        <xsl:variable name="required-fieldsi" select="ixsl:page()//*[@data-required]" as="item()*"/>

        <xsl:for-each select="$required-fieldsi">

            <xsl:variable name="resulti">
                <xsl:evaluate
                    xpath="concat('boolean(normalize-space(', @data-ref, '))', '=', @data-ref, '/', @data-required)"
                    context-item="$instanceXML"/>
            </xsl:variable>
            <xsl:sequence select="
                    if ($resulti = 'false') 
                    then .
                    else ()"
            />
        </xsl:for-each>

    </xsl:function>
    
    
    <xsl:function name="xforms:check-constraints-on-fields" as="item()*">
        <xsl:param name="updatedInstanceXML" as="document-node()"/>
        
        <xsl:variable name="constraint-fieldsi" select="ixsl:page()//*[@data-constraint]" as="item()*"/>
        
        
        
        <xsl:for-each select="$constraint-fieldsi">
            <xsl:variable name="contexti" as="node()">
                <xsl:evaluate xpath="@data-ref" context-item="$updatedInstanceXML"/>
            </xsl:variable>
            
            <xsl:variable name="resulti" as="xs:boolean">
                <xsl:evaluate
                    xpath="@data-constraint"
                    context-item="$contexti"/>
            </xsl:variable>
            <xsl:sequence
                select="
                if (not($resulti)) then
                .
                else
                ()"
            />
        </xsl:for-each>
        
        
        
    </xsl:function>



    <xd:doc scope="component">
        <xd:desc>Handle HTML submission</xd:desc>
    </xd:doc>
    <xsl:template match="button[exists(@data-submit)]" mode="ixsl:onclick">
        
        <xsl:call-template name="xforms-submit">
            <xsl:with-param name="form-control" select="."/>
        </xsl:call-template>

    </xsl:template>

    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template called by ixsl:schedule-action in template for xforms-submit event</xd:p>
        </xd:desc>
        <xd:param name="instance-id">Identifier of instance affected by submission</xd:param>
        <xd:param name="targetref">XPath to identify node within target instance</xd:param>
        <xd:param name="replace">String to identify whether to replace the node or just the text content</xd:param>
    </xd:doc>
    <xsl:template name="HTTPsubmit">
         <!-- The context item should be an 'HTTP response map' - i.e. our representation of an HTTP
            response as an XDM map.
           ?body is an XML document. -->
        <xsl:context-item as="map(*)" use="required"/>
        
        <xsl:param name="instance-id" as="xs:string" required="no" select="$default-instance-id"/>
        <xsl:param name="targetref" as="xs:string?" required="no"/>
        <xsl:param name="replace" as="xs:string?" required="no"/>
        
        <xsl:variable name="refi" as="xs:string" select="concat('instance(''', $instance-id, ''')/')"/>
        
        <xsl:variable name="responseXML" select="?body" as="document-node()"/>       
 
        <xsl:choose>
              <xsl:when test="empty($responseXML)">
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
                      <xsl:when test="$replace = 'instance'">
                          <xsl:sequence select="xforms:setInstance-JS($refi,$responseXML/*)"/>
                          
                          <xsl:call-template name="xforms-rebuild"/>
                         <xsl:message use-when="$debugMode">[HTTPsubmit] response body: <xsl:value-of select="serialize($responseXML)"/></xsl:message>
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
            <xsl:with-param name="xforms-doc" select="." />
            <xsl:with-param name="xFormsId" select="$xform-html-id" />
        </xsl:call-template>
    </xsl:template>

    <!--    <xsl:template name="generate-xform">
        <xsl:param name="xform-src"/>
        <xsl:apply-templates select="$xform-src" />
        
    </xsl:template>-->


    <xd:doc scope="component">
        <xd:desc>Template to (re)render entire page. REDUNDANT? [MD 2018]</xd:desc>
    </xd:doc>
    <xsl:template match="xhtml:html | html">
        <html>
            <xsl:copy-of select="@*"/>
            <head>
                <xsl:copy-of select="xhtml:head/@* | head/@*"/>
                <meta http-equiv="Content-Type" content="text/html;charset=utf-8"/>
                <xsl:for-each
                    select="xhtml:head/xhtml:meta[string(@http-equiv) != 'Content-Type'] | head/meta[string(@http-equiv) != 'Content-Type']">
                    <meta>
                        <xsl:copy-of select="@*"/>
                    </meta>
                </xsl:for-each>


                <xsl:copy-of select="script"/>
            </head>
            <body>
                <xsl:apply-templates select="body/*"/>
            </body>

        </html>

    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of XForms <a href="https://www.w3.org/TR/xforms11/#ui-output">output element</a>  </xd:p>          
            <xd:p>Generates HTML output field and registers actions.</xd:p>
        </xd:desc>
        <xd:param name="position">Integer representing position of item (in a repeat list for example).</xd:param>
    </xd:doc>
    <xsl:template match="xforms:output">
        <xsl:param name="position" as="xs:integer" required="no" select="0"/>

        <xsl:variable name="myid" as="xs:string"
            select=" if (exists(@id)) then @id else concat(generate-id(), '-', $position )"/>
        
         
        <!-- get xforms:bind element relevant to this -->
        <xsl:variable name="bindingi" as="node()?">
            <xsl:call-template name="getBinding">
                <xsl:with-param name="this" select="."/>
            </xsl:call-template>
        </xsl:variable>
                
        <!-- get XPath binding expression relevant to this -->
        <xsl:variable name="refi" as="xs:string">
            <xsl:call-template name="getDataRef">
                <xsl:with-param name="this" select="."/>
                <xsl:with-param name="bindingi" select="$bindingi"/>
            </xsl:call-template>
        </xsl:variable>
                
        <!-- identify instance field corresponding to this output -->
        <xsl:variable name="instanceField" as="node()?">
            <xsl:call-template name="getReferencedInstanceField">
                <xsl:with-param name="refi" select="$refi"/>
            </xsl:call-template>
        </xsl:variable>
                
        <xsl:variable name="valueExecuted" as="xs:string">
            <xsl:choose>
                <xsl:when test="exists(@value)">
                    <xsl:evaluate xpath="xforms:impose(@value)" context-item="$instanceField" as="xs:string" /> 
                    <xsl:message use-when="$debugMode">[xforms:output] xforms-imposed xpath = '<xsl:value-of select="xforms:impose(@value)"/>'</xsl:message>
                    
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="$instanceField"/>
                </xsl:otherwise>
            </xsl:choose>
            
        </xsl:variable>
        
        <xsl:variable name="relevantVar" as="xs:boolean">
            <xsl:choose>
                <xsl:when test="exists($bindingi) and exists($bindingi/@relevant) and exists($instanceField)">
                    <xsl:evaluate xpath="xforms:impose($bindingi/@relevant)" context-item="$instanceField"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="true()"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        


        <!-- GENERATE HTML -->
        <div>
            <xsl:variable name="class" as="xs:string?">
                <xsl:if test="exists(@class)">
                    <xsl:value-of select="@class"/>
                </xsl:if>
            </xsl:variable>
            <xsl:variable name="class-mod" as="xs:string?">
                <xsl:choose>
                    <xsl:when test="exists(@incremental)">
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
            
            <xsl:apply-templates select="xforms:label"/>
            
        <span>
            <xsl:attribute name="id" select="$myid"/>
            <xsl:attribute name="style" select="if($relevantVar) then 'display:inline' else 'display:none'" />
            <xsl:attribute name="data-ref" select="$refi"/>
 
            <xsl:sequence select="$valueExecuted" />
        </span>
        </div>
        
        <!-- register outputs -->
        <xsl:variable name="output-map" as="map(*)">
            <xsl:map>
                <xsl:if test="$refi != ''">
                    <xsl:map-entry key="'@ref'" select="xs:string($refi)" />
                </xsl:if>
                
                <xsl:if test="exists(@value)">
                    <xsl:map-entry key="'@value'" select="xs:string(@value)" />
                </xsl:if>
            </xsl:map>
        </xsl:variable>
        
        <xsl:sequence select="js:addOutput($myid , $output-map)" />
        
        <xsl:message use-when="$debugMode">[xforms:output] id = '<xsl:value-of select="$myid"/>', output-map = '<xsl:value-of select="serialize($output-map)"/>'</xsl:message>
        
    </xsl:template>

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of XForms <a href="https://www.w3.org/TR/xforms11/#ui-input">input element</a></xd:p>
            <xd:p>Generates HTML input field and registers actions.</xd:p>
        </xd:desc>
        <xd:param name="position">Integer representing position of item (in a repeat list for example).</xd:param>
    </xd:doc>
    <xsl:template match="xforms:input">
        <xsl:param name="position" as="xs:integer" required="no" select="0"/>

        <xsl:variable name="myid" as="xs:string"
            select=" if (exists(@id)) then @id else concat(generate-id(), '-', $position )"/>
        
        <xsl:variable name="time-id" as="xs:string" select="generate-id()"/>
        <xsl:sequence use-when="$debugTiming" select="js:startTime(concat('XForms-input-', $time-id))" />
                      
        <!-- get xforms:bind element relevant to this -->
        <xsl:variable name="bindingi" as="node()?">
            <xsl:call-template name="getBinding">
                <xsl:with-param name="this" select="."/>
            </xsl:call-template>
        </xsl:variable>
        
        <!-- get XPath binding expression relevant to this -->
        <xsl:variable name="refi" as="xs:string">
            <xsl:call-template name="getDataRef">
                <xsl:with-param name="this" select="."/>
                <xsl:with-param name="bindingi" select="$bindingi"/>
            </xsl:call-template>
        </xsl:variable>
        
        <!-- identify instance field corresponding to this -->
        <xsl:variable name="instanceField" as="node()?">
            <xsl:call-template name="getReferencedInstanceField">
                <xsl:with-param name="refi" select="$refi"/>
            </xsl:call-template>
        </xsl:variable>
               

        <!-- check whether this input is relevant -->
        <xsl:variable name="relevantVar" as="xs:boolean">
            <xsl:choose>
                <xsl:when test="exists($bindingi) and exists($bindingi/@relevant) and exists($instanceField)">
                    <xsl:evaluate xpath="xforms:impose($bindingi/@relevant)" context-item="$instanceField"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="true()"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <!-- set actions relevant to this -->
        <xsl:variable name="actions"  as="map(*)*">
            <xsl:call-template name="setActions">
                <xsl:with-param name="this" select="."/>
                <xsl:with-param name="nodeset" select="$refi" tunnel="yes"/>
            </xsl:call-template>
        </xsl:variable>
                
        <xsl:if test="exists($actions)">
            <xsl:sequence select="js:addAction($myid, $actions)" />
        </xsl:if>
        
        
        <!-- GENERATE HTML -->
        <div>
            <xsl:variable name="class" as="xs:string?">
                <xsl:if test="exists(@class)">
                    <xsl:value-of select="@class"/>
                </xsl:if>
            </xsl:variable>
            <xsl:variable name="class-mod" as="xs:string?">
                <xsl:choose>
                    <xsl:when test="exists(@incremental)">
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
            
            <span>
                <xsl:attribute name="style" select="if($relevantVar) then 'display:inline' else 'display:none'" />
                
                <xsl:apply-templates select="xforms:label"/>
                
                <xsl:variable name="hints" select="xforms:hint/text()"/>
                
                <xsl:variable name="refElement" select="tokenize($refi, '/')[last()]"/>
                
                <input>
                    <xsl:if test="exists(@incremental)">
                        <xsl:attribute name="class" select="'incremental'"/>
                    </xsl:if>
                    
                    <xsl:attribute name="data-ref" select="$refi"/>
                    <xsl:attribute name="data-element" select="$refElement" />
                    
                    <xsl:if test="exists($bindingi) and exists($bindingi/@required)">
                        <xsl:attribute name="data-required" select="$bindingi/@required"/>
                    </xsl:if>
                    <xsl:if test="exists($bindingi) and exists($bindingi/@constraint)">
                        <xsl:attribute name="data-constraint" select="$bindingi/@constraint"/>
                    </xsl:if>
                    <xsl:if test="exists($actions)">
                        <xsl:attribute name="data-action" select="$myid"/>
                    </xsl:if>
                    
                    <xsl:if test="exists($bindingi) and exists($bindingi/@relevant)">
                        <xsl:attribute name="data-relevant" select="$bindingi/@relevant"/>
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
                            if (exists($bindingi)) then
                            xs:QName($bindingi/@type) eq xs:QName('xs:date')
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
                            if (exists($bindingi)) then
                            xs:QName($bindingi/@type) eq xs:QName('xs:time')
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
                            if (exists($bindingi)) then
                            xs:QName($bindingi/@type) eq xs:QName('xs:boolean')
                            else
                            false()">
                            <xsl:attribute name="data-type" select="'checkbox'"/>
                            <!--<xsl:if test="$relevantVar">-->
                            <xsl:attribute name="type" select="'checkbox'"/>
                            <!--</xsl:if>-->
                            
                            
                            <!-- MD 2018: check this works -->
                            <xsl:if test="exists($instanceField)">
                                <xsl:message use-when="$debugMode"><xsl:value-of select="$bindingi/@nodeset"/>, value = <xsl:value-of select="serialize($input-value)"/></xsl:message>
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
                    
                    <xsl:if test="exists($hints)">
                        <xsl:attribute name="title" select="$hints"/>
                    </xsl:if>
                    <xsl:if test="exists(@size)">
                        <xsl:attribute name="size" select="@size"/>
                    </xsl:if>
                </input>
            </span>
        </div>
        
        <xsl:sequence use-when="$debugTiming" select="js:endTime(concat('XForms-input', $time-id))" />
        
    </xsl:template>


    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of XForms <a href="https://www.w3.org/TR/xforms11/#ui-textarea">textarea element</a>  </xd:p>          
            <xd:p>Generates HTML output field and registers actions.</xd:p>
        </xd:desc>
        <xd:param name="position">Integer representing position of item (in a repeat list for example).</xd:param>
    </xd:doc>
    <xsl:template match="xforms:textarea" priority="2">
        <xsl:param name="position" as="xs:integer" required="no" select="0"/>
        
        <xsl:variable name="myid" as="xs:string"
            select=" if (exists(@id)) then @id else concat(generate-id(), '-', $position )"/>
                
        <!-- get xforms:bind element relevant to this -->
        <xsl:variable name="bindingi" as="node()?">
            <xsl:call-template name="getBinding">
                <xsl:with-param name="this" select="."/>
            </xsl:call-template>
        </xsl:variable>               
        
        <!-- get XPath binding expression relevant to this -->
        <xsl:variable name="refi" as="xs:string">
            <xsl:call-template name="getDataRef">
                <xsl:with-param name="this" select="."/>
                <xsl:with-param name="bindingi" select="$bindingi"/>
            </xsl:call-template>
        </xsl:variable>        
        
        <!-- identify instance field corresponding to this  -->
        <xsl:variable name="instanceField" as="node()?">
            <xsl:call-template name="getReferencedInstanceField">
                <xsl:with-param name="refi" select="$refi"/>
            </xsl:call-template>
        </xsl:variable>
               
        <!-- set actions relevant to this -->
        <xsl:variable name="actions"  as="map(*)*">
            <xsl:call-template name="setActions">
                <xsl:with-param name="this" select="."/>
                <xsl:with-param name="nodeset" select="$refi" tunnel="yes"/>
            </xsl:call-template>
        </xsl:variable>
        
        <xsl:if test="exists($actions)">
            <xsl:sequence select="js:addAction($myid, $actions)" />
        </xsl:if>
        
        <xsl:variable name="refElement" select="tokenize($refi, '/')[last()]"/>

        <xsl:variable name="hints" select="xforms:hint/text()"/>
        
        <textarea>
            <xsl:copy-of select="@*[local-name() != 'ref']"/>
            <xsl:attribute name="data-element" select="$refElement" />
            <xsl:attribute name="data-ref" select="$refi"/>
            <xsl:choose>
                <xsl:when test="exists($instanceField)">
                    <xsl:value-of select="$instanceField"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:text/>&#xA0; </xsl:otherwise>
            </xsl:choose>
            <xsl:if test="exists($hints)">
                <xsl:attribute name="title" select="$hints"/>
            </xsl:if>
        </textarea>
        
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
        <xd:param name="position">Integer representing position of item (in a repeat list for example).</xd:param>
    </xd:doc>
    <xsl:template match="xforms:select1 | xforms:select">
        <xsl:param name="position" as="xs:integer" required="no" select="0"/>

        <xsl:variable name="myid" as="xs:string"
            select=" if (exists(@id)) then @id else concat(generate-id(), '-', $position )"/>
        
        <xsl:variable name="time-id" select="generate-id()"/>
        <xsl:sequence use-when="$debugTiming" select="js:startTime(concat('XForms-select', $time-id))" />

        <!-- get xforms:bind element relevant to this -->
        <xsl:variable name="bindingi" as="node()?">
            <xsl:call-template name="getBinding">
                <xsl:with-param name="this" select="."/>
            </xsl:call-template>
        </xsl:variable>
        
        <!-- get XPath binding expression relevant to this -->
        <xsl:variable name="refi" as="xs:string">
            <xsl:call-template name="getDataRef">
                <xsl:with-param name="this" select="."/>
                <xsl:with-param name="bindingi" select="$bindingi"/>
            </xsl:call-template>
        </xsl:variable>
                
        <!-- identify instance field corresponding to this -->
        <xsl:variable name="instanceField" as="node()?">
            <xsl:call-template name="getReferencedInstanceField">
                <xsl:with-param name="refi" select="$refi"/>
            </xsl:call-template>
        </xsl:variable>
        
        <!-- set actions relevant to this -->
        <xsl:variable name="actions"  as="map(*)*">
            <xsl:call-template name="setActions">
                <xsl:with-param name="this" select="."/>
                <xsl:with-param name="nodeset" select="$refi" tunnel="yes"/>
            </xsl:call-template>
        </xsl:variable>
        
        <xsl:if test="exists($actions)">
            <xsl:sequence select="js:addAction($myid, $actions)" /> 
        </xsl:if>
        
        
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
        
        <xsl:message use-when="$debugMode">[xforms:select] selected value = <xsl:value-of select="$selectedValue"/></xsl:message>
        
                 
        <xsl:variable name="refElement" select="tokenize($refi, '/')[last()]"/>
        
        <xsl:apply-templates select="xforms:label"/>

        <span>
            <xsl:attribute name="style" select="'display:inline'" />
            <select>
                <xsl:copy-of select="@*[local-name() != 'ref']"/>
                
                <xsl:attribute name="data-ref" select="$refi"/>
                <xsl:attribute name="data-element" select="$refElement" />
                
                <xsl:if test="exists($bindingi) and exists($bindingi/@constraint)">
                    <xsl:attribute name="data-constraint" select="$bindingi/@constraint"/>
                </xsl:if>
                
                <xsl:if test="local-name() = 'select'">
                    <xsl:attribute name="multiple">true</xsl:attribute>
                    <xsl:attribute name="size">
                      <xsl:value-of select="count(descendant::xforms:item)"/>
                    </xsl:attribute>
                </xsl:if>
                <xsl:if test="exists($actions)">
                    <xsl:attribute name="data-action" select="$myid"/>
                </xsl:if>
                
                <xsl:apply-templates select="xforms:item">
                    <xsl:with-param name="selectedValue" select="$selectedValue"/>
                </xsl:apply-templates>
            
            </select>
        </span>
        
        
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
        
<!--        <xsl:message use-when="$debugMode">[xforms:item] comparing value '<xsl:value-of select="xforms:value/text()"/>' against selected value '<xsl:value-of select="$selectedValue"/>'</xsl:message>-->

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
            <xd:p>Generates an HTML div and passes @ref or @nodeset to descendants.</xd:p></xd:desc>
    </xd:doc>
    <xsl:template match="xforms:group">
        
        <xsl:variable name="refi" as="xs:string?">
            <xsl:choose>
                <xsl:when test="exists(@nodeset)"><xsl:sequence select="@nodeset" /></xsl:when>
                <xsl:when test="exists(@ref)"><xsl:sequence select="@ref" /></xsl:when>
                <xsl:otherwise/>
            </xsl:choose>
        </xsl:variable>
        
        <div>
            <xsl:if test="exists($refi)">
                <xsl:attribute name="data-group-ref" select="$refi" />
            </xsl:if>
            <xsl:if test="exists(@id)">
                <xsl:attribute name="id" select="@id"/>
            </xsl:if>
            <xsl:apply-templates select="child::*">
                <xsl:with-param name="nodeset" select="if(exists($refi))then $refi else ''" tunnel="yes"/>
            </xsl:apply-templates>
        </div>
    </xsl:template>
    
    

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of XForms <a href="https://www.w3.org/TR/xforms11/#ui-repeat">repeat element</a></xd:p>
            <xd:p>Generates HTML div and iterates over items within.</xd:p>
        </xd:desc>
        <xd:param name="position">Integer representing position of item (in a repeat list for example).</xd:param>
    </xd:doc>
    <xsl:template match="xforms:repeat">
        <xsl:param name="position" as="xs:integer" required="no" select="0"/>
        
        <xsl:variable name="myid" as="xs:string"
            select=" if (exists(@id)) then @id else concat(generate-id(), '-', $position )"/>
        
        <xsl:variable name="time-id" select="generate-id()"/>
        <xsl:sequence use-when="$debugTiming" select="js:startTime(concat('XForms-repeat', $time-id))" />
      
        <!-- get xforms:bind element relevant to this -->
        <xsl:variable name="bindingi" as="node()?">
            <xsl:call-template name="getBinding">
                <xsl:with-param name="this" select="."/>
            </xsl:call-template>
        </xsl:variable>

        <!-- get XPath binding expression relevant to this -->
        <xsl:variable name="refi" as="xs:string">
            <xsl:call-template name="getDataRef">
                <xsl:with-param name="this" select="."/>
                <xsl:with-param name="bindingi" select="$bindingi"/>
            </xsl:call-template>
        </xsl:variable>
        
        
        <!-- identify instance fields corresponding to this -->
        <xsl:variable name="selectedRepeatVar" as="element()*">
            <xsl:sequence use-when="$debugTiming" select="js:startTime(concat('XForms-repeat-evaluate', $time-id))" />
            <xsl:call-template name="getReferencedInstanceField">
                <xsl:with-param name="refi" select="$refi"/>
            </xsl:call-template>
            <xsl:sequence use-when="$debugTiming" select="js:endTime(concat('XForms-repeat-evaluate', $time-id))" />
        </xsl:variable>
        
        <xsl:message use-when="$debugMode">
            <xsl:choose>
                <xsl:when test="exists($selectedRepeatVar)">
                    [xforms:repeat] ref = <xsl:sequence select="$refi" />
                    count = <xsl:sequence select="count($selectedRepeatVar)" />
                </xsl:when>
                <xsl:otherwise>[xforms:repeat] No repeat found for ref <xsl:sequence select="$refi" /></xsl:otherwise>
            </xsl:choose>
        </xsl:message>
           
        <xsl:if test="exists($selectedRepeatVar)">
            <div>
                <xsl:attribute name="data-repeatable-context" select="$refi" />
                <xsl:attribute name="data-count" select="count($selectedRepeatVar)" />
                <xsl:attribute name="id" select="$myid"/>
                <xsl:variable name="xf-repeat" select="." as="element(xforms:repeat)"/>
                <xsl:for-each select="$selectedRepeatVar">
                    <div data-repeat-item="true">
                        <xsl:apply-templates select="$xf-repeat/child::*">
                            <xsl:with-param name="nodeset" select="concat($refi, '[', position(), ']')" tunnel="yes"/>
                            <xsl:with-param name="position" select="position()"/>
                        </xsl:apply-templates>
                    </div>
                </xsl:for-each>
            </div>
        </xsl:if>
        
        <xsl:sequence use-when="$debugTiming" select="js:endTime(concat('XForms-repeat', $time-id))" />

    </xsl:template>

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for xforms:submit element.</xd:p>
        </xd:desc>
        <xd:param name="submissions">Map of submissions.</xd:param>
    </xd:doc>
    <xsl:template match="xforms:submit">
        <xsl:param name="submissions" select="map{}" as="map(xs:string, map(*))" tunnel="yes"/>
        
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
                    <xsl:if test="exists(@submission) and map:contains($submissions, @submission)">
                        <xsl:attribute name="data-submit" select="@submission"/>
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
        <xd:param name="insert-node">Node to be cloned</xd:param>
        <xd:param name="position-relative">"before" or "after"</xd:param>
    </xd:doc>
    <xsl:template match="*" mode="insert-node">
        <xsl:param name="insert-node" as="node()" tunnel="yes"/>
        <xsl:param name="position-relative" as="xs:string?" select="'after'" required="no" tunnel="yes"/>
        
        
        <xsl:if test=". is $insert-node and $position-relative = 'before'">
            <xsl:message>[insert-node mode] Found! <xsl:value-of select="serialize($insert-node)"/></xsl:message>
            <xsl:copy-of select="$insert-node"/>
        </xsl:if>
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates select="node()" mode="insert-node"/>
        </xsl:copy>
        <xsl:if test=". is $insert-node and $position-relative = 'after'">
            <xsl:copy-of select="$insert-node"/>
        </xsl:if>
        
    </xsl:template>


    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for updating instance XML based on node deleted with xforms:delete control</xd:p>
        </xd:desc>
        <xd:param name="delete-node">Node to be deleted</xd:param>
     </xd:doc>
    <xsl:template match="*" mode="delete-node">
        <xsl:param name="delete-node" as="node()" tunnel="yes"/>
        
        <xsl:choose>
            <xsl:when test=". is $delete-node">
                <xsl:message>[delete-node mode] Found! <xsl:value-of select="serialize($delete-node)"/></xsl:message>
                
            <!-- deleting controls from the xform -->
             <!--   <xsl:for-each
                    select="ixsl:page()//*[@data-ref = $path]/..">
                    
                    <xsl:result-document href="?." method="ixsl:replace-content">
                        
                    </xsl:result-document>
                </xsl:for-each>-->
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy>
                    <xsl:copy-of select="@*"/>
                    <xsl:apply-templates select="node()" mode="delete-node"/>
                </xsl:copy>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="@data-action" mode="update-ref" priority="2" >
        <xsl:param name="path" as="xs:string" select="''" />
        <xsl:param name="position" select="0" />
        
        <xsl:variable name="myid" select="concat(generate-id(),$position)" />
            
        <xsl:attribute name="data-old-action" select="." />
            
        <xsl:attribute name="data-action" >
            <xsl:value-of select="if(exists(ixsl:page()/*[data-action=$myid])) then concat(generate-id(),generate-id()) else $myid"/>
        </xsl:attribute>
        
    </xsl:template>

     <xsl:template match="@*" mode="update-ref" >
        <xsl:param name="path" as="xs:string" select="''" />
        <xsl:param name="position" select="0" />
        <xsl:variable name="name" select="name()"/>
        <xsl:variable name="path-updated" select="if ($position > 0) then concat($path, '[',$position,']') else $path"/>
        <xsl:variable name="str-length" select="string-length($path)"/>
         
        <xsl:choose>
            <xsl:when test="substring(.,1, $str-length) = $path">
                <xsl:attribute name="{$name}" >
                    <xsl:value-of select="concat($path-updated,substring(.,string-length($path-updated)+1))"/>
                </xsl:attribute>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy-of select="." />
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="*" mode="update-ref" >
        <xsl:param name="path" as="xs:string" select="''" />
        <xsl:param name="position" select="0" />
        
        <xsl:copy>
            <xsl:apply-templates select="@*|node()" mode="update-ref" >
                <xsl:with-param name="path" select="$path" />
                <xsl:with-param name="position" select="$position"/>
            </xsl:apply-templates>
        </xsl:copy>
        
    </xsl:template> 

 
    <xd:doc scope="component">
        <xd:desc>Handle HTML button click</xd:desc>
    </xd:doc>
    <xsl:template match="button[exists(@data-action)]" mode="ixsl:onclick">
        
        <xsl:call-template name="DOMActivate">
            <xsl:with-param name="form-control" select="."/>
        </xsl:call-template>
        
    </xsl:template>



    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of XForms <a href="https://www.w3.org/TR/xforms11/#ui-trigger">trigger element</a></xd:p>
            <xd:p>Generates HTML link or button and registers actions.</xd:p>
        </xd:desc>
        <xd:param name="position">Integer representing position of item (in a repeat list for example).</xd:param>
    </xd:doc>
    <xsl:template match="xforms:trigger">
        <xsl:param name="position" as="xs:integer" required="no" select="0"/>
        
        <xsl:variable name="myid" as="xs:string"
            select=" if (exists(@id)) then @id else concat(generate-id(), '-', $position )"/>
        
        <!-- get xforms:bind element relevant to this -->
        <xsl:variable name="bindingi" as="node()?">
            <xsl:call-template name="getBinding">
                <xsl:with-param name="this" select="."/>
            </xsl:call-template>
        </xsl:variable>                
        
        <!-- get XPath binding expression relevant to this -->
        <xsl:variable name="refi" as="xs:string">
            <xsl:call-template name="getDataRef">
                <xsl:with-param name="this" select="."/>
                <xsl:with-param name="bindingi" select="$bindingi"/>
            </xsl:call-template>
        </xsl:variable>
               
        <!-- set actions relevant to this -->
        <xsl:variable name="actions"  as="map(*)*">
            <xsl:call-template name="setActions">
                <xsl:with-param name="this" select="."/>
                <xsl:with-param name="nodeset" select="$refi" tunnel="yes"/>
            </xsl:call-template>
        </xsl:variable>
        
        <xsl:if test="exists($actions)">
            <xsl:sequence select="js:addAction($myid, $actions)" />
        </xsl:if>

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
                
                <xsl:attribute name="data-ref" select="$refi"/>
                <xsl:attribute name="data-action" select="$myid"/>
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
    <xsl:template match="xforms:action | xforms:*[local-name() = $xforms-actions] | xforms:show | xforms:hide | xforms:script | xforms:unload">
        <xsl:variable name="myid"
            select="
            if (exists(@id)) 
            then @id
            else generate-id()"/>
        
        <xsl:variable name="time-id" select="generate-id()"/>
        <xsl:sequence use-when="$debugTiming" select="js:startTime(concat('XForms-action', $time-id))" />        
  
        <xsl:variable name="action-map" as="map(*)">
            <xsl:call-template name="setAction">
                <xsl:with-param name="this" select="."/>
            </xsl:call-template>
        </xsl:variable>
        
<!--        <xsl:message use-when="$debugMode">
            [XForms Action] found action!
            node       = <xsl:value-of select="serialize(.)"/>, 
            id         = <xsl:value-of select="@id"/>,
            myid       = <xsl:value-of select="$myid"/>, 
            action map = <xsl:value-of select="serialize($action-map)"/>
        </xsl:message>
-->
        <xsl:if test="exists($action-map)">
            <xsl:sequence select="$action-map" />
        </xsl:if>

        <xsl:sequence use-when="$debugTiming" select="js:endTime(concat('XForms-action', $time-id))" />
    </xsl:template>
    
    

    
    <!-- mode="xforms-action" REDUNDANT? MD 2018-07-01 -->

    <xsl:template match="xforms:insert" mode="xforms-action">
        <xsl:param name="nodeset" select="''" tunnel="yes"/>
        <insert>
            <xsl:if test="exists(@ref)">
                <xsl:element name="ref">
                    <xsl:choose>
                        <xsl:when test="@nodeset = '.'">
                            <xsl:value-of select="$nodeset"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="@ref"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:element>
            </xsl:if>
            <xsl:if test="exists(@nodeset)">
                <xsl:element name="ref">
                    <xsl:choose>
                        <xsl:when test="@nodeset = '.'">
                            <xsl:value-of select="$nodeset"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="@nodeset"/>
                        </xsl:otherwise>
                    </xsl:choose>

                </xsl:element>
            </xsl:if>
            <xsl:if test="exists(@position)">
                <xsl:element name="position">
                    <xsl:value-of select="@position"/>
                </xsl:element>
            </xsl:if>
            <xsl:if test="exists(@at)">
                <xsl:element name="at">
                    <xsl:value-of select="@at"/>
                </xsl:element>
            </xsl:if>
            <xsl:if test="exists(@if)">
                <xsl:element name="if">
                    <xsl:value-of select="@if"/>
                </xsl:element>
            </xsl:if>
            <xsl:if test="exists(@while)">
                <xsl:element name="while">
                    <xsl:value-of select="@while"/>
                </xsl:element>
            </xsl:if>
        </insert>
    </xsl:template>

    <xsl:template match="xforms:delete" mode="xforms-action">
        <xsl:param name="nodeset" select="''" tunnel="yes"/>
        <delete>
            <xsl:if test="exists(@ref)">
                <xsl:element name="ref">
                    <xsl:choose>
                        <xsl:when test="@nodeset = '.'">
                            <xsl:value-of select="$nodeset"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="@ref"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:element>
            </xsl:if>
            <xsl:if test="exists(@nodeset)">
                <xsl:element name="ref">
                    <xsl:choose>
                        <xsl:when test="@nodeset = '.'">
                            <xsl:value-of select="$nodeset"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="@nodeset"/>
                        </xsl:otherwise>
                    </xsl:choose>

                </xsl:element>
            </xsl:if>
            <xsl:if test="exists(@position)">
                <xsl:element name="position">
                    <xsl:value-of select="@position"/>
                </xsl:element>
            </xsl:if>
            <xsl:if test="exists(@at)">
                <xsl:element name="at">
                    <xsl:value-of select="@at"/>
                </xsl:element>
            </xsl:if>
            <xsl:if test="exists(@if)">
                <xsl:element name="if">
                    <xsl:value-of select="@if"/>
                </xsl:element>
            </xsl:if>
            <xsl:if test="exists(@while)">
                <xsl:element name="while">
                    <xsl:value-of select="@while"/>
                </xsl:element>
            </xsl:if>
        </delete>
    </xsl:template>

    <xsl:template match="xforms:setvalue" mode="xforms-action">
        <xsl:param name="nodeset" select="''" tunnel="yes"/>
        <xsl:message use-when="$debugMode">setvalue ZZZ= <xsl:value-of select="serialize(.)"
            /></xsl:message>
        <setvalue>
            <xsl:if test="exists(@value)">
                <xsl:attribute name="value">
                    <xsl:value-of select="@value"/>
                </xsl:attribute>
            </xsl:if>
            <xsl:if test="exists(@ref)">
                <xsl:element name="ref">
                    <xsl:choose>
                        <xsl:when test="@nodeset = '.'">
                            <xsl:value-of select="$nodeset"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="@ref"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:element>
            </xsl:if>
            <xsl:if test="exists(@nodeset)">
                <xsl:element name="ref">
                    <xsl:choose>
                        <xsl:when test="@nodeset = '.'">
                            <xsl:value-of select="$nodeset"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="@nodeset"/>
                        </xsl:otherwise>
                    </xsl:choose>

                </xsl:element>
            </xsl:if>
            <xsl:if test="exists(@position)">
                <xsl:element name="position">
                    <xsl:value-of select="@position"/>
                </xsl:element>
            </xsl:if>
            <xsl:if test="exists(@at)">
                <xsl:element name="at">
                    <xsl:value-of select="@at"/>
                </xsl:element>
            </xsl:if>
            <xsl:if test="exists(@if)">
                <xsl:element name="if">
                    <xsl:value-of select="@if"/>
                </xsl:element>
            </xsl:if>
            <xsl:if test="exists(@while)">
                <xsl:element name="while">
                    <xsl:value-of select="@while"/>
                </xsl:element>
            </xsl:if>
            
            <xsl:if test="exists(./text())">
                <xsl:element name="value">
                    <xsl:value-of select="."/>
                </xsl:element>

            </xsl:if>
        </setvalue>
    </xsl:template>

    <xsl:template match="xforms:reset" mode="xforms-action">
        <xsl:param name="nodeset" select="''" tunnel="yes"/>
        <reset>
            <xsl:if test="exists(@ref)">
                <xsl:element name="ref">
                    <xsl:choose>
                        <xsl:when test="@nodeset = '.'">
                            <xsl:value-of select="$nodeset"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="@ref"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:element>
            </xsl:if>
            <xsl:if test="exists(@nodeset)">
                <xsl:element name="ref">
                    <xsl:choose>
                        <xsl:when test="@nodeset = '.'">
                            <xsl:value-of select="$nodeset"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="@nodeset"/>
                        </xsl:otherwise>
                    </xsl:choose>

                </xsl:element>
            </xsl:if>
            <xsl:if test="exists(@position)">
                <xsl:element name="position">
                    <xsl:value-of select="@position"/>
                </xsl:element>
            </xsl:if>
            <xsl:if test="exists(@at)">
                <xsl:element name="at">
                    <xsl:value-of select="@at"/>
                </xsl:element>
            </xsl:if>
            <xsl:if test="exists(@if)">
                <xsl:element name="if">
                    <xsl:value-of select="@if"/>
                </xsl:element>
            </xsl:if>
            <xsl:if test="exists(@while)">
                <xsl:element name="while">
                    <xsl:value-of select="@while"/>
                </xsl:element>
            </xsl:if>
            <xsl:if test="exists(@*:event)">
                <xsl:element name="event">
                    <xsl:value-of select="@*:event"/>
                </xsl:element>
            </xsl:if>
        </reset>
    </xsl:template>
    
    
    
    <!-- action-to-map -->
    
    
    <xd:doc scope="component">
        <xd:desc>Template for XForms Action elements nested within others (e.g. xforms:action, xforms:setvalue)</xd:desc>
        <xd:param name="nodeset">XPath identifying instance node(s) affected by the XForms Action element.</xd:param>
    </xd:doc>
    <xsl:template match="xforms:*[local-name() = $xforms-actions]" mode="xforms-action-map">
        
        <xsl:param name="nodeset" select="''" tunnel="yes"/>        
        
        <xsl:map-entry key="local-name()">
           <xsl:variable name="array" as="map(*)*">
               <xsl:for-each select="current-group()">
                   <xsl:apply-templates select="." mode="#default"/>
               </xsl:for-each>
           </xsl:variable>
           <xsl:sequence select="array{$array}" />
       </xsl:map-entry>
        
    </xsl:template>
    
    

    <xsl:function name="xforms:convert-xml-to-jxml" as="node()" exclude-result-prefixes="#all">
        <xsl:param name="xinstance" as="node()"/>
        <xsl:variable name="rep-xml">
            <xsl:element name="map" namespace="http://www.w3.org/2005/xpath-functions">
                <xsl:apply-templates select="$xinstance" mode="json-xml"/>
            </xsl:element>
        </xsl:variable>
        <xsl:sequence select="$rep-xml"/>
    </xsl:function>


    <xsl:template match="*" mode="json-xml">

        <xsl:choose>
            <!-- TODO handle attributes??? -->
            <!--<xsl:when test="attribute()"></xsl:when>-->
            <xsl:when test="count(*) > 0">
                <xsl:for-each-group select="* | @*" group-by="local-name()">
                    <xsl:choose>
                        <xsl:when test="count(current-group()) > 1">
                            <xsl:element name="array"
                                namespace="http://www.w3.org/2005/xpath-functions">
                                <xsl:attribute name="key" select="current-grouping-key()"/>
                                <xsl:for-each select="current-group()">
                                    <xsl:element name="map"
                                        namespace="http://www.w3.org/2005/xpath-functions">
                                        <xsl:apply-templates select="." mode="json-xml"/>
                                    </xsl:element>
                                </xsl:for-each>

                            </xsl:element>
                        </xsl:when>

                        <xsl:when test="current-group()[self::attribute()]">

                            <xsl:element name="string"
                                namespace="http://www.w3.org/2005/xpath-functions">
                                <xsl:attribute name="key"
                                    select="concat('@', current-grouping-key())"/>
                                <xsl:value-of select="."/>
                            </xsl:element>

                        </xsl:when>

                        <xsl:when test="count(current-group()/*) > 0">
                            <xsl:element name="map"
                                namespace="http://www.w3.org/2005/xpath-functions">
                                <xsl:attribute name="key" select="current-grouping-key()"/>
                                <xsl:apply-templates select="current-group()" mode="json-xml"/>
                            </xsl:element>
                        </xsl:when>
                        <xsl:otherwise>

                            <xsl:apply-templates select="current-group()" mode="json-xml"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:for-each-group>

            </xsl:when>
            <xsl:when test="matches(. ,'^[0-9]+$')">
                <xsl:element name="number" namespace="http://www.w3.org/2005/xpath-functions">
                    <xsl:attribute name="key" select="local-name(.)"/>
                    <xsl:value-of select="./text()"/>
                </xsl:element>
            </xsl:when>
            <xsl:otherwise>
                <xsl:element name="string" namespace="http://www.w3.org/2005/xpath-functions">
                    <xsl:attribute name="key" select="local-name(.)"/>
                    <xsl:value-of select="./text()"/>
                </xsl:element>
            </xsl:otherwise>
           
        </xsl:choose>

    </xsl:template>


    <xsl:function name="xforms:convert-json-to-xml" as="node()" exclude-result-prefixes="#all">
        <xsl:param name="jinstance" as="xs:string"/>
        <xsl:variable name="rep-xml">
            <xsl:sequence select="json-to-xml($jinstance)"/>
        </xsl:variable>
        <!-- <xsl:message use-when="$debugMode">TESTING json xml map = <xsl:value-of select="serialize($rep-xml)"/></xsl:message> -->
        <xsl:variable name="result">
            <!--<xsl:element name="document"> -->
            <xsl:apply-templates select="$rep-xml" mode="jxml-xml"/>
            <!--  </xsl:element> -->
        </xsl:variable>
        <xsl:sequence select="$result"/>
    </xsl:function>

    <xsl:template match="*:map" mode="jxml-xml">
        <xsl:choose>
            <xsl:when test="empty(@key)">

                <xsl:apply-templates select="*" mode="jxml-xml"/>

            </xsl:when>
            <xsl:otherwise>
                <xsl:choose>
                    <xsl:when test="starts-with(@key, '@')">
                        <xsl:attribute name="{substring(@key,2)}" select="."/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:element name="{@key}">
                            <xsl:apply-templates select="*" mode="jxml-xml"/>
                        </xsl:element>
                    </xsl:otherwise>
                </xsl:choose>

            </xsl:otherwise>
        </xsl:choose>

    </xsl:template>

    <xsl:template match="*:string | *:number" mode="jxml-xml">
        <xsl:choose>
            <xsl:when test="starts-with(@key, '@')">
                <xsl:attribute name="{substring(@key,2)}" select="text()"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:element name="{@key}">
                    <xsl:value-of select="text()"/>
                </xsl:element>
            </xsl:otherwise>
        </xsl:choose>

    </xsl:template>

    <xsl:template match="*:array" mode="jxml-xml">
        <xsl:variable name="keyVar" select="@key"/>

        <xsl:for-each select="*">
            <xsl:element name="{$keyVar}">
                <xsl:apply-templates select="." mode="jxml-xml"/>
            </xsl:element>

        </xsl:for-each>

    </xsl:template>


    <!-- Form instance check for updates made -->

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for updating instance XML based on new value in form control (xforms:input, xforms:setvalue)</xd:p>
            <xd:p>Path of each element is identified and compared to resolved @data-ref value of form control.</xd:p>
        </xd:desc>
        <xd:param name="instance-id">@id value of instance (or default). Used to help write path of instance element.</xd:param>
        <xd:param name="pendingUpdates">Map of XPath binding expression to new value</xd:param>
    </xd:doc>
    <xsl:template match="*" mode="form-check-initial">
        <xsl:param name="instance-id" as="xs:string" select="$default-instance-id"/>
        <xsl:param name="pendingUpdates" as="map(xs:string, xs:string)?" tunnel="yes"/>
        <!--<xsl:message use-when="$debugMode">form-check processing pendingUpdat Map size: <xsl:value-of select="map:size($pendingUpdates)"/>
        map keys <xsl:sequence select="serialize($pendingUpdates)"/>-->
            
        <!--</xsl:message>-->
        
        <xsl:variable name="curPath" as="xs:string">
            <xsl:choose>
                <xsl:when test="$instance-id = $default-instance-id">
                    <xsl:value-of select="''"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="concat('instance(''', $instance-id, ''')/')"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:copy>
            <xsl:apply-templates select="*" mode="form-check">
                <xsl:with-param name="curPath" select="$curPath"/>
            </xsl:apply-templates>
        </xsl:copy>
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for updating element within instance XML based on new value in form control (xforms:input, xforms:setvalue)</xd:p>
        </xd:desc>
        <xd:param name="curPath">XPath statement identifying parent</xd:param>
        <xd:param name="position">Integer position of element within set of siblings</xd:param>
        <xd:param name="pendingUpdates">Map of XPath binding expression to new value</xd:param>
    </xd:doc>
    <xsl:template match="*" mode="form-check">
        <xsl:param name="curPath" select="''"/>
        <xsl:param name="position" select="0"/>
        <xsl:param name="pendingUpdates" as="map(xs:string, xs:string)?" tunnel="yes"/>
        <!-- TODO namespaces?? -->
       
        <xsl:variable name="updatedPath"
            select="
                if ($position > 0) 
                then concat($curPath, local-name(), '[', $position, ']')
                else concat($curPath, local-name())"/>

<!--        <xsl:message use-when="$debugMode">form-check processing node: <xsl:value-of select="local-name()"/></xsl:message>-->
<!--        <xsl:message use-when="$debugMode">form-check updatedPath: <xsl:value-of select="$updatedPath"/></xsl:message> -->
        
        
        <xsl:copy>
            <!-- *** Process attributes of context node -->
            <xsl:apply-templates select="attribute()" mode="form-check">
                <xsl:with-param name="curPath" select="concat($updatedPath, '/')"/>
            </xsl:apply-templates>
            
            <!-- *** Process text content of context node -->
            <!-- Check for associated/bound form-control with id=$updatedPath  -->
            <xsl:variable name="associated-form-control"
                select="ixsl:page()//*[@data-ref = $updatedPath]"/>
            
            <xsl:choose>
                <xsl:when test="exists($associated-form-control)">
                    <xsl:message use-when="$debugMode">Found associated form control with id: <xsl:value-of
                        select="$updatedPath"/></xsl:message> 
                    <xsl:value-of>
                        <xsl:apply-templates select="$associated-form-control" mode="get-field"/>
                    </xsl:value-of>
                </xsl:when>
                <xsl:when test="exists($pendingUpdates) and map:contains($pendingUpdates, $updatedPath)">
                    <!--<xsl:message use-when="$debugMode">Found path in pendingUpdate <xsl:value-of
                    select="$updatedPath"/>
                    map = <xsl:sequence select="serialize($pendingUpdates)" />
                    map:contains(map{'Document/Options/Updated':'true'}, 'Document/Shipment') := <xsl:value-of select="if(map:contains($pendingUpdates, 'Document/Shipment')) then 'true' else 'false'"/>
                   get= <xsl:value-of select="map:get($pendingUpdates, 'Document/Shipment')"/>
                    get= <xsl:value-of select="map:get($pendingUpdates, 'Document/Options/Updated')"/>
                </xsl:message>-->
                    <xsl:value-of select="map:get($pendingUpdates, $updatedPath)"/>                    
                </xsl:when>
                <!--<xsl:otherwise><xsl:value-of select="."/></xsl:otherwise>-->
                <!-- Above does not just give text node content of current node -->
                
                <!-- TODO Is this the right way to handle white space?? -->
                <xsl:otherwise>
                    <!-- <xsl:message use-when="$debugMode">did not find path in form or pending list path: <xsl:value-of
                    select="$updatedPath"/></xsl:message>-->
                    <xsl:value-of select="normalize-space(string-join(data(text()), ''))"/>
                </xsl:otherwise>
            </xsl:choose>
            
            <!-- *** Process element children of context node -->
            <xsl:for-each-group select="element()" group-by="local-name(.)">                  
                
                <xsl:variable name="updatedChildPath" select="concat($updatedPath, '/', current-grouping-key())"/>
                <!--<xsl:variable name="repeatableVar"
                select="ixsl:page()//*[@data-repeatable-context = $updatedPath2]"/>-->
                
                <xsl:variable name="dataRefWithFilter"
                    select="ixsl:page()//*[starts-with(@data-ref, concat($updatedChildPath,'['))]"/>
                <!--<xsl:message use-when="$debugMode">for-each-group path= <xsl:value-of select="$updatedPath"/>, grouping key=<xsl:value-of select="current-grouping-key()"/>, repeatableVar <xsl:value-of select="$dataRefWithFilter"/></xsl:message>-->
                <xsl:choose>
                    <xsl:when test="count(current-group()) > 1 or exists($dataRefWithFilter)">   
                        <xsl:for-each select="current-group()">
                            <xsl:apply-templates select="." mode="form-check">
                                <xsl:with-param name="curPath" select="concat($updatedPath, '/')"/>
                                <xsl:with-param name="position" select="position()"/>
                            </xsl:apply-templates>
                        </xsl:for-each>                    
                    </xsl:when>
                    
                    <xsl:otherwise>
                        <xsl:for-each select="current-group()">
                            <xsl:apply-templates select="." mode="form-check">
                                <xsl:with-param name="curPath" select="concat($updatedPath, '/')"/>
                            </xsl:apply-templates>
                        </xsl:for-each>                        
                    </xsl:otherwise>
                    
                </xsl:choose>
                
            </xsl:for-each-group>
            
        </xsl:copy>
        
    </xsl:template>


    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for updating attribute within instance XML based on new value in form control (xforms:input, xforms:setvalue)</xd:p>
        </xd:desc>
        <xd:param name="curPath">XPath statement identifying parent</xd:param>
        <xd:param name="pendingUpdates">Map of XPath binding expression to new value</xd:param>
    </xd:doc>
    <xsl:template match="@*" mode="form-check">
        <xsl:param name="curPath" select="''"/>
        <xsl:param name="pendingUpdates" as="map(xs:string, xs:string)?" tunnel="yes"/>
        <xsl:variable name="updatedPath" select="concat($curPath, '@', local-name())"/>

        <!-- TODO what about namespaces of attributes?? -->
        <!--<xsl:message use-when="$debugMode">form-check processing attribute node: <xsl:value-of select="local-name()"
            /></xsl:message>
        <xsl:message use-when="$debugMode">form-check updatedPath: <xsl:value-of select="$updatedPath"/></xsl:message> -->

        <!-- Check for associated/bound form-control with id=$updatedPath  -->
        <xsl:variable name="associated-form-control"
            select="ixsl:page()//*[@data-ref = $updatedPath]"/>

        <xsl:choose>
            <xsl:when test="exists($associated-form-control)">
                <!--<xsl:message use-when="$debugMode">Found associated form control with id: <xsl:value-of
                        select="$updatedPath"/></xsl:message> -->
                <xsl:attribute name="{local-name()}">
                    <!-- TODO namespace?? -->
                    <xsl:apply-templates select="$associated-form-control" mode="get-field"/>
                </xsl:attribute>
            </xsl:when>
            <xsl:when test="exists($pendingUpdates) and map:contains($pendingUpdates, $updatedPath)">
                <xsl:attribute name="{local-name()}">
                    <xsl:sequence select="map:get($pendingUpdates, $updatedPath)"/>
                </xsl:attribute>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy select="."/>
            </xsl:otherwise>
        </xsl:choose>

    </xsl:template>




    <xsl:template match="*:input" mode="get-field">

        <!-- select="ixsl:get(ixsl:page()//*[@id=$updatedPath],'value')" -->
        <xsl:choose>
            <xsl:when test="exists(@type) and @type = 'checkbox'">
                <xsl:sequence select="ixsl:get(., 'checked')"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:sequence select="ixsl:get(., 'value')"/>
            </xsl:otherwise>
        </xsl:choose>

    </xsl:template>

    <xsl:template match="*:select" mode="get-field">

        <xsl:sequence select="ixsl:get(./option[ixsl:get(., 'selected') = true()], 'value')"/>
    </xsl:template>

    <xsl:template match="*:textarea" mode="get-field">

        <!-- select="ixsl:get(ixsl:page()//*[@id=$updatedPath],'value')" -->
        <xsl:sequence select="ixsl:get(., 'value')"/>
    </xsl:template>


    <xsl:template match="*:input" mode="set-field">
        <xsl:param name="value" select="''" tunnel="yes"/>

        <!-- select="ixsl:get(ixsl:page()//*[@id=$updatedPath],'value')" -->
        <xsl:for-each select=".">
        <xsl:choose>
            <xsl:when test="exists(@type) and @type = 'checkbox'">                
                <ixsl:set-property name="checked" select="if($value='true') then $value else ''" object="."/>
            </xsl:when>
            <xsl:otherwise>
                <ixsl:set-property name="value" select="$value" object="."/>
            </xsl:otherwise>
        </xsl:choose>
        
        
        
            
        </xsl:for-each>

    </xsl:template>

    <xsl:template match="*:select" mode="set-field">
        <xsl:param name="value" select="''" tunnel="yes"/>

        <xsl:for-each select="./option[@value = $value]">
            <ixsl:set-property name="selected" select="true()" object="."/>
        </xsl:for-each>
    </xsl:template>

    <xsl:template match="*:textarea" mode="set-field">
        <xsl:param name="value" select="''" tunnel="yes" />
        <!-- select="ixsl:get(ixsl:page()//*[@id=$updatedPath],'value')" -->
        <xsl:sequence select="ixsl:get(., 'value')"/>
    </xsl:template>
    
   
    <!-- 
    MD 2018
    
    Helper functions and templates
    
    -->
    
    <xd:doc scope="component">
        <xd:desc>Find string in HTML @class attribute.</xd:desc>
        <xd:return>True if $string is one of the values of $class</xd:return>
        <xd:param name="class">HTML @class attribute (e.g. class="block incremental")</xd:param>
        <xd:param name="string">String to match in class (e.g. "incremental")</xd:param>
    </xd:doc>
    <xsl:function name="xforms:hasClass" as="xs:boolean">
        <xsl:param name="class" as="attribute(class)"/>
        <xsl:param name="string" as="xs:string"/>
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
            <xd:p>Otherwise, the value is ther $default-instance-id</xd:p>
        </xd:desc>
        <xd:param name="nodeset">XPath binding expression</xd:param>
    </xd:doc>
    <xsl:function name="xforms:getInstanceId" as="xs:string">
        <xsl:param name="nodeset" as="xs:string"/>
        <xsl:variable name="instance-map" as="map(xs:string,xs:string)" select="xforms:getInstanceMap($nodeset)"/>
        <xsl:value-of select="map:get($instance-map,'instance-id')"/>
    </xsl:function>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>From an XPath binding expression, a map containing the relevant instance ID and the remaining component of the XPath.</xd:p>
            <xd:p>Example: if $nodeset is instance('test')/path/to/element, the map will have instance-id = 'test' and xpath = path/to/element.</xd:p>
        </xd:desc>
        <xd:param name="nodeset">XPath binding expression</xd:param>
    </xd:doc>
    <xsl:function name="xforms:getInstanceMap" as="map(xs:string,xs:string)">
        <xsl:param name="nodeset" as="xs:string"/>
        <xsl:map>
            <xsl:analyze-string select="normalize-space($nodeset)"
                regex="^instance\s*\(\s*&apos;(.*)&apos;\s*\)\s*(/\s*(.*)|)$"
                >
                <xsl:matching-substring>
                    <xsl:variable name="xpath" as="xs:string">
                        <xsl:choose>
                            <xsl:when test="regex-group(2) != ''">
                                <xsl:sequence select="regex-group(3)"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:sequence select="''"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:variable>
                    <xsl:map-entry key="'instance-id'" select="regex-group(1)"/>
                    <xsl:map-entry key="'xpath'" select="$xpath"/>
                </xsl:matching-substring>
                <xsl:non-matching-substring>
                    <xsl:map-entry key="'instance-id'" select="$default-instance-id"/>
                    <xsl:map-entry key="'xpath'" select="normalize-space($nodeset)"/>
                </xsl:non-matching-substring>
            </xsl:analyze-string>
        </xsl:map>
    </xsl:function>
    
    <!-- take nodeset or ref, i.e. 'instance(...)/xpath/to/element'
    return instance from JS instanceDocs map
    -->
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>When triggered by an event on the page, return the relevant instance from the Javascript model.</xd:p>
        </xd:desc>
        <xd:param name="ref">XPath binding expression (held as e.g. @data-ref on an HTML element).</xd:param>
    </xd:doc>
    <xsl:function name="xforms:getInstance-JS" as="element()?">
        <xsl:param name="ref" as="xs:string"/>
        
        <xsl:choose>
            <xsl:when test="$ref = ''">
                <xsl:message use-when="$debugMode">[xforms:getInstance-JS] Empty ref supplied, no instance will be returned</xsl:message>
            </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="instance-map" as="map(xs:string,xs:string)" select="xforms:getInstanceMap($ref)"/>
                <xsl:variable name="this-instance-id" as="xs:string" select="map:get($instance-map,'instance-id')"/>
                <xsl:sequence select="xforms:instance($this-instance-id)"/>
            </xsl:otherwise>
        </xsl:choose>
       
    </xsl:function>
    
    
    <xd:doc>
        <xd:desc>
            <xd:p>Function to replace an instance in the Javascript map</xd:p>
        </xd:desc>
        <xd:return>Empty sequence</xd:return>
        <xd:param name="ref">XPath expression identifying an instance</xd:param>
        <xd:param name="updatedInstance">New instance element</xd:param>
    </xd:doc>
    <xsl:function name="xforms:setInstance-JS" as="empty-sequence()">
        <xsl:param name="ref" as="xs:string"/>
        <xsl:param name="updatedInstance" as="element()"/>
<!--        <xsl:param name="updatedInstanceDoc" as="document-node()"/>-->
<!--        <xsl:variable name="updatedInstance" as="element()" select="$updatedInstanceDoc/*"/>-->
        
        <xsl:variable name="instance-map" as="map(xs:string,xs:string)" select="xforms:getInstanceMap($ref)"/>
        <xsl:variable name="this-instance-id" as="xs:string" select="map:get($instance-map,'instance-id')"/>
        <xsl:sequence select="js:setInstance($this-instance-id,$updatedInstance)"/>
    </xsl:function>
    
    
    

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>getInstance: return an XForms instance, given its ID</xd:p>
        </xd:desc>
        <xd:param name="instance-id">Identifier for the instance.</xd:param>
        <xd:param name="instances">Map of all instances in the XForm, set in the xformsjs-main template.</xd:param>
    </xd:doc>
    <xsl:template name="getInstance" as="element()?">
        <xsl:param name="instance-id" as="xs:string" required="no" select="''"/>
        <xsl:param name="instances" as="map(xs:string,element())" tunnel="yes"/>
        
        <xsl:variable name="matched-instance" as="element()?">
            <xsl:choose>
                <xsl:when test="$instance-id != ''">
                    <xsl:sequence select="map:get($instances,$instance-id)"/>
                </xsl:when>
                <xsl:otherwise>
                    <!-- if the instance is not identified, assume the first (only) instance in the form should be used -->
                    <xsl:copy-of select="map:get($instances,$default-instance-id)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:sequence select="$matched-instance"/>
    </xsl:template>
    
    
    <xd:doc scope="component">
        <xd:desc>getBinding: return xforms:bind element relevant to $this.</xd:desc>
        <xd:param name="this">An XForms field that may have a binding.</xd:param>
        <xd:param name="bindings">Map of registered bindings (set in xformsjs-main template).</xd:param>
    </xd:doc>
    <xsl:template name="getBinding">
        <xsl:param name="this" as="element()" required="yes"/>
        <xsl:param name="bindings" as="map(xs:string, node())" required="no" select="map{}" tunnel="yes"/>
        
        <xsl:variable name="ref-binding" as="xs:string">
            <xsl:call-template name="getBindingRef">
                <xsl:with-param name="this" select="."/>
            </xsl:call-template>
        </xsl:variable>
        
        <xsl:variable name="binding" as="element()?">
            <xsl:sequence select="
                if (empty($ref-binding)) 
                then ()
                else map:get($bindings, $ref-binding)"
            />
        </xsl:variable>
        
        <xsl:choose>
            <xsl:when test="exists($binding)">
                <xsl:message use-when="$debugMode">[getBinding for <xsl:value-of select="name($this)"/>] Binding found: <xsl:value-of select="serialize($binding)"/></xsl:message>
            </xsl:when>
        </xsl:choose>
        
    </xsl:template>
    
    
    <xd:doc scope="component">
        <xd:desc>getBindingRef: return ID or XPath reference that may identify a xforms:bind element relevant to $this.</xd:desc>
        <xd:param name="this">An XForms field that may have a binding.</xd:param>
    </xd:doc>
    <xsl:template name="getBindingRef">
        <xsl:param name="this" as="element()" required="yes"/>
        
        <xsl:choose>
            <!-- 
                @bind is a reference to an @id attribute of an xforms:bind element 
                Takes precedence over @ref if both are present 
            -->
            <xsl:when test="exists($this/@bind)">
                <xsl:value-of select="$this/@bind"/>
            </xsl:when>
            <!-- @ref is an XPath binding expression (which may correspond to a @nodeset attribute on a xforms:bind element) -->
            <xsl:when test="exists($this/@ref)">
                <xsl:value-of select="$this/@ref"/>
            </xsl:when>
             <xsl:otherwise>
                <xsl:value-of select="''"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>getDataRef: return XPath binding expression relevant to $this</xd:p>
        </xd:desc>
        <xd:param name="this">An XForms field that may have a binding</xd:param>
        <xd:param name="nodeset">An XPath binding expression. If it exists, $this/@ref is evaluated relative to it.</xd:param>
        <xd:param name="bindingi">xforms:bind element relevant to $this.</xd:param>
    </xd:doc>
    <xsl:template name="getDataRef">
        <xsl:param name="this" as="element()" required="yes"/>
        <xsl:param name="nodeset" as="xs:string" select="''" tunnel="yes"/>
        <xsl:param name="bindingi" as="node()?"/>
        
        
        <xsl:variable name="this-ref" as="xs:string?" select="
            if ( exists($this/@nodeset) )
            then  normalize-space( xs:string($this/@nodeset) )
            else if ( exists($this/@ref) ) 
            then normalize-space( xs:string($this/@ref) ) 
            else ()"/>
        
        <xsl:variable name="data-ref" as="xs:string">
            <xsl:choose>
                <xsl:when test="exists($bindingi)">
                    <!-- 
                    MD 2018-07-01: xforms:bind should not have a @ref element 
                
                    https://www.w3.org/TR/xforms11/#structure-bind-element
                -->
                    <xsl:value-of
                        select="
                        if (exists($bindingi/@nodeset)) 
                        then $bindingi/@nodeset
                        else $bindingi/@ref"
                    />
                </xsl:when>
                <xsl:when test="exists($this-ref)">
                    <xsl:message use-when="$debugMode">[getDataRef for <xsl:value-of select="name($this)"/>] parsing ref = <xsl:value-of select="$this-ref"/></xsl:message>
                    <xsl:sequence select="xforms:resolveXPathStrings($nodeset,$this-ref)"/>
                </xsl:when>
                <xsl:otherwise>
                    
                    <xsl:value-of select="$nodeset"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:message use-when="$debugMode">[getDataRef for <xsl:value-of select="name($this)"/>] final parsed ref = "<xsl:value-of select="$data-ref"/>"</xsl:message>
        
        <xsl:sequence select="$data-ref"/>
        
    </xsl:template>
    

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>getReferencedInstanceField: get a relevant instance field via an XPath binding expression.</xd:p>
        </xd:desc>
        <xd:param name="refi">XPath binding expression.</xd:param>
    </xd:doc>
    <xsl:template name="getReferencedInstanceField">
        <xsl:param name="refi" as="xs:string" required="no" select="''"/>
        
        <xsl:variable name="field" as="node()*">
            <xsl:choose>
                <xsl:when test="$refi != ''">
                    <xsl:variable name="instance-map" as="map(xs:string,xs:string)" select="xforms:getInstanceMap($refi)"/>
                    
                    <!-- MD 2018: for some reason this changes the element names from the instance to lower case !! 
                But not when $instances variable is populated using xsl:sequence !!!
                
                OND explains that HTML DOM is case-insensitive.
                -->
                    <xsl:variable name="this-instance" as="element()?">
                        <xsl:call-template name="getInstance">
                            <xsl:with-param name="instance-id" select="map:get($instance-map,'instance-id')"/>
                        </xsl:call-template>
                    </xsl:variable>
                    
                    <!--                <xsl:message use-when="$debugMode">[getReferencedInstanceField] this-instance = <xsl:value-of select="serialize($this-instance)"/></xsl:message>-->
                    
                    <xsl:evaluate xpath="map:get($instance-map,'xpath')" context-item="$this-instance" namespace-context="$this-instance"/>
                    
                </xsl:when>
                <xsl:otherwise>
                    <!-- choose default instance -->
                    <xsl:variable name="default-instance" as="element()?">
                        <xsl:call-template name="getInstance">
                            <xsl:with-param name="instance-id" select="$default-instance-id"/>
                        </xsl:call-template>
                    </xsl:variable>
                    <xsl:sequence select="$default-instance"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:message use-when="$debugMode">[getInstanceField] ref = <xsl:value-of select="$refi"/>
        found field(s) = <xsl:value-of select="serialize($field)"/>
        </xsl:message>
        
        <xsl:sequence select="$field"/>
        
    </xsl:template>
    
 
    <xd:doc scope="component">
        <xd:desc>Update HTML display elements corresponding to xforms:output elements</xd:desc>
    </xd:doc>
    <xsl:template name="refreshOutputs-JS">
<!--        <xsl:message use-when="$debugMode">[refreshOutputs-JS] START refreshOutputs</xsl:message>-->
        
        <!-- get all registered outputs -->
        <!-- MD 2018-06-30 : want to use as="xs:string*" but get a cardinality error!? 
        JS data typing thing?
        -->
        <xsl:variable name="output-keys" select="js:getOutputKeys()" as="item()*"/>
        
        <xsl:for-each select="$output-keys">
            <xsl:variable name="this-key" as="xs:string" select="."/>
            <xsl:variable name="this-output" as="map(*)" select="js:getOutput($this-key)"/>
            <xsl:message use-when="$debugMode">[refreshOutputs-JS] handling output <xsl:value-of select="serialize($this-output)"/></xsl:message>
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
            <xsl:message use-when="$debugMode">[refreshOutputs-JS] key = '<xsl:value-of select="$this-key"/>', output = '<xsl:value-of select="serialize($this-output)"/>', xpath = '<xsl:value-of select="$xpath-mod"/>'</xsl:message>
            
            <xsl:variable name="instance-map" as="map(xs:string,xs:string)">
                <xsl:choose>
                    <xsl:when test="map:contains($this-output,'@ref')">
                        <xsl:variable name="ref" select="map:get($this-output,'@ref')"/>
                        <xsl:sequence select="xforms:getInstanceMap($ref)"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:sequence select="xforms:getInstanceMap($default-instance-id)"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:variable>
            
<!--            <xsl:message use-when="$debugMode">[refreshOutputs-JS] instance-map = <xsl:value-of select="serialize($instance-map)"/> </xsl:message>-->
            
            <xsl:variable name="this-instance-id" as="xs:string" select="map:get($instance-map,'instance-id')"/>
            
<!--            <xsl:message use-when="$debugMode">[refreshOutputs-JS] this-instance-id = <xsl:value-of select="$this-instance-id"/> </xsl:message>-->
            
            <xsl:variable name="contexti" as="element()?">
                <xsl:sequence select="xforms:instance($this-instance-id)"/>
            </xsl:variable>
            
            <xsl:variable name="value" as="xs:string">
                <xsl:evaluate xpath="$xpath-mod" context-item="$contexti"/>
            </xsl:variable>
            
            <xsl:message use-when="$debugMode">[refreshOutputs-JS] instance = <xsl:value-of select="serialize($contexti)"/> </xsl:message>
            <xsl:message use-when="$debugMode">[refreshOutputs-JS] new value = <xsl:value-of select="$value"/> </xsl:message>
            
            <xsl:variable name="associated-form-control" select="ixsl:page()//*[@id = $this-key]" as="node()?"/>
            
            <xsl:message use-when="$debugMode">[refreshOutputs-JS]  $associated-form-control = <xsl:value-of select="serialize($associated-form-control)"/> </xsl:message>
            
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
        <xd:desc>
            <xd:p>setActions: create map of actions relevant to $this</xd:p>
        </xd:desc>
        <xd:param name="this">An XForms Core Form Control element (e.g. xforms:input, xforms:select, etc.) that may have actions.</xd:param>
    </xd:doc>
    <xsl:template name="setActions">
        <xsl:param name="this" as="element()"/>
        
        <xsl:apply-templates select=" $this/xforms:action | $this/xforms:*[local-name() = $xforms-actions] | $this/xforms:show | $this/xforms:hide | $this/xforms:script | $this/xforms:unload"/>
        
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Apply actions by calling the template appropriate to each action.</xd:p>
        </xd:desc>
        <xd:param name="action-map">Action map</xd:param>
        <xd:param name="instanceXML">Instance relevant to actions (e.g. setvalue)</xd:param>
        <xd:param name="nodeset">XPath identifying instance node(s) as the context for the action.</xd:param>
    </xd:doc>
    <xsl:template name="applyActions">
        <xsl:param name="action-map" required="yes" as="map(*)" tunnel="yes"/>
        <xsl:param name="instanceXML" required="no" as="element()?" tunnel="yes"/>
        <xsl:param name="nodeset" as="xs:string" select="''" tunnel="yes"/>
        
        <xsl:variable name="ref" select="map:get($action-map, '@ref')" as="xs:string?"/>
        <xsl:variable name="at" select="map:get($action-map, '@at')" as="xs:string?"/>
        <xsl:variable name="position" select="map:get($action-map, '@position')" as="xs:string?"/>
        <!-- TODO: handle @at (with @position) in action map -->
        
        
        <xsl:variable name="ref-qualified" as="xs:string?" select="
            if (exists($ref))
            then (
                if (exists($at))
                then concat($ref, '[', $at, ']')
                else $ref
            )
            else ()
            "/>
        
        <xsl:variable name="instance-id" as="xs:string" select="xforms:getInstanceId($ref)"/>
        <!-- override tunnel variable $instanceXML if $refz refers to a different instance -->
        <xsl:variable name="instanceXML2" as="element()">
            <xsl:choose>
                <xsl:when test="$instance-id = $default-instance-id and exists($instanceXML)">
                    <xsl:sequence select="$instanceXML"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="xforms:getInstance-JS($ref-qualified)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        
        
        <xsl:message use-when="$debugMode">
            [applyActions] evaluating action = <xsl:value-of select="serialize($action-map)"/>
        </xsl:message>
        
        <xsl:variable name="context" as="node()?">
            <xsl:choose>
                <xsl:when test="exists($ref-qualified) and not($ref-qualified = '') and exists($instanceXML2)">
                    <xsl:evaluate xpath="xforms:impose($ref-qualified)" context-item="$instanceXML2"/>
                </xsl:when>
            </xsl:choose>
        </xsl:variable>
        
        <!-- TODO error testing of incorrect ref given in the xform (i.e. context would be empty in this case) -->

        <xsl:variable name="ifVar" select="xforms:getIfStatement($action-map)"/>      
        <xsl:variable name="whileVar" select="xforms:getWhileStatement($action-map)"/>
        
        <!-- TODO if the action does not contain an if or while it should execute action -->
        <xsl:variable name="ifExecuted" as="xs:boolean">
            <xsl:choose>
                <xsl:when test="exists($ifVar) and exists($context)">
                    <xsl:evaluate xpath="$ifVar" context-item="$context"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="true()" />
                </xsl:otherwise>
            </xsl:choose>                    
        </xsl:variable>
        
        <xsl:if test="$ifExecuted">
            <xsl:variable name="action-name" as="xs:string" select="map:get($action-map,'name')"/>
            
            <xsl:choose>
                <xsl:when test="$action-name = 'setvalue'">
                    <xsl:call-template name="action-setvalue">
                        <xsl:with-param name="nodeset" select="$ref" as="xs:string" tunnel="yes"/>
                        <xsl:with-param name="instanceXML" select="$instanceXML2" as="element()" tunnel="yes"/>
                    </xsl:call-template>
                </xsl:when>
                <xsl:when test="$action-name = 'insert'">
                    <xsl:call-template name="action-insert">
                        <xsl:with-param name="nodeset" select="$ref-qualified" as="xs:string" tunnel="yes"/>
                        <xsl:with-param name="instanceXML" select="$instanceXML2" as="element()" tunnel="yes"/>
                    </xsl:call-template>
                </xsl:when>
                <xsl:when test="$action-name = 'delete'">
                    <xsl:call-template name="action-delete">
                        <xsl:with-param name="nodeset" select="$ref-qualified" as="xs:string" tunnel="yes"/>
                        <xsl:with-param name="instanceXML" select="$instanceXML2" as="element()" tunnel="yes"/>
                    </xsl:call-template>
                </xsl:when>
                <xsl:when test="$action-name = 'message'">
                    <xsl:call-template name="action-message"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:message use-when="$debugMode">[applyActions] action '<xsl:value-of select="$action-name"/>' not yet handled!</xsl:message>
                </xsl:otherwise>
            </xsl:choose>
            
            <xsl:for-each select="$xforms-actions">
                <xsl:if test="map:contains($action-map,.)">
                    <xsl:call-template name="applyNestedActions">
                        <xsl:with-param name="action-name" select="." as="xs:string"/>
                    </xsl:call-template>
                </xsl:if>
            </xsl:for-each>
        </xsl:if>
        
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Handle nested actions, e.g. xforms:action/xforms:setvalue</xd:p>
        </xd:desc>
        <xd:param name="action-map">Action map</xd:param>
        <xd:param name="action-name">Name of action</xd:param>
    </xd:doc>
    <xsl:template name="applyNestedActions">
        <xsl:param name="action-map" required="yes" as="map(*)" tunnel="yes"/>
        <xsl:param name="action-name" required="yes" as="xs:string"/>
        
        <xsl:if test="map:contains($action-map,$action-name)">
            <xsl:variable name="actionsArray" select="map:find($action-map, $action-name)" as="array(map(*))"/>
            <xsl:variable name="actions" as="item()*">
                <xsl:sequence select="array:flatten($actionsArray)"/>
            </xsl:variable>
            <xsl:for-each select="$actions">
                <xsl:call-template name="applyActions"/>
            </xsl:for-each>
        </xsl:if>
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>setAction: create map of an action relevant to $this</xd:p>
        </xd:desc>
        <xd:param name="this">An XForms Action element (e.g. xforms:action, xforms:setvalue, etc.) that may have child actions.</xd:param>
        <xd:param name="nodeset">XPath identifying instance node(s) affected by the XForms Action element.</xd:param>
    </xd:doc>
    <xsl:template name="setAction">
        <xsl:param name="this" as="element()"/>
        <xsl:param name="nodeset" select="''" tunnel="yes"/>
                
        <xsl:map>
            <xsl:map-entry key="'name'" select="local-name()"/>
            
            <xsl:if test="exists(@value)">
                <xsl:map-entry key="'@value'" select="string(@value)" />                          
            </xsl:if>
            <xsl:if test="empty(@value) and exists(./text())">
                <xsl:map-entry key="'value'" select="string(.)" />                         
            </xsl:if>
            
            <xsl:map-entry key="'@ref'">
                <xsl:choose>
                    <xsl:when test="exists(@ref)">
                        <xsl:sequence select="string(@ref)" />
                    </xsl:when>
                    <xsl:when test="exists(@nodeset)" >
                        <xsl:sequence select="string(@nodeset)" />
                    </xsl:when>
                    <xsl:otherwise>
                        <!-- action might inherit @ref/@nodeset from parent XForm control -->
                        <xsl:sequence select="''"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:map-entry>
            
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
            
            <xsl:for-each-group select="$this/child::*" group-by="local-name()">
                <xsl:apply-templates select="." mode="xforms-action-map"/>
            </xsl:for-each-group>          
        </xsl:map>
        
        
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
                
        <!-- get xforms:bind element relevant to this -->
        <xsl:variable name="bindingi" as="node()?">
            <xsl:call-template name="getBinding">
                <xsl:with-param name="this" select="$this"/>
            </xsl:call-template>
        </xsl:variable>        
        
        <!-- get XPath binding expression relevant to this -->
        <xsl:variable name="refi" as="xs:string">
            <xsl:call-template name="getDataRef">
                <xsl:with-param name="this" select="$this"/>
                <xsl:with-param name="bindingi" select="$bindingi"/>
            </xsl:call-template>
        </xsl:variable>
        
        <!-- set actions relevant to this -->
        <xsl:variable name="actions"  as="map(*)*">
            <xsl:call-template name="setActions">
                <xsl:with-param name="this" select="."/>
                <xsl:with-param name="nodeset" select="$refi" tunnel="yes"/>
            </xsl:call-template>
        </xsl:variable>
        
        <xsl:if test="exists($actions)">
            <xsl:sequence select="js:addAction($submission-id, $actions)" />
        </xsl:if>
        
        
        <xsl:map>
            <xsl:if test="not(empty($refi))">
                <xsl:map-entry key="'@ref'" select="$refi" />
            </xsl:if>
            
            <xsl:if test="exists($this/@resource)">
                <xsl:map-entry key="'@resource'" select="xs:string($this/@resource)" />
            </xsl:if>
            <xsl:if test="exists($this/@mode)">
                <xsl:map-entry key="'@mode'" select="xs:string($this/@mode)" />
            </xsl:if>
             
            <xsl:map-entry key="'@method'">
                <xsl:choose>
                    <xsl:when test="exists($this/@method)">
                        <xsl:sequence select="string($this/@method)"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <!-- default 'POST' method -->
                        <xsl:sequence select="'POST'"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:map-entry>
            
            <xsl:if test="exists($this/@validate)">
                <xsl:map-entry key="'@validate'" select="string($this/@validate)" />
            </xsl:if>
            <xsl:if test="exists($this/@relevant)">
                <xsl:map-entry key="'@relevant'" select="string($this/@relevant)" />
            </xsl:if>
            <xsl:if test="exists($this/@serialization)">
                <xsl:map-entry key="'@serialization'" select="string($this/@serialization)" />
            </xsl:if>
            <xsl:if test="exists($this/@version)">
                <xsl:map-entry key="'@version'" select="string($this/@version)" />
            </xsl:if> 
            <xsl:if test="exists($this/@indent)">
                <xsl:map-entry key="'@indent'" select="string($this/@indent)" />
            </xsl:if> 
            
            
            <xsl:map-entry key="'@mediatype'">
                <xsl:choose>
                    <xsl:when test="exists($this/@mediatype)">
                        <xsl:sequence select="string($this/@mediatype)"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <!-- default 'text/plain' media type -->
                        <xsl:sequence select="'text/plain'"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:map-entry>
            
            
            <xsl:if test="exists($this/@encoding)">
                <xsl:map-entry key="'@encoding'" select="string($this/@encoding)" />
            </xsl:if> 
            <xsl:if test="exists($this/@omit-xml-declaration)">
                <xsl:map-entry key="'@omit-xml-declaration'" select="string($this/@omit-xml-declaration)" />
            </xsl:if>
            <xsl:if test="exists($this/@standalone )">
                <xsl:map-entry key="'@standalone'" select="string($this/@standalone)" />
            </xsl:if>
            <xsl:if test="exists($this/@cdata-section-elements)">
                <xsl:map-entry key="'@cdata-section-elements'" select="string($this/@cdata-section-elements)" />
            </xsl:if>
            
            <xsl:map-entry key="'@replace'">
                <xsl:choose>
                    <xsl:when test="exists($this/@replace)">
                        <xsl:sequence select="string($this/@replace)"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <!-- default 'all' -->
                        <xsl:sequence select="'all'"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:map-entry>
            
            
            
            <xsl:if test="exists($this/@instance )">
                <xsl:map-entry key="'@instance'" select="string($this/@instance)" />
            </xsl:if>
            <xsl:if test="exists($this/@targetref )">
                <xsl:map-entry key="'@targetref'" select="string($this/@targetref)" />
            </xsl:if>
            <xsl:if test="exists($this/@separator )">
                <xsl:map-entry key="'@separator'" select="string($this/@separator)" />
            </xsl:if>
            <xsl:if test="exists($this/@includenamespaceprefixes)">
                <xsl:map-entry key="'@includenamespaceprefixes'" select="string($this/@includenamespaceprefixes)" />
            </xsl:if>
            
            <xsl:for-each-group select="$this/child::*" group-by="local-name()">
                <xsl:apply-templates select="." mode="xforms-action-map"/>
            </xsl:for-each-group>          
            
        </xsl:map>
        
        
        
    </xsl:template>
   
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of <a href=" https://www.w3.org/TR/xforms11/#evt-rebuild">xforms-rebuild event</a></xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template name="xforms-rebuild">
        <xsl:message use-when="$debugMode">[xforms-rebuild] START</xsl:message>
        <xsl:variable name="instanceDocs" as="map(*)">
            <xsl:variable name="instance-keys" select="js:getInstanceKeys()" as="item()*"/>
            <xsl:map>
                <xsl:for-each select="$instance-keys">
                    <xsl:variable name="refz" as="xs:string" select="concat('instance(''', ., ''')/')"/>
                    <xsl:map-entry key="." select="xforms:getInstance-JS($refz)"/>
                    <xsl:message use-when="$debugMode">[xforms-rebuild] getting instance = <xsl:value-of select="$refz"/></xsl:message>
                </xsl:for-each>
            </xsl:map>            
        </xsl:variable>
        
        <xsl:call-template name="xformsjs-main">
            <xsl:with-param name="xforms-file" select="$xforms-file"/>
            <xsl:with-param name="instance-docs" select="$instanceDocs"/>
        </xsl:call-template>
                
    </xsl:template>
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of <a href="https://www.w3.org/TR/xforms11/#evt-valueChanged">xforms-value-changed event</a></xd:p>
        </xd:desc>
        <xd:param name="form-control">HTML form control containing new value for updating an instance etc.</xd:param>
    </xd:doc>
    <xsl:template name="xforms-value-changed">
        <xsl:param name="form-control" as="node()"/>
        
        <xsl:variable name="refi" select="$form-control/@data-ref"/>
        <xsl:variable name="refElement" select="$form-control/@data-element"/>
        
        <xsl:variable name="instance-id" as="xs:string" select="xforms:getInstanceId($refi)"/>
        <xsl:variable name="actions" select="js:getAction(string($form-control/@data-action))"/>
        
        <!-- MD 2018-06-29: handle multiple instances -->
        <xsl:variable name="instanceXML" as="element()" select="xforms:getInstance-JS($refi)"/>
        <xsl:variable name="updatedInstanceXML" as="element()">
            <xsl:apply-templates select="$instanceXML" mode="form-check-initial">
                <xsl:with-param name="instance-id" select="$instance-id"/>
            </xsl:apply-templates>
        </xsl:variable>
 
        <xsl:sequence select="xforms:setInstance-JS($refi,$updatedInstanceXML)"/>
        <xsl:call-template name="refreshOutputs-JS"/>
        
        <!-- clear updates -->
        <xsl:variable name="pendingInstanceUpdates" as="map(xs:string, xs:string)" select="map{}"/>       
        <xsl:variable name="instanceUpdates" as="map(xs:string, xs:string)" select="map{}"/>
        
        <xsl:sequence select="js:setPendingUpdates($pendingInstanceUpdates)"/>
        <xsl:sequence select="js:setUpdates($instanceUpdates)"/>
        
        <xsl:message use-when="$debugMode">
            [xforms-value-changed] Detected change in form control '<xsl:value-of select="name($form-control)"/>', 
            ref= <xsl:value-of select="$refi"/>, 
            actions = <xsl:value-of select="serialize($actions)"/>            
        </xsl:message>
        
        <xsl:message use-when="$debugMode">
            [xforms-value-changed] instance: <xsl:value-of select="serialize($instanceXML)"/>
        </xsl:message>
        <xsl:message use-when="$debugMode">
            [xforms-value-changed] updated instance: <xsl:value-of select="serialize($updatedInstanceXML)"/>
        </xsl:message>
        
        
        <xsl:for-each select="$actions">
            <xsl:variable name="action-map" select="."/>
                        
            <xsl:if test="map:contains($action-map,'@event')">
                <xsl:if test="map:get($action-map,'@event') = 'xforms-value-changed'">
                    <xsl:message use-when="$debugMode">[xforms-value-changed] xforms-value-changed action found!</xsl:message>
                    <xsl:call-template name="applyActions">
                        <xsl:with-param name="action-map" select="$action-map" tunnel="yes"/>
                        <xsl:with-param name="nodeset" as="xs:string" select="$refi" tunnel="yes"/>
                        <xsl:with-param name="instanceXML" as="element()" select="$updatedInstanceXML" tunnel="yes"/>
                    </xsl:call-template>
                </xsl:if>
            </xsl:if>
        </xsl:for-each>
        
        <xsl:message use-when="$debugMode">
            instance before checkRelevantFields = <xsl:value-of select="serialize(xforms:getInstance-JS($refi))"/>
        </xsl:message>
                
        <xsl:sequence select="xforms:checkRelevantFields($refElement)"/>
        
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of <a href="https://www.w3.org/TR/xforms11/#submit-evt-submit">xforms-submit event</a></xd:p>
        </xd:desc>
        <xd:param name="form-control">HTML form control a @data-submit attribute referencing a registered submission.</xd:param>
    </xd:doc>
    <xsl:template name="xforms-submit">
        <xsl:param name="form-control" as="node()"/>
        
        <xsl:variable name="submission" select="js:getSubmission(string($form-control/@data-submit))" as="map(*)"/>
        <xsl:variable name="actions" select="js:getAction(string($form-control/@data-submit))" as="map(*)*"/>
        
        <xsl:message use-when="$debugMode">[xforms-submit] Submitting: <xsl:value-of select="serialize($submission)"/></xsl:message>
        
        <xsl:variable name="refi" as="xs:string?" select="map:get($submission,'@ref')"/>
        
        <xsl:variable name="instance-id" as="xs:string">
            <xsl:choose>
                <xsl:when test="map:get($submission,'@instance')">
                    <xsl:sequence select="map:get($submission,'@instance')"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="$default-instance-id"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:message use-when="$debugMode">[xforms-submit] refi = <xsl:value-of select="$refi"/></xsl:message>
        
        <xsl:variable name="instanceXML" as="element()" select="
            if ($refi)
            then xforms:getInstance-JS($refi) 
            else xforms:instance($instance-id)"/>
        
        <xsl:variable name="updatedInstanceXML" as="element()">
            <xsl:apply-templates select="$instanceXML" mode="form-check-initial">
                <xsl:with-param name="instance-id" select="$instance-id"/>
            </xsl:apply-templates>
        </xsl:variable>
        
        <xsl:variable name="required-fieldsi" select="ixsl:page()//*[@data-required]" as="item()*"/>
        
        <xsl:variable name="required-fields-check" as="item()*" select="xforms:check-required-fields($updatedInstanceXML)"/>
        
        
        <xsl:choose>
            <xsl:when test="empty($required-fields-check)">
                <xsl:variable name="requestBodyXML" as="element()">
                    <xsl:choose>
                        <xsl:when test="$refi">
                            <xsl:evaluate xpath="xforms:impose($refi)" context-item="$instanceXML"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:sequence select="$instanceXML"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                
                <xsl:variable name="requestBody">
                    <xsl:sequence select="serialize($requestBodyXML)"/>
                </xsl:variable>
                <xsl:variable name="requestBodyDoc">
                    <xsl:document>
                        <xsl:sequence select="$requestBodyXML"/>
                    </xsl:document>
                </xsl:variable>
                
                <xsl:variable name="method" as="xs:string" select="map:get($submission,'@method')"/>
                
                <xsl:variable name="serialization" as="xs:string?" select="map:get($submission,'@serialization')"/>
                
                <xsl:variable name="query-parameters" as="xs:string?">
                    <xsl:if test="exists($serialization) and $serialization = 'application/x-www-form-urlencoded'">
                        <xsl:variable name="parts" as="xs:string*">
                            <xsl:for-each select="$requestBodyXML/*">
                                <xsl:sequence select="concat(name(),'=',string())"/>
                            </xsl:for-each>
                        </xsl:variable>
                        <xsl:sequence select="
                            string-join($parts,'&amp;') 
                            "/>
                    </xsl:if>
                </xsl:variable>
                
                <xsl:variable name="href-base" as="xs:string" select="map:get($submission,'@resource')"/>
                
                <xsl:variable name="href" as="xs:string">
                    <xsl:choose>
                        <xsl:when test="exists($query-parameters)">
                            <xsl:sequence select="concat($href-base,'?',$query-parameters)"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:sequence select="$href-base"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                
                <xsl:variable name="mediatype" as="xs:string" select="map:get($submission,'@mediatype')"/>      
                
                <!-- http://www.saxonica.com/saxon-js/documentation/index.html#!development/http -->
                <xsl:variable name="HTTPrequest" as="map(*)">
                    <xsl:map>
                        <xsl:if test="not( upper-case($method) = 'GET')">
                            <xsl:map-entry key="'body'" select="$requestBodyDoc"/>
                        </xsl:if>
                        <xsl:map-entry key="'method'" select="$method"/>
                        <xsl:map-entry key="'href'" select="$href"/>
                        <xsl:map-entry key="'media-type'" select="$mediatype"/>
                    </xsl:map>
                </xsl:variable>
                
                <xsl:message use-when="$debugMode">[xforms-submit] HTTP request = <xsl:value-of select="serialize($HTTPrequest)"/></xsl:message>
                
                <ixsl:schedule-action http-request="$HTTPrequest">
                    <!-- The value of @http-request is an XPath expression, which evaluates to an 'HTTP request
                            map' - i.e. our representation of an HTTP request as an XDM map -->
                    <xsl:call-template name="HTTPsubmit">
                        <xsl:with-param name="instance-id" select="$instance-id" as="xs:string"/>
                        <xsl:with-param name="targetref" select="map:get($submission,'@targetref')"/>
                        <xsl:with-param name="replace" select="map:get($submission,'@replace')"/>
                    </xsl:call-template>
                </ixsl:schedule-action>
                
                <xsl:for-each select="$actions">
                    <xsl:variable name="action-map" select="."/>
                    
                    <xsl:message use-when="$debugMode">
                        [xforms-submit] evaluating action = <xsl:value-of select="serialize($action-map)"/>
                    </xsl:message>
                    
                    <!-- https://www.w3.org/TR/xslt-30/#func-map-contains -->
                    <xsl:if test="map:contains($action-map,'@event')">
                        <xsl:if test="map:get($action-map,'@event') = 'xforms-submit-done'">
                            <xsl:message use-when="$debugMode">[xforms-submit] xforms-submit-done action found!</xsl:message>
                            <xsl:call-template name="applyActions">
                                <xsl:with-param name="action-map" select="$action-map" tunnel="yes"/>
                                <xsl:with-param name="nodeset" as="xs:string" select="$refi" tunnel="yes"/>
                                <xsl:with-param name="instanceXML" as="element()" select="$instanceXML" tunnel="yes"/>
                            </xsl:call-template>
                        </xsl:if>
                    </xsl:if>
                </xsl:for-each>                
            </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="error-message">
                    <xsl:for-each select="$required-fields-check">
                        <xsl:variable name="curNode" select="."/>
                        <xsl:value-of select="concat('Value error see: ', serialize($curNode/@data-ref), '&#10;')"/>
                    </xsl:for-each>
                </xsl:variable>
                <xsl:sequence select="ixsl:call(ixsl:window(), 'alert', [serialize($error-message)])"/>
            </xsl:otherwise>
        </xsl:choose>
        
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
        
        <xsl:variable name="refi" select="$form-control/@data-ref"/>
        <xsl:variable name="instance-id" as="xs:string" select="xforms:getInstanceId($refi)"/>
        
        <xsl:variable name="instanceXML" as="element()?" select="xforms:getInstance-JS($refi)"/>
        
        <xsl:variable name="updatedInstanceXML" as="element()?">
           <xsl:if test="exists($instanceXML)">
               <xsl:apply-templates select="$instanceXML" mode="form-check-initial">
                   <xsl:with-param name="instance-id" select="$instance-id"/>
               </xsl:apply-templates>
           </xsl:if>
        </xsl:variable>
        
        <xsl:for-each select="$actions">
            <xsl:variable name="action-map" select="."/>
            
            <xsl:message use-when="$debugMode">
                [DOMActivate] evaluating action = <xsl:value-of select="serialize($action-map)"/>
                instance XML = <xsl:value-of select="serialize($instanceXML)"/>
            </xsl:message>
            
            <!-- https://www.w3.org/TR/xslt-30/#func-map-contains -->
            <xsl:if test="map:contains($action-map,'@event')">
                <xsl:if test="map:get($action-map,'@event') = 'DOMActivate'">
<!--                    <xsl:message use-when="$debugMode">[DOMActivate] DOMActivate action found!</xsl:message>-->
                    <xsl:call-template name="applyActions">
                        <xsl:with-param name="action-map" select="$action-map" tunnel="yes"/>
                        <xsl:with-param name="instanceXML" as="element()?" select="$updatedInstanceXML" tunnel="yes"/>
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
        <xd:param name="instanceXML">Instance relevant to actions (e.g. setvalue)</xd:param>
        <xd:param name="nodeset">XPath identifying instance node(s) as the context for the action.</xd:param>
    </xd:doc>
    <xsl:template name="action-setvalue">
        <xsl:param name="action-map" required="yes" as="map(*)" tunnel="yes"/>
        <xsl:param name="instanceXML" required="no" as="element()?" tunnel="yes"/>
        <xsl:param name="nodeset" as="xs:string" select="''" tunnel="yes"/>
        
        <xsl:variable name="ifVari" select="xforms:getIfStatement($action-map)"/>
        <xsl:variable name="whileVari" select="xforms:getWhileStatement($action-map)"/>
        <xsl:variable name="refz" select="xforms:resolveXPathStrings($nodeset,map:get($action-map,'@ref'))"/>
        
        <xsl:variable name="instance-id" as="xs:string" select="xforms:getInstanceId($refz)"/>
        <!-- override tunnel variable $instanceXML if $refz refers to a different instance -->
        <xsl:variable name="instanceXML2" as="element()">
            <xsl:choose>
                <xsl:when test="$instance-id = $default-instance-id and exists($instanceXML)">
                    <xsl:sequence select="$instanceXML"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="xforms:getInstance-JS($refz)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:variable name="valuez">
            <xsl:choose>
                <xsl:when test="map:contains($action-map,'@value')">
                    <xsl:message use-when="$debugMode">
                        $nodeset = <xsl:value-of select="$nodeset"/>
                        @value <xsl:value-of select="xforms:resolveXPathStrings($nodeset,map:get($action-map,'@value'))"/>
                    </xsl:message>
                    <xsl:variable name="contexti" as="node()">
                        <xsl:evaluate xpath="xforms:impose($nodeset)" context-item="$instanceXML" as="node()" />
                    </xsl:variable>
                    <xsl:sequence>
                        <xsl:evaluate xpath="xforms:impose(map:get($action-map,'@value'))" context-item="$contexti" />
                    </xsl:sequence>
                </xsl:when>
                <xsl:when test="map:contains(.,'value')">
                    <xsl:sequence select="map:get($action-map,'value')"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="''"/> 
                </xsl:otherwise>
            </xsl:choose>
            
        </xsl:variable>
        <xsl:message use-when="$debugMode"> 
            nodeset = <xsl:value-of select="$nodeset"/>
            refz = <xsl:value-of select="$refz"/>
        </xsl:message>
        <xsl:message use-when="$debugMode"> 
            value = <xsl:value-of select="xs:string($valuez)"/> 
        </xsl:message> 
        
        <!-- TODO: use ifVari and WhileVari -->
        <xsl:if test="exists($refz)">
            <xsl:variable name="associated-form-control"
                select="ixsl:page()//*[@data-ref = $refz]" as="node()?"/>
            <xsl:message use-when="$debugMode"> $associated-form-control = <xsl:value-of select="serialize($associated-form-control)"/> </xsl:message>
            <xsl:choose>
                <xsl:when test="exists($associated-form-control)">
                    <xsl:apply-templates select="$associated-form-control" mode="set-field">
                        <xsl:with-param name="value" select="xs:string($valuez)" tunnel="yes"/>
                    </xsl:apply-templates>
                    
                    <xsl:sequence select="js:setUpdates(map:put(js:getUpdates(),$refz , xs:string($valuez)))" />
                    <xsl:message use-when="$debugMode">
                        <xsl:variable name="mapxx" select="js:getUpdates()" />
                        Updates map = <xsl:sequence select="serialize($mapxx)" />
                    </xsl:message>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="js:setPendingUpdates(map:put(js:getPendingUpdates(),$refz , xs:string($valuez)))" />
                </xsl:otherwise>
            </xsl:choose>    
        </xsl:if>
        
        
        <xsl:if test="exists($refz) and not($refz = '')">
            <!-- update instance again if there were setvalue actions -->
            <xsl:variable name="pendingUpdates" select="js:getPendingUpdates()" as="map(xs:string, xs:string)?"/>
            
            <xsl:variable name="updatedInstanceXML" as="element()">   
                <xsl:apply-templates select="$instanceXML2" mode="form-check-initial">
                    <xsl:with-param name="instance-id" select="$instance-id" as="xs:string"/>
                    <xsl:with-param name="pendingUpdates" as="map(xs:string,xs:string)?" select="$pendingUpdates" tunnel="yes"/>
                </xsl:apply-templates>
            </xsl:variable>
            
            <!-- MD 2018-06-29: handle multiple instances -->
            <xsl:sequence select="xforms:setInstance-JS($refz,$updatedInstanceXML)"/>
            <xsl:call-template name="refreshOutputs-JS"/>
            
        </xsl:if>
       
    </xsl:template>
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for applying insert action</xd:p>
        </xd:desc>
        <xd:param name="action-map">Action map</xd:param>
        <xd:param name="instanceXML">Instance relevant to actions (e.g. setvalue)</xd:param>
        <xd:param name="nodeset">XPath identifying instance node(s) as the context for the action.</xd:param>
    </xd:doc>
    <xsl:template name="action-insert">
        <xsl:param name="action-map" required="yes" as="map(*)" tunnel="yes"/>
        <xsl:param name="instanceXML" required="no" as="element()?" tunnel="yes"/>
        <xsl:param name="nodeset" as="xs:string" select="''" tunnel="yes"/>
                
        <xsl:variable name="ref" select="xforms:resolveXPathStrings($nodeset,map:get($action-map,'@ref'))" />
        <xsl:variable name="at" select="map:get($action-map, '@at')" as="xs:string?"/>
        <xsl:variable name="position" select="map:get($action-map, '@position')" as="xs:string?"/>
         
        
        <xsl:variable name="ref-qualified" as="xs:string?" select="
            if (exists($ref))
            then (
            if (exists($at))
            then concat($ref, '[', $at, ']')
            else $ref
            )
            else ()
            "/>
        
        <xsl:variable name="instance-id" as="xs:string" select="xforms:getInstanceId($ref)"/>
        <!-- override tunnel variable $instanceXML if $map-ref refers to a different instance -->
        <xsl:variable name="instanceXML2" as="element()">
            <xsl:choose>
                <xsl:when test="$instance-id = $default-instance-id and exists($instanceXML)">
                    <xsl:sequence select="$instanceXML"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="xforms:getInstance-JS($ref)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        
        <xsl:message use-when="$debugMode">[action-insert] insert = <xsl:value-of select="serialize($action-map)"/> 
            ref-qualified = <xsl:value-of select="$ref-qualified"/>
        </xsl:message>
        
        <xsl:variable name="insert-node" as="node()">
            <xsl:evaluate xpath="xforms:impose($ref-qualified)" context-item="$instanceXML2"/>
        </xsl:variable>
                
         
        <xsl:variable name="instance-with-insert" as="element()">
            <xsl:apply-templates select="$instanceXML2" mode="insert-node">
                <xsl:with-param name="insert-node" select="$insert-node" tunnel="yes"/>
                <xsl:with-param name="position-relative" select="$position" tunnel="yes"/>
            </xsl:apply-templates>
        </xsl:variable>
        
        <xsl:sequence select="xforms:setInstance-JS($ref,$instance-with-insert)"/>
        <xsl:call-template name="xforms-rebuild"/>
                
    </xsl:template>
    
 
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for applying delete action</xd:p>
        </xd:desc>
        <xd:param name="action-map">Action map</xd:param>
        <xd:param name="instanceXML">Instance relevant to actions (e.g. setvalue)</xd:param>
        <xd:param name="nodeset">XPath identifying instance node(s) as the context for the action.</xd:param>
    </xd:doc>
    <xsl:template name="action-delete">
        <xsl:param name="action-map" required="yes" as="map(*)" tunnel="yes"/>
        <xsl:param name="instanceXML" required="no" as="element()" tunnel="yes"/>
        <xsl:param name="nodeset" as="xs:string" select="''" tunnel="yes"/>
        
        <xsl:variable name="ref" select="xforms:resolveXPathStrings($nodeset,map:get($action-map,'@ref'))"/>
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
        
        <xsl:variable name="instance-id" as="xs:string" select="xforms:getInstanceId($ref)"/>
        <!-- override tunnel variable $instanceXML if $map-ref refers to a different instance -->
        <xsl:variable name="instanceXML2" as="element()">
            <xsl:choose>
                <xsl:when test="$instance-id = $default-instance-id and exists($instanceXML)">
                    <xsl:sequence select="$instanceXML"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="xforms:getInstance-JS($ref)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:variable name="ifVar" select="xforms:getIfStatement($action-map)"/>
        <xsl:variable name="whileVar" select="xforms:getWhileStatement($action-map)"/>
         
        <xsl:variable name="delete-node" as="node()?">
            <xsl:choose>
                <xsl:when test="exists($ref-qualified) and not($ref-qualified = '')">
                    <xsl:evaluate xpath="xforms:impose($ref-qualified)" context-item="$instanceXML2"/>
                </xsl:when>
            </xsl:choose>
        </xsl:variable>
        
<!--        <xsl:message use-when="$debugMode">[action-delete] ref-qualified = <xsl:value-of select="$ref-qualified"/>; delete-node = <xsl:value-of select="serialize($delete-node)"/></xsl:message>-->
        
        <xsl:variable name="ifExecuted" as="xs:boolean">
            <xsl:choose>
                <xsl:when test="exists($ifVar)">
                    <xsl:evaluate xpath="$ifVar" context-item="$delete-node"/>
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
            
            <xsl:sequence select="xforms:setInstance-JS($ref,$instance-with-delete)"/>      
            <xsl:call-template name="xforms-rebuild"/>
        </xsl:if>
        
    </xsl:template>
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for applying message action</xd:p>
        </xd:desc>
        <xd:param name="action-map">Action map</xd:param>
    </xd:doc>
    <xsl:template name="action-message">
        <xsl:param name="action-map" required="yes" as="map(*)" tunnel="yes"/>
        
        <xsl:variable name="message-value" as="xs:string" select="map:get($action-map,'value')"/>
        
        <xsl:message>[action-message] Message reads "<xsl:value-of select="$message-value"/>"</xsl:message>
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
    </xsl:template>
    
</xsl:stylesheet>