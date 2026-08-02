# 测试矩阵

阶段实现时勾选对应行，不得只测 Happy Path。

## 设备与环境

| 维度 | 最低覆盖 |
|---|---|
| iPhone | 一台窄屏/小尺寸模拟器 + 一台 Pro Max 类模拟器 |
| iPad | 11 英寸类 + 13 英寸类或至少两种窗口宽度 |
| 方向 | iPhone 竖屏；iPad 横屏和竖屏 |
| 多任务 | iPad 全屏、约 1/2、窄列折叠 |
| 外观 | 浅色、深色 |
| 字体 | 默认、至少一个无障碍大字号 |
| 动效 | 默认、Reduce Motion |
| 网络 | 成功、慢、离线、超时、500、畸形响应、取消 |
| Session | 未登录、已登录、过期、退出 |

## App Shell

- 冷启动到默认 Tab。
- Tab 切换保留每个 Tab path。
- 重复切换 20 次无栈错乱或 overlay 残留。
- 前后台切换期间有请求。
- 内存警告/场景恢复不崩溃。
- iPad SplitView 折叠/展开选择保持。

## 推荐流

- 首次成功、空、失败、重试。
- 下拉刷新成功/失败，旧内容保持。
- 分页成功/失败/重复 cursor/重复 ID。
- 快速滚动只发一次对应请求。
- 新刷新早于旧刷新返回，旧响应被丢弃。
- 打开帖子返回，列表位置与内容保持。
- 标题空、超长、多行、无头像、坏图。

## 关注的吧

- 未登录引导。
- 登录后成功、空、失败、刷新。
- Session 过期统一处理。
- 进入吧首页返回位置保持。
- 大量吧列表滚动和图片复用。

## 吧首页

- 吧信息加载与主题列表独立失败策略。
- 置顶贴、普通贴、删除贴、特殊类型贴。
- 分区/排序切换：各自状态和 cursor 独立。
- 快速切换分区，旧响应不串页。
- 返回后选中分区和滚动位置保持。
- iPad 侧栏选择与详情一致。

## 帖子阅读

- 首屏、下一页、跳页/楼层（若范围批准）。
- 文本、图片、链接、表情、引用、未知节点。
- 楼主标识、楼层号、时间、删除/屏蔽内容。
- 楼中楼展开/分页只读。
- 大帖子快速滚动和 cell 复用。
- 加载下一页失败保留已读内容。
- 返回列表保持位置。

阶段 08 只关闭其中的“正文节点映射 + 隔离 Renderer”子集：

- `ThreadInfo.firstPostContent` cross-language fixture 覆盖 P0 raw、poll、
  unknown/presence/malformed/保序/稳定 ID。
- Renderer/test fixture 组合覆盖短/多段/换行/超长文本、图片六态；UI Lab
  固定 rendered/loading/fetch failure/decode failure，unit fixture 另覆盖
  idle/cancelled、请求替换隔离、重复确定性与取消传播；同时覆盖多图、
  安全/拒绝链接、emoji、mention、video/voice 降级、poll、unknown、
  empty/deleted/blocked。
- iPhone 定向 smoke 覆盖深色、Accessibility 大字号、Reduce Motion、
  图片 rendered/loading/fetch failure/decode failure 稳定 frame；失败态无
  action/MediaIntent，成功态保持 intent-only 导航。
- iPad 定向 smoke 覆盖 regular/compact 投影、旋转后内容保持，以及 loading、
  fetch/decode failure 均无图片 action。
- 本子集不表示 ThreadScreen、PB Page/楼层分页、滚动位置、
  楼中楼或 MediaViewer 已完成。

## MediaViewer/Pager

以下条目是完整发布矩阵。阶段 06 的 Open-Source Beta acceptance 采用分级
证据，不把未运行项目改写为通过：

- `PASS/CLOSED`：当前确定性测试和已声明 Simulator runtime 已验证。
- `DEFERRED_POST_BETA`：未验证且保留到 post-Beta/发布前，不阻塞阶段 09。
- `NOT_IMPLEMENTED`：生产能力尚不存在，不能用 Debug fixture 冒充验证。

- 单图、多图、首图、末图。
- 低速 49% 取消、低速 51% 提交，并独立覆盖短距离高 velocity 与长距离
  低 velocity；同触摸回撤/反向以结束位置裁决，cancelled/failed 不提交。
- 20 次交替 rapid-serial swipe 与左右边界各 20 次
  rapid-serial swipe；这些是高速但串行的 XCUITest gesture，不得
  报告为 concurrent/overlapping burst。结束后视觉页、selected
  PageID、current index 和 controller identity 一致，边界不出现空页。
- 真实同一触摸越过半程后回撤至起点并释放，连续 5 次；每次必须
  是一个 input sequence、一个 transition token、`reversalCount >= 1`，
  最终不提交，保留真实 recognizer trace 与录屏。
