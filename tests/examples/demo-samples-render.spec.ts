import { test, expect } from "@playwright/test";
import { startExamplesServer, waitForServerReady, stopServer } from "./examples-server";

const examplesPort = 5196;
const renderTimeoutMs = 15_000;

test.describe("Examples XForms render smoke", () => {
  test.describe.configure({ mode: "serial" });
  let examplesServer;

  test.beforeAll(async () => {
    examplesServer = startExamplesServer(examplesPort);
    // TEST-TRACE: run unified examples Node server in-test so pages can fetch SaxonJS3 + SEF assets and render controls; helps tests/examples/demo-samples-render.spec.ts examples render checks.
    await waitForServerReady(examplesServer);
  });

  test.afterAll(async () => {
    await stopServer(examplesServer);
  });

  test("examples fundamentals page renders XForms controls", async ({ page }) => {
    await page.goto(`${examplesServer.baseUrl}/demo-repeat.html`);
    // TEST-TRACE: assert rendered repeat controls exist after runtime transform; helps tests/supplemental/demo-samples-render.spec.ts fundamentals render check.
    await expect(page.locator("#xForm .xforms-repeat").first()).toBeVisible({ timeout: renderTimeoutMs });
  });

  test("examples booking page renders XForms controls", async ({ page }) => {
    await page.goto(`${examplesServer.baseUrl}/sample1.html`);
    // TEST-TRACE: assert rendered booking form controls exist after runtime transform; helps tests/supplemental/demo-samples-render.spec.ts booking render check.
    await expect(page.locator("#xForm .xforms-input").first()).toBeVisible({ timeout: renderTimeoutMs });
  });
});
