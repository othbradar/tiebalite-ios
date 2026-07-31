# Android 参考实现审计

状态：`PASSED_WITH_UNKNOWNS`

## 审计基线

- 根仓库阶段 01 基线：`6066549a17af04b914dfdd4970a85167d57a33e4`。
- Android reference branch：`4.0-dev`。
- Android reference commit：`5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`。
- reference lock：`References/TiebaLite-Android.lock` 与上述 commit 一致。
- 审计前后 Android 工作树和索引均 clean。
- 方法：只读 `rg`/`find`/`sed`/`git` 静态追踪；未构建 Android、未启动 App、未登录、未抓包、未访问真实接口。
- 证据状态：本报告没有 `RUNTIME_EVIDENCE`。服务端接受性、真实响应、错误码和交互细节凡无法由源码证明者均为 `UNKNOWN`。

本报告使用的标签定义见 `.agents/skills/tiebalite-reference-audit/references/evidence_labels.md`。详细 endpoint、Proto、内容节点、route 和状态分别见：

- `Specs/API_EVIDENCE.md`
- `Specs/PROTOBUF_MAP.md`
- `Specs/CONTENT_NODE_MATRIX.md`
- `Specs/NAVIGATION_MAP.md`
- `Specs/STATE_MACHINES.md`
- `Specs/UNKNOWN_BEHAVIORS.md`

## 仓库与模块索引

`CODE_EVIDENCE`：

- Android 是单一 `app` 模块；`app/build.gradle.kts::wire` 从 `src/main/protos` 生成 Kotlin Wire 类型。阶段提示中的 `src/main/proto` 与实际目录不同。
- 网络入口位于 `api/`，具体调用经 `ITiebaApi`、`MixedTiebaApiImpl`、Retrofit interface 和 interceptor 组合。
- 推荐、FRS、GeneralTab、PB 使用 repository；关注动态、关注吧、搜索、登录仍有 ViewModel/utility 直接调用 `TiebaApi` 的路径。
- UI 是 Compose Destinations + 单一 root `NavHostController`。图片查看器是独立 `PhotoViewActivity`。
- Room 数据库版本 40，实体包括 account、history、topforum、searchhistory 等；偏好使用 DataStore，当前账户 id 另存 SharedPreferences。
- `app/src/test` 与 `app/src/androidTest` 各只有一个模板测试，未覆盖业务行为。
- `app/src/main/protos` 有 321 个 `.proto` 文件；本阶段只把 P0 调用链及其直接依赖纳入候选生成图，不能把“存在 schema”视为服务器行为已验证。

```text
用户动作
  → Compose Page / UiIntent
  → ViewModel reducer
  → Repository（部分链路没有）
  → MixedTiebaApiImpl
  → Retrofit + request builder + interceptors
  → HTTP / multipart protobuf
  → Wire DTO / JSON DTO
  → mapper / extension
  → UI state / renderer
```

`INFERENCE`：iOS 应保留上图的业务边界，但生成 Proto 不得泄漏到 View；所有 direct-to-API Android 路径需在实现阶段收敛到 repository/use-case 协议。

## P0 完整调用链

### 推荐流

`CODE_EVIDENCE`：

```text
下拉刷新 / 触底
→ PersonalizedPage
→ PersonalizedUiIntent.Refresh / LoadMore(page)
→ PersonalizedViewModel
→ PersonalizedRepository.personalizedFlow(loadType, page)
→ MixedTiebaApiImpl.personalizedProtoFlow
→ POST /c/f/excellent/personalized?cmd=309264
→ PersonalizedRequest / PersonalizedResponse
→ thread_list + thread_personalized 按 tid 关联
→ 过滤直播及用户设置排除项
→ PersonalizedUiState
```

- 关键路径：`ui/page/main/explore/personalized/PersonalizedPage.kt`、`PersonalizedViewModel.kt`、`repository/PersonalizedRepository.kt`、`api/interfaces/impls/MixedTiebaApiImpl.kt::personalizedProtoFlow`、`api/retrofit/interfaces/OfficialProtobufTiebaApi.kt::personalizedFlow`、`app/src/main/protos/Personalized.proto`。
- `load_type=1` 用于刷新，`load_type=2` 用于更多；`pn` 是客户端页号，`page_thread_count=11`。
- reducer 刷新采用 `new + old` 后按主题 id 去重，分页采用 `old + new` 后去重；失败保留已有内容。
- 响应没有已确认的 `has_more`/cursor；Android UI 永远允许继续加载。
- 不同 intent subtype 经 `merge` 汇合，缺少请求代次、互斥和 stale-response 防护。

