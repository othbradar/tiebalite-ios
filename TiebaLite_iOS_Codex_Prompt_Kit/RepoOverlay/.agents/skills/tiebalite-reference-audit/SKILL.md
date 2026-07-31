---
name: tiebalite-reference-audit
description: Audit the read-only Android TiebaLite reference for feature behavior, API calls, repositories, protobuf messages, navigation, and content rendering. Use for evidence-backed specifications; do not use to write iOS production code.
---

# TiebaLite Android reference audit

1. Read root `AGENTS.md`, the current phase prompt, and existing audit/spec files.
2. Confirm `References/TiebaLite-Android` is clean and record branch plus commit SHA.
3. Define one audit scope before searching: feature, endpoint family, proto family, navigation flow, or renderer.
4. Trace from user action to UI intent, repository, request construction, endpoint, response/proto, mapper, state, and rendered behavior.
5. Cite local paths and symbols. Use the evidence labels in `references/evidence_labels.md`.
6. Search for alternate/legacy implementations and call sites before concluding a symbol is authoritative.
7. Record authentication, pagination, error, cancellation, empty and malformed-data behavior.
8. For protobuf, record message dependencies, unknown enum handling, optional/default semantics, and fixture needs.
9. For UI behavior, distinguish Android-specific implementation from product semantics suitable for native iOS.
10. Write only Specs/Docs/TASK_STATE. Do not create Swift, edit the submodule, or invent missing behavior.
11. End with UNKNOWN items and the smallest safe experiment needed to resolve each.
