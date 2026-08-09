# Apple Silicon Dotfiles 四阶段共用契约

> 状态：实施级共用规格<br>
> 版本：1.1<br>
> 日期：2026-08-09<br>
> 适用范围：阶段 0–3 的共同概念、接口边界和安全不变量

## 1. 文档目的

本契约是四份阶段需求的唯一共用定义来源：

- [阶段 0：源机器分析与导出](./stage-0-source-machine-analysis-and-export.md)
- [阶段 1：可移植 Dotfiles 能力建设](./stage-1-portable-dotfiles-capability-build.md)
- [阶段 2：目标机器配置与软件迁移](./stage-2-target-machine-configuration-and-software-migration.md)
- [阶段 3：Intel Homebrew 退役](./stage-3-intel-homebrew-retirement.md)

四份阶段文档只定义该阶段特有的流程、输入、输出和验收条件。实施者在执行任一阶段前必须完整阅读本契约；阶段文档引用本契约时，不得自行复制、放宽或重新解释共同规则。

设计来源：[四阶段流程图](./steps.excalidraw) 及拆分时审阅的原综合实施计划 v2.0。

阶段图决定四个阶段的边界和主线；原综合计划提供历史行为与安全依据。拆分后的五份文档已吸收并修正其配置职责模型，是后续实施和 Skill 化的现行需求基线；发生冲突时以本契约和对应阶段文档为准。

## 2. 综合目标

从一台已有工作环境的源机器中，安全地整理 Zsh 配置，并导出关键软件、工具链及其配置的期望状态；随后将这些机器现状转化为可复用、可验证、可回滚的 Dotfiles 产品能力，使另一台目标机器无需人工复刻源机器即可完成关键软件安装、配置迁移和验证。Intel Homebrew 的最终退役保持为单独、显式、不可逆的最后阶段。

这不是整机克隆。目标机器接收的是经过分类、规范化、脱敏和审批的期望状态，不接收源机器的偶然状态、密钥、公司信息、本机路径、缓存或完整软件依赖闭包。

## 3. 阶段模型

```text
阶段 0：源机器分析与导出
  → 阶段 1：建设可移植仓库能力
    → 阶段 2：目标机器应用配置并迁移关键软件
      → 阶段 3：显式退役 Intel Homebrew
```

阶段门禁不可跳过：

1. 阶段 0 未完成两次独立预审批，不得把候选文件提交到阶段 1 仓库。
2. 阶段 1 未通过隔离环境自闭环验证，不得用于目标机器阶段 2。
3. 阶段 2 未生成并验证本机迁移 manifest 和退役账本，不得进入阶段 3。
4. 阶段 3 不得由前一阶段自动触发。

阶段 0 和阶段 1 是仓库维护者执行的生产流程；阶段 1 形成一次建设、多人复用的能力。阶段 2 和阶段 3 由每个用户在各自目标机器上执行，本机 inventory、plan、manifest、backup、密钥状态和 retired record 不得回传公开仓库。

## 4. 规范用语

项目领域词汇以仓库根目录的 [CONTEXT.md](../CONTEXT.md) 为准。本文件只补充实施规格中的规范词：

- **必须**：正确性或安全性要求；不满足时阻止进入下一门禁。
- **应当**：默认最佳实践；只有记录证据和偏离理由后才可改变。
- **可以**：可选增强；不影响基础验收。
- **公开仓库（public repository）**：保存通用能力和集中式 `my_setup/` 个人配置；“公开”描述存储与分享边界，不是运行时配置层。
- **个人配置（personal configuration）**：公开仓库 `my_setup/` 下完整、可分享的软件和 Zsh 基线。
- **公司配置（company configuration）**：独立私有仓库中只与公司有关的可选配置；目录类别与个人配置对齐，但不复制通用能力。
- **本机私有数据（local private data）**：只保存不能公开的密钥、账号、机器路径和其他参数；不保存软件清单、工具版本、插件选择或普通个人偏好。
- **候选文件**：阶段 0 根据源机器证据生成、符合阶段 1 目标格式但尚未提交的建议版文件。
- **期望状态**：经分类和预审批后希望在目标机器存在的软件、版本和配置集合，不等于源机器的原始 dump。
- **本地应用**：阶段 2 中由配置安装器完成的 symlink、私有参数接入、备份和验证。
- **迁移**：阶段 2 中由独立迁移脚本安装 ARM 替代项、迁移已授权服务/数据并验证；不卸载 Intel Homebrew。
- **退役**：阶段 3 中由同一迁移脚本正式卸载 Intel Homebrew 并记录结果；不等于递归删除 `/usr/local`。
- **不可代理边界**：必须由用户亲自选择、授权或确认的外部或不可逆动作。

