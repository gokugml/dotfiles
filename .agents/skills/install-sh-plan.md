# install.sh 与轻量 Dotfiles 能力建设计划

> 状态：独立能力需求，不占用 Stage 编号<br>
> 日期：2026-08-10<br>
> 执行位置：Stage 0 选定的公开仓库与可选 shared 仓库

## 1. 阶段定位

本计划建设可供其他用户和机器复用的仓库能力。核心交付是 `dump.sh`、根目录统一 `install.sh`、三个内部能力安装模块、配置目录、最小测试、默认中文 README、独立英文 README，以及与 Stage 2 分离的一次性仓库开发初始化和 CI。

本计划只描述能力建设，不属于 Stage 0–3 主流程，也不在开发者真实 HOME 中安装配置或软件。Stage 2 在任意目标机器只以当前 checkout 为输入，调用本计划定义的 `install.sh`；它不读取 Stage 0/1 交接或 `zsh-repair-plan.md`。

## 2. 目标

1. 固化 `dump.sh` 的软件/tooling/plugin 只读导出能力，以及 Zsh Skill 的独立脱敏证据采集能力。
2. 生成根目录统一 `install.sh`，同时承担 Stage 2 安装和 Stage 3 退役入口；`zsh`、`tooling`、`macos` 各自提供一个只由根安装器编排的内部 `install.sh`。
3. 建立 `my_setup/`、shared 和 local 的轻量契约。
4. 用最小 smoke test 验证关键路径，不建设额外管理 CLI。
5. 用独立的 `./.githooks/install.sh` 一次性准备固定开发检查并安装 Git 默认 `.git/hooks/pre-commit`；pre-commit 与 CI 不进入 Stage 2。

## 3. 前置条件

- 当前 checkout 已包含准备部署的 macOS/tooling 声明与可选 Zsh 声明；
- 当前 public/shared 工作树没有未解决冲突；
- public 输出不含 shared 仓库专属信息、密钥或本机绝对路径；
- 服务和数据迁移事项已标为人工处理；
- 当前工作树冲突已由用户处理。

如果仓库声明残缺或无法解析，报告精确文件并停止；安装器不调用 Stage 0/1，也不猜测源机器状态。

### 3.1 执行前计划门

实现或更新本计划前，先只读检查当前 checkout 的 public/shared 声明、工作树、现有脚本/配置/测试/文档、Stage 2/3 接口和当前验证状态；不得在盘点阶段编辑文件、运行会写入候选的采集器、安装依赖或修改真实 HOME/软件。随后向用户展示完整计划，至少包含：

- 将新增、修改或删除的精确仓库路径和模块接口；
- 根 `install.sh` 与三个内部 `install.sh` 的预期行为变化；
- 测试、pre-commit、CI、文档和依赖变化；
- 可能发生的网络或系统影响、风险、停止条件和验证方式；
- 明确不会执行的真实安装、退役、commit、push 和范围外清理。

展示后停止并等待用户明确确认，再开始编辑。执行前重新检查工作树；目标结构、输入、风险或影响范围发生实质变化时，先更新完整计划并再次等待确认。初始计划确认只授权展示范围内的仓库能力变更，不授权 Stage 1 写入 Zsh 目标或 Stage 2/3 动作；任何工具自身的安全确认继续保留。

## 4. 目标结构

公开仓库：

