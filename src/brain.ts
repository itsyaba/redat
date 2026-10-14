import { spawn } from "node:child_process";
import { createInterface } from "node:readline";
import { randomUUID } from "node:crypto";
import { MODEL, WORK } from "./config.ts";
import { SYSTEM_PROMPT } from "./prompt.ts";
import { desktopSnapshot } from "./desktop.ts";
import { logCommand } from "./log.ts";

export type Reply = { am: string; en: string };

/** Split Claude's "Amharic…\nEN: English" reply; tolerate a missing EN line. */
export function splitReply(text: string): Reply {
  const m = text.match(/^([\s\S]*?)\n\s*EN:\s*([\s\S]*)$/);
  return m ? { am: m[1].trim(), en: m[2].trim() } : { am: text.trim(), en: "" };
}

export type BrainEvents = {
  /** Called when Claude starts a tool call (e.g. a Bash command). */
  onTool?: (name: string, input: any) => void;
};

/** One Claude conversation driven through the `claude` CLI (runs on the subscription). */
export class Brain {
  sessionId = randomUUID();
  private started = false;

  reset() {
    this.sessionId = randomUUID();
    this.started = false;
  }

  async think(userText: string, events: BrainEvents = {}): Promise<Reply> {
    const message = `${await desktopSnapshot()}\n\n[user said] ${userText}`;
    const args = [
      "-p", message,
      "--output-format", "stream-json", "--verbose",
      "--model", MODEL,
      "--system-prompt", SYSTEM_PROMPT,
      "--tools", "Bash,WebSearch,WebFetch",
      "--permission-mode", "bypassPermissions",
      // Skip user settings/plugins/hooks and MCP servers: halves startup time and context.
      "--setting-sources", "",
      "--strict-mcp-config",
      ...(this.started ? ["--resume", this.sessionId] : ["--session-id", this.sessionId]),
    ];
    const child = spawn("claude", args, { cwd: WORK, stdio: ["ignore", "pipe", "pipe"] });
    let stderr = "";
    child.stderr.on("data", (d) => (stderr += d));

    const pending = new Map<string, { name: string; input: any }>();
    let result: any;
    for await (const line of createInterface({ input: child.stdout })) {
      if (!line.trim()) continue;
      let ev: any;
      try {
        ev = JSON.parse(line);
      } catch {
        continue;
      }
      const content = ev.message?.content;
      if (ev.type === "assistant" && Array.isArray(content)) {
        for (const c of content) {
          if (c.type !== "tool_use") continue;
          pending.set(c.id, { name: c.name, input: c.input });
          events.onTool?.(c.name, c.input);
        }
      } else if (ev.type === "user" && Array.isArray(content)) {
        for (const c of content) {
          if (c.type !== "tool_result") continue;
          const call = pending.get(c.tool_use_id);
          pending.delete(c.tool_use_id);
          const output = Array.isArray(c.content)
            ? c.content.map((x: any) => x.text ?? "").join("")
            : String(c.content ?? "");
          logCommand({ tool: call?.name ?? "?", input: call?.input, output, error: !!c.is_error });
        }
      } else if (ev.type === "result") {
        result = ev;
      }
    }
    const code = await new Promise<number | null>((r) => child.once("close", r));
    if (!result) throw new Error(`claude exited ${code} without a result: ${stderr.slice(0, 500)}`);
    this.started = true;
    if (result.is_error) throw new Error(`Claude failed: ${result.result}`);
    return splitReply(String(result.result));
  }
}
