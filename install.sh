#!/bin/zsh

# Public entry point for Stage 2 installation and Stage 3 retirement.
# Capability-specific implementation lives in my_setup/*/install.sh.

emulate -LR zsh
setopt NO_UNSET PIPE_FAIL EXTENDED_GLOB
umask 077

readonly script_dir="${0:A:h}"
readonly repo_root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null)"

if [[ -z "$repo_root" || "$repo_root" != "$script_dir" ]]; then
  print -u2 -- 'install.sh: 必须位于当前公开 Git 仓库根目录'
  exit 1
fi

usage() {
  print -u2 -- '用法：'
  print -u2 -- '  ./install.sh'
  print -u2 -- '  ./install.sh verify'
  print -u2 -- '  ./install.sh retire'
  print -u2 -- '  ./install.sh retire --apply'
}

readonly test_mode="${DOTFILES_INSTALL_TEST_MODE:-0}"
if [[ "$test_mode" != 0 && "$test_mode" != 1 ]]; then
  print -u2 -- 'install.sh: DOTFILES_INSTALL_TEST_MODE 只能为 0 或 1'
  exit 1
fi

if [[ "$test_mode" == 1 ]]; then
  if [[ ! -d "$HOME" || -L "$HOME" || ! -O "$HOME" ]]; then
    print -u2 -- 'install.sh: 测试 HOME 必须是当前用户拥有的真实目录，且不得是 symlink'
    exit 1
  fi
  case "${HOME:A}" in
    /private/tmp/*|/tmp/*) ;;
    *)
      print -u2 -- 'install.sh: 测试模式只允许使用 /private/tmp 或 /tmp 下的隔离 HOME'
      exit 1
      ;;
  esac
fi

typeset shared_dir=''
if [[ -n "${DOTFILES_SHARED_DIR:-}" ]]; then
  if [[ "${DOTFILES_SHARED_DIR}" != /* ]]; then
    print -u2 -- 'install.sh: DOTFILES_SHARED_DIR 必须是绝对路径'
    exit 1
  fi
  shared_dir="${DOTFILES_SHARED_DIR:A}"
fi

typeset -gr DOTFILES_INSTALLER_ACTIVE=1
typeset -gr DOTFILES_REPO_ROOT="$repo_root"
typeset -gr DOTFILES_PERSONAL_DIR="$repo_root/my_setup"
typeset -gr DOTFILES_TARGET_HOME="$HOME"
typeset -gr DOTFILES_SHARED_DIR_RESOLVED="$shared_dir"
typeset -gr DOTFILES_LOCAL_DIR="$HOME/.config/dotfiles/local"
typeset -gr DOTFILES_LOCAL_FILE="$HOME/.config/dotfiles/local/parameters.zsh"
typeset -gr DOTFILES_PLUGIN_DIR="$HOME/.local/share/dotfiles/plugins"
typeset -gr DOTFILES_TEST_MODE="$test_mode"

for module in \
  "$DOTFILES_PERSONAL_DIR/zsh/install.sh" \
  "$DOTFILES_PERSONAL_DIR/tooling/install.sh" \
  "$DOTFILES_PERSONAL_DIR/macos/install.sh"; do
  if [[ ! -r "$module" ]]; then
    print -u2 -- "install.sh: 缺少内部能力模块 ${module#$repo_root/}"
    exit 1
  fi
  source "$module" || exit 1
done
unset module

typeset runtime_dir=''
cleanup_runtime() {
  if [[ -n "$runtime_dir" && -d "$runtime_dir" ]]; then
    command rm -rf -- "$runtime_dir"
  fi
}
trap cleanup_runtime EXIT
trap 'cleanup_runtime; exit 130' HUP INT TERM

prepare_runtime() {
  [[ -n "$runtime_dir" ]] && return 0
  runtime_dir="$(mktemp -d "${TMPDIR:-/private/tmp}/dotfiles-install.XXXXXX")" || return 1
  chmod 700 "$runtime_dir" || return 1
  typeset -g DOTFILES_RUNTIME_DIR="$runtime_dir"
  export TMPDIR="$runtime_dir"
  export TMP="$runtime_dir"
  export TEMP="$runtime_dir"
  export XDG_CACHE_HOME="$runtime_dir/cache"
  export MISE_CACHE_DIR="$runtime_dir/mise-cache"
  export MISE_TMP_DIR="$runtime_dir/mise-tmp"
  export UV_CACHE_DIR="$runtime_dir/uv-cache"
  export HOMEBREW_NO_ANALYTICS=1
  export HOMEBREW_NO_AUTO_UPDATE=1
  export HOMEBREW_NO_INSTALL_CLEANUP=1
}

check_architecture() {
  if [[ "$DOTFILES_TEST_MODE" == 1 ]]; then
    print -- '- 架构：隔离测试模式'
    return 0
  fi
  if [[ "$(uname -s)" != Darwin || "$(arch)" != arm64 ]]; then
    print -u2 -- 'install.sh: 真实安装、验证和退役只允许在 macOS 原生 arm64 会话运行'
    return 1
  fi
  print -- '- 架构：macOS arm64'
}

check_repositories() {
  local conflicts

  if [[ ! -d "$DOTFILES_PERSONAL_DIR" ]]; then
    print -u2 -- 'install.sh: 缺少 my_setup/'
    return 1
  fi
  if ! conflicts="$(git -C "$DOTFILES_REPO_ROOT" diff --name-only --diff-filter=U 2>/dev/null)"; then
    print -u2 -- 'install.sh: 无法检查当前公开仓库冲突状态'
    return 1
  fi
  if [[ -n "$conflicts" ]]; then
    print -u2 -- 'install.sh: 当前公开仓库存在未解决冲突，停止安装'
    return 1
  fi
  print -- "- personal：$DOTFILES_REPO_ROOT"

  if [[ -n "$DOTFILES_SHARED_DIR_RESOLVED" ]]; then
    if [[ ! -d "$DOTFILES_SHARED_DIR_RESOLVED" ]] \
      || ! git -C "$DOTFILES_SHARED_DIR_RESOLVED" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      print -u2 -- 'install.sh: DOTFILES_SHARED_DIR 必须指向唯一的现有 Git 工作树'
      return 1
    fi
    if ! conflicts="$(git -C "$DOTFILES_SHARED_DIR_RESOLVED" diff --name-only --diff-filter=U 2>/dev/null)"; then
      print -u2 -- 'install.sh: 无法检查 shared 仓库冲突状态'
      return 1
    fi
    if [[ -n "$conflicts" ]]; then
      print -u2 -- 'install.sh: shared 仓库存在未解决冲突，停止安装'
      return 1
    fi
    print -- "- shared：$DOTFILES_SHARED_DIR_RESOLVED"
  else
    print -- '- shared：未配置（可选）'
  fi
}

local_plan() {
  local mode='missing'

  if [[ -L "$DOTFILES_LOCAL_DIR" ]]; then
    print -u2 -- 'install.sh: local 目录不得是 symlink'
    return 1
  fi
  if [[ -d "$DOTFILES_LOCAL_DIR" ]]; then
    [[ -O "$DOTFILES_LOCAL_DIR" ]] || {
      print -u2 -- 'install.sh: local 目录必须属于当前用户'
      return 1
    }
    mode="$(stat -f '%Lp' "$DOTFILES_LOCAL_DIR" 2>/dev/null)"
  fi

  if [[ -e "$DOTFILES_LOCAL_FILE" || -L "$DOTFILES_LOCAL_FILE" ]]; then
    if [[ -L "$DOTFILES_LOCAL_FILE" || ! -f "$DOTFILES_LOCAL_FILE" || ! -O "$DOTFILES_LOCAL_FILE" ]]; then
      print -u2 -- 'install.sh: parameters.zsh 必须是当前用户拥有的普通文件，且不得是 symlink'
      return 1
    fi
    print -- "- local：存在；目录权限 ${mode}，安装时收敛为 0700/0600（不读取内容）"
  else
    print -- '- local：parameters.zsh 不存在；仅创建权限为 0700 的 local 目录'
  fi
}

local_apply() {
  command mkdir -p -- "$DOTFILES_LOCAL_DIR" || return 1
  chmod 700 "$DOTFILES_LOCAL_DIR" || return 1
  if [[ -f "$DOTFILES_LOCAL_FILE" && ! -L "$DOTFILES_LOCAL_FILE" ]]; then
    chmod 600 "$DOTFILES_LOCAL_FILE" || return 1
  fi
}

local_verify() {
  if [[ ! -d "$DOTFILES_LOCAL_DIR" || -L "$DOTFILES_LOCAL_DIR" || ! -O "$DOTFILES_LOCAL_DIR" ]]; then
    print -u2 -- 'verify: local 目录缺失、类型错误或 owner 错误'
    return 1
  fi
  if [[ "$(stat -f '%Lp' "$DOTFILES_LOCAL_DIR" 2>/dev/null)" != 700 ]]; then
    print -u2 -- 'verify: local 目录权限必须是 0700'
    return 1
  fi
  if [[ -e "$DOTFILES_LOCAL_FILE" || -L "$DOTFILES_LOCAL_FILE" ]]; then
    if [[ -L "$DOTFILES_LOCAL_FILE" || ! -f "$DOTFILES_LOCAL_FILE" || ! -O "$DOTFILES_LOCAL_FILE" ]]; then
      print -u2 -- 'verify: parameters.zsh 类型或 owner 错误'
      return 1
    fi
    if [[ "$(stat -f '%Lp' "$DOTFILES_LOCAL_FILE" 2>/dev/null)" != 600 ]]; then
      print -u2 -- 'verify: parameters.zsh 权限必须是 0600'
      return 1
    fi
    /bin/zsh -n "$DOTFILES_LOCAL_FILE" >/dev/null 2>&1 || {
      print -u2 -- 'verify: parameters.zsh 语法错误（内容未输出）'
      return 1
    }
  fi
  if git -C "$DOTFILES_REPO_ROOT" ls-files --error-unmatch "$DOTFILES_LOCAL_FILE" >/dev/null 2>&1; then
    print -u2 -- 'verify: parameters.zsh 不得被公开仓库跟踪'
    return 1
  fi
  if git -C "$DOTFILES_REPO_ROOT" ls-files | grep -Eq '(^|/)parameters[.]zsh$'; then
    print -u2 -- 'verify: 公开仓库不得跟踪任何 parameters.zsh'
    return 1
  fi
  if [[ -n "$DOTFILES_SHARED_DIR_RESOLVED" ]] \
    && git -C "$DOTFILES_SHARED_DIR_RESOLVED" ls-files | grep -Eq '(^|/)parameters[.]zsh$'; then
    print -u2 -- 'verify: shared 仓库不得跟踪任何 parameters.zsh'
    return 1
  fi
  print -- '✓ local 类型、owner、权限与 Git 边界'
}

hooks_plan() {
  local current
  current="$(git -C "$DOTFILES_REPO_ROOT" config --local --get core.hooksPath 2>/dev/null || true)"
  if [[ "$current" == .githooks ]]; then
    print -- '- pre-commit：core.hooksPath 已是 .githooks'
  else
    print -- "- pre-commit：设置 core.hooksPath=.githooks（当前 ${current:-未设置}）"
  fi
}

hooks_apply() {
  git -C "$DOTFILES_REPO_ROOT" config --local core.hooksPath .githooks
}

hooks_verify() {
  if [[ "$(git -C "$DOTFILES_REPO_ROOT" config --local --get core.hooksPath 2>/dev/null)" != .githooks ]]; then
    print -u2 -- 'verify: 当前公开仓库 core.hooksPath 不是 .githooks'
    return 1
  fi
  if [[ ! -x "$DOTFILES_REPO_ROOT/.githooks/pre-commit" ]]; then
    print -u2 -- 'verify: .githooks/pre-commit 缺失或不可执行'
    return 1
  fi
  print -- '✓ 公开仓库 pre-commit hook'
}

show_install_plan() {
  typeset -i blocked=0

  print -- 'Dotfiles 安装摘要'
  print -- '================'
  check_architecture || blocked=1
  check_repositories || blocked=1
  local_plan || blocked=1
  hooks_plan || blocked=1
  print
  print -- '[macos]'
  macos_plan || blocked=1
  print
  print -- '[tooling]'
  tooling_plan || blocked=1
  print
  print -- '[zsh]'
  zsh_plan || blocked=1
  print
  print -- '- 服务、数据库和 GUI 应用数据：仅报告，不自动迁移或启停'

  (( blocked == 0 ))
}

confirm_install() {
  local answer=''

  if [[ "$DOTFILES_TEST_MODE" != 1 && ( ! -t 0 || ! -t 1 ) ]]; then
    print -- 'install.sh: 非交互会话，默认 N；未执行任何安装'
    return 1
  fi
  read -r "answer?按上述摘要继续安装？[y/N] " || answer=''
  [[ "$answer" == [yY] ]]
}

run_verify() {
  typeset -i failed=0

  prepare_runtime || return 1
  print -- 'Dotfiles 验证'
  print -- '============='
  check_architecture || failed=1
  check_repositories || failed=1
  local_verify || failed=1
  hooks_verify || failed=1
  macos_verify || failed=1
  tooling_verify || failed=1
  zsh_verify || failed=1

  if (( failed != 0 )); then
    print -u2 -- 'install.sh verify: 失败'
    return 1
  fi
  print -- 'install.sh verify: 通过'
}

run_install() {
  prepare_runtime || return 1
  if ! show_install_plan; then
    print -u2 -- 'install.sh: 摘要包含阻断项，未请求确认，也未执行写入'
    return 1
  fi
  if ! confirm_install; then
    print -- 'install.sh: 已取消，未执行任何安装'
    return 0
  fi

  local_apply || return 1
  macos_apply || return 1
  tooling_apply || return 1
  zsh_apply || return 1
  hooks_apply || return 1
  run_verify
}

run_retire() {
  local apply_mode="$1"

  prepare_runtime || return 1
  check_architecture || return 1
  check_repositories || return 1
  run_verify || {
    print -u2 -- 'install.sh retire: Stage 2 验证未通过，退役被阻止'
    return 1
  }
  macos_retire_plan || return 1

  if [[ "$apply_mode" == 0 ]]; then
    return 0
  fi
  if (( MACOS_RETIRE_CANDIDATE_COUNT == 0 )); then
    return 0
  fi
  if [[ ! -t 0 || ! -t 1 ]]; then
    print -u2 -- 'install.sh retire --apply: 必须在 stdin/stdout 均为真实 TTY 时运行'
    return 1
  fi

  local answer=''
  read -r "answer?仅按上述清单正式退役？[y/N] " || answer=''
  if [[ "$answer" != [yY] ]]; then
    print -- 'install.sh retire --apply: 已取消，无变更'
    return 0
  fi
  macos_retire_apply || return 1
  run_verify
}

case "$#:$*" in
  '0:') run_install ;;
  '1:verify') run_verify ;;
  '1:retire') run_retire 0 ;;
  '2:retire --apply') run_retire 1 ;;
  *)
    usage
    exit 2
    ;;
esac
