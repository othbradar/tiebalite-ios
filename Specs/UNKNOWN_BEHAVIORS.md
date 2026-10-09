# 未确认行为与安全验证计划

## 2026-10-09 Build15 空Page读取失败修正

Build14的Mock完整页不能代表实际getmypost增量：真实成功读取明确返回空Page，已定位大于零页码校验导致刷新失败。修复将其作为无页码增量合并并独立缓存，不伪造分页元数据；正常页和增量都保留目标存在检查。该只读响应证据不改变发送、SDK/Passport、远程开关或审核留存的既有边界；本轮没有代理发送新内容。

## 2026-10-09 Build14 两项接线更新

普通帖子页成功后的getmypost已接入Live：匹配回执的一次读取、原生普通页面参数与注册默认开关1、列表/同页缓存合并和失效隔离。旧记录“完全未接生产”的状态已被本条取代。搜索34/正文普通链接14已传入现有编辑器；已支持的com.baidu.tieba严格Scheme分支确认保持0，外部HTTPS仍32，不混用iOStbclient的31。没有扩展任意Scheme/广告/推送/商业页面参数，完整楼中楼页保持既有独立刷新。

远程实验覆盖值仍未取得，不能将注册默认1说成官方账号当前实验值；本App无广告daily cache，使用原版明确的缺缓存分支。SDK/Passport继续按用户要求跳过。发送回执/后续读取和入口的离线测试不证明真实账号审核留存；本轮未代理实发，自动读取真实结果仍待用户点击发送后验收。图片其余差异、本轮未涉及的特殊来源和替代网络引擎不扩展。

## 2026-10-09 GIF 局部对齐更新

已核对原版普通GIF分支保留编码数据、严格小于10 MiB、同一分块上传封装，本轮接入选择/草稿/上传预检。用户此前确认的是Build12单张静态图实发，GIF真实发送尚待用户验证；不能互相替代。普通JPEG准备策略仍未与原版完整压缩/原图开关对齐，PNG透明度、原生AIGC元数据重建、提前上传/并发/水印/混排、getmypost生产合并、未知入口和运行配置/替代引擎继续OPEN。SDK/Passport及依赖它的验证续发按用户要求跳过。

2026-10-08 Build12：用户已授权图片，SDK/Passport本轮明确跳过。普通静态JPEG的iOS分块字段/Common签名/HTTP/回执/编辑器接线已实现，验证结果见TASK_STATE；先前“图片延期/全部禁止”是历史状态。仍未对齐：原图/GIF/元数据与完整压缩provider、混排、原版选图后提前上传及主题并发/水印/运行配置。既有App内存限额JPEG策略、点击才上传和失败不自动重发是明确保留的App行为；不能称为图片所有行为一致。getmypost完整provider/选路/合并、其他页面来源及替代引擎仍保留前轮缺口；验证码完成续发未实现。真实上传/发帖留待用户手动验证，服务端审核留存仍UNKNOWN。

## 2026-10-08 Build11 边界更新

用户确认 Build10 评论发送正常。本轮补齐 event_day 的真实系统日期 provider：原生 NSDate/NSDateFormatter + YYYYMMdd 已有明确指令证据，当前 runtime 不再遗漏。它不依赖私有 SDK，不代表其他空 provider 一并解决。Common 缓存/重算的真实远程开关仍未知，保留已声明的 recomputed 试用选择。

搜索/正文内部/Scheme 来源仍需实际入口与完整消息消费链；本轮确认 iOStbclient 与 com.baidu.tieba 分支不能混用，未随意赋14/31/32。getmypost 仍缺基础 PB provider、pb_reply_switch 实际值与生产列表合并；缺配置默认0不能作为运行配置证据。完整 SDK/Passport、挑战完成续发、可配置替代 HTTP 引擎仍 OPEN，图片延期。保留普通成功关闭/刷新，不把本包称为完整对齐或审核留存保证。

## 2026-10-08 Build10 边界更新

默认BBAAFNetworkingRequestManager的HTTP状态分派已确认并通过原生回放：200..<300接受，其他走失败；补齐实测统计，不改变业务成功判定。外部HTTPS帖子入口32→post_from=5已有静态完整传递证据并接入，不能再把所有外链一概记为未知。

仍OPEN：搜索/正文内部/scheme真实来源；BBANSURLSession/Turbo等可配置替代引擎的完整分派；getmypost基础PB provider、实际开关和生产读取/列表合并；验证挑战完成后的续发。以上有独立证据/接线工作，不能全部归因于SDK缺失。安全SDK/CUID/z_id、完整Passport和原版运行配置仍缺TiebaLite自身可用接入资料，用户已答复没有；不复制官方App身份或伪造provider。图片发送按用户前序要求延期。Build10仍为部分对齐文字试用版，不能称完整对齐或保证服务端长期留存。


2026-10-08 当前逐项对齐：已补实际URL加载失败统计（timeout=-2/其他=-1），以及推荐、吧首页、历史、回复通知内容/引用、提及通知的来源传递；未知搜索/外链仍为既有0。取消/换账号不发布统计是本App保护，不冒称原版全局行为。完整HTTP异常分派受AF/BBA引擎选择影响，未凭parser回放统一修改。用户明确没有TiebaLite安全SDK/Passport接入包或应用注册资料；完整SDK/CUID/z_id/配置、Passport及验证完成续发存在外部接入缺口。getmypost生产PB provider/开关/读取合并未完成，图片继续延期。普通回复已由用户多次确认成功，不等于这些缺口或长期审核留存已通过。

2026-10-08 Build7用户确认回复仍成功。新增证据已收窄“畸形响应统计”缺口：原生空body、IDL失败、JSON非字典/缺码记录-3；有效IDL字典缺data仍记录errorNum统计，但不能据此宣布发布成功。现已补对应统计并通过37项定向Unit及1条Mock UI，HTTP/网络失败、全局遥测、SDK/Passport/远程配置、页面来源、验证完成续发和getmypost生产读取合并仍OPEN；图片延期。全部对齐尚未完成。

