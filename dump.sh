#!/bin/zsh

# Stage 0 software and tooling collector. Native tool dumps and sanitized
# evidence are written only to the repository's ignored tmp/ candidate tree.
# Zsh analysis and AI review are separate skills and are never invoked here.

emulate -L zsh
setopt NO_UNSET PIPE_FAIL NULL_GLOB
umask 077

if (( $# != 0 )); then
  print -u2 -- '用法：./dump.sh'
  exit 1
fi

readonly script_dir="${0:A:h}"
readonly repo_root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null)"

if [[ -z "$repo_root" || "$repo_root" != "$script_dir" ]]; then
  print -u2 -- 'dump.sh: 必须位于当前公开 Git 仓库根目录'
  exit 1
fi

readonly output_root="$repo_root/tmp"
readonly report="$output_root/dump.md"
readonly candidate_root="$output_root/my_setup"
readonly company_candidate_root="$output_root/company"
readonly runtime_tmp="$output_root/.runtime"
readonly uv_cache_dir="$runtime_tmp/uv-cache"
typeset -i partial=0

export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_API_AUTO_UPDATE_SECS=31536000

cleanup_managed_output() {
  command rm -f -- "$report"
  command rm -rf -- "$candidate_root" "$company_candidate_root" "$runtime_tmp"
}

cleanup_on_signal() {
  cleanup_managed_output
  exit 1
}
trap cleanup_on_signal HUP INT TERM

prepare_output() {
  if [[ -L "$output_root" ]]; then
    print -u2 -- 'dump.sh: tmp/ 不得是 symlink'
    exit 1
  fi
  if ! git -C "$repo_root" check-ignore -q -- 'tmp/.dump-ignore-check'; then
    print -u2 -- 'dump.sh: tmp/ 必须被当前仓库的 Git ignore 规则覆盖'
    exit 1
  fi

  command mkdir -p -- "$output_root"
  if [[ ! -O "$output_root" ]]; then
    print -u2 -- 'dump.sh: tmp/ 必须属于当前用户'
    exit 1
  fi
  chmod 700 "$output_root"

  cleanup_managed_output
  command mkdir -p -- \
    "$candidate_root/macos" \
    "$runtime_tmp/homebrew/logs" \
    "$runtime_tmp/homebrew/temp"

  export TMPDIR="$runtime_tmp"
  export TMP="$runtime_tmp"
  export TEMP="$runtime_tmp"
  export XDG_CACHE_HOME="$runtime_tmp/xdg-cache"
  export NODE_COMPILE_CACHE="$runtime_tmp/node-compile-cache"
  export npm_config_cache="$runtime_tmp/npm-cache"
  export BUN_INSTALL_CACHE_DIR="$runtime_tmp/bun-cache"
  export GOCACHE="$runtime_tmp/go-cache"
  export MISE_CACHE_DIR="$runtime_tmp/mise-cache"
  export UV_CACHE_DIR="$uv_cache_dir"
  export HOMEBREW_LOGS="$runtime_tmp/homebrew/logs"
  export HOMEBREW_TEMP="$runtime_tmp/homebrew/temp"

  : > "$report"
  chmod 600 "$report"
}

sanitize_stream() {
  /usr/bin/sed -E \
    -e "s#${HOME//\#/\\#}#\$HOME#g" \
    -e 's#/Users/[^/[:space:]"'\'']+#$HOME#g' \
    -e 's#[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}#<redacted-email>#g' \
    -e 's#(https?|ssh)://[^[:space:]"'\'']+#<redacted-url>#g' \
    -e 's#git@[^[:space:]"'\'']+#<redacted-remote>#g'
}

append_command() {
  local label="$1"
  shift
  local command_output

  print -r -- "#### $label" >> "$report"
  print -r -- '```text' >> "$report"
  if command_output="$("$@" 2>&1)"; then
    if [[ -n "$command_output" ]]; then
      print -r -- "$command_output" | sanitize_stream >> "$report"
    else
      print -r -- '(no output)' >> "$report"
    fi
  else
    print -r -- "$command_output" | sanitize_stream >> "$report"
    print -r -- 'collector-failed' >> "$report"
    partial=1
  fi
  print -r -- '```' >> "$report"
  print >> "$report"
}

