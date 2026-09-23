# R06 帖子阅读整改

状态：USER_VISUALLY_APPROVED。2026-09-23 用户明确“可以这次看起来没问题了，提交R06进入R07”，授权提交本阶段并进入 R07。R05 提交为 50c5cb2，未推送。1000楼手工快速滚动未采集的历史验证缺口保留。

提交前复核：Artifacts/VisualReview/R07/r06-approval-* 保存本轮结果；Unit 22项/5 suites通过，R06ThreadSmokeTests 两项通过（51.639s），make lint / make build 通过。仅运行定向检查，未运行完整 quality 或长矩阵。此前失败与修订记录原样保留；人工批准以完整 Live 应用的日期和顶部吧头像修订为准。

人工交付修订：用户指出独立样本页无法验收完整体验。现已移除两台的 --r06-thread-parity 启动参数，正常打开完整App；iPhone既有登录态恢复关注吧列表，并从高通吧进入真实帖子“低频能效p用没有”。头像、等级、正文、图片和回复条已观察并停留，最终Live截图为 iphone-live-review.png。未读取/修改凭证，未卸载或清Keychain；仅操作运行中的App，无新增代码或回归测试。先前固定样本截图保留为辅助证据，不能替代用户在完整应用里的验收。

## R06 日期与顶部吧胶囊修订

用户反馈原文：“这个日期用中文，或者说这里面所有的日期都用中文，然后这个顶部高通吧的字样移动到返回键右边顶部栏里面不要跟下面的滑动帖子流放一块然后高通吧的药丸型图标加长一点里面左边放上圆形的吧头像”。

当前差异：PBPage日期fallback与吧内旧日期依赖系统locale，历史relative Text同样可能显示英文；帖子吧chip属于虚拟列表header row，而Android ThreadPage.kt:1873–1920 TopBar在固定toolbar内以Avatar+Text展示。用户要求返回键右侧，采用系统topBarLeading，不定制返回键/手势。真实头像证据为PBPageResponseData.forum#2 → SimpleForum.avatar#4/id#1，沿用既有TiebaAvatarResource及ProductionImageLoader，不合成URL或增加请求。

计划只改日期展示、帖子toolbar及对应论坛头像字段投影；将header移出列表，所有post/footer ID和分页架构不变。Store只需在合并页时保留新增头像字段；不改并发/anchor算法。用中文固定locale+公历，保留本地时区；动态/吧内旧日期和历史日期同步覆盖。短Unit验证格式/字段缺省/稳定楼层，短UI验证顶部头像与滚动前后固定位置。风险是系统toolbar默认玻璃容器叠加、分页响应缺头像造成闪空以及日期受系统语言影响；使用独立chip背景、字段保留及明确locale解决。无全量quality或长交互矩阵。

修订日志位于 Artifacts/VisualReview/R06/ToolbarRevision/：

- red.xcresult：新增2项日期回归在旧实现记录4个失败，exit65，确认帖子/吧内/动态绝对日期没有中文年月日。
- unit.xcresult：首轮19项中1项测试期望错误，系统zh_CN shortened小时为“4:59”而非补零“04:59”；调整测试遵循标准中文短时，不修改时区断言。其余18项通过。
- unit-verified.xcresult：20项/5 suites通过，包含中文日期/时区、R06字段与布局、原1000楼虚拟化、R04时间、已有R01头像Cell复用。原UIKit测试打印visibleCells更新期间访问警告，测试未失败，未据此改共享列表。
- iphone.xcresult：短UI在toolbar宿主与内容重复暴露同一个AX ID时查询歧义，exit65。层级同时证实Text宽度为0；给胶囊提供受限的内容理想尺寸后文字可见，测试明确选toolbar最外层同名host并额外断言文字宽度>20，而非只绕过失败查询。
- iphone-verified.xcresult 1/1，13.257s；ipad.xcresult 1/1，15.360s。均验证头像加载、吧名位于返回右侧/列表上方、列表内不再有header、真实swipe改变内容而chip frame不变。
- 截图发现iOS26系统还给自带背景的chip叠加了玻璃底。依SDK可用性为该ToolbarItem关闭sharedBackground，保留系统返回按钮，随后重跑相同短UI并正常构建；不自定义导航手势或overlay。
- ThreadReaderStore仅新增一行头像保留，protected.json中其余22个InteractionKit/图片/Session文件hash未变；不再将Store记为逐字未改。所有楼层和footer业务ID、分页及anchor算法未改；只将吧信息header移出可滚动列表。

