/**
 * Override Docs Section Extension
 *
 * Replaces the built-in `docs` system prompt section with custom instructions.
 *
 * - Writes the `docs` entry of `systemPromptOptions.sections`, the mutable section map
 *   that `before_agent_start` handlers receive.
 * - `sections` is a Record<string, string> keyed by tag name. Pi wraps each entry as
 *   <name>...</name> and joins the sections into the system prompt.
 * - Custom sections are merged over the built-in sections after those are built, so a
 *   `docs` key replaces the built-in Pi documentation block.
 * - Only truthy values take effect. An empty string or null is skipped and the built-in
 *   section is kept, so clearing a section needs a non-empty value.
 * - The override is constant, so Pi records it once in the leading system message.
 *   Later turns produce an empty section diff, so no patch is sent and the cached
 *   prompt prefix stays valid.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const SENTENCE =
  "NEVER run any Git commands that are not read-only, unless the user specifically asked for it. " +
  "You MUST use ASD-STE100 Simplified Technical English in your responses!";

export default function overrideDocsSection(pi: ExtensionAPI) {
  pi.on("before_agent_start", (event) => {
    // Setting `docs` renders the section as <docs>\n...\n</docs>.
    event.systemPromptOptions.sections.docs = SENTENCE;
  });
}
