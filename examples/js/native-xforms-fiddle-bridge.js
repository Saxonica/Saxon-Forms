(function () {
  const STYLESHEET_LOCATION = "../sef/saxon-xforms.sef.json";
  const SAXON_JS_RUNTIME_LOCATION = "../Saxon-JS/SaxonJS3.rt.js";
  const DEFAULT_NESTED_XFORMS_SOURCE = `<?xml version="1.0" encoding="UTF-8"?>
<xf:xform
    xmlns:xf="http://www.w3.org/2002/xforms"
    xmlns:ev="http://www.w3.org/2001/xml-events">
    <xf:model id="demo-model">
        <xf:instance id="demo-data">
            <data xmlns="">
                <name>World</name>
            </data>
        </xf:instance>
    </xf:model>
    <div class="native-fiddle-nested-form">
        <h2>Simple form</h2>
        <xf:input ref="instance('demo-data')/name" incremental="true">
            <xf:label>Name</xf:label>
        </xf:input>
        <p>Hello, <xf:output ref="instance('demo-data')/name"/></p>
    </div>
</xf:xform>`;

  function getConsoleElement() {
    return document.getElementById("native-fiddle-console");
  }

  function appendConsoleLine(level, message) {
    const consoleElement = getConsoleElement();
    if (!consoleElement) {
      return;
    }
    const safeLevel = level || "info";
    const text = `[${safeLevel}] ${message}`;
    const line = document.createElement("div");
    line.textContent = text;
    line.className = `native-fiddle-console-line native-fiddle-console-${safeLevel}`;
    consoleElement.appendChild(line);
    consoleElement.scrollTop = consoleElement.scrollHeight;
  }

  function clearConsole() {
    const consoleElement = getConsoleElement();
    if (!consoleElement) {
      return;
    }
    consoleElement.textContent = "";
  }

  function getSourceTextarea() {
    return document.querySelector("textarea[id^='native-fiddle-xforms-source']");
  }

  function getRenderTarget() {
    return document.getElementById("native-fiddle-render-target");
  }

  function parseXml(xmlText) {
    const parser = new DOMParser();
    const parsed = parser.parseFromString(xmlText, "application/xml");
    const parseError = parsed.querySelector("parsererror");
    if (parseError) {
      const details = (parseError.textContent || "Invalid XML")
        .replace(/\s+/g, " ")
        .trim();
      throw new Error(`Source is not well-formed XML: ${details}`);
    }
    return parsed;
  }

  function installFrameMessageListener() {
    if (window.__nativeXFormsFiddleMessageListenerInstalled) {
      return;
    }
    window.__nativeXFormsFiddleMessageListenerInstalled = true;
    window.addEventListener("message", (event) => {
      if (!event.data || typeof event.data !== "object") {
        return;
      }
      if (event.data.source !== "native-xforms-fiddle-frame") {
        return;
      }
      if (event.data.level === "error") {
        appendConsoleLine("error", event.data.message || "Nested render failed.");
        return;
      }
      appendConsoleLine("info", event.data.message || "Render complete.");
    });
  }

  function buildFrameMarkup(sourceText) {
    return `<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8" />
    <base href="${window.location.href}" />
    <script src="${SAXON_JS_RUNTIME_LOCATION}"></script>
  </head>
  <body>
    <div id="xForm"></div>
    <script>
      (function () {
        const sourceText = ${JSON.stringify(sourceText)};
        function post(level, message) {
          parent.postMessage({ source: "native-xforms-fiddle-frame", level: level, message: message }, "*");
        }
        function parseSource(text) {
          const parser = new DOMParser();
          const parsed = parser.parseFromString(text, "application/xml");
          const parseError = parsed.querySelector("parsererror");
          if (parseError) {
            throw new Error((parseError.textContent || "Invalid XML").replace(/\\s+/g, " ").trim());
          }
          return parsed;
        }
        (async function () {
          try {
            const sourceNode = parseSource(sourceText);
            await SaxonJS.transform(
              {
                stylesheetLocation: ${JSON.stringify(STYLESHEET_LOCATION)},
                sourceNode: sourceNode,
                stylesheetParams: { "xform-html-id": "xForm" }
              },
              "async"
            );
            post("info", "Render complete.");
          } catch (error) {
            post("error", error instanceof Error ? error.message : String(error));
          }
        })();
      })();
    </script>
  </body>
</html>`;
  }

  async function refresh() {
    clearConsole();
    const sourceTextarea = getSourceTextarea();
    const renderTarget = getRenderTarget();
    if (!sourceTextarea) {
      appendConsoleLine("error", "Unable to find source editor control.");
      return;
    }
    if (!renderTarget) {
      appendConsoleLine("error", "Unable to find render target container.");
      return;
    }

    const sourceText = sourceTextarea.value;
    appendConsoleLine("info", "Rendering nested XForms from source editor.");

    try {
      parseXml(sourceText);
      installFrameMessageListener();
      if (!(renderTarget instanceof HTMLIFrameElement)) {
        throw new Error("Render target is not an iframe.");
      }
      renderTarget.srcdoc = buildFrameMarkup(sourceText);
    } catch (error) {
      appendConsoleLine("error", error instanceof Error ? error.message : String(error));
    }
  }

  function resetSource() {
    const sourceTextarea = getSourceTextarea();
    if (!sourceTextarea) {
      appendConsoleLine("error", "Unable to find source editor control.");
      return;
    }
    sourceTextarea.value = DEFAULT_NESTED_XFORMS_SOURCE;
    sourceTextarea.dispatchEvent(new Event("input", { bubbles: true }));
    sourceTextarea.dispatchEvent(new Event("change", { bubbles: true }));
    sourceTextarea.dispatchEvent(new Event("blur", { bubbles: true }));
    appendConsoleLine("info", "Source reset to default.");
  }

  window.nativeXFormsFiddle = {
    refresh,
    resetSource,
    getDefaultSource() {
      return DEFAULT_NESTED_XFORMS_SOURCE;
    }
  };
})();
