# Apple Silicon Dotfiles 整改、迁移与 Intel Homebrew 退役实施计划

> 状态：已确认的实施级规格（尚未实施；当前交付重点是前置阶段 0 与顶层阶段 1）<br>
> 版本：2.0<br>
> 日期：2026-08-09<br>
> 适用目标：先建设可复用的 dotfiles 公开仓库与公司层文件契约，再由每个 Apple Silicon macOS 用户独立完成本地配置和 Intel Homebrew 退役<br>
> 文档用途：交给实施 Agent 或人工维护者，先完成独立前置阶段 0，再严格按“仓库能力 → 本地应用 → 不可逆退役”三个顶层阶段执行。

## 1. 执行摘要

本项目有一个独立前置阶段 0，以及三个顶层实施阶段；顺序不得颠倒：

```text
前置阶段 0 / 操作 A：只读诊断并给出 Zsh 修改建议（禁止导出候选配置）
  → Agent 按“一定要改 / 建议修改 / 可以不改”逐项分类并完成第一次预审批
    → 固定 local-only 根为 ~/.config/dotfiles，用户一次性指定 public/company 仓库+路径
      → 前置阶段 0 / 操作 B：按指定目的地单独导出当前设备配置并完成第二次预审批
        → 顶层阶段 1：根据预审批结论建设并 commit 可复用仓库能力（当前主目标）
        → 顶层阶段 2：每个用户/每台机器应用本地配置，并由独立脚本迁移 Intel Homebrew 到 ARM
          → 顶层阶段 3：由同一迁移脚本单独预览并退役 Intel Homebrew
```

- **前置阶段 0 是仓库生产的输入阶段，不计入三个顶层实施阶段。** 它必须拆成两个不可合并的操作：先结合 [Zsh 配置诊断与优化指南](./zshrc-diagnostics-guide.md) 只读分析 `.zshrc` 及其 source 链，生成 Zsh 修改建议且不导出候选配置；Agent 随即按“一定要改 / 建议修改 / 可以不改”分类并完成第一次预审批，不逐项询问用户。local-only 根目录直接使用计划已定义的 `~/.config/dotfiles`，具体配置位于其 `local/` 子目录；导出前只需由用户一次性选择 public 的目标仓库与仓库内路径，以及 company 的目标仓库与仓库内路径（或显式选择 `skip`）；再单独读取 Brewfile/已安装项与其他配置，把预审批通过的 Zsh 建议和设备现状转换为符合阶段 1 格式且落在指定目的地的候选文件。
- **顶层阶段 1 是当前主交付目标。** 它以前置阶段 0 产物的 Agent 预审批结论为输入，在用户选择的 public 仓库与路径中建成通用公开层、`install.sh`、`bin/dotfiles`、独立的 `scripts/migrate-intel-homebrew-to-arm.sh`、测试、文档、安全保护，并在用户选择且已获外部授权的 company 仓库与路径中更新需同步文件；只有此阶段可以 stage/commit 已预审批文件。
- **顶层阶段 2 是单机操作。** 用户 clone 或更新顶层阶段 1 的仓库后，先运行 `./install.sh` 完成只读盘点、本地计划、备份、symlink、私有分层配置和验证，再单独运行 `./scripts/migrate-intel-homebrew-to-arm.sh` 生成 Intel→ARM 计划，并仅以 `--apply` 安装和验证 ARM 替代工具；此阶段不允许卸载 Intel Homebrew。
- **顶层阶段 3 是独立的不可逆单机操作。** 只有顶层阶段 2 的配置验证与迁移 `--apply` 均通过并生成完整退役账本后，用户才能对同一迁移脚本显式使用 `--retire` 预览和正式退役。

前置阶段 0 和顶层阶段 1 是仓库维护者执行的生产流程；顶层阶段 1 产出一次建设、多人复用的产品能力。顶层阶段 2 和 3 由每个人在自己的机器上分别执行，其 inventory、plan、manifest、backup 和 retired record 不得回传到公开仓库。`install.sh` 只管理 dotfiles 来源、真实入口 symlink、私有分层和可逆配置；`scripts/migrate-intel-homebrew-to-arm.sh` 独占 Intel Homebrew 盘点、ARM 替代安装、服务/数据迁移、验证和最终退役。两者都不负责前置阶段 0，配置 apply、迁移 `--apply` 与不可逆 `--retire --apply` 不得自动串联。

本项目最终建立三个配置层，并固定覆盖关系：

```text
公开候选仓库（public） < 公司私有仓库（company，可选） < 本机私有配置（local）
```

- 公开候选仓库先创建为私有仓库；顶层阶段 1 的仓库能力、隔离测试、全历史密钥扫描和 Agent 发布预审批完成后，再由用户手工改为公开并采用 MIT License；不等待任何用户先完成顶层阶段 2/3。
- 公司配置必须存放在公司批准的私有 Git 服务或组织中；不得默认推送到个人 GitHub，也不得保存密钥。
- **local-only root** 固定为 `~/.config/dotfiles`；其私有配置固定位于 `~/.config/dotfiles/local/`，不进入 Git、不进入云同步，并拥有最高优先级。阶段 0 与顶层阶段 2 均复用此定义，不再另行询问 local-only 目录。
- `~/.zprofile` 与 `~/.zshrc` 分别稳定链接到公开仓库的 `zsh/.zprofile` 与 `zsh/.zshrc` 两个真实入口；前者只承担登录环境职责，后者只承担交互体验职责；不管理 `~/.zshenv`，也不设置 `ZDOTDIR`。
- `zsh/.zshrc` 必须以顶层阶段 1 固定的 Oh My Zsh 官方 `templates/zshrc.zsh-template` 为骨架，尽量保留其注释、段落顺序和 `source $ZSH/oh-my-zsh.sh` 等原生结构；只通过边界清楚的受管区块加入 ARM 配置和私有分层钩子。
- 最终运行时配置只接受 Apple Silicon Homebrew 原生前缀 `/opt/homebrew`；`.zprofile`、`.zshrc`、Brewfile、普通安装脚本和普通文档示例不得包含 Intel Homebrew 运行时路径或兼容分支。只有迁移脚本、迁移 fixture 和本机迁移/退役报告可以为盘点与移除目的读取或提及 Intel 前缀。顶层阶段 2 完成后不自动退役；用户一旦显式进入顶层阶段 3且最终预览通过，Intel Homebrew 当天退役，不设置观察期。
- Homebrew、mise、Bun、Node、pnpm、Go、uv 的职责互斥；移除 NVM、pyenv、旧 autojump 和重复初始化。
- API key 默认保存在 macOS Keychain，仅由命令 wrapper 临时注入；仓库不实现自定义密钥管理 CLI，只提供经过验证的 `security` 命令示例。
- 所有可逆变更先计划、备份并记录 manifest；Intel Homebrew 正式卸载、密钥轮换和明文密钥清除属于明确的不可逆边界。

本次只产出计划，**不得据此假定已经修改了 `~/.zshrc`、安装/卸载了软件、创建了远程仓库或处理了密钥**。

## 2. 规范用语

- **必须**：正确性或安全性要求，不满足时不得进入下一阶段。
- **应当**：默认最佳实践；只有记录理由后才可偏离。
- **可以**：可选增强，不影响基本验收。
- **公开层**：未来可公开的个人 dotfiles 仓库；初期仍为私有。
- **公司层**：公司批准的私有配置仓库，可在没有访问权限的机器上跳过。
- **本地层**：只存在于当前机器、无 Git/云同步的私有覆盖。
- **候选文件**：前置阶段 0 从当前机器现状生成的建议版配置；它必须先经 Agent 分类与预审批，不是未经验证即可落库的内容。
- **Zsh 修改建议**：前置阶段 0 第一段只读诊断产生的逐项建议；它说明当前行为、问题、建议改法、归属和验证，但不是配置文件，也不得触发配置导出。
- **当前设备配置导出**：前置阶段 0 第二段独立操作；它只消费已完成第一次预审批的 Zsh 修改建议、脱敏设备证据和用户确认的目的地映射，并生成与顶层阶段 1 目标路径、格式和 schema 一致的候选文件，不等于复制原始配置或 dump。
- **目的地映射**：前置阶段 0 导出前确定的 `destination-map.toml`；local-only 记录计划固定的 `~/.config/dotfiles` 根和 `local/` 相对根，public/company 分别记录用户选择的目标 Git checkout 和仓库内相对路径。它是存储与发布边界，不属于 Agent 可代理的内容修改预审批。
- **同行注释**：在目标格式安全支持注释时，紧跟配置项的结构化说明；至少包含功能、最佳实践结论、推荐/替代方案和建议归属。
- **仓库能力**：顶层阶段 1 交付的公开层代码、公司层契约、命令入口、测试、文档和安全规则；它不包含任何用户的本机执行结果。
- **本地应用**：顶层阶段 2，先由 `install.sh` 建立配置、真实入口 symlink、私有分层和可回滚状态，再由独立迁移脚本的默认计划与 `--apply` 建立 ARM 替代项；不卸载 Intel Homebrew。
- **退役**：已记录替代或明确淘汰后，由 `scripts/migrate-intel-homebrew-to-arm.sh --retire --apply` 卸载 Intel Homebrew，并按 Agent 预审批且由真实 TTY 最终确认的 manifest 处理其程序文件；不等于递归删除 Intel 前缀。

### 2.1 修改建议分类与预审批规则

凡是文档、诊断报告、候选文件或实施过程中出现“人工确认”“待审”“建议修改”“推荐方案”“accept/revise/reject/defer”等内容决策，均由实施 Agent 先根据仓库证据、诊断指南、安全约束和可验证结果分类并完成预审批，不再逐条向用户提问：

| 预审批分类 | 判断标准 | 默认决策与动作 |
|---|---|---|
| **一定要改** | 不修改会违反正确性、安全、架构边界、可移植性、可公开性或阶段门禁，或会导致验证失败 | 记为 `accept`；如原方案需纠正则记为 `revise`，由 Agent 直接改写、验证并纳入候选/落库 |
| **建议修改** | 不修改仍可运行，但修改能明确减少重复、维护成本、性能问题或未来迁移风险，且收益大于兼容成本 | 默认记为 `accept`；需要调整实现细节时记为 `revise`，由 Agent 直接改写、验证并纳入候选/落库 |
| **可以不改** | 纯偏好、收益不明确、证据不足但不阻断、改动风险不低于收益，或与首期目标无关 | 默认记为 `reject` 并保持现状或移入 backlog；不得为此打断用户。只有它确实阻断安全或正确性时，才能记为 `defer/unresolved` |

每项必须记录分类、证据、默认决策、修改动作和验证结果。Agent 只有在缺少的信息会实质改变安全边界、目标仓库归属或不可逆结果，且无法从本机/仓库证据推导时，才汇总为一个阻塞问题请求用户决策；不得逐项确认。

上述预审批只替代内容与可逆修改的人工复核，不替代以下不可代理边界：选择阶段 0 的 public/company 目标仓库与仓库内路径，创建远程仓库、授予公司仓库/服务访问权、修改仓库可见性、向远程 push、信任并执行公司 hook、密钥轮换或明文清除、启动/停止有状态服务，以及 Intel Homebrew 正式退役。这些动作仍须由用户显式授权；public/company 路径选择在导出前集中询问一次，退役仍必须在真实 TTY 输入精确确认短语。

### 2.2 哈希使用边界

哈希只用于内容被替换会造成实质安全风险的边界，不作为普通流程状态、正确性证明或审批替代品：

| 分类 | 使用规则 |
|---|---|
| **一定要保留** | 外部下载并执行的脚本、公司 hook 等可执行供应链内容；Intel Homebrew 正式退役前的最终 manifest。必须记录来源 revision 和 SHA-256 |
| **建议保留** | 前置阶段 0 全部预审批结束后，对该 run 的规范化最终产物只计算一次整体摘要 `stage0-summary.sha256`，供顶层阶段 1 验证输入未整体漂移 |
| **可以不做** | 单条建议、单个候选文件、普通 inventory、中间报告、可逆配置 apply 的修改前后文件。使用 `run-id`、稳定 ID、Git diff/commit、备份路径和验证结果追踪 |

不得在 0B、0C、0D 的每一步重复计算哈希，也不得为每条记录持久化 SHA-256。`stage0-summary.sha256` 在 0E 完成后一次性生成，覆盖按路径稳定排序的 `destination-map.toml`、最终建议/决策 TSV、public/company/local-only 候选文件内容和 public/company 仓库 diff；这些内容变化时重新完成受影响的预审批，再重新生成这一份整体摘要。顶层阶段 1 落库后改用 Git commit ID 作为仓库内容身份，不继续维护候选文件哈希链。

## 3. 目标、非目标与成功状态

### 3.1 目标

1. **先完成前置阶段 0 的 Zsh 修改建议。** 依据诊断指南盘点当前 `.zshrc/.zprofile/.zshenv` 及完整 source 链，逐项说明功能、问题、最佳实践结论、建议改法、归属和验证；本操作只输出报告，不创建 public/company/local-only 候选配置文件。
2. Agent 先对每条 Zsh 修改建议做三档分类与第一次预审批，并自动映射为 accept/revise/reject/defer；只有 accept/revise 建议进入配置导出，reject 不导出对应项，defer 只用于真正阻断安全或正确性的未决证据。
3. **再单独执行前置阶段 0 的当前设备配置导出。** local-only 直接使用已定义的 `~/.config/dotfiles` 根和 `local/` 子目录；导出前由用户集中选择 public 目标仓库+仓库内路径、company 目标仓库+仓库内路径（或 `skip`），一并固化为 `destination-map.toml`。然后盘点 Brewfile/已安装项、插件、工具管理器和其他顶层阶段 1 目标文件，消费已完成第一次 Agent 预审批的 Zsh 建议，把整理后的 Zsh 真实入口/固定私有覆盖、规范化 Brewfile 及其他候选文件直接生成到已定义/已选目的地；不自动采用当前仓库或隐式 staging 目录。
4. Agent 再对导出的候选文件做三档分类与第二次预审批；所有候选必须经语法/schema、安全和预审批检查，不得由导出操作直接 stage、commit 或 push。
5. **最后进入顶层阶段 1。** 根据候选文件第二次 Agent 预审批结果更新 `destination-map.toml` 中的 public 仓库+路径和已获批 company 仓库+路径的最终文件，再经测试与安全检查后 commit。
6. 顶层阶段 1 的 README、`install.sh`、`bin/dotfiles`、`scripts/migrate-intel-homebrew-to-arm.sh`、schema、fixture 和 CI 形成自闭环：新用户只需取得该仓库，即可规划、应用、验证和回滚顶层阶段 2，并通过迁移脚本单独预览和执行顶层阶段 3。
7. Public Zsh 只包含 `zsh/.zprofile` 与 `zsh/.zshrc` 两个可直接链接的真实入口，不创建薄入口、通用 loader 或 public phase 文件；`.zshrc` 保持 Oh My Zsh 官方模板骨架。私有 company/local 仍按 `public < company < local` 覆盖，并保留 profile/pre/rc 三阶段，但每层每阶段只有一个固定文件，由两个真实入口显式 source；Oh My Zsh/`compinit` 只能初始化一次。
8. 顶层阶段 2 在每台机器上完成本地收敛：`./install.sh apply` 只做备份、真实入口 symlink 和私有分层配置；`./scripts/migrate-intel-homebrew-to-arm.sh` 无参数只生成计划，`--apply` 才安装、迁移并验证 ARM 替代项。配置变更可回滚，新增软件只提供 cleanup 预览；密钥轮换/明文清除等不可逆安全操作必须分别确认；本阶段不自动进入 Homebrew 退役。
9. 顶层阶段 3 仅由 `./scripts/migrate-intel-homebrew-to-arm.sh --retire` 生成最终预览，再由 `./scripts/migrate-intel-homebrew-to-arm.sh --retire --apply` 执行 Intel Homebrew 的最终退役；两者必须消费同一脚本在顶层阶段 2 生成的已验证迁移 manifest 和退役账本，不得重新猜测机器状态。
10. 每个用户都能使用同一份顶层阶段 1 产物，在自己的本地环境独立执行顶层阶段 2 和 3，互不共享本机状态、密钥、备份或退役记录。
11. 当前交互 shell、Homebrew、常用 CLI 和语言工具链最终全部以 `arm64` 原生方式运行，最终活动 PATH 不包含 Intel Homebrew 路径。
12. Brewfile 是经 Agent 预审批维护的“期望状态”；mise 与 uv 使用明确版本，不使用 `latest`。
13. 密钥不进入仓库、Git 历史、诊断输出或长期普通备份；旧 shell 历史中的疑似密钥完成轮换和定向清理。
14. Intel Homebrew 的 formula、cask、服务和数据目录全部有明确处置状态，可由迁移脚本的一条受保护 `--retire --apply` 命令正式退役，并可由同一脚本 `--status` 查询退役记录。
15. 公开前同时完成 Agent 发布预审批、本地/CI Gitleaks 全历史扫描和托管平台安全检查；仓库可见性仍由用户手工修改。

### 3.2 首期非目标

- 不迁移 macOS `defaults`、系统偏好、Apple ID、应用账号或 GUI 应用数据。
- 不在首期接管 `.gitconfig`、SSH、tmux、编辑器设置等其他 dotfiles；只做脱敏盘点并列入后续 backlog。
- 不备份整个 Intel Homebrew Cellar。
- 不自动安装 Mac App Store 应用；只生成本地盘点报告。
- 不自动删除 Homebrew 未管理的 `/usr/local` 内容，不执行 `rm -rf /usr/local`，也不整体 `chown` `/usr/local`。
- 不为回滚重新安装 Intel Homebrew。
- 不把公司仓库或本地层纳入 MIT License。

