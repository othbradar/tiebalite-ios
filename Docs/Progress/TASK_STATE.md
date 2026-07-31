# TASK_STATE

- 当前阶段：05
- 状态：PASSED_WITH_ENVIRONMENT_LIMITATION
- 当前分支：`main`
- 基线 commit：
  `03ae2bd1f5923d289a43fb526b096dba2f2aec70`
  （阶段 04 绿色提交，`test: complete stage 04 deterministic harness`）
- 允许修改范围：阶段 05 的 `DesignSystem` token/Motion/标准状态组件、
  App Shell、强类型 route/canonical navigation state、fixture-only
  占位页、Debug-only 组件画廊、对应 Unit/UI tests、XcodeGen/质量脚本、
  ADR/规格和本文件。
- 禁止修改范围：Android submodule/gitlink、真实业务 Feature/Store、
  贴吧 API/Protobuf、登录/Cookie/Keychain、生产缓存、Pager、
  MediaViewer、自定义 push/pop、业务 DragGesture、未批准依赖，以及阶段
  06 或后续内容。
- 已读取规则/规格/ADR：根目录及 `App`、`Sources/DesignSystem`、
  `Sources/Core`、`TestSupport`、`Tests`、`UITests`、`Specs`、`Docs`
  的适用 `AGENTS.md`；`Prompts/05_DESIGN_SYSTEM_AND_APP_SHELL.md`；
  `Specs/04_INTERACTION_CONTRACT.md`、`Specs/05_MOTION_CONTRACT.md`、
  `Specs/ROUTE_MAP.md`、`Specs/MODULE_MAP.md`；ADR-0003 及最新
  `TASK_STATE`。
- 已显式使用 `.agents/skills/xcode-quality-gate`，并采用仓库
  architecture/interaction/motion audit skill 的检查清单。三个只读
  子代理分别复审 canonical state/规格、交互/无障碍、工程/Release
  隔离；所有工作树写入均由主代理完成。未使用 `ios-feature-slice`，因为
  本阶段明确禁止创建真实 Feature Store。

## 阶段 04 提交与阶段 05 基线

- 用户授权提交阶段 04 后，精确暂存阶段 04 差异并执行
  `git diff --cached --check`，随后
  `git commit -m "test: complete stage 04 deterministic harness"` 成功，
  创建
  `03ae2bd1f5923d289a43fb526b096dba2f2aec70`。
- 阶段 04 提交前在受限沙箱运行 `make doctor` 时仅因
  CoreSimulatorService 不可访问失败；提权执行相同命令后 0 failure、
  0 warning。沙箱内 `make quality-fast` 的 unit destination 退出 70；
  提权执行相同门禁后 unit 28/28 通过，cached diff check 通过。
- 阶段 04 提交后、阶段 05 实现前运行完整 `make quality` 通过：
  - Debug build：
    `Artifacts/TestResults/20260731-143540-7419-build.log`；
  - Unit 28/28：
    `Artifacts/TestResults/20260731-143541-7444-unit.xcresult`；
  - iPhone UI 7/7：
    `Artifacts/TestResults/20260731-143601-7748-ui-smoke.xcresult`；
  - iPad build：
    `Artifacts/TestResults/20260731-143701-8121-ipad-build.log`；
  - Release build：
    `Artifacts/TestResults/20260731-143702-8146-release-build.log`。
- 阶段 05 开始后出现 `.idea/noctule.xml`、`.idea/vcs.xml` 两个 IDE
  元数据漂移。它们不属于本阶段，始终未修改、未暂存、未提交，也未为
  获得 clean tree 而 restore。
- 工具基线：macOS 26.6、Xcode 26.6（17F113）、Swift 6.3.3、
  Git 2.50.1、XcodeGen 2.45.4、SwiftLint 0.65.0、xcbeautify 3.2.1。
  Android reference 始终 clean 且锁定
  `5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`。

