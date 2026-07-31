---
name: xcode-quality-gate
description: Run and interpret the repository's deterministic Xcode generation, lint, build, unit, UI smoke, static forbidden-pattern, and diff checks. Use before commits, handoffs, merges, or phase completion; do not delete tests or weaken settings to get green.
---

# Xcode quality gate

1. Read `scripts/project.env` and root `AGENTS.md` to determine the supported commands.
2. Record Git status, Xcode/Swift versions and the exact baseline/target.
3. Run `make doctor` when environment changed, then the requested gate:
   - targeted test during iteration;
   - `make quality-fast` before review;
   - `make quality` at phase completion.
4. Preserve raw xcodebuild exit status through any log formatter.
5. Save or report xcresult/log paths and list each failed test/build issue separately.
6. Triage failures into environment, existing baseline, compilation, lint, deterministic test, UI, or static policy.
7. Do not skip failing tests, increase arbitrary sleeps/timeouts, remove assertions, disable strict concurrency or relax lint without an approved ADR.
8. After a correction, rerun the narrow failure and then the original full gate.
9. Run `git diff --check`, secret/static pattern scans and regenerated-project drift checks.
10. Report exactly what ran, what passed, what failed and what remains unverified.

The helper `scripts/run_gate.sh` invokes the repository-level gate.
