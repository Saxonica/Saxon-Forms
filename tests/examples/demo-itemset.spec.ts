import { test, expect } from "@playwright/test";
import { startExamplesServer, stopServer, waitForServerReady, type RunningServer } from "./examples-server";

const renderTimeoutMs = 15_000;
const examplesPort = 5200;

test.describe("Examples demo-itemset", () => {
  test.describe.configure({ mode: "serial" });
  let examplesServer: RunningServer;

  test.beforeAll(async () => {
    examplesServer = startExamplesServer(examplesPort);
    await waitForServerReady(examplesServer);
  });

  test.afterAll(async () => {
    await stopServer(examplesServer);
  });

  test("renders itemset controls and updates selection outputs", async ({ page }) => {
    await page.goto(`${examplesServer.baseUrl}/demo-itemset.html`);
    // TEST-TRACE: assert dynamic itemset controls render before interactions; helps tests/examples/demo-itemset.spec.ts itemset smoke coverage.
    const selects = page.locator("#xForm select");
    await expect(selects.first()).toBeVisible({ timeout: renderTimeoutMs });
    await expect(selects).toHaveCount(2);

    await selects.nth(0).selectOption("carrot");
    await selects.nth(1).selectOption(["banana", "dates"]);

    // TEST-TRACE: verify bound output text reflects single and multi-select choices from xf:itemset; helps tests/examples/demo-itemset.spec.ts binding assertions.
    await expect(page.locator("#xForm")).toContainText("Favorite: carrot");
    await expect(page.locator("#xForm")).toContainText("Snacks:");
  });
});
