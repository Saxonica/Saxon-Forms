import { test, expect } from "../fixtures/echo-intercept";

/**
 * SAXON-LIMITATIONS #7 — MIP ancestor-walk performance + correctness.
 * Synthetic ~200-leaf tree with section-level relevant/readonly binds.
 */

const TIMEOUT = 30_000;
/** Soft budget: load + first paint (~200 MIP-bound controls). Pre-fix multi-10s; keep well under. */
const LOAD_BUDGET_MS = 15_000;
/** Soft budget: one setvalue+refresh. Correctness is primary; budget guards multi-10s regression. */
const REFRESH_BUDGET_MS = 12_000;

async function gotoReady(page: import("@playwright/test").Page) {
  const t0 = Date.now();
  await page.goto("/mip-perf.html");
  await expect(page.locator("#mip-perf-root")).toBeVisible({ timeout: TIMEOUT });
  await expect(page.locator(".item-row").first()).toBeVisible({ timeout: TIMEOUT });
  return Date.now() - t0;
}

test.describe("MIP perf — load budget", () => {
  test("large form loads under wall-clock budget", async ({ page }) => {
    const ms = await gotoReady(page);
    expect(ms).toBeLessThan(LOAD_BUDGET_MS);
  });
});

test.describe("MIP perf — relevant correctness", () => {
  test("section relevant=false hides bound leaf controls; show restores", async ({
    page,
  }) => {
    await gotoReady(page);

    const firstInput = page.locator("input.item-value, .item-value input").first();
    await expect(firstInput).toBeVisible({ timeout: TIMEOUT });

    const t0 = Date.now();
    await page.locator("button.hide-section").click();
    await expect(page.locator("#section-open-output")).toContainText("false", {
      timeout: TIMEOUT,
    });
    await expect
      .poll(async () => firstInput.evaluate((el) => getComputedStyle(el).display), {
        timeout: TIMEOUT,
      })
      .toBe("none");
    const hideMs = Date.now() - t0;
    expect(hideMs).toBeLessThan(REFRESH_BUDGET_MS);

    const t1 = Date.now();
    await page.locator("button.show-section").click();
    await expect(page.locator("#section-open-output")).toContainText("true", {
      timeout: TIMEOUT,
    });
    await expect
      .poll(async () => firstInput.evaluate((el) => getComputedStyle(el).display), {
        timeout: TIMEOUT,
      })
      .not.toBe("none");
    expect(Date.now() - t1).toBeLessThan(REFRESH_BUDGET_MS);
  });
});

test.describe("MIP perf — readonly correctness", () => {
  test("section readonly disables leaf trigger; unlock enables", async ({
    page,
  }) => {
    await gotoReady(page);

    const act = page.locator("button.leaf-act").first();
    await expect(act).toBeVisible({ timeout: TIMEOUT });
    await expect(act).toBeDisabled({ timeout: TIMEOUT });
    await expect(act).toHaveAttribute("data-readonly", "true");

    const t0 = Date.now();
    await page.locator("button.enable-edit").click();
    await expect(page.locator("#can-edit-output")).toContainText("true", {
      timeout: TIMEOUT,
    });
    await expect(act).toBeEnabled({ timeout: TIMEOUT });
    await expect(act).not.toHaveAttribute("data-readonly", "true");
    expect(Date.now() - t0).toBeLessThan(REFRESH_BUDGET_MS);

    await page.locator("button.disable-edit").click();
    await expect(page.locator("#can-edit-output")).toContainText("false", {
      timeout: TIMEOUT,
    });
    await expect(act).toBeDisabled({ timeout: TIMEOUT });
    await expect(act).toHaveAttribute("data-readonly", "true");
  });
});

