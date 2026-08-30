# API / Protobuf 证据

状态：`STAGE16B_USER_PROFILE_ANONYMOUS_RUNTIME_VERIFIED`

Android 基线：`4.0-dev@5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`。

阶段 07 完成首个 Personalized schema/request/response 的本地协议闭环：
从 pinned Android submodule 直接生成 51 文件闭包，以独立 JVM producer 构造
脱敏 binary fixture，并由 SwiftProtobuf decode/map。没有注册任何 Tieba live
host、没有发送真实请求，production composition 继续使用
`DisabledHTTPClient`。

阶段 08 在同一 51-file closure 中新增一份独立的合成首楼正文
`ThreadInfo.firstPostContent#142` cross-language fixture，并映射
`PbContent/PollInfo/PollOption` 为与 Proto/SwiftUI 解耦的领域值。该 fixture
不是 PB Page response，不证明普通楼层、分页或 live endpoint。

阶段 11 将唯一生成闭包扩展到 Personalized + PBPage 的 126 个文件，并建立
两套 typed Live adapter。2026-08-04 的 Debug-only 匿名 Personalized Probe
真实观察到 HTTP 200、`application/octet-stream` 和可解码 Proto；一轮早期
候选字段组合返回 5550 bytes/67 mapped items，但最终 evidence-locked request
重复返回合法空页（最终一轮 245 bytes/0 item/171 ms）。没有保存 raw response
或内容 fixture，因而这只是 `RUNTIME_OBSERVATION`，不能关闭稳定匿名能力、
最小参数、分页、错误 taxonomy 或 canonical identity。

阶段 11 最终推荐空页没有提供正 threadID，链式 PBPage Probe 按设计未运行；
当时 PBPage 只有锁定 Android call site/schema、确定性 request、合成 response
mapper 和 MockHTTPClient contract evidence，因此推荐和帖子两项 Production
能力均 fail closed。阶段 15 后续以公开 FRS 主题取得真实 threadID，并补齐下文
PBPage 匿名两页运行证据；推荐能力当时仍保持 fail closed。凡仍使用明文 HTTP
的链路状态为 `BLOCKED`，必须先找到并验证 HTTPS 等价路径。

阶段 12 在同一 evidence-locked Personalized request 上增加显式 active
AuthContext：由可见 WKWebView 取得 Android 已证的两个候选 Cookie 字段，经
Keychain/lease 边界授权后执行一次 Debug-only 请求。脱敏运行观察为 HTTP
200、`application/octet-stream`、83924 bytes、Proto decode 成功、12 mapped
items、`outcome=success`。没有保存 raw response、请求体、Cookie、账号或用户
内容。该单次观察只证明客户端在 matching lease 下完成了一条携带候选字段的
Personalized 请求；不证明服务端实际消费了 credential、把响应归因于认证或
接受它们作为最小集合，也不关闭匿名稳定性、token rotation、expired taxonomy、
PBPage 或 Production evidence gate。请求的 `page_thread_count=11` 只是
call-site hint；本次映射 12 项，不能把 11 声明为响应上限。

阶段 15.5 修复的是 Simulator Keychain 签名前置条件与启动 restore gate，不是
请求字段猜测。2026-08-09，在保留原 Keychain item、没有 logout/卸载/清理或
重新登录的签名 iPhone Simulator 构建中，App 自动恢复 active lease：

- Production active Personalized 首屏：HTTP 200、
  `application/octet-stream`、74924 bytes、Proto decode=true、mapped=12、
  typed outcome=success，推荐页显示非空内容；
- Production authenticated ForumGuide：HTTP 200、
  `application/octet-stream`、9199 bytes、Proto decode=true、mapped=18、
  typed outcome=success，“我关注的吧”显示真实列表；
- 两页往返没有重复登录提示。Repository 在请求前和响应后复验同一 lease；
  signed-out 在 HTTP 前 fail closed，替换 lease 的迟到响应不发布。

本次只记录 status、MIME、body byte count、decode、mapped count 和 typed
outcome；没有记录或保存 Cookie/credential、Cookie/Authorization header 或完整
headers、请求体、raw response、吧名、帖子正文或用户内容。自动化继续只使用
FakeSession、Fixture 和 Mock HTTP。

阶段 14 在同一 HTTPS Proto family 中加入 FRS Page 的最小生成闭包、typed
request/mapper、synthetic fixture 和 Debug-only 匿名 Probe。2026-08-05，
固定公开测试吧在无凭证 iPhone 与测试 iPad Simulator 上均观察到 HTTP 200、
`application/octet-stream`、54068 bytes、Proto decode 成功、13 mapped
threads、`outcome=success`；页面能显示吧摘要和帖子列表。没有保存 raw
response、帖子/作者内容、Cookie、请求体或设备标识。这足以解除 Forum Home
匿名首屏的 Production evidence gate，但不证明分页、ThreadList、所有吧、
错误 taxonomy 或内容长期稳定。

阶段 14P 在同一精确 FRS request family 上增加顺序下一页。
2026-08-09 的无凭证 Debug-only Probe 观察到 `pn=2/load_type=2`
返回 HTTP 200、`application/octet-stream`、156269 bytes、Proto decode
成功；首屏 13 条，追加 30 条后聚合 43 条，`typed-error=none`、
`outcome=success`。没有保存 raw response、请求体、Cookie、吧/帖子/
用户内容或设备标识。该证据只解除顺序 FRS 第二页的开源
Beta 门禁；第三页以及 `thread_id_list + ThreadList` 仍无运行证据。

阶段 15.6 只补齐 PBPage 与 Personalized 的普通顺序分页，不扩大
Proto 闭包、Session 或列表承载边界。2026-08-09 的脱敏运行证据：

- 一个公开长帖以匿名普通升序 PBPage 连续取得三页；三页 HTTP
  均为 200，MIME 均为 `application/octet-stream`，body 为
  24893/16779/13805 bytes，Proto decode 均成功，分别映射
  17/15/15 个楼层，按 `Post.id` 累计 45 个唯一楼层。服务端
  `current_page=1/2/3`，三页 `has_more` 均为 1，因此第三页
  已证不再被本地强制 terminal。首屏固定使用 `pid=0`；
  page2/page3 因前一页 pids 无未见正候选而按 Android 回退规则
  使用 `pid=0`。page3 映射出的未来 cursor 也为 0，但未发出 page4；
- 保留的 active session 下，Personalized 首页
  `load_type=1,pn=1`，第二页 `load_type=2,pn=2`，
  `page_thread_count=11`。第二页 HTTP 200、
  `application/octet-stream`、72958 bytes、Proto decode=true、mapped=12，
  相对首页新增 12 个稳定 `ThreadInfo.id`，typed outcome=success。

运行只记录 status、MIME、byte count、decode、page/count 和 typed
outcome；没有记录 threadID/postID 值、标题、正文、完整响应、请求体或
credential。Android 代码证据表明 `Page.has_more=0` 是客户端停止信号，
iOS 将其作为 wire terminal 合同；真实三页都为 1，服务端末页行为仍是
`RUNTIME_UNKNOWN`。
Personalized response 仍没有 terminal 字段；空页或 duplicate-only 页
停止是 iOS 的受测 client no-progress policy，不是服务端 `hasMore`。

