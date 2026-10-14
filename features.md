# ረዳት (Redat) — Features

A personal Amharic voice assistant for my own desktop (CachyOS + Hyprland).
Pipeline: mic → Addis STT → Claude (via `claude` CLI) → Addis TTS → speaker.

## Principles

- **Just for me.** No packaging, onboarding, or multi-user support. Settings live in `.env` / config files.
- **Claude through the `claude` CLI.** Runs on my subscription, not paid API calls.
- **Runs freely.** Claude gets full shell access with no confirmation prompts. Every command it runs is logged so I can review it.
- **Amharic in, Amharic out.** English app and brand names are fine. Replies are short and written to be spoken.

## 1. Voice I/O

- [ ] **Hotkey trigger:** a Hyprland keybind (`bind = SUPER, R, exec, ...`) signals the daemon to start listening
- [ ] **Wake word "ረዳት":** always listening locally, with no audio leaving the machine until the word triggers
- [ ] **End-of-speech detection (VAD):** stop recording automatically on silence, no second key press
- [ ] **Barge-in:** the hotkey or the wake word stops TTS playback and starts listening again
- [ ] **Earcons:** short sounds for listening, thinking, done and error
- [ ] **Streaming replies:** send Claude's output to TTS sentence by sentence to cut the wait before it starts speaking
- [ ] **Follow-up window:** after a reply, keep listening for a few seconds without needing the wake word again
- [ ] **STT vocabulary fixes:** a custom word list that maps common mistakes (e.g. "ፋይርፎክስ" → Firefox)

## 2. Desktop control (Claude runs commands freely)

- [ ] **Hyprland:** workspaces, focus/move/close/fullscreen windows, layouts (`hyprctl`)
- [ ] **Apps:** launch and close apps, open URLs and files
- [ ] **System:** volume, mic mute, brightness, media controls (`playerctl`), Wi-Fi/Bluetooth, battery, lock, suspend
- [ ] **Clipboard:** read it aloud, translate it, summarize it (`wl-paste` / `wl-copy`)
- [ ] **Screen awareness:** "what's on my screen?" using a screenshot (`grim`) and Claude vision
- [ ] **Dictation mode:** type what I say into the focused window (`wtype`)
- [ ] **Command log:** every shell command Claude runs, with timestamp and output, written to a log file

## 3. Knowledge & productivity

- [ ] General Q&A in Amharic
- [ ] Web search and fetch: news, weather, ETB exchange rates
- [ ] Timers, alarms and reminders (systemd timers + `notify-send` + spoken alert)
- [ ] Notes and to-dos by voice, saved as markdown files
- [ ] Amharic ⇄ English translation, for speech and for selected text
- [ ] Ethiopian calendar: today's date, holidays, converting dates between calendars

## 4. Memory

- [ ] Remembers facts about me across sessions (a memory file Claude reads and writes)
- [ ] Persistent conversation history across daemon restarts
- [ ] "Forget that" and "new conversation" voice commands

## 5. Runtime & UX

- [ ] **Daemon:** a long-running process, started as a systemd user service
- [ ] **CLI:** `redat start|stop|listen|say "text"|log|status`. `redat listen` is what the hotkey calls.
- [ ] **Status indicator:** a waybar module showing idle, listening, thinking or speaking
- [ ] **Usage tracking:** Addis credits per turn and a running total, with a warning when credits run low
- [ ] **Turn replay/debug:** save each turn's audio, transcript, reply and timings

## 6. Later / maybe

- [ ] Telegram: read and send messages by voice
- [ ] Spotify/MPD control
- [ ] MCP servers for extra tools
- [ ] Offline STT fallback (local Whisper) when Addis is down
- [ ] Choice of voice and persona
