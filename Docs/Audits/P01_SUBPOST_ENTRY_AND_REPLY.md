# P01 修订版：楼中楼入口与具体回复点击

- 日期：2026-10-19；源码基线 `8a2f28d36c606c7628228b35e76ea95aee8dcbc5`，继续当前工作树，保留用户原有未跟踪文件。
- 合同：按修订后的 P01，移除主帖蓝色“查看全部 N 条回复”及其行高；预览普通文字/背景进入现有三级页；三级页具体正文/非交互背景复用该条 reply intent。第一步不打开编辑器。没有暂存、提交、推送或 P02。
- 参考：用户登记的私人本机 IPA 可读，22.11.1 / 22.11.1.0，SHA-256 `8b7daae086ef9d3f35cf1ea2004336e09cec83d7ec955d521ebe0d725cba9f15` 匹配。按用户明确合同实现；未宣称静态符号证明官方运行时表现，未复制原包代码/资源、未重做全包分析。

## 根因及最小修改

原 ThreadReaderPostView 只在 remainingSubpostCount > 0 时构造旧入口按钮；预览 UITextView 没有普通文字点击回调。SubpostsContentRow 也只在小“回复”按钮上调用现有闭包。这是局部输入接线缺失，不是发送或分页故障。

- 主帖保留原最多三条预览，不再由剩余计数决定导航。没有可展示预览时不造空盒/新占位。仅删除旧按钮，保留原文字/字号/颜色/内边距；其余页面视觉不变。
- TiebaRichTextView 新增默认 nil 的 onBodyTap；仅预览和三级页正文启用。UIKit 单击识别让位于选择的双击/长按，已选择文字和链接不派发正文动作。updateUIView 更新闭包，dismantle 清除，原复制/表情文本映射不变。
- 背景动作只附在原有实际背景，无透明覆盖层、嵌套 Button 或高优先级手势。原链接、@、头像、图片继续独立处理。
- 原 SubpostsView/Store、AppRouter、Composer、VirtualizedList、缓存和返回逻辑保持。已有路由去重和 ComposerService 的 presentation guard 保持。目标沿用 threadID + 父 postID + 当前 subPostID + 当前条作者；不从“回复乙”文字猜目标。
- 无请求/签名/账号准备/上传/发送成功刷新变化；WRITE_BASELINE 文件及保护源码未变。无新动画、overlay、依赖；新增仅局部启用的单击识别。

## 定向证据

原始日志/xcresult/安装证据仅在 ignored `Artifacts/VisualReview/P01/`。

- `ui-red`：首版测试漏写原元素 ID 的 `.ssubPost`，主动终止该错误定位的运行，exit65，不计产品红灯。
- `ui-red-corrected`：修正测试定位后，两项均在预期行为断言失败：小预览不能打开三级页、三级页正文不能打开编辑器，exit65。
- `ui-green`：测试中的嵌套 Swift Testing require 宏不能编译；拆分临时变量后 `ui-green-buildfix` 两项通过，未改断言。
- `unit`：P01SubpostInteractionTests、R08SubpostsNavigationTests、R08SubpostsStoreTests、R07RichTextBuilderTests，共12项/4 suites通过。覆盖1/2/3/23和未知总数的三条限制，作者/父楼/子回复/草稿身份，分页去重/取消/失败/阅读锚点，链接排除、回调更新、原生选择与复制/表情。
- `ui-final`：iPhone三项通过。实际文字点击两步流程、取消后另选作者与恢复原草稿、链接/@独立动作、第三页预览背景进入/原位置返回。
- `ui-interactions`：iPhone一项通过。正文拖动实际改变位置而不弹编辑器，长按出现原生复制菜单。
- lint 首次仅新增测试 import 排序失败；修正后605文件0违规，WRITE_BASELINE23项通过。没有更改规则或摘要。

