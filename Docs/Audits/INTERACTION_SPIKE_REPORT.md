# Phase 06 Pager / Media Interaction Spike Report

## 结论

- 阶段结论：`SPIKE_PARTIAL`
- Pager：`UIPageViewController` 候选仅作为 Debug/UITesting 实验保留；
  SwiftUI `TabView(.page)` 候选已淘汰并删除。
- Media：每页 `UIScrollView` zoom + 同一 Debug Pager 的实验仅作为
  Debug/UITesting 证据保留。
- 生产状态：未创建生产 Pager、MediaViewer 或业务 Feature；Release
  SwiftFileList 和 binary 隔离检查必须排除全部 InteractionLab 实现。
- 阶段 07：未进入。

自动化矩阵已通过当前可运行部分，但 Computer Use 不能可靠向 Simulator
注入触摸 drag/pinch，也未操作真实 iPad split-view divider；本机无 iOS
18.x runtime。因此不满足提示词要求的完整手工矩阵，不能标记
`SPIKE_ACCEPTED`，后续 Feature 不得复制实验实现。

## 环境与基线

- 阶段 05 基线 commit：
  `4005387738f8c7425e93fde82b042cb589c98699`
  (`feat: complete stage 05 design system and app shell`)
- macOS 26.6；Xcode 26.6（17F113）；Swift 6.3.3；Git 2.50.1。
- XcodeGen 2.45.4；SwiftLint 0.65.0；xcbeautify 3.2.1。
- 可用 runtime：iOS 26.5 Simulator。
- iPhone：iPhone 17 Pro，
  `70D93841-1FEB-445A-8FAD-B1C29B981D5D`。
- iPad：
  `EE89FBE1-9DCA-49DC-8432-8A9C856A28FF`。
- Android reference 始终只读、clean，锁定
  `5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`。
- 阶段开始前完整 `make quality` 通过：
  - build：`20260731-163009-39064-build.log`
  - Unit 43/43：`20260731-163010-39099-unit.xcresult`
  - iPhone UI 12/12：`20260731-163031-39529-ui-smoke.xcresult`
  - iPad build：`20260731-163338-40956-ipad-build.log`
  - iPad UI 2/2：`20260731-163340-40987-ui-smoke-ipad.xcresult`
  - Release：`20260731-163447-41237-release-build.log`

## 范围与隔离

允许范围是 `Sources/InteractionKit/InteractionLab/Debug*.swift`、
Debug InteractionLab 页面、本地生成图片 fixture、状态/生命周期 Unit
tests、iPhone/iPad interaction UI tests、质量脚本、ADR 和审计记录。

明确未修改或未创建：

- 推荐、吧、帖子等业务页面/Store；
- 真实 API、Protobuf、Session、Cookie、Keychain、生产图片缓存；
- Android submodule；
- 生产 `Features/MediaViewer` 或生产 Pager API；
- 第三方依赖；
- 阶段 07 内容。

`project.yml` 的 Release 配置排除 `Debug*.swift`，并由
`scripts/verify_release_isolation.sh` 检查 SwiftFileList、bundle、
strings 和 symbols。UITesting 正向检查要求包含 InteractionLab、
固定 launch scenario 和 UI test harness。

## 候选与决策

### Pager 候选 A：SwiftUI `TabView(.page)`

统一 fixture 的运行表明 mutation hook 只能在 selection 已提交后执行。
公开 API 不能提供 begin/cancel token、冻结参与页或取消回调，无法证明
提示词要求的转场中增删与取消语义。运行证据：
`Artifacts/TestResults/20260731-170157-44937-ui-interaction.xcresult`。

结论：淘汰；候选源码完整删除，不留第二套 Pager。

### Pager 候选 B：`UIPageViewController`

Debug wrapper 使用稳定 PageID、单调 transition token、冻结
source/target/participant snapshot、completion 后 pending-order reconcile、
有界 hosting-controller cache，以及显式 delegate/dataSource/cache
dismantle。SwiftUI update 不无条件 reset 当前 controller。

