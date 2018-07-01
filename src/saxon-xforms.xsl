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
    xmlns:ev="http://www.w3.org/2001/xml-events" exclude-result-prefixes="xs math xforms sfl"
    extension-element-prefixes="ixsl saxon" version="3.0">
    
    <xsl:include href="xforms-function-library.xsl"/>

    <xsl:output method="html" encoding="utf-8" omit-xml-declaration="no" indent="no"
        doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN"
        doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"/>

    <xsl:param name="xforms-instance-id" select="'xforms-jinstance'"/>
    <xsl:param name="xforms-cache-id" select="'xforms-cache'"/>
    
    <!-- @id attribute of HTML div element into which the XForm is to be rendered on the page -->
    <xsl:param name="xform-html-id" as="xs:string" select="'xForm'"/>
    
    <xsl:variable static="yes" name="debugMode" select="true()"/>
    <xsl:variable static="yes" name="debugTiming" select="false()"/>
    <xsl:variable static="yes" name="default-instance-id" select="'saxon-forms-default'" as="xs:string"/>


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
        <xd:param name="xFormsId">The @id of an HTML dov on the page into which the XForm will be rendered.</xd:param>
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
        
        <xsl:param name="xFormsId" select="$xform-html-id" as="xs:string"/>

        <xsl:variable name="xforms-doci"
            select="
                if (empty($xforms-doc)) then
                    doc($xforms-file)
                else
                    $xforms-doc"
            as="document-node()?"/>

        <!-- all xforms:instance elements in the XForm -->
        <xsl:variable name="xforms-instances" as="map(xs:string, element())">
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
           
        </xsl:variable>
        
        
        <!-- register all bindings in model as a map -->
        <xsl:variable name="bindings" as="map(xs:string, node())">
            <xsl:map>
                <xsl:for-each select="$xforms-doci/xforms:xform/xforms:model/xforms:bind">
                    <!-- [exists(@type)] -->
                    <xsl:map-entry
                        key="
                            xs:string(if (exists(@id)) then
                                @id
                            else
                                @nodeset)"
                        select="."/>
                </xsl:for-each>
            </xsl:map>
        </xsl:variable>
        
        <!-- register submissions in a map -->
        <xsl:variable name="submissions" as="map(xs:string, xs:string)">
            <xsl:map>
                <xsl:for-each select="$xforms-doci/xforms:xform/xforms:model/xforms:submission">
                    <!-- 
                        MD 2018
                        
                        @id and @resource preferred in XForms 1.1 
                        https://www.w3.org/TR/xforms11/#submit
                        
                        How best to fall back to an error message if the key/value pair are not present?
                    -->
                    <xsl:variable name="map-key" as="xs:string" select="
                        if (@id) then xs:string(@id)
                        else if (@ref) then xs:string(@ref)
                        else 'null'
                        "/>
                    <xsl:variable name="map-value" as="xs:string" select="
                        if (@resource) then xs:string(@resource)
                        else if (@action) then xs:string(@action)
                        else 'null'
                        "/>
                    <xsl:map-entry key="$map-key" select="$map-value"/>
                </xsl:for-each>
            </xsl:map>
        </xsl:variable>
        
        <!-- $orig-instance-doc REDUNDANT? [MD 2018] -->
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
                            
                            

                            var getOutputs = function() {
                                return outputsMap;
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
                <xsl:sequence select="js:setRelevantMap($RelevantBindings)" />
            </xsl:otherwise>
        </xsl:choose>

        
        <!-- add each instance to the Javascript variable -->
        <xsl:variable name="instanceKeys" select="map:keys($xforms-instances)" as="xs:string*"/>
        
        <xsl:for-each select="$instanceKeys">
            <xsl:variable name="instance" select="map:get($xforms-instances, .)" as="element()" />  
            <xsl:message use-when="$debugMode">Setting instance with ID '<xsl:value-of select="."/>'</xsl:message>
            <xsl:sequence select="js:setInstance(.,$instance)"/>
        </xsl:for-each>
        

        <xsl:variable name="time-id" select="generate-id()"/>
        <xsl:sequence use-when="$debugTiming" select="js:startTime(concat('XForms Main-Build', $time-id))" />
        
        <xsl:result-document href="#{$xFormsId}" method="ixsl:replace-content">
            <xsl:apply-templates select="$xforms-doci/xforms:xform">
                <xsl:with-param name="instances" select="$xforms-instances" as="map(xs:string, element())" tunnel="yes"/>
                <xsl:with-param name="bindings" select="$bindings" as="map(xs:string, node())" tunnel="yes"/>
                <xsl:with-param name="submissions" select="$submissions" as="map(xs:string, xs:string)" tunnel="yes"/>
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
        
        <xsl:variable name="updatedInstanceXML4" select="js:getInstance()"/>
        
        <xsl:for-each select="$relevantFields">
            <xsl:variable name="keyi" select="."/>
            <xsl:variable name="context" select="ixsl:page()//*[@data-ref = $keyi]"/>
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
        <xd:desc>Handle change to HTML input</xd:desc>
    </xd:doc>
    <xsl:template match="input[exists(@data-action)]" mode="ixsl:onkeyup">
        <xsl:variable name="refi" select="@data-ref"/>
        <xsl:variable name="refElement" select="@data-element"/>
        
        <xsl:variable name="instance-id" as="xs:string" select="xforms:getInstanceId($refi)"/>
        <xsl:variable name="xforms-value-change" select="js:getAction(string(@data-action))"/>
        
        <!-- MD 2018-06-29: handle multiple instances -->
        <xsl:variable name="instanceXML" as="element()" select="xforms:getInstance-JS($refi)"/>
        <xsl:variable name="updatedInstanceXML">
<!--            <xsl:variable name="instanceXML" select="js:getInstance()"/>-->
            <xsl:apply-templates select="$instanceXML" mode="form-check-initial">
                <xsl:with-param name="instance-id" select="$instance-id"/>
            </xsl:apply-templates>
        </xsl:variable>
<!--        <xsl:sequence select="js:setInstance($updatedInstanceXML)"/>-->
        <xsl:sequence select="xforms:setInstance-JS($refi,$updatedInstanceXML)"/>
        
        
        
        <xsl:variable name="pendingInstanceUpdates" as="map(xs:string, xs:string)" select="map{}"/>
        
        <xsl:variable name="instanceUpdates" as="map(xs:string, xs:string)" select="map{}"/>
        
        <xsl:sequence select="js:setPendingUpdates($pendingInstanceUpdates)"/>
        <xsl:sequence select="js:setUpdates($instanceUpdates)"/>
        
        <xsl:message use-when="$debugMode">
            [HTML input] input detected onchange event, ref= <xsl:value-of select="$refi"/>, actions = <xsl:value-of select="serialize($xforms-value-change)"/>            
        </xsl:message>
        
        <xsl:message use-when="$debugMode">
            [HTML input] instance: <xsl:value-of select="serialize($instanceXML)"/>
        </xsl:message>
        <xsl:message use-when="$debugMode">
            [HTML input] updated instance: <xsl:value-of select="serialize($updatedInstanceXML)"/>
        </xsl:message>
        
        
        <xsl:for-each select="$xforms-value-change">
            <xsl:variable name="action-map" select="."/>
            
            <xsl:variable name="ref" select="map:get($action-map, '@ref')"/>
            
            <xsl:message use-when="$debugMode">
                input-changed evalute ref = <xsl:value-of select="$ref"/>, 
                position = <xsl:value-of select="position()"/>,
                action <xsl:value-of select="serialize($action-map)"/>
            </xsl:message>

            <xsl:variable name="context" as="node()?">
                <xsl:evaluate xpath="xforms:impose($ref)" context-item="$updatedInstanceXML"/>
            </xsl:variable>
            
            <!-- TODO error testing of incorrect ref given in the xform (i.e. context would be empty in this case) -->

            <xsl:variable name="ifVar" select="xforms:getIfStatement($action-map)"/>

            <xsl:variable name="whileVar" select="xforms:getWhileStatement($action-map)"/>

            <!-- TODO if the action does not contain an if or while it should execute action -->

                <xsl:variable name="ifExecuted" as="xs:boolean">
                    <xsl:choose>
                        <xsl:when test="exists($ifVar)">
                            <xsl:evaluate xpath="$ifVar" context-item="$context"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:sequence select="true()" />
                        </xsl:otherwise>
                    </xsl:choose>                    
                </xsl:variable>
            
                <xsl:if test="$ifExecuted">
                    <!-- MD 2018-06-30 -->
                    <xsl:call-template name="refreshOutputs-JS"/>

                    <!-- <xsl:message use-when="$debugMode">if statement true <xsl:value-of select="serialize($action-map)"/></xsl:message> -->
                    <xsl:variable name="setvalueVar" select="map:find($action-map, 'setvalue')"/>
                    <xsl:if test="exists($setvalueVar)">
                        <xsl:variable name="setValues" as="item()*">
                            <xsl:sequence select="array:flatten(map:get($action-map, 'setvalue'))"/>
                        </xsl:variable>
                        <!-- <xsl:message use-when="$debugMode">
                            instance <xsl:value-of select="serialize($updatedInstanceXML)"/>
                            setValues <xsl:value-of select="serialize(array:flatten($setValues))"/></xsl:message> -->

                        <xsl:for-each select="array:flatten($setValues)">
                            <xsl:variable name="ifVari" select="xforms:getIfStatement(.)"/>
                            <xsl:variable name="whileVari" select="xforms:getWhileStatement(.)"/>
                            <xsl:variable name="refz" select="xforms:resolveXPathStrings($refi,.?ref)"/>
                            <xsl:variable name="valuez">
                                <xsl:choose>
                                    <xsl:when test="map:contains(.,'@value')">
                                        <xsl:message use-when="$debugMode">
                                            $refi = <xsl:value-of select="$refi"/>
                                            @value <xsl:value-of select="xforms:resolveXPathStrings($refi,map:get(.,'@value'))"/>
                                        </xsl:message>
                                        <xsl:variable name="contexti" as="node()">
                                            <xsl:evaluate xpath="$refi" context-item="$updatedInstanceXML" as="node()" />
                                        </xsl:variable>
                                        <xsl:sequence>
                                            <xsl:evaluate xpath="map:get(.,'@value')" context-item="$contexti" />
                                        </xsl:sequence>
                                    </xsl:when>
                                    <xsl:when test="map:contains(.,'value')">
                                        <xsl:sequence select="xs:string(.?value)"/>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:sequence select="''"/> 
                                    </xsl:otherwise>
                                </xsl:choose>
                                
                            </xsl:variable>
                            <xsl:message use-when="$debugMode"> 
                                refi = <xsl:value-of select="$refi"/>
                                refz = <xsl:value-of select="$refz"/>
                            </xsl:message>
                            <xsl:message use-when="$debugMode"> 
                                value = <xsl:value-of select="xs:string($valuez)"/> 
                            </xsl:message> 

                            <!-- use ifVari and WhileVari -->
                            <xsl:if test="exists($refz)">
                                <xsl:variable name="associated-form-control"
                                    select="ixsl:page()//*[@data-ref = $refz]" as="node()?"/>
                                <xsl:message use-when="$debugMode"> $associated-form-control = <xsl:value-of select="serialize($associated-form-control)"/> </xsl:message>
                                <xsl:choose>
                                    <xsl:when test="exists($associated-form-control)">
                                        <xsl:apply-templates select="$associated-form-control"
                                            mode="set-field">
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



                        </xsl:for-each>
                        <xsl:if test="count(array:flatten($setValues)) gt 0">
                            <xsl:variable name="pendingUpdates" select="js:getPendingUpdates()" as="map(xs:string, xs:string)?"/>
                            
                            <xsl:variable name="updatedInstanceXML3">                                
                                <xsl:apply-templates select="$updatedInstanceXML" mode="form-check-initial">
                                    <xsl:with-param name="pendingUpdates" as="map(xs:string,xs:string)?" select="$pendingUpdates" />
                                </xsl:apply-templates>
                            </xsl:variable>
                            
                            <!-- MD 2018-06-29: handle multiple instances -->
                            <!--                            <xsl:sequence select="js:setInstance($updatedInstanceXML3)" />-->
                            <xsl:sequence select="xforms:setInstance-JS($refi,$updatedInstanceXML3)"/>
                            
                        </xsl:if>
                    </xsl:if>
                </xsl:if>
            

        </xsl:for-each>
        
        <!-- MD 2018-02-29: handle multiple instances -->
        <!--<xsl:message use-when="$debugMode">
            instance before checkRelevantFields= <xsl:value-of select="serialize(js:getInstance())"/>
        </xsl:message>-->
        <xsl:message use-when="$debugMode">
            instance before checkRelevantFields = <xsl:value-of select="serialize(xforms:getInstance-JS($refi))"/>
        </xsl:message>
        
        
        <xsl:sequence select="xforms:checkRelevantFields($refElement)"/>

        <!--<xsl:variable name="updatedInstanceXML2">
            <xsl:variable name="instanceXML" select="js:getInstance()"/>
            <xsl:apply-templates select="$instanceXML" mode="form-check-initial"/>
        </xsl:variable>
        
        <xsl:sequence select="js:setInstance($updatedInstanceXML2)"/> -->
       
       <!-- MD 2018-06-29: this was here to refresh the page when an instance was updated
       
       But we want to refresh individual pieces as appropriate
       -->
        <!--<xsl:call-template name="xformsjs-main">
            <xsl:with-param name="xforms-doc" select="js:getXFormsDoc()"/>
            <xsl:with-param name="instance-xml" select="$updatedInstanceXML2"/>
            <xsl:with-param name="xFormsId" select="js:getXFormsID()"/>
            <xsl:with-param name="updateMode" tunnel="yes" select="true()"/>
        </xsl:call-template>-->
    </xsl:template>




    <xsl:function name="xforms:getIfStatement" as="xs:string?">
        <xsl:param name="map" as="map(*)"/>
        <xsl:choose>
            <xsl:when test="map:contains($map, '@if')">
                <xsl:sequence select="map:get($map, '@if')"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:sequence select="map:get($map, '@if')"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

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
    
<!-- Only to use this function on simple path cases -->
    
    <xsl:function name="xforms:resolveXPathStrings" as="xs:string">
        <xsl:param name="base" as="xs:string"/>
        <xsl:param name="relative" as="xs:string"/>
        

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
        <xsl:message use-when="$debugMode">resolveXPathString base =<xsl:value-of select="$base"/> lastSlash <xsl:value-of select="$parentSlash"/> relative <xsl:value-of select="$relative"/> 
        
        countparent = <xsl:value-of select="$parentCallCount"/>
            <xsl:if test="$parentCallCount>0">
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

    </xsl:function>

    <xsl:template match="select[exists(@data-action)]" mode="ixsl:onchange">

        <xsl:variable name="refi" select="@data-ref"/>
        <xsl:variable name="refElement" select="@data-element"/>
        
        <!--<xsl:variable name="xforms-value-change"
            select="ixsl:page()//head/script[@data-ntype = 'xforms-value-changed' and @data-action-context = $refi]"/>-->
        <xsl:variable name="xforms-actions"
            select="js:getAction(string(@data-action))" as="map(*)*"/>
        
        <xsl:message use-when="$debugMode">action map = <xsl:sequence select="serialize($xforms-actions)" /></xsl:message>
        
        
        <!-- MD 2018-06-29: handle multiple instances -->
        <xsl:variable name="instanceXML" as="element()" select="xforms:getInstance-JS($refi)"/>
        <xsl:variable name="updatedInstanceXML">
            <!--            <xsl:variable name="instanceXML" select="js:getInstance()"/>-->
            <xsl:apply-templates select="$instanceXML" mode="form-check-initial"/>
        </xsl:variable>
        <!--        <xsl:sequence select="js:setInstance($updatedInstanceXML)"/>-->
        <xsl:sequence select="xforms:setInstance-JS($refi,$updatedInstanceXML)"/>
        
        <!--<xsl:variable name="updatedInstanceXML">
            <xsl:variable name="instanceXML" select="js:getInstance()"/>
            <xsl:apply-templates select="$instanceXML" mode="form-check-initial"/>
        </xsl:variable>-->
        
        <xsl:variable name="pendingInstanceUpdates" as="map(xs:string, xs:string)" select="map{}"/>
        <xsl:variable name="instanceUpdates" as="map(xs:string, xs:string)" select="map{}"/>
        
        <xsl:sequence select="js:setPendingUpdates($pendingInstanceUpdates)"/>
        <xsl:sequence select="js:setUpdates($instanceUpdates)"/>
        
        <xsl:message use-when="$debugMode"> select changed refi = <xsl:value-of select="$refi" />
        xforms-action <xsl:sequence select="serialize($xforms-actions)" />
        </xsl:message> 

        <xsl:for-each select="$xforms-actions">
            <xsl:variable name="action-map" select="."/>
            
            <!--<xsl:message> xforms action = <xsl:sequence select="serialize(.)" /></xsl:message>-->
             
            <xsl:variable name="ref" select="map:get($action-map, '@ref')"/>
            
            <xsl:message use-when="$debugMode"> select ref = <xsl:value-of select="$ref"/></xsl:message> 

            <xsl:variable name="context" as="node()?">
                <xsl:evaluate xpath="$ref" context-item="$updatedInstanceXML"/>
            </xsl:variable>

            <xsl:variable name="ifVar" select="map:get($action-map, '@if')"/>

            <xsl:variable name="whileVar" select="map:get($action-map, '@while')"/>
            <xsl:message use-when="$debugMode"> select ref = <xsl:value-of select="$ref"/>
            @if <xsl:value-of select="$ifVar"/>
                @while<xsl:value-of select="$whileVar"/>
            </xsl:message> 
            <!-- TODO if the action does not contain an if or while it should execute action -->

            
                
                <xsl:variable name="ifExecuted" as="xs:boolean">
                    <xsl:choose>
                        <xsl:when test="exists($ifVar)"><xsl:evaluate xpath="$ifVar" context-item="$context"/></xsl:when>
                        <xsl:otherwise>
                            <xsl:sequence select="true()" />
                        </xsl:otherwise>
                    </xsl:choose>
                    
                </xsl:variable>

                <xsl:if test="$ifExecuted">
                    <xsl:message use-when="$debugMode">
                        @if  executed <xsl:value-of select="$ifVar"/>
                        
                    </xsl:message> 
                    <!-- <xsl:message use-when="$debugMode">if statement true <xsl:value-of select="serialize($action-map)"/></xsl:message> -->
                    <xsl:variable name="setvalueVar" select="map:find($action-map, 'setvalue')"/>
                    <xsl:if test="exists($setvalueVar)">
                        <xsl:variable name="setValues" as="item()*">
                            <xsl:sequence
                                select="array:flatten(map:get($action-map, 'setvalue'))"/>
                        </xsl:variable>
                         <xsl:message use-when="$debugMode">
                            setValues <xsl:value-of select="serialize(array:flatten($setValues))"/></xsl:message> 

                        <xsl:for-each select="$setValues">
                            <xsl:variable name="ifVari" select="map:get(. , '@if')"/>
                            <xsl:variable name="ifExecutedi" as="xs:boolean">
                                <xsl:choose>
                                    <xsl:when test="exists($ifVari)"><xsl:evaluate xpath="$ifVari" context-item="$context"/></xsl:when>
                                    <xsl:otherwise>
                                        <xsl:sequence select="true()" />
                                    </xsl:otherwise>
                                </xsl:choose>
                                
                            </xsl:variable>
                            <xsl:variable name="whileVari" select="xforms:getWhileStatement(.)"/>
                            <xsl:variable name="refz"
                                select="xforms:resolveXPathStrings($refi,.?ref)"/>
                            <xsl:variable name="valuez" as="xs:string">
                                
                                <xsl:choose>
                                    <xsl:when test="map:contains(.,'@value')">
                                        <xsl:message use-when="$debugMode">
                                            @value <xsl:value-of select="xforms:resolveXPathStrings($refi,map:get(.,'@value'))"/>
                                        </xsl:message>
                                        <xsl:variable name="contexti" as="node()">
                                            <xsl:evaluate xpath="$refi" context-item="$updatedInstanceXML" as="node()" />
                                        </xsl:variable>
                                        <xsl:sequence>
                                            <xsl:evaluate xpath="map:get(.,'@value')" context-item="$contexti" as="xs:string" />
                                        </xsl:sequence>
                                    </xsl:when>
                                    <xsl:when test="map:contains(.,'value')">
                                        <xsl:sequence select="xs:string(.?value)"/>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:sequence select="''"/> 
                                    </xsl:otherwise>
                                </xsl:choose>
                                
                            </xsl:variable>
                            <xsl:message use-when="$debugMode"> ref = <xsl:value-of select="$refz"/></xsl:message>
                            <xsl:message use-when="$debugMode"> value = <xsl:value-of select="$valuez"/> </xsl:message> 

                            <!-- use ifVari and WhileVari -->
                            <xsl:if test="exists($refz) and $ifExecutedi">
                                <xsl:variable name="associated-form-control"
                                    select="ixsl:page()//*[@data-ref = $refz]" as="node()?"/>
                                <xsl:message use-when="$debugMode"> $associated-form-control = <xsl:value-of select="serialize($associated-form-control)"/> </xsl:message>
                                <xsl:choose>
                                    <xsl:when test="exists($associated-form-control)">
                                        <xsl:apply-templates select="$associated-form-control"
                                            mode="set-field">
                                            <xsl:with-param name="value" select="$valuez" tunnel="yes"/>
                                        </xsl:apply-templates>
                                        <xsl:sequence select="js:setUpdates(map:put(js:getUpdates(),$refz , xs:string($valuez)))" />
                                        <xsl:message use-when="$debugMode">
                                            <xsl:variable name="mapxx" select="js:getUpdates()" />
                                            Updates map = <xsl:sequence select="serialize($mapxx)" />
                                        </xsl:message>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <!-- update the instance -->
                                        
                                        <xsl:sequence select="js:setPendingUpdates(map:put(js:getPendingUpdates(),$refz , xs:string($valuez)))" />
                                        <xsl:message use-when="$debugMode"> update instance only ref = <xsl:value-of select="$refz"/>  </xsl:message>
                                    </xsl:otherwise>
                                </xsl:choose>
                            </xsl:if>



                        </xsl:for-each>

                    </xsl:if>
                </xsl:if>
            

        </xsl:for-each>
        <!--<xsl:variable name="updatedInstanceXML2">
            <xsl:variable name="instanceXML"
                select="xforms:convert-json-to-xml(ixsl:page()//script[@id = 'xforms-jinstance']/text())"/>
            <xsl:apply-templates select="$instanceXML" mode="form-check-initial"/>
        </xsl:variable>-->
        
        
        <!-- MD 2018-06-29: handle multiple instances -->
        <!--<xsl:variable name="updatedInstanceXML2">
            <xsl:variable name="instanceXML" select="js:getInstance()"/>
            <xsl:apply-templates select="$instanceXML" mode="form-check-initial">
                <xsl:with-param name="pendingUpdates" as="map(xs:string,xs:string)?" select="js:getPendingUpdates()" />
            </xsl:apply-templates>
        </xsl:variable>
        <xsl:sequence select="js:setInstance($updatedInstanceXML2)"/>-->
        
        <xsl:variable name="updatedInstanceXML2">                                
            <xsl:apply-templates select="$updatedInstanceXML" mode="form-check-initial">
                <xsl:with-param name="pendingUpdates" as="map(xs:string,xs:string)?" select="js:getPendingUpdates()" />
            </xsl:apply-templates>
        </xsl:variable>
        <xsl:sequence select="xforms:setInstance-JS($refi,$updatedInstanceXML2)"/>
        
        
        
        <xsl:message use-when="$debugMode">
            instance after select change <xsl:value-of select="serialize($updatedInstanceXML2)"/>
        </xsl:message>
        <xsl:sequence select="xforms:checkRelevantFields($refElement)"/>
       
    </xsl:template>


    <xsl:function name="xforms:check-required-fields" as="item()*">
        <xsl:param name="updatedInstanceXML" as="document-node()"/>

        <xsl:variable name="required-fieldsi" select="ixsl:page()//*[@data-required]" as="item()*"/>



        <xsl:for-each select="$required-fieldsi">

            <xsl:variable name="resulti">
                <xsl:evaluate
                    xpath="concat('boolean(normalize-space(', @data-ref, '))', '=', @data-ref, '/', @data-required)"
                    context-item="$updatedInstanceXML"/>
            </xsl:variable>
            <xsl:sequence
                select="
                    if ($resulti = 'false') then
                        .
                    else
                        ()"
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

    <xsl:template match="button[exists(@data-submit)]" mode="ixsl:onclick">
        <!-- XML Map rep of JSON map -->
        
        <!-- MD 2018-06-29
        Temporarily suppress this - it won't always be necessary to check and submit the instance
        For now I'm just checking the HTTP request
        -->
        <!--<xsl:variable name="instanceXML" select="js:getInstance()" as="document-node(element(Document))"/>

        <xsl:variable name="updatedInstanceXML" as="document-node(element(Document))?">
            <xsl:document>
                <xsl:apply-templates select="$instanceXML" mode="form-check-initial" />
            </xsl:document>
        </xsl:variable>

        <xsl:variable name="required-fieldsi" select="ixsl:page()//*[@data-required]" as="item()*"/>

        <xsl:variable name="required-fields-check" as="item()*" select="xforms:check-required-fields($updatedInstanceXML)"/>-->




        <xsl:variable name="action">
            <!-- MD 2018
            just use @data-submit value
            -->
<!--            <xsl:value-of select="serialize(@data-submit)"/>-->
            <xsl:value-of select="@data-submit"/>
        </xsl:variable>

        <xsl:variable name="requestBody" as="xs:string">
            <!-- MD 2018-06-29: test submission -->
            <xsl:variable name="test-submission" as="element()">
                <TEST>
                    <surname>Dunn</surname>
                </TEST>
            </xsl:variable>
            <xsl:sequence select="serialize($test-submission)"/>
            
<!--            <xsl:sequence select="serialize($updatedInstanceXML/Document)"/>-->
        </xsl:variable>
        
       <!-- <xsl:variable name="requestBody" as="document-node(element(submit))">
                  <xsl:document>
                      <submit>
                          <xsl:sequence select="$updatedInstanceXML/Document"/>

                      </submit>
                  </xsl:document>
              </xsl:variable>-->

        <xsl:choose>
            <!-- MD 2018-06-29: just check submission -->
            <xsl:when test="true()">
            <!--<xsl:when test="count($required-fields-check) = 0">-->
                <!-- <xsl:sequence
                    select="js:submitXMLorderWithUrl(serialize($action), serialize($updatedInstanceXML), 'orderResponse')"
                /> -->
                <xsl:message>
                    Sending HTTP request to '<xsl:value-of select="$action"/>'
                </xsl:message>
                
                <xsl:variable name="HTTPrequest" as="map(*)"
                          select="map{'body':$requestBody,
                         'method':'POST',
                         'href':$action,
                         'media-type':'text/plain'}"/>

                <ixsl:schedule-action http-request="$HTTPrequest">
                         <!-- The value of @http-request is an XPath expression, which evaluates to an 'HTTP request
                            map' - i.e. our representation of an HTTP request as an XDM map -->
                         <xsl:call-template name="HTTPsubmit"/>
                      </ixsl:schedule-action>


            </xsl:when>
            <xsl:otherwise>
                <!-- MD 2018-06-29: just check submission -->
                <!--<xsl:variable name="error-message">
                    <xsl:for-each select="$required-fields-check">
                        <xsl:variable name="curNode" select="."/>

                        <xsl:value-of
                            select="concat('Value error see: ', serialize($curNode/@data-ref), '&#10;')"/>

                    </xsl:for-each>
                </xsl:variable>
                <xsl:sequence select="ixsl:call(ixsl:window(), 'alert', [serialize($error-message)])"/>-->
            </xsl:otherwise>
        </xsl:choose>



    </xsl:template>

    <xsl:template name="HTTPsubmit">
         <!-- The context item should be an 'HTTP response map' - i.e. our representation of an HTTP
            response as an XDM map.
           ?body is an XML document. -->
         <xsl:context-item as="map(*)" use="required"/>
          <xsl:variable name="responseXML" select="?body"/>
        
        <!-- MD 2018: just seeing what a response looks like -->
        <xsl:variable name="response" select="."/>
        <xsl:message>Response: <xsl:value-of select="serialize($response)" /></xsl:message>

          <xsl:choose>
              <xsl:when test="empty($responseXML)">
                  <xsl:call-template name="serverError">
                      <xsl:with-param name="responseMap" select="."/>
                  </xsl:call-template>
              </xsl:when>


              <xsl:otherwise>
                  <xsl:message>Response: <xsl:value-of select="serialize($responseXML)" /></xsl:message>

              </xsl:otherwise>
          </xsl:choose>
        
        
      </xsl:template>

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
        <xd:desc>Implementation of XForms <a href="https://www.w3.org/TR/xforms11/#ui-output">output element</a></xd:desc>
    </xd:doc>
    <xsl:template match="xforms:output">
        
        <xsl:variable name="myid"
            select=" if (exists(@id)) then @id else generate-id() "/>
        
         
        <!-- get xforms:bind element relevant to this -->
        <xsl:variable name="bindingi" as="node()?">
            <xsl:call-template name="getBinding">
                <xsl:with-param name="this" select="."/>
            </xsl:call-template>
        </xsl:variable>
        
        <xsl:message use-when="$debugMode">[xforms:output] bindingi: <xsl:value-of select="serialize($bindingi)"/></xsl:message>
        
        <!-- get XPath binding expression relevant to this -->
        <xsl:variable name="refi" as="xs:string">
            <xsl:call-template name="getDataRef">
                <xsl:with-param name="this" select="."/>
                <xsl:with-param name="bindingi" select="$bindingi"/>
            </xsl:call-template>
        </xsl:variable>
        
        <xsl:message use-when="$debugMode">[xforms:output] refi: <xsl:value-of select="$refi"/></xsl:message>
        
        
        <!-- identify instance field corresponding to this output -->
        <xsl:variable name="instanceField" as="node()?">
            <xsl:call-template name="getReferencedInstanceField">
                <xsl:with-param name="refi" select="$refi"/>
            </xsl:call-template>
        </xsl:variable>
        
        <xsl:message use-when="$debugMode">[xforms:output] instanceField = <xsl:value-of select="serialize($instanceField)"/></xsl:message> 
        
        
        <xsl:message use-when="$debugMode">[xforms:output] xforms-imposed xpath = '<xsl:value-of select="xforms:impose(@value)"/>'</xsl:message>
        
        <xsl:variable name="valueExecuted" as="xs:string">
            <xsl:evaluate xpath="xforms:impose(@value)" context-item="$instanceField" as="xs:string" />
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
            <xd:p>Template for xforms:input</xd:p>
            <xd:p>Generates HTML input field and registers actions.</xd:p>
        </xd:desc>
        <xd:param name="nodeset">XPath identifying instance node(s) affected by the XForms input.</xd:param>
    </xd:doc>
    <xsl:template match="xforms:input">
        <!-- nodeset - used when the xforms:input is contained in a xforms:repeat to keep track of the entire instance document -->
        <xsl:param name="nodeset" as="xs:string" select="''" tunnel="yes"/>
        
        <xsl:variable name="time-id" as="xs:string" select="generate-id()"/>
        <xsl:sequence use-when="$debugTiming" select="js:startTime(concat('XForms-input-', $time-id))" />
        
        <xsl:variable name="myid" as="xs:string"
            select=" if (exists(@id)) then @id else generate-id() "/>
        
        
        <xsl:message use-when="$debugMode">
            xforms:input = <xsl:value-of select="serialize(.)"/> 
            nodeset = <xsl:value-of select="$nodeset"/> 
        </xsl:message> 
        
        <!-- get xforms:bind element relevant to this -->
        <xsl:variable name="bindingi" as="node()?">
            <xsl:call-template name="getBinding">
                <xsl:with-param name="this" select="."/>
            </xsl:call-template>
        </xsl:variable>
        
        <xsl:message use-when="$debugMode">[xforms:input] bindingi: <xsl:value-of select="serialize($bindingi)"/></xsl:message>


        <!-- get XPath binding expression relevant to this -->
        <xsl:variable name="refi" as="xs:string">
            <xsl:call-template name="getDataRef">
                <xsl:with-param name="this" select="."/>
                <xsl:with-param name="bindingi" select="$bindingi"/>
            </xsl:call-template>
        </xsl:variable>

        <xsl:message use-when="$debugMode">[xforms:input] refi: <xsl:value-of select="$refi"/></xsl:message>
        
        
        <!-- identify instance field corresponding to this input -->
        <xsl:variable name="instanceField" as="node()?">
            <xsl:call-template name="getReferencedInstanceField">
                <xsl:with-param name="refi" select="$refi"/>
            </xsl:call-template>
        </xsl:variable>
               
        <xsl:message use-when="$debugMode">[xforms:input] instanceField = <xsl:value-of select="serialize($instanceField)"/></xsl:message> 


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
                <xsl:attribute name="data-ref" select="$refi"/>
            </input>
        </span>
        </div>
        
        <xsl:sequence use-when="$debugTiming" select="js:endTime(concat('XForms-input', $time-id))" />
        
    </xsl:template>


    <xsl:template match="xforms:textarea" priority="2">
