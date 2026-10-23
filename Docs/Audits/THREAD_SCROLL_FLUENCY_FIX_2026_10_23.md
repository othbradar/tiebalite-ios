# SF-00–SF-08 帖子慢滑修复记录

状态：USER_ACCEPTED_DEVICE / 用户授权提交与发布，2026-10-23。基线 HEAD `c6401e9261e6aec14b725500899b9052df73549b`。

用户本轮授权实施 [审计任务表](THREAD_SCROLL_FLUENCY_AUDIT_2026_10_23.md) 的全部九项。保留 P05 已验收的 Cell 持有/业务绑定/同步首次尺寸/实测行高估算；没有换列表、清缓存、禁动图或改写协议。仅主代理写当前工作树，三个只读子代理复核列表/媒体/状态，建议由主代理核实后采用。

用户已实机测试并确认比之前顺滑，授权提交、推送及发布新IPA。下面READY/待验收描述保留为当时证据状态；这次确认不等于所有设备/场景的帧呈现已量化达标。

## 2026-10-23 实机测试 IPA — DEVICE_IPA_READY

用户在上述模拟器候选交付后要求编译新IPA，供自行真机测试；尚未确认本轮慢滑体验通过。本次无生产/测试源码修改，复用上一轮72项单元及19项UI回归，不重跑全历史矩阵、不提交/推送/发布GitHub。

- 基于当前HEAD `c6401e9261e6aec14b725500899b9052df73549b` 加未提交SF修复，从当前工作树归档；805项生产输入及实际文件集合与刚交付模拟器版本一致，构建前后摘要不变。SwiftPM锁包含于Config清单，未升级依赖。
- `make generate` exit0；`xcodebuild archive -project TiebaLite.xcodeproj -scheme TiebaLite -configuration Release -destination 'generic/platform=iOS' -derivedDataPath .build/DerivedData-ThreadFluency -clonedSourcePackagesDirPath .build/SourcePackages -onlyUsePackageVersionsFromResolvedFile -skipPackageUpdates -archivePath Artifacts/Releases/SF00-SF08-device-test-20261023/TiebaLite.xcarchive CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO` exit0 / ARCHIVE SUCCEEDED。复用现有DerivedData，未新增模拟器；只有无AppIntents依赖而跳过元数据提取的warning。
- 设备Release隔离副本仅更换本次归档/中间产物路径，并额外检查SF诊断符号，exit0。确认真实网络/阅读/图片/导航等正向控制存在，无Debug/TestSupport/Fixture及本机路径；三项SF新生产类型和P05 Cell/Height来源实际编入，无DEBUG/UITESTING编译标志或计数符号。
- 首次打包校验 exit1：实际输入集合额外发现两个Finder `.DS_Store`，属于非生产目录元数据；仅在清单核对中排除该固定文件名，保留文件，未删产品/资源或降低二进制、文件相等断言。原失败日志保存。重跑校验 exit0：ARM64/iPhoneOS、最低18.0、0.2.0/Build19、iPhone+iPad、原Bundle ID、图标/132个表情资源/照片添加声明、无签名和描述文件、ZIP CRC、140个包内文件逐字节相等及主程序执行权限全部通过。
- `make write-baseline-check` exit0（23项）、`make secret-scan` exit0、`git diff --check` exit0。查找不存在的 `Config/Base.xcconfig` 返回1，已依据Release实际include及归档结果核对配置，不算构建失败。没有重跑已知全仓forbidden旧失败及全量quality，仍沿用上文边界。
- 产物：`Artifacts/Releases/SF00-SF08-device-test-20261023/TiebaLite-0.2.0-SF00-SF08-ios18-arm64-unsigned.ipa`，**5,029,124 bytes**，SHA256 **`67385956209c5eec7fc5a74d042f2b793ef59527a74fb88de7fc1821c6ead769`**。同目录保存SHA256SUMS、归档日志/退出码、源码清单及package-verification.json。
- 沿用未签名IPA自行签名策略，原Bundle ID `dev.local.tiebaliteios`、版本及Keychain配置未改。用户需沿用原签名身份覆盖安装；本次未操作其真机、未收集或打包账号数据，不声称已验证真机顺滑度。无新增手势、动画、overlay或依赖；原模拟器停点保持。

