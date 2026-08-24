---
name: stage-1-apply-zsh-repair-plan
description: 从 Stage 0 固定本机目录 `~/.config/dotfiles/zsh-repair/` 或用户显式路径读取已确认 Zsh 修复计划，应用为可审查的 `zprofile`、`zshrc`、可选 `shared.zsh` 和本机 `integrations.zsh`；优先更新用户显式目标，否则先确认无前置点或有前置点命名。以最小修改保留 Oh My Zsh 模板，并用确定性清单逐块比较源 `.zprofile`/`.zshrc` 与目标及本机 integrations；在替换 NVM、PNPM_HOME、BUN_INSTALL 或其他工具 PATH/initializer 前，完整盘点会因此失去解析的 npm、pnpm、Bun 及明确移除目录中的直接全局 CLI。用于应用 zsh-repair-plan、保全 Kiro/Docker/gcloud/kimi 等软件追加块、生成或修复目标 Zsh 文件、盘点受 runtime/PATH 迁移影响的直接全局 CLI，或进入 Dotfiles Stage 1/1.1 时；不用于重新诊断源 Zsh、建立 HOME symlink、安装软件、运行 Stage 2/3、commit 或 push。
---

# Stage 1：应用 Zsh 修复计划

把已确认的修改建议转换为精确的目标文件变更：

```text
确认文件名 → 核对源功能块与全局 CLI 影响 → 确认计划与目标 → 生成候选
  → 源/目标/local 覆盖比较 → 用户确认完整 diff → 写入 → 再比较
  → 更新所采用修复计划的状态 → Stage 1.1 可选声明确认 → 停止
```

## 文件名确认门

用户没有显式提供精确目标路径时，在展示实施计划或生成候选前，先只读识别可能的默认目录，然后只询问以下选择并停止等待：

```text
1. 使用默认文件名 zshrc 和 zprofile（无前置点）
2. 使用 .zshrc 和 .zprofile（有前置点）
```

不得根据仓库现有文件、修复计划中的逻辑名称、Shell 惯例或下游安装器要求代替用户选择。选择 1 时默认目标为 `my_setup/zsh/zshrc` 和 `my_setup/zsh/zprofile`；选择 2 时默认目标为 `my_setup/zsh/.zshrc` 和 `my_setup/zsh/.zprofile`。记录本次选择并在后续计划、diff、写入和交接中始终使用同一组名称。

用户已经显式提供一个或多个精确目标路径时，不要要求其改名，也不要对已提供目标重复询问命名方案。只提供部分目标而修复计划还需要其他文件时，先询问缺失文件的精确路径；不要把命名选择自动套用到缺失目标。

## 全局 CLI PATH 策略确认门

当修复计划或候选涉及 runtime、全局包管理器、`PNPM_HOME`、`BUN_INSTALL`、npm prefix 或其 PATH 时，在文件名确认后、执行前计划门之前，先展示[全局 CLI 迁移交接协议](./references/global-cli-migration.md)中的两种 PATH 策略及简短利弊，然后只询问：

```text
1. 使用各 manager 官方原生全局目录（推荐）
2. 评估统一使用 ~/.local/bin
```

选项 1 是默认推荐，但不得代替用户作答。它保留 manager 官方安装、升级和卸载语义；代价是 PATH 入口较多，且 npm 全局 CLI 随具体 mise Node prefix 迁移。选项 2 提供稳定的 XDG 用户命令入口、便于迁移和备份；代价是必须逐个证明 manager 官方支持该目录或使用明确 wrapper，不能用复制、临时 symlink 或重复 runtime owner 冒充统一。

记录本次选择并停止等待。后续计划、候选和验证必须始终使用同一策略；输入或选择变化时重新展示计划并再次确认。无论选择哪种策略，`node`、`bun`、`bunx`、`pnpm`、`npm` 等 runtime/manager 命令都只能有一个主要 owner，不得为了统一目录复制或链接出第二套入口。

