#!/bin/zsh

# Stage 0 read-only evidence collector. It never sources user Zsh files and
# writes its single, temporary report outside the repository.

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
  print -u2 -- "dump.sh: 必须位于当前公开 Git 仓库根目录"
  exit 1
fi

readonly temp_root="${TMPDIR:-/tmp}"
readonly output_dir="$(mktemp -d "${temp_root%/}/dotfiles-dump.XXXXXX")"
readonly report="$output_dir/dump.md"
typeset -i partial=0

cleanup_on_signal() {
  command rm -rf -- "$output_dir"
  exit 1
}
trap cleanup_on_signal HUP INT TERM

sanitize_stream() {
  /usr/bin/sed -E \
    -e "s#${HOME//\#/\\#}#\$HOME#g" \
    -e 's#/Users/[^/[:space:]]+#$HOME#g' \
    -e 's#[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}#<redacted-email>#g' \
    -e 's#(https?|ssh)://[^[:space:]]+#<redacted-url>#g' \
    -e 's#git@[^[:space:]]+#<redacted-remote>#g'
}

append_command() {
  local label="$1"
  shift
  local command_output

  print -r -- "#### $label" >> "$report"
  print -r -- '```text' >> "$report"
  if command_output="$("$@" 2>&1)"; then
    print -r -- "$command_output" | sanitize_stream >> "$report"
  else
    print -r -- "$command_output" | sanitize_stream >> "$report"
    print -r -- "collector-failed" >> "$report"
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

zsh_file_signals() {
  local file="$1"
  /usr/bin/awk '
    function emit(kind, value) {
      if (value != "") print "- " kind ": line " NR " " value
    }
    {
      line = $0
      sub(/[[:space:]]*#.*/, "", line)

      source_line = line
      if (source_line ~ /^[[:space:]]*(source|\.)[[:space:]]+/) {
        sub(/^[[:space:]]*(source|\.)[[:space:]]+/, "", source_line)
        sub(/[[:space:];].*/, "", source_line)
        gsub(/[\047\042]/, "", source_line)
        emit("source", source_line)
      }

      alias_line = line
      if (alias_line ~ /^[[:space:]]*alias[[:space:]]+/) {
        sub(/^[[:space:]]*alias[[:space:]]+/, "", alias_line)
        sub(/=.*/, "", alias_line)
        emit("alias", alias_line)
      }

      function_line = line
      if (function_line ~ /^[[:space:]]*function[[:space:]]+/) {
        sub(/^[[:space:]]*function[[:space:]]+/, "", function_line)
        sub(/[[:space:]\(\{].*/, "", function_line)
        emit("function", function_line)
      } else if (function_line ~ /^[[:space:]]*[A-Za-z_][A-Za-z0-9_-]*[[:space:]]*\(\)[[:space:]]*\{/) {
        sub(/^[[:space:]]*/, "", function_line)
        sub(/[[:space:]]*\(\).*/, "", function_line)
        emit("function", function_line)
      }

      variable_line = line
      sub(/^[[:space:]]*export[[:space:]]+/, "", variable_line)
      if (variable_line ~ /^[A-Za-z_][A-Za-z0-9_]*=/) {
        sub(/=.*/, "", variable_line)
        emit("variable", variable_line)
      }
    }
  ' "$file" | sanitize_stream
}

zsh_file_summary() {
  local file="$1"
  local label="${file:t}"
  local kind="missing"
  local target="-"
  local permissions="-"
  local syntax="not-checked"
  local intel_hits=0
  local compinit_hits=0
  local completion_hits=0
  local plugin_hits=0
  local load_context="unknown"

  case "$label" in
    .zshenv) load_context="all-zsh-invocations" ;;
    .zprofile) load_context="login-shell" ;;
    .zshrc) load_context="interactive-shell" ;;
    .zlogin) load_context="login-shell-after-zshrc" ;;
  esac

  if [[ -L "$file" ]]; then
    kind="symlink"
    target="$(classify_path "$(readlink "$file")")"
  elif [[ -f "$file" ]]; then
    kind="file"
  elif [[ -e "$file" ]]; then
    kind="other"
  fi

  if [[ -e "$file" || -L "$file" ]]; then
    permissions="$(stat -f '%Sp' "$file" 2>/dev/null || print unknown)"
  fi
  if [[ -f "$file" ]]; then
    zsh -n "$file" >/dev/null 2>&1 && syntax="pass" || syntax="fail"
    intel_hits="$(grep -Eci '/usr/local|x86_64|arch[[:space:]]+-x86_64|Rosetta' "$file" 2>/dev/null || true)"
    compinit_hits="$(grep -Eci '(^|[^[:alnum:]_])compinit([^[:alnum:]_]|$)' "$file" 2>/dev/null || true)"
    completion_hits="$(grep -Eci 'compdef|bashcompinit|fpath|FPATH' "$file" 2>/dev/null || true)"
    plugin_hits="$(grep -Eci 'oh-my-zsh|plugins=|plugin(s)?/' "$file" 2>/dev/null || true)"
  fi

  print -r -- "### $label" >> "$report"
  print -r -- "- load-context: $load_context" >> "$report"
  print -r -- "- kind: $kind" >> "$report"
  print -r -- "- permissions: $permissions" >> "$report"
  print -r -- "- symlink-target: $target" >> "$report"
  print -r -- "- syntax: $syntax" >> "$report"
  print -r -- "- intel-markers: $intel_hits" >> "$report"
  print -r -- "- compinit-markers: $compinit_hits" >> "$report"
  print -r -- "- completion-markers: $completion_hits" >> "$report"
  print -r -- "- plugin-markers: $plugin_hits" >> "$report"
  if [[ -f "$file" ]]; then
    zsh_file_signals "$file" >> "$report"
  fi
  print >> "$report"
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
    print -r -- "not-installed" >> "$report"
    print >> "$report"
    return
  fi

  append_command "$label version" "$brew_command" --version
  append_command "$label taps" "$brew_command" tap
  append_command "$label direct formulae" "$brew_command" leaves
  append_command "$label casks" "$brew_command" list --cask -1
  append_command "$label services" "$brew_command" services list
}

uv_tools_summary() {
  local tool_root="${UV_TOOL_DIR:-$HOME/.local/share/uv/tools}"
  local tool_dir

  print -r -- '#### uv tools' >> "$report"
  if [[ ! -d "$tool_root" ]]; then
    print -r -- 'not-installed' >> "$report"
    print >> "$report"
    return
  fi

  for tool_dir in "$tool_root"/*(/N); do
    print -r -- "- ${tool_dir:t}" >> "$report"
  done
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

{
  print -r -- '# Dotfiles Stage 0 dump'
  print
  print -r -- '- scope: read-only source-machine evidence'
  print -r -- '- repository: current-public-repository'
  print -r -- '- secrets: values not collected'
  print
  print -r -- '## Zsh startup files'
  print
} > "$report"

for startup_file in .zshenv .zprofile .zshrc .zlogin; do
  zsh_file_summary "$HOME/$startup_file"
done

{
  print -r -- '## Inherited command search paths'
  print
  for path_entry in ${(s/:/)PATH}; do
    print -r -- "- $(classify_path "$path_entry")"
  done
  print
  print -r -- '## Inherited completion search paths'
  print
  for path_entry in "${fpath[@]}"; do
    print -r -- "- $(classify_path "$path_entry")"
  done
  print
  print -r -- '## Tool availability'
  print
} >> "$report"

tool_summary brew brew --version
tool_summary mise mise --version
tool_summary uv uv --version
tool_summary bun bun --version
tool_summary node node --version
tool_summary pnpm pnpm --version
tool_summary go go version
tool_summary python3 python3 --version
tool_summary pyenv pyenv --version
tool_summary pipx pipx --version

{
  print
  print -r -- '## Homebrew state'
  print
} >> "$report"
brew_summary 'Apple Silicon Homebrew' /opt/homebrew/bin/brew
brew_summary 'Intel Homebrew' /usr/local/bin/brew

{
  print -r -- '## Runtime manager state'
  print
} >> "$report"
[[ -n "${commands[mise]:-}" ]] && append_command 'mise list' mise list
if [[ -n "${commands[uv]:-}" ]]; then
  append_command 'uv managed Python' env UV_CACHE_DIR="$output_dir/.uv-cache" UV_NO_PROGRESS=1 uv python list --only-installed
  uv_tools_summary
  command rm -rf -- "$output_dir/.uv-cache"
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
  print -r -- '## Manual follow-up'
  print
  print -r -- '- Service and application data were not read or migrated.'
  print -r -- '- Dynamic source expressions and unknown tool ownership require AI review.'
  print -r -- '- Local parameters and Keychain contents were not inspected.'
} >> "$report"

if grep -Fq "$HOME" "$report" || grep -Eqi 'AKIA[[:alnum:]]{16}|sk-[[:alnum:]_-]{20,}|BEGIN (RSA |OPENSSH )?PRIVATE KEY' "$report"; then
  print -u2 -- 'dump.sh: 安全检查失败，临时输出已删除'
  command rm -rf -- "$output_dir"
  exit 1
fi

chmod 600 "$report"
if (( partial )); then
  print -r -- "dump.sh: 部分采集器失败；报告仍可供 AI 审查：$report"
  exit 2
fi

print -r -- "dump.sh: 完成：$report"
