#!/bin/zsh

emulate -LR zsh
setopt NO_UNSET PIPE_FAIL
umask 077

readonly script_dir="${0:A:h}"
readonly repo_root="${script_dir:h}"
readonly hook_source="$script_dir/pre-commit"
readonly hook_marker='# dotfiles-managed-pre-commit-v1'
readonly gitleaks_spec='ubi:gitleaks/gitleaks@8.30.0'

if [[ "$(git -C "$repo_root" rev-parse --show-toplevel 2>/dev/null)" != "$repo_root" ]]; then
  print -u2 -- 'githooks/install.sh: 必须位于当前 Git checkout 的 .githooks/ 中'
  exit 1
fi
if [[ ! -f "$hook_source" || -L "$hook_source" || ! -x "$hook_source" ]]; then
  print -u2 -- 'githooks/install.sh: .githooks/pre-commit 必须是可执行普通文件'
  exit 1
fi

readonly custom_hooks_path="$(git -C "$repo_root" config --get core.hooksPath 2>/dev/null || true)"
if [[ -n "$custom_hooks_path" ]]; then
  print -u2 -- "githooks/install.sh: 检测到自定义 core.hooksPath=$custom_hooks_path；拒绝绕过 Git 默认 hooks 目录"
  exit 1
fi

typeset hooks_dir="$(git -C "$repo_root" rev-parse --git-path hooks 2>/dev/null)"
[[ "$hooks_dir" == /* ]] || hooks_dir="$repo_root/$hooks_dir"
hooks_dir="${hooks_dir:A}"
readonly hook_target="$hooks_dir/pre-commit"

if [[ -e "$hook_target" || -L "$hook_target" ]]; then
  if [[ -L "$hook_target" || ! -f "$hook_target" || ! -O "$hook_target" ]] \
    || ! command head -n 2 "$hook_target" 2>/dev/null | grep -Fxq -- "$hook_marker"; then
    print -u2 -- "githooks/install.sh: 默认目标已存在且不属于本安装器，拒绝覆盖：$hook_target"
    exit 1
  fi
fi

readonly mise_command="${commands[mise]:-}"
if [[ -z "$mise_command" || ! -x "$mise_command" ]]; then
  print -u2 -- 'githooks/install.sh: 缺少 mise；请先独立安装 mise，再重试一次性仓库初始化'
  exit 1
fi

"$mise_command" --no-config install "$gitleaks_spec" || exit 1

command mkdir -p -- "$hooks_dir" || exit 1
typeset temporary="$(mktemp "$hooks_dir/.pre-commit.XXXXXX")" || exit 1
trap '[[ -n "$temporary" ]] && command rm -f -- "$temporary"' EXIT HUP INT TERM
{
  print -r -- '#!/bin/zsh'
  print -r -- "$hook_marker"
  print -r -- ''
  print -r -- 'emulate -LR zsh'
  print -r -- 'setopt NO_UNSET PIPE_FAIL'
  print -r -- ''
  print -r -- 'readonly repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"'
  print -r -- 'readonly managed_hook="$repo_root/.githooks/pre-commit"'
  print -r -- 'if [[ -z "$repo_root" || ! -x "$managed_hook" ]]; then'
  print -r -- "  print -u2 -- 'pre-commit: 无法定位仓库跟踪的 .githooks/pre-commit'"
  print -r -- '  exit 1'
  print -r -- 'fi'
  print -r -- 'exec "$managed_hook" "$@"'
} > "$temporary" || exit 1
chmod 700 "$temporary" || exit 1
command mv -f -- "$temporary" "$hook_target" || exit 1
temporary=''

if [[ ! -f "$hook_target" || -L "$hook_target" || ! -x "$hook_target" ]] \
  || ! command head -n 2 "$hook_target" | grep -Fxq -- "$hook_marker"; then
  print -u2 -- 'githooks/install.sh: 默认 pre-commit hook 安装验证失败'
  exit 1
fi

print -- "githooks/install.sh: 已安装 $hook_target"
print -- "githooks/install.sh: Gitleaks 由 mise 固定为 $gitleaks_spec"
