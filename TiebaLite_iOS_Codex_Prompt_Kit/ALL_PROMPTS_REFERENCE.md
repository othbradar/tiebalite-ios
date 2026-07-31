# TiebaLite iOS Codex 全部提示词参考

> 本文件用于搜索、审阅和离线保存。**不要把全文一次性粘贴给 Codex 执行。** 正确用法是安装仓库覆盖层后，按 `Prompts/README.md` 一次执行一个阶段。

# 阶段提示词索引与执行顺序

这些文件是 **Codex 桌面版中的单次任务指令**。每次只让 Codex 执行一个文件；阶段完成、质量门禁通过、`/review` 处理完并形成绿色 Git commit 后，才进入下一阶段。

## 每次发送给 Codex 的固定格式

```text
请执行 Prompts/<文件名>。
严格读取并遵守仓库根目录及目标目录适用的 AGENTS.md，并按需显式调用该提示词指定的 $skill。
当前只完成这个阶段/任务；不得开始下一个阶段，不得扩大范围。
先检查 Git 与测试基线，再给出本阶段计划，然后立即执行。
完成时报告真实运行过的命令、结果、未验证项和剩余风险。
```

## 主线顺序

| 顺序 | 提示词 | 建议运行位置 | 建议模式 | 退出门禁 |
|---:|---|---|---|---|
| 00 | `00_BOOTSTRAP_ENVIRONMENT.md` | Local | Sol/Ultra | `make doctor`，只改环境文档 |
| 01 | `01_ANDROID_REFERENCE_AUDIT.md` | Worktree 或 Local | Ultra，只读子代理 | 审计规格完整，`/review` |
| 01B | `01B_ANDROID_RUNTIME_BEHAVIOR_CAPTURE.md` | 可选独立 Worktree | Ultra + Computer Use | 原版运行证据或明确 NOT_AVAILABLE |
| 02 | `02_ARCHITECTURE_AND_EXECUTION_PLAN.md` | Local | Ultra，只读子代理 | ADR 与计划无冲突 |
| 02B | `02B_SCREEN_AND_INTERACTION_BLUEPRINTS.md` | Local | Ultra/Max | P0 每屏/每流契约获批准 |
| 03 | `03_PROJECT_SCAFFOLD.md` | Local | Max；Ultra 仅一名写入协调者 | App/build/unit/UI smoke 绿色 |
| 04 | `04_DETERMINISTIC_TEST_HARNESS.md` | Local | Max | 可模拟成功/失败/慢网/取消/乱序 |
| 05 | `05_DESIGN_SYSTEM_AND_APP_SHELL.md` | Local | Max | iPhone/iPad shell 与状态组件绿色 |
| 06 | `06_PAGER_AND_MEDIA_INTERACTION_SPIKES.md` | 独立 Worktree 推荐 | Max + Computer Use | Spike 报告明确 ACCEPTED/REJECTED |
| 07 | `07_NETWORKING_PROTOBUF_FOUNDATION.md` | Local | Max | Proto/HTTP fixture 路径绿色 |
| 08 | `08_THREAD_CONTENT_DOMAIN_AND_RENDERER.md` | Local | Max | 内容节点矩阵与 renderer 绿色 |
| 09 | `09_MEDIA_VIEWER_PRODUCTION.md` | Local | Max | 唯一生产 MediaViewer 绿色 |
| 10 | `10_RECOMMENDATIONS_VERTICAL_SLICE_FIXTURE.md` | Local | Max | 首条完整 fixture 链路绿色 |
| 10B | `10B_VISUAL_AND_INTERACTION_BASELINE.md` | Local | Max + Computer Use | 关键界面基线与交互证据冻结 |
| 11 | `11_LIVE_API_RECOMMENDATIONS_AND_THREAD.md` | Local | Max | 仅替换 Repository，fixture 无回归 |
| 12 | `12_SESSION_AND_LOGIN.md` | Local | Max | Fake 全矩阵；真实凭据仅用户手动 |
| 13 | `13_FOLLOWED_FORUMS.md` | Local | Max | 未登录/已登录/过期全部绿色 |
| 14 | `14_FORUM_HOME_AND_THREAD_LIST.md` | Local | Max | 吧页筛选/分页/返回状态绿色 |
| 15 | `15_FULL_THREAD_READER_AND_SUBPOSTS.md` | Local | Max | 完整楼层/楼中楼只读链路绿色 |
| 16A–C | P1 提示词 | 独立串行任务 | Max | 每个子阶段单独门禁/commit |
| 17 | `17_IPADOS_ADAPTATION_HARDENING.md` | Local | Max + Computer Use | 旋转/resize/分屏矩阵绿色 |
| 18 | `18_ACCESSIBILITY_PERFORMANCE_RESILIENCE.md` | Worktree 审计 + Local 修复 | Ultra 只读审计，Max 写入 | 审计和全门禁绿色 |
| 19 | `19_FINAL_PARITY_AND_RELEASE_PREFLIGHT.md` | Worktree 审计 + Local 修复 | Ultra 只读审计 | 最终矩阵与风险清单 |

“Max”表示在 Codex 中选择适合单任务深度执行的最高单代理推理档；坚持全程 Ultra 时，仍必须遵守主代理唯一写入规则。

## 日常任务和故障提示词

- 一般根因修复：`20_ROOT_CAUSE_BUG_FIX.md`
- 白块、遮挡、错页、手势冲突：`21_INTERACTION_GESTURE_LAYOUT_BUG.md`
- 动画不统一：`22_ANIMATION_CONSISTENCY_AUDIT.md`
- 阶段后回归：`23_REGRESSION_SWEEP.md`
- 只读代码审查：`24_CODE_REVIEW_ONLY.md`
- 已被 AI 改乱的分支恢复：`25_RECOVER_FROM_BAD_BRANCH.md`
- 把用户纠正沉淀为规则：`26_UPDATE_RULES_AFTER_CORRECTION.md`
- 单功能任务：`27_FEATURE_TASK_TEMPLATE.md`
- 小改动：`28_SMALL_CHANGE_TEMPLATE.md`
- Xcode/Simulator GUI 复现：`29_GUI_REPRODUCTION_WITH_COMPUTER_USE.md`
- Ultra 并行只读审计：`30_ULTRA_PARALLEL_AUDIT.md`
- Live 边界数据固化为 fixture：`31_LIVE_DATA_EDGE_CASE_CAPTURE.md`
- 新线程/Handoff 安全续作：`32_RESUME_OR_HANDOFF.md`
- 阶段收尾与可提交状态：`33_PHASE_CLOSEOUT.md`
- 新生产依赖只读评审：`34_DEPENDENCY_CHANGE_REVIEW.md`
- Android 参考 commit 升级：`35_ANDROID_REFERENCE_UPGRADE.md`
- Live API/登录突然失效：`36_LIVE_API_BREAKAGE_TRIAGE.md`

## 不能跳过的停机点

出现以下任一情况，当前线程必须停止实现并报告：

- Android/API/Protobuf 证据不足，需要猜测。
- 基线构建或测试已失败且无法区分新旧问题。
- 需要修改当前阶段明确禁止的共享组件。
- Pager/MediaViewer spike 未被接受。
- 发现真实 Cookie、BDUSS、STOKEN、密码或私密用户数据进入日志/附件/Git。
- 同一 Bug 的两个根因假设/修复尝试均失败。
- `/review` 仍有未处理 P0/P1。


---

# 仓库长期规则（AGENTS.md）

# TiebaLite iOS — Repository Operating Rules

本文件是整个仓库的长期约束。开始任何任务前必须读取本文件、当前任务提示词、相关 `Specs/`、最新 ADR 和 `Docs/Progress/TASK_STATE.md`。

## 1. 产品使命与范围

构建一个原生 iOS/iPadOS 的非官方 Tieba Lite 只读客户端。核心能力：

1. 推荐内容流。
2. 用户关注的吧列表。
3. 吧首页、吧信息、吧内主题列表及分页。
4. 帖子、楼层、楼中楼的只读浏览。
5. 图片加载、预览、缩放和分页浏览。
6. 登录态、Cookie、安全存储和失效处理。
7. iPhone/iPadOS、横竖屏、分屏、深色模式、大字体、Reduce Motion。

明确排除写操作：签到、发帖、回复、发布评论、删除、点赞等改变远端数据的行为。现有帖子回复与楼中楼仍需只读展示。

核心链路未通过质量门禁前，不实现非核心装饰功能。

## 2. 真相来源与优先级

发生冲突时按以下顺序处理：

1. 用户在当前任务中明确给出的要求。
2. 本目录链上的 `AGENTS.md` / `AGENTS.override.md`。
3. 已批准的 `Specs/` 和 ADR。
4. 可执行测试及固定 fixture 所定义的行为。
5. `References/TiebaLite-Android` 中可追踪的产品行为、协议、参数和字段。
6. 模型自己的推断。

不得凭记忆发明贴吧 API、参数、签名、Protobuf 字段语义或登录流程。无法从参考源码、抓取样本或已批准文档证实时，标为 `UNKNOWN`，记录证据缺口，并先实现 fixture/mock 路径。

`References/TiebaLite-Android` 是只读参考：

- 禁止修改 submodule。
- 禁止机械翻译 Android UI。
- 允许复用协议定义时必须保留许可证和来源说明。
- 每个真实接口映射必须在 `Specs/API_EVIDENCE.md` 中记录 Android 源文件、符号、请求/响应类型和验证样本。

## 3. 目标工具链

- macOS 26。
- Xcode 26。
- Swift 6 语言模式。
- 严格并发检查为 Complete。
- 默认最低部署 iOS/iPadOS 18.0；修改最低版本必须先更新 ADR 与测试矩阵。
- SwiftUI 为主要 UI 技术。
- UIKit 包装只用于有明确理由的高风险交互组件，例如统一 Pager 或缩放图片查看器。
- XcodeGen 管理工程声明；不得在大范围修改中手工编辑 `.pbxproj`。

## 4. 强制工作循环

每个任务必须按顺序执行：

1. **定位**：读取相关规则、规格、ADR、任务状态和参考源码。
2. **检查基线**：运行 `git status --short`、相关现有测试和构建；记录基线失败，不能把旧失败冒充新失败。
3. **给出计划**：列出目标、非目标、预计修改文件、测试和风险。计划不等于授权扩大范围。
4. **先定义行为**：新增/更新状态机、验收条件、fixture 或失败测试，再写实现。
5. **小步实现**：一次只完成一个垂直行为，不跨 Feature 大规模改动。
6. **定向验证**：先跑最小相关测试，再跑 `make quality-fast`；阶段出口运行 `make quality`。
7. **审查差异**：`git diff --check`，核对无无关修改、无密钥、无生成噪声。
8. **更新记录**：只根据已执行的命令更新 `Docs/Progress/TASK_STATE.md`。
9. **完成报告**：列出修改文件、状态变化、测试命令及结果、未解决风险、是否新增手势/动画/overlay/依赖。
10. **停止**：不得自动开始下一阶段。

不能用“理论上应该通过”“代码看起来正确”替代执行结果。无法运行的验证必须明确说明原因和未验证范围。

## 5. Ultra 与子代理写入规则

- 协调主代理是唯一可以写当前工作树的代理。
- 子代理默认只读，只能做源码搜索、风险分析、测试建议、方案对比和 diff review。
- 子代理不得同时修改导航、状态基础设施、Pager、MediaViewer、DesignSystem、工程配置或同一 Feature。
- 主代理采用子代理建议前必须自行核对证据和现有代码。
- 可并行的是独立分析，不是对共享基础设施的并行写入。

## 5A. Git 与用户工作保护

- 未经当前任务明确授权，不执行 `git commit`、`git amend`、`rebase`、`merge`、`push`、`tag` 或修改远端。
- 禁止 `git reset --hard`、`git clean -fd`、覆盖式 checkout/restore 或删除无法解释的用户文件。
- 发现未提交改动时先记录并避开；不能假设它们由模型生成，也不能为获得 clean tree 擅自丢弃。
- 只在独立、已命名任务中更新 Android submodule 或依赖锁；更新后必须重新审计受影响证据。
- Worktree 只用于可独立审查的任务；共享导航、工程配置、DesignSystem、Pager、MediaViewer 和同一 Feature 不并行写。
- 阶段“形成绿色 commit”表示差异已达到可提交状态；是否实际提交由当前任务授权或用户操作决定。

## 6. 目录与依赖方向

目标结构：

```text
App/
Core/
  Models/
  Networking/
  TiebaAPI/
  Session/
  Persistence/
  Images/
  Logging/
DesignSystem/
InteractionKit/
Features/
  Recommendations/
  FollowedForums/
  Forum/
  ThreadReader/
  MediaViewer/
  Search/
  Settings/
Generated/Protobuf/
Resources/
TestSupport/
Tests/
UITests/
Specs/
Docs/ADRs/
Docs/Audits/
Docs/Progress/
References/TiebaLite-Android/
```

依赖只能朝内：

```text
App → Features → Core protocols/models
Features → DesignSystem / InteractionKit
Core concrete implementations → Core protocols/models
Views ↛ URLSession / Protobuf / Keychain / database
Generated Protobuf ↛ UI
```

禁止循环依赖。Feature 之间不直接导入对方内部类型；跨 Feature 导航通过稳定 route 和小型公共模型。

不要为了“架构感”创建几十个空 target。初期使用清晰目录和协议边界；只有生成 Protobuf、编译隔离或复用价值明确时才拆独立模块。

## 7. 依赖政策

预批准：

- Apple SwiftProtobuf：解析和生成 Protobuf。
- XcodeGen：开发期工程生成。
- SwiftLint：开发期静态检查。
- `xcbeautify`：仅改善本地构建日志，可选。

图片库、数据库、状态管理框架、网络框架等生产依赖必须先写 ADR，比较：系统能力、维护状态、许可证、二进制体积、并发安全、测试性和退出成本。未经批准禁止添加 TCA、Alamofire、RxSwift、CombineExt、Kingfisher/Nuke 等依赖。不得同时引入两个完成相同工作的库。

禁止在 Feature 任务中顺手升级所有依赖或重写 `Package.resolved`。

## 8. Swift 与并发规则

- UI Store/ViewModel 使用 `@MainActor`，其公开状态只在主 actor 更新。
- 网络、磁盘、图片缓存等可变共享资源使用 actor 或不可变值语义。
- 跨 actor 数据必须 `Sendable`；不能通过 `@unchecked Sendable` 掩盖问题，除非有 ADR、锁策略和测试。
- 每个可取消异步操作必须保存任务句柄或使用结构化并发，页面消失/新请求开始时按状态机取消。
- 旧请求不得覆盖新请求；使用请求代次、稳定 cursor 或任务身份验证。
- 不使用 `DispatchQueue.main.asyncAfter` 修复时序、动画或布局问题。
- 不创建无父任务的 `Task.detached`，除非有可审查理由。
- 不吞掉 `CancellationError`，也不把取消当普通错误展示。
- 禁止 `try!`、`as!`、生产代码 `fatalError`、空 `catch`、无理由强制解包。

