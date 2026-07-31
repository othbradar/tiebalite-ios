# 阶段 14：吧首页与吧内主题列表

目标：实现 FRS/吧页的完整只读浏览，包括吧信息、置顶/普通主题、排序/分区、刷新和分页，同时保持交互统一。

## 前置

- Forum endpoint/proto/API evidence 足够。
- 关注吧 route 可进入占位 Forum 页面。
- PagerContainer 若产品规格要求横滑分区，必须已 Accepted；否则优先用系统 selector + 单列表，不自行发明横滑。

## 状态拆分

吧头信息和主题列表可能独立加载，必须定义：

- HeaderState。
- 每个 filter/sort 的独立 PagedState。
- 当前 selection。
- refresh/header failure/next-page failure。
- 旧请求与切换 selection 的隔离。

禁止一个 `isLoading` 管全部状态。

## 功能

- 吧名称、头像、简介、关注数等仅按证据显示。
- 主题行支持置顶、普通、删除/缺字段、图片摘要及已证实特殊类型。
- sort/filter 列表来自服务端证据或固定产品规格。
- 每个 selection 保留自己的 items、cursor、error、scroll anchor。
- 快速切换 selection 时取消/忽略旧响应，不能串页。
- refresh 保留当前内容；next-page error 使用尾部重试。
- 打开帖子→返回，吧列表状态和位置保持。

## 交互

- selector、下拉刷新、分页、错误反馈与推荐流复用同一标准。
- 如果使用 Pager：只调用唯一 PagerContainer，不在 Feature 中处理 DragGesture。
- iPad 侧栏选吧、详情列表、帖子详情按 route/size class 映射。
- 不叠加自定义导航动画。

## Fixture 场景

- success/empty/initial-error。
- header-only failure/list-only failure。
- pinned + normal + deleted + malformed。
- refresh failure。
- next-page failure/duplicate IDs。
- two filters with crossed stale responses。
- large titles/dark/dynamic type。

## Live 接入

UI fixture 通过后才接 live repository。每个 sort/filter 的请求参数必须有 API evidence。没有证据的选项不显示。

## 验收

- 快速切换/刷新/分页无重复请求、串页、跳顶或白块。
- 打开帖子返回状态保持。
- iPhone/iPad smoke 通过。
- `make quality` 和 interaction review 通过。

完成后停止。
