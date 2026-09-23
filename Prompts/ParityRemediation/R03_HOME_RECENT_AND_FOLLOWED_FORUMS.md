# 执行约束（每个阶段都适用）

本项目是 `othbradar/tiebalite-ios` 的 **Android TiebaLite 视觉与功能一致性整改**。
目标不是让你重新设计一个“更像 iOS 的贴吧”，而是在保留 iOS 系统导航、安全区、键盘和无障碍行为的前提下，尽量忠实复现 `zzc10086/TiebaLite` 最新 `4.0-dev` 的页面层级、信息密度、间距、列表结构、图片排列、标签和交互。

每次执行前必须：

1. 读取仓库现有 `AGENTS.md` 指令链。
2. 显式使用 `$tiebalite-android-visual-parity`。
3. 读取 `Docs/VisualParity/PROJECT_RULES.md`、`ANDROID_UI_REFERENCE.md`、`VISUAL_PARITY_MATRIX.md`。
4. 查看本阶段指定的 Android 源码和参考截图。
5. 检查 `git status --short`，不得纳入用户原有 `.idea`、`.DS_Store`、`Artifacts` 或凭证。
6. 当前阶段只有一个写入 Agent；不要启用并行写入子代理。只读源码搜索可以使用子代理，但结论必须回到主 Agent。

每个阶段的固定结束方式：

1. 只运行本阶段直接相关的 Unit/Smoke、`make lint`、`make build` 或 `make quality-fast`；不要每阶段自动跑完整 `make quality`。
2. 构建 Simulator `.app`，**不卸载 App、不清除 Keychain、不 erase Simulator**，直接覆盖安装。
3. 启动 App，并导航到本阶段目标页面。
4. 保存 iPhone 和必要时 iPad 截图到 `Artifacts/VisualReview/<阶段>/`。
5. 将 App 留在需要用户检查的页面。
6. 输出 `READY_FOR_USER_VISUAL_REVIEW`，说明截图路径、当前页面、验证动作和已知限制。
7. **不得提交、不得进入下一阶段、不得自动继续修外观。** 等用户看完后：
   - 用户要求修改：执行 `Prompts/REVISE_CURRENT_PHASE.md`；
   - 用户明确说通过：执行 `Prompts/APPROVE_AND_COMMIT_CURRENT_PHASE.md`。

视觉硬规则：

- Android 参考截图和源码是视觉/行为真相；不添加玻璃拟态、渐变、大阴影、大圆角卡片、悬浮白色圆形工具按钮等 AI 自创设计。
- 页面主体使用平面背景、紧凑间距和细分割线；只有 Android 原版确实使用 chip、引用框、楼中楼背景、搜索框时才允许小圆角容器。
- 不用 SF Symbol 代替真实用户头像或吧头像；加载失败时使用统一中性占位。
- 不使用随机 `UUID()` 解决刷新，不用 `asyncAfter`、固定 `sleep`、魔法 `zIndex` 或透明遮罩掩盖问题。
- 保留现有高性能 `VirtualizedList`、`UITableView + DiffableDataSource + UIHostingConfiguration`、Pager、MediaViewer、图片 Loader 和稳定业务 ID；除非本阶段明确要求，否则不得重写这些基础设施。
- 自动化测试用于防崩溃和关键回归，**视觉是否正确由每阶段用户人工验收决定**。


# R03：首页：搜索、最近浏览和关注贴吧

替换当前“关注的吧”大卡片页，使其接近 Android 首页截图。

## Android 参考

读取：

- `main/home/HomePage.kt`
- `HomeViewModel.kt`
- `HistoryUtil`/历史吧模型
- `ForumItemContent`
- 搜索框、最近浏览 LazyRow、置顶吧和关注吧列表

目标截图：
`Android-target/01-home-recent-followed.png`

## 页面层级

从上到下：

1. 左侧当前用户头像 + “首页”标题；右侧保留原版对应操作，不自创悬浮圆按钮。
2. 平面搜索框“发现更多”。
3. “经过贴吧/最近浏览”可展开标题。
4. 最近浏览吧的横向 chips：真实小吧图 + 吧名。
5. “置顶/常用”区（只有当前数据支持时显示）。
6. “关注”区：真实吧图、吧名、热度、`Lv.N`；平面行。
7. 底部系统 tab bar。

## 数据与行为

- 复用现有浏览历史，新增“forum 最近访问”投影；最多保存合理数量，最近优先。
- 打开成功的 ForumHome 后才记入最近浏览。
- FollowedForums Live 已有数据，补齐 avatar/hotNum/level 映射。
- 长按取消关注/置顶仅在原 API 已实现且范围小的时候接入；否则本阶段不做。
- 列表不要一项一个浅灰大圆角卡。
- 一行一个吧，细分隔线；大屏可按原版 preference/现有 adaptive 规则形成两列，但 iPhone 默认单列。
- 加载、空、失败状态也使用平面布局。

## 性能

关注吧可能很多。优先使用现有 `VirtualizedList` 或经验证的 UITableView 承载；最近浏览横向行不得为每个 item 建立独立 Store。

## 人工验收

Live 登录态下验证：

- 当前头像；
- 最近浏览至少 3 个吧；
- 关注吧真实图标、热度、等级；
- 进入一个吧并返回，位置保持；
- 深色模式快速看一次。

只跑 Home/Followed/History 定向测试和 build。

安装后停在首页，截图顶部、最近浏览和关注列表中部，输出人工门禁。

用户批准后提交：

```text
feat: align home and followed forums with TiebaLite
```
