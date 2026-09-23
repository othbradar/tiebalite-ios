# R05 阅读导航修订

状态：READY_FOR_USER_VISUAL_REVIEW（存在已记录的验证失败）。用户尚未批准 R05，未暂存、未提交、不进入 R06。

## 用户反馈（原文）

> 我发现了一个跟原版不一样的问题，原版tieba和tiebalite进入吧首页或帖子里的时候底边栏（选择动态、消息、我的的栏）是隐藏或者说不显示的，现在进入吧首页和帖子里面这个没隐藏还能看到比较浪费屏幕空间。还有ipad版竖屏的时候应该跟手机版显示差不多而不是左边有两层上级页面，恒屏则保存不变

两项分别是：阅读页仍显示根底栏；iPad 竖屏仍显示上级三列。用户本轮明确授权修改对应 Shell 投影规则，既有 R05 对根导航的保护范围在此精确扩展，其他基础设施不变。

## 证据、根因和计划

- CODE_EVIDENCE：Android UI 锁 c5f1125 的 MainPage.kt:276–287 将 BottomNavigation 放在主页面 Scaffold 内；MainActivityV2.kt:497–501 的根 DestinationsNavHost 将 Forum/Thread 作为独立 destination。目标截图 05-forum-home.png 和 06-thread-reader.png 均无四项根导航。
- 当前 iOS PhoneTabSelector 无条件放在整个 TabView 的 safeAreaInset 中，push Forum/Thread 不改变其存在性，持续占用 57pt 加系统底部安全区。
- 当前 AppShellView 仅以 horizontalSizeClass==regular 选择三列。竖屏 iPad 仍为 regular，所以展示 sidebar/content/detail，而非用户期望的单页完整栈。
- 差异属于布局/导航投影，不是数据、图片缓存、Cell 身份或网络竞态。
- 计划：以当前已选路径中的阅读 route 派生底栏可见性（包含历史入口及阅读页后续子页）；按实际容器长宽与 size class 选择现有 compact/regular 投影。保持同一 scene 的 navigation/Feature Store，无第二套路径、不清栈、不改业务 ID。
- 预计修改：AppShellView、Shell 展示策略、定向 Unit/UI、直接受新交互契约影响的 Shell Smoke、ADR/导航契约与 R05 记录。主要风险是旋转导致系统 path 回写，以及返回时底栏/阅读空间不恢复；用真实 UI frame、选中页和返回链验证。
- 基线：保留全部上一轮未提交 R05 文件及用户原有 prompts/agents 文件。Xcode 26.6 (17F113)、Swift 6.3.3、iOS 26.5。新增 Fixture 回归先在原实现连续三轮进入/返回与三轮旋转，保留原始失败。

## 验证记录

- make generate：exit 0。
- 初次定位尝试读取错误的 AppNavigationState.swift / NavigationProjection.swift 路径及旧 Android activities/MainActivityV2.kt 路径失败；已通过 rg / git ls-tree 找到 App/Navigation/AppRoute.swift 和根包 MainActivityV2.kt。无文件覆盖。
- 截图目录：Artifacts/VisualReview/R05/NavigationRevision/；iphone-before.png、ipad-before.png 为修改前正常 App 原图。
- phone-red.xcresult：原实现三次“吧→帖子→吧→首页”，九次阅读检查均显示根底栏，预期断言失败，exit 65。
- ipad-red.xcresult：三轮旋转后尝试点击尚未可命中的最新页行，先遇 XCTest 定位失败；已将三轮观测断言前置，并在后续进入帖子前等待实际 hittable 条件，未放宽超时。
- ipad-red-verified.xcresult：原实现三次竖屏均显示根入口，吧头宽度/窗口宽度均为 0.41860465；确定性失败，exit 65。
- unit.xcresult：25 项 / 5 suites，23 项通过；Stage17 的两个现有直接 UITableView 锚点测试报 39 vs 40。新增 Shell 3 项、既有导航/四根/Store 共 19 项均通过。已在原 Shell 同环境复核同样两项失败，不修改共享列表。
- anchor-baseline.xcresult 的单个 Swift Testing 方法 selector 未匹配，实际 0 tests，不计通过。改为整个 Stage17AdaptiveLayoutTests suite 后，anchor-baseline-verified.xcresult 实际 6 项，原 Shell 同样有上述两项 39/40 失败，exit 65；其余 4 项通过。候选 AppShellView 已逐字恢复，原始表格测试/断言及共享列表均未修改。
- 原 Shell 的“详情页点击根栏切 Tab”用例与新用户要求冲突；对应 Smoke 改为在阅读页断言根栏不存在、系统返回根页后切换，并保留四根实际内容/重选位置断言。横向 iPad 继续验证带详情的四根切换，compact 转换后先验证隐藏，再回横向切根；canonical 独立路径与 Store identity 的 Unit 仍原样保留。
- phone-green.xcresult：独立根入口、历史帖子、系统侧滑、四根内容 4/4 通过；三轮阅读的九次自定义根按钮检查均隐藏，但底部 gap 全为 83pt，空间断言失败。截图显示系统 TabView 的空白胶囊（49pt + 34pt 安全区），证实原 toolbar(.hidden) 放在 TabView 自身无法约束其子栈 preference。已将系统 tabBar 隐藏声明放到四个栈；原 <=40pt 空间断言不变。
- 首轮 make lint、网络隔离、凭据扫描 exit 0。附加 forbidden-pattern 检查发现上一版 R05 ForumHomeDestination 使用 AnyView（exit 1）；改为具名 ForumSearchDestination 打断递归类型边界，路由/搜索 sheet 行为不变，保留禁用规则并复跑原 R05 搜索回归。没有增加 allowlist。

