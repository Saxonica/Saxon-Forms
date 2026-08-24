<?xml version="1.0" encoding="UTF-8"?>
<!-- 
    XForms 1.1 XPath function library — pure XPath 3.1 implementations.
    
    All functions in this file are implementable without JS bridges,
    leveraging the full XPath 3.1 support provided by Saxon-JS.
    
    TEST-TRACE: helps tests/w3c/ch07.spec.ts
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:math="http://www.w3.org/2005/xpath-functions/math"
    xmlns:xforms="http://www.w3.org/2002/xforms"
    xmlns:fn="http://www.w3.org/2005/xpath-functions"
    xmlns:js="http://saxonica.com/ns/globalJS"
    xmlns:map="http://www.w3.org/2005/xpath-functions/map"
    exclude-result-prefixes="xs math fn js map"
    version="3.0">

    <!-- ================================================================
         7.8.2  property()
         Returns static XForms implementation properties.
         See https://www.w3.org/TR/xforms11/\#fn-property
         TEST-TRACE: helps ch07 7.8.2.a, 7.8.2.b, 7.8.2.c, 7.8.2.d
         ================================================================ -->
    <xsl:function name="xforms:property" as="xs:string" visibility="public">
        <xsl:param name="name" as="xs:string"/>
        <xsl:choose>
            <xsl:when test="$name = 'version'">1.1</xsl:when>
            <xsl:when test="$name = 'conformance-level'">full</xsl:when>
            <xsl:otherwise>
                <xsl:sequence select="''"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <!-- ================================================================
         7.6.1  boolean-from-string()
         'true' or '1' -> true; 'false' or '0' -> false; else false.
         See https://www.w3.org/TR/xforms11/\#fn-boolean-from-string
         TEST-TRACE: helps ch07 7.6.1.a
         ================================================================ -->
    <xsl:function name="xforms:boolean-from-string" as="xs:boolean" visibility="public">
        <xsl:param name="input" as="xs:string"/>
        <xsl:sequence select="lower-case(normalize-space($input)) = ('true', '1')"/>
    </xsl:function>

    <!-- ================================================================
         7.7.4  count-non-empty()
         Count of nodes whose string value is non-empty.
         See https://www.w3.org/TR/xforms11/\#fn-count-non-empty
         TEST-TRACE: helps ch07 7.7.4.a
         ================================================================ -->
    <xsl:function name="xforms:count-non-empty" as="xs:integer" visibility="public">
        <xsl:param name="nodeset" as="node()*"/>
        <xsl:sequence select="count($nodeset[string-length(string(.)) gt 0])"/>
    </xsl:function>

    <!-- ================================================================
         7.7.6  power()
         Returns base raised to exponent.  Delegates to math:pow().
         See https://www.w3.org/TR/xforms11/\#fn-power
         TEST-TRACE: helps ch07 7.7.6.a
         ================================================================ -->
    <xsl:function name="xforms:power" as="xs:double" visibility="public">
        <xsl:param name="base" as="xs:double"/>
        <xsl:param name="exponent" as="xs:double"/>
        <xsl:sequence select="math:pow($base, $exponent)"/>
    </xsl:function>

    <!-- ================================================================
         7.11.1  choose()
         If $test is true, return $value1; otherwise $value2.
         Unlike if(), all arguments are always evaluated.
         See https://www.w3.org/TR/xforms11/\#fn-choose
         TEST-TRACE: helps ch07 7.11.1.a
         ================================================================ -->
    <xsl:function name="xforms:choose" as="item()*" visibility="public">
        <xsl:param name="test" as="item()*"/>
        <xsl:param name="value1" as="item()*"/>
        <xsl:param name="value2" as="item()*"/>
        <xsl:sequence select="if (boolean($test)) then $value1 else $value2"/>
    </xsl:function>

    <!-- ================================================================
         7.11.2  event()
         Returns property values from the current XForms event context map.
         See https://www.w3.org/TR/xforms11/#fn-event
         TEST-TRACE: helps ch04 4.4.2.a and ch07 7.11.2.a
         ================================================================ -->
    <xsl:function name="xforms:event" as="item()*" visibility="public">
        <xsl:param name="name" as="xs:string"/>
        <xsl:variable name="event-context" as="item()*" select="js:getCurrentEventContext()"/>
        <xsl:choose>
            <xsl:when test="exists($event-context) and $event-context instance of map(*)">
                <xsl:sequence select="map:get($event-context, $name)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:sequence select="js:getCurrentEventProperty($name)"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <!-- ================================================================
         7.7.1  avg()
         Average of node-set values.  Returns NaN for empty set.
         Wraps fn:avg() with XForms-specific empty-set semantics.
         See https://www.w3.org/TR/xforms11/\#fn-avg
         TEST-TRACE: helps ch07 7.7.1.a, 7.7.1.b
         ================================================================ -->
    <xsl:function name="xforms:avg" as="xs:anyAtomicType" visibility="public">
        <xsl:param name="nodeset" as="item()*"/>
        <xsl:choose>
            <xsl:when test="empty($nodeset)">
                <xsl:sequence select="number('NaN')"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="nums" as="xs:double*"
                    select="for $n in $nodeset return number($n)"/>
                <xsl:sequence select="if (some $v in $nums satisfies string($v) = 'NaN')
                                      then number('NaN')
                                      else sum($nums) div count($nums)"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <!-- ================================================================
         7.6.2  is-card-number()
         Luhn checksum validation.
         See https://www.w3.org/TR/xforms11/\#fn-is-card-number
         TEST-TRACE: helps ch07 7.6.2.a
         ================================================================ -->
    <xsl:function name="xforms:is-card-number" as="xs:boolean" visibility="public">
        <xsl:param name="input" as="xs:string"/>
        <xsl:variable name="clean" select="normalize-space($input)"/>
        <xsl:choose>
            <xsl:when test="not(matches($clean, '^\d+$'))">
                <xsl:sequence select="false()"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="digits" as="xs:integer*"
                    select="reverse(
                              for $cp in string-to-codepoints($clean) 
                              return $cp - string-to-codepoints('0'))"/>
                <xsl:variable name="luhn-sum" as="xs:integer"
                    select="sum(
                              for $i in 1 to count($digits) return
                                if ($i mod 2 = 0) then
                                  (let $d := $digits[$i] * 2
                                   return if ($d gt 9) then $d - 9 else $d)
                                else
                                  $digits[$i])"/>
                <xsl:sequence select="$luhn-sum mod 10 = 0"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <!-- ================================================================
         7.9.3  now()
         Current dateTime as string (with timezone).
         See https://www.w3.org/TR/xforms11/\#fn-now
         TEST-TRACE: helps ch07 7.9.3.a
         ================================================================ -->
    <xsl:function name="xforms:now" as="xs:string" visibility="public">
        <xsl:sequence select="string(current-dateTime())"/>
    </xsl:function>

    <!-- ================================================================
         7.9.1  local-date()
         Current date as string (with timezone).
         See https://www.w3.org/TR/xforms11/\#fn-local-date
         TEST-TRACE: helps ch07 7.9.1.a
         ================================================================ -->
    <xsl:function name="xforms:local-date" as="xs:string" visibility="public">
        <xsl:sequence select="string(current-date())"/>
    </xsl:function>

    <!-- ================================================================
         7.9.2  local-dateTime()
         Current dateTime as string (with timezone).
         See https://www.w3.org/TR/xforms11/\#fn-local-dateTime
         TEST-TRACE: helps ch07 7.9.2.a
         ================================================================ -->
    <xsl:function name="xforms:local-dateTime" as="xs:string" visibility="public">
        <xsl:sequence select="string(current-dateTime())"/>
    </xsl:function>

    <!-- ================================================================
         7.9.4  days-from-date()
         Number of days between argument date and 1970-01-01.
         Returns NaN if argument is not a valid date or dateTime.
         See https://www.w3.org/TR/xforms11/\#fn-days-from-date
         TEST-TRACE: helps ch07 7.9.4.a, 7.9.4.b, 7.9.4.c
         ================================================================ -->
    <xsl:function name="xforms:days-from-date" as="xs:anyAtomicType" visibility="public">
        <xsl:param name="input" as="xs:string"/>
        <xsl:variable name="clean" select="normalize-space($input)"/>
        <xsl:choose>
            <xsl:when test="$clean castable as xs:date">
                <xsl:sequence select="(xs:date($clean) - xs:date('1970-01-01'))
                                      div xs:dayTimeDuration('P1D')"/>
            </xsl:when>
            <!-- Also accept xs:dateTime: ignore the time component -->
            <xsl:when test="$clean castable as xs:dateTime">
                <xsl:variable name="d" select="xs:date(
                    format-dateTime(xs:dateTime($clean), '[Y0001]-[M01]-[D01]'))"/>
                <xsl:sequence select="($d - xs:date('1970-01-01'))
                                      div xs:dayTimeDuration('P1D')"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:sequence select="number('NaN')"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <!-- ================================================================
         7.9.5  days-to-date()
         Converts integer days since 1970-01-01 to a date string.
         Returns empty string if argument is NaN.
         See https://www.w3.org/TR/xforms11/\#fn-days-to-date
         TEST-TRACE: helps ch07 7.9.5.a
         ================================================================ -->
    <xsl:function name="xforms:days-to-date" as="xs:string" visibility="public">
        <xsl:param name="days" as="item()"/>
        <xsl:choose>
            <xsl:when test="string(number($days)) = 'NaN'">
                <xsl:sequence select="''"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="d" as="xs:integer" select="xs:integer(round(number($days)))"/>
                <xsl:variable name="abs-d" as="xs:integer" select="abs($d)"/>
                <xsl:variable name="dur" select="xs:dayTimeDuration(concat('P', $abs-d, 'D'))"/>
                <xsl:sequence select="string(
                    if ($d ge 0) then xs:date('1970-01-01') + $dur
                    else xs:date('1970-01-01') - $dur)"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <!-- ================================================================
         7.9.6  seconds-from-dateTime()
         Seconds elapsed between argument dateTime and 1970-01-01T00:00:00Z.
         Returns NaN if argument is not a valid dateTime.
         See https://www.w3.org/TR/xforms11/\#fn-seconds-from-dateTime
         TEST-TRACE: helps ch07 7.9.6.a
         ================================================================ -->
    <xsl:function name="xforms:seconds-from-dateTime" as="xs:anyAtomicType" visibility="public">
        <xsl:param name="input" as="xs:string"/>
        <xsl:variable name="clean" select="normalize-space($input)"/>
        <xsl:choose>
            <xsl:when test="$clean castable as xs:dateTime">
                <xsl:variable name="dt" select="adjust-dateTime-to-timezone(
                    xs:dateTime($clean), xs:dayTimeDuration('PT0S'))"/>
                <xsl:variable name="epoch" select="xs:dateTime('1970-01-01T00:00:00Z')"/>
                <xsl:variable name="diff" select="$dt - $epoch"/>
                <xsl:variable name="total-seconds" select="
                    days-from-duration($diff) * 86400e0
                    + hours-from-duration($diff) * 3600e0
                    + minutes-from-duration($diff) * 60e0
                    + seconds-from-duration($diff)"/>
                <xsl:sequence select="$total-seconds"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:sequence select="number('NaN')"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <!-- ================================================================
         7.9.7  seconds-to-dateTime()
         Converts seconds since 1970-01-01T00:00:00Z to a dateTime string.
         Returns empty string if argument is NaN.
         See https://www.w3.org/TR/xforms11/\#fn-seconds-to-dateTime
         TEST-TRACE: helps ch07 7.9.7.a
         ================================================================ -->
    <xsl:function name="xforms:seconds-to-dateTime" as="xs:string" visibility="public">
        <xsl:param name="seconds" as="item()"/>
        <xsl:choose>
            <xsl:when test="string(number($seconds)) = 'NaN'">
                <xsl:sequence select="''"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="s" as="xs:decimal" select="xs:decimal(number($seconds))"/>
                <xsl:variable name="abs-s" as="xs:decimal" select="abs($s)"/>
                <xsl:variable name="dur" select="xs:dayTimeDuration(
                    concat('PT', string($abs-s), 'S'))"/>
                <xsl:variable name="epoch" select="xs:dateTime('1970-01-01T00:00:00Z')"/>
                <xsl:sequence select="string(
                    if ($s ge 0) then $epoch + $dur else $epoch - $dur)"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <!-- ================================================================
         7.9.9  seconds()
         Total seconds in the dayTime component of a duration string.
         Year/month components are ignored (contribute 0).
         Returns NaN if argument is not a valid duration.
         See https://www.w3.org/TR/xforms11/\#fn-seconds
         TEST-TRACE: helps ch07 7.9.9.a
         ================================================================ -->
    <xsl:function name="xforms:seconds" as="xs:anyAtomicType" visibility="public">
        <xsl:param name="input" as="xs:string"/>
        <xsl:variable name="clean" select="normalize-space($input)"/>
        <xsl:choose>
            <xsl:when test="$clean castable as xs:duration">
                <xsl:variable name="dur" select="xs:duration($clean)"/>
                <xsl:variable name="sign" as="xs:integer"
                    select="if (starts-with($clean, '-')) then -1 else 1"/>
                <!-- Extract only the dayTime components; year/month contribute 0 -->
                <xsl:variable name="total" select="
                    abs(days-from-duration($dur)) * 86400e0
                    + abs(hours-from-duration($dur)) * 3600e0
                    + abs(minutes-from-duration($dur)) * 60e0
                    + abs(seconds-from-duration($dur))"/>
                <xsl:sequence select="$total * $sign"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:sequence select="number('NaN')"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <!-- ================================================================
         7.9.10  months()
         Total months in a duration string.
         Day/time components are ignored.
         Returns NaN if argument is not a valid duration.
         See https://www.w3.org/TR/xforms11/\#fn-months
         TEST-TRACE: helps ch07 7.9.10.a
         ================================================================ -->
    <xsl:function name="xforms:months" as="xs:anyAtomicType" visibility="public">
        <xsl:param name="input" as="xs:string"/>
        <xsl:variable name="clean" select="normalize-space($input)"/>
        <xsl:choose>
            <xsl:when test="$clean castable as xs:duration">
                <xsl:variable name="dur" select="xs:duration($clean)"/>
                <xsl:sequence select="years-from-duration($dur) * 12
                                      + months-from-duration($dur)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:sequence select="number('NaN')"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <!-- ================================================================
         7.9.8  adjust-dateTime-to-timezone()
         Adjusts a dateTime string to the implicit timezone.
         0-arity form returns empty string.
         See https://www.w3.org/TR/xforms11/\#fn-adjust-dateTime-to-timezone
         TEST-TRACE: helps ch07 7.9.8.a
         ================================================================ -->
    <xsl:function name="xforms:adjust-dateTime-to-timezone" as="xs:string" visibility="public">
        <xsl:param name="input" as="xs:string"/>
        <xsl:variable name="clean" select="normalize-space($input)"/>
        <xsl:choose>
            <xsl:when test="$clean castable as xs:dateTime">
                <xsl:sequence select="string(
                    fn:adjust-dateTime-to-timezone(xs:dateTime($clean)))"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:sequence select="''"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <!-- 0-arity overload: XForms says return empty when no argument given -->
    <xsl:function name="xforms:adjust-dateTime-to-timezone" as="xs:string" visibility="public">
        <xsl:sequence select="''"/>
    </xsl:function>

    <!-- ================================================================
         7.8.3  digest()
         Cryptographic hash of data string.
         Uses @noble/hashes via JS bridge; returns empty string if
         the crypto library is not loaded.
         See https://www.w3.org/TR/xforms11/#fn-digest
         TEST-TRACE: helps ch07 7.8.3.a, 7.8.3.b, 7.8.3.f
         ================================================================ -->
    <!-- 3-arg form: digest(data, algorithm, encoding) -->
    <xsl:function name="xforms:digest" as="xs:string" visibility="public">
        <xsl:param name="data" as="xs:string"/>
        <xsl:param name="algorithm" as="xs:string"/>
        <xsl:param name="encoding" as="xs:string"/>
        <xsl:sequence select="js:computeDigest($data, $algorithm, $encoding)"/>
    </xsl:function>

    <!-- 2-arg form: digest(data, algorithm) — default encoding is base64 -->
    <xsl:function name="xforms:digest" as="xs:string" visibility="public">
        <xsl:param name="data" as="xs:string"/>
        <xsl:param name="algorithm" as="xs:string"/>
        <xsl:sequence select="js:computeDigest($data, $algorithm, 'base64')"/>
    </xsl:function>

    <!-- ================================================================
         7.8.4  hmac()
         Keyed-hash message authentication code.
         Uses @noble/hashes via JS bridge; returns empty string if
         the crypto library is not loaded.
         See https://www.w3.org/TR/xforms11/#fn-hmac
         TEST-TRACE: helps ch07 7.8.4.a, 7.8.4.b, 7.8.4.f
         ================================================================ -->
    <!-- 4-arg form: hmac(key, data, algorithm, encoding) -->
    <xsl:function name="xforms:hmac" as="xs:string" visibility="public">
        <xsl:param name="key" as="xs:string"/>
        <xsl:param name="data" as="xs:string"/>
        <xsl:param name="algorithm" as="xs:string"/>
        <xsl:param name="encoding" as="xs:string"/>
        <xsl:sequence select="js:computeHmac($key, $data, $algorithm, $encoding)"/>
    </xsl:function>

    <!-- 3-arg form: hmac(key, data, algorithm) — default encoding is base64 -->
    <xsl:function name="xforms:hmac" as="xs:string" visibility="public">
        <xsl:param name="key" as="xs:string"/>
        <xsl:param name="data" as="xs:string"/>
        <xsl:param name="algorithm" as="xs:string"/>
        <xsl:sequence select="js:computeHmac($key, $data, $algorithm, 'base64')"/>
    </xsl:function>

</xsl:stylesheet>
