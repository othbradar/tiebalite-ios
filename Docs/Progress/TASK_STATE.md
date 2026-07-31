# TASK_STATE

- 当前阶段：04
- 状态：PASSED_WITH_ENVIRONMENT_LIMITATION
- 当前分支：`main`
- 基线 commit：
  `2885b747369d5e198a5b53d6ebd406bde39661fb`
  （阶段 03 绿色提交，`build: complete stage 03 project scaffold`）
- 允许修改范围：阶段 04 的最小 `AppEnvironment`/composition root、
  `Sources/Core` 小型依赖协议与安全日志边界、`TestSupport` 确定性
  harness/fixture、对应 `Tests`/`UITests`、XcodeGen target/config 隔离、
  `Makefile`/`scripts` 质量门禁，以及本文件。
- 禁止修改范围：Android submodule/gitlink、真实贴吧 endpoint/网络请求、
  登录/Cookie/Keychain、业务 Feature/页面/导航、Pager、MediaViewer、
  Protobuf 生成、生产缓存实现、未批准依赖，以及阶段 05 或后续内容。
- 已读取规则/规格/ADR：根目录及 `App`、`Sources/Core`、`Resources`、
  `TestSupport`、`Tests`、`UITests`、`Specs`、`Docs` 的适用
  `AGENTS.md`；`Prompts/04_DETERMINISTIC_TEST_HARNESS.md`；
  `Specs/MODULE_MAP.md`、`Specs/PROJECT_PLAN.md`、
  `Specs/DEPENDENCY_POLICY.md`；ADR-0002、0006、0007、0008、0009、
  0010；上一版 `Docs/Progress/TASK_STATE.md`。已显式使用
  `.agents/skills/xcode-quality-gate/SKILL.md`，并采用三个只读子代理
  对并发、UI harness、工程/Release 隔离的复审建议；全部写入仅由主代理
  完成。

## 阶段 04 基线与授权

- 用户授权提交阶段 03 后，精确暂存阶段 03 差异并运行
  `git diff --cached --check`，随后
  `git commit -m "build: complete stage 03 project scaffold"` 成功创建
  `2885b747369d5e198a5b53d6ebd406bde39661fb`；提交后
  `git status --short` 为空。
- 阶段 04 开始前基线：
  - `make doctor`：0 failure、0 warning。
  - `make build`：通过，日志
    `Artifacts/TestResults/20260731-123859-82765-build.log`。
  - `make test-unit`：3/3 通过，结果
    `Artifacts/TestResults/20260731-123906-82874-unit.xcresult`。
  - `make test-ui-smoke`：1/1 通过，结果
    `Artifacts/TestResults/20260731-123931-83415-ui-smoke.xcresult`。
  - Android reference clean 且仍锁定
    `5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`。
- 工具基线未漂移：macOS 26.6、Xcode 26.6（17F113）、
  Swift 6.3.3、Git 2.50.1、XcodeGen 2.45.4、SwiftLint 0.65.0、
  xcbeautify 3.2.1。

## 当前实现与行为

- 新增不可变 `Sendable AppEnvironment` 和 `@MainActor
  AppCompositionRoot`。可替换依赖为 `AppClock`、`IDGenerator`、
  `HTTPClient`、`SessionProviding`、`ImageLoading`、`DataCaching`、
  `DiagnosticsClient`。正常 Debug/Release 使用系统时钟、单调 ID 及
  disabled/no-store/signed-out 安全实现，不创建 URLSession、真实会话、
  Keychain 或生产图片/磁盘缓存。
- `HarnessMockHTTPClient` 支持显式成功、类型化错误、无限可控延迟、
  取消和按 call ID 乱序完成；`HarnessLatestValueProbe` 可构造旧响应晚到
  且拒绝覆盖新代次。`HarnessControlledClock`、barrier 和 sequence ID
  不依赖墙钟、随机数或 `sleep()`。
- continuation 使用 `Synchronization.Mutex` 保护的同步 terminal gate。
  取消与完成以第一个 terminal 操作为线性化点，只恢复一次；预取消保持
  `CancellationError`，取消先于 `succeed`/`advance`/`release` 时不会被
  成功覆盖；计数等待器在预取消和已注册两种时序下都可取消并移除，
  不遗留永久 continuation。
