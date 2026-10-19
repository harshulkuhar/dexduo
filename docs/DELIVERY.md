# Delivery checkpoint

Updated 2026-10-19. Current local checkout: `/Users/nonu/Workspace/dexduo`.

## Completed preparation

- Product name selected by the owner: **DexDuo**.
- GitHub repository renamed to [harshulkuhar/dexduo](https://github.com/harshulkuhar/dexduo); origin updated.
- Rename implementation: `codex/dexduo-branding`, [PR #1](https://github.com/harshulkuhar/dexduo/pull/1), draft pending iOS validation.
- Cleanup implementation: `codex/cleanup`, [PR #2](https://github.com/harshulkuhar/dexduo/pull/2), based on the rename, draft pending iOS validation.
- Six feature specifications: [PRD](PRD.md). Feature branches contain the preparation baseline until their implementations begin; creating a branch does not mean the feature is shipped.

## Verification already performed

- Swift source syntax parsing; Xcode project plist, object references, shared scheme and target/module rename checks.
- Model package checksums, 1,025 labels, LFS attributes and tracked old-name/photo checks.
- Python syntax and diff whitespace checks.
- A compiled macOS harness exercising actual Foundation-only app sources: ranking, automatic thresholds, generation-token rejection, English entry decoding/whitespace and six-stat total passed. This is not a run of the iOS XCTest target.

Xcode 27.1 is now installed. The renamed baseline and the type-grid app/test targets compile successfully for iOS Simulator using an explicit developer directory. The iOS runtime is still downloading; iOS XCTest execution, search/import/fold UI regressions and physical-device checks remain pending.

## Next steps

1. Finish installing the iOS 27.1 Simulator runtime. Xcode 27.1 and its SDKs are present; commands in this session use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` without changing the global developer selection.
2. Restore ignored test fixtures with `python3 Tools/download_test_fixtures.py`; do not stage them. Restore LFS weights if needed.
3. Build/test the renamed `DexDuo` scheme; check app launch, search, import, fold and cached artwork. Resolve failures before marking PR #1 ready.
4. Validate cleanup against that baseline, then merge #1 followed by #2 and this documentation PR in dependency order. Retarget stacked PR bases as needed.
5. The owner selected `codex/type-matchups` as the first feature. Validate and merge its focused PR after the preparation stack, then proceed with the landscape foundation.
6. Implement speech, lens feedback, evolution and type matchups against their individual specifications. Record actual tests, PR links and device limitations here in each delivery.

## Branch inventory

| Branch | State |
| --- | --- |
| `codex/dexduo-branding` | Rename implementation; draft review |
| `codex/cleanup` | Cleanup implementation; draft review |
| `codex/dexduo-prds` | Release and feature requirements |
| `codex/iphone-landscape` | Planned |
| `codex/robotic-entries` | Planned |
| `codex/lens-flash` | Planned |
| `codex/evolution-chains` | Planned |
| `codex/type-matchups` | Implemented; iOS runtime verification pending |

## Type-grid implementation

The Types tab displays all 18 matchups in the first fitting layout among 3×6, 2×9, 6×3 and 9×2. The grid and sprite badges share the reference palette; the green sprite-screen background is unchanged. The chart, pinned CSV snapshot, provenance and license are bundled/retained without adding runtime requests.

Verification completed: all 324 source relationships, nine native macOS calculator/layout XCTest cases (including Gyarados and all dual-type pairs), iOS Simulator build-for-testing, model integrity, generator consistency and project/documentation checks. The actual SwiftUI component was rendered at all four layout sizes outside Git; all 18 header colors are present in each render. Sampled Water/Flying badge and grid-header pixels match exactly. This render is not an iOS Simulator screenshot.

The iOS search/import/type-selection UI tests are compiled but not yet executed while the runtime installs. Camera/hardware behavior is unverified. No photos or generated audio are committed.
