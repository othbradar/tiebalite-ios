# R02 根 Shell 验收记录

2026-09-23 用户查看 Simulator 后明确反馈“我看了r02现在没问题了，提交并进入r03”，R02 记为 `USER_VISUALLY_APPROVED`。此前自动化返回位置失败保留为已知记录，不改写为通过；用户已授权提交当前实现并进入 R03。

状态：`IMPLEMENTED_WITH_OPEN_VALIDATION_FAILURES`（2026-09-23）。已按用户批准实施最小推荐列表承载修订；本轮原卡死基线重新复现，修订后原回归连续 3/3 通过。iPad 侧栏返回位置和既有帖子返回偏移仍有失败，不能宣称 R02 已通过；完整结果及最终动态页截图见 `R02_LIST_REDESIGN_ACCEPTANCE.md`。以下保留此前执行记录。R01 已获用户视觉批准；未暂存、未提交，未进入 R03/R04。

## 行为契约（实现前）

- 根选择顺序为首页、动态、消息、我的；默认首页。保留原 recommendations/followed-forums/settings identity，分别投影为动态/首页/我的；新增 notifications。两个已有业务 root 的 Store、route 和列表承载不变。
- iPhone 继续使用既有 TabView + 独立 NavigationStack + safeAreaInset selector；不新增横滑、重选刷新或 pop。iPad 使用同一状态的 NavigationSplitView sidebar 投影。
- 首页只沿用关注吧内容并调整标题，不进入 R03；动态仅去掉重复 TiebaLite 大字、统一标题，不进入 R04。
- 消息明确显示“待实现”，无远端消息请求；可注入未读计数源，Production 为 0、Fixture 为 3。切换和重选不伪造已读，不清空计数。
- 我的提供个人资料、浏览历史、设置、关于入口。设置保留既有功能与 Debug 入口。当前 Session 不含本人 userID，个人资料入口明确显示暂不可用，不用 Fixture 用户作为 Live 本人；已有作者资料路线保持。
- 根底栏使用锁定 Android 矢量图的静态选中/未选中态、24 pt 图标、56 pt 栏高、平面背景和细分割线；与参考一致不显示底栏文字，VoiceOver 保留四项中文名称与选择状态。
- 消息根暂没有子页面，不共享“我的”的 settingsPath；切消息不能错误显示我的详情。现有 MediaViewer 只保留 AppSceneRoot 唯一 fullScreenCover。
- 验证四个 Tab、路径隔离、列表滚动与 Store 保持、重选 no-op、iPad sidebar/投影、一次媒体打开/关闭；仅定向 Unit/Smoke 和 make quality-fast，不跑完整 interaction/quality。
- 直接覆盖安装，禁止卸载/erase/清 Keychain。iPhone 四页截图及 iPad 对应截图保存到 Artifacts/VisualReview/R02，最后停首页；等待用户视觉验收，不提交、不进入 R03。

## 已确认基线

- make doctor exit 2：既有视觉技能缺少 agents/openai.yaml；见 baseline-doctor.log。只补其描述元数据，不放宽校验。
- make build exit 0；导航/DeepLink/Projection 定向 Unit exit 0，见 baseline-build.log、baseline-unit.xcresult。
- Android UI 锁 c5f1125f42498e49db4e4a9cb66313b8c8a285c7；API submodule 5545326b2a8e0d784b2f3dfbcb219c7b121e61c2 不变。已查看 Android-target 全六张截图。
- 源码：ui/page/main/MainPage.kt 的 navigationItems/userScrollEnabled=false；NavigationComponents.kt 的 BottomNavigation/NavigationRail（无阴影、24dp、无 label）；home/HomePage.kt Toolbar；notifications/NotificationsPage.kt 标题；user/UserPage.kt 资料及历史/设置/关于入口。路径前缀 app/src/main/java/com/huanchengfly/tieba/post/。

## 限制

