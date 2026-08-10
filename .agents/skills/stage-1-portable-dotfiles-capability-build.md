# Stage 1：轻量 Dotfiles 能力建设需求

> 状态：轻量阶段需求<br>
> 日期：2026-08-09<br>
> 执行位置：Stage 0 选定的公开仓库与可选 company 仓库

## 1. 阶段定位

本阶段把 Stage 0 已确认的分析结果整理为可供其他用户和机器复用的仓库能力。核心交付是 `dump.sh`、根目录统一 `install.sh`、三个内部能力安装模块、配置目录、最小测试、默认中文 README、独立英文 README 和 CI 发布门禁。

本阶段建设能力，不在开发者真实 HOME 中安装配置或软件。

## 2. 目标

1. 固化 `dump.sh` 的软件/tooling/plugin 只读导出能力，以及 Zsh Skill 的独立脱敏证据采集能力。
2. 生成根目录统一 `install.sh`，同时承担 Stage 2 安装和 Stage 3 退役入口；`zsh`、`tooling`、`macos` 各自提供一个只由根安装器编排的内部 `install.sh`。
3. 建立 `my_setup/`、company 和 local 的轻量契约。
4. 用最小 smoke test 验证关键路径，不建设额外管理 CLI。
5. 保留 pre-commit、分离且互链的完整中英文 README 和 CI 发布门禁。

## 3. 前置条件

- Stage 0 已完成人工确认；
- 当前 public/company diff 与确认内容一致；
- public 输出不含公司信息、密钥或本机绝对路径；
- 服务和数据迁移事项已标为人工处理；
- 当前工作树冲突已由用户处理。

如果输入需要重新分析，返回 Stage 0；本阶段不重新猜测源机器状态。

### 3.1 执行前计划门

未来 Stage 1 Skill 被触发后，先只读检查 Stage 0 获准输入、public/company 工作树、现有脚本/配置/测试/文档、Stage 2/3 接口和当前验证状态；不得在盘点阶段编辑文件、运行会写入候选的采集器、安装依赖或修改真实 HOME/软件。随后向用户展示完整计划，至少包含：

- 将新增、修改或删除的精确仓库路径和模块接口；
- 根 `install.sh` 与三个内部 `install.sh` 的预期行为变化；
- 测试、pre-commit、CI、文档和依赖变化；
- 可能发生的网络或系统影响、风险、停止条件和验证方式；
- 明确不会执行的真实安装、退役、commit、push 和范围外清理。

展示后停止并等待用户明确确认，再开始编辑。执行前重新检查工作树；目标结构、输入、风险或影响范围发生实质变化时，先更新完整计划并再次等待确认。初始计划确认只授权展示范围内的 Stage 1 仓库变更，不授权 Stage 2/3 动作；任何工具自身的安全确认继续保留。

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
│   │   ├── .zprofile          # Stage 2 根据已确认修复计划生成
│   │   ├── .zshrc             # Stage 2 根据已确认修复计划生成
│   │   ├── zsh-repair-plan.md
│   │   └── plugins.toml
│   ├── macos/
│   │   ├── install.sh
│   │   └── Brewfile
│   └── tooling/
│       └── install.sh
├── tests/
│   └── smoke.zsh
├── .githooks/pre-commit
└── .github/workflows/verify.yml
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

三个能力安装模块不是额外的用户命令面：它们被根安装器加载，只暴露带能力前缀的内部 plan/apply/verify 函数，直接执行时必须拒绝并引导用户使用根目录 `install.sh`。目标结构之外不再建设额外管理 CLI、独立 migrate/retire 脚本、通用 schemas 目录、拆散的插件文件、大量场景 fixture 或长期状态目录。

Stage 1 不根据修复计划生成最终 `.zprofile` 或 `.zshrc`；这两个文件仍由 Stage 2 生成并经用户审查。Stage 1 安装器在它们缺失时必须以清楚的阻断信息停止，smoke test 则只在临时仓库中创建最小 Zsh fixture 验证安装能力。

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
- 输出目录与 `my_setup/` 和可选 company 目标结构对齐，便于 AI 就地审阅；
- 有可回放原生 Dump 时优先使用；只有结构化 List/Status 时经脱敏写入 `tmp/dump.md`，由 AI 转成目标配置；
- 强制把子进程临时文件和可重定向缓存写入执行期间的 `tmp/.runtime/`，结束前清理，不继承仓库外 `TMPDIR`；Homebrew 只读使用已有 metadata cache 时禁用 refresh、自动更新和 description 查询；
- 导出完成后由 `review-exported-dotfiles` Skill 调整候选条目，并为每个直接期望项目补齐功能、最佳实践、修改级别、建议、归属和验证评论；
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

根安装器是唯一公开入口，负责参数解析、跨能力前置检查、汇总变更摘要、一次默认 `N` 的 `y/N` 确认、按顺序调用内部模块以及最终汇总验证。内部职责固定为：

- `my_setup/zsh/install.sh`：Zsh 入口备份和 symlink、插件安装及 Zsh 验证；
- `my_setup/tooling/install.sh`：mise、uv 等 tooling 安装及版本验证；
- `my_setup/macos/install.sh`：Homebrew、personal/company Brewfile 安装及来源与架构验证。

内部模块不得独立提示用户、重复确认、解析根命令面或自动调用其他模块；被直接执行时必须安全失败。普通安装仍只产生一次整体摘要和一次确认。

根安装器的真实 apply 顺序固定为 `macos → tooling → zsh → pre-commit hook → verify`，避免软件安装失败时提前切换真实 Zsh 入口。

### 6.1 无参数安装

执行时：

