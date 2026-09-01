# TASK_STATE

- 当前阶段：19A（Production 图片加载链路，已完成，停止于 19B 前）
- 状态：`PHASE_16A_SEARCH = COMPLETE`
- `PHASE_16 = COMPLETE`
- `PHASE_16B_HISTORY_SETTINGS_PROFILE = COMPLETE`
- `PHASE_17_IPADOS_ADAPTIVE_LAYOUT = COMPLETE`
- `PHASE_17_QUALITY_GATE = PASSED_STAGE_17F_REQUIRED_GATES`
- `PHASE_18 = COMPLETE`
- `PHASE_18_ACCESSIBILITY_PERFORMANCE_RESILIENCE = COMPLETE`
- `PHASE_18_QUALITY_GATE = PASSED_FULL_QUALITY`
- `PHASE_19 = IN_PROGRESS`
- `PHASE_19A_PRODUCTION_IMAGE_PIPELINE = COMPLETE`
- `PHASE_19B_RELEASE_CANDIDATE = NOT_STARTED`
- `BROWSING_HISTORY = LOCAL_JSON_BETA_READY`
- `APP_SETTINGS = USERDEFAULTS_RUNTIME_UI_VERIFIED`
- `USER_PROFILE = ANONYMOUS_LIVE_PROTOCOL_RUNTIME_VERIFIED`
- `LIVE_FORUM_SEARCH = ANONYMOUS_FIRST_PAGE_RUNTIME_VERIFIED`
- `LIVE_THREAD_SEARCH = ANONYMOUS_SECOND_PAGE_RUNTIME_VERIFIED`
- 状态：`PHASE_15_LIVE_PAGINATION = COMPLETE`
- `PHASE_15_5_CORE_LIVE_INTEGRATION = COMPLETE`
- `PHASE_11 = COMPLETE`
- `PHASE_11_LIVE_READ_FLOW = COMPLETE`
- `LIVE_RECOMMENDATION = ACTIVE_SESSION_SECOND_PAGE_RUNTIME_VERIFIED`
- `LIVE_THREAD = ANONYMOUS_THREE_PAGE_RUNTIME_VERIFIED`
- `PHASE_12_SESSION_AND_LOGIN = COMPLETE`
- `SESSION_IMPLEMENTATION = BETA_READY`
- `SIMULATOR_KEYCHAIN_ENTITLEMENT = DETERMINISTIC_BUILD_GATE_VERIFIED`
- `KEYCHAIN_PROCESS_RESTART_RESTORE = RUNTIME_REVERIFIED`
- `AUTH_CONTEXT_RESTORE = RUNTIME_VERIFIED`
- `ACTIVE_SESSION_PROBE = RUNTIME_VERIFIED`
- `MANUAL_LOGOUT_RUNTIME = DEFERRED_BY_USER_CREDENTIAL_RETENTION`
- `LOGOUT_IMPLEMENTATION = DETERMINISTIC_TEST_VERIFIED`
- `PRODUCTION_EXPIRED_SIGNAL = NOT_RUNTIME_VERIFIED`
- `PHASE_13 = COMPLETE`
- `PHASE_13_FOLLOWED_FORUMS = COMPLETE`
- `PHASE_15_5_ACCEPTANCE_STANDARD = OPEN_SOURCE_BETA`
- `FOLLOWED_FORUMS_LOCAL_IMPLEMENTATION = BETA_READY`
- `FORUM_GUIDE_AUTHENTICATED_PROBE = HTTP_200_PROTO_18_RUNTIME_VERIFIED`
- `LIVE_FOLLOWED_FORUMS = ACTIVE_LEASE_PRODUCTION_RUNTIME_VERIFIED`
- `PHASE_15_THREAD_READING = COMPLETE`
- `THREAD_READER_CONTAINER = VIRTUALIZED_UITABLEVIEW_BETA`
- `THREAD_READER_LARGE_FIXTURE = LOCAL_5_PAGE_1000_FLOOR_BOUND_VERIFIED`
- `THREAD_READER_SWIFTUI_AB = ONE_DEBUG_OBSERVATION`
- `PHASE_14_FORUM_HOME = COMPLETE`
- `PHASE_14_FORUM_HOME_PERFORMANCE = COMPLETE`
- `FORUM_HOME_LIST = VIRTUALIZED_UITABLEVIEW_BETA`
- `FORUM_HOME_LARGE_FIXTURE = LOCAL_10_PAGE_1000_THREAD_BOUND_VERIFIED`
- `FORUM_HOME_FIXTURE = BETA_READY`
- `LIVE_FORUM_HOME = ANONYMOUS_FIRST_AND_NEXT_PAGE_RUNTIME_VERIFIED`
- `PHASE_15 = COMPLETE`
- `PHASE_14 = COMPLETE`
- `SESSION_SIGNED_IN_SEMANTICS = WEB_COMPLETION_CANDIDATE`
- `RESTORE_VALIDATION = STRUCTURAL_KEYCHAIN_ONLY`
- `RESTORE_VALIDATION` 仅描述服务器端有效性仍未验证，不否定本阶段已复验的
  Keychain envelope → active lease 本地恢复链。
- 当前分支：`main`
- 阶段 07 提交：
  `4b80ed455051b4a7f57aceb3d740d8952cdc371b`
  （`feat: complete stage 07 networking and protobuf foundation`）
- 阶段 08 提交：
  `3b803553f61839aa166aed53ff494d542f17e7ee`
  （`feat: complete stage 08 thread content domain and renderer`）
- 阶段 08 图片状态定向修复：包含本文件的
  `fix: align thread image accessibility with render state`
- 阶段 09 提交：包含本文件的
  `feat: implement production media viewer`
- 阶段 10 提交：包含本文件的
  `feat: complete stage 10 fixture reading flow`
- production live：`RECOMMENDATIONS_ACTIVE_SESSION_SECOND_PAGE_RUNTIME_VERIFIED`；
  `FOLLOWED_FORUMS_ACTIVE_LEASE_RUNTIME_VERIFIED`；
  `THREAD_ANONYMOUS_PBPAGE_THREE_PAGE_RUNTIME_VERIFIED`；
  `LIVE_IMAGES_RECOMMENDATION_FORUM_THREAD_VIEWER_RUNTIME_VERIFIED`
- 阶段 06：`PHASE_06_INTERACTION_SPIKES = SPIKE_ACCEPTED`
  （`OPEN_SOURCE_BETA` 范围；已由阶段 09 迁移为唯一生产交互基础）
- 阶段 06C-C：`DEFERRED_POST_BETA`
- 阶段 09 前置条件：`PHASE_09_PREREQUISITES_SATISFIED`
- 阶段 09：`PHASE_09_PRODUCTION_MEDIA_VIEWER_COMPLETE`
- 阶段 10：`PHASE_10_FIXTURE_VERTICAL_SLICE = COMPLETE`
- 阶段 11：`COMPLETE`（`OPEN_SOURCE_BETA`）
- 阶段 12：`COMPLETE`（`OPEN_SOURCE_BETA`）
- 阶段 13：`COMPLETE`（`OPEN_SOURCE_BETA`）
- 阶段 14/14P：`PHASE_14_FORUM_HOME = COMPLETE`；
  `PHASE_14_FORUM_HOME_PERFORMANCE = COMPLETE`
- 阶段 15：`PHASE_15_THREAD_READING = COMPLETE`；
  `PHASE_15_LIVE_PAGINATION = COMPLETE`
- 阶段 16：`COMPLETE`；`PHASE_16A_SEARCH = COMPLETE`；
  `PHASE_16B_HISTORY_SETTINGS_PROFILE = COMPLETE`
- 阶段 17：`PHASE_17_IPADOS_ADAPTIVE_LAYOUT = COMPLETE`；
  `PHASE_17_QUALITY_GATE = PASSED_STAGE_17F_REQUIRED_GATES`
- 阶段 18：`PHASE_18_ACCESSIBILITY_PERFORMANCE_RESILIENCE = COMPLETE`；
  `PHASE_18_QUALITY_GATE = PASSED_FULL_QUALITY`
- 阶段 19：`IN_PROGRESS`；
  `PHASE_19A_PRODUCTION_IMAGE_PIPELINE = COMPLETE`；
  `PHASE_19B_RELEASE_CANDIDATE = NOT_STARTED`

## 阶段 19A 完成结果与停止点

阶段 19A 从提交 `b1b50cd117ac950bf97678d641df615f4dfaf180`
开始，只接通已有推荐/FRS/帖子正文/唯一 MediaViewer 的图片路径，
没有进入阶段 19B：

- Production composition 从 fail-closed loader 切换到唯一
  `ProductionImageLoader`。独立匿名 URLSession 不读 AuthContext/Cookie，
  只消费 mapper 已证且通过 HTTPS validation 的有限候选。
- 列表候选按 `big_pic → dynamic_pic → src_pic → origin_pic`；PB type 3
  正文按 `big_cdn_src → big_src → dynamic → cdn_src → cdn_src_active →
  src → origin_src`，Viewer 优先 origin；type 20 只用 src。
- Loader 使用 24 MiB response 上限、120M source pixel 上限、96 MiB/
  256 项 decoded NSCache、32 MiB memory-only URLCache。ImageIO 按实际
  geometry × displayScale 下采样、处理 EXIF；fill 结果中心裁到 target box，
  极端长图最大解码边 8192。
- Recommendation/Forum 图片状态只属于 cell-local state，不改稳定 row ID
  或 diffable snapshot；Thread 继续使用既有六态，只有当前 request rendered
  才能发 MediaIntent；Viewer 仍复用唯一 Pager/zoom/pan 实现。
- iPhone Live 已观察推荐/FRS 真实缩略图、单图帖与八图帖正文、Viewer
  连续三张切换和 2.50× 双击缩放；连续打开关闭 5 次、前后台一次均正常。
  没有执行 logout、读取/记录凭据、保存资源 URL/响应或真实用户正文。
- 终审红测试复现并关闭 cancellation/typed-decode rendezvous 与极端长图
  fill 超 target 两项直接风险；修复后图片定向套件 54/54。
- 完整 Unit 376 个逻辑测试/400 次执行；iPhone smoke 28/28、
  interaction 15/15；iPad smoke 最终 12/12、interaction 2/2；
  Release isolation 和 `make quality-fast` 通过。
