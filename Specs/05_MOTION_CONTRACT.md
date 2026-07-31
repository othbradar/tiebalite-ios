# 动效契约

目标：动效只表达层级、状态和直接操作反馈；不承担修补布局或竞态的职责。

## 唯一令牌

具体数值由阶段 04 通过视觉/设备验证确定，业务代码只能引用语义令牌：

- `Motion.instant`
- `Motion.fast`
- `Motion.standard`
- `Motion.emphasized`
- `Motion.interactive`

曲线和时长集中在 `DesignSystem/Motion.swift`。禁止 Feature 直接写 `.easeInOut(duration:)`、`.spring(...)` 等参数。

## 系统动效

- NavigationStack、NavigationSplitView、sheet 和 fullScreenCover 使用系统转场。
- 不叠加自定义页面 offset、scale 或 matchedGeometryEffect，除非有独立 ADR 和专项测试。
- Tab 切换默认不做自定义整页转场。

## 内容动效

- 首次 loading → content：可使用标准淡入，不能移动整个页面。
- refresh/loading-next：保留内容，不对整个列表 transition。
- 批量分页：不逐行飞入。
- inline error/banner：使用统一 transition，并保证布局稳定。
- 图片 decode 完成：最多做轻微 opacity 变化；占位与最终内容 frame 必须一致。

## Reduce Motion

- 所有自定义 Motion API 接收 reduce-motion 环境或提供等价无位移路径。
- 减弱动态效果时，导航仍由系统管理；自定义弹簧、缩放、滑入应替换为无动画或短淡入。

## 审计要求

每个阶段运行：

```bash
rg -n '\.animation\(|withAnimation\(|\.transition\(|\.spring\(|matchedGeometryEffect' Sources
```

每处调用必须归属一个令牌和一个产品行为。无法说明用途即删除。
