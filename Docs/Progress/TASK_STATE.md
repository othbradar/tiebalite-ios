# TASK_STATE

- 当前阶段：07
- 状态：`PHASE_07_COMPLETE_LOCAL_FIXTURE_FOUNDATION`
- 当前分支：`main`
- 阶段 06 提交：
  `dd1214ed5df258ae899c5748869ab8faf42c4114`
  （`feat: complete stage 06 interaction spikes`）
- 阶段 07 checkpoint：
  `11768dd4b1416619ea396c12cf97616546cccad1`
  （`feat: checkpoint stage 07 networking foundation`）
- production live：`DISABLED`
- 阶段 08：`NOT_STARTED`

## 目标与范围

阶段 07 只建立 Networking、SwiftProtobuf 和首个 Personalized
fixture-driven 协议基础：

- 通用 HTTPS transport、typed Endpoint/Auth/request/pipeline；
- pinned Android schema 最小闭包和确定性 Swift 生成；
- exact SwiftProtobuf lock；
- cross-language generated binary fixture；
- request golden、decode、Proto → domain mapper 和回归；
- 静态隔离、证据、许可证与 UNKNOWN 记录。

未创建业务页面、Feature Store 或生产 Repository；未接 live endpoint，未发
真实网络请求，未读取账号/Cookie/Keychain，未修改 Android submodule，也未
进入阶段 08。

## 已读取的规则、规格与技能

- 已读取根目录及 Sources/Core、Generated、TestSupport、Tests、Specs、Docs
  目录链上适用的 `AGENTS.md`。
- 已读取 `Prompts/07_NETWORKING_PROTOBUF_FOUNDATION.md`、关联 Specs、
  ADR-0001/0006/0007/0008/0009/0010/0011 和进入阶段时的本文件。
- 已显式使用 `.agents/skills/tiebalite-api-evidence` 与
  `.agents/skills/xcode-quality-gate`。
- 三个子代理只读核对 Proto closure/API 命名、SwiftPM/XcodeGen 锁和
  测试/隔离设计；所有工作树写入均由主代理完成。

## Git 与用户工作保护

- Android reference 保持 clean、exact
  `5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`。
- checkpoint 只提交当时 18 个阶段 07 网络基础文件。
- 用户原有 `.idea/dataSources.xml`、`.idea/db-forest-config.xml` 的
  staged/unstaged 状态，以及 `.idea/noctule.xml`、`.idea/vcs.xml`、
  根目录与 prompt kit 的 `.DS_Store` 漂移均未编辑、restore 或纳入阶段
  提交。
- 没有 amend、rebase、merge、push、tag、submodule update 或依赖浮动升级。

## 工具、来源与锁

- 环境：macOS 26.6、Xcode 26.6（17F113）、Swift 6.3.3、
  XcodeGen 2.45.4、SwiftLint 0.65.0、xcbeautify 3.2.1。
- Protobuf：`protoc 35.1`、`protoc-gen-swift 1.38.1`。
- SwiftProtobuf package/runtime：exact `1.38.1`，revision
  `55d7a1cc5666b85c13464aea1c4b4a90feccb4c8`。
- canonical lock：`Config/SwiftPM/Package.resolved`；生成工程的 lock
  只从 canonical lock materialize。
- schema root：Android reference 的
  `app/src/main/protos/Personalized.proto`。
- manifest：root 1 + direct 4 + transitive 46 = 51 个输入；逐文件
  SHA-256/import/relationship 锁定；`n0099` 不是输入。
- 权利边界：ADR-0011 只允许本地、个人、非商业使用；public/App Store/
  commercial 仍为 `BLOCKED`。

## 已实现

### 生成、工程与依赖

- `scripts/generate_protos.sh` 验证 submodule exact/clean、工具版本、
  manifest hash、imports 和 protoc dependency closure，再生成 51 个
  `.pb.swift`。
- 默认 output 在写/删前验证 lexical + realpath containment，在规范化前
  拒绝原始 `..` 组件，并拒绝路径链和 output tree 的任意
  symlink；自定义 output 只允许 `TMPDIR` 下经过验证的空目录。
- `scripts/verify_protos.sh` 比较两次 clean generation 与 tracked output。
- `scripts/materialize_swiftpm_lock.sh` /
  `scripts/verify_swiftpm_lock.sh` 固定 package identity/version/revision。
- XcodeGen 建立内部静态 `GeneratedProtobuf` target；App/Test 显式依赖，
  generated target 关闭 ObjC compatibility header 安装。
- resolve/build/test 使用
  `-onlyUsePackageVersionsFromResolvedFile -skipPackageUpdates`，结束后
  重新核对 lock。

### Fixture 与 provenance

- `scripts/fixtures/PersonalizedFixtureGenerator.java` 使用 Java
  `DynamicMessage`，不链接 Swift generated code。
