# 阶段 10B：冻结首条链路的视觉与交互基线

仅在阶段 10 fixture 垂直链路功能门禁完全绿色后执行。本阶段不接 live API，不重新设计架构；目标是把已通过的界面和交互转成后续可重复比较的基线，避免接 API 或新增 Feature 时悄悄破坏布局/动画。

## 基线环境

记录真实可用的：

- Xcode/iOS runtime。
- iPhone 小屏和大屏各一个。
- iPad 全屏与窄分屏场景。
- 浅色/深色。
- 默认字号与一个无障碍大字号。
- Reduce Motion 开/关。
- 固定 fixture、locale、时区和内容尺寸。

## 需要冻结的状态

至少保存 XCUITest 截图附件或明确的本地证据路径：

- 推荐 initial/loading/loaded/empty/error/refresh/next-page error。
- 帖子 loaded、未知节点、图片失败、分页 footer。
- MediaViewer 单图/多图/加载/失败/缩放后 chrome。
- 返回推荐后的滚动锚点。
- iPad 展开/折叠布局。

不把动态系统状态栏、时钟或随机数据作为像素级硬断言。截图用于发现布局/露底/遮挡回归，行为真相仍由状态与 UI 断言负责。

## 交互录像/脚本

使用 `$ios-interaction-qa` 和 Computer Use 运行：

1. 快速连续切换、半程取消、反向操作。
2. 打开/关闭媒体 20 次。
3. 缩放后翻页尝试与回到 1x 后翻页。
4. 滚动中触发刷新/分页失败并重试。
5. 旋转或 iPad resize 中保持 route/index/锚点。
6. Reduce Motion 下重复主链路。

记录 PASS/FAIL、证据、状态/route/index 和任何无法自动化项。

## 静态清单

- 动画调用都映射到 Motion token 和具体语义。
- Feature 无 DragGesture、UIScreen bounds、随机 identity、任意 zIndex、根隐式 animation。
- overlay/sheet/fullScreenCover 清单及生命周期明确。
- 页面/列表背景不透明且一致。

## 输出

- `Docs/Audits/VISUAL_INTERACTION_BASELINE.md`
- `Docs/Audits/Baselines/README.md`（说明证据是否入 Git、如何重跑、如何处理系统差异）
- 必要的 fixture UI tests 和启动场景。
- 不得因基线建立而加入第三方 snapshot 库；确有需要必须先 ADR。

## 验收

- 后续阶段有可重复的比较入口，而不是凭记忆判断“动画变了”。
- 所有截图/录屏无真实账号与敏感内容。
- 不修改 live repository。
- `make quality` 与 `/review` 通过。

完成后停止。