- iPad 首次 smoke 的唯一失败为既有组件画廊入口偶发
  `not hittable`；该用例独立 3/3，两次后续完整 iPad smoke 均 12/12，
  定性为 suite-state/hit-testing 波动，没有修改生产 UI。
- 最终 `make quality` 输出 `Quality gate completed.`；阶段 19A 标记
  `COMPLETE`，阶段 19 继续 `IN_PROGRESS`，19B 仍 `NOT_STARTED`。

### 阶段 19A 当前 Known Limitations

1. 头像 portrait token 没有已证安全 HTTPS 合成规则，继续使用统一占位。
2. 动态图片只保证可显示帧；不实现动画、full-resolution lease 或瓦片。
3. 未修改宿主网络设置做真实断网；确定性 offline Fixture 与 transport/
   decode/cancellation 回归已覆盖失败和重试，真实 CDN 断网分布保留发布前检查。
4. iPad Fixture 图片打开/关闭已自动化验证；无凭据 iPad 上未单独完成
   Live CDN 手工往返，不写成已验证。
5. memory-warning 清理路径未人工注入；本阶段不做跨 View in-flight
   请求合并、full-resolution lease 或精确内存曲线。
6. 所有候选 redirect 当前 fail closed；未来如需放宽必须先补运行证据。

## 阶段 18 当前结果与停止点

阶段 18 从提交 `9d4d4427c1e0f5e6854886762fcc16fd23d26a37`
开始，只收口已有只读主链路的无障碍、长列表、图片资源、
故障韧性、存储恢复与 Release 隔离，没有新增业务功能或进入阶段 19：

- ThreadReader/MediaViewer 图片现按稳定 MediaIntent 顺序读出
  “第 N 张，共 M 张”，打开提示为“打开图片查看器”。
  Viewer 装饰背景和可见页码不再与 Pager 暴露重复焦点；
  关闭/上一张/下一张仍为明确操作。
- Profile 装饰占位头像从无障碍树隐藏，用户名增加 heading；
  ForumHome 回复数读为“N 条回复”。
- `network.offline` 现在以 UITESTING-only fail-once Repository
  确定性展示首屏失败并在重试后恢复 Fixture；Mock HTTP 事件为空，
  Production 默认 Repository 选择不变。
- 新增设置未知值安全回退、MediaViewer 取消后迟到图片丢弃、
  以及真实 UITableView cell A→B 复用后旧异步结果不污染新行的回归。
- iPhone 17 Pro / iOS 26.5 Simulator 快速滚动 1000 帖 Fixture
  并跨过 page 1→2；快速滚动 1000 楼 Fixture 到约 302 楼并跨过
  200 楼分页边界，均无稳定卡死、白块、重复行或身份错乱。
  Unit 完整验证 10 页/1000 帖和 5 页/1000 楼的有界虚拟化。
- 三图 Viewer 切换、双击 2.50× 缩放、切图重置、连续开关 10 次、
  iPhone 横竖屏/前后台与 iPad Settings/Thread/Viewer/full→narrow→full
  简单检查均无明显残留、空白或重复呈现。
- 阶段 18 定向 Unit 29 个逻辑测试/30 次执行，直接 cell reuse
  1/1，定向 UI 2/2；最终全量 Unit 351 个逻辑测试/
  370 次执行，0 失败。
- 完整 `make quality` 通过：iPhone smoke 28/28、interaction 15/15；
  iPad smoke 12/12、interaction 2/2；Release isolation、`quality-fast`、
  secret scan、lint、diff check 与 Android clean 全部通过。
- 没有修改 `VirtualizedList`、Pager、Media zoom/gesture ownership、
  Session/Keychain、Live Endpoint 或分页协议；MediaViewer/Renderer 只修改
  无障碍投影。没有新增动画、手势、overlay、依赖或图片缓存。

### 阶段 18 Known Limitations

1. Simulator 无法可靠操作 VoiceOver；真机完整 VoiceOver、iOS 18.x、
   所有 iPad 型号和真实 Stage Manager 仍为发布前人工项。
2. 本阶段性能证据是 Beta 级快速滚动+确定性虚拟化测试，
   不是精确 FPS、能耗或 Time Profiler 认证。
3. Production 图片 loader 仍 fail-closed 且没有内存图片缓存；
   极端全尺寸图片压力和内存警告下的未来 cache 清理保留到相关功能存在后。
4. 真实 logout、全部服务端错误码、App Store entitlement 和公开分发许可
   仍是发布前项目，不阻塞阶段 18。

## 阶段 17 当前结果与停止点

阶段 17 从提交 `6e95bc8b17d0f9b5c788a34d6758145115b79620`
开始，只加固既有 iPhone/iPad 导航投影、虚拟列表 resize 与状态生命周期，
没有新增业务功能，也没有进入阶段 18：

- compact `TabView + NavigationStack` 与 regular 三列
  `NavigationSplitView` 继续共享一个 `AppNavigationStore`、route 集合和
  Feature Store registry；测试锁定 regular → compact → regular 后当前 Tab、
  Forum、Thread、Profile 与 Settings route 不变。
- SwiftUI 因 size-class/窗口投影替换 View 子树时，不再通过 View
  `onDisappear` 误取消 Store-owned 请求；只有 canonical route 真正移除时，
  registry 才取消并释放 Forum/Thread/Profile/Search Store。推荐、关注吧、
  ForumHome、ThreadReader 的确定性 rehost 回归均证明请求数保持 1。
- Forum/Thread/UserProfile 的历史展示 claim 归稳定 route Store 所有，避免
  resize 重新挂载时重复记录；正常新 route 仍开始新生命周期。
- `VirtualizedList` 对完全相同的稳定 ID/值不再重复 apply diffable snapshot；
  retained 值变化仍用 `reconfigureItems`，增删/重排仍走原增量 snapshot。
  dismantle 前记录当前顶部稳定业务 ID，用于 compact/regular 重建后的附近恢复；
  没有 `reloadData`，没有改变 threadID/postID identity 或分页。
- UITESTING-only 宿主以实际父容器宽度提供 full、约半宽和 320–390pt
  narrow 三个代表性 viewport；生产代码没有 `UIScreen`、设备型号或固定
  sidebar/detail 宽度分支。
- Stage 17 定向 Unit 9 个行为用例通过；全量 Unit 为 346 个逻辑测试、
  365 次执行、0 失败。iPhone 旋转/返回 1/1，iPad full → narrow → full、
  Settings split、MediaViewer 旋转关闭返回 3/3 均通过。
- 2026-08-31 在原 iPhone 17 Pro / iOS 26.5 Simulator 上覆装生产构建，
  保留并恢复原 Keychain 会话。Live 搜吧结果进入正确 ForumHome 并返回；
  Live 搜帖结果进入正确 ThreadReader，返回后关键词与结果仍保留。
  没有修改搜索代码、执行 logout 或读取/记录凭证，因此阶段 16A/16
  从运行证据 partial 提升为 complete。
- 原完整 `make quality` 的唯一失败是长帖图片按钮的
  XCUITest `Activation point invalid`。同一 iPad Simulator 上手工点击该图片、
  打开 MediaViewer、关闭并返回原帖全部正常；按钮 accessibility
  frame 非空且与 window 相交，无透明 overlay、sheet 或残留
  `fullScreenCover`。因此根因定性为 XCUITest suite-state/hit-testing
  isolation flake，不是稳定可复现的生产故障。
- 最终只修改 UI test/helper：每例终止并以固定 Fixture 重启 App、
  明确设置方向、等待根 sentinel，每次滚动后重新 query 按钮；
  只在重查后的按钮 frame 四边完整位于 container、window 和 app
  交集内、身份/尺寸稳定且无 overlay 时，才允许以该合法
  frame 中心 coordinate 作为 `isHittable` 假阴性回退。
- 最终证据：失败用例独立 5/5；与前序 regular/compact
  projection 用例组合 3/3（6 次执行）；iPad smoke 12/12；
  iPad interaction 2/2；`make release-isolation`、`make quality-fast`、
  `git diff --check` 和 Android submodule clean 检查全部通过。
  `quality-fast` 中全量 Unit 为 346 个逻辑测试、365 次执行、0 失败。
  按 17F 授权没有重复从头运行已在同一工作树通过的 iPhone
  smoke/interaction 或完整 `make quality`。本阶段现为 `COMPLETE`，
  仍未进入阶段 18。

### 阶段 17 Known Limitations

1. 未穷举全部 iPad 型号、全部精确 Split View 比例、iOS 18.x 或真机矩阵。
2. 测试宿主模拟了实际容器窄宽，但未自动拖动真实 Split View divider；真机
   Stage Manager/多窗口 resize 仍为发布前人工验证项。
3. MediaViewer 用例证明旋转、关闭与父 route/图片节点返回；
   `fullScreenCover` 按系统语义覆盖 UIWindow，不把子内容窄宽冒充真实
   Stage Manager presentation。
4. 真机 VoiceOver 保留到阶段 18；本阶段没有修改 Pager ownership、
   MediaViewer 手势或 ThreadContentRenderer 节点结构。
5. 17F 按用户授权只重跑受影响的 iPad smoke/interaction、
   Release isolation 和 `quality-fast`，没有重复从头执行已绿的
   iPhone 26 项 smoke、15 项 interaction 或完整 `make quality`。

## 阶段 16B 当前结果与停止点

阶段 16B 从提交 `95152b62bcc3f3083f954ec86d125221d845301a`
开始，只实现浏览历史、真实设置、基础用户资料与必要导航，
没有进入阶段 17：

- Production 历史为 actor 隔离的 Codable JSON，写到
  Application Support/TiebaLite，原子替换，默认上限 500。
- 成功 record/delete/clear 会推进 generation 并取消旧 load；确定性回归证明
  迟到的初始读取不能覆盖已发布的新历史。
  threadID/forumID/userID 去重，重访移到最前；只保存路由最小
  信息，不保存正文、URL、Cookie、credential 或完整响应。
- 只在 ForumHome/ThreadReader/UserProfile 成功展示后记录。记录/删除/
  清空失败可观察且保留旧数据；损坏 JSON 可先清空再重建。
  Fixture/UI Testing 使用独立内存 Repository。
- Settings 实现跟随系统/浅色/深色和小/标准/大正文，使用命名
  UserDefaults key 重启恢复。颜色方案由 AppSceneRoot 统一投影，正文
  通过 DesignSystem 令牌进入现有 Renderer；没有覆盖 Dynamic Type/
  Reduce Motion。设置也提供历史数量/系统确认清空、现有账户、
  版本/许可，运行模式只在 Debug 显示。
