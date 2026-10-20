# Delivery checkpoint

Updated 2026-10-20. Local checkout: `/Users/nonu/Workspace/dexduo`.

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
- Physical iPhone camera, cutouts, touch targets and cold/warm recognition performance. No physical iPhone was connected for this delivery.
- Audition at least ten spoken entries on a physical iPhone for intelligibility, robotic character, unusual names and speaker/headphone output. Simulator first requests measured roughly 0.9–2.03 seconds and immediate warm requests roughly 0.15–0.25 seconds for the short sample; these do not verify hardware or long-entry performance. Lens brightness/synchronization remains part of the upcoming lens feature.

## Remaining feature branches

| Branch | State |
| --- | --- |
| `codex/lens-flash` | Planned |

These branches are pulled, merged with `origin/main` and pushed after each feature merge. Completed delivery branches remain as history.

## Next steps

Deliver the speaking lens through its own PR. Complete the outstanding physical-device and actual fold checks when available.

Ignored recognition test images can be restored with `python3 Tools/download_test_fixtures.py`; model weights use Git LFS. Screenshots, recordings and visual evidence remain outside Git.
