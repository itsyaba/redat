"""Train the "ረዳት" wake-word classifier on openWakeWord *streaming* speech embeddings.

Training features come from the exact streaming pipeline the live detector uses (embedding whole
clips in batch gives slightly different features and caused heavy false triggers). Augmented clips
are laid out in long synthetic streams over background audio; every 80ms frame becomes an example:
  positive  = the frames just after a "ረዳት" ends (when the live detector should fire)
  ignored   = frames while the word is still being spoken, and shortly after the positive window
  negative  = everything else (other speech, confusables, partial words, noise, my recordings)

Data: data/pos, data/neg (generate.py, extra_voices.py, validate.py), data/bg, data/user (my own
voice from `redat enroll`, repeated more). Usage: .venv/bin/python -I train.py
"""
import pickle
from multiprocessing import Pool
from pathlib import Path

import numpy as np
import soundfile as sf
from sklearn.neural_network import MLPClassifier
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler

HERE = Path(__file__).resolve().parent
DATA = HERE / "data"
SR = 16000
CHUNK = 1280
FRAMES = 16
POS_AFTER = (0.0, 0.40)  # seconds after the word ends that count as "fire now"
IGNORE_AFTER = 0.8  # until then, frames are neither positive nor negative


def load(p: Path) -> np.ndarray:
    x, sr = sf.read(p, dtype="float32", always_2d=True)
    assert sr == SR, p
    return x[:, 0]


def trim(x: np.ndarray, thr=0.03) -> np.ndarray:
    idx = np.where(np.abs(x) > thr * max(1e-6, np.abs(x).max()))[0]
    return x[idx[0]: idx[-1] + 1] if len(idx) else x


def speed(x, f):
    n = int(len(x) / f)
    return np.interp(np.linspace(0, len(x) - 1, n), np.arange(len(x)), x).astype(np.float32)


def norm(x, peak):
    return x * (peak / max(1e-6, np.abs(x).max()))


def speaker(name: str) -> str:
    parts = name.split("-")
    return "-".join(parts[:3]) if parts[0] == "addis" else "-".join(parts[:4])


