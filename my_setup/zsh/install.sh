#!/bin/zsh

# Internal Zsh capability module. The repository-root install.sh is the only
# public command and sources this file after defining the shared contract.

if [[ "${DOTFILES_INSTALLER_ACTIVE:-0}" != 1 || "${ZSH_EVAL_CONTEXT:-}" != *:file* ]]; then
  print -u2 -- 'my_setup/zsh/install.sh 是内部模块；请从仓库根目录运行 ./install.sh'
  return 1 2>/dev/null || exit 1
fi

typeset -gA ZSH_PLUGIN_SOURCE
typeset -gA ZSH_PLUGIN_REVISION
typeset -gA ZSH_PLUGIN_ENABLED
typeset -gA ZSH_PLUGIN_ORDER
typeset -gA ZSH_PLUGIN_OWNER
typeset -gA ZSH_PLUGIN_SEEN
typeset -g ZSH_PERSONAL_PROFILE=''
typeset -g ZSH_PERSONAL_RC=''
typeset -g ZSH_PERSONAL_NAMING=''
typeset -gr ZSH_FUNCTIONAL_GUARD_MARKER='# dotfiles-zsh-functional-guard-v1'
typeset -g ZSH_FUNCTIONAL_GUARD_DIR=''
typeset -g ZSH_LAST_PROFILE_BACKUP='none'
typeset -g ZSH_LAST_RC_BACKUP='none'
typeset -gA ZSH_GUARD_STATUS
typeset -gA ZSH_GUARD_ADDED_COUNT
typeset -gA ZSH_GUARD_REMOVED_COUNT
typeset -gA ZSH_GUARD_BEFORE_SHA
typeset -gA ZSH_GUARD_POST_SHA
typeset -gA ZSH_GUARD_ADDED_SHA
typeset -gA ZSH_GUARD_CANDIDATE_SHA
typeset -ga ZSH_GUARD_CANDIDATE_FILES
typeset -gi ZSH_GUARD_EXTRACT_ADDED=0
typeset -gi ZSH_GUARD_EXTRACT_REMOVED=0
typeset -g ZSH_SEMICOLON_DIGEST=''

zsh_trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  print -r -- "$value"
}