- 用户资料 route 仅以正 userID 作 identity，ThreadReader 作者是首个入口。
  Store 以一个 Task + generation 拒绝迟到用户，具备 loading/loaded/
  empty/failed/retry；Fixture 显示占位头像、名称、简介和统计。
- Android 证据锁定
  `POST https://tiebac.baidu.com/c/u/user/profile?cmd=303012&format=protobuf`
  的 `ProfileRequest/ProfileResponse`。iOS 匿名 multipart request 不读 Session/
  Keychain，mapper 仅白名单映射请求 identity 匹配的公开字段，
  显式排除 schema 中 BDUSS/passwd/IP 类字段。
- Profile request/response 使唯一 generated Proto 闭包由 156 增到 207
  文件；两次 clean generation 确定性一致。新 binary fixture 为合成数据，
  不是 live capture。
- `SettingsRoute` 新增 history/about/licenses 和 history content chain，
  仍使用现有 iPhone Tab/System NavigationStack 与 iPad SplitView。
  没有新根 Tab、fullScreenCover、自定义返回或动画。
- iPhone Fixture 的帖子 → 历史 → 重开/清空、深色+大正文、作者 →
  资料均有已执行的绿色 smoke。iPad 的 profile → Settings → history
  在同一 Fixture 会话中覆盖；横屏 regular-width 三列投影连续
  执行 3 次通过，不改生产导航。
- 2026-08-30 Debug-only anonymous UserProfile Probe 返回 HTTP 200、
  `application/octet-stream`、4475 bytes、Proto decode=true、
  display fields=11、typed error=none。Probe 不读 Keychain，不记录
  userID/名称/正文/完整响应。
- 最终质量证据：Unit 337/337、iPhone smoke 25/25、iPhone interaction
  15/15、iPad smoke 9/9、iPad interaction 2/2；`make quality-fast` 与
  完整 `make quality` 均通过。首轮 smoke 的屏外手势锚点和一次 601 行
  lint 失败均已在审计中保留，并以最小测试代码调整后重新全量验证。

### 阶段 16B Known Limitations

1. UserProfile 匿名 transport/decode/mapper 已在单一 iOS 26.5
   Simulator 受控验证；长期服务可用性、删除/私密用户和完整
   错误 taxonomy 仍未验证。
2. 用户头像仍是统一占位；用户帖子/关注/粉丝列表、写操作、云同步、
   搜索词历史和多账号历史分区未实现。
3. 阶段 16A 的原锁屏缺口已在阶段 17 用原登录 Simulator 补验，
   搜吧/搜帖结果导航与返回状态均通过，现为 `COMPLETE`。
4. 没有修改 `VirtualizedList`、ForumHome/ThreadReader UITableView 承载、
   Pager、MediaViewer 或 Renderer 核心节点结构。

## 阶段 16A 当前结果与停止点

阶段 16A 从提交 `3612c7b015a3c613319f739f15bf14a813f21bc4`
开始，只实现搜吧、搜帖、Fixture/Live Repository、结果导航与
证据明确的搜帖顺序分页，没有进入阶段 16B：

- 锁定 Android Hybrid 证据为匿名 HTTPS GET JSON：搜吧
  `/mo/q/search/forum?word=...`；搜帖
  `/mo/q/search/thread?word=...&pn=N&st=5&tt=1&ct=1&is_use_zonghe=1&cv=99.9.101`。
  两者都不是 Proto，`SearchSug` 联想没有实现，156-file Proto
  闭包不变；
- `SearchStore` 使用一个 Task + generation，新关键词取消旧请求，
  迟到结果不覆盖，空白关键词零请求，分页失败保留已有
  结果。forumID/threadID 首出现去重保序，没有随机 identity；
- thread 从 `pn=1` 起始，`has_more == 1` 时请求
  `pn+1`，响应必须精确匹配 `current_page`。forum 只做首屏，
  因 Android ViewModel 没有下一页调用而不猜参数；
- Debug-only 脱敏 Probe 观察到 forum HTTP 200/
  `application/json`/36555 bytes/decode=true/mapped=48；thread page 1
  为 200/59907 bytes/decode=true/mapped=20；page 2 为
  200/66555 bytes/decode=true/mapped=20/new=20，typed error 均为 none；
- 首次 in-app forum Probe 稳定暴露 `concern_num` 同时有
  JSON string/integer。依实际类型和 Android
  `ForumFuzzyMatchAdapter.getNonNullString` 仅放宽统计字段解码，
  并加入合成 mixed-type 回归；
- `RouteIdentity.search` 位于 recommendations root 的现有系统导航中。
  iPhone 搜吧→ForumHome→返回和搜帖→ThreadReader→返回
  Fixture 2/2 通过，iPad SearchView 与两类结果 1/1 通过；
  返回后关键词和结果保留；
- 真实 forum 搜索结果已进入现有 ForumHome。真实 thread
  首页与第二页已证明解码、映射与新增 ID；阶段 17 又在生产 App 中点击
  Live thread 结果进入现有 ThreadReader 并返回，关键词和结果保持。
  自动化的结果导航仍使用 Fixture/Mock，不访问 Live 网络。
- 阶段 16A 定向 Unit 9/9、全量 Unit 311/311、iPhone UI 2/2、
  iPad UI 1/1 通过；`make instructions`、`make secret-scan`、修正后
  `make lint`、`make quality-fast` 和 `git diff --check` 均通过。
  本轮没有新增根级 Tab/Sidebar 或修改 AppSceneRoot，按任务约束未运行
  完整 `make quality` / Pager/Media interaction。

### 阶段 16A Known Limitations

1. 搜吧下一页、搜帖 page 3+、rate limit、完整服务错误 taxonomy
   和 endpoint 长期稳定性仍为 `UNKNOWN`。
2. 阶段 16A 提交时，用户搜索、输入联想、搜索历史、吧内搜帖与阶段 16B
   均未实现；当前阶段 16B 已完成浏览历史、设置与基础资料。
3. Live 证据是单 iOS 26.5 Simulator 的开源 Beta smoke，
   不是真机、多地区或发布级稳定性矩阵。
4. Production 图片 loader 仍 disabled。本阶段没有修改
   `VirtualizedList`、ForumHome/ThreadReader 列表、Pager、MediaViewer、
   Renderer、Session/Keychain 或已验证的推荐/FRS/PBPage 协议。

## 阶段 15.6 当前结果与停止点

阶段 15.6 从提交 `9a8cec68096a722772419bc9926bd2146dfdb31a`
开始，只补齐 ThreadReader 与推荐的普通顺序 Live 分页，没有进入阶段 16：

- 锁定 Android PBPage 以首屏 `pn=0/pid=0`、后续
  `pn=current_page+1` 连续请求，每页以 wire `Page.has_more=0`
  作为 Android 已证 client stop signal / iOS wire terminal 合同，
  不设本地固定最大页。真实三页均为 1，服务端末页仍为
  `RUNTIME_UNKNOWN`。后续页必须精确响应
  requested `current_page`；
- 从 `ThreadInfo.pids` 排除全部累计 postID 与当前页 postID，
  取最后一个未见正值；无候选时依已证 Android fallback 发送
  `pid=0`。跨页按 postID first-wins 去重保序；`has_more=1`
  却无新稳定 postID 时保留旧楼层并进入可重试 no-progress failure；
- 公开长帖匿名 Live Probe 连续取得三页：HTTP 全部 200、
  MIME 全部 `application/octet-stream`、body 24893/16779/13805 bytes、
  Proto decode 全部成功、`current_page=1/2/3`、映射 17/15/15 楼、
  累计 45 个唯一 postID；第三页仍 `has_more=1`，证明本地两页
  硬帽已移除；
- Personalized 继续使用 active lease：首屏
  `load_type=1,pn=1`，后续 `load_type=2,pn=N`，
  `page_thread_count=11`。Store 以单 Task/generation/page 保护分页，tail-4
  Store-owned 预取，按 `ThreadInfo.id` first-wins 增量追加；下一页
  失败/取消保留旧内容，刷新拒绝迟到分页；
- 推荐 Live 第二页为 HTTP 200、`application/octet-stream`、72958
  bytes、Proto decode=true、mapped=12，相对首屏新增 12 个稳定 ID，
  typed outcome=success。响应没有服务端 terminal 字段；空页或
  duplicate-only 页停止是受测 client no-progress policy；
- Fixture 推荐连续三页，ThreadReader 连续五页聚合 77 楼；
  原 5×200/1000 楼 UITableView 虚拟化承载未修改且继续通过回归。
  最终 `make test-unit` 为 302 个逻辑测试、321 次执行、0 failed/
  0 skipped；iPhone 推荐/帖子两条分页主链路 2/2 通过；iPad
  帖子五页 1/1 通过，推荐三页在 XCUITest split-column 手势坐标
  根因修正后 1/1 通过。`make instructions`、`make secret-scan`、
  `make lint`（185 files/0 violations）、`make quality-fast` 均 exit 0。

### 阶段 15.6 Known Limitations

1. PBPage 三页运行证据只来自一个公开长帖，且本样本三页均
   `has_more=1`；真实末页、合法空页、删除/私密、倒序、跳楼与跨主题
   稳定性仍为 `UNKNOWN`。
2. Personalized 只运行验证 active-session 第二页；匿名稳定性、
   第三页及更后 live 稳定性、服务终止语义、限流与完整错误
   taxonomy 仍为 `UNKNOWN`。
3. 自动化完全使用 Fixture/Mock/FakeSession，不读真实 Keychain、不访问
   Live 服务。真实 smoke 只是单 Simulator 开源 Beta 证据。
4. 本轮未修改 `VirtualizedList`、ForumHome、Pager、MediaViewer、
   Renderer、Session/Keychain 或生产图片 loader。

## 阶段 15.5 当前结果与停止点

阶段 15.5 从阶段 14P 提交
`9f45b63f311f608239a9cda999e14fe07e52eb96` 开始，只收口启动会话恢复、
AuthContext/ProtectedDataLease 投影，以及推荐和关注吧的生产只读接线；没有进入
阶段 16：

- 根因不是 credential 内容、Cookie 选择或 lease 时序。tracked
  `Config/Shared.xcconfig` 对 Simulator 禁用了 code signing，正常生成的 App
  缺少 simulated `application-identifier` 和嵌入 entitlements；Simulator
  `securityd` 因此以 `-34018` fail closed。移除该 override 后，新增确定性
  `simulator-keychain-entitlement` 门禁检查本地签名、application identifier
  与 Mach-O `__entitlements`；
