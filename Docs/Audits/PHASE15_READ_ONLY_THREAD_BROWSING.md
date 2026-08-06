# 阶段 15：只读帖子浏览与长列表虚拟化审计

- 基线：`bf0a0884bcda44aab1a159b756e45d41f0d3c367`
- Android reference：`4.0-dev@5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`
- 范围：PBPage 首屏/下一页、楼层、内联楼中楼、Fixture/Live Repository、
  ThreadReader 单一虚拟列表与直接测试
- 明确非范围：阶段 14 生产列表/FRS 分页、完整 PB Floor、写操作、Live 图片、
  Pager/MediaViewer/Renderer 核心修改、阶段 16

## Android 与协议证据

锁定 Android `ThreadPage.kt` 使用唯一顶层 `LazyColumn`；每个 `Post.id` 是一项，
内联 `SubPostList` 位于该楼层的普通 `Column`，请求 `floor_rn=4`，没有嵌套
滚动容器。分页接近最后 3 项触发；mapper/reducer 以 PostID 去重保序并保留
失败前内容。iOS 沿用这些原则，但不复制 Android 的 500ms sample 或缺少严格
同页互斥的 intent 排队行为。

PBPage 证据和实际匿名两页结果记录在 ADR-0017：首屏 HTTP 200、
`application/octet-stream`、24,567 bytes、Proto decode 成功，含首楼、16 个
普通楼层、60 条内联楼中楼且 has-next；第二页 HTTP 200、17,106 bytes、15 个
普通楼层。Probe 未记录 Cookie、完整请求/响应、threadID、标题或用户内容。

## 状态、映射与分页结果

- `ThreadReaderPageRequest` 首屏为 `pageNumber=0/postID=0`；下一页使用响应
  `currentPage + 1` 和已证 `ThreadInfo.pids` cursor。
- mapper 安全处理缺首楼的后续页、非法 pids、缺作者、未知节点、折叠态与单楼
  映射失败；生成 Proto 不进入 View。
- Store 只有一个 load Task 和递增 generation。下一页保留 previous；失败显示
  retry footer；取消恢复 previous；同页重复、迟到或错误 threadID 不提交。
- Beta gate 只允许首屏 `has_more` 产生一页 next；任何后续页强制 terminal，
  不把第二页 wire `has_more` 猜成已验证的第三页能力。
- 两页 Fixture 第一页 17 个顶层 post（首楼 + 16 回复），第二页包含一条重叠
  post 加 15 个新回复；最终严格 32 个唯一 postID，服务器顺序不变。
- 楼中楼按稳定 subpost ID 内联最多 4 条；total 大于 preview 时显示总数提示，
  不把楼中楼拆成 table 顶层项。

## 卡死定位、A/B 与生产方案

原 `ScrollView + LazyVStack` 的 31 楼真实 Row 首次滚动稳定卡死；主线程 sample
`/tmp/TiebaLite_2026-08-05_231850_6J1A.sample.txt` 的 1056/1056 个样本位于
SwiftUI lazy layout/placement/AttributeGraph 调用链。固定 120pt 文本 Row 的
单次 Debug A/B 使用同一 Fixture/Store/nav，结果包
`/private/tmp/stage15-lazy-fixed-row-isolation-20260806-1.xcresult` 为 1/1 通过，
20.564 秒。按任务裁决，不继续堆 SwiftUI 补丁。

最终生产 ThreadReader 只有一个 `UITableView + DiffableDataSource +
UIHostingConfiguration`。顶层 row 是 header、firstPost、post 和一个确定性
pagination footer；普通楼层以 threadID/postID 为稳定 identity。snapshot
无动画增量 apply，不调用 `reloadData`，prefetch 只转发末 4 个楼层 ID。

手工长帖初检真实发现：在 `didEndDisplaying` 清空 hosted content 会让回弹中
未 reuse 的同一 cell 重新可见时为空白。修复前结果
`/private/tmp/stage15-hosting-cell-red-20260806-2.xcresult` 确定失败；把清理移到
`prepareForReuse` 后，`stage15-hosting-cell-green-20260806-1.xcresult` 和
`stage15-list-lifecycle-green-20260806-2.xcresult` 通过。额外测试证明 reuse
会取消 hosted SwiftUI task，拆除后全部 task、delegate/data source 和 table
引用释放。