- 固定且唯一的 launch 参数解析器支持六个最小场景：
  `app.empty-shell`、`network.offline`、`network.slow`、
  `session.signed-out`、`session.signed-in-fixture`、`session.expired`。
  缺失、重复、未知或非精确值均 fail closed 为固定
  `invalid-scenario`，不回退 production 环境、不回显原值。
- UI test 公开启动入口只接受类型化场景或一个固定未知场景 canary。
  helper 使用条件等待和稳定 identifier；present、absent、label mismatch
  失败均附固定场景截图及脱敏摘要。摘要只列白名单 identifier，label
  不在固定安全集合时替换为 `<redacted>`，不附原始 hierarchy、参数或错误。
- fixture manifest 记录逻辑 ID、相对路径、格式、用途、synthetic 来源、
  sanitized 标记与 SHA-256。loader 覆盖 JSON、opaque binary Protobuf、
  SVG image、缺失、畸形、hash mismatch、重复 ID、路径穿越和未知 ID；
  错误只暴露安全逻辑路径，未知 ID 不回显输入。
- diagnostics 只接收类型化事件与白名单 metadata；Cookie、Authorization、
  token、BDUSS、STOKEN、password、device ID、URL 和 raw error 均被丢弃。
  `OSDiagnosticsClient` 是唯一允许直接使用 OSLog 的后端。
- App Debug/Release 均不编译 LaunchScenario/TestSupport；App UITesting
  仅编译 `TestSupport/LaunchScenarios`；Unit target 编译 harness 与
  `FixtureLoader` 并复制 `Fixtures`；UI target 仅编译 `UITests`。
  `UITESTING` 从全局 xcconfig 移到 App 的 UITesting target config，
  Unit 使用独立 `TEST_SUPPORT`。
- 新增静态源策略及正反 canary，阻止直接 console/OSLog、raw
  `localizedDescription`、`@unchecked Sendable`、
  `nonisolated(unsafe)`、`@preconcurrency`、`Task.detached`、共享
  singleton、直接 `Task.sleep`/`asyncAfter`，并阻止测试使用当前时间、
  `ContinuousClock()`、随机 UUID/随机 API。唯一 OSLog 后端和固定 epoch
  样本作为通过 canary；OSLog 后端只豁免直接 OSLog 构造，文件内
  console 输出和 raw error 仍由反向 canary 证明会被拒绝。
- 新增 Release 与 UITesting 结构检查：实际检查 SwiftFileList、fixture
  bundle、binary strings、demangled symbols 和正向 canary，避免仅根据
  `project.yml` 声称隔离。XcodeGen 重复 group warning 已通过统一
  `group: TestSupport` 消除。

## 行为优先与失败证据

- 首次尝试读取不存在的
  `Prompts/04_TEST_HARNESS_AND_FIXTURES.md` 失败；随后通过仓库文件清单
  定位并完整读取正确文件
  `Prompts/04_DETERMINISTIC_TEST_HARNESS.md`。
- 在实现 LaunchScenario/harness 前运行 `make test-unit`，退出 65；
  `Artifacts/TestResults/20260731-125807-85182-unit.log` 明确报告
  LaunchScenario 类型/符号缺失，证明测试先于实现失败。
- 首版 continuation 实现运行 `make test-unit` 退出 65；
  `Artifacts/TestResults/20260731-130243-85464-unit.log` 报两处
  `CheckedContinuation<Void, Error>` 泛型无法推断；显式类型后修复。
- 下一次 `make test-unit` 已执行 21 个用例，其中 18 通过、3 个
  FixtureLoader 用例失败；`20260731-130301-85556-unit.xcresult`
  证明根因是 `Fixtures` 未进入 test bundle。将 fixture 作为 XcodeGen
  `sources` 中 `buildPhase: resources` 的 folder resource 后修复。
- 首次在沙箱内复跑 Simulator 测试退出 70；
  `Artifacts/TestResults/20260731-130537-86055-unit.log` 明确显示
  CoreSimulatorService 日志权限/连接不可用。按权限规则提权复跑，
  `20260731-130659-86166-unit.xcresult` 的 21/21 用例通过。
