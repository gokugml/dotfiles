---
name: stage-2-target-machine-configuration-and-software-migration
description: 编排 macOS 目标机器 Stage 2：读取状态为 `Stage 1 已应用` 的修复计划交接，解析唯一完整的仓库版 Zsh 来源，把根 `install.sh` 声明的全部 Zsh/tooling 配置 symlink、Homebrew 软件、mise/uv runtime 和固定插件安装到当前系统原生架构对应的目标路径，并运行 `install.sh verify` 验证安装完整性。Apple Silicon 上若仍存在 Intel 软件或路径，verify 生成本机 `intel_to_be_retired.tsv` 交接清单供 Stage 3 重新核验；残留 Intel 项本身不阻止 Stage 2，但受管目标未安装到原生路径仍会失败。用于应用已确认配置、迁移 Zsh 与软件或执行 Stage 2；不生成或修复 Zsh，不读取 local 密钥值，不自动迁移服务数据、进入 Stage 3、commit 或 push，CI 状态只在最终报告中呈现而不作为门禁。
---

# Stage 2：目标机器配置与软件安装

把 Stage 1 已应用的仓库配置完整安装到当前 macOS 原生目标路径：

```text
确认 Stage 1 输出与原生架构 → ./install.sh
  → 脚本内 y/N 确认 → ./install.sh verify
  → 安装完整性 + 可选 intel_to_be_retired.tsv 交接
```

本阶段不再生成、修复或审查 `zprofile`/`.zprofile`、`zshrc`/`.zshrc`、`shared.zsh`。这些职责只属于 `$stage-1-apply-zsh-repair-plan`。

## 执行前计划门

先只读检查 public/shared 仓库、工作树、Stage 1 交接、仓库版 Zsh、已确认软件/插件配置、当前机器原生硬件架构、进程架构、Homebrew 路径、安装器能力和 local 路径元数据；不要读取 local 内容、生成 Zsh 草稿或运行安装器。

随后展示完整计划：

- Stage 1 已应用的仓库目标、所采用修复计划的状态字段及当前 diff；
- 检测到的原生硬件、进程状态、预期 Homebrew 前缀和判定证据；
- `install.sh` 要建立的每个精确 symlink 与配置目标，以及软件/tooling/plugin 的原生安装目标、hook、网络和磁盘影响；
- Apple Silicon 上 `intel_to_be_retired.tsv` 的生成位置、字段、权限和 Stage 3 仅参考语义；
- 服务/数据人工事项、验证、失败停止点、测试与 CI 当前状态，以及不会执行的 Zsh 生成、Stage 3、commit 和 push。

展示后停止并等待用户明确确认，再进入安装工作流。执行前重新检查输入、工作树和架构；范围、软件集合、shared 目标、Stage 1 输出或系统状态发生实质变化时，更新计划并再次等待确认。初始确认只授权进入安装器，不替代 `install.sh` 自身默认 `N` 的 `y/N`。

## 读取权威输入

开始前读取：

- [四阶段共用契约](../stage-common-contract.md)和[领域词汇](../../../CONTEXT.md)；
- [`$stage-1-apply-zsh-repair-plan`](../stage-1-apply-zsh-repair-plan/SKILL.md) 的完成交接；实际采用的每份 `zsh-repair-plan.md` 必须只有一个 `> 状态：Stage 1 已应用`；
- public 仓库 `my_setup/zsh/zprofile` + `zshrc` 或 `.zprofile` + `.zshrc` 中 Stage 1 已选且唯一完整的一组，以及可选 shared `zsh/shared.zsh`；
- Stage 0 已确认的软件、tooling 和 `plugins.toml` 配置；
- 已按 [`install-sh-plan.md`](../install-sh-plan.md) 实现并验证的根 `install.sh` 与内部模块；
- 目标机器的只读架构、路径和 Zsh 入口元数据，但不读取 local parameters 或 integrations 正文。

Stage 1 可以独立更新用户显式提供的任意 Zsh 目标，但 Stage 2 安装器只管理 `my_setup/zsh/` 中恰好一套完整来源。无前置点组和有前置点组都受支持，不设置隐式优先级：两套同时存在、跨组混搭或任一组残缺时，在安装确认和任何写入前停止。Stage 1 只更新了仓库外显式目标时，报告映射缺口并停止；不要复制、改名或生成另一套文件来迁就安装器。

## 允许只读事实查询

缺少 Stage 0/1 预先记录的工具版本、命令来源、配置目录或环境语义时，先在目标机器执行最小只读查询，不要直接把“证据不足”升级为安装阻断。此类查询属于执行前盘点、安装摘要核对和安装后验证，不需要额外确认。

允许的查询包括：

