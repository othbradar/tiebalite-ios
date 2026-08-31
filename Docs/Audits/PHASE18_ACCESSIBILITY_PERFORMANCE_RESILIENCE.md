# 阶段 18：无障碍、性能、内存与故障韧性审计

- 日期：2026-08-31
- 基线：`9d4d4427c1e0f5e6854886762fcc16fd23d26a37`
- Android reference：`5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`
- 标准：个人开源 Beta
- 状态：`PHASE_18_ACCESSIBILITY_PERFORMANCE_RESILIENCE = COMPLETE`
- 门禁：`PASSED_FULL_QUALITY`
- 后续阶段：`PHASE_19 = NOT_STARTED`

## 范围与实际发现

本阶段只收口既有只读主链路，没有新增业务功能或重设计页面。
实际发现并修复的问题是：

1. ThreadReader 图片和 MediaViewer 图片只读替代文本，
   没有说明当前序号/总数；打开提示还是内部实现文案。
2. MediaViewer 背景 root、可视页码和 Pager 同时暴露重复语义，
   可导致 VoiceOver 在同一视图中读到多个重叠焦点。
3. UserProfile 占位头像是纯装饰内容却可聚焦；ForumHome
   回复数据只读数字，语义不完整。
4. `network.offline` UI Fixture 只有场景名和传输配置，
   推荐列表仍直接使用成功 Fixture Repository，无法真正验证
   首屏失败→重试恢复。
5. 设置未知持久化值回退、Viewer 取消后迟到成功、以及
   真实 `UITableViewCell` A→B 复用后 A 的迟到结果不污染 B，
   实现风险较低但缺直接回归证据。

未发现稳定可复现的 P0/P1、超过约 1 秒的主线程卡死、
连续白块、重复 Cell、身份错乱或 Viewer 资源残留，因此没有修改
`VirtualizedList`、Pager、缩放/分页手势 ownership、图片缓存或 Live 协议。

## 实现结果

- 新增单一 `MediaAccessibilityCopy`，以稳定 MediaIntent 顺序生成
  “图片，第 N 张，共 M 张”；空替代文本统一回退“图片”。
- ThreadReader 成功图片 action 现在读出序号和“打开图片查看器”；
  加载/失败/取消的 value 继续由已有渲染 phase 决定，
  没有放宽失败态 MediaIntent。
- MediaViewer 只保留 Pager 作为“图片查看器”主语义，装饰背景和
  可见页码从无障碍树隐藏；关闭/上一张/下一张保持独立可执行控件。
- Profile 装饰占位头像隐藏，用户名增加 heading trait；
  ForumHome 回复统计读为“N 条回复”。
- `AppCompositionRoot` 只新增可选 RecommendationRepository 注入点；
  默认 Production/Fixture 构造不变。`network.offline` 在 UITESTING/
  TEST_SUPPORT 中注入 fail-once、retry-fixture Repository，并断言 Mock HTTP
  事件为空，不访问 Live 网络。
- 新增直接回归：未知设置值回退 defaults；Viewer 取消后
  非协作 loader 的迟到成功仍抛 `CancellationError`；真实 UITableView
  滚动促成 cell identity 复用并证明旧行迟到文本不能替换新行。

## 手工 Simulator 证据

- iPhone 17 Pro / iOS 26.5：1000 帖 Fixture 连续快速滚动并跨过
  page 1→2，可见稳定 threadID 连续、`items=200 page=2 has-more=true`；
  无卡死、连续白块或重复行。确定性 Unit 还完整加载
  10 页/1000 帖、去重并验证有界 cell 数。
- 同一 iPhone：1000 楼 Fixture 从首屏快速滚动到约 302 楼并
  跨过 200 楼分页边界，楼层/楼中楼身份连续；无稳定卡死、白块或错行。
  确定性 Unit 完整加载 5 页/1000 楼并验证虚拟化和释放。
- 三图 Fixture：左右切换、第 2 张双击放大到 2.50×、切到第 3 张
  回到原始大小；连续打开/关闭 MediaViewer 10 次后回到同一帖子，
  无重复 Viewer、状态泄漏或明显持续内存增长。
