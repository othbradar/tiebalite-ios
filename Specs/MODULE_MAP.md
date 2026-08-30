# 模块与依赖地图

状态：`IMPLEMENTED_PHASE_16A_SEARCH_RUNTIME_EVIDENCE_PARTIAL`

本文件把根目录结构解释为逻辑模块和 owner；它不表示阶段 02 已创建 Swift
target。工程生成决策见 `Docs/ADRs/ADR-0001-project-generation.md`。

## 编译 target 与逻辑模块

阶段 15 当前编译 target：

| 编译 target | 内容 | 可依赖 |
|---|---|---|
| `TiebaLite` | App、Core、DesignSystem、ThreadReader Renderer、MediaViewer、InteractionKit；仅 UITesting 配置加入 `TestSupport/LaunchScenarios/**` | Apple SDK；已批准且实际引入的 production package |
| `GeneratedProtobuf` | 锁定只读 endpoint 的 156-file closure 所生成的 tracked Swift；静态库 | SwiftProtobuf 1.38.1 only |
| `TiebaLiteTests` | State/mapper/repository/integration tests；单独编译所需 TestSupport 源 | `TiebaLite`、test-only helper |
| `TiebaLiteUITests` | XCUITest flows，只向 App 传 scenario ID | App 的 UITesting build；不可链接 production secret/live fixture |

目录通常是逻辑模块，不自动变成 target。`GeneratedProtobuf` 已因生成代码
编译隔离、可重复生成和 UI import gate 成为唯一新增内部 target；不能为每个
endpoint 再拆重复 generated target。

初期同一 App target 不能由编译器完全阻止越层 import/类型访问，这是已接受
风险；以访问级别、协议、静态 forbidden scan、diff review 和测试弥补。

## 逻辑模块

| 路径 | owner/责任 | 公开边界 | 禁止 |
|---|---|---|---|
| `App/` | composition root、scene、AppNavigationStore、root Store 生命周期 | Route/Presentation command、dependency factory | endpoint、Proto mapper、业务列表 reducer |
| `Sources/Core/Models/` | Sendable domain ID/value/error、Repository/use-case contracts | 领域值与面向用户任务的协议 | HTTP/Proto/UI/concrete import |
| `Sources/Core/Networking/` | HTTPClient、HTTPRequest/Response、redirect/TLS/error | Sendable transport 协议 | Feature 语义、隐式 auth |
| `Sources/Core/TiebaAPI/` | typed Endpoint、wire adapter、DTO/Proto mapper、Repository concrete | Feature-facing Repository 协议实现 | View、全局账户 |
| `Sources/Core/Session/` | SessionController、auth context、capability/lease、ProtectedDataCleaner 协议 | 脱敏 snapshot、SessionClient | raw secret 暴露给 Feature、Images concrete |
| `Sources/Core/Persistence/` | Keychain vault、journal/ledger、公开/受保护 namespace | 小型 storage 协议 | UI、业务导航 |
| `Sources/Core/Images/` | 唯一 ImageRepository、请求合并/cache policy | ImageRequest/Result/lease | 第二网络栈、raw URL 日志 |
| `Sources/Core/Logging/` | DiagnosticsClient、Signposter、安全事件 | 白名单 event API | raw Error/request/payload |
| `Sources/DesignSystem/` | 颜色、排版、Motion、Loading/Empty/Error 组件 | 语义 token/component | Feature、网络、route |
| `Sources/InteractionKit/` | 唯一 PagerContainer、媒体交互桥接及薄 VirtualizedList 承载 | PageID/selection/capability；稳定 item ID、row builder、prefetch/anchor | Feature 数据、第二 Pager、帖子或吧首页业务语义 |
| `Sources/Features/Recommendations/` | 推荐 Store/View | route 输入、领域 state/action | 其他 Feature 内部类型、Core concrete |
| `Sources/Features/FollowedForums/` | 关注吧 Store/View | session capability、领域 state/action | credential、HTTP |
| `Sources/Features/Forum/` | 吧信息/tab/主题 timeline | forumName route、领域 state/action | PB internals |
| `Sources/Features/ThreadReader/` | Thread/Subposts/Content renderer 与预计算 RowModel | thread/post route、ContentNode、稳定 ThreadReaderRowID | MediaViewer 内部状态、第二列表容器、Proto/UI 映射 |
| `Sources/Features/MediaViewer/` | 唯一 Viewer presentation/load state/page composition | MediaPresentation | 精确 zoom owner、自制 Pager、父列表复制 |
| `Sources/Features/Search/` | 显式 submit 搜吧/搜帖 Store、预计算 RowModel 与 View | `SearchRepository`、稳定 forum/thread 领域结果、Search route callback | HTTP/JSON DTO/Session，用户搜索/历史，第二列表承载 |
| `Generated/Protobuf/` | 机器生成 wire Message | 仅供 Core/TiebaAPI mapper | UI/Feature/domain 行为 |
| `Resources/` | asset/localization/config resources | typed resource access | secret/live response |
| `TestSupport/` | fixture loader、fake、clock；LaunchScenarios 子树 | Unit target；LaunchScenarios 另编入 App 的 UITesting 配置 | 普通 App Debug/Release 可达路径 |
| `Tests/` | Swift Testing/XCTest | 测试 | production source |
| `UITests/` | XCUITest | accessibility ID、scenario ID | live endpoint/credential |