- `command -v <tool>`、`type -a <tool>`、`file <resolved-command>` 等来源与架构检查；
- `<tool> --version`、`<tool> version`、`<tool> --help` 等版本和命令面检查；
- 工具明确声明为只读的 `config get`、`bin`、`root`、`prefix`、`env`、`list` 或等价查询；
- 针对 pnpm 的 `pnpm --version`、`pnpm config get global-bin-dir`、`pnpm bin -g`、`pnpm root -g` 等必要检查；
- `uname`、`arch`、`sysctl`、`brew --prefix` 等系统与管理器事实。

执行前确认命令不会安装、更新、删除、写配置、刷新 metadata/cache、启动服务或访问不必要的网络。只记录当前判定需要的字段；local 值、完整环境、本机敏感路径和凭证不得进入日志、报告或仓库。

按以下规则处理结果：

1. 查询确认事实后直接用于安装摘要或验证，不要求上游重复采集。
2. 工具尚未安装但已在声明式配置中确认时，允许安装器按计划安装，再在 `verify` 阶段运行同类只读查询。
3. 查询失败或语义仍有歧义时，先判断该事实是否被本次写入使用。未被使用时标为未解决并继续；只影响单个工具时隔离该工具的判定，不阻塞其他只读预检。
4. 只有无法确认的事实会改变精确写入目标、软件来源、架构选择、敏感边界或破坏性范围时，才阻断对应安装动作；不得因单个工具缺少版本或目录证据而全局阻止 Stage 2。

不得以“缺少 pnpm 版本证据”或“`PNPM_HOME` 目录语义尚未确认”为由，在运行上述只读查询之前停止；查询后仍不明确时，只按实际依赖范围处理。

## 判定机器架构和 Homebrew 路径

以机器原生硬件为准，不以当前进程表面显示的 `x86_64` 直接选择 Intel 路径：

1. 确认系统是 macOS。
2. 使用系统硬件事实（例如 `sysctl -in hw.optional.arm64`）区分 Apple Silicon 与 Intel。
3. 同时记录 `uname -m`、`arch` 和 `sysctl -in sysctl.proc_translated`（字段存在时），识别 Rosetta。
4. Intel Mac 的 Homebrew 前缀固定为 `/usr/local`，入口为 `/usr/local/bin/brew`。
5. Apple Silicon 的 Homebrew 前缀固定为 `/opt/homebrew`，入口为 `/opt/homebrew/bin/brew`。
6. Apple Silicon 上检测到 Rosetta 或非原生 ARM 进程时，允许完成只读计划，但在真实安装前停止并要求从原生 ARM 会话重试；不得因此选择 `/usr/local` Homebrew。

要求安装器即时验证所选原生 `brew --prefix`、全部受管目标的实际路径和关键二进制架构。硬件事实矛盾、原生入口缺失、受管命令最终仍解析到另一架构，或当前 `install.sh` 不能使用当前系统原生目标路径时，停止并报告 [`install-sh-plan.md`](../install-sh-plan.md) 尚未满足的能力缺口，不在本 Skill 内修改安装器。

另一架构 Homebrew、软件或 PATH 条目仍存在不再单独阻止 Stage 2：只要全部声明式受管目标已经安装到当前系统原生路径且运行时优先解析到原生目标，就把 Apple Silicon 上的 Intel 残留写入 `intel_to_be_retired.tsv`，留待 Stage 3 重新核验。不得因此在 Stage 2 删除、禁用或改写 Intel 项。

## 遵守硬边界

- 不生成、编辑或重写任何仓库版或显式目标 Zsh 文件；发现内容问题时返回 Stage 1。
- 不直接编辑、替换或重写真实 `~/.zprofile`、`~/.zshrc`；真实入口只允许由获准后的 `install.sh` 管理。
- 不读取、显示、复制、记录或持久化 `~/.config/dotfiles/local/parameters.zsh`、`integrations.zsh` 内容，只检查路径、文件类型、权限和无输出语法结果。
- 不把 shared 仓库专属内容、本机绝对路径、账号或密钥写入 public 仓库。
- 不覆盖与安装范围重叠的用户未确认修改；输入发生变化时重新计划。
- 不启停服务，不迁移数据库、Homebrew service 或 GUI 应用数据，不清理未知软件、项目 runtime 或另一架构的数据目录。
- 本机软件路径和盘点结果只允许写入安装器受管的 `${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/intel_to_be_retired.tsv`；不得写入 public/shared 仓库或其他长期状态，该文件也不是删除授权。
- 不调用 `install.sh retire` 或 `install.sh retire --apply`，不自动执行 Stage 3。
- 不 commit 或 push。

## 执行工作流

### 1. 预检

