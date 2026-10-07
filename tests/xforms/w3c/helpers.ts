import {
  test as base,
  expect,
  type Dialog,
  type Locator,
  type Page,
  type Request,
  type Route,
} from "@playwright/test";
import { installDeterministicNetworkRoutes } from "../../fixtures/network-routes";
import type { DispatchedEventRecord, RequestPredicate, SaxonFormsWindow } from "../../types";

/**
 * Shared test fixture that intercepts echo.sh requests, plus helper
 * functions used by all per-chapter W3C XForms 1.1 test specs.
 */


export const test = base.extend<{}>({
  page: async ({ page }, use) => {
    await installDeterministicNetworkRoutes(page);
    await use(page);
  },
});

export { expect };
export { evaluateSubmissionXPath } from "../../helpers";

export const RENDER_TIMEOUT = 15_000;

export async function loadTest(page: Page, file: string) {
  await page.goto(`/w3c-runner.html?test=${file}`);
  await expect(page.locator("#xForm")).not.toBeEmpty({ timeout: RENDER_TIMEOUT });
}

export async function loadAndWait(page: Page, file: string) {
  await page.goto(`/w3c-runner.html?test=${file}`);
  await expect(page.locator("#xForm")).not.toBeEmpty({ timeout: RENDER_TIMEOUT });
  await page.waitForTimeout(1000);
}

export function getRenderedText(page: Page): Promise<string> {
  return page.locator("#xForm").innerText();
}

/**
 * Like getRenderedText but strips the W3C title and instruction labels
 * so that assertions don't accidentally match the pass-criteria text.
 */
export async function getFormControlText(page: Page): Promise<string> {
  return page.evaluate(() => {
    const el = document.querySelector("#xForm");
    if (!el) return "";
    const clone = el.cloneNode(true) as HTMLElement;
    // Remove the title group (contains <label class="title">)
    clone.querySelector(".xforms-group:has(label.title)")?.remove();
    // Remove the first remaining instruction-only group
    // (a group whose only content is a <label> with no form controls)
    for (const g of clone.querySelectorAll(":scope > .xforms-group")) {
      if (!g.querySelector("input, select, button, textarea, .xforms-output, .xforms-input, .xforms-select, .xforms-repeat")) {
        g.remove();
        break;
      }
    }
    return clone.innerText;
  });
}

export async function getInstanceXML(page: Page, instanceId?: string): Promise<string> {
  return page.evaluate((id: string | undefined) => {
    const g = window as unknown as SaxonFormsWindow;
    const key = id || g.getInstanceKeys?.()[0];
    const inst = key ? g.getInstance?.(key) : null;
    if (!inst) return "";
    return new XMLSerializer().serializeToString(inst);
  }, instanceId);
}

export async function clickAndCaptureRequest(
  page: Page,
  trigger: Locator,
  requestPredicate: RequestPredicate,
  timeout = 2000
): Promise<Request | null> {
  const requestPromise = page.waitForRequest(
    (req) => requestPredicate(req),
    { timeout }
  ).catch(() => null);
  await trigger.click();
  return requestPromise;
}

export async function submitAndCapture(page: Page, submitButton: Locator, timeout = 2000): Promise<Request | null> {
  return clickAndCaptureRequest(
    page,
    submitButton,
    (req) => /\/echo\.sh(?:\?|$)/i.test(req.url()),
    timeout
  );
}

export async function forceOneShotEndpointFailure(
  page: Page,
  endpointMatcher: string | RegExp,
  options?: {
    status?: number;
    contentType?: string;
    body?: string;
    headers?: Record<string, string>;
  }
) {
  const status = options?.status ?? 500;
  const contentType = options?.contentType ?? "application/xml";
  const body = options?.body ?? "<?xml version=\"1.0\"?><error>forced failure</error>";
  const headers = options?.headers;
  const handler = async (route: Route) => {
    await route.fulfill({
      status,
      contentType,
      body,
      headers,
    });
    await page.unroute(endpointMatcher, handler);
  };
  await page.route(endpointMatcher, handler);
}

