# 交互契约

## 导航

- iPhone：每个主 Tab 保留独立 `NavigationStack` path。
- iPad：优先 `NavigationSplitView`，选择吧/主题时保留侧栏状态；窄宽度自动折叠为栈。
- 系统返回手势必须可用，不用自定义横滑覆盖。
- 重复点击当前 Tab：只有在产品规格明确时才滚到顶部；不得意外重建状态。
- 深链和恢复必须通过 route 进入，不直接操纵 View 层 Bool。

## 列表

- 首次加载显示骨架/统一加载状态，背景与最终页面一致。
- 刷新时保留内容和滚动位置；完成后在合理情况下保持锚点。
- 分页触发有防抖/防重，接近底部触发一次，不由多个 cell 同时发起。
- 下一页错误显示尾部重试，不覆盖整页。
- 返回列表恢复选中主题附近位置，不出现跳顶。
- 主题 ID 重复时去重但不打乱服务器顺序。

## Pager

- 仅 `InteractionKit/PagerContainer` 可处理横向页面滑动。
- 容器、当前页、相邻页背景均不透明且使用语义背景色。
- 交互转场未完成前不得移除参与转场的页面。
- 数据刷新不得把当前页面 ID 临时替换为空。
- 快速左右反复滑、半途取消、方向反转、旋转、iPad resize 后索引必须正确。
- 阶段 06 Debug UIKit 候选不复制 UIKit 未公开的 distance/velocity 组合
  算法；系统 `UIPageViewController` 的 `transitionCompleted` 是一次正常结束
  手势是否完成视觉转场的裁决。候选必须分别记录页面宽度归一化的终点/峰值
  距离、release velocity、pan terminal、source/target/token、previous/visible
  PageID，并在目标 Simulator 独立表征 49%/51% 低速输入与同距离慢/快输入。
- 业务 selection 仅在 callback 属于当前 token、previous source 与 visible
  target 一致且 pan 正常 ended 时采用系统完成结果；`cancelled`、`failed`、
  stale/duplicate/source mismatch 一律取消。同一触摸反向只累计在同一个
  input trace 中，不得创建第二个 transition；确定性 trace 测试和真实
  recognizer 诊断必须共用同一状态机，不能用独立纯函数冒充 runtime 手势。
- `didFinishAnimating` delegate evidence、Pager pan terminal 与 Media
  ownership terminal 必须按 transition token/input sequence、外部 selection
  generation 和 ownership session/generation 做三方 rendezvous；三者以任意
  顺序到达都只能解析一次。ownership `active` 只能保持 `pending`；只有固定
  owner 为 Pager 且已 `ended`，Pager terminal 也为正常 `ended`，delegate
  evidence 完全匹配时才可提交。ownership/Pager terminal 的 cancelled、failed、
  invalidated，或固定 owner 为 `mediaPan`，均不得提交。
- 最终 join 不得盲信已缓存的 ownership terminal；必须将其 session ID、
  generation、source、owner 和 Pager coordinator identity 与当前 ownership
  controller 重新核对。即使 `ended(G)` 先到，后续 generation 前进也必须
  使旧证据 `invalidated`，不得提交。
- Pager delegate callback 必须先 peek context，再验证 transition generation、
  source/target PageID、previous/visible host identity、direction、外部 selection
  generation 与 controller installation generation，最后才记录 evidence。
  无效、stale 或重复 callback 只写 Debug 诊断，不消费 context、不增加 resolved
  count、不改变 selection/destination，后续正确 callback 仍可完成同一 transition。
  最终 join 前还必须重新核对实际 visible host；resolution 后的迟到 callback
  幂等忽略，不得产生先提交再撤销的选择抖动。
- 外部 selection/generation 在交互中变化时只把旧 transition 标记为
  superseded；不得在 Pager/ownership 仍 active 时换 child、驱逐 source/target
  或发布旧 selection。D/P/O terminal evidence 齐全后才取消旧 transition 并
  一次性应用最新外部 selection；generation 必须从 live MainActor binding
  读取，不能依赖尚未执行的 representable update snapshot。
- Pager 页内纵向滚动夹带水平抖动时，不得启动或提交横向
  翻页，纵向内容仍必须可滚动。
