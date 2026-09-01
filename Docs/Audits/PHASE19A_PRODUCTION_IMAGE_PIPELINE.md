# 阶段 19A：Production 图片加载链路审计

- 日期：2026-09-01
- 基线：`b1b50cd117ac950bf97678d641df615f4dfaf180`
- Android reference：`5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`
- 标准：个人开源 Beta
- 状态：`COMPLETE`
- 后续阶段：`PHASE_19B_RELEASE_CANDIDATE = NOT_STARTED`

## 范围与根因

阶段 18 的记录没有过时：Production composition 确实注入
`DisabledImageLoader`，列表 mapper 也只保留媒体数量或丢弃候选 URL。
ThreadReader 与 MediaViewer 虽已有稳定六态、MediaIntent 和唯一交互实现，
加载时仍只传 resourceID，并且只消费 raw bytes；因此 Live 模式下推荐/FRS
只有占位，正文显示加载失败，也无法用真实图片进入 Viewer。

本阶段只接通以下既有入口：推荐缩略图、FRS/吧首页缩略图、帖子正文图片、
唯一 MediaViewer。头像 portrait 仍保留现有占位，因为当前模型只提供 opaque
token 或没有已证的安全 HTTPS URL，阶段 19A 不猜 host，也不扩大头像布局。

## Android 证据与候选顺序

- Feed/FRS `Media`：`big_pic → dynamic_pic → src_pic`，没有可用缩略图时
  才使用 `origin_pic`。证据为 `FeedCard.kt::ImmutableHolder<Media>.url` 与
  `ImageUtil.getUrl`。
- PB type 3 正文：`big_cdn_src → big_src → dynamic → cdn_src →
  cdn_src_active → src → origin_src`。证据为
  `Extensions.kt::PbContent.picUrl`；`origin_src` 是缩略候选为空时的 origin
  fallback。
- Viewer：`origin_src` 优先，随后只尝试上述已返回候选；type 20 只使用
  `src`。证据为 `PhotoViewUtils.kt`、`PhotoViewActivity.kt` 与
  `Extensions.kt`。
- Android Sketch 资源请求没有附加账户 Cookie 的证据，只有普通
  User-Agent 配置。iOS 使用完全独立的匿名图片 session，不读取
  AuthContext/ProtectedDataLease。
- Android call site 按高到低提供缩略 vararg，但 `ImageUtil.getUrl` 会根据
  imageLoadSettings/Wi-Fi 反转后只选一条。iOS Beta 固定采用高到低有限
  fallback，没有复制该 network/settings reversal。

iOS 的有限候选回退是本阶段的客户端韧性策略：一个候选只有在 HTTP、MIME、
大小和 ImageIO decode 全部成功后才算 rendered；失败只前进到下一条已证候选，
不合成 URL、不无限改写参数。Production descriptor 只保留 HTTPS，拒绝
credential URL、fragment、非绝对和超长 URL；没有新增 ATS 例外。

## Loader 与资源边界

唯一 `ProductionImageLoader` 使用系统 `URLSession`、`URLCache`、`NSCache`
和 ImageIO：

- 独立 ephemeral session；Cookie storage/credential storage 为 nil，
  request 禁止处理 Cookie；redirect fail closed。
- response 上限 24 MiB；source pixel 上限 120,000,000；只接受 2xx 和
  `image/*`，MIME 缺失时必须由 ImageIO 可靠识别。
- 解码缓存总 cost 上限 96 MiB、count 上限 256，cost 使用
  `bytesPerRow × height`；收到 memory warning 清空。原始响应只使用
  32 MiB memory-only URLCache，不建立自定义磁盘库。
- cache key 包含稳定 resourceID、purpose、resize mode、目标像素尺寸和
  有边界分隔的候选指纹；正常 identity 不使用 UUID。
- ImageIO 始终使用 thumbnail decode、EXIF transform 和立即缓存；最大解码边
  为 8192。`.fit` 保持比例，`.fill` 在安全下采样后中心裁到目标 pixel box，
  极端长图不会把超长边作为列表缓存结果。
- 网络/状态/MIME/大小/解码错误保持 typed；取消在 cache insert 和 UI 投影前
  再检查，取消不能被迟到的 typed decode failure 改写。

## 页面接入与状态

- Recommendation 与 ForumHome 使用 mapper 传入完整资源描述，并从实际
  cell geometry × displayScale 得到 `.listThumbnail` target；加载状态只属于
  cell-local SwiftUI state，不改 row identity、不重新 apply diffable snapshot。
- Forum media 继续保留原始 media ordinal；过滤无效 URL 后不重新编号。
  缺安全候选时保留原占位几何。
