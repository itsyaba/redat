import { appendFileSync } from "node:fs";
import { COMMAND_LOG } from "./config.ts";

/** Append one JSON line per tool call Claude made, so free-running commands stay auditable. */
export function logCommand(entry: { tool: string; input: unknown; output?: string; error?: boolean }) {
  const output = entry.output && entry.output.length > 2000 ? entry.output.slice(0, 2000) + "…" : entry.output;
  appendFileSync(COMMAND_LOG, JSON.stringify({ ts: new Date().toISOString(), ...entry, output }) + "\n");
}
