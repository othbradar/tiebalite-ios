# R09 文字发帖与回复

状态：USER_VISUALLY_APPROVED。用户已确认真实主题回复成功，并于 2026-09-24 明确授权提交 R09、进入 R10；其余写入类型未单独 Live 验证。

## 范围与实现

四个入口：吧首页新帖（选填标题、正文）、帖子底部回复主题、楼层回复、完整楼中楼回复选中作者。共用系统 sheet 和平面 TextEditor，目标吧/用户/两行引用明确、细分割线、系统键盘安全区、无图片/表情面板。新增 Core TextComposeTarget/Draft/Receipt/Failure、TextWriteProtocol/AccountProtocol/LiveTextWriteRepository，Feature Composer Store/View/Service；原 Feature 只接入入口和成功回调。PBPage 额外透传真实 forum.id，分页保留，缺失时禁用发送。没有猜测 ID、设备指纹或风控字段。

发送状态 idle→sending→failure/receipt；一个任务句柄，发送中禁止编辑、重复提交和交互关闭；正文/目标/租约在开始时捕获，再次校验租约阻断旧账号请求/迟到成功。失败不清草稿，不自动重试；结果不明明确提示先检查帖子，避免重复。成功必须含服务端正数 ID，关闭后仅调用当前 Forum/Thread/Subposts Store 的既有 reload/refresh，无乐观虚构楼层。草稿只保留本次进程/账号租约内存，取消后同目标恢复，账号变化清除，不写磁盘或日志。

UI参考 `c5f1125f` ReplyPage/ReplyViewModel/AddPostRepository；供给的 Android 截图只有01–06，无独立 ReplyPage 截图，已查看05/06及源码，不能声称精确像素比对缺失截图。协议仍锁定5545326b，AddPost闭包由216扩至234，18新生成文件；未修改Android submodule。请求完整证据、安全传输未验证项见 Specs/API_EVIDENCE.md 的 R09 节，决策见 ADR-0027。

## 必要修正与失败记录

- 第一次 `make generate` 失败：manifest已扩展而tracked生成物尚未更新；运行受控生成脚本后两次干净生成逐字节一致。没有手改生成Swift。
- composer-unit-initial：编译失败，Core和Feature新文件同名 TextComposeTargets；Feature重命名为ThreadComposeTarget。unit-second：生成字段拼写vcodeMd5及SwiftProtobuf.Decoder与Swift.Decoder重名；改为真实字段和显式Swift.Decoder后unit-third的9项通过。
- phone-initial 命令报告成功但实际执行0项（工程生成与启动先后）；明确不算验证。工程生成完成后phone-check实际2项都因查找正文失败。AX证据显示编辑器可见，但root composer.screen标识覆盖了子TextView标识；改成明确的children:contain容器后正文、标题和目标可单独访问，没有扩大点击范围或改选择行为。
- phone-verified：真实吧发帖入口/返回位置、主题/楼层/楼中楼入口和取消草稿恢复2项通过；四布局截图已取得，但Mock失败断言未通过。AX显示外层Toggle行点击后值仍0、实际上模拟成功；测试改为单击真实子Switch并断言值1，不改生产发送逻辑。
- iPad初轮转屏后编辑器不可见；ipad-observed在5秒可观察条件等待后仍失败，截图和AX显示已回组件画廊。确认为目的页局部sheet随compact/regular投影替换而消失。因此R09编辑会话及系统sheet由稳定AppSceneRoot注入的同一TextComposerService持有，Feature仅提交目标与成功回调；没有修改AppShell投影或导航树。ipad-stable初次编译因MainActor Identifiable隔离不匹配失败，改为不可变session值的普通Identifiable；ipad-final已通过转屏/输入保持/键盘和取消19.489s。
- lint初轮11条为参数对齐、嵌套DTO、空字符串/计数/长行/闭包格式；后续四条对齐及一处多空行修正。最终0 violations。Secret scan第一次把源码表达式authorization.stoken误判为20字token常量；遵循现有Personalized的局部sessionToken写法，扫描规则未放宽，无真实凭据。

## 已执行的检查

Artifacts/VisualReview/R09 保存所有命令日志与xcresult。R08批准前12Unit/原Smoke1/lint/build/secret/diff通过。R09只跑Composer/Write的定向Unit及短UI，没有全部Unit、完整quality或Pager/Media长矩阵。

