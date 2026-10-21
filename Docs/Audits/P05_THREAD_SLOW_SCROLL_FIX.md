## 2026-10-21 P05 — USER_ACCEPTED_SIMULATOR / DEVICE_IPA_READY

用户确认“不会卡半秒不动了也不跳了”，授权编译 IPA 供自行安装测试。此次只对当前已验收的 P05 工作树作设备归档和交付记录，没有继续改产品代码，没有提交/推送/发布或新阶段。下方候选与失败记录保留为历史。

- 基线 HEAD `0885df824189f02d41c2479f02c93a48a2895e86`，加现有未提交 P05 生产修复。构建前保存801项 App/Sources/Generated/Resources/Config/project/lock输入摘要，构建后逐项一致。Release SwiftFileList实际包含 `VirtualListCellContent.swift`、`VirtualizedList+Height.swift` 和三个修改的列表源文件，未使用旧发布源码。
- `make generate` exit0；`xcodebuild archive -project TiebaLite.xcodeproj -scheme TiebaLite -configuration Release -destination 'generic/platform=iOS' -derivedDataPath Artifacts/Releases/P05-device-test-20261021/DerivedData -clonedSourcePackagesDirPath .build/SourcePackages -onlyUsePackageVersionsFromResolvedFile -skipPackageUpdates -archivePath Artifacts/Releases/P05-device-test-20261021/TiebaLite.xcarchive CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO` exit0 / ARCHIVE SUCCEEDED。唯一warning为未依赖 AppIntents.framework而跳过元数据提取；没有归档失败。
- 沿用beta6设备隔离脚本，仅改当前归档/中间文件路径；`bash Artifacts/Releases/P05-device-test-20261021/verify-device-release.sh` exit0，真实网络、图片与阅读组件正向控制通过，TestSupport/Debug/Fixture未混入。`python3 Artifacts/Releases/P05-device-test-20261021/package_and_verify.py` exit0：arm64/iPhoneOS、0.2.0/Build19、最低18.0、iPhone+iPad、原Bundle ID、AppIcon/Assets、无签名/描述文件、ZIP CRC、全部140文件逐字节和可执行权限通过。
- `make write-baseline-check` exit0 /23项、`make secret-scan` exit0、`git diff --check` exit0。复用前述直接 Unit/UI 验证；本次只做设备构建与包检查，不重复全仓quality或模拟器安装。
- 产物在 ignored `Artifacts/Releases/P05-device-test-20261021/TiebaLite-0.2.0-P05-ios18-arm64-unsigned.ipa`，**4,996,496 bytes**，SHA256 **`6db34d6cbeb208322867b8321daa0e6de64771f9f7636dee5abf98465bb499c9`**。同目录保存 `SHA256SUMS`、`production-inputs.json`、`source-state.txt`、`generate.log`、`archive.log`、`release-isolation.log`、`package-verification.json`、冻结/secret检查日志和打包脚本。
- 沿用既有未签名IPA自行签名安装方式；不改版本号/签名团队/Bundle ID/Keychain，不包含用户账号、草稿或缓存。无新增动画、手势、overlay、依赖。模拟器用户验收已通过，真机安装与慢拖表现仍 **NOT_TESTED**，待用户本次测试；没有把模拟器确认外推为真机FPS或发送成功。

## 2026-10-21 P05 图片跳动续修 — READY_FOR_USER_VISUAL_REVIEW / 未提交

用户明确拒绝上一轮候选：遇到图片会乱跳。旧 READY 仅为历史候选，未获验收。本轮保持当前 HEAD/worktree，不回退旧版本，不改图片/发送协议，不新增阶段。

### 根因与红灯

- 上一轮小步复用测试缺少屏幕位置连续性断言；scrollToRow 每次重新指定目标、最终高度正确，都不能证明自然滚动过程中不跳。
- 新回归使用真实 UIWindowScene、生产 ThreadReaderRowView/UITableView、自适应高度、预解码有效 PNG、带楼中楼/图片的80楼样本，并启用实际阅读 scope。每显示帧移动8pt，前后共1,200步；用相同业务行的屏幕坐标验证位移，允许2pt像素/布局误差，不只比较 contentOffset（UIKit 可以合法校正离屏估算）。确认经过第17楼楼中楼及第37楼图片，且图片 loader 确实被调用。
- 未修候选 `geometry-red` 额外位移最大40pt；`sizing-red` 另一次最大130pt（楼中楼行高度差），并在短→长最小复现里测到：业务已换为480pt行，第一次 systemLayoutSizeFitting 仍返回旧72pt。后续显示更新才得到新高度。这是延迟内容绑定造成的生产测量问题，与上一轮未接scene的测试观察问题不同。
- `compatible-config` 仅给同一个 ObservableObject 根重新赋配置，仍有40pt跳动；同轮 Stage18 原物理 Cell 选择也未找到完整可见的初始对象，结果为失败，未采用此版本。无效改动已撤。没有删除/放宽新文字可见、旧结果不能污染和实际复用断言。

