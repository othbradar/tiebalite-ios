# P03 — 真实吧内搜索与系统页面导航

## 目标与范围

2026-10-20，继续 P02 本地提交 `c87b60b` 后的当前工作树。用户补充官方 iOS 截图：复用首页搜索框；空输入显示历史；左侧主题/评论、右侧新帖/相关独立选择。用户随后明确拒绝底部半页弹层，覆盖 P03 提示词的旧 sheet 默认。本轮改为现有系统导航栈 push，不改根容器、不进入 P04、不提交 P03。

## 修改文件与设计

- `SearchQuery`、`Search`、`InForumSearchProtocol`、`SearchWebProtocol`、`ForumSearchResultMapping`、`LiveSearchRepository`：不可变 forum scope 与 keyword/type/mode/sort/page 一起构成请求和缓存身份；请求直接传 fname，整页验证归属，不过滤全局结果冒充吧内搜索。主题 tt1 / 评论 tt3，新帖 st5 / 相关 st2。tid、父 pid、cid 分离，重复命中按完整业务 ID 去重。
- `SearchStore`、`SearchListPresentation`、`SearchView`、`ForumSearchControls`、`ForumSearchResultRow`：继续使用原 VirtualizedList、图片 Loader、分页、取消和 anchor。主题卡片显示图片，评论展示当前正文及父回复/原帖引用，关键词高亮。失败保留明确错误；翻页失败保留原内容并重试同页。
- `SearchHistoryRepository`、`AppCompositionRoot`：本地最近 20 个有效去重关键词；Live 使用独立 UserDefaults key，Fixture 使用内存/隔离 suite。只保存关键词，不保存账号/请求/结果；跨吧点击同一历史词仍使用当前吧范围。空输入显示历史，可清空/展开。
- `ForumHomeDestination`、`AppRoute`、`AppNavigationStore`、`AppFeatureStoreRegistry`、`AppRouter`、`BookmarkIntegration`：删除搜索 sheet 和私有 NavigationStack/path，直接 push `.search(scope: .forum(...))`。现有 registry 在 root/settings route 存活期间保留 scoped store，pop 时取消释放。原 forum route 始终在栈中，保留原列表/排序/位置。结果走原 thread / pid 定位 / SubpostsView，三类来源均记录 `.search`。
- `FixtureSearchRepository`、合成 JSON/manifest、P03 单元/UI、P02 原 scope 测试、API/状态/路由文档及 ADR-0020 同步更新。保留全部原未跟踪 Prompts、技能配置和 Python 缓存。

无新自定义手势、动画、overlay 或依赖。吧内搜索框/取消动作放在系统导航栏同一行，保留系统 back button 与边缘返回；无额外标题行。使用已有系统 push/pop 和 Menu；不修改已验收发送/上传/签名/账号准备/成功回显/重试。WRITE_BASELINE 摘要未改。

## 参考与证据边界

指定私人 IPA 22.11.1 / 22.11.1.0，SHA256 `8b7daae086ef9d3f35cf1ea2004336e09cec83d7ec955d521ebe0d725cba9f15` 已核对。只定点核对 ForumNavigation 搜索入口及其官方 Hybrid 页面。具体符号/字段见 `Specs/API_EVIDENCE.md`，未重新逆向全包或复制私有资源。

经 jshook 读取入口所用公开 JS：fname、GET `/mo/q/search/thread`、分页和命中字段得到代码证据；两独立筛选的当前 JS 分支有 HarmonyOS 环境判断，因此不能称为参考 IPA iOS 运行时已启用。视觉按用户官方 iOS 截图，字段按已证模块；固定 ct1/cv22.11.1 的四组合有限匿名读取均 HTTP200/no0、结果范围正确。此前同词两个吧首屏及其中一吧第二页共三次匿名读取同样成功。只保留状态、类型、计数、归属布尔值，无正文/凭证进 Git。未知字段或服务端失败不偷偷改全局搜索。

