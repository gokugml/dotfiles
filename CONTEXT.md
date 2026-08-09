# Dotfiles 可移植性

本领域描述可复用能力、可公开个人配置、公司专属配置和本机私有数据如何组成可迁移的 Apple Silicon 工作环境。

## Language

**公开仓库（Public Repository）**:
同时保存通用 Dotfiles 能力与个人配置的可分享仓库。
_避免使用_：公开层、个人仓库

**个人配置（Personal Configuration）**:
可对外分享并作为每台目标机器默认基线的一整套 Zsh 与软件配置。
_避免使用_：public 配置、根配置

**公司配置（Company Configuration）**:
只包含公司专属 Zsh、软件、工具和诊断增量的可选配置集合。
_避免使用_：公司能力仓库、公司安装框架

**本机私有数据（Local Private Data）**:
只存在于单台机器、用于补齐活动配置的密钥和不可公开参数，不定义软件清单或普通偏好。
_避免使用_：本地配置层、机器配置

**活动配置（Active Configuration）**:
个人配置、可选公司配置和本机私有数据在运行时形成的组合结果。
_避免使用_：public-company-local 三层栈

**源机器（Source Machine）**:
提供经审批 Zsh 与软件期望状态来源的现有机器。
_避免使用_：模板机器、黄金镜像

**目标机器（Target Machine）**:
消费公开仓库及可选公司配置、重建已审批环境的 Apple Silicon 机器。
_避免使用_：克隆机、副本
