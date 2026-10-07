import { test, expect } from "../fixtures/echo-intercept";

test("runtime diagnostics for Issue #31 trigger action", async ({ page }) => {
  const consoleLogs: string[] = [];
  const pageErrors: string[] = [];
  page.on("console", (msg) => consoleLogs.push(msg.text()));
  page.on("pageerror", (err) => pageErrors.push(err.message));
  await page.goto("/issues.html");
  await expect(page.locator("#issues-root")).toBeVisible();

  const button = page.locator("button[data-action*='trigger-31-insert']");
  await expect(button).toBeVisible();
  const actionId = (await button.getAttribute("data-action")) ?? "";

  const before = await page.evaluate((id: string) => {
    const w = window as any;
    const inst = w.getInstance?.("i31");
    const xml = inst ? new XMLSerializer().serializeToString(inst) : "";
    const actionsRaw = w.getAction?.(id) ?? null;
    const asArray = Array.isArray(actionsRaw) ? actionsRaw : actionsRaw ? [actionsRaw] : [];
    const summarize = (action: any) => {
      const nestedRaw = action?.["nested-actions"];
      const nested = Array.isArray(nestedRaw) ? nestedRaw : nestedRaw ? [nestedRaw] : [];
      return {
        keys: action ? Object.keys(action) : [],
        name: action?.name ?? null,
        event: action?.["@event"] ?? null,
        handlerStatus: action?.["handler-status"] ?? null,
        nestedCount: nested.length,
        nested: nested.map((n: any) => ({
          name: n?.name ?? null,
          event: n?.["@event"] ?? null,
          handlerStatus: n?.["handler-status"] ?? null,
        })),
      };
    };
    const flags = w.getDeferredUpdateFlags?.() ?? null;
    return {
      actionId: id,
      actionType: actionsRaw === null ? "null" : Array.isArray(actionsRaw) ? "array" : typeof actionsRaw,
      actions: asArray.map(summarize),
      flags,
      entryCount: (xml.match(/<entry/g) || []).length,
    };
  }, actionId);
  console.log("DIAG_BEFORE_31", JSON.stringify(before));
  const outputRegistry = await page.evaluate(() => {
    const w = window as any;
    const keysRaw = w.getOutputKeys?.() ?? [];
    const keys = Array.isArray(keysRaw) ? keysRaw : [keysRaw];
    const extractMapEntry = (candidate: any, key: string) => {
      try {
        if (candidate && typeof candidate.get === "function") {
          return candidate.get(key);
        }
      } catch {
        // ignore
      }
      try {
        return candidate?.[key];
      } catch {
        return undefined;
      }
    };
    return keys.slice(0, 20).map((k: any) => {
      const o = w.getOutput?.(k);
      const core = o?.value ?? o;
      const keyString = String(k);
      const domEl = document.getElementById(keyString);
      const addClasses = extractMapEntry(core, "@additional-class-values");
      const atValueDirect = extractMapEntry(o, "@value");
      const atRefDirect = extractMapEntry(o, "@ref");
      const atValueCore = extractMapEntry(core, "@value");
      const atRefCore = extractMapEntry(core, "@ref");
      const safeGet = (candidate: any, key: string) => {
        try {
          if (candidate && typeof candidate.get === "function") {
            const v = candidate.get(key);
            return v == null ? null : String(v);
          }
        } catch (e: any) {
          return `ERR:${String(e?.message ?? e)}`;
        }
        return null;
      };
      return {
        key: keyString,
        outputKeys: o ? Object.keys(o) : [],
        hasValueWrapper: !!(o && "value" in o),
        coreKeys: core ? Object.keys(core) : [],
        topGetType: typeof o?.get,
        coreGetType: typeof core?.get,
        atValueByTopGet: safeGet(o, "@value"),
        atRefByTopGet: safeGet(o, "@ref"),
        atValueByCoreGet: safeGet(core, "@value"),
        atRefByCoreGet: safeGet(core, "@ref"),
        atCtxByCoreGet: safeGet(core, "@context-nodeset"),
        atInstByCoreGet: safeGet(core, "@instance-context"),
        atValueType: typeof atValueDirect,
        atRefType: typeof atRefDirect,
        atContextType: typeof extractMapEntry(o, "@context-nodeset"),
        atInstanceType: typeof extractMapEntry(o, "@instance-context"),
        atValueCoreType: typeof atValueCore,
        atRefCoreType: typeof atRefCore,
        atValueCoreString: atValueCore == null ? null : String(atValueCore),
        atRefCoreString: atRefCore == null ? null : String(atRefCore),
        domDataValue: domEl?.getAttribute("data-value") ?? null,
        domDataRef: domEl?.getAttribute("data-ref") ?? null,
        domInstanceContext: domEl?.getAttribute("instance-context") ?? null,
        domText: (domEl?.textContent ?? "").replace(/\s+/g, " ").trim(),
        addClassesType: typeof addClasses,
        addClassesIsArray: Array.isArray(addClasses),
        addClassesLength: Array.isArray(addClasses) ? addClasses.length : null,
      };
    });
  });
  console.log("DIAG_OUTPUT_REGISTRY_31", JSON.stringify(outputRegistry));

  await button.click();

  const after = await page.evaluate((id: string) => {
    const w = window as any;
    const inst = w.getInstance?.("i31");
    const xml = inst ? new XMLSerializer().serializeToString(inst) : "";
    const flags = w.getDeferredUpdateFlags?.() ?? null;
    const out = document.querySelector("#out-31-count")?.textContent ?? "";
    const outWrapper = document.querySelector("#out-31-count");
    const outInner = outWrapper?.querySelector("span[id]");
    const outInnerId = outInner?.getAttribute("id") ?? null;
    const outKeysRaw = w.getOutputKeys?.() ?? [];
    const outKeys = Array.isArray(outKeysRaw) ? outKeysRaw.map((k: any) => String(k)) : [String(outKeysRaw)];
    const outEntry =
      outInnerId && typeof w.getOutput === "function" ? w.getOutput(outInnerId as string) : null;
    return {
      actionId: id,
      flags,
      entryCount: (xml.match(/<entry/g) || []).length,
      outText: out.replace(/\s+/g, " ").trim(),
      outWrapperHtml: outWrapper?.innerHTML ?? null,
      outInnerId,
      outInnerDataValue: outInner?.getAttribute("data-value") ?? null,
      outInnerDataRef: outInner?.getAttribute("data-ref") ?? null,
      outInnerInstanceContext: outInner?.getAttribute("instance-context") ?? null,
      outInnerText: (outInner?.textContent ?? "").replace(/\s+/g, " ").trim(),
      outputRegistryCount: outKeys.length,
      outputRegistryHasOutInner: outInnerId ? outKeys.includes(outInnerId) : false,
      outputEntryType: outEntry === null ? "null" : Array.isArray(outEntry) ? "array" : typeof outEntry,
      outputEntryKeys: outEntry ? Object.keys(outEntry) : [],
    };
  }, actionId);
  console.log("DIAG_AFTER_31", JSON.stringify(after));
  console.log("DIAG_PAGEERROR_31", JSON.stringify(pageErrors));
});
