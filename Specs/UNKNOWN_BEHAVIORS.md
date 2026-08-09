# 未确认行为与安全验证计划

状态：`OPEN`

Android 静态源码不是服务端或运行时证据。本文件集中记录所有 `UNKNOWN`，防止后续根据字段名、旧客户端实现或模型记忆补全协议。

## 验证原则

1. 先用构造 fixture 验证 mapper/state，再申请受控 live 验证。
2. 只使用专用测试账号和公开测试内容；不收集用户密码。
3. 抓取前定义字段白名单；落盘前移除 Cookie、BDUSS、STOKEN、TBS、手机号、授权头和可追踪设备 id。
4. 不关闭 TLS、不接受任意证书、不使用明文 HTTP 发送凭据。
5. 一次实验只改变一个变量，并记录 client state、请求类别、脱敏响应 hash 和结果。
6. 任何结论需最少一个可复现 fixture；截图不能代替 wire/state evidence。
7. 验证产物放 `Docs/Audits/` 与 `TestSupport/Fixtures/`，并更新 `Specs/API_EVIDENCE.md`。

## 最高优先级五项

| ID | 证据缺口 | 当前已知 | 最小安全实验 | 升级条件 |
|---|---|---|---|---|
| U-01 | 登录、验证码、Cookie/token 轮换、过期、多账号退出 | 阶段 12 已用可见 WKWebView 完成一次真实登录与 Keychain 重启恢复，携带两个候选字段的 active Personalized 请求成功返回；真实 logout 按用户保留凭证要求未运行，轮换/过期码/多账号仍未知 | 继续只由用户手工验证；logout 后重新登录、rotation、失效和重复回调只记录状态/字段存在性，不记录 token 值 | HTTPS 合法方案 + 脱敏 taxonomy + Session fixture/state tests + 真实 logout/expired evidence |
| U-02 | HTTP endpoint 的安全 HTTPS 等价路径和最小参数 | 关注吧、登录、picpage 当前 call site 是 `http://c.tieba.baidu.com` | 不调用 HTTP；从官方可观察 HTTPS 流或 reference 新 Proto call site寻找候选；单 endpoint、无凭据的公开请求先验证 TLS/编码 | 全程 HTTPS、无降级、最小字段有 evidence、成功/错误 fixture |
| U-03 | FRS dynamic tab 与 `thread_id_list`/page 契约 | 阶段 14P 已验证匿名 FRS `pn=2/load_type=2` 一页下一页；Android client 仍先消费最多 30 ids，再取下一 FRS page | 继续对同一公开吧记录更后页、tab raw fields、ThreadList 请求 ids、返回顺序、空/缺项；匿名与登录分开 | 动态 tab 值域与稳定 id、ThreadList 排序/终止/缺项策略均有 fixture |
| U-04 | PB `page=0+pid`、删除/私密/缺作者及并发 | Android 有多种锚点调用；mapper 强制 author；不同 intent 可并发 | 先构造 malformed/overlap fixture；再对公开帖验证首/中/末页、pid anchor、删除楼、升降序；用延迟 stub 重放竞态 | anchor/cursor/error taxonomy + stale-response tests |
| U-05 | 推荐匿名能力、顺序、空页与终止条件 | 阶段 11 无 session Probe 有一次 67 项非空页后稳定空页；阶段 12 携带 active Session candidate 的请求单次映射 12 项。均未保存响应 fixture，不能据此证明匿名/认证稳定性、顺序或终止条件 | 无 session/测试 session 对照公开内容；限制最大请求页，记录脱敏 item id 序列、空页、重复页与错误类别 | 匿名规则、稳定去重顺序、客户端安全上限和终止策略均有 fixture/state tests |

## API / 认证

