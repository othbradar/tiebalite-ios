# ADR-0002：Feature 状态、Effect 与依赖注入

- 状态：Accepted
- 日期：2026-07-31
- 决策者：阶段 02 架构决策
- 关联阶段：02、04 及所有 Feature 阶段

## 背景

P0 列表需要区分首次、刷新、分页、取消、过期响应和会话变化。SwiftUI View
不能同时持有业务真相，异步 I/O 也不能因方便而全部放到 MainActor 或全局
singleton。项目当前没有采用状态管理框架的证据或批准。

## 必须满足的约束

- 每个 Feature 只有一个 UI 状态 owner。
- Action、异步 Event 和 effect 生命周期显式。
- 所有 UI 可观察状态只在 MainActor 修改。
- 网络、Session、缓存、图片和持久化的共享可变真相由 actor 或不可变值
  管理。
- Tab 暂时不可见不等于 route 被移除。
- 每个响应必须能被 request identity、generation、cursor 和 session lease
  判定是否过期。
- 测试可替换 clock、ID generator、HTTP、Session、cache 与 image loader。

## 候选方案

### A：Observation Store + 明确 Action/Event/Effect

- 优点：贴合 SwiftUI；接口小；状态机可直接 fixture 测试。
- 缺点：任务注册、取消和 stale guard 需要项目自行明确。
- 风险：若 reducer 与 effect 混写，仍可能产生隐式状态。
- 验证方式：纯 transition tests、反向完成顺序、取消与 route 生命周期测试。

### B：所有 Store 都做 actor，再增加 MainActor projection

- 优点：内部串行化明显。
- 缺点：普通 Feature 形成 actor state 与 UI projection 两份真相。
- 风险：额外 hop 和发布时序使动画/导航更难预测。
- 验证方式：证明 projection 不丢事件且没有双向写。

### C：引入 TCA 或全局 reducer/service locator

- 优点：现成 effect/test 工具。
- 缺点：新增未批准生产依赖，且可能掩盖本仓库已定义的领域状态。
- 风险：Feature public API 和迁移成本被框架绑定。
- 验证方式：必须先有独立依赖 ADR 和系统方案失败证据。

## 决策

选择 A。

每个普通 Feature 使用：

```text
@MainActor @Observable final Store
  private(set) State
  send(Action)
  receive(Event)        // 仅 effect runner 可调用
  taskRegistry[EffectKey]
```

`State`、`Action`、`Event` 和领域模型使用可测试的值语义；reducer 在
MainActor 同步完成状态转换并产生零个或多个 `EffectDescriptor`。Effect
runner 调用注入的 Sendable 协议，成功/失败/取消统一转换为带 identity 的
Event，再回到 Store。View 只读取 State、发送 Action，不直接调用
Repository。

普通 Store 的依赖和任务表使用 Observation 忽略标记，不成为 UI 状态。
禁止 `Task.detached`、无 key 的 fire-and-forget、以 deinit 作为唯一取消
机制和全局 Environment service locator。

Effect identity 至少包含：

```text
featureInstanceID + effectKind + generation + requestID
+ cursor/page（若有） + ProtectedDataLease（若受保护）
```

Store 在 effect 启动前注册 key；新 refresh、filter/sort 变化、route 移除或
session generation 变化按契约取消对应 key。Event 提交前 reducer 再次核对
完整 identity；仅依赖 Task cancellation 不足以防晚到结果。

所有 Feature Store 均由 `AppCompositionRoot` 的 Store factory 创建：

- AppCompositionRoot（MainActor）创建 app/scene scoped 依赖；
- route identity 决定 route-scoped Store；
- Repository/HTTP/Session/cache/image concrete 实现在 composition root
  组装；
- Feature 仅接收面向用户任务的小型协议和不可变 dependency struct；
- 测试直接注入 fake、controlled clock、deterministic ID 和 barrier。

跨 Feature 的 Session 是例外：canonical 内部 Session engine 由 actor
持有；SwiftUI 只能观察脱敏、带单调 revision 的
`SessionViewSnapshot/Capability`，不能观察含 credential handle、journal
或 retry ref 的内部状态。

## 所有权与生命周期

| 真相 | owner | 隔离 | 生命周期 |
|---|---|---|---|
| Feature UI state | Feature Store | MainActor | route/root |
| root path、overlay、auth continuation | AppNavigationStore | MainActor、per scene | scene |
| HTTP mutable transport state | HTTPClient concrete | actor/Sendable | app |
| Session credential/journal/capability | SessionController | actor | app |
| cache/image in-flight | 对应 repository | actor | app/namespace |
| View-local focus/瞬时布局 | View/Coordinator | MainActor/UIKit main thread | presentation |

Tab 切换保留 root Store 和任务，除非具体 Action 契约要求取消。route pop、
MediaViewer 关闭或 Feature deactivate 才取消 route-owned effect。取消错误
归一为 `CancellationError` 且不进入可见失败状态。

## 为什么不是其他方案

B 只用于真正跨 Feature 的共享 I/O 真相；普通 Feature 使用它会产生两份
可观察状态。C 在没有系统方案失败证据时违反依赖政策。

## 迁移/退出成本

如果 Observation 在目标 Xcode/Swift 版本出现已证编译或运行缺陷，可由新
ADR 把 UI projection 改为 `ObservableObject`；State/Action/Event、effect
identity、协议和测试不得改变。只有三处以上重复且纯 helper 无法消除时，
才评估轻量 reducer 抽象。

## 验收与回滚条件

- 每个列表覆盖 success/empty/failure/cancel/stale/overlap。
- 旧 refresh、旧 cursor、旧 session 的 Event 均无法提交。
- route pop 取消 route-owned effect；Tab 切换不丢 Store。
- 取消不显示错误；failure 不吞已有内容。
- Store 测试不依赖真实时间、随机 UUID 或网络。
- View、Feature 不读取 concrete singleton。

若需要 `asyncAfter`、`.id(UUID())`、全局 Store 重建或删除测试才能稳定，
立即回滚该 Feature 到最近绿色状态并重审 effect identity。
