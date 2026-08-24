---
name: stage-2-target-machine-configuration-and-software-migration
description: 编排 macOS 目标机器 Stage 2：只读取当前 checkout 的公开仓库与可选 shared 仓库声明，把已启用的 macOS、tooling 和可选 Zsh 配置安装到当前机器原生架构对应的精确目标，再运行 `install.sh verify` 验证安装完整性；若存在 `my_setup/tooling/global-cli-migration.toml`，先询问用户是否在本机迁移其中的可选全局 CLI，缺失或跳过都不阻断基础安装。支持只 checkout 根安装器及 `my_setup/macos/`、`my_setup/tooling/` 的目标机部署；不依赖 Stage 0、Stage 1、`zsh-repair-plan.md`、本机待迁移 TSV 或其状态。Apple Silicon 上若仍有 Intel 残留，verify 生成本机 `intel_to_be_retired.tsv` 供 Stage 3 重新核验。用于多台 macOS 机器应用仓库配置、建立受管 symlink、安装 Homebrew 软件、mise/uv runtime、用户选择的全局 CLI 或可选 Zsh/plugin；不生成或修复仓库配置，不读取 local 密钥值，不迁移服务数据、进入 Stage 3、commit 或 push。
---

# Stage 2：从仓库配置目标机器

把当前 checkout 的声明直接部署到当前 macOS：

```text
仓库声明 + 可选全局 CLI 询问 + 原生架构 → ./install.sh → 脚本内 y/N
  → ./install.sh verify → 安装完整性 + 可选 Intel 退役交接
```

Stage 2 是独立部署阶段。不得读取或验证 Stage 0/1 状态、Stage 1 的本机 `global_cli_to_be_migrated.tsv`、`zsh-repair-plan.md`、历史 diff 或用户在其他机器上的确认记录。`my_setup/tooling/global-cli-migration.toml` 若存在，只因它是当前 checkout 的可分享 tooling 声明而参与本机可选询问，不构成对 Stage 1 的依赖。

## 执行前计划门

先只读检查当前 public/shared checkout、工作树、已启用模块、声明式配置、安装器能力、当前机器原生硬件架构、进程架构、Homebrew 路径、目标 symlink 和 local 路径元数据。不要读取 local 正文、运行安装器或修改系统。

随后展示：

- 当前 checkout 的 commit、diff、public/shared 来源和启用/跳过模块；
- 每个仓库 source、本机 target、安装动作及原生 Homebrew 前缀；
- Brewfile 软件、mise/uv runtime、可选 Zsh/plugin、网络与磁盘影响；
- `my_setup/tooling/global-cli-migration.toml` 是否存在、schema/条目摘要、安装器是否支持，以及本机全部迁移、逐项选择或跳过都不会改变基础模块依赖的语义；
- Apple Silicon 上 `intel_to_be_retired.tsv` 的路径、schema、权限和仅供 Stage 3 参考的语义；
- 服务/数据人工事项、A/B 验证、失败停止点，以及不会执行的仓库开发初始化、配置生成、Stage 3、commit 和 push。

展示后停止并等待用户明确确认。执行前重新检查 checkout、声明、目标和架构；实质变化时更新计划并再次确认。该确认只授权进入安装器，不替代 `install.sh` 内默认 `N` 的 `y/N`。

## 权威输入与模块发现

唯一权威输入是当前 checkout 中的文件：

- 必需：根 `install.sh`、完整的 `my_setup/macos/` 和完整的 `my_setup/tooling/`；这是目标机 sparse checkout 的最小安装集合；
- macOS：`my_setup/macos/install.sh` 与 `Brewfile`；
- tooling：`my_setup/tooling/install.sh`、实际存在的 mise/uv 声明，以及可选的 `my_setup/tooling/global-cli-migration.toml`；
- Zsh（可选）：`my_setup/zsh/install.sh`、`plugins.toml`，以及 `zprofile` + `zshrc` 或 `.zprofile` + `.zshrc` 中恰好一套；
- shared（可选）：显式 `DOTFILES_SHARED_DIR` 指向的现有 Git checkout 中与已启用模块对应的增量。

Brewfile 只允许 `tap`、`brew`、`cask`、`vscode` 的直接声明，不执行参数或动态 Ruby。每个直接期望项目推荐使用同一行的一句话说明，例如 `brew "ripgrep" # 快速递归搜索文本`；行尾注释与声明之间必须有空白且内容非空。安装器解析 personal/shared Brewfile 时接受这种注释，但写入临时 effective Brewfile 时只保留规范化声明，不把注释当作参数或安装语义。独立整行注释仍可用于分组或 AI 审阅说明。

按模块目录完整性启用能力：

1. macOS 或 tooling 模块目录、内部入口、必需声明缺失或残缺时，在确认前阻断；不得静默降级。
2. 只 checkout 根安装器、macOS 和 tooling 时必须可以计划、安装和验证；不得要求 Zsh 文件或 `zsh-repair-plan.md`。
3. Zsh 目录与内部入口都不存在时标为未 checkout/未启用并继续；只存在一部分时阻断，避免误以为 Zsh 已安装。
4. Zsh 模块存在时直接使用唯一完整命名组；两套并存、混搭或残缺时阻断 Zsh 模块，不猜优先级、不生成文件。
5. shared 只能扩展已启用的 personal 模块，不能单独提供安装框架。