### 3.3 完成后的可观察状态

前置阶段 0 和三个顶层阶段各自有独立的完成条件：

| 阶段 | 完成标志 |
|---|---|
| 0. 建议与配置导出 | Zsh 修改建议已先独立生成并完成三档分类与第一次预审批，建议阶段没有导出候选配置；`destination-map.toml` 已记录固定 local-only 根和用户选择的 public/company 目标；随后才单独导出当前设备配置，原文件与候选文件均完成最佳实践评估；public/company 候选文件已生成在用户选择的仓库与路径中但未 stage/commit，local-only 已生成在 `~/.config/dotfiles/local/`，retire/unresolved 仍在仓库外报告中；候选文件已完成第二次预审批 |
| 1. 仓库能力 | 用户选择的 public 仓库+路径中的两个真实 Zsh 入口、公司同步契约、配置安装/诊断/回滚命令、独立 Intel→ARM 迁移脚本、隔离 HOME/迁移 fixture、CI、中英 README 和密钥扫描全部通过；无需修改真实 HOME 或卸载软件即可验收 |
| 2. 本地应用 | 本机真实入口 symlink、固定三层加载、迁移脚本 `--apply` 的 ARM 替代工具、密钥边界、备份与 manifest 验证通过；状态明确标记“本地配置与 ARM 迁移完成，Intel Homebrew 未退役” |
| 3. Intel Homebrew 退役 | 本机所有 Intel 项目已归类、替代已验证、退役成功，且可查询 retired record；本机达到下方最终 ARM 状态 |

```text
arch                         -> arm64
command -v brew              -> /opt/homebrew/bin/brew
brew --prefix                -> /opt/homebrew
command -v node/bun/pnpm/go  -> mise 管理的原生版本
command -v uv               -> ARM 原生 uv
uv python find --managed-python -> uv 管理的 ARM Python
$path                        -> 无重复项、无活动 /usr/local Homebrew 项
zsh -l -i -c exit            -> 无加载错误
dotfiles verify              -> 正确性与安全性检查通过
./scripts/migrate-intel-homebrew-to-arm.sh --status -> 能查询本次迁移/退役清单、替代关系和结果
```

## 4. 不可破坏的安全约束

1. 前置阶段 0 对已安装软件只读；除受控本地状态目录外，只能写计划固定的 `~/.config/dotfiles/local/` 以及用户选择并明确授权的 public/company 仓库内路径；不得建立 symlink、安装/卸载软件、轮换密钥或清理历史。
2. 导出前必须检查用户选择的 public/company 工作区与固定的 `~/.config/dotfiles/local/`；对已存在的文件或未提交修改不得覆盖。如果候选文件与现有内容冲突，导出必须停止并生成差异/冲突报告；不得自动换到 staging 或其他默认目录。
3. 前置阶段 0 在任何内容进入用户选择的 public 工作树前必须先脱敏并完成归属分类；company、local-only、retire、unresolved 内容和原始诊断输出不得写入 public 候选文件。
4. 前置阶段 0 的“Zsh 修改建议”和“当前设备配置导出”不得合并执行。建议操作只能写诊断/建议报告，禁止写 public/company/local-only 候选配置；配置导出必须校验同一 `run-id` 的第一次预审批状态，只消费 accept/revise 建议。建议重新生成或预审批结论变化后，既有导出立即失效并必须重新执行；本门禁不要求逐条或逐文件计算哈希。
5. 前置阶段 0 不得运行 `git add`、`git commit`、`git push` 或修改仓库可见性。Zsh 建议和导出候选分别由 Agent 按三档分类并映射为 accept/revise/reject/defer；只有顶层阶段 1 可以根据候选预审批结论 stage/commit。
6. 顶层阶段 1 的构建和 CI 只能操作仓库工作树、临时目录和隔离 HOME；不得修改开发者的真实 shell 入口或包管理器。
7. `install.sh` 无参数运行只允许为顶层阶段 2 收集配置并生成计划，不得应用修改，也不执行前置阶段 0。
8. `./install.sh apply` 只允许应用顶层阶段 2 的两个真实入口 symlink、可选 `~/.config/dotfiles/company` 稳定 symlink 与私有分层配置，必须在变更前展示计划标识和 manifest；它不得安装 ARM 替代项，也不得调用迁移或 Intel Homebrew 卸载路径。`./scripts/migrate-intel-homebrew-to-arm.sh --apply` 独占 ARM 替代安装、服务/数据迁移与验证，并把新增软件和 cleanup 预览与可回滚配置分开记录。
9. 迁移脚本的 `--apply` 与顶层阶段 3 的 `--retire --apply` 都必须在原生 `arm64` 会话运行；非 `arm64` 会话直接阻断。日常 `.zprofile/.zshrc` 不实现 Rosetta/x86_64 兼容、Intel 路径回退或架构分支。
10. 顶层阶段 3 必须由同一迁移脚本的 `--retire` 显式发起，并且只接受同一台机器上该脚本 `--apply` 产生且已验证的 manifest/退役账本。
11. Intel 退役必须在真实 TTY 中展示清单，并由用户亲自输入精确确认短语；Agent、CI、管道输入和普通 `--yes` 都不得代替。
12. 任何 Git 更新只允许 `fetch` 和显式的 `pull --ff-only`；禁止自动 `reset`、`stash`、force checkout 或覆盖未提交修改。
13. 所有远程 URL 必须拒绝内嵌用户名、token 或密码；认证交给 SSH agent、Keychain 或托管平台 credential helper。
14. 公司仓库默认只提供声明式内容。任何公司 hook 都必须进入计划、显示路径与摘要并单独获批。
15. 日志、报告和 CI artifact 不得包含密钥值、Keychain 输出、完整环境变量或未脱敏的 shell 历史。
16. 本地明文密钥例外文件必须是 `0600`，父目录必须是 `0700`；公司仓库不得保存任何密钥。
17. 未归类的 Intel 程序、运行中服务、cask 或服务数据会阻止退役。
18. 性能数据只给建议，不作为强制门槛；语法、加载、架构、密钥、权限、备份和 manifest 正确性才是阻断项。

## 5. 仓库与本机目录模型

### 5.1 远程仓库

| 层 | 初始可见性 | 允许内容 | 禁止内容 |
|---|---|---|---|
| 公开候选仓库 | 私有，通过 Agent 发布预审批后可由用户手工公开 | 通用 Zsh、Brewfile、mise/uv 策略、插件目录、安装/测试/文档 | 密钥、公司域名/路径/账号、机器专属路径 |
| 公司仓库 | 公司批准的私有服务 | 公司 CLI、路径、Brewfile、补全、非密钥环境配置 | API key、个人 GitHub 私有仓库兜底、未经批准的任意执行 |
| 本地层 | 无远程 | 机器路径、个人应用路径、插件选择、允许的明文密钥例外、迁移临时文件 | Git、云同步、公开报告 |

公开候选仓库最终公开时采用 MIT License。公司仓库和本地层保持私有且不受该许可证覆盖。

### 5.2 来源配置

本节的 `sources.toml` 只服务于顶层阶段 2 的最终用户 clone/update 来源，不用于前置阶段 0 选择产物目的地。阶段 0 必须使用第 5.3.1 节的用户确认映射，不能从本节默认值推导。

本机保存：

```text
~/.config/dotfiles/sources.toml
```

建议的受限 schema：

```toml
schema_version = 1

[personal]
enabled = true
source = "git@host.example:USER/dotfiles.git"
path = "/Users/USER/.local/share/dotfiles/personal"

[company]
enabled = false
source = ""
path = "/Users/USER/.local/share/dotfiles/company"
```

约束：

- 首次运行先自动探测个人仓库来源与公司仓库来源：origin 和目录结构匹配时直接写入计划；公司来源不存在、不可访问或未获授权时自动使用 `skip`。只有存在多个相互冲突且无法由证据排除的来源时，才汇总为一个阻塞问题。
- 默认本地目录分别为 `~/.local/share/dotfiles/personal` 与 `~/.local/share/dotfiles/company`；Agent 根据现有 checkout 和路径冲突自动采用或调整，并在计划中记录，不逐项要求用户确认。
- `source` 可以是 Git URL 或已有本地路径。已有目录只验证，不删除、不重建；URL 对应目录不存在时才克隆。
- 运行脚本的当前仓库不得被静默当作个人仓库；Agent 必须展示探测结果，并在 origin、目录结构和本计划一致时将其归为“一定要改/可直接采用”的来源；证据冲突时才作为单个阻塞项报告。
- `sources.toml` 不提交 Git。

### 5.3 本机目录

```text
~/.local/share/dotfiles/
├── personal/                         # 公开候选仓库 checkout
├── company/                          # 公司仓库 checkout，可不存在
├── oh-my-zsh/                        # 固定 revision
└── plugins/                          # 固定 revision 的外部插件

~/.config/dotfiles/
├── sources.toml
├── company -> <selected-company-root> # 可选稳定 symlink；company=skip 时不存在
└── local/
    ├── zsh/
    │   ├── profile.zsh               # login 私有覆盖，本地最高优先级
    │   ├── pre.zsh                   # Oh My Zsh/compinit 之前的私有覆盖
    │   └── rc.zsh                    # Oh My Zsh 之后的私有交互覆盖
    ├── macos/Brewfile                # 本机私有期望状态
    ├── mise/90-local.toml            # 本机工具版本覆盖
    ├── uv/                            # 本机 uv 策略或版本声明
    ├── plugins/selection.toml         # 本机插件选择
    └── inventory/                     # 本地参考清单，不含密钥

~/.local/state/dotfiles/
├── stage0/<run-id>/
│   ├── source-inventory/               # 脱敏现状清单与来源定位
│   ├── reports/                        # 最佳实践、归属、三档分类与 Agent 预审批结论
│   └── manifest/                       # 目的地映射、生成文件、run-id 与处置状态；0E 后仅生成一次整体摘要
├── backups/<run-id>/
├── manifests/<run-id>/
├── reports/<run-id>/
├── retired-homebrew/<run-id>/
└── locks/

~/.local/state/zsh/
└── history
```

状态目录不得由安装器自动清理；只提供 `list` 和带预览、带确认的 `prune`。

`~/.config/dotfiles/company` 是两个真实 Zsh 入口定位 company 固定文件的唯一稳定路径。`install.sh apply` 根据 `sources.toml` 已验证的 company checkout+repo root 幂等建立该 symlink；目标必须是已授权 checkout 内根路径，不得链接到公开仓库、云同步目录或任意外部路径。company=`skip` 时不创建该 symlink。入口不解析 `sources.toml`、不读取动态环境变量，也不推导 checkout 位置。

前置阶段 0 的存储边界：

- 原始且可能含敏感信息的诊断中间结果不得保存；`source-inventory/` 只保存脱敏后的文件、行号/项目标识和不可逆指纹。
- public 候选文件只能写入用户在 `destination-map.toml` 中选择的 public Git checkout 及仓库内相对路径；Agent 不得因为当前工作目录看起来匹配就自动采用本仓库。
- company 候选文件只能写入用户选择且已授权的 company Git checkout 及仓库内相对路径；是否 `skip` 也必须由用户明确选择，不得根据当前访问状态自动代选。
- local-only 候选文件只能写入计划已定义的 `~/.config/dotfiles/local/`；其 root 是 `~/.config/dotfiles`，不得改成 `stage0/<run-id>/`、当前目录或任何 Git/云同步目录。
- 固定 local-only 目标或用户选择的 public/company 目标如果不可写、越界或与现有内容冲突，导出就停止并在 `reports/export-conflicts.md` 中报告；不得回退到另一个自动路径。
- retire 和 unresolved 项只写入仓库外报告；未决项会阻止顶层阶段 1 将对应配置落库。

#### 5.3.1 前置阶段 0 目的地选择

第一次 Agent 预审批完成后、任何 dump/export 或候选文件写入前，必须记录固定 local-only 目标，并把 public/company 两项作为一个集中问题请用户选择，不得拆成逐文件询问：

| 归属 | 决定方式 | 不允许的行为 |
|---|---|---|
| `local-only` | 计划固定：root 为 `~/.config/dotfiles`，配置相对根为 `local/`；不询问用户 | 另造一个 local-only root，或将配置直接写到 `~/.config/dotfiles/zsh/` |
| `public` | 一个已存在的 Git checkout，加一个仓库内相对根路径（仓库根使用 `.`） | 自动采用当前 dotfiles 仓库、origin 或推测路径 |
| `company` | 一个已存在且已授权的私有 Git checkout，加一个仓库内相对根路径；如本次不输出则显式选 `skip` | 自动选个人私库、自动因无权限而 `skip`、自动推测公司仓库 |

选择结果保存到 `~/.local/state/dotfiles/stage0/<run-id>/manifest/destination-map.toml`，建议 schema 如下：

```toml
schema_version = 2
run_id = "<run-id>"

[local-only]
root = "/Users/USER/.config/dotfiles" # ~/.config/dotfiles 的绝对形式
relative_root = "local"

[public]
repo_checkout = "/absolute/path/to/user-selected/public-repo"
repo_relative_root = "."

[company]
mode = "write" # 或 "skip"
repo_checkout = "/absolute/path/to/user-selected/company-repo"
repo_relative_root = "dotfiles"
```

Agent 可以自动读取所选 checkout 的 Git root、origin、可见性线索和工作树状态来做验证，但不能据此替用户选择另一个仓库或路径。`repo_relative_root` 必须是无 `..` 且不越过 checkout 根的相对路径。local-only `root` 必须等于当前用户 `$HOME/.config/dotfiles` 的规范化绝对路径，`relative_root` 必须等于 `local`；Agent 只校验并记录这两个固定值，不询问、不推测新路径。如果 `~/.config/dotfiles/local/` 中的固定 Zsh 文件已被当前 source 链加载，或目标文件已存在且内容不同，阶段 0 必须停止并报告冲突，不能为规避冲突而改写到另一 local-only root。

这份映射不进入 public/company Git。如果用户更改 public/company 任一目的地，旧导出标记为 stale，必须对受影响归属重新导出和验证。

### 5.4 前置阶段 0 的注释、最佳实践与 Agent 预审批契约

前置阶段 0 必须对“当前源文件”和“拟生成候选文件”分别做评估，不得因为配置在当前机器可以运行，就认定它适合进入仓库。最佳实践检查以诊断指南为基线，至少覆盖：

- Zsh 语法、启动文件职责、login/interactive 边界和防御式加载。
- `PATH`/`fpath` 顺序、唯一性、幂等性、架构和命令实际来源。
- 补全/插件所有权、`compinit` 次数、插件顺序、固定 revision 和供应链风险。
- 环境变量作用域、密钥暴露、用户/公司/机器路径、文件权限与可公开性。
- Homebrew formula/cask/tap/service 的用途、当前架构、重复职责、维护状态、替代方案和是否应进入 Brewfile。
- mise、uv、Bun、Node、pnpm、Go 等工具的安装/版本/激活所有权，以及是否使用明确版本。
- alias/function/wrapper 的参数边界、副作用、错误处理、命名、可移植性和破坏性确认。
- 候选文件的真实入口边界、私有固定 source 点、重复内容、加载顺序、OMZ 模板骨架保真度、注释正确性和可测试性。

目标格式安全支持行尾注释时，每个可独立决策的安装项或配置项必须使用下列固定字段：

```text
# 功能=<为什么存在>；最佳实践=<pass|rewrite|replace|remove|review>；修改级别=<一定要改|建议修改|可以不改>；建议=<保留/改写/替代项及理由>；归属=<public|company|local-only|retire|unresolved>；验证=<不含敏感值的检查方式>
```

示例：

```ruby
brew "zoxide" # 功能=智能目录跳转；最佳实践=replace；修改级别=建议修改；建议=替代 autojump 并先导入数据；归属=public；验证=command -v zoxide
```

```zsh
plugins=(git) # 功能=Git alias 与补全；最佳实践=pass；修改级别=可以不改；建议=保留 OMZ 内置插件；归属=public；验证=补全与常用 alias 可用
```

注释规则：

- 候选 `.zsh` 和 Brewfile 必须保留上述同行注释；顶层阶段 1 的 Agent 预审批可以修正结论，但除非格式或可读性明确不允许，最终落库文件仍应保留结构化注释。例外是 `.zshrc` 中从固定 OMZ revision 原样保留的官方模板行：不得为了元数据在行尾追加注释，其决策和验证记录写入 `reports/file-decisions.tsv`；只有新增受管区块内的可决策项继续优先使用同行注释。
- 对 JSON、签名文件、上游生成文件或其他不安全支持注释的格式，不得硬塞注释；在 `reports/file-decisions.tsv` 中用文件+字段/对象路径记录同样信息。
- 功能和建议必须可验证，不得使用“常用工具”“优化体验”之类无法审查的空泛说法。
- public 注释本身也必须可公开，不得因为二进制或密钥已移除就在注释中留下公司名、内部域名、账号或机器路径。

阶段 0 必须进行两次彼此独立的 Agent 预审批，不能用一次“整体同意”同时代替建议预审批和候选文件预审批，也不得把它们改回逐项询问用户的流程。

第一次预审批只处理 Zsh 修改建议。Agent 先填写三档修改级别，再决定配置导出可以消费什么：