- `ipad`：隔离 iPad 一项短流程通过，实际预览文字 → 三级页 → 第二条正文 → 编辑器 → 取消/其他作者/草稿恢复 → 原父楼。
- `make build`、最终 `make secret-scan`、`git diff --check` 均通过。未运行 quality/quality-fast、全量 Unit 或压力矩阵。
- 正常安装：`visual_review_build_install.sh P01` 完整 Debug 构建、模拟器签名/entitlement校验和原 iPhone 覆盖安装通过；同一包覆盖原 iPad。两设备主程序/debug dylib/Info.plist 与产物逐字节一致。安装器重新分配数据容器 UUID，因此首次“路径必须相同”审计断言失败；后续核对迁移后的原6份草稿/书签摘要全部一致，未卸载/erase/清 Keychain/数据。不可把路径变更写成数据清空，也不宣称路径未变。
- Live：原 iPhone 的登录头像、关注吧和原阅读缓存仍可用。已从真实灰框进入对应第6楼三级页，服务端计数2、当前可见1条；未打开Live编辑器或发送。返回后停在该父楼灰框，截图 `20261019-111214-live-small-preview.png`。另已看到较多回复父楼最多三条且无蓝色行。iPad正常包已安装，本轮其完整短交互验证在隔离Fixture完成。

## 边界

自动化仅固定 Fixture/Mock，未执行真实发送/上传/点赞/关注/删除。不把 UI 或 Mock 通过表述为服务端审核已验证。正常 Live 安装和人工停点结果见 TASK_STATE 当日记录；用户真实两次点击及发送由用户验收。


## 2026-10-19 用户补充：移除灰色回复入口，普通楼层正文直接回复

- 继续以上未提交工作树。用户明确将范围扩展到普通楼层与首楼的正文点击，并删除主帖和三级页独立的灰色“回复”按钮及行高。回复总数标题、引用中的“回复某人”内容与底部输入栏保持。
- ThreadReaderFloorViews 将普通正文接到原 onReply(post)；SubpostsContentRow 删除旧按钮。沿用原 ThreadComposeTarget/SubpostsStore/Composer，不改变目标映射、草稿、读取刷新或发送网络。普通楼层正文打开该楼编辑器，灰框预览仍只打开父楼三级页。
- 原按钮的收藏/本机书签/权限允许的删除菜单迁到作者栏长按；作者栏单击仍是个人主页。仅给现有作者栏 label 明确矩形命中区域，未增加可见按钮、占位、透明覆盖层或高优先级手势。正文仍使用上一轮的局部单击辅助器，原长按选择/复制保持。
- 灰色按钮删除后，同步 R08/R09/R12/U08/U10/U12 的旧选择器；U08 缩进断言直接比较正文与头像，仍验证刷新前后位置一致。没有降低生产断言或改写请求保护摘要。
- 红灯：grey-reply-red 中普通楼层正文点击不能打开编辑器，1项失败。green 首轮3项通过，R09对含链接的首条正文使用中心tap没有打开编辑器，U10作者栏长按未命中菜单。R09 改为明确第一行普通文字坐标后通过；U10 先排除部分可见的测试定位，层级证据仍显示误进用户主页，给作者栏 label 补 contentShape 后书签完整往返通过。
- 图片交互附加测试首轮/第二轮失败在测试 reveal 要求整张长图进入视口，不是 MediaViewer 故障；先显现该楼正文并等待图片加载，再点击可命中的图片，保留实际 MediaViewer/独立头像/正文拖动/原生复制断言，grey-reply-media-visible 通过。产品图片和列表布局未改。
- iPhone 本轮6个直接UI场景通过（分批日志）：普通楼层与子回复正文/无灰色按钮、子回复链接与@、拖动和长按复制、草稿取消恢复、作者栏书签到指定楼层/返回、正文链接/图片/头像独立动作。lint 605文件零违规、WRITE_BASELINE23项通过；首次仅3处参数缩进违规，修正后通过。全部原始失败与复验日志保留在 ignored Artifacts/VisualReview/P01/grey-reply-*。

- 最终验证：grey-reply-ipad 的普通楼层正文与小预览两步流程2项通过，含不同作者/草稿/原阅读位置返回；grey-reply-unit 的P01三项通过（含五种计数参数）。make build、make secret-scan、git diff --check通过。没有运行全量质量矩阵。
- 覆盖安装：原iPhone17Pro与iPadPro13M5均为当前完整正常Live Debug.app，主程序/debug dylib/Info.plist摘要与构建产物一致，6份原有草稿文件摘要保持；未卸载/erase/清Keychain。grey-reply-installed-proof.json记录源码与安装摘要，只在ignored目录。
- 人工停点：iPhone从保留的浏览记录恢复真实原帖11楼附近，当前12楼的一条可见子回复灰框和14楼两条预览均可见；灰色“回复”及蓝色“查看全部”均无残留或占位。账号显示已登录。截图20261019-114631-live-no-grey-reply.png。用户可直接点普通正文回复，点灰框则先进入三级页，再点具体子回复；Live编辑器/真实发送留给用户。CUA历史列表一次旧元素ID失效，刷新AX后正常打开，没有修改产品来规避工具问题。
- 状态：READY_FOR_USER_VISUAL_REVIEW。不暂存、提交、推送、制作IPA或进入P02；无新增网络调用、动画、overlay、依赖。


