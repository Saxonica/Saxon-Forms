<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl"
    xmlns:f="urn:saxon-forms:xd-doc"
    exclude-result-prefixes="xs xd f"
    version="3.0">
    <xsl:output method="html" html-version="5" encoding="utf-8" omit-xml-declaration="yes" indent="yes"/>
    <xsl:param name="source-rel-path" as="xs:string" select="string(base-uri(/))"/>
    <xsl:function name="f:documented-node" as="element()?">
        <xsl:param name="doc" as="element(xd:doc)"/>
        <xsl:sequence select="$doc/following-sibling::*[not(self::xd:*)][1]"/>
    </xsl:function>
    <xsl:function name="f:node-label" as="xs:string?">
        <xsl:param name="node" as="element()?"/>
        <xsl:choose>
            <xsl:when test="empty($node)">
                <xsl:sequence select="()"/>
            </xsl:when>
            <xsl:when test="$node/self::xsl:function">
                <xsl:sequence select="concat('xsl:function ', string($node/@name))"/>
            </xsl:when>
            <xsl:when test="$node/self::xsl:template">
                <xsl:sequence select="
                    if ($node/@name) then concat('xsl:template name=', string($node/@name))
                    else if ($node/@match) then concat('xsl:template match=', string($node/@match))
                    else 'xsl:template'"/>
            </xsl:when>
            <xsl:when test="$node/self::xsl:variable">
                <xsl:sequence select="concat('xsl:variable ', string($node/@name))"/>
            </xsl:when>
            <xsl:when test="$node/self::xsl:param">
                <xsl:sequence select="concat('xsl:param ', string($node/@name))"/>
            </xsl:when>
            <xsl:when test="$node/self::xsl:mode">
                <xsl:sequence select="
                    if ($node/@name) then concat('xsl:mode ', string($node/@name))
                    else 'xsl:mode #unnamed'"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:sequence select="name($node)"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    <xsl:template match="/">
        <article class="xd-docs">
            <h1>XSL xd:doc documentation</h1>
            <p>Source: <code><xsl:value-of select="$source-rel-path"/></code></p>
            <xsl:variable name="docs" as="element(xd:doc)*" select="//xd:doc"/>
            <xsl:choose>
                <xsl:when test="empty($docs)">
                    <p>No <code>xd:doc</code> sections were found.</p>
                </xsl:when>
                <xsl:otherwise>
                    <p>Total sections: <xsl:value-of select="count($docs)"/>.</p>
                    <xsl:for-each select="$docs">
                        <xsl:variable name="target" as="element()?" select="f:documented-node(.)"/>
                        <section class="xd-doc-entry">
                            <h2>Doc <xsl:value-of select="position()"/></h2>
                            <xsl:if test="@scope">
                                <p><strong>Scope:</strong> <code><xsl:value-of select="@scope"/></code></p>
                            </xsl:if>
                            <xsl:if test="exists($target)">
                                <p><strong>Applies to:</strong> <code><xsl:value-of select="f:node-label($target)"/></code></p>
                            </xsl:if>
                            <xsl:apply-templates select="xd:desc"/>
                            <xsl:if test="xd:param">
                                <h3>Parameters</h3>
                                <ul>
                                    <xsl:apply-templates select="xd:param" mode="param-list"/>
                                </ul>
                            </xsl:if>
                        </section>
                    </xsl:for-each>
                </xsl:otherwise>
            </xsl:choose>
        </article>
    </xsl:template>
    <xsl:template match="xd:desc">
        <div class="xd-desc">
            <xsl:for-each select="node()">
                <xsl:choose>
                    <xsl:when test="self::text()[normalize-space()]">
                        <p><xsl:value-of select="normalize-space(.)"/></p>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:apply-templates select="."/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:for-each>
        </div>
    </xsl:template>
    <xsl:template match="xd:param" mode="param-list">
        <li>
            <code><xsl:value-of select="@name"/></code>
            <xsl:text> — </xsl:text>
            <xsl:apply-templates select="node()"/>
        </li>
    </xsl:template>
    <xsl:template match="xd:p">
        <p><xsl:apply-templates/></p>
    </xsl:template>
    <xsl:template match="xd:b">
        <strong><xsl:apply-templates/></strong>
    </xsl:template>
    <xsl:template match="xd:ul">
        <ul><xsl:apply-templates/></ul>
    </xsl:template>
    <xsl:template match="xd:li">
        <li><xsl:apply-templates/></li>
    </xsl:template>
    <xsl:template match="xd:pre">
        <pre><code><xsl:value-of select="."/></code></pre>
    </xsl:template>
    <xsl:template match="xd:a">
        <a href="{@href}"><xsl:apply-templates/></a>
    </xsl:template>
    <xsl:template match="text()[not(normalize-space())]"/>
    <xsl:template match="text()">
        <xsl:value-of select="."/>
    </xsl:template>
    <xsl:template match="xd:*">
        <xsl:apply-templates/>
    </xsl:template>
</xsl:stylesheet>
