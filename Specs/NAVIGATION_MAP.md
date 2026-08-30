# 导航地图

状态：`APPROVED_WITH_RUNTIME_UNKNOWNS`

本文件只定义稳定路由身份、入口和恢复语义，不指定 SwiftUI 实现。Android 证据来自 `MainActivityV2.kt`、`MainPage.kt` 及各 `@Destination` 页面；iOS 容器约束来自 `Specs/04_INTERACTION_CONTRACT.md`。

## 顶层结构

`CODE_EVIDENCE`：Android 使用单一 `DestinationsNavHost(NavGraphs.root)`；主页面内部用不可横滑的 pager 承载 home/explore/notification/user，宽度变化时改用 bottom bar、rail 或 drawer。

`INFERENCE` / iOS 规范：

```text
AppShell
├── RecommendationsStack
└── FollowedForumsStack

└── SettingsStack（history/about/licenses/content）

iPad:
NavigationSplitView
├── Sidebar: selectedRoot
├── Content: selected root list
└── Detail: canonical routes projection

全局覆盖：
└── MediaViewer（唯一实例）
```

- P0 主入口固定为推荐和关注吧；阶段 16B 已实现独立 P1
  Settings/History 路径，但没有将它们变成第三个业务 RootID。
  阶段 16A 的搜索是 recommendations root 下的普通 P1 route，
  没有改变任何 P0 root/Tab identity。
- 每个主入口拥有独立导航路径、列表状态和滚动状态。
- 主入口切换只切可见树，不重建其他入口。
- iPhone 使用系统 `NavigationStack`；iPad 使用系统 `NavigationSplitView`。
- MediaViewer 是受控覆盖层，不属于任何 Feature 自制 pager。
- Android 的单 root NavHost、返回键先跳 home、Compose pager 和 rail/drawer 只是平台实现，不是 iOS 规范。

## 稳定 route

| iOS 稳定 route | Android 页面/入口 | 参数 | 可恢复所需最小值 | 返回时必须保留 | 证据 |
|---|---|---|---|---|---|
| `recommendationsRoot` | `PersonalizedPage` / Explore personalized | 无 | route id | 列表、cursor/page、滚动、错误尾状态 | `CODE_EVIDENCE` + 产品范围 |
| `followedForumsRoot` | `HomePage` 的关注吧区域 | 无 | route id + session ref | 同一 session 的列表、加载/错误状态、滚动；不含 P1 置顶/历史 | `CODE_EVIDENCE` + 产品范围 |
| `settingsRoot` | `UserPage` → `SettingsPage` | 无 | 不进业务 root snapshot | 外观/阅读设置由 Repository 持久；settingsPath 不持久 | Android 页面 `CODE_EVIDENCE`；阶段 16B iPhone/iPad Fixture `RUNTIME_EVIDENCE` |
| `forum` | `ForumPageDestination` | `forumName: String` 必需；已知业务入口另携可选正 `forumID`；`initialTab/sort` 仅本地状态 | 单次 decode/trim 后非空；外部 deep link 的 forumID 为 nil，不猜造；Unicode normalization 仍为 U-43 | 吧摘要、首屏帖子、当前 tab/sort/classify、各 tab 列表与滚动 | `CODE_EVIDENCE` + 阶段 14 决策 |
| `thread` | `ThreadPageDestination` | identity 仅 `threadID: Int64`；`forumID/anchorPostID/authorFilter/sort` 是一次性 NavigationIntent；Android `from/scrollToReply` 不进入稳定 route | threadID | 已加载楼层、前后 cursor、sort/filter、阅读锚、滚动 | Android 参数为 `CODE_EVIDENCE`；identity/intent 拆分为阶段 02 决策 |
| `subposts` | `SubPostsPage/SheetDestination` | identity 为 `threadID + postID`；`forumID/targetSubpostID` 是一次性 NavigationIntent；Android `loadFromSubPost` 不进入 route identity | threadID + postID | 楼中楼列表、页码、目标 subpost | Android 参数为 `CODE_EVIDENCE`；identity/intent 拆分为阶段 02 决策 |
| `mediaViewer`（非持久 overlay） | `PhotoViewActivity` | 进程内 `sourceRouteIdentity/sourceItemID`、有序 `MediaDescriptor`、initial media id、可选边界上下文 | 不单独做进程恢复；恢复父 route 后关闭 overlay | 来源 route、来源滚动；当前进程内按 media id 定位 | Android输入模型为 `CODE_EVIDENCE`；非持久 overlay 与 descriptor 契约为 `INFERENCE` |
| `authentication`（非持久 presentation） | `LoginPageDestination` | completion destination 由导航 coordinator 按 attemptID 持有；不传 token | 不单独恢复；恢复父 route 后关闭 presentation | 原页面状态；成功后最多显式重试受保护任务一次 | Android入口为 `CODE_EVIDENCE`；非持久 presentation 为阶段 02 决策 |
| `search` | `SearchPageDestination` / `tblite://search` | route identity 无参数；query 是 SearchStore 状态，不进 route | route id | normalized query、forum/thread 结果、thread page 与滚动锚 | Android 页面/Hybrid endpoint 为 `CODE_EVIDENCE`；阶段 16A Fixture 与匿名 Live `RUNTIME_EVIDENCE` |
| `userProfile` | `UserProfilePageDestination` | 正 `userID: Int64`；name/portrait 仅降级显示 | userID | 来源 Thread 与已加载内容 | Android/Proto `CODE_EVIDENCE`；阶段 16B Fixture route `RUNTIME_EVIDENCE` |
| `history` | `HistoryPageDestination` | 无 | 不进导航 snapshot；历史 Repository 独立持久 | 列表、大致滚动、返回后原记录 | Android 行为线索 + 阶段 16B iOS 契约/Fixture `RUNTIME_EVIDENCE` |
| `threadStore` | `ThreadStorePageDestination` | 无 | route id + session ref | 列表/页码 | `CODE_EVIDENCE`; P1 只读 |
| `forumDetail` | `ForumDetailPageDestination` | `forumID: Int64` 必需 | forumID | 来源 Forum 状态 | `CODE_EVIDENCE`; P1/按需 |