2026-10-08 Build7续接：用户报告Build6回复仍成功。已查实 svcp_stk 使用IDPCache默认策略2（内存+磁盘），本App补同账号受保护持久化与后台事件清理，保留旧账号格式和本App账号隔离；清理采用原生新建缓存默认3600秒及600秒事件节流，不等于迁移官方远程配置/全局跨账号共享。缓存策略3例、文件修改时间过期边界5例有独立原生回放。写后存储失败不改已解析回执、不重发。私有SDK/Passport、验证恢复、页面入口枚举、PB provider/同步配置/生产定向读取合并仍OPEN，图片仍延期。


2026-10-08 Build6续接：用户报告Build5回复正常，仅记作该次实测，不外推为全部入口或长期留存。已补账号普通表单client_logid及有效账号/TBS JSON回包统计，非零JSON错误码（含负码）、numberAtPath的logid精度规则有原生回放；首次账号准备失败后再换账号也不能带出旧统计。HTTP失败/畸形回包/传输失败的全局统计、SDK/Passport/验证恢复/原生定向读取合并仍OPEN；不改变业务成功判断、刷新或实发次数。图片继续延期。

2026-10-08 实际统计续接：原生写请求已补独立URLSession任务度量，取最后一次networkLoad的头部+正文实际字节和开始到解析前的耗时，按native parser规则进入下一次Common；取消/账号变化/缺payload或畸形响应不发布新统计。范围仅成功传输且可解析的新帖/回复，不包含账号/TBS JSON和网络失败统计，不能说全局生命周期完全一致。完整SDK/Passport、验证恢复、第6项Live页面参数/选择/合并仍OPEN。本轮用户要求IPA测试，交付只能注明上述边界，不能称为完全对齐或审核留存已验证。

2026-10-08 继续对齐与 GitHub 检索：原生 CMD309751 的 PbList 请求/响应及单次读取客户端已实现并通过组件测试，但基础页面 provider、实验选路、Common 实际输入和缓存/列表合并仍未接入 Live。请求中未知复杂 provider 显式拒绝，不用 Android 字段代替。GitHub 中 TiebaPure-iOS 的发送实际使用 Android 参数，另一个 TiebaLite-IOS 未实现回复；本轮未找到可补齐原生 SDK/Passport/验证恢复的对应实现。原成功发送安装保留，图片仍延期。具体证据见 API_EVIDENCE 最新项；不能称第6项或前六项已完成。

2026-10-08 前六项续接：当前源码已补本 App 准备账号/TBS 的受保护跨进程复用、同 UID 原始昵称复用、页面回复总数快照、网络类型/超时、原生语言权重及本地 client_logid；未改已有 UI。旧“只在内存复用”描述是历史候选。新增查实 getmypost CMD309751 使用 PbListReqIdl/PbListResIdl，非同名 GetMyPost；但 PB 基础上下文提供者/实验选路/响应合并尚未接通。第4项的私有 SDK/实际统计、第5项验证完成契约和第6项生产定向读取仍 OPEN，不以部分对齐冒称前六项完成，图片保持延期。

2026-10-08 当前试用版：用户进一步授权先交付参照 iOS 请求的正常 App。文字发送现已接入 NativeLiveTextWriteRepository；账号采用包内明确的 BDUSS 登录支路，系统 UA 在本地空白 WKWebView 获取，无网络/账号注入。原版 SDK/CUID、实际实验配置、完整 Passport/跨进程账号状态、图片上传、验证挑战及 getmypost 专用读取合并仍未对齐；服务端删帖原因仍 UNKNOWN。成功关闭和当前页刷新使用现有已测试行为，不保证跨页新回复立即可见。本版不使用 Android 上传或写入回退。此前“尚未接任何 Live”记录为历史状态。

2026-10-08模拟器续项：用户建议转本机模拟器。已直接核对参考IPA的Info/Mach-O：iPhoneOS、arm64、LC_BUILD_VERSION平台2，非Simulator平台；参考二进制SHA未变。本机正常与隔离测试iPhone Simulator均可用，继续用隔离Simulator验证TiebaLite代码，不将其表述为原版IPA在Simulator运行。回复后读取已追到独立/c/f/pb/getmypost（CMD309751），其参数转换与初始派发门控有16例原生封闭回放和3项Simulator Unit通过。NativeReplyFollowupParameters未接Live；PB原生基础参数提供者、折叠页面legacy分支、完整读取IDL/HTTP、结果合并、实际开关/SDK与账号来源仍UNKNOWN。没有因参数组件通过而宣称发送后立即显示或异常删除已修。

2026-10-08续项：参考iPhone已连接，用户已解锁，指定安装为iOS22.11.1。当前阻碍不再是设备不可用：实际LLDB附加被系统拒绝，Time Profiler未建立采样（设备准备超时）；builtByDeveloper=true不证明可调试，未读取安装包私有凭据或修改签名/安装。已询问现有签名安装工具，以判断独立可调试参考副本的可行性，不要求再发帖。新回复completion到PB/楼中楼handler的静态顺序已追通，PB后续读取受pbMyReplySwitch控制；其运行值及下层请求/合并、楼中楼requestFakeWallData语义、真实SDK/Common和账号提供者仍UNKNOWN。未把编辑器refreshContentFromContext误当帖子刷新，未把成功路径经过UEG管理器误当成功后必需验证。详见API_EVIDENCE本轮节；Live仍未迁移，MODERATION_CAUSE_UNKNOWN保留。

2026-10-07回复正文补充：22.11.1新旧回复编辑器共存，PB入口受isFoldingComment和isExperimentForPBReplyCompose控制。新提交插件第一次正文准备已独立回放并接到NativeTextWriteClient的显式内容分支；没有从目标ID猜实验状态。旧delegate的140单位截断不能盲目搬到新插件。实际用户当次分支、完整附件转换、验证重放及新插件完成回调仍UNKNOWN。参考iPhone本次devicectl为unavailable，本机无frida可执行工具；没有因此读取其他设备的个人数据或声称观察了官方运行状态。

