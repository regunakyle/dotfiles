/**
 * Self-hosted TabbyAPI provider: text/image chat plus a text-only OpenAI Decisions classifier.
 *
 * Pi does not export its Decisions API client to extensions directly, so this
 * reuses the one inside Pi's built-in OpenAI provider. That client sends requests
 * to the model's own baseUrl, so it works against TabbyAPI's `/v1/decisions`.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { builtinProviders } from "@earendil-works/pi-ai/providers/all";

const BASE_URL = process.env.TABBY_BASE_URL ?? "http://192.168.1.51:5000/v1";
const API_KEY = process.env.TABBY_API_KEY ?? "apiKey";
const MODEL_ID = process.env.TABBY_MODEL_ID ?? "Qwen3.8-27B-exl3";
const COST = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 };

export default function (pi: ExtensionAPI) {
  const classify = builtinProviders().find(
    (provider) => provider.id === "openai",
  )!.classify!;

  pi.registerProvider("self-hosted", {
    name: "Self Hosted",
    baseUrl: BASE_URL,
    api: "openai-completions",
    apiKey: API_KEY,
    models: [
      {
        type: "chat",
        id: MODEL_ID,
        name: "Qwen 3.8 27B",
        reasoning: true,
        input: ["text", "image"],
        contextWindow: 145920,
        maxTokens: 131072,
        cost: COST,
      },
      {
        type: "classifier",
        id: MODEL_ID,
        name: "Qwen 3.8 27B (classifier)",
        api: "openai-decisions",
        input: ["text"],
        contextWindow: 145920,
        cost: COST,
      },
    ],
    classifiers: {
      "openai-decisions": { classify },
    },
  });
}
