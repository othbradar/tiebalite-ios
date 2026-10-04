# 交互契约

## 导航

- iPhone：每个主 Tab 保留独立 `NavigationStack` path。
- iPad：横向 regular 窗口使用 `NavigationSplitView`，选择吧/主题时保留侧栏状态；竖向/方形或 compact 窗口使用同一 canonical route 的完整栈（ADR-0026）。
- 紧凑 Shell 进入吧/帖子以及其后续阅读子页时移除根底栏和占位；返回非阅读路径时恢复。历史入口同样适用，不清空其他 Tab 的路径。
- 系统返回手势必须可用，不用自定义横滑覆盖。
- 重复点击当前 Tab：只有在产品规格明确时才滚到顶部；不得意外重建状态。
- 深链和恢复必须通过 route 进入，不直接操纵 View 层 Bool。

## 列表

- U06P3（CODE_EVIDENCE；定向运行计数见 TASK_STATE）：帖子/吧首页可选择传入 Store 实例、内容 revision 及阅读字号组成的版本，默认调用方仍走原比较路径。内容、顺序、footer 改变递增 revision；anchor/回调不递增。VirtualizedList 同时比较字号、主题、方向和 locale 环境，分别保留 applying/completed/pending 版本，只有实际完成才标记 completed。相同版本不准备全表 IDs/字典；当前可见 Cell 更新回调，屏外 Cell 复用时取最新闭包。相同 ID 内容改变仍更新，字号/环境不能被冻结。P1 同步刷新提交使版本失效，P3 不改变首次定位/视口保持，不增加滚动、手势或动画。无持久数据迁移；移除可选版本即可恢复旧比较路径。

- 首次加载显示骨架/统一加载状态，背景与最终页面一致。
- 刷新时保留内容和滚动位置；完成后在合理情况下保持锚点。
- 分页触发有防抖/防重，接近底部触发一次，不由多个 cell 同时发起。
- 下一页错误显示尾部重试，不覆盖整页。
- 返回列表恢复选中主题附近位置，不出现跳顶。
- 主题 ID 重复时去重但不打乱服务器顺序。
- U02：吧首页选择性接入系统 UIRefreshControl；同一控件同时只执行一个刷新，销毁时取消并移除 target。其他 VirtualizedList 调用默认无刷新控件。按 2026-10-02 用户修订，删除列表顶部新内容/缓存更新提示行。每次重建吧首页先显示缓存并自动请求一次首屏；在顶部直接应用，深处则保留当前多页内容，回到顶部时静默应用。手动下拉直接请求并应用首屏，失败保留旧内容。不强制滚动或重建导航树；恢复仅在新列表实例第一次布局应用行锚点。
- U02 顶部位置：当前列表第一行（包括吧规或首条帖子）到达可见区顶部时，Store 清除旧帖子锚点，持久化为默认顶部；返回重进和磁盘重建均遵循此值。未知行及暂时 nil 的回调不等于用户回到顶部，不得清除已记录位置。零尺寸临时列表销毁不记录锚点；正常非空 viewport 离场仍保存实际位置，即使此时已移出窗口。
- U06P1：历史阅读锚点不授权刷新替换。已有内容的首屏响应先暂存；仅吧首页接入可选的 VirtualListRefreshCommit，在当前 snapshot 排空后的同步提交边界读取真实 tracking/dragging/decelerating、窗口/尺寸、恢复状态和 adjusted inset。自动更新只在静止的真实内容顶部应用，显式刷新在静止可读视口完成（不以刷新控件 spinning 为阻塞条件）。Store 与新行快照之间无 await；排队通知会重新读取状态和请求身份。开始/结束及顶部状态变化只发合并通知，不向 SwiftUI 逐帧发布 offset；触摸结束也可唤醒未形成拖动的 tracking。新首屏替换分页链，不混入旧后页；未知视口继续保留内容，首次无缓存加载不等待视口。其他列表默认不接入，无新增手势、强制滚顶或恢复机制。

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
- ADR-0029（用户 2026-09-25 要求）：仅吧首页启用首栏内容区返回。iOS 26+ 首栏向右由系统 content-pop 返回，其他栏向右仍翻到前一栏；取消返回保留 selection/offset，首栏向左及纵向滚动不受影响。局部 gate 只建立 failure requirements，不接管系统 delegate 或动画。iOS 18–25 保留系统边缘返回；MediaViewer 不启用此选项。

### 阶段 06 证据范围

`PHASE_06_INTERACTION_SPIKES = SPIKE_ACCEPTED` 采用个人开源 Beta 范围：当前
确定性状态机与 iOS 26.5 Simulator 的 iPhone/iPad 证据足以解除阶段 09
前置门禁，但不降低本节任何行为契约。iOS 18.x/真机、真机 VoiceOver、
真实同触摸反向录屏、极端图片资源压力与公开 UIKit callback 完全不可区分的
理论排列标记为 `DEFERRED_POST_BETA`；Debug InteractionLab 仍不得作为生产
Pager/MediaViewer 发布。

## MediaViewer