## 执行前计划门

完成文件名确认后，只读检查修复计划、用户显式目标、已选默认仓库目标、工作树、已有 Zsh 文件和可选 shared 仓库；不要生成候选或编辑文件。随后展示：

- 将读取的修复计划及其确认状态；
- 固定本机计划目录 `~/.config/dotfiles/zsh-repair/` 的类型、owner、`0700/0600` 权限、是否存在 legacy 仓库计划，以及本轮会读取或更新的精确计划文件；
- 每份实际采用的 `zsh-repair-plan.md` 当前状态、兼容的旧标题状态，以及成功后统一更新为 `> 状态：Stage 1 已应用` 的精确 diff；
- Stage 0 使用的源 `.zprofile`/`.zshrc` 精确映射、功能块清单和当前快照是否仍匹配；
- 每个 `zprofile`/`.zprofile`、`zshrc`/`.zshrc`、`shared.zsh` 的精确目标、命名选择和选择依据；
- 是否创建或修改固定本机文件 `~/.config/dotfiles/local/integrations.zsh`、`parameters.zsh`，已有文件的备份路径规则和只展示脱敏结构 diff 的原因；
- 修复计划涉及 Homebrew/PATH 时的目标架构或可移植判定；
- 用户选择的全局 CLI PATH 策略、精确 PATH 入口、顺序、manager owner，以及官方原生目录与统一 `~/.local/bin` 的简短利弊；
- 将保留的现有内容、计划修改的逻辑区域，以及是否从官方安装工具联网取得最新 Oh My Zsh 模板、隔离临时 HOME 和清理范围；
- 候选与临时文件范围、验证命令、敏感信息风险和失败停止点；
- 是否会因 NVM、`PNPM_HOME`、`BUN_INSTALL` 或其他工具 PATH/initializer 的移除、替换或语义变化而让现有全局 CLI 失去解析；将只读检查的每个精确旧 owner/目录、npm/pnpm/Bun 直接全局安装项、明确移除 PATH 目录中的直接 CLI、本机迁移清单路径、public 声明路径和 Stage 1.1 的独立确认边界；
- 明确只会在隔离临时 HOME 运行官方模板工具，不会执行真实 HOME symlink、软件安装、退役、commit 和 push。

展示后停止并等待用户明确确认。确认只授权生成候选和进入 diff 审查，不授权写入未展示的目标。输入、目标、工作树或 diff 发生实质变化时，更新完整计划并再次等待确认。

## 允许只读事实查询

缺少预先采集的工具版本、命令来源或目录语义，不是生成候选前的阻断条件。先执行解决当前问题所需的最小只读查询；这类查询属于本 Skill 的只读盘点和验证，不需要另设确认门。

允许的查询包括：

- `command -v <tool>`、`type -a <tool>`、`file <resolved-command>` 等命令来源与架构检查；
- `<tool> --version`、`<tool> version` 和 `<tool> --help` 等版本或命令面检查；
- 工具明确声明为只读的 `config get`、`bin`、`root`、`prefix`、`env` 或等价查询；
- 针对 pnpm 的 `pnpm --version`、`pnpm config get global-bin-dir`、`pnpm bin -g`、`pnpm root -g` 等必要检查；
- `uname`、`arch`、`sysctl` 等只读系统事实。

执行前确认命令不会安装、更新、删除、写配置、刷新 metadata/cache、启动服务或访问不必要的网络；不能确认只读性时先查看本机帮助或跳过该命令。已安装的业务 CLI 即使提供 `--version`、`version`、`doctor` 或首次运行命令，也不得用于全局 CLI 盘点，因为它们可能自更新或初始化；版本优先从 manager metadata 或安装目录 manifest 读取。只采集回答当前问题的字段，路径和环境值按 public/shared/local 边界脱敏，不输出完整环境或敏感值。

处理查询结果时：

