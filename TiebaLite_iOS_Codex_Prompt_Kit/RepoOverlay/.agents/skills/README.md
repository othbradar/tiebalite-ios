# Repository skills

显式调用格式：在 Codex 提示中写 `$skill-name`。审计类 skill 默认关闭隐式触发，避免在实现任务中突然切换为只读流程。

- `$tiebalite-reference-audit`：只读追踪 Android 功能/API/Proto/渲染证据。
- `$tiebalite-api-evidence`：实现或排查一个 endpoint/Proto 映射前建立证据、fixture 与测试。
- `$ios-architecture-review`：只读架构/共享 diff 审查。
- `$ios-feature-slice`：实现一个 fixture-first 的单一垂直行为。
- `$ios-root-cause-debug`：复现一个 Bug、先写失败回归、做最小根因修复。
- `$ios-interaction-qa`：iPhone/iPad 导航、Pager、Media、safe area、resize 与手势矩阵。
- `$ios-motion-audit`：动效清单、Motion token、Reduce Motion 与双重转场检查。
- `$xcode-quality-gate`：运行 doctor/fast/full 构建测试门禁并保留真实结果。

不要把多个写入型 skill 同时用于同一工作树。Ultra 子代理仍然只读；唯一协调主代理执行改动。
