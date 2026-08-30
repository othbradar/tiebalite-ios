# 阶段 16A：贴吧和帖子搜索审计

- 日期：2026-08-30
- 基线：`3612c7b015a3c613319f739f15bf14a813f21bc4`
- Android reference：`5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`
- 决策：`ADR-0020-hybrid-search-and-navigation-beta.md`
- 状态：`PHASE_16A_SEARCH = RUNTIME_EVIDENCE_PARTIAL`
- 后续阶段：`PHASE_16B_HISTORY_SETTINGS_PROFILE = NOT_STARTED`

## 目标与边界

本轮只实现搜吧、搜帖、Fixture/Live Repository、结果导航与
证据明确的搜帖顺序下一页。没有实现用户搜索、搜索联想、
历史、设置、资料页或阶段 16B。

共享 `VirtualizedList`、ForumHome/ThreadReader 生产列表、Pager、
MediaViewer、ThreadContentRenderer、Session/Keychain、Personalized/FRS/
PBPage 协议均无修改。

## Android 与请求证据

| 能力 | Android symbol | iOS request | response |
|---|---|---|---|
| 搜吧 | `AppHybridTiebaApi.searchForum` → `SearchForumViewModel` | `GET https://tieba.baidu.com/mo/q/search/forum?word=...` | `SearchForumBean` JSON |
| 搜帖 | `AppHybridTiebaApi.searchThread` → `SearchThreadViewModel` | `GET /mo/q/search/thread?word=...&pn=N&st=5&tt=1&ct=1&is_use_zonghe=1&cv=99.9.101` | `SearchThreadBean` JSON |

两者均是 Hybrid JSON，不是 Protobuf。Production 以匿名
`EndpointDescriptor` 请求，不读取 Keychain/Session，不发 Cookie。
Android 的 `NO_ST_PARAMS/NO_COMMON_PARAMS` 是客户端内部控制 header，
iOS 没有把它们发到 wire。

thread 以 `pn=1` 起始，仅 `has_more == 1` 时请求
`pn + 1`，且必须精确响应 `current_page`。forum 只保留首屏；
Android 当前 ViewModel 无搜吧下一页请求，因此 iOS 不猜参数。

## 实现和状态

- `SearchRepository` 仅输出 `ForumSearchResult`/
  `ThreadSearchResult` 领域值；View 不接触 HTTP、JSON DTO、Cookie 或 Proto。
- `SearchState = idle | searching | loaded | empty | failed | loadingMore`。
  首屏失败可重试；下一页失败保留已有结果并重试同页。
- 一个 Task + generation 处理新关键词取消、迟到响应、分页单飞和
  View 离开。不使用 delay/debounce 猜时序。
- 搜索只在用户点击按钮或键盘 submit 时执行；空白关键词零请求，
  相同已完成关键词不无故重复。提交后收起键盘，下方结果可点击。
- forumID/threadID 第一次出现优先且保序；不使用随机
  identity。帖子距末尾 4 项时通过现有列表 prefetch 进入 Store-owned
  分页意图。
- `RouteIdentity.search` 复用 recommendations root 的导航树。
  iPhone push，iPad replace detail；搜吧结果 push 现有 ForumHome，
  搜帖结果 push 现有 ThreadReader。

## 脱敏 Live 运行证据

| 能力 | HTTP | MIME | bytes | decode | mapped/new | typed error |
|---|---:|---|---:|---|---:|---|
| forum | 200 | `application/json` | 36555 | true | 48 | none |
| thread page 1 | 200 | `application/json` | 59907 | true | 20 | none |
| thread page 2 | 200 | `application/json` | 66555 | true | 20 / 20 new | none |

同一次 forum 响应中 `concern_num` 有 string/integer 混合形态。
首次 in-app Probe 因仅解字符串而稳定失败；根据实际类型与
Android `ForumFuzzyMatchAdapter.getNonNullString` 只放宽这两个统计字段为
string-or-integer，加入合成回归后三条 Probe 全部成功。

