---
name: regression-gate
description: Run compile + targeted + full regression checks for Saxon-Forms-fork against stored baselines. Trigger after a checkpoint commit (clean tree) whenever code/tests/build config change, and whenever user asks to run the gate, verify regressions, or confirm test-count parity. Enforce no W3C regressions and capture commit-linked provenance.
---

# Regression Gate (Saxon-Forms-fork)

## When to use
Use this skill after any code change in `src/`, `test-app/xforms/`, `tests/`, `examples/`, or build/test config files.

## Goal
Prevent regressions. The gate enforces two groups of requirements:

### Verification steps
1. Successful stylesheet compilation.
2. Targeted verification for changed behavior.
3. Full suite verification against stored baseline snapshots (no baseline re-discovery runs).

### Integrity requirements
4. Mandatory no-regression verification for `mandatory_suite_ids` (see `suites.json`).
5. Commit-linked run provenance (head SHA, branch, tree state, and run directory).

## Key files
- Suite registry (source of truth for test organization):
  - `.agents/skills/regression-gate/playwright/suites.json`
- Baseline snapshots (one per suite):
  - `.agents/skills/regression-gate/baselines/<suite-id>.json`
- Gate runner script (full workflow: compile + targeted + full queue + baseline comparison):
  - `.agents/skills/regression-gate/scripts/run_regression_gate.mjs` (`npm run test:gate`)
- Baseline evaluator script:
  - `.agents/skills/regression-gate/scripts/evaluate_playwright_baseline.mjs`
- Baseline generation script (repeatable initialization/refresh workflow):
  - `scripts/create-playwright-baseline.mjs` (`npm run test:baseline`)
- Run artifacts (timestamped):
  - `.agents/skills/regression-gate/runs/<suite-id>/<timestamp>/`
  - Must contain at least:
    - `playwright-report.json`
    - `comparison.json`
- Required per-run provenance sidecar:
  - `.agents/skills/regression-gate/runs/<suite-id>/<timestamp>/vcs-context.json`
- Run provenance ledger (append-only):
  - `.agents/skills/regression-gate/runs/run-index.ndjson`
  - One JSON record per suite run, including `suite_id`, `run_dir`, `policy_result`, `git_head_sha`, `git_branch`, `git_tree_state`, and `related_commit_sha`
- W3C Playwright coverage lives in:
  - `tests/xforms/w3c/ch02.spec.ts` ... `tests/xforms/w3c/ch11.spec.ts`
  - `tests/xforms/w3c/appendix.spec.ts`

Do not infer baseline from ad-hoc reruns. Always compare to the stored baseline file for the selected suite.
## VCS provenance capture (mandatory)
The gate runs after a checkpoint commit (see git skill), so the tree should always be clean and HEAD should point to the checkpoint.
Before running the gate, capture:
- `git --no-pager rev-parse --verify HEAD` (head SHA — this is the checkpoint commit),
- `git --no-pager rev-parse --abbrev-ref HEAD` (branch),
- `git --no-pager status --porcelain` (tree state — expected empty/clean),
- `git --no-pager diff --name-only` (changed files — expected none).
Set `related_commit_sha` to the HEAD SHA. It must never be `null` under this workflow.
If the tree is unexpectedly dirty, do not run the gate. Defer to the git skill to resolve the tree state before proceeding.
## Main commands
- Run default gate (uses `default_suite_id`, then appends mandatory suites):
  - `node .agents/skills/regression-gate/scripts/run_regression_gate.mjs`
- Run gate with explicit primary suite:
  - `node .agents/skills/regression-gate/scripts/run_regression_gate.mjs --suite <suite-id>`
- Add targeted verification for changed behavior (`Playwright -g` regex on primary suite):
  - `node .agents/skills/regression-gate/scripts/run_regression_gate.mjs --suite <suite-id> --grep "<regex>"`
- Skip targeted run even when a grep is supplied:
  - `node .agents/skills/regression-gate/scripts/run_regression_gate.mjs --suite <suite-id> --grep "<regex>" --skip-targeted`

## Gate runner exit codes
- `0`: pass (no new regressions)
- `2`: mandatory-suite regression detected (hard fail)
- `3`: non-mandatory regression detected (waiver justification required)
- `4`: missing baseline(s), initialize first

## Baseline bootstrap commands
Use the repeatable baseline script for initialization/refresh instead of manual baseline JSON edits:
- default suite baseline:
  - `npm run test:baseline`
- specific suite baseline:
  - `npm run test:baseline -- --suite <suite-id>`
