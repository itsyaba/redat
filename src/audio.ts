import { spawn } from "node:child_process";

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

/** Play a file; `stop()` cuts it off. `done` resolves either way. */
export function playback(path: string) {
  const p = spawn("pw-play", [path], { stdio: "ignore" });
  const done = new Promise<void>((r) => {
    p.once("exit", () => r());
    p.once("error", () => r());
  });
  return { done, stop: () => p.kill("SIGTERM") };
}

export async function play(path: string) {
  await playback(path).done;
}
