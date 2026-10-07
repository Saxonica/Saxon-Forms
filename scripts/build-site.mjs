#!/usr/bin/env node
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");
const defaultSiteRoot = path.join(repoRoot, "builds", "site");
const defaultDocsPublicRoot = path.join(repoRoot, "builds", "docs-public");
const defaultManifestPath = path.join(repoRoot, "docs", "site", "markdown-manifest.json");

function parseArgs(argv) {
  const config = {
    siteRoot: defaultSiteRoot,
    docsPublicRoot: defaultDocsPublicRoot,
    manifestPath: defaultManifestPath,
    clean: true,
    buildSef: true,
    compileExamples: true,
    validateDocbook: true,
    buildDocbook: true,
    help: false
  };

  for (const arg of argv) {
    if (arg === "--help" || arg === "-h") {
      config.help = true;
      continue;
    }
    if (arg === "--no-clean") {
      config.clean = false;
      continue;
    }
    if (arg === "--skip-build-sef") {
      config.buildSef = false;
      continue;
    }
    if (arg === "--skip-examples-compile") {
      config.compileExamples = false;
      continue;
    }
    if (arg === "--skip-docbook-validate") {
      config.validateDocbook = false;
      continue;
    }
    if (arg === "--skip-docbook-build") {
      config.buildDocbook = false;
      continue;
    }
    if (arg.startsWith("--site-root=")) {
      config.siteRoot = path.resolve(repoRoot, arg.slice("--site-root=".length).trim());
      continue;
    }
    if (arg.startsWith("--docs-public-root=")) {
      config.docsPublicRoot = path.resolve(
        repoRoot,
        arg.slice("--docs-public-root=".length).trim()
      );
      continue;
    }
    if (arg.startsWith("--manifest=")) {
      config.manifestPath = path.resolve(repoRoot, arg.slice("--manifest=".length).trim());
      continue;
    }
    throw new Error(`Unknown option: ${arg}`);
  }

  return config;
}