## 9. 网络、协议与安全

- UI 只依赖 repository/use-case 协议，不直接发请求。
- Endpoint 必须是强类型定义，包含方法、路径、编码、响应类型和认证要求。
- Protobuf/HTTP DTO 必须映射为领域模型，生成类型不得泄漏到 View。
- 所有真实接口都要有固定 fixture，以及成功、空、畸形、超时、取消、未登录、会话失效样本。
- Cookie、BDUSS、STOKEN、设备标识和授权头不得写入日志、fixture、Git 或测试附件。
- 日志默认脱敏；Debug 也不得打印完整 Cookie。
- Keychain 中只保存必要敏感信息；退出登录必须清理会话和受保护缓存。
- 不绕过 TLS，不关闭证书验证，不接受所有证书。
- 不使用隐蔽 WebView 注入或收集用户密码；登录方案必须有 ADR 和清晰用户边界。

## 10. 状态与分页不变量

每个异步列表必须明确区分：

- idle
- initialLoading
- loaded
- empty
- initialFailure
- refreshing（保留旧内容）
- loadingNextPage（保留旧内容）
- refreshFailure（保留旧内容）
- nextPageFailure（保留旧内容）

强制不变量：

- 下拉刷新不能先清空列表。
- 下一页失败不能丢失已加载内容。
- 同一 cursor/page 同时最多一个请求。
- 分页按稳定业务 ID 去重且保持服务器顺序。
- 已过期响应不能覆盖最新状态。
- 返回上一页保留列表、筛选、导航和滚动位置。
- Tab 切换保留每个 Tab 的独立导航栈与状态。
- 列表行身份只能使用稳定业务 ID；禁止在 `body` 中生成 UUID。
- 不在 Cell/View 的 `body` 或 `onAppear` 中无防重地启动请求。
- 删除贴、缺字段、未知内容节点和空标题必须降级显示，不能崩溃。

## 11. 导航、布局与手势

- iPhone 普通页面使用系统 `NavigationStack`。
- iPad 使用 `NavigationSplitView` 或经 ADR 批准的系统容器，共享同一业务状态。
- 主 Tab 可各自拥有独立 NavigationPath；不得用一个全局 `[AnyHashable]` 模糊管理。
- 不自定义全局 push/pop 位移动画，不覆盖系统左边缘返回。
- 不用 `UIScreen.main.bounds`、设备型号或硬编码屏幕尺寸决定布局。
- `.ignoresSafeArea()` 仅用于纯背景；固定底部内容使用 `safeAreaInset`，顶部操作使用 toolbar。
- 业务 Feature 禁止直接添加 `DragGesture`。横向切页只能由 `InteractionKit/PagerContainer` 处理；缩放只能由唯一 `MediaViewer` 处理。
- 不创建同方向嵌套 ScrollView。
- overlay 必须声明生命周期、z-order、触摸命中范围和无障碍行为。
- 所有可点击元素必须有稳定 `accessibilityIdentifier`，点击区域至少符合系统可用性预期。

## 12. 动效规则

- 所有自定义动效来自 `DesignSystem/Motion`。
- 业务代码不得写任意 duration、curve、spring 参数。
- 禁止在页面根节点使用无 `value` 的隐式 `.animation`。
- 系统导航使用系统动画；不叠加自定义 offset/opacity 造成双重转场。
- 网络刷新和批量分页默认不逐行动画。
- 加载、空态、错误态使用统一组件；状态替换不能露出未着色背景。
- 所有动效必须尊重 Reduce Motion；关闭动效后功能与状态仍正确。
- 新增动画必须同时新增/更新动效契约和至少一个验收路径。

## 13. Pager 与 MediaViewer 单实例原则

仓库只允许一个生产 Pager 抽象和一个生产 MediaViewer：

- 页面身份稳定。
- 当前页与相邻页在交互转场期间保持存活。
- 容器和页面背景始终明确且不透明，避免白块。
- 快速连续滑动、取消滑动、旋转、分屏尺寸变化和数据刷新均有测试。
- 图片缩放与分页手势优先级明确；缩放状态不能泄漏到复用页面。
- 图片加载失败时页面尺寸和背景保持稳定。

禁止 Feature 自己复制一份横滑实现。

## 14. 测试规则

- 纯状态、映射、分页、取消和错误处理优先使用 Swift Testing。
- UI 流程、启动、截图附件、性能和系统交互使用 XCTest/XCUITest。
- 自动化测试不依赖实时贴吧网络。
- 使用 `URLProtocol`/MockHTTPClient、固定 Protobuf/JSON fixture 和启动 scenario。
- 禁止 `sleep()` 等待 UI；使用可观察条件和 XCTest expectation。
- 测试必须覆盖成功、空、失败、慢网、取消、重复分页、过期响应、会话失效。
- 每个 Feature 至少有：状态测试、映射/Repository 测试、关键 UI smoke flow。
- 交互组件必须在 iPhone 与 iPad 目的地验证，包含横竖屏或分屏尺寸变化。
- Bug 修复先增加能失败的回归测试；无法自动化时必须提供确定性手工脚本和证据附件。

## 15. 禁止的“假修复”

除非有独立、可证明的产品理由，以下做法视为失败：

- `.id(UUID())` 强制刷新。
- `DispatchQueue.main.asyncAfter` 或任意延迟掩盖竞态。
- 增加全屏透明遮罩挡住错误画面。
- 全局关闭动画来掩盖局部状态错误。
- 用额外 `zIndex(9999)` 解决未分析的层级问题。
- 刷新时销毁并重建整个导航树。
- 通过清空缓存/重启 App 让 Bug “消失”。
- 捕获所有错误后静默忽略。
- 删除测试或降低断言来获得绿色结果。
- 把真实网络不可用归咎于 UI 并跳过 fixture 测试。
- 在没有根因证据时连续尝试多组视觉参数。

同类 Bug 两次修复仍失败：停止补丁，回退到最后绿色提交，输出组件状态/生命周期重设计方案。

## 16. 质量命令

工程生成后应支持：

```bash
make doctor
make generate
make lint
make test-unit
make test-ui-smoke
make quality-fast
make quality
```

若命令尚未建立，当前阶段必须明确是“基础设施未完成”，不能假称已通过。阶段出口至少执行 `make quality`；耗时性能矩阵在专门阶段执行。

## 17. 完成报告格式

每次完成必须按此结构报告：

```text
目标与范围
修改文件
关键设计/状态转换
新增或变更的动画、手势、overlay、依赖
执行的命令与逐项结果
回归覆盖
未解决风险/UNKNOWN
下一阶段前置条件
```

不得省略失败命令。不得把未执行的测试写成“通过”。


---

# 文件：`Prompts/00_BOOTSTRAP_ENVIRONMENT.md`

# 阶段 00：环境、仓库与护栏自检

你正在 macOS 26 的 Codex 桌面版中工作，目标工具链为 Xcode 26 / Swift 6。严格遵守仓库根目录 `AGENTS.md`。本阶段只建立可验证环境，不创建业务功能，不进入阶段 01。

## 目标

确认 Codex 打开的目录、Git、Android 参考 submodule、Xcode、Simulator、Homebrew/开发工具和仓库护栏均可用；将实际环境记录为可审查文件。

## 开始前

1. 读取根 `AGENTS.md`、`Specs/00_PRODUCT_CHARTER.md`、`Specs/02_DEFINITION_OF_DONE.md` 和 `Docs/Progress/TASK_STATE.md`。
2. 运行 `pwd`、`git rev-parse --show-toplevel`、`git status --short`。
3. 确认 `References/TiebaLite-Android` 存在且是 Git submodule；记录当前 branch/commit。不得修改它。
4. 若当前目录还不是 Git 仓库，初始化 Git，但不要删除用户文件。

## 必须检查并记录真实输出

```bash
sw_vers
uname -m
xcode-select -p
xcodebuild -version
swift --version
git --version
xcrun simctl list runtimes
xcrun simctl list devices available
command -v brew || true
command -v xcodegen || true
command -v swiftlint || true
command -v xcbeautify || true
git submodule status || true
```

## 工具处理

- 生成 `Docs/Audits/ENVIRONMENT.md`，包括命令、版本、可用 iPhone/iPad Simulator 和缺失项。
- 检查 `Brewfile`、`Makefile`、`scripts/` 和 `Prompts/` 是否存在；此时只修正明显的路径/权限问题。
- 不得未经说明安装生产依赖。
- 开发工具缺失时：优先生成/确认 `Brewfile`，说明将运行的命令；可在权限允许时执行 `brew bundle`。安装失败则保留可执行的后续步骤，不改用手工大改 `.pbxproj`。
- 执行 `scripts/bootstrap_check.sh` 或建立该脚本的可运行最小版本。
- 执行 `python3 scripts/check_instruction_size.py`，确认每条适用的 AGENTS 指令链未超限。
- 创建 `References/TiebaLite-Android.lock`，第一列写当前 Android submodule 的完整 commit SHA；以后只有显式参考版本升级任务才可更新。
- 执行 `scripts/reference_integrity.sh`，确认参考仓库 clean 且与 lock 一致。
- 验证 `.agents/skills/*/SKILL.md` frontmatter 均含 `name` 与 `description`。
- 验证所有 shell 脚本 `bash -n` 通过，并为应执行脚本设置 executable bit。

## 不允许

- 不创建 Xcode App target。
- 不写 Swift 业务代码。
- 不修改 Android submodule。
- 不猜测 bundle identifier、签名团队或真实账号。
- 不自动进入源码审计阶段。

## 交付物

- `Docs/Audits/ENVIRONMENT.md`
- `References/TiebaLite-Android.lock`
- 更新后的 `Docs/Progress/TASK_STATE.md`
- 必要的脚本权限/语法修正
- 缺失工具列表及明确影响

## 验收

- 仓库根目录和 Git 状态明确。
- Xcode 与至少一个 iPhone、一个 iPad Simulator 可识别，或明确记录缺失 runtime。
- Android submodule commit 可追踪且未修改。
- 所有仓库脚本至少通过 shell 语法检查。
- 没有新增业务代码。

完成后按 `AGENTS.md` 的报告格式汇报并停止。


---

# 文件：`Prompts/01B_ANDROID_RUNTIME_BEHAVIOR_CAPTURE.md`

# 阶段 01B（强烈建议、条件可选）：Android 原版运行行为采集

本阶段只采集原版 TiebaLite 的运行证据，用于补足源码无法确认的页面、滚动、返回、加载、错误、动效和手势行为。不得写 iOS 生产代码，也不得修改 Android submodule。

## 前置与可用性判断

1. 读取阶段 01 审计与 `Specs/UNKNOWN_BEHAVIORS.md`。
2. 检查本机是否已有 Android Studio/SDK/emulator，或是否有用户提供的原版录屏、截图和可运行 APK。
3. 不允许为了本阶段下载来路不明 APK、绕过签名/认证或抓取他人账号流量。
4. 环境不可用时，创建报告标记 `NOT_AVAILABLE`，列出未解决项和后续用户手工采集清单，然后停止；不要猜测。

## 安全规则

- 真实账号登录只由用户手工完成。
- Codex Computer Use 不输入、读取、复制或记录密码、Cookie、BDUSS、STOKEN、二维码授权内容。
- 录屏/截图遮盖用户名、头像、私聊、Cookie、设备标识和其他敏感内容。
- 不拦截 TLS，不安装自签根证书，不修改原版 App。

## 需要采集的 P0 流程

对每个流程记录：设备/窗口、起始状态、逐步动作、页面层级、滚动保持、加载/错误位置、返回行为、手势、动效起止、可观察时间关系和证据路径。

1. 冷启动与主 Tab 切换。
2. 推荐：首次、刷新、分页、错误/重试、打开帖子与返回位置。
3. 我关注的吧：未登录、已登录、进入吧首页与返回。
4. 吧首页：头部、置顶/普通贴、排序/分区切换、分页、返回。
5. 帖子：首屏、楼层分页、楼中楼展开/重试、图片打开/关闭。
6. 图片：左右切换、首尾、缩放、平移、失败图、系统返回。
7. 深色/大字体（原版支持范围内）。

不要把 Android 特有的导航按钮、动画或手势直接规定为 iOS 实现；分别标记：

- `PRODUCT_SEMANTIC`：应在 iOS 保留的用户行为。
- `ANDROID_CONVENTION`：应改用 iOS 系统惯例。
- `VISUAL_REFERENCE`：可参考的信息层级/密度。
- `UNKNOWN`：仍无法确认。

## 输出

- `Docs/Audits/ANDROID_RUNTIME_BEHAVIOR.md`
- `Docs/Audits/AndroidRuntimeEvidence/` 中的脱敏截图/简短录屏索引（大文件是否入 Git 按 ADR）。
- 更新 `Specs/UNKNOWN_BEHAVIORS.md`、`FEATURE_MATRIX.md`、`NAVIGATION_MAP.md`、`STATE_MACHINES.md`。
- 为每个 P0 用户流形成 Given/When/Then 行为条目。

## 验收

- 每个已运行流程都有可追踪证据，不用“看起来像”。
- Android 惯例与 iOS 产品语义已分离。
- 所有敏感信息已检查和脱敏。
- `git diff` 仅为 Docs/Specs/证据索引/TASK_STATE。

完成后停止。


---

# 文件：`Prompts/01_ANDROID_REFERENCE_AUDIT.md`

# 阶段 01：Android TiebaLite 只读源码审计

严格遵守根 `AGENTS.md`，并显式使用 `$tiebalite-reference-audit`。本阶段只读分析 `References/TiebaLite-Android`，不得创建 Swift/Xcode 项目，不得实现 iOS 页面。

建议使用 GPT-5.6 Sol Ultra，但所有子代理只读。协调主代理负责合并证据，不能让多个代理各自写同一审计文件。

## 目标

把 Android 4.0-dev 参考实现转化为可执行的 iOS 产品/协议规格，明确哪些是代码证据、运行证据和未知项。

## 必须审计的区域

至少系统搜索并建立索引：

- `app/src/main/java/.../api/`：HTTP 常量、LiteApi、TiebaApi、ProtobufRequest、请求适配与 caster。
- repository/data 层：推荐、FRS/吧页、PB/帖子页、关注吧、搜索、登录/session。
- `app/src/main/proto/`：请求与响应消息、分页、用户、主题、楼层、内容节点。
- UI/Compose/Fragment/Activity：主 Tab、推荐、吧首页、帖子、图片、登录、搜索、设置。
- 内容渲染器：文本、图片、链接、表情、视频/语音/投票/未知节点等实际分支。
- 数据库与 DataStore：历史、缓存、设置、账户状态。
- Android tests、issues 或代码中的异常/边界处理。

