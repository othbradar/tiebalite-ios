# R11 消息

状态：`USER_VISUALLY_APPROVED`（2026-09-25）。用户确认“我看了都改好了”，明确授权只提交 R11、先不进入 R12。前置工作已按用户授权提交 `9c9d715`；发帖审核问题按用户要求暂缓，本阶段未修改发布链路，也未执行 Live 发布。

## 用户验收与提交

用户已验收本阶段消息页面、完整帖子一级回复定位及末吧底部遮挡修订。验收候选截图为 `Artifacts/VisualReview/R11/FullThreadAndBottom/iphone-live-parent-floor.png`、`ipad-live-parent-floor.png`，证据保留在 ignored Artifacts，不纳入提交。此前 AI 的 Live 滚动工具限制不再作为等待用户批准的阻塞项，但不改写成 AI 已执行成功；接口与未读变化的 UNKNOWN 保留。

本轮只更新验收记录并精确提交，不再改生产代码/UI；沿用下面已完成的定向 Unit、共享列表/图片复用与 iPhone/iPad Smoke 结果，不重复长回归。不推送、不进入 R12。以下各节是实施与交付时的历史记录，早期候选的“未提交/待验收”不代表当前状态。

提交前复核：`make build`、`make lint`（364文件、0 violations）、`make secret-scan`、`git diff --check` 全部 exit 0；日志在 `Artifacts/VisualReview/R11/UserApproval/`。未重跑 Unit/UI，未更换已验收的 Simulator 页面或登录态。

## 本次修订：底部遮挡与完整帖子定位（2026-09-25）

用户反馈：吧选择页面底栏挡住末尾吧；上方具体回复应进入帖子并自动滚到对应一级回复。用户进一步明确：楼中楼消息也只定位父楼，不自动打开二级页面。本节取代下面历史修订中的“种子快照/直接进入楼中楼”行为与已通过判断。

根因与证据：

- 根 TabView 没有把外层 safeAreaInset 传给内层 UIKit 列表。长列表实际末行底边840pt、底栏顶边783pt，遮挡57pt（baseline-ui2）。根选择栏改成 TabView 的同级纵向布局，按自身高度占位；TabView、四个独立导航栈与现有列表实例保留，没有硬编码尾部垫片。
- 之前 PBPage(pid=目标) 的返回片段被当作完整帖子初始化，只有目标及后续楼层，无法上滚到前文。NotificationDestinationStore 现在复用普通 ThreadReaderStore，顺序加载首楼至目标所在页，预置业务ID锚点后才挂载列表；下一页仍由原入口处理。楼中楼只从真实 PBFloor 返回中解析父楼ID。
- 完整上下文揭示了另一处真实竞态：三次连续进入中，第一次恢复时 viewport=402×672.67/window=true，正确停第7楼；后两次 snapshot completion 在 bounds=0/window=false 时就消耗锚点，实际停到第2楼。`anchor-diagnostic` 的截图和仅 Fixture 布局诊断确认此因果；临时诊断已撤除。
- VirtualizedList 只补首次锚点生命周期：pending → 挂入窗口、有非空viewport、目标ID在快照 → 恢复一次 → 清空回调。沿用原 scrollToRow/Diffable/UIHostingConfiguration；普通追加、图片完成、旋转不重定位，teardown 清理回调。没有改 Cell 清理、业务ID、分页、Pager、MediaViewer、图片/Session/发布逻辑。

参考：同一锁定 Android HomePage 使用 Scaffold 内容边距和12dp尾部留白；ThreadViewModel 对 pid 定位还实现 LoadPrevious（PBPage back=true），说明其可以访问前文。iOS 按本轮范围复用已验证的普通前向分页保留前文，不新增反向协议或重建列表。

测试范围与证据目录：`Artifacts/VisualReview/R11/FullThreadAndBottom/`。baseline-unit 4测试中目标行为失败5断言；baseline-ui2确认目标页面无法上滚回首楼三次及底栏遮挡。首次 baseline-ui 因新增Fixture误给非可选Int传nil而编译失败，已修正并保留日志。首次候选UI还暴露新样本的非可见复用节点会存在于AX树：尾部滚动脚本改为等待实际可见且完整包含，引用断言改为首楼可见并处于视口顶部；没有降低实际目标楼层/前文断言。`iphone-ui`/`iphone-ui2` 的初始锚点失败为真实UI失败，后续只采证未盲目改参数。

