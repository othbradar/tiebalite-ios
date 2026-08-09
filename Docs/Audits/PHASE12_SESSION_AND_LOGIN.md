# 阶段 12：Session 与可见网页登录审计

- 日期：2026-08-04
- 基线：`2221793302250edcd0cdde591b0f92dfbc22db46`
- Android reference：`5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`
- 阶段 12 提交时状态：`PHASE_12_SESSION_AND_LOGIN = RUNTIME_EVIDENCE_PARTIAL`
- 阶段 15.5 当前状态：`PHASE_12_SESSION_AND_LOGIN = COMPLETE`
  （`OPEN_SOURCE_BETA`；真实 logout 仍按用户要求 deferred）
- 实现成熟度：`SESSION_IMPLEMENTATION = BETA_READY`
- 阶段 12 当时后续阶段：`PHASE_13 = NOT_STARTED`

## 目标与范围

本阶段按个人开源 Beta 范围建立唯一 Session 基础：用户可见的 `WKWebView`
登录、候选 Cookie 提取、Keychain 持久化、进程重启恢复、显式会话状态、授权
上下文、logout 清理以及一次受控 authenticated Debug Probe。

本阶段没有实现关注吧、评论、回复、发帖、签到、点赞、生产 PBPage、Production
Live 解锁或阶段 13；没有修改 Pager、MediaViewer、Renderer、图片管线或已有
Fixture 主链路。Android submodule 始终只读。

## 证据与登录边界

锁定 Android reference 的可追踪证据仅支持：

- 可见 HTTPS 登录入口为 `wappass.baidu.com`；
- 完成回跳只接受 Tieba first-party 完成页；
- 完成页同时存在非空 `BDUSS` 与 `STOKEN` 才形成候选 Session；
- Android legacy `/c/s/login` 与 `/c/s/initNickname` 使用明文 HTTP，iOS 不
  移植；Android GetUserInfo 路径也不是已证安全 validator。

因此 `signedIn` 的准确含义是：用户完成可见网页流程、两个候选 opaque 字段
成功写入本 App Keychain，并为当前进程签发 matching lease。它不等于服务端
确认最小字段集合、Production Live 已解锁或会话永不过期。

## 关键设计与状态转换

公开状态为 `signedOut`、`signingIn`、`signedIn`、`expired`、`failed`；实现
使用 `signingOut` 明确表示清理正在进行：

```text
signedOut → signingIn → signedIn
signingIn(cancel) → signingOut → signedOut | failed(logout)
signedIn → expired
signedIn | expired | failed(logout)
  → signingOut
  → signedOut | failed(logout)
```

- `SessionStore` 只保存一个 restore/login Task 与递增 generation；每次 await
  后核对 generation 和取消状态，旧恢复或旧登录完成不能覆盖新状态。
- `SessionAuthContextProvider` 由 App composition 创建唯一 `@MainActor` 实例；
  credential 更新会增加 generation 并签发新 lease。logout/expired 先 revoke，
  旧 lease 之后不能授权请求。
- logout 顺序为 revoke → Keychain delete → App-owned WebKit cleanup。即使
  Keychain delete 失败仍会请求 WebKit cleanup；Keychain delete 失败保留可重试
  错误。WebKit cleanup API 不返回错误，只能确认请求已回调完成。
- `WKWebView` 始终可见，使用 app-owned `WKWebsiteDataStore.nonPersistent()`；
  App 不调用 `evaluateJavaScript`、不注入或注册 DOM script handler，也不自动
  输入或保存账号、密码、验证码；网页自身 JavaScript 保持系统默认行为。
- 顶层导航只允许 HTTPS Baidu first-party，拒绝显式端口；完成页按 domain、
  path、secure 和名称筛选 Cookie。同一 scope 冲突时 fail closed。

## Keychain 与敏感数据

Keychain 只使用一个 `kSecClassGenericPassword` item：固定 service/account、
versioned Data envelope、`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`、不使用
access group、不同步 iCloud。payload 类型只有两个 opaque String：`BDUSS` 与
`STOKEN`。

credential、authorization 和错误描述均脱敏。没有账号、密码、验证码、Cookie
值、完整 Cookie header、完整请求体、完整响应或用户内容写入日志、fixture、
测试附件、文档或 Git。

## Fixture 与 Production 边界