1. 检查 public 与可选 shared 仓库的 `git status --short`，把已有变更视为用户内容。
2. 确认实际采用的修复计划状态为唯一的 `Stage 1 已应用`，且最新 Zsh diff 已获用户确认；`my_setup/zsh/` 中恰好存在交接所选的一套完整 Zsh 来源，且没有另一套或混搭残留。
3. 确认根安装器及三个内部模块存在，并能列出当前系统上全部受管 symlink、软件、tooling、runtime 和插件的精确目标；记录测试、pre-commit 和 CI 状态。CI 缺失、未运行或失败只进入最终报告，不得阻止计划、安装或 Stage 2 完成。
4. 检查所有已确认 personal/shared Brewfile、tooling 与插件配置存在且可解析；缺少工具版本、命令来源或目录语义时运行允许的只读查询。
5. 通过只读系统查询判定原生硬件、Rosetta 状态、预期 Homebrew 前缀和安装器兼容性。
6. 记录 local `parameters.zsh`、`integrations.zsh` 是否存在及其权限，不读取内容。

只有经过允许的只读查询后，仍会影响精确写入目标、安装安全、架构选择、敏感边界或来源唯一性的缺口，才阻止对应安装动作。单个工具的版本或目录证据缺口不阻止无关预检，也不能在查询前阻止 `install.sh` 计划阶段。不要在 Stage 2 生成文件来绕过真实安全缺口。

### 2. 运行安装器

只有执行计划获确认、Stage 1 输出未变化、架构判定明确、当前会话原生且安装器支持预期前缀时，才从 public 仓库根目录在真实终端运行：

```text
./install.sh
```

不要添加参数，不要代替用户输入 `y`，不要绕过或预先回答脚本确认。检查脚本在任何写入前即时展示：

- 原生硬件、进程状态、所选 Homebrew 路径和 public/shared 来源；
- 已解析的无前置点或有前置点仓库 Zsh 来源，以及 HOME 入口、现有文件或 symlink 的副本计划；
- personal/shared Brewfile 合并结果；
- tooling、mise/uv 和固定 revision 插件变更；
- public 仓库的 pre-commit hook 配置；
- local 路径和权限状态，但不显示内容；
- 服务、数据库或应用数据的人工事项。

让脚本使用默认 `N` 的一次 `y/N` 集中确认。若对应架构 Homebrew 等基础工具缺失，要求脚本另行展示官方来源和额外影响并再次确认；禁止不透明的 `curl | shell`。

确认后，让 `install.sh` 自己按契约完成副本、symlink、local 权限、`core.hooksPath`、Brewfile 合并、软件、mise/uv/tooling 和插件安装。不要在本 Skill 中复刻或绕过确定性步骤。

安装器必须以“全部声明目标到位”为完成方向，而不是以“目标机器没有旧软件”为前置条件：对每个计划项记录目标路径、安装/链接结果和后续验证证据；另一架构残留只进入退役交接，不参与本阶段删除。

### 3. 验证目标机器

安装器成功返回后运行：

```text
./install.sh verify
```

把 verify 分成两个独立结论：

### A. 安装完整性

确认 `install.sh` 在当前系统定义的目标路径中完成全部声明项，至少覆盖：

- 所有启用 Zsh 文件通过 `zsh -n`，login 与 interactive shell 无加载错误；
- `~/.zprofile` 和 `~/.zshrc` symlink 分别精确指向已选的 public `zprofile`/`zshrc` 或 `.zprofile`/`.zshrc`；
- integrations pre → shared → personal → parameters → integrations post 阶段正确，personal 独占 Oh My Zsh/补全初始化；
- local 父目录为 `0700`，存在的 `parameters.zsh`、`integrations.zsh` 为 `0600`，未被 Git 跟踪且内容未泄露；
- Intel Mac 的 Homebrew 和全部受管命令来自 `/usr/local`；Apple Silicon 的 Homebrew 和全部受管命令来自 `/opt/homebrew`。另一架构路径可以仍然存在，但不得成为任一受管命令或 symlink 的最终目标；
- Apple Silicon 的关键二进制为 ARM 或受支持的 Universal；Intel 的关键二进制与 Intel 原生架构匹配；
- 每个安装器计划中的 Zsh/tooling 配置 symlink、mise/uv runtime、Brewfile 项、插件和其他命令都存在于摘要声明的精确目标，且版本、revision、来源和架构符合配置；
- 再次运行安装不会覆盖已有副本或重复破坏 symlink；
- 服务和数据人工事项仍被如实报告。

只要任一声明项没有安装到当前系统的精确目标，A 失败，Stage 2 不得标为完成。旧 Intel 项存在但没有被受管目标使用，不使 A 失败。

### B. Intel 退役交接

仅在 Apple Silicon 上，verify 同时盘点仍存在的 Intel 软件和路径，并确定性维护：

