#!/usr/bin/env node
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");
const defaultSiteRoot = path.join(repoRoot, "builds", "site");

function parseArgs(argv) {
  const config = {
    siteRoot: defaultSiteRoot,
    help: false
  };

  for (const arg of argv) {
    if (arg === "--help" || arg === "-h") {
      config.help = true;
      continue;
    }
    if (arg.startsWith("--site-root=")) {
      config.siteRoot = path.resolve(repoRoot, arg.slice("--site-root=".length).trim());
      continue;
    }
    throw new Error(`Unknown option: ${arg}`);
  }

  return config;
}

function printHelp() {
  console.log(
    [
      "Usage: node scripts/validate-site-links.mjs [options]",
      "",
      "Validate internal href/src links in assembled site HTML output.",
      "",
      "Options:",
      "  --site-root=<path>     Override site root (default: builds/site)",
      "  --help, -h             Show this help"
    ].join("\n")
  );
}

async function pathExists(candidatePath) {
  try {
    await fs.access(candidatePath);
    return true;
  } catch {
    return false;
  }
}

async function collectHtmlFiles(rootDir) {
  const files = [];

  async function walk(currentDir) {
    const entries = await fs.readdir(currentDir, { withFileTypes: true });
    for (const entry of entries) {
      const fullPath = path.join(currentDir, entry.name);
      if (entry.isDirectory()) {
        await walk(fullPath);
        continue;
      }
      if (entry.isFile() && path.extname(entry.name).toLowerCase() === ".html") {
        files.push(fullPath);
      }
    }
  }

  await walk(rootDir);
  files.sort((left, right) => left.localeCompare(right));
  return files;
}

function shouldSkipLink(rawLink) {
  if (!rawLink) return true;
  if (rawLink.startsWith("#")) return true;
  if (rawLink.startsWith("mailto:")) return true;
  if (rawLink.startsWith("tel:")) return true;
  if (rawLink.startsWith("javascript:")) return true;
  if (rawLink.startsWith("data:")) return true;
  if (rawLink.startsWith("http://") || rawLink.startsWith("https://")) return true;
  if (rawLink.startsWith("//")) return true;
  return false;
}

function normalizeLink(rawLink) {
  const noHash = rawLink.split("#")[0];
  const noQuery = noHash.split("?")[0];
  return noQuery.trim();
}

function decodeLinkPath(linkPath) {
  try {
    return decodeURI(linkPath);
  } catch {
    return linkPath;
  }
}

async function checkLinkTarget(siteRoot, htmlFilePath, rawLink) {
  const normalized = normalizeLink(rawLink);
  if (!normalized) {
    return { ok: true };
  }

  const decodedLink = decodeLinkPath(normalized);
  const targetPath = decodedLink.startsWith("/")
    ? path.join(siteRoot, decodedLink.slice(1))
    : path.resolve(path.dirname(htmlFilePath), decodedLink);

  const candidates = [targetPath];
  if (decodedLink.endsWith("/")) {
    candidates.push(path.join(targetPath, "index.html"));
  } else if (!path.extname(targetPath)) {
    candidates.push(`${targetPath}.html`);
    candidates.push(path.join(targetPath, "index.html"));
  }

  for (const candidate of candidates) {
    if (await pathExists(candidate)) {
      return { ok: true };
    }
  }
  return {
    ok: false,
    candidates
  };
}

async function main() {
  const config = parseArgs(process.argv.slice(2));
  if (config.help) {
    printHelp();
    return;
  }

  if (!(await pathExists(config.siteRoot))) {
    throw new Error(`Site root does not exist: ${config.siteRoot}`);
  }

  const htmlFiles = await collectHtmlFiles(config.siteRoot);
  if (htmlFiles.length === 0) {
    throw new Error(`No HTML files found under site root: ${config.siteRoot}`);
  }

  const missingLinks = [];
  const linkPattern = /(href|src)=["']([^"']+)["']/gi;

  for (const htmlFilePath of htmlFiles) {
    const htmlSource = await fs.readFile(htmlFilePath, "utf8");
    let match;
    const uniqueLinks = new Set();
    while ((match = linkPattern.exec(htmlSource)) !== null) {
      const linkValue = match[2];
      if (shouldSkipLink(linkValue)) {
        continue;
      }
      uniqueLinks.add(linkValue);
    }

    for (const linkValue of uniqueLinks) {
      const result = await checkLinkTarget(config.siteRoot, htmlFilePath, linkValue);
      if (result.ok) {
        continue;
      }
      missingLinks.push({
        file: path.relative(repoRoot, htmlFilePath),
        link: linkValue,
        checked: result.candidates.map((candidate) => path.relative(repoRoot, candidate))
      });
    }
  }

  if (missingLinks.length > 0) {
    console.error(
      JSON.stringify(
        {
          event: "site-link-validation-failed",
          ts: new Date().toISOString(),
          missing_link_count: missingLinks.length,
          missing_links: missingLinks
        },
        null,
        2
      )
    );
    process.exit(1);
  }

  console.log(
    JSON.stringify(
      {
        event: "site-link-validation-complete",
        ts: new Date().toISOString(),
        site_root: path.relative(repoRoot, config.siteRoot),
        html_file_count: htmlFiles.length,
        missing_link_count: 0
      },
      null,
      2
    )
  );
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