- unit-third：9项/3suite通过；unit-verified：10项通过（补取消/无效receipt）；unit-final：11项/3suite通过（增加实际转屏修正涉及的唯一会话/关闭后只回调一次）。
- 两次确定性Proto生成一致、network isolation0failure、secret scan通过、最终lint333文件0violation、git diff --check通过。
- protected-check.json：共享InteractionKit/Pager/列表、MediaViewer、Core Images/Session、App Navigation及AppShell/AppRouter共33文件SHA与R08相同。ThreadReaderStore仅透传forumID，原分页与承载没有更改。
- R05/R06/R08既有测试仅将已被R09替代的只读提示断言更新为真实编辑器/取消，原分页、返回、图片断言保留；这三个旧长用例本阶段未重复跑。

没有新动画、手势、透明overlay、网络/图片缓存、生产依赖或Session/Keychain更改。只有本阶段系统编辑sheet。

## 未验证/限制

Live 写请求尚未执行，不能宣称发布成功。Android的login/addThread用HTTP，iOS仅使用相同host/path的HTTPS，实际TLS兼容性和无Android设备字段的最小请求待用户第二道门禁。缺少独立ReplyPage目标图，当前布局按源码与现有视觉原子。验证码/风控明确不支持，不自动解码、绕过或重发；未知服务端代码原样数字提示。新帖/回复成功后页面刷新在Mock验证，真实服务器刷新/审核延迟待用户手动发送验证。草稿关闭进程后不保留。

## 最终验证与交付

- `xcodebuild test` 定向 R09ComposerTests/R09WriteProtocolTests/R09WriteRepositoryTests：11项、3 suites，全部通过（unit-final.xcresult）。
- iPhone R09ComposerSmokeTests：3/3通过，78.531s（phone-final.xcresult）。四布局、空正文禁用、Mock失败保留草稿/成功关闭、三个阅读入口、取消恢复与不同目标草稿隔离；吧入口取消后仍是原列表。
- iPad R09ComposerIPadSmokeTests：1/1通过，19.489s（ipad-final.xcresult）。竖屏键盘输入→横屏，同一编辑器和输入文字保留，取消返回。
- `make lint`：333文件0 violations；`make build`、secret scan、network isolation、确定性Proto生成和`git diff --check`全部通过。未运行全部Unit、完整quality或无关长矩阵。
- 两台正常 Debug Simulator `.app` 已覆盖安装并以无Fixture参数启动，没有卸载、erase或清Keychain。安装包TiebaLite.debug.dylib SHA256均与本次构建一致：`8f2a9f91448823bb2404f7fc343b8bfdd3ed56a623c2b05032a163f3c09e6280`，证据installed.json。iPhone真实关注吧及帖子可见，登录态保留；未读取/导出凭据。
- CUA实际从高通吧打开空白新帖、真实帖“骁龙8e6会不会成为神u?”的第2楼回复，目标作者/引用正确，取消返回同一可见位置；随后打开底部回复主题并聚焦空白正文，CUA已观察到正确目标。交付截图时页面已回到真实帖子，保留用户当前操作位置。没有输入或发送真实内容。Live聚焦时仅观察到插入光标及输入法切换提示，未观察到屏幕键盘，键盘布局证据采用定向UI测试截图，不冒充Live发送验证。

截图均在 `Artifacts/VisualReview/R09/`：`iphone-composer-thread.png`、`iphone-composer-threadReply.png`、`iphone-composer-floorReply.png`、`iphone-composer-subpostReply.png` 为四布局；`iphone-mock-failure-retains-draft.png`、`iphone-mock-success-closes-composer.png` 为Mock结果；`ipad-iPad-portrait-keyboard.png`、`ipad-iPad-landscape-keyboard.png` 为宽度变化；`iphone-live-new-thread.png`、`iphone-live-floor-reply.png`、`iphone-live-handoff.png` 为完整Live页面。完整App还保留“我的→组件画廊→R09 · 文字编辑器验收”的隔离Mock入口。

第一道门禁仅等待用户布局验收。后续真实发布需要用户单独授权并亲自输入、点击发送；当前无任何Live发布成功证据。R09未暂存、未提交，不进入R10。

## 用户 Live 失败修订（2026-09-24）

### 目标与根因

用户在新钢笔吧手动回复后看到“返回内容无法识别”，另一个账号也没有找到回复。当前malformedResponse只在writeStarted=false的账号资料阶段产生。实际只读账号诊断确认HTTP200/error_code0，却标为application/x-javascript；旧MIME白名单在JSON解析前拒绝响应，因此本次没有走到AddPost。不是键盘或点击失效。

