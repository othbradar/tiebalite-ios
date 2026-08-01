# TASK_STATE

- 当前阶段：08
- 状态：`PHASE_08_THREAD_CONTENT_DOMAIN_RENDERER_COMPLETE`
- 当前分支：`main`
- 阶段 07 提交：
  `4b80ed455051b4a7f57aceb3d740d8952cdc371b`
  （`feat: complete stage 07 networking and protobuf foundation`）
- 阶段 08 提交：
  `3b803553f61839aa166aed53ff494d542f17e7ee`
  （`feat: complete stage 08 thread content domain and renderer`）
- 阶段 08 图片状态定向修复：包含本文件的
  `fix: align thread image accessibility with render state`
- production live：`DISABLED`
- 阶段 09：`NOT_STARTED`
- 阶段 09 门禁：`PHASE_09_BLOCKED_UNTIL_PHASE_06_SPIKE_ACCEPTED`

## 目标与范围

阶段 08 只完成首楼正文内容领域模型、Proto adapter 和隔离
Renderer：

- 根据锁定 Android reference 建立 P0 内容节点矩阵；
- 生成并交叉验证脱敏 `ThreadInfo.firstPostContent` binary fixture；
- 建立 Proto/SwiftUI 解耦的 `Sendable` / `Equatable` domain；
- 实现保序、稳定 ID、unknown/malformed/presence 降级 mapper；
- 实现只读 SwiftUI Renderer、注入式图片六态与 intent-only 点击；
- 建立 Debug-only Renderer Lab 和 iPhone/iPad 回归。

未建立业务 ThreadScreen、Repository、Endpoint、分页、PB Page/普通楼层
wire、Pager 或 MediaViewer；未发 live request，未读取账号/Cookie/
Keychain，未修改 Android submodule，未读取或执行阶段 09。

## 已读取的规则、规格与技能

- 已读取根目录及 App、Sources/Core、Sources/Features、Specs、Docs、
  TestSupport、Tests、UITests 目录链上适用的 `AGENTS.md`。
- 已读取 `Prompts/08_THREAD_CONTENT_DOMAIN_AND_RENDERER.md`、关联
  Specs、最新 ADR 与进入阶段时的本文件。
- 已显式使用 `.agents/skills/tiebalite-api-evidence`、
  `.agents/skills/ios-feature-slice` 和
  `.agents/skills/xcode-quality-gate`。
- 图片状态定向修复额外显式使用
  `.agents/skills/ios-root-cause-debug` 与
  `.agents/skills/xcode-quality-gate`；三个只读子代理复核状态模型、测试和
  提交边界。
- 三个子代理只读复核 Proto closure/fixture、XcodeGen/target 隔离、
  Renderer/测试/Git 风险；所有工作树写入均由主代理完成。

## Git 与用户工作保护

- baseline HEAD 为阶段 07 final commit
  `4b80ed455051b4a7f57aceb3d740d8952cdc371b`。
- 图片状态定向修复 baseline HEAD 为阶段 08 commit
  `3b803553f61839aa166aed53ff494d542f17e7ee`，祖先检查退出 0。
- Android reference 保持 clean、exact
  `5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`。
- 用户原有 `.idea/dataSources.xml`、`.idea/db-forest-config.xml` 的
  staged/unstaged 状态，以及 `.idea/noctule.xml`、`.idea/vcs.xml`、
  根目录与 prompt kit 的 `.DS_Store` 漂移均未编辑、restore 或纳入
  阶段 08 提交。
- 未 amend、rebase、merge、push、tag、submodule update 或浮动升级
  依赖。

## 证据、闭包与 fixture

- `PbContent.type#1` 是 raw `int32`；Android dispatcher 证明
  `0/9/27/35/40,1,2,3,4,5,10,20` 分支，未知 raw 保持
  unsupported 降级。
- 首楼路径是 `ThreadInfo.firstPostContent#142`，poll 为
  `ThreadInfo.poll_info#74`；`isDeleted#181` 只做保守 nonzero policy。
