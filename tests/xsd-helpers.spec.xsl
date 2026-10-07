<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:xsdh="http://saxonica.com/ns/xsd-helpers"
    exclude-result-prefixes="xs xsdh"
    version="3.0">

    <xsl:output method="xml" indent="yes"/>
    <xsl:include href="../src/xsd-helpers.xsl"/>

    <xsl:template match="/">
        <xsl:variable name="canonical-failures" as="element(failure)*">
            <xsl:for-each select="/cases/canonical-case">
                <xsl:variable name="actual" as="xs:string" select="xsdh:canonical-type(@input)"/>
                <xsl:if test="$actual ne string(@expected)">
                    <failure kind="canonical" id="{@id}" input="{@input}" expected="{@expected}" actual="{$actual}"/>
                </xsl:if>
            </xsl:for-each>
        </xsl:variable>
        <xsl:variable name="schema-aware-failures" as="element(failure)*">
            <xsl:variable name="qname-schema" as="document-node()" select="parse-xml(
                '&lt;xs:schema xmlns:xs=&quot;http://www.w3.org/2001/XMLSchema&quot; targetNamespace=&quot;urn:test&quot; xmlns:t=&quot;urn:test&quot; elementFormDefault=&quot;qualified&quot;&gt;
                    &lt;xs:simpleType name=&quot;QNameLen33&quot;&gt;
                        &lt;xs:restriction base=&quot;xs:QName&quot;&gt;
                            &lt;xs:length value=&quot;33&quot;/&gt;
                        &lt;/xs:restriction&gt;
                    &lt;/xs:simpleType&gt;
                    &lt;xs:element name=&quot;v&quot; type=&quot;t:QNameLen33&quot;/&gt;
                &lt;/xs:schema&gt;')"/>
            <xsl:variable name="qname-actual" as="xs:boolean" select="xsdh:is-type-valid-against-schema('t:QNameLen33','ns:item',$qname-schema)"/>
            <xsl:if test="not($qname-actual)">
                <failure kind="schema-aware" id="qname-length-facet" expected="true" actual="{if ($qname-actual) then 'true' else 'false'}"/>
            </xsl:if>

            <xsl:variable name="duration-schema" as="document-node()" select="parse-xml(
                '&lt;xs:schema xmlns:xs=&quot;http://www.w3.org/2001/XMLSchema&quot; targetNamespace=&quot;urn:test&quot; xmlns:t=&quot;urn:test&quot; elementFormDefault=&quot;qualified&quot;&gt;
                    &lt;xs:simpleType name=&quot;DurationMaxExclusive&quot;&gt;
                        &lt;xs:restriction base=&quot;xs:duration&quot;&gt;
                            &lt;xs:maxExclusive value=&quot;P1970Y01M01DT00H00M01S&quot;/&gt;
                        &lt;/xs:restriction&gt;
                    &lt;/xs:simpleType&gt;
                    &lt;xs:element name=&quot;v&quot; type=&quot;t:DurationMaxExclusive&quot;/&gt;
                &lt;/xs:schema&gt;')"/>
            <xsl:variable name="duration-actual-invalid" as="xs:boolean" select="xsdh:is-type-valid-against-schema('t:DurationMaxExclusive','P1983Y08M22DT12H17M52S',$duration-schema)"/>
            <xsl:if test="$duration-actual-invalid">
                <failure kind="schema-aware" id="duration-maxExclusive" expected="false" actual="{if ($duration-actual-invalid) then 'true' else 'false'}"/>
            </xsl:if>

            <xsl:variable name="gyear-schema" as="document-node()" select="parse-xml(
                '&lt;xs:schema xmlns:xs=&quot;http://www.w3.org/2001/XMLSchema&quot; targetNamespace=&quot;urn:test&quot; xmlns:t=&quot;urn:test&quot; elementFormDefault=&quot;qualified&quot;&gt;
                    &lt;xs:simpleType name=&quot;GYearMaxExclusive&quot;&gt;
                        &lt;xs:restriction base=&quot;xs:gYear&quot;&gt;
                            &lt;xs:maxExclusive value=&quot;1971&quot;/&gt;
                        &lt;/xs:restriction&gt;
                    &lt;/xs:simpleType&gt;
                    &lt;xs:element name=&quot;v&quot; type=&quot;t:GYearMaxExclusive&quot;/&gt;
                &lt;/xs:schema&gt;')"/>
            <xsl:variable name="gyear-valid" as="xs:boolean" select="xsdh:is-type-valid-against-schema('t:GYearMaxExclusive','1969',$gyear-schema)"/>
            <xsl:if test="not($gyear-valid)">
                <failure kind="schema-aware" id="gyear-maxExclusive-valid" expected="true" actual="{if ($gyear-valid) then 'true' else 'false'}"/>
            </xsl:if>
            <xsl:variable name="gyear-invalid" as="xs:boolean" select="xsdh:is-type-valid-against-schema('t:GYearMaxExclusive','2001',$gyear-schema)"/>
            <xsl:if test="$gyear-invalid">
                <failure kind="schema-aware" id="gyear-maxExclusive-invalid" expected="false" actual="{if ($gyear-invalid) then 'true' else 'false'}"/>
            </xsl:if>
            <xsl:variable name="pattern-schema" as="document-node()" select="parse-xml(
                '&lt;xs:schema xmlns:xs=&quot;http://www.w3.org/2001/XMLSchema&quot; targetNamespace=&quot;urn:test&quot; xmlns:t=&quot;urn:test&quot; elementFormDefault=&quot;qualified&quot;&gt;
                    &lt;xs:simpleType name=&quot;IntTwoDigits&quot;&gt;
                        &lt;xs:restriction base=&quot;xs:int&quot;&gt;
                            &lt;xs:pattern value=&quot;[0-9]{2}&quot;/&gt;
                        &lt;/xs:restriction&gt;
                    &lt;/xs:simpleType&gt;
                    &lt;xs:element name=&quot;v&quot; type=&quot;t:IntTwoDigits&quot;/&gt;
                &lt;/xs:schema&gt;')"/>
            <xsl:variable name="pattern-valid" as="xs:boolean" select="xsdh:is-type-valid-against-schema('t:IntTwoDigits','12',$pattern-schema)"/>
            <xsl:if test="not($pattern-valid)">
                <failure kind="schema-aware" id="pattern-whole-match-valid" expected="true" actual="{if ($pattern-valid) then 'true' else 'false'}"/>
            </xsl:if>
            <xsl:variable name="pattern-invalid" as="xs:boolean" select="xsdh:is-type-valid-against-schema('t:IntTwoDigits','ab12cd',$pattern-schema)"/>
            <xsl:if test="$pattern-invalid">
                <failure kind="schema-aware" id="pattern-whole-match-invalid" expected="false" actual="{if ($pattern-invalid) then 'true' else 'false'}"/>
            </xsl:if>
            <xsl:variable name="list-length-schema" as="document-node()" select="parse-xml(
                '&lt;xs:schema xmlns:xs=&quot;http://www.w3.org/2001/XMLSchema&quot; targetNamespace=&quot;urn:test&quot; xmlns:t=&quot;urn:test&quot; elementFormDefault=&quot;qualified&quot;&gt;
                    &lt;xs:simpleType name=&quot;ListOfInt&quot;&gt;
                        &lt;xs:list itemType=&quot;xs:int&quot;/&gt;
                    &lt;/xs:simpleType&gt;
                    &lt;xs:simpleType name=&quot;ListOfIntLen5&quot;&gt;
                        &lt;xs:restriction base=&quot;t:ListOfInt&quot;&gt;
                            &lt;xs:length value=&quot;5&quot;/&gt;
                        &lt;/xs:restriction&gt;
                    &lt;/xs:simpleType&gt;
                    &lt;xs:element name=&quot;v&quot; type=&quot;t:ListOfIntLen5&quot;/&gt;
                &lt;/xs:schema&gt;')"/>
            <xsl:variable name="list-valid" as="xs:boolean" select="xsdh:is-type-valid-against-schema('t:ListOfIntLen5','1 2 3 4 5',$list-length-schema)"/>
            <xsl:if test="not($list-valid)">
                <failure kind="schema-aware" id="list-length-valid" expected="true" actual="{if ($list-valid) then 'true' else 'false'}"/>
            </xsl:if>
            <xsl:variable name="list-invalid" as="xs:boolean" select="xsdh:is-type-valid-against-schema('t:ListOfIntLen5','1 2 3 4',$list-length-schema)"/>
            <xsl:if test="$list-invalid">
                <failure kind="schema-aware" id="list-length-invalid" expected="false" actual="{if ($list-invalid) then 'true' else 'false'}"/>
            </xsl:if>
            <xsl:variable name="list-qname-pattern-schema" as="document-node()" select="parse-xml(
                '&lt;xs:schema xmlns:xs=&quot;http://www.w3.org/2001/XMLSchema&quot; targetNamespace=&quot;urn:test&quot; xmlns:t=&quot;urn:test&quot; elementFormDefault=&quot;qualified&quot;&gt;
                    &lt;xs:simpleType name=&quot;ListQNamePattern&quot;&gt;
                        &lt;xs:restriction base=&quot;xs:NMTOKENS&quot;&gt;
                            &lt;xs:pattern value=&quot;([\i-[:]][\c-[:]]*:)?[\i-[:]][\c-[:]]*(\s+([\i-[:]][\c-[:]]*:)?[\i-[:]][\c-[:]]*)*&quot;/&gt;
                        &lt;/xs:restriction&gt;
                    &lt;/xs:simpleType&gt;
                    &lt;xs:element name=&quot;v&quot; type=&quot;t:ListQNamePattern&quot;/&gt;
                &lt;/xs:schema&gt;')"/>
            <xsl:variable name="list-qname-pattern-valid" as="xs:boolean" select="xsdh:is-type-valid-against-schema('t:ListQNamePattern','ns:one ns:two',$list-qname-pattern-schema)"/>
            <xsl:if test="not($list-qname-pattern-valid)">
                <failure kind="schema-aware" id="list-qname-pattern-subtraction-valid" expected="true" actual="{if ($list-qname-pattern-valid) then 'true' else 'false'}"/>
            </xsl:if>
            <xsl:variable name="list-qname-pattern-invalid" as="xs:boolean" select="xsdh:is-type-valid-against-schema('t:ListQNamePattern','1bad',$list-qname-pattern-schema)"/>
            <xsl:if test="$list-qname-pattern-invalid">
                <failure kind="schema-aware" id="list-qname-pattern-subtraction-invalid" expected="false" actual="{if ($list-qname-pattern-invalid) then 'true' else 'false'}"/>
            </xsl:if>
        </xsl:variable>

        <xsl:variable name="validity-failures" as="element(failure)*">
            <xsl:for-each select="/cases/validity-case">
                <xsl:variable name="expected" as="xs:boolean" select="@expected = 'true'"/>
                <xsl:variable name="actual" as="xs:boolean" select="xsdh:is-type-valid(@type,string(value))"/>
                <xsl:if test="$actual ne $expected">
                    <failure kind="validity"
                        id="{@id}"
                        type="{@type}"
                        expected="{@expected}"
                        actual="{if ($actual) then 'true' else 'false'}"
                        value="{string(value)}"/>
                </xsl:if>
            </xsl:for-each>
        </xsl:variable>

        <xsl:variable name="failures" as="element(failure)*" select="$canonical-failures, $validity-failures, $schema-aware-failures"/>
        <xsl:choose>
            <xsl:when test="exists($failures)">
                <xsl:message terminate="yes">
                    <xsl:text>xsd helper test failures (</xsl:text>
                    <xsl:value-of select="count($failures)"/>
                    <xsl:text>):</xsl:text>
                    <xsl:for-each select="$failures">
                        <xsl:text>&#10; - </xsl:text>
                        <xsl:value-of select="@kind"/>
                        <xsl:text> </xsl:text>
                        <xsl:value-of select="@id"/>
                        <xsl:text> expected=</xsl:text>
                        <xsl:value-of select="@expected"/>
                        <xsl:text> actual=</xsl:text>
                        <xsl:value-of select="@actual"/>
                        <xsl:if test="@type">
                            <xsl:text> type=</xsl:text>
                            <xsl:value-of select="@type"/>
                        </xsl:if>
                        <xsl:if test="@input">
                            <xsl:text> input=</xsl:text>
                            <xsl:value-of select="@input"/>
                        </xsl:if>
                        <xsl:if test="@value">
                            <xsl:text> value=</xsl:text>
                            <xsl:value-of select="@value"/>
                        </xsl:if>
                    </xsl:for-each>
                </xsl:message>
            </xsl:when>
            <xsl:otherwise>
                <results
                    canonical-tests="{count(/cases/canonical-case)}"
                    validity-tests="{count(/cases/validity-case)}"
                    failures="0"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

</xsl:stylesheet>
