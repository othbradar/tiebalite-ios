# 帖子内容节点矩阵

状态：`APPROVED_FOR_FIXTURE_DESIGN`

证据源：

- `References/TiebaLite-Android/app/src/main/protos/PbContent.proto::PbContent`
- `.../api/models/protos/Extensions.kt::List<PbContent>.renders`
- `.../ui/common/PbContentRender.kt`
- `.../ui/page/thread/ThreadPage.kt::PostCard/PollWidget`

本阶段没有真实响应样本。raw type 分支是 `CODE_EVIDENCE`；字段的服务端完整语义与出现频率仍为 `UNKNOWN`。

“支持状态”表示未来 P0 的目标处理等级，不是当前实现进度；阶段 01
仍没有 Swift 生产实现或 fixture。

## 节点矩阵

| Android/Proto 类型 | 字段与语义证据 | iOS 领域节点 | P0/P1 | 渲染 | 交互 | Fixture | 支持状态 | 证据 |
|---|---|---|---|---|---|---|---|---|
| `type=0` | `text`；Android 追加普通文本 | `TextNode(rawType: 0)` | P0 | Dynamic Type 文本，保留换行 | 选择/复制按系统 | 正常、空、超长、Unicode、混排 | `Supported` | `CODE_EVIDENCE` |
| `type=9` | Android 与普通文本同分支；原始业务语义未知 | `TextNode(rawType: 9)` | P0 | 与 text 一致，保留 raw type | 同文本 | 正常、空、与相邻节点 | `Degraded` | `CODE_EVIDENCE` / 语义 `UNKNOWN` |
| `type=27` | Android 与普通文本同分支；原始业务语义未知 | `TextNode(rawType: 27)` | P0 | 与 text 一致 | 同文本 | 正常、空 | `Degraded` | `CODE_EVIDENCE` / 语义 `UNKNOWN` |
| `type=35` | Android 当前与普通文本同分支；历史说明不足以证明“广告” | `TextNode(rawType: 35)` | P0 | 文本，不按猜测加样式 | 同文本 | 正常、空、URL-like text | `Degraded` | `CODE_EVIDENCE`; 原义 `UNKNOWN` |
| `type=40` | Android 当前与普通文本同分支；历史曾有不同处理 | `TextNode(rawType: 40)` | P0 | 文本 | 同文本 | 正常、空 | `Degraded` | 当前 `CODE_EVIDENCE`; 原义 `UNKNOWN` |
| `type=1` | `text` 为标签，`link` 为 URL annotation | `LinkNode(label,url)` | P0 | 链接样式；坏 URL 显示 label | 只允许白名单 scheme；系统确认/打开 | http/https、空 label、坏 URL、超长 URL、未知 scheme | `Supported` | `CODE_EVIDENCE` |
| `type=2` | `text/c` 注册表情，Android 渲染 `#(c)` | `EmojiNode(code,fallbackText)` | P0 | 有资源显示表情，无资源显示可读 fallback | 无 | 已知、未知、空 code、超长 | `Degraded` | `CODE_EVIDENCE`; 资源映射 `UNKNOWN` |
| `type=3` | 图片；URL 候选来自 origin/big/cdn/dynamic/src；尺寸取 `bsize` | `ImageNode` | P0 | 固定稳定占位；适配尺寸；失败占位 | 打开唯一 MediaViewer | 正常、GIF/长图、坏 URL、所有 URL 空、bsize 空/坏/零/极大 | `Supported` | `CODE_EVIDENCE` |
| `type=4` | `text` + int64 `uid`，Android 创建 user annotation；未提供时 proto3 默认为 0 | `MentionNode(userID?,label)` | P0 | 可读提及；uid=0 时仍显示 label | 合法 userID 进入 P1 profile；否则不导航 | 正常、uid 0/Int64 极值、空 label | `Supported` | `CODE_EVIDENCE` |
| `type=5`, `src` 非空 | `link` video URL、`src` thumbnail、`text` web URL、`bsize` | `VideoNode` | P1；P0 安全降级 | P0 显示 thumbnail + “视频”占位；P1 可播放 | P0 可打开经校验外链；不自动播放 | 正常、仅 thumbnail、坏 video/web URL、坏尺寸 | `Degraded` | `CODE_EVIDENCE` |
| `type=5`, `src` 为空 | Android 显示视频图标和 `text` URL | `LinkNode(kind: video)` | P0 降级 | “视频”+ 可读 URL/label | 白名单外链 | 正常、空 text、未知 scheme | `Degraded` | `CODE_EVIDENCE` |
| `type=10` | `voiceMD5/duringTime`；Android 拼接语音 URL | `VoiceNode(resourceID,duration)` | P1；P0 安全降级 | P0 显示语音占位与时长 | P1 播放；P0 不静默请求未知 URL | 正常、空 MD5、duration 0/极大、失败 | `Degraded` | `CODE_EVIDENCE`; URL 稳定性 `UNKNOWN` |
| `type=20` | 图片替代分支，显示/原图都取 `src`，尺寸仍取 `bsize` | `ImageNode(rawType: 20)` | P0 | 同图片；保留 raw type | MediaViewer | 正常、坏 src/bsize | `Degraded` | `CODE_EVIDENCE`; 类型原义 `UNKNOWN` |
| 其他 int（如 999） | Android 没有 else，会静默丢弃 | `UnsupportedNode(rawType,safeText)` | P0 | 明确、紧凑、不遮挡的“不支持内容”占位；相邻内容不丢 | 无；Debug 可显示 raw type，不显示敏感 raw payload | 未知 type、空字段、带 text/link/src、连续未知节点 | `Unsupported` | iOS 降级 `REQUIRED` |
| `memeInfo` | PbContent 字段存在，主源码无消费点 | `UnsupportedNode(kind: meme)` | P0 降级 | 占位；若 `text` 可安全保留则附 fallback | 无 | memeInfo only、meme + text | `Unknown` | `UNKNOWN` |
| `ThreadInfo.poll_info` | 非 PbContent；`PollWidget` 显示 title/tips/options/count/status | `ReadOnlyPollNode` | P0 只读 | 单/多选标签、选项、票数/比例、截止/关闭状态；未知状态降级 | 不允许投票提交 | 单选/多选、匿名、已投、过期、关闭、图片选项、total=0 | `Degraded` | `CODE_EVIDENCE`; 状态值域 `UNKNOWN` |
| 删除/折叠 Post | `Post.is_fold/fold_tip/is_post_visible` 等字段存在；完整服务端形态未知 | `UnavailablePostNode` | P0 | 保留楼层身份和说明，不崩溃 | 无 | 删除、折叠、私密、缺 author/content | `Degraded` | 字段 `CODE_EVIDENCE`; 行为 `UNKNOWN` |
| 空 content | repeated 为空或全为未知节点 | `EmptyContentNode` | P0 | 可访问的“内容不可用”占位 | 无 | 空数组、仅未知、仅空文本 | `Degraded` | iOS 降级 `REQUIRED` |

