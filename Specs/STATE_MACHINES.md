# P0 状态机

状态：`IMPLEMENTED_PHASE_16A_SEARCH_RUNTIME_EVIDENCE_PARTIAL_WITH_UNKNOWNS`

本文件定义 iOS 可测试的领域状态。Android reducer 是 `CODE_EVIDENCE`，但其中缺少的错误、取消和过期响应状态由根规则补齐，不复制 Android 的 Toast-only 或布尔堆叠实现。

## 通用列表状态

所有 P0 异步列表采用同一代数状态：

```text
idle
├─ load → initialLoading
│  ├─ success(items>0) → loaded
│  ├─ success(items=0) → empty
│  ├─ failure → initialFailure
│  └─ cancel → idle
loaded / empty
├─ refresh → refreshing(previous)
│  ├─ success(items>0) → loaded(new)
│  ├─ success(items=0) → empty
│  ├─ failure → refreshFailure(previous,error)
│  └─ cancel → previous
└─ loadNext → loadingNextPage(previous,cursor)
   ├─ success(items,hasMore) → loaded(merged)
   ├─ failure → nextPageFailure(previous,cursor,error)
   └─ cancel → previous
```

`refreshFailure` 和 `nextPageFailure` 是可见且可恢复的子状态，不得以“已有内容仍显示”为由丢失错误。

### 通用不变量

1. `previous` 内容在 refresh/page request 期间保持可见。
2. 同一 generation 内，同一 cursor/page 最多一个 in-flight request。
3. 新 refresh 创建新 generation，并取消旧 refresh/page request。
4. response 必须携带 request identity；identity 不匹配时丢弃，不改变状态。
5. 合并按稳定业务 id 去重并保持服务器首次出现顺序。
6. next-page failure 保留 cursor，retry 使用同一 cursor。
7. `CancellationError` 不显示为失败。
8. 空首屏与失败首屏不同；空下一页只在 endpoint 契约证明 terminal 时结束。
9. session 变化不会隐式销毁公开内容。
10. 状态 transition 必须可用纯 fixture 测试，不依赖时间延迟。

### Effect 执行与取消协议

Feature Store 依照 ADR-0002，以同步 reducer 产生 effect descriptor。每个异步
结果必须携带：

```text
EffectIdentity =
  featureInstanceID + effectKind + generation + requestID
  + cursor/page? + ProtectedDataLease?
```

| 事件 | 必须取消 | 仍保留 | Event 提交条件 |
|---|---|---|---|
| 新 initial/refresh | 同 timeline 旧 initial/refresh/page | 其他 tab/timeline | generation/requestID 匹配 |
| sort/filter/classify 改变 | 当前 timeline 全部旧 effect | 其他 tab state/effect | 新 filter snapshot + generation 匹配 |
| loadNext retry | 同 cursor 的旧 attempt | previous content | generation/cursor/new requestID 匹配 |
| route pop/deactivate | 该 route-owned effect | root/其他 route | route identity 仍 active |
| Tab 切换 | 默认不取消 | 两 root Store/effect | 原 identity 仍有效 |
| session generation 撤销 | 所有旧 protected effect | public effect | lease 仍有效且 sessionID 匹配 |

Task cancellation 是资源回收，不是提交正确性的唯一保障；reducer/repository
写入前仍需复核 identity/lease。`CancellationError` 不转成可见错误。禁止以
deinit、固定延迟或 View `onAppear` 无防重请求代替生命周期。

## 推荐流

Android 静态证据（`CODE_EVIDENCE`）：

- `PersonalizedUiIntent.Refresh/LoadMore`。
- `PersonalizedPartialChange.Refresh/LoadMore` 保留旧内容并按 thread id 去重。
- 没有 `hasMore`；不同 intent 分支可并发。

领域数据：

```text
RecommendationState {
  listState
  generation
  nextPage: Int?
  terminal: yes | no | unknown
  filterSnapshot
  scrollAnchor
}
```

| 事件 | 前置 | 请求 | 成功 | 失败 |
|---|---|---|---|---|
| `appear` | idle | page 1/loadType refresh | loaded/empty；nextPage=2；terminal 仍 unknown | initialFailure |
| `pullToRefresh` | 任意已显示态 | 新 generation page 1 | 替换或按已批准刷新语义合并；本规格采用替换列表并以 id 恢复 anchor | refreshFailure(previous) |
| `reachTail` | loaded 且 nextPage 存在且 page 空闲 | `load_type=2,pn=nextPage` | append+dedupe；空页或 duplicate-only 页以受测 client policy 停止 | nextPageFailure(previous) |
| `retryInitial/Refresh/Next` | 对应失败态 | 原请求 identity 的新 attempt | 对应成功态 | 保持失败态并更新 error |
| `filtersChanged` | loaded/empty | 新 generation refresh | 新过滤结果 | refreshFailure(previous) |

`UNKNOWN`：推荐 endpoint 无已证终止信号。阶段 15.6 以空页或跨页
duplicate-only 页停止，只是确定性 client no-progress policy，不得伪称
服务端 `hasMore`。列表末尾 4 项只派发 Store-owned load-next 意图；单一
Task、generation 与 page identity 防止重复请求，刷新取消旧分页且迟到结果
不得覆盖新列表。

## 关注的吧

Android 静态证据（`CODE_EVIDENCE`）：

- `HomeUiIntent.Refresh` 把本地 history 与 `allForumGuideFlow` zip。
- `allForumGuideFlow` 从 page 1 起、每页 50，循环 `like_forum_has_more`，收齐后只 emit 一次聚合结果。
- 任一中间页失败会使整个 flow 失败；Home reducer 可保留旧 state，但 UI 多为静默。
- 本地置顶/历史是 Android 附加能力，在批准范围中属于 P1，不进入 P0 关注吧状态。

领域状态：

```text
FollowedForumsState =
  signedOut
  | idle(sessionID)
  | initialLoading(sessionID, requestID)
  | loadingNextPage(sessionID, requestID, previousSameSession?, nextPage)
  | loaded(sessionID, forums)
  | empty(sessionID)
  | initialFailure(sessionID, error)
  | refreshing(previousSameSession, requestID)
  | refreshFailure(previousSameSession, error)
  | nextPageFailure(sessionID, requestID, previousSameSession?, failedPage, error)
  | sessionExpired(sessionID, reason)

FollowedForumsAggregation =
  collecting(sessionID, requestID, nextPage, accumulatedForumIDs, seenPageFingerprints)
```

