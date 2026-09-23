# R04 动态作者头像缺失

状态：USER_VISUALLY_APPROVED。作者头像转换缺口已修复，iPhone 正常 Live 动态首屏已显示两个真实作者头像。用户明确指出“动态作者头像没有”，并已明确允许对 `tb.himg.baidu.com/sys/portrait/item/` 使用原版 HTTP。本项不涉及本人资料、首页账户头像或 R12。

## 原因与本轮证据

- Android UI reference c5f1125 的 FeedCard.UserHeader 调用 StringUtil.getAvatarUrl(user.portrait)，裸标识转换成 `http://tb.himg.baidu.com/sys/portrait/item/<portrait>`。App.createSketch 使用独立图片 HTTP stack；AndroidManifest 允许明文图片。
- iOS 已映射真实 portrait，但 TiebaAvatarResource.user 直接把裸标识送入只接受完整 HTTPS 的 ImageResourceDescriptor，结果为 nil；TiebaAvatarView 展示中性缺省，根本没有发出该作者的图片请求。因此首要原因是缺失受支持的地址映射，不能笼统归为图片加载失败。
- 本轮临时只输出字段计数：三次当前响应分别包含 12、11、12 个作者，portraitHTTPS=0、highPresent=0、highHTTPS=0。两位作者通过已有匿名 Profile 接口复核，portrait/portraith 均有值但仍是裸标识，不能用备用字段解决动态行。
- 既有 R04 HTTPS 运行失败记录仍有效；本轮只读证书核查也看到旧主机所返回证书的 SAN 不包含 tb.himg.baidu.com。没有关闭证书校验。测试虚构标识的原 HTTP 地址返回 404、无重定向，不能声称其证明真实头像加载成功。
- 补查公开 `/f?kw=…` 页面获取完整 HTTPS 头像源的请求返回 HTTPError，没有获得可用证据。没有启用猜测域名或额外逐作者资料请求。
- 原始诊断日志仅有计数、字段存在性与 scheme/host 分类，在 Artifacts/VisualReview/R04/AuthorAvatar/；没有保存头像标识、真实用户 ID、Cookie 或完整响应。两个临时 probe 已从源码移除。

## 获批的最小兼容方案

原 ADR-0008 的约束是“只请求已验证 HTTPS URL”，ADR-0006 要求需要 HTTP 降级时回退 fixture。用户已接受这一公开头像的有限传输例外，记录于 ADR-0024。

1. 仅将 API 的有效裸 portrait 按原版规则映射到精确域名 tb.himg.baidu.com、精确路径族 /sys/portrait/item/。拒绝路径穿越、userinfo、端口、fragment 和不明 URL，完整 HTTPS 原值仍保持原样；不更换业务 ID。
2. ImageResourceDescriptor 仅增加这一头像来源的准入；不允许任意 HTTP 图片。ProductionImageLoader 继续复用其解码、缓存、取消和匿名 URLSession。实现复核发现直接构造 ImageRequest 能跳过描述符，因此在 Loader 的 URL 准入条件也复用同一校验，以保证 ATS 按域名放行后仍严格限制路径；Loader 只有这一行准入条件变更。
3. 通过工程声明添加只包含 tb.himg.baidu.com、无子域的 ATS 例外，不设置全局 NSAllowsArbitraryLoads。这一公开头像的传输是 HTTP，其余网络合同不变。图片仍无 Cookie/Authorization，重定向沿用拒绝策略。
4. 修改范围为 TiebaUserVisuals.swift、LegacyPortraitURL.swift、ImageLoading.swift、ProductionImageLoader 的准入条件、project.yml/生成的 Info 配置、隔离动态头像 Fixture、定向回归与证据/ADR。不改列表、导航、Session、Pager、MediaViewer 或其他页面。
5. 验证合成字段到请求的红绿测试，精确 host/path 边界、非法标识、无 Cookie、已有头像复用和单个动态 Smoke；lint/build/diff 后覆盖安装，确认真实头像显示，再交付用户验收。

有限 HTTP 兼容已获用户批准；修复后的实际验证尚需执行后记录。未暂存/提交，不进入下一阶段。

## 诊断清理与基线验证（授权前历史）

