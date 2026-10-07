#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import os from "node:os";
import { spawn } from "node:child_process";
import { getTestPaths } from "./lib/test-paths.mjs";

function parseArgs(argv) {
  const args = {
    manifest: "tests/xsd/nist/nist-simpletype-facets.manifest.json",
    validatorCmd: 'xmllint --noout --schema "{schema}" "{instance}"',
    schemaValidatorCmd: "",
    engine: "saxonforms",
    facets: [],
    maxGroups: 0,
    jobs: 0,
    listOnly: false,
  };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--manifest") args.manifest = argv[++i];
    else if (arg === "--validator-cmd") args.validatorCmd = argv[++i];
    else if (arg === "--schema-validator-cmd") args.schemaValidatorCmd = argv[++i];
    else if (arg === "--engine") args.engine = argv[++i];
    else if (arg === "--facet") args.facets.push(argv[++i]);
    else if (arg === "--max-groups") args.maxGroups = Number(argv[++i] || "0");
    else if (arg === "--jobs") args.jobs = Number(argv[++i] || "0");
    else if (arg === "--list-only") args.listOnly = true;
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
  console.log(`Usage: node scripts/run-nist-facet-harness.mjs [options]
Options:
  --manifest <path>              Manifest JSON path
  --validator-cmd <template>     Instance validator command (uses {schema}, {instance})
  --schema-validator-cmd <tmpl>  Optional schema validator command (uses {schema})
  --engine <saxonforms|xmllint>  Validation engine for instance tests (default: saxonforms)
  --facet <name>                 Restrict to facet (repeatable)
  --max-groups <n>               Limit selected groups
  --jobs <n>                     Number of groups to process concurrently (default: auto)
  --list-only                    Select and list tests without executing validators`);
}

function getRepoRoot() {
  const scriptDir = path.dirname(fileURLToPath(import.meta.url));
  return path.resolve(scriptDir, "..");
}

function loadManifest(manifestPath) {
  const text = fs.readFileSync(manifestPath, "utf8");
  const manifest = JSON.parse(text);
  if (!manifest.source_test_set || !manifest.facets) {
    throw new Error("Manifest must contain source_test_set and facets.");
  }
  return manifest;
}

function resolveSourceTestSetPath(repoRoot, sourceTestSet) {
  const testPaths = getTestPaths(repoRoot);
  const sourceValue = String(sourceTestSet || "").trim();
  const directPath = path.resolve(repoRoot, sourceValue);
  if (fs.existsSync(directPath)) {
    return { sourceValue, resolvedPath: directPath, warning: null };
  }

  const normalizedSlashes = sourceValue.replaceAll("\\", "/");
  const legacyPrefix = "../xsdtests/";
  if (normalizedSlashes.startsWith(legacyPrefix)) {
    const mappedSource = `tests/fixtures/external/xsdtests/${normalizedSlashes.slice(legacyPrefix.length)}`;
    const mappedPath = path.resolve(repoRoot, mappedSource);
    if (fs.existsSync(mappedPath)) {
      return {
        sourceValue: mappedSource,
        resolvedPath: mappedPath,
        warning: `legacy source_test_set "${sourceValue}" resolved to "${mappedSource}".`
      };
    }
  }
  const canonicalPrefix = "tests/fixtures/external/xsdtests/";
  if (normalizedSlashes.startsWith(canonicalPrefix)) {
    const mappedPath = path.join(
      testPaths.fixturesXsdtestsDir,
      normalizedSlashes.slice(canonicalPrefix.length)
    );
    if (fs.existsSync(mappedPath)) {
      return { sourceValue, resolvedPath: mappedPath, warning: null };
    }
  }

  return { sourceValue, resolvedPath: directPath, warning: null };
}
function selectGroups(manifest, facetsFilter) {
  const selectedFacetNames = facetsFilter.length ? facetsFilter : Object.keys(manifest.facets);
  const missing = selectedFacetNames.filter((name) => !(name in manifest.facets));
  if (missing.length) {
    throw new Error(`Facet(s) not found in manifest: ${missing.join(", ")}`);
  }
  const rows = [];
  for (const facet of selectedFacetNames) {
    const payload = manifest.facets[facet] ?? {};
    for (const group of payload.valid_groups ?? []) rows.push({ facet, origin: "valid_groups", group });
    for (const group of payload.invalid_groups ?? []) rows.push({ facet, origin: "invalid_groups", group });
  }
  const seen = new Set();
  const deduped = [];
  for (const row of rows) {
    if (seen.has(row.group)) continue;
    seen.add(row.group);
    deduped.push(row);
  }
  return deduped;
}

