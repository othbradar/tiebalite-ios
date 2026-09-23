# R03 首页、最近浏览与关注吧

状态：USER_VISUALLY_APPROVED（2026-09-23）。用户明确反馈“我看了可以了提交R03进入R04”，授权提交本阶段并开始 R04。此前工具未取得的中部截图仍记为未采集，不将用户验收改写成自动化证据。

## 证据、计划和边界

- 已读取根及 App/Core/Features/Tests/UITests/Docs/Specs 指令、PROJECT_RULES、ANDROID_UI_REFERENCE、矩阵、R03 提示词、ADR-0021/0022，显式使用 tiebalite-android-visual-parity 与 ios-feature-slice。
- 已查看 Android-target/01-home-recent-followed.png。锁定 c5f1125 的 HomePage.kt / ForumItemContent 为 40dp 吧图、15sp 标题、10sp 热度、11sp Lv、16dp 水平/12dp 垂直 padding；搜索框 6dp 圆角；最近吧 24dp 吧图/12sp 名称/横向 chips。读取 HomeViewModel、HistoryUtil、ForumHistoryExtra/HistoryForumItem、Toolbar.AccountNavIcon、StringUtil.getShortNumString。
- 目标：平面搜索“发现更多”、经过贴吧可展开 chips、关注列表紧凑平面行，真实吧图/热度/等级；成功展示后记录最近访问。
- 非目标：签到、取消关注、没有真实数据的置顶分组；不做 R04、不改 VirtualizedList、Pager、MediaViewer、图片缓存、Session 或根导航容器；只准入首页复用的 search route。
- 修改范围：Followed View/稳定行投影/首页组件、History 可选公开吧图与最近投影、App 依赖注入与首页 search route 准入。ForumHome 最终没有生产差异，沿用原 registry 的路由生命期与成功显示防重。无新动画/手势/overlay/依赖。

## 数据边界

ForumGuideProtocol 已映射 avatar/hotNum/levelId/levelName，本轮不新增 API 请求或猜测字段。吧图由 API 完整 HTTPS 地址进入现有 R01 组件，加载沿用 ProductionImageLoader 的无 Cookie CDN 路径；无有效图则中性占位，缺等级不造值。热度严格使用 hotCount，不拿 memberCount 代替。

最近浏览使用既有 500 条持久化历史中的 forum 投影，最多显示 20 条；可选公开吧图兼容旧 schema-1。成功回调及路由沿用原链路，无点击即写记录。详见 ADR-0023。

CURRENT_ACCOUNT_AVATAR = UNKNOWN：现有 Session 没有当前账号身份/头像来源，保留中性占位。置顶和长按写操作没有现有受支持数据/接口，不展示虚构内容。

## 已执行验证

日志目录：Artifacts/VisualReview/R03/。

| 命令/产物 | 结果 |
|---|---|
| R02 提交前 approval-baseline-unit.xcresult | 36/36 通过，含本阶段已有 Followed/History 基线 |
| history-red.xcresult | exit 65，新增测试确认旧成功访问记录缺少公开吧图字段 |
| home-unit.xcresult | exit 0，32/32，包含 7 项 R03 新回归与既有 Followed/History |
| implementation-lint.log | exit 2，新可选属性显式 nil 初始化不符合 lint；去掉冗余初始化后修正 |
| final-lint.log / r03-lint.log | exit 0 |
| home-iphone.xcresult | exit 65，首页 search 被旧 followed root grammar 拒绝；已加入现有搜索链的准入，没有修改导航容器 |
| home-iphone-search.xcresult | exit 0，1/1，44.749s；搜索/三个成功访问/重访排序/折叠展开/返回位置 |
| home-ipad.xcresult | exit 0，1/1，21.640s；深色/大字/Reduce Motion，三个成功访问，横竖屏和搜索 |
| home-projection-red.xcresult | exit 65，新增 onDisappear 清除显示标记导致既有投影替换回归失败；删除这处多余生产改动 |
| home-final-unit.xcresult | exit 65，41/42；新测试误以为再次 push 已有 search 应被拒绝，实际既有协议是回退到该 route。修正为直接验证 grammar 拒绝重复链，并验证 push 回退后路径 |
| home-verified-unit.xcresult | exit 0，42/42，7 suites；含 8 项 R03、新首页 route、既有 Followed/History、投影替换不重复请求/记录 |
| home-final-iphone.xcresult | exit 0，1/1，44.780s；撤掉生命周期改动后的当时的候选代码 |
| home-final-ipad.xcresult | exit 0，1/1，21.459s；当时的候选代码的深色/宽度/搜索检查 |
| r03-final-lint.log | exit 0 |
| protected-final.json | 37 个受保护文件 SHA-256 一致，ForumHome 无生产差异 |
| r03-build.log / r03-avatar-diagnostic-build.log | exit 0；后者临时聚合字段诊断仅输出计数，源码已移除 |
| home-title-iphone.xcresult | exit 0，1/1；Live 截图确认工具栏压缩标题后，增加内容宽度约束和标题可命中断言，再跑完整本阶段流程 |
| home-title-ipad.xcresult | exit 0，1/1，22.820s；标题调整后的深色/宽度检查 |
| r03-delivery-lint.log | exit 0 |

