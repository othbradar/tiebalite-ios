# 阶段 17：iPadOS 自适应布局与 resize 审计

- 日期：2026-08-31
- 基线：`6e95bc8b17d0f9b5c788a34d6758145115b79620`
- Android reference：`5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`
- 状态：`PHASE_17_IPADOS_ADAPTIVE_LAYOUT = COMPLETE`
- 门禁：`PASSED_STAGE_17F_REQUIRED_GATES`
- 后续阶段：`PHASE_18 = NOT_STARTED`

## 范围与根因

既有 compact `TabView + NavigationStack` 与 regular 三列
`NavigationSplitView` 已共享 canonical `AppNavigationStore` 和 Feature registry，
无需重写 App Shell。稳定复现的问题位于布局分支替换的生命周期边界：SwiftUI
teardown 会触发 View-local cancellation，导致仍在 canonical route 中的请求被
取消后重启；View-local 历史 once token 也会随重挂载丢失。UIKit 虚拟列表还会在
数据完全相同的普通 width update 中重复提交 diffable snapshot，并在 teardown 时
没有先保存当前顶部业务锚点。

本阶段只修这些实际问题。没有修改 PBPage/FRS/推荐分页协议、业务 Row identity、
Pager ownership、MediaViewer 手势、ThreadContentRenderer、Session/Keychain，
也没有新增业务功能、动画、手势、overlay 或依赖。

## 实现结果

- 推荐、关注吧、ForumHome、ThreadReader 的 Store-owned operation 跨 projection
  teardown 存活；route 真正 pop 后仍由 registry 取消并释放。Search 只在
  `.search` 从全部 canonical root path 消失后取消。
- Forum/Thread/UserProfile 展示 claim 归稳定 route Store 所有，避免 resize
  重复历史记录；业务 identity 仍为 forumID/threadID/userID。
- `VirtualizedList` 对相同顺序、相同稳定 ID、相同值直接 no-op；同 ID 值变化
  仍 `reconfigureItems`，增删/重排仍 apply 原 diffable snapshot。dismantle
  在解绑前发布当前顶部稳定 ID；没有调用 `reloadData`。
- UITESTING-only viewport harness 使用实际父宽提供 full、约半宽与
  320–390pt narrow 代表性尺寸，不向生产代码引入 `UIScreen`、设备型号判断或
  固定 sidebar/detail 宽度。

## 运行证据

- Stage 17 Unit：9 个直接行为用例通过；全量 Unit 346 个逻辑测试、
  365 次执行、0 失败。
- iPhone：ForumHome → ThreadReader → 中部楼层，横/竖屏往返后仍为同一楼层，
  系统返回到原帖子行，1/1 通过。
- iPad：landscape full → compact narrow → regular full 后同一帖子、中部楼层、
  table 宽度与返回锚保持；Settings route 在 regular/compact/regular 保持；
  MediaViewer 旋转后页码/chrome 保持，关闭回同一线程和图片节点，3/3 通过。
- `make secret-scan`、`make lint`、`make test-unit`、`make quality-fast`、
  `git diff --check` 与 Android submodule clean 检查通过。
- 完整 `make quality` 已真实执行，在 iPad smoke 停止：
  `20260831-110404-20721-ui-smoke-ipad.xcresult` 为 11/12，唯一
  失败是既有长帖图片动作在部分裁切 frame 中查询
  `isHittable` 时的 XCTest `Activation point invalid`。恢复原 helper
  后重跑完整 iPad smoke，
  `20260831-121928-47224-ui-smoke-ipad.xcresult` 仍为 11/12，
  相同失败重现。
- 相同用例独立连续 3/3 通过；Stage 17 iPad full/narrow/full、
  Settings split 与 MediaViewer 旋转返回定向场景 3/3 通过。
  两个只调整 UI test helper 的小步试验均未使整套稳定，
  已完整撤回；没有因门禁失败修改生产 Renderer/MediaViewer。
- 独立只读 review 未发现 P0/P1：无 UUID 强制刷新、UIScreen 分支、固定延迟、
  透明 blocker、魔法 zIndex、无界 cache 或共享交互越界。

## 阶段 17F：XCUITest 隔离收口

- 在同一 iPad Pro 13-inch (M5) / iOS 26.5 Simulator 手工启动
  Fixture 长帖，滚动到对应图片并直接点击：MediaViewer 正常打开，
  关闭后回到原 ThreadReader。按钮 accessibility frame 非空且与
  window 相交，没有透明 overlay、sheet 或残留 `fullScreenCover`。
  不存在稳定生产复现。
- 失败根因定性为 XCUITest suite-state/hit-testing isolation flake：
  套件内前序方向/投影与 UITableView cell reuse 会使旧 `XCUIElement`
  的 activation point 过期，而单独运行不稳定出现。
- 测试隔离修改仅位于 `FixtureReadingUITestSupport` 和
  `IPadAppShellSmokeTests`：终止/固定 Fixture 重启、明确横屏、根 sentinel、
  每次滚动后重查目标，并验证按钮 frame 四边完整包含于
  container/window/app 交集。首次稳定目标 `isHittable` 为 false
  后，只有重查 frame 仍稳定、按钮启用且无 overlay，才点击该
  完整 frame 中心；随后仍必须断言 MediaViewer 打开、位置与关闭返回。
  没有 sleep/asyncAfter、expected failure 或生产 hit-testing 修改。
- 最终结果包：
  - `stage17f-independent-5x-final.xcresult`：目标用例 5/5；
  - `stage17f-predecessor-combo-3x-final.xcresult`：前序+目标共 6 次执行，
    目标在前序后 3/3；
  - `20260831-145446-79392-ui-smoke-ipad.xcresult`：iPad smoke 12/12；
  - `20260831-150448-85940-ui-interaction-ipad.xcresult`：iPad interaction 2/2；
  - `20260831-153244-1534-unit.xcresult`：346 个逻辑 Unit、365 次执行。
- `make release-isolation`、`make quality-fast` 和最终 `git diff --check`
  通过；Android reference/submodule 保持 clean。根据 17F 授权，没有
  重复从头执行已通过的 iPhone smoke/interaction 或完整
  `make quality`。没有为测试修改生产 UI、Renderer、Pager、
  MediaViewer、VirtualizedList 或业务 identity。

阶段 16A 也在原 iPhone 17 Pro / iOS 26.5 Simulator 的生产构建中完成一次
可见补验：原 Keychain 会话恢复；Live 搜吧进入 ForumHome 并返回；Live 搜帖
进入 ThreadReader 并返回，关键词与结果保持。没有 logout、凭证读取或日志输出，
因此 `PHASE_16A_SEARCH` 与 `PHASE_16` 更新为 `COMPLETE`。

## Known Limitations

1. 没有穷举所有 iPad 型号、所有精确 Split View 比例、iOS 18.x 或真机。
2. 自动化窄宽是父容器 viewport 模拟；真实 divider 拖动和 Stage Manager/
   多窗口 resize 留到发布前手工矩阵。
3. 系统 `fullScreenCover` 覆盖 UIWindow；Media 用例证明旋转与正确返回，
   不把子内容窄宽冒充真实 Stage Manager presentation。
4. 真机 VoiceOver 留到阶段 18。本阶段没有进入阶段 18。
5. 17F 之后未重复从头执行已在同一工作树通过的 iPhone
   26 项 smoke、15 项 interaction 或完整 `make quality`；受影响的
   iPad/Release/quality-fast 最小门禁已全部通过。
