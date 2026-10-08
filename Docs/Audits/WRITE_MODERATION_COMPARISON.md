# 发布后删除通知：iOS 参考行为与迁移差异

## 2026-10-07 原生客户端发送组件连通

- NativeTextWriteClient连接已有账号/TBS、业务、Common/签名、HTTP与回执组件，没有调用旧Android账号准备或在失败时回退。四类目标5组完整出站字节对照独立原生组合/IDL样本一致；有效TBS只发1个写请求，缺失时1个TBS成功后才发1个写请求。受控网络用例覆盖取消、并行send拒绝、换账号晚返回、解析后状态回传及格式错误不覆盖旧状态。
- 直接回归发现空body会被SwiftProtobuf解为默认errorCode0；原生实际回放state4且不调用IDL。修client的解码前边界后9项client测试通过；原始失败2项断言保留。8项已有Session回归通过，原生组合样本5组+空body1组再次回放通过。
- Runtime provider仍是接口；实际SDK/账号来源与持久化、文本/图片准备、完整验证和编辑器完成调度未实现。没有切换App Live Repository、安装或自动发送。不能把完整请求的合成对照说成实网抓包，也不能宣称删除原因已确定或整个任务完成。

## 2026-10-07 TBS 普通表单与账号准备续项

- 完成已证实的TBS普通表单签名/编码、JSON解析和NativeWriteSession单次补取接线。真实ARM64动态/签名分支2样本、JSON→完成块22样本；运行时provider和Foundation为合成替身，DB/通知拦截，不是官方App完整执行。26项定向Unit通过，格式修正后12项受影响用例再通过，包含已有TBS复用、单次请求、失败显式重试、取消后晚成功及换账号拒绝旧回包。
- 下层证据纠正此前timeout范围：20秒只是基类初始化值；最终BBA表单由net_type字符串1选择10秒，其他25秒。表单空间%20、保留/和?；普通请求无Proto标记或multipart，JSON任意非零码不能因带tbs而当成功。详见API_EVIDENCE，本轮没有变动Android参考。
- NativeWrite组件仍未接入Live。实际账号/SDK上下文、持久化、富文本/上传与完整发送完成调度未闭合，不能宣称完全对齐或异常删除已解决。正常安装及用户数据保持，无自动发帖/回复/上传/重试。

## 2026-10-07 账号昵称和条件请求头续查

- 继续只以用户提供的iOS22.11.1为主参考。原生profile完成先检查UID，再以非空uNameShow或uName更新昵称缓存；这纠正了“缺失只能空值”的旧推断。NativeWriteSession只更新所属账号/lease内存昵称，保留TBS与进行中操作；原生11样本与12项Unit通过。
- 查明ka来自网络/配置条件，pub_env来自另一独立配置条件；12例原生ARM64回放通过，旧11份fixture未变。NativeWriteHTTPRequest现在接收明确配置并生成对应Cookie头；19项相关Unit通过，包含签名、HTTP和传输单次请求/取消/隔离。没有取全局Cookie或官方App身份。
- TBS请求普通参数模式、20秒默认timeout、合并业务的签名返回已定位，和发帖Proto common-only不能混用。该完整HTTP/账号准备实现及实际运行时provider仍待接通；详情见API_EVIDENCE。Live发送和正常安装保持原样，MODERATION_CAUSE_UNKNOWN未改变。


## 2026-10-07 公共参数构造与状态消费

- 同一22.11.1原生参考现已覆盖静态缓存/重算、动态标准/优化分支、上一请求统计消费及最终签名返回。新增9序列/15步、24例、6例，旧97例未改，统一回放核对通过。参数provider全部显式合成，未取得真实SDK/账号/设备上下文；不能用Android值或固定假标识补足。
- 直接回归抓到两处新组件差异：优化分支空m_api仍需写入；优化签名返回不附标准分支的package_version/实验元数据。按实际ARM64执行修正，最终相关13项Unit通过。原始失败保留于dynamic-common-unit.xcresult、common-transform-red.xcresult，绿色结果common-unit-green.xcresult。
- 完整正常Simulator构建、lint、secret scan、diff check通过。Live发送和安装不变，完整原生账号/provider/验证/上传仍未接通；无自动发布、重试或清数据。MODERATION_CAUSE_UNKNOWN保持，不把局部协议差异当作删除原因。


## 2026-10-07 iOS 签名及回执续查

- 最新明确基准是用户指定的原版衍生iOS22.11.1，Android仅记录旧差异，不用于补齐未知值。已实现原生公共副本/业务合并签名与大写MD5、签名后元数据顺序；5份签名回放通过，签名/原生编码10项Unit通过。
- 原生错误码谓词、UEGPass账号动作及parser状态共55组合成回放通过。原生protobuf解析由请求类型选择；正errorNum才把serverApi设为失败，不以anti/info非空判断失败。新增独立iOS响应descriptor子集/decoder，13份独立wire及最终9项相关Unit通过，具体来源见API_EVIDENCE。未知错误保留，不自动重试或执行验证。
- 原版回复completion0x10231ca9c调用isNetworkRequestSuccessful0x10025fa24，短连接条件包含procState3/serverApi.state3和无model.error；成功路径清对应草稿并交onCompletion。该谓词没有检查pid，但完整UEG/UI/delegate分支仍未执行。新decoder的目标ID关联保护是本客户端边界，不能冒称完整原版成功条件。
- 账号续查只确认TBCAccountModel的BDUSS登录支路、DB用户资料读取、TBS补取和loginSuccessNotification；尚不足以把该遗留模型断言为当前Passport主登录链路。不得直接换成一个新的每次发送登录请求。
- 全部新组件仍未接到Live，Common/SDK/账号来源、富文本/上传和最终回执接线仍不完整。构建/离线测试不证明原版运行环境一致，也不证明异常删除已解决。正常iPhone仍是原beta3对照，无自动发布或重新上传。保持MODERATION_CAUSE_UNKNOWN。

## 2026-10-07 原生最终 HTTP 路径续查

