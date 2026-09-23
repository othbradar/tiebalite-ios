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


# R02：根 Shell 改为首页 / 动态 / 消息 / 我的

当前 iOS 只有“推荐 / 关注的吧 / 设置”，不符合原版产品结构。本阶段只改根导航和各入口骨架，不实现消息业务内容。

## Android 参考

读取最新 UI commit：

- `main/MainPage.kt`
- `main/home/HomePage.kt`
- `main/notifications/NotificationsPage.kt`
- `main/user/UserPage.kt`
- 对应 BottomNavigation/NavigationRail

查看 Android-target 六张截图的底栏和标题区域。

## 目标结构

iPhone 底栏固定四项：

1. 首页：R03 将承载搜索、最近看过、关注吧；
2. 动态：现有 Recommendations；
3. 消息：R11 前显示明确的“待实现”占位，但导航、未读 badge 数据接口先留好；
4. 我的：现有用户资料、历史、设置和关于入口的容器。

要求：

- 移除推荐页额外的巨大 `TiebaLite` 文本；一个页面只保留一个标题层级。
- 根 tab 之间只通过底栏切换，不增加用户横滑；与 Android MainPage 一致。
- 切换 tab 保留各自 Store 和滚动位置。
- 重选当前 tab 执行回到顶部/刷新时，只使用现有明确行为。
- iPad 使用当前自适应 shell 的 rail/sidebar，不复制第二套业务状态。
- 消息 badge 先由可注入计数源提供，Fixture 可显示 3；Production 未接入前为 0。
- 不新增悬浮圆形搜索/刷新按钮；放到原版对应 toolbar 位置。
- 不开始 R03/R04/R11 的内容重写。

## 最低测试

- 四个 tab route 和状态保持；
- iPhone 各 tab 可打开；
- iPad rail/sidebar 可切换；
- 返回栈不跨 tab 污染；
- 现有 MediaViewer 根 cover 不重复。

修改 App 根导航，提交前只跑 shell 定向 UI、Unit、`make quality-fast`；不要跑完整长 interaction，除非实际改动 Pager/MediaViewer。

构建安装后依次停在首页、动态、消息、我的并截图，最后停在首页。输出人工门禁。

用户批准后提交：

```text
feat: align root navigation with TiebaLite
```
