// ረዳት daemon: owns the mic, the Claude session and playback; driven over a Unix socket by `redat`.
import { createServer, connect, type Socket } from "node:net";
import { appendFileSync, rmSync } from "node:fs";
import { STATE, TMP, MODEL, VOICE } from "./config.ts";
import { recordUtterance } from "./vad.ts";
import { playback } from "./audio.ts";
import { stt, tts } from "./addis.ts";
import { Brain } from "./brain.ts";
import { earcon, type Earcon } from "./sounds.ts";
import { Notifier } from "./notify.ts";

export const SOCKET = `${process.env.XDG_RUNTIME_DIR ?? "/tmp"}/redat.sock`;
const IDLE_RESET_MS = 15 * 60_000; // start a fresh conversation after this much quiet
const TURN_LOG = `${STATE}/turns.log`;
const TTS_BACKOFF_MS = 5 * 60_000; // after a TTS failure, skip voice (text only) for this long
let ttsDownUntil = 0;

type State = "idle" | "listening" | "thinking" | "speaking";

let state: State = "idle";
let lastTurnAt = 0;
let turns = 0;
let recorder: ReturnType<typeof recordUtterance> | undefined;
let player: ReturnType<typeof playback> | undefined;
const brain = new Brain();
const note = new Notifier();

const log = (...a: unknown[]) => console.log(new Date().toISOString().slice(11, 19), ...a);
const chime = (name: Earcon) => playback(earcon(name)).done;
function setState(s: State) {
  state = s;
  log(`state → ${s}`);
}

async function listen() {
  setState("listening");
  await chime("listen"); // before recording, so the chime isn't captured
  await new Promise((r) => setTimeout(r, 150)); // let the chime's tail/echo die out
  note.show("ረዳት 🎙", "እያዳመጥኩ ነው… (listening)", 3000);
  recorder = recordUtterance(`${TMP}/utterance.wav`);
  const res = await recorder.done;
  recorder = undefined;
  if (res.kind !== "speech") {
    log(`no speech (${res.kind})`);
    note.show("ረዳት", "ምንም አልሰማሁም (nothing heard)", 2500);
    void chime("cancel");
    return setState("idle");
  }
  void chime("heard");
  log(`recorded ${res.ms}ms`);
  await turn({ wav: res.wav });
}

async function turn(input: { wav?: string; text?: string }) {
  setState("thinking");
  const t: Record<string, number> = {};
  const t0 = performance.now();
  const mark = (k: string) => (t[k] = Math.round(performance.now() - t0));
  let heard = input.text ?? "";
  let reply = "";
  let english = "";
  let error: string | undefined;
  try {
    if (input.wav) {
      heard = (await stt(input.wav)).trim();
      mark("stt");
      if (!heard) {
        note.show("ረዳት", "ምንም አልሰማሁም (empty transcript)", 2500);
        void chime("cancel");
        return;
      }
    }
    log(`heard: ${heard}`);
    note.show("ረዳት 👂", heard, 6000);
    if (Date.now() - lastTurnAt > IDLE_RESET_MS && turns > 0) {
      log("idle too long, new conversation");
      brain.reset();
    }
    ({ am: reply, en: english } = await brain.think(heard, {
      onTool: (name, i) => {
        const what = i?.command ?? i?.query ?? i?.url ?? "";
        log(`tool ${name}: ${what}`);
      },
    }));
    mark("claude");
    log(`reply: ${reply} | ${english}`);
    const shown = english ? `${reply}\n${english}` : reply;
    const out = `${TMP}/reply.wav`;
    if (Date.now() < ttsDownUntil) {
      log("TTS recently failed, replying as text only");
      note.show("ረዳት 💬 (no voice)", `${heard}\n\n${shown}`, 20000);
      return;
    }
    note.show("ረዳት 💬", `${heard}\n\n${shown}`, 15000);
    try {
      const usage = await tts(reply, out);
      mark("tts");
      if (usage) log(`credits: ${usage.credits_used} ${usage.currency} (remaining ${usage.credits_remaining})`);
    } catch (err) {
      // Voice is down: the notification already carries the reply, so just flag it.
      error = `TTS: ${(err as Error).message}`;
      log(error);
      ttsDownUntil = Date.now() + TTS_BACKOFF_MS;
      note.show("ረዳት 🔇", "የድምፅ አገልግሎቱ አይሰራም (Addis TTS down) — replies are text-only for 5 min", 8000);
      await chime("error");
      return;
    }
    setState("speaking");
    player = playback(out);
    await player.done;
    player = undefined;
  } catch (err) {
    error = (err as Error).message;
    log(`error: ${error}`);
    note.show("ረዳት ❌", error.slice(0, 300), 10000);
    await chime("error");
  } finally {
    turns++;
    lastTurnAt = Date.now();
    appendFileSync(
      TURN_LOG,
      JSON.stringify({ ts: new Date().toISOString(), session: brain.sessionId, heard, reply, english, error, ms: t }) + "\n",
    );
    setState("idle");
  }
}

