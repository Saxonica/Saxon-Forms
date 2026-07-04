import { test, expect } from "@playwright/test";
import { startExamplesServer, waitForServerReady, stopServer } from "./examples-server";

const examplesPort = 5197;
const renderTimeoutMs = 25_000;

test.describe("native XForms fiddle", () => {
  test.describe.configure({ mode: "serial" });
  let examplesServer;

  test.beforeAll(async () => {
    examplesServer = startExamplesServer(examplesPort);
    await waitForServerReady(examplesServer);
  });

  test.afterAll(async () => {
    await stopServer(examplesServer);
  });

  test("loads host controls and renders default nested form", async ({ page }) => {
    await page.goto(`${examplesServer.baseUrl}/native-xforms-fiddle.html`);
    await expect(page).toHaveTitle("Native XForms Fiddle");
    await expect(page.getByRole("button", { name: "Refresh XForms" })).toBeVisible({ timeout: renderTimeoutMs });
    await expect(page.locator("textarea[id^='native-fiddle-xforms-source']")).toBeVisible({ timeout: renderTimeoutMs });
    await expect(page.frameLocator("#native-fiddle-render-target").locator(".xforms-input").first()).toBeVisible({ timeout: renderTimeoutMs });
    await expect(page.locator("#native-fiddle-console")).toContainText("Render complete.", { timeout: renderTimeoutMs });
  });

  test("refreshes nested form from edited source", async ({ page }) => {
    await page.goto(`${examplesServer.baseUrl}/native-xforms-fiddle.html`);
    await expect(page.frameLocator("#native-fiddle-render-target").locator(".xforms-input").first()).toBeVisible({ timeout: renderTimeoutMs });
    const didUpdateSource = await page.evaluate(() => {
      const sourceEditor = document.querySelector("textarea[id^='native-fiddle-xforms-source']");
      if (!(sourceEditor instanceof HTMLTextAreaElement)) {
        return false;
      }
      const updatedSource = sourceEditor.value.replace(
        "<xf:label>Name</xf:label>",
        "<xf:label>Full name</xf:label>"
      );
      if (updatedSource === sourceEditor.value) {
        return false;
      }
      sourceEditor.value = updatedSource;
      sourceEditor.dispatchEvent(new Event("input", { bubbles: true }));
      sourceEditor.dispatchEvent(new Event("change", { bubbles: true }));
      return true;
    });
    expect(didUpdateSource).toBeTruthy();
    await page.evaluate(() => window.nativeXFormsFiddle.refresh());

    await expect(page.frameLocator("#native-fiddle-render-target").locator("body")).toContainText("Full name", { timeout: renderTimeoutMs });
    await expect(page.locator("#native-fiddle-console")).toContainText("Render complete.", { timeout: renderTimeoutMs });
  });

  test("supports repeated refresh operations", async ({ page }) => {
    await page.goto(`${examplesServer.baseUrl}/native-xforms-fiddle.html`);
    await expect(page.frameLocator("#native-fiddle-render-target").locator(".xforms-input").first()).toBeVisible({ timeout: renderTimeoutMs });

    await page.getByRole("button", { name: "Refresh XForms" }).click();
    await expect(page.locator("#native-fiddle-console")).toContainText("Render complete.", { timeout: renderTimeoutMs });

    await page.getByRole("button", { name: "Refresh XForms" }).click();
    await expect(page.locator("#native-fiddle-console")).toContainText("Render complete.", { timeout: renderTimeoutMs });
    await expect(page.frameLocator("#native-fiddle-render-target").locator(".xforms-input").first()).toBeVisible({ timeout: renderTimeoutMs });
  });
});
