import { test, expect } from "../fixtures/echo-intercept";

/**
 * Tests for upstream Saxon-Forms issues #19-27.
 * These reproduce data mutation bugs from XForms 1.1 Appendix B.
 *
 * Each test clicks a trigger that performs an xf:insert or xf:delete,
 * then checks the instance data via JS to verify the mutation succeeded.
 *
 * Tests are initially expected to FAIL (confirming the bugs exist).
 * After fixes, they should be flipped to expect success.
 */

const RENDER_TIMEOUT = 15_000;

/** Helper: get serialized instance XML via JS */
async function getInstanceXML(
  page: any,
  instanceId: string
): Promise<string> {
  return page.evaluate((id: string) => {
    const inst = (window as any).getInstance(id);
    if (!inst) return "";
    const s = new XMLSerializer();
    return s.serializeToString(inst);
  }, instanceId);
}

/** Helper: wait for the issues page XForm to render */
async function waitForIssuesForm(page: any) {
  await page.goto("/issues.html");
  const root = page.locator("#issues-root");
  await expect(root).toBeVisible({ timeout: RENDER_TIMEOUT });
}

// =========================================================
// #23 — B.6: Remove Attribute
// Expected: after clicking trigger, item/@rating should be gone
// Bug: delete silently fails, @rating remains
// =========================================================
test.describe("Issue #23 — Remove Attribute (B.6)", () => {
  test("@rating exists before trigger click", async ({ page }) => {
    await waitForIssuesForm(page);
    const xml = await getInstanceXML(page, "i23");
    expect(xml).toContain('rating="classified"');
  });

  test("clicking delete removes @rating", async ({ page }) => {
    await waitForIssuesForm(page);
    const btn = page.locator("button[data-action*='trigger-23']");
    await expect(btn).toBeVisible({ timeout: RENDER_TIMEOUT });
    await btn.click();
    // TEST-TRACE: poll instance mutation instead of sleeping after trigger; helps tests/supplemental/issues.spec.ts "Issue #23".
    await expect.poll(
      async () => (await getInstanceXML(page, "i23")).includes("rating"),
      { timeout: 3_000 }
    ).toBe(false);

    const xml = await getInstanceXML(page, "i23");
    expect(xml).not.toContain("rating");
  });
});

// =========================================================
// #24 — B.7: Remove Nodeset (multiple elements)
// Expected: all <track> elements removed, only <name> remains
// Bug: cardinality error when deleting multiple elements
// =========================================================
test.describe("Issue #24 — Remove Nodeset (B.7)", () => {
  test("3 tracks exist before trigger click", async ({ page }) => {
    await waitForIssuesForm(page);
    const xml = await getInstanceXML(page, "i24");
    expect((xml.match(/<track/g) || []).length).toBe(3);
  });

  test("clicking delete removes all tracks", async ({ page }) => {
    await waitForIssuesForm(page);
    const btn = page.locator("button[data-action*='trigger-24']");
    await expect(btn).toBeVisible({ timeout: RENDER_TIMEOUT });
    await btn.click();
    await expect.poll(
      async () => (await getInstanceXML(page, "i24")).includes("<track"),
      { timeout: 3_000 }
    ).toBe(false);

    const xml = await getInstanceXML(page, "i24");
    expect(xml).not.toContain("<track");
  });
});

// =========================================================
// #21 — B.1: Prepend Element Copy
// Expected: a second <person> appears in <people>
// Bug: 'href' must be specified error
// =========================================================
test.describe("Issue #21 — Prepend Element Copy (B.1)", () => {
  test("1 person exists before trigger click", async ({ page }) => {
    await waitForIssuesForm(page);
    const xml = await getInstanceXML(page, "i21");
    expect((xml.match(/<person/g) || []).length).toBe(1);
  });

  test("clicking insert adds a person from prototype", async ({ page }) => {
    await waitForIssuesForm(page);
    const btn = page.locator("button[data-action*='trigger-21']");
    await expect(btn).toBeVisible({ timeout: RENDER_TIMEOUT });
    await btn.click();
    await expect.poll(
      async () => (await getInstanceXML(page, "i21")).match(/<person/g)?.length ?? 0,
      { timeout: 3_000 }
    ).toBe(2);

    const xml = await getInstanceXML(page, "i21");
    expect((xml.match(/<person/g) || []).length).toBe(2);
  });
});

