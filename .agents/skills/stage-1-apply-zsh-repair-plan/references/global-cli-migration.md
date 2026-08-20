# 全局 CLI 迁移交接协议

当 Stage 1 将 NVM、`PNPM_HOME`、`BUN_INSTALL` 或其他工具目录从活动 Zsh/PATH 中移除或改由新 owner 管理时，使用本协议保全已经安装、但会在新 Zsh 中失去命令解析的直接全局 CLI。

本协议只迁移软件安装意图，不迁移项目依赖、认证数据、token、缓存、服务数据、alias 或第三方 Zsh 功能块。alias 和功能块仍走 Stage 1 的功能块保全流程。

## 默认 runtime 与全局 CLI PATH ownership

把“runtime/manager 命令的主要入口”和“该 manager 安装的全局 CLI”分开管理。默认推荐各 manager 的官方原生全局目录，不默认把所有命令统一到 `~/.local/bin`。

### 默认推荐：manager 官方原生目录

- `node`、`bun`、`pnpm` runtime 由 mise 管理，通过 `mise activate` 或 shims 暴露；`npm` 随当前 mise Node 提供。`~/.bun/bin/bun`、`~/.bun/bin/bunx`、独立 pnpm/npm 安装不得抢占主要 runtime 入口。
- Bun 的状态与全局包保存在 `$HOME/.bun/`，Zsh 只把实际可执行目录 `$HOME/.bun/bin` 加入 PATH。由于该目录也包含 `bun`、`bunx`，mise shims/当前 runtime bin 必须排在它之前。
- pnpm 使用用户确认并由当前版本只读查询证明的 `PNPM_HOME`/global bin。优先核对 `pnpm config get global-bin-dir`、`pnpm bin -g` 和 `pnpm root -g`；不得固定猜测 `$PNPM_HOME/bin`。确认当前版本以 `$PNPM_HOME` 本身保存全局命令时，把 `$PNPM_HOME` 加入 PATH。
- npm 全局 CLI 位于当前 mise Node prefix 的 `bin`；由 mise 激活或 shims 暴露，不在 public Zsh 中硬编码 `~/.local/share/mise/installs/node/<version>/bin`。更换或退役 Node 版本前，必须逐个盘点该 prefix 的直接 npm 全局 CLI。
- `uv` 本体同样只能有一个已确认 owner；不要为了目录统一复制或链接第二个 `uv`。若启用 `uv tool` 的用户级 bin，只把其只读查询确认的 bin 目录作为独立全局 CLI owner 处理。

默认 PATH 优先级为：

```text
原生 Homebrew
→ mise shims / 当前 mise runtime
→ pnpm global bin
→ Bun global bin
→ ~/.local/bin（用户脚本与 wrapper，可选）
→ 继承 PATH
```

该策略保留 manager 官方安装、升级和卸载语义，无需额外复制或 symlink；代价是 PATH 入口较多，npm 全局 CLI 还会绑定具体 mise Node prefix。

### 可选：统一 `~/.local/bin`

每次 Stage 1 涉及 runtime/global CLI PATH 时，都要让用户选择是否改用统一 `~/.local/bin`，并先说明：统一目录提供稳定的 XDG 用户命令入口，便于 PATH 管理、迁移和备份；但可能隐藏真实 owner，并要求逐个 manager 证明官方支持自定义 global bin，或使用用户明确批准且可验证的 wrapper。

选择统一目录不授权复制、移动或 symlink `node`、`bun`、`bunx`、`pnpm`、`npm`、`uv` 等 runtime/manager 本体，也不允许为同一命令建立第二个 owner。某个 manager 不支持安全统一时，保持其官方原生目录并把偏离理由展示给用户；不要为了目录外观破坏安装器语义。

### 验证

- `command -v`/`type -a` 确认 `node`、`bun`、`bunx`、`pnpm`、`npm` 的首个解析结果来自 mise 管理的当前 runtime。
- Bun、pnpm、npm 安装的每个全局 CLI 解析到已确认的对应 global bin/Node prefix；同名命令不得由错误 manager 或旧 PATH 抢占。
- public Zsh 不包含版本化 mise Node prefix，不把 `$HOME/.bun` 状态根本身加入 PATH，也不把未经版本查询确认的 `$PNPM_HOME/bin` 写成固定规则。
- 选择统一 `~/.local/bin` 时，逐项记录 owner、官方配置或 wrapper 依据，并验证移除旧入口后命令仍可达；无法证明时保持 manager 原生目录或标为 `manual`。

## 双文件边界

### 本机迁移清单

固定路径：

```text
${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/global_cli_to_be_migrated.tsv
```

