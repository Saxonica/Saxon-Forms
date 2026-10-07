#!/usr/bin/env node
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");

function parseArgs(argv) {
  const config = { keepImage: false };
  for (const arg of argv) {
    if (arg === "--keep-image") {
      config.keepImage = true;
      continue;
    }
    if (arg === "--help" || arg === "-h") {
      config.help = true;
      continue;
    }
    throw new Error(`Unknown argument: ${arg}`);
  }
  return config;
}

function printHelp() {
  console.log(
    [
      "Usage: node scripts/verify-setup-docker.mjs [options]",
      "",
      "Options:",
      "  --keep-image   Keep the temporary verification image after completion",
      "  --help, -h     Show this help"
    ].join("\n")
  );
}

function commandExists(commandName) {
  const locator = process.platform === "win32" ? "where" : "which";
  const result = spawnSync(locator, [commandName], {
    cwd: repoRoot,
    stdio: "ignore"
  });
  return (result.status ?? 1) === 0;
}

function runDocker(args, description, options = {}) {
  const { allowFailure = false } = options;
  console.log(`[verify:setup:docker] ${description}`);
  const result = spawnSync("docker", args, {
    cwd: repoRoot,
    stdio: "inherit"
  });
  if (result.error) {
    throw new Error(`${description} failed: ${result.error.message}`);
  }
  if ((result.status ?? 1) !== 0 && !allowFailure) {
    throw new Error(`${description} failed with exit code ${result.status ?? 1}.`);
  }
}

function main() {
  const config = parseArgs(process.argv.slice(2));
  if (config.help) {
    printHelp();
    return;
  }

  if (!commandExists("docker")) {
    throw new Error("docker command is not available. Install Docker and ensure it is on PATH.");
  }

  const imageTag = `saxon-forms-setup-verify-${Date.now()}`;

  try {
    runDocker(
      ["build", "--tag", imageTag, "--file", "Dockerfile", "."],
      "building verification image"
    );
    runDocker(
      ["run", "--rm", imageTag, "npm", "run", "verify:setup:local"],
      "running in-container setup verification"
    );
    console.log("[verify:setup:docker] Verification completed successfully.");
  } finally {
    if (!config.keepImage) {
      runDocker(
        ["image", "rm", imageTag],
        "removing temporary verification image",
        { allowFailure: true }
      );
    }
  }
}

try {
  main();
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
}
