---
name: analyze-zsh-configuration
description: 只读采集并分析用户显式选择的 macOS Zsh 启动文件来源（当前 live HOME 或当前仓库目录及文件子集）的脱敏结构与运行时事实，依据 Skill 内置的 Zsh 最佳实践手册生成含证据来源、顶部结论、一览表和逐项建议的 zsh-repair-plan.md 候选。用于用户要求诊断或优化 .zshenv、.zprofile、.zshrc、.zlogin，排查 Intel/ARM 与 Homebrew 前缀、重复 compinit/source、PATH/fpath、*_HOME 功能错误、初始化顺序、变量作用域、疑似敏感项或启动性能时；不用于导出软件配置、审阅 Brewfile/tooling、生成最终 Zsh 文件或修改真实 HOME。
---

# Zsh 配置分析与修改建议

把用户选定的 Zsh 启动文件的脱敏结构与只读运行时证据转换为可执行、可验证的修改建议。只生成修复计划候选，不修改真实文件，不生成最终 `.zprofile`、`.zshrc` 或 `shared.zsh`。

## 执行前计划门

先确定输入来源，不得用计划输出路径反推采集输入：

1. 若用户已明确指定文件或仓库目录，把该范围视为已选择的 `repository` 来源；仅选择用户点名的 `zshenv,zprofile,zshrc,zlogin` 子集。文件不在同一目录、同一逻辑文件的点文件与非点文件同时存在，或选定路径不在当前仓库时，立即停止并说明能力与请求范围不匹配。
2. 若用户未指定来源，以编号选项询问并等待回复：`1. live-home`（当前 `$HOME/.zshenv` 等）；`2. repository`（用户提供当前仓库内目录和文件子集）。不默认为 `live-home`。
3. 对已选来源运行不落盘的 `--preflight`，验证 `source-origin`、`selected-files` 和每个 `input-map` 确实对应用户选择。任一映射不一致时停止；不得换回 `$HOME` 或扩大文件集。

然后只读检查仓库根、工作树、受管 `tmp/` 路径、采集器与所需手册章节的存在性，不运行会生成 `tmp/zsh-evidence.md` 的完整采集，也不直接读取所选 Zsh 内容。向用户展示计划：已选 `source-origin`、文件映射与预检结果、将运行的脱敏采集器、将读取的证据和手册章节、可能创建或覆盖的受管 `tmp/` 文件、输出归属、敏感信息边界、验证与清理方式，以及明确不会修改真实 HOME、软件或服务。展示后停止并等待用户明确确认，再进入执行流程。

若由 Stage 0 编排且其已获确认的初始计划逐项覆盖上述范围，可以继承该确认而不重复询问。确认后执行前重新检查工作树；输入、输出范围或风险发生实质变化时，先更新计划并再次等待确认。初始计划确认不授权正式目录写入、commit、push、安装或退役。

## 使用内置资源

- 使用 [`scripts/collect-zsh-evidence.zsh`](scripts/collect-zsh-evidence.zsh) 采集证据。始终从当前公开 Git 仓库根目录执行，必须显式传入 `--source live-home|repository`；`repository` 还必须传入 `--source-dir`，用 `--files` 限定文件子集。`--preflight` 只验证映射且不生成报告。不要用 `dump.sh` 采集 Zsh。脚本可以执行内置白名单中的只读事实检查，但不得 source 启动文件。
- 修改采集器后运行 [`scripts/test-collect-zsh-evidence.zsh`](scripts/test-collect-zsh-evidence.zsh)；测试必须使用 `/private/tmp/` fixture，验证信号覆盖和敏感值不进入报告。
- 使用 [`references/zshrc-diagnostics-guide.md`](references/zshrc-diagnostics-guide.md) 作为修改建议的权威手册。先查看目录，再只读取与当前证据相关的章节；涉及多个类别时可读取多个章节。

## 遵守边界