classify_path() {
  local value="$1"
  case "$value" in
    "$HOME/.local/bin"|"$HOME/.cargo/bin")
      print -r -- "${value/#$HOME/\$HOME}"
      ;;
    "$HOME"/*|/Users/*)
      print -r -- '$HOME/<redacted>'
      ;;
    /opt/homebrew/*|/usr/*|/bin|/sbin)
      print -r -- "$value"
      ;;
    *)
      print -r -- '<redacted-path>'
      ;;
  esac
}

tool_summary() {
  local name="$1"
  shift
  local executable="${commands[$name]:-}"
  if [[ -z "$executable" ]]; then
    print -r -- "- $name: not-installed" >> "$report"
    return
  fi

  local version
  if version="$("$@" 2>&1)"; then
    version="${version%%$'\n'*}"
    print -r -- "- $name: $(classify_path "$executable") | $(print -r -- "$version" | sanitize_stream)" >> "$report"
  else
    print -r -- "- $name: collector-failed" >> "$report"
    partial=1
  fi
}

brew_summary() {
  local label="$1"
  local brew_command="$2"

  print -r -- "### $label" >> "$report"
  if [[ ! -x "$brew_command" ]]; then
    print -r -- 'not-installed' >> "$report"
    print >> "$report"
    return
  fi

  append_command "$label version" "$brew_command" --version
  append_command "$label taps" "$brew_command" tap
  append_command "$label direct formulae" "$brew_command" leaves
  append_command "$label casks" "$brew_command" list --cask -1
  append_command "$label services" "$brew_command" services list
}

select_primary_brew() {
  if [[ -n "${commands[brew]:-}" && -x "${commands[brew]}" ]]; then
    print -r -- "${commands[brew]}"
  elif [[ -x /opt/homebrew/bin/brew ]]; then
    print -r -- /opt/homebrew/bin/brew
  elif [[ -x /usr/local/bin/brew ]]; then
    print -r -- /usr/local/bin/brew
  fi
}

native_brew_dump() {
  local brew_command="$1"
  local brewfile="$candidate_root/macos/Brewfile"
  local command_output

  print -r -- '## Native configuration dumps' >> "$report"
  print >> "$report"
  if [[ -z "$brew_command" ]]; then
    print -r -- '- Homebrew Brewfile: not-installed' >> "$report"
    print >> "$report"
    return
  fi

  if command_output="$("$brew_command" bundle dump --no-describe --file="$brewfile" --force 2>&1)"; then
    chmod 600 "$brewfile"
    print -r -- '- Homebrew Brewfile: tmp/my_setup/macos/Brewfile' >> "$report"
    print -r -- '- Homebrew descriptions: disabled to avoid refreshing external metadata; AI adds reviewed descriptions' >> "$report"
  else
    print -r -- '- Homebrew Brewfile: collector-failed' >> "$report"
    print -r -- "$command_output" | sanitize_stream >> "$report"
    command rm -f -- "$brewfile"
    partial=1
  fi
  print >> "$report"
}

secondary_brew_dumps() {
  local primary_brew="$1"
  local brew_command label

  for brew_command label in \
    /opt/homebrew/bin/brew 'Apple Silicon Homebrew native snapshot' \
    /usr/local/bin/brew 'Intel Homebrew native snapshot'; do
    [[ -x "$brew_command" ]] || continue
    [[ "$brew_command" == "$primary_brew" ]] && continue
    append_command "$label" "$brew_command" bundle dump --no-describe --file=-
  done
}

uv_tools_readonly_summary() {
  local tool_root="${UV_TOOL_DIR:-$HOME/.local/share/uv/tools}"
  local tool_dir receipt package_name normalized_package python_version installed_version
  local metadata metadata_name metadata_version

  print -r -- '#### uv tools read-only metadata fallback' >> "$report"
  print -r -- 'Native `uv tool list` is not used because it may create maintenance files in the live tool directory.' >> "$report"
  if [[ ! -d "$tool_root" ]]; then
    print -r -- 'not-installed' >> "$report"
    print >> "$report"
    return
  fi

  for tool_dir in "$tool_root"/*(/N); do
    receipt="$tool_dir/uv-receipt.toml"
    package_name='unknown'
    python_version='unknown'
    installed_version='unknown'
    if [[ -f "$receipt" ]]; then
      package_name="$(/usr/bin/awk '
        /^requirements[[:space:]]*=/ {
          line = $0
          if (match(line, /name[[:space:]]*=[[:space:]]*"[^"]+"/)) {
            token = substr(line, RSTART, RLENGTH)
            sub(/^[^"]*"/, "", token)
            sub(/".*$/, "", token)
            print token
          }
          exit
        }
      ' "$receipt")"
      [[ -z "$package_name" ]] && package_name='unknown'
    fi
    if [[ -f "$tool_dir/pyvenv.cfg" ]]; then
      python_version="$(/usr/bin/awk -F ' = ' '$1 == "version_info" { print $2; exit }' "$tool_dir/pyvenv.cfg")"
      [[ -z "$python_version" ]] && python_version='unknown'
    fi
    if [[ "$package_name" != unknown ]]; then
      normalized_package="${package_name:l}"
      normalized_package="${normalized_package//_/-}"
      for metadata in "$tool_dir"/lib/python*/site-packages/*.dist-info/METADATA(.N); do
        metadata_name="$(/usr/bin/awk -F ': ' '$1 == "Name" { print $2; exit }' "$metadata")"
        metadata_version="$(/usr/bin/awk -F ': ' '$1 == "Version" { print $2; exit }' "$metadata")"
        metadata_name="${metadata_name:l}"
        metadata_name="${metadata_name//_/-}"
        if [[ "$metadata_name" == "$normalized_package" ]]; then
          installed_version="${metadata_version:-unknown}"
          break
        fi
      done
    fi
    print -r -- "- name=${tool_dir:t} package=$package_name version=$installed_version python=$python_version" >> "$report"
  done
  print >> "$report"
}

pnpm_global_readonly_summary() {
  print -r -- '#### pnpm global packages read-only fallback' >> "$report"
  print -r -- 'Native `pnpm list --global` is not used because it may initialize or repair the live global bin directory.' >> "$report"
  print -r -- '- package inventory: use the npm JSON section when pnpm is installed through the current Node global prefix' >> "$report"
  print >> "$report"
}

plugin_repositories_summary() {
  local plugin_dir origin revision
  local -a plugin_dirs

  plugin_dirs=("$HOME/.oh-my-zsh" "$HOME/.local/share/dotfiles/plugins"/*(/N))
  print -r -- '## Installed Zsh plugin repositories' >> "$report"
  print >> "$report"
  if (( ${#plugin_dirs} == 0 )); then
    print -r -- '- none-detected' >> "$report"
  fi

  for plugin_dir in "${plugin_dirs[@]}"; do
    [[ -d "$plugin_dir/.git" ]] || continue
    origin="$(git -C "$plugin_dir" remote get-url origin 2>/dev/null || print unknown)"
    revision="$(git -C "$plugin_dir" rev-parse HEAD 2>/dev/null || print unknown)"
    case "$origin" in
      https://github.com/*|git@github.com:*) ;;
      *) origin='<redacted-remote>' ;;
    esac
    print -r -- "- name=${plugin_dir:t} source=$origin revision=$revision" >> "$report"
  done
  print >> "$report"
}

legacy_runtime_summary() {
  local label location

  print -r -- '## Legacy runtime footprints' >> "$report"
  print >> "$report"
  for label location in \
    nvm "$HOME/.nvm" \
    pyenv "$HOME/.pyenv" \
    pipx "$HOME/.local/pipx" \
    python-framework /Library/Frameworks/Python.framework; do
    if [[ -e "$location" ]]; then
      print -r -- "- $label: present; classification=manual" >> "$report"
    else
      print -r -- "- $label: absent" >> "$report"
    fi
  done
  print >> "$report"
}

safety_check() {
  local file
  local -a output_files

  output_files=("$report" "$candidate_root"/**/*(.N))
  for file in "${output_files[@]}"; do
    if grep -Fq "$HOME" "$file" \
      || grep -Eq '/Users/[^/[:space:]"'\'']+' "$file" \
      || grep -Eqi '[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}' "$file" \
      || grep -Eqi 'AKIA[[:alnum:]]{16}|sk-[[:alnum:]_-]{20,}|BEGIN (RSA |OPENSSH )?PRIVATE KEY' "$file"; then
      print -u2 -- 'dump.sh: 安全检查失败，本次候选输出已删除'
      cleanup_managed_output
      exit 1
    fi
  done
}

