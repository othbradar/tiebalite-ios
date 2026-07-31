# 依赖与工具政策

状态：`APPROVED`

## 原则

1. 先证明系统能力缺口，再评估生产依赖。
2. “预批准”不等于“已引入”或“任意版本可升级”。
3. production、build-time、development、test-only 分开审计。
4. 新增/升级依赖必须是独立任务，不夹带在 Feature diff。
5. 许可证、隐私、Swift 6、体积、维护与退出成本必须同时可接受。
6. Android reference 的依赖和许可证不会自动传递为 iOS 批准。

## 当前分类

| 依赖/工具 | 类别 | 状态 | 使用边界 |
|---|---|---|---|
| Apple SDK/Foundation/SwiftUI/UIKit/ImageIO/OSLog | 系统 | 可用 | 遵守 actor/隐私/平台契约 |
| SwiftProtobuf | production/build | 预批准、尚未引入 | 阶段 07 exact pin；仅 Generated/Core mapper |
| XcodeGen | development/build generation | 已安装 | `project.yml` 唯一真相，不进 App |
| SwiftLint | development quality | 已安装 | strict lint；版本差异阻断 |
| xcbeautify | development output | 已安装、可选 | 只美化输出，缺失不得改变结果 |
| ripgrep/Python/shell scripts | development checks | 已有 | 不进 App bundle |
| TestSupport fake/fixture helper | test-only | 未来建立 | Release 不可达 |

当前没有任何第三方 production package 实际写入工程。

## 明确未批准

- TCA、RxSwift、CombineExt 或其他状态框架；
- Alamofire 或其他网络框架；
- Nuke、Kingfisher 或其他图片/缓存框架；
- Realm、SQLite wrapper 或其他数据库框架；
- 第三方 Pager、MediaViewer、动画、analytics、crash/remote logging SDK；
- 同一职责的两个库。

这些不是永久禁止，但只有系统方案在量化验收中失败且新 ADR 通过后才能加入。

## 引入检查表

每个候选必须记录：

| 维度 | 必需证据 |
|---|---|
| 用户/架构缺口 | 哪个已批准行为系统方案无法满足 |
| 候选比较 | 至少系统方案、候选库和不实现 |
| 版本 | exact version、checksum、canonical lock、升级策略 |
| 来源 | 官方仓库、release/tag、维护活跃度 |
| 许可证 | SPDX、LICENSE、NOTICE、传递依赖、分发义务 |
| 平台 | iOS 18、Xcode 26、Swift 6 Complete concurrency |
| 并发 | Sendable/actor 模型、无未经批准 unchecked |
| 隐私/网络 | 数据字段、上传、Cookie/cache、关闭方式 |
| 体积/性能 | binary/launch/memory 基线与增量 |
| 测试性 | fake/fixture、失败/取消/时序 seam |
| 退出成本 | protocol boundary、移除步骤、数据迁移 |
| Owner | 唯一模块与升级负责人 |

任一项 UNKNOWN 时 ADR 维持 Proposed，生产 target 不得引用。

## SwiftProtobuf 专项

阶段 07 引入前必须同时满足：

- exact SwiftPM version，并提交 canonical
  `Config/SwiftPM/Package.resolved`；生成工程中的 lock 只由生成脚本
  materialize，resolve 后必须逐字节回查 canonical lock；
- generator 与 runtime 版本配套；
- P0 最小 schema import graph、来源 manifest、hash；
- Android schema 复制/clean-room 路径的权利决定；
- optional presence、unknown tag/raw value、round-trip 和 malformed tests；
- GeneratedProtobuf target 与 UI import 禁止检查；
- generated output 可确定性重建。

SwiftProtobuf 自身许可证通过不能解决输入 schema 的 GPL/上游来源风险。

## 开发工具固定

`Brewfile` 仅声明安装，不是 lock。阶段 03 增加版本清单并由 doctor 检查：

- Xcode/XcodeGen/SwiftLint exact mismatch：FAIL；
- Swift language/deployment/strict concurrency 由 project.yml 显式固定；
- xcbeautify 缺失/版本差异：WARN，原始 xcodebuild 结果仍是权威；
- 工具升级在独立任务更新版本、环境审计和全部质量门禁；
- 不为版本固定额外引入 Mint/mise 等管理器，除非新 ADR 证明需要。

当前已观察基线：

- Xcode 26.6 / Swift 6.3.3；
- XcodeGen 2.45.4；
- SwiftLint 0.65.0；
- xcbeautify 3.2.1。

## 更新与回滚

依赖新增/升级的独立 diff 必须：

1. 更新 ADR、版本锁、license/notice inventory。
2. 运行 deterministic generation、lint/build/unit/UI/iPad gate。
3. 记录 binary size、launch/performance 与 privacy 差异。
4. `git diff --check`，并确认 canonical lock 只含本任务预期变化，生成工程
   lock 与之逐字节一致。

失败时回退依赖和 lock 到最近绿色版本，不通过降低测试/并发设置或保留两套
实现过渡。删除依赖前先证明数据格式/缓存可迁移或可安全清理。
