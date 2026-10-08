# ADR-0027：文字发帖与回复

## 2026-10-07 后续授权：迁移至用户指定的原生22.11.1行为

用户已明确授权持续完成原生发送对齐，本节优先于下方beta3冻结决定。当前先落地有来源的文字业务构造和原生IDL编码及定向回归；生产Live发送仍保留旧路径，直到账号准备、Common/签名、响应状态和验证形成完整接线。不得仅重置旧摘要冒充对齐，不自动进行真实发帖、回复、上传或重试；不改变已验收外观、草稿和阅读行为。

### 原生公共参数边界

静态/动态Common按22.11.1真实方法分别实现，并在NativeWriteCommonParameters组合：缓存和重算模式显式提供，动态标准/优化分支取决于显式同步配置，上一请求统计按原生规则只消费一次。组件接收已准备provider值，不创建官方身份、初始化SDK或复制其他App账号材料。两条动态分支的空值语义不同，统计字段仍用普通setter；不能用统一的“去空值”策略改变签名输入。标准签名后追加包版本/实验元数据，优化分支不追加。离线数据字典/IDL一致不等于实际provider、Live发送或审核一致，完整接线完成前不切换生产发送路径。

### 原生正文准备边界

22.11.1 包内的新旧回复编辑器不能混同。NativeWriteContent 显式区分已准备正文与 reply-compose 插件输入；后一种按该插件第一次显式提交生成正文，并在任何 TBS/发送前捕获结果。它不负责选择原版实验配置、不改变用户草稿、也不启动验证码重放。新插件没有旧楼中楼 delegate 的 140 单位截断；不能把旧回调的限制搬入新路径。原生 NSPredicate 的宽度匹配语义使用 Foundation 保留，正文自身不 trim/截断/标准化。附件转换、旧路径完整处理和运行时选择仍待独立闭合，Live 暂不切换。

### 原生回复后读取边界

原生新回复的页面handler可在pbMyReplySwitch开启时进入独立getmypost读取；它不等同普通下拉刷新或先前U08追加同页读取的推测方案。NativeReplyFollowupParameters只准备原生已证字段及初始server state门控后的计数，既不启动请求，也不复用Android PB字段来补齐iOS基础上下文。调用方必须提供有效回执、实际原生分支和账号内请求所有权，才能提交返回的计数/派发计划。未完成完整IDL/HTTP、结果合并及SDK/账号准备前，不接现有Live，不清阅读缓存/草稿，不改变阅读锚点。

### 原生回执边界

NativeWriteResponseRules采用原生错误码谓词和账号动作分支；NativeWriteResponseDecoder以独立iOS响应descriptor读取error/data及回执字段。解析不等同于完成编辑器：保留返回ID与payload存在性，不由附带anti/info字段单独制造验证失败，不自动验证、换账号或重试。目标关联的正ID保护保留，缺失/错误目标不生成本地成功回执。账号验证UI和完整模型完成链路尚未接通，不将新组件通过写成Live迁移完成。

### 原生签名边界

用户再次明确 iOS 行为为唯一发送迁移依据，Android 只作为旧实现差异对照，不用于推断未知值。NativeWriteSigning 依据同一参考的原生合并/签名/返回分支：业务覆盖公共字典参与签名，返回公共副本；NSString literal 键排序、原始 key=value 拼接、UTF-8 MD5 大写十六进制。标准分支的package_version与实验元数据在签名后追加，优化分支不追加。公开协议后缀由原生 TBCCoreSign 直接查证，不由 Android 的现有实现推断。Common 无 sig 描述符，不制造 SDK sig 或提升为业务 data.sig。组件只接收明确上下文，尚未生成/获取真实 Common 或接入 Live；不以封闭回放替代完整原版发送证明。

### 原生 HTTP 封装边界

NativeWriteHTTPRequest只接收已准备的业务、Common及HTTP上下文，不产生账号或设备身份、不计算未知签名，不自行发送。复用现有body编码；原生Proto路径使用单个data/data/image/jpeg文件段、无额外表单和cmd/format查询，UA/语言/logID/timeout必须显式传入，实际Content-Length由编码字节计算。允许的响应MIME不能隐式改变出站Accept。响应大小上限沿用写端点1MiB；一次提交，无应用层重试。

共享EndpointRequestBuilder仅两处差异：encode从private变为模块内可用，boundary允许合法的+。WRITE_BASELINE保留beta3原摘要，通过声明的两处精确逆向编辑验证，其他改动仍失败；不是重置摘要或关闭基线保护。当前仅组件迁移，不切换Live，未闭合的Common/SDK/账号/回执不能由这些组件测试代替。

### 原生账号/响应状态边界

