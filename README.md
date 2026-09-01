# TiebaLite iOS

TiebaLite iOS 是一个非官方、只读的 iOS/iPadOS 贴吧客户端。本仓库当前状态为
本地 Beta Release Candidate：核心阅读链路已实现并通过 Simulator 自动化与
人工 smoke，但没有获得百度官方认可，也不代表已经具备 App Store、公开或商业
分发授权。

## 已实现

- 用户可见的 WKWebView 登录、Keychain 会话保存和重启恢复；
- 推荐流、关注的吧、吧首页和连续分页；
- 帖子首楼、普通楼层、内联楼中楼预览和连续分页；
- 生产图片加载、唯一 MediaViewer、多图切换、缩放、平移与旋转；
- 贴吧/帖子搜索及已证实的帖子搜索分页；
- 本地浏览历史、外观/阅读字号设置和基础用户资料；
- iPhone/iPad 自适应布局、深色模式、大字体与 Reduce Motion；
- Fixture 驱动的 Unit/UI 自动化、离线失败与重试场景。

项目刻意不实现签到、发帖、回复/发布评论、点赞、删除、私信、推送和离线下载。
完整楼中楼独立页面也不在当前 Beta 范围内。

## 系统与工具要求

- macOS 26；
- Xcode 26.6（Swift 6.3.3 工具链，工程使用 Swift 6 language mode）；
- iOS/iPadOS 18.0 或更高；
- XcodeGen 2.45.4、SwiftLint 0.65.0、xcbeautify 3.2.1；
- `protoc` / `protoc-gen-swift` 35.1 / 1.38.1；
- Java 与 Javac 21.0.10（仅用于确定性生成合成 Proto fixture）。

`Config/ToolVersions.env` 是版本真相来源。`Brewfile` 安装 Homebrew 管理的工具，
Java 21.0.10 需由开发者单独安装并确保 `java`、`javac` 位于 `PATH`。

## 从干净 checkout 构建

```bash
git submodule update --init --recursive
cp scripts/project.env.example scripts/project.env
make bootstrap-tools
make doctor
make generate
make build
```

`scripts/project.env` 被 Git 忽略；默认模板不包含秘密，Simulator UDID 留空时会
自动选择可用设备。构建和测试不需要真实账号、Cookie、Keychain 数据或私有响应。
生成的 `TiebaLite.xcodeproj`、DerivedData 与测试结果也不会进入 Git。

要验证 Release：

```bash
make release-build
make release-isolation
```

`project.yml`、`Config/*.xcconfig`、`Config/SwiftPM/Package.resolved` 和测试计划
是工程声明的真相来源，不应手工提交生成的 `.xcodeproj`。

## Live 与 Fixture 边界

Production composition 固定使用 Live Repository、URLSession、Keychain 和
`ProductionImageLoader`，不会静默降级到 Fixture。Debug/UITesting 构建保留
固定 Fixture 与 Mock transport，用于离线演示、确定性测试和接口失效排查；
纯 Fixture Repository、LaunchScenario、Probe、Renderer/Pager/Media Lab 和
1000 条实验入口均从 Release 源与资源中排除。

贴吧接口为私有协议，可能随服务端变化。自动化测试不访问实时贴吧服务器；Live
证据只记录状态码、MIME、响应大小、解码结果、映射数量和 typed error，不保存
完整请求/响应或真实用户内容。

## 登录与隐私边界

- 用户只在可见 WKWebView 中手工输入账号、密码和验证码；App 不读取或保存明文
  密码。
- 运行所需的 BDUSS/STOKEN 仅保存于本 App 的 Keychain；不会写入日志、fixture、
  文档或 Git。
- 浏览历史保存在 App 沙盒内的本地 JSON，设置保存在 UserDefaults。
- 需要授权的 API 仅在有效会话 lease 下发送；图片 CDN 请求使用独立匿名会话，
  不携带登录 Cookie。
- 项目没有第三方分析 SDK；诊断日志只记录脱敏的类型和计数。

## 测试

```bash
make test-unit
make quality-fast
make release-isolation
make quality
```

`make quality` 是当前完整 RC 门禁，包含 Debug/Release 构建、Unit、iPhone/iPad
UI smoke、Pager/Media interaction、静态策略、秘密扫描和 Release 隔离。

## Known Limitations

- 这是非官方客户端，贴吧私有 API、字段和错误码可能变化；所有服务端错误码尚未
  覆盖。
- 当前没有可证实的安全 HTTPS 头像合成规则，作者、用户和吧头像继续使用统一
  占位。
- 动图只保证显示可用静态帧；没有 GIF 动画框架、视频、全尺寸图片瓦片、复杂
  image lease 或跨 View in-flight 请求合并。
- 真机完整 VoiceOver、iOS 18.x runtime、完整设备/Stage Manager 矩阵尚未验证。
- logout 实现有确定性测试，但为保留当前会话，本轮未执行真实 logout。
- App Store、商标、服务条款、Proto 文件级来源以及公开/商业分发权利尚未完成
  独立确认。

这些限制不阻塞本地 Beta RC，但阻塞任何“App Store ready”“生产认证”或商业
分发声明。

## 许可与来源

根 [LICENSE](LICENSE) 当前明确记录“尚未授予项目级使用或分发许可”；源代码
可见不等于已获得开源许可。第三方依赖、Android reference 与生成 Proto 的精确
来源和边界见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) 与
[来源审计](Docs/Audits/SOURCE_AND_LICENSE_NOTES.md)。