## 修改文件

- App Shell / navigation：
  - 新增 `App/AppSceneRoot.swift`、`App/AppShellView.swift`、
    `App/AppRouter.swift`、`App/AppAccessibilityID.swift`、
    `App/FixturePlaceholderViews.swift`、
    `App/DebugComponentGalleryView.swift`；
  - 新增 `App/Navigation/AppRoute.swift`、
    `App/Navigation/AppNavigationStore.swift`、
    `App/Navigation/DeepLinkParser.swift`；
  - 更新 `App/TiebaLiteApp.swift`、`App/ScaffoldEnvironment.swift`，
    删除旧 `App/ScaffoldRootView.swift`。
- DesignSystem：
  - 新增 `Sources/DesignSystem/SemanticTokens.swift`、
    `Motion.swift`、`StateComponents.swift`、
    `StateComponentPreviews.swift`。
- Tests / test support：
  - 新增 `Tests/AppNavigationStoreTests.swift`、
    `Tests/DeepLinkParserTests.swift`、`Tests/DesignSystemTests.swift`、
    `UITests/AppShellSmokeTests.swift`、
    `UITests/IPadAppShellSmokeTests.swift`；
  - 更新 launch scenario、既有 smoke/unit tests 与 typed UI harness。
- 工程与质量脚本：
  - 更新 `project.yml`、`Makefile`、`scripts/run_xcodebuild.sh`、
    `scripts/forbidden_patterns.sh`、Release/UITesting 隔离脚本、
    `scripts/project.env.example` 和 `scripts/README.md`。
- 契约与记录：
  - 更新 ADR-0003、`Specs/ROUTE_MAP.md`、
    `Specs/05_MOTION_CONTRACT.md` 和本文件。

## 关键设计与状态转换

- 每个 `WindowGroup`/scene 由 `AppSceneRoot` 的 `@State` 持有唯一
  `@MainActor AppNavigationStore`。
- Shell 有三个 `AppTab`：recommendations、followedForums、settings；
  P0 `RootID` 始终只有前两个。`routesByRoot` 为两个业务 root 各保存独立
  强类型 `[RouteIdentity]`。Settings 仅保存最多一个 Debug Shell
  `settingsPath=[componentGallery]`，不成为第三业务 root、Feature Store
  或恢复数据。
- iPhone 的三个系统 `NavigationStack` 由 `TabView` 保活；iPad
  `NavigationSplitView` 与 compact `TabView` 只投影同一个 store。
  regular/compact 切换不能写回、截断或重排 canonical path。
- 运行时证明 iOS 26.5 系统 Tab bar 重按当前 Tab 会在不经过 selection
  binding 的情况下 pop 当前 `NavigationStack`。ADR-0003 因此记录：
  保留 `TabView` 生命周期容器、隐藏不可配置的系统 Tab bar，并在 bottom
  `safeAreaInset` 使用三个无手势 selection button。当前 Tab 重选为
  no-op；push/pop/back/边缘返回仍由系统 `NavigationStack` 完成。
- route identity 只包含经验证的 forumName、正 Int64 threadID/postID；
  grammar 限制最大深度、合法顺序、相邻 thread/subposts ID 一致和 chain
  内不重复。重复 identity 执行 pop-to，不压入副本；非法 system path 或
  command 对完整状态零修改。
- Deep Link 仅允许四个精确入口：
  `com.baidu.tieba://unidispatch/frs?kw=...`、
  `com.baidu.tieba://unidispatch/pb?tid=...`、
  `https://tieba.baidu.com/f?kw=...`、
  `https://tieba.baidu.com/p/{tid}`。执行 scheme/host/path、单 query、
  URL 长度、单次 decode、本地 forumName 和正 ID 校验；不跟 redirect、
  不记录 URL/query。
