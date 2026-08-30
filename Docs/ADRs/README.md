# Architecture Decision Records

从 `Specs/10_DECISION_LOG_TEMPLATE.md` 复制创建。阶段 02 已建立：

| ADR | 状态 |
|---|---|
| `ADR-0001-project-generation.md` | Accepted |
| `ADR-0002-feature-state-and-dependency-injection.md` | Accepted |
| `ADR-0003-navigation-and-ipad.md` | Accepted |
| `ADR-0004-pager-container.md` | Proposed，等待阶段 06 spike |
| `ADR-0005-media-viewer.md` | Proposed，等待阶段 06 spike |
| `ADR-0006-networking-and-protobuf.md` | Accepted，live endpoint 仍受 evidence gate |
| `ADR-0007-session-and-login.md` | Proposed，发布级 Session/journal/ledger 模型；阶段 12 Beta 子集见 ADR-0014 |
| `ADR-0008-cache-and-images.md` | Accepted，disk/decoded cache 仍需证据 |
| `ADR-0009-testing-and-launch-scenarios.md` | Accepted |
| `ADR-0010-observability-and-privacy.md` | Accepted |
| `ADR-0011-local-protobuf-source-and-swiftprotobuf-lock.md` | Accepted，本地/个人/非商业范围；公开分发仍阻塞 |
| `ADR-0012-thread-content-protobuf-adapter.md` | Accepted，精确增加阶段 08 Core mapper；不扩 Proto 闭包/分发范围 |
| `ADR-0013-pbpage-protobuf-and-live-reading.md` | Accepted，联合锁定 PBPage 闭包与唯一 Live Reading adapter；公开分发仍阻塞 |
| `ADR-0014-wkwebview-session-beta.md` | Accepted，阶段 12 可见 WKWebView、最小 Keychain 与 lease-aware AuthContext；发布级恢复仍延期 |
| `ADR-0015-followed-forums-protobuf-candidate.md` | Accepted，阶段 13 关注吧 HTTPS Proto 候选、最小会话子集与 136-file 闭包 |
| `ADR-0016-frs-forum-home.md` | Accepted，阶段 14 匿名 FRS 首屏、Forum identity/Repository 边界与 156-file 闭包 |
| `ADR-0017-pbpage-read-only-pagination-beta.md` | Accepted，阶段 15 匿名 PBPage 首屏/顺序下一页、楼中楼预览与保留内容分页 |
| `ADR-0018-thread-reader-table-virtualization-beta.md` | Accepted，阶段 15 唯一 UITableView/diffable/UIHostingConfiguration 长帖承载层 |
| `ADR-0019-core-live-pagination-beta.md` | Accepted，阶段 15.6 取代 PBPage 两页硬帽，并启用证据范围内的 Personalized 顺序分页 |
| `ADR-0020-hybrid-search-and-navigation-beta.md` | Accepted，阶段 16A 匿名 Hybrid JSON 搜吧/搜帖、搜帖顺序分页与普通 Search route |
| `ADR-0021-history-settings-user-profile.md` | Accepted，阶段 16B 本地历史、真实主题/阅读设置、Profile Proto 白名单与 Settings/UserProfile route |

Accepted ADR 是实现约束；变更必须新建 superseding ADR，不能静默改历史。