## 5. 职责组合与固定目录

### 5.1 职责边界

| 概念 | 保存位置 | 负责 | 不负责 |
|---|---|---|---|
| 公开仓库 | 用户选择的可分享 Git 仓库 | 通用 Skill、`install.sh`、`bin/`、`scripts/`、schema、测试、文档，以及集中式 `my_setup/` | 公司内容、密钥、本机不可公开参数 |
| 个人配置 | 公开仓库固定 `my_setup/` | 可分享的 Zsh、Brewfile、工具版本、插件和软件期望状态 | 通用执行能力、公司增量、密钥 |
| 公司配置 | 可选的公司私有 Git 仓库 | 仅公司相关 Zsh、软件、工具、插件和诊断增量 | Skill、安装器、迁移/退役脚本、通用 schema、个人偏好、密钥 |
| 本机私有数据 | 固定 `~/.config/dotfiles/local/` | Keychain 引用、密钥例外、账号、机器路径和不可公开参数 | Brewfile、软件清单、mise/uv 版本、插件选择、普通 alias/function 或通用偏好 |

个人方案由“公开仓库中的个人配置 + 本机私有数据”组成；公司场景在二者之间加入可选公司配置。活动配置的覆盖关系固定为：

```text
personal configuration < company configuration（可选） < local private data
```

local 的最高优先级只用于私有值覆盖，不得借此重新引入一套普通个人配置。company=`skip` 时，个人配置与本机私有数据必须独立形成完整可用方案。

### 5.2 仓库来源目录

```text
~/.local/share/dotfiles/
├── public/                           # 公开仓库 checkout；配置位于其 my_setup/
├── company/                          # company 仓库 checkout，可不存在
├── oh-my-zsh/                        # 固定 revision
└── plugins/                          # 固定 revision 的外部插件
```

阶段 2 的来源配置固定保存在：

```text
~/.config/dotfiles/sources.toml
```

`source` 可以是安全的 Git URL 或已有本地路径。Git URL 不得内嵌用户名、token 或密码；已有目录只能验证，不能删除或重建；远程更新只能 `fetch` 和显式 `pull --ff-only`。

### 5.3 本机私有数据固定根

本机私有数据根固定为 `~/.config/dotfiles/local/`，不得由 Agent 或用户在阶段执行中另选：

```text
~/.config/dotfiles/
├── sources.toml
├── company -> <selected-company-root> # company 启用时的稳定 symlink
└── local/
    ├── zsh/
    │   ├── profile.zsh
    │   ├── pre.zsh
    │   └── rc.zsh
    └── parameters/                    # 仅显式 schema 支持的工具私有参数；不自动加载
```

秘密默认只存在 macOS Keychain，不创建对应明文文件。`local/zsh/*.zsh` 只允许 Keychain wrapper 所需的本机账号、私有路径和无法公开的参数；`local/parameters/` 仅在目标工具有明确安全 schema 时使用，不提供通用 `.env` 自动加载。inventory 必须保存到状态目录，不得放入 local 配置。

`~/.config/dotfiles/company` 是个人 Zsh 真实入口寻找公司配置的唯一稳定路径。company=`skip` 时不得创建该 symlink。

### 5.4 状态目录

```text
~/.local/state/dotfiles/
├── stage0/<run-id>/
├── backups/<config-run-id>/
├── manifests/<config-run-id>/
├── reports/<config-run-id>/
├── migrations/<migration-run-id>/
├── retired-homebrew/<migration-run-id>/
└── locks/
```