阶段 16B 只扩展用户资料这一个 HTTPS Proto family。锁定 Android
`MixedTiebaApiImpl.userProfileFlow` 调用 V12
`ProfileRequest/ProfileResponse`；iOS 只使用正 `friend_uid` 查询他人公开
资料，descriptor 为 anonymous，不读 Session/Keychain。请求和 mapper 的
确定性、identity 匹配、公开字段白名单、合成 binary fixture 和 Mock
Repository 已验证。2026-08-30 的 Debug-only anonymous Probe 返回
HTTP 200、`application/octet-stream`、4475 bytes、Proto decode=true、
11 个可展示字段、typed error=none。该 Probe 没有读取 Session/
Keychain，且不记录公开作者的 ID、名称、正文或完整响应。

## 公共传输证据

### Protobuf family

- `CODE_EVIDENCE`：`RetrofitTiebaApi.OFFICIAL_PROTOBUF_TIEBA_API` 和 V12 variants 的 base URL 是 `https://tiebac.baidu.com/`。
- `CODE_EVIDENCE`：`OfficialProtobufTiebaApi` 使用 POST；`ProtobufRequest.buildProtobufRequestBody` 以 multipart/form-data 的 binary `data` part 发送 Wire `Message.encode()`。
- `CODE_EVIDENCE`：V12 Proto interface 的实际 header 名为
  `x_bd_data_type: protobuf`；请求还使用客户端版本/类型 header。iOS 未复制
  Android 设备标识。
- `CODE_EVIDENCE`：`ProtoFailureResponseInterceptor` 以公共 `Error.error_code` 判定业务失败；具体响应仍需独立解码。`Error.user_msg` 没有被现有异常映射完整保留。
- `CODE_EVIDENCE`：`CommonRequest` 可包含 BDUSS/STOKEN、设备/安装/屏幕/版本字段；外层 multipart 也可能附 `stoken`。
- `CODE_EVIDENCE`：`buildCommonRequest(TIEBA_V12, bduss, stoken)` 的 V12 分支忽略传入的两个参数，改读全局 `AccountUtil`；`buildProtobufRequestBody(..., needSToken=true)` 的外层 stoken 也读全局账户。
- `INFERENCE`：这会让“为新登录账户显式传凭据”的 caller 与实际发送账户不一致，可能发送旧/空 session。它是必须规避的 Android 实现风险，不是 iOS 认证契约。
- `UNKNOWN`：哪些字段是服务端最小必需值、哪些仅为 Android telemetry、
  iOS 合法客户端标识、签名与版本兼容。匿名接受性默认逐 endpoint 保持
  `UNKNOWN`；阶段 14 FRS 固定公开吧首屏已有下文的限定运行证据。

### Form / JSON family

- `CODE_EVIDENCE`：`RetrofitTiebaApi.OFFICIAL_TIEBA_API`、`MINI_TIEBA_API` 和 `NEW_TIEBA_API` 的 base URL 是 `http://c.tieba.baidu.com/`；Manifest 允许 cleartext。
- 结论：这些 endpoint 不得直接进入 iOS。即使服务器可能重定向，也必须视为 `BLOCKED`，因为在重定向前发送 form body/凭据的行为未验证。
- `CODE_EVIDENCE`：`WEB_TIEBA_API` 与 `HYBRID_TIEBA_API` 使用 `https://tieba.baidu.com/`，但可能带 Web Cookie。
- JSON 公共错误别名来自 `FailureResponseInterceptor`：`error_code/errno/no` 与 `error_msg/errmsg/error`。

### 认证等级

本文只使用以下值：

- `required-by-client`：源码有 `ForceLogin` 或强制 token 参数。
- `optional-in-request`：无本地 ForceLogin，但 request builder 会在账户存在时附凭据。
- `not-sent-by-client`：源码明确去掉凭据；仍不等于服务端匿名行为已验证。
- `unknown`：静态源码不足。

`optional-in-request` 只描述客户端静态构造，不自动证明匿名能力；匿名状态以各
endpoint 的独立运行证据为准。当前只有下文 FRS 固定公开吧首屏/
一页下一页和 PBPage
匿名首屏/一页下一页得到限定运行验证。

## 阶段 12 登录与 authenticated Probe 证据

- `CODE_EVIDENCE`：锁定 Android
  `LoginPage.kt::LOGIN_URL/LoginWebViewClient.onPageFinished` 使用可见 WebView，
  初始页为 `wappass.baidu.com/passport`，回跳到
  `tieba.baidu.com/index/tbwise/mine`；只有 tieba/tiebac 的
  `/index/tbwise/` 完成页才读取 Cookie，并要求非空 BDUSS 与 STOKEN。
- `CODE_EVIDENCE`：Android V12 CommonRequest 和 multipart helper 都会在
  active account 时发送 BDUSS/STOKEN，其中外层字段是 stoken。Android builder
  隐式读取全局账户的实现没有移植；iOS 由 matching ProtectedDataLease 显式
  授权。
- `RUNTIME_OBSERVATION`：2026-08-04，用户手工完成可见网页登录；本机签名
  iPhone Simulator 构建进入 `signedIn`，进程重启后从 Keychain 恢复
  `signedIn`。随后一次 active Personalized 请求得到 HTTP 200、
  `application/octet-stream`、83924 bytes、Proto decode 成功、12 mapped
  items、`outcome=success`。
- 隐私边界：没有记录 Cookie 值、账号、密码、验证码、完整 URL/query、请求体、
  raw response、帖子/用户内容或设备标识；自动化继续使用 FakeSession 和
  Mock/Fixture，不读取真实 Keychain 或 live 网络。
- `UNKNOWN`：两个字段是否是所有账号/风控场景的最小集合、服务端是否实际
  消费了它们、Cookie host-only 与 Domain 精确语义、rotation、真实失效码、
  authenticated/anonymous 差异、rate limit、PBPage 与关注吧能力。
- 历史结论（阶段 12）：`ACTIVE_SESSION_PERSONALIZED_RUNTIME_OBSERVATION`；当时
  不解除 Production fail closed。
- 阶段 15.5 当前结论：
  `ACTIVE_SESSION_FIRST_PAGE_RUNTIME_VERIFIED`。Production 使用同一 active
  Repository 路径并实际显示 12 项；没有 tracked live fixture，匿名稳定性、
  分页、字段最小性与服务端是否消费 credential 仍为 `UNKNOWN`。
- 阶段 15.6 当前结论：
  `ACTIVE_SESSION_SECOND_PAGE_RUNTIME_VERIFIED`。第二页
  `load_type=2,pn=2`成功并有 12 个新稳定 ID；匿名稳定性、第三页+
  live 与服务 terminal 仍为 `UNKNOWN`。

### 安全与 fixture 规则

- fixture 必须删除 Cookie、BDUSS、STOKEN、授权头、手机号、私密内容和可追踪设备标识。
- 二进制 fixture 同时保存脱敏来源记录、SHA-256 和预期 mapper 输出；不得保存真实请求 header。
- 成功、空、畸形、超时、取消、未登录、会话失效是所有 P0 endpoint 的最小集合。
- Personalized 已有构造的跨语言 fixture；其余路径仍是后续目标，不能把
  synthetic/cross-language fixture 标成 live capture。

## 阶段 08 首楼正文 wire 证据（非 endpoint 响应）

- 用户任务：确定性解码和只读渲染首楼正文节点。
- Android 消费路径：
  `ThreadViewModel.kt::threadInfo.firstPostContent.renders`。
