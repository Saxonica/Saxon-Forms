# Saxon-Forms Developer Setup Guide
This guide documents external dependencies and non-repo assets needed to run Saxon-Forms reliably from a clean clone.

## Recommended onboarding flow
Run these commands in order from repo root:
1. `npm run setup`
2. `npm run doctor`
3. `npm run verify:setup` (Docker-based validation)

## What is managed by the repo
- JavaScript/TypeScript/XSLT source code
- npm dependency manifests (`package.json`, `package-lock.json`)
- Committed Saxon-JS runtime files under `Saxon-JS/`
- Committed SEF artifacts under `sef/` and `tests/runtime/sef/`

## What is intentionally not committed
The following are excluded by `.gitignore` and are expected to be generated, downloaded, or installed locally:
- `node_modules/`
- `tests/fixtures/external/w3c-suite/` and `tests/runtime/w3c-suite`
- `ant4docbook-0.10.0/`
- `apache-ant*/`
- `tests/xsd/nist/.cache/` (generated NIST Playwright case index)
- build and test output directories (`builds/`, `runs/`, `playwright-report/`, `test-results/`)

## Required tools
### 1) Node.js + npm
- Install Node.js and npm.
- Recommended: use Node 22.x to match current repository support scripts.

### 2) Playwright browser binaries
- Install project dependencies first:
  - `npm install`
- Then install Playwright browsers:
  - `npx playwright install`

### 3) `xslt3` CLI availability
`xslt3` is managed as a pinned dev dependency in this repository and is expected to be installed via `npm install` / `npm run setup`.

## Optional/flow-specific tools
### DocBook build toolchain
DocBook commands require:
- Apache Ant available on `PATH` (or passed via `--ant-bin` to `scripts/run-docbook-build.mjs`)
- Local `ant4docbook-0.10.0` distribution unpacked at repo root:
  - `ant4docbook-0.10.0/`

These requirements are intentional and not committed to git.


## Setup commands and profiles
### Primary commands
- `npm run setup`  
  Recommended default bootstrap (`core + conformance`).
- `npm run doctor`  
  Non-destructive preflight checks with fix suggestions.
- `npm run verify:setup`  
  Canonical Docker-based setup validation.
- `npm run build:nist-engine-index`  
  Precompute `tests/xsd/nist/.cache/nist-engine-case-index.json` for `tests/xsd/nist/nist-facets-engine.spec.ts`.

### Setup profiles
- `npm run setup -- --profile core` — dependencies + SEF build
- `npm run setup -- --profile conformance` — Playwright browsers + W3C suite prep + SEF readiness
- `npm run setup -- --profile docs` — DocBook prerequisite checks
- `npm run setup -- --profile nist` — fetch + validate in-repo `xsdtests` dataset

## Non-repo datasets required for some tests
### W3C XForms 1.1 test suite
W3C tests require a downloaded suite:
- `npm run fetch:w3c`

This downloads and extracts the suite into:
- `tests/fixtures/external/w3c-suite/` (ignored in git)
- and links `tests/runtime/w3c-suite` when needed

### NIST XSD dataset
NIST-related manifests reference:
- `tests/fixtures/external/xsdtests/nistMeta/NISTXMLSchemaDatatypes.testSet`

Fetch the dataset with:
- `npm run fetch:nist`
- `npm run fetch:nist -- --force` (refresh existing copy)

This mirrors the W3C asset model by placing downloaded test assets under `tests/fixtures/external/` inside this repository (ignored in git).

NIST Playwright engine tests require a generated case index:
- `npm run build:nist-engine-index`

Override index path for local experiments with:
- `NIST_ENGINE_CASE_INDEX=<path-to-json>`

## Clean-clone bootstrap checklist
1. `npm run setup`
2. `npm run doctor`
3. `npm run verify:setup`
4. Install Ant + `ant4docbook-0.10.0/` and run `npm run setup -- --profile docs` (if running DocBook build commands)
5. Run `npm run fetch:nist`, `npm run setup -- --profile nist`, and `npm run build:nist-engine-index` (if running NIST facet workflows)

## Repository hygiene note
`package-lock.json` currently contains an extraneous local path entry (`../rabet-v-oscal-ui/frontend`).  
If you regenerate lockfiles, ensure lockfile changes only reflect this repository's true dependencies.
