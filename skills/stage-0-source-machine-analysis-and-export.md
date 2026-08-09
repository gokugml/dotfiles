# Stage 0：源机器分析与配置导出需求

> 状态：实施级阶段需求<br>
> 版本：1.0<br>
> 日期：2026-08-09<br>
> 执行角色：仓库维护者与实施 Agent<br>
> 执行位置：提供现有工作环境的源机器

## 1. 阶段定位

本阶段从源机器提取可验证证据，先独立提出 Zsh 整改建议并完成第一次 Agent 预审批，再由新的显式操作把获准建议及机器软件现状整理为阶段 1 可消费的候选配置。

执行前必须阅读 [四阶段共用契约](./stage-common-contract.md) 和 [Zsh 配置诊断与优化指南](./zshrc-diagnostics-guide.md)。共用术语、分层、目录、安全、审批和 Git 约束以共用契约为准，本文件不重复定义。

下一阶段：[Stage 1：可移植 Dotfiles 能力建设](./stage-1-portable-dotfiles-capability-build.md)。

## 2. 阶段目标

1. 脱敏盘点当前 Zsh 启动文件及完整 source 链，识别真实功能、问题、命令来源和迁移归属。
2. 为每个 Zsh 项生成稳定、可验证的修改建议，而不是直接修改当前配置。
3. 对 Zsh 建议完成第一次 Agent 预审批，明确哪些建议允许进入配置导出。
4. 由用户一次性指定 public/company 输出目的地；local-only 使用共用契约的固定目录。
5. 单独盘点并整理 Brewfile、Homebrew 项目、mise、uv、插件和关键软件配置。
6. 把不同来源统一转换为 `stage0-candidate/v8` 目标格式，避免另一台机器人工复刻源机器。
7. 对候选文件完成第二次 Agent 预审批，建立到阶段 1 的完整追溯链。

## 3. 非目标

- 不修改真实 `~/.zprofile`、`~/.zshrc` 或其 symlink。
- 不安装、升级、迁移或卸载任何软件。
- 不把源机器完整复制为另一台机器的默认值。
- 不创建远程仓库，不修改仓库可见性，不执行 `git add/commit/push`。
- 不执行阶段 1 的安装器、测试和 CI 建设。
- 不应用目标机器配置，不迁移或退役 Intel Homebrew。

## 4. 触发方式与状态机

本阶段必须提供两个不可合并的核心操作意图，以及位于二者之间的目的地配置操作：

```text
stage0 zsh-recommend
stage0 configure-destinations --recommendation-run <run-id>
stage0 export-config --recommendation-run <run-id> \
  --destinations <destination-map.toml>
```

命令名可以在实现时调整，但必须保持以下状态机：

```text
只读发现
  → 只生成 Zsh 建议
    → 第一次 Agent 预审批
      → 用户配置 public/company 目的地
        → 新操作导出并规范化机器配置
          → 第二次 Agent 预审批
            → 阶段 0 就绪
```

禁止提供 `stage0 all`、`--continue-to-export` 或其他会把建议、目的地选择和导出自动串联的入口。两个核心操作可以发生在不同时间或不同 Agent turn 中。

## 5. 前置条件与输入

### 5.1 必需输入

- 当前用户可读的 Zsh 启动文件、symlink、权限和 source 链。
- 当前 PATH/fpath、补全、插件、函数、alias、wrapper 和工具激活的只读证据。
- 现有 Brewfile、Intel/ARM Homebrew、mise、uv、Bun、Node、pnpm、Go、Python、NVM、pyenv、pipx 等只读状态。
- 当前仓库中阶段 1 目标文件的已有来源或“需要新建”状态。

### 5.2 导出前必须由用户决定的输入

用户必须在一个集中问题中提供：

- public：已存在 Git checkout 的绝对路径和仓库内相对根。
- company：已获授权的私有 Git checkout 绝对路径和仓库内相对根，或显式 `skip`。

Agent 不得自动采用当前工作目录、当前 origin 或推测的公司仓库。local-only 不询问，直接使用共用契约固定的 `~/.config/dotfiles/local/`。

