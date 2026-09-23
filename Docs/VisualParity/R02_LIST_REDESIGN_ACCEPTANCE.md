# R02 动态列表承载修订记录

2026-09-23 用户查看 Simulator 后明确反馈“我看了r02现在没问题了，提交并进入r03”，R02 记为 `USER_VISUALLY_APPROVED`。此前自动化返回位置失败保留为已知记录，不改写为通过；用户已授权提交当前实现并进入 R03。

状态：`IMPLEMENTED_WITH_OPEN_VALIDATION_FAILURES`。用户批准的 R02 最小承载替换已实施；原卡死回归连续 3 次通过，但返回位置检查未全部通过，不能声明 R02 修复完成。已覆盖安装并留在动态页供人工检查；未暂存、未提交、不进入 R03/R04。

## 目标与范围

解决用户原始反馈：“iPhone17模拟器tieba lite app我点了几下根导航按钮现在app卡死了”；补充为“滑动后切换底栏”。本轮不是继续尝试视觉参数，仅让 RecommendationsView 接入已有 VirtualizedList，保留当前 R02 Row 外观、RecommendationSummary、Store、Repository、路由与权限。

## 当前工作树重新复现

- 2026-09-23 11:49，先记录当前 Git 状态、93 个受保护文件 SHA-256 和原测试/Fixture/View 源码，再执行 make generate 与 xcodebuild 定向 UI 测试。没有修改原 Fixture、清缓存或清 Keychain。
- `current-baseline.log/.xcresult`：原 testDeepDynamicScrollAndRepeatedRootSwitchesStayResponsive 在第二次上滑（约 11.60 秒）后等不到 App idle，最终超过原 120 秒限额，命令 exit 65。
- 本次新进程 PID 11792 的 CPU 约 99%；`current-baseline.sample.txt` 的主线程 2241 个采样全部处于 UI 更新调用链，其中 2234 进入 GraphHost.flushTransactions，持续在 LazySubviewPlacements / LazyStack / AttributeGraph。截图 `current-baseline-freeze.png` 同时保存。
- 这是当前构建的实际冻结证据，不是复用旧日志，也不是单纯 XCTest 找不到元素/命中失败。此前两次局部补丁已撤回；本轮按用户明确批准执行组件承载替换。
- 证据目录：`Artifacts/VisualReview/R02/ListRedesign/`（忽略目录，不纳入提交）。

## 修改文件与状态转换

- `RecommendationsView.swift`：仅 loaded/refreshing/loadingNextPage/对应保留内容失败状态的列表分支使用同一 VirtualizedList；去掉 ScrollView/LazyVStack/scrollPosition 和 Cell 分页 task。首次加载/空态/失败态沿用原实现。
- `RecommendationsListPresentation.swift`：行 ID 为 `.thread(现有 threadID)` 和唯一 `.pagination`；原 RecommendationSummary 直接进入行，不重新映射导航或更改去重。first-row padding 标志只复现原列表外边距；footer 值变化不更换 ID。
- 预取将末 4 条中的有效业务 threadID 传给原 `store.requestNextPage(after:)`，不把 index 或 footer 当 threadID；Store 原 page/generation 防重保持。
- onScrollSettled 只接收当前 items 中有效正数 threadID；nil/footer/未知行不调用 Store，不覆盖上次有效 anchor。restoredAnchor 只供共享 coordinator 初建时消费，普通同步不回填它的 pendingRestoredAnchor。
- 普通追加仍在同一个 View 分支、同一个 Representable 类型和稳定行 ID 下；没有 `.id(UUID())`、根节点替换、reloadData 或强制定位。图片完成只更新原缩略图局部状态，不进入行投影或整表更新入口。
- 原 RecommendationRow 到文件末尾的图片任务、取消/清理代码与本轮基线逐字一致；沿用共享 prepareForReuse 生命周期，未增加 didEndDisplaying 清理。

## 动画、手势、overlay、依赖

均未新增或修改。VirtualizedList 共享实现、ForumHome、ThreadReader、Pager、MediaViewer、App 根导航、图片缓存、Session 与 Fixture 均以开始时 SHA-256 核验，不加入修改范围。

## 测试契约

