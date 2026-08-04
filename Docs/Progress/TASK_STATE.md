# TASK_STATE

- 当前阶段：11
- 状态：`PHASE_11_LIVE_READING_RUNTIME_EVIDENCE_PARTIAL`
- `PHASE_11 = RUNTIME_EVIDENCE_PARTIAL`
- `LIVE_RECOMMENDATION = PARTIAL`
- `LIVE_THREAD = NOT_RUNTIME_VERIFIED`
- `PHASE_12 = NOT_STARTED`
- 当前分支：`main`
- 阶段 07 提交：
  `4b80ed455051b4a7f57aceb3d740d8952cdc371b`
  （`feat: complete stage 07 networking and protobuf foundation`）
- 阶段 08 提交：
  `3b803553f61839aa166aed53ff494d542f17e7ee`
  （`feat: complete stage 08 thread content domain and renderer`）
- 阶段 08 图片状态定向修复：包含本文件的
  `fix: align thread image accessibility with render state`
- 阶段 09 提交：包含本文件的
  `feat: implement production media viewer`
- 阶段 10 提交：包含本文件的
  `feat: complete stage 10 fixture reading flow`
- production live：`RECOMMENDATIONS_BLOCKED_PENDING_REPRODUCIBLE_EVIDENCE`；
  `THREAD_BLOCKED_PENDING_RUNTIME_EVIDENCE`；`LIVE_IMAGES_DISABLED`
- 阶段 06：`PHASE_06_INTERACTION_SPIKES = SPIKE_ACCEPTED`
  （`OPEN_SOURCE_BETA` 范围；已由阶段 09 迁移为唯一生产交互基础）
- 阶段 06C-C：`DEFERRED_POST_BETA`
- 阶段 09 前置条件：`PHASE_09_PREREQUISITES_SATISFIED`
- 阶段 09：`PHASE_09_PRODUCTION_MEDIA_VIEWER_COMPLETE`
- 阶段 10：`PHASE_10_FIXTURE_VERTICAL_SLICE = COMPLETE`
- 阶段 11：`RUNTIME_EVIDENCE_PARTIAL`
- 阶段 12：`NOT_STARTED`

## 阶段 11 当前结果与停止点

阶段 11 从阶段 10 提交
`302b7b8fb34a8da3e1171e6bc5dc48afe548494e` 开始，只处理匿名推荐与帖子
首屏的只读 Live 边界：

- `AppEnvironment` 以显式 `fixture/live` mode 选择 Repository；普通
  Debug/Release production 持有 ephemeral、无 Cookie/credential/cache 的
  `URLSessionHTTPClient`，但两个未达门槛的能力均 fail closed；
  UITesting/LaunchScenario 始终强制 Fixture；
- `LiveRecommendationRepository` 使用阶段 07 EndpointPipeline，把 Proto 只在
  Core mapper 边界转换为推荐领域值；页面布局、导航、Pager 与 MediaViewer
  均未重写；
- 推荐和帖子 Store 各自保存当前 Task 与递增 generation。新请求取消旧请求，
  迟到完成不能覆盖新状态，取消不显示为网络失败；
- PBPage request/response 的实际 Android closure 已锁定为 125 个文件；与
  Personalized closure 合并后的唯一 GeneratedProtobuf target 为 126 个文件。
  `PBPageProtocol`、`LiveThreadReaderRepository` 和纯 `Post.content` mapper 已由
  合成 response、MockHTTPClient 与 replacement/cancellation tests 验证；
- Production 推荐与 ThreadReader 分别由
  `EvidenceBlockedRecommendationRepository` 和
  `EvidenceBlockedThreadReaderRepository` fail closed。它们不回退到 Fixture，
  也不发尚未达到可复现证据门槛的请求；typed Live adapter 仍可由 Mock tests
  和显式 Debug Probe 调用，Fixture 模式完整保留阶段 10 主链路。

2026-08-04 的 Debug-only 匿名推荐 Probe 只记录脱敏指标：所有受控请求均为
HTTP 200、`application/octet-stream` 且 Proto 可解码；曾有一轮早期候选
`client_type` 字段组合返回 5550 bytes/67 mapped items，紧接及最终
Android 静态字段锁定版本均返回合法空页。最终版本为 245 bytes、0 item、
171 ms。没有保存 raw response、正文、threadID、URL、Cookie、token 或设备
标识。由于最终推荐页没有正 threadID，链式 PBPage Probe 按设计未运行；没有
为取得成功而猜 AppPos、设备 ID、签名或循环重试。

因此本阶段不能标记 COMPLETE：推荐 transport/HTTP/MIME/Proto decode 已有
`RUNTIME_OBSERVATION`，但稳定匿名非空推荐、当前最小字段集合和 PBPage 匿名
运行态仍是 `UNKNOWN`。Production 两项能力均按停止条件 fail closed。阶段 12
保持 `NOT_STARTED`，本轮停止，不进入登录、关注、评论、回复、发帖或签到。

阶段 11 最终 `make quality` 从头 exit 0 并输出
`Quality gate completed.`：Unit 216 个逻辑测试/235 次执行、iPhone
smoke 16/16、iPhone interaction 15/15、iPad smoke 5/5、iPad
interaction 2/2 均 0 failed；iPad build、Release build/isolation 同时通过。

## 阶段 11 Known Limitations

1. 最终 evidence-locked 匿名推荐请求当前返回合法空页；早期单次非空结果未
   固化 raw response，因此不能证明稳定匿名推荐、服务端 canonical/pagination
   行为；Android 点击推荐使用 `ThreadInfo.id` 仅作为 route 字段的静态证据。
2. PBPage 的 Android schema/request/mapper/Mock contract 已完成，但没有从最终
   推荐页取得真实 threadID，Production ThreadReader 继续诊断性 fail closed。
