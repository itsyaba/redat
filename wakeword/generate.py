"""Generate synthetic training audio for the "ረዳት" wake word.

Positives: "ረዳት" from every Addis Amharic voice and both Edge Amharic voices (several prosodies).
Negatives: confusable words and ordinary Amharic/English sentences from the same voices, so the
model learns the word, not the voice.

Usage: .venv/bin/python -I generate.py   (reads ADDIS_API_KEY from ../.env; idempotent, skips existing files)
"""
import base64, json, os, subprocess, sys, uuid, urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent
DATA = HERE / "data"
ENV = dict(l.split("=", 1) for l in (HERE.parent / ".env").read_text().splitlines() if "=" in l)
KEY = ENV["ADDIS_API_KEY"].strip()
API = "https://api.addisassistant.com/api"
UA = {"user-agent": "redat-wakeword/0.1"}  # the default Python-urllib agent gets 403

POSITIVE = ["ረዳት", "ረዳት!", "ረዳት?", "ረዳት።"]
# TTS often garbles a lone word, so also say it at the END of short phrases (the model looks at
# the end of the window, so a varied prefix teaches it that only the last word matters).
CARRIER = ["ሄይ ረዳት።", "እሺ ረዳት።", "ሰላም ረዳት።", "እስኪ ረዳት።", "አንተ ረዳት።"]
CONFUSABLE = ["ረዳቶች", "ረድቶኛል", "ዳዊት", "ራዳር", "ረጅም", "ረዳ", "ሪድ", "ዕዳ ነው", "ረቂቅ", "ሰዓት", "ወዳጅ", "እረዳሃለሁ"]
SENTENCES = [
    "ዛሬ የአየሩ ሁኔታ ጥሩ ነው።",
    "ቡና ጠጥተሃል ወይ?",
    "ነገ ጠዋት ስብሰባ አለኝ።",
    "እባክህ መስኮቱን ዝጋው።",
    "ልጆቹ ትምህርት ቤት ሄደዋል።",
    "ይህን ፕሮጀክት ማክሰኞ እንጨርሰዋለን።",
    "ሙዚቃውን ትንሽ ቀንሰው።",
    "አዲስ አበባ ውስጥ ብዙ ሰው ይኖራል።",
    "ምሳ ምን እንብላ?",
    "ስልኬን የት አስቀመጥኩት?",
]
ENGLISH = ["open the browser please", "what time is the meeting", "can you hear me", "let's deploy this tonight"]
EDGE_VOICES = ["am-ET-MekdesNeural", "am-ET-AmehaNeural"]
EDGE_EN = ["en-US-GuyNeural", "en-US-JennyNeural"]
PROSODY = [("+0%", "+0Hz"), ("-25%", "-8Hz"), ("+20%", "+8Hz"), ("-10%", "+15Hz"), ("+10%", "-15Hz")]


def to16k(src: Path, dst: Path):
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(src), "-ac", "1", "-ar", "16000", str(dst)], check=True)
    src.unlink()


def addis(text: str, voice: str, dst: Path):
    if dst.exists():
        return
    lang = voice.split("-", 1)[0]
    body = json.dumps({"text": text, "voice_id": voice, "language": lang, "output_format": "wav_44100",
                       "client_request_id": str(uuid.uuid4())}).encode()
    req = urllib.request.Request(f"{API}/v1/voice/generations", body,
                                 {"x-api-key": KEY, "content-type": "application/json", **UA})
    for attempt in range(3):
        try:
            data = json.load(urllib.request.urlopen(req, timeout=45))["data"]
            break
        except Exception as e:
            if attempt == 2:
                print(f"  ! addis {voice} {text!r}: {e}", file=sys.stderr)
                return
    audio = data.get("audio") or ""
    raw = base64.b64decode(audio.split(",", 1)[1]) if audio.startswith("data:") else \
        urllib.request.urlopen(urllib.request.Request(data["audio_url"], headers={"x-api-key": KEY, **UA})).read()
    tmp = dst.with_suffix(".tmp.wav")
    tmp.write_bytes(raw)
    to16k(tmp, dst)


