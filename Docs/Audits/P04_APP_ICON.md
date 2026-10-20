# P04 — Android TiebaLite 淡蓝图标

## 目标与范围

2026-10-20，P03 经用户验收后已本地提交 `affbc56`，没有推送。
P04 初始制作了三款原创候选；用户随后明确要求直接使用 Android TiebaLite
图标，并将蓝色改为淡蓝色。本次按该新要求接入 Android 图标的矢量形状。
候选没有进入生产资源。本阶段未暂存、提交、推送或发布。

## 修改文件

- `Resources/AppIconSource.svg`：可编辑矢量，保留 Android 的四条路径。
- `Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`：正式不透明 PNG。
- `Resources/APP_ICON_PROVENANCE.md`、`THIRD_PARTY_NOTICES.md`：真实来源、修改和许可记录。
- 本文与 `Docs/Progress/TASK_STATE.md`：验收证据与停止位置。

## 关键设计与状态

来源为只读 Android reference `5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`，
`app/src/main/res/drawable/ic_launcher_new_foreground.xml`；
Manifest 的默认 `@mipmap/ic_launcher_new`、adaptive XML 和 Play Store PNG
共同确认这是正在使用的 Android TiebaLite 图标。
不是官方 IPA 图标，也不标为原创 AI 作品。保留 GPL 来源及仓库现有分发边界。

四条 pathData 与 SVG 路径逐条相等，viewport 为 `18 18 64 64`；
原造型配淡蓝背景 `#9BCBF2`、后卡片 `#CCE5FA`、横线 `#87B8E8`。
完整方形交给系统处理外轮廓。没有改 asset catalog 配置、Bundle ID、
签名、部署目标、页面或发送链路。没有新增动画、手势、overlay、依赖或业务状态转换。

## 执行与回归覆盖

| 命令/检查 | 结果 |
| --- | --- |
| `qlmanage -t -s 1024 -o Artifacts/VisualReview/P04 Resources/AppIconSource.svg` | exit 0，渲染 1024×1024 RGBA，alpha 全 255；转换为 RGB PNG |
| Python 资源校验 | 四条 Android 路径完全相等；PNG 1024×1024 RGB、10,465 bytes；40px/60px 浅深背景预览已查看 |
| `make build` | exit 0，Build Succeeded，SwiftProtobuf 锁不变 |
| `make secret-scan` | exit 0，无高置信度匹配 |
| `git diff --check` | exit 0 |
| `bash Artifacts/VisualReview/P04/install_live.sh` | exit 0，签名/entitlements 检查后覆盖原两台 Live 模拟器 |
| `python3 Artifacts/VisualReview/P04/install_proof.py after` | 两台二进制、Info.plist、Assets.car、派生图标摘要均匹配新构建；原草稿/书签文件摘要保留 |

资源-only 阶段按 P04 不运行业务 Unit/UI、全量 quality 或额外 lint。
检查生成 Info.plist，iPhone/iPad 均引用 AppIcon；
1024 原图及派生资源有效，SVG 没有进入 app bundle。
编译资源（Assets.car 和派生 PNG）较旧图合计减少 2,906,353 bytes。

真实主屏可见新图标，iPhone 从主屏图标打开首页成功；iPad 通过正常
`simctl launch` 恢复 App，原账号头像、关注吧列表及最近逛吧均可见。
不是 fixture/test shell，未卸载、erase、注销、改 Keychain 或清除缓存。
iPhone 原有 6 份草稿/书签摘要保持一致；iPad 原无对应文件。
最终两台留在 Home Screen，供用户检查图标。

证据在 ignored `Artifacts/VisualReview/P04/`：
`build.log`、`secret-scan.log`、`install.log`、`asset-validation.json`、
`compiled-assets.json`、`profile-installed-proof.json`、
`android-light-blue-small.png`、`iphone-home.png`、`ipad-home.png`、
`iphone-live.png`、`ipad-live.png`。

工具中间问题：一次资料检索使用不存在的 `Specs/*DESIGN*` glob，zsh exit 1，
改用 `rg --files`；不是构建失败。CUA iPhone 首次点击返回窗口已改变，
刷新 AX 后成功。iPad 坐标点击遇到 windowNotFoundAtPosition / 窗口已改变，
没有将其视为 App 故障；最终使用原设备的正常 launch 验证，再经系统 Home
返回主屏。没有因此修改 App 或重启/清理模拟器数据。

## 未验证与下一步

真机、iOS 18 主屏及系统着色/深色图标模式未验证；没有新增专用 appearance。
用户最终视觉验收待完成；本次图标不代表旧业务获得新的全量回归结论。
状态为 `READY_FOR_USER_VISUAL_REVIEW`。等待用户验收，P04 不提交、不推送。

## 用户验收与提交授权（2026-10-20）

用户确认“可以，现在提交并推送到github，并发布新的版本”。
据此提交上文已验收P04资源和来源文档；上述等待状态为本轮验收前记录。
新版构建和发布实际结果另见发布审计，不把本次授权记为已发布成功。
