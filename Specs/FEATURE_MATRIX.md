# 功能矩阵

状态：`IMPLEMENTED_THROUGH_PHASE_15_THREAD_READING_WITH_UNKNOWNS`

本矩阵把 Android `4.0-dev@5545326b2a8e0d784b2f3dfbcb219c7b121e61c2` 的静态证据转换为 iOS 验收范围。它不授权真实接口接入；endpoint 必须先满足 `Specs/API_EVIDENCE.md` 的 fixture 和运行证据门槛。

标签：

- `CODE_EVIDENCE`：Android 路径与 symbol 可定位。
- `INFERENCE`：由产品章程和多处源码归纳出的 iOS 语义。
- `UNKNOWN`：需脱敏运行证据。

## P0

| 功能 | Android 证据与数据源 | 登录 | iOS 验收流程 | 状态 |
|---|---|---:|---|---|
| App Shell / 主 Tab | `MainPage.kt::MainPage`；home/explore/notification/user；单 root NavHost | 产品无认证要求 | P0 两个 root（推荐/关注吧）各自独立 push 两层，切换往返仍保留栈、列表与滚动；当前 root 重选按 ADR-0003 固定为 no-op；iPhone/iPad 只投影同一 canonical routes，宽度切换不丢 route | `CODE_EVIDENCE` + 阶段 02 决策 |
| 深链基础 | `MainActivityV2.kt::checkIntent` 把 forumName/threadId 映射到 Forum/Thread | 产品公开；endpoint 认证另见目标页面 | 仅凭稳定 ID/name 从冷启动打开吧/帖子；坏参数安全拒绝；不依赖预载 Proto；cold/warm 均进入 recommendations root | `CODE_EVIDENCE` + `INFERENCE` |
| 推荐流 | `PersonalizedPage/ViewModel` → `PersonalizedRepository` → Personalized Proto | 产品公开；真实 endpoint 匿名能力 `UNKNOWN` | fixture 启动：成功、空、失败；刷新保留旧内容；分页去重且保序；尾部失败可重试；同页互斥；旧响应不能覆盖新请求 | `CODE_EVIDENCE`; auth/终止 `UNKNOWN` |
| 关注的吧 | `HomeViewModel` → `allForumGuideFlow` → `ForumGuideBean` | 产品要求登录 | 未登录显示明确登录入口；按 session 原子聚合多页；后续页失败/重试可测；刷新保留同 session 旧列表；账号切换立即隐藏旧 membership；点击进入正确 forumName | `LOCAL_SYNTHETIC_TESTED`; HTTPS `EVIDENCE_BLOCKED`;失效码 `UNKNOWN` |
| 吧首页信息 | `ForumPage` + `ForumViewModel.Load` → FRS Page | 产品公开；固定公开吧匿名首屏已验证 | forumName 自足打开；显示吧名/简介/统计的已证字段；缺字段降级；返回保留首屏列表与滚动；头像显示延后 | `LIMITED_RUNTIME_EVIDENCE` + Fixture tests |
| 吧内主题列表 | `ForumThreadListViewModel`、`GeneralTabListViewModel` → FRS/ThreadList/GeneralTab | 产品公开；FRS 固定公开吧匿名首屏已验证，ThreadList/GeneralTab 未验证 | 首屏置顶与普通项稳定并可进入帖子；动态 tab、排序和分页留待后续，未知时安全回退 | 首屏 `LIMITED_RUNTIME_EVIDENCE`; tab/分页边界 `UNKNOWN` |
| 帖子阅读 | `ThreadPage/ViewModel` → `PbPageRepository` → PB Page Proto | 产品公开；匿名普通升序首屏与一页下一页已有限运行验证 | threadId 自足打开；标题/作者/首楼/回复；基本下一页按 postID 去重保序；缺作者、折叠、畸形内容降级；返回保持锚点；唯一虚拟列表以 1000 楼合成 Fixture 验证 | `LIMITED_RUNTIME_EVIDENCE` + `LOCAL_1000_FLOOR_VIRTUALIZATION_TESTED`；倒序/只看楼主/跳楼/完整错误形态 `UNKNOWN` |
| 楼中楼只读 | `SubPostsPage/ViewModel` → PB Floor Proto | PBPage 内联预览已有限运行验证；独立 PB Floor 匿名能力 `UNKNOWN` | 当前按稳定 ID 内联最多 4 条 PBPage 预览并显示总数；完整楼中楼页/分页仍待后续；不出现回复或发布能力 | 内联 `LIMITED_RUNTIME_EVIDENCE`；完整页 `CODE_EVIDENCE` + `UNKNOWN` |
| 内容节点 | `PbContent.proto` + `Extensions.kt::renders` + `ThreadPage.PostCard` | 继承来源页面 | text/link/emoji/mention/image 正常；video/voice/poll 按矩阵展示或降级；未知 raw type 保留占位和相邻顺序；所有畸形 fixture 不崩溃 | `CODE_EVIDENCE` + `INFERENCE` |
| MediaViewer | `PhotoViewActivity/ViewModel` 提供来源集合、索引和边界加载语义 | 继承来源页面 | 唯一查看器；黑底；从点击图开始；左右分页、双击/捏合/平移；缩放与翻页仲裁；失败占位/重试；关闭回到原位置；旋转/尺寸变化稳定；进程恢复只回父 route | `CODE_EVIDENCE` + iOS 契约 |
| Session / 登录 | `LoginPage.LoginWebViewClient`、`AccountUtil`、`Account` entity | 不适用；只能由用户显式发起 | 平台无关的成功/取消/失败/过期事件；凭据仅 Keychain；profile 与凭据分离；重复 completion 只创建一次 session；退出原子清理 app-owned 数据；不得使用明文 HTTP | `CODE_EVIDENCE`; 登录边界 `UNKNOWN` |
| 状态保持 | Android 内存态与 history anchor 提供行为线索 | 否 | 返回、Tab 切换、旋转和分屏不丢列表/筛选/导航/阅读锚；进程恢复策略有测试并明确哪些状态不恢复 | `INFERENCE`; Android 进程恢复 `UNKNOWN` |
| iPhone/iPad 布局 | Android window size class 证明宽度适配需求 | 否 | iPhone 系统 NavigationStack；iPad 系统 split；横竖屏和常见分屏宽度；无设备型号/固定屏幕判断 | 产品契约 |
| 可访问性与外观 | Android 仅提供部分 contentDescription/主题证据 | 否 | Dynamic Type、VoiceOver、稳定 identifier、触控区域、深色模式、Reduce Motion；状态与手势在关闭动效后仍可用 | 产品契约；Android 覆盖 `UNKNOWN` |
| Fixture 与自动化 | Android 业务测试为零 | 否 | 每个 P0 有状态测试、repository/mapper fixture 测试和关键 UI smoke；不依赖实时网络 | 产品契约 |