```text
${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/intel_to_be_retired.tsv
```

- 父目录权限为 `0700`，文件权限为 `0600`，不得被 public/shared Git 跟踪；使用临时文件加原子替换，不能在日志中泄露 local 参数或凭证。
- 文件必须带安装器固定标记，并按稳定顺序使用 TSV 字段：`kind`、`manager`、`name`、`version`、`path`、`architecture`、`reason`。字段中的换行和制表符必须拒绝或安全编码。
- 只列通过只读管理器清单、命令解析或已知全局 runtime/plugin 根确认的精确项目与路径；允许记录 `/usr/local/bin` 等残留 PATH 条目，但不得递归枚举整个 `/usr/local`，也不得把未知目录推断为可删除软件。
- service/data、项目依赖和未知项可以进入清单，但 `reason` 必须明确标为保留/待人工处理；任何行都只是 Stage 3 输入线索，不是删除授权或 ARM 替代完成证明。
- 有 Intel 残留时，清单成功生成是 B 通过的必要条件；无法安全创建、权限不正确或内容无法确定性解析时，B 失败。
- 没有 Intel 残留时不得留下误导性的旧候选；只允许删除或清空带安装器固定标记的旧清单，遇到未知同名文件时停止并报告，不得覆盖。
- Intel Mac 不生成该清单，并明确报告 Stage 3 不适用。

Stage 2 只有 A 通过，且 Apple Silicon 上 B 为“已生成”或“无 Intel 残留”时才完成。清单由 Stage 3 重新盘点、逐项验证并分类后才能用于退役预览。

性能结果只作为建议，不阻止基础交付。

### 4. 报告并停止

报告原生硬件与所选前缀、仓库 Zsh 来源、真实入口和 tooling symlink、已创建副本、每项软件/tooling/plugin 的目标与结果、A/B 两类验证结论、`intel_to_be_retired.tsv` 路径与条目摘要、人工服务或数据事项、测试/pre-commit/CI 状态和未解决缺口。CI 只报告，不改变 Stage 2 结论。

在 Apple Silicon 上明确说明 Stage 3 仍需用户单独触发；在 Intel Mac 上明确说明 Stage 3 不适用。不要自动继续 Stage 3。

## 处理失败

- Stage 1 输出缺失、变化、所采用修复计划不是唯一 `Stage 1 已应用` 状态或验证失败：返回 Stage 1，不在本阶段修复 Zsh。
- 两套仓库 Zsh 来源同时存在、命名混搭或文件残缺：在确认前报告精确冲突并停止；不猜优先级，不创建别名、副本或另一套文件。
- Stage 1 显式目标位于仓库外：报告精确映射缺口并停止，不擅自复制到 `my_setup/zsh/`。
- 架构、Rosetta 或 Homebrew 前缀判定失败：不运行安装器，不猜测路径。
- 单个工具的版本、来源或目录查询失败：记录已运行的只读查询和未解决字段；只在该字段被对应写入使用且无法安全隔离时阻断该动作，不全局停止。
- 用户拒绝安装摘要：不执行真实系统变更。
- Zsh 副本创建失败：停止，不替换真实入口。
- 软件部分安装后验证失败：报告实际状态和人工修复建议，不自动卸载。
- 原生目标全部安装但 Intel 清单生成失败：保留已安装结果，报告 A 已通过、B 失败及精确状态文件问题；不自动删除 Intel 项，也不进入 Stage 3。
- 服务或数据尚未处理：允许完成配置和软件安装，但明确标记这些项目不得进入 Stage 3 删除清单。

## 完成判定

只有以下条件全部成立，才报告 Stage 2 完成：

- Stage 1 最新仓库版 Zsh diff 已确认，实际采用的修复计划状态为唯一 `Stage 1 已应用`，安装器已解析出唯一完整命名组且与 Stage 1 交接一致；
- 原生硬件、进程状态和 Homebrew 前缀判定明确；
- 用户已在 `install.sh` 内确认真实写入；
- 安装器摘要中的全部 Zsh/tooling symlink、local 权限、Brewfile 软件、mise/uv runtime 和 plugin 都已安装到当前系统定义的精确原生目标；
- `./install.sh verify` 的 A 安装完整性通过；Apple Silicon 上 B 已生成合规的 `intel_to_be_retired.tsv`，或确认没有 Intel 残留；
- 服务和数据只被报告，没有自动迁移；
- 测试、pre-commit 和 CI 状态已如实进入最终报告，但 CI 状态未被用作阻断条件；
- 没有生成 Zsh、执行 Stage 3、commit 或 push。

用户在任一确认处取消时，按实际状态报告“Stage 2 已取消”或“安装未获确认”，不要把未安装或部分安装标为完成。
