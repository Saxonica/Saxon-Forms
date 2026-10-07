import { test, expect } from "../fixtures/echo-intercept";

const RENDER_TIMEOUT = 20_000;
type ProviderConfig = {
  name: string;
  pagePath: string;
  changeEvent: string;
  exposesHostValue: boolean;
};

const providers: ProviderConfig[] = [
  {
    name: "shoelace",
    pagePath: "/test-web-components-shoelace.html",
    changeEvent: "sl-change",
    exposesHostValue: true,
  },
  {
    name: "tinymce",
    pagePath: "/test-web-components-tinymce.html",
    changeEvent: "Change",
    exposesHostValue: false,
  },
];

function componentSelector(provider: ProviderConfig, idPrefix: string) {
  const byPrefixSelector = `[id^='${idPrefix}']`;
  // TEST-TRACE: scope TinyMCE selectors to host custom elements so Playwright shadow-DOM piercing does not match TinyMCE internals; helps tests/supplemental/web-components.spec.ts "Web components integration (tinymce)".
  if (provider.name === "tinymce") {
    return `tinymce-editor${byPrefixSelector}`;
  }
  return byPrefixSelector;
}
async function assertProviderRuntime(page: any, provider: ProviderConfig) {
  if (provider.name !== "tinymce") {
    return;
  }
  // TEST-TRACE: assert local TinyMCE runtime exposes init() so missing/offline asset regressions fail immediately; helps tests/supplemental/web-components.spec.ts "Web components integration (tinymce)".
  await expect
    .poll(async () => page.evaluate(() => typeof (window as any).tinymce?.init))
    .toBe("function");
  // TEST-TRACE: assert local webcomponent script registers tinymce-editor so CDN fallback regressions cannot pass silently; helps tests/supplemental/web-components.spec.ts "Web components integration (tinymce)".
  await expect
    .poll(async () => page.evaluate(() => typeof customElements.get("tinymce-editor")))
    .toBe("function");
  // TEST-TRACE: wait until tinymce-editor hosts expose non-null values so interaction tests do not race TinyMCE async init; helps tests/supplemental/web-components.spec.ts "view to model updates work for custom and native events".
  await expect
    .poll(async () =>
      page.evaluate(() => {
        const hosts = Array.from(
          document.querySelectorAll("tinymce-editor[data-xf-component='true']")
        ) as any[];
        return hosts.length > 0 && hosts.every((host) => host.value !== null);
      })
    )
    .toBe(true);
}

async function waitForWebComponentsForm(page: any, provider: ProviderConfig) {
  await page.goto(provider.pagePath);
  await assertProviderRuntime(page, provider);
  await expect(page.locator("#wc-root")).toBeVisible({ timeout: RENDER_TIMEOUT });
  await expect(page.locator("[data-xf-component]")).toHaveCount(8, { timeout: RENDER_TIMEOUT });
}

async function setComponentValueAndDispatch(
  page: any,
  selector: string,
  value: string,
  eventName: string
) {
  await page.evaluate(
    ({ cssSelector, nextValue, evt }) => {
      const el = document.querySelector(cssSelector) as any;
      if (!el) {
        throw new Error(`Component not found: ${cssSelector}`);
      }
      el.value = nextValue;
      if (evt === "change" || evt === "input") {
        el.dispatchEvent(new Event(evt, { bubbles: true, composed: true }));
      } else {
        el.dispatchEvent(new CustomEvent(evt, { bubbles: true, composed: true, detail: { value: nextValue } }));
      }
    },
    { cssSelector: selector, nextValue: value, evt: eventName }
  );
}

async function getComponentValues(page: any, provider: ProviderConfig) {
  const projectSelector = componentSelector(provider, "project-name-");
  const ownerSelector = componentSelector(provider, "owner-email-");
  const releaseSelector = componentSelector(provider, "release-notes-");
  return page.evaluate(
    ({ projectCssSelector, ownerCssSelector, releaseCssSelector }) => ({
      projectName: (document.querySelector(projectCssSelector) as any)?.value ?? "",
      ownerEmail: (document.querySelector(ownerCssSelector) as any)?.value ?? "",
      releaseNotes: (document.querySelector(releaseCssSelector) as any)?.value ?? "",
    }),
    {
      projectCssSelector: projectSelector,
      ownerCssSelector: ownerSelector,
      releaseCssSelector: releaseSelector,
    }
  );
} 

