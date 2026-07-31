# ADR-0007：Session 与登录边界

- 状态：Proposed
- 日期：2026-07-31
- 决策者：阶段 02 候选决策，待登录证据与安全验证
- 关联阶段：02、04、12

## 背景

Android 使用 WebView Cookie、明文 Room 和 HTTP login validation，且 Proto
builder 可能读取全局旧账户。这些行为不能成为 iOS 契约。iOS 登录容器、
合法 callback、Cookie/token 轮换、过期 taxonomy、WebKit 数据清理和多账号
均为 UNKNOWN。

## 必须满足的约束

- 用户显式发起登录；不收集密码、不注入脚本、不绕过风控/TLS。
- raw credential 只在 Session/Vault 边界短暂 materialize。
- Feature 只看到 capability、opaque sessionID 和公开资料白名单。
- internal SessionState、journal、ledger、handle 不直接暴露给 SwiftUI。
- 旧 session 的响应不能 expire 或写入新 session。
- 登录成功、退出和 crash recovery 遵守现有 commit journal/cleanup ledger。
- production login 在 HTTPS、平台和运行证据关闭前保持 disabled。

## 候选方案

### A：ASWebAuthenticationSession

- 优点：系统认证 UX，浏览器与 App 边界清晰。
- 缺点：需要已证 callback/deep link 和服务端兼容。
- 风险：无法取得所需 app-owned credential handle，或依赖不可控共享 Cookie。
- 验证方式：专用测试账号，仅记录字段存在性与状态转换，不记录值。

### B：显式可见、隔离的 WKWebView 登录

- 优点：若服务不支持标准 callback，可观察 first-party navigation/cookie。
- 缺点：WebKit storage、domain allowlist、清理和审核风险高。
- 风险：误收集密码、JS 注入、第三方跳转、残留 Cookie。
- 验证方式：独立 privacy/security spike、navigation allowlist 和 cleanup
  integration tests；禁止隐藏 WebView。

### C：手工输入 Cookie/token、SFSafariViewController 抽取或共享 Cookie

- 优点：实现表面直接。
- 缺点：安全和平台边界不可接受。
- 风险：凭据泄漏、不可验证来源和清理不完整。
- 验证方式：拒绝进入实现。

### D：fixture-only Session adapter

- 优点：立即支持确定性状态/UI 开发，无真实凭据风险。
- 缺点：不能证明 production 登录。
- 风险：若误标为 live 会掩盖未知。
- 验证方式：所有状态机场景和脱敏 canary tests。

## 候选决策

当前选择 D。生产登录候选优先级为 A；只有 A 被运行证据证明不可行且 B 的
隐私/清理门禁通过，才可由 superseding/更新后的 Accepted ADR 选择 B。
ADR 保持 Proposed。

安全核心边界先固定为：

- `SessionController actor`：canonical internal state、operationID 与
  reentrancy guard；
- `CredentialVault actor`：Keychain app-only、ThisDeviceOnly 项与
  operation-tagged staging；
- `SessionJournalStore actor`：versioned commit journal/cleanup ledger；
- `ProtectedDataCoordinator actor`：capability、session generation、
  protected cache lease；
- `ProtectedDataCleaner`：由 Session 边界拥有的清理协议，composition root
  注入 Persistence/Images 等 concrete 的 aggregate，Session 不反向依赖
  Images concrete；
- `SessionViewProjection`：向 MainActor 发布脱敏、单调 revision 的 snapshot；
- `AppNavigationStore`：唯一持有进程内 attemptID → continuation，以及
  cleanupOperationID → cleanup 成功后登录 launch request。

每个 actor 在 `await` 后重新核对 operationID/state。raw token 不进入 state
description、Error、日志、fixture 或附件。

### Session 与受保护写

每个受保护请求获得：

```text
ProtectedDataLease(sessionID, generation)
```

Session 过期、退出或替换前先原子递增/撤销 generation，再取消任务。Repository
或 cache 在每次写入前验证 lease；取消后晚到的数据只能丢弃，不能重新污染
已清理 namespace。失效 signal 必须携带产生它的 sessionID；旧 session 的
401/业务错误不能使新 session expired。

只有 fixture/RUNTIME_EVIDENCE 明确分类的错误才能映射为 expired；未知错误
保持安全的领域失败。

cleanup 从 preparation、durable deletion retry 到 terminal event 使用同一
`cleanupOperationID`；每次异步尝试另建 `requestID`，旧 request 的回调必须
丢弃。durable `CleanupLedger` 只保存 ledgerID、cleanupOperationID、明确
scopes、destination 和 idempotency version，不保存 secret 或进程内
continuation。ledger 恢复保留 operation identity、创建新 request；进程内
的 reauthentication launch map 丢失后只完成清理到 signedOut，不猜测启动
登录。若 cleanup ledger 首次写入失败且已证明零删除，只有用户 signOut 的
完整源状态可 dismiss；恢复时递增为新的 generation，signedIn 才签发新
lease，旧 lease 永不重新激活。

### 登录与替换

- interactive new login 只从 clean `signedOut` 启动。
- `expired` 的同凭据续期走 `refreshStarted`。
- 用户要从 expired 更换/重新登录时，先撤销 lease，并通过 durable cleanup
  ledger 清到 signedOut；cleanup 成功后才创建新的 authentication attempt。
- cleanup 失败时不启动浏览器登录，也不把旧状态称为 clean signedOut。
- 当前只允许一个 active session；多账号需要新 ADR。

### Cookie 与浏览器数据

生产方案获准前，不决定可持久 Cookie 集合。未来实现必须使用 app-owned、
domain allowlisted jar/Keychain entry，禁止 `HTTPCookieStorage.shared` 和
隐式从全局账户读取。ASWebAuthenticationSession/Safari 无法由 App 清理的
数据必须在 UX 和文档中明确，不能声称“退出已清全部浏览器数据”。

## 为什么不是其他方案

A 尚无 callback 证据；B 尚无 WebKit 隐私和清理证据；C 明确越过安全边界。
D 是当前唯一不伪造 production 能力的路径。

## 迁移/退出成本

登录容器只输出平台无关 completion/credential handle，Session engine 和
Feature 不依赖 ASWebAuthenticationSession/WKWebView。容器候选可替换而不
改变状态机。无法获得合法 HTTPS/callback 时长期保留 fixture-only。

## 接受条件

ADR 只有在以下全部通过后可改 Accepted：

- 平台允许、全程 HTTPS 的显式登录方案；
- 成功/取消/重复 callback/验证码/过期/退出的安全分类；
- Vault、journal、ledger 各 midpoint crash/failure 测试；
- restored/newLogin retry 与 navigation continuation 测试；
- logout 后晚到 protected cache write 被 lease 拒绝；
- Web/Cookie 清理能力和不能清理的边界有真实证据；
- 日志/xcresult/fixture canary 不含 secret。

任一方案需要 HTTP、隐藏 WebView、JS 密码提取、共享 Cookie 或绕过 TLS，
立即回滚为 signedOut + fixture-only。