状态目录不得自动清理；只能提供 `list` 和带预览、带确认的 `prune`。配置应用与软件迁移必须使用不同 run-id 和不同 manifest 命名空间。

## 6. Zsh 运行时契约

### 6.1 真实入口

- 不接管 `~/.zshenv`，不设置 `ZDOTDIR`。
- `~/.zprofile` 必须稳定 symlink 到公开仓库 `my_setup/zsh/.zprofile`。
- `~/.zshrc` 必须稳定 symlink 到公开仓库 `my_setup/zsh/.zshrc`。
- 两个 personal 文件本身必须是完整、可直接阅读和测试的真实入口，不得是薄跳转器。
- `my_setup/zsh/` 不得创建 `entrypoints/`、`lib.zsh`、`zsh/lib/`、`profile.d*`、`pre.d*`、`rc.d*` 或通用 phase loader。
- company/local 每层只允许 `profile.zsh`、`pre.zsh`、`rc.zsh` 三个固定增量文件，不允许阶段分片目录；local 文件只能承载私有参数或秘密注入。

### 6.2 加载顺序

`.zprofile` 的固定顺序：

```text
personal ARM login PATH 和稳定非敏感环境
  → company/zsh/profile.zsh
    → local/zsh/profile.zsh
```

`.zshrc` 必须以固定 Oh My Zsh revision 的官方 `templates/zshrc.zsh-template` 为骨架，并保持原生注释、段落顺序和 `source $ZSH/oh-my-zsh.sh`：

```text
OMZ 官方模板头部与选项
  → company/local pre.zsh
    → 唯一一次 source $ZSH/oh-my-zsh.sh
      → personal 用户配置受管区块
        → company/local rc.zsh
          → 外部 ZLE 插件；zsh-syntax-highlighting 最后加载
```

Oh My Zsh 独占唯一一次 `compinit`。company/local 文件缺失时日常启动静默跳过；文件存在但加载失败时日常 shell 警告并保留 personal 基础能力；`apply/verify` 遇到同样错误必须阻断。

### 6.3 PATH 与架构

- 最终运行时只接受 Apple Silicon Homebrew 前缀 `/opt/homebrew`。
- `~/.local/bin` 必须有且只出现一次。
- 使用 Zsh `path` 数组和唯一化语义，禁止重复字符串拼接。
- 日常配置不得包含 Intel Homebrew PATH、Rosetta 分支、Intel wrapper 或 ARM→Intel fallback。
- Intel 旧路径只允许迁移脚本为盘点、迁移和移除目的在受控子进程中短时使用，不得写回配置或用户 PATH。

## 7. 软件、插件和版本所有权

| 管理器 | 唯一职责 | 不得负责 |
|---|---|---|
| ARM Homebrew | 系统 CLI、原生库、GUI cask，以及 mise、uv、zoxide、fzf 等宿主工具 | Node/Python 多版本、npm/pip 全局包 |
| mise | Bun、Node 兼容版本、pnpm、Go、Gitleaks及其他需固定版本的跨项目 CLI | Python 版本、Python venv、Python tool |
| Bun | 默认 JS/TS runtime 与项目包管理 | 全局 Node 版本切换 |
| uv | Python 版本、项目依赖、venv 和 Python CLI tool | Node、Go 或系统库 |

所有语言运行时、Oh My Zsh、外部插件和安全工具必须固定明确版本、tag 或 commit；禁止 `latest`。移除 NVM、pyenv、旧 autojump、重复 Bun/pnpm/Go PATH 和重复 `compinit`。项目级配置仍可覆盖全局版本，但不得绕过信任机制。

软件期望状态只由个人配置与可选公司配置表达：

```text
<public-repository>/my_setup/macos/Brewfile
<company-repository>/macos/Brewfile             # 可选
```