规则：

- 没有 session 时保持 `signedOut`；`requestLogin` 只向 Session 状态机发事件，不构造 token 请求，也不伪造 `loginRequested` 状态。
- P0 对外原子发布完整关注列表。首轮聚合没有 previous 时，中间页失败不展示部分 membership；刷新时继续显示同一 session 的 previous。
- `nextPageFailure` 可从 failedPage 重试；取消、重新刷新或 session 改变会丢弃 accumulator。相同 requestID/page 同时最多一个请求。
- sessionID 变化立即取消旧请求并清除旧 membership、accumulator 和受保护 cache；新账号绝不短暂显示旧账号列表。
- 进入 `sessionExpired` 时隐藏 membership。是否允许同账号过期后展示任何派生摘要，须先完成数据分类，本阶段不假定其为“非敏感”。
- `like_forum_has_more=true` 时继续下一页；重复页 fingerprint 或经配置的安全上限触发可恢复 protocol failure，防止死循环。上限值在 fixture/运行证据前为 `UNKNOWN`。
- forum id 去重；缺 id 时使用不可导航的降级 item，不按名称猜 id。
- 本地置顶/历史若进入 P1，使用独立 store，不与 P0 网络 membership 的完成条件互相门控。

阶段 13 的 Open-Source Beta 实现保留上述长期契约，但当前
HTTPS Proto candidate 只有单次原子 response、没有分页字段。因此当前
Store 只投影 `signedOut/signingIn/expired/initialLoading/loaded/empty/
initialFailure/refreshing/refreshFailure`，以单一 Task + generation 拒绝旧响应；
这不宣称已完成 legacy Home 的多页聚合契约。明确的远端过期
taxonomy 仍是 `UNKNOWN`，普通网络/解码错误不得转成 `expired`。

## 吧首页 / FRS

Android 静态证据（`CODE_EVIDENCE`）：

- `ForumViewModel.Load` 获取吧 header/tab。
- latest/good `ForumThreadListViewModel` 与 general `GeneralTabListViewModel` 各有 FirstLoad/Refresh/LoadMore。
- FRS 页先产生 `thread_id_list`，后续可转入 ThreadList，再回到下一 FRS page。

领域状态：

```text
ForumState {
  identity: forumName + resolvedForumID?
  headerState
  tabs: [ForumTab]
  selectedTabID
  perTab: [TabID: ForumTimelineState]
}

ForumTimelineCursor =
  initial
  | batchedThreadIDs(remainingIDs, frsPage)
  | frsPage(page)
  | generalTab(page, lastThreadID)
  | end
```

事件与约束：

- `open(forumName)` 同时启动 header/首个 tab 的受控任务，但两者状态独立。
- `selectTab(tabID)` 保存前一 tab 的列表、sort、classify、cursor、scroll。
- `changeSort/changeClassify` 只使当前 tab 新 generation refresh。
- `loadNext`：
  - 有 remaining thread ids：最多请求 30 个；
  - ids 耗尽：请求下一 FRS page；
  - general tab：传 page+1 和 lastThreadID。
- 任何 response 只更新自己的 `tabID + generation + cursor`。
- 服务端动态 tab 消失时，保留其缓存但选择 fallback latest；不能按 index 指向另一 tab。
- header 缺失不阻止已知 thread list 展示。

`UNKNOWN`：`thread_id_list` 的终止/乱序、dynamic tab 类型、置顶项归属。对应 fixture 未建立前不把推断编码为不可变 enum。

阶段 14P 的开源 Beta 投影比上述长期状态更窄：当前只有一条
latest timeline，不新建 tab/sort 状态。它区分 `initialLoading/loaded/empty/
initialFailure/refreshing/refreshFailure/loadingNextPage/nextPageFailure`；所有
retained 状态保留同一虚拟列表与稳定 threadID。接近末尾 4 条时只由
table prefetch 触发 Store；Store 以单 Task、generation、forumID 和 page
阻止重复/迟到提交。首屏用 FRS `pn=1/load_type=1`，后续页用
`pn=N/load_type=2`，按 threadID first-wins 去重保序，`Page.has_more`
终止。下一页失败只替换 footer 并保留旧 rows；重试同一 page。
`thread_id_list + ThreadList`、dynamic tab 与 general tab 仍属未实现的长期模型。

## 帖子 / PB

Android 静态证据（`CODE_EVIDENCE`）：

- `ThreadUiIntent.Load/LoadFirstPage/LoadMore/LoadPrevious/LoadLatestPosts`。
- Page 提供 current/newTotal/hasMore/hasPrev，`ThreadInfo.pids` 另参与下一 pid。
- LoadMore 去重；LoadPrevious producer 会按已观察到的 post id 过滤，但 reducer 只 prepend、没有第二层去重。不同 intent 可并发（`CODE_EVIDENCE`）。

`INFERENCE`：LoadPrevious 使用过期的 post id 快照时仍可能产生重叠，iOS reducer 需要提交时二次去重。

领域状态：

```text
ThreadReaderState {
  route: threadID + optional anchor/filter/sort
  headerState
  postsState
  previousCursor
  nextCursor
  generation
  readAnchor
  latestPostsNotice
}
```

| 事件 | 状态变化 |
|---|---|
| `open(route)` | initialLoading；可先显示 route 附带的安全 thread summary，但不能视为完整 response |
| `loadSuccess` | 校验 thread/forum/page；缺作者形成 UnknownAuthor；映射首楼和 replies；loaded/empty |
| `loadNext` | loadingNextPage(previous,nextCursor)；按 post id append |
| `loadPrevious` | refreshing/专用 loadingPrevious(previous,cursor)；按 post id prepend 并去重 |
| `changeSort/seeLz` | 新 generation，从 anchor policy 决定首屏；旧响应失效 |
| `jumpToPost(pid)` | 以独立 anchor request 加载；成功后确定性滚到稳定 post id |
| `refreshLatest` | 不连续新楼进入 `latestPostsNotice`，不破坏当前阅读位置 |
| `openSubposts(postID)` | push `subposts` route，不修改父状态 |
| `openMedia(mediaID)` | present MediaViewer，不修改父状态 |

