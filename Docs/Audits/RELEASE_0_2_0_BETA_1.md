# 0.2.0 Beta 1 发布构建记录

日期：2026-09-27。用户已验收 R01–R13 和最新回复修订，并明确授权提交、SSH 推送与 GitHub IPA 发布。

## 构建范围

- 基线：R13 `8aec6e4`；已验收显示名修复提交 `e479814`。
- 发布准备只更新版本（0.2.0 / Build 2）、README、版本说明及本记录，无新生产行为、手势、动画、overlay 或依赖。
- 真机 Release archive：Xcode 26.6 / 17F113、Swift 6.3.3；`generic/platform=iOS`，arm64，最低 iOS/iPadOS 18.0。
- `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`，沿用既有 Release 的未签名分发方式。需用户自行签名，非 Simulator / App Store / TestFlight 包。
- 用户原有未跟踪 Prompt/skill 文件、私密截图、登录数据不纳入提交或附件。

## 本轮实际检查

| 检查 | 结果及证据 |
| --- | --- |
| R09WriteProtocolTests、R09WriteRepositoryTests、R09ComposerTests 定向 Unit | PASS：15 项逻辑测试 / 18 次参数化执行，0 失败、0 跳过；`Artifacts/Releases/v0.2.0-beta.1/approval-unit.xcresult` |
| `make lint` | PASS：372 个文件，0 违规；`lint.log` |
| `make build` | PASS：`approval-build.log` |
| `make secret-scan`、`git diff --check` | PASS；`secret-scan.log`，提交前复核 |
| `make generate` | PASS：两次 Proto 生成与 tracked 输出一致；`generate.log`；只含已有 unused import 警告 |
| `xcodebuild ... -configuration Release -destination generic/platform=iOS ... archive` | PASS：exit 0 / ARCHIVE SUCCEEDED；`archive.log` |
| 实际真机 archive 的 Release 隔离 | PASS：沿用 `scripts/verify_release_isolation.sh` 所有检查，仅把临时副本的输入路径指向本次 iphoneos archive 及 SwiftFileList；`verify_device_isolation.sh` / `device-isolation.log` |
| IPA 内容与完整性 | PASS：0.2.0 / 2、iPhoneOS / arm64、iPhone+iPad、未签名、可执行位保留、ZIP CRC 通过、归档和 IPA 主程序字节一致；`package-verification.json` |

上述相对证据文件均位于 ignored `Artifacts/Releases/v0.2.0-beta.1/`。实际包隔离检查包含生产组件正对照、Fixture/Debug canary 排除、无本机绝对路径与测试插件；包内无 provisioning profile、私钥或数据库。

未重复全部 Unit、长 UI 或完整 `make quality`。R13 的完整及修订后定向证据见 `Docs/VisualParity/R13_ACCEPTANCE.md`：历史完整 gate 存在失败，不宣称本轮完整 gate 一次全绿。最初 `gh` 仓库/Release 查询因 CLI 未登录失败；Git SSH 连通，Release 改用用户已登录 Safari。该身份验证失败不是构建失败。

## 产物

- 文件：`TiebaLite-0.2.0-beta.1-ios18-arm64-unsigned.ipa`
- 大小：6,349,822 bytes。
- SHA-256：`029ef6686bac1f2dca8022a2d041aa7b10158c16e5cae9bf98715cf5a735930e`
- 附件仅该 IPA 与 `SHA256SUMS`；不上传 xcarchive / dSYM / 私人截图 / 原始调试日志。
- 更新说明：`Docs/Releases/v0.2.0-beta.1.md`，明确列出功能、页面重制、未签名安装方法和已知限制。

## 未知与发布状态

用户已手动确认一次文字加表情回复成功、当前可见；后续审核、长期留存及全部写入类型 Live 矩阵仍 UNKNOWN，未宣称彻底解决风控。本轮未执行真实贴吧发布或上传。

本记录覆盖已完成的本机发布准备；远端分支、标签、Release 与附件上传以 GitHub 页面及后续发布回执为准。

## 已完成发布回执

- Git SSH 原子推送成功：`visual-parity-remediation` 和附注标签 `v0.2.0-beta.1`；远端标签解析到 `b8dc258559172ef7472d590c2311e6029eae1a6d`。未改写 main 或历史。
- 用户自行完成 Safari 登录，Release 已公开：<https://github.com/othbradar/tiebalite-ios/releases/tag/v0.2.0-beta.1>，ID `397563756`，`draft=false`、`prerelease=true`。
- 公开 REST API 复核两项附件均 `uploaded`；IPA 6,349,822 bytes、SHA256SUMS 114 bytes，GitHub 返回的两项 SHA-256 均与本机文件完全一致。
- 发布正文包含新增功能、页面重制、安装方式、限制及源提交。完整机器回执在 ignored `Artifacts/Releases/v0.2.0-beta.1/publication-receipt.json`。
- 上传过程曾有一次原生文件选择器剪贴板超时；改用指定文件路径后上传成功，未上传其他文件。没有进行真实贴吧写操作。
