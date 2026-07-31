# Bug 报告模板

## 标识

- Bug ID：
- 标题：
- 首次发现 commit：
- 最后已知正常 commit：
- 发生频率：每次 / 高频 / 偶发 / 仅一次

## 环境

- macOS / Xcode：
- Simulator/真机：
- iOS/iPadOS：
- 横竖屏/窗口宽度：
- 浅色/深色：
- 字体大小：
- Reduce Motion：
- 网络 scenario：
- Session scenario：

## 确定性复现步骤

1.
2.
3.

## 预期行为

## 实际行为

## 证据

- 截图/录屏：
- 控制台日志区间：
- XCUITest/测试名：
- 相关状态快照：
- 相关视图/任务身份：

## 初步分类

- [ ] 状态机
- [ ] 异步竞态/取消
- [ ] SwiftUI 身份/复用
- [ ] 布局/Safe Area
- [ ] 手势竞争
- [ ] 动画/transaction
- [ ] UIKit bridge 生命周期
- [ ] 图片/缓存
- [ ] 导航
- [ ] 真实 API 数据边界

## 禁止做法

不得用延迟、随机 UUID、全屏遮罩、全局禁动画、无限 zIndex、重建导航树或清缓存作为修复。
