// ረዳት daemon: owns the mic, the Claude session and playback; driven over a Unix socket by `redat`.
import { createServer, connect, type Socket } from "node:net";
import { appendFileSync, existsSync, rmSync, writeFileSync } from "node:fs";
import { STATE, TMP, MODEL, VOICE } from "./config.ts";
import { recordUtterance } from "./vad.ts";
import { playback } from "./audio.ts";
import { stt } from "./addis.ts";
import { Brain } from "./brain.ts";
import { Speaker } from "./speaker.ts";
import { earcon, type Earcon } from "./sounds.ts";
import { Notifier } from "./notify.ts";

export const SOCKET = `${process.env.XDG_RUNTIME_DIR ?? "/tmp"}/redat.sock`;
const IDLE_RESET_MS = 15 * 60_000; // start a fresh conversation after this much quiet
const TURN_LOG = `${STATE}/turns.log`;
const TTS_BACKOFF_MS = 5 * 60_000; // after a TTS failure, skip voice (text only) for this long
const FOLLOW_UP_MS = Number(process.env.REDAT_FOLLOW_UP_MS ?? 4000); // 0 disables the follow-up window
let ttsDownUntil = 0;
const MUTE_FILE = `${STATE}/muted`; // wake word off; survives restarts
let muted = existsSync(MUTE_FILE);
let spokeUntil = 0; // when ረዳት last finished speaking (its own "ረዳት" can still be in the detector's window)

type State = "idle" | "listening" | "thinking" | "speaking";

let state: State = "idle";
let lastTurnAt = 0;
let turns = 0;
/** Bumped by every new listen; older turns that were interrupted stop touching state/UI. */
let gen = 0;
let recorder: ReturnType<typeof recordUtterance> | undefined;
let inFollowUp = false;
let speaker: Speaker | undefined;
const brain = new Brain();
brain.warm();
const note = new Notifier();

const log = (...a: unknown[]) => console.log(new Date().toISOString().slice(11, 19), ...a);
const chime = (name: Earcon) => playback(earcon(name)).done;
function setState(s: State) {
  state = s;
  log(`state → ${s}`);
}

async function listen(followUp = false) {
  const my = ++gen;
  setState("listening");
  await chime("listen"); // before recording, so the chime isn't captured
  await new Promise((r) => setTimeout(r, 150)); // let the chime's tail/echo die out
  if (my !== gen) return;
  if (!followUp) note.show("ረዳት 🎙", "እያዳመጥኩ ነው… (listening)", 3000);
  inFollowUp = followUp;
  recorder = recordUtterance(`${TMP}/utterance.wav`, undefined, followUp ? { noSpeechMs: FOLLOW_UP_MS } : {});
  const res = await recorder.done;
  recorder = undefined;
  inFollowUp = false;
  if (my !== gen) return;
  if (res.kind !== "speech") {
    log(`no speech (${res.kind}${followUp ? ", follow-up" : ""})`);
    if (!followUp) {
      note.show("ረዳት", "ምንም አልሰማሁም (nothing heard)", 2500);
      void chime("cancel");
    }
    return setState("idle");
  }
  void chime("heard");
  log(`recorded ${res.ms}ms`);
  await turn({ wav: res.wav }, my);
}

