Saxon-Forms
=========

The Saxon-Forms implementation is a XForms prototype written using Interactive XSLT 3.0. 
Interactive XSLT 3.0 is a feature of Saxon-JS, which is an XSLT 3.0 run-time written in pure JavaScript for use in the brower or a platform that supports JavaScript.

Presented at XMLLondon conference 2017. See paper: 
[Distributing XSLT Processing
between Client and Server](http://xmllondon.com/2017/xmllondon-2017-proceedings.pdf).

## Build

The latest builds of Saxon-Forms is placed in the build directory (i.e. xforms-js.sef.xml). However to build the tool yourself you will need [Saxon-EE](http://www.saxonica.com/download/download_page.xml) to export the stylesheet into an export file (SEF file) to run directly in Saxon-JS. See instructions to build the Saxon executable for Saxon-JS see: 
[Exporting for JS](http://www.saxonica.com/saxon-js/documentation/index.html#!starting/export) 


## Setup
Saxon-Forms currently supports Saxon-JS 1.0.0. To run Saxon-Forms you will need the latest Saxon-JS which can be downloaded at 
[Saxon-JS](http://www.saxonica.com/saxon-js/index.xml). Please see sample1 and sample2 which shows two ways alternative ways to use Saxon-Forms.

- Saxon-Forms can be loaded directly with the source document being the XForms application. See
[sample1](https://github.com/Saxonica/Saxon-Forms/tree/master/samples/sample1).
- Alternatively, Saxon-Forms can be loaded via a seperate stylsheet by a xsl:call-template or apply-template. See
[sample2](https://github.com/Saxonica/Saxon-Forms/tree/master/samples/sample2). 



## Technical Details

The XML instance data structure is maintained as JSON object on the page. However we have had to disable this feature temporarily due to a bug in Saxon-JS, which has now bee resolved and will be available in the next release.

