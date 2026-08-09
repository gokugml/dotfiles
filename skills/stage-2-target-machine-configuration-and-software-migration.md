# Stage 2：应用分析结果需求

> 状态：轻量阶段需求<br>
> 日期：2026-08-09<br>
> 执行位置：Apple Silicon 目标机器

## 1. 阶段定位

本阶段先由 AI 根据 Stage 0 修复计划生成仓库版 Zsh，用户确认 diff 后，再运行无参数 `install.sh` 完成本地 Zsh 切换和 personal/company 软件安装。

目标机器可以是源机器，也可以是另一台机器。无论哪种情况，都不直接就地改写真实 `~/.zshrc`。

## 2. 目标

1. 把 Zsh 修复计划落实为可审查的仓库文件。
2. 固定 company → personal → local 加载顺序。
3. 为本地旧 Zsh 文件或 symlink 创建副本。
4. 建立指向 `my_setup/zsh/` 的标准入口。
5. 安装 personal/company 声明的 Brewfile、tooling、mise/uv 和插件。
6. 验证 Zsh、PATH、软件版本和 ARM 架构。
7. 明确停止在“安装完成”，不自动进入退役。

## 3. 非目标

- 不直接把 AI 修改写入真实 `~/.zshrc`。
- 不从目标机器反向提交未经用户审查的通用配置。
- 不自动迁移数据库、Homebrew service 数据或 GUI 应用数据。
- 不清理未知软件、项目级 runtime 或 Intel 数据目录。
- 不保存安装状态档案。
- 不自动执行 Stage 3。

## 4. 前置条件

- 公开仓库已完成 Stage 1 的测试、pre-commit 和 CI；
- 当前 checkout 中存在 `dump.sh`、`install.sh`、`my_setup/` 和 Stage 0 修复计划；
- 可选 company 仓库已授权，或明确不启用；
- 当前工作树没有与待生成 Zsh 重叠的未确认修改；
- 写模式运行在原生 `arm64` 会话。

证据不足时，AI 可以生成草稿和问题摘要，但不得运行安装。

## 5. AI 生成仓库版 Zsh

### 5.1 输入

AI 读取：

- `my_setup/zsh/zsh-repair-plan.md`；
- 可选 company `zsh/zsh-repair-plan.md`；
- Stage 0 已确认的软件和插件配置；
- 当前仓库中已有 Zsh 文件；
- 目标机器只读 Zsh 证据，但不读取 local 密钥值。

### 5.2 输出

生成或更新：

```text
my_setup/zsh/.zprofile
my_setup/zsh/.zshrc
<company-repository>/zsh/company.zsh   # 可选
```

`.zprofile` 保持最小、线性和 ARM-only。`.zshrc` 中的受管顺序固定为：

```text
加载可选 company/zsh/company.zsh
  → 执行 personal 主配置
    → 加载可选 ~/.config/dotfiles/local/parameters.zsh
```

因此覆盖优先级是 `company < personal < local`。

company 必须：

- 只包含公司增量；
- 能在 personal 之前独立加载；
- 不依赖 personal 后续定义的 alias、function 或变量；
- 不包含密钥值。

personal 必须：

- 提供完整的默认 Zsh 体验；
- 独占 OMZ 和补全初始化；
- 不包含公司信息、本机路径或密钥；
- 不保留活动 Intel PATH 或 Rosetta fallback。

### 5.3 用户审查

AI 完成语法和边界自检后，集中展示 public/company Zsh diff。用户确认前：

- 不修改真实 HOME；
- 不运行 `install.sh`；
- 不 commit 或 push。

用户拒绝时只修改仓库草稿并重新展示 diff。

## 6. local 单文件

local 固定为：

```text
~/.config/dotfiles/local/parameters.zsh
```

它可以直接定义：

- API key 和其他密钥值；
- 账号；
- 本机绝对路径；
- 不能公开的工具参数。

要求：

- 父目录 `0700`；
- 文件 `0600`；
- 不进入 Git、云同步、普通备份、日志或测试；
- `dump.sh` 和 AI 不采集其内容；`install.sh` 不打印、复制或持久化内容，只允许语法检查和正常 shell 加载；
- local 文件只在 personal 主配置之后 source；
- Keychain 可以由用户自行采用，但不是默认流程。

文件不存在时，`install.sh` 可以在用户确认后创建只含安全注释的空模板并设置权限；不得写入示例密钥值。

## 7. 运行 `install.sh`

标准入口只有：