### 修正

Cell 仍持有有界的业务绑定和单调代次，prepareForReuse 仍不清空 hosting 配置。改为每次兼容 UIHostingConfiguration **直接携带不可变的本次内容/代次**，不依赖 ObservableObject 通知到下一帧才更新高度。系统可以复用 contentView，并在首次测量时读取新行。解绑立即禁用旧行交互；重绑新子树隔离旧 State/迟到结果，最终拆除释放。没有新框架、计时延迟、固定行高或强推 begin/endUpdates。

- `value-binding` 首次长行测量为480pt，几何额外位移0；旧行隔离、ABA、同一绑定更新均通过。
- 最终回归增加480→72→360→64的首次测量与同一宿主对象检查；清理临时探针后 `final-unit` **33项/8 suites通过**，1,200步额外位移仍0；涵盖图片迟到、P01目标、内容版本/预取、首定位和阅读投影。
- 新绑定内容、图/链接/复制/点击、缓存、预载、图片保存、分页、阅读事务及已验证官方iOS写链路均沿用；无新动画、手势、overlay、依赖。

### 分页期间的第二处跳动

- 不把前述小步几何绿灯当成自然拖动验收。`iphone-ui` 原4项通过，但截图/业务ID显示返回第29楼之后向上滑竟到第26楼；原测试只检查位置不同，漏掉方向。新增“正序样本向上滑必须前进”并保留精确原位、图片往返、新位置二次恢复要求，`forward-ui` 明确失败，立即滑后截图也为第26楼，排除仅AX读旧对象。
- 一次临时纯几何事件记录 `trace-ui` 捕获：pan中 count49→49的footer快照使contentSize 6668.333→8594、offset约4210.667→5329，随后追加到64行；停稳后又出现约1190pt的几何重算。该次强断言偶然通过，不能掩盖无探针的失败。临时记录已从生产删除。普通追加/8pt程序步进 `paging-geometry-red` 为绿，说明它未单独复现真实pan的快照跳动，未冒充红灯。
- 沿用自动行高，只在 VirtualList 内按业务ID记录**已实际显示**的高度供 estimatedHeight 使用，避免分页快照把已经测量过的楼层全部重新估成180pt。记录不持有Cell；真实内容/版本环境变更、宽度/字号trait/方向变化时不使用旧估算，删除行剔除、dismantle清空。没有固定高度、强制滚动补偿、暂停分页或新缓存持久化；UITableView仍实际测量内容。
- `height-estimate-ui3` 无探针的强方向UI回归通过；`height-final-unit` 34项/9 suites全部通过，含带图1,200步往返最大额外位移0、恢复第37楼再分页的600步约0.000003pt、旧行隔离/ABA/P01/阅读投影，以及实测高度在分页中保留、内容/宽度变化重新测量和释放。
- 新增文件首次未运行工程生成，`height-estimate-ui` 编译失败；生成后 `height-estimate-ui2` 报generic class extension不能声明ObjC delegate，已将delegate放回Coordinator并保留纯辅助extension。`height-traits-unit` 最初在trait尚未应用时立刻断言失效而失败，改为公开 `updateTraitsIfNeeded()` 并同时断言实际trait已改变，保留原180pt回退要求；`height-traits-unit2` 通过。没有延迟、删除断言或放宽业务检查。
- `height-repeat-ui` 无探针相同路径重复2次全部通过；连同首次共3次从精确第29楼向上滑正常前进，新位置再次恢复（重复两次均为第33楼）。`height-ipad-ui` 3项通过：图片/作者/文字选择独立，少量预览两步回复，阅读位置重进及同表缩窄/还原/新位置再次恢复。未运行全仓矩阵。
- 最终lint首次2个新文件参数换行对齐错误，格式修正后 `final-lint2` 629文件0违规，冻结发送23项通过；`final-secret` 与diff检查通过。

