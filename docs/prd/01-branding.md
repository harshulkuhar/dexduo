# 01 — DexDuo identity

Status: implementation prepared; iOS build verification pending. Branch: `codex/dexduo-branding`.

## Requirement

Use DexDuo consistently for the app and its codebase. This includes the checkout, GitHub repository, source directory, Xcode project, shared scheme, app entry type, root view, module, products, app/test targets, bundle identifiers, app-owned cache names, accessibility copy, tooling and documentation.

## Decisions

- Checkout: `/Users/nonu/Workspace/dexduo`.
- Repository: [harshulkuhar/dexduo](https://github.com/harshulkuhar/dexduo).
- Project/scheme/module/product: `DexDuo`; entry file/type: `DexDuo/DexDuoApp.swift` / `DexDuoApp`; root view: `DexDuoView`.
- Bundle identifier: `com.harshulkuhar.dexduo`; test identities use the same prefix. Earlier installs have a separate sandbox and permissions because the application identity changes. Do not claim automatic cache migration between app sandboxes.
- Keep domain names such as `Pokemon`, `Species`, `DexStore` and `DexAPI` where they already describe their responsibilities. There is no need to prefix every unrelated function with the product name.
- Preserve external URLs, API wire keys, upstream species labels, licenses and source revision records. Historical source references are not product branding.
- Update model author metadata and its package checksum only; retain the exact prediction graph and weight bytes. Do not reconvert or retrain for a rename.
- Keep the text-free red cover and existing code-drawn visuals. No new image assets or app icon are part of this rename.

## Acceptance

1. Xcode opens `DexDuo.xcodeproj`; the shared `DexDuo` scheme builds app and both test targets.
2. SpringBoard, Settings permission copy and app-owned accessibility labels show DexDuo.
3. Unit tests import `DexDuo`; the unit-test host and UI-test target resolve the renamed app.
4. All recorded package checksums verify; the large weight file remains in Git LFS at its renamed path.
5. Search tracked filenames and textual app content case-insensitively for the former brand. Any occurrence must belong to an unmodified external source rather than app identity.
6. No photos are staged; cache paths and Python conversion/benchmark instructions use the current source folder.

Static project/scheme checks, Swift parsing, package/label validation and the old-name scan have passed. Full iOS compilation and runtime tests remain pending while Xcode downloads.
