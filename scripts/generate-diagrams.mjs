#!/usr/bin/env node
/**
 * Generate SVG diagrams from PlantUML sources.
 *
 * Usage:
 *   node scripts/generate-diagrams.mjs
 *
 * It looks for *.plantuml under docs/docbook/diagrams and emits matching .svg files.
 * Uses `-tsvg -nometadata` to produce clean SVGs without embedded source metadata
 * (which can contain illegal `--` sequences inside XML comments).
 *
 * The PlantUML jar is downloaded on first use and cached under ~/.cache/plantuml
 * (or %USERPROFILE%\.cache\plantuml on Windows). You can override by setting
 * PLANTUML_JAR=/path/to/plantuml.jar .
 */
import fs from "node:fs/promises";
import path from "node:path";
import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

const DIAGRAMS_DIR = path.resolve("docs", "docbook", "diagrams");
const PLANTUML_VERSION = "1.2025.4";
const PLANTUML_JAR_NAME = `plantuml-${PLANTUML_VERSION}.jar`;
const PLANTUML_URL = `https://github.com/plantuml/plantuml/releases/download/v${PLANTUML_VERSION}/${PLANTUML_JAR_NAME}`;

function getCacheDir() {
  const home = process.env.HOME || process.env.USERPROFILE || process.cwd();
  return path.join(home, ".cache", "plantuml");
}

async function ensurePlantumlJar() {
  const envJar = process.env.PLANTUML_JAR;
  if (envJar) {
    try {
      await fs.access(envJar);
      return path.resolve(envJar);
    } catch {
      // fall through to auto-download
    }
  }

  const cacheDir = getCacheDir();
  await fs.mkdir(cacheDir, { recursive: true });
  const cached = path.join(cacheDir, PLANTUML_JAR_NAME);

  try {
    await fs.access(cached);
    return cached;
  } catch {
    // need to download
  }

  console.log(`[generate-diagrams] Downloading PlantUML ${PLANTUML_VERSION}...`);
  const res = await fetch(PLANTUML_URL, { redirect: "follow" });
  if (!res.ok) {
    throw new Error(`Failed to download PlantUML: HTTP ${res.status} ${res.statusText}`);
  }
  const buf = Buffer.from(await res.arrayBuffer());
  await fs.writeFile(cached, buf);
  console.log(`[generate-diagrams] Cached to ${cached}`);
  return cached;
}

async function generateDiagrams(jarPath) {
  let entries;
  try {
    entries = await fs.readdir(DIAGRAMS_DIR);
  } catch (e) {
    throw new Error(`Could not read diagrams directory: ${DIAGRAMS_DIR}`);
  }

  const pumlFiles = entries.filter((f) => f.toLowerCase().endsWith(".plantuml"));
  if (pumlFiles.length === 0) {
    console.log("[generate-diagrams] No .plantuml files found.");
    return;
  }

  for (const f of pumlFiles) {
    const full = path.join(DIAGRAMS_DIR, f);
    console.log(`[generate-diagrams] ${f} -> ${f.replace(/\.plantuml$/i, ".svg")}`);
    // PlantUML writes the .svg alongside the source when using -tsvg
    await execFileAsync("java", ["-jar", jarPath, "-tsvg", "-nometadata", full], {
      cwd: DIAGRAMS_DIR,
    });
  }

  console.log("[generate-diagrams] All diagrams regenerated (no metadata).");
}

async function main() {
  const jar = await ensurePlantumlJar();
  await generateDiagrams(jar);
}

main().catch((err) => {
  console.error("[generate-diagrams] ERROR:", err instanceof Error ? err.message : err);
  process.exit(1);
});
