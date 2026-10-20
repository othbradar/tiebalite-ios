# P02 全局搜索类型与样式

## 2026-10-20 搜人进入后个人主页读取失败回归

- 触发：用户报告搜人进入资料页后，关系、主题和关注吧均加载失败。原 iPhone Live 主题重试多次仍失败，关系也失败；LLDB 定点确认在 ProfileNativeClient 的 accountID 非空守卫前，CurrentAccountStore 为 failed=true、attemptedLoad=true、isLoading=false、profile=nil。没有到达目标 HTTP 请求。关注吧页面亦呈失败；共享相同守卫。手动使用“我的”既有资料重试后账号资料正常恢复。最早资料读取失败的网络/服务端原因没有捕获，仍 UNKNOWN，不将本次证明扩大为服务端故障。
- 根因：普通 loadIfNeeded 的一次尝试标记被复用为所有个人主页内容请求的账号前置条件；失败后的新只读请求无法触发重新读取，持续本地 identityUnavailable。不是搜索用户 ID 与父路由混淆，也不是用隐私空态掩盖网络错误。
- 最小修复：CurrentAccountStore 增加默认关闭的 retryInitialFailure；ProfileNativeClient 仅列表/关系读取启用。成功资料复用，并发同 task，单次失败结束，旧账号完成拒绝；following 与原发送链路不变。无新动画、手势、overlay、依赖、endpoint 或协议字段。
- 基线 U12ProfileContentTests/U12FollowedForumsTests 通过。第一次红灯 selector 漏 Swift Testing 的括号导致零测试，不计验证；修正 selector 后 profile-recovery-red2 实际执行 1 项/4 个预期失败。修复后 profile-recovery-green 19 项/4 suites 通过，覆盖首次失败恢复、普通渲染不重试、并发恢复、账号切换、撤销租约和既有 U12 状态/协议/私有/不可查看区分。
- 首次 lint 因 execute 新分支超过已有复杂度上限失败；仅提取 loadAccount 辅助后 616 文件零违规，冻结 23 项通过。make build、make secret-scan、git diff --check 通过。iPhone 搜人 → 资料 → 主题 → 返回 → 关注吧 → 返回 → 搜索位置短 UI 1 项通过。其余安装/Live 结果记录在 TASK_STATE 和 ignored profile-* 产物；未提交。
- 同一共享短 UI 在隔离 iPad 通过 1 项。完整 Live 正常包覆盖原 iPhone/iPad，三项二进制摘要匹配；原 iPhone 6 份草稿/书签文件摘要保持，iPad 原无对应文件，账号保留。
- 新包 iPhone 真实搜索进入一位用户，关系读取完成、主题正常 empty、关注吧加载出列表、两个子页可返回。另一个“苹果”推荐目标的基本资料独立返回 HTTP200/octet-stream、48字节 Protobuf 错误300003“加载数据失败”；未改服务端错误为成功，也没有据此变更接口/身份。原截图同名用户是否同 UID 未知。所有 LLDB 已 detach，无诊断源码、原始响应或凭证留存。
- CUA 在一级资料页无法命中可见返回控件（windowNotFoundAtPosition），重开正常 iPhone 进程仅为重新定位另一个查询；不清数据，不将重启当修复或返回通过证据。子列表真实返回成功、完整搜索返回由两端固定 UI 验证。
- iPad 正常 Live 搜人进入已验证用户：关系状态完成，主题加载出帖子，关注吧为既有 contentUnavailable 中性提示；返回主页成功。两台最终停在用户主页供人工检查。无真实关注/发送，READY_FOR_USER_VISUAL_REVIEW；未暂存/提交/推送或进入 P03。

## 范围、基线和参考

- P01由用户授权本地提交为6460a0df20e9ca86c2075a820932dc939813474b；本阶段从该提交继续，未推送。用户未跟踪资料保留。
- 按P02/COMMON，仅全局帖子/吧分类与查询状态，预留明确forum scope而不实现P03；已验证匿名Hybrid GET和帖子分页沿用，不扩展论坛分页，不修改写请求、共享列表/缓存/根导航。
- 用户明确将全局搜索视觉参考改为 Android TiebaLite（排除官方搜索广告），提供 Screenshot_20261019-160503/160510/160513_贴吧 Lite.png 三张私人截图，位于本机 Downloads。只实现搜吧/搜帖，不扩张搜人；截图不入 Git。用户进一步要求搜索框与首页顶部入口样式和位置一致，并追加搜帖三种排序菜单。
- UI 定点参考只读 revision c5f1125f42498e49db4e4a9cb66313b8c8a285c7 的 SearchPage、SearchForumPage、Search/TextFields；协议保留 pinned 5545326b2a8e0d784b2f3dfbcb219c7b121e61c2 的 Hybrid JSON。未切换引用树或重逆向 IPA，不使用 Android 写请求。
- baseline：xcodebuild test，Unit配置，Stage16ASearchProtocolTests与Stage16ASearchStoreTests，隔离iPhone；9 tests/2 suites通过，exit0。日志/xcresult在ignored Artifacts/VisualReview/P02/baseline.*。现有提交前lint608文件0违规、secret-scan/diff通过；轻量build复用刚验收的同一生产源码。

