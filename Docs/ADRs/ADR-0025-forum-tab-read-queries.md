# ADR-0025：R05 吧首页分类只读查询

状态：Accepted；R05 明确授权范围，普通分类匿名首屏/下一页运行验证通过。
日期：2026-09-23

## 决策

扩展 ADR-0016 的最小只读查询范围。最新 sort_type=0（回复）/1（发帖）；精华 sort_type=-1,is_good=1,cid=服务端 class_id（初始 0）。普通分类仅接受 nav_tab_info.tab 中 isGeneralTab=1 且 tabType=15 的真实条目，经 /c/f/frs/generalTabList?cmd=309622&format=protobuf 请求。pn 从 1 递增、rn=30、last_thread_id 来自响应 general_list 最后一条原 id；不改 threadID 路由 identity。

每个页签使用独立的既有 Store 和请求代次，只有提交选择才首次加载；最新排序/精华筛选刷新自身，其他页内容和 anchor 保持。共享 Pager 负责横滑和控制器生命周期；共享 VirtualizedList 负责纵向复用和一次性 anchor 恢复。无新列表/手势/缓存。头部为固定紧凑结构，页签内部唯一纵向列表。

匿名请求沿用现有 HTTPClient/EndpointExecutor，不读取登录凭据。缺少用户等级/经验、签到状态时不展示。普通分类 schema 只从协议锁 5545326 新增 root 传递闭包，不切换 Android submodule，不扩展到 ThreadList 或写接口。若匿名精确查询不可用，保留 typed failure 和 Fixture，记录缺口，不猜替代请求。

## 候选与回滚

拒绝以本地筛选替代服务端分类（行为不同），拒绝每次选择销毁 Store（分页/返回位置丢失）。回滚仅撤回查询与 Forum 展示层，原 latest FRS 参数仍为默认；不清用户数据。

## 运行证据

2026-09-23，固定公开高通吧：最新排序 0/1、精华 0/真实 class_id 均返回 HTTP 200、application/octet-stream，各 13 条。nav_tab_info 筛选后 8 个普通分类，精华 6 chips。普通分类 page 1/2 均 HTTP 200、application/protobuf，各 30 条；精确 MIME 只增加到 GeneralTabProtocol，HTML 仍拒绝，FRS 白名单保持原样。所有请求 Cookie=false；个人等级缺省。日志只保留字节数、成功类型和计数，Probe 已移除。

该证据允许匿名排序/精华/普通分类生产入口；服务端末页、所有分类、限流和非公开吧仍不是已验证范围。既有依赖/Session/图片来源和安全策略不变。