边界：

- `post_list=[]` 可能是 empty、deleted、private 或 malformed；在有运行证据前映射为 `unavailable` 而非通用 crash。
- `thread.author/forum/anti` 缺失不能在 mapper 强制解包；只有真正不可构建 identity 时才成为页面失败。
- `pids` 非数字 token 被忽略并记录脱敏 diagnostics；不能使整页失败。
- 阶段 15.6 取消两页本地硬帽。首屏 wire `pn=0` 必须映射服务端
  `current_page=1`；后续 `pn=N` 必须精确响应 `current_page=N`。每页
  `has_more=1` 允许顺序请求下一页。Android 已证 `has_more=0` 是
  client stop signal，iOS 以其作为 wire terminal 合同；真实末页运行语义
  仍为 `UNKNOWN`，不设固定最大页。
- 下一页 cursor 从 `ThreadInfo.pids` 排除全部累计 postID，取最后一个
  未见正数；无候选时依已证 Android fallback 使用 `pid=0`。
- `has_more=1` 却无新稳定 postID 时，保留已读楼层与原 page/pid，
  进入可重试 no-progress failure，防止空转；不伪装成服务端末页。
- refresh/load-next/load-previous 互斥规则由 generation + cursor 保证。
- readAnchor 使用稳定 post id；数组 index 只用于瞬时滚动实现。

### ThreadReader presentation 不变量

- 领域 Store 保留 `ThreadReaderSnapshot.posts`；table cell reuse 只回收展示，
  不等同于领域数据驱逐或分页回退。
- 顶层 presentation 一楼一项，普通楼层 identity 只用稳定 threadID/postID；
  header 与分页 footer 也使用确定性枚举 ID，禁止 UUID 和数组 index。
- 下一页成功只追加去重后的新 post row 并替换 footer；已有 post 内容未变化时
  identity 与 hosted state 保持，diffable apply 不使用 `reloadData` 或动画。
- prefetch 只产生 load-next 意图，Store 的单 Task、generation、page 和 hasMore
  决定能否请求；cell `onAppear` 不写分页状态。
- readAnchor 只在滚动终止时接收当前顶部 post ID；snapshot append、图片状态和
  self-sizing layout 不写 Store anchor，MediaViewer 返回继续使用同一 table。
- hosted Row task 在 `prepareForReuse` 或容器 dismantle 取消；
  `didEndDisplaying` 不提前销毁仍可能因回弹再次可见的 cell。

## 楼中楼

领域状态复用通用列表，加：

```text
SubpostsContext(threadID, postID, targetSubpostID?)
SubpostsCursor(page, totalPage?)
```

- 初始 response 成功后只有在 target id 存在时滚动；不使用固定延迟。
- 分页按 subpost id 去重。
- author/content 缺失按内容节点矩阵降级。
- 成功 payload 中任何 session/write metadata 不进入只读 View。
- 父 Thread 保持原位置。

## 搜索 / 阶段 16A

搜索只由用户显式 submit 触发，不对每个输入字符发请求：

```text
SearchState =
  idle
  | searching(keyword)
  | loaded(snapshot)
  | empty(keyword)
  | failed(keyword,error,retainedSnapshot?)
  | loadingMore(snapshot)

SearchSnapshot =
  keyword + forums + threads + currentThreadPage + hasMoreThreads
```

| 事件 | 前置 | 事务 | 成功 | 失败/取消 |
|---|---|---|---|---|
| `submit` | trim 后关键词非空，且不是同一已完成查询 | 取消旧 Task，generation+1，并发 forum page 1 + thread page 1 | 两类均空→empty；否则 loaded | 首屏→failed(nil)；取消恢复取消前状态 |
| `submitBlank` | 空白 | 不发 HTTP，取消当前任务 | idle | 不展示错误 |
| `reachThreadTail` | loaded，`hasMoreThreads=true`，当前无 Task | 请求精确 `currentPage+1` | 按 threadID first-wins 增量追加；空/duplicate-only 以 client no-progress 停止 | retained failed；重试同页；取消恢复 previous |
| `newKeyword` | 任何在途状态 | 取消旧 Task，新 generation | 只提交新关键词的结果 | 旧响应不改变任何状态 |
| `deactivate` | Search route 离开 | 取消在途 Task | 保留已完成的 query/result/scroll anchor | 取消不变普通 failure |

不变量：

1. 同时只有一个 Search Store Task；分页与新关键词互相隔离。
2. 响应提交必须同时匹配 generation 和 normalized keyword。
3. forumID/threadID 为稳定正业务 ID；跨页 first-wins 去重且保持首次顺序。
4. thread response `current_page` 必须精确匹配请求，只信任
   `has_more == 1` 作为继续信号。forum 分页未证，只做首屏。
5. 搜索返回时 scene 级 Store 保留 keyword、snapshot 和 scroll anchor；
   不因普通 View 更新重发请求。
6. UI Testing 只使用 Fixture Repository，无 Live 网络/真实 Session。

## MediaViewer

Android 静态证据（`CODE_EVIDENCE`）：

- `PhotoViewUiIntent.Init/LoadPrev/LoadMore`。
- 初始远端失败回退本地 items；边界失败静默；按 pic id 去重。
- Android 单击关闭、独立 Activity 和第三方 zoom 行为不可照搬。

领域状态：

```text
MediaViewerState =
  preparing(fixedItems, initialMediaID)
  | ready(fixedItems, currentMediaID, chromeVisible)
  | itemFailure(fixedItems, currentMediaID, fetch | decode | cancelled)
  | closing(returnContext)

MediaViewerImagePhase =
  idle | loading | rendered | failedToFetch | failedToDecode | cancelled

MediaPageCapability =
  (atMinimumZoom, horizontalBoundary: interior | leading | trailing | both)
```

事件：

- `present(source, initialMediaID)`：结构校验通过后按 media id 定位；阶段 09 的
  固定 intent 若 initial 不存在则拒绝 presentation、父状态不变。长期合同仍要求
  已接受 presentation 的 initial/current 后续消失时显示 unavailable，不按旧
  index 指向其他图。
