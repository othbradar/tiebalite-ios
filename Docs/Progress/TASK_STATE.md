# TASK_STATE

- 当前阶段：07
- 状态：NETWORKING_FOUNDATION_PARTIAL
- 阻塞：BLOCKED_ON_SCHEMA_RIGHTS_AND_RUNTIME_FIXTURE
- 当前分支：main
- 阶段 06 提交：
  dd1214ed5df258ae899c5748869ab8faf42c4114
  （feat: complete stage 06 interaction spikes）
- 阶段 07 工作树：未提交；不得进入阶段 08。

## 目标与范围

允许修改：

- Sources/Core/Networking 的通用 HTTPS transport；
- Sources/Core/TiebaAPI 的 typed Endpoint/AuthContext/request builder/
  fixture mapper seam；
- 最小 ProtectedDataLease 值类型；
- 对应 Unit tests 和 fixture-only 静态隔离脚本；
- API/Proto/许可证证据、阶段审计和本文件。

明确禁止：

- 业务页面、Feature Store、生产 Repository 或真实 Tieba mapper；
- Tieba live endpoint、真实网络 probe、账号/Cookie/Keychain；
- 复制 Android proto、生成 pb.swift、SwiftProtobuf/package lock；
- 修改 Android submodule；
- 进入阶段 08 或后续阶段。

## 已读取的规则、规格与技能

- 已读取根目录及 Sources/Core、Generated、Resources、TestSupport、Tests、
  Specs、Docs 目录链上适用的 AGENTS.md。
- 已读取 Prompts/07_NETWORKING_PROTOBUF_FOUNDATION.md、
  Specs/API_EVIDENCE.md、Specs/PROTOBUF_MAP.md、
  Specs/UNKNOWN_BEHAVIORS.md、Specs/DEPENDENCY_POLICY.md、
  Specs/PROJECT_PLAN.md、Specs/STATE_MACHINES.md、Specs/MODULE_MAP.md，
  ADR-0001/0006/0007/0008/0009/0010 和进入阶段时的 TASK_STATE。
- 已显式使用 .agents/skills/tiebalite-api-evidence 与
  .agents/skills/xcode-quality-gate。
- 三个子代理仅只读审计 Android evidence、网络架构和 Proto/toolchain；
  工作树写入全部由主代理完成。最终代码复审未发现 P0/P1。

## 阶段 06 提交与工作树保护

- 用户授权后以精确路径提交阶段 06，commit 为
  dd1214ed5df258ae899c5748869ab8faf42c4114。
- git show 核对该 commit 只有 30 个阶段 06 文件。
- 用户原有 .idea/dataSources.xml、.idea/db-forest-config.xml 暂存/工作树
  状态，以及 .idea/noctule.xml、.idea/vcs.xml 和两个 .DS_Store 漂移，
  均未修改、未 restore、未纳入阶段 06 commit，也不得纳入后续提交。
- 没有 amend、rebase、merge、push 或 tag。

## 阶段 07 基线

- git status --short：只见上述用户漂移。
- git submodule status：Android reference 锁定
  5545326b2a8e0d784b2f3dfbcb219c7b121e61c2。
- make doctor 在沙箱内因 CoreSimulatorService 权限退出 2；同一命令以批准
  权限在沙箱外复跑后 0 failure、0 warning。
- 工具：macOS 26.6、Xcode 26.6（17F113）、Swift 6.3.3、
  XcodeGen 2.45.4、SwiftLint 0.65.0、xcbeautify 3.2.1。
- command -v protoc：/opt/homebrew/bin/protoc；
  protoc --version：libprotoc 34.1。
- command -v protoc-gen-swift：退出 1，无输出。
- 阶段 06 commit 上 make quality-fast 通过：
  Debug build 20260731-200905-72067-build.log，
  Unit 61/61 20260731-200906-72101-unit.xcresult。

## Evidence / Proto 前置结论

- API_EVIDENCE 仍为 STATIC_EVIDENCE_ONLY；所有 P0 真实 fixture 都是
  NOT_CREATED。
- Android ExplorePage 在未登录时仍把 Personalized 作为首个页面，
  PersonalizedPage 首次加载发送 Refresh；这只证明客户端尝试匿名，
  不证明服务端接受匿名。
- 没有 Personalized/FRS/PB 的真实 binary payload；既有 opaque.pb 是
  synthetic loader fixture，不是 endpoint response。
