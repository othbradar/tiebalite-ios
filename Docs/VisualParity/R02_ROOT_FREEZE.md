# R02 根导航无响应修订

状态：`FOLLOWED_BY_APPROVED_LIST_REDESIGN`。下文是两次局部候选撤回后的诊断记录；用户现已批准最小承载修订，当前工作树重新复现和实施验证见 `R02_LIST_REDESIGN_ACCEPTANCE.md`。未提交、不进入 R03/R04。

## 用户原始反馈

> iPhone17模拟器tieba lite app我点了几下根导航按钮现在app卡死了

补充确认：“滑动后切换底栏”。

## 初始证据

- 当前工作树为 R01/R02 未提交实现，全部保留；R02 原静态/单元和浅层 Shell Smoke 为绿色，但不覆盖本次深滚动路径。
- iPhone 17 Pro / iOS 26.5 / macOS 26.6，Debug 生产组合根；冻结进程 PID 63417 持续约 100% CPU，79.5 MB 物理 footprint。
- `Artifacts/VisualReview/R02/RootFreeze/before-freeze.png`：停在动态列表中部；两份 `user-freeze*.sample.txt` 都显示主线程持续进行 SwiftUI LazySubviewPlacements / LazyStack / AttributeGraph 布局。
- 当前仅能定位到动态列表布局循环；还不能把 Tab 状态、网络或某个内部系统函数声明为唯一根因。没有抓取凭据、响应正文或进程内存。
- 采样保留后重新启动同一 App 以复现，未卸载/清缓存/清 Keychain。重启后首页/动态可加载、进程空闲，仅是复现准备，不视为修复。`idle-after-relaunch.sample.txt` 记录正常空闲对照。

## 验收行为

固定 Fixture 中滚动到第三页，再依次切消息/我的/首页/动态，保留可见业务行与滚动位置；回滚到顶部，每次执行重复 2 轮，最终重复运行 3 次，最后消息入口仍可立即打开。新回归 `R02RootShellSmokeTests.testDeepDynamicScrollAndRepeatedRootSwitchesStayResponsive` 先在未修复实现执行。

计划只修复触发布局循环的根因，保留四项导航、现有业务数据/identity、唯一媒体 cover 与已验证的列表/交互基础设施；不做 R03/R04 视觉改造。最终按定向 Shell、Unit、lint/build（或 quality-fast）验证，覆盖安装同一 Simulator 并重新截图。

## 对照与已排除路径

- 原 1x1 色块 Fixture：3 轮滚动/切换断言通过，未复现布局卡死；测试本身耗时 123 秒超过新设 120 秒 allowance，runner 结束阶段超时（命令 exit 65）。为保持有界短测试，每次改为 2 轮、保留 120 秒限额，后续重复运行，而非增加等待限额。
- 非正方大图原始 bytes Fixture：2 轮通过（baseline-mixed-media.xcresult，exit 0）。
- 加长昵称/吧名/回复数触发可变元数据：2 轮通过（baseline-mixed-metadata.xcresult，exit 0）。
- 去掉测试专用 GeometryReader/顶部布局控制，采用生产 AppSceneRoot 的根几何：2 轮通过（baseline-production-geometry.xcresult，exit 0）。这使回归覆盖真实根容器，但根容器差异本身尚未证明为根因。
- Fixture 复用 ProductionImageLoader 的缩略图解码、尺寸与缓存路径后，连续两次在第二次上滑时卡死（baseline-production-loader、red-production-loader-repeat，均 exit 65 / 120 秒限额）；CPU 约 100%，两份 fixture-production-loader*.sample 与现场同样集中于 LazySubviewPlacements / AttributeGraph / SizeFitting。只将传输替换为固定内存图片，不创建第二套生产图片系统、不访问网络。
- 初次 diagnostic-lint 发现新 Fixture 三元素 tuple 超限（exit 2），已改为具名 Sample 结构，未放宽 lint。

## 已撤回的缩略图尺寸尝试

- 单一橙色图片 338 pt 宽的尺寸测试通过；扩展到 3 张图 × 5 种宽度后，发现加载态/已加载态存在 1～2 个物理像素偏差（red-state-geometry，exit 65）。最初额外检查未对齐像素的理论高度会误报正常取整，改为严格比较三种状态的实际测量尺寸，并重新运行红测。
- 第一次候选修复让 GeometryReader 独立决定外框；15 个尺寸用例通过（fixed-state-geometry，exit 0），但完整深滚动仍在同一位置 CPU 100% 卡死（geometry-attempt.sample）。停止剩余重复执行，命令被中断 exit 73（fixed-deep-scroll-repeat），不能记作绿色。
- 因它未解决用户反馈，已撤回这个候选生产修改及专用尺寸测试；代码/测试副本保留在忽略的 Artifacts 中用于说明排除过程。没有回退或覆盖用户原有 R01/R02 工作。
- 对照缩短 Fixture 元数据仍在同一滚动点卡死，排除“长昵称/吧名”单独作为根因；测试数据已恢复长短混合。
- 第二次候选修复仅将 ContentSummaryCard 的 ViewThatFits 替换为同一组标签的无状态自定义 Layout，保留原横排/竖排语义。完整深滚动仍在第二次上滑卡住（metadata-attempt.sample），CPU 约 100%。采样中的 SizeFitting 分支消失，但 LazySubviewPlacements / GraphHost.flushTransactions 持续循环，排除 ViewThatFits 单独作为根因。停止剩余重复执行，命令被中断 exit 73（metadata-layout-deep-scroll）；该候选已完全撤回，ContentSummaryCard 对 HEAD 无差异。