3. 没有 live 图片 ImageRepository、candidate 选择、下采样、cache 或 lease；
   Production 继续使用 `DisabledImageLoader`，Fixture 图片链路不受影响。
4. 没有保存 live response fixture；成功/空/畸形/未登录/过期/error taxonomy
   的可复现服务器样本仍不齐全。
5. 本阶段只实现第一页；没有无限分页、楼中楼、删除/私密/折叠常态验证。
6. 阶段 10 的替代请求 rendezvous 风险已由推荐和帖子两组确定性 Task/
   generation 回归覆盖；这不等于 live endpoint 已验证。

## 阶段 11 变更边界

- 新增动画：无。
- 新增手势/Pager/MediaViewer：无。
- 新增 overlay/fullScreenCover：无。
- 新增依赖：无。
- 实际运行的 live 验证：仅 Debug Probe 的少量匿名 HTTPS 请求；Production
  composition fail closed，自动化测试不访问 live。
- 登录、Cookie、BDUSS、STOKEN、Keychain：未读取、未发送、未实现。
- Android submodule：只读且保持 clean。

## 阶段 10 目标与范围

阶段 10 按个人开源 Beta 标准完成 Fixture 驱动的主链路：

- 12 条合成推荐数据使用稳定 threadID，覆盖文字、单图、多图、长标题、
  无图以及不同吧名、作者和回复数；
- `RecommendationsStore` 明确区分 initial loading、loaded、empty 和 failed，
  Repository 协议与 Fixture 实现可由未来 live 数据源替换；
- 唯一 `ThreadReaderView` 按稳定 threadID 加载首楼和 3 个普通楼层，复用
  阶段 08 的 `ThreadContentRenderer`、节点身份与 `ThreadMediaIntent`；
- App scene 持有稳定推荐 Store，并按 root/threadID 复用帖子 Store；pop 后释放
  已离开路由的 Store，状态刷新或 MediaViewer presentation 不重建当前内容；
- iPhone 使用现有系统 push，iPad 使用现有 split detail projection；图片仍只从
  `AppSceneRoot` 的唯一 `fullScreenCover` 进入阶段 09 MediaViewer；
- Release 与 UITesting 均通过可注入 Fixture repository/image loader 演示本地
  内容，`DisabledHTTPClient` 继续阻止 live transport。

本阶段没有新增业务 `NavigationStack`、Pager、MediaViewer、Feature 自有
`fullScreenCover`、手势、动画、overlay、第三方依赖或 live 网络；没有实现
分页、PBPage、完整楼层/楼中楼、登录、评论、缓存大系统或阶段 11。

## 阶段 10 状态与回归

- 推荐和帖子 Store 的首次加载具有稳定 generation、幂等完成和结构化取消；
  失败可显式准备重试，错误 threadID 的 Repository 结果归一为失败并释放当前
  generation，不会永久卡在 loading。
- 推荐列表的 scroll position 双向绑定记录可见锚点；点击条目不主动把选中行
  居中。帖子 Store 与 scene route registry 在 MediaViewer 打开/关闭时保持身份，
  因而帖子和推荐返回位置无需 UUID、延迟或重建 Renderer。
- 同一推荐路由由 `AppNavigationStore` 按稳定 route identity 去重；媒体顺序由
  同一 `ThreadContentDocument` 的稳定 MediaID 决定。
- 新增 7 个阶段 10 Unit test；当前完整 Unit 为 199 个逻辑测试、218 次执行，
  0 failed、0 skipped。
- iPhone 定向主链路 1/1 通过，覆盖推荐中间项、帖子第二张图、2/3→3/3→2/3、
  关闭后帖子 frame 与系统返回后推荐 frame 基本保持。
- iPad 完整 App Shell smoke 5/5 通过，覆盖阶段 10 媒体开关、旋转、
  regular/compact 投影以及既有 Renderer/MediaViewer 回归。
- Simulator 手工观察因本机登录锁屏且自动解锁失败未执行；该项没有被自动化
  结果替代或写成通过。

详细范围、失败先行证据、最终门禁和 Known Limitations 见
`Docs/Audits/PHASE10_FIXTURE_VERTICAL_SLICE.md`。

## 阶段 10 Known Limitations

1. 当前只使用合成 Fixture；没有 live 推荐、帖子或图片请求。
2. 没有分页、完整楼层、楼中楼、删除态业务页或 live PBPage 映射。
3. 没有生产图片共享 cache、candidate 选择、下采样或 full-resolution lease。
4. 没有发布级系统版本/真机/VoiceOver 矩阵；iPhone/iPad Simulator 手工检查因
   Mac 锁屏未执行，自动化覆盖不等同于人工视觉确认。
5. 合成普通楼层仅用于 presentation vertical slice，不构成 Android PBPage
   wire 字段证据；live 推荐 canonical thread identity 与普通楼层 wire 仍为
   `UNKNOWN`。
6. 当前 Fixture Repository 同步完成；未来接入真正 suspension 的 live
   Repository 前，需要补充“旧 View task 正在取消时替代 task 到达”的
   cancellation rendezvous。该序列在本阶段实际 Fixture 主链路不可稳定触发。

## 阶段 10 出口与停止点

`PHASE_10_FIXTURE_VERTICAL_SLICE = COMPLETE`。阶段 11 保持 `NOT_STARTED`，
只能由新的明确用户指令开始。

## 阶段 09 目标与范围

阶段 09 按个人开源 Beta 标准完成唯一生产 MediaViewer：

- 从阶段 08 的 `ThreadMediaIntent` 构建有序、由稳定 MediaID 派生
  `stableKey` 的进程内 presentation；
