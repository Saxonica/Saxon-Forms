---
name: test-suite-development
description: Development discipline for passing tests with the smallest defensible change set. Trigger when user asks to fix failing tests, make CI/test-suite green, resolve regressions, or adjust code specifically to satisfy assertions. Do not use for broad feature work unless test-fix behavior is the primary objective.
---

# Test-Suite-Development (Minimal, Justifiable Changes)

## Purpose
Implement only the minimum code required to satisfy failing tests, with changes that can be clearly justified to external reviewers.

## Core principle
This repository's changes must remain conservative and easy to defend. Avoid major codebase changes unless no smaller alternative can resolve the failing test.

## Non-negotiable rules (in priority order)

### 1. Scope the change
1. Make the smallest localized change that resolves the failing test behavior.
2. Do not modify files that are not directly involved in the failing behavior.
3. If a larger change appears necessary, stop and document why no smaller option can resolve the failure before proceeding.

### 2. Avoid unrelated modifications
4. Do not perform broad refactors, architectural rewrites, style-only sweeps, large renames, or unrelated cleanups while pursuing test fixes.

### 3. Document every change
5. For every functional code change, add an adjacent short comment that explains:
   - what changed and why,
   - which specific test(s) this change helps pass.

### 4. Link to provenance
6. Every regression-gate run must include VCS provenance linked to a checkpoint commit (see regression-gate skill for provenance requirements).

## Required test-trace comment convention
Use a short `TEST-TRACE` comment immediately next to each changed block, using the file’s native comment syntax.

Examples:
- `// TEST-TRACE: restrict repeat toggle scope; helps tests/supplemental/issues.spec.ts "Issue #30"`
- `/* TEST-TRACE: preserve insert context fallback; helps tests/xforms/w3c/ch09.spec.ts "9.3.a" */`
- `<!-- TEST-TRACE: adjust relevance refresh ordering; helps tests/xforms/w3c/ch02.spec.ts "2.3.a" -->`

Keep comments concise and factual (one short line whenever possible).

## Workflow
1. Identify failing tests and the smallest likely fix surface.
2. Implement narrowly scoped code changes.
3. Add `TEST-TRACE` comments adjacent to each change.
4. Checkpoint and gate: stage, checkpoint commit, then run the regression gate (see git skill for checkpoint workflow, regression-gate skill for gate execution).
   - If the agent did not make the changes, confirm staging scope with the user before checkpointing.
5. If the gate fails, handle per git skill (rollback) and regression-gate skill (policy interpretation). Continue fixing until mandatory suites pass.
6. If non-mandatory regressions remain, document explicit justification before considering progress complete.

## Done criteria
1. Target failures are resolved.
2. No mandatory-suite regressions are introduced.
3. Every functional change has a nearby `TEST-TRACE` comment that names the relevant test(s).
4. Every regression-gate run is linked to a checkpoint commit SHA (provenance is never stale).