| 修改级别 | 默认建议决策 | 当前设备配置导出动作 |
|---|---|---|
| `一定要改` | `accept`；原方案不完整时为 `revise` | Agent 直接生成或修订对应 Zsh 候选内容并验证 |
| `建议修改` | `accept`；实现细节需调整时为 `revise` | Agent 默认纳入候选并验证，不逐项询问用户 |
| `可以不改` | `reject` | 不导出对应改动，保留现状或记录 backlog |

`defer` 不是第四种修改级别，只用于缺少证据且会阻断安全/正确性的事项。Agent 必须先穷尽只读证据；确需用户决定时集中报告阻塞项，不得逐条追问。

第一次预审批的产物是 `reports/recommendation-decisions.tsv`。它必须记录 `run_id`、修改级别、自动决策和证据；任何建议内容或决策变化都会使同一 run 中已生成的候选文件失效，但此处不计算建议报告哈希。

第二次预审批发生在配置导出完成后，Agent 为每个候选文件和每个 `review/unresolved` 项复核三档分类并记录候选决策：

| 决策 | 含义 | 顶层阶段 1 动作 |
|---|---|---|
| `accept` | 候选内容、注释、归属和三档分类一致 | 按候选文件更新目标仓库 |
| `revise` | 方向成立，但内容、注释、归属、修改级别或替代方案需调整 | Agent 直接按预审批意见改写，重新验证后落库 |
| `reject` | 属于“可以不改”或不应进入目标仓库 | 不落库；按预审批结论改归 local-only/retire、backlog 或删除候选副本 |
| `defer` | 证据不足且会阻断安全/正确性 | 保持仓库外，列入 unresolved；汇总为阻塞问题，不得先 commit 后补审 |

前置阶段 0 产物与顶层阶段 1 提交建立精简追溯关系：每个最终落库文件必须能指向 `run_id`、Zsh 建议项、三档修改级别、两次预审批决策和顶层阶段 1 中的修改/验证结果；0E 只为整组最终产物生成一次整体摘要，顶层阶段 1 落库后记录 Git commit ID。追溯报告不得包含原始密钥或未脱敏内容。

### 5.5 前置阶段 0 到顶层阶段 1 的候选文件格式契约

当前设备配置导出的生成方式可以是工具原生 dump、只读命令组合、现有文件整理，或 Agent 根据本机安装和实际命令来源生成；但生成方式不能决定最终格式或输出位置。所有交给顶层阶段 1 的候选文件必须遵循本节 `stage0-candidate/v8` 契约；v8 将 public Zsh 收敛为可直接 symlink 的 `zsh/.zprofile` 和 `zsh/.zshrc` 两个真实入口，取消 `entrypoints/`、通用 loader 和 public phase 文件；company/local-only 保留 profile/pre/rc 三阶段覆盖，但每层每阶段只允许一个固定文件。目的地和追溯字段继续沿用 v7。

任何 v7 Zsh 候选在本版本计划下都必须标记为 stale，不得通过简单改名、拼接或保留转发入口转换成 v8。实施必须以旧 source 链为证据，重新生成两个真实入口和六个可选私有固定文件，完成 OMZ 模板对照、语法/安全验证和第二次预审批后才能落库。

```text
本机文件/安装状态
  → 原始证据（dump、list、source map；仅脱敏后保存在 source-inventory）
    → Zsh 修改建议（只写报告，禁止导出候选配置）
      → Agent 三档分类 + 第一次预审批 accept/revise/reject/defer
        → 单独启动当前设备配置导出
          → 规范化候选文件（路径、格式和内容均与顶层阶段 1 目标一致）
            → 语法/schema/安全验证
              → Agent 三档复核 + 第二次预审批 accept/revise/reject/defer
```

Zsh 修改建议不是候选文件，建议操作结束时不得在任何 public/company/local-only 目的地创建配置树。当前设备配置导出必须是后续单独操作，并首先验证 `recommendation-decisions.tsv` 的 `run_id`、建议 ID 覆盖、第一次预审批状态与同一 run 的 `destination-map.toml` 一致。

原始 dump 也不是候选文件。即使工具能直接 dump，也必须在配置导出操作中经过以下规范化步骤：删除传递依赖和机器偶然状态、分离 public/company/local-only/retire/unresolved、固定版本或 revision、改成目标文件的稳定排序与语法、补全结构化注释，并执行目标格式验证。无法可靠转换的项目进入 `unresolved`，不得用猜测值或占位符生成看似完整的候选文件。

配置类产物的实际输出路径必须按下列公式计算，且只能使用用户选择的根路径：

```text
local-only: ~/.config/dotfiles/local/<classification-relative-path>
public:     <public.repo_checkout>/<public.repo_relative_root>/<stage-1-public-relative-path>
company:    <company.repo_checkout>/<company.repo_relative_root>/<stage-1-company-relative-path>
```

其中 `classification-relative-path` 必须符合所属层的 Zsh 结构契约：public Zsh 只使用 `zsh/.zprofile` 和 `zsh/.zshrc`；company/local-only 只使用 `zsh/profile.zsh`、`zsh/pre.zsh`、`zsh/rc.zsh` 三个固定文件。非 Zsh 文件例如 `macos/Brewfile`。禁止以 `*.dump`、`*.raw`、`inventory-*` 或工具私有导出格式替代下表中的目标文件，也禁止因工作树冲突而自动生成到另一个 staging 目录。

阶段 0 完成后，配置类主产物应能直接在固定或用户选择的对应目的地中看到。典型路径如下：

```text
<public-repo>/<public-root>/zsh/.zprofile
<public-repo>/<public-root>/zsh/.zshrc
<public-repo>/<public-root>/macos/Brewfile
<public-repo>/<public-root>/tooling/mise/10-public.toml
<public-repo>/<public-root>/tooling/uv/uv.toml
<public-repo>/<public-root>/tooling/uv/.python-versions
<public-repo>/<public-root>/zsh/plugins/{catalog,revisions}.toml

<company-repo>/<company-root>/zsh/{profile,pre,rc}.zsh
<company-repo>/<company-root>/macos/Brewfile
<company-repo>/<company-root>/mise/50-company.toml
<company-repo>/<company-root>/plugins/catalog.toml
<company-repo>/<company-root>/diagnostics/rules.toml

~/.config/dotfiles/local/zsh/{profile,pre,rc}.zsh
~/.config/dotfiles/local/macos/Brewfile
~/.config/dotfiles/local/mise/90-local.toml
~/.config/dotfiles/local/uv/*
~/.config/dotfiles/local/plugins/selection.toml
```

上述是可能产物集，不要求为没有实际内容的类别创建空文件。`brew bundle dump` 必须写到由 `mktemp -d` 创建的 run 内临时目录，不进入三类目的地，规范化和验证结束后即删除，不是稳定产物；public/company 的 `<selected-root>/macos/Brewfile` 与 local-only 的 `~/.config/dotfiles/local/macos/Brewfile` 才是经去除传递依赖、分层、稳定排序、注释和预审批后的阶段 0 配置产物。

| 顶层阶段 1 目标文件 | 前置阶段 0 可使用的来源 | 阶段 0 必须产出的候选格式 | 最低验证 |
|---|---|---|---|
| public `zsh/.zprofile` | 当前 `.zprofile` 与 login 环境片段 | 可直接作为 `~/.zprofile` symlink 目标的 UTF-8 Zsh 文本；内联实现仅 ARM 的 PATH/login 配置，再按 company→local 显式 source 固定 `profile.zsh`；不 source public loader | `zsh -n`；隔离 HOME 的 login 场景；symlink 目标正确；无 Intel 运行时路径 |
| public `zsh/.zshrc` | 当前 `.zshrc`、安装器片段、alias/function/补全/插件初始化 | 以固定 Oh My Zsh revision 的 `templates/zshrc.zsh-template` 为骨架，尽量保留原生注释、段落顺序、`plugins=(...)` 和 `source $ZSH/oh-my-zsh.sh`；只在带始末标记的受管区块中加入 ARM/public 配置和私有钩子；官方模板中的 Intel 路径示例必须删除 | `zsh -n`；隔离 HOME 的 interactive/non-login interactive 场景；模板骨架对照；OMZ/`compinit` 一次；无 Intel 运行时路径 |
| company/local-only `zsh/profile.zsh`、`zsh/pre.zsh`、`zsh/rc.zsh` | 公司、机器或个人专属配置 | 每层每阶段最多一个固定 UTF-8 Zsh 文件；`profile.zsh` 由 `.zprofile` 加载，`pre.zsh` 在 OMZ 之前加载，`rc.zsh` 在 OMZ 之后加载；不允许 `${phase}.d/*.zsh` 分片 | `zsh -n`；public → company → local-only 覆盖顺序；固定 source 点；可选文件缺失时正常启动 |
| `macos/Brewfile` | 现有 Brewfile、`brew bundle dump`、`brew leaves`、formula/cask/tap/service 清单、Agent 判断 | Homebrew Bundle Ruby DSL；只保留经预审批的期望状态，按 `tap`/`brew`/`cask` 分组并在组内稳定排序；每项带同行注释 | Brewfile 解析/`brew bundle check --file=...`；重复项、归属与架构检查 |
| `tooling/mise/10-public.toml`、公司 `mise/50-company.toml` | 现有 mise 配置、已安装运行时和实际命令来源、Agent 判断 | mise TOML 的 `[tools]` 等受支持字段；只写明确版本或明确的无默认策略，不写 `latest`，public/company 分层 | TOML 解析；mise 配置检查；工具所有权冲突检查 |
| `tooling/uv/uv.toml` | 现有 uv 配置、uv/Python 安装状态、Agent 判断 | uv 支持的 TOML 配置键；不混入项目级依赖或本机绝对路径 | TOML 解析；固定版本 uv 的配置检查 |
| `tooling/uv/.python-versions` | uv 管理的 Python 列表、项目与全局需求 | uv 原生多版本文件；每行一个明确 Python 版本，稳定排序；不写 `latest`、系统路径或当前机器缓存路径 | 固定版本 uv 读取；行格式、重复项和 ARM 可用性检查 |
| `zsh/plugins/catalog.toml`、`zsh/plugins/revisions.toml` | 当前插件目录、OMZ 插件列表、Git remote/revision、Agent 判断 | 第 6 节 schema 对应的 TOML；catalog 记录用途、加载阶段、依赖、风险和默认选择，revisions 只记录固定 commit/tag | TOML/schema；source URL 安全；revision 存在且非浮动引用 |
| 公司 `plugins/catalog.toml`、`diagnostics/rules.toml` | 公司配置、公司 CLI/补全和脱敏诊断需求 | 公司 schema 对应的 TOML；真实内部值只能进入获授权公司候选目录 | TOML/schema；公司/public 边界和无密钥检查 |
| `reports/file-decisions.tsv`、`manifest/files.tsv` | 上述全部证据和候选文件 | 本节定义的 UTF-8 TSV 表头与逐项记录；字段内禁止 tab、换行和敏感值 | 表头、枚举、run-id、路径和一一覆盖检查；不要求逐文件 SHA-256 |

public 受管区块的边界标记必须固定，例如：

```zsh
# >>> dotfiles: arm64 public configuration >>>
# 经预审批的 public 配置
# <<< dotfiles: arm64 public configuration <<<
```

`.zshrc` 中受管区块不得重排或复制 Oh My Zsh 官方模板的主体段落。实施时必须记录模板所属 OMZ revision，对照上游模板检查只有三类允许差异：经预审批的值修改、用户已确认不保留的 Intel 路径示例删除、带固定始末标记的受管区块。public 不得生成 `entrypoints/`、`lib.zsh`、`profile.d.zsh`、`pre.d.zsh`、`rc.d.zsh` 或通用 phase loader。company/local-only 不得生成 `${phase}.d/` 分片目录。

本节是顶层阶段 1 创建正式 schema、fixture 和校验器时必须实现的最低兼容基线。顶层阶段 1 如果需要调整候选格式，必须先版本化契约、把受影响项标记为 `revise` 并重新生成/验证，不得静默解释旧候选。

#### 5.5.1 规范化候选示例

Zsh 候选使用目标真实入口/固定私有覆盖语法，而不是把整份旧 `.zshrc` 作为字符串或报告保存：

```zsh
typeset -U path PATH # 功能=保持 PATH 唯一且保留首次出现顺序；最佳实践=rewrite；修改级别=一定要改；建议=替代重复字符串拼接；归属=public；验证=重复 source 后 PATH 无重复项
[[ -d "$HOME/.local/bin" ]] && path=("$HOME/.local/bin" "${path[@]}") # 功能=启用用户级命令目录；最佳实践=pass；修改级别=建议修改；建议=目录存在时加入；归属=public；验证=目录存在时 whence 能解析其中命令
export PATH # 功能=把规范化 PATH 传递给子进程；最佳实践=pass；修改级别=一定要改；建议=在 `.zprofile` ARM public 受管区块末尾统一导出；归属=public；验证=zsh 子进程读取 PATH
```

Brew dump 必须转换为审阅后的 Brewfile DSL；不能把 dump 时间、完整依赖闭包或本机偶然安装项带入候选：

```ruby
brew "git" # 功能=提供版本控制 CLI；最佳实践=pass；修改级别=建议修改；建议=由 ARM Homebrew 提供统一版本；归属=public；验证=command -v git && file "$(command -v git)"
brew "zoxide" # 功能=智能目录跳转；最佳实践=replace；修改级别=建议修改；建议=替代 autojump 并迁移数据；归属=public；验证=command -v zoxide
cask "iterm2" # 功能=提供终端应用；最佳实践=review；修改级别=可以不改；建议=公共默认 GUI 应用属于偏好项，保持本机选择；归属=local-only；验证=brew info --cask iterm2
```

上例只说明阶段 1 所需的候选语法和同行注释格式，不代表三个项目已获准落库。归属仍为 `unresolved` 的项目只能进入仓库外报告，不能进入 public/company 候选文件；归属为 public/company 但最佳实践结论是 `review` 的项目必须先由 Agent 完成三档分类，并在 0E 获得 `accept/revise` 才能由顶层阶段 1 落库。

mise 候选必须是可直接被阶段 1 使用的 TOML，并固定实际版本：

```toml
[tools]
node = "22.0.0" # 功能=提供 Node.js 运行时；最佳实践=review；修改级别=一定要改；建议=以实施时从只读证据确定的精确版本替换示例值；归属=public；验证=mise exec -- node --version
go = "1.23.0" # 功能=提供 Go 工具链；最佳实践=review；修改级别=一定要改；建议=以实施时从只读证据确定的精确版本替换示例值；归属=public；验证=mise exec -- go version
```

示例版本只说明格式，不是本项目默认值。阶段 0 必须从实际需求与安装证据生成可验证的精确版本；证据不足时进入 `unresolved`，不得复制示例值。

uv 候选使用 uv 原生的用户配置语法和多版本文件。`tooling/uv/uv.toml` 示例：

```toml
python-preference = "only-managed" # 功能=只使用 uv 管理的 Python；最佳实践=pass；修改级别=一定要改；建议=避免与系统/pyenv Python 混用；归属=public；验证=uv python find --managed-python
python-downloads = "manual" # 功能=限制隐式下载；最佳实践=pass；修改级别=建议修改；建议=只在阶段 2 明确安装计划中下载 Python；归属=public；验证=缺少版本时普通 uv 命令不自动下载
```

`tooling/uv/.python-versions` 示例：

```text
3.12.3
3.13.1
```

这些版本同样只说明“每行一个精确版本”的格式，不是默认选择。阶段 0 应从 `uv python list --only-installed` 等只读证据与实际需求形成候选，再由 Agent 按三档分类预审批应保留哪些版本。

#### 5.5.2 追溯文件的固定表头

`reports/recommendation-decisions.tsv` 的第一行固定为：

```text
run_id\trecommendation_id\tsource_locator\tfunction\tfinding\trecommendation\tchange_class\tclassification\tverification\trecommendation_decision\treview_note
```

`manifest/files.tsv` 的第一行固定为：

```text
contract_version\trun_id\tsource_kind\tsource_locator\tgenerator\trecommendation_ids\ttarget_repository\ttarget_path\tformat\tchange_class\tclassification\tbest_practice\treview_decision\tfinal_path\tfinal_commit
```

`reports/file-decisions.tsv` 的第一行固定为：

```text
run_id\ttarget_repository\ttarget_path\titem_locator\trecommendation_ids\tfunction\tbest_practice\tchange_class\trecommendation\tclassification\tverification\treview_decision\treview_note
```

上述 `\t` 表示一个真实 tab，文件中不得保存为反斜杠加字母 `t`。三个 TSV 的 `run_id` 必须一致，并与 `destination-map.toml` 的 `run_id` 一致。`change_class` 只允许 `must-change`、`recommended-change`、`may-keep`，分别对应“一定要改”“建议修改”“可以不改”。`recommendation_decision` 是配置导出前的第一次 Agent 预审批，`review_decision` 是导出后的候选文件第二次 Agent 预审批，两者不得复用同一字段或互相推导。Zsh 候选必须填写 `recommendation_ids`；非 Zsh 候选允许为空，但仍需填写 `change_class` 并完成候选预审批。`generator` 只允许 `dump-normalized`、`agent-derived`、`source-split` 或 `manual`；它用于说明生成方式，不降低目标格式要求。`target_repository` 只允许 `public`、`company`、`local-only` 或 `none`，并必须解析到目的地映射的对应 section；其中 retire/unresolved 等无候选目标的报告项使用 `none`。public/company 的 `target_path` 相对于用户选择的仓库内根，local-only 的 `target_path` 相对于固定的 `~/.config/dotfiles/local/`；它不得是另一个绝对路径。`classification` 使用 public/company/local-only/retire/unresolved，两个决策字段使用第 5.4 节枚举。候选初次生成时允许 `review_decision`、`final_path` 和 `final_commit` 为空，0E 结束时必须填充 `review_decision`，只有顶层阶段 1 实际落库后才填写 `final_path` 和 `final_commit`。v8 不保存 `raw_evidence_sha256`、`recommendation_report_sha256` 或 `candidate_sha256`。

