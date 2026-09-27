# R13 最终集成与 Beta 验收

状态：USER_VISUALLY_APPROVED（2026-09-27 用户明确授权提交 R13）。基线 `60ea8d6`（R12 已按用户明确授权提交，未推送）。使用 tiebalite-android-visual-parity、xcode-quality-gate 和 ios-root-cause-debug。自动化失败项均已定向转绿；解锁后已完成下述 Live 页面/手势检查与六屏并排对照；用户补充截图确认断网保留原列表，并明确确认恢复网络后重试成功。本次明确授权提交 R13；tag、push、IPA 不在本次授权内。

## 当前门禁结论

| 检查 | 已执行结果 |
| --- | --- |
| 全量 Unit | 526 项 / 601 次参数执行，0 失败、0 跳过 |
| iPhone Smoke | 原 28 项 26 通过；2 个失败项修正测试定位/旧契约后分别定向通过 |
| iPhone interaction | 原 15 项 14 通过；返回目标按 R12 路径修正后通过 |
| iPad Smoke / interaction | 原 13 项 9 通过、2 项 1 通过；5 个失败项定向 5/5 通过 |
| 干净候选 Debug / Release / Release 隔离 | 全部 exit 0，生产输入与当前工作树逐文件相同 |
| instructions / secret-scan / lint / 静态规则 | 最终 exit 0；lint 0/372，静态 0 error / 3 warning groups |
| Diff / 暂存区 / Android reference | diff check 通过；暂存区为空；参考 submodule 无修改 |

原 `make quality` 在首次 iPhone Smoke 失败处 exit 2；已逐项执行其剩余目标，并定向修正/重跑失败项，没有为了获得一条绿色总命令重复整个长矩阵。上述是组合证据，不把原失败命令改记为成功。原始日志与 xcresult 均保留，汇总在 ignored `Artifacts/VisualReview/R13/GATE_RESULTS.json`。

## 范围与验收计划

- 对照锁定 Android UI `c5f1125` 和 Android-target，复核首页、动态、吧/帖、楼中楼、表情、Composer、消息、我的/搜索/历史/设置。保留用户已接受的标题居中等差异。
- 复核 R12 iPad 深层阅读后切换我的的详情残留；先在当前基线上复现，只在证据支持时做最小修正，不改共享列表、Pager、图片缓存、Session。
- 更新 README、THIRD_PARTY_NOTICES、资源来源和本记录；执行完整门禁、Release 隔离及干净 checkout Debug/Release 构建。
- 门禁脚本目前 UI 分支先卸载主 App；这与用户持续要求保留 App 数据相冲突。先改为只确保设备启动、由 Xcode 覆盖安装，保留测试隔离断言，不卸载/erase/清 Keychain。
- 旧门禁另记录了 ComposerPhotoPreparation 全局 shared 单例违规；先运行原检查确认，再改为编辑器生命周期内的实例，不改变图片编解码与上传行为。
- 自动化仅隔离 Fixture；真实账号只做阅读、导航及打开编辑器，不执行发送或 logout。最终覆盖安装完整 Live App、截图并等待用户最终验收。

## 已知边界

发布后被服务端以异常行为删除：DEFERRED_BY_USER，不修复、不重试发送；不能宣称可靠发布。历史未知表情/缺失原图、iOS 18/真机和 VoiceOver 未覆盖等限制继续保留。旧阶段失败不自动变为通过。

## 执行记录

证据目录：`Artifacts/VisualReview/R13/`。完整日志和私人截图保存在 ignored Artifacts，不纳入 Git。

- R12 提交前 lint/build/secret/diff 均 exit 0（R12/UserApproval）。R12 已提交 `60ea8d6`，未推送。
- R13 原始 `make forbidden` exit 2：direct-console（R11 两条临时 frame print）、direct-oslog（消息协议/Store 临时调试）、shared-singleton（图片导入 actor）。原 `make instructions` exit 0。删除临时诊断，不改错误传播；图片准备改编辑器持有的 actor。UI runner 改为启动设备并由 Xcode 覆盖安装，未删除测试或弱化断言。

