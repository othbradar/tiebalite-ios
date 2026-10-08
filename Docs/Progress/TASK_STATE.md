# TASK_STATE

## 2026-10-08 U08 — USER_ACCEPTED，用户批准提交当前候选

- 用户在确认本轮模拟器真实主题回复成功、原帖第 8 楼可见后，明确要求“现在先提交”。提交范围为当前已安装候选的草稿持久化、原生 iOS 文字发送链路、URL 路由修复及对应回归/证据；验收后生产代码未变，沿用已有构建和定向结果，不重复全套测试。
- 精确提交本阶段源码、生成 Proto/输入锁、Mock/fixture、测试、回放工具、约束与证据文档。排除用户原有 Prompts 和技能配置、Artifacts、参考 IPA/程序、真实内容/凭据、缓存/草稿、IDE 文件及 Android submodule。提交题目：`fix: persist drafts and repair native iOS text replies`。本次仅提交，不推送、不进入 U09。
- 本次接受不表示原 U08 所有目标或原版协议完整对齐：图片发送仍不可用，完整 SDK/Passport、原生 getmypost 后续读取等仍未完成；仅当前主题回复有用户实发确认，其他目标及长期审核留存未据此转为通过。保留当前发送行为，后续调整继续需要用户明确授权。
- 提交前 secret scan 通过；首次 staged diff check 检出 4 个既有离线回放脚本的行尾/文件尾空白，清理后 Python AST 与清理前逐一相同，不改变回放或生产代码。精确清单共 121 个本阶段文件，用户原有 Prompts/技能配置保持未暂存。

## 2026-10-08 U08 — 用户确认当前候选真实回复成功

- USER_REPORTED：用户明确反馈“这回发成功了”，所附截图显示本次回复已出现在原帖第 8 楼。当前已安装的原生 Proto URL 修复候选获得一次真实主题回复成功、列表可见的人工验证；不是 agent 代发或 Mock 结果。
- 保留当前发送实现，不再自行调整账号准备、参数/签名、请求头/体、次数/顺序、回执或刷新。本轮仅记录反馈，没有生产代码、外观或用户数据变化；未提交、推送或进入 U09。
- 本次反馈未单独说明编辑器自动关闭/自动刷新过程，也不外推为新帖、楼中楼、上传、完整 SDK 对齐或长期审核留存已验证；此前记录的未验证项继续保留。文档差异检查通过，未重复构建或测试。

## 2026-10-08 U08 — 修正原生 Proto 写入 URL 路由遗漏，已覆盖安装，实发待用户确认

- 本次用户手动点击的 DEBUG 白名单诊断已取得：账号 HTTP200/JSON error_code0；回复 HTTP200/137bytes/JSON error_code110001，无 Proto payload/有效回复 ID。因此当前“未知”来自收到 JSON 后按 Proto 解码失败；不能解释为封禁、发送成功或已证明不存在远端回复。仅保存 metadata，未保存原始回包、正文或凭据。
- 确定的实现差异：NativeWriteHTTPRequest 发送了原生 Proto multipart，却漏了短连接 URL 的 `cmd` 和 `format=protobuf`。同 SHA 22.11.1 的 TBCBaseModel.loadInnerWithShotConnection（0x100249044–0x100249168）离线执行 6 个合成场景，得到 post309731/thread309730、已有 query、shortAsLong 及非 Proto 分支的实际地址。此前 query==nil 测试无依据，已更正；旧 body/header/signing fixtures 保持原字节，不将旧测试通过称为 URL 已对齐。
- 生产修复只在 NativeWriteHTTPRequest 拼接上述 query，command 复用既有编码器。新增 emulate_url.py / native-ios-request-url.json 并更新 HTTP、Client、Signing、LiveWrite 四套直接回归和证据文档。账号准备、正文、签名、请求头/体、次数/顺序、SDK、回执条件和成功刷新不变；无新增 UI、动画、手势、overlay 或生产依赖。保留全部既有 U08/用户草稿和其他工作树改动。
- 先红：native-url-red.xcresult 运行 5 项，两个测试因 URL 缺 query 产生 7 个断言失败，正文/头部断言未失败。修后 native-url-green.xcresult：30 项/4 套件 PASS，含实际 App runtime→Composer→账号准备→一次 Mock 写入和成功收起状态。lint 首次出现测试 fixture 类型嵌套 1 项违规，平移私有类型后 native-url-http-final.xcresult 再跑 HTTP 6 项 PASS；lint 488 文件 0 violation/23 项发送基线通过。make build、secret-scan、git diff --check 通过。未跑全量测试；未新增自动化 UI 结果，当前正常 Live UI 仅验证登录与原草稿恢复，不代替实发。
- 覆盖正常 iPhone 17 Pro 的完整 Live App 前通过现有 Simulator Keychain entitlement 检查；安装 executable/debug dylib 与本次 build 摘要相同。当前草稿目录 1 份文件在终止后、覆盖前后摘要一致（在启动前比较）；未卸载、清缓存、清 Keychain 或改签名。UI 已确认“已登录”，经浏览记录返回原帖，原两字草稿已恢复，停在编辑器，agent 实际写请求 0。证据 native-url-installed.json。一次历史行 AX ID 过期导致点击未执行，重新读取后正常打开，无错误发送。
- 地址差异已修，实网接收和审核留存仍待用户操作；没有把 JSON110001 含义猜为审核原因，完整 SDK/Passport/上传及 MODERATION_CAUSE_UNKNOWN 限制继续保留。未暂存、提交、推送或进入 U09。

## 2026-10-08 U08 — 发送结果未知，已装只读诊断候选，尚未修复

- 用户在上一编码修复候选中手动发送后立刻收到“尚未确认发送结果”，未见回复或封禁提示。与之前的发送前 malformedNumber 不同；没有将此问题表述为旧修复已经覆盖。系统 CFNetwork 元数据在对应时间附近显示两次 HTTP 200，分别 94/54ms、request_bytes=1398/response_bytes=673，但未保留业务回包，不足以证明目标写请求成功、服务器未接受或遭封禁。仅记录这些元数据，未留原系统日志。
- 不猜修改账号、SDK、请求参数/签名/次数/顺序、回执判定或刷新。新增 DEBUG 限定的 NativeWriteResponseDiagnostic 和 DebugNativeWriteDataLoader/Diagnostics，在原 loader 返回后仅提取白名单 HTTP 状态、MIME 类别、体积、JSON/Proto 解码是否成功、错误整数及 ID 是否存在/有效；不输出/保存原始响应、ID、正文、凭证、验证材料或任意服务端文字。缓存文件 NativeWriteDiagnostics-v1.json 最多 8 条，只观察本次显式用户操作触发的账号/TBS/写接口，不发新请求、不重试、不改结果。Release 不接入，UI 无变化。
- 新诊断测试先遇到嵌套 #require 宏展开、actor 断言访问编译问题，修正测试后 write-diagnostic-unit-green.xcresult 为 15 项/2 套件 PASS（4 项诊断及原 11 项客户端字节/单次请求/取消/旧账号回归）。首次 lint 8 项格式违规，修后 488 文件 0 violation；secret scan 两次误中合成 passToken 测试赋值（STOKEN 子串及长变量名），改用短名的明确合成样本后通过，扫描规则未改。generate/build、diff check 通过。未重新运行 UI 矩阵及无关测试。
- 已覆盖正常 iPhone 的完整 Live App，签名/Keychain 配置未改；安装可执行文件与本轮构建匹配，UI 确认已登录并恢复原帖两字草稿，停在编辑器。辅助草稿 hash 比较在重新打开编辑器之后执行，首次断言失败：5 份文件均在、4 份摘要相同、当前一份字节已变化，因此不声称五份逐字节一致；未输出正文，原草稿内容由 UI 确认。未卸载/清理账号或缓存；agent 未真实发送。已请用户在愿意继续该评论时自行点一次发送取得缺失证据，不要求连续重试；当前故障仍未解决，不输出 READY，不提交/推送/U09。已知完整 SDK 等缺口继续保留。

## 2026-10-08 U08 — 修复试用版发送前本地编码失败，已覆盖安装

- 用户截图提示“发送前获取账号资料失败”。本轮使用一次显式账号准备检查：HTTP 200、error_code=0、现有 user/anti 解码成功；未保存回包正文/凭据，未调用发帖或回复。诊断入口随后删除，App/TiebaLiteApp.swift 恢复本轮前内容，不留诊断页面或自动准备任务。
- 唯一根因是实际 NativeWriteAppRuntime 在缺少个性化配置时生成 `personalized_rec_switch=""`，SwiftProtobuf JSON int32 桥接抛 malformedNumber，尚未进入写入传输；通用错误映射误报为账号资料失败。之前只验证运行时 context 和使用完整配置的 Mock 发送，漏了真实运行时到编码这一边界。新真实运行时编码用例及空字段 wire 用例先红，分别保留 account-encoding-red-suite.xcresult / account-field-red.xcresult。
- 参考原版 IDL int32 分支 NSString.intValue 的显式零行为，仅在 NativeWriteRequestEncoder 的线格式转换前将该已知空字段转换为 0。签名仍基于原空串，缺字段保持 absent，其他非法整数仍拒绝；不改账号准备、正文/业务字段、SDK、网络请求次数/顺序、回执和刷新。NativeLiveTextWriteRepository 的非回包类发送前错误改为 requestPreparation，避免错误归因；保留草稿。相关差异仅上述编码器、错误模型/映射、直接测试及证据记录，无视觉/手势/动画/overlay/依赖变化。
- account-fix-green.xcresult：16 项/2 套件 PASS，含真实运行时完整 Composer→账号准备→单次 Mock 写入→成功、草稿/错误、字节/presence/签名/非法数回归。account-fix-ui.xcresult：隔离 iPhone 编辑器成功关闭/只清匹配草稿短 UI 1 项 PASS（24.292s）。最初单方法筛选漏括号执行 0 项，不计通过；已改为明确套件运行。lint 首次 4 项、第二次 1 项格式违规，修正后 account-fix-lint-clean.log 为 485 文件 0 violation / 23 项基线 PASS；make generate/build、secret scan、diff check 均通过。未跑全量测试；本次未新增 iPad UI 结果，沿用上一轮相关 UI 结果，不冒充本轮运行。
- 已按原签名覆盖正常 iPhone 17 Pro 完整 Live App；5 份既有草稿文件摘要一致，可执行文件与 debug dylib 匹配本轮 build，未卸载/清 Keychain/清缓存。UI 确认仍已登录，经浏览记录重开原帖，原两字草稿正确恢复，停在回复编辑器；未点击发送。安装证据 account-fix-installed.json；仅账号检查 1 次，agent 真实写请求 0 次。完整 SDK/Passport/图片上传等既有限制及 MODERATION_CAUSE_UNKNOWN 保留，不能据本地修复宣称审核通过。未暂存、提交、推送或进入 U09。

## 2026-10-08 U08 — iOS 文字请求试用版已接入并安装，等待用户手动发送

- 最新明确授权为“先做出来一版能参照原版 iOS 贴吧发请求的 TiebaLite iOS 再停止”。据此实际接入正常 App，而非继续追加孤立组件；本版限定文字新帖/主题回复/楼层回复/楼中楼回复。完整 SDK/Passport/上传/验证复刻仍未完成，不将原始完整迁移目标标为完成；本轮试用版交付后停止，不自动试发、提交、推送或进入 U09。
- 新增 NativeLiveTextWriteRepository、NativeAccountPreparation、NativeWriteAppRuntime。生产 Composer 改用该 Repository；账号准备走 22.11.1 包内明确 BDUSS 登录分支（原字符串 bdusstoken，不追加 Android 后缀），当前有效会话复用账号、缺 TBS 才补取，接已核对的 iOS 业务/IDL/Common/签名/单次 multipart。账号变化拒绝迟到结果，不自动重试、回退旧 Android 写入或额外查询旧 profile。浏览/个人资料模块未迁移。
- 运行时 UA 来自本 App 本地空白、nonPersistent WKWebView，仅读取 navigator.userAgent，不加载远端页面或账号；系统版本/机型/屏幕/会话使用本 App 实际值。原版 CUID/安全 SDK/实验值缺失不伪造；本版选用标准分支并明确保留缺口。账号仅内存缓存，进程重开重新准备，不能称为完整原生持久化账号生命周期。
- 回执零错误且目标 ID 有效才交还既有成功关闭/单次当前页刷新；附带 anti/info 不自动判为验证失败；真正错误码 5/6 等要求验证时保留草稿且不执行挑战。图片（包括选图中旧上传 token）在任何上传/账号请求前拒绝，明确提示本版暂不支持并保留草稿；旧上传实现留存但不接入本版 Composer。现有 UI/字号/图标、VirtualizedList、阅读恢复、预载、Pager 和 MediaViewer 未改。
- 定向验证：首次编译有 CGFloat→Double 转换错误；修正后 live-trial-unit-2.xcresult 为 16 项/2 套件 PASS。补各级目标及原阅读回归后 live-trial-final-unit.xcresult 为 10 项/2 套件 PASS（参数化用例另含 2 场景）；进一步明确验证码/空回执断言后 live-trial-verification-unit.xcresult 的 6 项新 Live adapter 测试 PASS。前述套件有重叠，不累加成独立测试数。Mock 实际观察首次 login→write、次次复用仅 write；没有 Android profile 调用，每次发送 1 个写请求，无真实写请求。
- UI：隔离 iPhone 和 iPad 各运行 U08DraftSmokeTests.testSuccessfulReplyClosesComposerWithoutConfirmationAndClearsOnlySentDraft，分别 24.312s/27.160s，均 1 项 0 失败。其 Fixture 验证编辑器关闭/当前页显示/位置保持，不冒充真实发送成功。lint 首轮 10 项格式/复杂度违规、第二轮 1 字行长违规，均已修复；最终 485 文件 0 violation、23 项旧基线检查通过（保留原摘要，新增精确授权的图片前置校验逆向差异）。make generate、make build 完整正常 Debug Simulator App、secret scan、diff check 通过。未跑全套 Unit/quality 或无关压力矩阵。
- 按现有安装脚本相同签名/Keychain 检查和 terminate→install→launch 流程，复用 .build/DerivedData 构建产物覆盖正常 iPhone 17 Pro，未新建 DerivedData、卸载/erase/清 Keychain。安装后可执行文件与 debug dylib 摘要均匹配本轮构建；四份既有草稿文件逐字节相同。Simulator 覆盖安装改变数据容器路径，最初“路径必须相同”辅助断言因此失败并停止启动；确认草稿仍一致后更正该错误前提并正常启动，未回滚/清数据。UI 实际确认“已登录”、最近逛吧和原排序仍在；未读取凭据。
- 当前完整 Live App 已打开高通吧真实帖子的空白回复编辑器，正文 0 字、未点击发送。Live 账号准备/写入尚未由用户触发，服务端接受及后续留存均未验证。图片发送、原版验证 SDK、专用 getmypost 合并/跨页新回复立即可见仍是限制。证据为 ignored live-trial-*.log/xcresult/installed.json，用户内容不写入提交；所有用户原改动、原草稿和 Android submodule 保留，暂存区为空。

## 2026-10-08 U08 — 模拟器验证后的 Live 接入阻塞确认

- 本轮仅复核最新记录、原生客户端/运行时上下文和 App 接线。`NativeWriteRuntimeProviding` 仍只有 TestSupport 实现；正常 App 仍接 `LiveCurrentAccountRepository`/`LiveTextWriteRepository`。上一轮组件通过没有改变这一事实，不能将其称为已完成发送迁移。
- 恢复目标后的连续三轮仍缺可用参考运行时证据：第一轮真机解锁后实际附加被拒绝，第二轮确认给定 IPA 为 iPhoneOS 真机包且转用 Simulator 验证本项目，第三轮确认这些验证不能提供实际账号/SDK/配置和验证生命周期。前两轮有静态/组件进展，本轮没有新的实现进展，也没有正在运行、值得等待的调试会话。当前无法有依据地闭合完整 Live，停止追加孤立组件，目标按同一阻塞达到阈值标记 blocked，未完成。
- 下一步需要可用的参考运行条件或等效脱敏运行证据；已提出的“参考 App 使用何种工具签名安装”问题仍待答复，用于判断独立可调试参考副本是否可行。签名工具名称本身不保证可调试。不索取凭据、不要求测试发帖，不把现有 App 改签或替换为混合候选。保留所有代码、草稿、账号、历史、缓存及已验收外观；不提交、推送或进入 U09。
- 本轮复核上一候选的 5 份文件摘要全部一致，沿用已执行的定向验证；未重复 Unit/UI/lint/build。仅任务记录更新，secret scan 与 diff check 通过，暂存区为空；无生产代码、安装、视觉、手势、动画、overlay 或依赖变化。

## 2026-10-08 U08 — 转本机Simulator验证原生回复后读取组件

- 上一goal turn是进展：解锁后取得实际调试拒绝证据，并追通新回复完成handler。本轮用户明确提出用本机模拟器，保留完整目标并继续实现，不以真机不可附加重复等待，也未将目标缩成仅组件通过。HEAD仍edfb9ef、暂存区为空，所有原U08/用户改动保留。
- 直接从用户指定IPA读取白名单元数据：22.11.1、iPhoneOS、arm64、LC_BUILD_VERSION平台2，SDK26.2，参考TBClient SHA相同；它不是可直接运行的Simulator包。本机正常和隔离iPhone Simulator均Booted/available。本轮测试运行于隔离Tieba-Perf-Test，不把ARM64封闭回放称作原版App在Simulator运行。
- 追到原版独立getmypost读取（CMD309751）：普通PB转换移除旧r/back/lz/pn并使用新pid；楼中楼保持字符串ID，mark_type=2。初始server state1/2不派发、不增加计数，其他状态使用下一request_times和offset=2。基础PB上下文、连接模式3的后续传输、响应合并和实际开关仍待闭合，不能与普通下拉刷新混同。
- 新增NativeReplyFollowupParameters及16例原生参数/门控回放、3项直接Unit；先固定原生样本和测试契约，再实现值转换。原生网络入口仅拦截计数，不访问账号/SDK或宿主网络。仅使用明确合成十进制ID验证64位精度；无效底层builder样本不等于允许无效目标发送。没有加入重试、计时器、循环读取、乐观回复行或新列表框架。
- 验证：make generate通过；reply-followup-unit.xcresult的3项/1套件Simulator Unit全部PASS（0.005s），覆盖16例原生场景和不修改原参数/描述脱敏；reply-followup-verify.log重放16例PASS；make lint为481文件0violation、23项WRITE_BASELINE PASS；make build完整正常Simulator App为Build Succeeded；secret-scan及git diff --check通过。编译只有既有unused Proto import/AppIntents metadata提示，无失败命令。未运行全部Unit、quality、UI长矩阵或重复未改缓存测试。
- 新组件尚未接Live；当前发送、安装、视觉、草稿、缓存、账号和阅读位置未改，无新手势/动画/overlay/生产依赖。未自动发送/回复/上传、暂存、提交、推送或进入U09。实际Runtime provider、原生账号准备、完整富文本/上传、验证和结果合并仍未完成；不宣称异常删除已解决，不安装未完成的混合链路，不输出READY，目标保持active。

## 2026-10-08 U08 — 设备恢复连接，核对调试限制及原生回复完成链

- 上一 goal turn 因设备/真实运行依据缺口标记 blocked，属于无进展的状态复核。本次目标已恢复 active，重新开始阻塞审计；不是沿用此前三次计数。当前出现新权威证据并追通新的静态调用关系，属于进展，不是 verified wait 或完成。
- HEAD仍edfb9ef、暂存区为空；reply-content-candidate-proof中9份源码/测试/回放文件摘要全部相同。保留所有未提交U08/用户改动，不重跑未变的13项Unit和完整构建，也不将这些旧结果表述为新Live验证。
- 参考iPhone已available，指定bundle查询确认安装为22.11.1/22.11.1.0、builtByDeveloper=true。首次LLDB设备选择因锁定终止；用户解锁后重试。批处理detach的“Process must be launched”未被当作附加结果；交互式附加得到明确“Not allowed to attach to process”。退出调试器后只查TBClient，原进程仍在。没有读取账号/私有容器、重签、替换或结束官方App。元数据过滤首次对URL做字符串比较失败，改用lastPathComponent后准确匹配，不扩大个人App/进程输出。
- 替代的Time Profiler单进程5秒采样未建立：设备准备超时，exit13；xctrace设备列表为Offline，同轮CoreDevice确认已解锁。未重启相同录制或将超时写成采样通过。两个工具会话均已终止；现在没有可继续等待的调试/采样句柄。已向用户询问参考App的签名安装工具，不索取证书/密码/凭证，不要求测试发送。
- 离线沿22.11.1新回复completion追到实际handler，明确成功先调用页面handler，再处理编辑器附件/草稿及收起；成功之后仍经过条件UEG检查。PB读取有pbMyReplySwitch门控，楼层/主题分别进入按父楼读取/按返回pid读取末页；楼中楼另走其handler。编辑器refreshContentFromContext不能冒充帖子刷新。具体地址、已证顺序及未知下层语义记入API_EVIDENCE和UNKNOWN；没有据方法名添加生产刷新或清草稿行为。
- 本轮只更新证据/状态与ignored反汇编，不改生产代码、App接线、界面、手势、动画、overlay或依赖；正常安装、用户数据与原Live发送保持。未发送/上传/重试、暂存、提交、推送或进入U09。完整目标未完成，仍缺可用运行证据、实际provider、完整富文本/上传与最终回执/页面接线；不输出READY，不宣称解决异常删除。
- 验证：参考TBClient SHA256复核相同，9份既有候选文件摘要一致；make secret-scan（runtime-completion-secret.log）及git diff --check通过。runtime-access-20261008.json仅记录白名单状态/版本与静态证据摘要，不含账号、设备标识或凭据。未重复Unit/UI/lint/build，不把本轮文档核对当新版本验收。

## 2026-10-07 U08 — 核对真实运行时接入条件，等待参考设备

- 最新复核：正文准备轮、上一接入条件轮、本轮连续三次 goal turn 均确认参考 iPhone unavailable，官方运行时来源缺口未变。上一轮新增真机平台/调试权限证据属进展，本轮仅重新核对权威状态，没有新实现进展，也不是 verified wait。NativeWriteRuntimeProviding 仍只有测试替身，上一候选所有文件摘要未变、暂存区为空。当前必须取得可用的官方运行/调试条件或等效脱敏运行证据，才能继续有依据地闭合 Live；不能用额外 Mock 或未知参数代替。目标按同一外部阻塞达到阈值标为 blocked，未完成；待用户恢复参考设备后先检查实际可调试性，不承诺仅连接就已解决。已有实现和完整目标保留。
- 上一 goal turn 为进展：正文准备已接入原生客户端、13 项定向测试及轻量检查通过。本轮核对当前 worktree：HEAD edfb9ef、暂存区为空，上一候选源码摘要仍相同；不重复测试或更换安装。
- 当前 NativeWriteRuntimeProviding 唯一实现仍是 TestSupport 的 NativeClientFixtureRuntime。AppCompositionRoot 的发送仍为 LiveTextWriteRepository，不能把新组件测试或已有 Live 安装当作原生迁移成功。真实 SDK/Common、账号准备及完整完成路径是接入前必需条件，不能用合成值补齐。
- 本次 devicectl 再次确认参考 iPhone unavailable。只检查用户提供 IPA 的白名单元数据：com.baidu.tieba/22.11.1，Mach-O 平台 iOS device（不是 Simulator），参考可执行文件 get-task-allow=false。未打印完整 entitlements、设备/账号标识或凭证；这些参考包属性不等于已安装 App 的实际调试能力，后者待设备恢复后检查。
- 已向用户请求恢复连接并解锁参考 iPhone，仅为确认运行/调试条件，不要求发布测试帖。当前没有可运行的官方调试会话，不把对话等待记为 verified wait。缺少运行时证据前不再将新的孤立 Mock 组件包装成 Live 可交付结果；目标仍 active/未完成，未标记 blocked 或 READY。无生产代码/界面/数据/安装改变，无提交/推送/U09。
- 本轮确认记录在 ignored runtime-access-status.json；源码未变，沿用 reply-content-candidate-proof.json 已通过结果，仅对记录再做 secret-scan 和 diff check。

## 2026-10-07 U08 — 新旧 iOS 回复路径区分及正文准备验证

- 上一轮为进展：原生客户端串联结果入档，并定位正文入口；本轮继续同一目标，不新增阶段。HEAD 仍 edfb9ef、暂存区为空，保留全部 U08/用户改动。无真实发送、上传、重试、提交、推送或 U09。
- 发现 22.11.1 同时包含旧回复控制器和新 ReplyComposeSubmitPlugin。PB 的 useReplyCompose 先排除折叠评论，再读取实验配置；不能仅凭包内存在某方法认定用户当次会执行。新插件最终仍调用原已验证的 PbReplayModel，但正文准备独立；上一轮看到的旧 delegate 140 单位截断不直接移植。实际用户配置仍 UNKNOWN，参考 iPhone 当前 devicectl 为 unavailable；未读取其他设备个人数据。
- 新增 NativeReplyComposeContent，按新插件第一次显式提交保留 serverText、空值回退、回复状态及收件人前缀条件。NativeWriteContent 显式接入新客户端，在 TBS/网络前完成不可变正文准备，新主题误用回复插件提前拒绝；已有 prepared 路径和四类完整请求字节不变。不修改草稿、界面、现有 Live、上传或验证重放，不从目标 ID 猜实验分支。
- 新增 16 例真实 ARM64 插件正文回放。第一版用 Python regex 替代 NSPredicate，初轮 Unit 13 项中 12 PASS/1 FAIL，发现全角冒号的 Foundation 宽度匹配差异。独立 Apple Foundation 探针确认后，改回放工具使用开发期 Foundation 原语，并在 Simulator 逐例验证原语；只有该预期结果变化，生产判断未变，原错误样本和失败 xcresult 保留。最终 reply-content-verify-final.log 的 16 例通过，不把初版错误替身当最终证据。
- reply-content-unit-final.xcresult：13 项/2 套件 PASS（0.047s），包括正文 oracle、脱敏、准备到单次出站、拒绝错入口及原 Client 回归。lint 首次 141 字行长、第二次换行对齐失败，只改测试空白后 479 文件 0 violation，23 项 WRITE_BASELINE PASS；最终测试之后仅空白及文档变化，未无故重跑。make generate、完整正常 Simulator make build、secret-scan、diff check PASS。证据在 ignored reply-content-*.log/xcresult，未跑全量 Unit/quality/UI 矩阵或缓存测试。
- 正常 iPhone/iPad 安装未改，新的正文处理仅接入尚未 Live 化的 NativeTextWriteClient。仍缺真实运行时 Common/SDK、账号取得/持久化、完整富文本/上传、新旧入口选择和验证/成功完成接线，不能宣称完全对齐或异常删除已解决。MODERATION_CAUSE_UNKNOWN 保留；无视觉、手势、动画、overlay 或生产依赖变化，不输出 READY，继续原目标。

## 2026-10-07 U08 — iOS 原生请求组件组合验证，Live 仍未迁移

- 继续以用户提供的 iOS 22.11.1 包为唯一新发送证据；Android 只用于旧实现差异对照。HEAD 仍 edfb9ef，暂存区为空，原有 U08/用户改动及正常安装保留；无真实发帖、回复、上传、重试、提交、推送或 U09。
- 新增 NativeTextWriteClient，将已验证的账号内存状态、缺失 TBS 准备、四类目标业务字段、Common/签名、HTTP、解码和响应状态串联；有 TBS 时直接一次写请求，缺失时一次 TBS 后一次写请求，不调用旧账号查询或失败回退。账号/取消/重复发送保护覆盖整个操作，runtime 的旧响应状态不能覆盖当前会话。实际运行时 provider、持久账号准备及 Live Repository 接线尚未实现，不能把本组件称为可安装的新发送链路。
- 独立原生组合样本覆盖四类目标的 5 种请求，完整 multipart 正文字节相等。另执行原生 parseBodyIsProtobuf 的空响应分支：state=4、IDL decodeCount=0；SwiftProtobuf 默认会把空字节解为零错误码对象。先加入回归，client-empty-red.xcresult 保留 1 项失败/2 个断言；然后在客户端解码前拒绝空响应，不写入捕获的响应状态。
- 定向结果：client-unit.xcresult 为初版 Client 8 项 + Session 8 项共 16 项 PASS；空响应修复后的 client-unit-final.xcresult 为 Client 9 项 PASS（0.044s）。Session 未再改动，沿用前述 8 项结果，不伪称一次运行了 17 项。client-verify-final.log 原生请求 5 例与空响应 1 例 PASS；旧 13 份 fixture 字节未变。首轮 lint 仅两处新测试格式失败，修正后 476 文件 0 violation，23 项 WRITE_BASELINE PASS。make generate、完整正常 Simulator make build、secret-scan、diff check 通过；候选摘要见 ignored client-candidate-proof.json。没有全量 Unit/quality/UI 或重复缓存测试。
- 后续仅定向查看正文准备入口：TBCEditableRichView.getTextForServer(0x101c44a90) 走 type=2 的富文本枚举；普通段保留原字符串，附件取 textForServer。generatePbReplyContent(0x1023313e4) 在指定回复输入状态下产生“回复 #(reply, portrait, name) :”前缀；楼中楼 delegate(0x102f527c4/0x102f7855c) 另有 140 单位截断和表情计数处理。尚未覆盖这些方法的完整上下文/运行回放，不据静态片段把 Android 正文处理直接认定为相等，也未修改生产正文或界面。
- 正常 iPhone 仍为先前批准的纯 beta3 对照，iPad 未变；本批未安装未完成的混合链路。运行时 Common/SDK、原生账号取得与持久化、正文/上传、完整验证及编辑器成功完成仍未闭合。MODERATION_CAUSE_UNKNOWN 保留，不宣称完全对齐或删除问题解决，不输出 READY。无视觉、手势、动画、overlay 或生产依赖变化。

## 2026-10-07 U08 — iOS TBS 普通请求与账号准备组件已验证

- 继续用户指定iOS22.11.1参考，不以Android补值。HEAD仍edfb9ef、暂存区为空，保留既有U08/用户改动及正常安装；无Live发帖/回复/上传/重试，无提交/推送/U09，无视觉、手势、动画、overlay、生产依赖变化。
- 新增NativeTBSRequest/ResponseDecoder；复用Common和签名，普通表单返回业务合并结果，空格%20且保留/和?，不走Proto/multipart。最终BBA timeout证据修正为net_type字符串1时10秒、其他25秒；此前20秒只属上层初始化，不能当最终网络值。原生command0头单独执行确认无protobuf标记，logID0/-1省略、42保留。
- 新增NativeWriteSession.prepareTBS，沿用HTTPClient，已有TBS不请求、缺失最多一次显式补取，失败和取消释放操作，不自动重试；晚回包/旧lease拒绝，昵称不被覆盖。限定准确TBS POST目的地。JSON按原生两种错误码优先级、任意非零拒绝，仅接受顶层非空tbs；类型转换及UTF8边界明确。
- 新增封闭TBS回放：两种真实普通Common/签名返回，以及22个真实JSON parser→stringAtPath→完成块样本；SDK/账号/Foundation primitive为显式合成替身，DB和通知只记录。初次回放因未声明的字典Foundation调用中止，补限定替身后通过，不开放网络。旧12份fixture逐字节未变；tbs-verify.log重新回放24样本PASS。表单编码/timeout另外来自静态链，不冒充整个URLRequest已运行。
- 首轮Unit编译失败是新测试6处异步throws断言漏await，修测试后tbs-unit-green.xcresult为26项/5套件PASS（0.052s），包含已有Session/签名/Common。首轮lint4项失败：合成请求计数count误触empty_count、末尾多余空行和Data转String写法；仅修测试/辅助命名与格式后473文件0violation，受影响12项/2套件又PASS（tbs-unit-final.xcresult，0.029s）。没有改扫描/测试规则或削弱断言。辅助读取两处猜测路径不存在已按实际文件定位，不作为代码缺失证据。
- make generate、完整正常Simulator make build（tbs-build.log）、secret-scan、git diff --check均PASS；lint内23项WRITE_BASELINE仍PASS。tbs-candidate-proof.json记录源码摘要及逐项证据。未跑全量Unit/quality/UI矩阵，未重复缓存测试；本批无UI接线变化。
- 实际账号资料取得/持久化、运行时Common/SDK provider、富文本/上传、完整UEG及最终Live Repository接线仍未闭合。新组件仍未接Live，正常iPhone仍是原纯beta3对照，iPad未变，没有以混合发送候选覆盖。MODERATION_CAUSE_UNKNOWN保持，不宣称完全对齐、不输出READY；继续原任务。

## 2026-10-07 U08 — 按 iOS 账号昵称与条件请求头继续对齐

- 最新用户再次强调以iOS而非Android实现为准；继续用户给定22.11.1参考包。HEAD仍edfb9ef，暂存区为空，保留全部既有U08/用户改动和安装。无自动Live发帖/回复/上传/重试，无提交/推送/U09，也未改视觉、手势、动画、overlay或依赖。
- 原生profile回调先核对UID，非空uNameShow优先，否则用该profile.uName；非空且不同才更新昵称缓存。纠正“缺失只为空”的旧推断。新增NativeWriteAccountName和NativeWriteSession的带AuthContext昵称入口，仅更新所属账号/lease，保留TBS和进行中操作；11个ARM64合成样本。account-name-unit.xcresult 12项/2套件PASS（0.012s），覆盖昵称回退、旧账号/同UID旧lease、TBS完成不覆盖新昵称。account-name构建及lint466文件0violation通过。
- 下层原生Cookie边界发现并补全：ka按WiFi/非WiFi配置选择，其他网络状态不启用；pub_env按独立smallFlow策略选择。新增NativeWriteRequestCookies与显式HTTPContext输入，系统Foundation生成对应头，transport仍只发一次且关闭全局Cookie处理。12个原生方法合成样本覆盖条件、nil/空值，原11份fixture逐字节未变。没有读取官方App/浏览器Cookie或把配置值当作账号凭证。
- request-cookies-unit.xcresult 19项/4套件PASS（0.037s），包含新Cookie与已有HTTP/transport/签名直接回归；扫描误报修名后仅重跑受影响Cookie套件4项PASS（request-cookies-unit-final.xcresult）。原封闭回放初次因未声明NSMutableArray分配中止，补限定替身后12例通过，不执行宿主网络。首次lint仅新测试4处参数对齐失败，格式修正后468文件0violation；secret-scan首次把测试内部类型Cookie的声明误判，改名RecordedPair后通过，扫描规则未变。23项WRITE_BASELINE仍PASS。
- make generate、完整正常Simulator make build（request-cookies-build.log）、secret-scan、git diff --check均通过。未跑全量Unit、quality、UI矩阵或未改缓存测试；没有UI接线变化。定向结果和本轮文件摘要记于account-cookie-candidate-proof.json，现有Live安装未被新组件覆盖。
- TBS普通参数入口已追到20秒默认timeout、业务合并/签名返回，与发帖Proto common-only封装不同；needSig及参数改名名单均不含TBS。最终TBS表单/JSON、原生资料取得/账号持久化、实际SDK/Common提供者、富文本/上传及完整UEG/发送完成接线仍未完成。所有NativeWrite组件未接Live；正常iPhone仍为原纯beta3对照，iPad未变。MODERATION_CAUSE_UNKNOWN保留，不输出READY、不宣称完全对齐，继续原任务。


## 2026-10-07 U08 — iOS 公共参数转换已验证，运行时来源与发送接线继续

- 继续用户指定22.11.1原生发送迁移；Android只作旧差异对照。HEAD仍edfb9ef、暂存区为空，保留全部既有U08/用户改动与正常安装，无提交/推送/U09，无Live发帖/回复/上传/重试。
- 新增静态Common缓存/重算、动态标准/优化分支、上一请求统计消费及组合签名入口。所有OS/SDK/账号/隐私/配置/时钟值必须显式提供，不由组件制造实际provider值。真实参考方法9序列/15步静态、24动态、6签名返回与独立IDL样本验证；原7份/97样本未变。最终common-verify.log全部PASS。nil/空值、隐私切换、静态缓存分支切换、统计只消费一次与64位/无符号精度均覆盖。
- 动态Unit首次4项中3PASS/1FAIL，定位到优化分支m_api仍使用普通setter，空字符串必须写入且消费，按原生0x1024b3fb8修正。新增组合回归首次2项FAIL（8处断言），准确复现优化分支不追加package_version/实验元数据；签名组件增加显式分支后解决。最终common-unit-green.xcresult共13项/4套件PASS（0.036s），含旧签名4项直接回归。没有弱化断言或改旧样本。
- 原生回放最初因未声明_objc_opt_new失败，补仅NSMutableDictionary的封闭Foundation替身后成功；不执行实际SDK/账号或宿主App。静态原型先后修正pureMode/xcxMode的NSString类型及回放快照别名，生产结果由独立生成/核对固定；这些调试失败不作为已通过证据。
- make generate PASS；lint初次仅新测试参数对齐2项失败，格式修正后最终464文件0violation，23项write-baseline仍通过；完整正常Simulator make build PASS（common-build.log）。secret-scan及diff check PASS。未跑全量Unit/quality/UI矩阵或重复缓存测试；本批没有UI接线变化，无新外观、手势、动画、overlay或生产依赖。
- 实际运行时Common/SDK provider、持久账号准备/TBS HTTP、富文本与上传、完整UEG和发布完成接线仍未完成。所有新增公共组件未接入Live，不能宣称完全对齐或异常删除已解决。正常iPhone仍为之前批准的纯beta3对照，iPad不变；不覆盖混合发送候选、不输出READY，继续原任务。


## 2026-10-07 U08 — iOS 签名与回执组件通过，完整原生发送仍在迁移

- 用户再次明确按原版iOS实现，已在AGENTS顶部记入当前授权；Android仅作为旧实现差异对照，不用于填补未知参数。HEAD仍edfb9ef，暂存区为空；保留既有U08代码、用户草稿/缓存/账号/外观，无提交/推送/U09或自动Live发送/上传/重试。
- NativeWriteSigning按同一22.11.1原生方法保留业务覆盖合并、公共副本返回、大写MD5和签名后元数据顺序；5组封闭回放，签名/编码10项Unit PASS（signing-unit.xcresult）。Common中不透明sig不提升为业务字段；未知运行时SDK值未伪造。正常构建signing-build.log PASS。
- NativeWriteResponseRules核对22个错误码谓词、30个账号动作输入与3个parser状态输入；独立3项Unit PASS。NativeWriteResponseDecoder新增iOS原生响应descriptor子集，分离错误码、payload存在性、ID关联和验证元数据；不以anti/info非空直接判失败，也不把解析/ID关联当成完整UEG/UI处理。新13组wire由参考descriptor独立编码，旧84组fixture不变；最终97组verify PASS（response-decoding-verify.log）。原234个生成文件摘要仍完全一致。
- 实际原版回复completion与onCompletion继续查证：短连接成功谓词要求procState3、serverApi.state3、无model.error，成功路径清对应草稿并交完成回调。谓词本身没有pid判定；本App正ID/目标关联是本地防错保护，完整验证和刷新delegate未执行。账号login模型/TBS路径已定位，不把遗留登录模型直接当作Passport主链路。
- 回执Unit初轮编译失败，原因新DTO与已有transport结果同名；仅改为NativeWriteDecodedResponse后8项PASS，补unknown-field回归并调整扫描误报后最终9项PASS（response-decoding-unit-final.xcresult，0.011s）。没有把初次编译失败或0运行当通过。定向检查覆盖两种原生响应、三类回复目标、附带验证字段、明确拒绝、材料缺失、错帖/缺ID、畸形与未知字段；无Live请求。
- make generate-protos、make generate PASS；最终lint457文件0violation，23项write-baseline仍PASS；正常完整Simulator make build PASS（response-decoding-build-final.log）。secret-scan先误判passToken参数表达式与changePassword测试selector，改局部变量表达后PASS，扫描规则未放宽。diff check PASS。辅助脚本一次括号语法错误/错误路径读取已纠正，仅影响本地分析；未读取用户正文/凭据。未跑全量Unit/quality/UI矩阵或重复缓存测试，无新视觉/手势/动画/overlay/生产依赖。
- 本批尚未接入Live。原生账号资料持久准备、完整运行时Common/SDK、TBS请求、富文本/上传、完整回执验证与最终发送接线仍未完成。正常iPhone仍为此前用户批准的纯beta3对照，iPad安装未变，未覆盖不完整的混合发送候选。不能宣称完全对齐或异常删除已修，不输出READY；继续原任务。