- Root/message path：
  `tieba.ThreadInfo.firstPostContent#142[] → tieba.PbContent.type#1`；只读投票为
  `ThreadInfo.poll_info#74 → PollInfo.options#9[] → PollOption`。
- raw dispatcher：
  `Extensions.kt::List<PbContent>.renders`；`type#1` 是 `int32`，不是 enum。
- iOS adapter：
  `Sources/Core/TiebaAPI/ThreadContentProtoMapper.swift`；输出
  `ThreadContentDocument`，严格保序且 unknown/malformed 按节点降级。
- Fixture：
  `TestSupport/Fixtures/API/ThreadContent/thread_content_cross_language.pb`，
  1535 bytes，SHA-256
  `d37a7486974718d660a4b43466d914156c66d36f3f83982507915575e68cdf12`。
- 生成和交叉验证：Java 21.0.10 + protobuf-java 4.35.1
  `DynamicMessage` 两次生成，tracked bytes 与独立
  `protoc --encode=tieba.ThreadInfo` 逐字节一致。
- 证据等级：`CROSS_LANGUAGE_GENERATED`；内容全部人工合成、脱敏。
- 不证明：PB Page wrapper、`Post.content#5`、普通楼层折叠/
  屏蔽、服务端 raw 分布、媒体可达性、账号或分页行为。

## P0 endpoint

### `recommendations.personalized`

- 用户任务：浏览、刷新和分页推荐主题。
- HTTP method / URL family：POST `https://tiebac.baidu.com/c/f/excellent/personalized?cmd=309264`。
- Android 来源文件：`api/retrofit/interfaces/OfficialProtobufTiebaApi.kt`；`api/interfaces/impls/MixedTiebaApiImpl.kt`；`repository/PersonalizedRepository.kt`。
- Android symbol：`personalizedFlow`、`personalizedProtoFlow`、`PersonalizedRepository.personalizedFlow`。
- 请求构建来源：`ProtobufRequest.buildProtobufRequestBody`、`buildCommonRequest(ClientVersion.TIEBA_V12)`。
- 认证要求：`optional-in-request`；无 ForceLogin。CODE_EVIDENCE：
  ExplorePage.kt::ExplorePage 未登录时仍把 Personalized 设为首个页面，
  PersonalizedPage.kt::PersonalizedPage 首次 lazy load 发送 Refresh，因此
  Android 客户端会尝试匿名调用；服务端是否接受匿名仍为 `UNKNOWN`。
- 请求编码：multipart/form-data，binary protobuf `data`；外层可带 stoken。
- 请求 Protobuf：`PersonalizedRequest` / `PersonalizedRequestData`，定义于 `app/src/main/protos/Personalized.proto`。
- 响应 Protobuf/DTO：`PersonalizedResponse`；`thread_list`、`thread_personalized`。
- 分页字段：请求 `load_type`、`pn`、`page_thread_count=11`；响应没有已证终止字段。
- iOS 阶段 07 request evidence：只编码 call-site 已证静态字段
  `load_type/pn/page_thread_count=11/q_type=1/new_net_type=1`；零值字段显式
  赋值但按 proto3 不出现在 wire。没有猜测 CommonRequest、AppPos、屏幕、
  设备或 session；该阶段请求未对服务端发送。阶段 11 根据 Android
  `buildCommonRequest(TIEBA_V12)` 和受控 Probe 增加非敏感静态字段：
  `client_type=2`、`client_version=12.52.1.0`、`from=1020031h`、固定 V12
  User-Agent 与 `personalized_rec_switch=1`。匿名路径不发送任何 session 字段。
  阶段 12 active Debug Probe 只额外写入 CommonRequest BDUSS/STOKEN 和外层
  multipart stoken。两条路径都不发送 CUID、Android ID、AppPos、安装时间、
  完整 Cookie header 或其他 Android telemetry。
- multipart evidence：固定 Android boundary
  `--------7da3d81520810*`，binary part 为 `name=data`、`filename=file`、无
  part Content-Type；外层 endpoint header 是 `x_bd_data_type: protobuf`。
- 服务端错误字段：`Error.error_code/error_msg/user_msg`。
- 关键 headers：`x_bd_data_type: protobuf`、`client_type=2`、
  `Charset=UTF-8` 与 V12 User-Agent。
- 设备/版本参数：CommonRequest、AppPosInfo、screen、client version；最小集合 `UNKNOWN`。
- 敏感字段：可选 BDUSS/STOKEN、client/device identifiers；fixture 必须移除。
- iOS domain mapper：`PersonalizedResponse → RecommendationPage(items, nextPageCandidate, terminalUnknown)`；已实现白名单 mapper，保留 raw `id/threadId`、服务器顺序、raw `threadTypes=999` 与 message presence。`CODE_EVIDENCE`：Android
  `PersonalizedPage` 点击项时以 `ThreadInfo.id` 打开帖子，因此 local Live adapter
  只把 raw `id` 用作 route ID；这不证明服务端 canonical/stability 语义，也不
  执行直播/视频过滤。
- Fixture 路径：
  `TestSupport/Fixtures/API/Recommendations/personalized_cross_language.pb`；
  SHA-256
  `54a838f8bd05c39e90b84b3bba4d4224dc81fe11b63934e23dd65be937eebb4a`。
- Fixture 类型：`CROSS_LANGUAGE_GENERATED`；Java 21.0.10 +
  protobuf-java 4.35.1 `DynamicMessage` 从固定 51-file Personalized
  descriptor closure
  生成，来源见相邻 `PROVENANCE.md`。
- 已验证行为：Android 静态调用链和 request 字段；request protobuf golden、
  Android multipart boundary/data/file 形态、optional default presence、未知
  field round-trip、empty/missing data、service error、malformed/empty body、
  raw integer 保留与 JVM→Swift mapper；Live Repository 的 evidence-locked
  candidate request、transport/HTTP/MIME/decode/map 与 Fixture/Production
  显式选择由 mock tests 验证。Debug Probe 观察到一次匿名非空和多次匿名合法
  空页；阶段 12 与阶段 15.5 分别观察到 active Session 的 12-item 成功页，且
  阶段 15.5 的 Production 页面实际显示 12 项。阶段 15.6 进一步在
  同一 active-session 路径验证 `load_type=2,pn=2`：HTTP 200、
  `application/octet-stream`、72958 bytes、decode=true、mapped=12，且
  较首屏新增 12 个稳定 `ThreadInfo.id`。Fixture/Store 连续覆盖三页、
  跨页 first-wins、下一页保留失败/重试与 refresh generation 隔离。
- UNKNOWN：稳定匿名能力、服务端终止条件、空页/duplicate-only 页的服务语义、
  第三页及更后 live 稳定性、广告/直播节点、限流与错误码。当前停止
  空页/无新 ID 只是 client policy，不声称服务端 `hasMore`。

### `followedForums.forumGuide`

- 用户任务：登录后读取全部关注吧。
- 状态：`ACTIVE_LEASE_HTTPS_PROTO_RUNTIME_VERIFIED`；Android Home 权威 legacy
  明文路径继续 `BLOCKED_INSECURE_HTTP`。
