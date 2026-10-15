import { readFileSync, writeFileSync } from "node:fs";
import { randomUUID } from "node:crypto";
import { ADDIS, ADDIS_KEY, VOICE } from "./config.ts";

/**
 * POST with a timeout. Retries once on network errors, timeouts and 5xx/provider failures,
 * and keeps polling (same body, so same client_request_id) while TTS says it's still generating.
 */
async function post(path: string, init: () => RequestInit, timeoutMs: number): Promise<{ res: Response; json: any }> {
  let failures = 0;
  const deadline = Date.now() + 40_000;
  for (;;) {
    let wait = 1000;
    try {
      const res = await fetch(`${ADDIS}${path}`, { method: "POST", ...init(), signal: AbortSignal.timeout(timeoutMs) });
      const json: any = await res.json().catch(() => ({}));
      const code = json?.error?.code;
      if (code === "GENERATION_IN_PROGRESS" && Date.now() < deadline) {
        wait = 3000;
      } else {
        const transient = res.status >= 500 || code === "TTS_PROVIDER_FAILED";
        if (!transient || ++failures >= 2) return { res, json };
      }
    } catch (err) {
      if (++failures >= 2 || Date.now() > deadline) throw new Error(`Addis ${path}: ${(err as Error).message}`);
    }
    await new Promise((r) => setTimeout(r, wait));
  }
}

/** STT sometimes leaks tokenizer byte tokens ("<0xE1><0x88><0xBC>" = "ሼ"); decode them. */
export function decodeByteTokens(text: string) {
  return text.replace(/(?:<0x[0-9A-Fa-f]{2}>)+/g, (run) =>
    Buffer.from(run.match(/[0-9A-Fa-f]{2}(?=>)/g)!.map((h) => parseInt(h, 16))).toString("utf8"),
  );
}

export async function stt(wavPath: string): Promise<string> {
  const audio = readFileSync(wavPath);
  const { res, json } = await post("/v2/stt", () => {
    const form = new FormData();
    form.append("audio", new Blob([audio], { type: "audio/wav" }), "audio.wav");
    form.append("request_data", JSON.stringify({ language_code: "am" }));
    return { headers: { "x-api-key": ADDIS_KEY }, body: form };
  }, 20_000);
  if (!res.ok || json.status !== "success") throw new Error(`STT failed: ${JSON.stringify(json)}`);
  return decodeByteTokens(json.data.transcription as string);
}

/** Synthesize Amharic speech into `out` (WAV). Returns credits info if reported. */
export async function tts(text: string, out: string, format: "wav_44100" | "mp3_44100" = "wav_44100") {
  const body = JSON.stringify({
    text,
    voice_id: VOICE,
    language: "am",
    output_format: format,
    client_request_id: randomUUID(), // same id on retry, so Addis can dedupe
  });
  const { res, json } = await post("/v1/voice/generations", () => ({
    headers: { "x-api-key": ADDIS_KEY, "content-type": "application/json" },
    body,
  }), 20_000);
  if (!res.ok || !json.data) throw new Error(`TTS failed: ${JSON.stringify(json)}`);
  const { audio, audio_url, usage } = json.data;
  if (typeof audio === "string" && audio.startsWith("data:")) {
    writeFileSync(out, Buffer.from(audio.slice(audio.indexOf(",") + 1), "base64"));
  } else {
    // Idempotent replays may omit inline audio; fall back to the signed URL.
    const a = await fetch(audio_url, { headers: { "x-api-key": ADDIS_KEY }, signal: AbortSignal.timeout(30_000) });
    writeFileSync(out, Buffer.from(await a.arrayBuffer()));
  }
  return usage as { credits_used: number; credits_remaining: number; currency: string } | undefined;
}

/**
 * Streaming TTS (`mp3-frames-v1`, same protocol as the official addisai SDK): the body is a
 * series of [u32 BE length][MP3 bytes] frames, a zero length, then JSON billing metadata.
 * Calls `onAudio` with each MP3 chunk as it arrives; resolves with the usage info.
 */
export async function ttsStream(text: string, onAudio: (mp3: Buffer) => void, signal?: AbortSignal) {
  const res = await fetch(`${ADDIS}/v1/voice/generations/stream`, {
    method: "POST",
    headers: { "x-api-key": ADDIS_KEY, "content-type": "application/json" },
    body: JSON.stringify({
      text,
      voice_id: VOICE,
      language: "am",
      output_format: "mp3_44100",
      client_request_id: randomUUID(),
    }),
    signal: signal ? AbortSignal.any([signal, AbortSignal.timeout(30_000)]) : AbortSignal.timeout(30_000),
  });
  if (!res.ok || res.headers.get("x-addis-audio-protocol") !== "mp3-frames-v1" || !res.body) {
    throw new Error(`TTS stream failed (${res.status}): ${(await res.text()).slice(0, 300)}`);
  }
  let pending = Buffer.alloc(0);
  let terminal = false;
  for await (const chunk of res.body) {
    pending = Buffer.concat([pending, chunk]);
    while (!terminal && pending.length >= 4) {
      const size = pending.readUInt32BE(0);
      if (size === 0) {
        terminal = true;
        pending = pending.subarray(4);
        break;
      }
      if (pending.length < size + 4) break;
      onAudio(pending.subarray(4, 4 + size));
      pending = pending.subarray(4 + size);
    }
  }
  if (!terminal) throw new Error("TTS stream ended before completion");
  try {
    return JSON.parse(pending.toString("utf8")).data?.usage as
      | { credits_used: number; credits_remaining: number; currency: string }
      | undefined;
  } catch {
    return undefined;
  }
}