本人 userID/头像资料来源、Production 消息计数尚未接入；本轮不新增 API。R01 portrait HTTPS 合成 UNKNOWN 保留。完整首页/动态/消息/我的内容分别留在 R03/R04/R11/R12。

## 实现中发现并修正的问题

- iPhone 首轮 Shell Smoke 的 3 条独立路径均复现 `Missing scroll container: recommendations.list`；同一快照可见推荐行及 `app.root.recommendations`，排除数据未加载或根 Tab 未切换。原因是移除重复标题后，根容器只有一个含子节点的 ScrollView，SwiftUI 合并无障碍容器，根 accessibilityIdentifier 覆盖内层列表标识。第一次恢复单子项 VStack 仍复现相同 3 条失败，证实仅补布局容器不足。最终将根页面标识绑定到实际可见的唯一系统导航标题（principal），列表保留原标识；不修改列表、滚动、Store 或测试断言。分类为 SwiftUI 无障碍容器身份；原 3 条失败测试作为回归。
- 首轮静态检查发现 LaunchScenarioFactory/UITestHarness 长度及 SettingsRouteGrammar 复杂度超限，拆出计数源工厂、测试标识枚举与路径校验函数；未调整阈值。新增测试的 import 顺序也已纠正。
- `quality-fast` 首轮在 networking-isolation 停止：R01 的 `TiebaUserVisualMapper.swift` 未列入精确 Core allowlist，Gallery 注释中的网络类型名被文本扫描误判。参照既有 PBPageDomainMapper 登记该单文件，同时要求仅导入 GeneratedProtobuf、禁止副作用及向领域模型泄漏 Proto；注释改为同义描述。未关闭检查或放宽 UI 分层规则，R01 运行逻辑和视觉未变。

## 验证执行记录

原始命令与完整输出保存于 `Artifacts/VisualReview/R02/`（忽略目录，不纳入提交）。UI 使用原生 xcodebuild 的 `-only-testing`，没有调用会卸载 App 的仓库 UI wrapper；Unit wrapper 没有卸载动作。

| 命令/日志 | 结果 |
|---|---|
| make doctor → baseline-doctor.log | exit 2；既有 skill metadata 缺失 |
| make doctor → final-doctor.log | exit 0；补齐 metadata 后恢复 |
| make build → baseline-build.log | exit 0 |
| baseline-unit.xcresult（导航/DeepLink/Projection） | 17/17 通过 |
| make lint → implementation-lint.log | exit 2；工厂/测试工具长度、路径校验复杂度 |
| make lint → implementation-lint-2.log | exit 2；工厂长度、路径校验复杂度 |
| make lint → implementation-lint-3.log | exit 2；路径校验复杂度 |
| make lint → final-lint.log | exit 2；路径校验复杂度、新测试 import 顺序 |
| make lint → final-lint-2.log | exit 0，0 violations |
| make build → implementation-build.log | exit 0 |
| targeted-unit.xcresult | 28/28 通过；R02、导航、深链、投影、设置回归 |
| shell-iphone.xcresult | exit 65；3 通过/3 失败，见上述列表标识根因 |
| shell-iphone-fixed.xcresult | exit 65；恢复单子项布局后仍 3 通过/3 失败 |
| shell-ipad.xcresult | exit 0；3/3 通过，四项侧栏、旋转、宽窄投影与路径保持 |
| shell-iphone-final.xcresult | exit 0；6/6 通过，保留全部原失败断言 |
| shell-ipad-final.xcresult | exit 0；1/1 通过，导航标题标识修正后的四入口投影复核 |
| make quality-fast → quality-fast.log | exit 2；上述两项 R01 networking-isolation 登记/注释问题 |
| bash scripts/verify_networking_isolation.sh → networking-isolation-fixed.log | exit 0；0 failure |
| make quality-fast → quality-fast-final.log | exit 0；所有静态/生成/分层/lint/build/entitlement 门禁及 Unit 通过 |
| quality-fast Unit：Artifacts/TestResults/20260923-095524-57502-unit.xcresult | 401 个逻辑测试、433 次执行；0 失败/跳过，包含最新 6 项 R02 Unit |
| make build → final-build.log | exit 0；最终 Debug Simulator App |
| simctl install → install-launch.log | exit 149；Unit 后目标 Simulator 处于 Shutdown，未发生安装/卸载 |
| simctl boot/bootstatus/install/launch → install-launch-booted.log | 两台所有命令 exit 0；直接覆盖安装，无 uninstall/erase/Keychain 清理 |