### 短性能边界

`value-timing`：同原隔离iPad/iOS26.5、UITesting -O、同80楼混合样本/预解码图片、第一遍预热后第二遍156个scrollToRow步骤。reuse n222，p50/p95/max=0.207/0.280/0.514ms；bind n227=0.050/0.065/0.206ms；layout n334=6.816/10.619/23.768ms；scroll max23.913ms；dismantle10.739ms。驻留峰值13，最终全部释放。原471ms清空宿主栈未重新引入，样本未发现长操作被移到绑定/布局/拆除。

显示帧间隔max149.820ms包含自动化/测试环境影响，不能推导真机FPS或宣称全部偶发停顿解决。临时计时与实验打印已从生产移除，原照片/账号未用于此回归。记录都在 ignored `Artifacts/VisualReview/P05/ImageJump/`。

### 正常 Live 交付与边界

- `make generate` / `make build` 正常 Debug generic Simulator 成功，最终 lint 629文件0违规及冻结发送23项、secret-scan、diff检查、codesign严格校验通过。实际命令和中间失败见上面的每条证据，未跑全量quality/历史阶段。
- `.build/DerivedData/Build/Products/Debug-iphonesimulator/TiebaLite.app`（0.2.0/Build19）已覆盖原 iPhone17Pro `70D93841…` 与 iPadPro13M5 `EE89FBE1…`。未卸载、erase、清缓存、改Bundle ID或账号；两台无启动参数、无debugger/采样器，运行完整正常Live。`ImageJump/profile-installed-proof.json` 核对程序/dylib/Info/Assets/图标摘要均相符，iPhone原6份草稿/书签文件摘要不变，iPad原无该类文件。
- CUA确认两台仍登录、关注吧和浏览历史保留，均从正常“我的→浏览记录”打开11116138791；iPhone从原第5楼向上滚一屏，iPad恢复第2楼附近，最终两台屏幕均实际显示第4楼正文、已加载GIF和3条楼中楼预览。私人截图仅在ignored `ImageJump/live-iphone.png` / `live-ipad.png`。未用测试壳作为交付，未执行真实发布/点赞/删除。
- 修改文件：VirtualListCellContent、VirtualizedList（Cell/Coordinator）、+Version、+Snapshot及新增+Height；测试为Stage18/19、P05Mixed、P05MeasuredRowHeight、U06P3、U03 UI及两个显示支架；记录为本审计、TASK_STATE、ADR0018、交互合同。旧UILabel观察问题与本次生产首次测量/分页估算问题明确区分，断言未弱化。
- 无新增手势、动画、overlay、依赖；沿用当前外观、搜索/图标、列表/分页/缓存预载、图片保存、阅读事务、P01两步点击和官方iOS发送协议。无暂存、提交、推送或新阶段。
- 短性能数据对应不可变绑定版本、分页估算补丁前的隔离样本，不能外推为最终正常Live帧率。最终实机/iOS18与自然慢拖手感未验收；当前只到候选条件，下一步仅用户在已打开的两台正常App慢滑确认。

---

# P05 上一轮候选 — 已因图片跳动被拒绝（历史记录）

以本机 HEAD `0885df824189f02d41c2479f02c93a48a2895e86` 继续。用户明确授权 Cell 内部生命周期修改，并替代旧机械两次停止规则；未回退版本、清数据或修改发送链路。源码、31 项定向 Unit、iPhone 4 项 / iPad 2 项 UI 和正常 Live 覆盖安装已完成。状态 **READY_FOR_USER_VISUAL_REVIEW**，最终自然慢拖手感尚待用户验收。下面保留 10-20 的原失败记录。

## 观察边界与最终实现