- 首次新 iPad 回归未重新 generate，实际执行 0 项，不算通过（ipad-baseline.xcresult）。生成工程后原代码三次均残留旧帖，回归 exit 65（ipad-baseline2.xcresult，81.521s）。
- 最小修正：我的空详情也绑定自己的系统 NavigationStack；原三次场景通过，返回首页仍保留原帖（ipad-empty-stack.xcresult，64.514s，exit 0）。回归归入 IPadAppShellSmokeTests，完整门禁会继续执行。根因/边界补充 ADR-0003；未改共享列表/route/Store/图片/Session。
- 本地资源清点 132 张、399224 字节，逐文件 SHA/长度与来源表全部一致（emoticon-inventory.json）。README 改为实际功能与明确的发布审核限制，来源文档更新当前 14 roots / 234 Proto inputs、R11/R12 UI 与 132 张表情目录。

- 干净工作树首轮 Debug/Release 构建均 exit 0；Release 隔离 exit 2，发现 TestSupport 的 R04FeedFixture/R05ForumFixture 仍在编译输入（虽然受 UITESTING/TEST_SUPPORT 条件保护）。补齐 Debug/Release 排除，并排除后续纯 Fixture Repository 文件；没有放宽检查规则。
- 首次完整门禁停在全量 Unit。测试宿主采样明确为 R10ComposerEditorTests:79 的 `UIPasteboard.general.items` 阻塞；约 8 分钟无进展后中断，xcodebuild exit 73，其余取消条目不冒充功能失败。原始日志、宿主与 xcodebuild 采样保留。
- 复制测试改用独立临时命名剪贴板，生产默认仍为 general；不再读取/备份用户系统剪贴板。复制/剪切/粘贴、精确 token 与附件断言全部保留，未增加等待或跳过测试。

- 独立剪贴板原 3 项测试 exit 0（clipboard-isolated.xcresult，0.147s）。第二次完整门禁全量 Unit 526 项 / 含参数 601 次执行，0 失败/跳过（20260927-115857-46833-unit.xcresult）。随后 networking-isolation 发现已批准 R11 NotificationTargetRepository 未登记到精确 Core Proto 文件白名单，以及 R12 Search/Profile 装饰分隔线 overlay 触发旧 Feature 交互禁令。同步已证实 Core 文件（API_EVIDENCE R11 父楼解析条目），不加目录通配；分隔线改显式布局，无触摸覆盖，无弱化门禁。
- 干净工作树修正后 Debug 构建和 Release 隔离 exit 0（clean-final-build.log、clean-final-release-isolation.log）。后续展示布局修订需要重建候选再核验。

- 最终候选干净工作树再构建：Debug、Release 和 Release 隔离均 exit 0（clean-final3-build.log），已同步最后的 Search/Profile 普通布局分隔线修改。候选文件清单/哈希保存在 clean-candidate-files.json；无用户原有未跟踪文件、登录数据或私人截图输入。
- 第三轮完整门禁全量 Unit 仍为 526 项 / 601 次执行、0 失败/跳过（20260927-120310-36566-unit.xcresult，24.506s）；lint 为 0 violations / 372 files。Proto/JVM fixture、工程生成稳定性、静态 canary、网络/渲染隔离、Debug Keychain entitlement 和 Release 隔离已通过，iPhone/iPad UI 仍进行中。
- 受保护目录 52 个文件对照基线，仅 ComposerPhotoPreparation.swift 去掉全局 shared；VirtualizedList、Pager、MediaViewer、Forum/Thread/Recommendations、Session/Persistence 未改（protected-source-audit.json）。
- Live iPad 冷启动已观察恢复账号、真实头像、关注吧与最近访问；后续人工操作被 macOS 锁屏阻止，已请求用户解锁。未把 Fixture UI 结果冒充完整 Live 验收。