已执行：34项/6组相关Unit通过（unit）；锚点与已有Cell/图片复用10项/3组通过（unit-anchor，与前轮重叠不累计）；iPhone完整定向Smoke3/3通过（iphone-anchor-fixed，129.177秒，三次同一消息、父楼、第二页目标、双页及四根入口/返回）；阅读底部边界1/1通过（iphone-ui）。没有全部Unit或完整quality。

iPad最后定向双消息Smoke2/2通过（ipad-ui3，123.312秒），包含三次准确目标/上滚首楼、楼中楼父楼、后页消息、实际四根页面及横竖屏切换；同设备阅读区和末吧底边2项已在ipad-ui通过。ipad-ui/ipad-ui2保留定位脚本失败：屏外UIKit AX节点返回 `(inf, inf, 0, 0)` 或零frame，直接查isHittable令XCTest抛错；ipad-ui3记录frame后排除空frame才判断包含与可点击性，原滚动次数、超时、内容和位置断言不变，没有为自动化修改生产交互。

lint-handoff：0 violations；secret-scan通过；diff check通过。中途lint的factory函数81行及测试双空行两处失败已修正，日志保留。已有图片复用测试输出visibleCells更新期间访问的UIKit诊断，该路径不提供锚点、未修改其willDisplay统计逻辑，测试断言全部通过；本轮不扩大处理。

最终 `make build` 通过（build.log），两台覆盖安装正常 Debug 完整 Live App，无 Fixture 参数、uninstall、erase 或 Keychain 清理。构建/iPhone/iPad 的 TiebaLite 和 TiebaLite.debug.dylib 两个文件逐一 SHA 一致（installed-binary-hashes.json）；实际功能库 SHA 为 `b81a299f0ca198d00035b3bb7606b7490b6d7e9f398b34f023f93d19d318508b`。

Live 实际点击：iPhone 普通消息进入原帖并滚至末尾第4楼，画面同时保留第2/3楼和首楼图片尾部（iphone-live-target-with-earlier-floors.png）；因该回复位于短帖末尾，UIKit按内容边界停在底部，不强造尾部空白来顶齐。第四条楼中楼消息在 iPhone 和 iPad 均定位原帖第6楼，灰色预览含原消息内容，下一层是第7楼，未进入二级页面（iphone-live-parent-floor.png / ipad-live-parent-floor.png）。两台停在这一真实父楼，iPhone前台，方便用户上滚、返回消息和切回首页检查。

限制：CUA滚轮和拖动仍未移动Live列表，未完成Live末吧/向上回首楼手工滚动；这些操作有两台确定性Fixture证据，不能冒称已在Live完成。长帖定位需顺序加载到目标所在页，耗时随页数增加；若目标已删除或分页无进展则显示失败，不跳错楼。既有未读非零Live变化/提到页为空的限制保留。截图与前图均在本证据目录，私人Live内容未写入Fixture或Git。

本次文件：消息目标Repository/Store/组合入口、AppShellView布局、VirtualizedList首次锚点21行差异（19增2删）、Debug/UITest样本及定向测试、交互/API/阶段记录。新增动画、手势、overlay、依赖：无。未修改发布链路、Pager/MediaViewer、图片系统或Session；发帖后台删除问题继续暂缓。所有差异未暂存/提交，不进入R12。`READY_FOR_USER_VISUAL_REVIEW`。

## 用户修订：主题引用与具体回复分开点击（待人工验收）

用户原话：“消息页面点击回复我的主题应该跳到对应的帖子，然后点击上面的具体回复应该跳到对应帖子对应的回复位置”。

差异属于交互：初版 `NotificationRow` 把作者、正文和引用都包在同一个 Button 中，只提供 `openTarget`，导致引用也携带回复 postID 进入定位路径。目标为两个独立可访问按钮：上方保持现有准确主楼/楼中楼定位，下方引用只传 threadID 走正常帖子入口；不改变行身份、外观、图片任务、列表及分页。

