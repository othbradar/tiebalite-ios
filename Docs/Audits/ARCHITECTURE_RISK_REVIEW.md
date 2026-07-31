# 阶段 02 架构风险审查

状态：`PASSED_WITH_PROPOSED_AND_RUNTIME_RISKS`

## 审查基线

- 主仓库基线：`6f10e38`（阶段 01 绿色提交）。
- Android reference：`4.0-dev@5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`，
  审查时 clean 且与 lock 一致。
- 方法：读取根/Specs/Docs 规则、阶段 01 规格、阶段 02 prompt，并显式使用
  `.agents/skills/ios-architecture-review/SKILL.md`。
- 范围：ADR、规格、执行计划的静态审查；没有 Swift、Xcode、Simulator
  交互 spike、真实 API、登录或依赖变更。

## 结论

阶段 02 已为每个共享基础设施指定唯一 owner、允许依赖、候选、当前选择和
退出条件。静态审查未发现未记录的 P0 架构矛盾。

以下决策仍有意保持 Proposed：

- ADR-0004 PagerContainer：等待阶段 06 SwiftUI/UIKit 对照 spike。
- ADR-0005 MediaViewer：等待 Pager、UIScrollView gesture/lifetime spike。
- ADR-0007 Session/Login：production 登录等待 HTTPS、平台、Cookie 与
  runtime evidence；当前安全默认是 fixture-only。

Accepted 不表示对应代码已实现或运行验证；所有工程/测试状态仍为
`NOT_CREATED/NOT_TESTED`。

## 审查中关闭的规格矛盾

| ID | 原矛盾 | 修正 |
|---|---|---|
| C-01 | thread anchor/filter/sort 同时被当作 route 参数和稳定 Store identity | 拆为 RouteIdentity(threadID) 与一次性 NavigationIntent |
| C-02 | login 出现在“可恢复 route”表，但 continuation 明确进程内 | 改为非持久 Authentication presentation |
| C-03 | iPad selection 与 per-root path 可能成为双重真相 | canonical routes 唯一；SplitView selection 只派生 |
| C-04 | Media Store 与 UIScrollView 都可能持精确 transform | 几何量只归 ZoomPage coordinator；Store 只持离散 capability |
| C-05 | FollowedForums 可“逐页提交”与原子 membership 契约冲突 | Repository 内部聚合，Store 只收完整集合或 failedPage failure |
| C-06 | expired 可直接 newLogin，但 commit journal 不覆盖旧 session 替换 | expired 先 durable cleanup 到 signedOut，再建新 attempt |
| C-07 | 取消请求后仍可能晚到写受保护 cache | 增加 ProtectedDataLease，并在每次写入前复核 generation |
| C-08 | Android optional endpoint 可隐式读取全局账户 | iOS 每请求显式 AuthContext anonymous/active/candidate |
| C-09 | cleanup retry 以可空 completion attempt 充当身份 | cleanupOperationID 跨 preparation/deletion retry 稳定，requestID 每次更新 |
| C-10 | root 列表 safe snapshot 无 RouteIdentity，恢复键无落点 | 拆成 root key 与 `(rootID, RouteIdentity)` route key |
| C-11 | 图片隐私 scope 与 retention 混成一组枚举 | CacheScope 与 CacheRetention 正交；unknown 强制 noStore |
| C-12 | test plan 被当作 Simulator destination owner | test plan 管测试配置，runner/project.env 管 destination，并设映射门禁 |
| C-13 | Session 直连 transport、Core concrete conform Feature protocol 会反转依赖 | Session-owned client protocol + App 注入；Repository contracts 固定在 Core inward boundary |

## 风险登记