## 6. 子阶段 0A：只读发现与脱敏清单

### 6.1 Zsh 证据

必须检查：

- `.zshenv`、`.zprofile`、`.zshrc`、`.zlogin` 及完整 source 链。
- 文件类型、权限、owner、symlink 目标和加载场景。
- login、interactive、non-login interactive 的实际行为。
- PATH/fpath 构造、重复项、Intel/ARM 路径、命令实际解析位置和架构。
- 环境变量名称、alias、function、wrapper、补全、主题、插件、历史与工具激活。
- OMZ、`compinit`、插件管理器和外部插件的初始化次数与顺序。

### 6.2 软件和配置证据

为后续导出预先盘点：

- 现有 Brewfile、tap、formula、leaf、cask、service 和可能的服务数据目录。
- ARM 与 Intel Homebrew 的实际命令来源和架构。
- mise、uv、Bun、Node、pnpm、Go、Python、NVM、pyenv、pipx 的所有权重叠。
- 插件来源、remote、revision、用途和加载顺序。
- Mac App Store 应用清单，但不读取或处理 Apple ID。

0A 只能使用不会生成配置文件的 inspect/list/status 命令。禁止 `brew bundle dump` 和其他 dump/export 操作。

### 6.3 脱敏要求

- 原始且可能包含敏感信息的中间结果不得保存。
- 保存的 source inventory 只包含脱敏文件定位、行号或项目 ID、类别、命中数和不可逆指纹。
- 不保存密钥值、完整环境变量、未脱敏 shell 历史或公司内部值。
- 必须列出阶段 1 目标树中“可由源机器生成候选”和“需要阶段 1 新建”的文件。

### 6.4 产物

- `reports/inventory.md`
- 脱敏 source map
- 已安装项与工具所有权清单
- 阶段 1 目标文件覆盖矩阵
- 敏感信息处置清单

## 7. 子阶段 0B：只生成 Zsh 修改建议

对每个可独立决策的 Zsh 项必须记录：

- 稳定 `recommendation_id` 和当前 `run_id`。
- 当前功能和实际命令来源，不得按名称猜测。
- 语法、职责、加载顺序、幂等、PATH/fpath、补全、插件、架构、安全、可移植性、性能和可公开性结论。
- 保留、改写、替代、移除或待决的建议。
- “一定要改 / 建议修改 / 可以不改”分类。
- public/company/local-only/retire/unresolved 归属。
- 建议代码形态、理由、风险和不含敏感值的验证方式。

只允许写：

- `reports/inventory.md`
- `reports/zsh-recommendations.md`
- `reports/zsh-best-practices.md`
- `reports/unresolved.md`

本子阶段不得创建或修改 public/company/local-only 候选配置，不得改写源机器真实 Zsh 文件，也不得生成建议报告哈希。

完成状态必须是：

```text
zsh_recommendations=ready_for_preapproval
```

## 8. 子阶段 0C：第一次 Agent 预审批

Agent 只审批 Zsh 建议，不审批尚未生成的候选文件。

1. 对每个 `recommendation_id` 填写三档修改级别。
2. 根据共用契约自动映射 `accept/revise/reject/defer`。
3. `revise` 必须先更新建议和决策记录；仍不得导出候选。
4. `reject` 对应改动不得进入导出。
5. `defer` 只用于真正阻断的证据缺口。
6. `recommendation-decisions.tsv` 必须使用同一 `run_id` 并覆盖全部建议 ID。

建议、决策、run-id 或 ID 覆盖不一致时，后续导出必须失败。0C 结束后仍不得存在由本 run 生成的候选配置树。

完成状态必须是：

```text
zsh_recommendations=preapproved
```

## 9. 目的地配置

0C 完成后、任何 dump/export 之前，必须生成：

```text
~/.local/state/dotfiles/stage0/<run-id>/manifest/destination-map.toml
```

固定 schema：

