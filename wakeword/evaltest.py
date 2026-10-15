"""Held-out acoustic test: new sentences (never trained on) and new "ረዳት" takes, mixed at realistic
levels over a real room recording, run through the live detector. Reports wakes on negatives
(false triggers) and missed positives. Usage: .venv/bin/python -I evaltest.py [room.wav]
"""
import subprocess, sys
from pathlib import Path

import numpy as np
import soundfile as sf

sys.path.insert(0, str(Path(__file__).resolve().parent))
from detect import Detector, CHUNK  # noqa: E402

HERE = Path(__file__).resolve().parent
EVAL = HERE / "data" / "eval"
NEG = ["ትናንት ማታ ዝናብ ዘንቦ ነበር።", "እህቴ ነገ ከአዳማ ትመጣለች።", "ይህ ኮምፒውተር በጣም ቀርፋፋ ነው።",
       "ገበያ ሄጄ ቲማቲም ገዛሁ።", "የእግር ኳስ ጨዋታው ስንት ሰዓት ይጀምራል?", "ዳቦ ቤቱ ዛሬ ዝግ ነው።",
       "ረዳቶቹ ስራቸውን ጨርሰዋል።", "መምህሩ ለተማሪዎቹ የቤት ስራ ሰጣቸው።", "ሬዲዮውን አጥፋው።", "ደብዳቤውን ልኬዋለሁ።"]
POS = ["ረዳት", "ረዳት፣ ስማኝ", "እሺ ረዳት"]
VOICES = [("am-ET-MekdesNeural", "+0%"), ("am-ET-AmehaNeural", "+0%"), ("am-ET-MekdesNeural", "-15%"), ("am-ET-AmehaNeural", "+15%")]


def clip(text, voice, rate, name):
    wav = EVAL / f"{name}.wav"
    if not wav.exists():
        mp3 = wav.with_suffix(".mp3")
        subprocess.run(["uvx", "edge-tts", "--voice", voice, f"--rate={rate}", "--text", text, "--write-media", str(mp3)],
                       check=True, capture_output=True)
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(mp3), "-ac", "1", "-ar", "16000", str(wav)], check=True)
        mp3.unlink()
    return sf.read(wav, dtype="float32")[0]


def main():
    EVAL.mkdir(parents=True, exist_ok=True)
    room = sf.read(sys.argv[1] if len(sys.argv) > 1 else HERE / "data/bg/mictest.wav", dtype="float32")[0]
    rng = np.random.default_rng(0)
    items = []
    for vi, (v, r) in enumerate(VOICES):
        items += [(clip(t, v, r, f"neg-{vi}-{i}"), 0, t) for i, t in enumerate(NEG)]
        items += [(clip(t, v, r, f"pos-{vi}-{i}"), 1, t) for i, t in enumerate(POS)]
    items = [items[i] for i in rng.permutation(len(items))]
    segs, events, t = [], [], 0
    for a, label, text in items:
        gap = int(rng.uniform(1.5, 3) * 16000)
        peak = float(np.exp(rng.uniform(np.log(0.04), np.log(0.4))))
        segs += [np.zeros(gap, np.float32), a * (peak / np.abs(a).max())]
        events.append((t + gap, t + gap + len(a), label, text, peak)); t += gap + len(a)
    x = np.concatenate(segs + [np.zeros(32000, np.float32)])
    bg = np.tile(room, len(x) // len(room) + 1)[: len(x)]
    x = np.clip(x + bg, -1, 1)
    x16 = (x * 32767).astype(np.int16)
    d = Detector()
    fires = []
    for i in range(0, len(x16) - CHUNK, CHUNK):
        s = d.step(x16[i:i + CHUNK], i / 16000)
        if s is not None:
            fires.append(i + CHUNK)
    hit = set()
    false = []
    for f in fires:
        ev = next((e for e in events if e[0] <= f <= e[1] + 16000), None)
        if ev and ev[2] == 1: hit.add(ev[0])
        else: false.append((f / 16000, ev[3] if ev else "(silence)", ev[4] if ev else 0))
    npos = sum(e[2] for e in events)
    print(f"threshold {d.threshold}: detected {len(hit)}/{npos} positives, {len(false)} false wakes in {len(x)/16000/60:.1f} min")
    for f, text, peak in false: print(f"  false at {f:6.1f}s  peak {peak:.2f}  {text}")
    for e in events:
        if e[2] == 1 and e[0] not in hit: print(f"  missed  {e[3]}  peak {e[4]:.2f}")


if __name__ == "__main__":
    main()
