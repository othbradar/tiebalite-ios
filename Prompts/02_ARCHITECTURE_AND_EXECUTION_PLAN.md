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