// =========================================================
// #22 — B.4: Set Attribute (copy attribute to sibling)
// Expected: item[2] gains @rating="classified"
// Bug: cardinality error (XTTE0570)
// =========================================================
test.describe("Issue #22 — Set Attribute (B.4)", () => {
  test("item[2] has no @rating before trigger click", async ({ page }) => {
    await waitForIssuesForm(page);
    const xml = await getInstanceXML(page, "i22");
    // item key="42" should not have rating
    expect(xml).toContain('key="42"');
    // Extract just the item[2] - it should NOT have rating
    const item2Match = xml.match(/<item key="42"[^/]*/);
    expect(item2Match?.[0]).not.toContain("rating");
  });

  test("clicking insert copies @rating to item[2]", async ({ page }) => {
    await waitForIssuesForm(page);
    const btn = page.locator("button[data-action*='trigger-22']");
    await expect(btn).toBeVisible({ timeout: RENDER_TIMEOUT });
    await btn.click();
    await expect.poll(
      async () => (await getInstanceXML(page, "i22")).includes('<item key="42" rating="classified"'),
      { timeout: 3_000 }
    ).toBe(true);

    const xml = await getInstanceXML(page, "i22");
    // item key="42" should now have rating="classified"
    const item2Match = xml.match(/<item key="42"[^/]*/);
    expect(item2Match?.[0]).toContain('rating="classified"');
  });
});

// =========================================================
// #25 — B.12: Replace Instance with Insert
// Expected: instance root replaced with empty <shoppingcart/>, no <item> children
// Bug: empty sequence error (XTTE0570)
// =========================================================
test.describe("Issue #25 — Replace Instance (B.12)", () => {
  test("2 items exist before trigger click", async ({ page }) => {
    await waitForIssuesForm(page);
    const xml = await getInstanceXML(page, "i25");
    expect((xml.match(/<item/g) || []).length).toBe(2);
  });

  test("clicking insert replaces with empty cart", async ({ page }) => {
    await waitForIssuesForm(page);
    const btn = page.locator("button[data-action*='trigger-25']");
    await expect(btn).toBeVisible({ timeout: RENDER_TIMEOUT });
    await btn.click();
    await expect.poll(
      async () => (await getInstanceXML(page, "i25")).includes("<item"),
      { timeout: 3_000 }
    ).toBe(false);

    const xml = await getInstanceXML(page, "i25");
    expect(xml).not.toContain("<item");
  });
});

// =========================================================
// #26 — instance() with immediate predicate in @ref
// Expected: group renders and context resolves to instance('i26')
// Regression: parser falls back to default instance, causing XTTE0570
// =========================================================
test.describe("Issue #26 — instance() predicate in @ref", () => {
  test("group bound to instance('i26')[not(control)] renders", async ({ page }) => {
    await waitForIssuesForm(page);

    const marker = page.locator("#out-26-group");
    await expect(marker).toBeVisible({ timeout: RENDER_TIMEOUT });
    await expect(marker).toContainText("VISIBLE");

    const title = page.locator("#out-26-title");
    await expect(title).toBeVisible({ timeout: RENDER_TIMEOUT });
    await expect(title).toContainText("Predicate Ref");
  });

  test("load does not emit XTTE0570 instanceXML cardinality failure", async ({ page }) => {
    const consoleLogs: string[] = [];
    page.on("console", (msg) => consoleLogs.push(msg.text()));

    await waitForIssuesForm(page);

    const cardinalityErrors = consoleLogs.filter(
      (line) =>
        line.includes("XTTE0570") ||
        line.includes("Required cardinality of value in 'xsl:variable name=\"Q{}instanceXML\"'")
    );
    expect(cardinalityErrors).toEqual([]);
  });
});