```text
dotfiles/
├── README.md                    # 默认中文文档
├── README.en.md                 # 独立英文文档
├── LICENSE
├── dump.sh
├── install.sh
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
│       └── install.sh
├── tests/
│   └── smoke.zsh
├── .githooks/
│   ├── install.sh              # 一次性仓库开发初始化
│   └── pre-commit              # 仓库跟踪的实际检查入口
└── .github/workflows/verify.yml
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

安装器受管的本机状态：

```text
${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/
└── intel_to_be_retired.tsv   # Apple Silicon 上残留 Intel 软件/路径的 Stage 2 → Stage 3 交接
```

三个能力安装模块不是额外的用户命令面：它们被根安装器加载，只暴露带能力前缀的内部 plan/apply/verify 函数，直接执行时必须拒绝并引导用户使用根目录 `install.sh`。除上述精确交接文件外，不再建设额外管理 CLI、独立 migrate/retire 脚本、通用 schemas 目录、拆散的插件文件、大量场景 fixture 或长期状态目录。

本计划及其安装器不生成最终 `zprofile`/`.zprofile`、`zshrc`/`.zshrc` 或 `shared.zsh`，也不读取任何 `zsh-repair-plan.md`。目标机最小 checkout 是根安装器、`my_setup/macos/` 与 `my_setup/tooling/`；`my_setup/zsh/` 整体可选。Zsh 启用时必须接受 `zprofile` + `zshrc` 或 `.zprofile` + `.zshrc` 中恰好一套完整来源；两套并存、混搭或残缺时，在确认前阻断，不猜优先级，也不生成副本。smoke test 只能在临时仓库中创建最小 fixture。

## 5. `dump.sh`

`dump.sh` 满足 Stage 0 编排 Skill 的只读边界，并作为面向其他用户的软件、tooling 和插件稳定导出入口：

```text
./dump.sh
```

实现要求：

- 使用 macOS 自带工具和可选的已安装管理器；
- 不读取或分析 Zsh 启动文件；Zsh 证据由 `analyze-zsh-configuration` Skill 内部脚本独立采集；
- 缺少某个工具时记录 `not-installed`，不自动安装；
- 原生 Dump/List 只写当前仓库被 Git 忽略的 `tmp/` 候选树，不使用仓库外临时目录；
- 输出目录与 `my_setup/` 和可选 shared 目标结构对齐，便于 AI 就地审阅；
- 有可回放原生 Dump 时优先使用；只有结构化 List/Status 时经脱敏写入 `tmp/dump.md`，由 AI 转成目标配置；
- 强制把子进程临时文件和可重定向缓存写入执行期间的 `tmp/.runtime/`，结束前清理，不继承仓库外 `TMPDIR`；Homebrew 只读使用已有 metadata cache 时禁用 refresh、自动更新和 description 查询；
- 导出完成后由 `review-exported-dotfiles` Skill 调整候选条目，并为每个直接期望项目补齐一句话描述、最佳实践、修改级别、建议、归属和验证评论；
- 不读取 local 密钥值，不修改 HOME，不调用 `install.sh`；
- 只清理本次明确生成的候选文件，不清空 `tmp/` 中的未知内容；
- 退出时清楚区分成功、部分证据缺失和安全失败。

## 6. 根目录统一 `install.sh`

命令面固定为：

```text
./install.sh
./install.sh verify
./install.sh retire
./install.sh retire --apply
```

无参数 `install.sh` 等于安装 apply。

根安装器是唯一公开入口，负责参数解析、跨能力前置检查、发现当前 checkout 中的模块、汇总每个精确目标的变更摘要、一次默认 `N` 的 `y/N` 确认、按顺序调用内部模块以及最终汇总验证。内部职责固定为：

- 可选 `my_setup/zsh/install.sh`：目录完整 checkout 时负责 Zsh 入口备份和 symlink、插件安装及 Zsh 验证；
- `my_setup/tooling/install.sh`：mise、uv 等 tooling 安装及版本验证；
- `my_setup/macos/install.sh`：Homebrew、personal/shared Brewfile 安装、来源与架构验证，以及 Apple Silicon 上残留 Intel 项的确定性交接清单。

macOS 与 tooling 模块是最小 checkout 的必需项；Zsh 目录和内部入口都不存在时明确跳过，部分存在时阻断。内部模块不得独立提示用户、重复确认、解析根命令面或自动调用其他模块；被直接执行时必须安全失败。普通安装仍只产生一次整体摘要和一次确认。

根安装器的真实 apply 顺序固定为 `macos → tooling → 可选 zsh → verify`，避免软件安装失败时提前切换真实 Zsh 入口。它不发现、安装或验证 Git hook，也不运行或报告 smoke、pre-commit、CI。

### 6.1 无参数安装

执行时：

1. 验证当前 checkout、必需 macOS/tooling 模块、可选完整 Zsh 模块和可选 shared 路径；
2. 检查 macOS 原生硬件架构、当前进程是否运行在 Rosetta 下、本地 Zsh 入口和 local 权限；
3. 计算并展示每个启用模块的仓库 source、本机 target 和 action，包括 tooling symlink、Brewfile、mise/uv runtime 和可选 Zsh/plugin；
4. 展示简短摘要并以默认 `N` 的 `y/N` 确认；
5. 为已有本地 `.zsh` 文件或 symlink 创建副本；
6. 仅当 Zsh 模块启用时，将唯一仓库来源组建立为固定 HOME 入口 `~/.zprofile` 和 `~/.zshrc` symlink；
7. Intel Mac 使用 `/usr/local` Homebrew，Apple Silicon 原生会话使用 `/opt/homebrew` Homebrew，安装 personal/shared Brewfile、tooling、mise/uv 和固定 revision 插件；
8. 调用同一脚本的验证逻辑，确认全部声明项安装到当前系统原生目标；Apple Silicon 上若仍有 Intel 残留，原子生成 `intel_to_be_retired.tsv`。

安装器不得打印、复制或持久化 `parameters.zsh`、`integrations.zsh` 内容；只允许检查文件类型、owner、权限和无输出语法。

### 6.2 验证

`./install.sh verify` 输出两个独立结论。A“安装完整性”至少检查：

- Zsh 模块启用时检查语法和两种常见启动场景；未 checkout 时不要求 Zsh；
- symlink 目标；
- integrations pre → shared → personal → parameters → integrations post 阶段；
- local `0700/0600` 权限及未被 Git 跟踪；
- Brewfile、tooling 和 `plugins.toml` 语法；
- 命令实际路径、版本和架构；
- Homebrew 与全部受管命令/配置路径符合当前机器原生架构：Intel 使用 `/usr/local`，Apple Silicon 使用 `/opt/homebrew`；另一架构路径可以残留，但不得成为受管命令或 symlink 的最终目标；
- Apple Silicon 的 Rosetta 会话被阻断，不因进程显示 `x86_64` 而改用 Intel Homebrew；
- 安装摘要中每个 Zsh/tooling symlink、Brewfile 项、mise/uv runtime 和固定 revision 插件都在精确目标存在且来源、版本、revision 与架构正确；
- 再次安装不会重复破坏 Zsh 入口或其他受管 symlink。

B“Intel 退役交接”仅适用于 Apple Silicon：

- 如果只读盘点发现仍存在 Intel Homebrew 项、全局 runtime/plugin、解析到 `/usr/local` 的旧命令或残留 PATH 条目，确定性生成 `${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/intel_to_be_retired.tsv`；
- 父目录为 `0700`、文件为 `0600`，使用安装器固定标记、原子替换和稳定排序；固定 TSV 字段为 `kind`、`manager`、`name`、`version`、`path`、`architecture`、`reason`；
- 只记录管理器清单、命令解析和已知全局根能够确认的精确项目/路径，不递归枚举 `/usr/local`；service/data、项目依赖和未知项必须标为保留或待人工处理；
- 清单是 Stage 3 线索而非删除授权。Intel 残留本身不使安装完整性失败；清单无法安全生成时 B 失败，并阻止 Stage 2 完成；
- 没有 Intel 残留时不保留旧候选清单，只能删除或清空带安装器固定标记的旧文件，未知同名文件必须阻断；Intel Mac 不生成清单。

`verify` 除原子维护上述本机状态文件外不得产生安装、卸载或其他配置写入。

### 6.3 退役入口

`install.sh` 同时实现 Stage 3 的 `retire` 和 `retire --apply`，但不得从普通安装自动进入退役。Stage 3 可以读取 `intel_to_be_retired.tsv` 作为参考，仍须实时重新盘点并逐项验证；具体行为以 [Stage 3 Skill](./stage-3-intel-homebrew-retirement/SKILL.md) 为准。

## 7. 配置文件约定

### 7.1 Zsh

- `my_setup/zsh/zprofile` + `zshrc` 与 `.zprofile` + `.zshrc` 是两种受支持的 personal 仓库命名；必须恰好完整存在一组，且没有另一组残留；
- HOME 启动入口始终是 `~/.zprofile` 和 `~/.zshrc`，分别指向已解析的仓库来源；
- shared 最多一个 `zsh/shared.zsh`；
- local 最多各一个 `parameters.zsh` 与 `integrations.zsh`；
- `.zshrc` 的声明式配置固定按 shared → personal → parameters 执行，单一 integrations 通过 zprofile/zshrc 的 pre/post 阶段包围；
- `.zshrc` 使用 `dotfiles: shared`、`dotfiles: personal`、`dotfiles: local` 三个固定标记让安装器验证上述顺序；
- 使用 `dotfiles: local-integrations <phase>` 标记让安装器验证存在的 pre/post loader 位置；
- `.zshrc` 为每个启用插件保留 `dotfiles: plugin <name>` 标记，并按合并后的 `load_order` 递增排列；
- shared 不依赖 personal 中后续才定义的 alias/function；
- `parameters.zsh` 只保存不可公开参数；`integrations.zsh` 只保存第三方安装器功能块；local 不保存软件期望状态。

### 7.2 插件

personal/shared 各自最多一份 `zsh/plugins.toml`。每个插件条目至少包含：

- 名称；
- source；
- 固定 tag 或 commit；
- enabled；
- 加载顺序。

安装器合并时按 shared → personal 处理，同名冲突由 personal 决定，local 不参与。

### 7.3 软件与 tooling

- personal/shared 各自使用 Brewfile 表达软件期望；
- tooling 文件按实际管理器保存，不为统一外观创建额外 schema；
- 版本必须明确；
- Homebrew、mise 和 uv 的职责遵循共用契约；
- 服务和数据只检测并报告，不放入自动迁移逻辑。

## 8. README

文档拆分为两份：根目录 `README.md` 是默认中文文档，`README.en.md` 是独立英文文档。两份文件都必须在标题后的靠前位置链接另一种语言，并保持：

- 相同章节结构；
- 相同命令示例；
- 相同安全警告；
- 相同阶段边界。

至少解释：

1. 四阶段流程，以及本计划是阶段外的安装能力建设需求；
2. Stage 0 分别使用 Zsh 分析 Skill、`dump.sh` 和导出配置 Review Skill，并先为每个工具给出一句话描述；
3. Stage 1 可以独立生产 Zsh 文件，但其 repair plan 与状态不是 Stage 2 输入；
4. Stage 2 从当前 checkout 独立部署必需 macOS/tooling 与可选 Zsh，按原生硬件架构选择 Intel `/usr/local` 或 Apple Silicon `/opt/homebrew`，把所有摘要目标安装完毕；Apple Silicon 的 Intel 残留进入本机 `intel_to_be_retired.tsv`，不阻止原生安装完成；
5. local parameters 可以保存密钥值，local integrations 可以保存第三方功能块，二者都永不进入 Git；
6. Stage 3 只适用于 Apple Silicon，且 `retire` 不会被普通安装触发；
7. 服务和数据需要人工处理。

## 9. 一次性仓库开发初始化与 pre-commit

仓库开发者在每个新 checkout 中显式运行一次：

```text
./.githooks/install.sh
```

该命令不属于 Stage 0–3，不由根 `install.sh` 调用。它负责：

- 要求当前 checkout 未配置任意作用域的 `core.hooksPath`；发现自定义路径时在写入和依赖安装前阻断，不擅自清除；
- 通过 mise 独立准备固定的 Gitleaks `8.30.0`，不把该 CI/开发工具写入 Stage 2 tooling 声明；
- 把带固定归属标记的轻量 shim 安装到 Git 默认 `.git/hooks/pre-commit`；普通 checkout 使用 `.git/hooks`，不定义替代路径；
- 未知同名 hook 不覆盖，已受管 hook 可幂等刷新；
- shim 调用仓库跟踪的 `.githooks/pre-commit`，因此 checkout 移动后仍按当前仓库根定位检查入口。

仓库跟踪的 `.githooks/pre-commit` 至少运行快速检查：

- Markdown 和 shell 基础格式；
- `zsh -n`；
- public 密钥与 shared 仓库专属信息扫描；
- 与目标机器原生架构不匹配的 Homebrew 运行时路径，以及 Apple Silicon 上的 Rosetta fallback；
- `README.md` 与 `README.en.md` 的章节结构一致性及靠前互链。

hook 本身不安装依赖、不修改用户文件；固定工具缺失时要求重新运行一次性初始化命令。

## 10. 测试与 CI 状态报告

本地只保留最小 `tests/smoke.zsh`，CI 可以复用同一验证入口。CI 至少覆盖：

- `dump.sh` 只读行为；
- Zsh 证据采集脚本不 source 启动文件、不输出值，只写 `tmp/zsh-evidence.md`；
- Zsh 和脚本语法；
- 安装摘要与默认 `N` 行为；
- Intel `/usr/local` 与 Apple Silicon `/opt/homebrew` 的路径选择，以及 Apple Silicon Rosetta 会话阻断；
- 临时 HOME 中的 Zsh 副本和 symlink；
- 安装幂等与 `verify`；
- A 安装完整性与 B `intel_to_be_retired.tsv` 的生成、权限、稳定 schema、原子更新、无残留时清理和“不构成删除授权”边界；
- personal/shared 插件和软件配置合并；
- local 两个可选文件的权限、语法及不读取正文；
- 源/目标 Zsh 功能块清单和缺块失败回归测试；
- `retire` 只读、非 TTY 阻断和未知数据保护；
- public 工作树密钥/shared 仓库专属信息扫描；
- 使用固定版本扫描器检查公开仓库当前内容和完整 Git 历史；
- `README.md` 与 `README.en.md` 的中英文一致性及靠前互链。

smoke、pre-commit 与 CI 只表达仓库开发质量，不由 Stage 2 采集、运行或报告，也不参与 Stage 2 输入和完成判定。不得因完整 CI 而重新引入管理 CLI、多套 schema 或复杂 fixture。

## 11. 完成条件

- [ ] 目标结构轻量且无被删除的旧组件；
- [ ] `dump.sh` 只导出软件/tooling/plugin，Zsh 采集与导出 Review 已拆分为独立 Skill；
- [ ] 根目录 `install.sh` 具备安装、A/B verify 和 retire 命令，三个内部能力安装模块只由根入口编排；
- [ ] 安装默认展示摘要并使用 `y/N`；
- [ ] shared/personal/local 加载顺序正确；
- [ ] 插件已收敛为单一 `plugins.toml`；
- [ ] local 密钥不会被脚本、测试或 CI 读取；
- [ ] `./.githooks/install.sh` 可在默认 `.git/hooks/pre-commit` 安全、幂等地完成一次性仓库开发初始化，且不设置 `core.hooksPath`；
- [ ] smoke test、pre-commit、分离且互链的中英文 README 和 CI 独立工作，不进入 Stage 2；
- [ ] 未修改开发者真实 HOME 或软件；

根安装器与三个内部模块必须具备当前机器所需的精确目标安装、A/B verify 和安全交接能力后，才用于 [Stage 2](./stage-2-target-machine-configuration-and-software-migration/SKILL.md) 真实安装。仓库开发初始化与 CI 走独立命令和 workflow，不改变 `Stage 0 → Stage 1 → Stage 2 → Stage 3` 的主流程。

## 12. 计划边界

本文件是 `install.sh` 与相邻轻量仓库能力的实现计划，不是 Stage Skill。按本计划建设或更新能力时，不得进入真实 HOME 执行 Stage 1/2，也不得扩张出新的管理 CLI、超出 `intel_to_be_retired.tsv` 的状态系统或独立迁移脚本。
