# Bug 修复：证据驱动的根因流程

把下面的 `[BUG DETAILS]` 替换为实际信息，或附上已填写的 `Specs/09_BUG_REPORT_TEMPLATE.md`。严格使用 `$ios-root-cause-debug` skill。不得扩大为重构任务。

## BUG DETAILS

```text
Bug ID/标题：
发生 commit：
最后已知正常 commit（若有）：
设备与系统：
窗口/方向：
外观/字体/Reduce Motion：
网络与 Session scenario：
复现步骤：
预期：
实际：
频率：
截图/录屏/日志：
```

## 强制流程

### 1. 冻结范围

- 读取 AGENTS、相关交互/状态规格和 ADR。
- `git status --short`，记录已有改动；不能覆盖用户未提交工作。
- 列出最多 5 个直接相关文件区域。
- 不顺手格式化、升级依赖或修其他问题。

### 2. 建立确定性复现

- 优先使用既有 fixture/LaunchScenario。
- GUI-only 问题使用 Simulator/Computer Use，按完全相同步骤至少复现 3 次。
- 保存失败前后的状态、route、稳定业务 ID、任务 ID、page/index、zoom、尺寸、安全区和动画 transaction。
- 无法复现时先增强诊断，不进行猜测式视觉修改。

### 3. 分类与证据

依次检查并排除：

1. 状态机不合法转换。
2. 请求取消/旧响应覆盖。
3. SwiftUI view identity/列表复用。
4. NavigationPath/route 重建。
5. Safe Area/overlay/z-order/keyboard。
6. 手势识别优先级和方向锁。
7. implicit animation/transaction。
8. UIKit coordinator/delegate/update 生命周期。
9. 图片请求、cache、decode 和资源释放。
10. 真实 API 边界数据。

输出一条主要根因陈述：

```text
当 [条件] 时，[具体状态/对象] 因 [机制] 进入 [错误状态]，从而产生 [用户现象]。
证据是 [日志/测试/代码路径]。
```

不要只列十个“可能原因”。

### 4. 先写失败回归

- 优先写最接近根因的状态/组件测试。
- 用户可见流程再加 UI test。
- 测试在修复前必须真实失败，并记录失败结果。
- 无法自动化时，写确定性手工回归脚本与可观察断言；解释限制。

### 5. 最小修复

- 一次只验证一个根因。
- 修复状态归属、身份、生命周期、取消或布局契约，不调一串随机参数。
- 禁止 asyncAfter、`.id(UUID())`、全屏透明遮罩、全局禁动画、无限 zIndex、重建根导航、清缓存假修复。
- 如果第一个假设被证伪，回退该尝试后再进入下一个假设。

### 6. 验证

- 回归测试由红变绿。
- 运行受影响组件的全部状态/交互测试。
- 重跑原复现 10 次或适合该问题的稳定次数。
- 验证反向/邻近场景：返回、旋转、iPad resize、深色、大字体、Reduce Motion、慢网、取消。
- 运行 `make quality-fast`，阶段性重要修复运行 `make quality`。

### 7. 停止规则

同一 Bug 连续两个修复尝试仍未通过：

- 停止堆补丁。
- 回退失败尝试。
- 输出组件状态、身份、生命周期重设计方案和迁移测试。
- 不开始第三个视觉补丁。

## 完成报告

- 确定根因及证据。
- 修复前失败测试。
- 最小代码变化。
- 修复后测试/复现结果。
- 未覆盖风险。
- 是否新增动画、手势、overlay、依赖。