// =========================================================
// #27 — Scoped xf:toggle inside xf:repeat
// Expected: toggling one row only affects that row's switch/cases
// =========================================================
test.describe("Issue #27 — Scoped toggle in repeat", () => {
  test("clicking Edit on row 1 does not toggle row 2", async ({ page }) => {
    await waitForIssuesForm(page);

    const rows = page.locator("#repeat-27 > div[data-repeat-item='true']");
    await expect(rows).toHaveCount(2);

    const row1 = rows.nth(0);
    const row2 = rows.nth(1);

    await expect(row1.locator("button[data-action*='trigger-27-edit']")).toBeVisible();
    await expect(row2.locator("button[data-action*='trigger-27-edit']")).toBeVisible();
    await expect(row1.locator("button[data-action*='trigger-27-done']")).toBeHidden();
    await expect(row2.locator("button[data-action*='trigger-27-done']")).toBeHidden();

    await row1.locator("button[data-action*='trigger-27-edit']").click();

    await expect(row1.locator("button[data-action*='trigger-27-done']")).toBeVisible();
    await expect(row2.locator("button[data-action*='trigger-27-edit']")).toBeVisible();
    await expect(row2.locator("button[data-action*='trigger-27-done']")).toBeHidden();
  });
});

// =========================================================
// #28 — class and custom data-* passthrough
// Expected: rendered controls keep custom classes and data attributes
// =========================================================
test.describe("Issue #28 — class + data-* passthrough", () => {
  test("trigger keeps custom class and data-testid", async ({ page }) => {
    await waitForIssuesForm(page);

    const trigger = page.locator("button[data-action*='trigger-28']");
    await expect(trigger).toBeVisible({ timeout: RENDER_TIMEOUT });
    await expect(trigger).toHaveClass(/xforms-trigger/);
    await expect(trigger).toHaveClass(/custom-trigger/);
    await expect(trigger).toHaveAttribute("data-testid", "issue-28-trigger");
  });

  test("output keeps custom class and data-testid", async ({ page }) => {
    await waitForIssuesForm(page);

    const outputWrapper = page.locator("[data-testid='issue-28-output']");
    await expect(outputWrapper).toBeVisible({ timeout: RENDER_TIMEOUT });

    const outputSpan = page.locator("span[id^='output-28-']");
    await expect(outputSpan).toBeVisible({ timeout: RENDER_TIMEOUT });
    await expect(outputSpan).toHaveClass(/xforms-output/);
    await expect(outputSpan).toHaveClass(/custom-output/);
  });
});

// =========================================================
// #29 — xf:group relevance refresh after insert/delete
// Expected: group visibility tracks predicate as controls are added/removed
// =========================================================
test.describe("Issue #29 — group relevance refresh", () => {
  test("empty-state group hides after insert and reappears after delete", async ({ page }) => {
    await waitForIssuesForm(page);

    const group = page.locator("[id^='group-empty-29-']");
    await expect(group).toBeVisible({ timeout: RENDER_TIMEOUT });

    const insertBtn = page.locator("button[data-action*='trigger-29-insert']");
    await expect(insertBtn).toBeVisible();
    await insertBtn.click();

    await expect(group).toBeHidden();
    await expect(page.locator("#out-29-count")).toContainText("1");

    const deleteBtn = page.locator("button[data-action*='trigger-29-delete']");
    await expect(deleteBtn).toBeVisible();
    await deleteBtn.click();

    await expect(group).toBeVisible();
    await expect(page.locator("#out-29-count")).toContainText("0");
  });
});

