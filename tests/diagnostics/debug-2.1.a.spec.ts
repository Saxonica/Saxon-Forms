import { test, expect } from "../fixtures/echo-intercept";

/**
 * Diagnostic test for EVENTS.md — verifies the SaxonJS event-handling
 * pipeline for ixsl:onchange.
 *
 * See EVENTS.md § "Key Diagnostic Evidence" for context.
 */

const RENDER_TIMEOUT = 15_000;

test("diag: SaxonJS registers document-level listeners for change, click, keyup", async ({ page }) => {
  await page.goto("/w3c-runner.html?test=Chapt02/2.1.a.xhtml");
  await expect(page.locator("#xForm")).not.toBeEmpty({ timeout: RENDER_TIMEOUT });
  await page.waitForTimeout(1000);

  const client = await page.context().newCDPSession(page);
  await client.send("Debugger.enable");
  const doc = await client.send("DOM.getDocument");
  const docObj = await client.send("DOM.resolveNode", { nodeId: doc.root.nodeId });
  const docListeners = await client.send("DOMDebugger.getEventListeners", {
    objectId: docObj.object.objectId!,
  });

  // Resolve each listener's script URL so we can attribute it to SaxonJS
  const listenerDetails: { type: string; scriptUrl: string }[] = [];
  for (const l of docListeners.listeners as any[]) {
    let scriptUrl = "(unknown)";
    if (l.scriptId) {
      try {
        const src = await client.send("Debugger.getScriptSource", { scriptId: l.scriptId });
        // Use first 200 chars to identify the script without dumping the whole thing
        const snippet = (src.scriptSource || "").substring(0, 200);
        scriptUrl = snippet.includes("SaxonJS") ? "SaxonJS runtime"
          : snippet.includes("xforms-cache") || snippet.includes("getInstance") ? "saxon-forms JS library"
            : l.scriptId;
      } catch {
        scriptUrl = l.scriptId;
      }
    }
    listenerDetails.push({ type: l.type, scriptUrl });
  }

  console.log("Document event listeners:", JSON.stringify(listenerDetails, null, 2));

  // Filter to listeners that come from the SaxonJS runtime
  const saxonListeners = listenerDetails.filter((d) => d.scriptUrl === "SaxonJS runtime");
  const saxonTypes = saxonListeners.map((d) => d.type);

  expect(saxonTypes, "SaxonJS runtime must own a 'change' listener").toContain("change");
  expect(saxonTypes, "SaxonJS runtime must own a 'click' listener").toContain("click");
  expect(saxonTypes, "SaxonJS runtime must own a 'keyup' listener").toContain("keyup");
});

test("diag: change event reaches document but ixsl:onchange template never fires", async ({ page }) => {
  const consoleLogs: string[] = [];
  page.on("console", (msg) => consoleLogs.push(`[${msg.type()}] ${msg.text()}`));

  await page.goto("/w3c-runner.html?test=Chapt02/2.1.a.xhtml");
  await expect(page.locator("#xForm")).not.toBeEmpty({ timeout: RENDER_TIMEOUT });
  await page.waitForTimeout(1000);

  // Install trace listeners and error catchers
  await page.evaluate(() => {
    document.addEventListener("change", (e) => {
      const t = e.target as HTMLElement;
      console.log("[TRACE] change reached document — target: " + t?.tagName + "." + t?.className);
    }, true);

    const sel = document.querySelector("select");
    if (sel) {
      sel.addEventListener("change", (e) => {
        console.log("[TRACE] change on select — value: " + (e.target as HTMLSelectElement).value);
      });
    }

    window.onerror = (msg, src, line, col, err) => {
      console.log("[ERROR] " + msg + " " + (err?.message || ""));
    };
    window.addEventListener("unhandledrejection", (e) => {
      console.log("[UNHANDLED] " + e.reason);
    });
  });

  // Instance before
  const xmlBefore = await page.evaluate(() => {
    const g = window as any;
    const key = g.getInstanceKeys?.()[0];
    const inst = key ? g.getInstance(key) : null;
    return inst ? new XMLSerializer().serializeToString(inst) : "NO INSTANCE";
  });

  // Dispatch change via Playwright
  await page.locator("select").first().selectOption("cash");
  await page.waitForTimeout(1000);

  // Also dispatch manually from JS to rule out Playwright dispatch issues
  await page.evaluate(() => {
    const sel = document.querySelector("select");
    if (sel) {
      sel.value = "cash";
      sel.dispatchEvent(new Event("change", { bubbles: true }));
    }
  });
  await page.waitForTimeout(1000);

  // Instance after
  const xmlAfter = await page.evaluate(() => {
    const g = window as any;
    const key = g.getInstanceKeys?.()[0];
    const inst = key ? g.getInstance(key) : null;
    return inst ? new XMLSerializer().serializeToString(inst) : "NO INSTANCE";
  });

  // --- Assertions ---

  // The change event must reach the document (proves the DOM event fires)
  const traceHits = consoleLogs.filter((l) => l.includes("[TRACE] change reached document"));
  expect(traceHits.length, "change event must reach the document listener").toBeGreaterThan(0);

  // No JS errors should be thrown
  const errors = consoleLogs.filter((l) => l.includes("[ERROR]") || l.includes("[UNHANDLED]"));
  expect(errors, "no silent JS errors during change dispatch").toEqual([]);

  // This is the actual bug: instance data should have changed but didn't
  expect(xmlBefore).toContain("<method>cc</method>");
  expect(xmlAfter, "ixsl:onchange should update instance — see EVENTS.md").toContain("<method>cash</method>");
});
