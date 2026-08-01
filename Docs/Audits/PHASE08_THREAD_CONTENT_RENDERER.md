# 阶段 08 Thread Content Domain / Renderer 审计

状态：`THREAD_CONTENT_DOMAIN_RENDERER_COMPLETE`

范围标签：`FIXTURE_FIRST` / `READ_ONLY` /
`PRODUCTION_LIVE_DISABLED` / `PHASE_09_NOT_STARTED`

## 范围与出口

阶段 08 只完成首楼正文内容的一个隔离垂直切片：

- 锁定 Android 证据的 P0 内容节点矩阵；
- 可重建、脱敏、跨语言的 `ThreadInfo.firstPostContent` binary
  fixture；
- Proto 隔离的 `Sendable` / `Equatable` 领域值与稳定 ID；
- 同步、确定性 `ThreadInfo/PbContent/PollInfo/PollOption` mapper；
- 只消费领域值的 SwiftUI `ThreadContentRenderer`；
- 注入式图片 loader 的 loading/success/failure 稳定布局；
- 图片与安全外链只产生 intent，不直接导航、播放或请求；
- Debug-only Renderer Lab 及 iPhone/iPad 确定性 UI smoke。

本阶段没有建立 ThreadScreen、Repository、Endpoint、PB Page/普通楼层
wire、分页、Pager 或 MediaViewer；没有发真实网络请求，也没有进入或
读取阶段 09 指令。

## 证据与 fixture

证据根为只读 Android submodule exact commit：

```text
5545326b2a8e0d784b2f3dfbcb219c7b121e61c2
```

`PbContent.type#1` 是 raw `int32`，Android
`Extensions.kt::List<PbContent>.renders` 已证分支为：

- `0/9/27/35/40` text-like；
- `1` link；
- `2` emoji；
- `3` image；
- `4` mention；
- `5` 的三种 video 降级形态；
- `10` voice；
- `20` alternate image；
- 其他 raw 值未有 Android `else` 分支。

首楼消费路径为 `ThreadInfo.firstPostContent#142`，只读 poll 为
`ThreadInfo.poll_info#74`。阶段 07 的 51-file 生成闭包已完整包含
`ThreadInfo` 的 47-file 传递闭包；阶段 08 没有修改
`Config/Protobuf/Personalized.inputs.tsv`、Android submodule 或
`Generated/Protobuf`。

tracked fixture：

- ID：`thread-content.first-post.cross-language`；
- path：
  `TestSupport/Fixtures/API/ThreadContent/thread_content_cross_language.pb`；
- size：1535 bytes；
- SHA-256：
  `d37a7486974718d660a4b43466d914156c66d36f3f83982507915575e68cdf12`；
- producer：Java 21.0.10 + protobuf-java 4.35.1 `DynamicMessage`；
- independent input：
  `scripts/fixtures/thread_content_response.textproto`；
- verifier：两次 JVM generation、tracked bytes 与独立
  `protoc --encode=tieba.ThreadInfo` 结果逐字节一致。

fixture 全部使用 synthetic ID/text 与 `fixture.invalid`，不含 Cookie、
BDUSS、STOKEN、授权头、设备标识或抓取内容。证据等级是
`CROSS_LANGUAGE_GENERATED`，不是 live response 或 PB Page fixture。

## 领域与 mapper 边界

`Sources/Core/Models/ThreadContent.swift` 只导入 Foundation，不暴露
generated message。主要不变量：

- 节点 ID 由 thread ID、post ID、scope 和 source ordinal 组成；
- 输出与 wire 节点一一对应、严格保序，不跨 unknown 合并文本；
- unknown/meme 只保留 raw type 和安全 field-presence 诊断；
- 图片候选只保留可解析 HTTPS，按明确优先级去重；
- 外链只接受绝对 HTTP(S)，拒绝 credential/scheme/畸形目标；
- 图片尺寸区分 missing/malformed/non-positive/out-of-range/extreme；
- mention 仅保留 uid/label，不生成 profile route；
- video/voice 不播放、不拼 Android endpoint；
- poll 永远只读，`total_poll <= 0` 不做除法；
- `isDeleted#181 != 0` 是保守 iOS unavailable policy，保留 raw flag，
  不声称已证服务端值域。

ADR-0012 只将 handwritten generated import allowlist 从一个文件精确扩为
`PersonalizedProtocol.swift` 与 `ThreadContentProtoMapper.swift`。Feature/View
继续不可见 Proto；mapper 无 URLSession/HTTPClient/磁盘/Keychain/
MainActor 副作用。

## Renderer 与交互

`ThreadContentRenderer` 只消费领域值和注入的 `ImageLoading`：

