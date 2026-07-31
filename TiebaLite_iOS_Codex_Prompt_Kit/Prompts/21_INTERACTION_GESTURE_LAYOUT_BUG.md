# 交互专项 Bug：白块、遮挡、错页、跳动、手势冲突

在填写实际现象后，显式调用 `$ios-interaction-qa` 与 `$ios-root-cause-debug`。本提示词专门处理视觉交互问题，不允许“凭感觉调动画”。

## 现象

```text
页面/组件：
操作：
白块/露底/遮挡/错页/跳动/无法返回/手势冲突：
发生阶段：手势开始 / 交互中 / 完成 / 取消 / 旋转 / 返回后
设备、方向、窗口宽度：
网络/图片状态：已加载 / 加载中 / 失败
复现率：
证据：
```

## 先记录的运行数据

- 容器 bounds、safeAreaInsets、页面 frame。
- 当前业务 page ID、邻页 ID、显示 index、目标 index。
- SwiftUI identity 与 UIKit controller/object identity。
- 页面背景颜色/透明度链。
- 参与转场页面是否被移除或替换。
- gesture recognizers 的 state、translation、velocity、failure dependency。
- zoomScale、contentOffset、contentSize。
- overlay/sheet/fullScreenCover 的展示状态与 hit-testing。
- animation transaction、Reduce Motion。
- 图片 request ID、状态和取消。

## 白块/透明露底检查顺序

1. 容器及每层背景是否不透明。
2. 当前/相邻页在 interactive transition 中是否保持存活。
3. 数据更新是否临时发出空数组/空 page。
4. `.id` 是否因随机值或 index 改变导致重建。
5. UIKit wrapper 是否在 `updateUIViewController` 重设 controller。
6. 图片 loading/failure 是否返回透明 `EmptyView`。
7. 尺寸变化是否出现一帧旧 frame/零 frame。
8. 双重动画是否把内容移出但背景未覆盖。

## 遮挡检查顺序

1. 是否应使用 toolbar/safeAreaInset 而用了 overlay。
2. `.ignoresSafeArea` 是否施加到内容而非背景。
3. z-order 与 hit-testing 是否一致。
4. 键盘/sheet/rotation 后 inset 是否恢复。
5. fixed frame 是否在 Dynamic Type/iPad split view 溢出。
6. 根 ZStack 是否存在常驻透明层。

## 手势检查顺序

1. 系统边缘返回是否优先。
2. 横向 pager 与纵向 scroll 的方向锁。
3. 图片 zoom/pan 与翻页的边界规则。
4. 同一动作是否被 SwiftUI 与 UIKit 两套 gesture 同时处理。
5. 取消/失败状态是否正确重置。

## 修复与验收

- 先写失败测试/InteractionLab scenario。
- 修复唯一根因。
- 快速滑动 20 次、取消/反向 10 次、旋转/resize、加载中/失败图均验证。
- 使用纯红/绿/蓝调试背景临时发现露底，完成前移除调试色并保留自动断言/测试。
- 不能用延迟、随机 ID、遮罩、全局禁动画。

报告根因，不只报告“已调整参数”。