- 首次使用 `xcrun xcresulttool get test-results tests ...` 在沙箱内因
  无权写 TestReport 失败；只读提权重跑成功，确认当时仅有上述三个
  fixture bundle 失败。
- 引入同步 terminal gate 后的首次 unit build
  `Artifacts/TestResults/20260731-132511-89223-unit.log` 退出 65：
  给 folder resource 同时设置 parent group 导致路径被解析为仓库根
  `Fixtures`。移除资源的 group override、保留 LaunchScenario 的统一
  group 后修复；重新生成的工程不再有 malformed group warning。
- 首次 `make lint` 退出 2：11 个 collection trailing comma 和 1 个
  Data→String 规则违规；机械修正后重跑为 0 violation/0 serious。
- 首次独立运行 `scripts/verify_ui_test_isolation.sh` 退出 1：
  Xcode 在 SwiftFileList 内容不变时不会刷新 mtime，时间戳规则误报。
  删除脆弱 mtime 假设，改用必须包含本阶段新增源码/二进制 canary 的
  内容正控；重跑通过。
- 首次逐个检查未跟踪文件 whitespace 的 zsh 循环误用变量名 `path`，
  覆盖了 zsh 的特殊 PATH 数组，因而重复报告 `git: command not found`
  并退出 1；改用 `/bin/bash` 和 `candidate_file` 变量后重跑为
  0 whitespace failure。
- 最终只读复审用临时 probe 发现 OSLog 后端路径的豁免过宽，导致该文件内
  console/raw error 可绕过扫描；同时发现 disabled/fixture image loader
  未优先检查预取消。已将路径豁免缩小到仅 `direct-oslog`，新增后端路径
  反向 canary，并为两种 image loader 增加取消检查。另补 registered
  observer 取消清理测试；修正后 targeted unit 与完整 quality 均通过。

## 最终执行命令与逐项结果

- `make generate`：通过；fixture 位于 Unit Copy Resources phase，
  LaunchScenario group 唯一；`xcodebuild -project
  TiebaLite.xcodeproj -list` 列出预期 3 target/3 config/1 scheme，
  无 malformed project warning。该 `-list` 在沙箱内虽退出 0，但仍输出
  CoreSimulatorService 无权限的环境噪声。
- `bash -n scripts/swift_source_policy.sh
  scripts/verify_static_policy_canaries.sh
  scripts/verify_release_isolation.sh
  scripts/verify_ui_test_isolation.sh ...`：通过。
- `make static-canaries`：通过，每个禁止样本均被对应 rule 拒绝，
  唯一 OSLog 后端与固定时间样本通过。
- `make forbidden`：0 error group、0 warning group。
- `make secret-scan`：通过；扫描范围已包含 Config、project.yml 和
  `scripts/project.env.example`。
- `make lint`：最终 30 个 Swift 文件，0 violation、0 serious；仍只有
  已知的 SwiftLint 配置提示
  `implicitly_unwrapped_optional` 未在 `opt_in_rules` 启用。
- `make test-unit`：补齐最终取消回归后 28/28 通过，结果
  `Artifacts/TestResults/20260731-135005-97574-unit.xcresult`。
- `make test-ui-smoke`：六个白名单场景加未知 fail-closed 共 7/7 通过，
  结果
  `Artifacts/TestResults/20260731-132928-91116-ui-smoke.xcresult`。
- `scripts/verify_ui_test_isolation.sh`：通过；UITesting App/Unit/UI
  target 的正负成员关系和 exact binary canary 均符合预期。
- `make release-isolation`：Release build 通过，随后 SwiftFileList、
  App bundle、strings 与 demangled symbols 隔离检查通过；日志
  `Artifacts/TestResults/20260731-133132-91629-release-build.log`。
- 将 `ui-test-isolation` 调整为独立调用时也先准备 unit/UI 产物后，再次
  运行 `make quality`；最终阶段出口通过：
  - instruction/skill/reference integrity、工具版本、两次 clean
    XcodeGen、forbidden、static canaries、secret scan、SwiftLint、
    generic Debug build、`git diff --check` 均通过；
  - 最终 unit 为 28/28，通过结果
    `Artifacts/TestResults/20260731-135041-98542-unit.xcresult`；
  - 最终 UI smoke 为 7/7，通过结果
    `Artifacts/TestResults/20260731-135058-98789-ui-smoke.xcresult`；
  - iPad build 通过，日志
    `Artifacts/TestResults/20260731-135158-99100-ipad-build.log`；
  - Release build 与隔离复验通过，日志
    `Artifacts/TestResults/20260731-135159-99118-release-build.log`；
  - 最终输出 `Quality gate completed.`。
