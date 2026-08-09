# 阶段 14：吧首页与吧内帖子列表审计

- 日期：2026-08-05
- 基线：`b6090a19c95fb720f24415975dc43e7729cae1df`
- Android reference：`5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`
- 状态：`PHASE_14_FORUM_HOME = COMPLETE`
- 后续阶段：`PHASE_15 = NOT_STARTED`

> 历史快照：本文保留 2026-08-05 阶段 14 首屏验收。其中
> `ThreadInfo.id` UI identity、无分页和长列表限制已由阶段 14P
> 取代；当前契约见 `PHASE14P_FORUM_HOME_PERFORMANCE.md`。

## 目标与范围

本阶段只实现 Forum Home 基础信息、吧内主题首屏、Fixture/Live
Repository、请求替换保护以及 Forum → 现有 ThreadReader 的导航与返回位置。
没有实现分页、吧头像网络管线、新 ThreadReader、新 Pager 或阶段 15。

## Android 与 Proto 证据

- Endpoint：`POST https://tiebac.baidu.com/c/f/frs/page?cmd=301001`。
- Request：`FrsPageRequest/FrsPageRequestData`，multipart 固定 boundary、
  `data/file` binary part，`kw` 与 `forum_name` 用 Java form encoding。
- Response：`FrsPageResponse/FrsPageResponseData`；吧信息来自 `Forum`，
  主题来自 `thread_list`，作者通过 `user_list` 关联。
- `ThreadInfo.id` 作稳定 row identity，`ThreadInfo.threadId` 作 ThreadRoute；
  `isTop == 1` 为置顶，并保持服务端顺序。
- FRS root 传递闭包为 74 个文件，与旧 136-file 集合重叠 54，
  净新增 20，总计 156 个 generated Swift 文件。两次 clean generation
  与 tracked bytes 一致。重名 `AdParam.pb.swift` 使用脚本固定的
  `FrsPage/FRSAdParam.pb.swift` 输出，并记录在 generation metadata。
- synthetic fixture 是 454 bytes，SHA-256
  `940d1df7631795791eccde105a7cb4dcbf3f38d465a8ebf9bac6af4c850887b0`；
  由 textproto 和 pinned schema 生成，不含抓取/用户内容。

## 实现与状态

- `ForumHomeRepository` 是 View/Store 的唯一数据边界。Live 通过
  `EndpointPipeline` 解码/映射；Fixture 有三个吧的独立、稳定主题 ID。
- `ForumRoute` 使用可选 positive `forumID` + 经验证 `forumName`。仅吧名
  deep link 不猜 ID，Fixture 也不为 name-only route 伪造 ID。
- Store 状态覆盖 initial loading、loaded、empty、initial failure、retained
  refreshing/failure。单 Task + generation 拒绝旧 forum 迟到结果，取消不
  显示普通错误，同 route 不重复加载。
- App registry 以 root + `ForumRoute` 复用 Store，Forum → ThreadReader → pop
  不重建 Store，保留 scroll anchor。离开 Forum route 后取消并移除。
- Forum 与 Recommendations 复用同一无业务依赖的 `ContentSummaryCard`；
  没有建第二套帖子卡片或第二个 NavigationStack。

## Live 运行证据

Debug-only Probe 在无真实凭证的 iPhone Air 和测试 iPad Simulator 上使用
固定公开吧：

- 首轮 iPhone/iPad：HTTP 200、`application/octet-stream`、54,068 bytes、
  Proto decode 成功、13 条主题、`outcome=success`。
- 最终 iPhone 复验：HTTP 200、`application/octet-stream`、55,996 bytes、
  `decoded=true`、`items=13`、`typed-error=none`、`outcome=success`。
- 吧名、简介、统计和 13 条普通主题可见，列表可滚动；iPhone 深色
  模式与 iPad 未观察到白块、遮挡或明显错位。Live 样本恰好无置顶帖，
  置顶映射由 synthetic fixture 确定性验证。

Probe 只显示 status/MIME/bytes/decode/items/typed error/outcome。没有记录
Cookie、BDUSS、STOKEN、完整请求体、完整响应、用户或帖子内容。