<!--        <xsl:param name="instance1" as="node()?" select="()" tunnel="yes"/>-->
<!--        <xsl:param name="bindings" as="map(xs:string, node())" select="map{}" tunnel="yes"/>-->
        <xsl:param name="nodeset" as="xs:string" select="''" tunnel="yes"/>
        <xsl:apply-templates select="*"/>

        <xsl:variable name="hints" select="xforms:hint/text()"/>
        
        <xsl:variable name="actions"  as="map(*)*">
            <xsl:apply-templates select="xforms:action | xforms:setvalue | xforms:insert | xforms:delete | xforms:toggle | xforms:send | xforms:setfocus | xforms:setindex | xforms:load | xforms:message | xforms:dispatch | xforms:rebuild | xforms:reset | xforms:show | xforms:hide | xforms:script | xforms:unload">
<!--                <xsl:with-param name="instance1" select="$instance1"/>-->
                <xsl:with-param name="nodeset" select="$nodeset" tunnel="yes"/>
<!--                <xsl:with-param name="bindings" select="$bindings"/>-->
            </xsl:apply-templates>
        </xsl:variable>
        
       
        <!-- MD 2018: move logic to new named template -->
        <xsl:variable name="bindingi" as="node()?">
            <xsl:call-template name="getBinding">
                <xsl:with-param name="this" select="."/>
            </xsl:call-template>
        </xsl:variable>
        
        <xsl:message>[xforms:textarea] bindingi = <xsl:value-of select="serialize($bindingi)"/></xsl:message>
        
        <!-- MD 2018: move logic to new named template -->
        <xsl:variable name="refi" as="xs:string">
            <xsl:call-template name="getDataRef">
                <xsl:with-param name="this" select="."/>
                <xsl:with-param name="bindingi" select="$bindingi"/>
            </xsl:call-template>
        </xsl:variable>
        
        <xsl:variable name="instanceForBinding" as="node()?">
            <xsl:call-template name="getItemForBinding">
                <xsl:with-param name="bindingi" as="node()?" select="$bindingi"/>
            </xsl:call-template>
        </xsl:variable>
        
        <xsl:variable name="instanceField" as="node()?">
            <xsl:call-template name="getReferencedInstanceField">
                <xsl:with-param name="refi" select="$refi"/>
            </xsl:call-template>
        </xsl:variable>
        
        
        <xsl:if test="exists($actions)">
        <xsl:variable name="myid"
            select="
            if (exists(@id)) 
            then @id
            else generate-id()"/>
        
           <!-- <xsl:variable name="actions-prep-for-json"  as="map(*)">
                <xsl:map>
                    <xsl:map-entry key="'actions'">
                        <xsl:sequence select="array{$actions}"/>
                    </xsl:map-entry>
                </xsl:map>
            </xsl:variable>-->
            
            <xsl:sequence select="js:addAction($myid, $actions)" />
            
            
        </xsl:if>
        <xsl:variable name="refElement" select="tokenize($refi, '/')[last()]"/>

        <textarea>
            <xsl:copy-of select="@*[local-name() != 'ref']"/>
            <xsl:attribute name="data-element" select="$refElement" />
            <xsl:attribute name="data-ref"
                select="
                    if ($nodeset = '') then
                        concat($nodeset, @ref)
                    else
                        concat($nodeset, '/', @ref)"/>
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

    <xsl:template match="xforms:select1 | xforms:select">