## 当前行为合同与实施计划

- SearchQuery明确scope(global/forum)、type(threads/forums)、keyword、已证实默认sort；只有thread query可分页，forum scope不能搜吧。Store和路由实际携带scope；当前入口仍global，未证实forum请求直接unsupported，不暗中发global。
- 仅提交或选择尚未加载类型请求；同词独立保存搜吧和三种搜帖排序状态/页码/anchor。切换和新词取消在途任务，generation与完整query共同防迟到覆盖；失败/空只归当前类型，重复提交/分页防重。返回原类型恢复已有数据。
- 预计改动限定Search模型/Live与Fixture repository/Store/presentation、搜索route参数及直接接线、现有测试与短记录。样式遵循用户 Android 截图；共享首页搜索框外观，保留 iOS 原生返回与键盘。没有新自定义动画、手势、overlay 或依赖。
- 定向红灯先用旧Fixture证明默认请求仍混合两类；后续复用并扩展旧搜索回归覆盖类型隔离/迟到/分页/恢复/route兼容；不重跑全量quality。

## 本轮实现

- Core：新增 SearchQuery，snapshot/page request 携带 scope/type/keyword/sort，新帖 st=5、旧帖 st=0、相关度 st=2；Live/Fixture search 仅所选类型；forum scope 请求前拒绝，未添加 P03 接口或猜测参数。
- Search Store/Presentation：两类独立 state/result/page/error/anchor，切换缓存直接恢复；单任务/取消恢复/完整 query+generation 防迟到；旧列表 anchor 和 prefetch 回调带查询身份，分页失败不自动重试。
- App route/registry：可选 scope 兼容旧 `search={}` 存档；同 scope 复用 Store、不同 scope 隔离；原全局入口继续全局。Debug 双接口 probe 改为明确顺序调用，仅保留原脱敏统计。
- 相关 Unit 与调用点适配新签名，规格/ADR 更新。无新动画、手势、overlay、依赖；发送/上传/冻结摘要、共享列表与根导航结构未改。
- UI：共享 TiebaSearchBoxSurface 保持首页入口的灰底/字号/内外边距/纵向位置；搜索页在原生 inline 导航栏下面放同一输入框。搜吧/搜帖紧凑下划线标签，已选搜帖点击打开系统 Menu（三种排序和当前勾选）。平面 SearchResultRows 保留头像/吧图、作者、时间、标题摘要、吧 chip 与阅读/分享入口；赞数仅展示，不新增写入。推荐/相关吧按实际 exactMatch 分类，无关键词广告。
- VirtualizedList 未重写，按完整 query 设置视口身份并恢复 Store anchor，旧 query 的分页和滚动回调无效；新关键词清旧缓存，类型/排序切回直接恢复。没有随机 UUID、延时定位或自定义 Pager。搜索框返回不自动弹键盘。
- Android 的排序常量/GET st 调用链已记录 API_EVIDENCE；所有分页透传当前排序，搜吧查询归一化不受排序影响。选择仅 scene 内保持，未新增跨重启设置。

## 命令与证据

所有 xcodebuild test 使用 TiebaLite.xcodeproj / TiebaLite scheme、`.build/DerivedData`、`.build/SourcePackages`、锁定 Package.resolved、关闭并行，测试计划 TiebaLite；日志/xcresult 仅在 ignored `Artifacts/VisualReview/P02/`。