- 阶段 07 的 51-file closure 完整包含 `ThreadInfo` 47-file 传递闭包；
  `Post.proto` 额外 25 个输入未纳入，本阶段无 generated/schema 差异。
- fixture：
  `TestSupport/Fixtures/API/ThreadContent/thread_content_cross_language.pb`，
  1535 bytes，SHA-256
  `d37a7486974718d660a4b43466d914156c66d36f3f83982507915575e68cdf12`。
- Java `DynamicMessage` 生产器、独立 textproto、两次 JVM generation、
  tracked bytes 与独立 protoc encoding 已逐字节相等。
- fixture 仅含 synthetic 值与 `fixture.invalid`，证据等级为
  `CROSS_LANGUAGE_GENERATED`，不是 live/PB Page response。

## 已实现

### Domain 与 Proto adapter

- `ThreadContentDocument` 按 thread/post/scope/source ordinal 产生稳定 ID。
- 领域值只依赖 Foundation，全部需跨 actor 的值均为 `Sendable`，不泄漏
  generated message。
- mapper 同步、纯值、严格保序，单个坏节点不丢失后续节点。
- 图片候选只保留 HTTPS；外链只接受绝对 HTTP(S)，不允许
  credential、危险 scheme 或畸形目标。
- 图片尺寸明确区分 missing/malformed/non-positive/out-of-range/
  extreme；voice/video 不拼 endpoint、不播放。
- poll 永远只读，零总票数不除零；unknown/meme 只保留安全 presence。
- ADR-0012 将 generated import allowlist 精确扩为两个 Core adapter，
  Feature/View 仍禁止 Proto。

### Renderer 与 Debug Lab

- Renderer 只消费 domain 与注入的 `ImageLoading`，无 URLSession/
  HTTPClient/Repository 直连。
- 图片 idle/loading/rendered/failed-to-fetch/failed-to-decode/cancelled 共用
  稳定框，ratio 限制为 `0.5...3.0`；无安全候选时不调用 loader，取消不
  显示为普通失败。
- 取得 bytes 不等于已显示；只有 decode/prepare 成功且状态请求与当前请求一致
  才使用“已加载”并输出稳定 `ThreadMediaIntent`。两类失败复用“加载失败”，
  无 action/hint/MediaIntent；请求不匹配的旧状态投影为 idle，单调请求代次
  拦截旧完成与旧取消；link/video 仍只输出 `ExternalLinkIntent`，不直接
  push/open/play。
- link/image/video 可交互区至少 44pt；文本支持换行、选择、
  Dynamic Type 与超长内容。
- emoji/mention/video/voice/unknown/poll/empty/deleted/blocked 均有可访问
  只读降级。
- Debug Lab 含 mixed 23 节点、empty、deleted、blocked 四份 domain
  fixture，以及 dark/Accessibility 大字/Reduce Motion 环境摘要。
- Release 包含 production Renderer，但排除 Debug Lab、harness、launch scenario
  和 canary。

## 行为先行与回归覆盖

- `20260801-073821-10588-unit.xcresult`：先写测试，domain 未存在时
  编译按预期失败。
- `20260801-074504-16621-ui-smoke.xcresult`：先写 UI 验收，Lab 未存在
  时按预期失败。
- 中间 Renderer UI 失败包
  `075207-20493`、`075627-22528`、`075820-24151`、
  `075940-25763`、`080106-27307`、`080331-28906`、
  `080504-30510`、`080709-32157`、`080817-33663`、
  `081036-35301`；分别暴露并修复菜单可达、loading 查询、图片
  frame、accessibility value、滚动方向与超长文本上界。
- 阶段 08 新增 20 项 mapper/cross-language test 与 6 项 Renderer
  contract test；全仓 Unit 为 111 项。
- iPhone 定向 Renderer：
  `20260801-083757-54280-ui-renderer.xcresult`，1/1，96.831s。
- iPad 定向 Renderer：
  `20260801-084038-56604-ui-renderer-ipad.xcresult`，1/1，39.745s。

图片状态定向修复的行为先行证据：

