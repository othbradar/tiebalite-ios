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

## 构建及产物验证

- 最终归档源码 `54f03d238b62459937671732df68b51e25f2455b`（发布准备`b6e9e06`后增加上述单行Release编译修正）。`make generate`、修正后的`make lint`（623文件0违规、冻结23项）、`make secret-scan`和`git diff --check`均通过。
- 独立detached源码快照重跑相同`xcodebuild archive`命令，设备Release归档exit0 / ARCHIVE SUCCEEDED。Release隔离检查exit0：保留生产renderer、Pager和MediaViewer，排除Debug/Fixture、测试插件及本机绝对路径。未运行全量quality。
- 799项生产输入逐项与最终提交摘要一致。相对已验收P04，只有Build18→19及搜索历史条件判断等价修改；快照Android目录使用固定只读引用软链接，未宣称此子模块路径为clean。
- 包校验通过：iPhoneOS/arm64、最低18.0、UIDeviceFamily1/2、0.2.0(19)，Bundle ID与beta5一致；无CodeSignature/profile。ZIP CRC、全部140文件与归档逐字节相等、主程序可执行权限、AppIcon声明及已验收PNG摘要均通过。
- 校验脚本首次将project.yml版本行按无引号比较而断言失败；查看真实差异后保留原有引号精确比较，复验通过，未调整产品配置。
- `TiebaLite-0.2.0beta6-ios18-arm64-unsigned.ipa`：4,991,206 bytes；SHA256 `3c9a4e0fb646fe81f722eebf232662628bf09376230e688c51cfffc5dd54e5e9`。
- `SHA256SUMS`：112 bytes；自身SHA256 `3bfdfc12c899c87cf109b94485e28d3410b078634f56fc2d08355bb0489d38d2`。
- 原始日志、隔离检查与`package-verification.json`保留于ignored `Artifacts/Releases/v0.2.0beta6/`。仅上述两个附件纳入发布，不上传archive、dSYM、私人参考或账号数据。

## 发布完成回执

- main及注释标签`v0.2.0beta6`已通过SSH原子快进推送。远端main及标签解引用均核对为`54f03d238b62459937671732df68b51e25f2455b`；注释标签对象为`0c18b3b1965cd13c6642eb7f3b2f3fcc3d4e9726`。
- [GitHub Release](https://github.com/othbradar/tiebalite-ios/releases/tag/v0.2.0beta6)已发布为Pre-release，页面提交与归档源码一致。手动附件IPA和SHA256SUMS均存在，页面显示4.76 MB与112 bytes；另有GitHub自动生成的两份源码包。
- 直接读取GitHub附件区完整SHA256，两个文件均与上面的本地摘要一致。发布后只读进入编辑页，服务器保存说明与准备稿逐字相等（仅统一末尾空白），未再次保存；已返回下载页。
- 浏览器扩展多次连接超时，改用Chrome原生界面。操作期间焦点数次切到其他页面，用户随后确认可以操作；所有上传均经系统文件选择器精确选择既定产物，未扩大扩展权限、提取会话凭据或上传其他文件。页面翻译只影响渲染，服务器保存的Markdown已独立核对。
- ignored `published-page.txt`、`published-body.md`、`published-assets.png`、`published-verification.json`保存回执。本文和TASK_STATE为发布后纯文档补记，正常快进推送，不改标签、IPA或生产代码。

未新增生产状态、动画、手势、overlay或依赖。继承各阶段已列真机、服务端及SDK边界。