不得只根据文件名总结；关键行为必须追到具体 symbol 和调用链。

## 可并行只读工作流

可让子代理分别审计：

1. API/请求构建/认证。
2. Protobuf 与 mapper。
3. 推荐与主导航。
4. 吧首页/FRS。
5. 帖子/PB/内容节点。
6. 关注吧与登录/session。
7. 图片查看、手势、设置与边界。

子代理输出必须含路径、symbol、证据置信度和 UNKNOWN，不得直接修改仓库。

## 必须产出

1. `Docs/Audits/ANDROID_REFERENCE_AUDIT.md`
   - branch/commit SHA
   - 模块图和关键调用链
   - Android UI 与 iOS 原生行为的区分
   - 已知高风险/过时做法
2. `Specs/FEATURE_MATRIX.md`
   - 原版功能、P0/P1/排除、登录要求、数据来源、验收流程
3. `Specs/NAVIGATION_MAP.md`
   - 页面、入口、route 参数、返回状态、Tab/子页关系
4. `Specs/API_EVIDENCE.md`
   - 从模板生成，逐 endpoint 填证据
5. `Specs/PROTOBUF_MAP.md`
   - 文件、message、request/response、领域模型、生成顺序、未知字段
6. `Specs/CONTENT_NODE_MATRIX.md`
   - 从模板生成，覆盖所有内容节点与降级策略
7. `Specs/STATE_MACHINES.md`
   - 推荐、关注吧、吧页、帖子、媒体、session 的状态和事件
8. `Specs/UNKNOWN_BEHAVIORS.md`
   - 仅运行 App/抓包/真实账号才能确认的问题，以及安全的验证方法
9. `Docs/Audits/SOURCE_AND_LICENSE_NOTES.md`
   - 参考仓库许可证、文件来源、允许复用/需重写的边界

## 规格要求

每条重要结论标注：

- `CODE_EVIDENCE`：有路径与 symbol。
- `RUNTIME_EVIDENCE`：有截图/录屏/响应 fixture。
- `INFERENCE`：根据多个证据推断，写明推断链。
- `UNKNOWN`：证据不足。

对推荐、FRS、PB、关注吧至少画出：

```text
用户动作 → UI intent → repository → endpoint/request → response/proto → mapper → UI state
```

## 不允许

- 不写 Swift。
- 不创建 `project.yml`。
- 不把 Android Compose 动画/手势照搬到 SwiftUI。
- 不凭字段名猜登录 token 或签名算法。
- 不把“未搜索到”写成“功能不存在”。
- 不自动进入架构阶段。

## 验收

- 每个 P0 功能至少有完整调用链和状态机。
- 每个拟接入 endpoint 有来源、认证、request/response 和分页信息，或明确 UNKNOWN。
- 内容节点矩阵不是只有 text/image 两项，而是覆盖参考代码实际分支。
- 所有审计文件相互引用且无明显矛盾。
- `git diff` 仅包含 Specs/Docs/TASK_STATE 变更。

完成后报告证据最弱的五个区域，并停止。


---

# 文件：`Prompts/02B_SCREEN_AND_INTERACTION_BLUEPRINTS.md`

# 阶段 02B：逐屏 UI、状态与交互蓝图

本阶段把已批准的产品/架构规格转化为可验收的页面蓝图。只写 Specs/Docs/测试计划，不创建 Swift 生产 UI。

## 目标

在 Codex 生成任何业务页面前，冻结每个 P0 页面在所有主要状态下的结构、信息层级、滚动容器、导航、手势、安全区、动效、iPad 映射和可访问性。不得只给一张“漂亮首页”草图。

## 必须创建

```text
Specs/Screens/
  AppShell.md
  Recommendations.md
  FollowedForums.md
  ForumHome.md
  ThreadReader.md
  MediaViewer.md
  SessionLogin.md
Specs/Flows/
  RecommendationsToThreadToMediaAndBack.md
  FollowedForumToForumToThreadAndBack.md
  SessionExpiration.md
Specs/COMPONENT_CATALOG.md
Specs/ACCESSIBILITY_IDENTIFIERS.md
Specs/LAUNCH_SCENARIOS.md
Docs/Audits/BLUEPRINT_REVIEW.md
```

## 每个 Screen 文档必须包含

1. 用户目的与非目标。
2. route 输入、单一状态来源和 Store 生命周期。
3. 页面区域顺序及每区字段来源。
4. initial/loading/loaded/empty/initial error/refresh/next-page error/session expired/unsupported data。
5. 唯一主滚动容器、滚动锚点和返回恢复规则。
6. toolbar、safe area inset、sheet/overlay 的所有权、z-order 和 hit testing。
7. 允许的用户事件与状态转换。
8. 导航进入/返回及 iPhone/iPad 宽窄映射。
9. 自定义动效语义、Motion token、Reduce Motion 路径；没有必要则写 `NO_CUSTOM_MOTION`。
10. 手势所有者与冲突优先级；Feature 页面默认 `NO_CUSTOM_DRAG_GESTURE`。
11. Dynamic Type、VoiceOver、深色、高对比和长文本/坏数据策略。
12. fixture scenario 与自动化/Computer Use 验收步骤。
13. Android 证据、运行证据、iOS 原生调整和 UNKNOWN。

## 视觉与布局规则

- 不指定固定屏幕像素布局；使用语义间距、可用宽度和系统容器。
- 不为 iPad 复制另一套业务页面。
- 不通过 skeleton 高度变化造成内容跳动；占位与最终结构要有稳定几何契约。
- 列表行必须定义稳定 ID、可点击区域、图片尺寸策略、长标题和无图降级。
- 同一状态/动作在不同页面复用同一组件和反馈，不创建局部变体。
- 系统 push/pop/sheet 使用系统动效，不要求“完全复制 Android 动画”。

## Flow 文档必须包含

逐步列出：Given、用户动作、route/state 变化、可观察 UI、取消/失败分支、返回后应保留的状态、需要的 identifier 和测试断言。至少覆盖：

- 推荐滚动 → 帖子滚动 → 第 N 图 → 缩放/切图 → 关闭 → 返回推荐并保持位置。
- 关注吧 → 吧首页切换分区/分页 → 帖子 → 返回并保持每层状态。
- 会话在请求中失效 → 单一全局状态转换 → 页面安全降级 → 重新登录后的恢复。

## 审查

使用 `$ios-architecture-review` 和 `$ios-interaction-qa` 只读检查蓝图内部是否存在：重复状态源、重复 Pager、overlay 常驻、滚动嵌套、自定义返回手势、任意动效、iPad 双状态或无法自动化的模糊验收。

## 验收

- 每个 P0 页面都能由规格直接写测试，不需要实现者临时决定关键交互。
- 所有跨屏状态保持有明确 owner。
- 组件目录没有多个同义 loading/error/pager/media 变体。
- UNKNOWN 仍显式，未用视觉设计掩盖协议未知。
- `/review` 无 P0/P1 文档矛盾。

完成后停止。


---

# 文件：`Prompts/02_ARCHITECTURE_AND_EXECUTION_PLAN.md`

# 阶段 02：架构决策与执行计划

本阶段基于已批准的 Android 审计建立 iOS 架构和 ADR，并显式使用 `$ios-architecture-review` 做候选与最终文档只读审查。只写规格/ADR/工程计划，不创建生产功能代码。

## 前置门禁

- 阶段 01 的交付物存在并内部一致。
- `Docs/Progress/TASK_STATE.md` 显示阶段 01 已通过。
- Android submodule clean。
- 对所有 UNKNOWN 保持显式，不用架构文档掩盖协议未知。

## 需要做出的决策

创建并接受或保留 Proposed 状态的 ADR：

1. `ADR-0001-project-generation.md`
   - XcodeGen、目录/target、生成文件是否提交、开发工具固定方式
2. `ADR-0002-feature-state-and-dependency-injection.md`
   - `@Observable`/Store、Action/Event、依赖组合根、取消/旧响应策略
3. `ADR-0003-navigation-and-ipad.md`
   - Tab 独立 path、NavigationStack、NavigationSplitView、route、状态恢复
4. `ADR-0004-pager-container.md`
   - SwiftUI 系统容器 vs UIKit 包装的候选与验证 spike
5. `ADR-0005-media-viewer.md`
   - UIScrollView zoom、分页、手势仲裁、资源生命周期
6. `ADR-0006-networking-and-protobuf.md`
   - URLSession、Endpoint、SwiftProtobuf、生成、DTO/domain 边界、fixture
7. `ADR-0007-session-and-login.md`
   - Cookie jar、Keychain、认证 UX、失效、日志脱敏；未知项保持 Proposed
8. `ADR-0008-cache-and-images.md`
   - 系统实现 vs第三方库；没有证据时不立即添加生产依赖
9. `ADR-0009-testing-and-launch-scenarios.md`
   - Swift Testing/XCTest、URLProtocol/mock、XCUITest scenario、test plans
10. `ADR-0010-observability-and-privacy.md`
    - 日志、signpost、诊断附件、敏感字段

## 架构产出

- `Specs/MODULE_MAP.md`：目录、责任、允许依赖、禁止依赖。
- `Specs/ROUTE_MAP.md`：所有 P0 route、参数、iPhone/iPad 映射。
- `Specs/STATE_MACHINES.md`：补齐 transition 表、取消和错误不变量。
- `Specs/PROJECT_PLAN.md`：阶段、输入、输出、门禁、回滚点。
- `Specs/DEPENDENCY_POLICY.md`：预批准依赖、ADR 流程、许可证检查。
- `Docs/Audits/ARCHITECTURE_RISK_REVIEW.md`：至少覆盖 SwiftUI 身份、并发、Pager、Media、session、真实 API 漂移、iPad。

## 设计约束

- 不采用大而全框架来回避状态设计。
- 不把所有东西做成 singleton。
- 不把所有类型标 `@MainActor`。
- 不先创建十几个独立 package/target；分层要与项目规模匹配。
- 生成 Proto 与领域模型隔离。
- UI 先 fixture 后 live endpoint。
- Pager/MediaViewer 先做隔离 spike，通过后只能保留一个生产实现。
- App Shell 从第一天支持 iPad route，但不用阶段 02 写 UI。

## Ultra 使用

可并行让子代理只读评审候选方案：

- Swift concurrency 风险。
- SwiftUI/UIKit interop 风险。
- 测试/可观测性。
- iPad/导航。
- 网络/session。

主代理必须在 ADR 中明确最终取舍，不能直接拼接互相矛盾的建议。

## 验收

- 每个高风险区域有明确候选、选择、退出/回滚条件。
- 项目计划能从空工程逐阶段到稳定 P0，不以“生成完整 App”作为一步。
- 所有共享基础设施只有一个 owner 和一个生产实现。
- 没有 Swift 生产代码、Xcode project 或真实依赖变更。
- `/review` 只剩已记录的 Proposed/UNKNOWN，不存在未解释架构矛盾。

完成后停止。


---

# 文件：`Prompts/03_PROJECT_SCAFFOLD.md`

# 阶段 03：创建可构建、可测试的 Xcode 工程骨架

本阶段只创建确定性工程骨架和最小 App，不实现贴吧业务页面或真实网络。

## 前置

- 阶段 02 的 ADR 已完成。
- Git 工作树 clean，记录基线 commit。
- 读取 `ADR-0001`、`ADR-0002`、`ADR-0003`、`ADR-0009`。

## 允许修改

- `project.yml`、XcodeGen 配置、生成的 `.xcodeproj`（按 ADR）。
- `App/` 与空目录/最小占位源码。
- Tests/UITests 的最小 smoke 测试。
- `Brewfile`、`Makefile`、`scripts/`、`.gitignore`。
- 工程文档和 TASK_STATE。

## 禁止

- 不接真实贴吧 API。
- 不添加 Pager、MediaViewer、推荐列表。
- 不添加未批准生产依赖。
- 不手工批量编辑 `.pbxproj`。
- 不配置用户的真实 Team ID、证书或 App Store 信息。

## 工程要求

1. 使用 XcodeGen 声明：
   - App target
   - unit test target
   - UI test target
   - shared scheme
   - 至少一个 `.xctestplan`
2. Swift 6 + strict concurrency Complete。
3. iOS/iPadOS 18.0+，支持 iPhone/iPad。
4. Bundle ID 使用明显占位且集中配置，例如 `dev.local.tiebaliteios`；签名使用 Automatic/无 Team 的 Simulator 可构建配置。
5. App 仅显示稳定的启动占位页和环境信息，不做花哨动画。
6. 目录引用与 ADR 一致，生成 Protobuf 目录可为空但边界存在。
7. Debug/Release 配置清晰；密钥不进入 build settings。
8. `scripts/project.env` 从 example 生成并填写真实 project/scheme/targets。
9. `make generate` 可重复，连续运行不产生非确定性差异。
10. `make build`、`make test-unit`、`make test-ui-smoke` 有真实结果。

## 必须测试

- 重新生成工程。
- `xcodebuild -list`。
- generic iOS Simulator build。
- 选取实际可用 iPhone Simulator 运行 unit tests。
- UI smoke：启动 App，确认根页面 identifier 存在。
- 若 iPad runtime 可用，至少 build 一次 iPad-compatible target；UI 流程放后续。

## 验收

- 从 clean checkout 按 README/Brewfile 可生成工程。
- App 在 Simulator 启动。
- unit/UI smoke 真实通过。
- `git diff --check` 通过。
- 重新 `make generate` 后差异为空或符合 ADR。
- 没有业务网络/页面代码。

报告所有实际命令与结果后停止。


---

# 文件：`Prompts/04_DETERMINISTIC_TEST_HARNESS.md`

# 阶段 04：确定性测试、Fixture 与依赖注入底座

目标是让后续所有 UI 先在完全可控的数据与时序下实现。不得接真实网络。

## 前置

- 工程骨架绿色。
- 读取 ADR-0002、ADR-0006、ADR-0009、ADR-0010。
- 先运行阶段 03 的 build/unit/UI smoke，记录基线。

## 实现范围

建立：

- `AppEnvironment`/composition root。
- 小型 `Clock`、`IDGenerator`、`HTTPClient`、`SessionProviding`、`ImageLoading` 协议。
- `MockHTTPClient` 或 `URLProtocol` stub，支持：成功、延迟、错误、取消、乱序响应。
- `LaunchScenario` 解析：UI tests 通过参数选择固定场景。
- Fixture loader：JSON、binary Protobuf、图片资源，错误信息清晰。
- 测试专用 session/cache，绝不触碰真实 Keychain/账号。
- 统一 Debug 日志与敏感字段 redaction 测试。
- UI test helper：等待 identifier、失败截图附件、启动场景。

