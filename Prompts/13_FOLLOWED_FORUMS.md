# 阶段 13：我关注的吧

实现登录/未登录两种完整体验，先 fixture 后 live repository；不实现关注/取消关注等写操作。

## 前置

- Session 状态机绿色。
- 关注吧 endpoint/proto 在 API evidence 中有证据。
- App Shell 的关注 Tab 已有稳定 route。

## 状态与行为

### 未登录

- 明确的 signed-out 空态和登录入口。
- 不自动弹出登录页阻断其他 Tab。
- 登录取消后仍保持当前页面可用。

### 已登录

- 首次、成功、空、失败、刷新。
- 若接口分页，按证据实现并测试；没有分页证据不得自行添加。
- 稳定 forum ID 去重。
- 行显示吧头像、名称、等级/未读等仅限证据字段。
- 点击进入 `ForumRoute(forumID, name)`。
- 返回后列表和滚动位置保持。

### Session 失效

- 保留非敏感缓存的策略按 ADR。
- 页面进入统一 expired/signed-out 表达，不重复弹窗。
- 重新登录后明确刷新行为。

## 实现顺序

1. fixture states 和 Store tests。
2. fixture UI 与 route tests。
3. live repository request/mapper tests。
4. Debug live smoke。
5. 完整回归。

## 测试

- 未登录→登录 fixture→列表。
- 登录取消。
- 登录过期。
- refresh failure 保留旧列表。
- 大量吧列表快速滚动和头像复用。
- 打开吧首页返回位置。
- 深色、大字体、iPad。

## 禁止

- 不在 row 中直接请求头像外的业务数据。
- 不用 session Bool 分散在 View。
- 不实现远端关注/取消关注。
- 不为该页面复制错误/加载组件。

## 验收

- Fixture UI tests 稳定。
- Live 能力诚实记录。
- Session 和 route 无重复状态源。
- `make quality` 通过。

完成后停止。
