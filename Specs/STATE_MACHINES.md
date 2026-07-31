# P0 状态机

状态：`READY_FOR_PHASE_02_INPUT_WITH_UNKNOWNS`

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
| `reachTail` | loaded 且非 terminal 且 cursor 空闲 | nextPage | append+dedupe；空页是否 terminal 取决于 fixture | nextPageFailure |
| `retryInitial/Refresh/Next` | 对应失败态 | 原请求 identity 的新 attempt | 对应成功态 | 保持失败态并更新 error |
| `filtersChanged` | loaded/empty | 新 generation refresh | 新过滤结果 | refreshFailure(previous) |

`UNKNOWN`：推荐 endpoint 无已证终止信号。直到 fixture 证明规则，连续空页策略只能作为受测 client policy，不得伪称服务端 `hasMore`。

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
- refresh/load-next/load-previous 互斥规则由 generation + cursor 保证。
- readAnchor 使用稳定 post id；数组 index 只用于瞬时滚动实现。

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

## MediaViewer

Android 静态证据（`CODE_EVIDENCE`）：

- `PhotoViewUiIntent.Init/LoadPrev/LoadMore`。
- 初始远端失败回退本地 items；边界失败静默；按 pic id 去重。
- Android 单击关闭、独立 Activity 和第三方 zoom 行为不可照搬。

领域状态：

```text
MediaViewerState =
  preparing(source, initialMediaID)
  | ready(items, currentMediaID, chromeVisible, boundaryState)
  | itemFailure(items, currentMediaID, error)
  | boundaryFailure(items, direction, cursor, error)
  | closing(returnContext)

PerMediaTransform = identity | zoomed(scale, translation)
```

事件：

- `present(source, initialMediaID)`：按 media id 定位；找不到时显示 unavailable，不把旧 index 指向其他图。
- `page(direction)`：当前页未缩放或横向 pan 已到边界时才交给 pager。
- `pinch/doubleTap/pan`：只更新当前 media transform；换页后每页状态策略固定为重置 identity。
- `singleTap`：切换 chrome；不关闭。
- `loadItem/retryItem`：占位尺寸与黑底保持。
- `reachBoundary`：一次只发一个 prev/next request；失败提供重试。
- `close`：恢复来源 route/anchor，不刷新父列表。
- size/rotation change：重新约束 transform，不泄漏到相邻 media。
- 进程恢复：不恢复 MediaViewer overlay；只恢复父 route。当前进程内的完整 `MediaDescriptor` 才是可呈现输入，单独 pic id 不足以重建 URL 和边界加载上下文。

`UNKNOWN`：Android 第三方手势范围不作为 iOS 输入；iOS 最终参数和 UIKit/SwiftUI 归属需阶段 02/ADR。

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
  | preparingCleanup(cleanupAttemptID, scopes, destination, fallback, completionAttemptID?)
  | signingOut(sessionID?, cleanupAttemptID, ledgerID, pendingScopes, destination, completionAttemptID?)
  | failed(operationID?, phase, error, recoverable, fallback, validationSource?, retryContextRef?, conservativeCleanupScope, cleanupDestination?, pendingCleanupLedgerID?, pendingCommitJournalID?)

