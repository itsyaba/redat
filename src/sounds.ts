import { existsSync, writeFileSync, mkdirSync } from "node:fs";
import { STATE } from "./config.ts";
import { wavFile } from "./vad.ts";

const RATE = 44100;
const DIR = `${STATE}/sounds`;

/** Sine tones with a soft attack/release; each note is [hz, ms]. */
function tones(notes: [number, number][], volume = 0.25): Buffer {
  const parts = notes.map(([hz, ms]) => {
    const n = Math.round((RATE * ms) / 1000);
    const b = Buffer.alloc(n * 2);
    const fade = Math.min(n / 2, RATE * 0.012);
    for (let i = 0; i < n; i++) {
      const env = Math.min(1, i / fade, (n - i) / fade);
      b.writeInt16LE(Math.round(Math.sin((2 * Math.PI * hz * i) / RATE) * env * volume * 32767), i * 2);
    }
    return b;
  });
  return wavFile(Buffer.concat(parts), RATE);
}

const EARCONS = {
  listen: () => tones([[660, 70], [990, 110]]), // rising: I'm listening
  heard: () => tones([[880, 60], [660, 90]], 0.18), // falling: got it, thinking
  error: () => tones([[330, 140], [220, 220]]),
  cancel: () => tones([[520, 90]], 0.15), // nothing heard
};
export type Earcon = keyof typeof EARCONS;

export function earcon(name: Earcon) {
  const path = `${DIR}/${name}.wav`;
  if (!existsSync(path)) {
    mkdirSync(DIR, { recursive: true });
    writeFileSync(path, EARCONS[name]());
  }
  return path;
}
