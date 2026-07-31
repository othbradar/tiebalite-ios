---
name: ios-motion-audit
description: Inventory and normalize SwiftUI/UIKit animations and transitions against the project's Motion contract, including Reduce Motion and system-navigation interactions. Use for inconsistent animations, jank, double transitions, or motion regressions.
---

# Motion audit

1. Read `Specs/05_MOTION_CONTRACT.md` and DesignSystem rules.
2. Run `scripts/interaction_inventory.sh` (optionally writing to an audit file), then inventory SwiftUI/UIKit animations, transitions, matched geometry, gesture-driven animators and root transactions.
3. Map every call to a user behavior, scope, semantic Motion token and Reduce Motion path.
4. Flag arbitrary duration/curve/spring, broad implicit animation, system plus custom navigation, batch-list animation, layout-changing image placeholders and duplicated feedback.
5. Produce a read-only motion audit before editing.
6. Fix in order: remove nonsemantic motion, narrow animation scope/value, use tokens, remove double transitions, then address underlying identity/state issues.
7. Do not solve jank with slower durations, global disabling or async delay.
8. Rerun representative flows in default and Reduce Motion on iPhone and relevant iPad sizes.
9. Add static checks or tests for recurring mistakes.
