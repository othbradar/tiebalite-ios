# UserProfile fixture provenance

- Source: `SYNTHETIC_PROTOC_GENERATED`
- Android reference: `5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`
- Root: `Profile/ProfileResponse.proto`
- Text input: `scripts/fixtures/profile_response.textproto`
- Content: one fictional public user with only the Stage 16B display-field whitelist.
- Sensitive data: no Cookie, BDUSS, STOKEN, password, account data, captured/live response body, or real user content.
- Purpose: deterministic Profile decode, mapper, repository, and UI contract.

Generated with locked `protoc 35.1`:

```text
scripts/generate_profile_fixture.sh
```

This fixture is not runtime evidence for anonymous server acceptance, MIME, or
production response contents.
