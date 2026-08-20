---
name: stage-0-source-machine-analysis-and-export
description: 编排源机器 Stage 0：运行 dump.sh 导出软件/tooling/plugin 候选，调用独立 Zsh 分析 Skill 生成含第三方功能块保全清单的修改建议，再调用独立导出 Review Skill 为每个工具先给出一句话描述并完成 AI 审阅、自检和一次用户确认；确认后把 Zsh 修复计划写入本机 `~/.config/dotfiles/zsh-repair/`，其他获准草稿写入对应仓库。用于用户要求分析当前 Zsh、保全软件安装器追加块、dump 本地配置、盘点源 Mac 或为 macOS dotfiles 迁移准备候选配置时；不直接承担 Zsh 诊断或导出文件逐项 Review，也不安装、退役、commit 或 push。
---

# Stage 0：源机器分析与配置导出编排

依次组合两个独立 AI Skill 与一个确定性导出脚本，形成一次可审查的 Stage 0 交付：

```text
dump.sh → Zsh 分析 Skill → 导出配置 Review Skill
  → 跨结果自检 → 用户一次确认 → 写入本机 Zsh 修复计划与获准仓库草稿 → 精确清理
```

## 执行前计划门

先只读检查公开仓库、可选 shared 目标、工作树、`tmp/` 边界、`dump.sh`、两个子 Skill、共用契约、本机 Zsh 修复计划目录和正式目标现状；此时不得运行 `dump.sh` 或 Zsh 采集器，也不得生成、编辑或清理候选。随后向用户展示完整计划：三个能力的执行顺序、将读取/生成/审阅/清理的精确路径、可能写入的本机修复计划与仓库草稿、部分证据缺失与安全失败的处理、验证方式，以及除获准修复计划目录外不会修改 HOME，也不会修改软件/服务、commit、push 或进入后续阶段。展示后停止并等待用户明确确认，再进入执行工作流。

该初始确认可以覆盖计划中已逐项列明的两个子 Skill 受管动作，子 Skill 不重复询问；任何未展示的新路径、shared 范围、网络/系统影响或风险都必须先更新计划并再次等待确认。执行前重新检查工作树。初始计划确认不替代第 6 步的正式草稿写入确认，也不授权安装或退役。

## 使用职责单一的能力

- 读取并执行 [`$analyze-zsh-configuration`](../analyze-zsh-configuration/SKILL.md)，让它采集脱敏 Zsh 证据并生成修改建议。
- 运行仓库根目录的 `./dump.sh`，只导出软件、tooling 和插件证据及候选配置。
- 读取并执行 [`$review-exported-dotfiles`](../review-exported-dotfiles/SKILL.md)，让它只审阅 `dump.sh` 已导出的文件。
- 读取[共用契约](../stage-common-contract.md)和[领域词汇](../../../CONTEXT.md)，统一目录、所有权与安全边界。

不要在本 Skill 里复制两个子 Skill 的分析规则。任何职责冲突按“Zsh 文件建议归 Zsh Skill，导出候选配置归 Review Skill，确认与正式写入归本 Skill”处理。

## 遵守硬边界

- 不直接读取、输出或 source 真实 Zsh 文件；Zsh 内容只由子 Skill 的脱敏采集脚本处理。第三方功能块只交接安全 ID、出现序号、顺序、行范围、阶段和处置，不交接正文或内容摘要。
- 不读取 Keychain、shell 历史、完整环境或 `~/.config/dotfiles/local/parameters.zsh`、`integrations.zsh` 内容。
- 除获准写入固定的本机 Zsh 修复计划目录外，不修改真实 HOME；不修改真实 Zsh、symlink、软件、服务或应用数据，不调用 `install.sh`。
- 不在 Stage 0 生成最终 `.zprofile`、`.zshrc` 或 `shared.zsh`。
- 不创建远程仓库，不改变可见性，不 commit 或 push。
- 保护用户已有工作区变更。目标文件在确认前后发生变化时，重新展示最新完整 diff，不应用过期确认。
- 无法安全判断时标记 `manual`，不要猜测共享归属、版本、替代关系或敏感值。

