#!/bin/zsh

# Internal Homebrew capability module. Use the repository-root install.sh.

if [[ "${DOTFILES_INSTALLER_ACTIVE:-0}" != 1 || "${ZSH_EVAL_CONTEXT:-}" != *:file* ]]; then
  print -u2 -- 'my_setup/macos/install.sh 是内部模块；请从仓库根目录运行 ./install.sh'
  return 1 2>/dev/null || exit 1
fi

typeset -gA MACOS_BREW_LINE
typeset -gA MACOS_BREW_OWNER
typeset -g MACOS_BREW_COMMAND=''
typeset -gA MACOS_RETIRE_REASON
typeset -gA MACOS_RETIRE_KEEP_REASON
typeset -gi MACOS_RETIRE_CANDIDATE_COUNT=0

macos_trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  print -r -- "$value"
}

macos_parse_brewfile() {
  local file="$1"
  local owner="$2"
  local line kind rest name key

  [[ -f "$file" && ! -L "$file" ]] || {
    print -u2 -- "macos: Brewfile 缺失或不是普通文件：$file"
    return 1
  }
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(macos_trim "$line")"
    [[ -z "$line" || "$line" == \#* ]] && continue
    kind="${line%% *}"
    case "$kind" in
      tap|brew|cask|vscode) ;;
      *)
        print -u2 -- "macos: Brewfile 只允许 tap/brew/cask/vscode 直接声明：$file"
        return 1
        ;;
    esac
    rest="$(macos_trim "${line#$kind}")"
    if [[ "$rest" != \"*\" || "$rest" == *\",* || "$rest" == *[[:space:]]* ]]; then
      print -u2 -- "macos: Brewfile 首版不执行带参数或动态 Ruby 的声明：$line"
      return 1
    fi
    name="${rest[2,-2]}"
    if [[ -z "$name" || "$name" == *\"* ]]; then
      print -u2 -- "macos: Brewfile 项目名无效：$line"
      return 1
    fi
    key="$kind:$name"
    MACOS_BREW_LINE[$key]="$kind \"$name\""
    MACOS_BREW_OWNER[$key]="$owner"
  done < "$file"
}

macos_load_brewfiles() {
  MACOS_BREW_LINE=()
  MACOS_BREW_OWNER=()

  if [[ -n "$DOTFILES_SHARED_DIR_RESOLVED" \
    && -e "$DOTFILES_SHARED_DIR_RESOLVED/macos/Brewfile" ]]; then
    macos_parse_brewfile "$DOTFILES_SHARED_DIR_RESOLVED/macos/Brewfile" shared || return 1
  fi
  macos_parse_brewfile "$DOTFILES_PERSONAL_DIR/macos/Brewfile" personal || return 1
  if (( ${#MACOS_BREW_LINE} == 0 )); then
    print -u2 -- 'macos: 合并后的 Brewfile 没有直接期望项目'
    return 1
  fi
}

macos_write_effective_brewfile() {
  local key
  local output="$DOTFILES_RUNTIME_DIR/Brewfile"

  : > "$output" || return 1
  chmod 600 "$output" || return 1
  for key in ${(ok)MACOS_BREW_LINE}; do
    print -r -- "$MACOS_BREW_LINE[$key]" >> "$output" || return 1
  done
  print -r -- "$output"
}

macos_prepare_brew() {
  if [[ "$DOTFILES_TEST_MODE" == 1 ]]; then
    MACOS_BREW_COMMAND="${commands[brew]:-}"
  else
    MACOS_BREW_COMMAND=/opt/homebrew/bin/brew
  fi
  if [[ -z "$MACOS_BREW_COMMAND" || ! -x "$MACOS_BREW_COMMAND" ]]; then
    print -u2 -- 'macos: 缺少 Apple Silicon Homebrew；请先按官方流程人工安装并审查来源'
    return 1
  fi
  if [[ "$DOTFILES_TEST_MODE" != 1 ]]; then
    if [[ "$($MACOS_BREW_COMMAND --prefix 2>/dev/null)" != /opt/homebrew ]]; then
      print -u2 -- 'macos: /opt/homebrew/bin/brew 未报告 ARM prefix'
      return 1
    fi
    if ! file -L "$MACOS_BREW_COMMAND" | grep -Eq 'arm64|script text'; then
      print -u2 -- 'macos: Homebrew 入口不是 ARM 二进制或受支持脚本'
      return 1
    fi
  fi
}

macos_plan() {
  local key owner
  typeset -i personal_count=0
  typeset -i shared_count=0

  macos_load_brewfiles || return 1
  macos_prepare_brew || return 1
  for key in ${(k)MACOS_BREW_LINE}; do
    owner="$MACOS_BREW_OWNER[$key]"
    if [[ "$owner" == shared ]]; then
      (( shared_count += 1 ))
    else
      (( personal_count += 1 ))
    fi
  done
  print -- "- Homebrew：$MACOS_BREW_COMMAND"
  print -- "- 合并期望：personal $personal_count 项，shared $shared_count 项；同名由 personal 决定"
  print -- '- 仅安装 Brewfile 声明；不启停 service，不迁移数据库或 GUI 数据'
}

macos_apply() {
  local effective

  macos_load_brewfiles || return 1
  macos_prepare_brew || return 1
  effective="$(macos_write_effective_brewfile)" || return 1
  "$MACOS_BREW_COMMAND" bundle --file="$effective" --no-upgrade
}

macos_formula_command() {
  local formula="$1"
  case "$formula" in
    ast-grep) print -r -- ast-grep ;;
    cmake) print -r -- cmake ;;
    gh) print -r -- gh ;;
    git-lfs) print -r -- git-lfs ;;
    graphviz) print -r -- dot ;;
    mise) print -r -- mise ;;
    poppler) print -r -- pdftoppm ;;
    ripgrep) print -r -- rg ;;
    rsync) print -r -- rsync ;;
    silicon) print -r -- silicon ;;
    temporal) print -r -- temporal ;;
    tmux) print -r -- tmux ;;
    tree) print -r -- tree ;;
    uv) print -r -- uv ;;
    vhs) print -r -- vhs ;;
    zoxide) print -r -- zoxide ;;
    *) return 1 ;;
  esac
}

