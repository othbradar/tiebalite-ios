# API / Protobuf 证据

## 2026-10-09 GIF 编码数据保留

CODE_EVIDENCE：同 SHA iOS22.11.1，TBCReplyComposeImageUploadCoordinator.imageUpload:shouldGifAtIndex:(0x102396458)检查runningMeta.imageType == 2；gifDataAtIndex:(0x1023964a8)返回imageGifData。TBCImageUpload.uploadGifImage…(0x10214c5e0)对编码数据调用filterImageMetaWithData:originalMetaData:，用imageWithData仅取得尺寸，再对同一份编码数据计算MD5并送入分块，不经过静态JPEG压缩。0x10214c874比较长度0xa00000，只有小于10 MiB才继续；主题新Uploader同样在0x102152f10比较该值。合成原指令回放的类型与严格大小边界见native-ios-gif-policy.json及generate_gif_policy.py，未运行真实上传。

filterImageMetaWithData:originalMetaData:(0x101cd8614)在无originalMetaData时返回输入NSData；有metadata时保留/重写AIGC信息。当前增量保持选择到的GIF编码字节（包括已有扩展数据），不调用JPEG编码，不声称完成原生AIGC元数据重建。sliceImageAndUploadChunks(0x10214d4a8)将isGif置1；uploadChunks(0x10214dbc8)令GIF跳过水印，缺saveOrigin delegate的普通回复仍为0。最终仍由同一TBCImageUploadModel传输；IDP上传的chunk/chunk/image/jpeg固定封装不因GIF更改。禁止因扩展名自行改成另一MIME或增加未经证实的GIF请求字段。

本轮仅闭合普通GIF选择→草稿→原编码分块路径。原静态图JPEG准备、原图配置/元数据、提前上传/并发/混排、SDK/Passport及其他发送分支的缺口仍按原记录保留。不会将GIF保留误写为所有图片已原图上传；图片显示/保存系统独立不变。

## 2026-10-08 图片发送迁移（SDK/Passport 按用户要求跳过）

同 SHA iOS22.11.1：TBCReplyComposeImageUploadCoordinator._drive(0x102395c44)串行创建TBCImageUpload，成功(0x102396630)保存picInfo。TBCImageUploadModel.uploadChunk:saveOrigin:(0x10214f384)使用/c/s/uploadPicture和chunk文件；业务字典含原始imgMd5作为resourceId、chunkNo、isFinish、width/height、size、smallWidth/smallHeight、alt=json、saveOrigin。普通回复delegate未实现水印回调，默认shouldAddWaterMark=0→pic_water_type=3；barName非空写small_flow_fname，不凭空加forum_name/groupId。六个显式合成输入执行原ARM64方法至accessAPI前，未联网。

补充实际资源ID来源：TBCImageUpload.uploadImage 在0x10214cf3c调用NSData.MD5String；BBACommonDigest category的0x1026592d8实现以%02X(0x102659364)逐字节格式化，明确为大写。上传字段转为大写，现有草稿稳定ID仍保留小写，不更换业务身份。reply coordinator的barNameForImageUpload(0x102396520)转发barName，保留实际吧名。

TBCImageUpload.sliceImageAndUploadChunks(0x10214d158)读取imageChunkSize(KiB)，缺配置0时使用0x7a800=501760字节；从1开始递增chunkCurrNum。普通chunk未设置small尺寸，保持对象零值。TBCImageUploadModel.generatedPicInfo(0x102150c14)生成#(pic,picID,orgPicWidth,orgPicHeight)。finishRequest(0x10214fbec)读取error_code、picId及picInfo/originPic，不能由本地文件名或请求尺寸伪造成功。保留本App对缺失/错误回执的拒绝约束。

IDPServerAPI.bba_uploadWithMethod…(0x102663bb4)把files的key同时用作fileName/asKey，MIME=image/jpeg。因此文件段为chunk/chunk/image/jpeg；数据独立于表单签名。timeoutWithURL:params:(0x102663f98)对上传返回120秒；小于1024字节文件的后置分支改为Wi-Fi10/其他25。原生普通Common/签名以uploadPicture API另行回放标准与优化两分支，结果为业务+Common合并签名，无Proto查询、无Proto元数据后缀。SDK/账号/设备输入均为显式合成替身，不能当真实身份生成。

主题图片另有TBCUploadImageManager.startUploadImage(0x102156b08)→TBCNewImageUploader路径；它仍使用TBCImageUploadModel(0x102154244)，但并发/原图/水印受配置控制。本App本次只接普通无水印JPEG字段分支，串行请求，不声称原版主题上传调度一致。TBCUploadImagePlugin.spliceContentTextWithImageStr(0x1018cf000)的非混排分支直接追加服务器图片串，混排分支替换(_ImageToUpload_)；本App原编辑器正文+换行图片序列仍保留，完整混排转换不在本次闭合范围。

本轮接线范围为既有编辑器选择的、已有本地准备策略产出的JPEG，按用户点击发送串行上传，全部成功后交给既有iOS正文/发送链。原图片导入的2560/1920/1080限额及0.95 JPEG策略是已批准App内存策略，并非原生压缩逐字节复刻；不将原图/动图/元数据处理、原版选图后后台提前上传或其可配置重试称为完成。本App保留用户点击才上传、取消/换账号失效、失败留稿且不自动重发的约束。原生配置实际值未知时仅使用上述明确默认值，不搬Android上传参数。

## 2026-10-08 Build11 系统日期 provider 与剩余路径复核

CODE_EVIDENCE：同 SHA 的 iOS22.11.1，commonStaticParametersNew 在 0x1024b16f4 调用 NSDate.date，0x1024b170c 创建 NSDateFormatter，只在 0x1024b171c 设置 `YYYYMMdd`，0x1024b1730 格式化该日期，0x1024b1750 写入 event_day。缓存分支对应 0x10024a37c/0x10024a388/0x10024a3ac；没有在这些方法内设置 locale/calendar/timeZone。原有 ARM64 Common 回放明确替代日期格式器，因此此前只能证明字段转交，不能证明 App 已提供日期。

当前 App 使用已声明的 recomputed 分支，但 runtime 的 eventDay 一直 nil。Build11 提供实际当前日期，创建新 Foundation formatter、只设置同一格式，其余使用系统默认。保留大写 Y 的 week-year 语义，不换成 yyyy、不固定 UTC、不缓存到下一天。不改 Common 缓存选路、签名算法、网络次数/顺序或成功处理。固定 provider 接线测试验证连续两次显式请求的 Common 与 Proto 日期；固定日期及 UTC/上海、en_US_POSIX/en_GB 验证跨日/跨周年行为，不读取真实账号或联网。

本轮另外复核的边界（未据此添加请求）：`iOStbclient` 分支 0x1021ab26c 赋31，不能套给 `com.baidu.tieba`。后者经 checkJumpToBaiduMatrix→checkJumpToMatrixPB(0x1021b674c)，buildWithNavigationController…fromType(0x10249d1bc)本身不赋 pbEnterType；QQ/shoubai/问答等 URL 字段还有后续覆盖。不能把通用 jumpToPB 的14或 Universal Link 的32直接用于搜索和全部 Scheme。搜索由 TBCWebSearchNewViewController 的 Web 跳转驱动，缺实际结果 URL 与完整消息消费链，仍 OPEN。

getmypost 基础 provider(0x102ca65b4)依赖 schema、页面/广告/推送/实验服务；pbMyReplySwitch(0x101cca4a0)读取 `pb_reply_switch`，回复完成(0x102d7660c)按该开关选择专用读取。开关实际值及完整 provider 未闭合，不能把默认缺配置返回0等同于当次真实配置，也不将当前普通刷新改成无条件专用请求。静态窗口保存在 ignored build11 证据目录，完整 SDK/Passport、挑战续发、替代 HTTP 引擎和图片发送仍未完成。

## 2026-10-08 默认 AF HTTP 分派与统计边界

CODE_EVIDENCE：同SHA22.11.1的BBAAPIRequestManager.sharedInstance块0x10462d568构造BBAAFNetworkingRequestManager；IDPBBARequest继承BBANormalAPIRequest/BBABaseAPIRequest，基类isUseNewRequestManager(0x104610c4c)返回0。默认数据及上传会话分别在0x10462a018/0x10462a340安装AFHTTPResponseSerializer；其init(0x104314db0)明确设置acceptableStatusCodes为200起100个索引，acceptableContentTypes=nil。validateResponse:data:error:(0x104314e60)在范围外构造AF响应错误code=-1011；不是HTTP成功包中业务error=0就允许通过。

原生TBCBBARequestManager completion/failure块0x10269a354/0x10269a598分别交付已完成/失败状态，失败进入已证实parser state4（除timeout以外统计result=-1、不记录完整字节）。成功传输且业务无错误时，非200但仍被默认AF接受的201等状态写入统计result；业务错误保持业务码优先，空/畸形body保留-3。统计不决定业务回执，不能将result=201当作帖子拒绝，也不能将HTTP503的合法形状body当作成功。采用原范围拒绝、只补实测统计及非200已解析统计；取消/旧账号/无measurement不制造统计。

固定fixture已独立执行native AF validator的9个HTTP状态及parser的54种组合，Foundation对象/诊断文案为显式合成替身，AF NSError合并helper执行原指令；网络、SDK和实际引擎远程配置不执行。BBANSURLSession/Turbo等可配置替代引擎仍为独立边界，不能把默认AF的对齐称为所有原生引擎都已复刻。fixture重新生成一致性及定向执行结果记入TASK_STATE。

## 2026-10-08 外部 Web 帖子入口来源

CODE_EVIDENCE：同SHA TBCRedirector.parseUniversalLink:navigationController:(0x1021cfe2c)校验输入/导航容器后，于0x1021cfed4把来源全局值设32；其普通PB分支0x1021d1110调用checkPBUrl。后者0x1021b1c5c读取该值作为jumpToPB:…enterType:的x6；闭包0x1021b3290赋给pbEnterType，再由既有已回放transPBReplyEnterTypeToStringParam映射32→post_from=5。源码窗口在ignored build10/entry-*。

本App仅对现有DeepLinkParser已接受的外部HTTPS帖子链接记录独立来源32，不扩展URL接受范围、不改导航结构/缓存/草稿ID；普通scheme/搜索/正文内部链接不能因此都推断为Universal Link。来源随原route移除，编辑器继续冻结当前来源。搜索由Web页面及额外URL参数驱动，尚缺确定的实际入口样本；不把通用jumpToPB的14或外部32套给所有搜索结果。

## 2026-10-08 页面来源传到回复模型

