# 来源与许可证记录

状态：`LOCAL_PERSONAL_NONCOMMERCIAL_PROTO_USE_APPROVED`；
`PUBLIC_APP_STORE_COMMERCIAL_DISTRIBUTION_BLOCKED`

本文件记录阶段 01 可证实的来源和边界，不构成法律意见。任何分发、上架、商业使用或文件级复用决定都需要项目负责人单独批准。

## 阶段 07 本地项目决策

- 重新核对 Android reference 仍锁定且 clean 于
  `5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`。
- 项目负责人在当前任务中明确批准：仅对本地、个人、非商业项目，可直接从
  上述 pinned、read-only submodule 的 `app/src/main/protos` 生成首个 P0
  Personalized 最小闭包。
- 实际闭包为 51 个文件；路径、hash、import 关系在
  `Config/Protobuf/Personalized.inputs.tsv`，没有复制 `.proto` 到 iOS 树。
- `n0099` 没有作为直接或间接生成输入；其链接不构成来源授权。
- 已生成 51 个 Swift 文件并引入 exact SwiftProtobuf 1.38.1；首个 250-byte
  JVM cross-language fixture 是完全构造且脱敏的，不是 live response。
- 未运行 live probe、未使用账号或 Cookie。匿名服务端成功仍为 `UNKNOWN`。
- 公开分发、App Store、商业使用、notice/源码义务和 fork/upstream 权利链仍
  未关闭；任何范围扩大必须新决策。此处记录项目政策，不构成法律意见。

## 阶段 11 本地 PBPage 扩展

- ADR-0013 在相同的本地、个人、非商业边界内，把锁定输入从 Personalized
  51-file closure 扩展为 Personalized + PBPage 三个 root 的 126-file union；
  PBPage 自身 closure 为 125，与 Personalized 重叠 50，因此新增 75 个生成文件。
- 路径、SHA-256、root/import 关系继续记录在历史命名的
  `Config/Protobuf/Personalized.inputs.tsv`；生成器直接只读同一 pinned、clean
  Android submodule，没有把 `.proto` 复制进 iOS 树，也没有使用 `n0099`。
- 阶段 11 的 PBPage mapper 测试只构造 Swift Proto response；没有把真实服务端
  响应、正文、图片 URL、用户字段或 token 保存为 fixture。
- Debug-only 无 session Personalized Probe 观察到一次 HTTPS/Proto 可达并映射出
  67 项，但最终锁定请求返回合法空页，PBPage Probe 未发送。API 可达性既不构成
  schema 来源授权，也不改变服务 API、内容、品牌或分发边界。
- 公开分发、App Store、商业使用、notice/源码义务、fork/upstream 权利链和
  Proto 文件级 provenance 继续 `BLOCKED/UNKNOWN`；本轮不扩大许可结论。

## Reference 身份

- submodule path：`References/TiebaLite-Android`
- `.gitmodules` URL：`https://github.com/zzc10086/TiebaLite.git`
- submodule remote `origin`：同上
- 审计 branch：`4.0-dev`
- 审计 commit：`5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`
- lock：`References/TiebaLite-Android.lock`
- 审计前后状态：工作树与索引 clean

`CODE_EVIDENCE`：README badge 指向 `HuanCheng65/TiebaLite`，而 submodule URL 指向 `zzc10086/TiebaLite`。这可能是 fork、迁移或镜像关系，但阶段 01 没有联网追踪历史，因此确切上游/版权链为 `UNKNOWN`。

## 仓库级许可与声明

`CODE_EVIDENCE`：

- 根 `LICENSE` 是 GNU General Public License version 3 文本。
- README 明确把 Tieba Lite 描述为非官方客户端。
- README 明确写有“本软件及源码仅供学习交流使用，严禁用于商业用途”。
- README 友情链接包含 `n0099/tbclient.protobuf`，但 reference 的 `.proto` 文件没有统一文件头说明每个 schema 的具体来源。

结论：

1. Android reference 整体按 GPL-3.0 审慎处理。
2. README 的非商业声明是额外权利风险信号；它与 GPL 文本的精确关系、是否来自所有权利人以及可执行范围为 `UNKNOWN`。
3. 未经明确评估，不得假定可以把 Android Kotlin/Java/Compose、资源、图片、图标或 Proto 文件复制进未来可分发 iOS 产品。
4. 不得把“开源可读”误写为“可闭源商业复用”。

## 阶段 01 实际使用

本阶段只做：

- 静态阅读路径、symbol、call site 和 state transition；
- 记录 endpoint method/path、message/field 名和 import 关系；
- 归纳产品语义、风险和待验证项；
- 引用少量稳定符号名以便审计复现。

本阶段没有：

- 修改 Android submodule；
- 复制 `.proto`、Kotlin、Java、Compose 或资源文件；
- 运行 Wire 生成；
- 生成 Swift；
- 复制图标、图片、字符串资源或 UI 布局；
- 把 Android 依赖带入 iOS；
- 进行真实网络或账号抓取。

## 允许的参考层次

在后续明确许可证决策之前：

