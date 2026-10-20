# DexDuo repository guidelines

## Feature delivery

- Use one feature branch and one pull request for every completed feature. Keep fixes for that feature in its existing PR while it remains open; do not combine unrelated features.
- After every PR merge, pull the latest `main`, then pull each remaining active feature branch, merge `origin/main` into it, and push the updated branch. Update tracking branches as needed. Also synchronize from main before starting the next feature.
- Preserve shared history when merging dependent PRs. Do not discard uncommitted work, reset branches or force-push to perform synchronization.
- Keep the active branch inventory and outstanding validation in `docs/DELIVERY.md` current.
- Before opening every PR, read and run the [dead-code-removal skill](.agents/skills/dead-code-removal/SKILL.md). Apply it to the final proposed changes, remove confirmed dead code, and record the findings and relevant verification in the PR. A clean audit is valid when nothing is unused.

## Validation and assets

- Record checks actually run. Successful compilation and native calculator tests do not establish that Simulator interaction/fold tests or physical-device tests passed.
- Do not commit reference images, captures, screenshots, recordings or test-image fixtures. Keep generated visual evidence outside the repository; text data, source provenance and existing model artifacts are allowed.
