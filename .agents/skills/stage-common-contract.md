# macOS Dotfiles 四阶段共用契约

> 状态：轻量共用需求<br>
> 日期：2026-08-10<br>
> 适用范围：Stage 0–3

## 1. 目的与权威顺序

本文件只保存四个阶段真正共用的术语、目录、命令和安全边界。具体步骤由对应阶段 Skill 或文档定义：

- [Stage 0：源机器分析与配置导出编排 Skill](./stage-0-source-machine-analysis-and-export/SKILL.md)
- [Zsh 配置分析与修改建议 Skill](./analyze-zsh-configuration/SKILL.md)
- [导出配置 AI Review Skill](./review-exported-dotfiles/SKILL.md)
- [Stage 1：应用 Zsh 修复计划 Skill](./stage-1-apply-zsh-repair-plan/SKILL.md)
- [Stage 2：目标机器配置与软件迁移 Skill](./stage-2-target-machine-configuration-and-software-migration/SKILL.md)
- [Stage 3：旧 Intel 软件退役 Skill](./stage-3-intel-homebrew-retirement/SKILL.md)
- [`install.sh` 与轻量 Dotfiles 能力建设计划](./install-sh-plan.md)

[四阶段流程图](./steps.excalidraw) 是阶段职责和功能范围的首要来源。本契约用于补充安全与跨阶段一致性，不得扩张或改变图中的主流程。领域词汇以 [CONTEXT.md](../../CONTEXT.md) 为准。

## 2. 四阶段主线

```text
install.sh plan：独立建设 dump.sh、根 install.sh、三个内部能力安装模块与可复用仓库能力

Stage 0：dump.sh 导出软件/tooling/plugin → Zsh Skill 生成修改建议 → Review Skill 先给工具一句话描述并审阅 → 跨结果自检 → 用户一次确认 → 修复计划写入本机固定目录
  → Stage 1：应用本机已确认 Zsh 修复计划 → 用户确认完整 diff → 写入显式目标或默认仓库目标 → 导出受 runtime/PATH 变更影响的本机全局 CLI 清单
    → Stage 1.1：用户可选确认并生成可分享全局 CLI 迁移声明

Stage 2：在任意目标机器 checkout 根 install.sh + macOS/tooling 声明 → 可选询问全局 CLI 迁移声明 → 按原生架构安装
  → verify 安装完整性 → 可选生成 Intel 退役交接清单
    → Stage 3：仅 Apple Silicon 上读取交接清单并重新盘点 → install.sh retire 预览 → 用户确认 → 退役与验证
```

### 2.1 所有 Skill 的执行前计划门

每个阶段 Skill 和独立子 Skill 被触发后，都必须先进入只读盘点，不得立即生成候选文件、编辑仓库、修改 HOME、安装或删除软件、启停服务、commit 或 push。只读盘点只允许读取本 Skill 边界内的必要文件、`git status`/diff、路径元数据以及明确允许的只读系统事实；不得为了补充计划而越过 local、密钥、shared 仓库专属信息或真实 Zsh 内容边界。

只读盘点完成后，在首次生成文件或状态变更前，必须向用户展示一份执行计划，至少包含：

1. 当前发现、前置缺口和必要假设；
2. 将读取、创建、修改或删除的精确范围，以及计划运行的关键命令；
3. 可能影响的仓库文件、真实 HOME、软件、服务、数据或网络访问；
4. 风险、不可自动恢复项、验证方式和停止条件；
5. 明确不会执行的越界事项，以及后续仍需单独确认的阶段门禁。

展示后必须停止并等待用户明确确认；空白、含糊回复或只回答局部问题不视为授权。用户确认只授权已展示范围，不能替代 Stage 0 正式草稿写入确认、Stage 1 Zsh diff 确认、Stage 2 安装器确认、Stage 3 删除确认，也不授权 commit、push 或范围外变更。

若本 Skill 由上级 Stage Skill 编排，且上级计划已逐项覆盖本 Skill 的读写范围、可能影响和验证并已获确认，可以继承这次初始计划确认，不重复打断用户。执行前重新检查输入与工作树；范围、风险或状态发生实质变化时，先展示更新后的完整计划并再次等待确认。

阶段之间只保留以下边界：

