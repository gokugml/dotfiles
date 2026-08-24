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
typeset -ga MACOS_HANDOFF_ROWS
typeset -gr MACOS_HANDOFF_MARKER='# dotfiles-intel-retirement-handoff-v1'

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
    MACOS_BREW_COMMAND="$DOTFILES_HOMEBREW_COMMAND"
  fi
  if [[ -z "$MACOS_BREW_COMMAND" || ! -x "$MACOS_BREW_COMMAND" ]]; then
    print -u2 -- "macos: 缺少当前原生架构 Homebrew：$DOTFILES_HOMEBREW_COMMAND"
    return 1
  fi
  if [[ "$($MACOS_BREW_COMMAND --prefix 2>/dev/null)" != "$DOTFILES_HOMEBREW_PREFIX" ]]; then
    print -u2 -- "macos: $MACOS_BREW_COMMAND 未报告原生 prefix $DOTFILES_HOMEBREW_PREFIX"
    return 1
  fi
  if [[ "$DOTFILES_TEST_MODE" != 1 ]]; then
    local expected_arch='x86_64|universal binary|script text'
    [[ "$DOTFILES_NATIVE_ARCH" == arm64 ]] && expected_arch='arm64|universal binary|script text'
    if ! file -L "$MACOS_BREW_COMMAND" | grep -Eq "$expected_arch"; then
      print -u2 -- 'macos: Homebrew 入口架构与原生硬件不一致'
      return 1
    fi
  fi
}

macos_plan() {
  local key owner kind name target
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
  for key in ${(ok)MACOS_BREW_LINE}; do
    owner="$MACOS_BREW_OWNER[$key]"
    kind="${key%%:*}"
    name="${key#*:}"
    case "$kind" in
      brew) target="$DOTFILES_HOMEBREW_PREFIX/Cellar/$name" ;;
      cask) target="$DOTFILES_HOMEBREW_PREFIX/Caskroom/$name" ;;
      tap) target="$DOTFILES_HOMEBREW_PREFIX/Library/Taps/$name" ;;
      vscode) target="$HOME/.vscode/extensions/$name" ;;
    esac
    print -- "- package source：$MACOS_BREW_OWNER[$key] Brewfile [$MACOS_BREW_LINE[$key]]"
    print -- "  target：$target；action：Homebrew bundle ensure"
  done
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
  local effective key kind name command_name command_path expected_arch
  typeset -i failed=0

  macos_load_brewfiles || return 1
  macos_prepare_brew || return 1
  effective="$(macos_write_effective_brewfile)" || return 1

  "$MACOS_BREW_COMMAND" bundle check --file="$effective" >/dev/null 2>&1 || {
    print -u2 -- 'verify: Homebrew 仍有未满足的 Brewfile 项目'
    failed=1
  }

  if [[ "$DOTFILES_TEST_MODE" != 1 ]]; then
    expected_arch='x86_64|universal binary|script text'
    [[ "$DOTFILES_NATIVE_ARCH" == arm64 ]] && expected_arch='arm64|universal binary|script text'
    for key in ${(k)MACOS_BREW_LINE}; do
      kind="${key%%:*}"
      name="${key#*:}"
      [[ "$kind" == brew ]] || continue
      command_name="$(macos_formula_command "$name" 2>/dev/null)" || continue
      command_path="$DOTFILES_HOMEBREW_PREFIX/bin/$command_name"
      [[ -x "$command_path" ]] || command_path="$DOTFILES_HOMEBREW_PREFIX/sbin/$command_name"
      if [[ ! -x "$command_path" ]]; then
        print -u2 -- "verify: $name 的关键命令 $command_name 不在 $DOTFILES_HOMEBREW_PREFIX"
        failed=1
      elif ! file -L "$command_path" | grep -Eq "$expected_arch"; then
        print -u2 -- "verify: $command_name 的架构不符合 $DOTFILES_NATIVE_ARCH"
        failed=1
      fi
    done
  fi

  if (( failed == 0 )); then
    print -- "✓ $DOTFILES_NATIVE_ARCH Homebrew、合并 Brewfile与关键命令原生目标"
  fi
  (( failed == 0 ))
}

