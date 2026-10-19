# 03 — Speaking lens

Status: planned. Branch: `codex/lens-flash`. Depends on spoken-entry playback.

## Requirement

The on-screen blue lens glows and pulses while DexDuo speaks. Its light should follow audible speech, including pauses, and return to the existing idle appearance when speech stops. This refers to the decorative lens, not the physical camera flash or torch.

## Behavior and implementation

Use the speech service's actual post-effect playback level. Publish an RMS envelope at no more than 30 updates per second; begin with roughly 40 ms attack and 120 ms release. Map the normalized level to a bounded cyan/white glow without changing the lens frame or hit area. Silence should settle toward idle rather than run a repeating timer animation.

The existing lens tap continues to open the scanner. Read/Stop stays a separate control. No new animation runs while idle, while synthesizing silently, or after cancellation. Fold/background/interruption clears the envelope together with the speech token, so obsolete audio buffers cannot flash the closed cover.

With Reduce Motion enabled, use a steady subtle speaking glow and no pulsing animation. Do not use full-screen flashes or fast strobing. The text-free closed cover keeps its existing appearance; narration is stopped on fold.

## Acceptance and tests

- Test silence, strong samples, clipping bounds, attack/release smoothing and cancellation using synthetic PCM data.
- Confirm lens activity tracks actual playback start/end and pauses, rather than just the synthesis callback or an arbitrary speaking timer.
- Stopping speech, opening the scanner, folding and backgrounding return the lens to idle promptly, with no late reactivation.
- The lens remains tappable; its layout does not jump as glow changes.
- Verify Reduce Motion and confirm no idle display-link/timer keeps running.

Record speaker playback and Simulator observations outside the repository. Audio/visual synchronization and the final brightness require physical-device verification.
