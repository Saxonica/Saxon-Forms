#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { ensureDirectoryAlias, getTestPaths } from "./lib/test-paths.mjs";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");
const testPaths = getTestPaths(repoRoot);
const npmCommand = "npm";
const nodeCommand = process.execPath;

function runCommand(command, args, description) {
  console.log(`[verify:setup:local] ${description}`);
  const result = process.platform === "win32"
    ? spawnSync("cmd.exe", ["/d", "/s", "/c", command, ...args], {
        cwd: repoRoot,
        stdio: "inherit"
      })
    : spawnSync(command, args, {
        cwd: repoRoot,
        stdio: "inherit"
      });
  if (result.error) {
    throw new Error(`${description} failed: ${result.error.message}`);
  }
  if ((result.status ?? 1) !== 0) {
    throw new Error(`${description} failed with exit code ${result.status ?? 1}.`);
  }
}

function ensureW3CSuiteLink() {
  const targetPath = testPaths.fixturesW3CSuiteDir;
  const linkPath = testPaths.runtimeW3CSuiteDir;

  if (!fs.existsSync(targetPath)) {
    throw new Error(
      `Expected W3C suite at ${targetPath}; run "npm run fetch:w3c" before verification.`
    );
  }
  ensureDirectoryAlias(targetPath, linkPath);
}

function main() {
  runCommand(npmCommand, ["run", "fetch:w3c"], "fetching W3C suite assets");
  ensureW3CSuiteLink();
  runCommand(npmCommand, ["run", "build:sef"], "building SEF artifacts");
  const smokeResult = spawnSync(
    nodeCommand,
    [
      "scripts/run-playwright-with-port.mjs",
      "--config=playwright.config.ts",
      "tests/examples/demo-samples-render.spec.ts",
      "--grep",
      "examples fundamentals page renders XForms controls",
      "--workers=1"
    ],
    {
      cwd: repoRoot,
      stdio: "inherit"
    }
  );
  if (smokeResult.error) {
    throw new Error(`running Playwright smoke test failed: ${smokeResult.error.message}`);
  }
  if ((smokeResult.status ?? 1) !== 0) {
    throw new Error(`running Playwright smoke test failed with exit code ${smokeResult.status ?? 1}.`);
  }
  console.log("[verify:setup:local] Verification completed successfully.");
}

try {
  main();
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
}