## 管理固定路径

只把以下临时路径视为本次受管输出：

```text
tmp/zsh-evidence.md
tmp/dump.md
tmp/my_setup/
tmp/shared/        # 仅存在明确共享增量时
tmp/.runtime/      # 只应在 dump.sh 运行期间存在
```

正式映射：

| 分类 | 正式目标 |
|---|---|
| personal | 当前公开仓库 `my_setup/` |
| shared | 可选独立共享仓库，只保存与他人共用的配置增量 |
| personal Zsh 修复计划 | `~/.config/dotfiles/zsh-repair/zsh-repair-plan.md` |
| shared Zsh 修复计划 | `~/.config/dotfiles/zsh-repair/shared-zsh-repair-plan.md`，仅确有 shared 增量时 |
| local | 只报告参数类别，不生成或审阅内容 |
| retire | 候选配置内的 `AI-RETIRE` 评论与 Stage 3 提示 |
| manual | 集中审查摘要 |

`~/.config/dotfiles/zsh-repair/` 是 Stage 0 → Stage 1 的本机实施交接目录，不是 Zsh 运行时配置，也不进入 Git、shared 仓库或 Stage 2 checkout。目录必须是当前用户拥有的普通目录且权限为 `0700`；计划必须是当前用户拥有的普通文件且权限为 `0600`，不得跟随 symlink。已有计划在获准覆盖前先备份为同目录 `0600` 时间戳副本，再通过同目录临时文件原子替换。任何类型、owner、权限或备份异常都阻止对应计划写入。

不得再把正式 `zsh-repair-plan.md` 写入 `my_setup/zsh/` 或 shared 仓库。发现这些旧位置已有计划时只把它们列为 legacy，除非其删除已经包含在本次完整 diff 且得到用户明确确认，否则不自动移动或删除。

只有当前目录不是有效仓库、仓库根不唯一，或确有 shared 增量但目标仓库无法唯一定位时，才把所有歧义合并成一次提问。

## 执行工作流

### 1. 预检

1. 定位当前公开 Git 仓库根目录，确认 `./dump.sh` 和两个子 Skill 均存在。
2. 检查 `git status --short`、仓库正式目标当前 diff，以及固定本机 Zsh 修复计划目标的类型、owner、权限和现有状态；把已有修改视为用户内容。
3. 确认 `tmp/` 被 Git 忽略、不是 symlink，且没有上次未处理的受管候选。未知 `tmp/` 内容不得删除。
4. 记录 personal 与可选 shared 的唯一目标位置。

### 2. 导出软件与工具配置

从仓库根运行无参数 `./dump.sh`。

无论退出码是什么，都先检查脱敏标准错误和 `tmp/dump.md`。出现网络 metadata refresh、仓库外 cache/临时目录写入、真实 HOME 修改或残留 `tmp/.runtime/` 时，按安全失败停止；只保留报告所需的最小脱敏错误摘要，精确清理本次受管输出。

在没有越界信号时：

- 退出码 `0`：视为完整导出；
- 退出码 `2`：视为部分证据缺失，允许继续 Review，但必须报告缺口；
- 其他退出码：停止并报告，不绕过脚本保护。

### 3. 生成 Zsh 修改建议

完整执行 `$analyze-zsh-configuration`，取得：

- `tmp/zsh-evidence.md`；
- personal 和可选 shared 的 `zsh-repair-plan.md` 候选；
- Zsh 发现摘要、逐块保全清单、证据缺口和自检结果。

必须在 `dump.sh` 完成后运行，避免导出脚本的候选清理删除 Zsh 修复计划。子 Skill 失败时停止并精确清理本次受管输出；不要改由本 Skill 直接读取真实 Zsh。