- 将阶段 06 通过的 Pager、zoom bridge、gesture ownership、
  rotation/resize 与 terminal rendezvous 整体迁移到生产
  `Sources/InteractionKit/Pager` 与 `Sources/InteractionKit/MediaViewer`；
- 在 `Sources/Features/MediaViewer` 只实现一个生产 Viewer，由
  `AppSceneRoot` 唯一 `fullScreenCover` 持有；
- 支持单图/多图、左右切换、双击/捏合缩放、放大后平移、
  chrome 切换、关闭返回、旋转/resize、深色与 Reduce Motion；
- 页面明确区分 idle/loading/rendered/failed-to-fetch/
  failed-to-decode/cancelled，失败可重试且全程使用不透明语义黑底；
- 图片数据仍只通过可注入 `ImageLoading` 获取；UITesting 使用
  固定 fixture/fake loader，Release 仍注入 `DisabledImageLoader`。

本阶段没有实现 ThreadScreen、登录、评论、live 贴吧网络、图片
cache/downsample/candidate/lease 系统或边界加载 Repository；没有下滑
关闭、第二套 Pager、第二个生产 MediaViewer 或新第三方依赖。

## 阶段 09 生产边界与验证

- `MediaViewerPresentation` 拒绝空集合、重复 stableKey 和不存在的
  initial ID；正常身份不使用 `UUID()`。动态数据移除 initial/current ID 后的
  稳定 unavailable 仍是长期合同，本阶段固定 intent 尚未实现该路径。
- `MediaZoomScrollView` 是精确 zoom/contentOffset 的唯一 owner；
  `MediaGestureOwnershipController` 按触摸 begin 固定 Pager/mediaPan/none。
- 只在翻页完成或显式前后切换时增加离场页 reset generation；
  取消/失败不偷换 current ID。
- 关闭失效活动 ownership session 并清理 Viewer 持有的离散状态；
  SwiftUI page task 在移除或 reload 时使用结构化取消。
- 新增 6 个逻辑 Unit test（7 次含参数执行）；当前完整 Unit
  为 192 个逻辑测试/211 次执行，0 failed/skipped。
- iPhone 定向证据覆盖捏合、双击、平移、5 次打开/关闭、三张
  连续切换、zoom reset 和 loading/fetch/decode 全尺寸失败态。
- iPad 定向证据覆盖三图、双击放大、放大后平移不翻页、
  竖→横→竖旋转、chrome/图片存活和关闭返回。
- Release isolation 以 source-list 证明生产 Pager/MediaViewer 均进入 Release，
  并以 binary 字符串证明 MediaViewer；同时排除 Debug lab、LaunchScenario
  和 TestSupport。Pager 没有单独 binary symbol 正向证明。

## 阶段 09 Known Limitations

1. 没有 live 图片网络、共享 cache、candidate 选择、下采样或
   full-resolution lease；Release 中当前无成功图片业务入口。
2. iOS 18.x、真机、真机 VoiceOver/Accessibility Escape 和真实
   iPad split divider 未验证。
3. iPad Simulator 对 1032×1319 全屏元素的 XCUITest pinch 合成
   在首轮不改变 zoomScale；iPhone 捏合已实测，iPad 以同一生产
   zoom wrapper 的双击、平移和旋转完成 smoke。
4. 50 次打开/关闭、100 张 full-resolution 压力、极端内存与全理论
   callback 排列按当前 Beta 标准延期；当前实测为 5 次开关。
5. Debug InteractionLab 仍保留诊断 Viewer shell，但只在 Debug/
   UITesting 编译并复用同一生产 Pager/zoom/ownership 原语；
   它不是可被 Feature 调用的第二个生产 Viewer。
6. 生产 iPhone Viewer 本阶段未单独执行横竖屏 UI smoke；生产 iPad
   竖横竖和阶段 06 底层 iPhone rotation/resize 回归已运行。
7. missing initial 当前作为结构错误拒绝 presentation；动态数据移除
   initial/current 后稳定 unavailable 的长期合同尚未实现。

## 阶段 09 出口与停止点

阶段 09 已在个人开源 Beta 范围完成。阶段 10 前置条件未在本任务评估，
阶段 10 仍是 `NOT_STARTED`，只能由新的明确用户指令开始。

## 阶段 08 历史目标与范围

阶段 08 只完成首楼正文内容领域模型、Proto adapter 和隔离
Renderer：

- 根据锁定 Android reference 建立 P0 内容节点矩阵；
- 生成并交叉验证脱敏 `ThreadInfo.firstPostContent` binary fixture；
- 建立 Proto/SwiftUI 解耦的 `Sendable` / `Equatable` domain；
- 实现保序、稳定 ID、unknown/malformed/presence 降级 mapper；
- 实现只读 SwiftUI Renderer、注入式图片六态与 intent-only 点击；
- 建立 Debug-only Renderer Lab 和 iPhone/iPad 回归。

未建立业务 ThreadScreen、Repository、Endpoint、分页、PB Page/普通楼层
wire、Pager 或 MediaViewer；未发 live request，未读取账号/Cookie/
Keychain，未修改 Android submodule，未读取或执行阶段 09。

## 已读取的规则、规格与技能

- 已读取根目录及 App、Sources/Core、Sources/Features、Specs、Docs、
  TestSupport、Tests、UITests 目录链上适用的 `AGENTS.md`。
- 已读取 `Prompts/08_THREAD_CONTENT_DOMAIN_AND_RENDERER.md`、关联
  Specs、最新 ADR 与进入阶段时的本文件。
- 已显式使用 `.agents/skills/tiebalite-api-evidence`、
  `.agents/skills/ios-feature-slice` 和
  `.agents/skills/xcode-quality-gate`。
- 图片状态定向修复额外显式使用
  `.agents/skills/ios-root-cause-debug` 与
  `.agents/skills/xcode-quality-gate`；三个只读子代理复核状态模型、测试和
  提交边界。
