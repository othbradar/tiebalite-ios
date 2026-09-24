# R07 官方表情内联

当前状态：USER_VISUALLY_APPROVED（2026-09-24）。用户查看完整Live候选后反馈：“可以了我看了，基本上表情都加载了”。本次127资源目录修订获人工确认；用户随后明确授权“提交R07进入R08”。提交前11项定向Unit、原表情短Smoke 1/1（20.422秒）、make lint（307文件0violations）、make build、secret scan及diff check通过，证据为Artifacts/VisualReview/R08/r07-approval-*。下方READY及失败记录为验收过程历史。

状态：READY_FOR_USER_VISUAL_REVIEW（2026-09-23 本次授权续作）。完整 R07 候选已恢复并覆盖安装；未暂存、未提交，不进入 R08。前次停止/撤回与失败命令保留在下文历史记录，不能作为当前版本结论。

## 2026-09-24 全量目录修订（取代上次单独补67的交付）

用户反馈原话：“你只修捂嘴笑？我都说了还有别的表情没渲染”，新截图显示 `#(微微一笑)`。上次把整批资源缺口收窄成单个别名修复，不满足用户意图。本次按目录完成整批覆盖。

**根因与范围**：Android锁定的默认编号集合共104项，iOS上次只有52项。Android通过Proto type2登记名称，而最初移植只拿到51个drawable和不完整静态名称表。已取齐余下52张默认图片；还从官方网页元数据确认23个扩展（102…124）及原图，合计127张/379540字节。微微一笑=91由用户对应公开帖的匿名PBPage返回独立证实。

**改动**：TiebaEmoticonRegistry从完整ID/名称目录投影别名；新增75个原PNG，来源URL/哈希逐项记录在Resources/TIEBA_EMOTICONS_PROVENANCE.md。名称来自Android映射及官方web模块174的事实表，没有猜测。正文/子回复/摘要继续共享既有parser和builder。62/86两个吃瓜显式节点保持原ID，普通文本按官方editor选86；生气61与web语法31兼容保留。验收样本加入微微一笑、吃瓜、鼠2，并增加完整App内“全部127个官方表情”只读目录入口。

未修改原生链接/选择/复制/滚动边界、业务ID、Store、Repository、Proto、Session、共享列表/Pager/MediaViewer/图片系统。无新增生产网络请求、Cookie、ATS豁免、缓存、依赖、动画、手势或overlay。36个受保护文件哈希保持一致。未知未来ID/名称仍保留原文；51…60没有来源依据，不擅自填图。

**已执行验证**（Artifacts/VisualReview/R07/FullEmoticons）：

- red.xcresult：新增全量节点/跨系列名称回归先失败，7项parser中新增2项失败（116条断言，exit65），原用例仍通过。
- green.xcresult：仅R07 parser/builder共11项通过（0.132秒，exit0），覆盖全部127显式节点/本地图片解码、各系列名称/三种语法、复制替代文本、未知降级、链接顺序、选择保留和字号。
- phone.xcresult：原单击链接+正常/大字/深色用例增加微微一笑/吃瓜/鼠2断言，1/1通过20.307秒，未改超时/点击次数。
- ipad.xcresult：同一短用例1/1通过21.426秒。
- lint.log：make lint通过，307文件0violations；secrets.log扫描通过。未跑完整quality/全Unit/长交互矩阵。
- Android静态HTTP路径102…124返回404，保留在asset-manifest.json；从官方web renderer已证实的HTTPS图片源取得全部23张，extended-asset-manifest.json逐一记录200和SHA。无TLS绕过。
- 修订前user-before.png；正常/大字phone-normal.png、phone-large.png、ipad-normal.png、ipad-large.png。实际看图确认微微一笑、捂嘴笑、吃瓜、鼠2在文字行内，链接intent也实际到达。

