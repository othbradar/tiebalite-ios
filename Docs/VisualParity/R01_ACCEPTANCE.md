# R01 行为与验收契约

状态：USER_VISUALLY_APPROVED；2026-09-23 重新打开 iPhone Component Gallery 并说明 R01 改动后，用户回复“行可以”，确认本阶段视觉验收通过。未提交，未进入 R02；下述 UNKNOWN 保留。

- 仅增加可复用视觉原子和领域字段；生产页面排版与所有稳定 ID、VirtualizedList、UITableView/Diffable、Pager、MediaViewer 均保持现有实现。
- 用户头像 36 pt、吧图 40 pt，圆形裁切；成功/加载/失败尺寸一致，加载与失败使用中性占位。
- 用户等级只显示正值，使用 Android 等级色及 25% 色背景的小胶囊；吧等级使用中性 `Lv.` 内容宽 chip。缺失值不显示，不把 Gallery 的演示等级注入 Live。
- API 自带合法 HTTPS 头像可加载；裸 portrait 保留但不猜测 HTTPS 合成。Android StringUtil 仅证实 HTTP 合成，安全 HTTPS 合成仍为 UNKNOWN。
- 图片统一通过 ImageLoading 注入现有 ProductionImageLoader；Gallery 只替换 HTTPDataLoading 为确定性本地 transport。新视图任务跟随生命周期取消，用请求身份与代次拒绝迟到结果。
- TiebaMediaGrid 是 Cell 内部非滚动布局：1=单图 2:1，2=并排，3=一行三图，4=2×2，5=3+2，6=3+3，7=3+3+1，8=3+3+2，间距 4 pt。4–8 是本轮用户明确要求的扩展；Android FeedCard 当前仅预览前三张。
- 分割线 1 pt、默认左右缩进 16 pt；元数据 11 pt 并支持 Dynamic Type；skeleton 平面背景、无动画/阴影/整行圆角。
- 定向 Unit 覆盖 Proto/JSON 字段透传及缺省、HTTPS 规则、网格数量/顺序/几何、头像任务取消和 A→B 复用；重跑现有图片 Loader/Cell 复用测试；只执行 make lint/build，不跑全仓 quality。
- 覆盖安装 Debug App，不卸载、不清 Keychain、不 erase。iPhone 总览同时展示所有要求的样本，另提供原宽网格；iPad 对应总览。最终留在 Gallery 并输出 READY_FOR_USER_VISUAL_REVIEW，不提交、不进入 R02。

基线：make build exit 0；ProductionImageLoaderTests、Stage19ImageCellReuseTests、Stage19ImageMappingTests 定向 xcodebuild exit 0，结果位于 Artifacts/VisualReview/R01/baseline-unit.xcresult。

整改前实看：推荐使用大圆角底板、单张大缩略图和人形作者符号；现有 Gallery 只有通用 loading/error/empty，24 pt 外边距、大段留白。截图 Artifacts/VisualReview/R01/iphone-before-gallery.png。

Android UI 锁：c5f1125f42498e49db4e4a9cb66313b8c8a285c7。路径前缀 app/src/main/java/com/huanchengfly/tieba/post/：Avatars.kt（ui/widgets/compose，34–38/123–139）、Headers.kt（76–110）、HomePage.kt（ui/page/main/home，298–367）、ThreadPage.kt（ui/page/thread，2133–2148/2360–2400）、FeedCard.kt（321–364/509–590）、Texts.kt（349–398）、utils/Util.java（120–151）、utils/ColorUtils.java（48–53）、utils/StringUtil.kt（150–156）。

## 修改文件与边界

