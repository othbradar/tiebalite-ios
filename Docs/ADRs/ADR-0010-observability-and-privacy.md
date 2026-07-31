# ADR-0010：可观测性与隐私

- 状态：Accepted
- 日期：2026-07-31
- 决策者：阶段 02 架构决策
- 关联阶段：02、04 及所有实现阶段

## 背景

分页、竞态、Session cleanup、Pager 和图片资源问题需要可复现诊断，但贴吧
请求可能包含 Cookie/token、设备标识、URL query、账号资料和正文。直接记录
Error.localizedDescription、request/response 或状态 dump 会越过隐私边界。

## 必须满足的约束

- 默认无第三方 analytics/crash/remote logging SDK。
- 仅记录白名单字段；敏感数据即使标记 private 也不主动写入。
- production 只保留诊断所需的粗粒度本地事件。
- test recorder 与 OSLog backend 使用同一安全 event model。
- 状态、附件、signpost 和错误 UI 均不得泄密。

## 候选方案

### A：小型 DiagnosticsClient + OSLog/OSSignposter

- 优点：系统能力、无生产依赖、可注入 recorder。
- 缺点：事件 schema 与隐私审查需自行维护。
- 风险：开发者绕过 client 直接打印。
- 验证方式：静态扫描、canary secret tests、事件字段白名单。

### B：直接使用 print/Logger/Error.description

- 优点：调用方便。
- 缺点：字段无治理、测试难拦截。
- 风险：URL、token、正文和 raw error 泄漏。
- 验证方式：不接受。

### C：第三方遥测/崩溃 SDK

- 优点：聚合和远程检索。
- 缺点：新增数据处理者、网络上传和生产依赖。
- 风险：隐私、合规、体积和退出成本。
- 验证方式：必须有新的依赖/隐私 ADR 与用户授权边界。

## 决策

选择 A。

定义 Sendable 安全事件：

```text
DiagnosticEvent {
  staticCategory
  symbolicOperationID
  shortLivedRequestID
  durationBucket?
  resultCategory
  safeIntegerCounts?
}
```

允许字段：

- 静态 category、Feature/endpoint symbolic ID；
- 当前进程内短生命周期 request/transition ID；
- duration、byte/count bucket；
- `success/cancel/offline/timeout/server/malformed/stale` 等安全类别；
- 状态 case 名和 generation/cursor 是否匹配，不含状态 payload。

禁止字段：

- raw URL、query、path 参数、header、body、Cookie/token；
- forum/thread title、正文、图片 URL、账号名/ID/资料；
- device/install identifier、Keychain key/value；
- `Error.localizedDescription`、raw server message、Proto/DTO dump；
- 可跨启动关联用户的稳定 request ID。

production 使用 OSLog 本地生命周期管理，不写自定义日志文件、不自动上传。
Release 默认仅 info/error 的安全聚合；Debug 可记录状态 case transition，但
不能记录 payload。Pager/network/image/session 性能使用 OSSignposter，同一
安全字段规则适用。

所有调用通过协议：

```text
DiagnosticsClient.record(DiagnosticEvent)
Signposter.measure(SafeInterval)
```

测试注入内存 recorder 并断言事件序列、stale drop 和字段白名单。阶段 02
现有 `scripts/forbidden_patterns.sh` 尚未包含日志绕过规则；当前只能由代码
审查和既有 generic secret scan 辅助发现，不能宣称已自动阻止 `print`、raw
request dump 或直接 Logger 调用。阶段 04 必须扩展静态规则并加入正反 canary，
再把该控制标为已证明。

### 诊断附件

- 自动附件只允许固定脱敏 fixture、状态 case 序列和安全计数；
- 真实账号、live response、Cookie jar、WebView storage 不做附件；
- 截图若可能含用户内容，默认不自动采集；
- xcresult 中的 launch args/environment 也不得包含 secret；
- 导出/分享诊断包需独立产品与隐私决策。

## 为什么不是其他方案

B 无法审计或测试；C 在当前没有远程遥测需求，且会新增隐私和依赖风险。

## 迁移/退出成本

Feature 只依赖 DiagnosticsClient，OSLog backend 可替换。未来如需 crash
reporting/remote metrics，必须新 ADR 记录数据字段、保留期、上传时机、用户
控制、供应商、许可证和退出方案。

## 验收与回滚条件

- canary token/URL/title/raw Error 经过所有 event/attachment 路径均不出现。
- production configuration 无 Test recorder、文件日志或 remote upload。
- state transition 只记录 case/identity mismatch，不记录 payload。
- request/Pager/Media signpost 可按短期 ID 配对且不跨启动。
- 扩展后的 secret/forbidden scan 与日志绕过 canary 通过；在阶段 04 实现前
  此项为 `NOT_IMPLEMENTED`。

发现任一敏感字段进入日志或 xcresult 时，先关闭对应事件/附件并回滚到最近
安全版本；不得以“仅 Debug”作为保留理由。