| ID | 风险/失败场景 | 影响 | 控制与 owner | 证明状态 / 回滚 |
|---|---|---|---|---|
| R-01 | SwiftUI View identity 因 index/可变 intent 重建，列表或 route Store 串页 | 高 | stable domain ID；AppNavigationStore；Feature Store registry | 静态已定义；UI `NOT_TESTED`。失败回滚容器投影 |
| R-02 | refresh/page/filter 反向完成，旧结果覆盖新 state | 高 | EffectIdentity、generation/cursor、Store 二次校验 | deterministic tests 待阶段 04 |
| R-03 | actor cancellation 后 late protected write 污染新/已退出 session | 高 | SessionController + ProtectedDataLease + write-before-commit check；safe dismiss 新 generation | fixture/crash tests 待阶段 04/12 |
| R-04 | Pager 取消/反向/数据刷新使 ID、视觉页和生命周期不一致 | 高 | InteractionKit 单一 owner；ADR-0004 Proposed spike | 未验证；失败淘汰候选，不复制实现 |
| R-05 | UIScrollView/Pager 同时拥有手势或 zoom 复用串页 | 高 | gesture-begin 固定 owner；几何单 owner；MediaViewer | 未验证；失败降级单图/按钮 |
| R-06 | 真实 API 参数、终止、错误码或 auth 漂移 | 高 | Endpoint evidence gate、fixture/live adapter 分离、kill switch | 50 项 UNKNOWN；失败回 fixture-only |
| R-07 | Proto schema 复制/生成触发未知许可证义务 | 高 | minimal closure、来源 manifest、权利门禁、clean-room 备选 | 未关闭；不得复制/生成 |
| R-08 | 图片缓存 key/namespace 泄漏跨账号资源 | 高 | ImageRepository、正交 scope/retention、lease、unknown noStore | strict concurrency/privacy tests 待后续 |
| R-09 | iPad collapse/expand 写回第二份 selection，route 丢失 | 高 | canonical routes；SplitView 单向投影 | iPad UI `NOT_TESTED`；回滚投影 |
| R-10 | XcodeGen/tool drift 导致 scheme/resource/test plan 不一致 | 中 | project.yml source of truth、version gate、regen tests | 阶段 03 验证 |
| R-11 | LaunchScenario/TestSupport 进入 Release 或未知 scenario 回 live | 高 | UITesting 白名单、Release source exclusion、fail-fast | 阶段 03/04 验证 |
| R-12 | 日志/xcresult 泄漏 URL、token、正文或 raw error | 高 | DiagnosticsClient allowlist；阶段 04 扩展 forbidden scan/canary | 契约完成；现有 scan 尚不拦 print/直接 Logger，实现 `NOT_IMPLEMENTED` |
| R-13 | 初期单 App target 无法编译级强制模块边界 | 中 | 目录/API/scan/review；Generated 后续单 target | 接受；发生越层再按门禁拆 target |
| R-14 | 系统图片管线无法满足 decode/内存/取消性能 | 中 | 最小 Data cache、metrics、第三方依赖新 ADR | 未测；先回 noStore/memory-only |

## Swift 6 并发审查

- 普通 Feature Store 是 MainActor owner；不把 I/O actor 化后再复制一份 UI
  truth。
- HTTP/Session/Persistence/Image 的共享可变状态由各自 actor 持有。
- 每个 await 后需要重新验证 operation/request/session identity。
- generated Message、UIImage/CGImage 在 SDK Sendable 状态未证明前不跨 actor。
- 不允许 `Task.detached`、无父 fire-and-forget、`@unchecked Sendable` 默认
  豁免或吞 CancellationError。
- Tab 切换不自动取消；route removal、generation change 和 session revoke
  使用明确 EffectKey。

剩余风险是编译器/SDK 标注和 actor reentrancy 的运行实现，阶段 03/04 strict
concurrency build 与反向 completion tests 才能关闭。

## SwiftUI / UIKit interop

- iPhone/iPad 共用 canonical routes，UIKit/SwiftUI 容器只能投影。
- Pager 候选都必须使用稳定 PageID 和 transition token。
- Media 的 UIScrollView coordinator 是精确 zoom owner；Store 不镜像几何。
- UIKit controller/delegate 必须在转场完成/关闭时清理，生命周期以
  weak/deinit probe 验证。
- 左边缘返回无法通过公开 API 保证时降级为显式切换，不使用私有 recognizer。

## 网络、Session 与隐私

- `optional-in-request` 不是 iOS 自动认证策略；AuthContext 必须显式。
- HTTPS→HTTP/跨 host redirect 默认拒绝；HTTP login/picPage 保持 BLOCKED。
- internal SessionState 不直接暴露 UI；只发布脱敏 capability snapshot。
- expired reauthentication 不做原地替换，先 journaled cleanup。
- 日志只用 symbolic endpoint/result；raw URL/query/header/body/Error 禁止。
- 真实账号 payload 默认不落盘，fixture 必须脱敏并带 hash/evidence。

## 测试与可观测性

最小确定性证明集合：

1. refresh/page/filter 反向完成与 cancel。
2. route pop/Tab 切换的 effect 生命周期。
3. FollowedForums 中间页 failure 不发布半成品。
4. old session invalidation 与 logout 后 late cache write。
5. 每个 Session commit/cleanup await 与 crash midpoint。
6. Proto presence/unknown tag/malformed mapping。
7. Pager transition token、ID reconcile、边缘返回与有界 controller。
8. Media zoom/pager owner、reset、resize、资源释放。
9. Navigation snapshot 未知版本整份丢弃；已知版本坏 route 取最长合法前缀。
10. diagnostics/xcresult secret canary 与 Release TestSupport exclusion。

## 未验证项

- 无 `project.yml`、Swift 源码、scheme 或 test plan。
- build、unit、UI smoke、iPad build 全部 `NOT_TESTED`。
- Pager/Media 没有 Simulator spike。
- 真实 API、登录、Cookie、Proto generation、图片性能没有运行证据。
- iOS 18.x runtime 当前环境不可用；最低部署兼容性需后续独立验证。

## 阶段 02 审查出口

可接受的剩余项均已明确落在 Proposed ADR 或
`Specs/UNKNOWN_BEHAVIORS.md`，没有以架构文档宣称已验证。进入阶段 03 前应
审查本阶段差异；只有新的用户指令才能开始 scaffold。
