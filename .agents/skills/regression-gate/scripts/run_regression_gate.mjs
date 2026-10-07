#!/usr/bin/env node
import fs from "fs";
import os from "os";
import path from "path";
import { spawnSync } from "child_process";
import { fileURLToPath } from "url";
import { ensureDirectoryAlias, getTestPaths } from "../../../../scripts/lib/test-paths.mjs";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const skillRoot = path.resolve(__dirname, "..");
const repoRoot = path.resolve(skillRoot, "../../..");
const testPaths = getTestPaths(repoRoot);

const suitesPath = path.join(skillRoot, "playwright", "suites.json");
const evaluatorPath = path.join(skillRoot, "scripts", "evaluate_playwright_baseline.mjs");
const fetchW3CPath = path.join(repoRoot, "scripts", "fetch-w3c-suite.mjs");
const playwrightLauncherPath = path.join(repoRoot, "scripts", "run-playwright-with-port.mjs");
const sefPath = path.join(repoRoot, "sef", "saxon-xforms.sef.json");
const testAppSefPath = testPaths.runtimeSefFile;
const runsRoot = path.join(skillRoot, "runs");

const playwrightTimeoutMs = Number(process.env.REGRESSION_GATE_PLAYWRIGHT_TIMEOUT_MS || 1200000);

function usage() {
  console.log(
    [
      "Usage:",
      "  node .agents/skills/regression-gate/scripts/run_regression_gate.mjs [options]",
      "",
      "Options:",
      "  --suite <suite-id>     Primary suite ID (defaults to default_suite_id in suites.json)",
      "  --grep <regex>         Optional Playwright -g regex for targeted run on primary suite",
      "  --skip-targeted        Skip targeted run even if --grep is provided",
      "  --help                 Show this help",
      "",
      "Environment variables:",
      "  REGRESSION_GATE_PLAYWRIGHT_TIMEOUT_MS   Timeout per Playwright run (default: 1200000)"
    ].join("\n")
  );
}

function parseArgs(argv) {
  let suiteId = null;
  let grepPattern = null;
  let skipTargeted = false;

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--suite") {
      suiteId = argv[i + 1];
      if (!suiteId) throw new Error("Missing value for --suite <suite-id>");
      i++;
      continue;
    }
    if (arg === "--grep") {
      grepPattern = argv[i + 1];
      if (!grepPattern) throw new Error("Missing value for --grep <regex>");
      i++;
      continue;
    }
    if (arg === "--skip-targeted") {
      skipTargeted = true;
      continue;
    }
    if (arg === "--help" || arg === "-h") {
      usage();
      process.exit(0);
    }
    throw new Error(`Unknown argument: ${arg}`);
  }

  return { suiteId, grepPattern, skipTargeted };
}
function resolveSpawnCommand(command, args) {
  // TEST-TRACE: use cmd.exe to launch npx on Windows where plain "npx" can fail with ENOENT.
  if (process.platform === "win32" && command === "npx") {
    return {
      command: "cmd.exe",
      args: ["/d", "/s", "/c", "npx", ...args]
    };
  }
  return { command, args };
}

function run(command, args, options = {}) {
  const {
    cwd = repoRoot,
    allowFailure = false,
    stdio = "inherit",
    timeoutMs = 0
  } = options;
  const spawnCommand = resolveSpawnCommand(command, args);
  const result = spawnSync(spawnCommand.command, spawnCommand.args, {
    cwd,
    stdio,
    encoding: "utf8",
    timeout: timeoutMs > 0 ? timeoutMs : undefined
  });
  if (result.error) {
    throw new Error(`Failed to run ${command}: ${result.error.message}`);
  }
  if (!allowFailure && result.status !== 0) {
    throw new Error(`Command failed (${result.status}): ${command} ${args.join(" ")}`);
  }
  return result;
}

function timestampUtcCompact() {
  return new Date().toISOString().replace(/[-:]/g, "").replace(/\.\d{3}Z$/, "Z");
}
function logEvent(event, payload = {}) {
  console.log(JSON.stringify({ ts: new Date().toISOString(), event, ...payload }));
}

function resolveSuitePath(value) {
  if (!value) return value;
  return path.isAbsolute(value) ? value : path.resolve(repoRoot, value);
}