状态机自动化满足核心契约，但 coordinator 尚有两项未关闭风险：延迟
selection commit 缺少同步代次/expected-source，可能覆盖同一 turn 的较新
外部 selection；横竖屏条件布局可能重建 representable，而现有回归只证明
PageID 与可见 viewport，不证明 coordinator/相邻页跨旋转连续。加上手工
触摸和真实 split resize 不完整，只能保留为 Debug 实验。

### Media 候选

仅实现每页 `UIScrollView` zoom wrapper。精确 zoomScale/contentOffset
只归 UIKit coordinator；SwiftUI 只接收 minimum/interior/boundary 等离散
能力。`MediaGestureSession` 状态模型表达 gesture begin 固定 owner，
但尚未接入运行时 recognizer；当前 Debug viewer 会按最新 capability 动态
启停 Pager。因此“同一触摸不移交”只有模型证据，运行时为 `NOT_TESTED`。
单击 recognizer 等待双击失败。成功翻页时父层只重置 capability/zoom
文本；同 MediaID 的缓存 UIScrollView 没有 reset token，真实 zoom 可能
保留。现有 UI 路径在离场前主动 zoom-out，不能证明离场 reset。

纯 SwiftUI 手势和第三方 viewer 未进入实现：前者需要重造边界仲裁，后者
违反唯一 Pager/依赖门禁。

## 行为与生命周期证据

- `PagerStateMachine`：转场参与页冻结、旧 token/重复 completion no-op、
  数据更新延后、插入/重排按业务 ID、删除 fallback 为下一存活 ID→前一
  ID→nil、重复 ID/非相邻 target 拒绝。
- Pager cache：真实 `UIHostingController` 在 100 个 PageID 往返后保持
  有界；teardown 清 delegate、dataSource 和 cache。闭包随 coordinator
  释放，未单独建立 weak/deinit callback probe。
- Media ownership 状态模型：minimum zoom 归 Pager；zoomed interior 归
  zoom page；同一手势到边界不移交；下一次边界手势重新判定；垂直/模糊
  意图不翻页。运行时尚未把 session 接到 recognizer begin，目前仅按最新
  capability 动态开关 Pager。
- Zoom teardown：清 scroll delegate 和自有 tap recognizer；父闭包随
  coordinator 释放，未单独建立 weak/deinit callback probe。
- Overlay：顺序固定为黑色背景→Pager→chrome；关闭清父层 capability
  和 transition source，返回来源页显示 `Overlay: absent`。

冻结源码后最终 Unit 证据（61/61）：
`Artifacts/TestResults/20260731-184221-65805-unit.xcresult`。

## 自动化与人工矩阵

状态含义：`PASS` 仅表示精确场景已在目标 runtime 执行且断言覆盖完整
契约；`PARTIAL` 表示只覆盖子动作、状态模型或 settled frame；
`NOT_TESTED` 表示代码可能存在但没有该场景运行证据。静态截图不能证明
动态手势或转场中的每一帧。

