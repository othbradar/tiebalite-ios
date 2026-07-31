# ADR-0006：网络、Endpoint 与 Protobuf 边界

- 状态：Accepted
- 日期：2026-07-31
- 决策者：阶段 02 架构决策
- 关联阶段：02、04、07、11

## 背景

阶段 01 只证明了 Android 静态调用链。部分 P0 候选仍是明文 HTTP，HTTPS
Proto endpoint 的匿名能力、最小参数、签名、错误分类和真实 payload 也都是
UNKNOWN。架构必须允许 fixture-first，并防止把 Android 的全局账户、生成
类型或 telemetry 复制到 iOS。

## 必须满足的约束

- 使用 URLSession；不关闭 ATS/TLS，不接受任意证书。
- Feature/View 不接触 URLSession、Cookie、Proto 或 transport DTO。
- 每次请求显式声明认证上下文，不能读取“当前账户”singleton。
- Endpoint 只在 HTTPS、host/path、编码、auth 与 evidence gate 全部满足后
  注册为 live。
- decode/map 不在 MainActor；跨 actor 只返回 Sendable domain。
- schema 来源与 SwiftProtobuf 包许可证是两个独立门禁。

## 候选方案

### A：URLSession + typed Endpoint + SwiftProtobuf

- 优点：系统网络栈、依赖少、边界可测试；SwiftProtobuf 已预批准。
- 缺点：multipart、错误映射、fixture 与生成流程需自行定义。
- 风险：隐式 Cookie、redirect、generated Sendable 和 schema 权利。
- 验证方式：URLProtocol/MockHTTPClient、编码 golden、mapper fixture、
  strict-concurrency build。

### B：Alamofire/其他网络框架

- 优点：请求构造和拦截器工具丰富。
- 缺点：无已证系统方案缺口，新增生产依赖。
- 风险：隐式全局 session/interceptor 与退出成本。
- 验证方式：须先由新依赖 ADR 证明 A 无法满足需求。

### C：Feature 直接使用 URLSession/Generated Message

- 优点：代码路径短。
- 缺点：协议、认证、错误和 UI 耦合。
- 风险：无法 fixture 替换、敏感字段进入 View、跨 actor 数据不安全。
- 验证方式：不进入实现。

## 决策

选择 A。

### Transport

定义小型 Sendable `HTTPClient` 协议，raw transport 只接收/返回：

```text
HTTPRequest(method, validated HTTPS URL, headers, body, timeout, redirectPolicy)
HTTPResponse(status, headers allowlist, Data)
```

production concrete 使用自有 URLSession configuration：

- 不使用 shared CookieStorage、shared URLCache 或全局 interceptor；
- HTTPS → HTTP 或未批准跨 host redirect 直接拒绝；
- response size、timeout 和 MIME 有 endpoint 上限；
- cancellation 保留 `CancellationError`；
- raw URL/query/header/body 不进入日志。

`Endpoint` 固化 symbolic ID、method、allowlisted host/path、body codec、
response family、auth requirement、timeout class 和 redaction policy。
`optional-in-request` 只是 Android evidence 标签，不能自动附加 active
credential。

每次调用必须显式传：

```text
AuthContext =
  anonymous
  | active(ProtectedDataLease)
  | candidate(operationID)
```

active 的 sessionID 只从 lease 派生，不能再传第二份可能不一致的值。
candidate validation 绝不能回退读取 active session；不存在合法 auth
context 时构造请求即失败。

### Repository 与 mapper

Repository 表达用户任务，负责选择 Endpoint、组织分页、调用 transport，并
在自己的隔离域内 decode Proto/DTO、校验 envelope、map 为 Sendable domain。
生成 Message 和 raw DTO 不跨 repository actor、不进入 Feature/View。

关注吧的网络页只在 Repository 内逐页聚合：Store 只接收同一 session 的完整
membership，或收到包含 failedPage 的失败；永不暴露半成品。其他分页仍按
`Specs/STATE_MACHINES.md` 的 generation/cursor/Event 提交。

### Protobuf 生成

- SwiftProtobuf 以 exact SwiftPM version 引入，并更新 canonical
  `Config/SwiftPM/Package.resolved`。
- 只生成经 evidence、import graph 和许可证审批的 P0 最小闭包。
- schema、来源 manifest、import lock、generator/runtime 版本、输出 hash
  与生成 Swift 一并提交；生成 Swift 是可重建的 tracked derived output，
  不手改，并从临时目录生成后逐字节比较。
- 生成代码位于 `Generated/Protobuf`，通过唯一内部
  `GeneratedProtobuf` target 隔离；UI/Feature 禁止 import。
- optional absent/default、未知 tag、raw int `.unknown(raw)`、multipart
  request golden 与 malformed response 必须有 byte-level tests。
- 在 SwiftProtobuf 的 Sendable/presence API 未编译验证前，generated
  Message 留在 repository 隔离内。

若 Android schema 权利门禁未关闭，选择 clean-room 最小兼容 schema 或保持
fixture-only；SwiftProtobuf 自身许可通过不能解锁 Android 文件复制。

### Live gate

任何 endpoint 的 production adapter 默认 disabled，直到
`Specs/API_EVIDENCE.md` 同时具备：

- HTTPS 合法路径、最小参数与 auth 证据；
- 成功/空/错误/畸形/取消/会话状态的脱敏 fixture；
- error taxonomy、分页/终止和 mapper tests；
- schema/DTO 来源与分发决定。

`media.picPage` 和 `session.loginValidation` 当前 HTTP 候选保持
`BLOCKED`，不得注册为可调用 live Endpoint。

## 为什么不是其他方案

B 没有解决证据、认证或 schema 风险，只增加依赖。C 直接违反
transport/domain/UI 边界与确定性测试要求。

## 迁移/退出成本

HTTPClient、Endpoint、Repository 和 domain 边界稳定，底层 transport 或
wire codec 可替换。无 HTTPS/合法参数时回退 fixture-only；schema 权利阻塞
时改用 clean-room 最小 schema。SwiftProtobuf presence/unknown round-trip
失败时先 pin/升级并复验，仍失败才用新 ADR 更换 codec。

## 验收与回滚条件

- anonymous/active/candidate 三类请求不会隐式串 session。
- URLProtocol/MockHTTPClient 覆盖取消、redirect、timeout、500、malformed。
- FollowedForums 中间页失败不发布部分列表。
- generated target 无 UI import，Feature 无 generated import。
- Proto golden 与 fixture hash 稳定；未知字段不导致 crash。
- secret scan 与诊断 recorder 不含 raw URL/query/header/body/token。

任何实现需要 HTTP 降级、shared Cookie、全局账户或删除 malformed tests
才能工作，立即回滚到 fixture adapter。