## Launch scenario 最低集合

```text
app.empty-shell
network.offline
network.slow
session.signed-out
session.signed-in-fixture
session.expired
```

后续 Feature 可扩展 `recommendations.success` 等，不得每个测试发明不同参数解析。

## 测试要求

- 同一 endpoint 旧请求晚返回不会自动覆盖（通过测试基础设施可构造）。
- Cancellation 能被观察，取消不映射为用户错误。
- Fixture 缺失/畸形时测试失败信息包含路径但不泄密。
- Redactor 能移除 Cookie/token/BDUSS/STOKEN 等敏感键。
- UI smoke 使用固定 launch scenario，不访问互联网。
- 测试不依赖随机 UUID、系统当前时间或 `sleep()`。

## 不允许

- 不创建贴吧业务 endpoint。
- 不写推荐/吧/帖子 UI。
- 不使用全局 mutable singleton 作为“注入”。
- 不把 test-only 代码暴露到 Release 行为。
- 不为了测试禁用 strict concurrency。

## 验收

- 可确定性模拟慢网、错误、取消和乱序。
- App 的依赖在组合根可替换。
- unit/UI smoke 全绿且重复运行稳定。
- `make quality` 通过。

完成后停止。


---

# 文件：`Prompts/05_DESIGN_SYSTEM_AND_APP_SHELL.md`

# 阶段 05：Design System、导航和 App Shell

本阶段建立统一视觉/反馈/路由基础，只使用占位 Feature，不接贴吧数据。

## 开始前

- 读取 `Specs/04_INTERACTION_CONTRACT.md`、`Specs/05_MOTION_CONTRACT.md`、ADR-0003。
- 跑当前质量基线。
- 明确 iPhone 与 iPad route 状态模型，再写 View。

## 实现

### DesignSystem

- 语义颜色：background、surface、primary/secondary text、separator、accent、error、mediaBackground。
- Typography：Dynamic Type 语义样式，不硬编码内容固定高度。
- Spacing、corner radius、icon size。
- Motion 令牌，统一 Reduce Motion 入口。
- 标准组件：InitialLoading、InlineLoading、EmptyState、FullPageError、InlineError/Retry、PaginationFooter。
- 所有组件有 Preview/fixture 和 accessibility 行为。

### App Shell

- 主 Tab：推荐、关注的吧、设置/账户占位。
- iPhone：每个 Tab 独立 NavigationStack/path。
- iPad：NavigationSplitView 或 ADR 指定方案，窄宽度折叠。
- AppRouter 使用稳定 route，不依赖 `AnyView` 或大量 Bool。
- Debug-only 场景菜单可进入组件画廊，Release 不暴露。
- 不自定义页面 push/pop 动画。

## 状态保持测试

- 在推荐占位页 push 两层，切到关注页，再切回，path 保持。
- 两个 Tab 的 path 不互相污染。
- iPad 选择项在宽/窄切换后有定义行为。
- 重复点击 Tab 不重建 App root。
- 深色、大字体、Reduce Motion 下组件可读。

## 禁止

- 不添加 DragGesture。
- 不使用 `UIScreen.main.bounds`。
- 不在 App 根节点添加 `.animation`。
- 不通过 `.id(UUID())` 强制 Tab 刷新。
- 不创建真实 Feature store 或网络请求。

## 验收

- App Shell 在 iPhone/iPad Simulator 可操作。
- 标准状态组件覆盖首次、空、失败、inline failure。
- 动效调用全部来自 Motion。
- UI tests 证明 Tab/path 状态保持。
- `make quality` 通过。

完成后停止。


---

# 文件：`Prompts/06_PAGER_AND_MEDIA_INTERACTION_SPIKES.md`

# 阶段 06：Pager 与 MediaViewer 隔离交互 Spike

这是高风险交互验证阶段。显式使用 `$ios-interaction-qa`；实现问题另开单一写入任务。只在 Debug/InteractionLab 中开发和测试，不接业务 Feature。目标是以证据选择稳定实现，而不是追求功能数量。

## 前置

- 读取 ADR-0004、ADR-0005、交互契约、动效契约。
- App Shell 质量门禁通过。
- 先列出候选方案与已知风险，确认 ADR 选择或在证据后更新 ADR。

## Pager Lab

使用颜色明显且不透明的固定页面、稳定 ID 和可配置延迟，至少验证：

- 当前/前后相邻页面保持存活。
- 快速连续左/右滑 20 次。
- 滑动一半取消、反向滑动。
- 数据插入/删除，但当前业务 ID 仍存在。
- 数据刷新时不临时变空。
- iPhone 左边缘系统返回优先级。
- 旋转和 iPad resize。
- Reduce Motion。
- 背景全程无白块/透明露底。

若采用 UIKit wrapper：明确 coordinator、delegate、update/dismantle、页面缓存和 index 同步；禁止在每次 SwiftUI update 无条件 reset。

## Media Lab

使用本地小图、大图、延迟图和失败图：

- 单图/多图打开。
- 双击缩放、捏合、平移。
- zoom 后尝试翻页，验证手势仲裁。
- 翻页后 zoom 不串页。
- 快速翻页、失败图、加载中翻页。
- 旋转/resize 后 index 与 zoom 定义明确。
- 关闭时不留 overlay。

## 测试与证据

- 为状态/索引同步写单元测试。
- 为关键手势写 XCUITest；无法精确自动化的动作建立 Computer Use 手工脚本。
- 使用 Simulator/Computer Use 完整执行矩阵并保存截图/录屏引用到 `Docs/Audits/INTERACTION_SPIKE_REPORT.md`。
- 对每个发现的问题写根因，不只写视觉现象。
- 记录选定实现、拒绝方案、退出条件，更新 ADR。

## 严禁

- 不接推荐/帖子。
- 不通过 asyncAfter、UUID、zIndex 极值、透明遮罩或全局禁动画修复。
- 不同时保留两套生产 Pager。
- 不为了“像 Android”覆盖系统返回手势。

## 阶段出口

只有以下条件同时满足才能将组件标记 `SPIKE_ACCEPTED`：

- 自动化测试通过。
- 手工交互矩阵完成。
- 无已知白块、错页、遮挡、zoom 串页。
- ADR 和报告包含回滚方案。

未通过则保留为实验，不能让后续 Feature 复制它。停止并汇报。


---

# 文件：`Prompts/07_NETWORKING_PROTOBUF_FOUNDATION.md`

# 阶段 07：Networking、SwiftProtobuf 与贴吧协议基础

本阶段建立可测试的真实协议实现，但不把 live 网络接到 UI。

## 前置

- `Specs/API_EVIDENCE.md` 与 `PROTOBUF_MAP.md` 已完成到足以实现首个匿名 endpoint。
- ADR-0006 已 Accepted。
- 工程、测试底座绿色。

## Protobuf

- 按来源与许可证记录，把必要 `.proto` 放入明确目录或以构建脚本从只读 reference 生成。
- 使用 SwiftProtobuf，生成步骤可重复且写入 `scripts/generate_protos.sh`。
- 生成代码不得手工编辑。
- 先只生成 P0 首批依赖闭包，不盲目导入所有无关 proto。
- 验证至少一个 Android/脱敏 binary fixture 可被 Swift 解析。
- 未知 enum/字段必须安全兼容。

## Networking

建立：

- 强类型 Endpoint/Request。
- URLSession HTTPClient actor 或 ADR 指定实现。
- query/form/protobuf 编码。
- response status、content type、decode、server error 映射。
- cancellation、timeout、retry policy（默认不盲目重试非幂等请求）。
- Cookie/session 注入接口，但本阶段使用 fixture/fake session。
- request/response logging redaction。

## Evidence 驱动

首批 endpoint 只允许来自 `API_EVIDENCE` 中证据充分的匿名能力，例如推荐或帖子首屏。每个实现提交同时包含：

- Android 源路径/symbol 注释或文档引用。
- 请求构造测试。
- binary/JSON response fixture。
- Proto → domain mapper test。
- 缺字段、未知 enum、畸形 payload、HTTP error、取消测试。

不得让 View 看到 Proto。

## Live probe

若权限与网络允许，可写 Debug-only 命令行/测试 probe 验证公开匿名 endpoint：

- 输出仅包含 status、大小、解析结果摘要。
- 严格脱敏。
- 不作为 CI/unit test。
- 失败不影响 fixture 驱动功能，但必须更新 UNKNOWN/风险。

## 验收

- Protobuf 生成可重复。
- 首批 fixture 解析和领域映射全绿。
- 网络 client 能模拟并正确处理取消/超时/畸形响应。
- Release UI 尚未接 live 网络。
- `make quality` 通过。

完成后停止。


---

# 文件：`Prompts/08_THREAD_CONTENT_DOMAIN_AND_RENDERER.md`

# 阶段 08：帖子内容领域模型与只读渲染器

本阶段只实现内容节点映射与隔离 Renderer Lab，不做完整帖子分页页面。

## 前置

- `Specs/CONTENT_NODE_MATRIX.md` 有代码证据。
- SwiftProtobuf 基础与 fixture loader 绿色。
- 先选取覆盖实际节点的脱敏 fixtures。

## 领域模型

建立与 UI/Proto 解耦的内容节点，例如：

- text
- image
- link
- emoji
- mention/quote
- line break/layout marker
- 已证实的其他节点
- unsupported/unknown

不要先假设节点集合；以矩阵为准。领域模型必须：

- Sendable、稳定 ID 或稳定顺序语义。
- 能表达缺字段和降级文本。
- 不包含 SwiftUI `View`、Proto message 或网络对象。

## Mapper

- 按 Proto 节点顺序映射，不能丢失相邻文本。
- 无效图片 URL/尺寸安全降级。
- 未知 enum/节点生成 UnsupportedNode，不崩溃。
- 链接展示文本与目标分离。
- 超长、空、删除/屏蔽内容有明确结果。

## Renderer Lab

- 使用标准 typography/color/spacing。
- 文本支持 Dynamic Type 和选择策略（按规格）。
- 图片占位与最终 frame 稳定，点击只触发统一 Media route。
- 链接使用统一外链策略。
- unknown node 显示低干扰占位或可读文本。
- 不加入任意动画、横滑或全屏 overlay。

## 测试

- 每种 P0 节点至少一个 mapper test 和 renderer smoke fixture。
- 混合节点顺序测试。
- 缺字段、未知 enum、坏 URL、超长文本、大字号、深色模式。
- Renderer 不直接请求网络；ImageLoading 可注入。

## 验收

- 内容矩阵中所有 P0 节点为 Supported 或明确 Degraded。
- 未知内容不崩溃、不吞相邻内容。
- 领域模型不泄漏 Proto。
- Renderer Lab UI smoke 通过。
- `make quality` 通过。

停止，不做完整 ThreadScreen。


---

# 文件：`Prompts/09_MEDIA_VIEWER_PRODUCTION.md`

# 阶段 09：将已验证 MediaViewer 升为唯一生产组件

只有阶段 06 标记 `SPIKE_ACCEPTED` 时执行。否则停止并报告前置不满足。

## 目标

把实验组件清理为 `InteractionKit/MediaViewer` 唯一生产实现，接入可注入 ImageLoading，但暂不接完整帖子页。

## 必须完成

- 删除或隔离被拒绝的实验实现，防止后续误用。
- 公共 API 只暴露稳定媒体 ID、初始 index、图片请求描述和关闭/页变更事件。
- 内部 UIKit/SwiftUI bridge 生命周期完整。
- 每页 zoom/pan 状态归属明确；复用/删除页面可预测。
- 邻页预取策略有上限；取消不可见的大图请求。
- 背景使用语义 `mediaBackground`，加载/失败不露白。
- chrome、安全区、状态栏策略统一。
- 支持 Reduce Motion。
- accessibility：当前索引、关闭按钮、图片描述。

## 手势契约

按 ADR 实现并测试：

- 单击 chrome。
- 双击缩放。
- 捏合/平移。
- zoom 与分页仲裁。
- 首尾边界。
- 系统 dismiss/返回。

首版不擅自加入下滑关闭。

## 回归

重复阶段 06 全矩阵，在生产路径运行。额外验证：

- 50 次打开/关闭无 overlay 残留。
- 快速浏览多张大图，内存不会持续单调增长到不可接受。
- 加载任务在关闭/切页后正确取消或降级。
- 切换深色/旋转/resize 不露底。

## 验收

- 仓库只有一个可被 Feature 使用的 MediaViewer。
- 所有 interaction tests 通过。
- 报告明确新增动画、手势和 UIKit bridge。
- `make quality` 通过。

完成后停止。


---

# 文件：`Prompts/10B_VISUAL_AND_INTERACTION_BASELINE.md`

# 阶段 10B：冻结首条链路的视觉与交互基线

仅在阶段 10 fixture 垂直链路功能门禁完全绿色后执行。本阶段不接 live API，不重新设计架构；目标是把已通过的界面和交互转成后续可重复比较的基线，避免接 API 或新增 Feature 时悄悄破坏布局/动画。

## 基线环境

记录真实可用的：

- Xcode/iOS runtime。
- iPhone 小屏和大屏各一个。
- iPad 全屏与窄分屏场景。
- 浅色/深色。
- 默认字号与一个无障碍大字号。
- Reduce Motion 开/关。
- 固定 fixture、locale、时区和内容尺寸。

## 需要冻结的状态

至少保存 XCUITest 截图附件或明确的本地证据路径：

- 推荐 initial/loading/loaded/empty/error/refresh/next-page error。
- 帖子 loaded、未知节点、图片失败、分页 footer。
- MediaViewer 单图/多图/加载/失败/缩放后 chrome。
- 返回推荐后的滚动锚点。
- iPad 展开/折叠布局。

不把动态系统状态栏、时钟或随机数据作为像素级硬断言。截图用于发现布局/露底/遮挡回归，行为真相仍由状态与 UI 断言负责。

## 交互录像/脚本

使用 `$ios-interaction-qa` 和 Computer Use 运行：

1. 快速连续切换、半程取消、反向操作。
2. 打开/关闭媒体 20 次。
3. 缩放后翻页尝试与回到 1x 后翻页。
4. 滚动中触发刷新/分页失败并重试。
5. 旋转或 iPad resize 中保持 route/index/锚点。
6. Reduce Motion 下重复主链路。

记录 PASS/FAIL、证据、状态/route/index 和任何无法自动化项。

## 静态清单

