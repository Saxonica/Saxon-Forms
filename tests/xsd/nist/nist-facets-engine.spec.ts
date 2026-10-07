import { test, expect, RENDER_TIMEOUT, submitAndCapture } from "../../xforms/w3c/helpers";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..", "..", "..");

type EngineCase = {
  caseId: string;
  title: string;
  expectedValid: boolean;
  schemaText: string;
  schemaHref: string;
  typeName: string;
  rootName: string;
  targetNamespace: string;
  lexicalValue: string;
};

type UnsupportedGroup = {
  facet: string;
  group: string;
  reason: string;
};

type EngineCaseBuildResult = {
  indexPath: string;
  selectedCount: number;
  runnableCases: EngineCase[];
  unsupportedGroups: UnsupportedGroup[];
};

type EngineCaseIndexFile = {
  selected_count: number;
  runnable_cases: EngineCase[];
  unsupported_groups: UnsupportedGroup[];
};

function resolveIndexPath(): string {
  const override = process.env.NIST_ENGINE_CASE_INDEX;
  if (!override || override.trim() === "") {
    return path.resolve(repoRoot, "tests/xsd/nist/.cache/nist-engine-case-index.json");
  }
  return path.isAbsolute(override) ? override : path.resolve(repoRoot, override);
}

function loadPrecomputedEngineCases(): EngineCaseBuildResult {
  const indexPath = resolveIndexPath();
  if (!fs.existsSync(indexPath)) {
    throw new Error(
      `Missing NIST engine case index at ${indexPath}. Run "npm run build:nist-engine-index" first or set NIST_ENGINE_CASE_INDEX.`
    );
  }
  // TEST-TRACE: read precomputed NIST case index to avoid expensive startup parsing and file traversal in benchmarked spec.
  const payload = JSON.parse(fs.readFileSync(indexPath, "utf8")) as EngineCaseIndexFile;
  return {
    indexPath,
    selectedCount: Number(payload.selected_count ?? 0),
    runnableCases: payload.runnable_cases ?? [],
    unsupportedGroups: payload.unsupported_groups ?? [],
  };
}

function xmlEscape(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&apos;");
}

function buildXhtml(caseDef: EngineCase): string {
  const valueLiteral = xmlEscape(caseDef.lexicalValue);
  const schemaLiteral = `schema-${encodeURIComponent(caseDef.caseId)}.xsd`;
  const inlineSchema = caseDef.schemaText.replace(/^\s*<\?xml[^>]*>\s*/i, "").trim();
  // TEST-TRACE: use local-name() nodesets so generated tests work for namespaced NIST roots; helps tests/w3c/nist-facets-engine.spec.ts expanded manifest coverage.
  const rootNodeset = `/*[local-name()='${caseDef.rootName}']`;
  const rootQName = caseDef.targetNamespace ? `nist:${caseDef.rootName}` : caseDef.rootName;
  const rootNamespaceDecl = caseDef.targetNamespace ? ` xmlns:nist="${xmlEscape(caseDef.targetNamespace)}"` : "";
  const schemaLocationNs = caseDef.targetNamespace || "urn:nist";
  return `<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml"
      xmlns:xforms="http://www.w3.org/2002/xforms"
      xmlns:ev="http://www.w3.org/2001/xml-events">
  <head>
    <title>NIST ${xmlEscape(caseDef.title)}</title>
    <xforms:model>
      <xforms:instance id="nist">
        <${rootQName}${rootNamespaceDecl} xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="${xmlEscape(schemaLocationNs)} ${schemaLiteral}">${valueLiteral}</${rootQName}>
      </xforms:instance>
      <xforms:bind nodeset="${rootNodeset}" type="${xmlEscape(caseDef.typeName)}"/>
      ${inlineSchema}
      <xforms:submission id="nist-submit" instance="nist" resource="/echo.sh" method="post"/>
    </xforms:model>
  </head>
  <body>
    <xforms:input ref="${rootNodeset}" incremental="true">
      <xforms:label>Value</xforms:label>
    </xforms:input>
    <xforms:submit submission="nist-submit">
      <xforms:label>Submit</xforms:label>
    </xforms:submit>
  </body>
</html>`;
}

const buildResult = loadPrecomputedEngineCases();
const engineCases = buildResult.runnableCases;
const unsupportedGroups = buildResult.unsupportedGroups;

test.describe("NIST facets through Saxon-Forms engine", () => {
  test.describe.configure({ mode: "serial" });

  test("manifest selection partitions into runnable and unsupported groups", async () => {
    // TEST-TRACE: guard against index/manifest divergence after precompute refactor; helps tests/w3c/nist-facets-engine.spec.ts "NIST facets through Saxon-Forms engine".
    expect(engineCases.length + unsupportedGroups.length).toBe(buildResult.selectedCount);
    expect(engineCases.length).toBeGreaterThan(0);
  });

  test.beforeAll(async () => {
    // TEST-TRACE: emit index path used by runtime to support benchmark provenance for startup overhead comparisons.
    console.warn(`[nist-engine] index=${buildResult.indexPath}`);
    if (!unsupportedGroups.length) return;
    const sample = unsupportedGroups.slice(0, 10).map((g) => `${g.group} (${g.reason})`).join(", ");
    // TEST-TRACE: emit one-time unsupported-group diagnostics for expanded manifest triage; helps tests/w3c/nist-facets-engine.spec.ts "NIST facets through Saxon-Forms engine".
    console.warn(`[nist-engine] runnable=${engineCases.length} unsupported=${unsupportedGroups.length} selected=${buildResult.selectedCount}`);
    console.warn(`[nist-engine] unsupported sample: ${sample}`);
  });

  for (const caseDef of engineCases) {
    test(`${caseDef.title} => ${caseDef.expectedValid ? "valid" : "invalid"}`, async ({ page }) => {
      const xhtmlPath = "**/w3c-suite/nist-generated/nist-case.xhtml*";
      await page.route(xhtmlPath, async (route) => {
        const url = new URL(route.request().url());
        const caseId = url.searchParams.get("caseId");
        if (caseId !== caseDef.caseId) {
          await route.fulfill({ status: 404, body: "unknown case" });
          return;
        }
        await route.fulfill({
          status: 200,
          contentType: "application/xhtml+xml",
          body: buildXhtml(caseDef),
        });
      });

      const testFile = `nist-generated/nist-case.xhtml?caseId=${encodeURIComponent(caseDef.caseId)}`;
      await page.goto(`/w3c-runner.html?test=${encodeURIComponent(testFile)}`);
      await expect(page.locator("#xForm")).not.toBeEmpty({ timeout: RENDER_TIMEOUT });

      const input = page.locator("#xForm input").first();
      await expect(input).toBeVisible();

      // TEST-TRACE: dispatch both input and change so Saxon-Forms updates instance before submit.
      await input.evaluate((node, value) => {
        const el = node as HTMLInputElement;
        el.value = value;
        el.dispatchEvent(new Event("input", { bubbles: true }));
        el.dispatchEvent(new Event("change", { bubbles: true }));
      }, caseDef.lexicalValue);

      const submitButton = page.getByRole("button", { name: "Submit" });
      const request = await submitAndCapture(page, submitButton, 1200);

      if (caseDef.expectedValid) {
        expect(request).not.toBeNull();
      } else {
        expect(request).toBeNull();
      }

      await page.unroute(xhtmlPath);
    });
  }
});