昵称缓存按原生profile完成规则更新：仅同UID，显示名优先、空缺时回退profile登录名，非空且字面不同才应用。必须携带原请求AuthContext，通过当前租约校验后才能写入NativeWriteSession；不从UI显示名获取，不在每次发送时查资料。昵称更新保留当前TBS及进行中补取，晚到TBS结果也保留已更新昵称。持久账号/provider及网络准备仍待接通，本批不新增另一套登录或Keychain。

新增组件按单个AuthContext及已取得的账号元数据持有TBS与响应状态。已有TBS复用；缺失只登记一个独立补取操作，失败/空值释放登记，晚到结果必须匹配原操作和原会话。显式失效或租约验证失败清除内存状态，不自动换绑到新账号。账号落盘及原生准备请求尚待完整接线，没有修改SessionCredential/Keychain、没有建立新的持久凭据仓库。

响应使用现有URLSessionHTTPClient和HTTPDataLoading的每次请求独立适配，只返回原生写端点Set-Cookie中的指定状态值，普通HTTPResponse继续采用原白名单。状态由解析响应的repository显式接受，无新值保留已有值，不把收到状态等同于发布成功。原始Cookie、重定向及其他域不被开放。以上实现先在隔离fixture验证，Live仍未切换；原版全局IDPCache的账号清理规则尚未证明，不将自有租约隔离写成原版源码事实。

## 2026-10-07 当前决定：发送链路完整恢复 beta3

用户明确要求与手机已确认可用的 `v0.2.0beta3` 完全对齐。本节覆盖下方 U08 历史方案；不再只对齐出站 Accept。基线提交 `4534020d509ea0188dced53cf582fcc775dbb71e`。

- 已恢复 Endpoint/Builder/TextWriteProtocol 完整文件：请求 Accept 与响应 MIME 使用旧版同一集合，AddPost 只接受原两种 MIME；验证码相关字段先于 error/pid/tid 的原判断顺序完整恢复。此前 MIME 扩展和成功优先均已撤回。因此旧版对 application/protobuf 的“结果未知”和附带验证字段提示也可能重新出现；不能私自兼容后仍声称完全一致。
- 发送成功的原顺序：清对应草稿 → 记录回执 → 收起编辑器 → sheet didDismiss 执行一次回调。帖子用原 reload，楼中楼用原 refresh；均按原 U03 当前阅读页机制保留已加载范围/锚点。撤回 U08 的 target 回调、lastReplyReceipt、父楼/末页选择、dirtyPages 和成功后追读新页；没有额外同页读/轮询/重发。
- TextComposerStore 发送主体、TextComposerService present/didDismiss、账号准备、签名/编码、四类目标、上传、网络和 Session 的既有代码与 beta3 对照一致。保留 U08 本地草稿落盘及图片文件所有权、草稿恢复就绪门槛、账户隔离清理；不将这些明确的本地存储差异或 U07 已验收外观说成全 App 字节一致。账号变化新增的强制关闭编辑器已撤回。
- Specs/WRITE_BASELINE.json 固定 beta3 源码/接线摘要；make write-baseline-check 纳入 lint。AGENTS.md 禁止今后未经新的明确授权改变这条链路或更新基线。没有任何 Live 发送、上传、重发或审核探测。源码/Mock 通过不证明服务端删帖原因已解决，MODERATION_CAUSE_UNKNOWN 保留。


状态：Accepted for implementation（2026-09-24 用户明确授权 R09）；Live 发布仍须用户手动完成。

R09 提示词授权新帖、回复主题、楼层和楼中楼，作为原只读范围的有限扩展。新增一个 Composer、一个 WriteRepository，复用现有网络执行器、授权租约与列表。没有点赞、删除、图片上传或表情面板。

编辑器由当前目的页用系统 sheet 展示，保留导航/列表实例。目标保存真实 forum/thread/parent/subpost/user ID；缺失时禁用发送。新帖标题遵循 Android 的 31 字限制且可留空。取消保留本次会话的目标草稿；草稿只在内存，进程结束不持久化，账号租约变化后不可读且清除。发送捕获不可变内容和当前租约，单一 in-flight；发送期间不允许取消关闭或改文。失败保留草稿，超时/取消/响应不明提示先检查目标页面，绝不自动重试。

数据层使用 Android 已证的 AddPost Protobuf 和 AddThread JSON，以及 loginFlow 的只读账户元数据（tbs/uid）；仅在用户点击发送后取元数据并再次核验租约。HTTPS、拒绝重定向、禁止自动重试，不仿造 Android 设备指纹/风控令牌，不输出正文或认证信息。缺失风控能力显示明确不支持；HTTPS 路径和最小字段的实际可用性为待人工 Live 验证项，不降级 HTTP。

成功必须有服务器 pid/tid，关闭编辑器后仅调用发起页面既有 reload/refresh，不制造乐观行。第一道门禁只检查四类编辑器和隔离 Mock 成败；AI 不点击 Live 发送。第二道门禁由用户另外决定和手动发布。无新依赖、动画、手势或共享列表变更。