## 允许依赖方向

下图使用逻辑模块名，省略实际路径的 `Sources/` 前缀。

```text
App ───────────────→ Features
 │                    │
 │                    ├──→ Core protocols/models
 │                    ├──→ DesignSystem
 │                    └──→ InteractionKit
 └──→ Core concrete composition

Core/TiebaAPI ──────→ Core/Networking
        │            Core/Session capability
        ├───────────→ Core/Models
        └───────────→ GeneratedProtobuf

Core/Session ───────→ Core/Persistence
        └───────────→ Core/Logging

Core/Images ────────→ Core/Networking + Core/Logging
        └───────────→ Core/Session capability/lease-validator protocol
InteractionKit ─────→ DesignSystem（仅语义视觉/动效）
GeneratedProtobuf ──→ SwiftProtobuf
```

`ProtectedDataCleaner` 协议由 Core/Session 拥有，Session 只调用抽象。App
composition root 注入由 Persistence/Images 等 concrete 组成的 aggregate；
Core/Session 不依赖 Core/Images concrete，因此 lease 校验和清理不会形成
循环依赖。

由 Core/TiebaAPI concrete 实现的 Repository/use-case protocol 固定由
Core/Models 的 inward contract boundary 拥有；Feature 只依赖该 contract，
concrete 只能在 Core/TiebaAPI。协议不能泄漏 Endpoint、URLRequest、DTO 或
generated Message。若以后确需 Feature-local façade，只能由 App adapter
桥接；Core concrete 不 import Feature、也不直接 conform Feature-owned
protocol。

阶段 08 的具体边界：`ThreadContentProtoMapper` 是第二个精确
allowlisted generated adapter；它只向内输出 `ThreadContentDocument`。
`ThreadContentRenderer` 只依赖该 domain 与可注入 `ImageLoading`，图片/链接
点击只输出 `ThreadMediaIntent` / `ExternalLinkIntent`，不实现
ThreadScreen 或 Repository。阶段 09 由 App composition closure 将
`ThreadMediaIntent` 交给唯一根 presentation；Renderer 本身仍不 import
MediaViewer internals。Debug Renderer Lab 只在 Debug/UITesting 编译，Release
排除。

阶段 09 的具体边界：`Sources/InteractionKit/Pager` 是唯一生产
`PagerContainer`，`Sources/InteractionKit/MediaViewer` 是唯一 zoom/gesture
ownership bridge；`Sources/Features/MediaViewer` 只持稳定 presentation、固定
item load phase 与 chrome。`AppSceneRoot` 每 scene 最多持有一个进程内
`fullScreenCover`。UITesting 注入固定 loader；Release 注入
`DisabledImageLoader`，因此本阶段没有建立 live 图片、cache/downsample/
candidate/lease 或第二网络栈。

阶段 15 的具体边界：`Sources/InteractionKit/VirtualList` 是无业务语义的单
section UITableView/diffable/UIHostingConfiguration adapter；它不 import
ThreadReader/Forum domain。`ThreadReaderListPresentation` 在 Feature 内把领域
posts 预计算为稳定 RowModel，生产 View 只有这一个列表容器。阶段 14 生产代码
尚未使用该 adapter；后续 14P 只能复用其当前最薄接口，不能反向加入 FRS 语义。