`UNKNOWN`：匿名可用性、终止条件、空页含义、稳定顺序、重复页与真实错误码。

### 关注的吧

`CODE_EVIDENCE`：

```text
登录后进入首页 / 刷新
→ HomePage
→ HomeUiIntent.Refresh
→ HomeViewModel.produceRefreshPartialChangeFlow
→ HistoryUtil.getFlow ZIP ITiebaApi.allForumGuideFlow
→ MixedTiebaApiImpl.allForumGuideFlow
→ OfficialTiebaApi.forumGuideFlow
→ POST /c/f/forum/forumGuide
→ ForumGuideBean
→ LikeForum → HomeUiState.Forum
→ FollowedForumsCache + HomeUiState
```

- endpoint 是 `http://c.tieba.baidu.com/c/f/forum/forumGuide` 的 form 请求，带 `ForceLogin`、`tbs`、`stoken`。
- Android 从 `page_no=1` 开始，每页 `res_num=50`，循环到 `like_forum_has_more=false` 后一次性提交 UI。
- Home 把结果与本地访问历史 zip；任一侧不完成或失败都会使整次刷新失败。
- 用户资料页另有 `/c/f/forum/like` 分页链；Proto `forumGuideNewFlow` 虽定义但未发现 Home 的生产 call site，不能替代当前证据。

`INFERENCE`：iOS P0 应采用可取消的分页 repository，支持未登录状态、刷新保留内容和会话失效；不能复制明文 HTTP、强制解包 token 或一次拉完全部页的实现。

`UNKNOWN`：HTTPS 等价 endpoint、会话失效码、空关注列表与权限错误的差异、账号很多时的页数上限。

### 吧首页 / FRS

`CODE_EVIDENCE`：

```text
打开 Forum(forumName) / 切排序或精品分类 / 刷新 / 触底
→ ForumPage + ForumThreadListPage
→ FirstLoad / Refresh / LoadMore
→ FrsPageRepository.frsPage / threadList
→ MixedTiebaApiImpl.frsPage / threadList
→ POST /c/f/frs/page?cmd=301001
   或 /c/f/frs/threadlist?cmd=301002
→ FrsPageResponse / ThreadListResponse
→ user_list 补齐 author + 过滤设置项
→ ForumThreadListUiState
```

- 关键路径：`ui/page/forum/ForumPage.kt`、`ForumViewModel.kt`、`ui/page/forum/threadlist/ForumThreadListViewModel.kt`、`repository/FrsPageRepository.kt`、`FrsPage/FrsPage.proto`。
- `forumName` 是自足 route 标识；请求同时使用 URL-encoded `kw` 与 `forum_name` header。
- 首屏 `pn=1/load_type=1`；分页优先每批消费最多 30 个 `thread_id_list`，耗尽后请求 `pn+1/load_type=2`。
- `Page.has_more` 是 FRS 页终止证据；thread-list 支路只以返回非空推断还有更多。
- latest、good 和服务端 general tab 是可见业务语义；GeneralTab 另走 `/c/f/frs/generalTabList?cmd=309622&format=protobuf`。
- `ForumPartialChange.Load.Success` 仍写 `isLoading=true`，页面刷新还有固定一秒的假 loading；这是参考实现风险，不是产品规范。
- repository 只有一组未按 forum/request key 分区的 `lastHash/lastResponse`，刷新与分页也没有 generation/cursor 互斥（`CODE_EVIDENCE`）。

`INFERENCE`：不同吧或并发 intent 可能交叉复用缓存、让过期 response 覆盖新状态；必须用延迟 fixture 证明 iOS 的隔离策略。

`UNKNOWN`：动态 tab 值域、置顶/普通帖契约、`thread_id_list` 与后续页的精确关系、匿名访问差异。

### 帖子 / PB / 楼中楼

`CODE_EVIDENCE`：

```text
打开 Thread(threadId[, anchor/filter/sort]) / 刷新 / 前后分页
→ ThreadPage
→ ThreadUiIntent.Load / LoadFirstPage / LoadMore / LoadPrevious
→ PbPageRepository.pbPage
→ MixedTiebaApiImpl.pbPageFlow
→ POST /c/f/pb/page?cmd=302001&format=protobuf
→ PbPageResponse
→ author/forum/anti/page 校验与 user_list 作者补齐
→ Post + PbContent mapper
→ ThreadUiState + PostCard
```

