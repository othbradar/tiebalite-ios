# 阶段 14P：Forum Home 长列表性能审计

- 日期：2026-08-09
- 基线：`c63a3c5065271bfc3ee6279ed3f79edc7aada9b4`
- Android API reference：`5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`
- 最新 Android UI reference：`268f388c7824ae2c8f6ed549827a943ec8a7f352`
- 状态：`PHASE_14_FORUM_HOME_PERFORMANCE = COMPLETE`
- 后续阶段：`PHASE_16 = NOT_STARTED`

## 目标与范围

本轮只加固 Forum Home 的 RowModel、唯一纵向虚拟列表、FRS 顺序分页、
1000 帖 Fixture、对应测试与证据文档。没有进入阶段 16，没有修改阶段 15
已经稳定的 `VirtualizedList`，也没有修改 ThreadReader、Pager、MediaViewer、
Renderer、Session 或图片管线。

## 修改前审计与方案

- 原 Forum Home 是一个 `ScrollView + LazyVStack`。置顶/普通分组在 View
  求值期间分别过滤全量主题，Cell 同时临时构造卡片；identity 使用 wire
  `itemID`，没有分页或统一 prefetch 入口。
- 最新 TiebaLite UI 使用一个顶层 `LazyColumn`，主题类型覆盖置顶、纯文字、
  单图、多图和视频；客户端消费 `thread_id_list` 时以最多 30 个 ID 分批，
  队列耗尽后再请求下一 FRS 页，并按 `ThreadInfo.id` first-wins 去重。
  iOS 本阶段没有移植 Android 的 index/item identity，而是按稳定身份合同
  使用 `ThreadInfo.threadId`。
- iOS 直接复用阶段 15 已验证的无业务语义 `VirtualizedList`：底层是
  `UITableView + UITableViewDiffableDataSource + UIHostingConfiguration`，
  支持 stable ID、增量 snapshot、prefetch、anchor、reuse 和 teardown。
  本轮没有修改该共享文件，也没有保留第二套生产 Forum 列表。

## 最终列表与身份

唯一顶层纵向列表依次投影：

1. forum header；
2. retained status（如有）；
3. pinned/regular section row；
4. 每个 thread 各一个顶层 row；
5. 单一 pagination footer 或 empty row。

`ForumThreadRowModel` 为 `Sendable + Equatable`，稳定身份为正值
`threadID`；wire `itemID` 只保留为协议证据，不参与 diffable identity。
Mapper 先生成摘要和媒体数量，Store 再生成 top/plainText/singleMedia/
multiMedia/video RowKind。标题最多 2 行、摘要最多 5 行、缩略图占位最多
3 个；当前没有生产缩略图 loader，因此不存在复用 Cell 显示旧网络图片的路径。

分页追加只向 presentation 插入新 `threadID`；同 ID 内容未变化时，
`VirtualizedList` 不 reconfigure retained row。跨页重复和迟到置顶采用
first-wins，保持服务端首次出现顺序。

## 分页与 Live 证据

Production 保持已有 FRS endpoint 和 Proto：

- `POST https://tiebac.baidu.com/c/f/frs/page?cmd=301001`
- 首屏：`pn=1`、`load_type=1`
- 后续页：`pn=N`、`load_type=2`
- response：`Tieba_FrsPage_FrsPageResponse`

Store 同时只保留一个 Task，并以 generation、ForumRoute 和 page 拒绝
重复或迟到请求；tail-4 prefetch 统一触发下一页。下一页失败保留旧 rows
和同页重试 footer；终止态不再请求。

无凭证 Debug Probe 对阶段 14 同一固定公开吧得到：HTTP 200、
`application/octet-stream`、156,269 bytes、Proto decode 成功；首屏 13 条，
第二页新增 30 条，聚合 43 条，`typed-error=none`、`outcome=success`。
Probe 没有记录 Cookie、请求体、响应正文、threadID、标题或用户内容。

当前 156-file Proto closure 没有 ThreadList root，且
`thread_id_list + ThreadList` 的遗漏、顺序和终止语义仍缺少本地
fixture/运行证据，因此本轮没有猜测或启用该链路。

## 自动化回归

新增或扩展的确定性覆盖包括：

- FRS 第二页的 page/load_type request；
- mapper 在 View 前完成 threadID 去重、摘要与媒体 RowKind 投影；
- 跨页重复（含迟到置顶）first-wins、服务端顺序和原 itemID 保留；
- 10×100 页增量到 1000 个唯一 thread，前 100 个 RowModel 始终不变，
  no-more 后不再请求；
