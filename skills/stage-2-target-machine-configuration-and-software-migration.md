# Stage 2：目标机器配置与软件迁移需求

> 状态：实施级阶段需求<br>
> 版本：1.0<br>
> 日期：2026-08-09<br>
> 执行角色：每台目标机器的用户与实施 Agent<br>
> 执行位置：Apple Silicon macOS 目标机器

## 1. 阶段定位

本阶段消费阶段 1 已交付的可移植仓库能力，在目标机器建立 Zsh 配置、私有分层和可回滚状态，再由独立迁移脚本安装并验证关键 ARM 软件和工具链。目标是让用户无需回忆或手工复刻源机器步骤，即可重建经过审批的关键工作环境。

目标机器可以是另一台新机器，也可以是源机器本身。无论是否存在 Intel Homebrew，都必须从仓库产品接口开始，不能直接复制旧 `.zshrc` 或跳过计划、备份和验证。

执行前必须阅读 [四阶段共用契约](./stage-common-contract.md) 和 [Stage 1：可移植 Dotfiles 能力建设](./stage-1-portable-dotfiles-capability-build.md)。命令职责、目录、分层、工具所有权和不可代理动作均引用共用契约。

下一阶段：[Stage 3：Intel Homebrew 退役](./stage-3-intel-homebrew-retirement.md)。阶段 2 完成后允许长期停留，不自动进入阶段 3。

## 2. 阶段目标

1. 取得并验证阶段 1 的 public 仓库及可选 company 来源。
2. 在真实目标机器执行只读 preflight，生成明确的配置应用计划。
3. 备份现有有效 Zsh 配置，建立两个真实入口 symlink 和固定 private source 点。
4. 把密钥从普通 shell 配置迁移到 Keychain wrapper 或获批 local-only 例外。
5. 由独立迁移脚本盘点目标机器现状，安装缺失的 ARM 关键软件和固定版本工具链。
6. 迁移已授权的服务、数据和工具所有权，验证 ARM 替代关系。
7. 生成可供阶段 3 使用的本机 migration manifest、retirement ledger 和 readiness 状态。
8. 明确结束于“配置与 ARM 迁移完成，Intel Homebrew 未退役”。

## 3. 非目标

- 不从目标机器旧配置反向修改或提交阶段 1 仓库。
- 不把目标机器 inventory、backup、manifest、密钥状态或退役账本回传仓库。
- 不由 `install.sh` 安装软件或执行 Homebrew 写操作。
- 不在普通迁移 `--apply` 中卸载 Intel Homebrew。
- 不自动执行阶段 3 预览或正式退役。
- 不自动安装 Mac App Store 应用，不处理 Apple ID 或 GUI 应用数据。
- 不迁移 macOS 系统偏好、`.gitconfig`、SSH、tmux、编辑器配置等首期范围外内容。

## 4. 前置条件与输入

### 4.1 仓库基线

- public 仓库已经通过阶段 1 的隔离测试、CI 和安全扫描。
- 当前 checkout 与预期 origin、目录结构和 commit 基线一致。
- `install.sh`、`bin/dotfiles` 和独立迁移脚本存在且权限正确。
- public 配置不含 Intel 运行时路径、密钥或公司信息。

### 4.2 本机输入

- 当前架构、shell 启动文件、symlink、PATH 和命令实际来源。
- 已有个人/company checkout 或安全的来源 URL。
- 当前关键软件、Brew formula/cask/service、语言运行时和工具管理器状态。
- 需要保留的 API key 变量名及其消费命令；不得收集值到报告。
- 有状态服务的数据位置、迁移方式和验证命令。

### 4.3 受限执行

本机数据不足时仍可生成只读 plan，但不得宣称配置、软件迁移或退役准备完成。非原生 `arm64` 会话阻止所有写模式，不创建 Intel 兼容配置。

## 5. 阶段流程

```text
2A 来源解析和只读 preflight
  → 2B 备份、密钥边界和配置应用
    → 配置 verify 后停止在配置边界
      → 2C 独立软件迁移 plan
        → 获得必要外部授权
          → 迁移 --apply 与 --verify
            → 2D 综合验证并生成退役准备度
```

配置应用和软件迁移必须是两个独立显式动作，使用不同 run-id、manifest 和回滚语义。Agent 不得因用户要求“配置新机器”而省略二者之间的验证边界。

## 6. 子阶段 2A：来源解析与安全 Preflight

### 6.1 启动入口

用户 clone 或取得阶段 1 public 仓库后，必须从以下只读入口之一开始：