- 动画调用都映射到 Motion token 和具体语义。
- Feature 无 DragGesture、UIScreen bounds、随机 identity、任意 zIndex、根隐式 animation。
- overlay/sheet/fullScreenCover 清单及生命周期明确。
- 页面/列表背景不透明且一致。

## 输出

- `Docs/Audits/VISUAL_INTERACTION_BASELINE.md`
- `Docs/Audits/Baselines/README.md`（说明证据是否入 Git、如何重跑、如何处理系统差异）
- 必要的 fixture UI tests 和启动场景。
- 不得因基线建立而加入第三方 snapshot 库；确有需要必须先 ADR。

## 验收

- 后续阶段有可重复的比较入口，而不是凭记忆判断“动画变了”。
- 所有截图/录屏无真实账号与敏感内容。
- 不修改 live repository。
- `make quality` 与 `/review` 通过。

完成后停止。


---

# 文件：`Prompts/10_RECOMMENDATIONS_VERTICAL_SLICE_FIXTURE.md`

# 阶段 10：推荐 → 帖子首屏 → 图片 → 返回的 Fixture 垂直链路

这是第一个完整用户链路，但必须完全使用 fixture/mock，不能接 live 贴吧。目标是先证明状态、导航、滚动、Pager 和 MediaViewer 稳定。

## 前置

- App Shell、状态组件、测试底座、内容 Renderer、生产 MediaViewer 绿色。
- 推荐与帖子首屏的领域 mapper/fixtures 可用。
- 先写完整状态机和验收测试清单。

## 推荐 Feature

实现：

- initial/loaded/empty/failure。
- refresh 保留旧内容。
- pagination 保留旧内容、尾部错误重试。
- 稳定 thread ID 去重。
- 请求代次和取消。
- 主题行：标题、吧名、作者/摘要/统计/缩略图等仅按证据显示。
- 稳定 accessibility identifiers。

## Thread 首屏

- 点击推荐主题进入 Thread route。
- 显示帖子元信息、首批楼层、已支持内容节点。
- 加载/空/失败使用统一状态组件。
- 点击图片打开唯一 MediaViewer，并从正确 index 开始。

## 返回不变量

必须自动化验证：

1. 推荐加载并滚动到中后部。
2. 打开某主题。
3. 滚动帖子并打开第 N 张图片。
4. 左右切图、缩放、关闭。
5. 帖子仍在原附近位置。
6. 返回推荐，推荐列表、分页数据和滚动锚点保持。
7. 切换 Tab 再返回，状态仍保持。

## 必测场景

- recommendations.success / empty / initial-error。
- refresh success/failure。
- next-page success/failure/duplicate IDs。
- stale refresh response。
- thread success/malformed-node/image-failure。
- Reduce Motion、深色、大字体。
- iPhone；涉及 Media/导航时至少一个 iPad Simulator smoke。

## 禁止

- 不接 live 网络。
- 不在行 `onAppear` 无防护分页。
- 不使用 UUID 刷新、根动画、自定义 push。
- 不因图片未加载把页面替换成透明/空 View。
- 不复制第二套 MediaViewer/Pager。

## 验收

- 上述链路在 XCUITest 与 Computer Use 手工流程均通过。
- 没有白块、遮挡、错页、跳顶或状态丢失。
- State tests 覆盖取消/乱序/分页去重。
- `make quality` 和 `/review` 无 P0/P1。

完成后停止。


---

# 文件：`Prompts/11_LIVE_API_RECOMMENDATIONS_AND_THREAD.md`

# 阶段 11：推荐与帖子首屏的 Live API 接入

目标：在不改变已验证 UI/交互状态机的前提下，把推荐和帖子首屏 repository 从 fixture 实现扩展为生产实现。UI tests 仍只使用 fixture。

## 前置

- 阶段 10 垂直链路完全绿色。
- 对应 endpoint 在 `Specs/API_EVIDENCE.md` 中证据充分。
- SwiftProtobuf mapper tests 已用脱敏真实样本验证。
- 工作树 clean，并记录阶段 10 绿色 commit。

## 核心原则

- 只替换 data/repository 路径，不顺手重写 View、导航、Pager 或动画。
- `AppEnvironment` 明确选择 fixture/live；Release 默认 live，UI test 强制 fixture。
- 真实网络不可用时不能破坏 fixture 测试或假称功能完成。
- 不把网络返回的 Proto 直接交给 View。

## 实现

### RecommendationsRepositoryLive

- 按证据构造 request。
- 正确编码分页参数/cursor。
- 映射 domain item，稳定 ID 与 fixture 路径一致。
- 服务端重复项、缺字段、未知贴类型安全处理。
- 区分 transport、HTTP、decode、server、authentication、cancelled。
- 不对每个 cell 单独请求可批量得到的数据。

### ThreadRepositoryLive（首屏）

- 按证据解析帖子元信息、楼层和内容节点。
- 图片 URL/尺寸/索引与 Media route 一致。
- 未知内容节点走既有降级，不增加临时 View 分支。
- 会话可选：匿名可读时不强制登录；需要认证时返回明确能力错误。

## Live 验证

创建 Debug-only、不可进入自动测试的 live smoke：

- 发出最少请求。
- 记录 endpoint 名、HTTP 状态、响应大小、decode 结果计数、耗时。
- 日志和附件严格脱敏。
- 不保存完整用户内容到 Git。
- 对 live 数据人工验证：空字段、图片、分页、删除贴、未知节点。

不得用 live 请求作为 `make quality` 的必要条件。

## 回归

- fixture 状态/UI tests 全部不改行为且通过。
- 新增 live repository 的 request/mapper/error/cancellation tests。
- 快速刷新和分页乱序仍由 Store 丢弃旧响应。
- 切回 fixture 环境时没有残留 Cookie/cache 影响。

## 停止条件

若 endpoint、签名或字段证据不足：

1. 不猜测。
2. 更新 `Specs/UNKNOWN_BEHAVIORS.md` 与 API evidence。
3. 保持生产 repository 对该能力返回可诊断 unsupported/unknown error。
4. 报告缺少的最小证据。

## 验收

- 生产 repository 可被 Debug live 环境调用。
- UI 与交互代码未发生无关重写。
- Fixture tests、unit tests、quality gate 全绿。
- Live 验证结果诚实记录。

完成后停止。


---

# 文件：`Prompts/12_SESSION_AND_LOGIN.md`

# 阶段 12：Session、登录、Cookie 与失效处理

这是安全敏感阶段。必须依据 `ADR-0007` 与 Android 源码证据实现，不能凭经验发明百度登录参数，也不能让 Codex 获取或记录用户密码。

## 前置

- `Specs/API_EVIDENCE.md` 中登录/会话相关证据已标明充分度。
- ADR-0007 已 Accepted，若仍有 UNKNOWN，先更新 ADR 的可验证范围。
- Fixture session 测试底座已存在。

## 安全边界

- App 不自行采集、保存或打印用户名/密码。
- 若采用官方网页登录，只允许已批准的百度登录域名和跳转规则；不注入脚本窃取表单。
- Codex/Computer Use 不代用户输入真实凭据，不录制含敏感内容的屏幕。
- Cookie/token 只保存必要字段，使用 Keychain 或 ADR 指定安全存储。
- 日志、测试附件、fixture、Git diff 必须通过 redaction 检查。
- 不关闭 TLS 校验，不接受任意证书。

## 状态机

实现并测试：

```text
signedOut
→ authenticating
→ signedIn(identity summary)
→ expired
→ signedOut

任何阶段可进入 failed(previous safe state)
```

明确：

- App 冷启动会话恢复。
- Cookie store 与 URLSession 同步。
- 过期如何从 server error 统一识别。
- 多个页面同时收到过期时只触发一次全局状态变化。
- 退出登录清理 Keychain、cookie、用户隔离缓存和 UI path。
- 取消登录回到 signedOut，不显示普通网络错误。

## 自动化测试

全部使用 fake web/session：

- 登录成功、取消、失败。
- 冷启动恢复。
- Cookie 注入到需要认证 endpoint。
- 不向匿名 endpoint 泄漏不必要身份信息。
- 会话过期的统一处理和页面旧内容策略。
- 退出清理。
- Redaction 单元测试覆盖敏感 key 与 header。

## 真实手工验证

真实登录只提供用户手工检查清单：

1. 用户自行输入凭据。
2. 登录完成后仅检查身份摘要和关注吧能力。
3. 关闭/重开 App 验证恢复。
4. 退出后验证清理。

不得把真实凭据或 Cookie 写入报告。Computer Use 只可在不显示凭据的页面验证后续 UI。

## 禁止

- 不实现签到/发帖/评论写操作。
- 不把 Cookie 放 UserDefaults。
- 不用全局 NotificationCenter 广播模糊 session 事件。
- 不在各 Feature 重复弹登录失效提示。
- 不因登录状态变化重建整个 App root 并丢失可安全保留的匿名状态。

## 验收

- Fake session 全矩阵自动化通过。
- 真实登录流程有安全、可执行的手工清单；若未实测，明确标注。
- 任何日志/附件无敏感值。
- `make quality` 与安全专项 review 通过。

完成后停止。


---

# 文件：`Prompts/13_FOLLOWED_FORUMS.md`

# 阶段 13：我关注的吧

实现登录/未登录两种完整体验，先 fixture 后 live repository；不实现关注/取消关注等写操作。

## 前置

- Session 状态机绿色。
- 关注吧 endpoint/proto 在 API evidence 中有证据。
- App Shell 的关注 Tab 已有稳定 route。

## 状态与行为

### 未登录

- 明确的 signed-out 空态和登录入口。
- 不自动弹出登录页阻断其他 Tab。
- 登录取消后仍保持当前页面可用。

### 已登录

- 首次、成功、空、失败、刷新。
- 若接口分页，按证据实现并测试；没有分页证据不得自行添加。
- 稳定 forum ID 去重。
- 行显示吧头像、名称、等级/未读等仅限证据字段。
- 点击进入 `ForumRoute(forumID, name)`。
- 返回后列表和滚动位置保持。

### Session 失效

- 保留非敏感缓存的策略按 ADR。
- 页面进入统一 expired/signed-out 表达，不重复弹窗。
- 重新登录后明确刷新行为。

## 实现顺序

1. fixture states 和 Store tests。
2. fixture UI 与 route tests。
3. live repository request/mapper tests。
4. Debug live smoke。
5. 完整回归。

## 测试

- 未登录→登录 fixture→列表。
- 登录取消。
- 登录过期。
- refresh failure 保留旧列表。
- 大量吧列表快速滚动和头像复用。
- 打开吧首页返回位置。
- 深色、大字体、iPad。

## 禁止

- 不在 row 中直接请求头像外的业务数据。
- 不用 session Bool 分散在 View。
- 不实现远端关注/取消关注。
- 不为该页面复制错误/加载组件。

## 验收

- Fixture UI tests 稳定。
- Live 能力诚实记录。
- Session 和 route 无重复状态源。
- `make quality` 通过。

完成后停止。


---

# 文件：`Prompts/14_FORUM_HOME_AND_THREAD_LIST.md`

# 阶段 14：吧首页与吧内主题列表

目标：实现 FRS/吧页的完整只读浏览，包括吧信息、置顶/普通主题、排序/分区、刷新和分页，同时保持交互统一。

## 前置

- Forum endpoint/proto/API evidence 足够。
- 关注吧 route 可进入占位 Forum 页面。
- PagerContainer 若产品规格要求横滑分区，必须已 Accepted；否则优先用系统 selector + 单列表，不自行发明横滑。

## 状态拆分

吧头信息和主题列表可能独立加载，必须定义：

- HeaderState。
- 每个 filter/sort 的独立 PagedState。
- 当前 selection。
- refresh/header failure/next-page failure。
- 旧请求与切换 selection 的隔离。

禁止一个 `isLoading` 管全部状态。

## 功能

- 吧名称、头像、简介、关注数等仅按证据显示。
- 主题行支持置顶、普通、删除/缺字段、图片摘要及已证实特殊类型。
- sort/filter 列表来自服务端证据或固定产品规格。
- 每个 selection 保留自己的 items、cursor、error、scroll anchor。
- 快速切换 selection 时取消/忽略旧响应，不能串页。
- refresh 保留当前内容；next-page error 使用尾部重试。
- 打开帖子→返回，吧列表状态和位置保持。

## 交互

- selector、下拉刷新、分页、错误反馈与推荐流复用同一标准。
- 如果使用 Pager：只调用唯一 PagerContainer，不在 Feature 中处理 DragGesture。
- iPad 侧栏选吧、详情列表、帖子详情按 route/size class 映射。
- 不叠加自定义导航动画。

## Fixture 场景

- success/empty/initial-error。
- header-only failure/list-only failure。
- pinned + normal + deleted + malformed。
- refresh failure。
- next-page failure/duplicate IDs。
- two filters with crossed stale responses。
- large titles/dark/dynamic type。

## Live 接入

UI fixture 通过后才接 live repository。每个 sort/filter 的请求参数必须有 API evidence。没有证据的选项不显示。

## 验收

- 快速切换/刷新/分页无重复请求、串页、跳顶或白块。
- 打开帖子返回状态保持。
- iPhone/iPad smoke 通过。
- `make quality` 和 interaction review 通过。

完成后停止。


---

# 文件：`Prompts/15_FULL_THREAD_READER_AND_SUBPOSTS.md`

# 阶段 15：完整帖子阅读、分页与楼中楼只读浏览

扩展阶段 10 的帖子首屏为生产级 ThreadReader。仍不实现发布回复/评论。

## 前置

- 内容节点矩阵和 Renderer 已验证。
- PB/thread endpoint、分页和楼中楼 endpoint 有证据。
- 推荐、吧页均能进入同一 Thread route。

## 状态模型

至少明确：

- Thread metadata。
- 楼层 paged state。
- 楼中楼按 floor/post ID 的独立 state。
- 当前阅读锚点/选中图片。
- 过滤/只看楼主（仅有证据并在范围时）。
- session 失效对匿名可读内容的影响。

楼层与楼中楼请求不得共享一个错误或 loading Bool。

## 功能

- 楼主/作者、楼层号、时间、内容、删除/屏蔽状态。
- 楼层分页、按稳定 post ID 去重。
- 楼中楼预览、展开、分页、失败重试，只读。
- 贴内所有图片映射到正确媒体集合/index；关闭后锚点保持。
- 外链/提及等按内容契约处理。
- 未知节点降级，不崩溃。
- 大帖子使用惰性列表但保持稳定身份。

## 异步与复用

- 同一楼中楼最多一个在途请求。
- cell 消失不应无条件取消用户已展开内容；由 Store 生命周期管理。
- 快速展开多个楼层的结果不能串行写错目标。
- 新页面返回时旧响应不能覆盖当前 thread ID。
- 切换到另一个帖子后清晰隔离 cache/key。