最终构建与安装：make build exit0（build.log）；iPhone/iPad正常Debug完整Live App均覆盖安装，无uninstall/erase/Keychain清除。installed.json验证两台二进制与本次Debug构建一致、全部127张资源字节一致。iPhone通过浏览历史回到用户反馈帖；工具尝试定位时报告用户正在操作，重新读取画面后原第7楼已显示微微一笑原图，实际Live截图iphone-live-floor7.png。没有把工具滚动尝试冒充独立滚动验证，未继续干扰用户页面。

当前状态：READY_FOR_USER_VISUAL_REVIEW，App留在该Live帖子。未暂存/提交、不进入R08。最后diff/secret scan通过；新增完整目录入口编译并在界面可见，未追加无关长列表滚动测试。

## 2026-09-24 用户修订：捂嘴笑缺失

用户原话：“我看了似乎像#捂嘴笑 这样的一些表情没有渲染，不过像滑稽这种正常渲染了，你看一下是啥问题”。截图实际token是 `#(捂嘴笑)`，出现在正文和楼中楼预览。

根因：R07初始资源只有Android静态drawable的51张，67既不在本地资源白名单，也没有名称映射。原解析器能够识别括号语法，但无法解析到已收录图片，因此按缺失策略保留原文；与之前链接测试同步问题无关。Android通过PbContent(type2) text/c动态登记名称，且预下载61…101等缺失drawable；本次既有匿名PBPage协议返回的67/捂嘴笑字段对确认了资源身份。没有修改请求、Repo或Proto。

最小改动：新增原版 `image_emoticon67.png`（3250字节）及捂嘴笑映射，builder沿用UIImage本地资源缓存增加PNG后缀读取，验收页增加该表情。parser算法、UITextView交互、列表/导航/图片系统未改，无新增手势、动画、overlay或依赖。资源总计52张146926字节；其余缺失ID仍原文降级，未宣称全量覆盖。资源来源/校验值见 `Resources/TIEBA_EMOTICONS_PROVENANCE.md`。

执行证据目录：`Artifacts/VisualReview/R07/MissingEmoticons/`。

- `red.xcresult` / red.log：新增回归先失败，3种写法全部未产生附件ID，原4项parser通过（xcodebuild exit65）。
- `green.xcresult`：仅R07EmoticonParserTests/R07RichTextBuilderTests，9项/2suite通过，含3种写法、原文复制、附件、52张解码（exit0）。
- `phone.xcresult`：原单击+正常/大字/深色用例保留原断言并增加捂嘴笑朗读断言，1/1通过20.354秒。
- `ipad.xcresult`：同一短用例1/1通过22.389秒。没有跑全Unit、quality或长交互矩阵；原链接选择/滚动边界未修改，上轮结果保留，未冒充本次重新执行。
- `make lint` exit0，307文件0violations；`make build` exit0；`scripts/secret_scan.sh`、`git diff --check`通过。36项受保护文件与上轮hash一致。
- 取证时公开HTML请求403，改用已有匿名PBPage得到HTTP200；资源HTTPS验证因主机名不匹配失败，没有禁用证书校验。按Android明确HTTP资源地址仅在开发期取原图并打包，App无新HTTP请求/ATS豁免/Cookie。
- 正常Debug完整Live候选覆盖安装iPhone/iPad，无uninstall/erase/Keychain清除；`installed.json`确认两台binary SHA与本次build一致且含67 PNG。
- 修订前：user-before.png；修订后组件：phone-normal.png、phone-large.png、ipad-normal.png、ipad-large.png，已实际看图确认捂嘴笑在行内。iPhone完整App已通过浏览历史回到原反馈帖子，截图iphone-live-original-thread.png。
- CUA的scroll/drag未使Live列表移动，未取得第5楼修订后Live截图；保留原帖首屏让用户手动滑到第5楼，不能把Fixture截图冒充该楼实拍。这不是已证实的生产滚动故障，本次不扩大修订。

状态：READY_FOR_USER_VISUAL_REVIEW。未暂存/提交，不进入R08。

## 本次获批续作：实际根因与处理

用户明确批准最小富文本适配层方案，同时要求实际正常、仅自动化失败时不改坏原生交互。先 git status/apply --check，恢复 Candidate tracked patch 和九组新增文件（包含全部51张资源），未覆盖原有 Prompt/skill 文件；基线仍是 R06 d1819c7。

