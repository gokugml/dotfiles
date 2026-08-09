# Stage 1：可移植 Dotfiles 能力建设需求

> 状态：实施级阶段需求<br>
> 版本：1.0<br>
> 日期：2026-08-09<br>
> 执行角色：仓库维护者与实施 Agent<br>
> 执行位置：阶段 0 由用户指定的 public/company Git checkout

## 1. 阶段定位

本阶段把源机器阶段 0 产生的候选配置和审批结论，建设为可供多台目标机器复用的 Dotfiles 产品能力。交付物不仅包含配置文件，还必须包含安装、计划、验证、回滚、Intel→ARM 迁移、退役保护、schema、fixture、测试、双语文档和安全发布门禁。

执行前必须阅读 [四阶段共用契约](./stage-common-contract.md) 和 [Stage 0：源机器分析与配置导出](./stage-0-source-machine-analysis-and-export.md)。本阶段不得重新解释共用目录、Zsh、工具所有权、命令职责或不可代理边界。

下一阶段：[Stage 2：目标机器配置与软件迁移](./stage-2-target-machine-configuration-and-software-migration.md)。

## 2. 阶段目标

1. 只消费阶段 0 两次预审批后为 `accept/revise` 的候选内容。
2. 把源机器特征收敛为可移植默认、分层 schema 和目标机器可配置项。
3. 建立 public 真实 Zsh 入口、Brewfile、mise/uv 策略和插件 catalog。
4. 实现配置安装器的 plan/apply/verify/rollback 自闭环。
5. 实现独立 Intel→ARM 迁移脚本及阶段 3 的唯一退役入口。
6. 定义并验证 company 仓库契约，同时保证 company=`skip` 时 public/local 独立可用。
7. 在隔离 HOME 和 fixture 中证明目标机器无需手工复刻即可安全执行阶段 2/3。
8. 通过密钥扫描、CI 和发布预审批，形成可提交、可审查的仓库能力。

## 3. 非目标

- 不修改开发者真实 `~/.zprofile`、`~/.zshrc`、Homebrew 或语言工具链。
- 不在真实机器安装、迁移或卸载软件。
- 不把阶段 0 工作树整体原样提交。
- 不创建远程仓库，不自动 push，不修改仓库可见性。
- 不等待任意用户先完成阶段 2/3 才发布仓库能力。
- 不把公司或 local-only 内容纳入 MIT License。
- 不迁移 macOS `defaults`、Apple ID、GUI 应用数据、`.gitconfig`、SSH、tmux 或编辑器设置。

## 4. 前置门禁

开始实施前必须验证同一阶段 0 `run_id` 的以下输入：

- `zsh-recommendations.md` 与 `zsh-best-practices.md`。
- `recommendation-decisions.tsv` 完整覆盖 Zsh 建议 ID。
- `destination-map.toml` 包含固定 local-only 根和用户选择的 public/company 目的地。
- `export-report.md` 与 `export-best-practices.md`。
- `stage0-candidate/v8` 候选文件。
- `files.tsv` 与 `file-decisions.tsv`。
- 第二次预审批决策。
- 唯一的 `stage0-summary.sha256`。

下列任一情况必须拒绝进入实施：

- 两次预审批被合并或缺少其中一次。
- `run_id`、建议 ID、候选路径或目的地不一致。
- 阶段 0 整体摘要验证失败。
- 候选已 stale、格式不兼容、验证失败或不在固定/用户选择的目的地。
- public 候选仍含公司、本机或敏感信息。
- 对应决策为 `reject/defer`。

仓库建设只能操作所选工作树、临时目录和隔离 HOME。

## 5. 阶段流程

```text
1A 验证输入、仓库和权限边界
  → 1B 落库获准候选并补齐产品能力
    → 1C 在隔离环境验证完整闭环
      → 1D 安全扫描、提交与发布预审批
```

只有本阶段可以根据阶段 0 预审批结果执行 `git add/commit`。远程 push 和仓库可见性修改仍属于用户授权边界。

## 6. 子阶段 1A：仓库和权限边界

### 6.1 Public 目标验证

- 使用 `destination-map.toml` 中用户选择的 checkout 和仓库内根，不得改选其他仓库。
- 验证 Git root、origin、工作树状态、权限、历史敏感信息和相对路径边界。
- 如果需要新建远程仓库，必须停止并由用户自行创建/授权后重新选择。
- public 候选仓库初始保持私有；通过发布关卡后才可建议用户手工公开。

### 6.2 Company 目标验证

