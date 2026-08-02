# 阶段 09 Production MediaViewer 审计

状态：`PHASE_09_PRODUCTION_MEDIA_VIEWER_COMPLETE`

范围标签：`OPEN_SOURCE_BETA` / `FIXTURE_FIRST` /
`PRODUCTION_LIVE_DISABLED` / `PHASE_10_NOT_STARTED`

## 范围与生产边界

阶段 09 将阶段 06 接受的交互基础整体迁移为唯一生产实现，并把阶段 08 的
`ThreadMediaIntent` 接到 App 根 presentation：

- `Sources/InteractionKit/Pager` 是唯一生产 `PagerContainer`；
- `Sources/InteractionKit/MediaViewer` 是唯一 zoom、pan 与 gesture ownership
  UIKit bridge；
- `Sources/Features/MediaViewer` 按 Domain/Data/Presentation 分层，只有一个
  生产 `MediaViewer`；
- `AppSceneRoot` 每个 scene 最多持有一个进程内 `fullScreenCover`；关闭只清
  presentation，不修改父导航、列表或 Renderer；
- 输入保留 `ThreadMediaID` 的稳定顺序，以 stableKey 作为 Pager 身份，拒绝空
  集合、重复 stableKey 和不存在的 initial ID；正常身份不生成 UUID；
- 图片通过可注入 `ImageLoading` 获取；UITesting 使用固定 fake loader，
  Release 使用 `DisabledImageLoader`。

本阶段没有创建 ThreadScreen、登录、评论、live 贴吧网络、第二套 Pager、
第二个生产 Viewer、cache/downsample/candidate/lease 大系统或新第三方依赖，
也没有读取或实现阶段 10。

## 状态与交互裁决

每个固定媒体项的展示状态为 idle、loading、rendered、failed-to-fetch、
failed-to-decode、cancelled。取得 bytes 不等于 rendered；只有
`UIImage(data:)` 并 prepare 成功后才创建 zoom surface。loading、fetch/
decode failure 和 cancelled 全部覆盖 Pager bounds，使用语义不透明黑底；
失败提供统一“重新加载”，不产生新的 MediaIntent。

每个 MediaID 的精确 zoomScale/contentOffset 只由一个
`MediaZoomScrollView` 持有。touch begin 时，既有阶段 06 ownership policy
固定 Pager/mediaPan/none；同一触摸不改 owner。只有完成翻页或显式前后切换
才 reset 离场页；取消/失败不 reset 当前页。关闭时失效活动 ownership，页面
task 随 SwiftUI 生命周期结构化取消。

z-order 固定为语义 media background → Pager → chrome。chrome 只拦截自身
控件区域；没有透明全屏 blocker、魔法 zIndex、固定 delay、DragGesture 或
新的任意 animation 参数。根背景使用 `.ignoresSafeArea()` 仅覆盖纯背景。

## 行为先行与回归证据

生产类型存在前先运行 Unit：

- `20260802-121030-27250-unit.xcresult` 因缺少
  `MediaViewerPresentation`/image-load 类型按预期编译失败；该结果不是通过。

实现后的最终完整 Unit：

- `20260802-134430-68489-unit.xcresult`：192 个逻辑测试、211 次执行、
  0 failed、0 skipped；其中阶段 09 新增 6 个逻辑测试、7 次执行，覆盖稳定
  intent 映射、重复/缺 initial 拒绝、成功 decode、fetch/decode failure、
  cancellation，以及重复 representable update 保留默认 zoom surface identity。

iPhone UI 的中间结果 `20260802-122628-32289-ui-smoke.xcresult` 与
`20260802-123827-38984-ui-smoke.xcresult` 分别暴露页数 label 与 image
accessibility identifier 被父容器覆盖；修正可访问树后，
`20260802-124700-stage09-targeted-ui.xcresult` 的单图用例通过，证明 pinch、
双击、pan 和 5 次打开/关闭，多图用例继续暴露 Pager identifier 覆盖。移出根
marker 后，`20260802-125500-stage09-warning-check.xcresult` 的多图用例通过，
且结果中不再包含 SwiftUI “Modifying state during view update” warning。

最终只读复审又定位并关闭两项确定性回归：

- `stage09-accessibility-red-suite.xcresult`：12 个测试中 1 failed，证明普通
  representable update 会把默认 zoom surface identifier 清为 `nil`；保留
  基于稳定 MediaID 的 fallback 后，`stage09-accessibility-green-suite.xcresult`
  为 12/12。
- `stage09-chrome-red.xcresult`：1/1 failed，证明在 rendered 页隐藏 chrome 后
  切到永久 loading/failure 页会失去关闭入口；页面 ID 变化时恢复 chrome 后，
  `stage09-chrome-green.xcresult` 为 1/1。