在恢复后的完整 Debug Live App 中，用同一组件实际单击 A 普通文本链接、B 表情+中文+链接+@、C 换行链接：各一次正确回调；回到原失败样本再实际单击，同样收到 intent。原失败自动化仍可复现。其 UTF-16 link range / UITextInput.firstRect / AX link.frame：A=5,4 / (87.67,227.67,67.33,22)，B=5,4 / (76.67,320,67.33,22)，C=9,4 / (16,432.67,67.33,22)；各自 native/AX frame 相同。原混合样本=4,6 / (72.33,394.67,76,22)，也一致。

实际根因是测试同步边界：XCTest.tap 返回后立即读状态，UIKit 已查询 primaryActionFor，但 UIAction handler 尚未执行；下一样本的操作前能观察到上一个 intent 已到达。原三连 tap 没有等待动作完成，不能证明单击失效。用既有测试约定的5秒可观察 label predicate（无 sleep、无加长超时、无重复点击）等待真实回调，再保留精确次数、sourceNodeID/URL 断言后，原用例和 A/B/C 同时通过。whole accessibilityLabel 造成附件后链接索引偏移的假设在这些样本中不成立；未认定 UIKit 缺陷。

按用户条件分支，未为测试重写已正常的生产链接交互，也没有强行引入 Coordinator。仍使用 SDK 公开 primaryActionFor API，只有返回的 UIAction handler 发送已有校验过的 ExternalLinkIntent；updateUIView 更新当前回调，文本/字号未变则不重设 attributedText；新增 dismantleUIView 仅清理自己的 delegate/callback。保留原生选择、复制及整段可读表情朗读，不使用替代文本索引定位原文。

R07 恢复范围仍为 parser、builder、唯一不滚动 UITextView、51本地资源、正文/摘要/子回复内联接入。新增完整 App 内的 A/B/C 对照入口，复用现有 VirtualizedList 检查不同楼层回调和滚出/返回；未修改共享列表实现。验收页隔离 accessibilityIdentifier 继承，使用实际 safeAreaInsets 约束测试列表底部。旧 Renderer Smoke 的独立链接 Button 定位同步为合并文本中的原生 Link，原 intent 断言保留；未运行其无关图片长流程。

## 本次执行与证据

日志/xcresult/截图：Artifacts/VisualReview/R07/Redesign/。

- baseline-build：make build 通过；baseline-links：2项 UI 失败，保留上述真实原场景证据。
- observed-activation：2项 UI 通过（42.452秒），仅改可观察状态同步，生产点击/AX label 未改。
- interaction-check：原样例通过；新验收页2项失败，分别为父标识覆盖子标识、长按坐标落入链接区域。
- interaction-locators：原生选择已出现；新用例仍失败，分别为验收列表底部处于根栏安全区、错误地查找 Select All Button（实际原生选择菜单为 Copy MenuItem）。修正仅在 Debug 页/测试定位；复制改用实际选区手柄扩展范围。
- native-interactions：3/3通过（81.927秒）：A/B/C独立单击各一次，来源/URL正确；从链接处起拖无额外 intent；滚出顶部至不同楼层链接，再返回顶部仍对应原源ID；长按/选区手柄/Copy/Paste得到精确 `#滑稽 中文 测试链接 @样本用户`，激活数仍为0；原失败样本单击、正常/大字号、未知词/话题和深色断言全部保留。
- unit-final：原18项/4 suites全部通过，未降低 parser/附件尺寸/本地解码/复制/换行/选区/复用断言。
- ipad-component：同一原失败样本及正常/大字/深色短检查1/1通过（22.689秒）。
- lint：第一轮仅多余空行失败；最终 make lint通过。make build、secret scan、git diff --check通过。
- 36个保护文件SHA与恢复前一致：VirtualizedList、Pager、MediaViewer、图片系统、Session、Forum与ThreadReaderStore均未改；无新增生产手势/动画/overlay/依赖。没有跑全部Unit、完整make quality或无关长矩阵。

