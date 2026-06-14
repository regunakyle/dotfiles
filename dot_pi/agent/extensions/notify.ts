/**
 * Desktop Notification Extension
 *
 * Sends a desktop notification when the agent finishes and is waiting for input.
 * Works on Linux (with notify-send). Tested on Fedora KDE only.
 * TODO: Also add Windows support
 *
 * Stolen and modified from: https://github.com/mitsuhiko/agent-stuff/blob/a3f8ab1108a48fec9e175f6cd5d9aaa4694ce29d/extensions/notify.ts
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Markdown, type MarkdownTheme } from "@earendil-works/pi-tui";

const isTextPart = (part: unknown): part is { type: "text"; text: string } =>
  Boolean(
    part &&
    typeof part === "object" &&
    "type" in part &&
    part.type === "text" &&
    "text" in part,
  );

const extractLastAssistantText = (
  messages: Array<{ role?: string; content?: unknown }>,
): string | null => {
  for (let i = messages.length - 1; i >= 0; i--) {
    const message = messages[i];
    if (message?.role !== "assistant") {
      continue;
    }

    const content = message.content;
    if (typeof content === "string") {
      return content.trim() || null;
    }

    if (Array.isArray(content)) {
      const text = content
        .filter(isTextPart)
        .map((part) => part.text)
        .join("\n")
        .trim();
      return text || null;
    }

    return null;
  }

  return null;
};

const plainMarkdownTheme: MarkdownTheme = {
  heading: (text) => text,
  link: (text) => text,
  linkUrl: () => "",
  code: (text) => text,
  codeBlock: (text) => text,
  codeBlockBorder: () => "",
  quote: (text) => text,
  quoteBorder: () => "",
  hr: () => "",
  listBullet: () => "",
  bold: (text) => text,
  italic: (text) => text,
  strikethrough: (text) => text,
  underline: (text) => text,
};

const simpleMarkdown = (text: string, width = 80): string => {
  const markdown = new Markdown(text, 0, 0, plainMarkdownTheme);
  return markdown.render(width).join("\n");
};

const formatNotification = (
  text: string | null,
): { title: string; body: string } => {
  const simplified = text ? simpleMarkdown(text) : "";
  const normalized = simplified.replace(/\s+/g, " ").trim();
  if (!normalized) {
    return { title: "Pi: Ready for input", body: "" };
  }

  const maxBody = 200;
  const body =
    normalized.length > maxBody
      ? `${normalized.slice(0, maxBody - 1)}…`
      : normalized;
  return { title: "Pi: Inference finished", body };
};

export default function (pi: ExtensionAPI) {
  pi.on("agent_end", async (event) => {
    const lastText = extractLastAssistantText(event.messages ?? []);
    const { title, body } = formatNotification(lastText);
    pi.exec("notify-send", ["-a", title, body]);
  });
}
