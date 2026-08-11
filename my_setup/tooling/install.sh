#!/bin/zsh

# Internal mise/uv capability module. Use the repository-root install.sh.

if [[ "${DOTFILES_INSTALLER_ACTIVE:-0}" != 1 || "${ZSH_EVAL_CONTEXT:-}" != *:file* ]]; then
  print -u2 -- 'my_setup/tooling/install.sh 是内部模块；请从仓库根目录运行 ./install.sh'
  return 1 2>/dev/null || exit 1
fi

tooling_trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  print -r -- "$value"
}

tooling_mise_files() {
  local file

  if [[ -n "$DOTFILES_SHARED_DIR_RESOLVED" && -d "$DOTFILES_SHARED_DIR_RESOLVED/tooling/mise" ]]; then
    for file in "$DOTFILES_SHARED_DIR_RESOLVED"/tooling/mise/*.toml(N); do
      print -r -- "shared|$file"
    done
  fi
  for file in "$DOTFILES_PERSONAL_DIR"/tooling/mise/*.toml(N); do
    print -r -- "personal|$file"
  done
}

tooling_validate_mise_file() {
  local file="$1"
  local line key value
  local in_tools=0
  typeset -A seen
  typeset -i count=0

  [[ -f "$file" && ! -L "$file" ]] || {
    print -u2 -- "tooling: mise 配置不是普通文件：$file"
    return 1
  }
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(tooling_trim "$line")"
    [[ -z "$line" || "$line" == \#* ]] && continue
    if [[ "$line" == '[tools]' ]]; then
      in_tools=1
      continue
    fi
    if [[ "$line" == \[*\] ]]; then
      in_tools=0
      continue
    fi
    (( in_tools )) || continue
    if [[ "$line" != *=* ]]; then
      print -u2 -- "tooling: mise [tools] 中存在无法解析的声明：$file"
      return 1
    fi
    key="$(tooling_trim "${line%%=*}")"
    value="$(tooling_trim "${line#*=}")"
    if [[ "$key" == \"*\" ]]; then
      key="${key[2,-2]}"
    fi
    if [[ "$value" != \"*\" || ${#value} -lt 3 ]]; then
      print -u2 -- "tooling: mise 工具 $key 必须使用双引号固定版本"
      return 1
    fi
    value="${value[2,-2]}"
    if [[ -z "$key" || "$key" == *[[:space:]]* || -z "$value" || "$value" == latest \
      || "$value" == *'*'* ]]; then
      print -u2 -- "tooling: mise 工具声明必须使用明确版本：$file"
      return 1
    fi
    if [[ -n "${seen[$key]:-}" ]]; then
      print -u2 -- "tooling: mise 配置重复声明 $key：$file"
      return 1
    fi
    seen[$key]=1
    (( count += 1 ))
  done < "$file"

  if (( count == 0 )); then
    print -u2 -- "tooling: mise 配置没有 [tools] 声明：$file"
    return 1
  fi
}

tooling_load_mise_tools() {
  local record owner file line key value
  local in_tools=0
  typeset -gA TOOLING_MISE_VERSION
  typeset -gA TOOLING_MISE_OWNER
  TOOLING_MISE_VERSION=()
  TOOLING_MISE_OWNER=()

  for record in ${(f)"$(tooling_mise_files)"}; do
    IFS='|' read -r owner file <<< "$record"
    tooling_validate_mise_file "$file" || return 1
    in_tools=0
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="$(tooling_trim "$line")"
      [[ -z "$line" || "$line" == \#* ]] && continue
      if [[ "$line" == '[tools]' ]]; then
        in_tools=1
        continue
      fi
      if [[ "$line" == \[*\] ]]; then
        in_tools=0
        continue
      fi
      (( in_tools )) || continue
      key="$(tooling_trim "${line%%=*}")"
      value="$(tooling_trim "${line#*=}")"
      [[ "$key" == \"*\" ]] && key="${key[2,-2]}"
      value="${value[2,-2]}"
      TOOLING_MISE_VERSION[$key]="$value"
      TOOLING_MISE_OWNER[$key]="$owner"
    done < "$file"
  done
  (( ${#TOOLING_MISE_VERSION} > 0 ))
}

tooling_uv_config_for() {
  local owner="$1"
  if [[ "$owner" == shared ]]; then
    print -r -- "$DOTFILES_SHARED_DIR_RESOLVED/tooling/uv/uv.toml"
  else
    print -r -- "$DOTFILES_PERSONAL_DIR/tooling/uv/uv.toml"
  fi
}

tooling_python_version_files() {
  local file
  if [[ -n "$DOTFILES_SHARED_DIR_RESOLVED" ]]; then
    file="$DOTFILES_SHARED_DIR_RESOLVED/tooling/uv/.python-versions"
    [[ -f "$file" && ! -L "$file" ]] && print -r -- "shared|$file"
  fi
  file="$DOTFILES_PERSONAL_DIR/tooling/uv/.python-versions"
  [[ -f "$file" && ! -L "$file" ]] && print -r -- "personal|$file"
}

tooling_load_python_versions() {
  local record owner file line
  typeset -gA TOOLING_PYTHON_OWNER
  TOOLING_PYTHON_OWNER=()

  for record in ${(f)"$(tooling_python_version_files)"}; do
    IFS='|' read -r owner file <<< "$record"
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="$(tooling_trim "$line")"
      [[ -z "$line" || "$line" == \#* ]] && continue
      if [[ "$line" != <->.<->.<-> ]]; then
        print -u2 -- "tooling: Python 版本必须固定为 X.Y.Z：$file"
        return 1
      fi
      TOOLING_PYTHON_OWNER[$line]="$owner"
    done < "$file"
  done
  if (( ${#TOOLING_PYTHON_OWNER} == 0 )); then
    print -u2 -- 'tooling: 没有已确认的 uv Python 版本'
    return 1
  fi
}

tooling_validate_uv_config() {
  local file="$1"
  local line key value

  [[ -f "$file" && ! -L "$file" ]] || {
    print -u2 -- "tooling: uv.toml 缺失或不是普通文件：$file"
    return 1
  }
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(tooling_trim "$line")"
    [[ -z "$line" || "$line" == \#* ]] && continue
    if [[ "$line" != *=* ]]; then
      print -u2 -- "tooling: uv.toml 包含无法解析的行：$file"
      return 1
    fi
    key="$(tooling_trim "${line%%=*}")"
    value="$(tooling_trim "${line#*=}")"
    case "$key:$value" in
      'python-preference:"only-managed"'|'python-downloads:"manual"') ;;
      *)
        print -u2 -- "tooling: uv.toml 首版只允许 only-managed 与 manual 安全设置：$file"
        return 1
        ;;
    esac
  done < "$file"
}

tooling_managed_link_plan() {
  local target="$1"
  local source="$2"
  if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
    print -- "- ${target#$DOTFILES_TARGET_HOME/}：symlink 已正确"
  elif [[ -e "$target" || -L "$target" ]]; then
    print -u2 -- "tooling: 受管路径已存在且不是期望 symlink，拒绝覆盖：$target"
    return 1
  else
    print -- "- ${target#$DOTFILES_TARGET_HOME/}：建立受管 symlink"
  fi
}

tooling_plan() {
  local record owner file target uv_config
  typeset -i mise_count=0
  typeset -i blocked=0

  for record in ${(f)"$(tooling_mise_files)"}; do
    IFS='|' read -r owner file <<< "$record"
    tooling_validate_mise_file "$file" || {
      blocked=1
      continue
    }
    (( mise_count += 1 ))
    target="$DOTFILES_TARGET_HOME/.config/mise/conf.d/$([[ "$owner" == shared ]] && print 10 || print 20)-dotfiles-${file:t}"
    tooling_managed_link_plan "$target" "$file" || blocked=1
  done
  if (( mise_count == 0 )); then
    print -u2 -- 'tooling: 没有 mise 配置文件'
    blocked=1
  elif tooling_load_mise_tools; then
    print -- "- mise：$mise_count 个配置文件，合并为 ${#TOOLING_MISE_VERSION} 个固定工具；同名由 personal 决定"
  else
    blocked=1
  fi

  uv_config="$DOTFILES_PERSONAL_DIR/tooling/uv/uv.toml"
  tooling_validate_uv_config "$uv_config" || blocked=1
  tooling_managed_link_plan "$DOTFILES_TARGET_HOME/.config/uv/uv.toml" "$uv_config" || blocked=1
  if [[ -n "$DOTFILES_SHARED_DIR_RESOLVED" \
    && -e "$DOTFILES_SHARED_DIR_RESOLVED/tooling/uv/uv.toml" ]]; then
    tooling_validate_uv_config "$DOTFILES_SHARED_DIR_RESOLVED/tooling/uv/uv.toml" || blocked=1
    print -- '- uv shared 配置：仅用于 shared 声明安装；personal 用户级配置最终生效'
  fi
  if tooling_load_python_versions; then
    print -- "- uv Python：${(j:, :)${(ok)TOOLING_PYTHON_OWNER}}"
  else
    blocked=1
  fi

  (( blocked == 0 ))
}

tooling_create_managed_link() {
  local target="$1"
  local source="$2"

  if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
    return 0
  fi
  if [[ -e "$target" || -L "$target" ]]; then
    print -u2 -- "tooling: 拒绝覆盖现有受管路径 $target"
    return 1
  fi
  command mkdir -p -- "${target:h}" || return 1
  chmod 700 "${target:h}" || return 1
  command ln -s -- "$source" "$target"
}

tooling_apply() {
  local record owner file target uv_config version tool
  local -a versions mise_specs

  (( $+commands[mise] )) || {
    print -u2 -- 'tooling: mise 未安装；macos 模块应先完成 Brewfile'
    return 1
  }
  (( $+commands[uv] )) || {
    print -u2 -- 'tooling: uv 未安装；macos 模块应先完成 Brewfile'
    return 1
  }

  for record in ${(f)"$(tooling_mise_files)"}; do
    IFS='|' read -r owner file <<< "$record"
    target="$DOTFILES_TARGET_HOME/.config/mise/conf.d/$([[ "$owner" == shared ]] && print 10 || print 20)-dotfiles-${file:t}"
    tooling_create_managed_link "$target" "$file" || return 1
  done
  tooling_load_mise_tools || return 1
  for tool in ${(ok)TOOLING_MISE_VERSION}; do
    mise_specs+=("${tool}@${TOOLING_MISE_VERSION[$tool]}")
  done
  mise --no-hooks -y install "${mise_specs[@]}" || return 1

  uv_config="$DOTFILES_PERSONAL_DIR/tooling/uv/uv.toml"
  tooling_create_managed_link "$DOTFILES_TARGET_HOME/.config/uv/uv.toml" "$uv_config" || return 1
  tooling_load_python_versions || return 1
  versions=(${(ok)TOOLING_PYTHON_OWNER})
  uv --config-file "$uv_config" --no-progress python install "${versions[@]}"
}

tooling_verify_binary_arch() {
  local name="$1"
  local path="${commands[$name]:-}"
  [[ -n "$path" ]] || {
    print -u2 -- "verify: $name 不在 PATH"
    return 1
  }
  if [[ "$DOTFILES_TEST_MODE" != 1 ]]; then
    if [[ "$path" != /opt/homebrew/* ]]; then
      print -u2 -- "verify: $name 必须来自 /opt/homebrew"
      return 1
    fi
    if ! file -L "$path" | grep -Eq 'arm64|universal binary'; then
      print -u2 -- "verify: $name 不是 ARM 或 Universal 二进制"
      return 1
    fi
  fi
}

tooling_verify() {
  local record owner file target uv_config version output tool
  local -a mise_specs
  typeset -i failed=0

  tooling_verify_binary_arch mise || failed=1
  tooling_verify_binary_arch uv || failed=1

  for record in ${(f)"$(tooling_mise_files)"}; do
    IFS='|' read -r owner file <<< "$record"
    tooling_validate_mise_file "$file" || {
      failed=1
      continue
    }
    target="$DOTFILES_TARGET_HOME/.config/mise/conf.d/$([[ "$owner" == shared ]] && print 10 || print 20)-dotfiles-${file:t}"
    if [[ ! -L "$target" || "$(readlink "$target" 2>/dev/null)" != "$file" ]]; then
      print -u2 -- "verify: mise 受管 symlink 错误：$target"
      failed=1
    fi
  done
  if tooling_load_mise_tools && (( $+commands[mise] )); then
    for tool in ${(ok)TOOLING_MISE_VERSION}; do
      mise_specs+=("${tool}@${TOOLING_MISE_VERSION[$tool]}")
    done
    mise --no-hooks install --dry-run-code "${mise_specs[@]}" >/dev/null 2>&1 || {
      print -u2 -- 'verify: mise 合并配置仍有未安装的固定工具'
      failed=1
    }
  else
    failed=1
  fi

  uv_config="$DOTFILES_PERSONAL_DIR/tooling/uv/uv.toml"
  tooling_validate_uv_config "$uv_config" || failed=1
  target="$DOTFILES_TARGET_HOME/.config/uv/uv.toml"
  if [[ ! -L "$target" || "$(readlink "$target" 2>/dev/null)" != "$uv_config" ]]; then
    print -u2 -- 'verify: uv 用户级配置未指向 personal uv.toml'
    failed=1
  fi
  if tooling_load_python_versions && (( $+commands[uv] )); then
    output="$(uv --config-file "$uv_config" --no-progress python list --only-installed --managed-python 2>/dev/null)" || {
      print -u2 -- 'verify: 无法读取 uv managed Python 清单'
      failed=1
      output=''
    }
    for version in ${(k)TOOLING_PYTHON_OWNER}; do
      if ! print -r -- "$output" | grep -Fq -- "$version"; then
        print -u2 -- "verify: uv managed Python $version 未安装"
        failed=1
      fi
    done
  else
    failed=1
  fi

  if (( failed == 0 )); then
    print -- '✓ mise/uv 配置、固定版本、受管 symlink 与二进制架构'
  fi
  (( failed == 0 ))
}