macos_intel_brew() {
  if [[ "$DOTFILES_TEST_MODE" == 1 && -n "${DOTFILES_TEST_INTEL_BREW:-}" ]]; then
    print -r -- "$DOTFILES_TEST_INTEL_BREW"
  elif [[ "$DOTFILES_TEST_MODE" == 1 ]]; then
    print -r -- "$DOTFILES_RUNTIME_DIR/no-intel-homebrew"
  else
    print -r -- /usr/local/bin/brew
  fi
}

macos_handoff_add() {
  local field row=''
  local -a fields
  fields=("$@")
  if (( ${#fields} != 7 )); then
    print -u2 -- 'handoff: 内部 TSV 字段数量错误'
    return 1
  fi
  for field in "${fields[@]}"; do
    if [[ "$field" == *$'\t'* || "$field" == *$'\n'* || "$field" == *$'\r'* ]]; then
      print -u2 -- 'handoff: TSV 字段包含制表符或换行，拒绝写入'
      return 1
    fi
  done
  row="${fields[1]}"$'\t'"${fields[2]}"$'\t'"${fields[3]}"$'\t'"${fields[4]}"$'\t'\
"${fields[5]}"$'\t'"${fields[6]}"$'\t'"${fields[7]}"
  MACOS_HANDOFF_ROWS+=("$row")
}

macos_path_architecture() {
  local target="$1" description
  if [[ ! -e "$target" && ! -L "$target" ]]; then
    print -r -- unknown
    return 0
  fi
  description="$(file -L "$target" 2>/dev/null)"
  if [[ "$description" == *x86_64* && "$description" != *arm64* ]]; then
    print -r -- x86_64
  elif [[ "$description" == *arm64* && "$description" == *x86_64* ]]; then
    print -r -- universal
  elif [[ "$description" == *arm64* ]]; then
    print -r -- arm64
  else
    print -r -- unknown
  fi
}

macos_collect_handoff_rows() {
  local intel_brew formula version rest reason formula_path architecture service_names
  local formula_lines cask_lines path_entry command_name command_path
  local -a current_path
  typeset -A desired arm_installed services seen_command

  MACOS_HANDOFF_ROWS=()
  [[ "$DOTFILES_NATIVE_ARCH" == arm64 ]] || return 0
  macos_load_brewfiles || return 1

  intel_brew="$(macos_intel_brew)"
  if [[ -x "$intel_brew" ]]; then
    if [[ "$($intel_brew --prefix 2>/dev/null)" != /usr/local ]]; then
      print -u2 -- 'handoff: Intel Homebrew 未报告 /usr/local prefix'
      return 1
    fi
    for formula in ${(k)MACOS_BREW_LINE}; do
      [[ "${formula%%:*}" == brew ]] && desired[${formula#*:}]=1
    done
    for formula in ${(f)"$($MACOS_BREW_COMMAND list --formula -1 2>/dev/null)"}; do
      [[ -n "$formula" ]] && arm_installed[$formula]=1
    done
    service_names="$($intel_brew services list 2>/dev/null | awk 'NR > 1 { print $1 }')"
    for formula in ${(f)service_names}; do
      [[ -n "$formula" ]] && services[$formula]=1
    done

    formula_lines="$($intel_brew list --versions --formula 2>/dev/null)" || formula_lines=''
    if [[ -z "$formula_lines" ]]; then
      formula_lines="$($intel_brew list --formula -1 2>/dev/null)" || return 1
    fi
    for rest in ${(f)formula_lines}; do
      [[ -n "$rest" ]] || continue
      formula="${rest%% *}"
      version="${rest#$formula}"
      version="${version##[[:space:]]#}"
      [[ -n "$version" ]] || version=unknown
      formula_path="$($intel_brew --prefix "$formula" 2>/dev/null)"
      [[ "$formula_path" == /usr/local/* ]] || formula_path="/usr/local/opt/$formula"
      architecture=unknown
      command_name="$(macos_formula_command "$formula" 2>/dev/null)" || command_name=''
      if [[ -n "$command_name" ]]; then
        command_path="/usr/local/bin/$command_name"
        [[ -e "$command_path" ]] || command_path="/usr/local/sbin/$command_name"
        [[ -e "$command_path" ]] && architecture="$(macos_path_architecture "$command_path")"
      fi
      if [[ -n "${services[$formula]:-}" ]]; then
        reason='保留：检测到 service/data，必须人工处理并由 Stage 3 重验'
      elif [[ -n "${desired[$formula]:-}" && -n "${arm_installed[$formula]:-}" ]]; then
        reason='候选：同名 ARM formula 已安装；Stage 3 仍须重验命令与数据'
      else
        reason='保留：未证明为当前声明目标或项目依赖，等待人工分类'
      fi
      macos_handoff_add formula homebrew "$formula" "$version" "$formula_path" "$architecture" "$reason" || return 1
    done

    cask_lines="$($intel_brew list --versions --cask 2>/dev/null)" || cask_lines=''
    if [[ -z "$cask_lines" ]]; then
      cask_lines="$($intel_brew list --cask -1 2>/dev/null)" || cask_lines=''
    fi
    for rest in ${(f)cask_lines}; do
      [[ -n "$rest" ]] || continue
      formula="${rest%% *}"
      version="${rest#$formula}"
      version="${version##[[:space:]]#}"
      [[ -n "$version" ]] || version=unknown
      macos_handoff_add cask homebrew "$formula" "$version" "/usr/local/Caskroom/$formula" unknown \
        '保留：GUI 应用及数据未知，必须人工处理' || return 1
    done
  fi

  current_path=(${(s/:/)PATH})
  for path_entry in $current_path; do
    case "$path_entry" in
      /usr/local/bin|/usr/local/sbin)
        macos_handoff_add path environment PATH-entry unknown "$path_entry" x86_64-prefix \
          '待处理：残留 Intel PATH；不代表其中项目可删除' || return 1
        ;;
    esac
  done

  for command_name in node bun pnpm uv python3 gh rg; do
    command_path="$(command -v "$command_name" 2>/dev/null || true)"
    [[ -n "$command_path" && -z "${seen_command[$command_path]:-}" ]] || continue
    architecture="$(macos_path_architecture "$command_path")"
    if [[ "$architecture" == x86_64 && "$command_path" != /usr/local/bin/* \
      && "$command_path" != /usr/local/sbin/* ]]; then
      seen_command[$command_path]=1
      macos_handoff_add command unmanaged "$command_name" unknown "$command_path" x86_64 \
        '保留：全局 Intel runtime/command，Stage 3 须确认所有权和项目依赖' || return 1
    fi
  done
}

macos_known_handoff_file() {
  [[ -f "$DOTFILES_INTEL_HANDOFF_FILE" && ! -L "$DOTFILES_INTEL_HANDOFF_FILE" \
    && -O "$DOTFILES_INTEL_HANDOFF_FILE" ]] || return 1
  [[ "$(command head -n 1 "$DOTFILES_INTEL_HANDOFF_FILE" 2>/dev/null)" == "$MACOS_HANDOFF_MARKER" ]]
}

macos_validate_state_dir() {
  local resolved_state_dir="${DOTFILES_STATE_DIR:A}"

  if [[ -L "$DOTFILES_STATE_DIR" || ( -e "$DOTFILES_STATE_DIR" && ! -d "$DOTFILES_STATE_DIR" ) ]]; then
    print -u2 -- 'handoff: 状态目录不得是 symlink，且必须是目录'
    return 1
  fi
  if [[ -d "$DOTFILES_STATE_DIR" && ! -O "$DOTFILES_STATE_DIR" ]]; then
    print -u2 -- 'handoff: 状态目录必须属于当前用户'
    return 1
  fi
  case "$resolved_state_dir" in
    "$DOTFILES_REPO_ROOT"|"$DOTFILES_REPO_ROOT"/*)
      print -u2 -- 'handoff: 状态目录不得位于 public checkout 内'
      return 1
      ;;
  esac
  if [[ -n "$DOTFILES_SHARED_DIR_RESOLVED" ]]; then
    case "$resolved_state_dir" in
      "$DOTFILES_SHARED_DIR_RESOLVED"|"$DOTFILES_SHARED_DIR_RESOLVED"/*)
        print -u2 -- 'handoff: 状态目录不得位于 shared checkout 内'
        return 1
        ;;
    esac
  fi
}

macos_write_handoff() {
  local temporary row
  local -a sorted_rows

  if (( ${#MACOS_HANDOFF_ROWS} == 0 )); then
    if [[ -e "$DOTFILES_INTEL_HANDOFF_FILE" || -L "$DOTFILES_INTEL_HANDOFF_FILE" ]]; then
      macos_validate_state_dir || return 1
      macos_known_handoff_file || {
        print -u2 -- 'handoff: 同名状态文件不属于安装器，拒绝覆盖或删除'
        return 1
      }
      command rm -f -- "$DOTFILES_INTEL_HANDOFF_FILE" || return 1
    fi
    print -- '- 未发现可确认的 Intel 残留；未保留交接清单'
    return 0
  fi

  macos_validate_state_dir || return 1
  if [[ -e "$DOTFILES_INTEL_HANDOFF_FILE" || -L "$DOTFILES_INTEL_HANDOFF_FILE" ]]; then
    macos_known_handoff_file || {
      print -u2 -- 'handoff: 同名状态文件不属于安装器，拒绝覆盖'
      return 1
    }
  fi
  command mkdir -p -- "$DOTFILES_STATE_DIR" || return 1
  chmod 700 "$DOTFILES_STATE_DIR" || return 1
  temporary="$(mktemp "$DOTFILES_STATE_DIR/.intel_to_be_retired.tsv.XXXXXX")" || return 1
  chmod 600 "$temporary" || {
    command rm -f -- "$temporary"
    return 1
  }
  sorted_rows=(${(f)"$(printf '%s\n' "${MACOS_HANDOFF_ROWS[@]}" | LC_ALL=C sort -u)"})
  {
    print -r -- "$MACOS_HANDOFF_MARKER"
    print -r -- $'kind\tmanager\tname\tversion\tpath\tarchitecture\treason'
    for row in "${sorted_rows[@]}"; do
      print -r -- "$row"
    done
  } > "$temporary" || {
    command rm -f -- "$temporary"
    return 1
  }
  command mv -f -- "$temporary" "$DOTFILES_INTEL_HANDOFF_FILE" || {
    command rm -f -- "$temporary"
    return 1
  }
  chmod 600 "$DOTFILES_INTEL_HANDOFF_FILE" || return 1
  print -- "- 已生成 $DOTFILES_INTEL_HANDOFF_FILE（${#sorted_rows} 项，仅供 Stage 3 重验）"
}

macos_verify_retirement_handoff() {
  if [[ "$DOTFILES_NATIVE_ARCH" == x86_64 ]]; then
    print -- '- Intel Mac：不生成 Intel 退役交接，Stage 3 不适用'
    return 0
  fi
  macos_collect_handoff_rows || return 1
  macos_write_handoff || return 1
  if [[ -e "$DOTFILES_INTEL_HANDOFF_FILE" ]]; then
    if [[ -L "$DOTFILES_INTEL_HANDOFF_FILE" || ! -f "$DOTFILES_INTEL_HANDOFF_FILE" \
      || ! -O "$DOTFILES_INTEL_HANDOFF_FILE" \
      || "$(stat -f '%Lp' "$DOTFILES_INTEL_HANDOFF_FILE" 2>/dev/null)" != 600 \
      || "$(stat -f '%Lp' "$DOTFILES_STATE_DIR" 2>/dev/null)" != 700 ]]; then
      print -u2 -- 'handoff: 状态文件类型、owner 或权限验证失败'
      return 1
    fi
    case "$DOTFILES_INTEL_HANDOFF_FILE" in
      "$DOTFILES_REPO_ROOT"/*)
        if git -C "$DOTFILES_REPO_ROOT" ls-files --error-unmatch \
          "${DOTFILES_INTEL_HANDOFF_FILE#$DOTFILES_REPO_ROOT/}" >/dev/null 2>&1; then
          print -u2 -- 'handoff: Intel 交接文件不得被 public checkout 跟踪'
          return 1
        fi
        ;;
    esac
    if [[ -n "$DOTFILES_SHARED_DIR_RESOLVED" ]]; then
      case "$DOTFILES_INTEL_HANDOFF_FILE" in
        "$DOTFILES_SHARED_DIR_RESOLVED"/*)
          if git -C "$DOTFILES_SHARED_DIR_RESOLVED" ls-files --error-unmatch \
            "${DOTFILES_INTEL_HANDOFF_FILE#$DOTFILES_SHARED_DIR_RESOLVED/}" >/dev/null 2>&1; then
            print -u2 -- 'handoff: Intel 交接文件不得被 shared checkout 跟踪'
            return 1
          fi
          ;;
      esac
    fi
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

  if [[ "$DOTFILES_NATIVE_ARCH" != arm64 ]]; then
    print -- 'Intel Mac：Stage 3 不适用'
    return 0
  fi

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