| 命令/选择器 | 结果 | 证据 |
|---|---|---|
| Unit：Stage16ASearchProtocolTests + Stage16ASearchStoreTests（修改前） | PASS，9 tests/2 suites，exit0 | baseline.log/.xcresult |
| Unit：Stage16ASearchStoreTests，新增默认仅帖查询（旧实现） | 预期 FAIL，8 tests中1个；forums 非空，exit65 | types-red.log/.xcresult |
| make generate | PASS，exit0 | generate.log |
| Unit：Stage16ASearchProtocolTests + Stage16ASearchStoreTests + P02SearchTests + AppNavigationStoreTests | PASS，27 tests/4 suites，exit0 | types-green.log/.xcresult |
| make lint 首次 | FAIL，5处（registry长度/复杂度与缩进） | lint.log |
| make lint 修正 | PASS，610文件0违规，WRITE_BASELINE23项 | lint-fixed.log |
| make build | PASS，Build Succeeded，exit0 | build.log |
| iPhone UI：R03HomeSmokeTests/testHomeSearchThreeSuccessfulVisitsCollapseAndReturnPosition + AppShellSmokeTests/testIndependentRootPathsAndCurrentTabReselection | PASS，2 tests，exit0 | route-phone.log/.xcresult |
| iPad UI：R03HomeSmokeTests/testIPadHomeRecentForumsSurviveDarkWidthChange 首次 | FAIL，line92转竖屏后查找首页按钮，exit65 | route-ipad.log/.xcresult |
| make secret-scan、git diff --check（早期实现） | PASS，exit0 | secret-scan.log / git输出 |
| iPad 上述 R03 用例修正复验 | PASS，1 test，exit0 | route-ipad-fixed.log/.xcresult |
| UI 初版 Unit 构建 | FAIL，Swift frontend IRGen crash（Binding setter 的 actor 方法引用） | ui-unit.log |
| 改为显式闭包后 Unit | PASS，14 tests/3 suites | shared-box-unit.log/.xcresult |
| iPhone P02SearchSmokeTests | PASS，1 test；搜索框位置/两类中部恢复/导航/键盘 | search-phone.log/.xcresult |
| iPad IPadAppShellSmokeTests/testFixtureSearchPageLoadsOnIPad | PASS，1 test | search-ipad.log/.xcresult |
| make lint / make build（共享搜索框后） | PASS，613文件0违规 / Build Succeeded | final-lint.log / final-build.log |
| Unit 加排序：Stage16ASearchProtocolTests + Stage16ASearchStoreTests + P02SearchTests | PASS，16 tests/3 suites；st=5/0/2两页、缓存隔离、迟到分页、搜吧保持 | sort-unit.log/.xcresult |
| iPhone P02SearchSmokeTests 加三种菜单切换 | PASS，1 test，54s；原位置/导航断言保留 | sort-phone.log/.xcresult |
| make lint（排序后） | PASS，613文件0违规、WRITE_BASELINE23项 | sort-lint.log |
| iPad 同一搜索短用例加共享排序菜单检查 | PASS，1 test，36s | sort-ipad.log/.xcresult |
| make build（排序后） | PASS，Build Succeeded，依赖锁未变 | sort-build.log |
| 正常 visual_review_build_install.sh P02 + 原 iPad 覆盖安装 | PASS，完整 Debug Live，签名/entitlement 检查通过 | live-install.log / ipad-install.log |
| 安装产物/数据校验 | PASS，两设备三项二进制摘要相等；原6份草稿/书签文件摘要不变 | installed-proof.json |
| make secret-scan / git diff --check（收尾） | PASS，exit0，无暂存差异 | final-secret-scan.log / git输出 |

自动化只用隔离 Fixture iPhone/iPad。iPad 失败核对 `AppShellPresentation` 和既有 R05 宽度回归：竖屏按已验收合同投影为 compact，已选吧仍占满屏幕。旧 R03 用例错误地直接找左侧首页。仅补 compact/吧页断言及原生返回，再保留原首页/最近访问/搜索全部断言；未改产品布局或放宽等待。失败后直接 simctl 截屏无可用 screen surface 超时，改读 xcresult 附件；这不是产品验证通过。

## 状态与边界

正常 iPhone/iPad 已覆盖完整 Live 包并核对二进制；登录态保留，未卸载/erase/清缓存/Keychain。iPhone 从首页搜索“高通”：新帖、旧帖、相关度分别成功显示不同结果；旧帖返回历史内容，相关度为服务端顺序，不声称服务器日期绝对单调。搜吧推荐/相关分组、实际头像/计数/简介显示正常；切回搜帖恢复原排序及缓存，最后恢复新帖。iPad Live 横屏三栏也完成搜帖/搜吧切换，首页与详情搜索框纵向对齐、外观一致，无键盘遮挡。两设备最终均留在全局搜帖/新帖在前，状态 READY_FOR_USER_VISUAL_REVIEW，等待用户亲自验收。

CUA 的一次文字输入未生效，改用同一可编辑字段的 AX setValue；iPad 输入后索引过期，重新读取 AX 定位再提交。没有增加产品输入延迟或修改手势。真实截图仅在 ignored Artifacts：20261019-164410-live-phone-sort-menu、164749-live-phone-forums、164925-live-phone-threads-ready，以及165451-live-ipad-forums、最终live-ipad-threads-ready。

P02 未暂存/提交/推送，不进入 P03。真实发送/点赞等远端写入未执行，已验收发送链路与冻结摘要不变。

