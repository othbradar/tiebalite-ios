# TASK_STATE

- 当前阶段：06
- 状态：`SPIKE_PARTIAL`
- 当前分支：`main`
- 阶段 05 提交：
  `4005387738f8c7425e93fde82b042cb589c98699`
  （`feat: complete stage 05 design system and app shell`）
- 阶段 06 工作树：未提交；不得进入阶段 07。
- 允许修改范围：Debug-only `InteractionLab` Pager/Media 实验、本地图片
  fixture、状态/生命周期 Unit tests、iPhone/iPad interaction UI tests、
  XcodeGen/质量隔离脚本、ADR、审计报告和本文件。
- 禁止修改范围：业务 Feature/Store、真实贴吧 API、Protobuf、Session、
  Cookie/Keychain、生产图片缓存、Android submodule、生产 Pager/
  MediaViewer、第三方依赖，以及阶段 07 或后续内容。

## 规则、规格与技能

- 已读取根目录及 `App`、`Sources/InteractionKit`、`Tests`、`UITests`、
  `Specs`、`Docs` 目录链上适用的 `AGENTS.md`。
- 已读取 `Prompts/06_PAGER_AND_MEDIA_INTERACTION_SPIKES.md`、
  `Specs/04_INTERACTION_CONTRACT.md`、`Specs/05_MOTION_CONTRACT.md`、
  ADR-0004、ADR-0005 和进入阶段时的 `TASK_STATE`。
- 已显式使用 `.agents/skills/ios-interaction-qa`、
  `.agents/skills/ios-motion-audit`、`.agents/skills/xcode-quality-gate`、
  `.agents/skills/ios-root-cause-debug`，并按 Computer Use skill 对
  Simulator 做人工观察。三个子代理只读复审架构/状态、交互/无障碍和
  工程/Release 隔离；所有工作树写入均由主代理完成。

## 阶段 05 提交与阶段 06 基线

- 用户授权后精确暂存阶段 05 文件，执行 cached diff check 并提交成功：
  `4005387738f8c7425e93fde82b042cb589c98699`。
- 首次 `git add` 因沙箱不能创建 `.git/index.lock` 失败；以批准权限重跑
  同一精确暂存命令成功。没有 amend、merge、rebase、push 或 tag。
- `.idea/dataSources.xml`、`.idea/db-forest-config.xml` 已有用户暂存/
  工作树状态，另有 `.idea/noctule.xml`、`.idea/vcs.xml` 与两个
  `.DS_Store` 漂移；均不属于阶段 06，未修改、未 restore、未纳入阶段
  05 提交，也不得纳入后续精确暂存。
- 阶段 06 开始时 `make doctor` 通过：macOS 26.6、Xcode 26.6
  （17F113）、Swift 6.3.3、Git 2.50.1、XcodeGen 2.45.4、
  SwiftLint 0.65.0、xcbeautify 3.2.1；Simulator 可见。
- Android reference 全程只读、clean，锁定
  `5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`。
- 阶段 06 实现前完整 `make quality` 通过：
  - Debug build：`20260731-163009-39064-build.log`
  - Unit 43/43：`20260731-163010-39099-unit.xcresult`
  - iPhone UI 12/12：`20260731-163031-39529-ui-smoke.xcresult`
  - iPad build：`20260731-163338-40956-ipad-build.log`
  - iPad UI 2/2：`20260731-163340-40987-ui-smoke-ipad.xcresult`
  - Release：`20260731-163447-41237-release-build.log`

## 阶段 06 修改

### Debug InteractionLab

- 新增 `App/DebugInteractionLabView.swift`、
  `App/DebugPagerLabView.swift`、`App/DebugMediaPageView.swift`。
- 新增
  `Sources/InteractionKit/InteractionLab/DebugPagerStateMachine.swift`、
  `DebugPagerContainer.swift`、`DebugMediaGestureOwnership.swift`、
  `DebugZoomImageView.swift`。
- 更新 App Shell、Settings Debug 路由、组件画廊入口和稳定
  accessibility identifiers。所有 Lab 文件使用 `Debug*` 命名；
  InteractionKit 实验另有 `#if DEBUG`，Release source exclusion 再提供
  第二层隔离。

### Tests 与质量脚本

- 新增 `Tests/PagerStateMachineTests.swift`、
  `Tests/MediaInteractionStateTests.swift`、
  `Tests/InteractionControllerLifecycleTests.swift`。
- 新增 `UITests/InteractionLabTests.swift`、
  `UITests/IPadInteractionLabTests.swift`，并扩展 typed UI harness。
