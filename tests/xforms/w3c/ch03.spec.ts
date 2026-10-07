import {  test, expect, loadTest, loadAndWait, getInstanceXML, submitAndCapture, collectDialogMessages, getFormControlText } from "./helpers";

const ch3_smoke: [string, string][] = [
  ["3.2.1.a — foreign elements", "Chapt03/3.2/3.2.1/3.2.1.a.xhtml"],
  ["3.2.3.e — binding exception (ref+bind)", "Chapt03/3.2/3.2.3/3.2.3.e.xhtml"],  // expects xforms-binding-exception message or fatal error
  ["3.2.3.f — binding exception (nodeset+bind)", "Chapt03/3.2/3.2.3/3.2.3.f.xhtml"],  // expects xforms-binding-exception message or fatal error
  ["3.2.4.a — select control items", "Chapt03/3.2/3.2.4/3.2.4.a.xhtml"],
  ["3.2.4.b — select submit", "Chapt03/3.2/3.2.4/3.2.4.b.xhtml"],
  ["3.2.4.c — select submit values", "Chapt03/3.2/3.2.4/3.2.4.c.xhtml"],
  ["3.2.4.e — binding exception (select)", "Chapt03/3.2/3.2.4/3.2.4.e.xhtml"],  // expects xforms-binding-exception message or fatal error
  ["3.2.4.f — binding exception (select)", "Chapt03/3.2/3.2.4/3.2.4.f.xhtml"],  // expects xforms-binding-exception message or fatal error
  ["3.3.1.a1 — no errors expected", "Chapt03/3.3/3.3.1/3.3.1.a1.xhtml"],
  ["3.3.1.a2 — no errors expected", "Chapt03/3.3/3.3.1/3.3.1.a2.xhtml"],
  ["3.3.1.b — compute exception", "Chapt03/3.3/3.3.1/3.3.1.b.xhtml"],  // expects xforms-compute-exception message or fatal error
  ["3.3.1.c1 — no message expected", "Chapt03/3.3/3.3.1/3.3.1.c1.xhtml"],
  ["3.3.1.c2 — link exception", "Chapt03/3.3/3.3.1/3.3.1.c2.xhtml"],  // expects xforms-link-exception message or fatal error
  ["3.3.1.d1 — no version exception", "Chapt03/3.3/3.3.1/3.3.1.d1.xhtml"],
  ["3.3.1.d2 — version exception", "Chapt03/3.3/3.3.1/3.3.1.d2.xhtml"],  // expects xforms-version-exception message or fatal error
  ["3.3.1.d3 — version exception", "Chapt03/3.3/3.3.1/3.3.1.d3.xhtml"],  // expects xforms-version-exception message or fatal error
  ["3.3.2.a — model with no instance", "Chapt03/3.3/3.3.2/3.3.2.a.xhtml"],
  ["3.3.2.d — link exception", "Chapt03/3.3/3.3.2/3.3.2.d.xhtml"],  // expects xforms-link-exception message or fatal error
  ["3.3.2.f — instance @resource", "Chapt03/3.3/3.3.2/3.3.2.f.xhtml"],
  ["3.3.2.g — link exception", "Chapt03/3.3/3.3.2/3.3.2.g.xhtml"],  // expects xforms-link-exception message or fatal error
  ["3.3.2.h — link exception", "Chapt03/3.3/3.3.2/3.3.2.h.xhtml"],  // expects xforms-link-exception message or fatal error
  ["3.4.1.a — extension element", "Chapt03/3.4/3.4.1/3.4.1.a.xhtml"],
  ["3.2.2.a — inline instance", "Chapt03/3.2/3.2.2/3.2.2.a.xhtml"],
  ["3.2.3.b — bind attribute", "Chapt03/3.2/3.2.3/3.2.3.b.xhtml"],
  ["3.2.3.g — nodeset attribute", "Chapt03/3.2/3.2.3/3.2.3.g.xhtml"],
  ["3.3.2.c — instance @src", "Chapt03/3.3/3.3.2/3.3.2.c.xhtml"],
  ["3.3.4.a — bind nodeset", "Chapt03/3.3/3.3.4/3.3.4.a.xhtml"],
  ["3.3.4.b — bind nodeset", "Chapt03/3.3/3.3.4/3.3.4.b.xhtml"],
];

