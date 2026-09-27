# R12 导航栏转场方块：证据与居中标题方案

2026-09-27：用户明确反馈“居中就居中，反正bug确实修好了，就按这个来”，批准采用第二个居中标题候选。仅本缺陷的居中方案获准；R12 整体仍待复核，不提交、不进入 R13。下文保留此前诊断和被放弃的备选方案。

## 用户反馈与复现

- 从帖子右滑返回吧首页，左上返回按钮上出现方块，等一会消失。
- 从首页吧选择列表进入吧首页，“首页”先变方块，再变返回按钮。
- 用户进一步指出：帖子页返回键右侧“吧头像＋吧名”移动到返回键位置，形成该方块。

环境：iPhone 17 Pro Simulator（70D93841…），iOS 26.5、Xcode 26.6、竖屏浅色、正常字号。完整 Debug Live App，保留现有登录。首次引入版本/最后无问题版本 UNKNOWN，未用旧提交冒充对照。

录屏 `Artifacts/VisualReview/R12/BackButton/live-baseline.mp4` 与逐帧图 `frames/changes-01.jpg`、`changes-02.jpg` 确认上述两条 Live 路径。返回结束后静态按钮正常，所以等 XCTest idle 再截一张图会漏掉问题。三次帖子返回的隔离 Fixture 测试两轮均通过功能断言，**不是视觉通过证据**；Fixture 的顶部 Harness 还遮住一部分导航栏，不能用它替代完整 Live 转场检查。

## 已确认边界与尚未证实部分

可见问题位于系统导航栏项目之间的变形转场：静态信息放在 `.topBarLeading`，在转场中和系统 back item 相匹配，其矩形快照边界过渡到圆形背景，产生用户看到的方块。不是帖子图片、列表 Cell 或回退后永久残留的一块业务 View。

Apple 的公开 `UIBarButtonItem.identifier` 文档和 Xcode 26.6 SDK 头文件说明：缺少显式身份时，系统根据位置/内容启发式匹配 bar items。LLDB 只读检查公开导航 item 属性，确认 SwiftUI `ToolbarItem(id:)` 的字符串确实进入 UIKit item；但原生 backBarButtonItem 仍为 nil。**没有证明只给 back item 设置 identifier 就一定能修好**，需在下一方案中做小范围验证。

