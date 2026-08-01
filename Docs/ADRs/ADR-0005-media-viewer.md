# ADR-0005：唯一 MediaViewer

- 状态：Proposed（阶段 06 Spike Partial，仅 Debug）
- 日期：2026-07-31
- 决策者：阶段 02 候选决策，待阶段 06 spike
- 关联阶段：02、06、09

## 背景

P0 MediaViewer 需要分页、双击/捏合缩放、缩放后平移、边界加载、旋转与
关闭恢复。纯 SwiftUI 手势、UIScrollView zoom 和外部图片库的取舍涉及高
风险手势仲裁与资源生命周期。ADR-0004 的 Pager 尚未由运行 spike 选定。

## 必须满足的约束

- App 中只有一个生产 MediaViewer 和一个 PagerContainer。
- Viewer 是进程内非持久 overlay；父 route/Store 是返回真相。
- 精确 zoomScale/contentOffset 只有一个 owner。
- loading/error/转场全程背景不透明且 frame 稳定。
- 首版无下滑关闭，不叠加自定义全屏转场。
- URL、Cookie、完整 descriptor 和图片数据不进入 scene restoration。

## 候选方案

### A：纯 SwiftUI Magnify/Drag 手势

- 优点：SwiftUI 层统一。
- 缺点：与 Pager、系统 back、双击、惯性和边界 handoff 需要手工仲裁。
- 风险：两个手势同时移动、复用串 transform、依赖延迟判定。
- 验证方式：与 UIScrollView 候选执行同一手势矩阵。

### B：每页一个 UIScrollView zoom wrapper + 唯一 PagerContainer

- 优点：缩放、平移、双击焦点和 content inset 有成熟系统语义。
- 缺点：需桥接 SwiftUI identity、尺寸变化、复用 reset 和离散能力状态。
- 风险：UIScrollView 与领域 Store 双持几何真相，或在同一 gesture 中抢权。
- 验证方式：阶段 06 以三图 fixture、旋转/resize 和生命周期 probe 验证。

### C：第三方图片查看器

- 优点：可能提供现成缩放和缓存。
- 缺点：未经批准的生产依赖，且常自带第二套 pager/cache/转场。
- 风险：无法满足唯一 owner、隐私与退出成本。
- 验证方式：只有 A/B 均有已证平台阻塞后才能新建依赖 ADR。

## 候选决策

选择 B 作为待验证方向，整体保持 Proposed，直到 ADR-0004 和 Media spike
同时通过。

AppShell 使用唯一受控 full-screen presentation 呈现
`MediaPresentation`：

```text
sourceRoot + sourceRouteIdentity + sourceItemID
+ ordered stable MediaDescriptor + initialMediaID
+ optional boundaryContext
```

它只存在于当前进程，不写 restoration。Viewer 关闭只清
`presentedMedia`，不刷新或重建父列表。

每个 MediaID 只有一个 ZoomPage/Coordinator 持有精确 zoomScale、
contentOffset、contentSize 和手势状态。领域 Media Store 只持：

- currentMediaID；
- chrome visibility；
- item loading/error；
- previous/next boundary request state；
- 离散 `atMinimumZoom` 与 `horizontalBoundary` 能力。

禁止 Store 与 UIScrollView 双向同步精确几何量。

### 手势仲裁

- 目标契约是在 gesture begin 时固定 owner。
- minimum zoom：Pager 可拥有明确水平拖动。
- zoomed 且不在水平边界：UIScrollView 独占整个 gesture。
- 同一 gesture 到达边界时不移交。
- 已在边界时，下一次朝外且水平意图明确的 gesture 才可交给 Pager。
- 单击 recognizer 必须等待双击失败；禁止用 `asyncAfter` 区分。
- 双击围绕点击位置缩放；pinch/pan 由 UIScrollView 管理。
- 翻页完成后才重置离场页；取消/反向不重置当前页。
- 旋转/resize 只 clamp 当前页 transform，不把 transform 复制给其他 ID。

### 资源生命周期

- 只保留 current 与转场所需相邻页的 full-resolution presentation 资源。
- 远页或关闭时取消其订阅/请求，清 delegate/callback，并释放 Viewer 自有
  full-resolution 资源。
- 共享网络/缓存由 ADR-0008 的唯一 ImageRepository 管理。
- boundary 每方向最多一个请求，并带 request identity/cursor；关闭时全部
  取消，旧响应不能重开 overlay。
- initial/current ID 消失时始终进入稳定 unavailable，保留明确关闭动作；不
  自动关闭，也不按旧 index 偷换。

### z-order 与可访问性

固定顺序为：不透明语义媒体背景 → Pager → chrome。chrome 隐藏时移出
hit-test 与 accessibility tree，但保留 Accessibility Escape 和可访问关闭
动作。控件只拦截自身区域，不能用透明全屏层修复手势。

## 为什么不是其他方案

A 在目标交互下需要重复实现 UIScrollView 已提供的复杂行为；C 会带入第二套
Pager/cache/转场并违反依赖门禁。B 仍需 spike，不能直接成为生产代码。

## Spike 验收

- 单图/多图、首末页、initial ID 消失、边界成功/失败/重试。
- minimum zoom 可翻页；zoomed 中部只平移；到边界同手势不翻页；下一次
  朝外拖才翻页。
