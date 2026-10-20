# Delivery checkpoint

Updated 2026-10-20. Local checkout: `/Users/nonu/Workspace/dexduo`.

## Delivery references

- Repository and app identity: **DexDuo**, [harshulkuhar/dexduo](https://github.com/harshulkuhar/dexduo).
- [PR #1](https://github.com/harshulkuhar/dexduo/pull/1): rename; merged into `main`.
- [PR #2](https://github.com/harshulkuhar/dexduo/pull/2): cleanup; merged into `main`.
- [PR #3](https://github.com/harshulkuhar/dexduo/pull/3): [release and feature PRDs](PRD.md); merged into `main`.
- [PR #4](https://github.com/harshulkuhar/dexduo/pull/4): responsive type grid and shared sprite-badge colors; merged into `main`.
- [PR #5](https://github.com/harshulkuhar/dexduo/pull/5): landscape iPhone support; merged into `main` with available Simulator validation complete.

The owner authorized feature PR creation and merging. [AGENTS.md](../AGENTS.md) records the workflow: one PR per completed feature, then pull and synchronize every remaining feature branch after each merge.

## Verification completed

- Xcode 27.1 with iOS 27.0 and 27.1 Simulator runtimes installed. Commands use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` without changing the global selection. The primary ordinary-phone destination is **iPhone 18 Pro**, named `DexDuo iPhone 18 Pro` locally.
- All **34 iOS unit tests pass on iPhone 18 Pro**: native Core ML Pikachu/Espeon inference, ranking/thresholds, cancellation/retry, labels/preprocessing, chart calculation, profile latching, layout/paging and rendered phone components.
- All **eight iPhone 18 Pro UI tests pass**: both native landscape directions, equal panel widths, cover/background state, retained loaded artwork, complete type grid, search typing/selection, scanner import/candidate confirmation, automatic recognition and accessibility entry/Stats/abilities paging.
- The separate **Duo presentation UI regression passes** on iOS 27.1: actual hinge-capable profile, existing cover/interior presentation and fixed UIKit orientation across device-orientation requests. Unit tests simulate repeated hinge/missing-update transitions; these do not constitute physical fold cycles.
- Phone component renders pass at **667×375, 812×375 and 956×440**, including simulated notched safe areas, all 18 type colors, accessibility details, scanner lookup failure/Retry and stable text-field identity. These are UIKit-hosted component checks, not full device interaction tests at every dimension.
- An **unsigned Release build for generic physical iOS devices passes**. Simulator build and both test targets also compile. Physical-device execution is separate.
- The chart tests verify all 324 relationships, all dual-type pairs, the Gyarados reference, invalid inputs and grid boundaries. Earlier native component renders verify all four grid arrangements and matching badge/header colors.
- Offline generator consistency, model package checksums, 1,025 labels, project/scheme references, Python syntax, whitespace and no-committed-photo checks pass.

The phone tests exposed startup publication/orientation, border bounds and scanner accessibility-identifier issues; those fixes are included in the passing runs. An earlier unit run exited unexpectedly during model inference; a fresh boot and the final iPhone 18 Pro run passed both real-model tests. Test logs, result bundles and visual evidence remain outside Git. No reference images, captures or recordings are committed.

## Maintenance cleanup

Removed unused type identity/multiplier helpers, the test-only body-height helper, unused encoding/hash/equality conformances, and unused singleton configuration arguments. Cover control follows the existing device profile directly; the unreachable Open branch in the interior header is removed. Detached-window rejection remains in the scene observer.

After cleanup, all 34 unit tests and five targeted iPhone 18 Pro UI tests pass (cover/artwork retention, both landscape directions, search, type selection, scanner import/confirmation and automatic lookup). The separate Duo presentation/orientation UI regression passes too. The offline 324-relationship chart check and whitespace/source-reference checks pass. The full eight-test phone run above belongs to the landscape feature; this cleanup reran the five affected UI cases. No visual assets were added.

## Pending validation

- Repeat at least 20 actual Duo fold/unfold cycles, including during search and recognition. DeviceHub menu automation was denied macOS assistive access, so no automated fold-cycle success is claimed. The separate Duo orientation smoke test and simulated hinge transitions passed.
- Check physical iPhone camera, cutouts, touch targets and cold/warm inference performance. No physical iPhone was connected for this feature.
- Audio and lens feedback remain future features; there are no placeholder controls for them in this delivery.

## Remaining feature branches

| Branch | State |
| --- | --- |
| `codex/robotic-entries` | Planned |
| `codex/lens-flash` | Planned |
| `codex/evolution-chains` | Planned |

These branches are pulled, merged with `origin/main` and pushed after each feature merge. The completed `codex/iphone-landscape` delivery branch is retained as history alongside the earlier delivery branches.

## Next steps

1. Deliver robotic speech, lens feedback and evolution through their individual branches and PRs.
2. Complete the outstanding physical-device and actual Duo fold checks when available.

Ignored test fixtures can be restored with `python3 Tools/download_test_fixtures.py`; model weights can be restored with Git LFS. Do not stage test images or visual evidence.
