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

## P02 增补（2026-10-19，全局类型、排序与 Android 参考样式）

用户要求全局“帖子/吧”独立选择，旧两类并发聚合会使单类失败影响全部结果，因此不再沿用该聚合方式。保留原匿名接口与帖子分页；每次仅所选类型发请求。同关键词的搜吧与三种搜帖排序分别保留结果、页码、错误与锚，完整 query 和 generation 防迟到覆盖。无需替换 HTTP 栈或引入新依赖。

为下一阶段真实吧内范围增加 SearchScope；Route→Registry→Store→Repository 都携带它。route 可选 scope 缺省 global，旧持久化 search={} 仍能解码；query、页码与结果仍在 scene Store。forum 范围当前明确 unsupported，不把 global 结果冒充吧内结果。

用户明确改用 Android TiebaLite 的三张搜索截图作为视觉参考，排除官方搜索广告；只实现本轮搜吧/搜帖，不扩张搜人。搜索框与首页顶部入口共用 TiebaSearchBoxSurface，位置一致；紧凑下划线类型标签、平面结果行和系统排序 Menu。默认新帖 st=5，用户追加旧帖 st=0、相关度 st=2，依据 Android SearchThreadSortType 与 Hybrid 调用链；分页携带当前排序，缓存隔离，搜吧查询不被排序拆分。选择在当前 scene Store 保留，不新增跨重启设置。沿用 VirtualizedList、导航返回与图片设施；不改发送链路。定向测试、失败修正与实际安装状态见 P02 audit；仍需用户视觉验收，不以丢弃用户改动或重建根导航作回滚。


### P02 用户追加搜人（2026-10-19）

上述“搜人不扩张”是前一轮边界，已被用户最新“还有一个搜人你没做”替换。第三标签 users 与论坛/帖子各自缓存；复用相同关键词、新词清旧条目、取消与代次隔离及 VirtualizedList，空结果只显示“没有匹配的用户”。选中搜人时读取匿名 GET /mo/q/search/user（word only），不加 pn/st，不用用户登录凭证。新 SearchUserWebProtocol 将推荐与相关用户映射成有效稳定 userID + 已有 UserProfileRoute；点击整行进入已有个人主页，返回恢复列表位置。数组/对象响应差异取自 UserExactMatchAdapter/UserFuzzyMatchAdapter，证据和合成样本见 API_EVIDENCE；头像复用现有 Loader。搜人不含关注按钮，不改变远端数据，无新手势、动画、overlay、依赖或账号/写请求调整。

## P03 amendment (2026-10-20)

The user's forum-search task authorizes a scoped read adapter. The supplied iOS IPA routes the forum search button to the official Hybrid forum page; its current JS proves GET `/mo/q/search/thread`, `fname`, iOS `ct=1`, and the three scoped modes. Reuse the anonymous HTTP executor and JSON DTO, with an explicit InForumSearchProtocol descriptor and whole-page scope validation. The prior global unsupported-scope guard remains on the global descriptor; LiveSearchRepository dispatches scoped requests separately. No global-result filtering or implicit fallback is permitted.

The user explicitly rejected the old partial sheet. Forum search now pushes `.search(scope: .forum(...))` into the existing system navigation path. The registry retains its scoped store while that route remains in a root/settings path, then cancels/releases it on pop. The preceding forum store stays in that path, preserving its list/order/viewport; result pushes retain the search viewport. Distinct floor/subreply identities use existing reading destinations. Full shared auth migration and write protocols are excluded; rollback is to explicit unsupported scope, never to mislabeled global results.

P03用户截图追加：页面采用独立主题/评论标签和新帖/相关菜单；参数来自官方Hybrid同模块的两组分支，ct1匿名组合实测通过。截图是视觉真相；公开JS分支当前标识HarmonyOS，因此不把该源码分支描述为参考IPA运行时iOS证据。吧内本地关键词历史限20，设备本地UserDefaults独立key；测试用隔离suite/内存，不读取账号。按用户后续要求删除搜索sheet及其私有导航path，复用现有NavigationStack、VirtualizedList和系统Menu；根容器与写链路不变。

P03系统返回补充：隐藏搜索导航栏会使iOS26边缘返回失效，单纯delegate适配没有修复，实验已撤销。最终将共享搜索框/取消动作放在系统toolbar，同一行且无额外标题，保留系统back button/边缘返回；不替换recognizer/delegate，不改Pager。
