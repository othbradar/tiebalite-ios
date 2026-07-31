# ADR-0011：本地 Proto 来源与 SwiftProtobuf 精确锁

- 状态：Accepted
- 日期：2026-07-31
- 决策者：项目负责人在阶段 07 当前任务中明确授权
- 关联阶段：07
- 补充：ADR-0006 的 schema 权利门，仅限本地/个人/非商业项目范围

## 背景

ADR-0006 要求把 SwiftProtobuf 自身许可证与输入 schema 权利分开判断。阶段
07 checkpoint 时，项目仍因 Android schema 的逐文件来源、GPLv3 与 README
非商业声明关系不明而停止生成。项目负责人随后明确给出当前项目政策：本地、
个人、非商业开发可以直接从锁定的只读 Android submodule 生成所需最小闭包；
公开分发、App Store、商业使用仍未获批准。

该政策是项目范围决定，不是法律结论，也不能外推到其他 commit、目录、fork
或外部 protobuf 合集。

## 决策

### Schema 来源

阶段 07 只允许一个输入来源：

```text
References/TiebaLite-Android
commit 5545326b2a8e0d784b2f3dfbcb219c7b121e61c2
app/src/main/protos/Personalized.proto
```

以及 `protoc` 实际解析出的 50 个传递依赖，总计 51 个文件。每个文件的相对
路径、SHA-256、root/direct/transitive 关系和直接 import 固定在
`Config/Protobuf/Personalized.inputs.tsv`。生成脚本必须同时验证 submodule
commit、clean 状态、文件 hash 与 `protoc --dependency_out` 闭包。

- 不把 `.proto` 复制进 iOS 源树；生成器直接只读 submodule。
- 不读取或使用 `n0099` 作为生成输入、fixture 输入或 schema 替代来源。
- 不生成其余 270 个与首个 P0 closure 无关的 schema。
- public distribution、App Store 与商业构建继续为 `BLOCKED`；进入这些范围
  前必须有新的权利/notice 决策。

### SwiftProtobuf 与工具锁

- runtime/package：Apple SwiftProtobuf `1.38.1`
- official URL：`https://github.com/apple/swift-protobuf.git`
- revision：`55d7a1cc5666b85c13464aea1c4b4a90feccb4c8`
- canonical lock：`Config/SwiftPM/Package.resolved`
- generator：`protoc-gen-swift 1.38.1`
- descriptor compiler：`protoc 35.1`
- 生成选项：
  `Visibility=Public,FileNaming=FullPath,UseAccessLevelOnImports=false`

SwiftProtobuf 本地 checkout 的 `LICENSE.txt` 是 Apache-2.0，并包含 Runtime
Library Exception。该许可审查只覆盖 SwiftProtobuf runtime/generator，不
覆盖 Android schema、服务 API、品牌或内容。

生成工程的 lock 只能由 canonical lock 单向 materialize。resolve/build/test
使用 `-onlyUsePackageVersionsFromResolvedFile` 与 `-skipPackageUpdates`，并在
完成后重新逐字节比较。不得使用 branch、range、local package 或 build
plugin 绕过 exact pin。

### 生成代码与 Swift 6 并发

SwiftProtobuf 1.38.1 对当前闭包中的 10 个复杂 copy-on-write message 自动
生成 `@unchecked Sendable`。只接受以下受控例外：

1. 该标记只能存在于 `Generated/Protobuf/*.pb.swift` 的确定性生成输出；
2. 10 个允许文件及全部生成 hash 由静态门禁和生成校验锁定；
3. 手写 App/Core/Test 源码继续禁止 `@unchecked Sendable` 与
   `@preconcurrency import`；
4. message 只在同步 decode/map 边界内创建、读取和局部复制，不在多个 task
   间共享可变实例，也不进入 domain、Feature 或 View；
5. 跨结构化任务只返回普通 `Sendable` 领域值，回归测试覆盖该边界。

generated target 是内部静态库 `GeneratedProtobuf`。只有
`Sources/Core/TiebaAPI/PersonalizedProtocol.swift` 可导入它与
SwiftProtobuf；App/Features/DesignSystem/InteractionKit 禁止导入或引用
生成类型。

### Fixture 与证据等级

首个 binary fixture 由独立 JVM `DynamicMessage` 生产器生成：

- Java/Javac 21.0.10；
- `com.google.protobuf:protobuf-java:4.35.1`；
- 同一锁定 descriptor closure；
- producer、runtime hash、fixture hash 和清理说明均 tracked。

protobuf-java 只存在于 ignored development cache，不进入 source tree 或 App。
`make bootstrap-fixture-tools` 只从
`https://repo.maven.apache.org/maven2/com/google/protobuf/protobuf-java/4.35.1/protobuf-java-4.35.1.jar`
下载，并同时校验 published SHA-1 与 locked SHA-256。质量门禁不发网络请求；
cache 缺失、symlink 或 hash 错误都 fail closed，不能降级为仅 protoc 自证。

所有 tracked/default 生成目标在任何 mkdir/delete/write 前执行 lexical +
realpath containment，并拒绝允许根以下的 symlink 路径组件；已有 Proto output
tree 中出现任意 symlink 也会阻断生成。

它只能标记为 `CROSS_LANGUAGE_GENERATED`。它证明 pinned schema 在 JVM 与
SwiftProtobuf 之间的 wire/presence/unknown-field 测试路径，不证明真实服务
器、匿名能力、响应 MIME、分页终止或错误码分布。

## 选择理由

直接从 pinned submodule 生成能保留完整 provenance，又避免把 schema 副本
散落到 iOS 树。exact runtime/generator/tool/manifest/output hash 使生成可复验。
JVM fixture 独立于 Swift producer，能发现同一种 Swift 实现自证的盲点。

全量 321 schema、`n0099` 输入、手写猜测 schema、浮动 SwiftPM 版本或真实
live probe 都不满足当前最小范围和证据要求。

## 迁移、退出与回滚

若 local policy 撤销、input hash/闭包漂移、生成不确定、Swift 6 边界失败或
需要 public/commercial distribution，则回滚：

1. 删除 Personalized wire adapter 和跨语言 fixture；
2. 从 `project.yml` 移除 `GeneratedProtobuf` 与 SwiftProtobuf；
3. 删除 canonical lock、生成输出和 schema manifest；
4. production 保持 `DisabledHTTPClient`，回到通用 fixture-only transport；
5. 另立 ADR 选择 clean-room schema 或完成可分发权利审查。

不得通过放宽 strict concurrency、取消 hash/lock 校验、保留两套 codec 或让
UI 直接消费生成类型来规避回滚。

## 验收条件

- 51 文件闭包、输入 hash、两次生成和 tracked output 一致；
- exact package lock/revision 与生成工程 lock 一致；
- JVM fixture 两次生成与 tracked bytes 一致；
- exact JVM tool cache 可重复 bootstrap，缺失/错误时 verifier fail closed；
- default/custom output containment 与 ancestor/tree symlink canary 通过；
- request golden、presence、unknown field、raw `999`、empty/malformed、
  server/missing-data 与 mapper tests 通过；
- static gate 只允许 exact package、exact generated location 和唯一 Core
  adapter，并继续证明 production transport disabled；
- 完整阶段 07 质量门禁通过。