test.describe("W3C Ch3 — Document Structure [smoke]", () => {
  for (const [name, file] of ch3_smoke) {
    test(`${name} renders`, async ({ page }) => { await loadTest(page, file); });
  }
});

test.describe("W3C Ch3 — Document Structure [behavioral]", () => {
  /* You must see a value of "Honda": */
  test("3.1.a — XForms namespace: output shows Honda", async ({ page }) => {
    await loadAndWait(page, "Chapt03/3.1/3.1.a.xhtml");
    const output = page.locator('.xforms-output');
    await expect(output).toHaveText("Honda");
  });

  /* You must see a value of "Mazda": */
  test("3.2.1.b — foreign attributes: output shows Mazda", async ({ page }) => {
    await loadAndWait(page, "Chapt03/3.2/3.2.1/3.2.1.b.xhtml");
    const output = page.locator('.xforms-output');
    await expect(output).toHaveText("Mazda");
  });

  /* You must see the value "120": */
  test("3.2.3.a — ref attribute: outputs show 120 and 1994", async ({ page }) => {
    await loadAndWait(page, "Chapt03/3.2/3.2.3/3.2.3.a.xhtml");
    const outputs = page.locator('.xforms-output');
    const texts = await outputs.allInnerTexts();
    expect(texts).toContain("120");
    expect(texts).toContain("1994");
  });

  /* You must see the value "silver": */
  test("3.2.3.c — context attribute: output shows silver", async ({ page }) => {
    await loadAndWait(page, "Chapt03/3.2/3.2.3/3.2.3.c.xhtml");
    const text = await getFormControlText(page);
    expect(text).toContain("silver");
  });

  /* You must see the value "silver": */
  test("3.2.3.d — model attribute: output shows silver", async ({ page }) => {
    await loadAndWait(page, "Chapt03/3.2/3.2.3/3.2.3.d.xhtml");
    const text = await getFormControlText(page);
    expect(text).toContain("silver");
  });

  /* You must see the value "BMW": */
  test("3.2.4.d — select1 with nodeset: shows BMW", async ({ page }) => {
    await loadAndWait(page, "Chapt03/3.2/3.2.4/3.2.4.d.xhtml");
    const text = await getFormControlText(page);
    expect(text).toContain("BMW");
  });

  /*
     You must see three output fields. The Name output field must have the value "Wendy", the Age
     output field must have the value "20", and the Education output field must have the value
     "college".
  */
  test("3.3.2.b — instance inline: Wendy, 20, college", async ({ page }) => {
    await loadAndWait(page, "Chapt03/3.3/3.3.2/3.3.2.b.xhtml");
    const outputs = page.locator('.xforms-output');
    const texts = await outputs.allInnerTexts();
    expect(texts).toContain("Wendy");
    expect(texts).toContain("20");
    expect(texts).toContain("college");
  });

  /*
     You must see three output fields. The Name output field must have the value "Wendy", the Age
     output field must have the value "20", and the Education output field must have the value
     "college".
  */
  test("3.3.2.e — instance @resource: Wendy", async ({ page }) => {
    await loadAndWait(page, "Chapt03/3.3/3.3.2/3.3.2.e.xhtml");
    const text = await getFormControlText(page);
    expect(text).toContain("Wendy");
  });

  /* You must see a value of "Mazda": */
  test("3.3.a — model element: output shows Mazda", async ({ page }) => {
    await loadAndWait(page, "Chapt03/3.3/3.3.a.xhtml");
    const text = await getFormControlText(page);
    expect(text).toContain("Mazda");
  });

});