- `SessionStore` 只有在 Keychain restore 已安装或撤销唯一 credential owner
  后才发布 `isLaunchRestoreResolved`。App shell 在此之前只显示完整背景的启动
  loading，避免推荐页先于 restore 发出 active 请求并缓存失败；
- Production factory 的同一 `SessionAuthContextProvider` 同时服务于
  Keychain-backed `SessionStore`、`AppEnvironment.session`、推荐和关注吧
  Repository。两条 Repository 均在请求前取得 matching authorization，并在
  响应后复验同一 lease；signed-out 在 HTTP 前 fail closed，替换 lease 的迟到
  响应不能发布；
- 在保留原 Keychain item、没有卸载/清理/logout/重新登录的 iPhone 17 Pro /
  iOS 26.5 Simulator 上覆装并重启签名构建，Session 自动恢复为 `signedIn`
  且 AuthContext 为 active；
- active Personalized：HTTP 200、`application/octet-stream`、74924 bytes、
  Proto decode=true、mapped=12、typed outcome=success；Production 推荐页显示
  非空内容；
- ForumGuide：HTTP 200、`application/octet-stream`、9199 bytes、Proto
  decode=true、mapped=18、typed outcome=success；Production “我关注的吧”
  显示真实列表；切到推荐再返回没有重复登录提示；
- 上述 Probe/文档只记录 status、MIME、body 大小、decode、映射数量和 typed
  outcome。没有记录或保存 credential、Cookie header、请求体、响应正文、吧名、
  帖子正文或用户内容；自动化继续使用 FakeSession、Fixture 和 Mock HTTP。
- 最终 `make test-unit` 与 `make quality-fast` 均通过；289 个逻辑 Unit、308 次
  执行、0 failed/0 skipped。entitlement 门禁、secret scan、lint（182 个 Swift
  文件）、networking isolation、Debug build 和 `git diff --check` 均通过。
  App 启动壳额外以 Fixture 跑过 iPhone smoke 19/19、iPad smoke 6/6；未重复
  运行本轮禁止修改的 Pager/Media interaction 矩阵。

### 阶段 15.5 Known Limitations

1. 按用户保留现有 credential 的要求，本轮没有执行真实 logout；logout 的 lease
   revoke、Keychain delete 和 App-owned WebKit cleanup 仍只有确定性测试证据。
2. 当前 `signedIn` 仍是本地完整 credential/active lease 语义；服务器是否实际
   消费两个字段、最小 credential 子集、轮换与真实失效码仍为 `UNKNOWN`。
3. Personalized 本轮只验证 active-session 首屏；匿名稳定性、分页，以及登录后
   对已显示失败页的自动刷新未验证。signed-out 不触网，登录后可由现有“重试”
   重新加载。
4. ForumGuide response 没有分页字段；超过 Android 注释所述 200 项的完整性、
   空列表和真实 expired taxonomy 仍为 `UNKNOWN`。
5. 自动化没有访问 Live 服务或真实 Keychain；真实 smoke 是个人开源 Beta 的
   单 Simulator 受控观察，不是多账号、真机、App Store 或发布级安全矩阵。
6. Production Live 图片仍 disabled。阶段 14P/15 虚拟列表、Pager、
   MediaViewer 与 Renderer 均未修改。

下文阶段 11、12、13 的“当前结果”保留各阶段提交时的历史快照；其中关于
Production evidence-blocked、AuthContext 恢复失败和 ForumGuide 未发请求的结论，
已由本节 2026-08-09 的阶段 15.5 证据取代。

## 阶段 14P 当前结果与停止点

阶段 14P 从阶段 15 完成提交
`c63a3c5065271bfc3ee6279ed3f79edc7aada9b4` 开始，只加固 Forum Home
长列表，没有进入阶段 16：

- 只有一个顶层 `VirtualizedList`，直接复用阶段 15 已验证且本轮
  未修改的 `UITableView + UITableViewDiffableDataSource +
  UIHostingConfiguration`。顶层 Row 为 header、retained status、section、
  每个 thread 和单一 pagination footer/empty，不存在嵌套纵向列表；
- Proto mapper 预计算摘要/媒体证据，Store 投影 `ForumThreadRowModel`。
  UI identity 统一为稳定 `threadID`，wire `itemID` 只保留为证据字段；
  RowKind 为 top/plainText/singleMedia/multiMedia/video，标题最多 2 行、
  摘要最多 5 行、媒体占位最多 3 个，没有新图片管线；
- Store 以一个 Task、递增 generation、route/page 与 tail-4 prefetch
  做下一页门禁。分页按 threadID first-wins 去重并保序，追加
  只插入新 ID；失败保留旧 rows 并重试同一 page，route 替换拒绝
  迟到下一页；
- Production 只使用已有 FRS：首屏 `pn=1/load_type=1`，后续页
  `pn=N/load_type=2`。无凭证 Probe 的第二页为 HTTP 200、
  `application/octet-stream`、156269 bytes、decode=true；首屏 13 条
  追加 30 条后聚合 43 条，typed error 为 none。
  `thread_id_list + ThreadList` 仍未启用；
- Debug-only 大吧 Fixture 固定 10 页×100 条，混合置顶/文字/单媒体/
  多媒体/视频证据，可对指定页 fail-once。确定性组件测试从
  100 增量到 1000 条，前缀保持、去重、snapshot 只增量变更，
  Cell 创建/存活数有界且发生复用；
- iPhone Debug Lab 实际到达 `items=1000 page=10 has-more=false`，中部
  thread 990424 打开并返回后原可见 rows 990422～990425 保持；iPad
  快速滚动到 200 条/第 2 页，`SWIFT_OPTIMIZATION_LEVEL=-O` 的近 Release
  Lab 快速滚动到 300 条/第 3 页，均未见稳定卡顿、持续白块或错页；
- 最终 Unit 为 284 个逻辑测试/303 次执行，iPhone smoke 19/19；iPad
  Forum 流程修复测试滚动容器后两次定向 1/1 通过。完整 iPad smoke
  一次为 5/6，仅余 MediaViewer close 视觉存在但 XCUITest not hittable
  的非稳定测试波动；`make quality-fast` 通过。共享 `VirtualizedList`
  未修改，因此按阶段约定未重复完整 `make quality`。

### 阶段 14P Known Limitations

1. Live 只对一个固定公开吧验证首屏和一页顺序下一页；
   第三页及更后页只有 Android 静态证据和合成 Fixture，没有另称
   完整 live 运行证据。
2. `thread_id_list + ThreadList`、dynamic tab、sort 变体、完整错误
   taxonomy 和限流行为仍为 `UNKNOWN`，Production 不猜请求。
3. 没有新建图片 loader/cache/downsampling；媒体列表只显示尺寸稳定
   的本地占位。
4. 性能验收是个人开源 Beta 的 Simulator/近 Release 手工观察，
   不是精确 FPS、Instruments 长期基准、真机或全系统版本矩阵。
5. 完整 iPad smoke 留有一次 MediaViewer close hit-testing 的 XCUITest
   波动；同一 Forum 流程两次定向复验以及套件内另外两个 MediaViewer
   测试均通过，当前没有稳定生产回归，本轮没有越界修改 MediaViewer。

## 阶段 15 当前结果与停止点

阶段 15 从阶段 14 提交
`bf0a0884bcda44aab1a159b756e45d41f0d3c367` 开始，完成只读帖子分页、
楼层/楼中楼呈现与 ThreadReader 长列表虚拟化，没有进入阶段 14P 或阶段 16：

- 匿名 PBPage 首屏与第二页均为 HTTP 200、Proto 解码成功；首屏含首楼和
  16 个普通楼层，第二页含 15 个普通楼层，共观察到 60 条内联楼中楼。
  Probe 只保留 HTTP/MIME/body 大小/decode/count/typed error，不记录 threadID、
  标题、用户内容、Cookie、请求体或响应正文；
- Store 使用一个 Task、递增 generation、页级 in-flight guard 和稳定 postID
  去重。Fixture 两页由 17 个顶层 post 增量追加到 32 个唯一 post，失败保留
  旧楼层并显示重试，取消和迟到响应不覆盖当前状态；
- 原 `ScrollView + LazyVStack` 的真实可变高度楼层首次滚动稳定卡住；同一
  Fixture/Store/nav 下固定 120pt 文本 Row 的一次隔离 1/1 通过。最终生产页
  只有一个 `UITableView + UITableViewDiffableDataSource +
  UIHostingConfiguration`，顶层项为 header、firstPost、post 和单一分页 footer；
- Debug-only 5×200 Fixture 依次得到 200/400/600/800/1000 个唯一楼层，
  请求序列为 `0,2,3,4,5`。component test 验证 diffable 增量 snapshot、
  1000/500/1 楼跳转、cell 数量有界、发生复用且 teardown 后 weak table 释放；
- 手工检查在无凭证 iPhone Air / iOS 26.5 Simulator 上用 Debug 和
  `SWIFT_OPTIMIZATION_LEVEL=-O` 构建各完成连续 5 次系统向下滚动，首屏可立即
  滚动，未再现数秒主线程卡死、白块、遮挡或错页。期间发现并修复了
  `didEndDisplaying` 过早清空 hosting content 造成的回弹空白 Cell，清理改在
  `prepareForReuse`，并以修复前失败、修复后通过的生命周期回归锁定。

阶段 15 定向 Unit 为 15/15。完整 Unit 为 275 个逻辑测试、294 次执行；
iPhone smoke 19/19、interaction 15/15，iPad smoke 6/6、interaction 2/2。
`make quality-fast` 首轮仅因新增 `PBPageDomainMapper.swift` 未列入精确
GeneratedProtobuf import allowlist 而失败；收紧脚本为单文件、单 import、
禁止副作用后，`make networking-isolation` 与 `make quality-fast` 通过。
最终 `make quality` 退出 0，并输出 `Quality gate completed.`。最终结果包：

- Unit：`Artifacts/TestResults/20260806-100432-13175-unit.xcresult`
- iPhone smoke：`Artifacts/TestResults/20260806-100503-13542-ui-smoke.xcresult`
- iPhone interaction：
  `Artifacts/TestResults/20260806-101617-14657-ui-interaction.xcresult`
