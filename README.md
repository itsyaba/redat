# ረዳት (Redat)

Personal Amharic voice assistant for my Hyprland desktop: mic → Addis STT → Claude (`claude` CLI, with
Bash) → Addis TTS → speaker. See `features.md`, `milestone.md`, `plans/`.

## Use

- **SUPER+Y**, speak, then pause. It stops on silence (or press SUPER+Y again to stop early).
- SUPER+Y while it's talking interrupts it and listens again.
- Or just say **"ረዳት"** (wake word, `redat-wake.service`). It only wakes when idle, so it never
  triggers on its own voice. `redat mute` toggles it.
- `redat enroll` records my own "ረዳት" (plus a few normal sentences), then `redat train` retrains and
  restarts the detector. My recordings count about 30× more than the synthetic ones.
- **Panel** (`redat-panel.service`, Quickshell, `panel/`): drops down whenever Redat is active — live transcript,
  every command Claude runs (click for output), the reply as it streams, pause/resume, stop, listen, wake-word
  mute, new conversation, reply speed, and a text box to type instead of speaking (🔊/🔇 = spoken or silent reply).
  SUPER+SHIFT+Y (`redat panel`) opens it with the keyboard on the text box; Esc closes. Notifications are only
  used when the panel isn't running. Colours follow Caelestia's scheme.
- `redat pause [on|off]` · `redat speed 1.15` (0.5–2, via ffmpeg atempo; default 1.15, remembered)
- `redat say "ሰላም"` — typed turn · `redat status` · `redat reset` · `redat cancel`
- `redat log -f` — every command Claude ran · `redat turns` · `redat journal`
- `redat start|stop|restart` — systemd user services (`redat.service`, `redat-wake.service`, `redat-panel.service`; start with the session)
- Dev: `node src/spike.ts --no-speak --text "..." --text "..."` (multi-turn, no daemon)

Config in `.env`: `ADDIS_API_KEY` (required), `REDAT_VOICE`, `REDAT_MODEL`, `REDAT_VAD_MIN`, `REDAT_VAD_SILENCE_MS`,
`REDAT_FOLLOW_UP_MS`, `REDAT_SPEED`. Wake word: `REDAT_WAKE_THRESHOLD`, `REDAT_WAKE_DEBUG=1` (set in the service's environment).
State in `~/.local/state/redat/`.