<!--        <xsl:param name="instance1" as="node()?" select="()" tunnel="yes"/>-->
<!--        <xsl:param name="bindings" as="map(xs:string, node())" select="map{}" tunnel="yes"/>-->
        <!-- nodeset - used when the xforms:input is contained in a xforms:repeat to keep track of the entire instance document -->
        <xsl:param name="nodeset" as="xs:string" select="''" tunnel="yes"/>
        <xsl:param name="position" select="''" tunnel="yes"/>
        
        <xsl:variable name="time-id" select="generate-id()"/>
        <xsl:sequence use-when="$debugTiming" select="js:startTime(concat('XForms-select', $time-id))" />
        <!-- TODO: binding need to be applied to the select/select1 element -->
        

        <!-- MD 2018: move logic to new named template -->
        <xsl:variable name="bindingi" as="node()?">
            <xsl:call-template name="getBinding">
                <xsl:with-param name="this" select="."/>
            </xsl:call-template>
        </xsl:variable>
        
        <!-- MD 2018: move logic to new named template -->
        <xsl:variable name="refi" as="xs:string">
            <xsl:call-template name="getDataRef">
                <xsl:with-param name="this" select="."/>
                <xsl:with-param name="bindingi" select="$bindingi"/>
            </xsl:call-template>
        </xsl:variable>
        
        <xsl:variable name="instanceForBinding" as="node()?">
            <xsl:call-template name="getItemForBinding">
                <xsl:with-param name="bindingi" as="node()?" select="$bindingi"/>
            </xsl:call-template>
        </xsl:variable>
        
        <xsl:variable name="instanceField" as="node()?">
            <xsl:call-template name="getReferencedInstanceField">
                <xsl:with-param name="refi" select="$refi"/>
            </xsl:call-template>
        </xsl:variable>
        
