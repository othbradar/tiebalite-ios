# R12 我的页与全局视觉复核

状态：USER_VISUALLY_APPROVED（2026-09-27，用户确认居中标题解决返回按钮方块，并明确授权“现在提交，进入R13”），基线 `9681d39`。iPad 详情残留保留到 R13 集成复核。发布审核问题继续 DEFERRED_BY_USER，本阶段不改写入行为。

## 证据与计划

使用 tiebalite-android-visual-parity、tiebalite-api-evidence。锁定 Android UI `c5f1125` 的 UserPage.kt / UserViewModel.kt，目标图 `Android-target/04-user-root.png`：左姓名、右圆形头像；独立统计条；历史/主题等菜单后细分隔线，再设置/关于。统计条本来有小圆角背景，不是整行 feed 卡片。

实际 R11 Live 我的页只有资料/历史/设置/关于与调试入口，资料入口不可用；首页头像为 nil，用户资料仍为人形图标。整改前截图 `Artifacts/VisualReview/R12/iphone-live-before.png`。Settings/Session/Search/History 仍有旧圆角分组或整行卡片。

计划文件：Core 当前账户只读 Repository、UserProfile 展示 Store/组件、App 组合和我的入口；Settings/About/History/Search 的平面布局；定向测试与记录。账户复用已有元数据/Profile 请求、图片 Loader，单任务与会话隔离，刷新保留内容；我的与首页共享头像。主题复用 SettingsStore。收藏无现有能力不显示；服务中心无受支持的设备参数/route不显示；登录/退出沿用 SessionStore。扫描核心八屏及深色/iPad宽度，只修具体视觉差距，保护列表/分页、稳定ID、Pager、MediaViewer、图片缓存与发布链路。

验收：真实头像/统计或中性缺省；匿名/加载/失败/刷新/切换不串号；主题生效并持久化；历史/资料/设置/关于/登录入口可用；四根入口状态保持。iPhone八屏截图，iPad首页/吧/帖子，额外我的深色/大字号/iPad。自动化只隔离Fixture，不执行Live发送/退出/清理。

基线：Stage16B 设置、资料协议、导航定向 Unit exit 0（baseline-unit.xcresult）；make build exit 0（baseline-build.log）。证据目录 `Artifacts/VisualReview/R12/`。后续仅相关 Unit、核心短 Smoke、lint/build/secret/diff；不跑完整 quality，用户原有 Prompts/skill 文件保留。

## 实现与边界

- 当前账户：`CurrentAccountRepository` / `LiveCurrentAccountRepository` 复用已核对的只读账户元数据与公开 Profile，`CurrentAccountStore` 由 scene 持有，一次请求供首页/我的/帖子回复条共用。有效会话代次变化时取消旧任务并清空旧头像；刷新失败保留资料，提供重试，不把缺省值伪装成账号数据。
- 我的与用户资料：`AppPersonalRootView`、`ProfileSummaryView`、`UserProfileView` 对齐 Android 左姓名右 56pt 圆形头像、真实 concernNum/fansNum/postNum 统计条、浏览记录/主题/设置/关于/登录退出。已存在的资料 route 接真实 UID，`AppFeatureStoreRegistry` 保留本人资料 Store，根 Tab 往返不重建。本人页、资料页、设置和关于内容最大宽度 640pt；iPad 横屏既有三列结构保留。
- 首页与帖子：仅新增当前账号头像展示参数；`FollowedForumsView` / `ThreadReaderReplyBar` 用已有 Loader，头像来源不再固定 nil。
- 全局细节：Settings/Session 原圆角分组改平面，History 使用 plain List 与紧凑标题，Search/ContentSummaryCard 去整行圆角并使用细分割线。调试入口移到设置内部；UITestHarness 只调整这三个调试入口的前置路径。
- 没有新增依赖、动画、手势、命中遮罩或后台发布；新增的分隔线 overlay 不截获触摸、随行销毁。头像 URL/缓存/Cookie 规则完全复用既有实现。
- `protected-files.json` 校验 288 个既有 InteractionKit、图片、Core Session、Composer、MediaViewer、Forum/Recommendations、ThreadReader Store/行投影及 Generated 文件与 HEAD 字节一致。唯一帖子改动是头像入参；没有改业务 ID、分页、列表承载、滚动恢复、媒体手势或写接口。

## 全局扫描结论

