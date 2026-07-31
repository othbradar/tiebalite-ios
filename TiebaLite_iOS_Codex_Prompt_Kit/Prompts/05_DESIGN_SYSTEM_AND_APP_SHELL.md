# 阶段 05：Design System、导航和 App Shell

本阶段建立统一视觉/反馈/路由基础，只使用占位 Feature，不接贴吧数据。

## 开始前

- 读取 `Specs/04_INTERACTION_CONTRACT.md`、`Specs/05_MOTION_CONTRACT.md`、ADR-0003。
- 跑当前质量基线。
- 明确 iPhone 与 iPad route 状态模型，再写 View。

## 实现

### DesignSystem

- 语义颜色：background、surface、primary/secondary text、separator、accent、error、mediaBackground。
- Typography：Dynamic Type 语义样式，不硬编码内容固定高度。
- Spacing、corner radius、icon size。
- Motion 令牌，统一 Reduce Motion 入口。
- 标准组件：InitialLoading、InlineLoading、EmptyState、FullPageError、InlineError/Retry、PaginationFooter。
- 所有组件有 Preview/fixture 和 accessibility 行为。

### App Shell

- 主 Tab：推荐、关注的吧、设置/账户占位。
- iPhone：每个 Tab 独立 NavigationStack/path。
- iPad：NavigationSplitView 或 ADR 指定方案，窄宽度折叠。
- AppRouter 使用稳定 route，不依赖 `AnyView` 或大量 Bool。
- Debug-only 场景菜单可进入组件画廊，Release 不暴露。
- 不自定义页面 push/pop 动画。

## 状态保持测试

- 在推荐占位页 push 两层，切到关注页，再切回，path 保持。
- 两个 Tab 的 path 不互相污染。
- iPad 选择项在宽/窄切换后有定义行为。
- 重复点击 Tab 不重建 App root。
- 深色、大字体、Reduce Motion 下组件可读。

## 禁止

- 不添加 DragGesture。
- 不使用 `UIScreen.main.bounds`。
- 不在 App 根节点添加 `.animation`。
- 不通过 `.id(UUID())` 强制 Tab 刷新。
- 不创建真实 Feature store 或网络请求。

## 验收

- App Shell 在 iPhone/iPad Simulator 可操作。
- 标准状态组件覆盖首次、空、失败、inline failure。
- 动效调用全部来自 Motion。
- UI tests 证明 Tab/path 状态保持。
- `make quality` 通过。

完成后停止。
