# Protobuf 映射与生成图

状态：`PERSONALIZED_THREAD_CONTENT_PBPAGE_FORUMGUIDE_AND_FRS_LOCAL_VERIFIED`

Android 基线：`4.0-dev@5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`。

## 基线事实

- `CODE_EVIDENCE`：真实 schema 目录是 `References/TiebaLite-Android/app/src/main/protos`，不是阶段提示中的 `app/src/main/proto`。
- `CODE_EVIDENCE`：共有 321 个 `.proto`、351 个 `message`，全部为 proto3；有 107 处 `optional`。
- `CODE_EVIDENCE`：没有 `enum`、`oneof` 或 `reserved` 声明。内容类型、排序、状态与 flag 多为裸整数。
- `CODE_EVIDENCE`：`app/build.gradle.kts::wire` 用 Square Wire 从 `src/main/protos` 生成 Android Kotlin；版本目录记录 Wire 6.4.0。
- `CODE_EVIDENCE`：reference 未跟踪生成 Kotlin，当前没有可审计的生成输出。
- 阶段 07 没有复制 `.proto`；生成器直接只读 pinned submodule，并仅对
  Personalized 的 51-file closure 生成 Swift。

阶段 07 实际工具与生成锁：

- `protoc 35.1`、`protoc-gen-swift 1.38.1`、SwiftProtobuf runtime/package
  `1.38.1`，revision
  `55d7a1cc5666b85c13464aea1c4b4a90feccb4c8`。
- canonical package lock：`Config/SwiftPM/Package.resolved`；生成工程 lock
  由脚本单向 materialize 并逐字节比较。
- schema manifest：历史文件名
  `Config/Protobuf/Personalized.inputs.tsv` 现锁定六个 root 的 156 个输入，
  均有 relative path、SHA-256、relationship 和 direct imports。
- generated output：`Generated/Protobuf` 的 156 个 `.pb.swift`、生成 metadata
  与逐文件 SHA-256；两次 clean generation 与 tracked output 一致。
- `GeneratedProtobuf` 是独立静态 target；UI/Feature import 被静态门禁拒绝。
- 首个 binary fixture 是 250-byte `CROSS_LANGUAGE_GENERATED` JVM fixture，
  不是 live endpoint evidence；原 `opaque.pb` 仍只是 loader fixture。
- 阶段 08 复用同一闭包中的 `ThreadInfo/PbContent/PollInfo/PollOption`，
  生成 1535-byte 首楼正文 fixture；没有新增 Proto 输入或修改生成文件。
- 阶段 11 依据 ADR-0013 增加 PBPage request/response 两个 root。PBPage
  request closure 为 6、response closure 为 119、合并为 125；与
  Personalized 51-file closure 重叠 50，当前唯一联合 closure 因而为 126。
- 阶段 13 依据 ADR-0015 增加 ForumGuide request/response 两个 root，联合闭包
  扩展为 136。
- 阶段 14 依据 ADR-0016 增加唯一 FRS 首屏 root
  `FrsPage/FrsPage.proto`。FRS closure 为 74，与原集合重叠 54，新增 20，
  当前唯一联合闭包为 156；未提前加入阶段 15 的 ThreadList root。

当前 local/personal/noncommercial schema 路径由 ADR-0011 批准；公开分发、
App Store 和商业使用继续 `BLOCKED`。

`INFERENCE`：iOS 只能选择 P0 所需的最小传递闭包；不能把 321 个 schema 全量导入当作“完成协议层”。生成产物必须隔离在 `Generated/Protobuf`，并由 mapper 转为领域模型。

### Personalized 已锁定闭包

- root：`Personalized.proto`（1）
- direct imports：`CommonRequest.proto`、`ThreadInfo.proto`、
  `AppPosInfo.proto`、`Error.proto`（4）
- transitive imports：46
- total：51
- enum count：0；因此 unknown-enum test 为
  `NOT_APPLICABLE_NO_ENUM_IN_PINNED_SCHEMA`，以 raw `threadTypes=999` 保留测试
  代替，不能虚构 enum。

### PBPage 与当前联合闭包

- roots：`PbPage/PbPageRequest.proto`、
  `PbPage/PbPageResponse.proto`（2）
- request closure：6
- response closure：119
- PBPage union：125
- 与 Personalized closure 重叠：50
- 阶段 11 三-root union：126
- 新增 generated files：75
- 阶段 13 增加 ForumGuide request/response 两个 root；其 union 为 58，与阶段 11
  集合重叠 48，当前五-root union / generated output 为 136
- 阶段 13 新增 generated files：10
- 阶段 14 增加 FRS Page root；closure 为 74，与阶段 13 集合重叠 54，
  当前六-root union / generated output 为 156
- 阶段 14 新增 generated files：20
- `FrsPage/AdParam.proto` 与已有 `PbPage/AdParam.proto` 会生成相同 basename；
  生成器确定性地只将前者输出重命名为 `FrsPage/FRSAdParam.pb.swift`，Proto
  message/module identity 不变，避免 Xcode target 输入冲突
- generated `@unchecked Sendable` 精确 allowlist：23 个文件 / 24 处声明；
  手写代码仍为 0

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
| Forum Guide | `ForumGuideRequestData` | `ForumGuideResponseData` | `FollowedForum` 列表 |

### Layer 3：外层 wrapper