function extractGroupBlocks(xml) {
  const groups = new Map();
  const groupRe = /<testGroup\b[^>]*\bname="([^"]+)"[^>]*>([\s\S]*?)<\/testGroup>/g;
  let m;
  while ((m = groupRe.exec(xml)) !== null) {
    groups.set(m[1], m[2]);
  }
  return groups;
}

function extractExpectedValidity(block) {
  const match = block.match(/<expected\b[^>]*\bvalidity="(valid|invalid)"/);
  if (!match) throw new Error("Missing <expected validity=...> in test metadata.");
  return match[1] === "valid";
}

function extractSchemaTests(groupBody, testsetDir) {
  const tests = [];
  const re = /<schemaTest\b[^>]*\bname="([^"]+)"[^>]*>([\s\S]*?)<\/schemaTest>/g;
  let m;
  while ((m = re.exec(groupBody)) !== null) {
    const name = m[1];
    const body = m[2];
    const hrefMatch = body.match(/<schemaDocument\b[^>]*\bxlink:href="([^"]+)"/);
    if (!hrefMatch) continue;
    tests.push({
      kind: "schema",
      name,
      expectedValid: extractExpectedValidity(body),
      schema: path.resolve(testsetDir, hrefMatch[1]),
    });
  }
  return tests;
}

function extractInstanceTests(groupBody, testsetDir) {
  const tests = [];
  const re = /<instanceTest\b[^>]*\bname="([^"]+)"[^>]*>([\s\S]*?)<\/instanceTest>/g;
  let m;
  while ((m = re.exec(groupBody)) !== null) {
    const name = m[1];
    const body = m[2];
    const hrefMatch = body.match(/<instanceDocument\b[^>]*\bxlink:href="([^"]+)"/);
    if (!hrefMatch) continue;
    tests.push({
      kind: "instance",
      name,
      expectedValid: extractExpectedValidity(body),
      instance: path.resolve(testsetDir, hrefMatch[1]),
    });
  }
  return tests;
}

function resolveJobCount(rawJobs) {
  if (Number.isInteger(rawJobs) && rawJobs > 0) return rawJobs;
  return Math.max(1, Math.min(8, os.cpus().length || 1));
}

function spawnAndCollect(command, args = [], options = {}) {
  return new Promise((resolve) => {
    const child = spawn(command, args, options);
    let stdout = "";
    let stderr = "";
    child.stdout?.on("data", (chunk) => {
      stdout += String(chunk);
    });
    child.stderr?.on("data", (chunk) => {
      stderr += String(chunk);
    });
    child.on("error", (error) => {
      resolve({ status: 1, stdout, stderr: `${stderr}${error instanceof Error ? error.message : String(error)}` });
    });
    child.on("close", (status) => {
      resolve({ status: status ?? 1, stdout, stderr });
    });
  });
}
function applyTemplateReplacements(templateValue, replacements) {
  let output = templateValue;
  for (const [key, value] of Object.entries(replacements)) {
    output = output.replaceAll(`{${key}}`, value);
  }
  return output;
}

function splitCommandTemplate(template) {
  const tokens = [];
  let current = "";
  let quote = "";
  for (let i = 0; i < template.length; i++) {
    const ch = template[i];
    if (quote) {
      if (ch === quote) {
        quote = "";
        continue;
      }
      if (ch === "\\" && quote === "\"" && i + 1 < template.length) {
        const next = template[i + 1];
        if (next === "\"" || next === "\\") {
          current += next;
          i += 1;
          continue;
        }
      }
      current += ch;
      continue;
    }
    if (ch === "\"" || ch === "'") {
      quote = ch;
      continue;
    }
    if (/\s/.test(ch)) {
      if (current !== "") {
        tokens.push(current);
        current = "";
      }
      continue;
    }
    current += ch;
  }
  if (quote) {
    throw new Error(`Unterminated quote in command template: ${template}`);
  }
  if (current !== "") {
    tokens.push(current);
  }
  return tokens;
}