- Fixture/UITesting 使用 `HarnessFakeSessionCredentialStore`、同一个 fixture
  auth provider、nil login URL 和 Mock HTTPClient；不读取系统 Keychain 或真实
  账号，也不访问贴吧服务器。
- Production composition 使用 Keychain store 与真实 Session provider，但
  Recommendation/ThreadReader 仍由阶段 11 evidence-blocked repositories
  fail closed。
- Debug Probe 仅在 Debug 编译、仅由已登录用户显式触发、一次请求且不重试；
  输出只包含 HTTP status、MIME、body size、Proto decode、mapped count 和 typed
  outcome。

## 真实运行观察

| 验收项 | 结果 | 证据边界 |
| --- | --- | --- |
| 用户可见网页登录 | PASS | 用户在 iPhone 17 Pro / iOS 26.5 Simulator 手工输入并完成；App 显示 `signedIn` |
| 进程重启 Keychain 恢复 | PASS | 终止并重新启动 App 后再次显示 `signedIn`；没有导出 Keychain 数据 |
| authenticated Debug Probe | PASS / runtime observation | HTTP 200；`application/octet-stream`；83924 bytes；Proto decoded；12 mapped；`outcome=success` |
| 真实 logout | NOT RUN | 用户明确要求保留登录凭证以便下次使用 |
| logout 后再次启动 | NOT RUN | `DEFERRED_BY_USER_CREDENTIAL_RETENTION` |

Probe 只证明 matching lease 能构造并完成该请求。因为该 endpoint 可能匿名成功，
结果不证明服务端实际消费 credential、字段最小、账号身份、稳定分页、PBPage 或
Production Repository。`page_thread_count=11` 是 Android call-site hint；本次
映射 12 项，不能视为响应上限。

质量门禁后在保留凭证的 Simulator 上再次终止并启动 App，未执行卸载、logout
或清理；macOS 锁屏阻止了额外可访问性标签读取。因此不新增一条“门禁后 UI
复核通过”声明，前一轮真实进程重启恢复证据仍有效。

## 回归覆盖

阶段 12 定向 Unit 19/19：

- Keychain envelope/query 的 save/load/delete；
- credential/authorization/log 描述脱敏；
- 不完整 Cookie 不进入 `signedIn`；
- 用户取消回到 `signedOut`；
- matching expiry 进入 `expired` 并撤销授权；
- logout revoke/delete/WebKit cleanup 调用，以及 Keychain delete 失败重试；
- App 重建后 Fake Session 恢复；
- restore/login replacement、迟到 completion 与旧 lease；
- Fixture/UITesting 不使用真实 Keychain/live URL；
- 完成域/path/secure/大小写选择、冲突 fail closed；
- active request 只加入已证字段且 anonymous golden 不变；
- Probe 服务端失败保持 typed outcome。

另有登录 URL/显式端口/Cookie 选择策略 3/3、设置大字体图库导航回归 1/1。最终完整结果：

- Unit：235 个逻辑测试、254 次执行，0 failed、0 skipped；
- iPhone smoke：16/16；
- iPhone interaction：15/15；
- iPad smoke：5/5；
- iPad interaction：2/2；
- Release build/isolation：PASS。

首次完整 `make quality` 在 iPhone smoke 出现 1 个失败：新增账号 section 后，
大字体场景的原图库按钮在屏外，旧测试没有滚动。修复仅使测试滚动到可点击元素；
定向回归 1/1 和随后完整 iPhone smoke 16/16 通过。没有通过延迟、UUID、overlay
或降低断言修复。

## 实际执行的命令与结果

- `git status --short`：记录并排除用户原有 `.DS_Store`、`.idea/vcs.xml` 与
  Prompt Kit `.DS_Store`。
- `git rev-parse HEAD`：基线为
  `2221793302250edcd0cdde591b0f92dfbc22db46`。
- `git submodule status` 与 Android 子模块 status：锁定 hash，clean。
- `make quality-fast`：阶段开始基线通过；最终完整质量中再次通过。
- 阶段 12 定向 Unit：19/19；策略回归：3/3；大字体 UI 回归：1/1。
- `make quality`：第一次因上述 1 个 smoke 失败退出；修复后在独立无凭证
  iPhone Air Simulator 上从头运行，exit 0 并输出 `Quality gate completed.`。