- `CODE_EVIDENCE`：当前 Android Home 使用 POST
  `http://c.tieba.baidu.com/c/f/forum/forumGuide`，form + ForceLogin，并从
  `page_no=1`、`res_num=50` 聚合到 `like_forum_has_more=false`。该路径不得进入
  iOS。
- `CODE_EVIDENCE`：相同 pinned commit 定义 POST
  `https://tiebac.baidu.com/c/f/forum/forumGuide?cmd=309683&format=protobuf`，
  request/response 为 `ForumGuideRequest/ForumGuideResponse`；Android 当前没有
  UI 或 Repository caller。iOS 阶段 15.5 已在受保护 lease 下通过同一候选的
  Production Repository 与页面运行验证。
- 请求 data：`sort_type#2=2`、`call_from#3=0`；认证位于 outer multipart 的
  `BDUSS`/`stoken` 与当前 lease。`CODE_EVIDENCE`：Android 实际 Retrofit
  链还通过 V11 common-parameter 和 sort/sign interceptor；最终 outer fields
  包含非敏感 common params 与大写 MD5 sign。iOS 刻意只实验
  BDUSS/STOKEN-only、unsigned subset，属于
  阶段 13 时属于 `INFERENCE/RUNTIME_UNVERIFIED`；阶段 15.5 已证明该最小候选
  能在当前会话得到并映射成功响应，但不声称与 Android final wire 精确一致，
  也不证明字段最小性。device/common/sign 必要性仍为 `UNKNOWN`，iOS 不复制
  device telemetry。
- 响应 `data.like_forum#2`：`forum_id`、`forum_name`、`avatar`、hot/member/thread
  counts、`level_id/name`、`is_sign`；无分页字段。Android 接口注释声明最多 200。
- 错误：`Error.error_code != 0` 只形成 generic server error；`is_login` 无消费点，
  没有已证 session-expired server code。
- iOS Proto closure：两个 root 共 58 个输入；复用当前 48 个，新增 10 个锁定输入，
  union 为 136。现有 `tieba.LikeForumInfo` wire 不兼容，不得替代。
- Fixture 路径：`TestSupport/Fixtures/API/FollowedForums/`；只允许合成、脱敏数据。
- 历史 Runtime：2026-08-05 为
  `NOT_RUN_AUTH_CONTEXT_RESTORE_FAILED`；没有发请求，该观察不属于服务端失败。
- 阶段 15.5 Runtime：`ACTIVE_LEASE_PRODUCTION_RUNTIME_VERIFIED`。同一保留会话
  恢复 active lease；ForumGuide 为 HTTP 200、`application/octet-stream`、
  9199 bytes、Proto decode=true、mapped=18、typed outcome=success，Production
  页面实际显示列表。未执行 logout/卸载/清理/重新登录；未保存 body、Cookie、
  吧名或用户内容。
- `UNKNOWN`：服务端是否实际消费当前 lease 字段及最小 auth subset、sign/device
  参数必要性、空列表、真实 expired/error taxonomy、超过 200 个关注吧的完整性，
  以及 Proto forum ID 与 Home identity 的长期等价性。

### `forum.frsPage`

- 用户任务：读取吧信息、主题首屏、刷新和后续页。
- HTTP method / URL family：POST `https://tiebac.baidu.com/c/f/frs/page?cmd=301001`。
- Android 来源文件：`OfficialProtobufTiebaApi.kt`、`MixedTiebaApiImpl.kt`、`FrsPageRepository.kt`、`ForumThreadListViewModel.kt`。
- Android symbol：`frsPageFlow`、`frsPage`、`FrsPageRepository.frsPage`。
- 请求构建来源：`FrsPageRequest` + multipart protobuf。
- 认证要求：iOS 选择 `.anonymous`；Android 无 ForceLogin 且会在无账户时
  调用。2026-08-05 固定公开吧首屏与 2026-08-09 顺序第二页的匿名
  服务器接受性已限定 `RUNTIME_VERIFIED`。
- 请求编码：multipart/form-data，固定 boundary
  `--------7da3d81520810*`，binary part `name=data`、`filename=file`、无 part
  MIME；另有 Java form-urlencoded 的 `forum_name` header。
- 请求 Protobuf：`FrsPageRequest/FrsPageRequestData`，`FrsPage/FrsPage.proto`。
- 响应 Protobuf/DTO：`FrsPageResponse/FrsPageResponseData`。
- 分页字段：`pn`、`load_type`、`Page.has_more`、`thread_id_list`；sort/cid/is_good 影响列表。
- 服务端错误字段：`Error`。
- 关键 headers：`x_bd_data_type=protobuf`、`client_type=2`、`Charset=UTF-8`、
  固定 V12 User-Agent 和 form-urlencoded `forum_name`；没有 `format=protobuf`
  query。
- iOS request data：首屏锁定 `pn=1/load_type=1`，顺序后续页使用
  `pn=N/load_type=2`；两者均使用 `q_type=2/rn=90/rn_need=30`、
  `sort_type=0/with_group=1/st_type=recom_flist`、Android call-site 的其余零值
  字段及 `ad_param(load=0,refresh=4,yoga=1.0)`；CommonRequest 只带已验证的
  非敏感 V12 client type/version/from/user-agent。没有复制 AppPos、屏幕尺寸、
  CUID、安装 ID、签名或 Android 设备 telemetry。
- 敏感字段：匿名实现不读取或发送 Session、Keychain、BDUSS、STOKEN、Cookie
  或 device identifiers。
- iOS domain mapper：`FrsPageResponse → ForumHomeSnapshot`。吧信息只映射已证
  字段；`ThreadInfo.threadId` 是 row/route 的稳定业务 identity，
  `ThreadInfo.id` 仅保留为 wire itemID；按 `threadID` first-wins 去重并保持
  首次出现顺序。`isTop == 1` 形成置顶 RowKind；`user_list` 关联失败
  降级，不抛整页。
- Fixture 路径：
  `TestSupport/Fixtures/API/ForumHome/frs_page_synthetic.pb`，454 bytes，SHA-256
  `940d1df7631795791eccde105a7cb4dcbf3f38d465a8ebf9bac6af4c850887b0`。
- Fixture 类型：`LOCAL_SYNTHETIC`，由固定 textproto + pinned schema 编码；包含
  2 个置顶、2 个普通主题、item/thread ID 分离、作者回填和缺失作者降级，
  不含真实吧、用户或帖子内容。
- Runtime：固定公开测试吧、无凭证 iPhone/iPad，HTTP 200、
  `application/octet-stream`、54068 bytes、decode=true、13 threads、
  outcome=success。最终 iPhone 复验响应为 55996 bytes，仍为
  decode=true、13 threads、typed-error=none、outcome=success；body 大小不作
  稳定产品契约。Production 因此使用唯一 `LiveForumHomeRepository`；
  UITesting 始终使用 Fixture + Mock HTTP。
  阶段 14P 第二页 Probe 为 HTTP 200、
  `application/octet-stream`、156269 bytes、decode=true；首屏 13 条追加
  30 条后聚合 43 条，`typed-error=none`、`outcome=success`。
- 已验证行为：Android 当前 call chain、确定性首屏/后续页 request、
  synthetic response mapper、`Page.has_more`、按 threadID 去重/保序、保留式
  next-page failure，匿名首屏/一页下一页 live transport/MIME/decode/map，
  以及 iPhone/iPad 基本视觉投影。
