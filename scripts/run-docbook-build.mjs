#!/usr/bin/env node
import { spawn } from "node:child_process";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import fs from "node:fs/promises";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");
const defaultBuildFile = path.join(repoRoot, "docs", "docbook", "build.xml");
const defaultAnt4DocbookHome = path.join(repoRoot, "ant4docbook-0.10.0");
const defaultAnt4DocbookCacheHome = path.join(os.homedir(), ".ant4docbook");
const DOCBOOK_XSL_VERSION = "docbook-xsl-2020-06-03";
const DOCBOOK_XSL_SNAPSHOT = "docbook-xsl-snapshot";
const ANT4DOCBOOK_RUNTIME_CACHE_VERSION = "V0.10.0";

const TARGET_BY_FORMAT = {
  all: "docbook-all",
  html: "docbook-html",
  pdf: "docbook-pdf",
  validate: "docbook-validate"
};
function resolvePathArgument(rawValue, baseDir = repoRoot) {
  const trimmed = String(rawValue ?? "").trim();
  if (!trimmed) {
    return trimmed;
  }
  return path.isAbsolute(trimmed) ? trimmed : path.resolve(baseDir, trimmed);
}

/**
 * Resolve an executable reference. Bare command names (e.g. "ant") stay on PATH.
 * Path-like values (slashes, .bat/.cmd/.exe) become absolute under baseDir so Windows
 * cmd.exe does not mis-parse leading "./" as the "." builtin.
 */
function resolveExecutable(rawValue, baseDir = repoRoot) {
  const trimmed = String(rawValue ?? "").trim();
  if (!trimmed) {
    return trimmed;
  }
  const looksLikePath =
    path.isAbsolute(trimmed) ||
    trimmed.includes("/") ||
    trimmed.includes("\\") ||
    /\.(bat|cmd|exe)$/i.test(trimmed);
  if (!looksLikePath) {
    return trimmed;
  }
  return resolvePathArgument(trimmed, baseDir);
}