## 已实施任务及证据

| 编号 | 实施 | 直接验证与边界 |
| --- | --- | --- |
| SF-00 | `ScrollWorkMetrics` 仅 UITESTING 编译；固定步进 CADisplayLink 窗口同时记录 interval、同步工作时间、目标间隔超预算数和相对位移。包括纯文、3条楼中楼、带图、实际 GIF、播放中语音，以及生产吧首页对照。最终计数写测试附件。 | 每个帖子样本先预热480帧再测480帧，8pt往返；吧首页/语音180+180帧。不是自然手指拖动、独立GPU呈现或真机FPS，不设虚假的跨设备FPS绿线。 |
| SF-01 | `TiebaSelectableTextView` 缓存最近4个真实 `super.sizeThatFits` 结果；文本/attributedText/textStorage 编辑同步清除，尺寸/inset/断行/方向/大字体/选择模式在key中。 | 相同条件重复30次命中；长短文字、外部富文本编辑、宽度/inset/行数变化与新实例测量相等。没有固定真实行高。 |
| SF-02 | `ThreadReaderPostRowModel` 持有正文 preparedBlocks；子回复模型持有含作者及“回复乙”前缀的 previewRuns，正文/身份变化重新生成。Renderer 消费已准备结果。 | 稳定内容不再从 View body 分块/解析；新作者/正文同业务ID正确更新。图片/链接/正文动作保持独立。未使用的重复子回复分块在复核后移除。 |
| SF-03 | `VirtualizedList` 可选 `refreshUnchangedContent`；仅线程行使用非观察动作 relay。已绑定同内容同环境时替换回调，不写 contentConfiguration；其余保持 P05 同步绑定。 | 生产 UITextView 的 accessibilityActivate 调用最新回调99，零host重配；旧捕获对象 weak 释放。内容更换实际新字/新字号可见；默认未接入调用方继续重配。 |
| SF-04 | 只读删除候选准备有独立任务表，同target/author合并；非本人负结果最多512项。既有写操作busy不再被候选检查广播。 | 30次非本人准备 busy观察通知1→0；确认第二消费者进入共用等待后，取消第一消费者不取消共用结果；会话切换丢弃迟到结果。点赞/删除写入执行链未改。 |
| SF-05 | configuredRows 先检查既有缓存，再进行删除扫描。 | 200楼相同版本30次调用，额外扫描6060→0；新增实际生产页面可见断言，屏蔽变化且 listRevision 不变时预览/父楼确实消失，取消屏蔽重新可见。 |
| SF-06 | 每行投影按原内容、展示时间及删除影响复用；页尾变化不重新过滤旧正文，追加仅投影新增行。users/removals revision进入列表版本。 | 200及1000行边界：页尾变化旧正文投影为0，追加只投影新增页；分页顺序、删除时间和返回位置继承回归。仍有必要的数组遍历/等值比较，不声称所有分页工作O(新增)。 |
| SF-07 | 一次可见播放复用一个CGImageSource，锁保护访问且仍在既有双worker执行；按父视口pixel size解码，1024上限，逐帧清缓存。 | GIF/WebP连续5帧 source5→1，96/192尺寸、帧内容、取消/释放通过；固定窗口多帧仅1source，真实resize仅新建1次。滚动离屏/入屏会重新播放，不要求整次滚动仅1source。 |
| SF-08 | 单一播放状态机保持；展示分成owner/generation/phase与elapsed/duration观察属性。只有当前语音依赖进度。 | 100次tick闲置status观察通知0，活跃进度改变；实际挂载的闲置视图不重建，生产语音播放期间列表通过位移检查。仍使用单AVPlayer及原手动/自动/后台策略。 |

## 基线与对照

`baseline3` 在未修复生产代码时运行：8项中5个断言失败，确认重复尺寸工作、busy通知、cache前扫描、页尾/追加全量投影。其余P05/U06行为不是推测失败。随后按分组运行 `text-projection`、`binding`、`sf-final2/3/5`；没有以一个混合绿色结果冒充每项独立根因。

相同本地固定内容、优化 UITesting、iPhone17Pro/iOS26.5；所有图片先加载。以下为 baseline3 → sf-final5：

