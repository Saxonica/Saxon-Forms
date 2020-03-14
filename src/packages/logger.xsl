<?xml version="1.0" encoding="UTF-8"?>
<xsl:package 
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" 
    xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl"
    xmlns:sfp="http://saxon.sf.net/ns/packages" 
    name="http://saxon.sf.net/packages/logger.xsl"
    package-version="1.0"
    exclude-result-prefixes="#all" 
    version="3.0">
    
    <xd:doc scope="stylesheet">
        <xd:desc>
            <xd:p><xd:b>Created on:</xd:b> 2018-11-30</xd:p>
            <xd:p><xd:b>Author:</xd:b> Mark Dunn</xd:p>
            <xd:p><xd:b>Purpose:</xd:b> Logging functions to assist in debugging stylesheets.</xd:p>
            
            <xd:p>
                <xd:b>Usage: </xd:b>
            </xd:p>
            
            <xd:p>1. Import this package in your stylesheet, e.g.  
                <xd:pre>
          &lt;xsl:use-package name="http://saxon.sf.net/packages/logger.xsl" package-version="[current version]"&gt;
            &lt;xsl:override&gt;
              &lt;xsl:variable name="sfp:LOGLEVEL" as="xs:integer" select="$sfp:LOGLEVEL_ALL"/&gt;
            &lt;/xsl:override&gt;
          &lt;/xsl:use-package&gt;
        </xd:pre>
            </xd:p>
            <xd:p>Set the override value of $sfp:LOGLEVEL to have one of the following values:
                <xd:ul>
                    <xd:li>$sfp:LOGLEVEL_OFF (= 0)</xd:li>
                    <xd:li>$sfp:LOGLEVEL_FATAL (= 10)</xd:li>
                    <xd:li>$sfp:LOGLEVEL_SEVERE (= 20)</xd:li>
                    <xd:li>$sfp:LOGLEVEL_WARNING (= 30)</xd:li>
                    <xd:li>$sfp:LOGLEVEL_INFO (= 40)</xd:li>
                    <xd:li>$sfp:LOGLEVEL_ALL (= 50)</xd:li>
                </xd:ul>
            </xd:p>
            <xd:p>OFF produces no messages; ALL outputs all possible messages </xd:p>
            <xd:p>2. In your code, insert function calls to the following functions: 
                <xd:ul>
                    <xd:li>sfp:logFatal()</xd:li>
                    <xd:li>sfp:logSevere()</xd:li>
                    <xd:li>sfp:logWarning()</xd:li>
                    <xd:li>sfp:logInfo()</xd:li>
                    <xd:li>sfp:logAll()</xd:li>
                </xd:ul>
            </xd:p>
            <xd:p>passing your log message as the (string) parameter.</xd:p>
            <xd:p>e.g. 
                <xd:pre>
          &lt;xsl:sequence select="
           sfp:logInfo(
             concat("Using output directory ", $outputDir)
           )"/>
        </xd:pre>
            </xd:p>
        </xd:desc>
    </xd:doc>
    
    
    <!-- Define enumerated log levels -->
    <xsl:variable name="sfp:LOGLEVEL_OFF" visibility="public" as="xs:integer" select="0"/>
    <xsl:variable name="sfp:LOGLEVEL_FATAL" visibility="public" as="xs:integer" select="10"/>
    <xsl:variable name="sfp:LOGLEVEL_SEVERE" visibility="public" as="xs:integer" select="20"/>
    <xsl:variable name="sfp:LOGLEVEL_WARNING" visibility="public" as="xs:integer" select="30"/>
    <xsl:variable name="sfp:LOGLEVEL_INFO" visibility="public" as="xs:integer" select="40"/>
    <xsl:variable name="sfp:LOGLEVEL_ALL" visibility="public" as="xs:integer" select="50"/>
    <xsl:variable name="sfp:LOGLEVEL_NOTSET" visibility="public" as="xs:integer" select="100"/>
    
    <xsl:variable name="sfp:LOGLEVEL" visibility="public" as="xs:integer" select="$sfp:LOGLEVEL_NOTSET"/> <!-- Initially set it to a high value so that all messages are output if sfp:LOGLEVEL is not defined in the calling template. -->
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Outputs any log message (if LOGLEVEL doesn't restrict).</xd:p>
        </xd:desc>
        <xd:param name="message">Message to write to log</xd:param>
    </xd:doc>
    <xsl:template name="sfp:logAll" visibility="private">
        <xsl:param name="message" as="xs:string" required="yes"/>
        <xsl:if test="$sfp:LOGLEVEL = $sfp:LOGLEVEL_NOTSET">
            <xsl:message>WARNING: sfp:LOGLEVEL not set.</xsl:message>
        </xsl:if>
        <xsl:if test="$sfp:LOGLEVEL >= $sfp:LOGLEVEL_ALL">
            <xsl:message>
                <xsl:sequence select="concat('*** INFO *** ', $message)"/>
            </xsl:message>
        </xsl:if>
    </xsl:template>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Outputs INFO log message (if LOGLEVEL doesn't restrict).</xd:p>
        </xd:desc>
        <xd:param name="message">Message to write to log</xd:param>
    </xd:doc>
    <xsl:template name="sfp:logInfo" visibility="private">
        <xsl:param name="message" as="xs:string" required="yes"/>
        <xsl:if test="$sfp:LOGLEVEL = $sfp:LOGLEVEL_NOTSET">
            <xsl:message>WARNING: sfp:LOGLEVEL not set.</xsl:message>
        </xsl:if>
        <xsl:if test="$sfp:LOGLEVEL >= $sfp:LOGLEVEL_INFO">
            <xsl:message>
                <xsl:sequence select="concat('*** INFO *** ', $message)"/>
            </xsl:message>
        </xsl:if>
    </xsl:template>
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Outputs WARNING log message (if LOGLEVEL doesn't restrict).</xd:p>
        </xd:desc>
        <xd:param name="message">Message to write to log</xd:param>
    </xd:doc>
    <xsl:template name="sfp:logWarning" visibility="private">
        <xsl:param name="message" as="xs:string" required="yes"/>
        <xsl:if test="$sfp:LOGLEVEL = $sfp:LOGLEVEL_NOTSET">
            <xsl:message>WARNING: sfp:LOGLEVEL not set.</xsl:message>
        </xsl:if>
        <xsl:if test="$sfp:LOGLEVEL >= $sfp:LOGLEVEL_WARNING">
            <xsl:message>
                <xsl:sequence select="concat('*** WARNING *** ', $message)"/>
            </xsl:message>
        </xsl:if>
    </xsl:template>
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Outputs SEVERE log message (if LOGLEVEL doesn't restrict).</xd:p>
        </xd:desc>
        <xd:param name="message">Message to write to log</xd:param>
    </xd:doc>
    <xsl:template name="sfp:logSevere" visibility="private">
        <xsl:param name="message" as="xs:string" required="yes"/>
        <xsl:if test="$sfp:LOGLEVEL = $sfp:LOGLEVEL_NOTSET">
            <xsl:message>WARNING: sfp:LOGLEVEL not set.</xsl:message>
        </xsl:if>
        <xsl:if test="$sfp:LOGLEVEL >= $sfp:LOGLEVEL_SEVERE">
            <xsl:message>
                <xsl:sequence select="concat('*** SEVERE *** ', $message)"/>
            </xsl:message>
        </xsl:if>
    </xsl:template>
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Outputs FATAL log message (if LOGLEVEL doesn't restrict).</xd:p>
            <xd:p>Warning: Calling this function will result in your stylesheet terminating</xd:p>
        </xd:desc>
        <xd:param name="message">Message to write to log</xd:param>
    </xd:doc>
    <xsl:template name="sfp:logFatal" visibility="private">
        <xsl:param name="message" as="xs:string" required="yes"/>
        <xsl:if test="$sfp:LOGLEVEL = $sfp:LOGLEVEL_NOTSET">
            <xsl:message>WARNING: sfp:LOGLEVEL not set.</xsl:message>
        </xsl:if>
        <xsl:if test="$sfp:LOGLEVEL >= $sfp:LOGLEVEL_FATAL">
            <xsl:message terminate="yes">
                <xsl:sequence select="concat('*** FATAL *** ', $message)"/>
            </xsl:message>
        </xsl:if>
    </xsl:template>
    
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Function to call log templates using arbitrary log levels.</xd:p>
        </xd:desc>
        <xd:param name="loglevel">Integer representing level of severity of message</xd:param>
        <xd:param name="message">Message to write to log.</xd:param>
    </xd:doc>
    <xsl:function name="sfp:log" visibility="private" as="empty-sequence()">
        <xsl:param name="loglevel" as="xs:integer" required="yes"/>
        <xsl:param name="message" as="xs:string" required="yes"/>
        <xsl:choose>
            <xsl:when test="$loglevel le $sfp:LOGLEVEL_FATAL">
                <xsl:call-template name="sfp:logFatal">
                    <xsl:with-param name="message" select="$message"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$loglevel le $sfp:LOGLEVEL_SEVERE">
                <xsl:call-template name="sfp:logSevere">
                    <xsl:with-param name="message" select="$message"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$loglevel le $sfp:LOGLEVEL_WARNING">
                <xsl:call-template name="sfp:logWarning">
                    <xsl:with-param name="message" select="$message"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$loglevel le $sfp:LOGLEVEL_INFO">
                <xsl:call-template name="sfp:logInfo">
                    <xsl:with-param name="message" select="$message"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
                <xsl:call-template name="sfp:logAll">
                    <xsl:with-param name="message" select="$message"/>
                </xsl:call-template>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Function to call fatal log messages</xd:p>
        </xd:desc>
        <xd:param name="message">Message to write to log.</xd:param>
    </xd:doc>
    <xsl:function name="sfp:logFatal" visibility="public" as="empty-sequence()">
        <xsl:param name="message" as="xs:string" required="yes"/>
        <xsl:sequence select="sfp:log($sfp:LOGLEVEL_FATAL, $message)"/>
    </xsl:function>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Function to call severe log messages</xd:p>
        </xd:desc>
        <xd:param name="message">Message to write to log.</xd:param>
    </xd:doc>
    <xsl:function name="sfp:logSevere" visibility="public" as="empty-sequence()">
        <xsl:param name="message" as="xs:string" required="yes"/>
        <xsl:sequence select="sfp:log($sfp:LOGLEVEL_SEVERE, $message)"/>
    </xsl:function>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Function to call warning log messages</xd:p>
        </xd:desc>
        <xd:param name="message">Message to write to log.</xd:param>
    </xd:doc>
    <xsl:function name="sfp:logWarning" visibility="public" as="empty-sequence()">
        <xsl:param name="message" as="xs:string" required="yes"/>
        <xsl:sequence select="sfp:log($sfp:LOGLEVEL_WARNING, $message)"/>
    </xsl:function>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Function to call info log messages</xd:p>
        </xd:desc>
        <xd:param name="message">Message to write to log.</xd:param>
    </xd:doc>
    <xsl:function name="sfp:logInfo" visibility="public" as="empty-sequence()">
        <xsl:param name="message" as="xs:string" required="yes"/>
        <xsl:sequence select="sfp:log($sfp:LOGLEVEL_INFO, $message)"/>
    </xsl:function>
    
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Function to call general log messages</xd:p>
        </xd:desc>
        <xd:param name="message">Message to write to log.</xd:param>
    </xd:doc>
    <xsl:function name="sfp:logAll" visibility="public" as="empty-sequence()">
        <xsl:param name="message" as="xs:string" required="yes"/>
        <xsl:sequence select="sfp:log($sfp:LOGLEVEL_ALL, $message)"/>
    </xsl:function>
    
</xsl:package>
