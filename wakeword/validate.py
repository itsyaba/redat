"""Keep only positive clips where Addis STT actually hears "ረዳ…" (TTS sometimes says something else).
Results are cached in data/stt.json; rejected clips move to data/rejected/. Usage: .venv/bin/python -I validate.py"""
import json, re, shutil, uuid, urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent
DATA = HERE / "data"
KEY = dict(l.split("=", 1) for l in (HERE.parent / ".env").read_text().splitlines() if "=" in l)["ADDIS_API_KEY"].strip()
CACHE = DATA / "stt.json"


def stt(p: Path) -> str:
    b = uuid.uuid4().hex
    body = (f"--{b}\r\nContent-Disposition: form-data; name=\"audio\"; filename=\"a.wav\"\r\nContent-Type: audio/wav\r\n\r\n").encode() \
        + p.read_bytes() + (f"\r\n--{b}\r\nContent-Disposition: form-data; name=\"request_data\"\r\n\r\n"
                            + json.dumps({"language_code": "am"}) + f"\r\n--{b}--\r\n").encode()
    req = urllib.request.Request("https://api.addisassistant.com/api/v2/stt", body, {
        "x-api-key": KEY, "content-type": f"multipart/form-data; boundary={b}", "user-agent": "redat-wakeword/0.1"})
    for attempt in range(3):
        try:
            return json.load(urllib.request.urlopen(req, timeout=40))["data"]["transcription"]
        except Exception as e:
            err = e
    return f"<error {err}>"


def main():
    cache = json.loads(CACHE.read_text()) if CACHE.exists() else {}
    clips = [p for p in sorted((DATA / "pos").glob("*.wav")) if p.name not in cache]
    print(f"{len(clips)} clips to check")
    with ThreadPoolExecutor(2) as ex:
        for p, t in zip(clips, ex.map(stt, clips)):
            cache[p.name] = t
    CACHE.write_text(json.dumps(cache, ensure_ascii=False, indent=0))
    (DATA / "rejected").mkdir(exist_ok=True)
    ok = 0
    for p in sorted((DATA / "pos").glob("*.wav")):
        t = cache.get(p.name, "")
        # Oromo "Redaat" may transcribe in Latin or Ge'ez; accept either spelling of the word.
        if re.search(r"ረዳ|ሬዳ|ረደት|redaa?t", t, re.I) and not t.startswith("<error"):
            ok += 1
        else:
            shutil.move(p, DATA / "rejected" / p.name)
    print(f"kept {ok}, rejected {len(list((DATA / 'rejected').glob('*.wav')))}")


if __name__ == "__main__":
    main()