## 测试

- 首次/分页/失败/重复/乱序。
- 楼中楼成功/空/失败/多楼层同时加载/旧响应。
- 删除楼层、缺作者、未知内容、坏图片。
- 大数据 fixture 快速滚动。
- 推荐→帖子→图片→返回→推荐。
- 吧页→帖子→返回→吧页。
- iPad 三列/折叠路径（按 ADR）。
- Dynamic Type、VoiceOver、Reduce Motion。

## 性能初检

- 不在主线程解码大 payload/图片。
- row body 不执行复杂 mapper。
- 不为每次状态变化重建所有内容节点 ID。
- 使用 signpost 或 Debug metrics 记录 decode/map/render 关键耗时。

## 验收

- 完整只读浏览稳定，写操作不存在或明确禁用。
- Pagination/Subposts 状态测试完整。
- MediaViewer 无回归。
- `make quality` 通过。

完成后停止。


---

# 文件：`Prompts/16A_SEARCH.md`

# 阶段 16A（P1）：搜索

只在所有 P0 核心链路绿色后执行。本提示词只实现搜索，不同时实现历史/设置/资料页。

## 范围

依据 Android 审计与 API evidence 确定：

- 搜索吧、主题或两者。
- 搜索建议/历史仅在有证据或本地需求时。
- 结果进入既有 ForumRoute/ThreadRoute，不复制详情页面。

## 状态

- idle（空查询）。
- debouncing。
- loading。
- loaded/empty/error。
- loading next page（若证据存在）。
- query generation，旧查询响应不能覆盖新查询。

## 交互

- 使用系统 searchable/search field。
- 键盘、安全区、取消和返回符合系统行为。
- debounce 使用可测试 Clock，不用 `asyncAfter`。
- 清空查询取消任务并恢复 idle。
- 搜索结果使用稳定 ID。

## 测试

- 快速输入多个查询，旧结果丢弃。
- 清空、取消、离线、超时、空结果。
- 键盘出现/旋转/iPad split view 无遮挡。
- 打开吧/帖子后返回查询与位置保持。

## 验收

- 不复制 Forum/Thread UI。
- fixture 自动化优先，live 证据单独记录。
- `make quality` 通过。

停止。


---

# 文件：`Prompts/16B_HISTORY_AND_SETTINGS.md`

# 阶段 16B（P1）：浏览历史与设置

只实现本地功能，不引入远端写操作。

## 浏览历史

- 记录 thread ID、标题、吧、最后访问时间、可选阅读锚点。
- 不保存完整帖子正文或敏感 Cookie。
- 去重、容量上限、删除/清空策略明确。
- 持久化访问通过 protocol/actor，Feature 不直接读数据库。
- 打开历史项复用 ThreadRoute。

## 设置

仅实现有明确产品价值且能统一生效的选项：

- 主题跟随系统/浅/深（若批准）。
- 字体或内容密度（尊重 Dynamic Type，不绕过无障碍）。
- 图片加载策略（例如仅 Wi‑Fi，需有可测试网络条件抽象）。
- 清理图片/内容缓存。
- 关于、来源和许可证。

禁止为每个页面保存一套设置副本。

## 测试

- 历史去重、排序、容量、清空、会话隔离策略。
- 设置持久化、冷启动恢复、即时生效。
- 清缓存不清 Keychain/session，退出登录按 ADR 清理。
- 大字体/深色无冲突。

## 验收

- 本地数据模型与隐私边界有 ADR/说明。
- 设置通过依赖/环境统一传播，不重建整个 App root。
- `make quality` 通过。

停止。


---

# 文件：`Prompts/16C_USER_PROFILE_READ_ONLY.md`

# 阶段 16C（P1）：用户资料只读页

只在 Android 审计和 endpoint 证据充分时实现。不得加入关注、私信、点赞等写操作。

## 功能

- 从作者头像/名称进入稳定 UserRoute。
- 显示公开身份摘要和已批准的公开内容。
- 错误、空、分页按标准 PagedState。
- 打开主题复用 ThreadRoute。
- 当前登录用户与他人资料共用领域模型，但权限/字段显式区分。

## 安全

- 不显示或记录隐私字段。
- 不将用户页响应无限缓存。
- Session 失效按统一规则。

## 测试

- 公开用户、缺字段、已删除/不可见、未登录、过期。
- 大头像失败、长名称、Dynamic Type。
- 打开帖子返回资料页位置。

完成质量门禁后停止。


---

# 文件：`Prompts/17_IPADOS_ADAPTATION_HARDENING.md`

# 阶段 17：iPadOS、旋转、分屏和多窗口尺寸硬化

架构从第一天支持 iPad，本阶段做系统性验证和缺口修复，不另写一套 iPad 业务层。

## 前置

- P0 iPhone 核心链路绿色。
- ADR-0003 已定义宽/窄映射。
- 使用实际可用 iPad Simulator；记录型号/runtime。

## 必须验证的宽度/方向

- 11/13 英寸类全屏横屏与竖屏。
- 至少一个约半屏宽度。
- 一个窄到 SplitView 折叠的宽度。
- 运行中 resize，而非只冷启动不同尺寸。

## 用户流

1. 推荐→帖子→图片→返回。
2. 关注吧→吧首页→帖子→返回。
3. 吧/帖子选择在 SplitView 展开与折叠间保持。
4. Search（若实现）键盘和结果。
5. Sheet/MediaViewer 在 resize、旋转中保持正确层级。

## 修复规则

- 根据可用宽度和系统容器布局，不检测具体 iPad 型号。
- 不使用 `UIScreen.main.bounds`。
- 不通过 duplicated iPadView 重写业务 Store。
- Sidebar/detail selection 和 NavigationPath 有单一映射，不双向死循环。
- resize 时不重置列表、current media index、zoom 或 session。
- 过窄时内容自适应/换行，不用固定 frame 裁切。

## 测试

- UI tests 覆盖宽/窄启动和关键 route。
- Computer Use 手工执行运行中 resize/旋转，附证据。
- Pager/MediaViewer 重新跑 resize 矩阵。
- Dynamic Type + split view 组合。

## 验收

- 无遮挡、白块、详情错配、重复导航、状态丢失。
- iPad 与 iPhone 共享 Feature/domain/data 实现。
- `make quality` 和 iPad 专项 test plan 通过。

停止。


---

# 文件：`Prompts/18_ACCESSIBILITY_PERFORMANCE_RESILIENCE.md`

# 阶段 18：可访问性、性能、内存与故障韧性硬化

本阶段不新增产品功能，只查证和修复质量问题。建议 Ultra 只读并行审计；主代理唯一写入。

## A. 可访问性

审计所有 P0 流程：

- VoiceOver label/value/hint、阅读顺序、重复元素。
- 点击区域和按钮语义。
- Dynamic Type 默认及无障碍大字号。
- 深色/高对比语义颜色。
- Reduce Motion。
- 图片替代文本/装饰标记。
- 错误和 loading 的可访问性公告不过度重复。

输出 `Docs/Audits/ACCESSIBILITY_AUDIT.md`。

## B. SwiftUI/主线程性能

使用 Xcode/Instrument 或可用的 SwiftUI profiling：

- 推荐列表滚动。
- 大帖子滚动。
- 分页插入。
- 图片 decode/显示。
- Tab/导航切换。

检查：

- body 计算和不稳定 identity。
- 主线程 Proto decode/map、磁盘或大图处理。
- 重复网络请求。
- 过度 state invalidation。
- 大量无必要动画 transaction。

先建立可重复 fixture 基线，再优化。禁止凭感觉微优化。

输出 `Docs/Audits/PERFORMANCE_AUDIT.md`，记录设备、scenario、测量方式、前后数据和不确定性。

## C. 内存

- 多图快速浏览后资源释放。
- 退出 MediaViewer 后 full-resolution 缓存有上限。
- 大帖子、切换多个帖子、前后台。
- UIKit coordinator/delegate/callback 无引用环。
- 取消不可见请求。

## D. 网络故障韧性

使用 mock chaos matrix：

- 延迟、乱序、丢包式失败、超时、500、畸形 Proto、空 body。
- Session 过期与匿名 fallback。
- 快速刷新/分页/切换 Tab/关闭页面。
- App 进入后台与恢复。

不得靠无限重试。重试次数、幂等性和用户触发策略明确。

## E. 稳定性扫雷

搜索并处理：

```text
try! / as! / fatalError / force unwrap
Task.detached
DispatchQueue.main.asyncAfter
.id(UUID())
UIScreen.main.bounds
根节点 .animation
重复 DragGesture/overlay/zIndex
空 catch / ignored error
```

并非机械替换；每处写明风险和修复证据。

## 验收

- 所有 P0 流程通过可访问性和故障矩阵。
- 性能/内存有可复现基线与无明显回归证据。
- 静态禁用模式无未经批准命中。
- 完整 test plans 和 `make quality` 通过。

停止。


---

# 文件：`Prompts/19_FINAL_PARITY_AND_RELEASE_PREFLIGHT.md`

# 阶段 19：最终功能一致性、发布前检查与风险清单

本阶段不擅自添加缺失功能；先进行只读审计，再只修复明确 P0 缺口。建议 Sol Ultra 将审计分为独立只读工作流。

## 审计输入

- Android reference 固定 commit。
- `Specs/FEATURE_MATRIX.md`、API evidence、内容节点矩阵。
- 所有 ADR。
- 自动化 test plans。
- 最新 App build 与 Simulator 录屏。

## 并行只读审计

1. 功能矩阵与 route。
2. 推荐/关注吧/吧首页/帖子数据和状态。
3. 内容节点/图片。
4. iPhone/iPad 交互与动效。
5. 网络/session/隐私。
6. 测试、性能、可访问性。
7. 许可证、来源、品牌和发布说明。

主代理合并为 `Docs/Audits/FINAL_PARITY_AUDIT.md`，每项标：

- PASS
- PARTIAL
- FAIL
- OUT_OF_SCOPE
- UNKNOWN

不得把 OUT_OF_SCOPE 写成 PASS。

## 发布前检查

- Release 配置可构建；可在无真实 Team 的情况下完成 unsigned/generic archive 可行性检查，或记录签名阻塞。
- 无 Debug menu、fixture credential、测试开关误入 Release UI。
- 无密钥、Cookie、token、真实用户数据。
- Privacy/网络权限说明与实际一致。
- 第三方依赖许可证清单。
- Android 参考与 GPL 来源说明。
- App 名称、图标和文案不暗示百度官方授权。
- 崩溃/日志策略不收集敏感正文。
- README 包含构建、测试、限制和已知风险。

## 最终矩阵实跑

至少完整执行：

- iPhone 小/大尺寸。
- iPad 横/竖与分屏。
- 浅/深、大字体、Reduce Motion。
- Offline/slow/error/session expired。
- 推荐→帖子→媒体→返回。
- 关注吧→吧→帖子→返回。

记录真实 test command、xcresult 和手工证据路径。

## 修复权限

- 只修 P0/P1 明确问题。
- 任何架构级改动先写风险和最小方案。
- 不在最终阶段顺手改设计风格、升级依赖或加入动画。

## 交付

- `FINAL_PARITY_AUDIT.md`
- `RELEASE_PREFLIGHT.md`
- `KNOWN_LIMITATIONS.md`
- 更新 `README.md`
- 最终测试结果与 commit

完成后停止，不自动提交 App Store。


---

# 文件：`Prompts/20_ROOT_CAUSE_BUG_FIX.md`

# Bug 修复：证据驱动的根因流程

把下面的 `[BUG DETAILS]` 替换为实际信息，或附上已填写的 `Specs/09_BUG_REPORT_TEMPLATE.md`。严格使用 `$ios-root-cause-debug` skill。不得扩大为重构任务。

## BUG DETAILS

```text
Bug ID/标题：
发生 commit：
最后已知正常 commit（若有）：
设备与系统：
窗口/方向：
外观/字体/Reduce Motion：
网络与 Session scenario：
复现步骤：
预期：
实际：
频率：
截图/录屏/日志：
```

## 强制流程

### 1. 冻结范围

- 读取 AGENTS、相关交互/状态规格和 ADR。
- `git status --short`，记录已有改动；不能覆盖用户未提交工作。
- 列出最多 5 个直接相关文件区域。
- 不顺手格式化、升级依赖或修其他问题。

### 2. 建立确定性复现

- 优先使用既有 fixture/LaunchScenario。
- GUI-only 问题使用 Simulator/Computer Use，按完全相同步骤至少复现 3 次。
- 保存失败前后的状态、route、稳定业务 ID、任务 ID、page/index、zoom、尺寸、安全区和动画 transaction。
- 无法复现时先增强诊断，不进行猜测式视觉修改。

### 3. 分类与证据

依次检查并排除：

1. 状态机不合法转换。
2. 请求取消/旧响应覆盖。
3. SwiftUI view identity/列表复用。
4. NavigationPath/route 重建。
5. Safe Area/overlay/z-order/keyboard。
6. 手势识别优先级和方向锁。
7. implicit animation/transaction。
8. UIKit coordinator/delegate/update 生命周期。
9. 图片请求、cache、decode 和资源释放。
10. 真实 API 边界数据。

输出一条主要根因陈述：

```text
当 [条件] 时，[具体状态/对象] 因 [机制] 进入 [错误状态]，从而产生 [用户现象]。
证据是 [日志/测试/代码路径]。
```

不要只列十个“可能原因”。

### 4. 先写失败回归

- 优先写最接近根因的状态/组件测试。
- 用户可见流程再加 UI test。
- 测试在修复前必须真实失败，并记录失败结果。
- 无法自动化时，写确定性手工回归脚本与可观察断言；解释限制。

### 5. 最小修复

- 一次只验证一个根因。
- 修复状态归属、身份、生命周期、取消或布局契约，不调一串随机参数。
- 禁止 asyncAfter、`.id(UUID())`、全屏透明遮罩、全局禁动画、无限 zIndex、重建根导航、清缓存假修复。
- 如果第一个假设被证伪，回退该尝试后再进入下一个假设。

### 6. 验证

- 回归测试由红变绿。
- 运行受影响组件的全部状态/交互测试。
- 重跑原复现 10 次或适合该问题的稳定次数。
- 验证反向/邻近场景：返回、旋转、iPad resize、深色、大字体、Reduce Motion、慢网、取消。
- 运行 `make quality-fast`，阶段性重要修复运行 `make quality`。

### 7. 停止规则

同一 Bug 连续两个修复尝试仍未通过：

- 停止堆补丁。
- 回退失败尝试。
- 输出组件状态、身份、生命周期重设计方案和迁移测试。
- 不开始第三个视觉补丁。

## 完成报告