- Proto上传已继续追至实际URLRequest：Tieba的manager选择AF或继承AF的TurboNet；二者复用AF multipart构造。文件段data/data/image/jpeg被传到AF，Proto分支params=nil，无Android额外表单。AF boundary含+；请求头客户端logID省略0/-1。4组原生方法离线回放及18项相关Swift测试通过。
- 新NativeWriteHTTPRequest复用原body编码和NativeWriteTransport；共享builder只开放模块内编码并支持boundary的+。原beta3摘要保留并精确逆向两项许可改动后比对；原完整请求快照通过。尚未接入Live，未改变已安装App。
- 进一步查证NSString.bbaCUID的dispatch_once块0x100056610直接读取BBACuidSDK.cuid；不能把旁支defaultCuid当成已证实主路径。原UA还有真实WebView system UA、版本、skin上下文；本轮没有用固定/复制设备值补齐。
- HTTPDNS/条件Cookie、TurboNet可选头、运行时Common/签名、账号准备、回执与上传仍须完成。Mock单次HTTP出口不证明完整官方运行环境相同，也不证明服务器删除已解决。保持MODERATION_CAUSE_UNKNOWN。


## 2026-10-07 续查：账号状态组件与外层传输边界

- `newGetUserTBS`和响应header提取的12组合成ARM64回放已成为可重放fixture，依赖替身与范围见API_EVIDENCE。原生getter缺失时返回nil并触发后台补取，不是等待login后才返回；TBS补取完成按捕获UID写DB。新增NativeWriteSession只管理已提供账号的内存准备和租约隔离，原生账号持久提供者/HTTP补取仍待接线。NativeWriteTransport不放开全局Cookie，而是逐请求捕获一个指定状态，解析后显式回传到原会话；普通请求/旧Live路径未变。
- 新主题也使用同一状态闭环：`TBCSendThreadModel.handleVerify` 0x10248f288 与 `customHeaders` 0x10248f3f8，已核对调用与key。没有把这些header状态等同于成功回执，也没有复制其他App运行时身份。
- 下层封装继续跟踪：`IDPServerAPI.accessAPI…` 0x1026641b4 在getProtobufRequest非nil时跳过addExtraParams，params保留nil；`bba_requestWithMethod…` 0x1026636e8 把Data按key=data加入files，再进入 `bba_uploadWithMethod…` 0x102663bb4。后者将文件key同时作为fileName/asKey，传给addPartWithFileData…的mimeType是image/jpeg，并设置Retry-Count（无重试标志为0）。这与现有Android外置公共表单字段及filename=file不同。以上是到IDPBBARequest的静态实参证据，尚未证明下层BBANormalAPIRequest/BBABaseAPIRequest到最终URLRequest没有转换，不据此提前切换Live或认定删除原因。
- 继续跟到BBABaseAPIRequest.addPartWithFileData…（0x10460f868）及outlined helper（0x104610e40/4c/58），确认调用setFileMimeType/setFileName/setKey保存上述实参。普通URLRequest构造位于BBAAPIRequestTaskDispatcher.urlRequestForRequest（0x10461e768）；实际默认manager还有BBAAPIRequestManager.urlRequestForRequest（0x10462f63c）、preprocessRequest（0x10462fc44）、dataTaskWithAPIRequest:error（0x10462fe58）待串联，不能在此把最终multipart、拦截器及SDK状态判为已闭合。
- 下层元数据/有界反汇编保存于ignored native-http-classes/native-http-parents与idp-*.asm。未运行官方App、未注入、未发任何Live写请求、未取运行时凭据；SDK/Common/签名和回执闭环未完成，MODERATION_CAUSE_UNKNOWN仍在。


## 2026-10-07 原生构造开始实现，签名层级重新核实

本轮新增独立原生IDL schema、文字业务参数构造、编码器及可重放的纯合成参考执行工具。5个原生业务方法样本和3个独立描述符编码样本可复现，10项Swift定向Unit通过。Live发送链路与安装仍未切换；这些结果不证明SDK、完整HTTP请求、账号生命周期、验证处理或服务端审核一致。

需要纠正此前记录中的一个推断：`TBCServerAPI.getProtobufRequest` (`0x100249d80`) 调公共参数方法时传false。后者在 `0x1024b2fa4` 保存公共字典副本，合并业务参数计算签名，`0x1024b33f0`/`0x1024b3428` 将sign/条件sig放入返回公共字典。CommonReq没有sig；`TBCIDLBaseTransform.initMessageWithDic:message:` (`0x1024dc26c`) 忽略没有descriptor的键，不将其提升到业务层。因而“存在TBCProcEncryption调用”不能直接证明最终请求含业务data.sig。尚需完整发送链路验证，不能据此认定sig缺失导致删帖。当前编码器按显式字段层级工作，测试禁止自动提升公共sig。

工具先核对参考SHA，仅执行选定ARM64方法、拦截所有外部依赖；回复各一次load拦截，无网络/真实账号值。新主题业务 `TBCComposeSendThreadPlugin.sendThreadCommonParams` (`0x1018b4d2c`) 已以明确的纯文字配置执行；CMD309730由 `TBCSendThreadModel.setupConfig` (`0x10248ee4c`) 证实。迁移授权有效，但剩余账号、Common、状态和验证不能用猜值补齐。

### 22.11.1 续查：账号归属、回执分支和 SDK 边界

本次继续沿同一条回复链检查，没有新增阶段或再次试发：

