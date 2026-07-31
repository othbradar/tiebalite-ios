# API / Protobuf 证据模板

阶段 01 将本文件复制/重命名为 `Specs/API_EVIDENCE.md` 并逐项填写。

## Endpoint 条目

### `<稳定名称>`

- 用户任务：
- HTTP method / URL family：
- Android 来源文件：
- Android symbol：
- 请求构建来源：
- 认证要求：anonymous / cookie / token / unknown
- 请求编码：form / query / protobuf / json / other
- 请求 Protobuf：
- 响应 Protobuf/DTO：
- 分页字段：
- 服务端错误字段：
- 关键 headers：
- 设备/版本参数：
- 敏感字段：
- iOS domain mapper：
- Fixture 路径：
- Fixture 获取/生成方式：
- 已验证行为：
- UNKNOWN：

## 证据规则

- 文件路径和符号必须可定位。
- 不以博客或模型记忆代替参考源码。
- 抓取样本必须去除 Cookie、账号、token、手机号、用户私密内容。
- 字段语义无法确认时保留原始命名并标 `UNKNOWN`，不根据字段序号猜用途。
- Endpoint 变更必须更新 fixture 与 mapper tests。