- 三个子代理只读复核 Proto closure/fixture、XcodeGen/target 隔离、
  Renderer/测试/Git 风险；所有工作树写入均由主代理完成。

## Git 与用户工作保护

- baseline HEAD 为阶段 07 final commit
  `4b80ed455051b4a7f57aceb3d740d8952cdc371b`。
- 图片状态定向修复 baseline HEAD 为阶段 08 commit
  `3b803553f61839aa166aed53ff494d542f17e7ee`，祖先检查退出 0。
- Android reference 保持 clean、exact
  `5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`。
- 用户原有 `.idea/dataSources.xml`、`.idea/db-forest-config.xml` 的
  staged/unstaged 状态，以及 `.idea/noctule.xml`、`.idea/vcs.xml`、
  根目录与 prompt kit 的 `.DS_Store` 漂移均未编辑、restore 或纳入
  阶段 08 提交。
- 未 amend、rebase、merge、push、tag、submodule update 或浮动升级
  依赖。

## 证据、闭包与 fixture

- `PbContent.type#1` 是 raw `int32`；Android dispatcher 证明
  `0/9/27/35/40,1,2,3,4,5,10,20` 分支，未知 raw 保持
  unsupported 降级。
- 首楼路径是 `ThreadInfo.firstPostContent#142`，poll 为
  `ThreadInfo.poll_info#74`；`isDeleted#181` 只做保守 nonzero policy。
- 阶段 07 的 51-file closure 完整包含 `ThreadInfo` 47-file 传递闭包；
  `Post.proto` 额外 25 个输入未纳入，本阶段无 generated/schema 差异。
- fixture：
  `TestSupport/Fixtures/API/ThreadContent/thread_content_cross_language.pb`，
  1535 bytes，SHA-256
  `d37a7486974718d660a4b43466d914156c66d36f3f83982507915575e68cdf12`。
- Java `DynamicMessage` 生产器、独立 textproto、两次 JVM generation、
  tracked bytes 与独立 protoc encoding 已逐字节相等。
- fixture 仅含 synthetic 值与 `fixture.invalid`，证据等级为
  `CROSS_LANGUAGE_GENERATED`，不是 live/PB Page response。

## 已实现

### Domain 与 Proto adapter

- `ThreadContentDocument` 按 thread/post/scope/source ordinal 产生稳定 ID。
- 领域值只依赖 Foundation，全部需跨 actor 的值均为 `Sendable`，不泄漏
  generated message。
- mapper 同步、纯值、严格保序，单个坏节点不丢失后续节点。
- 图片候选只保留 HTTPS；外链只接受绝对 HTTP(S)，不允许
  credential、危险 scheme 或畸形目标。
- 图片尺寸明确区分 missing/malformed/non-positive/out-of-range/
  extreme；voice/video 不拼 endpoint、不播放。
- poll 永远只读，零总票数不除零；unknown/meme 只保留安全 presence。
- ADR-0012 将 generated import allowlist 精确扩为两个 Core adapter，
  Feature/View 仍禁止 Proto。

### Renderer 与 Debug Lab

- Renderer 只消费 domain 与注入的 `ImageLoading`，无 URLSession/
  HTTPClient/Repository 直连。
- 图片 idle/loading/rendered/failed-to-fetch/failed-to-decode/cancelled 共用
  稳定框，ratio 限制为 `0.5...3.0`；无安全候选时不调用 loader，取消不
  显示为普通失败。
- 取得 bytes 不等于已显示；只有 decode/prepare 成功且状态请求与当前请求一致
  才使用“已加载”并输出稳定 `ThreadMediaIntent`。两类失败复用“加载失败”，
  无 action/hint/MediaIntent；请求不匹配的旧状态投影为 idle，单调请求代次
  拦截旧完成与旧取消；link/video 仍只输出 `ExternalLinkIntent`，不直接
  push/open/play。
- link/image/video 可交互区至少 44pt；文本支持换行、选择、
  Dynamic Type 与超长内容。
- emoji/mention/video/voice/unknown/poll/empty/deleted/blocked 均有可访问
  只读降级。
- Debug Lab 含 mixed 23 节点、empty、deleted、blocked 四份 domain
  fixture，以及 dark/Accessibility 大字/Reduce Motion 环境摘要。
- Release 包含 production Renderer，但排除 Debug Lab、harness、launch scenario
  和 canary。

## 行为先行与回归覆盖

- `20260801-073821-10588-unit.xcresult`：先写测试，domain 未存在时
  编译按预期失败。
- `20260801-074504-16621-ui-smoke.xcresult`：先写 UI 验收，Lab 未存在
  时按预期失败。
- 中间 Renderer UI 失败包
  `075207-20493`、`075627-22528`、`075820-24151`、
  `075940-25763`、`080106-27307`、`080331-28906`、
  `080504-30510`、`080709-32157`、`080817-33663`、
  `081036-35301`；分别暴露并修复菜单可达、loading 查询、图片
  frame、accessibility value、滚动方向与超长文本上界。
- 阶段 08 新增 20 项 mapper/cross-language test 与 6 项 Renderer
  contract test；全仓 Unit 为 111 项。
- iPhone 定向 Renderer：
  `20260801-083757-54280-ui-renderer.xcresult`，1/1，96.831s。
- iPad 定向 Renderer：
  `20260801-084038-56604-ui-renderer-ipad.xcresult`，1/1，39.745s。

图片状态定向修复的行为先行证据：

- 修复前新增 invalid-bytes fixture 回归；
  `stage08-red-1.xcresult`、`stage08-red-2.xcresult`、
  `stage08-red-3.xcresult` 三次均稳定失败（exit 65），证明 loader 成功后
  phase/accessibility 仍误报 loaded/“已加载”。
