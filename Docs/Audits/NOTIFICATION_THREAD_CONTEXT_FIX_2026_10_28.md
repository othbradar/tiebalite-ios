# 回复通知进入后缺正文与其他楼层 — 2026-10-28

## 范围与基线

- 用户目标：修复收到回复后点消息进入帖子只显示目标回复、普通入口也可能缺内容。当前HEAD `a5ad3eb98c4b78ac0aa7cf17635e480d526824ab`，保持工作树既有未跟踪资料；不提交、不推送。
- Xcode 26.6 (17F113)，复用 `.build/DerivedData-ThreadFluency` / `.build/SourcePackages`；原 iPhone 17 Pro 与 iPad Pro 13 M5 模拟器，未创建/删除设备。
- 仅通知定位、阅读缓存来源和旧数据恢复。无新增手势、动画、overlay、依赖；未改虚拟列表、图片、P01两步回复、发送/上传协议。

## 证据与根因

- CODE_EVIDENCE：NotificationDestinationStore在支持PID查询时直接locatePost；ThreadReaderNavigation把定位窗口当作完整目标页；CachedReadingRepository把pn=0/pid>0改记为返回页码，commit按responsePage替换普通页。PBPage mapper在lookup不补firstFloorPost。消息与吧首页Store独立，共享缓存使单条窗口污染普通入口。
- RUNTIME_EVIDENCE（确定性fixture）：第一页面本应1–15楼，原代码通知进入及重开均只有第7楼；晚页应16–28楼却只剩24楼。已预热整页被单条窗口覆盖，3次重复均失败。缺普通页失败场景也被误报成功。`red.xcresult`：4个测试函数、15个issue，exit65。
- UNKNOWN：本轮尚未抓取用户出错时的真实服务端响应；上述运行证据是合成窗口，不是Live抓包，也不宣称所有服务端PID响应都只有一条。

## 修复与状态边界

1. 定位窗口不写入普通页缓存；保留原调度合并、取消、账号和失效检查。
2. 位置确认后读取同页的普通页面，严格检查thread/page/target；旧普通页不含新回复时只刷新该页一次。不会因为目标缺失而定位到别的楼。晚页只取目标页，既有后续分页、回到首楼和跳页可用。
3. 新缓存记录保存可选已知来源标记，旧JSON兼容。恢复时记录需要确认的旧快照；用普通页替换，不清数据，失败保留旧显示和重试入口，取消后同Store可续修。待确认绑定原快照，防止把本会话新native回显误当旧窗口。
4. 原阅读位置仅在同页仍有原postID时重映射到新locator；不由预取创造新阅读进度。
5. native发送后方法和缓存合并方法正文与HEAD相同。新增“远页回复成功后冷重进不增加读取、不丢回执”测试；本轮没有代理真实发送。

## 执行记录

完整命令、日志、xcresult位于忽略目录 `Artifacts/VisualReview/NotificationThread-20261028/`。

| 检查 | 结果 | 证据 |
| --- | --- | --- |
| 原R11/U09/U03基线 | PASS：24项/3 suites，exit0 | baseline-command.json / baseline.xcresult |
| 单条窗口新增红测 | 预期FAIL：15个issue，exit65 | red-command.json / red.xcresult |
| 首次修复构建 | FAIL：新源文件尚未重新生成工程 | green-1.log；已XcodeGen重生成 |
| 第二次定向回归 | FAIL：U03普通游标被误判旧窗口，4个issue | green-2.xcresult；改为持久来源标记+仅恢复快照候选 |
| 收窄后的回归 | PASS：34项/4 suites | green-3.xcresult |
| 最终Unit及写后相邻回归 | PASS：49项/7 suites，exit0 | regression-command.json / regression.xcresult |
| iPhone通知UI | PASS：2项，引用/回复/回首楼循环3次，分页/楼中楼父楼/返回位置 | ui-iphone-command.json / ui-iphone.xcresult |
| iPad通知UI首轮 | 1项PASS；目标靠顶断言FAIL（3次），完整内容/回首楼/返回位置均通过 | ui-ipad.xcresult / ui-ipad-attachments |
| iPad实际滚动边界回归 | PASS：三次循环，目标正文完整可见、首楼可返回，靠顶或页尾精确对齐 | ui-ipad-alignment.xcresult |
| SwiftLint直接检查 | PASS：exit0 | swiftlint-3.log |
| 冻结基线 | 首次DRIFT；用户批准精确只读差异后23项PASS | write-baseline-approved.log / read-only-inverse-proof.json |
| secret-scan / diff check | PASS | secret-scan.log；git diff --check |
| make generate | FAIL：本机protoc35.1找不到旧abseil动态库 | generate.log |
| 直接XcodeGen +原SwiftPM锁 | PASS；未改Proto输入/产物 | xcodegen generate --spec project.yml --no-env；scripts/materialize_swiftpm_lock.sh |
| make quality-fast / make quality | FAIL：instructions扫描旧beta5归档产生AGENTS链长度超限 | quality-fast.log / quality.log |
| make forbidden | FAIL：已有5组source policy命中，新增文件无命中 | forbidden.log |

iPad首轮截图及AX几何确认：目标正文y=341，viewport y=118.5/h=1204.5，末尾加载更多Cell y=1256.5/h=66.5，与viewport底部1323严格相等。短页在高屏上已达最大滚动范围，旧固定180pt断言不适用。新断言仍要求精确目标正文完全可见，且仅允许靠顶或末Cell底部与viewport底部误差<=1pt；没有修改生产滚动代码。

SwiftLint中间还报嵌套、复杂度、600行上限附近增长等问题，已整理本次辅助方法后通过；未禁规则。全量quality未通过，不能将定向验证写成全仓绿灯；没有为通过门禁修改全局工具、删历史归档或降低断言。

## 交付与待验收

正常 Simulator Release build exit0（0.2.1/20，保留版本），签名验证通过。首次隔离脚本因project.env覆盖DERIVED_DATA_PATH读取错误目录而失败；仅将脚本副本的输出目录指向实际构建位置后完整隔离检查exit0，生产renderer/Pager/MediaViewer保留、test support/Debug排除，未改变检查规则。见live-build-command.json、live-build.log、release-isolation-current.log。

已在原iPhone/iPad执行simctl install覆盖，并无参数启动正常Live App；未卸载或清数据。安装迁移后容器UUID变化，iPhone先前6份本地草稿/书签内容SHA全部一致；iPad无对应本地文件，不将零文件校验当作数据保留证明。两台CUA均看到原账号头像、关注吧和最近浏览记录。见live-installation-proof.json。

iPhone正常Live手动只读验证：从真实回复通知打开目标父楼，确认后续第4–7楼等正文同时可读；两次向上滚动看到原帖标题和主楼正文；返回消息再通过引用打开同帖，仍显示主帖及第2楼正文/图片/楼中楼，未受到单条窗口污染。这里是成功后的Live UI证据，不是原错误响应抓包。iPad留在正常消息入口供用户继续验收。未代理点赞/发送，无测试启动参数或探针。

真实发生问题的那条新消息与物理设备最终体验仍需用户复核；未开始新阶段、未生成发布标签、未暂存/提交/推送。