- 确定根因及证据。
- 修复前失败测试。
- 最小代码变化。
- 修复后测试/复现结果。
- 未覆盖风险。
- 是否新增动画、手势、overlay、依赖。


---

# 文件：`Prompts/21_INTERACTION_GESTURE_LAYOUT_BUG.md`

# 交互专项 Bug：白块、遮挡、错页、跳动、手势冲突

在填写实际现象后，显式调用 `$ios-interaction-qa` 与 `$ios-root-cause-debug`。本提示词专门处理视觉交互问题，不允许“凭感觉调动画”。

## 现象

```text
页面/组件：
操作：
白块/露底/遮挡/错页/跳动/无法返回/手势冲突：
发生阶段：手势开始 / 交互中 / 完成 / 取消 / 旋转 / 返回后
设备、方向、窗口宽度：
网络/图片状态：已加载 / 加载中 / 失败
复现率：
证据：
```

## 先记录的运行数据

- 容器 bounds、safeAreaInsets、页面 frame。
- 当前业务 page ID、邻页 ID、显示 index、目标 index。
- SwiftUI identity 与 UIKit controller/object identity。
- 页面背景颜色/透明度链。
- 参与转场页面是否被移除或替换。
- gesture recognizers 的 state、translation、velocity、failure dependency。
- zoomScale、contentOffset、contentSize。
- overlay/sheet/fullScreenCover 的展示状态与 hit-testing。
- animation transaction、Reduce Motion。
- 图片 request ID、状态和取消。

## 白块/透明露底检查顺序

1. 容器及每层背景是否不透明。
2. 当前/相邻页在 interactive transition 中是否保持存活。
3. 数据更新是否临时发出空数组/空 page。
4. `.id` 是否因随机值或 index 改变导致重建。
5. UIKit wrapper 是否在 `updateUIViewController` 重设 controller。
6. 图片 loading/failure 是否返回透明 `EmptyView`。
7. 尺寸变化是否出现一帧旧 frame/零 frame。
8. 双重动画是否把内容移出但背景未覆盖。

## 遮挡检查顺序

1. 是否应使用 toolbar/safeAreaInset 而用了 overlay。
2. `.ignoresSafeArea` 是否施加到内容而非背景。
3. z-order 与 hit-testing 是否一致。
4. 键盘/sheet/rotation 后 inset 是否恢复。
5. fixed frame 是否在 Dynamic Type/iPad split view 溢出。
6. 根 ZStack 是否存在常驻透明层。

## 手势检查顺序

1. 系统边缘返回是否优先。
2. 横向 pager 与纵向 scroll 的方向锁。
3. 图片 zoom/pan 与翻页的边界规则。
4. 同一动作是否被 SwiftUI 与 UIKit 两套 gesture 同时处理。
5. 取消/失败状态是否正确重置。

## 修复与验收

- 先写失败测试/InteractionLab scenario。
- 修复唯一根因。
- 快速滑动 20 次、取消/反向 10 次、旋转/resize、加载中/失败图均验证。
- 使用纯红/绿/蓝调试背景临时发现露底，完成前移除调试色并保留自动断言/测试。
- 不能用延迟、随机 ID、遮罩、全局禁动画。

报告根因，不只报告“已调整参数”。


---

# 文件：`Prompts/22_ANIMATION_CONSISTENCY_AUDIT.md`

# 动画一致性专项审计与修复

显式使用 `$ios-motion-audit`。目标：找出所有显式/隐式动效，统一到 `Specs/05_MOTION_CONTRACT.md`，消除同一操作不同曲线、双重转场和数据刷新抖动。先审计后修改。

## 只读审计

运行并分类：

```bash
rg -n '\.animation\(|withAnimation\(|\.transition\(|\.spring\(|\.snappy\(|matchedGeometryEffect|CATransaction|UIView\.animate|UIViewPropertyAnimator' App Sources
rg -n 'DragGesture\(|gesture\(|simultaneousGesture|highPriorityGesture' App Sources
```

为每处记录：

- 文件/行/组件。
- 用户动作或状态变化。
- 动画来源：系统 / Motion token / 任意参数 / 隐式继承。
- 动画范围：局部属性 / 行 / 列表 / 整页 / 导航。
- Reduce Motion 路径。
- 是否与另一层系统/自定义动画叠加。
- 是否可能在网络批量更新触发。

输出 `Docs/Audits/MOTION_AUDIT.md`。

## 统一规则

- 系统 NavigationStack/SplitView/sheet 不叠加自定义整页转场。
- 同一 loading/error/banner 使用同一 Motion token。
- refresh/pagination 不逐行飞入，不替换整页。
- Feature 不写 duration/curve/spring。
- 根节点无广域隐式 `.animation`。
- 图片 load 最多局部 opacity，frame 不变。
- Reduce Motion 下移除非必要位移/缩放。

## 修改顺序

1. 删除无产品语义动画。
2. 收窄广域 animation 的 value 和作用范围。
3. 替换任意参数为 Motion token。
4. 消除系统 + 自定义双重转场。
5. 修复由状态重建而非动画参数导致的跳动。
6. 补充测试/录屏基线。

## 验证流

- 启动、Tab、push/pop。
- 推荐 initial/refresh/pagination/error。
- 吧分区切换。
- 帖子分页/楼中楼。
- MediaViewer 打开/切图/关闭。
- iPad resize。
- Reduce Motion。

每个流录制或用 Computer Use 重复，检查相同操作时序一致、没有白块/遮挡/双动画。

## 验收

- 所有自定义动画都能映射到 Motion token 和产品行为。
- 无根级广域隐式 animation。
- Reduce Motion 测试通过。
- `make quality` 和 motion 静态检查通过。


---

# 文件：`Prompts/23_REGRESSION_SWEEP.md`

# 回归扫测：完成一个阶段或重大 Bug 修复后使用

本任务不新增功能。调用 `$xcode-quality-gate` 和 `$ios-interaction-qa`，先运行自动化，再用 Computer Use 做最小手工矩阵。

## 输入

- 基线 commit：
- 当前 commit/工作树：
- 变更范围：
- 主要风险：
- 需要重点回归的 Bug ID：

## 自动化

1. `git diff --check`
2. 静态禁止模式扫描。
3. SwiftLint。
4. 受影响模块单元测试。
5. 全部 unit tests。
6. UI smoke。
7. 涉及交互时执行 interaction test plan。
8. 涉及 iPad 时执行 iPad test plan。

记录每条命令、退出码、xcresult 路径和失败测试。不得只给最后一句“全通过”。

## 手工最小矩阵

- 推荐→帖子→图片→返回。
- 关注吧→吧→帖子→返回（若 session fixture 可用）。
- 快速 Tab 切换与返回。
- 快速分页/刷新。
- Media 快速滑、缩放、关闭。
- 深色、大字体、Reduce Motion。
- iPad resize（若相关）。
- 慢网/失败/会话过期（若相关）。

## 差异风险审计

- View identity 是否变化。
- State 是否新增重复 truth。
- 是否新建 animation/gesture/overlay。
- 是否改变 route/path。
- 是否改变 endpoint/cookie/logging。
- 是否出现未批准依赖/Package.resolved 大改。

## 输出

`Docs/Audits/REGRESSION_<date-or-id>.md`：

- 自动化结果。
- 手工结果。
- 新回归。
- 未测范围。
- 是否可提交/合并：YES/NO。

发现回归时停止发布判断，使用根因 Bug 提示词逐个处理。


---

# 文件：`Prompts/24_CODE_REVIEW_ONLY.md`

# 只读代码审查提示词

本任务只审查，不修改工作树。可直接配合 Codex `/review` 使用。

## 审查范围

```text
基线分支/commit：
目标 diff：未提交 / 某 commit / 与 main 比较
功能目标：
相关 Specs/ADR：
```

## 优先级

按 P0/P1/P2/P3 报告，优先找真实缺陷而非格式偏好：

- P0：崩溃、数据/凭据泄露、严重状态错乱、不可用核心流程。
- P1：可复现交互 Bug、竞态、分页/取消错误、白块/遮挡、测试伪绿。
- P2：边界缺失、可维护性风险、性能/可访问性回归。
- P3：非阻塞清理。

## 必查

- 是否违反 AGENTS/Specs/ADR。
- State 单一来源、transition、取消、stale response。
- 稳定 ID、SwiftUI identity、列表复用。
- NavigationStack/SplitView/path 保持。
- Pager/MediaViewer 单实例和手势仲裁。
- Safe Area、overlay、animation 范围。
- Proto/domain 边界、字段缺失、未知 enum。
- Cookie/Keychain/log redaction。
- 测试是否确定性，是否真的覆盖改动。
- 是否存在 asyncAfter/UUID/zIndex/全局禁动画等假修复。
- 未批准依赖或无关大改。

## Finding 格式

每个 finding 必须包括：

- 优先级。
- 文件与最小行范围。
- 具体失败场景。
- 为什么当前测试未阻止。
- 建议的最小修复方向。

没有发现时明确写“未发现可操作缺陷”，并列出仍未验证的运行风险。不要为了显得有用制造意见。


---

# 文件：`Prompts/25_RECOVER_FROM_BAD_BRANCH.md`

# 从已经被 AI 改乱的分支恢复

目标：保全用户工作、找到最后绿色点、只救回可证明正确的部分。禁止在坏分支上继续全局补丁。

## 1. 冻结

- 不删除、reset 或覆盖用户文件。
- 记录 `git status --short`、当前分支、HEAD、最近提交。
- 创建安全分支/标签，例如 `rescue/snapshot-<date>`，保存未提交 diff/patch。
- 收集现有 build/test 结果。

## 2. 取证

生成 `Docs/Audits/BAD_BRANCH_FORENSICS.md`：

- 从最后已知正常 commit 到当前的提交图。
- 每个提交修改的模块。
- 首次出现 build/test/交互失败的位置（用二分或逐提交验证）。
- 重复 Pager、导航、状态源、动画、overlay、依赖。
- 不能确定正确性的改动。

## 3. 选择恢复策略

优先级：

1. 回到最后绿色 commit，在新分支重做最小任务。
2. 只 cherry-pick 经独立测试验证的语义提交。
3. 对未提交工作按文件/块手工迁移。
4. 只有没有绿色历史时才建立最小新骨架并逐项移植。

不得直接把坏分支 merge 到恢复分支再继续修。

## 4. 验证救回项

每救回一个组件：

- 先运行它的基线测试。
- 对比 Specs/ADR。
- 执行相关 UI flow。
- 形成独立 commit。

## 5. 输出

- 安全快照位置。
- 最后绿色 commit。
- 保留/丢弃/重做清单及理由。
- 恢复分支命令和测试。
- 下一步只能是一个明确小任务。


---

# 文件：`Prompts/26_UPDATE_RULES_AFTER_CORRECTION.md`

# 把一次纠正沉淀到 AGENTS/Specs/测试

当用户指出 Codex 重复犯错时使用。目标不是写一段道歉，而是让同类错误以后自动被阻止。

## 用户纠正

```text
发生了什么：
正确行为：
为什么现有规则/测试没挡住：
影响目录/Feature：
```

## 流程

1. 定位最接近的长期约束层：
   - 全仓库：根 AGENTS。
   - Core/Features/InteractionKit/Tests：嵌套 AGENTS。
   - 产品行为：Specs。
   - 架构选择：ADR。
   - 可执行保护：测试/静态脚本。
2. 只增加最小、可操作规则，避免重复和冲突。
3. 同时增加至少一个可执行保护（测试、lint、grep、CI）或说明为什么只能文档化。
4. 检查合并后的 AGENTS 指令大小与优先级。
5. 运行相关验证。

## 禁止

- 不把一次特殊例外升级成全局禁令。
- 不只写“以后注意”。
- 不复制同一句到多个 AGENTS 导致漂移。
- 不改无关实现。

## 输出

- 根因类别。
- 修改的规则/规格/测试。
- 未来触发条件。
- 验证结果。


---

# 文件：`Prompts/27_FEATURE_TASK_TEMPLATE.md`

# 单个 Feature/行为任务模板

将方括号替换后发送。一次只处理一个可验收行为。

## 任务

```text
Feature：
用户行为：
输入/入口：
预期结果：
异常结果：
明确非目标：
```

## 前置与证据

```text
相关 Specs：
相关 ADR：
Android reference 路径/symbol：
API evidence：
Fixture：
基线 commit：
```

## 允许修改

```text
目录/文件：
```

## 禁止修改

```text
共享导航/Pager/Media/Motion/网络核心/其他 Feature 等：
```

## 状态与并发验收

- 初始/成功/空/失败。
- refresh/pagination（适用时）。
- 取消。
- stale response。
- 稳定 ID 与去重。
- 返回/Tab 状态保持。

## UI/交互验收

- iPhone。
- iPad（涉及共享 UI 时）。
- 深色、Dynamic Type、Reduce Motion。
- accessibilityIdentifier。
- 不新增任意手势/动画/overlay。

## 执行流程

1. 先读规则并跑基线。
2. 先写/更新状态测试和 fixture。
3. 实现最小 data/domain/store。
4. 实现 View。
5. 加 UI smoke。
6. 跑 targeted tests，再 `make quality-fast`。
7. 报告并停止。

不得自动扩展到下一个 Feature。


---

# 文件：`Prompts/28_SMALL_CHANGE_TEMPLATE.md`

# 小改动模板

即使是小改动也要限定范围，避免 Codex 顺手重构。

```text
目标：
当前行为：
期望行为：
允许修改文件：
禁止修改文件：
必须保持的回归：
验证命令：
```

要求：

- 先检查 git diff 和相关测试基线。
- 不改公共架构、依赖、动画或手势，除非目标明确要求。
- 添加最小测试。
- 只做必要差异。
- 运行指定验证和 `git diff --check`。
- 报告实际结果后停止。


---

# 文件：`Prompts/29_GUI_REPRODUCTION_WITH_COMPUTER_USE.md`

# 使用 Codex Computer Use 在 Xcode/Simulator 复现 GUI Bug

调用 `@Computer` 或明确启用 Computer Use。范围只限 Xcode、Simulator 和当前 App，不操作无关应用。

## 目标流

```text
Simulator 设备：
启动 scenario：
起始页面：
精确操作序列：
预期：
实际：
重复次数：
```

## 操作规则

1. 先确认 App build 和 scenario，不用实时网络复现可 fixture 化的问题。
2. 将 Simulator 固定到指定设备/方向/外观/字体/Reduce Motion。
3. 清晰记录每次 tap/swipe/pinch/rotation/resize。
4. 复现前后保存截图；必要时保存录屏和控制台时间区间。
5. 不在复现过程中随机清缓存、重启或换设备。
6. 不让 Computer Use 输入/查看真实账号密码或 Cookie。
7. 复现后先停止并总结证据；代码修改按根因提示词执行。