- `page(direction)`：手势开始时依据当前 `MediaPageCapability` 固定 owner；
  同一手势到达边界不半途交给 pager，下一次朝外拖才可翻页。
- `pinch/doubleTap/pan`：精确 zoomScale/contentOffset 只由当前 MediaID 的
  UIScrollView coordinator 持有；Store 只接收离散 capability，不保存第二份
  transform。
- `singleTap`：切换 chrome；不关闭。
- `loadItem/retryItem`：占位尺寸与黑底保持。
- `reachBoundary`：阶段 09 固定 intent 边界不发请求；边界 Repository 留到有
  live/cursor 证据的后续独立阶段。
- `close`：长期合同是恢复来源 route/anchor 且不刷新父列表；阶段 09 实测范围
  仅证明关闭后原 Renderer Lab source view 保留。
- 翻页完成后才重置离场页；取消/反向不重置当前页；页面按 MediaID 复用前
  强制 reset。
- size/rotation change：coordinator clamp 当前 transform，不泄漏到相邻
  media。
- 进程恢复：不恢复 MediaViewer overlay；只恢复父 route。当前进程内的完整 `MediaDescriptor` 才是可呈现输入，单独 pic id 不足以重建 URL 和边界加载上下文。

阶段 09 生产实现使用稳定的固定 `ThreadMediaIntent`，以 MediaID 派生的
stableKey 作为页身份，并拒绝空集合、重复 stableKey 或不存在的 initial ID；
每页通过可注入 loader 区分 fetch 与 decode 成功，
只有 rendered 才进入 zoom surface。UIScrollView coordinator/Pager ownership
已按 ADR-0004/0005 接受并迁移到唯一生产路径。`UNKNOWN`：Android 第三方
手势范围仍不作为 iOS 输入；live boundary cursor、cache/downsample/candidate/
lease 仍无本阶段证据。固定构造拒绝 missing initial 是当前 Open-Source Beta
对长期 unavailable 合同的已知偏离；必须在动态媒体 Repository 接入前关闭。

## Session

Android 静态证据（`CODE_EVIDENCE`）：

- WebView 回跳读取 Cookie，随后 `fetchAccountFlow`。
- ForceLogin 只检查本地账户存在；过期常量未形成迁移。
- 凭据明文 Room、当前 id SharedPreferences；退出流程分步删除 account、切换当前 id、清 WebView cookies。

`INFERENCE`：上述分步退出在中途失败时可能留下不一致的账户或凭据状态，不能作为 iOS 原子清理模型。

领域状态：

```text
SessionState =
  restoring
  | signedOut
  | authenticating(attemptID, origin)
  | validating(attemptID, credentialHandle, origin, source)
  | preparingCommit(attemptID, retryContextRef, candidateSessionID, origin, source, conservativeCleanupDescriptor)
  | committing(attemptID, retryContextRef, candidateSessionID, origin, source, commitJournalID, conservativeCleanupDescriptor)
  | rollingBackCommit(commitJournalID, conservativeCleanupDescriptor, destination, completionAttemptID?)
  | signedIn(sessionID, accountSummary)
  | refreshing(sessionID, previous)
  | expired(sessionID, reason, recoverable)
  | preparingCleanup(cleanupOperationID, requestID, scopes, destination, fallback, completionAttemptID?)
  | signingOut(sessionID?, cleanupOperationID, requestID, ledgerID, pendingScopes, destination, completionAttemptID?)
  | failed(operationID?, phase, error, recoverable, fallback, validationSource?, retryContextRef?, completionAttemptID?, conservativeCleanupScope, cleanupDestination?, pendingCleanupLedgerID?, pendingCommitJournalID?)

AuthenticationOrigin =
  signedOut

ValidationSource = newLogin | restoredCredential
CleanupDestination = signedOut | AuthenticationOrigin
RetryContextRef = opaque non-secret ID owned by Session subsystem
ConservativeCleanupScope =
  none
  | temporaryAuthArtifacts(operationID)
  | candidateSessionArtifacts(operationID)
  | allAppOwnedSessionData
  | allAppOwnedProtectedData

ConservativeCleanupDescriptor =
  (scope: ConservativeCleanupScope, destination: CleanupDestination)

CommitJournal =
  (journalID, operationID, phase, conservativeCleanupDescriptor,
   recoveryDestination, idempotencyVersion)

CleanupLedger =
  (ledgerID, cleanupOperationID, scopes, destination, idempotencyVersion)

ProtectedDataLease =
  (sessionID, generation)
```

这是 `Specs/03_ARCHITECTURE_CONTRACT.md` 中
`signedOut/authenticating/signedIn/expired/failed` 的细化；`validating/refreshing/signingOut`
以及启动期 `restoring`、原子发布期 `preparingCommit/committing`、回滚期
`rollingBackCommit`、清理准备期
`preparingCleanup` 是过程状态，不重命名核心稳定状态。`origin/fallback`
只保存非敏感状态摘要，不保存凭据值。validation 类型的
`RetryContextRef` 在 Session 内部关联 credential handle、origin 与 source；
cleanup-preparation 类型只关联 scopes/destination/fallback，日志和 Feature
都只能看到引用 ID。`ConservativeCleanupDescriptor` 独立于 ref 保存，只描述
app-owned namespace/operation tag 与非敏感 destination，不含 handle、token
或账户值；下表省略时 scope 默认 `none`、destination 默认 `nil`。
`failed.validationSource` 仅保存 `newLogin/restoredCredential` 非敏感来源，在
validation/commit 失败中必须存在，其他 phase 为 nil。cleanup phase 的
`failed.operationID` 始终是稳定的 `cleanupOperationID`，不能拿可空的
`completionAttemptID` 代替；后者只关联进程内认证 completion。
scope 集合定义为：

- `temporaryAuthArtifacts(op)`：仅本次认证临时 handle/metadata。
- `candidateSessionArtifacts(op)`：包含本次 temporary auth、candidate Keychain/session/cache 写入。
- `allAppOwnedSessionData`：全部 app-owned credential、session metadata 和 candidate/temp artifacts，不含 Feature protected cache。
- `allAppOwnedProtectedData`：`allAppOwnedSessionData` 加全部按 session 绑定的 membership/受保护 cache，是 restored credential 失败时的保守范围。

