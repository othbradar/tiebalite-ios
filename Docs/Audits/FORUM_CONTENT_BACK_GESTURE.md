# 吧首页首栏内容区返回（2026-09-25）

基线：R10 `3744d4b`，Xcode 26.6 / Swift 6.3.3，iOS 26.5 iPhone 17 Pro / iPad Pro 13 M5。用户明确要求“从帖子内容区右滑也能返回”，不进入新阶段。使用 tiebalite-android-visual-parity、ios-root-cause-debug、xcode-quality-gate；单一写入，无并行子代理。

## 复现与实际根因

Fixture `forum.parity`，从我的吧打开 f13001，保持最左“最新”，在帖子流上向右滑。原始回归三次均未返回（baseline.xcresult，exit65）；只增加手势日志的 diagnostic.xcresult 同样三次失败（exit65）。Pager pan 每次 began(1)→ended(3)，导航栈有2层、当前 committed ID 为首项，系统 content-pop 为 failed(5)。这证明实际触摸命中了分页而未返回，不是 XCTest 找不到按钮，也不是导航栈为空。有限页 Pager 吸收首栏向外右滑并回弹，缺少与系统内容返回的边界仲裁。

Android 参考：用户本轮截图存 ignored Artifacts/Bugs/ForumContentBack/user-reference.jpeg；已查看 Android-target/05-forum-home.png。锁定 UI c5f1125 的 ForumPage / LazyLoad.kt 使用 Compose 横向 Pager，本次内容区域返回要求由用户明确指定。API与组件契约见 ADR-0029。

## 修订与失败记录

- 第一实现（fix.xcresult）使原三次首栏右滑回归通过。扩展边界回归 iphone-final.xcresult（exit65）发现第二栏向右也返回：gate 的 canPrevent 对所有 recognizer 返回 false，无法阻止本应让位于 Pager 的系统 content-pop。该轮原三次回归和既有旋转/Reduce Motion/系统边缘返回通过，非首栏失败保留。
- 第二实现只允许 gate 阻止当前系统 content-pop，仍不阻止 Pager/纵向列表/控件，也不改变系统 delegate。iphone-boundaries.xcresult（exit65）证明前一栏分页和首栏取消后列表位置均已通过，后续“根行同位置”断言失败104pt。原因是测试第一次访问新增了既有最近访问行，却与首次访问前的首页比较。测试先完成一次访问，确认 home.recent.f13001 后再比较同一内容；保留2pt容差和实际路由断言，不改生产主页或放宽断言。
- 初次 lint 报1处新增 UI 测试参数缩进，已修正；lint-final.log 零 violations。错误查找的 Android LazyLoadHorizontalPager.kt 不存在，随后定位真实 LazyLoad.kt；一次提前导出尚未关闭的 xcresult 附件失败，原结果保留。

## 实现范围与限制

ForumHome 仅开启默认关闭的 Pager 参数；新增 NavigationAwarePagerController / PagerNavigationBack 在实际系统导航栈里安装幂等 failure requirements 和局部 pan gate。其他 Pager 调用仍构造原 UIPageViewController，不影响 MediaViewer。数据、分页、selection、controller cache、导航路径和列表复用不改。teardown 移除 gate 与自有引用；无私有 API、定时器、遮罩、delegate 替换、自定义转场或新依赖。新增的是手势仲裁 recognizer，动画仍由系统负责。

iOS 26+ 提供公开内容区返回 API；iOS 18–25 保留系统边缘返回，不声称已实现旧系统的全内容区返回。真机行为待用户检查。自动化仅隔离 Fixture，Live 仅只读操作，不发送、不卸载、不清 Keychain。

## 执行结果

证据均在 ignored `Artifacts/Bugs/ForumContentBack/`；每份 xcodebuild 日志首行保留完整可重放命令。未运行全部 Unit、quality-fast、quality 或无关长矩阵。

| 命令/回归 | 实际结果 |
| --- | --- |
| xcodebuild Unit，仅 ForumContentBackGestureTests / PagerStateMachineTests / PagerControllerLifecycleEvidenceTests / PagerInteractionEvidenceTests | unit.xcresult，22项/4 suites通过，exit0 |
| xcodebuild UI Smoke，仅 ForumContentBackGestureTests，iPhone | iphone-verified.xcresult，2/2通过，55.776秒；首栏三次实际返回、非首栏分页、首栏左滑、短拖动取消、原行位置2pt、根页位置2pt、非首栏系统边缘返回 |
| 既有 InteractionLabTests/testPagerKeepsIDAcrossRotationReduceMotionAndSystemEdgeBack | iphone-final.xcresult中此项通过33.178秒；该结果包整体仍为上文记录的exit65，不改写 |
| iPad首栏三次返回 | ipad.xcresult中此项通过25.222秒 |
| 既有 R05ForumSmokeTests/testIPadForumTabsAndWidthChange | 失败，整轮exit65：横屏分类与滚动、转竖屏保留分类已完成；点“最新”后等待App空闲超过原2分钟上限。保留原断言/超时及诊断，没有判为已通过或已确认UIKit缺陷 |
| iPad手动转屏/标签 | Fixture精华→横屏三列→竖屏全宽，选择保留；点最新实际显示对应列表。截图ipad-manual-rotated-latest.png。CUA后续拖动反而打开帖子，不能作为Live内容右滑已验证的证据；手动返回仍待用户检查 |
| make lint | 初次缩进失败已修正；lint-final.log，350文件0 violations，exit0 |
| make build | build.log，正常完整Debug Simulator构建通过，exit0 |
| make secret-scan networking-isolation | security.log，通过exit0 |
| make forbidden | static.log，失败：ComposerPhotoPreparation.swift:8共享实例被规则拒绝。此文件未改；从HEAD提取受检Swift源码到隔离目录后执行同一source policy仍失败，static-baseline.log。保留R10基线失败，不改图片系统 |
| git diff --check | 通过exit0 |

iPad超时后尝试进程sample时原进程已退出，ipad-sample.log记录“no process”；没有取得有效主线程样本，不能声称主线程空闲已证明。147个受保护源文件（App/Core/ThreadReader/MediaViewer/VirtualList等）与基线hash一致。临时手势探针已移除。

## 交付与人工检查

两台均以simctl覆盖安装正常完整Live App，无Fixture启动参数、无卸载/erase/Keychain清理。构建及两台已安装TiebaLite.debug.dylib SHA-256均为`eb85c33e1b655898183c8c8155c2e2c1b6c5eec7f697344ab26b55b966b3dbe1`，见installed-normal-hashes.json。原关注吧数据仍可见；两台打开真实高通吧首栏供手工检查。

人工脚本：在最左“最新”帖子内容区向右拖动完成返回→从原首页重进；左滑精华后右滑应回最新；向上滚动后短右拖取消应保留位置；再完成返回检查首页位置。Live未发布任何内容。

交付时状态：READY_FOR_USER_VISUAL_REVIEW（保留上述验证失败及旧系统限制）。用户于2026-09-25明确授权提交当前改动并进入R11，发布问题暂不修；按此次授权精确提交，不改写历史失败。
