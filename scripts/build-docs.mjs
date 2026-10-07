#!/usr/bin/env node
import fs from "node:fs";
import fsp from "node:fs/promises";
import path from "node:path";
import { execFile } from "node:child_process";
import { createRequire } from "node:module";
import { fileURLToPath, pathToFileURL } from "node:url";
import { promisify } from "node:util";
import MarkdownIt from "markdown-it";
import { chromium } from "playwright";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRootDefault = path.resolve(__dirname, "..");

const IGNORED_DIR_NAMES = new Set([
  ".git",
  "node_modules",
  "playwright-report",
  "test-results"
]);
const XSL_FILE_PATTERN = /\.(xsl|xslt)$/i;
const XD_NAMESPACE_PATTERN = /xmlns:xd\s*=\s*["']http:\/\/www\.oxygenxml\.com\/ns\/doc\/xsl["']/i;
const XD_DOC_PATTERN = /<xd:doc\b/i;
const execFileAsync = promisify(execFile);

function toPosixPath(inputPath) {
  return inputPath.split(path.sep).join("/");
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function parseArgs(argv) {
  const config = {
    root: repoRootDefault,
    out: path.join(repoRootDefault, "builds", "docs"),
    clean: true,
    renderHtml: true,
    renderPdf: true,
    files: []
  };

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--root") {
      const value = argv[++i];
      if (!value) throw new Error("Missing value for --root");
      config.root = path.resolve(value);
      continue;
    }
    if (arg === "--out") {
      const value = argv[++i];
      if (!value) throw new Error("Missing value for --out");
      config.out = path.resolve(value);
      continue;
    }
    if (arg === "--no-clean") {
      config.clean = false;
      continue;
    }
    if (arg === "--html-only") {
      config.renderPdf = false;
      continue;
    }
    if (arg === "--pdf-only") {
      config.renderHtml = false;
      config.renderPdf = true;
      continue;
    }
    if (arg === "--help" || arg === "-h") {
      console.log(
        [
          "Usage: node scripts/build-docs.mjs [options] [source-file ...]",
          "",
          "Renders markdown files and XSL xd:doc sections to HTML and PDF.",
          "",
          "Options:",
          "  --root <dir>      Repository root to scan (default: repo root)",
          "  --out <dir>       Output directory (default: builds/docs)",
          "  --no-clean        Do not remove old output before building",
          "  --html-only       Generate HTML only",
          "  --pdf-only        Generate PDF only (HTML still produced as intermediate source)",
          "  --help, -h        Show this help"
        ].join("\n")
      );
      process.exit(0);
    }
    if (arg.startsWith("-")) {
      throw new Error(`Unknown option: ${arg}`);
    }
    config.files.push(arg);
  }

  return config;
}

function resolveMermaidAssetPath() {
  const require = createRequire(import.meta.url);
  const candidates = [
    "mermaid/dist/mermaid.min.js",
    "mermaid/dist/mermaid.js"
  ];
  for (const candidate of candidates) {
    try {
      return require.resolve(candidate);
    } catch {
      // continue
    }
  }
  return null;
}

async function discoverMarkdownFiles(rootDir, outDir, explicitFiles) {
  const rootResolved = path.resolve(rootDir);
  const outResolved = path.resolve(outDir);

  if (explicitFiles.length > 0) {
    return explicitFiles
      .map((inputPath) => path.resolve(rootResolved, inputPath))
      .filter((fullPath) => /\.md$/i.test(path.basename(fullPath)));
  }

  const results = [];

  async function walk(currentDir) {
    const entries = await fsp.readdir(currentDir, { withFileTypes: true });
    for (const entry of entries) {
      const fullPath = path.join(currentDir, entry.name);

      if (entry.isDirectory()) {
        if (IGNORED_DIR_NAMES.has(entry.name)) continue;
        if (path.resolve(fullPath).startsWith(outResolved)) continue;
        await walk(fullPath);
        continue;
      }

      if (entry.isFile() && /\.md$/i.test(entry.name)) {
        results.push(fullPath);
      }
    }
  }

  await walk(rootResolved);
  results.sort((a, b) => a.localeCompare(b));
  return results;
}

