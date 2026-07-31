# Core 目录约束

本目录承载领域模型、网络、会话、持久化、图片和日志基础设施，不承载页面 UI。

- Core 不依赖 Features、DesignSystem 或具体 View。
- 对外暴露小型协议和领域模型；不暴露 SwiftProtobuf 生成类型、URLSession task、Keychain 原始值。
- 所有领域模型应有稳定身份、值语义和清晰的 `Sendable` 策略。
- 网络/磁盘可变状态使用 actor；不要把所有类型随意标成 `@MainActor`。
- 每个 endpoint 映射都必须有 `Specs/API_EVIDENCE.md` 证据项和固定 fixture。
- 错误类型区分 transport、HTTP、decode、server、authentication、cancelled、unsupportedContent；不得只返回字符串。
- 日志必须脱敏 Cookie、token、设备参数和用户敏感信息。
- Cache 必须定义 key、有效期、淘汰、并发和会话隔离行为。
- Repository 必须能注入 mock clock、HTTP client、session 和 cache，测试不访问实时网络。
- 修改 Core 公共协议时，先列出所有调用方并保持改动最小；不得顺手重写所有 Feature。
