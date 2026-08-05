# ADR-0016：阶段 14 匿名 FRS 首屏与 Forum Home 边界

- 状态：Accepted
- 日期：2026-08-05
- 决策者：阶段 14 “吧首页和吧内帖子列表”
- 关联阶段：07、10、11、13、14、15
- Supersedes：扩展 ADR-0011/0013/0015 的 schema 闭包和阶段 13 的 Forum
  目的地；并仅对 `forum.frsPage` 匿名首屏授予 ADR-0006 Live gate 的
  开源 Beta 例外。不改变 Session、Pager、MediaViewer、Renderer 或分发边界

## 背景

锁定 Android reference 的生产 ForumPage 通过 HTTPS Proto FRS Page 同时取得
吧摘要和首屏帖子。该 endpoint 没有 ForceLogin；Android 在无账户时也构造
请求。阶段 13 已建立 `ForumRoute` 占位，但没有吧首页或帖子列表。

FRS root `FrsPage/FrsPage.proto` 的传递闭包为 74 个文件，与既有 136-file
集合重叠 54；首屏最小扩展新增 20 个文件，总计 156。阶段 15 所需的
ThreadList root 不属于本决策。

## 决策

1. `ForumRoute` 的稳定 identity 为可选正 `forumID` 加经边界校验的
   `forumName`。关注吧携带二者；外部 deep link 只有名称时保持 ID 为 nil，
   不猜造业务 ID。
2. View 只依赖 `ForumHomeStore`/`ForumHomeRepository`。Fixture 与 Live
   Repository 返回同一 `ForumHomeSnapshot`；Proto、HTTP 和 Cookie 不进入 View。
3. Live 首屏固定使用 `POST /c/f/frs/page?cmd=301001`、Android multipart
   boundary/data/file 形态、Java form-urlencoded `kw/forum_name` 与已证的非敏感
   V12 client fields。请求显式匿名，不读 Keychain、AuthContext 或设备标识，
   不复制 Android AppPos/屏幕/安装 telemetry，也不猜签名。
4. `ThreadInfo.id` 是列表 item identity；`threadId` 是进入现有 ThreadReader 的
   route identity。两者必须分别保留。`isTop == 1` 形成置顶分组，并保持服务端
   顺序；作者关联缺失时降级，不使整页失败。
5. Store 只持一个 Task 与递增 generation；新请求取消旧请求，旧 forum 的迟到
   结果不能覆盖新 route，取消不显示普通错误。同 route 的普通 View 更新不重复
   请求。scene/root registry 在 Forum → Thread → pop 期间保留 Store 与稳定
   scroll anchor。
6. 推荐与 Forum 帖子复用无业务语义的 `ContentSummaryCard`；Feature 之间不互相
   import。Forum 不建立第二套 NavigationStack、Pager、MediaViewer 或 Renderer。
7. Debug Probe 只记录 HTTP status、MIME、body byte count、Proto decode、帖子
   数量和 typed outcome；不得保存或打印 raw response、Cookie、请求体、吧/帖子/
   用户内容或设备标识。UITesting 始终使用 Fixture/FakeSession/Mock HTTP。
8. 本阶段只承诺首屏。即使 `Page.has_more` 存在，Android 的后续策略还依赖
   `thread_id_list + ThreadList`；分页完整性、排序和遗漏语义延至阶段 15。

### ADR-0006 开源 Beta 例外

本例外只覆盖 `forum.frsPage` 的匿名首屏，不是通用 Live 门禁降级。
允许启用生产 adapter 的最小证据为：HTTPS/精确 path 与 MIME、Android
可追踪请求形状、一份无真实内容的合成成功 fixture、request/mapper/
cancel/stale 测试，以及无凭证 Simulator 的匿名运行成功。空页、服务器错误、
malformed/timeout 矩阵、完整 error taxonomy 和分页保留为后续验证；这些未验证
不能被文档表述为已通过。若精确请求不再返回可解码首屏，必须 fail closed
并回退 Fixture，不放宽 TLS/MIME 或吞掉解析错误。

## 运行决议

2026-08-05，固定公开测试吧在不含真实登录凭证的 iPhone 与测试 iPad Simulator
上均得到 HTTP 200、`application/octet-stream`、54068 bytes、Proto decode
成功和 13 个映射帖子。吧摘要和帖子列表无明显白块、遮挡或错位；iPhone 深色
模式也未观察到白色背景泄漏。没有保存服务端 body 或用户内容。

该证据允许 Production 组合使用唯一 `LiveForumHomeRepository` 的匿名首屏；
不升级阶段 11、12、13，也不证明 ThreadList/分页、所有公开吧、限流或错误码。
若未来该精确请求不可用，保留 Fixture 和 typed failure，不放宽 MIME/TLS、
不吞解析错误，也不回退到明文 endpoint。

## 许可与回滚

本决策沿用 ADR-0011 的本地、个人、非商业范围。公开分发、App Store、商业
使用、服务条款、品牌和 Proto 文件级 provenance 继续阻塞；本 ADR 不构成法律
意见。回滚时删除 FRS root/20-file 扩展、Live Forum composition 和阶段 14
Feature，恢复显式 unavailable 目的地；不得影响 Fixture ThreadReader、唯一
MediaViewer 或阶段 13 Session/关注吧实现。
