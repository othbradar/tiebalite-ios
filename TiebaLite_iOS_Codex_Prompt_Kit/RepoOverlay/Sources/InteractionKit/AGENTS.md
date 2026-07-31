# InteractionKit 目录约束

这是唯一允许实现复杂手势、分页容器和 UIKit 桥接的目录。

- 业务 Feature 禁止复制 Pager、缩放、拖拽关闭或边缘返回逻辑。
- 每个组件先写交互契约和状态图，再写实现。
- UIKit coordinator 必须明确生命周期、delegate 解绑、复用重置和主线程要求。
- 不在 SwiftUI update 回调中无条件重设当前页、zoomScale 或 contentOffset。
- 页面/图片 ID 必须稳定；更新数据时保留仍存在页面的身份。
- 转场期间保留当前页和相邻页，背景不透明，不用空 View 作为加载占位。
- 手势冲突必须以手势状态、方向锁、zoomScale 和系统边缘返回优先级解决，不用延迟或透明遮罩。
- 组件测试至少覆盖：快速连续滑动、半途取消、反向滑动、数据插入/删除、旋转、iPad 尺寸变化、Reduce Motion、图片失败。
- 修改后必须运行交互专项 UI tests，并用 Simulator/Computer Use 完整走一遍契约场景。