def edge(text: str, voice: str, rate: str, pitch: str, dst: Path):
    if dst.exists():
        return
    tmp = dst.with_suffix(".tmp.mp3")
    r = subprocess.run(["uvx", "edge-tts", "--voice", voice, f"--rate={rate}", f"--pitch={pitch}",
                        "--text", text, "--write-media", str(tmp)], capture_output=True, text=True)
    if r.returncode != 0 or not tmp.exists():
        print(f"  ! edge {voice} {text!r}: {r.stderr[-200:]}", file=sys.stderr)
        return
    to16k(tmp, dst)


def main():
    catalog = json.load(urllib.request.urlopen(urllib.request.Request(
        f"{API}/v1/voice/voices", headers={"x-api-key": KEY, **UA})))["data"]
    voices = [v["id"] for v in catalog if v["language"] == "am"]
    # Tigrinya and Oromo voices are different speakers: extra speaker diversity for the same word.
    extra = [v["id"] for v in catalog if v["language"] in ("ti", "om")]
    print(f"{len(voices)} Addis Amharic voices, {len(extra)} ti/om voices")
    jobs = []
    for d in ("pos", "neg"):
        (DATA / d).mkdir(parents=True, exist_ok=True)
    for i, v in enumerate(voices):
        for j, t in enumerate(POSITIVE):
            jobs.append((addis, t, v, DATA / "pos" / f"addis-{v}-{j}.wav"))
        for j, t in enumerate(CARRIER):
            jobs.append((addis, t, v, DATA / "pos" / f"addis-{v}-c{j}.wav"))
        # Each voice: two confusables + one sentence (keeps cost low, still covers every voice).
        for k in range(2):
            c = CONFUSABLE[(i * 2 + k) % len(CONFUSABLE)]
            jobs.append((addis, c, v, DATA / "neg" / f"addis-{v}-conf{k}.wav"))
        s = SENTENCES[i % len(SENTENCES)]
        jobs.append((addis, s, v, DATA / "neg" / f"addis-{v}-sent.wav"))
    for i, v in enumerate(extra):
        word = "Redaat" if v.startswith("om-") else "ረዳት"
        for j, t in enumerate([word, word + "!", word + "?"]):
            jobs.append((addis, t, v, DATA / "pos" / f"addis-{v}-{j}.wav"))
        if v.startswith("ti-"):
            for j, t in enumerate(CARRIER[:3]):
                jobs.append((addis, t, v, DATA / "pos" / f"addis-{v}-c{j}.wav"))
        c = "Reedii" if v.startswith("om-") else CONFUSABLE[i % len(CONFUSABLE)]
        jobs.append((addis, c, v, DATA / "neg" / f"addis-{v}-conf0.wav"))
        s = "Har'a qilleensi gaarii dha." if v.startswith("om-") else "ሎሚ ሽታ ኣለዋ።"
        jobs.append((addis, s, v, DATA / "neg" / f"addis-{v}-sent.wav"))
    for v in EDGE_VOICES:
        for p, (rate, pitch) in enumerate(PROSODY):
            for j, t in enumerate(POSITIVE + CARRIER[:2]):
                jobs.append((edge, t, v, rate, pitch, DATA / "pos" / f"edge-{v}-{p}-{j}.wav"))
            for k, c in enumerate(CONFUSABLE):
                jobs.append((edge, c, v, rate, pitch, DATA / "neg" / f"edge-{v}-{p}-conf{k}.wav"))
        for k, s in enumerate(SENTENCES):
            jobs.append((edge, s, v, "+0%", "+0Hz", DATA / "neg" / f"edge-{v}-sent{k}.wav"))
    for v in EDGE_EN:
        for k, s in enumerate(ENGLISH):
            jobs.append((edge, s, v, "+0%", "+0Hz", DATA / "neg" / f"edge-{v}-en{k}.wav"))
    todo = [j for j in jobs if not j[-1].exists()]
    print(f"{len(jobs)} clips, {len(todo)} to generate")
    with ThreadPoolExecutor(6) as ex:
        for n, _ in enumerate(ex.map(lambda j: j[0](*j[1:]), todo), 1):
            if n % 25 == 0:
                print(f"  {n}/{len(todo)}")
    print("pos:", len(list((DATA / "pos").glob("*.wav"))), "neg:", len(list((DATA / "neg").glob("*.wav"))))


if __name__ == "__main__":
    main()
