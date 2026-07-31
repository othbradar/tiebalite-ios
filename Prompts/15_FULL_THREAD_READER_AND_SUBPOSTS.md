# 阶段 15：完整帖子阅读、分页与楼中楼只读浏览

扩展阶段 10 的帖子首屏为生产级 ThreadReader。仍不实现发布回复/评论。

## 前置

- 内容节点矩阵和 Renderer 已验证。
- PB/thread endpoint、分页和楼中楼 endpoint 有证据。
- 推荐、吧页均能进入同一 Thread route。

## 状态模型

至少明确：

- Thread metadata。
- 楼层 paged state。
- 楼中楼按 floor/post ID 的独立 state。
- 当前阅读锚点/选中图片。
- 过滤/只看楼主（仅有证据并在范围时）。
- session 失效对匿名可读内容的影响。

楼层与楼中楼请求不得共享一个错误或 loading Bool。

## 功能

- 楼主/作者、楼层号、时间、内容、删除/屏蔽状态。
- 楼层分页、按稳定 post ID 去重。
- 楼中楼预览、展开、分页、失败重试，只读。
- 贴内所有图片映射到正确媒体集合/index；关闭后锚点保持。
- 外链/提及等按内容契约处理。
- 未知节点降级，不崩溃。
- 大帖子使用惰性列表但保持稳定身份。

## 异步与复用

- 同一楼中楼最多一个在途请求。
- cell 消失不应无条件取消用户已展开内容；由 Store 生命周期管理。
- 快速展开多个楼层的结果不能串行写错目标。
- 新页面返回时旧响应不能覆盖当前 thread ID。
- 切换到另一个帖子后清晰隔离 cache/key。

## 测试

- 首次/分页/失败/重复/乱序。
- 楼中楼成功/空/失败/多楼层同时加载/旧响应。
- 删除楼层、缺作者、未知内容、坏图片。
- 大数据 fixture 快速滚动。
- 推荐→帖子→图片→返回→推荐。
- 吧页→帖子→返回→吧页。
- iPad 三列/折叠路径（按 ADR）。
- Dynamic Type、VoiceOver、Reduce Motion。

## 性能初检

- 不在主线程解码大 payload/图片。
- row body 不执行复杂 mapper。
- 不为每次状态变化重建所有内容节点 ID。
- 使用 signpost 或 Debug metrics 记录 decode/map/render 关键耗时。

## 验收

- 完整只读浏览稳定，写操作不存在或明确禁用。
- Pagination/Subposts 状态测试完整。
- MediaViewer 无回归。
- `make quality` 通过。

完成后停止。
