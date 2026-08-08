# Apple Silicon Dotfiles 整改、迁移与 Intel Homebrew 退役实施计划

> 状态：已确认的实施级规格（尚未实施）  
> 版本：1.0  
> 日期：2026-08-08  
> 适用目标：由 Intel Mac 迁移到 Apple Silicon 的当前 macOS 用户环境  
> 文档用途：交给实施 Agent 或人工维护者，按本文分阶段建立仓库、整改配置、迁移工具链并退役 Intel Homebrew。

## 1. 执行摘要

本项目最终建立三个配置层，并固定覆盖关系：

```text
公开候选仓库（public） < 公司私有仓库（company，可选） < 本机私有配置（local）
```

- 公开候选仓库先创建为私有仓库；完成整改、全历史密钥扫描和人工发布审查后，再由用户手工改为公开并采用 MIT License。
- 公司配置必须存放在公司批准的私有 Git 服务或组织中；不得默认推送到个人 GitHub，也不得保存密钥。
- 本机私有配置统一存放在 `~/.config/dotfiles/local/`，不进入 Git、不进入云同步，并拥有最高优先级。
- `~/.zprofile` 只承担登录环境职责；`~/.zshrc` 只承担交互体验职责；不管理 `~/.zshenv`，也不设置 `ZDOTDIR`。
- Homebrew 只使用 Apple Silicon 原生前缀 `/opt/homebrew`。Intel Homebrew 迁移完成后当天退役，不设置观察期。
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
- **退役**：已记录替代或明确淘汰后，卸载 Intel Homebrew，并按 reviewed manifest 处理其已确认程序文件；不等于递归删除 `/usr/local`。

## 3. 目标、非目标与成功状态

### 3.1 目标

1. 当前交互 shell、Homebrew、常用 CLI 和语言工具链全部以 `arm64` 原生方式运行。
2. 最终活动 PATH 不包含 Intel Homebrew 路径；公开运行时配置不提供 `/usr/local` 回退。
3. Zsh 启动文件边界清楚、模块化、幂等、可诊断，并且只有一次补全初始化。
4. 公开、公司、本地三层能独立安装、按固定顺序覆盖，并能诊断同名覆盖来源。
5. 新机器可通过 README 和 `install.sh` 安全地计划、应用、验证和回滚。
6. Brewfile 是人工维护的“期望状态”，不是未经审查的 `brew bundle dump` 快照。
7. mise 与 uv 使用明确版本，不使用 `latest`；项目配置可以覆盖全局默认。
8. 密钥不进入仓库、Git 历史、诊断输出或长期普通备份；旧 shell 历史中的疑似密钥完成轮换和定向清理。
9. Intel Homebrew 的公式、cask、服务和数据目录全部有明确处置状态，可用一条受保护命令正式退役，并能查询退役记录。
10. 公开前同时完成人工审查、本地/CI Gitleaks 全历史扫描和托管平台安全检查。

### 3.2 首期非目标

- 不迁移 macOS `defaults`、系统偏好、Apple ID、应用账号或 GUI 应用数据。
- 不在首期接管 `.gitconfig`、SSH、tmux、编辑器设置等其他 dotfiles；只做脱敏盘点并列入后续 backlog。
- 不备份整个 Intel Homebrew Cellar。
- 不自动安装 Mac App Store 应用；只生成本地盘点报告。
- 不自动删除 Homebrew 未管理的 `/usr/local` 内容，不执行 `rm -rf /usr/local`，也不整体 `chown` `/usr/local`。
- 不为回滚重新安装 Intel Homebrew。
- 不把公司仓库或本地层纳入 MIT License。