1. 查询能够确认版本或目录语义时，直接把事实用于候选和验证，不再要求 Stage 0 预先提供同一证据。
2. 工具尚未安装，但 Stage 2 将按已确认声明安装时，把运行时核验交给 Stage 2；不要因此阻止 Stage 1 生成其他候选。
3. 查询失败或结果仍有歧义时，保留该项已有安全配置，或只暂缓依赖该事实的单项修改，并把它标为未解决；继续生成和展示其余已确认变更的 diff。
4. 只有歧义直接影响精确写入目标、敏感信息边界或会导致破坏性修改时，才阻断对应写入；不要把单个工具的版本或目录证据缺口升级为整个 Stage 1 的停止条件。

不得以“缺少 pnpm 版本证据”或“`PNPM_HOME` 目录语义尚未确认”为由，在运行上述只读查询之前停止；查询后仍不明确时，也不得阻止无关 diff 的生成。

## 读取权威输入

按以下优先级解析输入：

1. 用户在当前请求中显式提供的 personal/shared `zsh-repair-plan.md`；
2. 固定本机 personal 计划 `~/.config/dotfiles/zsh-repair/zsh-repair-plan.md` 与可选 shared 计划 `~/.config/dotfiles/zsh-repair/shared-zsh-repair-plan.md`；
3. Stage 0 交接中的确认状态、证据缺口和目标归属；
4. 目标文件的现有内容，以及[共用契约](../stage-common-contract.md)和[领域词汇](../../../CONTEXT.md)；
5. Stage 0 证据来源对应的源文件；`live-home` 固定映射为当前 `$HOME/.zprofile` 与 `$HOME/.zshrc`，其他来源必须由用户显式提供精确源路径。

只应用已经过 Stage 0 确认，或由用户显式提供并明确要求执行的计划。计划仍是候选、互相冲突、缺少必要目标、缺少功能块保全清单或无法区分 personal/shared 时，集中提问，不自行补写需求。不得重新诊断真实 Zsh；只允许确定性功能块工具读取已确认源文件并输出安全清单、私有候选和覆盖结果，AI 不直接读取源块正文、变量值或内容摘要，也不得把实施时的新判断伪装成 Stage 0 证据。

固定计划目录不是 Zsh 运行时配置，也不进入 Git、shared 仓库或 Stage 2。目录必须是当前用户拥有的普通目录且权限为 `0700`；计划必须是当前用户拥有的普通文件且权限为 `0600`，不得跟随 symlink。默认计划不存在时，不得回退读取 `my_setup/zsh/zsh-repair-plan.md` 或 shared 仓库旧计划；发现旧位置时报告为 legacy，并要求用户显式提供计划或先运行 Stage 0 迁移。不得自动删除旧文件。

## 管理修复计划状态

把每份实际采用的 personal/shared `zsh-repair-plan.md` 作为 Stage 1 交接的一部分，不修改未被本次应用使用的计划。状态字段使用靠近标题的单行 Markdown 引用：

```text
> 状态：Stage 1 已应用
```

- 把 `> 状态：Stage 0 候选`、`> 状态：Stage 0 已确认`，以及旧标题 `Zsh 修复计划候选（Stage 0）` 识别为 Stage 0 状态；旧标题在获准 diff 中规范为普通 `Zsh 修复计划` 标题和独立状态字段，避免标题与状态互相矛盾。
- 生成候选时把状态迁移纳入用户审查的完整 diff，但在目标 Zsh、获准 local 文件和功能块覆盖验证全部通过前，不得把状态写成 `Stage 1 已应用`。
- 所有与该计划关联的目标验证通过后，再原子更新状态；状态文件并发变化、写入失败、最终状态不唯一或实际 diff 与获准 diff 不一致时，Stage 1 不得报告完成。
- 修改固定本机计划前，先在同目录创建权限为 `0600` 的时间戳备份，再通过同目录临时文件原子替换；备份、类型、owner 或权限验证失败时不修改计划状态，也不得报告 Stage 1 完成。
- 用户取消、目标写入失败或最终验证失败时保留原状态，不得用 `Stage 1 已应用` 掩盖候选或部分完成结果。
- 已是 `Stage 1 已应用` 但目标、源基线或计划正文后来发生变化时，把它视为交接失效，重新审查完整 diff；不得只沿用旧状态。

