<xsl:transform
   xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:ixsl="http://saxonica.com/ns/interactiveXSLT"
   xmlns:xs="http://www.w3.org/2001/XMLSchema"
   xmlns:map="http://www.w3.org/2005/xpath-functions/map"
   xmlns:array="http://www.w3.org/2005/xpath-functions/array"
   xmlns:f="http://www.saxonica.com/local/functions"
   xmlns:js="http://saxonica.com/ns/globalJS"
   xmlns:saxon="http://saxon.sf.net/"
   xmlns:xforms="http://www.w3.org/2002/xforms"
   exclude-result-prefixes="#all"
   extension-element-prefixes="ixsl"
   version="3.0"
   >
   
   <xsl:import href="../../src/saxon-xforms.xsl"/>
   
   
   <!-- The $bookingForm document contains the main form, in XForms format -->
   <xsl:variable name="bookingForm" as="xs:string" select="resolve-uri('../sample1/sampleBookingForm.xml', ixsl:location())"/>
   
   <xsl:template name="main">
      <!-- Use ixsl:schedule-action so that a subsequent doc() call on the document specified in
         @document is obtained using an asynchronous request (and then cached) -->
      <ixsl:schedule-action document="{$bookingForm}">
         <xsl:call-template name="main2"/>
      </ixsl:schedule-action>
   </xsl:template>
   
   <xsl:template name="main2">
      <xsl:call-template name="xformsjs-main" >
         <xsl:with-param name="xforms-doc" select="doc($bookingForm)" />
         <xsl:with-param name="xFormsId" select="'xForm'" />
      </xsl:call-template>
   </xsl:template>
   
   
   
</xsl:transform>