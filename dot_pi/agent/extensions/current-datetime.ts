/**
 * Current Datetime Extension
 *
 * Appends "The current datetime is <ISO8601 datetime in UTC>." to the system
 * prompt, so the model knows the current time. The timestamp is computed
 * once at startup and stays fixed for the whole session.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const CURRENT_DATETIME = new Date().toISOString();

export default function (pi: ExtensionAPI) {
  pi.on("before_agent_start", async (event) => {
    return {
      systemPrompt: `${event.systemPrompt}\n\nThe current datetime is ${CURRENT_DATETIME}.`,
    };
  });
}
