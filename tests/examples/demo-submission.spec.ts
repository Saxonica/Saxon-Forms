import { test, expect } from "@playwright/test";
import { startExamplesServer, stopServer, waitForServerReady, type RunningServer } from "./examples-server";

const renderTimeoutMs = 15_000;
const examplesPort = 5202;

test.describe("Examples demo-submission", () => {
  test.describe.configure({ mode: "serial" });
  let examplesServer: RunningServer;

  test.beforeAll(async () => {
    examplesServer = startExamplesServer(examplesPort);
    await waitForServerReady(examplesServer);
  });

  test.afterAll(async () => {
    await stopServer(examplesServer);
  });

  test("updates status node for submit success and failure paths", async ({ page }) => {
    const requests: string[] = [];
    page.on("request", (request) => {
      if (request.url().includes("/api/submit-ok") || request.url().includes("/api/submit-fail")) {
        requests.push(request.url());
      }
    });

    await page.goto(`${examplesServer.baseUrl}/demo-submission.html`);
    // TEST-TRACE: verify submission controls render and both lifecycle requests fire; helps tests/examples/demo-submission.spec.ts transport assertions.
    await expect(page.locator("#xForm .xforms-textarea").first()).toBeVisible({ timeout: renderTimeoutMs });

    await page.getByRole("button", { name: "Submit success path" }).click();
    await expect(page.locator("#xForm")).toContainText("Submission succeeded.");

    await page.getByRole("button", { name: "Submit failure path" }).click();
    await expect(page.locator("#xForm")).toContainText("Submission failed.");

    // TEST-TRACE: ensure both success and error endpoints were invoked by xf:submit actions; helps tests/examples/demo-submission.spec.ts endpoint coverage.
    expect(requests.some((url) => url.includes("/api/submit-ok"))).toBeTruthy();
    expect(requests.some((url) => url.includes("/api/submit-fail"))).toBeTruthy();
  });
});
