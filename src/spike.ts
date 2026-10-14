// ረዳት (Redat) spike: mic → Addis STT → Claude → Addis TTS → speaker.
// Usage:
//   node src/spike.ts                 push-to-talk loop (Enter to start/stop)
//   node src/spike.ts --file in.wav   run one turn from an audio file
//   node src/spike.ts --text "ሰላም"    run one turn from typed Amharic
import { spawn, execFile } from "node:child_process";
import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { randomUUID } from "node:crypto";
import { createInterface } from "node:readline/promises";
import { promisify } from "node:util";

const execFileP = promisify(execFile);
const ROOT = new URL("..", import.meta.url).pathname;
const TMP = `${ROOT}tmp`;
mkdirSync(TMP, { recursive: true });

// --- config -----------------------------------------------------------------
function loadEnv() {
  const path = `${ROOT}.env`;
  if (!existsSync(path)) return;
  for (const line of readFileSync(path, "utf8").split("\n")) {
    const m = line.match(/^\s*([A-Z_]+)\s*=\s*(.*)\s*$/);
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2];
  }
}
loadEnv();

const ADDIS_KEY = process.env.ADDIS_API_KEY;
if (!ADDIS_KEY) throw new Error("ADDIS_API_KEY missing (put it in .env)");
const ADDIS = "https://api.addisassistant.com/api";
const VOICE = process.env.REDAT_VOICE ?? "am-hamen";
const MODEL = process.env.REDAT_MODEL ?? "sonnet";

const SYSTEM_PROMPT = `You are ረዳት (Redat), a voice assistant running on the user's Linux desktop (CachyOS + Hyprland).
The user speaks Amharic. Their words reach you through Amharic speech-to-text, which often mangles
English tech words into Ge'ez-script guesses (e.g. "workspace" may arrive as "ወርክ ቤት", "Firefox" as "ፋይርፎክስ").
Infer the intended meaning generously.

Your reply is converted to speech by an Amharic TTS engine, so:
- Reply ONLY in Amharic (Ge'ez script). Keep it short: 1–3 sentences.
- No markdown, lists, emoji, code, URLs, or file paths.
- Write numbers as Amharic words (e.g. "ሦስት", not "3").
- English names (apps, brands) are fine but keep them minimal.

You cannot control the desktop yet; if asked to do something, say in Amharic what you WOULD do.`;

// --- timing -----------------------------------------------------------------
async function timed<T>(label: string, fn: () => Promise<T>): Promise<T> {
  const t0 = performance.now();
  try {
    return await fn();
  } finally {
    console.log(`  ⏱  ${label}: ${Math.round(performance.now() - t0)}ms`);
  }
}

// --- audio I/O --------------------------------------------------------------
async function recordUntilEnter(rl: ReturnType<typeof createInterface>): Promise<string> {
  const out = `${TMP}/mic.wav`;
  const rec = spawn("pw-record", ["--rate", "16000", "--channels", "1", "--format", "s16", out]);
  await rl.question("🎙  Recording… press Enter to stop ");
  const done = new Promise((r) => rec.once("exit", r));
  rec.kill("SIGINT"); // SIGINT lets pw-record finalize the WAV header
  await done;
  return out;
}

async function play(path: string) {
  await execFileP("pw-play", [path]);
}

// --- Addis AI ---------------------------------------------------------------
async function stt(wavPath: string): Promise<string> {
  const form = new FormData();
  form.append("audio", new Blob([readFileSync(wavPath)], { type: "audio/wav" }), "audio.wav");
  form.append("request_data", JSON.stringify({ language_code: "am" }));
  const res = await fetch(`${ADDIS}/v2/stt`, {
    method: "POST",
    headers: { "x-api-key": ADDIS_KEY! },
    body: form,
  });
  const json: any = await res.json();
  if (!res.ok || json.status !== "success") throw new Error(`STT failed: ${JSON.stringify(json)}`);
  return json.data.transcription as string;
}

async function tts(text: string): Promise<string> {
  const res = await fetch(`${ADDIS}/v1/voice/generations`, {
    method: "POST",
    headers: { "x-api-key": ADDIS_KEY!, "content-type": "application/json" },
    body: JSON.stringify({
      text,
      voice_id: VOICE,
      language: "am",
      output_format: "wav_44100",
      client_request_id: randomUUID(),
    }),
  });
  const json: any = await res.json();
  if (!res.ok || !json.data) throw new Error(`TTS failed: ${JSON.stringify(json)}`);
  const { audio, audio_url, usage } = json.data;
  const out = `${TMP}/reply.wav`;
  if (typeof audio === "string" && audio.startsWith("data:")) {
    writeFileSync(out, Buffer.from(audio.slice(audio.indexOf(",") + 1), "base64"));
  } else {
    // Idempotent replays may omit inline audio; fall back to the signed URL.
    const a = await fetch(audio_url, { headers: { "x-api-key": ADDIS_KEY! } });
    writeFileSync(out, Buffer.from(await a.arrayBuffer()));
  }
  if (usage) console.log(`  💰 ${usage.credits_used} ${usage.currency} (remaining ${usage.credits_remaining})`);
  return out;
}

// --- Claude (via the claude CLI, so it runs on your subscription) -----------
const sessionId = randomUUID();
let firstTurn = true;

async function think(userText: string): Promise<string> {
  const args = [
    "-p", userText,
    "--output-format", "json",
    "--model", MODEL,
    "--system-prompt", SYSTEM_PROMPT,
    "--tools", "",
    ...(firstTurn ? ["--session-id", sessionId] : ["--resume", sessionId]),
  ];
  const { stdout } = await execFileP("claude", args, { cwd: TMP, maxBuffer: 10 * 1024 * 1024 });
  firstTurn = false;
  const json = JSON.parse(stdout);
  if (json.is_error) throw new Error(`Claude failed: ${json.result}`);
  return (json.result as string).trim();
}

// --- one conversational turn ------------------------------------------------
async function turn(input: { wav?: string; text?: string }) {
  const t0 = performance.now();
  const heard = input.text ?? (await timed("STT", () => stt(input.wav!)));
  console.log(`  👂 ${heard}`);
  const reply = await timed("Claude", () => think(heard));
  console.log(`  🤖 ${reply}`);
  const audio = await timed("TTS", () => tts(reply));
  console.log(`  ⏱  total until speech: ${Math.round(performance.now() - t0)}ms`);
  await play(audio);
}

// --- main -------------------------------------------------------------------
const argv = process.argv.slice(2);
const flag = (name: string) => {
  const i = argv.indexOf(name);
  return i >= 0 ? argv[i + 1] : undefined;
};

if (flag("--text")) {
  await turn({ text: flag("--text") });
} else if (flag("--file")) {
  await turn({ wav: flag("--file") });
} else {
  const rl = createInterface({ input: process.stdin, output: process.stdout });
  console.log(`ረዳት spike — voice ${VOICE}, model ${MODEL}. Ctrl+C to quit.\n`);
  for (;;) {
    await rl.question("⏎  Press Enter and speak Amharic ");
    const wav = await recordUntilEnter(rl);
    try {
      await turn({ wav });
    } catch (err) {
      console.error(`  ❌ ${(err as Error).message}`);
    }
    console.log();
  }
}
