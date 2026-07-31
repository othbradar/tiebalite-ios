# 阶段 03：创建可构建、可测试的 Xcode 工程骨架

本阶段只创建确定性工程骨架和最小 App，不实现贴吧业务页面或真实网络。

## 前置

- 阶段 02 的 ADR 已完成。
- Git 工作树 clean，记录基线 commit。
- 读取 `ADR-0001`、`ADR-0002`、`ADR-0003`、`ADR-0009`。

## 允许修改

- `project.yml`、XcodeGen 配置、生成的 `.xcodeproj`（按 ADR）。
- `App/` 与空目录/最小占位源码。
- Tests/UITests 的最小 smoke 测试。
- `Brewfile`、`Makefile`、`scripts/`、`.gitignore`。
- 工程文档和 TASK_STATE。

## 禁止

- 不接真实贴吧 API。
- 不添加 Pager、MediaViewer、推荐列表。
- 不添加未批准生产依赖。
- 不手工批量编辑 `.pbxproj`。
- 不配置用户的真实 Team ID、证书或 App Store 信息。

## 工程要求

1. 使用 XcodeGen 声明：
   - App target
   - unit test target
   - UI test target
   - shared scheme
   - 至少一个 `.xctestplan`
2. Swift 6 + strict concurrency Complete。
3. iOS/iPadOS 18.0+，支持 iPhone/iPad。
4. Bundle ID 使用明显占位且集中配置，例如 `dev.local.tiebaliteios`；签名使用 Automatic/无 Team 的 Simulator 可构建配置。
5. App 仅显示稳定的启动占位页和环境信息，不做花哨动画。
6. 目录引用与 ADR 一致，生成 Protobuf 目录可为空但边界存在。
7. Debug/Release 配置清晰；密钥不进入 build settings。
8. `scripts/project.env` 从 example 生成并填写真实 project/scheme/targets。
9. `make generate` 可重复，连续运行不产生非确定性差异。
10. `make build`、`make test-unit`、`make test-ui-smoke` 有真实结果。

## 必须测试

- 重新生成工程。
- `xcodebuild -list`。
- generic iOS Simulator build。
- 选取实际可用 iPhone Simulator 运行 unit tests。
- UI smoke：启动 App，确认根页面 identifier 存在。
- 若 iPad runtime 可用，至少 build 一次 iPad-compatible target；UI 流程放后续。

## 验收

- 从 clean checkout 按 README/Brewfile 可生成工程。
- App 在 Simulator 启动。
- unit/UI smoke 真实通过。
- `git diff --check` 通过。
- 重新 `make generate` 后差异为空或符合 ADR。
- 没有业务网络/页面代码。

报告所有实际命令与结果后停止。