- UNKNOWN：动态 tab 类型、跨吧稳定性、`thread_id_list` 语义、ThreadList
  顺序/遗漏/空响应、第三页及更后页的 live 运行、所有 sort 值、
  限流和 FRS 专属错误 taxonomy。

### `forum.threadList`

- 用户任务：按 FRS 返回的 thread id 批量补取主题。
- HTTP method / URL family：POST `https://tiebac.baidu.com/c/f/frs/threadlist?cmd=301002`。
- Android 来源文件：`OfficialProtobufTiebaApi.kt`、`MixedTiebaApiImpl.kt`、`FrsPageRepository.kt`。
- Android symbol：`threadListFlow`、`threadList`、`FrsPageRepository.threadList`。
- 请求构建来源：`ThreadListRequest` multipart protobuf。
- 认证要求：`optional-in-request`。
- 请求编码：multipart/form-data + protobuf。
- 请求 Protobuf：`ThreadListRequest/ThreadListRequestData`，位于 `app/src/main/protos/ThreadList/`。
- 响应 Protobuf/DTO：`ThreadListResponse`。
- 分页字段：客户端一次最多取 30 个 id；响应无 Page，Android 以非空列表推断 hasMore。
- 服务端错误字段：`Error`。
- 关键 headers / 设备参数：同 protobuf family。
- 敏感字段：可选 session/device fields。
- iOS domain mapper：复用 `ForumThreadSummary`；按请求 id/服务端顺序的关系必须保留 raw evidence。
- Fixture 路径：`TestSupport/Fixtures/API/Forum/ThreadList/`（`NOT_CREATED`）。
- Fixture 获取/生成方式：与同一次 FRS fixture 配对采集；构造缺项、乱序、重复、空响应。
- 已验证行为：Android 每批最多 30 个 id。
- UNKNOWN：服务端是否保请求顺序、遗漏 id 含义、空响应是否终止、与下一 FRS page 的边界。

### `forum.generalTabList`

- 用户任务：浏览服务端定义的吧内 general tab。
- HTTP method / URL family：POST `https://tiebac.baidu.com/c/f/frs/generalTabList?cmd=309622&format=protobuf`。
- Android 来源文件：`OfficialProtobufTiebaApi.kt`、`MixedTiebaApiImpl.kt`、`GeneralTabListRepository.kt`。
- Android symbol：`generalTabListFlow`、`generalTabList`。
- 请求构建来源：`GeneralTabListRequest` multipart protobuf。
- 认证要求：`optional-in-request`。
- 请求编码：multipart/form-data + protobuf。
- 请求 Protobuf：`GeneralTabListRequest/Data`，`app/src/main/protos/GeneralTabList/`。
- 响应 Protobuf/DTO：`GeneralTabListResponse/Data`。
- 分页字段：`pn`、`rn=30`、`last_thread_id`、响应 `has_more`。
- 服务端错误字段：`Error`。
- 关键 headers / 设备参数：同 V12 protobuf family。
- 敏感字段：可选 session/device fields。
- iOS domain mapper：`GeneralTabListResponse → ForumThreadPage`；tab identity 使用 server tab id，不使用 index。
- Fixture 路径：`TestSupport/Fixtures/API/Forum/GeneralTab/`（`NOT_CREATED`）。
- Fixture 获取/生成方式：先由 FRS fixture 提供真实 tab，再成对采集；构造未知 tab_type、重复 last_thread_id。
- 已验证行为：Android production UI 使用该 endpoint。
- UNKNOWN：tab_type/is_general_tab/is_default 的业务语义、last_thread_id 与 pn 冲突时的优先级。

### `thread.pbPage`

- 用户任务：读取帖子、首楼、楼层、锚点和前后分页。
- HTTP method / URL family：POST `https://tiebac.baidu.com/c/f/pb/page?cmd=302001&format=protobuf`。
- Android 来源文件：`OfficialProtobufTiebaApi.kt`、`MixedTiebaApiImpl.kt`、`PbPageRepository.kt`、`ThreadViewModel.kt`。
- Android symbol：`pbPageFlow`、`PbPageRepository.pbPage`、`ThreadUiIntent.Load*`。
- 请求构建来源：`PbPageRequest/PbPageRequestData` + multipart protobuf。
- 认证要求：`optional-in-request`。
- 请求编码：multipart/form-data + protobuf。
- 请求 Protobuf：`PbPageRequest` / `PbPageRequestData`。
- 响应 Protobuf/DTO：`PbPageResponse` / `PbPageResponseData`。
- 分页/锚定字段：`pn/pid/back/last_pid`；排序 caller 写入 `r=sortType`。`floor_sort_type` 在当前 builder 恒为 1，语义 `UNKNOWN`，不能把它命名为已证排序字段。响应含 `current_page/new_total_page/has_more/has_prev`；下一 pid 还由 `ThreadInfo.pids` 推导。
- 服务端错误字段：`Error`。
- 关键 headers：V12 protobuf headers。
- 设备/版本参数：Android CommonRequest、AppPos、screen；最小集合
  `UNKNOWN`。iOS local adapter 只编码 `client_type=2`、
  `client_version=12.52.1.0`、`from=1020031h`、固定 User-Agent、
  `personalized_rec_switch=1` 和 call-site 静态 PBPage 字段，不编码 AppPos、
  screen、设备或 session。
- 敏感字段：可选 BDUSS/STOKEN 与 device fields。
- iOS domain mapper：阶段 15 的 `PBPageProtocol` 把公开标题、吧名、作者、
  首楼、普通楼层、`Post.content#5`、`Post.sub_post_list#15` 与 Page 字段转为
  `ThreadReaderSnapshot` / `ThreadContentDocument`。Post/SubPost 使用真实稳定
  ID；缺作者降级，未知节点保留 raw type，折叠只消费 `is_fold/fold_tip`，
  图片候选生成稳定 MediaIntent。
- Fixture 路径：`FixtureThreadReaderPages` 与
  `Tests/Stage15ThreadReadingTests.swift` 的完全合成、脱敏 Swift Proto response；
  阶段 15.6 连续五页覆盖首楼、普通楼层、内联楼中楼、图片、未知节点、
  折叠楼层、跨页重叠 postID、畸形/累计 pids、终止页和下一页失败。
  聚合为 77 个唯一楼层；独立 5×200 的 1000 楼虚拟化 fixture 保持不变。
  它们不是 live capture 或
  cross-language fixture。
- Fixture 获取/生成方式：只由测试代码与稳定业务 ID 构造；不保存服务端
  response。倒序、只看楼主、跳楼与完整 PBFloor 继续 `NOT_CREATED`。
- 已验证行为：Android 当前完整 Thread UI 使用 Proto 链；阶段 11 锁定
  PBPage closure；阶段 15/15.6 覆盖任意顺序 `pn/pid`、精确
  `current_page`、每页 `has_more`、累计 cursor 排除与已证 `pid=0`
  fallback、后续页无首楼、楼中楼/时间、非法单楼降级、分页去重保序、
  retained failure/重试、防重复、no-progress、取消与 route 离开回归。
  阶段 15.6 当时的 Proto 闭包为 156 文件；阶段 16B Profile 扩展后当前
  联合闭包为 207 文件。