## Mapper 规则

以下是 iOS 规范，不复制 Android 强制解析：

1. 输入顺序必须等于输出顺序；相邻 text-like 节点可以在渲染层合并，但需保留语义范围。
2. 未知 raw type 必须生成 `UnsupportedNode`，不能丢弃。
3. 缺字段或坏字段只使当前节点降级，不使整层楼、整页或相邻节点失败。
4. 图片/视频尺寸使用安全解析：
   - 正宽高：采用 aspect ratio；
   - 缺失、非数字、零、负数、溢出：使用稳定默认比例；
   - 不以强制索引/split/int conversion 解析。
5. URL 在 mapper 中解析为安全值或 invalid 状态；View 不直接拼接未知 scheme。
6. mention 的 uid 不合法时保留 label 并关闭导航。
7. voice resource id 为空时不构造网络 URL。
8. poll `total_poll <= 0` 时比例为未知/0，不除零；任何 submit action 都不存在。
9. 生成 Proto 不进入 View；领域节点必须是 `Sendable` 值类型。
10. Debug raw payload 也不得包含 Cookie/token/私密响应。

## 图片 URL 证据

`CODE_EVIDENCE`：Android `PbContent.picUrl` 调用 `ImageUtil.getUrl`，传入 origin、big CDN、big、dynamic、CDN active/src 等多个候选；`ImageUtil.getUrl/needReverse` 又会按图片设置与网络状态反转候选顺序。因此源码只能证明候选集合与条件分支，不能证明一个固定全局优先级。该选择逻辑是 Android 客户端策略，不是服务端契约。