```toml
schema_version = 2
run_id = "<run-id>"

[local-only]
root = "/Users/USER/.config/dotfiles"
relative_root = "local"

[public]
repo_checkout = "/absolute/path/to/user-selected-public-repo"
repo_relative_root = "."

[company]
mode = "write" # 或 "skip"
repo_checkout = "/absolute/path/to/user-selected-company-repo"
repo_relative_root = "dotfiles"
```

验证要求：

- local-only 绝对根必须是当前用户 `~/.config/dotfiles` 的规范化形式，相对根必须等于 `local`。
- public/company 的 `repo_relative_root` 必须是无 `..` 且不越过 Git checkout 根的相对路径。
- 展示“归属 → checkout/root → 相对路径 → 最终绝对路径”预览表。
- 验证 Git root、origin、可见性线索、工作树状态、写权限、路径越界和 Git/云同步边界。
- 已存在文件内容不同、工作树有重叠修改或 local-only 固定文件已被当前 source 链加载时，停止并生成冲突报告。
- 目的地发生变化时，旧导出标记为 stale；不得自动改道到 staging。

## 10. 子阶段 0D：单独导出机器配置

0D 必须由新操作显式启动，并首先验证：

- 0C 已完成。
- `run_id` 一致。
- 当前建议 ID 被第一次预审批完整覆盖。
- `destination-map.toml` 存在且通过验证。
- 既有候选没有因建议、决策、证据或目的地变化而失效。

### 10.1 Zsh 候选转换

只消费第一次预审批为 `accept/revise` 的建议：

- public 只生成 `zsh/.zprofile` 和 `zsh/.zshrc` 两个真实入口。
- `.zshrc` 使用固定 OMZ revision 官方模板骨架，只允许经预审批的值变更、Intel 示例删除和固定边界受管区块。
- company/local-only 每层最多生成 `zsh/profile.zsh`、`zsh/pre.zsh`、`zsh/rc.zsh`。
- `reject/defer` 项不得静默复制旧实现。
- 每个 Zsh 候选项必须关联同一 `run_id` 和一个或多个 `recommendation_id`。

public 受管区块标记固定为：

```zsh
# >>> dotfiles: arm64 public configuration >>>
# 经预审批的 public 配置
# <<< dotfiles: arm64 public configuration <<<
```

### 10.2 软件与工具配置转换

只有 0D 可以运行 `brew bundle dump` 等会生成配置的原生导出功能。原始输出必须进入 `mktemp -d` 创建的临时证据目录，规范化后删除，不得直接成为候选文件。

必须逐项完成：

- 删除传递依赖、缓存路径、dump 时间和机器偶然状态。
- 分离 public/company/local-only/retire/unresolved。
- 对 formula、cask、service、工具链和插件说明功能、所有权和替代方案。
- Brewfile 按 `tap`/`brew`/`cask` 分组并在组内稳定排序。
- mise、uv、语言运行时和插件使用明确版本或 revision，不得写 `latest`。
- Rosetta cask 只作迁移证据，不进入最终兼容配置。
- 未能从证据确定的版本或归属进入 `unresolved`，不得复制示例或猜测值。

### 10.3 候选目标路径

候选必须直接写入固定或用户选择的目的地：

```text
public:     <public-checkout>/<public-root>/<stage-1-relative-path>
company:    <company-checkout>/<company-root>/<company-relative-path>
local-only: ~/.config/dotfiles/local/<classification-relative-path>
```

典型候选集合：

```text
public/zsh/.zprofile
public/zsh/.zshrc
public/zsh/plugins/{catalog,revisions}.toml
public/macos/Brewfile
public/tooling/mise/10-public.toml
public/tooling/uv/{uv.toml,.python-versions}

company/zsh/{profile,pre,rc}.zsh
company/macos/Brewfile
company/mise/50-company.toml
company/plugins/catalog.toml
company/diagnostics/rules.toml

~/.config/dotfiles/local/zsh/{profile,pre,rc}.zsh
~/.config/dotfiles/local/macos/Brewfile
~/.config/dotfiles/local/mise/90-local.toml
~/.config/dotfiles/local/uv/*
~/.config/dotfiles/local/plugins/selection.toml
```

