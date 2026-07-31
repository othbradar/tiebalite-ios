# 阶段 09：将已验证 MediaViewer 升为唯一生产组件

只有阶段 06 标记 `SPIKE_ACCEPTED` 时执行。否则停止并报告前置不满足。

## 目标

把实验组件清理为 `InteractionKit/MediaViewer` 唯一生产实现，接入可注入 ImageLoading，但暂不接完整帖子页。

## 必须完成

- 删除或隔离被拒绝的实验实现，防止后续误用。
- 公共 API 只暴露稳定媒体 ID、初始 index、图片请求描述和关闭/页变更事件。
- 内部 UIKit/SwiftUI bridge 生命周期完整。
- 每页 zoom/pan 状态归属明确；复用/删除页面可预测。
- 邻页预取策略有上限；取消不可见的大图请求。
- 背景使用语义 `mediaBackground`，加载/失败不露白。
- chrome、安全区、状态栏策略统一。
- 支持 Reduce Motion。
- accessibility：当前索引、关闭按钮、图片描述。

## 手势契约

按 ADR 实现并测试：

- 单击 chrome。
- 双击缩放。
- 捏合/平移。
- zoom 与分页仲裁。
- 首尾边界。
- 系统 dismiss/返回。

首版不擅自加入下滑关闭。

## 回归

重复阶段 06 全矩阵，在生产路径运行。额外验证：

- 50 次打开/关闭无 overlay 残留。
- 快速浏览多张大图，内存不会持续单调增长到不可接受。
- 加载任务在关闭/切页后正确取消或降级。
- 切换深色/旋转/resize 不露底。

## 验收

- 仓库只有一个可被 Feature 使用的 MediaViewer。
- 所有 interaction tests 通过。
- 报告明确新增动画、手势和 UIKit bridge。
- `make quality` 通过。

完成后停止。