## 2026-10-19 用户补充：楼层/日期/属地下移，收紧作者栏

- 依据用户本轮第三张官方 iOS 截图，仅调整主帖楼层和三级页父楼/子回复的元信息与垂直排布。普通楼层底部显示“第N楼 MM-dd 属地”，三级页子回复显示“MM-dd 属地”；子回复不从 subPostID 或数组下标伪造楼层号。元信息位于正文和现有灰框预览之后，与正文左边缘对齐，去掉“来自”和点分隔。原灰色回复、蓝色查看全部行继续不存在。
- 根因：原作者栏仍为昵称/时间两行，并在整块44pt作者栏之后增加8pt间隔；删除灰色回复后正文直接接分隔线。现在作者姓名与头像居中，正文紧接作者栏，底部用真实元信息行及8pt上/12pt下边距形成收尾。头像、图标、正文字号和元信息字号保持。
- 修改：ThreadReaderFloorViews/SubpostsContentRow布局、ThreadReaderListPresentation显示日期；SubpostsView只传已有createdAt和父楼floorNumber两个展示字段，原replyIntent/Composer回调/成功刷新行保持。TiebaDateText新增独立monthDay格式化，不改变原date函数；缺时间戳的旧缓存继续保留原文字，不捏造日期。Fixture添加固定时间戳与公开属地，P01新增布局回归，U08仅适配紧凑楼层文字断言。无请求/签名/上传/缓存结构/Store/路由/发送行为变更，未更改WRITE_BASELINE。
- 定向红灯：footer-red布局测试在旧实现找不到底部元信息时失败，exit65。footer-green所有布局位置/内容断言通过，U08模拟发送关闭/回显/刷新前后缩进/草稿清理通过，但两处XCUITest默认TextView.tap进入作者页。footer-hitpoint记录正文frame=(60,487.333,364,41)，前次归档触点=(65,487.333)，恰落正文顶边/作者栏下边界。改测试使用实际正文内部坐标，不改生产手势，不放宽正文打开对象/草稿/返回位置断言。footer-body-point的两项iPhone测试通过。一次尝试读取仍运行中的xcresult尚无Info.plist，结束后正常导出附件。
- 继续使用现有局部正文点击、图片/链接动作和系统返回；本轮没有新增手势、动画、overlay或依赖。全部自动化仅Fixture/Mock。最终iPad/Unit/轻量构建与正常覆盖安装结果由下续记录补全。

- 最终定向测试：footer-body-point iPhone两项、footer-ipad iPad同两项通过，包含底部排列/无作者空行/两步入口/不同作者/草稿恢复/原父楼返回；footer-green中的U08成功回显一项通过。footer-unit的P01四项通过，含紧凑日期/跨时区日期边界/缺失时间保留、五种预览计数、父楼/子回复/当前作者身份、链接及选字排除。make lint最终605文件0违规且WRITE_BASELINE23项通过；make build和make secret-scan、git diff --check通过。未运行全量quality/quality-fast或压力矩阵。

- 正常覆盖安装：visual_review_build_install.sh P01成功，原iPhone17Pro和原iPadPro13M5安装同一完整正常Live Debug.app。footer-installed-proof.json验证主程序/debug dylib/Info.plist匹配、原6份草稿文件摘要全部保持；未卸载/erase/清Keychain/账号/历史/缓存。
- Live目检：从保留历史恢复用户本轮截图的同一主题，普通楼层显示“第4楼 10-19 四川”等底部行，作者到正文不再留元信息行；真实第3楼三级页父楼/子回复日期已在正文下方。该接口当前没有提供属地则只显示日期，未借作者主页/其他回复补造地点。多回复灰框仍最多三条，无旧蓝色行。已返回原位置，停在第6楼的一条可见子回复灰框及第7/8楼普通正文，供用户亲自完成预览→三级页→具体正文→Composer。Live未代点编辑器/发送/点赞/删除。截图footer-live-subposts与footer-live-review-ready只存ignored目录。历史列表AX元素一次过期，按新截图点击正常恢复，未改App规避工具问题。
- READY_FOR_USER_VISUAL_REVIEW：不暂存、不提交、不推送、不生成IPA、不进入P02。物理设备视觉及真实发送由用户自行验收，不将模拟器/Mock等同服务端发送结果。