// =========================================================
// #30 — xf:delete nodeset='.' inside repeat
// Expected: deleting current row updates repeat DOM and instance count
// =========================================================
test.describe("Issue #30 — delete current repeat row", () => {
  test("clicking delete removes one repeat item", async ({ page }) => {
    await waitForIssuesForm(page);

    const repeatRows = page.locator("#repeat-30 > div[data-repeat-item='true']");
    await expect(repeatRows).toHaveCount(2);

    const deleteButtons = page.locator("button[data-action*='trigger-30-delete']");
    await expect(deleteButtons).toHaveCount(2);
    await deleteButtons.first().click();

    await expect(repeatRows).toHaveCount(1);

    const xml = await getInstanceXML(page, "i30");
    expect((xml.match(/<item/g) || []).length).toBe(1);
  });
});

// =========================================================
// #31 — xf:insert fallback when nodeset is empty and no @context
// Expected: insert uses instance root fallback and appends entry
// =========================================================
test.describe("Issue #31 — insert fallback on empty nodeset", () => {
  test("clicking insert adds first entry without explicit context", async ({ page }) => {
    await waitForIssuesForm(page);

    const before = await getInstanceXML(page, "i31");
    expect((before.match(/<entry/g) || []).length).toBe(0);

    const btn = page.locator("button[data-action*='trigger-31-insert']");
    await expect(btn).toBeVisible({ timeout: RENDER_TIMEOUT });
    await btn.click();
    await expect.poll(
      async () => (await getInstanceXML(page, "i31")).match(/<entry/g)?.length ?? 0,
      { timeout: 3_000 }
    ).toBe(1);

    const after = await getInstanceXML(page, "i31");
    expect((after.match(/<entry/g) || []).length).toBe(1);
    await expect(page.locator("#out-31-count")).toContainText("1");
  });
});

// =========================================================
// #32 — current() inside string literals
// Expected: literal "current()" text is preserved (not rewritten)
// =========================================================
test.describe("Issue #32 — current() literal handling", () => {
  test("current() inside quotes remains literal text", async ({ page }) => {
    await waitForIssuesForm(page);

    const output = page.locator("#out-32-contains");
    await expect(output).toBeVisible({ timeout: RENDER_TIMEOUT });
    await expect(output).toContainText("true");
  });
});

// =========================================================
// #33 — explicit avg() namespace prefixes
// Expected: avg() and xforms:avg() keep XForms wrapper semantics (NaN),
//           fn:avg() keeps native fn semantics on empty nodeset (empty string)
// =========================================================
test.describe("Issue #33 — explicit avg() prefixes", () => {
  test("avg(), xforms:avg(), fn:avg() preserve intended semantics", async ({ page }) => {
    // TEST-TRACE: assert explicit fn:/xforms: prefixes are preserved through impose(); helps tests/supplemental/issues.spec.ts "Issue #33".
    const pageErrors: string[] = [];
    page.on("pageerror", (error) => {
      pageErrors.push(String(error?.message ?? ""));
    });
    await waitForIssuesForm(page);
    await expect(page.locator("#issue-33")).toBeVisible({ timeout: RENDER_TIMEOUT });

    // TEST-TRACE: assert semantic split regardless of wrapper display state; helps tests/supplemental/issues.spec.ts "Issue #33".
    const unprefText = (await page.locator("#out-33-unpref").textContent() ?? "").trim();
    const xformsText = (await page.locator("#out-33-xforms").textContent() ?? "").trim();
    expect(unprefText).toBe("NaN");
    expect(xformsText).toBe("NaN");

    const fnAvgText = (await page.locator("#out-33-fn").textContent() ?? "").trim();
    expect(fnAvgText).toBe("");

    const rewriteCorruptionErrors = pageErrors.filter(
      (msg) =>
        /xforms:xforms:avg/i.test(msg) ||
        /fn:xforms:avg/i.test(msg)
    );
    expect(rewriteCorruptionErrors).toEqual([]);
  });
});
