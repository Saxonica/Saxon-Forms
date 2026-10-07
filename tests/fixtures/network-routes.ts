import type { Page, Route } from "@playwright/test";

const configuredPlaywrightBaseUrl =
  process.env.PLAYWRIGHT_BASE_URL ||
  `http://${process.env.PLAYWRIGHT_TEST_HOST || "127.0.0.1"}:${process.env.PLAYWRIGHT_TEST_PORT || "5174"}`;
const configuredPlaywrightHost = (() => {
  try {
    return new URL(configuredPlaywrightBaseUrl).hostname.toLowerCase().replace(/\.$/, "");
  } catch {
    return "127.0.0.1";
  }
})();
const localHarnessHosts = new Set<string>([
  "localhost",
  "127.0.0.1",
  "::1",
  "[::1]",
  configuredPlaywrightHost,
]);
const echoServiceHosts = new Set<string>([
  "xformstest.org",
  "www.xformstest.org",
  "www.w3.org",
]);
const forcedExternalFailureHosts = new Set<string>([
  "bad.url",
  "invalid",
  "invaliduri",
  "invaliduri.com",
  "invaliduri.com8565",
]);

function escapeEchoHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function buildEchoShHtmlResponse(
  method: string,
  pathname: string,
  search: string,
  body: string,
  contentType: string,
  headers: Record<string, string>
): string {
  const queryString = search.startsWith("?") ? search.slice(1) : search;
  const requestUri = `${pathname}${search}`;
  const normalizedMethod = method.toUpperCase();
  const environmentLines: string[] = [];
  const bodyLength = new TextEncoder().encode(body).length;
  if (normalizedMethod !== "GET" && normalizedMethod !== "HEAD") {
    environmentLines.push(`CONTENT_LENGTH=${bodyLength}`);
  }
  if (contentType) {
    environmentLines.push(`CONTENT_TYPE=${escapeEchoHtml(contentType)}`);
  }
  environmentLines.push(`QUERY_STRING=${escapeEchoHtml(queryString)}`);
  environmentLines.push(`REQUEST_METHOD=${escapeEchoHtml(normalizedMethod)}`);
  environmentLines.push(`REQUEST_URI=${escapeEchoHtml(requestUri)}`);
  environmentLines.push(`SCRIPT_NAME=${escapeEchoHtml(pathname)}`);
  const headerLines = Object.entries(headers)
    .filter(([name]) => name.toLowerCase() !== "content-length")
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([name, value]) => {
      const cgiName = `HTTP_${name.toUpperCase().replace(/[^A-Z0-9]/g, "_")}`;
      return `${cgiName}=${escapeEchoHtml(String(value))}`;
    });
  environmentLines.push(...headerLines);

  return [
    "<?xml version=\"1.0\"?>",
    "<html xmlns='http://www.w3.org/1999/xhtml'>",
    "<head>",
    "<title>Results from echo.sh</title>",
    "</head>",
    "<body>",
    "<h1>Form posted data</h1>",
    "<pre>",
    escapeEchoHtml(body),
    "</pre>",
    "<h1>Environment variables</h1>",
    "<pre>",
    "",
    environmentLines.join("\n"),
    "</pre>",
    "</body>",
    "</html>",
  ].join("\n");
}

export async function installDeterministicNetworkRoutes(page: Page): Promise<void> {
  const virtualLocalFiles = new Map<string, string>();
  const initializedVirtualFiles = new Set<string>();
  // TEST-TRACE: make external requests deterministic so W3C specs do not fail purely due to internet availability; helps tests/w3c/ch10.spec.ts and tests/w3c/ch11.spec.ts.
  await page.context().route("**/*", async (route: Route) => {
    const request = route.request();
    const method = request.method().toUpperCase();
    const requestUrl = request.url();
    let parsedUrl: URL;
    try {
      parsedUrl = new URL(requestUrl);
    } catch {
      await route.continue();
      return;
    }

    const protocol = parsedUrl.protocol.toLowerCase();
    if (protocol !== "http:" && protocol !== "https:") {
      await route.continue();
      return;
    }

    const pathname = parsedUrl.pathname.toLowerCase();
    const hostname = parsedUrl.hostname.toLowerCase().replace(/\.$/, "");
    const key = pathname || requestUrl.toLowerCase();

    if (/\/echo\.sh$/i.test(pathname) && (localHarnessHosts.has(hostname) || echoServiceHosts.has(hostname))) {
      // TEST-TRACE: mirror live echo.sh response envelope and method/query fields so verb-based submission cases stay deterministic; helps tests/w3c/ch11.spec.ts "11.6.1.a", "11.9.2.a", "11.9.4.a".
      const body = request.postData() || "";
      const headers = request.headers();
      const contentType = headers["content-type"] || "";
      const responseBody = method === "HEAD"
        ? ""
        : buildEchoShHtmlResponse(method, parsedUrl.pathname, parsedUrl.search, body, contentType, headers);
      await route.fulfill({
        status: 200,
        contentType: "text/html",
        headers: {
          "access-control": "allow <*>",
        },
        body: responseBody,
      });
      return;
    }

    if (localHarnessHosts.has(hostname)) {
      if (/(?:myfile|deleteme)\.txt$/i.test(pathname)) {
        if (key.endsWith("/deleteme.txt") && !initializedVirtualFiles.has(key)) {
          virtualLocalFiles.set(key, "seed");
          initializedVirtualFiles.add(key);
        }
        if (method === "PUT" || method === "POST") {
          const body = request.postData() || "";
          virtualLocalFiles.set(key, body);
          await route.fulfill({ status: 200, contentType: "text/plain", body });
          return;
        }
        if (method === "DELETE") {
          virtualLocalFiles.delete(key);
          await route.fulfill({ status: 200, contentType: "text/plain", body: "" });
          return;
        }
        if (method === "GET") {
          if (virtualLocalFiles.has(key)) {
            await route.fulfill({
              status: 200,
              contentType: "text/plain",
              body: virtualLocalFiles.get(key) || "",
            });
            return;
          }
          await route.fulfill({ status: 404, contentType: "text/plain", body: "Not Found" });
          return;
        }
        await route.fulfill({
          status: 405,
          contentType: "text/plain",
          body: `Unsupported method: ${method}`,
        });
        return;
      }

      await route.continue();
      return;
    }

    if (forcedExternalFailureHosts.has(hostname)) {
      await route.abort("addressunreachable");
      return;
    }

    const fallbackBody =
      method === "HEAD"
        ? ""
        : request.postData() || "<?xml version=\"1.0\" encoding=\"UTF-8\"?><data>offline-stub</data>";
    await route.fulfill({
      status: 200,
      contentType: "application/xml",
      body: fallbackBody,
    });
  });
}
