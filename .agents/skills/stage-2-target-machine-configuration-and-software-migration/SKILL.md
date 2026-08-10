---
name: stage-2-target-machine-configuration-and-software-migration
description: 编排 Apple Silicon 目标机器 Stage 2：根据 Stage 0 已确认的 Zsh 修复计划和软件/插件配置生成 public/company 仓库版 Zsh，先让用户审查 diff，再运行无参数 install.sh 安装 personal/company 的 ARM Homebrew、mise/uv tooling 与固定 revision 插件，最后运行 install.sh verify。用于用户要求在源机器或新 Mac 上应用 Stage 0 分析结果、迁移 Zsh 与已声明软件或执行 Stage 2 时；不得直接编辑真实 ~/.zprofile 或 ~/.zshrc、读取 local 密钥值、自动迁移服务数据、进入 Stage 3、commit 或 push。
---

# Stage 2：目标机器配置与软件迁移

把已确认的分析结果应用到 Apple Silicon 目标机器，严格执行：

```text
生成仓库版 Zsh → 用户确认 public/company diff
  → ./install.sh → 脚本内 y/N 确认 → ./install.sh verify
```

完成后停在“Zsh 与已声明 ARM 软件安装完成”，不要自动进入退役。

## 执行前计划门

先只读检查 public/company 仓库、工作树、Stage 0 修复计划和已确认配置、现有仓库版 Zsh、目标架构、工具可用性及 local 路径元数据；不得读取 local 内容、生成 Zsh 草稿或运行安装器。随后向用户展示完整计划：将创建或修改的仓库文件、可能产生的真实 Zsh 副本和 symlink、可能安装的 Homebrew/tooling/plugin、hook 变更、网络与磁盘影响、服务/数据人工项、验证和失败停止点，以及明确不会执行的 Stage 3、commit、push。展示后停止并等待用户明确确认，再进入执行工作流。

执行前重新检查输入与工作树；范围、软件集合、company 目标或系统状态发生实质变化时，先更新计划并再次等待确认。初始计划确认只允许按计划生成草稿和进入后续审查，不替代第 3 步 Zsh diff 确认或 `install.sh` 自身的 `y/N`，也不授权退役。

## 读取权威输入

开始前读取：

- [四阶段共用契约](../stage-common-contract.md)和[领域词汇](../../../CONTEXT.md)；
- public 仓库的 `my_setup/zsh/zsh-repair-plan.md`；
- 可选 company 仓库的 `zsh/zsh-repair-plan.md`；
- Stage 0 已确认的软件、tooling 和 `plugins.toml` 配置；
- public/company 仓库中已有的 Zsh 文件；
- 目标机器的只读 Zsh 结构证据，但不读取 local 参数内容。

把 public 仓库解析为包含 `dump.sh`、`install.sh` 和 `my_setup/` 的当前 Git 仓库。只有确有 company 增量时才解析唯一的已授权 company 仓库；不能唯一定位时，把歧义集中成一次提问。

## 遵守硬边界

- 只在原生 `arm64` 会话中执行真实写入；证据不足时只生成草稿和问题摘要，不运行安装。
- 不直接编辑、替换或重写真实 `~/.zprofile`、`~/.zshrc`；真实入口只允许由获准后的 `install.sh` 管理。
- 不读取、显示、复制、记录或持久化 `~/.config/dotfiles/local/parameters.zsh` 的内容。只检查路径、文件类型、权限和无输出语法结果。
- 不把公司内容、本机绝对路径、账号或密钥写入 public 仓库。
- 不覆盖与本次 Zsh 草稿重叠的用户未确认修改。确认后输入或 diff 发生变化时，重新展示完整最新 diff 并再次确认。
- 不启停服务，不迁移数据库、Homebrew service 或 GUI 应用数据，不清理未知软件、项目 runtime 或 Intel 数据目录。
- 不调用 `install.sh retire` 或 `install.sh retire --apply`，不自动执行 Stage 3。
- 不 commit 或 push。

## 执行工作流

### 1. 预检

1. 检查 public 与可选 company 仓库的 `git status --short`，把已有变更视为用户内容。
2. 确认 Stage 1 的测试、pre-commit 和 CI 已完成，当前 checkout 包含 `dump.sh`、`install.sh`、`my_setup/` 和 Stage 0 修复计划。
3. 检查所有已确认 personal/company Brewfile、tooling 与插件配置存在且可解析。
4. 检查目标会话架构。非原生 `arm64` 时允许继续生成仓库草稿，但在安装前停止。
5. 记录 local 文件是否存在及其权限，不读取内容。

前置条件缺失时，集中报告缺口。只有不影响仓库草稿正确性的缺口才允许继续生成草稿；任何影响真实安装安全性的缺口都必须阻止 `install.sh`。

### 2. 生成仓库版 Zsh

根据已确认修复计划生成或更新：

```text
my_setup/zsh/.zprofile
my_setup/zsh/.zshrc
<company-repository>/zsh/company.zsh   # 仅有 company 增量时
```

保持 `.zprofile` 最小、线性且 ARM-only。在 `.zshrc` 中固定受管顺序：

```text
可选 company/zsh/company.zsh
  → personal 主配置
    → 可选 ~/.config/dotfiles/local/parameters.zsh
```