- 修复前新增 invalid-bytes fixture 回归；
  `stage08-red-1.xcresult`、`stage08-red-2.xcresult`、
  `stage08-red-3.xcresult` 三次均稳定失败（exit 65），证明 loader 成功后
  phase/accessibility 仍误报 loaded/“已加载”。
- 初次修复后 `stage08-image-state-green-2.xcresult` 通过，包含 7 个逻辑用例：
  合法解码、fetch failure、decode failure、六态 accessibility value、
  成功/失败 MediaIntent 与重复确定性；既有真实取消传播用例保留。
- 只读行为复审发现请求 A 的 rendered 状态可能在请求 B task 启动前复用，且
  同请求旧取消缺少代次保护；新增请求替换回归在
  `stage08-request-binding-red-1-all.xcresult`、
  `stage08-request-binding-red-2.xcresult`、
  `stage08-request-binding-red-3.xcresult` 三次 suite 执行均稳定失败
  （exit 65）。绑定请求并加入 generation guard 后，
  `stage08-request-binding-green.xcresult` 为 8/8。
- `stage08-request-binding-red-1.xcresult` 的方法级 selector 实际筛选 0 项，虽
  xcodebuild exit 0，但明确不计为通过证据。
- 复审补充的“已取消 task + loader 普通错误”回归在
  `stage08-cancel-error-red.xcresult` 失败（exit 65）；普通 error catch 先检查
  task cancellation 后，`stage08-cancel-error-green.xcresult` 通过，取消不再
  被错误映射为 fetch failure。
- 最终聚焦图片状态套件 `stage08-image-state-final.xcresult` 为 9/9。
- iPhone Renderer：
  `20260801-100220-92089-ui-renderer.xcresult`，1/1，114.590s；同时覆盖
  dark、Accessibility Dynamic Type、Reduce Motion。
- iPad Renderer：
  `20260801-100830-96413-ui-renderer-ipad.xcresult`，1/1，56.192s；覆盖
  regular/compact、旋转与两类失败 action 缺失。

## 本轮真实执行的命令与结果

- `git status --short`、`git log -4 --oneline --decorate`、
  `git rev-parse HEAD`、`git branch --show-current`：确认 baseline、`main`、
  阶段差异与用户漂移并存。
- `git submodule status -- References/TiebaLite-Android` 与 submodule
  `status --porcelain`：exact/clean。
- `make instructions`：全部指令链小于 32768 bytes，8 个 repo skill
  validation 通过。
- `make generate`：51 个 Proto 两次生成一致，XcodeGen 与 canonical
  SwiftPM lock materialization 通过。
- `make verify-protos`：两次 clean generation 与 tracked output 一致；
  上游 `ThreadInfo.proto` 持续产生 5 个 unused-import warning。
- `make generate-thread-content-fixture`：生成 1535-byte tracked fixture。
- `make verify-thread-content-fixture`：两次 JVM、tracked 与独立 protoc
  bytes 一致。
- `make secret-scan`：无 high-confidence match；已覆盖
  `scripts/fixtures`。
- `make networking-isolation`：0 failure；production 仍是
  `DisabledHTTPClient`，Proto/Renderer/网络/Pager/MediaViewer/手势/动画/
  overlay 边界通过。
- `make lint`：78 files，0 violation。
- `make test-unit`：
  `20260801-083720-52559-unit.xcresult`，Test Succeeded。
- `make test-ui-renderer`：
  `20260801-083757-54280-ui-renderer.xcresult`，1/1。
- `make test-ui-renderer-ipad`：
  `20260801-084038-56604-ui-renderer-ipad.xcresult`，1/1。
- `make quality-fast`：退出 0；Debug build
  `20260801-084235-63908-build.log`，Unit
  `20260801-084238-64028-unit.xcresult`，所有静态/生成/隔离门禁通过。