- 单击切换 chrome；双击按点击位置缩放；捏合缩放；缩放后平移。
- U06 用户修订：生产 Viewer 仅在 minimum zoom 时左右翻页；放大后单指/双指自由二维平移，不开启方向锁，边缘拖动也不翻页。双指捏合继续由原 UIScrollView 管理。
- 每次触摸只能在 recognizer begin 时依据当前 MediaID、
  `zoomScale`、`contentOffset`、水平边界与初始方向选择一个
  owner：`pager`、`mediaPan` 或 `none`。owner 在
  ended/cancelled/failed 前不可改变，同一触摸不得同时提交
  Pager 和图片平移。
- minimum zoom 且明确水平时可由 Pager 拥有；缩放后的
  interior 手势由 `mediaPan` 拥有；同一手势到达边界不移交。
  生产 Viewer 禁止缩放边缘向 Pager 移交；旧组件实验的边缘策略保留为默认兼容选项。
  minimum zoom 下的垂直或模糊方向为 `none`。
- 页面或 MediaID 切换、session 取消或失败后，旧 session
  不得提交页面变化；Reduce Motion 不改变 owner 决策。
- 翻页完成后新页面使用自身 zoom 状态；离开后复用必须重置。
- 图片加载/失败期间保持页面尺寸和背景，不能露白。
- 关闭返回帖子后，原图片单元和帖子滚动位置保持。
- 首版不实现下滑关闭，除非通过独立 ADR 和冲突测试。
- U06 用户修订：顶部只保留关闭与张数，VoiceOver 继续通过 adjustable action 翻页。未放大时长按实际图片显示系统菜单的保存图片、分享／存文件；放大时不显示菜单，不拦截捏合和平移。
  菜单打开时捕获 MediaID、资源描述、序号；选择动作后不再查询当前页，忙时不重复导出。菜单取消无副作用，关闭 Viewer 解绑长按 recognizer。
  加载原图只使用已证实的 original 候选；失败保留旧图并可重试，成功隐藏按钮，同 ID 的替换保留倍率/中心。
  保存只取得 original 候选编码文件，原图缺失/失败不降级保存缩略图；分享仍可明确标注可用版本。仅保存申请 Photos addOnly，实际写入完成才报成功。
  分享使用独占文件，持久 presenter 与 chrome/菜单显隐独立，iPad 在 Viewer 内锚定；系统操作完成/取消后才清理文件。无常驻保存/分享底栏，仅操作期间显示状态和可关闭结果。

## Safe Area 与遮挡

- 导航操作使用 toolbar。
- 固定底栏通常使用 `safeAreaInset(edge: .bottom)`。R11 根 TabView 经实际测量不传递外层 inset，根选择栏改为同级纵向布局，占用自身测量高度；保持 TabView 与独立导航栈实例，阅读页面隐藏后不保留空白。
- 列表初始锚点状态：pending → 已挂入窗口且 viewport 非空、目标 ID 已入快照 → restore once → consumed。零尺寸快照完成不得消耗锚点；追加、图片完成及后续 layout 不重复恢复；dismantle 清理一次性布局回调。
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

### U03：一次性定位与当前视口保持（2026-10-03 用户批准）

只在 ThreadReader 的 thread/account scope 接入路径启用；其他列表默认行为不变。新表等待有效窗口/尺寸、初始 snapshot 已应用和目标业务 ID 存在，执行一次定位；校验实际已显示 Cell 的当前 ID/配置和可读视口相交后，将实际几何交给当前视口记录，释放历史目标并结束初始回调。不等待曾创建的前置行测量或图片联网，恢复前后的 hosted Row 使用相同布局修饰。

独立视口适配只在表格布局边界维护当前稳定 ID、相对可读顶部 Y 和有效尺寸；新几何计算期望 offset 并限幅，只补 UIKit 尚未补偿的差值。几何读取和状态修改分离，程序调整防重入；不创建屏外全量 Cell、不递归布局、不轮询。用户拖动/惯性期间不纠偏，停稳后锚点跟随新的阅读位置；主动导航、回顶部优先；不同账号、路由、无效 snapshot 或尺寸不盲用旧几何。

初始恢复中的程序滚动不写阅读进度；结束后正常滚动/离开可保存实际有效位置，零尺寸临时表不覆盖有效锚点。分页、footer、图片完成不重启历史定位；通知指定楼层不被历史位置覆盖，同实例图片往返保留实际位置。U03 验收时的 iPad 旋转分栏回首楼失败回归仍保留；用户曾允许其不阻塞 U04，当时未标记通过。

U06P4：系统分栏重建表格时，UIKit 的导航 inset 调整可能在首个有效 layout 前触发 didScroll；仅这一回调不表示用户意图，不能消费尚未定位的目标。真实拖动、主动回顶部仍通过对应 delegate 立即取消；scope/目标变化和拆除继续失效。定位后沿用原实际 Cell 验证与当前视口保持，不新增等待协议或旋转导航状态。原失败及本轮结果见 TASK_STATE，人工验收前不将 U06P 记为完成。