```zsh
./install.sh
./install.sh plan
```

首次运行应自动探测：

- 当前 checkout 的 personal 来源、origin 和仓库根。
- 已存在且获授权的 company checkout。
- 本机 `sources.toml` 是否与实际 checkout 一致。
- local-only 固定目录和已有私有文件。

证据唯一时直接写入计划；company 不存在或无访问权时标记 `skip`。只有出现多个冲突来源且无法从证据排除时，才汇总为一个阻塞问题。不得逐文件询问路径。

### 6.2 Zsh 和架构盘点

必须脱敏收集：

- `uname -m`、`arch` 和当前进程架构。
- `.zshenv/.zprofile/.zshrc/.zlogin` 的类型、source 链和有效配置。
- login、interactive、non-login interactive 场景。
- PATH/fpath、命令来源、二进制架构、OMZ/`compinit` 和插件加载。
- 环境变量名称和疑似 Keychain 外密钥的来源定位。

`install.sh` 只检查当前 Homebrew 命令是否符合 ARM 运行时要求，不负责 Intel formula/cask/service/data 的完整盘点；这些由后续迁移脚本独占。

### 6.3 配置计划

配置 plan 必须列出：

- 个人/company/local 来源和目标路径。
- 现有 `~/.zprofile`、`~/.zshrc` 的类型与备份动作。
- 两个真实入口 symlink 的目标。
- company 稳定 symlink 的创建、更新或缺失处理。
- local-only 固定文件及权限。
- Oh My Zsh、插件和 Git hook 的固定 revision/版本。
- 疑似密钥的脱敏处置状态。
- 每项变更的风险、可逆性、验证和回滚动作。

本子阶段输出本地 inventory 和 plan，不生成 Intel 退役账本。

## 7. 子阶段 2B：配置应用

### 7.1 密钥边界

配置切换前，对需要保留的 API key：

1. 记录变量名、消费命令和是否支持单命令 wrapper，不记录值。
2. 使用隐藏输入把值写入 Keychain，并验证 wrapper 只向当前命令注入。
3. Keychain 迁移与配置 apply 分开记录。
4. 密钥轮换、明文清理和历史定向删除分别请求用户授权，不随 symlink apply 暗中执行。
5. 无法临时注入的工具只能使用符合共用契约权限要求的 local-only 例外。

### 7.2 旧配置迁移账本

切换前必须为当前旧 Zsh 的每条有效配置记录：

- 原始来源定位和功能。
- public/company/local-only/retire/unresolved 归属。
- 阶段 1 新配置中的对应位置或明确淘汰理由。
- 验证方法。

存在未解释但仍有效的配置时，阻止 symlink 切换。目标机器的新发现若应改进仓库，必须形成反馈并重新走阶段 0/1，不能在本阶段直接提交通用配置。

### 7.3 应用顺序

用户或 Agent 在展示 config run-id 和最终计划后，显式运行：

```zsh
./install.sh apply
```

实现顺序必须是：

1. 获取 lock，重新验证计划未漂移。
2. 创建配置 backup 和 manifest。
3. 保存现有入口的文件类型、权限、owner、symlink 目标和非敏感内容。
4. 建立 `~/.zprofile -> <public-root>/zsh/.zprofile`。
5. 建立 `~/.zshrc -> <public-root>/zsh/.zshrc`。
6. company 启用时幂等建立 `~/.config/dotfiles/company -> <selected-company-root>`；`skip` 时确保链接不存在。
7. 配置 local-only 固定目录、文件和权限。
8. 获取并验证固定 revision 的 Oh My Zsh 和外部插件；它们作为 Zsh 配置运行依赖，不得借此调用包管理器安装其他软件。
9. 配置仓库跟踪的 pre-commit hook 并记录可回滚的 `core.hooksPath` 原值；固定版本 Gitleaks 尚不存在时，将其记为后续软件迁移前置项，不由 `install.sh` 安装。
10. 验证固定 profile/pre/rc source 点和覆盖顺序。
11. 写入 config manifest，并在配置边界停止。

`apply` 不得调用迁移脚本、安装 Brewfile 项、清理软件或卸载 Homebrew。

### 7.4 配置验证与回滚

立即运行：

```zsh
./install.sh verify
```

必须验证：

