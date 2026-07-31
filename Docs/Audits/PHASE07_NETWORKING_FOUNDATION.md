# 阶段 07 Networking / Protobuf Foundation 审计

状态：NETWORKING_FOUNDATION_PARTIAL

阻塞标签：BLOCKED_ON_SCHEMA_RIGHTS_AND_RUNTIME_FIXTURE

## 范围

本阶段安全完成通用、fixture-first 的网络基础：

- validated HTTPS HTTPRequest；
- actor URLSessionHTTPClient 与独立 ephemeral configuration；
- typed EndpointDescriptor、显式 AuthContext 和 origin-aware
  RequestAuthorizing seam；
- deterministic query/form/multipart-binary 编码；
- fixture 与 transport 共用的 decode/map pipeline；
- transport、HTTP、server、decode、mapping、authentication、
  unsupported content、response limit 与 cancellation 分类；
- fixture-only/live/protobuf 静态隔离门禁。

本阶段没有：

- 注册 Tieba endpoint 或把 URLSession concrete 接入 composition root；
- 发真实网络请求或使用账号；
- 复制 Android schema、生成 Swift、添加 SwiftProtobuf/其他依赖；
- 创建业务页面、Repository、业务 mapper 或进入阶段 08。

## 前置证据结论

Specs/API_EVIDENCE.md 仍是 STATIC_EVIDENCE_ONLY。Android 未登录 Explore
会加载 Personalized，这只能证明客户端尝试匿名；没有服务端匿名成功证据。
所有 P0 fixture 仍是 NOT_CREATED。

Docs/Audits/SOURCE_AND_LICENSE_NOTES.md 仍为
REVIEW_REQUIRED_BEFORE_CODE_OR_SCHEMA_REUSE：321 个 Android proto 缺少
逐文件 provenance，仓库 GPLv3 与 README 非商业声明的关系未关闭。

工具链检查：

- /opt/homebrew/bin/protoc：libprotoc 34.1；
- protoc-gen-swift：missing；
- SwiftProtobuf checkout/canonical package lock：不存在；
- Generated/Protobuf：只有目录规则文件，无 generated source；
- opaque.pb：既有 synthetic loader fixture，不是 endpoint payload。

因此 Prompt 中“解析真实/sanitized endpoint binary fixture、未知字段
round-trip、生成可重复、Proto→domain mapper”的验收前置不成立。阶段状态
不能写 PASSED。

## 实现边界

### Transport

URLSessionHTTPClient：

- 使用 actor；
- production factory 创建独立 ephemeral URLSession；
- httpCookieStorage、urlCredentialStorage、urlCache 均为 nil；
- 不使用 shared session、shared cookie 或 shared cache；
- request 禁 userinfo、fragment、非法 header、非 HTTPS、非法 timeout/limit；
- delegate 当前唯一策略是拒绝全部 redirect；
- AsyncBytes 在已知 Content-Length 和未知长度两条路径限制 body；
- cancellation 保持 CancellationError；
- response 仅返回 allowlisted header，不返回 Set-Cookie 或任意私有 header。

当前 production composition 仍注入 DisabledHTTPClient。Transport concrete
可编译、可 fixture 测试，但没有 live consumer。

### Endpoint / Auth

EndpointDescriptor 固化 symbolic ID、method、validated host/ASCII path、
query、body codec、response family/MIME、auth requirement、timeout、body
limit、redirect/retry policy。path 拒绝 traversal、encoded ambiguity、
反斜线、fragment/query 和未编码 Unicode。

AuthContext 明确区分 anonymous、active lease 和 candidate operation。
authorizer 可见 endpoint ID 与 validated host，能在 materialize credential
前做目的地绑定。阶段 07 的唯一 concrete authorizer：

- anonymous 返回空 header；
- active/candidate fail closed 为 credentialUnavailable；
- context 不匹配为 contextMismatch。

没有 credential、Cookie storage 或 Keychain 实现。

### Encoding / mapping

- query 使用 RFC3986-style percent bytes，form 的空格使用加号；
- fields 稳定排序；
- multipart boundary 可注入并验证长度、字符与 payload 碰撞；
- binary payload 不转字符串；
- auth material 只在 body/URL 静态验证之后请求，await 后复核 cancellation；
- fixture adapter 与 executor 复用同一 MIME/status/decode/map pipeline；
- decoder/mapper 抛出的 cancellation 不被改写；
- executor 不重试。

