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

tooling_global_cli_file() {
  print -r -- "$DOTFILES_PERSONAL_DIR/tooling/global-cli-migration.toml"
}

tooling_global_cli_append() {
  local description="$1" package="$2" version="$3" binaries="$4"
  local source_manager="$5" target_manager="$6" target_spec="$7" reason="$8"

  [[ -n "$description" && -n "$package" && -n "$version" && -n "$binaries" \
    && -n "$source_manager" && -n "$target_manager" && -n "$target_spec" && -n "$reason" ]] || {
    print -u2 -- 'tooling: global CLI 声明存在缺失字段'
    return 1
  }
  [[ "$description$package$version$binaries$source_manager$target_manager$target_spec$reason" != *'|'* ]] || {
    print -u2 -- 'tooling: global CLI 声明不得包含管道符'
    return 1
  }
  [[ "$package" != *[[:space:]]* && "$package" != /* && "$package" != *..* ]] || {
    print -u2 -- "tooling: global CLI package 非法：$package"
    return 1
  }
  [[ "$version" == <->.<->.<->* ]] || {
    print -u2 -- "tooling: global CLI 源版本必须是精确版本：$package@$version"
    return 1
  }
  [[ "$source_manager" == npm || "$source_manager" == pnpm \
    || "$source_manager" == bun || "$source_manager" == path ]] || {
    print -u2 -- "tooling: global CLI source_manager 不受支持：$source_manager"
    return 1
  }
  [[ "$target_manager" == npm ]] || {
    print -u2 -- "tooling: 当前安装器只支持 mise Node 下的 npm global CLI：$package"
    return 1
  }
  [[ "$target_spec" == "${package}@latest" ]] || {
    print -u2 -- "tooling: global CLI target_spec 必须为 ${package}@latest"
    return 1
  }
  [[ -z "${TOOLING_GLOBAL_CLI_PACKAGE_SEEN[$package]:-}" ]] || {
    print -u2 -- "tooling: global CLI 重复声明 package：$package"
    return 1
  }
  TOOLING_GLOBAL_CLI_PACKAGE_SEEN[$package]=1
  TOOLING_GLOBAL_CLI_RECORDS+=("$description|$package|$version|$binaries|$source_manager|$target_manager|$target_spec|$reason")
}

tooling_global_cli_parse_binaries() {
  local value="$1" inner item binary
  local -a binaries

  [[ "$value" == \[*\] ]] || return 1
  inner="${value[2,-2]}"
  for item in ${(s:,:)inner}; do
    item="$(tooling_trim "$item")"
    [[ "$item" == \"*\" && ${#item} -ge 3 ]] || return 1
    binary="${item[2,-2]}"
    [[ -n "$binary" && "$binary" != *[!A-Za-z0-9._-]* ]] || return 1
    binaries+=("$binary")
  done
  (( ${#binaries} > 0 )) || return 1
  print -r -- "${(j:,:)${(ou)binaries}}"
}

tooling_load_global_cli_declaration() {
  local file line key value schema_version='' install_policy=''
  local description='' package='' version='' binaries=''
  local source_manager='' target_manager='' target_spec='' reason=''
  local in_tool=0 parsed

  typeset -ga TOOLING_GLOBAL_CLI_RECORDS
  typeset -gA TOOLING_GLOBAL_CLI_PACKAGE_SEEN
  TOOLING_GLOBAL_CLI_RECORDS=()
  TOOLING_GLOBAL_CLI_PACKAGE_SEEN=()
  file="$(tooling_global_cli_file)"
  [[ -e "$file" ]] || return 0
  [[ -f "$file" && ! -L "$file" ]] || {
    print -u2 -- 'tooling: global-cli-migration.toml 必须是普通文件'
    return 1
  }

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(tooling_trim "$line")"
    [[ -z "$line" || "$line" == \#* ]] && continue
    if [[ "$line" == '[[tools]]' ]]; then
      if (( in_tool )); then
        tooling_global_cli_append "$description" "$package" "$version" "$binaries" \
          "$source_manager" "$target_manager" "$target_spec" "$reason" || return 1
      fi
      in_tool=1
      description='' package='' version='' binaries=''
      source_manager='' target_manager='' target_spec='' reason=''
      continue
    fi
    [[ "$line" == *=* ]] || {
      print -u2 -- 'tooling: global CLI TOML 存在无法解析的行'
      return 1
    }
    key="$(tooling_trim "${line%%=*}")"
    value="$(tooling_trim "${line#*=}")"
    if (( ! in_tool )); then
      case "$key:$value" in
        'schema_version:1') schema_version=1 ;;
        'install_policy:"prompt"') install_policy=prompt ;;
        *)
          print -u2 -- "tooling: global CLI 顶层 schema 非法：$key"
          return 1
          ;;
      esac
      continue
    fi
    if [[ "$key" == binaries ]]; then
      parsed="$(tooling_global_cli_parse_binaries "$value")" || {
        print -u2 -- 'tooling: global CLI binaries 必须是非空唯一字符串数组'
        return 1
      }
      binaries="$parsed"
      continue
    fi
    [[ "$value" == \"*\" && ${#value} -ge 2 ]] || {
      print -u2 -- "tooling: global CLI 字段必须是字符串：$key"
      return 1
    }
    value="${value[2,-2]}"
    case "$key" in
      description) description="$value" ;;
      package) package="$value" ;;
      version) version="$value" ;;
      source_manager) source_manager="$value" ;;
      target_manager) target_manager="$value" ;;
      target_spec) target_spec="$value" ;;
      reason) reason="$value" ;;
      *)
        print -u2 -- "tooling: global CLI 声明包含未知字段：$key"
        return 1
        ;;
    esac
  done < "$file"

  if (( in_tool )); then
    tooling_global_cli_append "$description" "$package" "$version" "$binaries" \
      "$source_manager" "$target_manager" "$target_spec" "$reason" || return 1
  fi
  [[ "$schema_version" == 1 && "$install_policy" == prompt ]] || {
    print -u2 -- 'tooling: global CLI schema_version/install_policy 非法'
    return 1
  }
  (( ${#TOOLING_GLOBAL_CLI_RECORDS} > 0 )) || {
    print -u2 -- 'tooling: global CLI 声明不得为空'
    return 1
  }
}

tooling_select_global_cli() {
  local selection="${DOTFILES_GLOBAL_CLI_SELECTION:-skip}"
  local requested package record description version binaries source_manager target_manager target_spec reason
  local -a requested_packages
  local -A requested_seen matched
  typeset -ga TOOLING_SELECTED_GLOBAL_CLI_RECORDS
  typeset -g TOOLING_GLOBAL_CLI_SELECTION_LABEL
  TOOLING_SELECTED_GLOBAL_CLI_RECORDS=()
  TOOLING_GLOBAL_CLI_SELECTION_LABEL='skip'

  case "$selection" in
    skip) ;;
    all)
      TOOLING_SELECTED_GLOBAL_CLI_RECORDS=("${TOOLING_GLOBAL_CLI_RECORDS[@]}")
      TOOLING_GLOBAL_CLI_SELECTION_LABEL="all（${#TOOLING_GLOBAL_CLI_RECORDS} 项）"
      ;;
    *)
      requested_packages=(${(s:,:)selection})
      for requested in "${requested_packages[@]}"; do
        requested="$(tooling_trim "$requested")"
        [[ -n "$requested" && -z "${requested_seen[$requested]:-}" ]] || {
          print -u2 -- 'tooling: global CLI 逐项选择不得为空或重复'
          return 1
        }
        requested_seen[$requested]=1
      done
      for record in "${TOOLING_GLOBAL_CLI_RECORDS[@]}"; do
        IFS='|' read -r description package version binaries source_manager target_manager target_spec reason <<< "$record"
        if [[ -n "${requested_seen[$package]:-}" ]]; then
          TOOLING_SELECTED_GLOBAL_CLI_RECORDS+=("$record")
          matched[$package]=1
        fi
      done
      for requested in "${requested_packages[@]}"; do
        requested="$(tooling_trim "$requested")"
        [[ -n "${matched[$requested]:-}" ]] || {
          print -u2 -- "tooling: global CLI 逐项选择包含未声明 package：$requested"
          return 1
        }
      done
      TOOLING_GLOBAL_CLI_SELECTION_LABEL="${#TOOLING_SELECTED_GLOBAL_CLI_RECORDS} / ${#TOOLING_GLOBAL_CLI_RECORDS} 项"
      ;;
  esac
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
    print -- "- symlink source：$source"
    print -- "  target：$target；action：保持正确 symlink"
  elif [[ -e "$target" || -L "$target" ]]; then
    print -u2 -- "tooling: 受管路径已存在且不是期望 symlink，拒绝覆盖：$target"
    return 1
  else
    print -- "- symlink source：$source"
    print -- "  target：$target；action：建立受管 symlink"
  fi
}

tooling_mise_command() {
  if [[ "$DOTFILES_TEST_MODE" == 1 ]]; then
    print -r -- "${commands[mise]:-}"
  else
    print -r -- "$DOTFILES_HOMEBREW_PREFIX/bin/mise"
  fi
}

tooling_uv_command() {
  if [[ "$DOTFILES_TEST_MODE" == 1 ]]; then
    print -r -- "${commands[uv]:-}"
  else
    print -r -- "$DOTFILES_HOMEBREW_PREFIX/bin/uv"
  fi
}

tooling_global_cli_plan() {
  local record description package version binaries source_manager target_manager target_spec reason
  local selection="${DOTFILES_GLOBAL_CLI_SELECTION:-skip}"

  [[ -e "$(tooling_global_cli_file)" ]] || {
    print -- '- 声明不存在，跳过'
    return 0
  }
  if [[ "$selection" == skip ]]; then
    if ! tooling_load_global_cli_declaration; then
      print -- '- 声明无效；本机已选择 skip，仅跳过可选全局 CLI'
      return 0
    fi
  else
    tooling_load_global_cli_declaration || return 1
  fi
  tooling_select_global_cli || return 1
  if (( ${#TOOLING_SELECTED_GLOBAL_CLI_RECORDS} == 0 )); then
    print -- '- 本机选择：skip（不影响基础 tooling）'
    return 0
  fi
  tooling_load_mise_tools || return 1
  [[ -n "${TOOLING_MISE_VERSION[node]:-}" ]] || {
    print -u2 -- 'tooling: global CLI 迁移需要 mise Node 声明'
    return 1
  }
  print -- "- 本机选择：$TOOLING_GLOBAL_CLI_SELECTION_LABEL"
  for record in "${TOOLING_SELECTED_GLOBAL_CLI_RECORDS[@]}"; do
    IFS='|' read -r description package version binaries source_manager target_manager target_spec reason <<< "$record"
    print -- "- npm via mise node@$TOOLING_MISE_VERSION[node] → $target_spec"
    print -- "  source：$package@$version；binaries：$binaries；reason：$reason"
  done
}

tooling_apply_global_cli() {
  local record description package version binaries source_manager target_manager target_spec reason
  local mise_command
  local -a specs

  [[ -e "$(tooling_global_cli_file)" ]] || return 0
  [[ "${DOTFILES_GLOBAL_CLI_SELECTION:-skip}" == skip ]] && return 0
  tooling_load_global_cli_declaration || return 1
  tooling_select_global_cli || return 1
  (( ${#TOOLING_SELECTED_GLOBAL_CLI_RECORDS} > 0 )) || return 0
  tooling_load_mise_tools || return 1
  [[ -n "${TOOLING_MISE_VERSION[node]:-}" ]] || return 1
  mise_command="$(tooling_mise_command)"
  [[ -n "$mise_command" && -x "$mise_command" ]] || return 1
  for record in "${TOOLING_SELECTED_GLOBAL_CLI_RECORDS[@]}"; do
    IFS='|' read -r description package version binaries source_manager target_manager target_spec reason <<< "$record"
    specs+=("$target_spec")
  done
  "$mise_command" --no-hooks exec "node@$TOOLING_MISE_VERSION[node]" -- \
    npm install --global "${specs[@]}" || return 1
  print -- '✓ 可选全局 CLI 已安装到 mise Node npm prefix'
}

tooling_verify_global_cli() {
  local record description package version binaries source_manager target_manager target_spec reason
  local mise_command node_version node_prefix manifest binary binary_path resolved
  local node_check
  local -a expected_binaries

  [[ -e "$(tooling_global_cli_file)" ]] || return 0
  [[ "${DOTFILES_GLOBAL_CLI_SELECTION:-skip}" == skip ]] && return 0
  tooling_load_global_cli_declaration || return 1
  tooling_select_global_cli || return 1
  (( ${#TOOLING_SELECTED_GLOBAL_CLI_RECORDS} > 0 )) || return 0
  tooling_load_mise_tools || return 1
  node_version="${TOOLING_MISE_VERSION[node]:-}"
  [[ -n "$node_version" ]] || return 1
  mise_command="$(tooling_mise_command)"
  node_prefix="$("$mise_command" --no-hooks where "node@$node_version" 2>/dev/null)" || node_prefix=''
  [[ -n "$node_prefix" && -d "$node_prefix" ]] || {
    print -u2 -- "verify: 无法定位 mise Node $node_version prefix"
    return 1
  }
  node_check='const fs=require("fs");const [p,n,b]=process.argv.slice(1);const x=JSON.parse(fs.readFileSync(p,"utf8"));const bins=typeof x.bin==="string"?[n.split("/").pop()]:Object.keys(x.bin||{});if(x.name!==n||!x.version||b.split(",").some(v=>!bins.includes(v)))process.exit(1);process.stdout.write(x.version);'
  for record in "${TOOLING_SELECTED_GLOBAL_CLI_RECORDS[@]}"; do
    IFS='|' read -r description package version binaries source_manager target_manager target_spec reason <<< "$record"
    manifest="$node_prefix/lib/node_modules/$package/package.json"
    [[ -f "$manifest" && ! -L "$manifest" ]] || {
      print -u2 -- "verify: mise Node npm global 缺少 $package"
      return 1
    }
    version="$("$mise_command" --no-hooks exec "node@$node_version" -- \
      node -e "$node_check" "$manifest" "$package" "$binaries" 2>/dev/null)" || {
      print -u2 -- "verify: $package manifest 的 package/version/binaries 不匹配"
      return 1
    }
    expected_binaries=(${(s:,:)binaries})
    for binary in "${expected_binaries[@]}"; do
      binary_path="$node_prefix/bin/$binary"
      [[ -x "$binary_path" ]] || {
        print -u2 -- "verify: $binary 不在 mise Node npm global bin"
        return 1
      }
      resolved="${binary_path:A}"
      [[ "$resolved" == "$node_prefix"/* ]] || {
        print -u2 -- "verify: $binary 解析到 mise Node prefix 之外"
        return 1
      }
    done
    print -- "  npm $package@$version → mise node@$node_version"
  done
  print -- '✓ 可选全局 CLI package/version/binaries 与 mise Node owner'
}

tooling_plan() {
  local record owner file target uv_config tool version
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
    for tool in ${(ok)TOOLING_MISE_VERSION}; do
      version="$TOOLING_MISE_VERSION[$tool]"
      print -- "- runtime source：mise $tool@$version（$TOOLING_MISE_OWNER[$tool]）"
      print -- "  target：${MISE_DATA_DIR:-$DOTFILES_TARGET_HOME/.local/share/mise}/installs（由 mise where $tool@$version 精确验证）"
    done
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
    for version in ${(ok)TOOLING_PYTHON_OWNER}; do
      print -- "- runtime source：uv Python $version（$TOOLING_PYTHON_OWNER[$version]）"
      print -- "  target：${UV_PYTHON_INSTALL_DIR:-$DOTFILES_TARGET_HOME/.local/share/uv/python}（uv managed）"
    done
  else
    blocked=1
  fi

  print
  print -- '[可选全局 CLI 迁移]'
  tooling_global_cli_plan || blocked=1

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
  local record owner file target uv_config version tool mise_command uv_command
  local -a versions mise_specs

  mise_command="$(tooling_mise_command)"
  uv_command="$(tooling_uv_command)"
  [[ -n "$mise_command" && -x "$mise_command" ]] || {
    print -u2 -- 'tooling: mise 未安装；macos 模块应先完成 Brewfile'
    return 1
  }
  [[ -n "$uv_command" && -x "$uv_command" ]] || {
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
  "$mise_command" --no-hooks -y install "${mise_specs[@]}" || return 1

  uv_config="$DOTFILES_PERSONAL_DIR/tooling/uv/uv.toml"
  tooling_create_managed_link "$DOTFILES_TARGET_HOME/.config/uv/uv.toml" "$uv_config" || return 1
  tooling_load_python_versions || return 1
  versions=(${(ok)TOOLING_PYTHON_OWNER})
  "$uv_command" --config-file "$uv_config" --no-progress python install "${versions[@]}" || return 1
  tooling_apply_global_cli
}

tooling_verify_binary_arch() {
  local name="$1" binary_path="$2" expected_arch
  [[ -n "$binary_path" && -x "$binary_path" ]] || {
    print -u2 -- "verify: $name 不在原生目标路径"
    return 1
  }
  if [[ "$DOTFILES_TEST_MODE" != 1 ]]; then
    if [[ "$binary_path" != "$DOTFILES_HOMEBREW_PREFIX"/* ]]; then
      print -u2 -- "verify: $name 必须来自 $DOTFILES_HOMEBREW_PREFIX"
      return 1
    fi
    expected_arch='x86_64|universal binary'
    [[ "$DOTFILES_NATIVE_ARCH" == arm64 ]] && expected_arch='arm64|universal binary'
    if ! file -L "$binary_path" | grep -Eq "$expected_arch"; then
      print -u2 -- "verify: $name 架构不符合 $DOTFILES_NATIVE_ARCH"
      return 1
    fi
  fi
}

tooling_verify() {
  local record owner file target uv_config version output tool mise_command uv_command location
  local -a mise_specs
  typeset -i failed=0

  mise_command="$(tooling_mise_command)"
  uv_command="$(tooling_uv_command)"
  tooling_verify_binary_arch mise "$mise_command" || failed=1
  tooling_verify_binary_arch uv "$uv_command" || failed=1

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
  if tooling_load_mise_tools && [[ -x "$mise_command" ]]; then
    for tool in ${(ok)TOOLING_MISE_VERSION}; do
      mise_specs+=("${tool}@${TOOLING_MISE_VERSION[$tool]}")
      if [[ "$DOTFILES_TEST_MODE" != 1 ]]; then
        location="$("$mise_command" --no-hooks where "${tool}@${TOOLING_MISE_VERSION[$tool]}" 2>/dev/null)" || location=''
        if [[ -z "$location" || ! -d "$location" ]]; then
          print -u2 -- "verify: mise runtime ${tool}@${TOOLING_MISE_VERSION[$tool]} 没有精确安装目录"
          failed=1
        else
          print -- "  mise ${tool}@${TOOLING_MISE_VERSION[$tool]} → $location"
        fi
      fi
    done
    "$mise_command" --no-hooks install --dry-run-code "${mise_specs[@]}" >/dev/null 2>&1 || {
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
  if tooling_load_python_versions && [[ -x "$uv_command" ]]; then
    output="$("$uv_command" --config-file "$uv_config" --no-progress python list --only-installed --managed-python 2>/dev/null)" || {
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

  tooling_verify_global_cli || failed=1

  if (( failed == 0 )); then
    print -- '✓ mise/uv 配置、固定版本、受管 symlink 与二进制架构'
  fi
  (( failed == 0 ))
}
