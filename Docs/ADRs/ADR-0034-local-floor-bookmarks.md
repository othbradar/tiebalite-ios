# ADR-0034 — U10 本机帖子与楼层书签

- 日期：2026-10-12；基线 41b098013cda72d0c43484436ebffcbb80aa532f。
- 范围：U10 明确允许可靠 Live 写接口缺失时交付标注“本机书签”的能力。云端收藏仍未完成。本轮不重做发帖、回复、上传或账号准备，不将 Android 收藏写入直接称为 iOS 对齐。
- CODE_EVIDENCE：Android MixedTiebaApiImpl.threadStoreFlow 使用 rn 和 rn*page 的 offset；ThreadStorePage 点击使用 markPid。maxPid/postNo 用作最新回复提示，不是用户保存楼层。addStoreFlow 的 NewCollectDataBean 为 tid/pid/status=1，ThreadViewModel 仅 errorCode=0 才确认成功。旧 addStore 位置参数与 CollectDataBean(pid,tid,status,type) 顺序相反，不能直接照搬。新版 OfficialTiebaApi 依赖 Android common headers/params、stoken 和用户身份；当前缺少对应可靠 iOS 收藏调用证据。
- 模型：每个账号每个 threadID 一条，postID/楼层可选；重复保存更新位置，不混入历史。账号由已认证公开资料的稳定 ID 分区，异步操作绑定现有登录代次。登录变化立即取消任务/清空内存展示，旧结果不得发布到新账号。
- 持久化：独立 Application Support 目录内原子 JSON 文件，actor 执行磁盘操作；不属于临时内容或图片缓存，没有自动容量淘汰。写入成功后才更新内存；失败保留旧值并可重试。列表分批显示元数据，不预载正文。
- 入口：复用帖子更多菜单、现有楼层回复按钮的长按菜单、我的页同样式列表项。明确用“本机书签”命名，不加常驻说明栏。楼层目标使用 U09 一次性 pid 定位，优先于历史；找不到目标给出可重试/返回的失效提示，不假定位到其他楼层。
- 验证：添加/重复/取消、磁盘重开及清临时缓存、账号/旧任务隔离、写失败保留、目标优先/失效，iPhone/iPad 短 UI；只执行 COMMON 轻量门禁。无真实收藏写请求，正常用户数据不清理。云端同步 UNKNOWN，不进入 U11。