- Core：新增 `Models/TiebaUserVisuals.swift` 和 `TiebaAPI/TiebaUserVisualMapper.swift`；扩展 FixtureReadingFlow、RecommendationPage、ForumHome、FollowedForums、Search、UserProfile 的公开显示字段，以及 Personalized、LiveRecommendationRepository、FRSPage、PBPage、SearchWeb、Profile 的 mapper。
- DesignSystem：新增 TiebaParityTokens、TiebaAvatarView（含吧图）、TiebaRemoteImageView、TiebaMediaGrid、TiebaMetadataRow（含两种等级、divider、skeleton）。组件均只使用注入的 ImageLoading；未修改 ProductionImageLoader。
- App：原有 DebugComponentGalleryView 加 section；DebugAndroidParityGallery 和 DebugR01ImageSamples 是仅 Debug 的展示数据。根导航及各生产 Feature 页面没有修改。
- Tests：新增 R01VisualMappingTests、R01VisualPrimitivesTests、R01AvatarReuseTests、R01AvatarCellReuseTests；扩展 Stage11LiveRecommendationTests 的作者/吧图断言。
- 文档：本契约、API_EVIDENCE、THIRD_PARTY_NOTICES、VISUAL_PARITY_MATRIX、TASK_STATE。
- 新动画 0、手势 0、overlay modifier 0、依赖 0；ZStack 仅布局固定尺寸图片与中性占位，不拦截页面触摸。无第二套图片缓存、网络客户端或媒体查看器。

## 字段和状态

用户等级来自 User.level_id，FRS 吧等级来自 forum.user_level，关注吧保留原 LikeForum.level_id/hot_num/member_count。搜索无等级字段，始终缺省。proto3 标量没有 presence，非正等级不显示。姓名优先 nameShow；Profile 保持原有路由名称/portrait 降级。FRS 保持 userList 优先，缺少详情时只保留已返回的正 authorID。推荐保留既有 rawFeedID 列表身份。

图片 task 使用完整 ImageRequest（候选、尺寸、purpose、稳定资源 ID）作身份；loading→rendered/failed/cancelled。代次和取消检查阻止 A→B 迟到覆盖，同一用户 portrait 更新也立即隐藏旧图。UITableView 复用通过既有 UIHostingConfiguration 生命周期取消新组件的任务。

## 已执行验证

环境：macOS 26.6、Xcode 26.6 (17F113)、iOS 26.5 (23F77)；基线 HEAD `23cad4d70c72ff2d30b2a0c02a39a8383db34328`。API submodule clean/exact `5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`。

结果目录统一为 `Artifacts/VisualReview/R01/`，所有 xcodebuild 保留原始退出码、完整日志和 xcresult：

| 检查 | 实际结果 | 证据 |
|---|---|---|
| 基线 make build | exit 0 | baseline-build.log |
| 基线图片定向 Unit | 17 个逻辑测试 / 18 次执行，0 失败 | baseline-unit.xcresult |
| 首轮实现/Gallery/preview make build | 均 exit 0 | implementation-build-1.log、gallery-build-1.log、preview-build.log |
| 首轮 make lint | exit 2：样本编码函数/类型过长、颜色三元 tuple | lint-1.log |
| 修正样本组织及颜色后 make lint | exit 0 | lint-2.log |
| 首轮 R01 + 相关图片/mapper Unit | 47 个逻辑测试，0 失败 | targeted-unit-1.xcresult |
| 完整本阶段定向 Unit | 48 个逻辑测试 / 57 次执行，0 失败/跳过/expected failure | final-unit.xcresult |
| 随后 make lint | exit 2：FRS map 超过函数长度阈值 2 行 | final-lint.log |
| 提取 FRS 作者映射后 make lint | exit 0，未放宽 lint 配置 | final-lint-2.log |
| 最终 make build | exit 0 | final-build.log |
| FRS 提取后定向回归 | 8/8，0 失败 | frs-final.xcresult |
| 最终截图布局调整后 make lint / make build | 均 exit 0；只限制 Debug 总览宽度，生产组件未变 | capture-lint.log、capture-build.log |
| git diff --check | exit 0 | 最终命令记录 |
| 受保护目录差异检查 | VirtualizedList/InteractionKit、Forum/ThreadReader/MediaViewer 生产承载及 project.yml 无差异 | git diff --name-only |
| Simulator 覆盖安装/启动 | iPhone、iPad exit 0 | simctl install/launch |

