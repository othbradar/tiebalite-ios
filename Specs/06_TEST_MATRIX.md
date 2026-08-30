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

阶段 15.6 直接覆盖推荐三页 Fixture：`load_type=1,pn=1` 后
`load_type=2,pn=2/3`，跨页按 `ThreadInfo.id` first-wins 去重保序；
重复触底只有一个请求，下一页失败/取消保留首屏，重试相同页，
刷新拒绝迟到分页。iPhone/iPad Fixture smoke 覆盖第三页打开帖子
与返回锚点。Live 只有 active-session 第二页单 Simulator 运行证据；
服务端终止信号仍为 `UNKNOWN`。

## 搜索

- 空白关键词不请求；只在按钮或键盘提交时搜索。
- 新关键词取消旧 Task，旧 generation 不得覆盖新结果。
- 贴吧按 forumID、帖子按 threadID 首出现去重并保持服务端顺序。
- 搜帖下一页单飞；下一页失败保留已有结果并允许重试。
- 新关键词与旧关键词分页隔离，相同页不得重复请求。
- UI Testing 只使用 Fixture/Mock，不访问 Live 网络或真实 Keychain。
- iPhone 覆盖搜吧进入 ForumHome、搜帖进入 ThreadReader 及返回状态保持。
- iPad 在现有 split 容器覆盖 SearchView 和两类 Fixture 结果。

阶段 16A 的 Beta 子集使用三份合成 JSON Fixture，覆盖 forum 统计和 thread
`post_num/forum_id` 的混合 string/integer、稳定业务 ID、首出现去重、`pn=1/2`、精确
`current_page` 与 `has_more`。匿名 Live Probe 只验证 forum 首屏和 thread
前两页；forum 下一页因 Android 当前 ViewModel 没有调用证据而保持
`UNKNOWN`，没有猜测实现。

## 浏览历史、设置与用户资料

- threadID/forumID/userID 重复访问后单条、移到最前并更新访问次数。
- 自定义上限和默认 500 条驱逐最旧；单条删除/清空。
- JSON 重建恢复；损坏/未知 schema 初始失败后可清空重建并再记录。
- record/delete/clear 失败可观察且保留已加载列表；CancellationError
  不显示普通错误。
- Fixture/UI Testing composition 每次使用独立内存历史/设置和
  Fixture Profile，不读生产文件/UserDefaults/Keychain、不访问 Live。
- 外观设置持久化重建；快速多次更改串行保存后 newest snapshot 胜出。
- 阅读字号令牌 small/standard/large 有序；UI 中切换后 ThreadContent
  真实文字 frame 变大，不修改节点 identity/布局结构。
- Profile request golden 检查 endpoint/query/已证字段及无 credential/屏幕值；
  合成 Proto mapper 检查全部白名单字段、identity mismatch 和空头像回退。
- Profile Store 覆盖 route 替换、迟到响应、取消、empty、retry 和 Fixture。
- iPhone Fixture：帖子 → 返回 → 历史 → 再打开/清空；深色+大正文；
  帖子作者 → 资料。
- iPad Fixture：帖子 → 作者资料 → 系统 Sidebar → Settings → History，
  同一会话内 thread/user 记录都可见。

## 关注的吧

- 未登录引导。
- 登录后成功、空、失败、刷新。
- Session 过期统一处理。
- 进入吧首页返回位置保持。
- 大量吧列表滚动和图片复用。

阶段 13 Beta 子集已用合成 Proto/Mock 覆盖 fixture 列表、授权候选
request、映射、未登录不请求、替换/取消、typed expired 与普通错误
重试；iPhone 覆盖未登录与 signed-in fixture 列表/ForumRoute，iPad
覆盖 fixture 列表、系统导航返回与 regular/compact 投影。头像因尚无
production image loader 而使用统一占位；legacy 多页聚合、真实过期码和
超过 200 个吧仍属后续证据范围。

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