- schema 权利状态仍为
  REVIEW_REQUIRED_BEFORE_CODE_OR_SCHEMA_REUSE：Android 321 个 proto 缺少
  逐文件 provenance，GPLv3 与 README 非商业声明关系未关闭。
- 仓库无 SwiftProtobuf checkout、canonical Package.resolved、
  schema manifest/import lock 或 generated source；本机无
  protoc-gen-swift。
- 因此前置不成立，阶段 07 不得标 PASSED，也不能通过 synthetic schema
  或复制 Android 文件伪造 Proto 验收。

## 阶段 07 实现

### HTTPS transport

- HTTPRequest 新增 timeout、response body limit 和 reject redirect policy；
  拒绝非 HTTPS、空 host、userinfo、fragment、非法 header 和非法资源上限。
- URLSessionHTTPClient 是 actor；production factory 使用独立 ephemeral
  configuration，禁 shared cookie、credential 和 cache。
- URLSessionDataLoader 使用 AsyncBytes，在 Content-Length 已知和未知时
  都执行 byte limit；response 只保留 allowlisted headers。
- URLSession cancellation 保持 CancellationError；offline、timeout、
  malformed、oversize 和其他 transport 分开。
- production composition 继续使用 DisabledHTTPClient，没有 live consumer。

### Endpoint / Auth / mapper seam

- EndpointDescriptor 固化 symbolic ID、method、validated host/ASCII path、
  query/body codec、response family/MIME、auth、timeout、limit、
  redirect 和 retry=never。
- AuthContext 分 anonymous、active(ProtectedDataLease)、
  candidate(OperationID)。authorizer 可见 endpoint ID/host，以支持目的地
  绑定；阶段 07 concrete 对 active/candidate 一律 fail closed。
- query/form deterministic percent encoding；multipart binary boundary
  可注入，验证 metadata 和 payload collision。
- EndpointPipeline/FixtureEndpointAdapter 共用 status/MIME/decode/map
  行为；executor 不重试，transport oversize taxonomy 统一，
  decode/map cancellation 不被吞掉。

### 静态隔离

- 新增 make networking-isolation 并纳入 quality-fast。
- networking-isolation 先执行 deterministic project generation，避免直接
  运行该目标时检查陈旧 pbx。
- 禁止 App/Sources 出现真实 Tieba host、URLSession.shared、
  HTTPCookieStorage.shared、URLCredentialStorage.shared。
- 禁止 UI 层 URLSession/SwiftProtobuf/GeneratedProtobuf。
- 在 schema 权利门关闭前，禁止 project.yml 的 top-level packages、生成工程
  remote/local package reference 与 package product dependency、App/Sources
  中出现 SwiftProtobuf/GeneratedProtobuf 模块标识符（覆盖修饰符、selective、
  分号、换行或注释 import），
  并从仓库根扫描 .proto、.pb.swift、Package.resolved（排除只读 Android
  reference、prompt kit、构建产物和 .git）。
- AppCompositionRoot 必须继续注入 DisabledHTTPClient。

## 红绿与定向验证

- 实现前 make test-unit 预期红：
  20260731-202200-74635-unit.xcresult，缺少新增 production symbols，
  xcodebuild 退出 65。
- 20260731-202521-74834-unit.xcresult：warning-as-error 指出未使用
  response limit，退出 65，已修正。
- 20260731-202734-75524-unit.xcresult：redirect decision 的 nil 缺少类型，
  退出 65，已修正。
- make lint 首轮因 Endpoint.swift control_statement violation 退出 2；
  修正后 67 Swift files、0 violation、0 serious。
- 20260731-203246-76772-unit.xcresult：URLProtocol redirect cancellation
  seam 超时 30 秒，1 项失败；没有伪装成通过。删除错误 seam，改为直接调用
  production delegate 并证明 completion(nil)。
- 最新 make test-unit：
  20260731-203823-78488-unit.xcresult，78/78 通过。
- bash -n scripts/verify_networking_isolation.sh：PASS。
- make networking-isolation：0 failure。
- make secret-scan：PASS。
- git diff --check：PASS。

## 阶段出口门禁

- make quality 首次运行在 secret-scan 退出 2：测试中的非敏感 CRLF canary
  使用了 `Cookie` 字面量，被高置信规则正确拦截；改为 `X-Injected` 后单独
  make secret-scan 通过。该失败没有作为门禁通过证据。