新增TiebaDateText以明确zh_CN、公历和当前时区展示应用绝对日期；PBPage优先数值timestamp，缺失才保留接口提示文本。浏览历史的系统relative Text单独指定中文locale。帖子图中文字、正文中用户自行写入的日期不作篡改。新吧图使用现有资源规则，无新图片系统、CDN Cookie、手势、动效或依赖。

最终结果：iphone-final.xcresult 1/1（13.399s）、ipad-final.xcresult 1/1（14.215s），均exit0；make lint（lint-verified.log）、make build（build-final.log）、静态/网络/凭据扫描及git diff --check均exit0。仅上述定向验证，没有全量Unit/quality/长交互。两台正常Debug覆盖安装且无Fixture启动参数；未卸载、erase、清Keychain或退出账号。

iPhone经“我的→浏览历史”回到用户同一真实帖子“iPhone18Pro的QLC硬盘性能影响有点大啊”：顶部返回键右侧灰色胶囊显示圆形高通真实吧图，列表从作者开始，日期实际显示“2026年9月20日 12:59”。历史列表的相对时间也显示中文分钟/秒。前后对比 `ToolbarRevision/user-before.png` → `ToolbarRevision/iphone-live-after.png`。iPad完整App已恢复真实关注吧列表，当前停施德楼吧，吧内旧日期“2026年9月22日”实际可见，截图 `ToolbarRevision/ipad-live-after.png`；帖子toolbar固定位置的iPad证据为ipad-final.xcresult附件。CUA在iPad额外导航时报告前台改变，按新画面观察后不扩大手工操作。

本修订READY_FOR_USER_VISUAL_REVIEW；未暂存/提交，不进入R07。此前1000楼手工连续滚动未确认的限制不被本次短滚动或Unit覆盖替代。

## 范围和证据

显式使用 tiebalite-android-visual-parity。读取根及 App/Core/Features/DesignSystem/Tests/UITests/TestSupport/Docs/Specs 指令链，PROJECT_RULES、ANDROID_UI_REFERENCE、视觉矩阵、R06 提示词及 ADR-0026。Android UI 锁 c5f1125f42498e49db4e4a9cb66313b8c8a285c7，参考截图 06-thread-reader.png。

- ThreadPage.kt:194–208 时间/楼层/author.ip_address；2010–2278 PostCard 的 UserHeader、UserNameText、author.level_id / threadAuthorId / bawuType、post.agree.diffAgreeNum、正文缩进和浅色子回复块。
- 同文件2199–2216 以非图片打断连续图片组；PbContentRender.kt:302–350 当前 Android 使用宽度自适应 waterfall。R06 提示词明确要求紧凑 TiebaMediaGrid、一行最多4张，因此此处遵循本阶段明确要求，不照搬手机每图一行。
- ThreadPage.kt:1923–2004 底部头像、评论、点赞和更多；2285–2400 SubPostItem / UserNameText。ThreadViewModel LoadFirstPage/LoadMore 使用服务端 page、post IDs；既有 PBPage 分页不改。

当前 iOS 差异：header/floor 大卡、作者左右布局；真实头像/等级停在领域层；Renderer 每图整宽；子回复 prefix(4) 且全部链接不可点；无回复条。

## 计划 / 约束

只改 hosted floor、renderer 分组、所需数据字段、Feature route callback、隔离 Fixture 与定向测试。保持 ThreadReaderRowID、VirtualizedList/UITableView/Diffable/UIHostingConfiguration、Store 分页/anchor、Pager、MediaViewer、ProductionImageLoader 和 Session。Grid 增加保留比例的内容插槽，原 feed 调用默认布局不变。新增 bottom safeAreaInset 是真实评论入口，不重新引入根栏或白色空占位。评论/点赞均仅本地未开放提示，不发送请求。

