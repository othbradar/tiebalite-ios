# 阶段 18：可访问性、性能、内存与故障韧性硬化

本阶段不新增产品功能，只查证和修复质量问题。建议 Ultra 只读并行审计；主代理唯一写入。

## A. 可访问性

审计所有 P0 流程：

- VoiceOver label/value/hint、阅读顺序、重复元素。
- 点击区域和按钮语义。
- Dynamic Type 默认及无障碍大字号。
- 深色/高对比语义颜色。
- Reduce Motion。
- 图片替代文本/装饰标记。
- 错误和 loading 的可访问性公告不过度重复。

输出 `Docs/Audits/ACCESSIBILITY_AUDIT.md`。

## B. SwiftUI/主线程性能

使用 Xcode/Instrument 或可用的 SwiftUI profiling：

- 推荐列表滚动。
- 大帖子滚动。
- 分页插入。
- 图片 decode/显示。
- Tab/导航切换。

检查：

- body 计算和不稳定 identity。
- 主线程 Proto decode/map、磁盘或大图处理。
- 重复网络请求。
- 过度 state invalidation。
- 大量无必要动画 transaction。

先建立可重复 fixture 基线，再优化。禁止凭感觉微优化。

输出 `Docs/Audits/PERFORMANCE_AUDIT.md`，记录设备、scenario、测量方式、前后数据和不确定性。

## C. 内存

- 多图快速浏览后资源释放。
- 退出 MediaViewer 后 full-resolution 缓存有上限。
- 大帖子、切换多个帖子、前后台。
- UIKit coordinator/delegate/callback 无引用环。
- 取消不可见请求。

## D. 网络故障韧性

使用 mock chaos matrix：

- 延迟、乱序、丢包式失败、超时、500、畸形 Proto、空 body。
- Session 过期与匿名 fallback。
- 快速刷新/分页/切换 Tab/关闭页面。
- App 进入后台与恢复。

不得靠无限重试。重试次数、幂等性和用户触发策略明确。

## E. 稳定性扫雷

搜索并处理：

```text
try! / as! / fatalError / force unwrap
Task.detached
DispatchQueue.main.asyncAfter
.id(UUID())
UIScreen.main.bounds
根节点 .animation
重复 DragGesture/overlay/zIndex
空 catch / ignored error
```

并非机械替换；每处写明风险和修复证据。

## 验收

- 所有 P0 流程通过可访问性和故障矩阵。
- 性能/内存有可复现基线与无明显回归证据。
- 静态禁用模式无未经批准命中。
- 完整 test plans 和 `make quality` 通过。

停止。
