<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:math="http://www.w3.org/2005/xpath-functions/math"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:xforms="http://www.w3.org/2002/xforms"
    xmlns:xhtml="http://www.w3.org/1999/xhtml"
    xmlns:js="http://saxonica.com/ns/globalJS"
    xmlns:ixsl="http://saxonica.com/ns/interactiveXSLT"
    xmlns:in="http://www.w3.org/2002/xforms-instance"
    xmlns:fn="http://www.w3.org/2005/xpath-functions"
    xmlns:map="http://www.w3.org/2005/xpath-functions/map"
    xmlns:array="http://www.w3.org/2005/xpath-functions/array"
    exclude-result-prefixes="xs math xforms"
    extension-element-prefixes="ixsl"
    version="3.0">
    
    <xsl:output method="html" encoding="utf-8" omit-xml-declaration="no" indent="no" 
        doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN" doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"/>
    
    <!-- Contains the instance xml node if it exists -->
    <xsl:param name="instance-xml" as="document-node()?" select="()" />
    
    <!-- Contains the value of the XForms ID where the form will be represented -->
    <xsl:param name="xFormsID" select="'#xForm'" as="xs:string"/>
    
    <!-- Contains the value of the XForms instance ID where the instance will be inserted -->
    <xsl:param name="xforms-instanceID" select="'#xforms-jinstance'" />
    
    
    <xsl:template match="/" >
        
        <xsl:call-template name="xformsjs-main">
            <xsl:with-param name="instance-xml-main" select="$instance-xml" />
            <xsl:with-param name="xFormsID-main" select="$xFormsID"/>
            <xsl:with-param name="xforms-instanceIDi" select="$xforms-instanceID"></xsl:with-param>
            <xsl:with-param name="xforms-doc" select="." />
        </xsl:call-template>
        
    </xsl:template>
    
    
    <xsl:template name="xformsjs-main" >
        <xsl:param name="xforms-doc" as="document-node()?" select="()" />
        <xsl:param name="instance-xml-main" as="document-node()?" />
        <xsl:param name="xFormsID-main" select="'#xForm'" as="xs:string"/>
        <xsl:param name="xforms-instanceIDi" select="'#xforms-jinstance'" />              
        
        <xsl:variable name="instance-doc">
            <xsl:choose>
                <xsl:when test="not($instance-xml-main)">
                    <xsl:copy-of select="$xforms-doc/xforms:xform/xforms:model/xforms:instance/*:document"/>
                </xsl:when>
                <xsl:otherwise>                   
                     <xsl:copy-of select="$instance-xml-main/*:document"/>                       
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>

        <xsl:variable name="bindings" as="map(xs:string, node())">
                    <xsl:map >
                        <xsl:for-each select="$xforms-doc/xforms:xform/xforms:model/xforms:bind"><!-- [exists(@type)] -->
                           <xsl:variable name="xnodeset" as="node()?">
                               <xsl:evaluate xpath="./@nodeset" context-item="$instance-doc/*:document"/>
                            </xsl:variable>
                          <!--  <xsl:message>xnodeset<xsl:value-of select="serialize($xnodeset)"/></xsl:message> -->
                           
                          <xsl:map-entry key="generate-id($xnodeset)" select="."/>
                        <!-- <xsl:map-entry key="generate-id($xnodeset)" select="resolve-QName(./@type, .)"/> -->
                    </xsl:for-each>
                    </xsl:map>
        </xsl:variable>
        
        <xsl:variable name="submissions" as="map(xs:string, xs:string)">
            <xsl:map >
                <xsl:for-each select="$xforms-doc/xforms:xform/xforms:model/xforms:submission">                      
                    <xsl:map-entry key="xs:string(@ref)" select="xs:string(@action)"/>
                </xsl:for-each>
            </xsl:map>
        </xsl:variable>
       <!-- <xsl:message>
            instance-xml-main=<xsl:value-of select="serialize($instance-doc)"/>
            
        </xsl:message>
        <xsl:message>
            instance-map=<xsl:value-of select="serialize(xforms:convert-xml-to-jxml($instance-doc))"/>
           
        </xsl:message>-->
       
        <xsl:if test="exists($instance-doc)">
            <xsl:result-document href="{$xforms-instanceIDi}" method="ixsl:replace-content">
                <xsl:value-of select="xml-to-json(xforms:convert-xml-to-jxml($instance-doc))"/>
            </xsl:result-document>
       </xsl:if>
        
        <xsl:message>
            
            
            instance-jxml=<xsl:value-of select="serialize(xforms:convert-json-to-xml(ixsl:page()//script[@id='xforms-jinstance']/text()))"/>
        </xsl:message>
        
        <xsl:result-document href="{$xFormsID-main}" method="ixsl:replace-content">
            <xsl:apply-templates select="$xforms-doc/xforms:xform" >
                <xsl:with-param name="instance1" select="$instance-doc"/>
                <xsl:with-param name="bindings" select="$bindings" as="map(xs:string, node())"/>
                <xsl:with-param name="submissions" select="$submissions" as="map(xs:string, xs:string)"/>
            </xsl:apply-templates>
        </xsl:result-document>
        
    </xsl:template>
    
    <xsl:template match="input" mode="ixsl:onchange" >
      <xsl:message>Input box changed1 <xsl:value-of select="@value"/></xsl:message>
    </xsl:template>
    
    <xsl:function name="xforms:check-required-fields" as="item()*" >
        <xsl:param name="updatedInstanceXML" />
        
        <xsl:variable name="required-fieldsi" select="ixsl:page()//*[@data-required]" as="item()*" />
        
        
            
            <xsl:for-each select="$required-fieldsi">
                
                <xsl:variable name="resulti">                    
                    <xsl:evaluate xpath="concat('boolean(normalize-space(',@id,'))','=',@id,'/',@data-required)" context-item="$updatedInstanceXML" />
                </xsl:variable>
                <xsl:sequence select="if($resulti='false') then . else ()" />
            </xsl:for-each>
            
            
        
    </xsl:function>
    
    <xsl:template match="button[exists(@data-action)]" mode="ixsl:onclick" >
        <!-- XML Map rep of JSON map -->
        <xsl:variable name="instanceXML" select="xforms:convert-json-to-xml(ixsl:page()//script[@id='xforms-jinstance']/text())"/>
       
        <xsl:variable name="updatedInstanceXML">

                    <xsl:apply-templates select="$instanceXML" mode="form-check-initial" />
        </xsl:variable>
        
        
        <xsl:variable name="required-fieldsi" select="ixsl:page()//*[@data-required]" as="item()*" />
        
        <xsl:variable name="required-fields-check" as="item()*" select="xforms:check-required-fields($updatedInstanceXML)" />
            
        

        
        <xsl:variable name="action" ><xsl:value-of select="@data-action"/></xsl:variable>
      
        
        
       <xsl:choose>
           <xsl:when test="count($required-fields-check)=0">
               <xsl:sequence
                   select="js:submitXMLorderWithUrl(serialize($action),serialize($updatedInstanceXML), 'orderResponse')"/>       
           </xsl:when>
           <xsl:otherwise>
               <xsl:variable name="error-message">
                   <xsl:for-each select="$required-fields-check">
                    <xsl:variable name="curNode" select="."/>    
                   
                   <xsl:value-of select="concat('Value error see: ', serialize($curNode/@id),'&#10;')" />
                  
               </xsl:for-each>
               </xsl:variable>
               <xsl:sequence select="ixsl:call(ixsl:window(), 'alert', [serialize($error-message)])" />
           </xsl:otherwise>
       </xsl:choose>
        
        
     
    </xsl:template>
    
    <xsl:template match="xforms:model" />
    
    <!--<xsl:template match="/" >
        <xsl:apply-templates select="xforms:xform" />
        
    </xsl:template>-->
    
    <!--    <xsl:template name="generate-xform">
        <xsl:param name="xform-src"/>
        <xsl:apply-templates select="$xform-src" />
        
    </xsl:template>-->
    
    <xsl:template  match="xforms:xform">
        <xsl:param name="instance1" />
        <xsl:param name="bindings" as="map(xs:string, node())"  select="map{}" />
        <xsl:param name="submissions" as="map(xs:string, xs:string)"  select="map{}" />
        
        <xsl:apply-templates select="*">
            <xsl:with-param name="instance1" select="$instance1" />
            <xsl:with-param name="bindings" select="$bindings"/>
            <xsl:with-param name="submissions" select="$submissions" />
        </xsl:apply-templates>
    </xsl:template>
    
    <xsl:template  match="xhtml:html | html">
        <html >
            <xsl:copy-of select="@*"/>
            <head>
                <xsl:copy-of select="xhtml:head/@* | head/@*"/>
                <meta http-equiv="Content-Type" content="text/html;charset=utf-8"/>
                <xsl:for-each select="xhtml:head/xhtml:meta[string(@http-equiv) != 'Content-Type'] | head/meta[string(@http-equiv) != 'Content-Type']">
                    <meta>
                        <xsl:copy-of select="@*"/>
                    </meta>
                </xsl:for-each>
                
                
                <xsl:copy-of select="script"/>
            </head>
            <body>
                <xsl:apply-templates select="body/*" />
            </body>
            
        </html>
        
    </xsl:template>
    
    <xsl:template   match="xforms:input" >
        <xsl:param name="instance1" as="node()?" select="()" />
        <xsl:param name="bindings" as="map(xs:string, node())"  select="map{}" />
        <xsl:message>xforms:input=<xsl:value-of select="serialize($instance1)"/></xsl:message>
        <xsl:variable name="in-node" as="node()?">
            <xsl:evaluate xpath="@ref" context-item="$instance1/*:document"/>
        </xsl:variable>
        
        <xsl:apply-templates select="*" />
        
        <xsl:variable name="hints" select="xforms:hint/text()"/>
        <xsl:variable name="bindingi" select="map:get($bindings,generate-id($in-node))" as="node()?" />
        <input >
            <xsl:if test="exists($bindingi) and exists($bindingi/@required)">
                <xsl:attribute name="data-required" select="$bindingi/@required"/>
            </xsl:if>
            <xsl:if test="exists($bindingi) and  exists($bindingi/@relevant)">
                <xsl:attribute name="data-relevant" select="$bindingi/@relevant"/>
            </xsl:if>
            <xsl:choose>
                
                <xsl:when test="if(exists($bindingi)) then xs:QName($bindingi/@type) eq xs:QName('xs:date') else false()">
                    <xsl:attribute name="type" select="'date'" />
                </xsl:when>
                <xsl:when test="if(exists($bindingi)) then xs:QName($bindingi/@type) eq xs:QName('xs:time') else false()">
                    <xsl:attribute name="type" select="'time'" />
                </xsl:when>
                <xsl:otherwise>
                    <xsl:attribute name="type" select="'text'" />
                </xsl:otherwise>
            </xsl:choose>
            <xsl:if test="exists($hints)">
                <xsl:attribute name="placeholder" select="$hints" />
            </xsl:if>
            <xsl:if test="exists(@size)">
                <xsl:attribute name="size" select="@size" />
            </xsl:if>
            <xsl:attribute name="id" select="@ref" />
            <xsl:attribute name="value">
                <xsl:if test="exists($instance1) and exists(@ref)">
                    <xsl:evaluate xpath="concat(@ref,'/text()')" context-item="$instance1/*:document"/>
                </xsl:if> 
            </xsl:attribute>
        </input>        
    </xsl:template>
    
    
    <xsl:template   match="xforms:textarea" priority="2">
        <xsl:param name="instance1" as="node()?" select="()" />
        <xsl:param name="bindings" as="map(xs:string, node())"  select="map{}" />
        
        <xsl:apply-templates select="*" />
        
        <xsl:variable name="hints" select="xforms:hint/text()"/>
        
        <textarea><xsl:copy-of select="@*[local-name() != 'ref']"/>
            <xsl:choose>
                <xsl:when test="exists($instance1) and exists(@ref)"> 
                    
                    
                    <xsl:evaluate xpath="concat(@ref,'/text()')" context-item="$instance1/*:document"/>                    
                </xsl:when>
                <xsl:otherwise>
                    <xsl:text/>&#xA0;
                </xsl:otherwise>
            </xsl:choose>
            <xsl:if test="exists($hints)">
                <xsl:attribute name="placeholder" select="$hints" />
            </xsl:if>            
        </textarea>
    </xsl:template>
    
    <xsl:template  match="xforms:hint">
        
    </xsl:template>
    
    <xsl:template  match="xforms:select1|xforms:select">
        <xsl:param name="instance1" as="node()?" select="()" />
        <xsl:param name="bindings" as="map(xs:string, node())"  select="map{}" />
        
        <xsl:apply-templates select="xforms:label" />
        <select>
            <xsl:copy-of select="@*[local-name() != 'ref']"/>
            
            <xsl:if test="local-name() = 'select'">
                <xsl:attribute name="multiple">true</xsl:attribute>
                <xsl:attribute name="size">
                    <xsl:value-of select="count(descendant::xforms:item)"/>
                </xsl:attribute>
            </xsl:if>
            <xsl:apply-templates select="node()" mode="item">
                <xsl:with-param name="instance1" select="$instance1" />
            </xsl:apply-templates>
        </select>
        
        
        
        
    </xsl:template>
    
    
    <xsl:template  match="(node()|@*)">
        <xsl:param name="instance1" as="node()?" select="()" />
        <xsl:param name="bindings" as="map(xs:string, node())" select="map{}"/>
        <xsl:param name="submissions" as="map(xs:string, xs:string)" select="map{}"/>
        <xsl:copy>
            <xsl:apply-templates select="@*"/>
            <xsl:apply-templates select="node()" >
                <xsl:with-param name="instance1" select="$instance1" />
                <xsl:with-param name="bindings" select="$bindings" />
                <xsl:with-param name="submissions" select="$submissions" as="map(xs:string, xs:string)"/>
            </xsl:apply-templates>
            
        </xsl:copy>
    </xsl:template>
    
    
    
    <xsl:template match="text()[((ancestor::xforms:model))]" />
    
    
    
    <xsl:template   match="xforms:label">
        <xsl:param name="instance1" as="node()?" select="()" />
        <label><xsl:choose>
            <xsl:when test="count(./node()) &gt; 0">
                <xsl:apply-templates select="node()" />
            </xsl:when>
            <xsl:otherwise>&#xA0;<xsl:text/></xsl:otherwise>
        </xsl:choose></label>
    </xsl:template>
    
    <xsl:template  match="xforms:item" mode="item">
        <xsl:param name="instance1" as="node()?" select="()" />
        <xsl:variable name="selectedVar">
            <xsl:evaluate xpath="../@ref" context-item="$instance1/*:document"/> 
        </xsl:variable>
        
        <option value="{xforms:value}" >
            <xsl:if test="exists($instance1) and $selectedVar=xforms:value/text()">
                <xsl:attribute name="selected" select="$selectedVar" />
            </xsl:if>
            
            <xsl:value-of select="xforms:label"/>
        </option>
        
    </xsl:template>
    
    <xsl:template match="xforms:repeat" >
        <xsl:param name="instance1" as="node()?" select="()" />
        <xsl:param name="bindings" as="map(xs:string, node())"  select="map{}"/>
        <xsl:param name="submissions" as="map(xs:string, xs:string)"  select="map{}"/>
        <xsl:variable name="context" select="."/>
        
        <xsl:if test="exists($instance1)">
            <xsl:variable name="selectedVar">
                <xsl:evaluate xpath="@nodeset" context-item="$instance1/*:document"/> 
            </xsl:variable>
            <xsl:if test="count($selectedVar)>0">
            
            
                <xsl:for-each select="$selectedVar/*">
                
                <xsl:apply-templates select="$context/*">
                    <xsl:with-param name="instance1" >
                        <document>
                            <xsl:copy-of select=".[position()]" />
                        </document>
                    </xsl:with-param>
                    <xsl:with-param name="bindings" select="$bindings" />
                    <xsl:with-param name="submissions" select="$submissions" />
                </xsl:apply-templates>
            </xsl:for-each>
            </xsl:if>
        
        </xsl:if>
        
       
    </xsl:template>
    
    <xsl:template  match="xforms:trigger|xforms:submit" >
        <xsl:param name="instance1" as="node()?" select="()" />
        <xsl:param name="bindings" as="map(xs:string, node())"  select="map{}" />
        <xsl:param name="submissions" as="map(xs:string, xs:string)"  select="map{}" />
        <xsl:variable name="innerbody">
            <xsl:choose>
                <xsl:when test="xforms:label">
                    <xsl:apply-templates select="node()" >
                        <xsl:with-param name="instance1" select="$instance1" />
                        <xsl:with-param name="bindings" select="$bindings" />
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
                    <xsl:if test="exists(@id) and map:contains($submissions,@id)">
                        <xsl:attribute name="data-action" select="map:get($submissions,@id)" />
                    </xsl:if>
                    <xsl:copy-of select="$innerbody"/>                    
                </button>
            </xsl:otherwise>
        </xsl:choose>
        
    </xsl:template>
    
    <xsl:function name="xforms:convert-xml-to-jxml" as="node()" exclude-result-prefixes="#all">
        <xsl:param name="xinstance" as="node()"/>
        <xsl:variable name="rep-xml">
            <xsl:element name="map" namespace="http://www.w3.org/2005/xpath-functions">
                <xsl:apply-templates select="$xinstance" mode="json-xml"  />
            </xsl:element>
        </xsl:variable>
        <xsl:sequence select="$rep-xml" />
    </xsl:function>
    
    
    <xsl:template match="*" mode="json-xml">
        <xsl:choose>
            
            <xsl:when test="count(*)>0">
                <xsl:for-each-group select="*" group-by="local-name()" >
                    
                    <xsl:choose>                      
                        <xsl:when test="count(current-group())>1">
                            <xsl:element name="array" namespace="http://www.w3.org/2005/xpath-functions">
                                <xsl:attribute name="key" select="current-grouping-key()" />
                                <xsl:for-each select="current-group()">
                                    <xsl:element name="map" namespace="http://www.w3.org/2005/xpath-functions">
                                        <xsl:apply-templates select="." mode="json-xml" /> 
                                    </xsl:element>
                                </xsl:for-each>
                                 
                            </xsl:element>
                        </xsl:when>

                        <xsl:when test="count(current-group()/*)>0">
                            <xsl:element name="map" namespace="http://www.w3.org/2005/xpath-functions">
                                <xsl:attribute name="key" select="current-grouping-key()" />
                            <xsl:apply-templates select="current-group()" mode="json-xml" />   
                            </xsl:element>
                        </xsl:when>
                        <xsl:otherwise>
                           
                                <xsl:apply-templates select="current-group()" mode="json-xml" />   
                        </xsl:otherwise>
                    </xsl:choose>
                   
                    
                </xsl:for-each-group>
               
            </xsl:when>
            <xsl:when test=". castable as xs:int">
                <xsl:element name="number" namespace="http://www.w3.org/2005/xpath-functions">
                    <xsl:attribute name="key" select="local-name(.)" />
                    <xsl:value-of select="./text()"/>       
                </xsl:element>
            </xsl:when>
            <xsl:when test=". castable as xs:string">
                <xsl:element name="string" namespace="http://www.w3.org/2005/xpath-functions">
                    <xsl:attribute name="key" select="local-name(.)" />
                    <xsl:value-of select="./text()" />       
                </xsl:element>
            </xsl:when>
            <xsl:otherwise></xsl:otherwise>
        </xsl:choose>
       
    </xsl:template>
    
    
    <xsl:function name="xforms:convert-json-to-xml" as="node()" exclude-result-prefixes="#all">
        <xsl:param name="jinstance" as="xs:string"/>
        <xsl:variable name="rep-xml">
            <!--<xsl:sequence select="json-to-xml($jinstance)" /> -->
        </xsl:variable>
       <!-- <xsl:message>TESTING json xml map = <xsl:value-of select="serialize($rep-xml)"/></xsl:message> -->
        <xsl:variable name="result">
            <!--<xsl:element name="document"> -->
                <xsl:apply-templates select="$rep-xml" mode="jxml-xml" />
          <!--  </xsl:element> -->
        </xsl:variable>
        <xsl:sequence select="$result" />
    </xsl:function>
    
    <xsl:template match="*:map" mode="jxml-xml">
        <xsl:choose>
            <xsl:when test="empty(@key)">
                
                    <xsl:apply-templates select="*" mode="jxml-xml" />
                
            </xsl:when>
            <xsl:otherwise>
                <xsl:element name="{@key}">
                    <xsl:apply-templates select="*" mode="jxml-xml" />
                </xsl:element>
            </xsl:otherwise>
        </xsl:choose>
        
    </xsl:template>
    
    <xsl:template match="*:string|*:number" mode="jxml-xml">
        <xsl:element name="{@key}">
            <xsl:value-of select="text()"/>
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="*:array" mode="jxml-xml">
        <xsl:variable name="kayVar" select="@key"/>
        
        <xsl:for-each select="*">
            <xsl:element name="{$kayVar}">
                <xsl:apply-templates select="." mode="jxml-xml" />
            </xsl:element>
            
        </xsl:for-each>
        
    </xsl:template>
    
    
    <!-- Form instance check for updates made-->
    
    
    <xsl:template match="*" mode="form-check-initial">
        <xsl:copy>
            <xsl:apply-templates select="." mode="form-check"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="*" mode="form-check">
        <xsl:param name="curPath" select="''"/>
        <xsl:param name="position" select="0"/>
        <!--<xsl:variable name="updatedPath" select="concat($curPath, local-name())"/> -->
        <xsl:variable name="updatedPath" select="if($position>0) then concat($curPath, local-name(),'[',$position,']') else concat($curPath, local-name())"/>
        
        <xsl:for-each-group select="*" group-by="local-name(.)">
            
            <xsl:choose>
                <xsl:when test="count(current-group()) > 1">
                    
                    
                    <xsl:for-each select="current-group()">
                        
                        <xsl:copy>
                            <xsl:attribute name="ref" select="concat($updatedPath,'/', local-name(),'[',position(),']')"/>
                            <xsl:apply-templates select="." mode="form-check">
                                <xsl:with-param name="curPath" select="concat($updatedPath, '/')"/>
                                <xsl:with-param name="position" select="position()"/>
                            </xsl:apply-templates>
                        </xsl:copy>
                    </xsl:for-each>
                   
                    
                </xsl:when>
                
                
                <xsl:otherwise>
                    
                    
                    <xsl:for-each select="current-group()">
                        <xsl:variable name="ref" select="concat($updatedPath,'/', local-name())"/>
                        <xsl:choose>
                            <xsl:when test="not(node())">
                               
                                <xsl:variable name="fieldBox" >            
                                    <xsl:apply-templates select="ixsl:page()//*[@id=$ref]" mode="get-field" />
                                </xsl:variable>                                
                                
                                    <xsl:choose>
                                        
                                        <xsl:when test="exists($fieldBox)"><xsl:copy><xsl:value-of select="$fieldBox"/></xsl:copy></xsl:when>
                                        <xsl:otherwise ><xsl:copy-of select="."/></xsl:otherwise>
                                    </xsl:choose>
                                
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:copy>
                                    <!--<xsl:attribute name="ref" select="concat($updatedPath,'/', local-name())"/> -->
                                    <xsl:apply-templates select=".|node()" mode="form-check">
                                        <xsl:with-param name="curPath" select="concat($updatedPath, '/')"/>
                                    </xsl:apply-templates>
                                </xsl:copy>
                            </xsl:otherwise>
                        </xsl:choose>
                        
                       
                    </xsl:for-each>
                    
                </xsl:otherwise>
                
            </xsl:choose>
            
        </xsl:for-each-group>
        
        
        
        
    </xsl:template>
    
    <xsl:template match="text()" mode="form-check"> 
        <xsl:param name="curPath" select="''" />
        <xsl:variable name="updatedPath" select="concat($curPath,local-name(parent::node()))"/>
        
        <xsl:variable name="fieldBox" >            
            <xsl:apply-templates select="ixsl:page()//*[@id=$updatedPath]" mode="get-field" />
        </xsl:variable>                
       
        <xsl:choose>
            <xsl:when test="$fieldBox=."><xsl:copy-of select="."/></xsl:when>
            <xsl:otherwise><xsl:copy-of select="$fieldBox" /></xsl:otherwise>
        </xsl:choose>
        
    </xsl:template>
    
    
    
    
    <xsl:template match="*:input" mode="get-field">
        
        <!-- select="ixsl:get(ixsl:page()//*[@id=$updatedPath],'value')" -->
        <xsl:sequence select="ixsl:get(., 'value')" />
    </xsl:template>
    
    <xsl:template match="*:select" mode="get-field">
        
        <xsl:sequence select="ixsl:get(./option[ixsl:get(., 'selected') = true()],'value')" />
    </xsl:template>
    
    <xsl:template match="*:textarea" mode="get-field">
        
        <!-- select="ixsl:get(ixsl:page()//*[@id=$updatedPath],'value')" -->
        <xsl:sequence select="ixsl:get(., 'value')" />
    </xsl:template>
    
</xsl:stylesheet>