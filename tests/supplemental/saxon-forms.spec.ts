import { test, expect } from "../fixtures/echo-intercept";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

/**
 * Saxon-Forms E2E tests.
 *
 * These run against a generic test XForm (tests/runtime/xforms/test-app.xml)
 * that exercises the features added/fixed in the Saxon-Forms fork.
 * The XForm uses a custom namespace (urn:test:items) with prefix t:
 * and includes xf:script, xf:upload, and xf:load controls.
 */

const SF_RENDER_TIMEOUT = 15_000;

test.describe("XForm rendering", () => {
  test("page loads with correct title", async ({ page }) => {
    await page.goto("/");
    await expect(page).toHaveTitle("Saxon-Forms Test App");
  });

  test("xForm container renders content", async ({ page }) => {
    await page.goto("/");
    const root = page.locator("#test-app-root");
    await expect(root).toBeVisible({ timeout: SF_RENDER_TIMEOUT });
  });
});


test.describe("Fix 1 — Namespace prefix propagation", () => {
  test("namespace-prefixed repeat renders items", async ({ page }) => {
    await page.goto("/");
    const items = page.locator(".test-item");
    await expect(items.first()).toBeVisible({ timeout: SF_RENDER_TIMEOUT });
    await expect(items).toHaveCount(3);
  });

  test("namespace-prefixed output shows item names", async ({ page }) => {
    await page.goto("/");
    const name = page.locator(".item-name").first();
    await expect(name).toBeVisible({ timeout: SF_RENDER_TIMEOUT });
    await expect(name).toContainText("Alpha");
  });

  test("namespace-prefixed output shows item values", async ({ page }) => {
    await page.goto("/");
    const value = page.locator(".item-value").first();
    await expect(value).toBeVisible({ timeout: SF_RENDER_TIMEOUT });
    await expect(value).toContainText("100");
  });

  test("item @id attribute renders via output", async ({ page }) => {
    await page.goto("/");
    const id = page.locator(".item-id").first();
    await expect(id).toBeVisible({ timeout: SF_RENDER_TIMEOUT });
    await expect(id).toContainText("i-1");
  });

  test("calculated item count via xf:bind works", async ({ page }) => {
    await page.goto("/");
    const count = page.locator("#item-count-output");
    await expect(count).toBeVisible({ timeout: SF_RENDER_TIMEOUT });
    await expect(count).toContainText("3");
  });
});

test.describe("Fix 3 — xf:script action", () => {
  test("script trigger button renders", async ({ page }) => {
    await page.goto("/");
    const btn = page.locator("button.xforms-trigger", {
      hasText: "Run Script",
    });
    await expect(btn).toBeVisible({ timeout: SF_RENDER_TIMEOUT });
  });

  test("clicking trigger executes JS via xf:script", async ({ page }) => {
    await page.goto("/");
    const btn = page.locator("button.xforms-trigger", {
      hasText: "Run Script",
    });
    await expect(btn).toBeVisible({ timeout: SF_RENDER_TIMEOUT });

    const before = await page.evaluate(() => (window as any).__sfScriptResult);
    expect(before).toBeUndefined();

    await btn.click();

    const after = await page.evaluate(() => (window as any).__sfScriptResult);
    expect(after).toBe("ok");
  });
});

test.describe("Fix 4 — xf:load action", () => {
  test("load-js trigger button renders", async ({ page }) => {
    await page.goto("/");
    const btn = page.locator("button.xforms-trigger", {
      hasText: "Load JS",
    });
    await expect(btn).toBeVisible({ timeout: SF_RENDER_TIMEOUT });
  });

  test("clicking load trigger evaluates javascript: URI", async ({ page }) => {
    await page.goto("/");
    const btn = page.locator("button.xforms-trigger", {
      hasText: "Load JS",
    });
    await expect(btn).toBeVisible({ timeout: SF_RENDER_TIMEOUT });

    await btn.click();

    const result = await page.evaluate(() => (window as any).__sfLoadResult);
    expect(result).toBe("loaded");
  });
});

test.describe("Fix 2 — xf:upload", () => {
  test("xf:upload renders as file input", async ({ page }) => {
    await page.goto("/");
    const fileInput = page.locator(
      "input[type='file'][data-ref=\"instance('upload-target')\"]"
    );
    await expect(fileInput).toBeAttached({ timeout: SF_RENDER_TIMEOUT });
  });

  test("xf:upload label renders", async ({ page }) => {
    await page.goto("/");
    const upload = page.locator(".xforms-upload");
    await expect(upload).toBeVisible({ timeout: SF_RENDER_TIMEOUT });
    await expect(upload).toContainText("Upload XML");
  });

  test("uploading XML via xf:upload sets instance data", async ({ page }) => {
    await page.goto("/");
    const fileInput = page.locator(
      "input[type='file'][data-ref=\"instance('upload-target')\"]"
    );
    await expect(fileInput).toBeAttached({ timeout: SF_RENDER_TIMEOUT });

    // TEST-TRACE: fix relative path after asset consolidation; fixture lives in tests/fixtures/; helps tests/supplemental/saxon-forms.spec.ts upload test
    await fileInput.setInputFiles(
      path.resolve(__dirname, "../fixtures/upload-data.xml")
    );

    // Verify the instance was populated at the JS level
    await expect
      .poll(
        async () => {
          return page.evaluate(() => {
            const inst = (window as any).getInstance("upload-target");
            return inst ? inst.querySelectorAll("record").length : 0;
          });
        },
        { timeout: 10_000 }
      )
      .toBeGreaterThan(0);
  });
});