function toRepoRelative(displayPath) {
  const rel = path.relative(repoRoot, displayPath);
  if (!rel.startsWith("..") && !path.isAbsolute(rel)) {
    return rel.split(path.sep).join("/");
  }
  return displayPath;
}

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function loadSuiteRegistry() {
  if (!fs.existsSync(suitesPath)) {
    throw new Error(`Suite registry not found: ${toRepoRelative(suitesPath)}`);
  }
  const raw = readJson(suitesPath);
  const suites = raw?.suites || {};
  const normalizedSuites = {};
  for (const [suiteId, suiteConfig] of Object.entries(suites)) {
    normalizedSuites[suiteId] = {
      ...suiteConfig,
      config_path: resolveSuitePath(suiteConfig.config_path),
      test_path: resolveSuitePath(suiteConfig.test_path),
      baseline_path: resolveSuitePath(suiteConfig.baseline_path)
    };
  }
  return {
    default_suite_id: raw.default_suite_id,
    mandatory_suite_ids: Array.isArray(raw.mandatory_suite_ids) ? raw.mandatory_suite_ids : [],
    suites: normalizedSuites
  };
}

function getPathType(targetPath) {
  if (!targetPath || !fs.existsSync(targetPath)) return null;
  const stat = fs.statSync(targetPath);
  if (stat.isFile()) return "file";
  if (stat.isDirectory()) return "directory";
  return "other";
}

function validateSuitePaths(queue) {
  const problems = [];
  for (const suite of queue) {
    const configPathType = getPathType(suite.config_path);
    if (configPathType !== "file") {
      problems.push(
        `Suite '${suite.id}' config_path must be an existing file: ${toRepoRelative(suite.config_path)}`
      );
    }

    const testPathType = getPathType(suite.test_path);
    if (!testPathType || (testPathType !== "file" && testPathType !== "directory")) {
      problems.push(
        `Suite '${suite.id}' test_path must be an existing file or directory: ${toRepoRelative(suite.test_path)}`
      );
    }
  }
  if (problems.length > 0) {
    throw new Error(`Suite path preflight failed:\n- ${problems.join("\n- ")}`);
  }
}

function getTotalExecutedTests(stats = {}) {
  return (
    (stats.expected || 0) +
    (stats.unexpected || 0) +
    (stats.flaky || 0) +
    (stats.skipped || 0)
  );
}

function runPlaywrightToJsonReport({ suite, workers, runDir }) {
  const reportPath = path.join(runDir, "playwright-report.json");
  const configPathArg = toRepoRelative(suite.config_path);
  const testPathArg = toRepoRelative(suite.test_path);
  const startedAt = Date.now();
  logEvent("suite-start", {
    suite_id: suite.id,
    workers,
    config_path: configPathArg,
    test_path: testPathArg,
    report_path: toRepoRelative(reportPath)
  });
  const result = spawnSync(
    "node",
    [
      playwrightLauncherPath,
      "--workers",
      String(workers),
      "--config",
      configPathArg,
      testPathArg,
      "--reporter=dot,json"
    ],
    {
      cwd: repoRoot,
      stdio: "inherit",
      encoding: "utf8",
      timeout: playwrightTimeoutMs,
      env: {
        ...process.env,
        PLAYWRIGHT_JSON_OUTPUT_FILE: reportPath,
        PLAYWRIGHT_JSON_OUTPUT_DIR: path.dirname(reportPath),
        PLAYWRIGHT_JSON_OUTPUT_NAME: path.basename(reportPath)
      }
    }
  );
  const playwrightDurationSeconds = Number(((Date.now() - startedAt) / 1000).toFixed(2));

  if (result.error) {
    if (result.error.code === "ETIMEDOUT") {
      throw new Error(
        `Playwright timed out for suite ${suite.id} after ${playwrightTimeoutMs}ms. ` +
          "Increase REGRESSION_GATE_PLAYWRIGHT_TIMEOUT_MS if needed."
      );
    }
    throw new Error(`Playwright failed for suite ${suite.id}: ${result.error.message}`);
  }
  if (!fs.existsSync(reportPath) || fs.statSync(reportPath).size === 0) {
    throw new Error(`No Playwright JSON report produced for suite ${suite.id}.`);
  }
  const report = readJson(reportPath);
  const totalExecuted = getTotalExecutedTests(report?.stats || {});
  if (totalExecuted === 0) {
    throw new Error(
      `Suite '${suite.id}' executed zero tests for ${testPathArg}. Check suite test_path and discovery configuration.`
    );
  }
  return { result, reportPath, playwrightDurationSeconds, totalExecuted };
}