- 初次修复后 `stage08-image-state-green-2.xcresult` 通过，包含 7 个逻辑用例：
  合法解码、fetch failure、decode failure、六态 accessibility value、
  成功/失败 MediaIntent 与重复确定性；既有真实取消传播用例保留。
- 只读行为复审发现请求 A 的 rendered 状态可能在请求 B task 启动前复用，且
  同请求旧取消缺少代次保护；新增请求替换回归在
  `stage08-request-binding-red-1-all.xcresult`、
  `stage08-request-binding-red-2.xcresult`、
  `stage08-request-binding-red-3.xcresult` 三次 suite 执行均稳定失败
  （exit 65）。绑定请求并加入 generation guard 后，
  `stage08-request-binding-green.xcresult` 为 8/8。
- `stage08-request-binding-red-1.xcresult` 的方法级 selector 实际筛选 0 项，虽
  xcodebuild exit 0，但明确不计为通过证据。
- 复审补充的“已取消 task + loader 普通错误”回归在
  `stage08-cancel-error-red.xcresult` 失败（exit 65）；普通 error catch 先检查
  task cancellation 后，`stage08-cancel-error-green.xcresult` 通过，取消不再
  被错误映射为 fetch failure。
- 最终聚焦图片状态套件 `stage08-image-state-final.xcresult` 为 9/9。
- iPhone Renderer：
  `20260801-100220-92089-ui-renderer.xcresult`，1/1，114.590s；同时覆盖
  dark、Accessibility Dynamic Type、Reduce Motion。
- iPad Renderer：
  `20260801-100830-96413-ui-renderer-ipad.xcresult`，1/1，56.192s；覆盖
  regular/compact、旋转与两类失败 action 缺失。

## 本轮真实执行的命令与结果

- `git status --short`、`git log -4 --oneline --decorate`、
  `git rev-parse HEAD`、`git branch --show-current`：确认 baseline、`main`、
  阶段差异与用户漂移并存。
- `git submodule status -- References/TiebaLite-Android` 与 submodule
  `status --porcelain`：exact/clean。
- `make instructions`：全部指令链小于 32768 bytes，8 个 repo skill
  validation 通过。
- `make generate`：51 个 Proto 两次生成一致，XcodeGen 与 canonical
  SwiftPM lock materialization 通过。
- `make verify-protos`：两次 clean generation 与 tracked output 一致；
  上游 `ThreadInfo.proto` 持续产生 5 个 unused-import warning。
- `make generate-thread-content-fixture`：生成 1535-byte tracked fixture。
- `make verify-thread-content-fixture`：两次 JVM、tracked 与独立 protoc
  bytes 一致。
- `make secret-scan`：无 high-confidence match；已覆盖
  `scripts/fixtures`。
- `make networking-isolation`：0 failure；production 仍是
  `DisabledHTTPClient`，Proto/Renderer/网络/Pager/MediaViewer/手势/动画/
  overlay 边界通过。
- `make lint`：78 files，0 violation。
- `make test-unit`：
  `20260801-083720-52559-unit.xcresult`，Test Succeeded。
- `make test-ui-renderer`：
  `20260801-083757-54280-ui-renderer.xcresult`，1/1。
- `make test-ui-renderer-ipad`：
  `20260801-084038-56604-ui-renderer-ipad.xcresult`，1/1。
- `make quality-fast`：退出 0；Debug build
  `20260801-084235-63908-build.log`，Unit
  `20260801-084238-64028-unit.xcresult`，所有静态/生成/隔离门禁通过。
- `make quality`：从头退出 0 并输出 `Quality gate completed.`：
  - Debug build：`20260801-084337-67125-build.log`；
  - Unit：`20260801-084339-67179-unit.xcresult`，111/111；
  - iPhone UI smoke：`20260801-084408-67708-ui-smoke.xcresult`，13/13；
  - iPhone interaction：`20260801-084900-69328-ui-interaction.xcresult`，5/5；
  - iPad build：`20260801-085402-69867-ipad-build.log`；
  - iPad UI smoke：`20260801-085404-69920-ui-smoke-ipad.xcresult`，3/3；
  - iPad interaction：
    `20260801-085604-70212-ui-interaction-ipad.xcresult`，1/1；
  - Release build：`20260801-085646-70369-release-build.log`；
  - fresh Release isolation 与 UITesting isolation 通过。
- 7 次
  `xcrun xcresulttool get test-results summary --path ... --format json`：
  final Unit/UI 与两个定向 Renderer result 均为 `Passed`，0 failed、
  0 skipped。
- `bash -n` 核对 5 个阶段相关 shell script：PASS。
- `git diff HEAD --check`：文档更新前 PASS；提交前需重跑并仅根据
  最终结果交付。

不计为产品失败、但确实执行过的诊断失败：

- fresh Release 之前直接跑 `scripts/verify_release_isolation.sh` 退出 1，
  原因是旧 Release SwiftFileList 未包含 Renderer；`make quality` 重建后同一
  verifier 已通过。
- 只读审计中 3 次未批准权限的 `xcresulttool` 因无法写
  `TestReport` 退出 64；最终从 `/private/tmp` 以批准权限重跑 7 份
  结果并全部通过。
- 辅助进程检查 `pgrep` 因环境缺少 sysmond 退出 3；不影响 Xcode
  命令或验收结果。

### 图片状态定向修复已执行命令

- `git status --short`、`git diff --stat`、`git diff --cached --stat`：确认
  仅有既存 `.idea`/`.DS_Store` 漂移；两项 `.idea` 仍保持用户预暂存状态。
- `git rev-parse HEAD`：
  `3b803553f61839aa166aed53ff494d542f17e7ee`；
  `git merge-base --is-ancestor 3b803553... HEAD`：exit 0。
