# ADR-0004：唯一 PagerContainer

- 状态：Accepted（Open-Source Beta interaction foundation；Debug candidate）
- 日期：2026-07-31
- 最终裁决：2026-08-02
- 决策者：阶段 02 候选决策；阶段 06 Open-Source Beta 收口
- 关联阶段：02、06、09

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
- 阶段 06C-B Debug 候选保留 UIKit 的系统 distance/velocity 组合裁决，
  因公开 API 未承诺固定阈值而不自行覆盖。候选以被动 pan trace 在固定
  runtime 分别记录/验证 49%/51% 低速距离分支和同距离 slow/fast velocity
  分支；callback 还必须与当前 token、previous source、visible target 及
  ended terminal 匹配。cancelled/failed/stale/duplicate 一律不能提交。
- 阶段 06C-R 将 `didFinishAnimating` delegate evidence、Pager pan terminal
  和 Media ownership terminal 收入同一个 `@MainActor` 三方 rendezvous。
  context 固定 source/target/direction、外部 selection generation、controller
  installation generation、previous/visible host identity 和 ownership
  session/generation；三种 evidence 任意顺序到达都只解析一次。
  ownership `active` 只能 pending，只有 `ended(owner: pager)` 可参与 commit；
  cancelled/failed/invalidated、`mediaPan` owner 或 Pager 非 ended terminal
  均解析为 cancelled/invalidated，不发布 selection。
- delegate callback 采用 validate-before-consume：先 peek context 并验证
  PageID、host identity、direction 和全部 generation，再记录 evidence。
  错误 previous/visible snapshot、stale installation 或外部 selection 变化只写
  ignored reason，不清 context、不增加 resolved count，也不阻断后续正确
  callback。最终 join 再核对 live visible host，已 resolution 的迟到 callback
  幂等忽略。UIKit callback 不携带 token 的平台限制仍要求最低部署 runtime
  矩阵复验；Debug adapter 不因此推定为生产可用。
- 外部 selection generation 是 live `Binding`，交互中变化只记录 supersession，
  不立即 resolve、换 child 或 trim cache。D/P/O terminal 齐全后旧 transition
  才以 `invalidated` 单次收口并应用最新 selection；away→back 到原 source 也由
  generation 前进识别。Pager recognizer/controller lifecycle 替换会显式失效
  context，committed host 同时核对 PageID 与对象 identity。
- settled controller admission 只允许当前页及相邻页（≤3），transition
  admission 只允许冻结参与页（≤4）。data source 只接受当前 installed
  controller 及 cache 中同一 host instance；stale/evicted host 不能递归复活。
- 纳入 P4 retained-state 矩阵的页面通过稳定 content generation 更新同一
  host。generation 不变或倒退时不重建昂贵 root；刷新/旋转/尺寸投影不等于
  eviction。dismantle 取消 deferred commit，断开 delegate/dataSource/pan
  observer，移除 Pager hosting children 并换入不透明 teardown sentinel 后
  才算完成 UIKit owner 拆卸；hosting child/coordinator 必须可释放。
- 程序化选择遵守 Reduce Motion；交互转场不叠加自定义 Motion。
- 公开 API 无法保证左边缘系统返回时，push-hosted Pager 必须降级为显式
  tab/button 切换，不能使用私有 recognizer 关系。

## 阶段 06 初期为何暂不接受某一实现

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

## 阶段 06 运行结论（历史出口）

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

## 阶段 06B 收口结论（历史出口）

阶段 06B 关闭了两个可复现的 coordinator 根因，但仍不足以批准生产实现：

- deferred selection commit 现在带单调 generation 和 expected-source；每次
  synchronize、transition resolve 与 dismantle 都先取消旧提交。修复前
  `20260801-120058-40012-unit.xcresult` 可稳定让旧 fallback 覆盖较新的
  外部 selection；修复后完整 Unit 通过。
- Lab 的横竖屏布局改为同一子树上的 `AnyLayout`，不再用条件分支重建
  representable；Debug-only 单调 coordinator sequence 先在
  `20260801-120538-43562-ui-interaction.xcresult` 证明旋转发生重建，修复后
  双向旋转与翻页在 `20260801-123531-60392-ui-interaction.xcresult` 保持
  同一 sequence。
- 34% 页面宽度拖动取消在真实 iPhone Simulator 连续执行 5 次，逐次断言
  `idle-cancelled`、业务 ID 和 completion count；20 次交替切页也通过。
  这未达到严格半程，且仍是逐次 settled 操作，不等同于无等待 burst 或
  同一触摸反向轨迹。
