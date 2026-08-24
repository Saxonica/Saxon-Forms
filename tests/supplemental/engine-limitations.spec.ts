import { test, expect } from "../fixtures/echo-intercept";

/**
 * Coverage for engine bugs documented in xforms-publisher/SAXON-LIMITATIONS.md:
 * #2 relative submission resource base, #3 replace=instance root identity,
 * #4 data-count refresh, #5 cross-instance repeat dirty guard.
 */

const TIMEOUT = 20_000;
const propRows = "#filtered-props-repeat > [data-repeat-item='true']";

test.describe("Engine limitations — replace instance", () => {
  test("#3 replace=instance without targetref renders bound UI (no document-root crash)", async ({
    page,
  }) => {
    const pageErrors: string[] = [];
    page.on("pageerror", (err) => pageErrors.push(String(err)));

    await page.goto("/limitations.html");
    await expect(page.locator("#limitations-root")).toBeVisible({
      timeout: TIMEOUT,
    });

    // #3: bound outputs/repeat must refresh without document-root type crash
    await expect(page.locator("#detail-count-output")).toContainText("3", {
      timeout: TIMEOUT,
    });
    await expect(page.locator(propRows)).toHaveCount(2, { timeout: TIMEOUT });
    await expect(page.locator(".prop-id").first()).toContainText("d1");

    expect(
      pageErrors.some((e) => e.includes("supplied value is document"))
    ).toBeFalsy();
  });
});

test.describe("Engine limitations — cross-instance repeat dirty + data-count", () => {
  test("#5 mode change refreshes filtered repeat without touch hacks", async ({
    page,
  }) => {
    await page.goto("/limitations.html");
    await expect(page.locator(propRows)).toHaveCount(2, { timeout: TIMEOUT });
    await expect(page.locator("#filtered-count-output")).toContainText("2");

    const select = page.locator("select.mode-select, select.incremental").first();
    await expect(select).toBeVisible({ timeout: TIMEOUT });
    await select.selectOption("b");

    await expect(page.locator("#mode-output")).toContainText("b", {
      timeout: TIMEOUT,
    });
    await expect(page.locator("#filtered-count-output")).toContainText("1", {
      timeout: TIMEOUT,
    });
    await expect(page.locator(propRows)).toHaveCount(1, { timeout: TIMEOUT });
    await expect(page.locator(".prop-id").first()).toContainText("d3");
    await expect(page.locator(".prop-label").first()).toContainText("Beta-Only");
  });

  test("#4 data-count tracks live filtered cardinality after mode change", async ({
    page,
  }) => {
    await page.goto("/limitations.html");
    const wrapper = page.locator("#filtered-props-repeat");
    await expect(wrapper).toBeVisible({ timeout: TIMEOUT });
    await expect(page.locator(propRows)).toHaveCount(2, { timeout: TIMEOUT });

    await expect
      .poll(async () => wrapper.getAttribute("data-count"), { timeout: TIMEOUT })
      .toBe("2");

    const select = page.locator("select.mode-select, select.incremental").first();
    await select.selectOption("b");
    await expect(page.locator(propRows)).toHaveCount(1, { timeout: TIMEOUT });

    await expect
      .poll(async () => wrapper.getAttribute("data-count"), { timeout: TIMEOUT })
      .toBe("1");
  });
});