`INFERENCE`：iOS `ImageCandidateSet` 应保留来源列表，由 image repository 选择；选择策略、HTTPS 升级、缓存 key 和隐私过滤需独立规格。任何 `http://` 图片 URL 必须拒绝或经已验证 HTTPS 规范化，不能放宽 ATS。

## 排版与连续图片

`CODE_EVIDENCE`：Android `PostCard` 把连续 `PicContentRender` 聚合为 waterfall，多列数随 window width 改变。

`INFERENCE`：

- P0 只要求稳定、可访问的连续图片布局与正确 MediaViewer 次序，不要求复制 waterfall。
- 图片列表身份使用 media id/稳定 URL hash，不使用数组 index 作为唯一身份。
- Dynamic Type 不能使文本和相邻媒体重叠。
- 加载失败保持占位尺寸，避免列表跳动和透明露底。

## 交互边界

- Link：只允许已批准 scheme；外部打开由系统处理。
- Mention：P1 profile route；P0 可显示不可点击。
- Image：打开唯一 MediaViewer；来源列表和 initial media id 必须稳定。
- Video/Voice：P0 可降级，不自动播放、不后台预取未知媒体。
- Poll：永远只读。
- Unsupported/Empty/Unavailable：无手势，不吞相邻点击，不覆盖页面。

## Fixture 套件

建议目录 `TestSupport/Fixtures/ContentNodes/`，当前全部 `NOT_CREATED`：

- 每个已知 raw type 的正常样本。
- `type=5` 的 thumbnail/player 与 link fallback 两支。
- 未知 `999`，以及未知字段 tag round-trip。
- text 空/超长/多语言/RTL/组合 emoji。
- URL 空、非法、超长、非 http(s)、相对 URL。
- 图片 `bsize=""`、单段、非数字、0x0、极大值；全部 URL 候选为空。
- mention uid 为 proto3 默认 0、负值语义或 Int64 极值；楼中楼 nullable author 产生 `"null"` annotation 的独立样本。
- voice id 空、时长 0/负语义/极大值。
- post author 缺失且 user list 有/无匹配。
- content 空、仅未知节点、未知节点夹在两个文本节点之间。
- poll total=0、未知 status/type、无选项、重复 option id。
- 删除/折叠/不可见楼层。

每个 fixture 至少断言：domain 节点类型、稳定 id、可访问 fallback、相邻顺序、无 crash、无敏感字段。

## 已知 Android 风险（不得照搬）

- `bsize.split(",")[0/1].toInt()` 可因缺失/畸形崩溃。
- 普通图片/视频高度为零时没有统一比例保护。
- 未知 type 静默丢弃。
- 楼中楼 content renderer 空时使用 `reduce` 可崩溃。
- author 空时可能生成 `"null"` mention，点击再强制转 Long。
- Poll 比例未防 `total_poll=0`。
- Video/voice URL 构造和播放依赖 Android 库与当前 endpoint，不是跨平台证据。

在上述 fixture 通过前，内容节点状态保持 `APPROVED_FOR_FIXTURE_DESIGN`，不得声明生产级支持。
