# R05 吧首页

状态：READY_FOR_USER_VISUAL_REVIEW（2026-09-23）。基线 62c2b13，R04 已获用户批准并提交，R05 未暂存、未提交；未进入 R06。READY 表示已准备人工验收，不代表用户已经批准视觉。

用户本轮阅读导航反馈已追加修订：吧/帖子隐藏根底栏，iPad 竖屏单页、横屏保持分栏。最终状态、截图和新增验证失败以 [R05_NAVIGATION_REVISION.md](R05_NAVIGATION_REVISION.md) 为准：两个既有锚点 Unit 基线失败及 iPad 连续旋转 XCTest 失败仍保留，不能将下列早期全通过记录当作本轮全绿。

## 基线和实施计划

已使用 tiebalite-android-visual-parity、xcode-quality-gate、tiebalite-api-evidence。已读指令链、规则/矩阵、R05 prompt、ADR-0016/0019/0023/0024，以及 UI c5f1125 的 ForumPage、ForumThreadListPage/ViewModel、GeneralTabListViewModel、FeedCard 与请求实现。Android 参考 05-forum-home.png，iPhone 实际基线 iphone-baseline.png：大统计卡、置顶大图卡、无分类和排序、作者图未呈现。

基线定向 Unit 28 项/4 suites 通过（baseline-unit.xcresult）；本轮开始前 approval-build.log 构建通过。

1. Core 增加真实导航分类、精华分类、排序和头部白名单字段；扩展 FRS 查询与普通分类 endpoint，锁定 Proto 最小闭包。
2. ForumHomeStore 作为路由持有者保留 latest；每个分类一个既有 ForumHomeStore 实例，任务/代次/分页/anchor 独立。仅已选择页首次加载，排序刷新当前页。复用 PagerContainer 和 VirtualizedList，不改共享实现。
3. 移除大卡；紧凑吧图/名称/真实等级和进度（匿名缺字段不展示），置顶/吧规一行；普通行复用 R01 图片和等级原子。发帖仅明确占位，搜索接现有路由，更多含重载。
4. 定向 Unit 验证请求/映射/未知字段、懒加载、取消/迟到、去重和独立分页；Fixture Smoke 验证点击/横滑、切回位置、帖子返回、多图/头像、iPad 宽度。最终 lint/build/diff，覆盖安装、截图并停吧首页待用户验收。

非目标：Session/缓存/根导航/ThreadReader/共享 Pager 与 VirtualizedList 实现、实际写操作、R06。主要风险是分类 endpoint 的匿名运行证据与远页 Pager 淘汰后的 anchor 恢复；不伪造 Live 分类或用户等级，不放宽证书与图片来源。

## 迭代验证记录

- 两次 make generate 起初 exit 2：先更新 schema 输入锁但未生成受控输出，verify-protos 正确报告 207/212 漂移。执行 scripts/generate_protos.sh 后，make generate 的两次独立生成与受控输出一致。
- mapping-red.xcresult 首次编译失败：测试使用了 Proto 未提供的 hasForumRule 名称，改为实际生成的 hasForumRule_p。mapping-red-verified.xcresult 两项/10 断言按预期失败，证实默认 sort 与缺少导航映射。
- mapping-green.xcresult 21 项/4 suites 全通过；tabs-unit.xcresult 42 项/7 suites 中 2 项样本校验失败：新隔离 scenario 的 signedIn 注册断言未同步，零字节响应应归 emptyBody。已保留空 body 断言、另以带 error message 的无 data 样本检查 missingData。
- iphone-smoke.xcresult 首次失败：测试误查动态 thread 100003，实际打开的是 Forum thread 140003。头像、吧图、三张图片加载与选择已通过；仅修正测试的具体业务 ID，返回位置断言未放宽。
- lint-first exit 2：三个多闭包调用格式；lint-second exit 2：测试多余空行。均只修正格式。

- iphone-return.xcresult 第二次在直接查询屏幕外行的 isHittable 时触发 XCTest activation point invalid；改为先检查存在且 frame 与实际列表视口相交，再检查命中。iphone-viewport.xcresult 1/1、76.948s 通过：三图、帖子返回±12pt、精华筛选、左右滑普通分类、独立返回位置±12pt、排序、第三页、发帖提示、搜索与返回。
- ipad-smoke.xcresult 1/1、21.414s 通过；宽度截图发现旋转过渡的捕获时机可能早于布局稳定，追加实际横竖屏 frame 条件后再验证，不凭点击动作宣称完成。
- lint-third exit 0。网络隔离首轮发现新增 generated request storage 的 Sendable allowlist 尚未登记，中间 network-isolation-verified 仍未通过（随后发现调用正则多余括号及总计数未同步）；最终复验结果见下文。R05 明确允许的 Pager/占位 sheet/图片总数 overlay 按文件/调用单独登记，仍禁新手势、全屏 presentation 和网络泄漏。

