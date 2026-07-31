# Protobuf 映射与生成图

状态：`STATIC_SCHEMA_EVIDENCE`

Android 基线：`4.0-dev@5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`。

## 基线事实

- `CODE_EVIDENCE`：真实 schema 目录是 `References/TiebaLite-Android/app/src/main/protos`，不是阶段提示中的 `app/src/main/proto`。
- `CODE_EVIDENCE`：共有 321 个 `.proto`、351 个 `message`，全部为 proto3；有 107 处 `optional`。
- `CODE_EVIDENCE`：没有 `enum`、`oneof` 或 `reserved` 声明。内容类型、排序、状态与 flag 多为裸整数。
- `CODE_EVIDENCE`：`app/build.gradle.kts::wire` 用 Square Wire 从 `src/main/protos` 生成 Android Kotlin；版本目录记录 Wire 6.4.0。
- `CODE_EVIDENCE`：reference 未跟踪生成 Kotlin，当前没有可审计的生成输出。
- 本阶段没有复制 schema、没有运行 Wire/SwiftProtobuf、没有生成 Swift。

`INFERENCE`：iOS 只能选择 P0 所需的最小传递闭包；不能把 321 个 schema 全量导入当作“完成协议层”。生成产物必须隔离在 `Generated/Protobuf`，并由 mapper 转为领域模型。

## 生成层次

Wire/SwiftProtobuf 实际会按 import graph 解析；下列顺序是可审查的叶到根分层，不是手写逐文件脚本。

### Layer 0：公共叶类型

| 文件/message | 被谁使用 | iOS 处理 | 状态 |
|---|---|---|---|
| `Error.proto::Error` | 所有候选 response | `APIServiceErrorDTO` → 领域错误 | `CODE_EVIDENCE` |
| `CommonRequest.proto::CommonRequest` | P0 request data | 只在 transport builder；不得进入领域/UI | `CODE_EVIDENCE`; 最小字段 `UNKNOWN` |
| `AppPosInfo.proto::AppPosInfo` | Personalized/FRS/PB request | 默认不复制 Android 假定位；是否必需 `UNKNOWN` | `CODE_EVIDENCE` |
| `AppTransmitData.proto` | PB request | transport only | `CODE_EVIDENCE`; 语义 `UNKNOWN` |
| `Page.proto::Page` | FRS/PB/PBFloor | `PageEnvelope`，保留 raw 字段和冲突检测 | `CODE_EVIDENCE` |
| `Anti.proto::Anti` | FRS/PB | session/write metadata；只读 UI 不直接消费 | `CODE_EVIDENCE` |
| `MemeInfo.proto` | PbContent | 未发现生产消费 | `UNKNOWN` |
| `PollOption.proto` | PollInfo | 只读 `PollOption` | `CODE_EVIDENCE` |

### Layer 1：共享组合模型

| 文件/message | 关键依赖 | iOS 领域模型 | mapper 风险 |
|---|---|---|---|
| `PbContent.proto::PbContent` | MemeInfo | `ContentNode` | raw type 非 enum；未知值不得丢弃 |
| `PollInfo.proto::PollInfo` | PollOption | `ReadOnlyPoll` | `total_poll=0`、状态/类型值域 |
| `User.proto::User` | 多个装饰类型 | `AuthorSummary` / `PublicProfile` | 只取白名单字段；schema 含凭据/敏感形字段 |
| `SimpleForum.proto::SimpleForum` | 无/共享 | `ForumIdentity/Summary` | id/name 缺失 |
| `SubPostList.proto` + `SubPost.proto` | User/PbContent | `Subpost` / `SubpostPage` | author/content 可空 |
| `Post.proto::Post` | User/PbContent/SubPost 等 | `Post` | 删除/折叠/未知扩展字段 |
| `ThreadInfo.proto::ThreadInfo` | User/PbContent/PollInfo 等 | `ThreadSummary/ThreadMetadata` | `pids` 是未验证字符串 cursor |

### Layer 2：P0 payload

| Family | Request data | Response data | 领域输出 |
|---|---|---|---|
| Personalized | `PersonalizedRequestData` | `PersonalizedResponseData` | `RecommendationPage` |
| FRS Page | `FrsPageRequestData` | `FrsPageResponseData` | `ForumSnapshot + ForumThreadPage` |
| ThreadList | `ThreadListRequestData` | `ThreadListResponseData` | `ForumThreadPage` |
| GeneralTab | `GeneralTabListRequestData` | `GeneralTabListResponseData` | `ForumThreadPage` |
| PB Page | `PbPageRequestData` | `PbPageResponseData` | `ThreadSnapshot + PostPage` |
| PB Floor | `PbFloorRequestData` | `PbFloorResponseData` | `SubpostPage` |

