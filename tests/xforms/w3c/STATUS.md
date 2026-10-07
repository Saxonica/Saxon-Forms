# W3C XForms 1.1 Test Suite — Coverage Status

Source: <https://www.w3.org/MarkUp/Forms/Test/XForms1.1/Edition1/>

## Engine Gaps

The following categories of W3C test failures reflect known limitations in the Saxon-Forms engine.
These are tracked here to guide future development.

### Recently resolved

The following gaps were resolved and are listed here for reference:

- **Readonly MIP enforcement** — `readonly="true()"` bind now propagates to HTML inputs,
  including inheritance from ancestor bindings. *Resolved: 6.1.2.a, 6.1.2.b, 7.2.f.*
- **`index()` returns NaN** — Non-existent repeat IDs now return NaN per XForms 1.1 §7.7.5.
  *Resolved: 7.7.5.b; 4.7.c test updated.*
- **XPath 3.1 type coercion** — Calculate/relevant expressions wrapped in try/catch to
  handle empty-string arithmetic crashes. *Resolved: 6.1.5.a, 6.1.4.b.*
- **`min()`/`max()` negative tests** — XForms-compliant wrappers return NaN instead of
  throwing XPath 3.1 type errors. *Resolved: 7.7.2.b, 7.7.3.b.*
- **Constraint validation events** — `xforms-valid`/`xforms-invalid` events now dispatch
  after setvalue changes constraint state. *Resolved: 6.1.6.a.*
- **Switch/case selector issues** — Test selectors scoped to `.xforms-switch` to avoid
  matching instruction text. *Resolved: 9.1.1.a2, 9.1.1.b, 9.2.2.b, 9.2.2.c.*
- **Reset action** — Initial instance snapshots saved on construction and restored on
  `xf:reset`. *Resolved: 10.a.*
- **`setfocus` action** — Enhanced `setFocus` JS with suffixed-ID fallback and
  group→first-child focus. *Resolved: 9.1.1.c, 10.7.a.*
- **`current()` in repeat** — Output `@value` starting with `instance(...)` no longer
  short-circuits `$instanceField` inside repeats, so `current()` resolves to the repeat
  item. *Resolved: 7.10.2.b.*
- **`position()`/`last()` in bind calculate** — Calculate expressions containing
  `position()` or `last()` now substitute actual nodeset position/size before evaluation.
  *Resolved: 7.2.e.*
- **`adjust-dateTime-to-timezone()` test** — Test updated with timezone-aware assertions
  instead of hardcoded Pacific time. *Resolved: 7.9.8.a.*
- **Model-construction crash (no instance)** — `evaluate-xpath-with-context-node` parameter
  `$context-node` made optional (`node()?`) so models without instances don't crash the
  transform. *Resolved: 4.2.1.a, 4.2.1.d, 4.2.2.a, 4.2.3.a, 4.5.2.a.*
- **Select/select1 non-incremental sequencing** — Non-incremental `<select>/<select1>`
  onchange handling now performs inline recalculate/revalidate/refresh and avoids
  duplicate outer deferred-cycle dispatch from `xforms-value-changed` wrappers.
  *Resolved: 4.6.3.a, 4.6.3.b, 4.6.3.c.*
- **Action context resolution for bind-based actions** — Action-map persistence now keeps
  bind metadata and insert/delete now resolve local context first with absolute-ref fallback.
  *Resolved: 10.4.b, 10.18.b.*
- **`id()` function routing and implementation** — Added `id` to function rewriting and
  implemented `xforms:id()` overloads (supports `fn:id`, `@xml:id`, and `xsi:type` ID,
  including both W3C xsi namespace URIs). *Resolved: 7.10.3.a, 7.10.3.b, 7.10.3.c.*
- **Chapter 2 submit selector alignment** — Behavioral tests now match fixture submission IDs
  (`submit` for 2.1.a/2.2.a and `submit01` for 2.3.a), clearing temporary selector regressions.
  *Resolved: 2.1.a, 2.2.a, 2.3.a.*
- **Regression gate status** — Latest W3C conformance gate run reports `new_regressions_count: 0`
  and promoted baseline after the above fixes.

### Insert/delete action semantics (13 tests)

