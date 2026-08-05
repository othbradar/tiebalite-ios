# 阶段 13：“我关注的吧”审计

- 日期：2026-08-05
- 基线：`4f2c055a2fd01c78db6f413f30c87e568c3717ed`
- Android reference：`5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`
- 状态：`PHASE_13_FOLLOWED_FORUMS = RUNTIME_EVIDENCE_PARTIAL`
- 本地实现：`FOLLOWED_FORUMS_LOCAL_IMPLEMENTATION = BETA_READY`
- Production Live：`EVIDENCE_BLOCKED`
- 后续阶段：`PHASE_14 = NOT_STARTED`

## 目标与范围

本阶段只实现关注吧的 Proto/Repository 边界、Fixture 页面、Session
投影、请求替换保护和稳定 `ForumRoute`。没有实现吧首页、吧内主题
列表或阶段 14；没有修改 Pager、MediaViewer、Renderer 或
InteractionKit。

自动化始终使用无真实凭证的 iPhone Air 和测试 iPad Simulator，
Fixture/FakeSession/Mock HTTP 不读系统 Keychain，也不访问实时服务。
保存用户登录态的 iPhone 17 Pro 没有执行 logout、uninstall、清理或
重新登录。

## Android 与 Proto 证据

锁定 Android Home 当前使用的权威链路是携带 ForceLogin 的明文 form
`POST http://c.tieba.baidu.com/c/f/forum/forumGuide`，iOS 保持
`BLOCKED_INSECURE_HTTP`。同 commit 中另有未被 Home/Repository 调用的 HTTPS
Proto 候选：

```text
POST https://tiebac.baidu.com/c/f/forum/forumGuide?cmd=309683&format=protobuf
ForumGuideRequest.data = field #1
ForumGuideRequestData.sort_type = field #2, value 2
ForumGuideRequestData.call_from = field #3, value 0
ForumGuideResponse.error = field #1
ForumGuideResponse.data = field #2
ForumGuideResponseData.like_forum = field #2
```

`like_forum` 只映射 positive Int64 `forumID`、非空名称、头像候选、等级、
热度、成员数、主题数和签到标记；重复 ID 保留首次并保持服务器
顺序。`tieba.LikeForumInfo` 与 `tieba.forumGuide.LikeForum`
wire 不兼容，没有误用。

ForumGuide 两个 root 的 closure 为 58 个文件，与旧集合合并后为 136 个
generated Swift 文件。两次 clean generation 与 tracked output 一致；新增
fixture 是不含真实用户内容的 synthetic Proto。

Android 最终 wire 还会经过 common-parameter 和排序签名 interceptor。iOS
候选只使用 matching `ProtectedDataLease` 中的 BDUSS/STOKEN 外层字段，
不复制设备 telemetry；该 unsigned subset 只有 Mock 证据，不声称与
Android 最终 wire 等价。

## 实现与状态

- `FollowedForumsRepository` 是 View/Store 的唯一数据边界；Live adapter 在
  请求前后验证同一授权 lease，Fixture adapter 返回稳定虚构 forum ID。
- Production 组合使用 `EvidenceBlockedFollowedForumsRepository`；
  `ForumGuideProtocol`/`LiveFollowedForumsRepository` 只位于 Mock HTTP 与
  Debug Probe 边界，未验证候选不会自动发送会话。
- Store 投影 `signedOut`、`signingIn`、`expired`、`initialLoading`、
  `loaded`、`empty`、`initialFailure`、`refreshing` 和
  `refreshFailure`。重试保留旧列表，取消不显示普通错误。
- Store 只保留一个 Task 和递增 generation；新请求取消旧请求，每次
  await 后核对取消与 generation，迟到结果不能覆盖新状态。
- 只有明确 typed credential expiry 才使 Session 进入 `expired`；普通
  transport/server/decode/mapping 错误不猜成会话失效。`expired` 撤销当前
  lease 但不删除 Keychain；真实 logout 仍是唯一清理路径。
- 列表使用 `forumID` 作为稳定 identity，不生成 UUID。点击只形成
  已校验的 `ForumRoute`；目的地明确告知吧首页尚未开放，不伪造阶段
  14 内容。
- 头像使用 DesignSystem 内的统一占位，没有新建 live 图片 loader、缓存或
  下采样系统。

## 真实运行观察

2026-08-05 在保留用户登录态的 iPhone 17 Pro / iOS 26.5 Simulator
上，只终止并重启了 App 进程。当前构建投影“会话保存失败”，两个
authenticated Debug Probe 均 disabled，关注吧页显示未登录引导。没有点击
登录或 logout，也没有清理 Keychain/WebKit、卸载或重装。从推荐切换到
关注吧再返回时没有重复登录导航或崩溃。

