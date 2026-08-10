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

Stage 0：dump.sh 导出软件/tooling/plugin → Zsh Skill 生成修改建议 → Review Skill 先给工具一句话描述并审阅 → 跨结果自检 → 用户一次确认
  → Stage 1：应用已确认 Zsh 修复计划 → 用户确认完整 diff → 写入显式目标或默认仓库目标
    → Stage 2：按原生机器架构运行 install.sh → verify
      → Stage 3：仅 Apple Silicon 上运行 install.sh retire 预览 → 用户确认 → 退役与验证
```

### 2.1 所有 Skill 的执行前计划门

每个阶段 Skill 和独立子 Skill 被触发后，都必须先进入只读盘点，不得立即生成候选文件、编辑仓库、修改 HOME、安装或删除软件、启停服务、commit 或 push。只读盘点只允许读取本 Skill 边界内的必要文件、`git status`/diff、路径元数据以及明确允许的只读系统事实；不得为了补充计划而越过 local、密钥、公司或真实 Zsh 内容边界。

只读盘点完成后，在首次生成文件或状态变更前，必须向用户展示一份执行计划，至少包含：

1. 当前发现、前置缺口和必要假设；
2. 将读取、创建、修改或删除的精确范围，以及计划运行的关键命令；
3. 可能影响的仓库文件、真实 HOME、软件、服务、数据或网络访问；
4. 风险、不可自动恢复项、验证方式和停止条件；
5. 明确不会执行的越界事项，以及后续仍需单独确认的阶段门禁。

展示后必须停止并等待用户明确确认；空白、含糊回复或只回答局部问题不视为授权。用户确认只授权已展示范围，不能替代 Stage 0 正式草稿写入确认、Stage 1 Zsh diff 确认、Stage 2 安装器确认、Stage 3 删除确认，也不授权 commit、push 或范围外变更。

若本 Skill 由上级 Stage Skill 编排，且上级计划已逐项覆盖本 Skill 的读写范围、可能影响和验证并已获确认，可以继承这次初始计划确认，不重复打断用户。执行前重新检查输入与工作树；范围、风险或状态发生实质变化时，先展示更新后的完整计划并再次等待确认。

阶段之间只保留以下边界：

1. Stage 0 的草稿未经用户确认，不写入 personal/company 目标文件。
2. Stage 1 的最新完整 Zsh diff 未经确认，不写入目标，也不进入 Stage 2。
3. [`install-sh-plan.md`](./install-sh-plan.md) 定义的脚本、pre-commit 和 CI 能力未实现或未验证，不用于真实机器安装。
4. Stage 2 安装与验证未完成，不进入 Stage 3。
5. Stage 3 只适用于 Apple Silicon，且不由 Stage 2 自动触发。

## 3. 仓库和配置职责

| 范围 | 保存位置 | 负责 | 不负责 |
|---|---|---|---|
| 公开仓库 | 用户当前 Git 仓库 | `dump.sh`、根 `install.sh`、三个内部能力安装模块、Skills、文档、测试、pre-commit、CI 和 `my_setup/` | 公司内容、本机密钥 |
| personal | 公开仓库固定 `my_setup/` | 可分享的 Zsh、Brewfile、tooling、插件和软件期望状态 | 公司增量、本机密钥 |
| company | 可选独立私有仓库 | 公司专属 Zsh、Brewfile、tooling 和插件增量 | 通用脚本、个人偏好、本机密钥 |
| local | `~/.config/dotfiles/local/parameters.zsh` | 密钥值、账号、机器路径和不可公开参数 | Brewfile、软件清单、插件选择、普通共享配置 |

`personal configuration` 是语义分类；它在磁盘上的固定映射是：

```text
personal configuration → <public-repository>/my_setup/
```

company 缺失时，personal + local 必须能够独立工作。local 文件缺失时，personal 也必须能够独立工作。

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
│   │   ├── .zprofile          # Stage 1 生成或更新
│   │   ├── .zshrc             # Stage 1 生成或更新
│   │   ├── zsh-repair-plan.md
│   │   └── plugins.toml
│   ├── macos/
│   │   ├── install.sh
│   │   └── Brewfile
│   └── tooling/
│       └── install.sh
├── tests/
├── .githooks/pre-commit
└── .github/workflows/
```

