# Apple Silicon Dotfiles 四阶段共用契约

> 状态：轻量共用需求<br>
> 日期：2026-08-09<br>
> 适用范围：Stage 0–3

## 1. 目的与权威顺序

本文件只保存四个阶段真正共用的术语、目录、命令和安全边界。具体步骤由对应阶段文档定义：

- [Stage 0：本地分析与配置导出](./stage-0-source-machine-analysis-and-export.md)
- [Stage 1：轻量 Dotfiles 能力建设](./stage-1-portable-dotfiles-capability-build.md)
- [Stage 2：应用分析结果](./stage-2-target-machine-configuration-and-software-migration.md)
- [Stage 3：旧 Intel 软件退役](./stage-3-intel-homebrew-retirement.md)

[四阶段流程图](./steps.excalidraw) 是阶段职责和功能范围的首要来源。本契约用于补充安全与跨阶段一致性，不得扩张或改变图中的主流程。领域词汇以 [CONTEXT.md](../CONTEXT.md) 为准。

## 2. 四阶段主线

```text
Stage 0：dump.sh 原生导出到仓库 tmp/ → AI 就地审阅并评论 → AI 自检 → 用户一次确认
  → Stage 1：建设 dump.sh、install.sh 与可复用仓库能力
    → Stage 2：AI 生成仓库版 Zsh → install.sh 安装 → verify
      → Stage 3：install.sh retire 预览 → 用户确认 → 退役与验证
```

阶段之间只保留以下边界：

1. Stage 0 的草稿未经用户确认，不写入 personal/company 目标文件。
2. Stage 1 的脚本、pre-commit 和 CI 未验证，不用于真实机器安装。
3. Stage 2 安装与验证未完成，不进入 Stage 3。
4. Stage 3 不由 Stage 2 自动触发。

## 3. 仓库和配置职责

| 范围 | 保存位置 | 负责 | 不负责 |
|---|---|---|---|
| 公开仓库 | 用户当前 Git 仓库 | `dump.sh`、`install.sh`、Skills、文档、测试、pre-commit、CI 和 `my_setup/` | 公司内容、本机密钥 |
| personal | 公开仓库固定 `my_setup/` | 可分享的 Zsh、Brewfile、tooling、插件和软件期望状态 | 公司增量、本机密钥 |
| company | 可选独立私有仓库 | 公司专属 Zsh、Brewfile、tooling 和插件增量 | 通用脚本、个人偏好、本机密钥 |
| local | `~/.config/dotfiles/local/parameters.zsh` | 密钥值、账号、机器路径和不可公开参数 | Brewfile、软件清单、插件选择、普通共享配置 |

`personal configuration` 是语义分类；它在磁盘上的固定映射是：

```text
personal configuration → <public-repository>/my_setup/
```

company 缺失时，personal + local 必须能够独立工作。local 文件缺失时，personal 也必须能够独立工作。

## 4. 轻量目标结构

公开仓库：

```text
dotfiles/
├── README.md
├── dump.sh
├── install.sh
├── tmp/                 # Git ignored；Stage 0 临时候选树
├── skills/
├── my_setup/
│   ├── zsh/
│   │   ├── .zprofile
│   │   ├── .zshrc
│   │   ├── zsh-repair-plan.md
│   │   └── plugins.toml
│   ├── macos/Brewfile
│   └── tooling/
├── tests/
├── .githooks/pre-commit
└── .github/workflows/
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

本机私有参数：

```text
~/.config/dotfiles/
└── local/
    └── parameters.zsh