- 修改前 `make quality-fast`：exit 0；Unit bundle
  `20260801-093910-79912-unit.xcresult` Test Succeeded。
- 三次修复前定向 xcodebuild：均 exit 65；修复后两次定向 xcodebuild：
  `stage08-image-state-green-1.xcresult` 与改名/拆文件后的
  `stage08-image-state-green-2.xcresult` 均 Test Succeeded。
- 首次 `make lint`：exit 2，真实发现 UI 测试函数体、测试类型名和 Renderer
  文件长度共 3 项违规；拆出单一图片展示状态文件并提取测试 helper 后，后续
  三次 `make lint` 均为 80 files、0 violation。
- 首次 `make test-ui-renderer`：exit 2（底层 xcodebuild 65），失败于测试
  只向下滚；修正 test support 后复跑 1/1。
- 首次 `make test-ui-renderer-ipad`：exit 2（底层 xcodebuild 65）；导出的
  hierarchy 证明 n11/n12 存在，截图证明 split-view 全局 swipe 未滚动详情列；
  将手势限定到 Renderer 测试根后复跑 1/1。
- 首次最终 `make quality` 在 iPhone UI smoke 运行中被主动中断，make exit 1
  （底层 `test-ui-smoke` Error 73）；原因是只读复审发现上述请求归属阻塞项，
  该次不计质量结论，修复后必须从头重跑。
- 最终 `make instructions` 与 `make secret-scan`：exit 0。
- 最终首轮 `make lint`：exit 2，取消回归令 `ThreadContentTests.swift` 达 643
  行；将该直接回归及 loader 移至本任务图片状态测试文件后复跑为 80 files、
  0 violation。
- 最终 `make test-unit`：exit 0；
  `20260801-103959-16839-unit.xcresult` 为 120 个逻辑测试、129 次执行、
  0 失败/跳过。
- 最终 `make test-ui-renderer`：exit 0；
  `20260801-104059-18459-ui-renderer.xcresult`，1/1，113.990s，覆盖 dark、
  Accessibility Dynamic Type 与 Reduce Motion。
- 最终 `make test-ui-renderer-ipad`：exit 0；
  `20260801-104330-20268-ui-renderer-ipad.xcresult`，1/1，54.994s，覆盖
  regular/compact 投影与旋转。
- 最终 `make quality-fast`：exit 0；Debug build
  `20260801-104543-22813-build.log`，Unit
  `20260801-104546-22887-unit.xcresult`，所有生成、静态、隔离和 diff 门禁通过。
- 最终 `make quality`：从头 exit 0，并输出 `Quality gate completed.`：
  - Debug build：`20260801-104657-25457-build.log`；
  - Unit：`20260801-104658-25495-unit.xcresult`，120 个逻辑测试、
    129 次执行、0 失败/跳过；
  - iPhone UI smoke：`20260801-104728-25787-ui-smoke.xcresult`，13/13；
  - iPhone interaction：
    `20260801-105241-26551-ui-interaction.xcresult`，5/5；
  - iPad build：`20260801-105743-26977-ipad-build.log`；
  - iPad UI smoke：`20260801-105746-27033-ui-smoke-ipad.xcresult`，3/3；
  - iPad interaction：
    `20260801-110002-27314-ui-interaction-ipad.xcresult`，1/1；
  - Release build：`20260801-110045-27466-release-build.log`；
  - UITesting isolation、Release isolation 与最终 `git diff --check` 均通过。
- 最终只读行为复审：A→B 请求归属、generation、取消优先级、视觉/
  accessibility 与 MediaIntent 一致性均无剩余阻塞。
- `xcrun xcresulttool get test-results summary` 与
  `xcrun xcresulttool export attachments`：读取 iPad 失败包并导出 63 个测试
  附件到临时目录，仅用于确定测试滚动归属。

## 新增或变更的动画、手势、overlay、依赖

- 新增动画：无。
- 新增业务手势：无。
- 新增 overlay：无。
- 新增业务页面：无；仅新增 Debug-only 隔离 Renderer Lab。
- 新增生产依赖：无；SwiftProtobuf 继续 exact 1.38.1 /
  `55d7a1cc5666b85c13464aea1c4b4a90feccb4c8`。
- Android submodule 修改：无。

## 未验证与剩余风险

1. 未发 live request；服务端 raw 分布、真实 malformed 形态、媒体可达性
   和分发权利仍为 `UNKNOWN`。
2. raw `9/27/35/40/20`、meme、emoji registry、`isDeleted#181`、
   quote 的完整 live 语义未知。
3. PBPage、普通楼层 Post/fold/delete、楼中楼、分页、ThreadScreen 和
   滚动位置未实现/验证。
4. 不可解码 bytes 的状态语义已修复；`ImageLoading` 当前仍只接收
   resource ID，生产 URL/version cache key、candidate 选择、下采样、大图
   解码性能和 lease 需后续设计。
5. document/poll 顶层 accessibility ID 未包含 source；同屏多个
   Renderer 时可重复。极端超长 poll 标题/选项在 Accessibility 大字下仍需
   专项裁切测试。
6. UI/Unit 使用 iOS 26.5 Simulator；iOS 18.x、真机、VoiceOver
   实操和真实 iPad 分屏未验证。
7. 公开/App Store/商业分发仍被 ADR-0011 权利边界阻塞。
8. 阶段 06 已按个人开源 Beta 风险范围接受；发布前矩阵仍保留为 Known
   Limitations，详见本文件末尾与
   `Docs/Audits/INTERACTION_SPIKE_REPORT.md`。

## 下一阶段前置条件

阶段 08 出口时，阶段 06 interaction foundation 已按个人开源
Beta 标准收口，阶段 09 当时为 `NOT_STARTED`。该历史状态已由本文
顶部的阶段 09 生产完成状态取代；06C-C 仍为
`DEFERRED_POST_BETA`。