- iPad smoke：
  `Artifacts/TestResults/20260806-104821-16949-ui-smoke-ipad.xcresult`
- iPad interaction：
  `Artifacts/TestResults/20260806-105328-17396-ui-interaction-ipad.xcresult`

## 阶段 15 Known Limitations

1. SwiftUI A/B 和手工滚动只在 iOS 26.5 Simulator 各作一次确定性观察，
   不是 iOS 18、真机或统计性能基准。
2. 未做 50 页、长期 Instruments、内存警告或单个极端超长富媒体楼层矩阵。
3. 1000 楼 Fixture 图片为固定小图，不覆盖 full-resolution Live 图片压力；
   Production Live 图片 loader 仍 disabled。
4. 领域层仍持有 1000 个 Sendable 值对象；已验证的是 Cell/host 生命周期有界，
   不是数据库或领域对象流式驱逐。
5. 完整楼中楼页面与 PB Floor 分页未实现；阶段 15 只显示 PBPage 已返回的少量
   内联预览和“查看全部 N 条回复”提示。
6. 该阶段当时未修改 ForumHome；后续阶段 14P 已完成 1000 条主题、
   虚拟化与顺序 FRS 增量分页。`thread_id_list + ThreadList` 仍因
   Proto/运行证据不足而未启用。

## 阶段 15 变更边界

- 新增动画、业务手势、overlay、第三方依赖：无。
- Pager、MediaViewer、MediaZoomImageView、ThreadContentRenderer 核心：无修改。
- ForumHomeView、ForumHomeStore、FRS 分页：无修改。
- 自动化：Fixture/Mock-only；长帖 Lab 与 Live PBPage Probe 均为 Debug-only，
  Release isolation 通过。
- 用户登录凭证：未读取、未清除、未写入日志或 Git；完整门禁使用独立无凭证
  Simulator，结束后已恢复原 `project.env` UDID。
- Android submodule：只读且 clean，锁定
  `5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`。
- 阶段 16：`NOT_STARTED`，本轮停止。

## 阶段 14 历史结果（阶段 14P 前）

本节保留阶段 14 首屏验收快照；其 itemID identity、无分页与
长列表限制已由上文阶段 14P 结果取代。

阶段 14 从阶段 13 提交
`b6090a19c95fb720f24415975dc43e7729cae1df` 开始，完成吧首页和吧内帖子
首屏，没有进入分页或阶段 15：

- 新建 `ForumHomeRepository` 领域边界、Fixture/Live 实现、
  `ForumHomeStore` 与 `ForumHomeView`。页面显示吧名、简介、已证统计、
  置顶/普通主题，并处理 initial loading、loaded、empty、failure、
  retry 和 retained refresh；
- `ForumRoute` 保留可选正 `forumID` 和已校验 `forumName`，deep link
  仅有名称时不猜 ID。列表用 `ThreadInfo.id` 作 item identity，使用
  `threadId` 打开现有 ThreadReader；
- Store 只持一个 Task 和递增 generation。新 forum 取消旧请求，迟到
  结果不得覆盖新 route，取消不显示普通错误，同 route View 更新不
  重复发请求；
- App 根 registry 在 Forum → ThreadReader → pop 期间复用同一 Store 和
  scroll anchor。iPhone Fixture smoke 实测打开中间帖子后返回，位置在
  12pt 容差内；iPad 使用同一业务状态；
- FRS 依锁定 Android reference 实现为
  `POST https://tiebac.baidu.com/c/f/frs/page?cmd=301001`，请求/响应
  为 `FrsPageRequest/FrsPageResponse`。Proto 闭包由 136 扩至 156 个文件，
  两次 clean generation 与 tracked output 一致；
- 固定公开测试吧在无凭证 iPhone/iPad Simulator 均得到 HTTP 200、
  `application/octet-stream`、Proto decode 成功和 13 条主题。最终 iPhone
  复验为 55,996 bytes、`typed-error=none`、`outcome=success`；没有
  保存 raw body 或用户内容。

阶段 14 定向 Unit 12/12；完整 Unit 260 个逻辑测试/279 次执行。
iPhone smoke 18/18、interaction 15/15、iPad smoke 5/5、interaction 2/2
全部通过。`make quality-fast` 和因共享导航接入而执行的完整
`make quality` 均通过；完整门禁输出 `Quality gate completed.`。

## 阶段 14 Known Limitations

1. 只验证匿名首屏。`thread_id_list + ThreadList`、下一页、动态 tab、
   sort 变体、限流与完整 FRS 错误 taxonomy 未验证，分页留待阶段 15。
2. Live 运行只检查一个固定公开吧，不证明所有吧、所有主题或服务端
   字段长期稳定。Production 例外仅适用匿名首屏，失效时 fail closed。
3. 未实现 live 吧头像加载；当前显示统一占位。Fixture 三个吧有独立
   帖子 identity，但简介文案共用一份合成描述。
4. Xcode 26 `simctl io` 不再提供手工 rotate 命令；横竖屏由 iPad
   XCUITest orientation/regular-compact 用例和先前的 Simulator 视觉检查覆盖。
5. Live 吧主题会形成正确 ThreadRoute 并进入现有 ThreadReader；阶段 14 验收时
   Production Live Thread 仍 evidence-blocked，后来由阶段 15 的匿名 PBPage
   两页证据收窄。真实帖子正文不属于阶段 14 本身的完成证据。
6. 阶段 11、12、13 原有状态保持不变；本阶段没有解决 AuthContext
   恢复问题，也没有使用或清除真实登录凭证。

## 阶段 14 变更边界

- 新增动画、手势、overlay、fullScreenCover、依赖：无。
- Pager、MediaViewer、MediaZoomImageView、ThreadContentRenderer、InteractionKit：
  无修改。
- 实时网络：仅 Debug-only 固定公开吧少量匿名 Probe；自动化始终
  Fixture/FakeSession/Mock HTTP。
- 敏感数据：没有 Cookie、BDUSS、STOKEN、账号、请求体、响应正文或
  用户内容进入日志、fixture、文档、测试或 Git。
- Android submodule：只读且 clean。
- 阶段 15：`NOT_STARTED`，本轮停止。

## 阶段 13 当前结果与停止点

阶段 13 从阶段 12 提交
`4f2c055a2fd01c78db6f413f30c87e568c3717ed` 开始，只实现“我关注的吧”
和稳定 `ForumRoute`，没有进入吧首页、吧内帖子列表或阶段 14：

- 锁定 Android Home 权威路径仍是不可接入的明文 HTTP form/
  ForceLogin 分页链。同 commit 的 HTTPS Proto `forumGuide` 没有 Home
  caller，因此只作为受控 Probe 候选；ForumGuide 两个 root 的 58-file
  closure 与旧集合合并为 136 个 generated Swift 文件，两次 clean
  generation 与 tracked output 一致；
- `ForumGuideProtocol` 锁定 HTTPS path/query、`sort_type=2`、
  `call_from=0`、multipart data/file 和 response mapper。Android 最终 wire
  仍包含 common/sign interceptor；iOS 当前只实验由 matching
  `ProtectedDataLease` 授权的 BDUSS/STOKEN-only unsigned subset，没有伪称
  与 Android 精确一致；
- 领域列表使用 positive Int64 `forumID` 作为稳定的本地候选身份，
  名称经已批准 `ForumRoute` 校验后进入现有系统导航。阶段 14
  目的地只显示“暂未开放”，不伪造吧首页或帖子数据；
- `FollowedForumsStore` 投影 signed-out、signing-in、expired、initial
  loading、loaded、empty、initial failure、retained refreshing/failure；单一
  Task + generation 防止替换请求的旧响应覆盖。取消不显示普通错误，
  且只有明确 typed expiry 才会撤销进程 lease 并进入 expired；
- Fixture/UITesting 使用 FakeSession、Fixture Repository 和 Mock HTTP，不读
  系统 Keychain，不访问 live。iPhone 已覆盖未登录引导、fixture 列表、
  ForumRoute、返回和 Tab 状态；iPad 已覆盖 fixture 列表和 regular/compact
  投影。

2026-08-05 在保留用户登录环境的 iPhone 17 Pro / iOS 26.5
Simulator 上，macOS 解锁后仅终止并重启 App 进程，未执行卸载、
logout、Keychain/WebKit 清理或重新登录。当前构建仍投影“会话保存失败”，
因而 ForumGuide Probe 按设计保持 disabled，没有发出请求，也没有可报告的
HTTP/MIME/body/decode/item count。这不证明凭证已被删除，只证明本次
构建无法恢复可用 AuthContext。Production 因此回退为
`EvidenceBlockedFollowedForumsRepository`，不会绕过 Probe 自动发送凭证；
本阶段如实保持 `RUNTIME_EVIDENCE_PARTIAL`。

阶段 13 定向 Unit 为 13 个逻辑测试，包含一条修复前编译失败、修复后
13/13 的 Production evidence-blocked 回归。iPhone 原始 smoke 首轮暴露
5 个稳定失败：登录按钮 accessibility identifier 被状态容器继承覆盖、
列表容器 ID 被 root 容器投影、以及设置入口被新 Debug 行挤出首屏。
最小修正后原 5 项 5/5，完整 iPhone smoke 17/17、iPad smoke 5/5
均通过。完整 quality 结果见阶段审计。

## 阶段 13 Known Limitations

1. 真实 authenticated ForumGuide 请求未发出，因此 endpoint 的服务器
   接受性、MIME、正常 body、真实数量、identity 稳定性与错误 taxonomy
   仍为 `UNKNOWN`；Production 保持 evidence-blocked。
2. 当前凭证恢复失败的根因未经证明；为遵守用户保留凭证的要求，
   本阶段没有重新登录、覆盖或清除会话。
3. Android 实际候选 wire 含 common/sign interceptor；iOS 的两字段
   unsigned subset 只有本地/Mock 证据，不应为追求成功而猜测或复制设备
   telemetry。
4. Proto candidate response 没有分页字段，Android 注释只声明最多
   200 项；无法宣称超大关注列表完整。
5. 真实过期码仍未锁定；普通错误保守地显示为可重试加载失败。
   若未来获得明确 expiry，当前“保留 Keychain、只撤销 lease”语义在
   重启后缺少 durable expired marker，可能再度投影 signed-in。
6. 吧头像使用统一占位；没有新建图片缓存、下采样或 live image loader。

## 阶段 13 变更边界

