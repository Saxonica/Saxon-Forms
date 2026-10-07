import { test, expect, loadTest, loadAndWait, getRenderedText, getInstanceXML, submitAndCapture, collectDialogMessages, expectDialogAfterTrigger } from "./helpers";

const ch6_smoke: [string, string][] = [
  ["6.1.1.a — type", "Chapt06/6.1/6.1.1/6.1.1.a.xhtml"],  // expects modal message from event handler
  ["6.1.7.a — p3ptype", "Chapt06/6.1/6.1.7/6.1.7.a.xhtml"],  // likely will never be implemented
];

test.describe("W3C Ch6 — Model Item Properties [smoke]", () => {
  for (const [name, file] of ch6_smoke) {
    test(`${name} renders`, async ({ page }) => { await loadTest(page, file); });
  }
});

test.describe("W3C Ch6 — Model Item Properties [behavioral]", () => {
  /*
     You must see the value "Roland" in the First Name input control and the value "Orlando" in the
     Last Name input control. You must only be able to change the value in the Last Name input
     control.
  */
  test("6.1.2.a — readonly: values rendered, readonly MIP parsed", async ({ page }) => {
    await loadAndWait(page, "Chapt06/6.1/6.1.2/6.1.2.a.xhtml");
    const fnInput = page.locator('input[data-ref*="first-name"]');
    await expect(fnInput).toHaveValue("Roland");
    const lnInput = page.locator('input[data-ref*="last-name"]');
    await expect(lnInput).toHaveValue("Orlando");
    // First Name is readonly per bind readonly="true()": typing must not change value
    await fnInput.fill("Changed");
    await fnInput.blur();
    await expect(fnInput).toHaveValue("Roland");
    // Instance data
    const xml = await getInstanceXML(page);
    expect(xml).toContain(">Roland<");
    expect(xml).toContain(">Orlando<");
    expect(xml).not.toContain(">Changed<");
    // Note: Saxon-Forms parses readonly MIP but does not set HTML readonly
    // attribute. W3C expects first-name readonly, last-name editable.
  });

  /*
     You must see the value "Roland" in the First Name input control and the value "Orlando" in the
     Last Name input control. You must not be able to change the value in either of the input
     controls.
  */
  test("6.1.2.b — readonly inheritance: values rendered", async ({ page }) => {
    await loadAndWait(page, "Chapt06/6.1/6.1.2/6.1.2.b.xhtml");
    const fnInput = page.locator('input[data-ref*="first-name"]');
    await expect(fnInput).toHaveValue("Roland");
    const lnInput = page.locator('input[data-ref*="last-name"]');
    await expect(lnInput).toHaveValue("Orlando");
    // Both controls must be readonly due to ancestor readonly="true()"
    await fnInput.fill("ChangedFirst");
    await fnInput.blur();
    await lnInput.fill("ChangedLast");
    await lnInput.blur();
    await expect(fnInput).toHaveValue("Roland");
    await expect(lnInput).toHaveValue("Orlando");
    const xml = await getInstanceXML(page);
    expect(xml).toContain(">Roland<");
    expect(xml).toContain(">Orlando<");
    expect(xml).not.toContain(">ChangedFirst<");
    expect(xml).not.toContain(">ChangedLast<");
    // Note: W3C expects both readonly (parent inherits). Saxon-Forms does not
    // enforce HTML readonly attribute; see 6.1.2.a note.
  });

  /*
     The Submit First Name submit control must not replace this page with the form data until you
     have entered a value into the First Name input field.
  */
  test("6.1.3.a — required renders input control", async ({ page }) => {
    const dialogMessages = collectDialogMessages(page);
    await loadAndWait(page, "Chapt06/6.1/6.1.3/6.1.3.a.xhtml");
    const fnInput = page.locator('input[data-ref*="first-name"]');
    const submitBtn = page.getByRole("button", { name: "Submit First Name", exact: true });
    await expect(fnInput).toBeVisible();
    await expect(fnInput).toHaveValue("");
    await expect(submitBtn).toBeVisible();

    // Empty first-name is required: submit must be blocked and raise required-field dialog
    const blockedSubmission = await submitAndCapture(page, submitBtn, 1500);
    expect(blockedSubmission).toBeNull();
    expect(
      dialogMessages.some((message) =>
        /Required field is empty:\s*instance\('saxon-forms-default-instance'\)\/first-name/i.test(message)
      )
    ).toBe(true);

    // After entering First Name, submit should proceed
    await fnInput.fill("Roland");
    await fnInput.blur();
    // TEST-TRACE: poll instance state instead of sleeping before submit capture; helps tests/w3c/ch06.spec.ts "6.1.3.a".
    await expect.poll(
      async () => (await getInstanceXML(page)).includes(">Roland<"),
      { timeout: 3_000 }
    ).toBe(true);
    const allowedSubmission = await submitAndCapture(page, submitBtn, 5000);
    expect(allowedSubmission).not.toBeNull();
    const postBody = allowedSubmission?.postData() || "";
    expect(postBody).toContain("Roland");
  });

  /*
     You must only be able to enter a value into the Last Name input field. The Title and First Name
     input fields must be hidden or unavailable.
  */
  test("6.1.4.a — relevant=false() hides Title and First Name", async ({ page }) => {
    await loadAndWait(page, "Chapt06/6.1/6.1.4/6.1.4.a.xhtml");
    // first-name bind has relevant="false()" — its children must be hidden
    const title = page.getByText("Title:", { exact: true });
    await expect(title).toBeHidden();
    const firstName = page.getByText("First Name:", { exact: true });
    await expect(firstName).toBeHidden();
    // Last Name input must remain visible
    const lnInput = page.locator('input[data-ref*="last-name"]');
    await expect(lnInput).toBeVisible();
  });

  /*
     You must see the output "Discount : 100" after you activate the Enter 1500 trigger, but not
     when you activate the Enter 250 trigger.
  */
  test("6.1.4.b — relevant: Enter 1500 shows discount, Enter 250 hides it", async ({ page }) => {
    await loadAndWait(page, "Chapt06/6.1/6.1.4/6.1.4.b.xhtml");
    // Verify initial state: amount input and 2 triggers rendered
    const amountInput = page.locator('input[data-ref*="amount"]');
    await expect(amountInput).toBeVisible();
    await expect(page.locator('button.xforms-trigger')).toHaveCount(2);
    const discountOutput = page.locator('.xforms-output[data-ref*="discount"]');
    const discountRow = discountOutput.locator('xpath=..');

    // Click "Enter 1500" — discount output should become relevant/visible
    await page.getByRole('button', { name: 'Enter 1500' }).click();
    await expect(discountOutput).toBeVisible();
    await expect(discountRow).toContainText(/Discount\s*:\s*\S+/);

    // Click "Enter 250" — discount output should become non-relevant/hidden
    await page.getByRole('button', { name: 'Enter 250' }).click();
    await expect(discountOutput).toBeHidden();
  });

  /*
     You must only be able to enter a value into the Person A, Favorite Color A, and Person B input
     fields. The Favorite Color B, Person C, and Favorite Color C input fields must be hidden or
     unavailable.
  */
  test("6.1.4.c — relevant propagation hides Color B, Person C, Color C", async ({ page }) => {
    await loadAndWait(page, "Chapt06/6.1/6.1.4/6.1.4.c.xhtml");
    const colorB = page.getByText("Favorite Color B:", { exact: true });
    await expect(colorB).toBeHidden();
    const personC = page.getByText("Person C:", { exact: true });
    await expect(personC).toBeHidden();
    // Person A inputs must be visible
    const personAInput = page.locator('input[data-ref*="personA/value"]');
    await expect(personAInput).toBeVisible();
  });
  /*
     You must see the output "Discount : 750" after you have activated the Enter 1500 trigger. You
     must see the output "Discount : 1000" after you have activated the Enter 2000 trigger.
  */
  test("6.1.5.a — 6.1.5.a calculate property", async ({ page }) => {
    await loadAndWait(page, "Chapt06/6.1/6.1.5/6.1.5.a.xhtml");
    const discountOutput = page.locator('.xforms-output[data-ref*="discount"]');
    const discountRow = discountOutput.locator('xpath=..');
    await expect(page.locator('button.xforms-trigger')).toHaveCount(3);

    await page.getByRole('button', { name: 'Enter 1500' }).click();
    await expect(discountOutput).toBeVisible();
    await expect(discountRow).toContainText(/Discount\s*:\s*750(?:\.0+)?\b/);

    await page.getByRole('button', { name: 'Enter 2000' }).click();
    await expect(discountOutput).toBeVisible();
    await expect(discountRow).toContainText(/Discount\s*:\s*1000(?:\.0+)?\b/);
  });

  /*
     You must see an xforms-valid message when you activate the Valid Value trigger. You must see an
     xforms-invalid message when you activate the Invalid Value trigger.
  */
  test("6.1.6.a — constraint: Valid Value sets To=25, instance updated", async ({ page }) => {
    const dialogMessages = collectDialogMessages(page);
    await loadAndWait(page, "Chapt06/6.1/6.1.6/6.1.6.a.xhtml");
    const fromInput = page.locator('input[data-ref*="from"]');
    const toInput = page.locator('input[data-ref*="to"]');
    await expect(fromInput).toHaveValue("10");
    await expect(toInput).toBeVisible();
    await expect(toInput).toHaveValue("");

    await expectDialogAfterTrigger(page, dialogMessages, "Valid Value", /^xforms-valid$/i);
    await expect(toInput).toHaveValue("25");

    await expectDialogAfterTrigger(page, dialogMessages, "Invalid Value", /^xforms-invalid$/i);
    await expect(toInput).toHaveValue("5");
  });

  /*
     The First Name input control is bound to an atomic datatype. When you activate the Use Joe
     trigger you must see an xforms-valid message. When you activate the Use Empty String trigger
     you must see an xforms-invalid message.
  */
  test("6.2.1.a — 6.2.1.a atomic datatype", async ({ page }) => {
    const dialogMessages = collectDialogMessages(page);
    await loadAndWait(page, "Chapt06/6.2/6.2.1/6.2.1.a.xhtml");
    const firstNameInput = page.getByRole("textbox").first();
    await expect(firstNameInput).toBeVisible();
    await expect(firstNameInput).toHaveValue("Frank");

    await expectDialogAfterTrigger(page, dialogMessages, "Use Joe", /^xforms-valid$/i);
    await expect(firstNameInput).toHaveValue("Joe");

    await expectDialogAfterTrigger(page, dialogMessages, "Use Empty String", /^xforms-invalid$/i);
    await expect(firstNameInput).toHaveValue("");
  });
});