- `make quality`：从头退出 0 并输出 `Quality gate completed.`：
  - Debug build：`20260801-084337-67125-build.log`；
  - Unit：`20260801-084339-67179-unit.xcresult`，111/111；
  - iPhone UI smoke：`20260801-084408-67708-ui-smoke.xcresult`，13/13；
  - iPhone interaction：`20260801-084900-69328-ui-interaction.xcresult`，5/5；
  - iPad build：`20260801-085402-69867-ipad-build.log`；
  - iPad UI smoke：`20260801-085404-69920-ui-smoke-ipad.xcresult`，3/3；
  - iPad interaction：
    `20260801-085604-70212-ui-interaction-ipad.xcresult`，1/1；
  - Release build：`20260801-085646-70369-release-build.log`；
  - fresh Release isolation 与 UITesting isolation 通过。
- 7 次
  `xcrun xcresulttool get test-results summary --path ... --format json`：
  final Unit/UI 与两个定向 Renderer result 均为 `Passed`，0 failed、
  0 skipped。
- `bash -n` 核对 5 个阶段相关 shell script：PASS。
- `git diff HEAD --check`：文档更新前 PASS；提交前需重跑并仅根据
  最终结果交付。

不计为产品失败、但确实执行过的诊断失败：

- fresh Release 之前直接跑 `scripts/verify_release_isolation.sh` 退出 1，
  原因是旧 Release SwiftFileList 未包含 Renderer；`make quality` 重建后同一
  verifier 已通过。
- 只读审计中 3 次未批准权限的 `xcresulttool` 因无法写
  `TestReport` 退出 64；最终从 `/private/tmp` 以批准权限重跑 7 份
  结果并全部通过。
- 辅助进程检查 `pgrep` 因环境缺少 sysmond 退出 3；不影响 Xcode
  命令或验收结果。

### 图片状态定向修复已执行命令

- `git status --short`、`git diff --stat`、`git diff --cached --stat`：确认
  仅有既存 `.idea`/`.DS_Store` 漂移；两项 `.idea` 仍保持用户预暂存状态。
- `git rev-parse HEAD`：
  `3b803553f61839aa166aed53ff494d542f17e7ee`；
  `git merge-base --is-ancestor 3b803553... HEAD`：exit 0。
- 修改前 `make quality-fast`：exit 0；Unit bundle
  `20260801-093910-79912-unit.xcresult` Test Succeeded。
- 三次修复前定向 xcodebuild：均 exit 65；修复后两次定向 xcodebuild：
  `stage08-image-state-green-1.xcresult` 与改名/拆文件后的
  `stage08-image-state-green-2.xcresult` 均 Test Succeeded。
- 首次 `make lint`：exit 2，真实发现 UI 测试函数体、测试类型名和 Renderer
  文件长度共 3 项违规；拆出单一图片展示状态文件并提取测试 helper 后，后续
  三次 `make lint` 均为 80 files、0 violation。
- 首次 `make test-ui-renderer`：exit 2（底层 xcodebuild 65），失败于测试
  只向下滚；修正 test support 后复跑 1/1。
- 首次 `make test-ui-renderer-ipad`：exit 2（底层 xcodebuild 65）；导出的
  hierarchy 证明 n11/n12 存在，截图证明 split-view 全局 swipe 未滚动详情列；
  将手势限定到 Renderer 测试根后复跑 1/1。
- 首次最终 `make quality` 在 iPhone UI smoke 运行中被主动中断，make exit 1
  （底层 `test-ui-smoke` Error 73）；原因是只读复审发现上述请求归属阻塞项，
  该次不计质量结论，修复后必须从头重跑。
- 最终 `make instructions` 与 `make secret-scan`：exit 0。
- 最终首轮 `make lint`：exit 2，取消回归令 `ThreadContentTests.swift` 达 643
  行；将该直接回归及 loader 移至本任务图片状态测试文件后复跑为 80 files、
  0 violation。
- 最终 `make test-unit`：exit 0；
  `20260801-103959-16839-unit.xcresult` 为 120 个逻辑测试、129 次执行、
  0 失败/跳过。
- 最终 `make test-ui-renderer`：exit 0；
  `20260801-104059-18459-ui-renderer.xcresult`，1/1，113.990s，覆盖 dark、
  Accessibility Dynamic Type 与 Reduce Motion。
