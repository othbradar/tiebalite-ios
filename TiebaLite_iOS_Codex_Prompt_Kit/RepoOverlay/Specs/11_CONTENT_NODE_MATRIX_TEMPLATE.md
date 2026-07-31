# 帖子内容节点矩阵模板

阶段 01 从 Android Protobuf 和内容渲染器生成，禁止只凭 UI 截图枚举。

| Android/Proto 类型 | 字段与语义证据 | iOS 领域节点 | P0/P1 | 渲染 | 交互 | Fixture | 状态 |
|---|---|---|---|---|---|---|---|
| text |  | TextNode | P0 |  |  |  | UNKNOWN |
| image |  | ImageNode | P0 |  | 打开 MediaViewer |  | UNKNOWN |
| link |  | LinkNode | P0 |  | 外部确认/打开 |  | UNKNOWN |
| emoji |  | EmojiNode | P0 |  | 无 |  | UNKNOWN |
| unknown |  | UnsupportedNode | P0 | 安全占位 | 无 |  | REQUIRED |

每种节点至少需要：正常、缺字段、超长、无效 URL/资源、未知 enum 的 fixture 或构造测试。