- 关键路径：`ui/page/thread/ThreadPage.kt`、`ThreadViewModel.kt`、`repository/PbPageRepository.kt`、`PbPage/PbPageRequestData.proto`、`PbPage/PbPageResponseData.proto`、`api/models/protos/Extensions.kt`。
- route 的稳定必需值是 `threadId`；`forumId/postId/seeLz/sortType/from` 是可选上下文，不能依赖 Android 的四项 LRU `ThreadInfo` bridge。
- 请求关键字段含 `kz/pid/pn/lz/forum_id/back/last_pid/rn=15/with_floor=1/floor_rn=4/floor_sort_type`。
- 返回 `Page.current_page/new_total_page/has_more/has_prev`、thread、forum、anti、post_list、user_list、first_floor_post。
- LoadMore 按 post id 排除已加载项；LoadPrevious producer 也按它观察到的既有 post id 过滤，但 reducer 仅 prepend、没有第二层去重。分页失败只停 spinner，没有尾部错误状态。
- repository 使用 `userList.first` 补作者，缺作者可能抛异常；空 post list 被视为异常，删除贴/私密贴/合法空页无法区分。
- 楼中楼由 `SubPostsViewModel` 走 `/c/f/pb/floor?cmd=302002&format=protobuf`。页面未呈现明确失败/重试，append 也未去重。

`INFERENCE`：并发 LoadPrevious 使用过期的 post id 快照时仍可能产生重叠；iOS reducer 必须在提交状态时再次按稳定 id 去重。

`UNKNOWN`：`page=0 + pid` 锚定语义、删除/私密/折叠内容返回形态、作者缺失、热序页码、楼中楼 cursor 和真实终止条件。

## 内容渲染

`CODE_EVIDENCE`：

- `PbContent.proto::PbContent.type` 是整数而非 enum。
- `api/models/protos/Extensions.kt::List<PbContent>.renders` 实际处理：
  - `0/9/27/35/40`：文本；
  - `1`：链接；
  - `2`：表情；
  - `3`：图片；
  - `4`：用户提及；
  - `5`：视频或视频链接降级；
  - `10`：语音；
  - `20`：另一图片形态。
- 未命中的 type 被静默丢弃。图片 `bsize` 用强制 split/int 解析。普通 `PbContent.uid` 已是 int64；真正的 mention 转换风险来自楼中楼 nullable author 生成 `"null"` annotation，随后 renderer 强制转 Long。楼中楼文本对空 content 使用 `reduce`。
- 投票来自 `ThreadInfo.poll_info`，不是 `PbContent.type`；Android 还含投票提交写操作，iOS 只能展示只读结果。

`INFERENCE`：上述强制解析和静默丢弃都不是可接受的 iOS 降级策略。iOS mapper 必须保留相邻节点顺序，未知/畸形节点映射为稳定的 `UnsupportedNode`，不能静默丢失或崩溃。完整契约见 `Specs/CONTENT_NODE_MATRIX.md`。

## 导航与平台语义

`CODE_EVIDENCE`：

- `MainActivityV2` 使用一个 `rememberNavController` 和 `DestinationsNavHost(NavGraphs.root)`。
- `MainPage` 有首页、探索、通知、我的四个稳定 id；可隐藏探索成为三个 Tab。Compact/Medium/Expanded 分别使用 bottom bar、rail、drawer。
- Tab 内容由禁用用户横滑的 pager 承载；重选发全局 refresh；返回键在非首页 Tab 时先回首页。
- Android deep link 可把 `/f?kw=` 和 `/p/{tid}` 映射到 Forum/Thread。
- MediaViewer 是独立 Activity；Android 单击图片直接关闭。

`INFERENCE`：

- 可移植语义是稳定 route、独立 Tab 状态、重选行为、宽度自适应和 ID 驱动恢复。
- iOS 必须遵守已批准交互契约：每个主 Tab 独立 `NavigationStack`，iPad 使用系统分栏，MediaViewer 使用唯一手势协调器；不得复制单 root NavHost、Compose pager、Activity 生命周期、固定延迟或 Android 转场。

详细 route 和恢复条件见 `Specs/NAVIGATION_MAP.md`。

## Session、存储与安全

`CODE_EVIDENCE`：

- `LoginPage.LoginWebViewClient.onPageFinished` 在指定 tieba 回跳 URL 读取 WebView Cookie 中的 BDUSS/STOKEN，再调用 `AccountUtil.fetchAccountFlow`。
- `fetchAccountFlow` 组合 `/c/s/login`、`initNickname`、Sofire ZID 和 `getUserInfo`；基础登录成功而 profile 失败时仍可保存账户。
- `Account` Room entity 明文保存 `bduss/sToken/cookie/tbs/zid`；当前账户 id 在 SharedPreferences。
- `ForceLoginInterceptor` 只检查本地账户是否存在；`ERROR_LOGGED_IN_EXPIRED=12` 只有常量定义，未发现可靠消费和状态迁移。
- 退出代码分步删除当前账号行、重新选择当前账户 id 并清 WebView cookies。
- `isLoadingAccount` 被检查却未设置为 true；每次匹配的 `onPageFinished` 都可进入 `fetchAccountFlow`。
- DataStore helper 混用 `MainScope`、`runBlocking` 和组合时读写 effect。
- V12 `buildCommonRequest` 忽略 caller 传入的 BDUSS/STOKEN，改读全局 `AccountUtil`；登录组合链的 getUserInfo caller 确实传入了新账户参数。

