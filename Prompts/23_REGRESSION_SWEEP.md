# 回归扫测：完成一个阶段或重大 Bug 修复后使用

本任务不新增功能。调用 `$xcode-quality-gate` 和 `$ios-interaction-qa`，先运行自动化，再用 Computer Use 做最小手工矩阵。

## 输入

- 基线 commit：
- 当前 commit/工作树：
- 变更范围：
- 主要风险：
- 需要重点回归的 Bug ID：

## 自动化

1. `git diff --check`
2. 静态禁止模式扫描。
3. SwiftLint。
4. 受影响模块单元测试。
5. 全部 unit tests。
6. UI smoke。
7. 涉及交互时执行 interaction test plan。
8. 涉及 iPad 时执行 iPad test plan。

记录每条命令、退出码、xcresult 路径和失败测试。不得只给最后一句“全通过”。

## 手工最小矩阵

- 推荐→帖子→图片→返回。
- 关注吧→吧→帖子→返回（若 session fixture 可用）。
- 快速 Tab 切换与返回。
- 快速分页/刷新。
- Media 快速滑、缩放、关闭。
- 深色、大字体、Reduce Motion。
- iPad resize（若相关）。
- 慢网/失败/会话过期（若相关）。

## 差异风险审计

- View identity 是否变化。
- State 是否新增重复 truth。
- 是否新建 animation/gesture/overlay。
- 是否改变 route/path。
- 是否改变 endpoint/cookie/logging。
- 是否出现未批准依赖/Package.resolved 大改。

## 输出

`Docs/Audits/REGRESSION_<date-or-id>.md`：

- 自动化结果。
- 手工结果。
- 新回归。
- 未测范围。
- 是否可提交/合并：YES/NO。

发现回归时停止发布判断，使用根因 Bug 提示词逐个处理。