因为无可用 `AuthContext`，ForumGuide 请求没有发出。本轮没有可报告的
HTTP status、MIME、body byte count、Proto decode 或关注吧数量。这不证明
凭证被删除，只证明当前构建未能恢复可用授权上下文。阶段因此保持
`RUNTIME_EVIDENCE_PARTIAL`，不伪造 Live 成功或返回数量。

## 回归覆盖

阶段 13 定向 Unit 为 13/13：

- Fixture Repository 返回稳定列表；
- synthetic Proto 映射 forum ID、名称和可用字段；
- 授权 request 的 endpoint/query/Proto/最小候选 credential subset；
- Live Repository 通过 Mock HTTP 只返回领域值；
- 未登录不发请求，取消不显示错误，旧响应不覆盖新状态；
- 明确 expiry 进入 expired，普通错误可重试且不误判 expiry；
- UITesting 使用 FakeSession/Fixture/Mock HTTP，Production 在 Probe 前必须
  evidence-blocked；
- 脱敏 Probe metadata 与稳定 ForumRoute。

修复前先加入 Production evidence-blocked 回归，首次编译因
`EvidenceBlockedFollowedForumsRepository` 不存在而失败；实现后 13/13
通过。首轮完整 iPhone smoke 暴露 5 个可稳定复现失败：状态容器覆盖
登录按钮 accessibility ID，SwiftUI 列表 ID 投影到 root，以及新 Debug 行将
旧入口挤出首屏。只做直接修正后，原 5 项 5/5 和完整 smoke 均通过；
没有加入固定延迟、UUID、overlay 或放松断言。

最终 `make quality` 结果：

- Unit：248 个逻辑测试、267 次参数化执行，0 failed，0 skipped；
- iPhone smoke：17/17；
- iPhone interaction：15/15；
- iPad smoke：5/5；
- iPad interaction：2/2；
- Debug/iPad/Release build、Release isolation：PASS；
- 总结：exit 0，输出 `Quality gate completed.`。

## 实际执行的命令与结果

- `git status --short`、`git rev-parse HEAD`、`git submodule status`：基线正确，
  Android 锁定且 clean，用户原有漂移已记录并排除。
- `make instructions`、`make secret-scan`、`make lint`、
  `make networking-isolation`：PASS；157 个 Swift 文件 0 违规。
- `make test-unit`：PASS；248 个逻辑测试/267 次执行。
- `make quality-fast`：PASS。
- `make quality`：PASS，exit 0；完整 Unit、iPhone/iPad smoke、
  interaction 与 Release 构建全部通过。
- 最终证据：
  - `Artifacts/TestResults/20260805-134115-64735-unit.xcresult`
  - `Artifacts/TestResults/20260805-134148-65030-ui-smoke.xcresult`
  - `Artifacts/TestResults/20260805-135112-66267-ui-interaction.xcresult`
  - `Artifacts/TestResults/20260805-142339-69505-ui-smoke-ipad.xcresult`
  - `Artifacts/TestResults/20260805-142723-69964-ui-interaction-ipad.xcresult`
  - `Artifacts/TestResults/20260805-143627-70907-release-build.log`

`Artifacts/` 只是本地测试产物，不纳入提交。提交前另行执行
`git diff --check`、Android submodule clean 和精确暂存核验。

## 新增或变更的动画、手势、overlay、依赖

- 动画：无。
- 手势：无。
- overlay/fullScreenCover：无。
- 第三方依赖：无。
- Pager/MediaViewer/Renderer/InteractionKit：无修改。
- live 网络：ForumGuide 请求未发出；Production 显式 fail closed。

## Known Limitations / UNKNOWN

1. HTTPS Proto 候选的服务器接受性、MIME、正常 body、真实数量、forum ID
   运行稳定性和错误 taxonomy 未验证；Production 保持 evidence-blocked。
2. 当前构建未恢复可用 `AuthContext` 的根因未证明。为保留用户凭证，
   没有重新登录或清理现有会话。
3. iOS 的 BDUSS/STOKEN-only unsigned subset 没有服务器证据；不为追求
   成功而猜测签名、common fields 或设备 telemetry。
4. response 没有分页字段，Android 注释只声明最多 200 项，无法证明超大
   关注列表完整。
5. 真实过期码仍为 `UNKNOWN`。当未来获得明确 expiry 时，当前实现
   会撤销内存 lease 但保留 Keychain；由于没有 durable expired marker，
   再次启动可能又投影 `signedIn`。
6. 吧头像仅使用占位；没有 live 图片 loader、缓存或下采样。
7. 空白或超出 `ForumRoute` 验证的名称可以安全显示但不能导航；
   真实服务器是否返回该形态仍未验证。

## 停止点

`PHASE_13_FOLLOWED_FORUMS = RUNTIME_EVIDENCE_PARTIAL`，Production 保持
`EVIDENCE_BLOCKED`，`PHASE_11` 与 `PHASE_12` 原状态不变。
`PHASE_14 = NOT_STARTED`，本轮在提交阶段 13 成果后停止。