async function getTinymceEditable(page: any, idPrefix: string) {
  const host = page.locator(`tinymce-editor[id^='${idPrefix}']`);
  const iframe = host.locator('iframe').first();
  await iframe.waitFor({ state: 'attached', timeout: RENDER_TIMEOUT });
  const frame = iframe.contentFrame();
  if (!frame) throw new Error('TinyMCE iframe has no content frame');

  // TEST-TRACE: wait for the editor iframe body to become truly editable (contenteditable=true, no readonly class).
  // This guards against GPL init without license_key (which can leave the body readonly) and async TinyMCE init timing.
  // Helps tests/supplemental/web-components.spec.ts "Web components integration (tinymce)" real-interaction tests.
  const body = frame.locator('body').first();
  await body.waitFor({ state: 'attached', timeout: RENDER_TIMEOUT });

  // Poll until editable and not readonly. Use a generous timeout so slow CI boots still pass.
  await expect
    .poll(
      async () => {
        const ce = await body.getAttribute('contenteditable');
        const cls = (await body.getAttribute('class')) || '';
        const isEditable = ce === 'true';
        const notReadonly = !/\bmce-content-readonly\b/.test(cls);
        return isEditable && notReadonly ? 'ready' : `ce=${ce} clsHasReadonly=${/\bmce-content-readonly\b/.test(cls)}`;
      },
      { timeout: RENDER_TIMEOUT, message: 'TinyMCE editable body did not become contenteditable=true without mce-content-readonly' }
    )
    .toBe('ready');

  const editableBody = frame.locator('body[contenteditable="true"], body.mce-content-body:not(.mce-content-readonly)').first();
  await editableBody.waitFor({ state: 'visible', timeout: RENDER_TIMEOUT });
  return { host, iframe, frame, body: editableBody };
}