- mandatory suites from registry:
  - `npm run test:baseline -- --mandatory`
- all suites:
  - `npm run test:baseline -- --all`

## W3C-suite integrity policy (mandatory)
1. **Never modify W3C Working Group test documents.**
   - Files under the official `w3c-suite` corpus (`public-test/w3c-suite/**`, also exposed via `test-app/w3c-suite`) are immutable.
   - Under no circumstance should these `.xhtml` test documents be edited, rewritten, normalized, or reformatted.
2. **Playwright tests may be modified only when they mismatch W3C pass criteria.**
   - A Playwright assertion may be changed only if it does **not** correctly reflect the pass criteria in the corresponding `w3c-suite` `.xhtml`.
   - When changing Playwright tests, first read the corresponding `.xhtml`, identify the exact pass condition, and align assertions to that condition (not stricter, not looser).
   - If no mismatch is demonstrable from the `.xhtml`, do not change the Playwright test.

## Regression policy tiers
1. **Mandatory no-regression suites** (`regression_policy: mandatory-no-regressions`)
   - Includes all W3C suites and every suite ID listed in `mandatory_suite_ids` in `.agents/skills/regression-gate/playwright/suites.json`.
   - Any new regression is a hard failure and cannot be waived.
2. **Waivable suites** (`regression_policy: waivable-with-justification`)
   - Regressions are still undesirable and should be fixed first.
   - A regression may proceed only when explicitly justified in run artifacts and user-visible reporting.
## Required workflow
1. **Verify clean tree after checkpoint**
   - Confirm tree is clean (`git status --porcelain` is empty). The gate assumes a checkpoint commit has already been made (see git skill).
   - Record HEAD SHA (the checkpoint commit), branch, and tree state (see "VCS provenance capture").
2. **Run gate**
   - Use the gate runner script from this skill (see "Main commands").
3. **Persist run provenance**
   - For each suite run directory produced by the gate, write `vcs-context.json` with the captured Git metadata and `related_commit_sha` (always the checkpoint SHA).
   - Append one record per suite run to `.agents/skills/regression-gate/runs/run-index.ndjson`.
4. **Interpret policy result**
   - Hard fail (`exit 2`): mandatory-suite regression. Report failing tests; defer to git skill for rollback.
   - Soft fail (`exit 3`): non-mandatory regression. Report failing tests with justification requirement; defer to git skill for rollback or finalize decision.
6. **Baseline promotion rule**
   - Baseline may be promoted automatically by the comparison script only when:
     - there are **zero new regressions**, and
     - current run is better than stored baseline (more passes and/or fewer failures/flaky).
   - Runs that rely on non-W3C waivers must not be treated as successful baseline-promotion candidates.
7. **Uninitialized suites**
   - If a suite baseline file does not exist, initialize it only after user approval using:
     - `npm run test:baseline -- --suite <suite-id>`
   - For broad refreshes, use:
     - `npm run test:baseline -- --mandatory`
     - `npm run test:baseline -- --all`
## Regression-to-commit triage
When a regression is detected, identify likely cause commits using provenance records:
1. Find the latest passing ledger entry for the same suite (`policy_result: pass` and no new regressions).
2. Compare its `related_commit_sha` to the failing run’s `related_commit_sha`.
3. Build the suspect range:
   - `git --no-pager log --oneline <last-passing-sha>..<failing-sha>`
4. Report this range alongside failing tests.

## Reporting format
Always report:
- primary suite ID used,
- full suite queue executed,
- per-suite run directory and run timestamp,
- Git head SHA, branch, and tree state for the run,
- related commit SHA (always the checkpoint commit SHA),
- per-suite policy (`mandatory-no-regressions` or `waivable-with-justification`),
- baseline file path used per suite,
- compile status,
- targeted test status (or skipped),
- full suite pass/fail counts per suite,
- failing test names per suite,
- whether failures are only baseline or include new regressions,
- whether baseline was promoted,
- suspect commit range for each new regression (when determinable),
- whether any non-W3C regression waiver was used (and justification path).

## Baseline maintenance rule
Do not manually edit baseline snapshots during normal runs. Use `npm run test:baseline` for baseline initialization/refresh, and let the evaluator script promote baseline only under the defined improvement rule. Do not treat waived-regression runs as baseline-promotion candidates.

## Portability rule
- Keep all skill documentation and suite registry paths repo-relative.
- Do not embed machine-specific path fragments (usernames or host-specific mount points).
- Scripts must derive repository root dynamically and work across Windows/WSL/Linux/macOS.
