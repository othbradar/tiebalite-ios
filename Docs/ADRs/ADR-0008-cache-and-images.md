# ADR-0008：缓存与图片管线

- 状态：Accepted
- 日期：2026-07-31
- 决策者：阶段 02 架构决策
- 关联阶段：02、07、09、10

## 背景

列表与 MediaViewer 需要去重请求、取消、占位稳定和资源释放。当前没有性能
证据支持 Nuke/Kingfisher、数据库或自定义磁盘格式；图片 URL 候选的 HTTPS
有效性、隐私分类和 Swift 6 图像类型跨 actor 能力也未运行验证。

## 必须满足的约束

- 一个生产 ImageRepository；列表与 MediaViewer 共用。
- 只请求已验证 HTTPS URL，不猜测把 HTTP 字符串改为 HTTPS。
- cache namespace 与 session/privacy 分类一致。
- row 复用、取消和晚到结果不能显示错图或写回失效 session。
- 不用 `@unchecked Sendable` 掩盖 UIImage/CGImage 并发问题。
- 磁盘和 decoded-image cache 在证据前不得默认启用。

## 候选方案

### A：AsyncImage/shared URLCache

- 优点：代码少。
- 缺点：key、取消、coalescing、隐私 namespace 和测试控制不足。
- 风险：共享 Cookie/cache、受保护图片跨 session。
- 验证方式：无法满足当前显式 lease/namespace 契约，不作为 production data
  layer。

### B：Foundation/ImageIO 的最小自有管线

- 优点：无新增依赖；认证、key、取消、请求合并和生命周期可控。
- 缺点：内存上限、decode/downsample 和磁盘策略需自行验证。
- 风险：actor 外传图像对象的 Sendable 状态、重复 decode。
- 验证方式：strict-concurrency spike、资源 probe 和性能测量。

### C：Nuke/Kingfisher 等第三方

- 优点：成熟缓存、prefetch 和处理器。
- 缺点：未经批准，可能引入第二套网络/cache。
- 风险：体积、许可证、Swift 6 隔离和退出成本。
- 验证方式：只有 B 无法满足已量化门禁后才新建依赖 ADR。

## 决策

选择 B，并把初始 Accepted 范围限制为：

- `ImageRepository actor`；
- HTTPS fetch、in-flight coalescing、subscriber lease/cancel；
- actor 内封装的有界原始 Data memory cache；
- MIME、byte/pixel 上限与安全 metadata parsing；
- thumbnail/original/target pixel size 分 variant key；
- deterministic fake 与 metrics。

持久磁盘 cache、decoded image cache 和跨 actor 图像对象保持 Proposed，必须
由 strict-concurrency/性能 spike 决定。SDK 未明确提供安全 Sendable 图像
边界时，actor 只跨界传 Data 与不可变 metadata；不得添加
`@unchecked Sendable`。

### CachePolicy

```text
CacheScope =
  public
  | protected(ProtectedDataLease)
  | unknown

CacheRetention =
  noStore
  | memoryOnly
  | futureDisk
```

隐私 scope 与保留策略是两个独立维度。使用 active auth 发出的响应无论 URL
形态如何都必须标为 `protected`；不能因其看似公共而降为 public。无法证明
scope 的输入标为 `unknown` 并强制 `noStore`。`public` 与 `protected` 当前
都只允许 `memoryOnly/noStore`；`futureDisk` 只是在独立持久缓存 ADR、清理
和隐私门禁通过后的占位，不是当前能力。

key 是完整已验证 URL、variant、scope namespace 与版本的哈希；即使 retention
为 noStore，也不能省略 scope 参与请求合并/诊断身份。不记录 URL，不擅自剥
query 或把不同资源合并。失败响应不缓存；含 token-like query 的输入至少为
protected，无法安全分类时按 unknown/noStore。

protected write 必须携带 ADR-0007 的 lease，并在提交前复核。退出/过期先
撤销 generation，再清 protected namespace。public、protected 与 unknown
不共享 entry 或 in-flight result。共享 URLCache/CookieStorage 默认关闭；
若以后启用磁盘 URLCache，须证明 namespace、清理和 redirect 行为。

图片候选选择保留来源集合；只使用已经验证的 HTTPS candidate。列表与
MediaViewer 共用请求和 Data cache，但 Viewer 自己的 full-resolution
presentation resource 在离场/关闭时释放。

## 为什么不是其他方案

A 不能表达 session lease 与可测试 key；C 在系统路径没有失败证据时违反
依赖政策。B 的 Accepted 范围故意不承诺尚未验证的磁盘和 decoded cache。

## 迁移/退出成本

Feature 只依赖 ImageRepository 协议与 ImageRequest/ImageResult domain。
底层 decoder/cache 可由新 ADR 替换。隐私分类未完成时回退 memory-only；
性能不足时先测 downsample/coalescing，再评估第三方。

## 验收与回滚条件

- 同 URL/variant/namespace 并发请求合并；不同 namespace 不合并。
- 多订阅者取消互不影响，最后订阅者取消底层请求。
- row 复用的旧结果不能覆盖新 MediaID。
- logout/expired 后晚到 protected write 被拒绝。
- 超大像素、坏 MIME、坏 URL、失败与取消有确定性结果。
- MediaViewer 浏览 100 张后内存/任务不单调增长。
- 日志和 key diagnostics 不暴露 raw URL。

若 protected clear/lease 失败，禁用 protected 持久缓存；若 B 在量化性能、
内存或取消门禁上失败，先回退 noStore/memory-only，再以新 ADR 评估 C。
