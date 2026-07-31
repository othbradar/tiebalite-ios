---
name: tiebalite-api-evidence
description: Trace a Tieba endpoint or protobuf field from the Android reference into an evidence record, sanitized fixture, Swift request/mapper contract, and tests. Use when adding or verifying live API behavior; never guess undocumented parameters or expose credentials.
---

# API and protobuf evidence workflow

1. Read `Specs/API_EVIDENCE.md`, `Specs/PROTOBUF_MAP.md`, source/license notes and networking ADR.
2. Define one endpoint family or message question.
3. Search all Android call sites, request builders, constants, adapters/casters, repository consumers and protobuf definitions.
4. Record source path/symbol, HTTP method/path family, encoder, required headers, auth, request/response message, pagination and server error behavior.
5. Distinguish constant values, computed/device values, session values and UNKNOWN values.
6. Never paste or log real Cookie, BDUSS, STOKEN, user ID, password, device identifier or private content.
7. If a live probe is authorized, make the minimum request, log only metadata, sanitize/minimize the response, and stop after the target edge is observed.
8. Add a request-construction test, sanitized fixture, decode/mapper test and malformed/unknown-field test.
9. Generated protobuf code is never manually edited; generation must be repeatable.
10. Update evidence and UNKNOWN files before production repository code.
11. If evidence is insufficient, leave the feature fixture-backed and return a diagnostic unsupported/unknown outcome.
