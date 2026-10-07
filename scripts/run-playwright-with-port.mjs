#!/usr/bin/env node
import net from "net";
import { spawn } from "child_process";

const preferredPort = Number(process.env.PLAYWRIGHT_TEST_PORT || 5174);
const searchSpan = Number(process.env.PLAYWRIGHT_PORT_SEARCH_SPAN || 50);
const host = process.env.PLAYWRIGHT_TEST_HOST || "127.0.0.1";
const allowedBrowserModes = new Set(["chrome", "chromium", "firefox", "both"]);

function parseBrowserMode(rawArgs) {
  let browserMode = process.env.PLAYWRIGHT_BROWSER_MODE || "chrome";
  const forwardedArgs = [];

  for (let index = 0; index < rawArgs.length; index++) {
    const arg = rawArgs[index];
    if (arg === "--browser") {
      const value = rawArgs[index + 1];
      if (!value) {
        throw new Error("Missing value for --browser. Expected one of: chrome, firefox, both.");
      }
      browserMode = value;
      index++;
      continue;
    }
    if (arg.startsWith("--browser=")) {
      const value = arg.slice("--browser=".length);
      if (!value) {
        throw new Error("Missing value for --browser. Expected one of: chrome, firefox, both.");
      }
      browserMode = value;
      continue;
    }
    forwardedArgs.push(arg);
  }

  const normalizedBrowserMode = String(browserMode).trim().toLowerCase();
  if (!allowedBrowserModes.has(normalizedBrowserMode)) {
    throw new Error(
      `Unsupported browser mode '${browserMode}'. Expected one of: chrome, firefox, both.`
    );
  }
  const canonicalBrowserMode = normalizedBrowserMode === "chromium" ? "chrome" : normalizedBrowserMode;
  return { browserMode: canonicalBrowserMode, forwardedArgs };
}

function isUsablePort(port) {
  return Number.isInteger(port) && port > 0 && port <= 65535;
}

function isPortAvailable(port, listenHost) {
  return new Promise((resolve) => {
    const server = net.createServer();
    server.unref();
    server.on("error", () => resolve(false));
    server.listen({ port, host: listenHost }, () => {
      server.close(() => resolve(true));
    });
  });
}

async function selectPort() {
  if (!isUsablePort(preferredPort)) {
    throw new Error(`Invalid PLAYWRIGHT_TEST_PORT: ${process.env.PLAYWRIGHT_TEST_PORT}`);
  }
  const maxSpan = Number.isInteger(searchSpan) && searchSpan > 0 ? searchSpan : 50;
  for (let candidate = preferredPort; candidate < preferredPort + maxSpan; candidate++) {
    if (await isPortAvailable(candidate, host)) {
      return candidate;
    }
  }
  throw new Error(
    `Unable to find an available port in range ${preferredPort}-${preferredPort + maxSpan - 1}.`
  );
}

async function main() {
  const selectedPort = await selectPort();
  const baseUrl = `http://${host}:${selectedPort}`;
  const rawArgs = process.argv.slice(2);
  const { browserMode, forwardedArgs: browserForwardedArgs } = parseBrowserMode(rawArgs);
  const includeDiagnostics = rawArgs.includes("--include-diagnostics");
  const forwardedArgs = browserForwardedArgs.filter((arg) => arg !== "--include-diagnostics");
  const isWindows = process.platform === "win32";
  const spawnCommand = isWindows ? "cmd.exe" : "npx";
  const spawnArgs = isWindows
    ? ["/d", "/s", "/c", "npx", "playwright", "test", ...forwardedArgs]
    : ["playwright", "test", ...forwardedArgs];
  console.log(
    JSON.stringify({
      ts: new Date().toISOString(),
      event: "playwright-port-selected",
      preferred_port: preferredPort,
      selected_port: selectedPort,
      base_url: baseUrl,
      browser_mode: browserMode,
      include_diagnostics: includeDiagnostics
    })
  );
  // TEST-TRACE: launch via cmd.exe on Windows to avoid spawn EINVAL from npx.cmd; helps npm run test:e2e.

  const child = spawn(
    spawnCommand,
    spawnArgs,
    {
      stdio: "inherit",
      env: {
        ...process.env,
        PLAYWRIGHT_TEST_HOST: host,
        PLAYWRIGHT_TEST_PORT: String(selectedPort),
        PLAYWRIGHT_BASE_URL: baseUrl,
        PLAYWRIGHT_BROWSER_MODE: browserMode,
        VITE_PORT: String(selectedPort),
        ...(includeDiagnostics ? { PLAYWRIGHT_INCLUDE_DIAGNOSTICS: "1" } : {})
      }
    }
  );

  child.on("error", (error) => {
    console.error(error instanceof Error ? error.message : String(error));
    process.exit(1);
  });

  child.on("exit", (code, signal) => {
    if (signal) {
      process.kill(process.pid, signal);
      return;
    }
    process.exit(code ?? 1);
  });
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
