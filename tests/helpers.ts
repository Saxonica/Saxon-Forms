import type { Page } from "@playwright/test";
import type { SaxonFormsWindow } from "./types";
export type SubmissionXPathEvaluationResult = {
  parseError: string;
  xpathError: string;
  values: Record<string, string>;
};

export async function evaluateSubmissionXPath(
  page: Page,
  xmlBody: string,
  expressions: Record<string, string>
): Promise<SubmissionXPathEvaluationResult> {
  // TEST-TRACE: shared SaxonJS XPath payload analyzer for any Playwright spec; helps tests/xforms/w3c/ch11.spec.ts and future suites.
  return page.evaluate(
    ({ payload, xpathExpressions }) => {
      const parsed = new DOMParser().parseFromString(payload, "application/xml");
      const parseError = parsed.querySelector("parsererror");
      if (parseError) {
        return {
          parseError: parseError.textContent || "XML parse error",
          xpathError: "",
          values: {} as Record<string, string>,
        };
      }
      try {
        const evaluateXPath = (expression: string) => {
          const g = window as unknown as SaxonFormsWindow;
          const xpath = g.SaxonJS?.XPath;
          if (!xpath || typeof xpath.evaluate !== "function") {
            throw new Error("SaxonJS XPath evaluator is unavailable.");
          }
          return xpath.evaluate(expression, parsed);
        };
        const values: Record<string, string> = {};
        for (const [key, expression] of Object.entries(xpathExpressions)) {
          values[key] = String(evaluateXPath(String(expression)));
        }
        return {
          parseError: "",
          xpathError: "",
          values,
        };
      } catch (error) {
        return {
          parseError: "",
          xpathError: error instanceof Error ? error.message : String(error),
          values: {} as Record<string, string>,
        };
      }
    },
    { payload: xmlBody, xpathExpressions: expressions }
  );
}