2026-10-07最新发送接线：NativeTextWriteClient已将账号内存状态→按需TBS→业务/Common/签名→HTTP→回执/响应状态连通，并以完整出站字节和请求顺序定向验证；不是App的Live Repository。新增空body保护对齐原生parser，不能让Swift默认Proto消息变成零错误码成功。仍缺实际运行时provider/持久账号、富文本和上传、完整UEG/验证、成功回调/页面刷新以及最终App接线。原生正常onCompletion成功分支通知delegate，校验分支/antiStat也有独立路径；不能把现有正ID关联或任意anti/info存在当作整套完成条件。未改安装，无Live写入，MODERATION_CAUSE_UNKNOWN保持。

2026-10-07最新续项：TBS普通表单签名/编码、最终net_type对应10/25秒timeout、JSON回执与单次准备生命周期已实现并由原生合成样本/相关Unit验证。上一条“最终表单HTTP/JSON未知”已收窄；20秒仅是中间初始化值。实际账号资料来源/持久化、实际Common/SDK provider、完整UEG、富文本/上传与Live Repository接线仍缺失。正常安装未更换，没有自动发帖/上传。仅组件通过不能证明完全对齐或审核通过，MODERATION_CAUSE_UNKNOWN保持。


2026-10-07续项：原生profile昵称UID归属及显示名/登录名回退、网络/配置条件Cookie已用原生合成回放与Swift组件验证。实际资料获取/持久账号准备、TBS表单HTTP/JSON及运行时Common/SDK、完整UEG/上传仍未接好；不把这些已验证组件等同于已切换Live或解决删帖。原TBS“端点未知”已由静态链消除，但完整网络提供者缺口仍在。

2026-10-07最新边界：主要基准始终是用户指定的iOS22.11.1，Android仅作历史差异对照。已补齐有证据的Proto HTTP封装、静态Common缓存/重算、动态Common标准/优化分支及统计消费、公共字典签名作用域/大写MD5、错误码/账号动作谓词与独立原生回执子集解码。新增公共参数只接收显式provider输出，尚未取得实际运行时Common/SDK来源、原生账号持久准备和TBS完整请求；富文本/图片发送、完整UEG与业务完成调度仍未闭合，尚未切换Live。原版completion依据模型error及proc/server state，本地正ID/目标关联保护不能冒充已执行整个原版完成分支。对应定向组件通过不改变MODERATION_CAUSE_UNKNOWN，不要求用户重复试发。

U08原生迁移续项（2026-10-07）：已用封闭ARM64回放核对TBS缓存/DB回退/缺失补取getter及特定Set-Cookie解析；新增单账号内存生命周期和逐请求响应捕获组件。原生账号持久元数据提供者、完整TBS请求common/签名、Live Repository切换及回执/验证调度仍未接好。旧会话拒绝/内存清理是本App约束，原版全局IDPCache清理未证实。旧Live安装/源码发送仍未改变，MODERATION_CAUSE_UNKNOWN不变。


## U08 原生迁移当前边界（2026-10-07）

已实现并定向验证普通文字业务构造及原生IDL编码，具体上下文、来源和样本限制见API_EVIDENCE。尚缺账号TBS/显示名取得与更新接入、实际入口/富文本与上传映射、Common运行时来源及签名发送闭环、响应状态账号隔离、完整回执/验证处理。Live发送与安装未切换，完整行为对齐和删除根因均未确认。

补充修正：共同参数中的条件sig并不能直接证明最终业务data.sig存在；Common schema无此字段，当前IDL转换忽略未知键。独立schema测试的显式sig输入不是原生发送抓包。不得用假设备值/静态SDK替身补齐这些UNKNOWN或据此交付“完全修好”的候选。

最新用户指定（2026-10-07）：接受用户确认发帖正常的去广告版为行为参考；主要基准更新为22.11.1（TBClient SHA256 `4f0cb74c738f714258dd14bde5fb7a7859ab7baf19183c01e900704ab702d9eb`），22.7.3保留对照。用户已明确授权迁移发送行为，不再以旧beta3冻结或无现成抓包作为授权阻碍。已补核实专用TBS端点、原生签名/返回状态、新字段send_from #80及SSDKLib上下文provider边界；详见WRITE_MODERATION_COMPARISON最新节。尚未实现完整原生链路、未确定删帖原因；不把用户成功反馈说成逐字段抓包证据，也不把SDK字段存在说成必填。生产及安装未变。

状态：`OPEN`

Android 静态源码不是服务端或运行时证据。本文件集中记录所有 `UNKNOWN`，防止后续根据字段名、旧客户端实现或模型记忆补全协议。

## 官方 22.7.3 静态差异已确认（2026-10-07）

用户已提供并授权只读分析本机去广告解包；程序哈希、方法地址及分支见 WRITE_MODERATION_COMPARISON 最新节。确认 iOS 初始业务 anonymous=0、业务 tbs/账号缓存来源、iOS 公共参数、业务参与签名、额外 sig 路径和响应头状态回传均与当前 Android 参考链路有差异。AddPost现有67个字段/Common现有45个字段的编号和类型没有发现错位。官方衍生包不等于认证原始包，含注入；22.11.1 未分析。

尚未确认手机当次配置分支、主机选路、完整上下文及验证值生命周期、最终请求/响应和删除触发原因。静态差异不能直接称为根因；不能只补一个常量后要求用户反复试发。现有生产协议/基线摘要/安装不变，没有读取官方账号存储、没有Live写请求。当前 `OFFICIAL_IOS_STATIC_DIFFERENCES_CONFIRMED / RUNTIME_CONTRACT_INCOMPLETE / MODERATION_CAUSE_UNKNOWN`；下节“样本路径待回复”仅保留为前次历史。

## 最新复验：纯 beta3 和手机也失败，官方 iOS 成功（2026-10-07）

用户已完成上次纯 beta3 覆盖后的复验，仍收到异常行为删除，并补充手机 TiebaLite 也失败；同一账号近期在官方 iOS 百度贴吧可以发布且未随后删除。下方“旧版同设备结果待用户操作”和“手机 beta3 可发送”已被此新结果更新。不能再只用 U08 版本差异或 Simulator 解释故障，也不能由此断言账号被封或某个参数触发。