| 场景 | 自动化 | Computer Use | 结论 |
|---|---|---|---|
| 初始页、相邻参与页、稳定 PageID | state participants + cache dictionary + visible ID；无 weak/deinit probe | settled p2 可见 | PARTIAL |
| 快速左右交替 20 次 | 10 组逐次等待完成的往返、Resolved=20；非 burst | drag 无法注入 | PARTIAL |
| 短距离慢拖取消探针 | 6% 慢短拖保持 p2 + state cancel PASS | drag 无法注入 | PARTIAL |
| 半程取消与同一触摸反向 | 无物理手势断言 | drag 无法注入 | NOT_TESTED |
| 转场中插入/删除/重排 | UI + state tests PASS | drag 无法注入 | PARTIAL |
| 转场中真实数据刷新且内容持续可见 | UI 仅切换并最终断言 `Refresh: idle`；transient-empty 仅 state Unit | drag 无法注入 | NOT_TESTED |
| iPhone 系统边缘返回 | XCUITest system-edge swipe PASS | 未重复人工 | PASS |
| 旋转后 ID/可见视口 | PageID + viewport-height 回归 PASS；coordinator continuity 未探测 | 横屏绿色 p2、无洋红/白底 PASS | PARTIAL |
| iPad regular/compact 与旋转 | fixture projection + iPad UI PASS | 真实 divider 未操作 | PARTIAL |
| Pager Reduce Motion | reduced display profile 流程 PASS；未探测动画模式 | 未切真实系统设置 | PARTIAL |
| 100 页 cache dictionary 上界/teardown | UIKit coordinator Unit 清 dictionary/delegate/dataSource；无 child deinit probe | 不适用 | PARTIAL |
| 可访问显式上一页/下一页控件 | UI 按钮路径 PASS | p2→p3→p2 被观察到但无独立逐步 artifact；未开 VoiceOver | PARTIAL |
| Pager VoiceOver page value/adjustable action/朗读 | 无精确定位或朗读断言 | 未开 VoiceOver | NOT_TESTED |
| 转场全程无白块/透明露底 | 不透明 page + sentinel 存在，未逐帧断言 | 仅 settled 横屏截图 | PARTIAL |
| 单图/多图打开 | UI PASS | 多图打开可见 PASS | PASS |
| 延迟图、失败图、重试 | UI PASS | delayed 被观察到但无独立 artifact；failure/retry 未人工 | PARTIAL |
| 双击、pinch、pan/焦点 | 双击与 pinch 改变 scale；swipe 只断言 ID 未变，未断言 offset/boundary/双击焦点 | 工具无法注入 pinch/pan | PARTIAL |
| zoomed 时阻止翻页、minimum 后翻页 | UI 状态路径 + ownership 模型 Unit PASS；runtime fixed-owner 未接线 | 触摸手势无法注入 | PARTIAL |
| 同一触摸到达边界不移交 | 仅 ownership 模型 Unit；runtime 未接线 | 触摸手势无法注入 | NOT_TESTED |
| zoom/MediaID 隔离与离场 reset | 现有 UI 先主动 zoom-out；真实 cached scroll reset 未实现 | 人工路径未先保留 zoom 离场 | NOT_TESTED |
| Media 旋转/resize clamp | 仅离散状态 Unit | 未人工 | NOT_TESTED |
| chrome/关闭/overlay 清理 | UI PASS | 关闭后 `Overlay: absent` PASS | PASS |
| 首末页边界、initial/current ID 消失 | 无 unavailable/删除场景 | 未人工 | NOT_TESTED |
| 快速 Media burst、关闭 pending load/stale callback | 无异步请求或 burst 场景 | 未人工 | NOT_TESTED |
| 返回后的父 item/scroll anchor | 仅 source 元素存在 | 未验证 scroll anchor | NOT_TESTED |
| iPad Media、half/narrow split | 无 iPad Media suite | 未操作 divider | NOT_TESTED |
| Media safe area、深色/大字体/Reduce Motion | 无布局/遮挡/动效断言 | 未人工 | NOT_TESTED |
| Accessibility Escape、图片 label、VO focus/朗读 | 代码存在 escape；zoom surface 仅有 ID，Debug status 强制留在 tree | 未开 VoiceOver | NOT_TESTED |
| 100 张 full-resolution lease 上界 | controller cache 有界，非真实图片 lease | 未人工 | NOT_TESTED |
| iOS 18.x runtime | 编译 deployment target 18.0 | runtime 不可用 | NOT_TESTED |

## 人工截图

- Pager 横屏修复后：
  `Artifacts/TestResults/phase06-computer-use-pager-landscape.jpeg`
- Media large fixture：
  `Artifacts/TestResults/phase06-computer-use-media-viewer.jpeg`
- Viewer 关闭后：
  `Artifacts/TestResults/phase06-computer-use-media-closed.jpeg`

Computer Use 能点击 App 内按钮和 Simulator Rotate，但 `sky.drag` /
`sky.scroll` 没有转换为 Simulator touch；因此没有把它们写成手工手势
通过。自动化录屏由对应 xcresult 保存。

## 缺陷与红绿证据

1. 状态测试先于生产符号：
   `20260731-164127-42139-unit.xcresult` 按预期因 Pager/Media 符号缺失
   退出 65；后续修复 optional/Swift Testing mutation compile 问题
   （`164239`、`164304`）后状态测试转绿。
