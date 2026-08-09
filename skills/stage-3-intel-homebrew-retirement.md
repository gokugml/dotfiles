# Stage 3：Intel Homebrew 退役需求

> 状态：实施级阶段需求<br>
> 版本：1.0<br>
> 日期：2026-08-09<br>
> 执行角色：目标机器用户与实施 Agent<br>
> 执行位置：已完成阶段 2 且仍存在 Intel Homebrew 的目标机器

## 1. 阶段定位

本阶段是独立、显式且不可逆的 Intel Homebrew 退役阶段。它只消费阶段 2 在同一台机器上生成并验证的 migration manifest 和 retirement ledger；不得重新猜测机器状态，也不得由安装器、普通迁移或 Agent 自动进入。

执行前必须阅读 [四阶段共用契约](./stage-common-contract.md) 和 [Stage 2：目标机器配置与软件迁移](./stage-2-target-machine-configuration-and-software-migration.md)。不可代理边界、真实 TTY 规则、哈希边界、回滚限制和 Git/隐私要求以共用契约为准。

如果阶段 2 readiness 为 `not-applicable`，本阶段无需执行；如果为 `blocked`，必须回到阶段 2 处理阻断项。

## 2. 阶段目标

1. 重新验证阶段 2 的 ARM 替代结果、机器身份和账本时效。
2. 生成独立、只读、可审查的最终退役预览。
3. 冻结唯一的不可逆退役 manifest 并生成对应整体 SHA-256。
4. 让用户在真实 TTY 中亲自确认最终清单和影响路径。
5. 使用已固定、审查的 Homebrew 官方卸载机制退役 Intel Homebrew。
6. 只处理 manifest 内批准的遗留项目，不递归删除 `/usr/local`。
7. 验证最终 shell、PATH、关键命令、服务和残留状态。
8. 在本地留下可查询的官方卸载记录、retired inventory 和审计结果。

## 3. 非目标

- 不安装或重新选择 ARM 替代软件；替代不完整时回到阶段 2。
- 不通过 `install.sh` 或 `bin/dotfiles` 提供退役别名。
- 不设置 Intel 兼容 PATH、Rosetta fallback 或临时持久 wrapper。
- 不递归删除 `/usr/local`，不整体 `chown /usr/local`。
- 不删除未被 Homebrew 管理或未进入 manifest 的文件。
- 不自动删除 GUI 应用数据、数据库数据或未知服务目录。
- 不为回滚重新安装 Intel Homebrew。
- 不把退役 manifest、旧路径、机器 ID 或 retired record 提交仓库。

## 4. 触发和命令边界

本阶段必须由用户或 Agent 在收到用户明确的阶段 3 意图后，从只读预览开始：

```zsh
./scripts/migrate-intel-homebrew-to-arm.sh --retire
```

只有预览全部通过后，用户才可以在真实 TTY 中运行：

```zsh
./scripts/migrate-intel-homebrew-to-arm.sh --retire --apply
```

要求：

- `--retire` 只读，可以刷新预览和阻断报告。
- `--retire --apply` 是唯一正式退役入口。
- 两者不得与阶段 2 普通 `--apply` 在同次执行中组合。
- `install.sh`、`bin/dotfiles`、CI、Agent 管道和其他 wrapper 不得代替该命令。
- 用户一旦明确进入阶段 3 且最终预览通过，应在同一执行窗口完成退役，不设置自动观察期；如果用户中止，则重新预览后再进入。

## 5. 前置门禁

必须同时满足：

- 当前进程为原生 `arm64`。
- 阶段 1 仓库基线仍通过安全和配置验证。
- 本机阶段 2 配置 `verify` 成功。
- 本机迁移脚本普通 `--apply` 和 `--verify` 成功。
- 当前机器 ID 与 migration manifest 一致。
- retirement ledger 属于同一 migration run-id，未过期且未被外部修改。
- ARM Homebrew 健康，关键命令路径、架构和版本验证成功。
- 每个 Intel formula、cask、service 和数据目录都已归类。
- 不存在 `unresolved`、运行中的 Intel service、未知数据或失败替代项。

以下任一情况必须阻止正式命令：

- manifest/ledger 缺失、机器不匹配或时间状态过期。
- ARM 替代命令实际解析回 Intel 路径或架构不是 ARM。
- service/cask/data 状态变化，或新发现未盘点 Intel 项。
- public/company/local-only Zsh 出现 Intel 运行时路径或兼容分支。
- Homebrew 官方卸载脚本来源、revision 或 SHA-256 未固定和审查。
- 当前会话没有真实 TTY。

## 6. 子阶段 3A：独立预览与阻断检查

`--retire` 必须重新收集当前只读状态，并与阶段 2 已验证基线比较，而不是直接信任旧报告。

### 6.1 身份与时效

