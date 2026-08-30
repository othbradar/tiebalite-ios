# P0 执行计划与回滚点

状态：`IMPLEMENTED_THROUGH_PHASE_09_OPEN_SOURCE_BETA`

本文件只规划从空工程到稳定 P0 的小步阶段；阶段 02 不执行任何后续阶段。
每一阶段开始前必须有干净、可识别的绿色基线，结束时运行真实门禁并更新
`Docs/Progress/TASK_STATE.md`。形成“可提交差异”不授权自动 commit。

## 全局规则

- 一次只进入一个被用户明确授权的阶段。
- 输入门禁不满足即停止，不用占位实现绕过。
- 先 fixture/state/test，后 UI，再接 live adapter。
- Pager、MediaViewer、Motion、通用状态组件和共享服务各只有一个 owner。
- API/登录/许可证证据不足时允许该阶段保持 BLOCKED/fixture-only，不猜协议。
- 回滚到阶段开始的绿色 commit/差异；禁止 reset/clean 用户工作。
- 每次阶段出口执行最小相关测试、`make quality-fast`，阶段完成执行
  `make quality`；不能运行项逐项标 `NOT_TESTED`。

## 阶段 02：架构决策（历史）

- 输入：阶段 01 审计、route/state/API/Proto/content/UNKNOWN。
- 原子输出：ADR-0001…0010、Module/Route/Project/Dependency Map、风险审计、
  状态机补充。
- 门禁：文档内部一致；每个高风险区有候选/选择/回滚；无 Swift/project/
  依赖变化；Android clean。
- 回滚点：`6f10e38`。

## 阶段 03：最小工程 Scaffold

- 输入：ADR-0001、MODULE_MAP、DEPENDENCY_POLICY。
- 原子输出：`project.yml`、配置、App/Unit/UI 三 target、shared scheme/test
  plan、工具版本清单、最小启动壳；不创建业务页面。
- 门禁：连续两次 generate 稳定；无签名 iPhone/iPad build；unit/UI 空壳
  可执行；unit/ui/tests mode 与 canonical test plan 一致。
- 回滚：删除本阶段可解释的 scaffold 输出，回到阶段 02 绿色文档；不手改
  `.pbxproj`。

## 阶段 04：确定性测试 Harness

- 输入：ADR-0002、0009、0010，阶段 03 工程。
- 原子输出：controlled clock/ID/barrier、MockHTTPClient、fixture loader、
  LaunchScenario registry、diagnostics recorder、禁止 `print`/raw dump/
  直接 Logger 绕过的静态规则及正反 canary。
- 门禁：Release 不可达 TestSupport；未知 scenario fail-fast；无 sleep/live
  network/secret；日志绕过规则能拦截 canary 且不误报批准封装；示例
  stale/cancel test 绿色。
- 回滚：移除未通过的 harness seam，保留最小编译壳。

## 阶段 05：DesignSystem 与 App Shell

- 输入：ADR-0003、ROUTE_MAP、交互/动效契约。
- 原子输出：Motion/token、Loading/Empty/Error family、两 root shell、
  canonical navigation state 的 fixture UI。
- 门禁：两个 root 独立 path/store；当前 Tab 重选 no-op；deep link parser
  fixture；深色/大字体/Reduce Motion 基线。
- 回滚：保留 domain route/state，替换容器投影；不自定义全局导航动画。

## 阶段 06：Pager/Media 隔离 Spike

- 输入：Proposed ADR-0004/0005 和 deterministic harness。
- 原子输出：SwiftUI/UIKit Pager 候选的隔离证据、Media zoom/gesture/lifetime
  spike、候选结论。
- 门禁：ID reconcile、取消/反向、边缘返回、resize、VoiceOver、资源上界
  全部通过；ADR 改 Accepted。
- 回滚：淘汰候选完整删除；生产树只允许胜者一个 Pager。两者都失败则回到
  显式按钮降级方案并停阶段。