八屏已生成隔离 Fixture 截图。首页/动态/消息/我的的四入口、紧凑头像和等级、吧/帖子多图网格、前三条子回复与全部入口、楼中楼内联表情、Composer 均沿用已验收结构。深色我的页无白块，大字号菜单仍可滚动到设置；iPad 竖屏保留手机式单列，横屏保留既有分栏，本阶段新增资料区域做宽度上限。

源码扫描保留的是原有媒体/投票/错误占位，以及 Android 可证实的搜索框、引用、chip 和统计条；没有把这些不同语义容器一概抹平。登录提示图标和根导航图标不是正常头像，不做替换。收藏没有现有 Repository；服务中心的 Android route 依赖未接入的设备字段，两项均不显示。

Fixture 截图仅证明固定内容下的布局与交互，不作为 Live 头像、请求结果或人工视觉批准。XCTest 在 iPad 转屏后产生的部分 app 截图带方向/裁切黑边，保留原件；最终安装后另用 simctl 采集正常 Live 页面供视觉复核，不据此改动共享导航。

## 定向验证与保留的失败

所有日志与 xcresult 位于 `Artifacts/VisualReview/R12/`：

| 检查 | 结果 | 证据 |
|---|---|---|
| 基线设置/资料/导航 Unit、基线 build | 通过 | baseline-unit.xcresult、baseline-build.log |
| 首轮相关 Unit | 18 项 / 6 suites 通过 | unit.xcresult |
| 最终相关 Unit，增加本人资料 Store 保留 | 19 项 / 6 suites 通过，0.043s | unit-final.xcresult |
| iPhone R12 三项 Smoke | 3/3，96.495s | iphone-ui3.xcresult |
| iPad R12 两项 + 既有吧/帖子搜索返回两项 | 4/4，276.833s，包含横竖屏 | ipad-ui.xcresult |
| 最终 lint | 0 violations，370 文件 | lint-final.log |
| Secret scan | 无高置信度命中 | secret-scan.log |
| 受保护文件 | 288/288 与 HEAD 相同 | protected-files.json |

Unit 覆盖：账户元数据严格解析、错误/缺失身份不接受、一次共享加载、刷新保留、退出/切换后过期回包不串号、撤销会话不能继续 Profile 请求、本人资料 Store 跨根入口保留，以及已有设置持久化/匿名 Profile 协议/身份与导航隔离。

UI 覆盖：四根入口实际切换、我的真实模型统计与资料加载、浏览记录/主题/设置/关于、主题切换再恢复、未登录入口、深色大字号、吧与帖子图片布局、子回复与空 Composer 返回、iPad 横竖屏和搜索结果返回保留。没有真实发送、退出、清历史操作。

保留的迭代失败（未删测试或放宽断言）：

1. `lint-first.log`：8 个格式/嵌套问题，修正；`lint-third.log`：新增头像调用行超长，拆行修正；最终 lint 通过。
2. `iphone-ui.xcresult`：个人资料入口断言查找被外层覆盖的内部 AX ID，页面实际已有正确姓名和公开资料。改为查外层资料页、姓名和事实字段；另外两项原本通过。
3. `iphone-ui2.xcresult`：新增 registry Set 的泛型无法推断，补显式业务类型；最终编译、Unit/UI 通过。
4. `iphone-ui3` 命令曾包含一个不存在的合并搜索测试名，实际只执行 R12 三项，未把零匹配算成通过；真实两个既有搜索测试在随后 iPad 运行并通过。
5. iPad 转屏两次记录 `App animations complete notification not received`，各等待约 60 秒后继续，页面与断言均通过。没有增加测试超时、任意延时或修改导航消除日志。

未运行完整 quality、全部 Unit、无关 Pager/MediaViewer 长矩阵。既有发布审核问题继续 DEFERRED_BY_USER；本阶段不对其可靠性作新结论。

## 完整 Live 交付

`make build` 最终 exit 0（build-final.log）；`make lint`、`make secret-scan`、`git diff --check` 均通过。定向 xcodebuild 使用 TiebaLite scheme、`.build/DerivedData`、`-parallel-testing-enabled NO`；Unit 为 Debug/Unit 配置与表中 6 suites，UI 为 UITesting/UI Smoke 配置与 R12 三项、iPad 对应两项和 AppShell 两项搜索测试。完整调用参数保留在每份 xcodebuild 日志首段。