参考：Android 目标 `03-notifications.png`；锁定 UI `c5f1125` 的 `NotificationsListPage.kt:118–225`。该源码已有独立引用点击，但普通主题引用仍传 `postId`，不能声称其代码直接证明了“主题从首楼打开”；本次按用户明确指定的交互修订。未知 `quote_pid` 仍不作为目标楼层来源。

计划文件：`NotificationsView.swift`、`AppShellContent.swift`、消息 `RouteGrammar`、本地阅读 Fixture 的消息主题样本、R11 定向测试及记录。验证分别点击引用与正文，核对首楼/准确回复实际节点、返回列表位置和原双页 Smoke；仅相关 Unit、iPhone/iPad 短 UI、lint/build/secret/diff。不修改共享容器、发布或下一阶段。

修订结果：拆成并列 Button，正文保留原消息 ID 和精确回复路由，引用使用独立 `notifications.quote.<messageID>` 标识和不带 postID 的 `.thread` 路由；引用按钮最小高度 44pt。消息根允许既有普通帖子路由及同帖子回复/用户后续路径，拒绝跨帖混接。没有新增动画、手势、overlay 或依赖。

修复前在当前候选、相同 Fixture 连续点三次引用，每次实际显示了第 7 楼节点而没有首楼节点，产生 6 个准确内容断言失败（`ClickTargets/baseline-ui.xcresult`，exit 65），不是元素定位失败。新增普通帖子路由 Unit 同样先失败（`baseline-unit.xcresult`，exit 65）；原有三项目标测试通过。首轮 lint 两处新增测试参数缩进失败，整理格式后通过；未隐藏失败记录。

本修订执行结果（均在 `Artifacts/VisualReview/R11/ClickTargets/`）：

| 命令/验证 | 结果 |
|---|---|
| 定向 xcodebuild Unit：R11NotificationTargetTests、R11NotificationsStoreTests、R02RootShellTests | 17项、3 suites通过，`unit.log/.xcresult`，exit 0 |
| iPhone R11NotificationsSmokeTests | 2/2通过，86.146秒；含三次引用/正文不同目标与位置保持，`iphone-ui.log/.xcresult`，exit 0 |
| iPad 同一 R11NotificationsSmokeTests | 2/2通过，95.473秒；含原双页/四根入口/精确楼中楼/横竖屏及三次点击区分，`ipad-ui.log/.xcresult`，exit 0 |
| `make lint` | `lint-final.log`，0 violations，exit 0 |
| `make build` | `build.log`，exit 0 |
| `make secret-scan`、`git diff --check` | 通过；交付最终记录 `handoff-secret.log`、`diff-check.log` |
| 225个当前候选 App/Sources 文件 SHA 核对 | 只变更上列4个源码文件（含1个Debug Fixture文件），`source-changes.json`；共享承载/图片/Store/协议未修改 |

两台已覆盖安装完整正常 Live App，没有卸载、erase、清 Keychain 或 Fixture 参数。构建、iPhone、iPad 二进制 SHA-256 均为 `e55cfe99bd8d814a91fb5a7d305049c1e37c5aecc0b16cc7ccdce9649731774f`。iPhone 真实同一条消息已分别点击：引用显示对应标题、楼主正文和图片；上方回复显示对应作者第 4 楼。均成功返回消息首屏；未发布任何内容。

修订前截图 `ClickTargets/user-before.png`；修订后 `ClickTargets/iphone-live-messages-after.png`、`ClickTargets/ipad-live-messages-after.png`；实际两种目标分别见 `ClickTargets/iphone-live-quote-thread.png` 和 `ClickTargets/iphone-live-reply-floor.png`。两台 App 留在真实“回复我的”，iPhone 前台。初版记录中的 Live 深滚动、空提到页及未读转换限制仍保留；本次只修点击入口，未重复无关测试，未暂存/提交、未进入 R12。

## 初版实施记录（历史证据保留）

范围：消息双页、独立分页/位置、真实未读计数、消息目标适配。复用 VirtualizedList、Pager、ProductionImageLoader、TiebaRichTextView、ThreadReader/Subposts。禁止改写共享容器或发布链路。

证据：Android UI `c5f1125f42498e49db4e4a9cb66313b8c8a285c7` 的 notifications 页面及协议锁 `5545326b2a8e0d784b2f3dfbcb219c7b121e61c2` 相同。目标图 `Android-target/03-notifications.png`。原 iOS 只有“消息待实现”。

