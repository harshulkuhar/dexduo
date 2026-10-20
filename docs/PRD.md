# DexDuo product requirements

Status: all six features implemented; see individual specifications and the delivery checkpoint for Simulator checks and pending hardware validation. Updated 2026-10-20.

## Product

DexDuo is a native Pokémon companion with a red handheld interface, name search, local visual recognition and readable species information. This release adds spoken entries, a speaking lens, evolution families, defensive type matchups and a usable landscape interface on ordinary iPhones.

The name is **DexDuo**, selected by the owner. The six specifications below define the release. Verification and hardware limits are tracked in [the delivery checkpoint](DELIVERY.md).

| Feature | Specification | Branch | Dependency |
| --- | --- | --- | --- |
| Complete rename | [Branding](prd/01-branding.md) | `codex/dexduo-branding` | None |
| Landscape iPhone support | [Layout](prd/06-iphone-landscape.md) | `codex/iphone-landscape` | Rename and cleanup |
| Robotic spoken entries | [Speech](prd/02-spoken-entries.md) | `codex/robotic-entries` | Layout controls |
| Lens flash during speech | [Lens](prd/03-lens-flash.md) | `codex/lens-flash` | Speech playback state |
| Evolution chains | [Evolution](prd/04-evolution-chains.md) | `codex/evolution-chains` | Landscape details |
| Weaknesses and resistances | [Type chart](prd/05-type-matchups.md) | `codex/type-matchups` | Existing detail panel; standalone grid |

## Existing behavior to preserve

- A folded Duo shows only the text-free red cover. Opening restores the selected entry and decoded artwork without another artwork download.
- Duo folding must not request a UIKit orientation change or introduce a rotation animation. The existing fixed scene orientation and interior drawing transform are intentional.
- Search accepts a complete name, supports autocomplete, and keeps the same focused text field while the keyboard is visible.
- Info contains the English species entry, its source version, height and weight. Stats contains six base stats, their total and abilities.
- Recognition runs locally for 1,025 species through Generation 9; there is no OCR. Preserve import, camera capture, candidate confirmation, retry and obsolete-result cancellation.
- JSON and artwork caching remain available. Network failure never opens the wrong entry or dismisses a failed scan.
- No captured, imported, evaluation or reference images are committed. Screenshot evidence and audio auditions stay outside Git. Text fixtures and provenance are allowed.

## Interaction rules

The app shell, toolbar, detail tabs and artwork remain fixed. Info, Stats and Evolution scroll vertically within the right LCD, replacing detail pagination. Types shows all 18 matchups together without scrolling. Search and scanner result paging remain separate. Apple-owned Photos and camera interfaces retain their system behavior.

Ordinary iPhones run in landscape. A Duo retains its existing cover and interior behavior. Insets protect controls around camera cutouts, while the red shell fills the display. Layout uses available space instead of shrinking a tablet-sized canvas until text and buttons become unusable.

Speech is local and English in this release. A visible Read/Stop control and a persistent automatic-reading preference make playback predictable. Lens flash means the on-screen blue lens reacts to speech; it does not enable the camera torch.

## Engineering boundaries

Keep SwiftUI, the current minimum iOS 17 deployment target and the bundled recognition model. Building the current hinge implementation requires the matching Xcode/SDK, currently documented as Xcode 27.1 or later. No backend, account, cloud speech, new model training or OCR is required.

Add small, testable components for speech state, evolution decoding and type multiplication. Reuse `DexAPI`, artwork caching and request tokens. Avoid generic plugin frameworks or a broad rewrite of scanner/model code. Add new files to the explicit Xcode project references and shared test scheme.

## Delivery order and branches

1. Finish the DexDuo rename, including project/module identifiers and repository identity.
2. Remove unused code and redundant scaffolding on `codex/cleanup`; retain regression coverage.
3. Deliver these PRDs on `codex/dexduo-prds`.
4. Implement the responsive type-matchup grid first, as selected by the owner. Then implement landscape layout and evolution with contained detail scrolling, followed by speech and its lens feedback. The type grid fits the existing detail panel without waiting for the broader layout rewrite.

The preparation stack is delivered through [rename PR #1](https://github.com/harshulkuhar/dexduo/pull/1), [cleanup PR #2](https://github.com/harshulkuhar/dexduo/pull/2) and [documentation PR #3](https://github.com/harshulkuhar/dexduo/pull/3). The type grid is delivered through [PR #4](https://github.com/harshulkuhar/dexduo/pull/4). Use one PR per completed feature. After each merge, pull main, pull each remaining active feature branch, merge the latest main into it and push; also synchronize before starting implementation. See [repository guidelines](../AGENTS.md).

The owner has authorized branch work, PR creation and merging, and explicitly requested merging PRs #1–4 while Simulator checks remain pending. Xcode 27.1 is installed and iOS Simulator builds pass; the runtime is downloading. Portable tests and successful compilation do not replace iOS interaction/fold or hardware validation. Record outstanding checks accurately in each delivery.

## Release acceptance

| Area | Required evidence |
| --- | --- |
| Rename | No old app identifiers in tracked filenames, source or UI; working shared scheme, test host, LFS paths and package checksums |
| Cleanup | Removed code has no callers or has coverage in the real test target; scanner/search/fold behavior still passes |
| Layout | No clipped or unreachable controls at compact and large landscape sizes, keyboard visible and hidden, and supported text sizes |
| Speech/lens | Audible robotic treatment, offline operation, correct cancellation, synchronized light and reduced-motion behavior |
| Evolution | Complete linear and branching families; conditions, selection, contained scrolling, offline cache and failure retry |
| Types | All 18 standard attacking types visible together; correct multipliers, reference colors, matching sprite badges and explicit type-only scope |
| Regressions | Full search, import, candidate lookup, failed lookup, cached artwork and repeated fold/unfold checks |

Run the renamed `DexDuo` scheme's unit and UI suites after Xcode is ready. Test a compact landscape phone (667×375 points), a notched landscape phone (812×375 points), a current larger phone, and Duo closed/open. Use available simulator profiles or equivalent resized test configurations; do not assume a profile exists before inspecting the installed runtime. Repeat at least 20 fold/unfold cycles and both ordinary-phone landscape directions.

Hardware acceptance covers intelligible speech, audio interruptions/routes, camera behavior, usable safe areas, memory and recognition latency. Record hardware checks as pending until an actual device is used. Existing simulator rendering artifacts that also occur in Settings must be recorded separately from app regressions.

## Exclusions

No form-specific visual recognition, live scanning, crop editor, custom voice cloning, collection/team system, quiz, cloud image upload, new cover artwork or full battle simulator. The recognition benchmark and its card/screenshot limitations remain unchanged by these features. Branding does not alter upstream licenses or ownership statements.

## Resuming work

Use [the delivery checkpoint](DELIVERY.md) to find branches, review status and the next verification step. Update it in each implementation PR with tests actually run and remaining device checks. Preserve progress through normal commits and PRs; no scheduled continuation is configured.