## 2026-10-07 U08 — 原生 HTTP 封装已验证，完整原生发送继续

- HEAD仍edfb9ef，暂存区为空。保留原U08/用户改动、草稿、缓存及安装；无Live发帖/回复/上传/重试，无提交/推送/U09。
- 查证两种原生网络manager共用AF multipart分支。新增NativeWriteHTTPRequest，复用原body编码，Proto文件段为data/data/image/jpeg，无Android外层表单/cmd与format查询；使用明确提供的UA/语言/logID/timeout及单会话响应状态，不从响应MIME推导Accept。保持写端点1MiB响应上限和一次发送。它未接入Live，Common/签名及原生账号/回执/上传接线仍待完成。
- EndpointRequestBuilder仅encode模块内可见和允许boundary中的+两处变化。保留beta3原摘要，WRITE_BASELINE声明精确逆向这两项许可编辑后校验；23项PASS。临时目录guard用例证实正常通过、其他header漂移和缺少许可编辑均拒绝；未静默重置摘要。
- 离线原生HTTPEmulator新增4组header/文件段回放，旧20组数据不变；最终全部24组verify PASS。未执行宿主App、读取真实设备/账号值或联网。bbaCUID主路径另查明直接读BBACuidSDK.cuid；不能把defaultCuid旁支当成实际provider。
- 首个测试命令因Swift Testing方法筛选未匹配而运行0项，未记通过；改跑测试类后5项中4项在预期invalidBoundary失败，1项描述脱敏通过。支持+后定向18逻辑项/29参数场景PASS（http-green.xcresult），覆盖新封装、现有transport、共享builder及beta3四目标完整请求快照。没有重跑未改缓存/账号套件、全量Unit/quality或UI长矩阵。
- make generate PASS；make lint 451文件0violation；make build完整正常Simulator App PASS（http-build.log）；secret-scan、diff check PASS。新组件无UI接线，未运行UI。无新视觉、动画、手势、overlay、生产依赖。
- 正常iPhone仍为此前批准的纯beta3对照，iPad未改；未覆盖未完成的混合发送候选。不能把本轮HTTP组件通过称为完全对齐或发帖审核成功，不输出READY。剩余真实Common/SDK及账号、签名、回执、富文本/图片发送路径继续查证接线。

## 2026-10-07 U08 — 原生账号内存状态及响应捕获组件已验证，完整发送接线继续

- 保持最新原生22.11.1对齐授权与现有U08范围，HEAD仍edfb9ef、暂存区为空；未提交/推送/U09。保留原有代码、草稿、缓存、账号及安装，无Live发帖/回复/上传/重试。
- 新增NativeWriteSession：绑定当前有效lease和已有账号元数据，复用非空TBS，仅缺失时产生一个补取操作；空值/失败释放操作，操作对象身份防旧完成覆盖新请求，账号/lease变化失效。回包状态必须携带发起请求的AuthContext，即使误投递给新会话也会被拒绝。没有实现/宣称账号持久化提供者、原生TBS HTTP请求或自动网络重试。
- 新增NativeWriteResponseState与NativeWriteTransport：沿用原URLSessionHTTPClient的TLS/重定向/大小/取消约束，每个请求独立捕获原生写端点的指定状态；普通响应仍不暴露Set-Cookie，全局Cookie jar仍关闭；解析响应后才由Repository显式接受，不把它当成功回执。旧Live Repository/网络/Session/冻结基线文件未改，新组件尚未接入Live。
- 原生ARM64封闭回放新增6个TBS getter、6个header提取样本。查证新主题同样保存/回传svcp_stk；同时继续追到IDPServerAPI与BBABaseAPIRequest的外层Proto文件段构造（data/data/image/jpeg，Proto非nil跳过额外表单params），下层到最终URLRequest仍待核对，不能据此宣称完整wire一致或删帖原因确定。
- 相关Unit：初次测试编译因#require内部漏try失败，修接线后13项中仅header“首个空值后还有非空值”失败；按原生正则语义修正后13项PASS。加强旧响应误投递新账号保护后8项PASS；最后13项PASS，测试fixture类型移出过深嵌套后该唯一受影响用例又1项PASS。均为隔离Simulator纯合成输入，无Live发送。新增回放全部20样本核对PASS，旧8个fixture样本保持不变。
- make generate PASS；最终lint449文件0violation、原23项write-baseline检查PASS；secret scan先将setCookie参数名及较长合成值误判，改明确headerValue命名/短fixture值后PASS，未放宽规则；新增测试CodingKeys嵌套的1项lint失败已修。make build最终正常Simulator完整App PASS（account-build-final.log）；git diff --check PASS。未跑全量Unit/quality/UI矩阵，未重复未改动缓存测试。
- 正常iPhone仍是之前用户批准的纯beta3对照，未覆盖；iPad未改。完整迁移仍缺账号持久准备、Common/签名/实际请求封装、回执/验证及图片发送接线；不将这批组件通过当成发帖修好，不输出READY。无新UI、动画、手势、overlay或生产依赖。


## 2026-10-07 U08 — 原生文字业务构造与 IDL 编码已落地，完整发送迁移继续中

- 最新授权是持续完成与用户指定22.11.1参考包的发帖/回复对齐，仍属U08。本轮已开始实现，未新增阶段。HEAD仍edfb9ef，既有U08草稿及用户改动保留，暂存区为空；未提交/推送/U09。
- 新增 `Config/Protobuf/NativeWrite.proto`/输入锁，独立转录参考descriptor的Common87、回复80、新主题95个字段；既有Android234个生成Swift文件逐字节未改，只多一个NativeWrite生成文件及摘要/metadata。新主题Proto CMD309730、回复309731。`NativeWriteRequestEncoder` 与 `NativeTextWriteParameters` 实现显式上下文下的普通文字业务字段/编码；不负责选路、富文本转换、上传、账号准备、Common运行时字段或签名，尚未接入Live Repository。
- 新增封闭的ARM64离线回放工具 `scripts/fixtures/native_write/`，参考主程序SHA先校验，Foundation/账号/位置/发送使用显式合成替身，未知调用立即中止，不执行宿主App或提供网络出口。原生业务函数产生主题回复/楼层/楼中楼及有/无标题新帖5组数据，回复各命中一次拦截发送。独立Python descriptor编码另核对3个IDL样本。不是官方完整App执行/实网抓包，也不证明删帖已修。
- 新证据收窄此前sig判断：Proto入口传false，公共参数副本与业务合并签名后返回公共字典；其中条件sig不能直接等同data.sig。Common描述符无sig，IDL查不到字段会跳过，并无在该处提升到业务层的代码。本轮增加不自动提升未知公共sig的回归；没有按此前未闭合的“业务sig必需”假设接入Live。地址与证据见API_EVIDENCE本轮段。
- 定向验证：首次编码5项PASS、业务4项PASS；最终相关Unit共10项PASS（native-unit-final.xcresult）。`make generate-protos`、`make generate`含双生成比较PASS；`make build`完整正常Simulator构建PASS；最终lint444文件0violation，原23项写入基线检查PASS；secret-scan和diff check PASS。初轮lint13项格式/复杂度/嵌套违规已修；可重放工具初次因IDL消息名缺Idl后缀失败，修正后逐fixture比较PASS。没有运行全量Unit/quality/UI矩阵；本轮没有UI接线变更。
- 原生账号TBS生命周期、实际页面上下文、Common/签名完整来源、响应头状态闭环、回执/验证及现有图片发送的兼容接入仍未完成。不能把这些新组件的通过称为完整迁移或审核成功；MODERATION_CAUSE_UNKNOWN保持。没有改变Live发送行为、编造SDK身份、读取运行时凭据或自动发送/上传/重试。
- 正常iPhone仍是用户之前批准的纯beta3对照，未覆盖为本轮源码；iPad安装也未改。当前新构建只用于编译验证，不是可验收的原生迁移候选。账号、历史、缓存、排序、阅读位置和草稿均未清理；无新UI、动画、手势、overlay或生产依赖，不输出READY。继续完成剩余发送链路后再交付完整Live App。

## 2026-10-07 U08 — 22.11.1 账号/回执续查，完整迁移仍未完成

- 继续用户指定的发送对齐任务，无新增阶段。确认 TBS 完成块按发起时 UID 保存非空结果；原生回执按 serverApi 的错误码和错误信息进入对应验证处理，不能等价于当前任意 anti/info 字段非空即失败。返回 header 状态读取已追到实际 request，但该方法不提供账号清理契约。确切方法/地址追加在既有 WRITE_MODERATION_COMPARISON 顶部。
- ignored 分析工具补 UTF-16 CFString 后确认楼中楼静态正文前缀；SDK 入口 ret 跳板后的方法体可读，已定位一次性 token、实例状态读取和不同结果分支，完整间接控制流/初始化/更新仍未还原。未把局部反汇编或 selector 存在误写成完整运行证据；没有读取用户正文、凭据、设备值或嵌入接入密钥。
- 本轮只改本记录及既有差异记录，分析文件留在 Artifacts。没有生产源码/冻结摘要变化、没有新 App 构建或覆盖、没有 Live 发送/重试。iPhone 仍是此前批准覆盖的纯 beta3 对照；不能用它证明原生迁移。无动画、手势、overlay、依赖变化；完整迁移和删帖原因仍未解决，不输出 READY，不暂存/提交/推送/U09。
- 已执行 make write-baseline-check（23项PASS）、make secret-scan（PASS）、git diff --check（PASS），暂存区为空，HEAD仍edfb9ef。没有生产变化，未重跑Unit/UI/build；以上检查不构成发送/审核通过证据。

## 2026-10-07 U08 — 用户指定22.11.1正常发帖包为主要行为基准

- 用户再次明确：给出的去广告版发帖正常，按这个行为完整对齐；随后提供新版22.11.1 IPA。接受为有效功能基准，22.7.3只作对照，不以修改包身份/无抓包拒绝分析或要求重复试发。最新授权允许必要发送链路迁移；旧beta3冻结不构成该授权的阻碍，但未用更新摘要掩盖实现差异。
- 新IPA只读确认22.11.1/22.11.1.0、arm64 iPhoneOS、cryptid0；SHA8b7daae0…cba9f15，主程序SHA4f0cb74c…702d9eb。只复制主程序到ignored分析目录，未安装/执行/修改IPA，未读凭据、提取接入密钥或Live写入。
- 新版交叉验证匿名值、业务TBS、iOS Common、签名和Set-Cookie/svcp_stk状态闭环仍同前版；已确认TBS缺失补取为HTTPS /c/s/tbs。新版AddPost80字段、Common87字段；新增send_from #80来自replyStatScene，旧业务字段编号/类型不变。账号和上下文并非照抄固定参数：定位SSDK_zid→SSDKLib.getZInfoWithEvent及带CUID/appKey/secretKey/ready callback的初始化接口。没有证据认定该可选字段必填或导致删除；完整provider/验证生命周期仍未移植。
- 本轮只更新既有TASK_STATE、WRITE_MODERATION_COMPARISON、API_EVIDENCE、UNKNOWN，ignored目录保留证据。源码/安装/用户数据和U08草稿保持；无新动画/手势/overlay/依赖。不再把“不能认证原始App Store包”写成实施门槛，也不以静态部分相同宣称完整修好。初次metadata无methods键检索失败已修正，SDK线性反汇编不足已记明。
- 检查：make write-baseline-check 23项PASS、make secret-scan PASS、git diff --check PASS。不跑无代码变化的Unit/UI/build，不暂存/提交/推送，不进入U09。完整发送迁移尚未完成，不输出READY。

## 2026-10-07 U08 — 用户提供官方衍生解包，确认静态请求差异

- 用户确认官方22.11.1/22.7.3均可发送，并提供本机“贴吧去广告”解包目录。只读TBClient程序/元数据/制作记录，未执行注入库、未读App用户数据、未发送或重发。程序为22.7.3/22.7.3.0、arm64 iPhoneOS、cryptid0，SHA67867b7a…04c03c0与制作记录相符；含去广告注入，不能认证为原始App Store包；22.11.1未分析。
- 本轮沿用接口证据/根因流程，只追普通回复模型到参数、IDL及multipart。同post/add和CMD309731，不等于同实现：iOS初始anonymous0 vs 当前1、业务data.tbs vs 只设common.tbs、账号KV/数据库含缺失刷新分支 vs 每次login/资料、clientType1及iOS UA来源 vs Android2、业务参与签名/额外sig、响应Set-Cookie状态缓存并回传svcp_stk，均有精确方法/地址证据。详见WRITE_MODERATION_COMPARISON最新节，不记录凭据值/正文/设备ID、不复制另一App运行时身份。
- 独立解析包内descriptor，AddPost当前67字段/Common当前45字段对应tag/type均无冲突；官方schema分别79/85项，不将新增项全部视为必填。真实手机当次配置开关、选路、上下文来源和最终请求/响应仍未确认，静态差异不能定为删除根因；不提供只改字段的试发补丁。当前OFFICIAL_IOS_STATIC_DIFFERENCES_CONFIRMED / RUNTIME_CONTRACT_INCOMPLETE / MODERATION_CAUSE_UNKNOWN。
- 仅更新本记录、WRITE_MODERATION_COMPARISON、API_EVIDENCE、UNKNOWN；忽略目录保留有界反汇编/descriptor/摘要。辅助JSON/正则/边界解析初次失败已纠正，LLVM反汇编超时改用Capstone和LC_FUNCTION_STARTS；不隐瞒为一次全通过。当前生产源码、基线摘要、现有安装与用户数据均未变；iPhone仍为纯beta3对照，iPad仍为前次U08候选。无新动画/手势/overlay/依赖，无Unit/UI/build重跑，不输出READY或修复成功。
- 检查：make write-baseline-check 23项PASS、make secret-scan PASS、git diff --check PASS；git diff --cached为空。仅证实生产发送冻结未漂移及文档检查通过，不是Live修复结果。不暂存、提交、推送或进入U09。

## 2026-10-07 U08 — 纯 beta3 仍被删，官方 iOS 对照证据待补

- 用户确认原始 beta3 覆盖后仍失败，手机 TiebaLite 也失败；异步答复同一账号近期在官方 iOS App 能发送且没有随后被删。最新要求是调查并对齐官方 iOS；不能继续将“手机 beta3 可用”或恢复旧源码作为修复成功证据。当前 HEAD edfb9ef，U08 与用户原有改动保留，暂存区仍空。
- 使用既有根因/接口证据流程，限读当前发送链路、最新状态及相关规格。当前账号准备11.10.8.6、回复12.35.1.0、新主题7.2.0.0均为Android参考路径；没有官方iOS实现证据，不能猜UA/client type或安全参数替换。具体对照和公开来源记入WRITE_MODERATION_COMPARISON顶部，不新增阶段。
- 公开App Store、百度隐私政策及API/SDK合作页已读取；通过独立无登录Chrome/jshook核实政策中的账号/设备安全范围，但其不提供本次发帖字段、顺序或删帖原因。jshook首次call要求先activate，激活后读取成功；没有读取用户浏览器会话或发送内容。
- 连接iPhone的App元数据可见百度贴吧22.11.1及另一bundle的22.7.3；用户随后确认两个版本均能正常发送。工具filter未按预期过滤显示，未进一步访问无关App。现有devicectl文件域不支持导出官方程序包，未读取官方App数据/凭据。现有安装包/脱敏记录路径仍待用户回复。对照证据缺失前不制作“猜参数”候选。
- 本轮仅更新本记录、既有差异记录和UNKNOWN；生产源码、冻结基线及安装均未变，正常iPhone仍为上轮纯beta3对照，iPad仍为前次U08候选。不新增动画、手势、overlay或依赖；不自动发布/上传/重发/申诉。make write-baseline-check 23项、make secret-scan、git diff --check通过；不重跑无变化的Unit/UI/build。独立取证Chrome已关闭，未关闭用户浏览器。
- 当前 `OFFICIAL_IOS_EVIDENCE_NEEDED / MODERATION_CAUSE_UNKNOWN`，不输出READY或修复成功，不暂存/提交/推送/进入U09。

## 2026-10-07 U08 — 用户批准覆盖，原始 beta3 同设备对照已安装

- 用户明确回复“覆盖”。仅将正常iPhone 70D93841-1FEB-445A-8FAD-B1C29B981D5D覆盖为上一轮从4534020完整未修改源码构建的Release Simulator App；没有重新构建、改变源码/发送行为或覆盖iPad。当前iPhone运行的是纯beta3，**不是当前U08工作树候选**；不能在后续记录中混淆。
- 覆盖前复核候选主程序SHA及codesign；terminate → install → launch成功，安装后主程序SHA与beta3-app-proof一致。原data container保持，持久草稿目录全部文件覆盖前后及启动后摘要一致，仅在内存比较、不记录文件名/正文。证据ignored runtime-comparison/beta3-installed.json；无uninstall/erase/清Keychain/迁移或清缓存。
- CUA确认仍已登录、原浏览历史存在；已进入真实帖11082472712，第10/11/13楼及“评论一番”入口可见，留在帖子页。未点击发送、上传、点赞或修改草稿。旧版界面/会话草稿能力为本次明确批准的临时对照，U08持久草稿文件、当前工作树及新版完整App均保留。
- 同设备beta3实际发送及后续留存仍待用户操作，本轮只确认覆盖和启动，不输出发送修复通过。无生产代码变化，不重跑Unit/UI/构建；diff check通过。不暂存/提交/推送/进入U09。


## 2026-10-07 U08 — beta3 对齐候选仍被删，USER_RETEST_FAILED

- 用户再次确认当前电脑Simulator发出的回复仍被删除。上轮源码/Mock通过不能证明实际发送留存正常；本轮不输出修复成功/READY，不再修改发送协议、回执、刷新或增加请求/重试。
- 已复核当前正常iPhone安装程序及debug dylib与上轮beta3-alignment候选哈希相同，排除旧安装；本地原版beta3 IPA摘要与发布时回执一致，IPA内程序与留存归档一致，来源记录为4534020。原IPA为iPhoneOS Release，当前候选为Simulator Debug；这只是已知构建/运行环境差异，不是删除原因。证据在ignored runtime-comparison/current-installed.json及published-package.json。
- 核对剩余U07入口与U08草稿接线：发送目标仍来自原构造器，全App仍单一TextComposerHost、LiveTextWriteRepository直接使用原生产HTTPClient。保留的差异是本地持久恢复/保存、namespace隔离、图片文件所有权及已验收视觉，不据此猜删除根因。
- 新增直接离线测试：四类目标分别将合成草稿落盘、重建并恢复，再经真实ComposerStore → LiveRepository → URLSessionHTTPClient，在HTTPDataLoading入口截取URLRequest（Mock返回，不启动网络）。URL、方法、全部请求头、正文SHA、超时均匹配既有beta3快照；按原顺序读取账号/公开资料各一次、发布一次，完成后再调send不发第二次。request-boundary 2逻辑项/8参数情况PASS。该结果仍不是当次Live线上抓包或服务端证据。
- 新测试首次lint仅参数缩进失败，调整排版后lint440文件0violation、secret-scan、diff check通过；未动生产源码、未重跑全套Unit/UI。读取AppEnvironment+Live/Config/Base的路径不存在，已按实际文件定位；不据此推断缺少实现。
- 为避免继续假设，已在ignored目录导出纯beta3源码，App/Sources/Generated/Resources/Config/project.yml共664文件逐字节匹配tag；单独构建完整Release Simulator对照App，不改工作树、不新增模拟器。原始beta3完整Release Simulator App构建成功，664文件构建前后仍匹配；codesign、Simulator嵌入entitlements验证通过，application-identifier/Keychain组与当前正常候选一致。beta3-app-proof.json记录App及摘要。因为纯beta3也会暂时切回旧界面和会话草稿功能，已请求用户确认后才覆盖正常模拟器；当前正常App未更换，全部数据保留。后续须区分旧版同设备结果与新候选结果，不能把设备差异直接定为原因。MODERATION_CAUSE_UNKNOWN，不提交/推送/进入U09。


## 2026-10-07 U08 — 用户明确要求完整对齐 v0.2.0beta3，发送链路冻结

- 最新授权覆盖 U08 原来的回复后局部刷新方案：必须以手机已确认可用的 v0.2.0beta3（4534020d509ea0188dced53cf582fcc775dbb71e）完整恢复发送行为，后续不得擅改。当前 HEAD 仍 edfb9ef，未提交。此前“只恢复 Accept／撤回一次额外读”确实不等于完整对齐。
- 已逐字节恢复 Endpoint、EndpointRequestBuilder、TextWriteProtocol、ThreadReaderStore、SubpostsStore、CachedReadingRepository、ReadingContentCache 和原 R09 回执测试；保留 U07 视觉/链接接线，只恢复两处 textComposer 成功回调为原 reload/refresh。Composer 发送主体和 Service present/didDismiss 本来与 beta3 相同；恢复 View modifier、成功清草稿→回执→dismiss 原块，去掉新增账号变化强制关闭。保留草稿存储恢复/落盘/就绪门槛、namespace 隔离和图片文件所有权，不宣称全 App 与 beta3 字节相同。
- 已撤回 MIME 扩展、成功优先、requestAcceptMIMETypes、target 成功回调、lastReplyReceipt、父楼/尾页选择、dirtyPages 及追加读取。原 application/protobuf 的结果未知、anti/info 附带字段验证提示也按 beta3 原逻辑保留；不得再偷偷“兼容”。U03/U04 原缓存、排序、历史、位置及用户数据不删除。无新动画、手势、overlay 或依赖。
- 冻结：AGENTS.md 新增用户长期约束，Specs/WRITE_BASELINE.json 从 tag 提取23项完整文件/代码块/接线，scripts/verify_write_baseline.py 纳入 make lint。首次检查准确列出10个漂移文件，恢复后23项PASS；四类请求完整属性/正文SHA与原冻结快照一致。网络/Session/生成协议242源码逐字节0差异（ignored beta3-alignment/dependencies-proof.json）。逐项结果见WRITE_MODERATION_COMPARISON顶部，不重开历史审计阶段。
- 测试：原分支在新 beta3 回执断言上 unit-red 6逻辑项/10issue失败（MIME及anti优先级），恢复后 unit-green 共30逻辑项中29通过、1个新阅读测试选点失败。实际请求 [0,2,3,0,2]，原因是fixture第17楼在第一页/第二页重复，旧版刷新后将该锚点归到第二页；reload-observation保留原证据。测试改用唯一首楼，生产原码未改；reload-final 4项PASS，其余26项沿用unit-green，最终30项全部已通过。不再要求被用户撤回的全部旧协议断言；完整旧源码/测试保存于ignored beta3-alignment/before。初次清单生成引用了不存在的EndpointExecutor文件，改为实际EndpointPipeline；diff check曾发现文档尾空行，已修。未隐藏这些失败。
- UI：隔离Mock的iPhone成功关闭/一次刷新/真实返回新ID及原位置/仅清对应草稿23.932s PASS，文字表情图片跨进程恢复35.973s PASS；iPad对应成功关闭/刷新27.076s PASS。没有Live发送/上传/重发/审核探测。make lint 440文件0violation（含基线检查）、make build、secret-scan及修正后的diff check通过；未跑全量Unit/quality。
- scripts/visual_review_build_install.sh U08 成功，完整正常Live已覆盖原iPhone/iPad；两端主程序/debug dylib与候选哈希一致（beta3-alignment/installed-binary-proof.json），无卸载/erase/清Keychain/改签名。CUA确认iPhone已登录、历史存在，经原浏览记录进入真实帖11082472712，第10/11/13楼及评论入口可见，留在帖子页。一次CUA解析diff行索引失败无点击，改读完整AX后正常导航；未打开/修改用户草稿。
- 服务端删帖原因及恢复后真实发布留存仍 MODERATION_CAUSE_UNKNOWN；不能从源码相等或Mock通过宣称删帖修好。此前历史READY不是当前实网成功证据。本轮READY仅表示beta3发送基线恢复候选已安装待用户检查，不是审核通过。未暂存/提交/推送，不进入U09。


## 2026-10-07 U08 — 撤回未经实网证实的额外读取，STOP / MODERATION_CAUSE_UNKNOWN

- 用户再次反馈当前Simulator回复遭异常行为删除，并明确反对继续改回复行为。承认上一轮没有确认实际首读结果就新增同页额外读取，不应把合成场景当成该实网问题的根因。
- 仅撤回上一轮新增的额外同页读取、后置dirty标记和对应的Fixture假设；四个源码/测试文件已恢复到该改动前的精确字节。ThreadReaderStore/U08ReplyTests与reply-fix留档哈希一致，Fixture/UI与verification-fix哈希一致。发送协议、Endpoint/Builder与用户曾报告一次成功时的request-compatibility候选哈希一致；并非把整个U08回退到beta3，保留全部草稿/缓存/恢复和用户改动。证明见ignored withdraw-extra-read/restored-source-proof.json。
- 撤回内容与其测试完整备份在同目录withdrawn；原失败/通过的xcresult仍保留。恢复的是既有代码，沿用其定向Unit/短UI结果，不删失败来宣称产品已通过。旧“READY”是历史交付记录，当前实际发送可靠性与自动刷新均未验证解决；不输出READY。
- 本轮不再新增诊断/请求/重试/定时器，不探测审核，不读取真实凭据，不进行任何Live发送/上传/重发或申诉。make lint（440文件0violation）、make build、secret-scan、diff check通过；完整正常Live已覆盖iPhone/iPad，两端主程序/debug dylib均与撤回后候选哈希一致（withdraw-extra-read/installed-binary-proof.json）。未卸载/erase/清Keychain或用户数据。完成这次局部撤回后停止，不再追加机制；不暂存/提交/推送，不进入U09。

## 2026-10-07 U08 — 成功回复后首次读取仍旧页的有界确认

- USER_REPORTED：本次回复成功；编辑器自动收起、发送前已到底、未看到刷新失败，但手动下拉后才显示。即时回复可见仍不能证明后续审核留存；本轮不改已经对齐beta3的发送/回执/上传/认证代码。
- CODE/FIXTURE_EVIDENCE：成功回调和绕过缓存的首次读取已存在。缺口是首次读取成功但receipt未出现且hasMore仍false时直接结束，并把返回的旧页缓存标为fresh。已有Fixture假设首次读取就可见，未覆盖这一路径。新合成场景在旧代码上明确失败：只读2次（含初始加载）、新ID缺失、一直不可见时cache仍fresh。真实当次首个响应未保存，因此不能断言用户实网必然也是同一原因。
- 最小改动只ThreadReaderStore.replySucceeded：原已读到底的主题回复首次读取成功但缺receipt时，最多再读一次；有新增页则沿用原读取下一页，否则再强制刷新同一末页。没有固定delay/轮询/重发；仍缺receipt或第二次失败时保留内容/回执/锚点并重标相关cache dirty。取消/新代次/账号变化不再继续。无界面、动画、手势、overlay、依赖变化；VirtualizedList/恢复/预载策略及协议未改。
- 基线6项PASS。首次新测试因Int→Int32编译失败，修测试类型后unit-red2在上述4个断言失败。unit-green7项、补取消/第二次失败后的unit-final9项均PASS，涵盖三页/跨页/锚点、首次仍旧、一直不可见的上限、取消、失败、未知结果不重发与回调一次性。lint440文件0violation。既有写入候选6文件哈希一致，证据write-source-unchanged.json，未重复全套发送/缓存测试。
- 同一短UI的本地读服务改为首次仍返回旧内容，继续要求自动关闭、无确认alert、新ID/正文可见、原Y保留及仅清对应草稿。iPhone23.936s、iPad27.194s均PASS。make build、secret-scan、diff check通过；未运行全量Unit/quality/无关矩阵。
- scripts/visual_review_build_install.sh U08覆盖完整正常Live iPhone成功；iPad同候选覆盖成功，两端主程序/debug dylib哈希回读一致，证据reply-refresh-followup/installed-binary-proof.json。未卸载/清登录/缓存/草稿。iPhone已登录，经浏览记录进入刚回复的真实帖11082472712，留在第10/11/13楼附近及评论入口。CUA滚动/拖动没有改变画面，不据此声称复核了第14楼或修后Live发送刷新；自动回读显示新楼由隔离Mock短UI证明，未操作真实发送。
- 当前交付覆盖“一次读取滞后”的本地缺口，不保证服务端任意长延迟或审核留存；修后实际发送的自动刷新仍待正常使用确认。未暂存/提交/推送，不进入U09。READY_FOR_USER_VISUAL_REVIEW。

## 2026-10-07 U08 — beta3 请求兼容回查，删帖原因仍 UNKNOWN

- USER_REPORTED：当前电脑Simulator发出的回复收到“涉嫌异常行为”删除通知；手机GitHub发布版v0.2.0beta3仍能正常发送。基线明确为4534020d509ea0188dced53cf582fcc775dbb71e，当前HEAD edfb9ef。设备/系统/网络与版本同时不同，不把两者当成严格单变量实验，也不归咎于Simulator。
- CODE_EVIDENCE：此前“发送请求没变”的结论错误。EndpointRequestBuilder把allowedResponseMIMETypes同时用于Accept；U08补收application/protobuf时，AddPost的出站Accept也从两项变成三项。这是已确认的意外请求差异，不是已确认的服务端删除原因。此前成功优先的回执判定确有修改，但只影响本地成功/失败及后续关闭、读取刷新，不会撤回或改变已经提交的正文。
- 当前只修该可证实差异：分离请求Accept和响应MIME允许集合，为AddPost固定beta3的请求Accept，继续正确解析已实测application/protobuf回执。以纯合成输入离线比较四种发送目标的完整HTTP请求字段/正文摘要；保留草稿、自动关闭、局部刷新和单次发送。没有重发用户内容、读取凭据或打开申诉链接，不伪造设备/验证参数。
- 离线红测：从beta3发送构造代码生成纯合成冻结请求快照；三类回复仅Accept不等，新主题相等。最初两次编译未过分别为测试缺MainActor、在同步auth上多await；只修测试接线后得到上述行为失败。临时旧协议生成器移入ignored证据，未保留第二套发送实现。最终以冻结fixture核对method/URL/全部header/bodySHA256/timeout/bodyLimit/redirect。
- unit-green与最终unit-final均15项逻辑测试PASS；final包含beta3四目标、请求/响应MIME分离和非法值拒绝、共享builder既有5项、回执三目标各一次写入、重复send不追加、结果未知草稿保留不重发。首轮lint只因旧测试文件加用例超600行失败；将新增用例收在U08直接测试文件，原EndpointFoundationTests回到未改，final lint440文件0violation。phone-ui 24.136s PASS：Mock发送后关闭/无alert、新回复/原位置、对应草稿清理；iPad界面及关闭接线本轮未改，沿用上一轮27.027s结果，不重复长矩阵。
- make build、secret-scan、git diff --check通过。scripts/visual_review_build_install.sh U08构建并覆盖正常iPhoneLive成功，iPad同一完整App覆盖成功；两端主程序和debug dylib均与当前候选哈希一致（request-compatibility/installed-binary-proof.json）。未卸载/erase/清Keychain或用户数据；没有新增视觉、手势、动画、overlay、依赖或日志机制。
- 正常iPhone仍已登录，经浏览记录回到最近真实帖子中部，第5/6/8楼可见，停在帖子页；未点击发送或动旧草稿。当前只交付“恢复beta3请求兼容”的候选，不以Mock或即时回复可见证明服务端审核修复。删帖原因及修后持续发布可靠性仍UNKNOWN，不能将本轮标成删帖已解决。不暂存/提交/推送，不进入U09。

## 2026-10-07 U08 — 成功回执被验证字段覆盖，READY_FOR_USER_VISUAL_REVIEW

- 用户在MIME修复候选再次亲自发送：回复确已发布，但编辑器提示verificationRequired。这是App本地文案，不是直接展示的服务器原文。该次原响应未保存，具体触发字段值仍UNKNOWN；不把构造的vcode_type=0等测试值冒充实测，也不再要求用户替诊断重复发帖。
- 源码证据：旧decodePost先检查anti/info非空字段（包括非空字符串0的vcodeType及不明accessState.type），然后才检查error/pid/tid。Android createProtobufApi→ProtoFailureResponseInterceptor先拒绝非零错误，AddPostRepository以新pid确认，再由ReplyViewModel/ReplyPage成功关闭。原来的“附带字段优先于有效成功回执”是本地无依据规则，MIME修复暴露了后续这一独立误判。
- 最小修改仅AddPost回执判定：error0+正pid+匹配的非空tid确认成功；附带anti/info不覆盖成功回执。非零错误永不成功；未确认成功时保留need_vcode/验证码材料的verification分类，类型/accessState本身不冒充验证要求。错thread、缺ID、未知结果、Session和不自动重发保护保留。无UI、缓存、上传、请求参数或AddThread改动。
- unit-red新两项参数化规则在旧代码明确失败（6个成功回执元数据组合，3个无回执类型描述误判）。既有验证码测试改成带明确非零服务器错误的拒绝回执，保留原ID与挑战字段和失败断言；新用例另覆盖error0但无ID的真实挑战分类，不以删断言过关。unit-green 7项逻辑测试PASS，含全部旧触发字段、原MIME/三目标单次发送、服务器/验证失败及未知结果草稿保护。合成数据只经Mock，未发Live请求。
- 同生产pipeline携带附带字段的iPhone短UI24.395s、iPad短UI27.027s均PASS：收起、无alert、新行、原Y及清对应草稿断言全保留。make lint439文件0violation、make build、secret-scan、diff check通过。此前缓存/多页刷新结果沿用，无全量Unit/quality。
- scripts/visual_review_build_install.sh U08成功；完整正常Live覆盖iPhone/iPad，两端主程序/debug dylib均与最终候选匹配（verification-fix/installed-binary-proof.json），五个直接相关源码/测试哈希同目录保存。未卸载/清数据/改签名，账号、缓存、历史、草稿保留；没有新日志或诊断机制。
- 正常Live仍已登录，经历史进入用户刚回复的11082701396，第13楼154006608889可见，截图核对外观未改，停在帖子页供继续使用。未点击发送或删除旧草稿。修后实际发送关闭/刷新仍待用户手动验收，不能把Mock或已发布回复可见写成修后Live发送通过；真机未验证。未暂存/提交/推送，不进入U09，READY_FOR_USER_VISUAL_REVIEW。

## 2026-10-07 U08 — 回执 MIME 修复，READY_FOR_USER_VISUAL_REVIEW

- 用户已亲自再次发送并提供“结果未知”和服务端新回复同时存在的截图。正常iPhone本次元数据：HTTP200、208bytes、MIME protobuf（诊断常量对应application/protobuf）、payload protobuf、hasData=true、serverRejected=false、postID positive、threadID matches-target、pipeline unsupported-content、repository result-unknown。仅复制这份白名单元数据到ignored receipt-diagnostic/live-response-metadata.json，未采集正文/原响应/凭证。
- 根因确定：write.post只允许application/octet-stream和application/x-protobuf，在解码前拒绝了服务器实际返回的application/protobuf。仅补该端点MIME；当时误称未修改发送请求，现已发现该白名单也改变Accept头（见顶部纠正记录）。上传/认证、共享pipeline、ID校验或重试未改，保留此前已实现的自动关闭、保留位置刷新与草稿逻辑。
- 新U08WriteReceiptTests经真实Repository→MockHTTPClient→Composer复现三种回复目标resultUnknown；unit-red三个逻辑测试失败，均在预期MIME分支。保留该回归与既有无效ID/错thread/验证码/服务器错误/畸形/HTML保护。UITESTING本地回复服务改用同一生产pipeline解析合成application/protobuf回执，原短UI继续严格检查编辑器关闭、无alert、新行可见、首楼Y及清对应草稿。
- 临时诊断源码/测试已备份到ignored receipt-diagnostic并撤除，LiveTextWriteRepository精确回到原生产实现；未动用户草稿或其他U08实现。与此前reply-fix候选18个源码哈希相比，仅本地Fixture与UI注释改变；另外新增本次一个端点MIME条目和3项定向Unit。无外观、动画、手势、overlay或依赖变化。
- unit-green共8项逻辑测试PASS（新回执3项，U08保留式刷新/未知结果5项）；三类回复取得回执，账号资料与Profile各一次、真正write仅一次，成功后的重复send不发请求。无效ID/错thread/验证码/服务端错误/畸形PB/HTML仍拒绝；旧两种MIME继续有效。phone-ui 24.043s、ipad-ui 27.339s各1条PASS：同生产pipeline的已观察MIME→编辑器关闭/无alert→新行可见/原Y保留→再次打开空草稿。测试均在隔离设备使用合成数据。
- make lint439文件0violation、make build、secret-scan、diff check均通过；未运行全量Unit/quality/压力矩阵。scripts/visual_review_build_install.sh U08成功，完整正常Live覆盖iPhone/iPad，两端主程序/debug dylib均与候选一致（receipt-fix/installed-binary-proof.json）；最终源码哈希同目录保留。没有卸载、清数据或签名变更。
- iPhone正常Live仍显示已登录，经历史进入用户刚回复的11082715433，截图核对第3楼154006516140仍可见，保留原界面并停在帖子页回复入口。未操作发送、旧草稿或远端数据。修后真实发送关闭/刷新仍待用户手动验收，不把Fixture写成Live通过；真机未验证。未暂存/提交/推送，不进入U09，READY_FOR_USER_VISUAL_REVIEW。

## 2026-10-07 U08 — 已确认 resultUnknown，等待真实回执分支