- 运行态：`ANONYMOUS_THREE_PAGE_RUNTIME_VERIFIED`。2026-08-09 Debug-only
  Probe 从公开 FRS 选择长帖；PBPage 连续三页均 HTTP 200、
  `application/octet-stream`，为 24893/16779/13805 bytes，Proto decode 成功，
  `current_page=1/2/3`，分别映射 17/15/15 楼，累计 45 个唯一 postID。
  三页 `has_more=1`；首屏固定 `pid=0`，后续两页以 Android 已证
  fallback `pid=0` 继续。没有保存响应正文、Proto dump、
  threadID/postID 值、标题或用户内容。
- UNKNOWN：合法空页、删除/私密的完整语义、`is_post_visible` proto3 零值、
  sort 值域、倒序/跳楼/PBFloor、真实错误 taxonomy、限流与跨主题稳定性。
  Production 图片 loader 仍 disabled，Live 图片不是本次运行证据。

### `thread.pbFloor`

- 用户任务：读取某楼的完整楼中楼及分页。
- HTTP method / URL family：POST `https://tiebac.baidu.com/c/f/pb/floor?cmd=302002&format=protobuf`。
- Android 来源文件：`OfficialProtobufTiebaApi.kt`、`MixedTiebaApiImpl.kt`、`SubPostsViewModel.kt`。
- Android symbol：`pbFloorFlow`、`SubPostsUiIntent.Load/LoadMore`。
- 请求构建来源：`PbFloorRequest/PbFloorRequestData`。
- 认证要求：外层 `needSToken=false`，但 CommonRequest 在有账号时仍可能带 session；归类 `optional-in-request`。
- 请求编码：multipart/form-data + protobuf。
- 请求 Protobuf：`PbFloorRequest/Data`。
- 响应 Protobuf/DTO：`PbFloorResponse/Data`。
- 分页字段：请求 page；Android 用 `current_page < total_page` 判断 hasMore，而非 `Page.has_more`。
- 服务端错误字段：`Error`。
- 关键 headers / 设备参数：同 V12 protobuf family。
- 敏感字段：可选 CommonRequest session/device fields。
- iOS domain mapper：`SubpostPage`，按 subpost id 去重、保序；空/未知内容节点必须有效。
- Fixture 路径：`TestSupport/Fixtures/API/Thread/PBFloor/`（`NOT_CREATED`）。
- Fixture 获取/生成方式：正常、空、重叠页、缺作者、仅未知节点、页字段冲突。
- 已验证行为：Android UI production call chain 和 page 比较逻辑。
- UNKNOWN：外层无 token 时服务器是否匿名、Page 字段冲突优先级、subPostId 锚定语义。

### `media.picPage`

- 用户任务：从当前图片向前/后扩展帖子图片集合。
- HTTP method / URL family：POST `http://c.tieba.baidu.com/c/f/pb/picpage`；`BLOCKED`。
- Android 来源文件：`MiniTiebaApi.kt`、`MixedTiebaApiImpl.kt`、`PhotoViewViewModel.kt`。
- Android symbol：`picPageFlow`、`PhotoViewUiIntent.LoadPrev/LoadMore`。
- 请求构建来源：Retrofit form + MINI common interceptors。
- 认证要求：可选 `user_id`，其他 common 字段可能存在；服务端匿名行为 `UNKNOWN`。
- 请求编码：form-urlencoded。
- 请求 Protobuf：无。
- 响应 Protobuf/DTO：`PicPageBean` JSON。
- 分页字段：`pic_id/pic_index`；向前 `prev=10,next=0`，向后相反；客户端比较 `overall_index` 与 `pic_amount`。
- 服务端错误字段：`error_code`；错误消息形态 `UNKNOWN`。
- 关键 headers / 设备参数：MINI Android client、screen/q_type。
- 敏感字段：可选 uid/device id；图片 URL 也可能关联私密内容。
- iOS domain mapper：`MediaPage(items, total, hasPrevious, hasNext)`；所有数字字符串安全解析。
- Fixture 路径：`TestSupport/Fixtures/API/Media/PicPage/`（`NOT_CREATED`）。
- Fixture 获取/生成方式：在找到 HTTPS 等价路径后采集；P0 可先完全使用 PB 响应中的本地 media 列表 fixture。
- 已验证行为：Android MediaViewer 使用该 HTTP endpoint 扩边。
- UNKNOWN：安全 HTTPS endpoint、索引是否 1-based、blocked image、坏数字、空页、会话要求。

### `session.loginValidation`

- 用户任务：Web 登录完成后验证凭据并建立 session。
- HTTP method / URL family：POST `http://c.tieba.baidu.com/c/s/login`，另组合 initNickname；`BLOCKED`。
- Android 来源文件：`LoginPage.kt`、`AccountUtil.kt`、`OfficialTiebaApi.kt`、`MixedTiebaApiImpl.kt`。
- Android symbol：`LoginWebViewClient.onPageFinished`、`AccountUtil.fetchAccountFlow`、`loginFlow`。
- 请求构建来源：从 WebView Cookie 解析 BDUSS/STOKEN 后构造 form。
- 认证要求：`required-by-client`。
- 请求编码：form-urlencoded。
- 请求 Protobuf：无。
- 响应 Protobuf/DTO：`LoginBean`，含 user 与 anti/tbs；随后 GetUserInfo Proto 补 profile。
- 分页字段：无。
- 服务端错误字段：JSON common aliases；过期/验证码/风控分类 `UNKNOWN`。
- 关键 headers / 设备参数：legacy official headers/sign；不得复制到 iOS。
- 敏感字段：完整 Cookie、BDUSS、STOKEN、TBS、BAIDUID/ZID；绝不进入 fixture/log。
- iOS 实现边界：该明文 endpoint 没有 mapper，也没有注册到 EndpointPipeline；
  阶段 12 只把已证完成页中的两个候选字段交给 Keychain writer。
- Fixture 路径：只允许构造的脱敏 mapper fixture；真实认证响应默认不落盘。
- Fixture 获取/生成方式：先形成登录 ADR 与安全 HTTPS 方案；使用专用测试账号，只记录字段存在性/错误类别。
- 已验证行为：Android WebView 回跳和静态组合链；iOS 阶段 12 Beta 使用可见、
  first-party HTTPS WKWebView，只在已证完成页提取 BDUSS/STOKEN candidate。
  真实手工登录、Keychain 进程重启恢复及一次 authenticated Personalized Probe
  已成功；这不是 `session.loginValidation` endpoint 的运行证据。
- UNKNOWN：服务端 validation 的安全 HTTPS 等价路径、Cookie 轮换、二次验证、
  真实过期 taxonomy、重复回调常态、账号切换与 profile validation。

### `session.getUserInfo`