- phone-space-verified.xcresult：原 R02 深滚动/四根实际切换（95.102s）、原 R05 分类/分页/帖子返回/搜索（76.254s）、新增三轮阅读（69.082s），3/3 通过。九次阅读无根按钮，吧列表底边仅余 <=40pt 系统安全区；根页恢复四入口。
- ipad-green.xcresult：canonical regular/compact/regular、既有旋转/切根、四根 sidebar 三项通过；新增三轮旋转测试超时（exit 65）。XCTest 两次等待动画结束通知各 60s，另有脚本未指定的 landscapeRight/portraitUpsideDown 方向事件，不能据此推断来源。
- 同代码、同断言独立复跑旋转用例；等待期间 PID 96825 CPU 0.0%，3s sample 的 2605 次主线程样本均停在 CFRunLoop/mach_msg2_trap（ipad-rotation-main-thread.txt），没有主线程布局循环证据。首次运行应用日志同时有 XCTest animationDidStop 无对应 start 的监测警告和 UITableView visibleCells 更新期访问警告；共享列表未修改，不以延长超时、关动画或缓存重置掩盖。
- lint-final.log、forbidden-final.log、network.log、secrets.log 均 exit 0；protected-final.json 的 35 个共享基础设施文件与基线相同。最终普通 Debug build、正常 App 覆盖安装及交互截图仍待完成。

- ipad-rotation-repeat.xcresult：不改代码/超时的独立复跑仍失败，141.558s，在两次动画通知等待后方向 frame 条件不满足。保留为未解决的 XCTest 连续旋转验证项，没有将其记为通过。
- ipad-forum-width.xcresult：原 R05 精华/普通分类左右滑、滚动、横转竖、返回最新，1/1、23.807s 通过，exit 0。
- CUA 隔离 forum.parity 实际操作：先校正 Simulator 窗口与内容朝向（测试结束时窗口横向但内容横躺），随后三轮“竖→横→竖”，每轮观察到横向三列、竖向全宽，无根底栏，精华标签保留；第三轮截图 ipad-cua-third-landscape.png。从精华进入 Observation 帖子，竖向仍全宽且无根栏，返回仍精华；再次返回首页恢复四入口。
- 同一隔离场景打开搜索，显示软件键盘并输入 Swift，Layout: Compact 及全宽保持，未跳成三列；截图 ipad-cua-keyboard.png。CUA typeText 会收起软件键盘，已重新显示并核对，而非仅以输入成功判断键盘场景通过。
- CUA 观察与 XCTest 超时不是同一验证手段，不覆盖失败结果。尚不能证明连续旋转的 XCTest 同步问题已经解决；没有第三组生产视觉补丁。


## 最终交付

- 目标与范围：仅修订 Shell 的阅读底栏可见性及 iPad 竖屏投影，完成用户本轮反馈；没有提前整改 R06 帖子行外观。
- 修改文件：AppShellView.swift、新 AppShellPresentation.swift；新 R05ReadingShellTests / R05ReadingShellSmokeTests；直接冲突的 AppShell/IPad/R02/历史 smoke；ADR-0026、交互/导航契约与 R05 记录。ForumHomeDestination.swift 仅以具名 View 替代本阶段先前的 AnyView，搜索行为回归通过。
- 关键状态：由已选根的稳定路径派生阅读底栏，不新增可变导航真相；竖屏/方形/compact 使用完整栈，横向 regular 保持原三列。系统 tabBar 隐藏偏好落在各子栈，避免空胶囊和 49pt 残留占位。
- 新增或变更动画、手势、overlay、依赖：本导航修订均无。列表、Pager、MediaViewer、图片缓存、Session 与 canonical navigation 实现的 35 文件 hash 最终复核相同。
- make build → build-final.log：exit 0，正常 Debug Simulator universal .app。make lint → lint-final.log：exit 0；forbidden-final/network/secrets 均 exit 0；git diff --check → diff-final.log：exit 0。
- 定向 Unit 25 项中 23 项通过；新增 Shell 3 项通过，两个 Stage17 锚点 39/40 失败已在原 Shell 复现。iPhone 7 项独立相关 UI 场景通过（其中新增阅读场景内 3 轮）；iPad 4 项既有相关场景通过。新增 iPad 三轮 XCTest 旋转用例两次失败，保留原 timeout/frame 断言；没有全量 Unit、quality 或无关长矩阵。
- CUA 隔离 Fixture 三轮实际旋转、精华保持、帖子/吧/首页返回、软件键盘单页布局均观察正常；它们不能替代失败的 XCTest 结果。连续旋转自动化通知/方向同步原因尚未完全确定，不宣称全绿。
- 两台 xcrun simctl install + launch exit 0，无 uninstall/erase/Keychain 修改。正常 App 实际观察 iPhone 吧页及帖子均无根栏；iPad Live 吧页竖屏全宽、横屏原三列。iPhone 返回并留在高通吧最新页，iPad 留在竖屏高通吧，iPhone 窗口前台。