- `Makefile` 新增 `test-ui-interaction`、
  `test-ui-interaction-ipad`，并纳入 `make quality`。
- 更新 `project.yml`、`scripts/run_xcodebuild.sh`、
  `scripts/project.env.example`、UITesting/Release 隔离脚本及交互静态清单
  脚本。
- 更新 ADR-0004、ADR-0005；新增
  `Docs/Audits/INTERACTION_SPIKE_REPORT.md` 与
  `Docs/Audits/PHASE06_INTERACTION_INVENTORY.md`。

## 候选与关键状态

- SwiftUI `TabView(.page)` 候选运行后淘汰并删除：公开 API 只能在
  selection 提交后观察变化，无法提供 begin/cancel token 或冻结转场参与
  页，不能证明增删/取消语义。
- UIKit 候选使用稳定 PageID、单调 transition token、冻结
  source/target/participant、pending order reconcile、删除 fallback
  （下一存活 ID→前一 ID→nil）、有界 controller dictionary 与显式
  delegate/dataSource/cache teardown。
- Media 使用本地 small/2048×2048/delayed/failure fixture，每页一个
  UIScrollView zoom coordinator；精确 zoomScale/contentOffset 不进入
  SwiftUI 状态，single tap 等待 double tap recognizer 失败。
- overlay 顺序为不透明黑色背景→Pager→状态/chrome；关闭回来源页并显示
  `Overlay: absent`。无生产数据、网络或持久化。
- 动效仅使用系统 Pager/UIScrollView；没有新增任意 duration/curve，
  没有业务 DragGesture、透明全屏遮罩、极端 zIndex 或第三方依赖。

## 已确认的退出条件与 UNKNOWN

阶段 06 不满足 `SPIKE_ACCEPTED`。以下均为 Debug 候选的已知缺口：

1. `MediaGestureSession` 只有状态模型 Unit 证据，未接入运行时 recognizer
   begin。边界处内层 pan 与外层 Pager 都可能启用，未按手势方向固定
   owner；同一触摸 handoff 为 `NOT_TESTED`。
2. 成功离场只重置父层 capability/zoom 文本；缓存的同 MediaID
   UIScrollView 未收到 reset token，真实 zoom 可能保留。现有 UI 路径在
   离场前主动 zoom-out，不能证明离场 reset。
3. Pager 延迟 selection commit 缺少 generation/expected-source，旧任务
   可能覆盖同一 MainActor turn 内较新的外部 selection。
4. 横竖屏条件布局可能 dismantle/recreate Pager representable；当前回归
   只证明 PageID 与 viewport 可见，不证明 coordinator/相邻页生命周期
   连续。
5. 真实 iPad split divider、iOS 18.x runtime、VoiceOver/Accessibility
   Escape、动态白块逐帧、完整半程取消/反向、Media safe-area/大字体、
   100 张 full-resolution lease 均未完成。
6. Computer Use 可以点按钮和旋转 Simulator，但不能可靠注入 drag、
   pinch 或 scroll；三张截图仅证明 settled Pager、Media 初始页和关闭后
   overlay，无独立逐步 artifact 证明全部人工动作。

因此 UIKit Pager 与 UIScrollView Media 仅保留在 Debug InteractionLab；
不得改名、移动或复制为生产组件。后续补测仍失败时回滚为显式前后按钮/
单图方案，不得让 Feature 复制当前实验。

## 红绿证据与失败记录

- 首次状态测试在实现前退出 65：
  `20260731-164127-42139-unit.xcresult`，为预期 production symbol
  缺失；`164239`、`164304` 又暴露 optional/Swift Testing mutation 编译
  错误，修正后 Unit 转绿。
- 初轮 interaction UI 3/6：
  `20260731-165624-43983-ui-interaction.xcresult`。根因为 single-tap
  异步断言、大字体下按钮不可达和取消拖动位移过大。
- 第二轮 5/6：
  `20260731-170157-44937-ui-interaction.xcresult`；reset 在横向控件外。
  改两列 grid 后定向用例
  `20260731-171200-cancel-targeted.xcresult` 通过。
- 冻结唯一候选前 iPhone 5/5：
  `20260731-174030-50886-ui-interaction.xcresult`；iPad 1/1：
  `20260731-174540-51572-ui-interaction-ipad.xcresult`。二者早于最终横屏
  布局修复，不能替代最终完整门禁。
