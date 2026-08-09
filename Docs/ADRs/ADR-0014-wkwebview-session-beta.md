# ADR-0014：可见 WKWebView 与 Session Open-Source Beta 边界

- 状态：Accepted
- 日期：2026-08-04
- 决策者：阶段 12 Open-Source Beta
- 关联阶段：07、11、12
- Supersedes：仅取代 ADR-0007 的 fixture-only production 登录选择；不宣称完成
  ADR-0007 的发布级 journal、ledger、crash recovery 或安全审计

## 背景与证据

阶段 12 的当前用户指令要求可交互网页登录、Keychain 恢复、退出和一次受控
authenticated Debug Probe，并明确采用个人开源 Beta 标准。

锁定 Android reference
`5545326b2a8e0d784b2f3dfbcb219c7b121e61c2` 提供以下 `CODE_EVIDENCE`：

- `LoginPage.kt::LOGIN_URL` 使用 HTTPS `wappass.baidu.com`，回跳目标是
  `tieba.baidu.com/index/tbwise/mine`；
- `LoginWebViewClient.onPageFinished` 只在 tieba/tiebac 的
  `/index/tbwise/` 完成页读取 Web Cookie，并要求 `BDUSS` 与 `STOKEN`
  同时存在；`BAIDUID` 只是可选客户端标识；
- Android 随后的 `/c/s/login` 与 `/c/s/initNickname` 是明文 HTTP，继续
  `BLOCKED`，不得移植；
- Android V12 GetUserInfo builder 会忽略 caller candidate，读取全局旧/空
  账户，并且失败不阻止建账，不能作为已证安全 validator；
- 完整 Cookie、TBS、BAIDUID、ZID 和设备字段都不是阶段 12 已证的最小
  Web credential 集合。

因此本阶段只能把两个非空 Cookie 值称为 `candidate minimum`。Beta UI 的
`signedIn` 表示“可见网页完成、候选已原子写入本 App Keychain 并签发当前
进程 lease”，不等于 Android legacy validation、关注吧或阶段 11 Live API
已经完成服务器验证。

## 候选

### A：ASWebAuthenticationSession

需要服务端 callback/deep-link 和 credential transfer 证据。当前没有证据证明
它能把所需 HttpOnly Cookie 安全交给 App，阶段 12 无法完成目标。

### B：可见、App-owned 的 WKWebView

用户自行输入账号、密码和验证码；App 只通过 `WKHTTPCookieStore` 在已证完成
页提取两个候选值。容器可完全由 App 清理，且不依赖 Safari 共享 Cookie。

### C：私有账号密码接口、手工 Cookie 或共享浏览器存储

会让 App/Codex 接触密码或不可控共享 credential，拒绝采用。

## 决策

选择 B，并限定如下：

1. 登录容器始终可见，只加载 HTTPS；初始 URL 固定为 Android 已证 URL。
   顶层跳转仅允许 `baidu.com` first-party host，完成识别只接受 exact
   `tieba.baidu.com` 或 `tiebac.baidu.com` 且 path 以
   `/index/tbwise/` 开头。非 HTTPS 和非 first-party 顶层跳转取消。
2. 不调用 `evaluateJavaScript`，不注册读取 DOM/表单的 script handler，不
   自动输入账号、密码、验证码，也不记录网页 URL、标题、正文或错误文本。
3. 使用单个 `WKWebsiteDataStore.nonPersistent()` 作为本 App 登录会话。
   登录过程中允许跨导航 Cookie；退出时删除该 store 的 Cookie/website data
   并换成新 store。不能声称清除了 Safari 或系统浏览器数据。
4. `WKHTTPCookieStore` 内立即、大小写不敏感地提取两个非空值；不把
   `HTTPCookie`、完整 Cookie header、BAIDUID、TBS、ZID、profile 或设备字段
   传出 WebKit 边界。
5. Keychain 使用单个 `kSecClassGenericPassword`、固定 service/account、
   versioned Data envelope 和 `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`；
   不使用 access group、不同步 iCloud。payload 只含两个 opaque String。
6. `SessionAuthContextProvider` 的 `@MainActor` 实例是 credential/lease 的进程内 owner；
   Feature/View 只观察 `SessionState` 和公开摘要。`expired`/logout 先撤销当前
   lease；旧 lease、旧 generation 和迟到 completion 不能重新授权。
7. `SessionStore` 只保留一个 restore/login commit Task 和递增 generation。
   新检查、取消、过期或 logout 取消旧任务，每个 await 后重新核对 generation。
8. Fixture/UITesting 只使用 `FakeSessionCredentialStore` 和 fixture auth
   provider；不得访问真实 Keychain、真实账号或 live network。
9. Debug Probe 只允许用户显式触发一次 HTTPS authenticated Personalized
   请求；请求继续使用既有 Proto seam，只加入 Android 已证的 CommonRequest
   两项及 multipart outer stoken。只展示 HTTP status、MIME、body bytes、
   Proto decode、mapped count 和 typed outcome；不保存或记录请求/响应正文。
10. Production Recommendations/ThreadReader 继续 fail closed。单次 authenticated
    Probe 不改变阶段 11 的 `RUNTIME_EVIDENCE_PARTIAL`。

## Beta 状态投影

公开状态为：

```text
signedOut → signingIn → signedIn(public summary)
signingIn → failed(loginIncomplete | credentialStore)
signingIn(cancel) → signingOut → signedOut | failed(logout)
signedIn → expired
signedIn | expired | failed(logout)
  → signingOut
  → signedOut | failed(logout)
```