- `fetchTBSWithUId:andBduss:` 的完成块 `0x101c26318–0x101c26428` 在 API state 为 3 时读取顶层 `tbs`，仅非空时调用 `TBCDBService.saveTbsToLogin:tbs:`，账号参数来自请求发起时捕获的 UID，然后发送 TBS 更新通知。配合 `newGetUserTBS` 的账号键/数据库读取，证实它不是每次发帖重新登录。不能把异步完成时的“当前账号”当作结果归属。
- `TBCPbReplayModel.handleParsedData` `0x10245c02c–0x10245c49c` 先交给 `TBCUEGPassManager` 和 `TBCUEGManager`；`doUEGPassWork:sourceVC:` `0x1021fcf10–0x1021fd104` 按 `serverApi.error.userInfo` 中的 `errno`/`errInfo` 分流，包含绑定手机号、身份验证和人脸验证调用。它不能简化为当前 `TextWriteProtocol.decodePost` 中“任意 anti/info 验证字段非空即 verificationRequired”的规则。这是客户端处理差异，不是本次删除原因证据，也不证明原版一定先接受 pid。
- `handleVerifyData` `0x10245c49c–0x10245c5c8` 从实际使用的 BBA/另一 request 取 responseHeaders，经解析后只保存非空字符串到 `svcp_stk`；当前 `URLSessionHTTPClient` 的响应头允许列表直接舍弃 Set-Cookie。参考中这个方法本身没有证明账号隔离/清理规则，不能将其全局缓存照抄为跨账号共享状态。
- 修正分析工具对 UTF-16 CFString 的读取后，核实原版楼中楼正文前缀也是 `回复 #(reply, `；不能将此前未显示的中文字符串当作原版没有此格式。所有查看的正文均为程序静态格式串，没有读取用户正文。
- 沿 `getZInfoWithEvent:` 入口的 ret 跳板到真实目标 `0x100074ff4`，可见 `getOnceTokenWithEvent:`、`SSBusinessHelpTools.getTokenFromInterface`、`createMigrateID:eventID:` 和 `getZInfoDictionaryWithToken:isErrorToken:` 分支。`getTokenFromInterface` 的主体读取实例状态并进入同步/回调逻辑；它不是一个可用空串或静态哈希替代的已还原纯函数。间接分派与完整初始化/更新契约仍未还原，不能把可见 selector 当成已执行路径，更不能认定 SDK 字段必填或是删帖根因。

本轮没有将上述部分差异接入 Live：原生公共上下文、签名、状态更新和验证处理仍未形成可执行的完整契约，单独改匿名值/UA/TBS会留下混合实现。当前生产发送代码、基线摘要、正常 App 安装和全部用户数据保持；未完成修复，不生成可验收候选、不输出 READY。只保存有界静态分析产物，没有执行参考程序、读取官方 App 的运行时凭据或自动发送。

## 2026-10-07 用户指定有效参考，更新主要基准至 22.11.1

用户明确确认给出的去广告包在原版基础上修改、发帖行为正常，并要求 TiebaLite iOS 以其行为为准。**接受它作为功能对照，不以“不是未经修改的 App Store 包”作为继续分析或实现的阻碍，不再要求用户提供不存在的抓包或重复试发。** 最新提供 `/Users/othbradar/Downloads/百度贴吧_22.11.1_iOS睿睿.ipa`，取代22.7.3成为主要基准；旧包保留作交叉对照。这是对发送链路迁移的明确授权，不能继续拿先前beta3冻结规则否定此次授权；当前仍未修改冻结摘要或生产链路。

22.11.1 / 22.11.1.0、bundle com.baidu.tieba，主程序arm64 iPhoneOS、cryptid=0。IPA SHA256 `8b7daae086ef9d3f35cf1ea2004336e09cec83d7ec955d521ebe0d725cba9f15`，TBClient SHA256 `4f0cb74c738f714258dd14bde5fb7a7859ab7baf19183c01e900704ab702d9eb`。只将主程序复制到ignored分析目录，没有展开/执行注入库、安装或修改原IPA。包的修改来源继续如实记载，用户的成功发送反馈为USER_REPORTED，两者不矛盾。

本轮核对结果：

- 22.11.1回复模型 `TBCPbReplayModel.postPBContentAndFloor…` 起点 `0x10245d3dc`，仍写anonymous字符串0；业务tbs写入`0x10245d86c`。新版仍使用账号存储的TBS；缺失补取方法`TBCAccountSettings.fetchTBSWithUId:andBduss:` `0x101c2615c` 使用`https://tiebac.baidu.com/c/s/tbs`。22.7.3的同方法`0x101c0fa1c`已交叉核对，不再将这部分简单记为“未知接口”。这不是任意替换当前login端点，还需接通账号元数据的取得/更新生命周期。
- 新版Common参数构造`0x1024b1e74`、iOS client type、额外sig调用、响应状态保存`0x10245c49c`、Set-Cookie解析`0x1024769ec`及后续svcp_stk请求头`0x10245ea04`保留前版相同行为。最早回复模型服务对象在旧版TBCBaseModel.init `0x100246d84`使用HTTPS tiebac主机；已确认基础主机，最终配置/DNS分支不在此处一概断言。
- 从新版独立读取请求descriptor：AddPost偏移`0xa6ec6f4`/1706 bytes，有80个业务字段；Common所在client.proto偏移`0xa6ef2fc`/151219 bytes，有87个Common字段。相较22.7.3，现有AddPost字段名/编号/类型无变化；新增`send_from #80 string`，业务构造`0x10245e6d4`读取replyStatScene后写入。不能复制一个固定来源值覆盖所有入口。
- 已从Objective-C category定位到更具体的公共上下文来源：NSString.SSDK_zid `0x10024ac80` 调 `SSDKLib.sharedInstance/getZInfoWithEvent:`；后者`0x100074fa4`。SDK暴露`startSDKEngineWithCUID:hostAppCUID:appKey:secretKey:ZInfoReadyHandler:` `0x100072b0c`。defaultCuid `0x1022bfdfc`也有自己的持久值/配置来源；不是把iPhone型号或随机UUID填进去就相同。仅记录符号/调用，没有提取嵌入的接入密钥、现有token或设备身份。
- 公共参数仅在SSDK返回非空字符串时附加z_id，因此**没有证据说它必填或是这次删帖的根因**。但实现“与参考完全一致”需要考虑这个provider的正常、有值/无值和就绪状态，不能把“本实现没有SDK”当成已经等价于参考的空值分支。SDK初始化/就绪与服务端验证处理尚未完成可移植契约，不能声称完整迁移或风控修复。

主要产物：ignored `Artifacts/VisualReview/U08/official-ios-22.11.1/alignment-proof.json`、有界方法反汇编、provider调用记录和native-request-schema.json。22.7.3追加TBS端点/基类主机/网络调用链证据；初次类方法检索遇无methods键已改为可选读取，SDK方法的线性反汇编遇控制流跳板不能推导完整实现，未把空调用输出当作没有依赖。

