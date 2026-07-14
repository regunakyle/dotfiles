/**
 * Print System Prompt Extension
 *
 * Registers a `/system-prompt` command that writes the current system prompt
 * to `system-prompt.txt` in the current working directory.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { writeFileSync } from "node:fs";
import { join } from "node:path";

export default function (pi: ExtensionAPI) {
  pi.registerCommand("system-prompt", {
    description: "Print the current system prompt to system-prompt.txt",
    handler: async (_args, ctx) => {
      const prompt = ctx.getSystemPrompt();
      const outputPath = join(ctx.cwd, "system-prompt.txt");

      writeFileSync(outputPath, prompt, "utf-8");

      ctx.ui.notify(
        `System prompt written to ${outputPath} (${prompt.length} chars)`,
        "info",
      );
    },
  });
}
