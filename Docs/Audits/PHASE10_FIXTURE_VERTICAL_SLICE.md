# 阶段 10 Fixture 主链路审计

状态：`PHASE_10_FIXTURE_VERTICAL_SLICE = COMPLETE`

范围标签：`OPEN_SOURCE_BETA` / `FIXTURE_ONLY` /
`PRODUCTION_LIVE_DISABLED` / `PHASE_11_NOT_STARTED`

## 范围与替换边界

阶段 10 建立可运行的本地主链路：推荐 Fixture 列表 → Fixture 帖子 → 阶段 09
唯一生产 MediaViewer → 关闭返回原帖子位置 → 系统返回原推荐位置。

- Core/Models 定义小型 `RecommendationRepository`、`ThreadReaderRepository`
  协议和 Sendable 领域值；Core/TiebaAPI 提供 12 条合成推荐与对应帖子实现。
- 推荐内容覆盖文字、单图、多图、长标题、无图和不同元数据；每篇帖子包含首楼
  与 3 个合成普通楼层，threadID、postID、node ordinal 和 MediaID 均稳定。
- `FixtureReadingImageLoader` 只按本地 resourceID 返回固定 PNG 或确定性失败，
  不解析候选 URL，也不发请求；`DisabledHTTPClient` 继续作为 production
  transport 边界。
- `RecommendationsView` 使用系统 ScrollView/NavigationStack projection 与
  DesignSystem；`ThreadReaderView` 复用阶段 08 的唯一
  `ThreadContentRenderer` 和 `ThreadMediaIntent`。
- scene-owned `AppFeatureStoreRegistry` 保留推荐 Store，并按 root/threadID
  复用当前帖子 Store；路由 pop 后清理离开缓存的帖子 Store。
- iPhone 继续使用现有系统 push；iPad 继续使用现有 split detail root/tail；
  MediaViewer 仍仅由 `AppSceneRoot` 的一个 `fullScreenCover` 呈现。

本阶段没有添加 live host/Cookie/凭据、分页、PBPage、完整楼层/楼中楼、评论、
登录、缓存大系统、第二套 Pager/MediaViewer、Feature 自有 fullScreenCover、
自定义 push、业务 DragGesture、overlay、任意动画参数或第三方依赖。

## 状态、身份与返回位置

推荐状态为 initial loading、loaded、empty、initial failure；帖子状态为 initial
loading、loaded、initial failure。两者只在主 actor 提交状态，按 generation
拒绝旧完成并保留取消可观察性，成功后重复 `loadIfNeeded` 不重复读取 Fixture。

只读复审发现 Repository 若返回错误 threadID，原 guard 会提前返回且不释放
active generation。新增回归先在
`20260803-223545-85300-unit.xcresult` 稳定失败；将 stale generation 与错误
threadID 分开处理后，错误响应归一为 failure、允许 retry，最终 Unit 转绿。

推荐行点击不写入“选中行即滚动中心”；可见锚点仅由双向 scroll position 记录。
MediaViewer presentation 不改变 App route，帖子 Store 与 View 身份保持；系统
返回后仍使用同一 scene 推荐 Store。没有 `.id(UUID())`、固定延迟或销毁整个
Renderer/导航树的状态修补。

## 行为先行与回归证据

- `20260803-220556-70408-unit.xcresult`：阶段 10 行为测试先于类型实现，因缺少
  Recommendation/ThreadReader 类型按预期编译失败；不计为通过。
- `20260803-223545-85300-unit.xcresult`：复审新增的错误 threadID 回归按预期
  失败；`20260803-223837-87279-unit.xcresult` 修复后完整 Unit 为 199 个逻辑
  测试、218 次执行，0 failed、0 skipped，其中阶段 10 新增 7 个逻辑测试。
- 阶段 10 Unit 覆盖 12 条 Fixture 的稳定身份与帖子解析、推荐成功/empty/失败、
  route 去重、正确 threadID、三图 MediaIntent 顺序、取消、错误 threadID、
  Store registry 复用与 pop 后 weak release。
- `20260803-222158-78394-ui-smoke.xcresult` 是实现期失败批次：新增 ScrollView
  identifier 未进入 XCUI 树，且启动标题被测试错误替换；修复可访问性容器并
  恢复旧标题断言后继续验证。
- `20260803-223912-88922-ui-smoke.xcresult` 的 16 项中 15 passed；唯一失败为
  帖子 ScrollView identifier 不可查询。测试改用真实可见帖子根容器合成滚动，
  未修改生产布局。