### 4. Review 已导出文件

完整执行 `$review-exported-dotfiles`。只允许它读取 `tmp/dump.md` 并编辑导出范围内的 Brewfile、tooling 和 `plugins.toml`；确认 `tmp/zsh-evidence.md` 与两个 `zsh-repair-plan.md` 在 Review 前后没有变化。

取得候选文件清单、逐项调整摘要、manual 项、证据缺口和 Review 自检结果。逐项摘要中每个工具必须先给出 Review 已写入的一句话描述，再给出修改级别和本次建议。

### 5. 跨结果自检

合并两个子 Skill 的结果并检查：

- Zsh 建议中的工具所有权、Homebrew 架构和已确认替代关系与导出候选一致。
- personal/shared 无重复或所有权冲突，shared 内容未进入 public。
- public 输出不含本机绝对路径、邮箱、账号、敏感值或私有/内部/带凭证的远程地址；允许配置所需且已审阅的公开插件 source。
- Zsh Skill 只生成修复计划，Review Skill 只修改导出候选，均未越权。
- Zsh 证据中的每个功能块在修复计划中恰有一个处置；源文件、出现序号、相对顺序和加载阶段一致，`retire` 均能追溯到用户明确决定。
- tooling 版本、插件 revision 和每个直接期望项目的六字段 `AI-REVIEW` 完整，首字段是一句话工具描述。
- 未经审阅的机器快照没有直接成为正式配置；未知项均标记 `manual`。
- 正式目录、真实 HOME、软件、服务和 Git 历史尚未被本次流程修改。

把结果并入集中审查摘要，不创建独立审批表。

### 6. 集中展示并确认一次

展示：

1. Zsh 修改建议摘要、功能块保全清单、证据缺口，以及将写入固定本机目录的精确计划文件；
2. 导出配置的逐项调整摘要和 manual 项；每个工具先显示一句话描述，再显示修改级别和建议；
3. public/shared 正式目标与本机 Zsh 修复计划目标；
4. 仓库正式目录到候选目录的全部新增、修改和删除 diff，以及本机修复计划的完整安全 diff；
5. local 参数类别，但不显示值；
6. Stage 1 将生成或更新的 Zsh 目标，以及 Stage 2 将安装或验证的内容；
7. Stage 3 的退役建议；
8. 两个子 Skill 与跨结果自检结论。

然后只询问一次并停止等待：

```text
1. 确认写入上述全部候选文件
2. 要求调整候选文件
3. 取消本次 Stage 0
```

明确说明：确认只授权写入可逆仓库草稿，不授权安装、commit、push 或退役。

### 7. 按决定收尾

- 确认时，先重新检查正式目标、工作区和本机修复计划目标是否发生变化；没有变化时只写入已展示且获准的文件。本机计划按 `0700/0600`、同目录备份和原子替换规则写入，仓库不得获得其正式副本。
- 要求调整时，把 Zsh 建议交回 Zsh Skill，把导出配置调整交回 Review Skill；重新执行对应自检和完整跨结果审查，不直接在编排器里修改内容。
- 取消时不写任何正式文件。
- 确认写入完成、取消或安全失败后，只清理本次已知的 `tmp/zsh-evidence.md`、`tmp/dump.md`、`tmp/my_setup/`、`tmp/shared/` 和 `tmp/.runtime/`，不清空整个 `tmp/`。
- 最后展示正式工作树 diff、local/manual 提示和未解决证据缺口，然后停止；不要自动进入 Stage 1。

## 完成判定

只有两个子 Skill、跨结果自检、用户一次确认、本机 Zsh 修复计划及其他获准草稿写入全部完成，才报告 Stage 0 完成。若用户取消，报告“已取消并清理候选文件”；若本机计划安全写入、任一采集器或子 Skill 失败，报告具体阻断原因，不把部分结果标为完成。