已实际查看正常/大字号 `#滑稽` 的官方图像及中文混排，不以资源解码替代页面检查。截图 phone-normal.png / phone-large.png / phone-selection.png / phone-link-reuse.png / ipad-normal.png。完整正常 App 中再次点击原样例也收到 intent，截图 iphone-full-app-normal.png；CUA 的大字号开关操作未改变状态，保留 iphone-full-app-toggle-unchanged.png，不把它冒充大字号图；大字号证据来自已通过的对应 UI 测试。Live 手工拖动也未由 CUA 画面确认，滚动/复用结论来自真实触摸的定向 XCUITest，不宣称额外手工性能结果。

## 当前安装与交付边界

两台 Simulator 均为本次 make build 产出的完整 Debug R07 Live App；无 Fixture 启动参数，覆盖安装，不卸载/erase/清Keychain。构建与已安装 TiebaLite.debug.dylib 的 SHA256 一致：bf32c37e9daa8dea872fcef372b7c8bd8b9c57988e6d6c1e2202889ecaaf844c；两台各包含51资源，见 installed-candidate.json。与历史恢复的 R06 二进制不同。

iPhone 已留在真实高通吧帖子“8EE6拉完了”：真实作者、中文日期、两张图片、第二楼的官方内联表情及子回复均可见（iphone-live-thread.png）。完整 App 中保留“我的 → 正文 Renderer Lab → 官方表情对照 → 链接交互对照 A/B/C”入口。当前真实帖子不是固定样本。

表情覆盖仍限定 Android 已提供的51个本地资源；缺失资源（例如 canonical 生气=61）、未知名称保持原文，没有新增下载系统。链接验证边界是既有 ExternalLinkIntent，未新增外部浏览器路由；Live ThreadReader 原有默认回调/外链产品能力未在此扩大。等待用户人工查看，不进入 R08。

## 前次迭代历史（已被本次诊断更新）

## 定位、计划与边界

基线为 R06 批准提交；提交前定向 Unit 22项/5 suites、短 UI 2项、make lint/build、secret scan 和 diff-check 通过（Artifacts/VisualReview/R07/r06-approval-*）。只实现官方本地表情、唯一富文本 parser/builder/view、正文/楼中楼预览/动态摘要接入和隔离对照页。不修改共享列表、稳定楼层身份、Store、Pager、MediaViewer、远端图片 Loader/cache、Session 或根导航。

行为先由 R07 parser/builder/renderer 测试定义：独立 Proto type=2 与文本语法兼容，未知/话题不替换，顺序、复制替代文本、朗读、链接意图、基线、字号、换行和复用幂等。原连续图片分组保持。仅跑相关 Unit、短 Smoke、lint/build/diff；不跑全量 quality 或长交互矩阵。

风险是 TextKit 的测量/Cell 高度、选择与行点击竞争，以及 Android 名称映射中资源缺失；采用不滚动 UITextView、有限宽度测量、按输入变化更新、摘要不接管点击和缺资源原文回退。官方本地静态附件不走网络；远程图片沿用 ProductionImageLoader。新增资源的来源和包体记录在 Resources/TIEBA_EMOTICONS_PROVENANCE.md。

## Android 证据

UI commit c5f1125f42498e49db4e4a9cb66313b8c8a285c7；下列 Kotlin 路径前缀为 app/src/main/java/com/huanchengfly/tieba/post/：

