# 帖子内容节点矩阵

状态：`PHASE_08_IMPLEMENTED_AND_VERIFIED`

本矩阵只使用只读 Android submodule
`5545326b2a8e0d784b2f3dfbcb219c7b121e61c2` 的代码证据。raw type
是 `PbContent.type` 的裸 `int32`，不是 enum；服务端原义和出现频率没有响应
样本佐证时仍为 `UNKNOWN`。

## 证据路径与边界

- 正文 wire 类型：
  `References/TiebaLite-Android/app/src/main/protos/PbContent.proto::tieba.PbContent`
  （`type` field 1）。
- Android raw dispatcher：
  `References/TiebaLite-Android/app/src/main/java/com/huanchengfly/tieba/post/api/models/protos/Extensions.kt::List<PbContent>.renders`
  （行 222–357）。
- Android render 类型与文本合并：
  `References/TiebaLite-Android/app/src/main/java/com/huanchengfly/tieba/post/ui/common/PbContentRender.kt::PbContentRender/TextContentRender/PicContentRender/VoiceContentRender/VideoContentRender`
  （行 60–253）。
- 首楼正文实际消费路径：
  `References/TiebaLite-Android/app/src/main/java/com/huanchengfly/tieba/post/ui/page/thread/ThreadViewModel.kt`
  行 154 的 `threadInfo?.firstPostContent?.renders`，对应
  `ThreadInfo.proto::ThreadInfo.firstPostContent` field 142。
- 普通楼层 wire 路径（只读审计，当前 Swift 闭包不含 `Post.proto`）：
  `PbPageResponse.data#2 → PbPageResponseData.post_list#6[]` 或
  `first_floor_post#38 → Post.content#5[] → PbContent.type#1`。
- Poll：`PollInfo.proto::PollInfo`、`PollOption.proto::PollOption`，由
  `ThreadInfo.poll_info#74` 携带；Android 展示为
  `ThreadPage.kt::PollWidget`（行 913 起）。

阶段 07 的 51-file 生成闭包完整包含 `ThreadInfo` 的 47-file 依赖闭包，包含
`PbContent/MemeInfo/PollInfo/PollOption`，因此阶段 08 不扩大、也不修改生成
Proto。`Post.proto` 需要额外 25 个输入且未获 ADR-0011 批准；普通楼层折叠/
不可见状态只能保持领域级合成降级，不能伪称 wire-verified。

## P0 节点矩阵

每一行的场景都在合成的
`thread-content.first-post.cross-language` binary fixture、明确标注的 Renderer
领域 fixture，或固定 generated-message mapper 构造测试中出现。iOS
状态只表示阶段 08 的处理等级。

