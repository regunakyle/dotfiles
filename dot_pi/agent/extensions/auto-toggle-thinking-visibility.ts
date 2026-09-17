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

/** Modes for which the startup visibility switch already ran. */
const startedModes = new WeakSet<object>();

/** The live InteractiveMode instance. Captured in the init() wrapper. */
let mode: InteractiveModeLike | undefined;

/** Set the global thinking-block visibility at runtime. */
function setGlobalThinkingVisibility(visible: boolean): void {
  if (!mode) return;
  if (mode.hideThinkingBlock === !visible) return;
  mode.hideThinkingBlock = !visible;
  mode.updateThinkingBlockVisibility();
}

/**
 * Wrap InteractiveMode.init() to capture the live instance and to show
 * thinking blocks at startup. init() is the only place that exposes the
 * mode object, because no public extension API toggles this state.
 */
function installStartupHook(): void {
  const proto = (
    piCodingAgent as unknown as {
      InteractiveMode?: { prototype?: InteractiveModeLike };
    }
  ).InteractiveMode?.prototype;
  if (!proto || typeof proto.init !== "function") return;

  const store = proto as unknown as Record<PropertyKey, unknown>;
  const base = (store[INIT_ORIGINAL] as InitFn | undefined) ?? proto.init;
  store[INIT_ORIGINAL] = base;

  const current = proto.init;
  if (current !== store[INIT_WRAPPER] && current !== base) {
    // Another extension wrapped init after us; do not clobber it.
    return;
  }

  const wrapper = async function (
    this: InteractiveModeLike,
    ...args: unknown[]
  ): Promise<unknown> {
    const result = await base.apply(this, args);
    mode = this;
    if (!startedModes.has(this)) {
      startedModes.add(this);
      // Startup: show thinking blocks globally.
      setGlobalThinkingVisibility(true);
    }
    return result;
  };

  store[INIT_WRAPPER] = wrapper;
  proto.init = wrapper as InitFn;
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
  pi.on("before_agent_start", () => {
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
  pi.on("agent_settled", () => {
    setGlobalThinkingVisibility(false);
  });
}

export default function (pi: ExtensionAPI) {
  installStartupHook();
  installBeforeAgentStartHook(pi);
  installSettledHook(pi);
}