- DesignSystem 提供 8 个语义颜色角色、6 个 Dynamic Type typography
  角色、spacing/corner/icon token、5 个 Motion token，以及唯一的
  Reduce Motion 解析入口。标准组件为 InitialLoading、InlineLoading、
  EmptyState、FullPageError、InlineError/Retry、PaginationFooter；
  每个均有 Preview、固定 gallery fixture 和无障碍标识。
- Debug 组件画廊只在 Debug/UITesting 编译；Release 同时通过 source
  exclusion、`#if DEBUG`、SwiftFileList、bundle/strings/symbols 检查排除。
  技术 canary 是 hidden 且 accessibilityHidden 的正控，不作为
  VoiceOver hint。
- UITesting-only layout harness 可在同一 `AppSceneRoot` 上确定性强制
  regular/compact。没有 override 时完全继承系统 size class，防止
  `nil` 环境值误把 iPad 投影为 compact。
- UI runner 从受控 `Config/Shared.xcconfig` 派生精确 App bundle ID，
  只在选定 Simulator 上卸载 TiebaLite App 和其 UI runner；先检查存在，
  卸载必须成功，随后确认不存在。其他 App、container 和 Simulator
  数据不受影响。

## 行为优先与失败证据

- 在生产类型存在前新增 navigation/deep-link/design-system tests；
  首次 `make test-unit` 退出 65，日志
  `Artifacts/TestResults/20260731-144249-8495-unit.log` 报预期的
  production symbol 缺失。
- 首版 Motion 测试 override 尝试写只读系统
  `accessibilityReduceMotion`，unit build 退出 65：
  `20260731-145244-8959-unit.log`。改为 TestSupport 自有环境 override。
- 下一轮 unit 因非法 Swift array pattern grammar 退出 65：
  `20260731-145321-9075-unit.log`；改为显式 grammar helper 后修复。
- 首轮 iPhone UI 10 个用例有 8 个失败：
  `20260731-145438-9708-ui-smoke.xcresult`。根因是系统 TabView 未暴露预期
  identifier，早期中文 label fallback 被复审认定会假绿，最终完全删除。
- 第二轮 UI 使用了 Simulator clone 中陈旧 runner，六个 launch smoke
  失败：`20260731-145808-10252-ui-smoke.xcresult`。仅卸载
  `dev.local.tiebaliteios` 与
  `dev.local.tiebaliteios.uitests.xctrunner` 后，当前源码正常执行；该精确
  重装流程随后固化并增加失败/后置检查。
- 当前源码执行时 iPhone UI 9/10：
  `20260731-150455-11440-ui-smoke.xcresult`。唯一失败证明系统当前 Tab
  重按自动 pop。一次 state suppression workaround 仍为 9/10：
  `20260731-151103-12272-ui-smoke.xcresult`，因此删除 workaround，采用
  ADR 记录的 bottom safe-area selector；随后 10/10 通过。
- 阶段末定向命令在沙箱内 `make test-unit` 退出 70：
  `20260731-153810-20591-unit.log`，原因仅为 CoreSimulator destination
  不可见；提权执行同命令后 43/43 通过：
  `20260731-153929-20909-unit.xcresult`。
- 首次新增 iPad layout harness 后 2/2 UI 失败：
  `20260731-154322-22231-ui-smoke-ipad.xcresult`。xcresult 安全层级证明
  marker 实为 compact；根因是 harness 在无 override 时仍写入
  `horizontalSizeClass=nil`。改为 nil 时继承系统环境后 2/2 通过：
  `20260731-154458-22870-ui-smoke-ipad.xcresult`。
- 读取上述 xcresult 的首次沙箱命令因无权写 Xcode TestReport 临时目录
  退出 64；只读提权执行相同 `xcresulttool` 命令后成功。
