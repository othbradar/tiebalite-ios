# TestSupport 约束

- TestSupport 只提供确定性 fixture loader、mock/fake、clock、ID generator、LaunchScenario、UI test helper 和诊断附件工具。
- 不依赖真实网络、真实 Keychain、用户账号、当前时间、随机 UUID 或不受控系统状态。
- fixture 必须最小化、脱敏、有来源/生成说明；禁止保存完整 Cookie、BDUSS、STOKEN、密码或私密内容。
- TestSupport 不进入 Release 可达行为；Debug 菜单也必须由编译配置隔离。
- 不为每个 Feature 复制 mock HTTP/session/image 实现；共享协议语义保持一致。