先以前三条上限回归及分组/索引/缺字段测试定义行为；再平面化楼层，添加短 iPhone/iPad Fixture smoke、1000楼一次滚动。执行 ThreadReader/Renderer/Grid 相关 Unit、既有图片复用、lint/build/diff；不跑完整 quality 或长 Media interaction。

风险：原比例网格在可变宽度下的高度、Cell图片任务取消、底栏与刚修复安全区边界。以稳定几何、已有加载任务、实际 frame 和返回 route 验证。官方表情视觉留 R07，全楼中楼留 R08，写操作留 R09。

## 基线

R05 提交前与 R06 基线：Unit 37项/7 suites exit0（baseline-unit.xcresult），lint/build/static/secret扫描 exit0。尝试暂存用户 R05 prompt 后 staged diff-check 报原文件Markdown尾空格；已将该prompt移出暂存并保持原文，54个R05文件提交成功。期间若干读取旧/不存在路径的命令失败，后以rg定位，无文件覆盖。旧Stage17和连续旋转自动化问题沿用R05记录，不作为本阶段已解决。

## 迭代记录

- preview-red.xcresult：前三条上限的1项测试在原实现按预期失败（返回4条/remaining8而非3条/9），exit65。
- build-first.log：Layout 内容插槽使用错误的初始化参数导致编译失败，修正为 Layout 的 ViewBuilder 调用；build-second.log make build exit0。lint-first.log exit0。
- 回复条通过 safeAreaInset，帖子列表的下边界明确改为回复条上沿，吧页仍贴屏幕底边，ADR-0026 同步说明。

- unit.xcresult：42项/7 suites exit0，包括新 R06、原 ThreadReader/PBPage、1000楼身份/分页、Renderer、Grid、头像 Cell 和 LaunchScenario。该次 ThreadContentImageRenderStateTests selector 名称未匹配（实际 suite 为 ThreadImageRenderStateTests），不计该项；后续单独补跑正确 suite 与 Stage19ImageCellReuseTests。
- lint-second/third：先报 Factory 超1行、参数对齐和imports顺序；均仅格式修正。lint-fourth/static/network/secrets exit0；没有修改allowlist。
- iphone.xcresult：回复条的 accessibilityIdentifier 被传到所有子元素，测试查询歧义，exit65；增加容器 children:.contain 让回复条保留独立标识，子按钮仍可访问。
- iphone-bar.xcresult：布局/4图索引/三条预览通过，后在路由 value 断言发现 SwiftUI 将数值按locale显示为100,001/60,001；测试改为相同标准formatted()，未改业务ID、容差或超时。
- iphone-verified.xcresult：1/1，36.357s，exit0；验证全部六种图片数量，4/5索引、关闭返回位置、三条预览/全部路由/返回、只读评论提示、列表贴回复条。截图为固定样本，不冒充Live。
- 首轮Fixture使用既有1像素图片，虽已解码但不足以观察原比例；改为编号且尺寸匹配的固定本地位图，经同一个ProductionImageLoader的隔离transport解码/复用。正常Debug和UITesting共用该Fixture；Release不可达，没有第二套生产图片缓存。

- ipad.xcresult：同一条短 Smoke 1/1，49.934s，exit0；编号位图、全部六种数量、Viewer索引、预览/route/返回、回复条边界以及竖转横均通过。
- image-unit.xcresult：19项/3 suites exit0；正确的 ThreadImageRenderStateTests、已有 Stage19ImageCellReuseTests 和 R06ThreadPresentationTests，补齐图片状态、取消/复用及分组映射回归。
- build-final.log：正常Debug的Fixture replies.map触发Swift类型推断超时，exit2；抽取类型明确的subpost helper后，build-verified.log make build exit0，lint-verified.log make lint exit0（297文件、0违规）。没有改生产逻辑以绕过编译或断言。
- static-final/network-final/secrets-final 和最终 git diff --check 均 exit0；protected-final.json 记录 InteractionKit、Core/Images、Core/Session 与 ThreadReaderStore 共23文件 SHA 未变。未运行全部Unit、make quality、长Pager/MediaViewer矩阵。
- 正常Debug已覆盖安装iPhone 17 Pro/iPad Pro 13-inch，未卸载/erase/清Keychain。两台均以 --r06-thread-parity 打开隔离样本，最后同屏显示4图、前三条预览、查看全部7条和回复条；iPhone前台，iPad竖屏。最终截图为 iphone-review.png / ipad-review.png。
- 原 --stage15-long-thread-lab 已打开1000楼Fixture，观察到前部楼层；CUA scroll/drag 多次未得到可确认的连续滚动结果，并有一次工具报告前台窗口被切换。保留 iphone-long-fixture-observed.png；这不是性能通过证据。1000楼五页追加和稳定身份Unit已通过，快速滚动手工项仍 NOT_VERIFIED，不宣称性能无回退，不为此扩大测试矩阵。