阶段 06 的生产迁移、Release 隔离和唯一 Pager/MediaViewer 约束继续有效；
`SPIKE_ACCEPTED` 只接受当前 Debug interaction foundation 的架构与回归证据，
不把 Debug 源码自动晋升为生产组件。

## 阶段 06B Pager / Media Spike 收口（历史出口）

- baseline HEAD：`b205af6d0bd91d51cb7bc83b6e70f6da7fe93fbe`；Android reference
  始终 clean/exact
  `5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`。
- 已关闭：stale deferred selection ownership、iPhone 双向旋转 coordinator
  continuity、5 次 34% 宽度拖动取消、cached scroll 实际 zoom/offset reset、
  极端宽高比 resize 有限值、Reduce Motion zoom 分支、Zoom weak release、
  iPhone 5 次 open/close、iPad Media settled 旋转/切图/关闭。34% 拖动不计作
  严格半程覆盖。
- 新复现：Computer Use 在 iPhone Media zoom/pan 后旋转，业务 ID 与 zoom
  仍正确，但 chrome 按钮不可见/裁出可视区；证据截图：
  `Artifacts/TestResults/phase06b-media-rotation-chrome-clipped.png`。
- 运行环境只有 iOS 26.5（23F77）；没有 iOS 18.x runtime。真实 split-view
  divider 与 VoiceOver 未验证。
- `MediaGestureSession` 没有接到 recognizer begin，runtime fixed-owner 仍是
  阶段硬阻塞；未引入私有 recognizer API 或新的自定义手势来绕过。
- 阶段 08 图片六态与 MediaIntent 边界未修改；未创建 ThreadScreen、生产
  MediaViewer、live 网络、缓存、候选、下采样或 lease。
- 最终 `make quality` exit 0 并输出 `Quality gate completed.`；严格
  `xcresulttool` 结果为 Unit 125/125（设备参数执行 134）、iPhone smoke
  13/13、iPhone interaction 7/7、iPad smoke 3/3、iPad interaction 2/2，
  全部 0 failed/0 skipped/0 expected failure。绿色自动化不替代未完成的
  mandatory 实机验收。
- 该任务出口的状态决定：`PHASE_06_INTERACTION_SPIKES = SPIKE_PARTIAL`；
  当时 `PHASE_09_BLOCKED_UNTIL_PHASE_06_SPIKE_ACCEPTED` 保持；阶段 09 仍为
  `NOT_STARTED`，本轮未读取或执行阶段 09。该状态已由本文件末尾的 Beta
  acceptance 取代。

## 阶段 06C-A Media 手势与旋转硬阻塞收口（历史出口）

- baseline HEAD：`d33f10f3104989e0b543fd7172608bd12b6b33aa`；Android reference
  仍 clean/exact `5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`。
- 该任务出口状态：M1 runtime fixed-owner、M3 resize clamp/frame 和 V1
  iPhone zoom/pan 旋转 chrome 裁切均 `CLOSED`。阶段 06 当时仍为
  `SPIKE_PARTIAL`，阶段 09 当时仍 `NOT_STARTED` 且 `BLOCKED`。
- M1：在唯一 Debug Pager 上安装 ownership gate，于
  `gestureRecognizerShouldBegin` 一次性记录 session ID/generation/MediaID、
  began zoom/offset/velocity/translation、owner/reason。owner 在 ended/
  cancelled/failed 前不变；MediaID 或 generation 不匹配的旧 session
  不能 resolve Pager。
- V1：single tap 现在等待 double tap 和 media pan 失败，pan 不再
  误隐藏 chrome。chrome 使用独立 Media root coordinate space、同一
  layout pass 的 root/frame/safe-area 投影，与 zoom/contentOffset 无关。
- M3：zoom scroll 使用真实 aspect-fit image frame，不把 letterbox
  计入 pan range；resize 保留 normalized focal point 并对新 viewport
  完整 clamp x/y offset。同 MediaID 的新 image identity 会重建几何。
- Debug-only accessibility metrics 记录 root/chrome/session/input/viewport、window、
  safe area、layout/coordinator generation 及 invalid counter；Release 仍排除全部
  Debug labs。
- iPhone 实际执行 10 次 Pager 往返（20 转场）、10 次 zoomed
  media pan 与 10 个竖→横→竖周期；iPad 执行 5 个 zoom/pan
  旋转周期；dark + Accessibility 5 + Reduce Motion 执行 1 套完整矩阵。
  修复前证据为 `phase06ca-before-pan-hides-chrome.png` 和
  `phase06ca-before-landscape-chrome-hidden.png`；修复后 10 周期证据为
  `phase06ca-after-ten-rotation-cycles.png`。
- 最终 `make quality` exit 0 并输出 `Quality gate completed.`；
  `xcresulttool` 确认 Unit 146/146 顶层测试（155 次含参数执行）、
  iPhone smoke 13/13、iPhone interaction 9/9、iPad smoke 3/3、
  iPad interaction 2/2，全部 0 failed/0 skipped/0 expected failure。
- 新增生产动画 0、产品手势 0、overlay 0、依赖 0、live network 0。
  未使用 asyncAfter/sleep/UUID/magic zIndex/透明 blocker/全局禁动画等
  禁止假修复。
- 该任务当时未开始 06C-B；P3/P4/P5/M4/M5、真实 iPad split divider、
  iOS 18.x 和 VoiceOver 是当时的明确未验证项。详细根因、红绿结果包与
  最终证据见
  `Docs/Audits/INTERACTION_SPIKE_REPORT.md`。

## 阶段 06C-R terminal rendezvous 定向修复（历史出口）