来源：[Apple UIBarButtonItem.identifier](https://developer.apple.com/documentation/uikit/uibarbuttonitem/identifier)。Android 对照为锁定 UI reference c5f1125 的 ForumPage.kt 与 Android-target/05-forum-home.png；保留平面信息、既有左侧标题位置和系统返回行为。

## 两次尝试与撤回

1. 给首页/帖子两个 SwiftUI ToolbarItem 添加不同稳定字符串 ID：构建成功，`live-identifiers.mp4` 及用户新图仍有同样的变形方块，失败。已撤回。
2. 改用 `.principal` 标题区域，并尝试 leading frame：构建成功，录屏显示原按钮匹配路径改变，但 SwiftUI 仍按标题的固有宽度居中首页/吧名，违反原有靠左布局；未完成三轮及 iPad 验证，不能交付。已撤回。

记录未成功的两次 LLDB 表达式编译（Objective-C 的 windows 类型/childViewControllers 名称），随后公开属性检查成功；没有读取 Cookie、Keychain 或会话内容，也没有通过 LLDB 改 App 状态。

按 ios-root-cause-debug 第 11 条停止第三次补丁。只撤回本次两个 View 的试验行；保留进入本轮前完整 R12 候选及用户文件，不对全仓 reset/restore。`pre-revision.patch` 和 `restored.patch` 对照记录恢复边界。保留新增短 UI 回归源文件和全部录屏。

## 已放弃的备选组件方案（不实施）

以下是用户确认居中之前整理的备选，现无需实施或再次申请许可。

目标：保留首页头像/文字靠左、帖子吧 chip 紧邻返回键、原生 back 按钮及完整系统交互返回；给原生返回项与静态信息提供明确、分开的导航栏身份。

拟新增一个局部 `InteractionKit/Navigation` UIKit 适配器（UIViewControllerRepresentable），仅在相关页面挂载：

- 保留原有 SwiftUI leading 内容与布局，不创建自绘 back Button。
- 通过公开 `UINavigationItem.backBarButtonItem` 为下一级的原生返回项提供稳定的专用 identifier；不设置自定义 target/action/customView，不隐藏系统返回键。
- 首页信息与帖子吧 chip 使用各自稳定 identity，与原生 back identity 分离。先检查 UIKit 实际属性及同一 Live 路径录屏，验证是否停止不相关项目的匹配，不能只靠 API 文档下结论。
- 适配器只定位自身所在导航页的 owning controller，不扫描/修改其他窗口或全局 UIAppearance。attach/viewWillAppear 时幂等配置；保存原值；拆除时仅在属性仍由自身持有时恢复。不能因 SwiftUI 更新、图片完成、分页或一次布局反复替换 item。
- 不安装或替换导航 delegate/手势，不做自定义 push/pop 动画，不用延时、遮罩、关闭动画或取消交互返回来规避问题。
- 若 native back identity 不足以控制匹配，保留失败证据并停止；不继续盲目添加背景/clip/透明按钮。

范围：上述小型适配器、首页/吧/帖子最少接入点、生命周期 Unit、现有返回 Smoke 与 R12 文档。禁止修改 VirtualizedList、Pager、MediaViewer、Store、Session、图片缓存和路由业务 identity。现有 iPad 详情残留为独立问题，本方案不顺手修改。

验收：

1. 正常动画速度的完整 App，首页→吧→帖子→内容区右滑→吧，连续三轮逐帧确认没有标题/吧 chip 变形为返回键或矩形残留。
2. 保持标题靠左及 chip 紧邻原生 back；保留 R06 顶部 chip 不随楼层滚动的断言。
3. 点击返回、边缘返回、内容右滑和取消返回都维持原页面/滚动位置；吧其他标签仍切页。
4. 局部 lifecycle Unit、R12BackButtonSmokeTests、R06 固定标题短 Smoke、ForumContentBackGestureTests；iPad 竖屏一次同路径及横屏标题检查。只相关验证、lint/build/secret/diff，不跑全套质量矩阵。
5. 完整 Live 覆盖安装、不卸载、不清 Keychain；同一吧页面留给用户看，只有实际通过才输出 READY_FOR_USER_VISUAL_REVIEW。

## 最终采用：居中标题（用户明确批准）

- 只改 FollowedForumsView 与 ThreadReaderView 两个 toolbar item 的 placement 为 `.principal`。首页头像/标题与帖子吧头像/吧名由系统标题区域承载，按用户最新选择居中。
- 导航栏标题不再作为左侧 bar button 参加和原生 back item 的匹配；原生返回键、系统 push/pop、边缘/内容右滑均保留。没有 UIKit 新桥接、全局样式修改、动画关闭或命中遮罩。
- 保留 UI 回归 `R12BackButtonSmokeTests`，三次帖子内容返回检查真正回到吧页、标签不变、原行位置差不超过 2pt、返回键可点，最后返回首页。它验证行为；瞬态视觉依赖 Live 录屏及用户已确认结果。
- 相关 R06 标题固定位置测试和原有取消返回/其他标签横滑测试保持原断言。R06 的“位于返回键右侧”仍检查几何关系，并不要求标签紧贴返回键。
- 未新增 Unit：本次最终生产变化只有两个静态 toolbar placement；不重复全量状态/图片/媒体测试。最终执行结果见下节。

## 最终验证与安装

- iPhone：3/3（73.829s），`final-phone.xcresult`；R12 返回三轮、R06 标题固定、Forum 原取消/其他标签/边缘返回测试。
- iPad：1/1（16.417s），`final-ipad.xcresult`；竖屏对应 R06 标题固定测试。本缺陷未另跑 iPad 横屏转场矩阵，不冒称已覆盖。
- `make lint` 0 violations/371 files、`make build`、`make secret-scan`、`git diff --check` 均通过，`*-final.log`。不跑全量 Unit 或 quality。
- 两台普通 Debug 完整 App 覆盖安装，无测试启动参数、无卸载/erase/Keychain 清理；主程序和 debug dylib 与本次 build SHA256 一致（`live-install-final.json`）。
- Live 截图 `iphone-live-home-final.png`、`iphone-live-thread-final.png`、`iphone-live-forum-final.png`、`ipad-live-home-final.png`；瞬态证据 `live-final.mp4` 与 `fixture-final.mp4`。用户已明确确认本缺陷修复并接受居中。最终 iPhone 留在耐腐蚀艺术馆吧，iPad 留完整 Live 首页。
- 无新增手势、动画、overlay、依赖、导航适配器；不触碰列表/图片/Session。先前独立 iPad 详情残留仍按 R12_ACCEPTANCE 保留，用户未批准整个 R12，不暂存/提交、不进入 R13。
