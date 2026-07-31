# DesignSystem 目录约束

- 这里只放颜色、字体、间距、圆角、动效令牌和无业务语义的通用组件。
- DesignSystem 不发网络请求、不读 Session、不导航、不包含贴吧领域状态。
- 所有颜色必须有浅色/深色语义；禁止业务页面散落十六进制颜色。
- 字体支持 Dynamic Type；组件不得用固定高度裁切多行文字。
- 自定义动画必须通过 `Motion` 令牌并支持 Reduce Motion。
- 加载、空态、错误态、分页指示、Toast/提示条只能各有一个标准实现。
- 修改共享组件时必须运行至少一个使用它的 Feature UI smoke test，避免全局回归。
- 不为了视觉统一引入根视图全局 `.animation`。