## 回归覆盖

阶段 14 有 12 个逻辑 Unit，覆盖：

- Fixture 吧摘要、2 置顶 + 6 普通主题和三吧独立 identity；
- `ForumRoute` 的 ID/名称语义与 name-only 不猜 ID；
- FRS endpoint/header/multipart/request Proto 和匿名无 credential/device telemetry；
- synthetic Proto 吧信息、置顶/普通、item/thread identity、作者回填/降级；
- Live Repository 的 Mock HTTP 领域映射，server envelope/malformed diagnostics；
- route replacement 取消、stale response 拒绝、cancellation 非错误、同 route 防重；
- ThreadRoute 使用 threadID 而非 row itemID，UITesting 组合不访问 Live。

iPhone smoke 打开 Fixture 吧首页，滚到中间帖，进入 ThreadReader 再系统返回，
滚动位置在 12pt 容差内。iPad smoke 验证同一 Fixture Forum 投影、
regular/compact 与旋转。

## 实际命令与结果

- `git status --short`、`git rev-parse HEAD`、`git submodule status`：基线与
  Android 锁定值正确；用户原有漂移另行记录并排除。
- `make instructions`、`make secret-scan`、`make lint`、
  `make networking-isolation`：PASS；168 个 Swift 文件 0 lint violation。
- 阶段 14 定向 Unit：12/12 PASS；结果
  `/private/tmp/stage14-unit-20260805-3.xcresult`。
- `make test-unit`：260 个逻辑测试/279 次执行，0 failed/0 skipped。
- `make test-ui-smoke`：18/18 PASS；吧首页定向流 1/1 PASS。
- `make test-ui-smoke-ipad`：5/5 PASS。
- `make quality-fast`：PASS，exit 0。
- `make quality`：PASS，exit 0，输出 `Quality gate completed.`；
  iPhone interaction 15/15、iPad interaction 2/2，iPad/Release build 和
  Release isolation 全部通过。
- `git diff --check`、Android submodule clean 与精确暂存核验：提交前再次执行。

完整门禁的关键本地结果为：

- `Artifacts/TestResults/20260805-203108-86104-unit.xcresult`
- `Artifacts/TestResults/20260805-203137-86411-ui-smoke.xcresult`
- `Artifacts/TestResults/20260805-204128-87686-ui-interaction.xcresult`
- `Artifacts/TestResults/20260805-211358-90819-ui-smoke-ipad.xcresult`
- `Artifacts/TestResults/20260805-211746-91344-ui-interaction-ipad.xcresult`
- `Artifacts/TestResults/20260805-212656-92365-release-build.log`

`Artifacts/` 为忽略的本地测试产物，不纳入提交。

## 新增或变更的动画、手势、overlay、依赖

- 动画：无。
- 手势：无；业务 Feature 未新增 DragGesture。
- overlay/fullScreenCover：无。
- 依赖：无。
- Pager、MediaViewer、MediaZoomImageView、ThreadContentRenderer、InteractionKit：
  均未修改。

## Known Limitations

1. 分页未实现；`ThreadList` 与 `thread_id_list` 关系、终止/去重语义留待
   阶段 15。
2. 匿名 Live 只在一个固定公开吧与 iOS 26.5 Simulator 验证；动态
   tab、sort 分支、服务器错误矩阵、限流和跨吧稳定性未验证。
3. 吧头像保留统一占位，没有为本功能新建 live 图片管线。
4. 人工 Xcode 26 `simctl io rotate` 不可用；旋转依赖实际 XCUITest
   orientation/regular-compact 证据。没有进行真机或大规模压力测试。
5. Live 列表点击会以正确 threadID 进入现有 ThreadReader，但阶段 11 的
   Production Live Thread 仍 evidence-blocked；真实帖子正文未在本阶段验证。
6. 阶段 11、12、13 既有 `RUNTIME_EVIDENCE_PARTIAL` 不变，AuthContext 恢复问题
   不在本阶段处理。

## 停止点

`PHASE_14_FORUM_HOME = COMPLETE`，`PHASE_15 = NOT_STARTED`。本轮在阶段 14
停止，不自动实现分页或阶段 15。