function ensureW3CDataIfNeeded(queueIds) {
  const needsW3CData = queueIds.some((suiteId) => suiteId.startsWith("w3c-"));
  if (!needsW3CData) return;

  run("node", [fetchW3CPath]);
  const linkPath = testPaths.runtimeW3CSuiteDir;
  const targetPath = testPaths.fixturesW3CSuiteDir;

  if (!fs.existsSync(targetPath)) {
    throw new Error(`W3C source directory missing: ${toRepoRelative(targetPath)}`);
  }
  ensureDirectoryAlias(targetPath, linkPath);
}

function compileEngine() {
  const compileResult = run(
    "npx",
    [
      "xslt3",
      "-t",
      `-xsl:${path.join(repoRoot, "src", "saxon-xforms.xsl")}`,
      `-export:${sefPath}`,
      "-nogo",
      "-ns:##html5"
    ],
    { allowFailure: true }
  );
  if (compileResult.status !== 0 && !fs.existsSync(sefPath)) {
    throw new Error(
      "Stylesheet compilation failed and no existing SEF is available at " +
        `${toRepoRelative(sefPath)}`
    );
  }
  fs.copyFileSync(sefPath, testAppSefPath);
  return compileResult.status === 0 ? "ok" : "failed-used-existing-sef";
}