async function discoverXdStylesheetFiles(rootDir, outDir, explicitFiles) {
  const rootResolved = path.resolve(rootDir);
  const outResolved = path.resolve(outDir);
  const candidates = [];

  if (explicitFiles.length > 0) {
    for (const inputPath of explicitFiles) {
      const fullPath = path.resolve(rootResolved, inputPath);
      if (XSL_FILE_PATTERN.test(path.basename(fullPath))) {
        candidates.push(fullPath);
      }
    }
  } else {
    async function walk(currentDir) {
      const entries = await fsp.readdir(currentDir, { withFileTypes: true });
      for (const entry of entries) {
        const fullPath = path.join(currentDir, entry.name);

        if (entry.isDirectory()) {
          if (IGNORED_DIR_NAMES.has(entry.name)) continue;
          if (path.resolve(fullPath).startsWith(outResolved)) continue;
          await walk(fullPath);
          continue;
        }

        if (entry.isFile() && XSL_FILE_PATTERN.test(entry.name)) {
          candidates.push(fullPath);
        }
      }
    }

    await walk(rootResolved);
  }

  const xdFiles = [];
  for (const filePath of candidates) {
    const content = await fsp.readFile(filePath, "utf8");
    if (XD_NAMESPACE_PATTERN.test(content) && XD_DOC_PATTERN.test(content)) {
      xdFiles.push(filePath);
    }
  }
  xdFiles.sort((a, b) => a.localeCompare(b));
  return xdFiles;
}


async function renderXdDocsBodyHtml({ rootDir, sourcePath, relativeSourcePath }) {
  const extractorStylesheetPath = path.join(__dirname, "xd-doc-extract.xsl");
  const args = [
    "xslt3",
    `-xsl:${extractorStylesheetPath}`,
    `-s:${sourcePath}`,
    `source-rel-path=${relativeSourcePath}`
  ];

  try {
    const { stdout } = await execFileAsync("npx", args, {
      cwd: rootDir,
      shell: true,
      maxBuffer: 10 * 1024 * 1024
    });
    const html = (stdout || "").trim();
    if (!html) {
      throw new Error(`No xd:doc HTML was produced for ${relativeSourcePath}.`);
    }
    return html;
  } catch (error) {
    if (error instanceof Error) {
      throw new Error(
        `Failed to extract xd:doc HTML for ${relativeSourcePath}: ${error.message}`
      );
    }
    throw error;
  }
}

function createMarkdownRenderer() {
  const markdown = new MarkdownIt({
    html: true,
    linkify: true,
    typographer: true
  });

  const defaultFenceRenderer =
    markdown.renderer.rules.fence ??
    ((tokens, index, options, _env, self) => self.renderToken(tokens, index, options));

  markdown.renderer.rules.fence = (tokens, index, options, env, self) => {
    const token = tokens[index];
    const fenceInfo = (token.info || "").trim().split(/\s+/)[0].toLowerCase();
    if (fenceInfo === "mermaid") {
      return `<pre class="mermaid">${markdown.utils.escapeHtml(token.content)}</pre>\n`;
    }
    return defaultFenceRenderer(tokens, index, options, env, self);
  };

  return markdown;
}