完整普通 Debug App 已覆盖安装 iPhone 17 Pro `70D93841…` 和 iPad Pro 13 M5 `EE89FBE1…`，无 Fixture 参数启动；没有卸载、erase 或清 Keychain。两台均实际保留登录，并显示同一真实账户姓名、头像和接口统计；点击账户头部加载本人公开资料成功。iPhone 首页头像、iPad 帖子回复条头像均已实际显示。

主文件 SHA-256 `948a0b396fe50868289f8944fa6ff8b21b316183ad1eb5383bc3adf3e4383dd3`；debug dylib `3669d6dd33dacea3e0910b8d348274ccbbfdd0f72f7e105ecf26fe91665aeb2a`。两台安装产物与最终 build 一致（live-install.json）。

正常 Live 截图：`iphone-live-personal.png`、`iphone-live-profile.png`、`iphone-live-home.png`；`ipad-live-home.png`、`ipad-live-forum.png`、`ipad-live-thread.png`、`ipad-live-thread-landscape.png`、`ipad-live-personal-landscape.png`。正常 iPad 横屏截图无 XCTest 截图的裁切/黑边，三图并排与既有三列实际显示。

八屏固定矩阵见 `Artifacts/VisualReview/R12/SCREENSHOTS.md`，iPhone `R12-iphone-01-home` 到 `08-composer`，iPad 对应矩阵与深色/大字号补图均保留。Live 画面含用户内容，仅保存于 ignored Artifacts，不纳入 Git。

最终 iPhone 前台留在正常 Live 我的页；iPad 横屏留在我的与本人资料。手工可检查头像/统计、头部资料入口、浏览记录、主题切换、设置/关于及返回位置。未点退出、未发送内容。

## 未解决风险与下阶段前置条件

- **iPad 横屏详情残留，未解决**：本轮 Live 实际从首页进入吧→帖子，旋转横屏后点侧栏“我的”，中列已显示我的，但右列仍显示原帖；再点本人头像，右列正常改为本人资料。两次观察相同结果，保存 `ipad-live-personal-retained-detail.png`。本轮核心 Smoke 没有覆盖“已有深层详情→侧栏我的”这一路径，不能用 4/4 代替此问题通过。未重跑旧构建，不能断言是历史问题或 R12 新回归；不据猜测改共享导航容器。需另行定向定位，不自动进入 R13。
- 部分官方表情原图缺失、真实消息计数变化与发布审核等旧 UNKNOWN 按各阶段记录保留；R12 没有重新扩大验证结论。
- 收藏、服务中心因已有能力/route 缺口未展示。统计依照原 Profile mapper 的 proto3 标量语义，未新增无法证实的数据。
- 用户已批准 R12 并授权精确提交、进入 R13；下面的修订过程保留为历史记录。R13 最终 Release 提交仍需另行批准。


## 返回按钮瞬态方块修订（2026-09-27）

用户指出首页/帖子左侧信息转场成返回键时出现临时方块。Live 录屏已确认，两次尝试均未形成保持原布局的可交付修复，已精确撤回。方案、命令结果与失败边界见 `R12_NAVIGATION_BAR_REDESIGN.md`；证据在 `Artifacts/VisualReview/R12/BackButton/`。原 R12 候选仍保留，不能用早先阶段 READY 或静止截图表示该问题已通过。恢复构建、lint（0/371）、secret scan、diff check通过；未重跑全部 Unit/quality，不提交、不进入R13。

用户后续明确接受居中并确认方块消失，最终采用 `.principal` 标题区域方案，只改首页与帖子 toolbar 承载。iPhone 3/3、iPad 1/1 定向 Smoke、lint/build/secret/diff通过；两台普通完整 Live 覆盖安装并核对主程序与 dylib 哈希相同，登录保留。最终结果、候选撤回过程、未执行的 iPad 横屏矩阵均见上述诊断记录末节。此反馈只批准本次居中修复，不等于整体 R12 或提交授权。


## 用户批准与提交（2026-09-27）

用户接受标题居中的最终候选，并明确要求“现在提交，进入R13”。生产代码保持已验收版本；沿用上述最终定向 Unit/UI 和图片/列表保护证据，提交前再次运行 lint、build、secret scan、diff check。仅提交 R12 代码、测试与记录，不纳入用户原有 Prompt/skill、私有截图、Simulator 数据；不推送。iPad 详情残留与发布审核暂缓状态不因本次批准而改写为已修复。
