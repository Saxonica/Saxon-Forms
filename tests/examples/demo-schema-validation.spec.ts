import { test, expect } from "@playwright/test";
import { startExamplesServer, waitForServerReady, stopServer } from "./examples-server";

const examplesPort = 5198;
const renderTimeoutMs = 15_000;
function splitClassTokens(classValue: string | null): string[] {
  return (classValue ?? "")
    .split(/\s+/)
    .map((token) => token.trim())
    .filter((token) => token.length > 0);
}

test.describe("Schema validation demo", () => {
  test.describe.configure({ mode: "serial" });
  let examplesServer;

  test.beforeAll(async () => {
    examplesServer = startExamplesServer(examplesPort);
    await waitForServerReady(examplesServer);
  });

  test.afterAll(async () => {
    await stopServer(examplesServer);
  });

  test("renders schema demo controls", async ({ page }) => {
    await page.goto(`${examplesServer.baseUrl}/demo-schema-validation.html`);
    await expect(page.locator("#xForm .xforms-input").first()).toBeVisible({ timeout: renderTimeoutMs });
    await expect(page.locator("#xForm")).toContainText("Order ID:");
    await expect(page.locator("#xForm")).toContainText("Delivery Window:");
    await expect(page.locator("#xForm")).toContainText("Submit Purchase");
  });

  test("typed values persist after blur", async ({ page }) => {
    await page.goto(`${examplesServer.baseUrl}/demo-schema-validation.html`);
    await expect(page.locator("#xForm .xforms-input").first()).toBeVisible({ timeout: renderTimeoutMs });

    const orderIdInput = page.getByRole("textbox", { name: "Pattern: AAA-1234" });
    const emailInput = page.getByRole("textbox", { name: "Must look like a valid email address." });
    const orderDateInput = page.getByRole("textbox", { name: "Type: xs:date" });
    const quantityInput = page.getByRole("textbox", { name: "1 to 500" });
    const unitPriceInput = page.getByRole("textbox", { name: "Decimal with exactly 2 fraction digits." });
    const deliveryWindowInput = page.getByRole("textbox", { name: "Duration between PT12H and P7D (for example P2D)." });
    const tagsInput = page.getByRole("textbox", { name: "Space-separated NMTOKENS, at least 2 values." });

    await orderIdInput.fill("ABC-1234");
    await page.locator("body").click();
    await expect(orderIdInput).toHaveValue("ABC-1234");

    await emailInput.fill("qa@example.org");
    await page.locator("body").click();
    await expect(emailInput).toHaveValue("qa@example.org");

    await orderDateInput.fill("2026-05-21");
    await page.locator("body").click();
    await expect(orderDateInput).toHaveValue("2026-05-21");

    await quantityInput.fill("42");
    await page.locator("body").click();
    await expect(quantityInput).toHaveValue("42");

    await unitPriceInput.fill("12.34");
    await page.locator("body").click();
    await expect(unitPriceInput).toHaveValue("12.34");

    await deliveryWindowInput.fill("P3D");
    await page.locator("body").click();
    await expect(deliveryWindowInput).toHaveValue("P3D");

    await tagsInput.fill("priority wholesale");
    await page.locator("body").click();
    await expect(tagsInput).toHaveValue("priority wholesale");
  });

  test("orderId pattern facet marks invalid then valid", async ({ page }) => {
    await page.goto(`${examplesServer.baseUrl}/demo-schema-validation.html`);
    await expect(page.locator("#xForm .xforms-input").first()).toBeVisible({ timeout: renderTimeoutMs });

    const orderIdInput = page.getByRole("textbox", { name: "Pattern: AAA-1234" });

    await orderIdInput.fill("bad");
    await page.locator("body").click();
    await expect(orderIdInput).toHaveValue("bad");
    await expect(orderIdInput).toHaveClass(/xforms-invalid/);

    await orderIdInput.fill("ABC-1234");
    await page.locator("body").click();
    await expect(orderIdInput).toHaveValue("ABC-1234");
    await expect(orderIdInput).toHaveClass(/xforms-valid/);
  });

  test("repeated submit keeps validation class tokens unique", async ({ page }) => {
    // TEST-TRACE: guards against refresh-time class accumulation on repeated submit; helps tests/supplemental/demo-schema-validation.spec.ts "repeated submit keeps validation class tokens unique".
    await page.goto(`${examplesServer.baseUrl}/demo-schema-validation.html`);
    await expect(page.locator("#xForm .xforms-input").first()).toBeVisible({ timeout: renderTimeoutMs });

    const orderIdInput = page.getByRole("textbox", { name: "Pattern: AAA-1234" });
    const submitPurchaseButton = page.getByRole("button", { name: "Submit Purchase" });
    const classSignatures: string[] = [];

    for (let index = 0; index < 3; index += 1) {
      await submitPurchaseButton.click();
      await expect(orderIdInput).toHaveClass(/xforms-valid/);
      await expect(orderIdInput).toHaveClass(/xforms-required/);

      const classTokens = splitClassTokens(await orderIdInput.getAttribute("class"));
      expect(classTokens).toContain("xforms-input");
      expect(classTokens).toContain("xforms-valid");
      expect(classTokens).toContain("xforms-required");
      expect(new Set(classTokens).size).toBe(classTokens.length);
      classSignatures.push([...classTokens].sort().join(" "));
    }

    expect(new Set(classSignatures).size).toBe(1);
  });

  test("invalid orderId does not submit purchase request", async ({ page }) => {
    const requests: string[] = [];
    page.on("request", (request) => {
      if (request.method() === "POST" && request.url().includes("/api/purchase")) {
        requests.push(request.url());
      }
    });

    await page.goto(`${examplesServer.baseUrl}/demo-schema-validation.html`);
    await expect(page.locator("#xForm .xforms-input").first()).toBeVisible({ timeout: renderTimeoutMs });

    const orderIdInput = page.getByRole("textbox", { name: "Pattern: AAA-1234" });
    await orderIdInput.fill("ORD-10241");
    await page.locator("body").click();
    await expect(orderIdInput).toHaveClass(/xforms-invalid/);

    await page.getByRole("button", { name: "Submit Purchase" }).click();
    await page.waitForTimeout(500);

    expect(requests).toEqual([]);
  });
});