iPad 初轮实际复核发现：portrait→landscape 切换 compact/regular 后，目的页本地 sheet 状态消失，编辑器连同键盘被关闭（5秒可观察等待仍不出现；截图/AX显示已回组件画廊）。因此仅把 R09 编辑会话和系统 sheet 的持有者放到已有稳定 AppSceneRoot 注入的 TextComposerService；Feature 仍只发当前目标和成功刷新回调。没有更改 AppShell 的布局投影、路由、导航树、Store、列表或 shared lifecycle。正在编辑的 Store 随 sheet 存活，转屏不依赖页面局部 @State。

## U08 修订（2026-10-06，用户授权）

以上“仅本次会话/租约变化清草稿”由本条替代。TextComposerDrafts 复用登录恢复已有的非凭证 namespace，键为 namespace + kind/forum/thread/parent/subpost。同 namespace 的租约更新保留草稿；退出、失效、替换账号沿用隐私约定删除旧 namespace 的草稿，取消旧编辑器。Application Support/ComposerDrafts-v1 与两类缓存独立。ComposerDraftStorage actor 原子保存标题、正文原始表情 token、选图元数据及自己的附件副本，不编码服务器上传 token；临时导入仍按引用释放，持久文件由草稿存储管理。

文本编辑合并 300ms 写入，关闭/进后台显式 flush；持有最近内存快照和有序写队列，成功回执只清当前目标，晚到旧账号编辑不能回填。最多 64 个草稿、256MiB、单份 JSON 1MiB、9 张已处理图片。上限/磁盘失败明确提示且保留内存与旧磁盘副本，不自动淘汰有效草稿；已替换附件及未完成首次保存的孤儿文件由 actor 清理。不添加删除草稿操作，不自动发送、不扫用户相册。

回复回调携带服务端 receipt 和实际发起 target。复用 U03 对应页保留式刷新：父楼回复刷新包含父楼的已加载页，主题回复和楼中楼回复刷新各自已加载尾页。原先已到底而刷新后出现下一页时，若本次 receipt 仍不在已返回内容中，只追加读取这一页；不递归追读全帖，不注入未审核回复，不主动跳楼。对应 thread/subposts manifest 的 dirtyPages 与页面数据/阅读进度分开，旧版本 manifest 可继续读；成功刷新只消除该页标记。保留发送回执，服务端确认后自动关闭编辑器并刷新，按2026-10-07用户反馈移除阻塞阅读的“发送成功”确认框；刷新失败不清阅读内容。楼层定位未知时不提供虚假“查看回复”。协议、上传、VirtualizedList、Pager 与稳定外观不改。

2026-10-07回执修订：AddPost允许已实测的application/protobuf，复用原解码器。按原版错误拦截器与AddPostRepository规则，零错误码及有效、绑定目标的服务器新pid确认成功；附带anti/info不覆盖该回执。非零错误不能成功，缺失/不匹配ID仍不确认；只在未确认成功时将显式need_vcode或验证码材料归类为需要验证，不能仅凭类型字段作此断言。该修订不增加验证码处理、自动重试或请求字段；真实发送由用户执行。

2026-10-07撤回：以下额外读取方案已因缺少实网因果证据及用户再次反馈删帖而撤回，不再是当前契约；不是已确认其导致删除。保留原说明用于追溯：主题回复原先已读到底，第一次强制读取成功但仍未包含本次receipt时，最多再执行一个后续读取：出现下一页则读该页，否则再强制刷新同一已加载末页。不加固定等待或循环，不重新提交。第二次仍未可见/读取失败时保留已加载内容、锚点和回执，并重新标记相关缓存待更新；不能把旧页当作已经追上本次写入。取消/新代次/账号改变停止后续动作。该策略覆盖一次读接口可见性滞后，不保证审核或任意时长延迟，不能伪造新行。

## 2026-10-08 用户授权的文字发送试用版

用户明确要求先做出一版参照 iOS 请求的正常 App。NativeLiveTextWriteRepository 替换生产 Composer 的旧 LiveTextWriteRepository；现有浏览/个人资料网络不在本轮迁移范围。NativeWriteAppRuntime 只取本 App 真实系统/会话数据，原版 CUID/安全 SDK/实验配置缺口公开保留。采用包内明确 BDUSS 登录分支准备一次当前会话，重复发送复用内存账号，缺 TBS 由已有原生 TBS 组件补取；不称其为完整 Passport 或跨进程账号持久化实现。

文字新帖/各级回复经已验证的 NativeTextWriteClient 请求一次，回执关联后交给已有 Composer 成功关闭/当前页刷新。真正验证码/账号验证仍不自动执行；任何失败都不回退到 Android 写入，不自动重试。图片在上传前（包括已缓存上传 token 的选图）明确拒绝并保留草稿。此版没有新视觉布局、动画、手势或第三方依赖；不改 VirtualizedList、Pager、MediaViewer、内容预载和阅读恢复。