- 完整 iPhone Smoke 28 项中 26 通过、2 失败（20260927-120450-68202-ui-smoke.xcresult，1078.246s）；原样定向复跑两项均仍失败（smoke-original-rerun.xcresult，exit 65）。没有把 `make quality` 记为全绿：主命令在此 exit 2；后续只继续尚未执行的目标及失败项，不重复整套 Unit/Smoke。
- Stage18 大字号失败：导出的 XCTest 事件实际点击 `(21,171)`，截图中此处被放大的 Fixture 状态横幅覆盖；目标行仍在动态列表。测试改为按行/列表/窗口交集且避开可观察横幅的中心单击；原帖子、图片与 MediaViewer 语义断言保留，不改生产 UI。首轮定向通过（37.892s）。
- Renderer 原测试仍期待全篇 5 张图，而 R06 `imageGroupsStopAtEveryNonImageAndKeepViewerIndex` 已定义并验收连续图片组；当前样本节点 9–12 为 4 张一组，节点 16 在文字/视频/音频后另起一组。同步精确标签和 viewer `1 / 4`，不去掉加载/失败/尺寸/动作断言，生产 Renderer/MediaViewer 不变。
- UI 测试隔离脚本独立执行 exit 0（ui-test-isolation.log）；剩余 iPhone 与 iPad 门禁使用同一候选、独立构建目录和不同 Simulator，继续不卸载 App。

- 图片分组预期修正后的定向回归：Stage18 通过；Renderer 精确标签、加载/失败值、等尺寸检查已通过，但后续图片点击失败（smoke-targeted-fixed.xcresult，1/2，exit 65）。事件记录为 `(25,190)`，截图显示图片第一行在放大 Fixture 横幅后；按可见图片 frame 上滚并单击中心，仅改 UI 测试辅助，不改生产触摸/布局。新增辅助初放在 AppShellSmokeTests 触发 600 行/类型长度 lint；移到已有 ThreadContentUITestSupport 后定向 lint exit 0，未抬高阈值。最终点击回归待执行。
- iPad 剩余 Smoke 中本次 R13 三轮详情回归再次通过（66.899s）；此前常规/紧凑投影、5 页帖子/楼中楼/Media、3 页动态、搜索均通过。完整 Suite 尚未结束。

- iPad 完整 Smoke 最终 13 项 / 9 通过、4 失败（20260927-123211-74159-ui-smoke-ipad.xcresult）；独立 interaction 2 项 / 1 通过、1 失败（20260927-125357-79058-ui-interaction-ipad.xcresult）。图片缩放/翻页/旋转/关闭通过，失败没有涉及共享图片实现。常规/紧凑阅读用例曾等待 Simulator 旋转动画通知较久，采样主线程在 RunLoop 空闲；用例最终通过，不据此修改布局或增加超时。
- iPad 5 个失败原场景定向复跑仍失败（ipad-original-failures-rerun.xcresult，exit 65）。3 项期待竖屏 regular 三列，与已批准 R05 的“竖屏单列、横屏三列”契约冲突；测试改为先断言竖屏 compact，再转横屏确认 regular，并保留原 route、Pager ID/controller 与图片状态断言。
- 另 2 项历史按钮失败的运行时层级同时存在 My 中列和 Settings 详情列的 `settings.open-history`。原全局 query 多匹配，滚动 16 次仍无法得到唯一 hittable 元素；新增临时 frame 取值也因多匹配失败，日志给出两条完整所在层级。测试改为在传入的 Settings container 内查询，避免误点中列；临时 frame 诊断已移除。未改生产按钮或权限，修正后 5 项定向回归进行中。