## 自动化覆盖

新增 tests 覆盖：

- HTTPS、host、userinfo、fragment、header、timeout、body limit；
- host/path traversal、encoded path、Unicode path、MIME descriptor；
- deterministic query/form/multipart golden 与 boundary collision；
- anonymous AuthContext 不生成 credential header、active/candidate fail
  closed、auth origin binding；
- ephemeral cookie/credential/cache 隔离；
- redirect decision 与实际 production delegate completion(nil)；
- Content-Length early reject、未知长度 streaming limit、exact limit；
- allowlisted response headers、offline/timeout/malformed/body limit；
- HTTP 500、MIME missing/wrong、decode/server/map 分类；
- transport/pipeline error 统一、no retry、in-flight/decode/map cancellation；
- fixture adapter 与 domain mapper seam。

redirect 的测试精度：已直接调用 production delegate 并证明
completion(nil)；没有以真实 302 server 跑完整 session.bytes redirect
chain。HTTPRedirectPolicy 当前只有 reject；增加其他 policy 前必须把 policy
显式传入 loader 并补端到端回归。

## 红绿记录

- 实现前 make test-unit：
  20260731-202200-74635-unit.xcresult，预期因 production symbols 缺失退出
  65。
- 中间编译反馈：
  20260731-202521-74834-unit.xcresult、20260731-202734-75524-unit.xcresult
  分别暴露 warning-as-error 与 redirect decision nil 类型问题，已修正。
- make lint 首轮因 Endpoint.swift control-statement violation 失败，
  修正后 67 个 Swift 文件 0 violation。
- redirect URLProtocol 尝试：
  20260731-203246-76772-unit.xcresult 单例超时 30 秒；该 test seam 对
  redirect cancellation 没有完成 original response，已删除错误断言，改为
  直接验证 production delegate。失败未作为通过证据。
- 最新定向 Unit：
  20260731-203823-78488-unit.xcresult，78/78 通过。

阶段出口 make quality 首次被 secret scan 拦截：测试中的非敏感 CRLF canary
使用了 `Cookie` 字面量；改为 `X-Injected` 后，完整门禁通过：Unit 78/78、
iPhone UI smoke 12/12、iPhone interaction 5/5、iPad UI smoke 2/2、iPad
interaction 1/1，并通过 Debug/iPad/Release build 与 Release/test-support
isolation。随后加强静态隔离脚本，覆盖 root-wide artifact、合法 YAML
packages 变体、generated pbx remote/local/product dependency，并让目标先
生成工程；Swift 源采用 module-token gate，不再猜 import grammar，因此覆盖
修饰符/selective/分号/换行/注释变体。多轮复审后均重新运行
make quality-fast，Debug build 与 Unit 78/78 通过，最终结果为
20260731-210431-87589-unit.xcresult。命令、结果文件及一次 xcresulttool
沙箱权限失败在
Docs/Progress/TASK_STATE.md 完整记录。

## 剩余风险与解锁条件

1. schema 权利、notice 与分发路径明确。
2. 取得无敏感信息的真实 Personalized binary fixture 及来源、清理说明、
   SHA-256。
3. 用受控 HTTPS runtime evidence 确认匿名成功、最小参数/header、错误与
   分页/终止，不把“客户端尝试”误作“服务器接受”。
4. exact SwiftProtobuf、generator、canonical Package.resolved、schema
   manifest/import lock 与可重复生成全部落地。
5. optional absent/default、未知 tag round-trip、malformed、真实 mapper
   测试通过。
6. 完成真实 URLSession redirect chain 集成回归；在此之前仅允许
   reject-all 单一 policy。
7. production timeout/cancel 后 task 停止与资源释放、AsyncBytes 性能、
   typed redacted diagnostics 仍需验证。
8. active/candidate production credential、lease revalidation、session
   expiry 与跨 session stale response 仍未实现。

以上条件未满足时，不得接 live、不得把 transport concrete 放进 production
composition、不得宣称阶段 07 完成，也不得进入阶段 08。
