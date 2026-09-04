# 阶段 19B 本地 Beta Release Candidate 审计

## 范围与基线

- 基线提交：`55baab43dae829ef7e0000f929ab4b804403ac52`
- 目标：核对已有只读主链路，只关闭稳定可复现的 P0/P1，形成可从
  干净 checkout 构建的本地 Beta Release Candidate。
- 非目标：不增加写操作、完整楼中楼页、离线下载、动图框架、新 Pager/
  MediaViewer/列表框架，不扩大为发布级设备矩阵。
- Android reference 前后均 clean，锁定
  `5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`。

## 终审发现与最小修复

### 1. Release Fixture 隔离假绿

`CODE_EVIDENCE`：Release target 之前仍编译纯 Fixture Repository/路由占位，
`.subposts` 生产路由还使用 `FixtureRouteView`，隔离脚本未覆盖这些符号。

最小修复：

- Release 精确排除七个纯 Fixture 源文件，但保留承载生产领域模型的
  `FixtureReadingFlow.swift`；
- Fixture 默认 Store 构造移入 `TestSupport`，Production registry 必须显式注入；
- Debug gallery route、Fixture route ID、LaunchScenario 实现继续由编译条件或
  Release source exclusion 隔离；
- 生产 `.subposts` 改为如实说明 Beta 仅支持内联楼中楼预览的
  `SubpostsUnavailableView`；
- 隔离脚本新增 source list、Mach-O 符号、本机路径和 AppIcon 正反控制。

### 2. 干净安装未登录首页语义缺失

`RUNTIME_EVIDENCE`：修复前 `session.signed-out` 的 Live composition 未出现安全的
登录引导，定向 UI 回归失败：
`stage19b-signedout-red-2.xcresult`。

`ROOT_CAUSE`：默认推荐是需要 active AuthContext 的 Live Repository，但 App 根
直接展示 `RecommendationsView`，没有把 `SessionState/AuthContext` 投影成未登录、
登录中和过期页面状态。

最小修复是在 App 组合边界增加 `RecommendationsAppRootView`：Fixture 路径保持
原行为；Live 只在 `signedIn + active AuthContext` 时加载推荐，其他会话状态
展示一致背景、状态文案和可执行登录操作。绿灯 UI 回归为
`stage19b-signedout-green-4.xcresult`，3 次执行全部通过；将生产
access policy 与 Fixture transport 隔离后，最终定向结果
`stage19b-signedout-isolated-green.xcresult` 为 1/1 通过。

### 3. 会话替换仍可复用旧推荐数据

`CODE_EVIDENCE`：`AppFeatureStoreRegistry` 在会话 A →退出/过期 →会话 B 期间
保留同一 `RecommendationsStore`，原有 `hasCompletedInitialLoad` 会让 B 直接
沿用 A 的内容、分页和滚动锚点；迟到的 A 请求也可能在会话撤销后继续
完成。

修复前先新增两条会话作用域回归，首次 `make test-unit` 因尚无
`RecommendationsStore.synchronize(with:)` 编译失败，红灯日志为
`stage19b-session-scope-red.log`。最小修复引入 `active(lease)` / `fixture` /
`unavailable` 作用域；作用域变化时取消任务、递增 generation，并清理
内容、页码和锚点。App 只在 Store 已同步到当前 lease 后挂载推荐页，
因此不会短暂展示前一账号的内容。两条回归最终全部通过。

### 4. Release 携带 Pager 纯调试快照 API

`BUILD_EVIDENCE`：扩展 Release 反向 canary 后，`make release-isolation`
确定性失败，命中 `PagerContainerSnapshot` / `PagerGeometrySnapshot`、
debug environment key 和 snapshot callback 符号；红灯日志为
`stage19b-pager-release-isolation-red.log`。

最小修复用 `#if DEBUG` 隔离快照类型、环境键、诊断观察者/计数器和
callback；Release 事件仅保留生产需要的 began/completed 语义。手势所有权、
rendezvous、页面身份、缓存窗口和转场提交策略未改。实现中一次
`make test-unit` 因 Swift 不允许在 initializer 参数列表中以该形式交错
条件编译而失败；改为完整 Debug/Release initializer 分支后，Unit 与
Release isolation 均通过。随后独立二进制复审又确认
`PagerResolvedInputDiagnostic` 仍被 Release 保留；最终移除该中间类型，
将 `PagerInputDiagnostic` 定义收窄到 Debug，并把两类符号加入 Release
canary。

