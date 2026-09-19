/**
 * Load Useful Info Extension
 *
 * On a brand new chat, inject the current datetime, the OS, and the detected
 * Python and Node.js versions once as a hidden custom message. The message is
 * stored in the session transcript, so it is replayed automatically on resume
 * and the extension does nothing there.
 *
 * The system prompt is never modified, so its cached prefix stays valid both
 * within a chat and across a resume.
 *
 * The probes run once, on the first turn of the new chat, and never refresh.
 */

import * as os from "node:os";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const CUSTOM_TYPE = "load-useful-info";
const PROBE_TIMEOUT_MS = 2000;

/** True only for a brand new chat, and only until the info is injected. */
let isNewChat = false;

/** Run a probe and return the combined stdout/stderr text on success. */
async function probe(
  pi: ExtensionAPI,
  command: string,
  args: string[],
): Promise<string | undefined> {
  try {
    const { stdout, stderr, code } = await pi.exec(command, args, {
      timeout: PROBE_TIMEOUT_MS,
    });
    if (code !== 0) return undefined;
    return `${stdout}${stderr}`.trim() || undefined;
  } catch {
    return undefined;
  }
}

/** Detect Python. Tries `python` first, then `python3`. */
async function detectPython(pi: ExtensionAPI): Promise<string | undefined> {
  for (const exe of ["python", "python3"]) {
    // python3 prints the version to stdout, python2 prints it to stderr.
    const text = await probe(pi, exe, ["--version"]);
    // Accept every value after "Python ", for example 3.13.0rc1, 3.12.3+, or 2.7.18.
    const version = text?.match(/Python\s+(.+)/i)?.[1].trim();
    if (version) return version;
  }
  return undefined;
}

/** Detect Node.js through the `node` binary, not the running process. */
async function detectNode(pi: ExtensionAPI): Promise<string | undefined> {
  // `node -v` already prints the leading "v", for example v20.11.0.
  return probe(pi, "node", ["-v"]);
}

/** Build the hidden message content from the detected values. */
function buildContent(
  python: string | undefined,
  node: string | undefined,
): string {
  return [
    `Current datetime: ${new Date().toISOString()}`,
    `OS/Arch: ${os.type()} ${os.arch()} (${os.release()})`,
    `Python: ${python ?? "Not found"}`,
    `Node.js: ${node ?? "Not found"}`,
  ].join("\n");
}

export default function (pi: ExtensionAPI) {
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

  pi.on("before_agent_start", async () => {
    if (!isNewChat) return;
    // Inject on the first turn only; later turns of this chat must not add it again.
    isNewChat = false;

    const [python, node] = await Promise.all([
      detectPython(pi),
      detectNode(pi),
    ]);

    // Use sendMessage({ triggerTurn: false }) rather than returning `message`. Pi appends
    // returned before_agent_start messages *after* the user's message, but this appends
    // while the user message is still pending, so the info is persisted and sent
    // *before* the user's first message.
    await pi.sendMessage(
      {
        customType: CUSTOM_TYPE,
        content: buildContent(python, node),
        display: false,
      },
      { triggerTurn: false },
    );
  });
}