- 只属于生成它的当前机器，不进入 Git。
- 父目录必须为 `0700`，文件必须为当前用户拥有的普通文件且权限为 `0600`；不得跟随 symlink。
- 可以记录源机器绝对路径，但不得记录环境变量值、认证配置、token、完整环境或包配置正文。
- 使用临时文件、固定 ownership marker 和原子替换；未知同名文件不得覆盖。
- 没有候选时不创建空文件；已有、由固定 marker 证明归属的旧文件可以原子移除，未知文件不得删除。

固定第一行为：

```text
# dotfiles-global-cli-migration-v1
```

第二行及后续使用 UTF-8 TSV，字段顺序固定为：

```text
source_manager	package	version	binaries	source_runtime	source_prefix	source_bin_dir	impact	proposed_target_manager	proposed_target_spec	decision	status	verification
```

字段规则：

- `source_manager`：`npm`、`pnpm`、`bun` 或 `path`。
- `package`、`version`：直接安装项的精确包名和已安装版本；无法确定包身份时只允许 `source_manager=path`，并保持 `decision=manual`。
- `binaries`：按字节序排序、逗号分隔的命令名，不记录绝对路径。
- `source_runtime`：例如 `nvm-node@24.14.1`、`direct-bun@1.3.5`；无法确认时为 `unknown`。
- `source_prefix`、`source_bin_dir`：仅在本机 TSV 中记录规范化绝对路径。
- `impact`：`runtime-owner-replaced`、`global-home-changed`、`path-entry-removed` 或 `initializer-retired`。
- `proposed_target_manager`：`bun`、`mise`、`npm`、`pnpm` 或 `manual`。
- `proposed_target_spec`：目标管理器能够消费的安装 spec；已确认自动迁移时使用 `<package>@latest`，尚未确认时为空。
- `decision`：`pending`、`selected`、`skipped` 或 `manual`。
- `status`：`detected`、`declared`、`installed`、`verified`、`failed` 或 `skipped`。
- `verification`：只记录安全结果枚举或解析后的非敏感命令路径类别，不记录命令输出正文。

拒绝字段中的换行和制表符；稳定排序键为 `source_manager`、`package`、`version`、`binaries`、`source_bin_dir`。同一 package 的多个旧 prefix 分行保存，不因包名相同丢失来源证据。

### 可分享声明

固定 personal 路径：

```text
my_setup/tooling/global-cli-migration.toml
```

- 进入 Git，供任意目标机器的 Stage 2 可选消费。
- 不记录源机器绝对路径、HOME、账号、认证状态或本机配置。
- 只写入用户在 Stage 1.1 明确选择、且包名、版本、binary 和目标 manager 都已确定的项目。
- 它是 `prompt` 策略的可分享迁移声明，不是 Stage 2 的必需模块；缺失或用户跳过均不影响基础 Stage 2。
- 不创建 shared/local 副本，不把它混入 mise `conf.d` 文件。

固定 schema：

```toml
schema_version = 1
install_policy = "prompt"

[[tools]]
description = "一句话说明该 CLI 的用途"
package = "@scope/package"
version = "1.2.3"
binaries = ["example-cli"]
source_manager = "npm"
target_manager = "bun"
target_spec = "@scope/package@latest"
reason = "runtime-owner-replaced"
```

约束：

- `schema_version` 必须为 `1`，`install_policy` 必须为 `prompt`。
- `description`、`package`、`version`、`binaries`、`source_manager`、`target_manager`、`target_spec`、`reason` 都是必填字段。
- `version` 必须保留源机器检测到的精确版本，作为迁移来源快照；`target_spec` 必须使用与 `package` 对应的 `<package>@latest`。禁止其他 tag、semver 范围或省略版本。
- `binaries` 必须非空、唯一并按字节序排序。
- `source_manager` 只允许 `npm`、`pnpm`、`bun`、`path`；`target_manager` 只允许 `bun`、`mise`、`npm`、`pnpm`。
- JS CLI 默认优先评估 `bun`；只有包元数据、安装布局、目标 bin 可达性或兼容性证据不支持 Bun 时，才选 `mise`、`npm` 或 `pnpm`，并把理由展示给用户。
- 目标 manager 的全局 bin 必须能由最终 Zsh 或受管 runtime 解析；不得为了某一 CLI 恢复已退役的 NVM、旧 `PNPM_HOME`、`BUN_INSTALL` 或其他旧 PATH。
- package、version、binary、target manager 任一项不明确时只留在本机 TSV 的 `manual` 项，不写入 public TOML。

## 只读发现算法

1. 对比已确认源 Zsh 功能块/PATH 与 Stage 1 最终候选，先建立“源可达、候选不再可达或改由错误 owner 解析”的影响集；逐项列出本次变更明确移除、替换或改变语义的 runtime initializer、global home 和 PATH 目录。

   影响集包含 NVM initializer、`NVM_DIR` 或 NVM Node `bin`，或用户明确要求盘点 NVM 时，额外完整读取 [NVM 全局 CLI 逐版本盘点](./nvm-global-cli-inventory.md)；其他情况不加载该专项引用。