### 5. 同一会话下推荐投影重挂会误取消请求

`RUNTIME_EVIDENCE`：新增的会话包装层直接 `await store.synchronize`，
SwiftUI 因 iPad regular/compact 投影替换取消 View task 时，会继续通过
Store 的 caller-owned cancellation handler 取消共享请求。使用真实
`RecommendationsAppRootView` 的确定性重挂回归在修复前失败，结果包为
`20260901-162234-66207-unit.xcresult`。

最小修复捕获当前 access scope，以独立 MainActor Task 持有 Store 请求；
旧 View task 取消后不再传播到共享 load，且只有未取消并仍匹配同一
scope 的包装层可以写回同步状态。lease 真正变化时仍由 Store reset
主动取消并递增 generation。修复后完整 Unit 结果包
`20260901-162412-71969-unit.xcresult` 为 379 个逻辑测试/403 次执行，
0 失败。

### 6. 同一会话返回推荐列表会丢失精确位置

`RUNTIME_EVIDENCE`：新增的会话包装层在同一 access scope 的 View
重现时也先把 `synchronizedScope` 置空，导致原有推荐
`ScrollView` 被 loading 根视图短暂替换。Store 中的稳定 threadID 锚点能
恢复大致项目，但无法恢复原始像素偏移，因此帖子返回和分页返回
流程都会稳定跳位。两条失败用例分别独立重复 3/3 红灯。

最小修复只删除同 scope 重现前的该次置空；真正 scope 变化仍由
Store 的 reset 取消旧请求、递增 generation 并清理数据/页码/锚点。
修复后两条返回位置用例分别独立 3/3 绿灯，会话/投影定向
Unit 通过，iPhone smoke 最终 28/28。没有修改列表承载、稳定
identity 或滚动恢复算法。

### 7. RC 资源与仓库卫生

`CODE_EVIDENCE`：基线没有 AppIcon；Git 跟踪 `.idea`/两个 `.DS_Store`；历史审计
包含本机绝对路径和 Simulator UDID。

最小修复：

- 新增本轮新生成、无文字、无百度官方商标的 1024×1024 不透明 AppIcon，并由
  asset catalog 同时生成 iPhone/iPad 图标；
- 从 Git index 精确移除 `.idea` 和 `.DS_Store`，本机文件保留；
- 将审计中的私有绝对路径/UDID 替换为 `<repo-root>` 和匿名设备描述。

## 功能与运行证据

### iPhone Live

`RUNTIME_EVIDENCE`：在保留现有 Keychain 的 iPhone 17 Pro / iOS 26.5 Simulator 上覆盖
安装 Debug 构建，未执行 logout，未读取或记录凭据：

- 冷启动恢复登录会话；推荐返回非空内容，连续分页能力沿用阶段
  15.6 已验证的 Live 第二页协议和当前回归；
- 关注吧 Live 返回 18 个条目；打开真实吧首页、置顶/普通帖和后续页；
- 打开图片长帖，帖子至少达到第 55 楼（超过三页请求）；
- 打开三张不同 Live 图片，完成切换、2.50× 双击缩放、旋转、关闭并返回
  原帖位置；
- 使用一个普通非敏感关键词搜索时首次出现普通网络失败，点击一次重试后
  成功；吧/帖结果
  均能进入现有页面，返回保留关键词和结果；
- 历史显示 5 条；外观切到深色后立即生效，随后恢复“跟随系统”；
- 打开 Live 用户资料页；前后台往返后会话和页面状态保留；
- 未观察到稳定白块、错页、串图、重复 Viewer 或超过约 1 秒的主线程卡死。

`NOT_TESTED`：本轮没有修改宿主 macOS 网络开关；无网失败与重试由
`network.offline` 确定性 UI scenario 和 transport Unit 覆盖。

### iPad 与自适应