- 原失败操作与 120 秒限额、两轮深滚动、第三页业务行、返回位置 ±12pt、回到首行的断言保留；额外断言每个目标根页面存在且 hittable，避免只确认 tap。
- 连续执行 3 次原场景；iPad 同 Fixture 验证第三页、四项侧栏实际切换、返回位置、旋转带来的列表宽度变化及回到顶部。
- 少量 Unit 覆盖稳定完整数据、追加/footer 行不变、无效 anchor、业务 ID 预取和 in-flight 防重；既有图片复用/Loader、推荐分页与一次性 anchor 恢复回归按精确用例运行。
- 只执行本轮相关测试、make lint、make build、git diff --check。按用户要求不跑全部 Unit、quality-fast、完整 quality 或无关长矩阵。

## 已执行结果

| 命令/产物 | 结果 |
|---|---|
| make generate → baseline-generate.log | exit 0 |
| 原失败 UI → current-baseline.xcresult | exit 65，主线程布局循环已由本次采样确认 |
| make generate → implementation-generate.log | exit 0 |
| make lint → implementation-lint.log | exit 0 |
| targeted-unit.xcresult | exit 0，19 个逻辑测试 / 20 次执行；5 个新投影测试、生产图片 Loader 与两类已有图片复用测试通过 |
| deep-scroll-three-runs.xcresult | exit 0；原测试连续 3/3 通过，84.067 / 85.050 / 84.790 秒；每次包含两轮第三页→四个根入口实际显示→返回位置 ±12pt→首行 |
| ipad-scroll-width.xcresult | exit 65；默认 container.swipeUp 未命中实际中间列表列，第三页目标不可见。与 iPhone 最后一次运行重叠，未把此结果解释为卡死 |
| ipad-scroll-width-isolated.xcresult | exit 65；单独运行仍在相同滑动定位处失败，排除了仅由并行运行造成的解释 |
| ipad-scroll-width-anchor.xcresult | exit 65；使用已有 gestureAnchor 参数后，正常滚至第三页并完成四个侧栏目标页检查；返回动态时 t100012 不再 hittable，原断言保留。失败后未执行旋转断言 |
| recommendation-return.xcresult | exit 65；既有帖子打开/返回测试：返回 midY 807.67，进入前 711.00，偏移 96.67pt，超过原 ±12pt |
| recommendation-return-baseline.xcresult | exit 65；临时使用本轮原 RecommendationsView 重跑同一既有测试：598.50 对 570.17，偏移 28.33pt。随后逐字恢复候选适配文件。说明该测试在当前 R02 基线也失败，不能据此把候选的更大偏移算作通过 |
| pagination-anchor-unit.xcresult | exit 0，补跑 6/6：推荐三页/去重、失败重试代次、空页停预取、同实例值更新不重新定位、宽度更新不重建 snapshot、初建 anchor 恢复 |
| final-lint.log | make lint exit 0，261 文件、0 violation |
| final-build.log | make build exit 0，Debug Simulator .app 构建成功 |
| final-boundary-audit.json | exit 0；93 个受保护文件 SHA-256 全部与本轮开始相同；RecommendationRow 及图片实现逐字相同 |
| git diff --check | exit 0 |

首轮少数 Swift Testing 方法过滤器漏写 `()`，没有匹配到用例，未计为通过；已按 xcresult 实际 testIdentifier 补跑上述 6 项。合计 25 个逻辑 Unit / 26 次执行通过。既有共享列表 Unit 输出 visibleCells-during-update UIKit 诊断，测试断言仍通过；保留原日志，未改共享实现来消除它。

## 命令与复现

所有 xcodebuild 使用相同工程/方案、`.build/DerivedData`、`.build/SourcePackages`、`-onlyUsePackageVersionsFromResolvedFile -skipPackageUpdates -parallel-testing-enabled NO -testPlan TiebaLite`。

```text
xcodebuild -project TiebaLite.xcodeproj -scheme TiebaLite [上述公共参数]
  -only-test-configuration 'UI Smoke' test
  -destination 'platform=iOS Simulator,id=70D93841-1FEB-445A-8FAD-B1C29B981D5D'
  -test-iterations 3
  -only-testing:TiebaLiteUITests/R02RootShellSmokeTests/testDeepDynamicScrollAndRepeatedRootSwitchesStayResponsive
  -resultBundlePath Artifacts/VisualReview/R02/ListRedesign/deep-scroll-three-runs.xcresult
```

