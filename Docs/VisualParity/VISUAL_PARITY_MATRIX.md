# 视觉与功能一致性矩阵

R13：`USER_VISUALLY_APPROVED`（2026-09-27），基线 R12 `60ea8d6`。自动化失败均定向转绿、原记录保留，干净 Debug/Release/隔离及静态通过。真实账号主要页面与六屏 Android 对照已完成，分页/横滑、iPad 我的清旧帖与 full/narrow/full 获用户确认；用户最后补图确认断网保留原列表，并明确联网重试成功。软件键盘断开 Simulator 硬件键盘连接后恢复，无 App 补丁。具体证据与历史边界见 `R13_ACCEPTANCE.md`。两台完整 Live 保留登录，用户已明确授权提交 R13，提交后单独恢复发帖风控排查。

R12：`USER_VISUALLY_APPROVED`（2026-09-27）。用户明确授权提交 R12 并进入 R13。用户已明确接受标题居中并确认导航栏方块修复，最终采用两处 `.principal`；额外iPhone3项/iPad1项短Smoke、lint/build/secret/diff通过，两台完整Live覆盖安装且登录保留。过程见 `R12_NAVIGATION_BAR_REDESIGN.md`，UIKit备选无需实施。真实账户头部/统计、头像共用、本人资料和我的菜单、Settings/History/Search 平面布局已实现；19 Unit、iPhone3项/iPad4项短Smoke、lint/build/secret/diff通过。正常Live两台保留登录、截图矩阵与完整失败记录见 `R12_ACCEPTANCE.md`。额外Live发现iPad横屏从深层帖子切我的时右侧仍留原帖，点击本人头像后正常打开资料，未定位来源、未扩大导航修改。已获用户验收与提交授权，已知 iPad 问题留待 R13 复核。

R01：`USER_VISUALLY_APPROVED`（2026-09-23）。共用头像、等级、分割线、元数据、1–8 图网格与平面 skeleton 已实现，字段链路及图片复用定向测试通过；截图和限制见 `R01_ACCEPTANCE.md`。iPhone/iPad 完整组件截图已保存；重新打开 iPhone Gallery 后，用户回复“行可以”，确认视觉通过。未提交；完整页面仍按下表后续阶段处理。

R02：`USER_VISUALLY_APPROVED`（2026-09-23）。用户批准最小承载修订后，当前基线原卡死重新复现；推荐列表复用既有 VirtualizedList 后原回归连续 3/3 通过。iPad 侧栏返回位置和既有帖子返回偏移检查仍未通过，全部结果见 `R02_LIST_REDESIGN_ACCEPTANCE.md`。用户查看 Simulator 后确认“现在没问题了”，授权提交并进入 R03。此前返回位置失败仍保留，不宣称自动化全绿。

R03：`USER_VISUALLY_APPROVED`（2026-09-23）。用户反馈“我看了可以了提交R03进入R04”，授权提交并开始 R04。实际验证与历史失败见 `R03_ACCEPTANCE.md`。

R04：`USER_VISUALLY_APPROVED`（2026-09-23）。用户确认作者头像已修复，授权提交 R04 并进入 R05；提交前定向门禁及历史失败见 `R04_ACCEPTANCE.md` / `R04_AUTHOR_AVATAR.md`。

R05：`USER_VISUALLY_APPROVED`（2026-09-23），已按用户授权提交 `50c5cb2`，未推送。紧凑吧头、真实普通分类/精华、最新排序、独立分页和滚动 anchor、平面帖子流已实现。阅读导航及底部白条修订已获用户验收：吧/帖子隐藏根底栏，iPad 竖屏全宽、横屏原三列；iPhone/iPad 各一条短回归通过 <=1pt 底边断言。历史 Stage17 的2个基线失败和连续旋转 XCTest 限制仍保留，详见 `R05_ACCEPTANCE.md` / `R05_NAVIGATION_REVISION.md`，不改写为自动化全绿。

R06：`USER_VISUALLY_APPROVED`（2026-09-23，用户授权提交并进入 R07）。平面楼层、真实作者字段、连续图片原比例网格、前三条预览及全部route、只读回复条已实现。定向Unit/图片复用及iPhone/iPad短Smoke、lint/build通过；23个共享承载/图片/Session/Store保护文件不变。两台覆盖安装后停在多图+三条预览样本，截图及迭代见 `R06_ACCEPTANCE.md`。1000楼Unit通过，手工快速滚动未由工具确认，待复核；原阶段未提交；本次已获提交并进入R07授权。

R06 后续用户修订：人工交付改为保留账号的完整Live应用；全部应用日期中文化，帖子吧chip已移到返回键右侧的固定顶部栏并显示圆形真实吧图。20项定向Unit、两台短UI、lint/build通过，用户同一QLC帖子真实日期/头像截图在ToolbarRevision/iphone-live-after.png。本次Store仅为新增头像字段增加一行保留逻辑，共享列表/图片/Session等22文件仍不变；以前样本交付与23文件不变是历史结果，当前以R06_ACCEPTANCE.md修订记录为准。用户已确认本次修订通过；提交前22项Unit、2项短UI、lint/build通过。