写操作页面 `ReplyPage`、投票提交、编辑资料和删除确认不进入 iOS route 表。

## 页面入口与边

| 来源 | 动作 | 目标 | 条件 |
|---|---|---|---|
| 推荐页 toolbar | 搜索 | `search` | 普通 route；iPhone push，iPad replace detail |
| 搜索吧结果 | 点吧 | `forum` | 正 forumID + 非空 forumName |
| 搜索帖子结果 | 点帖子 | `thread` | threadID 必须安全解析为正 Int64 |
| 推荐列表 | 点主题/回复数 | `thread` | threadID 必须可解析；forumID 可选 |
| 推荐列表 | 点吧名 | `forum` | forumName 非空 |
| 推荐列表 | 点作者 | `userProfile` | P1；userID 合法 |
| 关注吧列表 | 点吧 | `forum` | 正 forumID + forumName 非空 |
| Forum 最新/精品/GeneralTab | 点主题 | `thread` | threadID 必须可解析 |
| Forum toolbar | 搜索 | `search` 或 forum-scoped search | P1；携带 forumName |
| Forum header | 吧资料 | `forumDetail` | P1 |
| Thread | 点楼中楼摘要 | `subposts` | threadID + postID |
| Thread | 点图片 | `mediaViewer` | 以 media id 定位初始页 |
| Thread/PbContent | 点作者或 mention | `userProfile` | P1；非法 uid 不导航 |
| Thread/PbContent | 点链接 | 系统外链流程 | P1；校验 scheme |
| 受保护入口 | 未登录 | `authentication` presentation | continuation 原子注册后才展示；登录成功后回原 route 并最多显式重试一次 |
| Settings/User | 历史 | `history` | 阶段 16B；使用 settingsPath |
| History | 点 thread/forum/user 记录 | 现有 `thread/forum/userProfile` | 仅安全最小 route 值，保留 History Store |
| About | 开源许可 | `licenses` | 现有 Settings stack 子 route |
| Settings/User | 收藏 | `threadStore` | P1，只读 |

## Deep Link

`CODE_EVIDENCE`：

- Android 接受 `com.baidu.tieba://unidispatch/frs?kw=...`。
- Android 接受 `com.baidu.tieba://unidispatch/pb?tid=...`。
- Android 接受 `https://tieba.baidu.com/f?kw=...`。
- Android 接受 `https://tieba.baidu.com/p/{tid}`。
- Android Compose route 另定义 `tblite://forum/{forumName}`、`tblite://search` 和通知 route。

`INFERENCE` / iOS 规范：

- 第一版只承诺能稳定映射的 `forumName` 与数值 `threadID`。
- URL 必须经过 scheme/host/path 白名单与参数长度检查。
- 无效/缺失/溢出 ID 返回可恢复错误，不 crash、不创建空模型。
- deep link 不得携带 Cookie、token、完整 Proto 或用户私密内容。
- cold start 与 warm start 必须产生相同 route。
- Forum/Thread 外部 deep link 无论 cold/warm 都归入 `recommendationsRoot` 并选中该 root；其他 root 的路径保持不变。App 内导航仍留在发起它的 root。
- 外部 Forum/Thread deep link 在 restoration 后原子替换 recommendations root
  的 detail chain 为单一目标 route，避免 warm state 改变结果；root 列表
  Store 保留。
