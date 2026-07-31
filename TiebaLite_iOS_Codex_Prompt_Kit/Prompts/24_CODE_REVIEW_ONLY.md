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