- Java/Javac 21.0.10、`protobuf-java 4.35.1`；jar 的 published SHA-1
  与 locked SHA-256 都校验。
- `make bootstrap-fixture-tools` 从 Config 锁定的 exact Maven Central URL
  原子安装 ignored cache；quality 离线且对缺失/symlink/错误 hash fail
  closed。
- tracked fixture：
  `personalized_cross_language.pb`，250 bytes，SHA-256
  `54a838f8bd05c39e90b84b3bba4d4224dc81fe11b63934e23dd65be937eebb4a`。
- verifier 比较两次 JVM generation、tracked bytes 和独立
  `protoc --encode` 输出。
- fixture 为 `CROSS_LANGUAGE_GENERATED`，只含 synthetic 值；不是 live
  抓包或匿名服务器证据。

### Personalized contract 与 mapper

- request：`POST /c/f/excellent/personalized?cmd=309264`、
  `X-BD-Data-Type: protobuf`、Android exact multipart envelope。
- refresh/page 1 protobuf golden：
  `0a0b2001280b30015801b80101`。
- descriptor host 由 fixture/test 注入；production Swift 无真实 Tieba host。
- 不猜 CommonRequest、AppPos、设备、credential 或 session 字段。
- decoder 拒绝 empty body，区分 protobuf decode、server error 和
  missing-data mapping。
- mapper 保留服务器顺序、raw feed/thread ID、raw type 999、message
  presence 和 public author whitelist；不泄漏 generated type，不映射
  credential 字段，不猜 canonical ID/terminal。
- `RecommendationPage` 等 domain 值为 `Sendable`；页码递增
  overflow-safe。

### Swift 6 与静态隔离

- generated output 中 10 个 generator-produced
  `@unchecked Sendable` 是 ADR-0011 的 exact generated-only 例外；
  文件名单/数量/hash 被门禁锁定。
- 手写源码继续禁止 `@unchecked Sendable` 和
  `@preconcurrency import`。
- 只有 `PersonalizedProtocol.swift` 可导入 GeneratedProtobuf 和
  SwiftProtobuf；UI/Feature/domain 看不到 generated type。
- production composition 继续注入 `DisabledHTTPClient`。
- project/package/live URL/shared storage/generated location/private capture
  以及 output ancestor/tree symlink、symlink + `..`、JVM cache 缺失等拒绝
  canary 已纳入
  `make networking-isolation` 和 `make quality-fast`。

## 行为先行与回归

- `20260731-230440-18801-unit.xcresult`：先写 Personalized tests，
  `RecommendationPage` 尚不存在，编译按预期失败。
- `20260731-230658-20506-unit.xcresult`：warning-as-error 拦截 deprecated
  protobuf initializer；改用 `serializedBytes`。
- `20260731-230721-21864-unit.xcresult`：实现后定向 Unit 通过。
- Personalized 新增 7 项覆盖：
  request golden/envelope、cross-language decode/map、empty-vs-missing-vs
  service error、optional presence、unknown field/raw 999、
  malformed/empty body、Sendable domain/overflow。
- 通用 network tests 覆盖 HTTPS/request validation、query/form/multipart、
  auth binding、ephemeral storage、HTTP/MIME/size/decode/map taxonomy、
  redirect reject、timeout、取消、no retry 和日志脱敏。

## 本轮真实执行命令与结果

- `git status --short`：阶段 07 差异与已知用户漂移并存；用户漂移保持隔离。
- `git log -2 --oneline --decorate`：HEAD 为 `11768dd`，其父为
  `dd1214e`。
- `git submodule status -- References/TiebaLite-Android`：exact SHA，
  无 dirty marker。
- `bash -n ...`（11 个变更 shell 脚本）：PASS。
- `make verify-protos`：两次 clean generation 与 tracked output 一致；
  51 files。上游 `ThreadInfo.proto` 有 5 个 unused-import warning。
- `make verify-personalized-fixture`：两次 JVM generation、tracked
  fixture、独立 protoc encoding 一致。
- `bash scripts/verify_swiftpm_lock.sh`：exact 1.38.1/revision PASS。
- `make generate`：Proto verify、XcodeGen 和 canonical lock
  materialization PASS。
- `make doctor`：沙箱内因 CoreSimulatorService 权限退出 2；同一原命令
  以批准权限复跑后 0 failure、0 warning。
- `make resolve-packages`：只解析
  `https://github.com/apple/swift-protobuf.git @ 1.38.1`，结束后 lock
  verify PASS。
