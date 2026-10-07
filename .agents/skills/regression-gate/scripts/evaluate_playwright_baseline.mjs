/**
 * evaluate_playwright_baseline.mjs
 *
 * Compares a Playwright JSON report to a baseline JSON file, detects regressions, and optionally promotes the baseline if results improve.
 *
 * CLI Arguments:
 *   --report <playwright-json>      Path to the Playwright JSON report file (required)
 *   --baseline <baseline-json>      Path to the baseline JSON file (required)
 *   --out <output-json>             Path to write the summary output (optional)
 *   --promote-if-better             If present, updates the baseline file if results improve (optional)
 *   --force-promote                 If present, always updates the baseline file, even if regressions are detected (optional)
 *
 * Example usage:
 *   node evaluate_playwright_baseline.mjs \
 *     --report playwright-report/data/report.json \
 *     --baseline playwright-report/data/baseline.json \
 *     --out playwright-report/data/summary.json \
 *     --promote-if-better
 *
 *   # To force baseline promotion (e.g. after making tests more strict):
 *   node evaluate_playwright_baseline.mjs \
 *     --report playwright-report/data/report.json \
 *     --baseline playwright-report/data/baseline.json \
 *     --out playwright-report/data/summary.json \
 *     --force-promote
 *
 * Exit codes:
 *   0 - No regressions detected
 *   2 - Regressions detected
 *   1 - Error (missing arguments, file not found, etc.)
 */
import fs from "fs";

function argValue(flag) {
  const idx = process.argv.indexOf(flag);
  if (idx === -1 || idx + 1 >= process.argv.length) return null;
  return process.argv[idx + 1];
}

function hasFlag(flag) {
  return process.argv.includes(flag);
}

function die(message, code = 1) {
  console.error(message);
  process.exit(code);
}

const reportPath = argValue("--report");
const baselinePath = argValue("--baseline");
const outputPath = argValue("--out");
const promoteIfBetter = hasFlag("--promote-if-better");
const forcePromote = hasFlag("--force-promote");

if (!reportPath) die("Missing required argument: --report <playwright-json>");
if (!baselinePath) die("Missing required argument: --baseline <baseline-json>");

if (!fs.existsSync(reportPath)) die(`Playwright report not found: ${reportPath}`);
if (!fs.existsSync(baselinePath)) die(`Baseline file not found: ${baselinePath}`);

const report = JSON.parse(fs.readFileSync(reportPath, "utf8"));
const baseline = JSON.parse(fs.readFileSync(baselinePath, "utf8"));

function collectSpecs(suites, parentTitles = []) {
  const collected = [];
  for (const suite of suites || []) {
    const title = suite?.title || "";
    const nextParents = title && !title.endsWith(".spec.ts")
      ? [...parentTitles, title]
      : parentTitles;

    for (const spec of suite?.specs || []) {
      const specTitle = spec?.title || "(unnamed test)";
      const displayTitle = nextParents.length
        ? `${nextParents.join(" › ")} › ${specTitle}`
        : specTitle;
      const statuses = (spec?.tests || [])
        .map((t) => t?.status)
        .filter(Boolean);
      const failedFromStatus = statuses.some((s) =>
        ["unexpected", "flaky", "timedOut", "interrupted"].includes(s)
      );
      const failed = failedFromStatus || spec?.ok === false;
      collected.push({ title: displayTitle, failed });
    }

    collected.push(...collectSpecs(suite?.suites || [], nextParents));
  }
  return collected;
}

const specs = collectSpecs(report?.suites || []);
const currentFailures = [...new Set(specs.filter((s) => s.failed).map((s) => s.title))].sort();

const stats = report?.stats || {};
const currentStats = {
  total:
    (stats.expected || 0) +
    (stats.unexpected || 0) +
    (stats.flaky || 0) +
    (stats.skipped || 0),
  passed: stats.expected || 0,
  failed: stats.unexpected || 0,
  flaky: stats.flaky || 0,
  skipped: stats.skipped || 0
};

const baselineFailures = new Set((baseline?.allowed_failures || []).map(String));
const newRegressions = currentFailures.filter((name) => !baselineFailures.has(name));
const resolvedFailures = [...baselineFailures].filter((name) => !currentFailures.includes(name));

const baselineStats = baseline?.stats || {};
const baselinePassed = Number.isFinite(baselineStats?.passed) ? baselineStats.passed : -1;
const baselineFailed = Number.isFinite(baselineStats?.failed) ? baselineStats.failed : Number.MAX_SAFE_INTEGER;
const baselineFlaky = Number.isFinite(baselineStats?.flaky) ? baselineStats.flaky : Number.MAX_SAFE_INTEGER;

const noRegressions = newRegressions.length === 0;
const improved =
  noRegressions &&
  (
    currentStats.passed > baselinePassed ||
    currentStats.failed < baselineFailed ||
    currentStats.flaky < baselineFlaky
  );

const summary = {
  suite_id: baseline?.suite_id || null,
  baseline_path: baselinePath,
  report_path: reportPath,
  current_stats: currentStats,
  baseline_stats: baselineStats,
  current_failures: currentFailures,
  new_regressions: newRegressions,
  resolved_failures: resolvedFailures,
  no_regressions: noRegressions,
  improved_vs_baseline: improved,
  baseline_promoted: false
};


if (forcePromote || (promoteIfBetter && improved)) {
  const promoted = {
    ...baseline,
    last_updated: new Date().toISOString(),
    stats: currentStats,
    allowed_failures: currentFailures
  };
  fs.writeFileSync(baselinePath, JSON.stringify(promoted, null, 2) + "\n");
  summary.baseline_promoted = true;
  summary.force_promote = !!forcePromote;
}

if (outputPath) {
  fs.writeFileSync(outputPath, JSON.stringify(summary, null, 2) + "\n");
}

console.log(JSON.stringify(summary, null, 2));
process.exit(noRegressions ? 0 : 2);