def make_stream(items, bg, seed):
    """Lay out (audio, label) items with background gaps; returns audio and per-frame labels (1/0/-1)."""
    rng = np.random.default_rng(seed)
    segs, events, t = [], [], 0
    def background(n):
        if rng.random() < 0.4 or not bg:
            return (rng.standard_normal(n) * rng.uniform(0.0002, 0.003)).astype(np.float32)
        src = bg[rng.integers(len(bg))]
        if len(src) < n:
            src = np.tile(src, n // len(src) + 1)
        s = rng.integers(0, len(src) - n + 1)
        return src[s: s + n] * rng.uniform(0.05, 0.35)
    negs = [a for a, label in items if label == 0 and len(a) > SR]
    for audio, label in items:
        g = int(rng.uniform(0.4, 1.8) * SR)
        segs.append(background(g)); t += g
        peak = float(np.exp(rng.uniform(np.log(0.03), np.log(0.9))))  # real mic speech peaks ~0.05–0.3
        a = norm(speed(audio, rng.uniform(0.88, 1.12)), peak)
        a = a + background(len(a))
        segs.append(a)
        events.append((t, t + len(a), label)); t += len(a)
        if label == 1 and negs and rng.random() < 0.4:
            # "ረዳት, <request>": the request starts right after the word, inside the positive window
            g = int(rng.uniform(0.1, 0.35) * SR)
            c = negs[rng.integers(len(negs))]
            c = norm(c, peak * rng.uniform(0.7, 1.2)) + background(len(c))
            segs += [background(g), c]
            events.append((t + g, t + g + len(c), 0)); t += g + len(c)
    segs.append(background(SR)); t += SR
    x = np.concatenate(segs)
    n_frames = len(x) // CHUNK
    y = np.zeros(n_frames, dtype=np.int8)
    ends = (np.arange(n_frames) + 1) * CHUNK  # sample index at the end of each frame
    for s, e, label in events:
        if label == 1:
            y[(ends > s) & (ends < e + POS_AFTER[0] * SR)] = -1
            y[(ends >= e + POS_AFTER[0] * SR) & (ends <= e + POS_AFTER[1] * SR)] = 1
            y[(ends > e + POS_AFTER[1] * SR) & (ends <= e + IGNORE_AFTER * SR)] = -1
    return (np.clip(x, -1, 1) * 32767).astype(np.int16), y


def stream_features(x: np.ndarray) -> np.ndarray:
    from openwakeword.utils import AudioFeatures
    f = AudioFeatures(ncpu=1)
    out = np.zeros((len(x) // CHUNK, FRAMES * 96), dtype=np.float32)
    for i in range(len(out)):
        f(x[i * CHUNK: (i + 1) * CHUNK])
        out[i] = f.get_features(FRAMES).reshape(-1)
    return out


def build(pos, neg, user, bg, groups, seed):
    """Items for the given speaker groups → features and labels (4 streams in parallel)."""
    rng = np.random.default_rng(seed)
    items = []
    for n, w in pos.items():
        if speaker(n) in groups:
            items += [(w, 1)] * 8 + [(w[: int(len(w) * rng.uniform(0.3, 0.55))], 0)]
    for n, w in user.items():
        if "user" in groups:
            items += [(w, 1)] * 30 + [(w[: int(len(w) * rng.uniform(0.3, 0.55))], 0)] * 2
    for n, x in neg.items():
        if speaker(n) in groups or n.startswith("user"):
            items += [(x, 0)] * 3
    order = rng.permutation(len(items))
    items = [items[i] for i in order]
    parts = [items[i::4] for i in range(4)]
    streams = [make_stream(p, bg, seed + i) for i, p in enumerate(parts)]
    with Pool(4) as pool:
        feats = pool.map(stream_features, [s[0] for s in streams])
    F = np.concatenate(feats)
    y = np.concatenate([s[1][: len(f)] for s, f in zip(streams, feats)])
    keep = y >= 0
    return F[keep], y[keep]


def model():
    return make_pipeline(StandardScaler(), MLPClassifier((128,), alpha=1e-2, max_iter=300, early_stopping=True, random_state=0))


def main():
    pos = {p.name: trim(load(p)) for p in sorted((DATA / "pos").glob("*.wav"))}
    user = {p.name: trim(load(p)) for p in sorted((DATA / "user").glob("*.wav"))}
    neg = {p.name: load(p) for p in sorted((DATA / "neg").glob("*.wav"))}
    neg |= {f"user-{p.name}": load(p) for p in sorted((DATA / "user_neg").glob("*.wav"))}
    bg = [load(p) for p in sorted((DATA / "bg").glob("*.wav"))]
    print(f"pos {len(pos)}  user {len(user)}  neg {len(neg)}  bg {len(bg)}")
    all_groups = {speaker(n) for n in list(pos) + list(neg)} | {"user"}

    speakers = sorted({speaker(n) for n in pos})
    held = set(np.random.default_rng(1).choice(speakers, max(3, len(speakers) // 5), replace=False))
    print("held-out speakers:", sorted(held))
    Ftr, ytr = build(pos, neg, user, bg, all_groups - held, 11)
    Fte, yte = build(pos, neg, user, bg, held, 12)
    print(f"train frames {len(ytr)} ({ytr.sum()} pos)  test frames {len(yte)} ({yte.sum()} pos)")
    clf = model().fit(Ftr, ytr)
    p = clf.predict_proba(Fte)[:, 1]
    for thr in (0.5, 0.7, 0.8, 0.9, 0.95):
        tp = ((p >= thr) & (yte == 1)).sum() / max(1, yte.sum())
        fp = ((p >= thr) & (yte == 0)).sum()
        print(f"  thr {thr}: positive-frame recall {tp:.3f}  false frames {fp}/{(yte == 0).sum()}")

    F, y = build(pos, neg, user, bg, all_groups, 13)
    F, y = np.concatenate([F, Ftr, Fte]), np.concatenate([y, ytr, yte])
    clf = model().fit(F, y)
    with open(HERE / "model.pkl", "wb") as f:
        pickle.dump({"clf": clf, "frames": FRAMES, "threshold": 0.85}, f)
    print(f"saved model.pkl ({len(y)} frames)")


if __name__ == "__main__":
    main()
