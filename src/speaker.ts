import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { readFileSync } from "node:fs";
import { TMP } from "./config.ts";
import { tts, ttsStream } from "./addis.ts";

const BOUNDARY = /[።?!፧፨\n]/;

type Usage = { credits_used: number; credits_remaining: number; currency: string } | undefined;

/** Playback speed; ffmpeg's atempo changes tempo without changing pitch. Applies from the next reply. */
export const playback = { speed: 1.15 };

/** One sentence being synthesized: MP3 chunks buffer here until it's this sentence's turn to play. */
class Clip {
  chunks: Buffer[] = [];
  done = false;
  error: Error | undefined;
  private wake: (() => void) | undefined;
  readonly abort = new AbortController();

  constructor(text: string, file: string, onUsage: (u: Usage) => void) {
    ttsStream(text, (b) => this.add(b), this.abort.signal)
      .then(onUsage)
      .catch(async (err) => {
        if (this.abort.signal.aborted) return;
        if (this.chunks.length) throw err; // failed mid-stream: keep what we have
        // Streaming unavailable: fall back to a whole-clip MP3 request.
        onUsage(await tts(text, file, "mp3_44100"));
        this.add(readFileSync(file));
      })
      .catch((err) => (this.error = err))
      .finally(() => {
        this.done = true;
        this.wake?.();
      });
  }

  private add(b: Buffer) {
    this.chunks.push(Buffer.from(b));
    this.wake?.();
  }

  /** Yield chunks as they become available until the clip is complete. */
  async *read() {
    let i = 0;
    for (;;) {
      while (i < this.chunks.length) yield this.chunks[i++];
      if (this.done) return;
      await new Promise<void>((r) => (this.wake = r));
    }
  }
}

/**
 * Speaks Claude's reply while it is still being written: each complete Amharic sentence starts
 * streaming TTS immediately (in parallel), and the MP3 audio is fed in order into one ffmpeg
 * process (tempo-adjusted, straight to PipeWire), so playback begins on the first audio chunk and sentences join without gaps.
 * Stops collecting at the "EN:" translation line, which is for the screen only.
 */
export class Speaker {
  private buf = "";
  private english = false;
  private cancelled = false;
  private paused = false;
  private finished = false;
  private n = 0;
  private clips: Clip[] = [];
  private chain: Promise<void> = Promise.resolve();
  private player: ChildProcessWithoutNullStreams | undefined;
  private playerExit: Promise<void> = Promise.resolve();
  private firstAudio: (() => void) | undefined;
  /** Resolves when the first audio starts playing. */
  readonly started = new Promise<void>((r) => (this.firstAudio = r));
  error: Error | undefined;
  played = false;

  private turnId: number;
  private onUsage: (u: Usage) => void;

  constructor(turnId: number, onUsage: (u: Usage) => void = () => {}) {
    this.turnId = turnId;
    this.onUsage = onUsage;
  }

  /** Feed streaming text from Claude. */
  push(delta: string) {
    if (this.english || this.cancelled) return;
    this.buf += delta;
    for (let m = this.buf.match(BOUNDARY); m && m.index !== undefined; m = this.buf.match(BOUNDARY)) {
      const chunk = this.buf.slice(0, m.index + 1);
      this.buf = this.buf.slice(m.index + 1);
      if (this.take(chunk)) return;
    }
  }

  /** No more text is coming: flush the remainder and let playback end after the last clip. */
  finish() {
    if (!this.english && !this.cancelled) this.take(this.buf);
    this.buf = "";
    this.finished = true;
    this.chain = this.chain.then(() => {
      this.player?.stdin.end();
      return this.playerExit;
    });
  }

  /** Returns true once the English line starts. */
  private take(chunk: string) {
    const text = chunk.trim();
    if (/^EN\s*:/.test(text)) {
      this.english = true;
      return true;
    }
    if (text && /[ሀ-፿]/.test(text)) this.say(text); // only speak Ge'ez-script text
    return false;
  }

  private ensurePlayer() {
    if (this.player) return this.player;
    // Small probe + pulse buffer keep the first-audio delay and the pause lag at ~150ms.
    const p = spawn("ffmpeg", [
      "-hide_banner", "-loglevel", "error",
      "-f", "mp3", "-probesize", "32", "-analyzeduration", "0", "-i", "pipe:0",
      "-af", `atempo=${playback.speed}`,
      "-f", "pulse", "-name", "Redat", "-buffer_duration", "150", "Redat",
    ], { stdio: ["pipe", "ignore", "ignore"] });
    p.stdin.on("error", () => {}); // killed on cancel
    this.playerExit = new Promise((r) => {
      p.once("exit", () => r());
      p.once("error", () => r());
    });
    this.player = p;
    return p;
  }

  private say(text: string) {
    const clip = new Clip(text, `${TMP}/reply-${this.turnId}-${this.n++}.mp3`, this.onUsage);
    this.clips.push(clip);
    this.chain = this.chain.then(async () => {
      for await (const b of clip.read()) {
        if (this.cancelled) return;
        const p = this.ensurePlayer();
        if (this.paused) p.kill("SIGSTOP"); // paused before the first audio arrived
        this.played = true;
        this.firstAudio?.();
        if (!p.stdin.write(b)) await new Promise((r) => p.stdin.once("drain", r));
      }
      if (clip.error && !this.error) this.error = clip.error;
    });
  }

  /** Resolves when all audio has played (call after finish()). */
  get done() {
    return this.chain;
  }

  get spokeAnything() {
    return this.n > 0;
  }

  /** Freeze playback (SIGSTOP the player); synthesis keeps buffering meanwhile. */
  pause() {
    if (this.paused || this.cancelled) return false;
    this.paused = true;
    this.player?.kill("SIGSTOP");
    return true;
  }

  resume() {
    if (!this.paused) return false;
    this.paused = false;
    this.player?.kill("SIGCONT");
    return true;
  }

  get isPaused() {
    return this.paused;
  }

  cancel() {
    this.cancelled = true;
    if (this.paused) this.player?.kill("SIGCONT"); // a stopped process can't act on SIGTERM
    for (const c of this.clips) c.abort.abort();
    this.player?.kill();
  }
}