zsh_store_plugin() {
  local file="$1"
  local owner="$2"
  local name="$3"
  local source="$4"
  local revision="$5"
  local enabled="$6"
  local load_order="$7"
  local seen_key="$owner:$name"

  if [[ -z "$name" && -z "$source" && -z "$revision" && -z "$enabled" && -z "$load_order" ]]; then
    return 0
  fi
  if [[ "$name" != [A-Za-z0-9._-]## ]]; then
    print -u2 -- "zsh: ${file#$DOTFILES_REPO_ROOT/} 包含无效插件名"
    return 1
  fi
  if [[ -z "$source" || "$source" == *[[:space:]'|']* ]]; then
    print -u2 -- "zsh: 插件 $name 的 source 无效"
    return 1
  fi
  if [[ "$source" != http://* && "$source" != https://* && "$source" != git@*:* \
    && "$source" != oh-my-zsh/* ]]; then
    print -u2 -- "zsh: 插件 $name 的 source 必须是 Git URL 或 oh-my-zsh 内部路径"
    return 1
  fi
  if [[ "$revision" != [0-9a-fA-F]## || ${#revision} -ne 40 ]]; then
    print -u2 -- "zsh: 插件 $name 必须固定 40 位 commit revision"
    return 1
  fi
  if [[ "$enabled" != true && "$enabled" != false ]]; then
    print -u2 -- "zsh: 插件 $name 的 enabled 必须为 true 或 false"
    return 1
  fi
  if [[ "$load_order" != <-> ]]; then
    print -u2 -- "zsh: 插件 $name 的 load_order 必须是非负整数"
    return 1
  fi
  if [[ -n "${ZSH_PLUGIN_SEEN[$seen_key]:-}" ]]; then
    print -u2 -- "zsh: ${file#$DOTFILES_REPO_ROOT/} 重复声明插件 $name"
    return 1
  fi

  ZSH_PLUGIN_SEEN[$seen_key]=1
  ZSH_PLUGIN_SOURCE[$name]="$source"
  ZSH_PLUGIN_REVISION[$name]="${revision:l}"
  ZSH_PLUGIN_ENABLED[$name]="$enabled"
  ZSH_PLUGIN_ORDER[$name]="$load_order"
  ZSH_PLUGIN_OWNER[$name]="$owner"
}

zsh_parse_plugins_file() {
  local file="$1"
  local owner="$2"
  local line key value
  local in_plugin=0
  local name='' source='' revision='' enabled='' load_order=''

  [[ -f "$file" && ! -L "$file" ]] || {
    print -u2 -- "zsh: plugins.toml 缺失或不是普通文件：${file#$DOTFILES_REPO_ROOT/}"
    return 1
  }

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(zsh_trim "$line")"
    [[ -z "$line" || "$line" == \#* ]] && continue

    if [[ "$line" == '[[plugins]]' ]]; then
      if (( in_plugin )); then
        zsh_store_plugin "$file" "$owner" "$name" "$source" "$revision" "$enabled" "$load_order" || return 1
      fi
      in_plugin=1
      name=''
      source=''
      revision=''
      enabled=''
      load_order=''
      continue
    fi
    if (( ! in_plugin )) || [[ "$line" != *=* ]]; then
      print -u2 -- "zsh: ${file#$DOTFILES_REPO_ROOT/} 只允许 [[plugins]] 与固定字段"
      return 1
    fi

    key="$(zsh_trim "${line%%=*}")"
    value="$(zsh_trim "${line#*=}")"
    case "$key" in
      name|source|revision)
        if [[ "$value" != \"*\" || ${#value} -lt 2 ]]; then
          print -u2 -- "zsh: $key 必须是双引号字符串"
          return 1
        fi
        value="${value[2,-2]}"
        case "$key" in
          name) name="$value" ;;
          source) source="$value" ;;
          revision) revision="$value" ;;
        esac
        ;;
      enabled) enabled="$value" ;;
      load_order) load_order="$value" ;;
      *)
        print -u2 -- "zsh: ${file#$DOTFILES_REPO_ROOT/} 包含未知字段 $key"
        return 1
        ;;
    esac
  done < "$file"

  if (( ! in_plugin )); then
    print -u2 -- "zsh: ${file#$DOTFILES_REPO_ROOT/} 没有插件声明"
    return 1
  fi
  zsh_store_plugin "$file" "$owner" "$name" "$source" "$revision" "$enabled" "$load_order"
}

zsh_load_plugins() {
  ZSH_PLUGIN_SOURCE=()
  ZSH_PLUGIN_REVISION=()
  ZSH_PLUGIN_ENABLED=()
  ZSH_PLUGIN_ORDER=()
  ZSH_PLUGIN_OWNER=()
  ZSH_PLUGIN_SEEN=()

  if [[ -n "$DOTFILES_SHARED_DIR_RESOLVED" \
    && -e "$DOTFILES_SHARED_DIR_RESOLVED/zsh/plugins.toml" ]]; then
    zsh_parse_plugins_file "$DOTFILES_SHARED_DIR_RESOLVED/zsh/plugins.toml" shared || return 1
  fi
  zsh_parse_plugins_file "$DOTFILES_PERSONAL_DIR/zsh/plugins.toml" personal || return 1
}

zsh_plugin_records() {
  local name
  for name in ${(k)ZSH_PLUGIN_SOURCE}; do
    print -r -- "${(l:9::0:)ZSH_PLUGIN_ORDER[$name]}|$name|$ZSH_PLUGIN_SOURCE[$name]|$ZSH_PLUGIN_REVISION[$name]|$ZSH_PLUGIN_ENABLED[$name]|$ZSH_PLUGIN_OWNER[$name]"
  done | LC_ALL=C sort
}

zsh_resolve_personal_entries() {
  local zsh_dir="$DOTFILES_PERSONAL_DIR/zsh"
  local plain_profile="$zsh_dir/zprofile"
  local plain_rc="$zsh_dir/zshrc"
  local dotted_profile="$zsh_dir/.zprofile"
  local dotted_rc="$zsh_dir/.zshrc"
  local resolved_profile='' resolved_rc='' resolved_naming=''
  typeset -i plain_count=0 dotted_count=0

  [[ -e "$plain_profile" || -L "$plain_profile" ]] && (( plain_count += 1 ))
  [[ -e "$plain_rc" || -L "$plain_rc" ]] && (( plain_count += 1 ))
  [[ -e "$dotted_profile" || -L "$dotted_profile" ]] && (( dotted_count += 1 ))
  [[ -e "$dotted_rc" || -L "$dotted_rc" ]] && (( dotted_count += 1 ))

  if (( plain_count == 2 && dotted_count == 0 )); then
    resolved_profile="$plain_profile"
    resolved_rc="$plain_rc"
    resolved_naming='无前置点（zprofile + zshrc）'
  elif (( dotted_count == 2 && plain_count == 0 )); then
    resolved_profile="$dotted_profile"
    resolved_rc="$dotted_rc"
    resolved_naming='有前置点（.zprofile + .zshrc）'
  elif (( plain_count == 2 && dotted_count == 2 )); then
    print -u2 -- 'zsh: my_setup/zsh/ 同时存在两套完整 Zsh 来源；请只保留 zprofile + zshrc 或 .zprofile + .zshrc 中的一套'
    return 1
  else
    print -u2 -- 'zsh: my_setup/zsh/ 的 Zsh 来源命名混搭或文件残缺；必须完整提供 zprofile + zshrc 或 .zprofile + .zshrc 中的一套'
    return 1
  fi

  if [[ -n "$ZSH_PERSONAL_PROFILE" \
    && ( "$ZSH_PERSONAL_PROFILE" != "$resolved_profile" || "$ZSH_PERSONAL_RC" != "$resolved_rc" ) ]]; then
    print -u2 -- 'zsh: 仓库 Zsh 来源在安装摘要后发生变化；停止写入，请重新运行安装器'
    return 1
  fi

  ZSH_PERSONAL_PROFILE="$resolved_profile"
  ZSH_PERSONAL_RC="$resolved_rc"
  ZSH_PERSONAL_NAMING="$resolved_naming"
}

zsh_uses_external_oh_my_zsh() {
  local rc="$1"
  grep -Fq -- 'export ZSH="$HOME/.oh-my-zsh"' "$rc"
}

zsh_external_oh_my_zsh_plan() {
  local rc="$1"
  local target="$DOTFILES_TARGET_HOME/.oh-my-zsh"

  zsh_uses_external_oh_my_zsh "$rc" || return 0
  if [[ ! -d "$target" || ! -r "$target/oh-my-zsh.sh" \
    || ! -r "$target/plugins/git/git.plugin.zsh" ]]; then
    print -u2 -- 'zsh: ~/.oh-my-zsh 必须是现有可读安装，并包含 oh-my-zsh.sh 与 git plugin'
    return 1
  fi
  print -- "- external Oh My Zsh：$target；action：复用现有安装，不 clone、checkout 或固定 revision"
}

zsh_external_oh_my_zsh_verify() {
  local rc="$1"
  local target="$DOTFILES_TARGET_HOME/.oh-my-zsh"

  zsh_uses_external_oh_my_zsh "$rc" || return 0
  if [[ ! -d "$target" || ! -r "$target/oh-my-zsh.sh" \
    || ! -r "$target/plugins/git/git.plugin.zsh" ]]; then
    print -u2 -- 'verify: 外部 ~/.oh-my-zsh 缺失或不能提供框架与 git plugin'
    return 1
  fi
  print -- '  external Oh My Zsh → ~/.oh-my-zsh（不受管 revision）'
}

zsh_entry_plan() {
  local target="$1"
  local source="$2"

  if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
    print -- "- ${target:t}：symlink 已正确"
  elif [[ -e "$target" || -L "$target" ]]; then
    if [[ -d "$target" && ! -L "$target" ]]; then
      print -u2 -- "zsh: $target 是目录，拒绝替换"
      return 1
    fi
    print -- "- ${target:t}：备份现有入口后建立 symlink"
  else
    print -- "- ${target:t}：建立 symlink"
  fi
}

zsh_plan() {
  local profile='' rc=''
  local record name source revision enabled owner target
  typeset -i enabled_count=0
  typeset -i blocked=0

  if zsh_resolve_personal_entries; then
    profile="$ZSH_PERSONAL_PROFILE"
    rc="$ZSH_PERSONAL_RC"
    print -- "- 仓库 Zsh 来源：$ZSH_PERSONAL_NAMING"
    print -- "- symlink source：$profile"
    print -- "  target：$DOTFILES_TARGET_HOME/.zprofile；action：备份冲突入口后建立 symlink"
    print -- "- symlink source：$rc"
    print -- "  target：$DOTFILES_TARGET_HOME/.zshrc；action：备份冲突入口后建立 symlink"
    for target in "$profile" "$rc"; do
      if [[ ! -f "$target" || -L "$target" ]]; then
        print -u2 -- "zsh: ${target#$DOTFILES_REPO_ROOT/} 必须是普通文件且不得是 symlink"
        blocked=1
      elif ! /bin/zsh -n "$target" >/dev/null 2>&1; then
        print -u2 -- "zsh: ${target#$DOTFILES_REPO_ROOT/} 语法错误"
        blocked=1
      fi
    done
  else
    blocked=1
  fi

  if (( blocked == 0 )); then
    zsh_entry_plan "$DOTFILES_TARGET_HOME/.zprofile" "$profile" || blocked=1
    zsh_entry_plan "$DOTFILES_TARGET_HOME/.zshrc" "$rc" || blocked=1
    zsh_external_oh_my_zsh_plan "$rc" || blocked=1
  fi

  if zsh_load_plugins; then
    for record in ${(f)"$(zsh_plugin_records)"}; do
      IFS='|' read -r _ name source revision enabled owner <<< "$record"
      [[ "$enabled" == true ]] || continue
      (( enabled_count += 1 ))
      if [[ "$source" == oh-my-zsh/* ]]; then
        target="$DOTFILES_PLUGIN_DIR/$source"
      else
        target="$DOTFILES_PLUGIN_DIR/$name"
      fi
      if [[ -e "$target" ]]; then
        print -- "- plugin source：$source@$revision（$owner）"
        print -- "  target：$target；action：校验 origin、工作树并固定 revision"
      else
        print -- "- plugin source：$source@$revision（$owner）"
        print -- "  target：$target；action：clone 并固定 revision"
      fi
    done
    print -- "- 启用插件：$enabled_count 个；同名冲突由 personal 决定"
    print -- '- Zsh 功能保全：macOS/tooling 前后比较脱敏语义 token；未覆盖新增功能时在替换 HOME 入口前停止'
    print -- "  receipt：$DOTFILES_ZSH_GUARD_FILE；action：最终 verify 重验候选与备份签名"
  else
    blocked=1
  fi

  (( blocked == 0 ))
}

zsh_token_digest() {
  local value="$1" output
  output="$(print -rn -- "$value" | /usr/bin/shasum -a 256)" || return 1
  print -r -- "${output%% *}"
}

zsh_digest_file() {
  local file="$1" output
  output="$(/usr/bin/shasum -a 256 "$file" 2>/dev/null)" || return 1
  print -r -- "${output%% *}"
}

zsh_prepare_functional_guard_runtime() {
  if [[ -z "$ZSH_FUNCTIONAL_GUARD_DIR" ]]; then
    ZSH_FUNCTIONAL_GUARD_DIR="$DOTFILES_RUNTIME_DIR/zsh-functional-guard"
  fi
  if [[ -L "$ZSH_FUNCTIONAL_GUARD_DIR" \
    || ( -e "$ZSH_FUNCTIONAL_GUARD_DIR" && ! -d "$ZSH_FUNCTIONAL_GUARD_DIR" ) ]]; then
    print -u2 -- 'zsh: 功能保全临时目录类型错误或不得是 symlink'
    return 1
  fi
  command mkdir -p -- "$ZSH_FUNCTIONAL_GUARD_DIR" || return 1
  chmod 700 "$ZSH_FUNCTIONAL_GUARD_DIR" || return 1
}

zsh_write_semantic_tokens_from_content() {
  local content="$1"
  local output="$2"
  local token normalized digest previous=''
  local -a parsed canonical

  parsed=("${(@Z:C:)content}")
  for token in "${parsed[@]}"; do
    normalized="$token"
    if [[ "$normalized" == \"*\" || "$normalized" == \'*\' ]]; then
      normalized="${(Q)normalized}"
    fi
    [[ "$normalized" == . ]] && normalized=source
    normalized="${normalized//\$\{HOME\}/\$HOME}"
    if [[ "$normalized" == ';' ]]; then
      (( ${#canonical[@]} == 0 )) && continue
      [[ "$previous" == ';' ]] && continue
    fi
    canonical+=("$normalized")
    previous="$normalized"
  done
  if (( ${#canonical[@]} > 0 )) && [[ "${canonical[-1]}" == ';' ]]; then
    canonical[-1]=()
  fi

  : > "$output" || return 1
  chmod 600 "$output" || return 1
  for token in "${canonical[@]}"; do
    digest="$(zsh_token_digest "$token")" || return 1
    print -r -- "$digest" >> "$output" || return 1
  done
}

zsh_write_semantic_tokens() {
  local file="$1"
  local output="$2"
  local content=''

  if [[ ! -e "$file" && ! -L "$file" ]]; then
    zsh_write_semantic_tokens_from_content '' "$output"
    return
  fi
  if [[ -L "$file" && ! -e "$file" ]]; then
    zsh_write_semantic_tokens_from_content '' "$output"
    return
  fi
  if [[ ! -f "$file" ]]; then
    print -u2 -- "zsh: 功能签名只支持普通文件或指向普通文件的 symlink：${file:t}"
    return 1
  fi
  /bin/zsh -n "$file" >/dev/null 2>&1 || {
    print -u2 -- "zsh: 无法为语法错误的启动文件建立功能签名：${file:t}"
    return 1
  }
  content="$(<"$file")" || return 1
  zsh_write_semantic_tokens_from_content "$content" "$output"
}

zsh_write_integration_phase_tokens() {
  local logical="$1"
  local output="$2"
  local first_phase second_phase content=''

  case "$logical" in
    zprofile) first_phase=zprofile-pre; second_phase=zprofile-post ;;
    zshrc) first_phase=zshrc-pre; second_phase=zshrc-post ;;
    *) return 1 ;;
  esac
  if [[ ! -f "$DOTFILES_LOCAL_INTEGRATIONS_FILE" \
    || -L "$DOTFILES_LOCAL_INTEGRATIONS_FILE" ]]; then
    zsh_write_semantic_tokens_from_content '' "$output"
    return
  fi
  if [[ "$(sed -n '1p' "$DOTFILES_LOCAL_INTEGRATIONS_FILE" 2>/dev/null)" \
    != '# dotfiles: generated local integrations v1' ]]; then
    zsh_write_semantic_tokens_from_content '' "$output"
    return
  fi
  content="$(/usr/bin/awk -v first="$first_phase" -v second="$second_phase" '
    $0 ~ "^[[:space:]]*" first "[)][[:space:]]*$" \
      || $0 ~ "^[[:space:]]*" second "[)][[:space:]]*$" { active=1; next }
    active && $0 ~ "^[[:space:]]*;;[[:space:]]*$" { active=0; next }
    active { print }
  ' "$DOTFILES_LOCAL_INTEGRATIONS_FILE")" || return 1
  zsh_write_semantic_tokens_from_content "$content" "$output"
}

zsh_extract_added_tokens() {
  local before_file="$1"
  local after_file="$2"
  local output="$3"
  local line
  local -a before=() after=()
  typeset -i prefix=0 suffix=0 start end before_count after_count

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "$line" ]] && before+=("$line")
  done < "$before_file"
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "$line" ]] && after+=("$line")
  done < "$after_file"
  before_count=${#before[@]}
  after_count=${#after[@]}
  while (( prefix < before_count && prefix < after_count )); do
    [[ "${before[prefix + 1]}" == "${after[prefix + 1]}" ]] || break
    (( prefix += 1 ))
  done
  while (( suffix < before_count - prefix && suffix < after_count - prefix )); do
    [[ "${before[before_count - suffix]}" == "${after[after_count - suffix]}" ]] \
      || break
    (( suffix += 1 ))
  done

  start=$(( prefix + 1 ))
  end=$(( after_count - suffix ))
  [[ -n "$ZSH_SEMICOLON_DIGEST" ]] \
    || ZSH_SEMICOLON_DIGEST="$(zsh_token_digest ';')" || return 1
  while (( start <= end )) && [[ "${after[start]}" == "$ZSH_SEMICOLON_DIGEST" ]]; do
    (( start += 1 ))
  done
  while (( end >= start )) && [[ "${after[end]}" == "$ZSH_SEMICOLON_DIGEST" ]]; do
    (( end -= 1 ))
  done

  : > "$output" || return 1
  chmod 600 "$output" || return 1
  if (( start <= end )); then
    for (( ; start <= end; start++ )); do
      print -r -- "${after[start]}" >> "$output" || return 1
    done
  fi
  ZSH_GUARD_EXTRACT_ADDED="$(/usr/bin/awk 'END { print NR + 0 }' "$output")" || return 1
  ZSH_GUARD_EXTRACT_REMOVED=$(( before_count - prefix - suffix ))
}

zsh_tokens_contain_sequence() {
  local candidate_file="$1"
  local sequence_file="$2"
  local line
  local -a candidate sequence
  typeset -i start offset candidate_count sequence_count matched

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "$line" ]] && candidate+=("$line")
  done < "$candidate_file"
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "$line" ]] && sequence+=("$line")
  done < "$sequence_file"
  candidate_count=${#candidate[@]}
  sequence_count=${#sequence[@]}
  (( sequence_count > 0 && candidate_count >= sequence_count )) || return 1

  for (( start = 1; start <= candidate_count - sequence_count + 1; start++ )); do
    matched=1
    for (( offset = 1; offset <= sequence_count; offset++ )); do
      if [[ "${candidate[start + offset - 1]}" != "${sequence[offset]}" ]]; then
        matched=0
        break
      fi
    done
    (( matched )) && return 0
  done
  return 1
}

zsh_prepare_candidate_tokens() {
  local logical="$1"
  local combined="$ZSH_FUNCTIONAL_GUARD_DIR/candidate-$logical.tokens"
  local file component
  local -a sources

  zsh_resolve_personal_entries || return 1
  case "$logical" in
    zprofile)
      sources+=("$ZSH_PERSONAL_PROFILE")
      ;;
    zshrc)
      sources+=("$ZSH_PERSONAL_RC")
      if [[ -n "$DOTFILES_SHARED_DIR_RESOLVED" \
        && -f "$DOTFILES_SHARED_DIR_RESOLVED/zsh/shared.zsh" \
        && ! -L "$DOTFILES_SHARED_DIR_RESOLVED/zsh/shared.zsh" ]]; then
        sources+=("$DOTFILES_SHARED_DIR_RESOLVED/zsh/shared.zsh")
      fi
      ;;
    *) return 1 ;;
  esac

  ZSH_GUARD_CANDIDATE_FILES=()
  for file in "${sources[@]}"; do
    component="$ZSH_FUNCTIONAL_GUARD_DIR/candidate-$logical-${#ZSH_GUARD_CANDIDATE_FILES}.tokens"
    zsh_write_semantic_tokens "$file" "$component" || return 1
    ZSH_GUARD_CANDIDATE_FILES+=("$component")
  done
  component="$ZSH_FUNCTIONAL_GUARD_DIR/candidate-$logical-integrations.tokens"
  zsh_write_integration_phase_tokens "$logical" "$component" || return 1
  ZSH_GUARD_CANDIDATE_FILES+=("$component")

  : > "$combined" || return 1
  chmod 600 "$combined" || return 1
  for component in "${ZSH_GUARD_CANDIDATE_FILES[@]}"; do
    print -r -- "component:${component:t}" >> "$combined" || return 1
    command cat -- "$component" >> "$combined" || return 1
  done
}

zsh_capture_pre_software_state() {
  local logical target

  zsh_resolve_personal_entries || return 1
  zsh_prepare_functional_guard_runtime || return 1
  ZSH_GUARD_STATUS=()
  ZSH_GUARD_ADDED_COUNT=()
  ZSH_GUARD_REMOVED_COUNT=()
  ZSH_GUARD_BEFORE_SHA=()
  ZSH_GUARD_POST_SHA=()
  ZSH_GUARD_ADDED_SHA=()
  ZSH_GUARD_CANDIDATE_SHA=()
  for logical target in \
    zprofile "$DOTFILES_TARGET_HOME/.zprofile" \
    zshrc "$DOTFILES_TARGET_HOME/.zshrc"; do
    zsh_write_semantic_tokens "$target" "$ZSH_FUNCTIONAL_GUARD_DIR/pre-$logical.tokens" \
      || return 1
  done
  print -- '✓ 已在软件安装前采集 HOME Zsh 脱敏功能签名'
}

zsh_guard_prepare_state_target() {
  if [[ -L "$DOTFILES_STATE_DIR" \
    || ( -e "$DOTFILES_STATE_DIR" && ! -d "$DOTFILES_STATE_DIR" ) ]]; then
    print -u2 -- 'zsh: 状态目录类型错误或不得是 symlink'
    return 1
  fi
  command mkdir -p -- "$DOTFILES_STATE_DIR" || return 1
  [[ -O "$DOTFILES_STATE_DIR" ]] || {
    print -u2 -- 'zsh: 状态目录必须属于当前用户'
    return 1
  }
  chmod 700 "$DOTFILES_STATE_DIR" || return 1
  if [[ -e "$DOTFILES_ZSH_GUARD_FILE" || -L "$DOTFILES_ZSH_GUARD_FILE" ]]; then
    if [[ -L "$DOTFILES_ZSH_GUARD_FILE" || ! -f "$DOTFILES_ZSH_GUARD_FILE" \
      || ! -O "$DOTFILES_ZSH_GUARD_FILE" \
      || "$(sed -n '1p' "$DOTFILES_ZSH_GUARD_FILE" 2>/dev/null)" \
        != "$ZSH_FUNCTIONAL_GUARD_MARKER" ]]; then
      print -u2 -- 'zsh: 未知或不安全的 Zsh 功能保全回执，拒绝覆盖'
      return 1
    fi
  fi
}

zsh_verify_post_software_functional_coverage() {
  local logical target before_file post_file added_file candidate_file component
  typeset -i covered

  [[ -n "$ZSH_FUNCTIONAL_GUARD_DIR" \
    && -d "$ZSH_FUNCTIONAL_GUARD_DIR" ]] || {
    print -u2 -- 'zsh: 缺少软件安装前功能签名'
    return 1
  }
  for logical target in \
    zprofile "$DOTFILES_TARGET_HOME/.zprofile" \
    zshrc "$DOTFILES_TARGET_HOME/.zshrc"; do
    before_file="$ZSH_FUNCTIONAL_GUARD_DIR/pre-$logical.tokens"
    post_file="$ZSH_FUNCTIONAL_GUARD_DIR/post-$logical.tokens"
    added_file="$ZSH_FUNCTIONAL_GUARD_DIR/added-$logical.tokens"
    candidate_file="$ZSH_FUNCTIONAL_GUARD_DIR/candidate-$logical.tokens"
    zsh_write_semantic_tokens "$target" "$post_file" || return 1
    zsh_extract_added_tokens "$before_file" "$post_file" "$added_file" || return 1
    ZSH_GUARD_ADDED_COUNT[$logical]="$ZSH_GUARD_EXTRACT_ADDED"
    ZSH_GUARD_REMOVED_COUNT[$logical]="$ZSH_GUARD_EXTRACT_REMOVED"
    zsh_prepare_candidate_tokens "$logical" || return 1
    ZSH_GUARD_BEFORE_SHA[$logical]="$(zsh_digest_file "$before_file")" || return 1
    ZSH_GUARD_POST_SHA[$logical]="$(zsh_digest_file "$post_file")" || return 1
    ZSH_GUARD_ADDED_SHA[$logical]="$(zsh_digest_file "$added_file")" || return 1
    ZSH_GUARD_CANDIDATE_SHA[$logical]="$(zsh_digest_file "$candidate_file")" || return 1

    if (( ZSH_GUARD_EXTRACT_ADDED == 0 )); then
      if [[ "${ZSH_GUARD_BEFORE_SHA[$logical]}" == "${ZSH_GUARD_POST_SHA[$logical]}" ]]; then
        ZSH_GUARD_STATUS[$logical]=unchanged
      else
        ZSH_GUARD_STATUS[$logical]=no-new-function
      fi
      continue
    fi
    covered=0
    for component in "${ZSH_GUARD_CANDIDATE_FILES[@]}"; do
      if zsh_tokens_contain_sequence "$component" "$added_file"; then
        covered=1
        break
      fi
    done
    if (( ! covered )); then
      print -u2 -- "zsh: $logical 在 macOS/tooling 后新增 ${ZSH_GUARD_EXTRACT_ADDED} 个功能 token，无法证明已由 managed/shared/local integrations 覆盖"
      print -u2 -- 'zsh: 为避免 symlink 后失去功能，保留当前 HOME Zsh 入口并停止；请先通过 Stage 1/1.1 保全该功能'
      return 1
    fi
    ZSH_GUARD_STATUS[$logical]=covered
  done
  zsh_guard_prepare_state_target || return 1
  print -- '✓ macOS/tooling 引入的 Zsh 新功能均已覆盖；允许备份并建立 symlink'
}

zsh_write_functional_guard_receipt() {
  local temp logical backup backup_path backup_tokens backup_sha line
  local -a lines

  zsh_guard_prepare_state_target || return 1
  for logical in zprofile zshrc; do
    if [[ "$logical" == zprofile ]]; then
      backup="$ZSH_LAST_PROFILE_BACKUP"
    else
      backup="$ZSH_LAST_RC_BACKUP"
    fi
    if [[ "$backup" != none ]]; then
      backup_path="$DOTFILES_TARGET_HOME/$backup"
      backup_tokens="$ZSH_FUNCTIONAL_GUARD_DIR/backup-$logical.tokens"
      zsh_write_semantic_tokens "$backup_path" "$backup_tokens" || return 1
      backup_sha="$(zsh_digest_file "$backup_tokens")" || return 1
      if [[ "$backup_sha" != "${ZSH_GUARD_POST_SHA[$logical]}" ]]; then
        print -u2 -- "zsh: $logical 备份与软件安装后的功能签名不一致"
        return 1
      fi
    fi
    line="$logical"$'\t'"${ZSH_GUARD_STATUS[$logical]}"$'\t'"${ZSH_GUARD_ADDED_COUNT[$logical]}"$'\t'"${ZSH_GUARD_REMOVED_COUNT[$logical]}"$'\t'"${ZSH_GUARD_BEFORE_SHA[$logical]}"$'\t'"${ZSH_GUARD_POST_SHA[$logical]}"$'\t'"${ZSH_GUARD_ADDED_SHA[$logical]}"$'\t'"${ZSH_GUARD_CANDIDATE_SHA[$logical]}"$'\t'"$backup"
    lines+=("$line")
  done

  temp="$(mktemp "$DOTFILES_STATE_DIR/.zsh-functional-guard.XXXXXX")" || return 1
  chmod 600 "$temp" || {
    command rm -f -- "$temp"
    return 1
  }
  {
    print -r -- "$ZSH_FUNCTIONAL_GUARD_MARKER"
    print -r -- $'logical_file\tstatus\tadded_tokens\tremoved_tokens\tbefore_sha256\tpost_sha256\tadded_sha256\tcandidate_sha256\tbackup'
    print -rl -- "${lines[@]}"
  } > "$temp" || {
    command rm -f -- "$temp"
    return 1
  }
  command mv -f -- "$temp" "$DOTFILES_ZSH_GUARD_FILE" || {
    command rm -f -- "$temp"
    return 1
  }
  chmod 600 "$DOTFILES_ZSH_GUARD_FILE" || return 1
  print -- "✓ Zsh 功能保全回执：$DOTFILES_ZSH_GUARD_FILE"
}

zsh_verify_functional_guard_receipt() {
  local marker header logical receipt_status added removed before_sha post_sha added_sha candidate_sha backup digest
  local backup_path backup_tokens backup_digest candidate_file candidate_digest
  local -A seen

  zsh_prepare_functional_guard_runtime || return 1
  if [[ ! -d "$DOTFILES_STATE_DIR" || -L "$DOTFILES_STATE_DIR" \
    || ! -O "$DOTFILES_STATE_DIR" \
    || "$(stat -f '%Lp' "$DOTFILES_STATE_DIR" 2>/dev/null)" != 700 \
    || ! -f "$DOTFILES_ZSH_GUARD_FILE" || -L "$DOTFILES_ZSH_GUARD_FILE" \
    || ! -O "$DOTFILES_ZSH_GUARD_FILE" \
    || "$(stat -f '%Lp' "$DOTFILES_ZSH_GUARD_FILE" 2>/dev/null)" != 600 ]]; then
    print -u2 -- 'verify: Zsh 功能保全状态目录/回执缺失，或类型、owner、0700/0600 权限错误'
    return 1
  fi
  {
    IFS= read -r marker
    IFS= read -r header
  } < "$DOTFILES_ZSH_GUARD_FILE"
  [[ "$marker" == "$ZSH_FUNCTIONAL_GUARD_MARKER" \
    && "$header" == $'logical_file\tstatus\tadded_tokens\tremoved_tokens\tbefore_sha256\tpost_sha256\tadded_sha256\tcandidate_sha256\tbackup' ]] || {
      print -u2 -- 'verify: Zsh 功能保全回执 marker 或 schema 错误'
      return 1
    }

  while IFS=$'\t' read -r logical receipt_status added removed before_sha post_sha added_sha candidate_sha backup; do
    [[ "$logical" == zprofile || "$logical" == zshrc ]] || return 1
    [[ -z "${seen[$logical]:-}" ]] || return 1
    seen[$logical]=1
    [[ "$receipt_status" == unchanged || "$receipt_status" == no-new-function \
      || "$receipt_status" == covered ]] || return 1
    [[ "$added" == <-> && "$removed" == <-> ]] || return 1
    for digest in "$before_sha" "$post_sha" "$added_sha" "$candidate_sha"; do
      [[ "$digest" == [0-9a-f]## && ${#digest} == 64 ]] || return 1
    done
    zsh_prepare_candidate_tokens "$logical" || return 1
    candidate_file="$ZSH_FUNCTIONAL_GUARD_DIR/candidate-$logical.tokens"
    candidate_digest="$(zsh_digest_file "$candidate_file")" || return 1
    if [[ "$candidate_digest" != "$candidate_sha" ]]; then
      print -u2 -- "verify: $logical managed/shared/local integrations 候选已在功能保全后变化"
      return 1
    fi
    if [[ "$backup" != none ]]; then
      [[ "$backup" == ".${logical}.dotfiles-backup."* \
        && "$backup" != *[[:space:]/]* ]] || return 1
      backup_path="$DOTFILES_TARGET_HOME/$backup"
      backup_tokens="$ZSH_FUNCTIONAL_GUARD_DIR/verify-backup-$logical.tokens"
      zsh_write_semantic_tokens "$backup_path" "$backup_tokens" || return 1
      backup_digest="$(zsh_digest_file "$backup_tokens")" || return 1
      if [[ "$backup_digest" != "$post_sha" ]]; then
        print -u2 -- "verify: $logical 备份不再匹配软件安装后的功能签名"
        return 1
      fi
    fi
  done < <(sed -n '3,$p' "$DOTFILES_ZSH_GUARD_FILE")
  [[ -n "${seen[zprofile]:-}" && -n "${seen[zshrc]:-}" \
    && ${#seen[@]} == 2 ]] || return 1
  print -- '✓ Zsh 功能保全回执、候选签名与备份签名'
}

zsh_backup_and_link() {
  local target="$1"
  local source="$2"
  local logical="$3"
  local stamp backup
  typeset -i suffix=0

  if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
    if [[ "$logical" == zprofile ]]; then
      ZSH_LAST_PROFILE_BACKUP=none
    else
      ZSH_LAST_RC_BACKUP=none
    fi
    return 0
  fi
  if [[ -e "$target" || -L "$target" ]]; then
    if [[ -d "$target" && ! -L "$target" ]]; then
      print -u2 -- "zsh: $target 是目录，拒绝替换"
      return 1
    fi
    stamp="$(date '+%Y%m%d%H%M%S')"
    backup="$target.dotfiles-backup.$stamp"
    while [[ -e "$backup" || -L "$backup" ]]; do
      (( suffix += 1 ))
      backup="$target.dotfiles-backup.$stamp.$suffix"
    done
    if [[ -L "$target" ]]; then
      command cp -P -- "$target" "$backup" || return 1
    else
      command cp -p -- "$target" "$backup" || return 1
    fi
    [[ -e "$backup" || -L "$backup" ]] || {
      print -u2 -- "zsh: 无法验证入口副本 $backup"
      return 1
    }
    command rm -f -- "$target" || return 1
    print -- "zsh: 已创建副本 $backup"
    if [[ "$logical" == zprofile ]]; then
      ZSH_LAST_PROFILE_BACKUP="${backup:t}"
    else
      ZSH_LAST_RC_BACKUP="${backup:t}"
    fi
  elif [[ "$logical" == zprofile ]]; then
    ZSH_LAST_PROFILE_BACKUP=none
  else
    ZSH_LAST_RC_BACKUP=none
  fi
  command ln -s -- "$source" "$target"
}

zsh_install_git_plugin() {
  local name="$1"
  local source="$2"
  local revision="$3"
  local target="$DOTFILES_PLUGIN_DIR/$name"
  local current origin dirty
  typeset -i created=0

  command mkdir -p -- "$DOTFILES_PLUGIN_DIR" || return 1
  chmod 700 "$DOTFILES_PLUGIN_DIR" || return 1

  if [[ ! -e "$target" ]]; then
    git clone --filter=blob:none --no-checkout -- "$source" "$target" || return 1
    created=1
  elif [[ ! -d "$target/.git" ]]; then
    print -u2 -- "zsh: 插件目标已存在但不是 Git 仓库：$target"
    return 1
  fi

  origin="$(git -C "$target" remote get-url origin 2>/dev/null)" || return 1
  if [[ "$origin" != "$source" ]]; then
    print -u2 -- "zsh: 插件 $name 的现有 origin 与声明不一致"
    return 1
  fi
  if (( ! created )); then
    dirty="$(git -C "$target" status --porcelain)"
    if [[ -n "$dirty" ]]; then
      print -u2 -- "zsh: 插件 $name 存在本地修改，拒绝 checkout"
      return 1
    fi
  fi
  if ! git -C "$target" cat-file -e "$revision^{commit}" 2>/dev/null; then
    git -C "$target" fetch --depth=1 origin "$revision" || return 1
  fi
  git -C "$target" checkout --detach "$revision" >/dev/null || return 1
  current="$(git -C "$target" rev-parse HEAD 2>/dev/null)" || return 1
  dirty="$(git -C "$target" status --porcelain)"
  [[ "$current" == "$revision" && -z "$dirty" ]] || return 1
}

zsh_apply() {
  local record name source revision enabled owner

  zsh_resolve_personal_entries || return 1
  zsh_load_plugins || return 1
  for record in ${(f)"$(zsh_plugin_records)"}; do
    IFS='|' read -r _ name source revision enabled owner <<< "$record"
    [[ "$enabled" == true ]] || continue
    if [[ "$source" == oh-my-zsh/* ]]; then
      if [[ ! -d "$DOTFILES_PLUGIN_DIR/$source" ]]; then
        print -u2 -- "zsh: 内部插件 $name 的父插件尚未安装"
        return 1
      fi
    else
      zsh_install_git_plugin "$name" "$source" "$revision" || return 1
    fi
  done

  zsh_backup_and_link "$DOTFILES_TARGET_HOME/.zprofile" "$ZSH_PERSONAL_PROFILE" zprofile || return 1
  zsh_backup_and_link "$DOTFILES_TARGET_HOME/.zshrc" "$ZSH_PERSONAL_RC" zshrc
}

zsh_verify_load_order() {
  local rc="$1"
  local shared_line personal_line local_line

  shared_line="$(grep -n -F -x -m1 -- '# dotfiles: shared' "$rc" 2>/dev/null | cut -d: -f1)"
  personal_line="$(grep -n -F -x -m1 -- '# dotfiles: personal' "$rc" 2>/dev/null | cut -d: -f1)"
  local_line="$(grep -n -F -x -m1 -- '# dotfiles: local' "$rc" 2>/dev/null | cut -d: -f1)"
  if [[ -z "$shared_line" || -z "$personal_line" || -z "$local_line" \
    || "$shared_line" -ge "$personal_line" || "$personal_line" -ge "$local_line" ]]; then
    print -u2 -- 'verify: .zshrc 必须按 dotfiles: shared → personal → local 标记顺序加载'
    return 1
  fi
}

zsh_verify_integration_loader() {
  local file="$1"
  local phase="$2"
  local marker_line first_nonblank last_nonblank

  marker_line="$(grep -n -F -m1 -- "# dotfiles: local-integrations $phase" "$file" 2>/dev/null | cut -d: -f1)"
  [[ -n "$marker_line" ]] || return 0
  grep -Fq -- "DOTFILES_INTEGRATIONS_PHASE=$phase" "$file" \
    && grep -Fq -- 'source "$HOME/.config/dotfiles/local/integrations.zsh"' "$file" || {
      print -u2 -- "verify: ${file:t} 的 integrations $phase loader 不完整"
      return 1
    }

  case "$phase" in
    *-pre)
      first_nonblank="$(/usr/bin/awk 'NF { print NR; exit }' "$file")"
      [[ "$marker_line" == "$first_nonblank" ]] || {
        print -u2 -- "verify: ${file:t} 的 integrations $phase 必须是第一个非空块"
        return 1
      }
      ;;
    *-post)
      last_nonblank="$(/usr/bin/awk 'NF { line=NR } END { print line }' "$file")"
      (( last_nonblank - marker_line <= 6 )) || {
        print -u2 -- "verify: ${file:t} 的 integrations $phase 必须是最后一个非空块"
        return 1
      }
      ;;
  esac
}

zsh_verify_plugin_load_order() {
  local rc="$1"
  local record name source revision enabled owner marker_line
  typeset -i previous_line=0

  zsh_load_plugins || return 1
  for record in ${(f)"$(zsh_plugin_records)"}; do
    IFS='|' read -r _ name source revision enabled owner <<< "$record"
    [[ "$enabled" == true ]] || continue
    marker_line="$(grep -n -F -m1 -- "# dotfiles: plugin $name" "$rc" 2>/dev/null | cut -d: -f1)"
    if [[ -z "$marker_line" || "$marker_line" -le "$previous_line" ]]; then
      print -u2 -- "verify: .zshrc 缺少按 load_order 排列的插件标记：$name"
      return 1
    fi
    previous_line="$marker_line"
  done
}

zsh_verify_plugin() {
  local name="$1"
  local source="$2"
  local revision="$3"
  local target current origin dirty

  if [[ "$source" == oh-my-zsh/* ]]; then
    target="$DOTFILES_PLUGIN_DIR/$source"
    [[ -d "$target" ]] || {
      print -u2 -- "verify: 内部插件 $name 不存在"
      return 1
    }
    return 0
  fi

  target="$DOTFILES_PLUGIN_DIR/$name"
  [[ -d "$target/.git" ]] || {
    print -u2 -- "verify: 插件 $name 未安装为 Git 仓库"
    return 1
  }
  current="$(git -C "$target" rev-parse HEAD 2>/dev/null)" || return 1
  origin="$(git -C "$target" remote get-url origin 2>/dev/null)" || return 1
  dirty="$(git -C "$target" status --porcelain)"
  if [[ "$current" != "$revision" || "$origin" != "$source" || -n "$dirty" ]]; then
    print -u2 -- "verify: 插件 $name 的 revision、origin 或工作树不符合声明"
    return 1
  fi
}

zsh_verify() {
  local profile='' rc=''
  local record name source revision enabled owner target
  typeset -i failed=0

  if zsh_resolve_personal_entries; then
    profile="$ZSH_PERSONAL_PROFILE"
    rc="$ZSH_PERSONAL_RC"
    for target in "$profile" "$rc"; do
      if [[ ! -f "$target" || -L "$target" ]] || ! /bin/zsh -n "$target" >/dev/null 2>&1; then
        print -u2 -- "verify: ${target#$DOTFILES_REPO_ROOT/} 缺失、类型错误或语法错误"
        failed=1
      fi
    done
  else
    failed=1
  fi

  if [[ -n "$profile" && -n "$rc" ]]; then
    if grep -En 'arch[[:space:]]+-x86_64|Rosetta fallback|ZDOTDIR' "$profile" "$rc" >/dev/null 2>&1; then
      print -u2 -- 'verify: personal Zsh 含禁止的 Rosetta fallback 或 ZDOTDIR 标记'
      failed=1
    fi
    zsh_verify_load_order "$rc" || failed=1
    zsh_verify_integration_loader "$profile" zprofile-pre || failed=1
    zsh_verify_integration_loader "$profile" zprofile-post || failed=1
    zsh_verify_integration_loader "$rc" zshrc-pre || failed=1
    zsh_verify_integration_loader "$rc" zshrc-post || failed=1
    zsh_verify_plugin_load_order "$rc" || failed=1
    zsh_external_oh_my_zsh_verify "$rc" || failed=1

    if [[ ! -L "$DOTFILES_TARGET_HOME/.zprofile" \
      || "$(readlink "$DOTFILES_TARGET_HOME/.zprofile" 2>/dev/null)" != "$profile" ]]; then
      print -u2 -- "verify: ~/.zprofile 未指向已选 personal ${profile:t}"
      failed=1
    fi
    if [[ ! -L "$DOTFILES_TARGET_HOME/.zshrc" \
      || "$(readlink "$DOTFILES_TARGET_HOME/.zshrc" 2>/dev/null)" != "$rc" ]]; then
      print -u2 -- "verify: ~/.zshrc 未指向已选 personal ${rc:t}"
      failed=1
    fi
  fi

  if [[ -n "$DOTFILES_SHARED_DIR_RESOLVED" \
    && -e "$DOTFILES_SHARED_DIR_RESOLVED/zsh/shared.zsh" ]]; then
    /bin/zsh -n "$DOTFILES_SHARED_DIR_RESOLVED/zsh/shared.zsh" >/dev/null 2>&1 || {
      print -u2 -- 'verify: shared.zsh 语法错误'
      failed=1
    }
  fi

  if zsh_load_plugins; then
    for record in ${(f)"$(zsh_plugin_records)"}; do
      IFS='|' read -r _ name source revision enabled owner <<< "$record"
      [[ "$enabled" == true ]] || continue
      zsh_verify_plugin "$name" "$source" "$revision" || failed=1
    done
  else
    failed=1
  fi

  if (( failed == 0 )); then
    env -u ZDOTDIR HOME="$DOTFILES_TARGET_HOME" /bin/zsh -l -c ':' >/dev/null 2>&1 || {
      print -u2 -- 'verify: login shell 启动失败（输出已丢弃）'
      failed=1
    }
    env -u ZDOTDIR HOME="$DOTFILES_TARGET_HOME" /bin/zsh -i -c ':' >/dev/null 2>&1 || {
      print -u2 -- 'verify: interactive shell 启动失败（输出已丢弃）'
      failed=1
    }
  fi

  zsh_verify_functional_guard_receipt || failed=1

  if (( failed == 0 )); then
    print -- '✓ Zsh 语法、入口 symlink、加载顺序、启动场景与固定插件'
  fi
  (( failed == 0 ))
}
