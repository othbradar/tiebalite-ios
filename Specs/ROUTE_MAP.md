# P0 Route 与容器映射

状态：`APPROVED_WITH_RUNTIME_UNKNOWNS`

本文件是阶段 02 的实现 route 契约；阶段 01 的 Android/产品证据仍见
`Specs/NAVIGATION_MAP.md`。决策来源为
`Docs/ADRs/ADR-0003-navigation-and-ipad.md`。

## Canonical 模型

每个 scene 只有：

```text
AppTab = recommendations | followedForums | settings
RootID = recommendations | followedForums

RouteIdentity =
  forum(validatedForumID?, validatedForumName)
  | thread(threadID)
  | subposts(threadID, postID)

NavigationIntent =
  forum(initialTabID?, sort?, classify?)
  | thread(anchorPostID?, authorFilter?, sort?, forumContext?)
  | subposts(targetSubpostID?, forumContext?)
```

`selectedTab` 是 Shell 选择的唯一真相。`settings` 仅为阶段 05 静态 P1
占位，不能转换为 `RootID`，不拥有 P0 route chain、Feature Store 或恢复
数据；`routesByRoot` 的 key 始终且仅为两个 `RootID`。阶段 05 允许
`settingsPath=[componentGallery]` 这一条仅 Debug 可达的 Shell 路径，用于
跨容器测试；它不属于业务 route，不持久化，Release 没有入口。

本文用 `activeRoot = selectedTab.rootID` 表示当前业务 root；选择 settings
时 `activeRoot=nil`，不得另存一份可写 `selectedRoot`。

`RouteIdentity` 参与 Hashable/path/Store key/restoration；`NavigationIntent`
不参与 identity，也不存入 identity-only map；NavigationCommand 在
`(sceneID,rootID,identity)` Store 创建/复用后于 MainActor 恰好一次派发
intent。MediaViewer 和 Authentication 是 presentation，不是持久 route。

Store identity 是 `(sceneID, rootID, RouteIdentity)`。同一业务对象从两个
root 打开是两个 Store；同 root 的同一 identity 加新 intent 复用 Store。

## P0 route

| route/presentation | 最小 identity/input | 一次性 intent | auth | 持久化 | iPhone | iPad regular |
|---|---|---|---|---|---|---|
| recommendations root | RootID | 无 | public；live 匿名 UNKNOWN | root + safe list snapshot ref | Tab 内 root list | content list |
| followedForums root | RootID | session capability | required | root；不持 membership/sessionID | Tab 内 root list/login state | content list/login state |
| forum | 可选正 forumID + 非空且通过边界校验的 forumName | initial tab/sort/classify | public；FRS 匿名首屏+一页下一页已验证 | identity + approved safe filter | push | detail root |
| thread | 正 Int64 threadID | anchor/filter/sort/forum context | public；live 匿名 UNKNOWN | identity + approved safe read state | push | detail root/tail |
| subposts | 正 threadID + postID | targetSubpostID/forum context | inherit thread | identity；target 是否保留由 safe snapshot | push | detail tail |
| MediaViewer presentation | source root/route/item + ordered descriptors + initial media ID | boundary context | inherit source | 否 | 唯一 full-screen presentation | 同一唯一 presentation |
| Authentication presentation | attemptID + 平台容器输入 | continuation 在 coordinator | 不适用 | 否 | 受控 sheet/full-screen | 受控 presentation |

关注吧和其他已证业务入口同时携带正 forumID 与 forumName；只含吧名的外部
deep link 使用 `forumID=nil`，不得猜造 ID。forumName 只做单次 percent decode、
trim、空值和本地资源上限校验；不宣称
Unicode normalization 已确定，NFC/NFKC 与服务端等价性继续由 U-43 跟踪。
未知服务端大小限制不猜测。数值 ID 溢出、零/负值或缺失时拒绝命令，不构造
占位业务 ID。

## 容器映射

### iPhone

- 两个 root 各自拥有系统 NavigationStack。
- settings 静态占位使用独立系统 NavigationStack，但不进入 P0 route map。
- selectedTab 切换只改变可见 stack。
- 当前 Tab 重选为 no-op；不 pop、不滚顶、不 refresh。
- 系统 back/pop 完成后再释放被移除 route Store。

### iPad regular

- sidebar：selectedTab；业务列从 `activeRoot` 派生。
- content：当前 root 的推荐/关注吧列表。
- detail：routes 首项；routes tail 投影到 detail 内 NavigationStack。
- 从 content 选择新 Forum/Thread 时替换当前 root detail chain。
- detail 内 Forum → Thread → Subposts 追加 tail。
- SplitView selection 全由 canonical routes 派生，不单独持久化。

### compact/collapse

同一 selectedTab/routes 投影为 Tab + 完整 NavigationStack。容器变化不能
修改、截断、重排 route，也不能创建第二 Store。

## NavigationCommand

P0 合法 chain grammar：

- recommendations：`[]`、`[forum]`、`[thread]`、`[forum,thread]`、
  `[thread,subposts]`、`[forum,thread,subposts]`；
- followedForums：`[]`、`[forum]`、`[forum,thread]`、
  `[forum,thread,subposts]`；
- subposts 的 threadID 必须等于紧邻前置 thread 的 threadID；
- 同一 chain 内禁止重复 RouteIdentity，最大深度为 3。

