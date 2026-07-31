# ADR-0004：唯一 PagerContainer

- 状态：Proposed
- 日期：2026-07-31
- 决策者：阶段 02 候选决策，待阶段 06 spike
- 关联阶段：02、06

## 背景

Forum tab 与 MediaViewer 都可能需要横向分页。SwiftUI 系统容器和 UIKit
包装各有生命周期、identity、系统返回手势与尺寸变化风险；静态分析不足以
证明哪一个满足仓库的全部交互约束。

## 必须满足的约束

- 仓库最终只有 `InteractionKit/PagerContainer` 一个生产 Pager。
- 页面使用稳定 PageID，index 不是身份。
- 交互完成前 source、target 和必要相邻页保持存活且背景不透明。
- 取消、反向、快速连续滑动、数据刷新、旋转和 iPad resize 后选择正确。
- push 栈左边缘系统返回优先，不使用私有手势 API。
- Feature 不添加自己的 DragGesture 或复制 Pager。

## 候选方案

### A：SwiftUI TabView + page style

- 优点：系统 SwiftUI 容器、代码量小、可访问性基础较好。
- 缺点：相邻生命周期、交互中 selection 时机和手势仲裁缺乏显式控制。
- 风险：刷新时 identity 偷换、取消时过早提交 selection、左边缘返回冲突。
- 验证方式：用稳定 ID、生命周期探针和 UI 可观察条件完成统一 spike。

### B：UIPageViewController 包装

- 优点：转场 delegate、source/target 生命周期和 completion 较明确。
- 缺点：HostingController 复用、SwiftUI identity、size transition 和
  accessibility 需要自行桥接。
- 风险：controller 累积、重复 completion、View 重建或状态串页。
- 验证方式：与 A 使用同一 scenario 和有界资源断言。

### C：自定义 SwiftUI DragGesture / 第三方 Pager

- 优点：表面上可完全控制参数。
- 缺点：违反唯一手势 owner 与依赖政策。
- 风险：系统 back、惯性、可访问性和生命周期都需重造。
- 验证方式：不进入 spike；除非 A/B 均有可复现平台阻塞并有新 ADR。

## 候选决策

A、B 进入阶段 06 隔离 spike；B 是当前首选但不因此自动胜出。两者必须实现
同一个与框架无关的契约：

```text
input: ordered stable PageID, committedSelection
internal: transitionToken, sourceID, targetID, frozen participant snapshot
output: selectionCommitted(PageID, transitionToken)
```

- pending target 只属于容器内部；取消不能发布业务 selection。
- 转场期间冻结参与页集合；数据更新在 completion 后按 PageID reconcile。
- 当前 ID 被删除时使用文档化 fallback：优先同序列下一存活 ID，否则前一
  ID，否则 empty；绝不让相同 index 指向另一 ID。
- View 可释放不等于 Feature Store 释放；父层按 PageID 持有页面业务状态。
- 远页可释放，controller/View 数量必须有界。
- 程序化选择遵守 Reduce Motion；交互转场不叠加自定义 Motion。
- 公开 API 无法保证左边缘系统返回时，push-hosted Pager 必须降级为显式
  tab/button 切换，不能使用私有 recognizer 关系。

## 为什么暂不接受某一实现

SwiftUI 候选不能因代码少直接胜出；UIKit 候选也不能凭经验假定生命周期
正确。相邻存活、取消/反向、ID reconcile、边缘返回、VoiceOver 和内存上界
都需要目标 Simulator 的运行证据。

## Spike 验收

- 快速左右交替 20 次、半途取消和反向滑动，最终 ID 与视觉页一致；
  每个 transition token 最多一次 completion。
- 手势中插入、删除、重排页面，不露白、不提前释放参与页。
- iPhone push 栈从左边缘拖动只触发系统 pop；非边缘横拖才可翻页。
- iPad 至少两个窗口宽度及旋转后 committed PageID 不变。
- 100 页往返后 controller/View 数量有界。
- loading/error 页参与滑动时 frame 和背景稳定。
- VoiceOver 可报告当前页/总页数并执行可访问分页动作。
- 测试不用 `sleep()`；使用 transition token、delegate probe 和 expectation。

## 迁移/退出成本

两候选只能存在于隔离 spike 目录。胜者进入唯一生产路径，败者完整删除。
Pager 的 PageID/selection 契约保持稳定，因此容器实现可替换而不改变
Feature State。

## 验收与回滚条件

任一候选不能以公开 API 满足边缘返回、ID reconcile、取消/反向或有界
生命周期即淘汰。同类缺陷两次最小修复仍失败时停止参数补丁，删除失败
spike，回到最近绿色候选并重做状态/生命周期设计。