- 修正后 make quality 完整通过：
  - Debug build：20260731-204418-80899-build.log；
  - Unit：78/78，20260731-204420-80961-unit.xcresult；
  - iPhone UI smoke：12/12，
    20260731-204439-81256-ui-smoke.xcresult；
  - iPhone interaction：5/5，
    20260731-204752-81942-ui-interaction.xcresult；
  - iPad build：20260731-205253-82241-ipad-build.log；
  - iPad UI smoke：2/2，
    20260731-205254-82270-ui-smoke-ipad.xcresult；
  - iPad interaction：1/1，
    20260731-205413-82726-ui-interaction-ipad.xcresult；
  - Release build/isolation：20260731-205455-82854-release-build.log；
  - 最终输出 `Quality gate completed.`。
- 完整门禁后的多轮只读对抗复审发现静态脚本覆盖缺口；最终修正为
  root-wide artifact scan、quoted/inline YAML packages、generated pbx
  remote/local/product gate、先生成工程，以及生产 Swift 源码中的 Protobuf
  module-token gate。后者不再猜 Swift import grammar，能覆盖修饰符、
  selective、分号、换行和注释变体。随后重新执行：
  - bash -n scripts/verify_networking_isolation.sh：PASS；
  - make networking-isolation：0 failure；
  - make secret-scan：PASS；
  - git diff --check：PASS；
  - make quality-fast 第一次复核后运行：PASS，Debug build
    20260731-205806-84178-build.log，Unit 78/78
    20260731-205807-84201-unit.xcresult；
  - 第二次 adversarial 复核补齐 selective/分号 import 与 inline/local
    package canary 后，make quality-fast 再次 PASS，Debug build
    20260731-210057-85951-build.log，Unit 78/78、0 failed、0 skipped，
    20260731-210057-85963-unit.xcresult；
  - 最后补齐 multiline/comment import、quoted YAML 与 stale pbx 防线后，
    最终 make quality-fast 再次 PASS，Debug build
    20260731-210430-87577-build.log，Unit 78/78、0 failed、0 skipped，
    20260731-210431-87589-unit.xcresult。
- `xcrun xcresulttool get test-results summary` 在沙箱内读取结果时因
  TestReport 临时目录权限退出 64；以批准权限复跑后成功，确认上述 Unit
  78/78、iPhone 12/12 + 5/5、iPad 2/2 + 1/1，均为 0 failed、0 skipped。

## 未验证与剩余风险

1. 没有 anonymous/live endpoint、真实 binary fixture、真实 Proto mapper。
2. SwiftProtobuf exact lock、生成器、schema/import manifest、生成 hash、
   optional presence、unknown tag round-trip 全部 NOT_TESTED。
3. redirect 只证明 production delegate 返回 nil，不是实际 302
   session.bytes end-to-end chain；当前 policy 只有 reject。扩展 policy 前必须
   把 policy 逐请求传入 loader 并新增集成测试。
4. production URLSession 的真实 timeout、取消后底层 task 停止/资源释放、
   AsyncBytes 性能未测。
5. Endpoint typed/redacted diagnostics 尚未接入；当前无 raw request 日志是
   因为不记录，不等于 observability 已验收。
6. RequestAuthorizing 当前仅是 header seam；Android static evidence 还可能
   涉及 CommonRequest/外层 multipart auth，不能据此猜 credential 注入。
7. active/candidate production credential、lease revalidation、session
   expiry、跨 session stale response 未实现。
8. Phase 06 Pager/Media 仍是 SPIKE_PARTIAL；阶段 07 不改变其已知风险。

## 动画、手势、overlay、依赖

- 新增动画：无。
- 新增手势：无。
- 新增 overlay：无。
- 新增生产依赖：无。
- SwiftProtobuf：未添加。

## 下一阶段前置条件

只有先关闭 schema 权利与 notice 决策、取得有来源/脱敏记录/SHA-256 的真实
binary fixture、验证匿名 HTTPS 最小请求与错误/分页，并完成 exact
SwiftProtobuf 可重复生成、unknown/presence/malformed/mapper tests，才可把
阶段 07 从 PARTIAL 提升。当前必须停止在阶段 07，不得进入阶段 08。
