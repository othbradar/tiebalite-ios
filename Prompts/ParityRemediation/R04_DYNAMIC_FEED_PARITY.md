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


# R04：动态/推荐信息流视觉一致性

当前 Recommendations 使用额外大标题、圆角 `ContentSummaryCard` 和一张 16:9 大图。改为 Android 动态截图的平面信息流。

## Android 参考

读取：

- 动态/Explore 页面及 ViewModel；
- `FeedCard.kt`；
- Feed 用户头、内容摘要、图片列表、吧 chip、分享/回复/点赞栏。

目标截图：
`Android-target/02-dynamic-feed.png`

## Row 结构

每个普通动态帖子：

1. 用户头像；
2. 用户名、必要等级/身份；
3. 相对时间；
4. 标题或正文摘要；
5. 连续图片网格：0～4 列，最多显示合理数量，更多显示计数；
6. 吧图/吧名 chip；
7. 底部分享、回复数、点赞区域；
8. 行间细分割线。

不允许：

- 整行浅灰大圆角卡；
- 只显示一张大图而丢弃其余媒体；
- 使用 `rectangle.stack` / `person` 作为正常元数据图标；
- 保留重复的 `TiebaLite` 产品大标题；
- 图片加载导致整行高度反复跳变。

## 数据

检查 Personalized/Recommendation Proto 和 Android mapper，补齐：

- author portrait、level；
- publish time；
- abstract/content；
- forum icon/name；
- 完整媒体候选列表；
- agree/share/reply count（只展示有真实字段的内容）。

不要伪造分享或点赞数。R09 前回复按钮可以打开只读帖子并聚焦底部回复入口占位，不发送写请求。

## 性能

推荐可连续分页，使用现有稳定虚拟列表承载和增量 row model；不要继续使用复杂 SwiftUI `LazyVStack` 作为长信息流，除非现有经验证承载已经被封装复用。

## 人工验收

Live 加载至少两页，检查：

- 纯文字；
- 单图；
- 多图；
- 长摘要；
- 头像加载失败；
- 进入帖子再返回位置保持。

定向测试、lint/build、一个 iPhone smoke；不跑全部 interaction。

安装后停在含多图的动态帖子，截顶部和列表中部，输出人工门禁。

用户批准后提交：

```text
feat: align dynamic feed with TiebaLite
```
