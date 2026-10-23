# v0.2.0beta7 发布记录

状态：PUBLISHED / VERIFIED，2026-10-23。用户已在实机验证SF候选包更顺滑，授权提交、推送、发布IPA并更新既有SideStore源；上述发布及在线文件校验已完成。

## 范围及来源

- P05已有本地提交 `c6401e9`；本轮SF-00～08提交 `9924674`。远端 `8692529` 已增加SideStore源及维护自动化，本地正常合并为 `7e537f6`；仅TASK_STATE发生前缀记录冲突，保留双方完整记录后解决，未改已验收产品源码、未重写历史。
- 标签沿用v0.2.0beta7；实际App版本由0.2.0/19递增为0.2.1/20，Bundle ID保持dev.local.tiebaliteios。Issue #1及现有维护脚本明确要求营销版本递增；沿用原raw main地址与自动化，不伪造JSON版本、不替换历史附件。
- 保留用户无关未跟踪提示词、技能配置及缓存。沿用真机Release未签名IPA+SHA256SUMS和GitHub Pre-release；不发布私人参考、账号数据、archive或dSYM。

## 已执行检查

- 提交前make lint exit0（643文件零违规、冻结写链23项）、secret-scan及diff检查exit0；复用已经验证且生产摘要一致的72项Unit及19项UI，不把用户体验改善等同所有场景量化达标。
- 合并后SideStore 7项Python回归exit0，包含拒绝仅Build增加、下一营销版本检测、排序、身份/大小/SHA、替换及回滚保护。
- 全仓forbidden仍有已记录的既有失败，本轮无新增；不重复全历史quality。
- gh未登录；jshook工具激活后连接现有Chrome因未启用DevTools端点失败，未读取凭据或改浏览器权限。发布使用已登录Chrome的原生界面，公开API及附件回读校验见下文。

## 归档与截图

- `make generate` exit0；generic iOS Release archive exit0；正常 Simulator Release build exit0。805个生产构建输入在归档前后及发布准备后摘要一致，聚合摘要 `4e8f0722bfc6499e69a484760c2dc9fafc01a882e6231cae4e1e88bdda768305`。文档和截图不参与生产编译。
- 完整真机包 `TiebaLite-0.2.0beta7-ios18-arm64-unsigned.ipa`：5,029,123 bytes，SHA256 `cb66f3c67e7ba39ad7103ac77a2347efe08ebf19708f2324b5529e39986c1042`。arm64、iPhoneOS、iOS18.0、iPhone/iPad、0.2.1/20、原bundle，140文件和132表情、图标及相册权限均在。ZIP CRC与逐文件内容/可执行权限匹配archive。Release隔离检查exit0，没有SF探针、Debug/UITESTING或本机源码路径。
- 主程序SHA256 `ae58161e701f20b44263c3c374dbe285e0785a0c3e461b3d02b57c236b072c97`，与用户实机接受的候选主程序一致；正式版仅增加版本元数据及发布文档。
- iPhone17Pro与iPadPro13M5原模拟器覆盖安装0.2.1/20；重新查询安装后容器，Documents/Application Support分别8/1个文件摘要一致，未卸载、未清数据或Keychain。初版校验脚本固定旧容器路径，安装后误报preflight文件变化，exit1；更正为安装后重新解析容器后exit0，没有恢复或修改该文件。
- 当前正常Live实际截图4张（iPhone吧首页、帖子中部、独立楼中楼及iPad吧首页），已逐张检查。README替换旧Beta1展示并更新功能、安装和验证范围。采集时关注吧首页网络加载失败，公开吧内页面及楼中楼可读；未据此改协议或声称完整实网验收。
- 证据在忽略目录 `Artifacts/Releases/v0.2.0beta7/`：archive/screenshot-live-build命令与日志、production-inputs.json、package-verification.json、screenshot-installation-proof.json、SHA256SUMS、published-release.json、published-source.json及downloaded/线上附件。

## 发布、源更新与在线回读

- 发布准备提交 `9883efc1a809f7ad4457cad0fe99fa42df96f194` 与注释标签 `v0.2.0beta7` 经SSH原子推送成功；805项生产输入与该提交逐项匹配。标签不随后续发布记录移动。
- [GitHub Release](https://github.com/othbradar/tiebalite-ios/releases/tag/v0.2.0beta7) 已于2026-10-23 11:15:47 UTC公开，Release ID `421747039`，draft=false、prerelease=true。发布页、标签及两个附件实际可见；发布正文规范化换行后与本地说明完全一致。
- 重新下载线上IPA和SHA256SUMS，均与本地逐字节相同。IPA大小5,029,123 bytes、SHA256与上文一致，ZIP CRC通过，包内真实版本0.2.1/20。SHA256SUMS为112 bytes，SHA256为 `d0df03239928e7fc79b448e866139791454ef1c0d101ea80006e8668b147e706`；GitHub附件摘要与本地计算值一致。
- Release触发的两次SideStore任务均成功：[39944852383](https://github.com/othbradar/tiebalite-ios/actions/runs/39944852383)、[39944852362](https://github.com/othbradar/tiebalite-ios/actions/runs/39944852362)。机器人提交 `ec10eda` 仅更新源；本地已fetch并fast-forward，不重写历史。
- [线上源](https://raw.githubusercontent.com/othbradar/tiebalite-ios/main/sidestore/source.json) 回读与本地JSON完全相同。首项0.2.1/20的下载地址、大小、SHA256及最低系统版本与发布IPA一致，历史0.2.0/19保留，顶层兼容字段同步。使用公开Release JSON和重新下载的IPA执行更新脚本两次均exit0，随后 `git diff --exit-code -- sidestore/source.json` 均exit0；`--check` 与7项Python回归再次通过。
- GitHub README已展示新版功能、3张iPhone和1张iPad正常Live截图；图片引用及页面渲染已检查。按用户追加要求删除README的“本版更新”整段，具体变更继续由Release页面承载。源维护文档同步当前beta7及实际App版本。
- 没有在物理设备上运行SideStore签名、源关联或Update按钮流程；已验证的是已发布IPA、在线源与已核对的版本检测条件，不将自动化通过表述为实机更新提示已亲测。刷新Sources后在My Apps检查Update，签名刷新与版本安装仍为不同操作。
- 本轮未改发送协议、未新增生产动画/手势/overlay/依赖，未执行真实贴吧写操作或Issue评论。无关未跟踪资料保留，不进入其他阶段。
