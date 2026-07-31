# ADR-0003：导航、iPad 投影与状态恢复

- 状态：Accepted
- 日期：2026-07-31
- 决策者：阶段 02 架构决策
- 关联阶段：02、05、17

## 背景

P0 有推荐与关注吧两个 root；每个 root 必须保留独立路径、列表和滚动状态。
iPhone 使用 NavigationStack，iPad 使用 NavigationSplitView，但容器切换
不能产生第二份 route 真相。阶段 01 的 route 还把 anchor/filter/sort
混入 route 参数，并把 login 列在 route 表中，需要在实现前收敛身份边界。

## 必须满足的约束

- 每个 scene 只有一个 AppNavigationStore。
- root 之间 path 和 Store identity 隔离。
- route identity 只含稳定、最小、可验证业务 ID。
- iPhone/iPad/compact 只是同一状态的不同投影。
- 系统返回与系统容器保持可用，不自定义全局 push/pop 动画。
- 恢复数据不含凭据、URL、Proto、私密正文或进程内 continuation。

## 候选方案

### A：per-root 强类型 route 数组作为 canonical state

- 优点：iPhone/iPad 共用；可版本化、测试和逐段校验。
- 缺点：SplitView 的 selection/detail 需要派生映射。
- 风险：映射若反向写入两套状态会分叉。
- 验证方式：宽度往返后 canonical routes 逐项相等。

### B：一个全局 NavigationPath

- 优点：表面实现简单。
- 缺点：root 状态、类型与恢复边界模糊。
- 风险：Tab 切换清栈、跨 root Store 串用。
- 验证方式：两个 root 同时 push 不同链；此方案无法自然满足。

### C：iPhone path 与 iPad selection 分别存储

- 优点：各容器代码局部直接。
- 缺点：同一业务选择存在双重真相。
- 风险：折叠/展开、旋转后 detail 与 path 不一致。
- 验证方式：反复 resize 后比较两套状态；维护成本不可接受。

## 决策

选择 A。每个 scene 的唯一模型是：

```text
AppNavigationState {
  selectedRoot
  routesByRoot: [RootID: [RouteIdentity]]
  presentedMedia?                   // 进程内
  presentedAuthentication?          // 进程内
  pendingAuthenticationContinuationByAttemptID
  pendingAuthenticationLaunchAfterCleanupByCleanupOperationID
  restorationRevision
}
```

`RouteIdentity` 只允许：

- `forum(validatedForumName)`
- `thread(threadID)`
- `subposts(threadID, postID)`

thread 的 anchor、author filter、sort、可选 forum context，以及 subposts 的
targetSubpostID/forum context 是 `NavigationIntent`。它们不参与 Hashable
identity、Store key 或 route 去重，也不存入按 identity 键控的 map。
NavigationCommand 在 MainActor 上创建/复用 `(sceneID,rootID,identity)` Store
后立即、恰好一次派发 intent；只有派发成功才完成命令。后续同 root 再以新
intent 打开同一 identity 时 pop-to/reuse，并向既有 Store 发 Action，不压入
第二个相同业务页面。

Store key 固定为 `(sceneID, rootID, RouteIdentity)`。Store 在 root 或 route
仍存在时保活；pop/replace 的转场完成后释放被移除 route 的 Store。不得把
Store 自身持久化。

### iPhone 投影

- 两个 root 各自一个系统 NavigationStack。
- Tab 切换只改 selectedRoot，不改另一 root 的 routes/Store/anchor。
- 重选当前 Tab 在 P0 是 no-op：不 pop、不滚顶、不刷新。任何改变需后续产品
  决策和测试，不沿用 Android 全局刷新。

### iPad 投影

regular width 使用三列 NavigationSplitView：

- sidebar：root selector；
- content：当前 root 的推荐/关注吧列表；
- detail：当前 root 的首 route，余下 routes 投影到 detail 内的
  NavigationStack。

compact width 把同一 selectedRoot/routes 投影为 Tab + 完整 Stack。size
class、旋转或 split resize 不能写回、截断或重排 canonical routes。
SplitView selection 从 routes 派生，不作为第二份可写业务状态。

content 列选择新对象时以单个 NavigationCommand 替换当前 root 的 detail
chain；detail 内继续 push 才追加 tail。系统 collapse/expand 只改变投影。

### Deep Link

cold/warm deep link 都在 restoration 完成后原子应用同一 NavigationCommand：

- Forum：选择 recommendations root，并把该 root chain 规范化为
  `[forum]`；
- Thread：选择 recommendations root，并把该 root chain 规范化为
  `[thread]`；
- 未选 root 的 chain 完全不变；
- App 内点击继续使用来源 root；
- 坏参数不改变现有导航状态。

### 恢复

持久化显式版本化、白名单 Codable DTO，仅包含：

- selectedRoot；
- 各 root 的稳定 RouteIdentity；
- 各 root 的已批准非敏感列表 snapshot；
- 以 `(rootID, RouteIdentity)` 键控的非敏感 filter/read anchor snapshot；
- schema version。

不持久化 sessionID/token、Store、opaque NavigationPath、login attempt/
continuation、cleanup 后登录 launch request、MediaViewer、
MediaDescriptor/URL、transient loading/error。
未知 schema version 不按 V1 猜测，整份 snapshot 丢弃并回默认
recommendations root。仅在已知 version 内逐段校验 route grammar；遇到坏
ID 时恢复最长合法前缀。Media/login 活跃时进程终止，只恢复父 route；
Session journal/ledger 由 Session 子系统独立恢复。

## 为什么不是其他方案

B 违反 Tab 独立路径；C 在 iPad 折叠与恢复时产生不可仲裁的双真相。保存
opaque NavigationPath、View 或 Store 既不可迁移，也不符合隐私边界。

## 迁移/退出成本

容器投影可以在不改变 canonical route、Store key 和 restoration DTO 的
前提下替换。若三列投影在目标系统有已证缺陷，可回退为两列 split +
detail NavigationStack；不得回退为独立 iPad path 或自定义全局导航。

## 验收与回滚条件

- 两 root 分别 push Forum/Thread/Subposts，切换 20 次状态不变。
- regular → compact → regular 后 routes 逐项相等、详情 ID 不变。
- 同一 thread 从两个 root 打开 Store 隔离；同 root 新 anchor 不重复 Store。
- cold/warm deep link 产生同一 canonical chain，另一 root 不变。
- snapshot 缺字段、坏 ID、未知版本均确定性降级且不 crash。
- login/media 活跃时杀进程，只恢复父 route。
- pop 后 detail Store 可释放；root Store 和列表 anchor 保留。
- 系统 back/边缘手势保持可用。

若 resize 导致 route 丢失/重复、跨 root Store 串用，或修复需要自定义全局
push/pop，回滚容器投影到最后绿色版本，保留 canonical route 模型。