- 最终日志扫描未发现 `malformed project`、`member of multiple groups`、
  `Test Failed` 或编译 `error:`；Android reference 仍 clean 且 SHA
  未变化。
- `git diff --check` 及逐个未跟踪文件
  `git diff --no-index --check /dev/null <file>`：最终均为
  0 whitespace failure。
- 最终 `make doctor`：0 failure、0 warning；Simulator 设备可见、规则链、
  repo skills、脚本语法、工具版本和 Android reference 均通过。

## 回归覆盖

- 依赖替换：clock、ID、HTTP、session、image、cache、diagnostics 均通过
  `AppEnvironment` existential 实际调用。
- HTTP：显式成功、立即错误、受控延迟、任务取消、预取消、取消先于完成、
  逆序完成、旧代次拒绝覆盖。
- Image：disabled 与 fixture loader 的预取消均保持
  `CancellationError`，不映射为 unavailable/missing fixture。
- 并发控制：固定 epoch、手动 advance、barrier release、取消先于
  advance/release、count waiter 预取消、registered waiter 取消清理、
  确定性 ID exhaustion。
- Fixture：JSON decode、binary Protobuf/image load、缺失、畸形、hash
  mismatch、duplicate ID、path traversal、unknown ID 脱敏。
- Diagnostics：typed event、metadata allowlist，以及敏感键/URL/raw error
  移除。
- UI：六个最低 launch scenarios 及 unknown fail-closed；两轮均全绿。
- 结构：Debug/Release/App UITesting/Unit/UI target 成员关系与 Release
  资源/符号隔离。

## 新增或变更的动画、手势、overlay、依赖

- 动画：无。
- 手势：无。
- overlay/presentation：无。
- 生产第三方依赖：无。`Synchronization`、Foundation、OSLog、SwiftUI、
  UIKit 均为系统/Swift 工具链模块；未修改依赖锁。

## UNKNOWN / 剩余风险

- 本机只有 iOS 26.5 Simulator runtime。最低部署版本 18.0 已由 build
  settings 和编译验证，但未在 iOS/iPadOS 18.x runtime 上执行，因此状态
  保留 `PASSED_WITH_ENVIRONMENT_LIMITATION`。
- iPad 仅验证 compatible build；旋转、分屏及 iPad UI 流程属于后续明确
  阶段，本阶段没有业务 UI 可执行这些验收。
- UI smoke 全绿，因此“失败时实际把截图/摘要写入 xcresult”的分支未通过
  故意失败的 UI 用例触发；本阶段由私有类型化启动 API、固定场景和静态
  allowlist 审查其安全性。
- 静态扫描是高置信规则而非完整数据流/taint 分析；后续新增诊断字段仍需
  code review 与 redaction 单测。
- 隔离脚本用源码/二进制正控避免空跑，但不使用 Xcode 不可靠的生成文件
  mtime。应通过 `make release-isolation` / `make ui-test-isolation`
  调用，让 Make 依赖先生成本轮 build/test 产物；直接单跑脚本可能消费
  已有 DerivedData。
- `Synchronization.Mutex` 的 terminal gate 已在当前 Swift 6.3.3、
  iOS 26.5 Simulator 下通过严格并发编译与竞态顺序测试；未在 iOS 18.x
  runtime 单独执行。
- 真实 API、Cookie/登录、业务状态、导航、Pager、MediaViewer、Proto
  映射均仍未实现/未验证，不得从阶段 04 harness 结果推断其可用。

## 下一阶段前置条件

- 阶段 04 当前差异保持未提交；只有新的用户指令可以授权提交。
- 只有新的用户指令才可开始阶段 05。开始前必须重新读取阶段 05 提示词和
  适用规则、确认阶段 04 绿色提交及 clean baseline，并重新运行基线门禁。
- 本阶段在此停止，不创建业务页面、导航 Shell 或任何阶段 05 内容。
