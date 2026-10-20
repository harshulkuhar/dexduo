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

The owner authorized feature PR creation and merging. [AGENTS.md](../AGENTS.md) records the workflow: one PR per completed feature, then pull and synchronize every remaining feature branch after each merge.

## Latest verification

Xcode 27.1, with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` set per command. The primary phone destination is **DexDuo iPhone 18 Pro** on iOS 27.0; the dedicated Duo destination uses iOS 27.1.

- **47 unit/component tests pass on iPhone 18 Pro.** These include real Core ML inference, ranking/cancellation/retry, all 324 type relationships and dual-type combinations, stable search-field identity, profile latching, and the new evolution cases.
- **All 12 phone UI tests pass.** They cover both landscape directions, fixed left artwork/tabs while the LCD scrolls, complete entry/Stats/abilities content, all eight Eevee branches, member selection and retained family position, method details, standalone/uneven families, cover/background/artwork retention, search, scanner import/confirmation and automatic recognition. The Duo-only orientation case is explicitly skipped on this phone destination.
- **Two Duo UI tests pass on the actual Duo Simulator destination:** fixed UIKit orientation/profile, and evolution-tree scrolling, all eight Eevee branches, member selection and the fixed Types grid.
- Phone component renders cover 667×375, 812×375 with simulated cutout insets, larger layouts and accessibility sizes. Evolution components additionally render Gastly, Eevee, Wurmple, Applin and Ditto at compact/notched panel dimensions. These are component renders, not full device interaction tests on every phone size.
- Evolution unit tests cover default-variety identifiers, alternative and compound requirements, regional restrictions, unknown conditions, coalesced requests, cache reuse while the API is unavailable, missing thumbnails, stale completions, selection Retry and cancellation during the entry fetch. Entry data now commits together so cancellation retains the previous complete entry.
- An **unsigned Release build for generic physical iOS devices passes**. This confirms compilation, not physical-device execution.
- Offline type-chart generation consistency, project source references, whitespace and no-added-image checks pass. JSON fixtures retain source URLs and contain no image bytes.

Early UI runs exposed an identifier collision and narrow condition labels; those were fixed. Scroll automation was corrected to avoid overshooting nodes, and layout assertions now wait for native orientation transitions to settle. The passing suite includes these changes. Existing Simulator metadata/appearance diagnostics remain in logs outside Git; no test failure is treated as a pass.

## Pending validation

- At least 20 actual Duo fold/unfold cycles, including during search and recognition. The orientation UI test and simulated hinge transitions passed; repeated physical fold cycles remain unverified. The earlier DeviceHub menu automation lacked macOS assistive access, and the public simctl IO commands do not provide hinge control.
- Physical iPhone camera, cutouts, touch targets and cold/warm recognition performance. No physical iPhone was connected for this delivery.
- Audio/lens audition remains part of the upcoming features.

## Remaining feature branches

| Branch | State |
| --- | --- |
| `codex/robotic-entries` | Planned |
| `codex/lens-flash` | Planned |

These branches are pulled, merged with `origin/main` and pushed after each feature merge. Completed delivery branches remain as history.

## Next steps

Deliver robotic speech, then its speaking lens, through separate PRs. Complete the outstanding physical-device and actual fold checks when available.

Ignored recognition test images can be restored with `python3 Tools/download_test_fixtures.py`; model weights use Git LFS. Screenshots, recordings and visual evidence remain outside Git.
