# Search fixture provenance

- Source: `SYNTHETIC_JSON`
- Android reference: `5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`
- Wire models: `SearchForumBean` and `SearchThreadBean`
- Content: fictional forum and thread search results, including deterministic
  duplicate IDs and string/integer wire variants for mapper tests.
- Sensitive data: no Cookie, BDUSS, STOKEN, account data, captured/live response
  body, real query history, or real user content.
- Purpose: deterministic Hybrid JSON decode, mapper, pagination, and repository
  contract tests.

These fixtures are not runtime evidence for anonymous server acceptance, MIME,
rate limits, result ordering, or production response contents.