async function runTemplate(template, replacements) {
  const resolvedTemplate = applyTemplateReplacements(template, replacements);
  const tokens = splitCommandTemplate(resolvedTemplate);
  if (!tokens.length) {
    return { ok: false, detail: "validator command template resolved to an empty command" };
  }
  const [command, ...args] = tokens;
  const proc = await spawnAndCollect(command, args);
  const output = `${proc.stdout ?? ""}${proc.stderr ?? ""}`.trim();
  return { ok: proc.status === 0, detail: output };
}
async function runSaxonFormsInstanceCheck(checkerPath, schemaPath, instancePath) {
  const isWindows = process.platform === "win32";
  const npxCommand = isWindows ? "npx.cmd" : "npx";
  const proc = await spawnAndCollect(npxCommand, [
    "xslt3",
    `-xsl:${checkerPath}`,
    "-it:main",
    `schema-uri=${schemaPath}`,
    `instance-uri=${instancePath}`,
  ], isWindows ? { shell: true } : {});
  const output = `${proc.stdout ?? ""}${proc.stderr ?? ""}`.trim();
  const m = output.match(/<result\b[^>]*\bvalid="(true|false)"/);
  if (proc.status !== 0 || !m) {
    return { ok: false, actualValid: false, detail: output || "unable to parse SaxonForms checker output" };
  }
  return { ok: true, actualValid: m[1] === "true", detail: output };
}
async function mapWithConcurrency(items, maxConcurrency, worker, onItemComplete) {
  if (!items.length) return [];
  const concurrency = Math.max(1, Math.min(maxConcurrency, items.length));
  const out = new Array(items.length);
  let nextIndex = 0;
  async function runWorker() {
    while (true) {
      const index = nextIndex;
      nextIndex += 1;
      if (index >= items.length) break;
      out[index] = await worker(items[index], index);
      if (typeof onItemComplete === "function") {
        onItemComplete(out[index], index);
      }
    }
  }
  await Promise.all(Array.from({ length: concurrency }, () => runWorker()));
  return out;
}


