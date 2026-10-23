# 帖子楼层慢滑流畅性审计与修复任务表

状态：**AUDIT_COMPLETE**。日期：2026-10-23。下文为实施前审计；用户随后授权 SF-00–08，实施与验证记录见 [THREAD_SCROLL_FLUENCY_FIX_2026_10_23.md](THREAD_SCROLL_FLUENCY_FIX_2026_10_23.md)。

## 目标、基线与结论

用户确认原先约半秒停住和明显图片跳位已修复，但在模拟器和真机慢速上下拖动帖子回复时，仍感觉一顿一顿；同一 App 的吧首页更流畅。本次审计覆盖帖子阅读的列表、状态、文字、图片、播放、手势、分页、阅读恢复及相关回归，产出可分别实施的修复任务，不实施生产补丁。

- iOS 源码基线：`c6401e9261e6aec14b725500899b9052df73549b`，`fix: stabilize thread cell reuse and scrolling geometry`。
- 开始时无 tracked 修改；既有未跟踪 Prompts、技能配置和 Python 缓存保留。
- Android 对照：[zzc10086/TiebaLite](https://github.com/zzc10086/TiebaLite)，只读本地 `References/TiebaLite-Android`，锁定提交 `5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`，分支 `4.0-dev`。不声称该提交等于远端最新提交，也未更新 submodule。
- 保留 P05 的同步业务绑定、代次隔离、宿主复用、实测行高估算。现有 `contentVersion`、`configuredRows`、图片后台解码及请求合并均已经存在。

**结论：当前最值得处理的是复杂楼层的重复文字工作和局部状态更新的影响范围，而不是再次更换列表容器。** 已确认多处不必要工作及一处流畅性验收缺口；尚未取得能够把本轮连续小卡顿唯一归因于某一项的当前版本帧时间证据。下面的优先级是修复/验证顺序，不是耗时占比排名。

帖子与吧首页都使用 `VirtualizedList + UITableViewDiffableDataSource + UIHostingConfiguration`。帖子要显示完整正文、多个可选择文字块和最多三条独立楼中楼预览，首页则主要是最多五行的 SwiftUI `Text` 与静态缩略图。首页流畅说明值得比较两种内容路径，不能据此断言 UIKit 列表本身有问题。

## 证据分级与采样边界

| 标记 | 含义 |
| --- | --- |
| S：源码确认 | 调用顺序、重复工作或依赖范围可从当前 HEAD 直接证明；不自动等于本次掉帧根因。 |
| H：历史测量 | P05 已有日志/回归，注明当时版本和采样方式；只用来缩小检查范围。 |
| V：待验证 | 对帧耗时、布局传播或位移的影响尚未建立当前版本的时间关联。 |
| G：验收缺口 | 已有测试不能回答当前用户反馈，不是生产根因。 |

历史证据来自 `Docs/Audits/P05_THREAD_SLOW_SCROLL_FIX.md:43、127–139`：

1. 修前自然慢拖曾捕获 `prepareForReuse → contentConfiguration=nil → SwiftUI/Text` 清空宿主栈，单次 471.14ms。当前 HEAD 已删除该复用清空路径，不能把旧栈当成当前仍然存在的故障。
2. 最后阶段的隔离 iPad、UITesting `-O`、预热混合内容自动滚动样本：reuse p95/max 0.280/0.514ms，bind max 0.206ms，layout p95/max 10.619/23.768ms。采集发生在最后实测行高补丁前；它提示仍应关注布局成本，**不能冒充当前 Live、自然拖动或真机 FPS**。嵌套方法耗时不能相加为整帧耗时。
3. 修前文字测量曾记录 985/802/1204 次，单次峰值 2.966ms；文字构建峰值 1.699ms。单次不足以解释 471ms，并不意味着多项集中在一帧时没有成本；当前版本频率与占比仍未知。
4. busy 对照曾把只读准备广播从 108 次降至 0，用户仍报告明显停顿。该实验已撤，不能再把 busy 宣称为唯一或已证主要根因。
5. 本轮尝试对原 iPhone Live 进程作 `sample 22659 15 2`，命令完成，但 CUA 输入进入楼中楼和编辑器，未保持“同一主帖连续慢拖”窗口，**整份排除，不用于性能排名、FPS 或修复效果**。已取消空编辑器并返回原帖，无输入/发送。原始文件只保存在 ignored `Artifacts/VisualReview/ThreadFluencyAudit-20261023/current-live-text-subposts.sample.txt`。也不能据此认定用户手势有新 bug。

本轮没有新增有效的当前真机帧时间数据，没有把静态风险包装为采样结论。

## 全链路审计覆盖

以下路径相对仓库根目录；行号对应本次 HEAD。

| 范围 | 已检查路径/符号 | 结论 |
| --- | --- | --- |
| 列表复用、释放 | `Sources/InteractionKit/VirtualList/VirtualizedList.swift`、`VirtualListCellContent.swift` | P05 同步绑定与释放边界保留；没有再次清空复用宿主。 |
| 版本、快照、可见行配置 | `VirtualizedList+Version.swift:23–69`、`+Snapshot.swift:16–98` | 同版本仍配置全部可见行；分页还有全量比较与完成后的可见行配置，见 SF-03/06。 |
| 行高、阅读恢复、坐标 | `VirtualizedList+Height.swift:14–36`、`+Reading.swift:80–99、132–157` | 已测高度按身份/尺寸/环境有效；正常拖动时阅读补偿返回，没有证据支持删掉阅读保持。 |
| View/Store/删除过滤 | `ThreadReaderView.swift:141–186`、`ThreadReaderNavigation.swift:4–42`、`ThreadReaderStore.swift:38–41、173、332–347` | 缓存判断前扫描、页尾触发投影；见 SF-05/06。 |
| 只读权限准备、点赞状态 | `ContentActionViews.swift:11–44`、`ContentActionStore.swift:42–50、97–115` | 只读候选准备会广播共享 busy，见 SF-04。 |
| 正文、楼中楼、表情 | `ThreadContentRenderer.swift:59–79`、`ThreadReaderFloorViews.swift:180–217`、`TiebaRichText.swift:49` | body 内仍分块/生成 runs；见 SF-02。 |
| TextKit 测量与复制 | `TiebaRichTextView.swift:49–66、99–112` | 已有 attributedText 更新短路，但无应用层相同尺寸请求复用；见 SF-01。 |
| 普通文字点击 | `TiebaTextBodyTap.swift:7–41` | 每个文本视图只有一个 lazy tap，未发现重复创建手势；关系配置可观察，暂不作为已证根因。 |
| 静态图片/保存/缓存 | `ProductionImageLoader.swift:97、211`、`ThreadContentImageRenderState.swift:144`、`ThreadContentRenderer.swift:269–308`、`TiebaMediaGrid.swift` | 已有后台解码、合并和稳定占位；图片网格仅处理至多8张的尺寸运算，不重复造图片管线。 |
| GIF/WebP | `AnimatedMediaImage.swift:47–73`、`AnimatedImageResource.swift:36–55` | 每帧重建 ImageSource、固定解码上限、每帧 SwiftUI 状态提交；见 SF-07。 |
| 视频/语音/可见性 | `MediaPlaybackController.swift:10、73、173`、`ThreadPlayableMedia.swift:10、57`、`MediaVisibilityObserver.swift:47–90` | 共享时间进度依赖过宽；已有可见性停止机制，见 SF-08。 |
| 分页/预载/持久化 | `ThreadReaderStore.swift:585`、`CachedReadingRepository.swift:189、292`、`VirtualizedList.swift:413` | 已有请求合并；阅读保存是停稳后的 actor manifest 更新，不能称逐帧同步磁盘写。 |
| 回归与验收 | `P05MixedCellLifecycleTests.swift:14、52–83`、`U06P3ListWorkTests.swift:42–46、60–126`、Stage18/19、U03/P01/U13 测试 | 位置、绑定、动作回归有价值；帧节奏与部分缓存前工作计数缺失，见 SF-00。 |

## 与 Android 的可迁移对照

Android 参考是当前锁定的 Compose 实现，不是把历史 RecyclerView 当成当前帖子页。

| Android 源码事实 | iOS 现状与可采用方向 |
| --- | --- |
| `ui/page/thread/ThreadPage.kt:1831–1844` 用 `Post_<业务ID>` 的 keyed items；`ui/widgets/compose/LazyLists.kt:24–49` 包装原生 `LazyColumn`。 | iOS 已有稳定业务 ID 和虚拟化，保留即可。这不是改回 LazyVStack 或移植 Android 滚动物理的理由。 |
| `ThreadViewModel.kt:1287–1300` 的不可变 `PostItemData` 持有 `contentRenders`，`SubPostItemData` 持有已生成的 `AnnotatedString`；`ThreadPage.kt:2197、2234–2236` 消费这些结果。 | 最有价值的差异：正文/预览解析结果绑定内容版本，减少 View 求值时的投影，见 SF-02。不是说 Android 完全没有重组或解析。 |
| `ThreadPage.kt:529–579` 分属性收集数据、loading 等状态；`:614–632` 用 derivedState 表达派生条件。 | 参考其更新范围，分开页尾、正文、播放进度。不能仅凭 `collectPartialAsState` 就断言 Android 每次只重组一行。 |
| `ThreadPage.kt:1115` 用现有账号与作者 ID 作删除候选判断。 | iOS 也可把候选准备从写操作 busy 分开；仍必须保留现有官方 iOS 新鲜权限确认，不移植 Android 写协议。 |
| `ui/common/PbContentRender.kt:144–172` 由数据宽高给图片比例；`:317` 复用按图片/列数生成的分组。 | iOS 已有稳定图片比例与 P05 行高估算，应保留；只查重复工作，不靠图片加载后再调整高度。 |

参考的源码结构支持上述改进方向；Android 在用户设备上流畅是用户提供的对照，本轮没有同设备同内容的 Android/iOS 帧时间实验，不能给出平台性能倍数。

## 修复任务总表

这些编号只用于本次审计拆分，不自动开始新阶段。全部状态为待实施；P0 表示后续修复共用的验收前置，P1 表示优先处理的高负载路径，P2 表示明确冗余或特定触发条件。

| ID | 优先级 | 修复/验证任务 | 证据与适用条件 | 完成标准摘要 |
| --- | --- | --- | --- | --- |
| SF-00 | P0 | 建立短卡顿的帧节奏与位移双重验收 | G/H；已有“无跳位”测试不能证明顺滑 | 同一预热内容记录卡帧和坐标突变，区分真机、模拟器与自动步进，不以没有 500ms 停顿判绿。 |
| SF-01 | P1 | 复核并减少相同富文本的重复尺寸测量 | S/V；长正文、多个文字块、楼中楼密集 | 相同布局条件复用，变化正确失效；首次尺寸、新文字和选择/复制仍正确。 |
| SF-02 | P1 | 正文分块、表情 runs、子回复前缀只随内容版本准备 | S/V；同内容 View 重算和再次绑定 | 无内容变化不重复解析；更换正文/作者/链接正确刷新，身份及回复目标不变。 |
| SF-03 | P2 | 分离最新动作回调与可见行内容重配 | S/V；anchor/callback 更新、快照完成 | 同内容同环境零内容重配且新回调生效；保留同步绑定、ABA 与迟到结果隔离。 |
| SF-04 | P2 | 只读删除候选准备不再广播点赞 busy | S/H/V；楼层进入/重绑，尤其非本人内容 | 非本人重复出现不触发无关按钮刷新；账号切换与本人权限检查不退化。 |
| SF-05 | P2 | 修复 configuredRows 缓存命中前仍全表扫描 | S/V；长帖停稳 anchor 等更新 | cache hit 时额外逐楼删除查询为零，删除/屏蔽变更仍精确更新。 |
| SF-06 | P2 | 页尾 loading/失败/追加复用既有楼层投影 | S/V；分页边界与长帖 | 页尾变化不重投影旧正文，追加按变化处理；页序、失败保留、预载和几何连续。 |
| SF-07 | P1（含动图） | 减少 GIF 重复解码准备并隔离帧绘制与外层布局 | S/V；可见 GIF/WebP 与滚动并行 | 不每帧重建相同解码源，按显示需要解码；离屏停止、内存有界、滚动行高稳定。 |
| SF-08 | P2（播放中） | 播放者时间进度不刷新无关视频/语音行 | S/V；一个播放者与多个媒体行共存 | 时间 tick 只更新对应进度；单播放器、手动/自动、切主和后台停止保持。 |

### SF-00：验收与一次性计数

现有 `P05MixedCellLifecycleTests` 用预解码 64×48 PNG 和每次 8pt 的程序 offset 步进验证相对位移，明确不是自然拖动 FPS 测试。`U06P3ListWorkTests` 只统计 preparation/snapshot/configuredRowsBuildCount，漏掉同版本可见重配及缓存判断前扫描。

先在当前 HEAD 自行建立固定、预热的六组样本：普通正文；三条长楼中楼；静态图+预览；多动图+预览；视频/语音播放；200/1000 楼分页边界。吧首页为同设备控制组，并注明它的文字截断和静态图差异，不能直接作等复杂度性能比较。

只在短窗口加入无正文/URL/凭据的计数：宿主配置、正文解析、测量 key 命中、测量/布局区间、snapshot、busy 发布、GIF 提交、reading adjustment。按时间关联一次主线程布局与输入/显示间隔，记录 p50/p95/p99/max 和超出当时目标显示间隔的次数；60/120Hz 对应约 16.67/8.33ms 只是预算尺度，实际按 display link 目标节奏和设备状态解释。CADisplayLink 间隔不是独立的 GPU 呈现证据，有条件用 Instruments corroboration；不要把自动化等待、AX 查询、调试器暂停算为 App 卡帧。

保留“可见业务行按预期滚动位移、额外漂移≤2pt”和“拖动时 reading adjustment 为0”检查。性能出口还需要同设备同样本前后对照、短帧尖峰的来源已解释或消除，以及正常 Release 真机慢拖确认；不只检查最终 offset 或长卡死次数。数值门槛由可复现基线确定后冻结，不在实现后调低。模拟器不设置通用绝对 FPS 断言。

### SF-01：文字尺寸工作

证据：`Sources/DesignSystem/Components/TiebaRichTextView.swift:63–66` 每次 proposal 都进入 `UITextView.sizeThatFits`；同文件 `:103` 只避免 attributedText 重建。UIKit 内部可能已有布局缓存，**调用次数不等于完整排版次数**，所以先计数相同 key 的累计时间再决定缓存范围。

最小方向是文本视图内部有界复用最近有效尺寸，不把估计值冒充实际行高。key/失效必须覆盖内容代次、有效宽度、字号、行数限制、相关排版环境及文本容器配置；复用到新业务行后首次返回必须是新内容尺寸。不得全量屏外测量、固定实际行高或改成不可选择文字。

直接回归：长短文交替复用、三预览、最大行数变化、动态字体/旋转、正文选择复制及链接；复用现有 Stage18/19 与 P05 首次短→长测量、迟到回执及几何断言。

### SF-02：不可变渲染准备

证据：`Sources/Features/ThreadReader/Presentation/ThreadContentRenderer.swift:63、73` 在 body 分块并生成 runs；`ThreadReaderFloorViews.swift:212` 为每条预览拼作者前缀并解析；`Sources/Core/Models/TiebaRichText.swift:49` 扫描文本/表情。即使末端 attributedText 短路，前面工作已经完成。

沿用现有展示模型与版本，缓存与内容一同拥有的不可变解析结果，不另造无限全局字典。不能只按 postID 复用，因为相同 ID 内容、引用作者或链接也会更新；主题/父楼/子回复 ID 必须继续分清。颜色/字号敏感的最终 attributedText 仍由现有组件处理。

直接回归：不变内容重复投影解析计数不增加；同 ID 改文字/作者/节点立即可见；图片/外链/用户链接独立动作、复制、1–3 条预览进入三级页再点击回复的 P01 流程保持。Android `PostItemData`/`SubPostItemData` 可作结构参考。

### SF-03：内容版本与动作上下文

证据：`Sources/InteractionKit/VirtualList/VirtualizedList+Version.swift:31–35、44–69` 相同版本仍逐个可见 Cell 生成 RowContent、binding、UIHostingConfiguration；`+Snapshot.swift:89–98` 完成后再更新可见内容。它没有重新 diff 全部行，但也没有跳过可见内容配置。历史自然拖动只有2–4次此更新，不能用它解释所有持续卡顿。

先记录触发原因。若当前开销值得修，将最新 callback/context 与内容配置的有效性分开；不能简单 early return 冻结回调，也不能重新引入观察 holder 的延后首次测量。内容、环境、必要配置变更仍立即呈现。

扩展 `Tests/U06P3ListWorkTests.swift:78–126`：同版本 callback=99 真正响应，正文配置数不增长；内容与字号更新可见；窗口真实挂载后验证新文字/旧结果隔离/ABA/长短行尺寸。不以只检查 State/body 代替实际显示对象。

### SF-04：只读准备的状态隔离

证据：每楼 `ContentDeletionPreparation` 启动 task，`ContentActionStore.prepareDeletion:45` 先进入 `run` 改共享 busy，再 `:46` 比较作者。非本人结果未记录，再次出现仍重复；所有 `ContentLikeButton:18` 读取同一 busy 集合。账号 provider 已缓存/合并，**不是每楼都发账号网络请求**。

候选筛选/准备去重按会话、目标和作者身份拥有，实际写操作 busy 保留；不把临时错误永久缓存成无权限，不取消当前官方 iOS 新鲜检查。历史失败 A/B 必须保留在结论中，本项价值是减少冗余，而非重新宣布找到主因。

直接回归：100个非本人楼层往返复用不发布点赞 busy；本人准备合并；切号、取消、失败后可重试；现有 U14 fresh inspection、明确确认、一次写请求不变。无需进行 Live 点赞/删除。

### SF-05：真正命中 configuredRows 缓存

证据：`Sources/Features/ThreadReader/Presentation/ThreadReaderNavigation.swift:9` 先做全 rows filter/count，第10行才检查已有缓存；`ContentRemovalVisibility.swift:27` 的 predicate contains 又扫描已删目标集合。N楼/R删除目标时额外查询最坏随 N×R 增长；没有删除目标也仍遍历楼层。停稳改 readAnchor 可触发本路径，不是每个手势帧都落盘或扫描。

最小修复是把 removedFloors 放到现有缓存 miss 内，必要时避免临时 filter 数组；不要重造 configuredRows 缓存。是否进一步索引删除集合由计数决定。

直接回归：1000楼、30次 anchor/callback 更新时，configuredRows 缓存命中分支的 removedFloors 扫描计数与删除查询计数均为0；不将此要求扩大为整个阅读位置保存链路零遍历。删除/屏蔽 revision、字体变化更新正确；一级回复数、预览总数和删除时间语义保持。

### SF-06：分页状态与正文投影分离

证据：`ThreadReaderStore.swift:173` 只改页尾 loading，却经 `listPresentation.didSet:39` 增版本；`ThreadReaderNavigation.swift:11–27` 重投影全部旧楼层；容器 `+Snapshot.swift:16–34` 重建字典、过滤已测高度、比较 retained Item。成功追加 `Store:332–347` 再触发。现有 append 和请求合并是有效机制，问题是展示投影仍过宽。

复用旧楼层投影与现有 diffable，只处理变化的页尾、新楼或确实变更的楼层。不要停分页、减预载、延迟到松手后才展示或在拖动期间补 offset。先测20/200/1000楼下 footer-only/append 的实际主线程耗时，再决定是否优化容器层比较。

直接回归：页尾 loading/失败不重解析旧正文；追加只处理必要 delta，服务端对旧楼的真实变更仍生效；正逆序、删除可见性、重复页/过期回执、阅读回位、图片行滚动方向和坐标连续。只涉及分页边界，不能解释远离边界的一切卡顿。

### SF-07：动图解码与帧提交

证据：`AnimatedMediaImage.swift:54–56` 每帧请求 maximumDimension=1024 并写 SwiftUI `@State frame`；`AnimatedImageResource.swift:36–54` 每帧创建 ImageSource 再取缩略帧。解码在既有双 worker executor，**并非已证主线程同步解码**。是否导致外层楼高重复测量，需要单独计数。

优先复用解码 worker 持有的 source/decoder，按实际显示像素需求解码；必要时把固定尺寸内的逐帧绘制从外层 SwiftUI 布局更新中隔离。仍只保留有界当前/在途帧，不预解码全部帧，不禁播 GIF 来掩盖卡顿。不把未声明线程安全的 ImageSource 随意跨线程共享。

直接回归：多 GIF/WebP 与楼中楼同时可见，静态/播放切换尺寸一致；帧顺序/时长、Reduce Motion、离屏和后台停止、迟到帧隔离、释放及内存预算保持；原文件保存与现有图片缓存不变。静态文本帖子不能由本项解释。

### SF-08：播放进度观察范围

证据：`MediaPlaybackController.swift:10` 将 owner/phase/elapsed 放在同一个 observable state；`:73–75、173` 每0.25秒更新；`ThreadPlayableMedia.swift:10、57` 的非播放行也读取 state.owner。属性级观察依赖过宽已确认，实际布局影响待量化。

将 owner/phase 与播放者时间进度的观察范围分开，保留单一 AVPlayer；不要为每楼创建播放器。直接回归：一个播放者和多个闲置行时 tick 不重建闲置内容；换 owner、暂停/结束、失败、后台与自动播放可见性行为不变。没有视频/语音播放时不走这条周期触发链。

## 暂不立为修复 bug 的观察项

- **P01 手势**：`TiebaTextBodyTap` 只有一个 lazy recognizer，字符 hit-test 在触摸/激活时进行，不是每个滚动帧运行。更新 callback 时会重新枚举手势和 require-to-fail，若 SF-00 计数显示有成本再作幂等化，不能删普通文字点击/复制选择。
- **阅读位置与行高**：拖动/减速时 `maintainReadingViewport` 清锚并返回；未测行仍用180估算，但没有当前证据证明这就是微跳。保留 P05 实际新内容尺寸、行高失效规则和几何回归，不改成固定实际高度或全量预测。
- **可见性与图片管线**：已有共享10Hz可见性 hub、裁剪祖先检查、离窗取消，以及后台解码/缓存/请求合并。不能说所有离屏 GIF 都在播放，不能另加第二套缓存。祖先遍历只作计数观察。
- **网络/磁盘**：已加载图片后仍出现的持续不顺滑不能简单归咎慢网；另一方面也没有发现每帧同步写全部帖子到磁盘的路径。不通过清缓存、禁预载或删阅读保存“修复”。

## 执行顺序、范围与验证记录

建议 SF-00 建一个共用小型计数窗口；然后先做 SF-01/02 的文字路径，动图样本并行评估 SF-07 的必要性。SF-05 是低风险独立冗余修复；SF-04/03/06 依据计数逐项推进；SF-08 针对播放场景。每次只改变一个来源，用同一预热样本对照，不要求用户在每个猜测之间反复手工采样。最后一次完整正常 Live/Release 真机确认保留给用户。

后续每项只跑直接相关回归和轻量构建，列表变化额外覆盖 P05 几何/绑定与 P01 两步点击。完整应用安装需覆盖保留账号/草稿/缓存，不卸载、不清数据；发送协议、请求顺序和实际发布动作不在这些任务范围内。修复分组可单独审查，不能把整个表一次性混合实施后无法归因。

本次实际执行：

| 操作 | 结果与边界 |
| --- | --- |
| `git status --short`、`git rev-parse HEAD`、本地 Android ref/remote 核对 | PASS；基线和既有未跟踪文件已记录，未切换/回退。 |
| `rg`、`nl -ba`、`sed` 定点读代码/规格/ADR/P05审计/测试 | 完成上述覆盖；误用 `VirtualizedList/` 和 `Core/Models/ThreadContentBlock.swift` 路径各 exit1，改为实际 `VirtualList/`、`Features/ThreadReader/Presentation/ThreadContentBlocks.swift` 后读取成功；一次测试 glob 无匹配 exit1，改为 `rg ... Tests UITests TestSupport` 成功。均为查找命令问题，不是构建/测试失败。 |
| GitHub 仓库页面读取与本地锁定源码对照 | 完成；未修改/拉取 submodule，未下载依赖。 |
| 当前 Live CUA 观察、15秒 sample | 命令成功，性能样本 INVALID/排除，原因见上；已返回原帖。 |
| 新 Unit/UI、构建、全量 quality | NOT_RUN；本轮只写审计与任务表，无生产/测试修改，没有新增有效帧测量成绩。历史绿灯不冒充本轮通过。 |
| `make secret-scan`、`git diff --check`、新文件检查 | PASS；secret-scan 包括 Docs 下新文件；Python 单独确认未跟踪审计无行尾空白、末尾换行及9个显式仓库路径/行号存在，不借暂存来检查。 |

交付修改仅为本文件及 `Docs/Progress/TASK_STATE.md`。无新增动画、手势、overlay、依赖；无暂存、提交、推送或发布。下一步前置是按选定任务建立当前版本计数/失败回归，不能把本审计完成标为流畅性修复完成。
