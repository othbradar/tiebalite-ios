# 阶段 15.5：核心 Live 能力收口审计

- 日期：2026-08-09
- 基线：`9f45b63f311f608239a9cda999e14fe07e52eb96`
- Android reference：`5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`
- 状态：`PHASE_15_5_CORE_LIVE_INTEGRATION = COMPLETE`
- 验收标准：`OPEN_SOURCE_BETA`
- 后续阶段：`PHASE_16 = NOT_STARTED`

## 目标与边界

本阶段只修复保存 credential 的启动恢复断点，把恢复后的 active AuthContext /
`ProtectedDataLease` 接到 Production 推荐和关注吧 Repository，并各做一次受控
Live smoke。没有重新实现登录，没有 logout、清理或打印现有凭证；没有修改
ForumHome/ThreadReader 虚拟列表、Pager、MediaViewer、Renderer、图片管线或
阶段 16。

## 根因与修复前回归

静态链路证明同一 `SessionAuthContextProvider` 内没有
“`signedIn` 但 AuthContext anonymous”的 await 窗口：`SessionStore.restore()`
先同步 install credential/lease，再发布 `signedIn`。Production factory 也已把
同一个 provider 交给 Keychain-backed Store 和 App environment。

真实失败发生在构建身份：tracked `Config/Shared.xcconfig` 禁用了 Simulator
code signing，生成 App 缺少 simulated `application-identifier` 和 Mach-O
entitlements。Simulator `securityd` 对该进程记录 `-34018`，即 client 没有
application identifier/keychain access group；Keychain 读取按设计 fail closed。
这不证明 item 丢失、payload 损坏或服务器拒绝 credential。

修复前新增的 `make simulator-keychain-entitlement` 在旧构建上确定性失败，指出
application identifier 缺失；移除 override 并由 Xcode 本地签名后通过。门禁现在
会先 build，再检查 App codesign、generated application identifier 与 built bundle
identifier 匹配，以及 Mach-O `__entitlements`。

## 启动与授权不变量

- `SessionStore.isLaunchRestoreResolved` 在启动 restore 完成 credential owner 的
  install/revoke 前保持 false；App shell 此时不创建，只显示不透明 loading；
- Production factory 的同一 provider 同时服务于 Keychain-backed
  `SessionStore`、`AppEnvironment.session`、`LiveRecommendationRepository` 与
  `LiveFollowedForumsRepository`；自动化锁定该 owner identity；
- 两个 Repository 都在发请求前取得 matching authorization，并在响应后复验
  原 lease；signed-out 在 HTTP 前 fail closed，replacement lease 的迟到响应
  不发布；
- Fixture/UITesting 继续使用 FakeSession、Fixture Repository 和 Mock HTTP，
  不读取系统 Keychain、不访问 Live 网络。

## 脱敏运行证据

在原保存会话所在的 iPhone 17 Pro / iOS 26.5 Simulator 上，只做签名 App 覆装、
终止和重新启动；没有 uninstall、logout、Keychain/WebKit 清理或重新登录。

| 能力 | HTTP | MIME | bytes | Proto | mapped | typed outcome | Production UI |
|---|---:|---|---:|---|---:|---|---|
| active Personalized 首屏 | 200 | `application/octet-stream` | 74924 | decoded | 12 | success | 推荐页非空 |
| authenticated ForumGuide | 200 | `application/octet-stream` | 9199 | decoded | 18 | success | 关注吧列表显示 |

推荐与关注吧 tab 往返一次，没有重复登录提示。Probe/文档没有记录或保存 Cookie、
credential、Cookie/Authorization header 或完整 headers、请求体、raw response、
吧名、帖子正文或用户内容。

## 回归覆盖

提交前定向测试先运行并通过 35 个逻辑测试：

- `Stage11LiveRecommendationTests`：8；
- `Stage12AuthenticatedProbeContractTests`：2；
- `Stage12SessionStoreTests`：11；
- `Stage13FollowedForumsTests`：12；
- `Stage15Point5LiveFollowedForumsTests`：2（为满足 lint 从同一 14-test suite
  机械拆分，行为与断言不变）。