| Raw/结构 | Android 文件与 symbol | Proto message / field 路径 | Android 展示/降级证据 | Fixture 场景 | iOS 状态 |
|---|---|---|---|---|---|
| `type=0` | `Extensions.kt::List<PbContent>.renders` 分支 `0,9,27,35,40` | `PbContent.type#1=0`, `text#2`；缺省 type 也解码为 0 | `appendText(text)`；空 text 不产生 Android 占位 | 含换行文本、空 text、尾部 text、超长领域 fixture | `SUPPORTED` |
| `type=9` | 同上 | `type#1=9`, `text#2` | 与普通文本完全同分支；业务原义 `UNKNOWN` | raw 9 与相邻 text | `DEGRADED` |
| `type=27` | 同上 | `type#1=27`, `text#2` | 与普通文本同分支；业务原义 `UNKNOWN` | raw 27 | `DEGRADED` |
| `type=35` | 同上；不得与 field 35 混淆 | `type#1=35`, `text#2` | 与普通文本同分支；业务原义 `UNKNOWN` | raw 35 | `DEGRADED` |
| `type=40` | 同上 | `type#1=40`, `text#2` | 与普通文本同分支；业务原义 `UNKNOWN` | raw 40 | `DEGRADED` |
| `type=1` link | `Extensions.kt::renders` raw 1；`PbContentRender.kt::PbContentText` URL annotation | `type#1=1`, label `text#2`, target `link#3` | 加 link icon/主色 label；现有 Android 路径内没有 scheme 校验 | HTTP/HTTPS、`javascript:`、空 label/target 构造 | `SUPPORTED`（非 HTTP(S) 只显示 label） |
| `type=2` emoji | `Extensions.kt::renders` raw 2 | `type#1=2`, registry key `text#2`, code `c#11` | 注册 `(text,c)` 后显示 `#(c)`；资源表/未知资源最终行为 `UNKNOWN` | 合成 code、空/未知 code 领域 fixture | `DEGRADED`（可读 fallback） |
| `type=3` image | `Extensions.kt::PbContent.picUrl` 与 `renders` raw 3；`PbContentRender.kt::PicContentRender` | `type#1=3`; candidates `originSrc#25,bigCdnSrc#9,bigSrc#6,dynamic#16,cdnSrc#8,cdnSrcActive#36,src#4`; size `bsize#5`; `originSize#27`, `showOriginalBtn#35` | 强制拆 `bsize`；坏值可崩；候选策略受 Android 设置影响；连续图片进入 waterfall | 正常、多候选、坏 URL、空字段、非正/越界/极端比例、多图及 image success/loading/failure | `SUPPORTED`（只保留经验证 HTTPS candidate） |
| `type=4` mention | `Extensions.kt::renders` raw 4；`PbContentRender.kt::PbContentText` user annotation | `type#1=4`, label `text#2`, `uid#15` int64 | 点击时直接 `toLong()` 导航；缺省 uid 为 0 且 Android 没有合法性 guard | uid 7301、uid 缺省 0、空 label 构造 | `DEGRADED`（保留 uid/label，阶段 08 不建 profile route） |
| `type=5`, `src`、`link` 非空 | `Extensions.kt::renders` raw 5；`PbContentRender.kt::VideoContentRender` | `type#1=5`, web `text#2`, video `link#3`, thumbnail `src#4`, `bsize#5` | 构造 VideoPlayer；坏尺寸可崩 | player-shaped synthetic node | `DEGRADED`（thumbnail + 外链 intent，不播放） |
| `type=5`, `src` 非空、`link` 空 | 同上 | 同字段，`link#3` 缺省空 | 显示 thumbnail，点击 WebView(`text`) | thumbnail-only node | `DEGRADED` |
| `type=5`, `src` 空 | `Extensions.kt::renders` raw 5 的 else | `type#1=5`, `text#2`；`link#3` 被 Android 忽略 | 视频 icon + “视频” + `text`，并把 `text` 当 URL annotation | fallback URL、非法 scheme 领域 fixture | `DEGRADED` |
| `type=10` voice | `Extensions.kt::renders` raw 10；`PbContentRender.kt::VoiceContentRender` | `type#1=10`, `voiceMD5#12`, `duringTime#13` uint32 | Android 客户端拼写 endpoint 并播放；该 URL 不是跨平台协议证据 | resource/duration、空 resource、duration 0/极大 | `DEGRADED`（只读占位，不请求） |
| `type=20` alternate image | `Extensions.kt::renders` raw 20 | `type#1=20`, `src#4`, `bsize#5`, `originSize#27`, `showOriginalBtn#35` | 显示 URL、原图 URL、picId 都取 `src`；原义 `UNKNOWN` | 正常/坏 src 与 bsize | `DEGRADED`（安全 image node，保留 raw） |
| 其他（fixture `999`） | `Extensions.kt::renders` 的 `when` 无 `else` | `PbContent.type#1=999`；其余字段不可按未知语义消费 | Android 静默丢弃；夹在文本中会让两侧文本跨节点合并 | unknown 位于前后 text 之间、带 text/link、连续 unknown | `UNSUPPORTED`（低干扰占位，后续节点保留） |
| `memeInfo` presence | 全 Android Kotlin 源检索无消费 symbol | `PbContent.memeInfo#33 → MemeInfo(pckId#1,picId#2,picUrl#3,thumbnail#4,width#5,height#6,detailLink#7)` | recognized raw type 仍按 raw 分支；缺省 raw 0 + meme-only 等价空文本；完整语义 `UNKNOWN` | unknown raw + explicit `memeInfo`；absence 对照 | `UNSUPPORTED`（仅记录 safe kind/presence） |
| read-only poll | `ThreadPage.kt::PollWidget` | `ThreadInfo.poll_info#74 → PollInfo`; `title#12,tips#7,is_multi#2,is_polled#5,polled_value#6,end_time#8,status#10,total_num#3,total_poll#11,options#9`; option `id#1,num#2,text#3,image#4` | `showResult` 由已投/过期/status/账号决定；ratio 除 `total_poll` 未防 0；Android 有 submit，option image 未展示 | total=0、raw type/status 999、已投、多选、两 options、图片 option；message absent 与正数 total mapper 对照 | `DEGRADED`（永远只读、零除保护、image 不猜） |
| empty content | `ThreadInfo.firstPostContent` repeated 可为空；Android raw 0 empty 也无可见输出 | `ThreadInfo.firstPostContent#142=[]` 或所有 text empty | 无统一 Android 空占位 | empty document / only-empty-text | `DEGRADED`（可访问占位） |
| deleted first post | `ThreadInfo.proto`; Android删除状态完整行为仍无闭环 | `ThreadInfo.isDeleted#181`（只适用于 ThreadInfo，不等价 `Post.is_fold`） | 字段存在；具体值域与 UI 组合 `UNKNOWN` | raw 7 mapper 构造 + Renderer unavailable fixture | `DEGRADED`（iOS 保守策略：非零显示不可用并保留 raw） |
| folded/blocked ordinary post | `Post.proto::Post`、`ThreadPage.kt::PostCard/BlockableContent` | `Post.is_post_visible#39,is_fold#43,fold_tip#44`；不在当前生成闭包 | Android blocked 还包含本地偏好计算；服务端形态未闭环 | Renderer-only unavailable/blocked synthetic fixture | `DEGRADED / NOT_WIRE_VERIFIED` |