- 用户回答提示为“发送结果暂不确定，请先到目标页面确认”。明确属于 resultUnknown，先前去成功 alert 和尾页刷新修复仅覆盖已确认 receipt 分支；不能据此宣称解决实网发送后不关闭问题。
- 核对当前 LiveTextWriteRepository/TextWriteProtocol、发送 Store 及锁定 Android AddPostResponse/Repository/ReplyPage。旧响应未保存，发送后格式校验、解码、回执 ID 或会话变化均可能落入同一提示；具体原因仍 UNKNOWN。没有猜测 MIME、放宽 ID 或将模糊结果当成功。
- 当前仅新增临时 Debug-only TextWriteResponseDiagnostics 和 Live repository 包装接线：同一 HTTPClient 原样执行一次，写回复响应在原 pipeline 前形成固定类别/布尔/计数记录，再记录 repository 结果。单份元数据覆盖保存于 App Caches/U08ReplyDiagnostics/last-attempt.json；不含正文、响应、URL、ID 值或凭证，也不观测账号资料响应。Release 不启用；无界面、动画、手势、overlay、依赖或 Session/缓存策略变化。
- 首轮 11 项定向 Unit PASS（新增诊断4项含4个回执参数场景，原单次发送1项、Composer6项）；lint 首次新增函数复杂度13超限，拆分固定错误分类后440文件0violation。分类拆分后的4项直接复核PASS；make build、secret-scan、diff check通过。此前成功发送后关闭/刷新/清对应草稿的iPhone/iPad短UI结果沿用，此轮没有改其接线，不重跑全套。
- scripts/visual_review_build_install.sh U08成功；完整正常Live覆盖iPhone/iPad，主程序/debug dylib均与候选一致，证据receipt-diagnostic/installed-binary-proof.json。未卸载/清数据，iPhone仍已登录，经历史回到原帖已缓存楼层并打开原回复编辑器，草稿保留。历史AX索引一次过期，重新读取当前索引后正常进入，不作为App失败。没有自动发送实网内容，也没有删除用户已发布但仍保留的草稿。
- 下一步需用户主动发送一条新的、确实想发布的回复（不能重复发送已发布的旧草稿），才能读取last-attempt.json定位真正失败分支；旧响应没有保存，Mock不替代Live证据。此候选是定位用完整App，问题尚未宣称修复，不输出READY。未暂存、提交或推送，不进入U09。

## 2026-10-07 U08 — 用户反馈：发送后自动关闭与回复刷新

- 用户已实际确认Live发送成功、草稿保留和帖子重进位置，进一步要求成功后自动收起编辑器、无需确认，并刷新显示回复。保留此前U08实现及所有用户数据；本轮不提交、不推送、不进入U09。
- 确定性证据：ui-red在真实生产编辑器接Fixture发送后已自动关闭，随后阅读页弹出的“发送成功”alert导致无需确认断言失败（14.483s）；Android ReplyPage的ReplySuccess同样执行onBack，不要求确认。删除ThreadReaderView/SubpostsView这两处阻塞alert，保留原receipt关闭编辑器和只清对应草稿的接线，不另造关闭机制或提示UI。
- 新内容定向测试：同页缓存刷新已经能取得服务端新行；unit-red明确失败于原先已到底、回复新增下一页时，只刷新旧尾页。修后仍只刷新父楼页/已加载尾页；原已到底且返回新增下一页、receipt尚不可见时最多追加一页，不追读整帖、不伪造审核未返回的行。楼中楼刷新已加载尾页，独立于较早的阅读锚点；缺少页来源的注入快照不再直接跳过刷新。保留分页范围/readAnchor、失败回执及原请求代次保护。
- 修改边界：上述两个View、两个Store、直接Unit/UI及隔离Mock接线，更新本ADR/状态契约；没有改写发送API、上传、草稿、缓存预算、VirtualizedList、恢复、Pager、图片或已验收外观。只移除系统alert，无新自定义动画、手势、overlay或依赖。
- 定向结果：unit-green 10项逻辑测试PASS（其中缓存同页/跨页2个参数场景），subpost-unit新增1项PASS，包含三页/原锚点保留、失败回执、错thread拒绝、结果未知不自动重发及原单次发送保护。phone-ui-final 1项23.967s PASS：发送后编辑器消失、无alert、服务端读取的新900002行可见、原首楼Y不变、再次打开已发送草稿为空。此前phone-ui失败为重启后未重选动态Tab；phone-ui-2失败为把现有富文本TextView查成StaticText，附件已证明900002行存在且可见，按实际控件修正查询，不放宽内容/可见/位置断言。新增Fixture只在UITESTING显式开关下接入，正常Live不可启用。
- 首轮lint报初始化方法长度与fixture参数对齐，正常拆分fixture工厂和对齐后lint通过（438文件0violation）。iPad同一短UI 27.092s PASS；make build、make secret-scan、git diff --check通过。正常完整Live覆盖iPhone/iPad，两个主程序/dylib均与候选匹配（reply-fix/installed-binary-proof.json），18个候选源码哈希另存；未卸载或清数据。

- Live交付回查发现更关键的新证据：真实帖11082826300已存在用户发布楼层154006424005，重新打开同一回复编辑器仍恢复原12字草稿。仅移除成功alert不足以证明解决本次实网症状；用户所说“确认回复”也可能是resultUnknown提示。已请求用户辨认提示原文，尚未收到答案，未自动发送或采集正文/凭证。当前候选保留在真实回复编辑器，原草稿未动。本次实网回执原因仍UNKNOWN，暂不宣称发送后不收起问题已完全解决，不输出READY。此前成功Mock、尾页漏刷和去alert的结论仅覆盖其实际验证分支。

## 2026-10-07 U08 — Live键盘恢复，READY_FOR_USER_VISUAL_REVIEW

- 用户反馈回复框无法呼出键盘。正常Live回复正文已有光标、draftReady已完成、表情面板可用；同一iPhone Simulator的系统Spotlight输入框也无软键盘，排除U08草稿等待禁用输入这一假设。设备原Connect Hardware Keyboard为关闭，单独开关此项无效；经Simulator的I/O → Keyboard → Toggle Software Keyboard恢复显示，再将硬件键盘连接恢复原关闭状态后，系统搜索和Live回复均显示键盘。不将系统日志中的无iCloud账号等无关错误当作根因。
- 本轮没有修改生产代码、布局或手势，也没有清数据、重装或发送内容。正常Live高通吧帖子11082715433回复入口已打开，系统键盘可见；表情面板→系统键盘切换直接复核通过，停在空白回复框供用户操作。截图：ignored Artifacts/VisualReview/U08/20261007-095055-live-reply-keyboard-restored.png。下条锁屏阻塞已解除。
- 已核对17个候选源码文件哈希全部一致；沿用已安装U08候选的17项定向Unit、3条UI及lint/build结果。本轮make secret-scan、git diff --check通过，仅处理Simulator显示状态，不重复构建测试。U08继续未暂存、提交或推送，不进入U09；真实发送及真机未验证。

## 2026-10-06 U08 — IMPLEMENTED，等待解锁打开Live验收入口

- U07 已按用户授权精确提交 `edfb9ef7caff71e89d94fd8c473be66ba48dd8bc`，message `fix: wire production links and content actions`；37文件，未推送。用户原有模拟器清理记录、未跟踪Prompts/skill及其他排除项保持未提交。
- 本阶段只做回复回执的相关页刷新与草稿持久化。复用U03现有保留式刷新，VirtualizedList/Pager/恢复/已验收视觉不改；不发送任何Live内容，不进入U09。
- 已执行基线R09ComposerTests 6项PASS。新增草稿/回执及旧发送与上传状态共16项定向Unit PASS；三页范围、第三页锚点保持、父楼页刷新失败保留回执已覆盖。首次测试编译因测试传了领域post而非行model失败，改为直接构造既有target；随后测试选中跨页重复边界楼层导致页号断言失败，改选第二页独有楼层后PASS。一条方法selector漏括号仅运行0项，未作为通过证据；最终按suite运行16项。
- 初次lint 6项（新方法长度/参数及行长）已按正常拆分修正，438文件0violation。iPhone原编辑器取消返回UI PASS；新增持久草稿UI首次因画廊入口位于设置页屏外失败，截图明确Y=1148.7，已补测试滚动到实际按钮，不改产品布局。后续测试与Live安装进行中。
- 最终17项不同逻辑Unit通过（U08新7项，R09/R10既有10项）；iPhone取消返回25.042s、持久化重开35.998s、iPad持久化重开38.479s UI通过。后续草稿状态按key隔离、flush代次/退出清理/附件失败清理调整后7项U08 Unit再验通过；一次catch排版lint已修正，最终438文件0violation。
- make build、make secret-scan、git diff --check通过；正常Debug的scripts/visual_review_build_install.sh U08成功，Live完整App覆盖iPhone/iPad，无卸载、清数据、签名变更。两端主程序和debug dylib与候选哈希一致（ignored Artifacts/VisualReview/U08/installed-binary-proof.json）。
- 当前Mac锁定，CUA无法自动解锁，已请求用户解锁。Live入口导航/截图尚未完成，不把Fixture流程冒充Live手工验收；尚不输出READY。用户真实发送、真机相册及签名团队未配置、既有iPad旋转分栏回首楼限制均未改动。本阶段无新自定义动画、手势、overlay或依赖，只有发送后系统确认提示；U08未暂存、提交或推送。


## 2026-10-06 U07 — USER_ACCEPTED，授权提交并进入U08

- 用户已确认最终外观并明确批准提交U07、开始U08。代码保持当前已安装验收候选，复用原31项不同逻辑Unit、7条设备/流程UI及各次直接视觉短回归；最终分享/回复候选19.590s UI、433文件lint/build/secret-scan/diff check已通过，不重复全套。
- 精确提交U07相关源码、测试、规格及视觉约束；排除用户原有未跟踪Prompt/skill、模拟器清理记录、Artifacts、凭证和Android submodule。真实Live仅验证过已记录范围，真机未验收。提交成功后才进入U08，不推送；全App已稳定视觉继续冻结。

## 2026-10-06 U07 分享/回复原版轮廓及分享文字

- 用户明确验收简洁空心点赞图标；TiebaLikeIcon保持原样。最新要求恢复分享右侧文字/数量，并按其原版截图替换分享、回复为简洁空心轮廓。仅修改两种信息流动作label并新增TiebaContentActionIcons：分享为圆角开口外框和斜向箭头，回复为圆润气泡、短弧和底部尾部；两者18pt、1.4pt圆头描边，与已验收点赞相同。
- 分享复用同一行现有计数label：源shareCount为正数显示其格式化数值，零/缺失显示“分享”；吧首页使用caption，动态使用原有12pt ScaledMetric，与各自点赞数字完全同源。使用已有API字段和计数格式化，不新增网络请求或伪增计数。保留48pt命中范围、系统ShareLink及现有回复动作；其他文字、位置、布局和已验收点赞图形不改。已更新PROJECT_RULES中的分享文字例外，全App视觉冻结仍生效。
- 最终make build、make lint（433文件0violation）、make secret-scan、git diff --check均exit0。现有U07动态标签/摘要/分享UI 1项19.590s PASS，未跑全套。证据在ignored `Artifacts/VisualReview/U07/share-label/`。无新动画、手势、overlay或依赖。
- scripts/visual_review_build_install.sh U07成功；完整正常Live覆盖iPhone/iPad，主程序/debug dylib与候选回读一致（share-label/installed-binary-proof.json），未卸载、清数据或改签名。iPhone真实高通吧已截图确认分享文字与右侧计数相同字号、分享/回复空心轮廓，停在吧首页供检查。本次Live可见的是“分享”回退分支；正数分支复用既有formatter和fixture shareCount，不冒称本次Live已观察到正数。iPad仅覆盖安装，真机未验证。
- 未暂存、提交或推送，不进入U08。点赞图形已获用户验收，本次分享/回复待用户视觉验收。READY_FOR_USER_VISUAL_REVIEW。

## 2026-10-06 U07 用户原版截图 — 简洁空心点赞轮廓

- 用户提供原版贴吧截图，明确拒绝实心拇指，要求空心且外形简洁。此前hand.thumbsup/hand.thumbsup.fill候选均未获视觉验收；以本次截图作为图形依据，不回退U07功能或用户数据。
- 新增纯绘制组件TiebaLikeIcon：圆润封闭外轮廓、直立拇指、一条袖口分界线，无填充和手指细纹。ForumThreadFeedRow、RecommendationFeedRow、ThreadReaderFloorViews复用这一18pt图形；仅替换点赞图形，保留现有位置、颜色、间距、点击范围和已按用户要求统一的caption计数字号。其余图标、正文、标题、作者、导航、列表和缓存均未调整；无新动画/手势/overlay/依赖。
- 最终make build、make lint（432文件0violation）、make secret-scan及git diff --check均exit0。共享组件定向UI `testFeedForumTagAndAbstractLinkUseIndependentNativeRoutes` 1项19.629s PASS；未跑全套。证据在ignored `Artifacts/VisualReview/U07/outline-like/`。
- scripts/visual_review_build_install.sh U07成功，完整正常Live覆盖iPhone和iPad，登录与数据保留。两端主程序/debug dylib均与候选一致（outline-like/installed-binary-proof.json）。iPhone真实吧首页及缓存帖11082436856第4/5楼已截图看到同一简洁空心图标，停在帖子页供用户检查；iPad本次仅覆盖安装，真机未验证。自绘轮廓参考用户截图，不冒称提取了官方原始素材。
- 本轮未暂存、提交或推送，不进入U08；保留全部U07与用户原有改动。等待用户视觉验收，READY_FOR_USER_VISUAL_REVIEW。下方实心及系统轮廓版本为已被用户否定的历史候选。

## 2026-10-06 U07 用户视觉反馈 — 点赞图标与尺寸

- 用户明确要求整个TiebaLite的已稳定视觉冻结：未获明确要求，不改变图标、字号、字重、间距、颜色或布局；已写入Docs/VisualParity/PROJECT_RULES.md。本轮仅处理用户指定的点赞符号、帖内外操作图标尺寸和最终再次明确授权的楼层点赞计数字号。
- 楼层原先在U07接线时从HStack换为默认Label，图标和计数缺少与信息流一致的尺寸约束。当前用原HStack排列和4pt间距；吧首页/动态/楼层点赞统一为`hand.thumbsup.fill`，操作图标共用18pt令牌，楼层点赞计数依最新要求使用与吧首页相同的caption。先前轮廓拇指候选被用户指出过细，已更换实心版本；不声称是官方原始素材。计数只提供一个无障碍元素，避免重复朗读。分享图标及无说明文字要求保留。
- 核对与HEAD的相关差异，未发现正文、标题、作者字号设置变化；本轮不修改这些文字、阅读字号偏好或布局。未改缓存、恢复、VirtualizedList、Pager、图片、导航或任何远端写操作。无新动画、手势、overlay和依赖。
- 验证：现有U07帖内/楼中楼/更多分享短UI 1项36.297s PASS（like-icons/phone-ui.xcresult）；随后只调整图形、计数字号和无障碍分组，功能结果复用，没有重复全套或新增镜像测试。最终filled-build、filled-lint（431文件0violation）、filled-secret-scan、git diff --check均exit0；filled-install完整Live覆盖安装成功，未卸载/清数据/改签名。
- iPhone/iPad的最终主程序及debug dylib均与候选一致，见ignored `Artifacts/VisualReview/U07/like-icons/filled-installed-binary-proof.json`。iPhone正常Live高通吧及缓存帖11082436856楼层2/3已截图确认相同实心拇指、较小计数，停在帖子页供用户检查；iPad本轮仅覆盖安装，不冒称重新执行大屏视觉/真机验收。证据在同目录及U07的filled-like-feed/reader截图。
- 保留所有U07及用户原有改动；未暂存、提交或推送，不进入U08。此前其他候选的安装哈希仅为历史证据。READY_FOR_USER_VISUAL_REVIEW。

## 2026-10-06 U07 用户视觉反馈 — 分享入口简化

- 用户要求分享入口只留图标，并进一步指出双向箭头不像分享。仅修改ForumThreadFeedRow和RecommendationFeedRow的分享label：使用`square.and.arrow.up`，移除分享文字/计数，保留原48pt点击区域、三列布局、系统ShareLink及无障碍名称。将后续按钮不随意添加可见描述文字的偏好写入Docs/VisualParity/PROJECT_RULES.md；无新增动画、手势、overlay或依赖。
- 图标单独显示后的现有短UI回归`U07ContentActionsSmokeTests/testFeedForumTagAndAbstractLinkUseIndependentNativeRoutes`通过，1项/19.600s；随后仅更换SF Symbol，沿用该功能结果，不重复全套或新增测试。最终make lint（431文件0violation）、make build、make secret-scan、git diff --check均exit0。证据在ignored `Artifacts/VisualReview/U07/share-icon/`。
- `scripts/visual_review_build_install.sh U07`成功；最终正常Live产物覆盖iPhone/iPad，主程序及debug dylib哈希与候选均一致（share-icon/installed-binary-proof.json），未卸载、清数据或改签名。iPhone真实高通吧页面已截图确认分享仅显示方框向上箭头，留在此处供用户检查；iPad本次只覆盖安装，沿用此前分享布局回归，未声称重新手工验收。真机未验证。
- 保留下方U07全部实现和既有验证记录；下方旧产物哈希为上一候选，不代表本次图标候选。未暂存、提交、推送，不进入U08。READY_FOR_USER_VISUAL_REVIEW。

## 2026-10-06 U07 — READY_FOR_USER_VISUAL_REVIEW

- 用户要求进入 U07；实际 HEAD 为8a1eedfd7aced187fbe35334037d55401fbf743a。读取本轮COMMON/实际U07及相关规则、当前源码；保留此前模拟器清理记录、用户未跟踪Prompt/skill和所有用户数据。不进入U08，不暂存/提交/推送。
- 根因：ThreadReader正文/三条子回复/完整楼中楼没有接收已有链接intent；动态摘要mapper丢弃link/mention，吧标签在外层帖卡Button内；旧RouteGrammar还拒绝thread→thread/forum。已接入统一安全网页/原生路由策略并仅补必要合法边；当前导航容器、去重和有界路径不变。已知uid提及走现有资料，未知uid保留文本。
- 公开链接只用已证实threadID或URLQueryItem编码吧名；生产分享使用系统ShareLink，更多菜单复制/分享/已有阅读操作，移除假点赞及过期评论未开放提示。普通帖卡主体保留原点击范围，吧标签独立；有链接的摘要保留TextKit选择，长按更多只挂作者入口。未改列表/富文本布局/缓存/预载/图片/Pager/Session。
- 验证进展：原摘要丢失红例actions-red FAIL；baseline的DeepLink4项PASS、R07 parser7项PASS。direct-unit-3为14项PASS（U07初版6、RichTextBuilder4、DeepLink4）；navigation-unit为21项PASS（U07最终7、导航Store7、R07 parser7）。同一已通过测试不跑全套。R07链接点击/起滑、长按选择复制UI两条PASS。
- UI排障如实记录：phone-ui的正文跳转因旧路径规则失败；动态分享已打开，失败是测试把系统Copy Cell查成Button，按实际AX修正。phone-actions-2两条U07已PASS，但普通帖卡改成仅作者行点击导致原滚动目标被跳过；恢复普通卡片原主体命中范围，无修改旧断言。phone-final三条PASS：四Tab/返回51.513s，正文/楼中楼/提及/吧入口/更多分享36.728s，动态吧标签/摘要链接/分享20.041s。早期两次Unit构建因测试支架多传参数失败，修正后通过。
- 最终相关验证：iPad-ui两条PASS（正文/楼中楼/提及/吧入口/更多分享38.237s，动态标签/摘要/分享21.034s），截图确认系统popover指向实际分享控件。navigation-compat使用test-without-building只跑R08楼中楼路由/Store投影和R11通知thread/subposts关系两项PASS。合计31个不同逻辑Unit、7条不同设备/流程UI通过；复用已通过R07结果，没有跑全部Unit/quality-fast/quality或无关压力矩阵。早期错误和中间失败保留上条及ignored日志，不计为通过。
- 最终门禁：make lint（431文件0violation）、make build、make secret-scan、git diff --check均PASS。只有工具链既有warning；无测试克隆（XCTestDevices count=0）。新增的是系统contextMenu/ShareLink及typed mention动作，没有自定义拖动、动画、透明遮罩或依赖；没有改变VirtualizedList、恢复、Pager、媒体、网络或缓存预算。
- 安装：scripts/visual_review_build_install.sh U07成功；同一完整正常Debug产物覆盖iPhone17Pro和13寸iPad，不uninstall/erase/清Keychain或数据。两端主程序SHA256均2091beb5edc46dd2b9fa97f72201eb393fbc0ee1b5eed4b5969e3b89766f6967，debug dylib均1d8e9596725660433e4033bc611793aeeb307da240d03534418f4bb2a4ea36b5；27个源码/测试候选哈希回读一致，证据在candidate-source-sha256/installed-binary-proof。
- 正常Live：iPhone原登录/关注和最新发布排序仍在，真实帖子顶部吧名成功进入原生高通吧；11082237926更多菜单包含复制链接/分享/重新加载，系统分享已实际弹出并正常关闭。iPad原最新回复排序仍在，缓存帖11071998867重进仍见153993794608（第31楼），系统分享锚定右下更多入口，关闭后仍在该楼层。iPhone最终留在11082237926更多菜单，iPad留在原缓存帖31楼供操作。没有发出真实帖子/关注/点赞等写操作。
- 范围/限制：正文、楼中楼、摘要、提及的具体链接跳转由完整生产App接Fixture进行确定性UI验证；本次正常Live未找到并遍历所有真实外链/短链组合，不冒称全部实网链接均验证。未知网页路径/查询仍交系统浏览器；保留现有5层业务路径及4层历史内容上限。只在Simulator验证，真机未验收。清理相关README/节点矩阵/导航/API证据中的过期说明，未重读或删除历史审计。
- 当前HEAD仍8a1eedf，暂存区为空；保留先前模拟器清理记录和用户原有未跟踪Prompt/skill。U07未暂存/提交/推送，不进入U08，等待用户验收。证据在ignored Artifacts/VisualReview/U07/。

## 2026-10-06 本机冗余测试模拟器清理

- 用户要求清理TiebaLite多余iPhone/iPad测试设备。核对当前无xcodebuild/xctest/XCTRunner运行，XCTestDevices下37台均为Shutdown的`Clone 2 of Tieba-Perf-Test`。逐个使用`xcrun simctl --set ~/Library/Developer/XCTestDevices delete <UDID>`，全部exit0；未使用全局erase/delete all。
- 删除后37个设备与目录均不存在，XCTestDevices占用由147,381,735,424 bytes（137.26 GiB）变为0。正常device set的15台清单完全一致：保留已登录日常iPhone17Pro/13寸iPad、Tieba-Perf-Test及U01-Forum-Sort-iPad一组隔离测试设备和其他项目设备。两台Live的App容器仍存在，未触碰账号、Keychain、历史、缓存、构建产物或runtime。
- 目录占用已清空，但df可用空间当时仍约264GB，未宣称物理磁盘已释放137GiB。系统存在Time Machine本地快照，APFS共享块/快照可能继续保留空间；没有越界删除系统快照。前后设备清单、占用和删除回执在ignored Artifacts/Maintenance/2026-10-06-simulator-cleanup/。
- 无App源码/配置变更、不运行构建测试、不提交推送；下次自动化继续使用保留的隔离设备，及时清理本次创建的测试克隆。

## 2026-10-04 v0.2.0beta3 — PUBLISHED_AND_VERIFIED

- 用户授权的提交、推送和IPA发布已完成：首页修复4e66ea6，发布源4534020；U06P1–P4一并快进推送，附注标签v0.2.0beta3解析为 `4534020d509ea0188dced53cf582fcc775dbb71e`，远端回读一致。
- Chrome正式发布页 `https://github.com/othbradar/tiebalite-ios/releases/tag/v0.2.0beta3`；Release ID402807353，draft=false/prerelease=true，2026-10-04 11:28:20（Asia/Shanghai）。已注明新功能、Bug修复、性能计数、安装方法及限制。
- IPA 6,789,405 bytes，SHA256 `cd775ccaea77a5ffaaa33e8c6f39c47efe942d1ceb0e9d35efabfa1c4220a0b1`；SHA256SUMS 112 bytes，均uploaded且远端digest与本机一致。发布正文归一换行后与准备稿相同。
- App0.2.0/Build4、真机arm64 Release未签名，需自行签名；未改Simulator现有安装或用户数据。已有定向结果复用，本次generate/lint/build/archive/Release隔离/包完整性/secret-scan/diff check通过。原warning及未验证范围见发布审计；没有运行全量测试或进入U07。
- 本条只补已核验远端回执，不变更已发布源码/标签或附件。下方RELEASE_PREPARED及未提交状态为历史记录；用户原有未跟踪Prompt/skill仍完整保留。

## 2026-10-04 v0.2.0beta3 — RELEASE_PREPARED

- 首页三项已验收修复精确16文件提交 `4e66ea614d1c46d32d6af43d88384b03495d9ff9`；15个候选哈希一致，沿用既有定向结果。当前准备把U06P1–P4与本次修复一起正常快进推送，不包含用户原有未跟踪文件或Android submodule。
- App 0.2.0/Build4，真机arm64 Release未签名IPA构建及完整性/Release隔离检查PASS，6,789,405 bytes，SHA256 `cd775ccaea77a5ffaaa33e8c6f39c47efe942d1ceb0e9d35efabfa1c4220a0b1`。make generate/lint/build/secret-scan/diff check均PASS，未重跑全套。
- 新功能、Bug修复、性能计数和限制见Docs/Releases/v0.2.0beta3.md；构建详情见Docs/Audits/RELEASE_0_2_0_BETA_3.md。P4指定旋转问题已修复，手工调宽/真机范围仍准确保留。无需改变现有Simulator安装、账号、签名或Keychain。
- GitHub CLI未登录，采用Chrome现有登录发布；当前只是本机产物准备完成，不提前宣称已上传。不进入U07。

## 2026-10-04 v0.2.0beta3 — USER_AUTHORIZED

- 用户已确认三项首页追加修复，现明确批准提交、推送并构建发布v0.2.0beta3，注明新功能和修复。当前15个候选文件SHA256全部与验收清单相同，沿用已通过的7项Unit/5条UI和最终位置人工验收，仅复核diff/secret scan/精确清单。
- 先独立提交首页修复，再将App Build 3升为4并构建真机arm64 Release未签名IPA，沿用既有分发方式，不修改签名、Bundle ID或Keychain。不进入U07，不纳入用户原有Prompt/skill、Artifacts或Android submodule。此条仅记录授权，不表示已经发布。

## 2026-10-04 用户追加：首页/吧首页三项修复 — USER_ACCEPTED（未提交）

- 按用户批准先精确六文件提交U06P4：`b976ffad19eb3593d84565869095987821432885`，`fix: preserve iPad reading position across layout changes`；五个验收候选哈希一致，沿用原定向结果，仅复核diff/secret scan/清单。未推送。本轮以此HEAD修三个用户指定问题，不执行U07。
- 底部根因与修改：外层VStack移除根选择栏时同时改变TabView/NavigationStack高度；新组件三次均测得91pt突变，普通最终row rect检查无法覆盖。正常Live基线转场录屏也保留在entry-live-baseline.mov。将根栏移到各非阅读目的页内部safeAreaInset，紧凑TabView保持完整底部视口；保留canonical route、系统转场、四根状态及iPad横屏三列。修后同一三次容器尺寸不变，阅读表格采样底边差<1pt。未改VirtualizedList、U03恢复、Pager、图片、缓存、协议或Session。
- 最近逛吧：当前只有打开入口。新增首页编辑态进入recent行投影，长按任意chip显示全部红底白减号，再长按隐藏；编辑时正文不导航，减号复用BrowsingHistoryStore.delete(.forum(id))，不取消关注、不清其他历史/阅读缓存。新增独立无障碍删除ID和管理动作；仅编辑期间有局部badge。用户指出第一版减号压住吧名；曾试加编辑态顶部空间，随后用户明确要求仅右移，已撤销该留白，最终只给badge向右10pt的视觉偏移，胶囊/文字/行尺寸及间距完全不变；未新增动画、依赖或列表框架。
- 刷新：原setRetainedStatus(.refreshing)在首行插入说明，改为仅失败时插入重试行；UI不再绘制“正在重新加载”，保留UIRefreshControl、旧内容及P1静止视口提交/取消。用户已实际确认底边遮挡和吧首页刷新说明均修好，这两处保持验收代码。
- 红例及观测：baseline-unit刷新行相等断言失败；初版转场Unit使用未关联scene的UIWindow不能挂载导航，不能当产品失败。改用真实UIWindowScene后，单看表格几何三轮通过但未覆盖容器缩放，补容器不变断言后entry-container-red三轮均91pt失败。entry-presentation-baseline中的长按入口在原代码失败（该次遗漏only-test-configuration导致同一条在三配置重复运行，未跑整套）。
- 定向结果：direct-unit **7/7 PASS**（新增3项、R05策略3项、P1拖动刷新1项）；phone-ui中的长按删除 **33.410s PASS**、三次进吧/看帖/返回及四Tab **69.660s PASS**。旧U02短测首屏固定“刷新1”失败，当时已显示“刷新2”；现有首页预载可能先完成，改成从显示源代次出发严格检查重进+1、下拉+1，保留刷新内容/可见/无提示断言，refresh-ui **21.012s PASS**。ipad-ui **2/2 PASS**：横竖屏路由/根切换31.051s、长按显隐删除34.909s。未重复缓存/恢复全套、全量Unit或quality；顶部留白试案的短回归badge-spacing-ui为33.295s PASS；用户随后要求仅右移，已撤销留白。最终仅badge位置变化，功能沿用已通过的长按/删除结果，最终右移版已覆盖正常Live两端，用户明确“现在位置可以了”。
- 此前门禁make lint（426文件0violation）/make build/secret scan/diff check通过，完整正常Live iPhone/iPad已覆盖且两端主程序/dylib与产物哈希一致。用户正在该候选检查；真实数据未删除，所有删除自动化仅在隔离Fixture。CUA观察与用户同时操作导致界面变化，不将其当应用失败。真机未验证。本轮追加修复不暂存/提交/推送。


- 最终交付：已撤销顶部留白，最终仅badge `.offset(x: 10)`；非编辑和编辑状态的胶囊/整行排版均保持原样。make lint/build/secret scan/diff check在最终代码PASS，最终完整Live两端产物哈希再次一致。用户已分别确认底边遮挡、刷新说明栏和最后的减号位置；无需继续改变已验收实现。前述7项Unit/5条UI验证功能与导航，最后纯位置调整由正常Live用户验收，未伪称为重新跑了全部自动化。iPhone/iPad均保留数据停在首页供使用，没有代理删除真实最近访问条目。真机未运行自动化；本批追加修复未暂存、未提交、未推送，无U07。

## 2026-10-04 U06P4 — USER_ACCEPTED，授权提交

- 用户批准提交U06P4并另行提出三个首页交互修复。五个候选源码/测试/契约/ADR哈希一致，沿用已验收定向结果，仅复核diff、secret scan及精确六文件清单。提交后再开始新修复，不混入本提交。
- U06P四批已获用户批准；P3两处条件性热点仍NOT_MEASURED，P4手工调宽及真机仍未验证，保留真实范围及历史失败证据。无push/tag/release，不进入U07。下方READY中的未提交状态为此前交付记录。

## 2026-10-04 U06P4 — READY_FOR_USER_VISUAL_REVIEW

- 用户授权“提交并进入U06P4”后，17个U06P3候选文件SHA256一致，沿用已验收定向结果；复核diff/secret scan/精确清单后仅18文件提交 `0d37b45e6a534a1ea34761441d1ad8d2f1e6812f`，`perf: avoid repeated full-list preparation`。未推送/tag/发版。以该实际HEAD开始U06P4，先读两级COMMON及实际P4提示词，未展开U07或全部历史审计。
- 原失败复现：`baseline-ipad.xcresult` 在旋转后同一目标450001不可见。正常Live安装已验收P3候选后，从真实缓存帖11072893916滚至中部（首个可见回复153994304967），竖转横分栏后回首楼153993052312，截图 `20261004-092747-baseline-live-ipad-returned-top.png`。只记录业务ID，未读取凭证或打印正文/URL。
- 根因：Registry保持同一阅读目的地的Store/四页数据；分栏新Coordinator收到450001和63行，但UIKit先将adjusted top inset改为64、offset改为-64，在layoutSubviews外触发didScroll。旧逻辑将其当作程序导航，取消尚未positioned的一次定位。零尺寸临时投影没有写进度，未发现数据回第一页或重做缓存的必要。脱敏实例/行/尺寸/写入来源在 `reading-trace.log` 等本轮ignored证据。
- 最小修复：VirtualizedList的didScroll在事务active且尚未positioned时保留目标；真实拖动/主动回顶部仍走原明确取消入口，scope/目标变化及拆除保持原失效；定位后仍以实际Cell身份/配置/可见完成，释放历史目标并交给原当前视口保持。无新等待机制、导航/Store/缓存修改，不跨尺寸复用旧几何。生产差异仅一条guard及说明；临时诊断已全部移除。
- Unit：新inset入口红例 `inset-red.xcresult` FAIL保留；加入guard后最早inset-green/geometry-unit仍因测试挂窗未触发布局而超时，补足真实layout入口后 `geometry-unit-2.xcresult` 两项PASS。最终 `direct-unit.xcresult` **8/8逻辑项PASS、0fail/skip**，包括原430001异高恢复/退出/新进度、拖动/账号/目标/拆除取消（4参数）、U02顶部（3参数）与深处恢复、通知精确楼层及一次消费、新导航inset和同表窄宽重排。Cell创建少于总行数，初始定位次数1，后续尺寸变化不重新执行历史定位。
- UI：`ipad-rotation-current-query.xcresult` **1/1 PASS，104.163s**，原楼层460001在竖→横分栏→竖后仍可见且初始恢复idle；`ipad-direct.xcresult` 中独立窄宽/新楼层重进用例 **PASS，124.916s**（同bundle另一旋转用例早期重进观测超时不能算通过）；`phone-ui.xcresult` **1/1 PASS**，保留430001可见、图片往返、不回拉和新楼层重进。窄宽已通过流程不重复跑；无全文分页/媒体/压力矩阵。
- 中间UI观测失败如实保留：diagnostic-ipad首次为Simulator活动App AX -25218环境错误；diagnostic-ipad-2定位到真实取消入口。inset-ipad/geometry-ipad/target-observation-ipad在旧hittable谓词超时，但最新查询及UITableView实际Cell已显示同一460001（610.5,260.5,765.5,142），并保持四页；改为每轮在当前表内按相同业务ID新建查询，仍要求exists/hittable/视口相交/idle及5秒限时，没有放宽楼层。ipad-final的旋转断言已过，随后系统“App animations complete notification not received”等待60秒导致合并流程180秒总限时失败，因此拆开旋转和窄宽两条直接场景，未关动画/增固定等待。首次lint两项测试排版错误修正后通过。
- 门禁：最终 `make lint` 425文件0violation，`make build`、`make secret-scan`、`git diff --check`均PASS。未全量Unit/quality-fast/quality；未修改Pager/MediaViewer/图片/Session/Keychain/Android submodule，无新手势、动画、overlay或依赖。只新增直接组件测试、扩展原UI与相关契约/ADR/本记录。
- 安装：`scripts/visual_review_build_install.sh U06P4` PASS，完整正常Debug App覆盖正常iPhone；同一产物覆盖正常iPad，保留账号/历史/排序/缓存/签名，无uninstall/erase/Keychain或缓存清理。两端主程序SHA256 `31029f4545e1572f6b31d0839fd4cd309952ded9a06c23322e784506393e3a10`、debug dylib `d60ee52fc8d395cbc005b20791e9acd895fdce53be70218bbd804c65e8257e4c` 与构建一致，证明见installed-binary-proof.json。iPad仅启用既有Debug工作计数参数，仍为完整Live环境。
- 解锁后正常Live验证：原失败帖11072893916的153994304967在竖→横分栏→竖后仍可见；该帖实际仅29楼，不冒充多页。另从正常吧首页选择多页帖11071998867，滚动加载到46行后，153993780180在竖→横分栏→竖均可见，46行没有退回首屏；继续滚到新位置后返回重进，恢复153993794608（第31楼），未回拉旧目标。表格计数从加载前31行到46行，旋转各新投影prepare/apply均1；旧表cells12/reuse38，新投影最多cells9，未全量创建楼层。截图live-ipad-multipage-rotation/live-ipad-new-position保留于本轮Artifacts。手工拖系统窗口边缘未产生尺寸变化，不能算Live窄宽通过；窄宽/新位置保存以独立UI回归PASS为证，由用户继续实际调宽验收。
- iPhone正常Live：缓存帖11071397108返回重进仍见153991153447/153991274030；正常terminate→launch后经历史进入同帖，以上同一业务楼层仍在视口，截图live-phone-process-reopen。账号/排序/历史/缓存均保留，未清理任何数据。操作中有两次AX索引过期及短帖到底后Scroll Down不可用，刷新实际界面后继续，不记为App失败或成功操作。
- 交付：候选源码/测试/规格/ADR共5个文件SHA256与已安装检查版本一致，仅补本记录；最终secret scan和diff check再次PASS，暂存区为空，HEAD仍为0d37b45。完整正常Live iPad留在11071998867第31楼，iPhone留在11071397108恢复位置。真机未验证，无新动画/手势/overlay/依赖。U06P4未暂存/提交/推送，不进入U07，等待用户验收。

## 2026-10-04 U06P3 — USER_ACCEPTED，授权提交并进入 U06P4

- 用户已验收并授权“提交并进入U06P4”。本次核对已安装候选17个源码/测试/规格/ADR文件SHA256全部一致，沿用下方定向Unit、短UI与轻量门禁结果；只复核diff、secret scan及精确暂存清单。
- 仅提交U06P3的18个相关文件，提交信息 `perf: avoid repeated full-list preparation`；排除用户原有Prompt/skill、Artifacts、凭证、IDE文件与Android submodule。不推送、不tag、不发版，提交成功后才实施U06P4。
- 下方READY的未提交/等待验收为此前交付状态。两处条件性热点仍NOT_MEASURED，iPad旋转分栏回首楼仍为已知失败，真机未验证，不将这些项目标为通过。

## 2026-10-03 U06P3 — READY_FOR_USER_VISUAL_REVIEW

