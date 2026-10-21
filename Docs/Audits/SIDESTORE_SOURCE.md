# SideStore 软件源审计（2026-10-21）

## 范围与验收

仅新增软件源、Python 更新/回归脚本、Actions 与使用说明。用户当前任务明确授权尽可能实现、发布及回复 Issue #1，因此执行远端发布；不修改任何已有 IPA、项目版本或业务源码。无动画、手势、overlay、生产依赖变更。

验收规则先定义为：源如实匹配 IPA；首个版本 beta6；新版本必须递增营销版本；版本倒退/仅 Build 变化/附件修改失败关闭；重复运行无差异；保留旧版本并数字降序；下载原 Release 附件。

## 上游证据

核对 SideStore develop 固定提交 `d97ec133719d79916675bdaf722b82a8d091d545`：

- [InstalledApp.hasUpdate](https://github.com/SideStore/SideStore/blob/d97ec133719d79916675bdaf722b82a8d091d545/AltStore/Core/Model/InstalledApp.swift)：比较包内营销版本的语义版本。主三段增加直接返回 true，单独 CFBundleVersion 不参与正常数值版本判断；beta 条件比较的是版本字符串中的 prerelease/build metadata，不是 IPA 的 CFBundleVersion。未解析版本才退回 matches。关联 storeApp、active 等仍是前置条件。
- [StoreApp](https://github.com/SideStore/SideStore/blob/d97ec133719d79916675bdaf722b82a8d091d545/AltStore/Core/Model/StoreApp.swift)：解码 versions，setVersions 取第一个为 latest，选择第一个系统兼容项为 latestSupportedVersion；源生成器负责顺序。
- [AppVersion](https://github.com/SideStore/SideStore/blob/d97ec133719d79916675bdaf722b82a8d091d545/AltStore/Core/Model/AppVersion.swift)：version/date/downloadURL/size，支持 buildVersion、minOSVersion、sha256。
- [VerifyAppOperation](https://github.com/SideStore/SideStore/blob/d97ec133719d79916675bdaf722b82a8d091d545/SideStore/Core/Operations/PipelineOperations/VerifyAppOperation.swift)：可校验 Bundle ID、系统版本、SHA256、大小、version 和 buildVersion。不能为制造更新而写假 version。
- [AppPermission](https://github.com/SideStore/SideStore/blob/d97ec133719d79916675bdaf722b82a8d091d545/AltStore/Core/Model/AppPermission.swift)：兼容隐私数组中的 name=PhotoLibraryAdd，转换为 NSPhotoLibraryAddUsageDescription。
- [ResignAppOperation](https://github.com/SideStore/SideStore/blob/d97ec133719d79916675bdaf722b82a8d091d545/SideStore/Core/Operations/PipelineOperations/ResignAppOperation.swift) 使用用户 Team/证书/Profile 签名；InstallAppOperation 要求重签名结果存在有效 provisioning profile。发布附件本身无需预签名；未在设备上执行这一流程。
- 另读取 GitHub latest release `0.7.0-alpha` 的 InstalledApp.swift，其 hasUpdate 与上述逻辑一致。这里只能证明已读取的两版逻辑，不宣称所有 SideStore 历史版本行为相同。
- [官方源结构参考](https://github.com/SideStore/apps.json/blob/main/_includes/source.json)。本次使用 v1 apps/versions 和 legacy 字段，未启用 releaseChannels。

## 已执行 / PASS

- 初始 clone 完成后 git status --short 为空；早于 clone 完成的一次 status 显示索引写入中的临时 D/??，clone 完成后全部消失，未清理或恢复用户文件。
- curl -L --fail 下载 beta6 原 Release IPA；Python zipfile/plistlib 读取真实包，4991206 bytes，SHA256 `3c9a4e0fb646fe81f722eebf232662628bf09376230e688c51cfffc5dd54e5e9`，与 GitHub asset.digest 一致。Info.plist=dev.local.tiebaliteios / 0.2.0 / 19 / iPhoneOS / MinimumOSVersion18.0。
- python scripts/update_sidestore_source.py --release-json /tmp/beta6-release.json --ipa /tmp/beta6.ipa，退出0；重复执行无变化。
- python scripts/update_sidestore_source.py --check，退出0。
- python -m unittest discover -s scripts -p test_sidestore_source.py -v，7项通过，退出0。覆盖 JSON、幂等、仅Build变化拒绝、0.2.1更新/排序、替换/倒退拒绝、数字排序、IPA身份/大小/hash校验。
- git diff --check，退出0。

## FAIL / NOT_TESTED

- make quality-fast、make quality 均退出2，停于 instructions：仓库现有 `.agents/skills/tiebalite-android-visual-parity/agents/openai.yaml` 缺失；未修改此无关基线。Linux 环境亦不提供 Xcode/Simulator。完整 App 测试、构建未执行，不将源定向检查称为全部质量门禁通过。
- 初次猜测 AltStoreCore/Model/InstalledApp.swift 路径返回404，随后通过上游文件树定位正确路径并读取。
- 真机 SideStore 添加源、原生 decoder、Apple ID 签名/安装、旧手动安装关联、覆盖保留数据、实际通知/更新按钮均 NOT_TESTED。beta5与beta6均0.2.0，旧到新不保证提示；beta6到下一次真实0.2.1只通过源码逻辑及对应数值分支测试验证。

## 发布方式与故障处理

源固定 raw main 地址，无需 GitHub Pages。Actions 发布/编辑Release、手动或每6小时轮询后下载实际附件，验证后原子替换源并提交。权限或分支规则拒绝时保留旧源并报错；不关闭校验来兼容错误版本。重复运行无新提交。版本记录不删除；手工恢复旧JSON可回滚源，但不得悄悄替换已发布IPA。
