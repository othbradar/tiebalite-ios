# v0.2.0beta2 发布构建记录

日期：2026-10-03（Asia/Shanghai）。用户验收 U06 图片查看器及张数居中，明确批准提交、推送和发布新版 IPA。

## 源码与范围

- U06：`a509d44dfe68fdcca934808db3b0e10803f8f9a4`，37个精确文件，`feat: cache image resources and refine media viewer`；已通过 SSH 推送 `origin/main` 并回读一致。
- 发布准备只改 `project.yml` Build 2→3、README、本版说明和记录，生产代码与已验收候选一致。继承 U01–U05 已提交内容，不进入 U07。
- 用户原有未跟踪 Prompt/skill、Android submodule、Artifacts、个人数据和凭证均不纳入提交或附件。
- 未改 Simulator 签名、Bundle ID、Keychain、证书或用户账号。沿用 Beta 1 的未签名真机 IPA 分发方式，需自行签名。

## 执行与证据

工具链：Xcode 26.6 / 17F113、Swift 6.3.3，SwiftProtobuf 锁定1.38.1。全部相对产物路径位于 ignored `Artifacts/Releases/v0.2.0beta2/`。

- 沿用已验收的 U06 缓存25逻辑项/26参数执行，以及 Viewer 修订19逻辑项/23参数执行、iPhone/iPad 直接短 UI 与 Simulator 人工结果；各批次存在重叠，不累加冒充独立测试总数。详细失败与修正保留于 TASK_STATE。本次未重跑全量 Unit、quality-fast、quality 或长交互矩阵。
- `make generate`：PASS，`generate.log`；生成源码无 tracked 漂移。
- `make lint`：PASS，418文件0违规，`lint.log`。
- `make build`：PASS，`build.log`；本次 Build 3 正常 Debug 构建成功，未改动已安装 Simulator 数据。
- `make secret-scan` 与 `git diff --check`：PASS，提交前复核。
- 真机 archive：PASS，exit 0 / ARCHIVE SUCCEEDED，`archive.log`。完整命令：

```bash
xcodebuild archive -project TiebaLite.xcodeproj -scheme TiebaLite \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath .build/Release020Beta2DerivedData \
  -clonedSourcePackagesDirPath .build/SourcePackages \
  -onlyUsePackageVersionsFromResolvedFile -skipPackageUpdates \
  -archivePath Artifacts/Releases/v0.2.0beta2/TiebaLite.xcarchive \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```

- 设备 Release 隔离：PASS。临时复制 `scripts/verify_release_isolation.sh`，仅将两个输入路径指向本次 iphoneos archive 和 SwiftFileList，全部检查原样执行，见 `verify_device_isolation.sh` / `device-isolation.log`。生产组件正对照存在，Fixture/Debug canary、测试插件、本机绝对路径均未进入包。
- IPA：PASS，真机 iPhoneOS、arm64、最低18.0、支持 iPhone/iPad、版本0.2.0/3、添加照片用途声明存在、未签名。`ditto` 复制归档 App 为 Payload 并打包；ZIP CRC、可执行权限、IPA 主程序与归档字节相同，无 profile/私钥/数据库等文件。见 `package-verification.json`。
- GitHub CLI 查询曾因未登录失败；采用已有登录的 Safari 发布，不提取网页凭证。内置浏览器建页超时，未产生发布操作。Safari 初次链接/键盘导航无跳转，改为明确设置地址栏后成功进入发布表单。

## 产物

- `TiebaLite-0.2.0beta2-ios18-arm64-unsigned.ipa`：6,734,035 bytes。
- SHA-256：`02bf64d510a3f97fb72527ad7d2d762af501db32f1f29a6b868affb80513855a`。
- 附件仅 IPA 与 `SHA256SUMS`；不上传 xcarchive、dSYM、私人截图或原始日志。
- 标签使用用户指定的 `v0.2.0beta2`，预发布；App 使用合法数字版本0.2.0 / Build 3。

## 保留限制

- U03 iPad旋转进入分栏回首楼仍未修复，不标记通过。
- 真机相册、完整设备/Stage Manager/VoiceOver 矩阵未验收；Development Team 未配置。
- 原图显示遵守4096像素解码预算，保存/分享使用实际原始编码文件；动图查看仍只保证静态帧。
- 受控缓存/合并结果与 Live 计数分别记录，未将 U04 Live 合并0次包装成已观察到真实接管。
- 平台接口及发布后审核持续性仍未知，未进行额外真实贴吧写操作。

远端标签、Release 与附件的最终状态以完成后的发布回执为准；本记录当前证明本机产物检查已完成。
