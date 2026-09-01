# 阶段 00 环境审计

- 审计时间：2026-07-31 09:11 CST（UTC+08:00）
- 审计阶段：00
- 总体状态：`PASS`
- 工作目录：`<repo-root>`
- 仓库根目录：`<repo-root>`
- 基线分支：`main`
- 基线 commit：`c9e2dd91de1ccd1bd51d468645e98af6dc24ea0d`
- 基线 `git status --short`：空

## 允许范围

本阶段只允许安装仓库护栏与提示词、记录环境、锁定 Android 参考 commit、补齐开发工具，以及修正必要的脚本路径/权限/语法。禁止创建 Xcode App target、Swift 业务代码或业务页面；禁止修改 Android submodule、`.gitmodules`、bundle identifier、签名团队或账号配置；禁止进入阶段 01。

## 主机与工具链

以下命令均真实运行：

```text
$ sw_vers
ProductName:            macOS
ProductVersion:         26.6
BuildVersion:           25G72

$ uname -m
arm64

$ xcode-select -p
/Applications/Xcode.app/Contents/Developer

$ xcodebuild -version
Xcode 26.6
Build version 17F113

$ swift --version
swift-driver version: 1.148.6 Apple Swift version 6.3.3
(swiftlang-6.3.3.1.3 clang-2100.1.1.101)
Target: arm64-apple-macosx26.0

$ git --version
git version 2.50.1 (Apple Git-155)
```

开发工具最终状态：

| 工具 | 路径 | 版本 | 状态 |
|---|---|---|---|
| Homebrew | `/opt/homebrew/bin/brew` | `6.0.13-118-ged35dbc` | PASS |
| ripgrep | `/opt/homebrew/bin/rg` | `15.1.0` | PASS |
| Python | `/opt/homebrew/bin/python3` | `3.14.4` | PASS |
| XcodeGen | `/opt/homebrew/bin/xcodegen` | `2.45.4` | PASS |
| SwiftLint | `/opt/homebrew/bin/swiftlint` | `0.65.0` | PASS（本阶段安装） |
| xcbeautify | `/opt/homebrew/bin/xcbeautify` | `3.2.1` | PASS（本阶段安装） |

阶段开始时 `command -v swiftlint || true` 与 `command -v xcbeautify || true` 输出为空；`Brewfile` 已声明二者。实际运行：

```text
$ brew bundle install --file=Brewfile --no-upgrade
Using ripgrep
Using xcodegen
Installing swiftlint
Installing xcbeautify
`brew bundle` complete! 4 Brewfile dependencies now installed.

$ env HOMEBREW_BUNDLE_NO_UPGRADE=1 brew bundle check --file=Brewfile --verbose
The Brewfile's dependencies are satisfied.
```

`--no-upgrade` 用于避免顺带升级本机 90 个与阶段 00 无关的 formula 和 5 个 cask。安装过程中 Homebrew 报告本机已安装的 `libtiff`/`webp` keg 元数据存在循环依赖警告，但本次安装与最终 Brewfile 检查均成功；未按提示卸载或重装这些无关图像库。

## Simulator

受限沙箱内首次运行以下两条命令均退出 `1`：

```text
xcrun simctl list runtimes
xcrun simctl list devices available
```

错误为 `CoreSimulatorService connection became invalid`，并包含对 `~/Library/Logs/CoreSimulator` 的 `Operation not permitted`。在获准的只读系统范围内原命令重新运行后均退出 `0`，证明失败来自沙箱权限，而不是 runtime 缺失。

可用 runtime：

```text
iOS 26.5 (26.5 - 23F77) - com.apple.CoreSimulator.SimRuntime.iOS-26-5
```

可用 iPhone Simulator（均为 iOS 26.5、`Shutdown`）：

| 设备 | 状态 |
|---|---|
| iPhone 17 Pro | Available |
| iPhone 17 Pro Max | Available |
| iPhone 17e | Available |
| iPhone Air | Available |
| iPhone 17 | Available |

另有自定义设备 `Tieba-Perf-Test`；`simctl` 列表未直接标明其 device family，因此不将它用于 iPhone 验收结论。

可用 iPad Simulator（均为 iOS 26.5、`Shutdown`）：

