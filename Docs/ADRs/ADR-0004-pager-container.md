# ADR-0004：唯一 PagerContainer

- 状态：Proposed（阶段 06 Spike Partial，仅 Debug）
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

## 阶段 06 运行结论

阶段 06 比较了 A/B，但没有批准生产实现：

- A 的 Debug `TabView(.page)` 候选只在 selection 已提交后才能触发数据
  变更，公开 API 不能给出转场 begin/cancel token、冻结参与页或取消回调。
  统一 fixture 的运行证据记录在
  `Artifacts/TestResults/20260731-170157-44937-ui-interaction.xcresult`；
  候选源码随后完整删除。
- B 的 `UIPageViewController` 候选能以 delegate 区分完成/取消，并通过
  稳定 PageID、pending order、单调 token、有界 hosting-controller
  cache 和显式 dismantle 实现契约。它只保留在
  `Sources/InteractionKit/InteractionLab/Debug*.swift`，Release
  SwiftFileList 明确排除。
- 自动化覆盖逐次等待完成的 20 次交替翻页、短距离慢拖取消尝试、状态机
  取消、转场中插入/删除/重排、refresh Bool/final-idle 探针、系统边缘
  返回、旋转、Reduce Motion、100 页有界缓存及 teardown；没有把顺序
  翻页写成快速 burst，也没有把短拖或 Bool 探针写成完整的半程取消/
  反向或真实刷新保留内容矩阵。
  人工检查另外发现并修复了横屏 Lab 单列布局把 Pager 压缩为近空视口的
  问题；回归以实测 viewport height 验证。
- 只读复审发现两个仍未关闭的 coordinator 风险：延迟 selection commit
  仅检查绑定值不同，缺少同步代次/expected-source，可能覆盖同一 turn
  内较新的外部 selection；横竖屏用条件分支在 `HStack`/`VStack` 之间
  搬动 representable，viewport 回归不能证明同一 coordinator 与相邻页
  生命周期连续。这两项均没有自动化运行证据，因此 B 不能晋升生产。
- Computer Use 无法向 Simulator 注入可靠的触摸拖拽，也未能操作真实
  iPad split-view divider；本机也只有 iOS 26.5 runtime。因此手工矩阵未
  完整，整体判定为 `SPIKE_PARTIAL`，不能命名或迁移为生产
  `PagerContainer`，后续 Feature 禁止复制。

若后续补齐 stale-commit、旋转 lifecycle、真实触摸、VoiceOver 和 split
resize 后 B 仍失败，回滚到显式前后按钮/Tab 的非交互降级；不得恢复 A
的提交后钩子或引入私有手势关系。

## 迁移/退出成本

两候选只能存在于隔离 spike 目录。胜者进入唯一生产路径，败者完整删除。
Pager 的 PageID/selection 契约保持稳定，因此容器实现可替换而不改变
Feature State。

## 验收与回滚条件

任一候选不能以公开 API 满足边缘返回、ID reconcile、取消/反向或有界
生命周期即淘汰。同类缺陷两次最小修复仍失败时停止参数补丁，删除失败
spike，回到最近绿色候选并重做状态/生命周期设计。
