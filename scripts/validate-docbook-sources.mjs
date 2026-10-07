#!/usr/bin/env node
import { execFile } from "node:child_process";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");
const docbookRoot = path.join(repoRoot, "docs", "docbook");
const identityStylesheetPath = path.join(__dirname, "docbook-identity.xsl");
const validationTempDir = path.join(repoRoot, "builds", "docs-docbook", "validation");
function parseArgs(argv) {
  const config = { help: false };
  for (const arg of argv) {
    if (arg === "--help" || arg === "-h") {
      config.help = true;
      continue;
    }
    throw new Error(`Unknown option: ${arg}`);
  }
  return config;
}

const citationLintRules = [
  {
    description: "L-number line citation",
    pattern: /\bL\d{2,}(?:[–-]\d{2,})?\b/g
  },
  {
    description: "file:line citation",
    pattern: /\b[\w./-]+\.xsl:\d+\b/g
  }
];

async function validateCitationStability(errors) {
  const sourceFiles = await collectFiles(docbookRoot, new Set([".xml", ".plantuml"]));

  for (const sourceFilePath of sourceFiles) {
    const source = await fs.readFile(sourceFilePath, "utf8");
    const relativeSourcePath = toPosixPath(path.relative(repoRoot, sourceFilePath));

    for (const rule of citationLintRules) {
      const matches = source.match(rule.pattern) ?? [];
      if (matches.length === 0) {
        continue;
      }
      const uniqueMatches = [...new Set(matches)];
      const sampleMatches = uniqueMatches.slice(0, 5).join(", ");
      const moreSuffix = uniqueMatches.length > 5 ? ", ..." : "";
      errors.push(
        `Found ${rule.description} in ${relativeSourcePath}: ${sampleMatches}${moreSuffix}. Use symbol and file references instead.`
      );
    }
  }
}

function printHelp() {
  console.log(
    [
      "Usage: node scripts/validate-docbook-sources.mjs [options]",
      "",
      "Validates DocBook XML sources, XInclude references, and checkpoint metadata.",
      "",
      "Options:",
      "  --help, -h        Show this help"
    ].join("\n")
  );
}

function toPosixPath(inputPath) {
  return inputPath.split(path.sep).join("/");
}

async function pathExists(candidatePath) {
  try {
    await fs.access(candidatePath);
    return true;
  } catch {
    return false;
  }
}

async function collectFiles(rootDir, extensions) {
  const files = [];

  async function walk(currentDir) {
    const entries = await fs.readdir(currentDir, { withFileTypes: true });
    for (const entry of entries) {
      const fullPath = path.join(currentDir, entry.name);
      if (entry.isDirectory()) {
        await walk(fullPath);
        continue;
      }
      if (entry.isFile() && extensions.has(path.extname(entry.name).toLowerCase())) {
        files.push(fullPath);
      }
    }
  }

  await walk(rootDir);
  files.sort((left, right) => left.localeCompare(right));
  return files;
}

function extractXiIncludeHrefs(xmlSource) {
  const hrefs = [];
  const includePattern = /<xi:include\b[^>]*\bhref\s*=\s*"([^"]+)"/g;
  let match;
  while ((match = includePattern.exec(xmlSource)) !== null) {
    hrefs.push(match[1]);
  }
  return hrefs;
}

async function validateXmlWellFormed(xmlFilePath) {
  const relativeSourcePath = toPosixPath(path.relative(repoRoot, xmlFilePath));
  const outputFilePath = path.join(
    validationTempDir,
    relativeSourcePath.replace(/[\\/]/g, "__").replace(/\.xml$/i, ".validated.xml")
  );
  await fs.mkdir(path.dirname(outputFilePath), { recursive: true });

  await execFileAsync(
    "npx",
    [
      "xslt3",
      `-xsl:${identityStylesheetPath}`,
      `-s:${xmlFilePath}`,
      `-o:${outputFilePath}`
    ],
    {
      cwd: repoRoot,
      shell: process.platform === "win32",
      maxBuffer: 10 * 1024 * 1024
    }
  );
}

