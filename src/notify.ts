import { execFile } from "node:child_process";

/**
 * Desktop notifications for a turn. Each call is a separate notification: Caelestia's popup
 * crashes ("Cannot read property 'summary' of null") when a notification replaces another,
 * so in-place updates (replaces_id / synchronous hint) never showed up.
 */
export class Notifier {
  show(summary: string, body = "", timeoutMs = 8000) {
    execFile("notify-send", ["-a", "Redat", "-t", String(timeoutMs), summary, body], () => {});
  }
}
