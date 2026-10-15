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

## M4 — Wake word "ረዳት" ✅

Goal: fully hands-free.

- [x] Choose an engine: openWakeWord streaming speech embeddings + my own small MLP classifier (`wakeword/`)
- [x] Train a custom "ረዳት" model: synthetic samples from Addis + Edge TTS voices, confusables/negatives, background noise, and my own recordings (`redat enroll` → `redat train`, weighted ~30×)
- [x] Always-on mic capture: separate `redat-wake.service` (pw-record) that sends `wake` to the daemon; only wakes when idle so it never triggers on its own voice
- [x] Tune false accepts and rejects (2-frame confirmation + cooldown, `REDAT_WAKE_THRESHOLD`); mute toggle via `redat mute`
- **Done when:** saying "ረዳት" from across the room reliably starts listening, and it rarely triggers when it shouldn't.
  ✅ verified on recorded files; keep tuning the threshold from real-room use.

## M5 — Redat panel (see it think, control it, type to it) ✅

Goal: whenever Redat is active, a panel drops down from the top of the screen in the same style as the
Caelestia dashboard (Media/Performance tabs). It shows what Redat hears, thinks and does, and you can
control it with the mouse or keyboard.

- [x] Daemon event stream: a `subscribe` command on the socket that pushes JSON events (state changes,
      transcript, text deltas, tool calls + results, mic level, errors, timings); commands on the same connection
- [x] Separate Quickshell config (`panel/`, run as `qs -p ~/projects/redat/panel` by `redat-panel.service`),
      so Caelestia updates never break it; colours read live from `~/.local/state/caelestia/scheme.json`
- [x] Opens automatically on hotkey, wake word or `redat say`, on the focused monitor; closes 9s after going idle; pin to keep it open
- [x] Header: an animated orb for each state (listening · thinking · speaking · paused · idle · offline) + mic level bars
- [x] Conversation: what I said, and Redat's reply streaming in as it speaks (Amharic + English line)
- [x] Thought process: every command Claude runs, as collapsible rows (command, output, ✓/✗, duration)
- [x] Controls: ⏸ pause / ▶ resume speech (SIGSTOP/SIGCONT on the player), ⏹ stop, 🎤 listen,
      🔕 wake-word mute, ↺ new conversation
- [x] Text box: type a turn instead of speaking (Enter sends); toggle for spoken vs silent replies
- [x] SUPER+SHIFT+Y (`redat panel`) toggles it with keyboard focus on the text box; notifications only when the panel isn't running
- [x] Extra: reply speed (default 1.15×, ffmpeg `atempo` keeps the pitch), − / + in the panel, `redat speed`, remembered
- **Done when:** I say "ረዳት", the panel drops down, I watch the transcript and commands appear live, pause
  it mid-sentence, resume, then type a follow-up question and get an answer.
  ✅ verified with typed turns (auto-open, live commands, pause/resume, speed); the voice path waits on my mic.

## M6 — Expressive voice

Goal: it sounds like it's listening and reacting, not reading text.

- [ ] Backchannels: short "እሺ…", "እ…", "አዎ" clips played during my mid-sentence pauses (pre-generated
      with the same Addis voice, cached locally, never more than once every few seconds)
- [ ] Echo cancellation (PipeWire `echo-cancel` module) so backchannels and replies don't trigger VAD,
      barge-in or the wake word on speakers
- [ ] Reply tone: Claude tags each reply with a mood (calm · happy/excited · apologetic · serious);
      first check which Addis TTS parameters exist (voice, speed, style), else get the effect through
      wording, punctuation, voice choice and matching earcons
- [ ] Short "thinking fillers" ("ቆይ እስኪ…") when a tool call will take more than ~2s
- **Done when:** in a normal conversation it says "እሺ" naturally while I talk, without cutting me off,
  and an error reply sounds clearly different from good news.

## M7 — Meeting mode

Goal: "ረዳት, ስብሰባውን ያዝልኝ" ("record the meeting for me") and get notes at the end.

- [ ] `redat meeting start|stop` (and by voice): record mic + system audio (PipeWire monitor) for calls
- [ ] Chunked transcription while recording (Addis STT for Amharic; English parts kept as they are), with timestamps
- [ ] Summary at the end: key points, decisions, action items (who/what/when), in Amharic with an English
      line; saved as markdown in `~/Documents/redat/meetings/`
- [ ] The panel shows a recording indicator and a live transcript; wake word and replies pause while recording
- [ ] Ask about it afterwards: "ምን ተወሰነ?" ("what was decided?") answers from the saved transcript
- **Done when:** a 30-minute call produces an accurate summary with action items, without the wake word
  or replies interrupting the call.

## M8 — Daily tools

- [ ] Timers, alarms and reminders
- [ ] Notes and to-dos (markdown)
- [ ] Clipboard read, translate and summarize
- [ ] Dictation mode (`wtype`)
- [ ] Screen awareness (grim + vision)
- [ ] Ethiopian calendar
- [ ] STT vocabulary fixes

## M9 — Memory & polish

- [ ] Memory file of long-term facts, loaded automatically before each turn and updated after it
- [ ] Conversation persists across restarts; "new conversation" / "forget that" commands
- [ ] Small bar indicator in the Caelestia bar (the full status lives in the M5 panel)
- [ ] Addis credit tracking + low-credit warning (shown in the panel)
- [ ] Turn replay/debug tooling

## Later

- Telegram voice-note gateway (control the PC from my phone)
- Self-learning skills: save tasks that worked as reusable scripts
- Screen timeline: periodic screenshot + OCR, "what was I doing at 10?"
- GUI clicking when no shell command exists (screenshot → coordinates → `ydotool`)
- Fast path: handle simple commands locally (~100ms) without Claude
- Proactive briefings and alerts; background tasks that report back
- Speaker verification before running shell commands
- Offline Whisper (Amharic fine-tune) fallback; Spotify/MPD; MCP servers; voice and persona choice
- Room satellites (ESP32-S3)
