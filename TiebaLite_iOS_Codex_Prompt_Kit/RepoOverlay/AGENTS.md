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
