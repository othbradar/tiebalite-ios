# 单元与集成测试约束

- 测试必须确定性、可重复、可并行，不依赖实时网络、当前日期、随机 UUID 或真实 Keychain。
- 使用固定 clock、固定 ID generator、fixture 和 MockHTTPClient。
- 每个测试只验证一个清晰行为，但允许表驱动覆盖边界矩阵。
- 不通过降低断言、增加超长 timeout 或重复重试掩盖不稳定测试。
- 并发测试验证取消、乱序返回、重复请求、actor 隔离和 stale response。
- Protobuf fixture 必须保留来源、生成方式和敏感信息清理说明。
- Bug 回归测试名称包含用户可观察行为，不只写内部方法名。
- 测试辅助代码放 `TestSupport`，禁止复制多套 mock。