## 当前结论与停止条件

问题属于布局/列表承载类。已确认触发链为生产图片解码后的动态 Row → 深滚动进入 SwiftUI lazy placement 持续循环 → 主线程无空闲 → 根 Tab 无法响应；不是登录失效或根按钮点击范围问题。没有证据支持把其中某个 SwiftUI 私有函数、图片像素取整或元数据分支宣布为唯一根因。

已达到 ios-root-cause-debug 技能第 11 条的两次失败停止条件；未增加第三个局部补丁。仅保留离线回归场景、UI 测试和诊断记录，原 R01/R02 工作保留。承载方案列出每个拟修改文件、现有 VirtualizedList 回调适配、稳定 ID 与验证出口，等待用户审查；不是已实现修复。

## 本轮主要执行记录

| 命令/产物（均在 Artifacts/VisualReview/R02/RootFreeze） | 实际结果 |
|---|---|
| baseline-deep-scroll | 原始 3 轮断言通过，123 秒超过 120 秒限额，runner exit 65；不是现场卡死 |
| baseline-mixed-media / baseline-mixed-metadata / baseline-production-geometry | 各 exit 0；原始 bytes 图片对照 |
| baseline-production-loader / red-production-loader-repeat | 各 exit 65；120 秒限额，第二次上滑必现主线程卡死 |
| diagnostic-lint | exit 2；测试三元素 tuple 超限，改具名结构后 lint 通过 |
| red-geometry | exit 0；单一图片尺寸不足以反映偏差 |
| red-geometry-matrix | exit 65；包含正常像素取整误报，校正测试后再次红测 |
| red-state-geometry | exit 65；三种状态在 15 用例中有 12 项尺寸断言失败 |
| fixed-state-geometry / fixed-lint | exit 0；候选一仅通过局部尺寸测试与 lint，未修复整页 |
| fixed-deep-scroll-repeat | exit 73；候选一仍卡死，采样后中断余下重复 |
| diagnostic-short-metadata | exit 65；缩短元数据仍卡死，测试数据已恢复 |
| metadata-layout-lint | exit 0；候选二 lint 通过 |
| metadata-layout-deep-scroll | exit 73；候选二仍卡死，采样后中断余下重复 |
| final-diagnostic-quality-fast | exit 2；旧静态规则将测试场景的生产解码器一律视为 Live 可达 |
| fixed-diagnostic-isolation | exit 0；精确登记唯一固定内存 transport 构造，其他生产构造/真实网络仍拒绝，并保留拒绝 canary |
| final-diagnostic-quality-fast-2 | exit 0；生成/静态/lint/build/entitlement 与全部 Unit 通过；402 个逻辑测试 / 434 次执行，0 失败/跳过 |
| make build → final-diagnostic-build.log | exit 0；恢复 Debug Simulator 产物 |
| simctl boot / bootstatus → final-boot.log | exit 0；Unit 后重新启动 iPhone |
| simctl install / launch（iPhone/iPad 各一次） | 全部 exit 0；直接覆盖安装 Debug，同一 bundle，无卸载/erase/Keychain 清理 |
| simctl io screenshot（iPhone/iPad 各一次） | 全部 exit 0；已实际打开并检查两张截图 |
| git diff --check / 受保护目录 diff --quiet | exit 0；无空白错误或共享列表/交互基础设施差异 |

未将诊断候选的绿色 Unit/lint 等同于修复通过；新增深滚动 UI 回归仍是已知失败。

## 保留的改动与不变量

- TestSupport：新增 root.mixed-media 场景、固定非正方图片及长短混合元数据；在原生产图片 Loader 中仅注入内存 HTTPDataLoading，候选 URL 固定为 root.fixture.invalid。新增 Unit 证明即使输入外部候选地址也只获得固定解码结果，不触发场景 HTTPClient。
- App：仅 UITESTING 分支为此场景直接使用生产 AppSceneRoot 几何，避免旧测试顶部布局控制改变复现条件；Debug/Release 业务路径不受影响。
- UITests：新增深滚动、四 Tab、稳定业务行/返回位置回归；保留 120 秒失败边界，不加 sleep 或放宽断言。
- scripts：网络边界按精确路径/构造允许测试用生产解码器，禁止默认生产工厂、真实 Session/网络和 Keychain 访问；其他场景仍禁止生产解码器。
- 无新增动画、手势、overlay 或依赖。VirtualizedList、ThreadReader、ForumHome、Pager、MediaViewer、生产图片 Loader、ContentSummaryCard 均已核对无本轮差异；R01/R02 用户工作未丢弃。没有 commit/push。

下一步前置条件：用户审查并确认承载提案后，才实施该组件范围调整；不能输出 READY_FOR_USER_VISUAL_REVIEW 代表本次 Bug 已通过。

## 当前 Simulator

两台均覆盖安装 `.build/DerivedData/Build/Products/Debug-iphonesimulator/TiebaLite.app` 并停在首页，iPhone 17 Pro 在前台。iPhone 原 Live 登录态仍有效，首页真实关注列表可见；iPad 保持原未登录状态。重启恢复首屏只为交还可操作环境，卡死修复尚未完成。

- 修订前冻结现场：`Artifacts/VisualReview/R02/RootFreeze/before-freeze.png`。
- 当前 iPhone：`Artifacts/VisualReview/R02/RootFreeze/iphone-restored-home.png`。
- 当前 iPad：`Artifacts/VisualReview/R02/RootFreeze/ipad-restored-home.png`。