- `stage10-targeted-iphone-20260803.xcresult`：iPhone 主链路 1/1 通过，验证
  2/3→3/3→2/3 媒体顺序、Viewer 关闭、帖子位置与推荐位置基本保持。
- `20260803-225051-91305-ui-smoke-ipad.xcresult`：iPad App Shell 5/5 通过，
  包含阶段 10 主链路、既有两级 route projection、regular/compact、旋转、
  Renderer 与生产 MediaViewer 回归。

## 只读审查

三个只读子代理分别复核架构、UI/可访问性和范围/Git 边界。审查确认：

- 没有第二套 Pager、MediaViewer、业务 NavigationStack 或 fullScreenCover；
- iPhone push、iPad detail projection 与 App scene modal ownership 没有分叉；
- App registry 的 Store 身份稳定，pop 后 route Store 可释放；
- 未修改 `Sources/InteractionKit` 或 `Sources/Features/MediaViewer`；
- 没有 live 网络、UUID、asyncAfter、sleep、魔法 zIndex、透明 blocker 或敏感值；
- 旧 forum→thread/back、iPad detail tail 与 launch title 门禁已保留，没有用
  阶段 10 测试替换或降低既有断言。

## 最终质量门禁

阶段出口真实运行并通过：

- `make instructions`；
- `make lint`：126 个 Swift 文件，0 violation；
- `make test-unit`：199 个逻辑测试、218 次执行；
- iPhone 阶段 10 定向主链路：1/1；
- `make test-ui-smoke-ipad`：5/5；
- `make quality-fast`；
- `make quality`（App 根导航被修改，因此执行完整门禁）；
- `git diff --check`；
- Android submodule exact/clean
  `5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`。

最终 `make quality` exit 0 并输出 `Quality gate completed.`：

- Debug build：`20260803-230055-97462-build.log`；
- Unit：`20260803-230057-97495-unit.xcresult`，199 个逻辑测试、218 次执行；
- iPhone UI smoke：`20260803-230128-97781-ui-smoke.xcresult`，16/16；
- iPhone interaction：`20260803-231048-98813-ui-interaction.xcresult`，15/15；
- iPad build：`20260803-234250-1932-ipad-build.log`；
- iPad UI smoke：`20260803-234253-1987-ui-smoke-ipad.xcresult`，5/5；
- iPad interaction：`20260803-234642-2365-ui-interaction-ipad.xcresult`，2/2；
- Release build：`20260803-235554-3210-release-build.log`；
- Release isolation 与 UITesting isolation 均通过。

全部最终结果为 0 failed、0 skipped。沙箱内首次 Unit 因 SwiftPM/clang 标准
缓存无写权限 exit 74，获准使用 Xcode 正常缓存后通过；该权限失败不归因于
产品代码。

## 手工检查与 Known Limitations

按提示词尝试使用 Computer Use 检查 Simulator，但 Mac 处于登录锁屏状态且
自动解锁失败，因此 iPhone/iPad 手工观察均未执行；自动化结果没有被冒充为
手工通过。

1. 当前只使用合成 Fixture；没有 live 推荐、帖子或图片接口。
2. 没有分页、完整楼层、楼中楼或 live PBPage 映射。
3. 没有生产图片共享 cache、candidate 选择、下采样或 full-resolution lease。
4. 没有发布级系统版本、真机或真机 VoiceOver 矩阵；本轮 Simulator 人工视觉
   检查也因 Mac 锁屏未完成。
5. 合成普通楼层只验证 presentation，不是 Android PBPage wire 证据；live 推荐
   canonical thread identity 和普通楼层 wire 字段继续标为 `UNKNOWN`。
6. 当前 Fixture Repository 同步完成；未来接入真正 suspension 的 live
   Repository 前，需要补充旧 View task 取消清理与替代 task 启动之间的
   rendezvous。该序列在本阶段实际 Fixture 主链路不可稳定触发，不阻塞 Beta。

## 变更类型与停止点

- 新增动画：无。
- 新增手势：无；图片交互只复用阶段 09 生产 Pager/zoom/ownership。
- 新增 overlay：无；继续复用 AppSceneRoot 唯一 fullScreenCover。
- 新增依赖：无。
- live 网络：无。
- Android submodule 修改：无。

阶段 10 在 Fixture-only Open-Source Beta 范围完成。阶段 11 保持
`NOT_STARTED`，本任务结束后停止。
