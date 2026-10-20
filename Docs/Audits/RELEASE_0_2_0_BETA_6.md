# v0.2.0beta6 发布构建记录

日期：2026-10-20（Asia/Shanghai）。用户已验收P04，并明确授权提交、推送GitHub和发布新版。

## 源码与范围

- P01 `6460a0d`、P02 `c87b60b`、P03 `affbc56` 和 P04 `99a8dfe` 均纳入本版。
- 发布准备仅Build18→19、README、版本说明与记录，App版本保持0.2.0。保留Bundle ID、签名团队、Keychain、现有页面和写请求链路。
- 用户原有未跟踪提示词、技能配置与Python缓存不纳入Git；私人参考IPA、截图、账号数据及编译产物不进入源码提交。
- 复用P01–P03直接回归、用户视觉验收及P04完整Live安装证据，见各阶段审计；本次不重复全量quality或业务测试矩阵。
- P04提交前 `make lint` 通过（623文件0违规、WRITE_BASELINE23项）；`make secret-scan`、`git diff --check`通过。

## 发布流程

从本地发布准备提交创建隔离源码快照，使用固定Android只读引用与SwiftProtobuf锁，构建generic iOS设备Release归档。沿用beta5未签名IPA策略，校验Release隔离、架构、版本、ZIP CRC、归档文件一致性和SHA256后发布两个附件：IPA与SHA256SUMS。

GitHub CLI未登录（release list/view均exit4），浏览器扩展首次连接超时，转已有Chrome会话的原生界面操作。没有提取凭证或改账号权限。SSH远端只读检查确认main仍为已发布beta5之后的记录提交，beta6标签尚不存在。

## 状态

首次设备Release归档实际失败（exit65）：`AppCompositionRoot.makeSearchStore`引用仅Debug定义的`.fixture`。已将历史持久化判断等价改为`== .live`，Debug中仍为fixture不持久化、Live持久化，Release只依赖生产枚举值。不扩大测试枚举编译范围、不改变搜索业务或发送链路。原失败日志保留为`archive-initial-failed.log`；使用相同归档命令重跑作为直接回归。

归档、附件及发布回执待执行完成后追加；本记录不提前宣称发布成功。
未新增生产状态、动画、手势、overlay或依赖。继承各阶段已列真机、服务端及SDK边界。