| ID | UNKNOWN | 安全验证方法 |
|---|---|---|
| U-06 | Personalized、FRS、PB、PBFloor 是否真正支持匿名 | FRS 固定公开吧匿名首屏+一页下一页和 PBPage 公开帖匿名首屏+一页下一页已限定运行成功；Personalized 仍有不可复现的无 session 非空观察，PBFloor 未发出；跨吧、更多页及认证对照继续 `UNKNOWN` |
| U-07 | `CommonRequest`/headers/外层 stoken 的最小必需集合 | 阶段 11 静态字段证明 HTTP/Proto 可达；阶段 12 按 Android evidence 增加 CommonRequest BDUSS/STOKEN 与外层 stoken 后单次成功，但没有逐字段消融，也不证明服务器实际消费 credential，不能称为最小集合；禁止复制 Android telemetry 全集 |
| U-08 | legacy sign 是否仍必需、是否允许 iOS 使用 | 只通过已批准协议/法律审查和 HTTPS 受控验证；在此之前不实现 |
| U-09 | Error.error_code、user_msg、HTTP status 的真实 taxonomy | 为成功、未登录、过期、无权限、删除、限流、服务器错误采脱敏 fixture |
| U-10 | 60 秒 timeout 是否是产品需求 | 使用本地延迟 stub 测 1/5/30/60 秒；最终 timeout 由 iOS UX 决策，不复制 Android |
| U-11 | redirect 是否存在以及是否会在 HTTP body 发送后发生 | 不以真实凭据测试 HTTP；只允许网络文档/无凭据安全探测，且不能据 redirect 解锁 HTTP |
| U-12 | Proto forumGuide 能否等价替代当前 form endpoint | 先找 production call site 或以同账号对比两端脱敏结果/分页；字段齐全才可候选 |

## 分页与顺序

| ID | UNKNOWN | 安全验证方法 |
|---|---|---|
| U-13 | 推荐终止信号 | 连续取页直到空/重复/错误，限制最大页；记录 item ids 和 raw response fields |
| U-14 | 推荐刷新应替换还是 `new + old` | 通过产品验收和 fixture 决策；不能以 Android reducer 的插入提示作为唯一依据 |
| U-15 | FRS `thread_id_list` 与 `thread_list`、下一 pn 的重叠/顺序 | 与 U-03 配对，断言 id 序列 |
| U-16 | ThreadList 空响应是终止、删除还是暂时错误 | 构造空/部分缺项；真实公开样本验证一次 |
| U-17 | GeneralTab `pn` 与 `last_thread_id` 冲突时优先级 | 以相同 pn 改 last id、相同 last id 改 pn；每次仅一变量 |
| U-18 | PB `pids` 的方向、request `r` sort 值域及恒定 `floor_sort_type=1` 的语义 | 正序/倒序/热序 fixture 对照；保留 raw pids、r 与 floor_sort_type |
| U-19 | PB Floor `has_more` 与 `current_page < total_page` 冲突 | 构造四种冲突 fixture，真实样本仅用于确认服务端常态 |
| U-20 | 合法空 post_list | 对已删除/私密/空回复公开可访问样本采脱敏 envelope；未确认前用 unavailable |

## Protobuf / schema

| ID | UNKNOWN | 安全验证方法 |
|---|---|---|
| U-21 | SwiftProtobuf 对 selected schema 的生成 API | `CLOSED_FOR_CURRENT_SIX_ROOT_LOCAL`：1.38.1 runtime/generator、Personalized/PBPage/ForumGuide/FRS 六 root、156-file manifest/hash、两次生成与 strict build 已验证；其他 P0 closure 仍 open |
| U-22 | proto3 optional absent 与显式 0/空字符串 | `LOCAL_WIRE_VERIFIED`：AppPos optional false 与 absent bytes/presence 已测；服务端差异仍属 U-07 |
| U-23 | 未知 tag 是否解码后可 round-trip 保留 | `LOCAL_WIRE_VERIFIED`：Personalized 顶层 field 2047 decode/re-encode/decode 保留；live server 行为不在结论内 |
| U-24 | 裸 int 状态/排序/type 完整值域 | 累积多 fixture，领域类型始终保留 `.unknown(raw)` |
| U-25 | 321 个 schema 中 P0 真正最小闭包 | `CLOSED_FOR_PERSONALIZED_PBPAGE_FORUMGUIDE_AND_FRS_LOCAL`：Personalized 51、PBPage 125、ForumGuide 58、FRS 74，当前六-root union 156；ThreadList/PBFloor 等仍 open |
| U-26 | schema 复用的许可证/分发后果 | `PARTIAL_LOCAL_POLICY`：ADR-0011/0013/0015/0016 允许本地、个人、非商业 exact pinned 生成当前 156-file union；公开分发/App Store/商业仍 `BLOCKED` |

阶段 07 local closure record：

