<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:xsdh="http://saxonica.com/ns/xsd-helpers"
    exclude-result-prefixes="xs xsdh"
    version="3.0">

    <xsl:include href="../src/xsd-helpers.xsl"/>

    <xsl:param name="schema-uri" as="xs:string"/>
    <xsl:param name="instance-uri" as="xs:string"/>

    <xsl:template name="main">
        <xsl:variable name="schema-doc" as="document-node()" select="doc($schema-uri)"/>
        <xsl:variable name="instance-doc" as="document-node()" select="doc($instance-uri)"/>
        <xsl:variable name="root" as="element()?" select="$instance-doc/*[1]"/>
        <xsl:variable name="root-name" as="xs:string" select="if (exists($root)) then local-name($root) else ''"/>
        <xsl:variable name="element-decl" as="element(xs:element)?" select="$schema-doc/xs:schema/xs:element[@name = $root-name][1]"/>
        <xsl:variable name="type-name" as="xs:string" select="normalize-space(string($element-decl/@type))"/>
        <!-- TEST-TRACE: validate NIST instance lexical value via schema-derived simpleType facets in xsd-helpers. -->
        <xsl:variable name="valid" as="xs:boolean" select="
            if (empty($root) or empty($element-decl) or $type-name = '')
            then false()
            else xsdh:is-type-valid-against-schema($type-name,string($root),$schema-doc)"/>
        <result valid="{$valid}" type="{$type-name}" root="{$root-name}"/>
    </xsl:template>

</xsl:stylesheet>