- 用户任务：验证 session 后读取公开账户资料。
- HTTP method / URL family：POST `https://tiebac.baidu.com/c/u/user/getuserinfo?cmd=303024&format=protobuf`。
- Android 来源文件：`OfficialProtobufTiebaApi.kt`、`MixedTiebaApiImpl.kt`、`AccountUtil.kt`。
- Android symbol：`getUserInfoFlow`、`AccountUtil.fetchAccountFlow`。
- 请求构建来源：GetUserInfo caller 把新账户 BDUSS/STOKEN 传给 V12 builder；但 V12 `buildCommonRequest` 忽略参数并读全局 `AccountUtil`，外层 stoken 同样来自全局账户。
- 认证要求：无 `ForceLogin`、参数为 nullable，实际 builder 在当前账户存在时附凭据；归为 `optional-in-request`，服务端是否必需认证及实际使用哪个 session 均 `UNKNOWN`。
- 请求编码：multipart/form-data + protobuf。
- 请求 Protobuf：`GetUserInfoRequest/Data`。
- 响应 Protobuf/DTO：`GetUserInfoResponse/Data`，使用 `user`。
- 分页字段：无。
- 服务端错误字段：`Error`。
- 关键 headers / 设备参数：V12 protobuf family。
- 敏感字段：session/device fields；响应也可能含不应持久化的 User 字段。
- iOS domain mapper：只选产品需要的公开 profile 字段；忽略 `User` 中的凭据/密码形字段。
- Fixture 路径：`TestSupport/Fixtures/API/Session/GetUserInfo/`（`NOT_CREATED`，必须深度脱敏）。
- Fixture 获取/生成方式：构造最小响应优先；真实样本需字段白名单脱敏。
- 已验证行为：Android login 组合链会调用该方法，失败会保留基础 account；不能由静态源码证明它用新登录账户成功请求。
- UNKNOWN：最小认证字段、全局账户为空/为旧账户时的实际服务端结果、资料隐私边界、session 失效码、字段稳定性。

## P1 endpoint

### `user.profile`

- 用户任务：从帖子作者打开基础公开用户资料。
- HTTP method / URL family：POST
  `https://tiebac.baidu.com/c/u/user/profile?cmd=303012&format=protobuf`。
- Android 来源文件：`MixedTiebaApiImpl.kt`、`OfficialProtobufTiebaApi.kt`、
  `UserProfileViewModel.kt`、`Profile/*.proto` 和 `User.proto`。
- Android symbol：`userProfileFlow(uid)` → V12 `profileFlow(body)`。
- 请求构建来源：`ProfileRequest(ProfileRequestData(...))` + V12 multipart
  protobuf。他人资料已证字段为 `friend_uid`、`friend_uid_portrait=""`、
  `has_plist=1`、`is_from_usercenter=1`、`is_guest=1`、
  `need_post_count=1`、`page=1`、`pn=1`、`q_type=0`、`rn=20`。
- 认证要求：iOS 本阶段 descriptor 为 `anonymous`，CommonRequest 只含
  锁定的非敏感 client/version/from/user-agent/personalized switch，不传
  BDUSS/STOKEN/uid。Android 的 self-profile 路径不在本阶段。
- 请求编码：`multipart/form-data` binary `data` part；确定性 protobuf。
- 请求/响应 Protobuf：`ProfileRequest/ProfileRequestData`；
  `ProfileResponse/ProfileResponseData` + `User` + `Error`。
- 分页字段：请求含 `page/pn/rn`，但阶段 16B 仅消费基础资料，
  不实现用户帖子/动态列表或分页。
- 服务端错误字段：公共 `Error.error_code`；完整 taxonomy `UNKNOWN`。
- 关键 headers / 设备参数：V12 protobuf family。Android 传 `scr_w/scr_h/
  scr_dip`；iOS 不猜测屏幕/设备值，保持 proto 零值。
- 敏感字段：`User` schema 含 `BDUSS`、`passwd`、IP 类字段。它们
  被 mapper 白名单边界显式排除，不进入领域、fixture、日志或 UI。
- iOS domain mapper：response `User.id` 必须匹配请求 route；只映射
  `nameShow/name`、portrait、intro、sex、concern/fans/post/thread/
  total-agree counts 和公开 `tieba_uid`。`tieba_uid` 仅作内部映射字段，
  Profile UI 不展示任何用户 ID；空 portrait 回退 route 候选值。
- Fixture 路径：`TestSupport/Fixtures/API/UserProfile/profile_synthetic.pb`；
  `SYNTHETIC_PROTOBUF`，manifest SHA-256
  `64dd17342c4e6f488c57b505e27b8966856716f03e6a5fec876798525562097f`。
- Fixture 获取/生成：`scripts/generate_profile_fixture.sh` 从人工合成
  textproto 生成，不是 live capture；生成前后不读真实会话。
- 已验证行为：精确 endpoint/query/request 静态快照，无 credential，
  成功 mapper、identity mismatch、empty、Mock Live Repository、cancel/stale
  及 Fixture UI route。generated closure 为 207 文件并两次 clean 确定性一致。
- 运行证据：2026-08-30 iOS 26.5 Simulator Debug-only anonymous
  Probe：HTTP 200、`application/octet-stream`、4475 bytes、decode=true、
  display fields=11、typed error=none。
- UNKNOWN：anonymous 长期接受性、屏幕字段必要性、self-profile、
  删除/私密用户、完整错误 taxonomy、字段长期稳定性和头像加载。

### `feed.userLike`

- 用户任务：关注动态。
- HTTP method / URL family：POST `https://tiebac.baidu.com/c/f/concern/userlike?cmd=309474`。
- Android 来源文件：`ConcernViewModel.kt`、`MixedTiebaApiImpl.kt`、`OfficialProtobufTiebaApi.kt`、`UserLike/UserLike.proto`。
- Android symbol：`ConcernUiIntent` → `MixedTiebaApiImpl.userLikeFlow` → `OfficialProtobufTiebaApi.userLikeFlow`。
- 请求构建来源：`UserLikeRequest/Data` + 公共 multipart protobuf family。
- 认证要求：`optional-in-request`；产品语义似乎需登录，但服务端规则 `UNKNOWN`。
- 请求编码：multipart/form-data + protobuf。
- 请求/响应 Protobuf：`UserLikeRequest/Response`；响应 `Error + UserLikeResponseData`。
- 分页字段：`pageTag/lastRequestUnix/loadType`；响应 `hasMore/pageTag/requestUnix`。
- 服务端错误字段：公共 `Error`。
- 关键 headers / 设备参数：V11 protobuf family + `CommonRequest`；最小合法集合 `UNKNOWN`。
- 敏感字段：可选 session/device fields；response 可能含用户与关注动态内容，fixture 必须脱敏。
- iOS domain mapper：若未来排期，`ConcernData → FollowedActivityItem`，未知 `recommendType` 必须降级。
- Fixture 路径：`TestSupport/Fixtures/API/Concern/`（`NOT_CREATED`）。
- Fixture 获取/生成方式：先构造分页/未知 recommendType；真实样本只用专用账号并删除 session、用户私密内容。
- 已验证行为：Android 生产 ViewModel 有调用链；不代表本功能已进入批准 P1。
- UNKNOWN：recommendType 值域、requestUnix 生命周期、匿名/过期行为、服务端顺序。

### `search.suggestions`