0E 完成后生成一次 `manifest/stage0-summary.sha256`。其输入是同一 `run_id` 下按相对路径稳定排序的 `destination-map.toml`、最终建议/决策 TSV、public/company/local-only 候选内容和 public/company 仓库 diff 的规范化串流；只保存这一份整体摘要，不生成逐文件 checksum 清单。顶层阶段 1 只在消费阶段 0 输入前验证一次，落库后由 `final_commit` 接管追踪。

## 6. 公开候选仓库目标结构

```text
dotfiles/
├── README.md                          # 完整中英双语；用户与 Agent 唯一入口
├── LICENSE                            # MIT
├── install.sh                         # /bin/zsh；无参数只配置并生成 plan
├── bin/
│   └── dotfiles                       # 日常管理命令，/bin/zsh
├── zsh/
│   ├── .zprofile                       # ~/.zprofile 的真实 symlink 目标
│   ├── .zshrc                          # ~/.zshrc 的真实 symlink 目标，保留 OMZ 官方模板骨架
│   └── plugins/
│       ├── catalog.toml
│       └── revisions.toml
├── scripts/
│   └── migrate-intel-homebrew-to-arm.sh # 独占 Intel→ARM 迁移、验证与退役
├── macos/
│   └── Brewfile
├── tooling/
│   ├── mise/10-public.toml
│   └── uv/
│       ├── uv.toml
│       └── .python-versions
├── schemas/
│   ├── sources.example.toml
│   ├── company-repository.schema.md
│   ├── plugin-catalog.schema.md
│   └── manifest.schema.md
├── tests/
│   ├── fixtures/
│   │   └── company-repo/             # 无敏感值的公司层契约 fixture
│   ├── syntax.zsh
│   ├── isolated-home.zsh
│   ├── idempotence.zsh
│   ├── rollback.zsh
│   └── homebrew-retirement-fixture.zsh
├── .githooks/
│   └── pre-commit
└── .github/workflows/
    └── verify.yml
```

不创建 `bootstrap.sh`，也不创建 `AGENTS.md`。README 必须完整描述 Agent 协议；`install.sh` 只负责配置应用，Intel→ARM 全流程只由 `scripts/migrate-intel-homebrew-to-arm.sh` 负责。public Zsh 只允许 `.zprofile`、`.zshrc` 和 `plugins/*.toml`；不得保留 `entrypoints/`、`lib.zsh`、`zsh/lib/`、`zsh/profile.d*`、`zsh/pre.d*`、`zsh/rc.d*` 或任何通用 loader placeholder。

上述整个目录是顶层阶段 1 在用户选择的 public 仓库内根路径下的最终交付物。前置阶段 0 应当先按相同目标路径生成可从当前机器推导的 `.zsh`/Brewfile/mise/uv/插件/诊断规则等候选文件，并在预审批报告中列出 README、`install.sh`、schema、测试和 CI 等无法由本机现状直接推导、仍需顶层阶段 1 实现的目标文件。

顶层阶段 1 不得将前置阶段 0 工作树直接整体 commit；必须消费 Agent 预审批决策，完成必要的 revise/reject/defer、补齐新文件，再在隔离 HOME 和 fixture 中验证顶层阶段 2/3 的命令路径。顶层阶段 1 自身不允许修改真实 `~/.zprofile`、`~/.zshrc` 或 Homebrew。

## 7. 公司仓库契约

前置阶段 0 必须先将当前机器中的公司配置与公开/本地内容分离，并仅向用户选择且已授权的 company checkout+仓库内路径生成候选文件；冲突时停止，不回退到 company staging。顶层阶段 1 根据 Agent 预审批结论更新该公司仓库与路径，并同时在用户选择的 public 仓库中产出公司仓库需遵循的文件契约、schema 和无敏感值 fixture。公司仓库建议只允许以下固定入口：

```text
company-dotfiles/
├── README.md
├── zsh/
│   ├── profile.zsh
│   ├── pre.zsh
│   └── rc.zsh
├── macos/Brewfile
├── mise/50-company.toml
├── plugins/catalog.toml              # 可选，公司插件扩展
├── diagnostics/rules.toml            # 不含密钥值
└── hooks/                             # 默认不执行
```

顶层阶段 1 对公司层的交付规则：

- 用户选择的 public 仓库+路径保存公司仓库 schema、可公开文档、加载契约和脱敏 fixture，用于保证公开层与公司层兼容。
- 如果用户在阶段 0 目的地映射中选择了获批的 company checkout+路径，实施者应在该目标中产出上述声明式文件并运行同一组契约验证；未获明确授权不得 push。
- 如果公司仓库为 `skip` 或当前不可访问，顶层阶段 1 仍必须完成 schema 和 fixture，但交付报告只能标记“公司同步文件已定义、实际公司仓库待同步”，不得声称公司仓库已完成。
- 两个真实 Zsh 入口、安全接口和命令实现只存在于公开仓库；公司仓库只同步 `profile.zsh`、`pre.zsh`、`rc.zsh` 三个固定覆盖文件和契约所需的声明式文件，不复制公开入口或创建第二套 loader。
- 任何公司名、域名、账号、内部路径和真实公司插件来源只能写入用户选择的 company 私有仓库+路径，不得反向同步到 public 目标。

- 公司仓库缺失、未启用或暂时不可访问时，公开层和本地层仍必须可用。
- 已存在且此前验证过的公司 checkout 可继续加载；更新失败只警告，不阻塞公开层更新。
- 公司仓库的 Zsh 文件在 `apply/verify` 中出现语法错误时阻断；日常 shell 中加载失败时警告并降级。
- 公司 hook 不能仅因存在而执行。计划必须列出 hook 的 SHA-256、路径、用途和拟执行命令，并另行确认。

## 8. Zsh 启动文件职责与加载顺序

### 8.1 明确边界

| 文件 | 管理策略 | 职责 | 禁止事项 |
|---|---|---|---|
| `~/.zshenv` | 不管理，只审计 | 无 | 不设置 `ZDOTDIR`，不放 PATH、插件或密钥 |
| `~/.zprofile` | 稳定 symlink 到 public `zsh/.zprofile` 真实入口 | login 环境、基础 ARM PATH、需要被登录会话后代继承的非敏感变量，以及 company/local `profile.zsh` 固定覆盖 | 别名、补全、主题、交互 widget、Intel 路径或架构兼容分支 |
| `~/.zshrc` | 稳定 symlink 到 public `zsh/.zshrc` 真实入口 | 保留 OMZ 官方模板骨架；交互历史、工具激活、补全、主题、插件、别名、函数、wrapper，以及 company/local `pre.zsh`/`rc.zsh` 固定覆盖 | 全局明文密钥、Intel 路径或回退、通用 loader、phase 目录遍历 |

`~/.zprofile` 和 `~/.zshrc` 必须是稳定 symlink，分别直接指向个人仓库的 `zsh/.zprofile` 和 `zsh/.zshrc`。这两个仓库文件本身就是完整启动文件，不得只作为跳转器，也不得间接 source public `lib.zsh` 或通用 phase loader。

Oh My Zsh 上游只提供 `.zshrc` 模板，不提供或接管 `.zprofile`。因此“尽可能保留 OMZ 原生安装格式和内容”的约束只作用于 `zsh/.zshrc`：它必须以固定 revision 的官方 `zshrc.zsh-template` 为基线；`zsh/.zprofile` 则按 Zsh 原生 login 启动语义保持最小、线性且可直接阅读，只包含 ARM login 环境和两个固定私有 `profile.zsh` source 点，不伪造 OMZ 风格模板。

### 8.2 PATH 策略

- `.zprofile` 内联使用 Zsh `path` 数组和唯一化语义构造 login PATH；`.zshrc` 只做交互场景的幂等兜底，不调用独立 PATH 模块。
- Apple Silicon Homebrew 只接受 `/opt/homebrew/bin` 与 `/opt/homebrew/sbin`。
- `~/.local/bin` 必须有且只出现一次，以容纳 uv 工具等用户级可执行文件。
- 不手写 NVM、pyenv、旧 pnpm、Bun curl installer 或 Intel Homebrew PATH。
- `apply/verify` 检查 PATH 每一项是否存在、是否重复、Homebrew 来源是否严格为 `/opt/homebrew`；public 运行时配置不保留任何 Intel 前缀兼容逻辑。

### 8.3 `.zprofile` 顺序

```text
1. `zsh/.zprofile` 内联构造 public ARM login PATH 和稳定非敏感环境
2. 如已启用 company，显式 source `~/.config/dotfiles/company/zsh/profile.zsh`
3. 显式 source `~/.config/dotfiles/local/zsh/profile.zsh`
```

company/local-only 的 `profile.zsh` 都是可选固定文件；不存在时静默跳过，存在时严格按 company→local-only 顺序各 source 一次。不允许 glob、目录遍历、aggregate/fallback 或动态排序。

### 8.4 `.zshrc` 顺序