### Layer 3：外层 wrapper

| Family | Request wrapper | Response wrapper | 错误 |
|---|---|---|---|
| Personalized | `PersonalizedRequest` | `PersonalizedResponse` | `Error` |
| FRS Page | `FrsPageRequest` | `FrsPageResponse` | `Error` |
| ThreadList | `ThreadListRequest` | `ThreadListResponse` | `Error` |
| GeneralTab | `GeneralTabListRequest` | `GeneralTabListResponse` | `Error` |
| PB Page | `PbPageRequest` | `PbPageResponse` | `Error` |
| PB Floor | `PbFloorRequest` | `PbFloorResponse` | `Error` |

PB Page + PB Floor 四个根 wrapper 的 Android import 传递闭包约 129 个 proto。阶段 03 生成前必须用脚本重新计算锁定列表和哈希，避免人工漏依赖；本阶段不创建该生成脚本。

## P0 message 映射

### Personalized

来源：`Personalized.proto`。

| Wire 字段 | 领域语义 | 证据 |
|---|---|---|
| request `load_type` | Android 1=刷新，2=更多 | call-site `CODE_EVIDENCE` |
| request `pn` | 客户端页号 | `CODE_EVIDENCE` |
| request `page_thread_count` | Android 固定 11 | `CODE_EVIDENCE` |
| response `thread_list` | 推荐主题 | `CODE_EVIDENCE` |
| response `thread_personalized` | 按 tid 关联的推荐元数据 | `CODE_EVIDENCE` |
| `weight/source/extra` | 不进入 P0 领域，保留 raw/忽略策略待定 | `UNKNOWN` |

### FRS Page

来源：`FrsPage/FrsPage.proto`。

| Wire 字段 | 领域语义 | 证据 |
|---|---|---|
| request `kw` | 吧名 | call-site `CODE_EVIDENCE` |
| `pn/load_type/sort_type/cid/is_good` | 页、加载类型、排序/精品过滤 | `CODE_EVIDENCE`; 值域部分 `UNKNOWN` |
| response `forum` | 吧摘要与分类 | `CODE_EVIDENCE` |
| response `page` | 页信息 | `CODE_EVIDENCE` |
| `thread_list/user_list` | 主题与作者表 | `CODE_EVIDENCE` |
| `thread_id_list` | 后续批量主题 id | 使用方式 `CODE_EVIDENCE`; 服务端语义 `UNKNOWN` |
| `frs_tab_info/nav_tab_info` | 服务端 tab | `CODE_EVIDENCE`; 类型值域 `UNKNOWN` |
| `forum_rule` | 规则入口摘要 | `CODE_EVIDENCE` |

### PB Page

来源：`PbPage/PbPageRequestData.proto`、`PbPage/PbPageResponseData.proto`。

| Wire 字段 | 领域语义 | 证据 |
|---|---|---|
| request `kz` | thread id | call-site `CODE_EVIDENCE` |
| `pid/pn/back/last_pid` | 锚定/页/向前/最新 id | 构造方式 `CODE_EVIDENCE`; 精确服务器语义 `UNKNOWN` |
| `lz` | 只看楼主 | call-site `CODE_EVIDENCE` |
| `r` | Android caller 传入的 sortType | 赋值为 `CODE_EVIDENCE`；值域/服务端语义 `UNKNOWN` |
| `floor_sort_type` | 当前 Android builder 恒传 1；业务含义不明 | 存在/常量为 `CODE_EVIDENCE`；语义 `UNKNOWN` |
| response `thread/forum/page/anti` | 帖子元数据/吧/页/服务元数据 | `CODE_EVIDENCE` |
| `post_list/user_list` | 楼层与作者表 | `CODE_EVIDENCE` |
| `first_floor_post` | 首楼 | `CODE_EVIDENCE` |
| 其余广告、推荐、业务推广字段 | P0 不映射，必要时作为未消费 DTO | 存在 `CODE_EVIDENCE`; 语义 `UNKNOWN` |

### PB Floor

来源：`PbFloor/`。

- request 以 thread/post/subpost/page 相关字段定位楼中楼；具体锚定语义需 fixture。
- response 提供 Page、Post/SubPostList、Thread/SimpleForum/Anti 等依赖。
- Android 以 `current_page < total_page` 判断下一页；iOS mapper 必须检测与 `has_more` 冲突并记录 fixture。

