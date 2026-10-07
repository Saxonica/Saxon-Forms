import { test, expect } from "@playwright/test";

const target = process.env.DEBUG_W3C_TEST;

test(`debug W3C state: ${target ?? "<unset>"}`, async ({ page }) => {
  if (!target) {
    throw new Error(
      "DEBUG_W3C_TEST is required. Example: DEBUG_W3C_TEST=Appendix/B/B.3/b.3.a.xhtml"
    );
  }
  page.on("pageerror", (err) => {
    console.log(`[pageerror] ${err.message}`);
  });
  page.on("console", (msg) => {
    const text = msg.text();
    console.log(`[console:${msg.type()}] ${text}`);
  });
  await page.goto(`/w3c-runner.html?test=${target}`);
  let renderReady = true;
  try {
    await expect(page.locator("#xForm")).not.toBeEmpty({ timeout: 15000 });
  } catch {
    renderReady = false;
  }
  await page.waitForTimeout(1200);

  const payload = await page.evaluate(() => {
    const g = window as any;
    const unwrap = (value: any): any => {
      if (
        value &&
        typeof value === "object" &&
        Object.prototype.hasOwnProperty.call(value, "value") &&
        Object.keys(value).length === 1
      ) {
        return (value as any).value;
      }
      return value;
    };
    const getMapEntry = (container: any, key: string): any => {
      const source = unwrap(container);
      if (!source || typeof source !== "object") return undefined;
      if (
        typeof (source as any).get === "function" &&
        typeof (source as any).keys === "function"
      ) {
        try {
          const mapKeys = toArray((source as any).keys());
          for (const mapKey of mapKeys) {
            if (String(unwrap(mapKey)) === key) {
              return unwrap((source as any).get(mapKey));
            }
          }
        } catch {
          // ignore and fall through to direct property read
        }
      }
      return unwrap((source as any)[key]);
    };
    const getMapKeys = (container: any): string[] => {
      const source = unwrap(container);
      if (!source || typeof source !== "object") return [];
      if (
        typeof (source as any).keys === "function"
      ) {
        try {
          return toArray((source as any).keys()).map((item: any) => String(unwrap(item)));
        } catch {
          // ignore and fall back
        }
      }
      return Object.keys(source as any);
    };
    const toArray = (value: any): any[] => {
      const unwrapped = unwrap(value);
      if (Array.isArray(unwrapped)) return unwrapped;
      if (
        unwrapped &&
        typeof unwrapped !== "string" &&
        typeof (unwrapped as any)[Symbol.iterator] === "function"
      ) {
        return Array.from(unwrapped as any);
      }
      if (
        unwrapped &&
        typeof unwrapped === "object" &&
        typeof (unwrapped as any).get === "function" &&
        typeof (unwrapped as any).keys === "function"
      ) {
        return [unwrapped];
      }
      return [];
    };
    const flattenAction = (action: any, out: any[]) => {
      const name = getMapEntry(action, "name");
      if (!name) {
        const unpacked = toArray(action);
        for (const nested of unpacked) {
          if (nested !== action) {
            flattenAction(nested, out);
          }
        }
        return;
      }
      out.push({
        keys: getMapKeys(action),
        name,
        handlerStatus: getMapEntry(action, "handler-status"),
        event: getMapEntry(action, "@event"),
        observer: getMapEntry(action, "@observer"),
        defaultAction: getMapEntry(action, "@defaultAction"),
        targetid: getMapEntry(action, "@targetid"),
        ref: getMapEntry(action, "@ref"),
        refLocal: getMapEntry(action, "@ref-local"),
        context: getMapEntry(action, "@context"),
        origin: getMapEntry(action, "@origin"),
        at: getMapEntry(action, "@at"),
        position: getMapEntry(action, "@position")
      });
      const nestedActions = toArray(getMapEntry(action, "nested-actions"));
      for (const nested of nestedActions) {
        flattenAction(nested, out);
      }
    };
    const describeEventActions = (eventName: string): any[] => {
      const raw = g.getEventAction?.(eventName) || [];
      const seq = toArray(raw);
      return seq.map((action) => ({
        keys: getMapKeys(action),
        name: getMapEntry(action, "name"),
        handlerStatus: getMapEntry(action, "handler-status"),
        event: getMapEntry(action, "@event"),
        observer: getMapEntry(action, "@observer"),
        defaultAction: getMapEntry(action, "@defaultAction"),
        targetid: getMapEntry(action, "@targetid"),
        context: getMapEntry(action, "@context")
      }));
    };

    const keys = g.getInstanceKeys?.() || [];
    const defaultId = keys.find((k: string) => k === "saxon-forms-default-instance") || keys[0];
    const defaultInstance = defaultId ? g.getInstance?.(defaultId) : null;
    const xml = new XMLSerializer();
    const outputs = Array.from(document.querySelectorAll(".hlist")).map((el) =>
      (el.textContent || "").replace(/\s+/g, " ").trim()
    );
    const repeatKeys = g.getRepeatKeys?.() || [];
    const repeats = repeatKeys.map((k: string) => ({
      key: k,
      context: g.getRepeatContext?.(k),
      ref: g.getRepeatRef?.(k),
      instanceId: g.getRepeatInstanceId?.(k),
      size: g.getRepeatSize?.(k),
      index: g.getRepeatIndex?.(k)
    }));

    const readyActionsRaw = g.getEventAction?.("xforms-ready") || [];
    const readyActions = toArray(readyActionsRaw);
    const flatReadyActions: any[] = [];
    for (const action of readyActions) {
      flattenAction(action, flatReadyActions);
    }
    const modelActionsRaw = g.getAction?.("saxon-forms-default-model") || [];
    const modelActions = toArray(modelActionsRaw);
    const flatModelActions: any[] = [];
    for (const action of modelActions) {
      flattenAction(action, flatModelActions);
    }
    const controlActions = Array.from(document.querySelectorAll("select.xforms-select")).map((el) => {
      const dataAction = el.getAttribute("data-action") || "";
      const controlRaw = dataAction ? g.getAction?.(dataAction) || [] : [];
      const controlSeq = toArray(controlRaw);
      const flatControlActions: any[] = [];
      for (const action of controlSeq) {
        flattenAction(action, flatControlActions);
      }
      return {
        id: (el as HTMLSelectElement).id || "",
        dataAction,
        actionNames: flatControlActions.map((action) => String(action.name)),
        eventActions: flatControlActions
          .filter((action) => action.event)
          .map((action) => ({
            name: String(action.name),
            event: String(action.event)
          }))
      };
    });
    const readyNestedRaw = readyActions.length > 0 ? getMapEntry(readyActions[0], "nested-actions") : null;
    const modelNestedRaw = modelActions.length > 0 ? getMapEntry(modelActions[0], "nested-actions") : null;
    const readyNestedFirst = Array.isArray(readyNestedRaw) && readyNestedRaw.length > 0 ? readyNestedRaw[0] : null;
    const modelNestedFirst = Array.isArray(modelNestedRaw) && modelNestedRaw.length > 0 ? modelNestedRaw[0] : null;
    const deferredFlags = g.getDeferredUpdateFlags?.() ?? {};
    const dirtyBeforeManualClear = g.hasDirtyInstances?.();
    g.clearDirtyInstances?.();
    const dirtyAfterManualClear = g.hasDirtyInstances?.();
    const xformRoot = g.getXForm?.();
    const xformHeadChildren: Array<{ name: string; ns: string | null }> = [];
    const xformBodyChildren: Array<{ name: string; ns: string | null }> = [];
    if (xformRoot && typeof xformRoot === "object") {
      for (const child of Array.from((xformRoot as any).childNodes || [])) {
        if (child?.nodeType !== 1) continue;
        if (child.localName === "head") {
          for (const headChild of Array.from(child.childNodes || [])) {
            if (headChild?.nodeType === 1) {
              xformHeadChildren.push({ name: String(headChild.localName), ns: headChild.namespaceURI || null });
            }
          }
        }
        if (child.localName === "body") {
          for (const bodyChild of Array.from(child.childNodes || [])) {
            if (bodyChild?.nodeType === 1) {
              xformBodyChildren.push({ name: String(bodyChild.localName), ns: bodyChild.namespaceURI || null });
            }
          }
        }
      }
    }
    return {
      href: location.href,
      renderReady: ((document.querySelector("#xForm")?.textContent || "").trim().length > 0),
      keys,
      defaultId,
      defaultXML: defaultInstance ? xml.serializeToString(defaultInstance) : "",
      outputs,
      repeatItemsCount: document.querySelectorAll("[data-repeat-item='true']").length,
      repeats,
      hasDirtyInstances: g.hasDirtyInstances?.(),
      dirtyBeforeManualClear,
      dirtyAfterManualClear,
      deferredFlags,
      pendingAppendDefault: g.getPendingAppendForInstance?.(defaultId),
      readyActionCount: readyActions.length,
      readyActionFirstType:
        readyActions.length > 0 ? Object.prototype.toString.call(readyActions[0]) : "",
      readyActionFirstKeys:
        readyActions.length > 0 && readyActions[0] && typeof readyActions[0] === "object"
          ? Object.keys(readyActions[0])
          : [],
      readyNestedType: Object.prototype.toString.call(readyNestedRaw),
      readyNestedKeys:
        readyNestedRaw && typeof readyNestedRaw === "object"
          ? Object.keys(readyNestedRaw)
          : [],
      readyNestedProto:
        readyNestedRaw
          ? Object.getOwnPropertyNames(Object.getPrototypeOf(readyNestedRaw))
          : [],
      readyNestedFirstType: Object.prototype.toString.call(readyNestedFirst),
      readyNestedFirstKeys:
        readyNestedFirst && typeof readyNestedFirst === "object"
          ? Object.keys(readyNestedFirst)
          : [],
      readyNestedFirstKeyList:
        unwrap(readyNestedFirst) && typeof unwrap(readyNestedFirst).keys === "function"
          ? toArray(unwrap(readyNestedFirst).keys()).map((item: any) => String(unwrap(item)))
          : [],
      readyNestedFirstName: getMapEntry(readyNestedFirst, "name"),
      readyTopAction: flatReadyActions[0] ?? null,
      readyActionNames: flatReadyActions.map((action) => String(action.name)),
      readyMutatingActions: flatReadyActions.filter((action) => ["insert", "delete"].includes(String(action.name))),
      modelActionCount: modelActions.length,
      modelActionFirstType:
        modelActions.length > 0 ? Object.prototype.toString.call(modelActions[0]) : "",
      modelActionFirstKeys:
        modelActions.length > 0 && modelActions[0] && typeof modelActions[0] === "object"
          ? Object.keys(modelActions[0])
          : [],
      modelNestedType: Object.prototype.toString.call(modelNestedRaw),
      modelNestedKeys:
        modelNestedRaw && typeof modelNestedRaw === "object"
          ? Object.keys(modelNestedRaw)
          : [],
      modelNestedProto:
        modelNestedRaw
          ? Object.getOwnPropertyNames(Object.getPrototypeOf(modelNestedRaw))
          : [],
      modelNestedFirstType: Object.prototype.toString.call(modelNestedFirst),
      modelNestedFirstKeys:
        modelNestedFirst && typeof modelNestedFirst === "object"
          ? Object.keys(modelNestedFirst)
          : [],
      modelNestedFirstKeyList:
        unwrap(modelNestedFirst) && typeof unwrap(modelNestedFirst).keys === "function"
          ? toArray(unwrap(modelNestedFirst).keys()).map((item: any) => String(unwrap(item)))
          : [],
      modelNestedFirstName: getMapEntry(modelNestedFirst, "name"),
      modelTopAction: flatModelActions[0] ?? null,
      modelActionNames: flatModelActions.map((action) => String(action.name)),
      modelMutatingActions: flatModelActions.filter((action) => ["insert", "delete"].includes(String(action.name))),
      controlActions,
      globalActionKeys: Object.keys((window as any).actions || {}),
      globalEventActionKeys: Object.keys((window as any).eventActions || {}),
      customEventActions: describeEventActions("custom-event"),
      scrollFirstEventActions: describeEventActions("xforms-scroll-first"),
      scrollLastEventActions: describeEventActions("xforms-scroll-last"),
      selectEventActions: describeEventActions("xforms-select"),
      deselectEventActions: describeEventActions("xforms-deselect"),
      xformHeadChildren,
      xformBodyChildren
    };
  });

  console.log(JSON.stringify(payload, null, 2));
});