- 100 页 controller cache 仍有界，Zoom coordinator/scroll weak release
  新增实测；但 Pager child hosting-controller deinit、真实 non-empty refresh
  保留内容、loading/failure 几何、纵向滚动夹带水平抖动、非默认 PageID 的
  regular/compact 重建与真实 split divider 仍缺运行证据。
- 本机唯一可用 runtime 是 iOS 26.5；iOS 18.x 与 VoiceOver 未验证。

因此在 06B 任务出口时 ADR 状态继续是
`Proposed（阶段 06 Spike Partial，仅 Debug）`；06B 不批准迁移、改名或复制
Debug Pager。该历史状态已由下方 Open-Source Beta 最终裁决取代。

## 阶段 06C-R rendezvous 修复结论（历史出口）

阶段 06C-R 只修复由三个确定性红测证明的共享终态协调根因：旧 ownership
授权把 `active` 当作可 resolve，且 Pager delegate 在完整身份验证前已消费
callback context。Debug 候选现在使用上述三方状态机，允许的结果仅为
`pending`、`committed`、`cancelled`、`invalidated`；一次 transition 最多发布
一次 side effect。外部 selection generation 前进会使旧 transition 失效，
不会出现旧选择短暂提交后再回退。

扩展 review 回归先以 14 个逻辑测试、21 次执行稳定暴露 7 个失败，再全部
转绿；最终复审又以 O→generation advance→D→P 的新回归稳定复现
1 个失败，join-time 当前身份复核后转绿。包含原三红的扩大定向套件
连续三次均为 31 个逻辑测试、39 次执行、0 失败。
完整 Unit 为 186 个逻辑测试、204 次执行、0 失败。该修复没有重新设计阶段
06C-A 已关闭的 zoom、rotation 或 chrome，也没有创建生产 Pager/MediaViewer。
06C-R 任务出口时 ADR 仍是 `Proposed（阶段 06 Spike Partial，仅 Debug）`；
该历史状态随后由下方 Open-Source Beta 最终裁决取代。

## Open-Source Beta 最终裁决

选择 B（唯一 `UIPageViewController` wrapper）作为阶段 09 可继续生产化的
interaction foundation，并将阶段 06 标记为
`PHASE_06_INTERACTION_SPIKES = SPIKE_ACCEPTED`。这项接受只覆盖架构边界、
PageID/selection 合同、D/P/O terminal rendezvous、P3/P4/P5 的当前自动化和
iOS 26.5 Simulator 证据；Debug `InteractionLab` 继续被 Release 排除，不能
直接改名或复制为生产组件。

- P3：49%/51% 各 5 次、独立 velocity 分支、20 次交替 rapid-serial swipe、
  左右边界各 20 次、反向 state-machine sequence 与纵向 jitter 通过。
- P4：retained refresh/loading/failure、initial loading/failure/empty、partial
  drag 中 5 次 refresh、opaque full-bounds 和 stale generation 通过。
- P5：缓存内 identity、eviction 后 weak release、100 PageID 的 cache/创建次数
  上界、无 orphan child 和 dismantle 释放通过。
- 06C-R：三个原始 rendezvous/callback 回归及 generation/host identity 扩展
  回归通过。

`PHASE_06C_C = DEFERRED_POST_BETA`；
`PHASE_09_PREREQUISITES_SATISFIED`，但阶段 09 保持 `NOT_STARTED`，生产实现
仍需新的明确任务。

Known Limitations 不再阻塞阶段 09：iOS 18.x/真机、真机 VoiceOver、真实同
触摸反向录屏、极端图片资源压力，以及 UIKit 完全同签名且不携带 token 的
理论迟到 callback。现有 generation/host/direction/visible/ownership 守卫覆盖
所有可观测身份；完全不可区分的排列保留到发布前平台矩阵。

## 迁移/退出成本

两候选只能存在于隔离 spike 目录。胜者进入唯一生产路径，败者完整删除。
Pager 的 PageID/selection 契约保持稳定，因此容器实现可替换而不改变
Feature State。

## 验收与回滚条件

任一候选不能以公开 API 满足边缘返回、ID reconcile、取消/反向或有界
生命周期即淘汰。同类缺陷两次最小修复仍失败时停止参数补丁，删除失败
spike，回到最近绿色候选并重做状态/生命周期设计。
