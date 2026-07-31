---
name: ios-root-cause-debug
description: Diagnose and fix a reproducible iOS bug by collecting evidence, identifying one root cause, adding a failing regression test, applying a minimal fix, and rerunning regressions. Use for crashes, state races, navigation bugs, white flashes, occlusion, or flaky interaction; never use visual patch guessing.
---

# Root-cause debugging

1. Read `Specs/09_BUG_REPORT_TEMPLATE.md`, relevant interaction/state contracts, ADR and Git history.
2. Protect user work: record Git status and do not reset or overwrite unrelated changes.
3. Reproduce deterministically with a fixture LaunchScenario. For GUI-only issues, use Computer Use on Xcode/Simulator with exact environment settings.
4. Reproduce at least three times and collect the minimum useful evidence: state transition, stable IDs, route, task generation, frames/insets, gesture state, animation transaction, image request, relevant logs.
5. Classify the failure using `references/bug_taxonomy.md` and eliminate categories with evidence.
6. State one primary root cause in causal form, not a list of possibilities.
7. Add the closest failing regression test and run it before the fix. Add a UI flow when user-visible behavior needs coverage.
8. Apply one minimal correction to state ownership, identity, lifecycle, cancellation, layout or gesture arbitration.
9. Do not use delay, random `.id`, global animation disabling, full-screen masking, extreme z-index, root reconstruction, cache clearing or weakened tests.
10. Run the failing test, adjacent component suite, original reproduction repeatedly, and relevant device/accessibility/network variants.
11. If two hypotheses/fix attempts fail, revert those attempts and propose a component redesign; do not add a third patch.
12. Report evidence, red-to-green test, exact fix, regressions and remaining uncertainty.
