# ADR-0030：吧首页页面缓存与阅读快照

- 状态：Accepted（用户授权 U02，实现等待视觉验收）
- 日期：2026-10-02
- 范围：吧首页内容；图片磁盘缓存仍按 ADR-0008，留待 U06。

## 问题与决策

现有 scene registry 只保留导航路径内的 ForumHomeStore；pop 会 cancel 并释放，重新进入需要网络首屏。扩大 registry 到无限保留 Store 会连带保留渲染状态，不能解决进程重启。采用 Repository 外的 CachedForumHomeRepository，保留 LiveForumHomeRepository 的协议和请求职责。无数据库及新依赖。

ContentPageCache 保存有界 Data；默认内存最多 30 条、16 MiB，包含页面及小型 manifest/别名；磁盘 Library/Caches/TiebaLiteContent-v1 为 128 MiB LRU。单条上限 4 MiB。独立 disk actor 原子写文件与小索引，坏文件按 miss 降级，孤立文件在启动准备时清理。JSON 编解码及文件访问不在 MainActor。预算不足是 cache miss，不限制网络继续分页。

持久 DTO 仅含领域内容、稳定 ID、页码/游标、hasMore、fetchedAt；manifest 为格式版本、快照代次、页键及稳定行锚点。路径全部为内部编码的 SHA-256；原文、URL、凭据不进入日志。每个 query/快照独立保存连续分页链，缺页时恢复完整前缀，再正常请求后页。

## 账号和有效期

账号键使用本机随机槽位，与 Cookie 值无关；正常会话恢复（包括凭据值变化后恢复）复用 UserDefaults 中的非敏感槽位，显式新登录更换槽位，匿名独立。退出/失效撤销旧槽位；失效状态不恢复内容缓存。运行时 revision 和 cache epoch 在 fetch、restore、save 前后核对，授权 lease 不序列化。旧账号文件无法经新账号键访问，继续受磁盘预算驱逐。

2026-10-02 用户修订：重进吧首页自动刷新新帖，删除“有新内容，点击更新”提示行。页面重建先显示缓存，无论 60 秒 freshness 都请求一次新首屏；同一 Store/查询的重复 synchronize 不触发额外请求。位于顶部则直接应用，深处阅读时静默暂存，滚回顶部时应用；明确下拉刷新直接请求网络并应用响应。自动更新失败不增加顶部提示，旧内容保持；手动刷新失败沿用现有错误状态。7 天后按 miss 清理；新首屏建立新分页链，旧后页不得拼接。Repository 通用读取仍保留 60 秒 freshness，吧首页 Store 显式请求更新。无需缓存格式迁移，回滚仅涉及 Store/View 的刷新策略。

## 生命周期与代价

2026-10-03 U06P2：ContentPageCache 的已验证内存命中直接返回，LRU 日期按 key 在内存合并（最多256项），单一维护 writer 约每秒批量提交；显式 flushMaintenance 提供无计时等待的 barrier。正文/manifest 写入仍 await 原子文件及索引完成，并在结构写入时吸收待处理的 LRU 日期；纯 miss（包括初次空目录查询）不写索引。维护是允许丢失的近似访问时间，阅读位置不是延后到进程退出才写的维护数据。clear 递增 epoch，旧批次检查 epoch 后才能修改索引，不改变磁盘格式、目录、容量或有效期。

吧首页在真正 fetch 到新页面时发布原 generation/page/cursor 键的正文；saveReading 通过缓存索引批量确认引用，随后只写小 manifest/锚点，别名不变不重写，不再逐页 read/touch/编码旧正文。未成功落盘的页不能生成新 manifest，预算驱逐/坏文件仍按既有恢复路径降为 cache miss。帖子 CachedReadingRepository 原本已只写小 manifest，本批保留其序列化及显式完成语义。计数与重启证据见 U06P2CacheFastPathTests 及 U03ReadingCacheTests。

页面完成、离开/后台时保存，滚动仅更新内存锚点；重建列表仅一次应用稳定行锚点，允许合理行内偏移差异。现有导航内 UIView 实例和 offset 不变。VirtualizedList 仅增加默认关闭的系统 UIRefreshControl 回调，未更换 diffable/复用/锚点算法；刷新去重，dismantle 取消并解绑。

冷命中仍有本地 IO 等待；本阶段没有离线图片持久化，也不承诺操作系统清理 Caches 后可离线读取。无缓存或持久化失败时正常网络路径仍可工作。

## 验证与退出条件

fake clock、临时目录和计数验证缓存即时恢复、每次重建一次复查、自动应用/深处延后、多页/锚点重建、排序/分类/账号隔离、错误保留、清理迟到结果、预算/坏文件；短 UI 验证返回第二页、换排序、系统下拉。实际结果以 TASK_STATE 为准。若缓存导致串账号/错页或滚动退化，移除 composition 的 adapter 即可回到网络路径，保留 U01 排序记忆；无需数据库迁移。