最终只读审查又确认 Android `SearchThreadBean.ThreadInfoBean` 将
`post_num/forum_id` 声明为 String，而当前 Live 响应恰为 number。合成
Fixture 现同时覆盖两种形态；生产修复前协议回归稳定为 1/2 失败并报告
`.decode`，窄化 string-or-integer 解码后同套件 2/2 通过。

真实 forum 结果已人工进入现有 ForumHome，吧摘要与帖子列表
正常出现。真实 thread 页在 macOS 锁屏前已证明首页/第二页
解码、映射与新增 ID；其结果到 ThreadReader 的导航使用与 Fixture
完全相同的稳定 `ThreadID` route，Fixture iPhone 已完成点击/返回。

Probe 与文档不记录公开查询词、吧名、threadID、标题、正文、
用户内容、完整请求/响应或凭据。

## Fixture、回归与运行命令

- 三个合成 JSON Fixture 覆盖稳定 ID、首出现去重、两页搜帖、
  `has_more/current_page`、跨页重复与混合类型统计字段。
- 定向 Search Unit 当前 9 个逻辑测试：协议/映射 2，Store/route/
  Fixture isolation 7，全部通过。
- iPhone Fixture：搜吧 → ForumHome → 返回，搜帖 → ThreadReader
  → 返回，关键词与结果保留，2/2 通过。
- iPad Fixture：现有 split 容器中搜索页、两类结果 smoke，1/1 通过。
- `make instructions`、`make secret-scan` 均通过。
- `make lint` 首次准确报告两处新增违规：SearchView 的空关联值匹配，
  以及 UITestHarness 因新增 7 个搜索 ID 达到 607 行。最小修正语法并压缩
  既有换行后，原命令重跑为 195 个 Swift 文件、0 违规。
- 阶段 16A 定向 xcodebuild 为 9/9 逻辑测试通过，xcresult：
  `Artifacts/TestResults/stage16a-final-targeted-after-review.xcresult`。
- thread mixed-type 回归在生产修复前为 1/2 失败（`.decode`），修复后
  2/2 通过；红/绿 xcresult 分别为
  `Artifacts/TestResults/stage16a-thread-string-regression-red.xcresult` 和
  `Artifacts/TestResults/stage16a-thread-string-regression-green.xcresult`。
- `make test-unit` 通过；xcresult summary 为 311/311、0 失败：
  `Artifacts/TestResults/20260830-162332-6516-unit.xcresult`。
- 定向 iPhone UI 为 2/2、iPad UI 为 1/1，xcresult 分别为
  `Artifacts/TestResults/stage16a-final-iphone.xcresult` 与
  `Artifacts/TestResults/stage16a-final-ipad.xcresult`。
- `make quality-fast` 完整通过；其最终 Unit 仍为 311/311、0 失败，
  build、Keychain entitlement、网络隔离、静态策略、生成确定性、fixture
  确定性和 secret scan 均为绿色；最终 Unit xcresult 为
  `Artifacts/TestResults/20260830-164124-20313-unit.xcresult`。
- 没有新增根级 Tab/Sidebar，也未修改 `AppSceneRoot` 或共享交互组件，
  因此按本阶段约束没有运行完整 `make quality` / Pager/Media interaction。

## Known Limitations / UNKNOWN

1. forum 分页、搜帖 page 3+、rate limit、完整错误 taxonomy 与
   endpoint 长期稳定性没有运行证据。
2. 搜索建议 `SearchSug` Proto、用户搜索、吧内搜帖和历史明确未实现；
   当前 Proto 仍是 156-file 闭包。
3. Live smoke 是单 iOS 26.5 Simulator 的开源 Beta 证据，不是真机、
   多地区或多系统发布矩阵。
4. Production 图片 loader 仍 disabled；搜索本身不建图片 cache/downsample。
5. 真实 forum 结果已人工进入 ForumHome；真实 thread 结果的最终 UI 点击
   因 macOS 锁屏导致 Computer Use 两次超时而未完成。Live thread page 1/2
   in-app Probe 与同一路由的 Fixture iPhone 点击/返回均已通过；因此阶段
   16A 保持 `RUNTIME_EVIDENCE_PARTIAL`，不得宣称完整人工 Live 验收。