```

不存在实际内容时不创建空 company 文件。详细 tooling 文件由实际工具决定，不为统一目录外观创建空 schema 或占位文件。

## 5. Zsh 运行时边界

- 不接管 `~/.zshenv`，不设置 `ZDOTDIR`。
- `~/.zprofile` symlink 到 `my_setup/zsh/.zprofile`。
- `~/.zshrc` symlink 到 `my_setup/zsh/.zshrc`。
- `.zshrc` 的受管加载顺序固定为 `company → personal → local`。
- company 只有一个可选 `zsh/company.zsh`，必须能够在 personal 配置之前独立加载。
- local 只有一个可选 `parameters.zsh`，在 personal 配置之后加载。
- company 或 local 文件缺失时静默跳过；存在但语法错误时 `install.sh verify` 失败。
- 日常配置不得包含 Intel Homebrew PATH、Rosetta fallback 或 ARM→Intel wrapper。

`parameters.zsh` 可以直接保存密钥值和其他不可公开参数。默认安全要求：

- 文件权限 `0600`，父目录权限 `0700`；
- 不进入 Git、云同步、普通备份、日志、报告、测试 fixture 或哈希输入；
- `dump.sh` 不采集文件内容；`install.sh` 不打印、复制或持久化内容，只允许无输出的语法检查和正常 shell 加载；
- Keychain 是可选增强，不是安装前置条件。

## 6. 软件与插件边界

- Homebrew 管理系统 CLI、原生库和 GUI cask。
- mise 管理需要固定版本的跨项目 runtime 和 CLI。
- uv 管理 Python 版本、环境和 Python tool。
- Stage 0 优先调用各管理器只读、可回放的原生 Dump；没有 Dump 时使用结构化只读输出，由 AI 转为目标配置。
- 原生命令如果会维护或写入仓库外状态，Stage 0 必须退化为只读元数据检查。
- personal 与 company 分别声明自己的 Brewfile 和 tooling；完全相同的项目去重，可覆盖字段按 company → personal 处理，管理器或版本所有权不兼容时停止并报告。
- personal 与 company 各自最多使用一份 `plugins.toml`，同一条目内记录来源、固定 revision、启用状态和加载顺序。
- local 不定义软件、版本或插件。

## 7. 命令契约

```text
./dump.sh
./install.sh
./install.sh verify
./install.sh retire
./install.sh retire --apply
```

- `dump.sh` 属于 Stage 0，只读收集分析输入，并只在当前仓库被忽略的 `tmp/` 生成同构候选文件。
- 无参数 `install.sh` 等于安装 apply。执行前即时展示摘要，并以默认 `N` 的 `y/N` 确认。
- `install.sh verify` 验证 Zsh、symlink、架构、软件来源和插件状态。
- `install.sh retire` 属于 Stage 3，只读预览。
- `install.sh retire --apply` 只在真实终端接受默认 `N` 的 `y/N` 确认。
- 主流程只提供上列命令，不扩张额外管理入口或独立迁移脚本。

## 8. 写入与删除安全

- 覆盖本地 Zsh 入口前，只为已有 `.zsh` 文件或 symlink 创建保留类型与目标的副本。
- 安装器不得覆盖 Git 工作树中的未提交冲突。
- 密钥、公司内容和本机路径不得进入 public 输出。
- Stage 0 只清理自己生成的 `tmp/dump.md`、`tmp/my_setup/`、执行期间的 `tmp/.runtime/` 和明确生成的可选 `tmp/company/`，不得清空未知临时内容。
- `dump.sh` 必须覆盖子进程的临时目录和可重定向缓存位置；只读使用 Homebrew 已有 metadata cache 时必须禁用 refresh、自动更新和 description 查询，使原生工具采集不会写入仓库外目录。
- 服务、数据库和 GUI 应用数据只检测并报告，不自动迁移。
- 未处理服务数据、未知 Intel 项、项目级依赖或未验证 ARM 替代不得删除。
- 不递归删除 `/usr/local`，不整体改变其 owner。
- 不透明的 `curl | shell` 不得作为安装或退役实现。

除 Zsh 入口副本外，主流程不实现自动恢复。未来 rollback 需求统一记录在 [rollback_feature.md](./rollback_feature.md)。

## 9. 共用验证

最低验证包括：

- 所有启用 Zsh 文件通过 `zsh -n`；
- login 与 interactive shell 无加载错误；
- symlink 指向 `my_setup/zsh/`；
- 加载顺序为 company → personal → local；
- local 权限正确且未被 Git 跟踪；
- PATH 无活动 Intel Homebrew 路径；
- Brewfile、mise/uv 和 `plugins.toml` 可解析；
- Stage 0 候选文件中的每个直接期望项目都有功能、最佳实践、修改级别、建议、归属和验证评论；
- 已安装命令的实际路径、版本和架构符合期望；
- `install.sh` 再次执行不会重复破坏已有配置；
- retire 预览不包含未知项目和未处理数据。

性能检查只产生建议，不阻止基础交付。

## 10. 文档和 Skill 约束

- 阶段文档只描述本阶段输入、主流程、输出和停止边界。
- 详细 Zsh 诊断按需读取 [Zsh 配置诊断与优化指南](./zshrc-diagnostics-guide.md)，不得复制回每个阶段。
- 后续转化为真正 Skill 时，`SKILL.md` 只保留触发条件和核心工作流；确定性检查再沉淀为 scripts。
- README 保持完整中文和英文正文，pre-commit 与 CI 负责验证两种语言的结构同步及基础安全。
