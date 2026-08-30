# 阶段 16B：浏览历史、设置与基础用户资料审计

- 日期：2026-08-30
- 基线：`95152b62bcc3f3083f954ec86d125221d845301a`
- Android reference：`5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`
- 决策：`ADR-0021-history-settings-user-profile.md`
- 状态：`PHASE_16B_HISTORY_SETTINGS_PROFILE = COMPLETE`
- 下一阶段：`PHASE_17 = NOT_STARTED`

## 目标与边界

本阶段只实现 thread/forum/user 浏览历史、真实生效的外观和阅读
设置、基础用户资料及必要的 route/composition/Fixture/测试。
没有进入阶段 17，没有用户帖子列表、关注/私信/编辑，没有数据库、
云同步或新图片系统。

`VirtualizedList`、ThreadReader/ForumHome 的 UITableView/diffable 承载、
Pager、MediaViewer 和 Session/Keychain 底层未修改。
ThreadContentRenderer 唯一变化是从 DesignSystem 读取正文字号令牌，
核心节点结构未改。

## 浏览历史

- `BrowsingHistoryEntry` 只含 kind/identity、标题、可选辅助字段、
  `visitedAt`、`visitCount` 和 route 最小值；无正文、Cookie、credential、
  URL 或响应字节。
- Production 使用 actor + Codable JSON，写到 Application Support/TiebaLite/
  `browsing-history.json`，原子替换，默认最多 500 条。
- 按 threadID/forumID/userID 首出现 identity 去重；重访更新时间与访问
  次数并移到最前。
- 只在 ThreadReader、ForumHome 或 UserProfile 已展示有效领域数据后记录。
  写入/删除/清空失败可观察，保留已加载数据；取消不误报失败。
- 损坏或未知 schema JSON 不会被猜测解码；用户可通过“清空”原子重建
  空 envelope 后继续记录。
- Fixture/UI Testing 的 composition 每次使用独立内存 Repository，不读真实历史。

## 设置与导航

- 实现跟随系统/浅色/深色，以及小/标准/大三档阅读正文。
  UserDefaults 命名 key 用于 Production 重启恢复；Fixture 使用内存快照。
- `AppSceneRoot` 等待设置加载后注入唯一颜色方案。Renderer 文字节点
  只消费 DesignSystem 的字号令牌，仍保留 Dynamic Type。
- 设置页还显示历史条数/清空确认、现有账户操作、App 版本、
  开源许可；数据模式仅 Debug 可见。
- Settings 仍使用现有 Tab/Sidebar 和系统 stack。`SettingsRouteGrammar`
  只接受 about/licenses、history 及 history 打开的 content route。
  历史进入原 Forum/Thread/UserProfile，返回时 Store 保留。

## 用户资料协议与隐私

| 项 | 证据/实现 |
|---|---|
| Android call | `MixedTiebaApiImpl.userProfileFlow(uid)` |
| Endpoint | `POST https://tiebac.baidu.com/c/u/user/profile?cmd=303012&format=protobuf` |
| Request | `tieba.profile.ProfileRequest/ProfileRequestData`，V12 multipart protobuf |
| Response | `tieba.profile.ProfileResponse/ProfileResponseData` + `tieba.User` |
| Identity | 正 `userID`；response `User.id` 必须与 route 匹配 |
| Auth | anonymous；不从 Session/Keychain 读取或发送 Cookie |
| Domain whitelist | name/nameShow、portrait、intro、sex、concern/fans/post/thread/agree count；tiebaUid 仅在 mapper/domain 内保留，不向 UI 展示 |
| Explicitly excluded | `User.BDUSS`、`passwd`、IP 及所有未必要嵌套模块 |

请求精确使用 Android 已证的 `friend_uid`、`is_guest=1`、
`has_plist=1`、`is_from_usercenter=1`、`need_post_count=1`、
`page=1/pn=1/q_type=0/rn=20` 及已锁定 CommonRequest 子集。
Android 传屏幕尺寸/密度；iOS 不猜测伪造值，保持 proto 零值。
自己资料所需 `uid/is_guest=0` 路径不在本阶段。