### 3.3 完成后的可观察状态

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
dotfiles homebrew retired    -> 能查询本次退役清单、替代关系和结果
```

## 4. 不可破坏的安全约束

1. `install.sh` 无参数运行只允许收集配置并生成计划，不得应用修改。
2. `./install.sh apply` 必须在实际变更前展示计划标识和 manifest；计划发生变化后必须重新确认。
3. `apply` 与 Intel 退役必须在原生 `arm64` 会话运行。Rosetta/x86_64 日常 shell 只警告，不加载 Intel 回退。
4. Intel 退役必须在真实 TTY 中展示清单，并由用户亲自输入精确确认短语；Agent、CI、管道输入和普通 `--yes` 都不得代替。
5. 任何 Git 更新只允许 `fetch` 和显式的 `pull --ff-only`；禁止自动 `reset`、`stash`、force checkout 或覆盖未提交修改。
6. 所有远程 URL 必须拒绝内嵌用户名、token 或密码；认证交给 SSH agent、Keychain 或托管平台 credential helper。
7. 公司仓库默认只提供声明式内容。任何公司 hook 都必须进入计划、显示路径与摘要并单独获批。
8. 日志、报告和 CI artifact 不得包含密钥值、Keychain 输出、完整环境变量或未脱敏的 shell 历史。
9. 本地明文密钥例外文件必须是 `0600`，父目录必须是 `0700`；公司仓库不得保存任何密钥。
10. 未归类的 Intel 程序、运行中服务、cask 或服务数据会阻止退役。
11. 性能数据只给建议，不作为强制门槛；语法、加载、架构、密钥、权限、备份和 manifest 正确性才是阻断项。

## 5. 仓库与本机目录模型

### 5.1 远程仓库

| 层 | 初始可见性 | 允许内容 | 禁止内容 |
|---|---|---|---|
| 公开候选仓库 | 私有，审查后可公开 | 通用 Zsh、Brewfile、mise/uv 策略、插件目录、安装/测试/文档 | 密钥、公司域名/路径/账号、机器专属路径 |
| 公司仓库 | 公司批准的私有服务 | 公司 CLI、路径、Brewfile、补全、非密钥环境配置 | API key、个人 GitHub 私有仓库兜底、未经批准的任意执行 |
| 本地层 | 无远程 | 机器路径、个人应用路径、插件选择、允许的明文密钥例外、迁移临时文件 | Git、云同步、公开报告 |

公开候选仓库最终公开时采用 MIT License。公司仓库和本地层保持私有且不受该许可证覆盖。

### 5.2 来源配置

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

- 首次运行必须询问个人仓库来源与公司仓库来源；公司来源允许输入 `skip`。
- 默认本地目录分别建议为 `~/.local/share/dotfiles/personal` 与 `~/.local/share/dotfiles/company`，但必须让用户确认或修改。
- `source` 可以是 Git URL 或已有本地路径。已有目录只验证，不删除、不重建；URL 对应目录不存在时才克隆。
- 运行脚本的当前仓库不得被静默当作个人仓库；仍需展示探测结果并让用户确认。
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
└── local/
    ├── zsh/
    │   ├── profile.d/                # login 层，本地最高优先级
    │   ├── pre.d/                    # Oh My Zsh/compinit 之前
    │   └── rc.d/                     # 普通交互层
    ├── macos/Brewfile                # 本机私有期望状态
    ├── mise/90-local.toml            # 本机工具版本覆盖
    ├── uv/                            # 本机 uv 策略或版本声明
    ├── plugins/selection.toml         # 本机插件选择
    └── inventory/                     # 本地参考清单，不含密钥

~/.local/state/dotfiles/
├── backups/<run-id>/
├── manifests/<run-id>/
├── reports/<run-id>/
├── retired-homebrew/<run-id>/
└── locks/

~/.local/state/zsh/
└── history
```

状态目录不得由安装器自动清理；只提供 `list` 和带预览、带确认的 `prune`。

## 6. 公开候选仓库目标结构