用户关闭登录页回 `signedOut` 且不显示普通错误。Cookie 不完整进入安全的
“登录未完成”失败；不写 Keychain。Keychain 写成功且 matching generation
后才进入 `signedIn`。启动恢复从同一 credential store 读取完整 envelope；
畸形/不完整数据 fail closed。logout 撤销 lease、删除 Keychain、清 App-owned
Web data 后才称为 `signedOut`。

## 阶段 12 运行观察

2026-08-04 在 iPhone 17 Pro / iOS 26.5 Simulator 的本机签名 Debug 构建中，
由用户在可见 WKWebView 内手工完成登录；App 随后进入 `signedIn`。进程终止并
重新启动后，SessionStore 从系统 Keychain 恢复同一候选 credential，并再次
进入 `signedIn`。全程没有由 Codex 输入、读取或记录账号、密码、验证码或
Cookie 值。

用户显式触发一次 authenticated Personalized Debug Probe，脱敏观察为：HTTP
200、`application/octet-stream`、83924 bytes、Proto decode 成功、12 个映射
条目、`outcome=success`。该观察证明客户端能在 matching lease 下构造并完成
一条携带候选字段的请求，但不证明服务端实际消费了这些字段、把响应归因于
认证或接受它们作为最小 credential 集合，也不验证 Cookie 轮换、真实过期
taxonomy、PBPage 或 Production Repository。请求的
`page_thread_count=11` 只是 Android call-site hint；本次映射 12 项明确证明
它不能被解释为已证响应上限。

用户随后明确要求保留登录凭证以便下次使用，因此本轮没有对该真实 Session
执行 logout。logout 的 lease 撤销、Keychain delete、WebKit cleanup 调用及独立
清理顺序由确定性测试验证；只有 Keychain delete 失败的可重试语义被注入验证。
WebKit cleanup API 没有错误返回，只能确认请求已回调完成；不得把这些写成真实
Simulator logout 通过。

## 延期与回滚

以下为 `DEFERRED_POST_BETA`：ADR-0007 的 CommitJournal/CleanupLedger、每个
midpoint crash recovery、受保护 cache aggregate、多账号、token rotation、
真实 expired error taxonomy、真机/发布级隐私与安全审计。阶段 12 不实现
关注吧、评论、回复、发帖、签到或点赞。

此外，Foundation Cookie API 没有把 host-only 与显式 Domain 属性作为独立
字段暴露给当前 selector；同 domain/path 的冲突会 fail closed，但 host-only
精确语义仍为 `UNKNOWN`。启动恢复只验证 versioned Keychain envelope 的结构
完整性，不证明服务端仍接受会话；取得 evidence-backed 过期信号前，过期
credential 可能暂时投影为 `signedIn`。

若可见网页登录、Cookie 完整性、Keychain 重启恢复、authenticated Probe 或
真实 logout 后再次启动任一无法真实完成，阶段 12 必须保持
`RUNTIME_EVIDENCE_PARTIAL`，保留 Fixture Session，并不得伪造 success。本轮
用户在登录后明确要求保留 credential，真实 logout 与再次启动因此标为
`NOT_RUN/DEFERRED_BY_USER_CREDENTIAL_RETENTION`；logout 的确定性 cleanup
与 Keychain delete retry 测试通过不等于真实 Simulator logout 已验证。发生安全回归时
回滚 production 登录入口，保留 Core protocol、Fake store 和
`signedOut` 默认。

## 验证

- 自动化使用注入 backend 验证 Keychain codec/query 的 save/load/delete；
  Unit 不读取系统 Keychain。
- 覆盖不完整 Cookie、取消、expired、logout、restore、Task replacement、旧
  lease、diagnostic redaction 以及 Fixture/UITesting 隔离。
- 真实人工步骤只由用户在可见 WebView 中输入凭据；不截图、不录制、不导出
  WebKit data。真实登录、重启和 Probe 已观察；logout 后再次启动未运行，故
  阶段保持 `RUNTIME_EVIDENCE_PARTIAL`，该未运行项不能写成通过。
- 因改动 App 根 presentation，阶段出口运行完整 `make quality`。

## 2026-08-09 阶段 15.5 修订

阶段 12 的一次性签名构建运行观察不等于默认构建链具备 Keychain entitlement。
阶段 15.5 证明 tracked `CODE_SIGNING_ALLOWED[sdk=iphonesimulator*]=NO` 会使正常
Simulator App 缺少 simulated `application-identifier`/embedded entitlements，
Keychain 因此 fail closed。现决策要求：可访问真实 Keychain 的 Simulator App
必须由 Xcode 本地签名，生成 application identifier 必须与 bundle identifier
匹配，Mach-O 必须嵌入 entitlements，并由确定性 quality-fast gate 检查。

启动期间 `SessionStore` 在 credential owner 完成 install/revoke 前保持 restore
unresolved；App shell 不在该窗口创建，避免 active-only Repository 抢先请求。
Production factory 必须把同一 `SessionAuthContextProvider` 交给 Keychain-backed
`SessionStore`、环境 session 与所有 active Repository。Repository 在发送前取得 matching lease，
并在响应后复验；signed-out 不得发送 HTTP，旧 lease 不得发布响应。

原决策第 10 条是阶段 12 当时的 evidence gate。阶段 15.5 的脱敏运行证据现允许
active-session Personalized 首屏和 authenticated ForumGuide 进入 Production；
ThreadReader 依据阶段 15 的独立匿名证据。Fixture/UITesting、无有效会话、真实
expired taxonomy 未知时仍 fail closed。真实 logout、字段最小性、token rotation、
真机/App Store entitlement 与发布级安全审计的延期结论不变。
