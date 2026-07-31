---
name: ios-interaction-qa
description: Validate iPhone/iPad navigation, scrolling, pager, media zoom, safe areas, overlays, animation consistency, rotation, split view, and accessibility using deterministic UI scenarios and Computer Use. Use for interaction audits and GUI regression verification.
---

# Interaction QA

1. Read `Specs/04_INTERACTION_CONTRACT.md`, `Specs/05_MOTION_CONTRACT.md`, test matrix and relevant interaction ADR.
2. Choose a deterministic fixture scenario and document device, runtime, orientation, window width, appearance, Dynamic Type and Reduce Motion.
3. Run automated interaction/UI tests first; attach failures and identify which contract clause failed.
4. Use Computer Use for flows difficult to assert from files: fast repeated swipes, cancelled/ reversed gestures, pinch/zoom, rotation and live iPad resizing.
5. Follow `references/interaction_matrix.md`; do not change code during the evidence pass.
6. Record page IDs/indexes, route/path, zoom state, frames/safe areas, overlay/hit-testing and animation mode when a failure occurs.
7. Run or inspect `scripts/interaction_inventory.sh`; check for duplicate pager/media/gesture implementations, arbitrary animations and presentation layers with unclear lifetime.
8. Produce PASS/FAIL/PARTIAL/NOT_TESTED per scenario with evidence paths.
9. For failures, open one root-cause task per defect instead of combining unrelated patches.
10. After a fix, rerun the original scenario plus reverse/adjacent cases and device variants.
