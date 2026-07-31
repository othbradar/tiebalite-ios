# 阶段 17：iPadOS、旋转、分屏和多窗口尺寸硬化

架构从第一天支持 iPad，本阶段做系统性验证和缺口修复，不另写一套 iPad 业务层。

## 前置

- P0 iPhone 核心链路绿色。
- ADR-0003 已定义宽/窄映射。
- 使用实际可用 iPad Simulator；记录型号/runtime。

## 必须验证的宽度/方向

- 11/13 英寸类全屏横屏与竖屏。
- 至少一个约半屏宽度。
- 一个窄到 SplitView 折叠的宽度。
- 运行中 resize，而非只冷启动不同尺寸。

## 用户流

1. 推荐→帖子→图片→返回。
2. 关注吧→吧首页→帖子→返回。
3. 吧/帖子选择在 SplitView 展开与折叠间保持。
4. Search（若实现）键盘和结果。
5. Sheet/MediaViewer 在 resize、旋转中保持正确层级。

## 修复规则

- 根据可用宽度和系统容器布局，不检测具体 iPad 型号。
- 不使用 `UIScreen.main.bounds`。
- 不通过 duplicated iPadView 重写业务 Store。
- Sidebar/detail selection 和 NavigationPath 有单一映射，不双向死循环。
- resize 时不重置列表、current media index、zoom 或 session。
- 过窄时内容自适应/换行，不用固定 frame 裁切。

## 测试

- UI tests 覆盖宽/窄启动和关键 route。
- Computer Use 手工执行运行中 resize/旋转，附证据。
- Pager/MediaViewer 重新跑 resize 矩阵。
- Dynamic Type + split view 组合。

## 验收

- 无遮挡、白块、详情错配、重复导航、状态丢失。
- iPad 与 iPhone 共享 Feature/domain/data 实现。
- `make quality` 和 iPad 专项 test plan 通过。

停止。
