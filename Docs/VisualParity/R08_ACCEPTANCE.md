# R08 完整楼中楼阅读

状态：USER_VISUALLY_APPROVED。2026-09-24 用户明确“可以了，提交R08进入R09”，批准当前完整R08及表情修订。下方资源缺口及历史验证限制保留。

提交前复核：12项R08 Unit/4 suites、原iPhone短Smoke 1/1、make lint、make build、secret scan、git diff --check全部通过；日志与xcresult在Artifacts/VisualReview/R09/r08-approval-*。未运行完整quality或全部Unit。仅提交R08拥有的差异，保留用户Prompt/skill未跟踪文件，未推送。

## 楼中楼表情修订（2026-09-24）

用户反馈原文：“这个回复楼层里面的表情有些没有正常渲染（似乎有的表情会显示成[图片]这样的样式，有的还是正常的#(滑稽)这样的样式）有的表情正常渲染，别的倒是没啥问题”；补充：“除了滑稽还有别的表情没渲染不要只修这俩”。

根因：R07资源目录只注册image_emoticon族。本次匿名PbFloor三页30/30/17条返回另一族shoubai_emoji_face，mapper已正确保留type2/text/c，但本地registry解析失败，直接显示fallback，不是UIKit布局/复用问题。已把所有三页出现且原图可用的04/大笑、07/笑哭、60/赞同、71/滑稽、72/捂脸原PNG及真实名称加入同一目录；原127图保持不变，总132图399224字节。显式node保留实际资源ID，普通文本同名滑稽仍使用已验收的25。没有替换renderer、请求/Proto或图片加载系统。

明确缺口：shoubai_emoji_face_368/绝在Android源及已证实的官方web备用地址均404，保留可读原文，不能声明全部未来表情支持。另6处[图片]由服务端作为type0纯文本返回，没有相应图片地址/ID；不会凭文字猜测图片。证据仅保存公开表情字段/计数，不存完整响应、用户ID或凭据，见Emoticons/wire-page{1,2,3}.json及assets.json。下载失败（旧源368、备用源71/368的404）均保留为资源缺口，未绕过TLS；原图仅开发时获取，生产无CDN新请求、Cookie、ATS例外或第二缓存。

变更：TiebaEmoticonRegistry + 五个Resources/TiebaEmoticons原图；已有Debug目录计数改为动态；Fixture首回复加入全部五种真实type2格式；R08SubpostEmoticonTests/R07资源总数及原R08短Smoke增加覆盖；来源/协议/验收记录更新。列表、布局、Store、业务ID、线程正文/图片/Session等45个保护文件hash全部不变。没有新动画、手势、overlay或依赖。

验证：Emoticons/red.xcresult的新回归参数0/1/2连续三次失败，原11项表情测试通过；补目录后green.xcresult为18项/4suite通过（含132图逐一解码、全部目录名称、五种新type2、正常/大字体内联附件、复制原文、原link节点身份、普通话题和[图片]不误替换）。iPhone原R08完整短Smoke1/1通过（62.096秒），加入五种表情朗读/首屏截图，原分页/资料/返回断言未降低。lint先因格式化尾逗号失败、修正后对齐再次失败，最终lint-verified.log exit0；secret scan/diff通过。未跑完整quality、全部Unit或无关长交互。

修订前：Emoticons/iphone-before.png（用户截图）。修订后固定样本：Emoticons/phone-fixture-five-faces.png、ipad-fixture-five-faces.png，已分别目视确认全部五图内联。iPad原短Smoke1/1通过（56.823秒，含旋转和返回）。make build exit0。两台已覆盖安装正常Debug完整App并无参数启动，5张新增资源均在安装包中，二进制SHA均匹配35109570…；没有uninstall/erase/Keychain清除。iPhone已恢复完整关注列表并从历史打开同一真实帖子“又是首发高通，玄戒又成小丑了？”，当前首屏截图Emoticons/iphone-live-installed.png；CUA滚动未改变位置，第6楼和原反馈回复位置需用户手工打开，未把Fixture截图冒充Live修复后截图。上述为当前停留状态，下方初轮“6楼的回复”首屏是修订前历史。完整结果见Emoticons/revision-result.json。未暂存/提交，不进入R09。

## 范围与计划

新增Core SubpostsRoute/ReplyIntent、PbFloor协议/mapper/Live repository与独立Subposts Store/Presentation/View。App仅替换既有subposts占位目的页并注入依赖；用户资料作为有效子路径。使用现有VirtualizedList、ProductionImageLoader、ThreadContentRenderer，保留R07富文本及媒体意图。既有ThreadReader/ForumHome/Pager/MediaViewer/Session及业务身份不改。没有发布回复行为，不进入R09。

测试先定义30条两页（第二页含重叠）、失败/重试、取消迟到、身份校验；仅定向Unit和iPhone/iPad短Smoke，lint/build/secret/diff。最终覆盖安装正常完整Live应用、不卸载/清Keychain。

## Android证据

UI c5f1125f42498e49db4e4a9cb66313b8c8a285c7：SubPostsPage.kt/SubPostsViewModel.kt、ThreadPage.kt1173附近。标题“第N楼的回复”，原楼层PostCard(showSubPosts=false)、回复总数、16横8纵平面行、头像Small+8正文缩进、User.level_id及thread.author.id楼主标记；回复目标保留content的mention原顺序。无排序切换，builder is_comm_reverse=0；VM用current_page<total_page并请求下一pn。R08使用系统push替代Androidsheet，沿现有授权route。

