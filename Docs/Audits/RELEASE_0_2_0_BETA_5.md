# v0.2.0beta5 发布构建记录

日期：2026-10-17（Asia/Shanghai）。用户已明确批准U15提交、GitHub推送和新版IPA发布。

## 源码与范围

- U15验收提交 `97741f0fd28d75ea4d50a8d9c06397e25b9ebd97`，包括文档与一个过时UI测试定位修正；此前U09–U14提交一并纳入发布。
- 发布准备只将project.yml Build17→18，App版本保留0.2.0，并更新README、发布说明和本记录。保留发送/回复/上传、视觉、Bundle ID、Keychain及签名团队设置。
- 用户原有Prompts、技能配置、Python缓存不纳入Git，运行证据仅放ignored `Artifacts/Releases/v0.2.0beta5/`。
- 复用相同生产代码的U15回归：Unit161项、iPhone12项（旧定位修正后精确复验）、iPad4项、正常Live只读与本机保存检查；完整范围见U15验收记录。

## 发布验证

准备中：将使用明确发布提交的独立源码快照执行设备Release归档、Release isolation、IPA字节/权限/架构/版本/ZIP/SHA256校验。沿用未签名真机IPA策略，不读取或修改证书、凭证，不重复全量测试。

GitHub CLI当前未登录；SSH远端可访问且main仍为上一发布回执02b32c9。构建成功后快进推送main与新标签，发布及上传通过已有浏览器会话完成；不提取浏览器凭据。

## 保留缺口

正文内容缓存占用/手动清理入口未完成；SDK/Passport按约定跳过，真实语音、全部删除/关系写入分支与物理设备矩阵未全验。不存在新的生产状态、动画、手势、overlay或依赖改动。
