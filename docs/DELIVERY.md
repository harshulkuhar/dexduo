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

Full iOS compilation, the renamed XCTest/UI targets, layout inspection and hardware checks have **not** run in this preparation session. Xcode is being downloaded; the selected developer directory currently points to Command Line Tools.

## Next steps

1. Locate the completed Xcode installation, select its developer directory and inspect installed SDKs/runtimes. Use the SDK required by the current hinge source.
2. Restore ignored test fixtures with `python3 Tools/download_test_fixtures.py`; do not stage them. Restore LFS weights if needed.
3. Build/test the renamed `DexDuo` scheme; check app launch, search, import, fold and cached artwork. Resolve failures before marking PR #1 ready.
4. Validate cleanup against that baseline, then merge #1 followed by #2 and this documentation PR in dependency order. Retarget stacked PR bases as needed.
5. Update feature branches to merged main before their implementation; begin with `codex/iphone-landscape`.
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
| `codex/type-matchups` | Planned |

No new feature implementation, recognition retraining, committed photos or physical-device performance claim is implied by these planning branches.
