# API / Protobuf 证据

状态：`STATIC_AND_CROSS_LANGUAGE_FIXTURE_EVIDENCE`

Android 基线：`4.0-dev@5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`。

阶段 07 完成首个 Personalized schema/request/response 的本地协议闭环：
从 pinned Android submodule 直接生成 51 文件闭包，以独立 JVM producer 构造
脱敏 binary fixture，并由 SwiftProtobuf decode/map。没有注册任何 Tieba live
host、没有发送真实请求，production composition 继续使用
`DisabledHTTPClient`。

本阶段没有真实请求、账号验证或服务端响应，因此没有
`RUNTIME_EVIDENCE`。`CROSS_LANGUAGE_GENERATED` 只证明 pinned schema 与
JVM/Swift wire 行为，不能证明匿名、最小 live 参数、MIME、错误码或分页。
下列 endpoint 仍不代表已获准在 iOS 生产代码中接入。凡仍使用明文 HTTP
的链路状态为 `BLOCKED`，必须先找到并验证 HTTPS 等价路径。

## 公共传输证据

### Protobuf family

- `CODE_EVIDENCE`：`RetrofitTiebaApi.OFFICIAL_PROTOBUF_TIEBA_API` 和 V12 variants 的 base URL 是 `https://tiebac.baidu.com/`。
- `CODE_EVIDENCE`：`OfficialProtobufTiebaApi` 使用 POST；`ProtobufRequest.buildProtobufRequestBody` 以 multipart/form-data 的 binary `data` part 发送 Wire `Message.encode()`。
- `CODE_EVIDENCE`：关键 header 包含 `X-BD-Data-Type: protobuf`、客户端版本/类型和设备标识。
- `CODE_EVIDENCE`：`ProtoFailureResponseInterceptor` 以公共 `Error.error_code` 判定业务失败；具体响应仍需独立解码。`Error.user_msg` 没有被现有异常映射完整保留。
- `CODE_EVIDENCE`：`CommonRequest` 可包含 BDUSS/STOKEN、设备/安装/屏幕/版本字段；外层 multipart 也可能附 `stoken`。
- `CODE_EVIDENCE`：`buildCommonRequest(TIEBA_V12, bduss, stoken)` 的 V12 分支忽略传入的两个参数，改读全局 `AccountUtil`；`buildProtobufRequestBody(..., needSToken=true)` 的外层 stoken 也读全局账户。
- `INFERENCE`：这会让“为新登录账户显式传凭据”的 caller 与实际发送账户不一致，可能发送旧/空 session。它是必须规避的 Android 实现风险，不是 iOS 认证契约。
- `UNKNOWN`：哪些字段是服务端最小必需值、哪些仅为 Android telemetry、匿名请求是否接受、iOS 合法客户端标识、签名与版本兼容。

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

任何 `optional-in-request` endpoint 的匿名能力都是 `UNKNOWN`。

### 安全与 fixture 规则

- fixture 必须删除 Cookie、BDUSS、STOKEN、授权头、手机号、私密内容和可追踪设备标识。
- 二进制 fixture 同时保存脱敏来源记录、SHA-256 和预期 mapper 输出；不得保存真实请求 header。
- 成功、空、畸形、超时、取消、未登录、会话失效是所有 P0 endpoint 的最小集合。
- Personalized 已有构造的跨语言 fixture；其余路径仍是后续目标，不能把
  synthetic/cross-language fixture 标成 live capture。

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
  设备或 session；该最小请求未对服务端发送。
- multipart evidence：固定 Android boundary
  `--------7da3d81520810*`，binary part 为 `name=data`、`filename=file`、无
  part Content-Type；外层 endpoint header 是 `X-BD-Data-Type: protobuf`。
- 服务端错误字段：`Error.error_code/error_msg/user_msg`。
- 关键 headers：`X-BD-Data-Type: protobuf`；V12 client headers。
- 设备/版本参数：CommonRequest、AppPosInfo、screen、client version；最小集合 `UNKNOWN`。
- 敏感字段：可选 BDUSS/STOKEN、client/device identifiers；fixture 必须移除。
- iOS domain mapper：`PersonalizedResponse → RecommendationPage(items, nextPageCandidate, terminalUnknown)`；已实现白名单 mapper，保留 raw `id/threadId`、服务器顺序、raw `threadTypes=999` 与 message presence；不决定 canonical ID、不执行直播/视频过滤。
- Fixture 路径：
  `TestSupport/Fixtures/API/Recommendations/personalized_cross_language.pb`；
  SHA-256
  `54a838f8bd05c39e90b84b3bba4d4224dc81fe11b63934e23dd65be937eebb4a`。
