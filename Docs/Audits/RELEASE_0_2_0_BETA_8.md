# v0.2.0beta8 发布记录

状态：PUBLISHED / VERIFIED，2026-10-28。用户明确授权提交、推送与发布新IPA；发布、附件回下载和SideStore源更新校验已完成。

## 范围与来源

- 基于main `a5ad3eb98c4b78ac0aa7cf17635e480d526824ab`提交通知整页上下文修复，见[修复审计](NOTIFICATION_THREAD_CONTEXT_FIX_2026_10_28.md)。不包含用户无关未跟踪提示词、技能配置和缓存。
- 用户已明确批准登记3个冻结文件中的只读差异；23项原始基线摘要与断言保留，发送、回复、上传和成功回显关键函数不变。没有真实贴吧写操作。
- 发布标签v0.2.0beta8；IPA真实版本0.2.2/21，Bundle ID仍为dev.local.tiebaliteios。沿用未签名ARM64真机IPA和原SideStore源，每次实际营销版本递增。
- README只更新版本/链接；保持2026-10-23截图及其真实0.2.1/20采集说明，不将发布说明放入README。

## 构建与验证

证据位于忽略目录 `Artifacts/Releases/v0.2.0beta8/`，各命令原始日志和exitcode保留。用户此前已看到的通知修复Unit/UI证据位于 `Artifacts/VisualReview/NotificationThread-20261028/`。

| 检查 | 结果 |
| --- | --- |
| 49项相关Unit及iPhone/iPad通知UI | 复用同一生产代码的已通过结果，包含冷/热缓存、晚页、取消/重试、写后回显、通知定位及回主楼 |
| XcodeGen+原SwiftPM锁生成 | PASS，使用未改变的已提交Proto产物 |
| generic iOS Release archive | PASS，exit0，Xcode26.6；原始命令见archive-command.json |
| 设备Release隔离 | PASS；仅将原检查脚本副本指向实际archive目录，检查规则未降低 |
| IPA包检查 | PASS，140文件逐项匹配archive，ZIP CRC/执行位、资源/132张表情、图标/相册权限、ARM64、iPhoneOS、iOS18+、iPhone/iPad均核对 |
| 生产输入 | 806项，归档前后SHA不变，清单摘要d331c7fcfa42221b769339f79b54d25f82b8e57f13d36e64e80e477cb7f862a7 |
| SwiftLint直接检查 | PASS，645文件零违规 |
| 发送冻结 / secret-scan / diff | PASS，原始摘要保留，23项冻结检查通过 |
| SideStore本地结构及回归 | PASS，--check及7项Python测试 |
| make lint | FAIL，tool-versions调用既有protoc35.1缺libabsl_die_if_null.2601.0.0.dylib；上列SwiftLint及冻结检查分别直接执行 |
| make quality-fast / make quality | FAIL，instructions扫描既有beta5归档AGENTS链长度超限；未改门禁，不称全仓绿色 |

IPA：`TiebaLite-0.2.0beta8-ios18-arm64-unsigned.ipa`，5,050,044 bytes，SHA256 `68d8ba63f333378216ec651b31ddc06480aae37cf4c7e42a34675b2eaf3eb298`。主程序SHA256 `7113db53facecc19692b0e4063b20d24b640d2d4df69f95f55854d50b7a63fe8`。无Debug/UITESTING、fixture、测试探针、本机绝对路径或用户数据。

## 发布边界

- GitHub连接器没有Release/二进制附件发布工具；gh未登录。jshook尝试连接现有Chrome返回DevToolsActivePort缺失，未改浏览器权限或读取凭据；使用已登录Chrome原生界面完成发布。
- 定稿Release正文并上传完整IPA+SHA256SUMS后再发布Pre-release；源脚本将正文也作为不可变版本元数据，发布后不随意修改。
- 线上IPA、源与机器人提交已在发布后核验；未在物理设备执行SideStore签名、关联及Update按钮流程。无新增手势、动画、overlay、依赖，不扩张发送协议。


## 公开发布回执

- 修复与发布准备提交 `311dfa407afbcd0a6c6083c794b30c935aad0212`，注释标签 `v0.2.0beta8`，通过SSH原子推送到main及远端tag。806项生产构建输入逐一匹配该提交，见committed-source-proof.json；标签不随后续文档移动。
- [GitHub Release](https://github.com/othbradar/tiebalite-ios/releases/tag/v0.2.0beta8)于2026-10-28 13:03:23 UTC公开，Release ID426675896，draft=false、prerelease=true。发布页确认标签、提交和正文；附件均为uploaded，发布说明规范化换行后与本地定稿一致。
- 线上IPA和SHA256SUMS重新下载后与本地逐字节一致。IPA大小5,050,044 bytes、SHA256如上，包内真实版本0.2.2/21，ZIP CRC通过。SHA256SUMS大小112 bytes，SHA256 `4d6adf7621f724fb464cabf58b51d9f38383a3cc42e78bc5f6b97ab6639ba14b`。GitHub附件digest与本地计算一致，证据为published-release.json、published-asset-verification.json及downloaded/。
- Release触发的[SideStore任务40692991742](https://github.com/othbradar/tiebalite-ios/actions/runs/40692991742)已成功，机器人提交 `5ddd529`仅更新sidestore/source.json；本地fetch后fast-forward同步，未重写历史。
- [原线上源](https://raw.githubusercontent.com/othbradar/tiebalite-ios/main/sidestore/source.json)回读与本地相同。首项0.2.2/21的下载URL、大小、SHA256、系统要求取自公开IPA，保留0.2.1/20和0.2.0/19；顶层兼容字段同步。
- 使用公开Release JSON及回下载IPA运行源生成两次均exit0、两次git diff --exit-code均0；--check与7项Python回归再次通过。source-verification.json记录结果。未亲测物理设备SideStore更新提示或签名。
- 首次发布表单在推送前已缓存旧标签列表，刷新后正确选择beta8；macOS附件对话框首次粘贴路径未生效，改用AX setValue明确路径并核对两个选中文件后上传。未上传日志、archive、私人资料或不相关文件。
- 本轮所有任务改动已获用户提交/推送授权；无关未跟踪提示词和缓存继续保留。无发送协议修改、真实贴吧写入、清数据、卸载或新阶段工作。