逐项复核原版ReplyViewModel、AddPostRepository、MixedTiebaApiImpl、MiniTiebaApi/OfficialProtobufTiebaApi及全部拦截器后，另发现回复multipart缺少后置公共字段和签名。此前“multipart没有_client_version、无需签名”的文档结论错误：CommonParamInterceptor会追加_client_version，SortAndSignInterceptor随后对非文件字段签名。此缺口在请求构造回归中证实；因为本次原失败停在资料阶段，不能把签名缺口说成已观察的服务器拒绝原因。

### 修改范围

- TextWriteAccountProtocol/TextWriteProtocol：只为R09 JSON端点兼容application/x-javascript（原版同一Gson转换器），仍需有效JSON；回复外层补齐可用的公共字段、签名和Charset/x_bd_data_type请求头。原Proto楼层/作者/正文/target映射不变。不伪造Android设备标识或风控字段。
- TextComposition：资料解析失败明确提示“发送前获取账号资料失败，尚未提交帖子或回复”，提交后的不确定结果继续提示检查帖子。
- R09WriteRepositoryTests及证据/fixture文档：更新真实响应类型、拦截器链与失败回归。没有新增动画、手势、overlay、依赖；共享网络pipeline、Session/Keychain、列表/导航/图片系统不变。

### 验证与失败记录

Artifacts/VisualReview/R09/WritePreflight保存结果。首轮red命令少了Swift Testing方法名括号，执行0项，不能算通过。red-actual正确筛选后3次执行均因malformedResponse而非server(1)失败；red-interceptors因缺少外层字段/签名/头失败；red-thread-json因MIME被拒绝失败。修复后green-final：13项/3 suites通过（0.017s）。make lint：333文件0violations，secret scan通过、network isolation0failure、diff check通过。只执行本次相关Unit，没有重复UI长流程或全部Unit/quality。

匿名元数据请求未带凭据。App内只读诊断使用当前会话：HTTP200、error_code0、MIME application/x-javascript;charset=utf-8、user.id是string、tbs存在、生产decoder成功，publishRequests=0。首个临时诊断在启动会话恢复前运行，仅得preflight-failed，不作为API证据；改为等已有会话恢复完成后才得到上述有效结果。临时诊断源码与启动参数已移除，App/TiebaLiteApp.swift恢复为本轮诊断前逐字内容，记录仅保留在ignored Artifacts内。没有记录或导出账号ID、令牌、正文、完整响应。

### 尚未验证

本轮没有调用Live AddPost/AddThread，没有任何自动发送。实际新帖HTTPS兼容、服务端风控、真实发布和发布后刷新仍须用户自行点击发送后观察。不能把账号前置资料成功/Mock成功写成Live发布成功。内存草稿不跨进程，本次覆盖安装后需用户自行重新输入。R09不暂存、不提交，不进入R10。

最终make build成功；两台Simulator已覆盖安装完整正常Debug App，二进制SHA256均匹配230c885ed1730296455066179c9cef96895b179d9da16c2ac7f8895780248dbe（installed.json）。没有卸载、erase、清Keychain或登录态变更。iPhone无任何测试/诊断启动参数，已从浏览历史打开用户原“钢笔购买渠道”帖子并停在空白回复主题编辑器，系统屏幕键盘已显示；截图iphone-live-ready.png。用户自行输入并发送，本轮所有工具的Live发布数为0。READY_FOR_USER_VISUAL_REVIEW仅表示修订可人工复验，不等于发布已通过。

## 用户手动主题回复成功（2026-09-24）

用户明确反馈“我确实发送成功了”，并提供原“钢笔购买渠道”帖子截图，新增第9楼已显示。记为主题回复路径LIVE_THREAD_REPLY_USER_VERIFIED，证据Artifacts/VisualReview/R09/WritePreflight/user-confirmed-live-thread-reply.png。本次为用户自行输入、点击发送后的实际可见结果；没有AI自动发布、没有抓取或保存发布响应与凭据。此前失败和只读诊断记录保留，不能回写为当时已通过。

新帖、回复指定楼层、回复楼中楼尚无单独用户Live成功证据，不由本次主题回复成功推定全部通过。当前只更新验收记录，未修改代码、未重复构建或测试；git diff --check通过。R09未暂存/提交，未进入R10。

## 用户批准后的提交检查

正常 App 的 R09 回复验收入口及页面改为仅 UITESTING 编译，入口不再显示验收字样；生产错误提示、草稿保留说明不受影响。13 项定向 Unit、1 项四种编辑器 Mock UI（44.665 秒）、make lint（333 文件零违规）、make build、secret scan、git diff --check 通过。证据位于 Artifacts/VisualReview/R10/r09-approval-*。首个 UI 命令误写配置为 UISmoke，exit 70、零测试；改为已配置的 UI Smoke 后通过，没有降低断言。未运行全量 quality，未执行 Live 发送。
