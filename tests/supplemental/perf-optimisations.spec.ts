import { test, expect } from "../fixtures/echo-intercept";

/**
 * Regression tests for the repeat-refresh performance optimisations
 * (6a dirty-instance tracking, 6b DOM-splice append, DOMActivate
 * repeat-index update).
 *
 * Uses a two-panel XForm: a read-only source repeat (5 entries) and
 * an initially-empty target repeat.  Clicking "+" on a source item
 * copies it to the target via xf:insert with index()-based origin.
 */

const TIMEOUT = 15_000;

/** Add-button selector: <a> triggers inside source-repeat items */
const addBtn = ".source-item a.xforms-trigger";
/** Target repeat items (direct children only) */
const targetItems = "#target-repeat > [data-repeat-item='true']";

// ── Rendering ──

test.describe("Perf XForm — rendering", () => {
  test("page loads and form renders", async ({ page }) => {
    await page.goto("/perf.html");
    await expect(page.locator("#perf-test-root")).toBeVisible({ timeout: TIMEOUT });
  });

  test("source repeat shows 5 entries", async ({ page }) => {
    await page.goto("/perf.html");
    const items = page.locator(".source-item");
    await expect(items).toHaveCount(5, { timeout: TIMEOUT });
  });

  test("source entries display correct IDs", async ({ page }) => {
    await page.goto("/perf.html");
    const ids = page.locator(".source-id");
    await expect(ids.first()).toBeVisible({ timeout: TIMEOUT });
    await expect(ids.nth(0)).toContainText("e-1");
    await expect(ids.nth(1)).toContainText("e-2");
    await expect(ids.nth(2)).toContainText("e-3");
  });

  test("target repeat is initially empty", async ({ page }) => {
    await page.goto("/perf.html");
    await expect(page.locator("#perf-test-root")).toBeVisible({ timeout: TIMEOUT });
    await expect(page.locator(targetItems)).toHaveCount(0);
  });

  test("target count output shows 0", async ({ page }) => {
    await page.goto("/perf.html");
    const count = page.locator("#target-count-output");
    await expect(count).toBeVisible({ timeout: TIMEOUT });
    await expect(count).toContainText("0");
  });

  test("source count output shows 5", async ({ page }) => {
    await page.goto("/perf.html");
    const count = page.locator("#source-count-output");
    await expect(count).toBeVisible({ timeout: TIMEOUT });
    await expect(count).toContainText("5");
  });
});

// ── Insert (6b append-splice + DOMActivate index fix) ──

test.describe("Perf XForm — insert", () => {
  test("clicking + on first source entry adds it to target", async ({ page }) => {
    await page.goto("/perf.html");
    const btn = page.locator(addBtn).first();
    await expect(btn).toBeVisible({ timeout: TIMEOUT });

    await btn.click();
    await expect(page.locator(targetItems)).toHaveCount(1, { timeout: TIMEOUT });
    await expect(page.locator(".target-id").first()).toContainText("e-1");
    await expect(page.locator(".target-label").first()).toContainText("Alpha");
  });

  test("target count updates after insert", async ({ page }) => {
    await page.goto("/perf.html");
    await page.locator(addBtn).first().click();
    await expect(page.locator(targetItems)).toHaveCount(1, { timeout: TIMEOUT });
    await expect(page.locator("#target-count-output")).toContainText("1");
  });

  test("sequential inserts from different source items produce distinct entries", async ({ page }) => {
    await page.goto("/perf.html");
    const btns = page.locator(addBtn);
    await expect(btns.first()).toBeVisible({ timeout: TIMEOUT });

    const expected = [
      { id: "e-1", label: "Alpha" },
      { id: "e-2", label: "Beta" },
      { id: "e-3", label: "Gamma" },
    ];

    for (let i = 0; i < expected.length; i++) {
      await btns.nth(i).click();
      await expect(page.locator(targetItems)).toHaveCount(i + 1, { timeout: TIMEOUT });
    }

    const items = page.locator(targetItems);
    for (let i = 0; i < expected.length; i++) {
      await expect(items.nth(i).locator(".target-id")).toContainText(expected[i].id);
      await expect(items.nth(i).locator(".target-label")).toContainText(expected[i].label);
    }
  });

  test("adding all 5 source entries works", async ({ page }) => {
    await page.goto("/perf.html");
    const btns = page.locator(addBtn);
    await expect(btns.first()).toBeVisible({ timeout: TIMEOUT });

    for (let i = 0; i < 5; i++) {
      await btns.nth(i).click();
      await expect(page.locator(targetItems)).toHaveCount(i + 1, { timeout: TIMEOUT });
    }

    await expect(page.locator("#target-count-output")).toContainText("5");
    await expect(page.locator(targetItems).last().locator(".target-id")).toContainText("e-5");
  });

  test("adding the same source entry twice duplicates it", async ({ page }) => {
    await page.goto("/perf.html");
    const btn = page.locator(addBtn).first();
    await expect(btn).toBeVisible({ timeout: TIMEOUT });

    await btn.click();
    await expect(page.locator(targetItems)).toHaveCount(1, { timeout: TIMEOUT });
    await btn.click();
    await expect(page.locator(targetItems)).toHaveCount(2, { timeout: TIMEOUT });

    await expect(page.locator(".target-id").nth(0)).toContainText("e-1");
    await expect(page.locator(".target-id").nth(1)).toContainText("e-1");
  });

  test("duplicate inserts render identical content (nested repeat tunnel leak regression)", async ({ page }) => {
    await page.goto("/perf.html");
    const btn = page.locator(addBtn).first();
    await expect(btn).toBeVisible({ timeout: TIMEOUT });

    await btn.click();
    await expect(page.locator(targetItems)).toHaveCount(1, { timeout: TIMEOUT });
    await btn.click();
    await expect(page.locator(targetItems)).toHaveCount(2, { timeout: TIMEOUT });

    // Both items should have the same label content — if splice-position
    // leaks to nested repeats, the second item will be missing children
    const item1Html = await page.locator(targetItems).nth(0).locator(".target-label").textContent();
    const item2Html = await page.locator(targetItems).nth(1).locator(".target-label").textContent();
    expect(item2Html?.trim()).toBe(item1Html?.trim());
  });
});