<!--        <xsl:message use-when="$debugMode">[xforms:select] instance field = <xsl:value-of select="serialize($instanceField)"/></xsl:message>-->
        
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
        
        
        <xsl:apply-templates select="xforms:label"/>
        
        <xsl:variable name="actions"  as="map(*)*">
            <xsl:apply-templates select="xforms:action | xforms:setvalue | xforms:insert | xforms:delete | xforms:toggle | xforms:send | xforms:setfocus | xforms:setindex | xforms:load | xforms:message | xforms:dispatch | xforms:rebuild | xforms:reset | xforms:show | xforms:hide | xforms:script | xforms:unload">
<!--                <xsl:with-param name="instance1" select="$instance1"/>-->
                <xsl:with-param name="nodeset" select="$refi" tunnel="yes"/>
<!--                <xsl:with-param name="bindings" select="$bindings"/>-->
<!--                <xsl:with-param name="position" select="$position"/>-->
            </xsl:apply-templates>
        </xsl:variable>
        
        <xsl:variable name="myid"
            select="
            if (exists(@id)) then
            @id
            else
            concat(generate-id(), $position)"/>
        
        
        <xsl:if test="exists($actions)">
          <!--  <xsl:variable name="actions-prep-for-json"  as="map(*)">
                <xsl:map>
                    <xsl:map-entry key="'actions'">
                        <xsl:sequence select="array{$actions}"/>
                    </xsl:map-entry>
                </xsl:map>
            </xsl:variable>-->
            <!--<xsl:message>select map <xsl:sequence select="serialize($actions-prep-for-json)" /></xsl:message>-->
            <xsl:sequence select="js:addAction($myid, $actions)" />
            
           
        </xsl:if>
        <xsl:variable name="refElement" select="tokenize($refi, '/')[last()]"/>
        <span>
            <xsl:attribute name="style" select="'display:inline'" />
            <select>
                <xsl:copy-of select="@*[local-name() != 'ref']"/>
                <xsl:if test="exists($refi)">
                    <xsl:attribute name="data-ref" select="$refi"/>
                </xsl:if>
               <!-- <xsl:if test="exists($instance1) and exists(@ref)">
                    <xsl:attribute name="data-ref"
                      select="
                        if ($nodeset = '') then
                            concat($nodeset, @ref)
                        else
                            concat($nodeset, '/', @ref)"
                         />
                </xsl:if>-->
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
<!--                    <xsl:with-param name="instance1" select="$instance1"/>-->
<!--                    <xsl:with-param name="nodeset" select="$refi"/>-->
<!--                    <xsl:with-param name="bindings" select="$bindings"/>-->
<!--                    <xsl:with-param name="position" select="$position"/>-->
                    <xsl:with-param name="selectedValue" select="$selectedValue"/>
                </xsl:apply-templates>
            
            </select>
        </span>
        <xsl:sequence use-when="$debugTiming" select="js:endTime(concat('XForms-select', $time-id))" />

    </xsl:template>


    <xsl:template match="(node() | @*)">
        <xsl:param name="instance1" as="node()?" select="()" tunnel="yes"/>
        <xsl:param name="bindings" as="map(xs:string, node())" select="map{}" tunnel="yes"/>
        <xsl:param name="submissions" as="map(xs:string, xs:string)" select="map{}" tunnel="yes"/>
        <!-- nodeset - used when the xforms:input is contained in a xforms:repeat to keep track of the entire instance document -->
        <xsl:param name="nodeset" as="xs:string" select="''" tunnel="yes"/>
        <xsl:copy>
            <xsl:apply-templates select="@*"/>
            <xsl:apply-templates select="node()">
                <xsl:with-param name="instance1" select="$instance1"/>
                <xsl:with-param name="bindings" select="$bindings"/>
                <xsl:with-param name="submissions" select="$submissions"
                    as="map(xs:string, xs:string)"/>
                <xsl:with-param name="nodeset" select="$nodeset" as="xs:string" tunnel="yes"/>
            </xsl:apply-templates>

        </xsl:copy>
    </xsl:template>



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
                <xsl:otherwise>&#xA0;<xsl:text/></xsl:otherwise>
            </xsl:choose>
        </label>
    </xsl:template>

    <xsl:template match="xforms:item">
<!--        <xsl:param name="instance1" as="node()?" select="()" tunnel="yes"/>-->
<!--        <xsl:param name="nodeset" as="xs:string" select="''"/>-->
        <xsl:param name="selectedValue" as="xs:string" select="''"/>
        