覆盖恢复后 active authorization、restore 未决 gate、signed-out zero-request、
active request body/golden、Production Mock transport、取消/旧 generation、普通错误
不误判 expired，以及两个 Repository 的 post-response lease replacement。新增的
Production composition 单一 authorization owner 回归由最终完整 Unit 覆盖。

## 实际命令与结果

- `git status --short`、`git diff --stat`、`git diff --cached --stat`、
  `git rev-parse HEAD`、`git submodule status`：基线与用户漂移已记录，Android
  submodule 指针未变且工作树 clean；
- 基线 `make quality-fast`：sandbox 内首次因用户缓存权限失败；按相同命令在允许
  Xcode/Simulator 缓存访问的环境重跑通过；
- 修复前 `make simulator-keychain-entitlement`：按预期失败；修复后
  `make build` 与 `make simulator-keychain-entitlement`：通过；
- 阶段相关定向 Unit：35/35，通过，xcresult：
  `.build/DerivedData/Logs/Test/Test-TiebaLite-2026.08.09_19-49-17-+0800.xcresult`；
- `make secret-scan`：通过，无 high-confidence match；
- `make lint`：第一次因新增测试使原 Stage13 test struct 超过 350 行而失败；
  只机械拆出两个阶段 15.5 回归并复用 TestSupport fixture loader 后，最终 182 个
  Swift 文件、0 violations；
- `make test-unit`：通过，289 个逻辑测试、308 次执行、0 failed/0 skipped；
  xcresult：`Artifacts/TestResults/20260809-200305-29173-unit.xcresult`；
- `make quality-fast`：通过；instructions、reference/Proto/fixture/SwiftPM/XcodeGen、
  forbidden/static canaries、secret scan、networking isolation、lint、Debug build、
  Simulator Keychain entitlement 和 Unit 全部通过。其 Unit 为 289 个逻辑测试、
  308 次执行、0 failed/0 skipped；xcresult：
  `Artifacts/TestResults/20260809-200506-34647-unit.xcresult`；
- 因修改 App 启动壳，额外运行 Fixture UI smoke：iPhone 19/19、iPad 6/6，
  0 failure；xcresult 分别为
  `Artifacts/TestResults/20260809-200741-39182-ui-smoke.xcresult` 与
  `Artifacts/TestResults/20260809-201917-44262-ui-smoke-ipad.xcresult`。按任务边界
  没有重复运行 Pager/Media interaction 矩阵；
- 最终 `git diff --check`：通过。

一次在 Simulator 仍为 Shutdown 时尝试覆装，install 按预期失败；随后启动同一
Simulator 并直接覆装成功，没有卸载或清除数据。该中间环境失败不计为运行成功。

## 状态更新

- `PHASE_11_LIVE_READ_FLOW = COMPLETE`（`OPEN_SOURCE_BETA`）；active 推荐首屏
  与阶段 15 匿名 PBPage 两页均有运行证据；
- `PHASE_12_SESSION_AND_LOGIN = COMPLETE`（`OPEN_SOURCE_BETA`）；当前用户明确
  允许真实 logout 继续列为 Known Limitation；
- `PHASE_13_FOLLOWED_FORUMS = COMPLETE`（`OPEN_SOURCE_BETA`）；
- `PHASE_16 = NOT_STARTED`。

## Known Limitations / UNKNOWN

1. 本轮按要求保留 credential，真实 logout 与 logout 后重启未运行；确定性测试
   覆盖 revoke、Keychain delete、WebKit cleanup 和失败重试。
2. 服务器是否实际消费两个 credential 字段、字段最小性、rotation 与真实 expired
   code 未证实；普通网络/server/decode 错误不会猜成 expired。
3. Personalized 只验证 active 首屏；匿名稳定性、分页和登录完成后的自动刷新未
   验证。已有失败页需用户点击现有“重试”。
4. ForumGuide 的空列表、超过 200 项完整性、forumID 长期稳定性及过期 taxonomy
   仍为 `UNKNOWN`。
5. 自动化无真实网络/Keychain；真实 smoke 是单 Simulator 的开源 Beta 证据，
   不是多账号、真机、App Store 或发布级安全矩阵。
6. Live 图片仍 disabled。本阶段没有新增动画、手势、overlay、第三方依赖或
   写操作。
