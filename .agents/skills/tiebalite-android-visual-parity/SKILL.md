---
name: tiebalite-android-visual-parity
description: Reproduce the latest Android TiebaLite visual hierarchy and behavior in the existing iOS/iPadOS port, with screenshot-based manual approval after every phase.
---

# TiebaLite Android Visual Parity

Use this skill whenever a task changes TiebaLite iOS UI, root navigation, forum/thread feed presentation, avatars, levels, media grids, emoticons, subposts, composing, or notifications.

## Workflow

1. Read `Docs/VisualParity/PROJECT_RULES.md`.
2. Read `Docs/VisualParity/ANDROID_UI_REFERENCE.md`.
3. Open the exact target screenshot under `Docs/VisualParity/ReferenceScreenshots/Android-target`.
4. Read the corresponding Android source from the locked UI reference commit.
5. Inspect the current iOS screen and record concrete differences.
6. Implement only the current remediation phase.
7. Preserve stable IDs and the existing virtualized list / Pager / MediaViewer infrastructure.
8. Run targeted tests and build, not the whole repository test matrix by default.
9. Install the Simulator `.app` without uninstalling or erasing the device.
10. Navigate to the target screen, capture screenshots, leave the app open.
11. Output `READY_FOR_USER_VISUAL_REVIEW`.
12. Do not commit until the user explicitly approves.

## Visual defaults

- Flat background and thin separators.
- Compact 12–16 pt horizontal padding unless the Android reference proves otherwise.
- Small chips only for semantics such as level, forum tag, pin, quote, subpost background.
- Real avatar/forum image when evidence provides an HTTPS source; neutral placeholder only on failure.
- No giant card wrappers around feed rows or floors.
- No decorative redesign.

## Data fidelity

Do not fake avatar URL, user level, forum level, reply count, unread count, sort mode, or category tabs. Trace the field through Android API/Proto/mapper and the current iOS mapper. If evidence is absent, leave the value absent and report it.

## Write safety

Never send a real post/reply in automated tests. Build and show the composer, then stop for the user to decide whether to submit a benign live test.