2. 首轮 Interaction UI 为 3/6：
   `20260731-165624-43983-ui-interaction.xcresult`。根因分别为单击
   recognizer 的异步断言、Accessibility 字体下按钮不可达、短拖位移过大。
   改为 predicate wait、滚动到可点击和更短慢拖。
3. 第二轮为 5/6：
   `20260731-170157-44937-ui-interaction.xcresult`。取消用例的 reset
   按钮仍在横向控件外；改为两列 grid 后，定向取消/变更通过
   `20260731-171200-cancel-targeted.xcresult`。
4. 最终唯一候选矩阵在横屏回归发现前为 iPhone 5/5：
   `20260731-174030-50886-ui-interaction.xcresult`；iPad 1/1：
   `20260731-174540-51572-ui-interaction-ipad.xcresult`。
5. Computer Use 发现横屏时状态仍为 p2，但 Debug Lab 单列控制区把 Pager
   压缩为近空视口。失败回归：
   `20260731-175600-rotation-color-regression-red.xcresult`。
   根因是 Lab `VStack` 的纵向布局约束，不是 PageID 或 UIKit 生命周期。
   宽大于高时改为控制面板/视口并排；可靠的 viewport-height 回归通过：
   `20260731-180800-rotation-viewport-regression-green.xcresult`。
6. 两个中间截图颜色探针在已知可见竖屏也返回 0，证明观测方法无效；
   对应失败 result（`175800`、`180100`、`180400`）未伪装为产品回归，
   最终删除探针，改测实际 GeometryReader viewport height。
7. 最终只读复审发现三个没有被绿色矩阵覆盖的运行时缺口：
   `scheduleSelectionCommit` 缺少代次/expected-source；横竖屏条件布局
   可能重建 Pager coordinator；Media 离场只复位父层文本状态、没有复位
   缓存 UIScrollView。它们没有被临时补丁或更弱断言掩盖，均保留为
   Debug-only 候选的退出条件。

未使用 `asyncAfter`、随机 UUID、透明遮罩、极端 zIndex、全局禁动画、
清缓存、私有手势 API 或删除/放宽测试。

## 动效、手势、overlay 与依赖审计

- 自定义 Motion 调用仍仅位于 `Sources/DesignSystem/Motion.swift`。
- Pager 交互使用系统 `UIPageViewController` 转场；程序化选择在 Reduce
  Motion 时不动画，没有叠加自定义 duration/curve。
- zoom/pan 使用 `UIScrollView` 系统行为；自有 recognizer 只有 single/
  double tap，single 显式 require double failure。
- presentation 只有 Debug `fullScreenCover`，无下滑关闭、自定义全屏转场
  或全屏透明拦截层。
- 无新增第三方依赖。
- 完整静态清单：
  `Docs/Audits/PHASE06_INTERACTION_INVENTORY.md`。

## 剩余风险与退出条件

- 真实 iPad split resize、iOS 18.x、VoiceOver 朗读/escape、复杂
  pinch/pan/边界 handoff 的手工矩阵未完成。
- Pager stale selection commit 与旋转 coordinator continuity 尚无回归；
  Media runtime fixed-owner 和真实 cached-scroll zoom reset 尚未实现。
- 100 页 controller 上界不能替代 100 张 full-resolution 图片资源 lease
  上界；生产 image repository 尚不存在。
- Debug B 候选不得在当前状态改名、移动或复制到生产目录。
- 若后续补测发现 Pager/zoom 同时移动、系统 back 被抢、viewport 再次露底、
  MediaID 串 zoom 或资源无法释放，则删除 Debug 候选并采用显式前后按钮/
  单图降级，重新设计状态和生命周期。

## 冻结源码阶段出口

最终 `make quality` 输出 `Quality gate completed.`：

- Debug build：
  `Artifacts/TestResults/20260731-184220-65782-build.log`
- Unit 61/61：
  `Artifacts/TestResults/20260731-184221-65805-unit.xcresult`
- iPhone App Shell UI 12/12：
  `Artifacts/TestResults/20260731-184242-66086-ui-smoke.xcresult`
- iPhone interaction UI 5/5：
  `Artifacts/TestResults/20260731-184551-66648-ui-interaction.xcresult`
- iPad build：
  `Artifacts/TestResults/20260731-185043-67042-ipad-build.log`