Root causes vary across the cluster:
- **Model-level `xforms-ready` handlers** — Insert actions defined as direct children of
  `<xforms:model>` (without `ev:observer`) do not execute reliably. Affects Appendix B tests
  (B.1, B.3, B.4, B.13) which use `<xforms:action ev:event="xforms-ready"><xforms:insert .../>`.
- **Multi-instance `@context` resolution** — Sequential insert actions that switch between
  instances via `@context` (e.g., `context="instance('second')"` then `context="number_list[2]"`)
  resolve against the wrong instance for later actions. Affects: 10.3.a, 10.3.c.
- **`@bind`/`@model` on insert** — Crashes the XSLT transform. Affects: 10.3.b.
- **`@at` position evaluation** — Insert/delete `@at` attribute position calculation produces
  wrong results for some trigger sequences. Affects: 10.3.d, 10.4.d.
- **Delete index tracking** — Post-delete repeat index not updated correctly. Affects: 10.4.e, 10.4.f.
- **Insert `@context` with absent `@nodeset`** — Guard added for empty `$ref-qualified` but
  deeper model event execution issues remain. Affects: 10.3.h, 10.3.j.

### Toggle action scoping in repeats (1 test)

`xf:toggle` inside a repeat iteration toggles ALL iterations' switches instead of just the
current one. The toggle action's `$source-control` scoping mechanism (lines 6018–6024 in
`saxon-xforms.xsl`) exists but `$source-control` is not being passed through the event
dispatch chain (`applyActions` → `action-toggle`) from the clicked button's DOM element.

Affected: 9.3.1.f.

### Toggle case-child precedence (1 test)

The `<xforms:case>` child element of `<xforms:toggle>` (which specifies the target case with
optional `@value` attribute) is not parsed by the toggle action. The action map builder
(line 932–933) stores `case` text content but does not handle `@value` attribute precedence.
The `<xforms:case>` child may also be incorrectly matched by the case rendering template
(line 1545).

Affected: 10.6.1.b.

### Model-event message dispatch (10 tests)

`xforms:message` elements that listen for model-level events (`xforms-rebuild`, `xforms-reset`,
`xforms-recalculate`, `xforms-revalidate`, `xforms-help`, `xforms-hint`) do not produce
modal dialogs when the event fires. The event itself may dispatch correctly, but the
`xforms:message` handler does not invoke `alert()` / modal output.

Affected tests: 10.13.a (reset), 10.8.1.a/b (rebuild), 8.1.8.a (DOMActivate message),
8.2.2.a–c (help), 8.2.3.a–c (hint).

### Submission features (4 tests)

- **`submission/@bind`** — The `bind` attribute on `xforms:submission` is parsed but does not
  filter the submitted instance data to only the bound node. The entire instance is sent.
  Affected: 11.1.b.
- **`xforms-submit-serialize` event** — The `submission-body` property set by an
  `xforms-submit-serialize` handler is not honoured; the original instance data is submitted.
  Affected: 11.3.b.
- **`xforms:header/xforms:name/xforms:value`** — Custom HTTP headers defined via child elements
  of `xforms:submission` are not added to the outgoing request.
  Affected: 11.8.1.a, 11.8.2.a.

### Processing model behavioral failures (3 tests)

- **4.2.2.b** — `xforms-model-construct-done` setvalue handler does not clear instance
  data ("Mitsubishi" persists). Root cause: event handler execution during model
  construction does not update instance values.
- **4.2.2.c1** — Form control referencing instance not yet loaded; output hidden after
  `xforms-ready`. Root cause: lazy instance resolution timing.
- **4.4.1.a** — `xforms-insert` event properties (`inserted-nodes`) not populated in
  event handler after clicking trigger.

### Container control edge cases (1 test)

- **`xf:repeat` startindex** — `startindex` attribute is set in XSLT but output
  `value="index('...')"` evaluates before the repeat template runs (document order issue).
  Affected: 9.3.1.b.


### Miscellaneous (4 tests)

- **Cancelled event propagation** — `dispatch` with `cancelable="true"` + `ev:preventDefault`
  does not prevent the default action. Affected: 10.8.f.
- **Insert with @context precision** — Insert action context attribute does not produce
  expected result in a specific pattern. Affected: 10.3.j.
- **Appendix H.2** — Renders empty. Affected: h.2.
- **`digest()` without crypto** — 7.5.b uses `digest()` in a binding-exception test;
  when crypto bundle is not loaded, the form crashes instead of raising the exception.
