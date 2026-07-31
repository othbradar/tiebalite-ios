# 使用 Codex Computer Use 在 Xcode/Simulator 复现 GUI Bug

调用 `@Computer` 或明确启用 Computer Use。范围只限 Xcode、Simulator 和当前 App，不操作无关应用。

## 目标流

```text
Simulator 设备：
启动 scenario：
起始页面：
精确操作序列：
预期：
实际：
重复次数：
```

## 操作规则

1. 先确认 App build 和 scenario，不用实时网络复现可 fixture 化的问题。
2. 将 Simulator 固定到指定设备/方向/外观/字体/Reduce Motion。
3. 清晰记录每次 tap/swipe/pinch/rotation/resize。
4. 复现前后保存截图；必要时保存录屏和控制台时间区间。
5. 不在复现过程中随机清缓存、重启或换设备。
6. 不让 Computer Use 输入/查看真实账号密码或 Cookie。
7. 复现后先停止并总结证据；代码修改按根因提示词执行。

## 输出

- 是否成功复现及频率。
- 最短确定性步骤。
- 观察到的状态/布局/手势证据。
- 证据文件位置。
- 建议调用的 Bug skill。