| 设备 | 状态 |
|---|---|
| iPad Pro 13-inch (M5) | Available |
| iPad Pro 11-inch (M5) | Available |
| iPad mini (A17 Pro) | Available |
| iPad Air 13-inch (M4) | Available |
| iPad Air 11-inch (M4) | Available |
| iPad (A16) | Available |

结论：至少一个 iPhone 与一个 iPad Simulator 可识别。仅验证了枚举，未启动设备、构建或运行 App。当前只安装 iOS 26.5 runtime，未验证 iOS 18.x runtime。

## Git 与 Android 参考

真实检查结果：

```text
$ pwd
<repo-root>

$ git rev-parse --show-toplevel
<repo-root>

$ git status --short
# 阶段开始时无输出

$ git log -1 --oneline --decorate
c9e2dd9 (HEAD -> main) chore: install Codex project guardrails

$ git submodule status --recursive
 5545326b2a8e0d784b2f3dfbcb219c7b121e61c2 References/TiebaLite-Android (v4.0.0-beta.6-7-g5545326b)
```

`.gitmodules` 记录：

- path：`References/TiebaLite-Android`
- URL：`https://github.com/zzc10086/TiebaLite.git`
- branch：`4.0-dev`

submodule 实际状态：

- 当前 branch：`4.0-dev`
- 完整 commit：`5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`
- `git -C References/TiebaLite-Android status --porcelain=v1 --untracked-files=all`：无输出
- 与 superproject gitlink 一致
- 与 `References/TiebaLite-Android.lock` 第一列一致
- `scripts/reference_integrity.sh`：退出 `0`

未执行网络 `fetch`，所以只确认当前 checkout、gitlink 与本地 remote-tracking ref；未声称该 commit 是远端最新版本。未修改 submodule。

阶段结束时 `git status --short --branch` 仅包含 `## main` 和本阶段新增的根护栏/交付目录（共 116 个未跟踪文件）；`git diff --name-only` 与 `git diff --cached --name-only` 均无输出，说明既有受跟踪文件、暂存区和 submodule gitlink 均未改动。未执行 `git add`、commit 或远端操作。

## 护栏、指令与脚本

阶段开始时 Prompt Kit 仅位于 `TiebaLite_iOS_Codex_Prompt_Kit/`；仓库根缺少 `AGENTS.md`、`.agents/`、`Specs/`、`Docs/`、`scripts/`、`Prompts/`、`Makefile` 和 `Brewfile`。`install_into_repo.sh` 会拒绝非空目的目录，因此按 `QUICK_START.md` 的手工 overlay 流程安装，并排除会覆盖现有用户文件的 `.DS_Store`。

真实检查与结果：

| 命令 | 退出码 | 结果 |
|---|---:|---|
| `shasum -a 256 -c MANIFEST.sha256`（Prompt Kit 目录） | 0 | 套件 manifest 全部通过 |
| `python3 scripts/check_instruction_size.py` | 0 | 全部适用链低于 32768 bytes；当前最大 28562 bytes |
| `python3 scripts/validate_skills.py` | 0 | 8 个 skill 的 `name`、`description` 与 metadata 通过 |
| `find scripts .agents/skills TiebaLite_iOS_Codex_Prompt_Kit -type f -name '*.sh' -exec bash -n {} \;` | 0 | 全部主仓库/Prompt Kit shell 脚本语法通过 |
| 主仓库 `.sh`/`.py` executable 检查 | 0 | 无缺失可执行位 |
| `scripts/reference_integrity.sh` | 0 | Android 参考 clean 且与 lock 一致 |
| `make instructions` | 0 | instruction-size 与 8 个 repo skill 均通过 |
| `make reference-check` | 0 | Android 参考 clean 且与 lock 一致 |
| `make forbidden` | 0 | 0 error group、0 warning group |
| `make secret-scan` | 0 | 未发现高置信密钥 |
| `make doctor`（可访问 CoreSimulatorService） | 0 | `0 failure(s), 0 warning(s)` |
| `git diff --check` | 0 | 无已跟踪差异错误 |
| 对 116 个未跟踪文件逐个执行 `git diff --no-index --check -- /dev/null <file>` | 0 | 无空白错误 |
| 业务源码/Xcode 工程查找 | 0 | 无 `.swift`、`project.yml`、`.xcodeproj`、`.xcworkspace` 或非规则业务文件 |

