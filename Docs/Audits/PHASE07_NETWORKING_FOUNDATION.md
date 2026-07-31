# 阶段 07 Networking / Protobuf Foundation 审计

状态：`NETWORKING_PROTOBUF_FOUNDATION_COMPLETE`

范围标签：`LOCAL_PERSONAL_NONCOMMERCIAL` /
`PRODUCTION_LIVE_DISABLED` / `PUBLIC_DISTRIBUTION_BLOCKED`

## 范围与出口

阶段 07 已建立可重复、fixture-first 的首个 Personalized 协议垂直切片：

- 通用 HTTPS transport、typed endpoint、显式 auth seam 和分层错误；
- 从 pinned Android reference 只读生成的最小 Protobuf 依赖闭包；
- exact SwiftProtobuf runtime/generator/package lock；
- 独立 JVM 生产、protoc 交叉核对的 synthetic binary fixture；
- request wire golden、Swift decode、Proto → Sendable domain mapper；
- optional presence、unknown field、raw unknown integer、畸形 payload、
  server/missing-data、取消/超时/HTTP/MIME/size 等回归；
- project/package/generated/UI/private-capture 静态隔离。

本阶段没有创建业务页面、Feature Store 或生产 Repository，没有发 Tieba
live 请求、读取账号/Cookie/Keychain，也没有把 concrete HTTP client 接入
production composition。阶段 08 未开始。

## 来源、权利与依赖

ADR-0011 接受的 schema 使用范围只限本地、个人、非商业开发。输入唯一来自：

```text
References/TiebaLite-Android
commit 5545326b2a8e0d784b2f3dfbcb219c7b121e61c2
app/src/main/protos/Personalized.proto
```

`Config/Protobuf/Personalized.inputs.tsv` 固定 root 1、direct 4、transitive
46，共 51 个文件的相对路径、SHA-256、关系和直接 import。生成脚本拒绝
submodule commit/clean 状态、hash、import 或 dependency closure 漂移；不复制
`.proto`，不读取 `n0099`，不生成其余 270 个无关 schema。

工具和依赖精确锁定：

- `protoc 35.1`；
- `protoc-gen-swift 1.38.1`；
- Apple SwiftProtobuf `1.38.1`，revision
  `55d7a1cc5666b85c13464aea1c4b4a90feccb4c8`；
- canonical lock：`Config/SwiftPM/Package.resolved`；
- Xcode resolve/build/test 使用 resolved-only、skip-updates，并在结束后重新
  比较 canonical lock。

SwiftProtobuf 的 Apache-2.0 + Runtime Library Exception 审查不覆盖 Android
schema、Tieba API、品牌或内容。公开分发、App Store 和商业使用仍为
`BLOCKED`，需要新的权利与 notice 决策。

## 生成与 Swift 6 边界

`scripts/generate_protos.sh` 只写明确的 repo output 或 `TMPDIR` 下经过
验证的空/真实目录；写/删前执行 lexical/realpath containment，在
规范化前拒绝原始 `..` 组件，并拒绝路径链与 output tree 的任意
symlink。输出是
`Generated/Protobuf` 下 51 个 `.pb.swift`、generation metadata 和
SHA-256 清单。`scripts/verify_protos.sh` 在两个独立临时目录生成，并比较
两者与 tracked output；五个 upstream unused-import warning 不影响字节稳定性。

当前 generator 在 10 个复杂 copy-on-write generated message 中产生
`@unchecked Sendable`。这是 ADR-0011 限定的 generated-only 例外：

- 静态门禁锁定 exact 文件名单、数量和生成 hash；
- 手写 App/Core/Test 继续禁止 `@unchecked Sendable` 和
  `@preconcurrency import`；
- raw message 只在同步 Core/TiebaAPI decode/map 边界内存在；
- 结构化任务只返回普通 `Sendable` domain 值。

`GeneratedProtobuf` 是内部静态 target。只有
`Sources/Core/TiebaAPI/PersonalizedProtocol.swift` 可以导入
GeneratedProtobuf/SwiftProtobuf；View、Feature 与 domain model 都看不到
generated type。

## 跨语言 fixture

`TestSupport/Fixtures/API/Recommendations/personalized_cross_language.pb`
由 Java 21.0.10 + `protobuf-java 4.35.1` 的
`DynamicMessage` producer 创建：

- 250 bytes；
- SHA-256
  `54a838f8bd05c39e90b84b3bba4d4224dc81fe11b63934e23dd65be937eebb4a`；
- jar SHA-256
  `a4345ba2aa009912ff6f90467fea2d104605256b72c50840d75f13256638a472`；
- 两次 JVM generation、tracked bytes 和独立 `protoc --encode` 输出一致。

`make bootstrap-fixture-tools` 只从 Config 锁定的 exact Maven Central URL
下载并校验 SHA-1/SHA-256，原子安装到 ignored cache。quality 不发网络请求，
cache 缺失、symlink 或 hash 错误均 fail closed；隔离门禁还验证缺失 cache
不能静默降级。

fixture 只包含 synthetic ID/text 和 `fixture.invalid` URL，不含真实账号、
Cookie、BDUSS、STOKEN、授权头、设备标识或真实内容。它的证据等级是
`CROSS_LANGUAGE_GENERATED`，不是抓包或 live runtime evidence。

## Personalized 协议行为

已证静态 request contract：