| Family | Request wrapper | Response wrapper | 错误 |
|---|---|---|---|
| Personalized | `PersonalizedRequest` | `PersonalizedResponse` | `Error` |
| FRS Page | `FrsPageRequest` | `FrsPageResponse` | `Error` |
| ThreadList | `ThreadListRequest` | `ThreadListResponse` | `Error` |
| GeneralTab | `GeneralTabListRequest` | `GeneralTabListResponse` | `Error` |
| PB Page | `PbPageRequest` | `PbPageResponse` | `Error` |
| PB Floor | `PbFloorRequest` | `PbFloorResponse` | `Error` |
| Forum Guide | `ForumGuideRequest` | `ForumGuideResponse` | `Error` |

PBPage 两个 root 的递归 closure 已由阶段 11 脚本锁定为 125，并与
Personalized 合并为 126；阶段 13 再与 ForumGuide request/response
closure 合并为 136；阶段 14 加入 FRS Page 后为当前 156 个文件。
PB Floor 与 ThreadList 仍未进入当前生成集合，
不能从旧的约数推断其闭包。

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

阶段 14 的生产 mapper 只消费首屏需要的 `forum`、`thread_list` 和
`user_list`：`ForumInfo.id/name/slogan/avatar/member_num/thread_num/post_num`
映射为 `ForumSummary`；`ThreadInfo.id` 是稳定 row identity，
`ThreadInfo.threadId` 独立作为 `ThreadRoute`，二者不混同；
`isTop == 1` 形成置顶分组并保持服务器顺序。作者优先按 `authorId` 从
`user_list` 回填，缺失时再用 embedded author，最终降级为统一未知作者。

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

`LOCAL_BUILD_EVIDENCE`：

- SwiftProtobuf 1.38.1 已生成并编译 `hasX/clearX` presence API。
- `AppPosInfo.ap_connected` 的 absent 与 explicit `false` wire bytes 不同，
  decode 后 presence 保留。
- Personalized 顶层追加 field 2047 的 unknown varint，decode/re-encode/decode
  后 `UnknownStorage` 保留且领域 mapper 结果不变。
- pinned 51-file closure 没有 enum；fixture 的 `threadTypes=999` 由 mapper
  原样保留。
- JVM fixture 对 message presence（第一条 video absent、第二条显式空
  VideoInfo）与 Swift 解码一致。

仍为 `UNKNOWN`：服务端是否区分 absent 与显式默认、裸整数的真实完整值域，
以及 Wire 6.4.0 特有实现与 Swift 的更广泛对照。不能把本地 round-trip 写成
服务端证据，也不能声明闭合 enum。

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

所有 P0 最终至少需要；阶段 07 当前只关闭 Personalized 子集：

1. 每个 P0 wrapper 的最小 request 编码 golden。
2. 正常/空/错误/缺 data/畸形 response。
3. `optional absent` 与 `optional explicit default` 的 byte-level 对照。
4. 未知 tag 解码、领域映射、再编码 round-trip。
5. 所有已知 PbContent raw type 及 `999`。
6. 图片尺寸、URL、voice、mention、author、pids、Page 冲突边界。
7. PB Page/PBFloor 重叠页、正序/倒序、锚点。
8. generated source 不含 UI import，UI target 不直接 import generated module 的结构检查。

Personalized 的 1、2（success/present-empty/missing-data/server error/
malformed）、3、4、raw `999` 和结构隔离已 `TESTED`。阶段 08 以
`ThreadInfo.firstPostContent#142` 为合成 carrier，已覆盖所有 Android
dispatcher P0 raw、unknown `999`、meme/poll message presence、URL/尺寸/空内容
降级与严格保序，状态为 `CROSS_LANGUAGE_GENERATED_AND_TESTED`。

PBPage wrapper、`Post.content#5`、首楼/普通楼层、图片 intent、server error
和 route identity mismatch 已由阶段 11 完全合成的 Swift Proto response
`LOCAL_SYNTHETIC_TESTED`；尚无 tracked cross-language 或 live PBPage fixture。
FRS 已有 1 份完全合成、脱敏的 response fixture、确定性 request/mapper
测试，以及 2026-08-05 匿名公开吧首屏运行观察；这不等于 live response
fixture。PB Floor、FRS/ThreadList 真实分页与普通楼层折叠/删除常态仍为
`NOT_CREATED/NOT_TESTED`；不得用首楼或 FRS synthetic fixture 替代运行证据。

## 来源与复制边界

Android reference 根目录含 GPL version 3 许可证文本，README 另有非商业
声明；逐文件授权、上游权利链及两者关系仍为 `UNKNOWN`。ADR-0011 仅在项目
负责人明确的本地/个人/非商业范围允许从 exact pinned submodule 生成历史
51-file Personalized closure；ADR-0013 在同一边界内批准历史 126-file
Personalized + PBPage union；ADR-0015 以相同边界批准当前五个 root、
136-file union；ADR-0016 在同一边界增加 FRS root，形成当前六-root、
156-file union。不把 `.proto` 复制进 iOS 树，也不使用
`n0099`。公开分发、
App Store、商业使用及 notice/源码义务仍 `BLOCKED`；扩大范围前必须按
`Docs/Audits/SOURCE_AND_LICENSE_NOTES.md` 新建权利决策，必要时切换到
clean-room 最小兼容 schema。