## 明确未伪造为节点的项目

- **line break/layout marker**：没有独立 raw node 证据；换行只作为
  `PbContent.text#2` 中的 `\n` 保序映射。状态为 `SUPPORTED_WITHIN_TEXT`。
- **quote**：`Post.quote_id#50` 只能证明楼层 metadata 字段，不能证明正文
  quote node 或展示形态；当前闭包也不含 `Post.proto`。状态为 `UNKNOWN / NOT_MODELED`。
- `PbContent.bigSize#7,imgType#10,width#18,height#19,mediaSubtitle#31,urlType#32,isLongPic#34`
  存在于 schema，但 `List<PbContent>.renders` 没有消费这些语义；阶段 08
  不将它们映射成用户可见语义。

## Mapper 不变量

1. 输出节点与 `firstPostContent` 输入一一对应且严格保序；阶段 08 不复制
   Android `appendText` 合并，因此相邻 text-like/raw 边界和 unknown 都可审计。
2. 单个 malformed 节点降级但不抛弃整篇；unknown 必须成为
   `UnsupportedNode`，不能静默丢弃。
3. scalar proto3 字段没有 presence；`type=0`、`uid=0` 与缺省无法区分，Mapper
   只能按值降级。只有 `hasMemeInfo`、`hasPollInfo` 可做 message presence 断言。
4. 图片尺寸只接受两个有限正整数；缺失、非数字、零、负数、溢出或极端比例
   使用固定安全 ratio，不强制索引/转换。
5. 图片候选只保留解析成功的 HTTPS URL；不升级 HTTP，不构造危险请求。
6. 外链只接受 HTTP/HTTPS 并映射为 intent；非法 scheme 保留 label，不发 intent。
7. mention uid≤0 时保留 label，不发 profile intent；voice 不拼 endpoint。
8. Poll 永远只读；`total_poll<=0` 时 ratio 为 0/unknown，不除零。
9. unknown 诊断只保存 raw type、source ordinal、已知字段 presence/kind，不保存或
   记录完整 Proto、正文、URL、Cookie/token。
10. Mapper 同步、纯值转换，不访问网络、磁盘、Keychain 或 MainActor；Proto 不
    穿过 Core mapper 边界进入 Feature/View。

## Cross-language fixture

- ID：`thread-content.first-post.cross-language`
- Binary：
  `TestSupport/Fixtures/API/ThreadContent/thread_content_cross_language.pb`
- Root/path：`tieba.ThreadInfo.firstPostContent#142[] → tieba.PbContent`
- 大小：1535 bytes
- SHA-256：
  `d37a7486974718d660a4b43466d914156c66d36f3f83982507915575e68cdf12`
- JVM producer：`scripts/fixtures/ThreadContentFixtureGenerator.java`
- 独立 textproto：`scripts/fixtures/thread_content_response.textproto`
- Provenance：`TestSupport/Fixtures/API/ThreadContent/PROVENANCE.md`
- 重建/验证：`make generate-thread-content-fixture` 与
  `make verify-thread-content-fixture`；后者比较两次 JVM generation、tracked
  bytes 和独立 `protoc --encode=tieba.ThreadInfo` bytes。

fixture 是人工合成、脱敏内容，只证明锁定 schema 的首楼正文 wire 与 mapper
契约；不证明 PBPage、普通楼层删除/折叠、live endpoint、媒体可达性或分发权利。

## 已知 Android 风险（不得照搬）

- `bsize.split(",")[0/1].toInt()` 可因缺失/畸形崩溃；图片/视频高度 0 时比例风险。
- 未知 raw type 静默丢弃，并可能让文本跨 unknown 合并。
- uid 缺省 0 仍可被 Android user annotation 导航。
- 楼中楼 content renderer 空时 `reduce` 可崩溃。
- Poll ratio 未防 `total_poll=0`，且包含本产品禁止的 submit 写操作。
- Video/voice URL 和播放行为依赖 Android 实现，不是跨平台协议证据。
