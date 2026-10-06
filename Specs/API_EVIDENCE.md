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
  阶段 19A 已补充当前 PBPage 返回图片候选的生产加载运行证据；这不补齐
  上述 PBPage endpoint 的其他 UNKNOWN。

### `image.resourceFetch`

- U05 导出（CODE_EVIDENCE）：Android `PhotoViewActivity.kt` 保存/分享按钮固定当时页索引，下载 `originUrl`。
  iOS 复用已存在的 `.original → bigCDN → big → dynamic → cdn → activeCDN → source` 候选，
  不合成 URL、不附加会话。原始编码文件与显示 Loader 的下采样位图分离，扩展名由内容类型确定。
  PhotoKit 使用 addOnly 和文件资源，成功依据 performChanges 完成；参见
  [Apple 文件资源说明](https://developer.apple.com/documentation/photos/phassetcreationrequest/addresource(with:fileurl:options:))。
  格式、方向、透明度、动图帧的字节保持由固定 fixture 验证；具体真机相册格式兼容性仍待人工验证。

- 用户任务：加载推荐/FRS 缩略图、PBPage 正文图片和唯一 MediaViewer
  当前页；它是服务端返回资源 URL 的普通 GET，不是新 Tieba API endpoint。
- Android 来源文件：`ui/widgets/compose/FeedCard.kt`、
  `api/models/protos/Extensions.kt`、`ui/utils/PhotoViewUtils.kt`、
  `ui/widgets/compose/Images.kt`、`ui/page/photoview/PhotoViewActivity.kt`、
  `App.kt`、`utils/ImageUtil.kt`。
- Android symbols：`ImmutableHolder<Media>.url`、`PbContent.picUrl`、
  `getPhotoViewData`、`NetworkImage`、`PreviewImage`、
  `App.createSketch`、`ImageUtil.getUrl`。
- 列表候选：`Tieba_Media` 的缩略图参数顺序为
  `big_pic → dynamic_pic → src_pic`，没有可用缩略图时才回到
  `origin_pic`。iOS 只保留字段中已有、通过 URL 解析且为 HTTPS 的候选，
  按该顺序逐个有限降级；不会合成 CDN host 或改写 URL。
- PB type 3 正文预览：Android `PbContent.picUrl` 将 `origin_src` 作为
  origin fallback，并按 `big_cdn_src → big_src → dynamic → cdn_src →
  cdn_src_active → src` 提供缩略候选。iOS 正文沿用该顺序；
  MediaViewer 优先 `origin_src`，随后只尝试同一组已返回候选。
- PB type 20：Android 只使用 `src` 作为 preview/origin；iOS 同样不生成
  额外候选。
- Android call site 按上述高到低顺序提供 vararg，但 `ImageUtil.getUrl` 会受
  imageLoadSettings/Wi-Fi 的 `needReverse` 影响而反转后只选择一条。iOS Beta
  固定使用高到低的有限 fallback，没有复制 Android 的网络/设置反转策略。
- 认证边界：Android Sketch `DisplayRequest` 接收资源 URL，global HTTP stack
  只显式设置普通 User-Agent；没有证据要求向资源 host 附加 BDUSS、STOKEN
  或 Cookie。iOS 因而使用独立 ephemeral `URLSession`，禁用 Cookie storage、
  credential storage 和 `httpShouldSetCookies`，不读取 AuthContext。
- 传输边界：Production domain descriptor 只接受 HTTPS；HTTP、credential URL、
  fragment、非绝对 URL 与超长 URL 均 fail closed。没有添加 ATS 任意加载例外。
  Loader 本身只识别 HTTP/HTTPS，以便确定性测试错误分类；Production mapper
  不会把 HTTP 候选交给它。
- iOS 领域映射：列表使用 `ImageResourceDescriptor`，PB 使用稳定
  `ThreadImageRequestDescriptor`；cache identity 由稳定业务资源 ID、purpose、
  resize mode、目标像素尺寸和候选指纹共同组成，不使用 UUID。
- iOS 运行态：2026-09-01 在保留既有 Keychain 会话的 iPhone Simulator 上，
  Live 推荐与公开吧首页均显示真实缩略图；一个八图公开帖的正文 8/8
  进入 rendered，MediaViewer 连续显示第 3、4、5 张、双击缩放并正确关闭返回。
  没有保存资源 URL、响应 bytes、用户正文、Cookie 或凭据。
- iOS 客户端策略：单个候选的 2xx/status、MIME、大小和 ImageIO decode
  均通过后才算成功；失败后只尝试下一条已证候选。这个“有限候选回退”是
  阶段 19A 的受测 iOS 韧性策略，不应误写成 Android 同时请求全部候选。
- UNKNOWN：所有资源 host/redirect 的长期稳定性、部分帖子只有 HTTP 候选时的
  安全替代、动画图片播放、头像 portrait token 的安全 HTTPS 合成规则、
  全分辨率瓦片和真实断网后的 CDN 错误分布。

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
- Fixture 路径：`TestSupport/Fixtures/API/Thread/PBFloor/`（R08 synthetic fixtures）。
- Fixture 获取/生成方式：正常、空、重叠页、缺作者、仅未知节点、页字段冲突。
- 已验证行为：Android UI production call chain 和 page 比较逻辑。
- R08 CODE_EVIDENCE：请求kz/pid/pn/forum_id/spid=0/is_comm_reverse=0/ori_ugc_type=0，V12 common，needSToken=false；不增加排序/锚定选项。回复目标已经是PbContent(type4)与文字组合，保留原始顺序，不能猜独立reply_user字段。SubPostList.content含PbContent，Android逐节点Render，允许复用图片renderer。
- R08 RUNTIME_EVIDENCE（2026-09-24）：公开帖匿名HTTPS最小请求，forum_id=0且无scr_*设备数据，HTTP200/application/octet-stream/error0，返回父楼身份匹配，13条唯一回复、13作者/等级、节点0/2/4。current_page=1,total_page=1,total_count=14；按Android页比较终止，不用has_more或条数推测。仅保存元数据于Artifacts/VisualReview/R08/public-floor-page1.json。
- R08客户端策略：只读匿名、不带Cookie/session/device；返回父楼/主题/页必须匹配，初页需要父楼，后续可保留已加载父楼。按稳定subPostID保序去重。真实错误码保留server(code)，不猜测登录失效映射。合成成功/空/错误/畸形/重叠页/缺作者/未知节点及Mock timeout/cancel均独立验证。
- UNKNOWN：跨主题匿名稳定性、Live第二页、服务端total_count差异原因、subPostId非零锚定语义；本阶段不支持后者。

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

## R01 视觉字段补全（CODE_EVIDENCE，2026-09-05）

不增加端点、请求参数、Proto 或凭据。API reference 保持
`5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`，UI reference 为
`c5f1125f42498e49db4e4a9cb66313b8c8a285c7`。

- `app/src/main/protos/User.proto`：id#2/name#3/nameShow#4/portrait#5/level_id#23/is_bawu#25/bawu_type#26；推荐、PBPage、FRS、Profile 白名单映射为共同用户值。proto3 无 scalar presence，非正等级保持 nil；楼主只按正 userID 与主题作者 ID 相等判定。
- `FrsPage/ForumInfo.proto`：user_level#7/level_name#8/member_num#9/thread_num#10/post_num#11/avatar#24。UI ForumPage 使用这些等级字段；没有已证 hot_num，不能用成员数冒充热度。
- `ForumGuide/LikeForum.proto`：avatar#3/hot_num#4/member_count#5/thread_num#6/level_id#10/level_name#11；既有 FollowedForum 映射保留。
- `SimpleForum.proto` avatar#4 来自 ThreadInfo.forumInfo；搜索 beans 的 SearchForumBean.ForumInfoBean.avatar、SearchThreadBean.UserInfoBean.user_id/portrait 和 ForumInfo.avatar 可选透传。搜索没有等级证据，保持 nil。
- UI `utils/StringUtil.kt:getAvatarUrl` 150–156 对完整 HTTP/HTTPS 原样返回；裸 portrait 只证实 HTTP URL。iOS 只消费有效 HTTPS 原值，保留裸 portrait 但不升级 scheme、不放宽 TLS。安全 HTTPS token 合成仍为 UNKNOWN。
- UI `api/models/protos/Extensions.kt:379` 吧务只在 is_bawu==1 时成立，manager 为吧主、其余为小吧主。缺失身份不得判断为楼主。

验证样本为 R01VisualMappingTests 中完全合成的 Proto/JSON，非 Live 响应；Gallery 图片与等级为明确标注的本地展示样本，绝不进入 Live repository。本阶段不宣称新的 Live 网络运行证据。

## R03 首页字段消费（CODE_EVIDENCE，2026-09-23）

本轮复用既有 ForumGuideProtocol likeForum 的 avatar/hotNum/levelId/levelName；映射和请求均不改变。UI reference c5f1125 的 HomePage.kt / ForumItemContent 消费同名字段；热度以 StringUtil.getShortNumString 截断显示，不以 memberCount 替代。最近浏览使用 ForumHome 已成功显示的 ForumSummary.avatarResourceID，缺图仅回退相同 forumID 的已知关注头像。公开 HTTPS 地址持久化边界见 ADR-0023；不合成头像 URL、不新增 CDN Cookie、不新增请求。

Android Toolbar.AccountNavIcon 使用 LocalAccount.portrait，而当前 iOS Session 只提供授权状态/lease，没有已证实的当前账号 userID/portrait。CURRENT_ACCOUNT_AVATAR 仍为 UNKNOWN，首页用中性缺省，不从登录 Cookie 推导身份，也不以 Fixture 冒充 Live。

R03 只读 Live 字段复核：当前 18 条关注吧中 avatar 18 条为完整 HTTP、0 条为可加载 HTTPS、0 条缺失（只输出计数，临时诊断已移除）。因此本轮未证明 Live 吧头像加载成功；不升级 scheme、不放宽 ATS、不向 CDN 发送 Cookie。账号头像缺字段与吧头像 HTTP 限制是两个独立 UNKNOWN。

### R03 ForumGuide 头像 HTTPS 传输适配（2026-09-23，CODE + RUNTIME_EVIDENCE）

用户明确要求参照 Android 使吧头像正常显示后，补查 UI reference c5f1125：HomePage.kt:294–310 的 ForumItemContent 将 item.avatar 原样传入 Avatar；Avatars.kt:127–145 用 Sketch DisplayRequest；App.kt:777–780 创建独立 OkHttpStack；AndroidManifest.xml:59 允许 cleartext。Android 没有执行 HTTPS 升级，不声称这条适配来自 Android。

iOS runtime 最小验证从当前 API 提供的两个完整公开头像地址出发，仅将 scheme 改为 HTTPS，使用同一注入的 ProductionImageLoader 加载，两次均 rendered=true。已证实 host=tiebapic.baidu.com、路径族=/forum/w=120;h=120/，地址带 query；未保存完整 URL、query 值或响应体。首次诊断因保守排除 query 没有发请求；保留原 query 后验证成功。详见 Artifacts/VisualReview/R03/forum-https-query-probe.log。

因此只对完整 HTTP、精确 host、已验证 path prefix、无 userinfo/port/fragment 的吧头像进行 HTTPS 协议适配，域名/编码路径/query 逐字保留；不合成资源路径、不合成裸 portrait、不对任意域名升级、不回退 HTTP。生产 Loader/缓存/Session 保持不变，仍不附带 Cookie 或 Authorization；合成样本及匿名请求合同由 R03ForumAvatarTests 验证。此项补充取代本节上方“当前没有可用 HTTPS 吧图”的待证状态；当前账户头像仍 UNKNOWN。

R03 完整列表复核发现 ForumGuide 实际 path 使用 percent encoding：decoded 前缀 forum/w=120;h=120，encoded 前缀 forum/w%3D120%3Bh%3D120，初版匹配 accepted=0。以 URLComponents.path 检查已验证路径族，输出仍仅替换原字符串 scheme，编码路径及 query 字节不变。新增 percentEncodedForumGuidePathKeepsItsExactBytes 回归；不通过重编码路径修复签名。

R03 整表地址分类补充：18 项由两类各 9 项构成：tiebapic.baidu.com/forum/w=120;h=120 与 imgsrc.baidu.com/forum/pic。前者已运行验证；对后者另取一个接口原值，仅替换 HTTPS，通过同一 ProductionImageLoader 得到 rendered=true。记录为 forum-family-probe.log。将第二个精确 host/path 配对加入已验证转换范围，未知 host/path 仍拒绝；整表不依赖访问吧首页后才能显示。诊断源码已移除。

## R04 Personalized feed 展示投影（2026-09-23，CODE_EVIDENCE）

锁定 API commit 5545326 的 ThreadInfo.proto / Media.proto / PbContent.proto 与 UI c5f1125 的 FeedCard.kt、api/models/protos/Extensions.kt：FeedCardForThreadInfo 的 UserHeader 使用 author + lastTimeInt；正文按 isNoTitle/title 与 richAbstract 展示，richAbstract 类型 0/40 为文本（连续空格收敛），2 为表情文字标记，未知类型不显示；旧 Abstract 类型 0/4 仅作缺少 richAbstract 时兼容。media 全数组保持原始 ordinal 及既有 big/dynamic/src/origin 候选顺序，动态只预览前三张，角标为完整媒体总数。forumInfo.avatar/name、shareNum、replyNum、agreeNum 分别用于吧 chip 和三栏计数。计数负值/零值不作有效正数展示；proto3 scalar presence 不可区分，不能宣称零值来自显式服务器字段。

请求、认证、分页、去重、route identity 维持既有链路；新增字段仅为响应白名单投影。合成 protobuf 回归位于 R04FeedMappingTests / Stage11LiveRecommendationTests，隔离 UI 样本明确标注 Fixture。本节为源码证据，不冒充 Live 运行结果。

R04 用户头像最小 RUNTIME_EVIDENCE：对 StringUtil.getAvatarUrl 已证实的 tb.himg.baidu.com/sys/portrait/item/ 路径仅更换 HTTPS，用现有 ProductionImageLoader 验证两个当前裸 portrait，结果均 transport（补充分类的一次复核亦如此）。没有记录完整地址/portrait/用户 ID。不能据此批准安全 HTTPS token 合成；AVATAR_HTTPS_TOKEN_SYNTHESIS 仍 UNKNOWN，完整 HTTPS 原值继续受支持。未修改生产 URL 规则。

R04 头像传输补充：对无用户路径/参数的 `https://tb.himg.baidu.com/` 执行 curl --head --max-time 10，exit 60，报告证书 subject name 不匹配目标 hostname。portrait-host-tls.log 为原始结果。没有使用 -k、ATS 例外或更换未获证据支持的域名。此结果解释当前环境的 TLS 失败，不证明所有网络环境永远失败。

### R04 作者头像 HTTP 例外（2026-09-23，用户已授权）

用户明确允许 `tb.himg.baidu.com/sys/portrait/item/` 使用原版 HTTP，决策和拒绝边界见 ADR-0024。CODE_EVIDENCE 仍为 UI c5f1125 的 StringUtil.kt:150–156、FeedCard.UserHeader，输入为 User.portrait#5，不新增接口或请求字段。只使用原版前缀加服务端标识；完整 HTTPS 原值继续使用，不将 HTTPS 失败改为自动 HTTP fallback。API、Session、身份和其他 CDN 不变，图片继续匿名且拒绝重定向。

本节是获批的实现合同，尚不代表修复后的真实头像加载通过；运行结果只在执行后写入 R04_AUTHOR_AVATAR。此前 HTTPS 合成 UNKNOWN 历史保留，这次没有声称旧域名支持 HTTPS。

修复后 RUNTIME_EVIDENCE：最终正常 Debug 构建使用既有 Live Personalized → mapper → TiebaAvatarView → ProductionImageLoader，iPhone 动态首屏实际显示两个不同作者的真实头像；截图 iphone-live-avatars-top.png / iphone-live-final.png。没有临时 probe 或额外作者资料请求。匿名图片请求与精确 host/path 准入由 R04AuthorAvatarTests 验证；不将 Fixture 头像当 Live 证据，不将首屏截图当后续每个作者均成功的证明。

## R05 Forum sort / good / ordinary tabs（CODE_EVIDENCE）

UI c5f1125：ForumPage.kt getSortType 默认 0、菜单值 [0,1]；generalTabs 仅 isGeneralTab==1 && tabType==15。ForumThreadListViewModel 调 FrsPageRepository，精华 sort=-1 / goodClassifyId=0 或 forum.good_classify.class_id；MixedTiebaApiImpl.frsPage 写 sort_type、is_good、cid。ForumPage Header 消费 avatar/user_level/level_name/cur_score/levelup_score/is_like/sign_in_info；匿名缺省不能当成已登录等级。

普通分类：MixedTiebaApiImpl.generalTabList / OfficialProtobufTiebaApi.generalTabListFlow，HTTPS tiebac.baidu.com POST /c/f/frs/generalTabList?cmd=309622&format=protobuf，multipart data/file、rn=30、pn=1+、tab_id/type/name/is_general_tab/is_default_navtab 均来自 nav_tab_info；sort_type 默认 0 或服务器 sort_menu.source_id；last_thread_id 初始 0，下一页 general_list.last.id。has_more==1 且列表非空继续。响应 general_list/user_list 复用 ThreadInfo/User；threadId 仍是既有 Forum route/行 ID。论坛请求保持匿名且不传播 Cookie 到图片 CDN。

协议 reference 5545326 的 GeneralTabList 四个文件及 SortOption.proto 与 UI 相应协议一致；行为验收 Fixture 为合成内容，无 Live body/凭据。RUNTIME_EVIDENCE 待本轮最小匿名 Probe；生产开放依据 ADR-0025。

R05 匿名运行（2026-09-23，固定公开高通吧）：reply/creation/good/good-filter 四种请求均 HTTP 200、application/octet-stream，分别 13 条；初始响应有 8 个符合 Android 筛选的普通分类、6 个精华分类。generalTabList HTTP 200、application/protobuf、343995 bytes，解码 30 条、id/threadID 均全部为正；首次 pipeline 因沿用 FRS 的 MIME 白名单而 fail closed。仅为 GeneralTabProtocol 添加已观察到的 application/protobuf，不改变 FRS 或全局网络校验。全部请求 Cookie=false，无原始 body/ID/内容持久化。

R05 复验：live-probe-verified.log 六次请求全部 HTTP 200、Cookie=false。reply/creation/good/good-filter 各 13 条；generalTabList page 1 / page 2 各 30 条、343995 / 348384 bytes、application/protobuf、has_more=true，raw id/threadID 全为正，next 使用前页原 id cursor。两次请求媒体多图条目各 2，首屏最新多图 5。个人 level=false，UI 保持缺省不显示。此证据启用 ADR-0025 的匿名普通分类，未保存 body 或作者/帖子 ID，已删除临时 Probe。

### R06 阅读楼层显示字段

R06 用户修订CODE_EVIDENCE：协议锁 `PbPage/PbPageResponseData.proto` forum#2 → `SimpleForum.proto` id#1/name#2/avatar#4；UI锁c5f1125 `ThreadPage.kt` TopBar:1873–1920 使用 forum.avatar 加圆形Avatar及吧名。PBPageDomainMapper透传为ThreadReaderSnapshot.forumAvatarResource，沿用TiebaAvatarResource现有CDN规则及匿名ProductionImageLoader，缺失保持nil；追加页未返回头像时保留已加载的首屏值。R06ThreadPresentationTests的固定generated-message检查非空/缺失映射。没有改请求/Proto/凭据边界或合成URL。

CODE_EVIDENCE：UI 锁 c5f1125 ThreadPage.kt:194–208/2130–2174 使用 author.ip_address、level_id、portrait、author.id == threadAuthorId、bawuType 与 post.agree.diffAgreeNum。协议锁下 User.proto field127 ip_address（生成 User.ipAddress）、Agree.proto field5 diffAgreeNum；Post.agree 的存在性通过 hasAgree 保留。TiebaUserVisualMapper 增加可选 ipLocation，PBPageDomainMapper 增加可选 agreeCount；缺字段不产生位置/计数，已有头像规则与请求凭据边界不改。确定性 generated-message 测试 R06ThreadPresentationTests 验证映射，不新增 endpoint 或更改 PBPage 请求。Live 数据展示尚待本阶段观察，不以 Fixture 冒充。

## R07 官方表情显示证据（不新增 API）

R08 用户反馈补充（2026-09-24）：匿名读取所报PbFloor全部3页（30/30/17条），除image_emoticon外实际还有type2：shoubai_emoji_face_04/大笑、07/笑哭、60/赞同、71/滑稽、72/捂脸及368/绝。前5个原PNG由锁定Android EmoticonManager.fetchEmoticons的已证实URL取得并本地打包；368的Android源和已证实web备用源均404，继续可读fallback。共6处“[图片]”是type0原文，响应不含对应图片ID/URL，不能重建表情。只保存类型/名称/ID和计数，证据在Artifacts/VisualReview/R08/Emoticons/wire-page{1,2,3}.json；没有Proto/API/Session或文本渲染器更改。R08SubpostEmoticonTests以合成回复复现并覆盖全部5种、旧目录、字号、附件、复制和链接node身份。

CODE_EVIDENCE：锁定UI c5f1125f42498e49db4e4a9cb66313b8c8a285c7 的 `api/models/protos/Extensions.kt::List<PbContent>.renders` case2 使用 text 注册资源ID、c 注册名称，然后以 `#(c)` 追加同一正文段；`utils/EmoticonManager.kt::registerEmoticon` 将 image_emoticon 别名规范化为 image_emoticon1。现有 PBPageDomainMapper/ThreadContentProtoMapper 已保留该独立node，无端点/请求/响应schema变化。合成 Swift Proto 回归验证独立type2、链接及@顺序，不能冒充Live抓包。直接复制资源和名称表的完整provenance见 Resources/TIEBA_EMOTICONS_PROVENANCE.md；无下载接口、CDN Cookie、TLS或Session修改。

### R07 捂嘴笑资源补齐（2026-09-24）

RUNTIME_EVIDENCE：对用户反馈的公开帖子使用现有 PBPageProtocol 匿名请求，HTTP200 / error_code0，仅提取 PbContent type2 的公开 text/c 对：`image_emoticon67` / `捂嘴笑`（同时返回已支持的25/滑稽）。未读取账户、Cookie、Keychain，不持久化完整响应。脱敏诊断记录：Artifacts/VisualReview/R07/MissingEmoticons/sanitized-emoticon-evidence.json。

CODE_EVIDENCE：UI锁c5f1125 Extensions.kt:47/59/254调用 EmoticonManager.registerEmoticon(text,c)；EmoticonManager.init预置61…101，fetchEmoticons下载缺失drawable的准确公开地址见 Resources/TIEBA_EMOTICONS_PROVENANCE.md。将67原PNG打包，并增加名称别名；生产请求/mapper/Proto/Session不变。其余未收录资源继续原文降级，不宣称完整动态注册支持。

### R07 全量表情目录修订（2026-09-24）

同一已存在匿名PBPage请求对第二个用户报告的公开帖子返回 type2/text=`image_emoticon91`/c=`微微一笑`；无账号/Cookie，未保存完整响应。Android锁定init编号集合104项全部收录。官方公开网页util.d8d2afea.js模块174提供完整名称表（包括23个注册扩展），core-common.6de6fbbf.js提供对应HTTPS图片规则；详细路径、SHA和冲突选择在 Resources/TIEBA_EMOTICONS_PROVENANCE.md。文本别名补齐，Proto给出的ID不重写。不新增生产API/动态注册/网络层，未改变Store/Repo/Proto/Session。总计127资源；无证据的51…60及未来未知ID保持原文，不以猜测填补。

## R09 text writes (2026-09-24, first visual gate)

User-authorized scope overrides the historical read-only product restriction only for new text threads and replies. Live sending is exclusively a visible user action; no automated Live write has been executed.

- UI source `c5f1125f`: `reply/ReplyPage.kt` 271–317 (draft), 497–520 (optional title length31), 645–670 (subpost prefix and send); `ReplyViewModel.kt`/`AddPostRepository.kt` separate addThread/addPost and use real returned IDs. No dedicated ReplyPage target screenshot exists in the supplied six-image directory; read 05/06 and source, do not claim pixel matching against a missing screenshot.
- `write.accountMetadata`: HTTPS POST `c.tieba.baidu.com/c/s/login`, form, active lease. Source `OfficialTiebaApi.loginFlow` 203–219, `LoginBean`, `AccountUtil.fetchAccountFlow` stores `anti.tbs` and `user.id`. Fields bdusstoken=`BDUSS|null`, stoken, channel_id/channel_uid empty, authsid=null, client11.10.8.6/type2; sign per `SortAndSignInterceptor` + secret literal. Response only allowlisted tbs/id is retained for the single send. No credential refresh or nickname mutation. Source route uses HTTP; HTTPS metadata support is now verified by the R09 read-only in-App preflight below; no HTTP fallback.
- `write.thread`: HTTPS POST `c.tieba.baidu.com/c/c/thread/add`, active form. Source `MiniTiebaApi.kt`424–454 + `RetrofitTiebaApi.MINI_TIEBA_API`; content/kw/fid/title/is_hide1/is_ntitle(1 for empty title)/is_feedback0/reply_uid=null/takephoto_num0/z_id empty/entrance_type1/vcode_tag12/new_vcode1/anonymous1/call_from2/can_no_forum0/cuid_gid empty/tbs/stoken. Client7.2.0.0/type2/from1021636m/subapp_type=mini/BDUSS; client_user_token from actual login uid. Signing is lowercase MD5 of decoded fields sorted by name, concatenated name=value without separators, then `tiebaclient!!!`; before URL encoding. Device identifiers, random StParam telemetry and unavailable display name are omitted, not forged. Response AddThreadBean.error_code, info.need_vcode, pid/tid; requires positive real pid/tid for success. HTTPS/minimal fields remain unverified.
- `write.post`: HTTPS POST `tiebac.baidu.com/c/c/post/add?cmd=309731&format=protobuf`, active multipart data + external stoken. Source `MixedTiebaApiImpl.addPostFlow`1257–1311, `OfficialProtobufTiebaApi.addPostFlow`, `ProtobufRequest.buildCommonRequest(TIEBA_V12_POST)`/body. Common client12.35.1.0/type2/from1020031h, BDUSS/stoken/tbs. Exact reply data defaults mapped in TextWriteProtocol. Thread reply uses post_from13, no quote/repost/subpost/recipient; floor uses post_from0 + quote_id/repostid=parent + reply_uid; subpost uses same parent, sub_post_id=selected reply, no post_from and `回复 #(reply, portrait, name) :content`. Correction from full interceptor audit: buildProtobufRequestBody initially omits client_version, but OFFICIAL_PROTOBUF_TIEBA_POST_API subsequently adds it via CommonParamInterceptor; SortAndSignInterceptor DOES sign the non-file multipart fields. See the correction below. Unavailable Android-only device/anti-abuse fields not fabricated.
- Wire closure: existing protocol5545326b AddPostRequest/Data/Response/Data and 14 dependencies, 234 total. Response PostAntiInfo/VcodeInfo produce verification-required status before checking error. Other nonzero server codes shown numerically, not guessed to mean success or expiration. HTTP401/current lease failure produces authentication error; ambiguous post transport/decode/cancellation keeps draft and instructs checking the page before retry.
- Shared EndpointExecutor, ActiveSessionRequestAuthorizer and URLSessionHTTPClient are reused. No logged bodies, sessions or full responses; no CDN credentials. HTTPS only, redirects rejected, retryPolicy.never. No image uploading, retries, optimistic row IDs or Session/Keychain changes.
- Domain: TextComposeTarget carries original stable IDs. PBPageDomainMapper additionally passes existing forum.id into ThreadReaderSnapshot, retained across pagination. Missing identifiers disable send; no forum name→ID guess.
- Fixed tests/fixtures: `TestSupport/Fixtures/API/Write/README.md`, R09WriteProtocolTests/R09WriteRepositoryTests/R09ComposerTests, isolated full-App DebugR09ComposerGallery. Live publishing, account restrictions and actual post-success server refresh are pending separate manual gate.

### R09 用户 Live 发送失败：前置资料响应与拦截器复核（2026-09-24）

RUNTIME_EVIDENCE：用户手动发送后出现malformedResponse，其他账号未见回复。此枚举只在writeStarted=false产生，即获取账号元数据阶段；不能把此提示当作已提交。匿名HTTPS `/c/s/login` 最小请求返回HTTP200、`application/x-javascript`、有效JSON/error_code1；旧白名单会在JSON解码之前拒绝该响应。未使用真实凭据或发送任何正文。脱敏元数据在Artifacts/VisualReview/R09/WritePreflight/anonymous-metadata.json。当前修复为R09两个使用原版同一JSON转换器的端点加入已观察MIME，不更改共享pipeline、不解析执行JavaScript。

CODE_EVIDENCE（UI c5f1125f）：`RetrofitTiebaApi.kt:280–344`为POST客户端添加CommonParamInterceptor；`CommonParamInterceptor`的MyMultipartBody分支实际追加字段；`SortAndSignInterceptor`因追加的_client_version存在，对所有非文件字段排序签名，文件data排除。此前只看ProtobufRequest.kt就推断没有签名是错误的。此次补齐明确可用的BDUSS/stoken、client type/version、from=tieba和静态公共参数，加入Charset/x_bd_data_type请求头，复用现有签名函数。proto内部common.from=1020031h与外层from=tieba是原版的两个独立值，不互相覆盖。时钟、Android设备/遥测及z_id来源仍不伪造，不声称请求逐字与Android设备一致。

重新核对ReplyViewModel→AddPostRepository→MixedTiebaApiImpl→OfficialProtobufTiebaApi/MiniTiebaApi→公共拦截器→响应模型：三种回复目标字段及正文前缀未发现映射差异；新帖表单已签名。Android GsonResponseBodyConverter直接读取JSON charStream，不因application/x-javascript拒绝LoginBean。新帖写接口尚无本轮Live样本；按同一Gson转换器行为兼容此JSON MIME并有固定样本验证，不宣称已观察到新帖的真实响应。发布后响应解析仍按真实pid/tid判断，不自动重试。

RUNTIME_EVIDENCE补充：在完整Debug App中通过当前AuthContext和原HTTPClient执行一次仅限host=c.tieba.baidu.com/path=/c/s/login的前置诊断。HTTP200、error_code0、MIME application/x-javascript;charset=utf-8、JSON有效、user.id为string、tbs非空，生产Account decoder返回account-ready；publishRequests=0。只输出类型/布尔/计数，不保存uid、tbs、正文或凭据。记录live-account-metadata.json。临时诊断启动标志及代码已全部移除，最终安装正常App。

RUNTIME_EVIDENCE（用户手动发布，2026-09-24）：用户明确确认修订版主题回复发送成功，并提供原帖新增第9楼截图。此证据覆盖AddPost的threadReply路径；没有采集原始发布响应或服务端pid，不推定新帖/指定楼层/楼中楼均通过。截图留在ignored Artifacts/VisualReview/R09/WritePreflight/user-confirmed-live-thread-reply.png。所有AI操作均未触发Live发布。

### 发布后删除通知与兼容性证据边界（2026-09-25）

USER_REPORTED：用户报告经当前应用发布的一条主题回复收到“涉嫌异常行为”删除通知。`WRITE_MODERATION_CAUSE_UNKNOWN`；这证明有实际删帖反馈，不证明账号封禁或某个请求字段触发。R09/R10 的历史用户确认只覆盖当时发送/可见，不覆盖后续审核。

CODE_EVIDENCE：重新检查锁定的 Android protocol/UI 两版，11个发布链相关文件和 addPostFlow/addThreadFlow 方法一致。当前 iOS 与原版的确定差异包括：每次发布前获取账号资料、缺少业务显示名、裁剪后的客户端公共上下文，以及新帖使用 HTTPS。默认 UA 和回复版本与原版默认相同；没有发现应用层自动重发循环。缺少这次即时发布响应及平台审核理由，不把差异当作删除根因，也不补造验证/设备信息。完整来源、静态检查范围和未验证项见 `Docs/Audits/WRITE_MODERATION_COMPARISON.md`；本轮无 Live 请求或生产实现变化。

## R10 图片上传（CODE_EVIDENCE + 用户手动端到端 RUNTIME_EVIDENCE）

UI参考 c5f1125：`components/ImageUploader.kt::uploadSinglePicture` 分块512000，普通5MiB/原图10MiB；`api/retrofit/interfaces/OfficialTiebaApi.kt::uploadPicture` POST `/c/s/uploadPicture`，JSON。`RetrofitTiebaApi::OFFICIAL_TIEBA_API` 基址 c.tieba.baidu.com；采用HTTPS安全适配（用户单图主题回复验证见下文，未采集原始响应），_client_version=12.41.7.1，User-Agent同版本，BDUSS及公共字段由 CommonParamInterceptor 注入，multipart非文件字段由 SortAndSignInterceptor 签名，文件chunk不签；StParamInterceptor对multipart不增加遥测。接口删除Charset/_client_type请求头及naws_game_ver/sdk_ver表单；Cookie仅ka=open（不伪造BAIDUID）。不虚构设备/安装/追踪字段。

业务字段：alt=json、chunkNo从1、forum_name/small_flow_fname=真实吧名、groupId=1、height/width、isFinish=0/1、is_bjh=0、pic_water_type=2、resourceId=文件MD5+512000、saveOrigin=0、size=实际字节数。文件part name=chunk filename=file。响应 `UploadPictureResultBean`: error_code/error_msg/resourceId/chunkNo/picId，最终picInfo.originPic.width/height。分块序号必须匹配，最后真实picId及正尺寸齐全才算成功；非零代码/畸形响应不继续发帖。

`ReplyPage` 最多9张，只在发送后upload，成功按顺序拼 `正文\n#(pic,picId,width,height)`；表情插入 `#(名称)`，复用 R07 目录。fixture为完全虚构 picID/尺寸，自动化不发送Live。对应 ADR-0028。Live最终发布只由用户本人进行。

RUNTIME_EVIDENCE（用户手动上传并发布，2026-09-24）：用户确认“都正常，图片和表情包都正确，可以提交了”，并提供完整 Live App 的高通吧帖子第14/15楼截图；第15楼含文字、已渲染滑稽及一张 LOCAL PHOTO 4 图片。证据：ignored `Artifacts/VisualReview/R10/UserApproval/user-confirmed-live-image-emoticon-reply.png`。此记录只证明当前账号的一次单图加表情主题回复端到端成功；没有原始上传响应、picId 或发布响应采样，不将其推定为所有账号、四种写入目标、多图发布或 Live 重试全部通过。AI 未触发 Live 上传或发布。

## R11 Replies / Mentions / unread counts (2026-09-25)

- Sources (protocol `5545326`, UI `c5f1125`, relevant files identical):
  `api/retrofit/interfaces/NewTiebaApi.kt::{replyMeFlow,atMeFlow,msgFlow}`,
  `api/retrofit/RetrofitTiebaApi.kt::NEW_TIEBA_API`, `SortAndSignInterceptor`,
  `api/models/{MessageListBean,MsgBean}.kt`, `api/adapters/MessageListAdapter.kt`,
  `ui/page/main/notifications/list/{NotificationsListPage,NotificationsListViewModel}.kt`,
  `services/NotifyJobService.kt`, `ui/page/main/MainPage.kt`.
- POST form `/c/u/feed/replyme`, `/c/u/feed/atme`: refresh pn=0; next page=2 then +1 (Android refresh stores currentPage=1).
  POST `/c/s/msg`: bookmark=1. Active session BDUSS, static `_client_type=2`, `_client_version=8.2.2`, `from=baidu_appstore`, sorted form signature.
  iOS uses HTTPS on the same c.tieba.baidu.com host, never sends credentials over Android's legacy HTTP; no redirects/retries.
  Device/CUID/IMEI and randomized st telemetry are omitted, not fabricated. Requiredness remains UNKNOWN until Live verification.
- JSON error_code must explicitly equal 0. reply_list/at_list may be primitive/empty (MessageListAdapter); page.has_more and current_page control pagination. message.replyme + message.atme form unread total. Unknown fields ignored; malformed/transport/HTTP/server/auth distinct.
- Stable ID: kind + post_id + replyer.id + time. Invalid thread/post identity cannot route. quote_pid is ambiguous and must not be treated as parent ID. Message replyer has no level field: absent.
- Read behavior: Android MainPage clears its local badge when opening; no separate mark-read endpoint was found. iOS reads selected list then re-fetches `/c/s/msg`, reflects server result, never invents read mutation or clears the unopened tab.
- Navigation: main row is_floor=1 resolves `/c/f/pb/floor` with pid=0, spid=post_id (`MixedTiebaApiImpl::pbFloorFlow`, `SubPostsPage::loadFromSubPost`); use returned parent ID/current page and require target child in response. Otherwise PBPage pid=post_id returns target page; validate target membership and thread identity before showing. Shared reader/list are unchanged; R11 uses a seed adapter.
- Fixtures are synthetic, generated from documented response shape; no private Live messages, accounts or credential values retained.
- Live 2026-09-25: HTTPS replies and msg return `application/x-javascript`. Initial allowlist rejected this before decode. R11 accepts this legacy JSON MIME while retaining strict JSONDecoder (no script/JSONP evaluation); fixture verifies JSON accepted and executable/JSONP text rejected. Only MIME/error-type metadata was recorded.
- R11 interaction revision 2026-09-25 (explicit user requirement): quote/title opens the existing normal thread route with threadID only; reply body retains the postID/subpost locator above. Locked Android NotificationsListPage has separate quote hit handling but still supplies postId for ordinary thread quotes, so the new first-post entry behavior is user-directed, not attributed to that code. Live observation confirmed the same message's quote opens the thread's first post and body opens its exact floor; no endpoint/authentication changes.

- R11 full-thread revision 2026-09-25 (explicit user clarification): body tap always opens the complete thread and scrolls to the primary reply. For `is_floor=1`, verified PBFloor `pid=0/spid=post_id` resolves the real parent; no Subposts screen is opened. Normal replies use their own post_id. The existing ThreadReaderRepository starts at page 0/pid 0, retains each ordinary next page through the target, and then mounts the native reader with a one-shot stable anchor. Target lookup does not interpret quote_pid or invent a floor index. This supersedes the earlier target-only snapshot adapter; no new endpoint/parameters/authentication changes.


## R12 Current account presentation (2026-09-27)

CODE_EVIDENCE: Android UI c5f1125 `ui/page/main/user/UserViewModel.kt::Refresh` reads account.uid then userProfileFlow; UserPage StatCard maps concernNum/fansNum/postNum to 关注/粉丝/回贴. API lock 5545326 `AccountUtil.updateAccount`, `LoginBean.User` read id/name/portrait from `/c/s/login`; `OfficialTiebaApi.loginFlow` request is already captured by R09 TextWriteAccountProtocol. R12 reuses that exact HTTPS descriptor/body, parses only id/name/portrait (ignores anti/tokens), then reuses LiveUserProfileRepository / ProfileProtocol. No nickname initialization, credential mutation, new endpoint, new parameter, publishing, redirect or HTTP fallback.

CurrentAccountRepository only publishes a profile after active lease revalidation; Store clears on context change and rejects stale completion. Profile counts use the existing verified User fields (proto3 scalar zero semantics, no optional presence accessor), absent Fixture counts remain nil. Avatar uses existing TiebaAvatarResource/ProductionImageLoader with anonymous CDN requests. Synthetic tests cover identity/malformed response and session revocation; no raw Live responses retained. Service center Android URL depends on CUID and timestamp; no supported iOS route, so omit. Favorites repository absent, so omit. Live current-account presentation was observed in the normal R12 candidate on both iPhone and iPad: retained session, matching public name/avatar/counts, and profile destination loaded. No raw authenticated response was retained; screenshots are in ignored Artifacts/VisualReview/R12. This does not validate publishing or moderation behavior.

### 2026-09-27 发布显示名补齐（独立于 R13，定向验证通过 / Live 审核未知）

CODE_EVIDENCE：Android `AccountUtil.fetchAccountFlow`144–187 从 LoginBean 取得 uid/tbs，再从 GetUserInfo 的 `user.nameShow` 更新账号；LoginBean.User 只有 id/name/portrait，不能把登录名猜成显示名。`MixedTiebaApiImpl.addPostFlow`1290–1291 将账号 nameShow（缺省空串）放入 AddPostRequestData.name_show；`MiniTiebaApi.addThreadFlow`437 将该字段放入新帖表单。当前移植未串联该字段，属于明确的业务字段遗漏；与涉嫌异常行为删除的因果关系仍 UNKNOWN。

本次最小适配复用已接入的匿名 `/c/u/user/profile` 和 ProfileProtocol（与 R12 当前账户资料相同的读取路径），只取同 uid 的原始 `user.nameShow`。不新增 getuserinfo/schema，不发送登录凭据到公开资料请求，不把 name/fallbackDisplayName 写成 name_show。资料获取失败/身份不符停止发送、保留草稿；有效响应缺字段用原版空值语义。每次发送前读取，不增加重试或账户缓存。固定样本：R09WriteFixture 的合成 uid42、不同登录名/显示名和 Unicode/保留字符；自动化全部 Mock。服务端审核/真实发布结果另行验证，不由 Unit 推定。

RUNTIME_EVIDENCE（用户手动，2026-09-27）：用户确认“这回发成功了”，提供完整 App 中新增第3楼、中文时间及内联表情正常显示的截图，保存在 ignored Artifacts/Audits/WriteCompatibility20260927/user-confirmed-live-reply.png。只验证本次发送/当前可见；未采集即时响应、未验证后续审核保留，不据此将 name_show 与删帖原因认定为因果。AI 零 Live 发送/上传，当前候选未提交。

### U07 公开内容动作（2026-10-06，CODE_EVIDENCE）

- 锁定 Android `ui/page/thread/ThreadPage.kt` 的 onShareClick（1440）使用 `https://tieba.baidu.com/p/$threadId`；
  `ui/page/forum/ForumPage.kt::shareForum`（344）使用 `https://tieba.baidu.com/f?kw=$forumName`。
  iOS PublicContentURL 只携正 threadID 或 URLQueryItem 编码的吧名，不拼 API、Cookie 或跟踪参数。
- `ThreadInfo.richAbstract` 的元素是既有 `PbContent`，复用 ThreadContentProtoMapper 的 type=1/link 与 type=4/uid 验证；
  `Abstract.proto` 只有 text/link/un 等，没有 uid，不能按显示名猜资料 ID。保留摘要文字/表情原顺序及原始 ordinal。
- 不新增 endpoint、请求或网络协议；外部安全网页通过系统 OpenURLAction，站内已知 URL 复用 DeepLinkParser 到当前路由栈。
  合成测试仅证明 intent、原生 route 与分享载荷，不能当作所有 Live 短链/查询组合已支持。
