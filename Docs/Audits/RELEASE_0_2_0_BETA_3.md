# v0.2.0beta3 发布构建记录

日期：2026-10-04（Asia/Shanghai）。用户已验收三项首页修复，明确批准提交、推送及新版IPA发布。

## 源码与范围

- U06P1–U06P4分别为85e0b0c、b16c6f0、0d37b45、b976ffa；首页追加修复精确16文件提交 `4e66ea614d1c46d32d6af43d88384b03495d9ff9`，`fix: polish forum entry and recent forum controls`。
- 15个验收候选文件SHA256均不变，沿用已有7项Unit/5条UI及最终减号位置人工验收。各U06P批次沿用对应已验收直接结果，不重新运行全量Unit/quality-fast/quality或长矩阵。
- 发布准备只改project.yml Build 3→4、README、版本说明与记录；App版本0.2.0。未改签名、Bundle ID、Keychain或当前Simulator安装数据；用户原有Prompt/skill及Android submodule保持原样。
- 本轮无新增生产代码、手势、动画、overlay或依赖，不进入U07。

## 本次执行结果

工具链Xcode26.6/17F113；证据位于ignored `Artifacts/Releases/v0.2.0beta3/`。

- `make generate`：PASS，generate.log。
- `make lint`：PASS，426文件0违规，lint.log。
- `make build`：PASS，正常Simulator Debug Build4，build.log；未覆盖或清理当前安装。
- `make secret-scan`、`git diff --check`：PASS。
- 真机archive：exit0 / ARCHIVE SUCCEEDED，archive.log。命令：

```bash
xcodebuild archive -project TiebaLite.xcodeproj -scheme TiebaLite \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath .build/Release020Beta3DerivedData \
  -clonedSourcePackagesDirPath .build/SourcePackages \
  -onlyUsePackageVersionsFromResolvedFile -skipPackageUpdates \
  -archivePath Artifacts/Releases/v0.2.0beta3/TiebaLite.xcarchive \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```

- 设备Release隔离：PASS。将现有verify_release_isolation.sh副本的App与intermediates两个输入改成本次iphoneos归档路径，其他规则不变。生产正对照存在，测试Fixture/Debug入口、插件、本机绝对路径均排除，见device-isolation.log。
- 包核验：PASS，ZIP CRC、可执行权限、归档与IPA二进制相同，iPhoneOS/arm64/18.0+/iPhone+iPad、0.2.0/4及仅添加照片用途声明正确，无签名、profile、凭证或数据文件，见package-verification.json。
- 编译保留两条warning：未依赖AppIntents所以跳过元数据提取；全屏/支持方向的归档校验提示。没有编译错误，不为消除提示改导航或设备方向配置。
- CLI `gh auth status` 返回未登录；使用用户指定Chrome已有会话发布，不读取浏览器凭证。此前定位文件的命令因不存在.github/App/Info.plist退出2，随后使用实际路径完成读取，与构建无关。

## 产物

- `TiebaLite-0.2.0beta3-ios18-arm64-unsigned.ipa`，6,789,405 bytes。
- SHA256：`cd775ccaea77a5ffaaa33e8c6f39c47efe942d1ceb0e9d35efabfa1c4220a0b1`。
- 附件仅IPA与SHA256SUMS，不上传xcarchive/dSYM、截图或原始日志。
- 沿用未签名真机分发，需要用户自行签名。Development Team未配置；Simulator验收不等于真机验收。

## 保留限制

- P4已修复指定iPad旋转回首楼问题，组件/短UI和正常Live多页帖检查通过；手工窗口调宽缺有效Live样本，窄宽以定向UI为证，完整Stage Manager/真机矩阵未覆盖。
- 真机相册未验收；图片可选写队列满时可能不持久化，显示解码4096像素预算与动图静态帧限制不变。
- 两处条件性热点仍NOT_MEASURED，不把计数优化写成FPS或全设备耗时承诺。

本记录当前确认本机构建，远端标签、发布正文及附件摘要待发布后另补回执。
