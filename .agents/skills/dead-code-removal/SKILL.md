---
name: dead-code-removal
description: Audit and remove confirmed dead code in DexDuo, including a required pass before opening each PR. Use for unused declarations, obsolete state and redundant scaffolding; preserve application behavior.
---

# Dead-code removal

Audit the proposed PR before opening it. On an explicit repository cleanup request, inspect the current app, tests, project references and maintenance tools.

- Use `git diff` and `rg` to trace declarations and callers. Reference counts identify candidates, not proof of dead code.
- Check SwiftUI property wrappers, UIKit/protocol callbacks, Codable fields, XCTest discovery, conditional compilation, Xcode resources and command-line entry points before deleting anything. Keep conversion/generation tools that support reproducibility.
- Remove declarations with no consumers, write-only state and obsolete branches. Inline forwarding helpers when they add no behavior or useful abstraction. Do not add replacement infrastructure merely to justify a cleanup.
- Preserve cancellation guards, caches, accessibility identifiers and device-specific behavior. Keep tests that verify product behavior; replace assertions about removed unused state with assertions about the behavior they were meant to protect.
- Build and run the existing tests affected by the removal. Include Simulator interaction checks when changing view composition, and check both phone and Duo code paths when shared code changes. Record limits honestly.
- Run `git diff --check` and inspect the final diff for accidental behavior changes or image additions. If later edits introduce more code before the PR opens, review those edits too.

In the PR, name the removed code, explain the evidence that it was unused and list checks actually run. Report a clean audit when nothing qualifies; do not manufacture deletions.
