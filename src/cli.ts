// redat — control the ረዳት daemon.
import { connect } from "node:net";
import { spawnSync } from "node:child_process";
import { mkdirSync, renameSync } from "node:fs";
import { COMMAND_LOG, ROOT, STATE, TMP } from "./config.ts";
import { recordUtterance } from "./vad.ts";
import { play } from "./audio.ts";
import { earcon } from "./sounds.ts";

const SOCKET = `${process.env.XDG_RUNTIME_DIR ?? "/tmp"}/redat.sock`;
const [cmd = "help", ...rest] = process.argv.slice(2);

const USAGE = `redat — Amharic voice assistant

  redat listen        start listening (hotkey); again = stop recording; while speaking = interrupt
  redat say <text>    run a turn from typed Amharic
  redat cancel        stop listening/speaking
  redat mute [on|off] toggle the "ረዳት" wake word
  redat pause [on|off] pause/resume the spoken reply (toggle by default)
  redat speed [x]     reply speed, e.g. 1.15 (0.5–2); no value = show it
  redat panel         show/hide the panel (SUPER+SHIFT+Y)
  redat enroll [n]    record my own "ረዳት" (n times, default 15) and some normal speech
  redat train         retrain the wake word (after enroll) and restart redat-wake
  redat reset         start a new conversation
  redat status        daemon state
  redat log [-f]      commands Claude ran (JSONL)
  redat turns [-f]    turn history with timings
  redat journal       follow daemon logs
  redat daemon        run the daemon in the foreground
  redat start|stop|restart   control the systemd user services (daemon, wake word, panel)`;

function request(cmd: string, arg?: string): Promise<{ ok: boolean; msg: string } | undefined> {
  return new Promise((resolve) => {
    const sock = connect(SOCKET);
    sock.once("connect", () => sock.write(JSON.stringify({ cmd, arg }) + "\n"));
    let buf = "";
    sock.on("data", (d) => (buf += d));
    sock.once("end", () => resolve(JSON.parse(buf)));
    sock.once("error", () => resolve(undefined));
  });
}

async function send(cmd: string, arg?: string) {
  const res = await request(cmd, arg);
  if (!res) {
    console.error("redat daemon is not running (redat start, or redat daemon)");
    spawnSync("notify-send", ["-a", "Redat", "ረዳት ❌", "daemon is not running — redat start"]);
    process.exitCode = 2;
    return;
  }
  console.log(res.msg);
  process.exitCode = res.ok ? 0 : 1;
}

const WAKE = `${ROOT}wakeword`;
const NEG_PROMPTS = ["ረዳቶች ብዙ ናቸው።", "ዳዊት ዛሬ መጣ።", "ሰዓቱ ስንት ነው?", "ራዳሩ ተበላሽቷል።", "እረዳሃለሁ፣ አትጨነቅ።", "ቡና ጠጣን።"];

/** Record my own voice for the wake-word model: "ረዳት" n times, then a few confusable sentences. */
async function enroll(n: number) {
  const wasMuted = (await request("status"))?.msg.includes('"muted":true');
  await request("mute", "on"); // don't let the detector act on the samples
  const stamp = new Date().toISOString().replace(/\D/g, "").slice(0, 14);
  const take = async (prompt: string, dir: string, name: string) => {
    for (;;) {
      console.log(`  ${prompt}`);
      await play(earcon("listen"));
      const r = await recordUtterance(`${TMP}/enroll.wav`, undefined, { noSpeechMs: 6000 }).done;
      if (r.kind === "speech" && (dir === "user_neg" || r.ms < 3500)) {
        mkdirSync(`${WAKE}/data/${dir}`, { recursive: true });
        renameSync(r.wav, `${WAKE}/data/${dir}/${name}.wav`);
        await play(earcon("heard"));
        return;
      }
      console.log(r.kind === "speech" ? "    too long — just the one word, please" : "    didn't hear anything, again");
      await play(earcon("cancel"));
    }
  };
  try {
    console.log(`Say "ረዳት" after each chime, the way you'd call it (vary loudness/distance a little). ${n} times.`);
    for (let i = 1; i <= n; i++) await take(`(${i}/${n}) ረዳት`, "user", `user-${stamp}-${i}`);
    console.log("Now read each sentence after the chime (these teach it what NOT to wake on):");
    for (const [i, s] of NEG_PROMPTS.entries()) await take(s, "user_neg", `user-${stamp}-n${i}`);
    console.log("Done. Run: redat train");
  } finally {
    if (!wasMuted) await request("mute", "off");
  }
}

const tail = (file: string) =>
  spawnSync("tail", [...(rest.includes("-f") ? ["-f"] : []), "-n", "20", file], { stdio: "inherit" });

switch (cmd) {
  case "listen":
  case "cancel":
  case "reset":
  case "status":
  case "quit":
    send(cmd);
    break;
  case "say":
    send("say", rest.join(" "));
    break;
  case "mute":
  case "pause":
  case "speed":
    send(cmd, rest[0]);
    break;
  case "panel":
    process.exitCode = spawnSync("qs", ["-p", `${ROOT}panel`, "ipc", "call", "panel", "toggle"], { stdio: "inherit" }).status ?? 1;
    break;
  case "enroll":
    await enroll(Number(rest[0] ?? 15));
    break;
  case "train": {
    const r = spawnSync(`${WAKE}/.venv/bin/python`, ["-I", `${WAKE}/train.py`], { stdio: "inherit" });
    if (r.status === 0) spawnSync("systemctl", ["--user", "restart", "redat-wake.service"], { stdio: "inherit" });
    process.exitCode = r.status ?? 1;
    break;
  }
  case "daemon":
    await import("./daemon.ts");
    break;
  case "start":
  case "stop":
  case "restart":
    process.exitCode = spawnSync("systemctl", ["--user", cmd, "redat.service", "redat-wake.service", "redat-panel.service"], { stdio: "inherit" }).status ?? 1;
    break;
  case "log":
    tail(COMMAND_LOG);
    break;
  case "turns":
    tail(`${STATE}/turns.log`);
    break;
  case "journal":
    spawnSync("journalctl", ["--user", "-u", "redat", "-f", "-o", "cat"], { stdio: "inherit" });
    break;
  default:
    console.log(USAGE);
}
