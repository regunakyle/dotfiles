/**
 * Override Docs Section Extension
 *
 * Replaces the built-in `docs` system prompt section with custom instructions.
 *
 * Preferred path (newer pi):
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
 *
 * Fallback (older pi without `systemPromptOptions.sections`):
 * - Mirrors load-useful-info: injects the sentence once, as a hidden custom message on
 *   the first turn of a brand new chat. The message is stored in the transcript and
 *   participates in the LLM context, so resume and fork replay it and the extension
 *   does nothing there.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const CUSTOM_TYPE = "override-docs-section";
const SENTENCE =
  "Be succinct: Use ASD-STE100 Simplified Technical English in your responses. " +
  "Important: Never run any Git commands that are not read-only, unless the user specifically asked for it.";

/** True only for a brand new chat, and only until the fallback message is injected. */
let isNewChat = false;

export default function overrideDocsSection(pi: ExtensionAPI) {
  pi.on("session_start", (event, ctx) => {
    // Resume and fork continue an existing chat history: do nothing.
    if (event.reason === "resume" || event.reason === "fork") {
      isNewChat = false;
      return;
    }

    // "startup", "new", and "reload" are brand new only when the transcript has no
    // conversation messages yet. Do NOT test getEntries().length === 0: pi appends
    // model_change and thinking_level_change entries before session_start, so the
    // count is never zero for a real new chat.
    const hasConversationMessages = ctx.sessionManager
      .getEntries()
      .some((entry) => entry.type === "message");
    isNewChat = !hasConversationMessages;
  });

  pi.on("before_agent_start", async (event) => {
    // Older pi builds have no `sections` field (and may lack the options object),
    // so read it defensively.
    const options = event.systemPromptOptions as
      | (typeof event.systemPromptOptions & {
          sections?: Record<string, string>;
        })
      | undefined;

    // Preferred path: override the built-in `docs` section in place.
    // Setting `docs` renders the section as <docs>\n...\n</docs>.
    if (options?.sections) {
      options.sections.docs = SENTENCE;
      return;
    }

    // Fallback path: inject the sentence once, on the first turn of a new chat.
    if (!isNewChat) return;
    isNewChat = false;

    // Use sendMessage({ triggerTurn: false }) rather than returning `message`. Pi appends
    // returned before_agent_start messages *after* the user's message, but this appends
    // while the user message is still pending, so the sentence is persisted and sent
    // *before* the user's first message.
    await pi.sendMessage(
      {
        customType: CUSTOM_TYPE,
        content: SENTENCE,
        display: false,
      },
      { triggerTurn: false },
    );
  });
}