prepare_output

{
  print -r -- '# Dotfiles Stage 0 dump'
  print
  print -r -- '- scope: read-only software, tooling, and plugin evidence plus native candidate files'
  print -r -- '- repository: current-public-repository'
  print -r -- '- candidate-root: tmp/my_setup/'
  print -r -- '- secrets: values not collected'
  print
} > "$report"

{
  print -r -- '## Tool availability'
  print
} >> "$report"

tool_summary brew brew --version
tool_summary mise mise --version
tool_summary uv uv --version
tool_summary bun bun --version
tool_summary node node --version
tool_summary pnpm pnpm --version
tool_summary npm npm --version
tool_summary go go version
tool_summary python3 python3 --version
tool_summary pyenv pyenv --version
tool_summary pipx pipx --version

readonly primary_brew="$(select_primary_brew)"
native_brew_dump "$primary_brew"

{
  print -r -- '## Homebrew state'
  print
} >> "$report"
brew_summary 'Apple Silicon Homebrew' /opt/homebrew/bin/brew
brew_summary 'Intel Homebrew' /usr/local/bin/brew
secondary_brew_dumps "$primary_brew"

{
  print -r -- '## Runtime and tooling native state'
  print
} >> "$report"
if [[ -n "${commands[mise]:-}" ]]; then
  append_command 'mise installed tools JSON' mise --no-hooks ls --installed --json --all-sources