用户明确授权调查/对齐官方 iOS。当前链路仍来自 Android 参考，原始 beta3 的源码相等不能证明官方 iOS 协议相等。官方公开资料说明账号/设备安全处理，但没有当前发帖逐字段协议；已连接 iPhone 安装版本可读，不等于有程序包/请求样本。用户已确认官方22.11.1和22.7.3均能正常发送，现成样本路径待回复，详见 WRITE_MODERATION_COMPARISON 顶部。本轮未改生产发送行为、清数据或再次覆盖，当前状态 `OFFICIAL_IOS_EVIDENCE_NEEDED / MODERATION_CAUSE_UNKNOWN`。

## 前次复验与覆盖记录（2026-10-07，后续结果见上）

用户确认beta3对齐候选在电脑Simulator仍被删除。安装哈希确认是本轮候选；留存原IPA与发布记录摘要相符。新增草稿恢复到URLRequest的离线端到端对照仍相等，没有新证据定位删除原因。未改生产发送代码，不将本地通过记录当作Live留存证据；用户随后批准“覆盖”，纯beta3完整Release Simulator App已安装到原正常iPhone，登录/数据和持久草稿文件保留；尚未由代理执行任何Live发送。旧版同设备结果仍待用户操作，当前状态MODERATION_CAUSE_UNKNOWN。

## 当前发送基线冻结（2026-10-07）

按用户最新授权完整恢复 v0.2.0beta3 的发送、MIME/回执判定、成功关闭及当前页刷新；此前仅 Accept 对齐和后续回执修订均不再作为当前实现。下列 U08 的 MIME/成功优先改动属于已撤回的历史诊断。旧版结果未知/验证提示可能仍出现；服务端删除原因未获证实。本地持久草稿、缓存、已验收视觉保留，禁止后续擅自变更发送链路。

## U08 当前 Simulator 回复被删除（2026-10-07，MODERATION_CAUSE_UNKNOWN）

- 后续用户先确认一次成功并反馈自动刷新未显示，再在增加额外读取的候选中报告同类删除。两次即时可见/删除不能确定服务端因果。上轮额外读取方案现已撤回，自动刷新实网问题与服务端删帖均仍OPEN；禁止基于Mock或前一条即时成功继续声称已修复。

- 用户确认工作旧版为GitHub v0.2.0beta3，当前发送设备为电脑Simulator；手机旧版可发送。无法由此区分版本、设备/环境及服务端审核因素，禁止将删帖归因为某个字段或宣称修好。
- 已证实MIME兼容变更同时改变了出站Accept，纠正此前“请求未变”记录；当前将响应允许集合与请求Accept分离并恢复beta3发送形状。请求构造、签名、上传、认证及一次发送路径已对照；不增加重试、设备/验证数据或实网探测。独立回执解析修复保留，但成功ID仅表示即时回执，不保证后续留存。

## U08 回复已发布但回执未确认（2026-10-07，根因已定位）

- 用户确认服务端回复可见，但编辑器提示发送结果未知。再次手动发送的脱敏诊断显示HTTP200、208 bytes、application/protobuf、有效PB/hasData、pid正数、tid匹配、serverRejected=false；原pipeline=unsupported-content → repository=result-unknown。
- 该次失败根因为回复接口漏收已观察的MIME，而非缺失ID或发送后会话改变。用纯合成pid401/tid101响应复现；仅为write.post补application/protobuf，不修改共享pipeline或放宽回执校验，仍不自动重发。
- 临时诊断仅记录固定类别/布尔/计数，未保存ID值、响应、正文、URL、账号资料或凭据。完成定位后撤除代码，元数据保留于ignored Artifacts。原App内单份元数据不再更新，不清理用户数据。
- 后续用户再次发送后实际出现verificationRequired，但回复已可见。旧decodePost把附带anti/info字段放在error/pid/tid之前检查，违反原版成功回执规则；现按API_EVIDENCE记录调整判定顺序，非零错误/无有效回执仍不能成功。本次原响应未保存，触发的具体字段值仍UNKNOWN，不猜实际vcode_type，不自动发送补样本。新候选的Live关闭/刷新仍待用户确认。

## R11 消息（2026-09-25）

- 回复/提到/未读三个 HTTPS 接口已接入，真实回复、提到空态及准确主楼/楼中楼跳转已观察；旧式 `application/x-javascript` 响应仍按严格 JSON 解码。请求/来源见 API_EVIDENCE.md 的 R11 节。
- 消息 replyer 没有可证实的等级字段，生产保持 nil。`quote_pid` 不用于推测父楼；楼中楼经 PB 的目标子回复定位返回真实父楼。
- 当前 Live 未读为零，读取后非零到零的时点/跨端同步仍 UNKNOWN；客户端只重取服务端计数，无乐观清零。Fixture 覆盖前后读取竞态。
- 当前账号提到页为空，非空样式及长文表情只用隔离 Fixture 补证；真实下一页 wire、删除消息错误 taxonomy 未单独采集。
- 两台正常 App 已保留账号覆盖安装。CUA 无法移动 Live 回复列表，故中部停留和 Live 深滚动尚未确认；两台定向 UI 已验证 Fixture 第二页、标签/根入口/目标页往返位置。详见 Docs/VisualParity/R11_NOTIFICATIONS.md。

## 验证原则

1. 先用构造 fixture 验证 mapper/state，再申请受控 live 验证。
2. 只使用专用测试账号和公开测试内容；不收集用户密码。
3. 抓取前定义字段白名单；落盘前移除 Cookie、BDUSS、STOKEN、TBS、手机号、授权头和可追踪设备 id。
4. 不关闭 TLS、不接受任意证书、不使用明文 HTTP 发送凭据。
5. 一次实验只改变一个变量，并记录 client state、请求类别、脱敏响应 hash 和结果。
6. 任何结论需最少一个可复现 fixture；截图不能代替 wire/state evidence。
7. 验证产物放 `Docs/Audits/` 与 `TestSupport/Fixtures/`，并更新 `Specs/API_EVIDENCE.md`。

