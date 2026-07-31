# 提示词套件校验报告

校验日期：2026-07-17

## 已通过

- 119 个交付文件在校验前均非空，文本文件可按 UTF-8 读取。
- 所有 shell 脚本通过 `bash -n`，带 shebang 的脚本具有可执行权限。
- 所有 Python 脚本通过编译检查。
- `.yml` / `.yaml` 可解析。
- 8 个仓库级 Skills 具有有效 `SKILL.md` frontmatter 与 `agents/openai.yaml`。
- 44 个 `Prompts/*.md` 路径引用全部可解析。
- 根及各目录适用的 AGENTS 指令链均低于默认 32 KiB；最大链约 14.8 KiB。
- `install_into_repo.sh` 在空目录完成安装，确认 `.agents`、Prompts、嵌套 AGENTS 和脚本未遗漏。
- 使用本地真实 Git submodule 形态验证：正确 SHA 通过，错误 lock SHA 和 dirty submodule 均会失败。
- 合成禁用 Swift 写法验证：`.id(UUID())`、Feature 任意动画和 page-style TabView 会被拦截。
- 合成 BDUSS 值验证：secret scan 会失败；清理后恢复通过。
- Interaction inventory 能生成非空审计清单。

## 生成环境中未运行

本套件是在非 macOS/Xcode 执行环境中生成，因此未在这里运行：

- Xcode 26 / Swift 6 编译。
- iPhone/iPad Simulator。
- XCTest / XCUITest。
- XcodeGen 生成的实际 iOS 工程。

这不是对未来 App 的测试结果。`Prompts/00_BOOTSTRAP_ENVIRONMENT.md` 会在你的 macOS 26 主机验证真实工具链；阶段 03 才创建 Xcode 工程并建立首个 build/unit/UI smoke 绿色基线。
