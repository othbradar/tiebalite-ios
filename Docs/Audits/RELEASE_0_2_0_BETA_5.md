# v0.2.0beta5 发布构建记录

日期：2026-10-17（Asia/Shanghai）。用户已明确批准U15提交、GitHub推送和新版IPA发布。

## 源码与范围

- U15验收提交 `97741f0fd28d75ea4d50a8d9c06397e25b9ebd97`，包括文档与一个过时UI测试定位修正；此前U09–U14提交一并纳入发布。
- 发布准备只将project.yml Build17→18，App版本保留0.2.0，并更新README、发布说明和本记录。保留发送/回复/上传、视觉、Bundle ID、Keychain及签名团队设置。
- 用户原有Prompts、技能配置、Python缓存不纳入Git，运行证据仅放ignored `Artifacts/Releases/v0.2.0beta5/`。
- 复用相同生产代码的U15回归：Unit161项、iPhone12项（旧定位修正后精确复验）、iPad4项、正常Live只读与本机保存检查；完整范围见U15验收记录。

## 构建与校验结果

证据均在 ignored `Artifacts/Releases/v0.2.0beta5/`。

- `make generate`、`make lint`、`make secret-scan`、`git diff --check`均PASS；lint602文件0违规、WRITE_BASELINE23项PASS。复用前述U15定向回归，未重复完整quality/quality-fast或全设备矩阵。
- 发布准备提交 `58533e8624a01ee982ed6f04accc6ba4abcd4e65`；在独立detached源码快照生成工程，Android只读引用固定5545326b，包版本锁定且禁止更新。设备Release归档exit0 / ARCHIVE SUCCEEDED：

```bash
xcodebuild archive -project TiebaLite.xcodeproj -scheme TiebaLite \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath ../DerivedData \
  -clonedSourcePackagesDirPath <repository>/.build/SourcePackages \
  -onlyUsePackageVersionsFromResolvedFile -skipPackageUpdates \
  -archivePath ../TiebaLite.xcarchive \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```

- Release isolation PASS：原规则仅适配设备archive/intermediates路径；生产正对照存在，Fixture/Debug、本机绝对路径及测试插件排除。归档仅有AppIntents无框架依赖的metadata extraction提示。
- 787项生产输入对比U15已验收包，仅project.yml的Build17→18不同；所有产品源码/资源保持，独立快照工作树clean。
- IPA为iPhoneOS/arm64、最低18.0、UIDeviceFamily1/2、0.2.0(18)、Bundle ID `dev.local.tiebaliteios`，与既有U15归档一致。无CodeSignature/profile，沿用需用户自行签名的分发策略。
- ZIP CRC、140个文件与归档逐字节一致、主程序可执行权限均PASS。校验脚本初版错误假定Bundle ID导致assertion失败，读取项目变量与既有归档后改为比较基准；未改变产品Bundle ID，复验通过。
- `TiebaLite-0.2.0beta5-ios18-arm64-unsigned.ipa`：7,747,492 bytes；SHA256 `8597f4872dc51a197055f2583cf574d16a5847b58d783325fe2781b200c63447`。
- `SHA256SUMS`：112 bytes；文件自身SHA256 `e1641b43e70fcdd47ba9cfa1d07ea91a53bf8def72a9f232c7e8ab55adea0f87`。仅发布上述两个附件，不上传archive/dSYM、诊断原件或用户数据。
- main和注释标签已通过SSH原子快进推送；远端main与标签解引用均为上述构建提交。不移动已发布标签。
- `gh release list`因未登录exit4；使用已有Chrome会话，不提取凭证。页面自动翻译导致一次英文定位无匹配，按当前页面重新定位；标签列表刷新后选中已推送标签。扩展上传因缺文件URL权限失败，改用系统文件选择器，不扩大扩展权限。首次路径粘贴未生效，核对路径后用setValue精确选择IPA，未上传其他文件。

## 保留缺口

正文内容缓存占用/手动清理入口未完成；SDK/Passport按约定跳过，真实语音、全部删除/关系写入分支与物理设备矩阵未全验。不存在新的生产状态、动画、手势、overlay或依赖改动。

## 发布完成回执

- [GitHub Release](https://github.com/othbradar/tiebalite-ios/releases/tag/v0.2.0beta5) 已发布为Pre-release，页面时间2026-10-17 17:21（Asia/Shanghai），标签仍指向归档源码 `58533e8624a01ee982ed6f04accc6ba4abcd4e65`。
- 两个手动附件均已上传；页面显示IPA 7.39 MB、SHA256SUMS 112 Bytes。分别读取GitHub附件区完整SHA256，两者均与本地上述摘要一致；另有GitHub自动生成的两份源码归档。
- 发布后只读进入编辑页面核对服务器保存的说明文本，与准备稿逐字相同（统一行尾空白）；未再次保存或修改发布内容，已返回下载页。
- 公共API核验收到HTTP403 rate limit exceeded，未反复请求；改用已发布页面DOM/原生AX与服务器附件摘要核验，不能声称取得API release/asset ID或精确字节字段。扩展在最后只读校验时超时失联，转原生AX完成文本相等检查，未扩大权限。
- ignored `published-verification.json`、`published-page.txt`、`published-body.md`及`published-assets.jpg`保留实际回执。本文和TASK_STATE为发布后纯文档记录，随后正常快进推送，不改变标签、IPA或产品代码。
- 本次发布准备/记录仅修改project.yml、README、发行说明、构建记录及TASK_STATE；没有新增生产状态、动画、手势、overlay或依赖。正文缓存入口、SDK/Passport及未验真实矩阵保持原边界；完成后停止，不进入下一阶段。
