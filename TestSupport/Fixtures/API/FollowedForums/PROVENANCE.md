# FollowedForums fixture provenance

- Source：`SYNTHETIC_PROTOC_GENERATED`
- Android reference：`5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`
- Root：`ForumGuide/ForumGuideResponse.proto`
- Text input：`scripts/fixtures/followed_forums_response.textproto`
- Content：三个虚构 forum ID、名称、等级和统计；不来自真实账号或服务端响应。
- Sensitive data：无 BDUSS、STOKEN、Cookie、账号、用户 ID、真实关注关系或正文。
- Purpose：固定 ForumGuide wire decode、领域映射和 Fixture Repository/UI contract。

生成命令使用锁定 `protoc 35.1`：

```text
protoc --proto_path=References/TiebaLite-Android/app/src/main/protos \
  --encode=tieba.forumGuide.ForumGuideResponse \
  ForumGuide/ForumGuideResponse.proto \
  < scripts/fixtures/followed_forums_response.textproto \
  > TestSupport/Fixtures/API/FollowedForums/forum_guide_synthetic.pb
```

该 fixture 只是确定性测试输入，不构成 HTTPS endpoint、认证、错误 taxonomy 或
真实账号内容的运行证据。
