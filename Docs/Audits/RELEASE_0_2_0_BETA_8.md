# v0.2.0beta8 发布记录

状态：READY_TO_PUBLISH，2026-10-28。用户明确授权提交、推送与发布新IPA；完成线上回读后另记最终回执。

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
- 线上IPA、源与机器人提交在发布后核验；未在物理设备执行SideStore签名、关联及Update按钮流程。无新增手势、动画、overlay、依赖，不扩张发送协议。
