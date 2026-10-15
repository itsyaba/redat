"""More speakers for free: non-Amharic Edge voices saying phonetic spellings of ረዳት.
Only clips that Addis STT hears as "ረዳ…" are kept (validate.py). Usage: .venv/bin/python -I extra_voices.py"""
import random, subprocess
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent
DATA = HERE / "data"
random.seed(3)
voices = [l.split()[0] for l in (DATA / "edge_voices.txt").read_text().splitlines() if l.strip()]
# Languages whose phonology handles "re-daat" well; a handful of voices each.
prefs = ["sw-", "so-", "ar-", "en-", "es-", "it-", "pt-", "zu-", "af-", "tr-", "hi-", "ur-", "fr-", "de-", "id-", "ms-"]
pick = []
for pfx in prefs:
    vs = [v for v in voices if v.startswith(pfx)]
    pick += random.sample(vs, min(len(vs), 4 if pfx in ("en-", "ar-", "es-") else 2))
SPELL = {"ar-": "رَدات", "hi-": "रदात", "ur-": "ردات"}
JOBS = []
for v in pick:
    word = next((w for p, w in SPELL.items() if v.startswith(p)), "Redaat")
    for j, (t, rate) in enumerate([(word, "+0%"), (word + "!", "-15%")]):
        JOBS.append((v, t, rate, DATA / "pos" / f"edgex-{v}-{j}.wav"))


def run(job):
    v, t, rate, dst = job
    if dst.exists() or (DATA / "rejected" / dst.name).exists():
        return
    tmp = dst.with_suffix(".tmp.mp3")
    r = subprocess.run(["uvx", "edge-tts", "--voice", v, f"--rate={rate}", "--text", t, "--write-media", str(tmp)],
                       capture_output=True)
    if r.returncode == 0 and tmp.exists():
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(tmp), "-ac", "1", "-ar", "16000", str(dst)], check=True)
        tmp.unlink()


print(f"{len(pick)} voices, {len(JOBS)} clips")
with ThreadPoolExecutor(6) as ex:
    list(ex.map(run, JOBS))