- 验证机器 ID、用户、架构、migration run-id 和仓库基线。
- 验证阶段 2 manifest、ledger、verify 报告和 status 的关联。
- 检测迁移后新增、删除、升级、启停或路径改变的项目。
- 任何实质漂移都使旧 readiness 失效，并要求回到阶段 2 更新计划与验证。

### 6.2 ARM 替代复验

对每个旧项目实际执行其无副作用验证命令，确认：

- replacement path 存在且不位于 Intel Homebrew 前缀。
- replacement architecture 为 ARM 或受支持的 Universal。
- replacement version 符合阶段 2 记录的期望。
- replacement manager 与共用工具所有权契约一致。
- `retired_by_choice` 有 Agent 分类证据和明确淘汰理由。

不得只检查“命令能运行”；必须验证实际路径和架构。

### 6.3 服务、Cask 和数据

- 验证所有 Intel service 已停止或已由 ARM service 接管。
- 验证服务配置、端口、数据和健康检查结果。
- 验证 cask 已归为 ARM/Universal、替代或明确淘汰。
- 审计 `/usr/local/var`、`/usr/local/etc` 及阶段 2 识别的其他数据路径。
- 未知目录保留并阻断，不得纳入通用删除动作。

### 6.4 最终预览

预览必须展示：

- migration run-id、机器身份和阶段 2 verify 状态。
- 每个 Intel 项及其最终目标状态。
- ARM 替代路径、架构、版本和验证结果。
- 需要停止或将被删除的服务/程序。
- Homebrew 官方卸载预计影响的路径。
- 明确保留的非 Homebrew `/usr/local` 内容和未知阻断项。
- 不可逆边界、无法自动回滚的内容和最终验证步骤。

预览不执行软件或文件写操作。

## 7. 最终退役 Manifest

预览无阻断项后，脚本必须冻结最终 manifest。它至少包含：

- schema version、migration run-id、机器 ID、用户和生成时间。
- Intel Homebrew 前缀及已确认的 Homebrew 管理路径。
- 每个项目的旧路径、架构、版本、处置状态和替代验证摘要。
- service/cask/data 的最终状态。
- 官方卸载脚本来源、固定 revision 和 SHA-256。
- 官方卸载将影响的路径。
- Agent 预审批结果。
- 明确保留和不得处理的路径。
- 退役后的验证命令集合。

只为这份冻结的不可逆清单生成：

```text
~/.local/state/dotfiles/retired-homebrew/<migration-run-id>/retirement-manifest.sha256
```

manifest 内容、机器状态或预览发生任何变化时，旧哈希立即失效，必须重新执行 `--retire`。不得为每个项目生成额外 checksum 链。

## 8. Agent 预审批与用户确认

### 8.1 Agent 预审批

Agent 必须在正式命令前复核：

- manifest 与 retirement ledger 一一覆盖。
- 所有项目目标状态合法且无 `unresolved`。
- ARM 替代验证完整。
- 未知或非 Homebrew 路径不在删除清单。
- 官方卸载脚本来源和哈希匹配。
- 不存在递归 `/usr/local` 删除、整体权限修改或隐藏副作用。

Agent 可以批准 manifest 内容，但不能批准或代替执行不可逆动作。

### 8.2 用户真实 TTY 确认

正式命令必须：

1. 确认 stdin/stdout 连接真实 TTY。
2. 再次展示最终清单、官方卸载影响路径和 manifest SHA-256。
3. 明确说明退役后不会自动重装 Intel Homebrew。
4. 要求用户亲自输入实现时固定的精确确认短语。
5. 拒绝空输入、模糊确认、普通 `--yes`、管道输入、环境变量确认和 Agent 代输。
6. 输入正确后再次验证 manifest 内容仍与 SHA-256 一致，才允许执行。

## 9. 子阶段 3B：正式退役

正式命令的执行顺序必须固定：

1. 获取独立退役 lock，防止配置、迁移和退役并发写入。
2. 重验原生 `arm64`、机器 ID、migration run-id 和仓库配置状态。
3. 重验 ARM Homebrew 健康和全部替代项。
4. 重验服务、cask、数据和未知路径阻断条件。
5. 重验冻结 manifest 的 SHA-256。
6. 完成真实 TTY 精确确认。
7. 根据已授权 runbook 停止剩余获准服务并记录状态。
8. 使用已下载、固定来源/revision/哈希且经审查的 Homebrew 官方卸载机制处理 Intel 前缀；禁止 `curl | shell`。
9. 只处理 manifest 中明确批准的遗留程序文件。
10. 保留所有未在 manifest 中列出的 `/usr/local` 内容，不递归删除或整体改 owner。
11. 刷新 shell 命令路径缓存，启动干净 shell 执行最终验证。
12. 写入每个动作和项目的结果，形成 retired record。

如果正式命令在部分执行后失败，必须保留准确的逐项状态并进入“部分退役”故障处理；不得尝试自动重装 Intel Homebrew或无清单清理残留。

## 10. 子阶段 3C：最终验收

### 10.1 Shell 与 PATH

必须验证：