每次 command 和 snapshot 恢复都验证上述 grammar。

| command | 前置 | canonical mutation | Store 行为 |
|---|---|---|---|
| `selectTab(tab)` | tab 已知 | 只改 selectedTab | 两 root Store 均保留 |
| `reselectCurrentRoot` | 已选 root | no-op | 无 Action |
| `selectRootDetail(route,intent?)` | 从 root content | 当前 root routes=`[route]` | 复用/创建 route Store，消费 intent |
| `push(route,intent?)` | 来源 route 可见且结果 grammar 合法 | identity 已在当前 chain 时 pop-to/reuse；否则 append | 创建/复用 Store 后恰好一次派发 intent |
| `pop` | routes 非空 | 删除末项 | 转场完成后释放末项 Store |
| `replaceTail(route)` | detail selection change | 替换受影响 tail | 释放旧 tail Store |
| `presentMedia(input)` | source context/descriptor 输入通过结构校验 | 只写 presentedMedia；initial ID 缺失也允许进入稳定 unavailable | 父 Store 不变，不按 index 替代 |
| `dismissMedia` | media active | 清 presentedMedia | 不 refresh 父 Store |
| `presentAuthentication(attempt)` | continuation 已原子注册 | 写 ephemeral presentation | Session 不持 returnRoute |
| `completeAuthentication` | matching attempt | 清 presentation、consume continuation | 最多显式重试原任务一次 |

任何 command 的参数校验失败时 canonical state 不变，仅产生安全领域错误。

阶段 09 Open-Source Beta 的固定 `ThreadMediaIntent` 暂将 missing initial 归入
结构校验失败，因此不写 `presentedMedia`；表中的稳定 unavailable 仍是动态
presentation 的长期合同，必须在接入可变媒体 Repository 前实现。

## Deep Link

支持的第一版输入：

- `com.baidu.tieba://unidispatch/frs?kw=...`
- `com.baidu.tieba://unidispatch/pb?tid=...`
- `https://tieba.baidu.com/f?kw=...`
- `https://tieba.baidu.com/p/{tid}`

解析使用 scheme/host/path 白名单、单次 decode、长度/数值检查。官方 scheme
长期稳定性、中文编码与 redirect 仍是 UNKNOWN。

restoration 完成后应用 deep link：

- Forum → selectedTab=recommendations，recommendations routes=`[forum]`；
- Thread → selectedTab=recommendations，recommendations routes=`[thread]`；
- followedForums routes 不变；
- warm/cold 结果相同；
- App 内点击不强制换 root。

阶段 14 的 `ForumHomeStore` 以 `(rootID, ForumRoute)` 缓存；Forum → Thread
push 时保留同一 Store 和稳定帖子 anchor，系统 pop 后恢复原列表位置。替换或
移除 Forum route 后才取消并释放对应 Store；普通 View 更新不会重复首屏请求。

不跟随未批准 redirect，不把 URL/query 写日志。

## 状态恢复 DTO

```text
NavigationSnapshotV1 {
  version
  selectedRoot // 仅两个业务 RootID
  routeIdentitiesByRoot
  safeRootStateByRoot?
  safeRouteStateByRootAndRouteIdentity?
}
```

可保存：route identity、已批准的非敏感 filter/read anchor。不得保存：Store、
opaque NavigationPath、sessionID/token、auth attempt/continuation、
MediaViewer/descriptor/URL、loading/error/task。

阶段 05 的 settings 与 `settingsPath` 不进入 snapshot。生成快照时若
`selectedTab=settings`，`selectedRoot` 确定性写为 recommendations；恢复
只选择两个业务 root，不能恢复到 settings。

恢复步骤：

1. 未知 version 时丢弃整份 snapshot，回 recommendations root，不按 V1
   猜测。
2. 已知 version 内验证 selectedRoot；无合法 root 时回 recommendations，
   并由它派生 selectedTab。
3. 每 root 从首项开始验证上述 route grammar、ID 约束与重复 identity。
4. 在首个非法 identity 截断，保留最长合法前缀。
5. root safe state 必须匹配 root/version，route safe state 必须匹配
   `(rootID, RouteIdentity)`/version；不匹配时只丢对应 safe state。
6. 完成恢复后再原子应用 pending deep link。

## Session 变化

- expired 不删除公开 Forum/Thread route。
- followedForums 立即隐藏旧 membership，绑定旧 lease 的写入失效。
- expired 的 interactive 新登录先 durable cleanup 到 signedOut，再创建 attempt。
- auth continuation 只在进程内；重启后取消，不猜 route。
- 登出保留公开 route；受保护 Store 转为 signedOut/sessionExpired state。

## 验收

- 两 root 独立压入不同链并切换 20 次。
- 同 root 同 thread 的不同 anchor 不产生重复 route/Store。
- regular/compact 往返后 canonical routes 完全相同。
- cold/warm deep link 相同，另一 root 不变。
- snapshot 坏版本丢弃整份；已知版本内坏 ID/非法 grammar 恢复最长合法前缀。
- media/login 活跃时进程退出只恢复父 route。
- iPhone/iPad 系统 back 可用，无自定义全局返回手势。

上述容器、恢复和 deep-link 验收在工程建立前均为 `NOT_TESTED`；U-40、
U-42、U-43 保持开放到对应 deterministic/UI 证据完成。
