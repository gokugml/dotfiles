# Dotfiles 可移植性

本领域描述一套可复用的 Dotfiles 能力，如何与可分享的个人配置、公司专属配置和本机私有参数组合为可迁移的 Apple Silicon 工作环境。

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
运行 `install.sh`，应用仓库配置并安装已确认软件的 Apple Silicon 机器。它可以与源机器是同一台设备。

**Dump（配置采集）**：
通过只读 `dump.sh` 收集脱敏的 Zsh、软件和工具状态，供 AI 分析；它不修改真实配置。

**安装（Install）**：
通过无参数 `install.sh` 备份本地 Zsh 入口、建立 symlink，并安装 personal/company 声明的配置与软件。

**退役（Retire）**：
通过 `install.sh retire` 预览，并通过 `install.sh retire --apply` 删除已有 ARM 替代或已明确淘汰的旧 Intel 软件。

## Core mappings

| 语义 | 固定位置 |
|---|---|
| 通用能力 | 公开仓库根 |
| 个人配置 | `<public-repository>/my_setup/` |
| 公司配置 | 可选的独立 company 仓库 |
| 本机私有参数 | `~/.config/dotfiles/local/parameters.zsh` |

Zsh 加载顺序固定为 `company → personal → local`，因此覆盖优先级为 `company < personal < local`。