验收：两页点击/横滑、独立分页去重、失败保留内容、取消/会话隔离、真实计数、精确主楼/楼中楼跳转和返回位置；表情及引用块；iPhone/iPad 定向 smoke。基线 R02RootShellTests/PagerStateMachineTests 15 项通过。

数据缺口：消息 JSON 的 replyer 没有等级字段，保持空值，不另查或填充等级。读取列表是否清除服务器未读由后续计数响应验证，客户端不乐观清零。

## 目标与范围、修改文件

- `Sources/Core/Models/Notifications.swift`：真实消息、目标和计数领域模型。
- `Sources/Core/TiebaAPI/{NotificationsProtocol,LiveNotificationsRepository,FixtureNotificationsRepository,NotificationTargetRepository}.swift`：原版消息接口、严格 JSON 映射、受 Session lease 约束的请求、固定样本、复用 PB 的目标定位。
- `Sources/Features/Notifications/Presentation/`：两页独立 Store、统一分页入口、平面行、浅色引用、表情、目标加载状态。
- `App/NotificationDestination.swift` 及 App 的 composition、registry、route、shell 集成：持久消息根栈、真实计数、导航目标；移除原占位页面。
- `ThreadReaderStore`、`SubpostsStore` 仅增加校验后的初始快照参数，复用原有列表、分页及 anchor；未改承载实现。
- `project.yml` 注册 Feature；`Tests/R11*`、`TestSupport/Notifications/`、`UITests/R11NotificationsSmokeTests.swift`；R02 根入口断言更新为真实消息根。
- 更新 API evidence、UNKNOWN、矩阵及 TASK_STATE。用户已有未跟踪 Prompt/skill 文件保持原状。

## 关键设计与状态转换

两页分别持有内容、cursor、失败状态和有效消息 anchor。初次失败/空态、保留内容的刷新失败/下一页失败、取消和过期响应均独立处理；同一页重复请求被合并。消息 ID 使用种类、post_id、replyer.id、time；追加去重保序，footer 不替代消息 anchor。仅当前可见标签触发首次读取，Pager 预加载不会提前读取另一页。

根 badge 读取 `/c/s/msg` 的真实回复/提到计数；列表读取后重新获取计数，等待并越过读取前仍在运行的计数请求，避免旧结果掩盖已读更新。服务器失败保留上次计数，切换认证上下文清理旧账号状态，不凭点击乐观清零。

消息先用目标 post_id 定位 PB 主楼或使用 `pid=0, spid=post_id` 定位楼中楼；校验实际返回 thread 和目标成员后再进入已有阅读组件。未把含义不明确的 quote_pid 当作父楼。目标不可用显示明确失败页。

首个 Live 请求确认旧式 JSON MIME 为 `application/x-javascript`，初版白名单在 JSON 解码前拒绝了它。只为消息接口补充该 MIME，仍严格 JSONDecoder，不执行脚本/JSONP，不改请求身份字段；定向样本覆盖接收 JSON 和拒绝脚本文本。

## 动画、手势、overlay、依赖

没有新增自定义动画、手势、overlay 或依赖。使用已有 Pager、VirtualizedList、ProductionImageLoader、TiebaRichTextView；共享承载、图片、Session、Forum 和 MediaViewer 源文件与前置提交保持一致，核对结果保存在 `Artifacts/VisualReview/R11/protected-files.json`。

## 执行命令与结果

所有日志、xcresult、截图均保存在 ignored `Artifacts/VisualReview/R11/`，没有把账号内容或凭据加入固定样本/Git。Xcode 命令使用已有工程/方案、Unit 配置、锁定依赖、关闭并行测试；完整调用首行保存在各日志中。

