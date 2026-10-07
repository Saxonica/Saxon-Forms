#!/usr/bin/env node
import { spawn } from "node:child_process";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");
const checkpointFilePath = path.join(
  repoRoot,
  "docs",
  "docbook",
  "checkpoints",
  "chapter-checkpoints.json"
);

function parseArgs(argv) {
  const config = {
    listOnly: false,
    runTests: false,
    chapterId: null
  };

  for (const arg of argv) {
    if (arg === "--list") {
      config.listOnly = true;
      continue;
    }
    if (arg === "--run-tests") {
      config.runTests = true;
      continue;
    }
    if (arg.startsWith("--chapter=")) {
      config.chapterId = arg.slice("--chapter=".length).trim();
      continue;
    }
    if (arg === "--help" || arg === "-h") {
      config.help = true;
      continue;
    }
    throw new Error(`Unknown option: ${arg}`);
  }

  return config;
}

function printHelp() {
  console.log(
    [
      "Usage: node scripts/run-docbook-checkpoints.mjs [options]",
      "",
      "Options:",
      "  --list                 List chapter checkpoints only",
      "  --chapter=<id>         Restrict to one chapter id",
      "  --run-tests            Execute targeted test command for selected chapters when present",
      "  --help, -h             Show this help"
    ].join("\n")
  );
}

async function runShellCommand(commandString) {
  const isWindows = process.platform === "win32";
  const command = isWindows ? "cmd.exe" : "sh";
  const args = isWindows ? ["/d", "/s", "/c", commandString] : ["-lc", commandString];

  await new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd: repoRoot,
      stdio: "inherit"
    });

    child.on("error", reject);
    child.on("exit", (code, signal) => {
      if (signal) {
        reject(new Error(`Command terminated with signal ${signal}: ${commandString}`));
        return;
      }
      if ((code ?? 1) !== 0) {
        reject(new Error(`Command failed with exit code ${code}: ${commandString}`));
        return;
      }
      resolve();
    });
  });
}

async function main() {
  const config = parseArgs(process.argv.slice(2));
  if (config.help) {
    printHelp();
    return;
  }

  const raw = await fs.readFile(checkpointFilePath, "utf8");
  const checkpointData = JSON.parse(raw);
  const chapters = (checkpointData.chapters || []).filter((chapter) =>
    config.chapterId ? chapter.id === config.chapterId : true
  );

  if (chapters.length === 0) {
    throw new Error(
      config.chapterId
        ? `No chapter checkpoint found for id "${config.chapterId}".`
        : "No chapter checkpoints available."
    );
  }

  const listing = chapters.map((chapter) => ({
    id: chapter.id,
    title: chapter.title,
    source: chapter.source,
    targeted_test_command: chapter.validation?.targeted_test_command || null,
    full_regression_command: chapter.validation?.full_regression_command || null,
    review_prompts: chapter.review_prompts || []
  }));

  console.log(
    JSON.stringify(
      {
        event: "docbook-checkpoint-list",
        ts: new Date().toISOString(),
        checkpoint_count: listing.length,
        checkpoints: listing
      },
      null,
      2
    )
  );

  if (config.listOnly || !config.runTests) {
    return;
  }

  for (const chapter of chapters) {
    const command = chapter.validation?.targeted_test_command;
    if (!command) {
      console.log(
        JSON.stringify({
          event: "docbook-checkpoint-test-skip",
          chapter_id: chapter.id,
          reason: "No targeted_test_command configured"
        })
      );
      continue;
    }
    console.log(
      JSON.stringify({
        event: "docbook-checkpoint-test-start",
        chapter_id: chapter.id,
        command
      })
    );
    await runShellCommand(command);
    console.log(
      JSON.stringify({
        event: "docbook-checkpoint-test-complete",
        chapter_id: chapter.id
      })
    );
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
