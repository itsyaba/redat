import { execFile } from "node:child_process";

/** One desktop notification that is updated in place across a turn. */
export class Notifier {
  private id: string | undefined;

  show(summary: string, body = "", timeoutMs = 8000) {
    const args = ["-a", "Redat", "-p", "-t", String(timeoutMs), "-h", "string:x-canonical-private-synchronous:redat"];
    if (this.id) args.push("-r", this.id);
    execFile("notify-send", [...args, summary, body], (err, stdout) => {
      if (!err && stdout.trim()) this.id = stdout.trim();
    });
  }
}
