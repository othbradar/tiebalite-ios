# TiebaLite Android 视觉一致性整改规则

## 产品真相优先级

1. 用户本轮提供的 Android TiebaLite 截图。
2. `ANDROID_UI_REFERENCE.md` 锁定的 Android `4.0-dev` commit。
3. Android 原版运行行为。
4. 用户本轮明确反馈。
5. iOS 系统强制行为：安全区、返回、键盘、Dynamic Type、VoiceOver。
6. 现有 iOS 设计仅作为待替换实现，不作为视觉真相。

## 不允许 AI 自由设计

- 不增加原版没有的大圆角卡片、渐变、玻璃、阴影、悬浮圆形刷新/搜索按钮。
- 不保留“因为已经写好了”但明显不符合原版的布局。
- 不用通用星形或人形图标替代真实吧图/头像。
- 不把标题、作者、吧名、回复数重新组织成自创卡片。
- 不为了“更像 iOS”把原版的标签页、平面信息流和底部动作条删掉。

## 可以采用 iOS 原生行为

- `NavigationStack` 返回和导航栏。
- `safeAreaInset` 键盘/底部输入条。
- `PhotosPicker`。
- 系统 sheet、confirmationDialog 和 context menu。
- Dynamic Type、VoiceOver、Reduce Motion。
- iPad Split View/NavigationSplitView，但内容密度和组件语义仍参考原版。

## 性能不可回退

- ThreadReader、ForumHome 已验证的 `VirtualizedList`/UITableView/Diffable 承载不得退回普通 VStack。
- 一帖/一楼一个稳定业务 ID。
- 图片/头像任务必须跟随 Cell 复用取消，迟到结果不得串行。
- 图片网格是 Cell 内部布局，不拆成顶层列表项。
- 楼中楼预览是楼层 Cell 内部最多三条，不嵌套滚动容器。

## 每阶段人工门禁

编译并安装 Simulator 后必须停止。用户没说“通过”之前不得提交。
