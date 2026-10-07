Saxon-Forms
=========

Saxon-Forms is an XForms implementation written using Interactive XSLT 3.0. 
Interactive XSLT 3.0 is a feature of Saxon-JS, which is an XSLT 3.0 run-time written in pure JavaScript for use in the browser or a platform that supports JavaScript.

See conference papers below:

[Implementing XForms using interactive XSLT 3.0](http://www.saxonica.com/papers/xmlprague-2018ond.pdf). XML Prague 2018.

[Distributing XSLT Processing between Client and Server](http://xmllondon.com/2017/xmllondon-2017-proceedings.pdf). XML London 2017.
## Quickstart (5 minutes)
For first-time contributor onboarding, run:
```bash
npm run setup
npm run doctor
npm run verify:setup
```

### Prerequisites
- Node.js + npm
- Saxon-JS 3 runtime assets available in `Saxon-JS/` (or copied to your hosting location)

Saxon-JS can be downloaded at [Saxon-JS](http://www.saxonica.com/saxon-js/index.xml) (older versions available at the [archive](https://www.saxonica.com/saxon-js/archive.xml)).

### 1) Bootstrap environment
```bash
npm run setup
```

### 2) Build Saxon-Forms SEF
```bash
npm run build:sef
```

This generates `sef/saxon-xforms.sef.json` and syncs it into `tests/runtime/sef/saxon-xforms.sef.json`.

### 3) Run examples locally
```bash
npm run examples
```

Then open `http://127.0.0.1:5174/` and start with:
- `examples/hello.html`
- `examples/native-xforms-fiddle.html`
- `examples/sample1.html` (direct XForms-source loading)
- `examples/sample2.html` (restored legacy sample page)
- `examples/sample3.html` (restored legacy sample page)

`npm run examples` starts a local server and continues running until you stop it manually.

### 4) Run end-to-end tests (Playwright)
```bash
npm run test:e2e
```
Run with a specific browser mode:
```bash
npm run test:e2e:chrome
npm run test:e2e:firefox
npm run test:e2e:both
```
Or pass the harness flag directly:
```bash
npm run test:e2e -- --browser=firefox
```

To run tests interactively:
```bash
npm run test:e2e:ui
```

### Common commands
- Build SEF: `npm run build:sef`
- Run all examples: `npm run examples`
- Compile stylesheet-driven examples on demand: `npm run examples:compile`
- Fetch W3C suite: `npm run fetch:w3c`
- Fetch NIST xsdtests dataset: `npm run fetch:nist`
- Build precomputed NIST Playwright case index: `npm run build:nist-engine-index`
- Run e2e in Chrome only: `npm run test:e2e:chrome`
- Run e2e in Firefox only: `npm run test:e2e:firefox`
- Run e2e in both browsers: `npm run test:e2e:both`
- Run full e2e flow (prepare + build + test): `npm run test:e2e:full`
- Run xsd helper tests: `npm run test:xsd-helpers`
- Run NIST facet harness with Saxon-Forms engine: `npm run test:nist-facets`
- Run NIST facet inventory by datatype families: `npm run test:nist-facets:inventory`
- Run diagnostics tests: `npm run test:e2e:diagnostics`

### NIST Playwright engine index
`tests/xsd/nist/nist-facets-engine.spec.ts` reads precomputed case data from:
- `tests/xsd/nist/.cache/nist-engine-case-index.json`

Generate/update this file with:
```bash
npm run build:nist-engine-index
```

Use a custom index path for experimentation by setting `NIST_ENGINE_CASE_INDEX` to an absolute or repo-relative JSON path.

### Troubleshooting
- If W3C tests are missing assets, run `npm run fetch:w3c`.
- If NIST workflows are missing assets, run `npm run fetch:nist`.
- If `tests/xsd/nist/nist-facets-engine.spec.ts` reports missing index data, run `npm run build:nist-engine-index`.
- If runtime output looks stale, rerun `npm run build:sef`.
- If docs builds fail, ensure `ant` is on PATH (or use `--ant-bin` with `scripts/run-docbook-build.mjs`).

## Contributing
See `CONTRIBUTING.md` for development workflow, validation expectations, and PR standards.
For complete machine/bootstrap setup (including external datasets and tools), see `SETUP.md`.

## Support expectations
Saxon-Forms support maturity is tracked by conformance behavior and implementation coverage.

- Supported and stable: core controls, many processing model actions, and major portions of chapter-based W3C tests.
- Partial support: areas with known behavioral gaps or edge-case limitations.
- In progress: features tracked as active gaps in conformance status.

For current details:
- `tests/xforms/w3c/STATUS.md` for live gap and resolution tracking
- `docs/docbook/` for implementation architecture and behavior mapping

If you are evaluating feature readiness for production, use those files as the source of truth.

## Documentation workflow (DocBook + ant4docbook)

The repository now includes a DocBook-based implementation guide under `docs/docbook/`, with chapter-level checkpoints and standalone UML/BPMN references.

Prerequisite for DocBook builds:
- Install Apache Ant and ensure `ant` is available on PATH (or provide a custom path via `--ant-bin` in `scripts/run-docbook-build.mjs`).

- Validate DocBook sources, XInclude targets, and checkpoint metadata:
  - `npm run docs:docbook:validate`
- Build DocBook HTML + PDF using the local `ant4docbook-0.10.0` distribution:
  - `npm run docs:docbook:build`
- Build only one output format:
  - `npm run docs:docbook:build -- --format=html`
  - `npm run docs:docbook:build -- --format=pdf`
- List checkpoint definitions and targeted chapter test commands:
  - `npm run docs:docbook:checkpoints`

Generated DocBook outputs are written to `builds/docs-docbook/`.

## GitHub Pages documentation site (CI/CD)

The repository supports an assembled static docs site artifact under `builds/site/`.
This includes:
- Curated markdown docs (allowlisted)
- DocBook implementation guide HTML output
- Published `examples/` pages and required runtime assets

Build and validate locally:
- `npm run site:build`
- `npm run site:validate`

The CI workflow `.github/workflows/pages-docs.yml` builds and validates this artifact on pull requests, and deploys to GitHub Pages on pushes to the default branch.

Note on examples in static hosting:
- Most examples render normally on Pages.
- Endpoint-backed submission demos (paths such as `/api/test`, `/api/echo`, `/api/book-submit`) require the local examples server for full behavior (`npm run examples`).

## Cryptographic Functions (Optional)

The XForms `digest()` and `hmac()` functions require the
[@noble/hashes](https://github.com/paulmillr/noble-hashes) library (MIT license). 
These functions are **optional** — forms that do not
use `digest()` or `hmac()` work without it. When the library is not loaded,
these functions return an empty string instead of crashing.

### Quick setup

1. Install the dependency:

   ```bash
   npm install @noble/hashes
   ```

2. Build the crypto bundle:

   ```bash
   node scripts/build-crypto.mjs
   ```

   This produces `builds/saxon-forms-crypto.js` (~14 KB, 6 KB gzipped).

3. Load the bundle **before** Saxon-Forms in your HTML:

   ```html
   <script src="saxon-forms-crypto.js"></script>
   <!-- then load SaxonJS and your XForm as usual -->
   ```

### CDN alternative

If you prefer not to install locally, you can load the pre-built bundle from
your own CDN or copy `builds/saxon-forms-crypto.js` alongside your other assets.

### What happens without it

If the crypto bundle is not loaded, `digest()` and `hmac()` return empty strings.
Forms that use these functions will render normally but any conditional logic
that depends on hash values (e.g. `ref="self::node()[digest(...) = '...']"`)
will not match.

## Technical Details


