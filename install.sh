#!/bin/zsh

# Public entry point for Stage 2 installation and Stage 3 retirement.
# It consumes only the declarations in the current checkout.

emulate -LR zsh
setopt NO_UNSET PIPE_FAIL EXTENDED_GLOB
umask 077

readonly script_dir="${0:A:h}"
readonly repo_root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null)"

if [[ -z "$repo_root" || "$repo_root" != "$script_dir" ]]; then
  print -u2 -- 'install.sh: 必须位于当前公开 Git checkout 根目录'
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
  if [[ "$DOTFILES_SHARED_DIR" != /* ]]; then
    print -u2 -- 'install.sh: DOTFILES_SHARED_DIR 必须是绝对路径'
    exit 1
  fi
  shared_dir="${DOTFILES_SHARED_DIR:A}"
fi

typeset -g DOTFILES_NATIVE_ARCH=''
typeset -g DOTFILES_PROCESS_ARCH=''
typeset -g DOTFILES_ROSETTA_TRANSLATED=0
typeset -g DOTFILES_HOMEBREW_PREFIX=''
typeset -g DOTFILES_HOMEBREW_COMMAND=''

detect_architecture() {
  local hardware_arm64 translated

  if [[ "$test_mode" == 1 ]]; then
    DOTFILES_NATIVE_ARCH="${DOTFILES_TEST_NATIVE_ARCH:-arm64}"
    DOTFILES_PROCESS_ARCH="${DOTFILES_TEST_PROCESS_ARCH:-$DOTFILES_NATIVE_ARCH}"
    DOTFILES_ROSETTA_TRANSLATED="${DOTFILES_TEST_TRANSLATED:-0}"
  else
    if [[ "$(uname -s)" != Darwin ]]; then
      print -u2 -- 'install.sh: 真实安装、验证和退役只支持 macOS'
      return 1
    fi
    hardware_arm64="$(sysctl -in hw.optional.arm64 2>/dev/null)" || {
      print -u2 -- 'install.sh: 无法读取原生硬件架构'
      return 1
    }
    DOTFILES_PROCESS_ARCH="$(arch 2>/dev/null)" || return 1
    if [[ "$hardware_arm64" == 1 ]]; then
      DOTFILES_NATIVE_ARCH=arm64
      translated="$(sysctl -in sysctl.proc_translated 2>/dev/null || print 0)"
      DOTFILES_ROSETTA_TRANSLATED="$translated"
    elif [[ "$hardware_arm64" == 0 ]]; then
      DOTFILES_NATIVE_ARCH=x86_64
      DOTFILES_ROSETTA_TRANSLATED=0
    else
      print -u2 -- "install.sh: 未知的原生硬件事实 hw.optional.arm64=$hardware_arm64"
      return 1
    fi
  fi

  case "$DOTFILES_NATIVE_ARCH" in
    arm64)
      DOTFILES_HOMEBREW_PREFIX=/opt/homebrew
      ;;
    x86_64)
      DOTFILES_HOMEBREW_PREFIX=/usr/local
      ;;
    *)
      print -u2 -- "install.sh: 不支持的原生架构 $DOTFILES_NATIVE_ARCH"
      return 1
      ;;
  esac
  DOTFILES_HOMEBREW_COMMAND="$DOTFILES_HOMEBREW_PREFIX/bin/brew"
}

detect_architecture || exit 1

typeset -gr DOTFILES_INSTALLER_ACTIVE=1
typeset -gr DOTFILES_REPO_ROOT="$repo_root"
typeset -gr DOTFILES_PERSONAL_DIR="$repo_root/my_setup"
typeset -gr DOTFILES_TARGET_HOME="$HOME"
typeset -gr DOTFILES_SHARED_DIR_RESOLVED="$shared_dir"
typeset -gr DOTFILES_LOCAL_DIR="$HOME/.config/dotfiles/local"
typeset -gr DOTFILES_LOCAL_FILE="$HOME/.config/dotfiles/local/parameters.zsh"
typeset -gr DOTFILES_LOCAL_INTEGRATIONS_FILE="$HOME/.config/dotfiles/local/integrations.zsh"
typeset -gr DOTFILES_PLUGIN_DIR="$HOME/.local/share/dotfiles/plugins"
typeset -gr DOTFILES_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
typeset -gr DOTFILES_INTEL_HANDOFF_FILE="$DOTFILES_STATE_DIR/intel_to_be_retired.tsv"
typeset -gr DOTFILES_TEST_MODE="$test_mode"
typeset -gi DOTFILES_MACOS_ENABLED=0
typeset -gi DOTFILES_TOOLING_ENABLED=0
typeset -gi DOTFILES_ZSH_ENABLED=0

load_required_module() {
  local name="$1"
  local directory="$2"
  local module="$directory/install.sh"

  if [[ ! -d "$directory" || ! -r "$module" ]]; then
    print -u2 -- "install.sh: 最小 checkout 缺少完整 $name 模块：${directory#$repo_root/}/"
    return 1
  fi
  source "$module" || return 1
}

load_optional_zsh_module() {
  local directory="$DOTFILES_PERSONAL_DIR/zsh"
  local module="$directory/install.sh"

  if [[ ! -e "$directory" && ! -e "$module" ]]; then
    DOTFILES_ZSH_ENABLED=0
    return 0
  fi
  if [[ ! -d "$directory" || ! -r "$module" ]]; then
    print -u2 -- 'install.sh: Zsh 模块只 checkout 了一部分；请完整 checkout my_setup/zsh/ 或整体移除'
    return 1
  fi
  source "$module" || return 1
  DOTFILES_ZSH_ENABLED=1
}

load_required_module macOS "$DOTFILES_PERSONAL_DIR/macos" || exit 1
DOTFILES_MACOS_ENABLED=1
load_required_module tooling "$DOTFILES_PERSONAL_DIR/tooling" || exit 1
DOTFILES_TOOLING_ENABLED=1
load_optional_zsh_module || exit 1

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
  if [[ "$DOTFILES_NATIVE_ARCH" == arm64 \
    && ( "$DOTFILES_PROCESS_ARCH" != arm64 || "$DOTFILES_ROSETTA_TRANSLATED" != 0 ) ]]; then
    print -u2 -- 'install.sh: Apple Silicon 必须从原生 arm64 会话运行；不会回退使用 Intel Homebrew'
    return 1
  fi
  print -- "- 原生架构：$DOTFILES_NATIVE_ARCH；进程：$DOTFILES_PROCESS_ARCH；Rosetta：$DOTFILES_ROSETTA_TRANSLATED"
  print -- "- 原生 Homebrew：$DOTFILES_HOMEBREW_COMMAND（prefix $DOTFILES_HOMEBREW_PREFIX）"
}

check_repositories() {
  local conflicts

  if ! conflicts="$(git -C "$DOTFILES_REPO_ROOT" diff --name-only --diff-filter=U 2>/dev/null)"; then
    print -u2 -- 'install.sh: 无法检查当前 public checkout 冲突状态'
    return 1
  fi
  if [[ -n "$conflicts" ]]; then
    print -u2 -- 'install.sh: 当前 public checkout 存在未解决冲突'
    return 1
  fi
  print -- "- public checkout：$DOTFILES_REPO_ROOT"

  if [[ -n "$DOTFILES_SHARED_DIR_RESOLVED" ]]; then
    if [[ ! -d "$DOTFILES_SHARED_DIR_RESOLVED" ]] \
      || ! git -C "$DOTFILES_SHARED_DIR_RESOLVED" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      print -u2 -- 'install.sh: DOTFILES_SHARED_DIR 必须指向现有 Git checkout'
      return 1
    fi
    conflicts="$(git -C "$DOTFILES_SHARED_DIR_RESOLVED" diff --name-only --diff-filter=U 2>/dev/null)" || return 1
    if [[ -n "$conflicts" ]]; then
      print -u2 -- 'install.sh: shared checkout 存在未解决冲突'
      return 1
    fi
    print -- "- shared checkout：$DOTFILES_SHARED_DIR_RESOLVED"
  else
    print -- '- shared checkout：未配置（可选）'
  fi
  print -- '- 模块：macOS=启用，tooling=启用，Zsh='"$([[ "$DOTFILES_ZSH_ENABLED" == 1 ]] && print 启用 || print 未checkout)"
}

local_plan() {
  local mode='missing' local_file local_name
  local -a present

  if (( ! DOTFILES_ZSH_ENABLED )); then
    print -- '- local Zsh：Zsh 模块未启用，不创建或修改 local 目录'
    return 0
  fi
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
  for local_file in "$DOTFILES_LOCAL_FILE" "$DOTFILES_LOCAL_INTEGRATIONS_FILE"; do
    local_name="${local_file:t}"
    if [[ -e "$local_file" || -L "$local_file" ]]; then
      if [[ -L "$local_file" || ! -f "$local_file" || ! -O "$local_file" ]]; then
        print -u2 -- "install.sh: $local_name 必须是当前用户拥有的普通文件，且不得是 symlink"
        return 1
      fi
      present+=("$local_name")
    fi
  done
  if (( ${#present[@]} > 0 )); then
    print -- "- local Zsh：${(j:、:)present} 存在；目录权限 ${mode}，安装时收敛为 0700/0600（不读取内容）"
  else
    print -- '- local Zsh：文件均不存在；安装时只创建 0700 local 目录'
  fi
}

local_apply() {
  (( DOTFILES_ZSH_ENABLED )) || return 0
  command mkdir -p -- "$DOTFILES_LOCAL_DIR" || return 1
  chmod 700 "$DOTFILES_LOCAL_DIR" || return 1
  local local_file
  for local_file in "$DOTFILES_LOCAL_FILE" "$DOTFILES_LOCAL_INTEGRATIONS_FILE"; do
    if [[ -f "$local_file" && ! -L "$local_file" ]]; then
      chmod 600 "$local_file" || return 1
    fi
  done
}

local_verify() {
  local local_file local_name
  if (( ! DOTFILES_ZSH_ENABLED )); then
    print -- '✓ local Zsh 未启用（未触碰）'
    return 0
  fi
  if [[ ! -d "$DOTFILES_LOCAL_DIR" || -L "$DOTFILES_LOCAL_DIR" || ! -O "$DOTFILES_LOCAL_DIR" \
    || "$(stat -f '%Lp' "$DOTFILES_LOCAL_DIR" 2>/dev/null)" != 700 ]]; then
    print -u2 -- 'verify: local 目录缺失、类型/owner 错误或权限不是 0700'
    return 1
  fi
  for local_file in "$DOTFILES_LOCAL_FILE" "$DOTFILES_LOCAL_INTEGRATIONS_FILE"; do
    local_name="${local_file:t}"
    if [[ -e "$local_file" || -L "$local_file" ]]; then
      if [[ -L "$local_file" || ! -f "$local_file" || ! -O "$local_file" \
        || "$(stat -f '%Lp' "$local_file" 2>/dev/null)" != 600 ]]; then
        print -u2 -- "verify: $local_name 类型、owner 或权限错误"
        return 1
      fi
      /bin/zsh -n "$local_file" >/dev/null 2>&1 || {
        print -u2 -- "verify: $local_name 语法错误（内容未输出）"
        return 1
      }
    fi
  done
  if git -C "$DOTFILES_REPO_ROOT" ls-files | grep -Eq '(^|/)(parameters|integrations)[.]zsh$'; then
    print -u2 -- 'verify: public checkout 不得跟踪 local Zsh 文件'
    return 1
  fi
  if [[ -n "$DOTFILES_SHARED_DIR_RESOLVED" ]] \
    && git -C "$DOTFILES_SHARED_DIR_RESOLVED" ls-files | grep -Eq '(^|/)(parameters|integrations)[.]zsh$'; then
    print -u2 -- 'verify: shared checkout 不得跟踪 local Zsh 文件'
    return 1
  fi
  print -- '✓ local Zsh 类型、owner、权限与 Git 边界'
}

show_install_plan() {
  typeset -i blocked=0
  print -- 'Dotfiles 安装摘要'
  print -- '================'
  check_architecture || blocked=1
  check_repositories || blocked=1
  local_plan || blocked=1
  print
  print -- '[macOS]'
  macos_plan || blocked=1
  print
  print -- '[tooling]'
  tooling_plan || blocked=1
  print
  print -- '[Zsh]'
  if (( DOTFILES_ZSH_ENABLED )); then
    zsh_plan || blocked=1
  else
    print -- '- 未 checkout，跳过 Zsh、plugin 与 HOME Zsh 入口'
  fi
  print
  print -- '- 服务、数据库和 GUI 应用数据：仅报告，不自动迁移或启停'
  print -- "- Intel 退役交接：$DOTFILES_INTEL_HANDOFF_FILE（只供 Stage 3 重新核验）"
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
  typeset -i install_failed=0 handoff_failed=0

  prepare_runtime || return 1
  print -- 'A. 安装完整性'
  print -- '==============='
  check_architecture || install_failed=1
  check_repositories || install_failed=1
  local_verify || install_failed=1
  macos_verify || install_failed=1
  tooling_verify || install_failed=1
  if (( DOTFILES_ZSH_ENABLED )); then
    zsh_verify || install_failed=1
  else
    print -- '✓ Zsh 模块未 checkout（不属于本次声明目标）'
  fi
  if (( install_failed )); then
    print -u2 -- 'A. 安装完整性：失败'
  else
    print -- 'A. 安装完整性：通过'
  fi

  print
  print -- 'B. Intel 退役交接'
  print -- '================='
  macos_verify_retirement_handoff || handoff_failed=1
  if (( handoff_failed )); then
    print -u2 -- 'B. Intel 退役交接：失败'
  else
    print -- 'B. Intel 退役交接：通过'
  fi

  if (( install_failed || handoff_failed )); then
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

  macos_apply || return 1
  tooling_apply || return 1
  if (( DOTFILES_ZSH_ENABLED )); then
    local_apply || return 1
    zsh_apply || return 1
  fi
  run_verify
}

run_retire() {
  local apply_mode="$1"
  prepare_runtime || return 1
  check_architecture || return 1
  check_repositories || return 1
  run_verify || {
    print -u2 -- 'install.sh retire: Stage 2 A/B 验证未通过，退役被阻止'
    return 1
  }
  macos_retire_plan || return 1
  [[ "$apply_mode" == 1 ]] || return 0
  (( MACOS_RETIRE_CANDIDATE_COUNT > 0 )) || return 0
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
  *) usage; exit 2 ;;
esac