- iPad App Shell UI 2/2：
  `Artifacts/TestResults/20260731-185044-67071-ui-smoke-ipad.xcresult`
- iPad interaction UI 1/1：
  `Artifacts/TestResults/20260731-185150-67240-ui-interaction-ipad.xcresult`
- Release build/isolation：
  `Artifacts/TestResults/20260731-185231-67389-release-build.log`

规则链、8 个 repo skills、Android lock、两次 clean XcodeGen、static
canaries、secret scan、SwiftLint、forbidden scan、UITesting isolation
和 Release SwiftFileList/bundle/strings/symbols isolation 同轮通过。
这是在交互清单稳定排序修复后重新运行的最终门禁；两次清单输出
SHA-256 均为
`9eb8a4051e3cf1778b3132d4f297126ea27ec07ed7942a58dbefef1681b1bcc5`，
并与本报告引用的 inventory 文件逐字一致。
`xcresulttool` 对五个结果包独立确认 61/12/5/2/1 passed，全部
0 failed/0 skipped，iPhone/iPad 均为 iOS 26.5 Simulator。
绿色门禁不关闭前述未执行手工矩阵与已知 Debug 候选风险，阶段结论仍为
`SPIKE_PARTIAL`。

## Phase 06B 定向收口（2026-08-01）

### 状态裁决

- baseline：`b205af6d0bd91d51cb7bc83b6e70f6da7fe93fbe`。
- 最终裁决：`PHASE_06_INTERACTION_SPIKES = SPIKE_PARTIAL`。
- 后续门禁保持：`PHASE_09_BLOCKED_UNTIL_PHASE_06_SPIKE_ACCEPTED`。
- 阶段 09 仍是 `NOT_STARTED`；本轮未读取或执行阶段 09。
- 阶段 08 Renderer/MediaIntent 图片六态未修改；无生产接线、live 网络、
  cache/downsample/candidate/lease、ThreadScreen 或生产 MediaViewer。

任何一项 mandatory 未验证都禁止 `SPIKE_ACCEPTED`。本轮即使自动化绿色，
仍因 runtime fixed-owner、横屏 chrome 裁切、iOS 18/VoiceOver/真实 split 等
明确阻塞而保持 Partial。

### 原未决项与 06B 结果

| ID | 风险与 symbol | 原验收 / 原有证据 | 06B 缺失或新增测试 | 维度 | 阶段 09 硬前置 | 结果 |
|---|---|---|---|---|---|---|
| P1 | `scheduleSelectionCommit` 旧提交覆盖新 selection | stale completion 不得覆盖；原无 controller 回归 | 先红后加 generation/expected-source；完整 Unit 绿 | Pager/identity | 是 | CLOSED |
| P2 | 横竖布局重建 Pager coordinator | 旋转后 ID/frame/identity；原只看默认 ID | sequence 红证明确有重建；`AnyLayout` 后竖→横→竖翻页同 sequence | Pager/resize | 是 | CLOSED（iPhone） |
| P3 | burst、半程取消、同触摸反向 | 原 20 次逐次往返、6% 短拖 | 34% 宽度拖动连续 5 次有 cancelled 状态；未达严格半程，burst/反向轨迹仍无 | Pager/gesture | 是 | PARTIAL |
| P4 | refresh/loading/failure 内容和几何 | 数据更新不露空页；原仅 Bool/final idle | 没有真实 retained revision、loading/failure 等高 frame UI fixture | Pager/visual | 是 | OPEN |
| P5 | child/controller 生命周期 | 100 页有界 cache、delegate/dataSource 清理 | Zoom weak release 已加；Pager child deinit/昂贵内容重建仍未探测 | Pager/perf | 是 | PARTIAL |
| M1 | `MediaGestureSession` 未接 recognizer begin | owner 在触摸开始固定；原只有纯模型 | 运行时仍按最新 capability 动态启停 Pager | Media/gesture | 是 | OPEN |
| M2 | cached `DebugZoomScrollView` 未实际 reset | 完成离场 reset，取消保留 | valid red 后 reset generation；Unit + iPhone/iPad UI 返回同 ID 为 1.00 | Media/identity | 是 | CLOSED |
| M3 | rotation/resize 与极端比例 | transform 合法、无 NaN/Infinity | tiny/wide/tall/unknown × 4 viewport Unit；iPad rotate UI | Media/iPad/resize | 是 | PARTIAL（settled） |
| M4 | async loading/cancel/stale/invalid bytes/burst | load 三态、取消、旧 callback 不反写 | Spike 只有 delayed/failure 本地状态；阶段 08 六态不能代替 Media viewer 运行证据 | Media/load | 是 | OPEN |
| M5 | 关闭与 full-res 资源上界 | 关闭释放，100 张不单调增长 | weak Zoom release + 5 次开关；无真实 task/observer/100 lease | Media/lifecycle | 是 | PARTIAL |
| I1 | iPad split、iOS 18、VoiceOver | 两宽度、旋转、page value/Escape | iPad settled Media 绿；仅有 iOS 26.5，无 divider/VoiceOver | iPad/a11y | 是 | OPEN |
| A1 | dark/大字/Reduce Motion | 状态与功能完整、无必要信息仅靠动画 | Pager reduced UI；Media UIKit zoom 分支 Unit；无完整 Media dark/大字布局断言 | motion/a11y | 是 | PARTIAL |
| V1 | 全帧露白、错页、遮挡、zoom leak | 初始/转场/旋转全程背景与 chrome 正确 | settled 自动化未见错页；Computer Use 实际复现 iPhone chrome 旋转裁切 | visual/safe area | 是 | FAILED |

