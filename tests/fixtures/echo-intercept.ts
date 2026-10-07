import { test as base, expect } from "@playwright/test";
import { installDeterministicNetworkRoutes } from "./network-routes";

/**
 * Extends Playwright's base `test` with the shared deterministic network
 * routes used by the W3C helpers. This keeps submission/echo behavior
 * consistent across supplemental and W3C suites.
 */
export const test = base.extend<{}>({
    page: async ({ page }, use) => {
        await installDeterministicNetworkRoutes(page);
        await use(page);
    },
});

export { expect };