| 屏幕 | 当前主要问题 | Android 目标 | 阶段 |
|---|---|---|---|
| 根 Shell | 四项入口已完成；原卡死回归 3/3，返回位置仍有失败 | 首页/动态/消息/我的 | R02 |
| 推荐 | R04 平面信息流已实现，真实作者头像经获批 HTTP 兼容已显示；用户已验收 | 平面动态流、头像/时间/吧标签/动作栏、多图 | R04 |
| 关注吧 | R03 平面搜索、最近访问 chips、真实吧图/热度/Lv；两个已验证 CDN 使用 HTTPS，用户视觉验收通过 | Android 首页紧凑层级；R12 已接真实当前账户头像 | R03 |
| 吧首页 | R05 已实现并获用户视觉验收；Live长交互的旧自动化缺口见验收记录 | 紧凑吧头、最新排序、精华/分类 Pager、平面帖子流 | R05 |
| 帖子 | R06 已获用户批准；1000楼快速滚动证据缺口保留 | 平面楼层、头像/Lv、图片瀑布/网格、前三条预览 | R06 |
| 表情 | R07用户已验收：目录全量127张（Android默认104+官方扩展23），名称与显式ID已覆盖；本次11 Unit/iPhone1/iPad1通过，见R07_ACCEPTANCE.md最新修订 | 官方表情内联图片 | R07 |
| 楼中楼 | R08只读分页/资料页已实现；表情修订补齐所报三页内5种可取得原图的Shoubai表情，18 Unit及两台短Smoke通过；368/绝原图404、纯文本[图片]缺数据，用户已批准R08，见R08_ACCEPTANCE.md | 独立分页楼中楼 | R08 |
| 写入 | R09已获用户批准提交；四种文字编辑器/草稿已实现；用户首次Live因账号JSON MIME失败，已修正并真实验证只读前置资料；补齐原版回复外层签名，主题回复已获用户手动发送成功及新增第9楼截图确认；其余写入类型未单独Live验证；R10图片链路已有Mock验证，正文内联笑眼已Live显示；用户批准的原生输入区域修订已完成，iPhone三轮开合/滚动与iPad转屏定向回归通过，完整Live原帖已显示四图和笑眼/滑稽等内联表情，USER_VISUALLY_APPROVED；用户手动完成单图加表情主题回复并提供已发布第15楼截图，授权提交R10；其余写入目标、多图Live发布和Live重试未单独验证 | 新帖、回复主题/楼层/楼中楼 | R09/R10 |
| 消息 | R11 USER_VISUALLY_APPROVED（2026-09-25）：双页/真实计数、独立分页、表情/引用；引用打开首楼，正文进入完整帖子自动定位一级回复（楼中楼定位父楼）；首次有效布局后一次恢复。iPhone/iPad定向验证通过，用户确认消息定位与根末吧遮挡修订均已改好，授权提交；未读非零Live变化等UNKNOWN保留。详见R11_NOTIFICATIONS.md，已提交9681d39 | 回复我的/提到我的 + 未读 | R11 |
| 我的 | R12已接真实头像/统计、本人资料、历史/主题/设置/关于/登录退出；用户已验收，iPad横屏详情残留待定位 | 原版我的页入口层级 | R12 |

## R00 源码位置基线

- 当前 iOS：`ef9f1c27f6fc2d59a2b430b53950bcdde228dc26`
- 当前 API/Proto submodule：`5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`
- 最新 Android UI：`c5f1125f42498e49db4e4a9cb66313b8c8a285c7`
- 下表 Android 相对路径前缀：
  `app/src/main/java/com/huanchengfly/tieba/post/`

| 屏幕 | 当前 iOS 生产源码 | Android UI reference 源码 |
|---|---|---|
| App shell | `App/AppSceneRoot.swift`、`App/AppShellView.swift`、`App/AppTabPresentation.swift`、`App/Navigation/AppRoute.swift` | `app/src/main/java/com/huanchengfly/tieba/post/ui/page/main/MainPage.kt`、`NavigationComponents.kt` |
| Recommendations | `App/RecommendationsAppIntegration.swift`、`Sources/Features/Recommendations/Presentation/RecommendationsView.swift`、`RecommendationsStore.swift` | `ui/page/main/explore/ExplorePage.kt`、`explore/personalized/PersonalizedPage.kt`、`ui/widgets/compose/FeedCard.kt` |
| Followed forums | `App/FollowedForumsAppIntegration.swift`、`Sources/Features/FollowedForums/Presentation/FollowedForumsView.swift`、`FollowedForumsStore.swift` | `ui/page/main/home/HomePage.kt` |
| Forum home | `Sources/Features/Forum/Presentation/ForumHomeView.swift`、`ForumHomeStore.swift`、`ForumHomeListPresentation.swift` | `ui/page/forum/ForumPage.kt`、`forum/threadlist/ForumThreadListPage.kt` |
| Thread reader | `Sources/Features/ThreadReader/Presentation/ThreadReaderView.swift`、`ThreadReaderStore.swift`、`ThreadReaderListPresentation.swift`、`ThreadContentRenderer.swift` | `ui/page/thread/ThreadPage.kt`、`ui/common/PbContentRender.kt` |
| User profile / settings | `Sources/Features/UserProfile/Presentation/UserProfileView.swift`、`App/Stage16BSettingsIntegration.swift`、`Sources/Features/Settings/Presentation/SettingsOptionsView.swift` | `ui/page/main/user/UserPage.kt`、`ui/page/settings/SettingsPage.kt`、`ui/page/user/UserProfilePage.kt` |

整改前 iOS 根层级为“推荐 / 关注的吧 / 设置”；R02 已调整为四项入口。
既有作者资料仍通过 `RouteIdentity.userProfile` 进入；R00 时本人资料来源未接入，R12 已接通。ForumHome 与
ThreadReader 继续共用 `Sources/InteractionKit/VirtualList/VirtualizedList.swift`。