```text
arch                              -> arm64
command -v brew                   -> /opt/homebrew/bin/brew
brew --prefix                     -> /opt/homebrew
command -v node/bun/pnpm/go       -> mise 管理的原生版本
command -v uv                     -> ARM 原生 uv
uv python find --managed-python   -> uv 管理的 ARM Python
$path                             -> 无重复项、无活动 Intel Homebrew 路径
zsh -l -i -c exit                 -> 无加载错误
```

还必须审计 public/company/local-only 的全部受管 Zsh 文件，确认它们始终没有 Intel 运行时兼容。

### 10.2 软件、服务和数据

- ARM Homebrew 和全部关键替代项可用。
- 已迁移 service 的状态、端口和数据验证通过。
- Intel formula/cask/service 已按 manifest 完成处置。
- `/usr/local` 残留被分类为保留、非 Homebrew、已知待办或异常；不存在无记录删除。
- cleanup 不得扩展到 manifest 外目标。

### 10.3 状态查询

必须运行：

```zsh
./scripts/migrate-intel-homebrew-to-arm.sh --verify
./scripts/migrate-intel-homebrew-to-arm.sh --status
```

`--status` 必须能查询：

- migration run-id 和机器身份。
- 每个项目的旧路径/架构、替代路径/架构和处置状态。
- 官方卸载脚本版本、manifest SHA-256 和执行时间。
- 服务/cask/data 结果。
- 失败、保留和 `/usr/local` 残留审计。

## 11. 本地交付产物

阶段 3 产物保存在：

```text
~/.local/state/dotfiles/retired-homebrew/<migration-run-id>/
├── retirement-manifest.*
├── retirement-manifest.sha256
├── official-uninstall-record.*
├── retired-inventory.*
├── actions.*
├── verify.*
├── status.*
└── usr-local-residual-audit.*
```

具体扩展名由阶段 1 schema 固定。报告不得包含密钥、完整环境变量、未脱敏历史或可用于识别其他私有系统的信息。这些文件不得提交 public/company 仓库。

## 12. 失败处理

### 12.1 正式执行前失败

- 清单漂移、验证失败或出现新项目：作废 manifest 和 SHA-256，回到阶段 2 更新迁移状态。
- 缺少真实 TTY 或确认短语不匹配：无变更退出。
- 官方脚本来源或哈希不匹配：阻断并重新取得、审查和固定来源。
- 未知 `/usr/local` 数据：保留并阻断，不推测所有权。

### 12.2 部分执行后失败

- 停止后续未执行动作，保留逐项 actions 和官方卸载输出。
- 先验证 ARM Homebrew、shell 和关键替代项仍可用。
- 使用 manifest 对照已完成与未完成项目，生成定向修复计划。
- 只修复或重装 ARM 替代项，不恢复 Intel Homebrew。
- 不使用通用递归删除完成“清理”。
- 修复后重新执行只读 `--verify/--status`；是否还需退役动作由剩余 manifest 决定。

## 13. 完成条件

- [ ] 用户明确进入阶段 3，并先单独运行只读 `--retire`。
- [ ] 当前会话、机器 ID、migration run-id、manifest 和账本均匹配且未过期。
- [ ] 所有 Intel 项已归类，无 `unresolved`、未知数据或运行中 Intel service。
- [ ] 所有 ARM 替代项已通过实际路径、架构和版本复验。
- [ ] 官方卸载脚本来源、revision 和 SHA-256 已固定并经 Agent 审查。
- [ ] 最终 manifest 已冻结，只生成一份整体 `retirement-manifest.sha256`。
- [ ] 用户在真实 TTY 中亲自输入精确确认短语。
- [ ] 正式执行只处理 manifest 项目，未递归删除或整体修改 `/usr/local`。
- [ ] 最终 shell、PATH、Homebrew、语言工具、服务和数据验证通过。
- [ ] `--status` 可以查询完整退役记录和残留审计。
- [ ] 退役产物只保存在当前机器，不含密钥且未提交仓库。
- [ ] rollback 没有尝试恢复 Intel Homebrew。

完成状态必须表述为“本机 Intel Homebrew 已按已审批 manifest 退役并通过最终审计”。

## 14. 未来 Skill 接口

未来 Skill 名：`stage-3-intel-homebrew-retirement`。

这是低自由度 Skill。推荐触发语义：用户明确要求退役当前 Apple Silicon 机器上的 Intel Homebrew。Skill 必须固定执行以下控制流：

```text
验证阶段 2 readiness
  → 只读 retire preview
    → Agent 预审批 manifest
      → 向用户报告不可逆边界
        → 用户在真实 TTY 运行正式命令并亲自确认
          → verify/status 与残留审计
```

Skill 不得自行键入确认短语，不得把普通迁移意图提升为退役意图，不得在阻断项存在时寻找绕过方案。schema、官方卸载来源规则和失败恢复矩阵应放在直接引用的 `references/`；manifest 和架构校验适合由确定性脚本实现。
