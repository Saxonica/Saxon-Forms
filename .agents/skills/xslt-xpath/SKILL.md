---
name: xslt-xpath
description: Guidance for authoring and reviewing XSLT/XPath changes with modern XSLT 3.0 + XPath 3.1 practices, prioritizing SaxonJS3-compatible features and avoiding deprecated functionality. Trigger for `.xsl`/XSLT templates, XPath expressions, XForms transform logic, or SaxonJS integration edits; do not trigger for pure TypeScript/Playwright changes unless they directly modify XSLT behavior.
---

# XSLT + XPath Modernization (SaxonJS3-first)

## When to use
Use this skill whenever making or reviewing changes in XSLT stylesheets, XPath expressions, or XSLT-driven JavaScript integration points.

## Core requirements
1. Prefer XSLT 3.0+ features over legacy constructs.
2. Prefer XPath 3.1+ expression capabilities and function library behavior.
3. Prefer SaxonJS3-compatible features and idioms.
4. Avoid deprecated functionality unless absolutely required for compatibility.
5. When something can be done equivalently in either XPath or XSLT, prefer the approach used by the existing codebase.

## Authoring rules
1. Use modern, explicit, and readable expression styles (including maps/arrays and function-oriented constructs where appropriate).
2. Prefer robust XSLT 3.0 mechanisms (e.g., structured modes, explicit typing where useful, package-aware organization where relevant) over ad-hoc legacy patterns.
3. Avoid introducing legacy-only compatibility code paths unless a concrete runtime constraint requires them.
4. Do not add deprecated functions or syntax when an equivalent modern feature exists.
5. If an unavoidable compatibility fallback is introduced, add a short comment explaining why modern-only behavior is not possible.
6. When adding XSLT functions or templates, ensure they are documented using the `http://www.oxygenxml.com/ns/doc/xsl` tagset.

## Review checklist
1. Does the change use XSLT 3.0 / XPath 3.1 idioms by default?
2. Is the code compatible with SaxonJS3 behavior?
3. Are any deprecated features introduced? If yes, is there explicit technical justification?
4. Is there a simpler modern replacement that should be used instead?

## Completion criteria
1. New/updated XSLT+XPath logic follows XSLT 3.0 and XPath 3.1-first conventions.
2. SaxonJS3 compatibility is preserved.
3. No unnecessary deprecated functionality remains in the change.

## Resources
1. Use the [Saxonica documentation](https://www.saxonica.com/saxonjs/documentation3/index.html) as needed to understand the use of the `ixsl`, `js` and `saxon` namespaces.