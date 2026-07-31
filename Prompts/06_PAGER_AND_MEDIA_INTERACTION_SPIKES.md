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