### 先红后绿与新增证据

- stale commit 红：`20260801-120058-40012-unit.xcresult`；修复后完整 Unit
  通过。
- rotation coordinator 红：
  `20260801-120538-43562-ui-interaction.xcresult`（5/6，sequence 变化）；
  修复后 `20260801-121216-45794-ui-interaction.xcresult` 6/6。
- cached zoom reset 的首个 fixture 在
  `20260801-122059-51449-unit.xcresult` 因未安装 coordinator 而没有建立
  zoom>1 前提，不计产品红；修正 fixture 后有效红为
  `20260801-122224-53158-unit.xcresult`，scale 2.0 在 reset 后仍为 2.0。
  reset generation 后完整 Unit 转绿。
- `20260801-121959-50059-unit.xcresult` 是新增 initializer 的编译失败；
  `20260801-123408-57307-unit.xcresult` 是 Swift Testing `allSatisfy`
  `rethrows` 宏编译失败；两者均修正并保留为真实执行记录。
- 首次新增后 `make lint` 因 `InteractionLabTests` 416 行超过 350 退出 2；
  Media tests 拆到同一 XCTest 类的独立 extension 后 81 files、0 violation。
- 当前聚焦绿色：Unit
  `20260801-123450-58690-unit.xcresult` 为 125/125 顶层逻辑测试（134 次
  参数运行），iPhone interaction
  `20260801-123531-60392-ui-interaction.xcresult` 为 7/7，iPad interaction
  `20260801-124313-62847-ui-interaction-ipad.xcresult` 为 2/2；三者均
  `Passed`、0 failed、0 skipped、0 expected failure，iOS 26.5/23F77。

### Simulator 实际矩阵

| 设备/场景 | 次数 | 结果 |
|---|---:|---|
| iPhone 竖屏 stable-ID p2↔p3 | 20 次切换 | 通过；视觉 ID/index 与 resolved count 一致 |
| iPhone 34% drag cancel | 5 次 | 通过；每次 p2、`idle-cancelled`、count +1；不计作严格半程覆盖 |
| iPhone 竖→横→竖 coordinator | 1 个双向周期、每向翻页 | 通过；同 sequence |
| iPhone Media open/close | 5 次 | 通过；每次 `Overlay: absent` |
| iPhone Media zoom/pan | XCUITest 1 次 + Computer Use 1 次 | 2.50 / pinch 后 current `large` 不变 |
| iPhone Media zoom/pan 后旋转 | Computer Use 1 次 | 失败；chrome 不可见/裁出，截图已保存 |
| iPad Media 竖→横、切图、reset、close | 1 个完整 UI 周期 | 通过；2/2 suite 中的新增用例 |
| iPad regular/compact 默认 p2 | 1 个 UI 周期 | 通过；非默认 ID 与真实 divider 未测 |
| dark + Accessibility Dynamic Type + Reduce Motion | Pager 1 个 UI 周期；Media reduce Unit | 部分通过；Media 完整布局/VoiceOver 未测 |
| iOS 18.x | 0 | runtime 不存在，不得声称验证 |