1. Stage 0 的草稿未经用户确认，不写入 personal/shared 目标文件或本机 Zsh 修复计划目录。
2. Stage 1 的最新完整 Zsh diff 未经确认，不写入 Stage 1 目标；其计划状态只服务于 Stage 1 自身交接，不构成 Stage 2 输入或门禁。Stage 1.1 生成的 `my_setup/tooling/global-cli-migration.toml` 只是当前 checkout 的可选 tooling 声明，缺失或目标机用户跳过时均不阻断 Stage 2。
3. [`install-sh-plan.md`](./install-sh-plan.md) 定义的根安装器、三个内部模块及目标路径/验证能力缺失或存在安全错误时，不用于真实机器安装；仓库开发初始化、pre-commit 和 CI 独立于 Stage 2。
4. Stage 2 安装与验证未完成，不进入 Stage 3。
5. Stage 3 只适用于 Apple Silicon，且不由 Stage 2 自动触发。

## 3. 仓库和配置职责

| 范围 | 保存位置 | 负责 | 不负责 |
|---|---|---|---|
| 公开仓库 | 用户当前 Git 仓库 | `dump.sh`、根 `install.sh`、三个内部能力安装模块、Skills、文档、测试、pre-commit、CI 和 `my_setup/` | shared 仓库专属内容、本机密钥 |
| personal | 公开仓库固定 `my_setup/` | 可分享的 Zsh、Brewfile、tooling、插件和软件期望状态 | shared 增量、本机密钥 |
| shared | 可选独立共享仓库 | 与他人共用的 Zsh、Brewfile、tooling 和插件增量 | 通用脚本、纯个人偏好、本机密钥 |
| local | `~/.config/dotfiles/local/parameters.zsh` 与 `integrations.zsh` | 前者保存密钥值、账号和机器参数；后者保存源机器上由第三方安装器追加且不能公开的功能块 | Brewfile、软件清单、插件选择、普通共享配置 |
| 本机 Zsh 修复交接 | `~/.config/dotfiles/zsh-repair/` | Stage 0 保存获准的 personal 修复计划与可选 shared 修复计划，Stage 1 读取并更新状态 | Zsh 运行时加载、Stage 2 安装输入、Git 声明 |
| 全局 CLI 迁移本机状态 | `${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/global_cli_to_be_migrated.tsv` | Stage 1 记录因 NVM、PNPM_HOME、BUN_INSTALL 或本次移除 PATH 而可能失去解析的直接全局 CLI 与本机来源 | Git 声明、认证数据、自动安装授权 |
| 本机状态 | `${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/intel_to_be_retired.tsv` | Stage 2 verify 在 Apple Silicon 上确定性记录残留 Intel 软件与精确路径，供 Stage 3 重新核验 | 声明式软件期望、删除授权、密钥或服务数据正文 |

`personal configuration` 是语义分类；它在磁盘上的固定映射是：

```text
personal configuration → <public-repository>/my_setup/
```

shared 缺失时，personal + local 必须能够独立工作。local 文件缺失时，personal 也必须能够独立工作。

## 4. 轻量目标结构

公开仓库：

```text
dotfiles/
├── README.md            # 默认中文文档
├── README.en.md         # 独立英文文档
├── dump.sh
├── install.sh
├── tmp/                 # Git ignored；Stage 0 临时候选树
├── skills/
├── my_setup/
│   ├── zsh/
│   │   ├── install.sh
│   │   ├── zprofile 或 .zprofile  # Stage 1 选择并生成其中一个
│   │   ├── zshrc 或 .zshrc        # 与 zprofile 使用同一命名方案
│   │   └── plugins.toml
│   ├── macos/
│   │   ├── install.sh
│   │   └── Brewfile
│   └── tooling/
│       ├── install.sh
│       └── global-cli-migration.toml  # 可选；Stage 1.1 确认的 prompt 声明
├── tests/
├── .githooks/
│   ├── install.sh
│   └── pre-commit
└── .github/workflows/
```

可选 shared 仓库：

```text
shared-dotfiles/
├── zsh/
│   ├── shared.zsh
│   └── plugins.toml
├── macos/Brewfile
└── tooling/
```

本机私有参数：

```text
~/.config/dotfiles/
└── local/
    ├── parameters.zsh
    └── integrations.zsh   # 可选；单一四阶段第三方功能块文件
```

本机 Zsh 修复交接：

```text
~/.config/dotfiles/
└── zsh-repair/                         # 0700，不进入 Git，不被 Zsh source
    ├── zsh-repair-plan.md              # 0600；personal，Stage 0 → Stage 1
    └── shared-zsh-repair-plan.md       # 0600；仅确有 shared 增量时
```

Stage 1/2/3 本机交接状态：

