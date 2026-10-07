import { test, expect, loadTest, loadAndWait, getRenderedText, getFormControlText, normalizeWhitespace } from "./helpers";

test.describe("W3C Appendix B — Data Mutation Patterns", () => {
  /* You must see an empty person name followed by the person name of "Jane Doe" : */
  test("B.1 Prepend Element Copy", async ({ page }) => {
    await loadAndWait(page, "Appendix/B/B.1/b.1.a.xhtml");
    const outputs = (await page.locator(".hlist").allInnerTexts()).map(normalizeWhitespace);
    expect(outputs).toEqual([
      "",
      "Jane Doe",
    ]);
  });

  /* You must see an empty person name after the person name of "Jane Doe" : */
  test("B.2 Append Element Copy", async ({ page }) => {
    await loadAndWait(page, "Appendix/B/B.2/b.2.a.xhtml");
    const outputs = (await page.locator(".hlist").allInnerTexts()).map(normalizeWhitespace);
    expect(outputs[0]).toBe("Jane Doe");
    expect(outputs.slice(1)).toContain("");
  });

  /* You must see three paragraphs, the last is a duplicate of the second : */
  test("B.3 Duplicate Element", async ({ page }) => {
    await loadAndWait(page, "Appendix/B/B.3/b.3.a.xhtml");
    const outputs = (await page.locator(".hlist").allInnerTexts()).map(normalizeWhitespace);
    expect(outputs).toEqual([
      "Lorem ipsum verterem voluptaria",
      "Primis abhorreant delicatissimi",
      "Primis abhorreant delicatissimi",
    ]);
  });

  /* You must see the string "classified" after each key : */
  test("B.4 Set Attribute", async ({ page }) => {
    await loadAndWait(page, "Appendix/B/B.4/b.4.a.xhtml");
    const outputs = (await page.locator(".hlist").allInnerTexts()).map(normalizeWhitespace);
    expect(outputs).toEqual([
      "23 classified",
      "42 classified",
      "68 classified",
    ]);
  });

  /* You must see only one item product("SKU-0815") : */
  test("B.5 Remove Element", async ({ page }) => {
    await loadAndWait(page, "Appendix/B/B.5/b.5.a.xhtml");
    const text = await getFormControlText(page);
    // Deletes item[2] (SKU-4711) — only item[1] (SKU-0815) should remain
    expect(text).toMatch(/Product\s*:\s*SKU-0815/i);
    expect(text).not.toMatch(/Product\s*:\s*SKU-4711/i);
  });

  /* You must not see the string "classified" after key '23' : */
  test("B.6 Remove Attribute", async ({ page }) => {
    await loadAndWait(page, "Appendix/B/B.6/b.6.a.xhtml");
    const outputs = (await page.locator(".hlist").allInnerTexts()).map(normalizeWhitespace);
    expect(outputs).toEqual(["23"]);
  });

  /* You must not see a Track ID : */
  test("B.7 Remove Nodeset", async ({ page }) => {
    await loadAndWait(page, "Appendix/B/B.7/b.7.a.xhtml");
    const outputs = (await page.locator(".hlist").allInnerTexts()).map(normalizeWhitespace);
    expect(outputs).toEqual([]);
  });

  /* You must see the strings "Jane Doe", "John Doe", and "Joe Sixpack" : */
  test("B.8 Copy Nodeset", async ({ page }) => {
    await loadAndWait(page, "Appendix/B/B.8/b.8.a.xhtml");
    // Copies 3 persons from prototypes into empty <people> — should see all 3 names
    const outputs = (await page.locator(".hlist").allInnerTexts()).map(normalizeWhitespace);
    expect(outputs).toEqual([
      "Jane Doe",
      "John Doe",
      "Joe Sixpack"
    ]);
  });

  /* You must see the string "classified" for each key '0': */
  test("B.9 Copy Attribute List", async ({ page }) => {
    await loadAndWait(page, "Appendix/B/B.9/b.9.a.xhtml");
    const outputs = (await page.locator(".hlist").allInnerTexts()).map(normalizeWhitespace);
    expect(outputs).toEqual([
      "0 classified",
      "0 classified",
    ]);
  });

  /* You must see an empty string for a person name : */
  test("B.10 Replace Element", async ({ page }) => {
    await loadAndWait(page, "Appendix/B/B.10/b.10.a.xhtml");
    const outputs = (await page.locator(".hlist").allInnerTexts()).map(normalizeWhitespace);
    expect(outputs).toEqual([""]);
  });

  /* You must see the value '0' for both item keys : */
  test("B.11 Replace Attribute — both keys show 0", async ({ page }) => {
    await loadAndWait(page, "Appendix/B/B.11/b.11.a.xhtml");
    const outputs = (await page.locator(".hlist").allInnerTexts()).map(normalizeWhitespace);
    expect(outputs).toEqual([
      "0",
      "0",
    ]);
  });

  /* You must not see item product ("SKU-0815") or item product ("SKU-4711") : */
  test("B.12 Replace Instance with Insert", async ({ page }) => {
    await loadAndWait(page, "Appendix/B/B.12/b.12.a.xhtml");
    const outputs = (await page.locator(".hlist").allInnerTexts()).map(normalizeWhitespace);
    expect(outputs).toEqual([]);
  });

  /* You must see Track ids "251", "331" and "461" : */
  test("B.13 Move Element — track ids 251, 331, 461", async ({ page }) => {
    await loadAndWait(page, "Appendix/B/B.13/b.13.a.xhtml");
    const outputs = (await page.locator(".hlist").allInnerTexts()).map(normalizeWhitespace);
    expect(outputs).toEqual([
      "251",
      "331",
      "461",
    ]);
  });

  /* You must see "classified" for key '42' : */
  test("B.14 Move Attribute — classified on key 42", async ({ page }) => {
    await loadAndWait(page, "Appendix/B/B.14/b.14.a.xhtml");
    const text = await getFormControlText(page);
    expect(text).toMatch(/Key\s*:\s*42/i);
  });

  /* You must see an empty paragraph : */
  test("B.15 Insert into Heterogeneous Nodeset — empty paragraph", async ({ page }) => {
    await loadAndWait(page, "Appendix/B/B.15/b.15.a.xhtml");
    const outputs = (await page.locator(".hlist").allInnerTexts()).map(normalizeWhitespace);
    expect(outputs.filter((value) => value !== "")).toEqual([]);
  });
});