| 参考方式 | 默认边界 | 要求 |
|---|---|---|
| 观察用户任务和状态语义 | 允许 | 用独立 iOS 设计与代码表达；保留证据路径 |
| 记录公开 protocol fact（path、field number、wire shape） | 审慎允许用于规格 | 必须有本地源码/脱敏运行证据；不凭字段名猜语义 |
| 独立实现 mapper/state machine | 允许 | 不逐行翻译；用 fixture/tests 定义行为 |
| 从 pinned submodule 生成 Personalized + PBPage 三-root/126-file union | 仅本地/个人/非商业允许 | ADR-0011/0013；exact commit/path/hash/import lock；不复制 `.proto`；公开分发仍阻塞 |
| 使用 `n0099` 或其他外部 schema 集 | 禁止 | 不作为直接/间接输入；需要独立来源与权利决策 |
| 复制 Kotlin/Java/Compose | 禁止默认复制 | 需要独立授权和完整 GPL 影响评估 |
| 复制 UI 资源/图标/品牌 | 禁止 | 产品章程禁止造成官方授权误导 |
| 复制 Android 第三方代码 | 禁止默认复制 | 必须逐文件审计其独立许可证和 notice |

## Proto 来源边界

`CODE_EVIDENCE`：

- reference 有 321 个 `.proto`。
- README 仅链接一个外部 protobuf 合集，没有逐文件 provenance。
- schema 没有统一版权/许可证 header。
- Android 使用 Wire 生成 Kotlin；生成物未跟踪。

风险：

- 文件级复制可能构成受 GPL 或其他上游许可约束的派生材料。
- 生成 Swift 也可能继承输入 schema 的 notice/许可义务。
- field 名/number 是兼容性事实，但具体表达的版权边界不能在编码任务中自行裁定。
- 321 个文件全量导入会把与 P0 无关、来源不明的材料带入项目。

后续可选路径：

1. **复用最小 schema 闭包**：先完成版权链和 notice 审查；保留来源、commit、变更标记与许可证。
2. **独立最小兼容 schema**：基于脱敏 wire fixture、公开可观察协议事实和必要字段编写；记录 clean-room 输入/输出。
3. **暂不接真实 Proto**：fixture/mock 先行，直到权利和协议均清楚。

采用哪条路径必须是显式 ADR/法律决策，阶段 01 不作选择。

## 第三方组件线索

### iOS 实际引入：SwiftProtobuf

- 来源：`https://github.com/apple/swift-protobuf.git`
- exact version：`1.38.1`
- exact revision：`55d7a1cc5666b85c13464aea1c4b4a90feccb4c8`
- 许可证：package checkout 的 `LICENSE.txt` 为 Apache License 2.0，并含
  Runtime Library Exception。
- canonical lock：`Config/SwiftPM/Package.resolved`
- owner：`GeneratedProtobuf` 与唯一 Core/TiebaAPI adapter；UI 禁止引用。
- 退出方式：见 ADR-0011；移除 generated target、adapter、package 与 lock
  后可回到 fixture-only transport。

以上仅覆盖 SwiftProtobuf 自身，不能替代 Android schema、API/内容/品牌的
来源和分发判断。

### 开发期 fixture producer：protobuf-java

- Maven Central artifact：`com.google.protobuf:protobuf-java:4.35.1`；
- exact URL、published SHA-1 与 local SHA-256 固定在
  `Config/ToolVersions.env`；
- 只存于 ignored `.build/FixtureTools`，用于 synthetic JVM
  `DynamicMessage` producer，不链接、不复制进 App 或 Release bundle；
- bootstrap 下载不等于项目再分发该 jar；若未来 vendoring/CI 镜像分发，
  必须另行补许可证与 notice 审查。

reference Gradle 声明 Wire、Compose Destinations、Room、Retrofit/OkHttp、Sketch/ZoomImage 等依赖。它们只解释 Android 实现，不自动成为 iOS 依赖候选。

`CODE_EVIDENCE`：少数 Java 文件有独立 Apache-2.0 文件头，例如 transformations 内部代码和 Compose WebView 派生文件。

`INFERENCE`：仓库可能包含混合来源，仓库级 LICENSE 因而不能替代逐文件 provenance、授权和 notice 审计。

后续若复用任意文件，至少记录：

- 原始 repository URL、branch、commit、path；
- 文件头和仓库 LICENSE；
- 修改说明；
- 依赖和生成物许可证；
- notice/源码提供义务；
- 商业/分发限制；
- 替换/退出方案。

## 品牌、内容与服务边界

- Tieba/百度名称、服务和协议不因参考源码可读而获得官方授权。
- 产品必须继续明确“非官方”，不得使用官方图标或暗示授权。
- API 可达性不等于允许使用；服务条款、账号、内容版权、隐私和 App Store 审核仍需独立确认。
- 不得绕过 TLS、认证、风控或平台限制。
- 真实 fixture 只使用公开测试内容或专用测试账号并深度脱敏。

## 发布前阻塞项

以下任一未关闭时，不得声明可公开分发/商业使用：

1. submodule fork/upstream 与权利人链不明。
2. README 非商业声明未解释。
3. Proto 文件来源与可复用方式未决定。
4. 服务 API 使用权、登录方式和品牌边界未确认。
5. 所有复制/生成材料的 notice 和源码义务未建立。

## 交叉引用

- 行为与代码证据：`Docs/Audits/ANDROID_REFERENCE_AUDIT.md`
- endpoint：`Specs/API_EVIDENCE.md`
- Proto 最小闭包：`Specs/PROTOBUF_MAP.md`
- 产品发布边界：`Specs/00_PRODUCT_CHARTER.md`
- 未知项：`Specs/UNKNOWN_BEHAVIORS.md`