阶段 15 Open-Source Beta 已用 5×200 的 1000 楼合成 Fixture 验证唯一生产
`UITableView + DiffableDataSource + UIHostingConfiguration`：snapshot 依次为
200/400/600/800/1000，稳定 postID 去重保序，跳到 1000/500/1 楼仍能显示，
reuse 大于 0，创建 cell 不超过 4 个峰值 viewport，reuse/dismantle 会取消 hosted
task 并释放 table。31/32 楼 Fixture 的 iPhone 首次滚动连续 5 次及 iPad
ThreadReader smoke 属于阶段出口；真机、iOS 18、50 页和 full-resolution 图片
压力为 `DEFERRED_POST_BETA`。

阶段 15.6 在不修改上述列表承载的前提下，新增五页、77 个唯一楼层
Fixture，锁定页码 `0,2,3,4,5`、累计 pids cursor/`pid=0` fallback、
wire `has_more=0` client-stop/terminal 合同、精确 `current_page`、跨页 postID 去重、
no-progress、retained failure/retry、重复触底与迟到 generation。公开长帖
Live smoke 连续取得三页、45 个唯一楼层。

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

以下条目是完整发布矩阵。阶段 06/09 的 Open-Source Beta acceptance 采用
分级证据，不把未运行项目改写为通过：

- `PASS/CLOSED`：当前确定性测试和已声明 Simulator runtime 已验证。
- `DEFERRED_POST_BETA`：未验证且保留到 post-Beta/发布前，不阻塞当前 Beta。
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
阶段状态为 `PHASE_06_INTERACTION_SPIKES = SPIKE_ACCEPTED`，acceptance scope 为
`OPEN_SOURCE_BETA`；`PHASE_06C_C = DEFERRED_POST_BETA`，
阶段 06 任务出口时 `PHASE_09 = NOT_STARTED`。

### 阶段 09 Open-Source Beta 出口

| 验收 | 结果 | 实际证据边界 |
|---|---|---|
| 唯一生产 Pager/MediaViewer | `PASS/BETA` | 阶段 09 整体迁移 Stage 06 foundation；Release source-list 正向包含生产源并排除 Debug/TestSupport |
| 单图打开/缩放/关闭 | `PASS` | iPhone pinch、双击、pan 与连续 5 次打开/关闭 |
| 三图连续切换与 zoom reset | `PASS` | iPhone/iPad production Viewer smoke；稳定 MediaID 与视觉位置一致 |
| 放大后平移不误翻页 | `PASS` | iPhone pinch/pan；iPad 双击/pan，页码保持 |
| loading/fetch/decode failure | `PASS` | 固定 fake loader；全尺寸不透明黑底、可重试、无可执行媒体打开 action |
| 旋转/chrome | `PASS/BETA` | iPad 竖→横→竖，图片与 chrome 存活且未裁切 |
| 深色/Reduce Motion | `PASS` | 语义 media 黑底；production smoke 在既有 appearance/motion harness 运行 |
| iPad pinch | `DEFERRED_POST_BETA` | 当前 Simulator 全屏 XCUITest pinch 未改变 zoomScale；同一生产 wrapper 的双击/pan/旋转已通过 |
| live 图片/cache/downsample/candidate/lease | `NOT_IMPLEMENTED` | 只使用可注入 fixture/fake loader，Release 保持 DisabledImageLoader |
| missing initial/current 后稳定 unavailable | `DEFERRED_POST_BETA` | 固定 intent 构造当前拒绝不存在的 initial；动态数据移除后的 unavailable 待有 Repository 后实现 |
| 真机/iOS 18/VoiceOver/极端压力 | `DEFERRED_POST_BETA` | 未运行，不阻塞个人开源 Beta |

阶段 09 为 `PHASE_09_PRODUCTION_MEDIA_VIEWER_COMPLETE`；阶段 10 前置条件未在
本任务评估，阶段 10 为 `NOT_STARTED`。

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
