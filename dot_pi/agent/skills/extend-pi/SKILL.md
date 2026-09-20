---
name: extend-pi
description: Reference workflow for extending or explaining the Pi agent. Verifies Pi's source before answering or coding.
disable-model-invocation: true
---

# Extending the Pi Agent

You are tasked with extending and/or explaining the Pi Agent (yourself). Pi's APIs evolve over time — **NEVER rely on memory or training data for API shapes, event names, or behavior.** ALWAYS verify against the source at the version the user is actually running (or the version the user specified).

## 1. Ensure the reference clone exists and is updated

Check for a `pi-reference` folder in the CURRNET WORKING DIRECTORY. If it does not exist, clone pi:

```bash
git clone https://github.com/earendil-works/pi pi-reference
```

If `pi-reference` already exists, refresh it instead:

```bash
git -C pi-reference fetch --tags origin
```

If either the clone or the fetch fails, you MUST warn the user and stop here. NEVER attempt to answer extension questions from memory.

## 2. Match the reference to the running version (or user specified version)

Unless user specified otherwise, check out the matching tag in the reference clone:

```bash
git -C pi-reference checkout "v$(pi --version)"
```

If the user specified another version, check out that version instead. If checkout fails, you MUST warn the user and stop here.

## 3. Where things live

Work from `pi-reference/packages/coding-agent`:

| What you need | Where to look |
|---|---|
| Extension API, events, lifecycle | `docs/extensions.md` |
| Skills format and discovery | `docs/skills.md` |
| System prompt files (SYSTEM.md etc.) | `docs/usage.md` |
| Working extension examples | `examples/extensions/` |
| SDK usage patterns | `examples/sdk/`, `docs/sdk.md` |
| System prompt construction | `src/core/system-prompt.ts` |
| Extension event dispatch | `src/core/extensions/runner.ts` |
| Event/result type definitions | `src/core/extensions/types.ts` |
| Session lifecycle | `src/core/agent-session.ts` |
| Built-in tool implementations | `src/core/tools/` |
| What's new / breaking changes | `CHANGELOG.md` |

Start with the docs and examples. If they don't answer the question, read the source. When docs and source disagree, the source wins.

## 4. Pi extensions

This part only applies if your task is related to Pi extensions.

- Extensions are TypeScript modules exporting a default factory `(pi: ExtensionAPI) => void`. They load via jiti, so no build step is needed.
- Follow the patterns in `examples/extensions/` — especially `permission-gate.ts` (blocking), `prompt-customizer.ts` (system prompt options), and `plan-mode/` (a full-featured example).
- Extensions run with full system permissions. Gate anything project-local behind trust; never execute untrusted input.
- For UI work, read `docs/tui.md` before writing components.
