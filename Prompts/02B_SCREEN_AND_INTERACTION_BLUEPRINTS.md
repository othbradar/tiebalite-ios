# 阶段 02B：逐屏 UI、状态与交互蓝图

本阶段把已批准的产品/架构规格转化为可验收的页面蓝图。只写 Specs/Docs/测试计划，不创建 Swift 生产 UI。

## 目标

在 Codex 生成任何业务页面前，冻结每个 P0 页面在所有主要状态下的结构、信息层级、滚动容器、导航、手势、安全区、动效、iPad 映射和可访问性。不得只给一张“漂亮首页”草图。

## 必须创建

```text
Specs/Screens/
  AppShell.md
  Recommendations.md
  FollowedForums.md
  ForumHome.md
  ThreadReader.md
  MediaViewer.md
  SessionLogin.md
Specs/Flows/
  RecommendationsToThreadToMediaAndBack.md
  FollowedForumToForumToThreadAndBack.md
  SessionExpiration.md
Specs/COMPONENT_CATALOG.md
Specs/ACCESSIBILITY_IDENTIFIERS.md
Specs/LAUNCH_SCENARIOS.md
Docs/Audits/BLUEPRINT_REVIEW.md
```

## 每个 Screen 文档必须包含

1. 用户目的与非目标。
2. route 输入、单一状态来源和 Store 生命周期。
3. 页面区域顺序及每区字段来源。
4. initial/loading/loaded/empty/initial error/refresh/next-page error/session expired/unsupported data。
5. 唯一主滚动容器、滚动锚点和返回恢复规则。
6. toolbar、safe area inset、sheet/overlay 的所有权、z-order 和 hit testing。
7. 允许的用户事件与状态转换。
8. 导航进入/返回及 iPhone/iPad 宽窄映射。
9. 自定义动效语义、Motion token、Reduce Motion 路径；没有必要则写 `NO_CUSTOM_MOTION`。
10. 手势所有者与冲突优先级；Feature 页面默认 `NO_CUSTOM_DRAG_GESTURE`。
11. Dynamic Type、VoiceOver、深色、高对比和长文本/坏数据策略。
12. fixture scenario 与自动化/Computer Use 验收步骤。
13. Android 证据、运行证据、iOS 原生调整和 UNKNOWN。

## 视觉与布局规则

- 不指定固定屏幕像素布局；使用语义间距、可用宽度和系统容器。
- 不为 iPad 复制另一套业务页面。
- 不通过 skeleton 高度变化造成内容跳动；占位与最终结构要有稳定几何契约。
- 列表行必须定义稳定 ID、可点击区域、图片尺寸策略、长标题和无图降级。
- 同一状态/动作在不同页面复用同一组件和反馈，不创建局部变体。
- 系统 push/pop/sheet 使用系统动效，不要求“完全复制 Android 动画”。

## Flow 文档必须包含

逐步列出：Given、用户动作、route/state 变化、可观察 UI、取消/失败分支、返回后应保留的状态、需要的 identifier 和测试断言。至少覆盖：

- 推荐滚动 → 帖子滚动 → 第 N 图 → 缩放/切图 → 关闭 → 返回推荐并保持位置。
- 关注吧 → 吧首页切换分区/分页 → 帖子 → 返回并保持每层状态。
- 会话在请求中失效 → 单一全局状态转换 → 页面安全降级 → 重新登录后的恢复。

## 审查

使用 `$ios-architecture-review` 和 `$ios-interaction-qa` 只读检查蓝图内部是否存在：重复状态源、重复 Pager、overlay 常驻、滚动嵌套、自定义返回手势、任意动效、iPad 双状态或无法自动化的模糊验收。

## 验收

- 每个 P0 页面都能由规格直接写测试，不需要实现者临时决定关键交互。
- 所有跨屏状态保持有明确 owner。
- 组件目录没有多个同义 loading/error/pager/media 变体。
- UNKNOWN 仍显式，未用视觉设计掩盖协议未知。
- `/review` 无 P0/P1 文档矛盾。

完成后停止。
