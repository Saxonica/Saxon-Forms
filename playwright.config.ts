import { defineConfig, devices } from "@playwright/test";
const playwrightHost = process.env.PLAYWRIGHT_TEST_HOST || "127.0.0.1";
const playwrightPort = Number(process.env.PLAYWRIGHT_TEST_PORT || 5174);
const baseURL =
  process.env.PLAYWRIGHT_BASE_URL || `http://${playwrightHost}:${playwrightPort}`;
const includeDiagnostics = process.env.PLAYWRIGHT_INCLUDE_DIAGNOSTICS === "1";
const browserModeRaw = (process.env.PLAYWRIGHT_BROWSER_MODE || "chrome").trim().toLowerCase();

function resolveProjects(browserMode: string) {
  const normalizedBrowserMode = browserMode === "chromium" ? "chrome" : browserMode;
  const chromeProject = {
    name: "chrome",
    use: { ...devices["Desktop Chrome"] },
  };
  const firefoxProject = {
    name: "firefox",
    use: { ...devices["Desktop Firefox"] },
  };

  if (normalizedBrowserMode === "chrome") {
    return [chromeProject];
  }
  if (normalizedBrowserMode === "firefox") {
    return [firefoxProject];
  }
  if (normalizedBrowserMode === "both") {
    return [chromeProject, firefoxProject];
  }

  throw new Error(
    `Unsupported PLAYWRIGHT_BROWSER_MODE '${browserMode}'. Expected one of: chrome, firefox, both.`
  );
}

const projects = resolveProjects(browserModeRaw);

export default defineConfig({
  testDir: "./tests",
  testIgnore: includeDiagnostics ? [] : ["**/diagnostics/**"],
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  reporter: [
    ["dot"],
    ["html", { open: "never" }]
  ],
  use: {
    baseURL,
    trace: "on-first-retry",
    bypassCSP: true,
    launchOptions: {
      args: ["--disable-web-security"],
    },
  },
  projects,
  webServer: {
    command: `npx http-server tests/runtime -p ${playwrightPort} -c-1`,
    url: baseURL,
    reuseExistingServer: !process.env.CI,
  },
});
