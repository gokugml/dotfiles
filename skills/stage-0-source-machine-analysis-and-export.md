# Stage 0：本地分析与配置导出需求

> 状态：轻量阶段需求<br>
> 日期：2026-08-09<br>
> 执行位置：提供当前环境的源机器

## 1. 阶段定位

本阶段先通过 `dump.sh` 调用工具原生 Dump/List，一次性收集本机 Zsh、软件和工具状态，并在当前仓库 `tmp/` 生成与目标目录同构的候选文件。随后由 AI 就地审阅候选文件、调整条目、补充逐项评论并完成自检，再由用户集中确认一次。它对应流程图中的“本地分析”阶段。

执行前读取 [共用契约](./stage-common-contract.md)。只有需要解释具体 Zsh 问题时，才按需读取 [Zsh 配置诊断与优化指南](./zshrc-diagnostics-guide.md) 的相关章节。

## 2. 目标

1. 只读收集当前 Zsh source 链和关键软件状态。
2. 生成脱敏、可执行的 Zsh 修复计划，但不直接修改真实 Zsh。
3. 优先使用工具原生 Dump 或结构化只读输出，把 Brewfile、tooling、mise/uv 和插件现状整理为可分享的期望状态草稿。
4. 按 personal/company/local/retire/manual 分类内容。
5. 由 AI 自检安全、可移植性和 Intel→ARM 替代关系。
6. 用户一次审查正式目录与 AI 审阅后候选目录的全部 diff 后，才写入公开或 company 工作树。

## 3. 非目标

- 不修改真实 `~/.zprofile`、`~/.zshrc` 或 symlink。
- 不安装、升级或删除软件。
- 不读取、复制或打印 `local/parameters.zsh` 中的密钥值。
- 不创建远程仓库、改变可见性、commit 或 push。
- 不生成最终 Zsh 文件；最终 `.zprofile`、`.zshrc` 和 `company.zsh` 在 Stage 2 由 AI 按修复计划生成。
- 不建立审批状态机或长期运行状态。

## 4. 输出位置

默认自动识别：

- 当前 Git 仓库是公开仓库；
- personal 固定映射到当前仓库 `my_setup/`；
- local 固定为 `~/.config/dotfiles/local/parameters.zsh`；
- company 是可选独立仓库。

只有当前目录不是有效 Git 仓库、存在多个可能根目录，或 company 需要启用但无法唯一定位时，才集中询问一次。

## 5. 主流程

```text
验证当前仓库和只读边界
  → 运行 ./dump.sh
    → 原生 Dump/List 写入仓库 tmp/ 候选树
      → AI 就地分析、调整条目并补充评论
        → AI 自检
          → 展示统一摘要和正式目录 → 候选目录 diff
            → 用户一次确认
              → 写入获准文件、清理候选文件并停止
```

用户拒绝或要求调整时，只更新 `tmp/` 候选文件并重新展示差异，不写入目标文件。用户确认或取消后，只清理本次已知候选文件，不清空 `tmp/` 中的未知内容。

## 6. `dump.sh` 需求

### 6.1 Zsh 证据

只读收集：

- `.zshenv`、`.zprofile`、`.zshrc`、`.zlogin` 及它们的 source 链；
- 文件类型、权限、symlink 目标和实际加载场景；
- PATH/fpath、命令来源、补全、OMZ、插件、alias、function 和 wrapper；
- Intel/ARM 路径、重复初始化、语法问题和明显性能问题；
- 环境变量名称与疑似密钥所在位置，但不收集值。

### 6.2 软件与工具证据

只读收集：

- ARM/Intel Homebrew 的 tap、formula、leaf、cask 和 service 名称；
- 已有 Brewfile；
- mise、uv、Bun、Node、pnpm、Go、Python、NVM、pyenv、pipx 等状态；
- 外部 Zsh 插件的来源、revision 和加载顺序；
- 已知服务或应用数据的存在性，只记录“需要人工处理”，不读取数据内容。

### 6.3 原生导出优先级

采集器按以下顺序选择能力：

1. 工具提供只读、可回放的原生 Dump 时，直接写入 `tmp/` 下与目标位置一致的候选文件；
2. 工具只有只读结构化 List/Status 时，保留允许字段到 `tmp/dump.md`，由 AI 转成目标格式；
3. 原生命令会维护或写入仓库外状态时，不调用该命令，退化为只读元数据检查；
4. 只有普通文本状态时，只收集最小版本、来源和所有权证据，未知信息标为 `manual`。

至少按此规则处理：

- Homebrew 使用 `brew bundle dump --no-describe` 直接生成候选 Brewfile；禁用 API/自动更新，原生描述由 AI 的逐项评论补足；
- mise 使用只读 JSON 列出已安装版本、requested version、backend 和配置来源类别，再由 AI 生成明确版本的 TOML；
- uv 使用 JSON 列出已安装 Python；`uv tool list` 只有确认不会写入工具目录时才使用，否则只读检查 uv 工具元数据；
- pipx 存在时使用其可回放 JSON 快照作为迁移输入，不把该快照写入正式仓库；
- pnpm/npm、Go、Bun、NVM、pyenv 和插件使用各自最接近的只读结构化能力，不能把普通文本列表伪装为可回放 Dump。

所有本次输出固定写在当前仓库：

```text
tmp/
├── dump.md
├── my_setup/
│   ├── macos/Brewfile
│   ├── tooling/
│   └── zsh/
└── company/              # 只有存在公司增量时生成
```

`tmp/` 必须被 Git 忽略。未经 AI 审阅的原生 Dump 不能直接写入正式目录；确认或取消后清理本次候选文件。

