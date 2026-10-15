import { spawn } from "node:child_process";
import type { Readable } from "node:stream";
import { writeFileSync } from "node:fs";
import { micTarget } from "./audio.ts";

const RATE = 16000;
const FRAME = 480; // 30ms of s16 mono

export const VAD = {
  calibrateMs: 300, // first frames estimate the noise floor
  minThreshold: Number(process.env.REDAT_VAD_MIN ?? 80), // RMS; my mic idles ~20, speech 200–2500
  floorFactor: 3.5,
  startFrames: 5, // consecutive voiced frames (150ms) before speech counts as started
  endSilenceMs: Number(process.env.REDAT_VAD_SILENCE_MS ?? 1100),
  noSpeechMs: 7000, // give up if nothing is said
  maxMs: 20000,
};

export type RecordResult =
  | { kind: "speech"; wav: string; ms: number }
  | { kind: "silence" } // nothing said before noSpeechMs
  | { kind: "cancelled" };

function rms(buf: Buffer, off: number) {
  let sum = 0;
  for (let i = 0; i < FRAME; i++) {
    const s = buf.readInt16LE(off + i * 2);
    sum += s * s;
  }
  return Math.sqrt(sum / FRAME);
}

export function wavFile(pcm: Buffer, rate = RATE): Buffer {
  const h = Buffer.alloc(44);
  h.write("RIFF", 0);
  h.writeUInt32LE(36 + pcm.length, 4);
  h.write("WAVEfmt ", 8);
  h.writeUInt32LE(16, 16);
  h.writeUInt16LE(1, 20); // PCM
  h.writeUInt16LE(1, 22); // mono
  h.writeUInt32LE(rate, 24);
  h.writeUInt32LE(rate * 2, 28);
  h.writeUInt16LE(2, 32);
  h.writeUInt16LE(16, 34);
  h.write("data", 36);
  h.writeUInt32LE(pcm.length, 40);
  return Buffer.concat([h, pcm]);
}

/**
 * Record from the mic (never a Bluetooth one, see micTarget) until the speaker goes quiet (energy VAD).
 * `stop()` ends early: keeps what was said if speech started, otherwise cancels.
 * `input` replaces the mic with a raw s16 16kHz mono stream (for tests).
 */
export function recordUtterance(
  out: string,
  input?: Readable,
  opts: { noSpeechMs?: number; onLevel?: (rms: number) => void } = {},
) {
  const noSpeechMs = opts.noSpeechMs ?? VAD.noSpeechMs;
  const rec = input
    ? { stdout: input, kill: () => input.destroy(), once: (e: string, f: () => void) => input.once(e === "exit" ? "close" : e, f) }
    : spawn("pw-record", [...micTarget(), "--rate", String(RATE), "--channels", "1", "--format", "s16", "--raw", "-"], {
        stdio: ["ignore", "pipe", "ignore"],
      });
  const chunks: Buffer[] = [];
  let pending = Buffer.alloc(0);
  let frames = 0;
  const calib: number[] = [];
  let threshold = VAD.minThreshold;
  let voicedRun = 0;
  let speechStartFrame = -1;
  let lastVoicedFrame = -1;
  let finish!: (r: RecordResult) => void;
  const done = new Promise<RecordResult>((r) => (finish = r));
  let ended = false;

  const ms = (f: number) => (f * FRAME * 1000) / RATE;
  const end = (reason: "speech" | "silence" | "cancelled") => {
    if (ended) return;
    ended = true;
    rec.kill("SIGINT");
    if (reason === "speech") {
      // Keep ~300ms before speech started so the first syllable isn't clipped.
      const from = Math.max(0, speechStartFrame - 10) * FRAME * 2;
      const pcm = Buffer.concat(chunks).subarray(from);
      writeFileSync(out, wavFile(pcm));
      finish({ kind: "speech", wav: out, ms: Math.round((pcm.length / 2 / RATE) * 1000) });
    } else finish({ kind: reason });
  };

  rec.stdout.on("data", (d: Buffer) => {
    if (ended) return;
    chunks.push(d);
    pending = Buffer.concat([pending, d]);
    while (pending.length >= FRAME * 2) {
      const level = rms(pending, 0);
      pending = pending.subarray(FRAME * 2);
      frames++;
      if (frames % 3 === 0) opts.onLevel?.(level); // ~11 Hz, for the panel's waveform
      if (ms(frames) <= VAD.calibrateMs) {
        calib.push(level);
        if (ms(frames + 1) > VAD.calibrateMs) {
          const floor = calib.sort((a, b) => a - b)[Math.floor(calib.length / 2)];
          threshold = Math.max(VAD.minThreshold, floor * VAD.floorFactor);
        }
        continue;
      }
      const inSpeech = speechStartFrame >= 0;
      const voiced = level > (inSpeech ? threshold * 0.7 : threshold);
      if (voiced) {
        lastVoicedFrame = frames;
        voicedRun++;
        if (!inSpeech && voicedRun >= VAD.startFrames) speechStartFrame = frames - voicedRun;
      } else voicedRun = 0;

      if (speechStartFrame >= 0) {
        if (ms(frames - lastVoicedFrame) >= VAD.endSilenceMs) return end("speech");
        if (ms(frames - speechStartFrame) >= VAD.maxMs) return end("speech");
      } else if (ms(frames) >= noSpeechMs) return end("silence");
    }
  });
  rec.once("exit", () => end(speechStartFrame >= 0 ? "speech" : "cancelled"));

  return {
    done,
    get speaking() {
      return speechStartFrame >= 0;
    },
    stop() {
      end(speechStartFrame >= 0 ? "speech" : "cancelled");
    },
  };
}
