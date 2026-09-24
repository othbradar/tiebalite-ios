# R10 图片与表情编辑器

状态：USER_VISUALLY_APPROVED（2026-09-24）。用户确认“都正常，图片和表情包都正确，可以提交了”，授权提交 R10；基线 R09 提交 1100788，不进入 R11。

## 用户最终验收与 Live 证据

用户提供高通吧帖子第14/15楼截图：文字和滑稽已内联显示，第15楼同时显示上传的 LOCAL PHOTO 4。证据保存于 ignored `Artifacts/VisualReview/R10/UserApproval/user-confirmed-live-image-emoticon-reply.png`。确认范围为用户本人手动完成的一张图片加表情的主题回复；AI 未执行 Live 上传或发布，未采集原始上传/发布响应。新帖、指定楼层、楼中楼、多图真实发布及 Live 失败重试未单独验证，不能由此扩大结论。

本轮只更新验收记录与精确提交，不再修改 UI。提交前 Unit 首次执行停在保存现有剪贴板（R10ComposerEditorTests.swift:79）：线程采样为 UIPasteboard.items 等待，截图显示 CoreSimulatorBridge 粘贴权限提示。拒绝读取外部剪贴板后原进程继续，11项/4 suites（13次执行）全部通过，未改断言、超时或生产代码；250秒耗时包含权限等待，不能当作产品性能结果。该提示截图和采样留在 UserApproval/，UIKit appearance 和生成 Proto 重复类诊断保留。下方各轮失败、UNKNOWN 和当时的未提交状态是历史记录，以本节最终用户验收为当前状态。

## 提交门禁（2026-09-24）

证据目录 `Artifacts/VisualReview/R10/UserApproval/`。环境 Xcode 26.6（17F113）、Swift 6.3.3；提交前基线 `1100788`，分支 `visual-parity-remediation`。

- `xcodebuild test`：project TiebaLite.xcodeproj、scheme/testPlan TiebaLite、configuration Unit、串行、iPhone 70D93841-1FEB-445A-8FAD-B1C29B981D5D，仅 R10ComposerEditorTests / R10ComposerMediaTests / R10ComposerStateTests / R10ImageUploadTests。11项/4 suites（13次执行）通过，exit0；权限等待过程见上文，原结果 `unit.xcresult` 未丢弃。
- 同一目的地 `xcodebuild test`、configuration “UI Smoke”，仅 R10ComposerSmokeTests 的 `testEmoticonPanelFillsWidthAndStaysBetweenToolbarAndStatus` / `testPhotoCountsDeleteEmoticonsAndUploadRetry`：2/2，54.436秒，exit0。原三轮几何断言和5秒超时未变；选图1/4/5、删中间、三种内联表情、Mock上传失败保留草稿及重试全部通过。`ui.xcresult`。
- `make lint`：347个Swift文件，0 violations；`make build`：Build Succeeded；`make secret-scan`、`git diff --check`：通过。日志分别为 lint.log / build.log / secret-scan.log。
- 本轮没有代码改动或新动画/手势/overlay/依赖；44个原生面板修订保护文件hash均不变（protected.json）。未重复全量 Unit/quality、iPad或无关长矩阵，iPad结果沿用上次已通过记录。
- 测试后恢复 iPhone 正常完整 Debug App 并启动，无 Fixture 参数，安装二进制与已验收候选同为 `dadbb284ad664ffef3045000f97e6a31829ecddf57613a11449020d8a5eff8df`。未卸载、清Keychain或erase；iPad保持原已验收安装。用户本人这次成功发布截图为最终人工证据。
- 只精确提交 R10 源码/测试/文档；用户未跟踪 Prompt/skill 文件和 ignored Artifacts 留在本地。无共享列表/导航改动，无Android submodule漂移，不推送、不进入R11。

## 2026-09-24 批准后的原生输入区域修订

按用户批准实施 R10_EDITOR_LAYOUT_REDESIGN.md。单个 UITextView 继续内联附件/选择/复制；同一 native inputView 在键盘和原官方表情网格之间切换，删除旧 VStack 的独立表情区域。实际窗口宽度由编辑器传入，宽度变化才同步，不使用屏幕常量、补偿偏移或高度反馈。当前回调和可编辑状态由 Coordinator 管理，模式不变不 reload，关闭与 teardown 清理自有引用。

`Artifacts/VisualReview/R10/NativeInput/` 保留所有接入失败：baseline 为原三轮错位；iphone（2失败）、input-diagnostic（1失败）、iphone-height（2失败）、iphone-inputview（2失败）、iphone-direct（2失败）、iphone-host-region（2失败）、actual-frames（1失败）、width-follow（2失败）、native-sizing（2失败）。这些尝试均未作为通过证据。实际帧诊断确认 native input 与 hosting grid 都在 window 中，但宽0；单独 autoresizing/self-sizing 开关无效。controller-identity Unit 通过且 root===inputView，排除控制器指向另一根视图。随后显式传入实际窗口宽度，scene-width UI 才转绿。临时诊断和 print 已删除，不打印 Live 数据。