- AI 分析层不直接读取、输出或 source 用户选定的 Zsh 文件；只有内置确定性脚本可以扫描结构，并采集架构、Rosetta、Homebrew 前缀、命令来源类别和二进制架构等只读事实。AI 只读取脚本生成的 `tmp/zsh-evidence.md`。
- 采集脚本不得启动会加载真实配置的交互/登录 shell，不得执行 `brew doctor`、包清单导出、工具健康检查、网络请求或性能 profiling；未测量的运行时效果必须保留为证据缺口。
- 不读取 Keychain、shell 历史、完整环境或 `~/.config/dotfiles/local/parameters.zsh` 内容。
- 不修改真实 Zsh、symlink、软件或服务，不调用 `install.sh`，不安装或退役项目。
- 不把本机绝对路径、shared 仓库专属信息、账号、远程地址或敏感值写入 public 修复计划。
- 不把推断当作证据。未知 source 表达式、被脱敏路径和无法确认的工具所有权统一标记 `manual`。
- 不负责审阅 `dump.sh` 导出的 Brewfile、tooling 或 `plugins.toml`；该职责属于 `$review-exported-dotfiles`。

## 执行流程

### 1. 预检

1. 定位当前公开 Git 仓库根目录，确认 `tmp/` 被 Git 忽略且不是 symlink。
2. 按执行前计划门确定 `source-origin`、来源目录和文件子集。运行与选择完全一致的 `--preflight`；确认 `report-written: no`，并把每个 `input-map` 与用户点名文件逐项对齐。
3. 检查 `git status --short`，保护用户已有变更；本 Skill 只管理 `tmp/zsh-evidence.md` 和自己生成的 `tmp/**/zsh/zsh-repair-plan.md`。
4. 将证据来源与输出归属分开确认。`tmp/my_setup/zsh/zsh-repair-plan.md` 只表示 personal 计划归属，不证明证据来自 `my_setup/zsh/`；`tmp/shared/...` 同理。
5. 若 shared 修复计划确有必要但 shared 归属或目标仓库不明确，把歧义交回 Stage 0 编排 Skill；不要自行猜测。
6. 如已有同路径候选计划，只覆盖本 Skill 明确生成的文件；不读取或改动其他 `tmp/` 内容。

### 2. 采集脱敏证据

从仓库根运行与已确认选择对应的一条命令：

```zsh
# 选项 1：当前 HOME；--files 必须与用户选定子集一致
.agents/skills/analyze-zsh-configuration/scripts/collect-zsh-evidence.zsh \
  --source live-home --files zshenv,zprofile,zshrc,zlogin

# 选项 2：当前仓库内目录；示例只采集用户点名的两个文件
.agents/skills/analyze-zsh-configuration/scripts/collect-zsh-evidence.zsh \
  --source repository --source-dir my_setup/zsh --files zprofile,zshrc
```

要求：

- 完整采集必须复用预检时的 `--source`、`--source-dir` 和 `--files`，只去掉 `--preflight`；不修改 HOME 或使用测试环境变量帮助生产采集。
- 采集失败时停止，不绕过脚本安全检查，不回读真实 Zsh 文件补证据。
- 确认唯一证据文件为 `tmp/zsh-evidence.md`，且 Git 未跟踪它。
- 确认报告顶部的 `source-origin`、`source-root-category`、`selected-files` 与预检及用户选择一致，且每个启动文件章节的 `source-input-name` 与 `input-map` 一致。不一致时删除本次证据并停止，不生成修复计划。
- 确认报告只包含以下白名单证据：文件类型/权限/symlink 类别、语法结果、活动与注释标记计数、变量名与导出作用域、source 类别、`*_HOME` 目标类别与文件类型、脱敏 PATH/fpath 及其精确重复计数、硬件 ARM 能力、采集进程架构、Rosetta、Homebrew 前缀、白名单命令的来源类别与二进制架构。
- 确认报告不包含变量值、alias/function body、原始 source 路径、完整命令输出、账号或本机绝对路径。活动行只表示“非注释结构信号”，不自动证明该分支在启动时执行。
- 继承 PATH/fpath 和命令来源只代表采集进程环境，不代表新登录 shell 的完整启动结果；不得把它们自动归因于 `.zshrc`。

