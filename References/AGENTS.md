# References 只读参考约束

- `TiebaLite-Android` 是只读 submodule；禁止修改、格式化、提交或在普通任务中更新 commit。
- 审计时记录 branch、完整 SHA、路径、symbol 和证据置信度；搜索 legacy/alternate call site 后再下结论。
- 不运行会修改 submodule 源码或生成受跟踪文件的命令；必要构建产物只能在被忽略目录并在完成后说明。
- Android UI 代码仅提供产品语义/视觉层级证据，不机械翻译为 SwiftUI。
- 参考升级必须走专用提示词，重新审计 API/Proto/行为并更新 lock。
