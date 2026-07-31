# ADR-0009：测试分层与 LaunchScenario

- 状态：Accepted
- 日期：2026-07-31
- 决策者：阶段 02 架构决策
- 关联阶段：02、03、04 及所有实现阶段

## 背景

自动化不得依赖实时贴吧网络、真实账号、sleep 或随机时序。状态、mapper、
Repository、Session crash recovery、Pager/Media 交互和 iPhone/iPad 容器
需要不同测试层，但必须共享同一 fixture/scenario 语义。

当前没有工程或 test plan。`scripts/run_xcodebuild.sh` 只有 `tests` mode
读取 `TEST_PLAN`，`unit`/`ui-smoke` 仍只按 target 选择；阶段 03 必须消除
该差异。

## 必须满足的约束

- 纯状态、mapper、Repository 和并发优先 Swift Testing。
- 系统生命周期、UI、性能、附件使用 XCTest/XCUITest。
- 每个测试拥有独立 HTTP/session/cache，不全局注册 URLProtocol。
- clock、ID、请求完成顺序和错误均可控。
- Release 不可到达 TestSupport 或 LaunchScenario factory。
- xcresult/日志/fixture 不含 credential 或私密正文。

## 候选方案

### A：分层 deterministic tests + versioned launch scenarios

- 优点：状态与 UI 都使用固定输入，可重放失败。
- 缺点：需要维护 fixture schema、scenario registry 和 test plan。
- 风险：scenario 与生产 composition root 分叉。
- 验证方式：同一 domain fixture 同时用于 mapper/state/UI 断言。

### B：主要依赖 UI tests 和真实网络

- 优点：表面接近生产环境。
- 缺点：慢、易抖动、无法覆盖精确竞态和 malformed payload。
- 风险：账号/网络变化导致假失败或泄密。
- 验证方式：不满足仓库确定性要求。

### C：大量 snapshot/sleep 测试

- 优点：编写初期直观。
- 缺点：掩盖状态和时序根因。
- 风险：系统/字体变化造成噪声，等待时间无法证明完成条件。
- 验证方式：拒绝使用 sleep 作为同步。

## 决策

选择 A。

### 测试层

| 层 | 工具 | 覆盖 | 禁止 |
|---|---|---|---|
| Domain/State | Swift Testing | reducer、merge、cursor、stale、error | 网络、真实 clock |
| Mapper/Repository | Swift Testing + MockHTTPClient/专属 URLProtocol | 编码、fixture、取消、反向完成 | 全局 URLProtocol |
| Session/Cache | Swift Testing/XCTest | actor reentrancy、lease、journal crash point | raw credential fixture |
| UI component | XCTest host | layout、Pager/Media lifecycle | sleep、实时网络 |
| UI flow | XCUITest | launch scenario、导航、a11y、系统容器 | prod endpoint |
| 性能 | XCTest metrics/signpost | 滚动、decode、内存/任务上界 | 用性能测试代替正确性 |

异步竞态使用 controlled continuation、barrier、test clock 与显式 expectation。
每个 effect completion 可由测试按任意顺序释放；不得使用 wall-clock 延迟碰运气。

### Fixture

- binary/JSON fixture 固定、脱敏并带来源记录与 SHA-256；
- mapper expected domain 与 raw fixture 分离；
- 成功、空、畸形、错误、取消、过期、重复页、未知字段成套；
- 真实账号响应默认不落盘；
- 任何 fixture 更新必须同时更新 evidence 和 mapper tests。

### LaunchScenario

UITesting build config 注册版本化白名单 ID，例如：

```text
v1.recommendations.success
v1.recommendations.next-page-failure
v1.session.expired
v1.media.three-items
```

启动参数只传 scenario ID 和非敏感显示开关；scenario factory 从已提交 fixture
构造完整 dependency graph。未知 ID fail-fast 并输出安全错误，不回退 live
网络。`TestSupport/LaunchScenarios/**` 只编入 App 的 UITesting 配置：
普通 Debug/Release 以配置级 source exclusion 排除，并以条件编译作第二层
防御。`TiebaLiteTests` 自己编译所需 TestSupport 源；`TiebaLiteUITests` 只传
scenario ID，不链接 factory。Release 结构检查必须证明不可达。

### Test plan 与命令

提交一个 canonical test plan，显式声明：

- unit、integration、UI smoke 和完整 UI suites 的 target/test membership；
- 各测试配置的 arguments、environment 和 diagnostics 选项；
- 深色、大字体、Reduce Motion 等可控测试配置；
- 是否并行及不可并行的 Session suite。

test plan 不声明 Simulator destination。`scripts/run_xcodebuild.sh` 与
`scripts/project.env` 选择 iPhone/iPad destination；阶段 03 门禁必须验证
每个 Make mode 的 test-plan configuration、target selection 和 runner
destination 映射一致。

阶段 03 必须让 `unit`、`ui-smoke`、`tests` 三个脚本 mode 与 canonical test
plan/target selection 一致，并保留 `-only-testing` 的快速子集能力。阶段出口
另跑 iPad build/UI 矩阵，不把 iPhone smoke 冒充 iPad 验证。

## 为什么不是其他方案

B 无法稳定证明 malformed/stale/crash point；C 把等待时间当作行为证据。
系统测试仍保留，但只消费 deterministic scenario。

## 迁移/退出成本

LaunchScenario 通过协议构造依赖，UI 框架变化不影响 fixture/state tests。
fixture version 可并存并显式迁移。若 Swift Testing 在某类系统生命周期上
受限，该测试可移至 XCTest，但行为和 fixture 不变。

## 验收与回滚条件

- 同一测试连续运行结果一致，不依赖联网/当前时间/随机 UUID。
- 反向完成、取消、旧 session、重复 cursor 与 crash midpoint 可控。
- 未知 scenario fail-fast；Release 无 TestSupport symbol/fixture。
- UI test 使用 accessibility identifier 和 expectation，无 `sleep()`。
- xcresult 附件只包含固定脱敏 fixture。
- Make mode 与 test plan 选择一致。

任何新测试需要真实网络、真实凭据或延迟才能通过，回滚该测试和实现到最近
绿色状态，先补可控 seam。