AuthenticationOrigin =
  signedOut
  | expired(sessionID, reason, recoverable)

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
validation/commit 失败中必须存在，其他 phase 为 nil。
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
| `appStarted(orphanTemporaryAuthArtifacts,noCommittedCredential)` | restoring | preparingCleanup(detected operation-tagged temporary/candidate scope, destination: signedOut, fallback: signedOut, completionAttemptID: nil) |
| `appStarted(orphanTemporaryAuthArtifacts,committedCredentialPresent)` | restoring | preparingCleanup(allAppOwnedProtectedData, destination: signedOut, fallback: signedOut, completionAttemptID: nil)；不能清 staging 后绕过既有凭据 |
| `appStarted(pendingCleanupLedger)` | restoring | signingOut(restored ledgerID/scopes/destination, completionAttemptID: nil；不重新猜范围) |
| `appStarted(pendingCommitJournal)` | restoring | rollingBackCommit(restored journalID/descriptor/recoveryDestination, completionAttemptID: nil) |
| `credentialRestoreFailure` | restoring | failed(phase: credentialRestore, fallback: signedOut, conservativeCleanupScope: allAppOwnedProtectedData, cleanupDestination: signedOut)；fail closed |
| `cleanupLedgerRestoreFailure` | restoring | failed(phase: cleanupLedgerRestore, fallback: signedOut, conservativeCleanupScope: allAppOwnedProtectedData, cleanupDestination: signedOut)；禁止 dismiss |
| `commitJournalRestoreFailure` | restoring | failed(phase: commitJournalRestore, fallback: signedOut, conservativeCleanupScope: allAppOwnedProtectedData, cleanupDestination: signedOut)；禁止 dismiss |
| `retryRestore` | failed(credentialRestore/cleanupLedgerRestore/commitJournalRestore) | restoring |
| `beginConservativeCleanup` | failed(credentialRestore/cleanupLedgerRestore/commitJournalRestore, conservative descriptor) | preparingCleanup(exact conservative scope/destination, fallback: signedOut, completionAttemptID: nil)；replacement ledger durable 前不删除旧 journal/ledger |
| `startLogin` | signedOut/expired | authenticating(new attemptID, origin: current stable state)；attemptID 同步交给导航 coordinator |
| `retryAuthentication` | failed(authentication, no pending cleanup) | authenticating(new attemptID, origin: fallback) |
| `authenticationCompleted(handle)` | matching authenticating | validating(same attemptID, handle, same origin, newLogin) |
| `authenticationCancelled` | authenticating | exact origin |
| `authenticationFailure` | authenticating | failed(phase: authentication, fallback: origin) |
| `validationSuccess(candidate,newLogin)` | matching validating | preparingCommit(attemptID, retryContextRef, candidateSessionID, origin, newLogin, descriptor: candidateSessionArtifacts(attemptID)→origin) |
| `validationSuccess(candidate,restoredCredential)` | matching validating | preparingCommit(attemptID, retryContextRef, candidateSessionID, origin, restoredCredential, descriptor: allAppOwnedProtectedData→signedOut) |
| `commitJournalPersisted` | preparingCommit | committing(same context + journalID)；journal durable 后才允许第一笔 Keychain/session/cache 写 |
| `commitJournalPersistenceFailure` | preparingCommit | failed(phase: commitPreparation, fallback: origin, validationSource: source, retryContextRef, exact conservative descriptor, no journal)；确认零 commit 写入 |
| `retryCommitPreparation` | failed(commitPreparation, retryContextRef) | preparingCommit(same source-aware descriptor) |
| `dismissCommitPreparationFailure` | failed(commitPreparation, validationSource, retryContextRef or conservative descriptor) | preparingCleanup(exact descriptor, completionAttemptID: operationID only for newLogin; nil for restoredCredential) |
| `sessionCommitSuccessAndJournalRemoved` | matching committing | signedIn(new sessionID)；释放 validation context；仅 newLogin 向导航发布 attemptID，restoredCredential 不发布导航事件 |
| `sessionCommitFailure(rollbackComplete,journalRemoved)` | committing | failed(phase: commit, fallback: origin, validationSource: source, retryContextRef, exact source-aware descriptor) |
| `sessionCommitFailure(rollbackIncomplete)` | committing | rollingBackCommit(same journalID/descriptor/recoveryDestination, completionAttemptID: attemptID only for newLogin; nil for restoredCredential) |
| `sessionCommitFinalizeFailure` | committing | rollingBackCommit(same journalID/descriptor/recoveryDestination, completionAttemptID: attemptID only for newLogin; nil for restoredCredential) |
| `commitRollbackSuccessAndJournalRemoved` | rollingBackCommit | exact recovery destination；若 completionAttemptID 非空则发布 authentication failure |
| `commitRollbackFailure` | rollingBackCommit | failed(operationID: completionAttemptID, phase: commitRecovery, exact conservative descriptor, pendingCommitJournalID)；fail closed |
| `retryCommitRecovery` | failed(commitRecovery, pendingCommitJournalID) | rollingBackCommit(same durable journal, same completionAttemptID) |
| `validationFailure(recoverable,newLogin)` | validating | failed(phase: validation, fallback: origin, validationSource: newLogin, retryContextRef, conservativeCleanupScope: temporaryAuthArtifacts(attemptID), cleanupDestination: origin) |
| `validationFailure(recoverable,restoredCredential)` | validating | failed(phase: validation, fallback: signedOut, validationSource: restoredCredential, retryContextRef, conservativeCleanupScope: allAppOwnedProtectedData, cleanupDestination: signedOut) |
| `retryValidation(contextResolved,newLogin)` | failed(validation/commit, validationSource: newLogin, retryContextRef, no cleanup/commit journal) | 先解析 handle/origin/source 并创建 new attemptID，再原子迁移 continuation；只有迁移成功后才进入 validating |
| `retryValidation(contextResolved,restoredCredential)` | failed(validation/commit, validationSource: restoredCredential, retryContextRef, no cleanup/commit journal) | 解析 handle/origin/source 后创建内部 new attemptID 并进入 validating；restored 流不期待、创建或迁移导航 continuation |
| `retryValidation(contextMissing,newLogin)` | failed(validation/commit, validationSource: newLogin, conservative descriptor) | 不创建 new attemptID、不迁移 key；以旧 operationID 为 completionAttemptID 进入 preparingCleanup |
| `retryValidation(contextMissing,restoredCredential)` | failed(validation/commit, validationSource: restoredCredential, conservative descriptor) | 不创建 new attemptID、不迁移 key；以 nil completionAttemptID 进入 preparingCleanup |
| `validationFailure(invalidCredential,newLogin)` | validating | preparingCleanup(temporaryAuthArtifacts(attemptID), destination: origin, fallback: origin, completionAttemptID: attemptID) |
| `validationFailure(invalidCredential,restoredCredential)` | validating | preparingCleanup(allAppOwnedProtectedData, destination: signedOut, fallback: signedOut, completionAttemptID: nil)，并发布 expired 原因 |
| `dismissFailure` | failed(authentication, no pending cleanup) | exact fallback |
| `dismissValidationFailure` | failed(validation/commit, validationSource, retryContextRef or conservative scope) | preparingCleanup(conservative scope, destination: fallback, fallback: fallback, completionAttemptID: operationID only for newLogin; nil for restoredCredential) |
| `refreshStarted` | signedIn | refreshing(previous) |
| `refreshSuccess` | refreshing | signedIn |
| `refreshFailure(recoverable)` | refreshing | signedIn(previous) 并发布安全错误事件 |
| `refreshFailure(expired)` | refreshing | expired；取消受保护请求 |
| `serverExpired` | signedIn/refreshing | expired；取消受保护请求 |
| `signOut` | signedIn/expired | preparingCleanup(all app-owned protected scopes, destination: signedOut, fallback: exact source, completionAttemptID: nil)；立即 suspend Feature 能力并取消受保护请求 |
| `cleanupLedgerPersisted` | preparingCleanup | signingOut(ledgerID, exact scopes/destination/completionAttemptID)；Feature 能力保持撤销 |
| `cleanupLedgerPersistenceFailure` | preparingCleanup | failed(operationID: completionAttemptID, phase: cleanupPreparation, fallback: exact fallback, retryContextRef, conservativeCleanupScope: exact scopes, cleanupDestination: exact destination, no ledger)；确认零删除后方可恢复 fallback 能力 |
| `retryCleanupPreparation` | failed(cleanupPreparation, retryContextRef, no ledger) | 优先由 ref 恢复 exact scopes/destination/fallback；ref 损坏时使用独立 conservative descriptor，再次进入 preparingCleanup |
| `dismissCleanupPreparationFailure` | failed(cleanupPreparation, retryContextRef, no ledger) | 仅当原事件是用户 signOut、零删除已确认且 fallback 的原 session artifacts 完整时回 exact signedIn/expired；其他 scope fail closed、只能 retry |
| `cleanupSuccessAndLedgerRemoved` | signingOut | exact destination |
| `cleanupFailure` | signingOut | failed(operationID: completionAttemptID, phase: cleanup, fallback: destination, conservativeCleanupScope: pending scopes, cleanupDestination: destination, pendingCleanupLedgerID)；不得恢复 signedIn |
| `retryCleanup` | failed(cleanup, pendingCleanupLedgerID) | signingOut(same durable ledger, new attempt, same completionAttemptID) |

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

