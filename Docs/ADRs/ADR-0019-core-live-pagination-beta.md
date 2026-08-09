# ADR-0019：PBPage 与 Personalized 连续 Live 分页的开源 Beta 边界

- 状态：Accepted
- 日期：2026-08-09
- 决策者：阶段 15.6“核心 Live 分页收口”
- 关联阶段：11、15、15.6、16
- Supersedes：仅取代 ADR-0017 中 PBPage“首屏 + 一页下一页”
  的临时硬帽，并为 Personalized 普通顺序分页增加范围受限的
  ADR-0006 开源 Beta 例外；ADR-0017 的阶段 15 历史记录保留不变

## 背景

ADR-0017 以一个真实两页样本临时将 PBPage 限制为首屏和一页
下一页。锁定 Android reference 的当前 `ThreadViewModel` 实际会在
`Page.has_more != 0` 时以 `current_page + 1` 继续顺序请求，没有固定
最大页数。Personalized 同样以 refresh page 1 和 next page N 顺序请求，
但响应不含 `has_more`、总页数或 cursor。

## 决策

### PBPage

1. 首屏固定 wire `pn=0,pid=0`，且必须映射为
   `current_page=1`；后续 `pn=N` 必须精确返回 `current_page=N`。
   缺失、倒退或跳页均保留已读楼层并进入可重试分页失败。
2. 每页都消费 wire `Page.has_more`。Android 代码证据表明
   `has_more=0` 是客户端停止信号，iOS 将其作为 wire terminal 合同；
   本阶段真实三页都为 `has_more=1`，因此真实服务端末页行为仍是
   `RUNTIME_UNKNOWN`。`total_page/new_total_page` 只作展示元数据。
3. 下一页 cursor 从 `ThreadInfo.pids` 排除全部累计已读和当前页
   `Post.id`，取最后一个未见正 Int64；没有候选时使用 Android 已证
   fallback `pid=0`。首屏的 `pid=0` 是固定初始值，不是 fallback。
4. 跨页按 `Post.id` first-wins 去重并保持服务器首次顺序。同一
   thread/page/generation 只允许一个请求；失败保留已读楼层并重试同一
   page/pid。`has_more=1` 但没有新增稳定 postID 时进入 retained
   client no-progress failure，不循环也不伪装成服务端末页。
5. 不设本地固定最大页，不修改唯一 UITableView/diffable 虚拟列表承载。

### Personalized

1. 刷新使用 `load_type=1,pn=1`；下一页使用
   `load_type=2,pn=N`；`page_thread_count=11`。非法 kind/page 组合在 HTTP 前
   fail closed。
2. Repository 在请求前取得 active protected lease，并在响应后复验同一
   lease。Store 以单 Task、generation 和 requested page 隔离刷新与分页，
   旧响应不能覆盖新内容。
3. 跨页按稳定 `ThreadInfo.id` first-wins 增量追加；下一页失败保留
   已有内容并可重试。列表末尾 4 项只派发 Store-owned load-next 意图，
   cell task 不拥有网络 Task。
4. Personalized response 没有服务端 terminal 字段。空页或
   duplicate-only 页停止是受测的 iOS client no-progress policy，不伪造
   `hasMore`，也不设固定页帽。

## 运行决议

2026-08-09 的 Debug-only 脱敏 Probe 观察到：

- 一个公开长帖的匿名普通升序 PBPage 连续取得三页：HTTP 全部
  200、MIME 全部 `application/octet-stream`、body
  24893/16779/13805 bytes、Proto decode 全部成功、分别映射
  17/15/15 楼，累计 45 个唯一 postID。首屏固定 `pid=0`；page 2
  和 page 3 因前页 pids 无未见候选而 fallback 为 `pid=0`。三页
  `has_more` 均为 1，证明第三页不再被本地两页硬帽终止，但不证明
  真实末页。
- 保留会话下 Personalized page 2 以 `load_type=2,pn=2` 返回 HTTP 200、
  `application/octet-stream`、72958 bytes、Proto decode=true、mapped=12，
  相对 page 1 新增 12 个稳定 ID。

运行记录只保留 status、MIME、byte count、decode、page/count 和 typed
outcome；不保留 ID 值、标题、正文、请求体、完整响应或凭证。

## 范围、未知项与回滚

例外仅覆盖 PBPage 匿名普通升序顺序分页和 Personalized active-session
顺序分页。真实 PBPage `has_more=0` 末页、合法空页、删除/私密、
倒序/跳楼、Personalized 匿名稳定性、page 3+、限流与完整错误 taxonomy
仍为 `UNKNOWN`。不扩展到 PB Floor、完整楼中楼、Live 图片、数据库、
离线缓存或阶段 16。

若精确 request/response 合同失效，回滚对应 Production Live 分页并保留
Fixture/Mock、retained failure 与脱敏证据；不放宽 TLS/MIME、不吞解析错误，
也不复制第二套列表、Pager、MediaViewer 或 Renderer。
