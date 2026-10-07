import { test, expect } from "@playwright/test";
import { startExamplesServer, stopServer, waitForServerReady, type RunningServer } from "./examples-server";

/*
This test suite provides supplemental tests on mapping decisions between XForms and HTML controls.
*/

const renderTimeoutMs = 15_000;
const examplesPort = 5201;

test.describe("Examples demo-input-select-output", () => {
  test.describe.configure({ mode: "serial" });
  let examplesServer: RunningServer;

  test.beforeAll(async () => {
    examplesServer = startExamplesServer(examplesPort);
    await waitForServerReady(examplesServer);
  });

  test.afterAll(async () => {
    await stopServer(examplesServer);
  });

  test("renders classic controls and new range/upload widgets", async ({ page }) => {
    await page.goto(`${examplesServer.baseUrl}/demo-input-select-output.html`);
    // TEST-TRACE: ensure baseline controls still render after extending demo with range/upload; helps tests/examples/demo-input-select-output.spec.ts regression guard.
    await expect(page.locator("#xForm .xforms-input").first()).toBeVisible({ timeout: renderTimeoutMs });
    await expect(page.locator("#xForm select").first()).toBeVisible({ timeout: renderTimeoutMs });

    const rangeInput = page.locator("#xForm input[type='range']").first();
    await expect(rangeInput).toBeVisible({ timeout: renderTimeoutMs });
    await rangeInput.evaluate((element) => {
      const input = element as HTMLInputElement;
      input.value = "7";
      input.dispatchEvent(new Event("input", { bubbles: true }));
      input.dispatchEvent(new Event("change", { bubbles: true }));
    });

    const uploadInput = page.locator("#xForm input[type='file']").first();
    await expect(uploadInput).toBeVisible({ timeout: renderTimeoutMs });
    await uploadInput.setInputFiles({
      name: "pet-note.xml",
      mimeType: "application/xml",
      buffer: Buffer.from("<note>hello</note>")
    });

    // TEST-TRACE: verify range value update and upload processing affect rendered outputs; helps tests/examples/demo-input-select-output.spec.ts widget assertions.
    await expect(page.locator("#xForm")).toContainText("Mood level: 7");
    await expect(uploadInput).toHaveValue(/pet-note\.xml/);
  });

  test("shows hints accessibly and defers full validation feedback until submit", async ({ page }) => {
    await page.goto(`${examplesServer.baseUrl}/demo-input-select-output.html`);

    const firstNameControl = page.locator("#xForm .xforms-input", { hasText: "Please enter your first name" }).first();
    const firstNameInput = firstNameControl.locator("input").first();
    await expect(firstNameInput).toBeVisible({ timeout: renderTimeoutMs });

    const hintId = await firstNameInput.getAttribute("aria-describedby");
    expect(hintId).toBeTruthy();
    await expect(firstNameInput).toHaveAttribute("title", "Also known as your given name");
    await expect(page.locator(`#${hintId!}`)).toBeVisible();
    await expect(page.locator(`#${hintId!}`)).toHaveText("Also known as your given name");

    const petTypeSelect = page.locator("#xForm .xforms-select select").first();
    await expect(petTypeSelect).toBeVisible({ timeout: renderTimeoutMs });
    await expect(petTypeSelect).not.toHaveClass(/xforms-invalid/);

    await firstNameInput.fill("Morgan");
    await expect(petTypeSelect).not.toHaveClass(/xforms-invalid/);

    await page.getByRole("button", { name: "Submit" }).click();
    await expect(petTypeSelect).toHaveClass(/xforms-invalid/);
  });

  test("accepts xs:time lexical values from native time input without invalid feedback", async ({ page }) => {
    await page.goto(`${examplesServer.baseUrl}/demo-input-select-output.html`);

    const feedingTimeControl = page.locator("#xForm .xforms-input", { hasText: "Enter pet's feeding time" }).first();
    const feedingTimeInput = feedingTimeControl.locator("input").first();

    await expect(feedingTimeInput).toBeVisible({ timeout: renderTimeoutMs });
    await expect(feedingTimeInput).toHaveAttribute("type", "time");

    await feedingTimeInput.fill("09:30");
    await feedingTimeInput.blur();

    await expect(feedingTimeInput).not.toHaveClass(/xforms-invalid/);
    await page.getByRole("button", { name: "Submit" }).click();
    await expect(feedingTimeInput).not.toHaveClass(/xforms-invalid/);
  });
});