- 用户授权“提交并进入U06P3”后，先核对U06P2验收候选10个文件哈希一致，复核diff/secret scan/精确暂存，沿用已有结果，精确11文件提交 `b16c6f06aa205a957c842ae1025771d9ae29de73`：`perf: remove disk maintenance from cache hit paths`。未推送/tag/发版。U06P3只执行当前实际提示词和两级COMMON，以该HEAD为基线；不展开P4/U07或历史审计。
- 原失败证据 `Artifacts/VisualReview/U06P3/baseline.xcresult` 3项FAIL：5页共1000项的吧缓存合并访问2994项；30次重复预取先构造全帖ID集合30次；30次anchor更新让全表prepare从1到31，实际apply保持1。断言保留，不用耗时阈值。优化构建基线以既有1000楼/每页200楼Fixture进行4次系统滚动，rows201、prepare3→7、apply1、cells9/reuse21；滚轮/原生drag未产生有效滚动的尝试不计入结果。
- 修改A：ForumCachedReading以一个Set和数组单次按页合并，first-wins及原顺序、首屏论坛元数据、最大页码、末页hasMore/cursor保持；只映射首次出现的主题。Store通过明确 `@concurrent assembledSnapshot()` 在通用执行器组装，回来后重新校验generation/账号/取消，再发布。1/3/5页访问数为200/600/1000，逐项结果与原appending相同；正常单页追加和缓存格式/权限/锚点不变。
- 修改B：帖子只有接近现有尾部加载边界才投机预取；先检查加载状态、账号和thread/page/cursor/generation，再由Scope懒构造请求。loadedPostIDs随首屏/恢复/刷新重建，后页合入新ID，不因每次回调扫描全帖。30次重复回调只准备1份请求、源调用1次；失败后前台仍成功加载第二页400楼。Scope失败/取消按本代次清理去重记录，后续边界事件可重试，完成不自动递归；U04调度器、槽位/预算和订阅者取消规则不变。
- 修改C：帖子/吧Store在真实presentation变化时递增revision，帖子configured rows按revision/阅读字号缓存。VirtualizedList可选接入Store身份/revision/设置及字号/主题/方向/locale环境版本，默认调用方仍走原比较。分别记录applying/completed/pending，只有真实完成才记completed；连续更新只应用最新有效数据。相同版本更新anchor/回调不再准备IDs、字典或retained比较；只更新实际可见Cell的闭包，复用时取最新parent。实际内容/footer/字号仍生效，无业务ID、UITableView/Diffable、首次恢复/视口补偿、Pager/导航改写。P1同步刷新提交使旧版本失效。快路径及完成/配置方法为薄扩展，未全表reload或预创建Cell。
- 定向结果：原3条红例 `fast-path.xcresult` 全通过。`direct-unit-final.xcresult` 8/8逻辑用例PASS、0skip（多页参数化1/3/5页）；覆盖顺序/元数据、重复预取与失败后前台加载、配置投影/字号、连续anchor不prepare、两次排队更新最新内容/footer、可见UIButton实际调用最新callback、14→26实际字体更新、替换token不留旧数据、既有千行虚拟化/复用、P1拖动刷新及排序/账号/取消、U03异高初始恢复。随后完成方法原样提取及限定可见回调刷新仅适用于接入者后，`completion-unit.xcresult` 3/3 PASS；将原U03异高用例接入可选版本后 `versioned-restoration.xcresult` 1/1 PASS，保持目标可见/事务退出/新位置进度/不重启断言。
- 完整App UI `phone-ui.xcresult` 2/2 PASS：复用五页帖子滚动→分页→看图→返回原位置（172.979s），以及吧首页深处重进→排序→下拉刷新→顶部重进（49.327s）。这是两条既有直接流程，没有跑历史全套或千楼压力矩阵。首次 `direct-unit.xcresult` 的4个旧方法selector未带括号，仅匹配了新增4条；不将其冒充8条，随后精确selector执行8条。lint前两次因对齐/参数数目/方法与类型长度/空行失败，提取原方法与轻量请求身份后修正，未降低规则。
- 相同Debug `-O`手工对照：候选仍用既有千行Fixture首批200楼、4次系统滚动，rows201、prepare1→1、apply1、cells9/reuse17；截图 `20261003-231329-optimized-fixture-after.png`，计数在baseline-counts/candidate-counts.json。未把该小样本推断为FPS或耗时百分比提升。两处条件性热点（URLSession逐字节接收、Viewer倍率导致根/Pager更新）未获得可靠采样：Time Profiler附着报Cannot find process，后查隔离设备已被测试生命周期关停；本轮没有可比较的接收/连续缩放样本，因此均记NOT_MEASURED/未证实，不修改网络或缩放实现。
- 门禁：`make lint`、`make build`、`make secret-scan`、`git diff --check`全PASS；未运行全量Unit、quality-fast、quality、iPad旋转矩阵。代码/规格/ADR/测试17个候选文件哈希在安装后复核未变。正常安装前尝试向已关停Fixture设备install/launch收到405，启动该隔离设备后成功；无卸载/erase或数据清理。
- 正常Live交付：`scripts/visual_review_build_install.sh U06P3` PASS，完整正常Debug App覆盖 iPhone `70D93841-1FEB-445A-8FAD-B1C29B981D5D`，保留原账号/历史/排序/缓存/签名/Keychain。主程序SHA256 `7a5a04c02f132165d40cef183f6ce8464dd6eb73e5e05e3e7bd8bd310c48894a`、debug dylib `34a82e9d9dd98d9ee8cf0eed18ef31ea93296d73f9f363a7670463c8b850e56f` 与本轮构建相同。经正常入口打开真实高通吧并滚动，再从历史进入原缓存帖 `11071397108`，第2/6张旧图正常显示，关闭回同一楼层 `153990906755`；“已登录”仍可见，最终停在真实帖子页供操作。Live图片服务累计disk48/network1/merged0，仅作兼容观察，不声称全程零请求或本批改善图片命中率。
- 范围与限制：修改Forum领域组装、相关Store/View投影与prefetch接线、VirtualizedList可选版本/计数及直接测试/记录；无新动画、手势、overlay或依赖，无缓存重置/持久格式/预算/图片系统/网络协议变更。iPad旋转分栏回首楼仍是已知失败，真机及两处条件性热点未验证。U06P3未暂存/提交/推送，不进入P4/U07，等待人工验收。

## 2026-10-03 U06P2 — USER_ACCEPTED，授权提交并进入 U06P3

- 用户已验收并授权“提交并进入U06P3”。本次核对已安装候选的10个源码/测试/ADR文件SHA256全部一致，沿用下方9项定向Unit及1项短UI和轻量门禁结果；只复核diff、secret scan及精确暂存清单。
- 仅提交U06P2的11个相关文件，提交信息 `perf: remove disk maintenance from cache hit paths`。排除用户原有Prompt/skill、Artifacts、凭证、IDE文件及Android submodule；不推送、不tag、不发版。提交成功后才实施U06P3。
- 下方READY的未提交/等待验收为此前交付状态。本次仍保留可选图片落盘队列溢出限制、真机未验证和U03 iPad旋转分栏回首楼已知缺陷，不将其标为通过。

## 2026-10-03 U06P2 — READY_FOR_USER_VISUAL_REVIEW

- 用户授权“提交并进入U06P2”后，先精确提交 U06P1：`85e0b0c503f4c91e10b1c3f09d6d825e20a4d60b`，`fix: defer forum refresh while scrolling`，11个相关文件；提交前10个候选文件哈希一致，复核 diff/secret scan/精确暂存。未 push/tag/release。U06P2 以此实际 HEAD 为基线，只读两级 COMMON、当前 P2、相关缓存源码/规格与最新记录，未展开后续批次或全量历史审计。
- 确认仍存在的两条失败：30次内存命中逐次写索引（30次），纯 miss 也写索引；4个真实下载被 gate 挂住时，另一张磁盘缓存图排入下载队列，不能独立返回。原红例 `baseline.xcresult` 两项 FAIL 保留。CachedReadingRepository 本来已是小 manifest checkpoint，不重写；吧首页 saveReading 的逐页旧正文读取仍存在，改为元数据确认引用。
- 页面最小修改：ContentPageCache 命中仅合并有界 LRU 日期，单 writer 批量维护，显式 flush 提供完成屏障；纯 miss 不写索引。正文/索引/manifest 仍 await 持久化成功，clear/账号/query/epoch 检查及原格式、容量、有效期不变。吧首页真实加载页面时先持久化页，再保存引用它的 manifest；保存锚点不读旧正文，别名未变不重复写。失败写不宣称已落盘。1秒计时仅用于 COMMON 明确允许的 LRU 合并维护，不参与 UI/布局/取消时序。
- 图片最小修改：同资源 flight 覆盖查盘到返回，磁盘查找最多2项，真正 miss 才进入原4个下载槽；共享优先级保持前台接管与订阅取消隔离。已验证 bytes 可先返回，单 writer 最多保留2项/48 MiB active + queued 编码资源，待写同键复用；超过上限跳过本次可选落盘并计数，不阻塞显示或扩大队列。旧 epoch 写不能回填，显式 flushPersistence 用于落盘/离线重启证明。原图/缩略图/裁切 key、完整性、传输规则、预算及 U05 独占导出文件均保留。
- 定向计数：30次页面命中从30次索引写合并为1次，20次纯 miss 写0次；挂住索引 writer 时31次内存命中仍能完成。吧首页1页/3页只改 anchor 均为旧正文读取0、manifest写1（读取小 manifest及两个别名共3次）；帖子3页 checkpoint仍为manifest读1/写1。缓存图返回时4个下载仍被挂住；两订阅者取消一个后另一成功，待写同键再次请求源下载仍1次。队列满时 pending=2、跳过1；clear后旧提交0，导出GIF逐字节保留；新 epoch落盘1，重建 Loader断网命中1、源请求0。
- 检查：`direct-unit-2.xcresult` 8/8 PASS；`final-disk-unit.xcresult` 2/2 PASS（复跑1项冷miss补充 + 1项原预算/损坏回归），合计9个不同逻辑用例，0 skip。含现有尺寸/裁切隔离及ImageWorkPool前台优先/实际退出才释放槽。`phone-ui.xcresult` 唯一完整App图片往返短UI 1/1 PASS（56.053s）：加载原图保持zoom、Mock保存、切页往返、关闭回阅读页。`make lint` 422文件0 violation、`make build`、`make secret-scan`、`git diff --check` 均PASS；没有全量Unit、quality-fast、quality或长矩阵。
- 中间失败保留：`fast-path-unit.xcresult` timer闭包直接访问actor隔离属性导致编译失败，改为actor入口；`direct-unit.xcresult` 测试宏中组合throwing Data读取导致编译失败，拆成局部值；首次lint参数对齐修正。修正后原2个红例 `fast-path-unit-2.xcresult` 通过。没有降低断言、增加布局延时或清用户缓存。
- 完整Live交付：`scripts/visual_review_build_install.sh U06P2` PASS；正常Debug App覆盖 iPhone `70D93841-1FEB-445A-8FAD-B1C29B981D5D`，保留登录、排序、历史、缓存，未 uninstall/erase/清Keychain。安装主程序SHA256 `24ee061359ba8c14d1497ad39fcf9da0fbf04df7be0a026f049ccbf47fa4d598`、debug dylib `5636fcf2ed141436d679067e1cd17713e46ee9186f5fb174fd9d46e2c6ed6c7d` 与本轮产物一致。证据仅在 ignored `Artifacts/VisualReview/U06P2/`。
- Live实际观察：打开真实高通吧（原排序保留），从已有历史打开缓存帖 `11071397108`、同一楼层 `153990906755` 的第2/6张图，关闭→返回→重进仍在该楼层。首次原图读取 disk36→37、network保持4、merged1。结束进程并重新launch，经原历史进入同帖同图；显示图disk32/network0/merged0，点加载原图后disk33/network0/merged0，图片显示1080×2400。以上是图片服务计数，未宣称所有业务请求为0；实际断网证明来自临时目录Mock测试，没有切断Live网络。当前候选留在该真实原图，截图 `20261003-223436-live-restart-original-ready.png`。
- 修改范围：5个Core缓存/Repository文件、3个直接测试、ADR-0008/0030和本记录；无UI/手势/动画/overlay/依赖变更，未改VirtualizedList、U03恢复、U02刷新策略、U04预载策略、Pager、Viewer、iPad导航或Android submodule。图片写队列饱和时本次资源可能未持久化；不承诺FPS或全设备耗时提升。真机未验证，U03 iPad旋转分栏回首楼仍未修复。U06P2未暂存/提交/推送，不进入P3/U07，等待人工验收。

## 2026-10-03 U06P1 — USER_ACCEPTED，授权提交并进入 U06P2

- 用户已验收并明确授权提交 U06P1 后进入 U06P2。当前10个源码/规格/测试文件与已安装、通过检查的候选 SHA256 全部一致；沿用下方8项定向 Unit、iPhone/iPad 短 UI 和轻量门禁结果，仅复核 diff、secret scan、精确暂存清单。
- 仅提交 U06P1 的11个代码、测试和必要记录文件，提交信息 `fix: defer forum refresh while scrolling`。排除用户原有 Prompt/skill、Artifacts、凭证及 Android submodule；不推送、不打 tag、不发版。提交成功后才读取并实施 U06P2，两个批次不混入同一提交。
- 下方 READY 记录的“未提交/等待验收”属于此前交付状态；本条更新授权。真机及 Live 延迟网络竞态未验证，U03 iPad 旋转进入分栏回首楼仍未修复，不将该缺陷标为通过。

## 2026-10-03 U06P1 — READY_FOR_USER_VISUAL_REVIEW

- 实际基线 HEAD `1dac48bfb72f26017f088788fbca9fee96a5100f`。只执行 `U06P/U06P1_REFRESH_DURING_SCROLL.md`，先读两级 COMMON；未展开后续提示词或旧审计。用户原有未跟踪 Prompt/skill 保留，无暂存、提交、推送、发版，未进入 U06P2/U07。
- 当前源码的确定性失败：缓存两页且锚点为 nil 时，调用真实列表 Coordinator 的拖动开始入口，再通过 continuation 释放自动首屏响应，Store 提前换成首屏。`baseline.xcresult` 原用例 1/1 FAIL；这是 Fixture/组件证据，不是 Live 网络复现。
- 最小修复：ForumHomeStore 暂存带 route/query/context/generation/intent 的首屏，不再由历史 scrollAnchor 授权替换。仅吧首页接入可选 `VirtualListRefreshCommit`：现有 delegate/布局/触摸结束边界发合并通知，实际 diffable 提交前在 MainActor 重读 tracking/dragging/decelerating、有效窗口/尺寸、snapshot/恢复状态及 `offsetY + adjustedTopInset`。自动更新只在静止几何顶部提交，显式刷新可在其他静止有效位置完成，spinning 不作为阻塞条件；Store 变更和新行 snapshot 间没有 await，旧后页不拼接。新响应/排序/账号/取消使旧回调失效，首次无缓存加载仍直接显示并沿用原持久化完成语义。
- 修改边界：ForumHomeStore/View；VirtualizedList 可选接线及新增 Refresh 扩展；原 snapshot 方法原样提取到 Snapshot 扩展以满足 lint 长度限制，方法体仅增加完成后的通知入口。`VirtualizedList+Reading`、InitialReadingRestoration、缓存/Repository/预载、Pager、MediaViewer、图片系统、Session、iPad 导航、Android submodule 均未改。无新手势、动画、overlay、依赖、计时等待或强制滚顶。
- 定向验证：`direct-unit-2.xcresult` 8 个逻辑用例全通过、0 skip（含新4项、U02 自动/深处回顶2项、原刷新控件/零尺寸保护2项）。受控源请求共3次＝首次首屏＋第二页＋重进自动检查；拖动/惯性/深处仍保留2页，回顶才替换1页，旧后页 ID 消失。覆盖排队后再拖动、顶部静止自动提交、手动成功/失败、刷新控件 inset、排序/账号/取消及一次性消费。复用并增强同一条 U02 短 UI：iPhone `phone-ui-2.xcresult` 1/1 PASS（45.389s），iPad `ipad-ui.xcresult` 1/1 PASS；深处重进、切排序、实际下拉刷新、顶部重进自动更新与无横条均通过。
- 中间失败如实保留：`fix-unit.xcresult` 测试误用不存在的 selectSort 方法导致编译失败，改为现有 changeQuery；`direct-unit.xcresult` 6/8 PASS，修正首次无缓存保存应保持原 await 完成语义，以及测试将 UIRefreshControl 增加 inset 后的位置误认成顶部。首次 lint 的两处参数对齐和类型长度已修正。`phone-ui.xcresult` 在新增刷新标记断言失败：原 swipeDown 合成行程200pt，未出现刷新标记；改为复用现有 U02 用例的完整下拉手势后通过，没有改业务阈值、降低断言或操作速度。
- 轻量门禁：`make lint` 421 文件0 violation；`make build` PASS；`make secret-scan` PASS；`git diff --check` PASS。未执行全量 Unit、quality-fast、quality 或无关长矩阵。证据仅在 ignored `Artifacts/VisualReview/U06P1/`；`candidate-files.json` 的10个源码/规格/测试哈希在安装后复核未变。
- 正常 Live 交付：`scripts/visual_review_build_install.sh U06P1` PASS，完整正常 Debug App 覆盖 iPhone `70D93841-1FEB-445A-8FAD-B1C29B981D5D`，codesign/Simulator entitlements 验证通过，无 uninstall/erase/清账号或 Keychain。安装主程序 SHA256 `803bd3c467fa2d23975e196b4522284e17081b172c0000130447b76702f2ed1d`、debug dylib `304f04772e653082710ef85e9acad8ee67fc99379e44909da865248c1032431e` 与本轮候选一致，见 `installed-binary-proof.json`。原账户头像、关注吧与历史入口仍显示；经生产入口打开真实高通吧，保留“最新发布”排序，留在吧首页供用户操作。截图 `20261003-215100-forum-home-review.png`。
- 剩余限制：Live 仅确认正常安装、登录态保留和真实入口可读；没有人为延迟真实网络来复现同一竞态，没有测量或宣称 FPS。U03 iPad 旋转进入分栏回首楼仍是已知失败，未在本批修复或标为通过；真机未验证。本批等待用户视觉验收，不进入下一批。

## 2026-10-03 v0.2.0beta2 — PUBLISHED_AND_VERIFIED

- 用户指定使用 Chrome，并澄清 Safari 未登录 GitHub；此前基于 Safari 页面控件作出的登录判断不作为认证证据。按用户要求使用本机 Chrome 的现有 GitHub 会话，经原生 UI 完成发布，无需 CLI 登录或读取浏览器凭证。
- 公开 Release：`https://github.com/othbradar/tiebalite-ios/releases/tag/v0.2.0beta2`，ID `402400487`，`draft=false`、`prerelease=true`，发布时间2026-10-03 16:02:38（Asia/Shanghai）。标签仍指向已核验发布源码 `5c9b3a8dda71d0deef8adfa685a7900d623b5b83`。
- 附件均 `uploaded`：IPA 6,734,035 bytes，SHA256SUMS 112 bytes，公开 REST 返回的两项大小及 SHA-256 与本机完全相同。IPA SHA256 `02bf64d510a3f97fb72527ad7d2d762af501db32f1f29a6b868affb80513855a`。发布正文与准备稿经 CRLF/LF 归一后相同，保留未签名安装说明、实测计数和已知缺陷。
- Chrome 已显示正式版本页面，机器回执在 ignored `Artifacts/Releases/v0.2.0beta2/publication-receipt.json`。本次只完成发布和回执，不再改 App、重打包或重跑测试，不进入 U07。此前“等待登录/尚未发布”是历史状态，由本节更新。

## 2026-10-03 v0.2.0beta2 — TAG_PUSHED，Release 等待 GitHub CLI 登录

- 发布源提交 `5c9b3a8dda71d0deef8adfa685a7900d623b5b83` 与附注标签 `v0.2.0beta2` 已原子推送到 `origin/main`；远端分支和标签解析均回读同一提交。U06 所有生产/测试源码哈希与已验收提交一致。
- 真机 IPA 与 SHA256SUMS 已构建核验，位置 `Artifacts/Releases/v0.2.0beta2/`；构建后 `make build`、secret scan、diff check 也通过。未签名安装方式和已知限制已写入发布说明。
- **GitHub Release 尚未发布，附件尚未上传**：公开 tag Release API 返回404。`gh` 未登录（查询 exit 4），Safari 虽已登录且能打开发布表单，但网页标题/正文输入无实际写入；内置浏览器及 Chrome 连接超时。未读取或提取浏览器凭证，未绕过认证。
- 已请求用户在本机执行 `gh auth login --hostname github.com --web`；无需发送密码或 token。后续直接用 `Artifacts/Releases/v0.2.0beta2/release-notes.md` 和两个已核验附件发布现有标签的 pre-release，并复核远端附件大小/摘要。当前状态不能称为 PUBLISHED。

## 2026-10-03 v0.2.0beta2 — RELEASE_PREPARED

- U06 已验收代码精确37文件提交 `a509d44dfe68fdcca934808db3b0e10803f8f9a4` 并推送 `origin/main`，远端回读一致；U03/U04/U05 已提交历史一并正常快进推送。用户原有文件、Android submodule、Artifacts、凭证保持排除。
- App 版本0.2.0 / Build 3，真机 arm64 Release 未签名 archive 与 IPA 检查通过；6,734,035 bytes，SHA256 `02bf64d510a3f97fb72527ad7d2d762af501db32f1f29a6b868affb80513855a`。不是 Simulator 包，需用户自行签名，未改变现有 Simulator 安装、账号、签名、Bundle ID 或 Keychain。
- 复用验收过的定向 Unit/UI；本次 generate、lint、secret scan、diff check、设备 archive、实际 Release 隔离与包完整性均通过，未重跑完整 gate。说明见 Docs/Releases/v0.2.0beta2.md，精确构建证据见 Docs/Audits/RELEASE_0_2_0_BETA_2.md。GitHub CLI 未登录，已有 Safari 登录可用于发布；远端发布状态待回执，不提前宣称已完成。
- U03 iPad旋转进入分栏回首楼仍是已知失败，真机相册未验收、Development Team 未配置。只发布当前已验收范围，不进入 U07。

## 2026-10-03 U06 — USER_ACCEPTED，授权提交并发布 v0.2.0beta2

- 用户已确认当前 Viewer 修订与张数居中满意，明确授权提交、推送 GitHub，并构建发布 `v0.2.0beta2` IPA。本次授权覆盖下方历史记录的“不提交/不推送”；不进入 U07。
- 当前验收代码未再修改，沿用 U06 缓存及 Viewer 的既有定向 Unit/UI、完整正常 Simulator 安装和人工验收结果。提交前重查 Git diff、secret scan 和精确文件清单，排除用户原有 Prompt/skill、Artifacts、凭证及 Android submodule。
- 发布沿用上一版真机 arm64 Release 未签名 IPA 方式，标签采用用户指定的 `v0.2.0beta2`；App 0.2.0 / Build 3。签名团队仍未配置，不修改 Simulator 签名、Bundle ID 或 Keychain。实际归档与 GitHub 回执在完成后补记；本条不表示产物已发布。

## 2026-10-03 U06 — Viewer 用户反馈修订，READY_FOR_USER_VISUAL_REVIEW

- 仍在 U06，HEAD 保持 U05 `3419033847e6f135fe7f0098015312dad23de870`。按用户反馈修改唯一 Viewer 的手势、操作入口和顶部居中，不提交、不推送、不进入 U07。保留现有缓存实现和用户工作；与前一候选比对，Composition、图片 store/disk/decode/work pool/Loader/文件下载器、Settings 共9个文件 SHA256 全部相同（`viewer-cache-preservation.json`）。未改 VirtualizedList、U03 恢复、U02 刷新、U04 预载、Pager 容器、Session 或 iPad 导航。
- 根因与修改：MediaZoomScrollView 原生 `isDirectionalLockEnabled=true` 导致浅斜线拖动只改变 X，现关闭方向锁。生产 Viewer 在缩放时由图片平移持有手势，边缘继续拖动也不切图；原始倍率沿用现有 Pager 左右切换，删除顶部箭头。慢/普通/快速原始倍率切页在修改前测试已通过，不将其宣称为已复现的 Pager 故障。顶部张数原为关闭按钮与两个 Spacer 的 HStack，左侧按钮使文字中心偏右；现将文字与左侧关闭按钮分层排布，文字独立相对查看器宽度居中，关闭按钮保留44pt点击区域。
- 图片操作：InteractionKit 新增原生单指长按，仅原始倍率且命中实际图片时打开系统保存/分享菜单；销毁时移除 recognizer，保留原双击/捏合。移除常驻底部保存/分享，反馈仅在操作期间或结果出现。原图入口改为“加载原图”，成功后隐藏，切回已加载图片不重启本代升级。保存仅请求已有 `.original` 候选、再次验证文件角色；无原图/原图失败明确报错，不降级保存缩略图。分享仍可显式提供可用版本。导出继续使用实际编码文件，不使用显示位图重编码；长按时捕获 MediaID 和候选。分享 presenter 生命周期独立于菜单和反馈，iPad 使用视口内原生 popover 定位。
- 修改文件范围：Core/Images/ImageExport；MediaViewer 的 View/Page/质量状态/ExportStore/Controls/SharePresenter；InteractionKit 的 MediaZoomScrollView/ImageView/GestureOwnership 和新增 MediaImageActionGesture；Debug 图片 fixture、直接 Unit/UI 和依赖旧箭头的短 smoke；ADR-0005、交互契约/状态机与本记录。新增原生 long press 与系统确认菜单，无新增自定义动画、透明拦截层或依赖。原生 UIScrollView 捏合/平移和唯一 Pager 保持，未创建第二套图片系统。
- 失败证据（均在 ignored `Artifacts/VisualReview/U06/`）：`viewer-red-diagonal.xcresult` 三条浅斜线均 `(330,120)→(408,120)`，Y 锁定；`viewer-unit-red.xcresult` 方向锁和保存降级两条红例。最早 `viewer-red.xcresult` 第三次拖动碰到垂直边界，调整测试起点后重新取证。首轮 phone UI 的系统菜单 AX 同名父子节点歧义、fixture 只声明 source、关闭前 chrome 被单击隐藏分别修正 selector/fixture/测试前置状态，未降低产品断言。iPad `viewer-ipad-ui.xcresult` 保存分享通过、手势用例在2倍 synthetic pinch 失败；隔离 `viewer-ipad-pinch-diagnostic.xcresult` 三次均未打开菜单，实际合成指尖各仅移动约11pt。改用4倍输入得到实际1.76倍后通过，不修改产品 pinch 或增加延时。中间 lint 的排版/过长诊断行均修正，未降低规则。
- 直接验证：`viewer-unit.xcresult` 18逻辑项/22参数执行全通过，补充 `viewer-edge-unit.xcresult` 3项通过，去重19逻辑项（23参数执行）。涵盖原图缺失/失败不写、分享降级及清理、捕获资源不串图、权限/下载/写入失败、原图替换保持倍率中心、长按仅原始倍率、缩放边缘不切页和 recognizer 拆除。`viewer-phone-ui-final.xcresult` 3/3 PASS：U05 保存分享取消往返、原图升级/隐藏/切回、三种速度切页和斜拖/捏合。iPad 复用 `viewer-ipad-ui.xcresult` 保存分享 PASS，`viewer-ipad-pinch-range.xcresult` 1/1 PASS，`viewer-ipad-gesture-final.xcresult` 1/1 PASS。修复后 iPhone 三次 `(330,120)→(408,127.67/135.33/150.33)`，iPad `(774,630.5)→(967,643)/(967,655)/(963.5,679)`，均双轴移动；缩放拖至边缘仍同 MediaID。全部自动相册写入用 Mock，未读写个人相册。未重跑未改动缓存套件或完整矩阵。
- 本轮正常 Live（居中修订前）：iPhone 真实帖11071397108、第2张加载原图仍为同 MediaID/2.50倍，1050×2334→1080×2400，disk38→39、network保持1、merged0；该次原图新增网络0、磁盘命中1，network1是全 App 累计。分享315720 bytes、SHA256 `7fd78513c41ad75c78be4f1e7219462f4cb1b388ccd00cc66d76f789efadb0bf`，与既有原始编码文件相同；系统取消后临时文件0。正常 iPad 实际图片菜单和371KB文件分享 popover 展示通过；CUA 取消时意外回到 Springboard，因此不声称该次 Live iPad 取消已验证（受控 iPad 取消用例已通过）。CUA 坐标拖动受窗口映射失败限制，斜拖/捏合证据来自 XCUITest，不冒充 Live 手工或真机验证。
- 最新顶部修订仅调整 chrome 排布，沿用上述行为结果。重新执行 `make lint`（`viewer-centered-lint.log`，418文件0 violation）、`make build`（`viewer-centered-build.log`）、`make secret-scan`（`viewer-centered-secret.log`）、`git diff --check` 全通过。`scripts/visual_review_build_install.sh U06`（`viewer-centered-live-install.log`）构建完整正常 Live App 并覆盖 iPhone；同一产物覆盖 iPad。两端 executable SHA256 `ddabb2646172958804f16939fdc917115175413b79032dc7baa7c4371c62c10a`、debug dylib `a36cd14c0306651bd80442f6ea0f78fddc2b18311f03885e7508bff7f9f833eb` 与构建一致（`viewer-centered-installed-binary-proof.json`）。保留账号、历史、排序、缓存、阅读位置；无 uninstall/erase/Keychain 或签名更改。最终 iPhone 从保留历史重开同帖同图，已目视确认“2 / 6”相对屏幕居中，停在该真实图片的原始倍率，供用户检查。
- 限制与验收：真机相册仍未验收、Development Team 仍未配置。U03 iPad旋转进入分栏回首楼仍是已知失败，未修复/不标通过；本轮未扩展旋转矩阵。原图查看仍遵守4096像素解码预算，保存传递原始编码文件，不能用1080×2400尺寸作为原图证明。未暂存任何文件，等待用户视觉验收。

## 2026-10-03 U05 已提交；U06 — READY_FOR_USER_VISUAL_REVIEW

- U05 先按用户批准提交 `3419033847e6f135fe7f0098015312dad23de870`，`feat: save and share images`，20 个相关文件，未 push。提交前全部文件与 U05 验收候选 SHA256 相符；沿用 11 项 Unit 和双端短 UI，仅复核 diff、secret scan、精确暂存清单。编码文件通道与 PhotoKit fileURL 已核对，不能由图片尺寸推断原图。用户已在 Simulator 保存并在照片 App 验收；**真机相册尚未验收、Development Team 未配置**，本轮未改签名、Bundle ID、Keychain。
- U06 本机基线即上述 U05 HEAD。读取 COMMON/CACHE_POLICY/实际 U06 提示词与当前相关实现；只修改 Core/Images、唯一 Viewer 的高清/加载接线、MediaZoomImageView/ScrollView 的可选图像替换接口、Settings/Composition 注入及直接测试/规格记录。VirtualizedList、U03 恢复、U02 自动刷新、U04 内容预载策略、Pager ownership、iPad 导航、Session、Android submodule 均未改。无新增依赖、手势、自定义动画或拦截 overlay。
- 编码资源：ImageResourceStore 与 ImageDiskCache，匿名共享 HTTPDataLoading；完整 URL/query + anonymous/schema 身份哈希，512 MiB/4096 项 LRU，单资源24 MiB，懒加载有界索引、原子文件、checksum/损坏淘汰。磁盘 I/O 在 actor、ImageIO 解码在2个 worker operation。关闭重复 URLCache；原 decoded NSCache96 MiB 保留。公开已用 CDN 候选可落盘；未知 host、含权限参数候选及 private/no-store 响应不落盘，不猜地址或记录 URL。
- 请求/失效：下载最多4个、解码最多2个，同键订阅共享；单消费者取消不取消其他使用者，最后消费者取消后仍等实际传输退出再释放运行槽。排队前台优先；不同 CDN URL/query/尺寸/fit-fill 隔离。清理先关入场并递增 epoch，旧任务不回填；不触碰内容、账号、排序、历史、位置、草稿或 U05 独占导出临时文件。设置提供图片占用与清理。**内容缓存清理未新增**：现有内容清空接口同时删除阅读清单/位置，本轮按用户禁止修改 U03/U04 的边界不接出这一入口，亦未声称内容清理已实现。
- 高清：保留现有 Viewer，新增当前图显式高清动作，最长边4096像素，source120MP安全上限；失败保留旧图并可重试。同 MediaID/重置代次时只替换图像，借现有几何布局保留倍率和归一化中心。仅当前与相邻一张屏幕尺寸订阅，快速离开取消过时任务，不抓整组原图。保存/分享复用同一编码资源并复制到独占临时目录，不使用显示 UIImage 重编码。
- 定向 Unit（`Artifacts/VisualReview/U06/`，均 ignored）：`baseline.xcresult` 原 ProductionImageLoader 基线 PASS；`cache-unit-2.xcresult` 新缓存6项 PASS；`quality-unit-2.xcresult` 原 Loader + 缓存 + 高清共20逻辑项/21参数化执行 PASS；`direct-unit.xcresult` 11项 PASS（缓存/合并队列/高清/原串图）；`final-edge-unit.xcresult` 精确3项 PASS（容量/损坏索引与文件、原取消、替换请求不串图）。去重合计25逻辑项、26个含参数用例，0失败/跳过。中间 direct-unit 使用了文件名而非类型名 ThreadContentImageRenderStateTests，该 selector 未匹配，不计入执行；后以正确 ThreadImageRenderStateTests 精确方法执行。
- 关键测试事实：重建 encoded store + 全部网络失败后，同 URL 仍解码显示，源请求0；未缓存 URL 正常失败。两个消费者同键源请求恰为1，取消一个另一仍成功。两个尺寸/处理方式位图不同且源请求1；导出 GIF 原字节相等，不受 clear 影响。最后消费者取消、前台排队优先、运行槽保持、clear 迟到完成不回填、URL query 不混同、LRU字节/条目上限、坏文件/索引淘汰、高清中心/倍率保持与失败保留均通过。
- 短 UI：`phone-ui.xcresult` iPhone 1/1 PASS（53.430s）；`ipad-ui.xcresult` iPad 1/1 PASS（52.047s）。同一完整 fixture App 用例：2.5×后高清仍同倍率、Mock 相册写入成功、一次快速滑动、切回、关闭返回来源。未扫描/写入个人相册。UI 后仅补诊断可访问性值、保留空候选失败及清缓存取消显示分支；普通 Live 已以最终构建再验高清/往返。
- 门禁：`make lint`（`lint-complete.log`）416文件0 violation；`make build`（`build-delivery.log`）PASS；最终 `make secret-scan`（`secret-delivery.log`）、`git diff --check` 均 PASS，暂存区为空。未跑全部 Unit、quality-fast、quality、长 Pager/千楼矩阵或旧内容缓存套件。中间失败：cache-unit 因 GIF fixture 工厂无参数却传入尺寸编译失败；quality-unit 因 SwiftUI task 参数顺序编译失败；修正后对应重跑通过。lint 曾报告参数对齐、actor长度、tuple成员数、行长、load方法复杂度；通过拆分解码/诊断及合并等价错误分支修正，未降低门槛。
- 正常 Live：`scripts/visual_review_build_install.sh U06`（`live-install.log`）PASS，完整正常 Debug App 覆盖 iPhone `70D93841-1FEB-445A-8FAD-B1C29B981D5D`，codesign/entitlements 验证通过；同一正常产物覆盖 iPad `EE89FBE1-9DCA-49DC-8432-8A9C856A28FF` 并启动。无 uninstall/erase/清 Keychain/账号/缓存。iPhone executable SHA256 `ff17c0f491fe4c63ee17273194ed51d75741a21d19566cc35af5a0f8754c9bff`、debug dylib `81ad2fdb442d015bc403bc34d5e434efac12f2622b352497ab97b1ab173a758c` 与本轮构建一致，见 installed-binary-proof.json。
- Live 实测：从保留的历史打开真实帖子11071397108、首楼153990906755、第2张/source ordinal4。screen 1050×2334，disk=6/network=26/merged=0；双击2.50×后高清1080×2400，disk=7/network=26/merged=0，截图中心/边界相同。分享实际文件315720 bytes，SHA256 `7fd78513c41ad75c78be4f1e7219462f4cb1b388ccd00cc66d76f789efadb0bf`，与一份磁盘 encoded Data 逐字节一致，取消后临时文件数0（live-file-proof.json）。该字节证据及 original candidate 角色证明文件通道，不以尺寸宣称原图。
- 随后正常 terminate/launch 进程，从保留历史重进同帖同图：screen 已显示，disk=38/network=1/merged=0；再2.50×高清，disk=39/network=1/merged=0。网络1是新进程**全 App累计**，不声称全 App零请求；这次高清新增网络0、磁盘命中1。关闭返回同一首楼，再打开同图，最终disk=41/network=1/merged=0，停在第2张、原始倍率，高清/保存/分享入口启用。真实并发 merged=0，合并1次源请求由受控测试证实，未伪装为已观察到 Live 合并。
- 限制：离线命中/未缓存失败为受控网络失败测试，未断开正常设备网络；新候选相册仍留用户点击验收，已有 U05 Simulator 人工验收不代表真机通过。未在保留账号设备清缓存或退出。高清受4096像素预算，不承诺任意全尺寸解码；未知/受保护候选不持久化。U03 **iPad旋转进入分栏回首楼** 已知失败保留、未修复，不标通过。iPad本轮高清短UI已通过，正常App已更新，未扩展旋转矩阵。
- U06 未暂存/提交/推送，不进入 U07。最终候选留在真实帖子的 Viewer，等待用户视觉验收。

## 2026-10-03 U04 已提交；U05 — USER_ACCEPTED（Simulator 相册已人工验收）

- 用户已在当前 Simulator 点击保存，并在照片 App 确认图片正确，明确批准提交 U05 后开始 U06。提交前与候选 20 文件 SHA256 清单逐一核对，代码未变，沿用 11 项 Unit 和 iPhone/iPad 短 UI；仅复核 diff、secret scan、精确暂存清单。保存/分享直接使用下载得到的编码 Data 文件，PhotoKit 添加 fileURL，分享传递 fileURL；不读取 Viewer 的 decoded UIImage，不裁切、转码或重编码。“原始候选”依据 descriptor 中已有 original 角色及字节保持路径，不依据 1080×2400 尺寸推断。