/** Run a turn without blocking the socket reply; errors are already handled inside. */
function start(task: () => Promise<void>) {
  task().catch((err) => {
    log(`unexpected: ${err?.stack ?? err}`);
    setState("idle");
  });
}

function handle(cmd: string, arg: string | undefined): { ok: boolean; msg: string } {
  switch (cmd) {
    case "listen": // the hotkey: start, finish early, or interrupt speech
      if (state === "idle") {
        start(listen);
        return { ok: true, msg: "listening" };
      }
      if (state === "listening") {
        recorder?.stop();
        return { ok: true, msg: "stopped recording" };
      }
      if (state === "speaking") {
        player?.stop(); // barge-in: cut the reply, then listen
        setTimeout(() => state === "idle" && start(listen), 150);
        return { ok: true, msg: "interrupted, listening" };
      }
      note.show("ረዳት ⏳", "እያሰብኩ ነው… (busy)", 2000);
      return { ok: false, msg: "busy thinking" };
    case "say":
      if (!arg) return { ok: false, msg: "say needs text" };
      if (state !== "idle") return { ok: false, msg: `busy (${state})` };
      start(() => turn({ text: arg }));
      return { ok: true, msg: "accepted" };
    case "cancel":
      recorder?.stop();
      player?.stop();
      return { ok: true, msg: `cancelled (${state})` };
    case "reset":
      brain.reset();
      return { ok: true, msg: `new conversation ${brain.sessionId}` };
    case "status":
      return {
        ok: true,
        msg: JSON.stringify({ state, turns, session: brain.sessionId, model: MODEL, voice: VOICE, pid: process.pid }),
      };
    case "quit":
      setTimeout(shutdown, 50);
      return { ok: true, msg: "bye" };
    default:
      return { ok: false, msg: `unknown command: ${cmd}` };
  }
}

function shutdown() {
  recorder?.stop();
  player?.stop();
  server.close();
  rmSync(SOCKET, { force: true });
  process.exit(0);
}

const server = createServer((sock: Socket) => {
  let buf = "";
  sock.on("data", (d) => {
    buf += d;
    if (!buf.includes("\n")) return;
    let res;
    try {
      const { cmd, arg } = JSON.parse(buf.slice(0, buf.indexOf("\n")));
      res = handle(cmd, arg);
    } catch (err) {
      res = { ok: false, msg: `bad request: ${(err as Error).message}` };
    }
    sock.end(JSON.stringify(res) + "\n");
  });
  sock.on("error", () => {});
});

// Refuse to start twice; clear a stale socket left by a crash.
await new Promise<void>((resolve) => {
  const probe = connect(SOCKET);
  probe.once("connect", () => {
    console.error(`redat daemon already running (${SOCKET})`);
    process.exit(1);
  });
  probe.once("error", () => {
    rmSync(SOCKET, { force: true });
    resolve();
  });
});
server.listen(SOCKET, () => log(`ረዳት daemon ready on ${SOCKET} — model ${MODEL}, voice ${VOICE}`));
process.on("SIGTERM", shutdown);
process.on("SIGINT", shutdown);