```text
dotfiles/
├── README.md                          # 完整中英双语；用户与 Agent 唯一入口
├── LICENSE                            # MIT
├── install.sh                         # /bin/zsh；无参数只配置并生成 plan
├── bin/
│   └── dotfiles                       # 日常管理命令，/bin/zsh
├── zsh/
│   ├── entrypoints/
│   │   ├── zprofile                   # ~/.zprofile 的薄入口
│   │   └── zshrc                      # ~/.zshrc 的薄入口
│   ├── lib/
│   │   ├── loader.zsh
│   │   ├── path.zsh
│   │   ├── diagnostics.zsh
│   │   └── reserved-names.zsh
│   ├── profile.d/
│   │   ├── 10-path.zsh
│   │   └── 20-environment.zsh
│   ├── pre.d/
│   │   ├── 10-oh-my-zsh.zsh
│   │   └── 20-completion-policy.zsh
│   ├── rc.d/
│   │   ├── 10-history.zsh
│   │   ├── 20-tools.zsh
│   │   ├── 30-aliases.zsh
│   │   ├── 40-functions.zsh
│   │   └── 90-wrappers.zsh
│   └── plugins/
│       ├── catalog.toml
│       └── revisions.toml
├── macos/
│   └── Brewfile
├── tooling/
│   ├── mise/10-public.toml
│   └── uv/
│       ├── uv.toml
│       └── python-versions.txt
├── schemas/
│   ├── sources.example.toml
│   ├── plugin-catalog.schema.md
│   └── manifest.schema.md
├── tests/
│   ├── fixtures/
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

不创建 `bootstrap.sh`，也不创建 `AGENTS.md`。README 必须完整描述 Agent 协议；`install.sh` 只负责执行。

## 7. 公司仓库契约

公司仓库建议只允许以下固定入口：

```text
company-dotfiles/
├── README.md
├── zsh/
│   ├── profile.d/*.zsh
│   ├── pre.d/*.zsh
│   └── rc.d/*.zsh
├── macos/Brewfile
├── mise/50-company.toml
├── plugins/catalog.toml              # 可选，公司插件扩展
├── diagnostics/rules.toml            # 不含密钥值
└── hooks/                             # 默认不执行
```

- 公司仓库缺失、未启用或暂时不可访问时，公开层和本地层仍必须可用。
- 已存在且此前验证过的公司 checkout 可继续加载；更新失败只警告，不阻塞公开层更新。
- 公司仓库的 Zsh 文件在 `apply/verify` 中出现语法错误时阻断；日常 shell 中加载失败时警告并降级。
- 公司 hook 不能仅因存在而执行。计划必须列出 hook 的 SHA-256、路径、用途和拟执行命令，并另行确认。

## 8. Zsh 启动文件职责与加载顺序

### 8.1 明确边界

| 文件 | 管理策略 | 职责 | 禁止事项 |
|---|---|---|---|
| `~/.zshenv` | 不管理，只审计 | 无 | 不设置 `ZDOTDIR`，不放 PATH、插件或密钥 |
| `~/.zprofile` | 指向公开薄入口 | login 环境、基础 PATH、需要被登录会话后代继承的非敏感变量 | 别名、补全、主题、交互 widget |
| `~/.zshrc` | 指向公开薄入口 | 交互历史、工具激活、补全、主题、插件、别名、函数、wrapper | 全局明文密钥、Intel 永久回退 |

`~/.zprofile` 和 `~/.zshrc` 应当是稳定 symlink，目标位于个人仓库；模块文件不得直接散落到 `$HOME`。

### 8.2 PATH 策略

- `.zprofile` 与 `.zshrc` 调用同一个幂等 PATH 模块。
- PATH 模块使用 Zsh `path` 数组和唯一化语义，避免多次 source 后重复。
- Apple Silicon Homebrew 只接受 `/opt/homebrew/bin` 与 `/opt/homebrew/sbin`。
- `~/.local/bin` 必须有且只出现一次，以容纳 uv 工具等用户级可执行文件。
- 不手写 NVM、pyenv、旧 pnpm、Bun curl installer 或 Intel Homebrew PATH。
- `apply/verify` 检查 PATH 每一项是否存在、是否重复、是否指向 `/usr/local` Homebrew 遗留。

### 8.3 `.zprofile` 顺序

```text
1. 加载公开 loader 与幂等 PATH
2. public/zsh/profile.d/*.zsh
3. company/zsh/profile.d/*.zsh（启用且可用时）
4. ~/.config/dotfiles/local/zsh/profile.d/*.zsh
```

所有目录按文件名前缀排序；覆盖顺序固定为 public < company < local。

### 8.4 `.zshrc` 顺序

```text
1. 检查交互模式与架构；Rosetta 只警告
2. 加载公开 loader、PATH 兜底与保留名称表
3. public/pre.d
4. company/pre.d
5. local/pre.d
6. 计算已确认的内置插件列表并仅 source 一次固定 revision 的 Oh My Zsh
7. public/rc.d
8. company/rc.d
9. local/rc.d
10. 外部 ZLE 插件激活；zsh-syntax-highlighting 必须最后加载
11. 记录模块来源，供诊断命令展示覆盖链
```

Oh My Zsh 负责唯一一次 `compinit`。公开配置不得再手动执行第二次 `compinit`。主题保持 `robbyrussell`，暂不引入 Powerlevel10k 或第二个插件管理器。

### 8.5 日常降级行为

- 可选公司层或本地目录不存在：静默跳过。
- 启用层文件加载失败：输出一条不含文件内容的简短警告，并继续提供公开基础 shell。
- `install.sh apply` 和 `verify`：同样错误必须阻断，不能以日常降级掩盖安装缺陷。
- 普通名称允许按三层覆盖；诊断必须能显示最终来源和覆盖链。
- loader、manifest、退役、安全 wrapper 等核心名称列为保留名称，公司层和本地层不得覆盖。

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
~/.config/dotfiles/local/zsh/rc.d/90-secrets.zsh
```

要求：

- 文件 `0600`，父目录 `0700`。
- 不进入 Git、iCloud、Dropbox 或任何未经明确批准的同步/备份目标；是否允许 Time Machine 收录必须单独决定。
- 诊断只检查存在性、权限和 symlink 目标，不读取或输出内容。

### 10.4 旧配置与历史清理

1. 本地扫描旧 `.zshrc/.zprofile` 和 `~/.zsh_history`。
2. 报告只含变量类别、文件、命中数和不可逆脱敏指纹，不含完整值。
3. 先把对应密钥录入 Keychain 并轮换；未轮换不得宣称修复完成。
4. 生成历史定向删除预览；用户确认后只删除命中记录，保留其他历史。
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
- 首次无参数 `install.sh` 或显式重新配置时逐项询问；选择保存在本地 `plugins/selection.toml`。
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
- 公开/公司全局片段默认只允许 `[tools]` 和经过审查的静态设置；`[env]`、hook、task、动态文件读取等可执行能力必须进入单独计划并获批，不能借 mise 绕过公司 hook 规则。

### 12.2 uv

- uv 是唯一 Python 管理器，移除 pyenv 和重复的 pipx/virtualenv 管理层。
- `tooling/uv/python-versions.txt` 写明确版本；实施时用 `uv python install <exact-version>`。
- 项目使用 `pyproject.toml`、`requires-python`、`.python-version` 和 `uv.lock` 覆盖全局默认。
- Python CLI 用 `uv tool install` 管理，并记录工具与 Python 版本。
- 不使用未经确认的自动“最新版本”升级；升级是显式维护任务。

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

- 三个文件都是人工维护的期望状态。
- `brew bundle dump` 只生成带时间戳的审计输入，不直接覆盖任何正式 Brewfile。
- 应用前检查重复 tap/formula/cask、层间冲突和 owner 归属。
- Homebrew 是滚动发布管理器，Brewfile 不设计 lockfile；需固定版本的语言运行时由 mise/uv 管理。
- `brew bundle cleanup` 默认只预览；不在通用 `apply` 中使用 `--force`。

### 13.2 cask、服务与 App Store

- cask 单独盘点：标记 ARM/Universal、明确保留的 Rosetta 应用、替代或淘汰；不删除应用数据。
- 原 Intel `brew services` 逐项记录服务名、状态和配置/数据路径。先停止旧服务，安装 ARM 版本，再由用户逐项确认是否启动并验证。
- `/usr/local/var`、`/usr/local/etc` 等服务数据按服务制定迁移步骤；未知或未确认目录阻止退役，通用命令不得递归删除。
- Mac App Store 应用只生成本地清单，不自动 `mas install`，不处理 Apple ID。

## 14. 安装器与日常命令接口

### 14.1 实现约束

- `install.sh` 与 `bin/dotfiles` 使用系统 `/bin/zsh` 和 macOS 内置工具。
- 引导阶段不得依赖 Homebrew、Bun、uv、Python、Node 或 jq。
- `sources.toml` 只接受本文定义的简单字段，解析器必须拒绝未知关键安全字段、重复 section 和无效路径。
- 所有写操作都有 lock、run-id、manifest 和明确退出码。

### 14.2 `install.sh`

```text
./install.sh                    # 交互配置 + 诊断 + 生成 plan；绝不 apply
./install.sh configure          # 重新配置来源和插件选择
./install.sh plan               # 重新生成计划
./install.sh apply              # 分阶段应用；退役前暂停并要求用户确认
./install.sh verify             # 正确性/安全性检查 + 性能建议
./install.sh rollback <run-id>  # 回滚可逆配置变更
```

`apply` 内部调用与独立命令相同的 Intel 退役逻辑；如果用户在退役确认处拒绝，前面已完成且验证通过的 ARM 配置保留，manifest 标记为“迁移完成、Intel 未退役”，可稍后单独重试。

### 14.3 `dotfiles`

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
dotfiles homebrew inventory-intel
dotfiles homebrew retire-intel           # 只预览
dotfiles homebrew retire-intel --apply   # 一句话正式退役，仍需精确 TTY 确认
dotfiles homebrew retired                # 查询已退役项目和替代记录
```

### 14.4 README 中的 Agent 协议

README 必须同时提供完整中文与完整英文正文，并使用相同章节编号、命令块和安全警告。Agent 流程固定为：

1. 完整阅读 README。
2. 检查架构、Git 工作区和来源配置。
3. 运行无参数 `./install.sh` 或 `plan`。
4. 把变更、风险、不可逆边界和阻断项报告给用户。
5. 获得用户确认后运行 `./install.sh apply`。
6. 到 Intel 退役节点必须暂停，让用户亲自在 TTY 输入精确短语。
7. 运行 `verify`，交付 manifest、报告和后续建议。

README 必须明确禁止 Agent 自动创建远程仓库、自动改仓库可见性、自动信任公司 hook、自动 force Git 或代替用户确认不可逆卸载。

## 15. Manifest、备份与回滚

### 15.1 每次 run 的产物

```text
~/.local/state/dotfiles/manifests/<run-id>/metadata.toml
~/.local/state/dotfiles/manifests/<run-id>/actions.tsv
~/.local/state/dotfiles/backups/<run-id>/...
~/.local/state/dotfiles/reports/<run-id>/plan.md
~/.local/state/dotfiles/reports/<run-id>/verify.md
```

`actions.tsv` 至少记录：顺序、动作类型、目标、修改前类型、修改前 SHA-256、备份相对路径、修改后 SHA-256、结果和回滚动作。报告不得写文件内容或密钥。

### 15.2 备份范围

应备份：

- 现有非敏感或已脱敏的 Zsh 配置。
- symlink 目标、权限、owner 和哈希。
- PATH/命令解析与架构报告。
- Intel/ARM Homebrew 的 formula、leaves、cask、tap、services、Brewfile 审计快照。
- NVM/npm 全局包、pyenv/Python、pipx/uv tool、Bun/pnpm/Go 等清单。
- 迁移账本和 Intel 替代映射。

不得进入普通备份：

- Keychain 值、完整环境变量、密钥字面值。
- 整个 Cellar。
- 未脱敏 shell 历史；历史只允许按第 10.4 节短期本地隔离。

### 15.3 回滚边界

- 在 Intel 退役前：可回滚 symlink、模块、来源、插件选择和多数配置。
- 密钥轮换、明文密钥清除不可恢复；回滚只能继续使用 Keychain wrapper。
- Homebrew 新增包默认不由 rollback 自动卸载，只生成 cleanup 预览，避免删除其他项目正在使用的依赖。
- Intel Homebrew 退役后：不恢复 `/usr/local` Homebrew；只修复/重装 ARM 替代项。
- 服务数据迁移按具体服务的 runbook 回滚，不由通用脚本猜测。

## 16. 临时 Intel 兼容文件

如果迁移过程中确实需要短时调用尚未替代的 Intel 命令，只允许创建：

```text
~/.config/dotfiles/local/zsh/pre.d/10-intel-homebrew-migration.zsh
```

要求：

- 文件带醒目的 `migration-only` 注释、创建 run-id 和自动失效检查。
- 只包含已盘点的最小路径或 wrapper，不得把整个 `/usr/local/bin` 永久置于 ARM Homebrew 之前。
- 公开 `.zprofile/.zshrc` 只负责通用目录加载，不出现 Intel 专属修改。
- 当替代验证完成时，退役流程按 manifest 删除该临时文件；最终 Zsh 入口无需大量修改。
- 如果迁移在退役前中止，`dotfiles status` 必须醒目标记该文件仍启用。

## 17. Intel Homebrew 盘点与退役

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
- `retired_by_choice`：用户确认不再需要。
- `unresolved`：未处理；会阻止退役。

### 17.2 服务与数据

运行中服务必须经过：

```text
记录状态 -> 识别配置/数据 -> 备份或迁移 -> 停止 Intel 服务 ->
安装 ARM 服务 -> 用户确认启动 -> 验证状态/端口/数据 -> 标记完成
```

未知的 `/usr/local/var`、`/usr/local/etc` 内容不得由通用退役命令删除。

### 17.3 一句话退役命令

预览：

```zsh
dotfiles homebrew retire-intel
```

正式执行：

```zsh
dotfiles homebrew retire-intel --apply
```

正式命令必须：

1. 验证当前进程是 `arm64`、ARM Homebrew 健康、所有旧项已归类。
2. 再次验证 ARM 替代命令的路径、架构和版本输出。
3. 验证所有运行中服务和 cask 已处理，服务数据不存在未知项。
4. 显示官方卸载将影响的路径和 reviewed manifest。
5. 要求用户在真实 TTY 输入精确确认短语。
6. 使用 Homebrew 官方卸载机制处理 `/usr/local` 前缀；实施时固定并记录官方脚本来源 revision/哈希，先下载审查，不使用不透明的 `curl | shell`。
7. 只对 manifest 中已确认的遗留程序文件执行后续处理；不递归删除 `/usr/local`。
8. 移除临时 Intel 兼容文件，刷新命令哈希并启动干净 login/interactive shell 验证。
9. 把每个项目的旧路径/架构、替代路径/架构、处置状态、时间和执行结果写入 `retired-homebrew/<run-id>/`。

查询记录：

```zsh
dotfiles homebrew retired
```

退役是不可逆边界。命令成功后，rollback 不得自动重新安装 Intel Homebrew。

## 18. 分阶段实施顺序

### 阶段 0：准备仓库与权限边界

前置条件：

- 用户自行创建或指定一个已存在的个人私有远程仓库；安装器不得自动创建远程仓库。
- 用户提供个人仓库 URL/本地路径；公司仓库提供获批 URL/路径或选择 `skip`。
- 初次创建代码由实施 Agent 在明确目录中完成；新机器安装则先手工 clone 个人仓库，再运行 README 中的流程。

产物：来源配置草案、仓库 origin/权限检查报告、公司层启用状态。

### 阶段 1：只读盘点

收集并脱敏记录：

- `uname -m`、`arch`、shell 路径和 Rosetta 状态。
- `.zshenv/.zprofile/.zshrc`、所有 source 链、PATH、重复 compinit、插件和环境变量名称。
- `command -v`/`type -a`/二进制架构。
- Intel 与 ARM Homebrew 的 formula、leaves、taps、casks、services 和数据目录。
- NVM/npm、pyenv/Python、pipx/uv、Bun/pnpm、Go、mise inventories。
- Keychain 外的疑似密钥和 shell 历史命中（仅脱敏元数据）。
- Mac App Store 应用和其他 dotfiles 的脱敏 backlog。

产物：`inventory.md`、命令解析表、密钥轮换清单、Intel 退役账本初稿。

### 阶段 2：实现并测试公开/公司契约

- 建立本文目录结构、README 中英文、MIT License、安装器、loader、插件目录、测试和 CI。
- 为当前旧 Zsh 配置建立逐项迁移账本：原位置、用途、目标层/模块、保留/改写/限定/Keychain/淘汰、验证方法。
- 未解释的有效配置不得进入切换。
- 使用 fixture 在隔离 HOME 中完成 plan/apply/再次 apply/rollback 测试。

产物：可审查的仓库提交、迁移账本、测试报告。

### 阶段 3：密钥迁移与安全清理

- 把需保留密钥录入 Keychain，建立 wrapper。
- 轮换曾出现在文件、历史或 Git 中的密钥。
- 清理旧配置中的明文值；定向清理历史。
- 安装原生 Git pre-commit hook 和固定版本 Gitleaks。

产物：脱敏扫描报告、轮换状态、历史清理 manifest。报告不得包含值。

### 阶段 4：ARM 工具链与配置切换

- 完善 ARM Brewfile，安装缺失 ARM 工具。
- 配置 mise 分层与固定版本；迁移 Bun/Node/pnpm/Go。
- 配置 uv 并迁移 Python 版本、venv/tool 所有权。
- 安装固定 revision 的 Oh My Zsh/插件。
- 导入 autojump 数据到 zoxide，验证后标记 autojump 可淘汰。
- 部署 `~/.zprofile`、`~/.zshrc` symlink；必要时启用唯一的临时 Intel 兼容文件。

产物：apply manifest、ARM 命令矩阵、配置加载报告。

### 阶段 5：服务、cask 与最终替代验证

- 迁移运行中服务及其数据。
- 逐项接管 cask，标记 ARM/Universal/Rosetta/替代/淘汰。
- 让 Intel 账本中所有条目离开 `unresolved`。
- 在干净 login shell 和 IDE 风格非-login 交互 shell 中验证 PATH 和工具。

产物：最终退役预览、服务验证、cask 分类表。

### 阶段 6：当天退役 Intel Homebrew

- `./install.sh apply` 到最后阶段暂停。
- 用户查看最终清单并亲自输入精确短语。
- 内部调用 `dotfiles homebrew retire-intel --apply`。
- 不设置观察天数；成功后立即进入最终验证。

产物：官方卸载记录、manifest、retired inventory、残留 `/usr/local` 审计。

### 阶段 7：最终验收与公开准备

- 运行全部本机验证、Gitleaks、Git 历史扫描和 CI。
- 验证临时 Intel 文件已移除，活动 PATH 无 Intel Homebrew。
- 生成公开 allowlist/denylist 和发布报告。
- 用户单独确认后，手工把个人候选仓库改为公开；脚本不自动修改可见性。

## 19. 检查与验收矩阵

### 19.1 阻断检查

| 类别 | 必须验证 |
|---|---|
| Zsh 语法 | 所有启用 `.zsh` 文件通过 `zsh -n` |
| 启动 | 隔离 HOME 与真实 HOME 的 login/interactive/non-login 交互场景正常退出 |
| 架构 | apply/retire 为 arm64；brew 和替代二进制不是 x86_64-only |
| PATH | 去重、优先级正确、最终无活动 Intel Homebrew 路径 |
| 补全 | Oh My Zsh/compinit 只初始化一次；缓存权限和路径正常 |
| 分层 | public < company < local；公司 skip 可用；覆盖链可诊断 |
| 保留名称 | 公司/本地层不能覆盖核心安全接口 |
| 密钥 | 暂存区、当前提交、完整历史通过固定版本 Gitleaks；本地权限正确 |
| Git | 工作区状态已报告；更新只 fast-forward；URL 不嵌入凭据 |
| 备份 | manifest、哈希、备份目标与回滚动作完整 |
| Intel | 每项已归类；服务、cask、数据已确认；替代命令架构验证通过 |

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
- CI 覆盖 Zsh 语法、目录 schema、插件 revision、Brewfile 语法/重复项、隔离 HOME、plan/apply/幂等/rollback、manifest、README 双语结构和 Gitleaks。
- CI 不安装全部 cask、不改真实系统偏好、不访问真实公司服务、不读取真实 Keychain、不执行真实 Intel 卸载。
- ShellCheck 只检查真正使用 `sh/bash/dash/ksh` 的脚本；不得用 Bash 方言误检 Zsh。若仓库全为 Zsh，则不运行 ShellCheck。

## 20. 密钥扫描与 Git 防护

- 使用固定版本 Gitleaks，而不是只依赖 GitHub。
- `.githooks/pre-commit` 跟踪在仓库中；用户确认后设置仓库本地 `core.hooksPath=.githooks`。
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
8. 所有 CI 是否通过，本机最终 ARM 验收是否通过。

通过后也只能建议发布；仓库可见性必须由用户手工修改。

## 22. 实施时待填数据（不是设计分歧）

以下信息应在阶段 0/1 由用户或只读盘点提供，不允许硬编码假设：

- 个人仓库 URL/本地路径。
- 公司仓库 URL/本地路径或 `skip`。
- 实际 Brew formula/cask/service 清单。
- mise、uv、Bun、Node、pnpm、Go 的精确目标版本。
- 每个 API key 的变量名、消费命令和是否支持单命令 wrapper；不记录值。
- 服务数据迁移步骤和验证命令。
- 旧 `.zshrc` 每条有效配置的迁移归类。
- 最终插件 revision 与 Gitleaks 固定版本。
- GitHub/公司 CI 的实际 runner 标签与权限。

这些数据缺失时可以完成代码骨架和只读 plan，但不得假装完成迁移或 Intel 退役。

## 23. 主要风险与缓解

| 风险 | 缓解 |
|---|---|
| 删除 Intel Homebrew 后遗漏命令 | 每项强制归类；替代路径和架构实际执行验证 |
| `/usr/local` 中混有非 Homebrew 数据 | 官方卸载 + reviewed manifest；未知目录保留并报告 |
| 数据库/服务中断 | 服务与数据单独 runbook，用户逐项确认启动 |
| 旧明文密钥进入备份或日志 | 先脱敏/轮换；普通备份禁存值；历史仅短期隔离 |
| 公司层故障导致 shell 不可用 | 安装严格、日常降级；公开层独立可用 |
| 双语 README 漂移 | 相同章节编号/命令块；CI 做结构检查，发布清单做语义复核 |
| 插件上游变化或供应链风险 | 固定 revision、关闭自动更新、显式差异审查 |
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
| 配置中出现 `/usr/local` Homebrew 路径 | Apple Silicon 公共运行时只使用 `/opt/homebrew`；Intel 兼容仅存在于可一次移除的本地临时文件 |
| 主要逻辑集中在单个 `.zshrc` | 拆分 `.zprofile` login 职责、`.zshrc` 交互职责和生命周期模块；不管理 `.zshenv` |
| 用被忽略的单个私有命令文件承载非公开内容 | 明确 public/company/local 三层及 profile/pre/rc 三个加载阶段，且能诊断覆盖来源 |
| 安装流程可能直接删除或替换已有文件 | 默认 plan、显式 apply、备份、哈希、manifest、幂等和 rollback；禁止无清单删除 |
| Brewfile dump 容易变成未经审查的机器快照 | dump 只作审计输入；正式 Brewfile 分层并人工维护，cleanup 默认只预览 |
| pyenv、NVM、mise 等职责可能重叠 | mise 独占 Bun/Node/pnpm/Go/固定版本跨项目 CLI，uv 独占 Python，移除 NVM/pyenv |
| 插件只有名称或 clone 行为 | 独立 catalog 记录痛点、理由、依赖、风险、加载阶段和固定 revision，安装时逐项询问 |
| 私有环境变量可能通过 shell 文件全局 export | 默认 Keychain + 单命令 wrapper；公司仓库无密钥，本地明文仅为权限受控例外 |
| 仓库更新和插件更新跟随上游当前状态 | Git 只允许显式 fast-forward；OMZ/插件/Gitleaks 固定 revision/version 并经测试升级 |
| 未覆盖 Intel Homebrew 完整退役 | 建立 formula/cask/service/data 账本、替代验证、一句话受保护退役及可查询记录 |

因此，这不是对参考仓库的风格复制，而是保留其“仓库化、Brewfile、OMZ、symlink”优点，同时补齐 Apple Silicon 原生化、职责边界、分层私密性、供应链固定、可回滚安装和不可逆退役控制。

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
- [zsh-syntax-highlighting 加载要求](https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/INSTALL.md)
- [ShellCheck 不支持 Zsh](https://www.shellcheck.net/wiki/SC1103)
- [GitHub 托管 runner](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
- [GitHub secret scanning 范围](https://docs.github.com/en/code-security/reference/secret-security/secret-scanning-scope)
- [Gitleaks](https://github.com/gitleaks/gitleaks)

## 26. 最终验收清单

- [ ] 个人候选仓库仍为私有，来源和路径由用户确认；公司层可 `skip`。
- [ ] README 为完整中英双语且是唯一 Agent 入口；不存在 `bootstrap.sh` 或 `AGENTS.md`。
- [ ] `.zshenv` 未被接管；`.zprofile/.zshrc` 职责和加载顺序符合本文。
- [ ] public < company < local 覆盖正确，保留名称无法被覆盖。
- [ ] ARM Homebrew、mise、uv、Bun、Node、pnpm、Go 所有权无重叠。
- [ ] Oh My Zsh/插件固定 revision，只有一次 compinit，语法高亮最后加载。
- [ ] API key 已进入 Keychain wrapper 或获批本地例外；无全局明文 export。
- [ ] 历史策略安全，旧历史命中已轮换并定向清理。
- [ ] 三层 Brewfile 人工审查通过；Mac App Store 仅盘点。
- [ ] 所有 Intel formula/cask/service/data 已归类且替代验证完成。
- [ ] `./install.sh apply` 在退役处要求用户精确 TTY 确认。
- [ ] `dotfiles homebrew retire-intel --apply` 成功，且 `retired` 可查询记录。
- [ ] 临时 Intel 兼容文件已移除，最终活动 PATH 无 Intel Homebrew。
- [ ] 真实 ARM 本机验证、隔离 HOME 测试、CI 和 Gitleaks 全历史扫描通过。
- [ ] 备份/manifest 可审计；密钥清除和 Intel 退役的不可逆边界已记录。
- [ ] 公开发布报告通过，并由用户单独手工决定是否公开。