- iPhone 完整 interaction 15 项 / 14 通过、1 失败（20260927-123534-41343-ui-interaction.xcresult，1989.601s）；缩放/旋转/复用/连续翻页均通过。唯一失败在系统返回后的目标：R12 把实验页入口移到 Settings，原测试却一跳期待 My。原样定向复跑仍失败（phone-final-renderer-original-back.xcresult），现按实际路径检查第一次边缘返回 Settings、第二次返回 My，保持系统手势与 Pager ID 断言。
- 同次 Renderer 定向没有通过：新增滚动辅助的单次 fling 把首图从顶部横幅后移到了底栏下（frame maxY 904.33、底栏 minY 784），可见性断言准确报错。已按当前图片 frame 与可用 viewport 的差距做小幅慢速拖动，保留完整可见范围和单击后 MediaViewer/intent 断言；不更改生产图片或加等待。Renderer、系统返回和受到查询辅助影响的两项 iPhone 历史/字号测试继续定向验证。

- iPad 5 项修正后定向全部通过（ipad-failures-fixed.xcresult，exit 0，包含 Pager 三轮投影）；iPhone 4 项定向 3 通过 / 1 失败（phone-failures-fixed.xcresult）。历史/清空、字号、两级系统边缘返回通过。Renderer 图片单击/intent/查看器/关闭均已通过，继续执行时才发现旧尾段 `n22` ID 不存在：R07 已将 `n19...22` 相邻文本合为单 UITextView，实际 AX 树 ID 为 n19，完整 label 仍含原尾句。定位改为当前块并断言原尾句、块末端实际滚入可见区；不把整块存在代替末尾可读。
- iPad 已覆盖安装干净 Debug 的完整 Live App，以无参数方式冷启动；主文件和 debug dylib SHA-256 均匹配候选（ipad-final-live-install.json），真实头像、最近访问和关注吧首页可见（ipad-final-live-home.png）。未卸载或触碰 Keychain；人工触摸浏览继续等待解锁。

## 自动化收尾及首次 Live 交付（解锁前历史记录）

最终 Renderer 1/1 通过（renderer-final.xcresult，103.811s）；原 intent、图片组、加载/失败、等尺寸、MediaViewer 关闭、未知节点及末尾文字可见断言均保留。iPhone 历史/字号/系统返回 3/3 已通过；最后 instructions、secret-scan、lint、forbidden exit 0（handoff-static.log）。

两台都已恢复完整 Debug Live（不是 UITesting/独立 Fixture 壳），无参数冷启动；主文件及 debug dylib 均与干净候选哈希一致，真实头像/关注吧已观察。停留首页供解锁后继续，截图为 `iphone-final-live-home.png`、`ipad-final-live-home.png`；本轮安装无 uninstall/erase/Keychain 操作，没有真实发送或 logout。

Mac 锁屏使 CUA 无法继续实际操作；已请求用户解锁，未尝试绕过。以下项目没有用 Fixture 结果代替 Live 结果：

- 动态分页、吧排序/分类横滑、帖子多页与完整楼中楼、图片/表情；
- 新帖/回复 Composer（只打开，不发送），回复我的/提到我的，搜索/历史/资料/设置；
- iPad full/narrow/full、前后台及断网重试，逐屏与 Android-target 并排对比。

自动化已覆盖对应的部分固定场景，但最终 Live 13 项仍需在解锁后完成。保持已接受的居中标题；发布审核问题继续暂缓。未输出 READY_FOR_USER_FINAL_ACCEPTANCE，未暂存/提交 R13，无 tag/push/IPA。

生产改动没有新增手势、动效、触摸 overlay 或第三方依赖。测试中的测量拖动属于 XCTest 输入，未进入 App；本轮真实缺陷只调整 iPad 空详情的系统栈边界，其余为门禁清理/隔离和来源文档。


## 解锁后 Live 验收与键盘修订（2026-09-27）

