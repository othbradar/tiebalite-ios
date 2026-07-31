# 阶段提示词索引与执行顺序

这些文件是 **Codex 桌面版中的单次任务指令**。每次只让 Codex 执行一个文件；阶段完成、质量门禁通过、`/review` 处理完并形成绿色 Git commit 后，才进入下一阶段。

## 每次发送给 Codex 的固定格式

```text
请执行 Prompts/<文件名>。
严格读取并遵守仓库根目录及目标目录适用的 AGENTS.md，并按需显式调用该提示词指定的 $skill。
当前只完成这个阶段/任务；不得开始下一个阶段，不得扩大范围。
先检查 Git 与测试基线，再给出本阶段计划，然后立即执行。
完成时报告真实运行过的命令、结果、未验证项和剩余风险。
```

## 主线顺序

| 顺序 | 提示词 | 建议运行位置 | 建议模式 | 退出门禁 |
|---:|---|---|---|---|
| 00 | `00_BOOTSTRAP_ENVIRONMENT.md` | Local | Sol/Ultra | `make doctor`，只改环境文档 |
| 01 | `01_ANDROID_REFERENCE_AUDIT.md` | Worktree 或 Local | Ultra，只读子代理 | 审计规格完整，`/review` |
| 01B | `01B_ANDROID_RUNTIME_BEHAVIOR_CAPTURE.md` | 可选独立 Worktree | Ultra + Computer Use | 原版运行证据或明确 NOT_AVAILABLE |
| 02 | `02_ARCHITECTURE_AND_EXECUTION_PLAN.md` | Local | Ultra，只读子代理 | ADR 与计划无冲突 |
| 02B | `02B_SCREEN_AND_INTERACTION_BLUEPRINTS.md` | Local | Ultra/Max | P0 每屏/每流契约获批准 |
| 03 | `03_PROJECT_SCAFFOLD.md` | Local | Max；Ultra 仅一名写入协调者 | App/build/unit/UI smoke 绿色 |
| 04 | `04_DETERMINISTIC_TEST_HARNESS.md` | Local | Max | 可模拟成功/失败/慢网/取消/乱序 |
| 05 | `05_DESIGN_SYSTEM_AND_APP_SHELL.md` | Local | Max | iPhone/iPad shell 与状态组件绿色 |
| 06 | `06_PAGER_AND_MEDIA_INTERACTION_SPIKES.md` | 独立 Worktree 推荐 | Max + Computer Use | Spike 报告明确 ACCEPTED/REJECTED |
| 07 | `07_NETWORKING_PROTOBUF_FOUNDATION.md` | Local | Max | Proto/HTTP fixture 路径绿色 |
| 08 | `08_THREAD_CONTENT_DOMAIN_AND_RENDERER.md` | Local | Max | 内容节点矩阵与 renderer 绿色 |
| 09 | `09_MEDIA_VIEWER_PRODUCTION.md` | Local | Max | 唯一生产 MediaViewer 绿色 |
| 10 | `10_RECOMMENDATIONS_VERTICAL_SLICE_FIXTURE.md` | Local | Max | 首条完整 fixture 链路绿色 |
| 10B | `10B_VISUAL_AND_INTERACTION_BASELINE.md` | Local | Max + Computer Use | 关键界面基线与交互证据冻结 |
| 11 | `11_LIVE_API_RECOMMENDATIONS_AND_THREAD.md` | Local | Max | 仅替换 Repository，fixture 无回归 |
| 12 | `12_SESSION_AND_LOGIN.md` | Local | Max | Fake 全矩阵；真实凭据仅用户手动 |
| 13 | `13_FOLLOWED_FORUMS.md` | Local | Max | 未登录/已登录/过期全部绿色 |
| 14 | `14_FORUM_HOME_AND_THREAD_LIST.md` | Local | Max | 吧页筛选/分页/返回状态绿色 |
| 15 | `15_FULL_THREAD_READER_AND_SUBPOSTS.md` | Local | Max | 完整楼层/楼中楼只读链路绿色 |
| 16A–C | P1 提示词 | 独立串行任务 | Max | 每个子阶段单独门禁/commit |
| 17 | `17_IPADOS_ADAPTATION_HARDENING.md` | Local | Max + Computer Use | 旋转/resize/分屏矩阵绿色 |
| 18 | `18_ACCESSIBILITY_PERFORMANCE_RESILIENCE.md` | Worktree 审计 + Local 修复 | Ultra 只读审计，Max 写入 | 审计和全门禁绿色 |
| 19 | `19_FINAL_PARITY_AND_RELEASE_PREFLIGHT.md` | Worktree 审计 + Local 修复 | Ultra 只读审计 | 最终矩阵与风险清单 |

“Max”表示在 Codex 中选择适合单任务深度执行的最高单代理推理档；坚持全程 Ultra 时，仍必须遵守主代理唯一写入规则。

## 日常任务和故障提示词

- 一般根因修复：`20_ROOT_CAUSE_BUG_FIX.md`
- 白块、遮挡、错页、手势冲突：`21_INTERACTION_GESTURE_LAYOUT_BUG.md`
- 动画不统一：`22_ANIMATION_CONSISTENCY_AUDIT.md`
- 阶段后回归：`23_REGRESSION_SWEEP.md`
- 只读代码审查：`24_CODE_REVIEW_ONLY.md`
- 已被 AI 改乱的分支恢复：`25_RECOVER_FROM_BAD_BRANCH.md`
- 把用户纠正沉淀为规则：`26_UPDATE_RULES_AFTER_CORRECTION.md`
- 单功能任务：`27_FEATURE_TASK_TEMPLATE.md`
- 小改动：`28_SMALL_CHANGE_TEMPLATE.md`
- Xcode/Simulator GUI 复现：`29_GUI_REPRODUCTION_WITH_COMPUTER_USE.md`
- Ultra 并行只读审计：`30_ULTRA_PARALLEL_AUDIT.md`
- Live 边界数据固化为 fixture：`31_LIVE_DATA_EDGE_CASE_CAPTURE.md`
- 新线程/Handoff 安全续作：`32_RESUME_OR_HANDOFF.md`
- 阶段收尾与可提交状态：`33_PHASE_CLOSEOUT.md`
- 新生产依赖只读评审：`34_DEPENDENCY_CHANGE_REVIEW.md`
- Android 参考 commit 升级：`35_ANDROID_REFERENCE_UPGRADE.md`
- Live API/登录突然失效：`36_LIVE_API_BREAKAGE_TRIAGE.md`

## 不能跳过的停机点

出现以下任一情况，当前线程必须停止实现并报告：

- Android/API/Protobuf 证据不足，需要猜测。
- 基线构建或测试已失败且无法区分新旧问题。
- 需要修改当前阶段明确禁止的共享组件。
- Pager/MediaViewer spike 未被接受。
- 发现真实 Cookie、BDUSS、STOKEN、密码或私密用户数据进入日志/附件/Git。
- 同一 Bug 的两个根因假设/修复尝试均失败。
- `/review` 仍有未处理 P0/P1。
