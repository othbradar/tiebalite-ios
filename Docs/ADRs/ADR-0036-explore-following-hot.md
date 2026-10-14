# ADR-0036 — U11 动态关注与热榜

- 2026-10-14；用户授权U11，基线e3e53b4。仅扩展动态根页面，保持推荐、发送、导航与列表实现。
- 复用唯一PagerContainer、RecommendationFeedRow/VirtualizedList；Pager仅新增默认空的retainedPageIDs可选参数，动态区保留最多三个已创建Host，避免非相邻标签切回丢失实际offset；不主动创建未访问页、不改转场/手势，移除ID或拆除时仍释放。首轮UI已复现未保留时第8条移到视口外（Y=933，列表底部865），红用例保留。三个稳定标签分别拥有Store、任务、游标和锚点，只在首次进入时加载。关注是关注用户动态，不是关注吧。已加载切回不重新加载；关系变化只失效关注页。
- 用户随后明确要求参考原版iOS，且确认入口就是现有动态中的关注/推荐/热榜。因此保留已建立的入口和推荐生产请求，仅把两个新增只读接口改为22.11.1原生Common、签名、IDL及HTTP封装，使用独立Runtime，不影响发送指标、账号准备或回执。原Android传输试验撤回，失败证据保留。
- 原生descriptor与IDL工厂确认userlike cmd309474、hotThreadList cmd309661、请求/响应字段；独立NativeExplore schema复用未改的NativeWrite Common，ThreadInfo显示字段经原生descriptor逐项校验后复用现有Mapper。关注只渲染实际threadList帖子及服务端游标；若只有尚未接入的page_data/feed_list，不误报空页。热榜只展示thread_info，不伪造后页、热度或排名。
- 原生完整页面调用者的业务参数选择、动态SDK环境尚无运行对照证据。当前follow_type=1/load_type=1或2、tab_id=1/tab_code=all沿用本轮已建立的查询，声明为当前应用选择，不宣称原版全部页面参数一致；SDK/Passport身份不伪造。原版多类型动态、话题榜/分类不在本轮帖子流范围。
- 新页缓存复用ContentPageCache，仅保存显示DTO与真实游标，按账号namespace/流/query隔离，60秒新鲜、7天硬过期；清缓存epoch/会话revision/请求代次拒绝迟到回填。过期首屏先展示，后台更新在现有安全提交边界、停止滑动且回顶部后应用；手动刷新保留旧内容直至安全提交。附近帖子仍复用U04两槽预载，不预创建离屏Cell。
- 只执行相关Unit、iPhone/iPad短UI及lint/build/secret/diff；两类Live只读少量请求。缺少运行证据必须标PARTIAL；不实发、关注、收藏或提交。