- 先按旧“删 nil + id”做定点观察：Cell 当前业务 ID=31、旧 UILabel ID=1，新 UILabel 只在未挂窗 graph 创建。加入 root controller、等待 CADisplayLink、检查有效可见区域仍复现；独立 content view 和 controller 实验也复现，故继续检查测试挂载。
- 旧 `UIWindow(frame:)` **未关联 UIWindowScene**。`UILabel.window != nil` 不等于当前屏幕 graph 已提交。真正关联 scene 后还必须把测试 viewport 放在窗口内；两次过渡用例分别遇到 viewport 变化没有复用原 Cell、viewport 在窗口外，明确排除为测试支架错误，未当成生产失败。
- 正确挂入 scene、等待原生文字并选择完整可见的同一物理 Cell 后，稳定 holder 成功显示新 pending，旧回执返回不能覆盖它，新 ready 也显示正确。ABA 在真实表格挂载 Cell 中验证绑定；不能在脱离 table 的裸 Cell 上调用 super.prepareForReuse 后期待 UIKit 自动恢复 display 状态，相关失败实验已删除。
- 最终只有一条生产路径：原 UITableView/Diffable/UIHostingConfiguration + Cell 本地 ObservableObject holder。首次安装配置，此后原子发布完整绑定；同一业务绑定保留 State，解绑/重绑用递增代次隔离 A→B→A。复用不再 `contentConfiguration=nil`，dismantle 才释放宿主。未改外观、分页、缓存、图片 Loader、请求/发送协议、P01 两步点击；无新手势/动画/overlay/依赖。
- 移除 provider/willDisplay 内用于计数的 visibleCells 查询（运行时发出 UIKit 重入 assertion），用 willDisplay/didEndDisplaying 集合计数。只影响诊断；阅读逻辑不变。
- U06P3 的旧 401 断言已核实为 400 post +1 replyFilters +1 pagination，替换为独立分类及 402 唯一 ID，保留原预取/锚点/字号断言。

## 隔离环境性能与容器

日志均在 ignored `Artifacts/VisualReview/P05/Continue/`，使用同一隔离 iPad/iOS26.5、UITesting `-O`、原生产 ThreadReaderRowView、80 楼固定混合内容、预解码有效 PNG。第一轮预热、第二轮逐显示帧驱动同序前后滚动，共 156 个步骤。这是程序滚动开发对照，**不是用户自然拖动或真机 FPS**。初次 FixtureReadingImageLoader 内图片 CRC 失败的一轮已排除，换为既有 TestImageFixtureFactory/HarnessCapturingImageLoader 提供有效预解码图。

| 单次耗时 ms（最大值） | 旧清空/重配路径 | 稳定绑定路径 |
| --- | ---: | ---: |
| reuse | 6.711 | 0.569 |
| bind/configure | 0.423 | 0.280 |
| table layout | 25.274 | 37.720 |
| scroll 调用 | 25.406 | 35.371 |
| dismantle | 10.499 | 13.848 |
| display-link 间隔（含测试运行环境影响） | 193.062 | 184.304 |

对应 `matched-before-loaded.log` / `resident.log`。修后 reuse n=204，p50=0.241ms、p95=0.298ms；layout p95=17.968ms，scroll p95=22.091ms。不能相加嵌套计时，不能用此宣称整帧峰值消除或已解释全部停顿。原 Live 的 471ms 清空路径已移除；修后该固定样本未在 bind/layout/dismantle 发现同量级长操作，仍需最后 Live 手感验收。

新混合压力回归最初把“累计创建”当成驻留上界而失败（85/93 个累计 Cell）。weak 注册实测峰值仅 27、结束剩 12；是 UIKit 淘汰后重新分配，不是为全部楼层永久保留视图。新回归改为直接约束同时存活数量 <=峰值可见数×4，保留复用、当前绑定、释放及内容断言。原已有其他回归未删断言。计时包装、print、P05 开关/入口均从生产删除，只保留按需读取 weak 注册数量的 Debug 属性，Release 不含该属性。

## 已执行验证与失败记录