macos_verify() {
  local effective key kind name command_name command_path shell_path
  typeset -i failed=0

  macos_load_brewfiles || return 1
  macos_prepare_brew || return 1
  effective="$(macos_write_effective_brewfile)" || return 1

  "$MACOS_BREW_COMMAND" bundle check --file="$effective" >/dev/null 2>&1 || {
    print -u2 -- 'verify: Homebrew 仍有未满足的 Brewfile 项目'
    failed=1
  }

  if [[ "$DOTFILES_TEST_MODE" != 1 ]]; then
    shell_path="$(env -u ZDOTDIR HOME="$DOTFILES_TARGET_HOME" /bin/zsh -l -c 'print -r -- "$PATH"' 2>/dev/null)" || {
      print -u2 -- 'verify: 无法读取受管 login shell PATH'
      failed=1
      shell_path=''
    }
    if [[ ":$shell_path:" == *:/usr/local/bin:* || ":$shell_path:" == *:/usr/local/sbin:* ]]; then
      print -u2 -- 'verify: 受管 login shell PATH 仍包含活动 Intel Homebrew'
      failed=1
    fi

    for key in ${(k)MACOS_BREW_LINE}; do
      kind="${key%%:*}"
      name="${key#*:}"
      [[ "$kind" == brew ]] || continue
      command_name="$(macos_formula_command "$name" 2>/dev/null)" || continue
      command_path="/opt/homebrew/bin/$command_name"
      [[ -x "$command_path" ]] || command_path="/opt/homebrew/sbin/$command_name"
      if [[ ! -x "$command_path" ]]; then
        print -u2 -- "verify: $name 的关键命令 $command_name 不在 /opt/homebrew"
        failed=1
      elif ! file -L "$command_path" | grep -Eq 'arm64|universal binary|script text'; then
        print -u2 -- "verify: $command_name 不是 ARM、Universal 或受支持脚本"
        failed=1
      fi
    done
  fi

  if (( failed == 0 )); then
    print -- '✓ ARM Homebrew、合并 Brewfile、关键命令来源与 PATH'
  fi
  (( failed == 0 ))
}

macos_intel_brew() {
  if [[ "$DOTFILES_TEST_MODE" == 1 && -n "${DOTFILES_TEST_INTEL_BREW:-}" ]]; then
    print -r -- "$DOTFILES_TEST_INTEL_BREW"
  else
    print -r -- /usr/local/bin/brew
  fi
}

