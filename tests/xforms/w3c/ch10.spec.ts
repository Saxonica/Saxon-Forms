import { test, expect, loadAndWait, getRenderedText, collectDialogMessages, clickTrigger, getFormControlText, getEventModelResults } from "./helpers";

test.describe("W3C Chapter 10 — XForms Actions", () => {
  /* After you activate the Fire Test trigger the value in the Car Model output must be "BMW". */
  test("10.1.a action element renders triggers", async ({ page }) => {
    await loadAndWait(page, "Chapt10/10.1/10.1.a.xhtml");
    const carModel = page.locator("input.xforms-input");
    await expect(carModel).toHaveValue("Porche");
    await page.getByRole("button", { name: "Fire Test", exact: true }).click();
    await page.waitForTimeout(300);
    await expect(carModel).toHaveValue("BMW");
  });

  /*
     You must see the value "white" in the Color output control, the value "excellent" in the
     Condition output control, and the value "Toyoto" in the Make output control. When you activate
     the Set Color trigger the value in the Color output must change to "blue". When you activate
     the Set Condition trigger the value in the Condition output must change to "fair". When you
     activate the Set Make trigger the value in the Make output must not change.
  */
  test("10.2.a setvalue with expression or literal", async ({ page }) => {
    await loadAndWait(page, "Chapt10/10.2/10.2.a.xhtml");
    const outputs = page.locator(".xforms-output");
    await expect(outputs).toHaveCount(3);
    await expect(outputs.nth(0)).toHaveText(/^white$/i);
    await expect(outputs.nth(1)).toHaveText(/^excellent$/i);
    await expect(outputs.nth(2)).toHaveText(/^Toyota$/i);

    await page.getByRole("button", { name: "Set Color", exact: true }).click();
    await page.waitForTimeout(300);
    await expect(outputs.nth(0)).toHaveText(/^blue$/i);

    await page.getByRole("button", { name: "Set Condition", exact: true }).click();
    await page.waitForTimeout(300);
    await expect(outputs.nth(1)).toHaveText(/^fair$/i);

    await page.getByRole("button", { name: "Set Make", exact: true }).click();
    await page.waitForTimeout(300);
    await expect(outputs.nth(2)).toHaveText(/^Toyota$/i);
  });

  /*
     You must see the value "white" in the Color output control and the value "excellent" in the
     Condition output control. When you activate the Set Color trigger the value in the Color output
     must change to "blue". When you activate the Set Condition trigger the value in the Condition
     output must change being empty.
  */
  test("10.2.b setvalue shows white and excellent", async ({ page }) => {
    await loadAndWait(page, "Chapt10/10.2/10.2.b.xhtml");
    const outputs = page.locator(".xforms-output");
    await expect(outputs).toHaveCount(2);
    await expect(outputs.nth(0)).toHaveText(/^white$/i);
    await expect(outputs.nth(1)).toHaveText(/^excellent$/i);

    await page.getByRole("button", { name: "Set color", exact: true }).click();
    await page.waitForTimeout(300);
    await expect(outputs.nth(0)).toHaveText(/^blue$/i);

    await page.getByRole("button", { name: "Set condition", exact: true }).click();
    await page.waitForTimeout(300);
    await expect(outputs.nth(1)).toHaveText(/^\s*$/);
  });

  /* You must see the correct values for each output control below. */
  test("10.3.a insert action using context attribute", async ({ page }) => {
    await loadAndWait(page, "Chapt10/10.3/10.3.a.xhtml");
    const outputs = page.locator(".xforms-output");
    const values = (await outputs.allInnerTexts()).map((value) => value.replace(/\s+/g, " ").trim()).filter(Boolean);
    // TEST-TRACE: assert all 10.3.a "You must see..." clauses (1,2,3,3 / 4,5,6,6,6,6 / 0,0).
    expect(values).toEqual(["1", "2", "3", "3", "4", "5", "6", "6", "6", "6", "0", "0"]);
  });

  /* You must see the correct values for each output control below. */
  test("10.3.b — 10.3.b insert action with bind and model attributes", async ({ page }) => {
    await loadAndWait(page, "Chapt10/10.3/10.3.b.xhtml");
    const assertSectionValues = async (sectionLabel: string, expectedValues: string[]): Promise<void> => {
      const sectionGroup = page.locator(".xforms-group").filter({ hasText: sectionLabel }).first();
      const sectionOutputs = sectionGroup.locator(".xforms-output");
      const sectionValues = (await sectionOutputs.allInnerTexts()).map((value) => value.replace(/\s+/g, " ").trim()).filter(Boolean);
      expect(sectionValues).toEqual(expectedValues);
    };
    // TEST-TRACE: cover all 10.3.b "You must see..." sections across default model and model=\"mod2\" groups.
    await assertSectionValues("You must see the numbers 4, 5, 6, and 6", ["4", "5", "6", "6"]);
    await assertSectionValues("You must see the numbers 7, 8, 9, 10, and 10", ["7", "8", "9", "10", "10"]);
    await assertSectionValues("You must see the numbers 11, 12, 13, 14, and 14", ["11", "12", "13", "14", "14"]);
  });

  /* You must see the correct values for each output control below. */
  test("10.3.c insert action using origin attribute", async ({ page }) => {
    await loadAndWait(page, "Chapt10/10.3/10.3.c.xhtml");
    const outputs = page.locator(".xforms-output");
    const values = (await outputs.allInnerTexts()).map((value) => value.replace(/\s+/g, " ").trim()).filter(Boolean);
    expect(values).toEqual(["1", "2", "3", "0", "3"]);
  });

  /*
     After activating any of the Test triggers the integer sequence must match the one on the label
     of the activated trigger.
  */
  test("10.3.d insert action using at attribute", async ({ page }) => {
    await loadAndWait(page, "Chapt10/10.3/10.3.d.xhtml");
    const triggers = page.locator("button.xforms-trigger");
    await expect(triggers).toHaveCount(7);
    const triggerLabels = (await triggers.allInnerTexts()).map((label) => label.replace(/\s+/g, " ").trim());
    const parseExpectedSequence = (triggerLabel: string): string[] => {
      const sequenceMatch = triggerLabel.match(/Test\s+[A-F]\s*:\s*([0-9 ]+)/i);
      if (!sequenceMatch) return [];
      return sequenceMatch[1].trim().split(/\s+/).filter(Boolean);
    };
    const getRenderedSequence = async (): Promise<string[]> =>
      (await page.locator("[data-repeat-item] .xforms-output").allInnerTexts())
        .map((value) => value.replace(/\s+/g, " ").trim())
        .filter(Boolean);
    const getListSizes = async (): Promise<{ x: number; y: number }> => {
      const text = await getRenderedText(page);
      const sizeXMatch = text.match(/Size of List X:\s*(\d+)/i);
      const sizeYMatch = text.match(/Size of List Y:\s*(\d+)/i);
      expect(sizeXMatch).not.toBeNull();
      expect(sizeYMatch).not.toBeNull();
      return {
        x: Number(sizeXMatch?.[1] ?? NaN),
        y: Number(sizeYMatch?.[1] ?? NaN),
      };
    };

    for (let index = 0; index < triggerLabels.length; index++) {
      await triggers.nth(index).click();
      await page.waitForTimeout(300);
      const sequenceValues = await getRenderedSequence();
      const listSizes = await getListSizes();
      if (index < 6) {
        const expectedSequence = parseExpectedSequence(triggerLabels[index]);
        expect.soft(
          sequenceValues,
          `Unexpected sequence for ${triggerLabels[index]}`
        ).toEqual(expectedSequence);
        expect.soft(
          listSizes,
          `Unexpected list sizes for ${triggerLabels[index]}`
        ).toEqual({ x: expectedSequence.length, y: 0 });
      } else {
        expect.soft(
          sequenceValues,
          `Unexpected sequence for ${triggerLabels[index]}`
        ).toEqual(["1", "2", "3", "4", "5"]);
        expect.soft(
          listSizes,
          `Unexpected list sizes for ${triggerLabels[index]}`
        ).toEqual({ x: 5, y: 0 });
      }
    }
  });

  /*
     After activating any of the Test triggers the numbers output onto the page must match those on
     the label of the activated trigger control.
  */
  test("10.3.e insert action using position attribute", async ({ page }) => {
    await loadAndWait(page, "Chapt10/10.3/10.3.e.xhtml");
    const triggers = page.locator("button.xforms-trigger");
    await expect(triggers).toHaveCount(4);
    const triggerLabels = (await triggers.allInnerTexts()).map((label) => label.replace(/\s+/g, " ").trim());
    const parseExpectedSequence = (triggerLabel: string): string[] => {
      const sequenceMatch = triggerLabel.match(/Test\s+[A-C]\s*:\s*([0-9 ]+)/i);
      if (!sequenceMatch) return [];
      return sequenceMatch[1].trim().split(/\s+/).filter(Boolean);
    };
    const getRenderedSequence = async (): Promise<string[]> =>
      (await page.locator("[data-repeat-item] .xforms-output").allInnerTexts())
        .map((value) => value.replace(/\s+/g, " ").trim())
        .filter(Boolean);
    const getListSizes = async (): Promise<{ x: number; y: number }> => {
      const text = await getRenderedText(page);
      const sizeXMatch = text.match(/Size of List X:\s*(\d+)/i);
      const sizeYMatch = text.match(/Size of List Y:\s*(\d+)/i);
      expect(sizeXMatch).not.toBeNull();
      expect(sizeYMatch).not.toBeNull();
      return {
        x: Number(sizeXMatch?.[1] ?? NaN),
        y: Number(sizeYMatch?.[1] ?? NaN),
      };
    };

    for (let index = 0; index < triggerLabels.length; index++) {
      await triggers.nth(index).click();
      await page.waitForTimeout(300);
      const sequenceValues = await getRenderedSequence();
      const listSizes = await getListSizes();
      const expectedSequence = parseExpectedSequence(triggerLabels[index]);
      if (expectedSequence.length > 0) {
        expect.soft(
          sequenceValues,
          `Unexpected sequence for ${triggerLabels[index]}`
        ).toEqual(expectedSequence);
        expect.soft(
          listSizes,
          `Unexpected list sizes for ${triggerLabels[index]}`
        ).toEqual({ x: expectedSequence.length, y: 0 });
      } else {
        expect.soft(
          sequenceValues,
          `Unexpected sequence for ${triggerLabels[index]}`
        ).toEqual(["1", "2", "3", "4", "5"]);
        expect.soft(
          listSizes,
          `Unexpected list sizes for ${triggerLabels[index]}`
        ).toEqual({ x: 5, y: 0 });
      }
    }
  });
  const xformsSpecUrl = /w3\.org\/TR\/xforms11\/?/i;

  async function assertDialogPatternsAfterTrigger(
    page: any,
    dialogMessages: string[],
    triggerLabel: string,
    requiredPatterns: RegExp[],
    timeout = 10_000
  ): Promise<string[]> {
    const beforeCount = dialogMessages.length;
    await clickTrigger(page, triggerLabel);
    await expect.poll(
      () =>
        requiredPatterns.every((pattern) =>
          dialogMessages.slice(beforeCount).some((message) => pattern.test(message))
        ),
      { timeout }
    ).toBe(true);
    return dialogMessages.slice(beforeCount);
  }

  async function measureRebuildDispatchLatency(
    page: any,
    dialogEvents: { message: string; timestamp: number }[],
    triggerLabel: string
  ): Promise<number> {
    const beforeCount = dialogEvents.length;
    const startedAt = Date.now();
    await clickTrigger(page, triggerLabel);
    await expect.poll(
      () =>
        dialogEvents.slice(beforeCount).find((event) => /^xforms-rebuild$/i.test(event.message))
          ?.timestamp ?? null,
      { timeout: 12_000 }
    ).not.toBeNull();
    const eventTimestamp = dialogEvents
      .slice(beforeCount)
      .find((event) => /^xforms-rebuild$/i.test(event.message))
      ?.timestamp;
    return Number(eventTimestamp ?? startedAt) - startedAt;
  }

  async function assertDelayedDispatchAppearsSlower(page: any, file: string) {
    const dialogEvents: { message: string; timestamp: number }[] = [];
    page.on("dialog", async (dialog: any) => {
      dialogEvents.push({
        message: dialog.message().replace(/\s+/g, " ").trim(),
        timestamp: Date.now(),
      });
      await dialog.dismiss();
    });
    await loadAndWait(page, file);
    const withoutDelayMs = await measureRebuildDispatchLatency(
      page,
      dialogEvents,
      "Rebuild Without Delay"
    );
    const withDelayMs = await measureRebuildDispatchLatency(
      page,
      dialogEvents,
      "Rebuild With Delay"
    );
    expect(withDelayMs).toBeGreaterThan(withoutDelayMs);
  }

  /* After trigger activation this page must be replaced by the XForms 1.1 specification (child resource precedence). */

  /* Each insert trigger must emit xforms-insert and place a new 0.00/empty row at the expected position. */
  test("10.3.f — insert action repeat positioning and defaults", async ({ page }) => {
    const dialogMessages = collectDialogMessages(page);
    const baseLines = [
      { price: "3.00", name: "a" },
      { price: "32.25", name: "b" },
      { price: "132.99", name: "c" },
    ];
    const scenarios: Array<{ triggerLabel: string; insertedIndex: number }> = [
      { triggerLabel: "Insert At index 1", insertedIndex: 0 },
      { triggerLabel: "Insert At index 1.5", insertedIndex: 1 },
      { triggerLabel: "Insert At index 100", insertedIndex: 3 },
    ];
    const readLines = async (): Promise<Array<{ price: string; name: string }>> => {
      const rows = page.locator("[data-repeat-item]");
      const count = await rows.count();
      const lines: Array<{ price: string; name: string }> = [];
      for (let index = 0; index < count; index++) {
        const rowInputs = rows.nth(index).locator("input.xforms-input");
        lines.push({
          price: (await rowInputs.nth(0).inputValue()).trim(),
          name: (await rowInputs.nth(1).inputValue()).trim(),
        });
      }
      return lines;
    };

    // TEST-TRACE: promote 10.3.f from render smoke check to insert-event, position, and default-value assertions.
    for (const { triggerLabel, insertedIndex } of scenarios) {
      await loadAndWait(page, "Chapt10/10.3/10.3.f.xhtml");
      expect(await readLines()).toEqual(baseLines);
      await assertDialogPatternsAfterTrigger(page, dialogMessages, triggerLabel, [/^xforms-insert$/i]);
      const expected = [...baseLines];
      expected.splice(insertedIndex, 0, { price: "0.00", name: "" });
      expect(await readLines()).toEqual(expected);
    }
  });

  /* You must see the value "7" : */
  test("10.3.g — 10.3.g insert action - nodeset indicates root element", async ({ page }) => {
    await loadAndWait(page, "Chapt10/10.3/10.3.g.xhtml");
    const text = await getFormControlText(page);
    expect(text).toContain("7");
  });

  /*
     You must see the correct values for the two output controls both before and after activating
     the Perform Insert trigger. The conditions change after the trigger is activated.
  */
  test("10.3.h — 10.3.h insert action and repeat element", async ({ page }) => {
    await loadAndWait(page, "Chapt10/10.3/10.3.h.xhtml");
    let text = await getFormControlText(page);
    expect(text).toMatch(/Before\s*-\s*You must see the value\s*"1"\s*:\s*1\b/i);
    expect(text).toMatch(/Before\s*-\s*You must see the value\s*"3"\s*:\s*3\b/i);

    await clickTrigger(page, "Perform Insert");
    text = await getFormControlText(page);
    expect(text).toMatch(/After\s*-\s*You must see the value\s*"3"\s*:\s*3\b/i);
    expect(text).toMatch(/After\s*-\s*You must see the value\s*"1"\s*:\s*1\b/i);
  });

  /* On xforms-ready insert, you must see xforms-insert and Node Count output must be 6. */
  test("10.3.i — xforms-ready insert emits event and updates node count", async ({ page }) => {
    const dialogMessages = collectDialogMessages(page);
    await loadAndWait(page, "Chapt10/10.3/10.3.i.xhtml");
    await expect.poll(
      () => dialogMessages.some((message) => /^xforms-insert$/i.test(message)),
      { timeout: 10_000 }
    ).toBe(true);
    // TEST-TRACE: promote 10.3.i from render smoke check to xforms-ready insert event and node-count assertions.
    expect(await getFormControlText(page)).toMatch(/Node Count\s*:\s*6/i);
  });

  /*
     You must not see the value "4.00", "5.00", or "6.00" in the three output controls.
  */
  test("10.3.j insert action — copied price attributes are not inserted", async ({ page }) => {
    await loadAndWait(page, "Chapt10/10.3/10.3.j.xhtml");
    const outputs = page.locator(".xforms-output");
    await expect(outputs).toHaveCount(3);
    await expect(outputs.nth(0)).toHaveText(/^\s*$/);
    await expect(outputs.nth(1)).toHaveText(/^\s*$/);
    await expect(outputs.nth(2)).toHaveText(/^3\.00$/);

    const values = (await outputs.allInnerTexts()).map((value) => value.replace(/\s+/g, " ").trim());
    expect(values).not.toContain("4.00");
    expect(values).not.toContain("5.00");
    expect(values).not.toContain("6.00");
  });

  /* You must see only the number 10: */
  test("10.4.a delete action using context attribute", async ({ page }) => {
    await loadAndWait(page, "Chapt10/10.4/10.4.a.xhtml");
    const outputs = page.locator(".xforms-output");
    const values = (await outputs.allInnerTexts()).map((value) => value.replace(/\s+/g, " ").trim()).filter(Boolean);
    expect(values).toEqual(["10", "4", "1", "2"]);
  });

  /* You must see only the numbers 4 and 5 : */
  test("10.4.b — 10.4.b delete action using context and bind attributes", async ({ page }) => {
    await loadAndWait(page, "Chapt10/10.4/10.4.b.xhtml");
    const outputs = page.locator(".xforms-output");
    const values = (await outputs.allInnerTexts()).map((value) => value.replace(/\s+/g, " ").trim()).filter(Boolean);
    expect(values).toEqual(["4", "5", "7", "8", "9", "11", "12", "13"]);
  });

  /* You must see the number 3 : */
  test("10.4.c — 10.4.c delete action using context attribute terminates with no effect", async ({ page }) => {
    await loadAndWait(page, "Chapt10/10.4/10.4.c.xhtml");
    const outputs = page.locator(".xforms-output");
    const values = (await outputs.allInnerTexts()).map((value) => value.replace(/\s+/g, " ").trim()).filter(Boolean);
    expect(values).toEqual(["3", "6", "3"]);
  });

  /* You must see the correct values for each output control below. */
  test("10.4.d delete action using at attribute", async ({ page }) => {
    await loadAndWait(page, "Chapt10/10.4/10.4.d.xhtml");
    const outputs = page.locator(".xforms-output");
    const values = (await outputs.allInnerTexts()).map((value) => value.replace(/\s+/g, " ").trim()).filter(Boolean);
    expect(values).toEqual(["1", "2", "4", "6", "8", "9", "10", "11", "13", "14", "17"]);
  });

  /*
     When you activate the Delete Item At Index trigger you must see an xforms-delete message. After
     an item is deleted the Current index must not change unless the last item in the list was
     deleted, in which case the Current index must point to the new last item. If all items in the
     list are deleted the Current index must be the number 0.
  */
  test("10.4.e delete element rules", async ({ page }) => {
    const dialogMessages = collectDialogMessages(page);
    await loadAndWait(page, "Chapt10/10.4/10.4.e.xhtml");
    const getCurrentIndex = async (): Promise<number> => {
      const text = await getFormControlText(page);
      const indexMatch = text.match(/Current index\s*:\s*(\d+)/i);
      expect(indexMatch).not.toBeNull();
      return Number(indexMatch?.[1] ?? NaN);
    };

    for (let deletion = 1; deletion <= 6; deletion++) {
      const beforeCount = dialogMessages.length;
      await page.getByRole("button", { name: "Delete Item At Index", exact: true }).click();
      await page.waitForTimeout(300);
      const newMessages = dialogMessages.slice(beforeCount);
      expect.soft(newMessages.some((message) => /xforms-delete/i.test(message))).toBe(true);

      const currentIndex = await getCurrentIndex();
      if (deletion < 6) {
        expect.soft(currentIndex).toBe(1);
      } else {
        expect(currentIndex).toBe(0);
      }
    }
  });

  /* You must see the correct values for each output control below. */
  test("10.4.f — 10.4.f delete action and repeat element", async ({ page }) => {
    await loadAndWait(page, "Chapt10/10.4/10.4.f.xhtml");
    const outputs = page.locator(".xforms-output");
    const values = (await outputs.allInnerTexts()).map((value) => value.replace(/\s+/g, " ").trim()).filter(Boolean);
    expect(values).toEqual(["0", "2", "1", "2", "1"]);
  });

  /* On xforms-ready delete, you must see xforms-delete and the numbers 1/2/3 must not appear below. */
  test("10.4.g — xforms-ready delete emits event and clears repeated values", async ({ page }) => {
    const dialogMessages = collectDialogMessages(page);
    await loadAndWait(page, "Chapt10/10.4/10.4.g.xhtml");
    await expect.poll(
      () => dialogMessages.some((message) => /^xforms-delete$/i.test(message)),
      { timeout: 10_000 }
    ).toBe(true);
    // TEST-TRACE: promote 10.4.g from render smoke check to delete-event and post-delete visibility assertions.
    await expect(page.locator(".xforms-output")).toHaveCount(0);
  });

  /*
     When you activate the Set index To -1 trigger you must see three xforms-scroll-first messages
     and the index must display the number 1. When you activate the Set index To 100 trigger you
     must see three xforms-scroll-last messages and the index must display the number 3. When you
     activate the Set index To 2 trigger you must not see a message and the index must display the
     number 2.
  */
  test("10.5.a setindex element rules", async ({ page }) => {
    const dialogMessages = collectDialogMessages(page);
    await loadAndWait(page, "Chapt10/10.5/10.5.a.xhtml");
    const getCurrentIndex = async (): Promise<number> => {
      const text = await getFormControlText(page);
      const indexMatch = text.match(/\bindex\s*:\s*(\d+)/i);
      expect(indexMatch).not.toBeNull();
      return Number(indexMatch?.[1] ?? NaN);
    };

    await expect(page.getByRole("button", { name: "Set index To -1", exact: true })).toBeVisible();
    await expect(page.getByRole("button", { name: "Set index To 100", exact: true })).toBeVisible();
    await expect(page.getByRole("button", { name: "Set index To 2", exact: true })).toBeVisible();
    expect(await getCurrentIndex()).toBe(1);

    const beforeNegativeIndex = dialogMessages.length;
    await page.getByRole("button", { name: "Set index To -1", exact: true }).click();
    await page.waitForTimeout(300);
    const negativeIndexMessages = dialogMessages.slice(beforeNegativeIndex);
    expect(
      negativeIndexMessages.filter((message) => /xforms-scroll-first/i.test(message))
    ).toHaveLength(3);
    expect(await getCurrentIndex()).toBe(1);

    const beforeLargeIndex = dialogMessages.length;
    await page.getByRole("button", { name: "Set index To 100", exact: true }).click();
    await page.waitForTimeout(300);
    const largeIndexMessages = dialogMessages.slice(beforeLargeIndex);
    expect(
      largeIndexMessages.filter((message) => /xforms-scroll-last/i.test(message))
    ).toHaveLength(3);
    expect(await getCurrentIndex()).toBe(3);

    const beforeMiddleIndex = dialogMessages.length;
    await page.getByRole("button", { name: "Set index To 2", exact: true }).click();
    await page.waitForTimeout(300);
    const middleIndexMessages = dialogMessages.slice(beforeMiddleIndex);
    expect(middleIndexMessages).toHaveLength(0);
    expect(await getCurrentIndex()).toBe(2);
  });

  /*
     When you activate the In Case trigger it must be replaced by the Out Case trigger. When you
     activate the Out Case trigger it must be replaced by the In Case trigger.
  */
  test("10.6.1.a — toggle between In Case and Out Case", async ({ page }) => {
    await loadAndWait(page, "Chapt10/10.6/10.6.1/10.6.1.a.xhtml");
    const inCaseTrigger = page.getByRole("button", { name: "In Case", exact: true });
    const outCaseTrigger = page.getByRole("button", { name: "Out Case", exact: true });

    await expect(inCaseTrigger).toBeVisible();
    await expect(outCaseTrigger).toHaveCount(0);

    await inCaseTrigger.click();
    await page.waitForTimeout(300);
    await expect(outCaseTrigger).toBeVisible();
    await expect(inCaseTrigger).toHaveCount(0);

    await outCaseTrigger.click();
    await page.waitForTimeout(300);
    await expect(inCaseTrigger).toBeVisible();
    await expect(outCaseTrigger).toHaveCount(0);
  });

  /*
     Activating different triggers will place the the switch element into different cases. When in
     the In case, you must see a Go To Out Case trigger. When in the Out case, you must see a Go To
     Exit Case trigger and a Go To In Case trigger. When in the Exit case, you must see a Go To Out
     Case trigger.
  */
  test("10.6.1.b — 10.6.1.b case element child of the toggle element precedence testing", async ({ page }) => {
    await loadAndWait(page, "Chapt10/10.6/10.6.1/10.6.1.b.xhtml");
    await expect(page.getByRole("button", { name: "Go To Out Case", exact: true })).toBeVisible();
    await clickTrigger(page, "Go To Out Case");
    await expect(page.getByRole("button", { name: "Go To Exit Case", exact: true })).toBeVisible();
    await expect(page.getByRole("button", { name: "Go To In Case", exact: true })).toBeVisible();
    await clickTrigger(page, "Go To Exit Case");
    await expect(page.getByRole("button", { name: "Go To Out Case", exact: true })).toBeVisible();
  });

  /*
     If you are in the "in" case and you activate the Show Out Case trigger you must see an
     xforms-deselect(in) message followed by an xforms-select(out) message. If you are in the "out"
     case and you activate the Show In Case trigger you must see an xforms-deselect(out) message
     followed by an xforms-select(in) message.
  */
  test("10.6.a events dispatched by toggle element", async ({ page }) => {
    const dialogMessages = collectDialogMessages(page);
    await loadAndWait(page, "Chapt10/10.6/10.6.a.xhtml");
    const inCaseLabel = page.getByText('You are now in the "in" case', { exact: true });
    const outCaseLabel = page.getByText('You are now in the "out" case', { exact: true });
    const getRecentToggleSignals = async (beforeDialogCount: number, beforeEventCount: number): Promise<string[]> => {
      const dialogSignals = dialogMessages
        .slice(beforeDialogCount)
        .map((message) => message.replace(/\s+/g, " ").trim().toLowerCase())
        .filter((message) => /xforms-(?:de)?select\(/i.test(message));
      if (dialogSignals.length > 0) {
        return dialogSignals;
      }
      return (await getEventModelResults(page))
        .slice(beforeEventCount)
        .map((value) => value.replace(/\s+/g, " ").trim().toLowerCase())
        .filter((message) => /xforms-(?:de)?select\(/i.test(message));
    };

    await expect(page.getByRole("button", { name: "Show Out Case", exact: true })).toBeVisible();
    await expect(page.getByRole("button", { name: "Show In Case", exact: true })).toBeHidden();
    await expect(inCaseLabel).toBeVisible();
    await expect(outCaseLabel).toBeHidden();

    const beforeShowOut = dialogMessages.length;
    const beforeShowOutEvents = (await getEventModelResults(page)).length;
    await clickTrigger(page, "Show Out Case");
    const outCaseSignals = await getRecentToggleSignals(beforeShowOut, beforeShowOutEvents);
    // if (outCaseSignals.length > 0) {
    expect(outCaseSignals).toEqual(["xforms-deselect(in)", "xforms-select(out)"]);
    // }
    await expect(page.getByRole("button", { name: "Show In Case", exact: true })).toBeVisible();
    await expect(page.getByRole("button", { name: "Show Out Case", exact: true })).toBeHidden();
    await expect(outCaseLabel).toBeVisible();
    await expect(inCaseLabel).toBeHidden();

    const beforeShowIn = dialogMessages.length;
    const beforeShowInEvents = (await getEventModelResults(page)).length;
    await clickTrigger(page, "Show In Case");
    const inCaseSignals = await getRecentToggleSignals(beforeShowIn, beforeShowInEvents);
    // if (inCaseSignals.length > 0) {
    expect(inCaseSignals).toEqual(["xforms-deselect(out)", "xforms-select(in)"]);
    // }
    await expect(page.getByRole("button", { name: "Show Out Case", exact: true })).toBeVisible();
    await expect(page.getByRole("button", { name: "Show In Case", exact: true })).toBeHidden();
    await expect(inCaseLabel).toBeVisible();
    await expect(outCaseLabel).toBeHidden();
  });

  /*
     The triggers below must shift the focus to the proper form controls when activated. The "Set
     Focus To Age" trigger must place the focus into the input control labeled Age. The "Set Focus
     To DOB" trigger must place the focus into the input control labeled DOB.
  */
  test("10.7.1.a — 10.7.1.a setfocus element with control child element", async ({ page }) => {
    await loadAndWait(page, "Chapt10/10.7/10.7.1/10.7.1.a.xhtml");
    const nameInput = page.locator("input.xforms-input[data-ref*='name']");
    const ageInput = page.locator("input.xforms-input[data-ref*='age']");
    const dobInput = page.locator("input.xforms-input[data-ref*='dob']");
    await expect(nameInput).toHaveCount(1);
    await expect(ageInput).toHaveCount(1);
    await expect(dobInput).toHaveCount(1);

    // TEST-TRACE: verify 10.7.1.a trigger actions move focus to Age then DOB controls.
    await nameInput.focus();
    await expect(nameInput).toBeFocused();
    await clickTrigger(page, "Set focus to Age field");
    await expect(ageInput).toBeFocused();

    await nameInput.focus();
    await expect(nameInput).toBeFocused();
    await clickTrigger(page, "Set focus to DOB field");
    await expect(dobInput).toBeFocused();
  });

  /*
     The triggers below must shift the focus to the proper form controls when activated. The "Set
     Focus To Age" trigger must place the focus into the input control labeled Age. The "Set Focus
     To DOB" trigger must place the focus into the input control labeled DOB.
  */
  test("10.7.1.b — 10.7.1.b control element precedence tests", async ({ page }) => {
    await loadAndWait(page, "Chapt10/10.7/10.7.1/10.7.1.b.xhtml");
    const nameInput = page.locator("input.xforms-input[data-ref*='name']");
    const ageInput = page.locator("input.xforms-input[data-ref*='age']");
    const dobInput = page.locator("input.xforms-input[data-ref*='dob']");
    await expect(nameInput).toHaveCount(1);
    await expect(ageInput).toHaveCount(1);
    await expect(dobInput).toHaveCount(1);

    // TEST-TRACE: verify 10.7.1.b control precedence yields focus to Age then DOB.
    await nameInput.focus();
    await expect(nameInput).toBeFocused();
    await clickTrigger(page, "Set Focus To Age");
    await expect(ageInput).toBeFocused();

    await nameInput.focus();
    await expect(nameInput).toBeFocused();
    await clickTrigger(page, "Set Focus To DOB");
    await expect(dobInput).toBeFocused();
  });

  /*
     The triggers below must shift the focus to the proper form controls when activated. The Set
     Focus To Shipping trigger must place the focus into the empty input control labeled Shipping.
     The Set Focus To First Item trigger must must place the focus into the input control containing
     the value "brake pad". The Set Focus To Third Item trigger must must place the focus into the
     input control containing the value "fan belt".
  */
  test("10.7.a — 10.7.a setfocus element", async ({ page }) => {
    await loadAndWait(page, "Chapt10/10.7/10.7.a.xhtml");
    const inputs = page.locator("input.xforms-input");
    await expect(inputs).toHaveCount(4);
    const shippingInput = inputs.nth(0);
    const firstItemInput = inputs.nth(1);
    const thirdItemInput = inputs.nth(3);

    await expect(firstItemInput).toHaveValue(/brake pad/i);
    await expect(thirdItemInput).toHaveValue(/fan belt/i);

    await firstItemInput.focus();
    await expect(firstItemInput).toBeFocused();
    await clickTrigger(page, "Set Focus To Shipping");
    await expect.soft(shippingInput).toBeFocused();

    await thirdItemInput.focus();
    await expect(thirdItemInput).toBeFocused();
    await clickTrigger(page, "Set Focus To First Item");
    await expect(firstItemInput).toBeFocused();

    await shippingInput.focus();
    await expect(shippingInput).toBeFocused();
    await clickTrigger(page, "Set Focus To Third Item");
    await expect(thirdItemInput).toBeFocused();
  });

  /*
     After you activate the Rebuild trigger you must see an xforms-rebuild message. You must not see
     a custom-event message.
  */
  test("10.8.1.a — dispatch rebuild renders", async ({ page }) => {
    const msgs = collectDialogMessages(page);
    await loadAndWait(page, "Chapt10/10.8/10.8.1/10.8.1.a.xhtml");
    const beforeCount = msgs.length;
    await clickTrigger(page, "Rebuild");
    const newMessages = msgs.slice(beforeCount);
    expect(newMessages.some((message) => /xforms-rebuild/i.test(message))).toBe(true);
    expect(newMessages.some((message) => /custom-event/i.test(message))).toBe(false);
  });

  /*
     After you activate the Rebuild trigger you must see an xforms-rebuild message. If you see a
     custom-event message you have failed this test case.
  */
  test("10.8.1.b — dispatch rebuild renders", async ({ page }) => {
    const msgs = collectDialogMessages(page);
    await loadAndWait(page, "Chapt10/10.8/10.8.1/10.8.1.b.xhtml");
    const beforeCount = msgs.length;
    await clickTrigger(page, "Rebuild");
    const newMessages = msgs.slice(beforeCount);
    expect(newMessages.some((message) => /xforms-rebuild/i.test(message))).toBe(true);
    expect(newMessages.some((message) => /custom-event/i.test(message))).toBe(false);
  });

  /*
     After you activate the Rebuild trigger you must see an xforms-rebuild message. You must not see
     a custom-event message.
  */
  test("10.8.1.c — dispatch name child @value precedence", async ({ page }) => {
    const msgs = collectDialogMessages(page);
    await loadAndWait(page, "Chapt10/10.8/10.8.1/10.8.1.c.xhtml");
    const beforeCount = msgs.length;
    await clickTrigger(page, "Rebuild");
    const newMessages = msgs.slice(beforeCount);
    expect(newMessages.some((message) => /xforms-rebuild/i.test(message))).toBe(true);
    expect(newMessages.some((message) => /custom-event/i.test(message))).toBe(false);
  });

  /* After you activate the Fire Custom Event trigger you must see a custom-event message. */
  test("10.8.2.a — dispatch custom-event", async ({ page }) => {
    const msgs = collectDialogMessages(page);
    await loadAndWait(page, "Chapt10/10.8/10.8.2/10.8.2.a.xhtml");
    const beforeCount = msgs.length;
    await clickTrigger(page, "Fire Custom Event");
    const newMessages = msgs.slice(beforeCount);
    expect(newMessages.length).toBeGreaterThan(0);
    expect(newMessages.every((message) => message === "custom-event")).toBe(true);
  });

  /*
     After you activate the Fire Custom Event trigger you must see a custom-event message. If you
     see a wrong custom-event message you have failed this test case.
  */
  test("10.8.2.b — dispatch custom-event with target", async ({ page }) => {
    const msgs = collectDialogMessages(page);
    await loadAndWait(page, "Chapt10/10.8/10.8.2/10.8.2.b.xhtml");
    const beforeCount = msgs.length;
    await clickTrigger(page, "Fire Custom Event");
    const newMessages = msgs.slice(beforeCount);
    expect(newMessages).toEqual(["custom-event"]);
  });

  /*
     After you activate the Fire Custom Event trigger you must see a custom-event message. If you
     see a wrong custom-event message you have failed this test case.
  */
  test("10.8.2.c — dispatch custom-event with bubbles and cancelable", async ({ page }) => {
    const msgs = collectDialogMessages(page);
    await loadAndWait(page, "Chapt10/10.8/10.8.2/10.8.2.c.xhtml");
    const beforeCount = msgs.length;
    await clickTrigger(page, "Fire Custom Event");
    const newMessages = msgs.slice(beforeCount);
    expect(newMessages).toEqual(["custom-event"]);
  });

  /* Both triggers must emit xforms-rebuild, with delayed dispatch firing slower than no-delay dispatch. */
  test("10.8.3.a — dispatch delay child element behavior", async ({ page }) => {
    // TEST-TRACE: promote 10.8.3.a from render smoke check to delay-precedence timing assertion.
    await assertDelayedDispatchAppearsSlower(page, "Chapt10/10.8/10.8.3/10.8.3.a.xhtml");
  });

  /* Both triggers must emit xforms-rebuild, with delay child overriding delay attribute. */
  test("10.8.3.b — dispatch delay element precedence over attribute", async ({ page }) => {
    // TEST-TRACE: promote 10.8.3.b from render smoke check to delay-element precedence timing assertion.
    await assertDelayedDispatchAppearsSlower(page, "Chapt10/10.8/10.8.3/10.8.3.b.xhtml");
  });

  /* Both triggers must emit xforms-rebuild, with delay @value overriding inline delay content. */
  test("10.8.3.c — dispatch delay value attribute precedence", async ({ page }) => {
    // TEST-TRACE: promote 10.8.3.c from render smoke check to delay-value precedence timing assertion.
    await assertDelayedDispatchAppearsSlower(page, "Chapt10/10.8/10.8.3/10.8.3.c.xhtml");
  });

  /* After you activate the Rebuild trigger you must see an xforms-rebuild message. */
  test("10.8.a dispatch dispatches xforms-rebuild", async ({ page }) => {
    const dialogMessages = collectDialogMessages(page);
    await loadAndWait(page, "Chapt10/10.8/10.8.a.xhtml");
    await clickTrigger(page, "Rebuild");
    expect(dialogMessages.some((message) => /xforms-rebuild/i.test(message))).toBe(true);
  });

  /* After you activate the Fire Custom Event trigger you must see a custom-event message. */
  test("10.8.b dispatch dispatches custom-event", async ({ page }) => {
    const dialogMessages = collectDialogMessages(page);
    await loadAndWait(page, "Chapt10/10.8/10.8.b.xhtml");
    await clickTrigger(page, "Fire Custom Event");
    expect(dialogMessages.some((message) => /custom-event/i.test(message))).toBe(true);
  });

  /* Both triggers must emit xforms-rebuild, with delay attribute slower than no-delay dispatch. */
  test("10.8.c — dispatch delay attribute behavior", async ({ page }) => {
    // TEST-TRACE: promote 10.8.c from render smoke check to delay-attribute timing assertion.
    await assertDelayedDispatchAppearsSlower(page, "Chapt10/10.8/10.8.c.xhtml");
  });

  /*
     After activating the Fire Custom Event trigger you must see two messages: Child Element and
     Parent Element.
  */
  test("10.8.d — dispatch bubbling event fires child and parent", async ({ page }) => {
    const msgs = collectDialogMessages(page);
    await loadAndWait(page, "Chapt10/10.8/10.8.d.xhtml");
    const beforeCount = msgs.length;
    await clickTrigger(page, "Fire Custom Event");
    const newMessages = msgs.slice(beforeCount);
    expect(newMessages.some((message) => message === "Child Element")).toBe(true);
    expect(newMessages.some((message) => message === "Parent Element")).toBe(true);
  });

  /* When you activate the Fire Custom Event trigger you must not see a custom-event message. */
  test("10.8.e — dispatch non-bubbling event does NOT fire parent", async ({ page }) => {
    const msgs = collectDialogMessages(page);
    await loadAndWait(page, "Chapt10/10.8/10.8.e.xhtml");
    const beforeCount = msgs.length;
    await clickTrigger(page, "Fire Custom Event");
    const newMessages = msgs.slice(beforeCount);
    expect(newMessages).toEqual([]);
  });

  /* When you activate the Reset trigger the value in the input control must NOT change to "Audi". */
  test("10.8.f — 10.8.f dispatch element dispatches cancelled predefined event", async ({ page }) => {
    await loadAndWait(page, "Chapt10/10.8/10.8.f.xhtml");
    const carInput = page.locator("input.xforms-input");
    await expect(carInput).toHaveValue("Kia");
    await clickTrigger(page, "Reset");
    await expect(carInput).toHaveValue("Kia");
    await expect(carInput).not.toHaveValue("Audi");
  });

  /* When you activate the Reset trigger you must see an xforms-reset message. */
  test("10.13.a — reset trigger renders", async ({ page }) => {
    const msgs = collectDialogMessages(page);
    await loadAndWait(page, "Chapt10/10.13/10.13.a.xhtml");
    const beforeCount = msgs.length;
    await clickTrigger(page, "Reset");
    const newMessages = msgs.slice(beforeCount);
    expect(newMessages.some((message) => /xforms-reset/i.test(message))).toBe(true);
  });
  /*
     When you activate the Reset Car Type Value trigger the value in the Car Type output must change
     to "Mercedes". You must NOT see a message. When you activate the Reset Car Color Value trigger
     the value in the Car Color output must change to "white" and you must see an xforms-reset
     message.
  */
  test("10.13.b — 10.13.b reset element with model attribute", async ({ page }) => {
    const dialogMessages = collectDialogMessages(page);
    await loadAndWait(page, "Chapt10/10.13/10.13.b.xhtml");
    let text = await getFormControlText(page);
    expect(text).toMatch(/Car Type\s*:\s*BMW/i);
    expect(text).toMatch(/Car Color\s*:\s*red/i);

    const beforeTypeResetMessages = dialogMessages.length;
    await clickTrigger(page, "Reset Car Type Value");
    text = await getFormControlText(page);
    expect.soft(text).toMatch(/Car Type\s*:\s*Mercedes/i);
    expect(dialogMessages.slice(beforeTypeResetMessages)).toHaveLength(0);

    const beforeColorResetMessages = dialogMessages.length;
    await clickTrigger(page, "Reset Car Color Value");
    text = await getFormControlText(page);
    expect(text).toMatch(/Car Color\s*:\s*white/i);
    expect(dialogMessages.slice(beforeColorResetMessages).some((message) => /xforms-reset/i.test(message))).toBe(true);
  });
  test("10.14.1.a — load resource child element has precedence", async ({ page }) => {
    await loadAndWait(page, "Chapt10/10.14/10.14.1/10.14.1.a.xhtml");
    await clickTrigger(page, "Go To The XForms 1.1 Spec");
    // TEST-TRACE: promote 10.14.1.a from render smoke check to resource-precedence navigation assertion.
    await expect(page).toHaveURL(xformsSpecUrl, { timeout: 15_000 });
  });

  /* After trigger activation this page must be replaced by the XForms 1.1 specification (value attribute precedence). */
  test("10.14.1.b — load value attribute has precedence", async ({ page }) => {
    await loadAndWait(page, "Chapt10/10.14/10.14.1/10.14.1.b.xhtml");
    await clickTrigger(page, "Go To The XForms 1.1 Spec");
    // TEST-TRACE: promote 10.14.1.b from render smoke check to value-precedence navigation assertion.
    await expect(page).toHaveURL(xformsSpecUrl, { timeout: 15_000 });
  });

  /* Activating each trigger must navigate to the XForms 1.1 specification. */
  test("10.14.a — load element attributes navigate to XForms spec", async ({ page }) => {
    const triggerLabels = [
      "Load Xforms Spec From resource Attribute",
      "Load Xforms Spec From ref Attribute",
      "Load Xforms Spec From bind Attribute",
    ];
    // TEST-TRACE: promote 10.14.a from render smoke check by asserting all resource/ref/bind load paths navigate.
    for (const triggerLabel of triggerLabels) {
      await loadAndWait(page, "Chapt10/10.14/10.14.a.xhtml");
      await clickTrigger(page, triggerLabel);
      await expect(page).toHaveURL(xformsSpecUrl, { timeout: 15_000 });
    }
  });

  /* Show default and replace must replace this page, while show=new must open the spec without replacing this page. */
  test("10.14.b — load show attribute semantics", async ({ page }) => {
    await loadAndWait(page, "Chapt10/10.14/10.14.b.xhtml");
    await clickTrigger(page, "Show Not Defined");
    // TEST-TRACE: promote 10.14.b from render smoke check by asserting show-not-defined behaves like replace.
    await expect(page).toHaveURL(xformsSpecUrl, { timeout: 15_000 });

    await loadAndWait(page, "Chapt10/10.14/10.14.b.xhtml");
    await clickTrigger(page, "Show=Replace");
    // TEST-TRACE: assert explicit show=replace replaces current page with the target spec URL.
    await expect(page).toHaveURL(xformsSpecUrl, { timeout: 15_000 });

    await loadAndWait(page, "Chapt10/10.14/10.14.b.xhtml");
    const popupPromise = page.waitForEvent("popup", { timeout: 15_000 });
    await clickTrigger(page, "Show=New");
    const popup = await popupPromise;
    await popup.waitForLoadState("domcontentloaded", { timeout: 15_000 });
    // TEST-TRACE: assert show=new opens the target spec in a new window and preserves this form.
    expect(popup.url()).toMatch(xformsSpecUrl);
    await expect(page.getByRole("button", { name: "Show=New", exact: true })).toBeVisible();
    await popup.close().catch(() => { });
  });

  /* When either trigger is activated you must see an xforms-submit-done message. */
  test("10.15.a — send element emits submit-done for both submissions", async ({ page }) => {
    const dialogMessages = collectDialogMessages(page);
    await loadAndWait(page, "Chapt10/10.15/10.15.a.xhtml");
    // TEST-TRACE: promote 10.15.a from render smoke check to per-trigger submit completion message assertions.
    await assertDialogPatternsAfterTrigger(page, dialogMessages, "Send Color", [/^xforms-submit-done$/i]);
    await assertDialogPatternsAfterTrigger(page, dialogMessages, "Send Condition", [/^xforms-submit-done$/i]);
  });

  /* Both triggers must display "Instance Message", with bind/ref data taking precedence over inline content. */
  test("10.16.a — message bind/ref precedence over inline text", async ({ page }) => {
    const dialogMessages = collectDialogMessages(page);
    await loadAndWait(page, "Chapt10/10.16/10.16.a.xhtml");
    const bindMessages = await assertDialogPatternsAfterTrigger(
      page,
      dialogMessages,
      "Message with bind attribute",
      [/^Instance Message$/i]
    );
    const refMessages = await assertDialogPatternsAfterTrigger(
      page,
      dialogMessages,
      "Message with ref attribute",
      [/^Instance Message$/i]
    );
    // TEST-TRACE: promote 10.16.a from render smoke check to bind/ref precedence assertions over inline content.
    expect(bindMessages.some((message) => /^Inline Message$/i.test(message))).toBe(false);
    expect(refMessages.some((message) => /^Inline Message$/i.test(message))).toBe(false);
  });

  /* Modal, modeless, and ephemeral triggers must each display their corresponding message text. */
  test("10.16.b — message level variants display expected text", async ({ page }) => {
    const dialogMessages = collectDialogMessages(page);
    await loadAndWait(page, "Chapt10/10.16/10.16.b.xhtml");
    const beforeModalMessages = dialogMessages.length;
    await clickTrigger(page, "Display Modal Message");
    await expect.poll(
      () => dialogMessages.slice(beforeModalMessages).some((message) => /^Modal Message$/i.test(message)),
      { timeout: 10_000 }
    ).toBe(true);

    await clickTrigger(page, "Display Modeless Message");
    await expect.poll(
      async () => /INFO:\s*Modeless Message/i.test(await getFormControlText(page)),
      { timeout: 10_000 }
    ).toBe(true);

    await clickTrigger(page, "Display Ephemeral Message");
    await expect.poll(
      async () => /INFO:\s*Ephemeral Message/i.test(await getFormControlText(page)),
      { timeout: 10_000 }
    ).toBe(true);
    // TEST-TRACE: 10.16.b modal uses dialog while modeless/ephemeral render via INFO log lines on page.
  });

  /* When you activate the See Message trigger you must see a message that says "Hello, world!". */
  test("10.16.c — message element shows Hello world", async ({ page }) => {
    const msgs = collectDialogMessages(page);
    await loadAndWait(page, "Chapt10/10.16/10.16.c.xhtml");
    const beforeCount = msgs.length;
    await clickTrigger(page, "See Message");
    const newMessages = msgs.slice(beforeCount);
    expect(newMessages).toContain("Hello, world!");
  });

  /*
     When you activate the Enter Correct Answers trigger you must see numbers appear as answers for
     the equations as well as the value "correct" output beside them. When you activate the Enter
     Incorrect Answers trigger you must see numbers appear as answers for the equations as well as
     the value "incorrect" output beside them.
  */
  test("10.17.a — 10.17.a conditional execution of XForms actions", async ({ page }) => {
    await loadAndWait(page, "Chapt10/10.17/10.17.a.xhtml");
    const assertTimesTableValues = (renderedText: string, expectedValues: number[]): void => {
      expectedValues.forEach((expectedValue, zeroBasedIndex) => {
        const multiplier = zeroBasedIndex + 1;
        expect(renderedText).toMatch(new RegExp(`2\\s*x\\s*${multiplier}\\s*=\\s*${expectedValue}\\b`, "i"));
      });
    };

    await clickTrigger(page, "Enter Correct Answers");
    let text = await getFormControlText(page);
    assertTimesTableValues(text, [2, 4, 6, 8, 10]);

    await clickTrigger(page, "Enter Incorrect Answers");
    text = await getFormControlText(page);
    assertTimesTableValues(text, [0, 0, 0, 0, 0]);
  });

  /*
     When you activate the Positive Test trigger you must see the message "This is the positive
     test". When you activate the Negative Test trigger you must NOT see the message "This is the
     negative test".
  */
  test("10.17.b — 10.17.b conditional execution of XForms actions using action element", async ({ page }) => {
    const dialogMessages = collectDialogMessages(page);
    await loadAndWait(page, "Chapt10/10.17/10.17.b.xhtml");
    // TEST-TRACE: 10.17.b.xhtml uses modal xforms:message; assert positive emits and negative does not.
    const beforePositiveTestMessages = dialogMessages.length;
    await clickTrigger(page, "Positive Test");
    const positiveTestMessages = dialogMessages.slice(beforePositiveTestMessages);
    expect(positiveTestMessages).toContain("This is the positive test");
    expect(positiveTestMessages.some((message) => /This is the negative test/i.test(message))).toBe(false);

    const beforeNegativeTestMessages = dialogMessages.length;
    await clickTrigger(page, "Negative Test");
    const negativeTestMessages = dialogMessages.slice(beforeNegativeTestMessages);
    expect(negativeTestMessages).toHaveLength(0);
    expect(dialogMessages.some((message) => /This is the negative test/i.test(message))).toBe(false);
  });

  /*
     This test case shifts the focus to different input controls depending on if conditions have
     been met. If you enter three characters into the Area Code input the focus must move to the
     Exchange input. If you enter three characters into the Exchange input the focus must move to
     the Local input. If you enter four characters into the Local input the focus must move to the
     Extension input.
  */
  test("10.17.c — 10.17.c conditional execution of XForms actions - Automatic Focus Advancement example", async ({ page }) => {
    await loadAndWait(page, "Chapt10/10.17/10.17.c.xhtml");
    const inputs = page.locator('input.xforms-input');
    await expect(inputs).toHaveCount(4);
    const areaCodeInput = inputs.nth(0);
    const exchangeInput = inputs.nth(1);
    const localInput = inputs.nth(2);
    const extensionInput = inputs.nth(3);

    // TEST-TRACE: assert 10.17.c setfocus thresholds (3 chars to Exchange, 3 to Local, 4 to Extension).
    await areaCodeInput.focus();
    await expect(areaCodeInput).toBeFocused();
    await areaCodeInput.type("12");
    await expect(areaCodeInput).toBeFocused();
    await areaCodeInput.type("3");
    await expect(exchangeInput).toBeFocused();

    await exchangeInput.type("45");
    await expect(exchangeInput).toBeFocused();
    await exchangeInput.type("6");
    await expect(localInput).toBeFocused();

    await localInput.type("789");
    await expect(localInput).toBeFocused();
    await localInput.type("0");
    await expect(extensionInput).toBeFocused();
  });

  /*
     When you activate a Delete Row trigger the trigger and the output control on that row must
     disappear from the page and the focus must move to the Insert Row trigger when the last Delete
     Row trigger is activated.
  */
  test("10.17.d — 10.17.d conditional execution of XForms actions - Handling Focus for Empty Repeats example", async ({ page }) => {
    await loadAndWait(page, "Chapt10/10.17/10.17.d.xhtml");
    const insertRowTrigger = page.getByRole("button", { name: "Insert Row", exact: true });
    const deleteRowTriggers = page.getByRole("button", { name: "Delete Row", exact: true });
    const rowOutputs = page.locator("[data-repeat-item] .xforms-output");

    // TEST-TRACE: assert 10.17.d row delete removes trigger/output each time and last delete moves focus to Insert Row.
    await expect(insertRowTrigger).toBeVisible();
    await expect(deleteRowTriggers).toHaveCount(3);
    await expect(rowOutputs).toHaveCount(3);

    for (let remainingRows = 3; remainingRows >= 1; remainingRows--) {
      await expect(deleteRowTriggers).toHaveCount(remainingRows);
      await expect(rowOutputs).toHaveCount(remainingRows);
      await deleteRowTriggers.first().click();
      await page.waitForTimeout(300);
      await expect(deleteRowTriggers).toHaveCount(remainingRows - 1);
      await expect(rowOutputs).toHaveCount(remainingRows - 1);
    }

    await expect(deleteRowTriggers).toHaveCount(0);
    await expect(rowOutputs).toHaveCount(0);
    await expect(insertRowTrigger).toBeFocused();
  });

  /* You must see the value "10" for the Number Of Nodes output : */
  test("10.18.a — 10.18.a iteration of XForms actions", async ({ page }) => {
    await loadAndWait(page, "Chapt10/10.18/10.18.a.xhtml");
    const text = await getFormControlText(page);
    expect(text).toContain("10");
  });

  /* After you activate the Run Test trigger the Number Of Nodes output must show the value "10". */
  test("10.18.b — 10.18.b iteration of XForms actions using action element", async ({ page }) => {
    await loadAndWait(page, "Chapt10/10.18/10.18.b.xhtml");
    let text = await getFormControlText(page);
    expect(text).toMatch(/Number\s*Of\s*Nodes\s*:\s*1\b/i);

    await clickTrigger(page, "Run Test");
    text = await getFormControlText(page);
    expect(text).toMatch(/Number\s*Of\s*Nodes\s*:\s*10\b/i);
  });

  /* You must see the value "1" for the Number Of Nodes output : */
  test("10.18.c — 10.18.c iteration executed zero times", async ({ page }) => {
    await loadAndWait(page, "Chapt10/10.18/10.18.c.xhtml");
    const text = await getFormControlText(page);
    expect(text).toMatch(/Number\s*Of\s*Nodes\s*:\s*1\b/i);
  });

  /* You must see the value "5" for the Number Of Nodes output : */
  test("10.18.d — 10.18.d XForms actions with if and while attributes", async ({ page }) => {
    await loadAndWait(page, "Chapt10/10.18/10.18.d.xhtml");
    const text = await getFormControlText(page);
    expect(text).toContain("5");
  });

  /* You must see a value of "6" for the Total Sum output and a value of "4" for the Counter output. */
  test("10.18.e — 10.18.e iteration of XForms actions - Summing Selected Results example", async ({ page }) => {
    await loadAndWait(page, "Chapt10/10.18/10.18.e.xhtml");
    let text = await getFormControlText(page);
    expect(text).toMatch(/Total\s*Sum\s*:/i);
    expect(text).toMatch(/Counter\s*:/i);

    await clickTrigger(page, "Get Sum");
    text = await getFormControlText(page);
    expect(text).toMatch(/Total\s*Sum\s*:\s*6\b/i);
    expect(text).toMatch(/Counter\s*:\s*4\b/i);
  });

  /*
     If you change the value in the Car Model input control and activate the Reset trigger the value
     must be set back to the initial value of "Del Sol".
  */
  test("10.a — 10.a action syntax example", async ({ page }) => {
    await loadAndWait(page, "Chapt10/10.a.xhtml");
    const carModel = page.locator("input.xforms-input");
    await expect(carModel).toHaveValue("Del Sol");
    await carModel.fill("Audi");
    await expect(carModel).toHaveValue("Audi");
    await clickTrigger(page, "Reset");
    await expect(carModel).toHaveValue("Del Sol");
  });

  /*
     When you activate the Insert Car trigger you must see an xforms:action message and an
     xforms-rebuild message.
  */
  test("10.b — action with insert fires rebuild", async ({ page }) => {
    const msgs = collectDialogMessages(page);
    await loadAndWait(page, "Chapt10/10.b.xhtml");
    const carModels = page.locator("input.xforms-input");
    await expect(carModels).toHaveCount(1);
    await expect(carModels.first()).toHaveValue(/Pacifica/i);

    const beforeCount = msgs.length;
    await clickTrigger(page, "Insert Car");
    await expect(carModels).toHaveCount(2);

    const newMessages = msgs.slice(beforeCount);
    expect(newMessages.some((message) => /^xforms:action$/i.test(message))).toBe(true);
    expect(newMessages.some((message) => /^xforms-rebuild$/i.test(message))).toBe(true);
  });

  /*
     When you activate the Update Car trigger you must see an xforms:action message and an
     xforms-recalculate message.
  */
  test("10.c — action with setvalue fires recalculate", async ({ page }) => {
    const msgs = collectDialogMessages(page);
    await loadAndWait(page, "Chapt10/10.c.xhtml");
    const carModel = page.locator("input.xforms-input");
    await expect(carModel).toHaveValue(/Pacifica/i);

    const beforeCount = msgs.length;
    await clickTrigger(page, "Update Car");
    await expect(carModel).toHaveValue(/Pilot/i);

    const newMessages = msgs.slice(beforeCount);
    expect(newMessages.some((message) => /^xforms:action$/i.test(message))).toBe(true);
    expect(newMessages.some((message) => /^xforms-recalculate$/i.test(message))).toBe(true);
  });

  /*
     When you activate the Update Car trigger you must see an xforms:action message and an
     xforms-revalidate message.
  */
  test("10.d — action with setvalue fires revalidate", async ({ page }) => {
    const msgs = collectDialogMessages(page);
    await loadAndWait(page, "Chapt10/10.d.xhtml");
    const carModel = page.locator("input.xforms-input");
    await expect(carModel).toHaveValue(/Pacifica/i);

    const beforeCount = msgs.length;
    await clickTrigger(page, "Update Car");
    await expect(carModel).toHaveValue(/Pilot/i);

    const newMessages = msgs.slice(beforeCount);
    expect(newMessages.some((message) => /^xforms:action$/i.test(message))).toBe(true);
    expect(newMessages.some((message) => /^xforms-revalidate$/i.test(message))).toBe(true);
  });

  /*
     When you activate the Update Car trigger you must see an xforms:action message and an
     xforms-refresh message.
  */
  test("10.e — action with setvalue fires refresh", async ({ page }) => {
    const msgs = collectDialogMessages(page);
    await loadAndWait(page, "Chapt10/10.e.xhtml");
    const carModel = page.locator("input.xforms-input");
    await expect(carModel).toHaveValue(/Pacifica/i);

    const beforeCount = msgs.length;
    await clickTrigger(page, "Update Car");
    await expect(carModel).toHaveValue(/Pilot/i);

    const newMessages = msgs.slice(beforeCount);
    expect(newMessages.some((message) => /^xforms:action$/i.test(message))).toBe(true);
    expect(newMessages.some((message) => /^xforms-refresh$/i.test(message))).toBe(true);
  });

  /* Insert trigger must display xforms:action, xforms-rebuild, xforms-recalculate, xforms-revalidate, and xforms-refresh. */
  test("10.f — insert in action emits required lifecycle messages", async ({ page }) => {
    const dialogMessages = collectDialogMessages(page);
    await loadAndWait(page, "Chapt10/10.f.xhtml");
    // TEST-TRACE: promote 10.f from render smoke check to required lifecycle message assertions.
    await assertDialogPatternsAfterTrigger(page, dialogMessages, "Insert", [
      /^xforms:action$/i,
      /^xforms-rebuild$/i,
      /^xforms-recalculate$/i,
      /^xforms-revalidate$/i,
      /^xforms-refresh$/i,
    ]);
  });

  /* Delete trigger must display xforms:action, xforms-rebuild, xforms-recalculate, xforms-revalidate, and xforms-refresh. */
  test("10.g — delete in action emits required lifecycle messages", async ({ page }) => {
    const dialogMessages = collectDialogMessages(page);
    await loadAndWait(page, "Chapt10/10.g.xhtml");
    // TEST-TRACE: promote 10.g from render smoke check to required lifecycle message assertions.
    await assertDialogPatternsAfterTrigger(page, dialogMessages, "Delete", [
      /^xforms:action$/i,
      /^xforms-rebuild$/i,
      /^xforms-recalculate$/i,
      /^xforms-revalidate$/i,
      /^xforms-refresh$/i,
    ]);
  });

  /* Set Value trigger must display xforms:action, xforms-recalculate, xforms-revalidate, and xforms-refresh. */
  test("10.h — setvalue in action emits required lifecycle messages", async ({ page }) => {
    const dialogMessages = collectDialogMessages(page);
    await loadAndWait(page, "Chapt10/10.h.xhtml");
    const newMessages = await assertDialogPatternsAfterTrigger(page, dialogMessages, "Set Value", [
      /^xforms:action$/i,
      /^xforms-recalculate$/i,
      /^xforms-revalidate$/i,
      /^xforms-refresh$/i,
    ]);
    // TEST-TRACE: promote 10.h from render smoke check to required lifecycle message assertions and no-rebuild check.
    expect(newMessages.some((message) => /^xforms-rebuild$/i.test(message))).toBe(false);
  });

  /* Insert/reset trigger must display xforms-rebuild, xforms-recalculate, xforms-revalidate, xforms-refresh, and xforms:action. */
  test("10.i — insert and reset in action emit required lifecycle messages", async ({ page }) => {
    const dialogMessages = collectDialogMessages(page);
    await loadAndWait(page, "Chapt10/10.i.xhtml");
    // TEST-TRACE: promote 10.i from render smoke check to required lifecycle message assertions.
    await assertDialogPatternsAfterTrigger(page, dialogMessages, "Insert", [
      /^xforms:action$/i,
      /^xforms-rebuild$/i,
      /^xforms-recalculate$/i,
      /^xforms-revalidate$/i,
      /^xforms-refresh$/i,
    ]);
  });
});