下一实现范围已明确为同一写入Repository下的原生账号准备、公共上下文、请求/回执及返回状态接线，不建立第二套生产发送器，不改视觉/草稿/阅读恢复；只有参考中有证据的行为才能进入候选。现阶段普通构造及provider边界已确认，完整原生链路仍未实现；不会把文档/Mock通过包装成“已完全对齐”。本轮无生产改动/新候选/Live写入，检查结果见TASK_STATE顶部。

## 2026-10-07 用户提供 22.7.3 解包：发送构造的具体差异

本节是最新证据，更新下方“安装包路径待回复”的状态。用户提供的目录为 `/Users/othbradar/PycharmProjects/ipa及apk等制作/ipa制作/贴吧去广告`；只读取其中 `百度贴吧_22.7.3-最终v6安全优化解包/Payload/TBClient.app` 的程序、版本元数据及制作记录，没有执行程序/注入库或访问官方 App 的数据容器。它是**含去广告注入的官方衍生包**，不能称为已验证的原始 App Store 二进制。

- `TBClient`：22.7.3 / 22.7.3.0，arm64、iPhoneOS、cryptid=0，SHA256 `67867b7abaa8fbdf1a754038325f20431ad07f60be8afe35de088f51704c03c0`，与同目录制作记录相符。包内有 AdBlocker / AdBlockerCore；有限字符串检索未发现发布端点，不等于证明它们不会影响运行时网络。22.11.1 未分析。
- 方法元数据和有界反汇编均直接来自该文件，以下地址为未加 ASLR 的虚拟地址。`read_macho.py` 用 Capstone、Objective-C selector/stub、单跳 branch thunk 和 LC_FUNCTION_STARTS 限定方法；辅助工具不是生产依赖。完整本地产物与摘要见 ignored `Artifacts/VisualReview/U08/official-ios-comparison/static-proof.json`。

| 环节 | 22.7.3 包内静态证据 | 当前 beta3 发送链路 | 结论边界 |
| --- | --- | --- | --- |
| 回复入口 | TBCReplyViewController.setupModel `0x1022da8f0` 创建 TBCPbReplayModel；postReplyInfo → sendMsgHandler → postPBContentAndFloor | TextComposerStore → LiveTextWriteRepository | 已追到业务请求模型，不用界面截图推断网络 |
| 路径/编码 | 模型 init `0x1023aa0f4`：`/c/c/post/add`，Proto CMD 309731；useProto 读取 `ios_thread_proto_switch`（getter `0x101cac22c`） | 同路径、CMD；固定走 Protobuf | 存在配置分支，手机当次开关值未知；主机选路和所有传输选项尚未完成动态核对 |
| anonymous | postPBContentAndFloor `0x1023ab750` 向业务字典写字符串 `0` | data.anonymous=`1` | 是初始赋值差异；末尾还有附加参数合并，不能由字段名断言匿名语义或删帖因果 |
| 账号/TBS | `0x1023ab914` 调 sharedSettings.getUserTBS，写业务 `tbs`；newGetUserTBS `0x101c0eda8` 读用户 KV/数据库，缺失分支可 fetchTBSWithUId:andBduss: | 每次 `/c/s/login` + 公开显示名读取；只设 common.tbs，未设 data.tbs | 账号来源/准备时机不同；不是“官方发送前永不请求”，也不提取或复制现有账号值 |
| 客户端类型/UA | commonStaticParameters `0x10024844c` 及 New `0x1023feba0` 初始 `_client_type=1`，版本来自 tbcClientVersion；UA 由 TBCUserAgentGenerator `0x10025b528` 读取/构造 | clientType 2、固定 Android 12.35.1.0 回复 UA；账号准备11.10.8.6、新主题mini7.2.0.0 | 不是完整 iOS 上下文；不把静态版本号冒充当前设备身份 |
| 参数与签名范围 | addExtraParamsWithIsContaintRequestParams `0x1023ff750`：`0x102400880` 后将 reqParams 合入签名输入，再排序、调用 key provider/MD5；needSig `0x10243df70` 名单含 post/add 和 thread/add，之后调用 toString 生成 sig | 外层非文件字段签名；业务 data.sig/common.sign 未赋值 | 不是同一构造契约；未提取嵌入密钥，也未验证所需运行时参数的来源/取值 |
| Proto 和 multipart | getProtobufRequest `0x10024831c` 拷贝 reqParams，加入 common 后包为 data；encodeMsg `0x102422cc8` 按 CMD 选 IDL；BBA upload `0x1025e7bd0` 设置 multipart 并添加文件 part | 外层字段 + 单 data 文件 part | 结构同类不代表完整请求逐字节相等；没有官方实际请求样本 |
| 响应状态回传 | handleVerifyData `0x1023aa5a4` 调 parser `0x1023c4810` 从 Set-Cookie 取 `__ymg_scsc`，非空时存 svcp_stk；customHeaders `0x1023ac9ec` 在有缓存时加同名 header | HTTPClient 响应头白名单丢弃 Set-Cookie；没有该读写接线 | 明确缺失服务端状态闭环；未读取 token 值，未确认其在本次成功/失败请求中是否存在 |
| 新主题 | 包内含 addThread/addThreadReq.proto 原生消息定义 | Mini 表单发布 | 只确认 schema 存在；本轮不将新主题/图片/楼中楼全部宣称已对齐 |

Protobuf 描述符独立提取：AddPost 请求 descriptor 文件偏移 `0xa59918c`、1687 bytes；Common 所在 client.proto 偏移 `0xa59bcd2`、146507 bytes。与本地生成代码 decoder 按编号和标量类型比较，AddPost 现有67项、Common现有45项全部对应、0类型冲突；官方分别有79/85项。新增字段的存在不代表普通回复全部必填。只保存静态 schema/比较结果，不复制生产生成代码、不更改 schema 或私自填充缺省字段。

**当前结论**：beta3 的 Android 路径确实不等同于此 iOS 实现。已经发现可定位的构造/状态差异，仍没有能够把其中某一项和服务端后续删除直接关联的证据，也没有完成官方 iOS 的账号上下文及动态分支契约。因此不做匿名值/UA等单字段试发补丁，不声称“完全对齐”，不制作或安装新发送候选。下一实施前置是确认实际选路、必要上下文来源与受支持的验证处理，并用合成输入建立完整请求及返回状态契约；现有静态样本不能替代这些运行证据。无须用户再发测试帖。