providers.forEach((provider) => {
  test.describe(`Web components integration (${provider.name})`, () => {
    test("hydrates model values into rendered components", async ({ page }) => {
      await waitForWebComponentsForm(page, provider);

      await expect(page.locator("#out-project-name")).toContainText("Acme Migration");
      await expect(page.locator("#out-owner-email")).toContainText("owner@example.test");
      await expect(page.locator("#out-release-notes")).toContainText("Initial draft notes");

      await expect(page.locator(componentSelector(provider, "project-name-"))).toHaveAttribute("data-xf-component", "true");
      await expect(page.locator(componentSelector(provider, "owner-email-"))).toHaveAttribute("data-xf-component", "true");
      await expect(page.locator(componentSelector(provider, "release-notes-"))).toHaveAttribute("data-xf-component", "true");
      if (provider.exposesHostValue) {
        await expect
          .poll(async () => getComponentValues(page, provider))
          .toMatchObject({
            projectName: expect.stringContaining("Acme Migration"),
            ownerEmail: expect.stringContaining("owner@example.test"),
            releaseNotes: expect.stringContaining("Initial draft notes"),
          });
      }
    });

    test("view to model updates work for custom and native events", async ({ page }) => {
      await waitForWebComponentsForm(page, provider);

      await setComponentValueAndDispatch(
        page,
        componentSelector(provider, "project-name-"),
        "project-ui-update",
        provider.changeEvent
      );
      await setComponentValueAndDispatch(
        page,
        componentSelector(provider, "owner-email-"),
        "owner-ui-update@example.test",
        provider.changeEvent
      );
      await setComponentValueAndDispatch(
        page,
        componentSelector(provider, "release-notes-"),
        "release notes ui update",
        provider.changeEvent
      );

      await expect(page.locator("#out-project-name")).toContainText("project-ui-update");
      await expect(page.locator("#out-owner-email")).toContainText("owner-ui-update@example.test");
      await expect(page.locator("#out-release-notes")).toContainText("release notes ui update");
    });

    test("model refresh updates component values and repeat rows stay isolated", async ({ page }) => {
      await waitForWebComponentsForm(page, provider);

      await page.locator("button[data-action*='set-main-values']").click();
      await expect(page.locator("#out-project-name")).toContainText("Acme Migration v2");
      await expect(page.locator("#out-owner-email")).toContainText("release.manager@example.test");
      await expect(page.locator("#out-release-notes")).toContainText("Release approved for staging deploy.");
      if (provider.exposesHostValue) {
        await expect
          .poll(async () => getComponentValues(page, provider))
          .toMatchObject({
            projectName: expect.stringContaining("Acme Migration v2"),
            ownerEmail: expect.stringContaining("release.manager@example.test"),
            releaseNotes: expect.stringContaining("Release approved for staging deploy."),
          });
      }
      const repeatInputs = page.locator(componentSelector(provider, "repeat-sl-"));
      await expect(repeatInputs).toHaveCount(2);

      await setComponentValueAndDispatch(
        page,
        componentSelector(provider, "repeat-sl-"),
        "repeat-a-ui-update",
        provider.changeEvent
      );
      const repeatOutputs = page.locator("[id^='repeat-name-out-']");
      await expect(repeatOutputs.nth(0)).toContainText("repeat-a-ui-update");
      await expect(repeatOutputs.nth(1)).toContainText("Run load tests");

      await page.locator("button[data-action*='set-repeat-second']").click();
      await expect(repeatOutputs.nth(1)).toContainText("repeat-b-model-update");
      if (provider.exposesHostValue) {
        const repeatSelector = componentSelector(provider, "repeat-sl-");
        await expect
          .poll(async () => {
            return page.evaluate((cssSelector) => {
              const rows = Array.from(document.querySelectorAll(cssSelector)) as any[];
              return rows.map((row) => row?.value ?? "");
            }, repeatSelector);
          })
          .toMatchObject([
            expect.stringContaining("repeat-a-ui-update"),
            expect.stringContaining("repeat-b-model-update"),
          ]);
      }
    });

    test("miswired event does not mutate model and no runtime page errors are raised", async ({ page }) => {
      const pageErrors: string[] = [];
      page.on("pageerror", (error) => {
        pageErrors.push(error.message);
      });

      await waitForWebComponentsForm(page, provider);

      await setComponentValueAndDispatch(
        page,
        componentSelector(provider, "sl-miswired-"),
        "should-not-persist",
        provider.changeEvent
      );
      await expect(page.locator("#out-miswired")).toContainText("keep-original");
      // TEST-TRACE: reject all runtime page errors so malformed script responses are no longer masked in TinyMCE coverage; helps tests/supplemental/web-components.spec.ts "miswired event does not mutate model and no runtime page errors are raised".
      expect(pageErrors).toEqual([]);
    });

    test("renders one web component per xf:repeat item", async ({ page }) => {
      await waitForWebComponentsForm(page, provider);

      const repeatRows = page.locator("#wc-repeat > [data-repeat-item='true']");
      await expect(repeatRows).toHaveCount(2);

      const repeatComponents = page.locator(componentSelector(provider, "repeat-sl-"));
      await expect(repeatComponents).toHaveCount(2);

      const componentIds = await repeatComponents.evaluateAll((els) =>
        els.map((el) => (el as HTMLElement).id)
      );
      expect(new Set(componentIds).size).toBe(2);
    });

    test("renders components in toggle cases and switches visibility on toggle", async ({ page }) => {
      await waitForWebComponentsForm(page, provider);

      const summaryComponent = page.locator(componentSelector(provider, "toggle-summary-"));
      const advancedComponent = page.locator(componentSelector(provider, "toggle-advanced-"));

      await expect(summaryComponent).toHaveCount(1);
      await expect(advancedComponent).toHaveCount(1);
      await expect(summaryComponent).toBeVisible();
      await expect(advancedComponent).toBeHidden();

      // TEST-TRACE: invoke trigger clicks in page context because TinyMCE host overlays can block pointer-based Playwright clicks during switch transitions; helps tests/supplemental/web-components.spec.ts "renders components in toggle cases and switches visibility on toggle".
      await page.evaluate(() => {
        const button = document.querySelector("button[data-action*='show-advanced-mode']") as HTMLButtonElement | null;
        if (!button) {
          throw new Error("Missing show-advanced-mode trigger");
        }
        button.click();
      });
      await expect(advancedComponent).toBeVisible();
      await expect(summaryComponent).toBeHidden();
      await page.evaluate(() => {
        const button = document.querySelector("button[data-action*='show-summary-mode']") as HTMLButtonElement | null;
        if (!button) {
          throw new Error("Missing show-summary-mode trigger");
        }
        button.click();
      });
      await expect(summaryComponent).toBeVisible();
      await expect(advancedComponent).toBeHidden();
    });

    test('TinyMCE editor boots with local GPL assets and exposes editable iframe', async ({ page }) => {
      test.skip(provider.name !== 'tinymce', 'TinyMCE-specific editor surface test');
      await waitForWebComponentsForm(page, provider);

      // Reach the real contenteditable inside the component's iframe (local self-hosted TinyMCE, no cloud).
      const { iframe, body } = await getTinymceEditable(page, 'project-name-');

      await expect(iframe).toBeVisible();
      await expect(body).toHaveAttribute('contenteditable', 'true');

      // Sanity: the editor should not be in a loading/broken state.
      await expect(body).not.toBeEmpty();
    });

    test('typing inside TinyMCE updates the XForm model (real editor, GPL self-hosted)', async ({ page }) => {
      test.skip(provider.name !== 'tinymce', 'TinyMCE-specific editor interaction');

      const pageErrors: string[] = [];
      const consoleMessages: string[] = [];
      page.on('pageerror', (e) => pageErrors.push(e.message));
      page.on('console', (msg) => {
        const text = msg.text();
        if (/tinymce|license|cloud|api key|premium/i.test(text)) {
          consoleMessages.push(`${msg.type()}: ${text}`);
        }
      });

      await waitForWebComponentsForm(page, provider);

      const editable = await getTinymceEditable(page, 'project-name-');
      const { body } = editable;

      // Clear existing content inside the real editor.
      await body.click();
      await body.press('ControlOrMeta+A');
      await body.press('Delete');

      // Type real content. TinyMCE will wrap paragraphs.
      await body.type('Hello from real TinyMCE');

      // Blur to encourage change notification.
      await body.press('Tab');

      // The XForm bridge should propagate via the custom Change event to the model output.
      await expect(page.locator('#out-project-name')).toContainText('Hello from real TinyMCE', { timeout: 10_000 });

      // No TinyMCE license/cloud errors should have been emitted.
      const licenseRelated = [
        ...pageErrors.filter((m) => /tinymce|license|cloud|api key|premium/i.test(m)),
        ...consoleMessages,
      ];
      expect(licenseRelated).toEqual([]);
    });
  });
});