```text
${XDG_STATE_HOME:-$HOME/.local/state}/
└── dotfiles/
    ├── global_cli_to_be_migrated.tsv  # Stage 1 可选；只保存生成机器的来源状态
    └── intel_to_be_retired.tsv        # 仅 Apple Silicon 且仍有 Intel 残留时存在
```

不存在实际内容时不创建空 shared 文件。详细 tooling 文件由实际工具决定，不为统一目录外观创建空 schema 或占位文件。

Stage 1 默认从 `~/.config/dotfiles/zsh-repair/` 读取已确认修复计划，生成或更新最终 `zprofile`/`.zprofile`、`zshrc`/`.zshrc` 和可选 `shared.zsh`；用户显式提供目标文件时优先更新这些目标，否则先让用户选择默认无前置点或有前置点命名。会改变 runtime/PATH owner 时，Stage 1 先完整盘点会失去解析的 npm、pnpm、Bun 直接全局 CLI 和明确移除 PATH 目录中的直接 CLI，再生成本机全局 CLI 迁移状态；完成后由 Stage 1.1 可选生成 `my_setup/tooling/global-cli-migration.toml`，该 public 文件不得含本机绝对路径。Stage 2 只读取当前 checkout：根安装器、`my_setup/macos/` 与 `my_setup/tooling/` 是最小集合，`my_setup/zsh/` 可选；不读取修复计划或 Stage 1 本机 TSV。启用 Zsh 时必须恰好存在 `zprofile` + `zshrc` 或 `.zprofile` + `.zshrc` 中一套完整来源；两套并存、混搭或残缺时安装器在确认前阻断，不猜优先级、不生成文件。安装器 smoke test 只能在临时仓库中使用最小 fixture。

## 5. Zsh 运行时边界

- 不接管 `~/.zshenv`，不设置 `ZDOTDIR`。
- `~/.zprofile` symlink 到已选的 `my_setup/zsh/zprofile` 或 `my_setup/zsh/.zprofile`。
- `~/.zshrc` symlink 到与其同组的 `my_setup/zsh/zshrc` 或 `my_setup/zsh/.zshrc`。
- 声明式配置的受管覆盖顺序固定为 `shared → personal → parameters`。`integrations.zsh` 是阶段钩子，不是第四个覆盖层。
- 单一可选 `integrations.zsh` 通过 `zprofile-pre`、`zprofile-post`、`zshrc-pre`、`zshrc-post` 四个分支加载：pre 是对应启动文件第一个非空块，post 是最后一个非空块。
- 对应目标文件使用 `dotfiles: local-integrations <phase>` 固定标记；缺少本阶段功能块时不添加空分支或空 loader。
- `.zshrc` 使用 `dotfiles: shared`、`dotfiles: personal`、`dotfiles: local` 固定标记供安装器验证加载顺序。
- `.zshrc` 为每个启用插件保留 `dotfiles: plugin <name>` 标记，并按合并后的 `load_order` 递增排列。
- shared 只有一个可选 `zsh/shared.zsh`，必须能够在 personal 配置之前独立加载。
- local 参数只有一个可选 `parameters.zsh`，在 personal 配置之后加载；可执行第三方块不得混入该文件。
- shared、parameters 或 integrations 文件缺失时静默跳过；存在但语法错误时 `install.sh verify` 失败。
- Stage 1 以目标现有内容为基线做最小修改，尽可能保留修复计划未涉及的 Oh My Zsh 官方模板注释、分区、选项和初始化形态；不得为了模板升级而整文件替换。
- Stage 0 必须为源 `.zprofile`/`.zshrc` 中识别到的第三方功能块生成脱敏保全清单；Stage 1 写入前后都必须用同一确定性工具比较源文件与目标文件加 `integrations.zsh`，缺块、正文变化、阶段错误或同阶段错序时失败。
- Stage 1 全部目标验证通过后，必须把每份实际采用的本机修复计划状态更新为唯一 `> 状态：Stage 1 已应用`；计划目录/文件保持 `0700/0600` 并使用同目录备份与原子替换，失败、取消或存在被排除的旧 owner 时不得更新。该状态不被 Stage 2 读取。
- 日常配置必须优先激活当前机器原生 Homebrew：Intel 使用 `/usr/local`，Apple Silicon 使用 `/opt/homebrew`；受管命令和 symlink 不得最终解析到另一架构，也不得包含 Rosetta fallback 或 ARM→Intel wrapper。继承环境中的另一架构路径或旧软件可以暂时存在，但只能进入 Stage 2 的 Intel 交接清单，不能替代原生安装目标。

