import { test, expect } from "@playwright/test";

const RENDER_TIMEOUT = 15_000;

test.describe("XHTML XForms source handling", () => {
  test("baseline standalone xf:xform XML still renders", async ({ page }) => {
    await page.goto("/");
    await expect(page.locator("#test-app-root")).toBeVisible({
      timeout: RENDER_TIMEOUT,
    });
    await expect(page.locator(".test-item")).toHaveCount(3);
  });

  test("direct .xhtml sourceNode renders XForms controls", async ({ page }) => {
    test.fail(
      true,
      "Known issue: XHTML sourceNode currently falls back to ixsl:page() handling instead of the fetched XHTML document."
    );

    await page.goto("/xhtml-source-node.html");

    const directRoot = page.locator("#xhtml-direct-root");
    await expect(directRoot).toBeVisible({ timeout: RENDER_TIMEOUT });

    const output = page.locator("#xhtml-direct-value");
    await expect(output).toContainText("alpha");

    const input = page.locator("input.xforms-input").first();
    await expect(input).toBeVisible({ timeout: RENDER_TIMEOUT });
    await input.fill("beta");
    await input.blur();

    await expect(output).toContainText("beta");
  });
});
