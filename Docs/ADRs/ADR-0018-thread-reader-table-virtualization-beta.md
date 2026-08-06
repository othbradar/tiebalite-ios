# ADR-0018：ThreadReader 使用薄 UITableView 虚拟化承载层

- 状态：Accepted
- 日期：2026-08-06
- 决策者：阶段 15 长帖性能定向修复
- 关联阶段：08、09、10、15、14P
- 扩展：ADR-0017 的帖子展示与分页提交策略

## 背景与证据

阶段 15 的原始生产实现是一个 SwiftUI `ScrollView + LazyVStack`，每个普通
楼层是顶层 item，内部继续使用现有 Renderer 和非滚动楼中楼预览。31 楼
Fixture 在首次滚动时稳定卡死；一次主线程 sample 的 1056/1056 个样本持续落在
SwiftUI lazy placement、layout 和 AttributeGraph 调用链。Repository、网络、
图片解码、Store Task、`scrollPosition` 与 `scrollTargetLayout` 已分别排除为
单独根因。

按同一 Fixture、Store、route 和首次滚动步骤只做一轮 A/B：把真实可变高度楼层
替换成固定 120pt 文本 Row 后，iPhone UI smoke 1/1 通过且首次滚动正常；恢复
真实 Row 会回到稳定卡死。证据只支持“复杂可变高度楼层与 SwiftUI lazy placement
组合在当前 Xcode/iOS runtime 不可靠”，不把某个内部 hash 或私有实现细节声明为
唯一根因，也不把一次观察写成跨系统性能基准。

## 决策

1. ThreadReader 只有一个生产列表：薄 `VirtualizedList` 使用 `UITableView`、
   单 section `UITableViewDiffableDataSource` 和 `UIHostingConfiguration`。
   不保留 SwiftUI `LazyVStack` fallback，不新增第二个 ThreadReader 页面。
2. 虚拟化粒度是一楼一个顶层 row。header、首楼、普通楼层和分页 footer 都在
   同一 snapshot；楼中楼只在对应楼层内用普通 `VStack`，最多显示服务端返回的
   4 条预览，更多内容只显示“查看全部 N 条回复”。
3. `ThreadReaderRowID` 只由 threadID、postID 与确定性分页状态构成。普通楼层
   禁止 index/UUID identity；内容节点继续由唯一 `ThreadContentRenderer` 处理。
4. `ThreadReaderListPresentation` 在 Store 提交前准备作者、时间、楼层、document、
   内联楼中楼和 MediaIntent 所需领域值。cell provider 不做 Proto 映射、排序、
   去重或全列表扫描。
5. 下一页按 postID 去重保序，diffable snapshot 禁用动画并保留已有 item identity；
   retained item 只有值变化时才 `reconfigureItems`，禁止 `reloadData`。分页由末 4
   个楼层的 table prefetch 触发，Store 的单 Task、page/generation 和 hasMore
   继续负责重复抑制及迟到结果拒绝。
6. UITableView 自己保持连续 offset；Store 只在拖动/减速/程序滚动结束时记录
   顶部稳定 post row，不在布局回调写状态。MediaViewer present/dismiss 不销毁
   table，返回继续显示原附近楼层。
7. HostingConfiguration 在 `prepareForReuse` 时清除，使该 Row 的 SwiftUI task
   （包括图片 task）取消；容器拆除时清除所有仍存活的 hosted cell、delegate、
   data source、prefetch source 和 snapshot 映射。不得在 `didEndDisplaying` 提前
   清除，因为 self-sizing/回弹期间同一 cell 可在未 reuse 时再次可见。
8. 承载层只公开 items、稳定 ID、row builder、prefetch 和 settled anchor，
   不含帖子、吧首页或 FRS 业务语义。阶段 14 生产代码本轮不接入、不修改；14P
   若复用，只能消费这份已经验证的最薄能力。

## Debug、测试和 Release 边界

`DebugStage15LongThreadFixtureRepository` 生成 1000 个稳定楼层，按 5×200 页
追加，混合长短文本、图片、1～3 条楼中楼和少量折叠态。Debug App 可用
`--stage15-long-thread-lab` 打开同一生产 ThreadReader；Release 通过 `Debug*.swift`
source exclusion 和 release-isolation 排除该入口及 fixture。

确定性组件测试把 production table 放入 390×844 window，依次应用
200/400/600/800/1000 row snapshot，跳到 1000、500、1 楼并验证稳定 ID、
前 200 楼值保持、reuse 大于 0、创建 cell 数量不超过 4 个峰值 viewport，且
拆除后 data source/task/table 可释放。该上界证明没有同时建立 1000 个 hosted
cell，不宣称精确 FPS 或内存峰值。

## 结果、限制与回滚

31 楼 Fixture 的 iPhone 主链路连续 5 次首次滚动通过；Debug 1000 楼首屏可
立即滚动。第一次 table 手工检查暴露 `didEndDisplaying` 过早清空造成的空白
cell，已由失败回归测试锁定并改到 reuse 边界；复验连续滚到 32 楼无空白。

当前仅为个人开源 Beta：一次 Simulator A/B 不是统计基准；1000 楼合成 fixture
不等同于 1000 楼 Live 图片压力；领域 snapshot 仍持有 1000 个值对象；未运行
真机、iOS 18、50 页、长期 Instruments 或极端单楼超长富媒体矩阵。若同一真实
Row 在 table 路径再次稳定卡死，先保留 snapshot/diagnostics 复现并回滚到本 ADR
前绿色提交，不复制第二套列表或通过延迟、遮罩、随机 ID 掩盖。
