# R04 动态信息流

状态：USER_VISUALLY_APPROVED（2026-09-23）。用户反馈“我看了确实修复了，那就提交R04进入R05”，明确批准当前外观、授权提交 R04 并进入 R05。历史失败和未自动验证项继续保留，不改写为全部通过。

追加修订：用户已明确批准旧头像域名的有限 HTTP 兼容，动态作者头像已在 Live 首屏实际显示。修复的红绿测试、40 项相关 Unit、6 项最终头像测试、59.337s 原 Smoke、最终截图与边界见 R04_AUTHOR_AVATAR.md / ADR-0024。下方旧 HTTPS 失败和初次头像缺失记录保留为历史，不代表最新构建仍缺失作者头像。Live 深滚动/第二页人工验证缺口仍保留。

## 基线和计划

- 已读取指令链、PROJECT_RULES、UI reference、矩阵、R04 prompt、ADR-0022/0023；显式使用 tiebalite-android-visual-parity、xcode-quality-gate、tiebalite-api-evidence。
- Android-target/02-dynamic-feed.png 与 UI c5f1125 的 ExplorePage、PersonalizedPage/ViewModel、FeedCard、Extensions.kt、StringUtil 已核对。
- 当前 Live 基线为浅灰圆角大卡、只取一图、SF 元数据，缺作者头像/时间/摘要/真实动作计数。截图 iphone-baseline.png。
- 基线 make build 为 R03 approval-build.log exit 0；R04 baseline-unit.xcresult exit 0（20 项/3 suites）。
- 修改范围：Recommendation 模型/mapper/summary 透传、独立平面 Row 与现有 RecommendationsView 适配，定向 Unit/单个 iPhone Smoke 与隔离样本。保留 Store、稳定行投影、分页、VirtualizedList、根导航、ForumHome/ThreadReader、Pager/MediaViewer、图片缓存和 Session。
- Android Card 水平 16dp、顶部 16dp，用户头像 36dp，内容间距 8dp；正文 15sp/最多 5 行，标题按 isNoTitle 判定加粗；动态图片单张 2:1，2/3 张同排，总数超过 3 时显示前三张+真实总数。使用 R01 TiebaMediaGrid，完整媒体保留在模型，不改变 Viewer identity。
- 准备验证：真实字段及缺省/非法值、全部媒体候选与原始 ordinal、稳定行与既有分页/图片复用；一个 iPhone Smoke 覆盖分页、Tab 返回、帖子返回、失败头像和多图。lint/build/diff，覆盖安装后 Live 至少两页及顶部/中部截图，停多图动态行。

## 行为与数据合同

- 路由仍使用既有 ThreadInfo.id，不改成 threadId；图片 ID 仍为原 owner + 原始 media ordinal。
- 用户头使用已有真实 portrait/level/isBawu；缺字段中性显示，不虚构等级。
- 时间按 Android FeedCard 的 lastTimeInt；不将 createTime 或拉取时刻冒充这个字段。时间无效时不显示。
- 摘要取 richAbstract type 0/40 文本，type 2 保留文字表情标记（图形表情属于 R07）；旧 abstract 只消费已有 type 0/4 文本。未知类型不输出资源地址。
- shareNum/agreeNum/replyNum 只来自服务器，非正/不可区分的 proto3 零值显示语义文字而非假计数。分享/点赞目前只读，不发送远端写操作；帖子/回复入口保留只读导航。
- 固定网格尺寸与图片解码无关；图片状态局部更新，不向 Store 写图片结果。
- R02 历史返回位置失败保留，R04 不借此改共享列表或导航。

## 实现期结果

- feed-unit.xcresult exit 0：26 项/6 suites；feed-lint.log / fixture-lint.log exit 0。
- avatar-probe-build.log / avatar-probe-reason-build.log 均 exit 0。临时仅对 Android getAvatarUrl 的原域名/原路径改 HTTPS，通过注入的 ProductionImageLoader 最小验证两个当前裸 portrait；首轮两个失败，补充失败类型后仍两个 transport，候选 loadable=true。日志只含布尔值/固定失败类别，无 URL、portrait、用户 ID 或凭据。
- 因没有成功的 HTTPS 运行证据，不启用裸 portrait 的生产合成，不改 ATS/Loader/缓存/Session，也不猜另一个 CDN。完整 HTTPS portrait 仍正常消费；当前 Live 裸 portrait 保持中性占位。这是 R04 明确未解决项。所有临时 probe 源码已移除。

- feed-iphone.xcresult exit 65：首轮 Smoke 的单图已成功，三图子元素查询失败；AX 附件证实父层 thumbnail ID 被 SwiftUI 传播给三张图并覆盖原子 ID，图均已加载。为网格增加明确的 accessibility contain 分组，保留每张图原有标识；不改超时、不删图片状态断言。

- feed-iphone-accessibility.xcresult exit 65：contain 分组仍继承外层单一 thumbnail identifier；最终移除这一旧单图标识，直接保留 R01 每个 media resource 的稳定标识。Smoke 仍逐一要求三张图存在且已加载、第四张不存在及真实总数，去掉冗余父层查询；没有减少图片或返回位置断言。

- feed-iphone-media-ids.xcresult exit 65：三张图逐一存在/已加载和第四张不展示均通过；新 contain 分组令总数不再合并进外层按钮 label。计数断言改为直接查询原本就有的“共 8 张图片”子元素，保留总数验证；增加失败头像在第三页的状态断言。

