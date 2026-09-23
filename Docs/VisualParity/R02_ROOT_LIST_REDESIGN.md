#
R02 动态滚动卡死：承载层修订提案

2026-09-23 用户查看 Simulator 后明确反馈“我看了r02现在没问题了，提交并进入r03”，R02 记为 `USER_VISUALLY_APPROVED`。此前自动化返回位置失败保留为已知记录，不改写为通过；用户已授权提交当前实现并进入 R03。

状态：`IMPLEMENTED_WITH_OPEN_VALIDATION_FAILURES`。用户已明确批准在 R02 内实施最小承载修订；当前工作树原失败已重新复现并采样，采用修订后原回归连续 3/3 通过，但 iPad/帖子返回位置仍有失败。执行与安装结果见 `R02_LIST_REDESIGN_ACCEPTANCE.md`；保留候选供手工检查，不宣称阶段通过、不扩大到共享组件、不进入 R03/R04。以下保留原提案及决策边界。

## 证据与边界

同一 iPhone 17 Pro / iOS 26.5 中，生产现场和离线 ProductionImageLoader Fixture 都在动态深滚动时进入主线程 LazySubviewPlacements / AttributeGraph 布局循环。固定缩略图外框、改写元数据 ViewThatFits 两个独立尝试均失败且已撤回。第二次采样已没有 SizeFitting 分支，但 LazySubviewPlacements 仍持续循环，故不能把元数据分支选择声明为唯一根因。

提案时能证实的是：动态页的 SwiftUI LazyVStack 与异步解码后的可变高度行组合不能稳定完成此次布局；尚未定位到 SwiftUI 内部单一错误。现象与 ADR-0018 的既有 ThreadReader 承载决策相似。实施后的原回归结果见顶部，不把有限 Fixture 通过外推为 UITableView 必然解决所有问题。

## 拟定的最小修改

1. **仅动态列表接入既有 `VirtualizedList`**。不修改 VirtualizedList.swift、UITableView/Diffable/UIHostingConfiguration 实现、ForumHome、ThreadReader、Pager、MediaViewer。也不新建第二份通用列表。
2. 新增 `RecommendationsListPresentation.swift`，使用 `.thread(Int64)` 和单个 `.pagination` 稳定行 ID；已加载 RecommendationSummary 原值作为行内容，footer 状态为显式值。业务 threadID、route、Store、Repository、生产请求与权限不变。
3. `RecommendationsView.recommendationList` 用现有 `VirtualizedList(items:backgroundColor:accessibilityIdentifier:restoredAnchor:onPrefetch:onScrollSettled:rowContent:)` 接口承载相同 Button/RecommendationRow 与 PaginationFooter。保留现有视觉，外边距和行间距由行内 padding 表达，不做 R04 平面 feed 改造。
4. `onPrefetch` 将 `.thread(id)` 转交现有 `store.requestNextPage(after:)`；现有 Store 的 page/generation 防重不变。取消 Cell 自己的分页 task，避免重复触发入口。
5. `restoredAnchor` 使用现有 `store.scrollAnchor.map(RowID.thread)`。`onScrollSettled` 仅对 thread 行记录 ID；footer 不覆盖最后有效 thread anchor。替换原 scrollPosition/scrollTargetLayout，避免在 SwiftUI lazy layout 中双向写 anchor。
6. 图片继续使用相同 RecommendationThumbnailView 与唯一 ProductionImageLoader。生命周期沿用现有 hosted Cell 的 prepareForReuse 取消规则，不修改图片缓存和登录 Cookie 规则。

## 可审查的文件范围

| 文件 | 拟修改 |
|---|---|
| Sources/Features/Recommendations/Presentation/RecommendationsView.swift | 只替换列表承载及其分页/anchor 适配 |
| Sources/Features/Recommendations/Presentation/RecommendationsListPresentation.swift | 稳定 thread/footer 行投影 |
| Tests/RecommendationsListPresentationTests.swift | identity、追加保序、footer 更新、anchor 不被 footer 覆盖 |
| UITests/R02RootShellSmokeTests.swift | 保留当前已失败的深滚动断言，不放宽 timeout/位置断言 |
| Docs/ADRs/ADR-0023-recommendations-existing-virtualized-list.md | 若采用，记录现有列表复用的原因与边界 |
| Docs/VisualParity/R02_ROOT_FREEZE.md、R02_ACCEPTANCE.md、VISUAL_PARITY_MATRIX.md、Docs/Progress/TASK_STATE.md | 仅根据实际执行更新结果 |

已有离线 root.mixed-media 场景继续使用生产解码/裁剪/缓存路径和固定内存传输，无真实网络或 Keychain。根导航、Store identity 和共享基础设施不加入修改范围。

## 验证与出口

- 先运行当前红色回归；采用候选方案后同一测试连续 3 次通过，每次滚动至第三页、四个根入口切换、返回位置保持并回到首行 2 轮。
- 相关 Unit、图片复用、推荐三页/返回位置 Smoke、R02 独立导航/媒体单实例 Smoke；iPad 定向侧栏与推荐滚动验证，含宽度变化。只用已有 Fixture，不访问 Live 网络做自动化。
- make lint、make build 或 quality-fast、git diff --check；不跑完整质量或性能矩阵。
- 覆盖安装同一 iPhone/iPad，不卸载、不清 Keychain；人工执行 Live 动态滚动后切底栏，采样确认没有持续布局循环，截图并留在本阶段页面。
- 只有上述真实通过后才恢复 READY_FOR_USER_VISUAL_REVIEW；仍不提交、不进入下一阶段。

## 尚未验证的风险

现有 VirtualizedList 只保存稳定顶部行，不保存行内精确像素偏移；需要证明 Tab 保持同一承载实例时原偏移不丢失，投影重建时至少回到同一业务行。动态缩略图的行高估计、快速分页、Cell 复用取消需要用现有红色 Fixture 实测。提案不承诺它必然修复，若仍失败保留证据并重新评估，不能通过降低断言交付。