## 执行的命令与回归

日志、xcresult 和截图均在 ignored `Artifacts/VisualReview/P03/`。直接 xcodebuild 使用项目 TiebaLite、scheme/testPlan TiebaLite、`-onlyUsePackageVersionsFromResolvedFile -skipPackageUpdates -parallel-testing-enabled NO`；DerivedData 与 SourcePackages 仍沿用仓库路径。

| 检查 | 结果 |
| --- | --- |
| P02 基线定向 Unit（baseline.log） | 6 项通过 |
| 旧 scoped 协议（scope-red） | 新回归按预期失败，旧实现拒绝 forum scope |
| 最终 `-only-test-configuration Unit`，P03ForumSearchTests / P02SearchTests / Stage16ASearchProtocolTests / R05ReadingShellTests（push-unit-final） | 19 项 / 4 suites 通过 |
| iPhone `P03ForumSearchSmokeTests` 两项（toolbar-keyboard-phone） | 2 项通过：无 sheet、提交收起键盘、筛选独立、第二页→帖子→结果原 offset、关键词/筛选、取消→原吧原排序/offset、历史重开/清空及系统边缘返回 |
| iPad `testIPadScopedSearchPagesReturnToOriginalForum`（toolbar-keyboard-ipad） | 1 项通过，包含提交收起键盘、第二页往返原 offset、历史及原吧排序/位置 |
| `make lint`（lint-final） | 623 文件 0 违规，冻结链路 23 项通过；已有未启用规则配置 warning 保留 |
| `make secret-scan`（secret-scan-final）、`git diff --check` | 通过 |
| `make build`（build-final） | Build Succeeded，SwiftProtobuf 锁定 1.38.1 未变 |
| 正常 Live 覆盖安装（install-final / profile-installed-proof） | 原 iPhone/iPad 均成功；三项产物摘要一致，原 6 份 iPhone 草稿/书签不变，iPad 原无对应文件 |

相关 Unit 覆盖同词 A/B/全局请求隔离、首次/下一页 scope、HTTP 字段、空/错误/范围错误、迟到取消、分页失败重试、mode/sort 缓存和 anchor、历史持久化/去重上限、多个楼层命中及父子 ID、原生导航路径与搜索来源。按 COMMON 只运行定向回归和轻量构建，未跑全量 quality/Pager/压力矩阵。

### 失败与修正（未隐藏）

- `unit-green` 测试宏嵌套 require 编译失败；拆分表达式。`unit-green-2` 两处错误断言未考虑 EndpointExecutionError.mapping 包装；按现有 adapter 合同修正。随后 `unit-final` 14 项通过。
- 首次 lint 五处风格、`lint-controls` 四处风格/文件长度超限，局部拆分/排版后通过；没有放宽规则。
- `ui-phone` 首次 sheet 内容为空：Boolean 与可选 store 捕获不同步，曾改为单 item；该实现后来被用户明确要求的 native push 完全替代。
- `new-controls-red` 用了不存在的测试配置 `Unit Tests`，未执行任何测试，不计红灯。`unit-controls` 当时 sheet 所需 Identifiable 隔离编译错误修正；最终 push 已不需要该 conformance。`unit-controls-2` 与 `unit-delivery` 各 15 项通过。
- `ui-ipad-controls` 误选 sheet 下方不可用导航按钮；定位修正后 `ui-ipad-final` 通过，`ui-phone-controls` 通过。这些是旧 sheet 的阶段证据，不代替最终 push 检查。
- `push-red` 单方法 selector 未加 Swift Testing 括号导致零项，不能称为通过；随后 `push-red-suite` 实际执行，新导航回归失败。加入现有 forum→scoped-search 路由后 `push-unit` 暴露 profileReply 未保存搜索来源的两处失败；补入现有 readingEntries 后最终 19 项通过。
- `push-ipad` 的通用“第一个可点击导航按钮”误点侧栏 followed-forums.reload；改为系统 `BackButton` 的可点击实例，未修改产品返回或削弱位置断言。最终复验结果见下。

