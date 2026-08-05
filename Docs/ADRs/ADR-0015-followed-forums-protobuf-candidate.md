# ADR-0015：阶段 13 关注吧 HTTPS Proto 候选与生成闭包

- 状态：Accepted
- 日期：2026-08-05
- 决策者：阶段 13 “我关注的吧”
- 关联阶段：07、11、12、13
- Supersedes：仅扩展 ADR-0011/0013 的 schema 闭包和 Core adapter
  allowlist；不改变本地、个人、非商业边界与公开分发阻塞

## 背景

锁定 Android reference 的 Home 当前使用
`POST http://c.tieba.baidu.com/c/f/forum/forumGuide`、form、ForceLogin 与分页聚合。
该路径会携带会话数据，不能越过 HTTPS-only 网络边界。相同 commit 另定义
`POST https://tiebac.baidu.com/c/f/forum/forumGuide?cmd=309683&format=protobuf`
以及 `ForumGuideRequest/ForumGuideResponse`，但没有 Repository、ViewModel 或 UI
caller，因此它只能作为 authenticated Debug Probe 候选，不能冒充 Android Home
的当前生产端点。

两个 ForumGuide root 的联合 closure 为 58 个文件，与阶段 11 的 126-file union
重叠 48 个；最小扩展是 10 个输入，总计 136 个。现有
`tieba.LikeForumInfo` 的 field #1/#2 与
`tieba.forumGuide.LikeForum` 相反，wire 不兼容，不能复用。

## 决策

1. 继续只从 pinned、clean Android submodule commit
   `5545326b2a8e0d784b2f3dfbcb219c7b121e61c2` 生成，不复制 `.proto`。
2. 历史 manifest 增加
   `ForumGuide/ForumGuideRequest.proto` 与
   `ForumGuide/ForumGuideResponse.proto` 两个 root；生成器必须证明 136-file
   union、输入 hash/import、两次 clean generation 和 tracked output完全一致。
3. 新增唯一 `ForumGuideProtocol` Core adapter。它可以构造 request、解码
   response，并只映射 positive wire forum ID 候选业务身份、名称、
   头像候选、等级和已有统计到 Core domain；generated 类型不得
   进入 App、Feature、日志或缓存。forum ID 的运行稳定性与 legacy Home
   identity 等价性在 Probe 前仍是 `UNKNOWN`。
4. Android Home 的明文 form endpoint 继续 `BLOCKED_INSECURE_HTTP`。HTTPS Proto
   endpoint 标记为 `CODE_EVIDENCE_CANDIDATE`，只有本阶段受控 authenticated
   Probe 成功后才允许 Production `LiveFollowedForumsRepository` 使用该精确候选。
5. Request data 固定为 Android builder 的 `sort_type=2`、`call_from=0`。认证只从
   当前 `ProtectedDataLease` 取得 BDUSS/STOKEN，并在发送前、返回后验证同一 lease；
   不复制 Android CUID、IMEI、OAID、安装 ID、UID header 或其他设备 telemetry。
   Android 实际 Retrofit 链还会经过 common-parameter 与排序签名 interceptor；
   iOS 的 BDUSS/STOKEN-only、unsigned outer-field subset 是隐私优先的
   `INFERENCE/RUNTIME_UNVERIFIED` 候选，不宣称与 Android 最终 wire 精确一致。
6. Probe 仅记录 HTTP、MIME、body byte count、Proto decode、映射数量和 typed
   outcome；不保存 raw response、请求体、Cookie、账号、吧名或其他用户内容。
7. `Error.error_code`、`data.is_login` 与 Android 本地常量均没有已证的远端
   expired taxonomy。普通 HTTP、server、transport、decode 和 mapping failure
   不得切换 Session expired；该映射保持 `UNKNOWN`。

## 映射与身份边界

- `forum_id > 0` 且可安全转换为 Int64 才能成为列表 identity；重复 ID 保留首次
  出现并保持服务器顺序，不生成 UUID；这是本地候选 identity
  契约，服务器运行稳定性仍待验证。
- 空名称或非法 ID 不产生列表项；非空 wire 全部无效时返回 typed mapping failure，
  不能伪装为空关注列表。
- Proto3 scalar 零值无法区分 absent 与显式零值；等级和统计只按 raw 值保守展示。
- response 没有分页字段；Android 接口注释只声明最多 200 个，因此不能宣称超过
  200 个关注吧时完整。
- App 导航继续使用已批准、校验后的 forum name route；forumID 仅用于列表身份。

## 许可、验证与回滚

本决策沿用 ADR-0011 的本地、个人、非商业批准。公开分发、App Store、商业使用、
服务条款、品牌和 Proto 文件级 provenance 继续阻塞；本 ADR 不构成法律意见。

必须通过 `make verify-protos`、generated 精确 allowlist、synthetic Proto mapper
tests、Mock HTTP/lease tests、secret scan、Release/UI isolation 和完整 quality。
若 authenticated Probe 不能解码并映射非敏感计数，Production 回滚为显式
evidence-blocked Repository，Fixture 页面保留，阶段 13 标记
`RUNTIME_EVIDENCE_PARTIAL`，不得猜字段或改用明文 endpoint。

## 2026-08-05 运行决议

本轮只重启了已保留用户登录态的 Simulator App，没有执行 logout、
uninstall、Cookie/Keychain 清理或重新登录。当前构建未能恢复可用
`AuthContext`，设置页的 authenticated Probe 与 ForumGuide Probe 均保持
禁用；因此没有发出 ForumGuide 请求，也没有 HTTP、MIME、body byte
count、Proto decode 或关注吧数量证据。

按本 ADR 的回滚条件，Production 组合使用
`EvidenceBlockedFollowedForumsRepository`，不向未验证的 HTTPS 候选端点
发送会话。`ForumGuideProtocol` 与 `LiveFollowedForumsRepository` 仅保留在
Mock HTTP/Debug Probe 边界内。阶段 13 因此收口为
`RUNTIME_EVIDENCE_PARTIAL`，阶段 14 保持 `NOT_STARTED`。
