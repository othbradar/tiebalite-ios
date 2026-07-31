# Docs 审计、ADR 与进度记录约束

- ADR 记录问题、约束、候选、决策、后果、回滚条件和状态；不得事后只写结论。
- Audits 保留环境、commit、scenario、方法、证据路径、PASS/FAIL/PARTIAL/NOT_TESTED 和不确定性。
- `Docs/Progress/TASK_STATE.md` 是跨线程恢复依据，只写当前仓库可证实事实。
- 不把真实凭据、Cookie、token、完整私密响应或未脱敏截图放入文档。
- 文档更新不能代替代码测试；测试结果必须含实际命令/退出状态或 xcresult 路径。
