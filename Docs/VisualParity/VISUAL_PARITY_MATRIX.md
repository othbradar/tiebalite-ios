# 视觉与功能一致性矩阵

| 屏幕 | 当前主要问题 | Android 目标 | 阶段 |
|---|---|---|---|
| 根 Shell | 仅推荐/关注/设置三项 | 首页/动态/消息/我的 | R02 |
| 推荐 | 重复大标题、圆角卡片、单张大图、无头像 | 平面动态流、头像/时间/吧标签/动作栏、多图 | R04 |
| 关注吧 | 蓝色星形占位、大圆角卡片、无最近浏览 | 搜索、最近浏览 chips、真实吧图、热度、Lv | R03 |
| 吧首页 | 吧头卡片、帖子卡片、无排序/横滑分类 | 紧凑吧头、最新排序、精华/分类 Pager、平面帖子流 | R05 |
| 帖子 | 标题/楼层卡片、无头像等级、单图纵列、楼中楼太多 | 平面楼层、头像/Lv、图片瀑布/网格、前三条预览 | R06 |
| 表情 | `#滑稽` 作为文字 | 官方表情内联图片 | R07 |
| 楼中楼 | “查看全部”不可用 | 独立分页楼中楼 | R08 |
| 写入 | 无发帖/回复 | 新帖、回复主题/楼层/楼中楼 | R09/R10 |
| 消息 | 无消息 tab | 回复我的/提到我的 + 未读 | R11 |
| 我的 | 设置成为根 tab、资料层级不一致 | 原版我的页入口层级 | R12 |

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

当前 iOS 根层级为“推荐 / 关注的吧 / 设置”；用户资料不是根 Tab，而是从
帖子作者或浏览历史进入的 `RouteIdentity.userProfile` 目的页。ForumHome 与
ThreadReader 继续共用 `Sources/InteractionKit/VirtualList/VirtualizedList.swift`。
