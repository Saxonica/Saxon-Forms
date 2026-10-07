#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

/**
 * Build a precomputed index of NIST engine test cases for Playwright.
 * This moves expensive manifest + testset parsing and schema/instance
 * file reads out of test startup and into an explicit offline step.
 */

function parseArgs(argv) {
  const args = {
    manifest: "tests/xsd/nist/nist-simpletype-facets.manifest.json",
    out: "tests/xsd/nist/.cache/nist-engine-case-index.json",
  };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--manifest") {
      args.manifest = argv[++i];
      continue;
    }
    if (arg === "--out") {
      args.out = argv[++i];
      continue;
    }
    if (arg === "--help" || arg === "-h") {
      printHelp();
      process.exit(0);
    }
    throw new Error(`Unknown argument: ${arg}`);
  }
  return args;
}

function printHelp() {
  console.log(`Usage: node scripts/build-nist-engine-case-index.mjs [options]
Options:
  --manifest <path>  Source manifest path (default: tests/xsd/nist/nist-simpletype-facets.manifest.json)
  --out <path>       Output JSON path (default: tests/xsd/nist/.cache/nist-engine-case-index.json)`);
}

function getRepoRoot() {
  const scriptDir = path.dirname(fileURLToPath(import.meta.url));
  return path.resolve(scriptDir, "..");
}

function loadJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function selectGroups(manifest) {
  const rows = [];
  for (const facetName of Object.keys(manifest.facets ?? {})) {
    const payload = manifest.facets[facetName] ?? {};
    for (const group of payload.valid_groups ?? []) {
      rows.push({ facet: facetName, origin: "valid_groups", group });
    }
    for (const group of payload.invalid_groups ?? []) {
      rows.push({ facet: facetName, origin: "invalid_groups", group });
    }
  }
  const seen = new Set();
  return rows.filter((row) => {
    if (seen.has(row.group)) return false;
    seen.add(row.group);
    return true;
  });
}

function extractGroupBlocks(testsetXml) {
  const groups = new Map();
  const groupRe = /<testGroup\b[^>]*\bname="([^"]+)"[^>]*>([\s\S]*?)<\/testGroup>/g;
  let match = null;
  while ((match = groupRe.exec(testsetXml)) !== null) {
    groups.set(match[1], match[2]);
  }
  return groups;
}

function extractSchemaHref(groupBody) {
  const match = groupBody.match(/<schemaDocument\b[^>]*\bxlink:href="([^"]+)"/);
  return match?.[1] ?? null;
}

function extractInstanceCases(groupBody) {
  const out = [];
  const re = /<instanceTest\b[^>]*>([\s\S]*?)<\/instanceTest>/g;
  let match = null;
  while ((match = re.exec(groupBody)) !== null) {
    const body = match[1];
    const hrefMatch = body.match(/<instanceDocument\b[^>]*\bxlink:href="([^"]+)"/);
    const validityMatch = body.match(/<expected\b[^>]*\bvalidity="(valid|invalid)"/);
    if (!hrefMatch || !validityMatch) continue;
    out.push({
      href: hrefMatch[1],
      expectedValid: validityMatch[1] === "valid",
    });
  }
  return out;
}

function analyzeSchemaRootAndType(schemaXml) {
  const elementMatch = schemaXml.match(/<(?:\w+:)?element\b[^>]*\bname="([^"]+)"[^>]*\btype="([^"]+)"/);
  if (!elementMatch) {
    return { ok: false, reason: "schema has no top-level element with both @name and @type" };
  }
  return { ok: true, rootName: elementMatch[1], typeName: elementMatch[2] };
}

function extractSchemaTargetNamespace(schemaXml) {
  const schemaMatch = schemaXml.match(/<(?:\w+:)?schema\b[^>]*\btargetNamespace="([^"]+)"/);
  return schemaMatch?.[1] ?? "";
}

function extractInstanceLexicalValue(instanceXml) {
  const noXmlDecl = instanceXml.replace(/^\s*<\?xml[^>]*>\s*/i, "");
  const rootMatch = noXmlDecl.match(/<[^!?][^>]*>([\s\S]*)<\/[^>]+>\s*$/);
  if (!rootMatch) return "";
  const inner = rootMatch[1];
  return inner.replace(/^[\r\n\s]+|[\r\n\s]+$/g, "");
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const repoRoot = getRepoRoot();
  const manifestPath = path.resolve(repoRoot, args.manifest);
  const outPath = path.resolve(repoRoot, args.out);

  const manifest = loadJson(manifestPath);
  const testsetPath = path.resolve(repoRoot, manifest.source_test_set);
  const testsetDir = path.dirname(testsetPath);
  const testsetXml = fs.readFileSync(testsetPath, "utf8");
  const groupBlocks = extractGroupBlocks(testsetXml);
  const selected = selectGroups(manifest);

  const runnableCases = [];
  const unsupportedGroups = [];

  for (const row of selected) {
    const groupBody = groupBlocks.get(row.group);
    if (!groupBody) {
      unsupportedGroups.push({
        facet: row.facet,
        group: row.group,
        reason: "group missing from source testSet",
      });
      continue;
    }

    const schemaHref = extractSchemaHref(groupBody);
    if (!schemaHref) {
      unsupportedGroups.push({
        facet: row.facet,
        group: row.group,
        reason: "group has no schemaDocument href",
      });
      continue;
    }

    const instanceCases = extractInstanceCases(groupBody);
    const preferredValidity = row.origin === "valid_groups";
    const chosen = instanceCases.find((entry) => entry.expectedValid === preferredValidity) ?? instanceCases[0];
    if (!chosen) {
      unsupportedGroups.push({
        facet: row.facet,
        group: row.group,
        reason: "group has no instanceTest cases",
      });
      continue;
    }

    const schemaPath = path.resolve(testsetDir, schemaHref);
    const instancePath = path.resolve(testsetDir, chosen.href);
    const schemaText = fs.readFileSync(schemaPath, "utf8");
    const instanceText = fs.readFileSync(instancePath, "utf8");
    const shape = analyzeSchemaRootAndType(schemaText);
    if (!shape.ok) {
      unsupportedGroups.push({
        facet: row.facet,
        group: row.group,
        reason: shape.reason,
      });
      continue;
    }

    runnableCases.push({
      caseId: `${row.facet}-${row.group}`,
      title: `${row.facet} / ${row.group}`,
      expectedValid: chosen.expectedValid,
      schemaHref,
      schemaText,
      typeName: shape.typeName,
      rootName: shape.rootName,
      targetNamespace: extractSchemaTargetNamespace(schemaText),
      lexicalValue: extractInstanceLexicalValue(instanceText),
    });
  }

  const payload = {
    generated_at: new Date().toISOString(),
    manifest_path: path.relative(repoRoot, manifestPath).replaceAll("\\", "/"),
    source_test_set: manifest.source_test_set,
    selected_count: selected.length,
    runnable_cases: runnableCases,
    unsupported_groups: unsupportedGroups,
  };

  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, `${JSON.stringify(payload)}\n`);

  console.log(`manifest=${manifestPath}`);
  console.log(`testset=${testsetPath}`);
  console.log(`selected_groups=${selected.length}`);
  console.log(`runnable_cases=${runnableCases.length}`);
  console.log(`unsupported_groups=${unsupportedGroups.length}`);
  console.log(`out=${outPath}`);
}

try {
  main();
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(2);
}