- 只有用户在阶段 0 显式选择 `skip` 时才跳过实际 company 输出。
- company=`write` 时，只在已授权 checkout 和指定相对根中工作。
- 暂时不可访问不能自动改成 `skip`；应报告阻塞或“待同步”状态。
- public 仓库无论如何都必须交付 company schema、脱敏 fixture 和兼容测试。

### 6.3 实施边界冻结

在写入前固定：

- public 两个真实 Zsh 入口和 OMZ 模板 revision。
- company/local 的 profile/pre/rc 固定 source 点。
- 工具管理器职责和精确版本策略。
- manifest/schema 版本。
- `install.sh` 与迁移脚本的职责分离。
- 阶段 3 不可逆确认边界。

## 7. 子阶段 1B：Public 仓库实现

### 7.1 目标结构

在用户选择的 public 仓库内根建立：

```text
dotfiles/
├── README.md
├── LICENSE
├── install.sh
├── bin/
│   └── dotfiles
├── zsh/
│   ├── .zprofile
│   ├── .zshrc
│   └── plugins/
│       ├── catalog.toml
│       └── revisions.toml
├── scripts/
│   └── migrate-intel-homebrew-to-arm.sh
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
│   ├── fixtures/company-repo/
│   ├── syntax.zsh
│   ├── isolated-home.zsh
│   ├── idempotence.zsh
│   ├── rollback.zsh
│   └── homebrew-retirement-fixture.zsh
├── .githooks/pre-commit
└── .github/workflows/verify.yml
```

不创建 `bootstrap.sh`、`AGENTS.md`、public Zsh loader 或阶段目录分片。

### 7.2 候选落库规则

- `accept`：按候选目标路径落库并重新验证。
- `revise`：按第二次预审批意见改写，再执行语法、schema、归属、敏感信息和最佳实践验证。
- `reject/defer`：不得落库。
- 候选契约需要变化时，先版本化契约，将受影响候选标记为 `revise` 并重新生成/验证；不得静默转换旧版本。
- 每个最终文件都必须回写 `files.tsv` 的 `final_path` 和 `final_commit`，保持 `run_id → recommendation_id → 两次审批 → 最终 Git commit` 追溯。

### 7.3 Zsh 入口

实现必须完全遵循共用契约的真实入口、加载顺序和 ARM-only 运行时要求，并额外满足：

- `.zprofile` 是最小、线性、可直接阅读的 login 入口，不伪造 OMZ 模板。
- `.zshrc` 对照固定 revision 的官方模板；只允许预审批值变更、Intel 路径示例删除和固定标记受管区块。
- company/local 文件不存在时可用，存在且错误时 apply/verify 阻断。
- 主题首期保持官方模板默认 `robbyrussell`，不引入第二个插件管理器。
- 首期默认插件及选择必须由 catalog 表达；外部插件固定 revision，关闭自动更新。

### 7.4 软件期望状态

- public Brewfile 只包含可移植且获准的直接期望项，按稳定顺序保存结构化注释。
- mise/uv/Bun/Node/pnpm/Go/Python 所有权符合共用契约。
- mise 配置只写明确版本和经预审批的静态设置；动态 `[env]`、hook、task 或文件读取需要独立计划和授权。
- uv 使用明确 Python 版本和受支持用户配置；不混入项目依赖、本机缓存或绝对路径。
- 插件 catalog 必须包含用途、痛点、来源、revision、安装所有者、依赖、激活阶段、加载顺序、冲突、安全/性能说明和卸载步骤。

## 8. 配置安装器需求

`install.sh` 和 `bin/dotfiles` 使用系统 `/bin/zsh` 与 macOS 内置工具。引导阶段不得依赖 Homebrew、Bun、uv、Python、Node 或 jq。所有写操作必须有 lock、run-id、manifest 和明确退出码。

### 8.1 `install.sh`

必须实现共用契约定义的命令，并满足：

- 无参数首次运行收集来源和插件选择，只读诊断并生成计划。
- `configure` 重新配置来源和选择，不应用变更。
- `plan` 可重复生成同等输入对应的配置计划。
- `apply` 只做备份、两个真实入口 symlink、company 稳定 symlink、私有分层配置，以及固定 revision 的 Oh My Zsh/插件配置依赖。
- `verify` 检查配置正确性、安全和性能建议。
- `rollback <run-id>` 只回滚可逆配置。
- `apply` 可以配置仓库跟踪的 pre-commit hook，但不得通过包管理器安装 Gitleaks；Gitleaks 二进制属于后续软件迁移计划。
- `apply` 完成后 manifest 明确写入“本地配置完成，Intel→ARM 迁移未由本命令执行”。
- 代码中不存在调用迁移脚本、Homebrew 写操作或自动进入阶段 3 的路径。