## 2026-10-19 用户追加：吧名与全局回复筛选

验收合同：仅吧首页普通帖子隐藏重复来源吧名；保留其他 feed 的来源标签。将首楼下方“回复 N”替换为左侧全部回复/只看楼主及右侧热门/正序/倒序；两组可组合，全局持久化，新帖子及重新启动沿用。查询成功才更新选择，失败保留旧内容/偏好；六种 query 的缓存与阅读位置隔离，复用既有只读导航与分页。消息/书签指定 pid 定位仍优先，不因全局筛选丢失目标；显式切换筛选后使用新选项。发送/成功回调不改。

定向验证计划：设置持久化与跨帖、请求编码/服务器顺序/缓存隔离、失败取消保持，iPhone/iPad 筛选 UI，吧首页无重复标签；原 U09 为基线。本轮不运行全量 quality、不暂存提交推送。

- 实现：ForumThreadFeedRow增加默认保留来源的展示开关，仅ForumHomeRowView关闭；新ThreadReplyFilterBar复用ThreadReaderStore.selectQuery/系统按钮，左两项右三项，较大字体宽度不足时换为两行。移除原“回复N”和菜单中的重复模式开关。SettingsStore/AppSettingsRepository持久化共享查询；默认全部正序，成功才保存，返回首楼保持当前选项。消息/书签指定postID仍优先，避免隐藏定位楼层。无发送/上传/签名/成功回调修改，WRITE_BASELINE未改。
- 热门证据：定点核对官方iOS22.11.1的PBPageModel/ListItem/CommentSortHeaderView，匿名响应确认热门2/正序0/倒序1。实际r2/pn0会退正序，r2/pn1才返回sort_type2；修正热门首屏页码，正/倒序编码保持。热门分页沿原版pn分支，pid0、保持服务器顺序，省略的floor不伪造。完整读包仍沿既有adapter，不能称为全部官方iOS字节一致。额外长帖读取TLS EOF，未放宽证书或重试。
- 基线filter-baseline的U09 8项通过；filter-red旧界面找不到筛选栏而失败。初次编译filter-unit遇EnvironmentKey默认值的Sendable要求，补mainactor协议Sendable；filter-unit-green测试遗漏request.postID，补显式0。filter-unit-final 11项/2 suites通过。
- 热门页码回归：filter-hot-page-red错误使用SwiftTesting单方法过滤，实际0测试，不能计通过；改用整个suite后filter-hot-page-red-suite 3项中1项明确失败（pn不是1）。修正生产编码后filter-wire-green 18项/3 suites通过，含默认只读请求、热序首屏/次页/lz组合、服务器排名/缓存身份、跨帖/重建Settings记忆、失败取消保持及U09跳页/返回。
- filter-ui-phone 3项通过（两组选择/跨帖记忆、吧首页无冗余标签、U09跳页与首楼）；filter-ui-ipad 2项通过（选择栏/跨帖、小预览→三级页→具体正文→编辑器/草稿返回）。接线补检filter-root-smoke四Tab/独立导航1项通过。全部自动化使用隔离Fixture设备，无真实写操作。
- lint首次1处else语句位置违规，修正后filter-lint-complete 608文件零违规、WRITE_BASELINE23项通过；secret-scan与diff通过。不跑全量quality/quality-fast。原始失败/通过日志与xcresult均在ignored Artifacts/VisualReview/P01/filter-*。
- 本轮无新动画、手势、overlay、生产依赖。唯一新增持久化为本机回复筛选；两组系统按钮使用现有导航和query页缓存。实际安装/停点见下续记录。

