#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

function parseArgs(argv) {
  const args = {
    sourceManifest: "tests/xsd/nist/nist-simpletype-facets.manifest.json",
    engine: "saxonforms",
    jobs: 1,
    maxFamilies: 0,
    onlyFamilies: [],
    outDir: "tests/xsd/nist/.shards",
    reportJson: "tests/xsd/nist/.shards/inventory-report.json",
  };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--source-manifest") args.sourceManifest = argv[++i];
    else if (arg === "--engine") args.engine = argv[++i];
    else if (arg === "--jobs") args.jobs = Number(argv[++i] || "1");
    else if (arg === "--max-families") args.maxFamilies = Number(argv[++i] || "0");
    else if (arg === "--family") args.onlyFamilies.push(argv[++i]);
    else if (arg === "--out-dir") args.outDir = argv[++i];
    else if (arg === "--report-json") args.reportJson = argv[++i];
    else if (arg === "--help" || arg === "-h") {
      printHelp();
      process.exit(0);
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }
  return args;
}

function printHelp() {
  console.log(`Usage: node scripts/run-nist-facet-inventory.mjs [options]
Options:
  --source-manifest <path>  Source manifest path (default: tests/xsd/nist/nist-simpletype-facets.manifest.json)
  --engine <name>           Harness engine (default: saxonforms)
  --jobs <n>                Harness jobs value (default: 1)
  --max-families <n>        Limit number of family shards to run
  --family <name>           Run only specific family (repeatable)
  --out-dir <path>          Output directory for generated shard manifests
  --report-json <path>      JSON file path for inventory report`);
}

function getRepoRoot() {
  const scriptDir = path.dirname(fileURLToPath(import.meta.url));
  return path.resolve(scriptDir, "..");
}

function readManifest(manifestPath) {
  return JSON.parse(fs.readFileSync(manifestPath, "utf8"));
}
function normalizeSourceTestSetForRepo(sourceTestSet) {
  const sourceValue = String(sourceTestSet || "").trim().replaceAll("\\", "/");
  const legacyPrefix = "../xsdtests/";
  if (sourceValue.startsWith(legacyPrefix)) {
    return `tests/fixtures/external/xsdtests/${sourceValue.slice(legacyPrefix.length)}`;
  }
  return sourceValue;
}

function dedupeGroups(manifest) {
  const rows = [];
  for (const facetName of Object.keys(manifest.facets ?? {})) {
    const facet = manifest.facets[facetName] ?? {};
    for (const group of facet.valid_groups ?? []) rows.push(group);
    for (const group of facet.invalid_groups ?? []) rows.push(group);
  }
  return [...new Set(rows)];
}

function getFamily(groupName) {
  if (groupName.startsWith("atomic-")) {
    const rest = groupName.slice("atomic-".length);
    const type = rest.split("-")[0];
    return `atomic-${type}`;
  }
  const parts = groupName.split("-");
  if (parts.length >= 2) return `${parts[0]}-${parts[1]}`;
  return parts[0];
}

function buildFamilyMap(groups) {
  const out = new Map();
  for (const group of groups) {
    const family = getFamily(group);
    if (!out.has(family)) out.set(family, []);
    out.get(family).push(group);
  }
  return out;
}

function writeShardManifest(outDir, family, sourceTestSet, groups) {
  const safeName = family.replace(/[^A-Za-z0-9._-]/g, "_");
  const file = path.join(outDir, `manifest-${safeName}.json`);
  const payload = {
    source_test_set: sourceTestSet,
    facets: {
      [`family_${safeName}`]: {
        valid_groups: groups,
        invalid_groups: [],
      },
    },
  };
  fs.writeFileSync(file, JSON.stringify(payload, null, 2));
  return file;
}

function runShard(repoRoot, args, manifestPath) {
  const cmd = [
    "node",
    "scripts/run-nist-facet-harness.mjs",
    "--engine",
    args.engine,
    "--manifest",
    manifestPath,
    "--jobs",
    String(args.jobs),
  ];
  const proc = spawnSync(cmd[0], cmd.slice(1), {
    cwd: repoRoot,
    encoding: "utf8",
    shell: process.platform === "win32",
  });
  const text = `${proc.stdout ?? ""}${proc.stderr ?? ""}`;
  const summaryLine = text.split(/\r?\n/).find((line) => line.startsWith("[summary]")) ?? "[summary] missing";
  const failLines = text
    .split(/\r?\n/)
    .filter((line) => line.startsWith("[fail]"));
  const failedCountMatch = summaryLine.match(/\bfailed=(\d+)/);
  const failedCount = failedCountMatch ? Number(failedCountMatch[1]) : NaN;
  return {
    exitCode: proc.status ?? 1,
    summaryLine,
    failLines,
    failedCount,
  };
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const repoRoot = getRepoRoot();
  const sourceManifestPath = path.resolve(repoRoot, args.sourceManifest);
  const outDir = path.resolve(repoRoot, args.outDir);
  const reportJsonPath = path.resolve(repoRoot, args.reportJson);
  fs.mkdirSync(outDir, { recursive: true });

  const sourceManifest = readManifest(sourceManifestPath);
  const shardSourceTestSet = normalizeSourceTestSetForRepo(sourceManifest.source_test_set);
  const groups = dedupeGroups(sourceManifest);
  const families = buildFamilyMap(groups);
  let familyNames = [...families.keys()].sort((a, b) => a.localeCompare(b));
  if (args.onlyFamilies.length) {
    const wanted = new Set(args.onlyFamilies);
    familyNames = familyNames.filter((name) => wanted.has(name));
  }
  if (args.maxFamilies > 0) {
    familyNames = familyNames.slice(0, args.maxFamilies);
  }

  console.log(`families_selected=${familyNames.length}`);
  const failingFamilies = [];
  for (let i = 0; i < familyNames.length; i++) {
    const family = familyNames[i];
    const shardManifest = writeShardManifest(outDir, family, shardSourceTestSet, families.get(family));
    const result = runShard(repoRoot, args, shardManifest);
    console.log(`[family ${i + 1}/${familyNames.length}] ${family} ${result.summaryLine}`);
    if ((Number.isFinite(result.failedCount) && result.failedCount > 0) || result.exitCode !== 0) {
      failingFamilies.push({
        family,
        summary: result.summaryLine,
        fail_samples: result.failLines.slice(0, 8),
      });
      for (const line of result.failLines.slice(0, 8)) console.log(`  ${line}`);
    }
  }

  console.log(`[inventory-summary] total_families=${familyNames.length} failing_families=${failingFamilies.length}`);
  for (const item of failingFamilies) {
    console.log(`[inventory-fail] family=${item.family} ${item.summary}`);
  }
  fs.writeFileSync(reportJsonPath, JSON.stringify({
    source_manifest: sourceManifestPath,
    total_families: familyNames.length,
    failing_families: failingFamilies,
  }, null, 2));
  console.log(`[inventory-report] ${reportJsonPath}`);
  process.exit(0);
}

try {
  main();
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(2);
}
