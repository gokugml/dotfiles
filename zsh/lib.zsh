# shellcheck shell=zsh

# ==============================================================================
# diagnostics.zsh
# ==============================================================================

dotfiles-doctor() {
  emulate -L zsh
  local command_name command_path

  print -r -- "arch=$(command arch 2>/dev/null || print unknown)"
  for command_name in brew mise node bun pnpm uv python3 zoxide; do
    command_path="${commands[$command_name]:-absent}"
    print -r -- "${command_name}=${command_path}"
  done
  print -r -- "path_entries=${#path}"
  print -r -- "loaded_modules=${#DOTFILES_LOADED_MODULES}"
  print -rl -- "${DOTFILES_LOADED_MODULES[@]}"
} # 功能=展示架构工具来源与模块链；最佳实践=pass；修改级别=建议修改；建议=不读取或打印密钥与完整环境；归属=public；验证=输出只含命令路径和模块路径

# ==============================================================================
# loader.zsh
# ==============================================================================

if [[ -n "${_DOTFILES_LOADER_READY:-}" ]]; then
  return 0
fi
typeset -g _DOTFILES_LOADER_READY=1
typeset -gaU DOTFILES_LOADED_MODULES
typeset -gA DOTFILES_MODULE_ORIGINS

dotfiles_source_file() {
  emulate -L zsh
  local layer="$1"
  local file="$2"
  local source_status

  builtin source "$file"
  source_status=$?
  if (( source_status != 0 )); then
    print -u2 -- "dotfiles: ${layer} 层模块加载失败：${file:t}"
    [[ "${DOTFILES_STRICT:-0}" == 1 ]] && return "$source_status"
    return 0
  fi

  DOTFILES_LOADED_MODULES+=("$file")
  DOTFILES_MODULE_ORIGINS["${file:t}"]="$layer"
}

dotfiles_source_phase() {
  emulate -L zsh
  setopt local_options null_glob
  local phase="$1"
  local layer root aggregate directory file
  local -a layers roots

  layers=(public)
  roots=("$DOTFILES_PUBLIC_ROOT")
  if [[ "${DOTFILES_COMPANY_ENABLED:-0}" == 1 && -n "${DOTFILES_COMPANY_ROOT:-}" ]]; then
    layers+=(company)
    roots+=("$DOTFILES_COMPANY_ROOT")
  fi
  layers+=(local-only)
  roots+=("${DOTFILES_LOCAL_ROOT:-$HOME/.config/dotfiles/local}")

  local index
  for (( index = 1; index <= ${#layers}; index++ )); do
    layer="${layers[index]}"
    root="${roots[index]}"
    aggregate="$root/zsh/${phase}.d.zsh"
    directory="$root/zsh/${phase}.d"

    if [[ -r "$aggregate" ]]; then
      dotfiles_source_file "$layer" "$aggregate" || return
      continue
    fi

    [[ -d "$directory" ]] || continue
    for file in "$directory"/*.zsh(N); do
      dotfiles_source_file "$layer" "$file" || return
    done
  done
} # 功能=固定三层模块加载和降级行为；最佳实践=rewrite；修改级别=一定要改；建议=优先加载集中件并兼容 company/local-only 分片目录；归属=public；验证=fixture 显示 public-company-local 顺序

# ==============================================================================
# path.zsh
# ==============================================================================

dotfiles_refresh_path() {
  emulate -L zsh
  typeset -gU path PATH fpath FPATH
  local entry
  local -a kept prefix

  for entry in "${path[@]}"; do
    [[ -n "$entry" && -d "$entry" ]] || continue
    case "$entry" in
      /usr/local/bin|/usr/local/sbin) continue ;;
    esac
    kept+=("$entry")
  done

  [[ -d /opt/homebrew/bin ]] && prefix+=(/opt/homebrew/bin)
  [[ -d /opt/homebrew/sbin ]] && prefix+=(/opt/homebrew/sbin)
  [[ -d "$HOME/.local/bin" ]] && prefix+=("$HOME/.local/bin")
  path=("${prefix[@]}" "${kept[@]}")
  export PATH
} # 功能=构造唯一且原生 ARM 优先的 PATH；最佳实践=rewrite；修改级别=一定要改；建议=移除 Intel Homebrew 入口并只加入存在目录；归属=public；验证=重复调用后无重复和 usr-local Homebrew 路径

dotfiles_refresh_path

# ==============================================================================
# plugins.zsh
# ==============================================================================

dotfiles_activate_external_plugins() {
  emulate -L zsh
  local plugin_root="${DOTFILES_PLUGIN_ROOT:-$HOME/.local/share/dotfiles/plugins}"

  if [[ -r "$plugin_root/zsh-autosuggestions/zsh-autosuggestions.zsh" && -z "${_DOTFILES_AUTOSUGGESTIONS_SOURCED:-}" ]]; then
    typeset -g _DOTFILES_AUTOSUGGESTIONS_SOURCED=1
    builtin source "$plugin_root/zsh-autosuggestions/zsh-autosuggestions.zsh" # 功能=按历史提供异步输入建议；最佳实践=pass；修改级别=建议修改；建议=只加载阶段 1 安装的固定 revision；归属=public；验证=插件只 source 一次且不改变补全所有权
  fi

  if [[ -r "$plugin_root/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" && -z "${_DOTFILES_SYNTAX_HIGHLIGHTING_SOURCED:-}" ]]; then
    typeset -g _DOTFILES_SYNTAX_HIGHLIGHTING_SOURCED=1
    builtin source "$plugin_root/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" # 功能=交互输入语法高亮；最佳实践=pass；修改级别=建议修改；建议=在所有 widget 和插件之后最后加载；归属=public；验证=该 source 是入口最后一次外部插件激活
  fi
} # 功能=集中激活固定来源的外部插件；最佳实践=rewrite；修改级别=建议修改；建议=缺失时静默跳过且保持幂等；归属=public；验证=插件缺失时基础 shell 正常

# ==============================================================================
# reserved-names.zsh
# ==============================================================================

typeset -gaU DOTFILES_RESERVED_NAMES
DOTFILES_RESERVED_NAMES=(
  DOTFILES_PUBLIC_ROOT
  DOTFILES_COMPANY_ROOT
  DOTFILES_LOCAL_ROOT
  DOTFILES_LOADED_MODULES
  DOTFILES_MODULE_ORIGINS
  dotfiles_source_file
  dotfiles_source_phase
  dotfiles_refresh_path
  dotfiles_activate_external_plugins
  dotfiles-doctor
) # 功能=声明公开运行时保留名称；最佳实践=pass；修改级别=建议修改；建议=公司和本地层不得覆盖核心加载与安全接口；归属=public；验证=阶段 1 静态检查拒绝重复定义