由此维持 `company < personal < local` 的覆盖优先级，并满足：

- company 只包含公司增量，可在 personal 之前独立加载，不依赖 personal 后续定义的 alias、function 或变量，也不包含密钥值；
- personal 提供完整默认体验，独占 Oh My Zsh 和补全初始化，不包含公司信息、本机路径、密钥、活动 Intel PATH 或 Rosetta fallback；
- company 或 local 缺失时静默跳过，存在但语法错误时让验证失败；
- local 始终最后加载，仓库文件中不写示例密钥值。

### 3. 自检并展示 Zsh diff

在请求确认前：

1. 对生成的 `.zprofile`、`.zshrc` 和可选 `company.zsh` 运行 `zsh -n`。
2. 检查 company → personal → local 顺序以及 Oh My Zsh/补全初始化唯一性。
3. 扫描 public diff 中的密钥、公司标识、本机绝对路径、Intel Homebrew PATH 和 Rosetta fallback。
4. 检查未触碰真实 HOME、软件、服务和应用数据。
5. 集中展示 public/company Zsh 的完整 diff、证据缺口、目标仓库和自检结果。

随后只给出以下选择并停止等待：

```text
1. 确认当前 Zsh diff，并继续运行 ./install.sh
2. 要求调整仓库草稿并重新审查
3. 取消本次 Stage 2
```

明确说明：选择 1 只授权进入安装器；真实系统写入仍受 `install.sh` 内默认 `N` 的 `y/N` 确认保护。选择 2 时只修改仓库草稿，重新运行全部自检并展示完整最新 diff。选择 3 时保留可审查的仓库草稿，不运行安装。

### 4. 运行安装器

只有用户确认最新 Zsh diff 且写模式仍满足全部前置条件时，才从 public 仓库根目录在真实终端运行：

```text
./install.sh
```

不要添加参数，不要代替用户输入 `y`，不要绕过或预先回答脚本确认。检查脚本在任何写入前即时展示：

- public 和可选 company 来源；
- Zsh 入口、现有文件或 symlink 的副本计划；
- personal/company Brewfile 合并结果；
- tooling、mise/uv 和固定 revision 插件变更；
- public 仓库的 pre-commit hook 配置；
- local 路径和权限状态，但不显示内容；
- 服务、数据库或应用数据的人工事项。

让脚本使用默认 `N` 的一次 `y/N` 集中确认。若 ARM Homebrew 等基础工具缺失，要求脚本另行展示来源和额外影响并再次确认；禁止不透明的 `curl | shell`。

确认后，让 `install.sh` 自己按契约完成副本、symlink、local 权限、`core.hooksPath`、Brewfile 合并、ARM 软件、mise/uv/tooling 和插件安装。不要在本 Skill 中复刻或绕过这些确定性步骤。

### 5. 验证目标机器

安装器成功返回后运行：

```text
./install.sh verify
```

确认验证至少覆盖：

- 所有启用 Zsh 文件通过 `zsh -n`，login 与 interactive shell 无加载错误；
- `~/.zprofile` 和 `~/.zshrc` symlink 指向 public `my_setup/zsh/`；
- company → personal → local 顺序正确，personal 独占 Oh My Zsh/补全初始化；
- local 父目录为 `0700`、文件为 `0600`，未被 Git 跟踪且内容未泄露；
- PATH 没有重复的活动 Intel Homebrew，Homebrew、mise、uv 和插件命令来自预期路径；
- 关键二进制为 ARM 或受支持的 Universal；
- 再次运行安装不会覆盖已有副本或重复破坏 symlink；
- 服务和数据人工事项仍被如实报告。

性能结果只作为建议，不阻止基础交付。

### 6. 报告并停止

报告仓库 Zsh 文件、真实入口 symlink、已创建副本、软件/tooling/插件结果、验证结论、人工服务或数据事项和未解决缺口。不要自动继续 Stage 3。

## 处理失败

- Zsh 草稿生成或自检失败：保留仓库草稿，报告问题，不运行安装。
- 用户拒绝 Zsh diff 或安装摘要：不执行真实系统变更。
- Zsh 副本创建失败：停止，不替换真实入口。
- 软件部分安装后验证失败：报告实际状态和人工修复建议，不自动卸载。
- Zsh 验证失败：报告副本位置和失败项并停止，不擅自恢复或覆盖。
- 服务或数据尚未处理：允许完成配置和软件安装，但明确标记这些项目不得进入 Stage 3 删除清单。

## 完成判定

只有以下条件全部成立，才报告 Stage 2 完成：

- 用户已确认最新 public/company Zsh diff；
- 加载顺序为 company → personal → local，local 权限正确且内容未被采集；
- 旧 Zsh 文件或 symlink 已创建副本，两个真实入口指向 `my_setup/zsh/`；
- personal/company 软件、tooling 和插件已安装；
- `./install.sh verify` 通过；
- 服务和数据只被报告，没有自动迁移；
- 没有执行 Stage 3、commit 或 push。

若用户在任一确认处取消，按实际状态报告“Stage 2 已取消”或“安装未获确认”，不要把草稿或部分安装标为完成。