`xcrun simctl list runtimes -j` 只返回 iOS 26.5（23F77）。固定设备是
iPhone 17 Pro `70D93841-1FEB-445A-8FAD-B1C29B981D5D` 与 iPad Pro
13-inch (M5) `EE89FBE1-9DCA-49DC-8432-8A9C856A28FF`。Computer Use
失败截图：
`Artifacts/TestResults/phase06b-media-rotation-chrome-clipped.png`。

### 06B 身份、手势与生命周期结论

- Pager 身份只使用业务 PageID；coordinator sequence 只用于 Debug 诊断；
  无 UUID。Media state/reset 只按稳定 MediaID。
- Pager 仍是唯一 Debug `UIPageViewController` 候选；Media 仍复用该 Pager；
  没有第二套 Pager/Viewer。
- zoom/pan 由每页唯一 `UIScrollView` 管理；single tap 等待 double tap。
  runtime fixed-owner 未接线，所以不能宣称满足边界 handoff 契约。
- 只读复审另指出 `updateUIView` 同步 `reportCapability` 会回写父级状态，
  尚无去重或嵌套更新回归；当前仅记录为未验证竞态风险，不作已关闭声明。
- 完成离场复位 source cached view；取消不复位。关闭清 SwiftUI 字典与
  transition source；dismantle 清 delegate/recognizers，weak probe 通过。
- 新增动画 0、自定义手势 0、overlay 0、依赖 0。仅把已有 UIKit 双击 zoom
  的 animated flag 接到 Reduce Motion。
- 未使用随机 identity、asyncAfter、sleep、magic zIndex、透明全屏 blocker、
  全局禁动画、私有 API、清空全局缓存或降低/删除失败断言。

### 06B 最终质量门禁

- `make instructions`、`make generate`、`make verify-protos`、
  `make secret-scan`、`make networking-isolation` 与最终 `make lint` 均
  exit 0；lint 扫描 81 个文件、0 violation。`verify-protos` 只有原有 5 个
  unused-import warning。
- 独立命令均 exit 0：`make test-unit`、`make test-ui-interaction`、
  `make test-ui-smoke`、`make test-ui-smoke-ipad`、
  `make test-ui-interaction-ipad` 与 `make quality-fast`。
- 最终 `make quality` 从头 exit 0，并输出 `Quality gate completed.`：
  - Debug build：`20260801-131831-85595-build.log`；
  - Unit：`20260801-131833-85627-unit.xcresult`；
  - iPhone UI smoke：`20260801-131903-85916-ui-smoke.xcresult`；
  - iPhone interaction：`20260801-132414-86650-ui-interaction.xcresult`；
  - iPad build：`20260801-133140-87228-ipad-build.log`；
  - iPad UI smoke：`20260801-133143-87282-ui-smoke-ipad.xcresult`；
  - iPad interaction：`20260801-133400-87518-ui-interaction-ipad.xcresult`；
  - Release build/isolation：`20260801-133529-87706-release-build.log`。
- `xcresulttool get test-results summary` 逐包确认 Unit 125/125 顶层逻辑
  测试（设备参数执行 134）、iPhone smoke 13/13、iPhone interaction 7/7、
  iPad smoke 3/3、iPad interaction 2/2；全部 `Passed`，且 failed、skipped、
  expected failure 均为 0。设备均是 iOS 26.5（23F77）Simulator。
- iPad 两个结果包每个用例均记录非失败 runtime warning：Info.plist 后续将要求
  支持全部 orientation。该 warning 不改变通过计数，但保留为未清理证据。
- 绿色门禁不覆盖前述真实 chrome 裁切与未验证 mandatory 项，因此不改变
  `SPIKE_PARTIAL` 裁决，也不解除阶段 09 门禁。
