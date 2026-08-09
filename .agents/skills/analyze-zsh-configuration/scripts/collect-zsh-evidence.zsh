#!/bin/zsh

# Collect sanitized structural evidence for AI-assisted Zsh analysis. Never
# source startup files or print variable, alias, or function bodies.

emulate -L zsh
setopt NO_UNSET PIPE_FAIL NULL_GLOB
umask 077

if (( $# != 0 )); then
  print -u2 -- '用法：collect-zsh-evidence.zsh'
  exit 1
fi

readonly repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"
readonly current_dir="${PWD:A}"
readonly source_home="${ZSH_ANALYSIS_TEST_HOME:-$HOME}"

if [[ -z "$repo_root" || "$repo_root" != "$current_dir" ]]; then
  print -u2 -- 'collect-zsh-evidence.zsh: 必须从当前公开 Git 仓库根目录运行'
  exit 1
fi
if [[ -n "${ZSH_ANALYSIS_TEST_HOME:-}" && "$source_home" != /private/tmp/* ]]; then
  print -u2 -- 'collect-zsh-evidence.zsh: ZSH_ANALYSIS_TEST_HOME 仅允许指向 /private/tmp/ 下的测试 fixture'
  exit 1
fi

readonly output_root="$repo_root/tmp"
readonly report="$output_root/zsh-evidence.md"

cleanup_report() {
  command rm -f -- "$report"
}

cleanup_on_signal() {
  cleanup_report
  exit 1
}
trap cleanup_on_signal HUP INT TERM

prepare_output() {
  if [[ -L "$output_root" ]]; then
    print -u2 -- 'collect-zsh-evidence.zsh: tmp/ 不得是 symlink'
    exit 1
  fi
  if ! git -C "$repo_root" check-ignore -q -- 'tmp/.zsh-evidence-ignore-check'; then
    print -u2 -- 'collect-zsh-evidence.zsh: tmp/ 必须被当前仓库的 Git ignore 规则覆盖'
    exit 1
  fi

  command mkdir -p -- "$output_root"
  if [[ ! -O "$output_root" ]]; then
    print -u2 -- 'collect-zsh-evidence.zsh: tmp/ 必须属于当前用户'
    exit 1
  fi
  chmod 700 "$output_root"

  cleanup_report
  : > "$report"
  chmod 600 "$report"
}

classify_path() {
  local value="$1"
  case "$value" in
    "$source_home/.local/bin"|"$source_home/.cargo/bin")
      print -r -- "${value/#$source_home/\$HOME}"
      ;;
    "$source_home"/*|/Users/*)
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
    function source_category(value, lower) {
      lower = tolower(value)
      if (lower ~ /parameters\.zsh/) return "local-parameters"
      if (lower ~ /oh-my-zsh/) return "oh-my-zsh"
      if (lower ~ /\/usr\/local|x86_64|rosetta/) return "intel-or-legacy"
      if (lower ~ /\/opt\/homebrew/) return "apple-silicon-homebrew"
      if (lower ~ /mise/) return "mise"
      if (lower ~ /nvm/) return "nvm"
      if (lower ~ /pyenv/) return "pyenv"
      if (lower ~ /compinit|completion/) return "completion"
      if (value ~ /[$`{(]/) return "dynamic-or-variable"
      if (value ~ /^\//) return "absolute-path-redacted"
      return "relative-path-redacted"
    }
    {
      line = $0
      sub(/[[:space:]]*#.*/, "", line)

      source_line = line
      if (source_line ~ /^[[:space:]]*(source|\.)[[:space:]]+/) {
        sub(/^[[:space:]]*(source|\.)[[:space:]]+/, "", source_line)
        sub(/[[:space:];].*/, "", source_line)
        gsub(/[\047\042]/, "", source_line)
        emit("source-category", source_category(source_line))
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
  ' "$file"
}

zsh_file_summary() {
  local file="$1"
  local label="${file:t}"
  local kind='missing'
  local target='-'
  local permissions='-'
  local syntax='not-checked'
  local intel_hits=0
  local compinit_hits=0
  local completion_hits=0
  local plugin_hits=0
  local load_context='unknown'

  case "$label" in
    .zshenv) load_context='all-zsh-invocations' ;;
    .zprofile) load_context='login-shell' ;;
    .zshrc) load_context='interactive-shell' ;;
    .zlogin) load_context='login-shell-after-zshrc' ;;
  esac

  if [[ -L "$file" ]]; then
    kind='symlink'
    target="$(classify_path "$(readlink "$file")")"
  elif [[ -f "$file" ]]; then
    kind='file'
  elif [[ -e "$file" ]]; then
    kind='other'
  fi

  if [[ -e "$file" || -L "$file" ]]; then
    permissions="$(stat -f '%Sp' "$file" 2>/dev/null || print unknown)"
  fi
  if [[ -f "$file" ]]; then
    zsh -n "$file" >/dev/null 2>&1 && syntax='pass' || syntax='fail'
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

safety_check() {
  if grep -Fq "$source_home" "$report" \
    || grep -Eq '/Users/[^/[:space:]"'\'']+' "$report" \
    || grep -Eqi '[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}' "$report" \
    || grep -Eqi 'AKIA[[:alnum:]]{16}|sk-[[:alnum:]_-]{20,}|BEGIN (RSA |OPENSSH )?PRIVATE KEY' "$report"; then
    print -u2 -- 'collect-zsh-evidence.zsh: 安全检查失败，本次证据已删除'
    cleanup_report
    exit 1
  fi
}

prepare_output

{
  print -r -- '# Stage 0 Zsh evidence'
  print
  print -r -- '- scope: sanitized structural signals from Zsh startup files'
  print -r -- '- values-and-bodies: not-collected'
  print -r -- '- local-parameters-and-keychain: not-read'
  print
  print -r -- '## Zsh startup files'
  print
} > "$report"

for startup_file in .zshenv .zprofile .zshrc .zlogin; do
  zsh_file_summary "$source_home/$startup_file"
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
  print -r -- '## AI analysis handoff'
  print
  print -r -- '- Interpret this evidence with skills/analyze-zsh-configuration/references/zshrc-diagnostics-guide.md.'
  print -r -- '- Treat unknown source expressions and redacted paths as manual.'
  print -r -- '- Generate recommendations only; do not modify live Zsh files.'
} >> "$report"

safety_check
chmod 600 "$report"
print -r -- 'collect-zsh-evidence.zsh: 完成；请由 Zsh 分析 Skill 审阅 tmp/zsh-evidence.md'