- 新增动画、手势、overlay、fullScreenCover、依赖：无。
- Pager、MediaViewer、Renderer、InteractionKit：无修改。
- 吧首页/吧内帖子：未实现；`ForumRoute` 仅进入明确未开放页。
- 真实网络：本阶段没有发出 ForumGuide 请求；Production fail closed。
- 敏感数据：没有 Cookie/凭证值、账号、请求体、原始响应或用户关注
  内容进入日志、fixture、文档、测试或 Git。
- Android submodule：只读且保持 clean。
- 阶段 14：`NOT_STARTED`，本轮停止。

## 阶段 12 当前结果与停止点

阶段 12 从阶段 11 提交
`2221793302250edcd0cdde591b0f92dfbc22db46` 开始，只实现登录与 Session
基础，不进入关注吧、评论、回复、发帖、签到、点赞或阶段 13：

- 用户在始终可见的 `WKWebView` 中自行输入账号、密码和验证码；App 不读取
  DOM、不自动填表，也不保存密码。完成页和两个候选 Cookie 字段严格来自锁定
  Android reference；不移植 Android 的明文 HTTP 私有登录接口；
- Keychain 只保存 `BDUSS` 与 `STOKEN` 两个 opaque String，使用单一
  Generic Password、versioned envelope、`WhenUnlockedThisDeviceOnly` 且不
  同步 iCloud。日志、测试、文档和 Git 均不包含字段值；
- `SessionStore` 提供 `signedOut/signingIn/signedIn/expired/failed`，并以内部
  `signingOut` 表示清理进行中。restore/login 只保留一个 Task 和递增
  generation；旧完成不能覆盖新状态；授权 lease 在 logout/expired 时先撤销；
- logout 实现按“撤销进程授权 → 删除 Keychain → 请求清理 App-owned
  nonpersistent WebKit store 并等待回调”执行；即使 Keychain 删除失败仍会尝试
  WebKit 清理，Keychain 删除失败进入可重试错误。WebKit 清理 API 不返回错误，
  因而不能声称其失败重试已被验证。Fixture/UITesting 使用 Fake store、fixture
  auth provider 与 nil login URL，不读取真实 Keychain 或账号；
- Production Recommendations/ThreadReader 继续 fail closed；阶段 12 的 Debug
  Probe 不把阶段 11 提升为 COMPLETE，也不接关注吧或 PBPage production。

2026-08-04 的真实运行观察：用户在 iPhone 17 Pro / iOS 26.5 Simulator 的
本机签名 Debug App 中完成可见网页登录，App 进入 `signedIn`；终止 App 进程并
重新启动后仍由系统 Keychain 恢复为 `signedIn`。用户显式触发的一次受控
Personalized Debug Probe 得到 HTTP 200、`application/octet-stream`、83924
bytes、Proto decode 成功、12 个映射条目、`outcome=success`。这些指标不证明
服务端实际消费了 credential，也不证明字段最小性、过期 taxonomy 或 Production
Live Repository 已验证。

用户随后明确要求保留登录凭证以便下次使用，因此没有执行真实 logout，也没有
清理 Keychain、卸载登录 App 或删除登录 Simulator。真实 logout 后再次启动为
`NOT_RUN/DEFERRED_BY_USER_CREDENTIAL_RETENTION`；确定性 logout 测试不能替代
该运行证据，所以阶段 12 如实保持 `RUNTIME_EVIDENCE_PARTIAL`。完整质量门禁在
独立、无凭证的 iPhone Air Simulator 上运行，未触碰上述登录容器。门禁后曾
再次终止并启动登录 App，但 macOS 锁屏阻止了额外可访问性标签读取；此前已完成
的进程重启恢复证据保持有效，该额外观察不写成通过。

阶段 12 定向 Unit 为 19/19；登录 URL/端口/Cookie 选择策略回归为 3/3；设置页
大字体导航回归为 1/1。最终完整 Unit 为 235 个逻辑测试/254 次执行，0 failed/0 skipped；
iPhone smoke 16/16、iPhone interaction 15/15、iPad smoke 5/5、iPad
interaction 2/2 均通过，Release isolation 通过，`make quality` exit 0 并输出
`Quality gate completed.`。首次完整质量运行曾有 1 个大字体 smoke 失败：新增
账号 section 后原图库按钮在屏外且测试未滚动；测试改为滚动到可点击元素，定向
1/1 和随后完整 iPhone smoke 16/16 均通过。

## 阶段 12 Known Limitations

1. 真实 logout、Keychain 删除、App-owned WebKit data 清理及 logout 后重启未
   运行，按用户保留凭证要求延期；实现仅由确定性 Fake/backend 测试验证。
2. 启动恢复只检查 versioned Keychain envelope 结构完整；没有已证轻量服务器
   validator，过期 credential 可能暂时投影为 `signedIn`。
3. `signedIn` 表示可见 Web 完成、候选 credential 原子写入并签发当前进程
   lease，不等于服务端确认账号有效、字段最小或阶段 11 Live 已解锁。
4. 真实服务器过期错误码、Cookie 轮换、host-only 与显式 Domain 差异、多账号、
   TBS、PBPage 和关注吧仍为 `UNKNOWN`。
5. 未做真机、App Store entitlement、发布级隐私/安全审计；ADR-0007 的 crash
   journal、cleanup ledger 与受保护缓存 aggregate 延至 post-Beta。
6. macOS 锁屏阻止了最终质量门禁后的额外 UI 标签复核；没有因此退出、卸载、
   重装或清除登录凭证。

## 阶段 12 变更边界

- 新增动画：无。
- 新增手势、Pager、MediaViewer、Renderer：无修改。
- 新增 overlay/fullScreenCover：无；仅由 App 根持有一个系统登录 sheet。
- 新增依赖：无。
- Live 网络：仅用户显式触发的一次 Debug-only、脱敏 Probe；Production live
  读取仍 fail closed，自动化测试不访问贴吧服务器。
- 敏感数据：没有密码、Cookie 值、账号、完整请求体或响应正文进入日志、fixture、
  文档、测试结果或 Git。
- Android submodule：只读且保持 clean。
- 阶段 13：`NOT_STARTED`，本轮停止。

## 阶段 11 当前结果与停止点

阶段 11 从阶段 10 提交
`302b7b8fb34a8da3e1171e6bc5dc48afe548494e` 开始，只处理匿名推荐与帖子
首屏的只读 Live 边界：

- `AppEnvironment` 以显式 `fixture/live` mode 选择 Repository；普通
  Debug/Release production 持有 ephemeral、无 Cookie/credential/cache 的
  `URLSessionHTTPClient`，但两个未达门槛的能力均 fail closed；
  UITesting/LaunchScenario 始终强制 Fixture；
- `LiveRecommendationRepository` 使用阶段 07 EndpointPipeline，把 Proto 只在
  Core mapper 边界转换为推荐领域值；页面布局、导航、Pager 与 MediaViewer
  均未重写；
- 推荐和帖子 Store 各自保存当前 Task 与递增 generation。新请求取消旧请求，
  迟到完成不能覆盖新状态，取消不显示为网络失败；
- PBPage request/response 的实际 Android closure 已锁定为 125 个文件；与
  Personalized closure 合并后的唯一 GeneratedProtobuf target 为 126 个文件。
  `PBPageProtocol`、`LiveThreadReaderRepository` 和纯 `Post.content` mapper 已由
  合成 response、MockHTTPClient 与 replacement/cancellation tests 验证；
- Production 推荐与 ThreadReader 分别由
  `EvidenceBlockedRecommendationRepository` 和
  `EvidenceBlockedThreadReaderRepository` fail closed。它们不回退到 Fixture，
  也不发尚未达到可复现证据门槛的请求；typed Live adapter 仍可由 Mock tests
  和显式 Debug Probe 调用，Fixture 模式完整保留阶段 10 主链路。

2026-08-04 的 Debug-only 匿名推荐 Probe 只记录脱敏指标：所有受控请求均为
HTTP 200、`application/octet-stream` 且 Proto 可解码；曾有一轮早期候选
`client_type` 字段组合返回 5550 bytes/67 mapped items，紧接及最终
Android 静态字段锁定版本均返回合法空页。最终版本为 245 bytes、0 item、
171 ms。没有保存 raw response、正文、threadID、URL、Cookie、token 或设备
标识。由于最终推荐页没有正 threadID，链式 PBPage Probe 按设计未运行；没有
为取得成功而猜 AppPos、设备 ID、签名或循环重试。

因此本阶段不能标记 COMPLETE：推荐 transport/HTTP/MIME/Proto decode 已有
`RUNTIME_OBSERVATION`，但稳定匿名非空推荐、当前最小字段集合和 PBPage 匿名
运行态仍是 `UNKNOWN`。Production 两项能力均按停止条件 fail closed。阶段 12
保持 `NOT_STARTED`，本轮停止，不进入登录、关注、评论、回复、发帖或签到。

阶段 11 最终 `make quality` 从头 exit 0 并输出
`Quality gate completed.`：Unit 216 个逻辑测试/235 次执行、iPhone
smoke 16/16、iPhone interaction 15/15、iPad smoke 5/5、iPad
interaction 2/2 均 0 failed；iPad build、Release build/isolation 同时通过。

## 阶段 11 Known Limitations

1. 最终 evidence-locked 匿名推荐请求当前返回合法空页；早期单次非空结果未
   固化 raw response，因此不能证明稳定匿名推荐、服务端 canonical/pagination
   行为；Android 点击推荐使用 `ThreadInfo.id` 仅作为 route 字段的静态证据。
2. PBPage 的 Android schema/request/mapper/Mock contract 已完成，但没有从最终
   推荐页取得真实 threadID，Production ThreadReader 继续诊断性 fail closed。
3. 没有 live 图片 ImageRepository、candidate 选择、下采样、cache 或 lease；
   Production 继续使用 `DisabledImageLoader`，Fixture 图片链路不受影响。
4. 没有保存 live response fixture；成功/空/畸形/未登录/过期/error taxonomy
   的可复现服务器样本仍不齐全。
5. 本阶段只实现第一页；没有无限分页、楼中楼、删除/私密/折叠常态验证。
6. 阶段 10 的替代请求 rendezvous 风险已由推荐和帖子两组确定性 Task/
   generation 回归覆盖；这不等于 live endpoint 已验证。

## 阶段 11 变更边界

