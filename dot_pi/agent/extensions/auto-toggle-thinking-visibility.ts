/**
 * Auto toggle thinking visibility.
 *
 * - On pi startup: show thinking blocks globally.
 * - At the start of an agent run (before_agent_start): show them.
 * - When the agent run settles (agent_settled): hide them.
 *
 * Global visibility is the same state ctrl+t changes, but this extension
 * only changes it at runtime. It does not write to settings.json.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import * as piCodingAgent from "@earendil-works/pi-coding-agent";

type InitFn = (...args: unknown[]) => Promise<unknown> | unknown;

interface InteractiveModeLike {
  hideThinkingBlock: boolean;
  updateThinkingBlockVisibility(): void;
  init: InitFn;
}

const INIT_WRAPPER = Symbol.for("pi.auto-thinking.initWrapper");
const INIT_ORIGINAL = Symbol.for("pi.auto-thinking.initOriginal");

/**
 * Registry for the live InteractiveMode instance, stored on globalThis
 * under a well-known symbol so it survives extension module
 * re-evaluation.
 *
 * /reload clears pi's extension cache (ResourceLoader.reload() ->
 * clearExtensionCache()), so jiti re-evaluates the module and resets all
 * module-level state. InteractiveMode.init() runs only once per process,
 * so the reloaded module can never re-capture the instance through the
 * init wrapper alone. The global registry is the only state that both
 * the first and every later module evaluation can see.
 */
const MODE_REGISTRY = Symbol.for("pi.auto-thinking.capturedMode");

function getCapturedMode(): InteractiveModeLike | undefined {
  return (globalThis as unknown as Record<PropertyKey, unknown>)[MODE_REGISTRY] as
    | InteractiveModeLike
    | undefined;
}

/** Set the global thinking-block visibility at runtime. */
function setGlobalThinkingVisibility(visible: boolean): void {
  const mode = getCapturedMode();
  if (!mode) return;
  if (mode.hideThinkingBlock === !visible) return;
  mode.hideThinkingBlock = !visible;
  mode.updateThinkingBlockVisibility();
}

/**
 * Wrap InteractiveMode.init() to capture the live instance and to show
 * thinking blocks at startup. init() is the only place that exposes the
 * mode object, because no public extension API toggles this state.
 *
 * The extension factory re-runs on every session rebind (/new, /fork,
 * /switchSession, /reload), and /reload additionally re-evaluates the
 * module itself (fresh module state). init() runs only once per process:
 * the same InteractiveMode instance serves every session. The wrapper
 * therefore re-wraps the original init around the same base on each
 * rebind, and records the instance in the global registry so every
 * module evaluation can reach it.
 *
 * Returns false when the hook could not be installed, so the caller can
 * surface a warning instead of failing silently.
 */
function installStartupHook(): boolean {
  const proto = (
    piCodingAgent as unknown as {
      InteractiveMode?: { prototype?: InteractiveModeLike };
    }
  ).InteractiveMode?.prototype;
  if (!proto || typeof proto.init !== "function") return false;

  const store = proto as unknown as Record<PropertyKey, unknown>;
  const base = (store[INIT_ORIGINAL] as InitFn | undefined) ?? proto.init;
  store[INIT_ORIGINAL] = base;

  const current = proto.init;
  if (current !== store[INIT_WRAPPER] && current !== base) {
    // Another extension wrapped init after us; do not clobber it.
    return false;
  }

  const wrapper = async function (
    this: InteractiveModeLike,
    ...args: unknown[]
  ): Promise<unknown> {
    const result = await base.apply(this, args);
    (globalThis as unknown as Record<PropertyKey, unknown>)[MODE_REGISTRY] = this;
    // Startup: show thinking blocks globally.
    setGlobalThinkingVisibility(true);
    return result;
  };

  store[INIT_WRAPPER] = wrapper;
  proto.init = wrapper as InitFn;
  return true;
}

/**
 * Show thinking blocks when an agent run starts.
 *
 * before_agent_start fires once per user submission, after the input is
 * accepted and before the agent loop. It is the counterpart of
 * agent_settled. Input queued during streaming does not fire it again,
 * so the run keeps the visibility it started with.
 */
function installBeforeAgentStartHook(pi: ExtensionAPI): void {
  pi.on("before_agent_start", (_event, ctx) => {
    if (ctx.mode !== "tui") return;
    setGlobalThinkingVisibility(true);
  });
}

/**
 * Hide thinking blocks once the whole agent run has settled.
 *
 * agent_settled fires after the agent loop, all tool calls, retries,
 * auto-compaction, and queued continuations are done, i.e. just before
 * the user can input again.
 */
function installSettledHook(pi: ExtensionAPI): void {
  pi.on("agent_settled", (_event, ctx) => {
    if (ctx.mode !== "tui") return;
    setGlobalThinkingVisibility(false);
  });
}

export default function (pi: ExtensionAPI) {
  const hooked = installStartupHook();

  if (!hooked) {
    pi.on("session_start", (_event, ctx) => {
      ctx.ui.notify(
        "auto-toggle-thinking: `InteractiveMode.init` not hookable; extension disabled",
        "warning",
      );
    });
    return;
  }

  installBeforeAgentStartHook(pi);
  installSettledHook(pi);

  // NOTE: do not clear the captured instance on session_shutdown.
  // InteractiveMode is created once per process (main.ts) and serves
  // every session; only the extension instance is rebound. Clearing the
  // capture here would strand it, because init() never fires again for
  // the remaining lifetime of the process.
}
