import { test, expect } from "@playwright/test";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..", "..");

test.describe("path contract", () => {
  test("canonical runtime and fixture roots exist and legacy roots are absent", async () => {
    // TEST-TRACE: enforce canonical test/runtime layout and block legacy root drift; helps migration gate checks for path consolidation.
    const runtimeRoot = path.join(repoRoot, "tests", "runtime");
    const w3cFixturesRoot = path.join(repoRoot, "tests", "fixtures", "external", "w3c-suite");
    const xsdFixturesRoot = path.join(repoRoot, "tests", "fixtures", "external", "xsdtests");
    const legacyPublicTestRoot = path.join(repoRoot, "public-test");
    const legacyTestAppRoot = path.join(repoRoot, "test-app");

    expect(fs.existsSync(runtimeRoot)).toBe(true);
    expect(fs.existsSync(w3cFixturesRoot)).toBe(true);
    expect(fs.existsSync(xsdFixturesRoot)).toBe(true);
    expect(fs.existsSync(legacyPublicTestRoot)).toBe(false);
    expect(fs.existsSync(legacyTestAppRoot)).toBe(false);
  });
});