- U04 已按用户批准的精确清单提交：`708b09e6088d8e2e7e33da59401cf2879e8c19c7`，`feat: add bounded content prefetching`，26 个相关文件，未推送。提交前复核 diff、secret-scan、暂存清单，源代码与验收候选一致，沿用已有结果。排除用户原有改动及提示词/技能文件、.idea、.DS_Store、Artifacts、凭证和 Android submodule。下方 U04 控制测试源请求 1 次、Live 合并计数 0 的事实不变。
- U05 修改范围：Core/Images 的 ImageExport、OriginalImageFileFetcher、PhotoLibraryWriter；Viewer 的 MediaExportStore、MediaExportControls、ImageFileSharePresenter；现有 Viewer/App composition 注入；project.yml 与生成 Info.plist 的 addOnly 用途说明；直接 Unit/UI、fixture、规格及本记录。未修改显示 Loader/解码策略、VirtualizedList/首次恢复/视口保持、Pager/缩放 ownership、U02/U03/U04 缓存刷新预载、Session/Keychain、iPad 导航。无第三方依赖、新手势、自定义动画、覆盖拦截层或 U06 磁盘图片缓存。
- 原始文件通道捕获点击时 MediaID、资源描述和序号，复用已有 Viewer 候选顺序和匿名 HTTPDataLoading（24 MiB 上限），不附加会话。ImageIO 只识别编码元数据，源 Data 写入独占临时文件，不读取/重新编码显示位图。原始候选失败时只使用已返回候选，显示“可用版本（非原图）”；无法识别、超限文件拒绝导出。正文复用原图片点击 → 唯一 Viewer 保存入口，未添加第二套长按实现。
- 状态：save → addOnly 授权 → 下载 → PhotoKit 文件资源写入 → 完成/明确失败；share → 下载 → 等待系统接管 → 分享 → 完成/取消清理。忙时禁止重复操作，切图不替换捕获资源，重试继续原图。关闭取消下载；PhotoKit 提交后保留文件到实际回调。尚未分享接管时关闭直接清理，接管后等待系统完成/取消/拆除再幂等释放。系统不支持写入时可用分享/存文件，不转换成 JPEG 或静态帧。
- Unit：`Artifacts/VisualReview/U05/baseline.xcresult` MediaViewerPresentation 2 PASS；最终 `lifecycle-unit.xcresult` **11 项，15 个含参数化用例，0 FAIL/skip**。覆盖捕获/重复点击、拒绝权限、下载/写入/格式失败与重试、原图优先/降级标记、JPEG 方向、透明 PNG、GIF 两帧逐字节保持、超限/无效文件、相册/分享期间文件保留、分享接管前关闭清理。自动化仅使用 Mock 写入端，不读写个人相册。
- UI：最终 `lifecycle-ui.xcresult` 同一短用例在独立 iPhone/iPad fixture Simulator **各 1 PASS**：第二张保存（Mock）、第三张实际文件分享面板、原生外部取消、取消后第三张再次保存、关闭返回来源页面。`make lint`（`lint-delivery.log`，406 文件 0 violation）、`make build`（`build-delivery.log`）、`make secret-scan`（`secret-delivery.log`）、`git diff --check` 均 PASS。未运行全量 Unit、quality-fast、quality、长交互矩阵或未改的内容缓存测试。
- 中间失败保留：export-unit 因候选字符串未转换 URL 编译失败，export-unit-2 因误用不存在的 callout token 编译失败；修正后 export-unit-3/export-unit-final 通过。早期 lint 为格式/对齐错误，已修正。phone-ui 分享已打开，但测试查找不存在的英文 Close 按钮失败；改用该系统原生外部取消后 phone-ui-final/ipad-ui 及最终 lifecycle-ui 通过。正常 Debug build.log 暴露 fixture 符号隔离遗漏，build-final.log 暴露旧 Debug Viewer 调用未注入依赖；修正 UITESTING 边界及可选导出注入后 build-pass/build-delivery 通过。没有降低产品断言掩盖失败。
- 正常 Live：最终 `scripts/visual_review_build_install.sh U05`（`live-install-final.log`）PASS，完整 Debug App 覆盖安装 iPhone `70D93841-1FEB-445A-8FAD-B1C29B981D5D`，签名/entitlements 校验通过，无卸载、erase、清 Keychain/账号/历史/排序/内容缓存。安装与构建哈希匹配：executable `fad47ddb5cca35309163e36b496654e0413ad22462f3d6162beac3d249a4af26`；debug dylib `19b9596a30827067b146b85e93e948ba9cb159606e9d619564602397ff3d620e`，见 `installed-binary-proof.json`。
- Live 实际文件：真实缓存帖子 `11071397108`、楼层 `153990906755`，第二张（source ordinal 4，2/6）使用已有 original 候选，系统分享展示 **JPEG / 1080×2400 / 315720 bytes**；取消后独占临时文件数为 0。关闭 Viewer 返回同一楼层，再打开第二张，停在启用的“保存图片”入口。`live-file-proof.json` 与 `20261003-125907-media-viewer-save-ready.png` 为 ignored 证据。未代用户点击真实相册保存、扫描照片或向他人发送；实际 Photos 内容、边缘、清晰度、方向及系统文件目标写入完成待人工检查。
- 限制：按原配置执行 generic iOS 设备 build（`device-build.log`）因 **未配置 Development Team** 失败，没有关闭签名、更改证书或生成伪 IPA。设备工程/用途声明已就绪，但无已签名真机包、无真机验证；真实 GIF/其他格式 PhotoKit 兼容性待设备验收。U03 的 **iPad 旋转进入分栏回首楼** 已知失败及证据保留，未修复、未标通过。
- U05 按此次授权精确提交，提交成功后才开始 U06；不推送，保留用户原有改动与 Android submodule。Simulator 人工相册验收通过不代表真机相册通过；真机未验收、签名团队未配置的限制保留。

## 2026-10-03 U04 — USER_ACCEPTED

- 本次验收：用户批准提交已安装 U04 候选并进入 U05。验收后代码未变，沿用同一候选的定向结果；只复核 diff、secret scan 和精确暂存清单。源请求 1 次的合并测试、Live merged=0 与 iPad 旋转分栏回首楼未修复的事实均保留。不 push，提交成功后才开始 U05。
- 授权与提交边界：先完成 U03 精确提交 `7f7a5c9f0132396f2f757a170649aa877741f25d`，标题 `feat: cache thread reading and restore reading position`；25 个相关文件，未 push。提交前沿用候选定向结果，只复核 diff、secret scan、精确暂存清单。未包含原有未跟踪 Prompt/skill、Artifacts、IDE 文件、凭证或 Android submodule。U03 缓存重进、首次定位自动结束、新位置保存、进程重开及规定的 iPad 重进保持已通过；`testIPadRotationKeepsNewReadingPosition` 的分栏旋转回首楼失败用例与证据保留，用户批准不阻塞 U04，但没有改为通过。
- U04 仅有界正文预载：新增 Core/Prefetch 的共享 ContentLoadScheduler、页级候选 scope/session 和 App 网络策略适配。关注吧与推荐/吧内帖子候选最多两个，列表末端最多一页；后台完成不递归排后页、不更新正在阅读的列表、不创建离屏 View/Cell、不写历史或 readAnchor。两个投机槽、八项队列，前台可接管或越过队列；单个等待者取消不终止其他消费者，最后消费者取消后仍等传输真正退出才释放槽。
- 数据与隔离：复用 U02/U03 Repository、ContentPageCache、账号/query 身份和原预算。帖子页预载保持后页、位置与定位页身份；吧 prepared 页与 reading manifest 分开，前台一次取用后仍保留后续重进自动检查。账号 revision、缓存 epoch、查询键、刷新 revision 拒绝旧完成；显式刷新移除原首屏 prepared 条目。网络取用前再查一次缓存，覆盖缓存首次查询与调度入场之间另一请求刚完成的窗口。
- 接线/设置：AppCompositionRoot/SceneRoot、FollowedForums/Recommendations/Forum/ThreadReader Store 与已有列表回调、Settings、两类缓存 Repository；AppSettings 增加独立持久化预载模式，默认仅非昂贵连接，可关闭/所有网络。constrained、低电量、非前台撤销投机消费者，前台接管者不受影响。仅应用内策略，不保证锁屏下载。Debug 设置页显示聚合 cache/foreground/prefetch/merged/memory/disk 计数，Release 无诊断条；计数不含正文、URL、账号或凭证。VirtualizedList、首次恢复/视口保持、Pager、MediaViewer、图片加载/缓存、iPad 导航和网络协议均无修改。无新动画、业务手势、overlay 或第三方依赖；图片磁盘缓存仍留 U06。
- 实际定向证据（ignored `Artifacts/VisualReview/U04/`）：`unit-delivery.xcresult` 9 项/12 次参数化执行 PASS；最终刷新条目清理补充后的 `unit-invalidation.xcresult` 5 项/8 次执行 PASS，未重复旧 U03 缓存套件。包括同键预载→前台接管→取消投机等待者→缓存重进的源调用总数恰为 1；两个运行请求+八个队列时前台立即开始；关闭/低数据/低电量/后台策略；取消不响应的传输仍占槽；账号/清理/刷新失效；首屏预载保留后页/锚点和当前显示；不同排序隔离、prepared 取用后重进仍新增一次自动检查。`unit-final` 命令附带的两个 U02 方法 selector 没有匹配 Swift Testing 参数化名称，不计为 U02 独立执行；U02 自动检查/深处缓存保留的本轮直接证据来自 U04 的 forumPreload 用例，未声称跑了完整 U02。
- UI：`ui-delivery.xcresult` 1/1 PASS（21.137s），同一完整 fixture App 中首次打开以 UITESTING accessibility 值证实来自预载缓存，实际滚动→返回→重进，保存楼层可见且 initial-restoration 自动 idle；没有弱化目标可见断言。该值不进入普通 Live/Release。未跑全部 Unit、quality-fast、完整 quality、长交互矩阵或 iPad 旋转。
- 门禁：`make lint` PASS（396 文件，0 violation），`make build` PASS，`make secret-scan` PASS，`git diff --check` PASS。过程中失败如实保留：首轮队列测试误用了单等待者 HarnessContinuationGate，替换成每请求独立 gate 后通过；编译阶段暴露 Sendable 闭包、Foundation import、lazy actor 默认值/初始化前捕获 self，已修正；首个 forum 用例误用不支持所需第二页的基础 fixture，改用已有 R05ForumFixture 后通过；lint 的长度/参数组织/对齐问题已修正。UI 首轮在隐藏底栏的帖子路由尝试直接切设置失败，改为读取帖子页已有缓存状态的测试值后通过，没有改导航。相关日志含 u04-scheduler*.log、unit-first/second/third/fourth、lint-first/second/third、ui-first。
- 正常 Live 交付：`scripts/visual_review_build_install.sh U04` PASS，完整 Debug .app 覆盖安装正常 iPhone `70D93841-1FEB-445A-8FAD-B1C29B981D5D`；签名和 Simulator entitlements 校验通过，未 uninstall/erase/清 Keychain/缓存。安装 executable SHA256 `dea971574d041ccbe7f5c7059744c2b1df8841397d8931c9f51662fa13599b69`、debug dylib `dd63689e1d0a929325f5352680bb298de5fae6ae6fe3c6964d40a6f32baf0700` 与本轮产物匹配。登录、关注吧、历史入口和高通吧最新发布排序保留。
- Live 实测：默认“仅非昂贵连接”；初始设置计数 cache=0 foreground=0 prefetch=2 merged=0 memory=0 disk=6。实际打开高通吧及两条附近帖子，第二条 `threadID 11071397108` 滚到中部→返回重进，原目标 `postID 153990977320` 仍在视口；磁盘仅检查位置元数据，确为同一 postID，未输出正文或凭证。随后设置计数 cache=1 foreground=3 prefetch=7 merged=0 memory=51 disk=9；这是实际操作累计值，不将 Live 未观察到的并发合并声称为通过，也不将所有打开称为预载命中。合并零重复源请求由上面的受控测试证明。最终再次回到该帖子，目标仍可见，留给用户检查。截图 `20261003-115721-live-middle-before-return.png`、`20261003-115815-live-middle-reentry.png` 和 live-final-reader 均在 U04 ignored 目录。
- 剩余限制与停止：预载只覆盖少量候选，受原 TTL/预算与网络策略限制；没有定量延迟承诺。U03 iPad 旋转分栏已知缺陷仍未修复，不在 U04 修改导航/旋转恢复。本记录的候选已获用户验收，按授权精确提交 U04，随后单独开始 U05；不推送。

## 2026-10-03 U03 — USER_ACCEPTED

- 用户批准按已验证范围提交 U03，沿用下方同一候选的定向 Unit/UI、缓存重进、初始恢复自动结束、新阅读位置保存、Live 进程重开及规定范围 iPad 重进结果。验收后未改变代码，只复核差异、secret scan 与精确暂存清单。
- iPad 旋转进入分栏后回首楼仍未修复；失败用例与 ignored 证据保留，不标记通过。用户明确允许此已知缺陷不阻塞 U04，U04 不修改导航或旋转恢复。
- 精确提交标题为 `feat: cache thread reading and restore reading position`；用户原有 Prompt/skill、Artifacts、凭证、IDE 文件及 Android submodule 排除。不推送；确认提交成功后才开始 U04，SHA 在随后 U04 记录补记。

## 2026-10-03 U03 — READY_FOR_USER_VISUAL_REVIEW（首次定位/视口保持分离；额外 iPad 旋转问题保留）

- 用户明确授权替换本轮新增的首次恢复等待协议。本轮仅修改 `InitialReadingRestoration.swift`、`VirtualizedList.swift`、新增同组件 `VirtualizedList+Reading.swift`，以及直接 Unit/UI 回归和本记录。现有 ThreadReader 的 thread/account scope 接线继续使用；缓存、Repository、Store、Subposts、用户草稿保持。本机 HEAD 仍为 `9248f2dc68a0610076178f2189a329d4a8bc5c6d`，无暂存/提交/推送，不进入 U04。
- 根因与修订：原协议将曾创建的前置行加入等待，依赖不保证逐配置触发的 SwiftUI 几何回调，既不能可靠退出，也不能证明后续首次测量已完成。现删除 awaitingMeasurements/predecessors/adopted 及恢复专用 fixedSize/onGeometryChange；恢复前后 hosted Row 的布局修饰相同。首次定位只等待窗口/尺寸、已应用 snapshot 和稳定业务 ID，一次 scrollToRow；校验实际已显示 Cell 的 ID、当前内容配置、窗口及有效视口相交后，把实际几何交给当前视口记录，释放历史目标，结束初始回调并允许正常进度。
- 后续只在 opt-in 表格布局边界维护当前 RowID/relativeY/尺寸，按新 rowMinY、adjusted top inset 与当前实际 offset 计算剩余修正并限幅。UIKit 已补偿时不重复移动；几何读取与状态修改分开，布局/程序滚动防重入。拖动/惯性期间清除旧记录，停稳后捕获新楼层；主动滚动和回顶部优先；账号、目标、拆除、无效 snapshot 或不同尺寸不沿用旧几何。分页、footer、图片完成不重启历史定位；程序补偿不报告用户进度，正常离场仍保存实际位置，U02 零尺寸保护保留。无新动画、手势、overlay、依赖、轮询、固定延迟、重复 scrollToRow、全表 reload 或全量 Cell 测量。
- 组件证据（ignored `Artifacts/VisualReview/U03/Viewport/`）：首次 `component.xcresult` 编译 FAIL，原因是拆出扩展时冗余 `internal(set)` 被严格构建拒绝，移除后 `component-fixed.xcresult` 4 项/10 次 PASS。最终 `unit-final.xcresult` **14 项/21 次 PASS，0 skipped**：包括原退出失败组件、实际退出后新进度/分页/footer/晚到高度更新、立即拖动及账号/目标/拆除取消、UIKit 无/完整/部分补偿三种真实表格几何结果、U02 刷新/零尺寸与 R11 通知目标 Unit。已完成恢复的 target 为 nil，初始回调已解除；Cell 创建数小于总楼层数。未重复缓存读写测试。
- iPhone：`reader-ui.xcresult` 原 UI 流程 PASS，自然滚动保存 420001，退出/新位置/图片往返全部通过。为固定验证 430001，补充真实列表手势定位；`iphone-final.xcresult` 的 U02 深处、顶部、自动/下拉刷新 3 项及通知具体楼层 1 项 PASS，但新增固定目标步骤在定位前因 430001 已离屏而 FAIL。`exact-target.xcresult` 同样因离屏 frame 为空 FAIL；`exact-visible-target.xcresult` 因过短手势落入点击而未建立目标 FAIL，均未改生产实现。改为先滚入视口，再把目标行部分置于视口顶部，实际验证首个可见 ID：最终 **`exact-floor.xcresult` PASS（88.559s）**，保存/恢复 **430001**，无需拖动即可 idle；后续实际保存/恢复 **470001**，旧目标不回拉。目标可见与新位置保存断言未放宽。
- iPad：`ipad.xcresult` 和 `ipad-final.xcresult` 的图片往返、第三页重进、自动退出、新位置再重进均通过，均在末尾额外的旋转断言 FAIL；等待实际可见条件后仍失败。录屏显示竖屏转分栏后详情回到首楼，保留 `ipad-rotation-failure.png`。**这是仍未解决的尺寸/导航切换限制，未宣称通过，也未扩改导航容器。** 将原旋转断言原样保留为 `testIPadRotationKeepsNewReadingPosition`，与用户要求的重进短用例分开。最终只运行规定的重进方法：`ipad-reentry.xcresult` **1/1 PASS，0 skipped**。本轮不运行旋转矩阵或另起阶段。
- 轻量检查：前两轮 lint 因类型长度/空行 FAIL，将恢复方法归入同组件扩展并修空行，最终 `lint-delivery.log` PASS；`make build`（`build.log`）、`make secret-scan`（`secret.log`）、`git diff --check` PASS。未运行全量 Unit、quality-fast、quality 或千楼压力矩阵。上述失败包均保留，不以通过的子步骤冒充整包通过。
- 安装与 Live：`scripts/visual_review_build_install.sh U03` PASS（`visual-install.log`），完整正常 Debug Simulator App 覆盖安装账号 iPhone，无卸载/erase/清 Keychain。已安装主程序和 dylib 与本轮产物 SHA256 相同（`installed-candidate.json`），不是旧 Live。已登录、原关注/历史可见，未修改排序。实际缓存帖子中部返回重进成功；继续滚到第 28 楼正文，返回重进仍显示同楼。随后正常 terminate/launch，经保留的历史入口重开，同一第 28 楼仍可见，未观察到恢复后再次上跳。只读缓存 manifest 元数据确认 `postID=153988156596`、页 `[0,2,3]`，不导出正文/URL/凭证。截图 `live-before-reentry`、`live-new-position`、`live-new-position-restored`、`live-after-process-restart` 在本目录；最终 App 留在帖子页。一次坐标滚动被工具拒绝、两次历史入口索引过期，改用已暴露的原生滚动动作及即时读取入口后完成，未将失败动作计入成功。
- 交付边界：首次定位和当前视口保持的要求范围通过，额外 iPad 旋转问题仍保留为失败回归；不承诺行内像素一致。等待用户视觉验收，不暂存、不提交、不推送、不进入 U04。

## 2026-10-02 U03 继续修正退出条件 — INCOMPLETE（退出断言仍失败）

- 本轮仅调查并修改首次恢复完成条件及直接回归，不新增阶段。HEAD 仍为 `9248f2dc68a0610076178f2189a329d4a8bc5c6d`；全部原有 U03 缓存、Repository、Store 与用户草稿保留，无暂存/提交/推送，不进入 U04。本节覆盖下方旧状态。
- 唯一组件失败的具体原因：首次定位分支原先直接 return，未在该入口执行结束判断；移除该 return 后，仍因必要前置行缺少 SwiftUI `onGeometryChange` 回调而不能结束。`entry-unit.xcresult` 中目标 29 已可见，required 为 `[1,24,25,26,27,28]`，其中 24–28 仍待测；这些 ID 仍在当前 snapshot，实际 Cell/configuration generation 为 1，已挂窗，cell/content bounds 均为 390×117。原等待状态并未建立可靠的配置测量代次对应，不能只凭行 ID 判定测量已完成。`adopted=false`、`isActive=true`、`permitsProgress=false`，布局回调仍存在，确实继续保留自动补偿和抑制阅读进度，并非调试标签未同步。
- 尺寸口径核对：已收到的 hosted content 与 UIKit fitting 高度相同，未发现靠增大容差即可解释的差值。尝试用 UIKit fitting 回调替代内容几何回调后，组件结束回归通过，但原 UI 目标可见回归失败。`layout-diagnostic.xcresult` 中 430001 在 y≈5393/offset≈5393 时过早结束；随后实际行布局变为 y≈5026.33，offset 不补偿，目标离开视口。`generation-diagnostic.xcresult` 只有一次 snapshot；结束后仍发生目标 Cell 的实际绑定，以及首次无障碍层级读取期间此前未显示行的绑定/测量。因此一次 fitting 结果不能证明本次定位所需布局工作已经完成；不能依赖“所有布局最终完成”，也不能立即结束而忽略后续首次测量。
- 已撤回造成目标漂移的 fitting 替换、代次接线及所有临时日志，试验副本保存在 ignored `Artifacts/VisualReview/U03/Exit/fitted-candidate/`。最终保留原目标几何补偿、首次定位入口尝试结束判断、统一结束清理调用，以及真实补偿次数/回调生命周期的测试观测。新增断言检查实际退出、允许新进度、旧补偿停止和更新后不重启，未删除目标可见或事务退出断言；不声称这些断言现已全部通过。没有新增动画、手势、overlay、依赖、全量 Cell 测量、固定等待或长期纠偏机制。
- 执行结果（均在 ignored `Artifacts/VisualReview/U03/Exit/`）：`diagnostic-unit.xcresult`、`diagnostic-entry.xcresult`、`entry-unit.xcresult` 均 FAIL 于退出；`fitting-unit.xcresult` 退出成功但旧绝对 offset 断言 FAIL，确认原回调已解除后将该内部断言改为实际补偿次数和新进度检查，`component.xcresult` 4 项/8 次 PASS，仅代表已撤回的试验。`reader-ui.xcresult`、`reader-natural-height.xcresult`、`layout-diagnostic.xcresult`、`generation-diagnostic.xcresult` 均 FAIL 于目标可见，未把试验组件通过当作修复成功。
- 最终 `final-targeted.xcresult`：**15 个逻辑测试，13 PASS / 2 FAIL，0 skipped**。同时选择 Unit/UI Smoke 配置使所选测试在两配置各执行一次，共 40 次执行，36 PASS / 4 FAIL；不是额外扩大测试范围。失败分别是实际表自动退出组件用例和原 U03 UI 自动退出断言；原目标可见断言通过，新阅读位置 UI 链在退出失败处停止，不能认定新位置保存已通过。U02 刷新/临时零尺寸组件及 R11 通知定位 Unit 通过；U02 深处/顶部 UI、通知 UI 和 iPad 重进未继续运行。测试期间一次 Simulator 启动 RequestDenied 后工具自动恢复并完成；未另行重跑。未重复已通过缓存读写测试或运行全量 Unit/quality-fast/quality/压力矩阵。
- 轻量检查：早期 `lint.log` 因长度/对齐 FAIL，调整格式后最终 `make lint`（`final-lint.log`，388 文件 0 violation）、`make build`（`final-build.log`）、`make secret-scan`（`final-secret.log`）、`git diff --check` 均 PASS。最终未同时满足保持目标与自动退出，按此前授权边界停止扩大修改。
- 本轮未覆盖安装正常 Live App，未执行新位置返回重进/进程重开验收；设备保留的旧 Live 版本不能证明本轮候选。账号、排序、历史、缓存与 Keychain 未清理。无 READY_FOR_USER_VISUAL_REVIEW。

## 2026-10-02 U03 续修 — INCOMPLETE（目标可见，初始恢复事务未可靠结束）

- 本次用户明确批准“初始恢复事务”最小重设计。HEAD 仍为 `9248f2dc68a0610076178f2189a329d4a8bc5c6d`；此前未提交 U03 缓存、模型、Repository、Store、测试及用户草稿全部保留，无暂存/提交/推送，无 U04 或独立阶段。下方旧记录是此前交付状态，本节覆盖当前状态。
- 本轮仅修改 VirtualizedList 的可选首次恢复生命周期、ThreadReader 的 thread/account scope 接线、直接回归与交互契约。新增 InitialReadingRestoration、U03InitialReadingRestorationTests；原 U03 UI 的业务目标行可见断言保留，并增加事务必须退出的断言。没有改变业务行 ID、Pager、MediaViewer、图片 Loader、网络或缓存预算，也没有新增动画、手势、overlay、依赖、全表 reload、全量创建 Cell、延时或重复 scrollToRow。
- 根因仍为已证实的首次自适应高度改变目标 minY，而原一次性定位未保持目标相对视口位置。候选以稳定 ID 只首次定位一次，之后补偿目标 minY 的实际变化；用户开始拖动、身份/目标改变或 teardown 使事务失效；恢复中的程序滚动不报告进度。完成条件尝试由已创建且位于目标之前的行报告内容尺寸、表格采用尺寸、目标可见共同决定。**当前候选仍在工作树，未达到生产验收条件，不能视为已完成修复。**
- 直接证据均在 ignored `Artifacts/VisualReview/U03/Restoration/`：`red.xcresult` 再次复现旧故障，保存目标 430001 重进不可见。首次候选 `transaction.xcresult` 因缺少显式 initializer 编译失败，补齐后 `transaction-ui.xcresult` 因 UIKit 几何查询同步进入 Cell provider、与事务 mutating access 冲突而崩溃；将几何读取移至事务写入前后消除该实现错误。
- `transaction-ui-fixed.xcresult` 原目标可见断言通过，但新增结束断言失败。`transaction-diagnostic.xcresult` 记录目标 minY/offset 从约 5573 一起变至 5188.33，待测集合最后仍有目标 430001；测量 observer 按原业务 ID 隔离后 `transaction-identity.xcresult` 仍未退出。进一步将结束等待范围限定为目标之前的实际创建行后，**最终 `transaction-final-ui.xcresult` 仍 FAIL**：postID **430001** 存在、可点击且与视口相交的原断言通过，`initial-restoration:idle` 断言超时（整条 60.573s）。不得仅凭“可见”宣称完成，事务可能长期保留布局回调；剩余无法收敛的具体 UIKit/SwiftUI 测量来源为 UNKNOWN。临时几何 print 已移除，UITESTING 只保留无正文的活动状态供断言。
- Unit：`transaction-unit.xcresult` 4 项中 2 FAIL（恢复未退出；另一个 teardown 空表 offset 应为 0 的测试夹具断言错误，已修正）。最终 `targeted-unit.xcresult` **20 项，19 PASS / 1 FAIL；25 次执行，24 PASS / 1 FAIL，0 skipped**。U02ForumRefreshControlTests（包括临时零尺寸保护）、R11NotificationTargetTests、Stage17AdaptiveLayoutTests 通过；新事务的几何补偿模型、拖动立即退出、不写程序进度、账号/目标/销毁失效通过；实际表的恢复退出用例仍失败。没有重复缓存读写测试。末尾曾仅尝试调整未运行的 Unit 挂载夹具，已撤回该未验证的三行调整，最终测试源码对应上述执行版本。
- 轻量检查：`make generate` PASS；`make lint` 曾因类型长度、尾闭包、空行 FAIL，修正结构/格式后 `lint-final.log` PASS；`make build`（`build-final.log`）PASS；`make secret-scan`（`secret-final.log`）PASS；`git diff --check` PASS。未运行全量 Unit、quality-fast、quality 或压力矩阵。
- 按用户“方案仍不能通过则记录实际差异并停止扩大修改”收口。本轮未继续 U02 深处/顶部 UI、iPad 重进或 Live 进程重启检查，因此不能宣称 U02 全部 UI 无回归。失败候选未覆盖安装到保留账号设备；账号、历史、排序、缓存、Keychain 未清理。CUA 确认原正常 Live App 仍停在已缓存帖子第 27–31 楼附近；这不是本次候选的成功验收。无 READY_FOR_USER_VISUAL_REVIEW，等待后续用户指令，不进入 U04。

## 2026-10-02 U03 — INCOMPLETE（缓存已接通，重进定位 UI 未通过）

- 目标与范围：用户授权“推送U02并进入U03”。U02 已精确提交 `9248f2dc68a0610076178f2189a329d4a8bc5c6d`（`feat: cache forum pages with retained refresh`），`git push origin main` 成功，`git ls-remote origin refs/heads/main` 回读同一 SHA。本轮以该 HEAD 为基线，仅 U03，未提交/推送 U03，未进入 U04。用户未跟踪 Prompt/skill 保留。
- 修改文件：AppCompositionRoot；Core/Models 的 ReadingContentCache、ThreadContent、FixtureReadingFlow、Subposts、ForumContentCache；ImageLoading 的资源 Codable；Core/TiebaAPI/CachedReadingRepository；ThreadReader Store/View/ListPresentation；Subposts Store/View；NotificationDestinationStore 的预定位调用；Stage15ThreadReadingTests、U03ReadingCacheTests、U03ThreadCacheSmokeTests；ADR-0031、STATE_MACHINES、本记录。最终 VirtualizedList、Stage17AdaptiveLayoutTests 与 HEAD 完全相同，两个共享列表候选均已仅撤回自己的差异。
- 关键设计/状态转换：生产 Debug/Release 共用同一个 ContentPageCache 实例，吧首页/帖子/楼中楼共享预算；页键含本地账号 namespace、thread/parent/query/pn/pid，manifest 只写页引用与最小 ReadingPosition。加载页保存完整领域节点，停稳/离开/后台不重编码正文。缓存恢复实际连续范围，缺前页不顺序联网追赶；保留 wire hasMore/cursor。5 分钟新鲜期，过期先显示再刷新阅读页；刷新成功保留其他页，失败保留正文。通知预定位不写进度，现有展示历史入口不变。账号 revision/cache epoch 拒绝迟到请求与 checkpoint；明确 HTTP/auth 拒绝及领域删首楼标记失效副本，未知 wire code 不猜为权限问题。
- 动画/手势/overlay/依赖：无新增自定义动画、手势、overlay 或依赖。线程/楼中楼接入既有可选系统下拉刷新；已缓存/失败文字仅在原页尾，不加顶部通知。两个首次定位候选未保留，最终仍沿用原一次性初始定位组件。
- 执行命令与结果（ignored `Artifacts/VisualReview/U03/`）：
  - 基线 `xcodebuild test` / Stage15ThreadReadingTests + R08SubpostsStoreTests：`baseline.xcresult` 15/15 PASS。新增刷新失败保留三页回归首次方法 selector 未带 Swift Testing 方法括号，`red.xcresult` 实际 0 项，不计通过；随后整类 `red-state.xcresult` 11 PASS/1 FAIL，确认原 reload 清空内容。
  - 首轮实现 `make build`（build-first.log）PASS；`targeted.xcresult` U03 + Stage15 + R08 + Stage17：29 项/30 次 PASS。新增确定性删首楼失效、通知不写进度、补齐会话检查后最终 `final-unit.xcresult`：38 项/39 次 PASS、0 skipped（含 U03 8 项/9 次、Stage15、R08、Stage17、R11NotificationTargetTests）。原组件的一次性定位/保留 offset 单测通过，不能替代下述真实异高行 UI 故障。
  - iPhone 隔离设备 `UI Smoke` / U03ThreadCacheSmokeTests：`ui-iphone.xcresult` FAIL（63.47s）。图片打开/返回、加载至第三页均成功；重进后指定首个可见 postID 不在视口，失败断言保留。`ui-diagnostic.xcresult` 再次复现；仅 UITESTING 临时日志证明停稳和回读同为 postID 430001。候选一等待初始 diffable apply 完成并 layoutIfNeeded：`ui-layout.xcresult` FAIL。`ui-geometry.xcresult` 仅观测，发现初始目标 row 28 的 minY 为 5393，前三次布局正确；第 4 次自适应行高更新使其 minY 变成 5026.33，而 contentOffset 仍为 5393，视口移至 row 30。候选二改等原生 push 转场结束：`ui-transition.xcresult` 仍 FAIL。全部日志/视频/附件保留 ignored；临时日志代码已移除。
  - 按 COMMON“两次无效尝试后停止堆补丁”停止继续调整共享组件，撤回两个候选及试验断言，没有削弱失败的 U03 UI 断言。最终核心回归通过；UI 未通过，不能宣称 U03 完成，不能输出 READY_FOR_USER_VISUAL_REVIEW。
  - `make lint` 前几次因 initializer/type 长度、三元 tuple、测试嵌套/对齐 FAIL；拆小型 helper/命名结构并修排版，未降低门槛。最终 `lint-final.log` 386 文件 0 violation。`make build`（build-final.log）、`make secret-scan`（secret.log）、`git diff --check` PASS。未运行全量 quality/quality-fast。
  - `scripts/visual_review_build_install.sh U03`（visual-install-final.log）PASS：最终不含列表试验的完整正常 Debug Simulator App 已覆盖安装 iPhone，签名和 entitlements 校验成功，无 uninstall/erase/清 Keychain。第一次中间安装结果由最终覆盖替代。
- Live 范围：最终候选原账户头像、关注列表及高通吧最新发布排序保留。中间候选真实帖子图片打开/关闭成功；最终覆盖安装/进程重启后重开同帖直接显示旧第 17–20 楼附近，继续滚到第 31 楼。仅检查缓存 manifest 元数据确认请求页 [0,2,3]（pn=0 响应第一页），位置页为 2；没有导出真实正文/凭证。最终停在该生产帖子，截图 `20261002-152338-iphone-live-cached-third-page.png`。未完成最终版本图片再往返、第三页后的完整返回/重启、Live 断网或 iPad 矩阵；不以 Fixture 冒充这些验收。
- 未解决风险/UNKNOWN：新 UITableView 的异高行初始恢复约偏移两楼，后续自适应行高改变已恢复目标的位置；持久化本身保存/读回的是同一 postID。当前首屏/刷新失败不丢内容，精确回到锚点的 UI 仍失败。图片字节离线持久化属于 U06，缓存缺早期页只恢复现存连续范围。
- 最小后续方案与前置条件：先定义并用失败 UI/几何样本验证“初始恢复事务”的结束条件：仅在新表首次自适应测量期间维持同一稳定行，用户开始拖动即结束；分页、图片完成和同实例更新不能重新开启恢复。需有针对异高首楼的组件回归再替代当前一次性 scrollToRow，不能继续叠固定延时/多次 scrollTo 或扩大到导航/图片重构。本轮已停止该问题的补丁尝试；U03 尚未达到阶段出口，U04 不启动。

## 2026-10-02 U02 — USER_ACCEPTED（删除提示、重进自动刷新）

- 用户明确回复“行，现在推送U02并进入U03”，批准当前已验收候选并授权提交、推送及仅继续 U03。生产代码自上一轮验收后未变，复用 SilentRefresh 最终构建/定向测试/双端 Live 结果；按 APPROVE_CURRENT_PHASE 只复核 diff、secret scan 与精确 staged 文件。下方“未提交/不进入 U03”为交付时历史状态，现由本次授权覆盖；完整提交与推送结果在 U03 记录补记。
- 用户明确否决“有新内容，点击更新”顶部提示，要求重进自动刷新或手动下拉刷新；本节覆盖下方 U02 历史记录中的提示行/新鲜命中零请求设计，仍不提交、不进入 U03。基线 HEAD 保持 `2d89ad00fa89a813d8288b565bc517eaead6c0ca`，现有未提交工作及用户 Prompt/skill 保留。
- 修改范围：ForumHomeStore/View 删除可见的新内容/缓存失败提示与按钮接线；Core 的 ForumHomeCacheAccess/CachedForumHomeRepository 删除不再调用的 revalidation helper；U02 状态/UI 测试、R05 fixture 的可选刷新序号、LaunchScenarioFactory、ADR-0030、交互/状态规格、本记录。共享 VirtualizedList/Pager/图片/签名/依赖本次不改。
- 状态：新 Store 先读缓存并恢复位置，再请求一次最新首屏（包括 60 秒内的缓存）；同 Store 重复 synchronize 不追加请求。在顶部自动应用并建立新分页链；深处静默暂存，滚回顶部时应用，旧后页不拼进新快照。下拉刷新直接请求；自动更新失败保持旧内容，手动失败沿用现有保留内容错误状态。无需顶部提示、替代入口或新 overlay。
- 定向证据（ignored `Artifacts/VisualReview/U02/SilentRefresh/`）：改动前 `baseline.xcresult` U02 8项/10次 PASS。新增新鲜/过期重进显示新帖测试 `red.xcresult` 两个参数均 FAIL，旧代码仍显示旧首帖。实现后 `green.xcresult` U02 + R05 Store 12项/15次 PASS，含新帖自动显示与持久化、同 Store 去重、深处保持/到顶应用、返回顶部磁盘记忆、失败保留、排序/账号/清理隔离及迟到排序。旧“零请求/等待按钮”断言按本次明确产品修改更新，缓存快照恢复与位置断言保留。
- `make lint` 初次因新增 Fake 参数对齐 FAIL（2条），仅修缩进后 `lint-final.log` 382文件 0 violation。`make secret-scan`、`git diff --check` PASS。iPhone `ui-iphone.xcresult` 深处/顶部两项 PASS，新自动刷新测试确认重进“刷新2”后，下拉 `swipeDown(.slow)` 未触发“刷新3”而 FAIL。测试改为顶部 15%→90% 的明确下拉手势（未改生产控件、未加重试/延时、未放宽刷新序号），`ui-pull.xcresult` 1/1 PASS（21.485s），真实观察刷新1→重进刷新2→下拉刷新3且提示不存在。失败包导出过早时 Info.plist 尚未生成而报错，完成后成功导出但无匹配附件；后续测试加 fixture 安全截图。iPad `ui-ipad.xcresult` 3/3 PASS、0 skipped（含更新序号、无提示、深处位置、回顶重进）。`make lint` 最终 lint-delivery.log 382文件0 violation；`make build`（build.log）PASS；`scripts/visual_review_build_install.sh U02`（visual-install.log）PASS，完整正常 Debug .app 覆盖安装 iPhone，并同包覆盖 iPad。签名/entitlements 通过，双端已安装 executable/debug dylib SHA256 与本次完整产物一致，未 uninstall/erase/清 Keychain。
- Live：双端正常账号头像、关注列表保留，实际进入高通吧，首屏已自动显示新列表；iPhone 最新发布、iPad 最新回复排序保留。目视确认标签栏下直接是吧规/置顶与帖子，无更新提示行、无原提示的占位空白。截图 `20261002-135841-iphone-live-no-banner.png`、`20261002-135941-ipad-live-no-banner.png` 位于 ignored SilentRefresh 目录。iPhone 留在前台吧首页，iPad 同样停在生产吧首页。
- 工具/未覆盖边界：CUA 切窗口时一次元素过期，重新读取后成功；两次 iPhone 坐标返回被 windowNotFound 拒绝（未送达 App），没有把这两次操作计为 Live 返回成功。自动重进/下拉刷新请求计数由双端 Fixture UI 证明，Live 只记录实际进入后的更新和无提示目视结果。本次未执行全量 quality/性能/旋转/真机/Live 断网；图片持久化仍留 U06。没有新动画、业务手势、overlay 或依赖，原虚拟列表保持。U02 未暂存/提交，不进入 U03，等待用户检查。

## 2026-10-02 U02 — READY_FOR_USER_VISUAL_REVIEW（顶部位置修订）

- 用户回归反馈：滑回吧首页顶部后退出重进仍恢复旧位置。按当前 U02 延续修复，不另起阶段、不提交。
- 根因（状态更新遗漏）：VirtualizedList 正常上报当前顶部行；ForumHomeStore.setScrollAnchor 只接受 thread，忽略顶部吧规行，旧 anchor 被 checkpoint 再次落盘。无吧规的首条帖子也应明确表示默认顶部，而不是保留强制恢复行身份。
- 本次最小差异：ForumHomeStore 将当前 presentation 第一行转换为 nil/top，忽略临时 nil 与未知行；VirtualizedList 仅补销毁时非空 viewport 检查，拒绝未布局临时表的虚假首行，不改变正常离场锚点或一次性恢复。Pager/图片/缓存策略不变。补 U02ForumCacheTests 参数化磁盘回归、U02ForumRefreshControlTests 零尺寸/有效尺寸销毁回归、U02ForumCacheSmokeTests 两轮滚回顶部再进入、交互规格及记录。
- 红绿证据（ignored `Artifacts/VisualReview/U02/TopPosition/`）：`red.xcresult` 新用例三个参数轮次全部 FAIL，观察旧锚点 140108/首条 140001 未被清除；同场其余7项 PASS。修正后 `green.xcresult` 缓存与 R05 Store 11项/13次执行全 PASS，涵盖有吧规/无吧规、临时 nil/未知行、磁盘重建仍为顶部且页面缓存保留、网络请求数不增加。`make lint` PASS（382文件0 violation）。
- 相邻回归与因果证据：`ui-iphone.xcresult` 顶部两轮 PASS、深处返回 FAIL；`ui-deep-evidence.xcresult` 即使等可见状态 5 秒仍 FAIL，截图确认回到顶部（目标行 frame 为零），不是断言过早。仅在 UITESTING 暂时记录布局与锚点，`trace.xcresult` 再现相同 FAIL：恢复 140007 后，一个 bounds=(0,0,0,0) 的临时表 dismantle 上报 rule 覆盖锚点；真实离场表 window 同样为空但 bounds 非零，应保留其回调。临时追踪代码已全部移除，未在真实账号运行。
- 直接红绿：`viewport-red.xcresult` 零尺寸 teardown 错误上报首行 [1] FAIL，有尺寸及刷新控件用例 PASS。加 `!bounds.isEmpty` 后 `unit-final.xcresult` 12项/15次执行 PASS、0 skipped，含两种 teardown、缓存全部用例及原 Cell 不提前清空/释放检查；未跑千条压力套件。最终 `lint-delivery.log` 382文件 0 violation。`ui-iphone-final.xcresult` 2/2 PASS（71.349s）、`ui-ipad-final.xcresult` 2/2 PASS，分别覆盖深处第二页重进/排序/刷新和两轮滑回顶部重进。`make build`（build-final.log）、`make secret-scan`（secret-final.log）、`git diff --check` PASS。`scripts/visual_review_build_install.sh U02` PASS（visual-install-final.log），同一正常 Debug 完整 .app 覆盖安装 iPad，签名/entitlements 校验通过。两台已安装 executable 和 debug dylib SHA256 与最终产物一致，无卸载/erase/清登录态。
- 本次 Live 验证：iPhone 原账户头像/关注列表可见，进入高通吧先恢复旧深处位置；AX Scroll Up 实际滚至吧规/置顶，返回首页再进入仍在顶部。随后正常 terminate/launch 并再次进入，仍恢复顶部、原最新发布排序保留。iPad 原账号与最新回复排序保留，完整 App 实际进入高通吧顶部。最终 iPhone 置前、双端停在生产吧首页。截图 `20261002-133251-iphone-live-top-reentry.png`、`20261002-133347-iphone-live-top-after-relaunch.png`、`20261002-133347-ipad-live-final.png` 均仅留 ignored TopPosition 目录。
- 本次修订无新增动画/手势/overlay/依赖；既有虚拟列表与缓存容量/TTL 不变。未重复全量 quality/压力/真机矩阵、未做 Live 断网；深处按稳定行恢复附近而非逐像素偏移。U02 未暂存/提交，等待本轮用户复验，不进入 U03。

