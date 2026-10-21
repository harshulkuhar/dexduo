# Delivery checkpoint

Updated 2026-10-21. Local checkout: `/Users/nonu/Workspace/dexduo`.

## Delivered

- [Repository](https://github.com/harshulkuhar/dexduo) and app identity: **DexDuo**.
- [PR #1](https://github.com/harshulkuhar/dexduo/pull/1): rename; merged.
- [PR #2](https://github.com/harshulkuhar/dexduo/pull/2): initial cleanup; merged.
- [PR #3](https://github.com/harshulkuhar/dexduo/pull/3): release and feature PRDs; merged.
- [PR #4](https://github.com/harshulkuhar/dexduo/pull/4): responsive type grid and shared badge colors; merged.
- [PR #5](https://github.com/harshulkuhar/dexduo/pull/5): landscape iPhone support; merged.
- [PR #6](https://github.com/harshulkuhar/dexduo/pull/6): unused helpers, conformances and redundant cover state; merged.
- [PR #7](https://github.com/harshulkuhar/dexduo/pull/7): EVO tab and scrollable Info/Stats/Evolution inside the right LCD; available Simulator checks complete. Types remains fixed. See [the updated PRD](prd/04-evolution-chains.md).
- [PR #8](https://github.com/harshulkuhar/dexduo/pull/8): removed unused evolution loading state, two forwarding view helpers and an unused screenshot-helper argument. The versioned [dead-code-removal skill](../.agents/skills/dead-code-removal/SKILL.md) is required before every PR by `AGENTS.md`.
- [PR #9](https://github.com/harshulkuhar/dexduo/pull/9): Read/Stop, persistent Auto-read and local robotic speech; see [the spoken-entry PRD and measured latency](prd/02-spoken-entries.md).

The owner authorized feature PR creation and merging. [AGENTS.md](../AGENTS.md) records the workflow: one PR per completed feature, then pull and synchronize every remaining feature branch after each merge.

## Cover-style app icon

[PR #16](https://github.com/harshulkuhar/dexduo/pull/16), branch `codex/app-icon`. Added the original red-cover AppIcon and a dependency-free Swift/Core Graphics generator (`swift Tools/render_app_icon.swift`). The universal icon is an opaque RGB 1024×1024 PNG, with system corner masking, registered in Debug and Release. The existing in-app covers are unchanged.

Simulator and unsigned Release builds pass. The icon was installed and visually inspected on iPhone 18 Pro and Duo Home Screens; the lens, lights, seam and triangle remain visible at icon size. Regeneration is byte-identical and PNG metadata confirms no alpha channel. The dead-code-removal audit found no unused code; the generator and asset registration have consumers. Only the original product icon is committed, not screenshots or reference art.

Remaining work, in order: `codex/privacy-site`, `codex/optional-tips`, `codex/app-store-showcase`. Branches are created from synchronized main when their work starts. Physical-device checks are deferred tonight.

## Prompt scanner dismissal

[PR #15](https://github.com/harshulkuhar/dexduo/pull/15), branch `codex/scanner-dismissal`. Reproduced Scan/blue lens → Done without taking a photograph on the connected Air. Four baseline runs took **10.30–10.34 seconds**. After moving preview-session disconnection from the main thread to the existing camera queue, the final four runs took **1.84–1.85 seconds** and passed the two-second regression gate. These end-to-end XCTest measurements include tap/idle handling and waiting for the entry's search field; they are not raw animation timings.

The queued operation retains the preview layer through cleanup, and teardown clears the coordinator's weak preview reference before cancelling rotation observations. Existing camera cancellation, Capture/Retake and recognition behavior remain unchanged. The blocked-camera-queue unit test verifies that stop/disconnect return immediately while native cleanup is pending.

Verification: 12 camera unit checks and both scanner UI regressions pass on iPhone 18 Pro. The signed Air Debug test and unsigned generic-iOS Release build pass. All 12 camera unit checks and three Duo UI regressions pass: fixed orientation/profile, accessible scanner controls and Import/cancel/Retake/reopening. The required dead-code-removal audit found all new declarations consumed and no additional unused code to remove. No screenshots, recordings, photographs or signing settings are committed.

## Evolution connector follow-up

[PR #14](https://github.com/harshulkuhar/dexduo/pull/14), branch `codex/evolution-connectors`. Direct evolutions keep aligned cards and use straight down arrows. Forks share a vertical trunk and long right-pointing arrows, with each requirement centered above its shaft and its destination card to the right. Sibling cards share a column, and direct stages within a branch stay aligned. The final trunk ends at the last sibling junction rather than extending through that sibling's descendants. Labels wrap and increase the row height; the arrow space scales with text size and adapts to the LCD width.

The signed build is installed on the Air. The owner confirms that Kirlia's Level 30/Gardevoir and Dawn Stone (male)/Gallade branches match the supplied sketch. The data, regional routes, artwork caches, selection/Retry and scroll restoration are unchanged.

Verification:

- **29 focused unit/component checks pass on iPhone 18 Pro**, covering connector geometry, wrapped captions, compact/notched/accessibility renders, all 19 species branch splits, form routing, offline cache, stale responses, cancellation and selection Retry.
- **All eight evolution UI cases and four additional phone regressions pass** on a dedicated iPhone 18 Pro Simulator. They cover Gastly, Eevee's eight outcomes, Kirlia/Snorunt, regional Pikachu/Geodude routes, Wurmple/Applin continuations, fixed panels, member selection/scroll retention, both landscape directions, cover/artwork retention, search, type-grid selection and scanner Import/cancel/Retake/reopening. An initial shared-Simulator launch attempt failed while another task was using that device; the final isolated run passes.
- **23 evolution unit checks and all six selected Duo UI cases pass**: fixed UIKit orientation/profile, continuing branches, Eevee traversal, Kirlia/Snorunt, separate Raichu outcomes and direct-chain selection/retained position.
- The unsigned generic-iOS Release and signed Air Debug builds pass. Phone UI screenshots and compact/accessibility renders were inspected outside Git. The required dead-code-removal skill traced all new consumers, removed the obsolete curved-arrow/uniform-indentation/decorative-trunk renderer and an unused test-helper argument; no further unused declaration qualified for deletion. Scroll anchors, cancellation, caches and accessibility identifiers retain their consumers.

Actual repeated Duo fold cycles and physical Duo verification remain pending. No screenshots, recordings or personal signing settings are included.

## Embedded camera follow-up

[PR #13](https://github.com/harshulkuhar/dexduo/pull/13), branch `codex/embedded-camera`. Scan starts the rear camera inside the existing green preview on phone and Duo. The entire frame uses aspect fit. Capture freezes and recognizes one image; Retake cancels the previous scan and resumes the preview, including while inference is pending. Import pauses capture and cancellation retains the prior live/frozen state. Done, permission Settings/Import, candidate confirmation and lookup Retry remain reachable. Accessibility sizes use shared Preview/Results pages with fixed capture controls.

The native session runs on a serial queue; Apple's rotation coordinator supplies preview and photograph angles. Generation guards reject late authorization, image and interruption callbacks. Closing, folding and backgrounding stop capture. A previously live preview resumes on foregrounding; captured/imported results stay frozen. Photographs remain in memory and are never saved automatically or uploaded. Recognition weights and thresholds are unchanged.

Verification:

- The phone suite passed all **79 unit/component cases** before the final Retake-during-inference case was added. All **11 camera cases** then passed on phone and Duo, including that additional cancellation case, permission/unavailable states, matching photo-angle forwarding, duplicate capture, capture failure/Retry, Import cancellation, stale callbacks and the actual aspect-fit native layer. A subsequent broader repeat hit a Simulator speech-preparation timeout in one native-audio case; all three native-audio cases pass on an isolated rerun after shutting down the second Simulator. All 80 distinct unit/component cases pass across these runs.
- All **14 phone UI cases pass across the broad and focused final runs**: scanner import/confirmation, automatic lookup, cancelled imports, Retake/reopening, accessible Preview/Results controls, search, type grid, retained artwork/both landscape directions and all four speech/lens cases. Two early picker waits timed out under concurrent Simulator load; focused reruns pass after waiting for actual dismissal and allowing the Photos service to populate its accessibility tree.
- On the actual Duo destination, **18 focused unit/component cases and four UI cases pass across the final runs**: fixed UIKit orientation, accessible scanner pages, repeated Import/cancel/Retake/reopening and candidate lookup. The final 11-camera/three-scanner run passes together. Early Duo attempts started with the simulated hinge closed; subsequent runs explicitly opened the device. Photos waits now account for its remote picker and tests close Done before relaunching.
- The final unsigned generic-iOS Release build passes. The phone scanner was visually inspected outside Git. Source registration, whitespace, no-media and no-personal-signing checks pass.
- The required dead-code-removal skill removed `CameraPicker`, its obsolete delegate methods, camera-sheet state, `openCamera` and a newly redundant preview forwarding property. Framework callbacks, camera/inference cancellation and existing recognition/artwork caches retain their consumers.

The signed Debug build was installed and launched on the Air. The owner confirms the embedded live preview, Capture and Retake work in both landscape directions. Real card/screen recognition accuracy, timings and longer repeated camera sessions remain pending. Actual Duo camera verification requires hardware. Simulator/mocked capture results do not establish those hardware checks. Personal Xcode signing/settings stay local and no screenshots, recordings or photographs are committed.

## Speaking lens

[PR #12](https://github.com/harshulkuhar/dexduo/pull/12), branch `codex/lens-flash`. The existing 36-point phone and 56-point Duo interior lenses now share a soft cyan halo driven by post-effect mixer audio. The envelope has a 40 ms attack and 120 ms release, with at most 30 published updates per second. Normal opacity is capped at 35%, with maximum blur of 5/8 points; Reduce Motion uses a steady 15% halo. Preparation stays idle. Stop, completion, failure and existing cancellation paths clear the light immediately. The closed cover, lens artwork, layout and scanner actions are unchanged.

Verification:

- All **69 unit/component tests pass on iPhone 18 Pro**. New coverage includes synthetic-PCM envelope timing and buffer-size equivalence, invalid levels, playback gating and render comparisons at both lens sizes. The existing recognition, type, evolution, search identity, profile/orientation and artwork tests remain green. Native engine checks verify actual nonzero output, bounded levels, publication cadence, cancellation and temporary-file cleanup.
- All **seven selected phone UI cases pass**, covering the four speech cases plus both landscape directions/retained artwork/type visibility, search and scanner import/confirmation. A final focused run passes **11 unit/component cases and two UI cases** after strengthening nonzero-level cancellation assertions and sustained-playback captures. Playback checks wait for the native engine's started event, rather than only the Stop label.
- **17 focused unit/component cases pass on the actual Duo Simulator destination. All five selected Duo UI cases pass across the initial and focused final runs**: fixed UIKit orientation/profile, accessible settings, automatic narration/scanner cancellation, unchanged speaking-lens frame/scanner action, and confirmed background cancellation. The initial background check failed because activating an already-running Settings instance left XCTest reporting DexDuo as foreground. Relaunching Settings and waiting for an actual background state resolved the test; the final run also passes the ten strengthened speech lifecycle cases.
- Idle/speaking screenshots and short playback clips from iPhone 18 Pro and the actual Duo inner display were inspected outside Git. Pixel comparisons verify the blue center and rim stay unchanged, louder levels affect only the halo, idle/preparing/stopped renders match, and Reduce Motion stays steady. No screenshots, recordings or generated audio are committed.
- The unsigned generic-iOS Release build passes. The required dead-code-removal skill traced all new consumers and project references, removing an unnecessary render-test dependency argument introduced during implementation. No unused app declaration qualified for deletion. Final whitespace, project-source and no-media checks pass; no timers, display links, settings or assets were added.

Physical-device lens brightness, perceived audio synchronization and actual repeated hinge cycles remain pending. See the [lens specification](prd/03-lens-flash.md) and outstanding checks below.

## Concise evolution labels and separate outcomes

[PR #11](https://github.com/harshulkuhar/dexduo/pull/11), branch `codex/evolution-branches`. The chart now shows one arrow and card per distinct outcome, including forms of the same species. “Thunder Stone” and “Thunder Stone (Alola)” lead to separate Raichu cards. Kirlia and Snorunt each have two arrows, retaining the male-only Gallade and female-only Froslass requirements. Shared ancestors appear once; source-form constraints keep regional continuations on the correct route.

Removed introduction-version paragraphs, redundant ordinary source/result-form prose and the family subtitle. Prefer supplied default methods per outcome; retain available requirements when no default exists. Form nodes resolve through Pokémon-form metadata to their own artwork/types. The left panel and previous/next controls use National Dex numbers, including after selecting a regional form.

Verification:

- **64 unit/component tests pass on iPhone 18 Pro.** The source cross-check covers all **19 branching-species parents** in PokéAPI’s species CSV, plus regional outcome routing, gender constraints, exact-form resolution, offline cache, selection cancellation/Retry and retained family position. JSON fixtures record retrieval URLs and the source CSV checksum.
- **All seven Evolution UI cases pass across phone runs**, including separate Raichu outcomes, Kirlia/Snorunt arrows, Geodude’s form-specific routes, Eevee traversal, standalone/uneven families, retained selection position and fixed tabs/artwork in both landscape directions. A focused final phone run also passes regional National Dex numbering/previous navigation, search and scanner import/confirmation. Compact/notched/accessibility renders pass.
- The final Duo run passes **19 evolution unit/lifecycle tests and five UI cases**: separate Raichu outcomes with exact-form selection and national-number navigation, Kirlia/Snorunt, Geodude routing, Eevee and fixed UIKit orientation.
- The final unsigned generic-iOS Release build passes. Phone and Duo captures were inspected outside Git; labels wrap inside the LCD. JSON/provenance, whitespace and no-media checks pass. No images or recordings are committed. Physical-device and repeated actual hinge checks remain pending below.
- The required dead-code-removal skill removed the old verbose conditions formatter/version accessor, historical-method rendering, family subtitle and the raw link’s unused `Identifiable` conformance. Cancellation, scene/fold behavior and image caches retain their existing paths.

## Evolution layout follow-up

[PR #10](https://github.com/harshulkuhar/dexduo/pull/10), branch `codex/evolution-inline-requirements`. Evolution families now use full-width vertical cards. Levels, stones, friendship and combined requirements appear inline; alternatives retain supplied game and form qualifiers. Removed the generic “Methods” labels, arrow instructions and separate method screen. Selecting family members still retains EVO and scroll position.

The required dead-code audit removed the unused horizontal layout chooser, linear-chain helper, short-summary fallback, method-navigation state/callbacks and column-card variants. Cache, cancellation, thumbnail and selection paths remain shared and unchanged.

Verification for this follow-up:

- All **60 unit/component tests pass on iPhone 18 Pro**, including Geodude/Alolan requirements, levels/trade, Eevee stones/friendship/alternatives, regional/unknown conditions, stale requests, offline cache and selection Retry. Compact/notched/accessibility renders include the new vertical layout.
- All **five Evolution UI cases pass across focused runs on iPhone 18 Pro**: vertical layout, direct requirements and Geodude wrapping, all eight Eevee branches, retained selection position, standalone/uneven families and fixed tabs/artwork in both landscape directions. The initial short-label width assertion measured accessibility glyph bounds; it was corrected to check containment and the case passed on rerun.
- Three additional iPhone 18 Pro UI regressions pass: cover/both directions/retained artwork and the type grid, typing/clearing/selection, and scanner import/candidate confirmation. Phone and Duo screen captures were inspected outside Git.
- Four focused checks pass on the actual Duo Simulator: Geodude inline requirements, vertical member selection/retained position, all Eevee branches with fixed Types, and fixed UIKit orientation/profile. Actual repeated hinge cycles and physical-device checks remain pending as listed below.
- The unsigned generic-iOS Release build, JSON fixture/identifier checks, final dead-code trace and whitespace/no-media checks pass.

## Previous feature verification

Xcode 27.1, with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` set per command. The primary phone destination is **DexDuo iPhone 18 Pro** on iOS 27.0; the dedicated Duo destination uses iOS 27.1.

- **59 unit/component tests pass on iPhone 18 Pro.** These include real Core ML inference, ranking/cancellation/retry, all 324 type relationships and dual-type combinations, stable search-field identity, profile latching, evolution, and speech lifecycle/effect/native-engine cases. Native audio tests verify output, warm requests, cancellation and temporary-file cleanup.
- **All 15 phone UI cases pass across the full suite and focused final runs.** They cover both landscape directions, fixed left artwork/tabs while the LCD scrolls, complete entry/Stats/abilities content, all eight Eevee branches, member selection and retained family position, the original method details, standalone/uneven families, cover/background/artwork retention, search, scanner import/confirmation, automatic recognition, Read/Stop, audio preference persistence and accessible audio settings. The Duo-only orientation case is explicitly skipped on this phone destination.
- **Five Duo UI checks pass on the actual Duo Simulator destination:** fixed UIKit orientation/profile; evolution-tree scrolling, all eight Eevee branches, member selection and the fixed Types grid; automatic/manual narration and scanner cancellation; audio settings persistence and confirmed background cancellation; and reachable settings dismissal at accessibility sizes. Native voice/engine tests and speech lifecycle tests also passed on Duo.
- Phone component renders cover 667×375, 812×375 with simulated cutout insets, larger layouts and accessibility sizes. Evolution components additionally render Gastly, Eevee, Wurmple, Applin and Ditto at compact/notched panel dimensions. These are component renders, not full device interaction tests on every phone size.
- Evolution unit tests cover default-variety identifiers, alternative and compound requirements, regional restrictions, unknown conditions, coalesced requests, cache reuse while the API is unavailable, missing thumbnails, stale completions, selection Retry and cancellation during the entry fetch. Entry data now commits together so cancellation retains the previous complete entry.
- An **unsigned Release build for generic physical iOS devices passes**. This confirms compilation, not physical-device execution.
- Offline type-chart generation consistency, project source references, whitespace and no-added-image checks pass. JSON fixtures retain source URLs and contain no image bytes.
- The subsequent dead-code cleanup reran 19 affected unit/component tests and four Evolution UI tests on iPhone 18 Pro, plus the two Duo UI checks above; all passed. The unsigned Release build and skill validator also passed. The earlier full-suite counts remain the feature baseline.

The original feature’s early UI runs exposed an identifier collision and narrow condition labels. This follow-up replaces the condition-column design entirely. Scroll automation was corrected to avoid overshooting nodes, and layout assertions now wait for native orientation transitions to settle. The passing suite includes these changes. Existing Simulator metadata/appearance diagnostics remain in logs outside Git; no test failure is treated as a pass.

## Pending validation

- At least 20 actual Duo fold/unfold cycles, including during search and recognition. The orientation UI test and simulated hinge transitions passed; repeated physical fold cycles remain unverified. The earlier DeviceHub menu automation lacked macOS assistive access, and the public simctl IO commands do not provide hinge control.
- Physical Air camera preview, Capture and Retake are owner-verified in both landscape directions; the revised evolution layout is also owner-verified. Actual card/screen recognition accuracy, cold/warm recognition performance, longer camera sessions and other hardware checks remain pending.
- Audition at least ten spoken entries on a physical iPhone for intelligibility, robotic character, unusual names and speaker/headphone output. Simulator first requests measured roughly 0.9–2.03 seconds and immediate warm requests roughly 0.15–0.25 seconds for the short sample; these do not verify hardware or long-entry performance. Speaking-lens brightness and perceived audio synchronization remain unverified on hardware.

## Remaining feature branches

`codex/embedded-camera` and `codex/evolution-connectors` are delivered through PRs #13 and #14. `codex/scanner-dismissal` is delivered through PR #15. No remaining active feature branches need synchronization after this merge. Completed branches remain as history.

## Next steps

Complete the outstanding physical-device and actual fold checks when available.

Ignored recognition test images can be restored with `python3 Tools/download_test_fixtures.py`; model weights use Git LFS. Screenshots, recordings and visual evidence remain outside Git.

## Release support website

`codex/privacy-site` adds the four static pages, a site-only Pages workflow and inline Support & About in the shared Info LCD. Local page/link validation, mobile/desktop browser inspection and keyboard focus checks pass. The support-link UI test passes on iPhone 18 Pro and Duo; the unsigned Release build passes. The initial popover design failed its visibility test and was removed in favor of the requested inline section; obsolete presentation state and dismissal controls are gone. Final dead-code audit found no additional unused declarations. Deployment HTTPS checks follow the merge.

Remaining release work: optional tips, then original App Store showcase exports. These branches will start from synchronized main. Financial account setup and physical-device validation remain owner tasks.

## Optional tips

`codex/optional-tips` adds one app-owned StoreKit manager, a local calendar/session policy and a shared support panel. The three consumables use Apple-localized prices and unlock nothing. Support & About retains manual access; verified success persists suppression before finishing transactions. Test catalog/resources are confined to test targets, and Debug-only UI-test preferences are isolated from normal installs.

Six policy/purchase tests pass on phone and Duo, including native local StoreKit repeat purchases. Phone and Duo normal/accessibility popup checks, manual access and relaunch suppression pass. Actual Simulator-display captures were inspected outside Git; XCTest landscape attachments have incorrect image metadata and are not used as visual evidence. Speech/scanner and phone keyboard regressions pass. Final narration-pause checks and the unsigned Release build are recorded in the PR. Dead-code audit removed temporary capture checkpoints; no remaining unused declarations qualify for deletion. No signing changes or captured media are included.

The support website is merged through PR #17; all four deployed HTTPS pages return 200. Optional-tip account/product setup and real-purchase/hardware checks remain pending. Showcase assets are the next feature and will start from synchronized main.