本轮仅更新本记录、TASK_STATE、API_EVIDENCE、UNKNOWN；冻结生产链路和用户数据未变，不新增动画、手势、overlay、依赖。没有 Live 发布/上传/重试，也没有操作申诉链接。工具过程中的 class JSON 顶层类型/空 decoder 正则、过短 descriptor 边界及有界 disassembly 方法边界问题均已纠正；LLVM disassembly 超时改用 bounded Capstone，原辅助失败不作为产品失败或通过。检查结果见 TASK_STATE 顶部；状态 `OFFICIAL_IOS_STATIC_DIFFERENCES_CONFIRMED / RUNTIME_CONTRACT_INCOMPLETE / MODERATION_CAUSE_UNKNOWN`。

## 2026-10-07 最新复验：纯 beta3 仍失败，转查官方 iOS 证据

USER_REPORTED：在同一正常 iPhone Simulator 覆盖完整、未修改的 beta3 后仍收到异常行为删除；手机 TiebaLite 也开始失败。同一账号在官方 iOS 百度贴吧近期能发且没有随后删除。此前“手机 beta3 仍可用”只属于当时结果，不能继续当作当前对照。此结果支持优先检查客户端链路差异，但没有隔离内容、时间、网络及会话条件，不能据此确定某个参数、模拟器或账号状态是删除原因。

本轮用户明确要求调查并对齐官方 iOS；不是继续叠加 beta3 补丁。当前源码仍为已冻结的 Android 参考路径，不能将“与 beta3 相同”写成“与官方 iOS 相同”。本轮未修改任何生产代码、冻结摘要或安装包。

| 对照环节 | 当前 TiebaLite 源码事实 | 官方 iOS 证据状态 |
| --- | --- | --- |
| 账号准备 | TextWriteAccountProtocol：Android 11.10.8.6 表单账号资料，再读取公开显示名 | 当前官方请求顺序、会话刷新规则未知 |
| 主题/楼层/楼中楼回复 | TextWriteProtocol：Android 12.35.1.0，clientType 2，multipart 内 AddPost Protobuf | 当前官方 endpoint、编码、客户端字段及签名来源未知；不能只换 UA 或版本号 |
| 新主题 | TextWriteProtocol：Android 7.2.0.0 的 mini 表单路径 | 当前官方发新主题与回复是否复用链路未知 |
| 传输和次数 | URLSessionHTTPClient：ephemeral、无自动 Cookie；Repository 每次账号资料→显示名→一次写入，无应用层重试 | 没有官方同次请求样本，不能把本地 Mock 次数当作官方次数 |
| 账号/设备安全 | 当前代码没有实现官方 iOS 的设备或安全 SDK 协议 | 官方隐私政策说明使用百度账号、百度安全等组件及设备/登录环境信息；未公开发帖逐字段协议，不能证明本次删除由缺少某字段导致 |
| 已安装对照版本 | 正常 Simulator 仍为上一轮用户批准的纯 beta3；本轮未覆盖 | 连接 iPhone 的 App 元数据显示 com.baidu.tieba 22.11.1、另一 bundle com.baidu.tieba3 22.7.3；用户确认两个版本均能正常发送，不访问两者用户数据 |