### 3. 选择手册章节

根据证据信号读取手册：

| 证据信号 | 至少读取的章节 |
|---|---|
| 启动文件职责、语法、source 顺序 | 2、3、6、14 |
| `/usr/local`、x86_64、Rosetta | 2、4、5 |
| 硬件 ARM 能力、采集进程架构、Homebrew 前缀、命令架构 | 4、11、14 |
| PATH/fpath 重复或硬编码 | 5、12 |
| compinit、补全、插件重复 | 7、8 |
| `*_HOME` 指向文件、缺失目录或动态表达式 | 6、11 |
| 活动/注释变量、导出作用域或疑似敏感项 | 9、10、12 |
| NVM、pyenv、mise 等职责冲突 | 8、11 |
| 需要统一输出格式或验收 | 15、16 |

证据不足时只读取基础分类、报告格式和验收章节，不扩大采集范围。

### 4. 生成修改建议

按实际内容生成：

```text
tmp/my_setup/zsh/zsh-repair-plan.md
tmp/shared/zsh/zsh-repair-plan.md    # 仅存在明确共享增量时
```

计划必须按以下顺序输出；即使详细发现较多，也先让读者在顶部看懂结论：

```markdown
# Zsh 修复计划候选（Stage 0）

## 结论
- 3–6 条：先写已确认的正常状态，再写最重要的 P0/P1 结论和关键证据缺口。

## 证据来源
- source-origin: live-home/repository
- selected-files: 用户选定的逻辑文件子集
- input-map-check: pass
- output-ownership: personal/shared（与证据来源独立）

## 问题一览
| 优先级 | 证据等级 | 类别/位置 | 结论与影响 | 归属 | 下一步 |
|---|---|---|---|---|---|
| P0/P1/P2/P3/保留 | 已确认/结构信号/证据缺口 | 脱敏逻辑位置 | 一句话 | personal/local/manual/... | 一句话 |

## 详细发现
...

## 已确认正常或无实际影响
## 证据缺口
## 自检结果
```

格式要求：

- 一览表覆盖每个详细发现，按 P0 → P3 → 保留排序；同优先级先列“已确认”，再列“结构信号”和“证据缺口”。
- `已确认` 只用于只读运行时事实或足以支持结论的确定性结构事实；`结构信号` 不得改写成“已执行”；没有采集则明确写 `证据缺口`。
- `保留` 只用于语法通过、缺失文件无须创建、注释配置不生效等非行动项；可出现在一览表，但不伪装成 P3 问题。
- 合并同一根因的信号，通常保持 5–8 个详细发现；不要为每个变量各写一条，也不要用“可能冲突”凑数。
- 结论、一览表和详细发现必须一致；顶部不得出现详细部分无法追溯的新结论。

为每个可行动发现写明：

```text
类别：手册定义的诊断类别
优先级：P0、P1、P2 或 P3
证据等级：已确认、结构信号或证据缺口
当前行为：只描述脱敏后的现象
证据：引用证据文件中的字段或计数，不复制敏感内容
影响：安全、正确性、架构、性能或维护成本
建议：保留、改写、替代或移除的最小可逆方向
归属：personal、shared、local、retire 或 manual
目标文件：Stage 1 应修改的逻辑位置；用户显式目标优先
风险：修改可能影响的命令或工作流
验证：修改后应执行的命令和预期结果
```

生成结论前逐项过覆盖门；没有问题也要记录已确认正常状态，不能静默跳过：