- text/line break/long text 使用 Dynamic Type；
- link/image/video 可交互命中区不小于 44pt；
- image loading/success/failure 共用同一尺寸框，布局 ratio 限制在
  `0.5...3.0`，取消不映射为 failure；
- 无安全候选时不调用 loader；
- image 点击仅输出包含稳定 media ID/顺序的 `ThreadMediaIntent`；
- link/video 点击仅输出已验证的 `ExternalLinkIntent`；
- emoji/mention/video/voice/unknown/poll/empty/deleted/blocked 都有可访问
  降级表示；
- 无业务手势、Pager、MediaViewer、自定义动画或页面 overlay。

Debug Renderer Lab 包含 4 份 document fixture（mixed 23 节点、empty、
deleted、blocked），在 dark mode、Accessibility 大字号、Reduce Motion
组合下验证。Release isolation 要求 production Renderer 在源清单中，
但 Debug Lab、launch scenario、harness 和 canary 均不得进入 Release。

## 自动化覆盖与最终结果

行为先行证据：

- `20260801-073821-10588-unit.xcresult`：model 存在前单测按预期
  compile fail；
- `20260801-074504-16621-ui-smoke.xcresult`：Renderer Lab 存在前 UI
  smoke 按预期失败；
- 中间 UI 结果
  `075207-20493` / `075627-22528` / `075820-24151` /
  `075940-25763` / `080106-27307` / `080331-28906` /
  `080504-30510` / `080709-32157` / `080817-33663` /
  `081036-35301` 真实暴露并修复了菜单可达性、三态图片框、
  accessibility value、滚动方向和超长文本上界。这些结果不计为
  通过。

阶段 08 新增 20 项 mapper/cross-language test 与 6 项 Renderer
contract test；全仓 Unit 为 111 项。最终 `make quality` 从头退出 0：

- Debug build：`20260801-084337-67125-build.log`；
- Unit：`20260801-084339-67179-unit.xcresult`，111/111；
- iPhone UI smoke：`20260801-084408-67708-ui-smoke.xcresult`，13/13；
- iPhone interaction：`20260801-084900-69328-ui-interaction.xcresult`，5/5；
- iPad build：`20260801-085402-69867-ipad-build.log`；
- iPad UI smoke：`20260801-085404-69920-ui-smoke-ipad.xcresult`，3/3；
- iPad interaction：
  `20260801-085604-70212-ui-interaction-ipad.xcresult`，1/1；
- Release build：`20260801-085646-70369-release-build.log`，Build Succeeded；
- Release isolation：包含 `ThreadContentRenderer.swift`，排除 TestSupport 与
  全部 Debug Lab；
- `xcresulttool` 对五份最终 test bundle 确认 0 failed、0 skipped。

额外定向验收：

- iPhone Renderer：`20260801-083757-54280-ui-renderer.xcresult`，1/1；
- iPad Renderer：`20260801-084038-56604-ui-renderer-ipad.xcresult`，1/1。

## 未验证与剩余风险

1. 未发 live request；服务端 raw 分布、真实 malformed 形态、媒体可达性
   与分发权利仍为 `UNKNOWN`。
2. raw `9/27/35/40/20` 的业务原义、meme 完整语义、emoji 资源
   命中行为和 `isDeleted#181` 值域仍为 `UNKNOWN`。
3. quote 没有正文节点证据，保持 `UNKNOWN / NOT_MODELED`；换行只作为
   text 内的 `\n`。
4. 当前 Proto closure 不含 `Post.proto`/PBPage wrapper；普通楼层、楼中楼、
   fold/delete/block 的 wire 与 ThreadScreen 未验证。
5. 生产图片网络/cache/session/lease 实现不在阶段 08；本阶段只验证
   注入 seam 和 fixture loader。
6. 当前 UI/Unit 使用 iOS 26.5 Simulator；iOS 18.x、真机、VoiceOver
   实机操作与真实 iPad 分屏未验证。
7. 公开/App Store/商业分发仍被 ADR-0011 的权利边界阻塞。
8. 阶段 06 Pager/Media 仍为 `SPIKE_PARTIAL`，本阶段没有扩大或
   解决它的运行时风险。

## 变更类型与停止点

- 新增动画：无。
- 新增业务手势：无。
- 新增 overlay：无。
- 新增业务页面：无；仅新增 Debug-only 隔离 Renderer Lab。
- 新增生产依赖：无；继续使用 exact SwiftProtobuf 1.38.1。
- Android submodule 修改：无。

阶段 08 完成后必须停止。阶段 09 保持 `NOT_STARTED`，且在阶段 06
`SPIKE_PARTIAL` 验收条件关闭前保持阻塞。