最终交互：scene-width.xcresult iPhone2/2（54.420s），原超时不变、三轮原几何断言保留，1/4/5图/删中间/三种官方表情内联/Mock失败保留与重试通过；ipad-final.xcresult 1/1（20.755s），四图+滑稽、横竖屏键盘视口宽度和控件不重叠通过。单元测试 unit-final.xcresult 9项/3 suites通过；最后禁用状态插入保护的 unit-verified.xcresult 同为9项/3 suites（11次执行）全部通过。临时 UIWindow host Unit 出现 begin/end appearance transition 诊断警告，结果通过；没有修改共享生命周期。未跑全部Unit/quality/无关长矩阵；44个受保护文件hash不变，Store、图片加载/缓存与Session未继续修改。无新增自定义手势/动画/overlay/依赖。

本次 lint-verified.log、make build/build-final.log、secret-final.log、git diff --check 均exit0。两台覆盖安装完整正常Debug，无Fixture启动参数；installed-build.json二进制SHA256一致为 dadbb284ad664ffef3045000f97e6a31829ecddf57613a11449020d8a5eff8df。terminate返回3表示此前未运行，安装/launch成功。iPhone已在原耐腐蚀艺术馆吧原帖的真实回复编辑器，通过PhotosPicker选入4张本地非私人样图，实际点选含笑眼/滑稽/呵呵的多个表情并观察内联附件。截图 iphone-live-four-photos-emoticons.png；iPad 同一真实帖子 sheet 已人工点选笑眼/滑稽，稳定全宽输入区域截图 ipad-live-emoticons.png（自动截图捕获过转屏过渡边缘，保留原附件，最终以此稳定Live图补充）；登录态保留，不卸载、不清Keychain、零上传/发送。

下方 STOPPED 及旧安装记录均为历史，不能混用为本次安装或通过证据。真实上传仍未执行，只由用户自行决定发送。

## 2026-09-24 用户反馈修订

用户指出正文笑眼未渲染、面板缩窄、偶发内容覆盖工具栏和字数。正文根因是初版 plain editor + 分离预览：原生 host 三次确认附件数0（unit-red-hosted.xcresult），修订后笑眼/滑稽/捂嘴笑在同一 UITextView 显示，复制和发送仍为原 token。`unit-editing.xcresult` 2项/4次执行通过，含光标UTF-16映射、连续同表情、中间插入/删除、选择复制/剪切/粘贴、未知原文；iPhone Mock UI 已实际点击笑眼/滑稽/呵呵并通过正文三附件值断言。

面板原失败在隔离样本连续3次复现（panel-before.xcresult），实际视口向左/上偏移并覆盖底栏。第一修正显式几何尺寸/裁剪仍3次失败（panel-after.xcresult）；只记录完整frames的诊断复跑亦失败（panel-diagnostic.xcresult）。第二修正将底部放safeAreaInset、保持面板实例，仍有首次错位及关闭后AX残留（panel-inset.xcresult）；原上传流程在关闭面板断言处停止，不算通过。已经撤回两次失败的面板修正并保留候选原文件、日志、截图，未做第三次补丁。提案 `R10_EDITOR_LAYOUT_REDESIGN.md` 尚未实施，具体系统级根因仍UNKNOWN。

首次Unit host没有挂Window导致无法找到UITextView，此测试设置失败保留为unit-red.xcresult；挂Window后才得到真实0附件失败。首次lint失败为格式/行长，已修正，不降低规则。所有本次证据位于 `Artifacts/VisualReview/R10/EditorRevision/`。未重复全部Unit或quality；无Live自动上传/发布。当前R10不输出READY，后文原首轮通过仅为历史结果，不能代表此次反馈已解决。

计划：扩展 TextDraft / TextComposerStore / TextComposerView，共用 PhotosPicker、顺序预览、删除、分块上传状态和可重试失败、光标插入官方 token。数据层新增有证据的上传协议与 Repository；App 仅注入依赖。图片预览增加 ProductionImageLoader 的显式本地文件入口，共用原解码/缓存，网络 URL 白名单不变。既有 R07 资源/parser/renderer 复用；不改列表、导航、Pager、MediaViewer、Session、业务目标 ID。小范围 Unit（分块/签名/响应/失败保留/取消/光标），1 个 iPhone Mock Smoke、1 个 iPad 简单检查、图片复用回归、lint/build/secret/diff。最后完整 Live App 选本地样图，零自动发送。

参考：锁定 UI c5f1125 的 ReplyPage / ReplyViewModel / ImageUploader / OfficialTiebaApi / RetrofitTiebaApi / CommonParamInterceptor / SortAndSignInterceptor / StParamInterceptor。已查看 Android 06 帖子图；现有六张参考没有图片编辑器截图，编辑器布局以源码证据为准，视觉仍待用户验收。原版最多9、按选择順序、无重排；表情48dp自适应格、#(名称)；点击发送后顺序上传再以服务器 picId/尺寸构造 #(pic,id,width,height)。不自动上传用户刚选的照片。

