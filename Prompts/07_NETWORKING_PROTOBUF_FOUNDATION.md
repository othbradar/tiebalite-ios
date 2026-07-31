# 阶段 07：Networking、SwiftProtobuf 与贴吧协议基础

本阶段建立可测试的真实协议实现，但不把 live 网络接到 UI。

## 前置

- `Specs/API_EVIDENCE.md` 与 `PROTOBUF_MAP.md` 已完成到足以实现首个匿名 endpoint。
- ADR-0006 已 Accepted。
- 工程、测试底座绿色。

## Protobuf

- 按来源与许可证记录，把必要 `.proto` 放入明确目录或以构建脚本从只读 reference 生成。
- 使用 SwiftProtobuf，生成步骤可重复且写入 `scripts/generate_protos.sh`。
- 生成代码不得手工编辑。
- 先只生成 P0 首批依赖闭包，不盲目导入所有无关 proto。
- 验证至少一个 Android/脱敏 binary fixture 可被 Swift 解析。
- 未知 enum/字段必须安全兼容。

## Networking

建立：

- 强类型 Endpoint/Request。
- URLSession HTTPClient actor 或 ADR 指定实现。
- query/form/protobuf 编码。
- response status、content type、decode、server error 映射。
- cancellation、timeout、retry policy（默认不盲目重试非幂等请求）。
- Cookie/session 注入接口，但本阶段使用 fixture/fake session。
- request/response logging redaction。

## Evidence 驱动

首批 endpoint 只允许来自 `API_EVIDENCE` 中证据充分的匿名能力，例如推荐或帖子首屏。每个实现提交同时包含：

- Android 源路径/symbol 注释或文档引用。
- 请求构造测试。
- binary/JSON response fixture。
- Proto → domain mapper test。
- 缺字段、未知 enum、畸形 payload、HTTP error、取消测试。

不得让 View 看到 Proto。

## Live probe

若权限与网络允许，可写 Debug-only 命令行/测试 probe 验证公开匿名 endpoint：

- 输出仅包含 status、大小、解析结果摘要。
- 严格脱敏。
- 不作为 CI/unit test。
- 失败不影响 fixture 驱动功能，但必须更新 UNKNOWN/风险。

## 验收

- Protobuf 生成可重复。
- 首批 fixture 解析和领域映射全绿。
- 网络 client 能模拟并正确处理取消/超时/畸形响应。
- Release UI 尚未接 live 网络。
- `make quality` 通过。

完成后停止。