- 目标与范围：用户批准 U01 并明确授权“现在提交并进入U02”。U01 已精确提交 `2d89ad00fa89a813d8288b565bc517eaead6c0ca`（`feat: remember forum sort preferences`），未 push；本轮仅 U02，以该真实 HEAD 为基线。原有未跟踪 Prompt/skill 保留。采用 COMMON 轻量验证，不建立额外准备/审计阶段，不进入 U03。
- 修改文件：AppCompositionRoot；Core/Models 的 ForumContentCache 与必要 Codable 领域字段；Core/Persistence/ContentPageCache；Core/TiebaAPI/CachedForumHomeRepository；SessionAuthContextProvider、ContentCacheAccountNamespace、SessionStore；ForumHomeStore/View；VirtualizedList 可选系统刷新接口；LaunchScenario/UITestLaunchContracts；U02ForumCacheTests、U02ForumRefreshControlTests、U02ForumCacheSmokeTests；ADR-0030、ADR-0008 相关例外、状态/交互规格及本记录。
- 关键设计/状态转换：保留导航路径内 registry 的现有实例，pop 后恢复有界页面 DTO/连续分页链/锚点；按账号本地槽位 + canonical ID/别名 + tab/category/sort + 页/游标 + 快照代次隔离。60 秒 fresh 零新增请求，stale 先读旧内容、一次后台检查；新首屏等待用户点击“有新内容”，失败保留旧内容；明确下拉走网络。清理 epoch、账号 revision 和 query 校验拒绝旧结果，锚点仅页面完成/离开/后台保存。无新增 API/Proto 或依赖锁修改。
- 动画、手势、overlay、依赖：无新自定义动画、业务 DragGesture、overlay、第三方依赖。为实际下拉刷新需求，仅给共享 VirtualizedList 增加默认关闭的 UIRefreshControl 回调；防并发、dismantle 取消及解绑有定向测试。原 diffable/UITableView/UIHostingConfiguration、Pager/MediaViewer/图片链路保留。
- 命令与结果（原始日志/xcresult 在 ignored `Artifacts/VisualReview/U02/`）：
  - 定向 Unit 首轮 `targeted.xcresult` 编译 FAIL：actor epoch 访问处的 `&&` autoclosure 隔离错误，拆成显式 await 后修正。
  - `targeted-2.xcresult`：26 PASS/1 FAIL，别名用例期待 ID 命中，但 name-only 基础 Fixture 没有返回 ID；补齐 U02 Fake 的 canonical ID 响应后通过，未弱化断言。
  - `targeted-3.xcresult` 编译 FAIL：新增 UI 场景缺少 UITestLaunchScenario 对应声明；补齐安全标签与场景声明后修正。
  - `xcodebuild test ... -only-test-configuration Unit` 定向 U02 缓存/刷新、U01 排序、R05 Store、Stage12 Session Store：`targeted-4.xcresult` 29/29 PASS、0 skipped。补充 query 续页校验和过期副本清理后的 `cache-final.xcresult` U02 8/8 PASS。
  - iPad 首轮 `ui-ipad.xcresult` FAIL：枚举所有复用行时，XCTest 对屏外 t140204 的 hittability 报 invalid activation point。测试改为先过滤非空且在视口中的行再查询 hittability；未改生产代码或降低返回位置断言。
  - iPhone 隔离设备 `UI Smoke` / U02ForumCacheSmokeTests：`ui-iphone.xcresult` 1/1 PASS（32.822s），第二页附近返回重进、无整页 loading、切排序、下拉刷新。
  - `make lint` 中间因函数/类型长度与长行 FAIL；仅拆分同文件 helper/extension 和换行，未降低门槛。最终 `lint-delivery.log` 382 文件 0 violation。
  - iPad 修正后的 `ui-ipad-2.xcresult` 同一短流程 1/1 PASS（34.771s）；最后 production query/清理代码均已包含。
  - `make build` PASS（build.log，普通 Debug 完整 Simulator 应用），SwiftProtobuf 锁未变。最终 `make lint`、`make secret-scan`、`git diff --check` PASS；未运行 test-unit/quality-fast/quality 全套。
  - `scripts/visual_review_build_install.sh U02` PASS（visual-install.log），codesign/Simulator entitlements 通过；同一正常 Debug .app 覆盖安装 iPad。两台已安装主文件/debug dylib SHA256 与最终产物相同。无 uninstall/erase/Keychain 清理，无 Fixture 启动参数。
  - Live：iPhone 原账号头像、关注列表与历史保留，已打开高通吧“最新发布”，AX Scroll Down 实际滚动，沙盒仅检查元数据确认缓存页码 [1,2]。初次坐标 drag 未移动、scroll API 报 windowNotFound，改用明确暴露的 AX Scroll Down 成功；随后 Mac 锁定，CUA 要求人工解锁；用户回复“已解锁”后继续以下检查。未记录真实正文到日志或仓库。
- Live 解锁后验证：iPhone 从已加载多页的高通吧返回首页，再进入恢复到原帖子附近；旧副本已过期，出现“有新内容，点击更新”，未替换当前阅读列表。退后台保存后 `simctl terminate` / 正常 `launch`，再次进入仍恢复同一帖子附近，原登录与最新发布排序保留。iPad 原账号关注列表和高通吧生产入口已目视确认，保留原最新回复排序。iPad 坐标返回操作两次被 CUA windowNotFound 拒绝（未送达 App）；双端返回重进验证仍有上述 Fixture UI 通过证据。最终 iPhone 前台停在缓存恢复位置及更新提示，iPad 停高通吧。截图为 `20261002-130029-iphone-live-retained-update.png`、`20261002-130134-iphone-live-restored-after-relaunch.png`、`20261002-130324-ipad-live-forum.png`（均在 ignored U02 目录，未提交）。本次解锁续验未修改生产代码/重建 App，只补记证据。
- 回归覆盖：磁盘重建后连续两页及锚点、fresh 零新增请求、stale 一次更新与主动应用、失败保留及显式刷新、排序/精华/账号/别名隔离、错误 query 游标拒绝、clear 迟到结果/checkpoint 不回填、账号槽位恢复/换凭据/新登录/失效、磁盘预算/损坏/7 天过期、刷新控件默认关闭/并发/解绑；U01/R05/Session 相关既有回归保留。
- 未覆盖/边界：未执行全量 quality/长列表压力矩阵；没有真实账号退出/清缓存操作，未切断设备真实网络。离线读取/更新失败保留以 Fake source 失败及磁盘重建的确定性测试为证，未冒充 Live 离线验收。图片磁盘持久化留待 U06，文本缓存不能宣称整页图片完全离线。缓存目录可被系统清理；重建按稳定行恢复附近位置，不承诺逐像素还原行内偏移。
- 下一阶段前置条件：完整 App 已安装并留在生产页面，等待用户 U02 视觉验收；U02 未暂存/提交，未进入 U03。后续提交与下一阶段仍需用户明确授权。

## 2026-10-02 U01 — USER_ACCEPTED

- 目标与范围：仅 U01；本机基线 HEAD `2849d89f4b342345350eb8cfa84c6ab105bb0b9b`。采用 NextIteration/COMMON 轻量验证；原有未跟踪 Prompts/skill 原样保留，不暂存/提交，不进入 U02。
- 修改文件：App/AppCompositionRoot.swift；Core/Models 的 AppSettings、ForumNavigation、新增 ForumSortPreferences；Core/Persistence/AppSettingsRepository；Forum 的 ForumHomeStore/View、ForumTabsView；SettingsStore/SettingsOptionsView；Tests/U01ForumSortMemoryTests、R05ForumStoreTests、Stage16BHistorySettingsProfileTests；UITests/U01ForumSortSmokeTests；Specs/STATE_MACHINES 与本记录。
- 关键设计/状态转换：场景原有设置恢复门槛与共享 SettingsStore 接线，创建 Store 和首请求使用每吧覆盖 → 全局默认 → 最新回复。UserDefaults 新增普通偏好键，name→ID 保守迁移且冲突不串吧；主动点选当前排序也记忆，恢复跟随全局移除覆盖。换 query 取消旧分页、清当前列表/anchor、pn=1，吧头/其他标签保留；旧响应不提交。新增 ForumQueryIdentity，仅预留内容查询身份，不建缓存。
- 动画、手势、overlay、依赖：均无新增；复用现有系统 Menu/Picker。VirtualizedList/Pager/MediaViewer、DesignSystem、图片模块、Android submodule、工程/依赖锁无修改。
- 执行命令与结果（证据目录 `Artifacts/VisualReview/U01/`，均本机忽略产物）：
  - Git status/diff/stat/HEAD 与相关规则/源码检查完成；Xcode 26.6，iOS 26.5 Simulator。
  - `xcodebuild test ... -only-test-configuration Unit -only-testing:TiebaLiteTests/R05ForumStoreTests` 基线 3 项 PASS（baseline.xcresult）。初次附加单方法映射 selector 未匹配，不计入基线；后续 R05ForumMappingTests 整类实际 4 项执行通过。
  - 先给 R05 迟到排序回归增加“切换期间不可显示旧 query 列表”断言：red-query-switch.xcresult FAIL（预期红灯），实施后同用例 PASS。
  - `xcodebuild test ...` 定向 U01ForumSortMemoryTests / R05ForumStoreTests / R05ForumMappingTests / Stage16BSettingsTests：18 项 PASS；随后增强迁移持久化及 registry 重建测试，U01 7 项 PASS（final-memory.xcresult）。合计 19 个不同逻辑测试覆盖，0 skipped。
  - `xcodebuild test ... -only-test-configuration 'UI Smoke' -only-testing:TiebaLiteUITests/U01ForumSortSmokeTests`：隔离 Tieba-Perf-Test iPhone 1/1 PASS（41.345s）；`test-without-building` 同 selector 于隔离 U01-Forum-Sort-iPad 1/1 PASS（42.471s）。只在 Fixture 设备执行自动化，未用账号设备跑测试。
  - `make lint` 初轮因 ForumHomeStore type_body_length 超限 FAIL；将排序方法移到同文件 extension 后 PASS，最终 375 文件 0 violation。未调整 lint 门槛。
  - `make build` PASS；截图发现默认排序 Picker 隐藏标题，补 LabeledContent 后 `make lint` / `make build` 再次 PASS（build-final.log），iPhone 正常 Live 设置页已目视确认标题。
  - `make secret-scan`、`git diff --check` PASS。未执行 test-unit/quality-fast/quality 全套。
  - `scripts/visual_review_build_install.sh U01` 初轮及标题修订后均 PASS，最终 Debug 完整 .app 已覆盖安装 iPhone；同一签名 .app 经 `simctl install` 安装 iPad。脚本的 codesign / Simulator entitlements 校验通过，两台已安装 executable/debug dylib 摘要与最终产物一致，无卸载/erase/清 Keychain。
  - 操作检查中的失败：新建隔离 iPad 首次缺少设备类型 12GB 后缀返回 146，查实际 devicetypes 后创建成功；开机前 get_app_container 返回 Shutdown，开机后正常；覆盖安装前后数据容器路径 cmp 返回 1（Simulator 重分配路径），不把路径变化当作数据丢失。iPhone Live 设置仍显示已登录和原浏览记录，iPad 原关注列表可见。
- 回归覆盖：持久化恢复、两吧独立、显式相同排序覆盖、全局/恢复跟随、name→ID 迁移与冲突、typed identity、首请求/registry 重建、旧分页/旧排序迟到、精华/分类互不污染、设置序列写入；UI 覆盖菜单实际结果、返回重进、切 Tab、设置入口和恢复跟随全局。
- 未解决风险/UNKNOWN：未跑全量压力/旋转/真机矩阵；未操作真实账号的退出或清缓存。偏好与内容/图片缓存分离有代码证据，本阶段不实现内容缓存。Live 双吧全局变更组合留给用户验收；最终默认排序标签只做增量 build + Live 目视复核，未重复整个 UI 测试。
- Live 手工结果：iPhone 高通吧由最新回复切到最新发布，观察结果变化；terminate/正常 relaunch 后重新进入，菜单仍勾选最新发布。最终 iPhone 前台、iPad 均停在高通吧排序菜单；capture 脚本截图为 `Artifacts/VisualReview/U01/*-iphone-live-sort-menu.png` 和 `*-ipad-live-sort-menu.png`。iPad 保留兼容默认最新回复，未修改其排序。
- 用户验收：2026-10-02 用户明确回复“可以，现在提交并进入U02”，批准 U01 并授权仅继续 U02。验收后生产代码未变化，复用上述构建/定向结果；提交前只复核 diff、secret scan 和精确 staged 清单。完整提交 SHA 在随后 U02 记录中补记。


- 2026-09-27 按用户纠正将最新已验收代码合入主分支：确认 origin/main 是候选祖先（0/17），本机 main 快进至 `82ef4e0` 并经 SSH 推送成功，无强推或历史重写。随后按用户要求为 README 增加四张已目视检查的 R13 Live 原始 PNG（动态、吧首页、表情编辑、搜索），不含账号/我的/私人消息页或本人头像昵称；未公开其余 Artifacts。截图字节与验收原件一致；首轮严格元数据检查因存在 EXIF 停止，复核 EXIF 仅色彩空间/图片尺寸后通过，无文本/GPS/设备身份元数据。图片路径、diff/secret 检查通过；仅文档与图片更新，不重复 App 测试/构建。

- 2026-09-27 v0.2.0-beta.1 = PUBLISHED_AND_VERIFIED：修复 `e479814`、发布源提交 `b8dc258` 已通过本机 SSH 推送；公开 GitHub Release ID 397563756，含新版真机 IPA 和 SHA256SUMS，两项远端大小/摘要均与本机一致。Release 标注新增功能、页面重制与未签名安装方式；正文及构建审计保留审核持续性 UNKNOWN。发布回执见 Docs/Audits/RELEASE_0_2_0_BETA_1.md。此次只补记文档，不改产物或标签；用户原有未跟踪文件原样保留。

- 2026-09-27 v0.2.0-beta.1 = RELEASE_PREPARED：显示名修复已提交 `e479814`；0.2.0/Build 2 真机 arm64 未签名 Release archive、实际包隔离与 ZIP/版本/架构/SHA 检查通过，IPA 6,349,822 bytes。定向 Unit 15项/18次、lint/build/secret/diff 通过，未重复完整长矩阵。功能及页面重制说明在 Docs/Releases/v0.2.0-beta.1.md，精确检查在 Docs/Audits/RELEASE_0_2_0_BETA_1.md。用户已完成 GitHub 网页登录；随后按授权使用 SSH 推送与网页发布，当前条目不冒充远端已完成。

- 2026-09-27 用户明确批准提交显示名修复、以本机 SSH 推送 GitHub 并发布新版 IPA。修复提交检查 R09 定向 15 项/18 次执行、lint/build/secret/diff 全通过。精确纳入修复与证据文件，用户原有未跟踪 Prompt/skill、私人 Artifacts 均排除；随后独立准备 v0.2.0-beta.1 Release 真机未签名包，发布成功与否以后续记录为准。

- 2026-09-27 发布候选 = LIVE_REPLY_USER_VERIFIED / MODERATION_RETENTION_PENDING：用户明确“这回发成功了”，截图可见新增第3楼（15:45）、文字和官方表情正常。仅确认本次发送及当前可见，风控根因和后续删除风险仍 UNKNOWN。私人图片保存在 ignored Artifacts/Audits/WriteCompatibility20260927/user-confirmed-live-reply.png。本轮只更新四份证据/进度文档并做 diff/secret 检查；未改代码/安装包、未重跑 Unit/build/UI、无 AI 发布/上传，无暂存/提交。R13 仍为已提交的 8aec6e4。

- 2026-09-27 用户验收的 R13 已精确提交 `8aec6e4`（release: prepare visual parity beta），未 push/tag；提交前定向 10 项/12 次 Unit、instructions/secret/lint/build/diff 通过，用户原有未跟踪文件保留。随后独立恢复发布问题：确认并补齐同账号公开资料 nameShow→AddPost/新帖字段链，27 项/30 次相关 Unit、lint/build/secret/networking-isolation/forbidden/diff 通过。红回归、一次测试编译/格式失败和安装时设备 Shutdown 均保留；恢复后两台完整 Live 候选覆盖安装且 hash 相符、无卸载/Keychain 清理、无真实发送/上传。`WRITE_MODERATION_CAUSE_UNKNOWN`：只修明确协议遗漏，没有证明此字段导致删帖；候选未暂存/提交，等待用户实际使用结果。完整范围与证据见 Docs/Audits/WRITE_MODERATION_COMPARISON.md 最新条目。无新手势/动画/overlay/依赖。

- 2026-09-27 用户最终批准 R13 并明确授权提交，随后恢复发帖风控排查。先精确提交已验收的 R13；此前全量/定向测试与 Live 证据沿用 R13_ACCEPTANCE.md，提交前只补必要检查，不重复长矩阵。后续发布问题单独处理，不推送、不自动发送真实回复。

- 2026-09-27 R13 = READY_FOR_USER_FINAL_ACCEPTANCE：用户补图确认断网刷新失败仍保留原列表，并明确“重试能恢复我试过了”，最后一项 Live 网络检查已补证。其余 Live 页面、六屏 Android 对照、用户确认的分页/横滑与 iPad full/narrow/full 结果见 R13_ACCEPTANCE.md；软件键盘通过断开 Simulator 硬件键盘连接恢复。完整/定向自动化、干净 Debug/Release/隔离证据沿用，历史失败保留；本轮仅更新三份记录，diff check 通过、暂存区为空，未重跑测试/构建或改 App。完整 Live 与登录保留，等待最终验收批准；未提交 R13、无 tag/push/IPA，发帖风控仍 DEFERRED_BY_USER。

- 2026-09-27 R12 已按用户授权提交 `60ea8d6`，未推送；R13 = IN_PROGRESS。执行最终集成、完整门禁和干净 checkout Debug/Release；发现并复现 iPad 我的空详情残留（三轮均失败），最小系统 NavigationStack 边界修正后三轮通过。旧调试输出、图片准备 shared、测试读取系统剪贴板阻塞及 Release Fixture 编译输入问题已按实际门禁证据修正。保留完整历史失败，详情见 `Docs/VisualParity/R13_ACCEPTANCE.md`。真实发布审核继续 DEFERRED_BY_USER；自动化仅 Fixture，不发送或 logout，不卸载/erase/清 Keychain；R13 尚未完成最终人工验收，不暂存/提交/tag/发布。

- 2026-09-27 R12 = USER_VISUALLY_APPROVED：用户接受居中标题并确认返回方块已修复，明确授权“现在提交，进入R13”。保持已验收候选，精确提交 R12 代码/测试/记录，用户原有 Prompt/skill 和私人 Artifacts 不纳入。沿用最终定向 Unit/UI 证据；提交前复核 lint/build/secret/diff。原 iPad 横屏详情残留继续待 R13 集成检查；发布审核仍 DEFERRED_BY_USER。下列旧记录保留为历史，不代表当前批准状态。

- 2026-09-27 R12 方块修订最终 = READY_FOR_USER_VISUAL_REVIEW：用户明确接受居中并确认问题修复，恢复 `.principal` 标题方案；只改首页/帖子两处 toolbar，原生返回手势保持。iPhone3/3（73.829s，包含三轮返回/取消/其他标签/标题固定）、iPad1/1（16.417s，竖屏标题固定）、lint 0/371、build/secret/diff通过。两台普通Live覆盖安装且主文件+dylib SHA一致，登录保留；iPhone留耐腐蚀艺术馆吧，iPad首页。详情在R12_NAVIGATION_BAR_REDESIGN.md末节、Artifacts/VisualReview/R12/BackButton；不实施UIKit备选，不再扩大修复，原iPad详情残留继续记录，无暂存/提交、不进入R13。

- 2026-09-27 R12 返回按钮方块修订 = STOPPED_WITH_OPEN_VISUAL_REGRESSION：完整 Live 录屏确认首页文字/帖子吧 chip 在导航栏转场中变形为 back item；两个对照（SwiftUI 稳定 ID、principal 标题位置）分别仍复现/造成居中布局回归，均已撤回，原 R12 tracked diff 与本轮备份 cmp 完全相同。保留三次返回功能 Smoke（两轮均通过，不能作为瞬态视觉通过）和录屏。恢复构建、lint 0/371、secret/diff通过；无新生产修复、无提交。下一步最小 UIKit 导航栏身份适配方案见 R12_NAVIGATION_BAR_REDESIGN.md，未实施；iPad详情残留仍独立待处理，不进入R13。

- 2026-09-27 R12 = READY_FOR_USER_VISUAL_REVIEW（有待定位 iPad 详情残留）：基线 9681d39；我的页接真实账户头像/统计，复用已证实账户元数据+Profile、已有 Loader，首页与帖子回复条共用；本人资料/主题/历史/设置/关于与平面行完成。19项定向Unit、iPhone3项Smoke、iPad4项Smoke、lint/build/secret/diff通过，迭代失败及两次转屏动画等待保留在R12_ACCEPTANCE.md。288保护文件与HEAD相同。两台完整正常Live覆盖安装、保留登录，真实头像/统计/资料入口已观察；iPhone前台我的，iPad横屏我的+本人资料，截图矩阵在Artifacts/VisualReview/R12/SCREENSHOTS.md。额外Live观察“已有帖子→横屏侧栏我的”时右侧残留旧帖子，点击本人头像可切换资料；未以旧构建判定来源、未改共享导航，保留待定位，不宣称全部行为无问题。无暂存/提交/推送，不进入R13，发布审核继续暂缓。

- 2026-09-25 R11 = USER_VISUALLY_APPROVED：用户确认“我看了都改好了”，授权提交 R11、先不进入 R12。本轮仅更新验收记录和精确提交；生产代码保持已验收候选，沿用下述通过的定向 Unit、共享列表/图片复用及 iPhone/iPad Smoke 证据。提交前 make build、lint（0 violations）、secret-scan、diff check 全部通过，日志在 Artifacts/VisualReview/R11/UserApproval/；未重复 Unit/UI 或更换 Simulator 页面。用户原有 Prompt/skill 未跟踪文件不纳入，私人截图/Simulator/凭证不纳入；不推送，不开始 R12，发布审核问题继续暂缓。此前记录保留为历史状态。

- 2026-09-25 R11 最新用户修订 = READY_FOR_USER_VISUAL_REVIEW：根底栏改按实际高度占位，修复末吧被挡；具体回复进入完整帖子并滚到对应一级楼，楼中楼只解析父楼、不打开二级。现有列表增加首次有效布局后一次性恢复锚点，修复零尺寸时过早消耗锚点的真实竞态；无列表/分页架构改写。34项相关Unit、10项锚点/Cell与图片复用回归通过（有重叠）；iPhone3项Smoke、iPad对应4项及横竖屏通过，lint/build/secret/diff通过。两台正常Live覆盖安装且主文件+debug dylib哈希一致，已实际确认普通消息带前文及楼中楼定位第6父楼；两台留在该父楼，iPhone前台。CUA拖动无效，Live末吧/上滚仍待手工复核，Fixture已通过。所有失败及证据见R11_NOTIFICATIONS.md最新节和Artifacts/VisualReview/R11/FullThreadAndBottom；未暂存/提交、不进入R12，发布问题继续暂缓。

- 2026-09-25 R11 用户点击区域修订 = READY_FOR_USER_VISUAL_REVIEW：原引用整行按钮连续3次实际打开第7楼，新增普通帖子路由Unit先红；现分为引用→正常帖子入口、正文→原准确回复定位。只改消息行/接入/消息route及Debug主题样本，225个App/Sources核对仅4文件变化，共享承载/Store/协议不动。17项相关Unit、iPhone2/2（86.146秒）、iPad2/2（95.473秒，含横竖屏及各3轮区分点击）、lint/build/secret/diff通过；初始失败/缩进lint失败保留。两台完整Live覆盖安装hash e55cfe99…一致、账号保留；iPhone真实同条引用打开首楼正文图片，上方回复打开第4楼，均成功返回。截图/命令见R11_NOTIFICATIONS.md修订节与Artifacts/VisualReview/R11/ClickTargets/。App留真实回复首屏，未暂存/提交、不进入R12，发布问题仍暂缓。

- 2026-09-25 前置工作已提交 `9c9d715`，未推送；R11 = READY_FOR_USER_VISUAL_REVIEW（Live中部停留待手动滚动）。真实回复/提到/未读接口、独立分页和消息导航已实现；29项定向Unit主轮、最终MIME修订后15项R11 Unit、iPhone/iPad各1短Smoke、lint/build/secret/diff通过，历史失败保留。两台完整正常Live覆盖安装，二进制SHA `b137ac5e…`一致，保留登录态；真实回复及主楼/楼中楼准确跳转已观察。“提到我的”实际为空，非空样式由隔离Fixture补证；真实未读为零，读后非零变零未Live验证；接口无等级字段不造数。CUA未移动Live列表，当前两端停回复首屏、iPhone前台；Fixture中部/两页/返回偏移已通过。所有文件、命令、截图及限制见R11_NOTIFICATIONS.md。R11未暂存/提交，不进入R12，发布删帖问题继续按用户要求暂缓。

- 2026-09-25 用户明确授权“先提交然后进入R11，发布bug先不修”。当前提交范围为Forum首栏内容返回及发布审计记录；沿用已执行的定向验证，iPad转屏自动化超时和既有静态规则失败继续保留。发布后删除问题标记DEFERRED_BY_USER，未宣称修复。提交后仅进入R11消息页，完成后等待人工验收，不自动提交R11或进入R12。

- 2026-09-25 发布问题补充 = SERVER_REMOVAL_USER_CONFIRMED / WRITE_MODERATION_CAUSE_UNKNOWN：用户确认同一账号在官方iOS贴吧/Android TiebaLite均可发布，本客户端所有新回复均收到系统删除通知，发送后编辑器停留。停止把问题仅当按钮/刷新故障处理；未修复、未确定删帖触发字段。本轮只检查源码并打开已有草稿观察，未发送/改草稿/改生产代码/改安装包，未提交；详细证据边界见WRITE_MODERATION_COMPARISON.md。

- 2026-09-25 用户报告主题回复因“涉嫌异常行为”被删除，发布审计 = WRITE_MODERATION_CAUSE_UNKNOWN。与 Android 锁定协议/UI 参考核对，11文件及两个发布方法一致；iOS确定差异为发送前资料获取、显示名遗漏及裁剪的客户端上下文，新帖另有HTTPS差异。回复默认UA/版本与原版相同，无应用层自动重发循环。不能用历史即时可见证明后续审核可靠，也未确认具体删除触发项或账号封禁。仅更新审计/API证据/状态；未改生产代码或安装包，零Live请求/发布，不提交、不进入R11，Forum返回候选保留。详见Docs/Audits/WRITE_MODERATION_COMPARISON.md；静态比较exit0，Unit/build未重跑。

- 2026-09-25 R10已提交3744d4b；用户新增吧首页首栏内容区右滑返回修复 = READY_FOR_USER_VISUAL_REVIEW（有保留的验证失败），不进入R11。原Fixture三次实际失败并记录Pager接管/系统content-pop失败；最小局部手势仲裁启用iOS26系统返回，非首栏仍分页，旧系统保留边缘返回。最终22项Unit、iPhone2项UI（含三次返回、其他栏、取消/位置）及既有Pager短回归通过；iPad三次返回通过，旧转屏UI等待空闲超时保留，手动转屏/标签正常。lint/build/secret/network/diff通过；forbidden命中未改的ComposerPhotoPreparation共享实例，隔离HEAD同样失败，未扩大修改。147保护文件hash不变。两台完整正常Live覆盖安装hash eb85c33e…一致，无卸载/清Keychain，停高通吧；Live右滑留用户手工检查。详见Docs/Audits/FORUM_CONTENT_BACK_GESTURE.md与ADR-0029，所有原始失败保留；本修复未暂存/提交。

- 2026-09-24 R10 = USER_VISUALLY_APPROVED：用户确认图片和表情均正常并明确授权提交。用户自行完成高通吧单图加表情主题回复，第14/15楼截图已存 ignored Artifacts/VisualReview/R10/UserApproval/user-confirmed-live-image-emoticon-reply.png；未采集原始响应，其他写入目标、多图Live发布/重试不扩大结论。AI零Live上传/发布。本轮仅更新记录、执行定向提交门禁及精确提交，不再改UI，不推送、不进入R11。提交门禁11 Unit/13次执行、iPhone2短UI（54.436秒）、lint/build/secret/diff通过；Unit曾被系统粘贴权限提示阻塞，拒绝读取外部剪贴板后原测试继续通过，证据保留。正常完整App已恢复到iPhone，SHA dadbb284…与用户验收候选一致；44保护文件hash未变。

- 2026-09-24 用户批准 R10 最小原生输入区域重设计后实施完成，READY_FOR_USER_VISUAL_REVIEW，未暂存/提交/进入R11。键盘与表情使用同一UITextView inputView，实际窗口宽度仅变化时同步，保留当前回调/选区/控制器和内联wire映射；撤下旧VStack面板。接入中多个UI失败完整保留（包括真实零宽证据），不归因UIKit缺陷；最终iPhone2/2（含原三轮开合/滚动与四图Mock失败重试）、iPad1/1（转屏/全宽/草稿）、9项定向Unit/11执行、lint/build/secret/diff通过。44保护文件hash未变。完整正常Live两台覆盖安装SHA dadbb284…一致，无卸载/清Keychain。iPhone原耐腐蚀艺术馆吧“最没用的非放射性元素是81”回复草稿已通过PhotosPicker选4张本地样图、点选笑眼/滑稽等多个内联表情，零自动上传/发送。证据 NativeInput/ 和 R10_ACCEPTANCE.md；所有历史失败/测试窗口appearance警告保留，真实上传仍UNKNOWN。

- 2026-09-24 R10用户反馈修订：正文plain token+分离预览根因确认，改为单UITextView内联附件，2项定向Unit/4次执行通过（光标/连续表情/删除/复制粘贴）；Live原帖已点选笑眼并实际显示在正文。面板初版3次复现错位，两次局部布局修正仍失败，按规则撤回失败布局，保留证据，停止第三补丁。R10=STOPPED_WITH_OPEN_PANEL_REGRESSION，提案见R10_EDITOR_LAYOUT_REDESIGN.md，尚未实施。lint/build/secret/diff通过；两台完整正常Debug覆盖安装hash9d82772e…一致，不卸载/清Keychain。CUA点击已恢复，iPhone停原耐腐蚀艺术馆吧“最没用的非放射性元素是81”回复编辑器，只有未发送笑眼草稿。无Live上传/发送，无暂存/提交，不进入R11；失败与截图在EditorRevision和R10_ACCEPTANCE.md。

- 2026-09-24 R09已提交1100788（feat: add text posting and replies），正常App的回复验收入口已去除，未推送。按用户授权进入R10；当前IMPLEMENTED_WAITING_LIVE_PRESENTATION：选图/顺序预览/上传重试/官方表情面板已实现，34定向Unit+最终6补充、iPhone1/iPad1短UI、lint/build/secret/network/diff通过。两台正常完整App已覆盖安装并核对hash44fee57e…；CUA连续windowNotFoundAtPosition导致最终Live四图停留尚未完成，已询问用户解锁并置前。自动化只Mock，零Live上传/发布。全部失败/限制/证据见R10_ACCEPTANCE.md。R10未暂存/提交，不进入R11。

- 2026-09-24 用户批准提交 R09 并进入 R10。已从正常应用移除 R09 验收入口，隔离自动化保留。提交检查 13 Unit、1 短 UI、lint/build/secret/diff 通过；首个 UI 配置拼写错误导致 exit 70，纠正后通过。R09 = USER_VISUALLY_APPROVED；真实主题回复已由用户验证，其余写入类型仍未单独 Live 验证。未自动发送、未推送。

- 2026-09-24 R09主题回复 = LIVE_THREAD_REPLY_USER_VERIFIED：用户明确“我确实发送成功了”，提供原帖新增第9楼截图（Artifacts/VisualReview/R09/WritePreflight/user-confirmed-live-thread-reply.png）。该成功来自用户自行发送；AI没有自动发布。本次仅更新记录，diff check通过；未重跑测试/构建。新帖/指定楼层/楼中楼未单独Live验证，不扩大结论。R09未暂存/提交，未进入R10。

- 2026-09-24 R09用户手动发送失败修订：确认账号元数据HTTP200/JSON/error_code0却带application/x-javascript，旧白名单拒绝后尚未进入发布；新增兼容并在完整App只读预检验证account-ready、零发布。复核原版完整拦截器链，纠正先前“multipart无需签名”的错误证据，补齐外层公共字段/签名/请求头；楼层目标映射不变。13项定向Unit、lint/build/secret/network/diff通过；临时诊断已移除，两台完整Live覆盖安装（hash230c885e…），iPhone停原“钢笔购买渠道”空白回复编辑器并显示屏幕键盘。READY_FOR_USER_VISUAL_REVIEW；真实发送仍待用户手动复核。完整失败与限制见R09_ACCEPTANCE.md最新修订，Artifacts/VisualReview/R09/WritePreflight。未暂存/提交，不进入R10。

- 2026-09-24 R08按用户批准提交58a1060（feat: add full subpost reading），未推送。R09 = READY_FOR_USER_VISUAL_REVIEW（第一道布局门禁）：文字新帖/主题/楼层/楼中楼编辑器、会话草稿与typed write repository已实现；11项Unit、iPhone3项/iPad1项定向UI、lint/build/secret/network/diff通过。iPad转屏丢编辑器根因修正为稳定AppSceneRoot持有同一系统sheet，列表/导航/图片/Session基础未改。两台完整Live覆盖安装，二进制hash8f2a9f91…一致、登录态保留；iPhone已实际打开高通吧真实帖回复编辑器，交付截图时回到同一帖子，保留当前操作位置；四布局/Mock结果/宽度变化截图在Artifacts/VisualReview/R09/。Live发布尚未执行，HTTPS最小请求兼容性待用户第二道门禁亲自发送验证；细节、全部失败与限制见R09_ACCEPTANCE.md。R09未暂存/提交，不进入R10。

- 2026-09-24 用户明确“可以了，提交R08进入R09”，R08 = USER_VISUALLY_APPROVED。提交前12项R08 Unit、iPhone原短Smoke 1/1、lint/build/secret/diff通过，证据Artifacts/VisualReview/R09/r08-approval-*。保留已记录资源缺口和历史失败；精确提交R08后按R09提示词开始文字编辑/发送状态，首轮停布局验收，自动化只用Mock，不执行Live发布。

- 2026-09-24 R08表情修订 = READY_FOR_USER_VISUAL_REVIEW（有资源缺口）：匿名核实用户第6楼全部三页77条，缺失为shoubai_emoji_face族未注册；加入原图可用的04/大笑、07/笑哭、60/赞同、71/滑稽、72/捂脸，全目录132图，保留原ID/名称优先级及所有renderer/列表。368/绝两处官方源404；6处[图片]是服务端type0原文，无图可恢复。新回归三例先红后绿，18 Unit、iPhone1/iPad1短Smoke、lint/build/secret/diff通过，45保护文件不变。两台完整正常Live覆盖安装，hash35109570…一致、5新资源在包内、登录态保留。iPhone打开同一原帖子，CUA滚动未生效，需手动到第6楼；前后/固定样本截图及完整缺口见R08_ACCEPTANCE.md最新修订和Artifacts/VisualReview/R08/Emoticons。未暂存/提交、不进入R09。

- 2026-09-24 R08 = READY_FOR_USER_VISUAL_REVIEW（Live中部停留待手工滑动）：PbFloor真实接口/领域映射、独立Store、平面VirtualizedList、分页去重/重试、资料子路径和只读回复intent已实现。10项定向Unit、iPhone1/iPad1短Smoke（含30条两页、返回位置、横竖屏）、lint/build/生成一致性/网络隔离/secret scan/diff通过；41共享基础文件hash不变。两台正常Debug完整R08已覆盖安装并核对二进制，无卸载/清Keychain；iPhone真实“6楼的回复”显示79条计数及真实作者、等级、回复对象，现停首屏，CUA滚动未生效，不冒充Live深滚动通过。截图Artifacts/VisualReview/R08/iphone-live-top.png及两台Fixture中部图；全部失败修正、文件范围和限制见R08_ACCEPTANCE.md。未暂存/提交R08，不进入R09。

- 2026-09-24 R07已提交4420ed0（feat: render official Tieba emoticons inline），未推送。按同一用户授权开始R08；范围与计划见R08_ACCEPTANCE.md。

- 2026-09-24 用户明确授权“提交R07进入R08”。R07提交前11项定向Unit、iPhone短Smoke 1/1、lint/build/secret scan/diff check通过；只提交R07拥有的代码、资源、测试及记录，保留用户Prompt/skill未跟踪文件。批准图为Artifacts/VisualReview/R07/FullEmoticons/iphone-live-floor7.png。

- 2026-09-24 用户查看127表情完整Live候选后反馈“可以了我看了，基本上表情都加载了”，R07 = USER_VISUALLY_APPROVED。当前差异保留，未暂存/提交，不进入R08；验收及全部执行证据见R07_ACCEPTANCE.md。

- 2026-09-24 R07全量修订：用户指出只补捂嘴笑不满足“其他表情”要求。本次补齐Android默认104及官方扩展23，共127原图379540字节和完整名称目录；微微一笑91经匿名Proto核实。新增全量回归先红后绿，11项定向Unit、iPhone/iPad各1短Smoke、lint/build/secret scan/diff通过。正常Debug完整Live已覆盖安装两台并核对127资源；原反馈帖第7楼实际已看到微微一笑（用户操作后读取，iphone-live-floor7.png）。36保护文件不变，未暂存/提交、不进入R08。READY_FOR_USER_VISUAL_REVIEW。详见R07_ACCEPTANCE.md最上方全量修订节及FullEmoticons证据目录。