## 解析精确目标

目标选择规则固定为：

1. 用户显式提供目标 `zshrc`/`.zshrc`、`zprofile`/`.zprofile` 或 `shared.zsh` 时，更新这些文件；不要同时另建默认仓库副本，也不要改名。
2. 用户只提供部分目标时，只修改获准文件。修复计划还要求其他文件时，先报告缺口并询问目标，不猜测默认位置。
3. 用户没有提供目标时，先完成文件名确认门。默认使用当前公开仓库的 `my_setup/zsh/zshrc`、`my_setup/zsh/zprofile`；只有用户选择有前置点方案时才使用 `my_setup/zsh/.zshrc`、`my_setup/zsh/.zprofile`。确有 shared 增量时仍使用唯一已授权 shared 仓库的 `zsh/shared.zsh`。
4. 计划中的“目标文件”是逻辑建议；当前请求中显式提供的目标路径优先。

记录目标是否存在、是否为普通文件、是否为 symlink、是否有未提交修改。不要跟随未披露的 symlink 写入；只有用户显式提供并确认解析后的真实目标时才允许更新。不得因为检测到 `~/.zshrc` 或 `~/.zprofile` 就把它当作目标；真实 HOME 文件只有作为用户显式目标并通过两次确认时才在本阶段更新，本 Skill 仍不建立或替换 symlink。

本 Skill 的固定 HOME 文件边界只有：本机修复计划目录中的实际采用计划、`~/.config/dotfiles/local/integrations.zsh`、`parameters.zsh`，以及全局 CLI 迁移协议规定的 `${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/global_cli_to_be_migrated.tsv`。修复计划只用于 Stage 0 → Stage 1 交接；integrations/parameters 只有在计划要求、执行前已逐项展示且最新 diff 已确认时才允许更新。不得借此修改其他 HOME 配置。

## 建立源功能块基线

使用 [`../analyze-zsh-configuration/scripts/zsh-functional-blocks.zsh`](../analyze-zsh-configuration/scripts/zsh-functional-blocks.zsh) 的 `inventory`，对 Stage 0 对应的源 `.zprofile` 和 `.zshrc` 重新生成安全清单并逐项核对修复计划：块 ID、出现序号、源顺序和 `zprofile-pre/post`、`zshrc-pre/post` 阶段必须一致。源文件缺失、清单缺项或从 Stage 0 后发生变化时停止，重新生成计划或让用户明确确认最新完整清单；不得继续使用旧行号抽取。

Stage 0 未提供功能块清单的旧计划不能直接完成 Stage 1。先对用户显式提供的源文件生成清单，展示后让用户确认补充计划；无法获得精确源文件时保留现有目标，不得以 Git HEAD、Oh My Zsh 模板或空文件代替源基线。

## 建立全局 CLI 迁移基线

当修复计划或候选会移除、替换或改变 NVM、`PNPM_HOME`、`BUN_INSTALL`、npm/pnpm/Bun 全局目录或其他工具 PATH/initializer 时，必须完整读取并执行[全局 CLI 迁移交接协议](./references/global-cli-migration.md)。覆盖 npm、pnpm、Bun 及本次 Zsh 修改明确移除的工具目录，只保全直接全局 CLI，不执行这些业务 CLI。

先以“源 Zsh/runtime 可达命令”与“Stage 1 最终候选可达命令”的差集建立失去解析影响集，而不是只查看当前默认 runtime。对每个被移除、替换或失去 PATH 可达性的旧 owner/目录，都必须盘点：