不变量：

- attemptID/sessionID 不匹配的回调和 response 被丢弃。
- 同一 authentication completion 最多建立一个 session；领域事件不依赖 WebView、系统浏览器或其他平台登录容器。
- new-login credential handle 在 commit 前只能位于按 operationID 标记的 staging namespace，不能作为 active restored credential；进程重启发现 orphan staging artifact 时先写 cleanup ledger 并清理。
- 远端验证成功不直接发布 `signedIn`；在第一笔 Keychain/session/cache commit 写之前，必须原子持久化不含 secret 的 CommitJournal。Keychain write、当前 session 发布、受保护 cache 绑定在 `committing` 中完成可回滚提交。
- CommitJournal 只含 operation tag、phase、source-aware conservative descriptor、安全 recovery destination 和幂等版本；不含 credential handle/value。只有 `sessionCommitSuccessAndJournalRemoved` 或 `commitRollbackSuccessAndJournalRemoved` 才能清 journal。
- 进程在 commit 任意写入点退出时，下次启动先按 journal 进入 `rollingBackCommit`；rollback-incomplete/finalize failure 继续使用原 journal，不能在 replacement ledger 持久化前丢失 partial-artifact 记录。
- 登出必须清 Keychain 凭据、app-owned session、受保护 cache 和本次认证产生的临时数据；WebKit/系统浏览器数据的可清范围由登录 ADR 与 U-37 决定，不能假装全部可控。
- 进入 `preparingCleanup` 时先 suspend Session capability、递增受保护请求 generation 并取消在途写，再计算 scope 和写 ledger；此窗口不允许新 credential/cache 写。只有 ledger 写失败且确认零删除后，才可按 fallback 恢复 capability。
- 每次进入 `signingOut` 前，必须先原子持久化不含 secret 的 cleanup ledger（ledgerID、scope 类型、幂等版本和安全归一化 destination）；只有 `cleanupSuccessAndLedgerRemoved` 才清 ledger。进程在 signingOut 任意点退出，下次启动先恢复同一 ledger，不能留下未跟踪的 crash window。
- cleanup 失败时 durable ledger 保持存在且 Feature 能力保持撤销；若 ledger 首次持久化失败，则删除尚未开始并回到明确 failure/fallback，不得声称已退出。
- cleanup-preparation failure 不能把仍含临时/失效 credential 的状态降格为 clean `signedOut`；只有用户 signOut 前的完整 signedIn/expired source 可在“零删除”证明后恢复。
- recoverable refresh failure 保留同一 session 的 previous summary；只有已分类为 expired/invalid credential 的结果才能迁移到 `expired`。
- retryContextRef 缺失/损坏时禁止猜 credential、origin、source、scope 或 destination；`failed.validationSource` 与独立保存的 conservative cleanup descriptor 只允许决定 completion 是否存在及保守清理，不能重建 credential。descriptor 缺失本身是 fail-closed restore error，不得 dismiss 为 clean signedOut。
- cleanup-ledger restore failure 与普通 credential restore failure是不同事件；两者都只能 retry restore 或先写 replacement ledger 后执行 conservative cleanup，不能直接 dismiss 绕过遗留数据。
- 启动恢复优先级固定为：可读 cleanup ledger → 可读 commit journal → orphan staging cleanup → committed credential validation → signedOut。发现 orphan staging 与 committed credential 并存时，必须先以 `allAppOwnedProtectedData` 写 ledger 并保守清理到 signedOut，不能只清 staging 后遗留 active credential/cache；任何 journal 读取/解码失败都 fail closed，不得跳到后续分支。
- 日志、state description、测试附件只持 credential handle，不持凭据值。
- 公开 Forum/Thread 状态不因退出被销毁。

