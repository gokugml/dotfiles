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
  else
    blocked=1
  fi

  (( blocked == 0 ))
}

zsh_backup_and_link() {
  local target="$1"
  local source="$2"
  local stamp backup
  typeset -i suffix=0

  if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
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

  zsh_backup_and_link "$DOTFILES_TARGET_HOME/.zprofile" "$ZSH_PERSONAL_PROFILE" || return 1
  zsh_backup_and_link "$DOTFILES_TARGET_HOME/.zshrc" "$ZSH_PERSONAL_RC"
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

  if (( failed == 0 )); then
    print -- '✓ Zsh 语法、入口 symlink、加载顺序、启动场景与固定插件'
  fi
  (( failed == 0 ))
}
