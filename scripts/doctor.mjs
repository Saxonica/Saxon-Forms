#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { getTestPaths } from "./lib/test-paths.mjs";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");
const testPaths = getTestPaths(repoRoot);

function commandExists(commandName) {
  const locator = process.platform === "win32" ? "where" : "which";
  const result = spawnSync(locator, [commandName], {
    cwd: repoRoot,
    stdio: "ignore"
  });
  return (result.status ?? 1) === 0;
}

function packageExists(packageName) {
  return fs.existsSync(path.join(repoRoot, "node_modules", ...packageName.split("/"), "package.json"));
}

function addCheck(results, status, name, details, fix) {
  results.push({ status, name, details, fix });
}

function printCheck(result) {
  const statusLabel = result.status === "pass"
    ? "PASS"
    : result.status === "warn"
      ? "WARN"
      : "FAIL";
  console.log(`[${statusLabel}] ${result.name}`);
  if (result.details) {
    console.log(`       ${result.details}`);
  }
  if (result.fix) {
    console.log(`       Fix: ${result.fix}`);
  }
}

async function checkPlaywrightBrowser(results) {
  if (!packageExists("playwright")) {
    addCheck(
      results,
      "fail",
      "Playwright runtime package",
      "playwright package is not installed in node_modules.",
      "Run `npm install`."
    );
    return;
  }

  try {
    const playwright = await import("playwright");
    const executablePath = playwright.chromium.executablePath();
    if (executablePath && fs.existsSync(executablePath)) {
      addCheck(
        results,
        "pass",
        "Playwright Chromium browser",
        `Chromium executable found at ${executablePath}.`
      );
      return;
    }
    addCheck(
      results,
      "fail",
      "Playwright Chromium browser",
      "Chromium executable is missing.",
      "Run `npx playwright install`."
    );
  } catch (error) {
    addCheck(
      results,
      "fail",
      "Playwright Chromium browser",
      `Failed to resolve Playwright browser: ${error instanceof Error ? error.message : String(error)}`,
      "Run `npm install` then `npx playwright install`."
    );
  }
}

async function main() {
  const results = [];
  const [majorNodeVersion] = process.versions.node.split(".").map((part) => Number(part));

  if (majorNodeVersion >= 22) {
    addCheck(results, "pass", "Node.js version", `Detected Node ${process.versions.node}.`);
  } else {
    addCheck(
      results,
      "warn",
      "Node.js version",
      `Detected Node ${process.versions.node}; Node 22.x is recommended for this repository.`,
      "Install Node.js 22.x for best compatibility."
    );
  }

  if (commandExists("npm")) {
    addCheck(results, "pass", "npm CLI", "npm command is available.");
  } else {
    addCheck(results, "fail", "npm CLI", "npm command is unavailable.", "Install Node.js/npm.");
  }

  if (commandExists("docker")) {
    addCheck(results, "pass", "Docker CLI", "docker command is available.");
  } else {
    addCheck(
      results,
      "warn",
      "Docker CLI",
      "docker command is unavailable (required for Docker-based setup verification).",
      "Install Docker Desktop/Engine and ensure `docker` is on PATH."
    );
  }

  if (fs.existsSync(path.join(repoRoot, "node_modules"))) {
    addCheck(results, "pass", "Installed dependencies", "node_modules directory is present.");
  } else {
    addCheck(
      results,
      "fail",
      "Installed dependencies",
      "node_modules directory is missing.",
      "Run `npm install`."
    );
  }

  if (packageExists("xslt3")) {
    addCheck(results, "pass", "xslt3 dependency", "xslt3 package is installed.");
  } else {
    addCheck(
      results,
      "fail",
      "xslt3 dependency",
      "xslt3 package is missing.",
      "Run `npm install`."
    );
  }

  if (packageExists("@playwright/test")) {
    addCheck(results, "pass", "@playwright/test dependency", "@playwright/test package is installed.");
  } else {
    addCheck(
      results,
      "fail",
      "@playwright/test dependency",
      "@playwright/test package is missing.",
      "Run `npm install`."
    );
  }

  await checkPlaywrightBrowser(results);

  const w3cSuiteRoot = path.join(testPaths.fixturesW3CSuiteDir, "Chapt02");
  if (fs.existsSync(w3cSuiteRoot)) {
    addCheck(results, "pass", "W3C suite assets", "tests/fixtures/external/w3c-suite is present.");
  } else {
    addCheck(
      results,
      "fail",
      "W3C suite assets",
      "tests/fixtures/external/w3c-suite is missing.",
      "Run `npm run fetch:w3c`."
    );
  }

  const w3cSuiteLink = testPaths.runtimeW3CSuiteDir;
  if (fs.existsSync(w3cSuiteLink)) {
    addCheck(results, "pass", "W3C suite runtime link", "tests/runtime/w3c-suite exists.");
  } else {
    addCheck(
      results,
      "fail",
      "W3C suite runtime link",
      "tests/runtime/w3c-suite is missing.",
      "Run `npm run setup -- --profile conformance` (or `npm run predev`)."
    );
  }

  const ant4docbookJar = path.join(repoRoot, "ant4docbook-0.10.0", "ant4docbook-0.10.0.jar");
  if (commandExists("ant")) {
    addCheck(results, "pass", "Apache Ant (DocBook)", "ant command is available.");
  } else {
    addCheck(
      results,
      "warn",
      "Apache Ant (DocBook)",
      "ant command is missing.",
      "Install Apache Ant and ensure `ant` is on PATH if you need DocBook builds."
    );
  }

  if (fs.existsSync(ant4docbookJar)) {
    addCheck(results, "pass", "ant4docbook distribution", "ant4docbook jar is present.");
  } else {
    addCheck(
      results,
      "warn",
      "ant4docbook distribution",
      "ant4docbook-0.10.0 is missing from repository root.",
      "Add ant4docbook-0.10.0/ at repo root if you need DocBook builds."
    );
  }

  const nistDatasetPath = path.resolve(
    testPaths.fixturesXsdtestsDir,
    "nistMeta",
    "NISTXMLSchemaDatatypes.testSet"
  );
  if (fs.existsSync(nistDatasetPath)) {
    addCheck(results, "pass", "NIST xsdtests dataset", `Found dataset at ${nistDatasetPath}.`);
  } else {
    addCheck(
      results,
      "warn",
      "NIST xsdtests dataset",
      `Dataset missing at ${nistDatasetPath}.`,
      "Run `npm run fetch:nist` to provision NIST assets."
    );
  }

  for (const result of results) {
    printCheck(result);
  }

  const passCount = results.filter((result) => result.status === "pass").length;
  const warnCount = results.filter((result) => result.status === "warn").length;
  const failCount = results.filter((result) => result.status === "fail").length;

  console.log(
    `[doctor] Summary: ${passCount} passed, ${warnCount} warnings, ${failCount} failures.`
  );

  if (failCount > 0) {
    process.exit(1);
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