- Fixture 类型：`CROSS_LANGUAGE_GENERATED`；Java 21.0.10 +
  protobuf-java 4.35.1 `DynamicMessage` 从同一 51-file descriptor closure
  生成，来源见相邻 `PROVENANCE.md`。
- 已验证行为：Android 静态调用链和 request 字段；request protobuf golden、
  Android multipart boundary/data/file 形态、optional default presence、未知
  field round-trip、empty/missing data、service error、malformed/empty body、
  raw integer 保留与 JVM→Swift mapper。没有匿名成功响应，不能升级为
  `RUNTIME_EVIDENCE`。
- UNKNOWN：匿名、终止条件、page 起点以外的边界、空页、广告/直播节点、稳定顺序、限流与错误码。

### `followedForums.forumGuide`

- 用户任务：登录后读取全部关注吧。
- HTTP method / URL family：POST `http://c.tieba.baidu.com/c/f/forum/forumGuide`；`BLOCKED`。
- Android 来源文件：`OfficialTiebaApi.kt`、`MixedTiebaApiImpl.kt`、`HomeViewModel.kt`。
- Android symbol：`forumGuideFlow`、`allForumGuideFlow`、`HomePartialChangeProducer.produceRefreshPartialChangeFlow`。
- 请求构建来源：Retrofit form + common-param/sign interceptors。
- 认证要求：`required-by-client`；ForceLogin，`tbs` 与 `stoken`。
- 请求编码：form-urlencoded。
- 请求 Protobuf：无。
- 响应 Protobuf/DTO：`ForumGuideBean`；`like_forum`、`like_forum_has_more`、公共 JSON 错误。
- 分页字段：`page_no` 从 1；`res_num=50`；循环到 `like_forum_has_more=false`。
- 服务端错误字段：JSON common aliases；真实会话失效码 `UNKNOWN`。
- 关键 headers：Official Android client headers；具体最小合法集合 `UNKNOWN`。
- 设备/版本参数：common Android params 和 legacy sign；不得复制。
- 敏感字段：STOKEN、TBS、可能的 Cookie/device id。
- iOS domain mapper：`ForumGuideBean → FollowedForumPage`；稳定 forum id/name。Repository 可在内部逐页聚合，但对 Store 只原子返回同一 session 的完整集合，或返回带 failedPage 的失败；不得发布部分 membership。
- Fixture 路径：`TestSupport/Fixtures/API/FollowedForums/`（`NOT_CREATED`）。
- Fixture 获取/生成方式：必须先确认 HTTPS 等价 endpoint，再用测试账号脱敏采集；不得通过 HTTP 采集凭据。
- 已验证行为：Android 当前 Home 的权威 call site 是 form endpoint；Proto `forumGuideNewFlow` 未发现 Home caller。
- UNKNOWN：安全 HTTPS 路径、token 最小集合、会话过期、空列表、账号超多页、Proto endpoint 能否等价替代。

### `forum.frsPage`