| 窗口 | 原生文字实际测量 | body解析/分块 | 最大同步步进工作ms | 最大display-link间隔ms | 最大额外位移pt |
| --- | ---: | --- | ---: | ---: | ---: |
| 纯正文 | 217→32 | runs30/blocks15→0/0 | 33.117→24.030 | 49.824→43.325 | 约0→约0 |
| 楼中楼密集 | 264→48 | runs25/blocks5→0/0 | 55.887→53.107 | 77.889→75.693 | 约0→约0 |
| 带图及楼中楼 | 492→32 | runs15/blocks3→0/0 | 81.621→39.932 | 103.906→63.187 | 0→0 |

sf-final5 的吧首页对照：interval p50/p95/p99/max均16.667ms，超预算0，步进工作max11.793ms；语音对照interval相同、步进max2.409ms。GIF实际播放46帧/source6，最大间隔72.362ms，额外位移0；没有同条件修复前GIF有效帧记录，不能量化其整体提升。

**这些数据证明重复工作减少，不证明连续慢滑全部达标。** 楼中楼窗口仍有约75.7ms间隔尖峰，纯文字超预算计数也未单调下降。模拟器调度、首次复用绘制和真实设备呈现仍有区别；不能把用户体验标为已经完全流畅。待用户在正常无探针版本最终慢滑验收。

## 验证执行记录

日志及xcresult保存在 ignored `Artifacts/VisualReview/ThreadFluencyFix-20261023/`，同一个 `.build/DerivedData-ThreadFluency` 复用编译缓存。

- `make generate`：通过，固定Protobuf/SwiftPM锁未更改。
- `baseline`、`baseline2`：测试支架编译错误（缺postID、诊断字段名、CGFloat推断），修正后 baseline3 实际运行并产生上述5个预期失败。
- `text-projection`：13项/4 suites通过；`binding`：11项/4 suites通过，包含P05已加载混合行小步位移及容器释放。
- `media`：Sendable几何闭包需显式捕获displayScale，编译失败后修正；这条内部几何路径随后因实际循环被父视口尺寸方案替换。
- `sf-final`：测试 ViewBuilder Void语句、weak变量被视为未修改而 warnings-as-errors 编译失败；修改测试支架，不删断言。一次格式化脚本中途断言失败，未当作完整执行。
- `sf-final2`：12项/6 suites通过，但GIF滚动窗口无实际frame计数，**该GIF条目排除作为播放证据**。补真实active环境与frame>0断言。
- `sf-final3`：15项/8 suites通过；发现播放期 source18/frame54 和 Geometry cycling 日志。虽断言绿，仍据运行证据修正：移除当前帧尺寸反馈，使用父视口targetPixelSize；新增不同封面比例的固定播放及resize测试。
- `sf-final4`：漏补 DebugU13MediaView 新参数导致编译失败；三处调用均补齐。
- `sf-final5`：17项/9 suites通过（含参数化用例），固定播放/resize source各1且持续推进，滚动窗口实际GIF播放，无上述Geometry cycling。
- `direct-unit`：44项/10 suites通过：P01、P05两组、Stage18/19复用、U03恢复/缓存、U06P3、U13媒体、U14状态。首次选择 `R07EmoticonTests` 文件名没有匹配suite，另以实际 Parser/Builder suite 补跑，不计作通过。
- `make lint`：早期因新增文件格式失败，作用域内格式修复后 lint5 643文件零违规，冻结写链23项通过；未放宽规则。
- `make forbidden`：失败，HEAD只读源码快照复现相同5组/39处既有策略命中（直接日志、singleton、编码帧/缓存sleep、测试UUID等）。本轮两条诊断print改为Swift Testing附件后，新命中为0；不改无关旧源码、不修改白名单来消除旧失败。
- `make static-canaries`、`make secret-scan`：通过。因为 `make forbidden` 已存在全局失败且本轮按审计约定定向验证，未运行全历史 `make quality-fast/quality`，不能称全门禁绿色。
- `sf-final6`：测试诊断由print改为附件后，再次17项/9 suites通过；6份计时/计数附件已从xcresult成功导出。此轮只验证最终报告接线，未替换上面的同内容对照数据。部分手工挂载支架仍报告未安装View时读取Environment默认值；不以这类支架代替系统动态字号/深色模式UI验证。
- `r07-unit`：补跑实际 R07EmoticonParserTests/R07RichTextBuilderTests，11项/2 suites通过。最新独立单元回归共72项（17+44+11，参数化case不重复计数）。
- `direct-ui-iphone`：15项通过（P01七项：两步点击、普通正文/子回复编辑器目标、拖动/复制、图片/作者独立动作、元数据；R07三项；U03重进/图片返回位置一项；U13四项）。`direct-ui-ipad`：4项通过（P01两步及独立动作两项、U03尺寸变化位置一项、U13播放/离屏一项）。UI共19项；只在本轮隔离fixture模拟器运行。
- `lint-final`：643文件零违规、WRITE_BASELINE23项通过。`static-final`与同一HEAD只读快照对比无新增策略命中；全仓既有失败仍保留，不称全部门禁通过。
- 正常完整 Release generic iOS Simulator构建成功，含arm64/x86_64；`codesign --verify --deep --strict`通过。既有发布隔离脚本仅将DerivedData路径替换为本轮目录后运行通过，检查内容未改变；二进制无ScrollWorkMetrics/ScrollFrameWindow。805项生产输入在构建后摘要不变，最后测试附件改动不涉及生产源码。
- 已覆盖原iPhone17Pro和iPadPro13M5的完整正常Release Live（0.2.0/Build19，bundle不变），两台安装后二进制与产物SHA256一致。原iPhone六份草稿/书签文件摘要不变，iPad原无对应文件。CUA确认两台账号/历史仍可用，均经浏览历史进入AI帖 `11116138791`，停在第4楼 `154046552805` 正文、已加载图片及3条楼中楼预览；截图为 `live-iphone.png` / `live-ipad.png`。未使用fixture参数、诊断探针或调试器。
- 本轮 CUA普通scroll/drag操作没有产生可见滚动，不作为输入/性能证据；改用已暴露的原生“Scroll Down”辅助动作完成停点。没有代替用户宣称自然慢拖验收通过。
- 仅删除本轮创建的 `Tieba-SF-Validation` / `Tieba-SF-iPad-Validation` 两个测试模拟器，原iPhone/iPad及其他现存设备保留；结果见 `temporary-device-cleanup.json`。保留测试源码和证据。

