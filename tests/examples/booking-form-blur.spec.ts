import { test, expect, type Locator, type Page } from "@playwright/test";
import {
  startExamplesServer,
  stopServer,
  waitForServerReady,
  type RunningServer
} from "./examples-server";

/*
This test suite verifies functionality of the underlying Saxon-Forms engine and should survive any changes to the
example booking form. 
*/

const renderTimeoutMs = 15_000;
const examplesPort = 5206;

async function installBlurCounter(locator: Locator): Promise<void> {
  await locator.evaluate((element) => {
    const input = element as HTMLInputElement & {
      __blurCount?: number;
      __blurListenerInstalled?: boolean;
    };
    input.__blurCount = 0;
    if (!input.__blurListenerInstalled) {
      input.addEventListener("blur", () => {
        input.__blurCount = (input.__blurCount || 0) + 1;
      });
      input.__blurListenerInstalled = true;
    }
  });
}

async function getBlurCount(locator: Locator): Promise<number> {
  return locator.evaluate((element) => {
    const input = element as HTMLInputElement & { __blurCount?: number };
    return input.__blurCount || 0;
  });
}

async function expectActiveElement(page: Page, locator: Locator): Promise<void> {
  await expect(locator).toBeFocused();
  await expect(
    locator.evaluate((element) => document.activeElement === element)
  ).resolves.toBe(true);
}
async function getInstanceFieldValue(page: Page, fieldName: "EventDate" | "EventTime"): Promise<string> {
  return page.evaluate((field) => {
    const getInstanceFn = (window as Window & { getInstance?: (name: string) => Element | null }).getInstance;
    if (typeof getInstanceFn !== "function") {
      return "";
    }
    const instanceRoot = getInstanceFn("booking");
    const fieldNode = instanceRoot?.querySelector(field);
    return (fieldNode?.textContent || "").trim();
  }, fieldName);
}
async function seedBookingInstance(page: Page): Promise<void> {
  await page.evaluate(() => {
    const win = window as Window & {
      getInstance?: (name: string) => Element | null;
      setInstance?: (name: string, value: Element) => void;
    };
    if (typeof win.getInstance !== "function" || typeof win.setInstance !== "function") {
      return;
    }
    const instanceRoot = win.getInstance("booking");
    if (!instanceRoot) {
      return;
    }
    const nextRoot = instanceRoot.cloneNode(true) as Element;
    const eventDate = nextRoot.querySelector("EventDate");
    const eventTime = nextRoot.querySelector("EventTime");
    if (eventDate) {
      eventDate.textContent = "2026-12-31";
    }
    if (eventTime) {
      eventTime.textContent = "12:34:00";
    }
    win.setInstance("booking", nextRoot);
  });
}

test.describe("Examples Booking Form native date/time blur behavior", () => {
  test.describe.configure({ mode: "serial" });
  let examplesServer: RunningServer;

  test.beforeAll(async () => {
    examplesServer = startExamplesServer(examplesPort);
    await waitForServerReady(examplesServer);
  });

  test.afterAll(async () => {
    await stopServer(examplesServer);
  });

  test("date/time controls do not blur while editing internal segments", async ({ page }) => {
    await page.goto(`${examplesServer.baseUrl}/sample1.html`);
    await expect(page.locator("#xForm .xforms-input").first()).toBeVisible({ timeout: renderTimeoutMs });

    const titleInput = page.locator("#xForm .xforms-input", { hasText: "Event Title:" }).locator("input").first();
    const eventDateInput = page.locator("#xForm .xforms-input", { hasText: "Event Date:" }).locator("input[type='date']").first();
    const eventTimeInput = page.locator("#xForm .xforms-input", { hasText: "Event Time:" }).locator("input[type='time']").first();

    await seedBookingInstance(page);
    await eventDateInput.fill("2026-12-31");
    await eventTimeInput.fill("12:34");
    await expect(await getInstanceFieldValue(page, "EventDate")).toBe("2026-12-31");
    await expect(await getInstanceFieldValue(page, "EventTime")).toBe("12:34:00");
    // TEST-TRACE: reset counters after setup fills so assertions capture blur transitions only during partial segment editing; helps tests/examples/booking-form-blur.spec.ts booking form date/time regression.
    await installBlurCounter(eventDateInput);
    await installBlurCounter(eventTimeInput);

    await eventDateInput.click();
    await eventDateInput.press("ControlOrMeta+A");
    await eventDateInput.pressSequentially("12");
    await expectActiveElement(page, eventDateInput);
    // TEST-TRACE: verify date control blur is deferred until focus leaves field, not between native segments; helps tests/examples/booking-form-blur.spec.ts booking form date regression.
    await expect(await getBlurCount(eventDateInput)).toBe(0);
    // TEST-TRACE: partial date editing must not clear persisted model value before exiting the control; helps tests/examples/booking-form-blur.spec.ts booking form date regression.
    await expect(await getInstanceFieldValue(page, "EventDate")).toBe("2026-12-31");
    // TEST-TRACE: reset time blur counter after date-phase focus transition so time assertions only
    // measure internal-segment behavior within the time control; helps tests/examples/booking-form-blur.spec.ts booking form time regression.
    await installBlurCounter(eventTimeInput);

    await eventTimeInput.click();
    await eventTimeInput.press("ControlOrMeta+A");
    await eventTimeInput.pressSequentially("12");
    await expectActiveElement(page, eventTimeInput);
    // TEST-TRACE: verify time control blur is deferred until focus leaves field, not between native segments; helps tests/examples/booking-form-blur.spec.ts booking form time regression.
    await expect(await getBlurCount(eventTimeInput)).toBe(0);
    // TEST-TRACE: partial time editing must not clear persisted model value before exiting the control; helps tests/examples/booking-form-blur.spec.ts booking form time regression.
    await expect(await getInstanceFieldValue(page, "EventTime")).toBe("12:34:00");

    await titleInput.click();
    await expect(await getBlurCount(eventDateInput)).toBe(1);
    await expect(await getBlurCount(eventTimeInput)).toBe(1);
  });

  test("date value persists when submitting booking", async ({ page }) => {
    await page.goto(`${examplesServer.baseUrl}/sample1.html`);
    await expect(page.locator("#xForm .xforms-input").first()).toBeVisible({ timeout: renderTimeoutMs });

    const eventDateInput = page.locator("#xForm .xforms-input", { hasText: "Event Date:" }).locator("input[type='date']").first();
    const submitButton = page.locator("#xForm button", { hasText: "Submit Booking" }).first();

    await seedBookingInstance(page);
    await eventDateInput.fill("2027-01-15");
    await submitButton.click();

    await expect.poll(async () => getInstanceFieldValue(page, "EventDate")).toBe("2027-01-15");
    await expect.poll(async () => getInstanceFieldValue(page, "EventTime")).toBe("12:34:00");
  });
});
