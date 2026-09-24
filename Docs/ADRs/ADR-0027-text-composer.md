# ADR-0027：文字发帖与回复

状态：Accepted for implementation（2026-09-24 用户明确授权 R09）；Live 发布仍须用户手动完成。

R09 提示词授权新帖、回复主题、楼层和楼中楼，作为原只读范围的有限扩展。新增一个 Composer、一个 WriteRepository，复用现有网络执行器、授权租约与列表。没有点赞、删除、图片上传或表情面板。

编辑器由当前目的页用系统 sheet 展示，保留导航/列表实例。目标保存真实 forum/thread/parent/subpost/user ID；缺失时禁用发送。新帖标题遵循 Android 的 31 字限制且可留空。取消保留本次会话的目标草稿；草稿只在内存，进程结束不持久化，账号租约变化后不可读且清除。发送捕获不可变内容和当前租约，单一 in-flight；发送期间不允许取消关闭或改文。失败保留草稿，超时/取消/响应不明提示先检查目标页面，绝不自动重试。

数据层使用 Android 已证的 AddPost Protobuf 和 AddThread JSON，以及 loginFlow 的只读账户元数据（tbs/uid）；仅在用户点击发送后取元数据并再次核验租约。HTTPS、拒绝重定向、禁止自动重试，不仿造 Android 设备指纹/风控令牌，不输出正文或认证信息。缺失风控能力显示明确不支持；HTTPS 路径和最小字段的实际可用性为待人工 Live 验证项，不降级 HTTP。

成功必须有服务器 pid/tid，关闭编辑器后仅调用发起页面既有 reload/refresh，不制造乐观行。第一道门禁只检查四类编辑器和隔离 Mock 成败；AI 不点击 Live 发送。第二道门禁由用户另外决定和手动发布。无新依赖、动画、手势或共享列表变更。

iPad 初轮实际复核发现：portrait→landscape 切换 compact/regular 后，目的页本地 sheet 状态消失，编辑器连同键盘被关闭（5秒可观察等待仍不出现；截图/AX显示已回组件画廊）。因此仅把 R09 编辑会话和系统 sheet 的持有者放到已有稳定 AppSceneRoot 注入的 TextComposerService；Feature 仍只发当前目标和成功刷新回调。没有更改 AppShell 的布局投影、路由、导航树、Store、列表或 shared lifecycle。正在编辑的 Store 随 sheet 存活，转屏不依赖页面局部 @State。
