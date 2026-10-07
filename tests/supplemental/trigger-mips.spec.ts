import { test, expect } from "../fixtures/echo-intercept";

/**
 * xf:trigger relevant/readonly MIP coverage.
 */

const TIMEOUT = 20_000;

async function gotoReady(page: import("@playwright/test").Page) {
  await page.goto("/trigger-mips.html");
  await expect(page.locator("#trigger-mips-root")).toBeVisible({
    timeout: TIMEOUT,
  });
  await expect(page.locator(".plain-trigger")).toBeVisible({ timeout: TIMEOUT });
}

test.describe("Trigger MIPs — relevant", () => {
  test("relevant=false hides trigger; toggle shows it; parent toolbar stays", async ({
    page,
  }) => {
    await gotoReady(page);

    const show = page.locator("button.show-trigger, button.xforms-trigger.show-trigger").first();
    const toolbar = page.locator("#toolbar");
    const plain = page.locator("button.plain-trigger").first();

    await expect(show).toBeAttached({ timeout: TIMEOUT });
    await expect
      .poll(async () => show.evaluate((el) => getComputedStyle(el).display), {
        timeout: TIMEOUT,
      })
      .toBe("none");
    await expect(toolbar).toBeVisible();
    await expect(plain).toBeVisible();

    await page.locator("button.enable-show").click();
    await expect(page.locator("#can-show-output")).toContainText("true", {
      timeout: TIMEOUT,
    });
    await expect
      .poll(async () => show.evaluate((el) => getComputedStyle(el).display), {
        timeout: TIMEOUT,
      })
      .not.toBe("none");

    await page.locator("button.disable-show").click();
    await expect(page.locator("#can-show-output")).toContainText("false", {
      timeout: TIMEOUT,
    });
    await expect
      .poll(async () => show.evaluate((el) => getComputedStyle(el).display), {
        timeout: TIMEOUT,
      })
      .toBe("none");
    await expect(plain).toBeVisible();
  });
});

test.describe("Trigger MIPs — readonly initial + refresh", () => {
  test("readonly button disabled; minimal gets aria-disabled + class + tabindex", async ({
    page,
  }) => {
    await gotoReady(page);

    const btn = page.locator("button.ro-button").first();
    const link = page.locator("a.ro-link").first();

    await expect(btn).toBeDisabled({ timeout: TIMEOUT });
    await expect(btn).toHaveAttribute("data-readonly", "true");

    await expect(link).toHaveAttribute("aria-disabled", "true");
    await expect(link).toHaveAttribute("tabindex", "-1");
    await expect(link).toHaveAttribute("data-readonly", "true");
    await expect
      .poll(async () => link.getAttribute("class"), { timeout: TIMEOUT })
      .toMatch(/xforms-disabled/);
  });

  test("toggling readonly driver updates disabled state on refresh", async ({
    page,
  }) => {
    await gotoReady(page);

    const btn = page.locator("button.ro-button").first();
    const link = page.locator("a.ro-link").first();

    await expect(btn).toBeDisabled({ timeout: TIMEOUT });

    await page.locator("button.enable-act").click();
    await expect(page.locator("#can-act-output")).toContainText("true", {
      timeout: TIMEOUT,
    });
    await expect(btn).toBeEnabled({ timeout: TIMEOUT });
    await expect(btn).not.toHaveAttribute("data-readonly", "true");

    await page.locator("button.disable-act").click();
    await expect(page.locator("#can-act-output")).toContainText("false", {
      timeout: TIMEOUT,
    });
    await expect(btn).toBeDisabled({ timeout: TIMEOUT });
    await expect(btn).toHaveAttribute("data-readonly", "true");

    await page.locator("button.enable-act-min").click();
    await expect(page.locator("#can-act-min-output")).toContainText("true", {
      timeout: TIMEOUT,
    });
    await expect
      .poll(async () => link.getAttribute("aria-disabled"), { timeout: TIMEOUT })
      .toBeNull();
    await expect
      .poll(async () => link.getAttribute("data-readonly"), { timeout: TIMEOUT })
      .toBeNull();
    await expect
      .poll(async () => link.getAttribute("class"), { timeout: TIMEOUT })
      .not.toMatch(/xforms-disabled/);
  });
});

test.describe("Trigger MIPs — activation guards", () => {
  test("readonly DOMActivate does not run actions", async ({ page }) => {
    await gotoReady(page);

    await expect(page.locator("#ro-clicks-output")).toContainText("0", {
      timeout: TIMEOUT,
    });

    const btn = page.locator("button.ro-button").first();
    await expect(btn).toHaveAttribute("data-readonly", "true");

    // Bypass native disabled: force-click via evaluate so engine DOMActivate path runs
    await page.evaluate(() => {
      const el = document.querySelector("button.ro-button") as HTMLElement | null;
      if (!el) throw new Error("ro-button missing");
      el.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true }));
    });

    // Allow a tick for any deferred updates
    await page.waitForTimeout(300);
    await expect(page.locator("#ro-clicks-output")).toContainText("0");
  });

  test("plain unbound trigger still activates", async ({ page }) => {
    await gotoReady(page);

    await expect(page.locator("#plain-clicks-output")).toContainText("0", {
      timeout: TIMEOUT,
    });

    const plain = page.locator("button.plain-trigger").first();
    await expect(plain).not.toHaveAttribute("data-relevant");
    await expect(plain).not.toHaveAttribute("data-readonly");
    await expect(plain).toBeEnabled();

    await plain.click();
    await expect(page.locator("#plain-clicks-output")).toContainText("1", {
      timeout: TIMEOUT,
    });
  });
});
