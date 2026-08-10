# Dotfiles 可移植性

本领域描述一套可复用的 Dotfiles 能力，如何与可分享的个人配置、公司专属配置和本机私有参数组合为可迁移的 macOS 工作环境。Stage 2 同时支持 Intel 与 Apple Silicon，Stage 3 只处理 Apple Silicon 上旧 Intel 软件的退役。

## Language

**公开仓库（Public Repository）**：
保存通用能力和个人配置的可分享 Git 仓库。
_避免使用_：公开层、个人仓库

**个人配置（Personal Configuration）**：
公开仓库 `my_setup/` 下的可分享 Zsh、软件和工具配置，是默认环境基线。
_避免使用_：public 配置、根配置

**公司配置（Company Configuration）**：
独立私有仓库中的可选公司增量，包括单一 Zsh 文件及公司 Brewfile、tooling 和插件声明。
_避免使用_：公司能力仓库、公司安装框架

**本机私有参数（Local Private Parameters）**：
单台机器 `~/.config/dotfiles/local/parameters.zsh` 中的密钥值、账号、机器路径和其他不可公开参数。
_避免使用_：本地配置层、机器配置

**活动配置（Active Configuration）**：
公司配置、个人配置和本机私有参数按固定顺序加载后的运行时结果。
_避免使用_：public-company-local 三层栈

**源机器（Source Machine）**：
提供 Zsh 与软件现状供 Stage 0 分析的机器。

**目标机器（Target Machine）**：
运行 `install.sh`，应用仓库配置并安装已确认软件的 macOS 机器。Intel 使用 `/usr/local` Homebrew，Apple Silicon 原生会话使用 `/opt/homebrew` Homebrew；它可以与源机器是同一台设备。

**Dump（配置采集）**：
通过只读 `dump.sh` 优先调用软件和工具的原生 Dump/List，把脱敏状态写入当前仓库被忽略的 `tmp/` 同构候选树。它不读取 Zsh 启动文件，不修改真实配置或软件。

**Zsh 分析（Zsh Analysis）**：
通过独立 Zsh Skill 的确定性脚本提取启动文件的脱敏结构证据，再由 AI 按 Skill 内置手册生成 `zsh-repair-plan.md` 修改建议。它不生成或修改最终 Zsh 文件。

**Zsh 修复应用（Zsh Repair Application）**：
Stage 1 通过独立 Skill 把已确认的 `zsh-repair-plan.md` 应用到用户显式提供的 `.zshrc`、`.zprofile` 目标；没有显式目标时更新公开仓库的默认 Zsh 文件和可选 company 增量。它尽可能保留现有 Oh My Zsh 模板配置，不建立 symlink 或安装软件。

**install.sh 能力计划（Install Capability Plan）**：
独立于 Stage 编号的仓库能力建设需求，定义根 `install.sh`、内部安装模块、`dump.sh`、测试、文档和 CI。它不生成最终 Zsh 文件，也不代表 `./install.sh plan` 子命令。

**导出审阅（Export Review）**：
通过独立 Review Skill 审阅当前仓库 `tmp/` 中由 `dump.sh` 已导出的 Brewfile、tooling 和插件候选，补充结构化 AI 评论。它不运行采集、不分析 Zsh 文件、不执行正式写入。

**安装（Install）**：
Stage 2 通过无参数 `install.sh` 备份本地 Zsh 入口、建立 symlink，并按当前机器原生硬件架构安装 personal/company 声明的配置与软件。Apple Silicon 的 Rosetta 会话不得回退使用 Intel Homebrew。

**退役（Retire）**：
Stage 3 只在 Apple Silicon 上通过 `install.sh retire` 预览，并通过 `install.sh retire --apply` 删除已有 ARM 替代或已明确淘汰的旧 Intel 软件；Intel Mac 不进入 Stage 3。

## Core mappings

| 语义 | 固定位置 |
|---|---|
| 通用能力 | 公开仓库根 |
| 个人配置 | `<public-repository>/my_setup/` |
| 公司配置 | 可选的独立 company 仓库 |
| 本机私有参数 | `~/.config/dotfiles/local/parameters.zsh` |

Zsh 加载顺序固定为 `company → personal → local`，因此覆盖优先级为 `company < personal < local`。