定向命令为 `xcodebuild -project TiebaLite.xcodeproj -scheme TiebaLite -derivedDataPath .build/DerivedData -clonedSourcePackagesDirPath .build/SourcePackages -onlyUsePackageVersionsFromResolvedFile -skipPackageUpdates -destination 'platform=iOS Simulator,id=70D93841-1FEB-445A-8FAD-B1C29B981D5D' -parallel-testing-enabled NO -testPlan TiebaLite -only-test-configuration Unit test`，按上述结果包增加 `-resultBundlePath` 与 `-only-testing:TiebaLiteTests/<Suite>`。最终 11 个 suite 是四个 R01 suite、ProductionImageLoaderTests、Stage19ImageCellReuseTests、Stage19ImageMappingTests、Stage11LiveRecommendationTests、Stage14PFRSPageTests、Stage16BProfileProtocolTests、Stage16ASearchProtocolTests。FRS 收尾仅重跑 R01VisualMappingTests 和 Stage14PFRSPageTests。

已有 lint 配置会提示 implicitly_unwrapped_optional 配置但该规则未启用；不是 R01 新 warning。没有运行 quality、quality-fast、全量 Unit、UI smoke 或 Release build。首次 Simulator install/launch 因设备 Shutdown 返回 405，启动设备后正常覆盖安装；没有卸载、erase 或清理 Keychain。CUA 初次连接超时、随后成功；最终截图期间 Mac 锁屏一度阻止 UI 工具，用户解锁后已完成补截。最后仅将 Debug 总览最大宽度限制为 340 pt，让完整 skeleton 与其余样本同屏；重新执行 lint/build 和两台覆盖安装，生产代码未再变更，未重复 Unit。

## 图片样本来源

下面均为用户提供的 Android-target 截图，不是账号接口响应。仅提取图片区域，RGB、最长边 192、JPEG quality 78，Base64 编码在 Debug 源码中；Gallery 等级和统计是明确的本地展示值，不流入 Live。原截图从未修改。

| key | 源截图 | 原图像素矩形 (left, top, right, bottom) |
|---|---|---|
| user | 05-forum-home.png | 42,1574,135,1668 |
| forum | 01-home-recent-followed.png | 41,774,146,879 |
| media1 | 02-dynamic-feed.png | 42,1355,320,1625 |
| media2 | 02-dynamic-feed.png | 330,1355,610,1625 |
| media3 | 02-dynamic-feed.png | 620,1355,896,1625 |

media3 内可见的“15”属于源截图像素，不是组件计数或新业务字段。Gallery 重复三个样本来验证 1–8 布局，不生成虚假的远端图片记录。

## 人工入口与限制

iPhone 17 Pro (`70D93841-1FEB-445A-8FAD-B1C29B981D5D`)：设置→组件画廊→Android parity · R01；iPad Pro 13-inch M5 (`EE89FBE1-9DCA-49DC-8432-8A9C856A28FF`)：侧栏设置→组件画廊。安装的是 `.build/DerivedData/Build/Products/Debug-iphonesimulator/TiebaLite.app`，bundle ID `dev.local.tiebaliteios`。iPhone 既有登录态仍显示已登录；iPad 未登录，没有复制 Keychain。

截图：`iphone-gallery.png`、`ipad-gallery.png`。两张均同时展示用户头像成功/加载/失败、用户等级 1/8/14/18、吧图/热度/成员/吧等级、1–8 图布局及完整平面 feed row skeleton。iPhone 原截图的 skeleton 底部遮挡已通过上述 Debug 总览尺寸调整解决并重新截图。2026-09-05 截图交付时两台均停在 Gallery；原宽 1–8 图样本在总览下方。2026-09-23 重新启动 iPhone 并打开 Gallery，用户确认视觉通过；本次仅更新验收文档，没有改代码或重跑测试。

UNKNOWN：裸 portrait 的安全 HTTPS 合成仍未证实；当前仅消费 API 已返回的 HTTPS 头像。Gallery 不证明 Live avatar CDN 运行成功。iOS 18/真机、完整 VoiceOver 和大字体/深色运行矩阵未执行；新组件使用 ScaledMetric/语义中性色，颜色转换遵循 Android 源码，不能把静态支持说成已通过完整矩阵。

R01 用户视觉验收已通过。保留不提交、不自动进入 R02 的边界，等待用户另行指令。