同SHA22.11.1的TBCHomePageViewController.homepageFeedCellGotoPbPageWithCell在0x1028d5430给pbEnterType=3，普通feed click及comment按钮同值；TBCPBContainerViewController.handleParamsDict:fromSource:needTransfer在source=3分支0x102c4d23c明确setIsFrsGoin=1、pbEnterType=5；TBCUserHistoryViewController.didSelectObject:atIndexPath在0x1030af46c赋30。新编辑器TBCReplyComposeSubmitPlugin.sendMsgHandler:msgContent从compose model读取pbEnterType并在0x1023df00c原值交给回复模型；普通PB addReplyView在0x102cff4d4传递同属性，lazySetupViews在0x102d2a87c传给replyModel。最后transPBReplyEnterTypeToStringParam(0x10245e8a8)的已回放映射分别3→post_from=2、5→3、30→11。

消息入口继续核对：TBCMessageReplyViewController.selectReplyItem:floorInfo:clickRange在0x102b57094赋37，originThreadDidSelectWithItem在0x102b58800赋29；分别映射post_from=12/4。TBCPersonMessageViewController在viewDidLoad的0x102b792dc设置标题“@我的”，loadData在0x102b7ab0c调用loadAt:page，模型0x102b77458设置/c/u/feed/atme，证实不是按类名猜测功能。其对应两种点击在0x102b7c328/0x102b7df40都赋39，映射13。调用窗口保存在ignored notification-entry-contexts.txt。

实际入口保存这些来源，随当前路由传到打开编辑器时的目标快照；不向业务ThreadID、缓存键、草稿ID或既有RouteIdentity增加来源。通知来源捕获实际Pager页面kind，不从之后的当前Tab倒推；进入楼中楼继续继承，返回移除路由时清理元数据。未知/搜索/外部链接仍走原unspecified=0，不能声称全入口完成。TBCRedirector的两处14来自通用jumpToPB路径，不能直接当搜索入口；未据此设置搜索来源。页面/楼中楼/通知生命周期与七种来源的Mock实际请求验证接线，不发真实评论。

## 2026-10-08 原生网络失败统计与剩余边界核查

同SHA22.11.1：IDPServerAPI.bba_handleRequest的failure block 0x102665170检查isCancelled：取消置state5，否则state4；默认retryHandleRequestWithFailed(0x1026649bc)返回0。普通IDP处理0x1026647b8同样传递3/4/5状态。commonHandleRequest 0x102664a9c在解析前记录实际netCost。TBCServerAPI.parseBodyIsProtobuf 0x1024b62d4读取request.error.code，-1001→m_result=-2，其余失败→-1；state5→-4。失败分支没有更新传输字节，不能把部分传输当完整字节。

generate_network_failure_metrics.py用明确的transport state输入封闭回放14例；包括5个网络失败、1个取消和8个已完成HTTP响应解析边界。文件native-ios-network-failure-metrics.json保留SHA及替身范围：未执行BBA传输库、真实网络或SDK。已完成HTTP有效包状态非200覆盖统计为HTTP码；空body仍-3。BBA底层HTTP可接受状态分派尚未执行验证，此部分暂不扩展生产成功判断。网络失败接线仅观察原一次请求耗时，在既有取消/账号检查后交给下一次显式请求消费；保留取消不发布、无自动重试的本App约束。实现/测试结果以TASK_STATE本轮记录为准。