- 覆盖 delegate、Pager terminal、Media ownership terminal 的六种到达排列；
  三方同 generation 证据齐全后只收口一次，不得依赖重复 callback。
  ownership `active` 不得授权提交；cancelled/failed/invalidated、
  `ended(owner: mediaPan)`、Pager cancelled/failed 均不得提交。
- previous/visible PageID 相同但 host identity 不同、方向错误、controller
  installation generation 过期或外部 selection generation 变化时，callback
  必须 non-consuming：selection/resolved count/context 不变，随后正确 callback
  仍能完成。resolution 后的迟到/重复 callback 不得改变视觉页或 selection。
- 交互中外部 selection 变化必须保留 source/target，直到 D/P/O terminal 齐全
  才应用最新选择；覆盖 away→back 同值但 generation 前进、Media 同 ID
  generation 前进、ownership terminal 先到后的同 ID generation 前进、
  Pager pan recognizer 更换、同 ID stale visible host，以及已缓存 delegate
  失效后由后续有效 delegate 替代。
- 纵向 ScrollView 夹带明显水平抖动连续 5 次；纵向 offset
  必须变化，PageID/controller 不变且 Pager resolved count 为 0。
- 图片未加载完成时滑动。
- 图片失败时滑动。
- Pager 页面覆盖 loaded、retained refreshing、loading next page、retained
  refresh failure、initial loading、initial failure、empty；每态 root/frame/
  不透明背景完整，partial drag 中更新不露白、不跳页、不吞无关点击。
- p2→p3→p2、刷新、旋转和 regular/compact 投影保持缓存内 child identity；
  正式驱逐后 weak reference 释放，返回时使用新 identity 且不继承旧 deferred
  commit。100 页遍历的 settled cache ≤3、transition cache ≤4，昂贵内容
  创建次数有界，dismantle 后无 orphan child/controller/coordinator/task。
- 双击缩放、捏合、平移、缩放后尝试翻页。
- 切页后 zoom 状态不串页。
- 旋转/窗口 resize 时 index 和背景稳定。
- 关闭后帖子位置保持。
- 全程无白块、透明露底、导航栏遮挡。

### 阶段 06 Open-Source Beta 出口

| 证据组 | 出口状态 | 当前证据边界 |
|---|---|---|
| P3 threshold/velocity/burst/jitter | `CLOSED` | iOS 26.5 Simulator：49%/51% 各 5 次、velocity 分支、20 次交替、左右边界各 20 次、纵向 jitter 5 次；真实同触摸反向录屏延期 |
| P4 retained state geometry | `CLOSED` | 七态 fixture、partial drag refresh 5 次、opaque full-bounds、稳定 PageID/host、stale generation rejection |
| P5 controller lifecycle | `CLOSED` | cache 内 identity、weak eviction/recreation、100 PageID cache/创建次数上界、dismantle release |
| Pager/Media terminal rendezvous | `CLOSED` | D/P/O 六种顺序、active/cancelled/failed/media owner、generation/host/direction 与三个原始回归 |
| iOS 18.x、真机、真机 VoiceOver | `DEFERRED_POST_BETA` | 当前无实际 runtime/设备证据 |
| 真实同触摸反向录屏 | `DEFERRED_POST_BETA` | deterministic reverse trace 已有；真实单 input sequence 录屏未完成 |
| 极端图片资源压力 | `DEFERRED_POST_BETA` | 100 张 full-resolution lease、全尺寸图片与极端内存/翻页压力未运行 |
| 完全同签名迟到 callback | `DEFERRED_POST_BETA` | 公开 UIKit callback 不携带 token；可观测 identity/generation 防线已验证，理论不可区分排列未穷举 |
| 生产 MediaViewer/图片管线 | `NOT_IMPLEMENTED` | Debug InteractionLab 不得进入 Release 或替代阶段 09 生产实现 |

阶段状态为 `PHASE_06_INTERACTION_SPIKES = SPIKE_ACCEPTED`，acceptance scope 为
`OPEN_SOURCE_BETA`；`PHASE_06C_C = DEFERRED_POST_BETA`，
`PHASE_09_PREREQUISITES_SATISFIED`，阶段 09 保持 `NOT_STARTED`。

## 可访问性与视觉稳定

- VoiceOver 元素顺序。
- 大字体标题/正文不裁切。
- 深色模式占位、错误、媒体背景正确。
- Reduce Motion 下无自定义大幅位移。
- Safe Area、Home Indicator、状态栏、键盘、sheet 无遮挡。

## 性能

- 推荐流连续滚动，无明显主线程阻塞。
- 大帖子滚动和图片 decode 不持续卡顿。
- 图片查看器快速翻页内存不无限增长。
- 退出大图后可释放非必要 full-resolution 资源。
- 请求重复率和分页触发符合预期。
