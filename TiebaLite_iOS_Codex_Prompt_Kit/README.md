# TiebaLite iOS / iPadOS — Codex 桌面版工程提示词套件

这不是“一条万能提示词”，而是一套用于长期约束 Codex 的仓库工程系统：

- `RepoOverlay/AGENTS.md`：所有线程都必须遵守的长期规则。
- `RepoOverlay/.agents/skills/`：审计、实现、调试、交互验收、质量门禁等可重复工作流。
- `Prompts/`：按阶段执行的任务提示词；每次只执行一个阶段；`Prompts/README.md` 是完整顺序表。
- `RepoOverlay/Specs/`：产品范围、架构、交互、动效、测试和 API 证据模板。
- `RepoOverlay/scripts/`：构建、测试、静态禁用模式和环境检查脚本。
- `RepoOverlay/Makefile`：统一入口，避免每个线程自己发明命令。

当前套件包含 44 个阶段/专项提示词、8 个仓库级 Skills，以及按 App/Core/Features/InteractionKit/Tests 等目录分层的 AGENTS 规则。

## 重要原则

不要把全部阶段一次性发给 Codex。正确流程是：

1. 运行 `install_into_repo.sh`，或把 `RepoOverlay` 与 `Prompts` 复制到空 Git 仓库。
2. 把 Android TiebaLite 以只读 Git submodule 放到 `References/TiebaLite-Android`。
3. 在 Codex 桌面版中打开 iOS 仓库根目录。
4. 先阅读 `Prompts/README.md`，再运行 `Prompts/00_BOOTSTRAP_ENVIRONMENT.md`。
5. 每一阶段完成后先运行质量门禁和 `/review`，再提交 Git。
6. 只有当前阶段达到退出条件，才发送下一阶段提示词。

## 推荐模型用法

- 架构审计、Android 源码映射、最终一致性审计：GPT-5.6 Sol Ultra。
- 单一功能实现、单个 Bug 根因修复：Sol Max 或 Extra High 更可控。
- 坚持使用 Ultra 时，仓库规则要求“主代理唯一写入；子代理只读分析”，避免多个代理同时重写导航、Pager 或状态层。

## 目标产品范围

第一优先级是稳定的只读客户端：

- 推荐流。
- 我关注的吧。
- 吧首页和吧内主题列表。
- 帖子、楼层、楼中楼的只读浏览。
- 图片预览、缩放、切换。
- 登录态、Cookie/会话失效处理。
- iPhone 和 iPadOS 自适应。

明确不做：签到、发帖、回复、发布评论。帖子中的已有回复仍需只读展示。

搜索、历史记录、用户资料、设置等放在核心链路稳定之后。

## 文件顺序

先阅读：

1. `QUICK_START.md`
2. `MODEL_AND_WORKTREE_POLICY.md`
3. `RepoOverlay/AGENTS.md`
4. `Prompts/README.md`
5. `Prompts/00_BOOTSTRAP_ENVIRONMENT.md`

`Prompts/99_ONE_TIME_MASTER_PROMPT.md` 只用于把既有空目录整理成受控仓库，不得让它连续实现所有阶段。
