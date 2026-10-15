"""Always-on "ረዳት" wake-word detector. Reads the mic via pw-record and tells the Redat daemon
{"cmd": "wake"} over its Unix socket when the word is heard.

Usage:
  .venv/bin/python -I detect.py                 live (run by redat-wake.service)
  .venv/bin/python -I detect.py --file x.wav    report detections in a 16kHz mono file
Env: REDAT_WAKE_THRESHOLD (default from model.pkl), REDAT_WAKE_DEBUG=1 prints scores.
"""
import json, os, pickle, socket, subprocess, sys, time
from pathlib import Path

import numpy as np
from openwakeword.utils import AudioFeatures

HERE = Path(__file__).resolve().parent
CHUNK = 1280  # 80ms @ 16kHz, one embedding frame
SOCKET = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "redat.sock")


class Detector:
    def __init__(self):
        m = pickle.loads((HERE / "model.pkl").read_bytes())
        self.clf, self.frames = m["clf"], m["frames"]
        self.threshold = float(os.environ.get("REDAT_WAKE_THRESHOLD", m["threshold"]))
        self.feats = AudioFeatures(ncpu=1)
        self.hits = 0
        self.cooldown_until = 0.0
        self.debug = os.environ.get("REDAT_WAKE_DEBUG") == "1"

    def step(self, chunk: np.ndarray, now: float) -> float | None:
        """Feed 80ms of int16 audio; returns the score when the wake word fires."""
        self.feats(chunk)
        x = self.feats.get_features(self.frames).reshape(1, -1)
        score = float(self.clf.predict_proba(x)[0, 1])
        if self.debug and score > 0.3:
            print(f"  score {score:.2f}", flush=True)
        self.hits = self.hits + 1 if score >= self.threshold else 0
        # Two consecutive frames above threshold (or one very confident) = detection; then 2s cooldown.
        if now >= self.cooldown_until and (self.hits >= 2 or score >= 0.97):
            self.cooldown_until = now + 2.0
            self.hits = 0
            return score
        return None


def notify_daemon(score: float):
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
            s.settimeout(2)
            s.connect(SOCKET)
            s.sendall((json.dumps({"cmd": "wake", "arg": f"{score:.2f}"}) + "\n").encode())
            print(f"wake {score:.2f} → {s.recv(1024).decode().strip()}", flush=True)
    except OSError as e:
        print(f"wake {score:.2f} (daemon unreachable: {e})", flush=True)


def run_file(path: str):
    import soundfile as sf
    x, sr = sf.read(path, dtype="int16", always_2d=True)
    assert sr == 16000, "need 16kHz"
    x = x[:, 0]
    d = Detector()
    for i in range(0, len(x) - CHUNK, CHUNK):
        t = i / 16000
        s = d.step(x[i:i + CHUNK], t)
        if s is not None:
            print(f"  detection at {t:6.2f}s score {s:.2f}")
    print(f"{len(x) / 16000:.1f}s scanned")


def run_live():
    d = Detector()
    print(f"ረዳት wake word listening (threshold {d.threshold})", flush=True)
    rec = subprocess.Popen(["pw-record", "--rate", "16000", "--channels", "1", "--format", "s16", "--raw", "-"],
                           stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    try:
        while True:
            buf = rec.stdout.read(CHUNK * 2)
            if not buf or len(buf) < CHUNK * 2:
                raise SystemExit("mic stream ended")
            s = d.step(np.frombuffer(buf, dtype=np.int16), time.monotonic())
            if s is not None:
                notify_daemon(s)
    finally:
        rec.kill()


if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "--file":
        run_file(sys.argv[2])
    else:
        run_live()
