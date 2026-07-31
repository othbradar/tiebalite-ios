# Live 数据边界采样与 Fixture 固化

只在用户明确允许访问公开/自身账号数据且安全策略已建立时执行。目标是发现真实 payload 边界并生成脱敏最小 fixture，不做批量抓取。

## 安全

- 只请求实现功能所必需的少量 endpoint。
- 不抓取私密内容、他人非公开数据或批量用户资料。
- 不保存完整 Cookie/token/header。
- 响应先在本地脱敏和最小化，再进入 Git。
- 记录来源和生成脚本，不记录账号身份。

## 采样目标

```text
Endpoint：
需要验证的字段/节点：
已知缺口：
最大请求数：
```

## 流程

1. 先以 API evidence 构造请求。
2. 记录 status/content-type/大小/解析摘要。
3. 找到目标边界后停止，不做爬取。
4. 抽取最小仍可复现结构的 fixture。
5. 替换用户 ID、名称、正文、URL query、设备和认证信息。
6. 添加 mapper/regression test。
7. 用 secret scan 和人工 diff 检查。

## 输出

- 验证/否定的字段语义。
- 新 fixture 与脱敏说明。
- 更新的 API/内容节点证据。
- 测试结果。
