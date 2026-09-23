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


# R01：头像、吧图、等级与原版视觉原子

本阶段先解决所有后续页面共同依赖的数据和组件，不重排完整页面。

## Android 参考

重点读取最新 UI commit 中：

- `main/home/HomePage.kt` 的 `ForumItemContent`；
- `thread/ThreadPage.kt` 的 `UserHeader`、`UserNameText`；
- `FeedCard.kt`；
- `Avatar` 组件；
- `StringUtil.getAvatarUrl`、吧头像字段和等级颜色规则。

查看 Android-target 的首页、动态、吧首页、帖子页截图。

## 数据链路

沿现有 Live 模型检查并保留真实字段：

- 用户：稳定 userID、portrait、display name/nameShow、level_id、吧务/楼主标识；
- 吧：forumID、forumName、avatar、levelID、hotNum/memberCount；
- 推荐、FRS、PBPage、关注吧、搜索、消息未来所需映射。

不得伪造等级或头像。头像 URL 合成规则必须来自 Android 原版当前源码或 API 已返回的 HTTPS 字段。若只有 portrait，按原版已证实规则生成；不把登录 Cookie 发往图片 CDN。

## 新增/整理的薄组件

- `TiebaAvatarView`：用户头像，圆形，稳定尺寸，异步复用安全；
- `TiebaForumAvatarView`：吧图；
- `TiebaUserLevelBadge`：紧凑 Lv chip；
- `TiebaForumLevelBadge`；
- `TiebaFlatDivider`；
- `TiebaMetadataRow`；
- `TiebaMediaGrid`：先用 Fixture 展示 1/2/3/4/5/8 图布局；
- 中性占位，不用蓝色星形或通用人形作为正常显示。

全部复用现有 `ProductionImageLoader`，不创建第二套图片系统。

## 视觉要求

- 对照原版大小和密度：头像、吧图、等级 chip 均紧凑。
- chip 只包内容，不做整行大圆角卡片。
- 分割线颜色和缩进统一。
- 不新增阴影、渐变或玻璃效果。
- 支持深色和 Dynamic Type，但不要因此改变原版层级。

## 展示与人工验收

在现有 Debug Component Gallery 新增 Android-parity section，展示：

- 用户头像成功/失败/加载；
- 用户等级 1、8、14、18；
- 吧图 + 热度 + 等级；
- 1～8 张图片网格；
- 平面 feed row skeleton。

只运行组件定向测试、图片复用测试、lint/build。

构建安装后把 Component Gallery 留在上述 section，截 iPhone 和 iPad 图，输出 `READY_FOR_USER_VISUAL_REVIEW`。

用户批准后提交：

```text
feat: add Tieba avatar level and media primitives
```