## `PbContent` raw type

`PbContent.type` 是 int32。当前生产 mapper 的完整分支以 `api/models/protos/Extensions.kt::List<PbContent>.renders` 为准：

| raw type | Android 当前分支 | iOS domain |
|---:|---|---|
| 0, 9, 27, 35, 40 | 文本 | `TextNode(rawType)` |
| 1 | URL annotation | `LinkNode` |
| 2 | 表情 | `EmojiNode` |
| 3 | 图片 | `ImageNode` |
| 4 | 用户 mention | `MentionNode` |
| 5 | 视频或 URL 降级 | `VideoNode` / `LinkNode` |
| 10 | 语音 | `VoiceNode` |
| 20 | 替代图片 | `ImageNode(rawType: 20)` |
| 其他 | Android 静默丢弃 | `UnsupportedNode(rawType, safeSummary)` |

type 9/27/35/40 的原始业务含义没有运行证据；只能证明当前 Android 把它们当文本。详见 `Specs/CONTENT_NODE_MATRIX.md`。

## Proto3 presence、默认值与未知字段

`CODE_EVIDENCE`：

- schema 同时有普通 proto3 scalar 和 `optional` scalar。
- Android request builder 会对部分 optional 主动传入 `0`/`""`，这会消除 absent 与显式默认值的区别。
- call site 把非 optional scalar 当作 `0/""`、repeated 当作空列表、message 当作 nullable 使用。

`UNKNOWN`：

- SwiftProtobuf 生成的具体 presence API 尚未生成/编译。
- Wire 6.4.0 与计划中的 SwiftProtobuf 对 optional、未知 tag、未知字段 round-trip 是否满足预期尚未做二进制对照。
- 服务端对 absent 与显式 `0/""` 是否有不同语义。
- 裸整数的完整值域；不能在领域层声明闭合 enum 而没有 `.unknown(rawValue)`。

实现要求：

1. transport request builder 明确选择 absent 或显式默认，不由 Swift 默认值偶然决定。
2. mapper 对所有裸整数保留 raw value。
3. response decode 允许未知 tag；再编码保留策略由 round-trip test 决定。
4. UI 不直接检查生成类型的 optional/presence。
5. 每次 schema 变更更新 import lock、生成哈希、fixture 和 mapper test。

## 畸形边界

以下是 `CODE_EVIDENCE` 指向的 Android 风险，iOS 必须有构造测试：

- `ThreadInfo.pids` 非数字 token 导致 `toLong()` 失败。
- 图片/视频 `bsize` 缺失、少于两段或非数字导致强制解析失败。
- 图片/视频高度为零导致非法比例。
- post author 缺失且 `user_list` 无匹配时 `first` 抛异常。
- 楼中楼 author 缺失会生成不可解析的 `"null"` mention。
- 楼中楼 content 空或全是未知节点时 `reduce` 抛异常。
- 未知 content type 被静默丢弃。
- 投票 `total_poll=0` 时比例除零。
- PB Floor 重叠页未去重。

## Fixture 与生成验证清单

后续阶段至少需要：

1. 每个 P0 wrapper 的最小 request 编码 golden。
2. 正常/空/错误/缺 data/畸形 response。
3. `optional absent` 与 `optional explicit default` 的 byte-level 对照。
4. 未知 tag 解码、领域映射、再编码 round-trip。
5. 所有已知 PbContent raw type 及 `999`。
6. 图片尺寸、URL、voice、mention、author、pids、Page 冲突边界。
7. PB Page/PBFloor 重叠页、正序/倒序、锚点。
8. generated source 不含 UI import，UI target 不直接 import generated module 的结构检查。

当前全部为 `NOT_CREATED/NOT_TESTED`。

## 来源与复制边界

Android reference 根目录含 GPL version 3 许可证文本，README 另有非商业声明，因此本项目按 GPLv3 风险保守处理；逐文件授权、上游权利链以及 README 声明与许可证的关系仍为 `UNKNOWN`。schema 的文件级复制与派生生成物可能触发许可证义务；本阶段只记录 message/字段和依赖事实，没有复制任何 `.proto`。后续若决定复用 schema，必须先按 `Docs/Audits/SOURCE_AND_LICENSE_NOTES.md` 完成来源标头、许可证评估和可分发性决策；否则应基于脱敏 wire evidence 独立编写最小兼容 schema。
