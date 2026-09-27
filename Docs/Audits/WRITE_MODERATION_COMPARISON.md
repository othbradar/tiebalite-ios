# 发布后删除通知：与 Android TiebaLite 的差异审计

日期：2026-09-25，更新于 2026-09-27。当前状态：`LIVE_REPLY_USER_VERIFIED / MODERATION_RETENTION_PENDING / WRITE_MODERATION_CAUSE_UNKNOWN`。用户已恢复排查；显示名遗漏已修，删除触发原因仍未确认。下列 9 月 25 日审计保留为历史，最新结果见末节。

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
