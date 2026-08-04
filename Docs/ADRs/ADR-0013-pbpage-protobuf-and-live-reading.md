# ADR-0013：阶段 11 PBPage Proto 与 Live Reading 边界

- 状态：Accepted
- 日期：2026-08-04
- 决策者：阶段 11 只读 Live API 接入
- 关联阶段：07、08、10、11
- Supersedes：仅扩展 ADR-0011 的 schema 闭包与 ADR-0012 的 Core adapter
  allowlist；不改变本地/个人/非商业许可与公开分发阻塞

## 背景

阶段 11 需要把公开帖子首屏的 `PbPageResponse` 映射到阶段 10 已验证的
`ThreadReaderSnapshot`。锁定 Android reference 的生产调用使用
`PbPageRequest/PbPageResponse`，首楼正文来自
`PbPageResponse.data.first_floor_post#38 -> Post.content#5`，普通楼层来自
`post_list#6 -> Post.content#5`。阶段 08 的
`ThreadInfo.firstPostContent#142` 只是合成 fixture carrier，不能替代 PBPage
wrapper，也不能通过构造临时 ThreadInfo 绕过缺失 schema。

PBPage request closure 为 6 个输入，response closure 为 119 个输入，二者合并
为 125 个；与现有 Personalized 51-file closure 重叠 50 个。一个统一的
GeneratedProtobuf target 因而需要锁定 126 个输入并新增 75 个生成文件。创建
第二个 generated module 会复制 50 个同名 message，破坏类型单一性。

## 决策

1. 继续只从 read-only Android submodule commit
   `5545326b2a8e0d784b2f3dfbcb219c7b121e61c2` 生成；不复制 `.proto` 到 iOS
   源码树。
2. 历史路径 `Config/Protobuf/Personalized.inputs.tsv` 扩展为三个 root 的联合
   hash/import lock：`Personalized.proto`、`PbPage/PbPageRequest.proto`、
   `PbPage/PbPageResponse.proto`。文件名为兼容既有门禁保留。
3. `scripts/generate_protos.sh` 必须证明三 root 的递归 closure 与 126-file
   manifest 完全相等，并继续两次 clean generation、hash 与 zero-drift 验证。
4. 新增唯一 `PBPageProtocol.swift` Core adapter。它可以导入 generated runtime，
   但只能构造/解码 PBPage、白名单映射为现有 Core domain；generated message
   不得进入 Feature、View、日志或缓存。
5. `ThreadContentProtoMapper` 提取纯 `Post.content` message 映射入口，保持现有
   URL、尺寸、unknown node、稳定 ID 与 MediaIntent 契约；不得 serialize 到
   临时 ThreadInfo 再 decode。
6. 请求只采用 Android 静态 call-site 的无敏感候选字段；Debug Probe 只分层记录
   Personalized transport/decode 观察，不能把候选集合称为服务端最小字段，
   也不能外推到未运行的 PBPage。不得复制 Cookie、BDUSS、STOKEN、CUID、
   安装 ID、定位占位或设备 telemetry。
7. Debug Probe 不进入 UITesting/Release，不保存 raw response，不记录正文、URL、
   token 或用户字段；自动化继续只使用合成/脱敏 fixture。

## 映射与隐私边界

- route `threadID` 是请求身份；wire 中出现不一致的正 thread ID 时返回 typed
  mapping failure，不静默打开另一贴。
- `Post.id` 的 UInt64 到 Int64、floor 的 UInt32 到 Int 必须 checked conversion；
  不生成 UUID 代替非法业务身份。
- 作者只读取 public id/name/nameShow；缺失作者降级为“未知作者”。
- `data.user`、`User.BDUSS/passwd`、`Anti.tbs`、写操作/验证码字段全部忽略。
- 首楼优先使用 `post_list` 中 floor 1，否则使用 `first_floor_post`；普通楼层按
  正 post ID 首次出现去重并保持服务器顺序。
- 本阶段只接首屏；`Page` 可以作为诊断 evidence，但不据此提前实现分页。

## 许可与发布

本决策沿用 ADR-0011 的项目负责人边界：仅允许当前本地、个人、非商业项目从
锁定 submodule 生成最小 endpoint closure。Android reference 按 GPL-3.0 审慎
处理，README 非商业声明、文件级 Proto provenance、notice/源码义务、服务 API
使用权与品牌边界仍未关闭。公开分发、App Store 和商业使用继续阻塞；本 ADR
不构成法律意见。

## 验证与回滚

必须通过 `make verify-protos`、generated import 精确 allowlist、Release/UI test
隔离、fixture mapper tests、live repository mock tests、secret scan 与完整 quality
gate。若真实 PBPage 的匿名能力、MIME、最小参数或 mapping 无法由脱敏 probe
验证，Production Thread repository 必须返回可诊断 unsupported/unknown，不能
回退到伪装的 fixture 或猜字段。

回滚时删除 PBPage adapter/live repository，恢复三个 root 前的 manifest 与生成
输出；Fixture reading flow、阶段 08 renderer 和阶段 09 MediaViewer 保持可用。
