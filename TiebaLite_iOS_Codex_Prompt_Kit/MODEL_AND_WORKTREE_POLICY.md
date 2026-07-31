# Sol Ultra、子代理与 Worktree 使用策略

## Ultra 适合做什么

可以并行拆分且主要是读取/分析的任务：

- Android 端 API、Protobuf、页面行为、内容节点的独立审计。
- 架构方案风险评审。
- 可访问性、iPad、性能、安全和测试覆盖的独立审计。
- 最终功能一致性矩阵核对。
- 大型 Bug 的日志、状态机、视图身份、手势和异步时序分轨分析。

## Ultra 不应并行写什么

以下内容只能由一个主代理串行修改：

- App 导航根节点。
- Tab 与 NavigationStack/NavigationSplitView 状态。
- PagerContainer。
- MediaViewer 手势仲裁。
- DesignSystem/Motion。
- 网络协议和会话核心。
- 同一 Feature 的 Store、View 和测试。
- XcodeGen 配置及工程生成文件。

仓库 `AGENTS.md` 明确规定：**只有协调主代理可以写工作树；Ultra 子代理默认只读，输出证据和建议。**

## Worktree 适合做什么

适合并行：

- 一个 worktree 做 Android 只读审计，另一个做测试矩阵审阅。
- 主分支实现功能，独立 worktree 做不改代码的 `/review` 或可访问性审计。
- 已有稳定基础设施后，两个完全不共享文件的 Feature 才可独立开发。

不适合并行：

- 一个 worktree 改导航，另一个改页面路由。
- 两个 worktree 各自实现 Pager 或图片查看器。
- 基础架构未冻结时并行做推荐、吧首页和帖子页。
- 两个分支都改 `project.yml`、`Package.resolved`、DesignSystem 或共享模型。

## 每个阶段的 Git 要求

- 开始前 `git status --short` 必须可解释。
- 阶段内不混入无关格式化或依赖升级。
- 质量门禁通过后形成一个可回退的语义提交。
- 不在失败状态继续叠加下一阶段。
- 连续两次修复同类交互问题仍失败时，回到最后绿色提交，重新设计组件，不堆第三层补丁。
