---
name: review-exported-dotfiles
description: 对当前 Git 仓库 tmp/ 中由 dump.sh 已导出的软件、tooling 和插件证据及候选配置执行 AI Review，先为每个直接期望工具给出一句话描述，再调整期望项目、按 personal/company/retire/manual 分类，并补齐相邻的 AI-REVIEW 或 AI-RETIRE 评论。用于用户要求审阅、整理或批准前检查已导出的 Brewfile、mise/uv 配置、runtime/tool 清单或 plugins.toml 时；不用于运行采集、分析真实 Zsh 文件、生成 zsh-repair-plan、安装软件或写入正式目录。
---

# 导出配置 AI Review

只审阅当前仓库已经导出的候选配置和脱敏证据。把机器快照整理成可分享的声明式期望状态，但不负责采集、Zsh 修改建议、用户最终确认或正式写入。

## 执行前计划门

先只读检查仓库根、工作树、允许的候选文件清单、`tmp/dump.md` 和正式目标的当前状态，不编辑任何候选。随后向用户展示计划：将审阅和可能修改的精确候选路径、可能新增/移除的声明类型、personal/company/retire/manual 分类影响、安全扫描、验证方式，以及明确不会运行采集、读取 Zsh/local 内容、写入正式目录或修改软件。展示后停止并等待用户明确确认，再进入执行流程。

若由 Stage 0 编排且其已获确认的初始计划逐项覆盖上述范围，可以继承该确认而不重复询问。确认后执行前重新检查候选与工作树；范围、证据或风险发生实质变化时，先更新计划并再次等待确认。初始计划确认不授权正式目录写入、commit、push、安装或退役。

## 严格限定输入

只读取或编辑以下路径：

```text
tmp/dump.md                              # 只读证据
tmp/my_setup/macos/Brewfile
tmp/my_setup/tooling/**
tmp/my_setup/zsh/plugins.toml
tmp/company/macos/Brewfile               # 仅存在公司增量时
tmp/company/tooling/**
tmp/company/zsh/plugins.toml
```

明确排除：

```text
tmp/zsh-evidence.md
tmp/my_setup/zsh/zsh-repair-plan.md
tmp/company/zsh/zsh-repair-plan.md
tmp/.runtime/**
真实 HOME、Keychain、shell 历史和完整环境
```

排除项由 `$analyze-zsh-configuration` 或 Stage 0 编排 Skill 管理。本 Skill 不修改、重写或评价 Zsh 修复计划。

## 执行流程

### 1. 验证导出边界

1. 定位当前 Git 仓库根目录，确认 `tmp/` 被 Git 忽略且不是 symlink。
2. 要求 `tmp/dump.md` 已存在；不要自行运行 `dump.sh` 或任何原生 Dump/List 命令。
3. 检查脱敏日志是否出现网络 metadata refresh、仓库外 cache/临时目录写入、真实 HOME 修改或残留 `tmp/.runtime/`。出现任一信号时停止，把安全失败交回 Stage 0；不要继续 Review。
4. 记录当前候选文件清单和正式目标文件状态，保护用户已有工作区变更。
5. 不联网补齐版本、描述或归属；只使用导出证据和稳定的一般知识。需要当前外部事实才能判断时标记 `manual`。

### 2. 区分证据类型

按可靠性解释 `tmp/dump.md`：

1. 可回放的原生 Dump：作为候选起点，仍需逐项审阅。
2. 结构化只读 List/Status：只把明确字段转换为候选配置。
3. 普通文本状态：只作为最小证据，不能伪装为可回放声明。
4. 缺失、失败或矛盾证据：标记 `manual`，不要猜测。

只在导出证据明确支持时创建缺失的 tooling 或 `plugins.toml` 候选；不要为目录外观创建空文件。

### 3. 整理声明式期望状态

逐项处理：

- Brewfile 只保留希望安装或继续保留的直接期望项目；移除传递依赖、一次性工具和无法确认的机器快照项。
- tooling 使用明确版本；禁止 `latest`、浮动 tag 和无法复现的版本范围。
- personal/company 各自最多一份 `plugins.toml`；每个插件写明 source、固定 tag/commit、enabled 和加载顺序。
- 完全相同的 personal/company 项去重；company 只保存公司增量，local 不参与软件、版本或插件选择。
- 已有 ARM 替代或明确淘汰的 Intel 项不保留活动配置行，改写为同一文件内的 `AI-RETIRE` 评论。
- 服务、数据库、GUI 应用数据、未知 Intel 项和未验证替代关系只进入 `manual` 结果，不自动迁移或删除。

### 4. 补齐逐项 AI 评论

在每个有效直接期望项目紧邻位置，使用该文件支持的注释语法分别写出六个 `AI-REVIEW` 字段。第一项必须是无需依赖后续字段即可理解的一句话工具描述：

```text
一句话描述：<name> 是什么工具，以及它主要解决什么问题
最佳实践：为何采用当前管理器、来源或固定版本
修改级别：保留、新增、替换、升级或降级
建议：本次具体处理
归属：personal 或 company
验证方式：Stage 2 可执行的最小验证
```

对退役项使用单条结构化评论，不保留活动配置行：

```text
AI-RETIRE: 项目=<name> | 原因=<reason> | 替代=<replacement-or-none> | 归属=retire | 验证=<check>
```

保持评论与有效配置一致，并确保 Brewfile、TOML 和版本文件仍可由原生工具解析。不要在评论中写入本机绝对路径、公司信息、账号、远程地址或敏感值。

### 5. 自检并交接

检查：

- 只修改了允许的导出候选路径，Zsh 证据和修复计划保持不变。
- public 候选不含公司信息、本机绝对路径、邮箱、凭证模式或敏感值；company 未误入 public。
- personal/company 无明显重复、管理器争用或版本所有权冲突。
- tooling 版本和插件 revision 固定；每个直接期望项目都有完整、相邻且一致的六字段评论。
- 每个替代/移除项目只有 `AI-RETIRE` 评论，没有活动配置行。
- 未经审阅的机器快照没有直接成为正式期望状态；所有未知项均标记 `manual`。
- 正式目录、真实 HOME、软件、服务和 Git 历史均未修改。

完成后把候选文件清单、逐项调整摘要、manual 项、证据缺口和自检结果交回 `$stage-0-source-machine-analysis-and-export`。逐项摘要必须先原样呈现对应工具的一句话描述，再给出修改级别和本次建议；不要让 Stage 0 根据工具名重新生成描述。不要请求最终写入确认，不要把候选复制到正式目录，不要 commit 或 push。
