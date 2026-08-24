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
    
    <!-- TEST-TRACE: register XForms function names for impose() rewriting; helps ch07 -->
    <xsl:variable name="xform-functions" select="'if','instance', 'index', 'avg', 'context', 'id', 'current-date', 'random', 'property', 'boolean-from-string', 'count-non-empty', 'power', 'choose', 'event', 'is-card-number', 'now', 'local-date', 'local-dateTime', 'days-from-date', 'days-to-date', 'seconds-from-dateTime', 'seconds-to-dateTime', 'seconds', 'months', 'adjust-dateTime-to-timezone', 'digest', 'hmac', 'min', 'max'"/>
    
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
        <!-- TEST-TRACE: normalize accidental prefix-corruption (fn:xforms:* / xforms:xforms:*) after local-name rewrite pass; helps tests/supplemental/issues.spec.ts "Issue #33". -->
        <xsl:variable name="input2a" as="xs:string" select="replace($input2, '(\i\c*:)\s*xforms:(\i\c*)\(', '$1$2(')"/>
        
        <!-- 
            Handle absolute XPaths like /rootElement/path anywhere in the expression.
            XForms instances are element nodes (not document nodes), so SaxonJS
            raises XPDY0050 when evaluating '/' against a non-document context.
            Strip the root element step and replace with root(.) which always
            navigates to the tree root regardless of the current context depth.
            E.g. /car/price  →  root(.)/price
                 0.024 * /car/price  →  0.024 * root(.)/price
                 /order/item/amount > 1000  →  root(.)/item/amount > 1000
            This is critical for bind MIP expressions (relevant, calculate, etc.)
            where the evaluation context is the bound node, not the instance root.
            The lookbehind matches start-of-string or XPath operators/whitespace
            that can precede an absolute path, but NOT '/' (to avoid //elem).
        -->
        <xsl:variable name="input3" as="xs:string" select="
            replace($input2a, '(^|[\s(*+,=&lt;&gt;\[\-])(/\i\c*)(/)','$1root(.)$3')"/>

        
        <!-- 
            Handle XForms current() function.
            Rewrite current() as an XPath 3.0 let-expression that captures the
            outermost context item (.), so that $__xf_current stays stable even
            inside predicates where . would change.
            See https://www.w3.org/TR/xforms11/#fn-current
            TEST-TRACE: keep current() inside quoted string literals untouched; helps tests/supplemental/issues.spec.ts "Issue #32 — current() literal handling".
        -->
        <xsl:variable name="input4-core" as="xs:string">
            <xsl:variable name="parts2" as="xs:string*">
                <xsl:analyze-string select="$input3" regex="'([^']|'')*'|&quot;([^&quot;]|&quot;&quot;)*&quot;">
                    <xsl:matching-substring>
                        <xsl:sequence select="."/>
                    </xsl:matching-substring>
                    <xsl:non-matching-substring>
                        <xsl:sequence select="replace(., 'current\s*\(\s*\)', '\$__xf_current')"/>
                    </xsl:non-matching-substring>
                </xsl:analyze-string>
            </xsl:variable>
            <xsl:sequence select="string-join($parts2)"/>
        </xsl:variable>
        <xsl:variable name="input4" as="xs:string">
            <xsl:choose>
                <xsl:when test="$input4-core ne $input3">
                    <xsl:sequence select="'let $__xf_current := . return (' || $input4-core || ')' " />
                </xsl:when>
                <xsl:otherwise>
                    <xsl:sequence select="$input3"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:sequence select="$input4" />
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
    
    <!-- TEST-TRACE: return xs:integer for registered repeats (preserves XPath predicate
         semantics) or xs:double(NaN) for non-existent repeats per XForms 1.1 §7.7.5;
         helps tests/w3c/ch07.spec.ts "7.7.5.b" -->
    <xsl:function name="xforms:index" as="xs:anyAtomicType" visibility="public">
        <xsl:param name="repeatID" as="xs:string" />
                
        <xsl:variable name="registered" as="xs:boolean" select="js:isRepeatRegistered($repeatID)"/>
        <xsl:variable name="repeat-index" as="xs:double?" select="js:getRepeatIndex($repeatID)"/>
                
        <xsl:sequence select="if ($registered) then xs:integer(($repeat-index, 0)[1]) else xs:double('NaN')"/>
        
    </xsl:function>
    
    <xsl:function name="xforms:random" as="xs:double" visibility="public">
        <xsl:variable name="randomNumber" select="js:Math.random()" as="xs:double"/>
        
        
        <xsl:sequence select="$randomNumber"/>
        
    </xsl:function>
    
    <!-- TEST-TRACE: 1-arg overload of random(seed); XForms 1.1 7.7.7;
         helps tests/w3c/ch07.spec.ts "7.7.7.a" -->
    <xsl:function name="xforms:random" as="xs:double" visibility="public">
        <xsl:param name="seed" as="item()"/>
        <!-- seed parameter is accepted but ignored; JS Math.random() is always seeded by implementation -->
        <xsl:sequence select="js:Math.random()"/>
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
    
    <!-- TEST-TRACE: 0-arg overload of instance(); XForms 1.1 7.10.1 says
         instance() with no argument returns the default instance;
         helps tests/w3c/ch07.spec.ts "7.10.1.a" -->
    <xsl:function name="xforms:instance" as="element()?" visibility="public">
        <xsl:sequence select="js:getDefaultInstance()"/>
    </xsl:function>
    
    <!-- implement XForms context() function -->
    <xsl:function name="xforms:context" as="item()*" visibility="public">
        <xsl:sequence select="."/>
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
    
    <!-- TEST-TRACE: XForms-compliant id() that recognizes xsi:type="xsd:ID";
         standard XPath id() only uses DTD/schema IDs; XForms 1.1 §7.10.3
         requires recognizing xsi:type annotations;
         helps tests/w3c/ch07.spec.ts "7.10.3.c" -->
    <xsl:function name="xforms:id" as="node()*" visibility="public">
        <xsl:param name="arg" as="item()*"/>
        <xsl:variable name="scope-node" as="node()?">
            <xsl:try>
                <xsl:sequence select="root(.)"/>
                <xsl:catch>
                    <xsl:sequence select="js:getDefaultInstance()"/>
                </xsl:catch>
            </xsl:try>
        </xsl:variable>
        <xsl:sequence select="xforms:id($arg, $scope-node)"/>
    </xsl:function>
    
    <xsl:function name="xforms:id" as="node()*" visibility="public">
        <xsl:param name="arg" as="item()*"/>
        <xsl:param name="node" as="node()?"/>
        
        <xsl:variable name="id-values" as="xs:string*" select="
            tokenize(
                normalize-space(
                    string-join(
                        for $v in $arg return normalize-space(string($v)),
                        ' '
                    )
                ),
                '\s+'
            )[. ne '']"/>
        <xsl:variable name="scope-node" as="node()?">
            <xsl:choose>
                <xsl:when test="exists($node)">
                    <xsl:sequence select="$node"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:try>
                        <xsl:sequence select="root(.)"/>
                        <xsl:catch>
                            <xsl:sequence select="js:getDefaultInstance()"/>
                        </xsl:catch>
                    </xsl:try>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="scope-elements" as="element()*" select="
            if (exists($scope-node))
            then (
                if ($scope-node instance of element())
                then ($scope-node | $scope-node//*)
                else $scope-node//*
            )
            else ()"/>
        <xsl:variable name="standard-id" as="node()*" select="
            if (exists($scope-node))
            then fn:id(string-join($id-values,' '), $scope-node)
            else ()"/>
        <xsl:variable name="xml-id" as="node()*" select="
            for $id in $id-values
            return $scope-elements[@xml:id = $id]"/>
        <xsl:variable name="xsi-typed-id" as="node()*" select="
            for $id in $id-values
            return $scope-elements[
                @*[local-name() = 'type' and namespace-uri() = ('http://www.w3.org/2001/XMLSchema-instance','http://www.w3.org/XMLSchema-instance')]
                [matches(normalize-space(string(.)), '(^|:)?ID$')]
            ][normalize-space(string(.)) = $id]"/>
        
        <xsl:sequence select="$standard-id | $xml-id | $xsi-typed-id"/>
    </xsl:function>
    
    <!-- TEST-TRACE: XForms-compliant min() wrapper; returns NaN for non-numeric
         or empty nodesets instead of throwing XPath 3.1 type errors;
         helps tests/w3c/ch07.spec.ts "7.7.2.b" -->
    <xsl:function name="xforms:min" as="xs:anyAtomicType" visibility="public">
        <xsl:param name="arg" as="item()*"/>
        <xsl:choose>
            <xsl:when test="empty($arg)">
                <xsl:sequence select="xs:double('NaN')"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:try>
                    <xsl:sequence select="fn:min($arg)"/>
                    <xsl:catch><xsl:sequence select="xs:double('NaN')"/></xsl:catch>
                </xsl:try>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
    <!-- TEST-TRACE: XForms-compliant max() wrapper; returns NaN for non-numeric
         or empty nodesets instead of throwing XPath 3.1 type errors;
         helps tests/w3c/ch07.spec.ts "7.7.3.b" -->
    <xsl:function name="xforms:max" as="xs:anyAtomicType" visibility="public">
        <xsl:param name="arg" as="item()*"/>
        <xsl:choose>
            <xsl:when test="empty($arg)">
                <xsl:sequence select="xs:double('NaN')"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:try>
                    <xsl:sequence select="fn:max($arg)"/>
                    <xsl:catch><xsl:sequence select="xs:double('NaN')"/></xsl:catch>
                </xsl:try>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
</xsl:stylesheet>