- 最终make build成功，正常Live构建及签名/entitlement校验通过，覆盖原iPhone和iPad；filter-installed-proof.json确认三项二进制匹配，原6份草稿摘要保持。正常账号头像/关注吧仍可用，未卸载/erase/清理数据。
- Live目检吧首页图片/分享/回复/点赞栏直接接正文，冗余吧名消失；真实帖子从正序切热门后回复顺序确有改变。终止并重启正常App，进入另一篇帖子仍选全部/热门，证明跨帖和重启记忆。检查后恢复全部/正序，停在筛选栏及第2楼单条预览，留给用户两步点击。截图filter-live-forum/hot/relaunch-cross-thread/review-ready仅ignored；未代点Live编辑器或发送。
- 热门实网多页样本未验证（额外匿名长帖TLS EOF）；次页字段/顺序/缓存隔离有离线回归。物理设备和大字体完整矩阵未运行，不能冒充官方整体包或全场景一致。iPad新栏及既有点击链在隔离Fixture通过，完整正常包已覆盖。READY_FOR_USER_VISUAL_REVIEW；未暂存提交推送或进入P02。

## 2026-10-19 用户视觉修订：缩小筛选文字、压扁排序胶囊

- 以本轮用户原版iOS截图为目标，当前实现左侧subheadline约15pt、右侧caption约12pt、外胶囊34pt高，显得偏大。本轮仅ThreadReplyFilterBar展示调整为左侧footnote约13pt、右侧caption2约11pt、外胶囊默认26pt；选中胶囊22pt。44pt点击区域独立保留，胶囊与文字随Dynamic Type放大，不改选择/持久化/网络/发送。继续原脏树，不新增手势、动画、overlay或依赖。
- 人工验收：同宽对比小字体与扁胶囊，检查全部/楼主和三种排序仍可点，iPhone及iPad覆盖原Live App保留数据，停在筛选栏。复用既有P01筛选短UI分别跑两设备，不为纯尺寸改动另造测试；基线复用上一轮同一源码的filter-ui-phone/ipad与filter-build通过结果。

- 本轮直接回归：compact-filter-phone、compact-filter-ipad各执行既有P01ReplyFilterTests一项且通过，覆盖两组点击与跨帖记忆；make lint 608文件0违规且WRITE_BASELINE23项通过，make build成功，make secret-scan、git diff --check通过。未新增尺寸镜像测试，未运行全量quality/quality-fast。compact-filter-before.json与当前摘要核对：本轮生产仅ThreadReplyFilterBar变化，协议/查询/导航/SettingsStore未变。
- 正常安装：visual_review_build_install.sh P01完成完整Live构建、签名/entitlement校验并覆盖原iPhone；同一产物覆盖原iPad。compact-filter-installed-proof.json确认两设备主程序/debug dylib/Info.plist均匹配，原iPhone的6份草稿摘要全部保持，iPad原无草稿；未卸载、erase、退出登录或清理数据。
- Live视觉：iPhone打开用户最新截图同一真实帖子，已见较小字体和26pt扁胶囊，停在筛选栏及第2楼两条子回复预览。iPad横屏从保留历史打开真实帖子，筛选栏在详情列正确呈现且两组均完整可见；当前已登录，保留侧栏与阅读内容。截图20261019-152906-compact-filter-live-phone.png、20261019-153237-compact-filter-live-ipad.png仅在ignored目录。部分远端头像读取失败显示既有占位，与本轮布局无关，未重试或改网络。
- 工具记录：一次Simulator Window菜单选择后AX仍指向其他手机窗口，再次选中并截图确认已切到原iPad；未更改产品绕过工具问题。本轮未发送或代点点赞等远端写操作。字体放大由现有动态字体/ScaledMetric接线支持，本轮未运行物理设备或大字体完整矩阵。
- READY_FOR_USER_VISUAL_REVIEW：两台原模拟器已覆盖并停在真实筛选栏。无新动画、手势、overlay、依赖；未暂存、提交、推送、生成IPA或进入P02，等待用户目检。

## 2026-10-19 用户验收与提交

用户明确授权本地提交当前P01并进入P02。已验收产物及所有定向回归沿用；本轮提交前复查lint、secret-scan与diff。只纳入P01实现、合成fixture、相关回归、API证据及阶段记录，不纳入私人截图/IPA/运行产物或用户未跟踪提示词；不推送。