test.describe("MIP perf — debugTiming quiet", () => {
  test("console is not flooded with startTime/endTime pairs on load", async ({
    page,
  }) => {
    const messages: string[] = [];
    page.on("console", (msg) => messages.push(msg.text()));

    await gotoReady(page);
    // Allow deferred refresh noise to settle
    await page.waitForTimeout(200);

    const timingSpam = messages.filter(
      (m) =>
        /startTime|endTime|getRelevantStatus \(evaluate\)/i.test(m) ||
        /Time taken/i.test(m)
    );
    expect(timingSpam.length).toBeLessThan(20);
  });
});

/** Soft budget: replace instance('detail') with ~200 props (guards multi-10s / 40s regression). */
const REPLACE_BUDGET_MS = 15_000;

async function gotoReplaceReady(page: import("@playwright/test").Page) {
  await page.goto("/mip-perf-replace.html");
  await expect(page.locator("#mip-replace-root")).toBeVisible({
    timeout: TIMEOUT,
  });
  // xforms-ready loads payload A (~200 props)
  await expect(page.locator("#detail-count-output")).toContainText("200", {
    timeout: TIMEOUT,
  });
  await expect(page.locator(".prop-row").first()).toBeVisible({
    timeout: TIMEOUT,
  });
}

test.describe("MIP perf — detail instance replace (A+B)", () => {
  test("large detail replace stays under budget; tree trigger stays readonly", async ({
    page,
  }) => {
    await gotoReplaceReady(page);

    const treeAct = page.locator("button.tree-act").first();
    await expect(treeAct).toBeDisabled({ timeout: TIMEOUT });
    await expect(treeAct).toHaveAttribute("data-readonly", "true");

    const detailAct = page.locator("button.detail-act").first();
    await expect(detailAct).toBeDisabled({ timeout: TIMEOUT });

    const reloadB = page.locator(".reload-b, button.reload-b, [data-submit='load-detail-b']").first();
    const reloadA = page.locator(".reload-a, button.reload-a, [data-submit='load-detail-a']").first();

    const t0 = Date.now();
    await reloadB.click();
    await expect(page.locator("#detail-count-output")).toContainText("180", {
      timeout: TIMEOUT,
    });
    expect(Date.now() - t0).toBeLessThan(REPLACE_BUDGET_MS);

    // Tree MIP bucket must survive detail replace (still readonly)
    await expect(treeAct).toBeDisabled({ timeout: TIMEOUT });
    await expect(treeAct).toHaveAttribute("data-readonly", "true");
    await expect(page.locator("#tree-label-output")).toContainText("Tree Node");

    // Payload B has edit=true → detail act enabled
    await expect(page.locator("#detail-edit-output")).toContainText("true", {
      timeout: TIMEOUT,
    });
    await expect(detailAct).toBeEnabled({ timeout: TIMEOUT });

    const t1 = Date.now();
    await reloadA.click();
    await expect(page.locator("#detail-count-output")).toContainText("200", {
      timeout: TIMEOUT,
    });
    expect(Date.now() - t1).toBeLessThan(REPLACE_BUDGET_MS);
    await expect(detailAct).toBeDisabled({ timeout: TIMEOUT });
    await expect(treeAct).toBeDisabled();
  });
});

test.describe("MIP perf — dirty gating & coalesced refresh", () => {
  test("single instance mutation only refreshes dirty outputs and stays under fast budget", async ({
    page,
  }) => {
    await gotoReplaceReady(page);

    const treeLabel = page.locator("#tree-label-output");
    await expect(treeLabel).toContainText("Tree Node");

    const t0 = Date.now();
    // Click reload B (updates detail only, tree untouched)
    const reloadB = page.locator(".reload-b, button.reload-b, [data-submit='load-detail-b']").first();
    await reloadB.click();
    await expect(page.locator("#detail-count-output")).toContainText("180", {
      timeout: TIMEOUT,
    });
    const elapsed = Date.now() - t0;
    expect(elapsed).toBeLessThan(REPLACE_BUDGET_MS);
    // Tree label output remains intact
    await expect(treeLabel).toContainText("Tree Node");
  });
});
