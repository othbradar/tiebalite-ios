# ADR-0020：Hybrid 搜索与普通业务 route 的开源 Beta 边界

- 状态：Accepted
- 日期：2026-08-30
- 决策者：阶段 16A“贴吧和帖子搜索”
- 关联阶段：16A、16B
- Extends：ADR-0003 的系统导航和 ADR-0006 的证据门禁；
  不取代两份已接受决策

## 背景

锁定 Android reference 的搜吧与搜帖主链路使用
`AppHybridTiebaApi` 的 HTTPS GET JSON，而不是 `SearchSug` Protobuf。
Android `SearchThreadViewModel` 以 `pn + 1` 和 `has_more == 1`
顺序翻页；`SearchForumViewModel` 只请求首屏，即使响应
携带 `pn/has_more` 也没有可跟踪的搜吧下一页请求语义。

## 决策

1. 阶段 16A 只实现搜吧和搜帖。搜索建议、用户搜索、搜索历史、
   吧内搜帖和阶段 16B 不进入本决策。
2. `RouteIdentity.search` 是 recommendations root 下的普通系统
   route。iPhone 使用已有 `NavigationStack` push；iPad 使用已有
   split detail 投影。不新增 Tab、Sidebar、`NavigationStack`、
   `fullScreenCover` 或自定义转场。
3. 查询词、搜索结果、帖子下一页和滚动锚存在 scene 级
   `SearchStore`，不进入 route identity。因此结果页进入吧首页/
   ThreadReader 并返回时复用同一 Store。
4. View 只依赖 `SearchRepository`。Live Repository 使用已有
   `HTTPClient + EndpointPipeline`的 JSON family，Fixture Repository 供
   Unit/UI Testing 和离线演示使用。两个 endpoint 都是匿名、
   无 body 的 HTTPS GET，不读 Session/Keychain，不发 Cookie。
5. forum identity 使用正 `forum_id`，thread identity 使用可解析的
   正 `tid`；重复结果 first-wins 且保持服务器首次顺序。
   不用 `UUID()` 生成业务 identity。
6. 搜帖页码从 1 开始，只在当页 `has_more == 1` 时请求
   `pn + 1`；响应 `current_page` 必须精确匹配。搜吧仅首屏，
   不猜测下一页参数。
7. Store 以一个 Task 和递增 generation 隔离新关键词、取消与
   迟到响应。分页失败保留已有结果；空关键词不发请求；
   取消不展示普通失败。
8. 结果复用现有 `VirtualizedList` 和 `ContentSummaryCard`，
   不修改共享列表承载，不建第二套帖子或吧首页。

## 运行证据

2026-08-30 在 iPhone 17 Pro / iOS 26.5 Simulator 的 Debug-only
脱敏 Probe 中：

- `/mo/q/search/forum?word=...`：HTTP 200，
  `application/json`，36555 bytes，JSON decode=true，映射 48 个吧；
- `/mo/q/search/thread?...&pn=1...`：HTTP 200，
  `application/json`，59907 bytes，decode=true，映射 20 个帖子；
- 相同公开关键词的 `pn=2`：HTTP 200，
  `application/json`，66555 bytes，decode=true，映射 20 个帖子，
  相对首页新增 20 个稳定 threadID。

首次 in-app Probe 稳定暴露 forum `concern_num` 在同一响应中
同时出现 JSON string 和 integer。Android
`ForumFuzzyMatchAdapter.getNonNullString` 会将两者投影为字符串；
iOS 现仅对 `post_num/concern_num` 做相同的 string-or-integer
窄化解码，并以合成 Fixture 回归锁定。

Probe 只保留 status、MIME、body byte count、decode、映射数量和
typed outcome；不保留查询词、结果内容、请求/响应原文或凭据。

## 后果、未知项与回滚

搜索成为 recommendations root 内的 P1 能力，不改变 P0 Tab
身份。本阶段没有生成或扩大 Proto；`SearchSug` 仍属未实现的
输入联想。搜吧分页、第三页及更后的 Live 搜帖、rate limit、
服务错误 taxonomy、参数必要性和 endpoint 长期稳定性仍为
`UNKNOWN`。

若 Hybrid endpoint 契约失效，回滚 Production Live Search 选择并保留
Fixture SearchView/Store 与导航；不放宽 TLS/MIME，不吞解码错误，
不引入 Cookie，也不重写共享列表、Pager、MediaViewer 或 Renderer。