可选 company 仓库：

```text
company-dotfiles/
├── zsh/
│   ├── company.zsh
│   ├── zsh-repair-plan.md
│   └── plugins.toml
├── macos/Brewfile
└── tooling/
```

本机私有参数：

```text
~/.config/dotfiles/
└── local/
    └── parameters.zsh
```

不存在实际内容时不创建空 company 文件。详细 tooling 文件由实际工具决定，不为统一目录外观创建空 schema 或占位文件。

Stage 1 根据已确认修复计划生成或更新最终 `.zprofile`、`.zshrc` 和可选 `company.zsh`；用户显式提供目标文件时优先更新这些目标，否则使用上述默认仓库位置。Stage 2 只接受与安装器固定来源一致的仓库版 Zsh；显式目标在仓库外时不得擅自复制或覆盖。必要仓库文件缺失时根安装器必须阻断真实安装，安装器 smoke test 只能在临时仓库中使用最小 fixture。

## 5. Zsh 运行时边界

- 不接管 `~/.zshenv`，不设置 `ZDOTDIR`。
- `~/.zprofile` symlink 到 `my_setup/zsh/.zprofile`。
- `~/.zshrc` symlink 到 `my_setup/zsh/.zshrc`。
- `.zshrc` 的受管加载顺序固定为 `company → personal → local`。
- `.zshrc` 使用 `dotfiles: company`、`dotfiles: personal`、`dotfiles: local` 固定标记供安装器验证加载顺序。
- `.zshrc` 为每个启用插件保留 `dotfiles: plugin <name>` 标记，并按合并后的 `load_order` 递增排列。
- company 只有一个可选 `zsh/company.zsh`，必须能够在 personal 配置之前独立加载。
- local 只有一个可选 `parameters.zsh`，在 personal 配置之后加载。
- company 或 local 文件缺失时静默跳过；存在但语法错误时 `install.sh verify` 失败。
- Stage 1 以目标现有内容为基线做最小修改，尽可能保留修复计划未涉及的 Oh My Zsh 官方模板注释、分区、选项和初始化形态；不得为了模板升级而整文件替换。
- 日常配置只激活当前机器原生 Homebrew：Intel 使用 `/usr/local`，Apple Silicon 使用 `/opt/homebrew`；不得同时激活另一架构前缀，不得包含 Rosetta fallback 或 ARM→Intel wrapper。

`parameters.zsh` 可以直接保存密钥值和其他不可公开参数。默认安全要求：

- 文件权限 `0600`，父目录权限 `0700`；
- 不进入 Git、云同步、普通备份、日志、报告、测试 fixture 或哈希输入；
- Zsh Skill 的采集脚本只提取脱敏结构信号，`dump.sh` 不读取 Zsh 文件；两者都不采集 `parameters.zsh` 内容。`install.sh` 不打印、复制或持久化内容，只允许无输出的语法检查和正常 shell 加载；
- Keychain 是可选增强，不是安装前置条件。

## 6. 软件与插件边界

- Homebrew 管理系统 CLI、原生库和 GUI cask。
- mise 管理需要固定版本的跨项目 runtime 和 CLI。
- uv 管理 Python 版本、环境和 Python tool。
- `dump.sh` 优先调用各管理器只读、可回放的原生 Dump；没有 Dump 时使用结构化只读输出，由导出配置 Review Skill 转为目标配置。
- 原生命令如果会维护或写入仓库外状态，Stage 0 必须退化为只读元数据检查。
- personal 与 company 分别声明自己的 Brewfile 和 tooling；完全相同的项目去重，可覆盖字段按 company → personal 处理，管理器或版本所有权不兼容时停止并报告。
- personal 与 company 各自最多使用一份 `plugins.toml`，同一条目内记录来源、固定 revision、启用状态和加载顺序。
- local 不定义软件、版本或插件。

## 7. 命令契约

```text
./dump.sh
./install.sh
./install.sh verify
./install.sh retire
./install.sh retire --apply
```

