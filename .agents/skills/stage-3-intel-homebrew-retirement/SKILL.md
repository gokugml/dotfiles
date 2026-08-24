---
name: stage-3-intel-homebrew-retirement
description: 在已完成 Stage 2 的 Apple Silicon Mac 上，读取 Stage 2 生成的本机 `intel_to_be_retired.tsv` 作为参考线索，再通过安装器重新盘点和验证旧 Intel Homebrew、全局 mise/uv runtime 与旧插件，低自由度编排退役预览、用户 y/N 确认、受管删除和最终验证。仅在用户明确要求进入 Stage 3、退役或清理已有 ARM 替代或已明确淘汰的旧 Intel 软件时使用；当前 Zsh、PATH、initializer 或全局 package owner 仍在使用的路径不是“旧”，清单也不是删除授权。普通安装、verify 或 Stage 2 完成不会触发退役，也不用于选择或安装 ARM 替代、迁移服务数据、删除项目依赖或清理未知 /usr/local 内容。
---

# Stage 3：旧 Intel 软件安全退役

严格编排仓库现有的 `install.sh`，不要自行拼接卸载命令。固定执行：

```text
只读预检 → retire 预览 → 用户 y/N → retire --apply → verify → 再次 retire
```

## 执行前计划门

先只读检查仓库、工作树、Stage 2 完成证据、personal/shared 配置、当前有效 Zsh 启动文件及其 PATH/initializer 结构、目标架构、安装器命令面和 `${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/intel_to_be_retired.tsv` 的路径/类型/权限/结构；不得运行 `retire --apply`、卸载命令或删除任何内容。随后向用户展示计划：将运行的 verify/retire 检查、verify 可能原子刷新该安装器受管交接文件的唯一写入影响、可能进入候选删除集的类别、受活动配置或 package owner 保护的路径与其他明确保留类别、真实软件与路径可能受到的影响、不可自动恢复风险、后续删除确认和验证方式，以及明确不会安装替代、处理服务数据、删除未知 `/usr/local` 内容、commit 或 push。展示后停止并等待用户明确确认，再进入预检和预览。

执行前重新检查工作树与 Stage 2 状态；候选类别、范围或风险发生实质变化时，先更新计划并再次等待确认。初始计划确认只授权只读预检与生成退役预览，不替代第 3 步的精确删除清单确认，也不授权任何预览外删除。

## 读取权威边界

开始前完整读取[四阶段共用契约](../stage-common-contract.md)和[领域词汇](../../../CONTEXT.md)。以当前 Skill 规定具体步骤，以共用契约补充跨阶段安全边界。

不要读取或输出 local 密钥值。`intel_to_be_retired.tsv` 只含 Stage 2 确认的机器软件路径和分类线索，可以读取其固定字段，但不得把它或普通安装、迁移完成、单独的 `verify` 请求解释为退役授权。

## 判定“旧”与活动所有权

不得根据目录名称、管理器类别、安装时间或“不是主要 runtime 入口”推断某项已经旧。只要满足以下任一条件，该路径就是活动状态，不得整体删除；其中有活动所有权的内容也必须保留：

- 当前有效 `.zprofile`、`.zshrc` 或其受管 source graph 仍引用对应 PATH、变量或 initializer；
- fresh login/interactive Zsh 的有效 PATH 仍包含该目录；
- 当前声明、命令解析或管理器只读元数据证明它仍拥有被使用的 runtime、全局 package 或直接全局 CLI。

运行时入口和 package home 是不同所有权层。`node`、`npm`、`pnpm`、`bun`、`bunx` 由 mise 暴露，不表示 `PNPM_HOME` 或 `$HOME/.bun` 已经旧；前者仍可保存 pnpm 全局命令，后者仍可保存 Bun 状态与全局 package。`$HOME/.bun/bin/bun` 或 `bunx` 不是主要入口，也不能作为淘汰 `$HOME/.bun` 的证据。

一个精确 runtime、package、插件或路径只有同时满足以下条件，才能进入退役预览：

1. 当前有效 Zsh 与 fresh shell 均不再引用或暴露它；
2. 当前声明、命令解析和管理器元数据均不能证明它仍承担活动所有权；
3. 它不是项目依赖、service/data、未知内容或尚未完成迁移的全局 CLI；
4. 已验证替代，或已有用户/Stage 0 对该精确项目的明确淘汰结论。

