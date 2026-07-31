# 单个 Feature/行为任务模板

将方括号替换后发送。一次只处理一个可验收行为。

## 任务

```text
Feature：
用户行为：
输入/入口：
预期结果：
异常结果：
明确非目标：
```

## 前置与证据

```text
相关 Specs：
相关 ADR：
Android reference 路径/symbol：
API evidence：
Fixture：
基线 commit：
```

## 允许修改

```text
目录/文件：
```

## 禁止修改

```text
共享导航/Pager/Media/Motion/网络核心/其他 Feature 等：
```

## 状态与并发验收

- 初始/成功/空/失败。
- refresh/pagination（适用时）。
- 取消。
- stale response。
- 稳定 ID 与去重。
- 返回/Tab 状态保持。

## UI/交互验收

- iPhone。
- iPad（涉及共享 UI 时）。
- 深色、Dynamic Type、Reduce Motion。
- accessibilityIdentifier。
- 不新增任意手势/动画/overlay。

## 执行流程

1. 先读规则并跑基线。
2. 先写/更新状态测试和 fixture。
3. 实现最小 data/domain/store。
4. 实现 View。
5. 加 UI smoke。
6. 跑 targeted tests，再 `make quality-fast`。
7. 报告并停止。

不得自动扩展到下一个 Feature。
