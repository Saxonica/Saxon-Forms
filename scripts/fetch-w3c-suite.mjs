#!/usr/bin/env node
/**
 * Fetch the W3C XForms 1.1 Test Suite and extract into tests/fixtures/external/w3c-suite/
 *
 * Usage:
 *   node scripts/fetch-w3c-suite.mjs           # skips if already present
 *   node scripts/fetch-w3c-suite.mjs --force   # re-downloads and replaces
 */

import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { downloadArchive, extractZipArchive, stripExtractedPrefix } from "./lib/archive-utils.mjs";
import { ensureDirectoryAlias, getTestPaths } from "./lib/test-paths.mjs";

const ZIP_URL = "https://www.w3.org/MarkUp/Forms/Test/XForms1.1/Edition1/zip/TestCases11.zip";
const STRIP_PREFIX = ["Test", "XForms1.1", "Edition1"];

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const projectRoot = path.resolve(__dirname, "..");
const testPaths = getTestPaths(projectRoot);
const targetDir = testPaths.fixturesW3CSuiteDir;

const force = process.argv.slice(2).includes("--force");

function fail(message) {
  console.error(message);
  process.exit(1);
}

function countXhtmlFiles(dirPath) {
  if (!fs.existsSync(dirPath)) return 0;

  let count = 0;
  for (const entry of fs.readdirSync(dirPath, { withFileTypes: true })) {
    const fullPath = path.join(dirPath, entry.name);
    if (entry.isDirectory()) {
      count += countXhtmlFiles(fullPath);
    } else if (entry.isFile() && entry.name.toLowerCase().endsWith(".xhtml")) {
      count += 1;
    }
  }
  return count;
}


async function main() {
  if (fs.existsSync(path.join(targetDir, "Chapt02")) && !force) {
    console.log(`W3C test suite already present in ${targetDir} (use --force to refresh)`);
    return;
  }

  console.log("Downloading W3C XForms 1.1 Test Suite...");
  const tmpZip = path.join(os.tmpdir(), `TestCases11.${process.pid}.${Date.now()}.zip`);

  try {
    await downloadArchive(ZIP_URL, tmpZip);

    if (fs.existsSync(targetDir)) {
      console.log(`Cleaning existing ${targetDir}...`);
      fs.rmSync(targetDir, { recursive: true, force: true });
    }
    fs.mkdirSync(targetDir, { recursive: true });

    console.log(`Extracting to ${targetDir}...`);
    extractZipArchive(tmpZip, targetDir);
    stripExtractedPrefix(targetDir, STRIP_PREFIX);
    ensureDirectoryAlias(testPaths.fixturesW3CSuiteDir, testPaths.runtimeW3CSuiteDir);

    const xhtmlCount = countXhtmlFiles(targetDir);
    console.log(`W3C test suite extracted successfully (${xhtmlCount} xhtml files)`);
  } finally {
    fs.rmSync(tmpZip, { force: true });
  }
}

main().catch((error) => fail(error instanceof Error ? error.message : String(error)));