活动 package home 本身及其整个目录树不得成为目录级候选。其内部单个 package 只有在安装器能以管理器所有的精确项目独立盘点、证明不再使用并完整展示时，才可单项进入预览；否则保留。

## 遵守硬边界

- 只通过 `./install.sh retire` 和 `./install.sh retire --apply` 编排退役；不要直接运行 `brew uninstall`、`mise uninstall`、`uv python uninstall` 或手工删除插件。
- 不安装、重新选择或修复 ARM 替代；替代缺失或验证失败时保留旧项并返回 Stage 2。
- 不直接根据 `intel_to_be_retired.tsv` 删除任何项目；每一行都必须由当前管理器所有权、实际路径、版本、架构、ARM 替代和 service/data 状态重新验证。
- 不删除当前有效 Zsh/PATH/initializer 仍引用的路径、活动 package home 或仍有全局 package/CLI 所有权的内容；`PNPM_HOME` 与 `$HOME/.bun` 在仍被当前配置和 package 使用时必须保留。
- 不删除项目级 runtime、venv、依赖、未知项目或未在最终摘要中展示的路径。
- 不停止 service，不迁移或删除数据库、GUI 应用数据及其他待处理数据。
- 不递归删除 `/usr/local`，不整体改变其 owner；只允许安装器处理由管理器明确拥有且已展示的路径。
- 不使用 `curl | shell`，不创建长期状态或自制卸载脚本。
- 不 commit、push，也不把退役授权扩张为其他系统变更。

## 1. 执行只读预检

1. 定位当前公开仓库根目录，确认 `install.sh` 存在且 Stage 2 使用的 personal/shared 配置仍能唯一确定；歧义会改变退役集合时停止并询问。
2. 记录 `git status --short`，保护已有工作区修改。
3. 运行 `arch`，只接受原生 `arm64` 进程。
4. 检查 `intel_to_be_retired.tsv`：只接受当前用户拥有的 `0600` 普通文件、安装器固定标记、固定 TSV schema 和可安全解析的绝对路径。文件缺失表示 Stage 2 当时未发现 Intel 残留，不替代本阶段实时盘点；文件无效时停止并返回 Stage 2 重新 verify。
5. 只读确定当前有效 `.zprofile`、`.zshrc` 及其受管 source graph；不得输出 local 文件正文或密钥值。通过 fresh login/interactive Zsh 的 PATH、命令解析和对应管理器元数据建立活动路径与所有权集合，分别记录 runtime 入口与 package home。活动集合至少覆盖 `PNPM_HOME`、`$HOME/.bun`、npm prefix、mise 与 uv 受管目录，以及本次候选涉及的其他 initializer/PATH。
6. 运行 `./install.sh verify`。它可以原子刷新上述安装器受管交接文件，但不得安装、卸载或修改其他软件；如果原生安装完整性失败，阻止整个 Stage 3；如果只影响单个 Intel 候选，保留对应项目并继续预览。
7. 只接受路径、版本和 `file` 架构均验证通过的 ARM 或受支持 Universal 替代。不要仅凭清单行、同名命令存在或旧 Stage 2 快照判定已经替代。

任一系统级前置条件不满足时停止，不要尝试现场修复或继续 `--apply`。

## 2. 运行并审查只读预览

从仓库根运行：

```text
./install.sh retire
```

该命令必须只读。运行后重新检查工作树；若出现命令造成的文件变化或任何软件变更迹象，立即停止并报告安全失败。

确认每个盘点项只进入一种分类：

| 分类 | 处理 |
|---|---|
| ARM 已替代 | 仅在替代路径、版本和架构验证通过时允许删除 |
| 明确淘汰 | 仅在用户或 Stage 0 已有明确结论时允许删除 |
| 活动配置或 package owner | 不整体删除路径；保留活动内容，单个 package 须另有精确证据 |
| 项目依赖 | 保留 |
| 数据待处理 | 保留 |
| 未知 | 保留 |

预览至少必须显示：