local 不得保存 Brewfile 或软件增删清单。Homebrew 不设计 lockfile；需固定的语言版本由 personal/company 的 mise/uv 配置管理。`brew bundle cleanup` 默认只预览，不得在通用 apply 中使用 `--force`。Mac App Store 只做状态目录中的本地清单，不自动安装或处理 Apple ID。

## 8. 命令职责边界

### 8.1 配置安装器

`install.sh` 只负责阶段 2 的配置来源、计划、备份、personal 真实入口 symlink、company/local 增量、作为 Zsh 配置运行依赖的固定 revision Oh My Zsh/插件、验证和配置回滚：

```text
./install.sh
./install.sh configure
./install.sh plan
./install.sh apply
./install.sh verify
./install.sh rollback <run-id>
```

无参数和 `plan` 必须只读。`apply` 不得调用包管理器安装关键软件、调用迁移脚本、卸载 Homebrew 或自动进入下一阶段。

### 8.2 Intel→ARM 迁移脚本

`scripts/migrate-intel-homebrew-to-arm.sh` 独占 Intel Homebrew 盘点、ARM 替代安装、服务/数据迁移、验证、退役和状态查询：

```text
./scripts/migrate-intel-homebrew-to-arm.sh
./scripts/migrate-intel-homebrew-to-arm.sh --apply
./scripts/migrate-intel-homebrew-to-arm.sh --verify
./scripts/migrate-intel-homebrew-to-arm.sh --retire
./scripts/migrate-intel-homebrew-to-arm.sh --retire --apply
./scripts/migrate-intel-homebrew-to-arm.sh --status
```

无参数、`--verify`、`--retire` 和 `--status` 只读。普通 `--apply` 属于阶段 2，只安装和验证 ARM 替代项；`--retire --apply` 属于阶段 3，是唯一正式退役入口。两个写模式都必须在原生 `arm64` 会话执行。

### 8.3 日常命令

`bin/dotfiles` 可以提供状态、诊断、验证、来源更新、插件计划和备份查询，但不得包装或复制迁移/退役写入逻辑。

## 9. 修改分类与 Agent 预审批

每个可独立决策的建议或配置项必须标注三档修改级别：

| 修改级别 | 判断标准 | 默认决策 |
|---|---|---|
| 一定要改 | 不改会违反正确性、安全、架构、可移植性、可公开性或阶段门禁 | `accept`；原方案不完整时 `revise` |
| 建议修改 | 修改可明确降低重复、维护成本、性能问题或迁移风险，收益大于兼容成本 | 默认 `accept`；实现细节需调整时 `revise` |
| 可以不改 | 纯偏好、证据不足但不阻断、收益不明确或不属于首期目标 | 默认 `reject`，保持现状或进入 backlog |

`defer` 不是第四种修改级别，只用于缺少证据且会实质阻断安全或正确性的情况。Agent 必须先穷尽只读证据，再把真正阻塞项合并为一个问题请求用户决策，不得逐项询问。

阶段 0 的 Zsh 建议与配置候选必须分别预审批；第二次审批不得替代第一次。分类与预审批只代理内容判断和可逆修改，不代理下一节列出的外部或不可逆授权。

## 10. 不可代理与不可逆边界

以下动作必须由用户显式选择、授权或亲自执行：

- 选择阶段 0 的公开仓库 checkout/root 和 company 仓库 checkout/root；公开仓库内个人配置目录固定为 `my_setup/`。
- 创建远程仓库、授予公司服务访问权、改变仓库可见性和向远程 push。
- 信任并执行公司 hook 或 mise 等配置中的动态执行能力。
- 密钥轮换、明文密钥清除和 shell 历史定向删除。
- 启动或停止有状态服务，以及执行其数据迁移 runbook。
- 正式退役 Intel Homebrew。

正式退役还必须由用户在真实 TTY 中亲自输入精确确认短语；Agent、CI、管道输入和普通 `--yes` 均不得替代。

## 11. 密钥与隐私