```text
ID：U-21/U-22/U-23/U-25；U-26 仅局部决策
日期：2026-07-31
Android build 与 commit：4.0-dev / 5545326b2a8e0d784b2f3dfbcb219c7b121e61c2
iOS baseline：11768dd4b1416619ea396c12cf97616546cccad1（阶段 07 checkpoint）
scenario：pinned Personalized 51-file generation + JVM→Swift fixture decode/map
请求类别：未发送网络请求；constructed anonymous/evidence-only request bytes
fixture：TestSupport/Fixtures/API/Recommendations/personalized_cross_language.pb
SHA-256：54a838f8bd05c39e90b84b3bba4d4224dc81fe11b63934e23dd65be937eebb4a
观察结果：两次 Proto generation、两次 JVM fixture generation 均逐字节一致；
  optional false presence 与 absent 不同；unknown field 2047 round-trip 保留；
  raw threadTypes=999 保留；schema enum count=0。
与现有规格的差异：不再是“无 plugin/lock/schema”；只关闭 Personalized local
  tooling/wire 子集，匿名 live、服务端 presence、其他 P0 和公开分发不变。
新增测试：PersonalizedProtocolTests 全组；verify-protos；
  verify-personalized-fixture；networking-isolation。
结论标签：LOCAL_BUILD_EVIDENCE / CROSS_LANGUAGE_GENERATED；非 RUNTIME_EVIDENCE
```

阶段 11 local closure 与受控运行观察：

```text
ID：U-05/U-06/U-07（保持 OPEN）；U-21/U-25 扩展本地关闭范围；U-26 仍局部决策
日期：2026-08-04
Android build 与 commit：4.0-dev / 5545326b2a8e0d784b2f3dfbcb219c7b121e61c2
iOS baseline：302b7b8fb34a8da3e1171e6bc5dc48afe548494e（阶段 10 完成提交）
scenario：pinned Personalized + PBPage 三-root/126-file generation；Debug-only、
  无 session 的 Personalized 单页 Probe；有正 route ID 才允许链式 PBPage Probe
请求类别：HTTPS multipart protobuf；不含 Cookie、BDUSS、STOKEN、Keychain、
  AppPos、安装标识或设备标识；没有循环重试
fixture：没有保存 live response 或正文；PBPage mapper 使用完全合成的 Swift
  Proto response，因此不满足关闭 runtime UNKNOWN 的 fixture 条件
观察结果：Personalized HTTP 200、application/octet-stream、Proto 可解码；一次
  早期组合为 5550 bytes/67 mapped items，最终 evidence-locked 请求为 245 bytes/
  0 item/171 ms。最终结果没有正 threadID，PBPage Probe 按设计未发出。
与现有规格的差异：证明 transport/decode 的受控可达性，但没有证明稳定匿名
  推荐、最小字段、分页/终止、错误 taxonomy、canonical identity 或匿名 PBPage。
  Production 推荐和 ThreadReader 因此均 fail closed；Fixture 主链路保持离线可用。
新增测试：Stage11LiveRecommendationTests、Stage11PBPageProtocolTests、
  Stage11LiveCompositionTests，以及 Store request generation/cancellation tests。
结论标签：RUNTIME_OBSERVATION / LOCAL_SYNTHETIC_TESTED；非可复现 RUNTIME_EVIDENCE
```

阶段 12 可见登录与 active Session Personalized 观察：

```text
ID：U-01/U-05/U-06/U-07/U-09/U-35/U-37（全部保持 OPEN 或 PARTIAL）
日期：2026-08-04
Android build 与 commit：4.0-dev / 5545326b2a8e0d784b2f3dfbcb219c7b121e61c2
iOS baseline：2221793302250edcd0cdde591b0f92dfbc22db46（阶段 11 partial 提交）
scenario：用户在可见 WKWebView 手工登录；本机签名 iPhone Simulator 构建
  写入候选 Session、终止进程并从 Keychain 恢复；显式运行一次携带 active
  Session candidate 的 Personalized Debug Probe
请求类别：HTTPS multipart protobuf；matching active lease 授权；只发送 Android
  已证的 CommonRequest BDUSS/STOKEN 与外层 stoken，不发送密码、TBS、完整
  Cookie header、AppPos、安装标识或设备标识；没有循环重试
fixture：没有保存 live response、请求体、用户内容或 credential；自动化只用
  FakeSession、MockHTTPClient 和合成 Proto
观察结果：登录后与进程重启后均显示 signedIn；Probe 为 HTTP 200、
  application/octet-stream、83924 bytes、Proto decode 成功、12 mapped items、
  outcome=success。按用户保留凭证要求，真实 logout 未执行。
与现有规格的差异：关闭本机 Beta 可见登录与 Keychain save/load 的运行缺口，
  证明客户端可在 matching lease 下构造并完成携带候选字段的一页请求；不证明
  服务器实际消费 credential、字段最小性、rotation、expired taxonomy、真实
  logout、PBPage、关注吧或 Production live-ready。
新增测试：Stage12SessionTests、Stage12SessionCleanupTests 以及登录 URL/port、
  active request、lease、redaction、replacement、cleanup 和 Fixture isolation 回归。
结论标签：ACTIVE_SESSION_RUNTIME_OBSERVATION / LOCAL_BETA；非可复现 server fixture
```