- `observe`/`holder`/`content-view`/`controller`：旧未接 scene 的显示隔离失败；`scene`/`scene-fixed-viewport`/`scene-holder`/`scene-safe-count` 的挂载/viewport 问题见上。
- `scene-onscreen`：正确 scene 下旧实际可见回归通过；`regressions` 初次编译失败（TestSupport 缺少测试模块导入），移至仅测试支持目录并显式导入后修复。
- `regressions2`/`regressions3`/`regressions4`：部分可见 Cell 的文字不在可读区、裸 Cell 绑定测试未满足 UIKit display 生命周期，修正为完整可见 Cell/真实 table 挂载；新 pending/ready 和旧结果不污染要求保留，`binding-mounted` 两项通过。
- `matched-before` 编译失败（优化模式把 weak 局部未赋值警告当错误），修正生命周期清理后通过；`matched-before2` 图片 CRC 失败不采用为性能证据。`matched-after`/`resident` 的新驻留断言误用累计数已按上面的实际对象计数修正。
- 去掉临时探针后的 `final-unit`：**31 项 /8 suites 全通过**，含 Stage18/Stage19 实际文字与迟到图、P05 混合复用/释放、U06P3 内容版本/回调/字号、P01 目标/文字点击、ThreadImageRenderState、U03 首次定位、U06P4 宽度变化/导航 inset。未跑全仓矩阵。
- 首次 lint 两个测试排版违规，已修正；重跑 627 文件零违规、WRITE_BASELINE 23项通过，secret-scan通过。
- 首次 iPhone UI 在隔离 iPhone17ProMax：图片/原生复制与拖动、子回复链接/个人页、少量预览→三级→准确回复编辑器三项通过；U03 在“离开页面以前”的定点拖动准备阶段没有停在期望业务 ID p430001（实际 p400001）失败，尚未执行返回验证。同尺寸 iPhone17Pro 再跑实际为 p440001，不能简单归因屏幕尺寸。注意这些是 postID，不是楼层编号；固定样本 p430001 的正文为第29楼。
- 加入当前原生 frame/首个可见 ID 观测后，候选 `iphone-target-observe` 完整返回测试通过，保留了精确 p430001、图片往返和再次更新位置断言。相同环境临时恢复旧清空/重配行为的 `iphone-old-path-ui` 则在返回后的再次滑动报 XCUITest 无有效 activation point；未当成候选产品故障或性能证据，实验源码已恢复到稳定绑定候选。
- 对 U03 支架仅作有界修正：目标从当前 table 查询，定位完成同时核对当前首个可见业务 ID；滑出可见区域后先判断 frame，避免向无显示区域的元素查询 hittability。精确目标、恢复完成、位置变化及第二次返回断言保留，断言前增加安全 fixture 截图，临时打印删除。最终用例结果另记。
- 隔离 iPad 的 `ipad-ui` 两项通过：少量楼中楼预览两步点击；图片往返、深处位置重进、同一列表宽度收窄/还原和新位置再次重进。未扩张到完整旋转矩阵。

## 最终检查、安装与边界

- `iphone-final-reentry` 在隔离 iPhone17Pro、最终生产源码上通过：精确 p430001（样本第29楼）→返回重进→更新到 p470001→再次重进；没有靠诊断打印等待。结合最初三项 iPhone UI 和两项 iPad UI，共 6 个不同直接 UI 场景通过。`final-unit` 的 31 项仍对应相同生产实现；后续只修正 UI 支架和文档，未重跑全仓。
- `make build` 正常 Debug/generic Simulator 成功；`make lint` 最终重跑 627 文件零违规、冻结发送 23 项通过；`make secret-scan`、`git diff --check`、`codesign --verify --strict` 通过。所有 xcodebuild test 使用 UITesting 固定场景及隔离设备，原两台 Live 没装测试壳。
- 完整 `.build/DerivedData/Build/Products/Debug-iphonesimulator/TiebaLite.app`（0.2.0 / Build19）覆盖原 iPhone17Pro 和 iPadPro13M5。同 Bundle ID、无诊断参数、无 debugger / 采样器；未卸载、清数据、改账号。主程序、dylib、Info.plist、Assets.car 和图标 SHA 与产物相符；iPhone 原6份草稿/书签摘要不变，iPad原无对应文件。证据 `Continue/profile-installed-proof.json`。
- CUA 确认两台仍已登录，真实首页及历史保留；均进入 `11116138791` AI 帖。iPhone 从保留的浏览记录恢复到第3–4楼，正文、动画图和楼中楼预览可见；iPad通过既有 U13 链接入口打开正常 Live 帖，停在第4楼正文、已加载图片及三条子回复区域。未新增入口、改数据模式或执行真实发送/点赞/删除。私人截图为 `Continue/live-iphone.png`、`Continue/live-ipad.png`，仅 ignored 保存。
- 未声明全部半秒停顿已消失：471ms 清空路径已去掉，固定自动滚动样本 reuse 最大6.711→0.569ms，但 layout / 整帧最大值没有相应改善，不能推导真机 FPS。下一步只由用户在当前正常包自然慢滑确认，不再要求多轮采样，不开始其它阶段。