function getChangedFiles() {
  const result = run("git", ["--no-pager", "diff", "--name-only"], {
    allowFailure: true,
    stdio: "pipe"
  });
  if (result.status !== 0) return [];
  return String(result.stdout || "")
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const suiteRegistry = loadSuiteRegistry();
  const suiteMap = suiteRegistry.suites;
  const allSuiteIds = Object.keys(suiteMap);
  if (allSuiteIds.length === 0) {
    throw new Error(`No suites found in ${toRepoRelative(suitesPath)}`);
  }

  const primarySuiteId = args.suiteId || suiteRegistry.default_suite_id || allSuiteIds[0];
  if (!suiteMap[primarySuiteId]) {
    throw new Error(`Unknown suite ID: ${primarySuiteId}`);
  }

  const queueIds = [primarySuiteId];
  for (const mandatoryId of suiteRegistry.mandatory_suite_ids) {
    if (!suiteMap[mandatoryId]) {
      throw new Error(`mandatory_suite_ids contains unknown suite: ${mandatoryId}`);
    }
    if (!queueIds.includes(mandatoryId)) {
      queueIds.push(mandatoryId);
    }
  }

  const queue = queueIds.map((suiteId) => ({ id: suiteId, ...suiteMap[suiteId] }));
  validateSuitePaths(queue);

  const missingBaselines = queue
    .filter((suite) => !fs.existsSync(suite.baseline_path))
    .map((suite) => ({
      suite_id: suite.id,
      baseline_path: toRepoRelative(suite.baseline_path),
      init_command: `npm run test:baseline -- --suite ${suite.id}`
    }));
  if (missingBaselines.length > 0) {
    console.log(
      JSON.stringify(
        {
          status: "uninitialized-baseline",
          missing_baselines: missingBaselines,
          suggestion: "Initialize missing baselines, then rerun gate."
        },
        null,
        2
      )
    );
    process.exit(4);
  }

  const workers = Math.max(1, Math.floor((os.cpus()?.length || 1) * 0.75));
  const changedFiles = getChangedFiles();

  ensureW3CDataIfNeeded(queueIds);
  const compileStatus = compileEngine();

  let targetedSummary = {
    status: "skipped",
    reason: args.grepPattern ? "skip-targeted requested" : "no --grep provided",
    exit_code: null,
    duration_seconds: null
  };

  if (args.grepPattern && !args.skipTargeted) {
    const primarySuite = queue.find((suite) => suite.id === primarySuiteId);
    const configPathArg = toRepoRelative(primarySuite.config_path);
    const testPathArg = toRepoRelative(primarySuite.test_path);
    const targetedStartedAt = Date.now();
    logEvent("targeted-start", {
      suite_id: primarySuite.id,
      workers,
      grep: args.grepPattern
    });
    const targetedResult = run(
      "node",
      [
        playwrightLauncherPath,
        "--workers",
        String(workers),
        "--config",
        configPathArg,
        testPathArg,
        "-g",
        args.grepPattern
      ],
      { allowFailure: true, timeoutMs: playwrightTimeoutMs }
    );
    const targetedDurationSeconds = Number(((Date.now() - targetedStartedAt) / 1000).toFixed(2));
    targetedSummary = {
      status: targetedResult.status === 0 ? "ok" : "failed",
      reason: null,
      exit_code: targetedResult.status,
      duration_seconds: targetedDurationSeconds
    };
    logEvent("targeted-end", {
      suite_id: primarySuite.id,
      workers,
      grep: args.grepPattern,
      status: targetedSummary.status,
      exit_code: targetedSummary.exit_code,
      duration_seconds: targetedSummary.duration_seconds
    });
  }

  let hardFail = false;
  let softFail = false;
  const suiteResults = [];

  for (const suite of queue) {
    const suiteStartedAt = Date.now();
    const runDir = path.join(runsRoot, suite.id, timestampUtcCompact());
    fs.mkdirSync(runDir, { recursive: true });
    const { result: playwrightResult, reportPath, playwrightDurationSeconds } = runPlaywrightToJsonReport({
      suite,
      workers,
      runDir
    });

    const comparisonPath = path.join(runDir, "comparison.json");
    const compareResult = run(
      "node",
      [
        evaluatorPath,
        "--report",
        reportPath,
        "--baseline",
        suite.baseline_path,
        "--out",
        comparisonPath,
        "--promote-if-better"
      ],
      { allowFailure: true, stdio: "pipe" }
    );

    let comparisonSummary = null;
    if (fs.existsSync(comparisonPath)) {
      comparisonSummary = readJson(comparisonPath);
    }

    if (compareResult.status !== 0) {
      if (suite.regression_policy === "mandatory-no-regressions") {
        hardFail = true;
      } else {
        softFail = true;
        fs.writeFileSync(
          path.join(runDir, "justification-required.txt"),
          [
            "Required justification for waiver:",
            "1) Why this regression is acceptable now",
            "2) Blast radius / impacted behaviors",
            "3) Mitigation in place",
            "4) Rollback plan"
          ].join("\n") + "\n"
        );
      }
    }
    const currentStats = comparisonSummary?.current_stats ?? null;
    logEvent("suite-end", {
      suite_id: suite.id,
      workers,
      policy: suite.regression_policy,
      run_dir: toRepoRelative(runDir),
      duration_seconds: Number(((Date.now() - suiteStartedAt) / 1000).toFixed(2)),
      playwright_duration_seconds: playwrightDurationSeconds,
      passed: currentStats?.passed ?? null,
      failed: currentStats?.failed ?? null,
      flaky: currentStats?.flaky ?? null,
      skipped: currentStats?.skipped ?? null,
      no_regressions: comparisonSummary?.no_regressions ?? null,
      baseline_promoted: comparisonSummary?.baseline_promoted ?? false,
      new_regressions_count: (comparisonSummary?.new_regressions || []).length
    });

    suiteResults.push({
      suite_id: suite.id,
      policy: suite.regression_policy,
      config_path: toRepoRelative(suite.config_path),
      test_path: toRepoRelative(suite.test_path),
      baseline_path: toRepoRelative(suite.baseline_path),
      run_dir: toRepoRelative(runDir),
      playwright_exit_code: playwrightResult.status,
      comparison_exit_code: compareResult.status,
      baseline_promoted: comparisonSummary?.baseline_promoted ?? false,
      no_regressions: comparisonSummary?.no_regressions ?? null,
      current_stats: currentStats,
      new_regressions: comparisonSummary?.new_regressions ?? []
    });
  }

  const summary = {
    created_at: new Date().toISOString(),
    primary_suite_id: primarySuiteId,
    suite_queue: queueIds,
    workers,
    changed_files: changedFiles,
    compile_status: compileStatus,
    targeted: targetedSummary,
    suites: suiteResults,
    policy_result: hardFail ? "hard-fail" : softFail ? "soft-fail" : "pass"
  };

  console.log(JSON.stringify(summary));

  if (hardFail) process.exit(2);
  if (softFail) process.exit(3);
  process.exit(0);
}

try {
  main();
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
}