## 最高优先级五项

| ID | 证据缺口 | 当前已知 | 最小安全实验 | 升级条件 |
|---|---|---|---|---|
| U-01 | 登录、验证码、Cookie/token 轮换、过期、多账号退出 | 阶段 12 已用可见 WKWebView 完成一次真实登录与 Keychain 重启恢复，携带两个候选字段的 active Personalized 请求成功返回；真实 logout 按用户保留凭证要求未运行，轮换/过期码/多账号仍未知 | 继续只由用户手工验证；logout 后重新登录、rotation、失效和重复回调只记录状态/字段存在性，不记录 token 值 | HTTPS 合法方案 + 脱敏 taxonomy + Session fixture/state tests + 真实 logout/expired evidence |
| U-02 | HTTP endpoint 的安全 HTTPS 等价路径和最小参数 | 关注吧、登录、picpage 当前 call site 是 `http://c.tieba.baidu.com` | 不调用 HTTP；从官方可观察 HTTPS 流或 reference 新 Proto call site寻找候选；单 endpoint、无凭据的公开请求先验证 TLS/编码 | 全程 HTTPS、无降级、最小字段有 evidence、成功/错误 fixture |
| U-03 | FRS dynamic tab 与 `thread_id_list`/page 契约 | 阶段 14P 已验证匿名 FRS `pn=2/load_type=2` 一页下一页；Android client 仍先消费最多 30 ids，再取下一 FRS page | 继续对同一公开吧记录更后页、tab raw fields、ThreadList 请求 ids、返回顺序、空/缺项；匿名与登录分开 | 动态 tab 值域与稳定 id、ThreadList 排序/终止/缺项策略均有 fixture |
| U-04 | PB `page=0+pid`、删除/私密/缺作者及并发 | 阶段 15.6 已对一个公开长帖连续验证 `current_page=1/2/3`、45 个唯一楼层，并确认本样本可以累计排除 pids 后以 Android fallback `pid=0` 继续；删除/私密/倒序/跳楼仍未验证 | 对其他公开长帖验证末页 `has_more=0`、非零 pid anchor、删除楼、升降序；保持脱敏 page/count/fingerprint | 跨主题 anchor/cursor/error taxonomy + 可复现 fixture/stale-response tests |
| U-05 | 推荐匿名能力、顺序、空页与终止条件 | 阶段 15.6 active-session `load_type=2,pn=2` 成功映射 12 项且全部为首屏未见稳定 ID；Fixture/Store 已验证三页去重保序、retained failure 与 generation。响应仍没有终止字段，匿名稳定性仍未证 | 无 session/测试 session 对照公开内容；在 Debug-only 受控 probe 中逐页记录脱敏 count/fingerprint、空页、重复页与错误类别，Production 不设任意固定页帽 | 匿名规则、第三页以后稳定性及服务终止语义有可复现证据 |

## API / 认证

| ID | UNKNOWN | 安全验证方法 |
|---|---|---|
| U-06 | Personalized、FRS、PB、PBFloor 是否真正支持匿名 | FRS 固定公开吧匿名首屏+一页下一页已限定成功；PBPage 对一个公开长帖匿名连续三页成功；Personalized active-session 第二页成功，匿名非空观察仍不可复现；PBFloor 未发出，跨吧/跨帖稳定性继续 `UNKNOWN` |
| U-07 | `CommonRequest`/headers/外层 stoken 的最小必需集合 | 阶段 11 静态字段证明 HTTP/Proto 可达；阶段 12 按 Android evidence 增加 CommonRequest BDUSS/STOKEN 与外层 stoken 后单次成功，但没有逐字段消融，也不证明服务器实际消费 credential，不能称为最小集合；禁止复制 Android telemetry 全集 |
| U-08 | legacy sign 是否仍必需、是否允许 iOS 使用 | 只通过已批准协议/法律审查和 HTTPS 受控验证；在此之前不实现 |
| U-09 | Error.error_code、user_msg、HTTP status 的真实 taxonomy | 为成功、未登录、过期、无权限、删除、限流、服务器错误采脱敏 fixture |
| U-10 | 60 秒 timeout 是否是产品需求 | 使用本地延迟 stub 测 1/5/30/60 秒；最终 timeout 由 iOS UX 决策，不复制 Android |
| U-11 | redirect 是否存在以及是否会在 HTTP body 发送后发生 | 不以真实凭据测试 HTTP；只允许网络文档/无凭据安全探测，且不能据 redirect 解锁 HTTP |
| U-12 | Proto forumGuide 能否等价替代当前 form endpoint | 先找 production call site 或以同账号对比两端脱敏结果/分页；字段齐全才可候选 |

## 分页与顺序

| ID | UNKNOWN | 安全验证方法 |
|---|---|---|
| U-13 | 推荐终止信号 | Response 没有 hasMore/total/cursor；当前空页或 duplicate-only 页停止是受测 client no-progress policy。后续只在 Debug-only 受控 probe 中观察脱敏 count/fingerprint/raw field presence，不在 Production 发明最大页数 |
| U-14 | 推荐刷新应替换还是 `new + old` | 通过产品验收和 fixture 决策；不能以 Android reducer 的插入提示作为唯一依据 |
| U-15 | FRS `thread_id_list` 与 `thread_list`、下一 pn 的重叠/顺序 | 与 U-03 配对，断言 id 序列 |
| U-16 | ThreadList 空响应是终止、删除还是暂时错误 | 构造空/部分缺项；真实公开样本验证一次 |
| U-17 | GeneralTab `pn` 与 `last_thread_id` 冲突时优先级 | 以相同 pn 改 last id、相同 last id 改 pn；每次仅一变量 |
| U-18 | PB `pids` 的方向、request `r` sort 值域及恒定 `floor_sort_type=1` 的语义 | 普通升序已证客户端从 pids 排除累计 postID 并取最后未见正值，无候选时 `pid=0`；其他方向、`r` 值域与 `floor_sort_type` 语义仍用正序/倒序/热序 fixture 对照，保留 raw 字段 |
| U-19 | PB Floor `has_more` 与 `current_page < total_page` 冲突 | 构造四种冲突 fixture，真实样本仅用于确认服务端常态 |
| U-20 | 合法空 post_list | 对已删除/私密/空回复公开可访问样本采脱敏 envelope；未确认前用 unavailable |