阶段 14 FRS 本地闭包与匿名首屏观察：

```text
ID：U-03/U-06/U-09/U-15 保持 PARTIAL/OPEN；U-21/U-25 扩展本地关闭范围；
  U-26 仍局部决策
日期：2026-08-05
Android build 与 commit：4.0-dev / 5545326b2a8e0d784b2f3dfbcb219c7b121e61c2
iOS baseline：b6090a19c95fb720f24415975dc43e7729cae1df（阶段 13 提交）
scenario：pinned FRS root/74-file closure，与既有集合形成六-root/156-file
  generation；固定公开测试吧的 Debug-only 匿名首屏 Probe
请求类别：HTTPS multipart protobuf；无 Cookie、BDUSS、STOKEN、Keychain、
  AppPos、屏幕、安装或设备标识；没有循环重试
fixture：TestSupport/Fixtures/API/ForumHome/frs_page_synthetic.pb；454 bytes；
  SHA-256 940d1df7631795791eccde105a7cb4dcbf3f38d465a8ebf9bac6af4c850887b0；
  完全合成，不是 live capture
观察结果：无凭证 iPhone 与测试 iPad 均 HTTP 200、application/octet-stream、
  54068 bytes、Proto decode 成功、13 mapped threads、outcome=success；未保存
  response body 或内容
与现有规格的差异：只关闭固定公开吧匿名 FRS 首屏的 transport/decode/map；
  动态 tab、ThreadList、分页、跨吧稳定性、限流和错误 taxonomy 不变
新增测试：Stage14ForumHomeTests、ForumHomeSmokeTests、iPad AppShell Forum smoke、
  156-file generate/network/UI isolation gates
结论标签：LIMITED_RUNTIME_EVIDENCE / LOCAL_SYNTHETIC_TESTED；非 live fixture
```

阶段 14P FRS 顺序分页观察：

```text
ID：U-03/U-06/U-09/U-15 仍为 PARTIAL/OPEN
日期：2026-08-09
Android API build 与 commit：4.0-dev / 5545326b2a8e0d784b2f3dfbcb219c7b121e61c2
最新 UI 参考：4.0-dev / 268f388c7824ae2c8f6ed549827a943ec8a7f352
scenario：无凭证 Debug-only Probe，首屏 has_more 为真时单次请求
  FRS pn=2/load_type=2；无循环重试
观察结果：HTTP 200、application/octet-stream、156269 bytes、
  Proto decode 成功；首屏 13 条，追加 30 条后聚合 43 条，
  typed-error=none、outcome=success
隐私：未保存 response body、请求体、Cookie、吧/帖子/用户内容
与现有规格的差异：只关闭顺序 FRS 一页下一页的 transport/
  decode/map；第三页以后、thread_id_list + ThreadList、dynamic tab、
  sort、限流和错误 taxonomy 不变
结论标签：LIMITED_RUNTIME_EVIDENCE；非 live fixture
```

## 内容节点

| ID | UNKNOWN | 安全验证方法 |
|---|---|---|
| U-27 | raw type 9/27/35/40 原始语义 | 收集脱敏样本并比较相邻字段；在此之前只按当前 Android 文本行为渲染并保留 raw type |
| U-28 | `memeInfo` 的产品语义 | 构造 meme-only fixture；真实样本出现前保持 UnsupportedNode |
| U-29 | 未见 raw type 的分布 | 只记录 raw type 频次和字段存在性，不保存私密正文 |
| U-30 | 图片 URL 候选顺序与 HTTPS 可用性 | 对同一公开图片逐候选 HEAD/GET 的安全验证需后续授权；不放宽 ATS |
| U-31 | type 5 的 video/link 字段稳定性 | 正常/缺 src/坏 URL fixture；P0 保持安全降级 |
| U-32 | voice endpoint、格式、时长单位 | 不自动请求；取得公开样本和 HTTPS evidence 后再进入 P1 |
| U-33 | Poll type/status、匿名/已投/过期 UI | 构造全部 raw 状态；真实样本只验证展示，不执行投票 |
| U-34 | 删除/折叠/私密楼层的 wire 形态 | 与 U-20 配对；所有未知形态降级为 UnavailablePost |