1. npm 的直接全局安装项及其 binaries；
2. pnpm 的直接全局安装项及其 binaries；
3. Bun 的直接全局安装项及其 binaries；
4. 本次明确移除 PATH 目录中不属于上述 manager、但直接位于该目录并会失去解析的 CLI。

只登记确实会失去解析、解析到错误 owner，或目标 owner 尚无精确等价项的直接 CLI；排除传递依赖、项目依赖、runtime 自带命令、缓存和无 binary 的包。某个 manager 没有全局根或没有直接安装项时记录安全的“无候选”证据，不生成空行，也不能据此跳过其他 manager。

在展示 Zsh diff 前确认每个受影响旧 owner 的直接安装项、版本、binaries、旧 prefix、失效原因和安全目标建议，并生成本机 `${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/global_cli_to_be_migrated.tsv` 候选。无法安全盘点某个即将失去解析的旧 owner 时，阻止对应 Zsh 退役变更或保持为 `manual`；不得因为 runtime 本身已经由 mise/Bun 替代，就假定其全局 CLI 也已迁移。

用户可以明确排除某个旧 owner 或目录的读取；此时不得读取该范围，但也不得应用会让该范围失去解析的 PATH/initializer 退役。若其他无关变更可以独立验证，可作为“Stage 1 部分应用”继续；修复计划保持未完成状态，不进入 Stage 1.1，也不得报告 Stage 1 完成。

本机 TSV 属于 Stage 1 获准写入范围并先于会使 CLI 失去解析的 Zsh 目标原子落盘；对话只展示脱敏结构摘要。可分享的 `my_setup/tooling/global-cli-migration.toml` 不在 Stage 1 主写入中自动生成，只能在 Stage 1 全部验证通过后的 Stage 1.1 由用户确认完整 diff 后写入。

## 生成最小候选

根据修复计划分别更新目标，遵守：

- 把跨进程静态环境放入已选的 `zprofile` 或 `.zprofile`，把交互行为放入已选的 `zshrc` 或 `.zshrc`；不接管 `.zshenv`，不设置 `ZDOTDIR`。
- 修复 Homebrew/PATH 时使用计划已确认的目标架构；缺少本机架构事实时先运行允许的只读系统查询，不要把执行 Stage 1 的当前进程架构自动当成目标。计划要求跨机器复用时使用只激活原生前缀的可移植判断；只有目标机器不同于当前机器或查询后仍无法确定目标时才询问。
- 以目标现有内容为基线做局部修改；不要为了格式统一重写整份文件，不改变计划未覆盖的用户配置。
- 目标缺失或内容不完整时，源功能块清单仍是兼容性基线；不得只使用 Git HEAD、空文件或 Oh My Zsh 模板生成目标。
- personal 提供完整默认体验并独占 Oh My Zsh 与补全初始化；shared 只保存可在 personal 之前独立加载的共享增量；声明式覆盖顺序仍为 `shared → personal → parameters`，本机 integrations 只通过 pre/post 阶段钩子包围对应启动文件。
- 保持声明式 `shared → personal → parameters` 顺序和对应的 `dotfiles: shared/personal/local` 标记；integrations pre/post 标记只包围该顺序。为启用插件保留按 `load_order` 排列的 `dotfiles: plugin <name>` 标记。
- 不把 shared 仓库专属内容、本机绝对路径、账号、密钥、服务数据或未确认的软件选择写入 public 文件；只允许确定性迁移操作读取 local 文件，AI 和对话不得显示其内容。
- 显式目标含疑似敏感赋值时，只保留并局部绕开，不在候选、日志或对话中显示值；修复计划要求改动该项时停止并先确认安全迁移方式。
- 不创建没有实际内容的 shared 文件。
- 生成或修改 runtime/global CLI PATH 时，完整执行全局 CLI 迁移协议中的 PATH ownership 策略。默认推荐使用 manager 官方原生目录：mise runtime 必须先于 pnpm/Bun global bin，npm global bin 由当前 mise Node prefix 通过 mise 激活暴露；不得硬编码版本化 mise Node prefix。只有用户选择统一 `~/.local/bin` 且每个 manager 的官方能力或明确 wrapper 方案都已确认时，才生成对应候选。

