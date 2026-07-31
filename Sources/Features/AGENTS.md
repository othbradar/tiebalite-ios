# Features 目录约束

每个 Feature 使用相同结构：

```text
FeatureName/
  Domain/
  Data/
  Presentation/
  Tests or corresponding Tests/FeatureName/
```

- 一个 Feature 只有一个明确状态源；View 不维护与 Store 重复的业务 Bool。
- Store/ViewModel 为 `@MainActor`，Action/Intent 和状态转换可测试。
- View 不直接调用 URLSession、SwiftProtobuf、Keychain、UserDefaults 或数据库。
- 列表必须使用稳定业务 ID，并实现首次、刷新、分页、空、失败和取消状态。
- `onAppear` 只能派发幂等 action，不能无防护重复请求。
- 页面 push/pop 使用 AppRouter/route，不自行修改全局导航层。
- 业务代码不得创建 `DragGesture`、任意动画时长或全屏 overlay。
- 所有交互元素提供稳定 `accessibilityIdentifier`；ID 命名使用 `feature.element.qualifier`。
- 每个新增状态都要有测试；每个新增异步路径都要测试取消和过期响应。
- Feature 完成必须证明返回后状态与滚动位置保持，而不只是“能打开页面”。