### 隐藏导航栏的边缘返回回归

Live 两次拖动及 `edge-back` 固定 Fixture 重现：取消可返回，边缘 pop 不生效。LLDB 仅输出导航栈深度/栏可见性/手势启用布尔值/类名：栈深3、hidden=true、enabled=true；没有读取账号或内容。局部 delegate 尝试 `edge-phone-green` 仍失败（普通往返通过、边缘失败）；已撤掉该桥接及实验 Unit 文件，最终没有修改 InteractionKit。

隔离 Fixture 中的临时 delegate=nil 对照也未解决，原 Live 未接受这些实验；动态检查只作用于测试 App 并已 detach。一次读取 delegate 决策表达式编译失败后修正；曾尝试附加已结束测试进程失败、向已关闭测试模拟器启动失败，均非产品结果。隔离样本首装误用了 Debug 产品，确认后换 UITesting 产品；原用户模拟器没有被装测试壳。

`edge-visible-control` 单变量改为显示系统栏后边缘测试通过。最终重排现有搜索框到 principal toolbar、取消到 trailing，删除额外标题行，完全保留 UIKit 返回处理。`native-toolbar-phone` 边缘通过，普通往返初始历史断言因容器 AX 类型变化失败；视频清楚显示历史标题和清空按钮，改为检查这两个实际控件（保留所有往返/offset/筛选断言）。最终复验见下。

### iPad toolbar 输入焦点

`native-toolbar-ipad-final` 暴露返回 offset 变化：视频显示提交后键盘仍在，而打开帖子才收起；前后 viewport 高度不同。新增提交后键盘消失断言，`toolbar-keyboard-red` 按预期失败。搜索框在系统 toolbar 的独立 hosting 中，原内容 FocusState=false 没有结束实际输入会话。显式提交/筛选时同时调用标准 responder resign action；不增加延时、手势或修改 anchor。`toolbar-keyboard-ipad` 全路径通过，原 offset 断言仍为 ±14pt，没有放宽。

## 正常 Live 安装与停点

最终 Debug 完整 App 覆盖原 iPhone 17 Pro / iPad Pro 13-inch (M5)，无测试参数、无卸载/erase/注销。签名及内嵌 entitlement 检查通过，主程序/debug dylib/Info.plist 与最终构建摘要一致；安装后和最终停点再次确认原草稿/书签摘要不变。iPhone 真实高通吧→搜索历史“手机”→主题结果成功。iPad 从现有逛吧记录进入高通，空历史页、输入“手机”、主题结果成功。iPhone 最终停在真实吧内历史页，iPad 停在真实吧内搜索结果页，均为整页系统导航。私人截图只在 ignored Artifacts/VisualReview/P03：20261020-120356-live-full-page-phone、20261020-121915-live-full-page-ipad、20261020-121916-live-history-phone。

CUA 在旧 iPad Simulator 窗口多次返回 windowNotFoundAtPosition，AX 与窗口图像可读但坐标不能命中。刷新 CUA、调整显示大小未解决；仅重开 Simulator 窗口/原设备后点击恢复，未修改产品代码或清理数据。重开使原 App 重新启动，已重新从真实入口恢复两台停点；不把这一步当作页面返回回归证据。返回/offset 证据来自最终两端固定 UI 测试。iPad 首页关注列表本轮出现已有加载失败，使用现有逛吧记录进入，未调查或声称修复该独立网络/账号问题。

## 追加：进入搜索时取消按钮的白块（2026-10-20）

目标：修复进入搜索后取消文字内约1秒的白色矩形；用户随后明确要求取消胶囊。本轮仅产品文件 SearchView.swift 及进度/审计记录改变，既有P03差异保留，未改搜索协议或发送行为。

