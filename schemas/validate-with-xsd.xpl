<?xml version="1.0" encoding="UTF-8"?>
<p:declare-step xmlns:p="http://www.w3.org/ns/xproc" name="validate-xsd" version="3.0">
  <p:input port="source" primary="true" content-types="application/xml text/xml application/xhtml+xml"/>
  <p:input port="schema"/>
  <p:output port="result" primary="true"/>
  <p:validate-with-xml-schema assert-valid="true">
    <p:with-input port="schema" pipe="schema@validate-xsd"/>
  </p:validate-with-xml-schema>
</p:declare-step>
