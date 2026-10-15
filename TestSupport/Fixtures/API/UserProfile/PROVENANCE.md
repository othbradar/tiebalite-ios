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

U12 native-ios.json 为独立 iOS 22.11.1 descriptor 生成的3请求/2响应合成样本，仅固定 UID42/帖子110/回复111及 Fixture 文本，无真实账号/凭证/正文/资源。generate.py/verify.py 位于 scripts/fixtures/native_profiles；参考 SHA 与偏移记录于 API_EVIDENCE。样本用于 wire 事实核对，不代表完整官方 SDK 或远端关注动作已验证。

U12 native-forums.json 为人工构造的 JSON 样本，依据同一 iOS 22.11.1 的 TBCLikeBarListDataItem.init (0x101b8975c) 数组类及 TBCBarDataItem.init (0x101b44d10) 映射。覆盖字符串/数字值、普通/分组列表、缺可选字段、重复/无效条目和原始 has_more。仅示例吧、13001/13002 和 fixture.invalid，无真实用户或捕获响应。

U12FollowedForumsTests 的 ForumAvailabilityFixture 与 DEBUG FixtureProfileContentRepository 中 UID1100001 的 metadata-only JSON 为合成样本：只保留实测 error_code0 且无列表/分页字段的结构，时间/日志标识均为固定假值。该结构代表当前无可查看列表，不能证明对方开启隐藏。用于 mapper→cache repository→store 的旧数据隐藏/无额外请求回归，以及 UI 中无红色失败/重试的检查；不保存真实响应或用户内容。
