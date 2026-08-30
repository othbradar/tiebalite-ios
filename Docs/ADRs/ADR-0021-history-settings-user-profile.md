# ADR-0021：浏览历史、真实设置与用户资料的 Beta 边界

- 状态：Accepted
- 日期：2026-08-30
- 决策者：阶段 16B“浏览历史、设置和基础用户资料”
- 关联阶段：16A、16B、17
- Extends：ADR-0002、ADR-0003、ADR-0006 和 ADR-0011；
  只取代 ADR-0003 中“Settings 是静态占位且 settingsPath 最多一项”的历史限制

## 背景

阶段 16B 需要在不改动已验证的虚拟列表、Pager、MediaViewer
和 Renderer 核心结构的前提下，增加可持久化的浏览历史、真正生效的
外观/阅读设置以及从 ThreadReader 作者打开的基础用户资料。

锁定 Android reference 的用户资料主链使用 V12 HTTPS Protobuf
`ProfileRequest/ProfileResponse`，但 `User` schema 同时含有不得进入领域或
日志的 credential-like 字段，因此必须在 mapper 边界做显式白名单。

## 决策

1. 浏览历史只保存 thread/forum/user 的稳定业务 ID、标题/名称、
   路由所需最小非敏感字段、`visitedAt` 和访问次数。同一 identity
   再次访问移到首位，默认上限 500，不保存正文、URL、Cookie、
   credential 或完整响应。
2. Production 历史使用 actor 隔离的 Codable JSON envelope，写入
   Application Support/TiebaLite 并使用原子替换。Fixture/UI Testing
   使用独立内存 Repository，不读 production 文件。只在页面已成功展示
   领域数据后记录；失败/取消不记录。
3. 设置快照只含外观 `system/light/dark` 和阅读正文
   `small/standard/large`。Production 用命名 UserDefaults key，Fixture 用
   内存 Repository。`SettingsStore` 串行合并待保存快照，避免旧写入
   覆盖最新选择。
4. 外观在 `AppSceneRoot` 读取完成后通过唯一
   `preferredColorScheme` 投影；阅读字号通过 DesignSystem 的
   `threadContentFont` 令牌进入现有 ThreadContentRenderer 文字节点。
   不覆盖 Dynamic Type 或 Reduce Motion。
5. `UserProfileRoute` 仅以正 `userID` 作 Hashable identity；名称和 portrait
   只是降级展示数据。资料 Store 使用一个 Task + generation，新用户取消
   旧请求，取消不展示普通失败。
6. Live 资料只使用 Android 已证的
   `POST https://tiebac.baidu.com/c/u/user/profile?cmd=303012&format=protobuf`，
   anonymous V12 multipart `data` part。请求使用 `friend_uid`、
   `has_plist/is_from_usercenter/is_guest/need_post_count/page/pn/q_type/rn`
   和已锁定的 CommonRequest 非敏感字段；不伪造屏幕/设备 ID，
   不发送 BDUSS/STOKEN。
7. Profile mapper 仅白名单映射请求身份匹配的用户名、portrait、
   简介、性别、关注/粉丝、发言/主题、获赞和公开 Tieba ID。
   `User.BDUSS`、`passwd`、IP 类字段不进入领域、Fixture、日志或文档。
8. 阶段 16B 扩展现有 Settings stack：`history/about/licenses`，
   以及从 history 打开的 `content(RouteIdentity)`。它不创建新根 Tab、
   NavigationStack 或 full-screen presentation；iPhone/iPad 仍由现有 Shell
   投影。`settingsPath` 不持久化。
9. 用户资料输入使已锁定 Proto 联合闭包由 156 增到 207 个
   generated Swift 文件。生成仍从 pinned submodule 发生，不复制
   `.proto`；合成 Profile response fixture 不含真实用户数据。

## 后果与未知项

- 历史是单机本地 Beta 数据，没有云同步、数据库、跨设备或多账号分区。
- 简单头像暂使用统一占位，不建新图片 cache/downsample 系统。
- Profile 的匿名服务器接受性、字段长期稳定性、自己资料和完整
  error taxonomy 只能根据脱敏 Probe 证据标注，不从 Android 静态代码
  推导为运行成功。
- 若 Profile endpoint 失效，Production 显示 typed failure/retry，Fixture
  和作者 route 保留；不放宽 TLS/MIME、不吞解码错误、不读会话。

## 验收与回滚

- 重复访问、500 条驱逐、原子持久化、损坏文件清空恢复和 Fixture
  隔离有确定性测试。
- 外观和阅读字号有持久化与实际 UI/Renderer 证据。
- ThreadReader 作者 → 资料 → 历史和历史 → 原内容 route 在 iPhone/iPad
  Fixture smoke 中可导航。
- 若全局主题导致 Shell 重建/路由丢失，或历史写入阻塞主 actor，
  回滚阶段 16B 注入并保留领域/Fixture 契约，不改动虚拟列表或交互层。
