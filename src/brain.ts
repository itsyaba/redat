import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
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
  onTool?: (name: string, input: any, id: string) => void;
  /** Called when that tool call finishes. */
  onToolResult?: (id: string, output: string, error: boolean) => void;
  /** Streaming text as Claude writes it. */
  onText?: (delta: string) => void;
};

type Turn = { events: BrainEvents; resolve: (r: Reply) => void; reject: (e: Error) => void };

/**
 * One Claude conversation in a long-lived `claude` CLI process (runs on the subscription).
 * Messages go in over stream-json stdin, so each turn skips CLI startup and session resume.
 */
export class Brain {
  sessionId = randomUUID();
  private proc: ChildProcessWithoutNullStreams | undefined;
  private turn: Turn | undefined;
  private queue: Promise<unknown> = Promise.resolve();
  private pending = new Map<string, { name: string; input: any }>();
  private stderr = "";

  private resume = false;

  /** Start the process now so the first turn doesn't pay for it. */
  warm() {
    this.ensure();
  }

  reset() {
    this.kill();
    this.sessionId = randomUUID();
    this.resume = false;
  }

  kill() {
    this.proc?.kill();
    this.proc = undefined;
  }

  private ensure() {
    if (this.proc && this.proc.exitCode === null) return this.proc;
    const args = [
      "-p",
      "--input-format", "stream-json",
      "--output-format", "stream-json", "--verbose",
      "--include-partial-messages",
      "--model", MODEL,
      "--system-prompt", SYSTEM_PROMPT,
      "--tools", "Bash,WebSearch,WebFetch",
      "--permission-mode", "bypassPermissions",
      // Skip user settings/plugins/hooks and MCP servers: halves startup time and context.
      "--setting-sources", "",
      "--strict-mcp-config",
      ...(this.resume ? ["--resume", this.sessionId] : ["--session-id", this.sessionId]),
    ];
    // Any later restart of this conversation must resume, not recreate, the session.
    this.resume = true;
    const proc = spawn("claude", args, { cwd: WORK, stdio: ["pipe", "pipe", "pipe"] });
    this.stderr = "";
    proc.stderr.on("data", (d) => (this.stderr = (this.stderr + d).slice(-2000)));
    proc.on("error", (err) => this.fail(err));
    proc.on("exit", (code) => {
      if (this.proc === proc) this.proc = undefined;
      this.fail(new Error(`claude exited (${code}): ${this.stderr.slice(-500)}`));
    });
    createInterface({ input: proc.stdout }).on("line", (line) => this.onLine(line));
    this.proc = proc;
    return proc;
  }

  private fail(err: Error) {
    const t = this.turn;
    this.turn = undefined;
    t?.reject(err);
  }

  private onLine(line: string) {
    let ev: any;
    try {
      ev = JSON.parse(line);
    } catch {
      return;
    }
    const t = this.turn;
    if (!t) return;
    const content = ev.message?.content;
    if (ev.type === "stream_event") {
      const d = ev.event?.delta;
      if (ev.event?.type === "content_block_delta" && d?.type === "text_delta") t.events.onText?.(d.text);
    } else if (ev.type === "assistant" && Array.isArray(content)) {
      for (const c of content) {
        if (c.type !== "tool_use") continue;
        this.pending.set(c.id, { name: c.name, input: c.input });
        t.events.onTool?.(c.name, c.input, c.id);
      }
    } else if (ev.type === "user" && Array.isArray(content)) {
      for (const c of content) {
        if (c.type !== "tool_result") continue;
        const call = this.pending.get(c.tool_use_id);
        this.pending.delete(c.tool_use_id);
        const output = Array.isArray(c.content)
          ? c.content.map((x: any) => x.text ?? "").join("")
          : String(c.content ?? "");
        logCommand({ tool: call?.name ?? "?", input: call?.input, output, error: !!c.is_error });
        t.events.onToolResult?.(c.tool_use_id, output, !!c.is_error);
      }
    } else if (ev.type === "result") {
      this.turn = undefined;
      if (ev.is_error) t.reject(new Error(`Claude failed: ${ev.result}`));
      else t.resolve(splitReply(String(ev.result ?? "")));
    }
  }

  /** Send one user message; turns are serialized, so a new one waits for the previous result. */
  think(userText: string, events: BrainEvents = {}): Promise<Reply> {
    const run = async () => {
      const message = `${await desktopSnapshot()}\n\n[user said] ${userText}`;
      const proc = this.ensure();
      return new Promise<Reply>((resolve, reject) => {
        this.turn = { events, resolve, reject };
        proc.stdin.write(JSON.stringify({ type: "user", message: { role: "user", content: message } }) + "\n");
      });
    };
    const p = this.queue.then(run, run);
    this.queue = p.catch(() => {});
    return p;
  }
}