没有实际内容时不创建空文件。retire/unresolved 只写仓库外报告。

## 11. `stage0-candidate/v8` 格式契约

| 目标文件 | 必需格式 | 最低验证 |
|---|---|---|
| public `zsh/.zprofile` | 可直接链接的 UTF-8 Zsh；内联 ARM login PATH；显式 source company/local `profile.zsh` | `zsh -n`、隔离 login、symlink 目标、无 Intel 运行时路径 |
| public `zsh/.zshrc` | 固定 OMZ 模板骨架；固定受管区块；显式 source company/local pre/rc | `zsh -n`、隔离交互场景、模板对照、OMZ/`compinit` 一次 |
| private `zsh/{profile,pre,rc}.zsh` | 每层每阶段一个固定 UTF-8 文件 | `zsh -n`、覆盖顺序、可选缺失行为 |
| `macos/Brewfile` | Homebrew Bundle Ruby DSL；分组稳定排序；只含期望状态 | 解析、重复项、归属、架构检查 |
| mise TOML | 受支持字段；明确版本；分层 | TOML 解析、mise 检查、所有权冲突 |
| `tooling/uv/uv.toml` | uv 支持的用户配置，不含项目依赖或本机路径 | TOML 解析、固定版本 uv 检查 |
| `.python-versions` | 每行一个明确 Python 版本，稳定排序 | 行格式、重复项、ARM 可用性 |
| plugin catalog/revisions | 固定 schema、来源、用途、依赖、风险和 revision | TOML/schema、URL 安全、revision 非浮动 |
| decisions/manifests | 本文件固定 TSV 表头 | 表头、枚举、run-id 和候选一一覆盖 |

支持注释的候选项必须使用结构化同行注释：

```text
# 功能=<为什么存在>；最佳实践=<pass|rewrite|replace|remove|review>；修改级别=<一定要改|建议修改|可以不改>；建议=<保留/改写/替代项及理由>；归属=<public|company|local-only|retire|unresolved>；验证=<不含敏感值的检查方式>
```

不安全支持注释的 JSON、签名、上游生成文件等格式必须用 `reports/file-decisions.tsv` 记录同等信息。OMZ 官方模板原样保留的行也使用 sidecar，不得为元数据破坏模板骨架。

## 12. 追溯文件

`reports/recommendation-decisions.tsv` 固定表头：

```text
run_id\trecommendation_id\tsource_locator\tfunction\tfinding\trecommendation\tchange_class\tclassification\tverification\trecommendation_decision\treview_note
```

`manifest/files.tsv` 固定表头：

```text
contract_version\trun_id\tsource_kind\tsource_locator\tgenerator\trecommendation_ids\ttarget_repository\ttarget_path\tformat\tchange_class\tclassification\tbest_practice\treview_decision\tfinal_path\tfinal_commit
```

`reports/file-decisions.tsv` 固定表头：

```text
run_id\ttarget_repository\ttarget_path\titem_locator\trecommendation_ids\tfunction\tbest_practice\tchange_class\trecommendation\tclassification\tverification\treview_decision\treview_note
```

文件中的 `\t` 必须是真实 tab。约束如下：

- `change_class`：`must-change`、`recommended-change`、`may-keep`。
- `generator`：`dump-normalized`、`agent-derived`、`source-split`、`manual`。
- `target_repository`：`public`、`company`、`local-only`、`none`。
- `classification`：`public`、`company`、`local-only`、`retire`、`unresolved`。
- Zsh 候选必须填写 `recommendation_ids`；非 Zsh 候选可以为空，但必须分类并完成第二次预审批。
- 阶段 0 结束时 `review_decision` 必须有值；`final_path/final_commit` 由阶段 1 落库后填写。
- v8 不保存逐项原始证据、建议报告或候选文件 SHA-256。

## 13. 子阶段 0E：第二次 Agent 预审批

Agent 必须读取候选来源摘要、diff、同行注释或 sidecar、最佳实践结论、归属和验证结果，并为每个候选文件及 `review/unresolved` 项重新填写三档分类及 `accept/revise/reject/defer`。

