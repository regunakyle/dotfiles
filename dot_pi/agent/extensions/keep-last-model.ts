/**
 * Keep Last Model Extension
 *
 * Pi applies the default model setting (defaultProvider/defaultModel in
 * settings.json) whenever a fresh session starts and no other model source
 * applies: no --model/--provider CLI flag, no scoped model pick (--models /
 * enabledModels), no model restored from the session transcript. The initial
 * startup may use the default; this extension intercepts only the later
 * reaplications and keeps using the last model instead.
 *
 * Interception points ("afterwards" model changes that use the default):
 *  - /new: the new empty session gets the settings default applied. With a
 *    model scope active, pi instead picks the saved default when it is inside
 *    the scope, else the first scoped model; the extension keeps the last
 *    model whenever it is part of the scope.
 *  - /resume and /fork when the session's own model could not be restored
 *    (model gone from the catalogue or no auth): pi falls back to the default.
 *
 * The last model is recorded on every model change (/model, Ctrl+P,
 * pi.setModel) and after every completed agent run.
 *
 * Storage: a globalThis registry under a well-known symbol. pi re-evaluates
 * extension modules on every session replacement (/new, /resume, /fork clear
 * the extension cache), so module-level state resets; globalThis is the only
 * state every module evaluation can see. The record therefore lives for the
 * whole pi process: a /new in the same process keeps the last model, while a
 * fresh pi process starts with no record (undefined) and applies nothing
 * until a model is used or switched once.
 *
 * Cases where the model is left alone:
 *  - Initial process startup: pi's pick, including the default model, is
 *    applied as usual.
 *  - The session restored its model from the transcript (pi -c, --resume,
 *    --fork, /resume, /clone).
 *  - The model was chosen explicitly on the command line (--model, --provider,
 *    --models); on /new the CLI model is reapplied, and for --models the
 *    first scoped model is reapplied (or the default, when it is inside the
 *    scope -- in that sub-case the default stays, by design of this guard).
 *  - A model scope (--models / enabledModels) is active and the target model
 *    is not part of it.
 *  - The target model is gone from the catalogue or has no configured
 *    authentication; pi.setModel returns false and pi's pick stays.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

interface LastModel {
  provider: string;
  modelId: string;
}

/** Well-known globalThis key; survives module re-evaluation within the process. */
const LAST_MODEL_KEY = Symbol.for("pi.keep-last-model.record");

/** The record, or undefined when no model was used or switched yet. */
function getLastModel(): LastModel | undefined {
  return (globalThis as Record<PropertyKey, unknown>)[LAST_MODEL_KEY] as
    | LastModel
    | undefined;
}

function saveLastModel(entry: LastModel): void {
  (globalThis as Record<PropertyKey, unknown>)[LAST_MODEL_KEY] = entry;
}

/** True when the command line names a model explicitly. */
function cliSpecifiesModel(): boolean {
  return process.argv.some((arg) =>
    /^--(model|provider|models)(=|$)/.test(arg),
  );
}

/** Loose shape of the session entries scanned below. */
interface BranchEntryLike {
  type: string;
  provider?: string;
  modelId?: string;
  message?: { role?: string; provider?: string; model?: string };
}

/**
 * Model recorded in the session transcript: the last model_change entry or
 * assistant message wins (same rule as pi's getSessionContextSettings).
 */
function sessionRecordedModel(
  branch: readonly BranchEntryLike[],
): { provider: string; modelId: string } | undefined {
  let recorded: { provider: string; modelId: string } | undefined;
  for (const entry of branch) {
    if (entry.type === "model_change" && entry.provider && entry.modelId) {
      recorded = { provider: entry.provider, modelId: entry.modelId };
    } else if (
      entry.type === "message" &&
      entry.message?.role === "assistant" &&
      entry.message.provider &&
      entry.message.model
    ) {
      recorded = {
        provider: entry.message.provider,
        modelId: entry.message.model,
      };
    }
  }
  return recorded;
}

export default function (pi: ExtensionAPI) {
  // Track every model switch: /model, Ctrl+P cycling, pi.setModel calls.
  pi.on("model_select", (event) => {
    saveLastModel({ provider: event.model.provider, modelId: event.model.id });
  });

  // Track the model that actually served a completed run. This covers
  // sessions that use pi's automatic pick without ever switching manually.
  pi.on("agent_end", (_event, ctx) => {
    if (ctx.model)
      saveLastModel({ provider: ctx.model.provider, modelId: ctx.model.id });
  });

  pi.on("session_start", async (event, ctx) => {
    // Initial startup ("startup"): pi's pick (the default model) is fine,
    // leave it. "reload" keeps the live model.
    if (
      event.reason !== "new" &&
      event.reason !== "resume" &&
      event.reason !== "fork"
    )
      return;

    const current = ctx.model;
    if (!current) return;

    // pi restores a model from the transcript only when the target session
    // already has context (a message, custom message, summary, or compaction).
    // Brand-new sessions and /new get pi's automatic pick instead, and for
    // those pi has already appended its resolved model as the first
    // model_change entry before session_start fires. A plain
    // "recorded === current" test would therefore always match on /new and
    // wrongly skip the switch, so require context before treating it as a
    // successful restore.
    const hasContext = ctx.sessionManager.buildContextEntries().some(
      (entry) =>
        entry.type === "message" ||
        entry.type === "custom_message" ||
        entry.type === "compaction" ||
        (entry.type === "branch_summary" && Boolean(entry.summary)),
    );
    const recorded = sessionRecordedModel(ctx.sessionManager.getBranch());
    if (
      hasContext &&
      recorded &&
      recorded.provider === current.provider &&
      recorded.modelId === current.id
    )
      return;

    // Reached for: /new (pi's automatic pick was applied to the empty
    // session), or /resume / /fork where the recorded model differs from the
    // current one, i.e. the restore failed and pi fell back to the default.

    // An explicit CLI pick wins over both the default and the last model.
    // On /new, pi reapplies the CLI model instead of the default.
    if (cliSpecifiesModel()) return;

    const lastModel = getLastModel();
    // No record yet (fresh process, nothing used or switched): apply nothing.
    if (!lastModel) return;

    // pi already picked the last model (e.g. it is the saved default, or the
    // scoped default): nothing to do.
    if (
      lastModel.provider === current.provider &&
      lastModel.modelId === current.id
    )
      return;

    // Candidates: the active scope (--models / enabledModels) or the whole
    // available catalogue, mirroring pi's own model picker.
    const candidates =
      ctx.scopedModels.length > 0
        ? ctx.scopedModels.map((scoped) => scoped.model)
        : ctx.modelRegistry.getAvailable();
    if (candidates.length === 0) return;

    const target = candidates.find(
      (model) =>
        model.provider === lastModel.provider && model.id === lastModel.modelId,
    );
    if (!target) return;

    // setModel returns false when the provider has no configured auth;
    // in that case pi's automatic pick stays in place.
    const applied = await pi.setModel(target);
    if (!applied) return;

    if (ctx.hasUI) {
      ctx.ui.notify(`Keeping last model: ${target.provider}/${target.id}`, "info");
    }
  });
}
