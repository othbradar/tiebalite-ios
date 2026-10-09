# v0.2.0beta4 发布构建记录

日期：2026-10-09（Asia/Shanghai）。用户实际确认Build16评论即时回显与格式正常，批准提交、推送并发布，明确选择v0.2.0beta4。

## 源码与范围

- 已验收Build14–16共39份相关文件精确提交：`1b696746c1280b45149cd67b7957059b6228fe06`（fix: refresh sent replies and preserve reader layout），已连同beta3之后先前本地提交正常快进推送main。没有纳入用户原有Prompt/skill/Python缓存、Artifacts、凭证或Android submodule。
- Build16的720份生产输入全部相同，复用已记录定向测试；用户确认普通评论即时回显正常。发布准备仅将project.yml Build4→17并更新README、发布说明与记录，App版本保持0.2.0。
- 不修改已验收发送链、视觉、恢复、签名团队、Bundle ID或Keychain；本轮没有真实发送、重新安装或清理Simulator数据，不进入下一阶段。

## 执行结果

Xcode26.6/17F113，证据：ignored `Artifacts/Releases/v0.2.0beta4/`。

- `make generate`、`make lint`、`make secret-scan`、`git diff --check`：PASS。524文件0违规，WRITE_BASELINE23项PASS；未重新跑全部Unit/quality-fast/quality。
- 最新相关既有验证：Build16 Unit8方法PASS、iPhone/iPad各1条短UI PASS；Build15真实只读getmypost成功、相关Unit31方法及iPhone1条UI PASS，Build14定向结果见TASK_STATE。没有将重复执行计数相加。
- 真机归档exit0 / ARCHIVE SUCCEEDED：

```bash
xcodebuild archive -project TiebaLite.xcodeproj -scheme TiebaLite \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath .build/U08NativeTrialDerivedData \
  -clonedSourcePackagesDirPath .build/SourcePackages \
  -onlyUsePackageVersionsFromResolvedFile -skipPackageUpdates \
  -archivePath Artifacts/Releases/v0.2.0beta4/TiebaLite.xcarchive \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```

- 设备Release隔离PASS：现有verify_release_isolation.sh规则不变，仅副本输入改为设备归档路径；生产正对照存在、Fixture/Debug和本机绝对路径已排除。
- IPA ZIP CRC、可执行权限、140份归档文件逐字节相同、iPhoneOS/arm64/18.0+/iPhone+iPad、0.2.0/17及照片仅添加用途声明核验PASS；无签名/profile，需用户自行签名。
- 归档前后720份验收输入保持；project.yml单独记录Build17摘要。既有AppIntents和方向声明warning保留，没有为消除警告改变界面。
- `gh auth status`未登录；Chrome浏览器扩展入口两次超时，已改用Chrome原生辅助功能界面确认已有GitHub会话，不读取浏览器凭据。未采用Safari。

## 产物

- `TiebaLite-0.2.0beta4-ios18-arm64-unsigned.ipa`：7,163,003 bytes。
- SHA256：`4aa54e2f18265d6c76dc62f159556a004fba4dce366fd7ab91cf865911d38ad9`。
- 仅发布IPA与SHA256SUMS，不上传archive、dSYM、原始诊断、测试附件或用户内容。
- Development Team未配置，沿用未签名真机IPA。Simulator验收不代表完整真机、相册或Stage Manager验收。

## 未对齐范围

SDK/Passport及安全验证续发按用户约定暂不接入；图片原图/透明度/完整压缩与元数据、图文混排/提前并发上传等仍有差异；GIF真实动画与多图/其他发送目标待分别实测。服务端审核留存不由一次发送成功保证。缺失楼层号保持未知，正文样式已恢复正确。具体见本版发行说明及UNKNOWN_BEHAVIORS。

## 发布完成回执

- 发布准备提交：`504bef4cf14d1835fef35b4c51e9e6452a3ab703`。main及注释标签v0.2.0beta4已原子推送；远端tag解引用与归档源码相同，发布后不移动标签。
- [GitHub Release](https://github.com/othbradar/tiebalite-ios/releases/tag/v0.2.0beta4)：ID `407592777`，发布时间`2026-10-09T06:39:20Z`；公共API确认draft=false、prerelease=true。正文与准备好的发行说明逐字核对一致（仅统一换行）。
- IPA附件ID `624111545`，7,163,003 bytes，state=uploaded；GitHub digest为`sha256:4aa54e2f18265d6c76dc62f159556a004fba4dce366fd7ab91cf865911d38ad9`，与本地一致。
- SHA256SUMS附件ID `624126147`，112 bytes，state=uploaded；GitHub digest为`sha256:0e69a06c5e74c4a4af31475167c13613dbf54b429890f6552a2c7cf10626c015`，与本地一致。Release恰有这两个手动上传附件。
- 可复核公共回执保存在ignored `Artifacts/Releases/v0.2.0beta4/published-verification.json`。本节与TASK_STATE是发布后的纯文档回执，不改变已验收代码、IPA或现有用户数据。