Live 字段诊断：18 条关注吧中 avatar 为 HTTP 18、可加载 HTTPS 0、缺失 0；仅存计数，不存地址、原始响应或凭证。Android 的既有规则保留完整 HTTP 地址，未找到 HTTPS 升级证据；遵循 R01 HTTPS-only 规则显示中性占位。这是修复前结果，后续用户要求继续修复，最终结论以下方 HTTPS 验证为准。当前账户头像另因身份字段缺失而 UNKNOWN。临时诊断改动已从 LiveFollowedForumsRepository 删除。

## 用户追加头像要求后的验证

- Android 源码证明 Avatar → Sketch → 独立 OkHttpStack 原样加载接口地址；manifest 允许 HTTP。iOS 没有照搬全局明文网络配置。
- 通过当前注入的 ProductionImageLoader 对两个实际完整图址仅替换 scheme，两个均解码成功；域名 tiebapic.baidu.com、路径族 /forum/w=120;h=120/、保留全部 query。没有记录完整地址或响应体。forum-https-query-probe.log 为脱敏结果；两次临时 probe build 均 exit 0，所有临时 App probe 已删除。
- 新规则只把这一精确域名/路径族的 HTTP 吧图转换为已验证 HTTPS，同资源路径和参数不变；不合成用户 portrait。新 Unit 包含未知域/路径/端口/userinfo/fragment 拒绝、query 编码保留、匿名 Loader 请求及旧头像/Cell 复用。
- 首页行可复用同 forumID 已有最近访问公开图；图源变更进入 row value，业务行 ID 不变。
- forum-avatar-lint.log 首轮 exit 2：移除临时 probe 后遗留两个空行；只需清掉多余空行。

- forum-avatar-unit.xcresult exit 65：新测试嵌套 #require 宏展开失败；拆成两个独立 require 后修正，未改变生产断言。
- forum-avatar-verified-unit.xcresult exit 0：19 项/7 suites（拒绝地址参数化额外 7 个样本），含 R03 Home/Avatar、R01 avatar 生命周期/真实 Cell 复用、Stage19 图片 Cell 复用、HTTPS 规则及 ProductionImageLoader 匿名请求。
- forum-avatar-final-lint.log exit 0。

- forum-avatar-iphone.xcresult exit 0，1/1，44.333s；该候选头像规则与 Home 投影的完整 R03 iPhone smoke。
- final-gate-lint.log / diff-check.log exit 0。

- forum-avatar-ipad.xcresult exit 0，1/1，22.964s；该候选代码的深色、大字、横竖屏和搜索检查。

- 首次最终 Live 列表检查仍只显示两张已访问吧的历史头像，用户截图亦复现；不能将此前两个 HTTPS 最小 probe 的成功当作整表成功。
- forum-path-probe.log 确认 decoded=forum/w=120;h=120、encoded=forum/w%3D120%3Bh%3D120、accepted=0。初版错误地用未编码前缀匹配 percentEncodedPath。修订为解码后校验路径族、输出保持原始 URL 字节仅换 scheme；补针对性失败回归。临时 probe 已全部移除。

- forum-encoded-path-red.xcresult exit 65：新增真实编码形式的合成回归稳定复现 nil resource。
- forum-encoded-path-green.xcresult exit 0：20 项/7 suites，通过路径修订后的头像、Home、匿名图片请求和复用回归。无断言放宽。
- delivery-lint.log exit 0。所有临时诊断源码均已删除。

- delivery-iphone.xcresult exit 0，1/1；delivery-ipad.xcresult exit 0，1/1，22.923s。两项均在编码路径修订后执行。
- delivery-diff-check.log exit 0。

- 修正编码后整表仍存在第二类旧 CDN 地址；forum-family-probe.log 对全 18 项分类：tiebapic.baidu.com/forum/w=120;h=120 为 9 项/accepted=9，imgsrc.baidu.com/forum/pic 为 9 项/accepted=0。后一类 HTTPS 实际解码成功后，新增精确 host/path 配对及合成回归，不扩大到通用域名规则。