- 冻结候选的第一次完整 `make quality` 在 iPhone UI 处退出 2：
  unit 43/43 通过，但 UI 11/12；
  `20260731-155227-28937-ui-smoke.xcresult` 明确显示 gallery 的独立
  InlineLoading 与 `.loading` PaginationFooter 同时产生两个
  `design-system.inline-loading` 元素。未放宽查询或断言，只将 footer
  fixture 改为 `.end`；`make test-ui-smoke` 随后 12/12 通过：
  `20260731-155636-30070-ui-smoke.xcresult`。
- 最终从修正后的冻结源码重新执行完整 `make quality`，全部通过，详见
  下一节。

## 最终执行命令与逐项结果

- `make quality`：最终输出 `Quality gate completed.`，逐项为：
  - instruction size、8 个 repo skill 校验、Android reference lock、
    tool versions、两次 clean XcodeGen、static canaries、secret scan
    全通过；
  - `make forbidden`：0 error group；唯一 warning 是
    `Sources/DesignSystem/Motion.swift` 中批准的统一动画入口；
  - SwiftLint：47 个 Swift 文件，0 violation、0 serious；仅保留既有
    `implicitly_unwrapped_optional` 未启用的配置提示；
  - Debug generic build 通过：
    `Artifacts/TestResults/20260731-155952-31716-build.log`；
  - Unit 43/43 通过：
    `Artifacts/TestResults/20260731-155954-31745-unit.xcresult`；
  - iPhone UI 12/12 通过：
    `Artifacts/TestResults/20260731-160014-32106-ui-smoke.xcresult`；
  - UITesting App/Unit/UI target 与 Debug gallery source/binary 隔离
    检查通过；
  - iPad build 通过：
    `Artifacts/TestResults/20260731-160324-33118-ipad-build.log`；
  - iPad UI 2/2 通过：
    `Artifacts/TestResults/20260731-160325-33147-ui-smoke-ipad.xcresult`；
  - Release build 通过，且 Release SwiftFileList、bundle、strings、
    symbols 均排除 TestSupport/Debug gallery：
    `Artifacts/TestResults/20260731-160434-33411-release-build.log`。
- `xcrun xcresulttool get test-results summary` 对上述三个最终 result
  bundle 逐一确认：Unit 43 passed/0 failed；iPhone UI 12/0；
  iPad UI 2/0；均运行在 iOS 26.5 Simulator。
- `xcrun xcresulttool export attachments` 导出最终画廊两张脱敏截图并
  人工检查：dark + Accessibility 3 + Reduce Motion 环境摘要、loading、
  full-page/inline error、retry 和 pagination end 均可滚动到、文本可读、
  按钮未裁切；两个 retry 已由 UI test 实际点击。
- 最终 `make doctor`：0 failure、0 warning；iPhone/iPad Simulator
  可见，规则链、repo skills、工具版本和 Android reference 均通过。
- `bash -n scripts/*.sh`：通过。
- `git diff --check`：通过；对每个未跟踪文件逐一执行
  `git diff --no-index --check /dev/null <file>`，0 whitespace failure。
- `scripts/secret_scan.sh`：通过。
- `scripts/interaction_inventory.sh`：动画调用只出现在
  `Sources/DesignSystem/Motion.swift`；无 gesture；无 overlay/sheet；
  两个 safe-area inset 分别为 UITesting 顶部证据 banner 和 iPhone
  bottom selector。
- 最终六个 build/test log 扫描未发现 `error:`、`Test Failed`、
  malformed project 或 member-of-multiple-groups。
- `git -C References/TiebaLite-Android status --short` 无输出；
  HEAD 仍为阶段 04 commit
  `03ae2bd1f5923d289a43fb526b096dba2f2aec70`。

## 回归覆盖

- Canonical navigation：两个业务 root 独立 path、切 Tab 保持、当前 Tab
  重选 no-op、重复 identity pop-to、非法 grammar 零写入、系统 path
  pop、Settings Debug path 与业务 path 隔离。
- 容器：iPhone 系统 Stack、iPad SplitView、真实横竖屏旋转，以及同 scene
  强制 regular→compact→regular 后完整 route、selected tab、
  Settings path 均保持。