- `POST /c/f/excellent/personalized?cmd=309264`；
- `X-BD-Data-Type: protobuf`；
- multipart boundary `--------7da3d81520810*`；
- binary part `name=data`、`filename=file`，无 per-part Content-Type；
- refresh/page 1 protobuf golden：
  `0a0b2001280b30015801b80101`；
- anonymous auth、redirect reject、retry never。

host 由 fixture/test 显式注入；production Swift 中没有真实 Tieba host。
request 只编码 Android static evidence 支持的 load/page/count/type 字段，不猜
CommonRequest、AppPos、设备或 session 值。

decoder 明确拒绝零字节，按非零 `errorCode` 映射 server failure，并在 mapper
前检查 message presence。mapper 保留服务器顺序、独立 raw `id/threadID`、
raw `threadTypes=999`、public author whitelist 和 optional child presence；
不映射 `User.bduss/passwd`，不猜 canonical identity、去重、分页终止或错误
文本。页码递增使用 overflow-safe 逻辑，终止状态保持 `.unknown`。

## 自动化覆盖

Personalized 新增 7 项 Unit：

1. exact request protobuf/multipart/header/no-credential；
2. cross-language fixture decode/map 和 server order；
3. present-empty、missing data、nonzero service error；
4. optional explicit-default 与 absent presence；
5. unknown field 2047 round-trip、raw integer 999；
6. empty/truncated/unterminated malformed body；
7. structured task 只返回 Sendable domain，页码 overflow-safe。

通用网络测试继续覆盖 HTTPS validation、query/form/multipart、origin-bound
auth、ephemeral cookie/credential/cache、HTTP/MIME/decode/map taxonomy、
redirect reject、timeout、response limit、取消、no retry 和日志脱敏。

行为先行记录：

- `20260731-230440-18801-unit.xcresult`：在
  `RecommendationPage` 尚未实现时按预期编译失败；
- `20260731-230658-20506-unit.xcresult`：warning-as-error 拦截 deprecated
  protobuf initializer，改用 `serializedBytes`；
- `20260731-230721-21864-unit.xcresult`：实现后定向 Unit 通过；
- `20260731-232129-34884-build.log`：最新 quality-fast Debug build 通过；
- `20260731-232134-35029-unit.xcresult`：Unit 85/85、0 failed、
  0 skipped。

安全终审修复后，完整阶段出口 `make quality` 从头退出 0 并输出
`Quality gate completed.`：

- Debug build：`20260801-000625-66395-build.log`；
- Unit：`20260801-000627-66436-unit.xcresult`，85/85；
- iPhone UI smoke：`20260801-000657-66748-ui-smoke.xcresult`，12/12；
- iPhone interaction：
  `20260801-001010-67628-ui-interaction.xcresult`，5/5；
- iPad build：`20260801-001510-68110-ipad-build.log`；
- iPad UI smoke：`20260801-001513-68162-ui-smoke-ipad.xcresult`，2/2；
- iPad interaction：
  `20260801-001632-68383-ui-interaction-ipad.xcresult`，1/1；
- Release build/isolation：
  `20260801-001714-68562-release-build.log`。

五个 xcresult 均由 `xcresulttool` 确认为 0 failed、0 skipped。当前
Release-iphonesimulator app 为 11,444 KiB，universal simulator executable
为 11,687,320 bytes；没有阶段 06 同配置基准，因此不声称依赖体积增量。

## 静态隔离

`make networking-isolation` 当前为 0 failure，并验证：

- production composition 仍为 `DisabledHTTPClient`；
- App/Sources 无 live Tieba URL、shared URLSession/cookie/credential；
- UI 无 URLSession、SwiftProtobuf 或 generated type；
- 只有 exact Core adapter 可以接触 generated module；
- project/pbx 只有 official exact package，无 branch/range/local/plugin；
- 唯一 canonical `Package.resolved`，生成 target 位置和文件数精确；
- handwritten concurrency bypass 为零，10 个 generated 例外 exact；
- private capture 目录内容被 ignore，不会进入构建或 Git；
- fixture classification/hash 和 adversarial canary 均通过。
- output ancestor/tree symlink 与 symlink + `..` 绕过均由负向 canary
  fail closed。

## 未验证与剩余风险

1. 未执行 Tieba live probe；匿名服务端接受、真实 response MIME、最小
   CommonRequest/AppPos/header、错误码和值域都仍为 `UNKNOWN`。
2. fixture 不能裁决 canonical ID、重复页、稳定顺序、分页终止或服务器实际
   unknown-field 分布；production mapping 的 terminal 保持 `.unknown`。
3. public/App Store/commercial distribution 仍被 ADR-0011 阻塞。
4. URLSession redirect 只验证 production delegate 返回 nil，未以真实 302
   server 跑完整 `session.bytes` chain；当前只允许 reject policy。
5. production timeout/cancel 后底层 task 资源释放、AsyncBytes 性能、typed
   redacted request diagnostics 未做运行性能验证。
6. active/candidate credential、lease revalidation、session expiry 与跨
   session stale response 不在阶段 07。
7. SwiftProtobuf 相对阶段 06 的可比 Release 体积增量尚无同配置基准；阶段
   07 只记录当前 Release 产物大小。
8. 阶段 06 Pager/Media 仍是既有 SPIKE_PARTIAL；本阶段没有扩大或修复其
   运行时缺口。

## 变更类型

- 新增动画：无。
- 新增手势：无。
- 新增 overlay：无。
- 新增业务页面：无。
- 新增生产依赖：SwiftProtobuf 1.38.1（exact lock）。
- Android submodule 修改：无。

阶段 07 完成后必须停止；不得自动开始阶段 08。