## Protobuf / schema

| ID | UNKNOWN | 安全验证方法 |
|---|---|---|
| U-21 | SwiftProtobuf 对 selected schema 的生成 API | `CLOSED_FOR_CURRENT_EIGHT_ROOT_LOCAL`：1.38.1 runtime/generator、Personalized/PBPage/ForumGuide/FRS/Profile 八 root、207-file manifest/hash、两次生成与 strict build 已验证；其他 closure 仍 open |
| U-22 | proto3 optional absent 与显式 0/空字符串 | `LOCAL_WIRE_VERIFIED`：AppPos optional false 与 absent bytes/presence 已测；服务端差异仍属 U-07 |
| U-23 | 未知 tag 是否解码后可 round-trip 保留 | `LOCAL_WIRE_VERIFIED`：Personalized 顶层 field 2047 decode/re-encode/decode 保留；live server 行为不在结论内 |
| U-24 | 裸 int 状态/排序/type 完整值域 | 累积多 fixture，领域类型始终保留 `.unknown(raw)` |
| U-25 | 321 个 schema 中已选 endpoint 真正最小闭包 | `CLOSED_FOR_CURRENT_SELECTED_ROOTS_LOCAL`：Personalized 51、PBPage 125、ForumGuide 58、FRS 74、Profile request/response union 105，当前八-root union 207；ThreadList/PBFloor 等仍 open |
| U-26 | schema 复用的许可证/分发后果 | `PARTIAL_PUBLIC_POLICY`：项目负责人已批准公开当前仓库，并以 `GPL-3.0-only` 许可其有权许可的原创 iOS 代码；207-file union 的文件级 provenance/第三方权利仍 `UNKNOWN`，公开行为不构成权利证据，App Store 与商业二进制分发仍未清权 |

阶段 07 local closure record：

```text
ID：U-21/U-22/U-23/U-25；U-26 仅局部决策
日期：2026-07-31
Android build 与 commit：4.0-dev / 5545326b2a8e0d784b2f3dfbcb219c7b121e61c2
iOS baseline：11768dd4b1416619ea396c12cf97616546cccad1（阶段 07 checkpoint）
scenario：pinned Personalized 51-file generation + JVM→Swift fixture decode/map
请求类别：未发送网络请求；constructed anonymous/evidence-only request bytes
fixture：TestSupport/Fixtures/API/Recommendations/personalized_cross_language.pb
SHA-256：54a838f8bd05c39e90b84b3bba4d4224dc81fe11b63934e23dd65be937eebb4a
观察结果：两次 Proto generation、两次 JVM fixture generation 均逐字节一致；
  optional false presence 与 absent 不同；unknown field 2047 round-trip 保留；
  raw threadTypes=999 保留；schema enum count=0。
与现有规格的差异：不再是“无 plugin/lock/schema”；只关闭 Personalized local
  tooling/wire 子集，匿名 live、服务端 presence、其他 P0 和公开分发不变。
新增测试：PersonalizedProtocolTests 全组；verify-protos；
  verify-personalized-fixture；networking-isolation。
结论标签：LOCAL_BUILD_EVIDENCE / CROSS_LANGUAGE_GENERATED；非 RUNTIME_EVIDENCE
```

阶段 11 local closure 与受控运行观察：

```text
ID：U-05/U-06/U-07（保持 OPEN）；U-21/U-25 扩展本地关闭范围；U-26 仍局部决策
日期：2026-08-04
Android build 与 commit：4.0-dev / 5545326b2a8e0d784b2f3dfbcb219c7b121e61c2
iOS baseline：302b7b8fb34a8da3e1171e6bc5dc48afe548494e（阶段 10 完成提交）
scenario：pinned Personalized + PBPage 三-root/126-file generation；Debug-only、
  无 session 的 Personalized 单页 Probe；有正 route ID 才允许链式 PBPage Probe
请求类别：HTTPS multipart protobuf；不含 Cookie、BDUSS、STOKEN、Keychain、
  AppPos、安装标识或设备标识；没有循环重试
fixture：没有保存 live response 或正文；PBPage mapper 使用完全合成的 Swift
  Proto response，因此不满足关闭 runtime UNKNOWN 的 fixture 条件
观察结果：Personalized HTTP 200、application/octet-stream、Proto 可解码；一次
  早期组合为 5550 bytes/67 mapped items，最终 evidence-locked 请求为 245 bytes/
  0 item/171 ms。最终结果没有正 threadID，PBPage Probe 按设计未发出。
与现有规格的差异：证明 transport/decode 的受控可达性，但没有证明稳定匿名
  推荐、最小字段、分页/终止、错误 taxonomy、canonical identity 或匿名 PBPage。
  Production 推荐和 ThreadReader 因此均 fail closed；Fixture 主链路保持离线可用。
新增测试：Stage11LiveRecommendationTests、Stage11PBPageProtocolTests、
  Stage11LiveCompositionTests，以及 Store request generation/cancellation tests。
结论标签：RUNTIME_OBSERVATION / LOCAL_SYNTHETIC_TESTED；非可复现 RUNTIME_EVIDENCE
```

阶段 12 可见登录与 active Session Personalized 观察：