公开来源（本轮读取）：[百度贴吧 App Store](https://apps.apple.com/cn/app/id477927812)、[官方隐私政策](https://tieba.baidu.com/tb/mobile/wisemainstatic/secretright.html)的内部组件说明及 1.13、[官方开放 API 介绍](https://tieba.baidu.com/tb/zt/tiebaapi/index.html)、[SDK 合作介绍](https://c.tieba.baidu.com/c/s/download/pc?src=webtb&t=7)。后两页提供合作/能力介绍，未提供当前原生 iOS 发帖实现；第三方开源客户端不是官方 iOS 协议证据。隐私政策通过独立无登录 Chrome/jshook 再核实，只读取公开页面，不拦截用户流量。

当前设备工具只能查询应用元数据；`devicectl device info files --help` 没有 App bundle 读取域，不能据配对连接就声称已经读取官方二进制或抓到请求。用户已确认两个版本均可正常发送；现成官方安装包/脱敏记录路径仍待回复。后续只比较有来源的请求顺序、字段名/类型、公开常量、编码和回执规则；凭证、设备标识、正文不进入记录，不复制另一 App 的运行时身份，不根据政策猜验证参数。不要求为取证重复发帖。

状态：`OFFICIAL_IOS_EVIDENCE_NEEDED / MODERATION_CAUSE_UNKNOWN`。`make write-baseline-check` 23 项通过；仅证明冻结链路未变，不证明发布留存正常。没有新增动画、手势、overlay、依赖或 Live 写请求。

## 2026-10-07 当前决定：发送链路完整恢复 beta3

用户明确要求与手机已确认可用的 `v0.2.0beta3` 完全对齐。本节覆盖下方 U08 历史方案；不再只对齐出站 Accept。基线提交 `4534020d509ea0188dced53cf582fcc775dbb71e`。

- 已恢复 Endpoint/Builder/TextWriteProtocol 完整文件：请求 Accept 与响应 MIME 使用旧版同一集合，AddPost 只接受原两种 MIME；验证码相关字段先于 error/pid/tid 的原判断顺序完整恢复。此前 MIME 扩展和成功优先均已撤回。因此旧版对 application/protobuf 的“结果未知”和附带验证字段提示也可能重新出现；不能私自兼容后仍声称完全一致。
- 发送成功的原顺序：清对应草稿 → 记录回执 → 收起编辑器 → sheet didDismiss 执行一次回调。帖子用原 reload，楼中楼用原 refresh；均按原 U03 当前阅读页机制保留已加载范围/锚点。撤回 U08 的 target 回调、lastReplyReceipt、父楼/末页选择、dirtyPages 和成功后追读新页；没有额外同页读/轮询/重发。
- TextComposerStore 发送主体、TextComposerService present/didDismiss、账号准备、签名/编码、四类目标、上传、网络和 Session 的既有代码与 beta3 对照一致。保留 U08 本地草稿落盘及图片文件所有权、草稿恢复就绪门槛、账户隔离清理；不将这些明确的本地存储差异或 U07 已验收外观说成全 App 字节一致。账号变化新增的强制关闭编辑器已撤回。
- Specs/WRITE_BASELINE.json 固定 beta3 源码/接线摘要；make write-baseline-check 纳入 lint。AGENTS.md 禁止今后未经新的明确授权改变这条链路或更新基线。没有任何 Live 发送、上传、重发或审核探测。源码/Mock 通过不证明服务端删帖原因已解决，MODERATION_CAUSE_UNKNOWN 保留。


### 当前逐项核对结果

| 环节 | 与 beta3 的差异及处理 |
| --- | --- |
| 四类目标与正文、表情、收件人编码 | TextComposeTargets / ThreadComposeTarget / TextWriteProtocol 基线一致；四类完整请求冻结快照一致 |
| 账号准备与发送顺序 | LiveTextWriteRepository / TextWriteAccountProtocol 一致；账号资料 → 显示名 → 一次发布，没有新增请求或重试 |
| 参数、签名、multipart、请求头 | 原协议及 Endpoint/Builder 恢复完整文件；撤回 requestAcceptMIMETypes 扩展 |
| 回执 MIME 与判定 | 撤回 application/protobuf 兼容与成功优先；恢复旧版验证码字段优先、错误及 ID 校验 |
| 上传、网络、Session | 上传两文件与基线一致；网络/Session/生成协议 242 个源码文件逐字节无差异 |
| Composer 发起/重复点击/取消/完成 | Store 发送主体、Service present/didDismiss 原代码一致；恢复原 presentation modifier 与成功处理块，取消新增账号变化强制关闭 |
| 发成功后的帖子/楼中楼读取 | 恢复原 reload / refresh 接线及 Store 全文件；不再传 target 选父楼/尾页，不再追读 |
| 阅读缓存 | 恢复 beta3 CachedReadingRepository/ReadingContentCache，全 U03/U04 缓存保留；移除 U08 dirtyPages。现有 JSON 多余字段可忽略，不迁移/清空数据 |
| 明确保留的本地差异 | U08 草稿异步恢复、持久保存、账号 namespace、图片文件所有权；U07 已验收外观/链接。不改变上述发送网络或回执链路 |

源码固定规则为 Specs/WRITE_BASELINE.json（23 项），依赖摘要为 ignored beta3-alignment/dependencies-proof.json。合成请求相等适用于相同输入，不等于不同设备的运行时凭据/环境字节相同，更不是服务器审核结论。

日期：2026-09-25，更新于 2026-09-27。当前状态：`LIVE_REPLY_USER_VERIFIED / MODERATION_RETENTION_PENDING / WRITE_MODERATION_CAUSE_UNKNOWN`。用户已恢复排查；显示名遗漏已修，删除触发原因仍未确认。下列 9 月 25 日审计保留为历史，最新结果见末节。2026-10-07新增Simulator删帖反馈：`MODERATION_CAUSE_UNKNOWN`，不沿用9月单次成功作为当前留存保证。

## 目标与范围

用户报告通过当前应用发布的主题回复收到“涉嫌异常行为”删除通知，要求对照原版发帖/回复实现。只做本地源码与既有证据审计，不重发该内容、不探测审核规则、不读取真实凭据、不模拟客户端验证信息。通知中的申诉/重新提交链接不是自动执行授权。

iOS 基线为 R10 `3744d4b`，当前另有未提交的 Forum 返回手势候选，全部保留。Android 协议参考 `5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`；UI 参考 `c5f1125f42498e49db4e4a9cb66313b8c8a285c7`。使用 tiebalite-api-evidence 技能。未更改 Android reference、应用源码、请求字段或安装包。

## 已确认与尚不能确认

- `USER_REPORTED`：用户收到一条回复的删除通知。足以记录内容被平台删除；不能据此确认整个账号被封禁，也不能单独判定是内容、账号、客户端还是网络环境触发。
- `CODE_EVIDENCE`：本移植是经过裁剪的发布链路，并非 Android 请求上下文的完整实现。R09 的最小字段策略已在 ADR-0027 记为兼容性限制。
- `UNKNOWN`：此次发布的原始响应/即时错误码、平台审核理由、提交与删除间隔、发帖设备、与 Android 同账号操作环境的可比性。本轮没有采集这些信息，不用旧成功截图代替。
- R09/R10 用户确认的回复/图片可见证据仍有效，但仅表示当时接收和展示正常；不能推定后续审核或持续发布可靠。本次通知新增了实际服务端删除风险，不覆盖或改写历史记录。

## 逐项对照

Android 路径下表均相对于 `References/TiebaLite-Android/app/src/main/java/com/huanchengfly/tieba/post/`。源码差异不等于删除原因。

| 项目 | Android 证据 | 当前 iOS | 结论 |
| --- | --- | --- | --- |
| 主题/楼层/楼中楼回复路由 | `api/interfaces/impls/MixedTiebaApiImpl.kt::addPostFlow`、`api/retrofit/interfaces/OfficialProtobufTiebaApi.kt::addPostFlow` | `TextWriteProtocol.descriptor/postRequest` 同一路由、HTTPS、multipart + Protobuf，三类目标 ID 和正文前缀对应 | 未发现把主题回复误送成新帖或楼中楼的差异 |
| 新主题路由 | `MixedTiebaApiImpl.addThreadFlow`、`MiniTiebaApi.addThreadFlow` | 同一表单端点/业务参数，iOS 使用 HTTPS；Android MINI 基址为 HTTP | 是传输差异；用户本次报告的是回复，不能拿新帖的协议差异解释本次删除 |
| 业务显示名 | `MixedTiebaApiImpl.addPostFlow`、`MiniTiebaApi.addThreadFlow` 从账号取显示名 | `TextWriteAccount` 只保存本次 uid/tbs，发布没有传 `name_show` | 确认遗漏；重要性及与删除的因果关系 UNKNOWN |
| 账号资料时机 | `ui/page/reply/ReplyPage.kt:208` 使用传入或现存账号资料；`utils/AccountUtil.kt::fetchAccountFlow` 为独立账号获取流程 | `LiveTextWriteRepository.send` 每次发送前调用资料端点，再发送一次发布请求 | 确认调用序列不同；没有证据认定多一次资料请求触发限制 |
| 客户端公共上下文 | `api/ProtobufRequest.kt::buildCommonRequest`、`RetrofitTiebaApi.OFFICIAL_PROTOBUF_TIEBA_POST_API` 和 `MINI_TIEBA_API` 有平台/安装/时钟/会话及验证相关上下文 | `TextWriteProtocol` 仅包含选定基础字段，不实现 Android 验证初始化；回复没有原版附加 Cookie 上下文 | 明显兼容性缺口。未推断哪些字段是必要项，不提供仿造值或规避审核方案 |
| 默认 User-Agent 与版本 | `api/Utils.kt::getUserAgent` 支持配置覆盖，默认字符串为固定 Android UA；POST 使用单独发布版本 | iOS 使用同一默认串和发布版本；没有 Android 配置覆盖逻辑 | 不能声称默认 UA 或发布版本本身抄错；用户 Android 实际配置未知 |
| 签名及编码 | `CommonParamInterceptor` 后 `SortAndSignInterceptor`，非文件字段排序签名，文件 part 不参与 | R09 修订后已有同类处理；`EndpointRequestBuilder` 编码正文一次 | 本次源码复核未发现先前“缺少外层签名”缺陷复发；没有抓取实际请求，不称字节完全相同 |
| 重复发送/重试 | Android 页面发送中展示进度；发送 intent 走既有 Repository | Store 在首个 await 前置 isSending；有 receipt 后禁止再发；EndpointExecutor/URLSessionHTTPClient 无应用层自动重试循环 | 未发现应用层自动重发路径；不等同于证明用户这次只操作一次，或证明系统网络栈没有内部行为 |
| 返回结果与后续审核 | Android 处理即时服务端错误，成功后关闭编辑器；所查发布路径不查询后续审核状态 | 校验服务端错误、验证码标记与正数 pid/tid，成功后关闭并刷新；未持续查询审核状态 | 双方的即时成功都不是后续审核承诺。此次不能用修改成功判断解决服务端删帖 |

## 本轮验证及改动

- 只读比较锁定的两个 Android commit：ReplyPage/ViewModel、Repository、Proto 请求构造、UA helper、API 配置/声明、公共参数/签名/Cookie 拦截器共11文件相同。MixedTiebaApiImpl 文件整体有其他差异，但 `addPostFlow` 与 `addThreadFlow` 两个完整方法相同。
- 静态提取 AddPost 业务赋值名并与 iOS `data.*` 赋值对照：只有 `name_show` 缺失。该检查不包括动态值、CommonRequest 内层字段或实际 wire，不能冒充完整协议验证。命令 exit0；结果在 ignored `Artifacts/Audits/WriteModeration20260925/source-comparison.json`。
- 阅读现有 R09WriteProtocolTests/R09WriteRepositoryTests/R09ComposerTests：已有请求构造、单次发送、重复点击抑制、凭证租约变化和不确定结果保留草稿等覆盖。本轮未重跑；旧测试通过不能验证平台审核。
- 若干首次读取路径不存在（网络授权器/执行器实际位于 Session/TiebaAPI、R09WriteProtocolTests 位于 R09WriteRepositoryTests.swift、ADR 文件为 ADR-0027-text-composer.md）；通过 rg 定位后读取实际文件。没有因文件名错误得出缺少实现的结论。
- 本轮只新增本审计、补充 API_EVIDENCE 与 TASK_STATE。无生产代码、手势、动画、overlay、依赖变化，无 build/Unit/UI 重跑，无覆盖安装、登录变更或 Live 请求。执行 diff check 与 secret scan，结果记于审计目录。

## 下一步证据门槛

后续 USER_REPORTED：用户确认同一账号在 iOS 官方贴吧和 Android TiebaLite 可以发布，账号未被封禁，只有本客户端现在无法回复。该对照增强了客户端相关问题的判断，但没有提供本次失败提示、即时错误码或相同环境下的服务端原因。

后续进一步确认：用户说点击发送后编辑器一直停留，并明确所有新回复均收到涉嫌异常行为的系统删除通知。记录为服务端删除新回复的用户证据；不再仅因复用了旧通知文本而认为新请求是否到达服务端完全未知。具体发布即时返回、提示未显示的原因和删帖触发条件仍 UNKNOWN。停止仅修按钮/列表刷新的方向，不能用这类 UI 变更宣称解决服务端删除。

Simulator 检查先看到帖子列表，没有发送错误；随后仅打开该页已有草稿，发送按钮可见，未点击发送、未修改草稿。未记录草稿正文或账号凭据。没有抓取 Live 请求，没有修改生产代码或请求字段；现有编辑器收到有效回执后关闭、否则保留草稿的分支只完成源码检查，不能作为本次服务端执行轨迹。

在没有因果证据前，不把显示名遗漏、客户端上下文缺口或网络环境任何一个定为根因，也不通过补造 Android 设备信息或验证数据宣称修复。普通协议缺陷可在独立、可验证的契约范围内纠正；客户端验证能力需要服务方支持的接入方式。

审计完成时未提交、未进入R11。随后用户明确授权提交当前改动并进入R11，且要求本bug暂不修：只提交此已知问题记录，不输出修复通过、不再扩大发布排查。R11不更改发布协议。

## 2026-09-27 用户恢复排查

R13 已按用户验收独立提交 `8aec6e4`。本次范围是已确认的显示名数据链遗漏，预计仅修改 TextWriteAccountProtocol、TextWriteProtocol、LiveTextWriteRepository、对应 Unit/fixture 说明及证据记录；不改 Session、导航、列表或上传系统。已核对 Android `AccountUtil.fetchAccountFlow`：nameShow 来自用户资料，LoginBean.name 不是该字段。最小适配复用现有公开 ProfileProtocol 的原始字段并校验 uid，取值失败阻止发送；不引入新的账号初始化、遥测/验证字段或自动重发。

先跑原 R09 定向基线，再运行“资料→同账号显示名→发送”的失败回归，随后修正并运行相邻 R09/R10/资料测试、lint/build/secret/diff。潜在代价是发送前多一次现有只读资料请求；不以公开展示名称的回退值填充协议字段。`WRITE_MODERATION_CAUSE_UNKNOWN` 保留，没有服务端因果证据，不宣称这一修正解决删帖。实际 Live 发布仍由用户手动完成。

### 本次候选结果

- 明确修正的是业务字段链：TextWriteAccount 原来没有 nameShow，发送器也从未赋值。现在每次发送前复用现有匿名 ProfileProtocol，校验资料用户与本次登录元数据同 uid，仅传原始 nameShow 到 AddPost Proto 和新帖签名表单。没有用登录名/显示回退字符串替代，也没有调整客户端验证、错误判断或重试。新增只读请求失败会保留草稿，属于额外的发送前网络依赖。
- 取消、资料身份不符和读取期间 lease 变化都停止在发布之前；公开资料请求不含登录凭据。既有重复点击抑制、上传成功项复用和有效回执判断不变。无新增手势、动画、overlay 或依赖。
- 基线：原 R09 协议/Repository/Composer 13 项通过。新同账号显示名回归先红（exit65），精确失败为预期资料读取时仍直接进入 `/c/c/post/add`；不是 Live 删帖复现。第一次修后构建因测试引用不存在的 hasNameShow 属性失败，lint 因参数缩进失败；改为断言真实 Proto 字符串及序列化往返、修正缩进，未降低显示名或身份断言。
- 最终 R09/R10 上传与 Composer/资料相关 27 项、30 次参数执行全部通过（display-name-green2.xcresult）；make lint 0/372、make build、make secret-scan、make networking-isolation、make forbidden（0 error / 3 warning groups）、git diff --check 通过。没有运行全量 Unit、make quality 或长 UI 矩阵。原日志与全部失败均保留于 ignored Artifacts/Audits/WriteCompatibility20260927/。
- 首次安装遇到 iPhone Simulator 为 Shutdown（simctl exit149），启动同一设备后重新覆盖安装成功。两台均为完整 Debug Live，无场景参数，主文件和 debug dylib 与候选哈希一致（live-install.json）；未卸载、erase 或清 Keychain，完整 App 的当前账户头像与真实关注吧已显示。
- AI 没有点击发送、上传或重发。当前仅证明业务字段遗漏被纠正，不能证明服务端风控已解决。后续需用户自行检查实际发送结果及审核后的可见性；候选未暂存/提交，不以即时回执或 Mock 通过作为审核成功证据。

### 用户确认本次 Live 回复成功（2026-09-27）

USER_REPORTED + 用户截图：用户明确“这回发成功了”；所附完整 App 截图显示高通吧帖子新增第 3 楼，时间为 2026年9月27日15:45，正文及官方表情正常展示。私人截图仅保存在 ignored `Artifacts/Audits/WriteCompatibility20260927/user-confirmed-live-reply.png`，文档不复制账号名或正文。该证据覆盖这一次实际回复发送及当前可见性，未采集原始响应，不能证明后续不会删除或 name_show 是风控根因；其他写入目标亦未据此扩展为已验证。

状态更新为 LIVE_REPLY_USER_VERIFIED / MODERATION_RETENTION_PENDING。AI 未发送、上传、重发或改动 App；候选代码/安装包与上一轮相同。本轮仅更新审计、API_EVIDENCE、UNKNOWN_BEHAVIORS、TASK_STATE，并执行 git diff --check 与轻量 secret-scan（结果见同目录 user-confirmation-checks.log）；不重复 Unit/build/UI，不暂存、不提交。后续观察是否再收到删除通知，不增加自动轮询。

### 用户批准提交与发布（2026-09-27）

用户明确授权提交此次修复、推送 GitHub 并发布新版 IPA。批准前最后一次 R09 协议/Repository/Composer 定向验证 15 项/18 次执行、0 失败/跳过，make lint（0/372）、make build、make secret-scan、git diff --check 全部通过；日志在 ignored Artifacts/Releases/v0.2.0-beta.1/。未修改候选生产行为或重复长 UI 矩阵。发布说明仅声明已纠正业务字段遗漏和本次用户发送成功，后续服务端审核仍待观察。

### U08 当前 Simulator 与手机 beta3 的对照（2026-10-07）

USER_REPORTED：手机GitHub v0.2.0beta3仍可发送，当前电脑Simulator的回复收到异常行为删除通知。版本基线为4534020d509ea0188dced53cf582fcc775dbb71e；环境与版本同时变化，不能得出单一风控原因。本次不记录正文，不读凭据、不重发、不打开申诉链接。

CODE_EVIDENCE：U08允许application/protobuf响应的同时，由EndpointRequestBuilder隐式改了出站Accept，纠正此前“发送请求没变”的错误说法。AddPost原Accept为application/octet-stream, application/x-protobuf，U08候选多application/protobuf。本轮独立请求Accept与响应校验集合，仅AddPost固定旧请求头；不再次改回执、认证、参数或重试策略。回执判定、成功收起及只读局部刷新此前确实改变；它们并非服务端审核通过证明。

OFFLINE_EVIDENCE：从发布标签提取发送构造代码，以合成账号/正文生成四种目标完整HTTP请求快照（正文存SHA256）。builder、authorizer、User-Agent/边界依赖以及Repository/账号资料/上传/transport在修复前与标签逐文件一致。旧候选红测三种回复仅Accept不同，新主题一致；修后四种目标与冻结快照一致。单次发送/重复点击与结果未知不自动重发测试仍通过。证据在ignored Artifacts/VisualReview/U08/request-compatibility；不保留第二套生产发送器，不把这些快照当成Live流量。

本次只确认请求兼容差异已纠正，服务端删除触发机制与修后留存仍UNKNOWN。没有伪造客户端验证字段，也不要求用户为补诊断样本继续发帖。具体构建、安装和检查结果见TASK_STATE本轮顶部。
