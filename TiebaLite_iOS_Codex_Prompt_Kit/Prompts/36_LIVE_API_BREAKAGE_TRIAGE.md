# Tieba Live API/登录突然失效的隔离排障

用于“之前能用、现在 live 请求失败/字段变了/登录失效”的情况。目标是把外部协议问题与 UI/状态回归隔离；不得因为 live 失败重写已验证的界面。

## 输入

```text
首次观察日期与 commit：
受影响能力：推荐/FRS/PB/关注吧/登录/图片/其他
HTTP/解析/服务端错误摘要（脱敏）：
Fixture 路径是否仍通过：
最后已知正常的参考/响应证据：
```

## 隔离顺序

1. 运行 fixture request/mapper/store/UI tests。Fixture 失败表示本地回归，走普通根因修复；fixture 全绿才继续外部协议排障。
2. 检查 session/clock/network 环境，不打印敏感值。
3. 用最小 Debug live probe 采集：endpoint 名、method、status、content type、响应字节数、decode 阶段、server error code、耗时；正文只做内存内最小检查并脱敏。
4. 对照当前 `API_EVIDENCE`、Proto schema、Android reference 最新受控 commit；不得根据第三方片段盲改签名/headers。
5. 分类：网络/TLS、认证过期、请求参数、HTTP/server、Proto decode、字段语义、反滥用/频控、服务能力下线、UNKNOWN。
6. 固化最小脱敏失败 fixture（可合法保存时）和一个先失败的 request/decode/mapper test。

## 修复边界

- 只修改 data/protocol/session 层及相应测试/证据。
- UI/导航/Pager/MediaViewer/动效状态机默认禁止修改。
- 新 header、设备参数、签名或 token 流程必须有证据和安全审查。
- 不绕过 TLS、验证码、账号保护、频控或服务限制。
- 无证据时返回可诊断 unavailable/unsupported，并保持 fixture 模式可用。

## 验证

- 新旧/畸形 fixture 测试。
- request construction 与 redaction。
- Store 对新错误的状态不变量。
- 最小 live smoke（非自动门禁）。
- 完整 `make quality`，确认 UI fixture 链路无回归。

## 输出

根因/证据、协议变化、最小修复、失败→通过测试、live 验证限制、仍需用户/上游证据。完成后停止。