async function validateCheckpointMetadata(errors, warnings) {
  const checkpointFilePath = path.join(docbookRoot, "checkpoints", "chapter-checkpoints.json");
  const traceSpecFilePath = path.join(docbookRoot, "checkpoints", "sequence-trace-spec.json");

  const [checkpointRaw, traceRaw] = await Promise.all([
    fs.readFile(checkpointFilePath, "utf8"),
    fs.readFile(traceSpecFilePath, "utf8")
  ]);

  const checkpointData = JSON.parse(checkpointRaw);
  const traceData = JSON.parse(traceRaw);
  const traceById = new Map((traceData.sequence_diagrams || []).map((entry) => [entry.id, entry]));
  const chapterSequenceIds = new Set();

  const diagramDirectoryPath = path.join(docbookRoot, "diagrams");
  const sequenceDiagramFiles = (await collectFiles(diagramDirectoryPath, new Set([".plantuml"]))).filter(
    (diagramPath) => path.basename(diagramPath).startsWith("sequence-")
  );
  const sequenceDiagramIds = sequenceDiagramFiles.map((diagramPath) =>
    path.basename(diagramPath, path.extname(diagramPath))
  );

  for (const sequenceDiagramId of sequenceDiagramIds) {
    if (!traceById.has(sequenceDiagramId)) {
      errors.push(
        `Sequence diagram ${sequenceDiagramId} is missing from docs/docbook/checkpoints/sequence-trace-spec.json`
      );
    }
  }

  for (const chapter of checkpointData.chapters || []) {
    if (!chapter?.source) {
      errors.push(`Chapter ${chapter?.id || "<missing-id>"} has no source path.`);
      continue;
    }

    const sourcePath = path.join(repoRoot, chapter.source);
    if (!(await pathExists(sourcePath))) {
      errors.push(`Chapter source is missing: ${chapter.source}`);
    }

    for (const specPath of chapter.w3c_specs || []) {
      const resolvedSpecPath = path.join(repoRoot, specPath);
      if (!(await pathExists(resolvedSpecPath))) {
        errors.push(`Missing W3C spec path for checkpoint ${chapter.id}: ${specPath}`);
      }
    }

    for (const sequenceDiagramId of chapter.sequence_diagrams || []) {
      chapterSequenceIds.add(sequenceDiagramId);
      if (!traceById.has(sequenceDiagramId)) {
        errors.push(
          `Checkpoint ${chapter.id} references unknown sequence diagram id: ${sequenceDiagramId}`
        );
      }
    }
  }

  for (const sequenceDiagramId of sequenceDiagramIds) {
    if (!chapterSequenceIds.has(sequenceDiagramId)) {
      errors.push(
        `Sequence diagram ${sequenceDiagramId} is not referenced by any chapter checkpoint`
      );
    }
  }

  for (const sequence of traceData.sequence_diagrams || []) {
    const diagramPath = path.join(repoRoot, sequence.diagram || "");
    if (!(await pathExists(diagramPath))) {
      errors.push(`Sequence diagram file missing for ${sequence.id}: ${sequence.diagram}`);
    }
    for (const testPath of sequence.verification_tests || []) {
      const resolvedTestPath = path.join(repoRoot, testPath);
      if (!(await pathExists(resolvedTestPath))) {
        errors.push(`Sequence verification test missing for ${sequence.id}: ${testPath}`);
      }
    }
    for (const hook of sequence.trace_hooks || []) {
      const hookPath = path.join(repoRoot, hook.location || "");
      if (!(await pathExists(hookPath))) {
        warnings.push(`Trace hook file missing for ${sequence.id}: ${hook.location}`);
      }
    }
  }
}

async function main() {
  const config = parseArgs(process.argv.slice(2));
  if (config.help) {
    printHelp();
    return;
  }
  const xmlFiles = await collectFiles(docbookRoot, new Set([".xml"]));
  const errors = [];
  const warnings = [];
  const validatedFiles = [];

  for (const xmlFilePath of xmlFiles) {
    const relativeXmlPath = toPosixPath(path.relative(repoRoot, xmlFilePath));
    const xmlSource = await fs.readFile(xmlFilePath, "utf8");
    const includeHrefs = extractXiIncludeHrefs(xmlSource);

    for (const href of includeHrefs) {
      const includePath = path.resolve(path.dirname(xmlFilePath), href);
      if (!(await pathExists(includePath))) {
        errors.push(`Missing XInclude target in ${relativeXmlPath}: ${href}`);
      }
    }

    try {
      await validateXmlWellFormed(xmlFilePath);
      validatedFiles.push(relativeXmlPath);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      errors.push(`XML parse/transform validation failed for ${relativeXmlPath}: ${message}`);
    }
  }

  await validateCheckpointMetadata(errors, warnings);
  await validateCitationStability(errors);

  console.log(
    JSON.stringify(
      {
        event: "docbook-validation-summary",
        ts: new Date().toISOString(),
        docbook_root: toPosixPath(path.relative(repoRoot, docbookRoot)),
        xml_file_count: xmlFiles.length,
        validated_file_count: validatedFiles.length,
        warning_count: warnings.length,
        error_count: errors.length,
        warnings,
        errors
      },
      null,
      2
    )
  );

  if (errors.length > 0) {
    process.exit(1);
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.stack ?? error.message : String(error));
  process.exit(1);
});
