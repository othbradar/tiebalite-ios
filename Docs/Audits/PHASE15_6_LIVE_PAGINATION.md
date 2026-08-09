# 阶段 15.6：核心 Live 分页收口审计

- 日期：2026-08-09
- 基线：`9a8cec68096a722772419bc9926bd2146dfdb31a`
- Android reference：`5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`
- 决策：`ADR-0019-core-live-pagination-beta.md`
- 状态：`PHASE_15_LIVE_PAGINATION = COMPLETE`
- 后续阶段：`PHASE_16 = NOT_STARTED`

## 目标与范围

本轮只将已有 PBPage ThreadReader 与 Personalized 推荐从有限首屏/
两页扩展为证据支持的普通顺序分页。没有引入数据库、离线缓存、
通用分页框架或固定最大页数，也没有进入阶段 16。

明确未修改：唯一 `VirtualizedList` / UITableView 列表承载、ForumHome、
Pager、MediaViewer、ThreadContentRenderer、Session/Keychain/登录、
生产图片 loader、评论/回复/发帖/签到。

## Android 与协议证据

### PBPage

- endpoint：POST `/c/f/pb/page?cmd=302001&format=protobuf`；
- 首屏：`pn=0,pid=0`；后续：`pn=current_page+1`；
- `ThreadInfo.pids` 排除累计已读 `Post.id`后取最后未见正值；
  无剩余候选时 Android 明确 fallback 为 `pid=0`；
- Android 以当页 `Page.has_more=0` 作为客户端停止信号；当前三页
  Live 样本未观察到 0，真实末页仍为 `RUNTIME_UNKNOWN`；
- reducer 按 `Post.id` first-wins 追加，下一页失败保留旧内容。

### Personalized

- endpoint：POST `/c/f/excellent/personalized?cmd=309264`；
- 首屏 `load_type=1,pn=1`，下一页 `load_type=2,pn=N`，
  `page_thread_count=11`；
- Android reducer 按 `ThreadInfo.id` first-wins 去重保序；
- response 没有 `has_more`、total page 或 cursor，Android UI 也不声明
  load-end，因此 iOS 不发明 server terminal。

## 实现合同

### ThreadReader

1. mapper 对首屏要求 wire `current_page=1`，对后续页要求精确等于
   requested page；缺失/跳页/倒退作为 typed retained failure。
2. 每一页都消费 wire `has_more`；Android 已证它是 client stop signal，
   iOS 以 0 作为 wire terminal 合同，但真实末页运行语义未验证；
   `total_page/new_total_page` 只作展示元数据。
3. Store 把累计 postID 作为仅 mapper 使用的 cursor context，不向 wire
   增加未证字段。跨页 postID first-wins，保持服务器首次顺序。
4. 同一 thread/page/generation 只有一个 Task；失败重试相同 page/pid，
   cancellation 不显示普通错误，迟到结果不覆盖新 route/generation。
5. `has_more=1` 但无新稳定 postID 时保留已读楼层与原 cursor，
   进入可重试 client no-progress failure，防止无限空转。

### Recommendations

1. Repository 升级为 page-aware request/result，继续在 HTTP 前取得 active
   lease，响应后复验同一 lease；非法 kind/page 组合在触网前 fail closed。
2. Store 区分 initial/loading-next/next-failure/refreshing/refresh-failure，以一个
   Task、generation 和 requested page 保护刷新/分页；分页失败保留旧页。
3. LazyVStack 末尾 4 项只同步派发 Store-owned load-next 意图，cell task
   的生命周期不再拥有/取消网络 Task。
4. 跨页按稳定 `ThreadInfo.id` first-wins 增量追加。空页或
   duplicate-only 页停止是受测 client no-progress policy，不是 server
   terminal，且没有固定最大页。

## 脱敏 Live 运行证据

| 能力 | HTTP | MIME | bytes | decode | page/count | outcome |
|---|---|---|---:|---|---|---|
| PBPage page 1 | 200 | `application/octet-stream` | 24893 | true | current=1, mapped=17 | success |
| PBPage page 2 | 200 | `application/octet-stream` | 16779 | true | current=2, mapped=15 | success |
| PBPage page 3 | 200 | `application/octet-stream` | 13805 | true | current=3, mapped=15 | success |
| Personalized page 1 | 200 | `application/octet-stream` | 91156 | true | mapped=12 | success |
| Personalized page 2 | 200 | `application/octet-stream` | 72958 | true | mapped=12, new=12 | success |

PBPage 三页累计 45 个唯一 postID，三页 `has_more=1`，请求顺序
为 initial/page2/page3。首屏固定使用 `pid=0`；page2/page3 因前一页
pids 无未见候选而使用已证 fallback `pid=0`。page3 映射出的未来
cursor 也为 0，但本轮未发出 page4。Personalized page2 的 request 为
`load_type=2,pn=2`，
相对 page1 新增 12 个稳定 ID。

