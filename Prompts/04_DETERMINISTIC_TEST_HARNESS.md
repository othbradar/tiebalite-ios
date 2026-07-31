# 阶段 04：确定性测试、Fixture 与依赖注入底座

目标是让后续所有 UI 先在完全可控的数据与时序下实现。不得接真实网络。

## 前置

- 工程骨架绿色。
- 读取 ADR-0002、ADR-0006、ADR-0009、ADR-0010。
- 先运行阶段 03 的 build/unit/UI smoke，记录基线。

## 实现范围

建立：

- `AppEnvironment`/composition root。
- 小型 `Clock`、`IDGenerator`、`HTTPClient`、`SessionProviding`、`ImageLoading` 协议。
- `MockHTTPClient` 或 `URLProtocol` stub，支持：成功、延迟、错误、取消、乱序响应。
- `LaunchScenario` 解析：UI tests 通过参数选择固定场景。
- Fixture loader：JSON、binary Protobuf、图片资源，错误信息清晰。
- 测试专用 session/cache，绝不触碰真实 Keychain/账号。
- 统一 Debug 日志与敏感字段 redaction 测试。
- UI test helper：等待 identifier、失败截图附件、启动场景。

## Launch scenario 最低集合

```text
app.empty-shell
network.offline
network.slow
session.signed-out
session.signed-in-fixture
session.expired
```

后续 Feature 可扩展 `recommendations.success` 等，不得每个测试发明不同参数解析。

## 测试要求

- 同一 endpoint 旧请求晚返回不会自动覆盖（通过测试基础设施可构造）。
- Cancellation 能被观察，取消不映射为用户错误。
- Fixture 缺失/畸形时测试失败信息包含路径但不泄密。
- Redactor 能移除 Cookie/token/BDUSS/STOKEN 等敏感键。
- UI smoke 使用固定 launch scenario，不访问互联网。
- 测试不依赖随机 UUID、系统当前时间或 `sleep()`。

## 不允许

- 不创建贴吧业务 endpoint。
- 不写推荐/吧/帖子 UI。
- 不使用全局 mutable singleton 作为“注入”。
- 不把 test-only 代码暴露到 Release 行为。
- 不为了测试禁用 strict concurrency。

## 验收

- 可确定性模拟慢网、错误、取消和乱序。
- App 的依赖在组合根可替换。
- unit/UI smoke 全绿且重复运行稳定。
- `make quality` 通过。

完成后停止。