function rewriteMarkdownLinksInHtml(html) {
  return html.replace(
    /href="([^"]+?)\.md((?:[#?][^"]*)?)"/gi,
    (_match, pathPrefix, suffix = "") => `href="${pathPrefix}.html${suffix}"`
  );
}

function deriveTitle(markdownSource, fallbackName) {
  const headingMatch = markdownSource.match(/^\s*#\s+(.+)\s*$/m);
  if (!headingMatch) return fallbackName;
  return headingMatch[1].trim();
}

function buildPageHtml({
  title,
  relativeSourcePath,
  bodyHtml,
  mermaidScriptHref
}) {
  const mermaidLoadScript = mermaidScriptHref
    ? [
        `<script defer src="${escapeHtml(mermaidScriptHref)}"></script>`,
        "<script>",
        "window.addEventListener('DOMContentLoaded', async () => {",
        "  try {",
        "    if (window.mermaid) {",
        "      mermaid.initialize({ startOnLoad: false, securityLevel: 'loose', theme: 'default' });",
        "      const nodes = document.querySelectorAll('pre.mermaid');",
        "      if (nodes.length) {",
        "        await mermaid.run({ nodes });",
        "      }",
        "    }",
        "  } catch (error) {",
        "    console.error('[build-docs] Mermaid render failed', error);",
        "  }",
        "  document.documentElement.setAttribute('data-render-ready', 'true');",
        "});",
        "</script>"
      ].join("\n")
    : [
        "<script>",
        "window.addEventListener('DOMContentLoaded', () => {",
        "  document.documentElement.setAttribute('data-render-ready', 'true');",
        "});",
        "</script>"
      ].join("\n");

  return [
    "<!doctype html>",
    "<html lang=\"en\">",
    "<head>",
    "  <meta charset=\"utf-8\" />",
    "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />",
    `  <title>${escapeHtml(title)}</title>`,
    "  <style>",
    "    :root { color-scheme: light dark; }",
    "    body { font-family: Inter, Segoe UI, Arial, sans-serif; margin: 0; line-height: 1.6; }",
    "    header { padding: 1rem 1.5rem; border-bottom: 1px solid #9995; }",
    "    main { max-width: 960px; margin: 0 auto; padding: 1.5rem; }",
    "    h1, h2, h3, h4, h5, h6 { line-height: 1.25; }",
    "    pre { overflow-x: auto; padding: 0.9rem; border-radius: 8px; border: 1px solid #9994; }",
    "    code { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; }",
    "    pre.mermaid { background: transparent; border: none; padding: 0; }",
    "    blockquote { margin-left: 0; padding-left: 1rem; border-left: 3px solid #9996; }",
    "    img { max-width: 100%; }",
    "    a { text-decoration: none; }",
    "    a:hover { text-decoration: underline; }",
    "    @media print {",
    "      :root { color-scheme: only light; }",
    "      body { background: #fff; color: #111; }",
    "      a { color: #1a0dab; text-decoration: underline; }",
    "    }",
    "  </style>",
    "</head>",
    "<body>",
    "  <header>",
    `    <strong>${escapeHtml(title)}</strong><br/>`,
    `    <small>Source: ${escapeHtml(relativeSourcePath)}</small>`,
    "  </header>",
    "  <main>",
    bodyHtml,
    "  </main>",
    mermaidLoadScript,
    "</body>",
    "</html>"
  ].join("\n");
}

async function ensureCleanOutput(outDir, clean) {
  if (clean && fs.existsSync(outDir)) {
    await fsp.rm(outDir, { recursive: true, force: true });
  }
  await fsp.mkdir(outDir, { recursive: true });
}

async function writeIndexFile(outDir, buildEntries, renderPdf) {
  const listItems = buildEntries
    .map((entry) => {
      const htmlHref = toPosixPath(path.relative(outDir, entry.htmlPath));
      const links = [`  — <a href="${escapeHtml(htmlHref)}">HTML</a>`];
      if (renderPdf) {
        const pdfHref = toPosixPath(path.relative(outDir, entry.pdfPath));
        links.push(`  — <a href="${escapeHtml(pdfHref)}">PDF</a>`);
      }
      return [
        "<li>",
        `  <code>${escapeHtml(entry.relativeSourcePath)}</code>`,
        ...links,
        "</li>"
      ].join("\n");
    })
    .join("\n");

  const indexHtml = [
    "<!doctype html>",
    "<html lang=\"en\">",
    "<head>",
    "  <meta charset=\"utf-8\" />",
    "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />",
    "  <title>Documentation Build Index</title>",
    "  <style>",
    "    body { font-family: Inter, Segoe UI, Arial, sans-serif; margin: 2rem; line-height: 1.6; }",
    "    code { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; }",
    "  </style>",
    "</head>",
    "<body>",
    "  <h1>Documentation Build Index</h1>",
    "  <ul>",
    listItems,
    "  </ul>",
    "</body>",
    "</html>"
  ].join("\n");

  await fsp.writeFile(path.join(outDir, "index.html"), indexHtml, "utf8");
}

async function main() {
  const config = parseArgs(process.argv.slice(2));
  const rootDir = path.resolve(config.root);
  const outDir = path.resolve(config.out);
  const htmlRoot = path.join(outDir, "html");
  const pdfRoot = path.join(outDir, "pdf");
  const assetsRoot = path.join(outDir, "assets");

  await ensureCleanOutput(outDir, config.clean);
  await fsp.mkdir(htmlRoot, { recursive: true });
  await fsp.mkdir(pdfRoot, { recursive: true });
  await fsp.mkdir(assetsRoot, { recursive: true });

  const markdownFiles = await discoverMarkdownFiles(rootDir, outDir, config.files);
  const xdStylesheetFiles = await discoverXdStylesheetFiles(rootDir, outDir, config.files);
  if (markdownFiles.length === 0 && xdStylesheetFiles.length === 0) {
    throw new Error("No markdown or xd-enabled XSL files found to render.");
  }

  const mermaidAssetInput = resolveMermaidAssetPath();
  const mermaidAssetOutput = path.join(assetsRoot, "mermaid.min.js");
  const mermaidAvailable = Boolean(mermaidAssetInput);
  if (mermaidAssetInput) {
    await fsp.copyFile(mermaidAssetInput, mermaidAssetOutput);
  }

  const markdown = createMarkdownRenderer();
  const buildEntries = [];

  for (const sourcePath of markdownFiles) {
    const relativeSourcePath = toPosixPath(path.relative(rootDir, sourcePath));
    const outputRelativeBase = relativeSourcePath.replace(/\.md$/i, "");
    const htmlPath = path.join(htmlRoot, `${outputRelativeBase}.html`);
    const pdfPath = path.join(pdfRoot, `${outputRelativeBase}.pdf`);

    await fsp.mkdir(path.dirname(htmlPath), { recursive: true });
    await fsp.mkdir(path.dirname(pdfPath), { recursive: true });

    const markdownSource = await fsp.readFile(sourcePath, "utf8");
    const title = deriveTitle(markdownSource, path.basename(outputRelativeBase));
    const bodyHtmlRaw = markdown.render(markdownSource);
    const bodyHtml = rewriteMarkdownLinksInHtml(bodyHtmlRaw);

    const mermaidScriptHref = mermaidAvailable
      ? toPosixPath(path.relative(path.dirname(htmlPath), mermaidAssetOutput))
      : null;

    const pageHtml = buildPageHtml({
      title,
      relativeSourcePath,
      bodyHtml,
      mermaidScriptHref
    });

    await fsp.writeFile(htmlPath, pageHtml, "utf8");
    buildEntries.push({
      kind: "markdown",
      sourcePath,
      relativeSourcePath,
      htmlPath,
      pdfPath
    });
  }

  for (const sourcePath of xdStylesheetFiles) {
    const sourceRelativePath = toPosixPath(path.relative(rootDir, sourcePath));
    const sourceLabel = `${sourceRelativePath} (xd:doc)`;
    const outputRelativeBase = toPosixPath(
      path.join("xd", sourceRelativePath.replace(XSL_FILE_PATTERN, ""))
    );
    const htmlPath = path.join(htmlRoot, `${outputRelativeBase}.html`);
    const pdfPath = path.join(pdfRoot, `${outputRelativeBase}.pdf`);

    await fsp.mkdir(path.dirname(htmlPath), { recursive: true });
    await fsp.mkdir(path.dirname(pdfPath), { recursive: true });

    const bodyHtml = await renderXdDocsBodyHtml({
      rootDir,
      sourcePath,
      relativeSourcePath: sourceRelativePath
    });
    const pageHtml = buildPageHtml({
      title: `XD docs: ${sourceRelativePath}`,
      relativeSourcePath: sourceLabel,
      bodyHtml,
      mermaidScriptHref: null
    });

    await fsp.writeFile(htmlPath, pageHtml, "utf8");
    buildEntries.push({
      kind: "xd",
      sourcePath,
      relativeSourcePath: sourceLabel,
      htmlPath,
      pdfPath
    });
  }

  const browser = config.renderPdf ? await chromium.launch({ headless: true }) : null;
  const page = browser ? await browser.newPage() : null;

  try {
    for (const entry of buildEntries) {
      if (config.renderPdf) {
        const htmlFileUrl = pathToFileURL(entry.htmlPath).href;
        await page.goto(htmlFileUrl, { waitUntil: "load" });
        await page.waitForSelector("html[data-render-ready='true']", { timeout: 15000 });
        await page.pdf({
          path: entry.pdfPath,
          format: "A4",
          printBackground: true,
          margin: {
            top: "14mm",
            right: "12mm",
            bottom: "14mm",
            left: "12mm"
          }
        });
      }
      console.log(
        JSON.stringify({
          event: "docs-file-rendered",
          kind: entry.kind,
          source: entry.relativeSourcePath,
          html: toPosixPath(path.relative(rootDir, entry.htmlPath)),
          ...(config.renderPdf
            ? { pdf: toPosixPath(path.relative(rootDir, entry.pdfPath)) }
            : {})
        })
      );
    }
  } finally {
    if (page) await page.close();
    if (browser) await browser.close();
  }

  await writeIndexFile(outDir, buildEntries, config.renderPdf);

  console.log(
    JSON.stringify({
      event: "docs-build-complete",
      root: toPosixPath(rootDir),
      output: toPosixPath(outDir),
      file_count: buildEntries.length,
      markdown_file_count: markdownFiles.length,
      xd_source_count: xdStylesheetFiles.length,
      mermaid_enabled: mermaidAvailable,
      html_enabled: config.renderHtml,
      pdf_enabled: config.renderPdf
    })
  );
}

main().catch((error) => {
  console.error(error instanceof Error ? error.stack ?? error.message : String(error));
  process.exit(1);
});
