# 阶段 08：帖子内容领域模型与只读渲染器

本阶段只实现内容节点映射与隔离 Renderer Lab，不做完整帖子分页页面。

## 前置

- `Specs/CONTENT_NODE_MATRIX.md` 有代码证据。
- SwiftProtobuf 基础与 fixture loader 绿色。
- 先选取覆盖实际节点的脱敏 fixtures。

## 领域模型

建立与 UI/Proto 解耦的内容节点，例如：

- text
- image
- link
- emoji
- mention/quote
- line break/layout marker
- 已证实的其他节点
- unsupported/unknown

不要先假设节点集合；以矩阵为准。领域模型必须：

- Sendable、稳定 ID 或稳定顺序语义。
- 能表达缺字段和降级文本。
- 不包含 SwiftUI `View`、Proto message 或网络对象。

## Mapper

- 按 Proto 节点顺序映射，不能丢失相邻文本。
- 无效图片 URL/尺寸安全降级。
- 未知 enum/节点生成 UnsupportedNode，不崩溃。
- 链接展示文本与目标分离。
- 超长、空、删除/屏蔽内容有明确结果。

## Renderer Lab

- 使用标准 typography/color/spacing。
- 文本支持 Dynamic Type 和选择策略（按规格）。
- 图片占位与最终 frame 稳定，点击只触发统一 Media route。
- 链接使用统一外链策略。
- unknown node 显示低干扰占位或可读文本。
- 不加入任意动画、横滑或全屏 overlay。

## 测试

- 每种 P0 节点至少一个 mapper test 和 renderer smoke fixture。
- 混合节点顺序测试。
- 缺字段、未知 enum、坏 URL、超长文本、大字号、深色模式。
- Renderer 不直接请求网络；ImageLoading 可注入。

## 验收

- 内容矩阵中所有 P0 节点为 Supported 或明确 Degraded。
- 未知内容不崩溃、不吞相邻内容。
- 领域模型不泄漏 Proto。
- Renderer Lab UI smoke 通过。
- `make quality` 通过。

停止，不做完整 ThreadScreen。