- 2026-09-24 R07 用户反馈捂嘴笑缺失：匿名PBPage确认image_emoticon67/捂嘴笑；缺失本地原图和名称映射为根因，已补原PNG及映射（52张）。新增回归先红后绿，9项表情Unit、iPhone/iPad各1短Smoke、lint/build/secret scan/diff通过。完整Debug Live已覆盖安装两台、登录态保留；iPhone留在原反馈帖首屏，第5楼Live实拍因CUA滚动未生效仍待用户手动复核。正常/大字截图及所有失败记录见 R07_ACCEPTANCE.md 修订节和 Artifacts/VisualReview/R07/MissingEmoticons。READY_FOR_USER_VISUAL_REVIEW，未暂存/提交、不进入R08。

- 2026-09-23 R07获批续作 = READY_FOR_USER_VISUAL_REVIEW：完整恢复候选代码/51资源；实际A/B/C及原样例单击正常，native/AX frame一致。原失败根因是测试立即断言早于UIKit action执行，采用既有5秒可观察状态等待保留单击及精确断言，没有重写正常生产点击。18项Unit、iPhone3项定向UI、iPad1项短UI、lint/build/secret/diff通过；36保护文件SHA未变。两台覆盖安装完整正常Debug R07，已安装二进制SHA与本次构建一致（bf32c37e…），保留账号，无样本启动参数。iPhone停真实高通吧“8EE6拉完了”帖子，内联表情/两图/子回复可见；完整App保留官方表情与链接验收入口。正常/大字/复制及失败历史见R07_ACCEPTANCE.md与Artifacts/VisualReview/R07/Redesign/；CUA大字号开关与Live手工拖动未确认，相关结论采用定向UI证据。未暂存/提交、不进入R08。

- 2026-09-23 R06已按用户批准提交 `d1819c7`（feat: align thread floors media and subpost previews），未推送。R07已开始但状态为STOPPED_WITH_OPEN_REGRESSION：51资源/解析/原始node/复制/换行/复用等18项Unit通过；新原生富文本链接点击不派发动作，两项修正均未解决。按两次失败规则撤回所有本轮应用代码/资源/工程修改到R06，候选和结果完整保存在Artifacts/VisualReview/R07/；仅留下阶段记录与最小重设计方案 `R07_RICHTEXT_REDESIGN.md`。iPhone覆盖安装已验收R06正常应用，无卸载/清Keychain/Fixture参数；观察到完整Live高通吧。R07不提交、不宣称READY、不进入R08。

- 2026-09-23 用户确认“可以这次看起来没问题了，提交R06进入R07”。R06 = USER_VISUALLY_APPROVED，授权提交并开始 R07 官方表情；提交前定向 Unit 22项/5 suites、R06短UI 2/2（51.639s）、make lint/build通过，日志在 Artifacts/VisualReview/R07/r06-approval-*。历史失败与1000楼手工性能未采集项继续保留；未运行完整quality。后续手工交付继续使用保留账号的完整Live应用。

- 2026-09-23 R06用户修订 = READY_FOR_USER_VISUAL_REVIEW：应用日期统一中文（帖子/动态/吧内/历史，保留本地时区），吧chip移到系统返回键右侧固定toolbar，加入真实圆形吧头像并加宽，关闭iOS26叠加玻璃背景。帖子列表只移除原header项，楼层/footer ID和承载不变；Store仅新增一行分页缺图时保留论坛头像，22个共享列表/手势/图片/Session文件hash未变。Unit20项通过，最终短UI iPhone1/1（13.399s）/iPad1/1（14.215s）、lint/build/static/网络/凭据/diff通过；原始失败和修正见R06_ACCEPTANCE.md。两台正常App覆盖安装，无卸载/清Keychain/样本启动参数；iPhone已回到用户截图同一真实QLC帖子，日期“2026年9月20日 12:59”、高通吧头像可见；iPad停Live施德楼吧且旧日期中文可见。证据在Artifacts/VisualReview/R06/ToolbarRevision/。未暂存/提交、不进入R07；既有1000楼手工滚动缺口保留。

- 2026-09-23 用户要求人工验收必须展示保留账号登录态的完整应用，独立Fixture页不足以验收。已取消两台Debug样本启动参数，正常启动完整App；iPhone原关注吧列表已恢复，从高通吧打开真实帖子“低频能效p用没有”，头像/等级/正文/图片/回复条实际显示，停留供用户操作。截图 `Artifacts/VisualReview/R06/iphone-live-review.png`。未触碰凭证、未卸载或清Keychain；本次仅切换入口、记录，无生产代码修改/重跑测试/提交。后续人工交付优先完整Live应用，隔离Fixture仅用于自动化及补充证据。

- 2026-09-23 R05 已按用户授权提交 `50c5cb2`（feat: align forum home tabs and feed with TiebaLite），未推送。R06 = READY_FOR_USER_VISUAL_REVIEW：平面楼层/真实作者字段、连续图片原比例网格、前三条子回复和全部route、只读回复条已实现；保留既有虚拟列表/分页/anchor/图片系统。定向Unit主轮42项、图片补轮19项通过；iPhone Smoke 1/1（36.357s）、iPad 1/1（49.934s，含旋转），最终lint/build/static/网络/凭据/diff通过，23个保护文件hash未变。原1000楼Fixture已打开但CUA未确认连续快速滚动效果，该手工项仍待复核，不宣称性能无回退。两台正常Debug已覆盖安装，无卸载/清Keychain，停在4图+三条预览+查看全部样本，iPhone前台/iPad竖屏。完整失败、修正、截图和限制见 `Docs/VisualParity/R06_ACCEPTANCE.md`。R06未暂存/提交，不进入R07。

- 2026-09-23 用户完整检查后批准 R05，明确授权“提交05R进入06R”。R05 = USER_VISUALLY_APPROVED；提交前 R05/ThreadReader 定向 Unit 37 项/7 suites、lint/build/static/凭据扫描/diff 全通过。此前已记录的 Stage17 基线/连续旋转 XCTest 限制保留，不重跑长矩阵。批准截图在 Artifacts/VisualReview/R05/BottomInset/；后续按独立 R06 提示词实施。

- 2026-09-23 用户回复“我看了修好了”：R05 底部白条修复 = USER_VISUALLY_APPROVED。正常 App 两台覆盖安装且停在高通吧；iPhone 前台、iPad 横屏。停止追加测试/交互，未暂存/提交、未进入 R06。

- 2026-09-23 R05 底部白条修订：原短 Fixture 回归测得 34pt 空区；Forum/Thread destination 和 Forum Pager 页面内容延伸 bottom container 安全区后，iPhone 1/1（22.093s）、iPad 1/1（28.912s，横竖屏）通过 <=1pt 底边断言。lint/build/diff 通过，35 个保护文件 hash 未变。仅定向短回归，未重跑 Unit/quality/长矩阵；旧 Stage17/连续旋转验证限制继续保留。正常 Debug .app 已覆盖安装两台，无卸载/清 Keychain；详见 R05_NAVIGATION_REVISION.md 的底部白条章节。未暂存、未提交、未进入 R06。

- 2026-09-23 R05 阅读导航修订 = READY_FOR_USER_VISUAL_REVIEW（有已记录验证失败）。吧/帖子及后续阅读路径移除根底栏和占位；iPad 竖屏全宽栈、横屏保留三列，canonical 路径和共享承载不变。iPhone 三轮阅读及原深滚动/分类等 7 项 UI 通过；iPad 4 项既有 UI 通过，新增连续旋转 XCTest 两次失败（等待动画通知/方向条件），主线程采样为空闲；CUA 三轮实际旋转、帖子返回、键盘观察正常。Unit 23/25，两个 Stage17 39/40 失败在原 Shell 同样复现。lint/build/static/网络/凭据/diff 通过，35 保护文件 hash 相同。正常 App 已覆盖安装，无卸载/清 Keychain；两台停 Live 高通吧，iPad 竖屏、iPhone 前台。详见 Docs/VisualParity/R05_NAVIGATION_REVISION.md；未暂存、未提交、不进入 R06。

- 2026-09-23 R05 = READY_FOR_USER_VISUAL_REVIEW，未暂存/提交，未进入 R06。紧凑吧头、最新排序、精华/真实普通分类 Pager、独立 Store/分页/anchor、平面头像/多图帖子行已实现；共享列表/Pager/MediaViewer/图片/Session/根导航未改。定向 Unit 59 项及最后 MIME 修订后 10 项通过，iPhone Smoke 1/1（76.948s）、iPad 加强几何断言 Smoke 1/1（24.439s）；最终 lint/build/网络隔离/凭据扫描/diff 均通过，35 个受保护文件 SHA 一致。正常 Debug .app 已覆盖安装两台，无卸载/清 Keychain。iPhone 前台停 Live 高通吧“最新/按发帖时间”标签区；iPad 停同吧横向详情。Live 排序、精华、普通分类与真实头像/多图已观察，分类接口前两页各 30 条、无 Cookie。Live 深滚动及横滑仍待人工；完整命令、历史失败、截图与限制见 Docs/VisualParity/R05_ACCEPTANCE.md。

- R04 已按用户授权提交 `62c2b13`（feat: align dynamic feed with TiebaLite），未推送。R05 开始，基线 Forum/Pager Unit 28 项通过，R04 approval build exit 0；计划与边界见 R05_ACCEPTANCE.md。

- 2026-09-23 用户反馈“我看了确实修复了，那就提交R04进入R05”。R04 = USER_VISUALLY_APPROVED，授权精确提交当前阶段并开始 R05。头像 HTTP 边界和既有验证缺口不扩大；最终批准截图为 Artifacts/VisualReview/R04/AuthorAvatar/iphone-live-final.png。

- 2026-09-23 R04 动态作者头像缺口已修复，READY_FOR_USER_VISUAL_REVIEW。用户明确允许 `tb.himg.baidu.com/sys/portrait/item/` 原版 HTTP，决策见 ADR-0024；LegacyPortraitURL 按 Android 规则转换真实 portrait，描述符与 Loader 仅放行精确来源，ATS 只配置该域名。没有 Cookie、TLS 证书绕过或新图片系统。40 项相关 Unit/80 次执行通过，补充的 6 项头像测试/32 次执行通过，iPhone 原 R04 Smoke 1/1（59.337s）、lint/build/secret scan/diff 通过。两台 Debug App 已覆盖安装，未卸载/清 Keychain；iPhone Live 首屏已实际显示两个真实作者头像并停在多图动态页。Live 深滚动仍因 CUA 滚动未生效而待人工复核。全部原始失败和证据见 R04_AUTHOR_AVATAR.md；未暂存/提交、不进入 R05。

- R03 已由用户视觉批准并提交 `c4f1302`（feat: align home and followed forums with TiebaLite），未推送。按同一授权进入 R04；R04 平面动态行、完整媒体数据/三图预览、摘要/时间/吧 chip/真实计数已实现，未暂存/提交、不进入 R05。最终定向 Unit 43 项通过（final-verified-unit.xcresult），iPhone 单个 Smoke 1/1 通过（55.912s），make lint/build 和 diff 检查通过。44 个受保护文件 SHA-256 一致。完整执行与失败修正见 Docs/VisualParity/R04_ACCEPTANCE.md。
- R04 首轮历史验收缺口：Android 裸 portrait 的原 CDN 主机 HTTPS 证书名称不匹配，当时保持中性头像；已由上方用户批准的 HTTP 兼容修订解决，完整 HTTPS 用户头像与已验证吧图链路不变。Live 第二页及中部截图仍待用户手动滑动，未把隔离 Fixture 的三页通过冒充 Live。

- 2026-09-23 用户反馈“我看了可以了提交R03进入R04”。R03 = USER_VISUALLY_APPROVED，已授权提交并进入 R04；原始失败及工具未采集的中部截图限制保留在 R03_ACCEPTANCE.md。R02 已提交 4d45b62，未推送。

- 2026-09-23 用户查看 Simulator 后明确反馈“我看了r02现在没问题了，提交并进入r03”，R02 记为 `USER_VISUALLY_APPROVED`。此前自动化返回位置失败保留为已知记录，不改写为通过；用户已授权提交当前实现并进入 R03。

- 2026-09-23 用户批准 R02_ROOT_LIST_REDESIGN.md 最小承载修订。先在当前工作树重新证实原 root.mixed-media 主线程 LazySubviewPlacements / AttributeGraph 循环，再仅将动态列表接入既有 VirtualizedList。原卡死回归连续 3/3 通过，每次两轮第三页/四个根入口/返回位置/首行均验证。完整记录见 `Docs/VisualParity/R02_LIST_REDESIGN_ACCEPTANCE.md`。