/** Quote one argument for cmd.exe /c when the full command line is a single string. */
function quoteForCmd(arg) {
  const value = String(arg);
  if (value.length === 0) {
    return '""';
  }
  const needsQuotes = /[\s"&<>|()^%]/.test(value);
  if (!needsQuotes) {
    return value;
  }
  return `"${value.replace(/"/g, '""')}"`;
}

/**
 * Spawn a process. On Windows, always run through cmd.exe with a single /c string
 * so .bat/.cmd paths and arguments with spaces are handled correctly.
 */
function spawnProcess(command, args, options = {}) {
  const isWindows = process.platform === "win32";
  if (!isWindows) {
    return spawn(command, args, options);
  }
  const commandLine = [command, ...args].map(quoteForCmd).join(" ");
  return spawn("cmd.exe", ["/d", "/s", "/c", commandLine], options);
}

function parseArgs(argv) {
  const config = {
    format: "all",
    antBin: resolveExecutable(process.env.ANT_BIN || "ant"),
    buildFile: defaultBuildFile,
    ant4docbookHome: defaultAnt4DocbookHome,
    ant4docbookCacheHome: resolvePathArgument(
      process.env.ANT4DOCBOOK_CACHE_HOME || defaultAnt4DocbookCacheHome
    )
  };

  for (const arg of argv) {
    if (arg === "--help" || arg === "-h") {
      config.help = true;
      continue;
    }
    if (arg.startsWith("--format=")) {
      config.format = arg.slice("--format=".length).trim().toLowerCase();
      continue;
    }
    if (arg.startsWith("--ant-bin=")) {
      config.antBin = resolveExecutable(arg.slice("--ant-bin=".length).trim());
      continue;
    }
    if (arg.startsWith("--build-file=")) {
      config.buildFile = resolvePathArgument(arg.slice("--build-file=".length).trim());
      continue;
    }
    if (arg.startsWith("--ant4docbook-home=")) {
      config.ant4docbookHome = resolvePathArgument(arg.slice("--ant4docbook-home=".length).trim());
      continue;
    }
    if (arg.startsWith("--ant4docbook-cache-home=")) {
      config.ant4docbookCacheHome = resolvePathArgument(
        arg.slice("--ant4docbook-cache-home=".length).trim()
      );
      continue;
    }
    throw new Error(`Unknown option: ${arg}`);
  }

  if (!TARGET_BY_FORMAT[config.format]) {
    throw new Error(
      `Invalid --format value "${config.format}". Expected one of: ${Object.keys(TARGET_BY_FORMAT).join(", ")}.`
    );
  }

  return config;
}

async function commandExists(commandName) {
  if (!commandName) return false;
  const resolved = resolveExecutable(commandName);
  if (resolved.includes(path.sep) || resolved.includes("/") || resolved.includes("\\")) {
    try {
      await fs.access(resolved);
      return true;
    } catch {
      return false;
    }
  }
  const isWindows = process.platform === "win32";
  const lookupCommand = isWindows ? "where" : "which";
  const lookupArgs = [resolved];
  try {
    await new Promise((resolve, reject) => {
      const child = spawnProcess(lookupCommand, lookupArgs, {
        cwd: repoRoot,
        stdio: "ignore"
      });
      child.on("error", reject);
      child.on("exit", (code) => {
        if ((code ?? 1) === 0) resolve();
        else reject(new Error(`${commandName} not found`));
      });
    });
    return true;
  } catch {
    return false;
  }
}

async function pathExists(candidatePath) {
  try {
    await fs.access(candidatePath);
    return true;
  } catch {
    return false;
  }
}
function printHelp() {
  console.log(
    [
      "Usage: node scripts/run-docbook-build.mjs [options]",
      "",
      "Options:",
      "  --format=<all|html|pdf|validate>   Build target to run (default: all)",
      "  --ant-bin=<path|command>           Ant executable (default: ANT_BIN env or 'ant')",
      "  --build-file=<path>                Ant build file path (default: docs/docbook/build.xml)",
      "  --ant4docbook-home=<path>          ant4docbook distribution directory",
      "  --ant4docbook-cache-home=<path>    ant4docbook cache home (default: ANT4DOCBOOK_CACHE_HOME or ~/.ant4docbook)",
      "  --help, -h                         Show this help"
    ].join("\n")
  );
}
async function createCompatibilityNestedPath(versionRoot) {
  const nestedRoot = path.join(versionRoot, DOCBOOK_XSL_VERSION);
  if (process.platform === "win32") {
    await fs.symlink(versionRoot, nestedRoot, "junction");
    return;
  }
  await fs.symlink(".", nestedRoot, "dir");
}

async function cloneDocbookTree(sourceRoot, destinationRoot) {
  await fs.mkdir(destinationRoot, { recursive: true });
  const entries = await fs.readdir(sourceRoot, { withFileTypes: true });
  for (const entry of entries) {
    if (entry.name === DOCBOOK_XSL_VERSION) {
      continue;
    }
    await fs.cp(path.join(sourceRoot, entry.name), path.join(destinationRoot, entry.name), {
      recursive: true
    });
  }
}


async function runCommand(command, args, options = {}) {
  const cwd = options.cwd || repoRoot;
  const stdio = options.stdio || "ignore";
  const resolvedCommand = resolveExecutable(command);

  await new Promise((resolve, reject) => {
    const child = spawnProcess(resolvedCommand, args, {
      cwd,
      stdio
    });
    child.on("error", reject);
    child.on("exit", (code, signal) => {
      if (signal) {
        reject(new Error(`Command terminated by signal ${signal}: ${resolvedCommand} ${args.join(" ")}`));
        return;
      }
      if ((code ?? 1) !== 0) {
        reject(new Error(`Command failed (${code}): ${resolvedCommand} ${args.join(" ")}`));
        return;
      }
      resolve();
    });
  });
}
async function ensureDocbookStylesheetCompatibility(config) {
  const cacheHome = config.ant4docbookCacheHome;
  const versionRoot = path.join(cacheHome, DOCBOOK_XSL_VERSION);
  const snapshotRoot = path.join(cacheHome, DOCBOOK_XSL_SNAPSHOT);
  const versionStylesheet = path.join(versionRoot, "xhtml", "docbook.xsl");
  const snapshotStylesheet = path.join(snapshotRoot, "xhtml", "docbook.xsl");
  const nestedRoot = path.join(versionRoot, DOCBOOK_XSL_VERSION);
  const nestedStylesheet = path.join(nestedRoot, "xhtml", "docbook.xsl");

  await fs.mkdir(cacheHome, { recursive: true });

  if (!(await pathExists(versionStylesheet)) && (await pathExists(snapshotStylesheet))) {
    console.log(
      JSON.stringify({
        event: "docbook-xsl-cache-promote-snapshot",
        ts: new Date().toISOString(),
        source: snapshotRoot,
        destination: versionRoot
      })
    );
    await fs.rm(versionRoot, { recursive: true, force: true });
    await fs.cp(snapshotRoot, versionRoot, { recursive: true });
  }

  if (!(await pathExists(versionStylesheet))) {
    return;
  }

  if (!(await pathExists(nestedStylesheet))) {
    await fs.rm(nestedRoot, { recursive: true, force: true });
    try {
      await createCompatibilityNestedPath(versionRoot);
    } catch (error) {
      console.log(
        JSON.stringify({
          event: "docbook-xsl-cache-compat-fallback-copy",
          ts: new Date().toISOString(),
          reason: error instanceof Error ? error.message : String(error)
        })
      );
      await cloneDocbookTree(versionRoot, nestedRoot);
    }
  }

  if (!(await pathExists(nestedStylesheet))) {
    throw new Error(
      `DocBook stylesheet cache is present but incompatible at ${versionRoot}. Missing ${nestedStylesheet}.`
    );
  }
}

async function ensureAnt4DocbookRuntimeCache(config) {
  const cacheHome = config.ant4docbookCacheHome;
  const runtimeRoot = path.join(cacheHome, ANT4DOCBOOK_RUNTIME_CACHE_VERSION);
  const runtimeStylesheet = path.join(runtimeRoot, "css", "jbossorg.css");
  if (await pathExists(runtimeStylesheet)) {
    return;
  }

  const ant4docbookJar = path.join(config.ant4docbookHome, "ant4docbook-0.10.0.jar");
  if (!(await pathExists(ant4docbookJar))) {
    return;
  }

  const jarExists = await commandExists("jar");
  if (!jarExists) {
    return;
  }

  await fs.mkdir(runtimeRoot, { recursive: true });
  await runCommand("jar", ["xf", ant4docbookJar, "css/jbossorg.css"], { cwd: runtimeRoot });

  if (!(await pathExists(runtimeStylesheet))) {
    throw new Error(
      `Failed to provision ant4docbook runtime cache at ${runtimeRoot}. Missing ${runtimeStylesheet}.`
    );
  }
}

/**
 * ant4docbook-0.10.0.jar ships Apache FOP Batik SVG classes, but its fat-jar
 * META-INF/services registry omits PreloaderSVG / ImageLoaderFactorySVG.
 * Without those SPI entries FOP reports "No ImagePreloader found" for every
 * diagram SVG. Drop a tiny overlay jar onto the Ant task classpath.
 */
async function ensureFopBatikSvgSpiOverlay(config) {
  const thirdPartyDir = path.join(config.ant4docbookHome, "3rd-party");
  const overlayJar = path.join(thirdPartyDir, "fop-batik-svg-spi.jar");
  const markerPath = path.join(thirdPartyDir, ".fop-batik-svg-spi-version");
  const overlayVersion = "1";

  let currentVersion = "";
  try {
    currentVersion = (await fs.readFile(markerPath, "utf8")).trim();
  } catch {
    currentVersion = "";
  }

  if ((await pathExists(overlayJar)) && currentVersion === overlayVersion) {
    return;
  }

  await fs.mkdir(thirdPartyDir, { recursive: true });

  const stagingRoot = await fs.mkdtemp(path.join(os.tmpdir(), "fop-batik-svg-spi-"));
  try {
    const serviceEntries = {
      "org.apache.xmlgraphics.image.loader.spi.ImagePreloader": [
        "org.apache.fop.image.loader.batik.PreloaderSVG",
        "org.apache.fop.image.loader.batik.PreloaderWMF"
      ],
      "org.apache.xmlgraphics.image.loader.spi.ImageLoaderFactory": [
        "org.apache.fop.image.loader.batik.ImageLoaderFactorySVG",
        "org.apache.fop.image.loader.batik.ImageLoaderFactoryWMF"
      ],
      "org.apache.xmlgraphics.image.loader.spi.ImageConverter": [
        "org.apache.fop.image.loader.batik.ImageConverterSVG2G2D",
        "org.apache.fop.image.loader.batik.ImageConverterG2D2SVG",
        "org.apache.fop.image.loader.batik.ImageConverterWMF2G2D"
      ]
    };

    const servicesDir = path.join(stagingRoot, "META-INF", "services");
    await fs.mkdir(servicesDir, { recursive: true });
    for (const [serviceName, implementations] of Object.entries(serviceEntries)) {
      await fs.writeFile(
        path.join(servicesDir, serviceName),
        `${implementations.join("\n")}\n`,
        "utf8"
      );
    }
    await fs.writeFile(
      path.join(stagingRoot, "META-INF", "README-fop-batik-svg-spi.txt"),
      [
        "SPI overlay for Apache FOP Batik SVG/WMF image support.",
        "Registers PreloaderSVG and related factories that ship inside",
        "ant4docbook-0.10.0.jar but are missing from its META-INF/services.",
        ""
      ].join("\n"),
      "utf8"
    );

    const jarExists = await commandExists("jar");
    if (jarExists) {
      await runCommand("jar", ["cf", overlayJar, "-C", stagingRoot, "."], { cwd: repoRoot });
    } else {
      // Fallback without the jar CLI: write a minimal zip via Python if available.
      const pythonCandidates = process.platform === "win32" ? ["py", "python", "python3"] : ["python3", "python"];
      let wrote = false;
      for (const pythonBin of pythonCandidates) {
        if (!(await commandExists(pythonBin))) {
          continue;
        }
        const pyArgs =
          pythonBin === "py"
            ? [
                "-3",
                "-c",
                "import pathlib,sys,zipfile; root=pathlib.Path(sys.argv[1]); out=pathlib.Path(sys.argv[2]); " +
                  "zf=zipfile.ZipFile(out,'w',compression=zipfile.ZIP_DEFLATED); " +
                  "[zf.write(p, p.relative_to(root).as_posix()) for p in root.rglob('*') if p.is_file()]; zf.close()",
                stagingRoot,
                overlayJar
              ]
            : [
                "-c",
                "import pathlib,sys,zipfile; root=pathlib.Path(sys.argv[1]); out=pathlib.Path(sys.argv[2]); " +
                  "zf=zipfile.ZipFile(out,'w',compression=zipfile.ZIP_DEFLATED); " +
                  "[zf.write(p, p.relative_to(root).as_posix()) for p in root.rglob('*') if p.is_file()]; zf.close()",
                stagingRoot,
                overlayJar
              ];
        try {
          await runCommand(pythonBin, pyArgs, { cwd: repoRoot });
          wrote = true;
          break;
        } catch {
          // try next interpreter
        }
      }
      if (!wrote) {
        throw new Error(
          `Unable to provision ${overlayJar}: neither 'jar' nor a working Python interpreter is available.`
        );
      }
    }

    if (!(await pathExists(overlayJar))) {
      throw new Error(`Failed to provision FOP Batik SVG SPI overlay at ${overlayJar}.`);
    }

    await fs.writeFile(markerPath, `${overlayVersion}\n`, "utf8");
    console.log(
      JSON.stringify({
        event: "fop-batik-svg-spi-overlay-ready",
        ts: new Date().toISOString(),
        overlay_jar: overlayJar,
        version: overlayVersion
      })
    );
  } finally {
    await fs.rm(stagingRoot, { recursive: true, force: true });
  }
}

async function runAnt(config) {
  const target = TARGET_BY_FORMAT[config.format];
  const antArgs = [
    "-f",
    config.buildFile,
    `-Dant4docbook.home=${config.ant4docbookHome}`,
    target
  ];

  const antBin = resolveExecutable(config.antBin);

  console.log(
    JSON.stringify({
      event: "docbook-build-start",
      ts: new Date().toISOString(),
      ant_bin: antBin,
      build_file: config.buildFile,
      ant4docbook_home: config.ant4docbookHome,
      ant4docbook_cache_home: config.ant4docbookCacheHome,
      target
    })
  );

  await new Promise((resolve, reject) => {
    const child = spawnProcess(antBin, antArgs, {
      cwd: repoRoot,
      stdio: "inherit"
    });

    child.on("error", reject);
    child.on("exit", (code, signal) => {
      if (signal) {
        reject(new Error(`Ant process terminated with signal ${signal}`));
        return;
      }
      if ((code ?? 1) !== 0) {
        reject(new Error(`Ant process failed with exit code ${code}`));
        return;
      }
      resolve();
    });
  });

  console.log(
    JSON.stringify({
      event: "docbook-build-complete",
      ts: new Date().toISOString(),
      target
    })
  );
}

async function main() {
  const config = parseArgs(process.argv.slice(2));
  if (config.help) {
    printHelp();
    return;
  }
  const antExists = await commandExists(config.antBin);
  if (!antExists) {
    throw new Error(
      `Ant executable not found: ${config.antBin}. Install Apache Ant and ensure it is on PATH, or pass --ant-bin=<path>.`
    );
  }
  await ensureDocbookStylesheetCompatibility(config);
  await ensureAnt4DocbookRuntimeCache(config);
  await ensureFopBatikSvgSpiOverlay(config);
  await runAnt(config);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