- 最终 `make quality` 产物：
  - `Artifacts/TestResults/20260804-215822-16911-unit.xcresult`
  - `Artifacts/TestResults/20260804-215856-17315-ui-smoke.xcresult`
  - `Artifacts/TestResults/20260804-220806-18809-ui-interaction.xcresult`
  - `Artifacts/TestResults/20260804-224026-22463-ui-smoke-ipad.xcresult`
  - `Artifacts/TestResults/20260804-224417-23037-ui-interaction-ipad.xcresult`
  - `Artifacts/TestResults/20260804-225331-24060-release-build.log`
- `make instructions`、`make secret-scan`、`make lint`、`make test-unit`、
  `make quality-fast`、`git diff --check`：均包含在最终完整质量路径或提交前再次
  执行；最终结果均为 PASS。

`Artifacts/` 仅为本地证据，不纳入提交。

## 新增或变更的动画、手势、overlay、依赖

- 动画：无。
- 手势：无。
- Pager/MediaViewer/Renderer：无修改。
- overlay/fullScreenCover：无；新增一个由 App 根持有的系统 login sheet。
- 第三方依赖：无。
- live 网络：只有上述一次 Debug-only 用户触发 Probe；Production 仍 fail
  closed，自动化均为 Fixture/Mock。

## Known Limitations / UNKNOWN

1. 真实 logout、系统 Keychain delete、真实 App-owned WebKit cleanup 及 logout
   后重启未运行；按用户保留 credential 的明确要求延期。因此阶段不标 COMPLETE。
2. 启动恢复只验证 Keychain envelope 结构，不验证服务器仍接受 Session；真实
   expired error taxonomy 尚无可复现证据。
3. active Probe 不能证明服务端消费 credential、字段最小性或账号身份。
4. Foundation Cookie API 的 host-only 与显式 Domain 属性差异仍为 `UNKNOWN`；
   同 scope 冲突只做 fail closed。
5. Cookie 轮换、多账号、TBS、PBPage、关注吧和生产 Live 解锁不在本阶段。
6. ADR-0007 的 crash journal、cleanup ledger、受保护缓存 aggregate，以及真机、
   App Store entitlement 和发布级隐私/安全审计延期至 post-Beta。

## 下一阶段前置条件与停止点

`PHASE_12_SESSION_AND_LOGIN = RUNTIME_EVIDENCE_PARTIAL`，实现本身达到当前 Beta
范围，但真实 logout→重启验收因用户保留凭证未执行。`PHASE_11` 继续保持
`RUNTIME_EVIDENCE_PARTIAL`，`PHASE_13 = NOT_STARTED`。本任务在提交阶段 12
成果后停止，不自动进入阶段 13。

## 阶段 15.5 后续修订（2026-08-09）

阶段 12 的手工登录/一次性重启记录是真实历史观察，但当时的 tracked
Simulator 默认构建不能稳定复现该签名产物。阶段 15.5 定位到确定根因：
`Config/Shared.xcconfig` 对 Simulator 设置 `CODE_SIGNING_ALLOWED=NO`，生成 App
缺少 simulated `application-identifier` 和嵌入 entitlements；Simulator
`securityd` 因而以 `-34018` 拒绝 Keychain 访问。未读取、清除或判定原
credential 无效。

移除该 override 后，正常 Debug Simulator build 由 Xcode 本地签名。新增
`make simulator-keychain-entitlement`，确定性检查 App codesign、生成
`application-identifier` 与 bundle identifier 匹配，以及 Mach-O
`__entitlements`；`make quality-fast` 依赖该门禁。App shell 还会等待
`SessionStore.isLaunchRestoreResolved`，确保同一 credential owner 已完成
install/revoke 后才让页面触发 live 请求。

在同一 Simulator 上覆装签名 App（没有卸载、logout、Keychain/WebKit 清理或
重新登录）后，App 进程重启自动恢复 `signedIn`，同一 provider 投影 active
AuthContext，并由 Production Repository 成功消费 matching lease。按阶段 15.5
当前用户给出的开源 Beta 完成条件，
`PHASE_12_SESSION_AND_LOGIN = COMPLETE`。真实 logout 与 logout 后重启仍因
“保留登录凭证”要求未运行，继续作为 Known Limitation；真实失效码、rotation、
最小 credential 集合及发布级安全审计也仍为 `UNKNOWN`。