<!--        <xsl:message use-when="$debugMode">[xforms:item] comparing value '<xsl:value-of select="xforms:value/text()"/>' against selected value '<xsl:value-of select="$selectedValue"/>'</xsl:message>-->

        <option value="{xforms:value}">
            <xsl:if test="$selectedValue = xs:string(xforms:value/text())">
                <xsl:attribute name="selected" select="$selectedValue"/>
            </xsl:if>

            <xsl:value-of select="xforms:label"/>
        </option>

    </xsl:template>
    
    <xsl:template match="xforms:group">
        <xsl:param name="instance1" as="node()?" select="()" tunnel="yes"/>
        <xsl:param name="bindings" as="map(xs:string, node())" select="map{}" tunnel="yes"/>
        <xsl:param name="submissions" as="map(xs:string, xs:string)" select="map{}" tunnel="yes"/>
        <xsl:variable name="time-id" select="generate-id($instance1)"/>
        <xsl:sequence use-when="$debugTiming" select="js:startTime(concat('XForms-repeat', $time-id))" />
        <xsl:variable name="context" select="."/>
        <xsl:variable name="refi" as="xs:string?">
            <xsl:choose>
                <xsl:when test="exists(@nodeset)"><xsl:sequence select="$context/@nodeset" /></xsl:when>
                <xsl:when test="exists(@ref)"><xsl:sequence select="$context/@ref" /></xsl:when>
                <xsl:otherwise></xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <div>
            <xsl:if test="exists($refi)">
                <xsl:attribute name="data-group-ref" select="$refi" />
            </xsl:if>
            <xsl:if test="exists(@id)">
                <xsl:attribute name="id" select="@id"/>
            </xsl:if>

                    <xsl:apply-templates select="$context/*">
                        <xsl:with-param name="instance1" select="$instance1" tunnel="yes"/>
                        <xsl:with-param name="position" select="position()" tunnel="yes"/>
                        <xsl:with-param name="nodeset" select="if(exists($refi))then $refi else ''" tunnel="yes"/>
                        <xsl:with-param name="bindings" select="$bindings" tunnel="yes"/>
                        <xsl:with-param name="submissions" select="$submissions" tunnel="yes"/>
                    </xsl:apply-templates>
                
            
        </div>
    </xsl:template>

    <xsl:template match="xforms:repeat">
        <xsl:param name="instance1" as="node()?" select="()" tunnel="yes"/>
        <xsl:param name="bindings" as="map(xs:string, node())" select="map{}" tunnel="yes"/>
        <xsl:param name="submissions" as="map(xs:string, xs:string)" select="map{}" tunnel="yes"/>
        <xsl:param name="nodeset" as="xs:string" select="''" tunnel="yes"/>
        <xsl:variable name="time-id" select="generate-id($instance1)"/>
        <xsl:sequence use-when="$debugTiming" select="js:startTime(concat('XForms-repeat', $time-id))" />
        <xsl:variable name="context" select="."/>
      
        
        <xsl:variable name="refi" as="xs:string">
            <xsl:choose>
                <xsl:when test="exists(@ref)">
                    <xsl:value-of
                        select="
                        if ($nodeset = '') then
                        concat($nodeset, @ref)
                        else
                        concat($nodeset, '/', @ref)"
                    />
                </xsl:when>
                <xsl:when test="exists(@nodeset)">
                    <xsl:value-of
                        select="
                        if ($nodeset = '') then
                        concat($nodeset, @nodeset)
                        else
                        concat($nodeset, '/', @nodeset)"
                    />
                </xsl:when>
                <!--<xsl:when test="exists($bindingi)">
                    <xsl:value-of
                        select="
                        if (exists($bindingi/@nodeset)) then
                        $bindingi/@nodeset
                        else
                        $bindingi/@ref"
                    />
                </xsl:when> -->
                <xsl:otherwise>
                    <xsl:value-of select="''"/>
                </xsl:otherwise>
            </xsl:choose>
            
        </xsl:variable>

        <xsl:if test="exists($instance1)">
            <xsl:message use-when="$debugMode">
                repeat:
                nodeset = <xsl:sequence select="serialize($nodeset)"/>
                refi = <xsl:sequence select="serialize($refi)"/>
                instance1 = <xsl:sequence select="serialize($instance1)"/> 
            </xsl:message>
            <xsl:variable name="selectedRepeatVar" as="node()*">
                <xsl:sequence use-when="$debugTiming" select="js:startTime(concat('XForms-repeat-evaluate', $time-id))" />
                <xsl:evaluate xpath="$refi" context-item="$instance1"/>
                <xsl:sequence use-when="$debugTiming" select="js:endTime(concat('XForms-repeat-evaluate', $time-id))" />
            </xsl:variable>
            
            <xsl:message use-when="$debugMode">
                <xsl:choose>
                    <xsl:when test="exists($selectedRepeatVar)">xforms:repeat ref=<xsl:sequence select="$refi" />, count = <xsl:sequence select="count($selectedRepeatVar)" /></xsl:when>
                    <xsl:otherwise>No repeatfound for ref <xsl:sequence select="$refi" /> with context <xsl:value-of select="xs:string($context)"/></xsl:otherwise>
                </xsl:choose>
                
                
                
            </xsl:message>
           
            <xsl:if test="exists($selectedRepeatVar)">
                <div data-repeatable-context="{$refi}" data-count="{count($selectedRepeatVar)}">
                    <xsl:if test="exists($refi)">
                        <xsl:attribute name="data-repeatable-context" select="$refi" />
                    </xsl:if>
                    <xsl:if test="exists(@id)">
                        <xsl:attribute name="id" select="@id"/>
                    </xsl:if>
                    <xsl:for-each select="$selectedRepeatVar">
                        <div data-repeat-item="true">
                            <xsl:apply-templates select="$context/*">
                                <xsl:with-param name="instance1" select="$instance1" tunnel="yes"/>
                                <xsl:with-param name="position" select="position()" tunnel="yes"/>                       
                                <xsl:with-param name="nodeset" select="concat($refi, '[', position(), ']')" tunnel="yes"/>
                                <xsl:with-param name="bindings" select="$bindings" tunnel="yes"/>
                                <xsl:with-param name="submissions" select="$submissions" tunnel="yes"/>
                            </xsl:apply-templates>
                        </div>
                    </xsl:for-each>
                </div>
            </xsl:if>

        </xsl:if>
        <xsl:sequence use-when="$debugTiming" select="js:endTime(concat('XForms-repeat', $time-id))" />

    </xsl:template>

    <xsl:template match="xforms:submit">
        <xsl:param name="instance1" as="node()?" select="()" tunnel="yes"/>
        <xsl:param name="bindings" as="map(xs:string, node())" select="map{}" tunnel="yes"/>
        <xsl:param name="submissions" as="map(xs:string, xs:string)" select="map{}" tunnel="yes"/>
        <xsl:variable name="innerbody">
            <xsl:choose>
                <xsl:when test="xforms:label">
                    <xsl:apply-templates select="node()">
                        <xsl:with-param name="instance1" select="$instance1"/>
                        <xsl:with-param name="bindings" select="$bindings"/>
                    </xsl:apply-templates>

                </xsl:when>
                <xsl:otherwise>&#xA0;</xsl:otherwise>
            </xsl:choose>
        </xsl:variable>


        <xsl:choose>
            <xsl:when test="@appearance = 'minimal'">
                <a>
                    <xsl:copy-of select="$innerbody"/>
                </a>
            </xsl:when>
            <xsl:otherwise>
                <button type="button">
                    <xsl:copy-of select="@*[local-name() != 'ref']"/>
                    <xsl:if test="exists(@id) and map:contains($submissions, @id)">
                        <xsl:attribute name="data-submit" select="map:get($submissions, @id)"/>
                    </xsl:if>
                    <xsl:copy-of select="$innerbody"/>
                </button>
            </xsl:otherwise>
        </xsl:choose>

    </xsl:template>

    <xsl:template match="*" mode="insert-node">
        <xsl:param name="insert-node" as="node()"/>
        <xsl:param name="path" as="xs:string" select="''"/>
        <xsl:param name="current-path" as="xs:string" select="''"/>
        <xsl:variable name="updatedPath" select="concat($current-path, '/', local-name())"/>

        <xsl:variable name="name" select="local-name()"/>
        <xsl:variable name="currentPosition"
            select="count(preceding-sibling::*[local-name() = local-name(current())]) + 1"/>
        <xsl:variable name="isLast"
            select="count(parent::*/*[local-name() = $name]) = $currentPosition"/>
        <xsl:variable name="updatedPath2">
            <xsl:value-of select="$updatedPath"/>
            <xsl:if
                test="(preceding-sibling::* | following-sibling::*)[local-name() = local-name(current())]">
                <xsl:value-of select="concat('[', $currentPosition, ']')"/>
            </xsl:if>
        </xsl:variable>

        <!-- TODO - have rule for adding attributes -->
        <xsl:choose>
            <xsl:when test="$updatedPath = $path and $isLast">


                <xsl:copy>
                    <xsl:apply-templates select="node()" mode="insert-node">

                        <xsl:with-param name="insert-node" select="$insert-node"/>
                        <xsl:with-param name="path" select="$path"/>
                        <xsl:with-param name="current-path" select="$updatedPath2"/>
                    </xsl:apply-templates>
                </xsl:copy>
                <xsl:copy-of select="$insert-node"/>
            </xsl:when>
            <xsl:otherwise>

                <xsl:copy>
                    <xsl:apply-templates select="node()" mode="insert-node">
                        <xsl:with-param name="insert-node" select="$insert-node"/>
                        <xsl:with-param name="path" select="$path"/>
                        <xsl:with-param name="current-path" select="$updatedPath2"/>
                    </xsl:apply-templates>
                </xsl:copy>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>


    <xsl:template match="*" mode="delete-node">
        <xsl:param name="path" as="xs:string" select="''"/>
        <xsl:param name="current-path" as="xs:string" select="''"/>
        <xsl:variable name="updatedPath" select="concat($current-path, '/', local-name())"/>

        <xsl:variable name="name" select="local-name()"/>
        <xsl:variable name="currentPosition"
            select="count(preceding-sibling::*[local-name() = local-name(current())]) + 1"/>
        <xsl:variable name="updatedPath2">
            <xsl:value-of select="$updatedPath"/>
            <xsl:if
                test="(preceding-sibling::* | following-sibling::*)[local-name() = local-name(current())]">
                <xsl:value-of select="concat('[', $currentPosition, ']')"/>
            </xsl:if>
        </xsl:variable>
        

        <!-- TODO - have rule for adding attributes -->
        <xsl:choose>
            <xsl:when test="$updatedPath2 = $path"> 
            <!-- deleting controls from the xform -->
             <!--   <xsl:for-each
                    select="ixsl:page()//*[@data-ref = $path]/..">
                    
                    <xsl:result-document href="?." method="ixsl:replace-content">
                        
                    </xsl:result-document>
                </xsl:for-each>-->
            </xsl:when>
            <xsl:otherwise>

                <xsl:copy>
                    <xsl:apply-templates select="node()" mode="delete-node">
                        <xsl:with-param name="path" select="$path"/>
                        <xsl:with-param name="current-path" select="$updatedPath2"/>
                    </xsl:apply-templates>
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
                <xsl:with-param name="position" select="$position"></xsl:with-param>
            </xsl:apply-templates>
        </xsl:copy>
        
        
    </xsl:template> 

    <xsl:template match="select[exists(@data-action)]" mode="ixsl:onclick"> </xsl:template>


    <xsl:template match="button[exists(@data-action)]" mode="ixsl:onclick">
        <xsl:variable name="contextButton" select="." as="element(button)"/>
        <xsl:variable name="action-ref" select="@data-action"/>
        
        <xsl:variable name="action-map"
            select="js:getAction(string(@data-action))"/>
        
        <xsl:variable name="action-keys" select="map:keys($action-map)"/>
      
        <!--<xsl:variable name="updatedInstanceXML">
            <xsl:variable name="instanceXML"
                select="xforms:convert-json-to-xml(ixsl:page()//script[@id = 'xforms-jinstance']/text())"/>
            <xsl:apply-templates select="$instanceXML" mode="form-check-initial"/>
        </xsl:variable> -->


        <!-- MD 2018-06-29: handle multiple instances -->
        <!--<xsl:variable name="updatedInstanceXML">
            <xsl:variable name="instanceXML" select="js:getInstance()"/>
            <xsl:apply-templates select="$instanceXML" mode="form-check-initial"/>
        </xsl:variable>-->
        <xsl:variable name="instanceXML" as="element()" select="xforms:getInstance-JS($action-ref)"/>
        <xsl:variable name="updatedInstanceXML">
            <!--            <xsl:variable name="instanceXML" select="js:getInstance()"/>-->
            <xsl:apply-templates select="$instanceXML" mode="form-check-initial"/>
        </xsl:variable>
        <!--        <xsl:sequence select="js:setInstance($updatedInstanceXML)"/>-->
        <xsl:sequence select="xforms:setInstance-JS($action-ref,$updatedInstanceXML)"/>
        
        
        <xsl:variable name="xforms-doc" select="js:getXFormsDoc()"/>

        <xsl:message use-when="$debugMode"> instanceXML XXX= <xsl:value-of
                select="serialize($updatedInstanceXML)"/> 
        </xsl:message>


        <!-- TODO: change the for-each to work on map(*)* -->
        <xsl:for-each select="$action-keys">

            <xsl:choose>
                <xsl:when test=". = 'insert'">
                    <xsl:variable name="inserts" as="item()*">
                        <xsl:sequence
                            select="array:flatten(map:get($action-map, 'insert'))"/>
                    </xsl:variable>
                    
                    <xsl:for-each select="array:flatten($inserts)">
                        
                        <xsl:variable name="map-ref" select=".?ref" />
                        <xsl:variable name="insert-node" as="node()">
                            <xsl:evaluate
                                xpath="concat($map-ref,'[','last()',']')"
                                context-item="$updatedInstanceXML"/>
                        </xsl:variable>
                        <xsl:message use-when="$debugMode">insert found !!!! insert = <xsl:value-of
                            select="serialize(map:get($action-map, 'insert'))"/> ref = <xsl:value-of
                                select="$map-ref"/>
                        </xsl:message>
                        
                        <xsl:variable name="instance-with-insert">
                            
                            <xsl:apply-templates select="$updatedInstanceXML" mode="insert-node">
                                <xsl:with-param name="insert-node" select="$insert-node"/>
                                <xsl:with-param name="path"
                                    select="concat('/',$map-ref)"/>
                            </xsl:apply-templates>
                            
                        </xsl:variable>
                        
                        <!-- MD 2018-06-29: handle multiple instances -->