复现：原iPhone17Pro/iOS26.5，浅色竖屏，正常Live高通吧→导航栏搜索→取消，连续3次。`cancel-flash-baseline.mov`及`cancel-flash-baseline-frames.png`记录进入到稳定的变化；不需要提交搜索或网络结果。LLDB只读导航栏子树显示取消动作走SwiftUI UIKitBarItemHost，host opaque=true、background=nil；默认玻璃platter过渡时出现文字大小的不透明矩形。分类为导航栏渲染/过渡，不是异步搜索状态或图片加载。UIKit内部如何生成该快照未进一步逆向。

第一次控制实验仅移除font/foregroundStyle改用tint，`cancel-flash-fixed-phone.mov`仍清楚出现白块；该实验失败，不能归因为字体修饰单独造成，已经撤销。最终使用plain文字按钮，并在iOS26为此ToolbarItem关闭共享玻璃底座；保留44pt点击区域、ID、系统导航栏与dismiss。iOS18–25有availability分支，不调用新API。无新增动画、手势、overlay或依赖，也没有遮罩、延时或全局禁动画。用户已明确接受去胶囊方向。

原录屏经ffmpeg按100ms取顶部取消区域作对照；`cancel-plain-transition-frames.png`显示完整进入过程无矩形白底。`cancel-plain-phone.mov`保留重复进入记录，iPad `cancel-plain-ipad.mov`记录3次进入/取消。此类短暂渲染问题以录屏帧作为红/绿视觉证据，既有XCUITest等待系统稳定后才截图，不能声称它直接检测到了瞬时白块。

| 本轮命令/产物 | 实际结果 |
| --- | --- |
| `make build`（cancel-flash-build，随后cancel-plain-build） | 两次构建均通过；前次视觉实验失败，最终plain版本用于交付 |
| `make lint`（cancel-plain-lint） | 623文件0违规，WRITE_BASELINE_PASS 23项 |
| `make secret-scan`（cancel-plain-secret）、`git diff --check` | 通过 |
| 既有P03ForumSearchSmokeTests iPhone2项（cancel-plain-phone-ui） | 通过，取消、键盘、范围/筛选/历史、分页往返原位置及系统边缘返回 |
| 既有P03 iPad单路径（cancel-plain-ipad-ui） | 1项通过，横屏搜索/取消及原位置保留 |
| 原两台正常Live覆盖安装（cancel-plain-install） | 成功；签名/entitlement通过，主程序/debug dylib/Info.plist摘要一致，原草稿/书签保留 |

没有新增镜像实现的测试或重跑业务Unit/全量quality。两次LLDB表达式因ObjC泛型类型解析失败，改为id容器后只读检查成功，已detach；未对运行时UI作修改。CUA起初旧窗口输入报错，重开Simulator后恢复，未erase或卸载，不以重启作为修复证据。最终截图`20261020-151825-cancel-plain-live-phone/ipad.png`保存于ignored Artifacts，iPad停在真实搜索历史页。真机、旧系统与深色过渡未在本轮验证；用户视觉复核后才能提交，未进入P04。

## 追加：搜索框转场顶部横条被裁切（2026-10-20）

目标与范围：用户报告进入和交互式返回时搜索框顶部短暂缺失。在当前P03工作树继续，仅调整TiebaSearchBoxSurface/SearchView的导航栏几何，并扩充既有P03ForumSearchSmokeTests；既有P03及取消纯文字修改全部保留。

根因/红灯：共享surface原minHeight=48、vertical padding=12，实际系统principal title容器为44pt。固定forumHomeParity场景进入搜索后，新增搜索框上下边界必须位于包含search.field的navigationBar内的断言。`search-top-red`实际1次失败，`search-top-red-repeat`用`-test-iterations 2`再失败2次，均为box.minY=92.333333、bar.minY=94.333333；xcodebuild退出65。不是请求/缓存或页面身份变化，是布局越界在转场裁切中暴露。