- `dump.sh` 属于 Stage 0，只读导出软件、tooling 和插件证据及同构候选文件；Zsh 证据由 Zsh Skill 内部脚本独立采集。
- 无参数 `install.sh` 等于安装 apply。执行前即时展示摘要，并以默认 `N` 的 `y/N` 确认。
- `install.sh verify` 验证 Zsh、symlink、架构、软件来源和插件状态。
- `install.sh retire` 属于 Stage 3，只读预览。
- `install.sh retire --apply` 只在真实终端接受默认 `N` 的 `y/N` 确认。
- 根目录 `install.sh` 是唯一公开安装入口；`my_setup/zsh/install.sh`、`my_setup/tooling/install.sh`、`my_setup/macos/install.sh` 只作为被根安装器加载的内部能力模块，直接执行时安全失败。
- 主流程只提供上列命令，不扩张额外用户命令入口或独立迁移脚本。

## 8. 写入与删除安全

- 覆盖本地 Zsh 入口前，只为已有 `.zsh` 文件或 symlink 创建保留类型与目标的副本。
- 安装器不得覆盖 Git 工作树中的未提交冲突。
- 密钥、公司内容和本机路径不得进入 public 输出。
- Stage 0 只清理自己生成的 `tmp/zsh-evidence.md`、`tmp/dump.md`、`tmp/my_setup/`、执行期间的 `tmp/.runtime/` 和明确生成的可选 `tmp/company/`，不得清空未知临时内容。
- `dump.sh` 必须覆盖子进程的临时目录和可重定向缓存位置；只读使用 Homebrew 已有 metadata cache 时必须禁用 refresh、自动更新和 description 查询，使原生工具采集不会写入仓库外目录。
- 服务、数据库和 GUI 应用数据只检测并报告，不自动迁移。
- 未处理服务数据、未知 Intel 项、项目级依赖或未验证的原生架构替代不得删除。
- 不递归删除 `/usr/local`，不整体改变其 owner。
- 不透明的 `curl | shell` 不得作为安装或退役实现。

除 Zsh 入口副本外，主流程不实现自动恢复。未来 rollback 需求统一记录在 [rollback_feature.md](./rollback_feature.md)。

## 9. 共用验证

最低验证包括：

- 所有启用 Zsh 文件通过 `zsh -n`；
- login 与 interactive shell 无加载错误；
- symlink 指向 `my_setup/zsh/`；
- 加载顺序为 company → personal → local；
- local 权限正确且未被 Git 跟踪；
- Homebrew 与 PATH 符合原生硬件架构：Intel 使用 `/usr/local`，Apple Silicon 使用 `/opt/homebrew`，另一架构前缀不活跃；
- Apple Silicon 的 Rosetta 会话不会回退使用 Intel Homebrew；
- Brewfile、mise/uv 和 `plugins.toml` 可解析；
- 导出配置 Review Skill 范围内的每个直接期望项目都有一句话描述、最佳实践、修改级别、建议、归属和验证评论；Stage 0 摘要先显示该描述再显示建议；
- 已安装命令的实际路径、版本和架构符合期望；
- `install.sh` 再次执行不会重复破坏已有配置；
- retire 预览不包含未知项目和未处理数据。

性能检查只产生建议，不阻止基础交付。

## 10. 文档和 Skill 约束

- 阶段文档只描述本阶段输入、主流程、输出和停止边界。
- Zsh 修改建议只由 Zsh Skill 生成；按需读取其内置的 [Zsh 配置诊断与优化指南](./analyze-zsh-configuration/references/zshrc-diagnostics-guide.md)，不得复制回编排或 Review Skill。
- 导出配置 Review Skill 只审阅 `dump.sh` 已导出的软件、tooling 和插件文件，不读取 Zsh 证据或修改 `zsh-repair-plan.md`。
- 后续转化为真正 Skill 时，`SKILL.md` 只保留触发条件和核心工作流；确定性检查再沉淀为 scripts。
- `README.md` 保持完整中文正文并作为默认入口，`README.en.md` 保持完整英文正文；两份文件在标题后的靠前位置互相链接，pre-commit 与 CI 负责验证结构同步及基础安全。