| 覆盖面 | 必查证据与结论边界 |
|---|---|
| 安全 | 活动和注释的疑似凭证标记、文件权限；不读取值，不把“疑似”写成“真实凭证” |
| 架构 | 硬件 ARM 能力、采集进程架构、Rosetta、Homebrew 前缀、关键命令架构；不得把采集进程说成用户终端，只有组合证据完整时才确认架构混用 |
| 功能 | `*_HOME` 的 target-kind；指向文件可列功能错误，动态或缺失保持 manual 并要求官方语义核验 |
| 补全 | 活动/注释的 `compinit` 引用与调用、fpath 与框架顺序、重复 source 类别；`autoload` 引用不是调用，结构重复不等于已测量执行次数 |
| PATH | 多点赋值、硬编码 HOME、继承 PATH/fpath 精确重复数；脱敏标签相同不等于真实路径相同，继承重复也不能自动归因于启动文件 |
| 作用域 | `scope=exported/shell` 与配置归属；只根据标识符不能判断子进程需求 |
| 工具职责 | 同一运行时出现多个明确所有者才写争用；NVM 与 Bun 并存本身不是冲突证据 |
| 性能 | 只有计时或 profiling 数据才量化；默认采集未 source 启动文件，必须写“未测量” |

遵守以下判断规则：

- 把跨进程静态环境建议放到 `.zprofile`，把交互行为建议放到 `.zshrc`；不建议接管 `.zshenv` 或设置 `ZDOTDIR`。
- 在 `arm64 + /usr/local Homebrew` 或关键命令为 `x86_64` 时明确指出已确认的架构混用；只有文本标记时写结构信号并给核验命令。注释中的 Intel/Rosetta 配置列为“无实际影响”，同时提醒不要重新启用。
- 分开报告活动和注释的 `compinit` 引用与调用；不要把 `autoload -Uz compinit` 计作调用。存在显式调用且框架也负责补全时，指出双所有者的结构候选，并结合 fpath 顺序给最小建议。没有 profiling 时不得声称实际执行次数或毫秒收益。
- `*_HOME target-kind=file` 必须进入一览表的功能正确性项；对具体工具先依据内置手册或官方文档核验语义，不根据变量名猜值。
- source 类别重复时指出重复初始化候选；只有脚本提供内容指纹或运行证据时，才能声称两个文件内容相同或运行了两次。
- PATH/fpath 只有精确重复计数才能写“已确认重复”；多次赋值、相同脱敏标签或硬编码信号只能支持结构性整改建议。
- 不把 NVM 与 Bun 并存自动升级为多版本管理器争用；必须确认它们竞争同一命令、版本选择或 PATH 所有权。
- 对敏感信息只写“疑似敏感变量需要迁移/轮换”，不写值；local 只记录参数类别。
- 只给修改方向和必要的最小片段，不拼装最终完整 Zsh 文件；最终文件由 `$stage-1-apply-zsh-repair-plan` 根据获准计划生成或更新。
- 没有实际内容时不创建空 shared 计划。

### 5. 自检并交接

检查：

- 建议均可追溯到 `tmp/zsh-evidence.md` 和手册章节，没有未经证据支持的结论。
- 证据报告的 `source-origin`、`selected-files`、`source-input-name` 与预检映射、用户选择及修复计划的“证据来源”完全一致。
- 输出路径只用于表示计划归属，没有被当作证据来源；两者不一致时已在计划中明示。
- 顶部结论和问题一览表均存在，覆盖全部详细发现，并标注证据等级。
- 已逐项检查安全、架构、功能、补全、PATH、作用域、工具职责和性能覆盖门；缺失证据已显式列出。
- public 计划不含 shared 仓库专属信息、本机绝对路径、账号、远程地址或敏感值。
- shared/local/retire/manual 未混入 personal 活动配置建议。
- 计划没有生成或修改最终 Zsh 文件，没有安装、退役、commit 或 push。
- 建议包含明确目标、风险和可执行验收，而不是只复述最佳实践；未测量项没有虚构运行时结果。
- 交接说明准确区分“采集脚本只读扫描了启动文件”和“AI 未直接读取文件内容”；不要笼统声称整个 Skill 未读取源文件。

完成后把修复计划路径、发现摘要、证据缺口和自检结果交回 `$stage-0-source-machine-analysis-and-export`。不要自行请求最终写入确认，也不要把 `tmp/` 候选写入正式目录。