- 单击、双击焦点、pinch、取消/反向均无双触发。
- 翻页完成后旧页 reset；取消后当前 zoom 保留；复用不串 MediaID。
- 旋转和两个 iPad 宽度后 current ID 不变，transform 合法 clamp。
- loading/error 无透明露底；关闭后父 item/scroll anchor 不变。
- 连续浏览 100 张后 controller、任务和 Viewer 自有 full-res 资源不单调
  增长；关闭后 weak/deinit probe 证明释放。
- VoiceOver 页数、关闭、Accessibility Escape 正确；Reduce Motion 不改变
  功能。

## 阶段 06 运行结论

阶段 06 只验证 B 的 Debug 实验，没有批准生产 MediaViewer：

- 每个本地 fixture MediaID 使用独立 `UIScrollView` coordinator；精确
  zoom/offset 不进入 SwiftUI Store。单击 recognizer 显式等待双击失败，
  没有延迟判定。
- 离散 `MediaPageCapability` 与 `MediaGestureSession` 状态模型可在手势
  begin 固定 owner；单元测试覆盖 minimum zoom、zoomed interior、已有
  边界的下一次手势、垂直/模糊意图、完成/取消后的逐 ID zoom reset。
  但该 session 尚未接入运行时 recognizer begin；Debug viewer 目前按最新
  capability 动态切换 Pager，不能作为“同一触摸不移交”的实现证据。
- 成功翻页后当前实现只把父层 capability/zoom 文本设回 minimum；相同
  MediaID 的缓存 `DebugZoomScrollView` 不会收到 reset identity/token，
  所以返回旧页时真实 zoom 可能仍保留。现有 UI 路径先主动 zoom-out 再
  离场，不能证明离场 reset 或逐 ID zoom 隔离。
- XCUITest 覆盖单图/多图、延迟图、失败/重试、双击、pinch、zoom 后禁止
  翻页、主动恢复 minimum zoom 后翻页、chrome 和关闭清理。Computer Use
  通过明确可访问按钮验证上一张/下一张、延迟态与关闭后
  `Overlay: absent`，但无法可靠注入 pinch/pan。
- 旋转后的精确 zoom clamp、真实 iPad split resize、运行时 fixed-owner
  接线及同一触摸到达边界后的 handoff、真实离场 zoom reset、
  Accessibility Escape/真实 VoiceOver、100 张
  full-resolution lease 上界尚未完成手工运行。因此状态为
  `SPIKE_PARTIAL`；所有实现继续位于 Debug InteractionLab 并被 Release
  排除，不能接业务 Feature。

回滚方案保持为单图加显式前后按钮；补齐矩阵前不得创建生产
`Features/MediaViewer`、第二套 Pager 或新图片/手势依赖。

## 阶段 06B 收口结论

阶段 06B 关闭了 cached transform 与部分尺寸/释放风险，但发现新的真实
横屏阻塞：

- 每个 MediaID 新增单调 reset generation。只有完成离场或显式可访问切图
  才触发；取消不触发。`DebugZoomScrollView` 收到新 generation 后实际把
  zoomScale、contentOffset 和 capability 复位。有效红证据为
  `20260801-122224-53158-unit.xcresult`，绿色 Unit 与 iPhone/iPad UI 均验证
  返回同一 cached MediaID 时 `Zoom: 1.00`。
- 极小、超宽、超高和未知尺寸 fixture 在四个 iPhone/iPad viewport resize
  后 frame、inset、offset 与 zoom 均为有限值；iPad Media 竖横屏保持业务
  ID 与 zoom，并可访问切图、复位和关闭。
- 双击 zoom 是否动画现在直接遵守 Reduce Motion；未增加 duration、curve、
  Motion token 或第二套动画。
- coordinator dismantle 清 delegate/两个 tap recognizer，weak probe 证明
  coordinator 与 scroll view 可释放；iPhone 连续 5 次打开/关闭均回到
  `Overlay: absent`。这不等同于 100 张 full-resolution lease 压力测试。
- Computer Use 在 iPhone 上实际完成双击到 2.50、pan 后保持 `large`，随后
  旋转复现 chrome 按钮不可见/裁出可视区；截图为
  `Artifacts/TestResults/phase06b-media-rotation-chrome-clipped.png`。未使用
  zIndex、透明 overlay 或延迟参数猜修。
- `MediaGestureSession` 仍只在模型层固定 owner。运行时继续按最新
  capability 动态启停 Pager，不能证明同一触摸到边界后不移交；非法图片
  bytes、异步取消/stale callback、快速 burst、VoiceOver Escape 和真实
  split divider 也未在 Media Spike 内完成。

因此 ADR 状态继续是 `Proposed（阶段 06 Spike Partial，仅 Debug）`；不得
建立生产 MediaViewer 或解除后续阶段门禁。

## 迁移/退出成本

Pager 与 ZoomPage 通过离散能力接口连接，可分别替换。不得为修复失败复制
第二个 Pager/Viewer 或全局清缓存。

## 验收与回滚条件

需要私有 API、Pager/zoom 同时移动、复用串状态、父滚动丢失或资源无法释放
时不得进入生产。同类问题两次最小修复仍失败，回退为单图加显式前后按钮的
可测试降级呈现并重新设计，不继续参数试错。
