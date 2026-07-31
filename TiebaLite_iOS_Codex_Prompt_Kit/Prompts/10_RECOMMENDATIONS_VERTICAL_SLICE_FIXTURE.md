# 阶段 10：推荐 → 帖子首屏 → 图片 → 返回的 Fixture 垂直链路

这是第一个完整用户链路，但必须完全使用 fixture/mock，不能接 live 贴吧。目标是先证明状态、导航、滚动、Pager 和 MediaViewer 稳定。

## 前置

- App Shell、状态组件、测试底座、内容 Renderer、生产 MediaViewer 绿色。
- 推荐与帖子首屏的领域 mapper/fixtures 可用。
- 先写完整状态机和验收测试清单。

## 推荐 Feature

实现：

- initial/loaded/empty/failure。
- refresh 保留旧内容。
- pagination 保留旧内容、尾部错误重试。
- 稳定 thread ID 去重。
- 请求代次和取消。
- 主题行：标题、吧名、作者/摘要/统计/缩略图等仅按证据显示。
- 稳定 accessibility identifiers。

## Thread 首屏

- 点击推荐主题进入 Thread route。
- 显示帖子元信息、首批楼层、已支持内容节点。
- 加载/空/失败使用统一状态组件。
- 点击图片打开唯一 MediaViewer，并从正确 index 开始。

## 返回不变量

必须自动化验证：

1. 推荐加载并滚动到中后部。
2. 打开某主题。
3. 滚动帖子并打开第 N 张图片。
4. 左右切图、缩放、关闭。
5. 帖子仍在原附近位置。
6. 返回推荐，推荐列表、分页数据和滚动锚点保持。
7. 切换 Tab 再返回，状态仍保持。

## 必测场景

- recommendations.success / empty / initial-error。
- refresh success/failure。
- next-page success/failure/duplicate IDs。
- stale refresh response。
- thread success/malformed-node/image-failure。
- Reduce Motion、深色、大字体。
- iPhone；涉及 Media/导航时至少一个 iPad Simulator smoke。

## 禁止

- 不接 live 网络。
- 不在行 `onAppear` 无防护分页。
- 不使用 UUID 刷新、根动画、自定义 push。
- 不因图片未加载把页面替换成透明/空 View。
- 不复制第二套 MediaViewer/Pager。

## 验收

- 上述链路在 XCUITest 与 Computer Use 手工流程均通过。
- 没有白块、遮挡、错页、跳顶或状态丢失。
- State tests 覆盖取消/乱序/分页去重。
- `make quality` 和 `/review` 无 P0/P1。

完成后停止。