正常 Debug 截图（相对于仓库）：

- Artifacts/VisualReview/R05/NavigationRevision/iphone-live-forum.png
- Artifacts/VisualReview/R05/NavigationRevision/iphone-live-thread.png
- Artifacts/VisualReview/R05/NavigationRevision/ipad-live-portrait-forum.png
- Artifacts/VisualReview/R05/NavigationRevision/ipad-live-landscape-forum.png

下一阶段前置条件：用户检查 Simulator 并明确批准 R05；本次不提交、不进入 R06。READY 仅表示实现和截图供人工查看，不表示上述自动化失败已解决。


## 底部白条二次反馈（2026-09-23）

用户原文：

> 这底部还有块白色的栏没去掉，进帖子里也一样，ipad版也有（无论横屏竖屏）。你把这个修好，不要搞大型的回归测试浪费token

- 上轮 <=40pt 断言接受了 34pt 固定空区，属于验收缺口；不能用“系统安全区”解释为已满足用户要求。Android 05 参考内容可延伸到手势条，ForumPage 的导航区 padding 施加在悬浮入口而非整张列表。
- 仅运行一个短 Fixture 场景：吧→帖→吧→根；iPad 同一场景增加一次横转竖。原实现 red.xcresult 23.321s、exit 65，实测 gap=[34,34,34]。原三轮阅读测试的 bottom gap 断言也改为 <=1pt，但本轮不重跑该长场景。
- 生产修改只在 AppRouter 的 Forum/Thread destination 上延伸 bottom container safe area；键盘/顶部和根入口安全区不变，其他 R05 未提交差异保持。具体例外记录于 ADR-0026。
- 本轮证据目录：Artifacts/VisualReview/R05/BottomInset/。开始时正常 App 已在上一轮构建成功并覆盖安装，本轮短 red 的 test build 再次编译通过后触发上述布局断言。

- phone.xcresult 第一候选 exit 65，gap 仍为 [34,34,34]：把修饰符放在外层 GeometryReader 不能越过系统 NavigationStack 对目的页施加的安全区。该候选已撤回；改为在系统导航内部的 Forum/Thread destination 上声明滚动视口的边缘行为，没有叠加两层修饰。

- phone-destination.xcresult：目的页修正后帖子 gap=0，吧页往返仍为 34pt，exit 65。源码确认 Forum PagerHostingController 为每页创建独立 UIHostingController，外部安全区声明不传播为内层 host 的边缘行为；在 ForumHomeView 的 Pager content 闭包同样声明 bottom container 边缘，未改共享 host。
- phone-page.xcresult：相同短用例 1/1、22.093s、exit 0；吧→帖→吧的视口底边均满足 <=1pt，返回根页四入口恢复。未放宽断言或超时。

- ipad-page.xcresult：同一短用例 1/1、28.912s、exit 0；横向吧/帖、竖向帖/返回吧均 <=1pt，返回根页恢复入口。没有再次运行三轮旋转或其他长矩阵。
- 本轮生产差异只有 AppRouter 的两处阅读目的页边缘声明，以及 ForumHomeView 的 Pager 页面内容边缘声明。没有新增动画、手势、overlay、依赖；35 个共享承载/图片/Session 等保护文件 SHA-256 全部相同（BottomInset/protected-final.json）。
- make lint、make build、git diff --check 均 exit 0；对应 BottomInset/lint-final.log、build-final.log、diff-final.log。本轮不重复 Unit、make quality 或完整 UI 矩阵。此前 Stage17 的两个基线失败和连续旋转 XCTest 问题仍按原记录保留，本次短回归通过不代表这些旧项已解决。
- 两台 Simulator 正常 Debug .app 已通过 simctl install 覆盖安装并无参数 launch，全部 exit 0；没有卸载、清 Keychain 或缓存。

- 正常 Debug CUA 实际观察：iPad 竖屏全宽、横屏三列均无底部固定白条；iPhone 吧页滚动内容可延伸至屏幕底边。截图 BottomInset/iphone-live-forum.png、ipad-live-portrait-forum.png、ipad-live-landscape-forum.png。两台停 Live 高通吧，iPhone 窗口前台。
- 用户随后明确回复“我看了修好了”：本次底部白条修复 = USER_VISUALLY_APPROVED。停止追加交互和测试；未暂存/提交，不自动进入 R06。该确认只记录本次反馈，不覆盖历史自动化限制。
