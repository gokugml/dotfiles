# Stage 0：本地分析与配置导出需求

> 状态：轻量阶段需求<br>
> 日期：2026-08-09<br>
> 执行位置：提供当前环境的源机器

## 1. 阶段定位

本阶段通过 `dump.sh` 一次性收集本机 Zsh、软件和工具状态，由 AI 同时完成 Zsh 分析、配置整理和自检，再由用户集中确认一次。它对应流程图中的“本地分析”阶段。

执行前读取 [共用契约](./stage-common-contract.md)。只有需要解释具体 Zsh 问题时，才按需读取 [Zsh 配置诊断与优化指南](./zshrc-diagnostics-guide.md) 的相关章节。

## 2. 目标

1. 只读收集当前 Zsh source 链和关键软件状态。
2. 生成脱敏、可执行的 Zsh 修复计划，但不直接修改真实 Zsh。
3. 把 Brewfile、tooling、mise/uv 和插件现状整理为可分享的期望状态草稿。
4. 按 personal/company/local/retire/manual 分类内容。
5. 由 AI 自检安全、可移植性和 Intel→ARM 替代关系。
6. 用户一次审查全部 diff 后，才写入公开或 company 工作树。

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
    → AI 分析 Zsh 并整理软件配置
      → AI 自检
        → 展示统一摘要和 diff
          → 用户一次确认
            → 写入获准文件并停止
```

用户拒绝或要求调整时，只更新草稿并重新展示差异，不写入目标文件。

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

允许原生 dump 命令把原始结果写入系统临时目录。临时输出只作为 AI 分析输入，确认或取消后清理，不直接成为仓库文件。

### 6.3 安全边界

`dump.sh` 必须：

- 默认只读，不提供 apply、install 或 delete 模式；
- 不 source 用户 Zsh 文件来取得变量值；
- 不读取 Keychain 或 `parameters.zsh` 内容；
- 不保存完整环境、shell 历史、token、内部账号或机器标识；
- 在输出中对用户目录、公司域名和本机路径做脱敏；
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

- Brewfile 只包含希望保留或安装的直接期望项；
- tooling 使用明确版本，不写 `latest`；
- personal 和 company 各自最多一份 `plugins.toml`；
- company 文件只保存公司增量；
- local 不保存 Brewfile、tooling 或插件选择；
- 已有 ARM 替代或明确淘汰的 Intel 项进入退役建议，不写回运行时配置；
- 服务和应用数据只进入人工处理提示。

`parameters.zsh` 可以由用户保存密钥值和本机参数，但 Stage 0 不自动生成、覆盖或审查其内容。

## 8. AI 自检

展示给用户前至少检查：

- public 输出不含公司信息、本机路径或密钥；
- company 输出未误入 public；
- personal/company 软件声明无明显重复和所有权冲突；
- Zsh 计划不保留活动 Intel PATH 或重复 `compinit`；
- 插件来源和 revision 明确；
- 所有未知数据和无法判断的替代关系已标记为 manual；
- 草稿只修改预期目标文件。

自检结果直接并入审查摘要，不生成独立审批表。

## 9. 用户一次确认

集中展示：

- Zsh 修复计划摘要；
- public 和 company 的目标路径；
- 每个新增、修改或删除文件的 diff；
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
- [ ] AI 已完成 Zsh 与软件联合分析和自检；
- [ ] 用户已一次确认全部目标 diff；
- [ ] public/company/local 边界正确；
- [ ] 未读取或泄露 local 密钥值；
- [ ] 未生成最终 Zsh、未安装软件、未执行 commit/push。

完成后停止，进入 [Stage 1](./stage-1-portable-dotfiles-capability-build.md)。

## 11. 未来 Skill 接口

未来 Skill 名：`stage-0-source-machine-analysis-and-export`。

触发语义是“分析当前 Zsh 并 dump 本地配置”。Skill 应直接编排 `dump.sh → AI 分析 → AI 自检 → 用户一次确认`，不得重新引入双审批或长期状态机。
