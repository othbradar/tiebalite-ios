# 阶段 12：Session、登录、Cookie 与失效处理

这是安全敏感阶段。必须依据 `ADR-0007` 与 Android 源码证据实现，不能凭经验发明百度登录参数，也不能让 Codex 获取或记录用户密码。

## 前置

- `Specs/API_EVIDENCE.md` 中登录/会话相关证据已标明充分度。
- ADR-0007 已 Accepted，若仍有 UNKNOWN，先更新 ADR 的可验证范围。
- Fixture session 测试底座已存在。

## 安全边界

- App 不自行采集、保存或打印用户名/密码。
- 若采用官方网页登录，只允许已批准的百度登录域名和跳转规则；不注入脚本窃取表单。
- Codex/Computer Use 不代用户输入真实凭据，不录制含敏感内容的屏幕。
- Cookie/token 只保存必要字段，使用 Keychain 或 ADR 指定安全存储。
- 日志、测试附件、fixture、Git diff 必须通过 redaction 检查。
- 不关闭 TLS 校验，不接受任意证书。

## 状态机

实现并测试：

```text
signedOut
→ authenticating
→ signedIn(identity summary)
→ expired
→ signedOut

任何阶段可进入 failed(previous safe state)
```

明确：

- App 冷启动会话恢复。
- Cookie store 与 URLSession 同步。
- 过期如何从 server error 统一识别。
- 多个页面同时收到过期时只触发一次全局状态变化。
- 退出登录清理 Keychain、cookie、用户隔离缓存和 UI path。
- 取消登录回到 signedOut，不显示普通网络错误。

## 自动化测试

全部使用 fake web/session：

- 登录成功、取消、失败。
- 冷启动恢复。
- Cookie 注入到需要认证 endpoint。
- 不向匿名 endpoint 泄漏不必要身份信息。
- 会话过期的统一处理和页面旧内容策略。
- 退出清理。
- Redaction 单元测试覆盖敏感 key 与 header。

## 真实手工验证

真实登录只提供用户手工检查清单：

1. 用户自行输入凭据。
2. 登录完成后仅检查身份摘要和关注吧能力。
3. 关闭/重开 App 验证恢复。
4. 退出后验证清理。

不得把真实凭据或 Cookie 写入报告。Computer Use 只可在不显示凭据的页面验证后续 UI。

## 禁止

- 不实现签到/发帖/评论写操作。
- 不把 Cookie 放 UserDefaults。
- 不用全局 NotificationCenter 广播模糊 session 事件。
- 不在各 Feature 重复弹登录失效提示。
- 不因登录状态变化重建整个 App root 并丢失可安全保留的匿名状态。

## 验收

- Fake session 全矩阵自动化通过。
- 真实登录流程有安全、可执行的手工清单；若未实测，明确标注。
- 任何日志/附件无敏感值。
- `make quality` 与安全专项 review 通过。

完成后停止。