```text
./install.sh
```

无参数运行等于安装 apply，不另设 `plan`。

### 7.1 即时摘要

执行写入前计算并展示：

- public 和可选 company 来源；
- 将创建的 Zsh symlink；
- 将创建副本的本地 Zsh 文件或 symlink；
- personal/company Brewfile 合并结果；
- 将安装或调整的 tooling、mise/uv 和插件；
- 当前公开仓库的 pre-commit hook 配置；
- local 文件路径和权限状态，不显示内容；
- 检测到的服务或应用数据人工事项。

然后使用默认 `N` 的 `y/N` 集中确认一次。用户拒绝时无变更退出，不保存 plan。

### 7.2 应用顺序

确认后：

1. 重新验证工作树和摘要输入未变化；
2. 为已有 `~/.zprofile`、`~/.zshrc` 及相关 symlink 创建保留原类型和目标的副本；
3. 创建 `~/.zprofile -> <public-root>/my_setup/zsh/.zprofile`；
4. 创建 `~/.zshrc -> <public-root>/my_setup/zsh/.zshrc`；
5. 验证或创建 local 目录和单一参数文件权限；
6. 为当前公开仓库配置 `core.hooksPath=.githooks`；
7. 合并 personal/company Brewfile，冲突项停止并报告；
8. 安装缺失的 ARM Homebrew 项；
9. 应用明确版本的 mise/uv/tooling；
10. 安装并验证 personal/company `plugins.toml` 中启用的固定 revision 插件；
11. 运行与 `install.sh verify` 相同的验证。

如果 ARM Homebrew 等基础工具缺失，安装器必须展示来源和额外影响并再次确认；不得使用不透明的 `curl | shell`。

### 7.3 服务和数据

安装器只检测并报告：

- 正在运行的 Intel service；
- `/usr/local/var`、`/usr/local/etc` 等已知数据目录；
- 数据库或其他有状态软件；
- GUI 应用数据。

它不启停服务、不复制数据、不执行通用迁移 runbook。用户未人工处理的内容必须在 Stage 3 保留。

## 8. 验证

运行：

```text
./install.sh verify
```

至少验证：

- `.zprofile`、`.zshrc`、`company.zsh` 和 `parameters.zsh` 通过 `zsh -n`；
- login 和 interactive shell 无加载错误；
- symlink 指向 `my_setup/zsh/`；
- company → personal → local 顺序正确；
- personal 独占 OMZ/补全初始化；
- local 权限正确且未被 Git 跟踪；
- PATH 无重复的活动 Intel Homebrew；
- Homebrew、mise、uv 和插件命令来自预期路径；
- 关键二进制是 ARM 或受支持的 Universal；
- 再次运行安装不会覆盖已有副本或重复破坏 symlink；
- 服务和数据人工事项仍被如实报告。

性能结果只作建议。

## 9. 失败处理

- AI 生成失败：保留仓库草稿，不运行安装。
- 用户拒绝 Zsh diff 或安装摘要：无真实系统变更退出。
- Zsh 副本创建失败：停止，不替换入口。
- 软件安装部分成功后验证失败：报告实际状态和人工修复建议，不自动卸载。
- Zsh 验证失败：报告副本位置并停止。
- 服务或数据未处理：配置和软件安装可以完成，但对应项目不得进入 Stage 3 删除清单。

## 10. 完成条件

- [ ] AI 已根据修复计划生成 public/company Zsh；
- [ ] 用户已确认 Zsh diff；
- [ ] 加载顺序为 company → personal → local；
- [ ] local 只有 `parameters.zsh`，权限正确；
- [ ] 本地旧 Zsh 文件或 symlink 已创建副本；
- [ ] 两个真实入口指向 `my_setup/zsh/`；
- [ ] personal/company 软件、tooling 和插件已安装；
- [ ] `install.sh verify` 通过；
- [ ] 服务和数据仅被报告，没有自动迁移；
- [ ] 未自动进入 Stage 3。

完成状态是“Zsh 与已声明 ARM 软件安装完成”。如果仍有旧 Intel 软件，由用户另行进入 [Stage 3](./stage-3-intel-homebrew-retirement.md)。

## 11. 未来 Skill 接口

未来 Skill 名：`stage-2-target-machine-configuration-and-software-migration`。

Skill 编排 `AI 生成 Zsh → 用户确认 diff → ./install.sh → ./install.sh verify`。它不得直接编辑真实 Zsh，不得自动迁移服务数据，也不得自动进入 retire。
