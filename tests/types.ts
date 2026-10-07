import type { Request } from "@playwright/test";

export type RequestPredicate = (request: Request) => boolean;

export type DispatchedEventRecord = {
  name: string;
  context: Record<string, string>;
};

export type SaxonFormsWindow = Window & {
  getInstance?: (id: string) => (Document | Element) | null;
  getInstanceKeys?: () => string[];
  clearDispatchedEvents?: () => void;
  getDispatchedEvents?: () => unknown;
  getModelDefaultInstanceKey?: (modelId: string) => string | string[] | undefined;
  SaxonJS?: {
    XPath?: {
      evaluate: (expression: string, contextNode: Node) => unknown;
    };
  };
};
