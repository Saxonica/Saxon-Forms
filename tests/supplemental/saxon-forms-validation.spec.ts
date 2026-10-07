import { test, expect } from "../fixtures/echo-intercept";

const RENDER_TIMEOUT = 15_000;

async function waitForValidationForm(page: any) {
  await page.goto("/validation.html");
  await expect(page.locator("#validation-root")).toBeVisible({ timeout: RENDER_TIMEOUT });
}

function inputControlWrapper(input: any) {
  return input.locator("xpath=ancestor::div[contains(concat(' ', normalize-space(@class), ' '), ' xforms-input ')][1]");
}

test.describe("Validation class MIPs on revalidate/refresh", () => {
  test("invalid xs:dateTime gets xforms-invalid", async ({ page }) => {
    // TEST-TRACE: captures missing invalid-class refresh propagation after xf:revalidate; helps tests/supplemental/saxon-forms-validation.spec.ts "invalid xs:dateTime gets xforms-invalid".
    await waitForValidationForm(page);

    const issuedAtInput = page.locator("input[id^='issued-at-input']");
    const issuedAtWrapper = inputControlWrapper(issuedAtInput);
    const revalidateButton = page.locator("button[data-action*='revalidate-trigger']");

    await issuedAtInput.fill("afs");
    await revalidateButton.click();

    await expect(issuedAtWrapper).toHaveClass(/xforms-invalid/);
    await expect(issuedAtWrapper).not.toHaveClass(/xforms-valid/);
  });

  test("empty required field gets xforms-required and xforms-invalid", async ({ page }) => {
    // TEST-TRACE: captures missing required+invalid MIP classes after xf:revalidate; helps tests/supplemental/saxon-forms-validation.spec.ts "empty required field gets xforms-required and xforms-invalid".
    await waitForValidationForm(page);

    const requiredInput = page.locator("input[id^='required-input']");
    const requiredWrapper = inputControlWrapper(requiredInput);
    const revalidateButton = page.locator("button[data-action*='revalidate-trigger']");

    await requiredInput.fill("");
    await revalidateButton.click();

    await expect(requiredWrapper).toHaveClass(/xforms-required/);
    await expect(requiredWrapper).toHaveClass(/xforms-invalid/);
  });

  test("valid xs:dateTime gets xforms-valid", async ({ page }) => {
    // TEST-TRACE: captures missing valid-class refresh propagation after xf:revalidate; helps tests/supplemental/saxon-forms-validation.spec.ts "valid xs:dateTime gets xforms-valid".
    await waitForValidationForm(page);

    const issuedAtInput = page.locator("input[id^='issued-at-input']");
    const issuedAtWrapper = inputControlWrapper(issuedAtInput);
    const revalidateButton = page.locator("button[data-action*='revalidate-trigger']");

    await issuedAtInput.fill("2026-05-18T14:30:00Z");
    await revalidateButton.click();

    await expect(issuedAtWrapper).toHaveClass(/xforms-valid/);
    await expect(issuedAtWrapper).not.toHaveClass(/xforms-invalid/);
  });

  test("correcting invalid value removes xforms-invalid", async ({ page }) => {
    // TEST-TRACE: captures missing invalid->valid class transition after correction; helps tests/supplemental/saxon-forms-validation.spec.ts "correcting invalid value removes xforms-invalid".
    await waitForValidationForm(page);

    const issuedAtInput = page.locator("input[id^='issued-at-input']");
    const issuedAtWrapper = inputControlWrapper(issuedAtInput);
    const revalidateButton = page.locator("button[data-action*='revalidate-trigger']");

    await issuedAtInput.fill("afs");
    await revalidateButton.click();
    await expect(issuedAtWrapper).toHaveClass(/xforms-invalid/);

    await issuedAtInput.fill("2026-05-18T14:30:00Z");
    await revalidateButton.click();
    await expect(issuedAtWrapper).not.toHaveClass(/xforms-invalid/);
    await expect(issuedAtWrapper).toHaveClass(/xforms-valid/);
  });
});