macos_collect_retire() {
  local intel_brew formula key command_name command_path
  local intel_formulae services arm_formulae
  typeset -A desired

  MACOS_RETIRE_REASON=()
  MACOS_RETIRE_KEEP_REASON=()
  MACOS_RETIRE_CANDIDATE_COUNT=0
  macos_load_brewfiles || return 1
  macos_prepare_brew || return 1

  intel_brew="$(macos_intel_brew)"
  if [[ ! -x "$intel_brew" ]]; then
    return 0
  fi
  if [[ "$DOTFILES_TEST_MODE" != 1 \
    && "$($intel_brew --prefix 2>/dev/null)" != /usr/local ]]; then
    print -u2 -- 'retire: Intel Homebrew 未报告 /usr/local prefix，拒绝盘点'
    return 1
  fi

  intel_formulae="$($intel_brew list --formula -1 2>/dev/null)" || return 1
  services="$($intel_brew services list 2>/dev/null)" || services=''
  arm_formulae="$($MACOS_BREW_COMMAND list --formula -1 2>/dev/null)" || return 1

  for key in ${(k)MACOS_BREW_LINE}; do
    [[ "${key%%:*}" == brew ]] && desired[${key#*:}]=1
  done

  for formula in ${(f)intel_formulae}; do
    [[ -n "$formula" ]] || continue
    if [[ -z "${desired[$formula]:-}" ]]; then
      MACOS_RETIRE_KEEP_REASON[$formula]='不在已确认 ARM 期望中，分类为未知/项目依赖'
      continue
    fi
    if ! print -r -- "$arm_formulae" | grep -Fxq -- "$formula"; then
      MACOS_RETIRE_KEEP_REASON[$formula]='同名 ARM formula 尚未安装'
      continue
    fi
    if print -r -- "$services" | awk 'NR > 1 { print $1 }' | grep -Fxq -- "$formula"; then
      MACOS_RETIRE_KEEP_REASON[$formula]='存在 Homebrew service/data 记录，必须人工处理'
      continue
    fi
    command_name="$(macos_formula_command "$formula" 2>/dev/null)" || {
      MACOS_RETIRE_KEEP_REASON[$formula]='缺少可验证的关键命令映射'
      continue
    }
    if [[ "$DOTFILES_TEST_MODE" == 1 ]]; then
      command_path="test://arm/$command_name"
    else
      command_path="/opt/homebrew/bin/$command_name"
      [[ -x "$command_path" ]] || command_path="/opt/homebrew/sbin/$command_name"
      if [[ ! -x "$command_path" ]] \
        || ! file -L "$command_path" | grep -Eq 'arm64|universal binary|script text'; then
        MACOS_RETIRE_KEEP_REASON[$formula]="ARM 关键命令 $command_name 的路径/架构验证失败"
        continue
      fi
    fi
    MACOS_RETIRE_REASON[$formula]="ARM 替代已验证：$command_path"
    (( MACOS_RETIRE_CANDIDATE_COUNT += 1 ))
  done
}

macos_retire_plan() {
  local formula intel_brew intel_casks

  macos_collect_retire || return 1
  intel_brew="$(macos_intel_brew)"
  print -- 'Intel Homebrew 退役预览（只读）'
  print -- '============================='
  if [[ ! -x "$intel_brew" ]]; then
    print -- '- 无 Intel Homebrew；无需执行 --apply'
    return 0
  fi

  if (( MACOS_RETIRE_CANDIDATE_COUNT == 0 )); then
    print -- '- 可安全退役：无'
  else
    print -- '- 可安全退役：'
    for formula in ${(ok)MACOS_RETIRE_REASON}; do
      print -- "  - $formula：$MACOS_RETIRE_REASON[$formula]"
    done
  fi
  print -- '- 明确保留/阻断：'
  if (( ${#MACOS_RETIRE_KEEP_REASON} == 0 )); then
    print -- '  - 无'
  else
    for formula in ${(ok)MACOS_RETIRE_KEEP_REASON}; do
      print -- "  - $formula：$MACOS_RETIRE_KEEP_REASON[$formula]"
    done
  fi
  intel_casks="$($intel_brew list --cask -1 2>/dev/null)" || intel_casks=''
  for formula in ${(f)intel_casks}; do
    [[ -n "$formula" ]] && print -- "  - cask:$formula：GUI 应用与数据未知，保留"
  done
  print -- '- /usr/local 不递归删除；NVM、Python Framework、全局 runtime、旧插件和 service/data 均保留，等待明确证据'
  if (( MACOS_RETIRE_CANDIDATE_COUNT == 0 )); then
    print -- '- 结论：当前无需执行 --apply'
  else
    print -- '- 验证计划：重新运行 verify 和 retire 只读预览'
  fi
}

macos_retire_apply() {
  local intel_brew formula

  if (( MACOS_RETIRE_CANDIDATE_COUNT == 0 )); then
    print -- 'retire: 无可安全退役项目'
    return 0
  fi
  intel_brew="$(macos_intel_brew)"
  [[ -x "$intel_brew" ]] || return 1
  for formula in ${(ok)MACOS_RETIRE_REASON}; do
    print -- "retire: 退役 Intel Homebrew formula $formula"
    "$intel_brew" uninstall "$formula" || return 1
  done
}