协议仍用5545326b2a8e0d784b2f3dfbcb219c7b121e61c2，不更新submodule。四个PbFloor schema加入已有生成闭包，复用SubPostList/PbContent/Post/User；图片节点通过既有content renderer。目标截图目录没有独立subposts图，已读06-thread-reader.png中的头像/缩进/预览与对应源码，不伪称存在独立目标图。

运行取证：Artifacts/VisualReview/R08/public-floor-page1.json。匿名HTTPS请求（forum_id=0、省略设备几何）HTTP200/服务端0，父楼/主题匹配，13条唯一回复，page1/total1/total_count14，作者/等级13项，节点0/2/4。总数字段与实际13不相等，展示服务端总数，不推算虚假回复。只保留计数/状态元数据，没有正文、用户ID或凭据。Live多页尚未证明，固定30条两页承担分页验收。

## 已执行验证与修正

- R07提交前：11项Unit、iPhone原表情短Smoke1/1（20.422秒）、lint/build/secret/diff通过；R07提交4420ed0，未推送。
- R08 unit-initial：exit65，新Feature目录尚未加入XcodeGen目标，找不到SubpostsStore/View；新增精确目录后继续。
- unit-targeted：exit65，合成图片fixture将originSize误写为尺寸字符串；对照PbContent修成width/height，没有改协议字段。
- unit-check：9项/3suite通过；补充初始失败→重试空页后unit-final：10项/3suite全部通过（0.034秒）。包含匿名请求无Cookie/token、父楼/页身份、空/缺作者/未知内容、内联表情/@、图片intent、跨页去重、重试、取消迟到和子资料路由/Store保活。
- phone-initial：R08唯一完整Smoke通过，58.335秒。30条至少两页、边界ID唯一、头像作者入口到资料真实页面、返回回复位置<=12pt、回复意图只读提示、末页、返回原楼层位置<=12pt，再打开中部。
- ipad-initial：exit65，XCTest在尚未可见的复用Cell上查询isHittable，其AX frame为0×0导致activation-point错误（不是已证实生产点击失效）。改为先判断非零且在视口内的frame，再查命中；无扩大超时、无重复点击、原位置断言不变。
- ipad-check：同一完整Smoke1/1通过，54.713秒，包含横竖屏与原父楼返回。截图ipad-final-images包含实际资料/分页返回及横向三列；转屏截图导出有方向元数据/黑边，不将其作为精细像素对齐证据。正常竖屏中部图可直接对照。
- 初次lint只有多行参数对齐/尾逗号等格式问题；最终make lint：320文件0violations。iOS26新增刷新toolbar关闭系统共享玻璃背景；既有系统返回保持原样。
- 初次network isolation：未登记新增协议/mapper与生成的PbFloorResponseData COW Sendable，2项失败。按精确文件扩展原白名单及生成数量212→216/生成COW计数30→31后network-final为0failure；没有放宽手写并发/Feature import/网络隔离规则。
- make generate验证两次干净生成与tracked output逐字节一致；make build通过，secret scan、git diff --check通过。没有完整quality、全Unit或无关长矩阵。
- 最终文档检查曾误调用不存在的scripts/scan_secrets.sh（exit127）；改用仓库实际scripts/secret_scan.sh，扫描与diff check均exit0，暂存区为空。
- protected-check.json：41个共享列表/Pager/MediaViewer/图片/Session/ThreadReader/Forum文件hash全部不变。新增系统只读alert，仅点“回复”存在，关闭即清除目标；没有新手势、动画、依赖、overlay或缓存。

## 安装

两台simctl install正常Debug完整App并无参数launch；无uninstall/erase/Keychain清除。installed.json确认两台debug.dylib SHA与本次构建一致（26f16c08…）。iPhone完整App关注列表恢复，已从“我的→浏览历史”打开原真实帖子。CUA滚动/拖动未改变页面，Raise提示用户正在操作，未把工具尝试写成滚动成功。

后续读取实际窗口，用户已在另一真实高通吧帖子第6楼；点击“查看全部77条回复”后，成功进入“6楼的回复”，接口总数字段显示79。父楼、真实头像、等级、中文日期、蓝色回复对象均实际可见，截图iphone-live-top.png。预览数量77与完整接口79分别来自两个服务器字段，没有本地补造。Live未完成多页/中部的工具验证；30条两页、返回位置和资料返回采用隔离Fixture证据，不以首屏Live替代。当前页滚动/拖动工具仍未移动，已请求用户协助滑至中部。

截图目录：Artifacts/VisualReview/R08/。可直接对照iphone-live-top.png、iphone-fixture-top.png、iphone-fixture-middle.png及ipad-fixture-middle.png。iPad正常完整App已覆盖安装；其楼中楼分页/宽度与返回位置证据来自短Smoke。

人工门禁：当前iPhone保留完整Live“6楼的回复”首屏，请检查滑动、作者资料、返回原楼位置和表情排版。因CUA滑动没有产生可观察位置变化，未声称已停Live中部；本轮到此停止，不继续修改或追加回归。页面“回复”仅承接目标intent并显示只读提示，实际发布属于后续阶段。
