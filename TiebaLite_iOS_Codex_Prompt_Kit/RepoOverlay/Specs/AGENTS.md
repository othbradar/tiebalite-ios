# Specs 规格与证据约束

- 规格必须区分 CODE_EVIDENCE、RUNTIME_EVIDENCE、INFERENCE、UNKNOWN；不能把推断写成已证实行为。
- 状态机、route、接口、内容节点、交互和动效文档之间不得互相矛盾。
- 变更已批准规格时记录原因、影响、迁移/回滚和对应测试；高风险决策使用 ADR。
- API/Proto 结论引用 Android 路径/symbol、脱敏 fixture 或受控 live 证据，不凭字段名猜测。
- 阶段完成状态只根据真实命令和证据更新；未运行项标 NOT_TESTED。
