
---
name: general-development
description: Repository default for non-XSLT coding tasks (refactors, debugging, performance work, feature implementation, test helper updates, and build/config edits). Trigger whenever the user asks for general code changes and no more specific skill (e.g. xslt-xpath, git, regression-gate, test-suite-development) is a better fit. 
---

1. All support scripts must be written in JavaScript and executable in a Node.js environment.
2. Target NodeJS 22.x: use only stable (non-experimental) APIs available in Node 22. Do not use APIs introduced in later versions or APIs deprecated in Node 22.
3. All npm packages must be checked for vulnerabilities/CVEs before use. No vulnerable packages may be used. If no non-vulnerable package exists for a required feature, notify the user and suggest alternative approaches or manual implementation.
4. When debugging W3C/XForms runtime behavior, use targeted diagnostics before broad reruns:
   - Set `DEBUG_W3C_TEST` to the exact test path (example: `Appendix/B/B.3/b.3.a.xhtml`).
   - Run `npm run test:e2e -- --include-diagnostics tests/diagnostics/w3c-diagnostics.spec.ts --project=chrome`.
   - Use emitted `[DIAG ...]` logs and JSON payload to localize state/action problems.
5. Treat diagnostics runs as investigation tools only; validate final fixes with normal targeted tests and the regression gate workflow.
