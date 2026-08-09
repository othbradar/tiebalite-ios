# 阶段 11：只读 Live Repository 接入审计

阶段 11 提交时状态：`RUNTIME_EVIDENCE_PARTIAL`

阶段 15.5 当前状态：`PHASE_11_LIVE_READ_FLOW = COMPLETE`
（`OPEN_SOURCE_BETA`；见文末后续修订）

基线：`302b7b8fb34a8da3e1171e6bc5dc48afe548494e`

日期：2026-08-04

## 目标与停止点

本阶段只接入匿名、只读的推荐与帖子数据边界，并保留阶段 10 Fixture 主链路。
没有实现登录、关注吧、评论、回复、发帖、签到、分页框架、数据库、复杂缓存、
图片 lease、ThreadScreen 或新的 Pager/MediaViewer。

受控运行证据只足以证明 Personalized transport、MIME、Proto decode 和一次非空
mapping 可达；最终 evidence-locked 请求返回合法空页，没有正 threadID。因此
PBPage Probe 按设计未发出。没有可复现的 server fixture 时，Production 推荐和
ThreadReader 均使用可诊断的 fail-closed Repository。阶段 11 不能标记为完整
Live reading，也不进入阶段 12。

## 基线与工作区保护

- 开始 HEAD：`302b7b8fb34a8da3e1171e6bc5dc48afe548494e`。
- Android reference：`5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`，只读且 clean。
- 开始前已存在的用户漂移：根 `.DS_Store`、`.idea/vcs.xml`、
  `TiebaLite_iOS_Codex_Prompt_Kit/.DS_Store`；这些文件不属于阶段 11。
- 没有使用 `git add -A`、`git add .` 或 `git commit -a`，也没有修改 submodule。

## Endpoint 与运行证据

| 路径 | 静态/本地证据 | Debug-only 运行观察 | Production 决策 |
|---|---|---|---|
| Personalized | Android V12 call site、阶段 07 golden、126-file union、typed mapper/mock tests | HTTPS 200、`application/octet-stream`、Proto decode 成功；一次早期请求 5550 bytes/67 mapped items；最终锁定请求 245 bytes/0 item/171 ms | `EvidenceBlockedRecommendationRepository` fail closed；typed adapter 仅用于 Mock/显式 Debug Probe |
| PBPage | Android request builder、PBPage request 6/response 119/union 125、deterministic request、synthetic response mapper/mock tests | 未运行：最终推荐页没有正 route ID | `EvidenceBlockedThreadReaderRepository` fail closed；不伪装 live-ready |

Probe 仅在 `DEBUG && !UITESTING` 编译，且只响应显式 launch flag。诊断仅显示
HTTP status、MIME、body byte count、decode boolean、mapped count、耗时和 typed
outcome；不读取 Cookie、BDUSS、STOKEN 或 Keychain，不记录 raw body、正文、URL、
threadID、用户字段或 token，也不循环重试。

## Repository 与状态保护

- View 继续只依赖 Repository/Store，不接触 HTTPClient 或 generated Proto。
- `LiveRecommendationRepository` 与 `LiveThreadReaderRepository` 通过唯一
  `EndpointPipeline` 解码并在 Core mapper 边界转换为领域模型。
- `ReadingDataSourceMode.fixture/live` 是显式 composition 选择；UITesting 与阶段
  10 launch scenarios 全部固定为 Fixture，不依赖实时服务器。
- Production 选择 `.live`，但推荐与帖子都因缺少可复现运行证据而 fail closed；
  不回退 Fixture，也不发送请求。图片 loader 仍为 disabled，未修改阶段 08
  图片状态或阶段 09 MediaViewer。
- RecommendationsStore 与 ThreadReaderStore 各自持有一个加载 Task 和递增
  request generation。新请求先取消旧请求；完成时检查 cancellation 与 generation；
  旧响应不能覆盖新状态，取消不展示为普通失败。

## PBPage 领域映射边界

- 只映射标题、吧名、公开作者、首楼、少量普通楼层与 `Post.content#5`。
- route threadID 与 wire 正 threadID 不一致时返回 typed mapping failure。
- post/floor 数值执行 checked conversion；无有效业务身份时不生成随机 UUID。
- 作者缺失安全降级；普通楼层按正 post ID 首次出现去重并保留服务器顺序。
- 图片节点可生成稳定 MediaIntent，但 Production live image loader 本阶段保持
  disabled；没有验证图片候选顺序或媒体可达性。
- 没有实现 PBPage 分页、楼中楼、删除/折叠/私密 wire taxonomy。

## 自动化回归

新增或扩展测试覆盖：

