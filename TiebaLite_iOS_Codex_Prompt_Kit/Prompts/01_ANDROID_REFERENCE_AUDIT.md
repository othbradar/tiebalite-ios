# 阶段 01：Android TiebaLite 只读源码审计

严格遵守根 `AGENTS.md`，并显式使用 `$tiebalite-reference-audit`。本阶段只读分析 `References/TiebaLite-Android`，不得创建 Swift/Xcode 项目，不得实现 iOS 页面。

建议使用 GPT-5.6 Sol Ultra，但所有子代理只读。协调主代理负责合并证据，不能让多个代理各自写同一审计文件。

## 目标

把 Android 4.0-dev 参考实现转化为可执行的 iOS 产品/协议规格，明确哪些是代码证据、运行证据和未知项。

## 必须审计的区域

至少系统搜索并建立索引：

- `app/src/main/java/.../api/`：HTTP 常量、LiteApi、TiebaApi、ProtobufRequest、请求适配与 caster。
- repository/data 层：推荐、FRS/吧页、PB/帖子页、关注吧、搜索、登录/session。
- `app/src/main/proto/`：请求与响应消息、分页、用户、主题、楼层、内容节点。
- UI/Compose/Fragment/Activity：主 Tab、推荐、吧首页、帖子、图片、登录、搜索、设置。
- 内容渲染器：文本、图片、链接、表情、视频/语音/投票/未知节点等实际分支。
- 数据库与 DataStore：历史、缓存、设置、账户状态。
- Android tests、issues 或代码中的异常/边界处理。

不得只根据文件名总结；关键行为必须追到具体 symbol 和调用链。

## 可并行只读工作流

可让子代理分别审计：

1. API/请求构建/认证。
2. Protobuf 与 mapper。
3. 推荐与主导航。
4. 吧首页/FRS。
5. 帖子/PB/内容节点。
6. 关注吧与登录/session。
7. 图片查看、手势、设置与边界。

子代理输出必须含路径、symbol、证据置信度和 UNKNOWN，不得直接修改仓库。

## 必须产出

1. `Docs/Audits/ANDROID_REFERENCE_AUDIT.md`
   - branch/commit SHA
   - 模块图和关键调用链
   - Android UI 与 iOS 原生行为的区分
   - 已知高风险/过时做法
2. `Specs/FEATURE_MATRIX.md`
   - 原版功能、P0/P1/排除、登录要求、数据来源、验收流程
3. `Specs/NAVIGATION_MAP.md`
   - 页面、入口、route 参数、返回状态、Tab/子页关系
4. `Specs/API_EVIDENCE.md`
   - 从模板生成，逐 endpoint 填证据
5. `Specs/PROTOBUF_MAP.md`
   - 文件、message、request/response、领域模型、生成顺序、未知字段
6. `Specs/CONTENT_NODE_MATRIX.md`
   - 从模板生成，覆盖所有内容节点与降级策略
7. `Specs/STATE_MACHINES.md`
   - 推荐、关注吧、吧页、帖子、媒体、session 的状态和事件
8. `Specs/UNKNOWN_BEHAVIORS.md`
   - 仅运行 App/抓包/真实账号才能确认的问题，以及安全的验证方法
9. `Docs/Audits/SOURCE_AND_LICENSE_NOTES.md`
   - 参考仓库许可证、文件来源、允许复用/需重写的边界

## 规格要求

每条重要结论标注：

- `CODE_EVIDENCE`：有路径与 symbol。
- `RUNTIME_EVIDENCE`：有截图/录屏/响应 fixture。
- `INFERENCE`：根据多个证据推断，写明推断链。
- `UNKNOWN`：证据不足。

对推荐、FRS、PB、关注吧至少画出：

```text
用户动作 → UI intent → repository → endpoint/request → response/proto → mapper → UI state
```

## 不允许

- 不写 Swift。
- 不创建 `project.yml`。
- 不把 Android Compose 动画/手势照搬到 SwiftUI。
- 不凭字段名猜登录 token 或签名算法。
- 不把“未搜索到”写成“功能不存在”。
- 不自动进入架构阶段。

## 验收

- 每个 P0 功能至少有完整调用链和状态机。
- 每个拟接入 endpoint 有来源、认证、request/response 和分页信息，或明确 UNKNOWN。
- 内容节点矩阵不是只有 text/image 两项，而是覆盖参考代码实际分支。
- 所有审计文件相互引用且无明显矛盾。
- `git diff` 仅包含 Specs/Docs/TASK_STATE 变更。

完成后报告证据最弱的五个区域，并停止。
