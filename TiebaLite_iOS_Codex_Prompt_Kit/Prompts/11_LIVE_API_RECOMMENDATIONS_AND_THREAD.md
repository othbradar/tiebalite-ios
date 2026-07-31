# 阶段 11：推荐与帖子首屏的 Live API 接入

目标：在不改变已验证 UI/交互状态机的前提下，把推荐和帖子首屏 repository 从 fixture 实现扩展为生产实现。UI tests 仍只使用 fixture。

## 前置

- 阶段 10 垂直链路完全绿色。
- 对应 endpoint 在 `Specs/API_EVIDENCE.md` 中证据充分。
- SwiftProtobuf mapper tests 已用脱敏真实样本验证。
- 工作树 clean，并记录阶段 10 绿色 commit。

## 核心原则

- 只替换 data/repository 路径，不顺手重写 View、导航、Pager 或动画。
- `AppEnvironment` 明确选择 fixture/live；Release 默认 live，UI test 强制 fixture。
- 真实网络不可用时不能破坏 fixture 测试或假称功能完成。
- 不把网络返回的 Proto 直接交给 View。

## 实现

### RecommendationsRepositoryLive

- 按证据构造 request。
- 正确编码分页参数/cursor。
- 映射 domain item，稳定 ID 与 fixture 路径一致。
- 服务端重复项、缺字段、未知贴类型安全处理。
- 区分 transport、HTTP、decode、server、authentication、cancelled。
- 不对每个 cell 单独请求可批量得到的数据。

### ThreadRepositoryLive（首屏）

- 按证据解析帖子元信息、楼层和内容节点。
- 图片 URL/尺寸/索引与 Media route 一致。
- 未知内容节点走既有降级，不增加临时 View 分支。
- 会话可选：匿名可读时不强制登录；需要认证时返回明确能力错误。

## Live 验证

创建 Debug-only、不可进入自动测试的 live smoke：

- 发出最少请求。
- 记录 endpoint 名、HTTP 状态、响应大小、decode 结果计数、耗时。
- 日志和附件严格脱敏。
- 不保存完整用户内容到 Git。
- 对 live 数据人工验证：空字段、图片、分页、删除贴、未知节点。

不得用 live 请求作为 `make quality` 的必要条件。

## 回归

- fixture 状态/UI tests 全部不改行为且通过。
- 新增 live repository 的 request/mapper/error/cancellation tests。
- 快速刷新和分页乱序仍由 Store 丢弃旧响应。
- 切回 fixture 环境时没有残留 Cookie/cache 影响。

## 停止条件

若 endpoint、签名或字段证据不足：

1. 不猜测。
2. 更新 `Specs/UNKNOWN_BEHAVIORS.md` 与 API evidence。
3. 保持生产 repository 对该能力返回可诊断 unsupported/unknown error。
4. 报告缺少的最小证据。

## 验收

- 生产 repository 可被 Debug live 环境调用。
- UI 与交互代码未发生无关重写。
- Fixture tests、unit tests、quality gate 全绿。
- Live 验证结果诚实记录。

完成后停止。
