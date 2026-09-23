# ADR-0023：首页最近访问投影与公开吧图

- 状态：Accepted；R03 用户视觉验收通过（2026-09-23）
- 日期：2026-09-23
- 扩展 ADR-0021 的本地浏览历史展示元数据边界，不改变历史仓库或 schemaVersion。

## 决策与证据

Android UI reference c5f1125 的 HomePage 使用本地 History 的论坛条目（名称、avatar、forum ID），最近优先展示横向 24dp 吧图 chips；HomeViewModel 读取 HistoryUtil.TYPE_FORUM，并用 ForumGuide likeForum 的 avatar/hotNum/levelId 渲染关注行。

1. 复用既有 BrowsingHistoryRepository/BrowsingHistoryStore，增加 RecentForum 只读投影：只含有效 forum route、按 visitedAt 最近优先、业务 ID 去重、最多展示 20 条。底层历史仍沿用原 500 条上限、原子 JSON 和统一删除/清空。
2. schema-1 entry 增加可选 forumAvatarResourceID，只保存成功展示 ForumSummary 中通过现有图片描述符校验的公开 HTTPS 头像地址。旧文件缺字段仍可解码；重访缺图时保留上次有效图。原“历史不保存 URL”的限制仅对这一公开展示字段开放，不增加正文、媒体内容、凭据或网络请求。
3. 旧历史没有吧图时，允许用当前关注列表相同业务 ID 的已知头像补充展示；不合成 URL，不根据名称发额外请求。
4. 沿用 ForumHome 成功展示回调和既有路由 Store 生命周期：布局投影替换不重新记访问；真正退出路由后再次进入由既有 registry 新建 Store，成功展示才更新访问时间。失败/initialLoading 不产生条目。同一显示过程、图片完成和普通分页不重复记录。ForumHome 生产代码保持原样。
5. 首页只使用现有 VirtualizedList 承载稳定 recent/heading/status/forum 行；图片沿用 R01 组件和 ProductionImageLoader。页头变化只重配相应行，普通同步不重复恢复 anchor。

6. 首页搜索使用既有 RouteIdentity.search 和 scene SearchStore，只扩展 followedForums route grammar 准入；复用现有搜索结果链，两个 root 的导航路径独立。没有增加根入口或改写导航容器。

7. 用户追加要求修复 Android 正常显示的吧头像后，确认 Android 直接加载 API 完整 HTTP 图址；iOS 采用已运行验证的精确 CDN/path 范围 HTTPS 协议适配。域名、路径、查询保持原值，图片请求沿用 ProductionImageLoader，不新增网络栈、Cookie、ATS 例外或裸 portrait 合成。证据和拒绝边界见 API_EVIDENCE 的 R03 补充。关注行也可复用相同业务 ID 已成功访问留下的 HTTPS 图，图片来源变化进入行的 Equatable 值，稳定业务 ID 不变。

## 边界与 UNKNOWN

Session 只暴露登录状态及授权 lease，没有已证实的当前 userID/portrait；Android 账户头像来自 LocalAccount。R03 不猜 Cookie 字段、不新增未经追踪的“本人”接口，当前头像保持中性缺省。置顶/常用没有现有持久数据源，不生成分组。签到/取消关注等远端写入不接入；保留已有只读重新加载操作。

## 验证和回滚

定向 Unit 覆盖 schema-1 兼容、去重/上限/顺序、真实业务路由、HTTPS 地址、删除清空、重新显示记录、稳定行投影和热度格式。iPhone/iPad Fixture 验证成功访问、搜索、收起/展开、返回位置、深色与宽度变化。回滚可忽略新可选字段，不删历史、不清 Keychain、不变更共享承载。
