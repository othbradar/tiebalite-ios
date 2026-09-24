# R10 表情输入区域最小承载修订提案

状态：USER_VISUALLY_APPROVED（2026-09-24）。用户确认图片和表情均正常并授权提交 R10；最小原生输入区域已实施，定向回归通过，完整登录 App 的图片加表情主题回复已由用户手动验证。不进入 R11。

用户反馈：笑眼等选入正文仍显示 token；表情面板右侧空白、滚动内容覆盖工具栏和字数栏，首次或再次打开时位置异常。

## 已确认与未确认

- 编辑框实际是纯文本 UITextView，下方另建只读预览。正文没有附件；不是笑眼资源缺失。真实 UIKit host 回归三次均测得 0 个附件，内联适配后三次均测得 3 个（含笑眼/滑稽/捂嘴笑）。发送仍保存原 token，未知表情保留原文。
- 原面板 UI 回归三次均失败：402pt 视口实际 x=-91.33、y=708.67，覆盖工具栏（底边780.67）和字数栏（顶边809.67）；截图也呈现错位，非仅 XCTest 命中问题。
- 第一修正给 ScrollView 明确宽高和裁剪，原回归仍三次失败。第二修正把底部区域独立放入 safeAreaInset 并保留面板实例，首次打开仍错误，且隐藏后 AX 残留。两次失败方案均已保存到 Artifacts/VisualReview/R10/EditorRevision；停止继续叠加参数，并撤销两次面板布局修改。
- 目前能确认的是：键盘/面板切换时，SwiftUI 底部区域所占空间与其内部实际滚动区域的位置不一致。不能由这些证据断言具体 UIKit/SwiftUI 系统缺陷，也不把增加宽度当作已修复。

## 最小方案

让现有单个可编辑 UITextView 使用公开 inputView / reloadInputViews 管理输入区域：系统键盘与官方表情面板作为同一个输入槽的两个模式，切换保持 first responder 与当前选区；不再在正文 VStack 中动态插入第二个输入区域。

表情面板继续复用当前目录、资源和 48pt 自适应网格，由一个 UIInputView 内的 UIHostingController 持有。编辑器将所属 UIWindow 的实际宽度交给原生输入视图（包含 iPad sheet 的键盘区域），尺寸变化只在宽度确实改变时更新，不依赖 UIScreen、机型或补偿 offset；原生容器提供固定面板高度及边界裁剪；约束贴齐容器四边，不读取设备屏幕尺寸、不设置补偿 offset。Coordinator 更新插入回调和当前模式，teardown 清理自身 host/controller 引用。图片栏和状态栏保持原样，只删除原表情面板的重复承载。

限定文件：ComposerTextEditor、ComposerMediaControls、TextComposerView，以及必要的当前编辑器局部容器文件、定向测试和本阶段文档。保留已实现的内联附件/UTF-16 映射/复制 token；不改资源系统、发送 Store/Repository、图片上传/缓存、Session、列表、导航、Pager 或 MediaViewer。

## 验收

原开合回归的几何断言保留：面板与正文同宽且 x 一致；位于工具栏下方、不覆盖字数；三次键盘/表情切换和滚动。补足原生输入槽后，按真实界面层级调整底部栏在键盘上方的预期，不能降低“不重叠”要求。

笑眼及其他表情在正文内显示；光标插入、连续同表情、删除、选择复制/粘贴与 wire token 一致。保留原 1/4/5 图、删除中间图、Mock 上传失败重试短回归。iPad 横竖屏一次。只跑相关 Unit/UI、lint/build/secret/diff；完整正常 Live 覆盖安装，不卸载/清 Keychain，零自动上传/发送，用户手动验收后才可宣布通过。

## 本次实施与实际验证（2026-09-24）

删除正文 VStack 中的独立表情面板；Coordinator 持有同一个局部输入控制器，当前回调通过 parent 更新，只有模式变化才 reloadInputViews。UITextView 保持 first responder、内容和选区；disabled 状态拒绝插入，teardown 清理 host 和回调。宿主排除自身键盘避让，只保留 container safe area。没有修改共享列表、导航、Store、图片系统或 Session。

接入期间多次短 UI 曾失败，不能由 Unit 通过推断可用：最初输入控制器覆盖、固定高度、直接赋值 inputView、宿主 safeAreaRegions 均未单独解决。实际动态诊断证明输入视图和 HostingScrollView 已挂在窗口，但宽度为0，外层键盘区域宽402；此前 updateUIView 中的 attached=false 是切换瞬间快照，不能作为持续未挂载的证据。flexibleWidth 和关闭 allowsSelfSizing 亦未单独解决，故不认定 self-sizing 是唯一根因。最终由编辑器提供实际所属窗口宽度，并在 layoutSubviews 仅宽度变化时同步，原三轮开合/滚动几何回归才转绿。原零宽网格无法自行推出键盘视口宽度，是此适配层的确定性问题；不声称 UIKit 本身有缺陷。

NativeInput/scene-width.xcresult：iPhone 2/2（54.420s），包含三次开合/滚动、完整1/4/5图/删中间/笑眼滑稽呵呵内联/Mock上传失败保留与重试。NativeInput/ipad-final.xcresult：iPad 1/1（20.755s），实际全窗口输入宽度、横竖屏、四图与文字/表情草稿保持、不覆盖状态栏。Unit 验证单控制器复用、窗口尺寸变化、当前回调、选区、复制/删除与原 token。诊断无障碍文本已移除。