原始基线同一选择器运行一次，没有 `-test-iterations 3`。iPad 目的地为 `EE89FBE1-9DCA-49DC-8432-8A9C856A28FF`，选择器为 `R02RootShellSmokeTests/testIPadDynamicScrollSidebarAndWidthChangeKeepTheVisibleThread`。帖子返回选择器为 `AppShellSmokeTests/testFixtureRecommendationsLoadThreePagesAndPreservePosition`。两次 UI 只复用既有产品时使用 `test-without-building`；修正 iPad 测试坐标参数后重新使用 `test` 编译。每次均保留独立 log/xcresult 与原始退出码，没有调用会卸载 App 的 UI wrapper。

Unit 配置为 `-only-test-configuration Unit`。首批选择 `RecommendationsListPresentationTests`、`ProductionImageLoaderTests`、`Stage19ImageCellReuseTests`、`R01AvatarCellReuseTests`；补跑使用下列精确方法选择器：

```text
Stage156LivePaginationTests/fixtureRecommendationsLoadThreePagesWithStableFirstWinsOrder()
Stage156LivePaginationTests/recommendationFailureRetryBurstAndRefreshGenerationStayIsolated()
Stage156LivePaginationTests/emptyOrDuplicateOnlyRecommendationPageStopsClientPrefetch()
Stage17AdaptiveLayoutTests/retainedValueUpdateAfterSettledAnchorDoesNotRepositionLiveTable()
Stage17AdaptiveLayoutTests/unchangedResizeKeepsOneDiffableSnapshotAndStableIdentity()
Stage17AdaptiveLayoutTests/initialAnchorStillRestoresWhenTheTableIsCreated()
```

## 安装、手工检查与截图

- 两台使用 `xcrun simctl install <UDID> .build/DerivedData/Build/Products/Debug-iphonesimulator/TiebaLite.app` 覆盖安装，exit 0；没有卸载、erase、清 Keychain、退出登录或修改凭据。
- 使用 `xcrun simctl launch --terminate-running-process <UDID> dev.local.tiebaliteios` 启动，exit 0。此前两次误写 `--terminate-running` 的 Fixture 启动尝试分别 exit 148 / 4，未启动目标；读取 help 后改用正确参数，Fixture 启动 exit 0。
- 自动化均使用隔离 Fixture；手工 iPad Fixture 横/竖屏图片 `ipad-manual-landscape-fixture.png` / `ipad-manual-portrait-fixture.png` 显示列表随宽度重新布局、界面可切换。手工首屏拖动/滚轮未确认追加到第二页，因此不将其算作分页通过，也不把未响应滚轮等同主线程卡死。
- 最终 Debug iPhone 停动态页且加载真实内容，现有登录状态保留；iPad 停动态页的原有未登录提示，没有操作登录。最终截图：`iphone-final-dynamic.png`、`ipad-final-dynamic.png`。iPhone Simulator 已置前。

## 限制与下一步

- 原卡死在当前基线重新证实，候选的原场景 3/3 通过；此结论限定于当前 iPhone/iOS 26.5、原 root.mixed-media Fixture，不能外推为 UITableView 必然解决所有布局问题。
- iPad 侧栏返回可见行未保持，帖子 push/pop 精确偏移测试也未通过；因此本轮没有满足全部出口条件。当前 AppShellView 的 iPad contentColumn 按选中入口切换 View 分支，共享 VirtualizedList 只支持初建时按行顶部恢复；这提示容器生命周期/行内偏移风险，但尚无足够证据将两项偏移失败归于单一根因。未修改这些受保护组件，也没有通过增加延迟、放宽超时/位置断言或重试隐藏失败。
- 不再追加视觉补丁、不扩大修改范围。`READY_FOR_USER_VISUAL_REVIEW` 在此仅表示候选 App 已打开供用户检查，不表示全部验证通过或 R02 获准结束。下一阶段仍需解决/明确接受以上失败并由用户批准；不自动进入 R03/R04。

## 用户批准后的提交复核

2026-09-23 用户明确批准当前 Simulator 并授权提交、进入 R03。本次复核：36/36 定向 Unit（包含 R02 与 R03 的 Followed/History 基线）通过；iPhone Shell 3/3 通过（独立路径、媒体单实例、原深滚动）；make lint、secret-scan exit 0。iPad Shell 1/1 通过（40.803 秒）；make build exit 0。日志在 `Artifacts/VisualReview/R03/r02-approval-*` 与 `approval-baseline-unit.*`，先前失败未删除或改写。

暂存后首次 `git diff --cached --check` exit 2：两份新纳入的 R01/R02 提示词含原有 Markdown 行尾双空格；只清理这两处空白，再次检查通过。