## P1

| 功能 | Android 证据 | iOS 边界 | 状态 |
|---|---|---|---|
| 搜索吧/主题/用户 | `SearchPage` 及三个结果 ViewModel；SearchSug Proto + Hybrid JSON | 吧/主题为首选；用户页可后置。输入使用 latest-cancel，结果分页有尾部失败；不复制共享 GlobalEvent | `CODE_EVIDENCE`; endpoint 运行态 `UNKNOWN` |
| 浏览历史 | `HistoryDao`、`HistoryUtil`、`HistoryPage` | 按吧/帖子分类、最近访问、阅读锚；无痕模式不写；畸形旧记录安全跳过 | `CODE_EVIDENCE` + `INFERENCE` |
| 用户资料只读 | `UserProfilePage/ViewModel`、GetUserInfo/Profile Proto | 只展示已证公开字段；不提供关注、私信、编辑等写操作 | `CODE_EVIDENCE` |
| 设置 | `SettingsPage`、`DataStore.kt`、`AppPreferencesUtils` | 只保留主题、字号、图片策略、阅读偏好等跨平台项；迁移和默认值可测试 | `CODE_EVIDENCE` + `INFERENCE` |
| 收藏/关注只读展示 | ThreadStore、UserLikeForum 页面 | 只展示服务端已有状态，不触发收藏/关注写请求 | `CODE_EVIDENCE` |
| 外链与分享 | PbContent link、WebView/launchUrl、Android share | 使用系统安全外链/分享边界；未知 scheme 不执行 | `CODE_EVIDENCE` + `INFERENCE` |

