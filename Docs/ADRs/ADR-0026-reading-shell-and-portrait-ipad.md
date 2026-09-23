# ADR-0026：阅读页根底栏与 iPad 竖屏投影

状态：Accepted（2026-09-23 用户明确要求）；实现仍须 R05 人工验收。

## 原因与决策

Android 主页面自己的 bottom navigation 不属于 Forum/Thread destination。当前 iOS 将 selector 无条件附在 TabView，造成阅读页占位；iPad 只看 regular size class，导致竖屏仍并排三列。

1. 仍以现有 TabView + NavigationStack 保存各根路径。当前选中根的 canonical route chain 包含 Forum、Thread 或 Subposts 时，不构造底部 selector，也不留下其 safeAreaInset 空间；阅读后的作者等子页继承该状态。历史 settingsPath 中 content route 同样适用。其他根保留原行为，不增加可写 visibility Bool。
2. 窗口宽大于高且 horizontalSizeClass 为 regular 时，使用既有三列 NavigationSplitView；其余使用既有 compact 完整栈。几何输入来自当前容器，包含其安全区，不使用设备型号、UIScreen 或设备朝向全局通知。竖屏 iPad 与窄分屏遵循单页行为；横向 regular 保持原三列。
3. 投影仅派生显示，不修改 route、Store key、分页、阅读 anchor 或 Session。系统 back / edge swipe 仍驱动原路径。没有新 Pager/列表容器、手势、动画或 overlay。

## 风险、验证与回滚

验证原实现连续三轮显示问题，再检查隐藏底栏后的实际列表底边、返回恢复、四根切换、iPad 三轮竖横往返的选中标签/深层 Thread 返回与 Store identity。键盘不能误触发投影切换。路径状态与显示布局分离，UI 元素显示应匹配有效投影而非原始 size class。

替代方案：只在 Feature 加 toolbar(.hidden, for: .tabBar) 无法控制自定义 selector；opacity/透明遮挡仍占空间；另建 iPad portrait 路径产生双重真相，均不采用。

回滚只撤回 App Shell 展示策略和此交互约定；不清缓存、用户数据或导航存储。此决策补充 ADR-0003/0022 的显示条件，不替换其 canonical state、root 重选 no-op 和恢复语义。


## 2026-09-23 底边补充（用户明确要求）

用户指出吧/帖子仍有固定白条，iPad 横竖屏同样存在。短 Fixture 回归量到三次阅读表格底边与窗口底边相差 34pt；这是系统导航内部的阅读目的页将 UIKit 滚动视口限制在 bottom safe area 上方，和已移除的根导航按钮不同。

.ignoresSafeArea 放在 Shell 外层无效；在 AppRouter 的 Forum/Thread 阅读目的页，以及 ForumHomeView 给独立 Pager host 提供的页面内容上使用 `.ignoresSafeArea(.container, edges: .bottom)`，允许滚动视口延伸到 Home indicator 区域。作为用户明确要求的阅读视口例外，顶部/键盘安全区仍保留，非阅读根页面不忽略底部安全区；不修改 UITableView、Pager、Cell、图片/Session 或手势实现。视觉判据改为视口底边与窗口相差不超过 1pt；不以额外色块、负 padding 或固定高度掩盖。

## R06 的实际回复条

R06 提示词明确要求真实 bottom safe-area composer。ThreadReader 从无底部控件改为紧凑回复条时，移除 AppRouter 对该目的页的底部忽略，使用系统 safeAreaInset 保证按钮在 Home indicator 上方；列表紧贴回复条上沿，不能在二者间残留白区。吧页继续延伸到底边。R05 短测试的帖子目标边缘因此改为回复条上沿（<=1pt），吧页仍为屏幕底边；没有放宽容差或修改共享列表。
