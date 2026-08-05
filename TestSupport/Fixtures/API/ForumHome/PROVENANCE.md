# ForumHome fixture provenance

- Source: `SYNTHETIC_PROTOC_GENERATED`
- Android reference: `5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`
- Root: `FrsPage/FrsPage.proto`
- Text input: `scripts/fixtures/forum_home_response.textproto`
- Content: one fictional forum, two pinned threads, two regular threads, and fictional authors.
- Sensitive data: no Cookie, BDUSS, STOKEN, account data, captured/live response body, or real user content.
- Purpose: deterministic FRS decode, mapper, repository, and ForumHome UI contract.

Generated with locked `protoc 35.1`:

```text
protoc --proto_path=References/TiebaLite-Android/app/src/main/protos \
  --encode=tieba.frsPage.FrsPageResponse \
  FrsPage/FrsPage.proto \
  < scripts/fixtures/forum_home_response.textproto \
  > TestSupport/Fixtures/API/ForumHome/frs_page_synthetic.pb
```

This fixture is not runtime evidence for anonymous server acceptance, MIME, or
production response contents.