P1 是已有范围的库存，不等于 endpoint 接入批准。用户资料、收藏/关注只读等尚未在
`Specs/API_EVIDENCE.md` 形成完整候选条目；未来若排期，必须先独立补齐来源、
认证、request/response、分页、fixture 与 UNKNOWN，不得沿用 Android 调用直接实施。

## 未排期候选

| 功能 | Android 证据 | 边界 | 状态 |
|---|---|---|---|
| 热门/关注动态/应用内通知列表 | Explore/Concern/Hot/Notifications | 不在已批准 P0/P1；需产品范围变更后重新审计。推送通知本身仍明确排除 | 页面存在为 `CODE_EVIDENCE`；产品优先级 `UNKNOWN` |

## 明确排除

下列能力即使 Android 有实现，也不得进入只读 iOS 客户端：

| 排除项 | Android 例证 | iOS 要求 |
|---|---|---|
| 签到/一键签到 | `ForumUiIntent.SignIn`、OKSign service | 不显示可执行入口，不调用 endpoint |
| 发帖/回帖/楼中楼发布 | `ReplyPage`、`AddPostRepository` | 现有内容只读展示；不创建编辑器 |
| 点赞/投票提交 | `Agree*`、`PollThread` | 可展示计数/投票结果，不发写请求 |
| 关注/取消关注 | `Like/Unlike/Unfollow` | 只展示关注状态 |
| 删除/屏蔽远端内容 | `DeletePost/DeleteThread` | 不调用远端写接口；本地显示过滤另行规格 |
| 收藏写操作 | `AddFavorite/RemoveFavorite` | 只读显示现有收藏 |
| 推送通知与后台签到 | Notification service、boot receiver | 首版不接入 |
| 账号资料编辑 | `EditProfileActivity` | 只读 |
| 绕过认证/TLS/平台限制 | cleartext 和 legacy client 仿真 | 明确禁止 |

## P0 端到端验收场景

1. 推荐：匿名 fixture 冷启动 → 首屏 → 触底两页 → 下拉刷新 → 制造下一页失败 → 重试 → 返回后位置不变。
2. 关注吧：未登录 → 显式登录 scenario → 原子聚合多页 → 制造后续页失败/重试 → 进入吧 → 返回 → 账号切换不显示旧列表 → 模拟过期 → 重新认证或退出。
3. FRS：以 forumName 打开 → latest/good/动态 tab → 改排序 → 触底 → 重复页 → 失败重试 → 返回保留 tab/滚动。
4. PB：以 threadId 打开 → 首楼/回复/楼中楼 → 锚定 pid → 前后页 → 图片查看 → 关闭返回 → 删除/缺作者/未知节点 fixture 不崩溃。
5. Session：认证/验证成功与失败、newLogin 与 restoredCredential 分别重试（restored 不创建导航 continuation）、expired 先撤销 lease 并 durable cleanup 到 signedOut 后才创建新登录 attempt、commit-journal 各写入 midpoint crash/回滚、orphan staging 单独存在及与 committed credential 并存、取消、重复回调、旧 session 失效信号和晚到 protected write、refresh 可恢复失败、过期、cleanup-ledger 写入失败、退出 cleanup 失败/重试、无/有效/失效 credential 与 pending cleanup/commit journal 的重启恢复；任何日志和附件不含 Cookie/token。

状态机细节见 `Specs/STATE_MACHINES.md`；尚不能执行的真实网络条件见 `Specs/UNKNOWN_BEHAVIORS.md`。
