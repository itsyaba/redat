import { spawn, execFileSync } from "node:child_process";

/**
 * pw-record args that pin capture to a non-Bluetooth mic. Recording from a Bluetooth headset's mic
 * forces it into HFP/SCO, and the always-on wake listener then made every headset connect/switch
 * renegotiate SCO, which hard-froze the PC. REDAT_MIC overrides with a source name.
 */
export function micTarget(): string[] {
  // A bare --target is only a hint: WirePlumber re-links the stream to the new default source when a
  // headset connects. These props make the pin strict (the stream errors out instead of moving).
  const pin = (n: string) => ["--target", n, "-P", "{ node.dont-reconnect = true node.dont-fallback = true node.dont-move = true }"];
  if (process.env.REDAT_MIC) return pin(process.env.REDAT_MIC);
  try {
    const run = (...a: string[]) => execFileSync("pactl", a, { encoding: "utf8", timeout: 2000 });
    const sources = run("list", "sources", "short").split("\n").map((l) => l.split("\t")[1]).filter(Boolean);
    const ok = (n: string) => !n.startsWith("bluez_") && !n.endsWith(".monitor");
    const def = run("get-default-source").trim();
    const mic = ok(def) ? def : sources.find(ok);
    if (mic) return pin(mic);
  } catch {}
  return []; // no usable non-Bluetooth mic info: fall back to the default
}

/** Start recording 16kHz mono WAV; call the returned stop() to finalize the file. */
export function startRecording(out: string) {
  const rec = spawn("pw-record", [...micTarget(), "--rate", "16000", "--channels", "1", "--format", "s16", out]);
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
