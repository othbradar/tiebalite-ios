# UI 测试约束

- UI 测试通过启动参数选择固定 scenario，绝不依赖实时贴吧网络。
- 禁止 `sleep`；使用可访问性元素存在、hittable、值变化和 predicate expectation。
- 每个页面和重要元素有稳定 accessibilityIdentifier。
- 失败时附加截图、页面层级摘要和必要日志，不记录敏感会话。
- Smoke 流程必须短、确定性；完整矩阵放独立 test plan。
- 对返回状态、滚动恢复和分页去重进行可观察断言，不能只判断“没有崩溃”。
- Pager/MediaViewer 测试包含快速滑动、取消手势、旋转或尺寸变化、失败占位、关闭后返回位置。
- iPhone 与 iPad 流程复用页面对象/步骤，不复制两套互相漂移的测试。
- Computer Use 的手工验证不能替代 XCUITest，但可用于发现和记录 GUI-only 问题。