```text
ID：U-01/U-05/U-06/U-07/U-09/U-35/U-37（全部保持 OPEN 或 PARTIAL）
日期：2026-08-04
Android build 与 commit：4.0-dev / 5545326b2a8e0d784b2f3dfbcb219c7b121e61c2
iOS baseline：2221793302250edcd0cdde591b0f92dfbc22db46（阶段 11 partial 提交）
scenario：用户在可见 WKWebView 手工登录；本机签名 iPhone Simulator 构建
  写入候选 Session、终止进程并从 Keychain 恢复；显式运行一次携带 active
  Session candidate 的 Personalized Debug Probe
请求类别：HTTPS multipart protobuf；matching active lease 授权；只发送 Android
  已证的 CommonRequest BDUSS/STOKEN 与外层 stoken，不发送密码、TBS、完整
  Cookie header、AppPos、安装标识或设备标识；没有循环重试
fixture：没有保存 live response、请求体、用户内容或 credential；自动化只用
  FakeSession、MockHTTPClient 和合成 Proto
观察结果：登录后与进程重启后均显示 signedIn；Probe 为 HTTP 200、
  application/octet-stream、83924 bytes、Proto decode 成功、12 mapped items、
  outcome=success。按用户保留凭证要求，真实 logout 未执行。
与现有规格的差异：关闭本机 Beta 可见登录与 Keychain save/load 的运行缺口，
  证明客户端可在 matching lease 下构造并完成携带候选字段的一页请求；不证明
  服务器实际消费 credential、字段最小性、rotation、expired taxonomy、真实
  logout、PBPage、关注吧或 Production live-ready。
新增测试：Stage12SessionTests、Stage12SessionCleanupTests 以及登录 URL/port、
  active request、lease、redaction、replacement、cleanup 和 Fixture isolation 回归。
结论标签：ACTIVE_SESSION_RUNTIME_OBSERVATION / LOCAL_BETA；非可复现 server fixture
```

阶段 14 FRS 本地闭包与匿名首屏观察：

```text
ID：U-03/U-06/U-09/U-15 保持 PARTIAL/OPEN；U-21/U-25 扩展本地关闭范围；
  U-26 仍局部决策
日期：2026-08-05
Android build 与 commit：4.0-dev / 5545326b2a8e0d784b2f3dfbcb219c7b121e61c2
iOS baseline：b6090a19c95fb720f24415975dc43e7729cae1df（阶段 13 提交）
scenario：pinned FRS root/74-file closure，与既有集合形成六-root/156-file
  generation；固定公开测试吧的 Debug-only 匿名首屏 Probe
请求类别：HTTPS multipart protobuf；无 Cookie、BDUSS、STOKEN、Keychain、
  AppPos、屏幕、安装或设备标识；没有循环重试
fixture：TestSupport/Fixtures/API/ForumHome/frs_page_synthetic.pb；454 bytes；
  SHA-256 940d1df7631795791eccde105a7cb4dcbf3f38d465a8ebf9bac6af4c850887b0；
  完全合成，不是 live capture
观察结果：无凭证 iPhone 与测试 iPad 均 HTTP 200、application/octet-stream、
  54068 bytes、Proto decode 成功、13 mapped threads、outcome=success；未保存
  response body 或内容
与现有规格的差异：只关闭固定公开吧匿名 FRS 首屏的 transport/decode/map；
  动态 tab、ThreadList、分页、跨吧稳定性、限流和错误 taxonomy 不变
新增测试：Stage14ForumHomeTests、ForumHomeSmokeTests、iPad AppShell Forum smoke、
  156-file generate/network/UI isolation gates
结论标签：LIMITED_RUNTIME_EVIDENCE / LOCAL_SYNTHETIC_TESTED；非 live fixture
```

阶段 14P FRS 顺序分页观察：

```text
ID：U-03/U-06/U-09/U-15 仍为 PARTIAL/OPEN
日期：2026-08-09
Android API build 与 commit：4.0-dev / 5545326b2a8e0d784b2f3dfbcb219c7b121e61c2
最新 UI 参考：4.0-dev / 268f388c7824ae2c8f6ed549827a943ec8a7f352
scenario：无凭证 Debug-only Probe，首屏 has_more 为真时单次请求
  FRS pn=2/load_type=2；无循环重试
观察结果：HTTP 200、application/octet-stream、156269 bytes、
  Proto decode 成功；首屏 13 条，追加 30 条后聚合 43 条，
  typed-error=none、outcome=success
隐私：未保存 response body、请求体、Cookie、吧/帖子/用户内容
与现有规格的差异：只关闭顺序 FRS 一页下一页的 transport/
  decode/map；第三页以后、thread_id_list + ThreadList、dynamic tab、
  sort、限流和错误 taxonomy 不变
结论标签：LIMITED_RUNTIME_EVIDENCE；非 live fixture
```

## 内容节点

| ID | UNKNOWN | 安全验证方法 |
|---|---|---|
| U-27 | raw type 9/27/35/40 原始语义 | 收集脱敏样本并比较相邻字段；在此之前只按当前 Android 文本行为渲染并保留 raw type |
| U-28 | `memeInfo` 的产品语义 | 构造 meme-only fixture；真实样本出现前保持 UnsupportedNode |
| U-29 | 未见 raw type 的分布 | 只记录 raw type 频次和字段存在性，不保存私密正文 |
| U-30 | 图片 URL 候选顺序与 HTTPS 可用性 | 对同一公开图片逐候选 HEAD/GET 的安全验证需后续授权；不放宽 ATS |
| U-31 | type 5 的 video/link 字段稳定性 | 正常/缺 src/坏 URL fixture；P0 保持安全降级 |
| U-32 | voice endpoint、格式、时长单位 | 不自动请求；取得公开样本和 HTTPS evidence 后再进入 P1 |
| U-33 | Poll type/status、匿名/已投/过期 UI | 构造全部 raw 状态；真实样本只验证展示，不执行投票 |
| U-34 | 删除/折叠/私密楼层的 wire 形态 | 与 U-20 配对；所有未知形态降级为 UnavailablePost |

## Session / 存储

| ID | UNKNOWN | 安全验证方法 |
|---|---|---|
| U-35 | iOS 登录方式与 App Store/平台边界 | `CLOSED_FOR_LOCAL_BETA`：ADR-0014 选择可见、first-party HTTPS WKWebView，不做 DOM/密码注入；App Store、服务条款和发布级隐私审计仍 OPEN |
| U-36 | 启动 refresh 失败时是否仍可浏览公开内容 | fixture session adapter + offline UI test |
| U-37 | Session commit/退出需清哪些 Cookie/Web data/cache | `PARTIAL_LOCAL_BETA`：当前撤销 lease、删除单一 Keychain item、清 App-owned nonpersistent WebKit store，并有失败/重试测试；真实 logout 按保留凭证要求未运行。cache aggregate、journal/ledger、midpoint crash recovery 与 Safari/系统浏览器数据继续 OPEN |
| U-38 | 多账号是否进入首版 | 产品决策；若无则模型仍须拒绝第二 session 并安全替换 |
| U-39 | Account User message 中哪些字段可持久化 | public profile 白名单评审；默认不保存未知字段 |