- feed-iphone-count.xcresult exit 0：1/1，55.912s；原操作及返回位置容差 12pt 未放宽。验证三图加载、8 图总数、帖子进入/返回位置、第三页失败头像、分页/根入口切换返回位置、回滚首行。Fixture 截图 iphone-fixture/。此新 R04 场景通过不抹去 R02 旧用例失败记录。
- final-lint.log exit 0；protected-final.json：44 个共享列表、Forum/Thread/MediaViewer、图片、Session、根导航及推荐 Store/投影文件 SHA-256 一致。
- 新增展示层角标 overlay 仅在网格右下角，无独立状态/生命期，allowsHitTesting(false)，有图片总数无障碍语义。不新增动画、手势或依赖。

- final-unit.xcresult exit 65：43 项中 1 项失败，新加入隔离 dynamic.parity 后注册表数量从 9 变为 10，旧固定数量断言未同步。仅更新注册表精确数量为 10，保留逐个允许场景解析/隔离验证。

R04 头像传输补充：对无用户路径/参数的 `https://tb.himg.baidu.com/` 执行 curl --head --max-time 10，exit 60，报告证书 subject name 不匹配目标 hostname。portrait-host-tls.log 为原始结果。没有使用 -k、ATS 例外或更换未获证据支持的域名。此结果解释当前环境的 TLS 失败，不证明所有网络环境永远失败。

## 最终门禁与交付

- final-verified-unit.xcresult exit 0：43 项/10 suites。为保持 iPhone Live 页面供用户操作，本次最终 Unit 在已启动 iPad 目的地运行；先前同一组件的 iPhone 26 项通过。包含 R04 mapper/summary、既有请求/分页/取消防重、注册表、R01 primitives/映射/头像 Cell 复用、Stage19 late image、匿名请求/缓存合同。
- make build final-build.log exit 0；make lint delivery-lint.log exit 0；git diff --check diff-check.log exit 0。未运行完整 Unit/quality/interaction 矩阵。
- Live 页面通过手动切换动态加载，临时只记录聚合 page/items/multi，live-pages.log 观察 page=1/items=12/multi=3。临时诊断已全部删除，最终 Debug .app 已覆盖安装两台并正常启动，无卸载/erase/清 Keychain。iPhone 保留登录态，iPad 保持原未登录状态。
- CUA 点击可切换根页，但 drag/scroll 未改变 Live 列表位置。已请求用户手动滑几屏；没有收到完成回复，故 Live 第二页/中部截图/Live 中部返回检查仍 NOT_VERIFIED。Fixture 三页与帖子返回通过不代替这项 Live 验收。
- iPad Fixture 尝试手工宽屏查看时，Simulator 窗口坐标操作报 windowNotFoundAtPosition，未取得动态对应图，不宣称 iPad 视觉通过；已恢复最终生产 Debug .app。本阶段只要求一个 iPhone Smoke，未加跑 iPad 长矩阵。
- 截图：iphone-live-top.png 为诊断构建的 Live 首屏；iphone-final-dynamic.png 为最终 Debug 构建的动态首屏，可见单图、纯文字行及真实吧图。iphone-fixture/ 保存纯文字/单图、多图返回、失败头像/双图三张隔离场景视口截图；多图行可能部分位于视口外，三图加载及 8 图总数由 Smoke 的逐项断言验证。Live 中部图未伪造。最终停留动态首屏，未完成停留多图行的人工操作要求。

## 修改文件、状态与边界

- Core/Models 的 RecommendationSummary、RecommendationItem 新增 RecommendationFeedDetails；保留所有 valid media 候选与总数，不更换稳定业务 identity。Core/TiebaAPI 的 RecommendationFeedMapper / PersonalizedProtocol / LiveRecommendationRepository 只补白名单响应字段。
- RecommendationsView 复用既有 VirtualizedList 并改用 RecommendationFeedRow；原圆角卡/第一张大图视图删除。RecommendationFeedText 负责可注入时钟的相对时间和紧凑计数。Store、分页入口、anchor、导航/权限保持原样。
- TestSupport 新增 dynamic.parity 独立场景与 R04FeedFixture，原 root.mixed-media 不变；Unit 覆盖完整媒体/非法值/字段缺省/摘要，Smoke 保留返回位置断言并检查独立图片状态。
- Docs、API_EVIDENCE、PROTOBUF_MAP 和 THIRD_PARTY_NOTICES 更新来源与实际结果。无新增动画/手势/依赖；唯一新增 overlay 是不拦截触摸的媒体总数角标。
- UNKNOWN：当前网络下裸 portrait 的安全 HTTPS 传输；Android 当前账户身份来源仍未接入，不将 Fixture user/level 冒充 Live。Concern/Hot 子频道、视频播放、图形表情与写操作均没有新增。
- 下一阶段前置：用户完成 Simulator 外观和 Live 操作检查并明确批准；R04 未提交，不进入 R05。

## 用户批准与提交前复验（2026-09-23）

用户明确批准截图 `Artifacts/VisualReview/R04/AuthorAvatar/iphone-live-final.png` 中的修复并授权提交 R04、进入 R05。`Approval/unit.xcresult` 35 项/6 suites 通过；`Approval/smoke.xcresult` 原动态 Smoke 1/1、59.449s 通过；make lint、make build、git diff --check 与 scripts/secret_scan.sh 均 exit 0。误用不存在的 scripts/check_secrets.py 命令 exit 2，已改用仓库实际脚本复验通过。没有重跑完整质量矩阵、没有继续修改 R04 UI。

暂存检查首次 exit 2：R04 prompt 原有 Markdown 尾随空格。只清除此空格，重新检查通过，未改提示词内容。
