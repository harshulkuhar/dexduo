# 02 — Robotic spoken entries

Status: planned. Branch: `codex/robotic-entries`. Depends on the landscape layout controls.

## Experience

When the user selects a Pokémon through search, scan, previous/next or evolution, DexDuo can read its name and the English entry already shown in Info. Add a clearly labeled Read/Stop button and a persistent Auto-read switch in a compact audio settings panel. Auto-read defaults on; initial launch, reopening after a fold and background refresh remain silent. The first explicit selection can start narration.

Manual Read works regardless of the Auto-read preference. Stop cancels immediately. Tapping Read again starts from the beginning. Narration reads the whole entry even when its visual presentation extends beyond the LCD viewport. Do not speak measurement/stat labels, source-version labels, loading text or error placeholders.

## Audio implementation

Use an installed English system voice and local synthesis. Produce PCM through `AVSpeechSynthesizer.write(_:toBufferCallback:)`, then apply a restrained robotic effect for playback through `AVAudioEngine`. Start with a fixed ring modulation around 70 Hz at approximately 25% wet mix plus conservative rate/pitch tuning; audition and adjust for intelligibility. Changing pitch alone is not sufficient evidence of robotic timbre. No downloaded character voice or network TTS is required.

Prefer an installed en-US voice, then another installed English voice. Do not require an enhanced/novelty voice pack. If no usable voice or audio engine is available, leave the text usable and show an actionable audio error. No repeated automatic retry loop.

Expose a small main-actor playback model with idle, preparing, speaking and failed states, the active entry token, and a normalized output audio level for the lens feature. Keep synthesis and sample processing off the main thread; bound queued PCM to approximately two seconds and discard buffers from obsolete tokens. Audio-session configuration must permit playback, handle route changes/interruption and avoid permanently taking over other audio.

## Lifecycle

- A new selection cancels earlier preparation/playback before its own entry is available. Only the latest successful selection may speak.
- Require an explicit entry-ready state in `DexStore`; an error string must never be mistaken for a valid entry. Missing English text disables Read with an explanation.
- Stop on fold, scanner presentation, app backgrounding, audio interruption and explicit Stop. Unfolding/foregrounding never silently resumes speech.
- A tab change or entry-page change does not restart narration.
- Suppress automatic narration while VoiceOver is active; manual Read remains available. Settings and controls expose accessible names and current playback state.

## Acceptance and tests

Unit tests use injected synthesis/playback to cover latest-selection wins, missing entries, disabled Auto-read, initial-launch silence, stop/fold/background cancellation and interruption. Test buffered late callbacks and a failed engine start. No production test flag should bypass these rules.

Simulator checks confirm Read/Stop, preference persistence and no layout overflow. On a physical iPhone, audition at least ten entries with short/long text and unusual names; assess intelligibility, robotic character, pronunciation limitations and output through speaker/headphones. Target cached-entry playback beginning within one second; record actual latency rather than promise it before measurement.

No generated audio files are committed. Record audition outcomes as text. Native pronunciation of some species names may remain imperfect; do not silently replace the displayed entry with invented wording.

## Source

[Apple: writing synthesized speech to audio buffers](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer/write(_:tobuffercallback:)). The processing and lifecycle rules above are DexDuo design decisions.
