# 可移植的 Apple Silicon Dotfiles

[English documentation](README.en.md)

<!-- section:overview -->

## 概览

这个公开仓库保存可分享的个人配置和迁移能力，用于把经过确认的 Zsh、Homebrew、mise、uv 与 Zsh 插件迁移到 Apple Silicon Mac。与他人共用的配置增量放在可选的独立 shared 仓库，本机密钥只放在仓库外的 local 文件。

Stage 1 根据已确认的 `zsh-repair-plan.md` 应用并审查仓库版 Zsh，可使用无前置点的 `zprofile` + `zshrc`，也可使用有前置点的 `.zprofile` + `.zshrc`。它在写入前后逐块比较源 Zsh 与目标加本机 integrations，缺块即失败。Stage 2 不生成这些文件；安装器从 `my_setup/zsh/` 中解析唯一完整的一组来源，再建立固定的 HOME 启动入口。

<!-- section:stages -->

## 四阶段流程

1. **Stage 0：分析与导出。** `./dump.sh` 只读导出软件、tooling 和插件候选；独立 Zsh Skill 采集不含值的结构证据与第三方功能块保全清单并生成修复计划；导出 Review Skill 审阅候选配置。用户确认后才写入正式草稿。
2. **Stage 1：应用 Zsh 修复计划。** 优先更新用户显式提供的目标；否则先确认使用 `zprofile`/`zshrc` 还是 `.zprofile`/`.zshrc`，再用官方安装工具在隔离 HOME 拉取最新版 Oh My Zsh 模板、应用计划、逐块比较源与目标并审查完整 diff。它不修改真实 Zsh 入口，只能在单独确认后备份并更新固定的 local parameters/integrations 文件，也不安装软件。
3. **Stage 2：配置与安装。** 确认 `my_setup/zsh/` 中恰好存在 Stage 1 选择的一套完整 Zsh 来源，再运行无参数 `./install.sh`。脚本展示所选来源和整体摘要，使用默认 `N` 的一次 `y/N` 确认，完成后运行 `./install.sh verify`。
4. **Stage 3：Intel 退役。** 先用 `./install.sh retire` 只读预览；只有再次审查并在真实 TTY 中确认后，才运行 `./install.sh retire --apply`。普通安装和 `verify` 永远不会触发退役。

<!-- section:layout -->

## 仓库与安装器结构

```text
dotfiles/
├── README.md                     # 默认中文文档
├── README.en.md                  # English documentation
├── dump.sh
├── install.sh                    # 唯一公开安装入口
├── my_setup/
│   ├── zsh/install.sh            # 内部 Zsh/symlink/plugin 模块
│   ├── zsh/{zprofile,zshrc}       # Stage 1 默认无前置点来源
│   │   或 zsh/{.zprofile,.zshrc}  # 用户选择的有前置点来源
│   ├── tooling/install.sh        # 内部 mise/uv 模块
│   └── macos/install.sh          # 内部 Homebrew 模块
├── tests/smoke.zsh
├── .githooks/pre-commit
└── .github/workflows/verify.yml
```

三个子 `install.sh` 是根安装器加载的内部模块；直接执行会安全失败。根安装器负责参数解析、跨能力预检、合并摘要、一次确认、调用顺序和最终验证。

<!-- section:commands -->

## 命令

```zsh
./dump.sh
./install.sh
./install.sh verify
./install.sh retire
./install.sh retire --apply
```

无参数安装的执行顺序是 `macos → tooling → zsh → pre-commit hook → verify`。如果 Apple Silicon Homebrew 缺失，脚本会阻断并要求先人工审查、安装官方 Homebrew；它不会执行不透明的 `curl | shell`。

可选 shared 仓库必须由 Stage 2 唯一确认，并在调用根安装器时以绝对路径传入：

```zsh
DOTFILES_SHARED_DIR=/absolute/path/to/shared-dotfiles ./install.sh
```

<!-- section:configuration -->

## 配置约定