可选全局 CLI 声明缺失时静默跳过，不视为 tooling 残缺；存在时必须完整读取并遵守 [Stage 1 全局 CLI 迁移交接协议](../stage-1-apply-zsh-repair-plan/references/global-cli-migration.md)的 public schema 和 Stage 2 可选消费边界。Stage 2 不读取同协议中的本机 TSV。

## 只读事实查询

为解析精确目标允许执行最小只读查询：

- `command -v`、`type -a`、`file`、版本和帮助命令；
- 管理器明确只读的 `config get`、`bin`、`root`、`prefix`、`env`、`list`；
- `pnpm --version`、`pnpm config get global-bin-dir`、`pnpm bin -g`、`pnpm root -g`；
- `uname`、`arch`、`sysctl`、原生 `brew --prefix`。

不要运行会安装、更新、删除、写配置、刷新 metadata/cache、启停服务或产生不必要网络访问的查询。可选全局 CLI 的版本和 binary 从 manager metadata、安装 manifest 与受管路径核验，不执行这些业务 CLI 的 `--version`、`version`、`doctor`、首次运行或 login 命令，因为它们可能自更新或初始化。只记录当前判定所需字段，不输出完整环境、local 值、凭证或无关本机路径。单个未安装工具若已由仓库声明，交给安装器安装并在 verify 核验；只有歧义影响精确目标、来源、架构或敏感边界时才阻断对应模块。

## 原生架构与 Homebrew

1. 确认系统为 macOS，以 `sysctl -in hw.optional.arm64` 等硬件事实区分 Apple Silicon 与 Intel。
2. 同时记录 `uname -m`、`arch` 和 `sysctl -in sysctl.proc_translated`。
3. Apple Silicon 原生目标固定为 `/opt/homebrew`，Intel 固定为 `/usr/local`。
4. Apple Silicon 的 Rosetta/非原生会话只允许只读计划，真实安装前停止；不得回退使用 Intel Homebrew。
5. 安装器必须即时验证原生 `brew --prefix`，并让所有受管命令和 symlink 最终解析到当前系统原生目标。
6. 另一架构软件或 PATH 可以暂时存在，但不得替代受管目标；Apple Silicon 上将其写入退役交接，不在 Stage 2 删除、禁用或改写。

原生 Homebrew 入口缺失、硬件事实矛盾或安装器不能支持当前原生前缀时停止并报告能力缺口，不猜路径、不使用不透明 `curl | shell`。

## 硬边界

- 不生成、编辑或修复 checkout 中的 Zsh、Brewfile、tooling 或 plugin 声明；输入错误时报告精确文件。
- 不直接编辑真实 `~/.zprofile`、`~/.zshrc`；仅允许获准后的根安装器备份并建立 symlink。
- 不读取、显示、复制或持久化 local `parameters.zsh`、`integrations.zsh` 正文；只检查类型、owner、权限和无输出语法。
- 不覆盖与安装范围冲突的用户未确认修改或未知受管目标。
- 不启停服务，不迁移数据库、Homebrew service 或 GUI 数据，不清理未知软件、项目 runtime 或另一架构目录。
- 本机 Intel 盘点只写 `${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/intel_to_be_retired.tsv`；不写入仓库，也不构成删除授权。
- 不调用 `install.sh retire` 或 `retire --apply`，不进入 Stage 3，不 commit 或 push。
- 不安装 Git hook，不设置 `core.hooksPath`，不运行或报告 smoke、pre-commit、CI；这些仓库开发能力独立于多机 Stage 2。
- 不把可选全局 CLI 声明缺失、用户跳过或安装器尚不支持该 schema 当作基础 Stage 2 的失败；也不得绕开根安装器临时执行 `bun add -g`、`npm install -g`、`pnpm add -g` 或等价命令。

## 安装工作流

### 1. 预检

1. 检查 public/shared `git status --short`，记录已有用户变更和冲突。
2. 发现模块并验证每个已启用模块的声明可解析、目标唯一、内部入口不可直接执行；Brewfile 预检必须按安装器同一语法接受并推荐 `kind "name" # 一句话说明`，不得把合法行尾注释误判为参数。
3. 让安装器能力能够列出每个精确 `source → target → action`。
4. 判定原生架构、Rosetta、Homebrew 前缀与关键目标路径。
5. 只检查 local 和既有目标的元数据，不读取 local 正文。

### 2. 可选全局 CLI 选择

若 `my_setup/tooling/global-cli-migration.toml` 不存在，跳过本节。存在时先验证 schema、精确来源 `version`、与 `package` 对应的 `<package>@latest` 目标 spec、binary 唯一性、target manager 和无本机路径/敏感内容，并确认根安装器能够在摘要、安装和 verify 中消费该声明。