`RUNTIME_EVIDENCE`：iPadOS Simulator 的 Fixture/UI 主链路覆盖推荐、吧首页、帖子、
MediaViewer、搜索和设置；阶段 17/18 已执行 full → narrow → full 容器变化。
本阶段的 iPad smoke/interaction 也已在阶段出口 `make quality` 重验。

`NOT_TESTED`：iPad Simulator 没有复制 iPhone 的真实 Keychain，也没有要求用户重新
登录，因此本轮 iPad 验收不声称 Live 账号链路。

### 长列表与 MediaViewer

`TEST_EVIDENCE`：当前 Unit 仍确定性验证 10 页/1000 帖和 5 页/1000 楼，稳定
业务 ID、增量 diffable snapshot、有界 cell 数与复用后迟到文本/图片不污染
新行。

`RUNTIME_EVIDENCE`：阶段 18 在同一生产承载上快速滚动了 1000 帖/1000 楼 Fixture，
并连续打开/关闭 Viewer 10 次；阶段 19A/19B 未修改 `VirtualizedList`、
Media zoom/gesture ownership、diffable identity 或 Renderer 核心结构。Pager 仅在
19B 对纯调试快照 API 做 Release 条件编译隔离，生产交互算法不变。

## 头像决策

`CODE_EVIDENCE`：现有部分 Proto 保留 portrait/avatar opaque token，但领域 Mapper 没有
已证安全 HTTPS URL；`Specs/API_EVIDENCE.md` 和 `UNKNOWN_BEHAVIORS.md` 也未锁定
可信的 host/合成规则。

结论：帖子作者、用户资料、吧头像、搜索结果和关注吧列表继续使用固定
占位；未猜 URL，未为头像新建 Loader/缓存，不阻塞本地 Beta RC。

## Release 边界

`BUILD_EVIDENCE`：Release 默认组合仍是 Live Repository + URLSession + Keychain +
`ProductionImageLoader`，不会静默切 Fixture。Release source list/二进制/包检查排除：

- Debug Live Probe；
- Renderer Lab 和 Pager/Media Interaction Lab；
- Pager geometry/container snapshot、input diagnostic、debug environment key 与
  快照 callback；
- 1000 帖/1000 楼实验入口；
- UI Testing LaunchScenario/Harness/FakeSession/Mock HTTP；
- 纯 Fixture Repository/路由占位和 `app.fixture.*` canary；
- 测试 plug-in、Artifacts/xcresult、本机路径与 Simulator UDID。

Release bundle 必须包含 `Assets.car`、`AppIcon` plist 声明、正确 Bundle ID/版本和
Simulator Keychain entitlement；最终结果见下方门禁表。

## 干净 checkout

`BUILD_EVIDENCE`：从最终代码、测试、构建输入、文档与资源的精确
暂存树 `5982b46f33840efde837e926c90a3f77603b8042` 生成不移动
当前分支的临时 commit
`237f0d9dae167219e74802858a5656a7c9c01d1c`，并完成干净 checkout 验证。
验证后只在本审计回填 tree/commit/日志识别符，没有再改产品、测试、
构建输入或资源。临时 checkout 没有复制
Keychain、私有 `project.env`、DerivedData 或缓存，仅从
`scripts/project.env.example` 建立环境配置，并成功执行：

- `make doctor`；
- `make generate`；
- `make build`（Debug）；
- `make test-unit`；
- `make release-build`；
- `make release-isolation`。

日志 `stage19b-clean-checkout-final-3.log` 最终输出
`CLEAN_CHECKOUT_VALIDATION=PASS`，同时验证 Android reference
正好位于锁定 SHA 且 clean，随后已删除临时 worktree。首次直接从
GitHub 初始化 submodule 时先收到 empty reply，重试后 75 秒超时；因此干净
最终验证使用本机已锁定且 clean 的 Git 对象作为 submodule 源，仍 checkout
`5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`。这验证了仓库构建可重现性，
但全新机器对公网 GitHub 的首次依赖下载仍取决于外部网络可用性。

## 最终门禁

以最终代码树真实执行：

