# 阶段 19：最终功能一致性、发布前检查与风险清单

本阶段不擅自添加缺失功能；先进行只读审计，再只修复明确 P0 缺口。建议 Sol Ultra 将审计分为独立只读工作流。

## 审计输入

- Android reference 固定 commit。
- `Specs/FEATURE_MATRIX.md`、API evidence、内容节点矩阵。
- 所有 ADR。
- 自动化 test plans。
- 最新 App build 与 Simulator 录屏。

## 并行只读审计

1. 功能矩阵与 route。
2. 推荐/关注吧/吧首页/帖子数据和状态。
3. 内容节点/图片。
4. iPhone/iPad 交互与动效。
5. 网络/session/隐私。
6. 测试、性能、可访问性。
7. 许可证、来源、品牌和发布说明。

主代理合并为 `Docs/Audits/FINAL_PARITY_AUDIT.md`，每项标：

- PASS
- PARTIAL
- FAIL
- OUT_OF_SCOPE
- UNKNOWN

不得把 OUT_OF_SCOPE 写成 PASS。

## 发布前检查

- Release 配置可构建；可在无真实 Team 的情况下完成 unsigned/generic archive 可行性检查，或记录签名阻塞。
- 无 Debug menu、fixture credential、测试开关误入 Release UI。
- 无密钥、Cookie、token、真实用户数据。
- Privacy/网络权限说明与实际一致。
- 第三方依赖许可证清单。
- Android 参考与 GPL 来源说明。
- App 名称、图标和文案不暗示百度官方授权。
- 崩溃/日志策略不收集敏感正文。
- README 包含构建、测试、限制和已知风险。

## 最终矩阵实跑

至少完整执行：

- iPhone 小/大尺寸。
- iPad 横/竖与分屏。
- 浅/深、大字体、Reduce Motion。
- Offline/slow/error/session expired。
- 推荐→帖子→媒体→返回。
- 关注吧→吧→帖子→返回。

记录真实 test command、xcresult 和手工证据路径。

## 修复权限

- 只修 P0/P1 明确问题。
- 任何架构级改动先写风险和最小方案。
- 不在最终阶段顺手改设计风格、升级依赖或加入动画。

## 交付

- `FINAL_PARITY_AUDIT.md`
- `RELEASE_PREFLIGHT.md`
- `KNOWN_LIMITATIONS.md`
- 更新 `README.md`
- 最终测试结果与 commit

完成后停止，不自动提交 App Store。