- final-unit.xcresult 59 项/11 suites 通过，涵盖 Forum/query/取消与迟到、1000 帖既有复用、Pager 状态、注册表、R01 头像 Cell/Stage19 图片 Cell 与 ProductionImageLoader。没有跑全量 Unit/Media interaction。
- 首轮 Live probe UI 报失败，但 stdout 缓冲未及时落盘；改临时诊断为即时 stderr 元数据后，证实只在普通分类的实际 MIME 被 FRS 白名单拒绝。未改认证或猜参数；GeneralTabProtocol 独立登记 application/protobuf，并新增接受该类型/拒绝 HTML/FRS 白名单不扩大的测试。

- live-probe-verified.log：最新 0/1、精华及首个非零精华分类均 13 条；普通分类两页各 30 条。全部 HTTP 200，Cookie=false，普通分类 application/protobuf，FRS application/octet-stream。没有请求或持久化凭据/原始 body。个人 level=false，按规则不显示经验/个人等级。临时 Probe 全部恢复/删除，未更改原 Debug 诊断入口。

## 目标与范围、修改文件

- Forum：ForumHomeView/Store/ListPresentation 与新 ForumHeaderView、ForumTabsView、ForumThreadFeedRow、ForumFeedText；紧凑吧头、平面置顶/吧规/普通帖子，保留原业务 thread ID 和路由映射。
- Core：ForumHome、ForumNavigation、FRSPageProtocol/FRSPageMapping、GeneralTabProtocol、LiveForumHomeRepository；真实排序/精华/普通分类参数、完整媒体与头部白名单字段。普通分类分页 cursor 使用原响应 id，导航使用原 threadID，二者不混用。
- App：ForumHomeDestination、AppRouter、AppCompositionRoot；搜索复用既有 SearchView/路由，系统 sheet 保持原吧页挂载；Fixture repository 注入只限隔离分支，Live 不使用样本数据。
- 测试：R05ForumFixture、LaunchScenario 注册、R05ForumMappingTests/TransportTests/StoreTests、R05ForumSmokeTests；已有 1000 帖、头像及图片复用回归保留。
- 协议与记录：新增 5 个受控生成 Proto 文件（总计 212）、输入/输出校验锁、生成脚本与精确网络隔离 allowlist；ADR-0025、API_EVIDENCE、PROTOBUF_MAP、THIRD_PARTY_NOTICES、TASK_STATE、视觉矩阵。没有升级依赖或修改 Android submodule。

## 关键设计与状态转换

每个页签保留独立 ForumHomeStore；首次选中才请求，刷新/排序仅更新当前页，任务代次阻止迟到覆盖；追加按稳定 ID 去重。普通行图片任务仍由既有 Loader/Cell 生命周期管理。onScrollSettled 只接收当前列表有效 thread anchor，footer 不覆盖；已挂载页保留实际 offset，淘汰页按共享列表既有机制恢复 anchor。没有通过刷新 id 重建整张列表。

新增或变更的动画、手势、overlay、依赖：无自定义动画/手势/依赖；横滑继续由共享 Pager 管理。新增系统搜索 sheet、明确只读的发帖占位 sheet，以及不命中触摸的媒体总数角标 overlay。没有实际发帖/点赞/分享写入。

## 最终命令与逐项结果

日志与 xcresult 根目录均为 `Artifacts/VisualReview/R05/`；各 xcodebuild 日志开头保留完整可重放命令、destination 和 only-testing 参数。

| 命令/结果束 | 结果 |
|---|---|
| scripts/generate_protos.sh；make generate | 通过，两个独立生成目录与受控输出一致 |
| xcodebuild Unit → final-unit.xcresult | 59 项 / 11 suites 通过，包括 Forum/Pager、1000 帖列表、R01 头像 Cell、Stage19 图片 Cell、ProductionImageLoader |
| MIME 修订后 xcodebuild Unit → mime-final-unit.xcresult | 10 项 / 3 suites 通过；接受 GeneralTab 的实际 MIME、拒绝 HTML、FRS 白名单不扩大，取消/超时不重试 |
| iPhone xcodebuild UI Smoke → iphone-viewport.xcresult | 1/1 通过，76.948s；选中页和实际内容、帖子返回 ±12pt、精华筛选、左右横滑、独立返回位置、排序、第三页、搜索/发帖占位均断言 |
| iPad xcodebuild UI Smoke → ipad-geometry.xcresult | 1/1 通过，24.439s；分类选择、滚动、横竖屏实际 frame 和标签保留；前一轮 ipad-smoke 1/1 同样通过 |
| make lint → final-lint.log | exit 0，288 文件无违规 |
| make build → final-build.log | exit 0，正常 Debug 构建；临时 Probe 对象已移除 |
| bash scripts/verify_networking_isolation.sh → final-network-verified.log | exit 0，0 failures；只以此最终日志记通过 |
| 凭据扫描 → final-secrets.log | exit 0，无 high-confidence match |
| git diff --check → final-diff.log | exit 0 |
| protected-final.json | 35 个既有基础设施文件 SHA-256 一致，changed=[] |
| xcrun simctl install + launch（两台） | 正常 Debug .app 覆盖安装并启动；无 uninstall、erase、退出登录或清 Keychain |

