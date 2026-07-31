# 快速开始：macOS 26 + Xcode 26 + Codex 桌面版

假设套件解压在：

```bash
~/Downloads/TiebaLite_iOS_Codex_Prompt_Kit
```

## 1. 安装仓库护栏与提示词

推荐使用安装脚本；它会保留 `.agents` 等隐藏目录，并拒绝覆盖非空目录：

```bash
chmod +x ~/Downloads/TiebaLite_iOS_Codex_Prompt_Kit/install_into_repo.sh
~/Downloads/TiebaLite_iOS_Codex_Prompt_Kit/install_into_repo.sh \
  ~/Developer/TiebaLiteIOS
```

手工方式：

```bash
mkdir -p ~/Developer/TiebaLiteIOS
cd ~/Developer/TiebaLiteIOS
git init -b main

ditto \
  ~/Downloads/TiebaLite_iOS_Codex_Prompt_Kit/RepoOverlay \
  ~/Developer/TiebaLiteIOS

ditto \
  ~/Downloads/TiebaLite_iOS_Codex_Prompt_Kit/Prompts \
  ~/Developer/TiebaLiteIOS/Prompts

cp \
  ~/Downloads/TiebaLite_iOS_Codex_Prompt_Kit/FIRST_CODEX_MESSAGE.txt \
  ~/Developer/TiebaLiteIOS/Prompts/FIRST_CODEX_MESSAGE.txt
```

不要使用 `cp *`，它会漏掉 `.agents` 等隐藏目录。

## 2. 添加 Android 只读参考仓库

```bash
cd ~/Developer/TiebaLiteIOS
git submodule add -b 4.0-dev \
  https://github.com/zzc10086/TiebaLite.git \
  References/TiebaLite-Android

git submodule update --init --recursive
```

`References/TiebaLite-Android` 仅用于审计协议、字段、状态和产品行为。普通实现任务不得修改或自动更新它。

## 3. 建立最初 Git 基线

```bash
cd ~/Developer/TiebaLiteIOS
git add -A
git commit -m "chore: install Codex project guardrails"
```

不要等 Codex 生成大量代码后才建立 Git。Codex Worktree、回滚、差异审查和最后绿色状态都需要可靠基线。

## 4. 打开 Codex 桌面版

- 选择 `~/Developer/TiebaLiteIOS` 作为项目根目录。
- Android 审计、架构评审、最终审计可选 GPT-5.6 Sol Ultra。
- 单个实现/修复任务优先 Sol Max；坚持使用 Ultra 时，必须保持“主代理唯一写入、子代理只读”。
- Computer Use 只授权 Xcode、Simulator 和必要系统设置；不让它输入或读取真实账号凭据。

## 5. 第一条消息

打开并完整粘贴：

```text
Prompts/FIRST_CODEX_MESSAGE.txt
```

也可以直接发送：

```text
请执行 Prompts/00_BOOTSTRAP_ENVIRONMENT.md。
严格读取并遵守仓库根目录及目标目录适用的 AGENTS.md，并按需使用仓库 .agents/skills。
当前只完成阶段 00；不得创建业务页面、不得进入阶段 01 或后续阶段。
先检查 Git、Xcode、Simulator、Android 参考 submodule、指令文件和脚本基线，再给出允许修改范围并立即执行。
完成时报告真实运行过的命令、结果、未验证项和剩余风险，然后停止。
```

完成后在 Terminal 检查：

```bash
cd ~/Developer/TiebaLiteIOS
make doctor
```

阶段 00 尚未创建 Xcode 工程，因此不要运行 `make quality-fast`。随后在 Codex 中运行 `/review`，选择 Review uncommitted changes；核对环境记录和 Android lock，再由你提交阶段 00。

## 6. 后续固定循环

```text
只发送一个阶段提示词
→ Codex 恢复 Git/规格/测试基线
→ 先写状态、fixture 或失败测试
→ 最小实现
→ 定向测试
→ make quality
→ /review
→ 只修当前范围 P0/P1
→ 再次 make quality
→ 由用户提交绿色 commit
→ 下一阶段
```

阶段完整顺序见 `Prompts/README.md`。交互 Bug 使用 `20_ROOT_CAUSE_BUG_FIX.md` 或 `21_INTERACTION_GESTURE_LAYOUT_BUG.md`；动画漂移使用 `22_ANIMATION_CONSISTENCY_AUDIT.md`；新线程续作先用 `32_RESUME_OR_HANDOFF.md`。不要发送“还有白块，继续调一下”这类无复现、无测试、无范围的指令。
