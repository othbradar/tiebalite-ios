# App 组合根与导航约束

- App 目录只负责应用入口、依赖组合、Scene 生命周期、主 Tab、系统导航容器和全局能力协调。
- 不在 App root 放推荐/吧/帖子业务状态、网络请求或 Proto 映射。
- 每个主 Tab 的 NavigationPath/selection 所有权清晰；iPhone/iPad 映射只转换 route，不复制 Feature Store。
- Session 过期、深链和场景恢复通过显式 coordinator/state 处理，不用散落 NotificationCenter 或多个 Bool。
- 禁止用 root `.id(...)`、条件重建 Window/App root 或全局 animation 修复页面问题。
- 修改 App Shell 必须运行所有主 Tab、返回状态和至少一个 iPad route UI smoke test。
