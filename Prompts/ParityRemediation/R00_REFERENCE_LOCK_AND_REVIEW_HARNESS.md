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


# R00：锁定最新 Android UI 参考并建立人工验收基线

本阶段不修改任何生产 UI、业务模型、Repository 或导航。

## 任务

1. 确认当前 iOS HEAD、当前 app 版本和未提交漂移。
2. 保持 `References/TiebaLite-Android` 当前工作树/Proto commit 不变。
3. 在 submodule 内执行只读 `fetch origin 4.0-dev`，记录：
   - `origin/4.0-dev` 精确 SHA；
   - 当前固定 API/Proto SHA。
4. 把最新 UI SHA 写入
   `Docs/VisualParity/ANDROID_UI_REFERENCE_COMMIT.txt`。
5. 检查套件中的十张截图可读取：
   - iOS-before 4 张；
   - Android-target 6 张。
6. 在 `VISUAL_PARITY_MATRIX.md` 追加当前源码文件位置：
   - App shell；
   - recommendations；
   - followed forums；
   - forum home；
   - thread reader；
   - user profile/settings。
7. 运行当前基线 `make lint`、`make build`；不要跑完整 `make quality`。
8. 运行 `scripts/visual_review_build_install.sh R00`，覆盖安装当前 App。
9. 依次打开推荐、关注吧、一个吧首页和一个帖子页，保存基线截图。
10. 不修任何问题。

## 输出

列出：

- 当前 iOS commit；
- Android API/Proto commit；
- Android 最新 UI commit；
- 4 个基线截图路径；
- 当前三个最明显的视觉差异；
- `READY_FOR_USER_VISUAL_REVIEW`。

不得提交。用户批准 R00 后提交信息：

```text
chore: add Android visual parity references
```
