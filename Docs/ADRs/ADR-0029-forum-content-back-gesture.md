# ADR-0029：吧首页首栏内容区右滑返回

状态：用户明确要求并于2026-09-25授权提交；定向验证通过项及保留的失败见 FORUM_CONTENT_BACK_GESTURE.md，不将提交授权视为所有自动化通过。

## 问题与边界

用户确认希望从帖子内容区右滑返回，而不局限于屏幕边缘。R10 基线 3744d4b 的 forum.parity 样本连续三次右滑均未返回，baseline.xcresult 保留。当前最左栏为“最新”；非首栏右滑仍应翻到前一栏。首栏左滑、纵向滚动、取消返回及系统左边缘返回均须保持。只处理吧首页，不进入 R11。

仅观察手势状态的第二次复跑仍三次失败（diagnostic.xcresult）。每次实际 UIKit Pager pan 从 began(1) 到 ended(3)，committed ID 为首项，导航栈深度为2，但系统 content-pop 为 failed(5)。确认并非 XCTest 未命中，也不是栈无上一级：原实现缺少首栏返回的手势优先级，有限页 Pager 在边界接管右滑并回弹，使系统返回失败。原始 stdout 已导出 diagnostic-export；临时探针在交付前移除。

## 决策

复用 iOS 26 公开的 UINavigationController.interactiveContentPopGestureRecognizer；SDK 规定该属性只用于建立 failure requirements，不接管其 delegate/target/isEnabled，不调用私有 API，不另造转场。iOS 18–25 保持系统边缘返回，不降低部署版本，也不以自定义全局返回模拟新 API。

在唯一 PagerContainer 增加默认关闭的首栏返回选项，仅 ForumHome 开启。局部仲裁使用一个不执行导航的 pan gate：非首栏横向输入让 content-pop 等待/失败，并允许原 Pager 识别；首栏 gate 失败，由系统 content-pop 与原 Pager 的 failure requirement 决定归属。系统边缘返回优先于二者。gate 仅安装在 Pager 内容视口，不覆盖标签栏或兄弟页面，不取消控件点击，不更换系统/Pager recognizer 的 delegate。

边界值在新手势开始时读取稳定 committed PageID/ordered IDs；转场中不移交，不修改业务 selection、route、Store 或列表。当前容器存在可返回的系统导航栈时才安装；重复布局安装幂等。detach 移除自身 gate/delegate/闭包；Pager 和 MediaViewer 原状态机、observer、缓存及复用契约不变。MediaViewer 不启用此选项。

## 替代方案、验证、回滚

- 不采用关闭整个 Pager、全屏 DragGesture、替换系统手势 delegate、私有 target 转发或另建导航转场。
- 验证原三次失败回归、非首栏前一页、首栏左滑、短拖动取消、纵向滚动、边缘返回、iPad 竖屏返回/横屏及宽度变化，并跑相关 Pager Unit/短交互与 lint/build/secret/diff。
- 两次修正仍失败时保留失败结果并停止，不扩大到共享列表/根导航。回滚只撤销本选项、局部桥接和 Forum 调用；不重置数据或凭证。

API 依据：本地 Xcode 26.6 UIKit UINavigationController.h:84–91；[Apple API](https://developer.apple.com/documentation/uikit/uinavigationcontroller/interactivecontentpopgesturerecognizer)、[WWDC25 284](https://developer.apple.com/videos/play/wwdc2025/284/) content backswipe 说明。Android UI c5f1125 的 ForumPage 使用 LazyLoadHorizontalPager（LazyLoad.kt 委托 Compose HorizontalPager），未在该组件实现自定义返回；本次首栏内容区返回的产品要求以用户明确指令为准。
