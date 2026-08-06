# ADR-0017：PBPage 只读帖子分页的开源 Beta 边界

- 状态：Accepted
- 日期：2026-08-05
- 决策者：阶段 15 “只读帖子、楼层、楼中楼和基本分页”
- 关联阶段：08、09、10、11、14、15、16
- Supersedes：扩展 ADR-0013 的 PBPage adapter，并仅对匿名首屏与顺序下一页
  授予 ADR-0006 Live gate 的开源 Beta 例外；不改变 Session、图片 loader、
  Pager、MediaViewer、Renderer、PB Floor 或分发边界

## 背景

阶段 11 已锁定 PBPage endpoint、request golden、Proto 闭包与首屏 mapper，
但因缺少真实 threadID 而保持 Production fail-closed。阶段 14 的匿名 FRS
首屏现在能提供真实公开 threadID。锁定 Android reference 证明普通升序阅读以
`pn=0/pid=0` 请求首屏，以响应 `current_page + 1` 和
`ThreadInfo.pids` 中排除本页 postID 后的最后一个合法值请求下一页。当前 Beta
gate 只允许首屏的 `Page.has_more` 决定是否请求这一页；任何后续页都强制
terminal，不据其 `has_more` 继续第三页。

PBPage 当前 156-file 生成集合已经包含 `Post`、`SubPost`、`SubPostList`、
`PbContent` 与 `Page`，本阶段不需要扩大 Proto 闭包。独立楼中楼完整页需要
PB Floor，但不属于本阶段的内联预览范围。

## 决策

1. `ThreadReaderRepository` 接收 `ThreadReaderPageRequest(threadID, pageNumber,
   postID)`。首屏固定 `pageNumber=0/postID=0`；顺序下一页使用已映射的
   `currentPage + 1` 与 `nextPostID`。不猜 sort、倒序、跳楼或 PB Floor 参数。
2. 响应 `Page.current_page/new_total_page` 进入领域快照；首屏的
   `Page.has_more` 只决定是否允许已验证的一页下一页，后续页无条件 terminal。
   `ThreadInfo.pids` 只接受正 Int64 token；畸形 token 被忽略，不复制 Android
   的强制解析崩溃。下一页无首楼是合法响应，只有首屏缺首楼才失败。
3. 楼层、楼中楼分别使用真实 `Post.id` 与 `SubPostList.id`。分页追加按 postID
   去重并保持服务器顺序；未知内容节点保留安全占位，单个非法 post/subpost
   被跳过而不使整页失败。折叠只使用已证 `is_fold/fold_tip`，不猜
   `is_post_visible` 的 proto3 零值语义。
4. 内联楼中楼显示作者、简单时间、正文与可证的 type-4 mention 回复对象。
   `SubPostList.title` 不被猜成回复关系。只显示 PBPage 已返回的预览，并明确
   剩余数量；不实现弹层、独立详情或 PBFloor 分页。
5. Store 保持单一 Task 与递增 generation。下一页加载/失败保留现有楼层和
   scroll anchor；重复请求被拒绝，取消不显示普通错误，迟到结果不能覆盖新
   状态。离开 Thread route 时 registry 显式取消 Store。
6. View 复用现有 `ThreadContentRenderer` 和唯一 `MediaViewer`；不创建第二套
   NavigationStack、Pager、手势、overlay 或 fullScreenCover。Fixture 与
   UITesting 保持完全离线。
7. Debug Probe 先从固定公开 FRS 首屏选择一个真实 threadID，再只请求 PBPage
   首屏和一页下一页。它只显示 HTTP status、MIME、byte count、Proto decode、
   标题/首楼存在性、普通楼层/楼中楼计数、has-next 与 typed error；不保存
   Cookie、请求体、响应体、Proto dump、threadID 或用户内容。

### ADR-0006 开源 Beta 例外

例外只覆盖精确 HTTPS PBPage endpoint 的匿名普通升序首屏与一页下一页。
启用条件是：Android 可追踪请求策略、确定性合成 Proto/Fixture 两页、
request/mapper/分页保留/去重/取消测试，以及无凭证 Simulator 的真实两页
成功。完整错误 taxonomy、倒序、只看楼主、跳楼、PB Floor、所有主题和压力
矩阵继续延期。精确请求失效时显示 typed failure，不放宽 TLS/MIME、不吞
解析错误，也不回退明文接口。

## 运行决议

2026-08-05，无凭证 iPhone Air Simulator 的 Debug-only Probe 先从公开
`minecraft` FRS 首屏取得真实主题，再执行 PBPage：

- 首屏：HTTP 200、`application/octet-stream`、24,567 bytes、Proto decode
  成功、首楼存在、16 个普通楼层、60 条内联楼中楼、`has_more=true`；
- 第二页：HTTP 200、`application/octet-stream`、17,106 bytes、Proto decode
  成功、15 个普通楼层；
- typed error 为 none，outcome 为 success。

没有保存服务端 body、完整 Proto、标题、threadID 或用户内容。该证据允许
Production 组合使用唯一 `LiveThreadReaderRepository` 的普通升序首屏和基本
下一页；阶段 11 总状态仍保持 `RUNTIME_EVIDENCE_PARTIAL`。

## 许可、限制与回滚

本决策沿用 ADR-0011 的本地、个人、非商业范围。公开分发、App Store、商业
使用和 Proto 权利义务继续阻塞。Production 图片 loader 仍 disabled，因此
Live 文本/楼层可读，但 Live 图片加载与 MediaViewer 入口不是本 ADR 的运行
证据；Fixture 使用现有 loader 验证完整图片链路。

回滚时将 Production ThreadReader 恢复 evidence-blocked，并保留 Fixture
两页、领域模型和 tests；不得修改唯一 Pager、MediaViewer 或 Renderer。

帖子列表的生产虚拟化承载、SwiftUI A/B 和 cell/task 生命周期由
`ADR-0018-thread-reader-table-virtualization-beta.md` 约束；本 ADR 继续只拥有
PBPage wire、mapper 与分页提交语义。