`UNKNOWN`：登录方式、token rotation、真实 expired taxonomy；在确认前 session adapter 必须 fixture-first。

## App Shell / 导航状态

```text
AppNavigationState {
  selectedRoot
  pathByRoot
  storeByRouteIdentity
  presentedMedia?
  pendingDeepLink?
  pendingAuthenticationContinuationByAttemptID
}
```

- Tab 切换只改 `selectedRoot`。
- route 由 stable ID/name Hashable 表示，不放生成 Proto。
- deep link 先解析/校验；Forum/Thread 外部链接确定性进入 `recommendationsRoot`，cold/warm 相同。App 内 push 保持来源 root。
- Store identity 是 `(rootID, routeIdentity)`，同一业务 ID 在不同 root 的状态互不覆盖。
- size class 改变只改变容器呈现，不重置路径。
- 认证 continuation 只由导航 coordinator 按 attemptID 持有，SessionState 不持 returnRoute；创建、保留、原子迁移和 consume 时机严格使用上表。缺 key 或 process restart 时不得猜 route 或自动重试业务请求。
- session route 是受控 sheet/push；成功后回到原 route 并显式重试原受保护任务。
- 进程恢复的精确持久化集合仍是 `UNKNOWN`，但至少 route identity 与非敏感 filter/read anchor 可编码。

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

Media 另覆盖 transform/pager 仲裁、item/boundary failure、旋转；Session 另覆盖无/有效/失效 restored handle、orphan staging、pending cleanup/commit journal 启动恢复、重复 completion、旧 attempt、continuation 迁移/缺失、认证/验证/refresh failure、commit journal 写入前后及每个 Keychain/session/cache midpoint crash、rollback 完整/不完整、cleanup-ledger 写入 crash window、Keychain/cleanup failure 与 cleanup retry。