- baseline HEAD：`367e420c979a927cb746c1e441ee1c3dc7a3a12c`；现有未提交 06C-B
  P3/P4/P5 工作完整保留，Android reference 仍要求 clean/exact
  `5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`。
- 修复前完整 Unit 为 171 个逻辑测试/182 次执行/3 个确定性失败：Media
  ownership cancellation 晚到前 Pager 提前提交，以及两个错误 delegate
  snapshot 提前消费 callback context。
- 当前使用 `@MainActor` 三方 delegate/Pager terminal/Media ownership terminal
  rendezvous。ownership `active` 只能 pending；仅相同 generation 的
  `ended(owner: pager)` 可授权。cancelled/failed/invalidated/`mediaPan`、旧
  external selection generation 或 stale host/controller 均不发布 selection。
- delegate 完整验证 transition、PageID、host identity、direction、external
  generation 与 installation generation 后才记录；无效 callback 不清 context、
  不增加 resolved count、不改变视觉页或 selection，后续正确 callback 可继续。
- 外部 selection 变化只标记 supersession，保留 source/target 至 D/P/O terminal
  齐全，再应用 live generation binding 的最新选择；recognizer replacement、
  same-ID stale host 和 same-ID ownership generation 均有直接回归；最终 join
  还会重新核对当前 ownership generation/session，防止先到的旧 terminal 证据提交。
- review 红包为 14 个逻辑测试/21 次执行/7 个失败，修复后同套件 0 失败；
  O-first 旧 generation 回归又以 7 个逻辑测试/14 次执行/1 个失败先红后全绿；
  扩大定向套件连续三次均为 31 个逻辑测试/39 次执行/0 失败，完整 Unit 为
  186 个逻辑测试/204 次执行/0 失败。新增生产动画、产品手势、生产/阻断 overlay、依赖
  和 live network 均为 0。
- 未进入 06C-C，未读取或实现阶段 09，未创建生产 Pager/MediaViewer、
  ThreadScreen、cache/candidate/downsample/lease。06C-R 任务出口当时保持
  `SPIKE_PARTIAL`；该历史状态已被下方 Open-Source Beta acceptance 取代。

## 阶段 06 Open-Source Beta 收口（2026-08-02）

### 阶段 06 任务出口状态（已由阶段 09 生产迁移取代）

- `PHASE_06_INTERACTION_SPIKES = SPIKE_ACCEPTED`
- `PHASE_06_ACCEPTANCE_SCOPE = OPEN_SOURCE_BETA`
- `PHASE_06C_C = DEFERRED_POST_BETA`
- `PHASE_09_PREREQUISITES_SATISFIED`
- `PHASE_09 = NOT_STARTED`
- `PRODUCTION_PAGER_MEDIA = NOT_CREATED`

以上是阶段 06 当时的任务出口；生产 Pager/MediaViewer 后续由本文顶部记录的
阶段 09 任务创建，不反写历史状态。

P3/P4/P5 在当前 Beta 范围内均为 `CLOSED`：P3 有 49%/51% 各 5 次、独立
velocity 分支、20 次交替 rapid-serial swipe、左右边界各 20 次和 5 次纵向
jitter；P4 覆盖 retained refresh/loading/failure、initial loading/failure/
empty、不透明全 bounds、partial drag 中 5 次 refresh 与 stale generation；
P5 覆盖缓存内 identity、refresh/resize/projection、明确 eviction 后 weak release、
100 PageID 的 cache/创建次数上界及 dismantle 释放。06C-R 的三个原始回归与
扩展 D/P/O rendezvous、non-consuming callback 回归全部保持绿色。

### 本次收口验证

- `make lint`：110 个 Swift 文件，0 violation。
- 三个原始 rendezvous 回归逐名通过；定向结果包同时运行相邻类用例，共
  16 个逻辑测试、17 次执行，0 failed/skipped/expected failure。
- `make test-unit`：186 个逻辑测试、204 次执行，全部通过。
- `make quality-fast`：instructions、reference/proto/fixture/lock/determinism、
  forbidden/static canaries、secret/network isolation、lint、Debug build、Unit 与
  diff check 全部 exit 0；其 Unit 同为 186/204。
- 本次完整 Unit 结果包为
  `Artifacts/TestResults/20260802-112421-10375-unit.xcresult`；quality-fast Unit
  为 `Artifacts/TestResults/20260802-112512-13014-unit.xcresult`。
- 同一组合工作树此前完整 `make quality` 已通过：Unit 186/204、iPhone smoke
  13/13、iPhone interaction 15/15、iPad smoke 3/3、iPad interaction 2/2，
  Release build/isolation 通过。
- Android reference 保持 clean/exact
  `5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`。

### Known Limitations（不再阻塞阶段 09）

1. 当前 runtime 证据来自 iOS 26.5 Simulator；iOS 18.x 与真机矩阵未验证。
2. 真机 VoiceOver/Accessibility Escape 未实操；真实 iPad split divider 仍属
   发布前矩阵。
3. 真实同一触摸越过半程后反向回撤的录屏未完成；确定性 transition trace 与
   runtime recognizer 共用策略已覆盖，但该手工证据延期。
4. 100 张 full-resolution lease、所有图片尺寸与极端内存/快速翻页压力未验证；
   当前 100 页证据只证明 controller/cache/昂贵内容创建上界。
5. UIKit 完全同签名且不携带 token 的迟到 delegate callback 无法由公开 API
   自证来源；当前 generation/host/visible/direction 防线已覆盖可观测身份，
   完全不可区分的理论排列留作发布前平台矩阵。
6. InteractionLab 继续 Debug/UITesting-only；生产 Pager/MediaViewer 已在
   阶段 09 迁移，ThreadScreen、live image pipeline、cache/downsample/
   candidate/lease 仍未创建。
