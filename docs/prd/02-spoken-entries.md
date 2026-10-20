# 02 — Robotic spoken entries

Status: implemented in [PR #9](https://github.com/harshulkuhar/dexduo/pull/9) on `codex/robotic-entries`; iPhone 18 Pro and Duo Simulator validation recorded below. Physical-device audition remains pending.

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

## Delivery notes

The scene owns `EntrySpeech`; `DexStore.spokenEntry` is populated only from successfully loaded, nonempty English text. Selection-start events cancel narration before entry fetches (including evolution metadata). Scanner results may wait for scanner dismissal; folding or backgrounding discards pending narration.

Native synthesis callbacks may arrive on the main thread. They copy PCM into a bounded asynchronous writer; engine setup, file I/O and sample processing run on the serial audio queue. Synthesis spools to a temporary CAF file, then playback reads 100 ms blocks with at most two seconds queued. An overfull preparation queue fails explicitly rather than dropping speech. Cancellation invalidates native work immediately and removes temporary audio. The output level comes from the post-effect mixer, capped at 30 updates/second; the lens visual remains a separate feature.

Simulator first-request preparation measured 2.03 seconds after a device restart, then 0.25 seconds on the same driver. A later full-suite process measured 0.90 seconds followed by 0.15 seconds. These measurements use the short “Pikachu. It stores electricity in its cheeks.” sample and do not establish physical-device latency or long-entry performance. Ring modulation, headroom and phase continuity are tested with synthetic PCM; perceived voice character and ten-entry speaker/headphone audition remain unverified.

The full phone run passed 58 unit/component tests and all 14 then-existing phone UI cases (the Duo-only case was skipped on the phone). After adding direct application/scene lifecycle coverage, all 59 unit/component tests and the two speech UI cases passed again on iPhone 18 Pro. The final settings layout adds a third speech UI case for accessibility sizes; all three pass on the phone. Duo native voice/playback, cancellation, orientation, tree and speech controls were also exercised. See the delivery checkpoint for the final Duo run.

Early native tests exposed synchronous work inside the synthesis callback and audio-engine construction before session activation; both were corrected before the passing native and lifecycle runs. On Duo, Home did not reliably background the target app (it reported foreground state 4). The background UI test now activates Settings and asserts the application is actually backgrounded before testing silent return. All five final Duo UI checks passed. Repeated actual folds and physical speaker/headphone behavior remain separate checks.