修复：共享surface新增placement，默认content保持48pt/12pt；只有scoped SearchView的principal搜索框选择navigationBar，使用minHeight44/vertical padding10。仍是最小高度而非固定裁切，字体/颜色/圆角及原44pt按钮命中区域保留。无新状态转换、自定义动画、手势、overlay或依赖；系统导航和返回delegate没有改变，发送/签名/请求次数完全未动。

命令使用既有project/scheme/testPlan TiebaLite、UI Smoke、固定fixture，DerivedData/锁定依赖不变。全部日志及xcresult位于ignored `Artifacts/VisualReview/P03/`：

| 命令 / 产物 | 执行结果 |
| --- | --- |
| `xcodebuild test ... -only-testing:TiebaLiteUITests/P03ForumSearchSmokeTests`，iPhone排除iPad方法（search-top-phone） | 退出0，2项通过：新增上下边界断言、搜索筛选/历史、分页往返原位置、键盘、取消及边缘返回 |
| 同命令iPad单方法testIPadScopedSearchPagesReturnToOriginalForum（search-top-ipad） | 退出0，1项通过，横屏布局和往返位置 |
| `xcodebuild test-without-building ... -only-testing:TiebaLiteUITests/P03ForumSearchSmokeTests/testScopedSearchSupportsSystemEdgeBack -test-iterations 3`（search-top-edge-repeat） | 退出0，3次通过；边界断言和系统拖动返回均成功 |
| `make lint`（search-top-lint） | 退出0，623文件0违规，WRITE_BASELINE_PASS 23项；保留已有规则配置warning |
| `make build`（search-top-build） | 退出0，Build Succeeded，SwiftProtobuf仍锁定1.38.1 |
| `make secret-scan`（search-top-secret）、`git diff --check` | 退出0 |
| `bash Artifacts/VisualReview/P03/install_live.sh`（search-top-install） | 退出0；原两台正常Live覆盖安装，三项产物摘要匹配、iPhone原6份草稿/书签不变、iPad原无对应文件 |

视觉：原iPhone真实高通吧入口→搜索→系统返回按钮→再次进入，`search-top-fixed-phone.mov`保留过程；按100ms取帧的`search-top-enter-frames.png`和`search-top-pop-frames.png`显示顶部圆角/横边在转场中保持完整。CUA手工edge drag未触发实际pop，因此不计手工手势通过；手势通过证据来自上述真实执行3次的固定XCUITest。额外simctl测试录屏没有捕获完整测试搜索过程，不用于视觉结论。原Live iPad从首页高通进入搜索，顶部完整；横屏布局与往返由固定UI测试覆盖。

正常Live两端停点截图：`20261020-155435-search-top-live-phone.png`和`20261020-155435-search-top-live-ipad.png`，都在真实高通吧的搜索历史页。未卸载/erase/注销/清缓存，未暂存/提交/推送。未重跑业务Unit或全量quality；本轮未验证真机、旧系统、深色与最大辅助字号的转场，不把默认字号几何通过外推到这些场景。用户视觉复核后才可提交/进入下一阶段。

## 未解决风险 / UNKNOWN

- 未验证真机或服务端长期稳定性；匿名成功不等于官方 iOS 全部头部/私有 SDK/实验行为完全一致。
- 子回复搜索结果进入正确父楼三级页面，未新增指定 cid 自动滚动定位。
- 分享使用现有系统 ShareLink，点赞只显示结果计数；未执行任何远端发送/点赞/关注/删除。

## 下一阶段前置条件

状态 READY_FOR_USER_VISUAL_REVIEW。用户确认视觉/交互后才可提交 P03；当前未暂存、提交、推送或进入 P04。

## 用户验收与提交授权（2026-10-20）

用户确认无问题并授权“提交并进入P04”，覆盖前文等待验收状态。验收后产品代码未修改；提交前make lint（accepted-lint，623文件0违规、冻结23项）、secret-scan（accepted-secret）及diff检查再次通过。只本地提交已验收P03文件，不推送，未跟踪任务提示词/技能配置/缓存保留。P04先进入候选选款。
