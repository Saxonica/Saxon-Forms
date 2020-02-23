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
        
    exclude-result-prefixes="xs math xforms sfl"
    extension-element-prefixes="ixsl saxon" version="3.0">
    
    <!-- 
        
        General TO DO list:
    
    
    A proper test suite/demo
    
    Error detection and messaging
    
    Handlers for more events
        
    Proper handling of @if, @while, and pending updates (I haven't used this before, so need to generate an example to develop against)
    
    Handle more xforms:submission options
    
    Is @targetref handled properly in HTTPsubmit?
    
    Apply improved performance to action-setvalue (i.e. remove use of form-check)
    
    Various other XForms elements and attributes still to be handled
    
    Improve performance (I think some of the simplifications may have slowed down performance, e.g. triggering xforms-rebuild after an insert or delete action rather than granular handling of the HTML)

    -->
    
    <!--  xmlns:r="http://ns.datacraft.co.uk/recipe" -->
    <xsl:include href="xforms-function-library.xsl"/>

    <xsl:output method="html" encoding="utf-8" omit-xml-declaration="no" indent="no"
        doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN"
        doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"/>
    
    <!--<xsl:use-package name="http://saxon.sf.net/packages/logger.xsl" package-version="1.0">
        <xsl:override>
            <xsl:variable name="sfp:LOGLEVEL" select="$sfp:LOGLEVEL_ALL"/>
        </xsl:override>
    </xsl:use-package>-->

    <xsl:param name="xforms-instance-id" select="'xforms-jinstance'"/>
    <xsl:param name="xforms-cache-id" select="'xforms-cache'"/>
    
    <!-- @id attribute of HTML div element into which the XForm is to be rendered on the page -->
    <xsl:param name="xform-html-id" as="xs:string" select="'xForm'"/>
    
    <xsl:param name="xforms-file" as="xs:string?"/>
    
    <xsl:variable name="xforms-doc" as="document-node()?" select="if (exists($xforms-file) and fn:doc-available($xforms-file)) then fn:doc($xforms-file) else ()"/>

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
        
        <xsl:message use-when="$debugMode">[xformsjs-main] START</xsl:message>

        <xsl:variable name="xforms-doci"
            select="
                if (empty($xforms-doc)) then
                    doc($xforms-file)
                else
                    $xforms-doc"
            as="document-node()?"/>
        
        <xsl:variable name="xform" as="element(xforms:xform)" select="xforms:addNamespaceDeclarations($xforms-doci/*)"/>
        

        <!-- all xforms:instance elements in the XForm -->
        <xsl:variable name="xforms-instances" as="map(xs:string, element())">
            <xsl:choose>
                <xsl:when test="empty($instance-docs)">
                    <xsl:map>
                        <xsl:choose>
                            <xsl:when test="empty($instance-xml)">
                                <xsl:variable name="instances" as="element(xforms:instance)*" select="$xforms-doci/xforms:xform/xforms:model/xforms:instance"/>
                                <xsl:if test="count($instances[not(@id)])">
                                    <xsl:variable name="message" as="xs:string" select="'[xformsjs-main] FATAL ERROR: The XForm contains more than one instance with no ID. At most one instance may have no ID.'"/>
                                    <xsl:message terminate="yes" select="$message"/>
                                </xsl:if>
                                
                                <xsl:for-each select="$instances">
                                    <xsl:variable name="instance-with-explicit-namespaces" as="element()">
                                        <xsl:apply-templates select="./*" mode="namespace-fix"/>
                                    </xsl:variable>
                                    
                                    <xsl:map-entry key="
                                        xs:string(
                                        if (exists(@id)) 
                                        then @id 
                                        else $default-instance-id
                                        )"
                                        select="$instance-with-explicit-namespaces"/>
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
                        key="xs:string(
                            if (exists(@id)) 
                            then @id
                            else @nodeset
                            )"
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
        
<!--        <xsl:message use-when="$debugMode">[xformsjs-main] RelevantBindings = <xsl:sequence select="serialize($RelevantBindings)"/></xsl:message>-->
        

        <xsl:variable name="CalculationBindings" as="map(xs:string, xs:string)">
            <xsl:map>
                <xsl:for-each select="$bindingKeys">
                    <xsl:variable name="bindingNode" select="map:get($bindings, xs:string(.))" as="node()" />                    
                    
                    <xsl:if test="$bindingNode[exists(@calculate)]">
                        <xsl:variable name="keyi" select="xs:string($bindingNode/@nodeset)" as="xs:string"/>
                        <xsl:map-entry key="$keyi" select="xs:string($bindingNode/@calculate)" />
                    </xsl:if>
                </xsl:for-each>
            </xsl:map>  
        </xsl:variable>
        