## 1000 楼与实际 UI 证据

- 1000 楼 Fixture 使用 5×200 页，稳定且唯一 postID，混合长短文本、图片、
  楼中楼和折叠态；Store 请求序列严格为 `0,2,3,4,5`，计数依次
  `200,400,600,800,1000`，第 5 页后停止，前 200 楼值保持不变。
- production table component 在固定 iPhone window 应用全部五个 snapshot，
  可跳至 1000/500/1 楼；复用计数大于 0，创建 cell 保持在最多 4 个峰值
  viewport，未构造 1000 个 SwiftUI cell；拆除后 weak table 释放。
- Debug 长帖入口使用无凭证 iPhone Air Simulator；另以
  `SWIFT_OPTIMIZATION_LEVEL=-O` 构建同一入口作接近 Release 的手工检查。
  两轮修复后复验均连续完成 5 次系统滚动，优化构建最终显示 25～31 楼；
  首屏无等待，未见数秒主线程卡死、空白楼层、遮挡或错页。该入口与 fixture
  不进入正式 Release。
- 原 31/32 楼 Fixture iPhone 主链路结果包
  `/private/tmp/stage15-iphone-thread-table-20260806-2.xcresult` 为 1/1 通过；
  每次先连续 swipe 5 次，再验证第二页末楼、楼中楼、图片 loaded、唯一
  MediaViewer 打开/关闭和返回位置。iPad 定向结果包
  `/private/tmp/stage15-ipad-thread-table-20260806-1.xcresult` 同样为 1/1 通过。

## 自动化与门禁

阶段 15 定向 Unit 最终为 15/15，覆盖 PBPage request/mapper、分页/去重、失败
重试、取消、route teardown、稳定 row identity、1000 楼增量 snapshot、
复用/释放、空白 cell 回归和 hosted task 取消。

最终完整门禁实际结果：

- Unit：275 个逻辑测试、294 次执行、0 failure；
  `Artifacts/TestResults/20260806-100432-13175-unit.xcresult`；
- iPhone smoke：19/19；
  `Artifacts/TestResults/20260806-100503-13542-ui-smoke.xcresult`；
- iPhone interaction：15/15；
  `Artifacts/TestResults/20260806-101617-14657-ui-interaction.xcresult`；
- iPad smoke：6/6；
  `Artifacts/TestResults/20260806-104821-16949-ui-smoke-ipad.xcresult`；
- iPad interaction：2/2；
  `Artifacts/TestResults/20260806-105328-17396-ui-interaction-ipad.xcresult`；
- `make quality-fast`：首轮仅因新 mapper 未进入精确 GeneratedProtobuf import
  allowlist 而失败；将隔离规则限定为 `PBPageDomainMapper.swift` 的单一 import
  且拒绝 HTTP/UI/storage 副作用后重跑通过；
- `make quality`：退出 0，包含 Release isolation，输出
  `Quality gate completed.`；
- `git diff --check`：文档更新前已通过，提交前再次执行并记录。

## 变更边界

- 新增动画、业务手势、overlay、第三方依赖：无。
- 新增生产 Pager、MediaViewer、Renderer：无；现有三者核心文件未修改。
- 阶段 14 `ForumHomeView`、`ForumHomeStore`、FRS 分页：未修改。
- Live 网络：仅阶段 15 已脱敏 Debug PBPage Probe；自动化完全 Fixture/Mock。
- Android submodule：只读、clean、exact SHA。

## Known Limitations

1. A/B 和手工滚动只在 iOS 26.5 Simulator，不能代表 iOS 18 或真机统计性能。
2. 未做 50 页、长期 Instruments、内存警告或单个极端超长富媒体楼层矩阵。
3. 1000 楼 fixture 图片使用固定小图，不是 full-resolution Live 图片压力；
   Production Live 图片 loader 仍 disabled。
4. 领域层仍保留 1000 个 Sendable 值对象；本阶段只证明 view/cell 生命周期有界。
5. 完整楼中楼页面与 PB Floor 分页仍未实现；当前只展示 PBPage 返回的少量预览。
6. 阶段 14 的 1000 条吧内主题、`thread_id_list` 分批加载与增量分页留给独立
   14P，本轮没有提前修改。