- 用户任务：关键词联想。
- HTTP method / URL family：POST `https://tiebac.baidu.com/c/s/searchSug?cmd=309438&format=protobuf`。
- Android 来源文件：`SearchViewModel.kt`、`MixedTiebaApiImpl.kt`、`OfficialProtobufTiebaApi.kt`、`SearchSug/*.proto`。
- Android symbol：`SearchUiIntent.KeywordInputChanged` → `searchSuggestionsFlow` → `searchSugFlow`。
- 请求构建来源：`SearchSugRequest/Data(word,isforum)` + V12 multipart protobuf。
- 认证要求：`optional-in-request`；V12 CommonRequest 与外层 multipart 均可能读取当前全局 session。
- 请求编码：multipart/form-data + protobuf。
- 请求/响应 Protobuf：`SearchSugRequest/Response`；响应 `Error + SearchSugResponseData`。
- 分页字段：无。
- 服务端错误字段：公共 `Error`。
- 关键 headers / 设备参数：V12 protobuf family + `CommonRequest`；最小集合 `UNKNOWN`。
- 敏感字段：查询词、可选 session/device fields；fixture 不保存可识别用户查询历史。
- iOS domain mapper：P1 只映射经批准的 suggestion 字符串/吧摘要；Android 当前主路径只取 `data.list`。
- Fixture 路径：`TestSupport/Fixtures/API/Search/Suggestions/`（`NOT_CREATED`）。
- Fixture 获取/生成方式：构造空/重复/超长/敏感词与反向延迟响应；真实样本需查询白名单和脱敏。
- 已验证行为：Android Search ViewModel 有静态调用链。
- UNKNOWN：匿名能力、排序、空/敏感建议、输入规范化、错误 taxonomy。

### `search.webResults`

- 用户任务：阶段 16A 只接入搜吧和搜主题；用户、吧内帖子和联想延期。
- HTTP method / URL family：
  - forum：GET `https://tieba.baidu.com/mo/q/search/forum?word=...`；
  - thread：GET `https://tieba.baidu.com/mo/q/search/thread`，query 为
    `word,pn,st=5,tt=1,ct=1,is_use_zonghe=1,cv=99.9.101`。
- Android 来源文件：`AppHybridTiebaApi.kt`、`SearchForumBean.kt`、
  `SearchThreadBean.kt`、`ForumFuzzyMatchAdapter.kt`、
  `ExactMatchAdapter.kt`、`SearchForumViewModel.kt`、
  `SearchThreadViewModel.kt`。
- Android symbol：`searchForumFlow` 和 `searchThreadFlow`；thread
  `LoadMore` 以 `pn + 1` 请求且在 `has_more == 1` 时继续。
- 认证要求：阶段 16A Debug-only Probe 已证匿名三次请求
  HTTP 200/解码成功。iOS descriptor 固定 `anonymous`，不读
  Session/Keychain，不发 Cookie/BDUSS/STOKEN。Android 可选 Web Cookie
  路径不是匿名成功的必要条件。
- 请求编码：HTTPS GET query，无 body；response 为
  `application/json`。不放宽 TLS、redirect 或全 MIME。
- 请求/响应类型：无 Protobuf；本阶段仅
  `SearchForumBean` / `SearchThreadBean` 对应的 Swift JSON DTO。
- 分页字段：thread 请求 `pn` 从 1 起，响应必须精确
  `current_page` 且 `has_more == 1` 才继续。forum response 有
  `pn/has_more`，但 Android Forum ViewModel 没有下一页调用，因此
  iOS 只做首屏。
- 服务端错误字段：已观察两类响应的顶层 `no/error`；
  非零 `no` 映射为 typed wire server error。完整 taxonomy 仍未知。
- 关键 headers：iOS 仅发锁定 Hybrid 证据的固定
  `User-Agent`、`Accept-Language`、no-cache 和
  `X-Requested-With`。匿名 Probe 无 Referer 成功；
  `NO_ST_PARAMS/NO_COMMON_PARAMS` 是 Android 内部控制 header，
  iOS 不发它们。
- 敏感字段：查询词和搜索结果内容。Probe 只保留 status、
  MIME、body size、decode、count 和 typed error；不保留查询词、
  请求/响应原文、ID 值或结果内容。
- iOS domain mapper：forum 以正 `forum_id`，thread 将 `tid`
  安全解析为正 Int64；first-wins 去重保序。实际 forum
  `concern_num` 有 string/integer 混合，根据 Android
  `getNonNullString` 仅对 `post_num/concern_num` 做相同窄化投影。
  Android `SearchThreadBean.ThreadInfoBean` 将 `post_num/forum_id`
  声明为 String，而当前 Live 样本为 number；iOS 仅对这两个整数业务字段
  接受 numeric string 或 integer，并由合成 mixed-type 回归锁定。
- Fixture 路径：`TestSupport/Fixtures/API/Search/`；三个
  `SYNTHETIC_JSON` 且 manifest hash 锁定，不含真实响应或查询历史。
- 运行证据：forum 200/`application/json`/36555 bytes/
  decode=true/mapped=48；thread page 1 为 200/59907 bytes/
  decode=true/mapped=20；page 2 为 200/66555 bytes/
  decode=true/mapped=20/new=20。
- UNKNOWN：endpoint 长期稳定性、forum 分页、thread page 3+、
  rate limit、完整错误 taxonomy、固定 header/query 最小集、用户/
  吧内帖子搜索和 SearchSug 匿名能力。

## Alternate / legacy 记录

`CODE_EVIDENCE`：

- 推荐仍有 Mini/Official JSON 方法，但当前 `PersonalizedRepository` 使用 Proto。
- FRS/PB/PBFloor 仍有旧 JSON 方法；完整 Forum/Thread UI 使用 Proto。`QuickPreviewUtil` 的旧 JSON callback symbol 未发现外部 call site，当前 clipboard preview 使用 Proto Flow。
- `forumGuideNewFlow` 的 Proto endpoint 已定义，但当前 Home 使用 HTTP form；不能因“更现代”而擅自切换。
- Search 旧 Web/Mini 方法仍在接口，当前 Flow ViewModel 使用 Hybrid。

任何实现阶段的 endpoint 选择都必须重新搜索 call site，并在更换 endpoint 时补一份脱敏 fixture 和 mapper test。

## 接入门槛

真实 endpoint 只有同时满足以下条件才能从 `STATIC_EVIDENCE_ONLY` 升级：

1. HTTPS；不关闭 TLS 验证。
2. 认证和最小参数有脱敏 `RUNTIME_EVIDENCE`。
3. 成功/空/畸形/超时/取消/未登录/过期 fixture 齐全。
4. 生成 DTO 只进入 mapper，UI 不导入 Proto。
5. 请求日志默认脱敏，测试附件不含 session/device secret。
6. 分页终止、去重、过期响应和错误状态有确定性测试。
7. 来源和许可证记录与 `Docs/Audits/SOURCE_AND_LICENSE_NOTES.md` 一致。

`forum.frsPage` 按 ADR-0016 使用范围受限的开源 Beta 例外：
它只在精确 HTTPS/MIME/请求形状、合成成功 fixture、request/mapper/
cancel/stale 测试和无凭证运行成功后启用匿名首屏。阶段 14P
另以 `pn=2/load_type=2` 运行成功、去重/保序/保留失败测试
解除一页顺序下一页。第三页及更后页的 live 证据、完整错误矩阵、
`thread_id_list + ThreadList` 均未验证，不能用该例外启用其他 endpoint。

`thread.pbPage` 按 superseding `ADR-0019-core-live-pagination-beta.md` 使用
另一个独立、
范围受限的开源 Beta 例外：启用普通升序匿名 PBPage 顺序分页，
不设本地固定最大页。该例外由真实 FRS threadID、连续三页
HTTP/MIME/Proto/current-page 运行证据与五页确定性 pagination tests
支持。Android 已证 `has_more=0` 是 client stop signal，iOS 以其作为
wire terminal 合同；真实末页仍未运行验证。不扩展到 PB Floor、
倒序、跳楼、只看楼主、Live 图片或其他 endpoint。
