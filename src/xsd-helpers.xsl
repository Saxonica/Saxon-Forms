<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:xsdh="http://saxonica.com/ns/xsd-helpers"
    exclude-result-prefixes="xs xd xsdh"
    version="3.0">

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Normalize datatype names from xsd:/xs:/xforms: prefixes into canonical local names.</xd:p>
            <xd:p>Special-cases custom ccnumber handling used by 2.3.a.</xd:p>
        </xd:desc>
        <xd:param name="binding-type">Datatype string from bind metadata</xd:param>
    </xd:doc>
    <xsl:function name="xsdh:canonical-type" as="xs:string">
        <xsl:param name="binding-type" as="xs:string?"/>
        <xsl:variable name="raw" as="xs:string" select="lower-case(normalize-space(string($binding-type)))"/>
        <xsl:variable name="normalized-prefix" as="xs:string" select="
            if (starts-with($raw,'xsd:') or starts-with($raw,'xs:') or starts-with($raw,'xforms:'))
            then substring-after($raw,':')
            else $raw"/>
        <xsl:sequence select="
            if ($normalized-prefix = '')
            then ''
            else if ($raw = ('my:ccnumber','ccnumber'))
            then 'ccnumber-strict'
            else if ($raw = ('xforms:card-number','card-number'))
            then 'card-number'
            else $normalized-prefix"/>
    </xsl:function>
    <xsl:variable name="xsdh:type-validators" as="map(xs:string, function(xs:string) as xs:boolean)" select="
        map{
            'datetime': function($v as xs:string) as xs:boolean { ($v castable as xs:dateTime) or xsdh:is-native-datetime-local-lexical($v) },
            'time': function($v as xs:string) as xs:boolean { ($v castable as xs:time) or xsdh:is-native-time-lexical($v) },
            'date': function($v as xs:string) as xs:boolean { $v castable as xs:date },
            'gyearmonth': function($v as xs:string) as xs:boolean { $v castable as xs:gYearMonth },
            'gyear': function($v as xs:string) as xs:boolean { $v castable as xs:gYear },
            'gmonthday': function($v as xs:string) as xs:boolean { $v castable as xs:gMonthDay },
            'gday': function($v as xs:string) as xs:boolean { $v castable as xs:gDay },
            'gmonth': function($v as xs:string) as xs:boolean { $v castable as xs:gMonth },
            'string': function($v as xs:string) as xs:boolean { true() },
            'normalizedstring': function($v as xs:string) as xs:boolean { true() },
            'token': function($v as xs:string) as xs:boolean { true() },
            'language': function($v as xs:string) as xs:boolean { $v castable as xs:language },
            'name': function($v as xs:string) as xs:boolean { $v castable as xs:Name },
            'ncname': function($v as xs:string) as xs:boolean { $v castable as xs:NCName },
            'id': function($v as xs:string) as xs:boolean { $v castable as xs:ID },
            'idref': function($v as xs:string) as xs:boolean { $v castable as xs:IDREF },
            'idrefs': function($v as xs:string) as xs:boolean { $v castable as xs:IDREFS },
            'nmtoken': function($v as xs:string) as xs:boolean { $v castable as xs:NMTOKEN },
            'nmtokens': function($v as xs:string) as xs:boolean { $v castable as xs:NMTOKENS },
            'boolean': function($v as xs:string) as xs:boolean { $v castable as xs:boolean },
            'base64binary': function($v as xs:string) as xs:boolean { $v castable as xs:base64Binary },
            'hexbinary': function($v as xs:string) as xs:boolean { $v castable as xs:hexBinary },
            'float': function($v as xs:string) as xs:boolean { $v castable as xs:float },
            'decimal': function($v as xs:string) as xs:boolean { $v castable as xs:decimal },
            'double': function($v as xs:string) as xs:boolean { $v castable as xs:double },
            'anyuri': function($v as xs:string) as xs:boolean { not(matches($v,'\s')) and ($v castable as xs:anyURI) },
            'qname': function($v as xs:string) as xs:boolean { matches($v,'^\i\c*(:\i\c*)?$') },
            'integer': function($v as xs:string) as xs:boolean { $v castable as xs:integer },
            'nonpositiveinteger': function($v as xs:string) as xs:boolean { $v castable as xs:nonPositiveInteger },
            'negativeinteger': function($v as xs:string) as xs:boolean { $v castable as xs:negativeInteger },
            'long': function($v as xs:string) as xs:boolean { $v castable as xs:long },
            'int': function($v as xs:string) as xs:boolean { $v castable as xs:int },
            'short': function($v as xs:string) as xs:boolean { $v castable as xs:short },
            'byte': function($v as xs:string) as xs:boolean { $v castable as xs:byte },
            'nonnegativeinteger': function($v as xs:string) as xs:boolean { $v castable as xs:nonNegativeInteger },
            'unsignedlong': function($v as xs:string) as xs:boolean { $v castable as xs:unsignedLong },
            'unsignedint': function($v as xs:string) as xs:boolean { $v castable as xs:unsignedInt },
            'unsignedshort': function($v as xs:string) as xs:boolean { $v castable as xs:unsignedShort },
            'unsignedbyte': function($v as xs:string) as xs:boolean { $v castable as xs:unsignedByte },
            'positiveinteger': function($v as xs:string) as xs:boolean { $v castable as xs:positiveInteger },
            'listitem': function($v as xs:string) as xs:boolean { not(matches($v,'\s')) },
            'listitems': function($v as xs:string) as xs:boolean { matches($v,'^\S+(\s+\S+)*$') },
            'daytimeduration': function($v as xs:string) as xs:boolean { $v castable as xs:dayTimeDuration },
            'yearmonthduration': function($v as xs:string) as xs:boolean { $v castable as xs:yearMonthDuration },
            'email': function($v as xs:string) as xs:boolean { matches($v,'^[^\s@]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$') },
            'card-number': function($v as xs:string) as xs:boolean { matches($v,'^\d{12,19}$') },
            'ccnumber-strict': function($v as xs:string) as xs:boolean { matches($v,'^\d{14,18}$') }
        }"/>

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Return true when a value is valid for a given datatype.</xd:p>
            <xd:p>Empty values are accepted by default so @required remains the source of presence checks, except for explicit nonEmptyString handling.</xd:p>
        </xd:desc>
        <xd:param name="binding-type">Datatype string from bind metadata</xd:param>
        <xd:param name="raw-value">Current lexical value to validate</xd:param>
    </xd:doc>
    <xsl:function name="xsdh:is-type-valid" as="xs:boolean">
        <xsl:param name="binding-type" as="xs:string?"/>
        <xsl:param name="raw-value" as="xs:string?"/>
        <xsl:variable name="raw-type" as="xs:string" select="lower-case(normalize-space(string($binding-type)))"/>
        <xsl:variable name="is-xforms-type" as="xs:boolean" select="starts-with($raw-type,'xforms:')"/>
        <xsl:variable name="type" as="xs:string" select="xsdh:canonical-type($binding-type)"/>
        <xsl:variable name="value" as="xs:string" select="normalize-space(string($raw-value))"/>
        <xsl:variable name="validator" as="(function(xs:string) as xs:boolean)?" select="$xsdh:type-validators($type)"/>
        <!--
            High-level lexical validation model:
            - canonical-type() normalizes prefix variants into a single internal token.
            - A type->validator map centralizes castability and regex checks by canonical token.
            - For xforms:* custom types, empty lexical values are accepted here so requiredness
              remains controlled by @required/relevant logic in the runtime.
            - Unknown/non-mapped types intentionally default to true() so schema-aware validation
              (when available) can make the final decision based on restriction facets.
        -->
        <xsl:sequence select="
            if ($type = '')
            then true()
            else if ($type = 'nonemptystring')
            then string-length($value) gt 0
            else if ($value = '' and $is-xforms-type)
            then true()
            else if (exists($validator))
            then $validator($value)
            else if (starts-with($type,'list:'))
            then (
                let $item-type := substring-after($type,'list:'),
                    $items := tokenize(normalize-space($value),'\s+')
                return
                    if (normalize-space($value) = '')
                    then true()
                    else every $item in $items satisfies xsdh:is-type-valid($item-type,$item)
            )
            else true()"/>
    </xsl:function>
    <xsl:function name="xsdh:is-native-time-lexical" as="xs:boolean">
        <xsl:param name="value" as="xs:string"/>
        <xsl:sequence select="matches($value,'^([01][0-9]|2[0-3]):[0-5][0-9]$')"/>
    </xsl:function>
    <xsl:function name="xsdh:is-native-datetime-local-lexical" as="xs:boolean">
        <xsl:param name="value" as="xs:string"/>
        <xsl:sequence select="matches($value,'^[0-9]{4}-[0-9]{2}-[0-9]{2}T([01][0-9]|2[0-3]):[0-5][0-9]$')"/>
    </xsl:function>


    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Validate a lexical value against a schema-derived restricted simpleType.</xd:p>
            <xd:p>This supports scoped XSD facet checks used by the NIST facet harness for Saxon-Forms.</xd:p>
        </xd:desc>
        <xd:param name="binding-type">Named simpleType from bind metadata or schema element @type</xd:param>
        <xd:param name="raw-value">Current lexical value to validate</xd:param>
        <xd:param name="schema-doc">Schema document containing simpleType restrictions</xd:param>
    </xd:doc>
    <xsl:function name="xsdh:is-type-valid-against-schema" as="xs:boolean">
        <xsl:param name="binding-type" as="xs:string?"/>
        <xsl:param name="raw-value" as="xs:string?"/>
        <xsl:param name="schema-doc" as="document-node()?"/>
        <xsl:variable name="type-name" as="xs:string" select="normalize-space(string($binding-type))"/>
        <xsl:variable name="type-local" as="xs:string" select="xsdh:local-type-name($type-name)"/>
        <!--
            restriction-chain() returns inherited restrictions followed by local restriction,
            so downstream checks evaluate the complete effective facet set.
        -->
        <xsl:variable name="restrictions" as="element(xs:restriction)*" select="xsdh:restriction-chain($schema-doc,$type-local,())"/>
        <!--
            resolved-base-type() walks named simpleType inheritance until it reaches an xs:*
            built-in base type (or exits safely if unresolved/cyclic).
        -->
        <xsl:variable name="base-type" as="xs:string" select="xsdh:resolved-base-type($schema-doc,$type-local,())"/>
        <!-- TEST-TRACE: apply whiteSpace facet normalization before facet checks; helps scripts/run-nist-facet-harness.mjs whiteSpace groups. -->
        <xsl:variable name="normalized-value" as="xs:string" select="xsdh:apply-white-space(string($raw-value),$restrictions)"/>
        <!--
            Evaluation order:
            1) If there is no schema context, fall back to lexical validator only.
            2) If type has no restrictions in this schema, fall back to lexical validator.
            3) Validate against the resolved built-in base type first.
            4) Apply effective facet set via facet-valid().
        -->
        <xsl:sequence select="
            if ($type-name = '' or empty($schema-doc))
            then xsdh:is-type-valid($type-name,$raw-value)
            else if (empty($restrictions))
            then xsdh:is-type-valid($type-name,$raw-value)
            else if (not(xsdh:is-type-valid($base-type,$normalized-value)))
            then false()
            else xsdh:facet-valid($normalized-value,$base-type,$restrictions)"/>
    </xsl:function>

    <xsl:function name="xsdh:facet-valid" as="xs:boolean">
        <xsl:param name="value" as="xs:string"/>
        <xsl:param name="base-type" as="xs:string"/>
        <xsl:param name="restrictions" as="element(xs:restriction)*"/>
        <xsl:variable name="canonical" as="xs:string" select="xsdh:canonical-type($base-type)"/>
        <xsl:variable name="length-facets" as="xs:integer*" select="$restrictions/xs:length/@value ! xs:integer(.)"/>
        <xsl:variable name="min-length-facets" as="xs:integer*" select="$restrictions/xs:minLength/@value ! xs:integer(.)"/>
        <xsl:variable name="max-length-facets" as="xs:integer*" select="$restrictions/xs:maxLength/@value ! xs:integer(.)"/>
        <xsl:variable name="pattern-facets" as="xs:string*" select="$restrictions/xs:pattern/@value ! string(.)"/>
        <xsl:variable name="enum-facets" as="xs:string*" select="$restrictions/xs:enumeration/@value ! string(.)"/>
        <xsl:variable name="min-inclusive-facets" as="xs:string*" select="$restrictions/xs:minInclusive/@value ! string(.)"/>
        <xsl:variable name="max-inclusive-facets" as="xs:string*" select="$restrictions/xs:maxInclusive/@value ! string(.)"/>
        <xsl:variable name="min-exclusive-facets" as="xs:string*" select="$restrictions/xs:minExclusive/@value ! string(.)"/>
        <xsl:variable name="max-exclusive-facets" as="xs:string*" select="$restrictions/xs:maxExclusive/@value ! string(.)"/>
        <xsl:variable name="total-digits-facets" as="xs:integer*" select="$restrictions/xs:totalDigits/@value ! xs:integer(.)"/>
        <xsl:variable name="fraction-digits-facets" as="xs:integer*" select="$restrictions/xs:fractionDigits/@value ! xs:integer(.)"/>
        <!-- TEST-TRACE: use type-aware facet length semantics (not raw lexical length) for binary families; helps scripts/run-nist-facet-harness.mjs base64Binary length groups. -->
        <xsl:variable name="length" as="xs:integer?" select="xsdh:facet-length($value,$base-type)"/>
        <!-- TEST-TRACE: support totalDigits/fractionDigits for decimal-derived types; helps scripts/run-nist-facet-harness.mjs decimal digit groups. -->
        <xsl:variable name="decimal-lex" as="xs:string?" select="
            if (xsdh:is-decimal-family($base-type) and ($value castable as xs:decimal))
            then string(xs:decimal($value))
            else ()"/>
        <xsl:variable name="decimal-total-digits" as="xs:integer?" select="
            if (exists($decimal-lex))
            then string-length(replace($decimal-lex,'[^0-9]',''))
            else ()"/>
        <xsl:variable name="decimal-fraction-digits" as="xs:integer?" select="
            if (exists($decimal-lex))
            then (if (contains($decimal-lex,'.')) then string-length(substring-after($decimal-lex,'.')) else 0)
            else ()"/>
        <!--
            Conjunctive facet policy:
            - Every present facet category must hold.
            - Missing facet category => neutral true().
            - enumeration and bound comparisons delegate to type-aware helpers.
            This keeps the main boolean expression readable while preserving explicit semantics.
        -->
        <xsl:sequence select="
            xsdh:length-facet-ok($canonical,$length,$length-facets,'eq')
            and xsdh:length-facet-ok($canonical,$length,$min-length-facets,'ge')
            and xsdh:length-facet-ok($canonical,$length,$max-length-facets,'le')
            and (every $p in $pattern-facets satisfies xsdh:facet-pattern-match($value,$p))
            and (empty($enum-facets) or (some $enum in $enum-facets satisfies xsdh:facet-value-eq($value,$enum,$base-type)))
            and (every $bound in $min-inclusive-facets satisfies xsdh:facet-compare($value,$bound,$base-type,'ge'))
            and (every $bound in $max-inclusive-facets satisfies xsdh:facet-compare($value,$bound,$base-type,'le'))
            and (every $bound in $min-exclusive-facets satisfies xsdh:facet-compare($value,$bound,$base-type,'gt'))
            and (every $bound in $max-exclusive-facets satisfies xsdh:facet-compare($value,$bound,$base-type,'lt'))
            and (
                empty($total-digits-facets)
                or (exists($decimal-total-digits) and (every $limit in $total-digits-facets satisfies $decimal-total-digits le $limit))
            )
            and (
                empty($fraction-digits-facets)
                or (exists($decimal-fraction-digits) and (every $limit in $fraction-digits-facets satisfies $decimal-fraction-digits le $limit))
            )"/>
    </xsl:function>
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Evaluate length, minLength, and maxLength facet families with shared semantics.</xd:p>
            <xd:p>QName remains exempt, and missing computed length fails closed when facets are present.</xd:p>
        </xd:desc>
        <xd:param name="canonical">Canonical base type token</xd:param>
        <xd:param name="length">Computed facet length when available</xd:param>
        <xd:param name="facets">Facet limits for one length-family category</xd:param>
        <xd:param name="op">Comparison operation: eq/ge/le</xd:param>
    </xd:doc>
    <xsl:function name="xsdh:length-facet-ok" as="xs:boolean">
        <xsl:param name="canonical" as="xs:string"/>
        <xsl:param name="length" as="xs:integer?"/>
        <xsl:param name="facets" as="xs:integer*"/>
        <xsl:param name="op" as="xs:string"/>
        <xsl:sequence select="
            if (empty($facets) or $canonical = 'qname')
            then true()
            else if (not(exists($length)))
            then false()
            else if ($op = 'eq')
            then every $l in $facets satisfies $length = $l
            else if ($op = 'ge')
            then every $l in $facets satisfies $length ge $l
            else if ($op = 'le')
            then every $l in $facets satisfies $length le $l
            else false()"/>
    </xsl:function>
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Return facet length using datatype-aware semantics where needed.</xd:p>
            <xd:p>Binary datatypes count octets; fallback remains lexical string-length.</xd:p>
        </xd:desc>
        <xd:param name="value">Facet candidate lexical value</xd:param>
        <xd:param name="base-type">Resolved base type lexical name</xd:param>
    </xd:doc>

    <xsl:function name="xsdh:facet-length" as="xs:integer?">
        <xsl:param name="value" as="xs:string"/>
        <xsl:param name="base-type" as="xs:string"/>
        <xsl:variable name="canonical" as="xs:string" select="xsdh:canonical-type($base-type)"/>
        <!--
            Length semantics notes:
            - base64Binary and hexBinary length/minLength/maxLength are byte-count based.
            - We convert through canonical hex representation and divide by 2 to get octets.
            - Other datatypes currently use lexical string-length fallback.
        -->
        <xsl:sequence select="
            if ($canonical = 'base64binary' and ($value castable as xs:base64Binary))
            then string-length(string(xs:hexBinary(xs:base64Binary($value)))) idiv 2
            else if ($canonical = 'hexbinary' and ($value castable as xs:hexBinary))
            then string-length(string(xs:hexBinary($value))) idiv 2
            else if (starts-with($canonical,'list:'))
            then (if (normalize-space($value) = '') then 0 else count(tokenize(normalize-space($value),'\s+')))
            else string-length($value)"/>
    </xsl:function>
    <xsl:function name="xsdh:facet-pattern-match" as="xs:boolean">
        <xsl:param name="value" as="xs:string"/>
        <xsl:param name="pattern" as="xs:string"/>
        <!-- XSD pattern facets are whole-value matches, not substring matches. -->
        <xsl:variable name="normalized-pattern" as="xs:string" select="
            xsdh:replace-literal(
                xsdh:replace-literal($pattern,'[\i-[:]]','\i'),
                '[\c-[:]]','\c'
            )"/>
        <xsl:sequence select="matches($value,concat('^(',$normalized-pattern,')$'))"/>
    </xsl:function>
    <xsl:function name="xsdh:replace-literal" as="xs:string">
        <xsl:param name="input" as="xs:string"/>
        <xsl:param name="search" as="xs:string"/>
        <xsl:param name="replacement" as="xs:string"/>
        <xsl:sequence select="
            if ($search = '' or not(contains($input,$search)))
            then $input
            else concat(
                substring-before($input,$search),
                $replacement,
                xsdh:replace-literal(substring-after($input,$search),$search,$replacement)
            )"/>
    </xsl:function>

    <xsl:function name="xsdh:facet-value-eq" as="xs:boolean">
        <xsl:param name="left" as="xs:string"/>
        <xsl:param name="right" as="xs:string"/>
        <xsl:param name="base-type" as="xs:string"/>
        <!--
            Equality strategy for enumeration facets:
            - decimal-family values compare in numeric value-space
            - float/double values compare in floating numeric value-space
            - otherwise lexical equality fallback
        -->
        <xsl:sequence select="
            if (xsdh:is-decimal-family($base-type) and ($left castable as xs:decimal) and ($right castable as xs:decimal))
            then xs:decimal($left) = xs:decimal($right)
            else if (xsdh:canonical-type($base-type) = ('float','double') and ($left castable as xs:double) and ($right castable as xs:double))
            then xs:double($left) = xs:double($right)
            else $left = $right"/>
    </xsl:function>
    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Evaluate ordered comparisons for already-cast atomic values.</xd:p>
            <xd:p>Unsupported operators fail closed as false().</xd:p>
        </xd:desc>
        <xd:param name="left">Typed left value</xd:param>
        <xd:param name="right">Typed right value</xd:param>
        <xd:param name="op">Comparison operation: ge/le/gt/lt</xd:param>
    </xd:doc>
    <xsl:function name="xsdh:ordered" as="xs:boolean">
        <xsl:param name="left" as="xs:anyAtomicType"/>
        <xsl:param name="right" as="xs:anyAtomicType"/>
        <xsl:param name="op" as="xs:string"/>
        <xsl:sequence select="
            if ($op = 'ge') then $left ge $right
            else if ($op = 'le') then $left le $right
            else if ($op = 'gt') then $left gt $right
            else if ($op = 'lt') then $left lt $right
            else false()"/>
    </xsl:function>

    <xsl:function name="xsdh:facet-compare" as="xs:boolean">
        <xsl:param name="left" as="xs:string"/>
        <xsl:param name="right" as="xs:string"/>
        <xsl:param name="base-type" as="xs:string"/>
        <xsl:param name="op" as="xs:string"/>
        <!-- TEST-TRACE: add ordered facet comparisons for date/time families; helps scripts/run-nist-facet-harness.mjs date/dateTime/gDay boundary groups. -->
        <xsl:variable name="canonical" as="xs:string" select="xsdh:canonical-type($base-type)"/>
        <!--
            Ordered comparison strategy:
            - Use native typed comparisons where XPath defines ordering.
            - For gDay/gMonth/gMonthDay, dispatch to lexical-component helpers to avoid
              processor errors on direct ordered comparisons of partial-date primitives.
            - Unsupported type/op combinations fail closed as false().
        -->
        <xsl:sequence select="
            if (xsdh:is-decimal-family($base-type) and ($left castable as xs:decimal) and ($right castable as xs:decimal))
            then xsdh:ordered(xs:decimal($left),xs:decimal($right),$op)
            else if ($canonical = ('float','double') and ($left castable as xs:double) and ($right castable as xs:double))
            then xsdh:ordered(xs:double($left),xs:double($right),$op)
            else if ($canonical = 'date' and ($left castable as xs:date) and ($right castable as xs:date))
            then xsdh:ordered(xs:date($left),xs:date($right),$op)
            else if ($canonical = 'datetime' and ($left castable as xs:dateTime) and ($right castable as xs:dateTime))
            then xsdh:ordered(xs:dateTime($left),xs:dateTime($right),$op)
            else if ($canonical = 'time' and ($left castable as xs:time) and ($right castable as xs:time))
            then xsdh:ordered(xs:time($left),xs:time($right),$op)
            else if ($canonical = 'gyearmonth' and ($left castable as xs:gYearMonth) and ($right castable as xs:gYearMonth))
            then xsdh:facet-compare-gyearmonth($left,$right,$op)
            else if ($canonical = 'gyear' and ($left castable as xs:gYear) and ($right castable as xs:gYear))
            then xsdh:facet-compare-gyear($left,$right,$op)
            else if ($canonical = 'gmonthday' and ($left castable as xs:gMonthDay) and ($right castable as xs:gMonthDay))
            then xsdh:facet-compare-gmonthday($left,$right,$op)
            else if ($canonical = 'gday' and ($left castable as xs:gDay) and ($right castable as xs:gDay))
            then xsdh:facet-compare-gday($left,$right,$op)
            else if ($canonical = 'gmonth' and ($left castable as xs:gMonth) and ($right castable as xs:gMonth))
            then xsdh:facet-compare-gmonth($left,$right,$op)
            else if ($canonical = 'duration' and ($left castable as xs:duration) and ($right castable as xs:duration))
            then xsdh:facet-compare-duration($left,$right,$op)
            else if ($canonical = 'daytimeduration' and ($left castable as xs:dayTimeDuration) and ($right castable as xs:dayTimeDuration))
            then xsdh:ordered(xs:dayTimeDuration($left),xs:dayTimeDuration($right),$op)
            else if ($canonical = 'yearmonthduration' and ($left castable as xs:yearMonthDuration) and ($right castable as xs:yearMonthDuration))
            then xsdh:ordered(xs:yearMonthDuration($left),xs:yearMonthDuration($right),$op)
            else false()"/>
    </xsl:function>
    <xsl:function name="xsdh:facet-compare-gyear" as="xs:boolean">
        <xsl:param name="left" as="xs:string"/>
        <xsl:param name="right" as="xs:string"/>
        <xsl:param name="op" as="xs:string"/>
        <xsl:variable name="left-year" as="xs:integer?" select="
            if (matches($left,'^-?[0-9]{4,}'))
            then xs:integer(replace($left,'^(-?[0-9]{4,}).*$','$1'))
            else ()"/>
        <xsl:variable name="right-year" as="xs:integer?" select="
            if (matches($right,'^-?[0-9]{4,}'))
            then xs:integer(replace($right,'^(-?[0-9]{4,}).*$','$1'))
            else ()"/>
        <xsl:sequence select="
            if (exists($left-year) and exists($right-year))
            then xsdh:facet-compare-integer($left-year,$right-year,$op)
            else false()"/>
    </xsl:function>
    <xsl:function name="xsdh:facet-compare-gyearmonth" as="xs:boolean">
        <xsl:param name="left" as="xs:string"/>
        <xsl:param name="right" as="xs:string"/>
        <xsl:param name="op" as="xs:string"/>
        <xsl:variable name="left-year" as="xs:integer?" select="
            if (matches($left,'^-?[0-9]{4,}-[0-9]{2}'))
            then xs:integer(replace($left,'^(-?[0-9]{4,})-[0-9]{2}.*$','$1'))
            else ()"/>
        <xsl:variable name="left-month" as="xs:integer?" select="
            if (matches($left,'^-?[0-9]{4,}-[0-9]{2}'))
            then xs:integer(replace($left,'^-?[0-9]{4,}-([0-9]{2}).*$','$1'))
            else ()"/>
        <xsl:variable name="right-year" as="xs:integer?" select="
            if (matches($right,'^-?[0-9]{4,}-[0-9]{2}'))
            then xs:integer(replace($right,'^(-?[0-9]{4,})-[0-9]{2}.*$','$1'))
            else ()"/>
        <xsl:variable name="right-month" as="xs:integer?" select="
            if (matches($right,'^-?[0-9]{4,}-[0-9]{2}'))
            then xs:integer(replace($right,'^-?[0-9]{4,}-([0-9]{2}).*$','$1'))
            else ()"/>
        <xsl:variable name="left-key" as="xs:integer?" select="if (exists($left-year) and exists($left-month)) then ($left-year * 100 + $left-month) else ()"/>
        <xsl:variable name="right-key" as="xs:integer?" select="if (exists($right-year) and exists($right-month)) then ($right-year * 100 + $right-month) else ()"/>
        <xsl:sequence select="
            if (exists($left-key) and exists($right-key))
            then xsdh:facet-compare-integer($left-key,$right-key,$op)
            else false()"/>
    </xsl:function>
    <xsl:function name="xsdh:facet-compare-duration" as="xs:boolean">
        <xsl:param name="left" as="xs:string"/>
        <xsl:param name="right" as="xs:string"/>
        <xsl:param name="op" as="xs:string"/>
        <xsl:variable name="left-duration" as="xs:duration" select="xs:duration($left)"/>
        <xsl:variable name="right-duration" as="xs:duration" select="xs:duration($right)"/>
        <xsl:variable name="left-ym" as="xs:yearMonthDuration" select="xs:yearMonthDuration($left-duration)"/>
        <xsl:variable name="left-dt" as="xs:dayTimeDuration" select="xs:dayTimeDuration($left-duration)"/>
        <xsl:variable name="right-ym" as="xs:yearMonthDuration" select="xs:yearMonthDuration($right-duration)"/>
        <xsl:variable name="right-dt" as="xs:dayTimeDuration" select="xs:dayTimeDuration($right-duration)"/>
        <!--
            xs:duration ordering is partial in XML Schema.
            Compare via the four reference dateTimes from Appendix E to determine
            strict ordering only when all anchors agree.
        -->
        <xsl:variable name="anchors" as="xs:dateTime+" select="
            (
                xs:dateTime('1696-09-01T00:00:00Z'),
                xs:dateTime('1697-02-01T00:00:00Z'),
                xs:dateTime('1903-03-01T00:00:00Z'),
                xs:dateTime('1903-07-01T00:00:00Z')
            )"/>
        <xsl:variable name="left-shifts" as="xs:dateTime*" select="for $a in $anchors return (($a + $left-ym) + $left-dt)"/>
        <xsl:variable name="right-shifts" as="xs:dateTime*" select="for $a in $anchors return (($a + $right-ym) + $right-dt)"/>
        <xsl:variable name="all-lt" as="xs:boolean" select="every $i in 1 to count($anchors) satisfies $left-shifts[$i] lt $right-shifts[$i]"/>
        <xsl:variable name="all-gt" as="xs:boolean" select="every $i in 1 to count($anchors) satisfies $left-shifts[$i] gt $right-shifts[$i]"/>
        <xsl:variable name="all-eq" as="xs:boolean" select="every $i in 1 to count($anchors) satisfies $left-shifts[$i] eq $right-shifts[$i]"/>
        <xsl:sequence select="
            if ($op = 'lt') then $all-lt
            else if ($op = 'gt') then $all-gt
            else if ($op = 'le') then ($all-lt or $all-eq)
            else if ($op = 'ge') then ($all-gt or $all-eq)
            else false()"/>
    </xsl:function>

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Compare gDay lexical values by day-of-month component.</xd:p>
        </xd:desc>
        <xd:param name="left">Left lexical gDay</xd:param>
        <xd:param name="right">Right lexical gDay</xd:param>
        <xd:param name="op">Comparison operation: ge/le/gt/lt</xd:param>
    </xd:doc>
    <xsl:function name="xsdh:facet-compare-gday" as="xs:boolean">
        <xsl:param name="left" as="xs:string"/>
        <xsl:param name="right" as="xs:string"/>
        <xsl:param name="op" as="xs:string"/>
        <!-- TEST-TRACE: compare gDay boundaries lexically by day component to avoid xs:gDay ordered-comparison runtime errors; helps scripts/run-nist-facet-harness.mjs atomic-gDay max/min groups. -->
        <xsl:variable name="left-day" as="xs:integer?" select="if (matches($left,'^---[0-9]{2}')) then xs:integer(substring($left,4,2)) else ()"/>
        <xsl:variable name="right-day" as="xs:integer?" select="if (matches($right,'^---[0-9]{2}')) then xs:integer(substring($right,4,2)) else ()"/>
        <xsl:sequence select="
            if (exists($left-day) and exists($right-day))
            then xsdh:facet-compare-integer($left-day,$right-day,$op)
            else false()"/>
    </xsl:function>

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Compare gMonth lexical values by month component.</xd:p>
        </xd:desc>
        <xd:param name="left">Left lexical gMonth</xd:param>
        <xd:param name="right">Right lexical gMonth</xd:param>
        <xd:param name="op">Comparison operation: ge/le/gt/lt</xd:param>
    </xd:doc>
    <xsl:function name="xsdh:facet-compare-gmonth" as="xs:boolean">
        <xsl:param name="left" as="xs:string"/>
        <xsl:param name="right" as="xs:string"/>
        <xsl:param name="op" as="xs:string"/>
        <xsl:variable name="left-month" as="xs:integer?" select="if (matches($left,'^--[0-9]{2}')) then xs:integer(substring($left,3,2)) else ()"/>
        <xsl:variable name="right-month" as="xs:integer?" select="if (matches($right,'^--[0-9]{2}')) then xs:integer(substring($right,3,2)) else ()"/>
        <xsl:sequence select="
            if (exists($left-month) and exists($right-month))
            then xsdh:facet-compare-integer($left-month,$right-month,$op)
            else false()"/>
    </xsl:function>

    <xd:doc scope="component">
        <xd:desc>
            <xd:p>Compare gMonthDay lexical values by (month,day) tuple.</xd:p>
        </xd:desc>
        <xd:param name="left">Left lexical gMonthDay</xd:param>
        <xd:param name="right">Right lexical gMonthDay</xd:param>
        <xd:param name="op">Comparison operation: ge/le/gt/lt</xd:param>
    </xd:doc>
    <xsl:function name="xsdh:facet-compare-gmonthday" as="xs:boolean">
        <xsl:param name="left" as="xs:string"/>
        <xsl:param name="right" as="xs:string"/>
        <xsl:param name="op" as="xs:string"/>
        <xsl:variable name="left-month" as="xs:integer?" select="if (matches($left,'^--[0-9]{2}-[0-9]{2}')) then xs:integer(substring($left,3,2)) else ()"/>
        <xsl:variable name="left-day" as="xs:integer?" select="if (matches($left,'^--[0-9]{2}-[0-9]{2}')) then xs:integer(substring($left,6,2)) else ()"/>
        <xsl:variable name="right-month" as="xs:integer?" select="if (matches($right,'^--[0-9]{2}-[0-9]{2}')) then xs:integer(substring($right,3,2)) else ()"/>
        <xsl:variable name="right-day" as="xs:integer?" select="if (matches($right,'^--[0-9]{2}-[0-9]{2}')) then xs:integer(substring($right,6,2)) else ()"/>
        <xsl:variable name="left-key" as="xs:integer?" select="if (exists($left-month) and exists($left-day)) then ($left-month * 100 + $left-day) else ()"/>
        <xsl:variable name="right-key" as="xs:integer?" select="if (exists($right-month) and exists($right-day)) then ($right-month * 100 + $right-day) else ()"/>
        <xsl:sequence select="
            if (exists($left-key) and exists($right-key))
            then xsdh:facet-compare-integer($left-key,$right-key,$op)
            else false()"/>
    </xsl:function>

    <xsl:function name="xsdh:facet-compare-integer" as="xs:boolean">
        <xsl:param name="left" as="xs:integer"/>
        <xsl:param name="right" as="xs:integer"/>
        <xsl:param name="op" as="xs:string"/>
        <xsl:sequence select="xsdh:ordered($left,$right,$op)"/>
    </xsl:function>

    <xsl:function name="xsdh:is-decimal-family" as="xs:boolean">
        <xsl:param name="base-type" as="xs:string"/>
        <xsl:variable name="canonical" as="xs:string" select="xsdh:canonical-type($base-type)"/>
        <!-- Centralized membership check for decimal + all integer-derived built-ins. -->
        <xsl:sequence select="$canonical = (
            'decimal','integer','nonpositiveinteger','negativeinteger',
            'long','int','short','byte','nonnegativeinteger',
            'unsignedlong','unsignedint','unsignedshort','unsignedbyte','positiveinteger'
        )"/>
    </xsl:function>

    <xsl:function name="xsdh:apply-white-space" as="xs:string">
        <xsl:param name="value" as="xs:string"/>
        <xsl:param name="restrictions" as="element(xs:restriction)*"/>
        <xsl:variable name="mode" as="xs:string?" select="($restrictions/xs:whiteSpace/@value ! lower-case(normalize-space(string(.))))[last()]"/>
        <!--
            whiteSpace facet behavior:
            - replace: normalize tabs/newlines to spaces
            - collapse: replace + trim + collapse internal runs
            - preserve/default: leave input unchanged
            Last-declared facet wins across derivation chain.
        -->
        <xsl:sequence select="
            if ($mode = 'replace')
            then replace($value,'[\t\r\n]',' ')
            else if ($mode = 'collapse')
            then normalize-space(replace($value,'[\t\r\n]',' '))
            else $value"/>
    </xsl:function>

    <xsl:function name="xsdh:resolved-base-type" as="xs:string">
        <xsl:param name="schema-doc" as="document-node()?"/>
        <xsl:param name="type-local" as="xs:string"/>
        <xsl:param name="visited" as="xs:string*"/>
        <!-- Guard recursion with visited to prevent infinite loops on malformed cycles. -->
        <xsl:variable name="simple-type" as="element(xs:simpleType)?" select="$schema-doc/xs:schema/xs:simpleType[@name = $type-local][1]"/>
        <xsl:variable name="list-item-lexical" as="xs:string" select="normalize-space(string($simple-type/xs:list[1]/@itemType))"/>
        <xsl:sequence select="
            if (empty($simple-type) or $type-local = '' or $type-local = $visited)
            then $type-local
            else if ($list-item-lexical != '')
            then concat('list:',xsdh:local-type-name($list-item-lexical))
            else
                let $base-lexical := normalize-space(string($simple-type/xs:restriction[1]/@base)),
                    $base-local := xsdh:local-type-name($base-lexical)
                return
                    if ($base-lexical = '' or starts-with(lower-case($base-lexical),'xs:') or starts-with(lower-case($base-lexical),'xsd:'))
                    then $base-lexical
                    else xsdh:resolved-base-type($schema-doc,$base-local,($visited,$type-local))"/>
    </xsl:function>

    <xsl:function name="xsdh:restriction-chain" as="element(xs:restriction)*">
        <xsl:param name="schema-doc" as="document-node()?"/>
        <xsl:param name="type-local" as="xs:string"/>
        <xsl:param name="visited" as="xs:string*"/>
        <!-- Returns restrictions in ancestor->descendant order for effective facet evaluation. -->
        <xsl:variable name="simple-type" as="element(xs:simpleType)?" select="$schema-doc/xs:schema/xs:simpleType[@name = $type-local][1]"/>
        <xsl:variable name="restriction" as="element(xs:restriction)?" select="$simple-type/xs:restriction[1]"/>
        <xsl:variable name="base-lexical" as="xs:string" select="normalize-space(string($restriction/@base))"/>
        <xsl:variable name="base-local" as="xs:string" select="xsdh:local-type-name($base-lexical)"/>
        <xsl:sequence select="
            if (empty($simple-type) or empty($restriction) or $type-local = '' or $type-local = $visited)
            then ()
            else if (starts-with(lower-case($base-lexical),'xs:') or starts-with(lower-case($base-lexical),'xsd:'))
            then $restriction
            else (xsdh:restriction-chain($schema-doc,$base-local,($visited,$type-local)),$restriction)"/>
    </xsl:function>

    <xsl:function name="xsdh:local-type-name" as="xs:string">
        <xsl:param name="qname-lexical" as="xs:string?"/>
        <xsl:variable name="raw" as="xs:string" select="normalize-space(string($qname-lexical))"/>
        <!-- Lightweight lexical split only; namespace resolution is context-dependent upstream. -->
        <xsl:sequence select="if (contains($raw,':')) then substring-after($raw,':') else $raw"/>
    </xsl:function>

</xsl:stylesheet>