- 下一页失败保留旧内容并重试同一页；多个预取共享一个 in-flight 请求；
- page 2 挂起时切换 ForumRoute，取消且拒绝旧页迟到结果；
- 实际 UITableView 从 100 增量到 1000 rows，可跳转 1000/500/1，
  `reuseCount > 0`、`createdCellCount <= peakVisibleCellCount * 4`，
  teardown 后 hosted cell 数为 0。

最终 `make test-unit` 和 `make quality-fast` 的 Unit 结果均为 284 个逻辑
测试、303 次执行、0 failed/0 skipped。最终结果包为
`Artifacts/TestResults/20260809-165524-92493-unit.xcresult`。

## Simulator 与 UI 结果

- iPhone UI smoke：19/19 PASS，结果
  `Artifacts/TestResults/20260809-160542-65503-ui-smoke.xcresult`。
- iPad Forum 流程最初因测试把 swipe 发给整个 split app 而不是 detail
  `forum-home.list`，连续 3 次无法滚到目标 row。测试改为使用已有容器版
  helper 后，Forum → ThreadReader → MediaViewer 流程两次定向运行均为
  1/1 PASS：`/private/tmp/stage14p-ipad-fix-green1.xcresult` 与
  `/private/tmp/stage14p-ipad-forum-green2.xcresult`。生产列表和断言未放宽。
- 第二次完整 iPad smoke 为 5/6：Forum 列表、分页、图片打开均成功，随后
  一次 `media-viewer.close` 视觉存在但 XCUITest 报 not hittable；同一流程
  两次定向复验及套件内另外两个 MediaViewer 测试均通过，未形成稳定产品
  回归，因此按开源 Beta 标准保留为测试波动，不越界修改 MediaViewer。

Debug-only 1000 帖 Lab 的实际观察：

- iPhone 从 100 条连续触发到 `items=1000 page=10 has-more=false`，底部可见
  第 998～1000 条和“已经到底了”；没有持续白块、重复 identity、错页或
  稳定超过约 1 秒的停顿。
- 在第 5 页打开中部 thread 990424，再返回后原可见 rows 990422～990425
  保持，列表位置未丢失。
- iPad 从首屏快速滚动并触发到 200 条/第 2 页，未见明显布局或滚动异常。
- 另以 Debug Lab + `SWIFT_OPTIMIZATION_LEVEL=-O` 构建近 Release 版本，
  手工快速滚动到 300 条/第 3 页，未见稳定卡顿或白块。

## 实际门禁

- `make secret-scan`：PASS。
- `make lint`：最终 180 个 Swift 文件，0 violation；首轮发现测试类型超长，
  只拆分测试类型后复验通过。
- `make test-unit`：284 个逻辑测试/303 次执行，PASS。
- `make test-ui-smoke`：19/19 PASS。
- iPad Forum 定向 smoke：修复后 2×(1/1) PASS；完整 iPad smoke 的一次
  5/6 结果按上节如实保留。
- `make quality-fast`：PASS，exit 0。
- `git diff --check`、Android submodule clean、精确暂存与密钥扫描：提交前复验。
- 完整 `make quality`：未运行；本轮没有修改/抽取阶段 15 的共享
  `VirtualizedList`，按任务约定无需重复 interaction/Release 全矩阵。

## 新增或变更的动画、手势、overlay、依赖

- 动画：无。
- 业务手势：无。
- overlay/fullScreenCover：无。
- 第三方依赖：无。
- Live 图片或其他网络：无；只有 Debug-only 少量 FRS Probe。

## Known Limitations

1. Live 只验证固定公开吧首屏与一页顺序下一页；第三页及更后页只有 Android
   静态证据与 Fixture，不宣称完整运行验证。
2. `thread_id_list + ThreadList`、dynamic tab、sort 变体、限流与完整错误
   taxonomy 仍为 `UNKNOWN`，Production 继续 fail closed。
3. 列表媒体仍是稳定本地占位；没有实现 thumbnail loader、缓存或下采样。
4. 性能结论是 iOS 26.5 Simulator 与 `-O` 近 Release 手工观察，不是精确
   FPS、Instruments 长期基准、真机或全系统版本矩阵。
5. 完整 iPad smoke 留有一次仅在 MediaViewer close hit-testing 的 XCUITest
   波动；当前没有稳定可复现的生产白块、错页、遮挡、崩溃或卡顿。

## 停止点与提交边界

`PHASE_14_FORUM_HOME = COMPLETE`，
`PHASE_14_FORUM_HOME_PERFORMANCE = COMPLETE`，`PHASE_16 = NOT_STARTED`。
用户原 `.idea`、`.DS_Store`、Android submodule 与 `Artifacts` 不纳入提交；
没有 Cookie、BDUSS、STOKEN、响应正文或其他凭证进入代码、日志、文档或 Git。
