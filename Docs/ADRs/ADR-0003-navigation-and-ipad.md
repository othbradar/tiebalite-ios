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
  selectedTab
  routesByRoot: [RootID: [RouteIdentity]]
  settingsPath: [SettingsRoute]     // 最多一个 Debug Shell route，不持久化
  presentedMedia?                   // 进程内
  presentedAuthentication?          // 进程内
  pendingAuthenticationContinuationByAttemptID
  pendingAuthenticationLaunchAfterCleanupByCleanupOperationID
  restorationRevision
}
```

### 阶段 05 Shell 选择澄清

阶段 05 提示词要求“推荐、关注的吧、设置/账户占位”三个主 Tab，而 P0
`RootID` 仍只有推荐与关注的吧。为避免 `selectedTab`/`selectedRoot` 双写，
Shell 使用单一 `AppTab = recommendations | followedForums | settings`；
只有前两项可投影为 `RootID` 并拥有 canonical routes。`settings` 是无业务
route、无 Feature Store、无持久化的静态 P1 占位。阶段 05 仅为 Debug
组件画廊保存最多一个强类型 `settingsPath`，使容器投影不依赖 SwiftUI 私有
path；Release 无入口，快照不保存。未来实现 P1 Settings 必须另行更新
route/恢复决策。本文统一称 `activeRoot = selectedTab.rootID`，不另存可写
`selectedRoot`。

iOS 26.5 运行证据表明 SwiftUI 系统 Tab bar 重按当前项会直接清空其
`NavigationStack` path，且该动作不经过 selection binding，违反本 ADR 的
P0 重选 no-op。阶段 05 因此保留 `TabView` 作为三个栈的生命周期容器，
隐藏其不可配置的系统 Tab bar，并在底部 `safeAreaInset` 使用三个显式
selection button。该 selector 只写 `selectedTab`，不实现手势、页面转场或
push/pop；NavigationStack 与系统 back/边缘返回保持系统实现。若后续系统
提供可关闭 reselect-pop 的公开 API，可移除 selector 并恢复系统 Tab bar，
canonical route/state 不变。

### 阶段 16B Settings 投影补充

ADR-0021 以受控的 `SettingsRoute` 替代了阶段 05 的静态
Settings 占位。`settingsPath` 现可包含 history/about/licenses，以及
由 history 打开的已有 Forum/Thread/UserProfile content route；语法仍由
`SettingsRouteGrammar` 白名单约束，不改变两个业务 root 的 canonical
`routesByRoot`。iPhone 继续使用 Settings 自身的系统
`NavigationStack`；iPad 将 Settings root 放在 content 列，将
`settingsPath` 投影到 detail 列。该扩展不纳入导航恢复快照，不保存
凭证或内容数据；阶段 05 对“静态占位/最多一个 Debug route”的
陈述仅作为历史决策背景保留。

当前 `RouteIdentity` 允许：

- `forum(validatedForumID?, validatedForumName)`
- `search`
- `thread(threadID)`
- `subposts(threadID, postID)`
- `userProfile(userID)`

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
- Settings Feature 拥有独立系统 NavigationStack，但不进入 `routesByRoot`；
  其 history/about/licenses/content 使用受控 `settingsPath`。
- Tab 切换只改 selectedTab，不改另一 root 的 routes/Store/anchor。
- 重选当前 Tab 在 P0 是 no-op：不 pop、不滚顶、不刷新。任何改变需后续产品
  决策和测试，不沿用 Android 全局刷新。

### iPad 投影

regular width 使用三列 NavigationSplitView：

- sidebar：selectedTab；两个 P0 root 与真实 Settings Feature 的 shell selector；
- content：当前业务 root 的推荐/关注吧列表，或 Settings root；
- detail：当前业务 root 的首 route及 tail，或 Settings 的受控 detail path，
  均投影到系统 NavigationStack。

compact width 把同一 selectedTab/routes 投影为 Tab + 完整 Stack。size
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

- selectedRoot（仅两个业务 RootID；若当前 selectedTab=settings，生成快照
  时确定性降级为 recommendations）；
- 各 root 的稳定 RouteIdentity；
- 各 root 的已批准非敏感列表 snapshot；
- 以 `(rootID, RouteIdentity)` 键控的非敏感 filter/read anchor snapshot；
- schema version。

不持久化 sessionID/token、Store、opaque NavigationPath、login attempt/
continuation、cleanup 后登录 launch request、MediaViewer、
MediaDescriptor/URL、transient loading/error。
也不持久化 settings 或其 Debug-only `settingsPath`；恢复只进入两个业务
Tab。
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