- Stage 2 `intel_to_be_retired.tsv` 中每条线索在实时盘点中的匹配、变化或消失状态；
- 待删除的旧 Intel Homebrew、全局 mise/uv runtime 或旧插件；
- 每项 ARM 替代的实际路径、版本和架构，或明确淘汰理由；
- 当前有效 Zsh、fresh shell PATH 和管理器所有权保护的路径；明确区分 mise runtime 入口与 `PNPM_HOME`、`$HOME/.bun` 等活动 package home；
- 保留的项目依赖、未知内容和未处理 service/data；
- `/usr/local` 中明确保留与未知的内容；
- 执行后的验证命令。

若清单与实时预览不一致，以更保守的实时验证为准并报告差异；不得自动扩张删除集。若预览把活动 Zsh/PATH/initializer 引用、活动 package home、仍被使用的全局 package/CLI、项目依赖、数据待处理、未知内容、运行中的 service 或宽泛 `/usr/local` 路径列为删除，视为阻断错误，不要继续。若没有可安全删除的项目，报告“无需执行 `--apply`”并成功结束。

## 3. 集中展示并等待一次确认

向用户完整展示待删除清单、ARM 替代证据、明确淘汰理由、全部保留/阻断项和验证计划。明确说明预览本身没有授权任何删除，然后只询问一次并停止等待：

```text
1. y：确认按上述清单进入正式退役
2. N：取消，保持无变更（默认）
```

只有用户明确选择 `y` 才继续。空输入、`N`、含糊回答或其他输入均按取消处理，不运行 `--apply`。

## 4. 在真实终端执行正式退役

用户明确选择 `y` 后，用 stdin/stdout 均连接真实 TTY 的交互会话运行：

```text
./install.sh retire --apply
```

不要 pipe `yes`，不要预先写入输入。等待安装器重新盘点并展示最终删除与保留摘要：

- 若状态、活动所有权集合或动作集合与用户刚确认的预览不同，向安装器输入 `N`，取消本次执行并重新运行只读预览。
- 若最终摘要一致且仍满足全部边界，把用户刚才明确输入的 `y` 传给安装器的普通 `y/N` 提示。
- 若没有真实 TTY、没有默认 `N` 的提示或安装器试图执行摘要外动作，停止且不要绕过保护。

只允许安装器使用对应管理器删除最终摘要中的项目。退役整个 Intel Homebrew 时，只允许安装器使用已经审查的 Homebrew 官方卸载机制。

## 5. 验证结果

正式命令成功后，从仓库根依次运行只读检查：

```text
arch
command -v brew
brew --prefix
command -v <预览中的关键命令>
file <对应关键二进制>
./install.sh verify
./install.sh retire
```

确认：

- shell 启动无错误，PATH 无活动 Intel Homebrew；
- 退役前受保护的 Zsh PATH/initializer、活动 package home 及其仍被使用的全局 package/CLI 保持存在且可达；
- 关键命令解析到已验证的 ARM 或受支持 Universal 二进制；
- 已删除项目不再被配置引用；
- 再次 `retire` 只显示保留项、阻断项或“无需退役”；
- 最终 `intel_to_be_retired.tsv` 已由 verify 刷新，已删除条目不再作为当前候选，仍保留项继续包含精确路径和保留理由；
- 项目依赖、未知项目和数据目录仍然存在；
- 工作区原有修改没有被覆盖。

只有上述检查全部通过，才报告“已安全退役当前可确认的旧 Intel 软件”。同时列出仍保留的项目及其分类，不把“存在保留项”误报为整体失败。

## 处理失败

- 执行前状态变化：取消并重新运行只读预览。
- 非 TTY 或用户未明确输入 `y`：无变更退出。
- ARM 替代验证失败：保留旧项并指出需返回 Stage 2 的缺口。
- 活动引用、package 所有权或迁移状态无法确定：保留对应路径与内容，不得按名称推断为旧。
- 单项删除失败：停止后续相关动作，报告已完成、未完成及当前验证结果。
- 部分退役后失败：先验证 ARM 环境仍可用，再提供定向人工处理建议；不要自动重装 Intel 软件。
- `verify` 或最终预览失败：如实报告部分完成状态，不宣称 Stage 3 完成。