公开SDK核查：[百度iOS安全SDK文档](https://cloud.baidu.com/doc/AFD/s/xjwvy4rv4)当前提供HTSSDKLib静态库并要求上传应用申请AppKey/SecretKey。包内22.11.1使用SSDKLib与CUID/账号事件输入；不能证明公共最新版与包内同版本，更不能用伪造标识或其他App身份补齐。已通过隔离Chrome读取公开文档，不读取个人登录或发帖。完整SDK/Passport、运行配置、页面入口、挑战完成及定向读取生产接线继续逐项核查，不将其判为已完成。

用户本轮明确答复：没有TiebaLite对应SDK接入包或应用注册资料。这里缺少的是本App可用接入条件，不是把官方IPA误称为SDK，也不是说公开SDK不存在。没有复制官方App的AppKey/SecretKey/设备身份或加入伪造provider。

其余边界的直接核查：TBCUEGManager.showSmsVerifyH5(0x101c8cc0c)先注册TBCSmsVerify JS handler再经TBCRedirector展示URL；UEGPassManager.verifyID(0x1021fd714)调用PASSControllerFactory并设置scene=tieba_ueg，reSendRequest(0x1021fe428)把完成返回的authsid合入原reqParams再提交。没有可核验的实际挑战完成数据/SDK回调时不自动续发。PB provider仍读取schema、TBCDeviceService、TBCAdCommomParamService、TBCAppContext和push统计，pbMyReplySwitch的当次值未知；不能把已有普通刷新或仅PbList组件标成完整getmypost生产链。

HTTP补充：BBAAFNetworkingRequestManager.createDataSession(0x104629ef4)/createUploadSession(0x10462a1a4)安装AFHTTPResponseSerializer，另一BBANSURLSessionRequestManager.handleTaskCompletion(0x104631330)自行设置statusCode并交parseResponseData后分派成功/失败。实际选路/完整异常分派没有封闭回放，不能从已完成HTTP的parser样本推导全部HTTP失败均用同一result。生产HTTP接受/拒绝条件保持，本轮只接已证URL加载失败统计；原生取消统计-4仅为参考，本App取消和失效账号继续不发布统计。


## 2026-10-08 原生响应解析失败统计（Build7用户确认回复成功后续接）

参考仍为22.11.1同SHA。TBCServerAPI.parseBodyIsProtobuf: 0x1024b5db0进入时先记录api/netCost及传输字节；空body在0x1024b62c8记录result=-3，IDL返回nil在0x1024b6ad4记录-3，JSON非字典及缺error_code/error.errno分别在0x1024b6e34/0x1024b6d0c记录-3。有效IDL字典但没有data时不会因此设置解析失败：0x1024b6748检查的是IDL返回字典，非payload。正errorNum仍记录原码，非正归零；这不代表业务已发送成功。

generate_parse_failure_metrics.py实际执行上述原生parser，10个合成边界固定为native-ios-parse-failure-metrics.json；Foundation/IDL输出显式替代，断言/告警/日志出口仅记录，不执行网络或SDK。两轮未声明的原生日志调用使回放失败，明确补日志替身后10例完成；不把替身IDL称为任意wire的原生解码验证。Swift以相应合成wire交叉验证解析统计，业务回执/草稿/成功关闭保持原判断。无有效测量不估算；取消/旧账号不得发布统计；HTTP拒绝、实际网络失败及全局遥测仍未对齐。


## U08 原生回复续接状态的落盘范围（2026-10-08）

同一 iOS22.11.1 SHA 的 `IDPCache.sharedCache`(0x10025f1cc)明确使用 default_cache、storagePolicy=2；`setObj:forKey:`(0x102babd68)先写内存再写磁盘，`saveInner:forKey:`(0x102bac0ac)对字符串调用 saveString。`objectForKey:`(0x102bac2c0)先读内存，未命中读磁盘并回填内存。`generate_state_cache.py`封闭执行这些真实分支和 memoryKey 的 MD5 变换，底层内存/文件、时钟及性能日志为明确合成替身，三个策略的差异及清空内存后读回均可重放；没有读取官方缓存。

此前已证回复/主题 handleVerify 把单个解析值以 svcp_stk 键交给该共享缓存，因此仅 NativeWriteSession 内存不等同原版生命周期。initWithNameSpace:storagePolicy:(0x102bab6e0)在没有配置时写入3600秒，配置已有但缺失该键的默认值为10800秒；不能混为一个固定全局TTL。原版后台 cleanBackground(0x102baaebc)先清内存，首次或距上次清理超过600秒再清磁盘；查找本身不判过期。下游 syncCleanExpiredFiles 是独立清理边界。文件分支 cleanExpiredFiles:fileName:expire:expiredKeys:currentDate:(0x102bb1dd8)使用NSFileModificationDate，仅 modification+expire < now 才删除；封闭回放5例涵盖负年龄/零/过期前/精确边界/边界后。

本App使用自身受保护账号伴随记录保存该单值及更新时间，不保存完整Set-Cookie，不复制官方全局缓存、不读取官方账号标识。兼容旧version1账号记录。后台采用本App新建缓存的3600秒默认策略；不把SDK运行时配置/跨账号全局共享/全部缓存管理器迁移称作已完成。账号切换/登出仍必须隔离，写后持久化失败不能改变已确定的发送结果或自动重发。

另外本轮只读确认 PB 基础provider(0x102ca65b4)合并 schema→页面→统计→翻页四组参数，并包含广告/设备/同步配置服务；不能用空字典冒充完全提供。pbMyReplySwitch→findType(0x101ccbf2c)缺少配置对象时返回0，普通主题 handler 在该分支不派发 getmypost。现阶段未擅自启用生产定向读取，NativeReplyReadClient 仍未Live接线；此为明确剩余差异。

## 2026-10-08 U08 续接：账号/TBS 普通表单的回包统计与请求编号

用户确认Build5回复正常后授权继续对齐并生成新版IPA。仍使用同SHA的22.11.1。TBCServerAPI.parseBodyIsProtobuf:的JSON分支0x1024b6498–6558、0x1024b6e68–71c8：error_code非零优先，否则取error/errno；JSON非零负码也写入result，不沿用Proto的非正归零规则。JSON logid经numberAtPath:（0x10265afdc）取得：NSNumber直接使用，NSString先doubleValue再装箱，其他类型缺失；最后unsignedLongLongValue。不能用出站编号替代服务端logid，数字JSON与大整数字符串也不能强行统一精度。

IDPServerAPI.accessAPI:WithParams:files:requestMethod:completionBlock:（0x1026641b4，调用点0x1026643e4）在普通表单选路前调用addExtraHttpHeaders。TBCServerAPI实现0x10025d3ec在requestCMD=0时不加Proto标志，clientLogID非0/非-1时加client_logid。当前NativeAccountPreparation漏接已有runtime编号；TBS原实现已有该头。本次只补账号表单漏项，不变UA、body编码、普通签名或端点。

generate_form_metrics.py封闭执行原生JSON parser、numberAtPath和普通头分支，12个统计样本、4个头样本固定于native-ios-form-metrics.json，重生成逐字节一致；既有4个Proto度量样本未变。Foundation标量操作是明确合成替身，网络/日志均拦截；不是实网发送。NativePreparationHTTPClient接入现有账号→可选TBS→一次写入顺序；度量仅在当前账号且未取消、HTTP成功且有效JSON错误码包中接受，既有业务decoder的成败规则不变。统计所有权从首次准备开始绑定，覆盖准备失败、尚无client时切换账号的清理。新增7项Unit及已有4套直接回归共40项通过，Mock观察首轮有TBS时2次请求，缺TBS时3次请求，没有自动重试。没有真实请求，SDK/验证/回执定向读取等其余缺口不据此标通过。

## 2026-10-08 U08 续接：实际写请求传输统计

同 SHA iOS 22.11.1：IDPRequest.dispatchRequestDidFinishCollectingMetrics:（0x102656ef4）的块0x102656f68只采用resourceFetchType=1（networkLoad）的事务；顺序覆盖，取最后一次，不累加。IDPRequestMetric.requestMetricWithTransactionMetrics:（0x102657988，关键0x102657a58–a94）分别将URLSession的headerBytes与bodyBytes相加。普通stream读取保持原字节/超时/重定向拒绝/容量限制，仅原生写入可选择按请求独立的delegate收集；没有共享可串号的全局最近记录。

IDPServerAPI.commonHandleRequestWithResponseData:requestHeaders:（0x102664a9c）在解析前以当前绝对时钟减startTime记录netCost。TBCServerAPI.parseBodyIsProtobuf:（0x1024b5db0）去掉API第一个前导斜杠、乘1000换成毫秒、成功传输取上述字节数，解析正errorno写result，非正值保持0。generate_transfer_metrics.py封闭执行该原生parser的4组合成样本，Foundation标量/字典访问显式替换；不执行网络或SDK。Error描述符只有errorno/errmsg/usermsg，不能用出站client_logid填充回包logid。

本批接线仅限同账号、未取消、HTTP成功且已完成Proto解析并有payload的新帖/回复结果进入下一次Common消费。账号/TBS JSON、传输或畸形响应失败时的原生全局统计覆盖尚未迁移，不宣称全部统计生命周期一致。缺少系统transactionMetrics时保留缺失，不按payload大小估算；迟到度量不追改已完成请求。数据不落盘、不记录正文/头部值或设备地址。修改共享loader仅增加显式delegate重载，旧入口仍用自身delegate；WRITE_BASELINE保留原摘要，以精确逆向差异记录用户当前授权。

最终统计组件6项Unit通过，相关发送/传输/Live adapter/诊断共5套件40个不同用例通过；短UI只验证Mock成功关闭和草稿清除。按用户请求产出0.2.0(5)未签名设备试用IPA，候选源码/包内字节/Release隔离通过；包证据在ignored Artifacts/Releases/U08-native-alignment-20261008/package-verification.json。仍有下述SDK/验证/定向读取接线缺口，不是完整原生对齐或真实发送验证。

## 2026-10-08 U08 续接：原生回执定向读取组件

继续使用下节同一 iOS 22.11.1 可执行文件/SHA，不改变 Live 发送次数、参数或完成回调。NativeReplyReadProtocol / NativeReplyReadClient 新增 CMD309751 的独立读取边界：`/c/f/pb/getmypost?cmd=309751&format=protobuf`，由原生 PbList 描述符生成请求/响应，单次请求、无重试；拒绝错误账号、错误主题、缺失目标和过期/取消结果。参数仍必须由调用方提供，组件没有生产调用者。

- `scripts/fixtures/native_write/generate_reply_read.py` 从原生描述符独立生成 3 个请求和 8 个响应合成样本。`native-ios-reply-read.json` 覆盖大于 Double 精确范围的 ID、first_floor 标签6、post_list标签7、page标签8，以及错误/空/错主题/缺目标/缺分页/不支持的内容类型。重新生成逐字节相同；不是抓取真实内容或网络验收。
- 原生响应外壳使用专用 ReplyReadResponse；thread/forum/user/post/page 的内部 payload 复用已有只读 DTO 前，`verify_reply_read_dtos.py` 按原生 client.proto 核对递归闭包：70 个消息、698 个已用字段的 tag/cardinality/type/message 类型。唯一例外 PbContent.type 原生 uint32、既有 int32，适配器拒绝超出 Int32 正值范围的内容类型。既有 PBPageDomainMapper 仅作为内存中的领域映射器使用，没有调用 Android 端点、请求构造器或响应外壳解析。
- 原生复杂字段 ad_param/app_transmit_data/push_info 未取得完整 provider，显式拒绝，不能静默忽略后声称完整页面对齐。基础 PB provider、pbMyReplySwitch/入口选路、完整 Common/签名输入、返回数据与阅读缓存的合并仍未闭合。新客户端不写缓存、不改变锚点、不自行准备账号或重发回复。共享 HTTP 封装仅抽取函数，原写入字节回归保持。
- 直接验证：最终读取套件 6 项、HTTP 套件 6 项通过；先前组合的读取/HTTP/发送客户端 20 项通过。每次测试均为 Mock。当前正常 Live 仍是已验收候选，没有据组件结果安装半成品或声明发送后刷新已修复。

### GitHub 补充检索（2026-10-08）

已检索原生 iOS 发帖/回复、PbListReqIdl、TBCUEG 及 Passport 等对应实现，未找到可核验且能填补上述 provider/验证恢复缺口的开源实现。范围是本轮检索，不能解释为所有实现均不存在。

- [TiebaPure-iOS，固定提交 6bf728b](https://github.com/infinityf4p/TiebaPure-iOS/tree/6bf728bcdc231137b728ccb9ca99b3b192ddd03d)：SwiftUI 前端，但 `TiebaRequestBuilder.swift` 的 `_client_type=2` / `bdtb for Android`，`TiebaContentSubmissionAPI.swift` 的 client_type=2 及 upload_client_type=2 表明发送采用 Android 参数；不作为本次 iOS 行为来源、不导入代码。
- [toamdou/TiebaLite-IOS](https://github.com/toamdou/TiebaLite-IOS)：README 明确发帖/回复/楼中楼尚未实现，不能补本次发送链路。

## 2026-10-08 U08 前六项续接：账号、页面数量与实际网络上下文

授权为用户“先把前6项与原版不一致的做一下对齐，图片先等前面的做好了再做”。基线 b5266dd；参考仍为用户指定 iOS 22.11.1 / SHA256 4f0cb74c738f714258dd14bde5fb7a7859ab7baf19183c01e900704ab702d9eb。没有更换到 Android 写入协议，也没有真实发布/上传。

### 已接入的有据差异

- **账号/TBS**：沿用此前已证实的账号优先、缺 TBS 才补取、profile 完成按 UID 更新昵称规则。NativeWriteAccountVault 将本 App 已成功准备的 UID/TBS/原始昵称放入独立 WhenUnlockedThisDeviceOnly Keychain 条目；使用现有稳定账号 namespace 隔离。同 namespace 重启复用，显式登录/登出清理此伴随条目；旧 AuthContext 的迟到保存不能进入写请求或清除新账号条目。串行化存储事务防止 actor 在 read/delete 间重入。不是 Passport 数据库复刻，不读取官方 App 容器/身份，不改登录凭证格式、access group 或签名配置。
- **昵称来源**：原生 account-name 回放中 uNameShow/uName 的 UTF-16 选择和 UID 保护保持。ProfileProtocol 只额外保留已有读取结果的原始 name_show/name，视图 displayName 的归一化和兜底不变；writer 不使用 UI fallback 更新账号、不追加 profile 请求。原有只读资料协议未在本轮迁移，不能把该域数据复用称为完整原生账号链路。
- **页面数量**：线程回复模型 0x102d6c5c8 / 0x102d6c740 取 pbListItem.iReplayNum；TBCPBListItem.init 0x101ba11dc / 0x101ba1390 将其映射为 thread/reply_num。楼中楼模型 0x102f5b270 / 0x102f5b388 取 pbItem.iReplayNum；TBCPBCellItem.init 0x101b954a4 / 0x101b95534 映射 sub_post_number。编辑器打开时冻结 snapshot.replyCount / subposts.totalCount，发送时进入已有 business.floor（只参与字典/签名，不是 Proto 楼层字段），不减一、不改变目标/草稿 ID。0x102f5b3fc 明确给 floorNum 字符串 "0"；不得用界面楼层数字替换。pageEntryType 各真实入口语义仍未验证，继续原默认 0，不标为全入口已齐。
- **网络环境**：NSStringUtils.netTypeForReport 0x10024aa80、字符串表 0x10c109920，以及 detailNetTypeNameByType 0x10219eb28 / 表 0x10c107678：无网络空串，Wi-Fi=1，OTHER=0，2G/3G/4G/5G=2/3/4/5。用本 App NWPathMonitor 的首次状态和当前数据 SIM 的 radio access technology 得到该值，不取运营商/订户 ID。复用原先证明的 Wi-Fi 10 秒、其余 25 秒超时。Common int32 的空 net_type 与已有 personalized_rec_switch 一样，仅签名后在线格式转为显式 0；其余非法数字仍拒绝。
- **语言头**：AFHTTPRequestSerializer block 0x10430e6b0，以 Float 的 1 + index * -0.1、格式 `%@;q=%0.1g` 输出，包含 q=0.5 项后结束，逗号空格连接。保留本 App 实际 Locale.preferredLanguages。
- **请求编号**：IDPClientLogIDProduter.getClientLogID 0x100268b8c / 初始化 0x10005a380：首个本地时间截断为秒乘1000，再逐次加1。封闭 ARM64 执行合成时间1000.999实际返回1000001/1000002/1000003（ignored six-client-log-proof.json）。使用本进程序列，不复制官方 App 的编号，不以该编号冒充响应 m_logid。

### 定向读取的新证据与未接入边界

命令309751通过原版 IDL factory 0x1024df4f0 的实际分支到 0x1024e1b34，构造函数0x103b38cac/0x103b3a548；vtable0x10c1a1690/0x10c1a18e8的 RTTI 分别为 tbclient::PbList::PbListReqIdl / PbListResIdl，解析目标 TBCPBListItem。请求描述符 pbList/pbListReq.proto offset0xa7381ec，1196bytes；响应 offset0xa738725，4844bytes。关键字段 kz2/int64、last_pid4/int64、mark_type8/int32、request_times36/int32；响应 first_floor6/Post、post_list7/Post、page8/Page。

不能因为接口名 getmypost 而使用 getMyPost/getMyPostReq.proto：后者 thread_id/post_id 等字段不同。普通主题分支还调用 TBCPBRequestParamsUtils.requestParamsToDictionary...（0x102ca65b4），读取页面来源、会话请求计数、广告/实验等实际 provider；现有跟随参数回放将这一步作为显式输入，未验证其完整生产输入。当前没有把不完整字典或 Android PBPage 构造器拼进原生后续读取。原 getmypost 组件仍未生产接入，既有成功关闭/当前页 reload/refresh 不变，不能标记第6项完成。

### 仍未完成的前六项范围

完整 Passport/安全 SDK 的提供者及初始化、CUID/z_id/UA配置/实验选路、实际传输统计和响应状态完整作用域，以及验证码/短信等完成后的恢复仍缺可用移植契约。参考 IPA 为 iPhoneOS 程序，不是可供 Simulator 链接的 SDK；既有封闭回放只拦截 provider/发送出口，不构成真实 SDK 执行证据。继续保留 UNKNOWN，不以空值、伪造身份、估算包大小或自动重发填补。图片完全留后续；本批代码是部分对齐，不是前六项全部完成。


## 2026-10-08 U08 — 试用版发送前整数编码失败

用户截图中的账号资料失败提示过于宽泛。一次显式、仅账号准备的本机检查观察到 `/c/s/login` HTTP 200、error_code=0，user.id/anti.tbs 为字符串且现有解码成功；不保存响应正文或凭据，没有执行写请求。临时检查入口已经移除。

实际 NativeWriteAppRuntime 的标准 Common 在缺少配置提供者时生成 `personalized_rec_switch=""`；此前 SwiftProtobuf JSON 桥接对该 int32 字段抛 `malformedNumber`。参考 iOS 22.11.1 的 TBCIDLBaseTransform.setFiledValue:message:fieldDescriptor:isRepeatedFelid:repeatedIndex:（0x1024dc678）在 int32 分支对 NSString 调 intValue（0x1024dc7c0），之后明确调用反射 setter。空串因此写为带 presence 的 0。这里不是官方真实发送流量的抓包；依据为原二进制的局部静态调用和本机 Foundation/编码回归。

只在 IDL 编码边界把这个已知字段的空字符串映射为 0；不补缺失字段，不改其他畸形整数的拒绝策略，不更改签名前字典或签名结果。独立预期 wire `0A050A03F80300` 验证新帖/回复的 Common field 63 显式零，缺字段仍保持 absent。实际运行时 → Common → 编码的原失败测试已转绿，完整 Composer + 实际运行时 + Mock 网络观察到 login 一次、write 一次、无重试。非回包类的发送前准备错误不再误报为账号资料失败；账号解码失败仍有原区分。无真实自动发帖/回复，服务端接受及留存仍由用户验收。

## 2026-10-08 U08 — 用户授权的 iOS 请求试用版接入

本轮用户明确要求先做出一版参照原版 iOS 发请求的正常 App。范围为文字新帖及主题/楼层/楼中楼回复；不再以完整 SDK 对齐作为这版安装前置条件，但不宣称完整复刻或审核成功。沿用此前核对的 22.11.1 业务字段、IDL、签名与 HTTP 封装。

新增接入采用参考包内 TBCAccountModel.loginWithBduss:stoken:（0x101be282c）的显式 BDUSS 登录支路：`bdusstoken` 是原字符串，不追加 Android 的 `|null`；HTTPS 下非空 stoken 加入业务字典；appendFirstLoginParam（0x101be2a08）按本 App 自己的首次准备状态附加 first_login。响应映射 TBCLoginRespItem（0x101b41c18）取 user/anti，用户映射（0x101b41da8）取 id/name。仅一次成功准备后在当前 AuthContext 内复用账号；不是原版 Passport SDK 主登录生命周期，也尚未跨进程持久化这些账号材料。账号变化/取消后不接受旧响应。

运行时只使用本 App 的真实系统版本、机型、屏幕、当前时间及用户授权会话。系统 UA 在无网络、无 Cookie 的本地 WKWebView 中读取 navigator.userAgent；按 TBCUserAgentGenerator（0x10025d578）组合 tieba 版本后缀。没有原版 CUID/安全 SDK/皮肤提供者时不伪造其结果，UA 使用原方法 NSString 的 nil 格式 `(null)`；Common 中对应可选 SDK 项不填。版本 22.11.1 表示本版选用的参考协议版本，不修改 App 展示版本或签名。配置采用已验证的标准签名分支，未声称观察到用户原版的实验配置。

本版未实现图片上传及验证挑战执行；在任何上传或账号网络开始前拒绝图片发送并保留草稿。零错误码且有效目标回执才接入既有关闭/单次当前页刷新；真正验证错误返回原提示、不自动重发、不改为乐观回复。完整原生 getmypost 页面合并仍未接入。正文、页面来源取本 App 的当前目标，不借用 Android 请求 builder。


## U08 iOS 回复后定向读取参数（2026-10-08，迁移中）

继续上一节的成功回调，仅以相同22.11.1二进制为来源。普通PB并非在此调用普通下拉刷新：`TBCPBPageGetMyPostModel.pbReplayGetLastPage:aPostID:fakeWallParams:`（0x102c8ec38）在非折叠评论页面设置 `/c/f/pb/getmypost`、CMD 309751，保存返回的新pid，并进入独立的读取模型。`getParamsForRequestMyReplyWithFakeWallParams:`（0x102c8e7d8）从已准备的PB字段副本删除r/back/lz/pn，设置NSNumber mark_type=2、按NSString.integerValue转换的last_pid，必要时增加is_fold_comment_req字符串1。空/缺失基础字典返回nil。折叠评论页面另调用legacy方法，不属于本次实现。

`loadInnerForMyReply`（0x102c8e620）在当前serverApi.state为1或2时直接返回，不增加计数或派发；其他状态设置afterReply标志，pbRequestCount加一，复制字段并写request_times与字符串offset=2，调用loadWithLongConnection:3。不能把这解释成自动重复读取或轮询策略；连接模式3后面的传输选路仍待核对。新参数组件只准备值和本次计数，不拥有网络任务或共享全局计数器。

楼中楼`TBCFloorFakeWallModelV2.init`（0x102f44c54）设置相同路径/CMD；`loadFakeWallWithThreadId:replyPid:`（0x102f44cec）使用kz、last_pid的原始字符串及NSNumber mark_type=2，清该模型解析结果后调用loadWithLongConnection:3。入口控制器0x102f4e2d8先要求threadID/pid是非空字符串；底层参数函数自身的nil/空值样本不是允许无效目标发请求的依据。

新增封闭原生回放16例：11例参数及5例加载状态，基础PB字典/状态为合成输入，网络派发只记录。Swift的NativeReplyFollowupParameters只将这些参数规范为既有编码边界使用的字符串字典，并保留请求门控和计数变化；基础PB上下文、原生IDL/HTTP、读取结果合并、UI及实际配置未由这些样本证明。此组件尚未接入当前Live，不能把组件通过当作发送后刷新已经修好。

## U08 iOS 新回复完成链与设备核对（2026-10-08，迁移中）

用户解锁后，CoreDevice 对指定 `com.baidu.tieba` 查询返回 22.11.1 / 22.11.1.0、builtByDeveloper=true；这不等于允许调试。LLDB 选择设备后，对已运行 TBClient 的交互式附加明确返回 `Not allowed to attach to process`。随后定向进程查询确认原进程仍在；没有重签、安装、终止 App 或读取私有容器。先前批处理的 detach 报 `Process must be launched` 不能当作权限结论，以上独立交互式结果才是依据。Time Profiler 的单进程短采样在设备准备阶段超时，xctrace 将该设备列为 Offline，而同轮 CoreDevice 的 lockState 为已解锁；未形成可用采样，不声称已执行官方发送路径。

继续只读核对相同 SHA 的参考 TBClient。新插件在 0x1023df558 安装的 completion block 实际入口为 0x1023dfa58，经弱引用检查调用 `handleModelCompletion:legacyModel:content:spriteId:`（0x1023dfab8）。该方法先复位发送按钮状态，再读取 `isNetworkRequestSuccessful`。成功分支先调用 composeHandler 的 `handleSendReplySuccess:model:spriteId:seekHelpTabId:`，随后处理附件与该编辑器服务的草稿，调用 `dismissAfterSuccess`（0x1023e10e4），并发送完成通知。dismiss 方法请求 `transitionToState:0 trigger:9`。其中 `refreshContentFromContext` 是编辑器 service 的调用，不能按方法名称误当作帖子网络刷新；`clearAllDraftCache` 的服务作用域也不能直接扩成清除 TiebaLite 全部草稿。

成功分支之后仍到达统一的 error 检查及 `doUEGPassWork:sourceVC:` 尾部，不能写成“成功路径完全跳过验证管理器”。这不表示零错误需要验证：管理器的具体错误码条件仍由已记录的原生分支决定。这里没有引入“附带 anti/info 即失败”的旧错误判断，也没有改变当前 Live 回执。

普通 PB 的 handler 为 `TBCHybridPBViewController.handleSendReplySuccess…`（0x102d17514），会调用 `onReplyThreadSuccessWithReplyModel:`（0x102d7660c）。后者先读取 `pbMyReplySwitch`；开启时，楼层回复走现有 replyPostId 的 `pbReplayWithPostID:`，主题回复记录当前阅读锚点后，以返回 pbReplyItem.pid 调用 `pbReplayGetLastPage:`。关闭该开关时不会执行这一段。另有 H5 评论/数量通知，不能把这整条链简化成无条件 `reload`。开关的当前运行值、下层请求封装和返回后的列表合并仍未验证，本次不向生产列表追加猜测的刷新。

楼中楼页面 `VitalityFloorViewControllerV2.handleSendReplySuccess…`（0x102f5f384）取返回 pid 交给 `onReplyFloorSuccess:andReplyText:`（0x102f5e7b8），后者更新 floor 模型上下文并调用 `requestFakeWallDataWithReplyPid:`。这里只确认调用关系，不按名称推定其联网次数、审核结果或本地插入行为。相关有界反汇编保存在 ignored `content-plugin-completion.asm`、`content-plugin-handle-completion.asm`、`content-plugin-dismiss-success.asm`、`content-pb-reply-success.asm`、`content-floor-reply-success.asm` 和 `content-followup-*.asm`。这是静态证据，未作整条完成路径运行回放；生产接线、草稿、视觉与安装不变。

## U08 iOS 回复正文路径区分（2026-10-07，迁移中）

同一 22.11.1 包包含旧 `TBCReplyViewController` 和新 `TBCReplyComposeViewController`，不能把“在 iOS 包内找到”当作“用户当次一定执行”。`TBCHybridPBViewController.useReplyCompose`（0x102d546f8）在折叠评论场景返回 false，否则委托 `TBCExperiment.isExperimentForPBReplyCompose`。用户账号当次实验配置未知；本次没有选择或伪造该值。新控制器的发布入口（0x1023ec11c）查询提交 service，`TBCReplyComposeSubmitPlugin` 再执行发送；新旧路径最终均可调用已验证的 `TBCPbReplayModel.postPBContentAndFloor…`。

新插件 `generatePbReplyContent`（0x1023deab0）优先使用非空 currentTextForServer，否则回退 currentText 或空串；不会 trim 或进行旧楼中楼 delegate 的 140 单位截断。仅 isFloor 且非空 atMeString 满足原生 `NSPredicate("SELF MATCHES %@", "回复 [\\s\\S]* :")` 时，使用当前模型的 portrait/name 生成回复 token；缺失值用空串，再拼接原正文。它另有验证重放分支，本次只实现第一次显式提交，未实现或启动该重放。

新增 `NativeReplyComposeContent` 和显式 `NativeWriteContent.replyCompose`，接入 NativeTextWriteClient 的请求前正文准备。不会从业务目标自行猜当前实验路径；新主题误用此路径在 TBS/HTTP 前拒绝。原有已准备正文入口保留，四类原生完整请求字节回归不变。上下文为不可变值，描述全部脱敏；不改用户草稿、界面、旧 Live Repository 或正常安装。

`native-ios-reply-content.json` 的 16 组样本执行真实插件方法，编辑器准备好的文字由合成输入提供，Foundation 原语限定替代，没有执行实际富文本附件转换、SDK、验证或网络。首次使用 Python 正则替代 NSPredicate，直接 iOS 测试发现全角冒号差异；独立宿主 Apple Foundation 探针证实原生谓词也匹配全角冒号。回放改为调用开发期 Foundation 辅助程序，且每组都在 Simulator 核对谓词结果。仅这一个预期结果改正，原失败 fixture 和 xcresult 保留；生产谓词未为迁就错误样本而改变。不能把旧回放的全角冒号结论继续当证据。

旧控制器 `generatePbReplyContent`（0x1023313e4）、富文本 getTextForServer（0x101c44a90）及楼中楼 delegate（0x102f527c4/0x102f7855c）仅完成静态入口定位。旧路径完整正文处理、富文本/上传、新旧入口的运行时选择和完整发布完成仍未闭合；本次新插件的局部验证不等于全部 iOS 回复行为已迁移。

## U08 iOS 原生发送组件串联（2026-10-07，迁移中）

`NativeTextWriteClient`把此前独立验证的单账号状态、缺失TBS补取、四类目标业务字段、Common/签名、原生HTTP、解析及特定响应状态串在一起。有效TBS直接复用；缺失时先完成准确TBS POST再发一次写请求。没有调用旧`TextWriteAccountProtocol`、旧昵称资料查询或Android写接口，也不在失败后回退到旧Repository。NativeWriteOrigin和preparedContent由调用方明确提供，图片/尚未转换的富文本不冒充已支持上传。它仍不是AppCompositionRoot的Live Repository，运行时context provider尚未实现。

runtime在每个实际请求边界提供显式Common/HTTP上下文，并拥有待消费请求统计；不在client里伪造CUID、SDK值、请求日志ID或UA。client保留Common实例，消费并归还统计状态；另校验API、账号材料及TBS属于本次输入。账号/lease在网络前后复核；同一client并行send拒绝，取消不自动重发。出站svcp_stk只来自当前NativeWriteSession，runtime给出的旧状态不能覆盖；解析完成且账号仍有效才接受本次捕获的状态，格式错误/HTTP失败不更改它。解析出的服务端拒绝仍是拒绝，不能因为返回ID而当成功。

新增独立组合样本`native-ios-client.json`：引用已独立回放的5组业务输入，再执行真实iOS动态Common/MD5/返回路径，由包内原生IDL描述符独立编码；Swift完整发送链经过URLSessionHTTPClient/逐请求捕获器到受控HTTPDataLoading边界，比较完整multipart正文，而不是用同一Swift编码器生成期望。包括主题、楼层、楼中楼及有/无标题新帖，4类目标5组；没有执行真实SDK/HTTP或发布。`NativeClientHarnessBridge`复用既有可控HTTP测试器，不创建URLSession。

接线复核发现并直接修复空响应边界：原生`parseBodyIsProtobuf:`在rawData为空时state=4、error reason为server return empty body且IDL调用0次。SwiftProtobuf接受空Data并产生默认errorCode0，因此client必须在调用decoder前拒绝空body。原生单样本真实回放已加入上述fixture；新回归先失败（错误地返回默认DTO、接受空回执header状态2项断言），修正后9项client用例通过。此前8项Session用例亦通过，未删除旧失败记录或弱化断言。这里只补组合边界，不改变原独立decoder对有效Protobuf消息的定义。

完整UEG/账号验证UI、成功关闭及帖子页更新调度、持久账号与真实SDK/Common、富文本/上传尚未接通；返回NativeWriteDecodedResponse不等于UI已获得完整成功事件，更不代表服务端后续审核留存。既有Live路径、正常安装、草稿/缓存/历史/视觉均保持。此次客户端整合验证不能替代这些剩余要求。

## U08 iOS TBS 表单、JSON 与单次准备（2026-10-07，迁移中）

参考仍为用户指定22.11.1 TBClient，SHA `4f0cb74c738f714258dd14bde5fb7a7859ab7baf19183c01e900704ab702d9eb`。`fetchTBSWithUId:andBduss:` 的业务仅BDUSS、POST `/c/s/tbs`、无文件；普通参数标志true使标准及优化Common分支返回合并业务与sign，均不附Proto尾部元数据。新增TBSCommonEmulator执行真实动态Common、MD5签名、`needSig:`（0x1024f0720）、`urlIsSupportLegal:`（0x1024b0dc8）及改名名单（0x1024b1004），两分支均确认TBS不参与额外sig或敏感键改名。运行时provider仍为显式合成输入，不从Android填值。

最终BBA请求边界修正早先仅看到的默认timeout：基类init虽然把0变为20，但`IDPServerAPI`普通BBA构造在0x102663830读取已签表单net_type；0x102663850比较字符串1，匹配时10秒，否则25秒，然后0x102663870调用setRequestTimeout。这不是按isInstantRequest判断。`BBAAPIRequestTaskDispatcher.urlRequestForRequest:`（0x10461e768）普通POST体使用`BBAAPIRequestHelper.formatParams`（0x10463b688），Content-Type为application/x-www-form-urlencoded。`encodeURL:`（0x10463bf64）从URLQueryAllowedCharacterSet移除 `:#[]@!$&'()*+,;=`，空格为%20、保留/与?；原生按50个UTF16单位的完整组合字符范围分段编码。Swift使用同一Foundation字符集一次编码完整字符串，不套用遗留的+空格编码器。字典枚举顺序非契约，Swift按键排序只保证本地可重复性；不声称整个请求逐字节同序。以上表单及timeout来自有界反汇编，编码回归不是完整原生网络执行样本。

`parseBodyIsProtobuf:`（0x1024b5db0）对TBS使用false分支：UTF8→JSON字典，顶层error_code非零优先，否则查error/errno；二者都不存在则解析失败，JSON的任意非零码都失败。`IDPExtension.stringAtPath:`（0x10265b16c）对NSString原样返回、NSNumber转longLongValue十进制、其他类型nil；error码之后按NSString.intValue判断。completion（0x101c26318）先释放protectLock，仅state3且顶层tbs非空时按捕获UID保存并通知。TBSResponseEmulator实际执行parser、stringAtPath与completion，JSON/Foundation primitive显式替代、DB/通知仅计数；22样本覆盖错误优先级、负码、缺失、类型、嵌套误取、空值及无效JSON。没有实际网络或账户DB访问。

新增NativeTBSRequest/ResponseDecoder和NativeWriteSession.prepareTBS：复用已有有效TBS，缺失时最多一个显式补取，失败/取消释放本次操作，不自动重试；返回期间账号lease变化拒绝旧结果，昵称更新不被TBS覆盖。request构建回调只能返回该准确TBS POST目的地。沿用现有HTTPClient，重定向/响应大小保护不变，不创建第二套网络栈、不接受非UTF8回执、不写浏览数据。TBS表单签名入口复用已验证的Common组件。26项相关Unit通过，格式修正后受影响12项再次通过；既有Proto签名/账号回归通过。实际账号来源、持久化、运行时SDK/Common、富文本/上传和Live发送调度仍待接通，不将这些组件通过等同于完整迁移或删帖问题解决。


## U08 iOS 条件请求 Cookie 与 TBS 入口（2026-10-07，迁移中）

22.11.1 `TBCServerAPI.addExtraCookieParams`（0x10025d9ec）先调用 `shouldKeepAlive`（0x10025de04）：netStatus=1取keepAliveWifi、=2取keepAliveNonWifi，其他状态为false。开启时创建ka=open；`shouldGoSmallFlow`（0x10025df50）独立读取策略，开启时以其pubEnvValue创建pub_env。它们不是Android路径里的固定Cookie。Cookie域/路径为.baidu.com和/。本次CookieEmulator执行三个真实方法，配置、网络、时间与Foundation为显式合成替身，禁用HTTP DNS分支；12例覆盖两个网络配置、无网络/未知/负值、两个条件独立、nil/空值。原11份fixture逐字节不变。

`IDPServerAPI.bba_uploadWithMethod…`（0x102663bb4）把数组传入setRequestCookies；`BBANormalAPIRequest.applyCookieHeader`（0x1046113bc）调用系统requestHeaderFieldsWithCookies并设置Cookie头，requestHeaders（0x1046110dc）转为最终字符串字典，经已查证multipart路径加入URLRequest。全局Cookie jar是另一个shouldHandleCookies分支，未作为本次输入来源，也未读取官方App或浏览器Cookie。NativeWriteRequestCookies只处理两种已证实的配置值；新NativeWriteHTTPContext显式要求这些输入，借同一Foundation工厂生成出站头，继续关闭URLSession的全局Cookie处理。CR/LF拒绝是本App的输入校验；临时配置Cookie不落盘，不声称复刻原版Cookie持久化/HTTP DNS。旧HTTP envelope fixture明确未覆盖Cookie，因此原样保留，新增单独回归。

TBS补取静态链进一步闭合到参数模式：fetchTBSWithUId:andBduss:（0x101c2615c）使用https://tiebac.baidu.com、timeout=0，基类initWithServer:timeout:（0x102664038）将非正timeout变为20秒。accessAPI:WithParams:files:completionBlock:（0x1026646e8）以默认method=0转发，files=nil，业务只有显式BDUSS；URL为/c/s/tbs。普通参数入口addExtraParams（0x1002463c8）传includeRequestParams=true，与发帖的Proto common-only=false不同。标准公共参数在0x1024b331c为true时返回已合并业务与sign的字典，跳过Proto专用的package_version/实验元数据附加。needSig名单（0x1024f0720）及敏感参数改名名单（0x1024b1004）均没有/c/s/tbs；不能据此类推到其他端点。表单最终编码、JSON解析及实际TBS网络提供者仍未完成，未接入Live。

此处只修正新原生构造器的遗漏，未改变旧Live Repository、登录/Keychain、阅读和视觉。组件回放/测试不证明完整SDK环境一致或异常删除根因。

## U08 iOS 当前账号昵称更新（2026-10-07，迁移中）

`TBCAccountSettings.getUserNickName`（0x101c24efc）直接返回userNickName；登录数据更新块0x101c25ef4分别从UID、UNAME、UNAMESHOW更新ID/登录名/昵称。清账号块0x101c25e9c分别清这三个值。发送中的name_show读取这个昵称属性，不能直接把界面展示fallback标签写入。

进一步追到`TBCPersonalInfoModel.handleParsedData:`的主线程完成块0x101e19970：先确认profile.user.uID与当前账号UID相等，才处理当前账号信息。昵称优先uNameShow；nil、非字符串或空时回退该profile的uName。候选非空且与缓存不同时，调用updateUserNickName，按原账号UID保存到UNAMESHOW、重新读取登录数据并通知更新。`TBCTabBarController.NoUserNameAccountLoginFinished:`（0x101f8cfac）也有显示名/登录名回退和保存；同时使用SAPIMainManager.currentLoginModel更新账号并补取TBS。这证明原生存在该回退，纠正“昵称缺失永远只能为空”的Android推断；但不代表可以把遗留BDUSS登录模型当作整个Passport主登录路径。

新增封闭AccountNameEmulator执行上述profile完成块的UID检查及昵称选择/更新，直到0x101e1a0a4或非本账号出口0x101e1a23c；其他profile权限/缓存效果、DB写入与通知均明确拦截，账号与profile全为合成值。11例覆盖同名、空/nil回退、两者缺失、错账号、无账号、无缓存、空白保留及Unicode字面差异。NativeWriteAccountName转录这些规则，NativeWriteSession接收带发起AuthContext的已解码profile，只更新本账号内存昵称，保留TBS/其进行中操作；旧lease即使同UID也拒绝。实际资料请求、持久写入与登录准备接线尚未完成，不调用旧Android账号预请求替代，也不改Live路径。

## U08 iOS 公共参数的两条构造分支（2026-10-07，迁移中）

同一22.11.1主程序：`commonStaticParameters`（0x100249eb0）按tbEnableYaloggerLog选择全局缓存路径或`commonStaticParametersNew`（0x1024b12c4）的重新计算路径。缓存路径只在首次填入版本、系统、屏幕及SDK provider值，后续更新隐私条件下的标识与pure_mode/xcx_mode；重新计算分支不覆盖旧静态缓存。两个分支均由真实ARM64方法回放，9个合成序列/15次调用覆盖nil、空值、隐私切换、缓存和切换分支。`%.1f`格式用于屏幕尺寸/scale，imageQuality为整数格式；pureMode/xcxMode是字符串。event_day由原生`YYYYMMdd`日期格式器提供，本组件接收其输出，不偷换成Android日期/设备常量。

`addExtraParams…`动态部分0x1024b1e74到0x1024b2f94；isEnableSignOptMode与覆盖配置可改走`addExtraParamsWithRequestParams:`（0x1024b3804）。原生Proto调用参数为false，因此两条路径均不执行仅表单开启的敏感键改名。非空sample、浏览模式、client_id/extra默认值、个性化配置回退、当前账号材料、可选SSDK值、秒转毫秒的时间格式、keep-alive/small-flow、tbs格式化及启动来源均按显式provider输入核对；不初始化或伪造这些provider。原生楼层name_show使用getUserNickName，昵称缓存的原生更新/回退流程见上节，不能由UI标签或Android默认值替代。

优化分支使用`safeSetString:forKey:`（0x10265b6f8），nil/空值不写入且不删除已有键；标准分支部分字段保留空字符串或用nullable下标删除。sample_id在优化分支为空时因此可能保留旧静态值。上一请求统计是例外：两条分支均使用普通下标setter；只要旧api非nil（即使为空字符串）就写入m_api并消费统计。logid/result/upload/download非零才写，cost总是写为`%f`并清零；api为nil时整组不消费。24个原生回放同时断言字段、选择分支及消费后的状态，包含64位/无符号上界，没有使用浮点数替代整型ID。

新增NativeWriteStaticCommonParameters、NativeWriteDynamicCommonParameters与组合入口，只接受明确上下文并返回待签名/已签名Common，不执行网络。签名后的标准分支仍追加package_version/实验元数据；优化分支直接返回公共副本与sign，不追加这两项。封闭回放继续穿过动态构造、原生合并/MD5与返回边界（标准0x1024b3458、优化0x1024b45b0），6个样本由独立descriptor编码比对。静态Common来自单独验证的原生输出，运行时SDK/账号/时钟仍是显式合成替身，不能把这些样本称为完整官方App运行。

以上只推进有证据的公共参数转换；实际provider及持久账号准备、TBS HTTP、完整UEG/完成回调、富文本与上传仍未接通，Live路径和正常安装未改变。不据此推断异常删除原因或宣布完整对齐。


## U08 原生回执编码与编辑器完成条件（2026-10-07，迁移中）

来源继续是同一22.11.1主程序。独立descriptor：AddPost响应文件偏移0xa6ece2f、1193bytes；AddThread响应0xa6ee253、964bytes。两个外壳均error#1/data#2，Error(errorno#1 int32、errmsg#2/usermsg#3 string)，data.tid#2/pid#3 string、info#14 PostAntiInfo、anti#17 VcodeInfo。新增NativeWrite.proto响应子集只转录需要的回执/验证字段；其余作为unknown fields，不导入Android响应类型，也不采集access_state.userinfo中的账号材料。

NativeWriteResponseDecoder独立解析该子集，区分payload存在性、原始ID、正错误码拒绝、原生错误类别/账号动作。不会用need_vcode/vcode_type等元数据非空覆盖零错误码；没有把解析通过直接作为最终编辑器结果。correlatedReceipt是TiebaLite既有目标关联保护：完整正ID且属于当前目标才产生回执，缺字段/错帖不能清用户草稿；不能把这一额外保护冒充原版完整UI条件。13份纯合成wire由参考descriptor独立编码，类别/账号动作仍用原生方法封闭回放，旧84份样本未改。

补充实际UI证据：TBCReplyViewController.setupModel(0x10231c974)安装completion block 0x10231ca9c；该block调用isNetworkRequestSuccessful，TBCBaseModel实现0x10025fa24对短连接要求procState=3、serverApi.state=3并且model.error为空。成功路径清对应草稿并调用onCompletion(0x102332e40)；后者仍有UEGPass和编辑/草稿分支。这个网络成功谓词本身不检查pid，也不能简化为任意anti字段非空即失败。未执行完整UI或最终delegate刷新，因此不声称已复现原版完整关闭/刷新链路。

本批组件仍未接入Live，UI和原发送逻辑未修改；Common运行时来源、原生账号准备/持久化、完整UEG、上传及统一发送接线尚未完成。没有通过真实发送测试审核，也没有改变安装候选。

## U08 原生回执错误分支（2026-10-07，迁移中）

同一22.11.1参考的IDPServerAPI.commonHandleRequestWithResponseData:requestHeaders:（0x102664a9c）依据请求x_bd_data_type选择Protobuf解码。子类实际实现为TBCServerAPI.parseBodyIsProtobuf:（0x1024b5db0），不是IDPServerAPI的空方法。传输已成功的Proto分支由requestCMD选择IDL解码，从返回data/error取模型；正errorNum设失败state4并构造errno/errmsg/errInfo，非正值保留成功传输state3并设置protobufParserData。此状态不等于发布完成，后面仍有业务模型/UEG/UI路径；不能仅凭这个分支宣布成功。

ResponseEmulator执行以上方法，以明确合成IDL解码模型、HTTP200及封闭Foundation代替真实网络。三例涵盖零错误、零错误附验证描述、正错误；零错误附描述在此层仍为state3。另直接执行TBCUEGManager的10个纯错误谓词（0x101c8c9e8、0x101c8cb20..0x101c8cbfc），22个边界输入覆盖验证码5/6、短信3250012、禁言/封禁3250001...3250004、实名1990055、异常227001、文字220015、频率220034、禁言230277、申诉3250013与MCN限制1211067。它们是原生谓词事实，不代表所有返回码或完整路由优先级。

TBCUEGPassManager实际分支0x1021fcf10读取serverApi.error.userInfo.errno/errInfo：1触发账号重新登录，3250017绑定手机，3250020/3250021仅在非空NSString pass_token时验证身份，3250022改密码，3250023人脸验证；其他返回false。30组合回放截获这些动作名称，不执行账号删除、SDK、界面或网络。新NativeWriteResponseRules只保留这些有证据的分类/动作判断，不执行动作，不凭anti字段存在猜测验证，不改旧Live回执，完整模型回执和验证界面仍待接线。所有材料均为合成，无用户凭据/正文。

## U08 原生签名作用域与格式（2026-10-07，迁移中）

22.11.1 `TBCCoreSign.tiebaSignKey`（0x1070d2560）只返回协议常量；在内存中比较确与仓库既有公开Android签名后缀相同，未读取或复制SDK接入key/secret或用户凭据。`getSignWithParams:`（0x1024b4638）对键以 `compare:options:2` 排序（literal比较，block 0x1024b47f4），拼接未经URL编码的 `key=value`、无分隔符，附协议后缀。`NSStringUtils.md5:`（0x1022bd39c）使用UTF-8数据与CC_MD5，最后以16个 `%02X` 输出32位大写十六进制；既有Android实现为小写，不能直接把旧输出复用于原生。

新增 `CommonSigningEmulator` 从真实函数的0x1024b2f94进入、到0x1024b3458清理边界停止，以显式寄存器/栈局部模拟“运行时Common已经准备完成”的状态。它执行原生copy、业务覆盖合并、HTTPS stokenFilter、签名、返回公共字典及签名后元数据追加，MD5格式执行原生方法，CC_MD5由离线hashlib等价替代。5组回放覆盖普通回复、新主题、业务/公共tbs冲突、nil/变更元数据以及显式不透明sig替身；没有执行较早的账号/设备/SDK取值，不称为完整Common或原版App运行。

HTTPS过滤（0x1024b7610）在isHttpsRequest为真时直接返回，stokenLeakFixSwitch打开也不去掉stoken。签名输入为公共与业务合并字典，业务值优先；返回的是合并之前的公共副本加sign，业务独有字段（如floor）参与签名但不进入Common IDL。`package_version`及`abtest_config_intervention`在签名之后加入公共副本；后者 `%@^%@` 对nil采用NSString的 `(null)` 字样。不能签名最终已追加元数据的字典来替代这一顺序。

原生可选 `common.sig` 不在Common描述符中，IDL会丢弃；这批不重建TBCProcEncryption的接入实现或将其提升为data.sig。新Swift组件只生成传入字典在这个Proto分支的可序列化公共结果，使用CryptoKit，不更改Android签名或Live写路径。独立Python IDL核对生成的5组字节；其中不透明sig有/无时字节相同。这不是说业务data.sig永远无用，也不推论z_id/其他SDK上下文可以随意省略。


## U08 原生 HTTP 封装（2026-10-07，迁移中）

2026-10-08 地址证据更正：此前 HTTP fixture 仅覆盖 headers/part/body，没有覆盖最终 URL，Swift 测试中的 `query == nil` 缺乏原生依据。用户本次手动发送的白名单诊断为账号 HTTP200/JSON error_code0，回复 HTTP200/137bytes/JSON error_code110001，无 Protobuf payload 或有效回复 ID；未保留原始正文/凭据。错误码含义未独立证实，不能解释为封禁或成功。

同 SHA 22.11.1 的 `TBCBaseModel.loadInnerWithShotConnection`（0x100248dac）中 0x100249044–0x100249168 明确在 messageRequestType=3 或 shortAsLongConnection 且 command>0 时追加 `?cmd=%ld`（已有 query 则 `&cmd=%ld`），设置 serverApi.requestCMD；后者>0 时追加 `&format=protobuf`。`getProtobufRequest`（0x100249d80）同样以该 command 选择二进制分支，不能仅复制二进制 body 而遗漏 URL 路由。`IDPServerAPI.accessAPI:WithParams:files:requestMethod:completionBlock:`（0x1026641b4）随后把 server+address 交给 HTTP 请求，不删除 query；realAPIKey 的去 query 仅用于键计算。

`emulate_url.py` 在上述地址块执行原生 ARM64，6 组显式合成输入覆盖 post309731、thread309730、已有 query、shortAsLong 及两个不追加分支；结果固定于 `native-ios-request-url.json`，运行前检查参考程序 SHA，截断在网络派发之前。原生回复地址 `/c/c/post/add?cmd=309731&format=protobuf`；主题相对地址 `c/c/thread/add?cmd=309730&format=protobuf` 经既有 host/path 拼接成为绝对地址。Foundation 字符串和状态 getter 为替身，不是完整 App 或实网回放。

本轮仅修正 NativeWriteHTTPRequest 的 URL，复用既有 command(for:)；账号、业务/签名/body/header、请求次数/顺序、回执/刷新与 SDK 缺口不变。请求地址遗漏与回包 JSON/未知状态相符，但修后服务器是否接收和审核保留仍待用户真实操作，不能以离线通过声称完整对齐。

仍以同一 SHA 的22.11.1主程序为准。BBAAPIRequestManager 的 tb_sharedInstance block（0x103211ea0）按配置选择 TBTurboNetRequestManager 或 BBAAFNetworkingRequestManager；前者继承后者且没有重写 urlRequestForRequest。两者的上传请求因此都走 0x1046297ec 的 AF multipart 分支，构造块 0x104629a50 将现有 fileData/key/fileName/mimeType 原样交给 AF。IDPServerAPI（0x1026636e8 / 0x102663bb4）在 Proto 分支把二进制放入 data 文件项，name=data、filename=data、mime=image/jpeg；上游 getProtobufRequest 非空时 params=nil，因此普通路径没有外层业务或认证表单项。这是指定静态分支的调用链，不是当前手机完整抓包。

新增封闭回放 HTTPEmulator：执行 TBCServerAPI.addExtraHttpHeaders（0x10025d3ec）和 AFStreamingMultipartFormData.appendPartWithFileData（0x104311458）。4组纯合成输入证明 x_bd_data_type=protobuf、UA来自provider、client_logid为0/-1时省略、其余保留64位精度，以及自定义svcp_stk透传；文件段的Content-Disposition/Content-Type和字节由原生方法生成/传出。fixture不包含真实UA、Cookie、账号或设备值；没有网络出口。

AFHTTPBodyPart.stringForHeaders/contentLength/read（0x104312ad8 / 0x104312d28 / 0x104313034）使用标准CRLF、首个 `--boundary` 与末尾 `--boundary--`；header经NSDictionary allKeys遍历，没有稳定字节顺序保证。AF init（0x104310ab4）boundary格式 `Boundary+%08X%08X`；finalize（0x104311880）设置Content-Type及实际Content-Length。原生serializer的Accept-Language来自系统偏好，最终请求的UA来自TBCUserAgentGenerator。响应允许的MIME与出站Accept不混用。

实现复用现有EndpointRequestBuilder的body编码，仅开放模块内encode入口并允许合法boundary字符 `+`；beta3保护保留原摘要，只允许精确逆向这两处已授权差异后验证原文件。原有makeRequest与multipart旧输入输出不变。原生封装需要调用方显式提供完整公共字典、UA/Accept-Language/clientLogID/timeout和当前会话的响应状态，不默认猜测这些来源。保持一次发送，不添加自动重试。

尚缺完整运行时Common/签名和登录准备接线。HTTPDNS/keep-alive/小流量Cookie分支、TurboNet的条件X-Bind-Mobile/X-Delegate-Callback、服务端配置实际值也未全部闭合；这批不伪造这些字段，不宣称整个官方HTTP环境或审核结果一致，不启用未完成的Live迁移。


## U08 原生账号准备及响应状态（2026-10-07，迁移中）

参考仍为用户指定22.11.1 TBClient，SHA `4f0cb74c738f714258dd14bde5fb7a7859ab7baf19183c01e900704ab702d9eb`。新增封闭离线回放 `emulate_account.py`：`newGetUserTBS`（0x101c254e8）6个纯合成输入证实先查当前UID的KV，后查登录DB，非空DB值会种入KV；二者缺失且登录DB含UID/BDUSS时触发补取，getter当次仍返回nil。无登录记录/空UID不请求；没有TTL或每次发送login的分支。`fetchTBSWithUId:andBduss:`（0x101c2615c）的protectLock限制单次补取；completion（0x101c26318）先解锁，仅state3且top-level tbs非空时按请求捕获的UID保存，不能使用返回时的新账号UID。这些回放替代了KV/DB/Foundation及网络出口，未执行真正登录、磁盘保存或TBS接口。

`ymgScscParseFromResponseHeader:`（0x1024769ec）6个回放样本保留原生正则 `__ymg_scsc=([^;]+)` 的第一个非空匹配语义，含“第一个值为空、后一个值非空”。回复 `handleVerifyData`（0x10245c49c）/新主题 `handleVerify`（0x10248f288）从实际request的responseHeaders取该值，非空更新IDPCache；两者 `customHeaders`（0x10245ea04 / 0x10248f3f8）读取 `svcp_stk` 回传，无新值不清旧值。当前App全局transport丢弃Set-Cookie，不能直接实现此闭环。

原生迁移组件：`NativeWriteSession` 绑定明确的账号元数据及现有AuthContext，复用TBS，仅缺失时产生一个可完成的补取操作，失败/空值释放操作；结果受操作身份和原lease保护。`NativeWriteTransport` 通过每次请求独立的HTTPDataLoading适配复用现有URLSessionHTTPClient，只为HTTPS原生发帖/回复端点捕获上述一个值；完整Set-Cookie不进入普通HTTPResponse或全局Cookie jar。解析响应后由repository显式接收状态；捕获不意味着发送成功。会话隔离、失效清除、目标/HTTP过滤是TiebaLite边界保护，不宣称已从原版全局IDPCache查到同样账号清理规则。

尚未接入Live、当前账号持久元数据提供者、TBS请求的完整common/签名/传输及回执调度。getter不等待网络的原生事实不等价于这些组件已补齐原版整个登录/发送生命周期。测试不能证明完整迁移、实际账号请求数或删除原因。


## U08 22.11.1 原生编码迁移（进行中）

用户明确要求持续完成发帖/回复对齐。本地 ARM64 离线模拟执行 `TBCPbReplayModel.postPBContentAndFloor…`（`0x10245d3dc`），仅运行该方法与两个纯场景转换方法；Foundation、账号、位置和网络均由显式合成替身提供，未知调用立即失败。普通 PB 场景得到 `anonymous=0`、业务 `tbs`、`send_from=pb_reply` 等业务字段，发送出口被拦截一次。此结果证明给定输入下的业务分支，不是完整 App 运行、真实账号上下文或服务端审核证据。模拟器脚本及每个替身输入保留在 ignored 分析目录。

新主题 `TBCSendThreadModel.setupConfig`（`0x10248ee4c`）使用 `c/c/thread/add`，Proto 分支 CMD `309730`；回复 CMD `309731`。从相同 SHA 的程序提取 FileDescriptorProto：`client.proto/CommonReq` 87 字段；AddPost DataReq 80 字段；AddThread DataReq 95 字段（最大 tag97）；全为 proto2 optional。只转录这三个请求消息的字段名/编号/类型，不导入整个 client.proto，不复制参考程序/SDK或密钥。`Config/Protobuf/NativeWrite.proto` 与生成输入摘要独立记录来源，原 Android 234 文件闭包保持。

当前工作先提供字段存在性和原生新主题/回复的编码边界，Live Repository 尚未切换。编码器不生成或猜测安全上下文、不读取账号、也不发送；输入必须由后续已验证的账号/公共参数准备提供。不能把这一步的 Unit 通过标记为完整发送迁移或安装验收。

补充本轮实现：`NativeTextWriteParameters` 只实现显式上下文下的普通文字分支，不选择实际页面入口、不转换富文本、不上传。`TBCHybridPBViewController.syncReplyDimensionsWithCell:` (`0x102cfece4`) 给 PB 场景/容器各赋 1；`VitalityFloorViewControllerV2.syncReplySceneToComposeWithType:` (`0x102f4d590`) 给楼中楼容器赋 2。离线三个模型输入分别得到 `pb_reply` / `pb_sub` / `pb_sub_subsub`；不能将它们当成所有页面的统一来源值。子回复 `repostid` 会改用父 `quote_id`。新主题 `TBCComposeSendThreadPlugin.sendThreadCommonParams` (`0x1018b4d2c`) 在纯文字、入口1、composeType0的显式合成上下文产生22字段；无标题另有 `st_type=notitle`。这五个输入和结果已固定为 fixture，生成器为 `scripts/fixtures/native_write/generate.py`。

签名层级校正：`getProtobufRequest` 以 false 调 `addExtraParamsWithIsContaintRequestParams:`，后者先保存公共字典副本，再合并业务字典计算签名，最后把 `sign` 和条件 `sig` 放入返回的公共字典。不能据此推出 `data.sig` 必定出现在最终 Protobuf 中：CommonReq 没有 `sig` 字段，`TBCIDLBaseTransform.initMessageWithDic:message:` (`0x1024dc26c`) 查不到描述符的键会跳过，没有在此处将公共 `sig` 提升到业务层。当前证据尚未闭合完整签名发送路径；此前静态记录中的“额外业务 sig”不是已验证的 wire 事实。编码回归明确禁止自动提升未知公共键；独立 schema 样本中的业务 `sig` 仅验证调用方显式提供该字段时的编码。

最新用户指定（2026-10-07）：接受用户确认发帖正常的去广告版为行为参考；主要基准更新为22.11.1（TBClient SHA256 `4f0cb74c738f714258dd14bde5fb7a7859ab7baf19183c01e900704ab702d9eb`），22.7.3保留对照。用户已明确授权迁移发送行为，不再以旧beta3冻结或无现成抓包作为授权阻碍。已补核实专用TBS端点、原生签名/返回状态、新字段send_from #80及SSDKLib上下文provider边界；详见WRITE_MODERATION_COMPARISON最新节。尚未实现完整原生链路、未确定删帖原因；不把用户成功反馈说成逐字段抓包证据，也不把SDK字段存在说成必填。生产及安装未变。

## 2026-10-07 U08：官方衍生 iOS 22.7.3 的只读静态证据

用户提供解包 TBClient，SHA256 `67867b7abaa8fbdf1a754038325f20431ad07f60be8afe35de088f51704c03c0`，版本22.7.3/22.7.3.0、cryptid0。包含去广告注入，未执行。来源、未加ASLR方法地址、字段类型和精确差异见 `Docs/Audits/WRITE_MODERATION_COMPARISON.md` 顶部；ignored静态产物在 `Artifacts/VisualReview/U08/official-ios-comparison`。它更新“没有官方二进制”的证据状态，不替代原Android来源或实际运行样本。

TBCReplyViewController → TBCPbReplayModel → TBCBaseModel/TBCServerAPI → CMD IDL/multipart 路径已找到。已证实同回复path/CMD，但初始anonymous、业务tbs、账号准备、客户端公共上下文、签名范围及响应header状态回传不同。AddPost本地67项与官方对应tag/type相符，Common本地45项亦相符；没有据此修改生成代码或认定额外字段全部必填。Protobuf开关等为远端配置分支，成功手机当次值未知；未提取凭据、设备标识、正文或嵌入密钥。

这只是 `STATIC_BINARY_EVIDENCE`，不是官方实网发帖契约或服务端删除因果证据。没有构造新的生产发送器/回执规则，没有新增Fixture宣称通过，没有Live写入；保持冻结beta3实现和全部用户数据，直到实际选路/上下文来源具备可验证的完整契约。22.11.1、新主题/上传等完整行为未完成对照。

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

### U08 已发布但回执未确认（2026-10-07）

USER_REPORTED：用户确认回复已显示，但编辑器出现结果未知提示。旧响应未保留，不能推断发送成功就代表当前回执 decoder 已成功。CODE_EVIDENCE：锁定 AddPostResponseData 的 tid=2/pid=3 均为 string；Android AddPostRepository 要求 pid 可转为整数，ReplyPage 收到成功后删除对应草稿并返回。iOS 当前 MIME/解码/ID/发送后会话检查均可能落入 resultUnknown，原因仍 UNKNOWN。本轮仅加 Debug-only 元数据观测，使用原 HTTPClient 和原 pipeline，只记录固定类别/布尔/计数，不保存响应或 ID 值；未修改请求、成功条件或重试规则，未自动发送 Live 内容。详见 UNKNOWN_BEHAVIORS 的 U08 条目，待用户主动发送取得实际分支后再修正。

RUNTIME_EVIDENCE补充：用户于同日再次亲自发送，脱敏记录为HTTP200/208bytes，MIME类别protobuf（对应唯一白名单常量application/protobuf），payload protobuf，hasData=true，serverRejected=false，postID positive，threadID matches-target，pipeline unsupported-content，repository result-unknown。证据仅为固定元数据，未保存真实响应或业务ID；ignored路径receipt-diagnostic/live-response-metadata.json。据此仅在write.post响应白名单补application/protobuf；仍按锁定schema解码、要求正pid、核对非空tid、优先处理验证码和非零错误。不修改write.thread或共享EndpointPipeline。U08WriteReceiptTests以合成响应及MockHTTPClient复现并验证单次请求/Composer回执，UI本地服务同样通过生产pipeline解析这一MIME。临时诊断已完成定位用途，最终候选移除观测代码；用户修后实网验收仍待执行。

### U08 回执成功与附带验证描述的优先级（2026-10-07）

USER_REPORTED：MIME修复后用户再次发送，回复已实际可见，编辑器却显示本地verificationRequired文案。这次没有保存响应，具体由anti/info哪一字段触发仍UNKNOWN，不能声称观察到了某个实际vcode_type值。CODE_EVIDENCE：iOS旧decodePost在检查error/pid/tid之前，仅凭非空anti.vcode_type（包括字符串0）、md5/url或access_state.type就报验证；这段规则没有Android来源依据。Android RetrofitTiebaApi.createProtobufApi接入ProtoFailureResponseInterceptor，后者只在非零error_code时抛失败；随后AddPostRepository.addPost要求可解析的新pid，ReplyViewModel进入Success，ReplyPage关闭并清草稿。没有用附带anti/info描述覆盖已确认的新回复。

修订契约：AddPost的error_code为0、服务器pid为正且返回的非空tid匹配捕获目标时确认成功，附带anti/info不推翻本次回执；非零错误绝不成功，仍在未确认成功时根据need_vcode或具体验证码材料分类为verificationRequired。类型描述或access_state.type本身不足以断言需要验证码；无有效回执也不据此猜成功。保留非空tid不匹配拒绝、会话校验、一次请求、草稿及未知结果不自动重发。只调整AddPost结果判定，不变更请求/验证码能力或AddThread JSON。合成表驱动测试覆盖全部旧触发字段，不把这些构造值当作Live采样值。

### 发布后删除通知与兼容性证据边界（2026-09-25）

USER_REPORTED：用户报告经当前应用发布的一条主题回复收到“涉嫌异常行为”删除通知。`WRITE_MODERATION_CAUSE_UNKNOWN`；这证明有实际删帖反馈，不证明账号封禁或某个请求字段触发。R09/R10 的历史用户确认只覆盖当时发送/可见，不覆盖后续审核。

CODE_EVIDENCE：重新检查锁定的 Android protocol/UI 两版，11个发布链相关文件和 addPostFlow/addThreadFlow 方法一致。当前 iOS 与原版的确定差异包括：每次发布前获取账号资料、缺少业务显示名、裁剪后的客户端公共上下文，以及新帖使用 HTTPS。默认 UA 和回复版本与原版默认相同；没有发现应用层自动重发循环。缺少这次即时发布响应及平台审核理由，不把差异当作删除根因，也不补造验证/设备信息。完整来源、静态检查范围和未验证项见 `Docs/Audits/WRITE_MODERATION_COMPARISON.md`；本轮无 Live 请求或生产实现变化。

## R10 图片上传（CODE_EVIDENCE + 用户手动端到端 RUNTIME_EVIDENCE）

UI参考 c5f1125：`components/ImageUploader.kt::uploadSinglePicture` 分块512000，普通5MiB/原图10MiB；`api/retrofit/interfaces/OfficialTiebaApi.kt::uploadPicture` POST `/c/s/uploadPicture`，JSON。`RetrofitTiebaApi::OFFICIAL_TIEBA_API` 基址 c.tieba.baidu.com；采用HTTPS安全适配（用户单图主题回复验证见下文，未采集原始响应），_client_version=12.41.7.1，User-Agent同版本，BDUSS及公共字段由 CommonParamInterceptor 注入，multipart非文件字段由 SortAndSignInterceptor 签名，文件chunk不签；StParamInterceptor对multipart不增加遥测。接口删除Charset/_client_type请求头及naws_game_ver/sdk_ver表单；Cookie仅ka=open（不伪造BAIDUID）。不虚构设备/安装/追踪字段。

业务字段：alt=json、chunkNo从1、forum_name/small_flow_fname=真实吧名、groupId=1、height/width、isFinish=0/1、is_bjh=0、pic_water_type=2、resourceId=文件MD5+512000、saveOrigin=0、size=实际字节数。文件part name=chunk filename=file。响应 `UploadPictureResultBean`: error_code/error_msg/resourceId/chunkNo/picId，最终picInfo.originPic.width/height。分块序号必须匹配，最后真实picId及正尺寸齐全才算成功；非零代码/畸形响应不继续发帖。

`ReplyPage` 最多9张，只在发送后upload，成功按顺序拼 `正文\n#(pic,picId,width,height)`；表情插入 `#(名称)`，复用 R07 目录。fixture为完全虚构 picID/尺寸，自动化不发送Live。对应 ADR-0028。Live最终发布只由用户本人进行。

RUNTIME_EVIDENCE（用户手动上传并发布，2026-09-24）：用户确认“都正常，图片和表情包都正确，可以提交了”，并提供完整 Live App 的高通吧帖子第14/15楼截图；第15楼含文字、已渲染滑稽及一张 LOCAL PHOTO 4 图片。证据：ignored `Artifacts/VisualReview/R10/UserApproval/user-confirmed-live-image-emoticon-reply.png`。此记录只证明当前账号的一次单图加表情主题回复端到端成功；没有原始上传响应、picId 或发布响应采样，不将其推定为所有账号、四种写入目标、多图发布或 Live 重试全部通过。AI 未触发 Live 上传或发布。


### U08 与已发布 beta3 的请求差异纠正（2026-10-07）

USER_REPORTED：当前Simulator回复被删，手机v0.2.0beta3可发送。CODE_EVIDENCE：基线4534020中EndpointRequestBuilder也从allowedResponseMIMETypes生成Accept，因此先前只补MIME的修改实际增加了出站application/protobuf。此前“请求不变”描述不准确；当前给EndpointDescriptor独立的可选requestAcceptMIMETypes，仅AddPost指定旧版两项，默认行为保持兼容。响应仍严格按已观察的三种MIME解码，成功及错误判定不借本轮再变更。该差异与服务端审核的因果关系UNKNOWN，不推测或伪造验证字段，不执行Live发送。

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

### 2026-10-07 用户指定 beta3 完整发送基线（当前实现）

用户明确要求与手机已确认可用的 `v0.2.0beta3` 完全对齐。本节覆盖下方 U08 历史方案；不再只对齐出站 Accept。基线提交 `4534020d509ea0188dced53cf582fcc775dbb71e`。

- 已恢复 Endpoint/Builder/TextWriteProtocol 完整文件：请求 Accept 与响应 MIME 使用旧版同一集合，AddPost 只接受原两种 MIME；验证码相关字段先于 error/pid/tid 的原判断顺序完整恢复。此前 MIME 扩展和成功优先均已撤回。因此旧版对 application/protobuf 的“结果未知”和附带验证字段提示也可能重新出现；不能私自兼容后仍声称完全一致。
- 发送成功的原顺序：清对应草稿 → 记录回执 → 收起编辑器 → sheet didDismiss 执行一次回调。帖子用原 reload，楼中楼用原 refresh；均按原 U03 当前阅读页机制保留已加载范围/锚点。撤回 U08 的 target 回调、lastReplyReceipt、父楼/末页选择、dirtyPages 和成功后追读新页；没有额外同页读/轮询/重发。
- TextComposerStore 发送主体、TextComposerService present/didDismiss、账号准备、签名/编码、四类目标、上传、网络和 Session 的既有代码与 beta3 对照一致。保留 U08 本地草稿落盘及图片文件所有权、草稿恢复就绪门槛、账户隔离清理；不将这些明确的本地存储差异或 U07 已验收外观说成全 App 字节一致。账号变化新增的强制关闭编辑器已撤回。
- Specs/WRITE_BASELINE.json 固定 beta3 源码/接线摘要；make write-baseline-check 纳入 lint。AGENTS.md 禁止今后未经新的明确授权改变这条链路或更新基线。没有任何 Live 发送、上传、重发或审核探测。源码/Mock 通过不证明服务端删帖原因已解决，MODERATION_CAUSE_UNKNOWN 保留。
