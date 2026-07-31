# 阶段 00：环境、仓库与护栏自检

你正在 macOS 26 的 Codex 桌面版中工作，目标工具链为 Xcode 26 / Swift 6。严格遵守仓库根目录 `AGENTS.md`。本阶段只建立可验证环境，不创建业务功能，不进入阶段 01。

## 目标

确认 Codex 打开的目录、Git、Android 参考 submodule、Xcode、Simulator、Homebrew/开发工具和仓库护栏均可用；将实际环境记录为可审查文件。

## 开始前

1. 读取根 `AGENTS.md`、`Specs/00_PRODUCT_CHARTER.md`、`Specs/02_DEFINITION_OF_DONE.md` 和 `Docs/Progress/TASK_STATE.md`。
2. 运行 `pwd`、`git rev-parse --show-toplevel`、`git status --short`。
3. 确认 `References/TiebaLite-Android` 存在且是 Git submodule；记录当前 branch/commit。不得修改它。
4. 若当前目录还不是 Git 仓库，初始化 Git，但不要删除用户文件。

## 必须检查并记录真实输出

```bash
sw_vers
uname -m
xcode-select -p
xcodebuild -version
swift --version
git --version
xcrun simctl list runtimes
xcrun simctl list devices available
command -v brew || true
command -v xcodegen || true
command -v swiftlint || true
command -v xcbeautify || true
git submodule status || true
```

## 工具处理

- 生成 `Docs/Audits/ENVIRONMENT.md`，包括命令、版本、可用 iPhone/iPad Simulator 和缺失项。
- 检查 `Brewfile`、`Makefile`、`scripts/` 和 `Prompts/` 是否存在；此时只修正明显的路径/权限问题。
- 不得未经说明安装生产依赖。
- 开发工具缺失时：优先生成/确认 `Brewfile`，说明将运行的命令；可在权限允许时执行 `brew bundle`。安装失败则保留可执行的后续步骤，不改用手工大改 `.pbxproj`。
- 执行 `scripts/bootstrap_check.sh` 或建立该脚本的可运行最小版本。
- 执行 `python3 scripts/check_instruction_size.py`，确认每条适用的 AGENTS 指令链未超限。
- 创建 `References/TiebaLite-Android.lock`，第一列写当前 Android submodule 的完整 commit SHA；以后只有显式参考版本升级任务才可更新。
- 执行 `scripts/reference_integrity.sh`，确认参考仓库 clean 且与 lock 一致。
- 验证 `.agents/skills/*/SKILL.md` frontmatter 均含 `name` 与 `description`。
- 验证所有 shell 脚本 `bash -n` 通过，并为应执行脚本设置 executable bit。

## 不允许

- 不创建 Xcode App target。
- 不写 Swift 业务代码。
- 不修改 Android submodule。
- 不猜测 bundle identifier、签名团队或真实账号。
- 不自动进入源码审计阶段。

## 交付物

- `Docs/Audits/ENVIRONMENT.md`
- `References/TiebaLite-Android.lock`
- 更新后的 `Docs/Progress/TASK_STATE.md`
- 必要的脚本权限/语法修正
- 缺失工具列表及明确影响

## 验收

- 仓库根目录和 Git 状态明确。
- Xcode 与至少一个 iPhone、一个 iPad Simulator 可识别，或明确记录缺失 runtime。
- Android submodule commit 可追踪且未修改。
- 所有仓库脚本至少通过 shell 语法检查。
- 没有新增业务代码。

完成后按 `AGENTS.md` 的报告格式汇报并停止。