转换：

| 事件 | from | to |
|---|---|---|
| `appStarted(noCredential,noPendingJournal)` | restoring | signedOut |
| `appStarted(restoredHandle,noOrphanArtifacts)` | restoring | validating(startup attempt, handle, signedOut, restoredCredential)；不创建导航 continuation |
| `appStarted(orphanTemporaryAuthArtifacts,noCommittedCredential)` | restoring | preparingCleanup(new cleanupOperationID, new requestID, detected operation-tagged temporary/candidate scope, destination: signedOut, fallback: signedOut, completionAttemptID: nil) |
| `appStarted(orphanTemporaryAuthArtifacts,committedCredentialPresent)` | restoring | preparingCleanup(new cleanupOperationID, new requestID, allAppOwnedProtectedData, destination: signedOut, fallback: signedOut, completionAttemptID: nil)；不能清 staging 后绕过既有凭据 |
| `appStarted(pendingCleanupLedger)` | restoring | signingOut(restored cleanupOperationID, new requestID, restored ledgerID/scopes/destination, completionAttemptID: nil；不重新猜范围) |
| `appStarted(pendingCommitJournal)` | restoring | rollingBackCommit(restored journalID/descriptor/recoveryDestination, completionAttemptID: nil) |
| `credentialRestoreFailure` | restoring | failed(phase: credentialRestore, fallback: signedOut, conservativeCleanupScope: allAppOwnedProtectedData, cleanupDestination: signedOut)；fail closed |
| `cleanupLedgerRestoreFailure` | restoring | failed(phase: cleanupLedgerRestore, fallback: signedOut, conservativeCleanupScope: allAppOwnedProtectedData, cleanupDestination: signedOut)；禁止 dismiss |
| `commitJournalRestoreFailure` | restoring | failed(phase: commitJournalRestore, fallback: signedOut, conservativeCleanupScope: allAppOwnedProtectedData, cleanupDestination: signedOut)；禁止 dismiss |
| `retryRestore` | failed(credentialRestore/cleanupLedgerRestore/commitJournalRestore) | restoring |
| `beginConservativeCleanup` | failed(credentialRestore/cleanupLedgerRestore/commitJournalRestore, conservative descriptor) | preparingCleanup(new cleanupOperationID, new requestID, exact conservative scope/destination, fallback: signedOut, completionAttemptID: nil)；replacement ledger durable 前不删除旧 journal/ledger |
| `startLogin` | clean signedOut | authenticating(new attemptID, origin: signedOut)；attemptID 同步交给导航 coordinator |
| `requestReauthentication(cleanupOperationID)` | matching expired 且无 cleanup 在途 | preparingCleanup(same cleanupOperationID, new requestID, allAppOwnedProtectedData, destination: signedOut, fallback: exact expired, completionAttemptID: nil)；进入状态并撤销 protected lease 后才返回 accepted receipt |
| `retryAuthentication` | failed(authentication, no pending cleanup) | authenticating(new attemptID, origin: fallback) |
| `authenticationCompleted(handle)` | matching authenticating | validating(same attemptID, handle, same origin, newLogin) |
| `authenticationCancelled` | authenticating | exact origin |
| `authenticationFailure` | authenticating | failed(phase: authentication, fallback: origin) |
| `validationSuccess(candidate,newLogin)` | matching validating | preparingCommit(attemptID, retryContextRef, candidateSessionID, origin, newLogin, descriptor: candidateSessionArtifacts(attemptID)→origin) |
| `validationSuccess(candidate,restoredCredential)` | matching validating | preparingCommit(attemptID, retryContextRef, candidateSessionID, origin, restoredCredential, descriptor: allAppOwnedProtectedData→signedOut) |
| `commitJournalPersisted` | preparingCommit | committing(same context + journalID)；journal durable 后才允许第一笔 Keychain/session/cache 写 |
| `commitJournalPersistenceFailure` | preparingCommit | failed(phase: commitPreparation, fallback: origin, validationSource: source, retryContextRef, exact conservative descriptor, no journal)；确认零 commit 写入 |
| `retryCommitPreparation` | failed(commitPreparation, retryContextRef) | preparingCommit(same source-aware descriptor) |
| `dismissCommitPreparationFailure` | failed(commitPreparation, validationSource, retryContextRef or conservative descriptor) | preparingCleanup(new cleanupOperationID, new requestID, exact descriptor, completionAttemptID: operationID only for newLogin; nil for restoredCredential) |
| `sessionCommitSuccessAndJournalRemoved` | matching committing | signedIn(new sessionID)；释放 validation context；仅 newLogin 向导航发布 attemptID，restoredCredential 不发布导航事件 |
| `sessionCommitFailure(rollbackComplete,journalRemoved)` | committing | failed(phase: commit, fallback: origin, validationSource: source, retryContextRef, exact source-aware descriptor) |
| `sessionCommitFailure(rollbackIncomplete)` | committing | rollingBackCommit(same journalID/descriptor/recoveryDestination, completionAttemptID: attemptID only for newLogin; nil for restoredCredential) |
| `sessionCommitFinalizeFailure` | committing | rollingBackCommit(same journalID/descriptor/recoveryDestination, completionAttemptID: attemptID only for newLogin; nil for restoredCredential) |
| `commitRollbackSuccessAndJournalRemoved` | rollingBackCommit | exact recovery destination；若 completionAttemptID 非空则发布 authentication failure |
| `commitRollbackFailure` | rollingBackCommit | failed(operationID: journal.operationID, phase: commitRecovery, completionAttemptID, exact conservative descriptor, pendingCommitJournalID)；fail closed |
| `retryCommitRecovery` | failed(commitRecovery, pendingCommitJournalID) | rollingBackCommit(same durable journal, same completionAttemptID) |
| `validationFailure(recoverable,newLogin)` | validating | failed(phase: validation, fallback: origin, validationSource: newLogin, retryContextRef, conservativeCleanupScope: temporaryAuthArtifacts(attemptID), cleanupDestination: origin) |
| `validationFailure(recoverable,restoredCredential)` | validating | failed(phase: validation, fallback: signedOut, validationSource: restoredCredential, retryContextRef, conservativeCleanupScope: allAppOwnedProtectedData, cleanupDestination: signedOut) |
| `retryValidation(contextResolved,newLogin)` | failed(validation/commit, validationSource: newLogin, retryContextRef, no cleanup/commit journal) | 先解析 handle/origin/source 并创建 new attemptID，再原子迁移 continuation；只有迁移成功后才进入 validating |
| `retryValidation(contextResolved,restoredCredential)` | failed(validation/commit, validationSource: restoredCredential, retryContextRef, no cleanup/commit journal) | 解析 handle/origin/source 后创建内部 new attemptID 并进入 validating；restored 流不期待、创建或迁移导航 continuation |
| `retryValidation(contextMissing,newLogin)` | failed(validation/commit, validationSource: newLogin, conservative descriptor) | 不创建 new attemptID、不迁移 key；创建 cleanupOperationID/requestID，以旧 operationID 为 completionAttemptID 进入 preparingCleanup |
| `retryValidation(contextMissing,restoredCredential)` | failed(validation/commit, validationSource: restoredCredential, conservative descriptor) | 不创建 new attemptID、不迁移 key；创建 cleanupOperationID/requestID，以 nil completionAttemptID 进入 preparingCleanup |
| `validationFailure(invalidCredential,newLogin)` | validating | preparingCleanup(new cleanupOperationID, new requestID, temporaryAuthArtifacts(attemptID), destination: origin, fallback: origin, completionAttemptID: attemptID) |
| `validationFailure(invalidCredential,restoredCredential)` | validating | preparingCleanup(new cleanupOperationID, new requestID, allAppOwnedProtectedData, destination: signedOut, fallback: signedOut, completionAttemptID: nil)，并发布 expired 原因 |
| `dismissFailure` | failed(authentication, no pending cleanup) | exact fallback |
| `dismissValidationFailure` | failed(validation/commit, validationSource, retryContextRef or conservative scope) | preparingCleanup(new cleanupOperationID, new requestID, conservative scope, destination: fallback, fallback: fallback, completionAttemptID: operationID only for newLogin; nil for restoredCredential) |
| `refreshStarted` | signedIn | refreshing(previous) |
| `refreshSuccess` | refreshing | signedIn |
| `refreshFailure(recoverable)` | refreshing | signedIn(previous) 并发布安全错误事件 |
| `refreshFailure(expired,sourceSessionID)` | refreshing(matching sessionID) | 原子递增 generation/撤销 lease 后进入 expired；取消受保护请求 |
| `serverExpired(sourceSessionID)` | signedIn/refreshing 且 sourceSessionID 匹配 | 原子递增 generation/撤销 lease 后进入 expired；取消受保护请求 |
| `signOut` | signedIn/expired | preparingCleanup(new cleanupOperationID, new requestID, all app-owned protected scopes, destination: signedOut, fallback: exact source, completionAttemptID: nil)；先原子撤销 lease，再 suspend Feature 能力并取消受保护请求 |
| `cleanupLedgerPersisted(cleanupOperationID,requestID,ledgerID)` | matching preparingCleanup | signingOut(same cleanupOperationID, new deletion requestID, ledgerID, exact scopes/destination/completionAttemptID)；Feature 能力保持撤销 |
| `cleanupLedgerPersistenceFailure(cleanupOperationID,requestID)` | matching preparingCleanup | failed(operationID: cleanupOperationID, phase: cleanupPreparation, fallback: exact fallback, retryContextRef, completionAttemptID, conservativeCleanupScope: exact scopes, cleanupDestination: exact destination, no ledger)；确认零删除后方可恢复 fallback 能力 |
| `retryCleanupPreparation` | failed(cleanupPreparation, operationID: cleanupOperationID, retryContextRef, no ledger) | 保留同一 cleanupOperationID，创建新 requestID；优先由 ref 恢复 exact scopes/destination/fallback，ref 损坏时使用独立 conservative descriptor，再次进入 preparingCleanup |
| `dismissCleanupPreparationFailure` | failed(cleanupPreparation, operationID: cleanupOperationID, retryContextRef, no ledger) | 仅当原事件是用户 signOut、零删除已确认且 fallback 的原 session artifacts 完整时回 exact signedIn/expired；递增到从未发放过的新 generation，signedIn 才签发新 lease，expired 保持 capability 撤销；旧 lease 永不重新激活。其他 scope fail closed、只能 retry |
| `cleanupSuccessAndLedgerRemoved(cleanupOperationID,requestID)` | matching signingOut | exact destination；发布脱敏 cleanup completion，若进程内存在 matching reauthentication launch request，则到 signedOut 后才创建全新 authentication attempt |
| `cleanupFailure(cleanupOperationID,requestID)` | matching signingOut | failed(operationID: cleanupOperationID, phase: cleanup, fallback: destination, completionAttemptID, conservativeCleanupScope: pending scopes, cleanupDestination: destination, pendingCleanupLedgerID)；不得恢复 signedIn |
| `retryCleanup` | failed(cleanup, operationID: cleanupOperationID, pendingCleanupLedgerID) | signingOut(same cleanupOperationID, new requestID, same durable ledger, same completionAttemptID) |

