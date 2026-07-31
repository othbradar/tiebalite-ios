# 阶段 01B（强烈建议、条件可选）：Android 原版运行行为采集

本阶段只采集原版 TiebaLite 的运行证据，用于补足源码无法确认的页面、滚动、返回、加载、错误、动效和手势行为。不得写 iOS 生产代码，也不得修改 Android submodule。

## 前置与可用性判断

1. 读取阶段 01 审计与 `Specs/UNKNOWN_BEHAVIORS.md`。
2. 检查本机是否已有 Android Studio/SDK/emulator，或是否有用户提供的原版录屏、截图和可运行 APK。
3. 不允许为了本阶段下载来路不明 APK、绕过签名/认证或抓取他人账号流量。
4. 环境不可用时，创建报告标记 `NOT_AVAILABLE`，列出未解决项和后续用户手工采集清单，然后停止；不要猜测。

## 安全规则

- 真实账号登录只由用户手工完成。
- Codex Computer Use 不输入、读取、复制或记录密码、Cookie、BDUSS、STOKEN、二维码授权内容。
- 录屏/截图遮盖用户名、头像、私聊、Cookie、设备标识和其他敏感内容。
- 不拦截 TLS，不安装自签根证书，不修改原版 App。

## 需要采集的 P0 流程

对每个流程记录：设备/窗口、起始状态、逐步动作、页面层级、滚动保持、加载/错误位置、返回行为、手势、动效起止、可观察时间关系和证据路径。

1. 冷启动与主 Tab 切换。
2. 推荐：首次、刷新、分页、错误/重试、打开帖子与返回位置。
3. 我关注的吧：未登录、已登录、进入吧首页与返回。
4. 吧首页：头部、置顶/普通贴、排序/分区切换、分页、返回。
5. 帖子：首屏、楼层分页、楼中楼展开/重试、图片打开/关闭。
6. 图片：左右切换、首尾、缩放、平移、失败图、系统返回。
7. 深色/大字体（原版支持范围内）。

不要把 Android 特有的导航按钮、动画或手势直接规定为 iOS 实现；分别标记：

- `PRODUCT_SEMANTIC`：应在 iOS 保留的用户行为。
- `ANDROID_CONVENTION`：应改用 iOS 系统惯例。
- `VISUAL_REFERENCE`：可参考的信息层级/密度。
- `UNKNOWN`：仍无法确认。

## 输出

- `Docs/Audits/ANDROID_RUNTIME_BEHAVIOR.md`
- `Docs/Audits/AndroidRuntimeEvidence/` 中的脱敏截图/简短录屏索引（大文件是否入 Git 按 ADR）。
- 更新 `Specs/UNKNOWN_BEHAVIORS.md`、`FEATURE_MATRIX.md`、`NAVIGATION_MAP.md`、`STATE_MACHINES.md`。
- 为每个 P0 用户流形成 Given/When/Then 行为条目。

## 验收

- 每个已运行流程都有可追踪证据，不用“看起来像”。
- Android 惯例与 iOS 产品语义已分离。
- 所有敏感信息已检查和脱敏。
- `git diff` 仅为 Docs/Specs/证据索引/TASK_STATE。

完成后停止。
