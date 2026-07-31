# 阶段收尾、质量门禁与可提交状态检查

当前阶段的实现应已完成。本任务只做收尾验证、最小必要修正和报告，不新增功能，不进入下一阶段。显式使用 `$xcode-quality-gate`，最后使用 `/review` 做只读审查。

## 1. 核对范围

- 读取当前阶段提示词、Definition of Done、TASK_STATE、相关 ADR/Specs。
- 列出验收条件并逐项映射到测试/手工证据。
- 检查 Git diff 是否含无关格式化、依赖升级、生成噪声、调试开关、临时 fixture 或敏感内容。

## 2. 验证顺序

1. 运行最近失败过的定向测试。
2. 运行受影响 Feature/组件测试。
3. `make quality-fast`。
4. 当前阶段涉及 UI/导航/交互/iPad 时，运行指定 UI/interaction test plan 和手工矩阵。
5. `make quality`。
6. `git diff --check`、`git status --short`、reference/secret/instruction checks。
7. 对项目生成/Proto 生成有变更时，验证重复生成确定性。

不能用删除测试、增加 sleep、放宽 strict concurrency/lint 或跳过失败 target 获得绿色结果。

## 3. 只读审查

运行 `/review`，优先检查：

- 正确性、状态转换、取消与 stale response。
- SwiftUI identity、导航/滚动恢复。
- safe area、overlay、手势、动效和 Reduce Motion。
- iPhone/iPad 路由一致性。
- Proto/domain 边界、Session/日志隐私。
- 测试是否真的覆盖新行为和失败分支。

只修当前阶段范围内的 P0/P1 finding；架构级外溢先记录，不趁收尾扩大重构。

## 4. 更新记录

仅按真实结果更新：

- `Docs/Progress/TASK_STATE.md`
- 相关 ADR/审计/基线文档
- 必要 README

不得把未运行项写成 PASS。无法执行的手工/设备矩阵标 `NOT_TESTED` 并说明影响。

## 5. 最终报告

- 阶段目标与完成状态。
- 修改文件/模块。
- 验收条件对应的证据。
- 实际命令、退出状态、xcresult/日志路径。
- `/review` finding 及处理。
- 新增/变更依赖、手势、动效、overlay、路由。
- 剩余风险、UNKNOWN、未验证项。
- 当前 diff 是否达到“可由用户提交”的绿色状态。

未经明确授权不执行 commit/push。完成后停止。