<!--                        <xsl:sequence select="js:setInstance($instance-with-insert)"/>-->
                        <xsl:sequence select="xforms:setInstance-JS($action-ref,$instance-with-insert)"/>
                        
                        <xsl:variable name="node-to-copyi" select="ixsl:page()//div[@data-repeatable-context = $map-ref]/div[last()]" as="node()"/>
                       
                        
                        <xsl:variable name="newNodePosition" select="count(ixsl:page()//div[@data-repeatable-context = $map-ref]/div)+1" as="xs:integer" />
                        
                        <xsl:variable name="newNodeCPath" select="$map-ref" as="xs:string"/>
                        
                        <xsl:variable name="name" select="name()"/>
                        <xsl:variable name="path-updated" select="if ($newNodePosition > 0) then concat($newNodeCPath, '[',$newNodePosition,']') else $newNodeCPath"/>
                        <xsl:variable name="str-length" select="string-length($newNodeCPath)"/>
                        
                        
                        
                        
                        
                        <xsl:variable name="copied-node" as="node()">
                            <xsl:apply-templates select="$node-to-copyi" mode="update-ref" >
                                <xsl:with-param name="path" select="$map-ref" />
                                <xsl:with-param name="position" select="$newNodePosition" />
                            </xsl:apply-templates>
                        </xsl:variable>
                        
                      
                        
                        <xsl:message use-when="$debugMode">node to copy= <xsl:value-of select="serialize($node-to-copyi)"/>
                            node to copy with updated ref = <xsl:value-of select="serialize($copied-node)"/>
                        </xsl:message>
                        
                        <xsl:for-each
                            select="ixsl:page()//div[@data-repeatable-context = $map-ref]">
                        
                            <xsl:result-document href="?." method="ixsl:append-content">
                                <xsl:copy-of select="$copied-node" />
                            </xsl:result-document>
                        </xsl:for-each>
                        
                        <!-- now need to check for associated actions for the new node(s) created. 
                        If we find any then add the to the ixsl:page()/head as a new script element -->
                        
                        <xsl:variable name="findDataRefs" select="$node-to-copyi//*[exists(@data-ref) or exists(@data-action)]" as="node()*"/>
                        <xsl:for-each select="$findDataRefs">
                            <xsl:variable name="dataRef" select="@data-ref" as="xs:string?"/>
                            <xsl:variable name="dataActionRef" select="@data-action " as="xs:string?"/>
                            
                            <xsl:if test="exists($dataActionRef)">
                                
                                <xsl:variable name="actionEvents" select="js:getAction(string($dataActionRef))" as="map(*)*"/>
                                
                                
                                <xsl:variable name="newActionId" select="$copied-node//*[@data-old-action=$dataActionRef]/@data-action" as="xs:string"/>
                                <xsl:variable name="dataRefForNewNode" select="$copied-node//*[@data-old-action=$dataActionRef]/@data-ref" as="xs:string?"/>
                                
                                <xsl:variable name="actions" as="map(*)*">
                                <xsl:for-each select="$actionEvents">
                                    <xsl:variable name="myContext" select="."/>
                                  
                                    <xsl:variable name="refExsists" select="map:contains($myContext, '@ref')" as="xs:boolean"/>
                                    <xsl:choose>
                                      
                                        <xsl:when test="$refExsists and exists($dataRefForNewNode)">
                                            
                                        <!--TODO do a manual copy of the js map instead of updateAction -->
                                            <xsl:sequence select="map:put($myContext, '@ref', string($dataRefForNewNode))" />
                                        </xsl:when>
                                        <xsl:when test="$refExsists">
                                            <xsl:variable name="contextRef" select="map:get($myContext, '@ref')" as="xs:string"/>
                                            <xsl:variable name="newPathVar" select="concat($path-updated,substring($contextRef,string-length($path-updated)+1))"/>
                                           
                                            <xsl:sequence select="map:put($myContext, '@ref', $newPathVar)" />
                                        </xsl:when>
                                        <xsl:otherwise>
                                            <xsl:sequence select="." />
                                        </xsl:otherwise>
                                    </xsl:choose>
                               
                                
                            </xsl:for-each>
                            </xsl:variable>
                              
                                <xsl:sequence select="js:addAction($newActionId, $actions)" />
                              
                            </xsl:if>
                        </xsl:for-each>
                        
                    </xsl:for-each>
                    
                </xsl:when>
                <xsl:when test=". = 'delete'">
                    <xsl:variable name="deletes" as="item()*">
                        <xsl:sequence
                            select="array:flatten(map:get($action-map, 'delete'))"/>
                    </xsl:variable>
                    
                    <xsl:variable name="action-refi" as="xs:string?" select="map:get($action-map, '@ref')" />
                        
                    <xsl:for-each select="$deletes">
                        <xsl:variable name="if-clause" select=".?if" as="xs:string"/>
                        <xsl:variable name="delete-ref" select=".?ref" as="xs:string"/>
                        
                        <xsl:variable name="if-statement" as="xs:boolean">
                            <xsl:choose>
                                <xsl:when test="empty($if-clause)">
                                    <xsl:sequence select="true()"/>
                                </xsl:when>
                                <xsl:otherwise><xsl:evaluate xpath="$if-clause" context-item="$updatedInstanceXML"/></xsl:otherwise>
                            </xsl:choose>
                            
                        </xsl:variable>
                        
                        <!-- TODO: the deleteRefFiexed is to be used on simple paths. We need something better for complicated  xpath -->
                        <xsl:variable name="deleteRefFixed" select="if($delete-ref = '.') then concat('/', $action-refi) else concat(if(exists($action-refi)) then concat('/',$action-refi) else '', '/',$delete-ref)" as="xs:string" />
                        
                        
                        <xsl:if test="$if-statement">
                            <xsl:variable name="instance-with-delete">
                                
                                <xsl:apply-templates select="$updatedInstanceXML" mode="delete-node">
                                    <xsl:with-param name="path"
                                        select="$deleteRefFixed"/>
                                </xsl:apply-templates>
                                
                            </xsl:variable> 
                            
                            
                            
                            <xsl:sequence select="js:setInstance($instance-with-delete)"/>
                            
                            <!-- save instance with delete applied -->
                            
                          <!--  <xsl:variable name="nodesToKeep" select="ixsl:page()//button[@data-action = $contextButton/@data-action]/../../../div[not()]"/>
                            
                            <xsl:message>nodes to kepp = <xsl:sequence select="count($nodesToKeep)"/></xsl:message>-->
                            
                            <!--<xsl:for-each
                                select="ixsl:page()//div[./span/button/@data-action = $contextButton/@data-action]">                                
                                <xsl:result-document href="?." method="ixsl:replace-content"></xsl:result-document>
                            </xsl:for-each>-->
                            
                            <xsl:call-template name="xformsjs-main">
                                <xsl:with-param name="xforms-doc" select="$xforms-doc"/>
                                <xsl:with-param name="instance-xml" select="$instance-with-delete"/>
                                <xsl:with-param name="xFormsId" select="js:getXFormsID()"/>
                            </xsl:call-template>
                        </xsl:if>
                    </xsl:for-each>
                    
                    
                    

                   

                </xsl:when>
                <xsl:when test=". = 'reset'">
                    <xsl:message use-when="$debugMode">reset found !!!!</xsl:message>
                </xsl:when>
            </xsl:choose>
        </xsl:for-each>

    </xsl:template>



    <xsl:template match="xforms:trigger">
        <xsl:param name="instance1" as="node()?" select="()" tunnel="yes"/>
        <xsl:param name="bindings" as="map(xs:string, node())" select="map{}" tunnel="yes"/>
        <xsl:param name="submissions" as="map(xs:string, xs:string)" select="map{}" tunnel="yes"/>
        <xsl:param name="position" select="''" tunnel="yes"/>
        <xsl:param name="nodeset" select="''" tunnel="yes"/>

        <!--
                <xsl:apply-templates select="node()">
            <xsl:with-param name="instance1" select="$instance1"/>
            <xsl:with-param name="bindings" select="$bindings"/>
        </xsl:apply-templates>
        
        -->
        <xsl:variable name="innerbody">
            <xsl:choose>
                <xsl:when test="*[local-name(.) = 'label']">

                    <xsl:apply-templates select="xforms:label">
                        <xsl:with-param name="instance1" select="$instance1" tunnel="yes"/>
                        <xsl:with-param name="bindings" select="$bindings" tunnel="yes"/>
                    </xsl:apply-templates>

                </xsl:when>
                <xsl:otherwise>&#xA0;</xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="myid"
            select="
                if (exists(@id)) then
                    @id
                else
                    concat(generate-id(), $position)"/>