2. 对影响集中的每个旧 owner/目录分别覆盖 npm、pnpm、Bun 的直接全局安装项，以及明确移除 PATH 目录中的直接可执行文件；不能因为当前默认 runtime 属于其中一个 manager 就跳过另外两个。不要扫描无关 PATH、整个 HOME、`/usr/local` 或项目目录。
3. 优先读取已经存在的包管理器结构化清单、lock/manifest、包目录 `package.json`、bin symlink 和精确 runtime metadata。只在本机帮助能够证明命令完全只读且不会维护全局目录时，才调用 manager 的 list/root/bin/prefix 查询。
4. 不执行已安装的业务 CLI，不调用可能自更新的 `--version`、`version`、首次运行、login 或 doctor 命令。版本从 manager metadata 或安装目录 manifest 取得。
5. 排除 runtime 自带的 npm、Corepack、包管理器自身、传递依赖、项目依赖、缓存和没有暴露 CLI binary 的库包。
6. 计算最终 Zsh/runtime 下的命令可达性。只有命令会失去解析、解析到错误架构/旧 owner，或相同 package 尚未存在于目标 owner 时才进入清单。
7. 相同 package/version/binaries 已在目标 owner 精确存在且命令解析正确时，记录为已覆盖证据，不进入待迁移清单。

8. 无法安全读取旧 prefix、无法确认直接/传递关系、package identity 或版本时，阻止自动退役对应旧 initializer/PATH；把该项标为 `manual`，不要猜测或静默遗漏。
9. 用户明确排除某个 owner 或目录时不得读取该范围；同时从本轮可应用 Zsh 变更中移除对应 PATH/initializer 退役。其他独立变更可以继续，但本轮只能报告“Stage 1 部分应用”，修复计划不得标为已应用，也不得进入 Stage 1.1。

## Stage 1 写入时序

1. 在展示 Zsh 完整 diff 前完成只读发现，并在执行前计划中列出将检查的精确旧 owner/目录，以及 npm、pnpm、Bun、直接 PATH CLI 四类的逐项覆盖结果。
2. 把本机 TSV 的新增、更新或安全移除作为 Stage 1 写入范围；对话只展示 manager/package/version/binaries/impact/decision 的脱敏结构摘要，不展示源绝对路径。
3. 用户确认完整 Stage 1 diff 后，先原子写入本机 TSV，再写 Zsh 目标；TSV 写入失败时不得应用会让对应 CLI 失去解析的 Zsh 变更。
4. Zsh、功能块和修复计划状态全部验证通过后，Stage 1 才完成；随后才进入可选 Stage 1.1。

## Stage 1.1：确认可分享声明

Stage 1.1 不安装、更新或删除软件。仅当本机 TSV 中存在 `pending` 或 `manual` 候选时，展示候选、迁移理由、精确版本、binaries、建议 target manager、兼容性缺口，以及 `my_setup/tooling/global-cli-migration.toml` 的完整候选 diff，然后询问：

```text
1. 把全部可自动迁移项写入可分享声明
2. 逐项选择并重新审查完整声明 diff
3. 暂不迁移，保留本机清单
```

- 选择 1 只写入已经展示且 target 已确定的项目；`manual` 项继续留在 TSV。
- 选择 2 时逐项取得 `selected`/`skipped`/`manual` 决定，重新生成并展示完整 diff，再次等待确认。
- 选择 3 不创建或修改 public TOML，把本轮候选状态保留为 `pending`；Stage 1 仍然完成。
- 合并已有 public TOML 时保留未受本次来源影响的既有声明；删除或改变既有条目必须出现在完整 diff 中并单独获准。
- public 写入成功后原子更新本机 TSV 的 `decision/status`；任一写入失败时按实际状态报告，不把未写入项标为 `declared`。
- 完成或跳过后停止，不自动进入 Stage 2。

## Stage 2 可选消费

Stage 2 只把当前 checkout 的 `my_setup/tooling/global-cli-migration.toml` 当作可选权威输入；不读取本机 TSV、Stage 1 状态或历史确认。

- 文件缺失：不询问、不报缺失，按基础 Stage 2 继续。
- 文件存在且可解析：在安装前展示条目并询问本机是全部迁移、逐项选择还是跳过。
- 用户跳过：不影响基础 Stage 2 完成；报告本机未选择可选全局 CLI。
- 用户选择：只有所选项进入本次 Stage 2 安装与验证条件。必须使用根 `install.sh` 已明确支持的声明能力；不得由 Agent 在安装器外临时运行全局安装命令。
- 当前安装器不能消费该 schema：把它报告为可选能力缺口；基础安装可在用户明确选择跳过该可选迁移后继续，不得把 ad-hoc 安装伪装成声明式迁移。
- 验证目标 package/version/binaries、命令解析 owner 与原生架构；不得用旧 NVM/旧 global home 中仍可执行的副本代替。