Probe 和文档只保留 status、MIME、byte count、decode、page/count 与 typed
outcome。没有记录/保存 threadID/postID 值、标题、正文、用户内容、请求体、
完整响应、Cookie/Authorization header 或 credential。自动化完全
使用 Fixture/Mock/FakeSession。

## Fixture 与回归

- ThreadReader 生产领域 Fixture 五页，有跨页 overlap，聚合 77 个唯一楼层；
- 已有 5×200/1000 楼 UITableView 虚拟化测试仍通过，共享承载没有 diff；
- 推荐 Fixture 三页，有边界重复 ID，验证 first-wins/顺序、失败重试、
  重复触底、取消、refresh/next generation 隔离与 Store-owned prefetch。
- iPhone/iPad smoke 走 Fixture 三页推荐与五页帖子链路，Live 证据
  只由 Debug-only 受控 Probe 获取。

## 中间失败与根因

- 首个后续页 mapper 红测证明旧本地两页硬帽；实现后转绿。
- 首次 Debug build 因测试辅助签名使用 existential 失败，改为精确协议
  类型后通过。
- 首次连续 Thread Probe 把 Android 明确允许的 `pid=0` fallback 误当
  协议失败；重读锁定 reference 后删除该猜测。
- 一次 Thread Probe 选中了无法继续第三页的边界主题，该中间运行
  没有形成可复现的真实末页证据；改为确定性选择 FRS 中 reply count
  最大的非置顶公开帖，不改 PBPage 字段。
- 首轮 iPhone 推荐 UI 因旧固定 ID/路由断言失败，只更新 Fixture 测试
  识别与断言。
- 首轮 iPad 组合测试的 Forum 用例使用整个 split app 而不是
  Forum list 容器滚动；只修正测试容器后定向通过。
- 最终 iPad 组合 smoke 中帖子五页链路通过，推荐用例两次卡在
  末页 row 不可点击。xcresult 截图/录屏和合成手势事件证明
  `recommendations.list` 的 accessibility frame 跨过空 detail column：默认
  center 与第一次“leading 20%”坐标分别落在空 detail/sidebar，页面实际
  没有滚动。测试现从已知可见 recommendation row 取得列的绝对
  x 坐标，不依赖设备尺寸；iPad 和 iPhone 定向复验均通过。
- 一次 lint 因新测试文件超过长度门禁失败；将唯一可复用
  Repository 辅助移入 `TestSupport`，不降低门禁。

## 最终命令与结果

- `make instructions`：exit 0，全部指令链与 8 个 repo skill 通过；
- `make secret-scan`：exit 0，无 high-confidence match；
- `make lint`：exit 0，185 个 Swift 文件、0 violations；
- 阶段 10/15/15.6 定向 Unit：通过；结果包
  `Artifacts/TestResults/stage15_6-final-targeted.xcresult`；
- `make test-unit`：通过；最终 `make quality-fast` 内的 Unit 结果包为
  `Artifacts/TestResults/20260809-222321-38783-unit.xcresult`，302 个逻辑测试、
  321 次执行、0 failed/0 skipped；
- iPhone 推荐三页/打开/返回锚点：1/1，
  `stage15_6-final-iphone-recommendation-anchor.xcresult`；帖子五页/楼中楼/
  图片往返/返回 Forum：1/1，与推荐合并运行结果包
  `stage15_6-final-iphone-smoke.xcresult`（合计 2/2）；
- iPad 帖子五页主链路：1/1，最终组合结果包内该用例通过；
  推荐三页/打开/返回：滚动坐标根因修正后 1/1，
  `stage15_6-final-ipad-recommendation-anchor.xcresult`；
- `make quality-fast`：exit 0；instructions、reference/Proto/fixture 确定性、
  SwiftPM/XcodeGen、forbidden/static canaries、secret scan、networking isolation、
  lint、Debug build、Simulator Keychain entitlement 与全部 Unit 通过；
- `git diff --check` 与 Android submodule clean 检查在精确暂存前最终运行。

任务明确禁止修改共享交互/列表承载，本轮没有运行完整
Pager/Media interaction 或 `make quality`；这不影响上述定向 UI 与
`quality-fast` 结论。

## Known Limitations / UNKNOWN

1. PBPage 仅一个公开长帖的三页运行证据；真实 `has_more=0`
   末页、空页、删除/私密、倒序/跳楼、跨主题稳定性仍未验证。
2. Personalized 只验证 active-session page2；匿名稳定性、page3+
   live、服务 terminal、限流和完整错误 taxonomy 仍为 `UNKNOWN`。
3. 真实 smoke 是 iOS 26.5 单 Simulator 开源 Beta 观察，不是真机/
   多账号/多系统发布级矩阵。
4. 完整 PB Floor 楼中楼页、Live 图片、数据库、离线缓存与阶段 16
   均未开始。