认证 continuation 生命周期由导航 coordinator 独占：

| Session 事件/阶段 | `pendingAuthenticationContinuationByAttemptID` 动作 |
|---|---|
| `startLogin` | 在启动认证前创建 `attemptID → continuation`；创建失败则不启动 |
| newLogin 的 authentication completed、validating、preparingCommit、committing | 保留同一个 key |
| restoredCredential 的 validating、preparingCommit、committing | 不创建且不期待导航 key；attemptID 仅用于 Session 内部请求身份 |
| `authenticationCancelled` | consume 为 cancelled 并删除 key |
| recoverable authentication failure；newLogin 的 validation/commit-preparation/rollback-complete commit failure | 保留旧 key，等待 retry/dismiss |
| restoredCredential 的 recoverable validation/commit failure | 不创建导航 key；retry/dismiss 只处理 Session 状态 |
| `retryAuthentication` 或 `retryValidation(contextResolved,newLogin)` | 解析成功后、启动新 attempt 前原子迁移 `oldAttemptID → newAttemptID`；迁移失败则不启动 |
| `retryValidation(contextResolved,restoredCredential)` | 不创建/迁移导航 key；解析成功后用新的内部 attemptID 启动 |
| `retryValidation(contextMissing,newLogin)` | 不创建/迁移新 key；旧 attemptID 作为 completionAttemptID 进入 cleanup |
| `retryValidation(contextMissing,restoredCredential)` | 不创建/迁移 key；以 nil completionAttemptID 进入 cleanup |
| `dismissFailure` | consume 为 failure 并删除旧 key |
| newLogin invalid credential、`dismissValidationFailure/dismissCommitPreparationFailure` 进入 cleanup | 将原 attemptID 作为 `completionAttemptID` 保留到 cleanup terminal |
| restoredCredential invalid/dismiss 进入 cleanup | completionAttemptID 为 nil；不生成导航 completion |
| newLogin rollback-incomplete/finalize failure 进入 `rollingBackCommit` | 保留原 key；commit journal 持久化 recovery scope，continuation 仍只在内存 |
| restoredCredential rollback-incomplete/finalize failure | completionAttemptID 为 nil；只恢复 Session 数据一致性 |
| commit rollback failure | newLogin 保留 key、restoredCredential 不存在 key；retry recovery 均不迁移 |
| `commitRollbackSuccessAndJournalRemoved` 且 completionAttemptID 非空 | consume 为 failure 并删除 |
| cleanup-ledger persistence failure | completionAttemptID 非空时 retry 保留 key；仅满足上表安全 dismiss guard 时 consume 为 failure，否则保留且 fail closed |
| cleanup failure | completionAttemptID 非空时保留 key；retry 不迁移业务 continuation |
| `cleanupSuccessAndLedgerRemoved` 且 completionAttemptID 非空 | consume 为 failure 并删除；不得重试受保护业务 |
| `sessionCommitSuccessAndJournalRemoved(newLogin)` | consume 为 success、删除 key，并且原受保护任务最多显式重试一次 |
| `sessionCommitSuccessAndJournalRemoved(restoredCredential)` | 不消费不存在的 key、不重试旧业务，只发布 signedIn capability |
| process restart | 内存 continuation 全部取消；可恢复 cleanup ledger/commit journal，但不得在新进程猜测或自动重试旧业务任务 |
| 任意 terminal event 找不到 key | 记录脱敏 diagnostics；不猜 route、不重试业务 |