- Personalized protobuf golden 与 evidence-locked candidate request、Live
  Repository success/empty/typed HTTP failure/cancellation；
- 推荐新请求替换旧请求、迟到响应不能覆盖、取消不展示错误；
- PBPage deterministic decoded request contract、首楼/普通楼层/content/image
  intent mapping、service error、route identity mismatch、Live Repository
  pipeline/cancellation；
- ThreadReader 新请求替换旧请求、迟到响应不能覆盖、取消不展示错误；
- Fixture/Live composition 明确分离、UI scenarios 离线、Production transport 为
  URLSession 且图片 disabled、推荐/PBPage 无可复现证据时均不发送请求；
- generated source、networking、Release 与 UITesting isolation。

## 实际验证与结果

- `make instructions`、`make secret-scan`、最终 `make lint`、
  `git diff --check`：全部 exit 0；SwiftLint 为 133 files / 0 violations。
- `make build`：最终 exit 0，Debug-only Probe 与两个 typed Live Repository
  组合编译成功。
- `make test-unit`：exit 0；216 个逻辑测试、235 次 Simulator 执行，
  0 failed / 0 skipped。
- `make quality-fast`：exit 0；instructions、Android reference lock、Proto/
  JVM fixture 确定性、SwiftPM/XcodeGen、forbidden/static canaries、secret scan、
  networking isolation、lint、Debug build 与 Unit 全部通过。
- `make quality`：从头 exit 0 并输出 `Quality gate completed.`；Unit
  216/235、iPhone smoke 16/16、iPhone interaction 15/15、iPad smoke
  5/5、iPad interaction 2/2 全部 0 failed；iPad build、Release build/
  isolation 通过。
- `git submodule status` 与 Android 子模块 `git status --short`：指针仍为
  `5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`，工作树 clean。

中间失败已保留语义：初次 sandbox 内 Xcode 命令只因用户 cache 权限
失败，升级后通过；Probe 改为 Repository delegation 后，首次 lint 因六参数
超限失败，首次 Debug build 因 Optional 链与两个缺失 `return` 失败，
均最小修正并重跑通过。此前一次完整门禁在发现 Production 推荐应
fail closed 后被主动中断（exit 130），不计为绿色；修正后的最终
`make quality` 已独立从头通过。

## Known Limitations / UNKNOWN

1. 一次非空推荐观察不可稳定复现；没有 tracked live response fixture，匿名能力、
   最小 CommonRequest/header 字段、服务端 canonical/stability、稳定顺序与终止
   条件仍 unknown。Android 点击项使用 `ThreadInfo.id` 只证明 local route 字段。
2. PBPage 没有真实请求/解码/mapping 运行证据；匿名能力、MIME、错误 taxonomy、
   锚点、排序、分页、删除/折叠/私密形态均未验证。
3. 本阶段只加载推荐第一页；不实现无限分页。
4. Production live 图片仍 disabled；没有下载、缓存、下采样或候选选择系统。
5. 真实服务可用性会变化；自动化只使用 Mock/Fixture，绝不依赖 live Tieba。
6. 当前 Proto 生成仅获项目内本地、个人、非商业批准；公开分发/App Store/
   商业使用与服务条款继续阻塞。

## 阶段边界

阶段 10 Fixture 主链路、阶段 08 renderer 图片状态和阶段 09 唯一 MediaViewer
保持不变。阶段 11 在上述证据边界停止，不开始阶段 12。

## 阶段 15.5 后续修订（2026-08-09）

本审计此前的 Production fail-closed 结论是阶段 11 提交时的历史快照。阶段
15.5 修复 Simulator Keychain 签名前置条件并在保留的真实会话上重新取得 active
`ProtectedDataLease` 后，使用 Production `LiveRecommendationRepository` 的
同一 request/mapper 路径得到：HTTP 200、`application/octet-stream`、74924
bytes、Proto decode=true、mapped=12、typed outcome=success；推荐页实际显示
非空内容。

Production 现在只在 active context 下发出 Personalized 首屏请求；signed-out
在 HTTP 前 fail closed，请求返回后复验原 lease，替换 lease 的迟到响应不得
发布。Mock composition、signed-out zero-request 与 post-response lease replacement
已有确定性回归。Fixture/UITesting 仍固定使用 Fixture/FakeSession/Mock HTTP。

结合阶段 15 已取得的匿名 PBPage 首屏与一页下一页运行证据，当前
`PHASE_11_LIVE_READ_FLOW = COMPLETE`（`OPEN_SOURCE_BETA`）。该结论不扩展为
匿名 Personalized、推荐分页、登录完成后的自动刷新、完整错误 taxonomy 或
Live 图片；已在 signed-out 失败页时，用户登录后需点击现有“重试”。
