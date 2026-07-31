# ADR-0001：工程生成与 target 边界

- 状态：Accepted
- 日期：2026-07-31
- 决策者：阶段 02 架构决策
- 关联阶段：02、03、07

## 背景

仓库在阶段 02 仍没有 `project.yml`、Xcode project、Swift 源码或测试
target。根规则已指定 XcodeGen 为工程声明真相，并要求 Swift 6、Complete
严格并发检查、iOS/iPadOS 18.0+，同时禁止为了形式上的“模块化”预建大量
空 target。

当前可复现工具基线为 Xcode 26.6、Swift 6.3.3、XcodeGen 2.45.4、
SwiftLint 0.65.0、xcbeautify 3.2.1。`Brewfile` 是安装清单，不是精确版本
锁。

## 必须满足的约束

- `project.yml` 是唯一手写工程声明；不手工维护 `.pbxproj`。
- scheme、test plan、资源、编译配置和最低系统版本均显式声明。
- 初期目录边界优先于编译 target 边界。
- 生成必须离线可重复；质量脚本不得依赖 IDE 中的隐式状态。
- Xcode、XcodeGen 和 SwiftLint 版本差异会改变构建或门禁语义，必须阻断；
  xcbeautify 仅改变输出格式，缺失或版本偏差只警告。
- 阶段 02 不创建任何工程或源码。

## 候选方案

### A：XcodeGen 声明、生成工程不提交

- 优点：无 `.pbxproj` 合并噪声；声明可审查；每次从同一输入生成。
- 缺点：首次打开前必须安装 XcodeGen 并运行生成。
- 风险：工具版本漂移可能改变输出；脚本与 test plan 可能选择不一致。
- 验证方式：同一输入连续生成两次，第二次无声明或工程语义差异；所有
  Make target 使用同一 scheme/test plan。

### B：提交生成的 `.xcodeproj`

- 优点：没有 XcodeGen 的消费者也可直接打开。
- 缺点：声明与生成物形成双重真相；容易出现手工修改和生成噪声。
- 风险：CI 只能通过再生成 diff 检测漂移。
- 验证方式：每次提交前生成并要求生成物 diff 为空。

### C：阶段 03 先拆多个 framework/package

- 优点：编译器能强制部分依赖方向。
- 缺点：空模块、scheme 和构建设置数量立即膨胀。
- 风险：循环依赖、测试宿主复杂化和无业务价值的 public API。
- 验证方式：每个 target 必须先证明独立生成、编译隔离或复用价值。

## 决策

选择 A。

阶段 03 只建立三个实际 target：

1. `TiebaLite` App target。
2. `TiebaLiteTests` 单元/集成测试 target。
3. `TiebaLiteUITests` UI 测试 target。

`App/`、`Sources/Core/`、`Sources/DesignSystem/`、
`Sources/InteractionKit/`、`Sources/Features/` 先作为同一 App target 内的
逻辑模块，以目录、可见性、构造根、静态扫描和审查维持边界。阶段 07
只有在 Proto 来源/许可证、最小 import 闭包与生成门禁关闭后，才允许增加
唯一内部 `GeneratedProtobuf` target；不得提前创建空 target。

以下文件在后续对应阶段成为手写/外部取得的 canonical 输入：

- `project.yml`、共享 scheme/test plan 声明；
- 编译配置文件和显式资源列表；
- 工具版本清单；
- 引入 SwiftPM 后的 canonical `Config/SwiftPM/Package.resolved`；
- 若 Proto 路径获准，最小 schema、来源/import manifest，以及
  generator/runtime 版本。

生成的 `.xcodeproj`、`.xcworkspace` 和 DerivedData 不提交。Proto
`.pb.swift` 是允许提交、禁止手改的 tracked derived output，不是 canonical
输入；生成门禁必须从 canonical 输入写入临时目录并与已提交输出逐字节
比较。`make generate` 每次重建工程。引入 SwiftPM 后，生成脚本把 canonical
lock materialize 到生成工程的
`TiebaLite.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`，
执行 resolve 后再与 `Config/SwiftPM/Package.resolved` 逐字节比较；两者不
一致即失败，不把生成工程内 lock 当第二真相。以上路径和机制均是后续阶段
契约，阶段 02 不创建它们。阶段 03 增加工具版本清单并由 doctor 检查：

- Xcode/XcodeGen/SwiftLint 与锁定值不一致：FAIL；
- xcbeautify 缺失或版本不同：WARN，并回退原始 `xcodebuild` 输出；
- `Brewfile` 继续只负责声明安装工具，不把它误称为版本锁。

初始工程必须显式设置：

- Swift 6 语言模式与 Complete strict concurrency；
- iOS/iPadOS 18.0 deployment target；
- Debug/Release/UITesting 配置；
- 无签名 Simulator build；
- App、unit、UI 的共享 scheme 与同一 canonical test plan。

## 为什么不是其他方案

B 只有在未来存在无法安装 XcodeGen 的外部消费者时才有价值；届时需新 ADR
说明双重真相和漂移检查。C 在当前没有编译隔离收益，违反“小规模先用清晰
目录和协议边界”的仓库规则。

## 迁移/退出成本

逻辑目录未来可逐一提升为 target，前提是 public API、依赖方向和构建时间
收益可量化。提升不能改变领域模型或 Feature 状态语义。若退出 XcodeGen，
必须以 superseding ADR 提供等价的可重复声明和 drift gate。

## 验收与回滚条件

阶段 03 至少证明：

- 连续两次 `make generate` 稳定；
- `xcodebuild -list` 中 target/scheme/test plan 与声明一致；
- App、unit、UI 和 iPad build 命令选择一致；
- Release 不包含 TestSupport/launch scenario；
- `git status` 不出现生成工程噪声；
- 无手工 `.pbxproj` 差异。

若同输入生成不稳定、资源/scheme 丢失、无法无签名构建，回退到最近绿色的
`project.yml` 和工具版本基线，不手改生成工程。