expired 重新认证的“清理后启动”使用另一张进程内表
`pendingAuthenticationLaunchAfterCleanupByCleanupOperationID`：

- 在发送 `requestReauthentication` 前原子创建稳定 cleanupOperationID 和
  对应 key；创建失败不开始 cleanup。Session 只在 matching expired 且没有
  cleanup 在途时采用同一个 ID，并返回不可含糊的 accepted/rejected receipt。
- 发送失败或 rejected receipt 时，导航 coordinator 只删除 matching
  cleanupOperationID 的预注册 key；accepted 后即使调用 task 收到取消，也
  保留 key 贯穿 preparation/deletion retry，直到 matching terminal event。
- cleanup/retry 期间保留 key；cleanup 成功到 signedOut 后消费 key，再按
  `startLogin` 的正常规则创建全新 attemptID/continuation。
- cleanup 失败或 ledger 恢复期间不得提前打开登录容器。
- 进程重启会丢弃 key；durable ledger 仍完成清理并停在 signedOut，不自动
  弹出浏览器，也不猜旧业务 continuation。

不变量：

- attemptID/sessionID 不匹配的回调和 response 被丢弃。
- interactive newLogin 只能从 clean signedOut 开始；expired 必须先完成
  `allAppOwnedProtectedData` durable cleanup。因而 newLogin commit journal
  只描述 candidate artifacts，不承担旧 session 替换。
- 同一 authentication completion 最多建立一个 session；领域事件不依赖 WebView、系统浏览器或其他平台登录容器。
- new-login credential handle 在 commit 前只能位于按 operationID 标记的 staging namespace，不能作为 active restored credential；进程重启发现 orphan staging artifact 时先写 cleanup ledger 并清理。
- 远端验证成功不直接发布 `signedIn`；在第一笔 Keychain/session/cache commit 写之前，必须原子持久化不含 secret 的 CommitJournal。Keychain write、当前 session 发布、受保护 cache 绑定在 `committing` 中完成可回滚提交。
- CommitJournal 只含 operation tag、phase、source-aware conservative descriptor、安全 recovery destination 和幂等版本；不含 credential handle/value。只有 `sessionCommitSuccessAndJournalRemoved` 或 `commitRollbackSuccessAndJournalRemoved` 才能清 journal。
- 进程在 commit 任意写入点退出时，下次启动先按 journal 进入 `rollingBackCommit`；rollback-incomplete/finalize failure 继续使用原 journal，不能在 replacement ledger 持久化前丢失 partial-artifact 记录。
- 登出必须清 Keychain 凭据、app-owned session、受保护 cache 和本次认证产生的临时数据；WebKit/系统浏览器数据的可清范围由登录 ADR 与 U-37 决定，不能假装全部可控。
- 进入 `preparingCleanup` 时先 suspend Session capability、原子递增受保护
  generation/撤销全部旧 `ProtectedDataLease` 并取消在途写，再计算 scope 和
  写 ledger；此窗口不允许新 credential/cache 写。Repository/cache 的每次
  protected write 在提交前复核 lease，取消竞态后的晚到结果只能丢弃。只有
  ledger 写失败且确认零删除后，才可按 fallback 恢复 capability；恢复时
  必须递增为从未发放过的新 generation，旧 lease 永不重新激活。
- `cleanupOperationID` 从首次进入 cleanup 到 preparation retry、durable
  deletion retry 和 terminal event 始终不变；每次异步尝试另建 requestID，
  旧 requestID 回调全部丢弃。
