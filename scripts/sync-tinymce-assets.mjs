#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { getTestPaths } from "./lib/test-paths.mjs";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");
const testPaths = getTestPaths(repoRoot);
const sourceTinyRoot = path.join(repoRoot, "node_modules", "tinymce");
const sourceTinyWebComponent = path.join(
  repoRoot,
  "node_modules",
  "@tinymce",
  "tinymce-webcomponent",
  "dist",
  "tinymce-webcomponent.js"
);
const destinationLibRoot = path.join(testPaths.runtimeRoot, "lib");
const destinationTinyRoot = path.join(destinationLibRoot, "tinymce");
const destinationTinyWebComponent = path.join(destinationLibRoot, "tinymce-webcomponent.js");
const tinymceEntries = ["tinymce.min.js", "icons", "models", "plugins", "skins", "themes"];

function assertExists(targetPath, label) {
  if (!fs.existsSync(targetPath)) {
    throw new Error(`${label} not found: ${targetPath}. Run 'npm install' first.`);
  }
}

function syncTinymceAssets() {
  assertExists(sourceTinyRoot, "tinymce package");
  assertExists(sourceTinyWebComponent, "@tinymce/tinymce-webcomponent bundle");
  fs.mkdirSync(destinationLibRoot, { recursive: true });
  fs.rmSync(destinationTinyRoot, { recursive: true, force: true });
  fs.mkdirSync(destinationTinyRoot, { recursive: true });

  // TEST-TRACE: copy TinyMCE runtime assets from pinned npm package; helps tests/supplemental/web-components.spec.ts "Web components integration (tinymce)".
  for (const entry of tinymceEntries) {
    const sourcePath = path.join(sourceTinyRoot, entry);
    const destinationPath = path.join(destinationTinyRoot, entry);
    assertExists(sourcePath, `tinymce asset '${entry}'`);
    fs.cpSync(sourcePath, destinationPath, { recursive: true, force: true });
  }

  // TEST-TRACE: copy local TinyMCE webcomponent bundle so TinyMCE tests run without CDN access; helps tests/supplemental/web-components.spec.ts "Web components integration (tinymce)".
  fs.cpSync(sourceTinyWebComponent, destinationTinyWebComponent, { force: true });

  // TEST-TRACE: patch the copied webcomponent (test-only) to forward 'license-key' / 'license_key'
  // attribute to tinymce.init config. Without this, GPL self-hosted inits can leave the
  // editor body with contenteditable=false + mce-content-readonly. The webcomponent only
  // maps a whitelist (configAttributes) and renames via configRenames; license-key is not
  // in the upstream whitelist. This patch enables <tinymce-editor license-key="gpl" ...> to work
  // fully offline with the local tinymce package; helps the real-interaction tests.
  let wcCode = fs.readFileSync(destinationTinyWebComponent, 'utf8');
  if (!/license-?key/i.test(wcCode)) {
    wcCode = wcCode.replace(
      /promotion:\s*parseBooleanOrString\s*\n?\s*\}/m,
      "promotion: parseBooleanOrString,\n  'license-key': parseString,\n  license_key: parseString\n}"
    );
    wcCode = wcCode.replace(
      /const configRenames = \{\}/,
      "const configRenames = {'license-key': 'license_key'}"
    );
    fs.writeFileSync(destinationTinyWebComponent, wcCode);
    console.log("[sync:tinymce] Patched tinymce-webcomponent.js to forward license-key (GPL self-hosted).");
  }

  console.log("[sync:tinymce] Synced TinyMCE assets to tests/runtime/lib.");
}

try {
  syncTinymceAssets();
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
}