阶段 16A 的具体边界：`Sources/Core/Models/Search.swift` 拥有
`SearchRepository` 和稳定搜索领域值；`Sources/Core/TiebaAPI/SearchWebProtocol.swift`
只负责 Hybrid JSON descriptor/DTO/mapper，不向 Feature 泄漏 wire。
`Sources/Features/Search` 只持 Store/presentation/View，复用未修改的
`VirtualizedList` 和 `ContentSummaryCard`。SearchStore 由 scene 级
`AppFeatureStoreRegistry` 持有，不建全局 singleton，不读 Session。

登录验证/续期同样不允许 Session 直接构造 transport。Core/Session 拥有无
HTTP/DTO 的 `SessionValidationClient`/`CredentialRefreshClient` 协议，
Core/TiebaAPI concrete 实现并依赖 Core/Networking，App composition root
注入给 SessionController；因此没有 Session → Networking 或
Session → TiebaAPI concrete 的边。

## 明确禁止的边

- Feature → 另一个 Feature 内部类型。
- View → URLSession、Proto、Keychain、database、CookieStorage。
- GeneratedProtobuf → UI/Feature/DesignSystem/InteractionKit。
- Core Models → concrete networking/persistence/UI。
- DesignSystem/InteractionKit → Feature。
- Repository → AppNavigationStore。
- Session → 业务 route；认证 continuation 由 AppNavigationStore 持有。
- static/global mutable singleton → 任意 Feature。
- TestSupport → Release product。

阶段 03 的 source membership 必须让 `TestSupport/LaunchScenarios/**` 只在
App 的 UITesting 配置参与编译：普通 Debug/Release 以配置级 source exclusion
排除，并以 `#if UITESTING`（共享 unit helper 可用独立 test flag）作第二层
防御。同一所需源可由 `TiebaLiteTests` 自己编译；`TiebaLiteUITests` 只传
scenario ID，不链接 TestSupport。

## 单一 owner / 单一生产实现

| 共享能力 | 唯一 owner | 生产实例范围 |
|---|---|---|
| App route/path/auth continuation | `App/AppNavigationStore` | 每 scene 一个 |
| Pager | `InteractionKit/PagerContainer` | 组件实现一个 |
| MediaViewer | `Features/MediaViewer` | AppShell 全局 presentation 一个 |
| Motion token | `DesignSystem/Motion` | 一套 |
| Loading/Empty/Error family | `DesignSystem` | 一族语义组件 |
| HTTP transport | `Core/Networking` | composition root 创建 |
| Session canonical state | `Core/Session/SessionController` | app scoped actor |
| Image/cache pipeline | `Core/Images/ImageRepository` | app scoped actor/namespace |
| diagnostics | `Core/Logging` | 一个 backend，可测试替换 |

## 并发与数据跨界

- UI Store/Main navigation：MainActor。
- Session、HTTP mutable state、cache/image、journal/vault：各自 actor。
- transport response 在 repository 隔离内 decode/map；只把 Sendable domain
  交给 Store。
- generated Message 不跨 repository/task 边界；SwiftProtobuf 1.38.1 自动
  生成的 10 个 `@unchecked Sendable` 只按 ADR-0011 的 exact hash/allowlist
  接受，message 仍不得在任务间共享可变实例。UIImage/CGImage 的 Sendable
  边界仍须独立证明。
- 受保护写必须携带 `ProtectedDataLease(sessionID,generation)`。
- 不使用 `@unchecked Sendable` 作为默认逃生口。

## 提升为独立 target 的门禁

满足至少一项并记录 build/test 影响，才可拆 target：

1. generated code 需要阻止 UI import；
2. 编译隔离能阻止已发生的依赖违规；
3. 多个产品明确复用；
4. 构建时间测量证明收益；
5. 系统/许可证要求独立封装。

拆分后不能制造循环依赖或为公开 API 暴露 concrete DTO。失败时回滚 target
声明，保留逻辑目录和协议。

## 结构验证

阶段 03 起静态检查至少断言：

- Feature/View 中无 URLSession/Keychain/generated import；
- Generated 中无 SwiftUI/UIKit/Feature import；
- `PagerContainer`、`MediaViewer`、Motion 和通用状态组件生产定义各一处；
- Release sources 不含 TestSupport；
- project.yml 的 sources/resources 与本地图一致。