未验证：物理设备、大字完整矩阵、搜帖长时间多页稳定性；搜人/吧内搜索/关键词联想不在本轮。截图与真实搜索内容仅保留 ignored Artifacts，Git 只记录方法、结果及证据路径。


## 追加搜人（2026-10-19，用户扩大本阶段范围）

用户“还有一个搜人你没做”覆盖前文暂不实现搜人的边界；继续原未提交 P02，无回退/重做。目标为搜吧/搜帖/搜人三标签、推荐/相关用户平面列表、头像/姓名/可选一行简介，整行进入既有个人主页。保持原输入框位置、搜帖排序、独立状态缓存与返回锚，不改 iOS 发送或远端写操作。

修改集中在 Search query/model/DTO/Live/Fixture/Store/Presentation/View/Rows、新 UserSearch protocol、AppRouter 和最小路由准入。新增合成 fixture 与定向 unit/UI；原 VirtualizedList、图片 Loader、主页 Store 和全局导航容器保持。无新动画、手势、overlay、依赖。

- `users-baseline`: 原 P02SearchTests 6 项通过。
- `users-red`: 首次新 UI 1 项失败于错误测试入口 app.open-search（首页实际 home.search），未到搜人断言，不算产品红灯。已修测试入口，保留日志。
- `users-unit`: 首次 10 项中 1 项失败（同一用例两根路由断言），旧 .search() scope=nil 没有匹配显式 .global 分支；改准入为 scope ?? .global。不是修改发送或网络。
- `users-unit-green`: 11 项/2 suites 通过，覆盖用户匿名 GET/字段/去重/推荐/无分页、旧/显式全局主页路由、对象/数组/空/坏响应/服务端拒绝、类型排序缓存与锚、重试/新词取消迟到、超时离线及取消不重试。
- `users-lint`: 首次 3 处测试格式违规，已改换行和对齐；最终结果待完成后补。

- `users-phone`: P02SearchSmokeTests + P02UserSearchSmokeTests，2 项通过（81.55s），覆盖原位置一致/排序/吧与帖中部恢复及用户第18项 → 对应主页 → 返回/切类型后同位置。
- `users-ipad`: IPadAppShellSmokeTests/testFixtureSearchPageLoadsOnIPad，1 项通过（49.60s），调用相同搜人导航/回位步骤，保留原分类与三种排序断言。
- `users-lint-green`: make lint，616 文件0违规、WRITE_BASELINE23项通过；`users-build`: make build Build Succeeded且依赖锁未变；`users-secret-scan`: PASS。git diff --check通过，无暂存差异。
- 验证范围遵循 COMMON 的轻量要求，没有运行全量 quality/quality-fast。下一步完整正常 Live 两设备覆盖安装及只读搜人目检；不发帖、不关注、不点赞。


### 搜人最终正常安装与读取证据

完整 Live `visual_review_build_install.sh P02` 覆盖原 iPhone17Pro，原 iPadPro13M5随后覆盖；签名/entitlement通过，两台主程序/debug dylib/Info.plist与构建产物摘要相同。原iPhone6份草稿/书签文件摘要保持，iPad该目录原无文件；未卸载/erase/注销/清缓存。`users-installed-proof.json`仅摘要与布尔值。

iPad“高通”前两次显示读取失败，未记录对应底层响应，不把它定性为网络或解码问题。第三次通过现有匿名请求，LLDB临时断点只检查状态/MIME/业务码/条数：HTTP200，application/json; charset=UTF-8，26009字节，no=0，映射47项。列表实际显示推荐/相关用户及头像简介。未修改源码诊断/参数，没有自动重试；断点已禁用并detach。脱敏摘要保存在ignored `users-live-diagnostic.json`，没有保存响应正文或真实用户ID。

iPhone首次搜人正常显示，选中相关用户可以进入正确现有个人主页并加载资料；该主页头像/关系读取出现既有失败提示，不扩大本阶段到关系/头像网络链路。CUA未获得导航栏返回AX，坐标/快捷键返回未生效；真实返回位置已在iPhone/iPad Fixture UI中确认。为停留验收入口仅正常重启iPhone App后重新定位搜人，没有改变产品导航或清数据，不能将这次重启说成返回功能验证。

两台最终均留在搜人结果供用户亲自验收。参考截图与正常Live截图只在ignored Artifacts。无新动画、手势、overlay、依赖，不改发送/上传/冻结摘要，不暂存/提交/推送、不进入P03。未验证物理设备、Dynamic Type完整矩阵及Live临时失败原因；采用既有手动重试并保留明确错误状态。

最终截图：`20261019-173421-users-live-ipad.png`、`20261019-174930-users-live-phone-ready.png`。iPhone重新定位后搜人也一次成功；最终数据/二进制校验、secret-scan、diff再次通过，暂存区为空。