### 8.2 来源 schema

`sources.toml` 至少支持：

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

解析器必须拒绝未知关键安全字段、重复 section、无效路径和内嵌认证信息。现有 checkout 只验证；URL 对应目录不存在时才允许 clone。

### 8.3 `bin/dotfiles`

至少提供：

```text
dotfiles status
dotfiles diagnose [--performance]
dotfiles verify
dotfiles sources status
dotfiles sources update
dotfiles sources update --apply
dotfiles plugins status|plan-update
dotfiles backup list
dotfiles backup prune [--apply]
```

`sources update` 默认只 fetch 和报告差异；`--apply` 只允许 fast-forward。日常命令可以显示最近迁移状态，但不得提供 Homebrew 写入或退役别名。

## 9. 独立迁移脚本需求

`scripts/migrate-intel-homebrew-to-arm.sh` 必须：

- 以模式 `0755` 纳入仓库。
- 使用自身绝对路径推导仓库根，不假设 checkout 位于固定目录。
- 实现共用契约定义的 plan/apply/verify/retire/status 接口。
- 使用独立 migration run-id、状态目录、inventory、actions 和 retirement ledger。
- 只在写模式验证当前进程为原生 `arm64`；非 `arm64` 无变更退出。
- 普通 `--apply` 安装 ARM 替代项并执行已授权服务/数据 runbook，但不卸载 Intel Homebrew。
- `--retire --apply` 只接受同机、同 migration run-id 的已验证账本，并实施真实 TTY 精确确认。
- 不把 Intel 旧前缀写入 Zsh、最终 Brewfile、配置 apply manifest 或普通安装文档示例。
- 不允许 `install.sh` 或 `bin/dotfiles` 复制、包装或调用其写逻辑。

退役账本至少表达：旧项目类型/名称/路径/架构/版本、所有者、目标状态、替代名称/管理器/路径/架构、验证命令、服务或数据说明和状态。目标状态只允许 `arm_replaced`、`renamed_replacement`、`managed_elsewhere`、`retired_by_choice`、`unresolved`。

## 10. Company 仓库契约

建议的声明式结构：

```text
company-dotfiles/
├── README.md
├── zsh/{profile,pre,rc}.zsh
├── macos/Brewfile
├── mise/50-company.toml
├── plugins/catalog.toml
├── diagnostics/rules.toml
└── hooks/                             # 默认不执行
```

要求：

- 两个 public 真实入口、安装器、安全接口和迁移脚本只存在于 public 仓库。
- company 不复制 public 入口，不创建第二套 loader。
- 真实公司名、域名、账号、路径和插件来源只进入获授权的 company checkout。
- company hook 仅因存在不得执行；必须展示路径、用途、命令和 SHA-256 并单独授权。
- company 不可访问时，已验证的 public/local 仍可用；报告必须如实区分“schema 已完成”“实际同步待完成”和 `skip`。

## 11. README 与 Agent 协议

README 必须提供完整中文和完整英文正文，并保持相同章节编号、命令块和安全警告。它是用户和 Agent 的唯一仓库入口，必须明确：

1. 四个阶段及其门禁。
2. 阶段 0 的建议与导出不可合并。
3. 阶段 2 必须先从无参数 `install.sh` 或 `plan` 开始。
4. `install.sh apply` 完成配置后停止，不自动运行迁移。
5. 只有用户要求迁移时才运行迁移脚本普通 plan/`--apply`/`--verify`。
6. 普通迁移完成后仍停在阶段 2。
7. 只有用户另行进入阶段 3 时才执行 `--retire` 预览。
8. 正式退役只能由用户在真实 TTY 执行 `--retire --apply`。
9. Agent 不得自动创建远程仓库、改变可见性、push、信任 hook、force Git 或代理不可逆确认。

## 12. 子阶段 1C：隔离验证

必须使用临时 HOME、mock 和 fixture 验证：

- 所有 Zsh 文件语法。
- 两个真实入口的 login/interactive/non-login interactive 启动。
- OMZ 模板骨架、受管区块、固定 source 点、覆盖顺序和唯一 `compinit`。
- company 启用、company=`skip` 和 company 文件故障降级。
- `install.sh` plan/apply/再次 apply 幂等/verify/rollback。
- sources schema、路径越界、冲突和安全 URL 拒绝。
- Brewfile/TOML/plugin schema、明确版本和工具所有权。
- 配置 run-id 与 migration run-id 隔离。
- 迁移脚本 plan/apply/verify/retire/status 的 fixture 行为。
- 非 `arm64` 写模式无变更失败。
- 正式退役无法被 CI、管道或普通 yes 绕过。