### 保全并迁移第三方功能块

对修复计划的每个源功能块只允许一种处置：

- `preserve-target`：把原块逐字节保留在相同启动阶段，并维持同阶段内相对顺序；
- `migrate-local-integrations`：使用功能块工具的 `render-local` 把可迁移块逐字节写入权限为 `0600` 的私有候选，目标固定为 `~/.config/dotfiles/local/integrations.zsh`；
- `manual`：在目标原阶段保留原块并阻止自动搬移，直到用户确认具体处置；
- `retire`：只接受修复计划中可追溯到用户明确决定的精确 `logical-file:id#occurrence`，不得用类别通配。

单一 `integrations.zsh` 使用四个阶段分支：`zprofile-pre`、`zprofile-post`、`zshrc-pre`、`zshrc-post`。目标文件以固定 `dotfiles: local-integrations <phase>` 标记条件加载：pre 标记必须是对应文件第一个非空块，post 标记必须是最后一个非空块。这样 Kiro 的 top/bottom 约束和其他安装器块的源文件边界仍可验证；不得把所有块无条件挪到 `.zshrc` 末尾。

本机 integrations 不存在时，只在权限为 `0700` 的私有临时目录生成候选。本机文件已经存在时，先做无输出语法检查和安全清单；若不能证明合并会逐字节保留其既有内容，就保留源块在仓库目标并把迁移标为 `manual`，不要覆盖。获准修改已有 integrations 时，写入前创建同目录 `integrations.zsh.dotfiles-backup.<timestamp>` 副本并设为 `0600`；备份失败则停止。

`parameters.zsh` 继续只保存私有赋值，不保存可执行第三方块。迁移源文件中的私有赋值时，只按变量名执行无输出 upsert：已有 `parameters.zsh` 必须先备份为同目录时间戳副本，再保留其他变量并更新同名值；父目录保持 `0700`、文件与副本保持 `0600`。任何值都不得进入候选 diff、日志、对话或哈希输入。

候选默认保存在进程内。确需临时文件时，使用权限为 `0700` 的独立临时目录和 `0600` 文件；包含显式目标原文或疑似敏感内容时不得写入仓库 `tmp/`，完成、取消或失败后只清理本次精确创建的临时路径。

## 使用官方最新版并保留用户配置

把官方安装工具在隔离临时 HOME 生成的最新 `.zshrc` 视为 Oh My Zsh 模板基线，把现有目标和已确认源文件视为用户功能基线：

- 只有执行前计划明确展示联网影响并获确认后，才从 Oh My Zsh 官方 `master/tools/install.sh` 下载当前安装工具到权限为 `0700` 的私有临时目录；不要执行未落盘审查的 `curl | shell`。
- 使用独立临时 `HOME` 和 `ZSH` 目录运行官方工具的 `--unattended` 模式，禁止更改默认 shell、启动交互 Zsh、写真实 HOME 或复用现有 `~/.oh-my-zsh`。记录官方仓库实际 commit，取得生成的最新 `.zshrc` 后精确清理隔离目录。
- 网络、官方脚本下载、仓库 clone 或模板生成失败时，不用本地旧模板、Git HEAD 或手写最小结构冒充最新版；把 Oh My Zsh 相关候选标为阻断，同时继续处理不依赖该模板且能独立验证的项目。
- 保留最新官方模板的注释、分区顺序、变量示例、主题配置、`plugins=(...)` 位置和 `source $ZSH/oh-my-zsh.sh` 初始化形态；把现有目标与源功能基线中的用户配置逐项合并，而不是整文件覆盖。
- 优先在模板预留位置内更新 `ZSH`、主题、插件和用户配置；只插入满足 shared/personal/local 契约所需的最小受管块。
- 保证 Oh My Zsh 和补全只初始化一次；修复重复 `compinit`、重复 source 或错误顺序时，只移除已确认冲突的片段。
- 修复计划或安全边界与模板冲突时，以获准计划和安全边界为准，并逐项列出偏离模板的原因。

