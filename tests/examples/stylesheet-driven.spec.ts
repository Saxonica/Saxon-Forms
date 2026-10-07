import { test, expect } from "@playwright/test";
import { startExamplesServer, stopServer, waitForServerReady, type RunningServer } from "./examples-server";
const renderTimeoutMs = 15_000;
const examplesPort = 5204;

test.describe("Examples restored sample2/sample3 pages", () => {
  test.describe.configure({ mode: "serial" });
  let examplesServer: RunningServer;

  test.beforeAll(async () => {
    examplesServer = startExamplesServer(examplesPort);
    await waitForServerReady(examplesServer);
  });

  test.afterAll(async () => {
    await stopServer(examplesServer);
  });

  test("sample2 and sample3 render XForms controls", async ({ page }) => {
    await page.goto(`${examplesServer.baseUrl}/sample2.html`);
    // TEST-TRACE: assert restored sample2 page renders controls in xForm root; helps tests/examples/stylesheet-driven.spec.ts sample2 assertion.
    await expect(page.locator("#xForm .xforms-input").first()).toBeVisible({ timeout: renderTimeoutMs });

    await page.goto(`${examplesServer.baseUrl}/sample3.html`);
    // TEST-TRACE: assert restored sample3 page renders controls in xForm root; helps tests/examples/stylesheet-driven.spec.ts sample3 assertion.
    await expect(page.locator("#xForm .xforms-input").first()).toBeVisible({ timeout: renderTimeoutMs });
  });
});