## Session / 存储

| ID | UNKNOWN | 安全验证方法 |
|---|---|---|
| U-35 | iOS 登录方式与 App Store/平台边界 | `CLOSED_FOR_LOCAL_BETA`：ADR-0014 选择可见、first-party HTTPS WKWebView，不做 DOM/密码注入；App Store、服务条款和发布级隐私审计仍 OPEN |
| U-36 | 启动 refresh 失败时是否仍可浏览公开内容 | fixture session adapter + offline UI test |
| U-37 | Session commit/退出需清哪些 Cookie/Web data/cache | `PARTIAL_LOCAL_BETA`：当前撤销 lease、删除单一 Keychain item、清 App-owned nonpersistent WebKit store，并有失败/重试测试；真实 logout 按保留凭证要求未运行。cache aggregate、journal/ledger、midpoint crash recovery 与 Safari/系统浏览器数据继续 OPEN |
| U-38 | 多账号是否进入首版 | 产品决策；若无则模型仍须拒绝第二 session 并安全替换 |
| U-39 | Account User message 中哪些字段可持久化 | public profile 白名单评审；默认不保存未知字段 |

## 导航 / 交互 / 恢复

| ID | UNKNOWN | 安全验证方法 |
|---|---|---|
| U-40 | ADR-0003 已选择的 versioned route/safe-state snapshot 在进程死亡后的真实恢复正确性 | fixture App：各 Tab push 两层、设置 filter/anchor、终止进程再启动；验证最长合法前缀与排除 media/auth/session |
| U-41 | ADR-0003 已选择的当前 Tab 重选 no-op 在系统 Tab/VoiceOver 下是否始终无副作用 | UI test 重选 root/子页各 20 次，断言 path、anchor、请求数和可访问焦点不变 |
| U-42 | iPad sidebar/split collapse 后 route 恢复 | iPad simulator 多宽度 UI smoke |
| U-43 | deep link 中文吧名、短链和重定向 | 本地 URL parser fixture 优先；网络 redirect 后续独立验证 |
| U-44 | thread anchor 在数据刷新/删除后恢复 | post id fixture：存在、移动、删除三组 |
| U-45 | Reduce Motion 下 Media/Tab/refresh 行为 | UI test 启动参数切换 Reduce Motion；功能断言不依赖动画 |

## 搜索 / P1

| ID | UNKNOWN | 安全验证方法 |
|---|---|---|
| U-46 | Hybrid search endpoint 稳定性与 Cookie 必要性 | 匿名/测试 session 对照；只保存脱敏 public result |
| U-47 | 搜索建议慢响应顺序 | 本地 stub 反向延迟 query，验证 latest-cancel |
| U-48 | forum/user 搜索是否分页 | 检查真实 response 的 pn/has_more，并用第二页验证 |
| U-49 | 搜索 thread 重复率与 sort 值域 | 多页 id 序列 fixture；未知 sort 保留 raw |

## Media / 交互验证

| ID | UNKNOWN | 安全验证方法 |
|---|---|---|
| U-50 | Media 缩放与 pager 仲裁、边界加载、失败/旋转 | 使用 3 图 fixture：中图缩放/平移→翻页→首尾边界→断网/重试→旋转/分屏→返回；验证已批准的逐页 transform reset、进程恢复只回父 route，以及 iPhone/iPad 一致行为 |

## Android 源码异常不等于产品行为

以下只能作为回归风险线索，不应通过运行实验“固化”为 iOS 行为：

- Forum 成功后 `isLoading=true`。
- 固定 20ms/1s/1.5s/2s delay。
- refresh/page failure 只 Toast 或静默。
- `first/!!/toLong()` 导致畸形响应 crash。
- 未知内容节点静默丢弃。
- Media 单击关闭、吞掉触摸 RuntimeException。
- 单 root NavHost 与返回键跳 home。
- 明文 Room 凭据和 cleartext endpoint。

## 关闭 UNKNOWN 的记录格式

每项关闭时必须追加：

```text
ID：
日期：
Android/iOS build 与 commit：
scenario：
请求类别（不含 secret）：
fixture 路径与 SHA-256：
观察结果：
与现有规格的差异：
新增测试：
结论标签：RUNTIME_EVIDENCE
```

没有上述记录的项目不得从 `UNKNOWN` 改为已验证。