- Store identity 使用 `(rootID, routeIdentity)`；同一 thread 从两个 root 打开时状态互不覆盖，不能因 ID 相同跨 root 偷换页面。
- `UNKNOWN`：官方 scheme 的长期稳定性、中文吧名编码、短链/分享链重定向；验证方法见 `Specs/UNKNOWN_BEHAVIORS.md`。

## 返回与状态恢复

### 列表 → 子页 → 列表

1. push 前保存稳定 route identity 和可观察列表状态；anchor/filter/sort
   作为一次性 intent 交给 Store，不进入 route identity。
2. 子页只持有业务 ID，不拥有父列表。
3. pop 后复用原 Store；不因 `onAppear` 无条件刷新。
4. 已有内容过期时可后台 refresh，但必须保持滚动与旧内容。

阶段 14 已用 Fixture 验证 Forum 中部帖子 → 现有 ThreadReader → 系统返回后
稳定 row 的屏幕位置保持；Forum Store 在 route chain 仍含 Forum 时继续由
scene/root registry 持有。该证据不证明阶段 15 分页后的跨页位置恢复。

### Tab 切换

- 切换不清空路径、Store、filter 或 scroll anchor。
- P0 推荐/关注吧当前 root 重选固定为 no-op：不 pop、不滚顶、不 refresh。
  Android 的全局 refresh 只提供行为线索，不进入 iOS 契约。

### Session 变化

- `signedIn → expired` 不销毁当前浏览 route。
- 受保护数据转为 session-expired 状态；关注吧 membership 默认隐藏并绑定原 session，不跨账号显示。公开 Forum/Thread 内容可按缓存分类继续浏览。
- expired 的同凭据续期走 Session refresh；interactive 新登录先撤销旧 lease，
  durable cleanup 到 signedOut，随后才创建新 attempt。
- 登录 continuation 只存在于进程内 `AppNavigationState.pendingAuthenticationContinuationByAttemptID`，SessionState 不持 returnRoute；创建/迁移/消费遵守 `Specs/STATE_MACHINES.md` 的 continuation 表。成功后只重试 attemptID 对应的任务；进程重启取消旧 continuation，不得猜 route 或重建整个导航树。
- 退出时删除敏感 session 与受保护 cache；公开 Forum/Thread route 可以保留。

### MediaViewer

- 打开时记录来源 route、来源 item id 和 initial media id。
- 关闭只恢复来源，不隐式刷新。
- 数据刷新后若 initial id 仍存在按 id 定位；不存在则显示稳定不可用状态并
  保留关闭动作，不自动关闭、不按旧 index 指向另一张图。
- MediaViewer 只作为进程内 overlay；进程恢复时恢复父 route 并关闭 overlay。fixture 可以用完整 `MediaDescriptor` 直接测试，但不能声称仅凭 pic id 可从冷启动重建 URL/边界上下文。

阶段 09 Open-Source Beta 只接受固定 intent：构造时 initial ID 不存在会被视为
结构错误并保持父 view，不呈现 overlay。上述“已呈现后 ID 消失 → 稳定
unavailable”仍是必须保留的长期合同，待动态媒体 Repository 接入前关闭该偏离。

## Android 不可作为 iOS 规范的行为

- `NavSerializer.ThreadNavBridge` 只有四项 LRU，cache miss 返回空 `ThreadInfo()`。
- 一个 root NavHost 管理所有主入口。
- Tab 使用 pager 但禁用用户横滑。
- Android back 在非 home Tab 时优先跳 home。
- MediaViewer 单击直接关闭。
- 固定 `delay(20/1000/1500/2000)` 驱动滚动、刷新或返回。
- Reply bottom sheet、Android system bar、Activity/Intent 传参和 Compose 转场。

## 导航验收

- 每个持久 route 都能仅用“最小可恢复值”从 fixture 冷启动；非持久 MediaViewer 从父 route 的固定 media fixture 打开。
- 相同 ID 重建 route 不产生重复业务页面。
- 连续 push Forum → Thread → Subposts → MediaViewer 后逐层返回，父层状态均不变。
- iPhone 竖屏、iPad 横屏和至少两个分屏宽度执行同一业务链。
- deep link 坏参数、未知 route、session 过期和 media 消失均有确定性降级。
- route 状态测试与 UI smoke 不依赖真实网络。