- 系统交互：导航栏 back 与真实左边缘 swipe 均返回前一 fixture route；
  未添加自定义返回/DragGesture。
- Deep Link：四个 allowlisted 入口；scheme/host/path/query、空/重复参数、
  尾斜杠、零/负/溢出 ID；非法 URL 对 selectedTab、两个 root path 与
  settingsPath 全部零修改。
- DesignSystem：token family 完整性；5 个 Motion token 的精确值与全部
  Reduce Motion `.none`；六类状态组件 Preview/gallery/a11y；深色、
  Accessibility 3、Reduce Motion 下滚动可达与 retry hit target。
- Shell UI：三个精确 stable Tab identifier、`.isSelected` trait、
  两 root 独立 route、当前 Tab 重选、Settings gallery 跨 Tab 保持。
- 隔离：Release 不含 Debug gallery/TestSupport；UITesting 包含固定
  scenario、layout harness 和 gallery 正控，Unit/UI target 成员方向正确。

## 新增或变更的动画、手势、overlay、依赖

- 动画：新增统一 `Motion` token/Reduce Motion 入口；当前业务占位页没有
  自定义动画。唯一 `.animation` 调用位于 `DesignSystem/Motion.swift`。
- 手势：无新增手势；系统 NavigationStack 左边缘返回由 UI test 验证。
- overlay/presentation：无 overlay、sheet 或 fullScreenCover。新增两个
  `safeAreaInset`：UITesting-only 顶部证据区域、iPhone bottom Tab
  selector；均不覆盖系统 push/pop。
- 生产第三方依赖：无；未修改依赖锁。

## UNKNOWN / 剩余风险

- 本机只有 iOS 26.5 Simulator runtime。最低部署 18.0 通过 build setting
  与编译，但没有在 iOS/iPadOS 18.x runtime 实跑，因此状态为
  `PASSED_WITH_ENVIRONMENT_LIMITATION`。
- regular/compact 的 canonical 投影由确定性 UITesting size-class
  override 验证；真实 iPad split-window 拖拽尺寸矩阵仍属于阶段 17，
  本阶段未声称完成。
- VoiceOver 的 `.isSelected` trait、label/value 和 technical canary
  隔离已由 accessibility tree/UI test 验证，但实机 VoiceOver 朗读顺序
  未人工听测。
- Navigation restoration DTO/持久化与 cold/warm deep-link 编排尚未
  实现；阶段 05 只实现 parser 与 canonical mutation。Settings 不进入
  snapshot；恢复阶段仍需 malformed Codable fixture。
- Tieba 官方 scheme 长期稳定性、Unicode normalization 与 redirect
  行为仍为已记录 UNKNOWN；未从记忆猜测。
- 系统 Tab bar 在 iOS 26.5 的重选 pop 行为导致当前使用自定义 bottom
  selection button。它不接管页面导航或手势；若后续系统提供可关闭该行为
  的公开 API，应复核并优先恢复系统 Tab bar。
- 真实贴吧 API、Proto、登录/session、业务 Store、Pager、MediaViewer
  均未实现/未验证，不能由阶段 05 fixture shell 推断可用。
- `.idea/noctule.xml`、`.idea/vcs.xml` 仍是范围外 IDE 漂移，保留在工作树
  且未纳入任何提交。

## 下一阶段前置条件

- 阶段 05 差异保持未提交；本次授权只提交了阶段 04。只有新的用户指令才
  能授权提交阶段 05。
- 只有新的用户指令才可开始阶段 06。开始前需精确暂存阶段 05 文件并排除
  `.idea` 漂移，重新检查 cached diff/质量证据，提交后再读取阶段 06
  提示词、适用规则和对应 interaction spike 规格。
- 本阶段在此停止；不得提前创建 Pager、MediaViewer、真实业务页面或进入
  阶段 06。
