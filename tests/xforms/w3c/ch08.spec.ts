import { test, expect, loadTest, loadAndWait, getRenderedText, getInstanceXML, collectDialogMessages, clickTrigger, normalizeWhitespace, getFormControlText } from "./helpers";

const ch8_1_smoke: [string, string][] = [
  ["8.1.1.a — form control binding restriction", "Chapt08/8.1/8.1.1/8.1.1.a.xhtml"],  // expects xforms-binding-exception message or fatal error
  ["8.1.1.c — relevant becoming non-relevant", "Chapt08/8.1/8.1.1/8.1.1.c.xhtml"],  // expects modal message or error dialog
  ["8.1.2.a — input incremental", "Chapt08/8.1/8.1.2/8.1.2.a.xhtml"],  // depends on incremental update or binding restriction enforcement
  ["8.1.3.a — secret incremental", "Chapt08/8.1/8.1.3/8.1.3.a.xhtml"],  // depends on incremental update or binding restriction enforcement
  ["8.1.3.b — secret binding restrictions", "Chapt08/8.1/8.1.3/8.1.3.b.xhtml"],  // depends on incremental update or binding restriction enforcement
  ["8.1.4.a — textarea incremental", "Chapt08/8.1/8.1.4/8.1.4.a.xhtml"],  // depends on incremental update or binding restriction enforcement
  ["8.1.4.b — textarea binding restrictions", "Chapt08/8.1/8.1.4/8.1.4.b.xhtml"],  // depends on incremental update or binding restriction enforcement
  ["8.1.5.c — output UI common", "Chapt08/8.1/8.1.5/8.1.5.c.xhtml"],  // expects modal message from event handler
  ["8.1.6.a — upload mediatype", "Chapt08/8.1/8.1.6/8.1.6.a.xhtml"],  // non-normative test
  ["8.1.6.b — upload incremental", "Chapt08/8.1/8.1.6/8.1.6.b.xhtml"],  // expects modal message or error dialog
  ["8.1.6.c — upload filename/mediatype", "Chapt08/8.1/8.1.6/8.1.6.c.xhtml"],  // depends on file upload interaction
  ["8.1.6.d — upload binding restrictions", "Chapt08/8.1/8.1.6/8.1.6.d.xhtml"],  // expects xforms-binding-exception message or fatal error
  ["8.1.6.e — upload element", "Chapt08/8.1/8.1.6/8.1.6.e.xhtml"],  // depends on file upload interaction
  ["8.1.7.f — range binding restrictions", "Chapt08/8.1/8.1.7/8.1.7.f.xhtml"],  // depends on incremental update or binding restriction enforcement
  ["8.1.7.g — range binding basic", "Chapt08/8.1/8.1.7/8.1.7.g.xhtml"],  // depends on incremental update or binding restriction enforcement
  ["8.1.9.a — submit", "Chapt08/8.1/8.1.9/8.1.9.a.xhtml"],  // no testable output criteria in spec
  ["8.1.10.d — select out of range", "Chapt08/8.1/8.1.10/8.1.10.d.xhtml"],  // expects modal message after trigger activation
  ["8.1.11.d — select1 out of range", "Chapt08/8.1/8.1.11/8.1.11.d.xhtml"],  // expects modal message after trigger activation
];

const ch8_2_smoke: [string, string][] = [
  ["8.2.4.a — alert refs instance", "Chapt08/8.2/8.2.4/8.2.4.a.xhtml"],  // expects modal message from event handler
  ["8.2.4.b — alert inline text", "Chapt08/8.2/8.2.4/8.2.4.b.xhtml"],  // expects modal message from event handler
  ["8.2.4.c — alert binding precedence", "Chapt08/8.2/8.2.4/8.2.4.c.xhtml"],  // expects modal message or error dialog
];

const ch8_3_smoke: [string, string][] = [
  ["8.3.3.a — value binding restrictions", "Chapt08/8.3/8.3.3/8.3.3.a.xhtml"],  // expects modal message or error dialog
];