- 所有启用 Zsh 文件通过 `zsh -n`。
- 三种 shell 场景无加载错误。
- symlink 目标、company 状态和三层覆盖正确。
- OMZ 模板、`compinit` 次数、插件顺序和 revision 正确。
- PATH 唯一、无受管 Intel 兼容路径，`~/.local/bin` 正确。
- Keychain wrapper 和 local-only 权限不泄露值。
- 再次 `apply` 幂等。

配置验证失败时，停止软件迁移并使用：

```zsh
./install.sh rollback <config-run-id>
```

回滚只恢复配置、symlink、来源、选择和可逆 Git 设置，不撤销密钥轮换或明文清理。

## 8. 配置阶段产物

```text
~/.local/state/dotfiles/manifests/<config-run-id>/metadata.toml
~/.local/state/dotfiles/manifests/<config-run-id>/actions.tsv
~/.local/state/dotfiles/backups/<config-run-id>/...
~/.local/state/dotfiles/reports/<config-run-id>/plan.md
~/.local/state/dotfiles/reports/<config-run-id>/verify.md
```

`actions.tsv` 至少记录顺序、动作类型、目标、修改前类型、备份相对路径、结果和回滚动作。报告不得保存配置全文或密钥值。

## 9. 子阶段 2C：独立软件与工具迁移

### 9.1 迁移计划

配置 verify 通过后，必须由新的显式操作启动：

```zsh
./scripts/migrate-intel-homebrew-to-arm.sh
```

脚本只读盘点：

- Intel/ARM Homebrew 的 tap、formula、leaf、cask、service、配置和数据目录。
- 当前 ARM Homebrew 健康状态；缺失时在计划中给出受保护的安装前置动作，不得由 `install.sh` 补装。
- NVM/npm global、pyenv/Python、pipx/uv tool、Bun/pnpm/Go、mise 的当前所有权。
- public/company/local 三层 Brewfile 的合并期望与冲突。
- 每个旧项目的 ARM 替代、改名替代、其他管理器接管、明确淘汰或 unresolved 状态。
- cask 的 ARM/Universal、替代或淘汰分类。
- service 的运行状态、配置、数据、端口、停机风险和验证命令。

迁移 plan 必须区分：

- 可自动且可验证的安装动作。
- 会修改软件但可重试的动作。
- 有状态服务启停和数据迁移等不可代理动作。
- cleanup 预览。
- 阻止进入阶段 3 的 unresolved 项。

### 9.2 外部授权

Agent 先根据证据完成内容分类和替代决策，不逐项询问。只有以下动作需要集中请求用户授权：

- 安装过程中必须执行的外部供应链脚本。
- 启动或停止有状态服务。
- 执行服务数据迁移 runbook。
- 其他会实质影响外部系统或不可恢复数据的动作。

授权不得扩展为阶段 3 的退役许可。

### 9.3 迁移应用

计划和授权满足后，显式运行：

```zsh
./scripts/migrate-intel-homebrew-to-arm.sh --apply
```

`--apply` 必须：

1. 获取独立 migration lock 和 run-id。
2. 再次验证原生 `arm64`、计划时效和仓库配置状态。
3. 根据三层 Brewfile 安装缺失的 ARM 系统 CLI、原生库和获准 cask。
4. 安装或配置固定版本 mise、Bun、Node、pnpm、Go 和跨项目 CLI。
5. 使用 uv 安装明确 Python 版本、迁移 venv/tool 所有权并移除 pyenv/pipx 重复管理关系。
6. 将 autojump 数据迁移到 zoxide，验证后只在账本中标记旧工具可退役。
7. 根据已授权 runbook 迁移服务配置和数据，逐项验证状态、端口和数据。
8. 更新 retirement ledger 中的替代路径、架构、版本和验证结果。
9. 生成新增软件 cleanup 预览，但不自动卸载其他项目可能依赖的软件。
10. 保留 Intel Homebrew，不调用阶段 3 路径。

在没有 Intel Homebrew 的新目标机器上，脚本仍需完成 ARM 关键软件和工具链期望状态验证，并将 Intel 迁移标记为不适用；不得伪造 retired record。

### 9.4 退役账本

每个 Intel 项必须记录共用契约和阶段 1 定义的字段及目标状态。以下情况保持 `unresolved`：

- 找不到可验证替代且未明确淘汰。
- 运行中的 Intel service 未处理。
- cask 架构或替代状态不明。
- `/usr/local/var`、`/usr/local/etc` 或其他路径包含未知服务数据。
- 替代命令路径、架构或版本验证失败。

`unresolved` 不否定已通过的 Zsh 配置应用，但会阻止阶段 3。

## 10. 软件迁移产物

