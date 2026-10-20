# 03 — Speaking lens

Status: implemented on `codex/lens-flash`; delivery verification is recorded in [the checkpoint](../DELIVERY.md). Depends on spoken-entry playback.

## Appearance

Keep the existing blue center, white rim and lens size. Draw a soft cyan halo behind the interior lens: normal opacity is 0–35%, with maximum blur radii of 5 points on the 36-point phone lens and 8 points on the 56-point Duo lens. Louder syllables brighten it; pauses let it fade. No text, resizing, blinking or movement is added.

Reduce Motion uses a steady 15% halo at the corresponding maximum blur throughout actual playback. Preparation stays idle. Stop returns immediately to idle. The closed cover is unchanged. The lens still opens the scanner.

## Implementation

`SystemSpeechDriver.swift` advances a per-playback exponential envelope from post-effect mixer PCM, with a 40 ms attack and 120 ms release time constant. Elapsed audio frames, rather than callback counts, determine smoothing. Existing mixer callbacks publish at no more than 30 updates per second; no timer, display link, setting or asset is added.

`EntrySpeech.swift` accepts normalized levels only while `.speaking`. Non-finite levels become zero. Existing generation guards reject callbacks after Stop, selection changes, scanner opening, cover closing, folding, backgrounding, interruption, completion or failure. Cancellation zeros the published level immediately.

`SpeakingLens.swift` provides one shared decorative background modifier. Phone and Duo pass speech state, output level and the system Reduce Motion preference. The halo does not affect layout or hit testing. The existing scanner button is identified as `scannerLens` and exposes only Idle/Speaking accessibility values; loudness changes are not announced.

## Verification

- Synthetic PCM tests cover silence, quiet/loud samples, bounds, invalid inputs, attack/release timing and equivalent envelopes for different buffer sizes.
- Speech lifecycle tests cover preparation, playback, terminal states and rejected obsolete callbacks. Native engine tests cover audible output, publication cadence, cancellation and temporary-audio cleanup.
- Render comparisons cover both lens sizes, identical idle/preparing/stopped appearance, unchanged centers and a steady Reduce Motion halo.
- Simulator interaction tests wait for the native playback event, then check Read/Stop, automatic narration, invariant scanner-control frames, scanner taps, background/cover cancellation and both ordinary-phone landscape directions. Existing search, scanner import, type-grid, retained-artwork and Duo orientation regressions remain required.

Capture phone and actual Duo inner-display evidence outside Git. An unsigned Release build verifies compilation. Physical-device lens brightness, perceived audio synchronization and repeated actual hinge cycles remain pending until tested on hardware. See the checkpoint for checks actually completed.
