<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:math="http://www.w3.org/2005/xpath-functions/math"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:xforms="http://www.w3.org/2002/xforms" xmlns:xhtml="http://www.w3.org/1999/xhtml"
    xmlns:xf="http://www.w3.org/2002/xforms"
    xmlns:js="http://saxonica.com/ns/globalJS" xmlns:ixsl="http://saxonica.com/ns/interactiveXSLT"
    xmlns:in="http://www.w3.org/2002/xforms-instance"
    xmlns:fn="http://www.w3.org/2005/xpath-functions"
    xmlns:map="http://www.w3.org/2005/xpath-functions/map"
    xmlns:array="http://www.w3.org/2005/xpath-functions/array"
    xmlns:ev="http://www.w3.org/2001/xml-events" exclude-result-prefixes="xs math xforms"
    extension-element-prefixes="ixsl" version="3.0">
    
    <xsl:variable name="xform-functions" select="'index', 'avg', 'foo', 'current-date'"/>
    
    <xsl:function name="xforms:impose" as="xs:string">
        <xsl:param name="input" as="xs:string" />
        <xsl:variable name="parts" as="xs:string*" >
            <xsl:analyze-string select="$input" regex="\i\c*\(">
                <xsl:matching-substring>
                    <xsl:choose>
                        <xsl:when test="substring-before(.,'(')=$xform-functions">
                            <xsl:sequence select="concat('xforms:',.)" />
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:sequence select="." />
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:matching-substring>
                <xsl:non-matching-substring>
                    <xsl:sequence select="." />
                </xsl:non-matching-substring>
                
                
            </xsl:analyze-string>
        </xsl:variable>
        <xsl:sequence select="string-join($parts)" />
    </xsl:function>
    
    <xsl:function name="xforms:foo" as="xs:boolean">
        <xsl:param name="num" as="xs:integer" />
        
        <xsl:sequence select="$num lt 5" />
        
    </xsl:function>
    <xsl:function name="xforms:index" as="xs:integer">
    <xsl:param name="repeatID" as="xs:string" />
        <xsl:variable name="element" select="js:getElementById($repeatID)"/>
        <xsl:choose>
            <xsl:when test="empty($element)">
                <!--<xsl:sequence select="xs:integer('NaN')" />-->
                <xsl:sequence select="0" />
            </xsl:when>
            <xsl:when test="exists($element/@data-repeatable-context)">
                <xsl:sequence select="count($element//*)" />
            </xsl:when>
            <xsl:otherwise>
                <xsl:sequence select="0" />
            </xsl:otherwise>
        </xsl:choose>
        
   
        
    </xsl:function>
    
    <xsl:function name="xforms:current-date" as="xs:string">
        <xsl:variable name="today" select="js:getCurrentDate()" as="xs:string"/>
        
       
        <xsl:sequence select="$today"/>
        
        
        
    </xsl:function>
</xsl:stylesheet>