模板处理必须通过三方对照验证：列出官方最新模板 commit、保留的官方区块、从现有目标/源功能基线合并的用户配置、必要变更和非必要格式变化；存在非必要变化时继续收窄 diff。

## 自检并确认 diff

写入目标前完成：

1. 对所有仓库候选和私有 integrations 候选运行 `zsh -n`。
2. 检查 integrations pre → shared → personal → parameters → integrations post 阶段、受管标记、插件顺序及 Oh My Zsh/补全初始化唯一性。
3. 对照修复计划确认每项已应用、保留或作为未解决单项隔离；证据缺口已经先用允许的只读查询补充，且没有阻塞无关变更或顺手扩张。
4. 扫描 public 候选中的密钥模式、shared 仓库专属标识、本机绝对路径、与已确认目标架构不匹配的 Homebrew 前缀和 Rosetta fallback。
5. 对比原文件，确认 Oh My Zsh 模板和用户配置只发生必要变化。
6. 运行功能块工具的 `compare`，逐块比较源 `.zprofile` + `.zshrc` 与目标 `zprofile` + `zshrc` + 私有 integrations 候选。只有 `preserved-target`、已校验阶段 loader 的 `migrated-local` 或精确获准的 `approved-retired` 通过；`missing`、`content-changed`、`phase-changed`、`order-changed`、`missing-loader` 均阻止展示可写 diff。
7. 验证失去解析影响集逐一覆盖 npm、pnpm、Bun 和每个明确移除 PATH 目录；迁移清单只含本次变更影响的直接安装项，稳定排序、权限/schema/ownership marker 正确，public 候选不含源绝对路径、认证数据或环境值。任一被排除或无法安全盘点的范围必须与对应被阻止的 Zsh 退役变更精确关联。
8. 验证所选 PATH 策略：`node`、`bun`、`bunx`、`pnpm`、`npm` 的主要解析 owner 符合 mise/runtime 声明；pnpm/Bun/npm 全局 CLI 解析到各自已确认 owner；manager 原生 global bin、可选 `~/.local/bin` 和继承 PATH 的顺序符合协议且没有错误 owner 抢占。
9. 展示每个仓库目标和每份实际采用的本机 `zsh-repair-plan.md` 状态迁移完整 diff，以及私有文件和本机迁移清单按变量名/块 ID/manager/package/binaries/impact/数量生成的脱敏结构 diff；不得显示私有正文、值、源绝对路径或内容摘要。一起展示目标类型、候选验证、模板保留摘要、功能块覆盖表、CLI 影响覆盖表、PATH owner/顺序表和未解决缺口。

随后只给出以下选择并停止等待：

```text
1. 确认当前完整 diff，并写入已展示的目标
2. 要求调整候选并重新审查
3. 取消本次 Stage 1
```

选择 2 时重新运行全部自检并展示完整最新 diff。选择 3 时不写目标并精确清理本次临时文件。

## 写入并验证

只有用户确认最新完整 diff，且目标内容、路径和类型未变化时，才写入精确目标。发现并发变化时停止，重新生成并确认 diff。

写入后：