## 修改文件与状态

- Core：TiebaUserVisuals / TiebaUserVisualMapper 传递真实IP字段；FixtureReadingFlow / PBPageDomainMapper 传递真实agree差值，缺字段保持nil。
- ThreadReader：ListPresentation保留整层业务ID和分页，前三条子回复保留作者数据；ThreadContentBlocks按连续图片分组；ThreadContentRenderer复用原图片任务；ThreadReaderFloorViews平面行/回复条；ThreadReaderView接入已有route回调。
- DesignSystem：TiebaMediaGrid新增按原比例排列的内容插槽，原feed默认布局不变。
- App：AppRouter连接已有SubpostsUnavailable route；帖子有真实safeAreaInset后取消该destination的底部ignore，吧页不变。AppCompositionRoot、TiebaLiteApp、DebugStage15ThreadProbe和新增DebugR06ThreadFixture仅接入隔离验收样本。
- Tests/TestSupport：R06ThreadPresentationTests、R06ThreadSmokeTests、LaunchScenario及工厂/契约/测试；R05ReadingBottomEdgeTests更新帖子应贴回复条的几何预期（该旧test本轮未重跑，相同边界由新Smoke验证）。
- 文档：本记录、TASK_STATE、VISUAL_PARITY_MATRIX、ADR-0026、API_EVIDENCE、CONTENT_NODE_MATRIX。

既有Store的加载/刷新/连续分页、anchor、Cell清理、图片任务取消及MediaViewer ownership保持不变。没有新增自定义动画、手势、overlay或生产依赖；新增系统alert用于明确提示写入未开放，沿用既有全屏图片查看器。

## 命令与证据

所有日志/xcresult/截图保存在 Artifacts/VisualReview/R06/。定向测试使用 xcodebuild test、TiebaLite scheme、TiebaLite testPlan、Unit或UI Smoke配置、明确的 -only-testing selector、-parallel-testing-enabled NO；结果与失败见上方逐项记录。

- Unit主轮选择：R06ThreadPresentationTests、Stage15ThreadReadingTests、Stage15ThreadListVirtualizationTests、ThreadContentRendererContractTests、R01VisualPrimitivesTests、R01AvatarCellReuseTests、LaunchScenarioTests。
- 图片补轮选择：ThreadImageRenderStateTests、Stage19ImageCellReuseTests、R06ThreadPresentationTests。
- iPhone/iPad各选择 R06ThreadSmokeTests/testFloorGridViewerSubpostsAndReplyBar；无放宽超时或几何容差。
- make lint、make build、scripts/forbidden_patterns.sh、scripts/verify_networking_isolation.sh、scripts/secret_scan.sh、git diff --check；以各日志实际命令为准。
- xcrun simctl install 覆盖安装 Debug-iphonesimulator/TiebaLite.app；simctl launch --terminate-running-process 仅用于切换明确的Debug样本入口；simctl io screenshot 保存截图。

## 已知限制与下一阶段前置条件

视觉待用户查看Simulator批准；1000楼连续快速滚动尚待手工复核，不能用Unit替代性能结论。本轮没有使用真实凭证或验证Live帖子；截图内头像、等级、IP、数字和位图均为明确固定样本。生产仅映射实际接口字段；底部账户头像当前为中性占位，不冒充已接入账户资料。

官方表情留R07，完整楼中楼留R08，真实写入留R09；不提前实现。R05历史Stage17基线失败和连续旋转自动化限制仍保留，不因本次单条Smoke通过改写为已解决。R06只有用户明确批准后才允许提交并按新指令进入下一阶段。