`INFERENCE`：分步多账号退出可能留下旧列表/空账户；重复回跳可能并发创建 session；混合协程/阻塞读写可能覆盖状态或脱离生命周期；全局 V12 认证源可能发送旧/空 session。iOS 必须把最小必要凭据放 Keychain，非敏感 profile/历史另存；登录、刷新、过期、退出、切换必须由原子 session 状态机驱动。Android WebView、Room 明文凭据、GlobalScope、固定 1.5 秒返回和 HTTP endpoint 一律不可照搬。

`UNKNOWN`：真实过期/封禁码、Cookie 轮换、验证码/二次验证、取消登录、多账号恢复、App Store 可接受的登录边界。

## 已知高风险或过时做法

以下条目的源码形态为 `CODE_EVIDENCE`；其对并发、安全或 UX 的后果是
`INFERENCE`，只用于规避，不构成 iOS 设计输入：

1. `RetrofitTiebaApi` 的 Official/Mini/New base URL 使用明文 HTTP；Manifest 开启 `usesCleartextTraffic=true`。
2. `ProtobufRequest` 构造大量 Android 设备标识与定位占位值；`SortAndSignInterceptor` 含 legacy 签名常量。服务端协议能否在 iOS 合法、最小化使用是 `UNKNOWN`。
3. DTO/生成 Proto 多处直接进入 UI，缺少领域隔离。
4. 多数 ViewModel 将不同 intent 分支 `merge`，没有取消、generation 或 cursor 互斥；存在陈旧响应覆盖风险。
5. 多处 `!!`、`first`、`toLong()`、强制图片尺寸解析和异常吞噬。
6. 非空列表会隐藏 refresh/page failure，许多失败只 Toast 或静默。
7. 推荐没有终止信号；部分页忽略 `hasMore`。
8. Room 明文保存凭据；日志可直接打印 intent/state/error。
9. MediaViewer 捕获并吞掉所有触摸 `RuntimeException`。
10. 仅有模板测试，核心链路零回归覆盖。

## Android 行为与 iOS 产品规范的边界

| Android 证据 | 可移植产品语义 | 不可照搬 |
|---|---|---|
| 稳定 forumName/threadId 路由 | route 自足、深链可恢复 | LRU 传完整 Proto |
| refresh/load-more reducers | 保留旧内容、稳定去重 | Toast-only、无代次并发 |
| Compact/Medium/Expanded 导航 | iPhone/iPad 自适应 | rail/drawer 视觉和 Compose pager |
| 黑底图片查看器 | 全屏、分页、缩放、索引 | 单击关闭、Activity、吞异常 |
| Web 登录后读取 Cookie | 明确用户触发的登录与 session | 隐蔽注入、明文 DB、固定延时 |
| PbContent type 分支 | 领域节点和安全降级 | 强制解析、未知节点静默丢弃 |

## 测试与运行证据

- Android unit test：只有 `ExampleUnitTest.addition_isCorrect`。
- Android instrumented test：只有包名断言。
- 本阶段未运行 Android build/test，避免在只读 reference 中生成文件。
- 未创建 fixture，所有 endpoint 仍是静态候选证据；对应 fixture 需求列在 `Specs/API_EVIDENCE.md` 和 `Specs/CONTENT_NODE_MATRIX.md`。
- 未验证真实网络、账号、截图、旋转、分屏、进程恢复、Reduce Motion 或可访问性。

## 最弱的五个证据区域

1. 登录验证码、Cookie/token 轮换、过期和多账号退出。
2. 明文 HTTP 候选接口是否存在安全的 HTTPS 等价路径，以及最小合法签名/设备参数。
3. 推荐流匿名能力、稳定顺序、空页与真实终止条件。
4. FRS 动态 tab、`thread_id_list` 与 page 的真实分页契约。
5. PB `page=0 + pid`、删除/私密/缺作者/畸形响应与并发次序。

这些项目及最小安全验证方法在 `Specs/UNKNOWN_BEHAVIORS.md` 中保持开放；在获得脱敏 `RUNTIME_EVIDENCE` 前不得升级为已证实行为。