一次 method-level Swift Testing selector 没有匹配测试、执行数为 0，不计入
回归或通过计数。`20260802-132427-58314-ui-smoke.xcresult` 在只读复审发现上述
阻塞项后被主动中断：当时 3 passed、1 cancelled，整个 `make quality` 不作为
质量结论；修复后已从头重跑最终门禁。

iPad 首轮完整 smoke `20260802-125909-43532-ui-smoke-ipad.xcresult` 为 3/4；
唯一失败是 Simulator 对全屏目标合成 pinch 后 zoomScale 未变化。没有修改
生产手势参数；改用同一生产 wrapper 的双击后，
`20260802-130400-stage09-ipad-targeted.xcresult` 为 1/1，覆盖三图、zoom 后
pan 不翻页、竖→横→竖、chrome/图片存活和关闭。提交前 UI helper 进一步要求
目标 image `hittable == true`，避免把相邻缓存页“存在”误当成当前视觉页；三张
成功 fixture 也使用不同 PNG，便于截图直接识别错图。

## Release 与隔离

Release/UITesting source-list 门禁使用生产文件作为正向控制：

- `Sources/InteractionKit/Pager/PagerContainer.swift`；
- `Sources/Features/MediaViewer/Presentation/MediaViewer.swift`。

旧 `InteractionLab/DebugPager*.swift` 与 `DebugZoom*.swift` 实现已删除；Debug
Media Lab 继续受 `#if DEBUG`/UITesting 隔离并复用生产原语。Release 继续排除
Debug Lab、LaunchScenario、TestSupport、fixture 与 canary；Android submodule
保持 exact `5545326b2a8e0d784b2f3dfbcb219c7b121e61c2` 且 clean。

## 最终质量门禁

最终 `make lint` 为 116 个 Swift 文件、0 violation。允许 Xcode 使用正常系统
缓存后，最终 `make quality-fast` exit 0；随后从头运行 `make quality` exit 0
并输出 `Quality gate completed.`：

- Debug build：`20260802-134428-68408-build.log`；
- Unit：`20260802-134430-68489-unit.xcresult`，192 个逻辑测试、211 次执行；
- iPhone UI smoke：`20260802-134502-68923-ui-smoke.xcresult`，15/15；
- iPhone interaction：`20260802-135323-70562-ui-interaction.xcresult`，15/15；
- iPad build：`20260802-142435-74226-ipad-build.log`；
- iPad UI smoke：`20260802-142439-74277-ui-smoke-ipad.xcresult`，4/4；
- iPad interaction：`20260802-142753-74682-ui-interaction-ipad.xcresult`，2/2；
- Release build：`20260802-143706-75575-release-build.log`；
- Release isolation 与 UITesting isolation 通过，Android reference exact/clean。

全部最终结果均为 0 failed、0 skipped。沙箱内首次 `make quality-fast` 因无权
写用户 SwiftPM/clang cache 而 exit 2/下游 xcodebuild 74；获准使用正常缓存后
同一门禁通过，该权限失败已如实保留，不归因于产品代码。

## Known Limitations

1. 没有 live 图片网络、共享 cache、candidate、downsample 或 full-resolution
   lease；Release 当前没有成功图片业务入口。
2. iOS 18.x、真机、真机 VoiceOver/Accessibility Escape 和真实 iPad split
   divider 未运行。
3. iPad Simulator 的 XCUITest 全屏 pinch 合成未改变 zoomScale；iPhone pinch
   已实测，iPad 以同一生产 wrapper 的双击、pan 和旋转完成 Beta smoke。
4. 50 次开关、100 张 full-resolution 图片、极端内存与全部理论 callback
   排列延期；当前开关实测为 5 次。
5. 生产 iPhone Viewer 本阶段未单独执行横竖屏 UI smoke；生产 iPad 和阶段 06
   底层 rotation/resize 回归已运行。
6. missing initial 当前作为结构错误拒绝 presentation；动态数据移除
   initial/current 后稳定 unavailable 的长期合同尚未实现。
7. Debug Media Lab 是 Debug/UITesting-only 诊断壳；它不是 Feature 可达的
   第二个生产 Viewer。

## 变更类型与停止点

- 新增动画：无；只复用系统 presentation 与阶段 06 Reduce Motion 方案。
- 新增手势：生产化既有 Pager/zoom/tap/pinch/pan ownership；无业务
  `DragGesture`，无下滑关闭。
- 新增 overlay：`AppSceneRoot` 唯一生产 `fullScreenCover`；无额外透明 overlay。
- 新增依赖：无。
- live 网络：无。
- Android submodule 修改：无。

阶段 09 完成后停止。阶段 10 前置条件未在本任务评估，阶段 10 保持
`NOT_STARTED`，只能由新的明确用户指令开始。