未运行 make quality、完整 UI/interaction 或 Release 矩阵。Android reference、SwiftPM lock 和受保护列表/交互组件未变。

## 最终改动范围

- App 根层：AppRoute、AppTabPresentation、AppShellView、AppShellContent、AppShellTabSelector、AppPersonalRootView、NotificationBadgeState；组合根注入计数，保留场景级 Store 和原两个业务根。
- 入口与标题：RecommendationsAppIntegration、RecommendationsView、FollowedForumsView、Stage16BSettingsIntegration、TiebaParityToolbar；移除重复品牌标题，保留既有业务内容。
- 资源：8 个 Android 导航图标状态及 ROOT_NAVIGATION_PROVENANCE、THIRD_PARTY_NOTICES。
- 契约/验证：ADR-0022、ROUTE_MAP、R02 Unit/Smoke、现有 UI 导航入口适配；测试 ID 仅移动到独立文件，既有业务 identity 不变。
- 门禁修复：补全视觉技能的 agents/openai.yaml；为 R01 mapper 添加精确 Proto 边界登记和副作用/领域泄漏检查，澄清 Gallery 注释，不改变 R01 行为。
- 无新增动画、手势或依赖。未读角标仅在 count>0 时位于所属 Tab 图标之上，随按钮生命周期显示；不接管触摸，VoiceOver 由按钮读出完整计数。现有唯一 MediaViewer cover 不变。

## Simulator 与截图

最终产物：`.build/DerivedData/Build/Products/Debug-iphonesimulator/TiebaLite.app`。
直接覆盖安装 iPhone 17 Pro 与 iPad Pro 13-inch (M5)，iOS 26.5；没有卸载、erase、清 Keychain 或退出登录。
iPhone 原有登录态正常恢复，首页/动态读取 Live 列表；iPad 当前未登录，保留真实登录提示，没有注入 Fixture 登录。
手工依次切换四个入口并确认对应选中图标、标题、占位和入口，最后两台均停在首页，iPhone 窗口位于前台。

| 入口 | iPhone | iPad |
|---|---|---|
| 首页 | [iphone-home.png](../../Artifacts/VisualReview/R02/iphone-home.png) | [ipad-home.png](../../Artifacts/VisualReview/R02/ipad-home.png) |
| 动态 | [iphone-dynamic.png](../../Artifacts/VisualReview/R02/iphone-dynamic.png) | [ipad-dynamic.png](../../Artifacts/VisualReview/R02/ipad-dynamic.png) |
| 消息 | [iphone-messages.png](../../Artifacts/VisualReview/R02/iphone-messages.png) | [ipad-messages.png](../../Artifacts/VisualReview/R02/ipad-messages.png) |
| 我的 | [iphone-personal.png](../../Artifacts/VisualReview/R02/iphone-personal.png) | [ipad-personal.png](../../Artifacts/VisualReview/R02/ipad-personal.png) |

iPhone/iPad 都保留现有列表、系统返回与安全区；首页/动态卡片样式及旧列表占位仍属于 R03/R04 待整改内容，本轮不将其标为视觉通过。

## 原人工门禁（已撤回）

此前 `READY_FOR_USER_VISUAL_REVIEW` 曾因用户反馈卡死撤回。最新承载修订的原深滚动回归已连续三次通过，但返回位置验证仍有失败。当前 App 已覆盖安装并留动态页，供用户检查候选；READY 不代表 R02 全部门禁通过，不自动修外观、不提交、不进入 R03/R04。