test.describe("W3C Ch8 — UI [smoke tests]", () => {
  for (const [name, file] of ch8_1_smoke) {
    test(`${name} renders`, async ({ page }) => { await loadTest(page, file); });
  }
  for (const [name, file] of ch8_2_smoke) {
    test(`${name} renders`, async ({ page }) => { await loadTest(page, file); });
  }
  for (const [name, file] of ch8_3_smoke) {
    test(`${name} renders`, async ({ page }) => { await loadTest(page, file); });
  }
});
test.describe("W3C Ch8 — UI [behavioral]", () => {
  /*
     You must see three output controls. The Car Make output control must have the value "Lotus".
     The Car Year output control must have the value "2005". The Car Color output control must have
     the value "Aztec Bronze".
  */
  /*
     You must see an xforms-enabled message, an xforms-value-changed message, an xforms-valid
     message, an xforms-readwrite message, and an xforms-optional message.
  */
  test("8.1.1.b — 8.1.1.b non-relevant form control becoming relevant", async ({ page }) => {
    const dialogMessages = collectDialogMessages(page);
    await loadAndWait(page, "Chapt08/8.1/8.1.1/8.1.1.b.xhtml");
    // TEST-TRACE: Assert required xforms:* modal messages are emitted as JS dialogs.
    await expect(page.locator('input.xforms-input')).toHaveCount(1);
    await page.waitForTimeout(300);
    const normalizedMessages = dialogMessages.map((message) => normalizeWhitespace(message));
    const missingEvents = [
      "xforms-enabled",
      "xforms-value-changed",
      "xforms-valid",
      "xforms-readwrite",
      "xforms-optional",
    ].filter(
      (eventName) =>
        !normalizedMessages.some((message) => new RegExp(`\\b${eventName}\\b`, "i").test(message))
    );
    expect(missingEvents).toEqual([]);
  });

  /*
     This page has two input controls. One is bound to the data type 64Binary and the other to the
     data type hexBinary. Input controls do not correctly bind to these data types. The input
     controls must not work correctly, generate an error, not appear on this page or otherwise make
     the problem known.
  */
  test("8.1.2.b — 8.1.2.b data binding restrictions for input element", async ({ page }) => {
    test.fixme("Binding-restriction handling for xsd:base64Binary/xsd:hexBinary input controls is not implemented yet.");
    await loadAndWait(page, "Chapt08/8.1/8.1.2/8.1.2.b.xhtml");
  });

  /*
     You must see an input bound to a node of type xsd:date. It might be rendered as a calendar
     control. The default value is 1997-12-21.
  */
  test("8.1.2.c — 8.1.2.c datatype bound to input element", async ({ page }) => {
    await loadAndWait(page, "Chapt08/8.1/8.1.2/8.1.2.c.xhtml");
    // TEST-TRACE: Assert typed input defaults, not just control presence.
    const dateInput = page.locator('input[data-ref*="date-of-birth"]');
    await expect(dateInput).toHaveCount(1);
    await expect(dateInput).toHaveValue("1997-12-21");

    const confirmInput = page.locator('input[data-ref*="confirm"]');
    await expect(confirmInput).toHaveCount(1);
    const confirmType = ((await confirmInput.getAttribute("type")) ?? "").toLowerCase();
    if (confirmType === "checkbox") {
      await expect(confirmInput).not.toBeChecked();
    } else {
      await expect(confirmInput).toHaveValue(/false/i);
    }

    const xml = await getInstanceXML(page);
    expect(xml).toContain("<date-of-birth");
    expect(xml).toContain(">1997-12-21<");
    expect(xml).toContain("<confirm");
    expect(xml).toContain(">false<");
  });

  /* You should see the "calendar-picker-open.png" image. */
  test("8.1.5.1.a — 8.1.5.1.a mediatype element", async ({ page }) => {
    test.fixme("Dynamic output rendering from xf:mediatype child content is not implemented yet.");
    await loadAndWait(page, "Chapt08/8.1/8.1.5/8.1.5.1/8.1.5.1.a.xhtml");
  });
  test("8.1.5.a — output controls show car instance values", async ({ page }) => {
    await loadAndWait(page, "Chapt08/8.1/8.1.5/8.1.5.a.xhtml");
    // Scoped: check output elements contain expected car data
    const outputs = page.locator('.xforms-output');
    const texts = await outputs.allInnerTexts();
    expect(texts).toContain("Lotus");
    expect(texts).toContain("2005");
    expect(texts).toContain("Aztec Bronze");
    // Instance data
    const xml = await getInstanceXML(page);
    expect(xml).toContain(">Lotus<");
    expect(xml).toContain(">2005<");
    expect(xml).toContain(">Aztec Bronze<");
  });
  /*
     You must see the value "1032" for the Tax output control and the value "2005" for the Car Year
     output control.
  */
  test("8.1.5.b output with @value and @bind — bind takes precedence", async ({ page }) => {
    await loadAndWait(page, "Chapt08/8.1/8.1.5/8.1.5.b.xhtml");
    // Tax output: value="0.024 * /car/price" → 1032
    // Car Year output: value="/car/price" bind="year_bind" → bind wins, shows 2005
    const text = await getFormControlText(page);
    expect(text).toContain("1032");
    expect(text).toContain("2005");
  });

  /* You should see the "calendar-picker-open.png" image. */
  test("8.1.5.d — 8.1.5.d mediatype attribute", async ({ page }) => {
    test.fixme("Output mediatype-driven image rendering is not implemented yet.");
    await loadAndWait(page, "Chapt08/8.1/8.1.5/8.1.5.d.xhtml");
  });

  /*
     After using the upload control to select a file you must see the file name displayed in the
     Filename output control.
  */
  test("8.1.6.1.a — 8.1.6.1.a filename element", async ({ page }) => {
    await loadAndWait(page, "Chapt08/8.1/8.1.6/8.1.6.1/8.1.6.1.a.xhtml");
    const text = await getRenderedText(page);
    expect(text).not.toBe("");
    // the expected outcome is part of the native file input behavior and cannot be programmatically asserted
    test.fixme();
  });

  /*
     After using the upload control to select a file you must see the file type displayed in the
     Mediatype output control.
  */
  test("8.1.6.2.a — 8.1.6.2.a mediatype element", async ({ page }) => {
    await loadAndWait(page, "Chapt08/8.1/8.1.6/8.1.6.2/8.1.6.2.a.xhtml");
    const uploadInput = page.locator("input[type='file']");
    await expect(uploadInput).toHaveCount(1);

    // TEST-TRACE: Exercise xf:upload with a concrete XML file and assert resulting mediatype.
    await uploadInput.setInputFiles({
      name: "simple.xml",
      mimeType: "application/xml",
      buffer: Buffer.from("<?xml version=\"1.0\"?><root><value>1</value></root>", "utf8"),
    });
    await page.waitForTimeout(500);

    const mediatypeOutput = page.locator(".xforms-output[data-ref*='@type']");
    await expect(mediatypeOutput).toHaveCount(1);
    await expect(mediatypeOutput.locator("xpath=..")).toContainText(/Mediatype\s*:\s*application\/xml/i);

    const xml = await getInstanceXML(page);
    expect(xml).toMatch(/<attachment[^>]*\btype=\"application\/xml\"/i);
  });

  /* You must see a range control that starts at 1000. No end value is defined. */
  test("8.1.7.a — 8.1.7.a start attribute of range element", async ({ page }) => {
    await loadAndWait(page, "Chapt08/8.1/8.1.7/8.1.7.a.xhtml");
    // TEST-TRACE: Verify xf:range @start maps to native range min/value and bound output.
    const rangeInput = page.locator("input[type='range'][data-ref*='mileage']");
    await expect(rangeInput).toHaveCount(1);
    await expect(rangeInput).toHaveAttribute("min", "1000");
    await expect(rangeInput).toHaveValue("1000");
    await expect(page.locator(".xforms-output[data-ref*='mileage']").locator("xpath=..")).toContainText(/Car mileage\s*:\s*1000/);
  });

  /* You must see a range control that ends at 50000. No start value is defined. */
  test("8.1.7.b — 8.1.7.b end attribute of range element", async ({ page }) => {
    await loadAndWait(page, "Chapt08/8.1/8.1.7/8.1.7.b.xhtml");
    // TEST-TRACE: Verify xf:range @end maps to native range max and initial bound value.
    const rangeInput = page.locator("input[type='range'][data-ref*='mileage']");
    await expect(rangeInput).toHaveCount(1);
    await expect(rangeInput).toHaveAttribute("max", "50000");
    await expect(rangeInput).toHaveValue("50000");
    await expect(page.locator(".xforms-output[data-ref*='mileage']").locator("xpath=..")).toContainText(/Car mileage\s*:\s*50000/);
  });

  /* You must see a range control that increments by 2. No start or end values are defined. */
  test("8.1.7.c — 8.1.7.c step attribute of range element", async ({ page }) => {
    await loadAndWait(page, "Chapt08/8.1/8.1.7/8.1.7.c.xhtml");
    // TEST-TRACE: Verify xf:range @step and value propagation to output/instance.
    const rangeInput = page.locator("input[type='range'][data-ref*='age']");
    await expect(rangeInput).toHaveCount(1);
    await expect(rangeInput).toHaveAttribute("step", "2");
    await rangeInput.evaluate((input) => {
      (input as HTMLInputElement).value = "4";
      input.dispatchEvent(new Event("change", { bubbles: true }));
    });
    await page.waitForTimeout(250);
    await expect(page.locator(".xforms-output[data-ref*='age']").locator("xpath=..")).toContainText(/Car age\s*:\s*4/);
    const xml = await getInstanceXML(page);
    expect(xml).toContain(">4<");
  });

  /*
     You must see a range control that displays an xforms-value-changed message when you change its
     value.
  */
  test("8.1.7.d — 8.1.7.d incremental attribute of range element", async ({ page }) => {
    const dialogMessages = collectDialogMessages(page);
    await loadAndWait(page, "Chapt08/8.1/8.1.7/8.1.7.d.xhtml");
    // TEST-TRACE: Verify incremental slider change dispatches xforms-value-changed and updates model.
    const rangeInput = page.locator("input[type='range'][data-ref*='age']");
    await expect(rangeInput).toHaveCount(1);
    await rangeInput.evaluate((input) => {
      (input as HTMLInputElement).value = "7";
      input.dispatchEvent(new Event("input", { bubbles: true }));
    });
    await page.waitForTimeout(300);
    const normalizedMessages = dialogMessages.map((message) => normalizeWhitespace(message));
    expect(normalizedMessages.some((message) => /\bxforms-value-changed\b/i.test(message))).toBe(true);
    await expect(page.locator(".xforms-output[data-ref*='age']").locator("xpath=..")).toContainText(/Car age\s*:\s*7/);
    const xml = await getInstanceXML(page);
    expect(xml).toContain(">7<");
  });

  /* You should see a range control with range of -2 to 2 and increments by 0.5. */
  test("8.1.7.e — 8.1.7.e example of range element", async ({ page }) => {
    await loadAndWait(page, "Chapt08/8.1/8.1.7/8.1.7.e.xhtml");
    // TEST-TRACE: Verify min/max/step mapping for decimal xf:range and output reflection.
    const rangeInput = page.locator("input[type='range'][data-ref*='balance']");
    await expect(rangeInput).toHaveCount(1);
    expect(Number(await rangeInput.getAttribute("min"))).toBe(-2);
    expect(Number(await rangeInput.getAttribute("max"))).toBe(2);
    expect(Number(await rangeInput.getAttribute("step"))).toBe(0.5);
    await rangeInput.evaluate((input) => {
      (input as HTMLInputElement).value = "1.5";
      input.dispatchEvent(new Event("input", { bubbles: true }));
    });
    await page.waitForTimeout(300);
    await expect(page.locator(".xforms-output[data-ref*='balance']").locator("xpath=..")).toContainText(/Balance\s*:\s*1\.5/);
    const xml = await getInstanceXML(page);
    expect(xml).toContain(">1.5<");
  });
  /*
     When you activate the DOMActivate trigger control you must see a DOMActivate message.
  */
  test("8.1.8.a — DOMActivate trigger shows popup", async ({ page }) => {
    const dialogMessages = collectDialogMessages(page);
    await loadAndWait(page, "Chapt08/8.1/8.1.8/8.1.8.a.xhtml");
    // TEST-TRACE: Verify clicking the DOMActivate trigger emits the expected modal dialog message.
    await clickTrigger(page, "DOMActivate");
    await page.waitForTimeout(300);
    const normalizedMessages = dialogMessages.map((message) => normalizeWhitespace(message));
    expect(normalizedMessages.some((message) => /\bDOMActivate\b/i.test(message))).toBe(true);
  });

  /*
     You must see two trigger controls on this page, one labeled "Regular Trigger" and the other
     labeled "Minimal Trigger". They may look different.
  */
  test("8.1.8.b — two trigger controls rendered", async ({ page }) => {
    await loadAndWait(page, "Chapt08/8.1/8.1.8/8.1.8.b.xhtml");
    const text = await getFormControlText(page);
    expect(text).toContain("Regular Trigger");
    expect(text).toContain("Minimal Trigger");
  });

  /*
     You must see two submit controls on this page, one labeled "Regular Submit" and the other
     labeled "Minimal Submit". They may look different.
  */
  test("8.1.9.b — two submit controls rendered", async ({ page }) => {
    await loadAndWait(page, "Chapt08/8.1/8.1.9/8.1.9.b.xhtml");
    const text = await getFormControlText(page);
    expect(text).toContain("Regular Submit");
    expect(text).toContain("Minimal Submit");
  });

  /*
     You must be able to both select a value from the Select A Flavor select control and enter your
     own value into it.
  */
  test("8.1.10.a — 8.1.10.a selection attribute of select element", async ({ page }) => {
    test.fixme("xf:select selection='open' custom value entry is not implemented yet.");
    await loadAndWait(page, "Chapt08/8.1/8.1.10/8.1.10.a.xhtml");
  });
  // --- Render checks ---
  /*
     You must see an xforms-value-changed message whenever you change the selection in the Select A
     Flavor select control. When you make a selection a list of the first letter of the flavor(s)
     must be displayed in the Selected Flavor output control.
  */
  test("8.1.10.b — select incremental dispatches xforms-value-changed", async ({ page }) => {
    const dialogMessages = collectDialogMessages(page);
    await loadAndWait(page, "Chapt08/8.1/8.1.10/8.1.10.b.xhtml");
    // TEST-TRACE: Promote smoke coverage by asserting incremental select updates dialog, output, and instance.
    const flavorSelect = page.locator("div.xforms-select select");
    await expect(flavorSelect).toHaveCount(1);
    await flavorSelect.selectOption(["v"]);
    await page.waitForTimeout(300);
    const normalizedMessages = dialogMessages.map((message) => normalizeWhitespace(message));
    expect(normalizedMessages.some((message) => /\bxforms-value-changed\b/i.test(message))).toBe(true);
    await expect(page.locator(".xforms-output[data-ref*='flavor']").locator("xpath=..")).toContainText(/Selected Flavor\s*:\s*v/);
    const xml = await getInstanceXML(page);
    expect(xml).toContain("<flavor>v</flavor>");
  });

  /*
     You must see three select controls each with a different value for appearance (Full, Compact,
     or Minimal). When you make a selection a list of the first letter of the flavor(s) must be
     displayed in the Selected Flavor output control. Each letter is separated by a space in the
     list.
  */
  test("8.1.10.c — three select appearances (full, compact, minimal)", async ({ page }) => {
    await loadAndWait(page, "Chapt08/8.1/8.1.10/8.1.10.c.xhtml");
    // TEST-TRACE: Assert xf:select appearance wiring and enforced minimal->compact degrade for Chapt08/8.1/8.1.10/8.1.10.c.xhtml.
    const fullSelect = page.locator("select[data-appearance-requested='full']").first();
    const compactSelect = page.locator("select[data-appearance-requested='compact']").first();
    const minimalSelect = page.locator("select[data-appearance-requested='minimal']").first();
    const selectedFlavorOutput = page.locator(".xforms-output[data-ref*='flavor']").locator("xpath=..").first();

    await expect(fullSelect).toHaveCount(1);
    await expect(fullSelect).toHaveAttribute("data-appearance", "full");
    await expect(fullSelect).toHaveAttribute("multiple", /^(true|multiple)$/);

    await expect(compactSelect).toHaveCount(1);
    await expect(compactSelect).toHaveAttribute("data-appearance", "compact");
    await expect(compactSelect).toHaveAttribute("multiple", /^(true|multiple)$/);

    await expect(minimalSelect).toHaveCount(1);
    await expect(minimalSelect).toHaveAttribute("data-appearance", "compact");
    await expect(minimalSelect).toHaveAttribute("data-appearance-degraded", "true");
    await expect(minimalSelect).toHaveAttribute("multiple", /^(true|multiple)$/);

    await fullSelect.selectOption(["v"]);
    await expect(selectedFlavorOutput).toContainText(/Selected Flavor\s*:\s*v/);
    await compactSelect.selectOption(["s"]);
    await expect(selectedFlavorOutput).toContainText(/Selected Flavor\s*:\s*s/);
    await minimalSelect.selectOption(["c"]);
    await expect(selectedFlavorOutput).toContainText(/Selected Flavor\s*:\s*c/);
  });

  /*
     You must be able to both select a value from the Select A Flavor select1 control and enter your
     own value into it.
  */
  test("8.1.11.a — 8.1.11.a selection attribute of select1 element", async ({ page }) => {
    test.fixme("xf:select1 selection='open' custom value entry is not implemented yet.");
    await loadAndWait(page, "Chapt08/8.1/8.1.11/8.1.11.a.xhtml");
  });

  /*
     You must see an xforms-value-changed message whenever you change the selection in the Select A
     Flavor select1 control. When you make a selection the first letter of the flavor must be
     displayed in the Selected Flavor output control.
  */
  test("8.1.11.b — select1 incremental dispatches xforms-value-changed", async ({ page }) => {
    const dialogMessages = collectDialogMessages(page);
    await loadAndWait(page, "Chapt08/8.1/8.1.11/8.1.11.b.xhtml");
    // TEST-TRACE: Promote smoke coverage by asserting incremental select1 updates dialog, output, and instance.
    const flavorSelect1 = page.locator("div.xforms-select select");
    await expect(flavorSelect1).toHaveCount(1);
    await flavorSelect1.selectOption("s");
    await page.waitForTimeout(300);
    const normalizedMessages = dialogMessages.map((message) => normalizeWhitespace(message));
    expect(normalizedMessages.some((message) => /\bxforms-value-changed\b/i.test(message))).toBe(true);
    await expect(page.locator(".xforms-output[data-ref*='flavor']").locator("xpath=..")).toContainText(/Selected Flavor\s*:\s*s/);
    const xml = await getInstanceXML(page);
    expect(xml).toContain("<flavor>s</flavor>");
  });

  /*
     You must see three select1 controls each with a different value for appearance (Full, Compact,
     or Minimal). When you make a selection the first letter of the flavor must be displayed in the
     Selected Flavor output control.
  */
  test("8.1.11.c — three select1 appearances (full, compact, minimal)", async ({ page }) => {
    await loadAndWait(page, "Chapt08/8.1/8.1.11/8.1.11.c.xhtml");
    // TEST-TRACE: Assert xf:select1 appearance wiring for full/compact/minimal and output updates for each control in Chapt08/8.1/8.1.11/8.1.11.c.xhtml.
    const fullSelect1 = page.locator("select[data-appearance-requested='full']").first();
    const compactSelect1 = page.locator("select[data-appearance-requested='compact']").first();
    const minimalSelect1 = page.locator("select[data-appearance-requested='minimal']").first();
    const selectedFlavorOutput = page.locator(".xforms-output[data-ref*='flavor']").locator("xpath=..").first();

    await expect(fullSelect1).toHaveCount(1);
    await expect(fullSelect1).toHaveAttribute("data-appearance", "full");
    await expect(fullSelect1).toHaveAttribute("size", "3");

    await expect(compactSelect1).toHaveCount(1);
    await expect(compactSelect1).toHaveAttribute("data-appearance", "compact");
    await expect(compactSelect1).toHaveAttribute("size", "2");

    await expect(minimalSelect1).toHaveCount(1);
    await expect(minimalSelect1).toHaveAttribute("data-appearance", "minimal");
    await expect(minimalSelect1).not.toHaveAttribute("size", /.*/);

    await fullSelect1.selectOption("v");
    await expect(selectedFlavorOutput).toContainText(/Selected Flavor\s*:\s*v/);
    await compactSelect1.selectOption("s");
    await expect(selectedFlavorOutput).toContainText(/Selected Flavor\s*:\s*s/);
    await minimalSelect1.selectOption("c");
    await expect(selectedFlavorOutput).toContainText(/Selected Flavor\s*:\s*c/);
  });

  /*
     This test case is non-normative and assumes that navindex attributes will be recognized and
     interpreted as described in section 4.3.1 of the specification. Navigation order must be the
     Name input first, the Quantity input second, and the Item input third. Keyboard users can use
     the Tab key to test the navigation order. The input controls are also set to use access keys.
     Keyboard users can hold down the Alt key, the Shift key, and the key in parentheses in the
     labels of the input controls to jump directly to an input control.
  */
  test("8.1.a — 8.1.a navindex and accesskey (non-normative)", async ({ page }) => {
    await loadAndWait(page, "Chapt08/8.1/8.1.a.xhtml");
    // TEST-TRACE: Verify navindex/accesskey rendering and keyboard tab order; helps tests/w3c/ch08.spec.ts "8.1.a".
    const nameInput = page.locator("input.xforms-input[data-ref*='name']");
    const quantityInput = page.locator("input.xforms-input[data-ref*='quantity']");
    const itemInput = page.locator("input.xforms-input[data-ref*='item']");
    await expect(nameInput).toHaveCount(1);
    await expect(quantityInput).toHaveCount(1);
    await expect(itemInput).toHaveCount(1);
    await expect(nameInput).toHaveAttribute("tabindex", "1");
    await expect(quantityInput).toHaveAttribute("tabindex", "2");
    await expect(itemInput).toHaveAttribute("tabindex", "3");
    await expect(nameInput).toHaveAttribute("accesskey", "n");
    await expect(quantityInput).toHaveAttribute("accesskey", "q");
    await expect(itemInput).toHaveAttribute("accesskey", "i");
    await nameInput.focus();
    await page.keyboard.press("Tab");
    await expect(quantityInput).toBeFocused();
    await page.keyboard.press("Tab");
    await expect(itemInput).toBeFocused();
  });

  /* You must see an input control with the label "Instance Data". */
  test("8.2.1.a — 8.2.1.a label element references instance data", async ({ page }) => {
    await loadAndWait(page, "Chapt08/8.2/8.2.1/8.2.1.a.xhtml");
    // TEST-TRACE: Assert xf:label @ref resolves from instance data onto rendered input; helps tests/w3c/ch08.spec.ts "8.2.1.a".
    const inputControl = page.locator("div.xforms-input").filter({ has: page.locator("input.xforms-input") });
    await expect(inputControl).toHaveCount(1);
    await expect(inputControl.locator("input.xforms-input")).toHaveAttribute("data-ref", /myinput/);
    await expect(inputControl.locator("label")).toHaveText(/^\s*Instance Data\s*$/);
  });

  /* You must see an input control with the label "Inline Text". */
  test("8.2.1.b — 8.2.1.b label element uses inline text", async ({ page }) => {
    await loadAndWait(page, "Chapt08/8.2/8.2.1/8.2.1.b.xhtml");
    // TEST-TRACE: Assert inline xf:label text renders on input control when no binding reference exists; helps tests/w3c/ch08.spec.ts "8.2.1.b".
    const inputControl = page.locator("div.xforms-input").filter({ has: page.locator("input.xforms-input") });
    await expect(inputControl).toHaveCount(1);
    await expect(inputControl.locator("input.xforms-input")).toHaveAttribute("data-ref", /myinput/);
    await expect(inputControl.locator("label")).toHaveText(/^\s*Inline Text\s*$/);
  });

  /* You must see an input control with the label "Instance Data". */
  test("8.2.1.c — 8.2.1.c label element has binding precedence", async ({ page }) => {
    await loadAndWait(page, "Chapt08/8.2/8.2.1/8.2.1.c.xhtml");
    // TEST-TRACE: Assert xf:label @ref takes precedence over inline fallback text; helps tests/w3c/ch08.spec.ts "8.2.1.c".
    const inputControl = page.locator("div.xforms-input").filter({ has: page.locator("input.xforms-input") });
    await expect(inputControl).toHaveCount(1);
    await expect(inputControl.locator("input.xforms-input")).toHaveAttribute("data-ref", /myinput/);
    await expect(inputControl.locator("label")).toHaveText(/^\s*Instance Data\s*$/);
  });

  /*
     You must see a select control and a select1 control on the page. The select control must
     contain three choices elements labeled Group 1, Group 2, and Group 3. The select1 control must
     contain three choices elements labeled Group 4, Group 5, Group 6.
  */
  test("8.3.1.a — 8.3.1.a choices element", async ({ page }) => {
    await loadAndWait(page, "Chapt08/8.3/8.3.1/8.3.1.a.xhtml");
    // TEST-TRACE: Assert xforms:choices renders as grouped options with expected labels/values; helps tests/w3c/ch08.spec.ts "8.3.1.a".
    const selectControl = page.locator("div.xforms-select").filter({ has: page.locator("select[multiple]") });
    const select1Control = page.locator("div.xforms-select").filter({ has: page.locator("select:not([multiple])") });
    await expect(selectControl).toHaveCount(1);
    await expect(select1Control).toHaveCount(1);

    const selectChoiceLabels = await selectControl
      .locator("optgroup")
      .evaluateAll((groups) => groups.map((group) => group.getAttribute("label") ?? ""));
    expect(selectChoiceLabels).toEqual(["Group 1", "Group 2", "Group 3"]);
    const selectChoiceValues = await selectControl
      .locator("optgroup option")
      .evaluateAll((options) => options.map((option) => (option as HTMLOptionElement).value));
    expect(selectChoiceValues).toEqual(["vanilla", "chocolate", "orangeCreamsicle", "fudgeRipple", "yuck", "whyBother"]);

    const select1ChoiceLabels = await select1Control
      .locator("optgroup")
      .evaluateAll((groups) => groups.map((group) => group.getAttribute("label") ?? ""));
    expect(select1ChoiceLabels).toEqual(["Group 4", "Group 5", "Group 6"]);
    const select1ChoiceValues = await select1Control
      .locator("optgroup option")
      .evaluateAll((options) => options.map((option) => (option as HTMLOptionElement).value));
    expect(select1ChoiceValues).toEqual(["vanilla", "chocolate", "orangeCreamsicle", "fudgeRipple", "yuck", "whyBother"]);
  });

  /*
     You must see a select control and a select1 control on the page. The select control must
     contain two item elements labeled Item 1 and Item 2 as well as a choices element labeled
     Special Items that contains another item element labeled Special 3. The select1 control must
     contain two item elements labeled Item 4 and Item 5 as well as a choices element labeled
     Special Items that contains another item element labeled Special 6.
  */
  test("8.3.2.a — 8.3.2.a item element", async ({ page }) => {
    await loadAndWait(page, "Chapt08/8.3/8.3.2/8.3.2.a.xhtml");
    // TEST-TRACE: Assert mixed item + xforms:choices rendering includes Special Items group and nested values; helps tests/w3c/ch08.spec.ts "8.3.2.a".
    const selectControl = page.locator("div.xforms-select").filter({ has: page.locator("select[multiple]") });
    const select1Control = page.locator("div.xforms-select").filter({ has: page.locator("select:not([multiple])") });
    await expect(selectControl).toHaveCount(1);
    await expect(select1Control).toHaveCount(1);

    const selectValues = await selectControl
      .locator("option")
      .evaluateAll((options) => options.map((option) => (option as HTMLOptionElement).value));
    expect(selectValues).toEqual(["item1", "item2", "item3"]);
    const selectSpecialGroups = await selectControl
      .locator("optgroup")
      .evaluateAll((groups) => groups.map((group) => group.getAttribute("label") ?? ""));
    expect(selectSpecialGroups).toEqual(["Special Items"]);
    const selectSpecialValues = await selectControl
      .locator("optgroup option")
      .evaluateAll((options) => options.map((option) => (option as HTMLOptionElement).value));
    expect(selectSpecialValues).toEqual(["item3"]);

    const select1Values = await select1Control
      .locator("option")
      .evaluateAll((options) => options.map((option) => (option as HTMLOptionElement).value));
    expect(select1Values).toEqual(["item4", "item5", "item6"]);
    const select1SpecialGroups = await select1Control
      .locator("optgroup")
      .evaluateAll((groups) => groups.map((group) => group.getAttribute("label") ?? ""));
    expect(select1SpecialGroups).toEqual(["Special Items"]);
    const select1SpecialValues = await select1Control
      .locator("optgroup option")
      .evaluateAll((options) => options.map((option) => (option as HTMLOptionElement).value));
    expect(select1SpecialValues).toEqual(["item6"]);
  });

  /*
     No matter what flavor you choose in the Flavors select1 control the value "Neapolitan" must be
     displayed in the Selected Flavor output control.
  */
  test("8.3.3.b — 8.3.3.b precedence for value element", async ({ page }) => {
    await loadAndWait(page, "Chapt08/8.3/8.3.3/8.3.3.b.xhtml");
    // TEST-TRACE: Assert xf:value @ref precedence drives output to Neapolitan after selection; helps tests/w3c/ch08.spec.ts "8.3.3.b".
    const flavorSelect = page.locator("div.xforms-select select");
    await expect(flavorSelect).toHaveCount(1);
    await flavorSelect.selectOption({ label: "Vanilla" });
    await page.waitForTimeout(250);

    const selectedFlavorOutput = page.locator(".xforms-output[data-ref*='flavor']").locator("xpath=..");
    await expect(selectedFlavorOutput).toHaveCount(1);
    await expect(selectedFlavorOutput).toContainText(/Selected Flavor\s*:\s*Neapolitan/);
  });

  /*
     When you pick a value from the Select A Color select1 control you must see the same value as
     the output for the Your Color output control.
  */
  test("8.3.3.c — select1 value reflected in output", async ({ page }) => {
    await loadAndWait(page, "Chapt08/8.3/8.3.3/8.3.3.c.xhtml");
    // TEST-TRACE: Assert each select1 item value propagates to both rendered output and instance data.
    const colorSelect = page.locator("div.xforms-select select");
    await expect(colorSelect).toHaveCount(1);

    const options = await colorSelect
      .locator("option")
      .evaluateAll((items) =>
        items.map((item) => ({
          label: (item.textContent ?? "").trim(),
          value: (item as HTMLOptionElement).value,
        }))
      );
    expect(options).toEqual([
      { label: "red", value: "red" },
      { label: "blue", value: "blue" },
      { label: "green", value: "green" },
    ]);

    const yourColorOutput = page.locator(".xforms-output[data-ref*='mycolor']").locator("xpath=..");
    await expect(yourColorOutput).toHaveCount(1);

    for (const color of ["red", "blue", "green"]) {
      await colorSelect.selectOption(color);
      await expect(colorSelect).toHaveValue(color);
      const xml = await getInstanceXML(page);
      await expect(yourColorOutput).toContainText(new RegExp(`Your\\s*Color\\s*:\\s*${color}`));
      expect(xml).toContain(`<mycolor>${color}</mycolor>`);
    }
  });


  // --- Known gap: help/hint message dispatch is not implemented ---
  const ch8_promoted_smoke: [string, string][] = [
    ["8.2.2.a — help message (inline)", "Chapt08/8.2/8.2.2/8.2.2.a.xhtml"],
    ["8.2.2.b — help message (src)", "Chapt08/8.2/8.2.2/8.2.2.b.xhtml"],
    ["8.2.2.c — help message (instance)", "Chapt08/8.2/8.2.2/8.2.2.c.xhtml"],
    ["8.2.3.a — hint message (inline)", "Chapt08/8.2/8.2.3/8.2.3.a.xhtml"],
    ["8.2.3.b — hint message (src)", "Chapt08/8.2/8.2.3/8.2.3.b.xhtml"],
    ["8.2.3.c — hint message (instance)", "Chapt08/8.2/8.2.3/8.2.3.c.xhtml"],
  ];
  for (const [name, file] of ch8_promoted_smoke) {
    test(`${name} renders`, async ({ page }) => {
      test.fixme("xforms-help/xforms-hint dispatch message handling is not implemented yet.");
      await loadTest(page, file);
    });
  }
  // Note: help/hint message dispatch tests (8.2.2.a-c, 8.2.3.a-c)
  // are tracked as explicit gaps until xforms-help/xforms-hint behavior is implemented.
});
