# Contributing to Saxon-Forms
Thanks for contributing to Saxon-Forms. This document defines the expected local workflow, quality checks, and pull request standards.
For full machine/bootstrap setup (including non-repo datasets and external tooling), see `SETUP.md`.

## Scope
This repository contains:
- Saxon-Forms XSLT implementation in `src/`
- Browser-facing bridges and helpers
- W3C conformance tests in `tests/xforms/w3c/`
- Interactive examples in `examples/`
- Implementation docs in `docs/docbook/` 

## Prerequisites
- Node.js + npm
- Saxon-JS assets available for local runs
- Apache Ant (only required for DocBook build workflows)

## Local setup
1. Bootstrap environment:
   ```bash
   npm run setup
   ```
2. Run preflight checks:
   ```bash
   npm run doctor
   ```
3. Validate setup via Docker:
   ```bash
   npm run verify:setup
   ```

## Development workflow
- Create a focused branch for each change.
- Keep behavior changes and refactors separate unless tightly coupled.
- Add or update tests for any behavior change.
- If conformance status changes, update `tests/xforms/w3c/STATUS.md`.
- Keep documentation aligned with implementation changes.

## Required local checks before opening a PR
Run the following before submitting:

```bash
npm run build:nist-engine-index
npm run build:sef
npm run test:e2e:full
npm run test:xsd-helpers
npm run docs:docbook:validate
```

`npm run build:nist-engine-index` generates `tests/xsd/nist/.cache/nist-engine-case-index.json`, which is required by `tests/xsd/nist/nist-facets-engine.spec.ts`.

If your change affects documentation, also run:

```bash
npm run docs:docbook:build
npm run site:build
npm run site:validate
```

## Working with W3C tests
- Specs are grouped by chapter in `tests/xforms/w3c/chXX.spec.ts`.
- Shared helpers and fixtures live in `tests/xforms/w3c/helpers.ts`, `tests/helpers.ts`, and `tests/fixtures/`.
- Known gaps and resolved regressions are tracked in `tests/xforms/w3c/STATUS.md`.

## Working with NIST XSD tests
- NIST engine coverage spec: `tests/xsd/nist/nist-facets-engine.spec.ts`
- Build/update precomputed case index before running this spec:
  - `npm run build:nist-engine-index`
- Default index output:
  - `tests/xsd/nist/.cache/nist-engine-case-index.json`
- Optional override for local experiments:
  - `NIST_ENGINE_CASE_INDEX=<path-to-json>`

## Architecture map (where to start)
Use this map to find implementation ownership quickly:

- Main transformation/runtime orchestration: `src/saxon-xforms.xsl`
- XPath/XForms function implementations: `src/xforms-function-library.xsl`, `src/xforms-xpath-functions.xsl`
- JavaScript bridge behavior and browser-side support: `src/xforms-javascript-library.xsl`
- Schema/type helper logic: `src/xsd-helpers.xsl`
- End-to-end conformance tests by chapter: `tests/xforms/w3c/chXX.spec.ts`
- Shared Playwright fixtures/helpers: `tests/xforms/w3c/helpers.ts`, `tests/fixtures/`

When fixing a conformance gap:
1. Reproduce with a specific chapter/test ID.
2. Add or adjust tests as needed.
3. Implement the fix.
4. Verify pass/fail delta locally.
5. Update `tests/xforms/w3c/STATUS.md` when gap status changes.

## Coding guidelines
- Prefer minimal, localized changes.
- Preserve existing project style in XSL/TS files.
- Use descriptive names and keep control-flow explicit.
- Add comments where logic is subtle (especially XPath/XForms semantics).
- Avoid broad formatting-only churn in functional PRs.

## Documentation expectations
Update docs whenever behavior changes:
- User-facing workflows: `README.md`
- Implementation details: `docs/docbook/`
- Conformance gap status: `tests/xforms/w3c/STATUS.md`
- Published docs/examples site assembly: `npm run site:build` output in `builds/site/`

## Pull request expectations
A pull request should clearly describe:
- What changed
- Why it changed
- How it was validated (commands and key outcomes)
- Conformance impact (if applicable)
- Known limitations (if any remain)

To keep PRs reviewable:
- Keep scope cohesive and limited.
- Avoid unrelated file churn.
- Include enough context for a reviewer to reproduce results.

## Reporting issues
When reporting a bug, include:
- Reproduction steps
- Expected behavior
- Actual behavior
- Minimal sample input (XForm/XPath) when possible
- Relevant W3C chapter/test ID when applicable
- Any logs or screenshots needed for diagnosis
