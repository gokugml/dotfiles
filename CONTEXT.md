# Dotfiles 可移植性

本领域描述一套可复用的 Dotfiles 能力，如何与可分享的个人配置、与他人共用的共享配置和本机私有参数组合为可迁移的 macOS 工作环境。Stage 2 同时支持 Intel 与 Apple Silicon，Stage 3 只处理 Apple Silicon 上旧 Intel 软件的退役。

## Language

**公开仓库（Public Repository）**：
保存通用能力和个人配置的可分享 Git 仓库。
_避免使用_：公开层、个人仓库

**个人配置（Personal Configuration）**：
公开仓库 `my_setup/` 下的可分享 Zsh、软件和工具配置，是默认环境基线。
_避免使用_：public 配置、根配置

**共享配置（Shared Configuration）**：
独立 shared 仓库中与他人共用的可选配置增量，包括单一 Zsh 文件及共享 Brewfile、tooling 和插件声明。
_避免使用_：共享能力仓库、共享安装框架

**本机私有参数（Local Private Parameters）**：
单台机器 `~/.config/dotfiles/local/parameters.zsh` 中的密钥值、账号、机器路径和其他不可公开参数。
_避免使用_：本地配置层、机器配置

**本机功能集成（Local Functional Integrations）**：
单台机器可选的 `~/.config/dotfiles/local/integrations.zsh`，保存由第三方安装器追加且不能公开的 Zsh 功能块，并通过四个 pre/post 阶段加载。
_避免使用_：第四配置层、本机软件清单

**活动配置（Active Configuration）**：
第三方 pre 钩子、共享配置、个人配置、本机私有参数和第三方 post 钩子按固定阶段加载后的运行时结果。
_避免使用_：public-shared-local 三层栈

**源机器（Source Machine）**：
提供 Zsh 与软件现状供 Stage 0 分析的机器。

**目标机器（Target Machine）**：
运行 `install.sh`，应用仓库配置并安装已确认软件的 macOS 机器。Intel 使用 `/usr/local` Homebrew，Apple Silicon 原生会话使用 `/opt/homebrew` Homebrew；它可以与源机器是同一台设备。

**Dump（配置采集）**：
通过只读 `dump.sh` 优先调用软件和工具的原生 Dump/List，把脱敏状态写入当前仓库被忽略的 `tmp/` 同构候选树。它不读取 Zsh 启动文件，不修改真实配置或软件。

**Zsh 分析（Zsh Analysis）**：
通过独立 Zsh Skill 的确定性脚本提取启动文件的脱敏结构证据与第三方功能块保全清单，再由 AI 按 Skill 内置手册生成 `zsh-repair-plan.md` 修改建议。它不生成或修改最终 Zsh 文件。

**Zsh 修复应用（Zsh Repair Application）**：
Stage 1 通过独立 Skill 把已确认的 `zsh-repair-plan.md` 应用到用户显式提供的 `zshrc`/`.zshrc`、`zprofile`/`.zprofile` 目标；没有显式目标时先让用户选择无前置点或有前置点仓库命名，再更新对应文件、可选 shared 增量和获准的本机 `integrations.zsh`。写入前后逐块比较源 Zsh 与目标加本机 integrations，缺块即失败。它尽可能保留现有 Oh My Zsh 模板配置，不建立 symlink 或安装软件。

**install.sh 能力计划（Install Capability Plan）**：
独立于 Stage 编号的仓库能力建设需求，定义根 `install.sh`、内部安装模块、`dump.sh`、测试、文档和 CI。它不生成最终 Zsh 文件，也不代表 `./install.sh plan` 子命令。

**导出审阅（Export Review）**：
通过独立 Review Skill 审阅当前仓库 `tmp/` 中由 `dump.sh` 已导出的 Brewfile、tooling 和插件候选，补充结构化 AI 评论。它不运行采集、不分析 Zsh 文件、不执行正式写入。

**安装（Install）**：
Stage 2 通过无参数 `install.sh` 从 `my_setup/zsh/` 中唯一完整的无前置点或有前置点来源组备份并建立固定的 HOME Zsh 入口 symlink，再按当前机器原生硬件架构安装 personal/shared 声明的配置与软件。Apple Silicon 的 Rosetta 会话不得回退使用 Intel Homebrew。

**退役（Retire）**：
Stage 3 只在 Apple Silicon 上通过 `install.sh retire` 预览，并通过 `install.sh retire --apply` 删除已有 ARM 替代或已明确淘汰的旧 Intel 软件；Intel Mac 不进入 Stage 3。

## Core mappings

| 语义 | 固定位置 |
|---|---|
| 通用能力 | 公开仓库根 |
| 个人配置 | `<public-repository>/my_setup/` |
| 共享配置 | 可选的独立 shared 仓库 |
| 本机私有参数 | `~/.config/dotfiles/local/parameters.zsh` |
| 本机功能集成 | `~/.config/dotfiles/local/integrations.zsh`（可选） |

声明式 Zsh 覆盖顺序固定为 `shared → personal → parameters`，因此覆盖优先级为 `shared < personal < parameters`；`integrations.zsh` 通过 `zprofile-pre/post` 与 `zshrc-pre/post` 阶段钩子加载，不参与覆盖层命名。