修改分组：`VirtualListCellContent.swift`、`VirtualizedList.swift`、`VirtualizedList+Version.swift` 为生产修复；`VirtualListBindingFixture.swift`、`VirtualListNativeTestSupport.swift` 和 Stage18/Stage19/P05Mixed/U06P3/U03 UI 为直接回归；ADR0018、交互合同、本审计和 TASK_STATE 为记录。旧 UILabel 失败主要由测试未关联 UIWindowScene/观察未提交对象造成，并不证明已交付串楼；正确挂载后的新内容可见、旧回执隔离和 ABA 要求全部保留。最终无新增手势、动画、overlay、依赖；缓存、预载、图片保存、阅读位置、P01 两步点击及发送协议保持。没有暂存、提交、推送或更改标签。

---

# P05 慢拖动停顿 — 未完成，已撤无效实验

2026-10-20。当前 HEAD 为 `0885df824189f02d41c2479f02c93a48a2895e86`，未变更提交、分支、索引或标签。最终生产源码与该 HEAD 相同；本轮只留下本记录和 TASK_STATE。没有性能验收候选，不能标为 READY_FOR_USER_VISUAL_REVIEW。

## 场景与方法

- 原 iPhone 17 Pro / iOS 26.5 Simulator，完整 Live App 0.2.0 / Build 19。Xcode 26.6 / Swift 6.3.3。
- 用户实际反馈的《Ai这逆向工程能力太恐怖了》，第 4 楼图片及多条楼中楼附近，正文及图片预热后由用户自然慢拖动约 30 秒。
- 使用优化 Debug（`SWIFT_OPTIMIZATION_LEVEL=-O`）、短 `sample PID 30 5` 统计采样及临时无内容计数。采样期间 LLDB 已 detach，没有 XCUITest/高频 AX 查询。计数仅记录操作名、次数、耗时，不记录凭据、正文或 URL。
- 两次 Instruments attach 均报找不到进程，exit 21，未产生可用 trace，改用 sample。不是 Instruments Hitches 结果，不推导真机 FPS。
- 私人录像、sample、日志、实验 patch 均在 ignored `Artifacts/VisualReview/P05/`。

## 有效证据

| 同帖自然拖动记录 | 配置 Cell | 文本构建 | 测量 | 可见行更新 |
| --- | ---: | ---: | ---: | ---: |
| ai-natural-before | 68 | 194 / 合计 77.10ms | 985 / 合计 173.10ms | 3 |
| ai-quiet（只隔离只读准备 busy） | 59 | 163 / 合计 55.84ms | 802 / 合计 131.38ms | 2 |
| ai-frames（原行为、增加耗时峰值） | 68 | 193 / 合计 67.42ms | 1204 / 合计 203.09ms | 4 |

不同手势及可见楼层数量不同，不能据此计算性能改善百分比。

1. **busy 不是已证主要根因。** quiet 对照将只读准备 busy 计数从 108 次降到 0，用户明确反馈仍有明显卡顿、偶发约 0.5 秒停住。实验已完全撤除，ContentActionStore 与 HEAD 相同。
2. **捕获 Cell 复用热点。** ai-frames 中 `prepareForReuse` 48 次，合计 745.48ms，单次最大 **471.14ms**；configure 最大 1.243ms，文本构建最大 1.699ms，单次测量最大 2.966ms。主线程采样包含 `prepareForReuse → contentConfiguration=nil → _applyContentViewConfiguration / _setContentView → UIHostingContentView._containerViewIsHidden → updateViewGraph / sizeThatFits → TextView 构造`。清空旧 hosting 内容在回收路径上触发布局/构建，是本次已测得的主要长操作；还不能证明所有停顿均由它造成。
3. 帧计数中的 2.23 秒最大间隔包含 LLDB reset 边界暂停，**不作为 App 卡顿证据**。另一拖动帧间隔约 510ms，未建立逐时间戳因果关联。reuse 最大值的统计窗口开始/结束时 debugger 均停在主线程 runloop 等待，不把调试器暂停算入该方法执行时长。
4. 同版本可见行更新次数低，富文本解析/测量单次峰值也没有解释半秒停顿。保留现有版本、configuredRows、图片解码/合并和文字手势实现，没有继续猜测式优化。

预先工具拖动未真正滚动、用户切换帖子的一段录像、同帖但无滚动计数的 idle 记录均被排除；不是前后性能对照。对应原始文件保留，不能在后续摘要中混用。

## 修复尝试与撤除