```text
~/.local/state/dotfiles/migrations/<migration-run-id>/
├── metadata.toml
├── inventory.tsv
├── retirement-ledger.tsv
├── actions.tsv
├── reports/
│   ├── plan.md
│   └── verify.md
└── status.toml
```

迁移 run-id 不得复用 config run-id。普通迁移不生成阶段 3 的 `retirement-manifest.sha256`。

## 11. 子阶段 2D：综合验证与退役准备

依次执行：

```zsh
./install.sh verify
./scripts/migrate-intel-homebrew-to-arm.sh --verify
./scripts/migrate-intel-homebrew-to-arm.sh --status
```

### 11.1 配置验证

- 干净 login shell 和 IDE 风格 non-login interactive shell 正常。
- 两个真实入口和三层固定 source 点正确。
- OMZ、插件、补全、history、alias、function 和 wrapper 正常。
- public/company/local-only 不含 Intel 运行时兼容。

### 11.2 软件验证

- `arch` 为 `arm64`。
- `command -v brew` 与 `brew --prefix` 指向 `/opt/homebrew`。
- Homebrew 管理的关键工具和 cask 符合期望状态。
- Bun、Node、pnpm、Go 等由 mise 管理且二进制为 ARM。
- Python 由 uv 管理，明确版本和 tool 可用。
- 服务配置、端口和数据通过对应 runbook 验证。
- retirement ledger 每项都有当前状态，readiness 明确。

### 11.3 阶段终态

阶段结束时必须停止，并在 manifest/status 中明确写入：

```text
本地配置与 ARM 软件迁移完成。
Intel Homebrew 未由本阶段退役。
```

readiness 可以是：

- `ready`：存在 Intel Homebrew，全部项目已归类并通过替代验证，可由用户另行进入阶段 3。
- `blocked`：配置可用，但退役账本仍有阻断项。
- `not-applicable`：目标机器不存在 Intel Homebrew，无需阶段 3。

## 12. 失败与恢复

- 配置 apply 失败：停止迁移，按 config run-id 回滚可逆配置。
- 软件迁移中断：保留 migration run-id 和已完成 actions，使用 plan/status 判断安全重试点，不回退到 Intel PATH。
- 新软件安装成功但后续验证失败：记录 cleanup 预览和修复建议，不由配置 rollback 自动卸载。
- 服务迁移失败：使用该服务专属 runbook 回滚，不由通用脚本猜测数据恢复。
- 密钥轮换或明文清理完成后：不可通过配置 rollback 恢复旧值。
- 发现应进入 public/company 的新通用需求：生成反馈证据，重新执行阶段 0/1，不在目标机器直接修改仓库基线。

## 13. 完成条件

- [ ] public/company 来源已解析，工作区和 commit 基线通过验证。
- [ ] 目标机器写模式为原生 `arm64`。
- [ ] 配置 plan、backup、manifest 和两个真实入口 symlink 完成。
- [ ] company 启用或 `skip` 状态正确且 apply 幂等。
- [ ] local-only 固定文件、Keychain wrapper 和权限符合共用契约。
- [ ] `install.sh verify` 通过，配置 apply 未触发任何 Homebrew 写操作。
- [ ] 独立迁移脚本完成 plan、`--apply` 和 `--verify`。
- [ ] 关键 ARM 软件、固定版本工具链和语言环境已安装并通过实际路径/架构验证。
- [ ] formula/cask/service/data 和旧工具管理器均有迁移处置状态。
- [ ] 配置与迁移使用不同 run-id、manifest 和状态目录。
- [ ] inventory、backup、报告和账本仅保存在当前机器且不含密钥值。
- [ ] Intel Homebrew 未退役，readiness 明确为 `ready`、`blocked` 或 `not-applicable`。
- [ ] 没有自动启动阶段 3。

## 14. 未来 Skill 接口

未来 Skill 名：`stage-2-target-machine-configuration-and-software-migration`。

推荐触发语义：在 Apple Silicon 目标机器上，使用已交付 Dotfiles 仓库应用配置并迁移关键软件。Skill 必须识别并保持三个显式边界：配置 plan/apply/verify、软件迁移 plan/apply/verify、阶段结束。

Skill 应把 schema 和详细验证矩阵放在 `references/`，把来源解析、隔离 plan、manifest 校验和架构验证沉淀为确定性脚本。它必须拒绝在阶段 1 仓库未通过门禁时执行，也必须拒绝把“迁移完成”解释为“允许退役”。
