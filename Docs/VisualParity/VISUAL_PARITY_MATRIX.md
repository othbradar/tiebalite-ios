# 视觉与功能一致性矩阵

R01：`USER_VISUALLY_APPROVED`（2026-09-23）。共用头像、等级、分割线、元数据、1–8 图网格与平面 skeleton 已实现，字段链路及图片复用定向测试通过；截图和限制见 `R01_ACCEPTANCE.md`。iPhone/iPad 完整组件截图已保存；重新打开 iPhone Gallery 后，用户回复“行可以”，确认视觉通过。未提交；完整页面仍按下表后续阶段处理。

R02：`USER_VISUALLY_APPROVED`（2026-09-23）。用户批准最小承载修订后，当前基线原卡死重新复现；推荐列表复用既有 VirtualizedList 后原回归连续 3/3 通过。iPad 侧栏返回位置和既有帖子返回偏移检查仍未通过，全部结果见 `R02_LIST_REDESIGN_ACCEPTANCE.md`。用户查看 Simulator 后确认“现在没问题了”，授权提交并进入 R03。此前返回位置失败仍保留，不宣称自动化全绿。

R03：`USER_VISUALLY_APPROVED`（2026-09-23）。用户反馈“我看了可以了提交R03进入R04”，授权提交并开始 R04。实际验证与历史失败见 `R03_ACCEPTANCE.md`。

R04：`USER_VISUALLY_APPROVED`（2026-09-23）。用户确认作者头像已修复，授权提交 R04 并进入 R05；提交前定向门禁及历史失败见 `R04_ACCEPTANCE.md` / `R04_AUTHOR_AVATAR.md`。

R05：`USER_VISUALLY_APPROVED`（2026-09-23）。紧凑吧头、真实普通分类/精华、最新排序、独立分页和滚动 anchor、平面帖子流已实现。定向 Unit/Smoke、最终 lint/build 与边界检查通过；iPhone/iPad 已覆盖安装并停 Live 高通吧，未暂存/提交。阅读导航追加修订：吧/帖子隐藏根底栏，iPad 竖屏全宽、横屏原三列；本轮 Unit 23/25（2 个基线失败），iPad 连续旋转 XCTest 仍失败，CUA 三轮实际操作正常，不能宣称自动化全绿。两台已再次覆盖安装并停吧页。残留底部白条已另行修正并获用户确认“我看了修好了”：iPhone / iPad 各一条短回归通过 <=1pt 底边断言（含 iPad 横竖屏），未重跑长矩阵。最终外观等待用户验收，记录见 `R05_ACCEPTANCE.md` / `R05_NAVIGATION_REVISION.md`。

| 屏幕 | 当前主要问题 | Android 目标 | 阶段 |
|---|---|---|---|
| 根 Shell | 四项入口已完成；原卡死回归 3/3，返回位置仍有失败 | 首页/动态/消息/我的 | R02 |
| 推荐 | R04 平面信息流已实现，真实作者头像经获批 HTTP 兼容已显示；用户已验收 | 平面动态流、头像/时间/吧标签/动作栏、多图 | R04 |
| 关注吧 | R03 平面搜索、最近访问 chips、真实吧图/热度/Lv；两个已验证 CDN 使用 HTTPS，用户视觉验收通过 | Android 首页紧凑层级；当前账户头像来源仍 UNKNOWN | R03 |
| 吧首页 | R05 已实现；真实头像/多图、排序及分类已在 Live 显示，最终视觉与 Live 深滚动/横滑待人工验收 | 紧凑吧头、最新排序、精华/分类 Pager、平面帖子流 | R05 |
| 帖子 | 标题/楼层卡片、无头像等级、单图纵列、楼中楼太多 | 平面楼层、头像/Lv、图片瀑布/网格、前三条预览 | R06 |
| 表情 | `#滑稽` 作为文字 | 官方表情内联图片 | R07 |
| 楼中楼 | “查看全部”不可用 | 独立分页楼中楼 | R08 |
| 写入 | 无发帖/回复 | 新帖、回复主题/楼层/楼中楼 | R09/R10 |
| 消息 | 已有待实现 tab/计数注入，尚无真实消息 | 回复我的/提到我的 + 未读 | R11 |
| 我的 | 已有资料/历史/设置/关于入口，完整资料布局待整改 | 原版我的页入口层级 | R12 |

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
既有作者资料仍通过 `RouteIdentity.userProfile` 进入，本人资料来源尚未接入。ForumHome 与
ThreadReader 继续共用 `Sources/InteractionKit/VirtualList/VirtualizedList.swift`。