- forum-all-families-unit.xcresult exit 0：最终两个 CDN/path 配对共 21 项/7 suites；forum-all-families-lint.log exit 0。此前两端 delivery smoke 已通过；此后只增加纯头像 URL 映射的旧 CDN 配对，复跑模型/Loader/复用 Unit 并以最终 Live 整表复核交付。

- forum-all-families-build.log exit 0。最终 Debug .app 已通过 simctl install 覆盖两台，并正常 launch；无 uninstall/erase/Keychain 操作。最后一次进程 iPhone=17373、iPad=17380。
- Live 已确认首屏七个关注行均显示实际吧图，其中包含原失败的钢笔/自动铅笔；新钢笔吧成功加载并返回后新增最近访问。首页顶部截图 iphone-home-top.png；iPad 未登录生产首页为 ipad-home.png，两端 Fixture 图在 delivery 附件目录。
- 远程 CUA 的拖动/滚动动作未能改变当前 Simulator 的列表位置，但折叠/展开、点击进吧可响应；进程 CPU=0%，没有以工具滑动无效认定主线程卡死。已请求用户手动滑到中部以完成对应截图和下半段核对，暂不宣称全 18 个图均已目视确认。

Live 深色首页已检查并保存 iphone-home-dark.png，随后恢复原 light 设置；停留首页并展开最近访问。当前仍待用户手动滑动完成中部截图、下半段全部吧图及 Live 中部返回位置检查，未伪造对应截图或通过记录。Unit 日志仍有共享 UITableView 测试承载的 visibleCells 更新期诊断；相关测试通过，本阶段未修改共享承载。

## 修改文件与关键状态

- App/AppShellContent.swift、App/FollowedForumsAppIntegration.swift：只注入同一历史 Store 与图片 Loader；App/Navigation/AppRoute.swift / Specs/ROUTE_MAP.md：首页准入既有 search route，保留独立路径。
- Sources/Core/Models/BrowsingHistory.swift、RecentForum.swift：可选公开吧图、schema-1 兼容、最近优先且去重上限 20；原持久历史仍 500。Sources/Features/History/Presentation/BrowsingHistoryStore.swift：成功展示时携带公开吧图。
- Sources/Core/Models/TiebaUserVisuals.swift：完整 API 吧图只在两个已证实 host/path 配对上从 HTTP 适配 HTTPS，保留编码路径/query。用户 portrait 合成未放宽。
- FollowedForumsState.swift / FollowedForumsView.swift / FollowedForumsListPresentation.swift / HomeForumComponents.swift：平面搜索、最近 chips、40pt 关注吧图、真实热度/Lv、细分割线与中性状态；稳定 forum ID；页头不覆盖论坛 anchor。
- Tests/R03HomeTests.swift、R03ForumAvatarTests.swift、Stage17ProjectionTestSupport.swift、UITests/R03HomeSmokeTests.swift：本阶段回归和原测试适配。
- ADR-0023、API_EVIDENCE、MATRIX、TASK_STATE：来源、运行证据、失败与当前门禁。没有新动画、手势、overlay、依赖。

## 当前截图与风险

- iPhone Live：Artifacts/VisualReview/R03/iphone-home-top.png、iphone-home-dark.png。至少三个成功访问（耐腐蚀艺术馆、高通、新钢笔）已显示为最近 chips；首屏七个关注行吧图已目视成功。
- iPad：ipad-home.png 为最终生产未登录状态；ipad-delivery-final/ 为隔离 Fixture 的深色/大字/横竖屏对应页面。未操作 iPad 凭据。
- 头像修复前的 HTTP 限制和两次不完整覆盖均如实保留；最终协议字段/匿名请求/复用 Unit 21 项通过。没有宣称已逐一目视全部 18 张。
- 当前用户头像仍无已证账号身份来源，使用中性缺省；没有置顶数据，不虚构置顶分组。
- R02 历史已知失败不在 R03 被消除或改写。中部截图及 Live 中部返回位置需要用户手动滑动补核对；工具拖动未生效，不能据此断言 App 滚动失败或通过。
- 下一阶段前置已满足：2026-09-23 用户明确批准 R03 并授权提交、进入 R04。原始验证限制及失败记录保留。

## 用户批准后的提交门禁

2026-09-23 最终工作树复跑：approval-unit.xcresult exit 0（41 项/8 suites，含 Home、Avatar、Followed、History 与图片 Cell 复用）；approval-smoke.xcresult exit 0（iPhone R03 完整流程 1/1，43.957s）；make lint（approval-lint.log）、make build（approval-build.log）、git diff --check 均 exit 0。未跑完整 quality/无关矩阵。只提交 R03 文件和本阶段提示词，未来阶段提示词及本地 agent 配置保留未暂存。
