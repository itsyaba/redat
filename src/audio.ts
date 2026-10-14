import { spawn, execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileP = promisify(execFile);

/** Start recording 16kHz mono WAV; call the returned stop() to finalize the file. */
export function startRecording(out: string) {
  const rec = spawn("pw-record", ["--rate", "16000", "--channels", "1", "--format", "s16", out]);
  return {
    async stop() {
      const done = new Promise((r) => rec.once("exit", r));
      rec.kill("SIGINT"); // SIGINT lets pw-record finalize the WAV header
      await done;
      return out;
    },
  };
}

export async function play(path: string) {
  await execFileP("pw-play", [path]);
}
