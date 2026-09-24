# ADR-0028：共用编辑器的本地图片与表情

状态：Accepted，USER_VISUALLY_APPROVED（2026-09-24，用户已验收并授权提交 R10）。

四类目标共享 R09 sheet、Store、写入 Repository。PhotosPicker 仅授权用户所选文件；后台 ImageIO 转为最长边2560的JPEG（质量0.95，超5MiB继续降尺寸），拒绝超过120MP/输入50MiB，无全尺寸批量解码。此保守内存上限是 iOS 适配；暂不提供原图开关。照片临时文件由不可变引用持有，随会话草稿释放删除，不落相册、不建第二套持久缓存。预览交由现有 ProductionImageLoader 共用解码与 NSCache，新增独立 local-file API，不把 file URL 放入网络候选。

发送：验证租约 → 依序分块上传（512000字节）→ 捕获真实服务器 picId/宽高 → 现有 TextWriteRepository。进度为服务端确认字节，失败保留全文和所有照片；重试复用本次目标已上传照片，不自动重发帖子。账号变化/取消后停止，忽略旧进度；失败后发送仅由用户再次主动点击。

初版采用正文 token + 下方只读预览，用户反馈不符合原版。2026-09-24修订为同一个 UITextView 内可编辑附件，复用 R07 parser/builder/资源，删除分离预览。实际 attributedText 的 UTF-16 附件范围映射到原始 wire token；中文/系统 emoji/连续同表情、光标插入、删除、复制粘贴由定向原生测试验证。marked text 不重新排版，普通字符不继承附件替代属性；文字和字体无变化不重设内容。无新框架、动画或依赖；照片删除控件只覆盖自身44pt按钮。

表情面板原 SwiftUI 承载两次局部布局修正失败后已撤销。用户明确批准最小原生输入槽方案：同一 UITextView 的 inputView 切换键盘/表情，局部 UIHostingController 复用既有网格，所属窗口提供实际宽度（含 iPad sheet），固定216pt高、裁剪。Coordinator 保持当前回调、选择与控制器身份；切换模式才 reloadInputViews，teardown 清理自身引用。定向 iPhone 三轮开合与 iPad 转屏已通过，完整记录见 `Docs/VisualParity/R10_EDITOR_LAYOUT_REDESIGN.md`；用户已完成最终视觉验收。

上传沿用既有 EndpointExecutor/HTTPClient/授权租约；HTTPS 拒绝重定向、无自动重试、Cookie仅ka=open，登录信息只在已证 API 表单中。原版设备标识不伪造。用户已在完整 Live App 手动完成一张图片加表情的主题回复，并提供第15楼已发布截图；这为当前 HTTPS 上传路径提供端到端用户证据，未采集原始响应。其他写入目标、多图实网发送和 Live 失败重试仍未单独验证。回滚限 Composer/上传新增代码，不影响 R09 纯文字路径。