- personal 固定保存在公开仓库的 `my_setup/`。
- shared 是可选的独立 Git 工作树，只保存与他人共用的配置增量。
- local 固定在 `~/.config/dotfiles/local/`：`parameters.zsh` 保存密钥值、账号和单机路径；可选 `integrations.zsh` 保存第三方安装器追加的 Zsh 功能块。二者都不保存软件或插件期望状态。
- personal Zsh 仓库来源必须恰好完整存在一组：`my_setup/zsh/zprofile` + `zshrc`，或 `my_setup/zsh/.zprofile` + `.zshrc`。两套并存、跨组混搭或文件残缺都会在安装确认和写入前阻断；安装器不会猜优先级或创建另一套副本。
- HOME 端始终使用 `~/.zprofile` 和 `~/.zshrc`，分别 symlink 到已解析的同组仓库来源。
- `.zshrc` 使用 `dotfiles: shared → dotfiles: personal → dotfiles: local` 维持声明式覆盖顺序；`integrations.zsh` 通过 `dotfiles: local-integrations <phase>` 在 zprofile/zshrc 的 pre/post 阶段加载。
- 每个启用插件在 `.zshrc` 中使用 `dotfiles: plugin <name>` 标记，并按合并后的 `load_order` 递增排列。
- personal/shared 各自最多一份 `zsh/plugins.toml`；插件固定 40 位 commit，相同名称由 personal 决定。
- personal/shared 分别声明 Brewfile 和 tooling；相同 Homebrew 项目由 personal 决定。

mise 配置通过受管 symlink 进入 `~/.config/mise/conf.d/`，shared 文件名前缀为 `10-`，personal 为 `20-`。uv 的 personal `uv.toml` 通过受管 symlink 成为用户级配置，已确认的 `.python-versions` 由安装器显式交给 `uv python install`。

<!-- section:safety -->

## 安全边界

- 安装器只在原生 macOS `arm64` 会话执行真实安装；测试模式只允许 `/private/tmp` 或 `/tmp` 下的隔离 HOME。
- 替换现有 `.zprofile` 或 `.zshrc` 前，会创建保留文件类型或 symlink 目标的带时间戳副本。
- local 父目录权限必须为 `0700`，存在的 `parameters.zsh` 和 `integrations.zsh` 权限必须为 `0600`。脚本不会显示、复制、记录、持久化或哈希其内容，只执行无输出语法检查和正常 shell 加载。
- public 输出不得包含 shared 仓库专属信息、密钥或本机绝对路径。
- 服务、数据库、Homebrew service 和 GUI 应用数据只报告、人工处理，不自动启停、迁移或删除。
- retire 只处理同时具备明确 ARM 替代路径、版本/架构证据且没有 service/data 记录的精确 Intel formula；未知项目、项目依赖、NVM、Python Framework、全局 runtime、旧插件和整个 `/usr/local` 默认保留。

<!-- section:verification -->

## 测试与发布门禁

```zsh
./tests/smoke.zsh
./tests/smoke.zsh --quick
.githooks/pre-commit
```

完整 smoke 使用临时仓库和临时 HOME 验证无前置点与有前置点两种仓库来源、歧义/混搭阻断、默认 `N`、副本、symlink、幂等、shared/personal 合并、local 不泄露、retire 只读以及非 TTY 阻断。快速模式执行语法、Markdown、中英文文档章节结构、安全边界和 Intel 路径扫描。

pre-commit 不安装依赖。它要求 `gitleaks 8.30.0` 已由 Stage 2 的 mise 配置安装，并扫描当前公开工作树；CI 还会使用同一固定版本扫描当前内容和完整 Git 历史。只有快速检查、完整 smoke 和 CI 全部通过后才能发布。

<!-- section:manual -->

## 人工事项

当前 Brewfile 不会自动迁移 nginx、redis 等服务的配置或数据，也不会自动接管 GUI 应用数据、npm 全局 CLI、项目 runtime 或旧 Python Framework。必须先完成对应数据处置和 ARM 替代验证，再把精确项目带入 Stage 3。
