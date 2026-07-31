---
name: ios-feature-slice
description: Implement one tightly scoped iOS feature behavior end-to-end with fixture-first state, domain/data boundaries, SwiftUI UI, tests, and quality gates. Use for a single vertical slice; do not use for whole-app generation or broad refactors.
---

# Implement one feature slice

1. Read root and nested `AGENTS.md`, relevant Specs/ADR, and `Docs/Progress/TASK_STATE.md`.
2. Inspect Git status and run the smallest existing baseline tests before editing.
3. State the exact user behavior, non-goals, allowed files, forbidden shared infrastructure, and acceptance tests.
4. Confirm Android/API evidence when behavior depends on Tieba; mark gaps UNKNOWN rather than guessing.
5. Add or update deterministic fixtures.
6. Define domain state and legal transitions, including initial, loaded, empty, failure, refresh, pagination, cancellation and stale responses when applicable.
7. Write failing state/mapper tests first.
8. Implement the smallest domain/data/store changes. Views never call networking, protobuf, Keychain or persistence directly.
9. Implement UI from existing DesignSystem, AppRouter, Pager and MediaViewer. Do not create duplicate interaction components.
10. Add stable accessibility identifiers and a fixture-driven UI smoke flow.
11. Run targeted tests, then `make quality-fast`; phase completion requires the task's full gate.
12. Inspect the diff for unrelated changes, arbitrary animation/gesture/overlay, dependency changes and secrets.
13. Update TASK_STATE using only executed evidence and stop after this slice.

Read `references/feature_done.md` before declaring completion.