fi
if [[ -n "${commands[uv]:-}" ]]; then
  append_command 'uv installed Python JSON' env UV_NO_PROGRESS=1 uv python list --only-installed --output-format json --no-python-downloads
  uv_tools_readonly_summary
fi
if [[ -n "${commands[pipx]:-}" ]]; then
  append_command 'pipx restorable snapshot JSON' pipx list --skip-maintenance --output json
fi
if [[ -n "${commands[pnpm]:-}" ]]; then
  pnpm_global_readonly_summary
fi
if [[ -n "${commands[npm]:-}" ]]; then
  append_command 'npm global direct packages JSON' npm list --global --depth=0 --json
fi
if [[ -n "${commands[go]:-}" ]]; then
  append_command 'Go environment JSON' go env -json GOARCH GOHOSTARCH GOVERSION
fi

plugin_repositories_summary
legacy_runtime_summary

{
  print -r -- '## Existing repository declarations'
  print
} >> "$report"
for declaration in \
  "$repo_root/my_setup/macos/Brewfile" \
  "$repo_root/my_setup/tooling/mise/10-public.toml" \
  "$repo_root/my_setup/tooling/uv/.python-versions" \
  "$repo_root/my_setup/tooling/uv/uv.toml" \
  "$repo_root/my_setup/zsh/plugins.toml"; do
  if [[ -f "$declaration" ]]; then
    print -r -- "- ${declaration#$repo_root/}: present" >> "$report"
  else
    print -r -- "- ${declaration#$repo_root/}: missing" >> "$report"
  fi
done

{
  print
  print -r -- '## Export handoff'
  print
  print -r -- '- Candidate files require the exported-dotfiles review skill before user confirmation.'
  print -r -- '- Zsh startup-file analysis is intentionally outside dump.sh.'
  print
  print -r -- '## Manual follow-up'
  print
  print -r -- '- Service and application data were not read or migrated.'
  print -r -- '- Unknown tool ownership requires AI review.'
  print -r -- '- Local parameters and Keychain contents were not inspected.'
} >> "$report"

command rm -rf -- "$runtime_tmp"
safety_check
chmod 600 "$report" "$candidate_root"/**/*(.N)

if (( partial )); then
  print -r -- 'dump.sh: 部分采集器失败；候选文件仍可供导出配置 Review Skill 审阅：tmp/'
  exit 2
fi

print -r -- 'dump.sh: 完成；请使用导出配置 Review Skill 审阅 tmp/dump.md 与 tmp/my_setup/'
