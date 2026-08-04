#!/usr/bin/env node
/**
 * Fetch W3C xsdtests archive and extract into tests/fixtures/external/xsdtests/
 *
 * Usage:
 *   node scripts/fetch-nist-xsdtests.mjs           # skips if already present
 *   node scripts/fetch-nist-xsdtests.mjs --force   # re-downloads and replaces
 */

import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { downloadArchive, extractZipArchive, stripExtractedPrefix } from "./lib/archive-utils.mjs";
import { getTestPaths } from "./lib/test-paths.mjs";

const ZIP_URL = "https://github.com/w3c/xsdtests/archive/refs/heads/master.zip";
const STRIP_PREFIX = ["xsdtests-master"];

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const projectRoot = path.resolve(__dirname, "..");
const testPaths = getTestPaths(projectRoot);
const targetDir = testPaths.fixturesXsdtestsDir;
const requiredDatasetPath = path.join(targetDir, "nistMeta", "NISTXMLSchemaDatatypes.testSet");

const force = process.argv.slice(2).includes("--force");

function fail(message) {
  console.error(message);
  process.exit(1);
}

function countXsdFiles(dirPath) {
  if (!fs.existsSync(dirPath)) return 0;

  let count = 0;
  for (const entry of fs.readdirSync(dirPath, { withFileTypes: true })) {
    const fullPath = path.join(dirPath, entry.name);
    if (entry.isDirectory()) {
      count += countXsdFiles(fullPath);
    } else if (entry.isFile() && entry.name.toLowerCase().endsWith(".xsd")) {
      count += 1;
    }
  }
  return count;
}

async function main() {
  if (fs.existsSync(requiredDatasetPath) && !force) {
    console.log(`NIST xsdtests already present in ${targetDir} (use --force to refresh)`);
    return;
  }

  console.log("Downloading W3C xsdtests archive...");
  const tmpZip = path.join(os.tmpdir(), `xsdtests.${process.pid}.${Date.now()}.zip`);

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

    if (!fs.existsSync(requiredDatasetPath)) {
      throw new Error(
        `NIST dataset not found after extraction. Expected ${requiredDatasetPath}.`
      );
    }

    const xsdCount = countXsdFiles(targetDir);
    console.log(`NIST xsdtests extracted successfully (${xsdCount} .xsd files)`);
  } finally {
    fs.rmSync(tmpZip, { force: true });
  }
}

main().catch((error) => fail(error instanceof Error ? error.message : String(error)));