测试不得触碰开发者真实 HOME、Keychain、公司服务或 Homebrew，不安装完整 cask，也不执行真实 Intel 卸载。

ShellCheck 只用于其支持的 shell；不得用它检查 Zsh。所有验证逻辑必须可由本地命令调用，不能只存在于 CI YAML。

## 13. 子阶段 1D：安全、提交与发布门禁

### 13.1 安全扫描

- 固定版本 Gitleaks 检查 tracked、untracked、ignored、暂存区、当前提交、所有 branch/tag 和完整历史。
- `.githooks/pre-commit` 被仓库跟踪；Gitleaks 缺失或报错时 fail closed。
- allowlist 必须精确到规则、路径或指纹，并记录误报理由和复核日期。
- 如果历史曾含真实密钥或公司内容，必须先轮换，再重写历史或新建干净仓库并重新扫描。

### 13.2 CI

CI 至少覆盖本阶段第 12 节全部隔离验证，以及：

- `stage0-candidate/v8` schema 与追溯链。
- README 中英结构一致性。
- public/company 边界和无 Intel 运行时路径。
- 已落库路径不存在 `defer/unresolved`。
- Gitleaks 完整历史扫描。

个人仓库使用实施时核实可用的明确版本 ARM macOS 托管 runner，不使用个人 self-hosted runner。公司 CI 未配置时如实标记缺失，但仍运行本地契约验证。

### 13.3 提交与发布

- 只 stage/commit 本阶段已验证且有 `accept/revise` 追溯的文件。
- 提交后用 Git commit ID 填充阶段 0 追溯表。
- 发布报告必须说明实际 company 同步状态，不得声称任意目标机器已完成迁移或退役。
- MIT License 只覆盖 public 内容。
- 公开发布不依赖阶段 2/3 完成。
- 通过发布门禁后只建议用户手工改变可见性；脚本不得代办。

## 14. 阶段产物

- 用户选择的 public 仓库内完整可移植 Dotfiles 文件集。
- company schema、脱敏 fixture、兼容测试和同步说明。
- 如已授权，用户指定 company checkout 中的声明式文件集。
- 阶段 0 候选到最终 Git commit 的追溯表。
- 隔离 HOME、幂等、rollback 和迁移 fixture 测试报告。
- CI、Gitleaks 全历史扫描和 Agent 发布预审批报告。
- 固定的 Oh My Zsh、插件、Gitleaks 和工具版本/revision。

## 15. 完成条件

- [ ] 阶段 0 输入、两次审批和唯一整体摘要通过验证。
- [ ] 只落库 `accept/revise`，`revise` 已重验，`reject/defer` 未落库。
- [ ] public 目录、两个真实 Zsh 入口、Brewfile、工具配置、schema、测试和 CI 完整。
- [ ] README 中英正文和 Agent 协议完整同步。
- [ ] `install.sh` 配置闭环通过，且不含 Homebrew 写操作或迁移调用。
- [ ] 独立迁移脚本提供完整阶段 2/3 接口并以 `0755` 纳入仓库。
- [ ] company 启用和 `skip` 两条路径都通过验证，实际同步状态如实记录。
- [ ] 临时 HOME 的 syntax/plan/apply/幂等/verify/rollback 全部通过。
- [ ] 迁移与退役 fixture 覆盖阻断和真实 TTY 防护，不触碰真实系统。
- [ ] 每个阶段 0 最终文件可追溯到 run-id、建议 ID、两次预审批和 Git commit。
- [ ] 固定版本 Gitleaks、完整历史扫描和 CI 通过。
- [ ] 未修改真实 HOME/Homebrew，未自动 push 或改变仓库可见性。

完成状态必须表述为“可移植仓库能力已交付并通过隔离验证”，不得表述为“用户机器已经迁移”。

## 16. 未来 Skill 接口

未来 Skill 名：`stage-1-portable-dotfiles-capability-build`。

推荐触发语义：基于阶段 0 已预审批候选，建设或更新可复用 Dotfiles 仓库能力。Skill 必须先验证阶段 0 门禁；输入不完整时只报告缺口，不得从源机器重新猜测配置，也不得进入真实目标机器执行阶段 2。

Skill 的程序性主体保留在 `SKILL.md`；详细 public/company schema、fixture 规则和验收矩阵适合放入直接引用的 `references/`；可重复的 schema、隔离 HOME 和安全检查适合沉淀为确定性 `scripts/`。