- field-probe-build.log、profile-probe-build.log、restored-build.log：三次 make build 均 exit 0；最后一次已移除全部临时诊断。
- restored-lint.log：make lint，274 个文件，0 violation。git diff --check 通过。
- baseline-unit.xcresult：iPad 目的地，8 个逻辑测试/16 次参数化执行通过，覆盖 R01 头像来源现有合同、迟到结果、取消、实际 Cell 复用及共用网格。方法级 ProductionImageLoader selector 选中 0 项，该匿名图片测试不计入本轮结果；其历史通过证据保留在 R04_ACCEPTANCE。
- 最后覆盖安装正常 Debug .app 到 iPhone/iPad，未卸载/erase/清 Keychain。CUA 切动态未成功，截图 restored-home.png 证实 iPhone 停在首页；不把尝试点击写成目标页面已到达。本轮没有外观修复，不能将该图作为作者头像通过证据。
- 尚无新实现可做修复后 Smoke/视觉验收；等待用户决定是否接受上述有限 HTTP 兼容。没有新增动画、手势、overlay 或依赖。

## 本轮获批修订

- avatar-red.xcresult：修改实现前 exit 65，4 个逻辑测试中 3 个失败/5 个断言问题。三种合法真实字段形态（全部为合成样本）的资源均为 nil，匿名加载回归因资源为 nil 失败，最终 App 缺少 ATS 字典；24 种未批准地址拒绝边界通过。
- R01 旧测试对所有裸标识一律为 nil 的断言按本轮授权改为精确原版地址；原有错误路径、userinfo、HTTPS 源和稳定资源 ID 断言保留。
- dynamic.parity 的头像改用明确的合成裸标识，仍通过隔离图片传输、既有 ProductionImageLoader 解码；Smoke 增加首行和多图行头像“已加载”的断言，原失败头像/分页/返回位置断言全部保留。Fixture 不进入 Live。

## 最终结果

- `avatar-green.xcresult` exit 0：40 个逻辑测试/80 次参数化执行、9 suites；包括裸 portrait 映射、24 个拒绝边界、ATS 配置、同一 Loader 的无 Cookie/Authorization 请求与缓存命中、R01 头像迟到/取消/实际 Cell 复用、R03 吧头像、Stage19 映射/复用及完整 ProductionImageLoader 套件。
- `avatar-final-unit.xcresult` exit 0：补充“已有 HTTPS 不降级/头像变化只改变图片缓存键”和“直接 ImageRequest 不能绕过 HTTP 路径限制”后，6 个逻辑测试/32 次执行通过。工程生成的 Info 版本显式沿用原 MARKETING_VERSION/CURRENT_PROJECT_VERSION，最终 App 仍为 0.1.0/build 1。
- `avatar-smoke.xcresult` exit 0：iPhone 原 R04 单个 Smoke 1/1，59.337s；新增两处裸 portrait 头像加载成功断言，原三图/8 图计数/失败头像/三页分页/帖子与 Tab 返回位置/回滚首行断言全部保留，未放宽超时或误差。附件在 fixture-screenshots/。
- `make generate` 两轮、`make lint`（avatar-lint.log）、`make build`（avatar-build.log）、`make secret-scan`、`git diff --check` 均 exit 0。未运行完整 Unit/quality/interaction 矩阵。开发期生成 Info 的默认版本曾为 1.0，交付前已在 project.yml 改回引用现有构建变量并重新生成/构建；没有交付版本号漂移。
- protected-final.json：44 个原受保护文件中，42 个 SHA-256 不变；两个变化仅为 ImageLoading/ProductionImageLoader 的已批准 HTTP 来源准入条件。缓存、解码、请求/取消生命周期、列表/导航/Store/Session 全部保持原样。
- 两台 Simulator 已覆盖安装正常 Debug .app，未卸载、erase、清 Keychain；当前 iPhone 保留登录态并停在含多图的 Live 动态首屏。`iphone-live-avatars-top.png` 与 `iphone-live-final.png` 可见足球和卡通两个真实作者头像、三图与双图布局，均为正常生产数据路径。没有临时 probe 或额外 Profile 请求。
- CUA 的 drag/scroll 再次没有改变可见位置，故本轮只确认 Live 首屏头像成功，不声称 Live 深滚动/第二页已人工通过。隔离 Fixture 的三页滚动/头像复用回归通过。该工具限制仍留给用户在 Simulator 手动复核。
- 无新增动画、手势、overlay、依赖或第二套图片系统。未暂存、未提交、未进入 R05；下一步仅等待用户视觉验收。