const appendix_gaps_smoke: [string, string][] = [
  ["g.1.a", "Appendix/G/G.1/g.1.a.xhtml"],  // non-normative CSS styling test
  ["g.1.b", "Appendix/G/G.1/g.1.b.xhtml"],  // non-normative CSS styling test
  ["g.1.c", "Appendix/G/G.1/g.1.c.xhtml"],  // non-normative CSS styling test
  ["g.1.d", "Appendix/G/G.1/g.1.d.xhtml"],  // non-normative CSS styling test
  ["g.1.e", "Appendix/G/G.1/g.1.e.xhtml"],  // non-normative CSS styling test
  ["g.2.a", "Appendix/G/G.2/g.2.a.xhtml"],  // non-normative CSS styling test
  ["g.2.b", "Appendix/G/G.2/g.2.b.xhtml"],  // non-normative CSS styling test
  ["g.2.c", "Appendix/G/G.2/g.2.c.xhtml"],  // non-normative CSS styling test
  ["g.2.d", "Appendix/G/G.2/g.2.d.xhtml"],  // non-normative CSS styling test
  ["g.3", "Appendix/G/G.3/g.3.xhtml"],  // non-normative test
  ["h.1", "Appendix/H/h.1.xhtml"],  // full application example (Appendix H)
  ["h.2", "Appendix/H/h.2.xhtml"],  // full application example (Appendix H)
];

test.describe("W3C Appendix [smoke]", () => {
  for (const [name, file] of appendix_gaps_smoke) {
    test(`${name} renders`, async ({ page }) => { await loadTest(page, file); });
  }
});
