# v0.2.0beta7 发布记录

状态：PREPARING，2026-10-23。用户已在实机验证SF候选包更顺滑，授权提交、推送、发布IPA并更新既有SideStore源。

## 范围及来源

- P05已有本地提交 `c6401e9`；本轮SF-00～08提交 `9924674`。远端 `8692529` 已增加SideStore源及维护自动化，本地正常合并为 `7e537f6`；仅TASK_STATE发生前缀记录冲突，保留双方完整记录后解决，未改已验收产品源码、未重写历史。
- 标签沿用v0.2.0beta7；实际App版本由0.2.0/19递增为0.2.1/20，Bundle ID保持dev.local.tiebaliteios。Issue #1及现有维护脚本明确要求营销版本递增；沿用原raw main地址与自动化，不伪造JSON版本、不替换历史附件。
- 保留用户无关未跟踪提示词、技能配置及缓存。沿用真机Release未签名IPA+SHA256SUMS和GitHub Pre-release；不发布私人参考、账号数据、archive或dSYM。

## 已执行检查

- 提交前make lint exit0（643文件零违规、冻结写链23项）、secret-scan及diff检查exit0；复用已经验证且生产摘要一致的72项Unit及19项UI，不把用户体验改善等同所有场景量化达标。
- 合并后SideStore 7项Python回归exit0，包含拒绝仅Build增加、下一营销版本检测、排序、身份/大小/SHA、替换及回滚保护。
- 全仓forbidden仍有已记录的既有失败，本轮无新增；不重复全历史quality。
- gh未登录；jshook工具激活后连接现有Chrome因未启用DevTools端点失败，未读取凭据或改浏览器权限。发布使用已登录Chrome的原生界面。命令/回执后续补记。

## 归档与截图

- `make generate` exit0；generic iOS Release archive exit0；正常 Simulator Release build exit0。805个生产构建输入在归档前后及发布准备后摘要一致，聚合摘要 `4e8f0722bfc6499e69a484760c2dc9fafc01a882e6231cae4e1e88bdda768305`。文档和截图不参与生产编译。
- 完整真机包 `TiebaLite-0.2.0beta7-ios18-arm64-unsigned.ipa`：5,029,123 bytes，SHA256 `cb66f3c67e7ba39ad7103ac77a2347efe08ebf19708f2324b5529e39986c1042`。arm64、iPhoneOS、iOS18.0、iPhone/iPad、0.2.1/20、原bundle，140文件和132表情、图标及相册权限均在。ZIP CRC与逐文件内容/可执行权限匹配archive。Release隔离检查exit0，没有SF探针、Debug/UITESTING或本机源码路径。
- 主程序SHA256 `ae58161e701f20b44263c3c374dbe285e0785a0c3e461b3d02b57c236b072c97`，与用户实机接受的候选主程序一致；正式版仅增加版本元数据及发布文档。
- iPhone17Pro与iPadPro13M5原模拟器覆盖安装0.2.1/20；重新查询安装后容器，Documents/Application Support分别8/1个文件摘要一致，未卸载、未清数据或Keychain。初版校验脚本固定旧容器路径，安装后误报preflight文件变化，exit1；更正为安装后重新解析容器后exit0，没有恢复或修改该文件。
- 当前正常Live实际截图4张（iPhone吧首页、帖子中部、独立楼中楼及iPad吧首页），已逐张检查。README替换旧Beta1展示并更新功能、安装和验证范围。采集时关注吧首页网络加载失败，公开吧内页面及楼中楼可读；未据此改协议或声称完整实网验收。
- 证据在忽略目录 `Artifacts/Releases/v0.2.0beta7/`：archive/screenshot-live-build命令与日志、production-inputs.json、package-verification.json、screenshot-installation-proof.json、SHA256SUMS。在线发布与源回读待补。