未运行全量 Unit、完整 make quality 或无关 Media interaction。中间失败均保留在上方；收尾读取日志的组合命令还因查询不存在的 Sources/Features/Forum/AGENTS.md 而 exit 2，未改源码或误记为质量门禁通过。重复导出已存在的 xcresult 附件曾报 file exists，保留原附件，未删除结果束。

## Simulator 与截图

最终 iPhone 17 Pro 前台停在 Live 高通吧“最新 / 按发帖时间”的标签区域，真实头像与多图已显示；iPad 正常 Debug App 停在同吧的横向详情。人工操作仅只读浏览，自动化始终使用隔离 forum.parity Fixture。

- `iphone-live-tabs-media.png`：按最后回复的吧头、普通分类、真实头像与紧凑三图。
- `iphone-live-creation-media.png`：切换按发帖后实际更换的帖子和并排两图。
- `iphone-live-good.png`：真实精华 chips、头像、等级及两图；进入帖子后返回仍在原精华首屏。
- `iphone-live-category.png`：服务端“吧友互助”被选中且实际内容加载成功。
- `ipad-live-landscape.png`：Live 吧首页横向布局。simctl 原始 PNG 按设备面板方向存储，查看器可能需旋转 90°；未加工截图。CUA 已直接观察到正常横向窗口、完整吧头/标签/平面多图行。
- `iphone-fixture/BE105BBB-9940-4DC3-9564-EB2E6902F34A.png`：固定吧头、等级/经验、置顶、三图预览/8 图总数。
- `iphone-fixture/501C6321-080C-465C-B2F8-D5A24266DF82.png`：固定第三页。
- `ipad-final-fixture/`：横向分类与竖向吧头的原始 XCTest 附件及 manifest。早期旋转附件呈现异常方向/边界，不能仅据附件宣称布局无误；后续增加实际 frame 断言，并以最终 Live 窗口复核。

## 未解决风险 / UNKNOWN 与下一阶段前置条件

- Live 匿名吧接口没有个人等级/经验，按约定隐藏；不借用关注列表的等级或 Fixture 值。
- 已验证固定公开吧的排序、精华与一个普通分类前两页，不代表全部分类/受限吧/末页均经 Live 验证。
- CUA Live 横向 drag 本次被识别为点按并打开帖子；未将其记作横滑成功。Live 深滚动、跨远端标签后精确 offset 仍待用户手工检查。Fixture 的左右横滑、相邻页位置、第三页和返回断言通过；被共享 Pager 淘汰的远页恢复粒度仍遵循既有 anchor 契约。
- 发帖入口仅明确占位。R05 尚未获得视觉批准；等待用户在 Simulator 检查后再决定修改或提交，不进入 R06。

## 阅读页底部补充

用户反馈根栏隐藏后仍余白条，后续窄范围修复、原始失败与短回归结果见 `R05_NAVIGATION_REVISION.md` 的“底部白条二次反馈”。生产仅改阅读目的页及 Forum Pager 内容边缘；iPhone / iPad 各一条短用例通过，未重跑本文件历史长矩阵。截图在 `Artifacts/VisualReview/R05/BottomInset/`。

## 用户最终批准与提交

2026-09-23 用户明确表示“我看了一遍应该没问题了，你提交05R进入06R”。R05 全阶段视觉获批；本轮未继续修改 UI。提交前定向 Unit 37 项 / 7 suites、make lint/build、forbidden、secret-scan 和 git diff --check 均 exit 0，日志在 Artifacts/VisualReview/R06/r05-approval-* 与 baseline-unit.xcresult。历史失败保留，不改写为全绿；不重复完整质量矩阵。精确暂存 R05 实现、测试与记录，不包含用户其他阶段 prompts、skill agents 元数据、Artifacts 或 Simulator 数据。