- ThreadReader 和 MediaViewer 各做一次前后台往返，原 route/
  Viewer 保持，没有重复推送；iPhone Viewer 横竖屏 chrome 完整。
- iPad Pro 13-inch (M5) / iOS 26.5：Settings 三列分栏、三图 ThreadReader、
  MediaViewer 打开/关闭、full→narrow→full 简单检查通过，无白块或遮挡。
- Simulator `Features` 菜单未提供可靠的 VoiceOver 操作入口；
  按任务约束保留自动化语义检查，不因为工具限制无限阻塞。

## 自动化与门禁证据

- 阶段 18 定向 Unit：29 个逻辑测试/30 次执行，0 失败；
  真实 cell reuse 加强回归 1/1 通过。
- 阶段 18 定向 UI：大字+深色+Reduce Motion 图片语义/
  Viewer 唯一焦点，以及无网络失败→重试，2/2 通过。
- 最终全量 Unit：351 个逻辑测试/370 次执行，0 失败；
  `20260831-205418-6709-unit.xcresult`。
- iPhone smoke：28/28；
  `20260831-205504-7157-ui-smoke.xcresult`。
- iPhone interaction：15/15；
  `20260831-211325-10046-ui-interaction.xcresult`。
- iPad smoke：12/12；
  `20260831-214610-14031-ui-smoke-ipad.xcresult`。
- iPad interaction：2/2；
  `20260831-215602-15325-ui-interaction-ipad.xcresult`。
- `make instructions`、`make secret-scan`、修正后 `make lint`、
  `make test-unit`、`make quality-fast`、`make release-isolation`、
  `git diff --check` 与 Android submodule clean 检查通过。
- 因生产 MediaViewer/ThreadContentRenderer 的无障碍投影发生修改，
  完整 `make quality` 已真实运行并通过，包含上述 Unit、iPhone/iPad
  smoke/interaction 和 Release isolation。

## 校准过程中的失败与处理

- 修复前红测试确定性复现了图片序号语义缺失和
  offline 场景不会出现失败页，2 个预期失败。
- 首次绿测试的一个 Fixture 替代文本期望写错，修正测试数据后
  定向 UI 2/2 通过，没有为此改动生产行为。
- 原 cell 测试只能证明旧结果不在新行出现，但不能证明同一 cell
  真正复用。两次加强设计试运行暴露了测试本身的不充分条件；
  最终以滚动到 20/30 行、检查同一 cell identity 和 `reuseCount > 0`
  的确定性方式 1/1 通过，没有修改生产列表。
- lint 曾分别报告 3 个新测试长度/命名问题和 1 个闭包参数
  换行问题；均只修正测试格式，最终 225 个 Swift 文件 0 违规。
- 一个只读结果统计 shell wrapper 误用 zsh 特殊变量名导致
  `xcrun`/`rg` 无法找到；改用任务专用变量后立即成功，
  不影响任何构建或测试结果。

## 变更边界

- 没有新增动画、手势、overlay、依赖、图片缓存或 Live 网络请求。
- 没有修改 `VirtualizedList`、`PagerContainer`、`MediaZoomImageView`、
  列表 identity、Session/Keychain、已验证 Endpoint 或分页协议。
- MediaViewer 和 ThreadContentRenderer 只修改无障碍投影/文案，
  没有改动 Pager transition、zoom/pan ownership 或图片状态模型。
- 没有执行 logout或删除 Keychain；日志、测试、fixture 和 Git 差异
  不包含 Cookie、BDUSS、STOKEN、完整响应或真实用户内容。

## Known Limitations

1. Simulator 无法可靠操作 VoiceOver；真机完整 VoiceOver、iOS 18.x
   和全部 iPad 型号仍是发布前人工矩阵。
2. 手工性能检查只是开源 Beta 观察，不是精确 FPS、能耗或
   Instruments 认证；由于没有稳定卡顿，本阶段没有启动 Time Profiler。
3. Production 图片 loader 仍 fail-closed，当前没有图片内存缓存，
   因此没有可清理的内存警告 cache；极端全尺寸图片压力保留发布前验证。
4. 真实 logout、所有服务端错误码、App Store entitlement 与公开分发许可
   仍按用户允许作为发布前项目，不阻塞阶段 18。