- 先确认本机全局 CLI 迁移 TSV 已按获准结构原子落盘；若它失败，不得继续写入会让对应 CLI 失去解析的 Zsh 变更；
- 再次运行 `zsh -n` 和全部静态边界检查；
- 针对实际落盘文件再次运行同一源/目标/local 功能块 `compare`；任一块缺失、变化、错序或 loader 阶段错误都报告失败，不得标为完成；
- 只有上述验证通过后，才把每份实际采用的 `zsh-repair-plan.md` 原子更新为唯一的 `> 状态：Stage 1 已应用`；旧标题同时按已确认 diff 去掉 Stage 0 候选字样；
- 确认实际 diff 与获准 diff 完全一致；
- 报告更新的目标、最终文件命名方案、模板保留情况、计划覆盖结果、每份修复计划的最终状态、全局 CLI 迁移清单摘要和证据缺口；
- Stage 1 完成后按下节进入 Stage 1.1；不要安装全局 CLI、运行 `install.sh` 或自动进入 Stage 2。

不要修改真实 Zsh 入口的 symlink，不在真实 HOME 安装 Oh My Zsh、插件、Homebrew 或 tooling，不让 AI 读取 local 正文，不 commit 或 push。

## Stage 1.1：确认全局 CLI 可分享声明

Stage 1.1 是 Stage 1 成功后的可选确认阶段，不改变 `> 状态：Stage 1 已应用`，也不执行软件迁移。只有本机迁移 TSV 存在待处理候选时才进入；没有候选时不创建空 public 文件并直接停止。

完整读取[全局 CLI 迁移交接协议](./references/global-cli-migration.md)，展示待迁移 package/version/binaries、受影响原因、建议 target manager、兼容性缺口，以及 `my_setup/tooling/global-cli-migration.toml` 的完整候选 diff，然后只询问：

```text
1. 把全部可自动迁移项写入可分享声明
2. 逐项选择并重新审查完整声明 diff
3. 暂不迁移，保留本机清单
```

只有用户确认已展示的最新声明 diff 后才写入 public 文件并原子更新本机 TSV 的决定状态。选择跳过、只有 manual 项或 Stage 1.1 写入失败不回滚已经完成的 Stage 1；按实际结果报告后停止。Stage 2 不强依赖该文件，但文件存在时会在每台目标机重新询问是否迁移。

## 完成判定

只有以下条件全部成立，才报告 Stage 1 完成：

- 修复计划已确认且每个目标来源明确；
- 无显式目标时，用户已明确选择无前置点或有前置点命名方案；
- 用户已确认最新完整 diff；
- 只更新了显式目标或没有显式目标时的默认仓库目标；
- 所有写入文件通过语法和边界检查；
- 已从源与最终候选的可达性差集完整盘点本次 Zsh 变更影响的 npm、pnpm、Bun 直接全局 CLI 及明确移除 PATH 目录中的直接 CLI；存在受影响项时，本机迁移 TSV 已先于对应 Zsh 写入原子落盘，无法盘点或用户排除的旧 owner 未被静默退役；
- 本轮涉及 runtime/global CLI PATH 时，用户已明确选择 manager 官方原生目录或统一 `~/.local/bin` 策略；最终 PATH 顺序、主要 runtime owner 和各 manager global CLI owner 均与该选择一致且验证通过；
- 源 `.zprofile` + `.zshrc` 的每个功能块都由最终目标文件或正确阶段加载的 `integrations.zsh` 精确覆盖，或有用户明确批准的精确 retire 记录；
- 修改过的既有 `integrations.zsh`/`parameters.zsh` 均已先完成 `0600` 同目录备份，且 local 父目录为 `0700`；
- Oh My Zsh 模板来自本次获准运行的官方最新安装工具，官方 commit 已记录；用户配置已保留，所有偏离都有获准理由；
- 每份实际采用的本机 `zsh-repair-plan.md` 都只含一个 `> 状态：Stage 1 已应用`，保持 `0600` 且状态迁移包含在用户确认的完整 diff 中；
- 没有建立 symlink、在真实 HOME 安装软件、退役、commit 或 push；Stage 1.1 只生成用户确认的可分享声明。

若用户取消、目标变化或验证失败，按实际状态报告，不把候选或部分写入标为完成。Stage 1.1 被跳过或失败时，必须把“Stage 1 已完成”和“全局 CLI 声明未生成/未完成”分别报告。
