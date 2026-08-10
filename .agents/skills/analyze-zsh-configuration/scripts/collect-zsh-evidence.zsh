#!/bin/zsh

# Collect sanitized structural evidence for AI-assisted Zsh analysis. Never
# source startup files or print variable, alias, or function bodies.

emulate -L zsh
setopt NO_UNSET PIPE_FAIL NULL_GLOB
umask 077

readonly repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"
readonly current_dir="${PWD:A}"

if [[ -z "$repo_root" || "$repo_root" != "$current_dir" ]]; then
  print -u2 -- 'collect-zsh-evidence.zsh: 必须从当前公开 Git 仓库根目录运行'
  exit 1
fi

usage() {
  print -u2 -- '用法：'
  print -u2 -- '  collect-zsh-evidence.zsh --source live-home [--files zshenv,zprofile,zshrc,zlogin] [--preflight]'
  print -u2 -- '  collect-zsh-evidence.zsh --source repository --source-dir <repo-relative-dir> [--files zprofile,zshrc] [--preflight]'
}

source_mode=''
source_dir_argument=''
startup_files_argument='zshenv,zprofile,zshrc,zlogin'
preflight_only='no'

while (( $# > 0 )); do
  case "$1" in
    --source)
      (( $# >= 2 )) || { usage; exit 1; }
      source_mode="$2"
      shift 2
      ;;
    --source-dir)
      (( $# >= 2 )) || { usage; exit 1; }
      source_dir_argument="$2"
      shift 2
      ;;
    --files)
      (( $# >= 2 )) || { usage; exit 1; }
      startup_files_argument="$2"
      shift 2
      ;;
    --preflight)
      preflight_only='yes'
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      print -u2 -- "collect-zsh-evidence.zsh: 未知参数：$1"
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$source_mode" ]]; then
  print -u2 -- 'collect-zsh-evidence.zsh: 必须显式选择 --source live-home 或 --source repository'
  usage
  exit 1
fi

readonly semantic_home="${ZSH_ANALYSIS_TEST_HOME:-$HOME}"
if [[ -n "${ZSH_ANALYSIS_TEST_HOME:-}" && "$semantic_home" != /private/tmp/* ]]; then
  print -u2 -- 'collect-zsh-evidence.zsh: ZSH_ANALYSIS_TEST_HOME 仅允许指向 /private/tmp/ 下的测试 fixture'
  exit 1
fi

source_origin=''
source_root_category=''
startup_root=''
case "$source_mode" in
  live-home)
    if [[ -n "$source_dir_argument" ]]; then
      print -u2 -- 'collect-zsh-evidence.zsh: live-home 模式不接受 --source-dir'
      exit 1
    fi
    source_origin='live-home'
    source_root_category='live-home'
    startup_root="$semantic_home"
    ;;
  repository)
    if [[ -z "$source_dir_argument" ]]; then
      print -u2 -- 'collect-zsh-evidence.zsh: repository 模式必须提供 --source-dir'
      exit 1
    fi
    if [[ ! -d "$source_dir_argument" || -L "$source_dir_argument" ]]; then
      print -u2 -- 'collect-zsh-evidence.zsh: --source-dir 必须是仓库内的真实目录，不得是 symlink'
      exit 1
    fi
    startup_root="${source_dir_argument:A}"
    case "$startup_root" in
      "$repo_root"|"$repo_root"/*) ;;
      *)
        print -u2 -- 'collect-zsh-evidence.zsh: --source-dir 解析后必须位于当前 Git 仓库内'
        exit 1
        ;;
    esac
    source_origin='repository'
    source_root_category='current-repository'
    ;;
  *)
    print -u2 -- "collect-zsh-evidence.zsh: 不支持的 --source：$source_mode"
    usage
    exit 1
    ;;
esac

typeset -a startup_files
typeset -A selected_names
startup_files=("${(@s:,:)startup_files_argument}")
if (( ${#startup_files[@]} == 0 )); then
  print -u2 -- 'collect-zsh-evidence.zsh: --files 不得为空'
  exit 1
fi
for startup_file in "${startup_files[@]}"; do
  startup_file="${startup_file#.}"
  case "$startup_file" in
    zshenv|zprofile|zshrc|zlogin) ;;
    *)
      print -u2 -- "collect-zsh-evidence.zsh: --files 包含不支持的名称：$startup_file"
      exit 1
      ;;
  esac
  if [[ -n "${selected_names[$startup_file]:-}" ]]; then
    print -u2 -- "collect-zsh-evidence.zsh: --files 包含重复名称：$startup_file"
    exit 1
  fi
  selected_names[$startup_file]=yes
done
startup_files=()
for startup_file in zshenv zprofile zshrc zlogin; do
  [[ -n "${selected_names[$startup_file]:-}" ]] && startup_files+=("$startup_file")
done

readonly source_origin source_root_category startup_root semantic_home

readonly output_root="$repo_root/tmp"
readonly report="$output_root/zsh-evidence.md"

typeset -A startup_paths
typeset -A startup_input_names

resolve_startup_paths() {
  local startup_file plain_candidate dotted_candidate selected_candidate resolved_candidate

  for startup_file in "${startup_files[@]}"; do
    if [[ "$source_origin" == live-home ]]; then
      selected_candidate="$startup_root/.$startup_file"
    else
      plain_candidate="$startup_root/$startup_file"
      dotted_candidate="$startup_root/.$startup_file"
      if [[ ( -e "$plain_candidate" || -L "$plain_candidate" ) \
        && ( -e "$dotted_candidate" || -L "$dotted_candidate" ) ]]; then
        print -u2 -- "collect-zsh-evidence.zsh: repository 模式中 $startup_file 与 .$startup_file 同时存在，无法确定输入"
        exit 1
      elif [[ -e "$plain_candidate" || -L "$plain_candidate" ]]; then
        selected_candidate="$plain_candidate"
      elif [[ -e "$dotted_candidate" || -L "$dotted_candidate" ]]; then
        selected_candidate="$dotted_candidate"
      else
        selected_candidate="$plain_candidate"
      fi

      if [[ -L "$selected_candidate" ]]; then
        resolved_candidate="${selected_candidate:A}"
        case "$resolved_candidate" in
          "$repo_root"|"$repo_root"/*) ;;
          *)
            print -u2 -- "collect-zsh-evidence.zsh: repository 模式中 .$startup_file 的 symlink 目标不得离开当前仓库"
            exit 1
            ;;
        esac
      fi
    fi

    startup_paths[$startup_file]="$selected_candidate"
    startup_input_names[$startup_file]="${selected_candidate:t}"
  done
}

input_kind() {
  local file="$1"
  if [[ -L "$file" ]]; then
    print -r -- 'symlink'
  elif [[ -f "$file" ]]; then
    print -r -- 'file'
  elif [[ -e "$file" ]]; then
    print -r -- 'other'
  else
    print -r -- 'missing'
  fi
}

print_preflight() {
  local startup_file

  print -r -- '- preflight: pass'
  print -r -- "- source-origin: $source_origin"
  print -r -- "- source-root-category: $source_root_category"
  print -r -- "- selected-files: ${(j:,:)startup_files}"
  for startup_file in "${startup_files[@]}"; do
    print -r -- "- input-map: .$startup_file <- ${startup_input_names[$startup_file]} kind=$(input_kind "${startup_paths[$startup_file]}")"
  done
  print -r -- '- report-written: no'
}

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
    "$semantic_home/.local/bin"|"$semantic_home/.cargo/bin")
      print -r -- "${value/#$semantic_home/\$HOME}"
      ;;
    "$semantic_home"/*|/Users/*)
      print -r -- '$HOME/<redacted>'
      ;;
    /opt/homebrew/*|/usr/*|/bin|/bin/*|/sbin|/sbin/*)
      print -r -- "$value"
      ;;
    *)
      print -r -- '<redacted-path>'
      ;;
  esac
}

command_architecture() {
  local command_name="$1"
  local command_path=''
  local path_category='missing'
  local file_info=''
  local architecture='missing'

  command_path="$(command -v "$command_name" 2>/dev/null || true)"
  if [[ -n "$command_path" ]]; then
    if [[ "$command_path" == /* ]]; then
      path_category="$(classify_path "$command_path")"
      file_info="$(/usr/bin/file -L -b -- "$command_path" 2>/dev/null || true)"
      if [[ "$file_info" == *arm64* && "$file_info" == *x86_64* ]]; then
        architecture='universal'
      elif [[ "$file_info" == *arm64* ]]; then
        architecture='arm64'
      elif [[ "$file_info" == *x86_64* ]]; then
        architecture='x86_64'
      elif [[ "$file_info" == *script* || "$file_info" == *text* ]]; then
        architecture='script-or-text'
      else
        architecture='other-or-unknown'
      fi
    else
      path_category='shell-command'
      architecture='shell-command'
    fi
  fi

  print -r -- "- command: $command_name source=$path_category architecture=$architecture"
}

print_runtime_facts() {
  local process_arch='unknown'
  local hardware_arm64='unavailable'
  local translated='unavailable'
  local brew_command=''
  local brew_source='missing'
  local brew_prefix='unavailable'
  local command_name

  process_arch="$(/usr/bin/arch 2>/dev/null || print unknown)"
  hardware_arm64="$(/usr/sbin/sysctl -in hw.optional.arm64 2>/dev/null || print unavailable)"
  [[ "$hardware_arm64" == 0 || "$hardware_arm64" == 1 ]] || hardware_arm64='unavailable'
  translated="$(/usr/sbin/sysctl -in sysctl.proc_translated 2>/dev/null || print unavailable)"
  [[ "$translated" == 0 || "$translated" == 1 ]] || translated='unavailable'

  brew_command="$(command -v brew 2>/dev/null || true)"
  if [[ "$brew_command" == /* ]]; then
    brew_source="$(classify_path "$brew_command")"
    brew_prefix="$("$brew_command" --prefix 2>/dev/null || print unavailable)"
    [[ "$brew_prefix" == unavailable ]] || brew_prefix="$(classify_path "$brew_prefix")"
  fi

  print -r -- '## Read-only runtime facts'
  print
  print -r -- "- hardware-arm64-capable: $hardware_arm64"
  print -r -- "- collector-process-architecture: $process_arch"
  print -r -- "- rosetta-translated: $translated"
  print -r -- "- brew-source: $brew_source"
  print -r -- "- brew-prefix: $brew_prefix"
  for command_name in zsh brew node npm pnpm bun python3 uv docker rg gh; do
    command_architecture "$command_name"
  done
  print
  print -r -- '- startup-performance: not-measured'
  print -r -- '- startup-files-sourced: no'
  print
}

print_path_summary() {
  local -a entries
  local -A seen
  local entry key
  local total distinct duplicate_excess

  entries=("$@")
  for entry in "${entries[@]}"; do
    key="$entry"
    [[ -n "$key" ]] || key='<empty-entry>'
    seen[$key]=$((${seen[$key]:-0} + 1))
  done

  total=${#entries[@]}
  distinct=${#seen[@]}
  duplicate_excess=$((total - distinct))
  print -r -- "- entries: $total"
  print -r -- "- distinct: $distinct"
  print -r -- "- duplicate-excess: $duplicate_excess"
  for entry in "${entries[@]}"; do
    print -r -- "- path: $(classify_path "$entry")"
  done
}

zsh_marker_counts() {
  local file="$1"
  /usr/bin/awk '
    {
      raw = $0
      active = raw
      sub(/[[:space:]]*#.*/, "", active)

      commented = ""
      if (raw ~ /^[[:space:]]*#/) {
        commented = raw
        sub(/^[[:space:]]*#[[:space:]]*/, "", commented)
      }

      active_lower = tolower(active)
      commented_lower = tolower(commented)

      if (active_lower ~ /\/usr\/local|x86_64|arch[[:space:]]+-x86_64|rosetta/) active_intel++
      if (commented_lower ~ /\/usr\/local|x86_64|arch[[:space:]]+-x86_64|rosetta/) commented_intel++
      if (active_lower ~ /(^|[^[:alnum:]_])compinit([^[:alnum:]_]|$)/) active_compinit_reference++
      if (commented_lower ~ /(^|[^[:alnum:]_])compinit([^[:alnum:]_]|$)/) commented_compinit_reference++
      if (active_lower ~ /(^|[;&|][[:space:]]*)compinit([[:space:]]|$)/) active_compinit_call++
      if (commented_lower ~ /(^|[;&|][[:space:]]*)compinit([[:space:]]|$)/) commented_compinit_call++
      if (active_lower ~ /compdef|bashcompinit|fpath/) active_completion++
      if (active_lower ~ /oh-my-zsh|plugins=|plugin(s)?\//) active_plugin++
    }
    END {
      print active_intel + 0, commented_intel + 0, active_compinit_reference + 0, commented_compinit_reference + 0, active_compinit_call + 0, commented_compinit_call + 0, active_completion + 0, active_plugin + 0
    }
  ' "$file"
}

home_variable_targets() {
  local file="$1"
  local line_number name rhs candidate path_category target_kind

  while IFS=$'\t' read -r line_number name rhs; do
    rhs="${rhs#"${rhs%%[![:space:]]*}"}"
    rhs="${rhs%"${rhs##*[![:space:]]}"}"
    if (( ${#rhs} >= 2 )) \
      && [[ ( "$rhs[1]" == '"' && "$rhs[-1]" == '"' ) \
        || ( "$rhs[1]" == "'" && "$rhs[-1]" == "'" ) ]]; then
      rhs="${rhs[2,-2]}"
    fi

    candidate=''
    path_category='dynamic-or-relative'
    target_kind='unknown'
    case "$rhs" in
      '$HOME/'*)
        candidate="$semantic_home/${rhs#\$HOME/}"
        path_category='$HOME/<redacted>'
        ;;
      '${HOME}/'*)
        candidate="$semantic_home/${rhs#\$\{HOME\}/}"
        path_category='$HOME/<redacted>'
        ;;
      "$semantic_home"|"$semantic_home"/*|/Users/*)
        candidate="$rhs"
        path_category='$HOME/<redacted>'
        ;;
      /usr/*|/opt/homebrew/*|/bin/*|/sbin/*)
        candidate="$rhs"
        path_category='system-prefix'
        ;;
      /*)
        candidate="$rhs"
        path_category='absolute-redacted'
        ;;
    esac

    if [[ -n "$candidate" ]]; then
      if [[ -d "$candidate" ]]; then
        target_kind='directory'
      elif [[ -f "$candidate" || -x "$candidate" ]]; then
        target_kind='file'
      elif [[ -e "$candidate" ]]; then
        target_kind='other'
      else
        target_kind='missing'
      fi
    fi

    print -r -- "- home-variable-target: line $line_number name=$name path-category=$path_category target-kind=$target_kind"
  done < <(
    /usr/bin/awk '
      {
        line = $0
        sub(/[[:space:]]*#.*/, "", line)
        sub(/^[[:space:]]*/, "", line)
        sub(/^export[[:space:]]+/, "", line)
        if (line ~ /^[A-Za-z_][A-Za-z0-9_]*(_HOME|_DIR|_INSTALL)[[:space:]]*=/) {
          name = line
          sub(/[[:space:]]*=.*/, "", name)
          rhs = line
          sub(/^[^=]*=/, "", rhs)
          print NR "\t" name "\t" rhs
        }
      }
    ' "$file"
  )
}

zsh_file_signals() {
  local file="$1"
  /usr/bin/awk '
    function emit(kind, value) {
      if (value != "") print "- " kind ": line " NR " " value
    }
    function secret_like(name, upper) {
      upper = toupper(name)
      return upper ~ /(^|_)(API_?KEY|ACCESS_?KEY|SECRET|TOKEN|PASSWORD|PASSWD|CREDENTIAL)(_|$)/
    }
    function source_category(value, lower) {
      lower = tolower(value)
      if (lower ~ /parameters\.zsh/) return "local-parameters"
      if (lower ~ /oh-my-zsh/) return "oh-my-zsh"
      if (lower ~ /nvm/ && lower ~ /bash_completion/) return "nvm-completion"
      if (lower ~ /nvm\.sh/) return "nvm-runtime"
      if (lower ~ /nvm/) return "nvm"
      if (lower ~ /autojump/) return "autojump"
      if (lower ~ /docker/ && lower ~ /complet/) return "docker-completion"
      if (lower ~ /google-cloud-sdk/ && lower ~ /complet/) return "google-cloud-completion"
      if (lower ~ /google-cloud-sdk/) return "google-cloud-path"
      if (lower ~ /\/usr\/local|x86_64|rosetta/) return "intel-or-legacy"
      if (lower ~ /\/opt\/homebrew/) return "apple-silicon-homebrew"
      if (lower ~ /mise/) return "mise"
      if (lower ~ /pyenv/) return "pyenv"
      if (lower ~ /compinit|completion/) return "completion"
      if (value ~ /[$`{(]/) return "dynamic-or-variable"
      if (value ~ /^\//) return "absolute-path-redacted"
      return "relative-path-redacted"
    }
    {
      raw = $0

      commented_line = raw
      if (commented_line ~ /^[[:space:]]*#[[:space:]]*(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=/) {
        sub(/^[[:space:]]*#[[:space:]]*/, "", commented_line)
        commented_scope = "shell"
        if (commented_line ~ /^export[[:space:]]+/) {
          commented_scope = "exported"
          sub(/^export[[:space:]]+/, "", commented_line)
        }
        commented_name = commented_line
        sub(/[[:space:]]*=.*/, "", commented_name)
        if (secret_like(commented_name)) {
          emit("commented-variable", "name=" commented_name " scope=" commented_scope " secret-like=yes")
        }
      }

      line = raw
      sub(/[[:space:]]*#.*/, "", line)

      if (line ~ /(^|[[:space:];&|])source[[:space:]]+/ \
        || line ~ /(^|[[:space:];&|])[.][[:space:]]+/ \
        || line ~ /(^|[[:space:];&|])[\\][.][[:space:]]+/) {
        emit("source-category", source_category(line))
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
      sub(/^[[:space:]]*/, "", variable_line)
      variable_scope = "shell"
      if (variable_line ~ /^export[[:space:]]+/) {
        variable_scope = "exported"
        sub(/^export[[:space:]]+/, "", variable_line)
      }
      if (variable_line ~ /^[A-Za-z_][A-Za-z0-9_]*=/) {
        variable_name = variable_line
        sub(/=.*/, "", variable_name)
        emit("variable", "name=" variable_name " scope=" variable_scope " secret-like=" (secret_like(variable_name) ? "yes" : "no"))
      }

      if (line ~ /\/Users\//) {
        emit("hardcoded-home", "active=yes")
      }
    }
  ' "$file"

  home_variable_targets "$file"
}

zsh_file_summary() {
  local file="$1"
  local label="$2"
  local kind='missing'
  local target='-'
  local permissions='-'
  local syntax='not-checked'
  local active_intel_hits=0
  local commented_intel_hits=0
  local active_compinit_references=0
  local commented_compinit_references=0
  local active_compinit_calls=0
  local commented_compinit_calls=0
  local active_completion_hits=0
  local active_plugin_hits=0
  local load_context='unknown'
  local -a marker_counts

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
    marker_counts=("${(@s: :)$(zsh_marker_counts "$file")}")
    active_intel_hits="${marker_counts[1]}"
    commented_intel_hits="${marker_counts[2]}"
    active_compinit_references="${marker_counts[3]}"
    commented_compinit_references="${marker_counts[4]}"
    active_compinit_calls="${marker_counts[5]}"
    commented_compinit_calls="${marker_counts[6]}"
    active_completion_hits="${marker_counts[7]}"
    active_plugin_hits="${marker_counts[8]}"
  fi

  print -r -- "### $label" >> "$report"
  print -r -- "- source-input-name: ${file:t}" >> "$report"
  print -r -- "- load-context: $load_context" >> "$report"
  print -r -- "- kind: $kind" >> "$report"
  print -r -- "- permissions: $permissions" >> "$report"
  print -r -- "- symlink-target: $target" >> "$report"
  print -r -- "- syntax: $syntax" >> "$report"
  print -r -- "- intel-markers-active: $active_intel_hits" >> "$report"
  print -r -- "- intel-markers-commented: $commented_intel_hits" >> "$report"
  print -r -- "- compinit-references-active: $active_compinit_references" >> "$report"
  print -r -- "- compinit-references-commented: $commented_compinit_references" >> "$report"
  print -r -- "- compinit-calls-active: $active_compinit_calls" >> "$report"
  print -r -- "- compinit-calls-commented: $commented_compinit_calls" >> "$report"
  print -r -- "- completion-markers-active: $active_completion_hits" >> "$report"
  print -r -- "- plugin-markers-active: $active_plugin_hits" >> "$report"
  if [[ -f "$file" ]]; then
    zsh_file_signals "$file" >> "$report"
  fi
  print >> "$report"
}

safety_check() {
  if grep -Fq "$semantic_home" "$report" \
    || grep -Fq "$startup_root" "$report" \
    || grep -Eq '/Users/[^/[:space:]"'\'']+' "$report" \
    || grep -Eqi '[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}' "$report" \
    || grep -Eqi 'AKIA[[:alnum:]]{16}|sk-[[:alnum:]_-]{20,}|BEGIN (RSA |OPENSSH )?PRIVATE KEY' "$report"; then
    print -u2 -- 'collect-zsh-evidence.zsh: 安全检查失败，本次证据已删除'
    cleanup_report
    exit 1
  fi
}

resolve_startup_paths

if [[ "$preflight_only" == yes ]]; then
  print_preflight
  exit 0
fi

prepare_output

{
  print -r -- '# Stage 0 Zsh evidence'
  print
  print -r -- '- scope: sanitized structural signals and allowlisted read-only runtime facts'
  print -r -- "- source-origin: $source_origin"
  print -r -- "- source-root-category: $source_root_category"
  print -r -- "- selected-files: ${(j:,:)startup_files}"
  print -r -- '- runtime-origin: collector-process'
  print -r -- '- values-and-bodies: not-collected'
  print -r -- '- local-parameters-and-keychain: not-read'
  print -r -- '- interactive-or-login-shell-started: no'
  print
} > "$report"

print_runtime_facts >> "$report"

{
  print -r -- '## Zsh startup files'
  print
} >> "$report"

for startup_file in "${startup_files[@]}"; do
  zsh_file_summary "${startup_paths[$startup_file]}" ".$startup_file"
done

{
  print -r -- '## Inherited command search paths'
  print
  print_path_summary "${(@s/:/)PATH}"
  print
  print -r -- '## Inherited completion search paths'
  print
  print_path_summary "${fpath[@]}"
  print
  print -r -- '## AI analysis handoff'
  print
  print -r -- '- Interpret this evidence with .agents/skills/analyze-zsh-configuration/references/zshrc-diagnostics-guide.md.'
  print -r -- '- Treat unknown source expressions and redacted paths as manual.'
  print -r -- '- Generate recommendations only; do not modify live Zsh files.'
} >> "$report"

safety_check
chmod 600 "$report"
print -r -- 'collect-zsh-evidence.zsh: 完成；请由 Zsh 分析 Skill 审阅 tmp/zsh-evidence.md'