- `accept`：允许阶段 1 按候选落库。
- `revise`：允许阶段 1 按预审批意见改写并重新验证。
- `reject`：不得落库；移入 local-only/retire/backlog 或删除候选副本。
- `defer`：留在仓库外并阻止对应内容落库。

如果候选审批要求改变 Zsh 建议，必须回到 0B/0C 更新建议，再重新执行 0D；不能用第二次审批反向覆盖第一次审批。

所有决策完成后，按路径稳定排序并规范化串联以下内容，只生成一次 `manifest/stage0-summary.sha256`：

- `destination-map.toml`
- 最终建议与决策 TSV
- public/company/local-only 候选内容
- public/company 仓库 diff

此前不得生成中间哈希或逐文件 checksum。

## 14. 阶段产物

```text
~/.local/state/dotfiles/stage0/<run-id>/
├── source-inventory/
├── reports/
│   ├── inventory.md
│   ├── zsh-recommendations.md
│   ├── recommendation-decisions.tsv
│   ├── zsh-best-practices.md
│   ├── export-report.md
│   ├── export-best-practices.md
│   ├── file-decisions.tsv
│   ├── unresolved.md
│   └── export-conflicts.md            # 仅发生冲突时
└── manifest/
    ├── destination-map.toml
    ├── files.tsv
    └── stage0-summary.sha256
```

配置类主产物直接位于 destination map 指定的三个目的地；敏感原始证据、retire 和 unresolved 项不进入这些配置树。

## 15. 失败、失效与恢复

- 建议文本、第一次预审批、源机器证据或目的地发生变化：已有导出标记为 stale，重新执行受影响的 0D/0E。
- 候选要求改变 Zsh 方案：回到 0B/0C，不能直接在 0E 修补追溯链。
- 目的地不可写、越界或有内容冲突：停止并生成 `export-conflicts.md`，不得换目录或覆盖。
- 敏感内容或公司信息进入 public 候选：删除候选副本、记录失败、重新分类与生成；不得只靠提交前扫描补救。
- `defer/unresolved` 仅阻止相关内容准入；如果它影响全局正确性或安全，则阻止整个阶段完成。

## 16. 完成条件

- [ ] 0A 已脱敏覆盖 Zsh source 链、软件、插件和工具所有权证据。
- [ ] 0B 只生成建议报告，没有候选配置或真实 HOME 修改。
- [ ] 每条 Zsh 建议有稳定 ID、三档分类和第一次预审批决策。
- [ ] `destination-map.toml` 记录固定 local-only 和用户选择的 public/company 目的地。
- [ ] 0D 是单独显式操作，且只消费 `accept/revise` Zsh 建议。
- [ ] 原始 dump 只作为证据，所有候选符合 `stage0-candidate/v8`。
- [ ] 候选已完成语法、schema、归属、架构、最佳实践和敏感信息验证。
- [ ] 每个候选与 unresolved 项完成第二次独立预审批。
- [ ] Zsh 候选可以追溯到同一 run-id 和建议 ID。
- [ ] 配置候选位于固定/用户选择的实际目的地，没有覆盖既有工作。
- [ ] public 候选及其注释/sidecar 不含密钥、公司或机器专属信息。
- [ ] 只生成一份最终 `stage0-summary.sha256`。
- [ ] 未执行软件写操作、symlink 修改或任何 `git add/commit/push`。

完成状态必须表述为“候选文件和两次 Agent 预审批已就绪”，不得表述为“仓库或目标机器已交付”。

## 17. 未来 Skill 接口

未来 Skill 名：`stage-0-source-machine-analysis-and-export`。

Skill 必须区分至少两类触发语义：

- “分析/诊断当前 Zsh 并提出建议”只能执行 0A–0C，输出后停止。
- “基于已预审批建议导出机器配置”只能从目的地配置和 0D 开始，完成 0E 后停止。

Skill 必须把本文件作为工作流来源，把 [共用契约](./stage-common-contract.md) 作为共享 reference；不得把两个触发语义合并为一次自动执行。