- 最终 `make test-ui-renderer-ipad`：exit 0；
  `20260801-104330-20268-ui-renderer-ipad.xcresult`，1/1，54.994s，覆盖
  regular/compact 投影与旋转。
- 最终 `make quality-fast`：exit 0；Debug build
  `20260801-104543-22813-build.log`，Unit
  `20260801-104546-22887-unit.xcresult`，所有生成、静态、隔离和 diff 门禁通过。
- 最终 `make quality`：从头 exit 0，并输出 `Quality gate completed.`：
  - Debug build：`20260801-104657-25457-build.log`；
  - Unit：`20260801-104658-25495-unit.xcresult`，120 个逻辑测试、
    129 次执行、0 失败/跳过；
  - iPhone UI smoke：`20260801-104728-25787-ui-smoke.xcresult`，13/13；
  - iPhone interaction：
    `20260801-105241-26551-ui-interaction.xcresult`，5/5；
  - iPad build：`20260801-105743-26977-ipad-build.log`；
  - iPad UI smoke：`20260801-105746-27033-ui-smoke-ipad.xcresult`，3/3；
  - iPad interaction：
    `20260801-110002-27314-ui-interaction-ipad.xcresult`，1/1；
  - Release build：`20260801-110045-27466-release-build.log`；
  - UITesting isolation、Release isolation 与最终 `git diff --check` 均通过。
- 最终只读行为复审：A→B 请求归属、generation、取消优先级、视觉/
  accessibility 与 MediaIntent 一致性均无剩余阻塞。
- `xcrun xcresulttool get test-results summary` 与
  `xcrun xcresulttool export attachments`：读取 iPad 失败包并导出 63 个测试
  附件到临时目录，仅用于确定测试滚动归属。

## 新增或变更的动画、手势、overlay、依赖

- 新增动画：无。
- 新增业务手势：无。
- 新增 overlay：无。
- 新增业务页面：无；仅新增 Debug-only 隔离 Renderer Lab。
- 新增生产依赖：无；SwiftProtobuf 继续 exact 1.38.1 /
  `55d7a1cc5666b85c13464aea1c4b4a90feccb4c8`。
- Android submodule 修改：无。

## 未验证与剩余风险

1. 未发 live request；服务端 raw 分布、真实 malformed 形态、媒体可达性
   和分发权利仍为 `UNKNOWN`。
2. raw `9/27/35/40/20`、meme、emoji registry、`isDeleted#181`、
   quote 的完整 live 语义未知。
3. PBPage、普通楼层 Post/fold/delete、楼中楼、分页、ThreadScreen 和
   滚动位置未实现/验证。
4. 不可解码 bytes 的状态语义已修复；`ImageLoading` 当前仍只接收
   resource ID，生产 URL/version cache key、candidate 选择、下采样、大图
   解码性能和 lease 需后续设计。
5. document/poll 顶层 accessibility ID 未包含 source；同屏多个
   Renderer 时可重复。极端超长 poll 标题/选项在 Accessibility 大字下仍需
   专项裁切测试。
6. UI/Unit 使用 iOS 26.5 Simulator；iOS 18.x、真机、VoiceOver
   实操和真实 iPad 分屏未验证。
7. 公开/App Store/商业分发仍被 ADR-0011 权利边界阻塞。
8. 阶段 06 Pager/Media 仍为 `SPIKE_PARTIAL`；本修复未开始 06B 收口。

## 下一阶段前置条件

阶段 08 完成后停止，不自动开始阶段 09。除非另有明确用户指令
且阶段 06 `SPIKE_PARTIAL` 验收被正式关闭，阶段 09 保持
`PHASE_09_BLOCKED_UNTIL_PHASE_06_SPIKE_ACCEPTED`。待关闭的阶段 06 风险包括：

1. stale selection commit generation / expected-source 归属；
2. 旋转期间 coordinator continuity；
3. 运行时 fixed-owner 手势交接；
4. cached scroll/zoom 离场重置；
5. 真实 iPad 分屏、iOS 18.x 与 VoiceOver 验收；
6. resource lease 与 100 张 full-resolution 资源压力证据。