| 验证 | 结果与证据 |
|---|---|
| 基线 R02RootShellTests、PagerStateMachineTests | 15 项通过，`baseline.log/.xcresult` |
| R11 四组 Unit + R02RootShellTests + PagerStateMachineTests | 最终主轮 29 项、6 suites 通过，`unit-final.log/.xcresult` |
| MIME 修正后 R11 四组 Unit | 15 项、4 suites 通过，`mime-regression.log/.xcresult`；与上一行有重复，不累加为独立用例数 |
| R11 iPhone 定向 UI | 1/1 通过，46.717 秒，`iphone-smoke2.log/.xcresult` |
| R11 iPad 定向 UI（含横竖屏） | 1/1 通过，50.780 秒，`ipad-smoke.log/.xcresult` |
| `make lint` | 通过，`lint-final.log`；交付前再次检查见 `handoff-lint.log` |
| `make build` | 最终 MIME 候选通过，`live-mime-build.log` |
| `make secret-scan` | 通过，`secret-scan-final.log`；交付前再次检查见 `handoff-secret-scan.log` |
| `git diff --check` | 通过，交付前记录见 `handoff-diff-check.log` |
| 覆盖安装、二进制核对 | iPhone/iPad/构建三者 SHA-256 均为 `b137ac5e56cce5c51a534bcc2512288537bec01c1e0137abc1a3ad0d4b068311`，见 `installed-binary-hashes.json` |

没有运行全部 Unit、完整 quality 或无关长交互矩阵。UI 测试运行于隔离 Fixture；最后 MIME 修订仅改变响应类型白名单，有对应 Unit 和实际 Live 加载证据，没有重复整套 UI。

历史失败均保留：`compile.log` 为新 Feature 未注册工程；`compile2.log` 为日期函数引用参数不匹配；`unit.log` 为调用了不存在的测试 helper；初轮 lint 为格式规则。均已修正。第一次 iPhone UI 使用旧的楼层行标识而失败；失败截图已显示准确第 7 楼，改为断言现有正文节点和目标作者后通过，未降低断言、延长超时或为测试改生产点击。`iphone-smoke.xcresult`、`target-failure.png` 保留。既有 ComposerPhotoPreparation 静态规则失败来自前置阶段，本轮未修复或冒称通过。

## 回归覆盖与 Live 观察

Unit 覆盖请求/映射/错误分类、撤销 lease、取消/陈旧结果、独立分页去重、失败保留内容、有效 anchor、读取后计数竞态和准确主楼/楼中楼定位。短 UI 实际滚到第二页目标行，横滑/点选双页、切换四个根入口、进入准确楼层/子回复后返回，并比较可见行位置；iPad 加入方向/宽度变化。样本包含长正文和官方内联表情。

完整正常 Live App 已覆盖安装两台，未卸载、erase、清 Keychain 或使用 Fixture 启动参数。两端真实回复已加载，头像、中文日期和引用可见。iPhone 实际打开一条主楼回复及一条楼中楼回复，确认目标内容并返回原列表。当前账号“提到我的”为空，非空样式使用隔离 Fixture 补证。AI 没有发送、上传或修改任何帖子/回复。

截图：

- `iphone-live-replies.png`：最终完整应用回复页；`ipad-live-replies.png`：iPad 对应 Live 页。
- `iphone-live-mentions.png`：该账号真实空页。
- `iphone-live-floor.png`、`iphone-live-subpost.png`：真实主楼和楼中楼目标。
- `iphone-smoke2-attachments/ED9384F0-7707-404D-BC21-A51DC9B380AD.png`：非空“提到我的”与表情 Fixture。
- `iphone-smoke2-attachments/E00E28B6-D9E6-4D94-888B-DE88FD5D88D9.png`：回复中部 Fixture。
- `ipad-smoke-attachments/`：iPad 非空标签、中部和横屏样本。

## 未解决风险 / UNKNOWN、下一阶段前置条件

当前真实未读计数为零，没有观察到 Live 非零变零；该状态转换仅有确定性 Unit/Fixture 证据。未采集真实下一页 wire 样本或删除消息错误样本。消息接口未提供作者等级，缺省不显示。

CUA 的滚轮和拖动未能移动 Live 列表，因此当前 iPhone 前台与 iPad 都停在“回复我的”首屏，**未达到 Live 中部停留要求**；中部、分页和返回偏移仅有本阶段 Fixture UI 证据，不冒充 Live 验证。用户可直接在 Simulator 手动滚动检查。

等待用户查看真实消息、横滑、滚动及返回位置后决定视觉是否通过；此阶段不暂存/提交、不进入 R12。发布被后台删除的问题继续 `DEFERRED_BY_USER`。