`make doctor` 最终确认 Git、Xcode、Swift、Python、ripgrep、Homebrew、XcodeGen、SwiftLint、xcbeautify、iPhone/iPad Simulator、instruction chains、skills 和 Android lock 全部可用。

## 已观察并保留的失败

以下失败均未被省略，且都有明确恢复证据：

1. `rg --files Prompts .agents | sort`：退出 `2`，因为阶段开始时根目录尚未安装这两个目录；overlay 后路径已存在。
2. `bash TiebaLite_iOS_Codex_Prompt_Kit/RepoOverlay/scripts/bootstrap_check.sh`：overlay 前退出 `1`，汇总 `5 failure(s), 2 warning(s)`；原因是根护栏/脚本缺失、SwiftLint/xcbeautify 缺失和沙箱内 Simulator 不可访问。最终 `make doctor` 退出 `0`。
3. 两条 `xcrun simctl list ...`：沙箱内各退出 `1`；只读提升后原命令各退出 `0`。
4. 首次 `rsync -a --exclude='.DS_Store' .../RepoOverlay/ ./`：退出 `1`，因为沙箱禁止创建根 `.agents/`；同一复制命令在获准范围内退出 `0`。
5. 沙箱内 `brew bundle check --file=Brewfile`：退出 `1`，因为 `/opt/homebrew/Cellar` 与 Homebrew cache 不可写。
6. 获准范围内 `brew bundle check --file=Brewfile --verbose`：安装前退出 `1`，报告 SwiftLint/xcbeautify 缺失，同时认为已有 ripgrep/xcodegen 可更新；随后使用 `--no-upgrade` 安装缺失工具，最终带 `HOMEBREW_BUNDLE_NO_UPGRADE=1` 的检查退出 `0`。
7. 安装后不带 `HOMEBREW_BUNDLE_NO_UPGRADE=1` 的两次 `brew bundle check` 仍退出 `1`，因为默认检查把已有 ripgrep/xcodegen 的可用升级视为未满足，并重复报告 `libtiff`/`webp` 元数据循环；这不否定四个命令均已安装及带 no-upgrade 检查退出 `0` 的结果。
8. `command -v shellcheck`：退出 `1`；ShellCheck 不在阶段 00 指令或 Brewfile 中，所要求的 `bash -n` 已通过。
9. 一个只读子审计使用 `pgrep` 检查是否残留 Homebrew 进程时被沙箱进程可见性限制拒绝；未使用该结果判断安装状态，安装命令自身和最终工具版本检查均退出 `0`。

## 缺失项、未验证项与风险

- 缺失工具：无。阶段开始时缺失的 SwiftLint 与 xcbeautify 已补齐。
- `project.yml`、Xcode project/workspace 和 App target 尚不存在，这是阶段 00 的预期状态。
- `make generate`、`make lint`、构建、单元测试、UI smoke、`make quality-fast` 与 `make quality` 均为 `NOT_TESTED`；`QUICK_START.md` 明确要求阶段 00 不运行 `make quality-fast`，工程在阶段 03 才创建。
- Simulator 只完成枚举，未 boot；无 App 可供运行。
- 当前无 iOS 18.x Simulator runtime，后续最低部署版本兼容性测试仍需单独环境。
- Homebrew 的 `libtiff`/`webp` 旧 keg 元数据循环依赖警告仍存在；未扩大阶段 00 范围去卸载或重装无关工具。
- 因原始 Prompt Kit 仍在仓库内，最长适用 instruction chain 为 28562/32768 bytes，仅余 4206 bytes；当前通过，但后续扩充嵌套 `AGENTS.md` 前必须重新检查。
- `scripts/bootstrap_check.sh` 通过名称过滤确认存在 iPhone/iPad，但脚本本身没有分别计数两类设备；本审计已直接检查完整 `simctl` 输出补足证据。
- `scripts/reference_integrity.sh` 的 `git diff` 检查本身不覆盖 untracked 文件；本审计额外运行 `status --porcelain=v1 --untracked-files=all`，结果为空。
- Prompt Kit 原始目录仍作为基线 commit 中的用户文件保留，根目录同时安装其 overlay；未删除、移动或改写原始套件。