## 阶段 07：Networking / Protobuf Foundation

- 输入：ADR-0006、DEPENDENCY_POLICY、API/PROTO evidence。
- 原子输出：HTTPClient/Endpoint/AuthContext、fixture adapter、mapper seam；
  仅在权利门禁关闭时加入 exact SwiftProtobuf 和最小 generated target。
- 门禁：HTTPS/redirect/auth tests、golden/malformed/unknown field、生成可重复、
  UI 无 generated import、许可证记录完整。
- 回滚：保持 fixture-only；不得以 HTTP 或全量复制 321 schema 获得绿色。

## 阶段 08：Thread Content Domain/Renderer

- 输入：CONTENT_NODE_MATRIX、fixture harness、domain/mapper 边界。
- 原子输出：Sendable ContentNode、mapper、统一只读 renderer 和降级组件。
- 门禁：18 类目标状态、unknown 999、坏尺寸/URL/author/pids、poll total=0；
  大字体/VoiceOver/深色无 crash/裁切。
- 回滚：未知节点退化为安全占位，不删除测试或静默丢节点。

## 阶段 09：生产 MediaViewer

- 状态：`PHASE_09_PRODUCTION_MEDIA_VIEWER_COMPLETE`（Open-Source Beta）。
- 输入：阶段 06 已 Accepted Pager/Media ADR、阶段 08 media domain。
- 原子输出：唯一 Viewer、生产 Pager/zoom 迁移、固定 intent 图片状态、
  结构化取消/清理与 fixture UI；本阶段不实现边界 Repository 或 live 图片。
- 已执行门禁：单图/三图、pinch/双击/pan、zoom 后不误翻页、切页 reset、
  旋转、失败黑底、5 次开关、iPhone/iPad smoke、Unit、quality-fast/quality。
- Beta 延期：100 张 full-resolution 资源压力、真机/iOS 18.x、真机
  VoiceOver、真实 split divider 和 live/cache/downsample/candidate/lease。
- 回滚：回到单图/显式前后按钮降级，不复制第二 Viewer/Pager。

阶段 10 保持 `NOT_STARTED`；只有新的明确用户指令才可进入。

## 阶段 10：推荐流 Fixture 垂直切片

- 输入：阶段 04/05/07/08，Recommendation state contract。
- 原子输出：fixture Repository → Store → SwiftUI 的首个完整 slice。
- 门禁：initial/empty/failure、refresh 保留、分页/重叠/旧响应、返回与 Tab
  保持、UI smoke。
- 回滚：保留 fixture/domain，回退最后一个未通过的 UI/effect diff。

## 阶段 11：受证据约束的 Live Recommendations/Thread

- 输入：对应 HTTPS、最小参数、auth、fixture、错误/分页
  `RUNTIME_EVIDENCE`。
- 原子输出：可关闭的 live adapter；fixture adapter 始终保留。
- 门禁：无 session/测试 session 对照、脱敏 fixture、live/fixture contract
  tests、无 HTTP/secret。
- 回滚：任何漂移立即禁用 live adapter 回 fixture-only；证据不足时本阶段
  合法状态是 BLOCKED，不强行完成。

## 阶段 12：Session / Login

- 输入：ADR-0007 已满足接受条件、合法 HTTPS/login UX 与 taxonomy。
- 原子输出：Vault、SessionController、journal/ledger、lease、显式登录容器。
- 门禁：所有 crash midpoint、重复/旧 callback、expired→cleanup→signedOut
  →new login、late protected write、日志/附件 canary。
- 回滚：关闭 production login，保持 signedOut + fixture Session；不降级
  HTTP/隐藏 WebView。

## 阶段 13：关注的吧

- 输入：Session capability、已验证 HTTPS FollowedForums adapter 或 fixture。
- 原子输出：按 session 原子聚合的完整只读列表。
- 门禁：中间页失败不发布半成品、failedPage retry、切账号立即隐藏、过期/
  cleanup、返回 anchor。