展示每项 description、package、version、binaries、target manager 和 reason，然后只询问：

```text
1. 在本机迁移声明中的全部全局 CLI
2. 逐项选择本机需要迁移的全局 CLI
3. 本机跳过这份可选迁移声明
```

- 选择 1/2 后，只有所选项加入本次 Stage 2 的安装摘要和验证条件。
- 选择 3 时继续基础 Stage 2，不修改或删除声明，报告本机已跳过。
- 安装器不能消费该 schema 时，先报告可选能力缺口；只有用户明确选择跳过后才能继续基础安装，不得由 Agent 在安装器外补装。
- 这个选择只作用于当前目标机器，不回写 checkout 或本机 Stage 1 TSV；不同目标机必须各自询问。

### 3. 运行安装器

计划获确认、输入未变化、会话原生且安装器支持所选前缀后，从 checkout 根目录在真实终端运行：

```text
./install.sh
```

不添加参数，不代替用户输入 `y`。确认安装器在任何写入前展示：架构与原生前缀、启用/跳过模块、每个精确 source/target/action、软件/runtime/plugin 版本、local 元数据和人工服务/数据事项。

用户在默认 `N` 的集中确认中同意后，由根安装器按 `macOS → tooling（含本机已选全局 CLI）→ 可选 Zsh → verify` 执行。缺失或跳过模块不得被调用；已启用模块及本机已选全局 CLI 的任一声明目标必须全部安装，不能以旧软件已存在代替原生目标。

### 4. 验证

安装器成功后再次运行：

```text
./install.sh verify
```

#### A. 安装完整性

对所有启用模块确认：

- 摘要中的每个配置 symlink、Brewfile 项、mise/uv runtime、插件和命令均存在于精确目标，来源、版本、revision 与架构正确；
- 所有受管命令优先解析到当前机器原生 Homebrew/runtime；另一架构残留不得成为受管目标；
- macOS+tooling 最小 checkout 不要求 Zsh；启用 Zsh 时才验证语法、HOME symlink、加载顺序、启动场景和插件；
- local 为 `0700/0600`、未被 Git 跟踪且内容未泄露；
- 再次安装不会重复备份或破坏正确 symlink；服务和数据仍只报告。
- 本机选择迁移的全局 CLI 必须匹配 package/version/binaries，命令解析到声明的 target manager/原生 runtime；不得以旧 NVM、旧 `PNPM_HOME`、旧 Bun global home 或已移除 PATH 中的副本代替。用户跳过的条目不进入 A 的完成条件。

任一已启用声明项未到位则 A 失败。未 checkout 的可选模块不计为缺失。

#### B. Intel 退役交接

仅 Apple Silicon 执行。确定性维护：

```text
${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/intel_to_be_retired.tsv
```

- 父目录 `0700`、文件 `0600`，固定标记，使用临时文件和原子替换；
- 稳定 TSV 字段为 `kind`、`manager`、`name`、`version`、`path`、`architecture`、`reason`，拒绝或安全编码换行与制表符；
- 只记录管理器清单、命令解析、残留 PATH 或已知全局 runtime/plugin 根确认的精确项目，不递归枚举 `/usr/local`；
- service/data、项目依赖和未知项必须标明保留/待人工处理；每行仅是 Stage 3 线索；
- 有残留时必须安全生成；无残留时只清理由固定标记证明归属的旧文件，未知同名文件不得覆盖；
- Intel Mac 不生成清单并报告 Stage 3 不适用。

Stage 2 只有 A 通过，且 Apple Silicon 上 B 为“已生成”或“无残留”时完成。

### 5. 报告并停止

报告 checkout commit/diff、架构与前缀、启用/跳过模块、可选全局 CLI 声明是否存在和本机选择、每个精确目标及结果、备份、A/B 结论、Intel 清单路径和条目摘要、人工服务/数据事项与未解决缺口。Apple Silicon 上说明 Stage 3 需单独触发；Intel Mac 上说明不适用。

## 失败与完成判定

- checkout 输入残缺或无法解析：安装前停止并报告精确模块/文件；不调用 Stage 0/1 修复。
- 原生架构、Rosetta、前缀或精确目标不明确：不运行安装器。
- 可选全局 CLI 声明不存在或用户跳过：继续基础 Stage 2；不把它报告为缺失。声明存在但 schema 错误时只阻断可选分支，用户明确跳过后可继续基础安装。
- 用户拒绝摘要：报告安装未获确认，不产生写入。
- 部分安装后失败：保留实际状态，报告失败模块和人工修复，不自动卸载。
- A 通过但 B 失败：报告安装目标已到位但 Stage 2 未完成，不删除 Intel 项。

只有当前 checkout 的所有已启用基础声明目标和本机明确选择的可选全局 CLI 完成安装、用户已在安装器内确认、A 通过、B 在适用时通过，且服务/数据未被自动迁移，才报告 Stage 2 完成。可选声明缺失或本机跳过不影响完成；`zsh-repair-plan.md`、Stage 0/1 状态、本机 Stage 1 TSV 和仓库开发/CI 能力均不参与完成判定。