两台仍为上述哈希匹配的完整 Debug Live 候选；本轮没有改生产代码、重新构建或更换安装包。没有发送、上传、点赞、logout、uninstall、erase 或 Keychain 清理。真实账号截图仅在 ignored `Artifacts/VisualReview/R13/Live/`。

| R13 功能项 | 实际证据及边界 |
| --- | --- |
| 1 冷启动恢复登录 | PASS：两台完整 Live 恢复真实账号及头像，安装哈希记录沿用上节。 |
| 2 最近浏览/关注吧 | PASS：两台实际观察真实最近吧、关注吧头像/热度/等级；iPhone 保存 01-home-recent-followed.png。 |
| 3 动态分页 | USER_VERIFIED：用户手工确认持续下滑可加载下一页；AI 观察真实首屏并保存 02-dynamic-top.png。工具拖动未生效，不记为 AI 完成滚动。 |
| 4 吧首页排序 | PASS：实际从“最新”菜单选择按发帖时间，观察保留旧内容的重新加载及不同主题返回。 |
| 5 最新/精华/分类 | USER_VERIFIED：用户明确确认分类横滑正常；真实分类栏可见。 |
| 6 帖子多页/头像等级/多图 | PASS + USER_VERIFIED：用户确认帖子下滑加载下一页；实际打开真实帖子，头像/等级/中文日期可见。两图并排、MediaViewer 1/2→2/2、双击放大及关闭回原帖已观察。 |
| 7 完整楼中楼 | PASS（打开与首屏）：实际点“查看全部17条回复”，打开完整二级列表并观察父楼、真实作者/等级、@和官方表情；未逐条检查全部17条或另测楼中楼 Live 分页。 |
| 8 官方表情 | PASS（已观察内容）：消息、楼中楼和编辑正文均有实际内联表情。空回复草稿点选一个表情后正常渲染，随后通过原生选择/剪切清除，确认0字/0图再取消；未知资源缺口仍沿用历史记录。 |
| 9 新帖/回复 Composer | PASS（打开/输入区域）：真实吧新帖、真实帖回复均打开；断开 Simulator 硬件键盘后软件键盘可见且正确避让。新帖保持空白，回复测试草稿已清除，未发送。 |
| 10 回复我的/提到我的 | PASS：真实回复列表加载，点击具体回复进入完整帖子并定位一级父楼；提到我的实际为空态，未把 Fixture 非空样本当 Live。 |
| 11 搜索/历史/资料/设置 | PASS：打开本人资料、浏览记录、设置；使用触摸键盘输入 iOS 并提交只读搜索，实际返回吧列表。未清除历史或修改账号设置。 |
| 12 iPad full/narrow/full | PASS + USER_VERIFIED：实际旋转观察竖屏单列、横屏三列及同帖保留；用户确认窗口全宽→收窄→恢复时页面/位置保留，以及帖子→我的清除旧详情→首页保留原帖。AI 另观察我的右侧已为空详情。 |
| 13 前后台/断网重试 | PASS + USER_VERIFIED：实际通过系统 Home 进入后台，再点完整 TiebaLite 返回，吧首页与内容保留。用户随后提供截图确认断网刷新显示“重新加载失败，已保留原列表。”且列表仍在，并明确“重试能恢复我试过了”。断网及恢复重试由用户手工完成，AI 未操作系统网络，不以 networkOffline Fixture 代替 Live。 |

### 触摸键盘问题

用户先回答滚动/键盘正常，随后纠正为触摸键盘不出现；以后者为准。当前实测与 Simulator `I/O → Keyboard → Connect Hardware Keyboard` 有关：断开硬件键盘后，回复正文触摸键盘出现；取消后重新进入再次出现，新帖和搜索输入也实际显示软件键盘。截图为 `09-reply-software-keyboard.png`、`09-new-post-software-keyboard.png`。仅改 Simulator 输入设置，没有为此改 App 的焦点、输入 view 或 safe area。