function printHelp() {
  console.log(
    [
      "Usage: node scripts/build-site.mjs [options]",
      "",
      "Build and assemble the GitHub Pages site artifact at builds/site.",
      "",
      "Options:",
      "  --site-root=<path>            Override assembled site output root",
      "  --docs-public-root=<path>     Override intermediate markdown docs output root",
      "  --manifest=<path>             Override markdown manifest JSON path",
      "  --no-clean                    Do not remove previous assembled site output",
      "  --skip-build-sef              Skip `npm run build:sef`",
      "  --skip-examples-compile       Skip `npm run examples:compile`",
      "  --skip-docbook-validate       Skip `npm run docs:docbook:validate`",
      "  --skip-docbook-build          Skip `node scripts/run-docbook-build.mjs --format=html`",
      "  --help, -h                    Show this help"
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

async function ensureDirectoryExists(directoryPath, label) {
  if (!(await pathExists(directoryPath))) {
    throw new Error(`${label} not found: ${directoryPath}`);
  }
}

async function ensureFileExists(filePath, label) {
  if (!(await pathExists(filePath))) {
    throw new Error(`${label} not found: ${filePath}`);
  }
}

async function runCommand(command, args, description) {
  console.log(`[build-site] ${description}`);
  const isWindows = process.platform === "win32";
  const useWindowsCmd = isWindows && command.toLowerCase() === "npm";
  const resolvedCommand = useWindowsCmd ? "cmd.exe" : command;
  const resolvedArgs = useWindowsCmd ? ["/d", "/s", "/c", "npm", ...args] : args;
  await new Promise((resolve, reject) => {
    const child = spawn(resolvedCommand, resolvedArgs, {
      cwd: repoRoot,
      stdio: "inherit"
    });
    child.on("error", reject);
    child.on("exit", (code, signal) => {
      if (signal) {
        reject(new Error(`Command terminated by signal ${signal}: ${command} ${args.join(" ")}`));
        return;
      }
      if ((code ?? 1) !== 0) {
        reject(new Error(`Command failed (${code}): ${command} ${args.join(" ")}`));
        return;
      }
      resolve();
    });
  });
}

async function readManifest(manifestPath) {
  await ensureFileExists(manifestPath, "Markdown manifest");
  const raw = await fs.readFile(manifestPath, "utf8");
  const parsed = JSON.parse(raw);
  const markdownDocuments = Array.isArray(parsed?.markdown_documents)
    ? parsed.markdown_documents
    : [];

  if (markdownDocuments.length === 0) {
    throw new Error(
      `Manifest ${manifestPath} has no markdown_documents entries; at least one markdown source is required.`
    );
  }

  for (const entry of markdownDocuments) {
    if (!entry || typeof entry.source !== "string" || entry.source.trim() === "") {
      throw new Error(`Manifest ${manifestPath} contains an invalid markdown_documents entry.`);
    }
    if (!entry.source.toLowerCase().endsWith(".md")) {
      throw new Error(`Manifest source must be a markdown file: ${entry.source}`);
    }
    const sourcePath = path.resolve(repoRoot, entry.source);
    if (!(await pathExists(sourcePath))) {
      throw new Error(`Manifest source does not exist: ${entry.source}`);
    }
  }

  if (!parsed?.docbook || typeof parsed.docbook.html_output !== "string") {
    throw new Error(`Manifest ${manifestPath} must include docbook.html_output.`);
  }

  return parsed;
}

function sourceMarkdownToOutputRelativePath(sourcePath) {
  return sourcePath.replace(/\.md$/i, ".html");
}

function htmlEscape(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll("\"", "&quot;")
    .replaceAll("'", "&#39;");
}

function buildSiteIndexHtml() {
  return [
    "<!doctype html>",
    "<html lang=\"en\">",
    "<head>",
    "  <meta charset=\"utf-8\" />",
    "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />",
    "  <title>Saxon-Forms Documentation Site</title>",
    "  <style>",
    "    body { font-family: Inter, Segoe UI, Arial, sans-serif; margin: 0; line-height: 1.6; color: #0f172a; background: #f8fafc; }",
    "    main { max-width: 980px; margin: 0 auto; padding: 2rem 1.25rem 3rem; }",
    "    h1, h2 { line-height: 1.2; }",
    "    .cards { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 0.9rem; }",
    "    .card { border: 1px solid #cbd5e1; border-radius: 10px; background: #fff; padding: 1rem; }",
    "    .card a { font-weight: 600; text-decoration: none; }",
    "    .muted { color: #475569; }",
    "    code { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; }",
    "  </style>",
    "</head>",
    "<body>",
    "  <main>",
    "    <h1>Saxon-Forms documentation site</h1>",
    "    <p class=\"muted\">This site is assembled from curated markdown docs, the DocBook implementation guide, and published examples.</p>",
    "    <div class=\"cards\">",
    "      <section class=\"card\">",
    "        <h2>Documentation</h2>",
    "        <p><a href=\"docs/\">Open docs home</a></p>",
    "        <p class=\"muted\">Includes markdown references and the DocBook implementation guide.</p>",
    "      </section>",
    "      <section class=\"card\">",
    "        <h2>Examples</h2>",
    "        <p><a href=\"examples/\">Open examples index</a></p>",
    "        <p class=\"muted\">Interactive pages from <code>examples/</code> are published as part of this site.</p>",
    "      </section>",
    "      <section class=\"card\">",
    "        <h2>Pages compatibility</h2>",
    "        <p><a href=\"examples/PAGES-COMPATIBILITY.html\">Read compatibility notes</a></p>",
    "        <p class=\"muted\">Some submission demos target local endpoint paths and have reduced behavior on static hosting.</p>",
    "      </section>",
    "    </div>",
    "  </main>",
    "</body>",
    "</html>"
  ].join("\n");
}

function buildDocsIndexHtml(markdownDocuments, docbookTitle) {
  const markdownItems = markdownDocuments
    .map((entry) => {
      const displayTitle = entry.title || entry.source;
      const href = `markdown/${toPosixPath(sourceMarkdownToOutputRelativePath(entry.source))}`;
      return `<li><a href="${htmlEscape(href)}">${htmlEscape(displayTitle)}</a> <span class="muted">(${htmlEscape(
        entry.source
      )})</span></li>`;
    })
    .join("\n");

  return [
    "<!doctype html>",
    "<html lang=\"en\">",
    "<head>",
    "  <meta charset=\"utf-8\" />",
    "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />",
    "  <title>Saxon-Forms docs</title>",
    "  <style>",
    "    body { font-family: Inter, Segoe UI, Arial, sans-serif; margin: 0; line-height: 1.6; color: #0f172a; background: #f8fafc; }",
    "    main { max-width: 980px; margin: 0 auto; padding: 2rem 1.25rem 3rem; }",
    "    h1, h2 { line-height: 1.2; }",
    "    .panel { border: 1px solid #cbd5e1; border-radius: 10px; background: #fff; padding: 1rem; margin-bottom: 1rem; }",
    "    .muted { color: #475569; }",
    "    a { text-decoration: none; }",
    "    a:hover { text-decoration: underline; }",
    "  </style>",
    "</head>",
    "<body>",
    "  <main>",
    "    <h1>Documentation</h1>",
    "    <p class=\"muted\"><a href=\"../index.html\">← Site home</a></p>",
    "    <section class=\"panel\">",
    `      <h2>${htmlEscape(docbookTitle)}</h2>`,
    "      <p><a href=\"docbook/index.html\">Open implementation guide</a></p>",
    "    </section>",
    "    <section class=\"panel\">",
    "      <h2>Curated markdown references</h2>",
    "      <ul>",
    markdownItems,
    "      </ul>",
    "    </section>",
    "    <section class=\"panel\">",
    "      <h2>Examples</h2>",
    "      <p><a href=\"../examples/\">Open published examples</a></p>",
    "      <p><a href=\"../examples/PAGES-COMPATIBILITY.html\">GitHub Pages compatibility notes</a></p>",
    "    </section>",
    "  </main>",
    "</body>",
    "</html>"
  ].join("\n");
}

function buildExamplesCompatibilityHtml() {
  return [
    "<!doctype html>",
    "<html lang=\"en\">",
    "<head>",
    "  <meta charset=\"utf-8\" />",
    "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />",
    "  <title>Examples compatibility on GitHub Pages</title>",
    "  <style>",
    "    body { font-family: Inter, Segoe UI, Arial, sans-serif; margin: 0; line-height: 1.6; color: #0f172a; background: #f8fafc; }",
    "    main { max-width: 980px; margin: 0 auto; padding: 2rem 1.25rem 3rem; }",
    "    h1, h2 { line-height: 1.2; }",
    "    .panel { border: 1px solid #cbd5e1; border-radius: 10px; background: #fff; padding: 1rem; margin-bottom: 1rem; }",
    "    code { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; }",
    "  </style>",
    "</head>",
    "<body>",
    "  <main>",
    "    <h1>Examples compatibility on GitHub Pages</h1>",
    "    <p><a href=\"./\">← Examples index</a> · <a href=\"../docs/\">Docs home</a></p>",
    "    <section class=\"panel\">",
    "      <h2>Fully static pages</h2>",
    "      <p>Most rendering examples work on GitHub Pages because required runtime assets are published with the site.</p>",
    "    </section>",
    "    <section class=\"panel\">",
    "      <h2>Endpoint-backed flows</h2>",
    "      <p>Examples that submit to local endpoint paths such as <code>/api/test</code>, <code>/api/echo</code>, and <code>/api/book-submit</code> rely on the local examples server and have reduced behavior on static hosting.</p>",
    "      <p>For full submission behavior, run <code>npm run examples</code> locally.</p>",
    "    </section>",
    "  </main>",
    "</body>",
    "</html>"
  ].join("\n");
}

async function assembleSite({
  siteRoot,
  docsPublicRoot,
  manifest
}) {
  const docsOutputHtmlRoot = path.join(docsPublicRoot, "html");
  const docsOutputAssetsRoot = path.join(docsPublicRoot, "assets");
  const docbookOutputPath = path.resolve(repoRoot, manifest.docbook.html_output);
  const docbookDiagramsRoot = path.join(repoRoot, "docs", "docbook", "diagrams");
  const bpmnRoot = path.join(repoRoot, "docs", "bpmn");
  const ant4docbookCssRoot = path.join(os.homedir(), ".ant4docbook", "V0.10.0", "css");
  const examplesRoot = path.join(repoRoot, "examples");
  const saxonJsRoot = path.join(repoRoot, "Saxon-JS");
  const sefRoot = path.join(repoRoot, "sef");
  const srcRoot = path.join(repoRoot, "src");

  await ensureDirectoryExists(docsOutputHtmlRoot, "Curated markdown docs output");
  await ensureFileExists(docbookOutputPath, "DocBook HTML output");
  await ensureDirectoryExists(examplesRoot, "Examples root");
  await ensureDirectoryExists(saxonJsRoot, "Saxon-JS runtime root");
  await ensureDirectoryExists(sefRoot, "SEF artifact root");
  await ensureDirectoryExists(srcRoot, "XSLT source root");
  await ensureDirectoryExists(docbookDiagramsRoot, "DocBook diagrams root");

  await fs.mkdir(siteRoot, { recursive: true });
  await fs.mkdir(path.join(siteRoot, "docs"), { recursive: true });
  await fs.mkdir(path.join(siteRoot, "examples"), { recursive: true });

  await fs.cp(docsOutputHtmlRoot, path.join(siteRoot, "docs", "markdown"), { recursive: true });
  if (await pathExists(docsOutputAssetsRoot)) {
    await fs.cp(docsOutputAssetsRoot, path.join(siteRoot, "docs", "assets"), { recursive: true });
  }

  await fs.mkdir(path.join(siteRoot, "docs", "docbook"), { recursive: true });
  await fs.copyFile(docbookOutputPath, path.join(siteRoot, "docs", "docbook", "index.html"));
  await fs.cp(docbookDiagramsRoot, path.join(siteRoot, "docs", "diagrams"), { recursive: true });
  await fs.cp(docbookDiagramsRoot, path.join(siteRoot, "docs", "docbook", "diagrams"), {
    recursive: true
  });
  const docbookCssSiteRoot = path.join(siteRoot, "docs", "docbook", "css");
  if (await pathExists(ant4docbookCssRoot)) {
    await fs.cp(ant4docbookCssRoot, docbookCssSiteRoot, { recursive: true });
  } else {
    await fs.mkdir(docbookCssSiteRoot, { recursive: true });
    await fs.writeFile(
      path.join(docbookCssSiteRoot, "jbossorg.css"),
      "/* Fallback stylesheet for static publishing when ant4docbook cache CSS is unavailable. */\n",
      "utf8"
    );
  }
  if (await pathExists(bpmnRoot)) {
    await fs.cp(bpmnRoot, path.join(siteRoot, "docs", "bpmn"), { recursive: true });
    await fs.cp(bpmnRoot, path.join(siteRoot, "bpmn"), { recursive: true });
  }

  await fs.cp(examplesRoot, path.join(siteRoot, "examples"), { recursive: true });
  await fs.cp(saxonJsRoot, path.join(siteRoot, "Saxon-JS"), { recursive: true });
  await fs.cp(sefRoot, path.join(siteRoot, "sef"), { recursive: true });
  await fs.cp(srcRoot, path.join(siteRoot, "src"), { recursive: true });

  await fs.writeFile(path.join(siteRoot, ".nojekyll"), "", "utf8");
  await fs.writeFile(path.join(siteRoot, "index.html"), buildSiteIndexHtml(), "utf8");
  await fs.writeFile(
    path.join(siteRoot, "docs", "index.html"),
    buildDocsIndexHtml(
      manifest.markdown_documents,
      manifest.docbook.title || "DocBook implementation guide"
    ),
    "utf8"
  );
  await fs.writeFile(
    path.join(siteRoot, "examples", "PAGES-COMPATIBILITY.html"),
    buildExamplesCompatibilityHtml(),
    "utf8"
  );
}

async function main() {
  const config = parseArgs(process.argv.slice(2));
  if (config.help) {
    printHelp();
    return;
  }

  const manifest = await readManifest(config.manifestPath);
  const markdownSources = manifest.markdown_documents.map((entry) => entry.source);

  if (config.clean && (await pathExists(config.siteRoot))) {
    console.log(`[build-site] Removing previous site output at ${config.siteRoot}`);
    await fs.rm(config.siteRoot, { recursive: true, force: true });
  }
  if (config.clean && (await pathExists(config.docsPublicRoot))) {
    console.log(`[build-site] Removing previous curated docs output at ${config.docsPublicRoot}`);
    await fs.rm(config.docsPublicRoot, { recursive: true, force: true });
  }

  if (config.buildSef) {
    await runCommand("npm", ["run", "build:sef"], "Building Saxon-Forms SEF artifacts");
  }
  if (config.compileExamples) {
    await runCommand("npm", ["run", "examples:compile"], "Compiling stylesheet-driven examples");
  }

  await runCommand(
    process.execPath,
    [
      path.join("scripts", "build-docs.mjs"),
      "--html-only",
      "--out",
      config.docsPublicRoot,
      ...markdownSources
    ],
    "Building curated markdown documentation set"
  );

  if (config.validateDocbook) {
    await runCommand("npm", ["run", "docs:docbook:validate"], "Validating DocBook sources");
  }
  if (config.buildDocbook) {
    await runCommand(
      process.execPath,
      [path.join("scripts", "run-docbook-build.mjs"), "--format=html"],
      "Building DocBook HTML output"
    );
  }

  await assembleSite({
    siteRoot: config.siteRoot,
    docsPublicRoot: config.docsPublicRoot,
    manifest
  });

  console.log(
    JSON.stringify(
      {
        event: "site-build-complete",
        ts: new Date().toISOString(),
        site_root: toPosixPath(path.relative(repoRoot, config.siteRoot)),
        docs_public_root: toPosixPath(path.relative(repoRoot, config.docsPublicRoot)),
        markdown_count: manifest.markdown_documents.length,
        docbook_html: manifest.docbook.html_output
      },
      null,
      2
    )
  );
}

main().catch((error) => {
  console.error(error instanceof Error ? error.stack ?? error.message : String(error));
  process.exit(1);
});
