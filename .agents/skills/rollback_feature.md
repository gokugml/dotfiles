# Rollback Feature（未来功能记录）

> 状态：已从当前四阶段主流程移除，暂不实现<br>
> 日期：2026-08-09

## 1. 目的

本文件集中保存此前阶段文档中已经描述过的 rollback 相关需求，避免它们继续增加当前轻量流程的复杂度。

当前 Stage 0–3 不提供 `rollback` 命令、run-id、action manifest、自动软件卸载或退役恢复。当前唯一保留的保护措施是：`install.sh` 替换本地 Zsh 入口前，为已有 `.zsh` 文件或 symlink 创建副本。

本文件是未来功能 backlog，不是当前实现契约，也不构成任何阶段的完成门禁。

## 2. 未来可能的命令面

此前描述过的命令语义包括：

```text
./install.sh plan
./install.sh apply
./install.sh verify
./install.sh rollback <run-id>
```

如果未来重新引入，应与当前“无参数 `install.sh` 等于 apply”的接口重新评估，不能直接并存造成歧义。

## 3. 配置恢复

此前需求包括：

- 为每次配置写入创建唯一 run-id；
- 在 apply 前保存文件类型、owner、权限、symlink 目标和内容副本；
- 使用 actions manifest 记录执行顺序、结果和反向动作；
- 恢复 `~/.zprofile`、`~/.zshrc`、shared 链接和来源配置；
- 恢复可逆 Git 设置，例如 `core.hooksPath`；
- 验证恢复后的 login/interactive shell；
- 对重复 rollback 保持幂等；
- 提供 backup list/prune，并在清理前预览和确认。

未来设计时必须区分：

- 普通文件副本；
- symlink 本身及其目标；
- 已存在但无内容变更的路径；
- 安装后由用户继续修改的文件；
- backup 已缺失或部分损坏的情况。

## 4. 软件安装回退

此前需求包括：

- 记录本次新增的 Homebrew formula/cask；
- 记录 mise、uv 和其他 tooling 的安装前版本；
- 安装验证失败时生成 cleanup 预览；
- 可选地卸载仅由本次操作新增、且未被其他项目引用的软件；
- 把 runtime/tool 恢复到安装前的明确版本；
- 避免把配置 rollback 扩展为无边界的包管理器清理。

未来若实现，必须先解决：

- Homebrew 缺少通用 lockfile；
- formula/cask 可能被其他项目共享；
- 项目级 mise/uv 配置可能覆盖全局版本；
- 软件安装、数据创建和服务启动并不具有统一反向操作；
- 自动卸载可能比保留新增软件风险更高。

## 5. 服务与数据恢复

此前需求包括为每个有状态服务提供独立 runbook：

- 记录服务启停状态；
- 备份配置和数据；
- 迁移端口、数据目录和 owner；
- 验证目标服务健康；
- 失败时执行服务专属恢复步骤。

当前流程只检测并报告服务/数据，不自动迁移，因此不需要这套 rollback。未来若重新引入，必须按具体服务设计，不得用通用脚本猜测数据库或 GUI 应用数据的恢复方式。

## 6. 退役恢复边界

此前 Stage 3 需求明确：

- Intel Homebrew 正式退役后不自动重装；
- 密钥轮换、明文清理和历史删除不可通过 rollback 恢复；
- 未在退役清单中的 `/usr/local` 内容不得处理；
- 部分退役失败时，只修复 ARM 替代，不用自动重建 Intel 环境。

这些不可逆边界未来仍应保留。即使实现配置或软件 rollback，也不应宣称能够完整恢复 Stage 3。

## 7. 状态与追溯

此前设计使用：

```text
~/.local/state/dotfiles/
├── backups/<config-run-id>/
├── manifests/<config-run-id>/
├── reports/<config-run-id>/
├── migrations/<migration-run-id>/
└── retired-homebrew/<migration-run-id>/
```

并使用 metadata、actions、inventory、ledger、verify 报告和整体 checksum 关联状态。

未来若重新实现，应先证明这些产物对恢复成功率确有价值，再选择最小集合。不得恢复逐条 checksum、重复 TSV 或无法实际执行反向动作的“形式化追溯”。

## 8. 未来启用条件

只有同时满足以下条件，才应把 rollback 重新纳入主流程：

1. 用户明确需要自动恢复，而不仅是保留副本；
2. 已定义清楚可恢复和不可恢复的边界；
3. 能在隔离 HOME 和包管理器 fixture 中验证真实反向动作；
4. 失败或部分恢复时不会进一步破坏系统；
5. 新增状态、manifest 和命令的复杂度明显低于其风险收益。

在此之前，当前主流程继续采用“Zsh 副本 + 安装后验证 + 人工定向处理”的轻量策略。
