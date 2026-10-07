import { test, expect, loadAndWait, getRenderedText, getInstanceXML, getFormControlText, collectDialogMessages, normalizeWhitespace } from "./helpers";

test.describe("W3C Ch9 — Container Form Controls [behavioral]", () => {
  // -----------------------------------------------------------------
  // 9.1 group
  // -----------------------------------------------------------------

  /*
     You must not be able to see the Street Name and City input controls or they must be somehow
     unavailable to you.
  */
  test("9.1.1.a1 — group relevant=false hides Street Name and City", async ({ page }) => {
    await loadAndWait(page, "Chapt09/9.1/9.1.1/9.1.1.a1.xhtml");
    // group1 binds to shipDate with relevant="false()" → Street Name hidden
    const streetLabel = page.getByText("Street Name", { exact: true });
    await expect(streetLabel).toBeHidden();
    // input2 has relevant="false()" → City hidden
    const cityLabel = page.getByText("City", { exact: true });
    await expect(cityLabel).toBeHidden();
  });

  /*
     You must not be able to see the Street Name and City input controls or they must be somehow
     unavailable to you.
  */
  test("9.1.1.a1 group with bind relevant=false hides children", async ({ page }) => {
    await loadAndWait(page, "Chapt09/9.1/9.1.1/9.1.1.a1.xhtml");
    // group1 binds to shipDate with relevant="false()" — Street Name input must NOT be visible
    const streetLabel = page.getByText("Street Name", { exact: true });
    await expect(streetLabel).toBeHidden();
  });

  /*
     When you activate the Show Out Case trigger you must see "You are now in the Out case" output
     to the screen and a Show In Case trigger. When you activate the Show In Case trigger you must
     see "You are now in the In case" output to the screen and a Show Out Case trigger. When either
     switch is activated you must see an xforms-disabled message and an xforms-enabled message.
  */
  /* TEST-TRACE: scope selectors to .xforms-switch to avoid matching instruction text;
     helps tests/w3c/ch09.spec.ts "9.1.1.a2" */
  test("9.1.1.a2 — group inside switch/case toggles between In and Out", async ({ page }) => {
    await loadAndWait(page, "Chapt09/9.1/9.1.1/9.1.1.a2.xhtml");
    const sw = page.locator('.xforms-switch');
    // Initial state: "In case" is selected — label and trigger visible
    await expect(sw.getByText("You are now in the In case")).toBeVisible();
    const showOutTrigger = page.getByRole("button", { name: "Show Out Case" });
    await expect(showOutTrigger).toBeVisible();
    // Click "Show Out Case" → Out case shown
    await showOutTrigger.click();
    await page.waitForTimeout(500);
    await expect(sw.getByText("You are now in the Out case")).toBeVisible();
    const showInTrigger = page.getByRole("button", { name: "Show In Case" });
    await expect(showInTrigger).toBeVisible();
    // Click "Show In Case" → In case restored
    await showInTrigger.click();
    await page.waitForTimeout(500);
    await expect(sw.getByText("You are now in the In case")).toBeVisible();
    await expect(page.getByRole("button", { name: "Show Out Case" })).toBeVisible();
  });

  /*
     The first element in each of the two groups is a label element. This label should act as a
     label for the entire group. The group labeled "Shipping Address" must include the inputs Street
     Name and City. The group labeled "Shipping Date" must include the inputs Day and Month.
  */
  /* TEST-TRACE: scope assertions to each logical xforms-group and verify group label + child inputs;
     helps tests/w3c/ch09.spec.ts "9.1.1.b" */
  test("9.1.1.b — Shipping Address group has Street Name and City; Shipping Date has Day and Month", async ({ page }) => {
    await loadAndWait(page, "Chapt09/9.1/9.1.1/9.1.1.b.xhtml");

    const groupsWithInputs = page.locator("div.xforms-group").filter({ has: page.locator("div.xforms-input") });
    await expect(groupsWithInputs).toHaveCount(2);

    const shippingAddressGroup = groupsWithInputs.filter({ has: page.getByText("Shipping Address", { exact: true }) });
    await expect(shippingAddressGroup).toHaveCount(1);
    await expect(shippingAddressGroup.locator("xpath=./label")).toHaveText(/^Shipping Address$/);
    await expect(shippingAddressGroup.locator("input[data-ref*='shipTo/street']")).toHaveCount(1);
    await expect(shippingAddressGroup.locator("input[data-ref*='shipTo/city']")).toHaveCount(1);
    await expect(shippingAddressGroup.getByText("Street Name", { exact: false })).toBeVisible();
    await expect(shippingAddressGroup.getByText("City", { exact: false })).toBeVisible();
    await expect(shippingAddressGroup.getByText("Day", { exact: false })).toHaveCount(0);
    await expect(shippingAddressGroup.getByText("Month", { exact: false })).toHaveCount(0);

    const shippingDateGroup = groupsWithInputs.filter({ has: page.getByText("Shipping Date", { exact: true }) });
    await expect(shippingDateGroup).toHaveCount(1);
    await expect(shippingDateGroup.locator("xpath=./label")).toHaveText(/^Shipping Date$/);
    await expect(shippingDateGroup.locator("input[data-ref*='shipDate/day']")).toHaveCount(1);
    await expect(shippingDateGroup.locator("input[data-ref*='shipDate/month']")).toHaveCount(1);
    await expect(shippingDateGroup.getByText("Day", { exact: false })).toBeVisible();
    await expect(shippingDateGroup.getByText("Month", { exact: false })).toBeVisible();
    await expect(shippingDateGroup.getByText("Street Name", { exact: false })).toHaveCount(0);
    await expect(shippingDateGroup.getByText("City", { exact: false })).toHaveCount(0);
  });

  /*
     When you activate the Set Focus To Group 2 trigger it will set the focus to the second group.
     The focus (your cursor) must be inside the Street Name 2 input control of the Billing Address
     group.
  */
  test("9.1.1.c — Set Focus To Group 2 moves focus to Street Name 2", async ({ page }) => {
    await loadAndWait(page, "Chapt09/9.1/9.1.1/9.1.1.c.xhtml");
    // Both groups visible
    await expect(page.getByText("Shipping Address (group 1)")).toBeVisible();
    await expect(page.getByText("Billing Address (group 2)")).toBeVisible();
    // Click the trigger
    await page.getByRole("button", { name: "Set Focus To Group 2" }).click();
    await page.waitForTimeout(500);
    // Street Name 2 input should now have focus
    const streetName2 = page.locator('input[data-ref*="billTo/street"]');
    await expect(streetName2).toBeFocused();
  });

  // -----------------------------------------------------------------
  // 9.2 switch / case
  // -----------------------------------------------------------------

  /*
     When you activate the In Case trigger it must be replaced by the Out Case trigger. When you
     activate the Out Case trigger it must be replaced by the In Case trigger.
  */
  test("9.2.1.a1 — switch toggles between Case In and Case Out triggers", async ({ page }) => {
    await loadAndWait(page, "Chapt09/9.2/9.2.1/9.2.1.a1.xhtml");
    // Initial: "Case In" trigger visible, "Case Out" hidden
    const caseInBtn = page.getByRole("button", { name: "Case In" });
    const caseOutBtn = page.getByRole("button", { name: "Case Out" });
    await expect(caseInBtn).toBeVisible();
    await expect(caseOutBtn).toBeHidden();
    // Click "Case In" → "Case Out" visible, "Case In" hidden
    await caseInBtn.click();
    await page.waitForTimeout(500);
    await expect(caseOutBtn).toBeVisible();
    await expect(caseInBtn).toBeHidden();
    // Click "Case Out" → "Case In" visible again
    await caseOutBtn.click();
    await page.waitForTimeout(500);
    await expect(caseInBtn).toBeVisible();
    await expect(caseOutBtn).toBeHidden();
  });

  /*
     When you choose "yes" in the select1 control, you should see the message "Switch is readonly"
     and the select1 control should be readonly too.
  */
  test("9.2.1.a2 — switch readonly event and readonly select1 behavior", async ({ page }) => {
    const dialogMessages = collectDialogMessages(page);
    await loadAndWait(page, "Chapt09/9.2/9.2.1/9.2.1.a2.xhtml");
    // TEST-TRACE: keep strict 9.2.1.a2 pass criteria without xfail masking so readonly regressions fail visibly.
    const haveCarSelect = page.locator("div.xforms-select select");
    await expect(haveCarSelect).toHaveCount(1);
    await expect(haveCarSelect).toHaveValue("no");

    await haveCarSelect.selectOption("yes");
    await page.waitForTimeout(300);
    await expect(haveCarSelect).toHaveValue("yes");
    const normalizedMessages = dialogMessages.slice(beforeSelectionMessages).map((message) => normalizeWhitespace(message));
    expect(normalizedMessages.some((message) => /Switch is readonly/i.test(message))).toBe(true);

    await haveCarSelect.selectOption("no");
    await page.waitForTimeout(300);
    await expect(haveCarSelect).toHaveValue("yes");

    const xml = await getInstanceXML(page);
    expect(xml).toContain("<haveCar>yes</haveCar>");
  });

  /*
     When you activate the Send Name trigger, the input control and the trigger will be replaced by
     an output that says "Hello" followed by whatever value was in the input control when it was
     activated and an Edit trigger. When activated, the output and the Edit trigger must be replaced
     by the input field and the Send Name trigger.
  */
  test("9.2.1.b — Send Name shows Hello output; Edit restores input", async ({ page }) => {
    await loadAndWait(page, "Chapt09/9.2/9.2.1/9.2.1.b.xhtml");
    // Initial state: input with "Bill" + "Send Name" trigger
    // Note: ref="/yourname" is the root element, so data-ref won't contain
    // "yourname" — use the class selector instead.
    const nameInput = page.locator('input.xforms-input');
    await expect(nameInput).toBeVisible();
    await expect(nameInput).toHaveValue("Bill");
    const sendBtn = page.getByRole("button", { name: "Send Name" });
    await expect(sendBtn).toBeVisible();
    // Click "Send Name" → output shows "Hello" + "Bill", Edit trigger appears
    await sendBtn.click();
    await page.waitForTimeout(500);
    const output = page.locator('.xforms-output');
    await expect(output).toContainText("Bill");
    // The "out" case container shows the Hello label + output
    await expect(page.locator('#out')).toContainText("Hello");
    const editBtn = page.getByRole("button", { name: "Edit" });
    await expect(editBtn).toBeVisible();
    // Input and Send Name should be hidden
    await expect(nameInput).toBeHidden();
    await expect(sendBtn).toBeHidden();
    // Click "Edit" → back to input + Send Name
    await editBtn.click();
    await page.waitForTimeout(500);
    await expect(nameInput).toBeVisible();
    await expect(sendBtn).toBeVisible();
  });

  /*
     You must see the output "Name : Janel" below. You must NOT be able to see an output labeled
     "Eye Color" or it must be somehow unavailable to you.
  */
  test("9.2.2.a — case: first case auto-selected, shows Name Janel, Eye Color hidden", async ({ page }) => {
    await loadAndWait(page, "Chapt09/9.2/9.2.2/9.2.2.a.xhtml");
    // Name output visible with "Janel"
    const outputs = page.locator('.xforms-output');
    const texts = await outputs.allInnerTexts();
    expect(texts).toContain("Janel");
    // Eye Color label must NOT be visible
    const eyeColorLabel = page.getByText("Eye Color :", { exact: false });
    await expect(eyeColorLabel).toBeHidden();
  });

  /*
     You must see the output "Eye Color : Blue" below. You must NOT be able to see an output labeled
     "Name" or it must be somehow unavailable to you.
  */
  /* TEST-TRACE: scope selectors to .xforms-switch to avoid matching instruction text;
     helps tests/w3c/ch09.spec.ts "9.2.2.b" */
  test("9.2.2.b — case selected=true on second case shows Eye Color Blue, Name hidden", async ({ page }) => {
    await loadAndWait(page, "Chapt09/9.2/9.2.2/9.2.2.b.xhtml");
    const sw = page.locator('.xforms-switch');
    // Eye Color output visible with "Blue"
    const outputs = sw.locator('.xforms-output');
    const texts = await outputs.allInnerTexts();
    expect(texts).toContain("Blue");
    // Eye Color case visible
    await expect(sw.locator('#out')).toBeVisible();
    await expect(sw.locator('#out .xforms-output')).toContainText("Blue");
    // Name case must be hidden
    await expect(sw.locator('#in')).toBeHidden();
  });

  /*
     You must see the output "Name : Janel" below. You must NOT be able to see an output labeled
     "Eye Color" or it must be somehow unavailable to you.
  */
  /* TEST-TRACE: scope selectors to .xforms-switch to avoid matching instruction text;
     helps tests/w3c/ch09.spec.ts "9.2.2.c" */
  test("9.2.2.c — both cases selected=true: first wins, shows Name Janel, Eye Color hidden", async ({ page }) => {
    await loadAndWait(page, "Chapt09/9.2/9.2.2/9.2.2.c.xhtml");
    const sw = page.locator('.xforms-switch');
    // First case wins — Name output visible with "Janel"
    const outputs = sw.locator('.xforms-output');
    const texts = await outputs.allInnerTexts();
    expect(texts).toContain("Janel");
    // Name case visible
    await expect(sw.locator('.xforms-case').first()).toBeVisible();
    // Eye Color case must be hidden
    await expect(sw.locator('.xforms-case').nth(1)).toBeHidden();
  });

  /*
     When you activate the In Case trigger it must be replaced by the Out Case trigger. When you
     activate the Out Case trigger it must be replaced by the In Case trigger.
  */
  test("9.2.3.1.a — case element child of toggle element", async ({ page }) => {
    await loadAndWait(page, "Chapt09/9.2/9.2.3/9.2.3.1/9.2.3.1.a.xhtml");
    const inCaseTrigger = page.getByRole("button", { name: "In Case" });
    const outCaseTrigger = page.getByRole("button", { name: "Out Case" });

    await expect(inCaseTrigger).toBeVisible();
    await expect(outCaseTrigger).toBeHidden();

    await inCaseTrigger.click();
    await page.waitForTimeout(300);
    await expect(outCaseTrigger).toBeVisible();
    await expect(inCaseTrigger).toBeHidden();

    await outCaseTrigger.click();
    await page.waitForTimeout(300);
    await expect(inCaseTrigger).toBeVisible();
    await expect(outCaseTrigger).toBeHidden();
  });
  /*
     Activating different triggers will place the the switch element into different cases. When in
     the In case, you must see a Go To Out Case trigger. When in the Out case, you must see a Go To
     Exit Case trigger and a Go To In Case trigger. When in the Exit case, you must see a Go To Out
     Case trigger.
  */
  test("9.2.3.1.b — 9.2.3.1.b case element child of the toggle element precedence testing", async ({ page }) => {
    await loadAndWait(page, "Chapt09/9.2/9.2.3/9.2.3.1/9.2.3.1.b.xhtml");
    await expect(page.getByText("You are in the In case", { exact: false })).toBeVisible();
    const goToOutCase = page.getByRole("button", { name: "Go To Out Case" });
    await expect(goToOutCase).toBeVisible();

    await goToOutCase.click();
    await page.waitForTimeout(300);
    await expect(page.getByText("You are in the Out case", { exact: false })).toBeVisible();
    const goToExitCase = page.getByRole("button", { name: "Go To Exit Case" });
    const goToInCase = page.getByRole("button", { name: "Go To In Case" });
    await expect(goToExitCase).toBeVisible();
    await expect(goToInCase).toBeVisible();

    await goToExitCase.click();
    await page.waitForTimeout(300);
    await expect(page.getByText("You are in the Exit case", { exact: false })).toBeVisible();
    const exitGoToOutCase = page.getByRole("button", { name: "Go To Out Case" });
    await expect(exitGoToOutCase).toBeVisible();
    await expect(goToExitCase).toBeHidden();
    await expect(goToInCase).toBeHidden();

    await exitGoToOutCase.click();
    await page.waitForTimeout(300);
    await expect(page.getByText("You are in the Out case", { exact: false })).toBeVisible();
    await expect(goToExitCase).toBeVisible();
    await expect(goToInCase).toBeVisible();
  });

  /*
     If you are in the "in" case and you activate the Show Out Case trigger you must see an
     xforms-deselect(in) message followed by an xforms-select(out) message. If you are in the "out"
     case and you activate the Show In Case trigger you must see an xforms-deselect(out) message
     followed by an xforms-select(in) message.
  */
  test("9.2.3.a — toggle dispatches deselect/select messages in order", async ({ page }) => {
    const dialogMessages = collectDialogMessages(page);
    await loadAndWait(page, "Chapt09/9.2/9.2.3/9.2.3.a.xhtml");

    const showOutCase = page.getByRole("button", { name: "Show Out Case" });
    const showInCase = page.getByRole("button", { name: "Show In Case" });
    await expect(showOutCase).toBeVisible();
    await expect(showInCase).toBeHidden();

    const beforeOutToggle = dialogMessages.length;
    await showOutCase.click();
    await page.waitForTimeout(300);
    await expect(showInCase).toBeVisible();
    await expect(showOutCase).toBeHidden();
    const outToggleMessages = dialogMessages.slice(beforeOutToggle).map((value) => normalizeWhitespace(value));
    const deselectInIndex = outToggleMessages.findIndex((value) => /xforms-deselect\(in\)/i.test(value));
    const selectOutIndex = outToggleMessages.findIndex((value) => /xforms-select\(out\)/i.test(value));
    expect(deselectInIndex).toBeGreaterThanOrEqual(0);
    expect(selectOutIndex).toBeGreaterThanOrEqual(0);
    expect(deselectInIndex).toBeLessThan(selectOutIndex);

    const beforeInToggle = dialogMessages.length;
    await showInCase.click();
    await page.waitForTimeout(300);
    await expect(showOutCase).toBeVisible();
    await expect(showInCase).toBeHidden();
    const inToggleMessages = dialogMessages.slice(beforeInToggle).map((value) => normalizeWhitespace(value));
    const deselectOutIndex = inToggleMessages.findIndex((value) => /xforms-deselect\(out\)/i.test(value));
    const selectInIndex = inToggleMessages.findIndex((value) => /xforms-select\(in\)/i.test(value));
    expect(deselectOutIndex).toBeGreaterThanOrEqual(0);
    expect(selectInIndex).toBeGreaterThanOrEqual(0);
    expect(deselectOutIndex).toBeLessThan(selectInIndex);
  });

  // -----------------------------------------------------------------
  // 9.3 repeat
  // -----------------------------------------------------------------

  /*
     You must see the values "winshield wipers", "tires", "exhaust", and "air freshener" output
     below.
  */
  test("9.3.1.a — repeat outputs windshield wipers, tires, exhaust, air freshener", async ({ page }) => {
    await loadAndWait(page, "Chapt09/9.3/9.3.1/9.3.1.a.xhtml");
    const items = page.locator('[data-repeat-item]');
    await expect(items).toHaveCount(4);
    const text = await getFormControlText(page);
    expect(text).toContain("windshield wipers");
    expect(text).toContain("tires");
    expect(text).toContain("exhaust");
    expect(text).toContain("air freshener");
  });

  /* The value of the Initial Index output must be "3". */
  test("9.3.1.b — repeat startindex=3: Initial Index output is 3", async ({ page }) => {
    await loadAndWait(page, "Chapt09/9.3/9.3.1/9.3.1.b.xhtml");
    // The index output must show "3"
    const indexOutput = page.locator('.xforms-output').first();
    await expect(indexOutput).toHaveText("3");
    // All 4 items still rendered
    const items = page.locator('[data-repeat-item]');
    await expect(items).toHaveCount(4);
  });

  /* You may see only one car part item for the Items In Cart output. */
  test("9.3.1.c — repeat number=1: may see only one item", async ({ page }) => {
    await loadAndWait(page, "Chapt09/9.3/9.3.1/9.3.1.c.xhtml");
    // number="1" means processor may display only 1 item at a time
    const text = await getFormControlText(page);
    expect(text).toContain("Items In Cart");
    // At least 1 item visible
    const items = page.locator('[data-repeat-item]');
    const count = await items.count();
    expect(count).toBeGreaterThan(0);
  });

  /*
     You must see two lists of items, Items In Cart 1 and Items In Cart 2. Both lists must contain
     the values "winshield wipers", "tires", "exhaust", and "air freshener".
  */
  test("9.3.1.d — unrolled repeat: both lists show all 4 cart items", async ({ page }) => {
    await loadAndWait(page, "Chapt09/9.3/9.3.1/9.3.1.d.xhtml");
    const text = await getFormControlText(page);
    // Both lists must contain all items
    expect(text).toContain("Items In Cart 1");
    expect(text).toContain("Items In Cart 2");
    const allOutputs = page.locator('.xforms-output');
    const allTexts = await allOutputs.allInnerTexts();
    // Each item should appear at least twice (once per list)
    for (const item of ["windshield wipers", "tires", "exhaust", "air freshener"]) {
      const occurrences = allTexts.filter((t) => t.includes(item)).length;
      expect(occurrences).toBeGreaterThanOrEqual(2);
    }
  });

  /*
     You must see three items (named a, b, and c) and a price for each item (3.00, 32.25, and 132.99
     respectively). You must be able to add and remove items. When you add an item its initial name
     will be an empty input control and initial price will be 0.00.
  */
  test("9.3.1.e — repeat shows 3 line items (a/3.00, b/32.25, c/132.99) with insert and delete", async ({ page }) => {
    await loadAndWait(page, "Chapt09/9.3/9.3.1/9.3.1.e.xhtml");
    const getCurrentIndex = async (): Promise<number> => {
      const text = await getFormControlText(page);
      const indexMatch = text.match(/Current index\s*:\s*(\d+)/i);
      expect(indexMatch).not.toBeNull();
      return Number(indexMatch?.[1] ?? NaN);
    };
    const readLineRows = async (): Promise<Array<{ price: string; name: string }>> =>
      page.locator("[data-repeat-item]").evaluateAll((rows) =>
        rows.map((row) => {
          const inputs = Array.from(row.querySelectorAll("input")) as HTMLInputElement[];
          const priceInput = inputs.find((input) => (input.getAttribute("data-ref") || "").includes("price"));
          const nameInput = inputs.find((input) => (input.getAttribute("data-ref") || "").includes("@name"));
          return {
            price: priceInput?.value ?? "",
            name: nameInput?.value ?? "",
          };
        })
      );
    // Initially 3 repeat items
    const items = page.locator('[data-repeat-item]');
    await expect(items).toHaveCount(3);
    // Verify initial line values
    const initialRows = await readLineRows();
    expect(initialRows).toEqual([
      { name: "a", price: "3.00" },
      { name: "b", price: "32.25" },
      { name: "c", price: "132.99" },
    ]);

    const beforeInsertIndex = await getCurrentIndex();
    expect(beforeInsertIndex).toBeGreaterThanOrEqual(1);
    expect(beforeInsertIndex).toBeLessThanOrEqual(initialRows.length);
    // Insert trigger adds a new item
    await page.getByRole("button", { name: "Insert New Item After The Current One" }).click();
    await page.waitForTimeout(500);
    await expect(items).toHaveCount(initialRows.length + 1);
    // Current index identifies where the inserted row was placed
    const afterInsertIndex = await getCurrentIndex();
    expect(afterInsertIndex).toBe(Math.min(beforeInsertIndex + 1, initialRows.length + 1));

    const rowsAfterInsert = await readLineRows();
    expect(rowsAfterInsert).toHaveLength(initialRows.length + 1);
    expect(rowsAfterInsert[afterInsertIndex - 1]).toEqual({ name: "", price: "0.00" });
    const rowsWithoutInserted = rowsAfterInsert.filter((_, index) => index !== afterInsertIndex - 1);
    expect(rowsWithoutInserted).toEqual(initialRows);
    // Remove trigger deletes the current item
    await page.getByRole("button", { name: "Remove Current Item" }).click();
    await page.waitForTimeout(500);
    await expect(items).toHaveCount(initialRows.length);
  });

  /*
     You must see three sets of the statement "You are in the In case" and Go To Out Case triggers.
     When you activate a Go To Out Case trigger, the corresponding statement must change to "You are
     in the Out case" and the trigger must be replaced by a Go To In Case trigger. The other two
     statements and triggers must not change. Activating a Go To In Case trigger must restore the
     statement and trigger to their original state and also not change the other two statements or
     triggers.
  */
  test("9.3.1.f — switch inside repeat: 3 In-case statements, toggle one without affecting others", async ({ page }) => {
    await loadAndWait(page, "Chapt09/9.3/9.3.1/9.3.1.f.xhtml");
    // 3 repeat items
    const items = page.locator('[data-repeat-item]');
    await expect(items).toHaveCount(3);
    const expectInState = async (row: ReturnType<typeof items.nth>) => {
      await expect(row.locator('.xforms-output', { hasText: "You are in the In case" })).toBeVisible();
      await expect(row.locator('.xforms-output', { hasText: "You are in the Out case" })).toBeHidden();
      await expect(row.getByRole("button", { name: "Go To Out Case" })).toBeVisible();
      await expect(row.getByRole("button", { name: "Go To In Case" })).toBeHidden();
    };
    const expectOutState = async (row: ReturnType<typeof items.nth>) => {
      await expect(row.locator('.xforms-output', { hasText: "You are in the Out case" })).toBeVisible();
      await expect(row.locator('.xforms-output', { hasText: "You are in the In case" })).toBeHidden();
      await expect(row.getByRole("button", { name: "Go To In Case" })).toBeVisible();
      await expect(row.getByRole("button", { name: "Go To Out Case" })).toBeHidden();
    };

    // Initial state: all three sets in \"In\" case
    for (let index = 0; index < 3; index++) {
      await expectInState(items.nth(index));
    }

    // Validate each set toggles independently and other two remain unchanged
    for (let activeIndex = 0; activeIndex < 3; activeIndex++) {
      const activeRow = items.nth(activeIndex);

      await activeRow.getByRole("button", { name: "Go To Out Case" }).click();
      await page.waitForTimeout(500);
      await expectOutState(activeRow);

      for (let otherIndex = 0; otherIndex < 3; otherIndex++) {
        if (otherIndex === activeIndex) continue;
        await expectInState(items.nth(otherIndex));
      }

      await activeRow.getByRole("button", { name: "Go To In Case" }).click();
      await page.waitForTimeout(500);
      await expectInState(activeRow);

      for (let otherIndex = 0; otherIndex < 3; otherIndex++) {
        if (otherIndex === activeIndex) continue;
        await expectInState(items.nth(otherIndex));
      }
    }
  });

  /*
     When you activate the Show Out Case trigger it must be replaced by the Show In Case trigger.
     When you activate the Show In Case trigger it must be replaced by the Show Out Case trigger.
  */
  test("9.3.4.a — switch inside repeat toggles between Show Out/In Case", async ({ page }) => {
    await loadAndWait(page, "Chapt09/9.3/9.3.4/9.3.4.a.xhtml");
    // Initial: "Show Out Case" trigger visible
    const showOutBtn = page.getByRole("button", { name: "Show Out Case" });
    await expect(showOutBtn).toBeVisible();
    // Click → "Show In Case" appears
    await showOutBtn.click();
    await page.waitForTimeout(500);
    const showInBtn = page.getByRole("button", { name: "Show In Case" });
    await expect(showInBtn).toBeVisible();
    await expect(showOutBtn).toBeHidden();
    // Click back → "Show Out Case" restored
    await showInBtn.click();
    await page.waitForTimeout(500);
    await expect(showOutBtn).toBeVisible();
    await expect(showInBtn).toBeHidden();
  });

  /*
     Part 1 and Part 2 must each render the list of car parts (windshield wipers, tires, exhaust,
     air freshener). Part 3 must render "Items in cart :" and the same four items.
  */
  test("9.3.5.a — repeating via attributes renders all three item lists", async ({ page }) => {
    await loadAndWait(page, "Chapt09/9.3/9.3.5/9.3.5.a.xhtml");
    await expect(page.getByText("Part 1: If the XForms processor under test supports repeat-* attribute usage", { exact: false })).toBeVisible();
    await expect(page.getByText("Part 2: If the XForms processor under test supports repeat-* attribute usage", { exact: false })).toBeVisible();
    await expect(page.getByText("Part 3: If the XForms processor under test supports repeat-* attribute usage", { exact: false })).toBeVisible();
    await expect(page.getByText("Items in cart :", { exact: false })).toBeVisible();

    const outputs = page.locator(".xforms-output");
    await expect(outputs).toHaveCount(6);
    const itemValues = (await outputs.allInnerTexts()).map((value) => value.replace(/\s+/g, " ").trim()).filter(Boolean);
    expect(itemValues[0]).toBe("windshield wipers tires exhaust air freshener");
    expect(itemValues[1]).toBe("windshield wipers tires exhaust air freshener");
    expect(itemValues.slice(2)).toEqual(["windshield wipers", "tires", "exhaust", "air freshener"]);
  });

  /*
     You must see two select controls that both contain the values "Vanilla", "Strawberry", and
     "Chocolate".
  */
  test("9.3.6.a — 9.3.6.a itemset element example", async ({ page }) => {
    await loadAndWait(page, "Chapt09/9.3/9.3.6/9.3.6.a.xhtml");
    const flavorSelects = page.locator("div.xforms-select select");
    await expect(flavorSelects).toHaveCount(2);

    for (let index = 0; index < 2; index++) {
      const labels = await flavorSelects
        .nth(index)
        .locator("option")
        .evaluateAll((options) =>
          options.map((option) => (option.textContent ?? "").trim()).filter((label) => label.length > 0)
        );
      expect(labels).toEqual(expect.arrayContaining(["Vanilla", "Strawberry", "Chocolate"]));
    }
  });

  /*
     When you select a flavor from the select control below you must see the output "Icecream Order
     : " and the selected flavor. If no flavor is selected (including if the chosen flavor is
     deselected) the output control, including label, must not be visible on the page.
  */
  test("9.3.7.a — 9.3.7.a copy element", async ({ page }) => {
    await loadAndWait(page, "Chapt09/9.3/9.3.7/9.3.7.a.xhtml");
    const flavorSelect = page.locator("div.xforms-select select");
    await expect(flavorSelect).toHaveCount(1);

    const icecreamOrderOutput = page.locator(".xforms-output[data-ref*='order/flavor']").locator("xpath=..");
    if ((await icecreamOrderOutput.count()) > 0) {
      await expect(icecreamOrderOutput.first()).toBeHidden();
    }

    await flavorSelect.selectOption({ label: "vanilla" });
    await page.waitForTimeout(300);
    await expect(icecreamOrderOutput).toHaveCount(1);
    await expect(icecreamOrderOutput.first()).toBeVisible();
    await expect(icecreamOrderOutput.first()).toContainText(/Icecream Order\s*:\s*vanilla/i);

    await flavorSelect.selectOption([]);
    await page.waitForTimeout(300);
    await expect(icecreamOrderOutput.first()).toBeHidden();
  });

  /*
     When you try to select a flavor from the select control you must see an
     xforms-binding-exception message or a fatal error due to an xforms-binding-exception.
  */
  test("9.3.7.b — copy across model raises binding exception", async ({ page }) => {
    const dialogMessages = collectDialogMessages(page);
    const pageErrors: string[] = [];
    page.on("pageerror", (error) => {
      pageErrors.push(normalizeWhitespace(error.message));
    });
    await loadAndWait(page, "Chapt09/9.3/9.3.7/9.3.7.b.xhtml");
    // TEST-TRACE: assert copy/model mismatch surfaces as xforms-binding-exception dialog or fatal xforms-binding-exception error text.
    const flavorSelect = page.locator("div.xforms-select select");
    await expect(flavorSelect).toHaveCount(1);
    const beforeSelectionMessages = dialogMessages.length;
    const beforeSelectionErrors = pageErrors.length;
    await flavorSelect.selectOption({ label: "vanilla" });
    await page.waitForTimeout(300);

    const normalizedMessages = dialogMessages.slice(beforeSelectionMessages).map((message) => normalizeWhitespace(message));
    const normalizedErrors = pageErrors.slice(beforeSelectionErrors);
    const formControlText = normalizeWhitespace(await getFormControlText(page));
    const sawBindingExceptionDialog = normalizedMessages.some((message) => /\bxforms-binding-exception\b/i.test(message));
    const sawFatalBindingExceptionError = normalizedErrors.some(
      (message) => /\bfatal error\b/i.test(message) && /\bxforms-binding-exception\b/i.test(message)
    );
    const sawFatalBindingExceptionInForm = /\bfatal error\b/i.test(formControlText) && /\bxforms-binding-exception\b/i.test(formControlText);
    expect(sawBindingExceptionDialog || sawFatalBindingExceptionError || sawFatalBindingExceptionInForm).toBe(true);
  });
});