- `make networking-isolation`：0 failure。
- `make secret-scan`：无 high-confidence match。
- `git diff --check HEAD`：PASS。
- 安全终审期间曾真实触发并修复以下失败：
  - 静态 post-lock canary 首版有 shell runtime parse error，
    `make networking-isolation` 退出 2；
  - fixture bootstrap 首版参数带入字面 `+`，
    `make bootstrap-fixture-tools` 退出 2；
  - path safety 首两版误拒绝 macOS `/var` → `/private/var` 受信别名，
    `make verify-personalized-fixture` 两次退出 2；
  - missing exact JVM cache 的直接负向测试退出 66，符合 fail-closed
    设计；
  - 两次完整 `make quality` 在只读审计新发现 P1 后由协调代理
    主动中断，分别停在 UI smoke 和 iPhone interaction，`make` 报
    `Quit: 3`；修复后从头重跑下述最终门禁。
- `make quality-fast`：PASS：
  - Debug build：
    `Artifacts/TestResults/20260731-232129-34884-build.log`；
  - Unit：
    `Artifacts/TestResults/20260731-232134-35029-unit.xcresult`，
    xcresulttool 确认 85/85、0 failed、0 skipped；
  - lint：70 files、0 violation；
  - project generation、Proto、fixture、lock、secret scan、network isolation
    均在同一门禁中复验通过。
- 安全修复后最终 `make quality`：从头完整退出 0，并输出
  `Quality gate completed.`：
  - Debug build：
    `Artifacts/TestResults/20260801-000625-66395-build.log`；
  - Unit：
    `Artifacts/TestResults/20260801-000627-66436-unit.xcresult`，
    xcresulttool 确认 85/85、0 failed、0 skipped；
  - iPhone UI smoke：
    `Artifacts/TestResults/20260801-000657-66748-ui-smoke.xcresult`，
    12/12、0 failed、0 skipped；
  - iPhone interaction：
    `Artifacts/TestResults/20260801-001010-67628-ui-interaction.xcresult`，
    5/5、0 failed、0 skipped；
  - iPad build：
    `Artifacts/TestResults/20260801-001510-68110-ipad-build.log`；
  - iPad UI smoke：
    `Artifacts/TestResults/20260801-001513-68162-ui-smoke-ipad.xcresult`，
    2/2、0 failed、0 skipped；
  - iPad interaction：
    `Artifacts/TestResults/20260801-001632-68383-ui-interaction-ipad.xcresult`，
    1/1、0 failed、0 skipped；
  - Release build/isolation：
    `Artifacts/TestResults/20260801-001714-68562-release-build.log`，
    Build Succeeded，Release 不含 TestSupport、Debug gallery 或
    interaction lab；
  - canonical SwiftPM lock 在每个 Xcode 命令后复验通过。
- 当前 Release-iphonesimulator `TiebaLite.app` 为 11,444 KiB；
  universal simulator executable 为 11,687,320 bytes。没有阶段 06 的同配置
  Release 基准，因此不声称体积增量。
- 对两个已主动中断的 `.xcresult` 运行 `xcresulttool` 均退出 64，
  原因是中断包未生成 `Info.plist`；不将它们计为通过或产品回归。
- 状态文档更新后，误输入的 `make instructions-check` 因仓库无该 target
  退出 2；改用正确的 `make instructions` 后全部指令链/仓库 skills 验证
  PASS。
- 提交前再跑 `make release-isolation`：
  `Artifacts/TestResults/20260801-002146-72294-release-build.log`，Build Succeeded，
  Release 隔离 PASS；`make networking-isolation`、`make secret-scan`、
  `git diff --check HEAD` 和 submodule exact/clean 复核亦 PASS。

## 未验证与剩余风险

1. 未运行 live probe；匿名服务器接受、真实 MIME、最小
   CommonRequest/AppPos/header、错误码和值域均为 `UNKNOWN`。
2. synthetic fixture 不能裁决 canonical identity、重复页、稳定顺序、
   terminal、真实 unknown-field 分布或真实内容退化。
3. public/App Store/commercial distribution 仍被 ADR-0011 阻塞。
4. URLSession redirect 只验证 delegate reject，未做真实 302
   `session.bytes` integration。
5. production timeout/cancel 的底层资源释放、AsyncBytes 性能与 typed
   redacted request diagnostics 未测。
6. active/candidate credential、session expiry、lease revalidation 和跨
   session stale response 不在阶段 07。
7. SwiftProtobuf 相对阶段 06 的可比 Release 体积增量没有同配置基准；
   完整门禁后只记录当前 Release 大小。
8. iOS 18.x runtime 不可用；当前 UI/Unit 使用 iOS 26.5 Simulator。
9. 阶段 06 Pager/Media 的既有 SPIKE_PARTIAL 风险未改变。

## 动画、手势、overlay、依赖

- 新增动画：无。
- 新增手势：无。
- 新增 overlay：无。
- 新增业务页面：无。
- 新增生产依赖：SwiftProtobuf 1.38.1 exact。
- Android submodule 修改：无。

## 停止条件

阶段 07 的本地 fixture-first Networking/Protobuf 基础已完成，安全终审
后的最终 `make quality` 已通过。只允许提交阶段 07 差异；提交后停止，
阶段 08 保持 `NOT_STARTED`。