- `loaded` 进入 `refreshing`、`loadingNextPage` 或
  `refreshFailure` 时保留原 PageID、原内容和 child controller；
  `initialLoading`、`initialFailure`、`empty` 仍须以不透明 root 完整覆盖
  Pager bounds。旧 generation 不得覆盖较新状态，状态层不得吞掉无关点击。
- settled cache 仅保留当前页及约定相邻页（最多 3 个 controller）；交互期间
  仅保留冻结参与页（最多 4 个）。状态刷新、旋转和 regular/compact 投影
  不是驱逐，不得重建当前 child；正式离开缓存窗口后允许释放并以新
  instance sequence 重建。stale controller 不得重新进入 data source 路由。
- 由父层异步状态驱动且纳入 P4 retained-state 矩阵的 Pager 页面必须提供
  稳定 content generation；generation 未变化或倒退时不得重建昂贵
  SwiftUI root，前进时只更新同一 hosting controller 的 root。
  dismantle 必须取消 deferred commit、断开 delegate/dataSource/observer，
  移除全部 Pager hosting children，并以不透明 teardown sentinel 满足 UIKit
  的非空约束，随后允许 coordinator/hosting child 释放。
- Pager pan recognizer 或 controller installation 被替换时必须显式 lifecycle
  invalidate，不能留下等待旧 input 的 context；显示 committed PageID 时还必须
  匹配当前缓存 host 对象，不能仅因 PageID 相同接受 stale controller。
- 左边缘系统返回与内部横滑冲突时，系统返回优先，具体判定写入组件 ADR。

### 阶段 06 证据范围

`PHASE_06_INTERACTION_SPIKES = SPIKE_ACCEPTED` 采用个人开源 Beta 范围：当前
确定性状态机与 iOS 26.5 Simulator 的 iPhone/iPad 证据足以解除阶段 09
前置门禁，但不降低本节任何行为契约。iOS 18.x/真机、真机 VoiceOver、
真实同触摸反向录屏、极端图片资源压力与公开 UIKit callback 完全不可区分的
理论排列标记为 `DEFERRED_POST_BETA`；Debug InteractionLab 仍不得作为生产
Pager/MediaViewer 发布。

## MediaViewer

- 单击切换 chrome；双击按点击位置缩放；捏合缩放；缩放后平移。
- `zoomScale > minimumZoomScale` 时，横向手势优先用于图片平移；仅达到边界并满足明确阈值时才允许翻页。
- 每次触摸只能在 recognizer begin 时依据当前 MediaID、
  `zoomScale`、`contentOffset`、水平边界与初始方向选择一个
  owner：`pager`、`mediaPan` 或 `none`。owner 在
  ended/cancelled/failed 前不可改变，同一触摸不得同时提交
  Pager 和图片平移。
- minimum zoom 且明确水平时可由 Pager 拥有；缩放后的
  interior 手势由 `mediaPan` 拥有；同一手势到达边界不移交。
  只有下一次从已有边界明确朝外开始的水平手势才可交给
  Pager；minimum zoom 下的垂直或模糊方向为 `none`。
- 页面或 MediaID 切换、session 取消或失败后，旧 session
  不得提交页面变化；Reduce Motion 不改变 owner 决策。
- 翻页完成后新页面使用自身 zoom 状态；离开后复用必须重置。
- 图片加载/失败期间保持页面尺寸和背景，不能露白。
- 关闭返回帖子后，原图片单元和帖子滚动位置保持。
- 首版不实现下滑关闭，除非通过独立 ADR 和冲突测试。

## Safe Area 与遮挡

- 导航操作使用 toolbar。
- 固定底栏使用 `safeAreaInset(edge: .bottom)`。
- 键盘出现时输入控件（若未来有搜索）可见，内容不被永久偏移。
- Sheet/fullScreenCover 的展示状态归属明确，dismiss 后状态重置。
- 透明 overlay 只能覆盖需要拦截的区域；不可无意吞掉列表或返回手势。

## 状态反馈

- 同一种错误在各 Feature 使用同一 ErrorView/inline banner 语义。
- 同一种成功提示使用同一反馈机制。
- 触觉反馈只用于明确用户动作，不用于网络自动完成。
- 离线/超时/会话失效提示可区分且可恢复。

## 可访问性

- VoiceOver 顺序与视觉顺序一致。
- 图片有可用标签或标记为装饰。
- 动态字体不因固定 frame 截断标题和楼层文本。
- Reduce Motion 下取消非必要位移动画，但不取消状态反馈。