async function turn(input: { wav?: string; text?: string }, my = ++gen) {
  setState("thinking");
  const current = () => my === gen;
  const t: Record<string, number> = {};
  const t0 = performance.now();
  const mark = (k: string) => (t[k] ??= Math.round(performance.now() - t0));
  let heard = input.text ?? "";
  let reply = "";
  let english = "";
  let error: string | undefined;
  let spoke = false;
  try {
    if (input.wav) {
      heard = (await stt(input.wav)).trim();
      mark("stt");
      if (!heard) {
        if (current()) {
          note.show("ረዳት", "ምንም አልሰማሁም (empty transcript)", 2500);
          void chime("cancel");
        }
        return;
      }
    }
    log(`heard: ${heard}`);
    if (current()) note.show("ረዳት 👂", heard, 6000);
    if (Date.now() - lastTurnAt > IDLE_RESET_MS && turns > 0) {
      log("idle too long, new conversation");
      brain.reset();
    }

    const voice = Date.now() >= ttsDownUntil;
    const sp = (speaker = new Speaker(my, (u) => u && log(`credits: ${u.credits_used} ${u.currency} (remaining ${u.credits_remaining})`)));
    sp.started.then(() => {
      mark("firstAudio");
      if (current()) setState("speaking");
    });
    ({ am: reply, en: english } = await brain.think(heard, {
      onText: (d) => {
        mark("firstToken");
        if (voice) sp.push(d);
      },
      onTool: (name, i) => log(`tool ${name}: ${i?.command ?? i?.query ?? i?.url ?? ""}`),
    }));
    mark("claude");
    log(`reply: ${reply} | ${english}`);
    if (!current()) return void sp.cancel(); // interrupted: the user already moved on
    const shown = english ? `${reply}\n${english}` : reply;
    note.show(voice ? "ረዳት 💬" : "ረዳት 💬 (no voice)", `${heard}\n\n${shown}`, voice ? 15000 : 20000);
    if (!voice) return log("TTS recently failed, replying as text only");

    sp.finish();
    await sp.done;
    spoke = sp.played;
    if (spoke) spokeUntil = Date.now();
    if (sp.error && !sp.played) {
      error = `TTS: ${sp.error.message}`;
      log(error);
      ttsDownUntil = Date.now() + TTS_BACKOFF_MS;
      note.show("ረዳት 🔇", "የድምፅ አገልግሎቱ አይሰራም (Addis TTS down) — replies are text-only for 5 min", 8000);
      await chime("error");
    } else if (sp.error) {
      error = `TTS (partial): ${sp.error.message}`;
      log(error);
    }
  } catch (err) {
    speaker?.cancel();
    error = (err as Error).message;
    log(`error: ${error}`);
    if (current()) {
      note.show("ረዳት ❌", error.slice(0, 300), 10000);
      await chime("error");
    }
  } finally {
    turns++;
    lastTurnAt = Date.now();
    log(`timings ${JSON.stringify(t)}`);
    appendFileSync(
      TURN_LOG,
      JSON.stringify({ ts: new Date().toISOString(), session: brain.sessionId, heard, reply, english, error, ms: t }) + "\n",
    );
    if (current()) {
      speaker = undefined;
      // Follow-up window: keep listening briefly so a reply doesn't need the hotkey again.
      if (spoke && FOLLOW_UP_MS > 0) start(() => listen(true));
      else setState("idle");
    }
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
      if (state === "listening" && inFollowUp && !recorder?.speaking) {
        recorder?.stop(); // hotkey during the quiet follow-up window = a fresh, normal listen
        start(listen);
        return { ok: true, msg: "listening" };
      }
      if (state === "listening") {
        recorder?.stop();
        return { ok: true, msg: "stopped recording" };
      }
      // thinking or speaking: barge in — silence the reply and listen again
      speaker?.cancel();
      start(listen);
      return { ok: true, msg: "interrupted, listening" };
    case "wake": // the wake-word detector heard "ረዳት"
      if (muted) return { ok: false, msg: "muted" };
      if (Date.now() - spokeUntil < 1500) return { ok: false, msg: "ignored (just spoke)" };
      if (state === "idle" || (state === "listening" && inFollowUp && !recorder?.speaking)) {
        log(`wake word (score ${arg ?? "?"})`);
        recorder?.stop();
        start(listen);
        return { ok: true, msg: "listening" };
      }
      // Busy: ignore, so ረዳት saying its own name (or the user saying it mid-request) can't retrigger.
      return { ok: false, msg: `ignored (${state})` };
    case "mute": {
      const want = arg === "on" ? true : arg === "off" ? false : !muted;
      if (want !== muted) {
        muted = want;
        if (muted) writeFileSync(MUTE_FILE, "");
        else rmSync(MUTE_FILE, { force: true });
        if (arg !== "on" && arg !== "off") // explicit on/off is used by scripts (enroll); stay quiet
          note.show("ረዳት", muted ? "🔕 የመቀስቀሻ ቃል ጠፍቷል (wake word off)" : "🔔 የመቀስቀሻ ቃል በርቷል (wake word on)", 3000);
      }
      return { ok: true, msg: muted ? "wake word muted" : "wake word on" };
    }
    case "say":
      if (!arg) return { ok: false, msg: "say needs text" };
      if (state === "listening") return { ok: false, msg: "busy (listening)" };
      speaker?.cancel();
      start(() => turn({ text: arg }));
      return { ok: true, msg: "accepted" };
    case "cancel":
      gen++;
      recorder?.stop();
      speaker?.cancel();
      setState("idle");
      return { ok: true, msg: `cancelled (${state})` };
    case "reset":
      brain.reset();
      return { ok: true, msg: `new conversation ${brain.sessionId}` };
    case "status":
      return {
        ok: true,
        msg: JSON.stringify({ state, muted, turns, session: brain.sessionId, model: MODEL, voice: VOICE, pid: process.pid }),
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
  speaker?.cancel();
  brain.kill();
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
