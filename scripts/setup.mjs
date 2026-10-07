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
const npxCommand = "npx";

const profileOrder = ["core", "conformance", "docs", "nist"];
const validProfiles = new Set([...profileOrder, "recommended"]);

function parseArgs(argv) {
  const profiles = [];
  let showHelp = false;

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--help" || arg === "-h") {
      showHelp = true;
      continue;
    }
    if (arg === "--profile") {
      const value = argv[index + 1];
      if (!value || value.startsWith("-")) {
        throw new Error("Missing value for --profile");
      }
      index += 1;
      profiles.push(value);
      continue;
    }
    if (arg.startsWith("--profile=")) {
      const value = arg.slice("--profile=".length).trim();
      if (!value) {
        throw new Error("Missing value for --profile");
      }
      profiles.push(value);
      continue;
    }
    throw new Error(`Unknown argument: ${arg}`);
  }

  return { profiles, showHelp };
}

function printHelp() {
  console.log(
    [
      "Usage: node scripts/setup.mjs [--profile <name>]...",
      "",
      "Profiles:",
      "  recommended   Equivalent to core + conformance (default)",
      "  core          Install dependencies and build SEF",
      "  conformance   Install Playwright browsers, fetch W3C suite, ensure W3C link",
      "  docs          Validate DocBook tooling prerequisites",
      "  nist          Fetch and validate in-repo xsdtests dataset availability",
      "",
      "Examples:",
      "  npm run setup",
      "  npm run setup -- --profile docs",
      "  npm run setup -- --profile core --profile conformance"
    ].join("\n")
  );
}

function expandProfiles(inputProfiles) {
  const requested = inputProfiles.length > 0 ? inputProfiles : ["recommended"];
  const expanded = [];

  for (const requestedProfile of requested) {
    const profile = requestedProfile.trim().toLowerCase();
    if (!validProfiles.has(profile)) {
      throw new Error(
        `Unsupported profile "${requestedProfile}". Valid options: ${[...validProfiles].join(", ")}`
      );
    }
    if (profile === "recommended") {
      expanded.push("core", "conformance");
      continue;
    }
    expanded.push(profile);
  }

  const deduped = [];
  for (const profile of profileOrder) {
    if (expanded.includes(profile)) {
      deduped.push(profile);
    }
  }
  return deduped;
}

function runCommand(command, args, description, options = {}) {
  const { allowFailure = false } = options;
  console.log(`[setup] ${description}`);
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
  if ((result.status ?? 1) !== 0 && !allowFailure) {
    throw new Error(`${description} failed with exit code ${result.status ?? 1}.`);
  }
  return result;
}

function runNpm(args, description) {
  return runCommand(npmCommand, args, description);
}

function runNpx(args, description) {
  return runCommand(npxCommand, args, description);
}

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

function ensureDependenciesInstalled() {
  const nodeModulesPath = path.join(repoRoot, "node_modules");
  const requiredPackages = ["@playwright/test", "xslt3"];
  const missingPackages = requiredPackages.filter((packageName) => !packageExists(packageName));

  if (!fs.existsSync(nodeModulesPath) || missingPackages.length > 0) {
    const reason = missingPackages.length > 0
      ? `installing dependencies (missing: ${missingPackages.join(", ")})`
      : "installing dependencies";
    runNpm(["install"], reason);
    return;
  }

  console.log("[setup] Dependencies already installed; skipping npm install.");
}

function ensureW3CSuiteLink() {
  const targetPath = testPaths.fixturesW3CSuiteDir;
  const linkPath = testPaths.runtimeW3CSuiteDir;

  if (!fs.existsSync(targetPath)) {
    throw new Error(
      `W3C suite not found at ${targetPath}. Run "npm run fetch:w3c" and retry.`
    );
  }
  ensureDirectoryAlias(targetPath, linkPath);
  console.log("[setup] W3C suite runtime alias present at tests/runtime/w3c-suite.");
}

function verifyDocsPrerequisites({ strict }) {
  const issues = [];
  const ant4docbookJarPath = path.join(repoRoot, "ant4docbook-0.10.0", "ant4docbook-0.10.0.jar");

  if (!commandExists("ant")) {
    issues.push("Apache Ant not found on PATH.");
  }
  if (!fs.existsSync(ant4docbookJarPath)) {
    issues.push("ant4docbook distribution missing at ant4docbook-0.10.0/.");
  }

  if (issues.length === 0) {
    console.log("[setup] DocBook prerequisites look good.");
    return;
  }

  if (strict) {
    throw new Error(
      `DocBook prerequisites are incomplete:\n- ${issues.join("\n- ")}\nFix: install Ant and add ant4docbook-0.10.0 at repo root.`
    );
  }

  console.warn(`[setup] DocBook prerequisites not ready:\n- ${issues.join("\n- ")}`);
}

function verifyNistPrerequisites({ strict }) {
  const datasetPath = path.resolve(
    repoRoot,
    "tests",
    "fixtures",
    "external",
    "xsdtests",
    "nistMeta",
    "NISTXMLSchemaDatatypes.testSet"
  );
  if (fs.existsSync(datasetPath)) {
    console.log("[setup] NIST dataset detected.");
    return;
  }

  const message = [
    "NIST dataset missing.",
    `Expected: ${datasetPath}`,
    "Fix: run `npm run fetch:nist`."
  ].join("\n");

  if (strict) {
    throw new Error(message);
  }
  console.warn(`[setup] ${message}`);
}

async function main() {
  const { profiles, showHelp } = parseArgs(process.argv.slice(2));
  if (showHelp) {
    printHelp();
    return;
  }

  const selectedProfiles = expandProfiles(profiles);
  console.log(`[setup] Selected profiles: ${selectedProfiles.join(", ")}`);

  for (const profile of selectedProfiles) {
    if (profile === "core") {
      ensureDependenciesInstalled();
      runNpm(["run", "build:sef"], "building SEF artifacts");
      continue;
    }
    if (profile === "conformance") {
      ensureDependenciesInstalled();
      runNpx(["playwright", "install"], "installing Playwright browsers");
      runNpm(["run", "fetch:w3c"], "fetching W3C suite");
      ensureW3CSuiteLink();
      if (!selectedProfiles.includes("core")) {
        runNpm(["run", "build:sef"], "building SEF artifacts (required for conformance)");
      }
      continue;
    }
    if (profile === "docs") {
      verifyDocsPrerequisites({ strict: true });
      continue;
    }
    if (profile === "nist") {
      runNpm(["run", "fetch:nist"], "fetching NIST xsdtests dataset");
      verifyNistPrerequisites({ strict: true });
    }
  }

  if (profiles.length === 0 || profiles.map((value) => value.toLowerCase()).includes("recommended")) {
    verifyDocsPrerequisites({ strict: false });
    verifyNistPrerequisites({ strict: false });
  }

  console.log("[setup] Setup completed successfully.");
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