```text
1. 保留固定 OMZ revision 的官方 `zshrc.zsh-template` 头部注释、`export ZSH`、主题与选项段落
2. 在官方 `plugins=(...)` 附近保留经 Agent 三档分类与预审批的内置插件列表
3. 在 `source $ZSH/oh-my-zsh.sh` 之前的固定受管区块，依次显式 source `~/.config/dotfiles/company/zsh/pre.zsh` 与 `~/.config/dotfiles/local/zsh/pre.zsh`
4. 保留官方 `source $ZSH/oh-my-zsh.sh` 原生行和位置，且只执行一次
5. 在官方 `# User configuration` 段内的 public 受管区块加入历史、mise、zoxide、alias、function 和 bindings
6. 在 OMZ 之后依次显式 source `~/.config/dotfiles/company/zsh/rc.zsh` 与 `~/.config/dotfiles/local/zsh/rc.zsh`
7. 最后激活外部 ZLE 插件；`zsh-syntax-highlighting` 必须是最后 source 的外部插件
```

Oh My Zsh 负责唯一一次 `compinit`。public/company/local-only 均不得再手动执行第二次 `compinit`。主题保持官方模板默认 `robbyrussell`，暂不引入 Powerlevel10k 或第二个插件管理器。`.zshrc` 的 OMZ 模板对照是结构契约，不允许为了“模块化”将官方段落移出真实入口。

### 8.5 日常降级行为

- 可选 company/local-only 固定文件不存在：静默跳过。
- 已存在的私有文件加载失败：输出一条不含文件内容的简短警告，并继续提供 public 基础 shell。
- `install.sh apply` 和 `verify`：已启用的固定私有文件任一语法/加载错误都必须阻断，不能以日常降级掩盖安装缺陷。
- 普通名称允许按 public < company < local-only 覆盖；`dotfiles diagnose` 通过检查三个固定 source 点和实际定义来源展示覆盖结果，不在启动时维护模块来源数组。
- manifest、迁移/退役和安全 wrapper 的内部名称不得由 company/local-only 覆盖；实施使用狭前缀，不为此创建通用 reserved-names loader。

## 9. 环境变量、普通变量、别名与函数

### 9.1 变量规则

- 只有子进程确实需要的稳定、非敏感变量才 `export`。
- `workc`、`refc` 等只供交互函数使用的路径是普通变量，不 `export`；它们属于公司层或本地层。
- `DISABLE_TELEMETRY`、`ANTHROPIC_MODEL` 等工具专属变量放入对应 wrapper，只传给该命令。
- API key 不允许在 `.zprofile`、公开/公司 `.zshrc` 或 mise `[env]` 中全局导出。

### 9.2 命令抽象规则

- 简短、无参数、无副作用的替换可以使用 alias。
- 带参数、分支、目录切换、错误处理或多个步骤的行为必须使用 function。
- 有破坏性的函数必须使用明确名称、默认预览并二次确认。
- `pullmain` 应实现为函数：确认仓库与工作区状态、保存原分支名、fetch、仅 fast-forward、失败后恢复原目录/分支；不得自动 stash/reset。
- `ccauto` 等组合行为应实现为函数并保留参数边界。
- `wow` 等机器专属应用路径只放本地层。

## 10. 历史与密钥管理

### 10.1 Zsh 历史

建议的公开历史策略：

```text
HISTFILE=~/.local/state/zsh/history
HISTSIZE > SAVEHIST
启用 APPEND_HISTORY、EXTENDED_HISTORY、去重、HIST_IGNORE_SPACE、HIST_NO_STORE
禁用 SHARE_HISTORY 和实时跨终端写入
```

- 状态目录权限 `0700`，历史文件权限 `0600`。
- 不把“前导空格”当作主要密钥保护；它只是应急措施。
- README 必须明确：不要在命令行直接写入密钥字面值。

### 10.2 macOS Keychain

仓库不实现 `dotfiles secret set/exec` 之类自定义 CLI，只提供以下类型的示例：

1. 用隐藏输入方式把值写入 `/usr/bin/security add-generic-password`。
2. 用 `/usr/bin/security find-generic-password -w` 在 wrapper 调用时读取。
3. 通过 `VAR="$value" command ...` 只注入当前命令，随后清除 shell 局部变量。
4. Keychain service 名统一使用 `dotfiles:<VARIABLE_NAME>`，account 使用当前用户或文档明确的账号名。

示意 wrapper（实施时须先验证 `security` 的具体参数，不能把真实值写进命令示例）：

```zsh
claude() {
  local anthropic_key
  anthropic_key="$(/usr/bin/security find-generic-password \
    -a "$USER" -s 'dotfiles:ANTHROPIC_API_KEY' -w)" || return

  ANTHROPIC_API_KEY="$anthropic_key" \
  DISABLE_TELEMETRY=1 \
  ANTHROPIC_MODEL='已确认的模型名' \
    command claude "$@"

  unset anthropic_key
}
```

### 10.3 明文例外

只有工具无法按命令临时注入时，才允许使用：

```text
~/.config/dotfiles/local/zsh/rc.zsh
```

要求：

- 密钥例外必须放在该固定 `rc.zsh` 的独立标记区块内；一旦含任何明文例外，整个文件权限必须是 `0600`，父目录 `0700`。
- 不进入 Git、iCloud、Dropbox 或任何未经明确批准的同步/备份目标；是否允许 Time Machine 收录必须单独决定。
- 诊断只检查存在性、权限和 symlink 目标，不读取或输出内容。

### 10.4 旧配置与历史清理

1. 本地扫描旧 `.zshrc/.zprofile` 和 `~/.zsh_history`。
2. 报告只含变量类别、文件、命中数和不可逆脱敏指纹，不含完整值。
3. 先把对应密钥录入 Keychain 并轮换；未轮换不得宣称修复完成。
4. 生成历史定向删除预览并由 Agent 分类处置；由于历史删除不可逆，仍须集中获得一次用户显式授权，之后只删除命中记录并保留其他历史，不逐条确认。
5. 历史原文件可短期隔离备份为 `0600`，并提供独立删除命令；不得上传或进入通用备份 artifact。
6. 普通长期配置备份必须脱敏。为安全删除的明文密钥行不属于可回滚内容。

## 11. 插件与 Oh My Zsh

### 11.1 首版默认推荐

| 名称 | 类型 | 默认 | 解决的问题 | 关键约束 |
|---|---|---:|---|---|
| `git` | Oh My Zsh 内置 | 是 | 常用 Git alias/补全 | 随固定 OMZ revision |
| `zoxide` | OMZ 集成 + Homebrew 二进制 | 是 | 替换 autojump，智能目录跳转 | 导入 autojump 数据后再卸载旧工具 |
| `zsh-autosuggestions` | 外部插件 | 是 | 基于历史给出输入建议 | 固定 commit/tag |
| `zsh-syntax-highlighting` | 外部插件 | 是 | 输入时发现无效命令和语法问题 | 必须最后 source |
| `fzf` | Homebrew 二进制/可选集成 | 否 | 模糊文件与历史选择 | 启用前说明 Ctrl-R/Ctrl-T 等快捷键变化 |

### 11.2 插件目录字段

`zsh/plugins/catalog.toml` 中每项至少包含：

```text
id、display_name、kind、default_selected、reason、pain_point、source_url、
revision、install_owner、dependencies、activation_phase、load_order、
conflicts、security_notes、performance_notes、uninstall_steps
```

- `kind` 必须区分 OMZ 内置插件、外部插件、补全脚本、二进制集成和纯激活逻辑。
- 首次无参数 `install.sh` 或显式重新配置时，Agent 根据当前命令使用、快捷键冲突、启动耗时和依赖自动分类：一定要改/建议修改项默认启用，可以不改项保持现状；选择保存在本地 `plugins/selection.toml`，不逐项询问。
- 非交互 CI 使用 fixture 中的明确 profile，不依赖默认按回车。
- Oh My Zsh 和外部插件固定 tag/commit，关闭自动更新。
- 升级命令只生成上游差异和候选 revision；测试通过并提交 revision 文件后才生效。

## 12. 工具所有权与版本策略

| 管理器 | 唯一职责 | 不再负责 |
|---|---|---|
| Homebrew ARM | 系统 CLI、原生库、GUI cask，以及 mise、uv、zoxide、fzf 等宿主工具 | Node/Python 多版本、npm/pip 全局包 |
| mise | Bun、Node 兼容版本、pnpm、Go、Gitleaks 及其他需要固定版本的跨项目 CLI | Python 版本、Python venv、Python tool |
| Bun | 默认 JS/TS runtime 与项目包管理器 | 全局 Node 版本切换 |
| uv | Python 版本、项目依赖、venv、Python CLI tool | Node/Go、系统库 |

### 12.1 mise

- 全局配置利用 mise 官方 `~/.config/mise/conf.d/*.toml` 合并：

```text
~/.config/mise/conf.d/10-public.toml  -> 公开仓库
~/.config/mise/conf.d/50-company.toml -> 公司仓库，可选
~/.config/mise/conf.d/90-local.toml   -> 本地层
```

- 后加载文件覆盖前文件，项目中的 `mise.toml`/`.mise.toml` 再覆盖全局默认。
- 所有工具写明确版本；禁止 `latest`。
- `mise activate zsh` 只在交互 `.zshrc` 执行一次。
- 不自动信任任意项目配置；保持 mise trust 提示，禁止全局信任 `/`。
- 公开/公司全局片段默认只允许 `[tools]` 和经过 Agent 预审批的静态设置；`[env]`、hook、task、动态文件读取等可执行能力必须进入单独计划并获批，不能借 mise 绕过公司 hook 规则。

### 12.2 uv

- uv 是唯一 Python 管理器，移除 pyenv 和重复的 pipx/virtualenv 管理层。
- `tooling/uv/.python-versions` 使用 uv 原生多版本格式并逐行写明确版本；实施时用 `uv python install <exact-version>`。
- 项目使用 `pyproject.toml`、`requires-python`、`.python-version` 和 `uv.lock` 覆盖全局默认。
- Python CLI 用 `uv tool install` 管理，并记录工具与 Python 版本。
- 不使用自动“最新版本”升级；Agent 必须根据兼容证据选择明确版本、分类并预审批，升级是显式维护任务。

### 12.3 清理的旧入口

- NVM 初始化与 `~/.nvm` PATH。
- pyenv 初始化与 shims。
- Intel Homebrew `/usr/local/bin`、`/usr/local/sbin` 运行时回退。
- 旧 autojump source。
- 重复 Bun、pnpm、Go PATH。
- 重复 compinit。

## 13. Brewfile 策略

### 13.1 分层文件

```text
personal/macos/Brewfile
company/macos/Brewfile        # 可选
~/.config/dotfiles/local/macos/Brewfile
```

- 三个文件都是经 Agent 三档分类与预审批维护的期望状态。
- `brew bundle dump` 只能在前置阶段 0D 的独立配置导出操作中生成带时间戳的审计输入；0A–0C 禁止运行。dump 不得直接覆盖任何正式或候选 Brewfile。
- 应用前检查重复 tap/formula/cask、层间冲突和 owner 归属。
- Homebrew 是滚动发布管理器，Brewfile 不设计 lockfile；需固定版本的语言运行时由 mise/uv 管理。
- `brew bundle cleanup` 默认只预览；不在通用 `apply` 中使用 `--force`。

### 13.2 cask、服务与 App Store

- cask 单独盘点：目标状态只允许 ARM/Universal、原生替代或淘汰；现有 Rosetta 应用只作为迁移证据，不进入最终 Brewfile 或兼容配置；不删除应用数据。
- 原 Intel `brew services` 逐项记录服务名、状态和配置/数据路径。Agent 自动分类迁移必要性并生成 runbook；由于服务启停可能影响有状态业务，实际启停仍作为不可代理边界集中请求一次明确授权，然后逐项验证。
- `/usr/local/var`、`/usr/local/etc` 等服务数据按服务制定迁移步骤；未知或未确认目录阻止退役，通用命令不得递归删除。
- Mac App Store 应用只生成本地清单，不自动 `mas install`，不处理 Apple ID。

## 14. 安装器与日常命令接口

### 14.1 实现约束

- `install.sh`、`bin/dotfiles` 和 `scripts/migrate-intel-homebrew-to-arm.sh` 使用系统 `/bin/zsh` 和 macOS 内置工具。
- 引导阶段不得依赖 Homebrew、Bun、uv、Python、Node 或 jq。
- `sources.toml` 只接受本文定义的简单字段，解析器必须拒绝未知关键安全字段、重复 section 和无效路径。
- 所有写操作都有 lock、run-id、manifest 和明确退出码。

### 14.2 `install.sh`

`install.sh` 是顶层阶段 1 落库后提供给每台机器的使用者入口，不是前置阶段 0 的仓库生产工具。前置阶段 0 依据诊断指南与本计划的 Agent 预审批契约执行；不得为了复用 `install.sh` 而把未预审批的本机结论写入仓库。

```text
./install.sh                         # 顶层阶段 2：交互配置 + 只读诊断 + 生成 plan；绝不 apply
./install.sh configure               # 顶层阶段 2：重新配置来源和插件选择
./install.sh plan                    # 顶层阶段 2：重新生成本地应用计划
./install.sh apply                   # 顶层阶段 2：只应用真实入口 symlink 和私有分层配置
./install.sh verify                  # 顶层阶段 2：配置正确性/安全检查 + 性能建议
./install.sh rollback <run-id>       # 顶层阶段 2：回滚可逆配置变更
```

`./install.sh apply` 成功后必须停在配置应用边界，manifest 明确标记“本地配置完成，Intel→ARM 迁移未由本命令执行”。代码中不得存在从 `install.sh apply` 调用迁移脚本或自动 fall through 到任何 Homebrew 写操作的路径。

### 14.3 Intel→ARM 独立迁移脚本

`scripts/migrate-intel-homebrew-to-arm.sh` 是 Intel Homebrew 全生命周期的唯一写操作实现，`install.sh` 和 `bin/dotfiles` 不得复制或包装其迁移/退役逻辑：

```text
./scripts/migrate-intel-homebrew-to-arm.sh                    # 顶层阶段 2：只读盘点、生成/刷新迁移计划
./scripts/migrate-intel-homebrew-to-arm.sh --apply            # 顶层阶段 2：安装 ARM 替代、迁移已授权服务/数据并验证
./scripts/migrate-intel-homebrew-to-arm.sh --verify           # 只读重验 ARM 替代、服务/数据和退役准备度
./scripts/migrate-intel-homebrew-to-arm.sh --retire           # 顶层阶段 3：只生成/刷新最终退役预览
./scripts/migrate-intel-homebrew-to-arm.sh --retire --apply   # 顶层阶段 3：不可逆退役，需真实 TTY 精确确认
./scripts/migrate-intel-homebrew-to-arm.sh --status           # 查询迁移、退役和残留审计记录
```

无参数、`--verify`、`--retire` 和 `--status` 均只读；只有 `--apply` 与 `--retire --apply` 允许写系统状态。`--retire --apply` 不得与普通 `--apply` 同次执行，且必须先校验同一台机器上普通 `--apply` 的成功 manifest、机器标识和退役账本。

该文件必须以可执行模式 `0755` 纳入仓库，使用自身绝对路径推导仓库根，不假设仓库位于 `~/dotfiles` 或其他固定 checkout。任何写模式都必须先确认当前进程为原生 `arm64`；非 `arm64` 直接退出且不产生系统变更。脚本只可在自身迁移状态目录中记录旧 Intel 绝对路径，不得把旧前缀写入配置 apply manifest、最终 Brewfile、Zsh 入口或普通安装文档示例。

### 14.4 `dotfiles`

```text
dotfiles status
dotfiles diagnose [--performance]
dotfiles verify
dotfiles sources status
dotfiles sources update                 # fetch + 差异报告
dotfiles sources update --apply         # 仅 pull --ff-only
dotfiles plugins status|plan-update
dotfiles backup list
dotfiles backup prune [--apply]
```

`dotfiles` 可以在 `status/diagnose` 中显示迁移脚本最近状态文件，但不提供 `homebrew apply/retire` 类写入子命令，以避免第二套入口和实现漂移。

### 14.5 README 中的 Agent 协议

README 必须同时提供完整中文与完整英文正文，并使用相同章节编号、命令块和安全警告。Agent 流程固定为：

1. 先判断当前任务是“前置阶段 0 的 Zsh 修改建议与第一次 Agent 预审批”、“预审批后的当前设备配置导出与第二次 Agent 预审批”、“顶层阶段 1 候选落库”，还是“使用已交付仓库执行单机顶层阶段 2/3”；不得在 Zsh 建议任务中顺带导出候选配置，不得绕过第一次预审批启动导出，也不得把未预审批候选文件当作已交付配置。
2. 如果任务是 Zsh 修改建议，只生成建议报告、稳定 ID 和第一次预审批状态，报告后停止；不得运行 dump/export、计算中间哈希或创建候选配置树。
3. 如果任务是当前设备配置导出，先校验同一 run-id、建议 ID 覆盖和第一次预审批，然后记录固定的 local-only 根 `~/.config/dotfiles` 与 `local/` 相对根，并集中请用户一次选择 public 仓库+路径和 company 仓库+路径/`skip`。不得自动采用当前仓库；目的地验证通过后再单独导出、完成第二次预审批并在 0E 末尾生成一次整体摘要后停止；不得继续进入顶层阶段 1 commit。
4. 完整阅读 README，检查架构、Git 工作区和来源配置。
5. 顶层阶段 2 的配置应用只能从无参数 `./install.sh` 或 `./install.sh plan` 开始。
6. 把可逆配置变更按三档分类，记录风险、备份、manifest 和阻断项；当用户已要求实施且没有不可代理阻塞项时运行 `./install.sh apply` 和 `./install.sh verify`，完成后停止；不得自动启动 Homebrew 迁移。
7. 只有用户要求 Intel→ARM 迁移时，才先无参数运行 `./scripts/migrate-intel-homebrew-to-arm.sh`；根据计划分类和完成服务启停等不可代理授权后，显式运行 `--apply` 和 `--verify`。
8. 普通 `--apply` 成功后必须停在顶层阶段 2；不得因 ARM 替代验证通过就自动启动顶层阶段 3。
9. 只有用户单独提出或明确确认进入顶层阶段 3 时，才运行 `./scripts/migrate-intel-homebrew-to-arm.sh --retire` 生成最终预览。
10. 正式退役必须再次报告不可逆边界，并让用户亲自在真实 TTY 中通过 `./scripts/migrate-intel-homebrew-to-arm.sh --retire --apply` 输入精确短语。
11. 退役后再次运行迁移脚本 `--verify` 和 `--status`，交付 retired record、最终报告和后续建议。

README 必须明确禁止 Agent 自动创建远程仓库、自动改仓库可见性、自动信任公司 hook、自动 force Git 或代替用户确认不可逆卸载。

## 15. Manifest、备份与回滚

### 15.1 每次 run 的产物

前置阶段 0 使用独立产物：

```text
~/.local/state/dotfiles/stage0/<run-id>/manifest/files.tsv
~/.local/state/dotfiles/stage0/<run-id>/reports/inventory.md
~/.local/state/dotfiles/stage0/<run-id>/reports/zsh-recommendations.md
~/.local/state/dotfiles/stage0/<run-id>/reports/recommendation-decisions.tsv
~/.local/state/dotfiles/stage0/<run-id>/reports/export-report.md
~/.local/state/dotfiles/stage0/<run-id>/reports/file-decisions.tsv
~/.local/state/dotfiles/stage0/<run-id>/reports/zsh-best-practices.md
~/.local/state/dotfiles/stage0/<run-id>/reports/export-best-practices.md
~/.local/state/dotfiles/stage0/<run-id>/reports/unresolved.md
~/.local/state/dotfiles/stage0/<run-id>/reports/export-conflicts.md       # 仅冲突时
~/.local/state/dotfiles/stage0/<run-id>/manifest/destination-map.toml
~/.local/state/dotfiles/stage0/<run-id>/manifest/stage0-summary.sha256
```

`zsh-recommendations.md` 是第一次操作的唯一主交付物；`recommendation-decisions.tsv` 以同一 `run_id` 记录三档分类与第一次 Agent 预审批。两者完成前不得创建 `files.tsv` 或候选文件树，也不生成中间哈希。

`destination-map.toml` 是配置类产物的唯一输出根映射；它只记录用户选择，不允许 Agent 写入推测默认。`files.tsv` 必须使用第 5.5.2 节固定表头，记录契约版本、run-id、来源类别、脱敏来源定位、生成方式、关联建议 ID、候选目标类别、相对于已选根的候选路径、格式、三档修改级别、归属、最佳实践结论、候选预审批决策、顶层阶段 1 最终提交路径和 commit ID。对于不支持注释的格式，`file-decisions.tsv` 使用第 5.5.2 节固定表头，作为同行注释的 sidecar 替代。

顶层阶段 1 的每个最终提交项必须在 `file-decisions.tsv` 中有 `accept` 或 `revise` 候选预审批决策；Zsh 项还必须通过同一 `run_id` 和 `recommendation_ids` 关联 `recommendation-decisions.tsv` 中的 `accept/revise` 决策与三档分类。任一预审批为 `reject/defer`、缺少分类/决策、run-id 不一致或最终整体摘要验证失败时不得落库。

顶层阶段 2 的配置 apply 使用独立的本机产物：

```text
~/.local/state/dotfiles/manifests/<config-run-id>/metadata.toml
~/.local/state/dotfiles/manifests/<config-run-id>/actions.tsv
~/.local/state/dotfiles/backups/<config-run-id>/...
~/.local/state/dotfiles/reports/<config-run-id>/plan.md
~/.local/state/dotfiles/reports/<config-run-id>/verify.md
```

独立迁移脚本使用另一套命名空间，不得复用配置 apply 的 run-id 或把 Homebrew 动作写入配置 manifest：

```text
~/.local/state/dotfiles/migrations/<migration-run-id>/metadata.toml
~/.local/state/dotfiles/migrations/<migration-run-id>/inventory.tsv
~/.local/state/dotfiles/migrations/<migration-run-id>/retirement-ledger.tsv
~/.local/state/dotfiles/migrations/<migration-run-id>/actions.tsv
~/.local/state/dotfiles/migrations/<migration-run-id>/reports/plan.md
~/.local/state/dotfiles/migrations/<migration-run-id>/reports/verify.md
~/.local/state/dotfiles/migrations/<migration-run-id>/status.toml
~/.local/state/dotfiles/retired-homebrew/<migration-run-id>/retirement-manifest.sha256  # 仅顶层阶段 3
```

配置与迁移各自的 `actions.tsv` 至少记录：顺序、动作类型、目标、修改前类型、备份相对路径、结果和回滚动作。可逆配置 apply 不记录逐文件修改前/后 SHA-256；正确性由备份存在性、目标类型、symlink 指向、权限、实际命令验证和 rollback 演练保证。迁移 `--apply`、`--verify`、`--retire` 和 `--status` 必须围绕同一 `migration-run-id` 延续状态，最终退役只能消费这次迁移的已验证账本。报告不得写配置文件内容或密钥。

### 15.2 备份范围

应备份：

- 现有非敏感或已脱敏的 Zsh 配置。
- symlink 目标、权限和 owner；可逆配置不额外计算内容哈希。
- PATH/命令解析与架构报告。
- Intel/ARM Homebrew 的 formula、leaves、cask、tap、services、Brewfile 审计快照。
- NVM/npm 全局包、pyenv/Python、pipx/uv tool、Bun/pnpm/Go 等清单。
- 迁移账本和 Intel 替代映射。

不得进入普通备份：

- Keychain 值、完整环境变量、密钥字面值。
- 整个 Cellar。
- 未脱敏 shell 历史；历史只允许按第 10.4 节短期本地隔离。

### 15.3 回滚边界

- 在 Intel 退役前：可回滚 symlink、真实入口/固定私有覆盖、来源、插件选择和多数配置。
- 密钥轮换、明文密钥清除不可恢复；回滚只能继续使用 Keychain wrapper。
- Homebrew 新增包默认不由 rollback 自动卸载，只生成 cleanup 预览，避免删除其他项目正在使用的依赖。
- Intel Homebrew 退役后：不恢复 `/usr/local` Homebrew；只修复/重装 ARM 替代项。
- 服务数据迁移按具体服务的 runbook 回滚，不由通用脚本猜测。

## 16. 运行时不提供 Intel 兼容

不创建任何临时 Intel Zsh 兼容文件。public/company/local-only 的 `.zprofile`、`.zshrc`、`profile.zsh`、`pre.zsh`、`rc.zsh` 都不得加入 Intel Homebrew PATH、Rosetta 分支、Intel wrapper 或 ARM→Intel fallback。

迁移期尚未替代的 Intel 命令只能由 `scripts/migrate-intel-homebrew-to-arm.sh` 在受控子进程中以已盘点的绝对路径短时调用；脚本不得把该路径 export 到用户 shell、写入任何 Zsh 配置或留下持久 wrapper。迁移中止时，`--status` 只报告未完成替代项，不启用运行时兼容。

## 17. Intel Homebrew 迁移与退役脚本

本节的盘点、ARM 替代安装、服务/数据迁移、验证、退役和记录查询必须全部实现在 `scripts/migrate-intel-homebrew-to-arm.sh` 中。该脚本是普通运行时禁止 Intel 路径规则的唯一例外，且例外仅用于识别、迁移和移除旧状态。

### 17.1 退役账本

每个旧项目必须有一行：

```text
kind | old_name | old_path | old_arch | old_version | owner/source |
target_state | replacement_name | replacement_manager | replacement_path |
replacement_arch | verification_command | service/data_note | status
```

`target_state` 只允许：

- `arm_replaced`：已安装并验证 ARM 替代。
- `renamed_replacement`：由不同名称/工具替代。
- `managed_elsewhere`：由 mise、uv 或其他已确认管理器接管。
- `retired_by_choice`：Agent 根据使用证据归为“可以不改/可淘汰”并完成预审批；真正删除仍受顶层阶段 3 的统一真实 TTY 确认保护。
- `unresolved`：未处理；会阻止退役。

### 17.2 服务与数据

运行中服务必须经过：

```text
记录状态 -> 识别配置/数据 -> 备份或迁移 -> 停止 Intel 服务 ->
安装 ARM 服务 -> Agent 汇总服务启停计划 -> 用户对有状态服务集中授权一次 -> 验证状态/端口/数据 -> 标记完成
```

未知的 `/usr/local/var`、`/usr/local/etc` 内容不得由通用退役命令删除。

### 17.3 迁移、退役与查询命令

迁移计划与应用：

```zsh
./scripts/migrate-intel-homebrew-to-arm.sh
./scripts/migrate-intel-homebrew-to-arm.sh --apply
./scripts/migrate-intel-homebrew-to-arm.sh --verify
```

普通 `--apply` 必须按退役账本安装 ARM 替代项、执行已获授权的服务/数据 runbook，并在不卸载 Intel Homebrew 的前提下生成已验证迁移 manifest。

预览：

```zsh
./scripts/migrate-intel-homebrew-to-arm.sh --retire
```

正式执行：

```zsh
./scripts/migrate-intel-homebrew-to-arm.sh --retire --apply
```

正式命令必须：

1. 验证当前进程是 `arm64`、ARM Homebrew 健康、所有旧项已归类。
2. 再次验证 ARM 替代命令的路径、架构和版本输出。
3. 验证所有运行中服务和 cask 已处理，服务数据不存在未知项。
4. 冻结最终退役 manifest，并只为这份不可逆操作清单生成 `retirement-manifest.sha256`；预览或清单变化后必须重新生成。
5. 显示官方卸载将影响的路径、Agent 预审批 manifest 和该整体 SHA-256。
6. 要求用户在真实 TTY 输入精确确认短语，并在执行前验证 manifest 仍与该 SHA-256 一致。
7. 使用 Homebrew 官方卸载机制处理 `/usr/local` 前缀；实施时固定并记录官方脚本来源 revision/哈希，先下载并由 Agent 审查，不使用不透明的 `curl | shell`。
8. 只对 manifest 中已确认的遗留程序文件执行后续处理；不递归删除 `/usr/local`。
9. 审计 public/company/local-only Zsh 固定文件不含 Intel 运行时路径或兼容分支，刷新 shell 命令路径缓存并启动干净 login/interactive shell 验证。
10. 把每个项目的旧路径/架构、替代路径/架构、处置状态、时间和执行结果写入 `retired-homebrew/<run-id>/`。

查询记录：

```zsh
./scripts/migrate-intel-homebrew-to-arm.sh --status
```

退役是不可逆边界。命令成功后，rollback 不得自动重新安装 Intel Homebrew。

## 18. 分阶段实施顺序

下文先定义一个独立前置阶段 0，再定义三个顶层实施阶段。数字后的字母是该阶段内部的子阶段，不是新的顶层阶段。

### 前置阶段 0：先提出 Zsh 修改建议，再单独导出当前设备配置

本阶段是仓库生产的前置步骤，由仓库维护者在一台现有机器上执行，不是每个终端用户的安装步骤。它不计入三个顶层实施阶段，不通过 `install.sh` 执行。Zsh 修改建议与配置导出是两个独立操作：可以在不同时间、不同 Agent turn 中执行，必须有不同的开始条件、输出目录状态和完成标志。

实施可以由 Agent 直接执行，也可以在顶层阶段 1 后补充维护者工具；无论实现方式如何，都必须暴露两个不同的操作意图。若提供命令，接口至少等价于：

```text
stage0 zsh-recommend
stage0 configure-destinations --recommendation-run <run-id>
stage0 export-config --recommendation-run <run-id> --destinations <destination-map.toml>
```

禁止提供会把建议、目的地选择和导出自动串联的 `stage0 all`、`--continue-to-export` 或类似入口。`configure-destinations` 必须在第一次预审批后自动记录固定 local-only 目标，并集中请用户填写 public/company 两类目的地；`export-config` 必须由维护者或实施 Agent 在映射验证通过后重新显式发起。

#### 0A：只读发现与脱敏现状清单

- 完整阅读诊断指南，检查当前 `.zshenv`、`.zprofile`、`.zshrc`、`.zlogin`、其全部 source 链、权限、symlink 和启动场景。
- 脱敏收集 PATH/fpath、环境变量名称、alias、function、wrapper、补全、插件、主题、历史策略和工具激活。
- 为后续导出预先脱敏盘点现有 Brewfile 与 Intel/ARM Homebrew 的 tap/formula/leaf/cask/service/data，以及 mise、uv、Bun、Node、pnpm、Go、Python、NVM、pyenv、pipx 等所有权，但本子阶段不得生成这些配置的候选文件。
- 只能运行不会生成配置文件的只读 inspect/list/status 命令，或由 Agent 读取现有配置和命令实际来源形成证据；本子阶段禁止 `brew bundle dump` 及其他会写出配置文件的 dump/export 功能。脱敏证据只记录来源定位、run-id 和稳定项目 ID，不逐项计算哈希，也不得触发候选导出。
- 查找顶层阶段 1 目标树中已经有当前来源的文件，并列出尚无当前来源、需要顶层阶段 1 新建的 README、安装器、schema、测试和 CI 等文件。
- 密钥与历史只记录类别、脱敏来源、命中数和不可逆指纹，不记录值。

产物：脱敏 `inventory.md`、source map、已安装项清单、目标文件覆盖矩阵和敏感信息处置清单。

#### 0B：只生成 Zsh 修改建议

- 只分析 `.zshenv`、`.zprofile`、`.zshrc`、`.zlogin` 和完整 source 链；对每个可独立决策的 Zsh 项说明当前功能与实际命令来源，不根据名称猜测。
- 做文件级和逐项最佳实践检查，记录语法、启动文件职责、加载顺序、幂等性、PATH/fpath、补全、插件、架构、安全、所有权、可移植性、性能和可公开性问题。
- 对每项给出“保留、改写、替代、移除或待决”建议，并强制标注“一定要改 / 建议修改 / 可以不改”，说明建议代码形态、理由、风险、public/company/local-only/retire/unresolved 归属和验证方式。
- 每条建议分配稳定 `recommendation_id`，并关联当前 `run_id`，便于后续导出精确引用；本子阶段不生成建议报告 SHA-256。
- 本子阶段只能写 `inventory.md`、`zsh-recommendations.md`、`zsh-best-practices.md` 和未决报告；不得在任何 public/company/local-only 目的地创建或修改候选配置树，也不得把建议直接改写回当前 `.zshrc`。

产物：`zsh-recommendations.md`、`zsh-best-practices.md`、run-id、稳定建议 ID 和 Zsh unresolved 清单。完成标志为 `zsh_recommendations=ready_for_preapproval`，不是“配置已导出”。

#### 0C：第一次 Agent 预审批——分类并批准 Zsh 修改建议

- Agent 只查看 Zsh 现状、问题证据和修改建议，不在这次预审批中批准尚未生成的候选文件。
- 对每个 `recommendation_id` 先记录 `change_class`，再按第 2.1/5.4 节默认映射记录 accept/revise/reject/defer；revise 必须先更新建议报告和决策记录，但不计算中间哈希；reject 不允许导出对应项，defer 只用于真正阻断的未决证据。
- `recommendation-decisions.tsv` 必须使用同一 `run_id` 并完整覆盖当前 `zsh-recommendations.md` 的建议 ID；建议或决策缺失、run-id 不一致时，配置导出不得开始。
- 本次预审批结束后仍不得存在由本 run 生成的候选配置树。

产物：`recommendation-decisions.tsv` 和 `zsh_recommendations=preapproved` 门禁状态。

#### 0D：单独导出当前设备配置

- 必须由新的显式操作启动；首先验证 0C 完成状态、同一 run-id、建议 ID 覆盖和每条 Zsh 建议决策，不允许从 0B/0C 自动继续执行。
- 在任何 dump/export 前先读取并验证同一 run 的 `destination-map.toml`。如果不存在，先运行 `configure-destinations`：自动写入 local-only 的固定 `~/.config/dotfiles` root 和 `local/` 相对根，再把 public 仓库+相对路径、company 仓库+相对路径/`skip` 一次性询问用户。Agent 不得询问或另行推测 local-only 路径，也不得自行填入 public/company 选择。
- 在写入前展示一张“归属 → 仓库/根目录 → 相对路径 → 最终绝对路径”预览表，并检查 Git root/origin、路径越界、工作树冲突、本地目录是否进入 Git/云同步边界以及写权限。冲突时终止，不自动改目的地。
- 只有本子阶段可以运行 `brew bundle dump` 等会生成配置文件的原生 dump/export 功能；输出必须先进入受控临时证据区并记录 `generator=dump-normalized`，随后规范化，不能直接成为候选文件。
- 只把 accept/revise 的 Zsh 建议转换为候选：先将旧配置按 `.zprofile` login 职责、`.zshrc` public/OMZ 骨架、company/local-only 的 profile/pre/rc 固定覆盖归类；public 生成 `zsh/.zprofile` 和 `zsh/.zshrc` 两个真实入口，company/local-only 每层只生成 `profile.zsh`、`pre.zsh`、`rc.zsh`。reject/defer 项不得静默复制原实现。
- 对 Brewfile、Homebrew 安装项、mise、uv、插件和其他设备配置逐项说明功能，评估最佳实践、替代方案与归属并标注三档修改级别，再转换为待预审批的分层 Brewfile、精确版本和 catalog/revision；不得直接提交原始 dump。
- 严格按第 5.5 节 `stage0-candidate/v8` 和 `destination-map.toml` 映射目标路径、文件格式、稳定排序、字段和固定表头；dump、Agent 推导和现有文件整理得到的相同项目必须归一为同一种候选格式。
- 对支持注释的候选 `.zsh`/Brewfile 等文件保留结构化同行注释；不支持注释的格式使用 sidecar。
- 对拟生成候选再次执行文件级最佳实践、目标格式语法/schema、敏感信息、内部信息和归属检查；验证失败的文件不得进入 0E。
- public/company 候选分别写入用户选择的 Git checkout+仓库内路径，local-only 候选固定写入 `~/.config/dotfiles/local/`，retire/unresolved 留在 run 报告中。不得自动写到当前仓库、其他 local-only root 或受控 staging。
- 每个 Zsh 候选项必须记录同一 `run_id` 和 `recommendation_id`。重新运行 0B、修改 0C 决策或改变设备证据后，旧导出标记为 stale，不得交给顶层阶段 1；无需逐项重新计算哈希。

产物：用户选定位置中的 public/company 整理后配置，以及固定 `~/.config/dotfiles/local/` 中的 local-only Zsh 固定覆盖、规范化分层 Brewfile、mise/uv 与插件候选文件；run 状态目录中的 `destination-map.toml`、retire/unresolved 清单、`export-report.md`、`export-best-practices.md`、候选语法/安全报告和 `files.tsv`。完成标志为 `device_config_export=ready_for_preapproval`。

#### 0E：第二次 Agent 预审批——候选文件与顶层阶段 1 准入

- Agent 读取每个候选文件的来源摘要、diff、同行注释/sidecar、最佳实践结论、推荐替代和建议归属，不显示或保存密钥值及未脱敏内容。
- Agent 对每个候选文件和每个 `review/unresolved` 项复核 `change_class` 并自动记录 accept/revise/reject/defer，不逐项询问用户。
- 任何缺少分类/预审批决策、仍含敏感/公司信息的 public 内容、或者候选文件最佳实践检查未完成的项，都会阻止顶层阶段 1 对应文件落库。
- 本次预审批不能反向替代 0C 的建议预审批；如果候选预审批要求改变 Zsh 修改方案，必须回到 0B/0C 更新建议，然后重新执行 0D 导出。
- 0E 全部决策和验证完成后，才按第 2.2/5.5.2 节为该 run 的最终产物生成一次 `stage0-summary.sha256`；此前各子阶段不生成哈希。
- 前置阶段 0 不执行 `git add/commit/push`；它的终态是“候选文件与 Agent 预审批结论已就绪”，不是“仓库已交付”。

前置阶段 0 产物：脱敏现状 inventory、独立 Zsh 修改建议、三档分类与第一次预审批决策、记录固定 local-only 与用户选择 public/company 目标的 `destination-map.toml`、源/目标文件映射、独立配置导出报告、用户选定位置中的 public/company 整理后配置文件、固定 `~/.config/dotfiles/local/` 中的 local-only 配置文件、仓库外的 retire/unresolved 报告、原文件+候选文件最佳实践报告、候选第二次预审批决策和追溯 manifest。其中只有来源建议与候选文件两次预审批均满足门禁，且候选获得 `accept/revise` 的 public/company 内容，才能成为顶层阶段 1 最终落库文件的输入。

### 顶层阶段 1：建设公开仓库与公司同步契约（当前主目标）

本阶段只建设可复用产品能力，不对开发者的真实 HOME 执行本地应用，也不卸载任何 Homebrew。

#### 1A：准备仓库与权限边界

前置条件：

- 用户已在阶段 0 的 `destination-map.toml` 中指定一个已存在的 public Git checkout 和仓库内根路径；如需新建远程仓库，由用户自行创建/授权后重新选择，安装器不得自动创建。
- Agent 根据 Git root、origin、目录结构、敏感信息扫描和工作区状态验证用户选择的 public/company 目标，不得改选其他仓库或路径。company 只在用户显式选择 `skip` 时跳过；不得因暂时不可访问而自动改为 `skip`。
- 固定两个 public 真实 Zsh 入口、OMZ 官方模板骨架、company/local 的 profile/pre/rc 固定 source 点与覆盖关系、工具所有权、manifest schema 和不可逆边界。
- 验证前置阶段 0 的同一 `run_id`、Zsh 建议/最佳实践报告、`recommendation-decisions.tsv`、已记录固定 local-only 根并由用户确认 public/company 目标的 `destination-map.toml`、独立 `export-report.md`/`export-best-practices.md`、`contract_version`、`files.tsv`、三档分类、候选预审批决策和唯一 `stage0-summary.sha256` 完整；拒绝两次预审批未分离、run-id/建议 ID 不一致、候选文件不在固定/已选目的地、整体摘要不匹配、目标路径/格式不符合第 5.5 节、验证失败或已过期的候选输入。
- 仓库建设只使用工作树、临时目录和隔离 HOME；不得把“建设仓库”理解为“获准改动当前机器”。

产物：仓库 origin/权限检查报告、公司层契约或 `skip` 状态、实施边界、获准候选输入清单。

#### 1B：实现公开仓库与公司文件集

- 建立本文定义的目录结构、完整中英 README、MIT License、`install.sh`、`bin/dotfiles`、两个真实 Zsh 入口、`scripts/migrate-intel-homebrew-to-arm.sh`、诊断、备份、manifest、rollback、插件目录与 CI；不创建通用 Zsh loader。
- 对前置阶段 0 的 `accept` 候选内容按原样落库；对 `revise` 内容先按 Agent 预审批结论改写并重新执行语法、最佳实践、归属与密钥检查；不落库 `reject/defer`。
- 实现前置阶段 0 列出的“无现有来源、仍需新建”文件，但不得越过已确认的产品契约。
- `install.sh` 与 `bin/dotfiles` 实现顶层阶段 2 的配置 plan/apply/verify/rollback 闭环；`scripts/migrate-intel-homebrew-to-arm.sh` 独立实现 Intel→ARM plan/apply/verify 和顶层阶段 3 retire preview/apply/status，两者不共享写入入口。
- 在用户选择的 public 仓库+路径中建立公司仓库 schema、脱敏 fixture 和同步说明；如用户已选择获批 company checkout+路径，在该目标生成第 7 节文件并验证，但不自动 push。
- 所有需要固定的工具、OMZ、插件和 Gitleaks 版本都写入仓库；禁止 `latest`。

产物：经 Agent 预审批结论更新的公开仓库文件、公司同步 schema/fixture/说明、如已授权则包含实际公司仓库文件集，以及 run-id、Zsh 建议/三档分类/第一次预审批→配置导出→第二次预审批→最终路径与 Git commit ID 的精简追溯表。

#### 1C：在隔离环境验证自闭环

- 使用 fixture 和临时 HOME 完成 syntax、plan、apply、再次 apply 幂等性、verify、rollback 和公司 `skip`/启用两种路径。
- 用 mock/fixture 验证退役预览、阻断条件和真实 TTY 确认防护；测试不得触碰真实 Homebrew。
- 执行 Gitleaks 全历史扫描、Agent 发布预审批和 CI；发布报告不得声称任何用户已完成本地迁移或退役。
- 用户单独确认后，手工把公开候选仓库改为公开；脚本不自动修改可见性。

顶层阶段 1 产物：用户选择的可审查 public 仓库+路径、用户选择的 company 同步契约与文件状态、隔离环境测试报告、CI/Gitleaks 报告和发布报告。这些产物是任何用户开始顶层阶段 2/3 的唯一代码基线。

### 顶层阶段 2：每个用户应用本地配置并单独完成 Intel→ARM 迁移

本阶段由每个用户在自己的机器上，从顶层阶段 1 交付的仓库启动。本阶段可以完成并长期停留；它不会自动进入 Intel Homebrew 退役。

#### 2A：配置来源与单机安全 preflight

- 用户先 clone 公开仓库，再运行无参数 `./install.sh`；Agent 自动验证并采用个人来源路径，公司来源在已有授权 checkout 时自动采用，否则标记 `skip`，不为路径逐项询问用户。
- 脱敏收集 `uname -m`、`arch`、Zsh source 链、PATH、`compinit`、插件、环境变量名称和命令/二进制架构；非 `arm64` 会话阻断 apply，不生成兼容配置。
- `install.sh` 只读检查 Homebrew 命令来源是否符合 `/opt/homebrew`，不盘点或迁移 Intel Homebrew；Intel/ARM formula、leaves、taps、casks、services、数据目录以及 NVM/npm、pyenv/Python、pipx/uv、Bun/pnpm、Go、mise 所有权改由独立迁移脚本盘点。
- 只记录 Keychain 外疑似密钥和 shell 历史命中的脱敏元数据，不记录值。
- 本子阶段只用于判断已落库文件能否安全应用到该机器，不得从用户的旧 `.zshrc` 反向生成、修改或提交顶层阶段 1 仓库内容；需要回馈仓库的改进必须重新走前置阶段 0 与顶层阶段 1。

产物：`inventory.md`、命令解析表、密钥轮换清单和本地配置 apply plan；不在本子阶段生成 Intel 退役账本。

#### 2B：备份、密钥边界与本地配置应用

- 把需保留密钥录入 Keychain，建立 wrapper。
- 密钥轮换和明文清除分别显式确认，不随 symlink apply 暗中执行。
- 为当前旧 Zsh 配置建立逐项迁移账本；未解释的有效配置不得进入切换。
- 先创建备份和 manifest，再建立 `~/.zprofile -> <public-root>/zsh/.zprofile` 与 `~/.zshrc -> <public-root>/zsh/.zshrc` 两个真实入口 symlink；company 启用时另幂等建立 `~/.config/dotfiles/company -> <selected-company-root>`，`skip` 时保证其不存在；最后验证 public/company/local 的固定 profile/pre/rc source 点。
- 安装原生 Git pre-commit hook 和固定版本 Gitleaks。
- 安装固定 revision 的 Oh My Zsh/插件。

产物：脱敏扫描报告、密钥处理状态、backup、配置 apply manifest 和固定 source 点加载报告。

#### 2C：Intel→ARM 独立迁移

- 先无参数运行 `./scripts/migrate-intel-homebrew-to-arm.sh`，盘点 Intel/ARM Homebrew、工具管理器所有权、formula/cask/service/data 并生成迁移计划；此步只读。
- 对服务启停和有状态数据迁移集中获取用户授权，然后显式运行 `--apply`。
- `--apply` 完善 ARM Brewfile 并安装缺失 ARM 工具；配置 mise 分层与固定版本，迁移 Bun/Node/pnpm/Go；配置 uv 并迁移 Python 版本、venv/tool 所有权；导入 autojump 数据到 zoxide 并验证替代。
- 迁移运行中服务及其数据，逐项接管 cask，标记 ARM/Universal/替代/淘汰，让 Intel 账本中所有条目离开 `unresolved`。
- 迁移脚本可以为盘点与移除目的读取 Intel 前缀，但不得写入任何 Zsh 配置或用户 PATH。

#### 2D：本地验证与退役准备

- 在干净 login shell 和 IDE 风格非-login 交互 shell 中验证 PATH 和工具。
- 运行 `./install.sh verify` 产生独立的本地配置验收结果；再运行 `./scripts/migrate-intel-homebrew-to-arm.sh --verify` 产生 ARM 命令矩阵和 retirement-readiness 状态。
- 未解决 Intel 项目只阻止顶层阶段 3，不否定已验证的本地 Zsh 应用；本阶段结束时必须停止。

顶层阶段 2 产物：本地 inventory、backup、apply manifest、ARM 命令矩阵、配置加载报告、服务/cask 分类、退役账本和 retirement-readiness 报告。它们全部留在当前机器。

### 顶层阶段 3：每台机器显式退役 Intel Homebrew

本阶段必须与顶层阶段 2 使用不同命令发起。用户可在顶层阶段 2 完成后决定何时进入；一旦明确进入且最终预览通过，本计划仍要求当天退役，不设观察期。

#### 3A：独立预览与阻断检查

- 用户或 Agent 只能先运行 `./scripts/migrate-intel-homebrew-to-arm.sh --retire`，重新验证当前机器标识、顶层阶段 2 迁移 manifest、ARM Homebrew 健康状态和账本时效性。
- 再次验证所有 ARM 替代命令的路径、架构和版本，以及服务、cask 和数据状态。
- 存在 `unresolved`、未知数据、运行中 Intel 服务、过期 manifest 或机器不匹配时阻止正式命令。

#### 3B：真实 TTY 确认与当天退役

- 用户运行 `./scripts/migrate-intel-homebrew-to-arm.sh --retire --apply`；这是唯一退役实现，`install.sh` 和 `bin/dotfiles` 不提供别名或包装入口。
- 用户查看最终清单、官方卸载将影响的路径和 Agent 预审批 manifest，并在真实 TTY 亲自输入精确短语。
- 使用已固定来源/revision/哈希且经 Agent 审查的 Homebrew 官方卸载机制；只处理 manifest 内项目，不递归删除 `/usr/local`。

#### 3C：最终验收与记录

- 运行全部本机验证。
- 验证所有受管 Zsh 文件从未含有 Intel 运行时兼容，活动 PATH 无 Intel Homebrew。
- 验证 `./scripts/migrate-intel-homebrew-to-arm.sh --status` 能查询旧路径/架构、替代路径/架构、处置状态和时间。
- 交付官方卸载记录、manifest、retired inventory 和残留 `/usr/local` 审计；不将这些本机产物提交回公开仓库。

阶段门禁是：前置阶段 0 没有先独立完成 Zsh 修改建议、三档分类和第一次 Agent 预审批时，不得执行当前设备配置导出；配置导出没有单独完成格式/安全验证和第二次 Agent 预审批时，顶层阶段 1 不得将对应配置 stage/commit；顶层阶段 1 的仓库能力未通过隔离测试时，不得用于顶层阶段 2；顶层阶段 2 未验证或退役账本存在阻断项时，不得进入顶层阶段 3。

## 19. 检查与验收矩阵

### 19.1 阻断检查

| 阶段 | 类别 | 必须验证 |
|---|---|---|
| 0 | 现状覆盖 | Zsh 启动文件/source 链、PATH/fpath、变量、alias/function/wrapper、补全/插件、Brewfile 与 Homebrew/mise/uv/语言工具所有权已脱敏盘点；顶层阶段 1 目标文件有源/无源状态已列出 |
| 0 | Zsh 建议独立性 | 先只生成逐项 Zsh 修改建议、run-id 和稳定建议 ID；该操作不计算中间哈希，没有生成/修改任何候选配置树，也没有改写真实 Zsh 文件 |
| 0 | 建议预审批门禁 | 每条 Zsh 建议有“一定要改 / 建议修改 / 可以不改”分类及独立 accept/revise/reject/defer，`recommendation-decisions.tsv` 与当前 run-id/建议 ID 完整对应；导出只消费 accept/revise |
| 0 | 配置导出独立性 | 导出由单独操作显式启动，不从建议流程自动继续；Zsh 候选能追溯到同一 run-id 和建议 ID，建议变化会令导出失效 |
| 0 | 最佳实践 | 当前源文件、Zsh 修改建议和拟生成候选文件均已按诊断指南完成语法、边界、幂等、架构、安全、所有权、可移植性和可公开性评估 |
| 0 | 候选格式与目的地 | dump/Agent/现有文件等证据均已归一为 `stage0-candidate/v8`；public Zsh 只有 `.zprofile/.zshrc` 两个真实入口，company/local-only 只使用每层三个固定 profile/pre/rc 文件；`.zshrc` 符合固定 OMZ revision 的官方模板骨架；`destination-map.toml` 已记录固定 local-only root `~/.config/dotfiles`/`local/` 和用户选择的 public/company 仓库+路径；候选路径镜像顶层阶段 1，文件通过对应语法/schema，追溯 TSV 使用精简表头且含 `run_id`/`change_class`；原始 dump 未冒充候选文件 |
| 0 | 注释与归属 | 每个可决策项都有功能、最佳实践结论、推荐/替代、public/company/local-only/retire/unresolved 归属和验证；支持注释的文件使用同行注释，其他格式使用 sidecar |
| 0 | 密钥与工作树 | public 候选不含公司/本地/密钥信息；原始敏感输出未保存；现有未提交工作未被覆盖；本阶段未执行 add/commit/push |
| 0 | 候选预审批准入 | 每个候选文件与 review/unresolved 项另有三档分类及 accept/revise/reject/defer 决策；候选预审批不能代替建议预审批；完整两段追溯链成立 |
| 1 | 仓库结构 | 公开目录、公司 schema/fixture、README、License、命令入口、测试与 CI 完整 |
| 1 | 候选落库 | 只消费前置阶段 0 的 accept/revise 内容；唯一阶段 0 整体摘要验证通过；revise 已重新验证；reject/defer 未落库；最终文件可追溯到 run-id、三档分类、Agent 预审批决策与 Git commit ID |
| 1 | 隔离自闭环 | 临时 HOME 中两个真实入口的 symlink plan/apply/幂等/verify/rollback 通过；迁移脚本的 plan/apply/verify/retire 只使用 mock/fixture，不触碰真实 HOME/Homebrew |
| 1 | 公司契约 | company 启用与 `skip` 均通过；公司层不能覆盖保留安全接口；实际同步状态未被夸大 |
| 1 | 仓库密钥 | tracked/untracked/ignored、暂存区、当前提交和完整历史通过固定版本 Gitleaks |
| 2 | Zsh 语法与启动 | 所有启用 `.zsh` 文件通过 `zsh -n`；真实 HOME 的 login/interactive/non-login interactive 场景正常 |
| 2 | 分层与补全 | `.zprofile/.zshrc` 为直接 symlink 目标；public < company < local 在 profile/pre/rc 固定 source 点按预期覆盖；`.zshrc` 保持 OMZ 模板骨架；Oh My Zsh/`compinit` 只初始化一次 |
| 2 | 应用与回滚边界 | symlink 目标正确；manifest、备份目标与配置回滚动作完整；可逆 apply 不要求逐文件哈希；`./install.sh apply` 未调用迁移脚本或任何 Homebrew 写操作 |
| 2 | ARM 替代项 | 迁移脚本 `--apply` 会话为 arm64；ARM Homebrew 和替代二进制架构正确；新增软件的 cleanup 只预览；退役账本与 readiness 状态已生成 |
| 2 | 本地密钥 | 诊断/报告无密钥值；本地例外文件与父目录权限正确；不可逆密钥操作有独立确认 |
| 3 | 阶段门禁 | 只接受本机已验证的顶层阶段 2 manifest；机器 ID、账本和计划未过期 |
| 3 | Intel 归类 | 每项已归类；服务、cask、数据已确认；替代命令架构验证通过；无 `unresolved` |
| 3 | 不可逆退役 | retire 会话为 arm64；真实 TTY 精确确认；仅执行 Agent 预审批 manifest；不递归删除 `/usr/local` |
| 3 | 最终 PATH 与记录 | PATH 去重、优先级正确、无活动 Intel Homebrew 路径；retired record 可查询 |

### 19.2 性能诊断（仅建议）

- 多次测量 `zsh -i -c exit` 和 login shell 启动时间，报告中位数与波动。
- 可选 `zprof` 模块耗时。
- 插件数量、每个加载阶段耗时、PATH 长度与重复项。
- compinit 缓存状态与重建原因。
- 诊断输出“数据 + 建议”，不得因固定毫秒门槛阻止安装、验收或退役。

### 19.3 CI

- 验证逻辑必须能由本地命令调用，与 CI 平台解耦。
- 个人仓库使用明确版本的 GitHub 托管 ARM macOS runner（例如 `macos-26`，实施时再次核对可用标签），不使用个人 self-hosted runner。
- 公司仓库由公司获批 CI 调用同一验证命令；暂未配置时在发布报告标记缺失，但本地验证仍执行。
- CI 覆盖 Zsh 语法、`.zprofile/.zshrc` 两个真实入口的 symlink 启动、OMZ 官方模板骨架对照、受管区块边界、company/local-only 固定 profile/pre/rc source 点、无 Intel 运行时路径、插件 revision、Brewfile 语法/重复项、隔离 HOME、配置 plan/apply/幂等/rollback、迁移脚本 fixture、manifest、README 双语结构和 Gitleaks。
- CI 检查 `stage0-candidate/v8` 目标路径/格式、`destination-map.toml` 的 schema/run-id、local-only 固定根、public/company 用户选择状态、候选文件是否落在正确根路径、`change_class` 三档枚举、Zsh 建议与两次 Agent 预审批追溯、受管 `.zsh`/Brewfile 的结构化同行注释字段、不支持注释文件的 sidecar 覆盖、精简 TSV 表头和已落库路径中不存在 `defer/unresolved`；CI 不要求逐条或逐文件 SHA-256。
- CI 不安装全部 cask、不改真实系统偏好、不访问真实公司服务、不读取真实 Keychain、不执行真实 Intel 卸载。
- ShellCheck 只检查真正使用 `sh/bash/dash/ksh` 的脚本；不得用 Bash 方言误检 Zsh。若仓库全为 Zsh，则不运行 ShellCheck。

## 20. 密钥扫描与 Git 防护

- 使用固定版本 Gitleaks，而不是只依赖 GitHub。
- `.githooks/pre-commit` 跟踪在用户选择的 public 仓库中；将该 checkout 的本地 `core.hooksPath=.githooks` 归为“建议修改”并预审批启用，记录原值且可回滚，不再二次询问用户。
- Gitleaks 缺失或扫描错误时 pre-commit fail closed，并给出安装提示。
- CI 扫描提交范围和完整历史；公开前再次执行全历史扫描。
- GitHub 可用时同时启用 secret scanning/push protection；公司平台使用等价原生能力，但它们只是第二层防护。
- allowlist 必须窄到具体规则/路径/指纹，写明误报原因和复核日期；禁止全局跳过常见 token 模式。
- 如果历史曾提交真实密钥或公司内容：先轮换，再重写历史或新建干净公开仓库，然后从头扫描；不得仅删除当前文件后直接公开。

## 21. 公开发布关卡

发布报告必须回答：

1. 当前 tracked/untracked/ignored 文件是否符合 allowlist。
2. 所有 symlink 是否指向仓库允许范围，是否可能暴露本地/公司文件。
3. 当前工作区、暂存区、所有 branch/tag 和完整历史是否通过 Gitleaks。
4. 是否存在公司名、域名、内部路径、账号、私有仓库 URL、设备标识或注释泄露。
5. README 中英两版的命令与安全警告是否同步。
6. License 是否只覆盖公开仓库内容。
7. Git remote、Actions、issue/PR 模板、artifact 是否不含私有信息。
8. 顶层阶段 1 的所有 CI、隔离 HOME 和退役 fixture 是否通过；如有参考机器的端到端结果，是否明确标注为单机证据而不是其他用户的完成条件。
9. 前置阶段 0 是否先独立完成 Zsh 建议、三档分类及第一次 Agent 预审批，再单独导出配置并完成第二次 Agent 预审批；最终产物是否只有一份整体摘要，落库文件是否可追溯到 run-id、建议 ID、分类、两次决策和 Git commit ID，以及 public 同行注释/sidecar 本身是否不泄露公司或本机信息。

顶层阶段 1 的公开发布不以任何用户完成顶层阶段 2/3 为前置；否则新用户将无法先获取仓库再执行本地流程。通过发布关卡后也只能建议发布；仓库可见性必须由用户手工修改。

## 22. 实施时待填数据（不是设计分歧）

以下信息必须按顶层阶段区分，不允许为了提前宣称某个阶段完成而硬编码假设。

前置阶段 0 由仓库维护者当前机器的只读盘点提供：

- 实际 Zsh 启动文件与 source 链、现有 Brewfile/Homebrew 项目、插件、补全、函数、工具管理器和命令解析状态。
- 独立 Zsh 修改建议、run-id、稳定建议 ID，以及每条建议的三档分类与第一次 Agent 预审批决策。
- 配置导出阶段中每个非 Zsh 项目的功能、最佳实践结论、建议/替代方案、建议归属和验证方式。
- 顶层阶段 1 目标文件的“可由现状生成候选”或“需要新建”状态。
- 记录固定 local-only 根与用户选择 public/company 目标的阶段 0 目的地映射，独立配置导出报告，用户所选仓库中的 public/company 候选文件，`~/.config/dotfiles/local/` 中的 local-only 候选文件，仓库外的 retire/unresolved 报告，以及候选文件的三档分类与第二次 Agent 预审批决策。

上述信息中的本机结果只用于生产和 Agent 预审批仓库候选文件，不能被当作其他用户的默认环境或阶段 2/3 完成证据。

顶层阶段 1 完成前必须固定：

- 公开默认的 mise、uv、Bun、Node、pnpm、Go 精确版本或明确的无默认策略。
- 最终插件/Oh My Zsh revision、Gitleaks 固定版本和 GitHub/CI 的实际 runner 标签与权限。
- 公司仓库 schema、需同步文件集、兼容契约，以及实际公司 checkout 的“已同步”或“待同步”状态。

顶层阶段 2 由每台机器的用户或只读盘点提供：

- 个人仓库 URL/本地路径。
- 公司仓库 URL/本地路径或 `skip`。
- 实际 Brew formula/cask/service 清单。
- 每个 API key 的变量名、消费命令和是否支持单命令 wrapper；不记录值。
- 服务数据迁移步骤和验证命令。
- 旧 `.zshrc` 每条有效配置的迁移归类。

顶层阶段 2 的单机数据缺失不影响顶层阶段 1 的通用仓库交付；但它们缺失时只能生成受限的只读 plan，不得假装完成本地应用或 Intel 退役。

## 23. 主要风险与缓解

| 风险 | 缓解 |
|---|---|
| Agent 在给出 Zsh 建议时顺带导出或改写配置 | 建议与导出使用独立操作、产物和完成标志；建议阶段禁止候选树，导出必须验证同一 run-id、建议 ID 覆盖和第一次 Agent 预审批 |
| Zsh 建议更新后仍沿用旧导出 | 候选记录 run-id/建议 ID；建议或决策变化立即把导出标记为 stale，并强制重新导出；0E 最后才生成一次整体摘要 |
| 把工具 dump 或 Agent 推导结果直接当成阶段 1 文件 | dump/推导只作证据；统一转换为版本化候选契约，按目标路径和语法验证、三档分类并完成 Agent 预审批后才能落库 |
| 前置阶段 0 写错仓库/目录或覆盖现有工作 | 导出前由用户集中确认 `destination-map.toml`；校验 Git root/origin、相对路径、Git/云同步边界和现有内容；任何冲突都停止并生成报告，不自动换到 staging/默认目录 |
| 当前机器现状被误当成所有用户的默认配置 | 当前机器只提供候选证据；顶层阶段 1 用可移植默认、schema、fixture 和隔离 HOME 验证后才落库 |
| 同行注释、sidecar、三档分类/预审批结论与最终文件漂移 | 使用 run-id、稳定 ID、精简追溯表、唯一阶段 0 整体摘要和最终 Git commit ID；CI 阻止缺分类、缺决策及 `defer/unresolved` 内容落库 |
| 本机、密钥或公司信息经候选文件/注释泄露到公开仓库 | 写入 public 前先脱敏和归属分类；敏感原始输出不落盘；候选与注释同时经过 Agent 预审批和 Gitleaks |
| 删除 Intel Homebrew 后遗漏命令 | 每项强制归类；替代路径和架构实际执行验证 |
| `/usr/local` 中混有非 Homebrew 数据 | 官方卸载 + Agent 预审批 manifest；未知目录保留并报告 |
| 数据库/服务中断 | 服务与数据使用单独 runbook；Agent 先分类，用户仅对有状态服务启停集中授权一次 |
| 旧明文密钥进入备份或日志 | 先脱敏/轮换；普通备份禁存值；历史仅短期隔离 |
| 公司层故障导致 shell 不可用 | 安装严格、日常降级；公开层独立可用 |
| 双语 README 漂移 | 相同章节编号/命令块；CI 做结构检查，发布清单做语义复核 |
| 插件上游变化或供应链风险 | 固定 revision、关闭自动更新、由 Agent 执行显式差异审查和三档预审批 |
| Agent 误执行不可逆步骤 | README 唯一协议；真实 TTY 精确确认不可代理 |
| Git 更新覆盖本地工作 | 默认 fetch/report；只允许显式 `pull --ff-only` |
| 回滚承诺过度 | 明确密钥清除和 Intel 卸载不可逆，新增包只给 cleanup 预览 |

## 24. 与 `yujiachen-y/dotfiles` 参考方案的关系

本项目借鉴 [yujiachen-y/dotfiles](https://github.com/yujiachen-y/dotfiles) 的仓库化管理思路，但不 fork、不直接运行其安装脚本，也不把它作为运行时依赖。对照基线是访谈前审查的该仓库 `main` 快照；实施时若再次比较，必须记录新的 commit。

### 24.1 继续采用的思想

- 用 Git 仓库维护可复用 dotfiles，并通过安装入口部署。
- 使用 Brewfile 表达常用软件的期望集合。
- 保留 Oh My Zsh、轻量主题和按需插件。
- 使用 symlink 避免在 `$HOME` 复制多份配置。
- 为用户提供可读的安装说明，而不是要求记忆所有手工步骤。

### 24.2 有意改造的部分

| 参考做法或风险 | 本计划的处理 |
|---|---|
| 配置中出现 `/usr/local` Homebrew 路径 | Apple Silicon 公共运行时只使用 `/opt/homebrew`；不创建 Intel 兼容文件或 PATH fallback；只有独立迁移脚本可为识别、迁移和移除目的读取 Intel 前缀 |
| 主要逻辑集中在单个 `.zshrc` | 保留“真实入口可直接链接且打开即可理解”的结构；增加真实 `.zprofile` 分担 login 职责，`.zshrc` 则保留 OMZ 官方模板骨架，不再拆出 public loader/阶段文件；不管理 `.zshenv` |
| 用被忽略的单个私有命令文件承载非公开内容 | 保留 public/company/local 三层及 profile/pre/rc 三个加载阶段，但每层每阶段只允许一个固定文件，由两个真实入口显式 source，不创建通用 loader |
| 安装流程可能直接删除或替换已有文件 | 默认 plan、显式 apply、备份、manifest、幂等和 rollback；可逆配置不维护逐文件哈希，禁止无清单删除 |
| Brewfile dump 容易变成未经预审批的机器快照 | dump 只作审计输入；正式 Brewfile 分层并由 Agent 三档分类、预审批维护，cleanup 默认只预览 |
| pyenv、NVM、mise 等职责可能重叠 | mise 独占 Bun/Node/pnpm/Go/固定版本跨项目 CLI，uv 独占 Python，移除 NVM/pyenv |
| 插件只有名称或 clone 行为 | 独立 catalog 记录痛点、理由、依赖、风险、加载阶段和固定 revision；Agent 按三档分类自动采用/跳过，不在安装时逐项询问 |
| 私有环境变量可能通过 shell 文件全局 export | 默认 Keychain + 单命令 wrapper；公司仓库无密钥，本地明文仅为权限受控例外 |
| 仓库更新和插件更新跟随上游当前状态 | Git 只允许显式 fast-forward；OMZ/插件/Gitleaks 固定 revision/version 并经测试升级 |
| 未覆盖 Intel Homebrew 完整迁移与退役 | 以独立 `scripts/migrate-intel-homebrew-to-arm.sh` 统一建立 formula/cask/service/data 账本、ARM 替代安装与验证、服务/数据迁移、受保护退役及可查询记录 |

因此，本计划明确采用参考仓库“一个 shell 启动职责对应一个可直接链接的真实配置文件”风格，并保留 Brewfile、OMZ 原生模板骨架与 symlink 优点；安全、分层私密性、供应链固定、可回滚安装和 Intel→ARM 退役控制不得迫使 Zsh 运行时重新演变成通用 loader 框架。

## 25. 参考依据

- [Zsh 启动文件](https://zsh.sourceforge.io/Doc/Release/Files.html)
- [Zsh 历史选项](https://zsh.sourceforge.io/Doc/Release/Options.html)
- [Homebrew FAQ：Apple Silicon 前缀与卸载](https://docs.brew.sh/FAQ)
- [Homebrew Brewfile 与 Brew Bundle](https://github.com/Homebrew/brew/blob/main/docs/Brew-Bundle-and-Brewfile.md)
- [mise 配置层级与 `conf.d`](https://mise.jdx.dev/configuration.html)
- [mise 交互 shell 激活](https://mise.jdx.dev/getting-started)
- [uv Python 版本管理](https://docs.astral.sh/uv/concepts/python-versions/)
- [uv 工具管理](https://docs.astral.sh/uv/concepts/tools/)
- [zoxide 安装与 autojump 导入](https://github.com/ajeetdsouza/zoxide/blob/main/README.md)
- [Oh My Zsh 插件目录](https://github.com/ohmyzsh/ohmyzsh/wiki/plugins)
- [Oh My Zsh 官方 `.zshrc` 模板](https://github.com/ohmyzsh/ohmyzsh/blob/master/templates/zshrc.zsh-template)
- [zsh-syntax-highlighting 加载要求](https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/INSTALL.md)
- [ShellCheck 不支持 Zsh](https://www.shellcheck.net/wiki/SC1103)
- [GitHub 托管 runner](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
- [GitHub secret scanning 范围](https://docs.github.com/en/code-security/reference/secret-security/secret-scanning-scope)
- [Gitleaks](https://github.com/gitleaks/gitleaks)

## 26. 最终验收清单

### 前置阶段 0：Zsh 修改建议与独立配置导出

- [ ] 已完整阅读诊断指南，并脱敏覆盖当前 Zsh 启动文件及 source 链、Brewfile/Homebrew、插件、补全、函数、工具管理器和顶层阶段 1 目标文件来源。
- [ ] 已先单独生成 `zsh-recommendations.md`：每条建议有稳定 ID、当前功能、问题证据、建议改法、归属和验证；此时没有生成候选配置树，也没有修改真实 Zsh 文件。
- [ ] 每条 Zsh 建议已标注“一定要改 / 建议修改 / 可以不改”并完成第一次 Agent 预审批，自动映射的 accept/revise/reject/defer 与同一 run-id 下的 `recommendation-decisions.tsv`、稳定建议 ID 一致；没有生成建议报告哈希。
- [ ] 导出前已在 `destination-map.toml` 中记录 local-only 固定 root `~/.config/dotfiles` 与 `local/` 相对根，并由用户在一次集中选择中确认 public Git checkout+仓库内根路径、company Git checkout+仓库内根路径/`skip`；映射与 run-id 一致。
- [ ] 当前设备配置导出是后续单独启动的操作；它没有从建议流程自动继续，只消费 accept/revise 建议，reject/defer 项未被静默复制。
- [ ] 当前源文件、Zsh 修改建议和拟生成候选文件均完成文件级最佳实践检查；不能因为当前可运行而直接判定适合落库。
- [ ] 工具 dump、只读命令、Agent 推导和现有文件整理都只作为证据；最终候选已转换为第 5.5 节 `stage0-candidate/v8` 的目标路径、格式、排序和精简字段，没有用原始 dump 替代配置文件。
- [ ] public Zsh 候选只使用 `zsh/.zprofile` 和 `zsh/.zshrc` 两个真实入口；`.zshrc` 已记录固定 OMZ revision，保留官方模板注释、段落顺序与原生 source 行，只有经预审批的值变更、Intel 路径示例删除和带固定标记的受管区块。
- [ ] public 候选不存在 `entrypoints/`、`lib.zsh`、`zsh/lib/`、`profile.d*`、`pre.d*`、`rc.d*` 或通用 loader；company/local-only 每层只允许 `profile.zsh`、`pre.zsh`、`rc.zsh` 三个固定文件。
- [ ] 每个 Zsh、Brewfile、mise、uv、插件和公司候选文件都通过对应语法/schema 验证；`files.tsv` 与 `file-decisions.tsv` 使用固定表头且能覆盖所有候选项。
- [ ] 每个 Zsh 候选项都能追溯到同一 run-id、建议 ID 和三档分类；建议、第一次预审批或设备证据变化后旧导出已标记失效并重新生成。
- [ ] 每个可独立决策项都有功能、最佳实践结论、推荐/替代、归属和验证方式；支持注释的格式使用结构化同行注释，其他格式有完整 sidecar。
- [ ] 整理后的 Zsh 真实入口/固定私有覆盖、规范化分层 Brewfile、mise/uv 和插件候选文件已直接出现在固定 `~/.config/dotfiles/local/` 或用户选择的 public/company 仓库+路径；retire/unresolved 只在仓库外报告中。
- [ ] 所有配置候选的最终绝对路径已展示并验证；没有写入未经用户选择的当前仓库、计划之外的 local-only root 或 staging 目录，冲突没有被静默覆盖或改道。
- [ ] public 候选文件及其注释不含密钥、公司或机器专属信息；原始敏感诊断输出没有保存。
- [ ] 除写入计划固定的 `~/.config/dotfiles/local/` 候选文件外，未修改真实 HOME 的 shell 入口、symlink 或已安装软件，未覆盖现有内容/未提交工作，也未执行 `git add`、`git commit`、`git push`。
- [ ] 每个候选文件和 `review/unresolved` 项都完成了独立于建议预审批的三档复核与第二次 accept/revise/reject/defer Agent 预审批；run-id、建议 ID、分类、两次预审批和目标路径可追溯。
- [ ] 0E 结束时仅生成一份 `stage0-summary.sha256`；未保存原始证据、逐条建议或单个候选文件的 SHA-256 清单。

### 顶层阶段 1：仓库能力（当前交付门）

- [ ] 只消费前置阶段 0 的 `accept/revise` 内容；`revise` 已按 Agent 预审批意见修改并重新验证，`reject/defer` 没有落库。
- [ ] 已校验阶段 0 候选的 `contract_version`、目标相对路径和格式；契约不兼容时先版本化并按 `revise` 重新生成，没有静默转换。
- [ ] 每个由前置阶段 0 产生的最终文件都能追溯到 run-id、Zsh 建议 ID、三档分类、两次 Agent 预审批、独立配置导出、顶层阶段 1 的修改/验证结果和最终 Git commit ID。
- [ ] 用户选择的 public 仓库+仓库内根路径包含第 6 节全部公开文件；不存在 `bootstrap.sh` 或 `AGENTS.md`。
- [ ] public Zsh 结构为 `zsh/.zprofile` + `zsh/.zshrc` + `zsh/plugins/`；前两者是完整真实入口，已通过直接 symlink 的 login/interactive/non-login interactive 测试。
- [ ] `.zprofile` 显式 source company/local `profile.zsh`；`.zshrc` 在 OMZ 原生 source 行前显式 source company/local `pre.zsh`，在 OMZ 后显式 source company/local `rc.zsh`；无 glob、目录遍历、fallback 或通用 loader。
- [ ] README 为完整中英双语且是用户与 Agent 的唯一入口，清楚区分独立前置阶段 0 与三个顶层阶段。
- [ ] `install.sh` 与 `bin/dotfiles` 在仓库内形成顶层阶段 2 的配置 plan/apply/verify/rollback 闭环；`scripts/migrate-intel-homebrew-to-arm.sh` 独立形成 Intel→ARM plan/apply/verify 和顶层阶段 3 retire/status 闭环。
- [ ] `scripts/migrate-intel-homebrew-to-arm.sh` 以 `0755` 纳入仓库，从自身位置推导仓库根；配置 run-id 与迁移 run-id/状态目录完全分离，非 `arm64` 写模式已用 fixture 验证为无变更退出。
- [ ] `./install.sh apply` 不调用迁移脚本或任何 Homebrew 写操作；退役只能由 `./scripts/migrate-intel-homebrew-to-arm.sh --retire --apply` 显式发起。
- [ ] 公司仓库 schema、需同步文件契约和脱敏 fixture 已完成；实际公司 checkout 的“已同步/待同步/skip”状态如实记录。
- [ ] `.zshenv` 未被接管；`.zprofile/.zshrc` 真实入口、OMZ 模板骨架、public < company < local 固定 source 点、补全所有权和工具所有权已用 fixture 验证。
- [ ] Oh My Zsh、插件、Gitleaks 和需固定的工具都有明确版本/revision，不使用 `latest`。
- [ ] 隔离 HOME 的 syntax/plan/apply/幂等/verify/rollback、公司启用/`skip` 和退役 fixture 全部通过，且没有修改真实 HOME/Homebrew。
- [ ] CI、Gitleaks 全历史扫描和公开发布报告通过；仓库可见性只由用户手工修改。

### 顶层阶段 2：单机本地应用

- [ ] 用户从顶层阶段 1 的仓库运行 `./install.sh`，完成个人/公司来源配置和只读盘点。
- [ ] 现有配置已备份，`~/.zprofile -> <public-root>/zsh/.zprofile` 与 `~/.zshrc -> <public-root>/zsh/.zshrc` symlink 目标正确；company 启用时 `~/.config/dotfiles/company -> <selected-company-root>` 正确且可重复 apply，company=`skip` 时该链接不存在；company/local 的固定 profile/pre/rc 覆盖结果可诊断。
- [ ] ARM Homebrew、mise、uv、Bun、Node、pnpm、Go 所有权无重叠；Oh My Zsh/`compinit`/插件加载正确。
- [ ] API key 已进入 Keychain wrapper 或获批本地例外；不可逆密钥操作经过独立确认。
- [ ] 三层 Brewfile 已由 Agent 完成三档分类与预审批；独立迁移脚本的无参数 plan、`--apply` 和 `--verify` 已生成 Intel formula/cask/service/data 账本和 retirement-readiness 报告；没有为内容项逐条询问用户。
- [ ] `./install.sh verify` 通过本地配置检查，迁移脚本 `--verify` 通过 ARM 替代检查；manifest 明确标记“本地配置与 ARM 迁移完成、Intel Homebrew 未退役”。

### 顶层阶段 3：单机 Intel Homebrew 退役

- [ ] 用户先单独运行 `./scripts/migrate-intel-homebrew-to-arm.sh --retire`，且它只消费本机同一脚本 `--apply/--verify` 产生的已验证 manifest/账本。
- [ ] 所有 Intel formula/cask/service/data 已归类，无 `unresolved`，ARM 替代项经实际路径/架构/版本验证。
- [ ] `./scripts/migrate-intel-homebrew-to-arm.sh --retire --apply` 由用户在真实 TTY 亲自输入精确确认短语，执行过程不递归删除 `/usr/local`。
- [ ] 所有 public/company/local-only Zsh 文件从未包含 Intel 运行时兼容，最终活动 PATH 无 Intel Homebrew。
- [ ] `./scripts/migrate-intel-homebrew-to-arm.sh --status` 可查询退役记录，官方卸载记录、manifest、retired inventory 和残留审计留在本地。
