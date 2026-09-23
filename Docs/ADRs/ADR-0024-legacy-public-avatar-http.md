# ADR-0024：Android 公开作者头像的有限 HTTP 兼容

- 状态：Accepted，用户明确授权（2026-09-23）
- 授权原文：允许对 `tb.himg.baidu.com/sys/portrait/item/` 使用原版 HTTP。
- 仅补充 ADR-0006/0008 对这一公开图片来源的限制；业务 API、登录和其他图片地址不扩展。

## 问题与证据

Android UI reference c5f1125 的 `StringUtil.getAvatarUrl` 将裸 portrait 拼接到 `http://tb.himg.baidu.com/sys/portrait/item/`，`FeedCard.UserHeader` 使用其结果。当前动态的真实响应仅有裸 portrait，iOS 的 HTTPS-only 描述符把它过滤成 nil，因而作者头像一直是占位。备用资料字段也没有完整 HTTPS 候选。旧域名直接改成 HTTPS 的实际请求失败，证书不覆盖该主机；详见 R04_AUTHOR_AVATAR。

## 决策与边界

1. 仅对既有真实用户 portrait 使用 Android 的原规则；完整有效 HTTPS 值保持原样，已经是 HTTPS 的地址失败时不降级。
2. HTTP 准入要求精确主机、无端口/userinfo/fragment、精确路径前缀 `/sys/portrait/item/`，末尾只能是非空 ASCII 字母/数字/点/下划线/连字符组成的单个标识，禁止 `.`/`..`、百分号转义和额外斜杠。可选原始 `t=数字` 查询保持原值，不拼造时间戳。
3. ATS 仅配置该精确域名、NSIncludesSubdomains=false，不设置全局任意加载、WebView 或媒体放行。ATS 本身只能按域名配置；路径范围由应用图片地址校验落实。图片传输为明文 HTTP，无法提供 TLS 的机密性与真实性，这是本次用户接受的有限兼容代价。
4. 继续使用 ProductionImageLoader、原匿名 URLSession、缓存键、解码、取消和复用生命周期，不创建第二套下载或缓存系统。图片请求不含 Cookie/Authorization，拒绝重定向，业务 HTTPClient 仍仅接受 HTTPS。
5. 不改列表承载、分页、路由、Session/Keychain 或当前账户资料，不改变业务 identity。不重试证书错误、不猜测新 CDN。

## 验证与回滚

先运行字段到头像资源的失败回归，再验证该资源经现有 Loader 的匿名请求、缓存命中，以及非法 host/path、userinfo/端口/fragment/转义的拒绝；验证最终 App 的 ATS 字典只含该域名。既有头像迟到/取消/Cell 复用和单个 R04 动态 Smoke 保留。Live 只通过正常 App 人工路径验证，自动化始终使用隔离 Fixture。

若旧头像服务不再可用，保持中性失败状态。回滚移除这一映射、HTTP 准入和单域 ATS 例外，不清缓存、Keychain 或用户数据。HTTPS 替代若将来获得源码/API 及运行证据，应以新的可审查修订取代本例外。