- 每次进入 `signingOut` 前，必须先原子持久化不含 secret 的 CleanupLedger
  （ledgerID、cleanupOperationID、scope 类型、幂等版本和安全归一化
  destination）；只有 matching `cleanupSuccessAndLedgerRemoved` 才清
  ledger。进程在 signingOut 任意点退出，下次启动恢复同一 operation ID 和
  ledger、创建新 requestID，不能留下未跟踪的 crash window。
- cleanup 失败时 durable ledger 保持存在且 Feature 能力保持撤销；若 ledger 首次持久化失败，则删除尚未开始并回到明确 failure/fallback，不得声称已退出。
- cleanup-preparation failure 不能把仍含临时/失效 credential 的状态降格为 clean `signedOut`；只有用户 signOut 前的完整 signedIn/expired source 可在“零删除”证明后恢复。
- recoverable refresh failure 保留同一 session 的 previous summary；只有已分类为 expired/invalid credential 的结果才能迁移到 `expired`。
- session invalidation signal 必须携带发出请求时的 sessionID；旧 session 的
  401/业务失败不能 expire 当前新 session。真实 error code 未经 fixture/
  RUNTIME_EVIDENCE 不得映射为 expired。
- retryContextRef 缺失/损坏时禁止猜 credential、origin、source、scope 或 destination；`failed.validationSource` 与独立保存的 conservative cleanup descriptor 只允许决定 completion 是否存在及保守清理，不能重建 credential。descriptor 缺失本身是 fail-closed restore error，不得 dismiss 为 clean signedOut。
- cleanup-ledger restore failure 与普通 credential restore failure是不同事件；两者都只能 retry restore 或先写 replacement ledger 后执行 conservative cleanup，不能直接 dismiss 绕过遗留数据。
- 启动恢复优先级固定为：可读 cleanup ledger → 可读 commit journal → orphan staging cleanup → committed credential validation → signedOut。发现 orphan staging 与 committed credential 并存时，必须先以 `allAppOwnedProtectedData` 写 ledger 并保守清理到 signedOut，不能只清 staging 后遗留 active credential/cache；任何 journal 读取/解码失败都 fail closed，不得跳到后续分支。
- 日志、state description、测试附件只持 credential handle，不持凭据值。
- 公开 Forum/Thread 状态不因退出被销毁。
- internal SessionState 不直接作为 SwiftUI `@Observable` state；UI 只接收
  不含 handle/ref/journal/ledger 的 `SessionViewSnapshot(capability,
  publicAccountSummary?, revision)`，revision 单调递增。

`UNKNOWN`：登录方式、token rotation、真实 expired taxonomy；在确认前 session adapter 必须 fixture-first。

## App Shell / 导航状态

```text
AppNavigationState {
  selectedRoot
  routesByRoot
  presentedMedia?
  presentedAuthentication?
  pendingDeepLink?
  pendingAuthenticationContinuationByAttemptID
  pendingAuthenticationLaunchAfterCleanupByCleanupOperationID
  restorationRevision
}
```

- Tab 切换只改 `selectedRoot`。
- 当前 Tab 重选为 no-op，不 pop、不滚顶、不 refresh。
- route identity 只含 stable ID/name；anchor/filter/sort/target 是一次性
  NavigationIntent，不参与 Hashable/Store key，也不放生成 Proto。
  NavigationCommand 在 `(sceneID,rootID,identity)` Store 创建/复用后于
  MainActor 恰好一次派发 intent，不把它存入仅按 identity 键控的 map。
- deep link 先解析/校验；Forum/Thread 外部链接确定性进入 `recommendationsRoot`，cold/warm 相同。App 内 push 保持来源 root。
- Store identity 是 `(sceneID, rootID, routeIdentity)`，同一业务 ID 在不同
  scene/root 的状态互不覆盖。
- size class 改变只改变同一 routes 的容器投影，不写回第二份 SplitView
  selection。
- 认证 continuation 只由导航 coordinator 按 attemptID 持有，SessionState 不持 returnRoute；创建、保留、原子迁移和 consume 时机严格使用上表。缺 key 或 process restart 时不得猜 route 或自动重试业务请求。
- authentication 是受控、进程内、不可恢复 presentation；成功后回到原
  route 并最多显式重试原受保护任务一次。
- versioned restoration 只保存 selectedRoot、route identity 与已批准的
  非敏感 filter/read anchor；Store、opaque NavigationPath、sessionID、
  auth continuation、MediaViewer/descriptor、loading/error/task 均不保存。
  运行恢复正确性仍由 U-40/U-42 保持 `UNKNOWN/NOT_TESTED`。

## 错误分类

所有状态机使用领域错误，而不是把 `Throwable.message` 直接显示：

- `offline`
- `timeout`
- `cancelled`（不展示）
- `unauthenticated`
- `sessionExpired`
- `server(code, safeMessage?)`
- `malformedResponse`
- `unavailableContent`
- `unsupportedContent`
- `rateLimited`（运行证据待定）
- `unknown`

真实 error code 到上述分类的映射保持 `UNKNOWN`，直到 `Specs/API_EVIDENCE.md` 的 fixture 建立。

## 最小状态测试

每个 P0 列表必须覆盖：

- initial success/empty/failure/cancel；
- refresh success/empty/failure/cancel 且旧内容保持；
- next success/overlap/empty/failure/cancel；
- duplicate cursor 防重；
- refresh 与 next 并发；
- stale response；
- session expired；
- malformed mapper；
- route 返回/Tab 切换/size change 状态保持。

Media 另覆盖 zoom coordinator 单一几何真相、gesture owner、取消/完成 reset、
pager 仲裁、item/boundary failure、旋转；Session 另覆盖无/有效/失效
restored handle、orphan staging、pending cleanup/commit journal 启动恢复、
重复 completion、旧 attempt、continuation 迁移/缺失、expired 先
cleanup→signedOut 再创建新 attempt、旧 session invalidation、lease 撤销后
晚到 cache write、认证/验证/refresh failure、commit journal 写入前后及每个
Keychain/session/cache midpoint crash、rollback 完整/不完整、cleanup-ledger
写入 crash window、cleanupOperationID 跨 preparation/deletion retry 稳定且
requestID 更新、重复/竞态 reauthentication 的 accepted/rejected receipt
不会遗留 launch key、safe dismiss 不复活旧 lease、Keychain/cleanup
failure 与 cleanup retry。