<!--        <xsl:message use-when="$debugMode">[xformsjs-main] CalculationBindings = <xsl:sequence select="serialize($CalculationBindings)"/></xsl:message>-->
        
        
        <!-- copy xform-doc to HTML page -->
        <xsl:choose>
            <!-- when Javascript section already exists... (i.e. page is being re-rendered? REDUNDANT?) -->
            <xsl:when test="ixsl:page()//script/@id = $xforms-cache-id">
                <xsl:sequence select="js:setXFormsDoc($xforms-doc)"/>
                <xsl:sequence select="js:setXForm($xform)"/>
                <xsl:sequence select="js:setXFormsID($xFormsId)"/>
                <xsl:sequence select="js:setRelevantMap($RelevantBindings)" />
                <xsl:sequence select="js:setCalculationMap($CalculationBindings)" />
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
                            var XForm = null;
                            var defaultInstanceDoc = null;
                            
                            // MD 2018: OND's suggestion for multiple instances
                            var instanceDocs = {};
                            
                            var pendingUpdatesMap = null;
                            var updatesMap = null;
                            var XFormsID = '<xsl:value-of select="$xFormsId"/>';
                            var actions = {};
                            var submissions = {};
                            var outputs = {};
                            var repeats = {};
                            var relevantMap = {};
                            var calculationMap = {};
                            var repeatIndexMap = {};
                            var repeatSizeMap = {};
                            var elementsUsingIndexFunction = {};
                            
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
                            
                            var setXForm = function(element) {
                                XForm = element;
                            }
                            
                            var getXForm = function() {
                                return XForm;
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
                            
                            var getInstances = function() {
                                return instanceDocs;
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
                            
                            // repeats is a map of HTML IDs to (parsed) xf:repeat/@nodeset values
                            var addRepeat = function(name, value){
                                repeats[name] = value;
                            }
                            
                            var getRepeat = function(name){
                                return repeats[name];
                            }
                            
                            var getRepeatKeys = function() {
                                return Object.keys(repeats);
                            }
                            
                            var setRelevantMap = function(map1) {
                                relevantMap = map1;                            
                            }
                            
                            var getRelevantMap = function() {
                                return relevantMap;
                            }
                            
  
                            var setCalculationMap = function(map1) {
                                calculationMap = map1;                            
                            }
  
                            var getCalculationMap = function() {
                                return calculationMap;
                            }
  
                            
                            var setRepeatIndex = function(name, value) {
                                repeatIndexMap[name] = value;
                            }
                            
                            var getRepeatIndex = function(name) {
                                if ( typeof(repeatIndexMap[name]) != 'undefined' ) {
                                    return repeatIndexMap[name];
                                }
                                else {
                                    return 0;
                                }
                            } 
                            
                            var setRepeatSize = function(name, value) {
                                repeatSizeMap[name] = value;
                            }
                            
                            var getRepeatSize = function(name) {
                                if ( typeof(repeatSizeMap[name]) != 'undefined' ) {
                                    return repeatSizeMap[name];
                                }
                                else {
                                    return 0;
                                }
                            } 
                            
                            var setElementUsingIndexFunction = function(name, value) {
                                elementsUsingIndexFunction[name] = value;
                            } 
                            
                            var getElementUsingIndexFunction = function(name) {
                                return elementsUsingIndexFunction[name];
                            }
                            
                            var getElementsUsingIndexFunctionKeys = function() {
                            return Object.keys(elementsUsingIndexFunction);
                            }
                            
                            
                            var startTime = function(name) {
                                console.time(name);
                            }
                            
                            var endTime = function(name) {
                                console.timeEnd(name);
                            }
                            
                            var highlightClicked = function(id) {
                                var item = document.getElementById(id);
                                toggleClass(item);
                            }
                            
                            var toggleClass = function(element) {
                                if (element.className == 'selected') {
                                    element.classList.remove('selected');
                                }
                                else {
                                    var x = document.getElementsByClassName('selected');
                                    var i;
                                    for (i = 0; i &lt; x.length; i++) {
                                        x[i].classList.remove('selected');
                                    } 
                                    element.classList.add('selected');
                                }
                            }
                            
                            var setFocus = function(id) {
                                var item = document.getElementById(id);
                                item.focus();
                                // alert('setFocus on ' + id);
                            }
                            
                        </script>
                    </xsl:result-document>
                </xsl:for-each>

                <xsl:sequence select="js:setXFormsDoc($xforms-doc)"/>
                <xsl:sequence select="js:setXForm($xform)"/>
                <xsl:sequence select="js:setDefaultInstance($default-instance)"/>
                <xsl:sequence select="js:setRelevantMap($RelevantBindings)" />
                <xsl:sequence select="js:setCalculationMap($CalculationBindings)" />
                
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
            <!--<xsl:message use-when="$debugMode">Setting submission with ID '<xsl:value-of select="."/>'</xsl:message>
            <xsl:message use-when="$debugMode">Submission map: '<xsl:value-of select="serialize($submission)"/>'</xsl:message>-->
            <xsl:sequence select="js:addSubmission(.,$submission)"/>
        </xsl:for-each>
        

        <xsl:variable name="time-id" select="generate-id()"/>
        <xsl:sequence use-when="$debugTiming" select="js:startTime(concat('XForms Main-Build', $time-id))" />
        
        
        <!-- Write HTML to placeholder <div id="xForm"> -->
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
        
                        
        <xsl:for-each select="$relevantFields">
            <xsl:variable name="keyi" select="."/>
            <xsl:variable name="context" select="ixsl:page()//*[@data-ref = $keyi]"/>
            <xsl:variable name="updatedInstanceXML4" select="xforms:getInstance-JS($keyi)"/>
            
            <xsl:variable name="relevantCheck" as="xs:boolean">
                <xsl:evaluate xpath="concat(.,'/',map:get($relevantMap, .))" context-item="$updatedInstanceXML4" namespace-context="$updatedInstanceXML4"/>
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
    <xsl:template match="input[xforms:hasClass(.,'incremental')]" mode="ixsl:onkeyup">
        
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
            <xd:p>Highlight repeat item when selected</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template match="div[@data-repeat-item = 'true']//*[self::span or self::input]" mode="ixsl:onclick">
        <xsl:sequence select="js:highlightClicked( string(@id) )"/>
                
        <!-- update repeat index of ancestors (we may have clicked on a repeat item within a repeat item) -->
        <xsl:for-each select="./ancestor::div[@data-repeat-item = 'true']">
            <xsl:variable name="repeat-id" as="xs:string" select="./ancestor::div[exists(@data-repeatable-context)][1]/@id"/>
            <xsl:variable name="item-position" as="xs:integer" select="count(./preceding-sibling::div[@data-repeat-item = 'true']) + 1"/>
            
<!--            <xsl:message use-when="$debugMode">[div onclick] Setting repeat index '<xsl:value-of select="$repeat-id"/>' to value '<xsl:value-of select="$item-position"/>'</xsl:message>-->
            <xsl:sequence select="js:setRepeatIndex($repeat-id,$item-position)"/>                        
        </xsl:for-each>
        
        <xsl:if test="self::span">
            <xsl:call-template name="refreshElementsUsingIndexFunction-JS"/>     
        </xsl:if>
       
        
       <!-- <xsl:if test="self::input">
            <xsl:sequence select="js:setFocus( xs:string(@id) )"/>    
        </xsl:if>-->
        

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
                    
                    <xsl:variable name="parentCallCount" select="if(contains($relative, '/')) then count(tokenize($relative, '/')[. ='..']) else if(contains($relative, '..')) then 1 else 0"/>
                    <xsl:variable name="slashes"
                        select="if(contains($base, '/')) then index-of(string-to-codepoints($base), string-to-codepoints('/')) else 0"
                        as="xs:integer*"/>
                    
                    <!--                <xsl:message use-when="$debugMode">resolveXPathString base =<xsl:value-of select="$base"/> 
                    relative <xsl:value-of select="$relative"/>
                    parentCallCount = <xsl:value-of select="$parentCallCount"/>
                    slashes = <xsl:value-of select="$slashes"/>
                </xsl:message>
-->                
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
                    
                    <!-- <xsl:message use-when="$debugMode">[xforms:resolveXPathStrings] base =<xsl:value-of select="$base"/> 
                    lastSlash = <xsl:value-of select="$parentSlash"/> 
                    relative = <xsl:value-of select="$relative"/> 
                    countparent = <xsl:value-of select="$parentCallCount"/>
                    <xsl:if test="$parentCallCount > 0">
                        base without parent nodes = <xsl:value-of select="substring($base, 1, $parentSlash)" />
                        relativeCut = <xsl:value-of select="replace($relative, '\.\./', '')"/>
                    </xsl:if>
                    
                </xsl:message>-->
                    
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
        </xsl:variable>
        
        <!-- stopped resolving index, as it fixes the value up front but we need to be dynamic -->
        <!-- then resolve index() into an integer position -->
        <!--<xsl:variable name="full-path-parsed-components" as="xs:string+">
            <xsl:analyze-string select="$full-path" regex="(index\(&apos;([^&apos;]+)&apos;\)|/\.$)">
                <xsl:matching-substring>
                    <xsl:variable name="match" select="regex-group(1)"/>
                    <xsl:choose>
                        <xsl:when test="$match = '/.'"/>
                        <xsl:otherwise>
                            <xsl:sequence select="xs:string( js:getRepeatIndex( regex-group(2) ) )"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:matching-substring>
                <xsl:non-matching-substring>
                    <xsl:sequence select="normalize-space(.)"/>
                </xsl:non-matching-substring>
            </xsl:analyze-string>
        </xsl:variable>
        
        <xsl:sequence select="string-join($full-path-parsed-components)"/>-->
        
        <xsl:sequence select="$full-path"/>

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
                    context-item="$instanceXML" namespace-context="$instanceXML"/>
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
                <xsl:evaluate xpath="@data-ref" context-item="$updatedInstanceXML" namespace-context="$updatedInstanceXML"/>
            </xsl:variable>
            
            <xsl:variable name="resulti" as="xs:boolean">
                <xsl:evaluate
                    xpath="@data-constraint"
                    context-item="$contexti" namespace-context="$contexti"/>
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
            <xsl:with-param name="submission" select="string(./@data-submit)"/>
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
        
<!--        <xsl:message use-when="$debugMode">[HTTPsubmit] Response: <xsl:sequence select="fn:serialize(.)"/></xsl:message>-->
        
        <xsl:variable name="responseXML" select="?body" as="document-node()"/>  
        
        <xsl:message use-when="$debugMode">[HTTPsubmit] Response body: <xsl:sequence select="fn:serialize($responseXML)"/></xsl:message>
 
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
                          
                          <xsl:call-template name="xforms-recalculate"/>
<!--                          <xsl:call-template name="xforms-rebuild"/>-->
                        <!-- <xsl:message use-when="$debugMode">[HTTPsubmit] response body: <xsl:value-of select="serialize($responseXML)"/></xsl:message>-->
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
        <xd:param name="context-position">String representing position of item in a hierarchy (e.g. in nested repeat)</xd:param>
    </xd:doc>
    <xsl:template match="xforms:output">
        <xsl:param name="position" as="xs:integer" required="no" select="0"/>
        <xsl:param name="context-position" as="xs:string" required="no" select="''"/>
        
        <xsl:variable name="string-position" as="xs:string" select="if ($context-position != '') then $context-position else string($position)"/>
        
        <xsl:variable name="myid" as="xs:string" select="if (exists(@id)) then @id else concat( generate-id(), '-', $string-position )"/>
        
        <xsl:if test="xforms:usesIndexFunction(.) and not(ancestor::*[xforms:usesIndexFunction(.)])">
            <xsl:sequence select="js:setElementUsingIndexFunction($myid,.)"/>
        </xsl:if>
        
         
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
        
        <xsl:variable name="namespace-context-item" as="element()" select="
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
                <xsl:when test="exists($bindingi) and exists($bindingi/@relevant) and exists($instanceField)">
                    <xsl:evaluate xpath="xforms:impose($bindingi/@relevant)" context-item="$instanceField" namespace-context="$namespace-context-item"/>
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
                <xsl:attribute name="id" select="$myid"/>
                <xsl:attribute name="style" select="if($relevantVar) then 'display:inline' else 'display:none'" />
                <xsl:attribute name="data-ref" select="$refi"/>
                
                <xsl:sequence select="$valueExecuted" />
            </span>
        </div>
        
        <!-- register outputs (except those inside a repeat) -->
        <xsl:if test="not(ancestor::xforms:repeat)">
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
            
            <!--<xsl:sequence select="sfp:logInfo(
            concat('[xforms:output] Registering output with ID ', $myid)
            )"/>-->
            <!--<xsl:message use-when="$debugMode">
                <xsl:sequence select="concat('[xforms:output] Registering output with ID ', $myid)"/>
            </xsl:message>-->
            <xsl:sequence select="js:addOutput($myid , $output-map)" />
        </xsl:if>
 
        
    </xsl:template>

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of XForms <a href="https://www.w3.org/TR/xforms11/#ui-input">input element</a></xd:p>
            <xd:p>Generates HTML input field and registers actions.</xd:p>
        </xd:desc>
        <xd:param name="position">Integer representing position of item (in a repeat list for example).</xd:param>
        <xd:param name="context-position">String representing position of item in a hierarchy (e.g. in nested repeat)</xd:param>
    </xd:doc>
    <xsl:template match="xforms:input">
        <xsl:param name="position" as="xs:integer" required="no" select="0"/>
        <xsl:param name="context-position" as="xs:string" required="no" select="''"/>
        
        <xsl:variable name="string-position" as="xs:string" select="if ($context-position != '') then $context-position else string($position)"/>
        
        <xsl:variable name="myid" as="xs:string" select="if (exists(@id)) then concat(@id, '-', $string-position) else concat( generate-id(), '-', $string-position )"/>
        
        <xsl:if test="xforms:usesIndexFunction(.) and not(ancestor::*[xforms:usesIndexFunction(.)])">
            <xsl:sequence select="js:setElementUsingIndexFunction($myid,.)"/>
        </xsl:if>
        
        <xsl:variable name="time-id" as="xs:string" select="generate-id()"/>
        <xsl:sequence use-when="$debugTiming" select="js:startTime(concat('XForms-input-', $time-id))" />
                      
        <!-- get xforms:bind element relevant to this -->
        <xsl:sequence use-when="$debugTiming" select="js:startTime(concat('XForms-input-binding-1-', $time-id))" />
        <xsl:variable name="bindingi" as="node()?">
            <xsl:call-template name="getBinding">
                <xsl:with-param name="this" select="."/>
            </xsl:call-template>
        </xsl:variable>
        <xsl:sequence use-when="$debugTiming" select="js:endTime(concat('XForms-input-binding-1-', $time-id))" />
        
        
        <!-- get XPath binding expression relevant to this -->
        <xsl:sequence use-when="$debugTiming" select="js:startTime(concat('XForms-input-refi-1-', $time-id))" />
        <xsl:variable name="refi" as="xs:string">
            <xsl:call-template name="getDataRef">
                <xsl:with-param name="this" select="."/>
                <xsl:with-param name="bindingi" select="$bindingi"/>
            </xsl:call-template>
        </xsl:variable>
        <xsl:sequence use-when="$debugTiming" select="js:endTime(concat('XForms-input-refi-1-', $time-id))" />
                
        <!-- identify instance field corresponding to this -->
        <xsl:sequence use-when="$debugTiming" select="js:startTime(concat('XForms-input-instanceField-1-', $time-id))" />
        <xsl:variable name="instanceField" as="node()?">
            <xsl:call-template name="getReferencedInstanceField">
                <xsl:with-param name="refi" select="$refi"/>
            </xsl:call-template>
        </xsl:variable>
        <xsl:sequence use-when="$debugTiming" select="js:endTime(concat('XForms-input-instanceField-1-', $time-id))" />
        

        <xsl:variable name="namespace-context-item" as="element()" select="
            if (exists($instanceField))
            then $instanceField
            else xforms:addNamespaceDeclarations(/*)"/>
               
               

        <!-- check whether this input is relevant -->
        <xsl:variable name="relevantVar" as="xs:boolean">
            <xsl:choose>
                <xsl:when test="exists($bindingi) and exists($bindingi/@relevant) and exists($instanceField)">
                    <xsl:evaluate xpath="xforms:impose($bindingi/@relevant)" context-item="$instanceField" namespace-context="$namespace-context-item"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="true()"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <!-- set actions relevant to this -->
        <xsl:sequence use-when="$debugTiming" select="js:startTime(concat('XForms-input-actions-1-', $time-id))" />
        <xsl:variable name="actions"  as="map(*)*">
            <xsl:call-template name="setActions">
                <xsl:with-param name="this" select="."/>
                <xsl:with-param name="nodeset" select="$refi" tunnel="yes"/>
            </xsl:call-template>
        </xsl:variable>
        <xsl:sequence use-when="$debugTiming" select="js:endTime(concat('XForms-input-actions-1-', $time-id))" />
        
        <xsl:if test="exists($actions)">
            <xsl:sequence select="js:addAction($myid, $actions)" />
        </xsl:if>
        
        
        <!-- GENERATE HTML -->
        <div class="xforms-input">
            <xsl:attribute name="style" select="if($relevantVar) then 'display:block' else 'display:none'" />
            
            <xsl:apply-templates select="xforms:label"/>
            
            <xsl:variable name="hints" select="xforms:hint/text()"/>
            
            <xsl:variable name="refElement" select="tokenize($refi, '/')[last()]"/>
            
            <input>
                <xsl:sequence select="xforms:getClass(.)"/>
                <xsl:attribute name="id" select="$myid"/>
                
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
        </div>
        
        <xsl:sequence use-when="$debugTiming" select="js:endTime(concat('XForms-input-', $time-id))" />
        
    </xsl:template>
    

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of XForms <a href="https://www.w3.org/TR/xforms11/#ui-textarea">textarea element</a>  </xd:p>          
            <xd:p>Generates HTML output field and registers actions.</xd:p>
        </xd:desc>
        <xd:param name="position">Integer representing position of item (in a repeat list for example).</xd:param>
        <xd:param name="context-position">String representing position of item in a hierarchy (e.g. in nested repeat)</xd:param>
    </xd:doc>
    <xsl:template match="xforms:textarea" priority="2">
        <xsl:param name="position" as="xs:integer" required="no" select="0"/>
        <xsl:param name="context-position" as="xs:string" required="no" select="''"/>
        
        <xsl:variable name="string-position" as="xs:string" select="if ($context-position != '') then $context-position else string($position)"/>
        
        <xsl:variable name="myid" as="xs:string" select="if (exists(@id)) then @id else concat( generate-id(), '-', $string-position )"/>
        
        <xsl:if test="xforms:usesIndexFunction(.) and not(ancestor::*[xforms:usesIndexFunction(.)])">
            <xsl:sequence select="js:setElementUsingIndexFunction($myid,.)"/>
        </xsl:if>
        
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
        <xd:param name="context-position">String representing position of item in a hierarchy (e.g. in nested repeat)</xd:param>
    </xd:doc>
    <xsl:template match="xforms:select1 | xforms:select">
        <xsl:param name="position" as="xs:integer" required="no" select="0"/>
        <xsl:param name="context-position" as="xs:string" required="no" select="''"/>
        
        <xsl:variable name="string-position" as="xs:string" select="if ($context-position != '') then $context-position else string($position)"/>
        
        <xsl:variable name="myid" as="xs:string" select="if (exists(@id)) then @id else concat( generate-id(), '-', $string-position )"/>
        
        <xsl:if test="xforms:usesIndexFunction(.) and not(ancestor::*[xforms:usesIndexFunction(.)])">
            <xsl:sequence select="js:setElementUsingIndexFunction($myid,.)"/>
        </xsl:if>
        
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
                         
        <xsl:variable name="refElement" select="tokenize($refi, '/')[last()]"/>
        
        <div class="xforms-select">
            <xsl:apply-templates select="xforms:label"/>
            
            <select>
                <xsl:sequence select="xforms:getClass(.)"/>
                <xsl:copy-of select="@* except (@class,@ref,@incremental)"/>
                
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
        <xd:param name="position">Integer representing position of item (in a repeat list for example).</xd:param>
        <xd:param name="context-position">String representing position of item in a hierarchy (e.g. in nested repeat)</xd:param>
    </xd:doc>
    <xsl:template match="xforms:group">
        <xsl:param name="position" as="xs:integer" required="no" select="0"/>
        <xsl:param name="context-position" as="xs:string" required="no" select="''"/>
        
        <xsl:variable name="string-position" as="xs:string" select="if ($context-position != '') then $context-position else string($position)"/>
        
        <xsl:variable name="myid" as="xs:string" select="if (exists(@id)) then @id else concat( generate-id(), '-', $string-position )"/>
        
        <xsl:if test="xforms:usesIndexFunction(.) and not(ancestor::*[xforms:usesIndexFunction(.)])">
            <xsl:sequence select="js:setElementUsingIndexFunction($myid,.)"/>
        </xsl:if>
        
        <xsl:variable name="refi" as="xs:string?">
            <xsl:choose>
                <xsl:when test="exists(@nodeset)"><xsl:sequence select="@nodeset" /></xsl:when>
                <xsl:when test="exists(@ref)"><xsl:sequence select="@ref" /></xsl:when>
                <xsl:otherwise/>
            </xsl:choose>
        </xsl:variable>
        

        <div>
            <xsl:attribute name="id" select="$myid"/>
            <xsl:if test="exists($refi)">
                <xsl:attribute name="data-group-ref" select="$refi" />
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
        <xd:param name="context-position">String representing position of item in a hierarchy (e.g. in nested repeat)</xd:param>
        <xd:param name="recalculate">Boolean parameter. A true value means we are recalculating and do not output the top-level div</xd:param>
        <xd:param name="refreshRepeats">Boolean parameter. A true value means we are calling it from the refreshRepeats-JS template - we are replacing the contgent of the div wrapper and don't need to recreate it (otherwise there will be duplicate IDs)</xd:param>
    </xd:doc>
    <xsl:template match="xforms:repeat">
        <xsl:param name="position" as="xs:integer" required="no" select="0"/>
        <xsl:param name="context-position" as="xs:string" required="no" select="''"/>
        <xsl:param name="recalculate" as="xs:boolean" required="no" select="fn:false()"/>
        <xsl:param name="refreshRepeats" as="xs:boolean" required="no" select="fn:false()"/>
        
        <xsl:variable name="string-position" as="xs:string" select="if ($context-position != '') then $context-position else string($position)"/>
        
        <xsl:variable name="myid" as="xs:string" select="if (exists(@id)) then @id else concat( generate-id(), '-', $string-position )"/>
        
        <xsl:variable name="time-id" select="generate-id()"/>
        <xsl:sequence use-when="$debugTiming" select="js:startTime(concat('XForms-repeat', $time-id))" />
        
        
        <!-- set the starting index value -->        
        <xsl:if test="not($recalculate)">
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
            
            <xsl:sequence select="js:setRepeatIndex($myid, $this-index)"/>
        </xsl:if>


      
      
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
            <xsl:sequence select="js:addRepeat($myid , $refi)" />            
        </xsl:if>
        
        <!-- register size of repeat -->
        <xsl:sequence select="js:setRepeatSize($myid,count($selectedRepeatVar))"/>
        
        
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
                    <xsl:if test="exists(@submission) and map:contains($submissions, @submission)">
<!--                        <xsl:message use-when="$debugMode">[xforms:submit] Submission found</xsl:message>-->
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
        <xd:param name="delete-node">Node to be deleted</xd:param>
     </xd:doc>
    <xsl:template match="*" mode="delete-node">
        <xsl:param name="delete-node" as="node()" tunnel="yes"/>
        
        <xsl:choose>
            <xsl:when test=". is $delete-node">
<!--                <xsl:message>[delete-node mode] Found! <xsl:value-of select="serialize($delete-node)"/></xsl:message>-->
                
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
    
<!--    <xsl:template match="@data-action" mode="update-ref" priority="2" >
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
        <xsl:param name="position" select="'0'" />
        
        <xsl:copy>
            <xsl:apply-templates select="@*|node()" mode="update-ref" >
                <xsl:with-param name="path" select="$path" />
                <xsl:with-param name="position" select="$position"/>
            </xsl:apply-templates>
        </xsl:copy>
        
    </xsl:template> 
-->
 
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
        <xd:param name="context-position">String representing position of item in a hierarchy (e.g. in nested repeat)</xd:param>
    </xd:doc>
    <xsl:template match="xforms:trigger">
        <xsl:param name="position" as="xs:integer" required="no" select="0"/>
        <xsl:param name="context-position" as="xs:string" required="no" select="''"/>
        
        <xsl:variable name="string-position" as="xs:string" select="if ($context-position != '') then $context-position else string($position)"/>
        
        <xsl:variable name="myid" as="xs:string" select="if (exists(@id)) then @id else concat( generate-id(), '-', $string-position )"/>
        
        <xsl:if test="xforms:usesIndexFunction(.) and not(ancestor::*[xforms:usesIndexFunction(.)])">
            <xsl:sequence select="js:setElementUsingIndexFunction($myid,.)"/>
        </xsl:if>
        
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
        
<!--        <xsl:message>[xforms:trigger] $refi = <xsl:value-of select="$refi"/></xsl:message>-->
               
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
        <xsl:variable name="myid" select="if (exists(@id)) then @id else generate-id()"/>
        
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

<!--    <xsl:template match="xforms:insert" mode="xforms-action">
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
<!-\-        <xsl:message use-when="$debugMode">setvalue ZZZ= <xsl:value-of select="serialize(.)"/></xsl:message>-\->
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
    
-->    
    
    <!-- action-to-map -->
    
    
    <xd:doc scope="component">
        <xd:desc>Template for XForms Action elements nested within others (e.g. xforms:action, xforms:setvalue)</xd:desc>
        <xd:param name="nodeset">XPath identifying instance node(s) affected by the XForms Action element.</xd:param>
    </xd:doc>
<!--    <xsl:template match="xforms:*[local-name() = $xforms-actions]" mode="xforms-action-map">
        
        <xsl:param name="nodeset" select="''" tunnel="yes"/>        
        
        <xsl:map-entry key="local-name()">
           <xsl:variable name="array" as="map(*)*">
               <xsl:for-each select="current-group()">
                   <xsl:apply-templates select="." mode="#default"/>
               </xsl:for-each>
            </xsl:variable>
           <xsl:sequence select="array{$array}" />
       </xsl:map-entry>
        
        
    </xsl:template>-->
    
    

<!--    <xsl:function name="xforms:convert-xml-to-jxml" as="node()" exclude-result-prefixes="#all">
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
            <!-\- TODO handle attributes??? -\->
            <!-\-<xsl:when test="attribute()"></xsl:when>-\->
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
-->
<!--
    <xsl:function name="xforms:convert-json-to-xml" as="node()" exclude-result-prefixes="#all">
        <xsl:param name="jinstance" as="xs:string"/>
        <xsl:variable name="rep-xml">
            <xsl:sequence select="json-to-xml($jinstance)"/>
        </xsl:variable>
        <!-\- <xsl:message use-when="$debugMode">TESTING json xml map = <xsl:value-of select="serialize($rep-xml)"/></xsl:message> -\->
        <xsl:variable name="result">
            <!-\-<xsl:element name="document"> -\->
            <xsl:apply-templates select="$rep-xml" mode="jxml-xml"/>
            <!-\-  </xsl:element> -\->
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

-->
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
            
            <xsl:for-each-group select="element()" group-by="local-name(.)">                  
                
                <xsl:variable name="updatedChildPath" select="concat($curPath, current-grouping-key())"/>
                <!--<xsl:variable name="repeatableVar"
                select="ixsl:page()//*[@data-repeatable-context = $updatedPath2]"/>-->
                
                <xsl:variable name="dataRefWithFilter"
                    select="ixsl:page()//*[starts-with(@data-ref, concat($updatedChildPath,'['))]"/>
                <xsl:choose>
                    <xsl:when test="count(current-group()) > 1 or exists($dataRefWithFilter)">   
                        <xsl:for-each select="current-group()">
                            <xsl:apply-templates select="." mode="form-check">
                                <xsl:with-param name="curPath" select="$curPath"/>
                                <xsl:with-param name="position" select="position()"/>
                            </xsl:apply-templates>
                        </xsl:for-each>                    
                    </xsl:when>
                    
                    <xsl:otherwise>
                        <xsl:for-each select="current-group()">
                            <xsl:apply-templates select="." mode="form-check">
                                <xsl:with-param name="curPath" select="$curPath"/>
                            </xsl:apply-templates>
                        </xsl:for-each>                        
                    </xsl:otherwise>
                    
                </xsl:choose>
                
            </xsl:for-each-group>
            
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
       <xsl:param name="updated-node" as="node()?" tunnel="yes"/>
        <xsl:param name="value" as="xs:string?" tunnel="yes"/>
       
       <!-- 
       problems when repeats are used
       
       the first item's position is not made explicit
       
       we really need to evaluate the XPath
       
       maybe "pendingUpdates" should be used for this ... ?
       
       at xforms-value-changed, xsl:evaluate the data-ref XPath
       to identify the precise node that changed
       and do a node comparison here instead of an XPat string comparison
       
       ... it works ...
       -->
        <xsl:variable name="updatedPath"
            select="
                if ($position > 0) 
                then concat($curPath, name(), '[', $position, ']')
                else concat($curPath, name())"/>
<!--        <xsl:variable name="updatedPath" select="concat($curPath, name(), '[', $position, ']')"/>-->
        
<!--        <xsl:message use-when="$debugMode">form-check processing node: <xsl:value-of select="local-name()"/></xsl:message>-->
<!--        <xsl:message use-when="$debugMode">form-check updatedPath: <xsl:value-of select="$updatedPath"/></xsl:message> -->
        
        <xsl:message use-when="$debugMode">[form-check] looking for form control for XPath '<xsl:sequence select="$updatedPath"/>'</xsl:message>
        <xsl:for-each select="ixsl:page()//*[self::input or self::select or self::textarea]">
            <xsl:message use-when="$debugMode">[form-check] checking <xsl:sequence select="name(.)"/>, @data-ref = '<xsl:sequence select="@data-ref"/>'</xsl:message>
            <xsl:message use-when="$debugMode">[form-check] resolved @data-ref = '<xsl:sequence select="xforms:resolve-index(@data-ref)"/>'</xsl:message>
        </xsl:for-each>
        
        <xsl:copy>
            <!-- *** Process attributes of context node -->
            <xsl:apply-templates select="attribute()" mode="form-check">
                <xsl:with-param name="curPath" select="concat($updatedPath, '/')"/>
            </xsl:apply-templates>
            
            <!-- *** Process text content of context node -->
            <!-- Check for associated/bound form-control with id=$updatedPath  -->
            <xsl:variable name="associated-form-control" as="element()*"
                select="ixsl:page()//*[self::input or self::select or self::textarea][xforms:resolve-index(@data-ref) = $updatedPath]"/>
                     
            <xsl:if test="count($associated-form-control) > 1">
                <xsl:message>[form-check] More than one form element controls the value of XForm node at <xsl:value-of select="$updatedPath"/>; Saxon-Forms will apply the value of the first</xsl:message>
            </xsl:if>
            
            <xsl:choose>
                <xsl:when test="$updated-node is .">
                    <xsl:message use-when="$debugMode">
                        [form-check] Matched node!!
                    </xsl:message>
                    <xsl:value-of select="$value"/>
                </xsl:when>
                <xsl:when test="exists($associated-form-control)">
                    <!--<xsl:message use-when="$debugMode">[form-check mode] Found form control &lt;<xsl:value-of select="name($associated-form-control[1])"/>&gt; associated with instance item at: <xsl:value-of
                        select="$updatedPath"/></xsl:message> -->
                    <xsl:value-of>
                        <xsl:apply-templates select="$associated-form-control[1]" mode="get-field"/>
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
            <xd:p>Template for updating element within instance XML based on new value in binding calculation (xforms:bind/@calculate)</xd:p>
        </xd:desc>
        <xd:param name="updated-nodes">Nodes within instance that are affected by binding calculations</xd:param>
        <xd:param name="updated-values">Values of those nodes</xd:param>
    </xd:doc>

    <xsl:template match="*" mode="recalculate">
        <xsl:param name="updated-nodes" as="node()*" tunnel="yes"/>
        <xsl:param name="updated-values" as="xs:string*" tunnel="yes"/>
        
        <xsl:variable name="updated-node" as="element()?" select="$updated-nodes[. is fn:current()]"/>
        
        <xsl:copy>
            <xsl:apply-templates select="@*" mode="recalculate"/>
            
            <xsl:choose>
                <xsl:when test="exists($updated-node)">
                    <xsl:variable name="updated-node-position" as="xs:integer" select="$updated-nodes[. is fn:current()]/position()"/>
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

        <!-- select="ixsl:get(ixsl:page()//*[@id=$updatedPath],'value')" -->
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

        <!-- select="ixsl:get(ixsl:page()//*[@id=$updatedPath],'value')" -->
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
        <xd:desc>Write message to HTML page for the user.</xd:desc>
        <xd:param name="message">String message.</xd:param>
    </xd:doc>
    <xsl:function name="xforms:logToPage" as="empty-sequence()">
        <xsl:param name="message" as="xs:string"/>
        <xsl:result-document href="#{$xform-html-id}" method="ixsl:append-content">
            <div class="message">
                <p>
                    <xsl:sequence select="$message"/>
                </p>
            </div>
        </xsl:result-document>
    </xsl:function>
    
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
                regex="^instance\s*\(\s*&apos;([^&apos;]+)&apos;\s*\)\s*(/\s*(.*)|)$"
                >
                <xsl:matching-substring>
                    <xsl:variable name="xpath" as="xs:string">
                        <xsl:choose>
                            <xsl:when test="regex-group(2) != ''">
                                <xsl:sequence select="regex-group(3)"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:sequence select="'.'"/>
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
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Function xforms:getDataRef is equivalent to the named template getDataRef.</xd:p>
            <xd:p>The function version is used to support the xforms-recalculate event on repeats</xd:p>
        </xd:desc>
        <xd:param name="this">An XForms field that may have a binding</xd:param>
        <xd:param name="nodeset">An XPath binding expression. If it exists, $this/@ref is evaluated relative to it.</xd:param>
    </xd:doc>
    <xsl:function name="xforms:getDataRef" as="xs:string">
        <xsl:param name="this" as="element()"/>
        <xsl:param name="nodeset" as="xs:string?"/>
        
        <xsl:variable name="this-ref" as="xs:string?" select="
            if ( exists($this/@nodeset) )
            then  normalize-space( xs:string($this/@nodeset) )
            else if ( exists($this/@ref) ) 
            then normalize-space( xs:string($this/@ref) ) 
            else ()"/>
        
        
        <xsl:variable name="this-binding" as="node()?">
            <xsl:call-template name="getBinding">
                <xsl:with-param name="this" select="$this"/>
            </xsl:call-template>
        </xsl:variable>
        
        <xsl:variable name="this-binding-ref" as="xs:string?">
            <xsl:choose>
                <xsl:when test="exists($this-binding)">
                    <!-- 
                        MD 2018-07-01: xforms:bind should not have a @ref element
                        https://www.w3.org/TR/xforms11/#structure-bind-element
                    -->
                    <xsl:value-of
                        select="
                        if (exists($this-binding/@nodeset)) 
                        then normalize-space( xs:string($this-binding/@nodeset) )
                        else normalize-space( xs:string($this-binding/@ref) )
                        "
                    />
                </xsl:when>
                <xsl:otherwise/>
             </xsl:choose>
        </xsl:variable>
        
        <xsl:variable name="data-ref" as="xs:string">
            <xsl:choose>
                <xsl:when test="exists($this-binding)">
                    <xsl:sequence select="xforms:resolveXPathStrings('',$this-binding-ref)"/>
                </xsl:when>
                <xsl:when test="exists($this-ref)">
                    <xsl:sequence select="xforms:resolveXPathStrings($nodeset,$this-ref)"/>
                </xsl:when>
                <xsl:when test="$nodeset != ''">
                    <xsl:sequence select="xforms:resolveXPathStrings('',$nodeset)"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="''"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:sequence select="$data-ref"/>
        
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
        
        <xsl:variable name="ref-binding" as="xs:string" select="
            if ( exists($this/@bind) )
            then xs:string($this/@bind)
            else (
                if ( exists($this/@ref) )
                then xs:string($this/@ref)
                else ''
            )"/>
        
        <xsl:variable name="binding" as="element()?">
            <xsl:sequence select="
                if (empty($ref-binding)) 
                then ()
                else map:get($bindings, $ref-binding)"
            />
        </xsl:variable>
        
        <xsl:if test="exists($binding)">
           <!-- <xsl:sequence select="sfp:logInfo(
                concat(
                '[getBinding for ', name($this), '] Binding found: ', serialize($binding)
                )
                )"/>-->
            <xsl:message use-when="$debugMode">[getBinding for <xsl:value-of select="name($this)"/>] Binding found: <xsl:value-of select="serialize($binding)"/></xsl:message>
            
        </xsl:if>
        
        <xsl:sequence select="$binding"/>
        
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
        
        <xsl:variable name="this-context" as="xs:string?" select="
            if ( exists($this/@context) )
            then  normalize-space( xs:string($this/@context) )
            else '.'"/>
        
        <xsl:variable name="this-binding-ref" as="xs:string?">
            <xsl:choose>
                <xsl:when test="exists($bindingi)">
                    <!-- 
                        MD 2018-07-01: xforms:bind should not have a @ref element
                        https://www.w3.org/TR/xforms11/#structure-bind-element
                    -->
                    <xsl:value-of
                        select="
                        if (exists($bindingi/@nodeset)) 
                        then normalize-space( xs:string($bindingi/@nodeset) )
                        else normalize-space( xs:string($bindingi/@ref) )
                        "
                    />
                </xsl:when>
                <xsl:otherwise>
                    <!-- get xforms:bind element relevant to this -->
                    <xsl:variable name="this-binding" as="node()?">
                        <xsl:call-template name="getBinding">
                            <xsl:with-param name="this" select="."/>
                        </xsl:call-template>
                    </xsl:variable>
                    <xsl:if test="exists($this-binding)">
                        <xsl:value-of
                            select="
                            if (exists($this-binding/@nodeset)) 
                            then normalize-space( xs:string($this-binding/@nodeset) )
                            else normalize-space( xs:string($this-binding/@ref) )
                            "
                        />
                    </xsl:if>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
<!--        <xsl:message use-when="$debugMode">[getDataRef] Handling <xsl:value-of select="name($this)"/></xsl:message>-->
        
        <xsl:variable name="data-ref" as="xs:string">
            <xsl:choose>
                <xsl:when test="exists($bindingi)">
<!--                    <xsl:message use-when="$debugMode">[getDataRef] Binding found</xsl:message>-->
                    <xsl:sequence select="xforms:resolveXPathStrings('',$this-binding-ref)"/>
                </xsl:when>
                <xsl:when test="exists($this-ref) and $nodeset = ''">
                    <xsl:sequence select="xforms:resolveXPathStrings($this-context,$this-ref)"/>
                </xsl:when>
                <xsl:when test="exists($this-ref)">
<!--                    <xsl:message use-when="$debugMode">[getDataRef] $this-ref = '<xsl:value-of select="$this-ref"/>'</xsl:message>-->
                    <xsl:sequence select="xforms:resolveXPathStrings($nodeset,$this-ref)"/>
                </xsl:when>
                <xsl:when test="$nodeset != ''">
<!--                    <xsl:message use-when="$debugMode">[getDataRef] $nodeset = '<xsl:value-of select="$nodeset"/>'</xsl:message>-->
                    
                    <xsl:sequence select="xforms:resolveXPathStrings('',$nodeset)"/>
                </xsl:when>
                <xsl:otherwise>
<!--                    <xsl:message use-when="$debugMode">[getDataRef] $nodeset = '<xsl:value-of select="$nodeset"/>' (fallback)</xsl:message>-->
                    <xsl:value-of select="$nodeset"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
<!--        <xsl:message use-when="$debugMode">[getDataRef] $data-ref = '<xsl:value-of select="$data-ref"/>'</xsl:message>-->
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
        
<!--        <xsl:message use-when="$debugMode">[getReferencedInstanceField] $refi = '<xsl:value-of select="$refi"/>'</xsl:message>-->
        
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
                    
                    <xsl:variable name="xpath-mod" as="xs:string" select="xforms:impose(map:get($instance-map,'xpath'))"/>
                                      
                 
                    
                    <xsl:evaluate xpath="$xpath-mod" context-item="$this-instance" namespace-context="$this-instance"/>
                    
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
            
            <xsl:message use-when="$debugMode">[refreshOutputs-JS] Refreshing output ID = '<xsl:sequence select="$this-key"/>'</xsl:message>
            
            
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
            
            <xsl:message use-when="$debugMode">[refreshOutputs-JS] $xpath-mod = '<xsl:sequence select="$xpath-mod"/>'</xsl:message>
            
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
                        
            <xsl:variable name="this-instance-id" as="xs:string" select="map:get($instance-map,'instance-id')"/>
                        
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
                
        <xsl:message use-when="$debugMode">[refreshRepeats-JS] START refreshRepeats</xsl:message>
        
        
        <xsl:variable name="repeat-keys" select="js:getRepeatKeys()" as="item()*"/>
        
        <xsl:for-each select="$repeat-keys">
            <xsl:variable name="this-key" as="xs:string" select="."/>
            <xsl:variable name="this-repeat-nodeset" as="xs:string" select="js:getRepeat($this-key)"/>
            
            <xsl:message use-when="$debugMode">[refreshRepeats-JS] Refreshing repeat ID = '<xsl:sequence select="$this-key"/>'</xsl:message>
            
            
            <xsl:variable name="instance-map" as="map(xs:string,xs:string)">
                <xsl:sequence select="xforms:getInstanceMap($this-repeat-nodeset)"/>
            </xsl:variable>
            
            <xsl:variable name="this-instance-id" as="xs:string" select="map:get($instance-map,'instance-id')"/>
            
            
            
            <xsl:variable name="contexti" as="element()?">
                <xsl:sequence select="xforms:instance($this-instance-id)"/>
            </xsl:variable>
                        
            <xsl:variable name="namespace-context-item" as="element()" select="
                if (exists($contexti))
                then $contexti
                else js:getXForm()
                "/>
                        
            <xsl:variable name="page-element" select="ixsl:page()//*[@id = $this-key]" as="node()?"/>
            
            <xsl:choose>
                <xsl:when test="exists($page-element)">
                    <xsl:variable name="instance-keys" as="item()*" select="js:getInstanceKeys()"/>
                    <xsl:variable name="instances" as="map(xs:string, element())">
                        <xsl:map>
                            <xsl:for-each select="$instance-keys">
                                <xsl:map-entry key="." select="js:getInstance(.)"/>
                            </xsl:for-each>
                        </xsl:map>
                    </xsl:variable>
                    <xsl:result-document href="#{$this-key}" method="ixsl:replace-content">
                        <xsl:apply-templates select="$xforms-doc//xforms:repeat[xforms:getDataRef(.,'') = $this-repeat-nodeset]">
                            <xsl:with-param name="instances" select="$instances" tunnel="yes"/>
                            <xsl:with-param name="recalculate" select="true()"/>
                            <xsl:with-param name="refreshRepeats" select="fn:true()"/>
                        </xsl:apply-templates>
                    </xsl:result-document>
                </xsl:when>
                <xsl:otherwise/>
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
        
        <xsl:variable name="instance-keys" as="item()*" select="js:getInstanceKeys()"/>
        <xsl:variable name="instances" as="map(xs:string, element())">
            <xsl:map>
                <xsl:for-each select="$instance-keys">
                    <xsl:map-entry key="." select="js:getInstance(.)"/>
                </xsl:for-each>
            </xsl:map>
        </xsl:variable>
        
                
        <xsl:for-each select="$ElementsUsingIndexFunction-keys">
            <xsl:variable name="this-key" as="xs:string" select="."/>
            
            <xsl:message use-when="$debugMode">[refreshElementsUsingIndexFunction-JS] Refreshing item with key '<xsl:sequence select="$this-key"/>'</xsl:message>
            
            <xsl:variable name="this-element" as="element()" select="js:getElementUsingIndexFunction($this-key)"/>
            <xsl:variable name="this-element-refi" as="xs:string?">
                <xsl:choose>
                    <xsl:when test="exists($this-element/@nodeset)"><xsl:sequence select="$this-element/@nodeset" /></xsl:when>
                    <xsl:when test="exists($this-element/@ref)"><xsl:sequence select="$this-element/@ref" /></xsl:when>
                    <xsl:otherwise/>
                </xsl:choose>
            </xsl:variable>
            <xsl:result-document href="#{$this-key}" method="ixsl:replace-content">
                <xsl:apply-templates select="$this-element/*">
                    <xsl:with-param name="instances" select="$instances" tunnel="yes"/>
                    <xsl:with-param name="nodeset" select="if(exists($this-element-refi))then $this-element-refi else ''" tunnel="yes"/>
                    <xsl:with-param name="recalculate" select="fn:true()"/>
                </xsl:apply-templates>
            </xsl:result-document>
            
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
        
        
        <xsl:variable name="ref-qualified" as="xs:string?" select="
            if (exists($ref) and $ref != '')
            then (
                if (exists($at))
                then concat($ref, '[', $at, ']')
                else $ref
            )
            else ()
            "/>
        
        <xsl:variable name="instance-id" as="xs:string" select="xforms:getInstanceId($ref)"/>
        <!-- override tunnel variable $instanceXML if $refz refers to a different instance -->
        <xsl:variable name="instanceXML2" as="element()?">
            <xsl:choose>
                <xsl:when test="$instance-id = $default-instance-id and exists($instanceXML)">
                    <xsl:sequence select="$instanceXML"/>
                </xsl:when>
                <xsl:when test="exists($ref-qualified)">
                    <xsl:sequence select="xforms:getInstance-JS($ref-qualified)"/>
                </xsl:when>
                <xsl:otherwise/>
            </xsl:choose>
        </xsl:variable>
        
<!--        <xsl:message use-when="$debugMode">[applyActions] evaluating action = <xsl:value-of select="serialize($action-map)"/></xsl:message>-->
        
        <xsl:variable name="context" as="node()?">
            <xsl:choose>
                <xsl:when test="exists($ref-qualified) and not($ref-qualified = '') and exists($instanceXML2)">
                    <xsl:evaluate xpath="xforms:impose($ref-qualified)" context-item="$instanceXML2" namespace-context="$instanceXML2"/>
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
                <!--<xsl:when test="$action-name = 'refresh'">
                    <xsl:call-template name="action-refresh"/>
                </xsl:when>-->
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
        
        
<!--        <xsl:message use-when="$debugMode">[setAction] <xsl:value-of select="serialize($this)"/> ; $nodeset = '<xsl:value-of select="$nodeset"/>'; $refi = '<xsl:value-of select="$refi"/>'</xsl:message>-->
        
        <xsl:map>
            <xsl:map-entry key="'name'" select="local-name()"/>
            
            <xsl:if test="exists($this/@value)">
                <xsl:map-entry key="'@value'" select="string($this/@value)" />                          
            </xsl:if>
            <xsl:if test="empty($this/@value) and exists(./text())">
                <xsl:map-entry key="'value'" select="string(.)" />                         
            </xsl:if>
            
            <xsl:map-entry key="'@ref'" select="$refi"/>
            
            <!-- 
                for @at and @position,
                see https://www.w3.org/TR/xforms11/#action-insert
            -->
            <xsl:if test="exists($this/@position)">
                <xsl:map-entry key="'@position'" select="string($this/@position)" />
            </xsl:if>
            <xsl:if test="exists($this/@at)">
                <xsl:map-entry key="'@at'" select="string($this/@at)" />
            </xsl:if>
            
            <!-- https://www.w3.org/TR/xforms11/#action-conditional -->
            <xsl:if test="exists($this/@if)">
                <xsl:map-entry key="'@if'" select="string($this/@if)" />
            </xsl:if>
            
            <!-- https://www.w3.org/TR/xforms11/#action-iterated -->
            <xsl:if test="exists($this/@while)">
                <xsl:map-entry key="'@while'" select="string($this/@while)" />
            </xsl:if>
            
            <xsl:if test="exists($this/@*:event)">
                <xsl:map-entry key="'@event'" select="string($this/@*:event)" />
            </xsl:if>
            <xsl:if test="exists($this/@submission)">
                <xsl:map-entry key="'@submission'" select="string($this/@submission)" />
            </xsl:if>
            
            <xsl:if test="exists($this/@model)">
                <xsl:map-entry key="'@model'" select="string($this/@model)" />
            </xsl:if>
            
            <xsl:if test="exists($this/@control)">
                <xsl:map-entry key="'@control'" select="string($this/@control)" />
            </xsl:if>
            
            <xsl:if test="exists($this/@repeat)">
                <xsl:map-entry key="'@repeat'" select="string($this/@repeat)" />
            </xsl:if>
            
            <xsl:if test="exists($this/@index)">
                <xsl:map-entry key="'@index'" select="string($this/@index)" />
                
                
            </xsl:if>
            
            <xsl:if test="exists($this/@origin)">
                <xsl:variable name="origin-context" as="xs:string" select="
                    if (exists($this/@context)) 
                    then xforms:resolveXPathStrings($nodeset,$this/@context)
                    else $nodeset"/>
                
                <xsl:variable name="origin-ref" as="xs:string" select="xforms:resolveXPathStrings($origin-context,$this/@origin)"/>
                
                <xsl:map-entry key="'@origin'" select="$origin-ref" />    
            </xsl:if>
            
            <!-- need to apply nested actions in order! -->            
            <xsl:if test="$this/child::*">
                <xsl:map-entry key="'nested-actions'">
                    <xsl:variable name="array" as="map(*)*">
                        <xsl:for-each select="$this/child::*">
                            <xsl:apply-templates select="." mode="#default"/>
                        </xsl:for-each>
                    </xsl:variable>
                    <xsl:sequence select="array{$array}" />
                 </xsl:map-entry>
            </xsl:if>
            
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
            
            <!--<xsl:for-each-group select="$this/child::*" group-by="local-name()">
                <xsl:apply-templates select="." mode="xforms-action-map"/>
            </xsl:for-each-group> -->         
            
        </xsl:map>
        
        
        
    </xsl:template>
   
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of <a href="https://www.w3.org/TR/xforms11/#evt-rebuild">xforms-rebuild event</a></xd:p>
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
            <xd:p>Implementation of <a href="https://www.w3.org/TR/xforms11/#evt-recalculate">xforms-recalculate event</a></xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:template name="xforms-recalculate">
        <xsl:message use-when="$debugMode">[xforms-recalculate] START</xsl:message>
        <xsl:variable name="instance-keys" select="js:getInstanceKeys()" as="item()*"/>
        <xsl:variable name="calculationMap" select="js:getCalculationMap()" as="map(xs:string,xs:string)"/>
        
        <xsl:variable name="instances-with-calculations" as="map(xs:string,map(*)*)">
            <xsl:map>
                <xsl:for-each-group select="map:keys($calculationMap)" group-by="xforms:getInstanceId(.)">
                    <xsl:map-entry key="fn:current-grouping-key()" select="fn:current-group()"/>
                </xsl:for-each-group>
            </xsl:map>
        </xsl:variable>
        
        <xsl:for-each select="map:keys($instances-with-calculations)">
            <xsl:variable name="instanceXML" as="element()" select="xforms:instance(.)"/>
            
            <xsl:variable name="calculations" as="map(xs:string,xs:string)*" select="map:get($instances-with-calculations,.)"/>
            
            <!-- sequence of nodes affected by calculations -->
            <xsl:variable name="calculated-nodes" as="node()*">
                <xsl:for-each select="map:keys($calculations)">
                    <xsl:evaluate xpath="xforms:impose(.)" context-item="$instanceXML" namespace-context="$instanceXML"/>
                </xsl:for-each>
            </xsl:variable>
            
            <!-- sequence of new vaues for those nodes -->
            <xsl:variable name="calculated-values" as="xs:string*">
                <xsl:for-each select="map:keys($calculations)">
                    <!-- handle possibility that evaluation will return null -->
                    <xsl:variable name="value" as="xs:string?">
                        <xsl:evaluate xpath="xforms:impose(map:get($calculations,.))" context-item="$instanceXML" namespace-context="$instanceXML"/>
                    </xsl:variable>
                    <!-- 
                        return at least an empty string
                        need to preserve sequence in step with calculated-nodes
                    -->
                    <xsl:sequence select="($value,'')[1]"/>
                </xsl:for-each>
            </xsl:variable>
            
            <xsl:variable name="updatedInstanceXML" as="element()">
                <xsl:apply-templates select="$instanceXML" mode="recalculate">
                    <xsl:with-param name="updated-nodes" select="$calculated-nodes"/>
                    <xsl:with-param name="updated-values" select="$calculated-values"/>
                </xsl:apply-templates>
            </xsl:variable>
            
            <xsl:sequence select="js:setInstance(.,$updatedInstanceXML)"/>
            
        </xsl:for-each>
        
        <xsl:call-template name="refreshOutputs-JS"/>
        <xsl:call-template name="refreshRepeats-JS"/>
        <xsl:call-template name="refreshElementsUsingIndexFunction-JS"/>
         
                
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
<!--        <xsl:variable name="instanceXML" as="element()" select="xforms:getInstance-JS($refi)"/>-->
        <!--<xsl:variable name="updatedInstanceXML" as="element()">
            <xsl:apply-templates select="$instanceXML" mode="form-check-initial">
                <xsl:with-param name="instance-id" select="$instance-id"/>
            </xsl:apply-templates>
        </xsl:variable>-->
        
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
 

        <xsl:sequence select="xforms:setInstance-JS($refi,$updatedInstanceXML)"/>
        
        
        <!-- clear updates -->
        <xsl:variable name="pendingInstanceUpdates" as="map(xs:string, xs:string)" select="map{}"/>       
        <xsl:variable name="instanceUpdates" as="map(xs:string, xs:string)" select="map{}"/>
        
        <xsl:sequence select="js:setPendingUpdates($pendingInstanceUpdates)"/>
        <xsl:sequence select="js:setUpdates($instanceUpdates)"/>        
        
        <xsl:for-each select="$actions">
            <xsl:variable name="action-map" select="."/>
                        
            <xsl:if test="map:contains($action-map,'@event')">
                <xsl:if test="map:get($action-map,'@event') = 'xforms-value-changed'">
                    
                    <xsl:call-template name="applyActions">
                        <xsl:with-param name="action-map" select="$action-map" tunnel="yes"/>
                        <xsl:with-param name="nodeset" as="xs:string" select="$refi" tunnel="yes"/>
                        <xsl:with-param name="instanceXML" as="element()" select="$updatedInstanceXML" tunnel="yes"/>
                    </xsl:call-template>
                </xsl:if>
            </xsl:if>
        </xsl:for-each>

        <xsl:call-template name="xforms-recalculate"/>

        <xsl:sequence select="xforms:checkRelevantFields($refElement)"/>
        
    </xsl:template>
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Implementation of <a href="https://www.w3.org/TR/xforms11/#evt-focus">xforms-focus event</a></xd:p>
        </xd:desc>
        <xd:param name="control">Identifier of a form control to give focus to.</xd:param>
    </xd:doc>
    <xsl:template name="xforms-focus">
        <xsl:param name="control" as="xs:string"/>
        <xsl:variable name="xforms-control" as="element()" select="$xforms-doc//*[@id = $control]"/>
        
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
        
        <xsl:variable name="refi" as="xs:string?" select="map:get($submission-map,'@ref')"/>
        
        <xsl:variable name="instance-id" as="xs:string">
            <xsl:choose>
                <xsl:when test="map:get($submission-map,'@instance')">
                    <xsl:sequence select="map:get($submission-map,'@instance')"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="$default-instance-id"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
<!--        <xsl:message use-when="$debugMode">[xforms-submit] Submitting data for instance '<xsl:sequence select="$instance-id"/>'</xsl:message>-->
        
       <!-- <xsl:variable name="instanceXML" as="element()" select="
            if ($refi)
            then xforms:getInstance-JS($refi) 
            else xforms:instance($instance-id)"/>
        
        <xsl:variable name="updatedInstanceXML" as="element()">
            <xsl:apply-templates select="$instanceXML" mode="form-check-initial">
                <xsl:with-param name="instance-id" select="$instance-id"/>
            </xsl:apply-templates>
        </xsl:variable>-->
        
        <xsl:variable name="instanceXML" as="element()" select="xforms:instance($instance-id)"/>
        <xsl:variable name="data-fields" as="element()*" select="ixsl:page()//*[self::input or self::select or self::textarea][exists(@data-ref)][xforms:getInstanceId(@data-ref) = $instance-id]"/>
        
        <!-- sequence of nodes involved in submission -->
        <xsl:variable name="calculated-nodes" as="node()*">
            <xsl:for-each select="$data-fields">
                <xsl:evaluate xpath="xforms:impose(fn:string(@data-ref))" context-item="$instanceXML" namespace-context="$instanceXML"/>
            </xsl:for-each>
        </xsl:variable>
        
        <!-- sequence of new vaues for those nodes -->
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
        
        <xsl:variable name="updatedInstanceXML" as="element()">
            <xsl:apply-templates select="$instanceXML" mode="recalculate">
                <xsl:with-param name="updated-nodes" select="$calculated-nodes"/>
                <xsl:with-param name="updated-values" select="$calculated-values"/>
            </xsl:apply-templates>
        </xsl:variable>
        
        
        <xsl:variable name="required-fieldsi" select="ixsl:page()//*[@data-required]" as="item()*"/>
        
        <xsl:variable name="required-fields-check" as="item()*" select="xforms:check-required-fields($updatedInstanceXML)"/>
        
       <!-- <xsl:message use-when="$debugMode">[xforms-submit] Submitting instance XML: <xsl:value-of select="serialize($instanceXML)"/></xsl:message>
        <xsl:message use-when="$debugMode">[xforms-submit] Updated instance XML: <xsl:value-of select="serialize($updatedInstanceXML)"/></xsl:message>-->
        
        <xsl:choose>
            <xsl:when test="empty($required-fields-check)">
                <xsl:variable name="requestBodyXML" as="node()">
                    <xsl:choose>
                        <xsl:when test="$refi">
                            <xsl:evaluate xpath="xforms:impose($refi)" context-item="$instanceXML" namespace-context="$instanceXML"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:sequence select="$instanceXML"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                
                <xsl:variable name="requestBody">
                    <xsl:sequence select="serialize($requestBodyXML)"/>
                </xsl:variable>
                <!--<xsl:variable name="requestBodyDoc" as="document-node()?">
                    <xsl:choose>
                        <xsl:when test="$requestBodyXML[self::element()]">
                            <xsl:document>
                                <xsl:sequence select="$requestBodyXML"/>
                            </xsl:document>
                        </xsl:when>
                        <xsl:otherwise/>
                    </xsl:choose>
                </xsl:variable>-->
                <xsl:variable name="requestBodyDoc" as="document-node()">
                    <xsl:document>
                        <xsl:sequence select="$requestBodyXML"/>
                    </xsl:document>
                </xsl:variable>
                <xsl:variable name="method" as="xs:string" select="map:get($submission-map,'@method')"/>
                
                <xsl:variable name="serialization" as="xs:string?" select="map:get($submission-map,'@serialization')"/>
                
                <xsl:variable name="query-parameters" as="xs:string?">
                    <xsl:if test="exists($serialization) and $serialization = 'application/x-www-form-urlencoded'">
                        <xsl:variable name="parts" as="xs:string*">
                            <xsl:for-each select="$requestBodyXML/*">
                                <xsl:variable name="query-part" as="xs:string" select="concat(name(),'=',string())"/>
                                <xsl:sequence select="$query-part"/>
                                <xsl:message use-when="$debugMode">[xforms-submit] Query part: <xsl:value-of select="$query-part"/></xsl:message>
                                
                            </xsl:for-each>
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
                            <!--<xsl:choose>
                                <xsl:when test="exists($requestBodyDoc)">
                                    <xsl:map-entry key="'body'" select="$requestBodyDoc"/>       
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:map-entry key="'body'" select="$requestBody"/>
                                </xsl:otherwise>
                            </xsl:choose>-->
                            <xsl:map-entry key="'body'" select="$requestBodyDoc"/>  
                        </xsl:if>
                        <xsl:map-entry key="'method'" select="$method"/>
                        <xsl:map-entry key="'href'" select="$href"/>
                        <xsl:map-entry key="'media-type'" select="$mediatype"/>
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
                    </xsl:call-template>
                </ixsl:schedule-action>
                
                <xsl:for-each select="$actions">
                    <xsl:variable name="action-map" select="."/>
                    
                    <!-- https://www.w3.org/TR/xslt-30/#func-map-contains -->
                    <xsl:if test="map:contains($action-map,'@event')">
                        <xsl:if test="map:get($action-map,'@event') = 'xforms-submit-done'">
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
        
        <!--<xsl:variable name="instanceXML" as="element()?" select="xforms:getInstance-JS($refi)"/>
                
        <xsl:variable name="updatedInstanceXML" as="element()?">
           <xsl:if test="exists($instanceXML)">
               <xsl:apply-templates select="$instanceXML" mode="form-check-initial">
                   <xsl:with-param name="instance-id" select="$instance-id"/>
               </xsl:apply-templates>
           </xsl:if>
        </xsl:variable>-->
        
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
                    <xsl:sequence select="$instanceXML"></xsl:sequence>
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
                    <xsl:variable name="contexti" as="node()">
                        <xsl:evaluate xpath="xforms:impose($nodeset)" context-item="$instanceXML" namespace-context="$instanceXML" as="node()" />
                    </xsl:variable>
                    <xsl:sequence>
                        <xsl:evaluate xpath="xforms:impose(map:get($action-map,'@value'))" context-item="$contexti" namespace-context="$contexti" />
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
        
        <!-- TODO: use ifVari and WhileVari -->
        <xsl:if test="exists($refz)">
            <xsl:variable name="associated-form-control"
                select="ixsl:page()//*[@data-ref = $refz]" as="node()?"/>
            <xsl:choose>
                <xsl:when test="exists($associated-form-control)">
                    <xsl:apply-templates select="$associated-form-control" mode="set-field">
                        <xsl:with-param name="value" select="xs:string($valuez)" tunnel="yes"/>
                    </xsl:apply-templates>                    
                    <xsl:sequence select="js:setUpdates(map:put(js:getUpdates(),$refz , xs:string($valuez)))" />
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
        <xsl:variable name="origin-ref" select="map:get($action-map, '@origin')" as="xs:string?"/>
        
        
        <xsl:variable name="ref-qualified" as="xs:string?" select="
            if (exists($ref) and $ref != '')
            then (
            if (exists($at))
            then concat($ref, '[', $at, ']')
            else $ref
            )
            else ()
            "/>
        
        <xsl:variable name="instance-id" as="xs:string" select="xforms:getInstanceId($ref)"/>
        <!-- override tunnel variable $instanceXML if $origin-ref refers to a different instance -->
        <xsl:variable name="instanceXML2" as="element()">
            <xsl:choose>
                <xsl:when test="$instance-id = $default-instance-id and exists($instanceXML)">
                    <xsl:sequence select="$instanceXML"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="xforms:instance($instance-id)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:variable name="instance-id-origin" as="xs:string" select="xforms:getInstanceId($origin-ref)"/>
        <!-- override tunnel variable $instanceXML if $map-ref refers to a different instance -->
        <xsl:variable name="instanceXML-origin" as="element()">
            <xsl:choose>
                <xsl:when test="$instance-id-origin = $default-instance-id and exists($instanceXML)">
                    <xsl:sequence select="$instanceXML"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="xforms:instance($instance-id-origin)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        
                
<!--        <xsl:message use-when="$debugMode">[action-insert] $nodeset = '<xsl:value-of select="$nodeset"/>'; $ref = '<xsl:value-of select="$ref"/>'; inserting node at XPath <xsl:value-of select="$ref-qualified"/></xsl:message>-->
       
        <!-- 
                    get node to insert using getReferencedInstanceField
                -->
        <xsl:variable name="origin-node" as="node()?">
            <xsl:evaluate xpath="xforms:impose($origin-ref)" context-item="$instanceXML-origin" namespace-context="$instanceXML-origin"/>
        </xsl:variable>
         
        <xsl:variable name="insert-node-location" as="node()">
            <xsl:evaluate xpath="xforms:impose($ref-qualified)" context-item="$instanceXML2" namespace-context="$instanceXML2"/>
        </xsl:variable> 
        
        <!--<xsl:message use-when="$debugMode">[action-insert] $insert-node-location = <xsl:value-of select="fn:serialize($insert-node-location)"/></xsl:message>
        <xsl:message use-when="$debugMode">[action-insert] $origin-node = <xsl:value-of select="fn:serialize($origin-node)"/></xsl:message>-->
        
       
        
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
                <xsl:with-param name="insert-node-location" select="$insert-node-location" tunnel="yes"/>
                <xsl:with-param name="node-to-insert" select="$node-to-insert" tunnel="yes"/>
                <xsl:with-param name="position-relative" select="$position" tunnel="yes"/>
            </xsl:apply-templates>
        </xsl:variable>
        
<!--        <xsl:message use-when="$debugMode">[action-insert] Updated instance: <xsl:sequence select="fn:serialize($instance-with-insert)"/></xsl:message>-->
        
        <xsl:sequence select="xforms:setInstance-JS($ref,$instance-with-insert)"/>
        
        
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
        
        

<!--        <xsl:call-template name="xforms-rebuild"/>-->
        <xsl:call-template name="xforms-recalculate"/>
        
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
                    <xsl:sequence select="xforms:instance($instance-id)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:variable name="ifVar" select="xforms:getIfStatement($action-map)"/>
        <xsl:variable name="whileVar" select="xforms:getWhileStatement($action-map)"/>
         
        <xsl:variable name="delete-node" as="node()?">
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
            
            <xsl:sequence select="xforms:setInstance-JS($ref,$instance-with-delete)"/>    
            
            <!-- set index -->
            <xsl:if test="matches($at,'index\s*\(')">
                <xsl:variable name="repeat-id" as="xs:string?" select="xforms:getRepeatID($at)"/>
                <xsl:variable name="at-position" as="xs:integer">
                    <xsl:evaluate xpath="xforms:impose($at)"/>
                </xsl:variable>
                
                <xsl:if test="exists($repeat-id)">
                    <xsl:variable name="repeat-size" as="xs:double" select="js:getRepeatSize($repeat-id)"/>
                    
                    <xsl:message use-when="$debugMode">[action-delete] Size of repeat '<xsl:value-of select="$repeat-id"/>' is <xsl:value-of select="$repeat-size"/>, index is <xsl:value-of select="$at-position"/></xsl:message>
                    
                    <xsl:choose>
                        <xsl:when test="$at-position = $repeat-size">
                            <!-- adjust index if it is now out of bounds -->
                            <xsl:sequence select="js:setRepeatIndex($repeat-id, $repeat-size - 1)"/>
                        </xsl:when>
                        <xsl:otherwise/>
                    </xsl:choose>
                </xsl:if>
                
            </xsl:if>
            
            
            <xsl:call-template name="xforms-recalculate"/>
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
        <!-- TO DO: implement remainder of this action -->
    </xsl:template>
 
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Template for applying setfocus action</xd:p>
        </xd:desc>
        <xd:param name="action-map">Action map</xd:param>
    </xd:doc>
    <xsl:template name="action-setfocus">
        <xsl:param name="action-map" required="yes" as="map(*)" tunnel="yes"/>
        
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
        
        <xsl:variable name="repeatID" as="xs:string" select="map:get($action-map,'@repeat')"/>
        <xsl:variable name="new-index-ref" as="xs:string" select="map:get($action-map,'@index')"/>
        
                
        <xsl:variable name="new-index" as="xs:integer">
            <xsl:evaluate xpath="xforms:impose($new-index-ref)"/>
        </xsl:variable>
        
        <xsl:message use-when="$debugMode">[action-setindex] $action-map = <xsl:value-of select="serialize($action-map)"/></xsl:message>
        
        <xsl:sequence select="js:setRepeatIndex($repeatID,$new-index)"/>
        
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
    </xsl:template>
    
</xsl:stylesheet>