async function main() {
  const args = parseArgs(process.argv.slice(2));
  const repoRoot = getRepoRoot();
  const manifestPath = path.resolve(repoRoot, args.manifest);
  const checkerPath = path.resolve(repoRoot, "scripts/nist-xsd-instance-check.xsl");
  if (!fs.existsSync(manifestPath)) throw new Error(`Manifest not found: ${manifestPath}`);
  const manifest = loadManifest(manifestPath);
  const sourceTestSet = resolveSourceTestSetPath(repoRoot, manifest.source_test_set);
  if (sourceTestSet.warning) {
    console.warn(`[warn] ${sourceTestSet.warning}`);
  }
  const testsetPath = sourceTestSet.resolvedPath;
  if (!fs.existsSync(testsetPath)) {
    throw new Error(
      `Source testSet not found: ${testsetPath} (manifest source_test_set=${manifest.source_test_set})`
    );
  }
  const testsetXml = fs.readFileSync(testsetPath, "utf8");
  const groupsIndex = extractGroupBlocks(testsetXml);
  let selected = selectGroups(manifest, args.facets);
  if (args.maxGroups > 0) selected = selected.slice(0, args.maxGroups);

  console.log(`manifest=${manifestPath}`);
  console.log(`source_test_set=${sourceTestSet.sourceValue}`);
  console.log(`testset=${testsetPath}`);
  console.log(`selected_groups=${selected.length}`);
  const jobs = resolveJobCount(args.jobs);
  console.log(`jobs=${jobs}`);

  const missing = selected.filter((row) => !groupsIndex.has(row.group));
  if (missing.length) {
    console.error("Missing groups in source testSet:");
    for (const row of missing) console.error(`  - ${row.group}`);
    process.exit(2);
  }

  const allResults = [];
  if (!["saxonforms", "xmllint"].includes(args.engine)) throw new Error(`Unsupported --engine value: ${args.engine}`);
  let processedGroups = 0;
  const groupOutcomes = await mapWithConcurrency(selected, jobs, async (row) => {
    const groupBody = groupsIndex.get(row.group);
    const schemaCases = extractSchemaTests(groupBody, path.dirname(testsetPath));
    const instanceCases = extractInstanceTests(groupBody, path.dirname(testsetPath));
    const schemaCase = schemaCases[0] ?? null;
    const groupCases = [...schemaCases, ...instanceCases];
    const groupResults = [];

    for (const c of groupCases) {
      if (args.listOnly) {
        groupResults.push({ ...c, passed: true, skipped: true, actualValid: null, detail: "list-only" });
        continue;
      }
      if (c.kind === "schema") {
        if (args.engine === "saxonforms") {
          groupResults.push({
            ...c,
            passed: true,
            skipped: true,
            actualValid: null,
            detail: "schema test skipped for saxonforms engine",
          });
          continue;
        }
        if (!args.schemaValidatorCmd) {
          groupResults.push({
            ...c,
            passed: true,
            skipped: true,
            actualValid: null,
            detail: "schema-validator-cmd not provided; schema test skipped",
          });
          continue;
        }
        const result = await runTemplate(args.schemaValidatorCmd, { schema: c.schema });
        const actualValid = result.ok;
        groupResults.push({ ...c, actualValid, passed: actualValid === c.expectedValid, skipped: false, detail: result.detail });
        continue;
      }
      if (!schemaCase?.schema) {
        groupResults.push({ ...c, passed: false, skipped: true, actualValid: null, detail: `missing schemaTest in group ${row.group}` });
        continue;
      }
      if (args.engine === "saxonforms") {
        // TEST-TRACE: run instance checks through Saxon-Forms xsd-helpers facet logic; helps NIST facet manifest execution.
        const result = await runSaxonFormsInstanceCheck(checkerPath, schemaCase.schema, c.instance);
        const actualValid = result.actualValid;
        groupResults.push({ ...c, actualValid, passed: result.ok && actualValid === c.expectedValid, skipped: false, detail: result.detail });
        continue;
      }
      const result = await runTemplate(args.validatorCmd, { schema: schemaCase.schema, instance: c.instance });
      const actualValid = result.ok;
      groupResults.push({ ...c, actualValid, passed: actualValid === c.expectedValid, skipped: false, detail: result.detail });
    }

    return { row, groupCases, groupResults };
  }, (outcome) => {
    processedGroups += 1;
    const { row, groupCases, groupResults } = outcome;
    const passed = groupResults.filter((r) => r.passed).length;
    const skipped = groupResults.filter((r) => r.skipped).length;
    console.log(`[progress] groups=${processedGroups}/${selected.length}`);
    console.log(`[group] facet=${row.facet} origin=${row.origin} name=${row.group} cases=${groupCases.length} passed=${passed} skipped=${skipped}`);
  });

  for (const outcome of groupOutcomes) {
    const { groupResults } = outcome;
    allResults.push(...groupResults);
  }

  const total = allResults.length;
  const passed = allResults.filter((r) => r.passed).length;
  const skipped = allResults.filter((r) => r.skipped).length;
  const failed = allResults.filter((r) => !r.passed && !r.skipped);
  console.log(`[summary] total=${total} passed=${passed} failed=${failed.length} skipped=${skipped}`);
  for (const r of failed.slice(0, 30)) {
    console.log(
      `[fail] kind=${r.kind} name=${r.name} expected=${r.expectedValid ? "valid" : "invalid"} actual=${r.actualValid ? "valid" : "invalid"}`,
    );
    if (r.detail) console.log(`       detail=${String(r.detail).slice(0, 500)}`);
  }
  process.exit(failed.length ? 1 : 0);
}

try {
  await main();
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(2);
}
