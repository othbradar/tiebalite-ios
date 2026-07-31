# 架构契约

阶段 02 必须通过 ADR 固化具体实现，本文件定义不可违反的边界。

## UI 与状态

- SwiftUI View 是状态的投影，不拥有重复业务真相。
- 每个 Feature 有单一 `@MainActor` Store/ViewModel。
- 用户事件通过明确 Action/Intent 进入；异步结果通过明确 Event/Result 返回。
- Navigation route 使用稳定、可测试、Hashable 的领域 ID。
- 列表滚动恢复使用稳定 item ID/scroll position，不保存像素截图式 offset 作为唯一真相。

## Domain 与 Data

- 领域模型不依赖 HTTP、Protobuf 或 UI。
- Repository 接口表达用户任务，不暴露 endpoint 细节。
- Transport DTO/Proto → mapper → domain model。
- Mapper 对缺失字段、未知 enum、超长内容、无效 URL 和删除内容有显式策略。

## 异步与取消

- 每个加载动作定义：是否可并发、取消时机、重试策略、旧响应判定、缓存策略。
- 首次、刷新和分页是不同 action，不共享一个模糊 `isLoading`。
- Store deinit/页面关闭不是唯一取消机制；Tab 状态保持时应由 action 生命周期决定。

## Session

- SessionState：signedOut、authenticating、signedIn、expired、failed。
- 敏感值由 Session subsystem 管理；Feature 只看到身份摘要和能力。
- 401/服务端登录失效统一映射，不在各页面重复弹窗。

## 工程生成

- `project.yml` 是 Xcode 工程声明真相。
- `.xcodeproj` 只能由 XcodeGen 生成；若提交生成文件，CI/脚本检查重新生成无差异。
- 所有 scheme、test plan、资源和编译设置显式声明。

## 依赖注入

- App 组合根创建 concrete dependencies。
- Feature 初始化时接收小型协议，不读取全局 singleton。
- 测试可以替换 clock、ID generator、HTTP、session、cache 和 image loader。

## 观测性

- 关键请求记录匿名 request ID、endpoint、耗时、结果类别。
- 日志不能含 Cookie/token/正文隐私。
- 状态转换可在 Debug 构建中追踪，但生产默认降低详细度。
