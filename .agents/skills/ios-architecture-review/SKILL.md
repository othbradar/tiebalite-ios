---
name: ios-architecture-review
description: Perform a read-only architecture and diff review for Swift 6 concurrency, feature boundaries, navigation, state ownership, dependency direction, testing, and high-risk interaction components. Use before accepting an ADR, scaffold, shared refactor, or major phase; do not edit code.
---

# Read-only architecture review

1. Read root/nested AGENTS, relevant Specs/ADR and target diff.
2. Confirm the intended scope and baseline commit.
3. Review dependency direction, public APIs, state truth, actor isolation, cancellation and stale-response handling.
4. Review route/path ownership, iPhone/iPad mapping and state restoration.
5. Verify there is one Pager, one MediaViewer, one motion system and one family of loading/error components.
6. Check API/protobuf/domain separation and session/logging privacy.
7. Check whether tests can deterministically exercise every new behavior and failure mode.
8. Identify unapproved dependencies, build-generation drift, unnecessary modules or broad unrelated edits.
9. Report only actionable findings with priority, file/line, concrete failure scenario and smallest remediation direction.
10. Do not modify the tree. If no defect is found, state that and list runtime risks not proven by static review.
