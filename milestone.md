# ረዳት (Redat) — Milestones

Each milestone should leave Redat usable every day. Order is by value per effort.

## M0 — Spike ✅

- [x] Push-to-talk loop in the terminal: mic → Addis STT → Claude CLI → Addis TTS → speaker
- [x] `--text` / `--file` modes and timing per stage

## M1 — It can actually do things

Goal: say a command, and it happens on the desktop.

- [x] Give Claude shell access: replace `--tools ""` with `Bash` + `--permission-mode bypassPermissions`
- [x] System prompt describing my machine (Hyprland, PipeWire, Wayland tools available)
- [x] Command log written to `~/.local/state/redat/commands.log`
- [x] Spoken reply after the action ("ወደ workspace ሦስት ወስጄዋለሁ")
- **Done when:** "open Firefox on workspace three" works start to finish. ✅ (verified by text; voice path waits on Addis TTS + a real-mic check)

## M2 — Hands-free basics: daemon + hotkey + VAD

Goal: stop living in a terminal.

- [x] Split the spike into modules (audio, stt, tts, brain, daemon)
- [x] Daemon process listening on a Unix socket; `redat` CLI (`start`, `stop`, `listen`, `say`, `status`)
- [x] Hyprland keybind runs `redat listen` (SUPER+Y — SUPER+R was already the Todo workspace)
- [x] VAD: automatic stop on silence
- [x] Earcons for listening, thinking, done and error
- [x] systemd user service
- **Done when:** I press SUPER+Y, speak, and it acts and replies without touching a terminal. ⏳ everything verified except my real voice
- [x] Extra: TTS failure fallback (reply shown as a notification), Addis timeouts/retries, STT byte-token fix, turn log

## M3 — Fast & interruptible

Goal: feels like a conversation, not a batch job.

- [x] Stream Claude output (`--output-format stream-json`) and send each sentence to TTS as it arrives
- [x] Queue audio playback so sentences play smoothly back to back
- [x] Barge-in: the hotkey stops playback
- [x] Follow-up window after each reply
- [x] Measure and reduce the time until it starts speaking (target: < 3s)
- **Done when:** a simple question gets spoken audio in under 3 seconds, and I can cut it off.
  ✅ mostly: 2.8–3.7s from text to first audio (was ~15s); add ~2.5s for Addis STT when speaking. Barge-in verified.
- [x] Extra: persistent Claude process (first token ~1s instead of 6–10s), Addis streaming TTS (first audio ~0.8s vs ~4s)

## M4 — Wake word "ረዳት"

Goal: fully hands-free.

- [ ] Choose an engine (likely openWakeWord, which runs locally and supports custom models)
- [ ] Train a custom "ረዳት" model: synthetic samples from Addis TTS voices + my own recordings
- [ ] Always-on mic capture in the daemon, shared with VAD
- [ ] Tune false accepts and rejects; add a mute toggle via the CLI and the hotkey
- **Done when:** saying "ረዳት" from across the room reliably starts listening, and it rarely triggers when it shouldn't.

## M5 — Daily tools

- [ ] Timers, alarms and reminders
- [ ] Notes and to-dos (markdown)
- [ ] Clipboard read, translate and summarize
- [ ] Dictation mode (`wtype`)
- [ ] Screen awareness (grim + vision)
- [ ] Ethiopian calendar
- [ ] STT vocabulary fixes

## M6 — Memory & polish

- [ ] Memory file of long-term facts
- [ ] Conversation persists across restarts; "new conversation" / "forget that" commands
- [ ] Waybar status module
- [ ] Addis credit tracking + low-credit warning
- [ ] Turn replay/debug tooling

## Later

Telegram, Spotify/MPD, MCP servers, offline Whisper fallback, voice and persona choice.
