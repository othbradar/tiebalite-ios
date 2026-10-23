# SideStore 软件源

在 SideStore 的 Sources（源）页面点击 `+`，粘贴：

```
https://raw.githubusercontent.com/othbradar/tiebalite-ios/main/sidestore/source.json
```

添加源后选择 **TiebaLite iOS** 安装。需要 iOS/iPadOS 18.0 或更高版本，并先完成 SideStore 自身的账号、配对和签名环境设置。此源直接下载原 GitHub Release 的未签名真机 IPA，由 SideStore 使用你的证书重新签名；无需开发者提供企业签名。源不提供证书或绕过系统签名。

此源包含公开 Beta，使用兼容的 v1 `versions` 数组，不依赖 SideStore 的 Beta channel 开关。`versions[0]` 是最新版本，同时保留顶层旧版字段。刷新源用于获取元数据；出现新版本后在 My Apps 中执行 Update。定时刷新签名不等于自动安装新版本。

已有客户端请保留原 Apple ID/Team、签名后 Bundle ID 及自定义 ID 设置，尝试覆盖安装，避免卸载丢失资料。从其他签名工具转入或手动导入的 App，不保证能自动关联此源；请先备份资料，再核对 SideStore 的关联/安装行为。不要为了更新检测修改此源的 Bundle ID。

## 版本规则（发布前必须执行）

首个版本为 `v0.2.0beta6`，IPA 内实际 `CFBundleShortVersionString=0.2.0`、`CFBundleVersion=19`。源如实使用 `version=0.2.0`、`buildVersion=19`，没有修改发布附件。Release 标签只用于显示及定位下载，不作为 IPA 版本。

后续每个公开 Beta **也必须递增数值型 MARKETING_VERSION**，并增加 Build。例如 beta7 的 IPA 可为 `0.2.1 / 20`，下个 Beta 为 `0.2.2 / 21`，之后正式版采用更高版本（如 `0.3.0`）。标签可继续叫 `v0.2.0beta7`，但发布说明应明确实际 App 版本。不要重复 `0.2.0` 仅增加 Build，不要只改 JSON 为 `0.2.0-beta.7` 或 `0.2.0+20`：前者不触发可靠更新，后者与 IPA 不符会被校验拒绝。

目前源中的 beta6 对已安装同营销版本的 beta5 **不保证显示更新**；可通过源中的安装操作尝试覆盖为 beta6。beta6 到下一次真实 `0.2.1` 的更新在已核对代码路径上可被检测。无需也不应该重打包旧版解决这个历史限制。

## 更新源

使用 Python 3.12+，无第三方运行依赖：

```bash
python scripts/update_sidestore_source.py --tag v0.2.0beta6
python scripts/update_sidestore_source.py --check
python -m unittest discover -s scripts -p test_sidestore_source.py -v
```

脚本读取 Release，下载唯一匹配 `*-ios18-arm64-unsigned.ipa` 的附件，读取包内 Info.plist，验证大小、GitHub 提供的 SHA256、设备平台及 Bundle ID，提取真实版本/Build/最低系统版本。新版本按数字版本降序排列，历史版本保留；重复执行不改变 JSON。相同营销版本、倒退版本、已发布条目变化、多 IPA、缺失附件、草稿 Release 会报错且不覆盖源。源码项目配置与已发布 IPA 无须相同，源以下载的 IPA 为准。

工作流 `.github/workflows/sidestore-source.yml` 在 Release published/edited 后运行；每6小时检查最新公开 Release（含 prerelease），也可手动指定 tag。先上传完整附件再发布 Release；上传较晚可手动重跑或等待定时任务。若短时间连续发布多版，漏掉的中间版可按递增版本顺序手动补入。旧 Release edited 事件只允许完全相同的元数据，不会回滚源。

工作流固定 checkout main，验证通过后只提交 `sidestore/source.json`。需要 Actions 的 contents:write 和允许机器人向 main 推送；若分支规则阻止推送，任务会失败，可本地执行脚本后通过 PR 更新。失败不会发布部分 JSON。Raw 地址有缓存，新提交后可能需要稍后再刷新。

## 验证边界

实际验证及上游源码定位见 [SideStore 发布审计](../Docs/Audits/SIDESTORE_SOURCE.md)。已验证 IPA 字节、JSON、版本顺序、幂等和更新规则；没有连接物理 iPhone/iPad，没有执行 Apple ID 签名、安装、覆盖保留数据或 SideStore 原生 CoreData 解码测试。测试中对更新判断的验证是针对已核对源码的数值版本分支，并非运行 SideStore App。
