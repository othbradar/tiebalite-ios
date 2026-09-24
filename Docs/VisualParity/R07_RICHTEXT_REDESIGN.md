# R07 富文本交互最小重设计方案

状态：用户已明确批准；已按实际点击/自动化对照完成条件分支，2026-09-23。

本次实际点击 A/B/C 及原样例均正常，native/AX链接frame一致。失败根因定位为 XCTest 在 UIKit action handler 执行前立即断言；按用户要求保留正常原生交互，只修可观察回调同步及验收页定位/无障碍容器。没有强行执行下方原先设想的 Coordinator 替换。原用例、准确意图计数、复制/滚动/复用、18 Unit 和 iPad短检查通过；完整 R07 Live 候选已覆盖安装，等待用户查看。详见 R07_ACCEPTANCE.md 本次续作章节。

以下保留获批前方案和历史证据；“原生CUA未观察到回调”是前次观察，已被本次四个实际单击样例纠正。

## 已证实的边界

R06绿色基线为d1819c7。R07的51个官方静态资源可由UIKit本地解码；parser、wire节点顺序、附件尺寸/基线、复制替代文本、长文换行、相同输入附件复用及选区保留共18项定向测试通过。

独立renderer固定样本在iPhone 17 Pro/iOS26.5中，链接存在、可定位，三次XCTest.tap后均未收到应用回调。诊断轨迹为U→UP→UP→UPP（U=apply，P=primaryActionFor，A=action handler，M=menu configuration）。没有A或M，也没有重复U，因此不能归因为反复更新/重建或找不到链接意图；图片显示正常。截图显示点击最后进入文本选择。原生CUA点击也未观察到回调。根因仅缩小至UIKit链接交互/命中到动作派发之间，尚未证实系统缺陷或具体某一delegate规则。

两个已撤回的修正尝试：给UIAction保留defaultAction.title；将link属性的字符串改为URL对象。两者均未改变失败。不会保留这两项作为“修复”，也不以延时、重复点击、扩大命中层或降低断言掩盖。

## 新组件职责与生命周期

- Core parser与已证实资源映射保留为不可变输入，不读取网络，不改Proto/Store。资源按原WebP和SHA保持可复用。
- TiebaRichTextView仍为唯一富文本入口。重建其UIKit适配边界：稳定Coordinator拥有链接意图/回调；UITextView仅负责文字、附件、选择和复制，不同时作为自己的delegate及动作所有者。UIViewRepresentable update只替换发生变化的文本/字体及当前回调，不重建native view。
- NSTextAttachment原文替代与朗读语义分开。先检验whole-view accessibilityLabel替换附件为多字朗读文本是否改变AX link range/rect：比较原始UTF-16范围、UITextInput.firstRect、AX链接frame与实际tap坐标。此处是INFERENCE，不能当已证实根因。应保留原始文字索引，采用附件/链接的局部无障碍语义，而非改变整段字符串后假定链接索引不变。
- 动作只有在UIKit确认激活时交给Coordinator；查询可访问性、候选动作生成、长按选择和滚动不得触发导航。继续传递已有ExternalLinkIntent及稳定sourceNodeID，不让原始URL绕过已有验证。
- 所有测量按实际提议宽度进行，原高度/选区/附件复用检查保留。仍是单个不滚动文本视图；楼层的VirtualizedList和业务ID完全不动。

## 最小验证与退出条件

先建立同一隔离页上的两种内容：纯文字链接，以及前置表情+链接+@；共用同一原始tap操作与callback断言。记录delegate、动作派发、选区、文字范围和命中frame，排除AX坐标与touch派发的差异。只有证据定位后才完成重设计；若仍不能可靠激活，保留失败并停止，不增添自定义全局手势。

通过后恢复原R07短Smoke的正常字号/大字号/深色截图；验证连续三次独立激活分别只回调一次，以及从链接上滚动不导航。再跑现有18项定向Unit、lint/build/diff，仅做iPad对应组件短检查。最终覆盖安装完整Live应用、保留账号；不以独立Fixture替代用户验收，不提交R07，不进入R08。

候选代码、映射/资源和测试保存在Artifacts/VisualReview/R07/Candidate/；tracked diff在r07-candidate-tracked.patch，完整原始日志/xcresult同目录。应用源已恢复R06，不把未通过候选留作生产实现。