- 密钥不得进入公开/company Git、Git 历史、诊断输出、日志、CI artifact 或普通长期备份。
- API key 默认保存在 macOS Keychain，只由命令 wrapper 临时注入；仓库不实现自定义密钥管理 CLI。
- Keychain service 统一使用 `dotfiles:<VARIABLE_NAME>`；读取值时不得打印或持久化。
- 只有工具无法临时注入时，才允许在 local `zsh/rc.zsh` 的独立标记区块保存明文例外；文件必须 `0600`，父目录必须 `0700`。
- 旧历史扫描只记录变量类别、文件、命中数和不可逆脱敏指纹。必须先轮换密钥，再经独立授权定向删除命中记录。
- personal 候选的配置、注释和 sidecar 均不得包含公司名、内部域名、账号、设备标识或机器绝对路径。

## 12. Git、供应链和文件安全

- 不得自动 `reset`、`stash`、force checkout、覆盖未提交修改或改变仓库可见性。
- Git 更新只能 `fetch` 和显式 `pull --ff-only`。
- 已存在文件或工作树冲突必须停止并报告，不得自动换到 staging 或另一个默认目录。
- 外部下载后执行的脚本和公司 hook 必须记录来源 revision 与 SHA-256；禁止不透明的 `curl | shell`。
- 固定版本 Gitleaks 必须覆盖 tracked、untracked、ignored、暂存区、当前提交和完整历史；扫描失败时 fail closed。
- 公开仓库采用 MIT License；company 和 local 内容不受该许可证覆盖。

## 13. 追溯、哈希与回滚原则

- 普通流程状态使用 run-id、稳定 ID、Git diff/commit、备份路径和验证结果追踪，不对每条记录或可逆文件维护 SHA-256。
- 阶段 0 只在两次预审批结束后，为整组可分享/company 候选及 local 脱敏元数据生成一份 `stage0-summary.sha256`；local 私有文件内容和 Keychain 值不得进入摘要输入。
- 阶段 1 落库后使用 Git commit ID 接管内容身份。
- 阶段 3 只为冻结的最终不可逆退役 manifest 生成 `retirement-manifest.sha256`。
- 可逆配置修改必须先生成计划、备份和 manifest，再 apply；验证应覆盖目标类型、symlink 指向、权限、命令来源和 rollback 演练。
- 新安装软件默认不由配置 rollback 自动卸载，只生成 cleanup 预览。
- 密钥轮换、明文清除和 Intel Homebrew 退役不可恢复；退役后不得自动重装 Intel Homebrew。

## 14. 共用验证基线

阻断检查至少覆盖：

- Zsh 语法、login/interactive/non-login interactive 启动场景。
- 两个真实 symlink 入口、三层固定 source 点和覆盖顺序。
- Oh My Zsh 模板骨架、唯一一次 OMZ/`compinit`、插件顺序和固定 revision。
- PATH 唯一性、实际命令来源和二进制 `arm64` 架构。
- Brewfile/TOML/schema 语法、工具所有权冲突和明确版本。
- 密钥、公司信息、权限、symlink 越界和 Git 工作树安全。
- plan/apply 幂等性、manifest 完整性、verify 和 rollback。

性能数据只产生建议，不作为阻断门槛。可记录多次 Zsh 启动中位数、波动、`zprof`、插件耗时、PATH 长度和补全缓存状态。

## 15. 未来 Skill 化约束

四份阶段文档的 slug 与未来 Skill 目录名保持一致。转化为 Skill 时：

1. 每个阶段建立同名目录和 `SKILL.md`，只包含该阶段的触发条件、核心工作流与门禁。
2. 本契约作为共享 reference，不复制到四个 `SKILL.md`。
3. schema、详细产物格式和安全说明放入直接引用的 `references/`；确定性且重复的检查才沉淀为 `scripts/`。
4. 每个 Skill 必须能识别“当前不属于本阶段”的请求，并停在正确阶段边界。
5. 阶段 0 的建议与导出即使未来属于同一个 Skill，也必须保持两个独立触发意图，禁止提供自动串联的 `all` 路径。
6. 阶段 3 采用最低自由度：固定命令、固定门禁、真实 TTY 确认和严格失败退出。