## 输出

- 是否成功复现及频率。
- 最短确定性步骤。
- 观察到的状态/布局/手势证据。
- 证据文件位置。
- 建议调用的 Bug skill。


---

# 文件：`Prompts/30_ULTRA_PARALLEL_AUDIT.md`

# Sol Ultra 并行审计模板：子代理只读、主代理唯一写入

目标：把复杂问题拆成独立证据流，同时避免并行代理互相改坏工程。

## 审计问题

```text
主题：
范围：
基线 commit：
需要回答的决策：
输出文件：
```

## 子代理分工

仅选择真正独立的轨道，例如：

1. 状态机/并发/取消。
2. SwiftUI identity/导航/布局。
3. Gesture/Pager/Media。
4. API/Proto/Session。
5. Tests/可观测性。
6. iPad/可访问性/性能。

## 强制权限

- 所有子代理只读仓库，禁止编辑、格式化、生成工程、安装依赖或运行破坏性命令。
- 子代理输出：结论、路径/行、复现/测试证据、置信度、UNKNOWN、最小建议。
- 不同子代理不能各自创建最终 ADR/修复。
- 主代理核对重复/冲突后，才写一个统一审计文件。
- 若进入实现，另开单一写入任务，不在本 Ultra 审计中直接大改。

## 合并规则

- 相同结论合并证据。
- 冲突结论并列，写明需要何种实验裁决。
- 推断不可升级为事实。
- 结果按 P0/P1/P2 和证据强度排序。

## 完成

输出统一审计、建议的单一下一任务和禁止并行修改区域，然后停止。


---

# 文件：`Prompts/31_LIVE_DATA_EDGE_CASE_CAPTURE.md`

# Live 数据边界采样与 Fixture 固化

只在用户明确允许访问公开/自身账号数据且安全策略已建立时执行。目标是发现真实 payload 边界并生成脱敏最小 fixture，不做批量抓取。

## 安全

- 只请求实现功能所必需的少量 endpoint。
- 不抓取私密内容、他人非公开数据或批量用户资料。
- 不保存完整 Cookie/token/header。
- 响应先在本地脱敏和最小化，再进入 Git。
- 记录来源和生成脚本，不记录账号身份。

## 采样目标

```text
Endpoint：
需要验证的字段/节点：
已知缺口：
最大请求数：
```

## 流程

1. 先以 API evidence 构造请求。
2. 记录 status/content-type/大小/解析摘要。
3. 找到目标边界后停止，不做爬取。
4. 抽取最小仍可复现结构的 fixture。
5. 替换用户 ID、名称、正文、URL query、设备和认证信息。
6. 添加 mapper/regression test。
7. 用 secret scan 和人工 diff 检查。

## 输出

- 验证/否定的字段语义。
- 新 fixture 与脱敏说明。
- 更新的 API/内容节点证据。
- 测试结果。


---

# 文件：`Prompts/32_RESUME_OR_HANDOFF.md`

# 新线程、Handoff 或上下文压缩后的安全续作

本提示词用于已有工程，不用于开始新阶段。目标是从仓库事实恢复当前任务，不能依赖旧对话记忆，也不能一打开仓库就继续写代码。

## 只读恢复步骤

1. 读取根和当前目录适用的 `AGENTS.md`。
2. 读取 `Docs/Progress/TASK_STATE.md`、当前阶段提示词、相关 Specs/ADR 和最近审计。
3. 运行并记录：

```bash
pwd
git rev-parse --show-toplevel
git branch --show-current
git status --short
git log --oneline --decorate -12
git diff --stat
git diff --check
git submodule status
```

4. 检查 Android reference lock/clean 状态。
5. 读取当前未提交 diff；不得假设所有改动由前一个代理生成。
6. 从 TASK_STATE 找出最后真实执行并通过的命令；“计划运行”不算通过。
7. 运行当前任务最小基线测试；若环境/代码未变且有可验证的刚执行结果，可说明证据，但阶段出口仍需重跑门禁。

## 恢复报告

在写入前输出：

- 当前阶段/任务和状态。
- 基线 commit、当前 branch、未提交文件及其可能 owner。
- 已完成验收项与证据。
- 仍未完成项。
- 已知基线失败/阻塞/UNKNOWN。
- 本次允许修改和禁止修改范围。
- 下一步最小行为与对应测试。
- 是否适合继续 Local，还是只应在 Worktree 做只读审查。

## 继续条件

仅当当前任务、允许范围、现有改动和下一验收步骤都唯一明确时，才继续该任务。存在以下情况时停止写入并给出恢复方案：

- TASK_STATE 与 Git/测试事实矛盾。
- 不清楚未提交改动是否属于用户。
- 当前阶段已完成但没有授权进入下一阶段。
- 需要猜测 API/Proto/登录行为。
- 共享基础设施出现多个并行实现。
- 基线失败无法归类。

不得自动丢弃、stash、reset、commit、merge 或进入下一阶段。


---

# 文件：`Prompts/33_PHASE_CLOSEOUT.md`

# 阶段收尾、质量门禁与可提交状态检查

当前阶段的实现应已完成。本任务只做收尾验证、最小必要修正和报告，不新增功能，不进入下一阶段。显式使用 `$xcode-quality-gate`，最后使用 `/review` 做只读审查。

## 1. 核对范围

- 读取当前阶段提示词、Definition of Done、TASK_STATE、相关 ADR/Specs。
- 列出验收条件并逐项映射到测试/手工证据。
- 检查 Git diff 是否含无关格式化、依赖升级、生成噪声、调试开关、临时 fixture 或敏感内容。

## 2. 验证顺序

1. 运行最近失败过的定向测试。
2. 运行受影响 Feature/组件测试。
3. `make quality-fast`。
4. 当前阶段涉及 UI/导航/交互/iPad 时，运行指定 UI/interaction test plan 和手工矩阵。
5. `make quality`。
6. `git diff --check`、`git status --short`、reference/secret/instruction checks。
7. 对项目生成/Proto 生成有变更时，验证重复生成确定性。

不能用删除测试、增加 sleep、放宽 strict concurrency/lint 或跳过失败 target 获得绿色结果。

## 3. 只读审查

运行 `/review`，优先检查：

- 正确性、状态转换、取消与 stale response。
- SwiftUI identity、导航/滚动恢复。
- safe area、overlay、手势、动效和 Reduce Motion。
- iPhone/iPad 路由一致性。
- Proto/domain 边界、Session/日志隐私。
- 测试是否真的覆盖新行为和失败分支。

只修当前阶段范围内的 P0/P1 finding；架构级外溢先记录，不趁收尾扩大重构。

## 4. 更新记录

仅按真实结果更新：

- `Docs/Progress/TASK_STATE.md`
- 相关 ADR/审计/基线文档
- 必要 README

不得把未运行项写成 PASS。无法执行的手工/设备矩阵标 `NOT_TESTED` 并说明影响。

## 5. 最终报告

- 阶段目标与完成状态。
- 修改文件/模块。
- 验收条件对应的证据。
- 实际命令、退出状态、xcresult/日志路径。
- `/review` finding 及处理。
- 新增/变更依赖、手势、动效、overlay、路由。
- 剩余风险、UNKNOWN、未验证项。
- 当前 diff 是否达到“可由用户提交”的绿色状态。

未经明确授权不执行 commit/push。完成后停止。


---

# 文件：`Prompts/34_DEPENDENCY_CHANGE_REVIEW.md`

# 新增或更换生产依赖的只读评审

除 `AGENTS.md` 已预批准项外，任何网络、图片、数据库、状态管理、日志、UI、测试辅助库进入生产 target 前，先执行本提示词。本任务默认只写 ADR/评审，不安装依赖、不改 `Package.resolved`。

## 输入

```text
要解决的问题：
候选依赖：
当前系统实现的缺口：
受影响 target/功能：
预计长期维护周期：
```

## 必须比较

- 不引入依赖的系统 API 方案。
- 至少一个候选库（若确有候选）。
- 功能适配度与不需要的附带能力。
- iOS 18+/Swift 6/strict concurrency 兼容。
- actor/Sendable 与取消语义。
- 二进制/编译/启动/内存影响。
- 维护活跃度、版本策略、退出/替换成本。
- 许可证及与项目分发方式的兼容性。
- 测试性、fixture 支持、隐私/遥测默认值。
- 是否与已有依赖职责重复。

当前版本、兼容性和许可证必须查官方文档/仓库并记录日期，不能凭模型记忆。

## 输出

创建 Proposed ADR，给出：问题、约束、候选、证据、决策、拒绝理由、集成边界、升级/锁定策略、回滚条件、验证计划。

## 退出规则

- 没有明显净收益：拒绝依赖。
- 许可证/维护/并发兼容不清楚：保持 Proposed 并停止。
- 获得批准后，另开一个范围明确的集成任务；不得在本审查中顺手改业务代码。


---

# 文件：`Prompts/35_ANDROID_REFERENCE_UPGRADE.md`

# Android 参考仓库版本升级与证据重审

仅在用户明确要求更新 TiebaLite Android 参考 commit 时执行。不得在普通功能任务中自动 `git submodule update --remote`。

## 前置

- 工作树可解释，当前阶段有绿色基线。
- 记录旧 lock SHA、目标 branch/commit 和升级原因。
- 创建独立 branch/worktree；主功能实现暂停依赖此升级的写入。

## 流程

1. 在不改源码的前提下更新 submodule 到明确目标 commit。
2. 生成旧→新 diff 摘要，重点：API、请求常量、Proto、repository、登录/session、内容节点、分页和 UI 行为。
3. 使用 `$tiebalite-reference-audit` 和 `$tiebalite-api-evidence` 做只读影响分析。
4. 更新 API/Proto/Feature/Content/Unknown/License 规格，逐项标记：UNCHANGED、CHANGED、REMOVED、NEW、UNKNOWN。
5. 只在证据审计完成后更新 `References/TiebaLite-Android.lock`。
6. 运行现有 fixture decode/mapper/request tests；旧 fixture 失败时先判断协议真实变化，不直接重录所有 fixture。

## 禁止

- 不把 submodule dirty 改动带入。
- 不机械同步 Android UI。
- 不在同一任务同时改 iOS 生产实现。
- 不删除旧证据或 fixture 来掩盖不兼容。

## 输出

- `Docs/Audits/ANDROID_REFERENCE_UPGRADE_<old>_<new>.md`
- 更新后的 lock/Specs/UNKNOWN。
- iOS 受影响任务列表及优先级。

审计完成后停止，由后续独立任务实施必要变更。


---

# 文件：`Prompts/36_LIVE_API_BREAKAGE_TRIAGE.md`

# Tieba Live API/登录突然失效的隔离排障

用于“之前能用、现在 live 请求失败/字段变了/登录失效”的情况。目标是把外部协议问题与 UI/状态回归隔离；不得因为 live 失败重写已验证的界面。

## 输入

```text
首次观察日期与 commit：
受影响能力：推荐/FRS/PB/关注吧/登录/图片/其他
HTTP/解析/服务端错误摘要（脱敏）：
Fixture 路径是否仍通过：
最后已知正常的参考/响应证据：
```

## 隔离顺序

1. 运行 fixture request/mapper/store/UI tests。Fixture 失败表示本地回归，走普通根因修复；fixture 全绿才继续外部协议排障。
2. 检查 session/clock/network 环境，不打印敏感值。
3. 用最小 Debug live probe 采集：endpoint 名、method、status、content type、响应字节数、decode 阶段、server error code、耗时；正文只做内存内最小检查并脱敏。
4. 对照当前 `API_EVIDENCE`、Proto schema、Android reference 最新受控 commit；不得根据第三方片段盲改签名/headers。
5. 分类：网络/TLS、认证过期、请求参数、HTTP/server、Proto decode、字段语义、反滥用/频控、服务能力下线、UNKNOWN。
6. 固化最小脱敏失败 fixture（可合法保存时）和一个先失败的 request/decode/mapper test。

## 修复边界

- 只修改 data/protocol/session 层及相应测试/证据。
- UI/导航/Pager/MediaViewer/动效状态机默认禁止修改。
- 新 header、设备参数、签名或 token 流程必须有证据和安全审查。
- 不绕过 TLS、验证码、账号保护、频控或服务限制。
- 无证据时返回可诊断 unavailable/unsupported，并保持 fixture 模式可用。

## 验证

- 新旧/畸形 fixture 测试。
- request construction 与 redaction。
- Store 对新错误的状态不变量。
- 最小 live smoke（非自动门禁）。
- 完整 `make quality`，确认 UI fixture 链路无回归。

## 输出

根因/证据、协议变化、最小修复、失败→通过测试、live 验证限制、仍需用户/上游证据。完成后停止。


---

# 文件：`Prompts/99_ONE_TIME_MASTER_PROMPT.md`

# 一次性主提示词（只用于接管空仓库，不连续实现全 App）

你是本地 macOS 26 / Xcode 26 环境中的高级 iOS 工程负责人。当前仓库用于构建原生 iOS/iPadOS Tieba Lite 只读客户端。

你的第一责任不是快速生成大量代码，而是建立可验证、可回退、可持续审查的工程。严格执行以下规则：

1. 先读取仓库根 `AGENTS.md`、所有适用于当前目录的嵌套 AGENTS、`Specs/`、ADR 和 `Docs/Progress/TASK_STATE.md`。
2. 识别 `.agents/skills`，按任务显式调用合适 skill。
3. 检查 Git 根、状态和 Android 参考 submodule；参考仓库只读。
4. 只有协调主代理可写当前工作树；Ultra 子代理只读分析。
5. 不发明 API、Protobuf 字段、登录参数或原版行为。证据不足写 UNKNOWN，先用 fixture。
6. 不一次性实现完整 App。只执行我当前指定的一个阶段。
7. 每阶段先跑基线、先写规格/失败测试，再最小实现、定向测试、质量门禁和报告。
8. 不用 asyncAfter、`.id(UUID())`、透明遮罩、无限 zIndex、全局禁动画或重建根导航掩盖交互问题。
9. 导航使用系统 NavigationStack/NavigationSplitView；业务 Feature 不自己实现 DragGesture、Pager、MediaViewer 或任意动画参数。
10. Swift 6 strict concurrency；UI 状态主 actor，网络/缓存 actor，取消与 stale response 明确。
11. 自动化测试使用固定 fixture，不依赖实时贴吧网络；真实接口仅 Debug smoke，日志脱敏。
12. 当前阶段完成后停止，不自动进入下一阶段。

现在只执行 `Prompts/00_BOOTSTRAP_ENVIRONMENT.md`。先给出将读取的文件、将运行的命令和允许修改范围，然后立即执行。完成后按 AGENTS 的报告格式汇报并停止。
