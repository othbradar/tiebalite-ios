# 阶段 16A（P1）：搜索

只在所有 P0 核心链路绿色后执行。本提示词只实现搜索，不同时实现历史/设置/资料页。

## 范围

依据 Android 审计与 API evidence 确定：

- 搜索吧、主题或两者。
- 搜索建议/历史仅在有证据或本地需求时。
- 结果进入既有 ForumRoute/ThreadRoute，不复制详情页面。

## 状态

- idle（空查询）。
- debouncing。
- loading。
- loaded/empty/error。
- loading next page（若证据存在）。
- query generation，旧查询响应不能覆盖新查询。

## 交互

- 使用系统 searchable/search field。
- 键盘、安全区、取消和返回符合系统行为。
- debounce 使用可测试 Clock，不用 `asyncAfter`。
- 清空查询取消任务并恢复 idle。
- 搜索结果使用稳定 ID。

## 测试

- 快速输入多个查询，旧结果丢弃。
- 清空、取消、离线、超时、空结果。
- 键盘出现/旋转/iPad split view 无遮挡。
- 打开吧/帖子后返回查询与位置保持。

## 验收

- 不复制 Forum/Thread UI。
- fixture 自动化优先，live 证据单独记录。
- `make quality` 通过。

停止。
