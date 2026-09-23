# ADR-0022：Android parity 四项根导航

- 状态：Accepted；2026-09-23 用户视觉验收通过（此前自动化失败记录保留）
- 日期：2026-09-23
- 决策来源：用户要求进入 R02_ROOT_SHELL_PARITY
- 扩展 ADR-0003、ADR-0021；不改变现有业务 identity、列表或媒体架构。

## 问题与证据

旧 Shell 三项“推荐/关注的吧/设置”与 Android MainPage 的 home/explore/notification/user 不一致。锁定 UI commit c5f1125f42498e49db4e4a9cb66313b8c8a285c7 的 MainPage.kt 禁用根 Pager 用户横滑；NavigationComponents.kt 底栏是 24dp 图标、无文字、零 elevation。用户提供的四张根页面截图也体现这一结构。

## 决策

1. 保留 RootID.recommendations / followedForums 以及原 settings identity；只调整 AppTab 顺序和显示映射为首页/动态/消息/我的，新增 notifications。默认选择 followedForums（首页）。Deep link 仍进 recommendations（动态），不迁移已有 ID。
2. 沿用已有 TabView + NavigationStack + safeAreaInset selector，重选 no-op。iPad 继续 NavigationSplitView，不增加第二份业务 Store 或选择状态。消息暂无子 route，使用独立静态根栈，不能误投影 settingsPath。
3. “我的”沿用 settingsPath。新增 preferences 作为真实设置页；可前缀于既有 history/about/licenses/Debug routes，最大深度由 4 扩展为带单个 preferences 的 5。新增 accountProfile 明确的暂不可用入口。Session 仅有 credential/lease、无本人 userID；R02 不新增账户接口或伪造用户身份。
4. 组合根注入 NotificationCountSource。Production 使用不可用的零计数源，Fixture 可注入可观察的 3。Shell 只显示计数，切换不标记已读、不发请求。R11 可替换计数源。
5. 复用 Android 通用导航矢量资源的静态两端形状，不移植动画。iOS 26 根 toolbar 按系统公开 API 隐藏 shared background；保留系统导航、安全区和返回手势。
6. 首页/动态仅改变根标题，动态去掉多余品牌大字；列表视觉仍由 R03/R04 处理。“我的”仅入口骨架，完整资料布局由 R12 处理。

## 候选与取舍

- 重命名全部业务 RootID：无必要且增加恢复、Store key 和跨阶段回归风险，放弃。
- 用一个全局栈：会导致跨 Tab 返回污染，放弃。
- 新增一套 Pager 或自定义返回：超出范围，放弃。

## 验证与回滚

定向 Unit 验证默认项、顺序、原 identity、路径/Store/anchor 保留和 badge 注入；iPhone/iPad Shell Smoke 验证四页、返回链和唯一 MediaViewer。用户视觉批准前不提交。回滚只撤销 R02 Shell/入口/资源增量，保留 R01 和全部生产列表/媒体基础设施。