本次收尾：lint-final.log零违规；build-final.log exit0（底层Artifacts/TestResults/20260924-204725-12265-build.log）；secret-final.log及git diff --check exit0。两台完整正常Debug覆盖安装，二进制hash9d82772ea09ad44ed4dba670c1958809d3264a0ed3e1e793e5f87e59d7be403e一致。terminate命令返回原App未运行（code3），随后正常launch成功。CUA粘贴曾超时，实际草稿为空；改为直接点选笑眼后正文实际显示，零发送。iPhone留在原耐腐蚀艺术馆吧原帖回复编辑器，未发送笑眼草稿；截图live-inline-and-open-panel-failure.png同时保留内联成功与面板未修复证据，最终收起面板。没有卸载/清Keychain、暂存或提交。

## 实现与边界

PhotosPicker按选择顺序导入，最多9张，以处理后内容MD5作稳定ID；相同图片去重，删除中间图片不重排其余项。后台处理最长边2560、JPEG0.95、5MiB上限；图片仅持有临时文件，预览通过原 ProductionImageLoader 的同一解码和NSCache。本地入口不放宽网络 URL 白名单，不带登录Cookie。按用户发送动作上传，512000字节顺序分块，服务端确认进度；已成功图片保存在当前目标会话草稿，失败后手动重试跳过成功项。取消、租约变化不继续最终发布。四类目标最终仍走 R09 既有Repository及业务ID。

官方表情面板复用R07完整目录、48pt格，UTF-16光标处插入 #(名称)，未知文本不替换。正文内联附件复用原R07 builder，复制和发送保留原token；没有重建富文本框架。键盘与面板互斥。无新依赖、手势、自定义动画或根overlay；删除按钮只占自身44pt。iOS普通压缩模式不提供原图开关；最长边上限是已记录的内存适配差异。

## 执行结果

- 未实现时定向测试先编译失败：ComposerInsertion/ImageUploadProtocol不存在，unit-red.log，exit65；明确为feature未实现，非运行时失败。
- 首轮实现15项Unit通过（unit-implementation.log）；R10状态/上传、R09、ProductionImageLoader及已有Cell复用合计34项/8 suites通过（unit-final.xcresult）。复用测试有UIKit visibleCells更新时诊断警告，测试通过；共享列表未改，不扩大修复。
- 最后补充实际multipart字节断言、保留明确上传服务端错误后，相关6项/2 suites通过（unit-upload-final.xcresult）。无测试放宽、无全量Unit/quality。
- iPhone短UI首轮0删除按钮：视频显示缩略图已显示，按钮标识被父容器继承；显式children.contain后原数量/删除顺序断言通过。同一流程1/1，28.994秒，iphone-ui-accessibility.xcresult。覆盖1/4/5图、删中间、滑稽+呵呵、切键盘/表情、可观察上传中、失败保留、手动Mock重试成功。Mock续行由明确按钮驱动，没有延时。
- iPad短UI1/1，18.110秒（ipad-ui.xcresult），四图+滑稽草稿跨转屏保留、键盘可编辑。截图导出ipad-ui-green；附件含旋转过渡边缘，最终Live停留仍待完成，不能冒充稳定Live截图。
- lint前两轮为新增文件对齐/函数复杂度/loader长度问题，修正局部格式、拆出失败处理和同文件扩展，最终lint零违规；make build、secret scan、网络隔离、git diff --check通过。build-final.log / lint-final.log / secret-final.log / networking-isolation.log。
- protected-check.json：对R09基线1100788，39个列表/导航/会话受保护文件无变化。

## 安装和仍待完成的交付

已覆盖安装正常Debug完整App到iPhone17Pro与iPadPro13，未卸载/erase/清Keychain；两台已安装dylib与本次构建SHA256一致：44fee57e8faaa69b230fbeecd16bf24333e72bbd294ccf9cbd6c57cb4e298cf5。正常App不包含r09/r10 Mock入口（installed-build.json）。iPhone完整Live首页可见原关注吧和等级。四张本地非私人样图已放入iPhone模拟器相册，尚未上传。

CUA内容坐标点击连续返回 windowNotFoundAtPosition；刷新绑定、标准/全屏窗口及重连仍失败，App自身未显示卡死证据。已请求用户将Mac解锁并把模拟器置前。当前尚未在正常Live App完成PhotosPicker四图选择与最终编辑器停留，因此不宣称交付门禁全部完成。Mock四图+表情截图位于iphone-ui-green，不能作为Live上传成功证据。HTTPS上传、真实账号图片回复仍为UNKNOWN，只能由用户自行决定发送后核验。AI零Live上传/发布，R10未暂存/提交，不进入R11。