## 导航 / 交互 / 恢复

| ID | UNKNOWN | 安全验证方法 |
|---|---|---|
| U-40 | ADR-0003 已选择的 versioned route/safe-state snapshot 在进程死亡后的真实恢复正确性 | fixture App：各 Tab push 两层、设置 filter/anchor、终止进程再启动；验证最长合法前缀与排除 media/auth/session |
| U-41 | ADR-0003 已选择的当前 Tab 重选 no-op 在系统 Tab/VoiceOver 下是否始终无副作用 | UI test 重选 root/子页各 20 次，断言 path、anchor、请求数和可访问焦点不变 |
| U-42 | iPad sidebar/split collapse 后 route 恢复 | iPad simulator 多宽度 UI smoke |
| U-43 | deep link 中文吧名、短链和重定向 | 本地 URL parser fixture 优先；网络 redirect 后续独立验证 |
| U-44 | thread anchor 在数据刷新/删除后恢复 | post id fixture：存在、移动、删除三组 |
| U-45 | Reduce Motion 下 Media/Tab/refresh 行为 | UI test 启动参数切换 Reduce Motion；功能断言不依赖动画 |

## 搜索 / P1

| ID | UNKNOWN | 安全验证方法 |
|---|---|---|
| U-46 | `PARTIAL_CLOSED_BETA`：Hybrid forum/thread 的 Cookie 必要性 | iOS 26.5 Simulator 的匿名 forum page 1 与 thread page 1/2 均 HTTP 200/JSON decode 成功，证明本路径不需 Cookie；长期稳定性仍 OPEN |
| U-47 | 搜索建议慢响应顺序 | SearchSug 未进入 16A；已实现的显式 submit 搜索以 Controlled Repository 反向完成测试锁定 latest-cancel/generation |
| U-48 | forum/user 搜索是否分页 | forum response 已观察 `pn/has_more`，但 Android Forum ViewModel 无下一页请求，阶段 16A 仅首屏；user 未实现，两者分页仍 OPEN |
| U-49 | 搜索 thread 重复率与 sort 值域 | `PARTIAL_CLOSED_BETA`：第二页已证 `pn=2/has_more/current_page`、20 个映射结果均为新 ID；Fixture 锁定重叠页 first-wins；`st` 其他值域仍 OPEN |

## 历史 / 设置 / 用户资料 / P1

| ID | UNKNOWN | 安全验证方法 |
|---|---|---|
| U-51 | `PARTIAL_CLOSED_BETA`：Profile endpoint 匿名接受性、屏幕字段必要性和长期稳定性 | 2026-08-30 单 Simulator Debug-only 公开作者 Probe 已 HTTP 200/decode=true/display fields=11；屏幕字段服务端必要性与长期稳定性仍 OPEN，不增加设备伪造值 |
| U-52 | self-profile 的 `uid/is_guest=0`、私密/删除用户与完整错误 taxonomy | 后续独立账户资料任务；不复用当前 anonymous 他人资料 descriptor 猜测 |
| U-53 | History schema 升级、多账号分区、云同步和跨设备 | 当前只是 schemaVersion=1 本地 JSON；未知版本 fail closed 并可清空恢复。需产品/隐私决策后才设计迁移 |
| U-54 | 用户 portrait 图片候选、cache/downsample 和失败语义 | 阶段 16B 统一占位；等现有 production image loader 有独立证据后复用，不建第二图片管线 |
| U-55 | Settings 更多跨平台项、迁移和 iCloud 同步 | 当前只保存已真实生效的外观/阅读字号；新项需实际行为和迁移测试，不加假开关 |

## Media / 交互验证

| ID | UNKNOWN | 安全验证方法 |
|---|---|---|
| U-50 | Media 缩放与 pager 仲裁、边界加载、失败/旋转 | 使用 3 图 fixture：中图缩放/平移→翻页→首尾边界→断网/重试→旋转/分屏→返回；验证已批准的逐页 transform reset、进程恢复只回父 route，以及 iPhone/iPad 一致行为 |

## Android 源码异常不等于产品行为

以下只能作为回归风险线索，不应通过运行实验“固化”为 iOS 行为：

- Forum 成功后 `isLoading=true`。
- 固定 20ms/1s/1.5s/2s delay。
- refresh/page failure 只 Toast 或静默。
- `first/!!/toLong()` 导致畸形响应 crash。
- 未知内容节点静默丢弃。
- Media 单击关闭、吞掉触摸 RuntimeException。
- 单 root NavHost 与返回键跳 home。
- 明文 Room 凭据和 cleartext endpoint。

## 关闭 UNKNOWN 的记录格式

每项关闭时必须追加：

```text
ID：
日期：
Android/iOS build 与 commit：
scenario：
请求类别（不含 secret）：
fixture 路径与 SHA-256：
观察结果：
与现有规格的差异：
新增测试：
结论标签：RUNTIME_EVIDENCE
```

没有上述记录的项目不得从 `UNKNOWN` 改为已验证。

## 2026-09-27 发布审核（R13 之后独立排查）

- 用户已明确同账号官方 iOS/Android TiebaLite 可发布，而本客户端新回复被涉嫌异常行为删除；真实触发原因与即时返回仍 UNKNOWN。
- 源码已证明 name_show 业务字段遗漏，当前候选修正同账号公开资料→写入请求的传递；未证明该字段影响风控，不能称审核通过。
- Profile 取值复用 R12 路径，不冒用登录名或 UI fallback，不加入 Android 设备/验证数据。用户已手动发布成功并提供新增第3楼截图；后续是否仍收到删除通知/持续可见性待观察。自动化只使用 Mock，AI 无 Live 上传、发送或重发。