- 最终 `git diff --check`、16个新增文件的末尾换行/空白/冲突标记检查、交付前 `make secret-scan` 均通过；无暂存差异。

## 生命周期和剩余边界

- preparation由Store持有到只读检查结束或会话改变；一个Cell消失不会取消另一个等待者。不会将普通取消当作发布失败。会话切换仍取消旧任务并清权限/负缓存。
- 已排队的ImageIO单帧不能中途取消，但worker结果回UI前和失败回写前均检查取消；完成后释放source，不宣称取消瞬间终止解码。
- 同一行非内容更新只替换回调；真实环境变化继续重配，普通文本选择/复制/链接由原组件处理。没有增加业务手势、动画、生产overlay或依赖。
- 不修改官方iOS发帖/回复/上传参数、签名、回执和发布顺序；没有真实发送、点赞、删除。
- 账号、草稿、图片缓存、阅读位置无迁移；没有卸载/清数据/暂存/提交/推送/发布。新增临时验证设备仅用于fixture测试，正常用户设备最后覆盖完整Live包。

## 交付与后续验收

- 正常Release可执行文件SHA256：`f93e35c46641f642d556ec74aca29f55ae3f0b2c489418908ba8e8379f7100b6`；构建/输入/签名/安装保护记录为 `live-build-proof.json`、`production-inputs.json`、`installation-proof.json`、`release-isolation.log`。
- 修改集中于帖子行投影/绑定、文字测量、只读权限准备、动图解码和播放展示观察，另增直接回归及测试专用计数。共享列表默认行为与P05首次同步测量保留；没有新增手势、动画、overlay、依赖。
- 下一步由用户在已停好的两台正常Live上慢速上下拖动，重点检查带图及楼中楼区域，往返后检查位置和两步点击。尚无本轮物理设备/自然手指拖动帧呈现证据；SF-00验收环境已建立，最终主观与真机顺滑度未宣称通过。
- 本轮未暂存、提交、推送、发布IPA或开始其他阶段。不会把9项已实施等同所有短帧尖峰已经消失。