<!--
        <xsl:apply-templates select="*[not(local-name() = 'label')]">
            <xsl:with-param name="instance1" select="$instance1"/>
            <xsl:with-param name="bindings" select="$bindings"/>
            <xsl:with-param name="myid" select="$myid" tunnel="yes"/>
            <xsl:with-param name="nodeset" select="$nodeset"/>
        </xsl:apply-templates>-->
        
        <xsl:variable name="actions"  as="map(*)*">
            <xsl:apply-templates select="xforms:action | xforms:setvalue | xforms:insert | xforms:delete | xforms:toggle | xforms:send | xforms:setfocus | xforms:setindex | xforms:load | xforms:message | xforms:dispatch | xforms:rebuild | xforms:reset | xforms:show | xforms:hide | xforms:script | xforms:unload">
                <xsl:with-param name="instance1" select="$instance1" tunnel="yes"/>
                <xsl:with-param name="nodeset" select="$nodeset" tunnel="yes"/>
                <xsl:with-param name="bindings" select="$bindings" tunnel="yes"/>
                <xsl:with-param name="position" select="$position" tunnel="yes"/>
                <xsl:with-param name="myid" select="$myid" tunnel="yes"/>
            </xsl:apply-templates>
        </xsl:variable>
        
        
        <xsl:if test="exists($actions)">
      
           <!-- <xsl:variable name="actions-prep-for-json"  as="map(*)">
                <xsl:map>
                    <xsl:map-entry key="'actions'">
                        <xsl:sequence select="array{$actions}"/>
                    </xsl:map-entry>
                </xsl:map>
            </xsl:variable>-->
           <!-- <xsl:message>select map <xsl:sequence select="serialize($actions-prep-for-json)" /></xsl:message>-->
            <!--  <xsl:sequence select="js:addAction($myid, serialize($actions-prep-for-json, map{'method':'json'}))" /> -->
            <xsl:sequence select="js:addAction($myid, $actions)" />
            
        </xsl:if>

     <span style="display:'inline'">
        <xsl:choose>
            <xsl:when test="@appearance = 'minimal'">
                <a>
                    <xsl:attribute name="data-action" select="$myid"/>
                    <xsl:copy-of select="$innerbody"/>
                </a>
            </xsl:when>
            <xsl:otherwise>
                <button type="button">
                    

                    <xsl:attribute name="data-action" select="$myid"/>
                    <!-- <xsl:copy-of select="@*[local-name() != 'ref']"/>
                    <xsl:if test="exists(@id) and map:contains($submissions,@id)">
                        <xsl:attribute name="data-action" select="map:get($submissions,@id)" />
                    </xsl:if> -->
                    <xsl:copy-of select="$innerbody"/>
                </button>
            </xsl:otherwise>
        </xsl:choose>
     </span>

    </xsl:template>

    <xsl:template match="xforms:action">
        <xsl:param name="instance1" as="node()?" select="()" tunnel="yes"/>
        <xsl:param name="bindings" as="map(xs:string, node())" select="map{}" tunnel="yes"/>
        <xsl:param name="submissions" as="map(xs:string, xs:string)" select="map{}" tunnel="yes"/>
        <xsl:param name="position" select="''" tunnel="yes"/>
        <xsl:param name="nodeset" select="''" tunnel="yes"/>
        <xsl:param name="myid" tunnel="yes"
            select="
            if (exists(@id)) then
            @id
            else
            concat(generate-id(), $position)"/>
        <xsl:variable name="time-id" select="generate-id($instance1)"/>
        <xsl:sequence use-when="$debugTiming" select="js:startTime(concat('XForms-action', $time-id))" />
        <!--  <xsl:message use-when="$debugMode">action xxx found outside of trigger <xsl:value-of select="@ev:event"/>, position= <xsl:value-of select="$position"/>, nodeset = <xsl:value-of select="$nodeset"/></xsl:message>-->
        <xsl:variable name="ntypei" select="@ev:event"/>
        
  
        <xsl:variable name="action-map" as="map(*)">
            <xsl:map>
            
                
                    <xsl:if test="not(empty($nodeset))">
                        <xsl:map-entry key="'@ref'" select="xs:string($nodeset)" />
                    </xsl:if>
                    
                    <xsl:if test="exists(@*:event)">
                        <xsl:map-entry key="'@event'" select="xs:string(@*:event)" />
                        
                    </xsl:if>
                    <xsl:if test="exists(@position)">
                        <xsl:map-entry key="'@position'" select="string(@position)" />
                    </xsl:if>
                    <xsl:if test="exists(@at)">
                        <xsl:map-entry key="'@at'" select="string(@at)" />
                    </xsl:if>
                    <xsl:if test="exists(@if)">
                        <xsl:map-entry key="'@if'" select="string(@if)" />
                    </xsl:if>
                    <xsl:if test="exists(@while)">
                        <xsl:map-entry key="'@while'" select="string(@while)" />
                    </xsl:if>
                    
                    <xsl:for-each-group
                        select="xforms:setvalue | xforms:insert | xforms:delete | xforms:toggle | xforms:send | xforms:setfocus | xforms:setindex | xforms:load | xforms:message | xforms:dispatch | xforms:rebuild | xforms:reset | xforms:show | xforms:hide | xforms:script | xforms:unload" group-by="local-name()">
                        
                        <xsl:apply-templates select="." mode="xforms-action-map">
                            <xsl:with-param name="nodeset" select="$nodeset" tunnel="yes"/>
                        </xsl:apply-templates>
                    </xsl:for-each-group>
                
            
            
            </xsl:map>
        </xsl:variable>
        
        <xsl:message use-when="$debugMode">xforms:action found !!!! XXX, node
            <xsl:value-of select="serialize(.)"/>, id= <xsl:value-of select="@id"/>,
            myid = <xsl:value-of select="$myid"/>, nodeset=<xsl:value-of select="$nodeset"
            />
            action xml <xsl:value-of select="serialize($action-map)"/>
        </xsl:message>

        <xsl:if test="exists($action-map) and exists($myid)">
           
            <xsl:sequence select="$action-map" />
        </xsl:if>

        <xsl:sequence use-when="$debugTiming" select="js:endTime(concat('XForms-action', $time-id))" />
    </xsl:template>
    
    
    <!-- MD 2018-06-29 -->
    <xsl:template match="@incremental[. = 'true']">
        <xsl:param name="nodeset" select="''" tunnel="yes"/>
        <xsl:message use-when="$debugMode">[@incremental] Setting action</xsl:message>
        <xsl:variable name="action-map" as="map(*)">
            <xsl:map>
                <xsl:if test="not(empty($nodeset))">
                    <xsl:map-entry key="'@ref'" select="xs:string($nodeset)" />
                </xsl:if>
            </xsl:map>
        </xsl:variable>
        <xsl:sequence select="$action-map"/>
    </xsl:template>


    <xsl:template
        match="xforms:setvalue | xforms:insert | xforms:delete | xforms:toggle | xforms:send | xforms:setfocus | xforms:setindex | xforms:load | xforms:message | xforms:dispatch | xforms:rebuild | xforms:reset | xforms:show | xforms:hide | xforms:script | xforms:unload">
        <xsl:param name="instance1" as="node()?" select="()" tunnel="yes"/>
        <xsl:param name="bindings" as="map(xs:string, node())" select="map{}" tunnel="yes"/>
        <xsl:param name="submissions" as="map(xs:string, xs:string)" select="map{}" tunnel="yes"/>
        <xsl:param name="position" select="''" tunnel="yes"/>
        <xsl:param name="nodeset" select="''" tunnel="yes"/>
        <xsl:param name="updateMode" tunnel="yes" select="false()"/> <!-- redundant - not used anymore -->
        <xsl:param name="myid" tunnel="yes"
            select="
                if (exists(@id)) then
                    @id
                else
                    concat(generate-id(), $position)"/>
        <xsl:variable name="ntypei" select="@ev:event"/>
        
        <xsl:variable name="nodeseti" select="if($nodeset='') then @nodeset else $nodeset" />
         
        <xsl:if test="not($updateMode)">
            
                <xsl:message use-when="$debugMode">xforms:setvalue found !!!! XXX, node
                        <xsl:value-of select="serialize(.)"/>, id= <xsl:value-of select="@id"/>,
                    myid = <xsl:value-of select="$myid"/>, nodeset=<xsl:value-of select="$nodeseti"
                    /></xsl:message>
           
            
            <xsl:variable name="action-map" as="map(*)">
                <xsl:map>
                    
                        
                            <xsl:if test="not(empty($nodeset))">
                                <xsl:map-entry key="'@ref'" select="xs:string($nodeset)" />
                            </xsl:if>
                            
                            <xsl:if test="exists(@*:event)">
                                <xsl:map-entry key="'@event'" select="xs:string(@*:event)" />
                                
                            </xsl:if>
                            <xsl:if test="exists(@position)">
                                <xsl:map-entry key="'@position'" select="string(@position)" />
                            </xsl:if>
                            <xsl:if test="exists(@at)">
                                <xsl:map-entry key="'@at'" select="string(@at)" />
                            </xsl:if>
                            <xsl:if test="exists(@if)">
                                <xsl:map-entry key="'@if'" select="string(@if)" />
                            </xsl:if>
                            <xsl:if test="exists(@while)">
                                <xsl:map-entry key="'@while'" select="string(@while)" />
                            </xsl:if>
                            
                            <xsl:for-each-group select="." group-by="local-name()">
                                <xsl:apply-templates select="." mode="xforms-action-map">
                                    <xsl:with-param name="nodeset" select="$nodeset" tunnel="yes"/>
                                </xsl:apply-templates>
                                
                            </xsl:for-each-group>
                                
                               
                            
                        
                    
                    
                </xsl:map>
            </xsl:variable>
                
                <xsl:message use-when="$debugMode">xforms:setvalue found !!!! XXX, node
                    <xsl:value-of select="serialize(.)"/>, id= <xsl:value-of select="@id"/>,
                    myid = <xsl:value-of select="$myid"/>, nodeset=<xsl:value-of select="$nodeseti"
                    />
                    action xml <xsl:value-of select="serialize($action-map, map{'method':'json'})"/>
                </xsl:message>
                
                <!--<xsl:choose>
                    <xsl:when test="ixsl:page()//script/@data-action = $myid">
                        <xsl:for-each select="ixsl:page()//head/script[@data-action = $myid]">
                            <xsl:result-document href="?." method="ixsl:replace-content">
                                <xsl:value-of
                                    select="serialize($action-map, map{'method':'json'})"/>
                            </xsl:result-document>
                        </xsl:for-each>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:for-each select="ixsl:page()//head">
                            <xsl:result-document href="?.">
                                <script type="application/json" data-action="{$myid}" data-ntype="{$ntypei}" data-action-context="{$nodeseti}">                
                                    <xsl:value-of select="serialize($action-map, map{'method':'json'})"/>                
                                </script>
                            </xsl:result-document>
                        </xsl:for-each>

                    </xsl:otherwise>
                </xsl:choose>-->
            
            <xsl:sequence select="$action-map"/>
        </xsl:if>


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
    
    
    
    <xsl:template match="xforms:*" mode="xforms-action-map">
        <xsl:param name="nodeset" select="''" tunnel="yes"/>        
       <xsl:map-entry key="local-name()">
           
           <xsl:variable name="array" as="map(*)*">
               <xsl:for-each select="current-group()">
                   
                   
                       <xsl:map>
                           <xsl:if test="exists(@value)">
                               <xsl:map-entry key="'@value'" select="string(@value)" />
                                   
                           </xsl:if>
                           <xsl:if test="empty(@value) and exists(./text())">
                               <xsl:map-entry key="'value'" select="string(.)" />
                                   
                           </xsl:if>
                           <xsl:if test="exists(@ref)">
                               <xsl:map-entry key="'ref'" select="string(@ref)" />
                                   
                           </xsl:if>
                           <xsl:if test="exists(@nodeset)" ><!-- Removed the logic: if(@nodeset = '.') then string($nodeset) else  -->
                               <xsl:map-entry key="'ref'" select="string(@nodeset)" />
                               
                           </xsl:if>
                           <xsl:if test="exists(@position)">
                               <xsl:map-entry key="'position'" select="string(@position)" />
                                   
                               
                           </xsl:if>
                           <xsl:if test="exists(@at)">
                               <xsl:map-entry key="'at'" select="string(@at)" />
                               
                           </xsl:if>
                           <xsl:if test="exists(@if)">
                               <xsl:map-entry key="'if'" select="string(@if)" />
                                   
                           </xsl:if>
                           <xsl:if test="exists(@while)">
                               <xsl:map-entry key="'while'" select="string(@while)" />
                                   
                               
                           </xsl:if>
                           <xsl:if test="exists(@*:event)">
                               <xsl:map-entry key="'event'" select="string(@*:event)" />
                                   
                           </xsl:if>
                       </xsl:map>
                   
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

    <xsl:template match="*" mode="form-check-initial">
        <xsl:param name="instance-id" as="xs:string" select="$default-instance-id"/>
        <xsl:param name="pendingUpdates" as="map(xs:string, xs:string)?"/>
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
                <xsl:with-param name="pendingUpdates" as="map(xs:string,xs:string)?" select="$pendingUpdates" />
            </xsl:apply-templates>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="*" mode="form-check">
        <xsl:param name="curPath" select="''"/>
        <xsl:param name="position" select="0"/>
        <xsl:param name="pendingUpdates" as="map(xs:string, xs:string)?"/>
        <!-- TODO namespaces?? -->
        <!-- 
        MD 2018
        
        update path with instance ID, e.g. "instance('search')"
        -->
        <xsl:variable name="updatedPath"
            select="
                if ($position > 0) then
                    concat($curPath, local-name(), '[', $position, ']')
                else
                    concat($curPath, local-name())"/>

        <xsl:message use-when="$debugMode">form-check processing node: <xsl:value-of select="local-name()"/></xsl:message>
        <xsl:message use-when="$debugMode">form-check updatedPath: <xsl:value-of select="$updatedPath"/></xsl:message> 
        <!--<xsl:message use-when="$debugMode">
            form-check processing pendingUpdat Map size: <xsl:value-of select="map:size($pendingUpdates)"/>
            path <xsl:sequence select="$updatedPath"/>
        </xsl:message>-->

        <!-- *** Process attributes of context node -->
        <xsl:apply-templates select="attribute()" mode="form-check">
            <xsl:with-param name="curPath" select="concat($updatedPath, '/')"/>
            <xsl:with-param name="pendingUpdates" as="map(xs:string,xs:string)?" select="$pendingUpdates" />
        </xsl:apply-templates>

        <!-- *** Process text content of context node -->
        <!-- Check for associated/bound form-control with id=$updatedPath  -->
        <xsl:variable name="associated-form-control"
            select="ixsl:page()//*[@data-ref = $updatedPath]"/>
        
        <xsl:choose>
            <xsl:when test="exists($associated-form-control)">
                <xsl:message use-when="$debugMode">Found associated form control with id: <xsl:value-of
                        select="$updatedPath"/></xsl:message> 
                <xsl:copy>
                    <xsl:value-of>
                        <xsl:apply-templates select="$associated-form-control" mode="get-field"/>
                    </xsl:value-of>
                </xsl:copy>
             </xsl:when>
            <xsl:when test="exists($pendingUpdates) and map:contains($pendingUpdates, $updatedPath)">
                <!--<xsl:message use-when="$debugMode">Found path in pendingUpdate <xsl:value-of
                    select="$updatedPath"/>
                    map = <xsl:sequence select="serialize($pendingUpdates)" />
                    map:contains(map{'Document/Options/Updated':'true'}, 'Document/Shipment') := <xsl:value-of select="if(map:contains($pendingUpdates, 'Document/Shipment')) then 'true' else 'false'"/>
                   get= <xsl:value-of select="map:get($pendingUpdates, 'Document/Shipment')"/>
                    get= <xsl:value-of select="map:get($pendingUpdates, 'Document/Options/Updated')"/>
                </xsl:message>-->
                <xsl:copy>
                    <xsl:value-of select="map:get($pendingUpdates, $updatedPath)"/>                    
                </xsl:copy>
                
            </xsl:when>
            <!--<xsl:otherwise><xsl:value-of select="."/></xsl:otherwise>-->
            <!-- Above does not just give text node content of current node -->

            <!-- TODO Is this the right way to handle white space?? -->
            <xsl:otherwise>
               <!-- <xsl:message use-when="$debugMode">did not find path in form or pending list path: <xsl:value-of
                    select="$updatedPath"/></xsl:message>-->
                <xsl:copy>
                    <xsl:value-of select="normalize-space(string-join(data(text()), ''))"/>
                </xsl:copy>
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
                            <xsl:with-param name="pendingUpdates" as="map(xs:string,xs:string)?" select="$pendingUpdates" />
                        </xsl:apply-templates>
                    </xsl:for-each>

                </xsl:when>

                <xsl:otherwise>
                    <xsl:for-each select="current-group()">
                        <xsl:apply-templates select="." mode="form-check">
                            <xsl:with-param name="curPath" select="concat($updatedPath, '/')"/>
                            <xsl:with-param name="pendingUpdates" as="map(xs:string,xs:string)?" select="$pendingUpdates" />
                        </xsl:apply-templates>
                    </xsl:for-each>

                </xsl:otherwise>

            </xsl:choose>

        </xsl:for-each-group>

    </xsl:template>

    <xsl:template match="@*" mode="form-check">
        <xsl:param name="curPath" select="''"/>
        <xsl:param name="pendingUpdates" as="map(xs:string, xs:string)?"/>
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
                regex="^instance\s*\(\s*&apos;(.*)&apos;\s*\)\s*/\s*(.*)$"
                >
                <xsl:matching-substring>
                    <xsl:map-entry key="'instance-id'" select="regex-group(1)"/>
                    <xsl:map-entry key="'xpath'" select="regex-group(2)"/>
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
    <xsl:function name="xforms:getInstance-JS" as="element()">
        <xsl:param name="ref" as="xs:string"/>
        <xsl:variable name="instance-map" as="map(xs:string,xs:string)" select="xforms:getInstanceMap($ref)"/>
        <xsl:variable name="this-instance-id" as="xs:string" select="map:get($instance-map,'instance-id')"/>
        <xsl:sequence select="xforms:instance($this-instance-id)"/>
    </xsl:function>
    
    
    <xsl:function name="xforms:setInstance-JS" as="empty-sequence()">
        <xsl:param name="ref" as="xs:string"/>
        <xsl:param name="updatedInstanceDoc" as="document-node()"/>
        <xsl:variable name="updatedInstance" as="element()" select="$updatedInstanceDoc/*"/>
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
        <xsl:message use-when="$debugMode">Looking for instance ID '<xsl:value-of select="$instance-id"/>'</xsl:message>
        <xsl:message use-when="$debugMode">Candidate instances: <xsl:value-of select="serialize($instances)"/></xsl:message>
        
        <xsl:variable name="matched-instance" as="element()?">
            <xsl:choose>
                <xsl:when test="$instance-id != ''">
                    <xsl:sequence select="map:get($instances,$instance-id)"/>
                    <!--<xsl:sequence select="
                        if ($instance-id = $default-instance-id)
                        then $instances[1]/*
                        else $instances[@id = $instance-id]/*"/>-->
                    
                </xsl:when>
                <xsl:otherwise>
                    <!-- if the instance is not identified, assume the first (only) instance in the form should be used -->
                    <xsl:copy-of select="map:get($instances,$default-instance-id)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:message use-when="$debugMode">[getInstance] Matched instance: <xsl:value-of select="serialize($matched-instance)"/></xsl:message>
        
        <xsl:sequence select="$matched-instance"/>
    </xsl:template>
    
    
    <xd:doc scope="component">
        <xd:desc>getBinding: return xforms:bind element relevant to $this.</xd:desc>
        <xd:param name="this">An XForms field that may have a binding.</xd:param>
        <xd:param name="bindings">Map of registered bindings (set in xformsjs-main template).</xd:param>
    </xd:doc>
    <xsl:template name="getBinding">
        <xsl:param name="this" as="element()" required="yes"/>
        <xsl:param name="bindings" as="map(xs:string, node())" tunnel="yes"/>
        
        <xsl:variable name="ref-binding" as="xs:string">
            <xsl:call-template name="getBindingRef">
                <xsl:with-param name="this" select="."/>
            </xsl:call-template>
        </xsl:variable>
        
        <xsl:sequence select="
            if (empty($ref-binding)) 
            then ()
            else map:get($bindings, $ref-binding)"
            />
    </xsl:template>
    
    
    <xd:doc scope="component">
        <xd:desc>getBindingRef: return ID or XPath reference that may identify a xforms:bind element relevant to $this.</xd:desc>
        <xd:param name="this">An XForms field that may have a binding.</xd:param>
    </xd:doc>
    <xsl:template name="getBindingRef">
        <xsl:param name="this" as="element()" required="yes"/>
        
        <xsl:choose>
            <!-- @ref is an XPath binding expression (which may correspond to a @nodeset attribute on a xforms:bind element) -->
            <xsl:when test="exists($this/@ref)">
                <xsl:value-of select="$this/@ref"/>
            </xsl:when>
            <!-- @bind is a reference to an @id attribute of an xforms:bind element -->
            <xsl:when test="exists($this/@bind)">
                <xsl:value-of select="$this/@bind"/>
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
        
        <xsl:choose>
            <xsl:when test="exists($this/@ref)">
                <xsl:value-of
                    select="
                    if ($nodeset = '') then
                    concat($nodeset, $this/@ref)
                    else
                    concat($nodeset, '/', $this/@ref)"
                />
            </xsl:when>
            <xsl:when test="exists($bindingi)">
                <!-- 
                    MD 2018-07-01: xforms:bind should nbot have a @ref element 
                
                    https://www.w3.org/TR/xforms11/#structure-bind-element
                -->
                <xsl:value-of
                    select="
                    if (exists($bindingi/@nodeset)) then
                    $bindingi/@nodeset
                    else
                    $bindingi/@ref"
                />
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="''"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>getItemForBinding: get a relevant instance via a xforms:bind element.</xd:p>
        </xd:desc>
        <xd:param name="bindingi">xforms:bind element.</xd:param>
        <xd:param name="instances">Map of all instances in the XForm, set in the xformsjs-main template.</xd:param>
    </xd:doc>
    <xsl:template name="getItemForBinding">
        <xsl:param name="bindingi" as="node()?" select="()"/>
        <xsl:param name="instances" as="map(xs:string,element())" tunnel="yes"/>
        <xsl:choose>
            <xsl:when test="exists($bindingi) and exists($bindingi/@nodeset)">
                <xsl:variable name="instance-map" as="map(xs:string,xs:string)" select="xforms:getInstanceMap($bindingi/@nodeset)"/>
<!--                <xsl:message use-when="$debugMode">[getItemForBinding] instance-map = <xsl:value-of select="serialize($instance-map)"/></xsl:message>-->
                
                <!-- MD 2018: for some reason this changes the element names from the instance to lower case !! -->
                <xsl:variable name="this-instance" as="element()?">
                    <xsl:call-template name="getInstance">
                        <xsl:with-param name="instance-id" select="map:get($instance-map,'instance-id')"/>
                    </xsl:call-template>
                </xsl:variable>
                
<!--                <xsl:message use-when="$debugMode">[getItemForBinding] this-instance = <xsl:value-of select="serialize($this-instance)"/></xsl:message>-->
<!--                <xsl:message use-when="$debugMode">[getItemForBinding] instanceForBinding found binding/@nodeset <xsl:value-of select="$bindingi/@nodeset"/></xsl:message>-->
                <xsl:evaluate xpath="map:get($instance-map,'xpath')" context-item="$this-instance"/>
                
                <!--                    <xsl:evaluate xpath="$bindingi/@nodeset" context-item="$instance1" />-->
            </xsl:when>
            <xsl:otherwise>
                <xsl:sequence select="map:get($instances,$default-instance-id)"/>
            </xsl:otherwise>
        </xsl:choose>
        
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>getReferencedInstanceField: get a relevant instance field via an XPath binding expression.</xd:p>
        </xd:desc>
        <xd:param name="refi">XPath binding expression.</xd:param>
    </xd:doc>
    <xsl:template name="getReferencedInstanceField">
        <xsl:param name="refi" as="xs:string" required="no" select="''"/>
        <xsl:choose>
            <xsl:when test="$refi != ''">
                <xsl:variable name="instance-map" as="map(xs:string,xs:string)" select="xforms:getInstanceMap($refi)"/>
                <xsl:message use-when="$debugMode">[getReferencedInstanceField] instance-map = <xsl:value-of select="serialize($instance-map)"/></xsl:message>
                
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
                
                <xsl:evaluate xpath="map:get($instance-map,'xpath')" context-item="$this-instance"/>
                
            </xsl:when>
            <xsl:otherwise/>
        </xsl:choose>
        
    </xsl:template>
    
 
    <xd:doc scope="component">
        <xd:desc>Implementation of XForms <a href="https://www.w3.org/TR/xforms11/#evt-refresh">refresh event</a></xd:desc>
    </xd:doc>
    <xsl:template name="refreshOutputs-JS">
        <xsl:message use-when="$debugMode">[refreshOutputs-JS] START refreshOutputs</xsl:message>
        
        <!-- get all registered outputs -->
        <!-- MD 2018-06-30 : want to use as="xs:string*" but get a cardinality error!? 
        JS data typing thing?
        -->
        <xsl:variable name="output-keys" select="js:getOutputKeys()" as="item()*"/>
        
        <xsl:for-each select="$output-keys">
            <xsl:variable name="this-key" as="xs:string" select="."/>
            <xsl:variable name="this-output" as="map(*)" select="js:getOutput($this-key)"/>
            <xsl:variable name="xpath" as="xs:string" select="map:get($this-output,'@value')"/>
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
            
            <xsl:message use-when="$debugMode">[refreshOutputs-JS] instance-map = <xsl:value-of select="serialize($instance-map)"/> </xsl:message>
            
            <xsl:variable name="this-instance-id" as="xs:string" select="map:get($instance-map,'instance-id')"/>
            
            <xsl:message use-when="$debugMode">[refreshOutputs-JS] this-instance-id = <xsl:value-of select="$this-instance-id"/> </xsl:message>
            
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
        <xd:param name="this">An XForms field that may have actions.</xd:param>
    </xd:doc>
    <xsl:template name="setActions">
        <xsl:param name="this" as="element()"/>
        
        <xsl:apply-templates select="$this/@incremental | $this/xforms:action | $this/xforms:setvalue | $this/xforms:insert | $this/xforms:delete | $this/xforms:toggle | $this/xforms:send | $this/xforms:setfocus | $this/xforms:setindex | $this/xforms:load | $this/xforms:message | $this/xforms:dispatch | $this/xforms:rebuild | $this/xforms:reset | $this/xforms:show | $this/xforms:hide | $this/xforms:script | $this/xforms:unload"/>
        
    </xsl:template>
    
</xsl:stylesheet>