export async function clearDispatchedEvents(page: Page) {
  await page.evaluate(() => {
    const g = window as unknown as SaxonFormsWindow;
    if (typeof g.clearDispatchedEvents === "function") {
      g.clearDispatchedEvents();
    }
  });
}

export async function getDispatchedEvents(
  page: Page
): Promise<DispatchedEventRecord[]> {
  return page.evaluate(() => {
    const g = window as unknown as SaxonFormsWindow;
    const events = typeof g.getDispatchedEvents === "function" ? g.getDispatchedEvents() : [];
    if (!Array.isArray(events)) return [];
    return events.map((eventRecord): DispatchedEventRecord => {
      const record = eventRecord as { name?: unknown; context?: unknown };
      const rawContext = typeof record.context === "object" && record.context !== null
        ? record.context as Record<string, unknown>
        : {};
      return {
        name: String(record.name ?? ""),
        context: Object.fromEntries(
          Object.entries(rawContext).map(([key, value]) => [String(key), String(value)])
        ),
      };
    });
  });
}

export async function waitForCondition(
  page: Page,
  predicate: () => Promise<boolean> | boolean,
  options?: {
    timeoutMs?: number;
    intervalMs?: number;
    description?: string;
  }
) {
  const timeoutMs = options?.timeoutMs ?? 3_000;
  const intervalMs = options?.intervalMs ?? 100;
  const description = options?.description ?? "condition";
  const startedAt = Date.now();
  let attempts = 0;
  while ((Date.now() - startedAt) < timeoutMs) {
    attempts += 1;
    if (await predicate()) {
      return;
    }
    await page.waitForTimeout(intervalMs);
  }
  throw new Error(`Timed out after ${timeoutMs}ms waiting for ${description} (attempts: ${attempts}).`);
}

export async function isUnavailable(input: Locator): Promise<boolean> {
  const visible = await input.isVisible().catch(() => false);
  if (!visible) return true;
  const enabled = await input.isEnabled().catch(() => false);
  return !enabled;
}

export function normalizeWhitespace(value: string): string {
  return value.replace(/\s+/g, " ").trim();
}

export function collectDialogMessages(page: Page): string[] {
  const dialogMessages: string[] = [];
  page.on("dialog", async (dialog: Dialog) => {
    dialogMessages.push(normalizeWhitespace(dialog.message()));
    try {
      await dialog.dismiss();
    } catch {
      // ignore teardown race where dialog arrives after test end/page close
    }
  });
  return dialogMessages;
}

export async function getEventModelResults(page: Page): Promise<string[]> {
  return page.evaluate(() => {
    const g = window as unknown as SaxonFormsWindow;
    const raw = g.getModelDefaultInstanceKey?.("event_model");
    const instanceKey = Array.isArray(raw) ? raw[0] : raw;
    const instance = instanceKey ? g.getInstance?.(instanceKey) : null;
    if (!instance) return [];
    if (!(instance instanceof Document || instance instanceof Element)) return [];
    return Array.from(instance.getElementsByTagName("event")).map((node) =>
      String(node.textContent ?? "").replace(/\s+/g, " ").trim()
    );
  });
}

export function escapeRegex(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

export function expectDatatypeEvents(
  values: string[],
  eventName: "xforms-valid" | "XFORMS-INVALID",
  typeNames: string[]
) {
  const normalized = values.map(normalizeWhitespace);
  for (const typeName of typeNames) {
    const pattern = new RegExp(
      `${escapeRegex(eventName)}[^\\)]*\\(${escapeRegex(typeName)}\\)`,
      "i"
    );
    expect(normalized.some((value) => pattern.test(value))).toBe(true);
  }
}

export async function clickTrigger(page: Page, label: string) {
  await page.getByRole("button", { name: label, exact: true }).click();
  await page.waitForTimeout(300);
}

export async function expectDialogAfterTrigger(
  page: Page,
  dialogMessages: string[],
  triggerLabel: string,
  messagePattern: RegExp
) {
  const beforeCount = dialogMessages.length;
  await clickTrigger(page, triggerLabel);
  await waitForCondition(
    page,
    () => dialogMessages.slice(beforeCount).some((message) => messagePattern.test(message)),
    { description: `dialog matching ${messagePattern}` }
  );
}