- 新增动画：无。
- 新增手势/Pager/MediaViewer：无。
- 新增 overlay/fullScreenCover：无。
- 新增依赖：无。
- 实际运行的 live 验证：仅 Debug Probe 的少量匿名 HTTPS 请求；Production
  composition fail closed，自动化测试不访问 live。
- 登录、Cookie、BDUSS、STOKEN、Keychain：未读取、未发送、未实现。
- Android submodule：只读且保持 clean。

## 阶段 10 目标与范围

阶段 10 按个人开源 Beta 标准完成 Fixture 驱动的主链路：

- 12 条合成推荐数据使用稳定 threadID，覆盖文字、单图、多图、长标题、
  无图以及不同吧名、作者和回复数；
- `RecommendationsStore` 明确区分 initial loading、loaded、empty 和 failed，
  Repository 协议与 Fixture 实现可由未来 live 数据源替换；
- 唯一 `ThreadReaderView` 按稳定 threadID 加载首楼和 3 个普通楼层，复用
  阶段 08 的 `ThreadContentRenderer`、节点身份与 `ThreadMediaIntent`；
- App scene 持有稳定推荐 Store，并按 root/threadID 复用帖子 Store；pop 后释放
  已离开路由的 Store，状态刷新或 MediaViewer presentation 不重建当前内容；
- iPhone 使用现有系统 push，iPad 使用现有 split detail projection；图片仍只从
  `AppSceneRoot` 的唯一 `fullScreenCover` 进入阶段 09 MediaViewer；
- Release 与 UITesting 均通过可注入 Fixture repository/image loader 演示本地
  内容，`DisabledHTTPClient` 继续阻止 live transport。

本阶段没有新增业务 `NavigationStack`、Pager、MediaViewer、Feature 自有
`fullScreenCover`、手势、动画、overlay、第三方依赖或 live 网络；没有实现
分页、PBPage、完整楼层/楼中楼、登录、评论、缓存大系统或阶段 11。

## 阶段 10 状态与回归

- 推荐和帖子 Store 的首次加载具有稳定 generation、幂等完成和结构化取消；
  失败可显式准备重试，错误 threadID 的 Repository 结果归一为失败并释放当前
  generation，不会永久卡在 loading。
- 推荐列表的 scroll position 双向绑定记录可见锚点；点击条目不主动把选中行
  居中。帖子 Store 与 scene route registry 在 MediaViewer 打开/关闭时保持身份，
  因而帖子和推荐返回位置无需 UUID、延迟或重建 Renderer。
- 同一推荐路由由 `AppNavigationStore` 按稳定 route identity 去重；媒体顺序由
  同一 `ThreadContentDocument` 的稳定 MediaID 决定。
- 新增 7 个阶段 10 Unit test；当前完整 Unit 为 199 个逻辑测试、218 次执行，
  0 failed、0 skipped。
- iPhone 定向主链路 1/1 通过，覆盖推荐中间项、帖子第二张图、2/3→3/3→2/3、
  关闭后帖子 frame 与系统返回后推荐 frame 基本保持。
- iPad 完整 App Shell smoke 5/5 通过，覆盖阶段 10 媒体开关、旋转、
  regular/compact 投影以及既有 Renderer/MediaViewer 回归。
- Simulator 手工观察因本机登录锁屏且自动解锁失败未执行；该项没有被自动化
  结果替代或写成通过。

详细范围、失败先行证据、最终门禁和 Known Limitations 见
`Docs/Audits/PHASE10_FIXTURE_VERTICAL_SLICE.md`。

## 阶段 10 Known Limitations

1. 当前只使用合成 Fixture；没有 live 推荐、帖子或图片请求。
2. 没有分页、完整楼层、楼中楼、删除态业务页或 live PBPage 映射。
3. 没有生产图片共享 cache、candidate 选择、下采样或 full-resolution lease。
4. 没有发布级系统版本/真机/VoiceOver 矩阵；iPhone/iPad Simulator 手工检查因
   Mac 锁屏未执行，自动化覆盖不等同于人工视觉确认。
5. 合成普通楼层仅用于 presentation vertical slice，不构成 Android PBPage
   wire 字段证据；live 推荐 canonical thread identity 与普通楼层 wire 仍为
   `UNKNOWN`。
6. 当前 Fixture Repository 同步完成；未来接入真正 suspension 的 live
   Repository 前，需要补充“旧 View task 正在取消时替代 task 到达”的
   cancellation rendezvous。该序列在本阶段实际 Fixture 主链路不可稳定触发。

## 阶段 10 出口与停止点

`PHASE_10_FIXTURE_VERTICAL_SLICE = COMPLETE`。阶段 11 保持 `NOT_STARTED`，
只能由新的明确用户指令开始。

## 阶段 09 目标与范围

阶段 09 按个人开源 Beta 标准完成唯一生产 MediaViewer：

- 从阶段 08 的 `ThreadMediaIntent` 构建有序、由稳定 MediaID 派生
  `stableKey` 的进程内 presentation；
- 将阶段 06 通过的 Pager、zoom bridge、gesture ownership、
  rotation/resize 与 terminal rendezvous 整体迁移到生产
  `Sources/InteractionKit/Pager` 与 `Sources/InteractionKit/MediaViewer`；
- 在 `Sources/Features/MediaViewer` 只实现一个生产 Viewer，由
  `AppSceneRoot` 唯一 `fullScreenCover` 持有；
- 支持单图/多图、左右切换、双击/捏合缩放、放大后平移、
  chrome 切换、关闭返回、旋转/resize、深色与 Reduce Motion；
- 页面明确区分 idle/loading/rendered/failed-to-fetch/
  failed-to-decode/cancelled，失败可重试且全程使用不透明语义黑底；
- 图片数据仍只通过可注入 `ImageLoading` 获取；UITesting 使用
  固定 fixture/fake loader，Release 仍注入 `DisabledImageLoader`。

本阶段没有实现 ThreadScreen、登录、评论、live 贴吧网络、图片
cache/downsample/candidate/lease 系统或边界加载 Repository；没有下滑
关闭、第二套 Pager、第二个生产 MediaViewer 或新第三方依赖。

## 阶段 09 生产边界与验证

- `MediaViewerPresentation` 拒绝空集合、重复 stableKey 和不存在的
  initial ID；正常身份不使用 `UUID()`。动态数据移除 initial/current ID 后的
  稳定 unavailable 仍是长期合同，本阶段固定 intent 尚未实现该路径。
- `MediaZoomScrollView` 是精确 zoom/contentOffset 的唯一 owner；
  `MediaGestureOwnershipController` 按触摸 begin 固定 Pager/mediaPan/none。
- 只在翻页完成或显式前后切换时增加离场页 reset generation；
  取消/失败不偷换 current ID。
- 关闭失效活动 ownership session 并清理 Viewer 持有的离散状态；
  SwiftUI page task 在移除或 reload 时使用结构化取消。
- 新增 6 个逻辑 Unit test（7 次含参数执行）；当前完整 Unit
  为 192 个逻辑测试/211 次执行，0 failed/skipped。
- iPhone 定向证据覆盖捏合、双击、平移、5 次打开/关闭、三张
  连续切换、zoom reset 和 loading/fetch/decode 全尺寸失败态。
- iPad 定向证据覆盖三图、双击放大、放大后平移不翻页、
  竖→横→竖旋转、chrome/图片存活和关闭返回。
- Release isolation 以 source-list 证明生产 Pager/MediaViewer 均进入 Release，
  并以 binary 字符串证明 MediaViewer；同时排除 Debug lab、LaunchScenario
  和 TestSupport。Pager 没有单独 binary symbol 正向证明。

## 阶段 09 Known Limitations

1. 没有 live 图片网络、共享 cache、candidate 选择、下采样或
   full-resolution lease；Release 中当前无成功图片业务入口。
2. iOS 18.x、真机、真机 VoiceOver/Accessibility Escape 和真实
   iPad split divider 未验证。
3. iPad Simulator 对 1032×1319 全屏元素的 XCUITest pinch 合成
   在首轮不改变 zoomScale；iPhone 捏合已实测，iPad 以同一生产
   zoom wrapper 的双击、平移和旋转完成 smoke。
4. 50 次打开/关闭、100 张 full-resolution 压力、极端内存与全理论
   callback 排列按当前 Beta 标准延期；当前实测为 5 次开关。
5. Debug InteractionLab 仍保留诊断 Viewer shell，但只在 Debug/
   UITesting 编译并复用同一生产 Pager/zoom/ownership 原语；
   它不是可被 Feature 调用的第二个生产 Viewer。
6. 生产 iPhone Viewer 本阶段未单独执行横竖屏 UI smoke；生产 iPad
   竖横竖和阶段 06 底层 iPhone rotation/resize 回归已运行。
7. missing initial 当前作为结构错误拒绝 presentation；动态数据移除
   initial/current 后稳定 unavailable 的长期合同尚未实现。

## 阶段 09 出口与停止点

阶段 09 已在个人开源 Beta 范围完成。阶段 10 前置条件未在本任务评估，
阶段 10 仍是 `NOT_STARTED`，只能由新的明确用户指令开始。

## 阶段 08 历史目标与范围

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
8. 阶段 06 已按个人开源 Beta 风险范围接受；发布前矩阵仍保留为 Known
   Limitations，详见本文件末尾与
   `Docs/Audits/INTERACTION_SPIKE_REPORT.md`。

## 下一阶段前置条件

阶段 08 出口时，阶段 06 interaction foundation 已按个人开源
Beta 标准收口，阶段 09 当时为 `NOT_STARTED`。该历史状态已由本文
顶部的阶段 09 生产完成状态取代；06C-C 仍为
`DEFERRED_POST_BETA`。

阶段 06 的生产迁移、Release 隔离和唯一 Pager/MediaViewer 约束继续有效；
`SPIKE_ACCEPTED` 只接受当前 Debug interaction foundation 的架构与回归证据，
不把 Debug 源码自动晋升为生产组件。

## 阶段 06B Pager / Media Spike 收口（历史出口）

- baseline HEAD：`b205af6d0bd91d51cb7bc83b6e70f6da7fe93fbe`；Android reference
  始终 clean/exact
  `5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`。
- 已关闭：stale deferred selection ownership、iPhone 双向旋转 coordinator
  continuity、5 次 34% 宽度拖动取消、cached scroll 实际 zoom/offset reset、
  极端宽高比 resize 有限值、Reduce Motion zoom 分支、Zoom weak release、
  iPhone 5 次 open/close、iPad Media settled 旋转/切图/关闭。34% 拖动不计作
  严格半程覆盖。