- api/models/protos/Extensions.kt:249–260：PbContent type 2 使用 text 作为 registry ID、c 作为名称，注册后追加 `#(名称)` 至同一文本段。当前 Live PBPage mapper 已逐节点调用 ThreadContentProtoMapper；其 case 2 已保留为独立 ThreadEmojiContent。此为 CODE_EVIDENCE，不将合成测试冒充 Live 抓包。
- utils/EmoticonManager.kt：DEFAULT_EMOTICON_MAPPING、registerEmoticon、getEmoticonDrawable/Uri。`image_emoticon` 规范化为 `image_emoticon1`；drawable 优先，缺失才使用 Android 下载缓存。本阶段不复制下载逻辑。
- utils/EmoticonUtil.kt：`#(名称)`；web 转换映射也明确 `(#名称)`。裸 `#滑稽` 是当前用户要求的兼容扩展，只接受完整已知名称，不按前缀替换话题。
- ui/page/reply/ReplyPage.kt:708：插入 `#(名称)`。
- ui/widgets/compose/Texts.kt:128–155 与 PbContentRender.kt：附件占行高的0.9、TextCenter，与正文同一行。
- drawable 中共有51个本地官方资源：image_emoticon1…50、89。DEFAULT 映射中的生气重复定义最终为61，而本地只有31；web映射明确为31。严格区分：canonical生气缺61时保留文本，web生气或独立node的明确31可显示；其余仅有远端资源的名称不猜测替代图。
- 已查看 Android-target/06-thread-reader.png：表情与正文共行，无独立图片行或额外卡片。

人工交付继续遵循用户的明确修订：保留账号的完整 Live 应用为最终页面，固定表情对照仅用于自动化和补充正常/大字/深色截图。覆盖安装，不卸载、不清 Keychain。

## 前次实际执行结果与停止原因

全部命令日志位于Artifacts/VisualReview/R07/。定向xcodebuild使用TiebaLite scheme/testPlan、指定Unit或UI Smoke配置、iPhone 17 Pro目的地、关闭并行。

- R06提交复核：Unit22项/5 suites、R06ThreadSmokeTests 2项、lint/build、secret scan、diff-check通过；精确35个文件提交d1819c7，没有push。
- build-first：ScaledMetric声明缺少初始wrappedValue，exit2；修正初始化后build-second通过。
- lint-first：imports顺序、else位置及参数对齐失败；lint-second仅剩超长行；格式修正后lint-third通过，未改变规则。
- unit-first：测试的CGSize.greatestFiniteMagnitude类型歧义，构建exit65；改为CGFloat明确类型。
- unit-second：18项中1项失败。UITextView.attributedText getter不保证相同包装对象，原指针断言不适用；改验实际NSTextAttachment复用身份及选区保持，未放宽换行/字号/资源断言。unit-verified：18项/4 suites通过。
- iphone-first：单次tap未收到链接回调，exit65，15.611s。link-diagnostic：同页三次tap均失败，16.838s；源码可解析原intent但UIAction handler未执行，截图含选择菜单。
- link-action-title：保留defaultAction.title仍失败，16.784s。已撤回。
- link-lifecycle：只采诊断，U→UP→UP→UPP，未重复apply、未dispatch action。没有把该诊断称为修复。
- link-url-value：link属性改为URL后原用例仍失败，17.870s。已撤回；停止第三个补丁。
- UIKit本地SDK头文件与Apple UITextItem文档确认primaryActionFor/NSLinkAttributeName的公开契约，但不能据此宣称运行时问题已经解决。
- 未运行全量Unit、make quality、长Pager/MediaViewer矩阵，未做新的远端API或凭证访问。

正常/大字号/深色完整Smoke未通过（在链接断言提前停止）；正常样本失败截图不能冒充视觉验收通过。无iPad R07验收证据。没有READY_FOR_USER_VISUAL_REVIEW结论。

## 前次回退与交付

只反向应用本轮自有tracked diff；本轮新源码/51个资源/测试移入ignored Candidate目录保存，未删除用户工作。当前应用实现回到d1819c7的R06，未新增生产动画/手势/overlay/依赖。

iPad仍保存已验收R06正常Debug应用；从该已安装app bundle留存ApprovedR06.app并覆盖安装iPhone，不卸载、不erase、不清Keychain。该二进制SHA256为a4d0de7ce2797b792bd5f7211cef52cf452195a8da4bf8b3e07a2074428750dd（TiebaLite.debug.dylib）。iPhone无任何Fixture启动参数，已观察到完整Live高通吧列表、真实头像和多图。随后CUA报告用户切换Simulator，停止继续代操作；以当前最新截图为准。