CUA 的部分拖动/键盘事件未传入设备，iPad 横屏部分坐标操作返回 windowNotFoundAtPosition/noWindowsAvailable；旋转、点击及用户手工操作可继续。整理/缩放窗口未可靠解决工具问题，不能据此认定根因是窗口重叠，也不能当作 App 卡死证据。

### 最终视觉对照

本地 `Live/comparison.html` 将 Android-target 与本轮 iPhone 六屏并排，已逐屏查看：首页、动态、消息、我的、吧首页、帖子。平面主体、真实头像、小等级 chip、引用区、紧凑多图及底部动作结构保持；没有新增整行装饰卡片。保留 R04/R11/R12 已接受的功能入口差异、iOS 系统导航/安全区/键盘及居中标题；动态仍只显示已接入的数据入口，不伪造原版未接入的标签数据。账号、内容及服务端缺字段不同，不用截图的具体数值判定视觉一致。iPad 对照对应页面的自适应层级，未要求复制 Android 手机宽度。

截图还包括 `03-notifications.png`、`04-user-root.png`、`05-forum-home.png`、`06-thread-reader.png`、`07-full-subposts.png`、`09-reply-emoticon-editor.png`、`10-message-parent-anchor.png`、`11-settings.png`、`11-search-results.png`、`12-ipad-landscape.png`、`12-ipad-portrait-forum.png`、`12-ipad-my-cleared.png` 和 `12-ipad-windowed.png`。并排页仅在本机回环地址查看，临时服务已关闭，私人图片不纳入 Git。

### 当前出口

真实断网及恢复重试已由用户补证，R13 进入 READY_FOR_USER_FINAL_ACCEPTANCE，等待用户最终批准；这不等于自动提交授权。已执行的完整/定向自动化不重复跑；本轮只更新验收记录并做 diff 检查。候选不暂存、不提交、不 tag/push/IPA，发布审核问题继续 DEFERRED_BY_USER。没有新增生产手势、动画、overlay 或依赖。

收尾：iPhone 保留用户当前完整 Live 帖子阅读位置（iphone-final-thread.png），iPad 保留用户操作后的窗口状态。更新记录后 `git diff --check` exit 0，暂存区为空；本轮未重跑构建或 Unit/UI 矩阵。

### 用户补齐断网/重试证据（2026-09-27）

用户先确认“断网也保留原来的了”，截图明确显示刷新失败提示、重试入口与原关注吧列表；随后明确“重试能恢复我试过了”。私人截图保存为 ignored `Live/13-user-confirmed-offline-retains-list.png`。恢复重试结论来自用户手工确认，未伪称 AI 点击或记录网络响应。AI 读取当前窗口时完整 Live 已在吧首页；保持该页面与登录态，没有追加网络操作或发送内容。

仅更新 R13_ACCEPTANCE、TASK_STATE、VISUAL_PARITY_MATRIX；`git diff --check` exit 0，暂存区为空。生产候选及先前构建/测试证据不变，本轮未重跑 Unit/UI/build。R13 已可交付最终人工验收，仍须用户明确批准后才提交；既有发帖风控、未知表情资源、真机/iOS 18/VoiceOver 等已记录边界不因此消失。

## R13 用户批准提交

用户明确要求“先提交R13，然后尝试修复风控问题”。R13 以已验收候选精确提交，未改 UI，不纳入用户原有 Prompt/skill、私人 Artifacts 或参考 submodule。发帖风控排查在 R13 提交后作为独立工作继续，不能用后续未知修订替换本次已验收候选。沿用已完成的完整与定向测试；提交前定向 Unit（R10ComposerEditorTests + AppNavigationStoreTests）10 项 / 12 次参数执行、0 失败/跳过；instructions、secret-scan、make lint（0/372）、make build、git diff --check 全部通过。原始日志和 targeted-unit.xcresult 位于 ignored Artifacts/VisualReview/R13/UserApproval/。本次未重跑长交互矩阵。
