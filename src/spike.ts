// ረዳት (Redat) spike: mic → Addis STT → Claude (with desktop control) → Addis TTS → speaker.
// Usage:
//   node src/spike.ts                 push-to-talk loop (Enter to start/stop)
//   node src/spike.ts --file in.wav   run one turn from an audio file
//   node src/spike.ts --text "ሰላም"    run one turn from typed Amharic (repeat --text for more turns)
//   add --no-speak to skip TTS + playback
import { createInterface } from "node:readline/promises";
import { MODEL, VOICE, TMP } from "./config.ts";
import { startRecording, play } from "./audio.ts";
import { stt, tts } from "./addis.ts";
import { Brain } from "./brain.ts";

async function timed<T>(label: string, fn: () => Promise<T>): Promise<T> {
  const t0 = performance.now();
  try {
    return await fn();
  } finally {
    console.log(`  ⏱  ${label}: ${Math.round(performance.now() - t0)}ms`);
  }
}

const argv = process.argv.slice(2);
const flag = (name: string) => {
  const i = argv.indexOf(name);
  return i >= 0 ? argv[i + 1] : undefined;
};
const speak = !argv.includes("--no-speak");
const brain = new Brain();

async function turn(input: { wav?: string; text?: string }) {
  const t0 = performance.now();
  const heard = input.text ?? (await timed("STT", () => stt(input.wav!)));
  console.log(`  👂 ${heard}`);
  const { am: reply, en } = await timed("Claude", () =>
    brain.think(heard, {
      onTool: (name, i) => console.log(`  🔧 ${name}: ${i?.command ?? i?.query ?? i?.url ?? JSON.stringify(i)}`),
    }),
  );
  console.log(`  🤖 ${reply}`);
  if (en) console.log(`  🇬🇧 ${en}`);
  if (!speak) return;
  const out = `${TMP}/reply.wav`;
  const usage = await timed("TTS", () => tts(reply, out));
  if (usage) console.log(`  💰 ${usage.credits_used} ${usage.currency} (remaining ${usage.credits_remaining})`);
  console.log(`  ⏱  total until speech: ${Math.round(performance.now() - t0)}ms`);
  await play(out);
}

const texts = argv.flatMap((a, i) => (a === "--text" ? [argv[i + 1]] : []));
if (texts.length) {
  for (const text of texts) await turn({ text }); // several --text = one multi-turn conversation
} else if (flag("--file")) {
  await turn({ wav: flag("--file") });
} else {
  const rl = createInterface({ input: process.stdin, output: process.stdout });
  console.log(`ረዳት spike — voice ${VOICE}, model ${MODEL}. Ctrl+C to quit.\n`);
  for (;;) {
    await rl.question("⏎  Press Enter and speak Amharic ");
    const rec = startRecording(`${TMP}/mic.wav`);
    await rl.question("🎙  Recording… press Enter to stop ");
    try {
      await turn({ wav: await rec.stop() });
    } catch (err) {
      console.error(`  ❌ ${(err as Error).message}`);
    }
    console.log();
  }
}