1. 验证当前仓库、`my_setup/` 和可选 company 路径；
2. 检查原生 `arm64`、本地 Zsh 入口和 local 权限；
3. 计算 Zsh backup/symlink、Brewfile、tooling、插件变更；
4. 展示简短摘要并以默认 `N` 的 `y/N` 确认；
5. 为已有本地 `.zsh` 文件或 symlink 创建副本；
6. 建立指向 `my_setup/zsh/` 的 `~/.zprofile` 和 `~/.zshrc` symlink；
7. 为当前公开仓库配置受管的 `core.hooksPath=.githooks`；
8. 安装 personal/company Brewfile、tooling、mise/uv 和固定 revision 插件；
9. 调用同一脚本的验证逻辑。

安装器不得打印、复制或持久化 `parameters.zsh` 内容；只允许检查文件类型、owner、权限和无输出语法。

### 6.2 验证

`./install.sh verify` 至少检查：

- Zsh 语法和两种常见启动场景；
- symlink 目标；
- company → personal → local 加载顺序；
- local `0700/0600` 权限及未被 Git 跟踪；
- Brewfile、tooling 和 `plugins.toml` 语法；
- 命令实际路径、版本和架构；
- PATH 中没有活动 Intel Homebrew；
- 再次安装不会重复破坏 Zsh 入口。

### 6.3 退役入口

`install.sh` 同时实现 Stage 3 的 `retire` 和 `retire --apply`，但不得从普通安装自动进入退役。具体行为以 [Stage 3 Skill](./stage-3-intel-homebrew-retirement/SKILL.md) 为准。

## 7. 配置文件约定

### 7.1 Zsh

- `my_setup/zsh/.zprofile` 和 `.zshrc` 是唯一真实 personal 入口；
- company 最多一个 `zsh/company.zsh`；
- local 最多一个 `parameters.zsh`；
- `.zshrc` 固定按 company → personal → local 执行；
- `.zshrc` 使用 `dotfiles: company`、`dotfiles: personal`、`dotfiles: local` 三个固定标记让安装器验证上述顺序；
- `.zshrc` 为每个启用插件保留 `dotfiles: plugin <name>` 标记，并按合并后的 `load_order` 递增排列；
- company 不依赖 personal 中后续才定义的 alias/function；
- local 只保存不可公开参数，不保存软件选择。

### 7.2 插件

personal/company 各自最多一份 `zsh/plugins.toml`。每个插件条目至少包含：

- 名称；
- source；
- 固定 tag 或 commit；
- enabled；
- 加载顺序。

安装器合并时按 company → personal 处理，同名冲突由 personal 决定，local 不参与。

### 7.3 软件与 tooling

- personal/company 各自使用 Brewfile 表达软件期望；
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

1. 四阶段流程；
2. Stage 0 分别使用 Zsh 分析 Skill、`dump.sh` 和导出配置 Review Skill；
3. 无参数 `install.sh` 会在确认后安装；
4. local 可以保存密钥值但永不进入 Git；
5. `retire` 不会被普通安装触发；
6. 服务和数据需要人工处理。

## 9. pre-commit

仓库跟踪 `.githooks/pre-commit`。它至少运行快速检查：

- Markdown 和 shell 基础格式；
- `zsh -n`；
- public 密钥与公司信息扫描；
- 禁止的 Intel 运行时路径；
- `README.md` 与 `README.en.md` 的章节结构一致性及靠前互链。

hook 不安装依赖、不修改用户文件；检查工具缺失时给出明确失败或安装提示。

## 10. 测试与 CI 发布门禁

本地只保留最小 `tests/smoke.zsh`，CI 可以复用同一验证入口。CI 至少覆盖：

- `dump.sh` 只读行为；
- Zsh 证据采集脚本不 source 启动文件、不输出值，只写 `tmp/zsh-evidence.md`；
- Zsh 和脚本语法；
- 安装摘要与默认 `N` 行为；
- 临时 HOME 中的 Zsh 副本和 symlink；
- 安装幂等与 `verify`；
- personal/company 插件和软件配置合并；
- local 权限及不读取密钥内容；
- `retire` 只读、非 TTY 阻断和未知数据保护；
- public 工作树密钥/公司信息扫描；
- 使用固定版本扫描器检查公开仓库当前内容和完整 Git 历史；
- `README.md` 与 `README.en.md` 的中英文一致性及靠前互链。

发布必须等待 pre-commit 等价检查和 CI 通过。不得因完整 CI 而重新引入管理 CLI、多套 schema 或复杂 fixture。

## 11. 完成条件

- [ ] 目标结构轻量且无被删除的旧组件；
- [ ] `dump.sh` 只导出软件/tooling/plugin，Zsh 采集与导出 Review 已拆分为独立 Skill；
- [ ] 根目录 `install.sh` 具备安装、verify 和 retire 命令，三个内部能力安装模块只由根入口编排；
- [ ] 安装默认展示摘要并使用 `y/N`；
- [ ] company/personal/local 加载顺序正确；
- [ ] 插件已收敛为单一 `plugins.toml`；
- [ ] local 密钥不会被脚本、测试或 CI 读取；
- [ ] smoke test、pre-commit、分离且互链的中英文 README 和 CI 通过；
- [ ] 未修改开发者真实 HOME 或软件；

完成后进入 [Stage 2](./stage-2-target-machine-configuration-and-software-migration/SKILL.md)。

## 12. 未来 Skill 接口

未来 Skill 名：`stage-1-portable-dotfiles-capability-build`。

Skill 只负责建设或更新上述轻量仓库能力。它不得进入真实 HOME 执行 Stage 2，也不得扩张出新的管理 CLI、状态系统或独立迁移脚本。
