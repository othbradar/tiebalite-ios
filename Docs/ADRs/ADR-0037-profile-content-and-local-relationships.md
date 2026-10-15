# ADR-0037 — U12 用户子列表与关系

- 2026-10-14，状态：2026-10-15 用户批准提交（USER_ACCEPTED）；基线 8731b3e3fce63517a0d0c8699feb5f58e4aed330。用户授权进入 U12，保留已验收外观及发送链路。
- 约束：复用资料页、ForumThreadFeedRow/HomeFollowedForumRow、VirtualizedList、现有 ThreadReader/书签定位；不新增 Pager、手势、动画、生产依赖或离屏 Cell。原基本资料/发送账号准备协议不迁移。
- 选择：三个独立子列表 Store/游标/缓存键；主题稳定 thread ID，自己的回复稳定 post ID（同帖多次回复不能去重成一条），关注吧稳定 forum ID。从用户页进入现有 route；回复目标复用已有书签定位组件及 ReadingPosition。只为含 profileList 的路径增加两个有界层级，其余导航深度不变。
- 新增请求参考用户的 iOS 22.11.1 包：TBCMyPostAndReplyModel 的 /c/u/feed/userpost、CMD303002、pn/rn/need_content/is_thread/is_view_card/last_thread_time；TBCPersonFavBarsModel 的 /c/f/forum/like、page_no/page_size/uid/friend_uid/is_guest；TBCPersonalInfoModel 的普通 profile/follow/unfollow。独立 Runtime 仅复用已核对 Common/签名/HTTP 工具，不使用 Android 请求或改动写 Runtime。NativeProfiles 转录最小 wire 字段，独立 SHA 锁；原 234 文件闭包不变，加三个 native schema 共 237。
- 关系状态从验证身份的 user.has_concerned 读取，缺失保持未知；关注目标 portrait 取本次服务端资料，不合成。仅用户点击写；单按钮和同账号同目标 Repository 都防重复，失败回滚，取消/账号变更拒绝迟到状态。成功仅失效对应用户缓存及同作用域 U11 关注，其他已打开资料下次重新读取关系。
- 本机屏蔽是本地能力，不称云端黑名单。按账号 namespace 在 Application Support 原子持久化；资料页的更多菜单提供管理/取消。原始页与服务器游标保留，Store/展示 Mapper 过滤动态、吧帖子、楼层及楼中楼；全页过滤时仍可继续分页。弱键读取版本只失效行配置缓存，不操作 offset、readAnchor 或阅读进度。清图片/内容缓存不删除屏蔽名单。
- 缓存复用 ContentPageCache/Scheduler，账号/UID/子列表/页/时间游标隔离，最多使用原有容量。进行中同键前台读复用，epoch/revision/账号变更拒绝回填。仅保存消费过的显示 DTO；服务器明确收紧权限后隐藏旧内容、定向失效对应缓存。
- 未选择：全局清缓存、复制 Reader/Pager、显示他人私有回复、用粉丝数猜关系、直接引用原版私有 SDK 身份。SDK/Passport 完整运行环境依然未对齐；当前基础列表/关系协议不等于整个官方个人中心或风控行为完全一致。
- 回滚条件：同账号分页链被破坏、UID 或权限混用、未点击发生远端写、默认未屏蔽时阅读/发送/视觉回归。不得通过删除用户数据或更新发送冻结摘要消除失败。

- 2026-10-15 关注吧回归：原数组实际元素类为 TBCBarDataItem，不是 TBCLikeForumItem。按 id/name/avatar/member_count/level_id 映射；普通/分组结构严格检查，非空页全部无法解析时报错，不伪装为空成功。复用行增加默认开启的 showsHotCount，只有此接口无热度字段的资料子页关闭，现有首页显示保持原值。
- 同日补充：用户要求可能隐藏关注吧时不显示加载失败。根据实测成功且无 forum_list/has_more 的结构新增 contentUnavailable，复用小号次级文字，不新增图标/按钮/布局。与确认为私有、正常空列表、真实错误分开；隐藏该用户旧行并失效既有作用域缓存，不改变请求/参数或追加探测。实际隐私原因仍 UNKNOWN。