`parameters.zsh` 可以直接保存密钥值和其他不可公开参数。默认安全要求：

- 文件权限 `0600`，父目录权限 `0700`；
- 不进入 Git、云同步、普通备份、日志、报告、测试 fixture 或哈希输入；
- Zsh Skill 的采集脚本只提取脱敏结构信号，`dump.sh` 不读取 Zsh 文件；两者都不采集 `parameters.zsh` 内容。`install.sh` 不打印、复制或持久化内容，只允许无输出的语法检查和正常 shell 加载；
- Keychain 是可选增强，不是安装前置条件。

`integrations.zsh` 只保存由确定性工具从已确认源文件逐字节迁移的第三方功能块，权限同样为 `0600`，不得进入 Git、报告或内容摘要输入。已有 `parameters.zsh` 或 `integrations.zsh` 在 Stage 1 获准修改前必须先创建同目录 `0600` 时间戳副本；无法证明安全合并时保留源块在目标文件并标为 `manual`，不得覆盖本机文件。

## 6. 软件与插件边界

- Homebrew 管理系统 CLI、原生库和 GUI cask。
- mise 管理需要固定版本的跨项目 runtime 和 CLI。
- uv 管理 Python 版本、环境和 Python tool。
- `dump.sh` 优先调用各管理器只读、可回放的原生 Dump；没有 Dump 时使用结构化只读输出，由导出配置 Review Skill 转为目标配置。
- 原生命令如果会维护或写入仓库外状态，Stage 0 必须退化为只读元数据检查。
- personal 与 shared 分别声明自己的 Brewfile 和 tooling；完全相同的项目去重，可覆盖字段按 shared → personal 处理，管理器或版本所有权不兼容时停止并报告。
- personal 与 shared 各自最多使用一份 `plugins.toml`，同一条目内记录来源、固定 revision、启用状态和加载顺序。
- local 不定义软件、版本或插件期望状态；`integrations.zsh` 只保留安装器已经追加的机器级加载块。
- Stage 1 本机全局 CLI TSV 只保存迁移证据与决定；可分享安装意图只进入 `my_setup/tooling/global-cli-migration.toml`。Stage 2 不要求该 TOML 存在，存在时必须按目标机重新询问，只有用户选择的条目进入该次安装与验证条件。

## 7. 命令契约

```text
./dump.sh
./install.sh
./install.sh verify
./install.sh retire
./install.sh retire --apply
```

- `dump.sh` 属于 Stage 0，只读导出软件、tooling 和插件证据及同构候选文件；Zsh 证据由 Zsh Skill 内部脚本独立采集。
- 无参数 `install.sh` 等于安装 apply。它只读取当前 checkout 的声明，执行前即时展示摘要，并以默认 `N` 的 `y/N` 确认。
- `install.sh verify` 验证全部 Zsh/tooling symlink、架构、软件、runtime 和插件是否安装到当前系统定义的原生目标；Apple Silicon 上若仍有 Intel 残留，唯一允许的写入是原子维护本机 `intel_to_be_retired.tsv` 交接清单。
- `install.sh retire` 属于 Stage 3，只读预览。
- `install.sh retire --apply` 只在真实终端接受默认 `N` 的 `y/N` 确认。
- 根目录 `install.sh` 是唯一公开安装入口；`my_setup/zsh/install.sh`、`my_setup/tooling/install.sh`、`my_setup/macos/install.sh` 只作为被根安装器加载的内部能力模块，直接执行时安全失败。
- 主流程只提供上列命令，不扩张额外用户命令入口或独立迁移脚本。

## 8. 写入与删除安全