- 回滚：live 不满足门禁时回 fixture-only，不展示跨账号旧 membership。

## 阶段 14：Forum 首页与主题列表

- 输入：FRS/ThreadList/GeneralTab fixture 与状态契约。
- 原子输出：header 与 per-tab timeline、sort/classify、分页。
- 门禁：独立错误、动态 tab fallback、30-ID batching、重复/乱序/stale、
  iPad detail。
- 回滚：未知动态 tab 降级 latest，不按 index 猜 identity。

## 阶段 15：完整 ThreadReader/Subposts

- 输入：PB/PBFloor fixture、内容 renderer、MediaViewer。
- 原子输出：首/前/后页、anchor/filter/sort、楼中楼、Media 打开/返回。
- 门禁：删除/私密/缺作者、重叠页、anchor 消失、并发/stale、父状态保持。
- 回滚：不可识别 payload 显示 unavailable，不强制解析或删除测试。

## P1 阶段 16A/16B/16C

Search、History/Settings、UserProfile 均为 P1，不是 P0 稳定出口前置。
阶段 16A 已在单独授权下实现 Hybrid JSON 搜吧/搜帖、搜帖证据范围内的
顺序分页和到现有 Forum/Thread route 的导航；因真实搜帖结果的最终
ThreadReader 人工点击尚未完成，状态保持 `RUNTIME_EVIDENCE_PARTIAL`。
阶段 16B 已在单独授权下实现本地 thread/forum/user 历史、真实生效的
外观/阅读设置、ThreadReader 作者到基础用户资料的 route、Fixture 及
Profile Proto request/mapper。`PHASE_16B_HISTORY_SETTINGS_PROFILE = COMPLETE`。
搜索联想、用户搜索、用户帖子/关注/粉丝列表、云历史和阶段 16C
仍保持 deferred；阶段 17 为 `NOT_STARTED`。

## 阶段 17：iPadOS 适配强化

- 输入：全部 P0 fixture slice。
- 原子输出：regular/compact 投影、旋转/分屏恢复、选中与滚动保持。
- 门禁：两种 iPad 尺寸/至少两个窗口宽度、collapse/expand、系统 back、
  Pager/Media resize。
- 回滚：只回滚容器投影，不分叉业务 Store/Repository。

## 阶段 18：可访问性、性能与韧性

- 输入：P0 功能完整、diagnostics/signpost。
- 原子输出：VoiceOver/Dynamic Type/Reduce Motion、滚动/decode/内存与故障矩阵。
- 门禁：测试矩阵、性能预算、无泄漏/死循环/主线程持续阻塞。
- 回滚：关闭非核心优化/prefetch，保留正确性；不全局禁动画掩盖问题。

## 阶段 19：Parity 与发布前检查

- 输入：全部 P0 绿色、许可证/服务/品牌/隐私决定。
- 原子输出：最终差距、release configuration、notice、发布证据。
- 门禁：`make quality`、完整设备矩阵、secret/license/size/privacy review；
  所有发布阻塞关闭。
- 回滚：任一权利、登录、live API 或隐私阻塞未关闭即停止发布；fixture
  build 不能冒充可发布产品。

## 跨阶段阻塞

| 阻塞 | 影响 | 安全停留状态 |
|---|---|---|
| Proto 来源/许可证未决 | 阶段 07 generated/live | clean-room 或 fixture-only |
| HTTPS/最小参数/error taxonomy 未证 | 阶段 11/13/14/15 live | fixture adapter |
| 登录 UX/callback/Cookie cleanup 未证 | 阶段 12/13 | signedOut + fixture Session |
| Pager/Media spike 不通过 | 阶段 09 | 显式按钮/单图降级 |
| 发布权利/服务条款未决 | 阶段 19 | 不发布 |

任何阻塞都不能通过降低 TLS、测试、并发检查、隐私或许可证要求绕过。