- R02 提交前验证记录：`IMPLEMENTED_WITH_OPEN_VALIDATION_FAILURES`（2026-09-23）。25 个逻辑 Unit / 26 次执行（含已有图片复用）通过；make lint/build、git diff --check exit 0。iPad 修正测试滑动落点后可达第三页，但侧栏返回原可见行失败；既有帖子返回偏移测试在候选与本轮原基线上均失败，不能宣布全部修复。93 个受保护文件 SHA-256 与本轮基线相同，Row/图片任务逐字一致，无新增动画/手势/overlay/依赖。未暂存、未提交、未进入 R03/R04。
- 已覆盖安装两台 Debug .app 并截图、停动态页，iPhone 在前台且现有登录态保留；iPad 保持原未登录态。截图与逐项失败证据在 `Artifacts/VisualReview/R02/ListRedesign/`。本轮仅供用户手工检查，READY 不代表全部验证通过；不扩大到共享列表/根导航/图片系统。
- 上一轮诊断收尾（历史记录，非本轮重跑）：make quality-fast exit 0（402 个逻辑 Unit / 434 次执行，含图片复用与固定传输测试）、make build / git diff --check exit 0；当时新增深滚动 UI 仍失败，候选撤回记录见 R02_ROOT_FREEZE.md。当时两台停首页，截图为 Artifacts/VisualReview/R02/RootFreeze/*-restored-home.png。本轮未重复全量 Unit/quality-fast/quality。
- 此前验证（不覆盖此次卡死）：iPhone Shell Smoke 6/6；iPad 3/3，标题标识修正后 1/1 复核；make quality-fast exit 0（401 个逻辑 Unit / 433 次执行）；make build、git diff --check exit 0。首轮 lint、无障碍标识、R01 网络边界登记与 Simulator Shutdown 安装失败及修正均见 `Docs/VisualParity/R02_ACCEPTANCE.md`。
- 此前直接覆盖安装 iPhone/iPad，未卸载/erase/清 Keychain。四个入口截图保存在 `Artifacts/VisualReview/R02/`；当时 iPhone Live 登录态恢复，iPad 保持真实未登录态。完整页面整改、真实消息和本人资料仍为后续范围。

- 上一整改阶段：`R01 = USER_VISUALLY_APPROVED`（2026-09-23，用户视觉验收通过/未提交）。
- 仅补全公开用户/吧字段与共用头像、等级、细分割线、元数据、1–8 图网格、平面 skeleton；只在 Debug Gallery 展示。VirtualizedList、ThreadReader/ForumHome UITableView 承载、Pager、MediaViewer、gesture ownership 与原有业务 ID 无修改。
- 定向 Unit 48 个逻辑测试/57 次执行通过；FRS mapper 提取后的 8/8 定向回归通过；最终 make lint、make build、git diff --check exit 0。中途两次 lint 失败及修正、完整命令和日志见 `Docs/VisualParity/R01_ACCEPTANCE.md`，未运行全量 quality/UI smoke/Release。
- R01 验收时已覆盖安装 iPhone/iPad Debug App，没有卸载、erase、清 Keychain 或退出登录；两台当时停在 Component Gallery 的 Android parity section。截图 `Artifacts/VisualReview/R01/iphone-gallery.png`、`ipad-gallery.png` 均完整同屏展示全部要求样本。用户解锁后，将 Debug 总览最大宽度限制为 340 pt，解决 iPhone skeleton 底部遮挡；重新运行 make lint/build 均 exit 0（capture-lint.log、capture-build.log），再覆盖安装两台并完成截图。
- `AVATAR_HTTPS_TOKEN_SYNTHESIS = UNKNOWN`：Android 裸 portrait 只证实 HTTP 规则；只加载 API 自带的有效 HTTPS 头像，Gallery 为明确的本地展示样本，不冒充 Live 证据。
- 2026-09-23 重新启动 iPhone 并打开 Component Gallery，说明改动后用户回复“行可以”，确认 R01 视觉通过。验收当时仅更新三份文档，没有修改代码或重跑测试；其后用户另行授权进入 R02（见顶部）。

- 2026-09-04 公开源码决定：
  `PUBLIC_SOURCE_REPOSITORY = OWNER_APPROVED`；
  `ROOT_LICENSE = GPL-3.0-only`，仅覆盖项目作者有权许可的原创 iOS 代码；
  third-party/Generated Proto provenance、App Store、商标、服务条款和商业
  二进制分发权利仍为 `UNRESOLVED`。
- 2026-09-04 滚动锚点热修复打包/推送：
  `SCROLL_ANCHOR_HOTFIX = PUSHED_TO_GITHUB`；
  修复文件为 `Sources/InteractionKit/VirtualList/VirtualizedList.swift`，
  回归为 `Tests/Stage17AdaptiveLayoutTests.swift`。
  已执行 `make quality-fast`、`git diff --check`、secret scan、
  forbidden/static/networking/lint/build/unit 聚合门禁；新增
  `Releases/TiebaLite-0.1.0-build1-ios18-arm64-unsigned.ipa`
  作为未签名 arm64 真机 IPA，SHA-256
  `18e29c811a000240900b96cdcf15c050b0de32ce362748ec536ad0626a16464b`。
  源码与 IPA 已推送到 `origin/main`，修复提交为 `4839b79`。
- 整改前基础阶段：19B（本地 Beta Release Candidate 已完成）
- `PROJECT_STATUS = BETA_RELEASE_CANDIDATE`
- 状态：`PHASE_16A_SEARCH = COMPLETE`
- `PHASE_16 = COMPLETE`
- `PHASE_16B_HISTORY_SETTINGS_PROFILE = COMPLETE`
- `PHASE_17_IPADOS_ADAPTIVE_LAYOUT = COMPLETE`
- `PHASE_17_QUALITY_GATE = PASSED_STAGE_17F_REQUIRED_GATES`
- `PHASE_18 = COMPLETE`
- `PHASE_18_ACCESSIBILITY_PERFORMANCE_RESILIENCE = COMPLETE`
- `PHASE_18_QUALITY_GATE = PASSED_FULL_QUALITY`
- `PHASE_19 = COMPLETE`
- `PHASE_19A_PRODUCTION_IMAGE_PIPELINE = COMPLETE`
- `PHASE_19B_RELEASE_CANDIDATE = COMPLETE`
- `PHASE_19B_QUALITY_GATE = PASSED_BETA_WITH_ISOLATED_XCUITEST_TRANSIENT`
- `BROWSING_HISTORY = LOCAL_JSON_BETA_READY`
- `APP_SETTINGS = USERDEFAULTS_RUNTIME_UI_VERIFIED`
- `USER_PROFILE = ANONYMOUS_LIVE_PROTOCOL_RUNTIME_VERIFIED`
- `LIVE_FORUM_SEARCH = ANONYMOUS_FIRST_PAGE_RUNTIME_VERIFIED`
- `LIVE_THREAD_SEARCH = ANONYMOUS_SECOND_PAGE_RUNTIME_VERIFIED`
- 状态：`PHASE_15_LIVE_PAGINATION = COMPLETE`
- `PHASE_15_5_CORE_LIVE_INTEGRATION = COMPLETE`
- `PHASE_11 = COMPLETE`
- `PHASE_11_LIVE_READ_FLOW = COMPLETE`
- `LIVE_RECOMMENDATION = ACTIVE_SESSION_SECOND_PAGE_RUNTIME_VERIFIED`
- `LIVE_THREAD = ANONYMOUS_THREE_PAGE_RUNTIME_VERIFIED`
- `PHASE_12_SESSION_AND_LOGIN = COMPLETE`
- `SESSION_IMPLEMENTATION = BETA_READY`
- `SIMULATOR_KEYCHAIN_ENTITLEMENT = DETERMINISTIC_BUILD_GATE_VERIFIED`
- `KEYCHAIN_PROCESS_RESTART_RESTORE = RUNTIME_REVERIFIED`
- `AUTH_CONTEXT_RESTORE = RUNTIME_VERIFIED`
- `ACTIVE_SESSION_PROBE = RUNTIME_VERIFIED`
- `MANUAL_LOGOUT_RUNTIME = DEFERRED_BY_USER_CREDENTIAL_RETENTION`
- `LOGOUT_IMPLEMENTATION = DETERMINISTIC_TEST_VERIFIED`
- `PRODUCTION_EXPIRED_SIGNAL = NOT_RUNTIME_VERIFIED`
- `PHASE_13 = COMPLETE`
- `PHASE_13_FOLLOWED_FORUMS = COMPLETE`
- `PHASE_15_5_ACCEPTANCE_STANDARD = OPEN_SOURCE_BETA`
- `FOLLOWED_FORUMS_LOCAL_IMPLEMENTATION = BETA_READY`
- `FORUM_GUIDE_AUTHENTICATED_PROBE = HTTP_200_PROTO_18_RUNTIME_VERIFIED`
- `LIVE_FOLLOWED_FORUMS = ACTIVE_LEASE_PRODUCTION_RUNTIME_VERIFIED`
- `PHASE_15_THREAD_READING = COMPLETE`
- `THREAD_READER_CONTAINER = VIRTUALIZED_UITABLEVIEW_BETA`
- `THREAD_READER_LARGE_FIXTURE = LOCAL_5_PAGE_1000_FLOOR_BOUND_VERIFIED`
- `THREAD_READER_SWIFTUI_AB = ONE_DEBUG_OBSERVATION`
- `PHASE_14_FORUM_HOME = COMPLETE`
- `PHASE_14_FORUM_HOME_PERFORMANCE = COMPLETE`
- `FORUM_HOME_LIST = VIRTUALIZED_UITABLEVIEW_BETA`
- `FORUM_HOME_LARGE_FIXTURE = LOCAL_10_PAGE_1000_THREAD_BOUND_VERIFIED`
- `FORUM_HOME_FIXTURE = BETA_READY`
- `LIVE_FORUM_HOME = ANONYMOUS_FIRST_AND_NEXT_PAGE_RUNTIME_VERIFIED`
- `PHASE_15 = COMPLETE`
- `PHASE_14 = COMPLETE`
- `SESSION_SIGNED_IN_SEMANTICS = WEB_COMPLETION_CANDIDATE`
- `RESTORE_VALIDATION = STRUCTURAL_KEYCHAIN_ENVELOPE_VALIDATED`
- `RESTORED_SESSION_SERVER_ACCEPTANCE = RUNTIME_REVERIFIED_STAGE_15_5_AND_19B`
- 恢复时的本地判定只验证 Keychain envelope 结构；恢复出 active lease 后，
  阶段 15.5/19B 又以服务器成功响应独立复验了该会话的当时可用性。
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
- production live：`RECOMMENDATIONS_ACTIVE_SESSION_SECOND_PAGE_RUNTIME_VERIFIED`；
  `FOLLOWED_FORUMS_ACTIVE_LEASE_RUNTIME_VERIFIED`；
  `THREAD_ANONYMOUS_PBPAGE_THREE_PAGE_RUNTIME_VERIFIED`；
  `LIVE_IMAGES_RECOMMENDATION_FORUM_THREAD_VIEWER_RUNTIME_VERIFIED`
- 阶段 06：`PHASE_06_INTERACTION_SPIKES = SPIKE_ACCEPTED`
  （`OPEN_SOURCE_BETA` 范围；已由阶段 09 迁移为唯一生产交互基础）
- 阶段 06C-C：`DEFERRED_POST_BETA`
- 阶段 09 前置条件：`PHASE_09_PREREQUISITES_SATISFIED`
- 阶段 09：`PHASE_09_PRODUCTION_MEDIA_VIEWER_COMPLETE`
- 阶段 10：`PHASE_10_FIXTURE_VERTICAL_SLICE = COMPLETE`
- 阶段 11：`COMPLETE`（`OPEN_SOURCE_BETA`）
- 阶段 12：`COMPLETE`（`OPEN_SOURCE_BETA`）
- 阶段 13：`COMPLETE`（`OPEN_SOURCE_BETA`）
- 阶段 14/14P：`PHASE_14_FORUM_HOME = COMPLETE`；
  `PHASE_14_FORUM_HOME_PERFORMANCE = COMPLETE`
- 阶段 15：`PHASE_15_THREAD_READING = COMPLETE`；
  `PHASE_15_LIVE_PAGINATION = COMPLETE`
- 阶段 16：`COMPLETE`；`PHASE_16A_SEARCH = COMPLETE`；
  `PHASE_16B_HISTORY_SETTINGS_PROFILE = COMPLETE`
- 阶段 17：`PHASE_17_IPADOS_ADAPTIVE_LAYOUT = COMPLETE`；
  `PHASE_17_QUALITY_GATE = PASSED_STAGE_17F_REQUIRED_GATES`
- 阶段 18：`PHASE_18_ACCESSIBILITY_PERFORMANCE_RESILIENCE = COMPLETE`；
  `PHASE_18_QUALITY_GATE = PASSED_FULL_QUALITY`
- 阶段 19：`COMPLETE`；
  `PHASE_19A_PRODUCTION_IMAGE_PIPELINE = COMPLETE`；
  `PHASE_19B_RELEASE_CANDIDATE = COMPLETE`

## 阶段 19B 完成结果与停止点

阶段 19B 从提交 `55baab43dae829ef7e0000f929ab4b804403ac52`
开始，只做最终功能一致性、Release 隔离、分发权利边界说明和可重建性收尾：

- iPhone 保留现有 Keychain 会话的 Live 主链路通过：推荐非空、
  关注吧 18 个、真实吧首页/分页、长帖至少 55 楼、三张不同 Live
  图片 Viewer/缩放/旋转/返回、搜索失败后重试、历史/设置/资料和前后台。
  未执行 logout，未读取或记录凭据。
- iPad 确定性 Fixture/UI 覆盖推荐、吧首页、帖子、MediaViewer、搜索、
  历史/设置/资料和 regular/compact/旋转；本轮没有向 iPad Simulator
  复制真实 Keychain，因此不声称 iPad Live 账号链路。
- 阶段 18 同一生产承载上的 1000 帖/1000 楼和 Viewer 连续开关 10 次
  运行证据继续有效；本阶段 Unit 重验 1000/1000 稳定 ID、增量 snapshot、
  有界 cell 与复用污染隔离，最终 UI interaction 重验 Viewer 循环。
- 干净临时 checkout 未复制缓存、Keychain 或私有 `project.env`，通过
  doctor、generate、Debug build、Unit、Release build 和 release-isolation。公网
  GitHub submodule 首次初始化因 empty reply/超时失败，改用同一锁定
  SHA 的本地 clean Git 源完成；全新机器的首次依赖下载仍取决于外部网络。
- Release 默认仍为 Live Repository + URLSession + Keychain +
  `ProductionImageLoader`；已排除 Debug Probe/Lab、LaunchScenario/Harness/
  FakeSession/Mock HTTP、纯 Fixture Repository、1000 项实验入口、测试插件和
  Artifacts，并包含 AppIcon。
- 干净安装未登录首页的稳定 P1 已以红灯 UI 回归复现，根因为
  生产推荐需求 active AuthContext 但 App 组合边界未投影会话状态。
  修复后 UI 回归和网络隔离均通过，没有放宽 fail-closed。
- 会话 A →退出/过期 →会话 B 会复用旧推荐的稳定 P1 已关闭：
  Store 现按 active lease/Fixture/unavailable 作用域取消、递增 generation 并清理
  内容/分页/锚点，两条直接回归通过。
- Release 中 Pager 快照类型、debug environment key、观察者/计数器和
  input diagnostic 和 snapshot callback 的 P1 已关闭；生产手势/
  rendezvous/页面身份策略未改。
- 同一 active lease 下 iPad 投影重挂会误取消推荐请求的 P1 已以
  真实 App 包装层回归复现并关闭；重挂保持单请求，lease 替换仍主动
  取消旧 generation。
- 同一会话返回推荐列表的稳定跳位 P1 已关闭：两条用例在修复前
  分别独立 3/3 失败，根因是同 scope 重现时短暂销毁列表；删除该次
  多余置空后分别 3/3 通过，真正会话替换仍清理旧数据和 generation。
- 最终 Unit 为 379 个逻辑测试/403 次执行；iPhone smoke 28/28、
  interaction 15/15；iPad smoke 12/12、interaction 2/2；Release isolation
  通过。最终 `make quality` 聚合运行在 iPad smoke 的第二次
  `swipeUp` 遇到一次 XCTest `Synthesize event` 超时而非 0 退出；
  原用例随后独立 3/3、人工 full → narrow → full 正常、完整
  iPad smoke 12/12，其他套件全绿。按阶段 19B 明确的非稳定
  XCUITest 例外记为 `PASSED_BETA_WITH_ISOLATED_XCUITEST_TRANSIENT`，
  没有为此修改产品 UI，也不声称聚合命令输出了
  `Quality gate completed.`。
- 未发现剩余稳定可复现 P0/P1。`PROJECT_STATUS` 仅为
  `BETA_RELEASE_CANDIDATE`，不声称 `APP_STORE_READY`、
  `PRODUCTION_CERTIFIED` 或 `COMMERCIAL_DISTRIBUTION_CLEARED`；本任务后停止，
  没有开始新阶段。

完整证据与 Known Limitations 见
`Docs/Audits/PHASE19B_BETA_RELEASE_CANDIDATE.md`。

## 阶段 19A 完成结果与停止点

阶段 19A 从提交 `b1b50cd117ac950bf97678d641df615f4dfaf180`
开始，只接通已有推荐/FRS/帖子正文/唯一 MediaViewer 的图片路径，
没有进入阶段 19B：

- Production composition 从 fail-closed loader 切换到唯一
  `ProductionImageLoader`。独立匿名 URLSession 不读 AuthContext/Cookie，
  只消费 mapper 已证且通过 HTTPS validation 的有限候选。
- 列表候选按 `big_pic → dynamic_pic → src_pic → origin_pic`；PB type 3
  正文按 `big_cdn_src → big_src → dynamic → cdn_src → cdn_src_active →
  src → origin_src`，Viewer 优先 origin；type 20 只用 src。
- Loader 使用 24 MiB response 上限、120M source pixel 上限、96 MiB/
  256 项 decoded NSCache、32 MiB memory-only URLCache。ImageIO 按实际
  geometry × displayScale 下采样、处理 EXIF；fill 结果中心裁到 target box，
  极端长图最大解码边 8192。
- Recommendation/Forum 图片状态只属于 cell-local state，不改稳定 row ID
  或 diffable snapshot；Thread 继续使用既有六态，只有当前 request rendered
  才能发 MediaIntent；Viewer 仍复用唯一 Pager/zoom/pan 实现。
- iPhone Live 已观察推荐/FRS 真实缩略图、单图帖与八图帖正文、Viewer
  连续三张切换和 2.50× 双击缩放；连续打开关闭 5 次、前后台一次均正常。
  没有执行 logout、读取/记录凭据、保存资源 URL/响应或真实用户正文。
- 终审红测试复现并关闭 cancellation/typed-decode rendezvous 与极端长图
  fill 超 target 两项直接风险；修复后图片定向套件 54/54。
- 完整 Unit 376 个逻辑测试/400 次执行；iPhone smoke 28/28、
  interaction 15/15；iPad smoke 最终 12/12、interaction 2/2；
  Release isolation 和 `make quality-fast` 通过。
- iPad 首次 smoke 的唯一失败为既有组件画廊入口偶发
  `not hittable`；该用例独立 3/3，两次后续完整 iPad smoke 均 12/12，
  定性为 suite-state/hit-testing 波动，没有修改生产 UI。
- 最终 `make quality` 输出 `Quality gate completed.`；阶段 19A 标记
  `COMPLETE`，阶段 19 继续 `IN_PROGRESS`，19B 仍 `NOT_STARTED`。

### 阶段 19A 当前 Known Limitations

1. 头像 portrait token 没有已证安全 HTTPS 合成规则，继续使用统一占位。
2. 动态图片只保证可显示帧；不实现动画、full-resolution lease 或瓦片。
3. 未修改宿主网络设置做真实断网；确定性 offline Fixture 与 transport/
   decode/cancellation 回归已覆盖失败和重试，真实 CDN 断网分布保留发布前检查。
4. iPad Fixture 图片打开/关闭已自动化验证；无凭据 iPad 上未单独完成
   Live CDN 手工往返，不写成已验证。
5. memory-warning 清理路径未人工注入；本阶段不做跨 View in-flight
   请求合并、full-resolution lease 或精确内存曲线。
6. 所有候选 redirect 当前 fail closed；未来如需放宽必须先补运行证据。

## 阶段 18 当前结果与停止点

阶段 18 从提交 `9d4d4427c1e0f5e6854886762fcc16fd23d26a37`
开始，只收口已有只读主链路的无障碍、长列表、图片资源、
故障韧性、存储恢复与 Release 隔离，没有新增业务功能或进入阶段 19：

- ThreadReader/MediaViewer 图片现按稳定 MediaIntent 顺序读出
  “第 N 张，共 M 张”，打开提示为“打开图片查看器”。
  Viewer 装饰背景和可见页码不再与 Pager 暴露重复焦点；
  关闭/上一张/下一张仍为明确操作。
- Profile 装饰占位头像从无障碍树隐藏，用户名增加 heading；
  ForumHome 回复数读为“N 条回复”。
- `network.offline` 现在以 UITESTING-only fail-once Repository
  确定性展示首屏失败并在重试后恢复 Fixture；Mock HTTP 事件为空，
  Production 默认 Repository 选择不变。
- 新增设置未知值安全回退、MediaViewer 取消后迟到图片丢弃、
  以及真实 UITableView cell A→B 复用后旧异步结果不污染新行的回归。
- iPhone 17 Pro / iOS 26.5 Simulator 快速滚动 1000 帖 Fixture
  并跨过 page 1→2；快速滚动 1000 楼 Fixture 到约 302 楼并跨过
  200 楼分页边界，均无稳定卡死、白块、重复行或身份错乱。
  Unit 完整验证 10 页/1000 帖和 5 页/1000 楼的有界虚拟化。
- 三图 Viewer 切换、双击 2.50× 缩放、切图重置、连续开关 10 次、
  iPhone 横竖屏/前后台与 iPad Settings/Thread/Viewer/full→narrow→full
  简单检查均无明显残留、空白或重复呈现。
- 阶段 18 定向 Unit 29 个逻辑测试/30 次执行，直接 cell reuse
  1/1，定向 UI 2/2；最终全量 Unit 351 个逻辑测试/
  370 次执行，0 失败。
- 完整 `make quality` 通过：iPhone smoke 28/28、interaction 15/15；
  iPad smoke 12/12、interaction 2/2；Release isolation、`quality-fast`、
  secret scan、lint、diff check 与 Android clean 全部通过。
- 没有修改 `VirtualizedList`、Pager、Media zoom/gesture ownership、
  Session/Keychain、Live Endpoint 或分页协议；MediaViewer/Renderer 只修改
  无障碍投影。没有新增动画、手势、overlay、依赖或图片缓存。

### 阶段 18 Known Limitations

1. Simulator 无法可靠操作 VoiceOver；真机完整 VoiceOver、iOS 18.x、
   所有 iPad 型号和真实 Stage Manager 仍为发布前人工项。
2. 本阶段性能证据是 Beta 级快速滚动+确定性虚拟化测试，
   不是精确 FPS、能耗或 Time Profiler 认证。
3. Production 图片 loader 仍 fail-closed 且没有内存图片缓存；
   极端全尺寸图片压力和内存警告下的未来 cache 清理保留到相关功能存在后。
4. 真实 logout、全部服务端错误码、App Store entitlement 和公开分发许可
   仍是发布前项目，不阻塞阶段 18。

## 阶段 17 当前结果与停止点

阶段 17 从提交 `6e95bc8b17d0f9b5c788a34d6758145115b79620`
开始，只加固既有 iPhone/iPad 导航投影、虚拟列表 resize 与状态生命周期，
没有新增业务功能，也没有进入阶段 18：

- compact `TabView + NavigationStack` 与 regular 三列
  `NavigationSplitView` 继续共享一个 `AppNavigationStore`、route 集合和
  Feature Store registry；测试锁定 regular → compact → regular 后当前 Tab、
  Forum、Thread、Profile 与 Settings route 不变。
- SwiftUI 因 size-class/窗口投影替换 View 子树时，不再通过 View
  `onDisappear` 误取消 Store-owned 请求；只有 canonical route 真正移除时，
  registry 才取消并释放 Forum/Thread/Profile/Search Store。推荐、关注吧、
  ForumHome、ThreadReader 的确定性 rehost 回归均证明请求数保持 1。
- Forum/Thread/UserProfile 的历史展示 claim 归稳定 route Store 所有，避免
  resize 重新挂载时重复记录；正常新 route 仍开始新生命周期。
- `VirtualizedList` 对完全相同的稳定 ID/值不再重复 apply diffable snapshot；
  retained 值变化仍用 `reconfigureItems`，增删/重排仍走原增量 snapshot。
  dismantle 前记录当前顶部稳定业务 ID，用于 compact/regular 重建后的附近恢复；
  没有 `reloadData`，没有改变 threadID/postID identity 或分页。
- UITESTING-only 宿主以实际父容器宽度提供 full、约半宽和 320–390pt
  narrow 三个代表性 viewport；生产代码没有 `UIScreen`、设备型号或固定
  sidebar/detail 宽度分支。
- Stage 17 定向 Unit 9 个行为用例通过；全量 Unit 为 346 个逻辑测试、
  365 次执行、0 失败。iPhone 旋转/返回 1/1，iPad full → narrow → full、
  Settings split、MediaViewer 旋转关闭返回 3/3 均通过。
- 2026-08-31 在原 iPhone 17 Pro / iOS 26.5 Simulator 上覆装生产构建，
  保留并恢复原 Keychain 会话。Live 搜吧结果进入正确 ForumHome 并返回；
  Live 搜帖结果进入正确 ThreadReader，返回后关键词与结果仍保留。
  没有修改搜索代码、执行 logout 或读取/记录凭证，因此阶段 16A/16
  从运行证据 partial 提升为 complete。
- 原完整 `make quality` 的唯一失败是长帖图片按钮的
  XCUITest `Activation point invalid`。同一 iPad Simulator 上手工点击该图片、
  打开 MediaViewer、关闭并返回原帖全部正常；按钮 accessibility
  frame 非空且与 window 相交，无透明 overlay、sheet 或残留
  `fullScreenCover`。因此根因定性为 XCUITest suite-state/hit-testing
  isolation flake，不是稳定可复现的生产故障。
- 最终只修改 UI test/helper：每例终止并以固定 Fixture 重启 App、
  明确设置方向、等待根 sentinel，每次滚动后重新 query 按钮；
  只在重查后的按钮 frame 四边完整位于 container、window 和 app
  交集内、身份/尺寸稳定且无 overlay 时，才允许以该合法
  frame 中心 coordinate 作为 `isHittable` 假阴性回退。
- 最终证据：失败用例独立 5/5；与前序 regular/compact
  projection 用例组合 3/3（6 次执行）；iPad smoke 12/12；
  iPad interaction 2/2；`make release-isolation`、`make quality-fast`、
  `git diff --check` 和 Android submodule clean 检查全部通过。
  `quality-fast` 中全量 Unit 为 346 个逻辑测试、365 次执行、0 失败。
  按 17F 授权没有重复从头运行已在同一工作树通过的 iPhone
  smoke/interaction 或完整 `make quality`。本阶段现为 `COMPLETE`，
  仍未进入阶段 18。

### 阶段 17 Known Limitations

1. 未穷举全部 iPad 型号、全部精确 Split View 比例、iOS 18.x 或真机矩阵。
2. 测试宿主模拟了实际容器窄宽，但未自动拖动真实 Split View divider；真机
   Stage Manager/多窗口 resize 仍为发布前人工验证项。
3. MediaViewer 用例证明旋转、关闭与父 route/图片节点返回；
   `fullScreenCover` 按系统语义覆盖 UIWindow，不把子内容窄宽冒充真实
   Stage Manager presentation。
4. 真机 VoiceOver 保留到阶段 18；本阶段没有修改 Pager ownership、
   MediaViewer 手势或 ThreadContentRenderer 节点结构。
5. 17F 按用户授权只重跑受影响的 iPad smoke/interaction、
   Release isolation 和 `quality-fast`，没有重复从头执行已绿的
   iPhone 26 项 smoke、15 项 interaction 或完整 `make quality`。

## 阶段 16B 当前结果与停止点

阶段 16B 从提交 `95152b62bcc3f3083f954ec86d125221d845301a`
开始，只实现浏览历史、真实设置、基础用户资料与必要导航，
没有进入阶段 17：

- Production 历史为 actor 隔离的 Codable JSON，写到
  Application Support/TiebaLite，原子替换，默认上限 500。
- 成功 record/delete/clear 会推进 generation 并取消旧 load；确定性回归证明
  迟到的初始读取不能覆盖已发布的新历史。
  threadID/forumID/userID 去重，重访移到最前；只保存路由最小
  信息，不保存正文、URL、Cookie、credential 或完整响应。
- 只在 ForumHome/ThreadReader/UserProfile 成功展示后记录。记录/删除/
  清空失败可观察且保留旧数据；损坏 JSON 可先清空再重建。
  Fixture/UI Testing 使用独立内存 Repository。
- Settings 实现跟随系统/浅色/深色和小/标准/大正文，使用命名
  UserDefaults key 重启恢复。颜色方案由 AppSceneRoot 统一投影，正文
  通过 DesignSystem 令牌进入现有 Renderer；没有覆盖 Dynamic Type/
  Reduce Motion。设置也提供历史数量/系统确认清空、现有账户、
  版本/许可，运行模式只在 Debug 显示。
- 用户资料 route 仅以正 userID 作 identity，ThreadReader 作者是首个入口。
  Store 以一个 Task + generation 拒绝迟到用户，具备 loading/loaded/
  empty/failed/retry；Fixture 显示占位头像、名称、简介和统计。
- Android 证据锁定
  `POST https://tiebac.baidu.com/c/u/user/profile?cmd=303012&format=protobuf`
  的 `ProfileRequest/ProfileResponse`。iOS 匿名 multipart request 不读 Session/
  Keychain，mapper 仅白名单映射请求 identity 匹配的公开字段，
  显式排除 schema 中 BDUSS/passwd/IP 类字段。
- Profile request/response 使唯一 generated Proto 闭包由 156 增到 207
  文件；两次 clean generation 确定性一致。新 binary fixture 为合成数据，
  不是 live capture。
- `SettingsRoute` 新增 history/about/licenses 和 history content chain，
  仍使用现有 iPhone Tab/System NavigationStack 与 iPad SplitView。
  没有新根 Tab、fullScreenCover、自定义返回或动画。
- iPhone Fixture 的帖子 → 历史 → 重开/清空、深色+大正文、作者 →
  资料均有已执行的绿色 smoke。iPad 的 profile → Settings → history
  在同一 Fixture 会话中覆盖；横屏 regular-width 三列投影连续
  执行 3 次通过，不改生产导航。
- 2026-08-30 Debug-only anonymous UserProfile Probe 返回 HTTP 200、
  `application/octet-stream`、4475 bytes、Proto decode=true、
  display fields=11、typed error=none。Probe 不读 Keychain，不记录
  userID/名称/正文/完整响应。
- 最终质量证据：Unit 337/337、iPhone smoke 25/25、iPhone interaction
  15/15、iPad smoke 9/9、iPad interaction 2/2；`make quality-fast` 与
  完整 `make quality` 均通过。首轮 smoke 的屏外手势锚点和一次 601 行
  lint 失败均已在审计中保留，并以最小测试代码调整后重新全量验证。

### 阶段 16B Known Limitations

1. UserProfile 匿名 transport/decode/mapper 已在单一 iOS 26.5
   Simulator 受控验证；长期服务可用性、删除/私密用户和完整
   错误 taxonomy 仍未验证。
2. 用户头像仍是统一占位；用户帖子/关注/粉丝列表、写操作、云同步、
   搜索词历史和多账号历史分区未实现。
3. 阶段 16A 的原锁屏缺口已在阶段 17 用原登录 Simulator 补验，
   搜吧/搜帖结果导航与返回状态均通过，现为 `COMPLETE`。
4. 没有修改 `VirtualizedList`、ForumHome/ThreadReader UITableView 承载、
   Pager、MediaViewer 或 Renderer 核心节点结构。

## 阶段 16A 当前结果与停止点

阶段 16A 从提交 `3612c7b015a3c613319f739f15bf14a813f21bc4`
开始，只实现搜吧、搜帖、Fixture/Live Repository、结果导航与
证据明确的搜帖顺序分页，没有进入阶段 16B：

- 锁定 Android Hybrid 证据为匿名 HTTPS GET JSON：搜吧
  `/mo/q/search/forum?word=...`；搜帖
  `/mo/q/search/thread?word=...&pn=N&st=5&tt=1&ct=1&is_use_zonghe=1&cv=99.9.101`。
  两者都不是 Proto，`SearchSug` 联想没有实现，156-file Proto
  闭包不变；
- `SearchStore` 使用一个 Task + generation，新关键词取消旧请求，
  迟到结果不覆盖，空白关键词零请求，分页失败保留已有
  结果。forumID/threadID 首出现去重保序，没有随机 identity；
- thread 从 `pn=1` 起始，`has_more == 1` 时请求
  `pn+1`，响应必须精确匹配 `current_page`。forum 只做首屏，
  因 Android ViewModel 没有下一页调用而不猜参数；
- Debug-only 脱敏 Probe 观察到 forum HTTP 200/
  `application/json`/36555 bytes/decode=true/mapped=48；thread page 1
  为 200/59907 bytes/decode=true/mapped=20；page 2 为
  200/66555 bytes/decode=true/mapped=20/new=20，typed error 均为 none；
- 首次 in-app forum Probe 稳定暴露 `concern_num` 同时有
  JSON string/integer。依实际类型和 Android
  `ForumFuzzyMatchAdapter.getNonNullString` 仅放宽统计字段解码，
  并加入合成 mixed-type 回归；
- `RouteIdentity.search` 位于 recommendations root 的现有系统导航中。
  iPhone 搜吧→ForumHome→返回和搜帖→ThreadReader→返回
  Fixture 2/2 通过，iPad SearchView 与两类结果 1/1 通过；
  返回后关键词和结果保留；
- 真实 forum 搜索结果已进入现有 ForumHome。真实 thread
  首页与第二页已证明解码、映射与新增 ID；阶段 17 又在生产 App 中点击
  Live thread 结果进入现有 ThreadReader 并返回，关键词和结果保持。
  自动化的结果导航仍使用 Fixture/Mock，不访问 Live 网络。
- 阶段 16A 定向 Unit 9/9、全量 Unit 311/311、iPhone UI 2/2、
  iPad UI 1/1 通过；`make instructions`、`make secret-scan`、修正后
  `make lint`、`make quality-fast` 和 `git diff --check` 均通过。
  本轮没有新增根级 Tab/Sidebar 或修改 AppSceneRoot，按任务约束未运行
  完整 `make quality` / Pager/Media interaction。

### 阶段 16A Known Limitations

1. 搜吧下一页、搜帖 page 3+、rate limit、完整服务错误 taxonomy
   和 endpoint 长期稳定性仍为 `UNKNOWN`。
2. 阶段 16A 提交时，用户搜索、输入联想、搜索历史、吧内搜帖与阶段 16B
   均未实现；当前阶段 16B 已完成浏览历史、设置与基础资料。
3. Live 证据是单 iOS 26.5 Simulator 的开源 Beta smoke，
   不是真机、多地区或发布级稳定性矩阵。
4. Production 图片 loader 仍 disabled。本阶段没有修改
   `VirtualizedList`、ForumHome/ThreadReader 列表、Pager、MediaViewer、
   Renderer、Session/Keychain 或已验证的推荐/FRS/PBPage 协议。

## 阶段 15.6 当前结果与停止点

阶段 15.6 从提交 `9a8cec68096a722772419bc9926bd2146dfdb31a`
开始，只补齐 ThreadReader 与推荐的普通顺序 Live 分页，没有进入阶段 16：

- 锁定 Android PBPage 以首屏 `pn=0/pid=0`、后续
  `pn=current_page+1` 连续请求，每页以 wire `Page.has_more=0`
  作为 Android 已证 client stop signal / iOS wire terminal 合同，
  不设本地固定最大页。真实三页均为 1，服务端末页仍为
  `RUNTIME_UNKNOWN`。后续页必须精确响应
  requested `current_page`；
- 从 `ThreadInfo.pids` 排除全部累计 postID 与当前页 postID，
  取最后一个未见正值；无候选时依已证 Android fallback 发送
  `pid=0`。跨页按 postID first-wins 去重保序；`has_more=1`
  却无新稳定 postID 时保留旧楼层并进入可重试 no-progress failure；
- 公开长帖匿名 Live Probe 连续取得三页：HTTP 全部 200、
  MIME 全部 `application/octet-stream`、body 24893/16779/13805 bytes、
  Proto decode 全部成功、`current_page=1/2/3`、映射 17/15/15 楼、
  累计 45 个唯一 postID；第三页仍 `has_more=1`，证明本地两页
  硬帽已移除；
- Personalized 继续使用 active lease：首屏
  `load_type=1,pn=1`，后续 `load_type=2,pn=N`，
  `page_thread_count=11`。Store 以单 Task/generation/page 保护分页，tail-4
  Store-owned 预取，按 `ThreadInfo.id` first-wins 增量追加；下一页
  失败/取消保留旧内容，刷新拒绝迟到分页；
- 推荐 Live 第二页为 HTTP 200、`application/octet-stream`、72958
  bytes、Proto decode=true、mapped=12，相对首屏新增 12 个稳定 ID，
  typed outcome=success。响应没有服务端 terminal 字段；空页或
  duplicate-only 页停止是受测 client no-progress policy；
- Fixture 推荐连续三页，ThreadReader 连续五页聚合 77 楼；
  原 5×200/1000 楼 UITableView 虚拟化承载未修改且继续通过回归。
  最终 `make test-unit` 为 302 个逻辑测试、321 次执行、0 failed/
  0 skipped；iPhone 推荐/帖子两条分页主链路 2/2 通过；iPad
  帖子五页 1/1 通过，推荐三页在 XCUITest split-column 手势坐标
  根因修正后 1/1 通过。`make instructions`、`make secret-scan`、
  `make lint`（185 files/0 violations）、`make quality-fast` 均 exit 0。

### 阶段 15.6 Known Limitations

1. PBPage 三页运行证据只来自一个公开长帖，且本样本三页均
   `has_more=1`；真实末页、合法空页、删除/私密、倒序、跳楼与跨主题
   稳定性仍为 `UNKNOWN`。
2. Personalized 只运行验证 active-session 第二页；匿名稳定性、
   第三页及更后 live 稳定性、服务终止语义、限流与完整错误
   taxonomy 仍为 `UNKNOWN`。
3. 自动化完全使用 Fixture/Mock/FakeSession，不读真实 Keychain、不访问
   Live 服务。真实 smoke 只是单 Simulator 开源 Beta 证据。
4. 本轮未修改 `VirtualizedList`、ForumHome、Pager、MediaViewer、
   Renderer、Session/Keychain 或生产图片 loader。

## 阶段 15.5 当前结果与停止点

阶段 15.5 从阶段 14P 提交
`9f45b63f311f608239a9cda999e14fe07e52eb96` 开始，只收口启动会话恢复、
AuthContext/ProtectedDataLease 投影，以及推荐和关注吧的生产只读接线；没有进入
阶段 16：

- 根因不是 credential 内容、Cookie 选择或 lease 时序。tracked
  `Config/Shared.xcconfig` 对 Simulator 禁用了 code signing，正常生成的 App
  缺少 simulated `application-identifier` 和嵌入 entitlements；Simulator
  `securityd` 因此以 `-34018` fail closed。移除该 override 后，新增确定性
  `simulator-keychain-entitlement` 门禁检查本地签名、application identifier
  与 Mach-O `__entitlements`；
- `SessionStore` 只有在 Keychain restore 已安装或撤销唯一 credential owner
  后才发布 `isLaunchRestoreResolved`。App shell 在此之前只显示完整背景的启动
  loading，避免推荐页先于 restore 发出 active 请求并缓存失败；
- Production factory 的同一 `SessionAuthContextProvider` 同时服务于
  Keychain-backed `SessionStore`、`AppEnvironment.session`、推荐和关注吧
  Repository。两条 Repository 均在请求前取得 matching authorization，并在
  响应后复验同一 lease；signed-out 在 HTTP 前 fail closed，替换 lease 的迟到
  响应不能发布；
- 在保留原 Keychain item、没有卸载/清理/logout/重新登录的 iPhone 17 Pro /
  iOS 26.5 Simulator 上覆装并重启签名构建，Session 自动恢复为 `signedIn`
  且 AuthContext 为 active；
- active Personalized：HTTP 200、`application/octet-stream`、74924 bytes、
  Proto decode=true、mapped=12、typed outcome=success；Production 推荐页显示
  非空内容；
- ForumGuide：HTTP 200、`application/octet-stream`、9199 bytes、Proto
  decode=true、mapped=18、typed outcome=success；Production “我关注的吧”
  显示真实列表；切到推荐再返回没有重复登录提示；
- 上述 Probe/文档只记录 status、MIME、body 大小、decode、映射数量和 typed
  outcome。没有记录或保存 credential、Cookie header、请求体、响应正文、吧名、
  帖子正文或用户内容；自动化继续使用 FakeSession、Fixture 和 Mock HTTP。
- 最终 `make test-unit` 与 `make quality-fast` 均通过；289 个逻辑 Unit、308 次
  执行、0 failed/0 skipped。entitlement 门禁、secret scan、lint（182 个 Swift
  文件）、networking isolation、Debug build 和 `git diff --check` 均通过。
  App 启动壳额外以 Fixture 跑过 iPhone smoke 19/19、iPad smoke 6/6；未重复
  运行本轮禁止修改的 Pager/Media interaction 矩阵。

### 阶段 15.5 Known Limitations

1. 按用户保留现有 credential 的要求，本轮没有执行真实 logout；logout 的 lease
   revoke、Keychain delete 和 App-owned WebKit cleanup 仍只有确定性测试证据。
2. 当前 `signedIn` 仍是本地完整 credential/active lease 语义；服务器是否实际
   消费两个字段、最小 credential 子集、轮换与真实失效码仍为 `UNKNOWN`。
3. Personalized 本轮只验证 active-session 首屏；匿名稳定性、分页，以及登录后
   对已显示失败页的自动刷新未验证。signed-out 不触网，登录后可由现有“重试”
   重新加载。
4. ForumGuide response 没有分页字段；超过 Android 注释所述 200 项的完整性、
   空列表和真实 expired taxonomy 仍为 `UNKNOWN`。
5. 自动化没有访问 Live 服务或真实 Keychain；真实 smoke 是个人开源 Beta 的
   单 Simulator 受控观察，不是多账号、真机、App Store 或发布级安全矩阵。
6. Production Live 图片仍 disabled。阶段 14P/15 虚拟列表、Pager、
   MediaViewer 与 Renderer 均未修改。

下文阶段 11、12、13 的“当前结果”保留各阶段提交时的历史快照；其中关于
Production evidence-blocked、AuthContext 恢复失败和 ForumGuide 未发请求的结论，
已由本节 2026-08-09 的阶段 15.5 证据取代。

## 阶段 14P 当前结果与停止点

阶段 14P 从阶段 15 完成提交
`c63a3c5065271bfc3ee6279ed3f79edc7aada9b4` 开始，只加固 Forum Home
长列表，没有进入阶段 16：

- 只有一个顶层 `VirtualizedList`，直接复用阶段 15 已验证且本轮
  未修改的 `UITableView + UITableViewDiffableDataSource +
  UIHostingConfiguration`。顶层 Row 为 header、retained status、section、
  每个 thread 和单一 pagination footer/empty，不存在嵌套纵向列表；
- Proto mapper 预计算摘要/媒体证据，Store 投影 `ForumThreadRowModel`。
  UI identity 统一为稳定 `threadID`，wire `itemID` 只保留为证据字段；
  RowKind 为 top/plainText/singleMedia/multiMedia/video，标题最多 2 行、
  摘要最多 5 行、媒体占位最多 3 个，没有新图片管线；
- Store 以一个 Task、递增 generation、route/page 与 tail-4 prefetch
  做下一页门禁。分页按 threadID first-wins 去重并保序，追加
  只插入新 ID；失败保留旧 rows 并重试同一 page，route 替换拒绝
  迟到下一页；
- Production 只使用已有 FRS：首屏 `pn=1/load_type=1`，后续页
  `pn=N/load_type=2`。无凭证 Probe 的第二页为 HTTP 200、
  `application/octet-stream`、156269 bytes、decode=true；首屏 13 条
  追加 30 条后聚合 43 条，typed error 为 none。
  `thread_id_list + ThreadList` 仍未启用；
- Debug-only 大吧 Fixture 固定 10 页×100 条，混合置顶/文字/单媒体/
  多媒体/视频证据，可对指定页 fail-once。确定性组件测试从
  100 增量到 1000 条，前缀保持、去重、snapshot 只增量变更，
  Cell 创建/存活数有界且发生复用；
- iPhone Debug Lab 实际到达 `items=1000 page=10 has-more=false`，中部
  thread 990424 打开并返回后原可见 rows 990422～990425 保持；iPad
  快速滚动到 200 条/第 2 页，`SWIFT_OPTIMIZATION_LEVEL=-O` 的近 Release
  Lab 快速滚动到 300 条/第 3 页，均未见稳定卡顿、持续白块或错页；
- 最终 Unit 为 284 个逻辑测试/303 次执行，iPhone smoke 19/19；iPad
  Forum 流程修复测试滚动容器后两次定向 1/1 通过。完整 iPad smoke
  一次为 5/6，仅余 MediaViewer close 视觉存在但 XCUITest not hittable
  的非稳定测试波动；`make quality-fast` 通过。共享 `VirtualizedList`
  未修改，因此按阶段约定未重复完整 `make quality`。

### 阶段 14P Known Limitations

1. Live 只对一个固定公开吧验证首屏和一页顺序下一页；
   第三页及更后页只有 Android 静态证据和合成 Fixture，没有另称
   完整 live 运行证据。
2. `thread_id_list + ThreadList`、dynamic tab、sort 变体、完整错误
   taxonomy 和限流行为仍为 `UNKNOWN`，Production 不猜请求。
3. 没有新建图片 loader/cache/downsampling；媒体列表只显示尺寸稳定
   的本地占位。
4. 性能验收是个人开源 Beta 的 Simulator/近 Release 手工观察，
   不是精确 FPS、Instruments 长期基准、真机或全系统版本矩阵。
5. 完整 iPad smoke 留有一次 MediaViewer close hit-testing 的 XCUITest
   波动；同一 Forum 流程两次定向复验以及套件内另外两个 MediaViewer
   测试均通过，当前没有稳定生产回归，本轮没有越界修改 MediaViewer。

## 阶段 15 当前结果与停止点

阶段 15 从阶段 14 提交
`bf0a0884bcda44aab1a159b756e45d41f0d3c367` 开始，完成只读帖子分页、
楼层/楼中楼呈现与 ThreadReader 长列表虚拟化，没有进入阶段 14P 或阶段 16：

- 匿名 PBPage 首屏与第二页均为 HTTP 200、Proto 解码成功；首屏含首楼和
  16 个普通楼层，第二页含 15 个普通楼层，共观察到 60 条内联楼中楼。
  Probe 只保留 HTTP/MIME/body 大小/decode/count/typed error，不记录 threadID、
  标题、用户内容、Cookie、请求体或响应正文；
- Store 使用一个 Task、递增 generation、页级 in-flight guard 和稳定 postID
  去重。Fixture 两页由 17 个顶层 post 增量追加到 32 个唯一 post，失败保留
  旧楼层并显示重试，取消和迟到响应不覆盖当前状态；
- 原 `ScrollView + LazyVStack` 的真实可变高度楼层首次滚动稳定卡住；同一
  Fixture/Store/nav 下固定 120pt 文本 Row 的一次隔离 1/1 通过。最终生产页
  只有一个 `UITableView + UITableViewDiffableDataSource +
  UIHostingConfiguration`，顶层项为 header、firstPost、post 和单一分页 footer；
- Debug-only 5×200 Fixture 依次得到 200/400/600/800/1000 个唯一楼层，
  请求序列为 `0,2,3,4,5`。component test 验证 diffable 增量 snapshot、
  1000/500/1 楼跳转、cell 数量有界、发生复用且 teardown 后 weak table 释放；
- 手工检查在无凭证 iPhone Air / iOS 26.5 Simulator 上用 Debug 和
  `SWIFT_OPTIMIZATION_LEVEL=-O` 构建各完成连续 5 次系统向下滚动，首屏可立即
  滚动，未再现数秒主线程卡死、白块、遮挡或错页。期间发现并修复了
  `didEndDisplaying` 过早清空 hosting content 造成的回弹空白 Cell，清理改在
  `prepareForReuse`，并以修复前失败、修复后通过的生命周期回归锁定。

阶段 15 定向 Unit 为 15/15。完整 Unit 为 275 个逻辑测试、294 次执行；
iPhone smoke 19/19、interaction 15/15，iPad smoke 6/6、interaction 2/2。
`make quality-fast` 首轮仅因新增 `PBPageDomainMapper.swift` 未列入精确
GeneratedProtobuf import allowlist 而失败；收紧脚本为单文件、单 import、
禁止副作用后，`make networking-isolation` 与 `make quality-fast` 通过。
最终 `make quality` 退出 0，并输出 `Quality gate completed.`。最终结果包：

- Unit：`Artifacts/TestResults/20260806-100432-13175-unit.xcresult`
- iPhone smoke：`Artifacts/TestResults/20260806-100503-13542-ui-smoke.xcresult`
- iPhone interaction：
  `Artifacts/TestResults/20260806-101617-14657-ui-interaction.xcresult`
- iPad smoke：
  `Artifacts/TestResults/20260806-104821-16949-ui-smoke-ipad.xcresult`
- iPad interaction：
  `Artifacts/TestResults/20260806-105328-17396-ui-interaction-ipad.xcresult`

## 阶段 15 Known Limitations

1. SwiftUI A/B 和手工滚动只在 iOS 26.5 Simulator 各作一次确定性观察，
   不是 iOS 18、真机或统计性能基准。
2. 未做 50 页、长期 Instruments、内存警告或单个极端超长富媒体楼层矩阵。
3. 1000 楼 Fixture 图片为固定小图，不覆盖 full-resolution Live 图片压力；
   Production Live 图片 loader 仍 disabled。
4. 领域层仍持有 1000 个 Sendable 值对象；已验证的是 Cell/host 生命周期有界，
   不是数据库或领域对象流式驱逐。
5. 完整楼中楼页面与 PB Floor 分页未实现；阶段 15 只显示 PBPage 已返回的少量
   内联预览和“查看全部 N 条回复”提示。
6. 该阶段当时未修改 ForumHome；后续阶段 14P 已完成 1000 条主题、
   虚拟化与顺序 FRS 增量分页。`thread_id_list + ThreadList` 仍因
   Proto/运行证据不足而未启用。

## 阶段 15 变更边界

- 新增动画、业务手势、overlay、第三方依赖：无。
- Pager、MediaViewer、MediaZoomImageView、ThreadContentRenderer 核心：无修改。
- ForumHomeView、ForumHomeStore、FRS 分页：无修改。
- 自动化：Fixture/Mock-only；长帖 Lab 与 Live PBPage Probe 均为 Debug-only，
  Release isolation 通过。
- 用户登录凭证：未读取、未清除、未写入日志或 Git；完整门禁使用独立无凭证
  Simulator，结束后已恢复原 `project.env` UDID。
- Android submodule：只读且 clean，锁定
  `5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`。
- 阶段 16：`NOT_STARTED`，本轮停止。

## 阶段 14 历史结果（阶段 14P 前）

本节保留阶段 14 首屏验收快照；其 itemID identity、无分页与
长列表限制已由上文阶段 14P 结果取代。

阶段 14 从阶段 13 提交
`b6090a19c95fb720f24415975dc43e7729cae1df` 开始，完成吧首页和吧内帖子
首屏，没有进入分页或阶段 15：

- 新建 `ForumHomeRepository` 领域边界、Fixture/Live 实现、
  `ForumHomeStore` 与 `ForumHomeView`。页面显示吧名、简介、已证统计、
  置顶/普通主题，并处理 initial loading、loaded、empty、failure、
  retry 和 retained refresh；
- `ForumRoute` 保留可选正 `forumID` 和已校验 `forumName`，deep link
  仅有名称时不猜 ID。列表用 `ThreadInfo.id` 作 item identity，使用
  `threadId` 打开现有 ThreadReader；
- Store 只持一个 Task 和递增 generation。新 forum 取消旧请求，迟到
  结果不得覆盖新 route，取消不显示普通错误，同 route View 更新不
  重复发请求；
- App 根 registry 在 Forum → ThreadReader → pop 期间复用同一 Store 和
  scroll anchor。iPhone Fixture smoke 实测打开中间帖子后返回，位置在
  12pt 容差内；iPad 使用同一业务状态；
- FRS 依锁定 Android reference 实现为
  `POST https://tiebac.baidu.com/c/f/frs/page?cmd=301001`，请求/响应
  为 `FrsPageRequest/FrsPageResponse`。Proto 闭包由 136 扩至 156 个文件，
  两次 clean generation 与 tracked output 一致；
- 固定公开测试吧在无凭证 iPhone/iPad Simulator 均得到 HTTP 200、
  `application/octet-stream`、Proto decode 成功和 13 条主题。最终 iPhone
  复验为 55,996 bytes、`typed-error=none`、`outcome=success`；没有
  保存 raw body 或用户内容。

阶段 14 定向 Unit 12/12；完整 Unit 260 个逻辑测试/279 次执行。
iPhone smoke 18/18、interaction 15/15、iPad smoke 5/5、interaction 2/2
全部通过。`make quality-fast` 和因共享导航接入而执行的完整
`make quality` 均通过；完整门禁输出 `Quality gate completed.`。

## 阶段 14 Known Limitations

1. 只验证匿名首屏。`thread_id_list + ThreadList`、下一页、动态 tab、
   sort 变体、限流与完整 FRS 错误 taxonomy 未验证，分页留待阶段 15。
2. Live 运行只检查一个固定公开吧，不证明所有吧、所有主题或服务端
   字段长期稳定。Production 例外仅适用匿名首屏，失效时 fail closed。
3. 未实现 live 吧头像加载；当前显示统一占位。Fixture 三个吧有独立
   帖子 identity，但简介文案共用一份合成描述。
4. Xcode 26 `simctl io` 不再提供手工 rotate 命令；横竖屏由 iPad
   XCUITest orientation/regular-compact 用例和先前的 Simulator 视觉检查覆盖。
5. Live 吧主题会形成正确 ThreadRoute 并进入现有 ThreadReader；阶段 14 验收时
   Production Live Thread 仍 evidence-blocked，后来由阶段 15 的匿名 PBPage
   两页证据收窄。真实帖子正文不属于阶段 14 本身的完成证据。
6. 阶段 11、12、13 原有状态保持不变；本阶段没有解决 AuthContext
   恢复问题，也没有使用或清除真实登录凭证。

## 阶段 14 变更边界

- 新增动画、手势、overlay、fullScreenCover、依赖：无。
- Pager、MediaViewer、MediaZoomImageView、ThreadContentRenderer、InteractionKit：
  无修改。
- 实时网络：仅 Debug-only 固定公开吧少量匿名 Probe；自动化始终
  Fixture/FakeSession/Mock HTTP。
- 敏感数据：没有 Cookie、BDUSS、STOKEN、账号、请求体、响应正文或
  用户内容进入日志、fixture、文档、测试或 Git。
- Android submodule：只读且 clean。
- 阶段 15：`NOT_STARTED`，本轮停止。

## 阶段 13 当前结果与停止点

阶段 13 从阶段 12 提交
`4f2c055a2fd01c78db6f413f30c87e568c3717ed` 开始，只实现“我关注的吧”
和稳定 `ForumRoute`，没有进入吧首页、吧内帖子列表或阶段 14：

- 锁定 Android Home 权威路径仍是不可接入的明文 HTTP form/
  ForceLogin 分页链。同 commit 的 HTTPS Proto `forumGuide` 没有 Home
  caller，因此只作为受控 Probe 候选；ForumGuide 两个 root 的 58-file
  closure 与旧集合合并为 136 个 generated Swift 文件，两次 clean
  generation 与 tracked output 一致；
- `ForumGuideProtocol` 锁定 HTTPS path/query、`sort_type=2`、
  `call_from=0`、multipart data/file 和 response mapper。Android 最终 wire
  仍包含 common/sign interceptor；iOS 当前只实验由 matching
  `ProtectedDataLease` 授权的 BDUSS/STOKEN-only unsigned subset，没有伪称
  与 Android 精确一致；
- 领域列表使用 positive Int64 `forumID` 作为稳定的本地候选身份，
  名称经已批准 `ForumRoute` 校验后进入现有系统导航。阶段 14
  目的地只显示“暂未开放”，不伪造吧首页或帖子数据；
- `FollowedForumsStore` 投影 signed-out、signing-in、expired、initial
  loading、loaded、empty、initial failure、retained refreshing/failure；单一
  Task + generation 防止替换请求的旧响应覆盖。取消不显示普通错误，
  且只有明确 typed expiry 才会撤销进程 lease 并进入 expired；
- Fixture/UITesting 使用 FakeSession、Fixture Repository 和 Mock HTTP，不读
  系统 Keychain，不访问 live。iPhone 已覆盖未登录引导、fixture 列表、
  ForumRoute、返回和 Tab 状态；iPad 已覆盖 fixture 列表和 regular/compact
  投影。

2026-08-05 在保留用户登录环境的 iPhone 17 Pro / iOS 26.5
Simulator 上，macOS 解锁后仅终止并重启 App 进程，未执行卸载、
logout、Keychain/WebKit 清理或重新登录。当前构建仍投影“会话保存失败”，
因而 ForumGuide Probe 按设计保持 disabled，没有发出请求，也没有可报告的
HTTP/MIME/body/decode/item count。这不证明凭证已被删除，只证明本次
构建无法恢复可用 AuthContext。Production 因此回退为
`EvidenceBlockedFollowedForumsRepository`，不会绕过 Probe 自动发送凭证；
本阶段如实保持 `RUNTIME_EVIDENCE_PARTIAL`。

阶段 13 定向 Unit 为 13 个逻辑测试，包含一条修复前编译失败、修复后
13/13 的 Production evidence-blocked 回归。iPhone 原始 smoke 首轮暴露
5 个稳定失败：登录按钮 accessibility identifier 被状态容器继承覆盖、
列表容器 ID 被 root 容器投影、以及设置入口被新 Debug 行挤出首屏。
最小修正后原 5 项 5/5，完整 iPhone smoke 17/17、iPad smoke 5/5
均通过。完整 quality 结果见阶段审计。

## 阶段 13 Known Limitations

1. 真实 authenticated ForumGuide 请求未发出，因此 endpoint 的服务器
   接受性、MIME、正常 body、真实数量、identity 稳定性与错误 taxonomy
   仍为 `UNKNOWN`；Production 保持 evidence-blocked。
2. 当前凭证恢复失败的根因未经证明；为遵守用户保留凭证的要求，
   本阶段没有重新登录、覆盖或清除会话。
3. Android 实际候选 wire 含 common/sign interceptor；iOS 的两字段
   unsigned subset 只有本地/Mock 证据，不应为追求成功而猜测或复制设备
   telemetry。
4. Proto candidate response 没有分页字段，Android 注释只声明最多
   200 项；无法宣称超大关注列表完整。
5. 真实过期码仍未锁定；普通错误保守地显示为可重试加载失败。
   若未来获得明确 expiry，当前“保留 Keychain、只撤销 lease”语义在
   重启后缺少 durable expired marker，可能再度投影 signed-in。
6. 吧头像使用统一占位；没有新建图片缓存、下采样或 live image loader。

## 阶段 13 变更边界

- 新增动画、手势、overlay、fullScreenCover、依赖：无。
- Pager、MediaViewer、Renderer、InteractionKit：无修改。
- 吧首页/吧内帖子：未实现；`ForumRoute` 仅进入明确未开放页。
- 真实网络：本阶段没有发出 ForumGuide 请求；Production fail closed。
- 敏感数据：没有 Cookie/凭证值、账号、请求体、原始响应或用户关注
  内容进入日志、fixture、文档、测试或 Git。
- Android submodule：只读且保持 clean。
- 阶段 14：`NOT_STARTED`，本轮停止。

## 阶段 12 当前结果与停止点

阶段 12 从阶段 11 提交
`2221793302250edcd0cdde591b0f92dfbc22db46` 开始，只实现登录与 Session
基础，不进入关注吧、评论、回复、发帖、签到、点赞或阶段 13：

- 用户在始终可见的 `WKWebView` 中自行输入账号、密码和验证码；App 不读取
  DOM、不自动填表，也不保存密码。完成页和两个候选 Cookie 字段严格来自锁定
  Android reference；不移植 Android 的明文 HTTP 私有登录接口；
- Keychain 只保存 `BDUSS` 与 `STOKEN` 两个 opaque String，使用单一
  Generic Password、versioned envelope、`WhenUnlockedThisDeviceOnly` 且不
  同步 iCloud。日志、测试、文档和 Git 均不包含字段值；
- `SessionStore` 提供 `signedOut/signingIn/signedIn/expired/failed`，并以内部
  `signingOut` 表示清理进行中。restore/login 只保留一个 Task 和递增
  generation；旧完成不能覆盖新状态；授权 lease 在 logout/expired 时先撤销；
- logout 实现按“撤销进程授权 → 删除 Keychain → 请求清理 App-owned
  nonpersistent WebKit store 并等待回调”执行；即使 Keychain 删除失败仍会尝试
  WebKit 清理，Keychain 删除失败进入可重试错误。WebKit 清理 API 不返回错误，
  因而不能声称其失败重试已被验证。Fixture/UITesting 使用 Fake store、fixture
  auth provider 与 nil login URL，不读取真实 Keychain 或账号；
- Production Recommendations/ThreadReader 继续 fail closed；阶段 12 的 Debug
  Probe 不把阶段 11 提升为 COMPLETE，也不接关注吧或 PBPage production。

2026-08-04 的真实运行观察：用户在 iPhone 17 Pro / iOS 26.5 Simulator 的
本机签名 Debug App 中完成可见网页登录，App 进入 `signedIn`；终止 App 进程并
重新启动后仍由系统 Keychain 恢复为 `signedIn`。用户显式触发的一次受控
Personalized Debug Probe 得到 HTTP 200、`application/octet-stream`、83924
bytes、Proto decode 成功、12 个映射条目、`outcome=success`。这些指标不证明
服务端实际消费了 credential，也不证明字段最小性、过期 taxonomy 或 Production
Live Repository 已验证。

用户随后明确要求保留登录凭证以便下次使用，因此没有执行真实 logout，也没有
清理 Keychain、卸载登录 App 或删除登录 Simulator。真实 logout 后再次启动为
`NOT_RUN/DEFERRED_BY_USER_CREDENTIAL_RETENTION`；确定性 logout 测试不能替代
该运行证据，所以阶段 12 如实保持 `RUNTIME_EVIDENCE_PARTIAL`。完整质量门禁在
独立、无凭证的 iPhone Air Simulator 上运行，未触碰上述登录容器。门禁后曾
再次终止并启动登录 App，但 macOS 锁屏阻止了额外可访问性标签读取；此前已完成
的进程重启恢复证据保持有效，该额外观察不写成通过。

阶段 12 定向 Unit 为 19/19；登录 URL/端口/Cookie 选择策略回归为 3/3；设置页
大字体导航回归为 1/1。最终完整 Unit 为 235 个逻辑测试/254 次执行，0 failed/0 skipped；
iPhone smoke 16/16、iPhone interaction 15/15、iPad smoke 5/5、iPad
interaction 2/2 均通过，Release isolation 通过，`make quality` exit 0 并输出
`Quality gate completed.`。首次完整质量运行曾有 1 个大字体 smoke 失败：新增
账号 section 后原图库按钮在屏外且测试未滚动；测试改为滚动到可点击元素，定向
1/1 和随后完整 iPhone smoke 16/16 均通过。

## 阶段 12 Known Limitations

1. 真实 logout、Keychain 删除、App-owned WebKit data 清理及 logout 后重启未
   运行，按用户保留凭证要求延期；实现仅由确定性 Fake/backend 测试验证。
2. 启动恢复只检查 versioned Keychain envelope 结构完整；没有已证轻量服务器
   validator，过期 credential 可能暂时投影为 `signedIn`。
3. `signedIn` 表示可见 Web 完成、候选 credential 原子写入并签发当前进程
   lease，不等于服务端确认账号有效、字段最小或阶段 11 Live 已解锁。
4. 真实服务器过期错误码、Cookie 轮换、host-only 与显式 Domain 差异、多账号、
   TBS、PBPage 和关注吧仍为 `UNKNOWN`。
5. 未做真机、App Store entitlement、发布级隐私/安全审计；ADR-0007 的 crash
   journal、cleanup ledger 与受保护缓存 aggregate 延至 post-Beta。
6. macOS 锁屏阻止了最终质量门禁后的额外 UI 标签复核；没有因此退出、卸载、
   重装或清除登录凭证。

## 阶段 12 变更边界

- 新增动画：无。
- 新增手势、Pager、MediaViewer、Renderer：无修改。
- 新增 overlay/fullScreenCover：无；仅由 App 根持有一个系统登录 sheet。
- 新增依赖：无。
- Live 网络：仅用户显式触发的一次 Debug-only、脱敏 Probe；Production live
  读取仍 fail closed，自动化测试不访问贴吧服务器。
- 敏感数据：没有密码、Cookie 值、账号、完整请求体或响应正文进入日志、fixture、
  文档、测试结果或 Git。
- Android submodule：只读且保持 clean。
- 阶段 13：`NOT_STARTED`，本轮停止。

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
7. 此处阶段 08 当时的公开分发阻塞结论，已由 2026-09-04 项目负责人批准
   公开源码仓库的决定部分取代；Android reference/Proto 文件级 provenance、
   App Store 和商业二进制分发权利仍未清理。
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
