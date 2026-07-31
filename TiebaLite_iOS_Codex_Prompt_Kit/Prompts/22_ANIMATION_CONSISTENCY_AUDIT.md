# 动画一致性专项审计与修复

显式使用 `$ios-motion-audit`。目标：找出所有显式/隐式动效，统一到 `Specs/05_MOTION_CONTRACT.md`，消除同一操作不同曲线、双重转场和数据刷新抖动。先审计后修改。

## 只读审计

运行并分类：

```bash
rg -n '\.animation\(|withAnimation\(|\.transition\(|\.spring\(|\.snappy\(|matchedGeometryEffect|CATransaction|UIView\.animate|UIViewPropertyAnimator' App Sources
rg -n 'DragGesture\(|gesture\(|simultaneousGesture|highPriorityGesture' App Sources
```

为每处记录：

- 文件/行/组件。
- 用户动作或状态变化。
- 动画来源：系统 / Motion token / 任意参数 / 隐式继承。
- 动画范围：局部属性 / 行 / 列表 / 整页 / 导航。
- Reduce Motion 路径。
- 是否与另一层系统/自定义动画叠加。
- 是否可能在网络批量更新触发。

输出 `Docs/Audits/MOTION_AUDIT.md`。

## 统一规则

- 系统 NavigationStack/SplitView/sheet 不叠加自定义整页转场。
- 同一 loading/error/banner 使用同一 Motion token。
- refresh/pagination 不逐行飞入，不替换整页。
- Feature 不写 duration/curve/spring。
- 根节点无广域隐式 `.animation`。
- 图片 load 最多局部 opacity，frame 不变。
- Reduce Motion 下移除非必要位移/缩放。

## 修改顺序

1. 删除无产品语义动画。
2. 收窄广域 animation 的 value 和作用范围。
3. 替换任意参数为 Motion token。
4. 消除系统 + 自定义双重转场。
5. 修复由状态重建而非动画参数导致的跳动。
6. 补充测试/录屏基线。

## 验证流

- 启动、Tab、push/pop。
- 推荐 initial/refresh/pagination/error。
- 吧分区切换。
- 帖子分页/楼中楼。
- MediaViewer 打开/切图/关闭。
- iPad resize。
- Reduce Motion。

每个流录制或用 Computer Use 重复，检查相同操作时序一致、没有白块/遮挡/双动画。

## 验收

- 所有自定义动画都能映射到 Motion token 和产品行为。
- 无根级广域隐式 animation。
- Reduce Motion 测试通过。
- `make quality` 和 motion 静态检查通过。