- 用户任务：读取吧信息、主题首屏、刷新和后续页。
- HTTP method / URL family：POST `https://tiebac.baidu.com/c/f/frs/page?cmd=301001`。
- Android 来源文件：`OfficialProtobufTiebaApi.kt`、`MixedTiebaApiImpl.kt`、`FrsPageRepository.kt`、`ForumThreadListViewModel.kt`。
- Android symbol：`frsPageFlow`、`frsPage`、`FrsPageRepository.frsPage`。
- 请求构建来源：`FrsPageRequest` + multipart protobuf。
- 认证要求：`optional-in-request`；匿名行为 `UNKNOWN`。
- 请求编码：multipart/form-data + protobuf；另有 `forum_name` header。
- 请求 Protobuf：`FrsPageRequest/FrsPageRequestData`，`FrsPage/FrsPage.proto`。
- 响应 Protobuf/DTO：`FrsPageResponse/FrsPageResponseData`。
- 分页字段：`pn`、`load_type`、`Page.has_more`、`thread_id_list`；sort/cid/is_good 影响列表。
- 服务端错误字段：`Error`。
- 关键 headers：protobuf data type、URL-encoded forum name header。
- 设备/版本参数：CommonRequest、AppPos、screen、V12 version。
- 敏感字段：可选 session/device fields。
- iOS domain mapper：`FrsPageResponse → ForumSnapshot + ForumThreadPage + ServerTabs`；user_list 关联失败必须形成可降级作者，而非抛异常。
- Fixture 路径：`TestSupport/Fixtures/API/Forum/FRSPage/`（`NOT_CREATED`）。
- Fixture 获取/生成方式：匿名和登录两组脱敏样本；另构造动态 tab、置顶、精品分类、缺 user、重复 id、空页。
- 已验证行为：字段构造、当前 call chain、Android Page.has_more 读取。
- UNKNOWN：动态 tab 类型、置顶顺序、匿名差异、`thread_id_list` 语义、sort 值域、合法空页。

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
- 设备/版本参数：CommonRequest、AppPos、screen；最小集合 `UNKNOWN`。
- 敏感字段：可选 BDUSS/STOKEN 与 device fields。
- iOS domain mapper：`ThreadSnapshot`、`PostPage`、`Post/ContentNode`；缺作者映射为匿名/未知作者；未知节点保留 raw type。
- Fixture 路径：`TestSupport/Fixtures/API/Thread/PBPage/`（`NOT_CREATED`）。
- Fixture 获取/生成方式：脱敏采集首屏/中页/末页/锚点/升降热序；构造缺 data/page/author/forum/anti、空 post_list、重叠 pid、畸形 pids。
- 已验证行为：Android 当前完整 Thread UI 使用 Proto 链；`QuickPreviewUtil` 保留旧 JSON callback symbol，但未发现外部 call site，当前 clipboard preview caller 使用 Proto Flow。
- UNKNOWN：`page=0 + pid`、合法空页、删除/私密/折叠、sort 值域、匿名差异、stale 请求时序。

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
- iOS domain mapper：`SessionValidationResult(accountID, publicProfile, credentialRotation?)`；凭据只交 Keychain writer。
- Fixture 路径：只允许构造的脱敏 mapper fixture；真实认证响应默认不落盘。
- Fixture 获取/生成方式：先形成登录 ADR 与安全 HTTPS 方案；使用专用测试账号，只记录字段存在性/错误类别。
- 已验证行为：Android WebView 回跳和静态组合链。
- UNKNOWN：iOS 允许的登录方式、HTTPS validation、Cookie 轮换、二次验证、取消、过期、重复回调、账号切换。

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

- 用户任务：搜索吧、主题、用户、吧内帖子。
- HTTP method / URL family：GET `https://tieba.baidu.com/mo/q/search/forum|thread|user`；吧内帖子复用 thread query。
- Android 来源文件：`AppHybridTiebaApi.kt`、`SearchForumViewModel.kt`、`SearchThreadViewModel.kt`、`SearchUserViewModel.kt`、`ForumSearchPostViewModel.kt`。
- Android symbol：`searchForumFlow/searchThreadFlow/searchUserFlow/searchPostFlow`。
- 请求构建来源：Retrofit query + 动态 `Referer`；thread 使用 `word/pn/st/tt/rn/fname/ct/is_use_zonghe/cv`。
- 认证要求：接口的 `NO_COMMON_PARAMS` 明确排除 BDUSS/STOKEN query，但 `HYBRID_TIEBA_API` 的 common header / `AddWebCookieInterceptor` 会从当前账户构造 Web Cookie；归为 `optional-in-request`，匿名能力 `UNKNOWN`。
- 请求编码：HTTPS GET query + JSON DTO。
- 请求/响应类型：无 Protobuf；`SearchForumBean/SearchThreadBean/SearchUserBean/SearchPostBean`。
- 分页字段：thread 使用请求 `pn` 与响应 `current_page/has_more`；forum/user UI 当前只取一次。
- 服务端错误字段：DTO 的 `error_code/error` 或 `error_code/error_msg`；类型在不同 DTO 中不一致。
- 关键 headers：动态 `Referer` 含查询词；Hybrid client 加 User-Agent、XHR/fetch headers 和可能含 BDUSS/STOKEN 的 Cookie。`NO_ST_PARAMS/NO_COMMON_PARAMS` 仅为内部控制 header，发送前移除。
- 设备/版本参数：thread query 固定 `cv=99.9.101`；其他自动添加项及最小集合 `UNKNOWN`。
- 敏感字段：查询词、Referer、可选 Cookie/session、搜索结果中的用户内容。
- iOS domain mapper：分别映射 SearchForum/Thread/User item；字符串 ID 必须安全解析，未知/缺失分页字段降级。
- Fixture 路径：`TestSupport/Fixtures/API/Search/Results/`（`NOT_CREATED`）。
- Fixture 获取/生成方式：构造三类成功/空/错误/畸形 DTO 和 thread 重叠页；真实样本仅用白名单公开查询并去身份化。
- 已验证行为：Android 搜索 ViewModel 静态调用 Hybrid HTTPS interface。
- UNKNOWN：Web endpoint 稳定性、cookie 必要性、forum/user 下一页、rate limit、错误 taxonomy、Referer 与 `cv` 是否必需。

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