- `make instructions`：通过；
- `make secret-scan`：通过；
- `make lint`：237 个 Swift 文件，0 violation；
- `make test-unit`：379 个逻辑测试、403 次执行、0 失败，结果包
  `20260901-171007-36558-unit.xcresult`；
- `make quality-fast`：在最终代码的阶段出口聚合运行中通过；
- `make release-isolation`：通过，Release 日志
  `20260901-192935-64617-release-build.log`；
- `git diff --check`：通过；
- Android submodule：clean 且位于锁定 SHA。

上述门禁中间曾出现一次 `quality-fast` 失败：最早的未登录 UI
回归借用 Live data mode，触发 networking-isolation 检查。将“生产需求有效会话”
拆为独立 `RecommendationsAccessPolicy`，而 UI 回归仍使用 Fixture/FakeSession/
Mock transport 后，定向回归与最终 `quality-fast` 均通过；没有放宽网络隔离。

阶段出口在最终产品代码上从头执行一次 `make quality`。该聚合命令的
Unit、iPhone smoke/interaction 和 iPad build 通过；首次 iPad smoke
11/12，唯一失败是 XCTest 在第二次 `swipeUp` 中的 99 秒
`Synthesize event` 超时，不是业务断言失败，因此聚合命令本身非 0
退出，也没有伪称其输出 `Quality gate completed.`。按本阶段提示词对
非稳定 XCUITest 命中波动的专项规则，继续完成以下最终证据：

- Unit：379 个逻辑测试、403 次执行、0 失败，
  `20260901-171007-36558-unit.xcresult`；
- iPhone smoke：28/28，`20260901-171041-36870-ui-smoke.xcresult`；
- iPhone interaction：15/15，`20260901-172900-39021-ui-interaction.xcresult`；
- iPad 原失败 resize 用例独立 3/3，
  `stage19b-ipad-resize-3x.xcresult`；
- 同一 Fixture 路径人工验证 full → narrow → full，帖子/楼层保留，
  无白块、遮挡、错页或崩溃；
- iPad smoke 完整重跑 12/12，
  `20260901-190952-51936-ui-smoke-ipad.xcresult`；
- iPad interaction：2/2，
  `20260901-191953-58297-ui-interaction-ipad.xcresult`；
- Release build/isolation：通过，`20260901-192935-64617-release-build.log`。

因失败用例独立 3/3、人工产品行为正常、完整 iPad smoke 12/12，
且其他所有套件通过，该事件按明确的 Beta 例外定性为
suite-state/event-synthesis 波动，没有为此修改产品 UI。

实施期间还曾遇到并立即修正三个确定性工程门禁问题：
`RecommendationsAppRootView` 初版条件编译构造失败、SwiftLint
`type_body_length` 353 > 350，以及测试类名超过 40 字符。分别通过完整
Debug/Release initializer 分支、拆分小型 View 和缩短测试类名修正；
没有禁用规则或降低断言。

最终没有留下稳定可复现的 P0/P1。

## Known Limitations

1. 这是非官方客户端，私有 API、字段和服务端错误码可变，尚未覆盖全部
   服务端错误码。
2. 没有已证安全的头像 HTTPS URL，继续使用统一占位。
3. 动图只保证可显示静态帧；没有 GIF 动画、视频、全尺寸瓦片、复杂 image lease
   或跨 View in-flight 请求合并。
4. 真机完整 VoiceOver、iOS 18.x runtime、完整设备和 Stage Manager 矩阵未验证。
5. logout 实现有确定性测试，但本轮为保留会话没有执行真实 logout。
6. 完整楼中楼独立页、签到、发帖、回复/发布评论、点赞、删除、私信、离线下载和
   推送不在 Beta 产品范围。
7. 公开源码仓库及原创 iOS 代码的 `GPL-3.0-only` 授权已由项目负责人批准；
   Android reference/Proto 的文件级来源，以及 App Store、商标、服务条款和
   商业二进制分发权利尚未完成独立确认。

上述限制不阻塞公开源码 Beta RC，但阻塞 `APP_STORE_READY`、
`PRODUCTION_CERTIFIED` 或 `COMMERCIAL_DISTRIBUTION_CLEARED` 声明。
