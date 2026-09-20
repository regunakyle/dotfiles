/**
 * Print System Prompt Extension
 *
 * Registers a `/system-prompt` command that writes the *effective* system prompt
 * to `system-prompt.txt` in the current working directory.
 *
 * The "effective" prompt includes every `before_agent_start` mutation (for example
 * the docs override from `override-docs-section.ts`). Simply calling
 * `ctx.getSystemPrompt()` from the command does NOT show those mutations: slash
 * commands are dispatched before `before_agent_start` runs, and the run-scoped
 * options are reset to undefined outside an active turn.
 *
 * So instead this command submits a real user message to enter the full prompt
 * pipeline, captures the prompt inside an `agent_start` handler (at which point
 * the mutated options are already applied), and aborts the run before the
 * provider is called.
 *
 * Afterwards it asks the user whether to delete the current session and start a
 * new one. Deleting follows pi's own convention (try the `trash` CLI first, then
 * fall back to `unlink`) and reports failures. Choosing to stay leaves the
 * synthetic turn in place for the user to clean up themselves.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { spawnSync } from "node:child_process";
import { existsSync, writeFileSync } from "node:fs";
import { unlink } from "node:fs/promises";
import { join } from "node:path";

/** Label attached to the injected message so the session tree marks it as synthetic. */
const SENTINEL_LABEL = "system-prompt capture — do not resume";

const CLEANUP_CONFIRM_TITLE = "system-prompt capture";
const CLEANUP_CONFIRM_MESSAGE =
  "Delete the current session and start a new one?\n\n" +
  "If you stay here, you should run `/tree` and pick the one labeled with:" +
  "\n\n`" +
  SENTINEL_LABEL +
  "`\n\n" +
  "Otherwise you might run into issue (depending on which LLM provider you use).";

/**
 * Delete a session file, mirroring pi's own session deletion: try the `trash`
 * CLI first (recoverable), then fall back to a permanent `unlink`.
 */
async function deleteSessionFile(
  sessionPath: string,
): Promise<{ ok: boolean; error?: string }> {
  const trashArgs = sessionPath.startsWith("-")
    ? ["--", sessionPath]
    : [sessionPath];
  const trashResult = spawnSync("trash", trashArgs, { encoding: "utf-8" });

  // Trash succeeded, or the file is already gone.
  if (trashResult.status === 0 || !existsSync(sessionPath)) {
    return { ok: true };
  }

  // Fall back to permanent deletion.
  try {
    await unlink(sessionPath);
    return { ok: true };
  } catch (err) {
    const unlinkError = err instanceof Error ? err.message : String(err);
    const trashHint =
      trashResult.error?.message ?? trashResult.stderr?.trim().split("\n")[0];
    const error = trashHint
      ? `${unlinkError} (trash: ${trashHint})`
      : unlinkError;
    return { ok: false, error };
  }
}

export default function (pi: ExtensionAPI) {
  pi.registerCommand("system-prompt", {
    description: "Print the current system prompt to system-prompt.txt",
    handler: async (_args, ctx) => {
      const outputPath = join(ctx.cwd, "system-prompt.txt");

      let captured = "";
      let resolveDone: () => void = () => {};
      const done = new Promise<void>((resolve) => {
        resolveDone = resolve;
      });

      // Captured after before_agent_start handlers have run, so getSystemPrompt()
      // reflects their mutations. Abort immediately, before the provider is called.
      const unsubscribeStart = pi.on("agent_start", (_event, agentCtx) => {
        captured = agentCtx.getSystemPrompt();
        writeFileSync(outputPath, captured, "utf-8");
        agentCtx.abort();
      });

      // pi.sendUserMessage() is fire-and-forget, so completion is observed here.
      const unsubscribeSettled = pi.on("agent_settled", () => {
        resolveDone();
      });

      // Safety net: if the run never starts (e.g. no model/API key), don't hang.
      const timeout = setTimeout(() => resolveDone(), 10000);

      try {
        // Empty injected turn: it only exists to drive the pipeline
        // (before_agent_start -> agent_start), then is aborted before inference.
        pi.sendUserMessage("");
        await done;
      } finally {
        clearTimeout(timeout);
        unsubscribeStart();
        unsubscribeSettled();
      }

      if (captured.length === 0) {
        ctx.ui.notify("Failed to capture the system prompt.", "error");
        return;
      }

      // Ask how to clean up. Defaults to staying (non-destructive) when no
      // dialog-capable UI is available.
      let shouldDelete = false;
      if (ctx.hasUI) {
        shouldDelete = await ctx.ui.confirm(
          CLEANUP_CONFIRM_TITLE,
          CLEANUP_CONFIRM_MESSAGE,
        );
      }

      if (shouldDelete) {
        // Capture the old file path BEFORE replacing the session: the old ctx
        // goes stale as soon as ctx.newSession() succeeds.
        const oldSessionFile = ctx.sessionManager.getSessionFile();

        const result = await ctx.newSession({
          withSession: async (freshCtx) => {
            let failure: string | undefined;
            if (oldSessionFile) {
              const deletion = await deleteSessionFile(oldSessionFile);
              if (!deletion.ok) {
                failure = deletion.error ?? "unknown error";
              }
            }

            if (failure) {
              freshCtx.ui.notify(
                `System prompt written to ${outputPath} (${captured.length} chars). New session started, but the previous session could not be deleted (${failure}).`,
                "warning",
              );
            } else {
              freshCtx.ui.notify(
                `System prompt written to ${outputPath} (${captured.length} chars). Previous session deleted; new session started.`,
                "info",
              );
            }
          },
        });

        if (result.cancelled) {
          // Replacement did not happen, so the old ctx is still valid here.
          ctx.ui.notify("New session cancelled.", "warning");
        }
        return;
      }

      // Stay: do not rewind. Leave the synthetic turn in place for the user to
      // handle themselves. The label just marks it clearly in the tree.
      const injectedId = ctx.sessionManager.getLeafEntry()?.parentId;
      if (injectedId && ctx.sessionManager.getEntry(injectedId)) {
        pi.setLabel(injectedId, SENTINEL_LABEL);
      }

      ctx.ui.notify(
        `System prompt written to ${outputPath} (${captured.length} chars). The aborted turn is harmless and can be ignored.`,
        "info",
      );
    },
  });
}