Profile request/response 两个 root 使联合 generated closure 由 156 增到 207。
生成仍直接读取 pinned Android `.proto`；两次 clean generation 与 tracked
输出一致。合成 Profile binary fixture 只含构造的公开字段，受 manifest hash
约束，不是 live capture。

## 状态与回归

- History：idle/loading/loaded（空数组即空态）/failed，外加可观察的
  record/delete/clear 持久化问题。成功 mutation 会使旧 load generation
  失效，迟到的初始读取不能覆盖新记录。
- Settings：default snapshot → load；修改立即更新 UI，串行 save loop 最终
  持久化最新 snapshot。
- UserProfile：idle/loading/loaded/empty/failed；route 替换取消旧 Task 且
  generation 拒绝迟到结果。
- Unit 回归覆盖历史去重/驱逐/删除/清空/JSON 恢复、损坏文件恢复与
  初始读取迟到保护，设置持久化/字号令牌/新值胜出，Profile request/mapper/
  identity/empty/cancel/stale，Fixture 隔离与 route grammar。
- iPhone Fixture 覆盖帖子 → 历史 → 再打开/清空，深色+大正文实际生效，
  帖子作者 → 资料。iPad Fixture 覆盖同一会话中帖子/资料历史和
  Settings split 路由。

## 运行证据与 Known Limitations

1. 2026-08-30 UserProfile anonymous Debug Probe 实际返回 HTTP 200、
   `application/octet-stream`、4475 bytes、Proto decode=true、
   display fields=11、typed error=none。长期服务可用性仍不由单次
   Beta smoke 保证。
2. 头像暂使用统一占位；未实现用户帖子/关注/粉丝列表、写操作、
   云历史或搜索词历史。
3. 阶段 16A 真实结果最终点击因 macOS 锁屏未完成，保持
   `RUNTIME_EVIDENCE_PARTIAL`，不阻塞 16B。
4. 自动化不读真实 Keychain、不访问 Live 网络。Live Profile 证据只是
   单 Simulator 的开源 Beta smoke，不是真机/多系统/发布级矩阵。

## 验证命令

- 定向 Stage 16B Unit：25/25 通过。
- History 初始读取迟到回归在修复前为 4/5（新增用例按预期失败），
  修复后为 5/5。
- `make test-unit`：337/337 通过；结果包
  `Artifacts/TestResults/20260830-204415-70962-unit.xcresult`。
- `make test-ui-smoke`：25/25 通过；结果包
  `Artifacts/TestResults/20260830-204447-71264-ui-smoke.xcresult`。
- `make test-ui-interaction`：15/15 通过；结果包
  `Artifacts/TestResults/20260830-210040-73263-ui-interaction.xcresult`。
- `make test-ui-smoke-ipad`：9/9 通过；结果包
  `Artifacts/TestResults/20260830-213323-76749-ui-smoke-ipad.xcresult`。
- `make test-ui-interaction-ipad`：2/2 通过；结果包
  `Artifacts/TestResults/20260830-214026-77580-ui-interaction-ipad.xcresult`。
- 首轮 iPhone smoke 为 24/25：原 recommendations paging smoke 以
  屏外第三行作为手势锚点，确定性单测复跑仍失败。只将 UI 测试锚点改为
  可见且稳定的首行后，定向复跑及完整 smoke 均通过；未改推荐生产列表或分页。
- 一次 `make quality-fast` 因 `UITestHarness.swift` 达到 601 行触发 lint
  失败；移除一个无语义空行后，`make lint` 为 218 files / 0 violations，
  `make quality-fast` 通过。
- 最终 `make quality` 通过：instructions、Android reference clean、Proto/
  fixture/XcodeGen 确定性、source policy、secret scan、networking isolation、
  lint、build、Keychain entitlement、337 Unit、iPhone/iPad smoke 与 interaction、
  iPad build、Release isolation 及 `git diff --check` 全部通过。
- Debug-only Profile Probe 的实际脱敏结果为 HTTP 200、
  `application/octet-stream`、4475 bytes、Proto decode=true、
  display fields=11、typed error=none；未输出 userID、名称、正文、Cookie
  或凭证。
