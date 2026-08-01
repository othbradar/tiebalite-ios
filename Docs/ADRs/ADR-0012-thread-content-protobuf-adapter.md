# ADR-0012：阶段 08 ThreadContent Proto adapter 边界

- 状态：Accepted
- 日期：2026-08-01
- 决策者：阶段 08 内容领域模型与 Renderer
- 关联阶段：07、08
- Supersedes：仅替代 ADR-0011 的“唯一 Core adapter 文件”限制；不改变其
  schema、工具、许可、分发或 Production transport 决策

## 背景

阶段 08 需要把锁定 Android schema 中的
`ThreadInfo.firstPostContent#142`、`PbContent`、`MemeInfo` 和
`ThreadInfo.poll_info#74` 映射为与 Proto/SwiftUI 解耦的领域值。阶段 07 的
51-file Personalized closure 已包含 `ThreadInfo` 的完整 47-file closure，且
cross-language fixture 已证明这条合成首楼正文 wire；无需扩大 manifest 或改动
`Generated/Protobuf`。

ADR-0011 把 generated import 精确限制在
`PersonalizedProtocol.swift`。把阶段 08 mapper 塞入该文件会混淆 Endpoint 与
内容领域职责；放宽整个 Core 目录又会扩大 generated 类型泄漏面。

## 决策

在保留 ADR-0011 其余全部约束的前提下，generated runtime 的手写 import
allowlist 精确扩为两个文件：

1. `Sources/Core/TiebaAPI/PersonalizedProtocol.swift`
2. `Sources/Core/TiebaAPI/ThreadContentProtoMapper.swift`

第二个文件只允许：

- 同步 decode `Tieba_ThreadInfo` binary fixture；
- 同步、确定性地把 `ThreadInfo/PbContent/PollInfo/PollOption` 映射为
  `ThreadContentDocument` 值；
- 返回 `Sendable/Equatable` Core domain，不返回 generated message；
- 对 raw/缺省/畸形字段作本地、typed 或明确降级处理。

它不得创建 Endpoint、访问 HTTPClient/URLSession、磁盘、Keychain 或
MainActor，不得记录 raw Proto、正文或 URL。Feature/View/DesignSystem/
InteractionKit 继续禁止 `GeneratedProtobuf`、`SwiftProtobuf` 与 `Tieba_*`。

## 不在本决策范围

- 不增加、删除或重生成任何 Proto input/generated file；
- 不把 `Post.proto` 或 PBPage closure 加入阶段 07 manifest；
- 不证明普通楼层 fold/delete、PBPage、live endpoint 或媒体可达性；
- 不改变本地/个人/非商业许可范围；公开、App Store 或商业分发仍阻塞；
- 不改变 Production 的 `DisabledHTTPClient`；
- 不建立 ThreadScreen、Repository、Pager 或 MediaViewer。

## 验证与回滚

静态门禁必须精确检查两个 allowlisted 文件各自的 import，并拒绝其他 App/
Sources Swift 文件使用 generated/runtime symbol。`make verify-protos` 必须继续
证明 51 个生成文件零漂移；ThreadContent fixture verifier 必须比较两次 JVM
generation、独立 protoc encoding 与 tracked bytes。

若 mapper 需要当前闭包外的类型、generated 类型泄漏到 Feature/View、strict
concurrency 需要手写豁免，或权利范围变化，停止实现并以新 ADR 重新审计；不得
放宽目录级 allowlist。