- ThreadContentRenderer 只修改图片节点的数据请求：仍使用
  idle/loading/rendered/failedToFetch/failedToDecode/cancelled 六态；只有当前
  request 成功解码后才产生可打开的 MediaIntent。
- MediaViewer 使用 viewport × displayScale 的 `.mediaViewer` target，优先
  origin candidate；关闭/换页/旋转由现有 `.task` identity 和 generation
  丢弃迟到结果。没有修改 Pager、zoom/pan ownership 或页面切换逻辑。

## 回归与校准

- 新增 loader 成功、HTTP、MIME、坏 bytes、大小上限、候选回退、缓存命中、
  target 分离、EXIF、非法 target、日志脱敏、取消、极端长图 fill 回归。
- 新增 Feed/FRS/PB/Viewer 候选顺序和稳定 identity 映射测试。
- 新增真实 `UITableView` A→B cell reuse，证明 A 的迟到图片不能污染 B。
- Fixture/UI Testing composition 固定使用 Fixture/Harness loader；即使请求描述
  带 HTTPS candidate，也只按本地 resourceID 读取，Mock HTTP 事件保持空。
- 终审发现并先用红测试复现两项直接风险：取消与 typed decode failure
  rendezvous 会误投失败；极端长图 `.fill` 会产生超过 target 的解码结果。
  修复只增加 cancellation-first 检查和 bounded center crop，定向测试随后转绿。

## Live Simulator 证据

- 保留既有 Keychain 会话，没有 logout、重装 credential device 或读取凭据。
- Live 推荐首屏显示多张真实缩略图；关注吧列表进入公开吧后，FRS 行显示
  与帖子对应的真实缩略图；进入帖子再返回仍对应原行。
- 单图帖正文进入“已加载”，Viewer 显示真实图片；双击达到 2.50×，关闭返回
  原帖子。连续打开/渲染/关闭/返回 5 次均正常，前后台一次后 route 和会话保持。
- 另一个公开帖的 8 张正文图片全部 rendered；从第 3 张打开 Viewer，连续
  显示第 3、4、5 张，页码与稳定 MediaID 一致，关闭后仍回到同一帖子。
- 多次上下滚动未出现失败状态、错位 identity、连续白块或明显超过 1 秒卡死。
- Live 日志与文档没有记录图片 URL、response body、帖子正文、用户信息、
  Cookie、BDUSS 或 STOKEN。

## 最终门禁

- 图片定向套件 54/54；完整 Unit 376 个逻辑测试、400 次执行，
  0 failed/0 skipped。
- iPhone smoke 28/28，包含单图/多图 Viewer、5 次开关、长帖图片语义与
  offline Fixture 失败重试；iPhone interaction 15/15。
- iPad 首次完整 smoke 11/12，唯一失败是既有组件画廊入口偶发
  `not hittable`，与图片链路无关。该用例独立 3/3，随后完整 iPad smoke
  12/12，最终 `make quality` 中再次 12/12；iPad interaction 2/2。
- `make instructions`、`make secret-scan`、`make lint`、`make quality-fast`、
  `make release-isolation`、`git diff --check` 与 Android submodule clean 检查通过。
- `make quality` 输出 `Quality gate completed.`；Release 包含生产
  Renderer/Pager/MediaViewer/图片 loader，排除 TestSupport 与 Debug Lab。

## 变更边界与 Known Limitations

- 没有修改 `VirtualizedList`、UITableView diffable identity、Forum/PB 分页、
  PagerContainer、MediaZoomImageView、Session/Keychain、Live endpoint、动画、
  手势或 overlay；Renderer 非图片节点未改。
- 头像仍为占位；opaque portrait token 的安全 HTTPS 规则是 UNKNOWN。
- GIF/WebP 等动态资源本阶段只保证可显示帧，不实现动画播放。
- 不实现 full-resolution lease、瓦片缩放、自定义磁盘数据库或全 CDN 压测。
- 没有为了人工断网检查修改宿主机网络设置；失败/重试由确定性 offline Fixture、
  HTTP/MIME/decode/cancellation Unit 覆盖，真实 CDN 断网错误分布仍是人工发布项。
- iPad Fixture 图片打开/关闭已由 smoke 两次 12/12 和最终 quality 证明；
  无凭据 iPad 上未单独完成 Live CDN 手工往返，不将其写成已验证。
- memory-warning 观察者会清理 decoded cache，但本轮未人工注入系统
  memory warning；也没有实现跨 View 的 in-flight 请求合并。
- 当前候选 redirect fail closed；若未来服务端稳定改为 redirect，必须先补脱敏
  runtime evidence 和跨 host credential policy，不能直接放宽。