- Computer Use 重复发现横屏状态为 p2 但 Pager 视口近乎空白。可靠红例：
  `20260731-175600-rotation-color-regression-red.xcresult`。根因是 Lab
  单列 VStack 压缩视口，不是 PageID。横屏改为控制区/视口并排，真实
  viewport-height 回归
  `20260731-180800-rotation-viewport-regression-green.xcresult` 通过。
- 中间颜色截图探针在已知可见竖屏也返回 0；`175800`、`180100`、
  `180400` 等失败未被伪装为产品失败，探针已删除并改测真实 geometry。
- 沙箱内 `make test-unit` 曾因 CoreSimulator destination 不可见退出 70，
  `20260731-173832-50362-unit.log`；以批准权限运行同一命令后 Unit
  61/61 通过：
  `20260731-173952-50516-unit.xcresult`。
- `make lint` 曾从 5 个再到 1 个 violation；逐项修正后 59 个 Swift
  文件 0 violation、0 serious。
- `simctl launch` 首次用了错误 bundle ID 并退出 4；从共享 xcconfig
  取得实际 ID 后启动成功。直接 xcodebuild 的 LLDB debugger warning
  为非致命 Simulator 环境提示。
- AppShell Release 路由曾无条件引用 Debug-only case；修正闭包
  `#if DEBUG` 后 fresh `make release-isolation` 通过：
  `20260731-181450-58681-release-build.log`。

## 当前验证状态

- 冻结源码定向 Unit：61/61 PASS，
  `20260731-182332-60336-unit.xcresult`。
- `make quality-fast`：PASS；Debug build
  `20260731-182415-61341-build.log`，Unit 61/61
  `20260731-182418-61421-unit.xcresult`。
- 最终完整 `make quality` 输出 `Quality gate completed.`：
  - rules/8 repo skills、Android lock、deterministic XcodeGen、static
    canaries、secret scan、SwiftLint 59 files/0 violation、forbidden
    0 error group 全通过；
  - Debug build：
    `20260731-184220-65782-build.log`；
  - Unit 61/61：
    `20260731-184221-65805-unit.xcresult`；
  - iPhone App Shell UI 12/12：
    `20260731-184242-66086-ui-smoke.xcresult`；
  - iPhone interaction UI 5/5：
    `20260731-184551-66648-ui-interaction.xcresult`；
  - UITesting/Debug gallery/InteractionLab 隔离：PASS；
  - iPad build：
    `20260731-185043-67042-ipad-build.log`；
  - iPad App Shell UI 2/2：
    `20260731-185044-67071-ui-smoke-ipad.xcresult`；
  - iPad interaction UI 1/1：
    `20260731-185150-67240-ui-interaction-ipad.xcresult`；
  - Release build 与 source/bundle/strings/symbols isolation：
    `20260731-185231-67389-release-build.log`，PASS。
- `xcrun xcresulttool get test-results summary` 对最终五个 xcresult
  独立确认：Unit 61、iPhone smoke 12、iPhone interaction 5、iPad
  smoke 2、iPad interaction 1，全部 0 failed/0 skipped，运行于 iOS
  26.5 Simulator。
- 早期定向 Unit 61/61：
  `20260731-173952-50516-unit.xcresult`。
- 当前源码旋转定向回归：1/1 PASS，
  `20260731-180800-rotation-viewport-regression-green.xcresult`。
- 修复 Release 条件编译后的单独 fresh isolation：PASS，
  `20260731-181450-58681-release-build.log`。
- `make lint` 单独复跑：59 files，0 violation、0 serious。
- 交互清单脚本增加 file/line 稳定排序后，两次输出 SHA-256 均为
  `9eb8a4051e3cf1778b3132d4f297126ea27ec07ed7942a58dbefef1681b1bcc5`，
  且与 `PHASE06_INTERACTION_INVENTORY.md` 逐字一致；上述最终
  `make quality` 是在该修复之后运行。
- 最终 `make doctor`：0 failure、0 warning；iPhone/iPad Simulator
  可见，规则链、工具版本与 Android reference 均通过。
- `bash -n scripts/*.sh`、`scripts/secret_scan.sh`、阶段 06 tracked/
  untracked whitespace check、全工作树 `git diff --check` 与 cached
  diff check 全通过；交互清单已重新运行并更新。
- 最终 cached diff 仍只有用户原有的两个 `.idea` 文件；没有阶段 06
  文件被暂存。Android submodule status 无输出，HEAD 仍为
  `5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`。
- 完整门禁只证明自动化覆盖；它不把明确列出的手工缺口或四个运行时
  风险变为已验证。阶段状态保持 `SPIKE_PARTIAL`，阶段 06 工作树保持
  未提交，未进入阶段 07。
