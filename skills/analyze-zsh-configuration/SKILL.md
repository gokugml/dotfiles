---
name: analyze-zsh-configuration
description: 只读采集并分析 macOS Zsh 启动文件的脱敏结构证据，依据 Skill 内置的 Zsh 最佳实践手册生成逐项文件修改建议和 zsh-repair-plan.md 候选。用于用户要求诊断或优化 .zshenv、.zprofile、.zshrc、.zlogin，排查 Intel/ARM 路径、重复 compinit、PATH/fpath、初始化顺序、变量作用域、敏感信息边界或启动性能时；不用于导出软件配置、审阅 Brewfile/tooling、生成最终 Zsh 文件或修改真实 HOME。
---

# Zsh 配置分析与修改建议

把源机器 Zsh 启动文件的脱敏结构证据转换为可执行、可验证的修改建议。只生成修复计划候选，不修改真实文件，不生成最终 `.zprofile`、`.zshrc` 或 `company.zsh`。

## 使用内置资源

- 使用 [`scripts/collect-zsh-evidence.zsh`](scripts/collect-zsh-evidence.zsh) 采集证据。始终从当前公开 Git 仓库根目录执行，不要用 `dump.sh` 采集 Zsh。
- 使用 [`references/zshrc-diagnostics-guide.md`](references/zshrc-diagnostics-guide.md) 作为修改建议的权威手册。先查看目录，再只读取与当前证据相关的章节；涉及多个类别时可读取多个章节。

## 遵守边界

- AI 分析层不直接读取、输出或 source 真实 Zsh 文件；只有内置确定性脚本可以只读扫描其结构信号。AI 只读取脚本生成的 `tmp/zsh-evidence.md`。
- 不读取 Keychain、shell 历史、完整环境或 `~/.config/dotfiles/local/parameters.zsh` 内容。
- 不修改真实 Zsh、symlink、软件或服务，不调用 `install.sh`，不安装或退役项目。
- 不把本机绝对路径、公司信息、账号、远程地址或敏感值写入 public 修复计划。
- 不把推断当作证据。未知 source 表达式、被脱敏路径和无法确认的工具所有权统一标记 `manual`。
- 不负责审阅 `dump.sh` 导出的 Brewfile、tooling 或 `plugins.toml`；该职责属于 `$review-exported-dotfiles`。

## 执行流程

### 1. 预检

1. 定位当前公开 Git 仓库根目录，确认 `tmp/` 被 Git 忽略且不是 symlink。
2. 检查 `git status --short`，保护用户已有变更；本 Skill 只管理 `tmp/zsh-evidence.md` 和自己生成的 `tmp/**/zsh/zsh-repair-plan.md`。
3. 若 company 修复计划确有必要但 company 归属或目标仓库不明确，把歧义交回 Stage 0 编排 Skill；不要自行猜测。

### 2. 采集脱敏证据

从仓库根运行：

```zsh
skills/analyze-zsh-configuration/scripts/collect-zsh-evidence.zsh
```

要求：

- 不传参数，不修改 HOME 来帮助采集。
- 采集失败时停止，不绕过脚本安全检查，不回读真实 Zsh 文件补证据。
- 确认唯一证据文件为 `tmp/zsh-evidence.md`，且 Git 未跟踪它。
- 确认报告只包含文件类型、权限、symlink 类别、语法结果、计数、标识符名称、source 类别和脱敏 PATH/fpath，不包含变量值、alias/function body 或原始 source 路径。

### 3. 选择手册章节

根据证据信号读取手册：

| 证据信号 | 至少读取的章节 |
|---|---|
| 启动文件职责、语法、source 顺序 | 2、3、6、14 |
| `/usr/local`、x86_64、Rosetta | 2、4、5 |
| PATH/fpath 重复或硬编码 | 5、12 |
| compinit、补全、插件重复 | 7、8 |
| 变量名、作用域或疑似敏感项 | 9、10、12 |
| NVM、pyenv、mise 等职责冲突 | 8、11 |
| 需要统一输出格式或验收 | 15、16 |

证据不足时只读取基础分类、报告格式和验收章节，不扩大采集范围。

### 4. 生成修改建议

按实际内容生成：

```text
tmp/my_setup/zsh/zsh-repair-plan.md
tmp/company/zsh/zsh-repair-plan.md   # 仅存在明确公司增量时
```

为每个发现写明：

```text
类别：手册定义的诊断类别
优先级：P0、P1、P2 或 P3
当前行为：只描述脱敏后的现象
证据：引用证据文件中的字段或计数，不复制敏感内容
影响：安全、正确性、架构、性能或维护成本
建议：保留、改写、替代或移除的最小可逆方向
归属：personal、company、local、retire 或 manual
目标文件：Stage 2 应修改的逻辑位置
验证：修改后应执行的命令和预期结果
```

遵守以下判断规则：

- 把跨进程静态环境建议放到 `.zprofile`，把交互行为建议放到 `.zshrc`；不建议接管 `.zshenv` 或设置 `ZDOTDIR`。
- 明确指出活动 Intel Homebrew PATH、Rosetta fallback、ARM→Intel wrapper、重复 `compinit`、重复 PATH/fpath 和多版本管理器争用。
- 对敏感信息只写“疑似敏感变量需要迁移/轮换”，不写值；local 只记录参数类别。
- 只给修改方向和必要的最小片段，不拼装最终完整 Zsh 文件；最终文件由 Stage 2 根据获准计划生成。
- 没有实际内容时不创建空 company 计划。

### 5. 自检并交接

检查：

- 建议均可追溯到 `tmp/zsh-evidence.md` 和手册章节，没有未经证据支持的结论。
- public 计划不含公司信息、本机绝对路径、账号、远程地址或敏感值。
- company/local/retire/manual 未混入 personal 活动配置建议。
- 计划没有生成或修改最终 Zsh 文件，没有安装、退役、commit 或 push。
- 建议包含明确目标、风险和可执行验收，而不是只复述最佳实践。
- 交接说明准确区分“采集脚本只读扫描了启动文件”和“AI 未直接读取文件内容”；不要笼统声称整个 Skill 未读取源文件。

完成后把修复计划路径、发现摘要、证据缺口和自检结果交回 `$stage-0-source-machine-analysis-and-export`。不要自行请求最终写入确认，也不要把 `tmp/` 候选写入正式目录。
