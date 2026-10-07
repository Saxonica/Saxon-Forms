<?xml version="1.0" encoding="UTF-8"?>
<p:declare-step xmlns:p="http://www.w3.org/ns/xproc" name="validate-rng" version="3.0">
  <p:input port="source" primary="true" content-types="application/xml text/xml application/xhtml+xml"/>
  <p:input port="schema"/>
  <p:output port="result" primary="true"/>
  <p:validate-with-relax-ng assert-valid="true">
    <p:with-input port="schema" pipe="schema@validate-rng"/>
  </p:validate-with-relax-ng>
</p:declare-step>
