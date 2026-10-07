import fs from "node:fs";
import path from "node:path";

export function getTestPaths(repoRoot) {
  const runtimeRoot = path.join(repoRoot, "tests", "runtime");
  const fixturesExternalRoot = path.join(repoRoot, "tests", "fixtures", "external");
  return {
    runtimeRoot,
    runtimeSefDir: path.join(runtimeRoot, "sef"),
    runtimeSefFile: path.join(runtimeRoot, "sef", "saxon-xforms.sef.json"),
    runtimeW3CSuiteDir: path.join(runtimeRoot, "w3c-suite"),
    fixturesExternalRoot,
    fixturesW3CSuiteDir: path.join(fixturesExternalRoot, "w3c-suite"),
    fixturesXsdtestsDir: path.join(fixturesExternalRoot, "xsdtests"),
  };
}

export function ensureDirectory(targetPath) {
  fs.mkdirSync(targetPath, { recursive: true });
}

export function ensureDirectoryAlias(targetPath, aliasPath) {
  if (!fs.existsSync(targetPath)) {
    throw new Error(`Alias target missing: ${targetPath}`);
  }
  if (fs.existsSync(aliasPath)) {
    return;
  }
  ensureDirectory(path.dirname(aliasPath));
  fs.symlinkSync(
    targetPath,
    aliasPath,
    process.platform === "win32" ? "junction" : "dir"
  );
}
