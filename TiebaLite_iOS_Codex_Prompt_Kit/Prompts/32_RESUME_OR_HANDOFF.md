# 新线程、Handoff 或上下文压缩后的安全续作

本提示词用于已有工程，不用于开始新阶段。目标是从仓库事实恢复当前任务，不能依赖旧对话记忆，也不能一打开仓库就继续写代码。

## 只读恢复步骤

1. 读取根和当前目录适用的 `AGENTS.md`。
2. 读取 `Docs/Progress/TASK_STATE.md`、当前阶段提示词、相关 Specs/ADR 和最近审计。
3. 运行并记录：

```bash
pwd
git rev-parse --show-toplevel
git branch --show-current
git status --short
git log --oneline --decorate -12
git diff --stat
git diff --check
git submodule status
```

4. 检查 Android reference lock/clean 状态。
5. 读取当前未提交 diff；不得假设所有改动由前一个代理生成。
6. 从 TASK_STATE 找出最后真实执行并通过的命令；“计划运行”不算通过。
7. 运行当前任务最小基线测试；若环境/代码未变且有可验证的刚执行结果，可说明证据，但阶段出口仍需重跑门禁。

## 恢复报告

在写入前输出：

- 当前阶段/任务和状态。
- 基线 commit、当前 branch、未提交文件及其可能 owner。
- 已完成验收项与证据。
- 仍未完成项。
- 已知基线失败/阻塞/UNKNOWN。
- 本次允许修改和禁止修改范围。
- 下一步最小行为与对应测试。
- 是否适合继续 Local，还是只应在 Worktree 做只读审查。

## 继续条件

仅当当前任务、允许范围、现有改动和下一验收步骤都唯一明确时，才继续该任务。存在以下情况时停止写入并给出恢复方案：

- TASK_STATE 与 Git/测试事实矛盾。
- 不清楚未提交改动是否属于用户。
- 当前阶段已完成但没有授权进入下一阶段。
- 需要猜测 API/Proto/登录行为。
- 共享基础设施出现多个并行实现。
- 基线失败无法归类。

不得自动丢弃、stash、reset、commit、merge 或进入下一阶段。
