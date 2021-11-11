<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:math="http://www.w3.org/2005/xpath-functions/math"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:xforms="http://www.w3.org/2002/xforms" 
    xmlns:xhtml="http://www.w3.org/1999/xhtml"
    xmlns:xf="http://www.w3.org/2002/xforms"
    xmlns:js="http://saxonica.com/ns/globalJS" 
    xmlns:ixsl="http://saxonica.com/ns/interactiveXSLT"
    xmlns:in="http://www.w3.org/2002/xforms-instance"
    xmlns:fn="http://www.w3.org/2005/xpath-functions"
    xmlns:map="http://www.w3.org/2005/xpath-functions/map"
    xmlns:array="http://www.w3.org/2005/xpath-functions/array"
    xmlns:sfl="http://saxonica.com/ns/forms-local"
    xmlns:ev="http://www.w3.org/2001/xml-events" 
    exclude-result-prefixes="xs math xforms"
    extension-element-prefixes="ixsl" version="3.0">
    
    <xsl:variable name="xform-functions" select="'if','instance', 'index', 'avg', 'foo', 'current-date', 'random'"/>
    
    <xsl:function name="xforms:impose" as="xs:string" visibility="public">
        <xsl:param name="input" as="xs:string" />
        <xsl:variable name="parts" as="xs:string*" >
            <!-- 
            \i = "initial name character"
            \c = "name character"
            
            https://www.w3.org/TR/xmlschema11-2/#Name
            https://www.mulberrytech.com/quickref/regex.pdf
            
            -->
            <xsl:analyze-string select="$input" regex="\i\c*\(">
                <xsl:matching-substring>
                    <xsl:choose>
                        <xsl:when test="substring-before(.,'(')=$xform-functions">
                            <xsl:sequence select="concat('xforms:',.)" />
<!--                            <xsl:sequence select="concat('Q{http://www.w3.org/2002/xforms}',.)" />-->
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
        
        <xsl:variable name="input2" as="xs:string" select="string-join($parts)"/>
        
        <!-- handle case where XPath starts "/" (i.e. root node of default instance) -->
        <xsl:variable name="input3" as="xs:string">
            <xsl:choose>
                <xsl:when test="matches($input2,'^\s*/')">
                    <xsl:sequence select="replace($input2, '^\s/[^/]+', '.')"/>
                </xsl:when>
                <!-- TEST - can we remove instance() at start of expression? -->
                <!--<xsl:when test="matches($input2,'^\s*xforms:instance\s*\(\s*''[^'']+''\s*\)')">
                    <xsl:sequence select="replace($input2, '^\s*xforms:instance\s*\(\s*''[^'']+''\s*\)', '.')"/>
                </xsl:when>-->
                <xsl:otherwise>
                    <xsl:sequence select="$input2"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>

        
        <xsl:sequence select="$input3" />
    </xsl:function>
    
    <xsl:function name="xforms:resolve-index" as="xs:string" visibility="public">
        <xsl:param name="input" as="xs:string" />
        <xsl:variable name="parts" as="xs:string*">
            <xsl:analyze-string select="$input" regex="index\s*\(\s*&apos;([^&apos;]+)&apos;\s*\)">
                <xsl:matching-substring>
<!--                    <xsl:message>[xforms:resolve-index] Resolving index of '<xsl:value-of select="regex-group(1)"/>' to '<xsl:value-of select="xforms:index(regex-group(1))"/>'</xsl:message>-->
                    <xsl:sequence select="xs:string(xforms:index(regex-group(1)))"/>
                </xsl:matching-substring>
                <xsl:non-matching-substring>
                    <xsl:sequence select="." />
                </xsl:non-matching-substring>
            </xsl:analyze-string>
        </xsl:variable>
<!--        <xsl:message>[xforms:resolve-index] XPath '<xsl:value-of select="$input"/>' resolves to '<xsl:value-of select="string-join($parts)"/>'</xsl:message>-->
        
        <xsl:sequence select="string-join($parts)" />
    </xsl:function>
    
    <xsl:function name="xforms:foo" as="xs:boolean" visibility="public">
        <xsl:param name="num" as="xs:integer" />
        
        <xsl:sequence select="$num lt 5" />
        
    </xsl:function>
    
    <xsl:function name="xforms:index" as="xs:integer" visibility="public">
        <xsl:param name="repeatID" as="xs:string" />
                
        <!-- call to js:getRepeatIndex doesn't work on first pass for some reason -->
        <xsl:variable name="repeat-index" as="xs:double?" select="js:getRepeatIndex($repeatID)"/>
                
        <!-- assign value '0' if $repeat-index does not exist -->
        <xsl:sequence select="if (exists($repeat-index)) then xs:integer($repeat-index) else 0"/>
        
    </xsl:function>
    
    <xsl:function name="xforms:random" as="xs:double" visibility="public">
        <xsl:variable name="randomNumber" select="js:Math.random()" as="xs:double"/>
        
        
        <xsl:sequence select="$randomNumber"/>
        
    </xsl:function>
    
    <!-- This is almost an implementation of xforms:local-date(), but not quite, since TZ is missing
        It is actually equivalent to: substring(xforms:local-date(), 1, 10) -->
    <xsl:function name="sfl:current-date" as="xs:string" visibility="public">
        <xsl:variable name="today" select="js:getCurrentDate()" as="xs:string"/>
        
        <xsl:sequence select="$today"/>
        
    </xsl:function>
    
    <!-- implement XForms instance() function -->
    <xsl:function name="xforms:instance" as="element()?" visibility="public">
        <xsl:param name="instance-id" as="xs:string"/>
        <xsl:sequence select="js:getInstance($instance-id)"/> 
    </xsl:function>
    
    <xd:doc scope="component">
        <xd:desc>Implement XForms <xd:a href="https://www.w3.org/TR/xforms11/#fn-if">if() function</xd:a></xd:desc>
        <xd:param name="test-item">Result of evaluating first parameter of if()</xd:param>
        <xd:param name="result-if-true">Result of evaluating second parameter of if()</xd:param>
        <xd:param name="result-if-false">Result of evaluating third parameter of if()</xd:param>
    </xd:doc>
    <xsl:function name="xforms:if" as="item()*" visibility="public">
        <xsl:param name="test-item" as="item()*"/>
        <xsl:param name="result-if-true" as="item()*"/>
        <xsl:param name="result-if-false" as="item()*"/>
        <xsl:choose>
            <xsl:when test="$test-item">
                <xsl:sequence select="$result-if-true"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:sequence select="$result-if-false"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
</xsl:stylesheet>