工具子进程的临时文件和可重定向缓存必须强制写入 `tmp/.runtime/`，不能继承仓库外的 `TMPDIR`。Homebrew 可以只读使用已有 metadata cache，但必须禁用 API refresh、自动更新和原生 description 查询；不得向仓库外 cache 写入。`tmp/.runtime/` 只在 `dump.sh` 执行期间存在，命令结束前清理。

### 6.4 安全边界

`dump.sh` 必须：

- 默认只读，不提供 apply、install 或 delete 模式；
- 不 source 用户 Zsh 文件来取得变量值；
- 不读取 Keychain 或 `parameters.zsh` 内容；
- 不保存完整环境、shell 历史、token、内部账号或机器标识；
- 在输出中对用户目录、公司域名和本机路径做脱敏；
- 只管理 `tmp/dump.md`、`tmp/my_setup/`、执行期间的 `tmp/.runtime/` 和本次明确生成的可选 `tmp/company/`，不递归清空整个 `tmp/`；
- 无法安全判断时标记 `manual`，不得猜测。

## 7. AI 分析和草稿

### 7.1 Zsh 修复计划

修复计划至少说明：

- 当前行为和问题；
- 建议保留、改写、替代或移除的内容；
- 目标归属：personal、company、local、retire 或 manual；
- 预期生成位置；
- 简短验证方式。

公开安全的计划写入：

```text
my_setup/zsh/zsh-repair-plan.md
```

如果存在公司专属 Zsh 事项，在获授权的 company 仓库单独写入：

```text
zsh/zsh-repair-plan.md
```

公开计划不得出现公司内容、密钥名对应的值或本机绝对路径。local 密钥值不进入任何修复计划。

### 7.2 软件配置草稿

按实际内容生成或更新：

```text
my_setup/macos/Brewfile
my_setup/tooling/*
my_setup/zsh/plugins.toml

<company-repository>/macos/Brewfile
<company-repository>/tooling/*
<company-repository>/zsh/plugins.toml
```

要求：

- AI 直接审阅 `tmp/` 候选文件，可以删除依赖项、替换旧工具、增加已确认项目或移动 company 增量；
- Brewfile 只包含希望保留或安装的直接期望项；
- tooling 使用明确版本，不写 `latest`；
- personal 和 company 各自最多一份 `plugins.toml`；
- company 文件只保存公司增量；
- local 不保存 Brewfile、tooling 或插件选择；
- 已有 ARM 替代或明确淘汰的 Intel 项进入退役建议，不写回运行时配置；
- 服务和应用数据只进入人工处理提示。

工具原生描述在不触发仓库外写入时保留；为避免 metadata refresh 而关闭原生描述时，由 AI 补齐等价的功能说明。每个直接期望项目都由 AI 在相邻评论中补齐：

- 功能；
- 最佳实践；
- 修改级别；
- 建议；
- 归属；
- 验证方式。

有效配置使用 `AI-REVIEW` 评论。被替代或移除的项目不保留有效配置行，改用同一文件内的 `AI-RETIRE` 评论；不为此增加独立退役说明文件。评论不得破坏 Brewfile、TOML 或版本文件的原生解析。

`parameters.zsh` 可以由用户保存密钥值和本机参数，但 Stage 0 不自动生成、覆盖或审查其内容。

## 8. AI 自检

展示给用户前至少检查：

- public 输出不含公司信息、本机路径或密钥；
- company 输出未误入 public；
- personal/company 软件声明无明显重复和所有权冲突；
- Zsh 计划不保留活动 Intel PATH 或重复 `compinit`；
- 插件来源和 revision 明确；
- 每个直接期望项目都有完整、相邻且与有效配置一致的 AI 评论；
- 原生 Dump 与 AI 调整的职责清晰，未经审阅的机器快照未直接成为正式配置；
- 所有未知数据和无法判断的替代关系已标记为 manual；
- 草稿只修改预期目标文件。

自检结果直接并入审查摘要，不生成独立审批表。

## 9. 用户一次确认

集中展示：

- Zsh 修复计划摘要；
- public 和 company 的目标路径；
- 每个新增、修改或删除文件的 diff；
- 原生 Dump 到 AI 审阅后目标状态的调整摘要；
- 将保留到 local 的参数类别，但不显示值；
- Stage 2 将执行的安装内容；
- Stage 3 的退役建议；
- 需要人工处理的服务和数据。

只有用户明确确认后才把草稿写入目标工作树。确认只代表接受可逆的仓库草稿，不代表授权安装、push 或退役。

## 10. 阶段产物与完成条件

阶段产物只有：

- public/company 的 Zsh 修复计划；
- 经确认的软件和插件配置；
- 最终 Git diff；
- 对 local、服务和数据的脱敏人工提示。

完成条件：

- [ ] `dump.sh` 未修改真实配置或软件；
- [ ] 原生 Dump/List 结果已写入当前仓库被忽略的 `tmp/` 候选树；
- [ ] AI 已完成 Zsh 与软件联合分析和自检；
- [ ] 每个直接期望项目已补齐结构化 AI 评论；
- [ ] 用户已一次确认全部目标 diff；
- [ ] public/company/local 边界正确；
- [ ] 未读取或泄露 local 密钥值；
- [ ] 未生成最终 Zsh、未安装软件、未执行 commit/push。

完成后停止，进入 [Stage 1](./stage-1-portable-dotfiles-capability-build.md)。

## 11. 未来 Skill 接口

未来 Skill 名：`stage-0-source-machine-analysis-and-export`。

触发语义是“分析当前 Zsh 并 dump 本地配置”。Skill 应直接编排 `dump.sh → AI 就地审阅 tmp 候选文件 → AI 自检 → 用户一次确认 → 写入获准文件并清理候选文件`，不得让 Shell 脚本调用 AI，也不得重新引入双审批或长期状态机。