- 覆盖本地 Zsh 入口前，只为已有 `.zsh` 文件或 symlink 创建保留类型与目标的副本。
- 安装器不得覆盖 Git 工作树中的未提交冲突。
- 密钥、shared 仓库专属内容和本机路径不得进入 public 输出。
- 本机 `zsh-repair/` 目录使用 `0700`、计划使用 `0600`，不进入 Git、shared 或 Stage 2；覆盖前创建同目录 `0600` 时间戳备份并原子替换，不得跟随 symlink。公开/shared 旧位置的计划只作为 legacy 报告，未经完整 diff 确认不得删除。
- Stage 0 只清理自己生成的 `tmp/zsh-evidence.md`、`tmp/dump.md`、`tmp/my_setup/`、执行期间的 `tmp/.runtime/` 和明确生成的可选 `tmp/shared/`，不得清空未知临时内容。
- `dump.sh` 必须覆盖子进程的临时目录和可重定向缓存位置；只读使用 Homebrew 已有 metadata cache 时必须禁用 refresh、自动更新和 description 查询，使原生工具采集不会写入仓库外目录。
- 服务、数据库和 GUI 应用数据只检测并报告，不自动迁移。
- `intel_to_be_retired.tsv` 使用 `0700` 父目录与 `0600` 文件权限，不进入 Git；只记录精确管理器项目/路径和保留理由，不递归枚举 `/usr/local`，也不构成 Stage 3 删除授权。
- `global_cli_to_be_migrated.tsv` 同样使用 `0700` 父目录与 `0600` 文件权限，不进入 Git；只记录本次 Zsh/runtime 变更影响的直接全局 CLI、本机精确来源和迁移状态，不记录认证数据，也不构成安装授权。
- 未处理服务数据、未知 Intel 项、项目级依赖或未验证的原生架构替代不得删除。
- 不递归删除 `/usr/local`，不整体改变其 owner。
- 不透明的 `curl | shell` 不得作为安装或退役实现。

除 Zsh 入口副本外，主流程不实现自动恢复。未来 rollback 需求统一记录在 [rollback_feature.md](./rollback_feature.md)。

## 9. 共用验证

最低验证包括：

- 所有启用 Zsh 文件通过 `zsh -n`；
- login 与 interactive shell 无加载错误；
- symlink 指向 `my_setup/zsh/`；
- 声明式加载顺序为 shared → personal → parameters，integrations 的 pre/post 阶段和固定标记位置正确；
- Stage 1 自身验证源 `.zprofile` + `.zshrc` 功能块清单全部由目标 Zsh 或 `integrations.zsh` 精确覆盖，除非用户逐项批准 retire；Stage 2 不重复读取该清单；
- local 权限正确且未被 Git 跟踪；
- Homebrew、全部受管命令和 symlink 符合原生硬件架构：Intel 目标位于 `/usr/local`，Apple Silicon 目标位于 `/opt/homebrew`；另一架构前缀或旧软件可以残留，但不得成为受管目标，并须在 Apple Silicon 上写入 `intel_to_be_retired.tsv`；
- Apple Silicon 的 Rosetta 会话不会回退使用 Intel Homebrew；
- Brewfile、mise/uv 和 `plugins.toml` 可解析；
- 导出配置 Review Skill 范围内的每个直接期望项目都有一句话描述、最佳实践、修改级别、建议、归属和验证评论；Stage 0 摘要先显示该描述再显示建议；
- Stage 1 改变 runtime/global home/PATH owner 时，失去解析影响集完整覆盖 npm、pnpm、Bun 和明确移除 PATH 目录中的直接 CLI，本机全局 CLI 清单 schema、权限、稳定排序和影响覆盖正确；被用户排除或无法安全盘点的 owner 对应退役必须被阻止。Stage 1.1 public 声明只含用户选择的固定 package/version/binaries/target manager，且不含本机路径；
- 已安装命令的实际路径、版本和架构符合期望；
- `install.sh` 再次执行不会重复破坏已有配置；
- `intel_to_be_retired.tsv` 可确定性解析、权限正确、没有误把未知路径或 service/data 标为可删除；Stage 3 会重新盘点而不直接信任该快照；
- retire 预览不包含未知项目和未处理数据。

性能检查只产生建议，不阻止基础交付。

## 10. 文档和 Skill 约束

- 阶段文档只描述本阶段输入、主流程、输出和停止边界。
- Zsh 修改建议只由 Zsh Skill 生成；按需读取其内置的 [Zsh 配置诊断与优化指南](./analyze-zsh-configuration/references/zshrc-diagnostics-guide.md)，不得复制回编排或 Review Skill。
- 导出配置 Review Skill 只审阅 `dump.sh` 已导出的软件、tooling 和插件文件，不读取 Zsh 证据或修改 `zsh-repair-plan.md`。
- 后续转化为真正 Skill 时，`SKILL.md` 只保留触发条件和核心工作流；确定性检查再沉淀为 scripts。
- `README.md` 保持完整中文正文并作为默认入口，`README.en.md` 保持完整英文正文；两份文件在标题后的靠前位置互相链接。pre-commit 与 CI 负责仓库结构同步及基础安全结果，通过独立的一次性仓库初始化接入 Git 默认 hooks 路径，不属于 Stage 2。