- 新复现：Computer Use 在 iPhone Media zoom/pan 后旋转，业务 ID 与 zoom
  仍正确，但 chrome 按钮不可见/裁出可视区；证据截图：
  `Artifacts/TestResults/phase06b-media-rotation-chrome-clipped.png`。
- 运行环境只有 iOS 26.5（23F77）；没有 iOS 18.x runtime。真实 split-view
  divider 与 VoiceOver 未验证。
- `MediaGestureSession` 没有接到 recognizer begin，runtime fixed-owner 仍是
  阶段硬阻塞；未引入私有 recognizer API 或新的自定义手势来绕过。
- 阶段 08 图片六态与 MediaIntent 边界未修改；未创建 ThreadScreen、生产
  MediaViewer、live 网络、缓存、候选、下采样或 lease。
- 最终 `make quality` exit 0 并输出 `Quality gate completed.`；严格
  `xcresulttool` 结果为 Unit 125/125（设备参数执行 134）、iPhone smoke
  13/13、iPhone interaction 7/7、iPad smoke 3/3、iPad interaction 2/2，
  全部 0 failed/0 skipped/0 expected failure。绿色自动化不替代未完成的
  mandatory 实机验收。
- 该任务出口的状态决定：`PHASE_06_INTERACTION_SPIKES = SPIKE_PARTIAL`；
  当时 `PHASE_09_BLOCKED_UNTIL_PHASE_06_SPIKE_ACCEPTED` 保持；阶段 09 仍为
  `NOT_STARTED`，本轮未读取或执行阶段 09。该状态已由本文件末尾的 Beta
  acceptance 取代。

## 阶段 06C-A Media 手势与旋转硬阻塞收口（历史出口）

- baseline HEAD：`d33f10f3104989e0b543fd7172608bd12b6b33aa`；Android reference
  仍 clean/exact `5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`。
- 该任务出口状态：M1 runtime fixed-owner、M3 resize clamp/frame 和 V1
  iPhone zoom/pan 旋转 chrome 裁切均 `CLOSED`。阶段 06 当时仍为
  `SPIKE_PARTIAL`，阶段 09 当时仍 `NOT_STARTED` 且 `BLOCKED`。
- M1：在唯一 Debug Pager 上安装 ownership gate，于
  `gestureRecognizerShouldBegin` 一次性记录 session ID/generation/MediaID、
  began zoom/offset/velocity/translation、owner/reason。owner 在 ended/
  cancelled/failed 前不变；MediaID 或 generation 不匹配的旧 session
  不能 resolve Pager。
- V1：single tap 现在等待 double tap 和 media pan 失败，pan 不再
  误隐藏 chrome。chrome 使用独立 Media root coordinate space、同一
  layout pass 的 root/frame/safe-area 投影，与 zoom/contentOffset 无关。
- M3：zoom scroll 使用真实 aspect-fit image frame，不把 letterbox
  计入 pan range；resize 保留 normalized focal point 并对新 viewport
  完整 clamp x/y offset。同 MediaID 的新 image identity 会重建几何。
- Debug-only accessibility metrics 记录 root/chrome/session/input/viewport、window、
  safe area、layout/coordinator generation 及 invalid counter；Release 仍排除全部
  Debug labs。
- iPhone 实际执行 10 次 Pager 往返（20 转场）、10 次 zoomed
  media pan 与 10 个竖→横→竖周期；iPad 执行 5 个 zoom/pan
  旋转周期；dark + Accessibility 5 + Reduce Motion 执行 1 套完整矩阵。
  修复前证据为 `phase06ca-before-pan-hides-chrome.png` 和
  `phase06ca-before-landscape-chrome-hidden.png`；修复后 10 周期证据为
  `phase06ca-after-ten-rotation-cycles.png`。
- 最终 `make quality` exit 0 并输出 `Quality gate completed.`；
  `xcresulttool` 确认 Unit 146/146 顶层测试（155 次含参数执行）、
  iPhone smoke 13/13、iPhone interaction 9/9、iPad smoke 3/3、
  iPad interaction 2/2，全部 0 failed/0 skipped/0 expected failure。
- 新增生产动画 0、产品手势 0、overlay 0、依赖 0、live network 0。
  未使用 asyncAfter/sleep/UUID/magic zIndex/透明 blocker/全局禁动画等
  禁止假修复。
- 该任务当时未开始 06C-B；P3/P4/P5/M4/M5、真实 iPad split divider、
  iOS 18.x 和 VoiceOver 是当时的明确未验证项。详细根因、红绿结果包与
  最终证据见
  `Docs/Audits/INTERACTION_SPIKE_REPORT.md`。

## 阶段 06C-R terminal rendezvous 定向修复（历史出口）

- baseline HEAD：`367e420c979a927cb746c1e441ee1c3dc7a3a12c`；现有未提交 06C-B
  P3/P4/P5 工作完整保留，Android reference 仍要求 clean/exact
  `5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`。
- 修复前完整 Unit 为 171 个逻辑测试/182 次执行/3 个确定性失败：Media
  ownership cancellation 晚到前 Pager 提前提交，以及两个错误 delegate
  snapshot 提前消费 callback context。
- 当前使用 `@MainActor` 三方 delegate/Pager terminal/Media ownership terminal
  rendezvous。ownership `active` 只能 pending；仅相同 generation 的
  `ended(owner: pager)` 可授权。cancelled/failed/invalidated/`mediaPan`、旧
  external selection generation 或 stale host/controller 均不发布 selection。
- delegate 完整验证 transition、PageID、host identity、direction、external
  generation 与 installation generation 后才记录；无效 callback 不清 context、
  不增加 resolved count、不改变视觉页或 selection，后续正确 callback 可继续。
- 外部 selection 变化只标记 supersession，保留 source/target 至 D/P/O terminal
  齐全，再应用 live generation binding 的最新选择；recognizer replacement、
  same-ID stale host 和 same-ID ownership generation 均有直接回归；最终 join
  还会重新核对当前 ownership generation/session，防止先到的旧 terminal 证据提交。
- review 红包为 14 个逻辑测试/21 次执行/7 个失败，修复后同套件 0 失败；
  O-first 旧 generation 回归又以 7 个逻辑测试/14 次执行/1 个失败先红后全绿；
  扩大定向套件连续三次均为 31 个逻辑测试/39 次执行/0 失败，完整 Unit 为
  186 个逻辑测试/204 次执行/0 失败。新增生产动画、产品手势、生产/阻断 overlay、依赖
  和 live network 均为 0。
- 未进入 06C-C，未读取或实现阶段 09，未创建生产 Pager/MediaViewer、
  ThreadScreen、cache/candidate/downsample/lease。06C-R 任务出口当时保持
  `SPIKE_PARTIAL`；该历史状态已被下方 Open-Source Beta acceptance 取代。

## 阶段 06 Open-Source Beta 收口（2026-08-02）

### 阶段 06 任务出口状态（已由阶段 09 生产迁移取代）

- `PHASE_06_INTERACTION_SPIKES = SPIKE_ACCEPTED`
- `PHASE_06_ACCEPTANCE_SCOPE = OPEN_SOURCE_BETA`
- `PHASE_06C_C = DEFERRED_POST_BETA`
- `PHASE_09_PREREQUISITES_SATISFIED`
- `PHASE_09 = NOT_STARTED`
- `PRODUCTION_PAGER_MEDIA = NOT_CREATED`

以上是阶段 06 当时的任务出口；生产 Pager/MediaViewer 后续由本文顶部记录的
阶段 09 任务创建，不反写历史状态。

P3/P4/P5 在当前 Beta 范围内均为 `CLOSED`：P3 有 49%/51% 各 5 次、独立
velocity 分支、20 次交替 rapid-serial swipe、左右边界各 20 次和 5 次纵向
jitter；P4 覆盖 retained refresh/loading/failure、initial loading/failure/
empty、不透明全 bounds、partial drag 中 5 次 refresh 与 stale generation；
P5 覆盖缓存内 identity、refresh/resize/projection、明确 eviction 后 weak release、
100 PageID 的 cache/创建次数上界及 dismantle 释放。06C-R 的三个原始回归与
扩展 D/P/O rendezvous、non-consuming callback 回归全部保持绿色。

### 本次收口验证

- `make lint`：110 个 Swift 文件，0 violation。
- 三个原始 rendezvous 回归逐名通过；定向结果包同时运行相邻类用例，共
  16 个逻辑测试、17 次执行，0 failed/skipped/expected failure。
- `make test-unit`：186 个逻辑测试、204 次执行，全部通过。
- `make quality-fast`：instructions、reference/proto/fixture/lock/determinism、
  forbidden/static canaries、secret/network isolation、lint、Debug build、Unit 与
  diff check 全部 exit 0；其 Unit 同为 186/204。
- 本次完整 Unit 结果包为
  `Artifacts/TestResults/20260802-112421-10375-unit.xcresult`；quality-fast Unit
  为 `Artifacts/TestResults/20260802-112512-13014-unit.xcresult`。
- 同一组合工作树此前完整 `make quality` 已通过：Unit 186/204、iPhone smoke
  13/13、iPhone interaction 15/15、iPad smoke 3/3、iPad interaction 2/2，
  Release build/isolation 通过。
- Android reference 保持 clean/exact
  `5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`。

### Known Limitations（不再阻塞阶段 09）

1. 当前 runtime 证据来自 iOS 26.5 Simulator；iOS 18.x 与真机矩阵未验证。
2. 真机 VoiceOver/Accessibility Escape 未实操；真实 iPad split divider 仍属
   发布前矩阵。
3. 真实同一触摸越过半程后反向回撤的录屏未完成；确定性 transition trace 与
   runtime recognizer 共用策略已覆盖，但该手工证据延期。
4. 100 张 full-resolution lease、所有图片尺寸与极端内存/快速翻页压力未验证；
   当前 100 页证据只证明 controller/cache/昂贵内容创建上界。
5. UIKit 完全同签名且不携带 token 的迟到 delegate callback 无法由公开 API
   自证来源；当前 generation/host/visible/direction 防线已覆盖可观测身份，
   完全不可区分的理论排列留作发布前平台矩阵。
6. InteractionLab 继续 Debug/UITesting-only；生产 Pager/MediaViewer 已在
   阶段 09 迁移，ThreadScreen、live image pipeline、cache/downsample/
   candidate/lease 仍未创建。