先增加“复用保留 hosting 容器”回归，原行为确实红灯（reuse-red）。尝试不在 prepareForReuse 清空配置，并给当前业务行设置稳定 `.id(item.id)`，新保留容器回归通过；但既有 `lateResultFromAReusedCellCannotReplaceTheNewRow` 连续失败：当前第 31 行实际 UILabel 仍为第 1 行 pending 文本。

隔离运行同样失败。测试侧短诊断显示新 SwiftUI body/State 已是第 31 行，实际 Cell 后代仍是旧 UILabel；让出主队列、等一次 display frame 及 layout 并未消除。局部内容身份作用域、带 indexPath dequeue 检查也没有通过旧回归，没有安装这些版本。

不删除/放宽旧文字及迟到回执断言，也不将“新测试通过”称为安全修复。按 P05 第 8 节同假设重复失败停止补丁的规则，保存 `rejected-reuse-and-probe.patch`，撤除全部临时生产/测试改动和计数文件。没有全仓 reset、checkout/restore、清数据或回退旧版本。

Apple 对 [contentConfiguration 的说明](https://developer.apple.com/documentation/uikit/uitableviewcell/contentconfiguration-2lzvp) 允许兼容内容视图直接更新，设 nil 则替换为空视图；这一 API 合同支持调查容器复用，但不能替代本机失败的运行时回归。

## 最小替代方案（仅设计，未实施）

保持现有 UITableView、Diffable、UIHostingConfiguration 和所有上层缓存/路由。只调整 Cell 内内容所有权：

- 每个 Cell 持有一个稳定的行内容持有者，hosting 配置绑定该持有者；`configure` 原子更新当前业务 ID、内容和当前动作上下文，不反复销毁 hosting 容器。
- 生命周期明确为未绑定 → 绑定当前行 → 解绑旧行/失效旧任务 → 绑定新行。业务 `.id` 在持有者内部生效，旧异步结果必须同时满足当前行身份/代次才能进入显示状态；同一行真实内容或环境变化仍更新。
- 先用现有迟到结果测试证明实际 UILabel/图片/点击目标隔离，再验证同一行状态保持、真实内容/字体更新和容器数量有界。通过后才进行同帖同模式自然慢拖动复验。

这是一处 Cell 内部状态/生命周期调整方案，不是第二套列表或图片框架。当前尚未证明它可行，也没有宣布性能修复。

## 已执行检查及安装

- 优化 Debug 构建、诊断构建成功；frame-probe 包装 shell 曾因 zsh 只读变量 `status` 返回 1，但 xcodebuild 日志为成功，未把包装结果冒充成功命令。
- `xcodebuild test`，UITesting / Unit / 隔离 U01-Forum-Sort-iPad，selectors 为 Stage18VirtualizedCellReuseTests、U06P3ListWorkTests、P01SubpostInteractionTests。首次修复尝试 exit 65：旧行隔离失败，另有旧配置行数断言失败。
- 撤除实验后的同一 3 suites：**9 项，8 通过、1 失败，exit 65**。旧行隔离恢复通过，P01 相关测试通过；U06P3 `repeatedPrefetchPreparesIDsOnlyOnce` 仍报 402 != 401。生产与测试源码均已恢复 HEAD，证明该断言为本机基线失败。P01 已增加回复筛选行，此旧总数断言未调整；本轮不顺手修无关基线测试。
- `make generate`、`make build`、`make lint`（623 文件 0 违规，WRITE_BASELINE 23 项）、`make secret-scan`、`codesign --verify --strict` 均通过。未跑全量 quality 或新性能候选 UI 回归。
- 重新覆盖安装完整正常 Debug Live 包到原 iPhone 和原 iPad，无诊断启动参数；不是 UITesting 壳。主程序、debug dylib、Info.plist、Assets.car 和图标摘要与本次产物一致。iPhone 原 6 份草稿/书签摘要全部相同，iPad 原无对应文件；两台登录态、历史保留。
- CUA 确认 iPhone 回到上述 Ai 帖第 4 楼（正文、已加载图片、三条楼中楼）；iPad 回到原《高通8ee6为何缓存给的这么抠门，还没麒麟9050Pro给的多》第 5 楼正文/楼中楼。仅恢复正常使用状态，不作为已修复候选或流畅度通过。

未新增生产动画、手势、overlay、依赖或发送行为；未执行任何真实点赞/发布/上传/删除。无修后自然拖动成绩、无真机结论，P05 仍未完成。