// ── Delete (splice invalidation) ──

test.describe("Perf XForm — delete", () => {
  test("clicking ✕ removes an entry from target", async ({ page }) => {
    await page.goto("/perf.html");
    const addBtns = page.locator(addBtn);
    await expect(addBtns.first()).toBeVisible({ timeout: TIMEOUT });

    // Add two items
    await addBtns.nth(0).click();
    await addBtns.nth(1).click();
    await expect(page.locator(targetItems)).toHaveCount(2, { timeout: TIMEOUT });

    // Delete the first
    const removeBtn = page.locator(targetItems).first()
      .locator("a.xforms-trigger").filter({ hasText: "✕" });
    await removeBtn.click();
    await expect(page.locator(targetItems)).toHaveCount(1, { timeout: TIMEOUT });
  });

  test("after delete, remaining entry has correct identity", async ({ page }) => {
    await page.goto("/perf.html");
    const addBtns = page.locator(addBtn);
    await expect(addBtns.first()).toBeVisible({ timeout: TIMEOUT });

    await addBtns.nth(0).click();
    await addBtns.nth(1).click();
    await expect(page.locator(targetItems)).toHaveCount(2, { timeout: TIMEOUT });

    // Delete first entry (e-1); second entry (e-2) should remain
    const removeBtn = page.locator(targetItems).first()
      .locator("a.xforms-trigger").filter({ hasText: "✕" });
    await removeBtn.click();
    await expect(page.locator(targetItems)).toHaveCount(1, { timeout: TIMEOUT });
    await expect(page.locator(".target-id").first()).toContainText("e-2");
  });

  test("insert after delete works correctly", async ({ page }) => {
    await page.goto("/perf.html");
    const addBtns = page.locator(addBtn);
    await expect(addBtns.first()).toBeVisible({ timeout: TIMEOUT });

    // Add e-1, delete it, add e-3
    await addBtns.nth(0).click();
    await expect(page.locator(targetItems)).toHaveCount(1, { timeout: TIMEOUT });

    const removeBtn = page.locator(targetItems).first()
      .locator("a.xforms-trigger").filter({ hasText: "✕" });
    await removeBtn.click();
    await expect(page.locator(targetItems)).toHaveCount(0, { timeout: TIMEOUT });

    await addBtns.nth(2).click();
    await expect(page.locator(targetItems)).toHaveCount(1, { timeout: TIMEOUT });
    await expect(page.locator(".target-id").first()).toContainText("e-3");
  });
});

// ── 6a: source repeat stability ──

test.describe("Perf XForm — source repeat stability (6a)", () => {
  test("source list retains 5 entries after multiple target inserts", async ({ page }) => {
    await page.goto("/perf.html");
    const addBtns = page.locator(addBtn);
    await expect(addBtns.first()).toBeVisible({ timeout: TIMEOUT });

    for (let i = 0; i < 3; i++) {
      await addBtns.nth(i).click();
      await expect(page.locator(targetItems)).toHaveCount(i + 1, { timeout: TIMEOUT });
    }

    // Source should still have exactly 5 items with correct IDs
    await expect(page.locator(".source-item")).toHaveCount(5);
    await expect(page.locator("#source-count-output")).toContainText("5");
    await expect(page.locator(".source-id").nth(0)).toContainText("e-1");
    await expect(page.locator(".source-id").nth(4)).toContainText("e-5");
  });
});
