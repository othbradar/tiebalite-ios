# ADR 0038 — U13 帖内播放与有界动图

状态：已实施，用户于2026-10-15批准提交U13；已知验证边界保留。基线 de3b969；不涉及写入、上传或 Pager ownership。

- 用户修订（2026-10-15）：视频直接在帖子原海报位置播放，删除独立 sheet；系统 AVPlayerViewController 嵌入该位置。设置→阅读→视频播放提供“点击播放/自动播放”，默认点击播放，持久化复用 AppSettingsRepository。该修订覆盖 U13 原提示词“仅点击”的限制，以用户指定的原版 iOS 交互为依据，不声称逐像素复刻原版所有播放器控件。
- 视频和语音共享一个按节点 ID 管理的 AVPlayer，替换 owner 先停止前一项。自动模式仅登记主要可见视频（裁剪后至少占可展示区域的一半；高竖视频按可用视口计算），无 owner 时选一个；暂停/结束/失败仍占有当前槽位，不循环重放、不挤掉用户手动语音。离开可见范围/页面释放；后台停止并冻结当时可见候选，回前台不自行恢复声音。中断/拔耳机暂停；系统播放器暂停/重播同步至共享状态。
- UIKit 可见范围观察仅用于媒体资源生命周期：裁剪祖先与 window 相交；单一弱引用 display-link hub 观察已挂载媒体，不增加手势、不改变列表/分页。静态图片不注册。
- 正文沿用 UIHostingConfiguration 虚拟列表。该容器拒绝 UIViewControllerRepresentable（Live 日志及 320/600/1024 三宽度回归均复现），因此播放器使用 UIViewRepresentable 的 UIView 桥接，在实际响应链的 UIViewController 下按 addChild/didMove 挂载 AVPlayerViewController，移出窗口/销毁时成对解除 containment。未替换列表容器。
- GIF/WebP 用 ImageIO 探测真实多帧数据；编码资源至多 8 MiB、源帧至多 4 MP、至多 500 帧，播放帧最长边至多 1024。只保留当前帧与正在解码帧，不创建全帧 UIImage 数组。解码进入既有双 worker ImageDecodeExecutor。超限或不支持时明确静态降级。
- 复用原图片请求与缓存，编码字节计入 decoded cache cost。图片保存仍直接保存原始文件。减少动态效果默认静止，用户可以明确播放；不可见、非当前 Viewer 页、后台取消解码任务。
- Apple ImageIO WebP 帧时长：[WebPUnclampedDelayTime](https://developer.apple.com/documentation/imageio/kcgimagepropertywebpunclampeddelaytime)。[音频中断](https://developer.apple.com/documentation/AVFAudio/handling-audio-interruptions)。
- 覆盖：所有权切换/迟到事件、结束/非法进度、真实 GIF/WebP 帧、预算静态降级、原位播放/重试/离页/后台、自动播放设置持久化与暂停保留、原 Viewer 缩放返回。真实贴吧播放结果单独记录，不用 fixture 冒充。
- Live：用户提供的帖子 11090254635 已在正常 iPhone/iPad App 的正文原海报位置呈现实际视频帧，无独立 sheet。仅对实测支持 TLS 的 tb-video.bdstatic.com 原 HTTP URL 升级 scheme，原路径及查询不改。语音仅验证本地 AAC；真实贴吧语音资源格式与兼容性待样本确认。
- 已知限制：iPad 横竖屏跨越原有单栏/分栏容器时旧播放节点会销毁，手动模式需再次点播放；自动模式可按新节点可见性重新播放，不保证原播放时间连续。本阶段不重构导航所有权。
