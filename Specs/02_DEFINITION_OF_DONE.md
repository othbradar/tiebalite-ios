# Definition of Done

“写完代码”不等于完成。一个阶段只有同时满足以下条件才可退出。

## 规格

- 验收条件、状态机、非目标和边界已写入 Specs/ADR。
- 所有未知行为有证据缺口记录，未被模型猜测替代。
- 若接真实 API，每个 endpoint 有来源追踪和脱敏 fixture。

## 实现

- 改动只在授权范围内。
- 无 TODO 占位、空 catch、强制解包、`fatalError`、异步延迟假修复。
- 无重复 Pager/MediaViewer/Loading/Error 组件。
- 无新增未批准生产依赖。
- View 身份、任务取消和旧响应处理明确。

## 测试

- 新行为有状态/映射测试。
- 关键用户流有 fixture 驱动 UI smoke test。
- Bug 有先失败后通过的回归测试，或有明确不能自动化的理由与确定性手工脚本。
- 执行并记录阶段要求的真实命令。

## 交互

- iPhone 目标设备上完整走通。
- 涉及布局/导航/手势时，iPad 目标设备也走通。
- 深色、大字体、Reduce Motion 不出现裁切、遮挡或行为丢失。
- 返回后状态、滚动位置和已加载内容符合契约。

## 工程

- `git diff --check` 通过。
- `make quality` 通过，或所有不能运行项有明确环境原因。
- `/review` 的 P0/P1 问题已修复或形成批准的风险接受记录。
- `Docs/Progress/TASK_STATE.md` 与实际一致。
- 当前阶段形成可回退的绿色 Git commit。
