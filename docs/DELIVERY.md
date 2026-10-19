# Delivery checkpoint

Updated 2026-10-20. Local checkout: `/Users/nonu/Workspace/dexduo`.

## Delivery references

- Repository and app identity: **DexDuo**, [harshulkuhar/dexduo](https://github.com/harshulkuhar/dexduo).
- [PR #1](https://github.com/harshulkuhar/dexduo/pull/1): rename; merged into `main`.
- [PR #2](https://github.com/harshulkuhar/dexduo/pull/2): cleanup; merged into `main`.
- [PR #3](https://github.com/harshulkuhar/dexduo/pull/3): [release and feature PRDs](PRD.md); merged into `main`.
- [PR #4](https://github.com/harshulkuhar/dexduo/pull/4): responsive type grid and shared sprite-badge colors; merged at the owner’s request before the pending Simulator checks.

The owner requested consolidating all four PRs into `main`. This authorization does not mean the pending runtime or hardware checks have passed. The repository workflow is recorded in [AGENTS.md](../AGENTS.md): one PR per completed feature, and pull/synchronize every remaining feature branch after each merge.

## Verification completed

- Xcode 27.1 builds the renamed baseline, feature app and both iOS Simulator test targets (`build-for-testing`). Commands use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` without changing the global selection.
- Nine native macOS calculator/layout XCTest cases pass using the actual app source and test cases: all 324 source relationships, the Gyarados reference, all dual-type pairs, invalid inputs and layout boundaries.
- The actual SwiftUI type component was rendered outside Git in all four grid arrangements; all 18 header colors are present. Sampled Water/Flying badge and header pixels match exactly. These are component renders, not iOS Simulator screenshots.
- Offline generator consistency, model package checksums, 1,025 labels, project references, scheme/module consistency, Python syntax, documentation links, whitespace and no-committed-photo checks pass.
- Earlier portable checks passed ranking, automatic thresholds, obsolete-token rejection, entry decoding/whitespace and six-stat total. Those checks do not constitute an iOS XCTest run.

## Pending validation

The installed iOS 27.1 runtime supports Duo only; the standard iOS 27.0 runtime is downloading for ordinary-phone UI tests. The initial 29-test iOS unit run passed. New phone render/input tests pass at 667×375, 812×375 and 956×440 (including all 18 header colors, accessibility details, failed-lookup scanner state and retained text-field identity). These are UIKit-hosted component tests on the Duo runtime, not ordinary-phone device interaction tests.

The expanded full run passed all 34 unit tests after a fresh Simulator boot. An earlier run exited unexpectedly during the existing Pikachu model integration test; the fresh-boot run passed both real-model inference tests. Ordinary-phone orientation/keyboard/import UI interaction and repeated Duo fold/unfold remain unverified. DeviceHub menu automation was denied macOS assistive access; no fold-cycle success is claimed. Physical camera, cutouts/touch, audio and performance remain unverified. No images or recordings are committed.

## Remaining feature branches

| Branch | State |
| --- | --- |
| `codex/iphone-landscape` | Implemented locally; runtime validation in progress |
| `codex/robotic-entries` | Planned |
| `codex/lens-flash` | Planned |
| `codex/evolution-chains` | Planned |

These active branches are pulled, synchronized with `origin/main` and pushed after each merge. Completed delivery branches are retained as history; they are not additional active features.

## Next steps

1. Finish the standard iOS 27.0 runtime download and run ordinary-phone UI tests; iOS 27.1 Duo is already installed.
2. Restore ignored test fixtures with `python3 Tools/download_test_fixtures.py` if needed; do not stage them. Restore Git LFS weights if needed.
3. Run the renamed `DexDuo` scheme's iOS unit/UI tests, search/import/grid checks, repeated fold/unfold and retained-artwork checks. Record actual results and resolve failures.
4. Deliver landscape iPhone support through one focused PR after available validation. Keep pending device/fold checks explicit. Then deliver robotic speech, lens feedback and evolution through their individual branches and PRs.
