import { test, expect, loadAndWait, getInstanceXML, submitAndCapture, isUnavailable, getFormControlText } from "./helpers";

test.describe("W3C Ch2 — Introduction [behavioral]", () => {
  /*
     You must see a select1 control with the values "Cash" and "Credit" as well as two input
     controls on the page. When you activate the Submit Now submit control this page must be
     replaced by the form data. You must see the value "cc" if you had selected Credit or the value
     "cash" if you had selected Cash. You must also see the values, if any, you entered in the
     Credit Card Number and Expiration Date input controls.
  */
  test("2.1.a — select1 with Cash/Credit and input controls", async ({ page }) => {
    await loadAndWait(page, "Chapt02/2.1.a.xhtml");

    // 1. select1 control with values "Cash" and "Credit"
    const select = page.locator('select.xforms-select');
    await expect(select).toHaveCount(1);
    const options = select.locator('option');
    await expect(options).toHaveCount(2);
    await expect(options.nth(0)).toHaveText("Cash");
    await expect(options.nth(1)).toHaveText("Credit");
    // Default instance value is "cc" so "Credit" should be selected
    await expect(select).toHaveValue("cc");

    // 2. Two input controls: Credit Card Number and Expiration Date
    const inputs = page.locator('input.xforms-input');
    await expect(inputs).toHaveCount(2);
    const text = await getFormControlText(page);
    expect(text).toContain("Credit Card Number:");
    expect(text).toContain("Expiration Date:");

    // Select Cash — input controls must remain visible
    await select.selectOption("cash");
    await expect(inputs.nth(0)).toBeVisible();
    await expect(inputs.nth(1)).toBeVisible();

    // Enter values in input controls
    await inputs.nth(0).fill("4111111111111111");
    await inputs.nth(0).blur();
    await inputs.nth(1).fill("12/2025");
    await inputs.nth(1).blur();
    // TEST-TRACE: poll instance XML instead of sleeping so model-update timing is deterministic; helps tests/w3c/ch02.spec.ts "2.1.a".
    await expect.poll(
      async () => {
        const snapshot = await getInstanceXML(page);
        return snapshot.includes("cash") &&
          snapshot.includes("4111111111111111") &&
          snapshot.includes("12/2025");
      },
      { timeout: 3_000 }
    ).toBe(true);

    // Instance data must reflect all user interactions
    const xml = await getInstanceXML(page);
    expect(xml).toContain("cash");
    expect(xml).toContain("4111111111111111");
    expect(xml).toContain("12/2025");

    // 3. Submit Now — must trigger form submission
    const submitBtn = page.locator('button[data-submit="submit"]');
    await expect(submitBtn).toBeVisible();
    await expect(submitBtn).toContainText("Submit Now");

    // Verify Submit fires a POST (echo.sh is intercepted by the shared fixture)
    const requestPromise = page.waitForRequest(
      (req: any) => req.url().includes('echo.sh'),
      { timeout: 5000 }
    ).catch(() => null);
    await submitBtn.click();
    const submissionRequest = await requestPromise;

    // Spec: "this page must be replaced by the form data"
    expect(submissionRequest, 'Submit Now must trigger form submission').not.toBeNull();
    // Submitted data must contain selected method and entered values
    const postBody = submissionRequest?.postData() || '';
    expect(postBody).toContain('cash');
    expect(postBody).toContain('4111111111111111');
    expect(postBody).toContain('12/2025');
  });

  /*
     You must see a select1 control with the values "Cash" and "Credit" as well as two input
     controls on the page. When you activate the Submit Now submit control this page must be
     replaced by the form data. You must see the value "cc" if you had selected Credit or the value
     "cash" if you had selected Cash. You must also see the values, if any, you entered in the
     Credit Card Number and Expiration Date input controls.
  */
  test("2.2.a — instance with select1 and inputs", async ({ page }) => {
    await loadAndWait(page, "Chapt02/2.2.a.xhtml");
    // 1. select1 control with values "Cash" and "Credit"
    const select = page.locator('select.xforms-select');
    await expect(select).toHaveCount(1);
    const options = select.locator('option');
    await expect(options).toHaveCount(2);
    await expect(options.nth(0)).toHaveText("Cash");
    await expect(options.nth(1)).toHaveText("Credit");
    // Default instance value is "cc" so "Credit" should be selected
    await expect(select).toHaveValue("cc");

    // 2. Two input controls: Credit Card Number and Expiration Date
    const inputs = page.locator('input.xforms-input');
    await expect(inputs).toHaveCount(2);
    const text = await getFormControlText(page);
    expect(text).toContain("Credit Card Number:");
    expect(text).toContain("Expiration Date:");

    // Select Cash — input controls must remain visible
    await select.selectOption("cash");
    await expect(inputs.nth(0)).toBeVisible();
    await expect(inputs.nth(1)).toBeVisible();

    // Enter values in input controls
    await inputs.nth(0).fill("4111111111111111");
    await inputs.nth(0).blur();
    await inputs.nth(1).fill("12/2025");
    await inputs.nth(1).blur();
    // TEST-TRACE: poll instance XML instead of sleeping so model-update timing is deterministic; helps tests/w3c/ch02.spec.ts "2.2.a".
    await expect.poll(
      async () => {
        const snapshot = await getInstanceXML(page);
        return snapshot.includes("cash") &&
          snapshot.includes("4111111111111111") &&
          snapshot.includes("12/2025");
      },
      { timeout: 3_000 }
    ).toBe(true);

    // Instance data must reflect all user interactions
    const xml = await getInstanceXML(page);
    expect(xml).toContain("cash");
    expect(xml).toContain("4111111111111111");
    expect(xml).toContain("12/2025");

    // 3. Submit Now — must trigger form submission
    const submitBtn = page.locator('button[data-submit=\"submit\"]');
    await expect(submitBtn).toBeVisible();
    await expect(submitBtn).toContainText("Submit Now");

    // Verify Submit fires a POST (echo.sh is intercepted by the shared fixture)
    const requestPromise = page.waitForRequest(
      (req: any) => req.url().includes('echo.sh'),
      { timeout: 5000 }
    ).catch(() => null);
    await submitBtn.click();
    const submissionRequest = await requestPromise;

    // Spec: "this page must be replaced by the form data"
    expect(submissionRequest, 'Submit Now must trigger form submission').not.toBeNull();
    // Submitted data must contain selected method and entered values
    const postBody = submissionRequest?.postData() || '';
    expect(postBody).toContain('cash');
    expect(postBody).toContain('4111111111111111');
    expect(postBody).toContain('12/2025');


  });

  /*
     You must see a select1 control with the values "Cash" and "Credit" as well as two input
     controls on the page. The Credit Card Number and Expiration Date input controls are set to be
     relevant only when Credit is selected. If you have selected Cash then you must be able to
     submit the form and the input controls must have become unavailable.
  */
  test("2.3.a — renders select1 and credit inputs with default Credit selection", async ({ page }) => {
    await loadAndWait(page, "Chapt02/2.3.a.xhtml");
    const select = page.locator("select.xforms-select");
    await expect(select).toHaveCount(1);
    const options = select.locator("option");
    await expect(options).toHaveCount(2);
    await expect(options.nth(0)).toHaveText("Cash");
    await expect(options.nth(1)).toHaveText("Credit");
    await expect(select).toHaveValue("cc");

    const inputs = page.locator("input.xforms-input");
    await expect(inputs).toHaveCount(2);
    await expect(inputs.nth(0)).toBeVisible();
    await expect(inputs.nth(1)).toBeVisible();

    await select.selectOption("cash");
    await expect(inputs.nth(0)).not.toBeVisible();
    await expect(inputs.nth(1)).not.toBeVisible();

    const submitBtn = page.locator('button[data-submit="submit01"]');
    await expect(submitBtn).toBeVisible();
    await expect(submitBtn).toContainText("Submit Now");

    // Verify Submit fires a POST (echo.sh is intercepted by the shared fixture)
    const requestPromise = page.waitForRequest(
      (req: any) => req.url().includes('echo.sh'),
      { timeout: 5000 }
    ).catch(() => null);
    await submitBtn.click();
    const submissionRequest = await requestPromise;
  });

  test("2.3.a — selecting Cash makes credit inputs unavailable", async ({ page }) => {
    await loadAndWait(page, "Chapt02/2.3.a.xhtml");

    const select = page.locator("select.xforms-select");
    const inputs = page.locator("input.xforms-input");

    await select.selectOption("cash");
    // TEST-TRACE: replace fixed delay with poll-based availability checks; helps tests/w3c/ch02.spec.ts "2.3.a — selecting Cash makes credit inputs unavailable".
    await expect.poll(() => isUnavailable(inputs.nth(0)), { timeout: 3_000 }).toBe(true);
    await expect.poll(() => isUnavailable(inputs.nth(1)), { timeout: 3_000 }).toBe(true);
  });

  test("2.3.a — selecting Cash still allows submit", async ({ page }) => {
    await loadAndWait(page, "Chapt02/2.3.a.xhtml");

    const select = page.locator("select.xforms-select");
    const submitBtn = page.locator('button[data-submit="submit01"]');

    await select.selectOption("cash");
    await expect(submitBtn).toBeVisible();
    await expect(submitBtn).toContainText("Submit Now");

    const submissionRequest = await submitAndCapture(page, submitBtn, 5000);
    expect(submissionRequest, "Cash selection should still allow submit").not.toBeNull();
    const postBody = submissionRequest?.postData() || "";
    expect(postBody).toContain("cash");
  });

  test("2.3.a — Credit blocks invalid values and submits only after valid card + gYearMonth", async ({ page }) => {
    await loadAndWait(page, "Chapt02/2.3.a.xhtml");

    const select = page.locator("select.xforms-select");
    const cardInput = page.locator("input.xforms-input").nth(0);
    const expiryInput = page.locator("input.xforms-input").nth(1);
    const submitBtn = page.locator('button[data-submit="submit01"]');

    await select.selectOption("cc");
    await expect(cardInput).toBeVisible();
    await expect(expiryInput).toBeVisible();

    await cardInput.fill("1234567890123");
    await cardInput.blur();
    await expiryInput.fill("2025-12");
    await expiryInput.blur();

    const invalidSubmission = await submitAndCapture(page, submitBtn, 1500);
    expect(
      invalidSubmission,
      "Credit with an invalid 13-digit card number must not submit"
    ).toBeNull();

    await cardInput.fill("12345678901234");
    await cardInput.blur();
    await expiryInput.fill("2025-12");
    await expiryInput.blur();

    const validSubmission = await submitAndCapture(page, submitBtn, 5000);
    expect(
      validSubmission,
      "Credit with valid card and gYearMonth expiry should submit"
    ).not.toBeNull();

    const postBody = validSubmission?.postData() || "";
    expect(postBody).toContain("cc");
    expect(postBody).toContain("12345678901234");
    expect(postBody).toContain("2025-12");
  });

  /*
     You must see a select1 control with the values "Cash" and "Credit" as well as two input
     controls on the page. The Credit Card Number and Expiration Date input controls are set to be
     relevant only when Credit is selected. If you have selected Cash then you must be able to
     submit the form and the input controls must have become unavailable.
  */
  test("2.4.a — complete example with select1 and inputs", async ({ page }) => {
    await loadAndWait(page, "Chapt02/2.4.a.xhtml");
    const text = await getFormControlText(page);
    expect(text).toContain("Cash");
  });
});
