# Android 参考仓库版本升级与证据重审

仅在用户明确要求更新 TiebaLite Android 参考 commit 时执行。不得在普通功能任务中自动 `git submodule update --remote`。

## 前置

- 工作树可解释，当前阶段有绿色基线。
- 记录旧 lock SHA、目标 branch/commit 和升级原因。
- 创建独立 branch/worktree；主功能实现暂停依赖此升级的写入。

## 流程

1. 在不改源码的前提下更新 submodule 到明确目标 commit。
2. 生成旧→新 diff 摘要，重点：API、请求常量、Proto、repository、登录/session、内容节点、分页和 UI 行为。
3. 使用 `$tiebalite-reference-audit` 和 `$tiebalite-api-evidence` 做只读影响分析。
4. 更新 API/Proto/Feature/Content/Unknown/License 规格，逐项标记：UNCHANGED、CHANGED、REMOVED、NEW、UNKNOWN。
5. 只在证据审计完成后更新 `References/TiebaLite-Android.lock`。
6. 运行现有 fixture decode/mapper/request tests；旧 fixture 失败时先判断协议真实变化，不直接重录所有 fixture。

## 禁止

- 不把 submodule dirty 改动带入。
- 不机械同步 Android UI。
- 不在同一任务同时改 iOS 生产实现。
- 不删除旧证据或 fixture 来掩盖不兼容。

## 输出

- `Docs/Audits/ANDROID_REFERENCE_UPGRADE_<old>_<new>.md`
- 更新后的 lock/Specs/UNKNOWN。
- iOS 受影响任务列表及优先级。

审计完成后停止，由后续独立任务实施必要变更。
