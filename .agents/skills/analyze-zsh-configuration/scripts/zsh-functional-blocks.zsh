#!/bin/zsh

# Inventory and compare installer-managed Zsh blocks without printing their
# bodies, paths, values, or content digests.

emulate -LR zsh
setopt NO_UNSET PIPE_FAIL
umask 077

usage() {
  print -u2 -- '用法：'
  print -u2 -- '  zsh-functional-blocks.zsh inventory --file <path> --logical-file <.zprofile|.zshrc>'
  print -u2 -- '  zsh-functional-blocks.zsh render-local --source-zprofile <path> --source-zshrc <path> --output <new-private-candidate>'
  print -u2 -- '  zsh-functional-blocks.zsh compare --source-zprofile <path> --source-zshrc <path> --target-zprofile <path> --target-zshrc <path> [--integrations <path>] [--allow-retired <logical-file:id#occurrence,...>]'
}

fail() {
  print -u2 -r -- "zsh-functional-blocks.zsh: $1"
  exit 1
}

typeset -ga scan_ids scan_occurrences scan_starts scan_ends scan_phases
typeset -ga scan_relocations scan_contents

marker_id=''
marker_phase=''
marker_relocation=''

classify_marker() {
  local line="$1"
  local logical_file="$2"
  local trimmed lower

  marker_id=''
  marker_phase=''
  marker_relocation=''
  trimmed="${line#"${line%%[![:space:]]*}"}"
  [[ "$trimmed" == \#* ]] || return 1
  lower="${trimmed:l}"

  case "$lower" in
    *'kiro cli pre block'*) marker_id='kiro-cli-pre' ;;
    *'kiro cli post block'*) marker_id='kiro-cli-post' ;;
    *'docker desktop'*'complet'*) marker_id='docker-desktop-completion' ;;
    *'google cloud sdk'*'completion'*|*'completion'*'gcloud'*)
      marker_id='google-cloud-sdk-completion'
      ;;
    *'google cloud sdk'*'path'*|*'path'*'google cloud sdk'*)
      marker_id='google-cloud-sdk-path'
      ;;
    *'kimi-code'*|*'kimi code'*) marker_id='kimi-code' ;;
    *)
      if [[ "$lower" =~ '(added|installed|managed|generated)[[:space:]]+by|keep[[:space:]]+at[[:space:]]+the[[:space:]]+(top|bottom)' ]]; then
        marker_id='unclassified-installer-block'
      else
        return 1
      fi
      ;;
  esac

  if [[ "$logical_file" == '.zprofile' || "$logical_file" == zprofile ]]; then
    if [[ "$marker_id" == 'kiro-cli-pre' || "$lower" == *'keep at the top'* ]]; then
      marker_phase='zprofile-pre'
    else
      marker_phase='zprofile-post'
    fi
  elif [[ "$marker_id" == 'kiro-cli-pre' || "$lower" == *'keep at the top'* ]]; then
    marker_phase='zshrc-pre'
  else
    marker_phase='zshrc-post'
  fi

  if [[ "$marker_id" == 'unclassified-installer-block' ]]; then
    marker_relocation='manual'
  else
    marker_relocation='local-integrations'
  fi
}

block_content() {
  local -a lines
  local start="$2"
  local end="$3"

  lines=("${(@f)$(<"$1")}")
  if (( end < start || ${#lines[@]} == 0 )); then
    print -rn -- ''
    return
  fi
  print -rn -- "${(F)lines[$start,$end]}"
}

scan_file() {
  local file="$1"
  local logical_file="$2"
  local -a lines marker_ids marker_starts marker_phases marker_relocations
  local -A occurrences
  local index line marker_index next_start end_index cursor id occurrence

  scan_ids=()
  scan_occurrences=()
  scan_starts=()
  scan_ends=()
  scan_phases=()
  scan_relocations=()
  scan_contents=()

  [[ -f "$file" ]] || return 0
  lines=("${(@f)$(<"$file")}")
  (( ${#lines[@]} > 0 )) || return 0

  for (( index = 1; index <= ${#lines[@]}; index++ )); do
    line="${lines[$index]}"
    if classify_marker "$line" "$logical_file"; then
      marker_ids+=("$marker_id")
      marker_starts+=("$index")
      marker_phases+=("$marker_phase")
      marker_relocations+=("$marker_relocation")
    fi
  done

  for (( marker_index = 1; marker_index <= ${#marker_ids[@]}; marker_index++ )); do
    if (( marker_index < ${#marker_ids[@]} )); then
      next_start="${marker_starts[$((marker_index + 1))]}"
      end_index=$((next_start - 1))
    else
      end_index=${#lines[@]}
    fi

    for (( cursor = marker_starts[$marker_index] + 1; cursor <= end_index; cursor++ )); do
      if [[ -z "${lines[$cursor]//[[:space:]]/}" ]]; then
        end_index=$((cursor - 1))
        break
      fi
    done

    id="${marker_ids[$marker_index]}"
    occurrence=$((${occurrences[$id]:-0} + 1))
    occurrences[$id]="$occurrence"
    scan_ids+=("$id")
    scan_occurrences+=("$occurrence")
    scan_starts+=("${marker_starts[$marker_index]}")
    scan_ends+=("$end_index")
    scan_phases+=("${marker_phases[$marker_index]}")
    scan_relocations+=("${marker_relocations[$marker_index]}")
    scan_contents+=("$(block_content "$file" "${marker_starts[$marker_index]}" "$end_index")")
  done
}

inventory() {
  local file=''
  local logical_file=''
  local index body_lines

  shift
  while (( $# > 0 )); do
    case "$1" in
      --file)
        (( $# >= 2 )) || fail '--file 缺少参数'
        file="$2"
        shift 2
        ;;
      --logical-file)
        (( $# >= 2 )) || fail '--logical-file 缺少参数'
        logical_file="$2"
        shift 2
        ;;
      *) fail "inventory 不支持参数：$1" ;;
    esac
  done

  [[ -n "$file" && -n "$logical_file" ]] || { usage; exit 1; }
  scan_file "$file" "$logical_file"
  print -r -- "- functional-block-count: ${#scan_ids[@]}"
  for (( index = 1; index <= ${#scan_ids[@]}; index++ )); do
    body_lines=$((scan_ends[$index] - scan_starts[$index]))
    print -r -- "- functional-block: id=${scan_ids[$index]} occurrence=${scan_occurrences[$index]} order=$index phase=${scan_phases[$index]} relocation=${scan_relocations[$index]} start-line=${scan_starts[$index]} end-line=${scan_ends[$index]} body-lines=$body_lines"
  done
}

loader_marker_line() {
  local file="$1"
  local phase="$2"
  /usr/bin/awk -v marker="# dotfiles: local-integrations $phase" '$0 == marker { print NR; exit }' "$file"
}

loader_is_valid() {
  local file="$1"
  local phase="$2"
  local marker_line first_nonblank last_nonblank

  [[ -f "$file" ]] || return 1
  marker_line="$(loader_marker_line "$file" "$phase")"
  [[ -n "$marker_line" ]] || return 1
  grep -Fq -- "DOTFILES_INTEGRATIONS_PHASE=$phase" "$file" || return 1
  grep -Fq -- 'source "$HOME/.config/dotfiles/local/integrations.zsh"' "$file" || return 1

  case "$phase" in
    zprofile-pre|zshrc-pre)
      first_nonblank="$(/usr/bin/awk 'NF { print NR; exit }' "$file")"
      [[ "$marker_line" == "$first_nonblank" ]] || return 1
      ;;
    zprofile-post|zshrc-post)
      last_nonblank="$(/usr/bin/awk 'NF { line=NR } END { print line }' "$file")"
      (( last_nonblank - marker_line <= 6 )) || return 1
      ;;
  esac
}

target_block_position_is_valid() {
  local file="$1"
  local id="$2"
  local phase="$3"
  local start="$4"
  local end="$5"
  local boundary

  if [[ "$phase" == *-pre ]]; then
    boundary="$(/usr/bin/awk 'NF { print NR; exit }' "$file")"
    [[ "$start" == "$boundary" ]]
  elif [[ "$id" == kiro-cli-post ]]; then
    boundary="$(/usr/bin/awk 'NF { line=NR } END { print line }' "$file")"
    [[ "$end" == "$boundary" ]]
  else
    return 0
  fi
}

render_local() {
  local source_zprofile='' source_zshrc='' output=''
  local label file phase index rendered=0 manual=0
  local -a block_files block_starts block_ends block_phases block_relocations

  shift
  while (( $# > 0 )); do
    case "$1" in
      --source-zprofile) source_zprofile="$2"; shift 2 ;;
      --source-zshrc) source_zshrc="$2"; shift 2 ;;
      --output) output="$2"; shift 2 ;;
      *) fail "render-local 不支持参数：$1" ;;
    esac
  done

  [[ -n "$source_zprofile" && -n "$source_zshrc" && -n "$output" ]] \
    || { usage; exit 1; }
  [[ ! -e "$output" && ! -L "$output" ]] || fail 'render-local 拒绝覆盖已有候选'
  [[ -d "${output:h}" && ! -L "${output:h}" ]] || fail '候选父目录必须是已存在的真实目录'
  [[ "$(stat -f '%Lp' "${output:h}" 2>/dev/null || print unknown)" == 700 ]] \
    || fail '候选父目录权限必须为 0700'

  for label file in zprofile "$source_zprofile" zshrc "$source_zshrc"; do
    scan_file "$file" "$label"
    for (( index = 1; index <= ${#scan_ids[@]}; index++ )); do
      if [[ "${scan_relocations[$index]}" == local-integrations ]]; then
        block_files+=("$file")
        block_starts+=("${scan_starts[$index]}")
        block_ends+=("${scan_ends[$index]}")
        block_phases+=("${scan_phases[$index]}")
      else
        (( manual++ ))
      fi
    done
  done

  (( ${#block_files[@]} > 0 )) || fail '没有可迁移到本机 integrations 的功能块'

  {
    print -r -- '# dotfiles: generated local integrations v1'
    print -r -- '# Managed by Stage 1; keep installer blocks byte-for-byte unchanged.'
    print -r -- 'case "${DOTFILES_INTEGRATIONS_PHASE:-}" in'
  } > "$output"
  chmod 600 "$output"

  for phase in zprofile-pre zprofile-post zshrc-pre zshrc-post; do
    if (( ${block_phases[(I)$phase]} == 0 )); then
      continue
    fi
    print -r -- "  $phase)" >> "$output"
    for (( index = 1; index <= ${#block_files[@]}; index++ )); do
      [[ "${block_phases[$index]}" == "$phase" ]] || continue
      /usr/bin/sed -n "${block_starts[$index]},${block_ends[$index]}p" \
        "${block_files[$index]}" >> "$output"
      print >> "$output"
      (( rendered++ ))
    done
    print -r -- '    ;;' >> "$output"
  done
  print -r -- 'esac' >> "$output"

  if ! /bin/zsh -n "$output" >/dev/null 2>&1; then
    command rm -f -- "$output"
    fail '生成的本机 integrations 候选语法失败，候选已删除'
  fi
  print -r -- "- render-local: pass rendered=$rendered manual=$manual"
}

compare_blocks() {
  local source_zprofile='' source_zshrc='' target_zprofile='' target_zshrc=''
  local integrations='' retired_argument=''
  local -a source_ids source_occurrences source_contents source_phases source_labels
  local -a candidate_ids candidate_contents candidate_locations candidate_indices
  local -a candidate_phases candidate_files candidate_starts candidate_ends
  local -A retired used last_order
  local label file index candidate_index match_index='' block_status bucket key
  local source_total covered=0 missing=0 retired_count=0

  shift
  while (( $# > 0 )); do
    case "$1" in
      --source-zprofile) source_zprofile="$2"; shift 2 ;;
      --source-zshrc) source_zshrc="$2"; shift 2 ;;
      --target-zprofile) target_zprofile="$2"; shift 2 ;;
      --target-zshrc) target_zshrc="$2"; shift 2 ;;
      --integrations) integrations="$2"; shift 2 ;;
      --allow-retired) retired_argument="$2"; shift 2 ;;
      *) fail "compare 不支持参数：$1" ;;
    esac
  done

  [[ -n "$source_zprofile" && -n "$source_zshrc" \
    && -n "$target_zprofile" && -n "$target_zshrc" ]] || { usage; exit 1; }

  if [[ -n "$retired_argument" ]]; then
    for key in "${(@s:,:)retired_argument}"; do
      [[ -n "$key" ]] && retired[$key]=yes
    done
  fi

  for label file in zprofile "$source_zprofile" zshrc "$source_zshrc"; do
    scan_file "$file" "$label"
    for (( index = 1; index <= ${#scan_ids[@]}; index++ )); do
      source_ids+=("${scan_ids[$index]}")
      source_occurrences+=("${scan_occurrences[$index]}")
      source_contents+=("${scan_contents[$index]}")
      source_phases+=("${scan_phases[$index]}")
      source_labels+=("$label")
    done
  done

  for label file in zprofile "$target_zprofile" zshrc "$target_zshrc" integrations "$integrations"; do
    [[ -n "$file" ]] || continue
    scan_file "$file" "$label"
    for (( index = 1; index <= ${#scan_ids[@]}; index++ )); do
      candidate_ids+=("${scan_ids[$index]}")
      candidate_contents+=("${scan_contents[$index]}")
      if [[ "$label" == integrations ]]; then
        candidate_locations+=("local-integrations")
      else
        candidate_locations+=("target-$label")
      fi
      candidate_indices+=("$index")
      candidate_phases+=("${scan_phases[$index]}")
      candidate_files+=("$file")
      candidate_starts+=("${scan_starts[$index]}")
      candidate_ends+=("${scan_ends[$index]}")
    done
  done

  source_total=${#source_ids[@]}
  for (( index = 1; index <= source_total; index++ )); do
    key="${source_labels[$index]}:${source_ids[$index]}#${source_occurrences[$index]}"
    block_status='missing'
    match_index=''

    for (( candidate_index = 1; candidate_index <= ${#candidate_ids[@]}; candidate_index++ )); do
      [[ -z "${used[$candidate_index]:-}" ]] || continue
      if [[ "${source_phases[$index]}" == zprofile-* \
        && "${candidate_locations[$candidate_index]}" == target-zshrc ]]; then
        continue
      fi
      if [[ "${source_phases[$index]}" == zshrc-* \
        && "${candidate_locations[$candidate_index]}" == target-zprofile ]]; then
        continue
      fi
      if [[ "${candidate_ids[$candidate_index]}" == "${source_ids[$index]}" \
        && "${candidate_contents[$candidate_index]}" == "${source_contents[$index]}" ]]; then
        match_index="$candidate_index"
        break
      fi
    done

    if [[ -n "$match_index" ]]; then
      used[$match_index]=yes
      if [[ "${candidate_locations[$match_index]}" == local-integrations ]]; then
        if [[ "${source_phases[$index]}" == zprofile-* ]]; then
          file="$target_zprofile"
        else
          file="$target_zshrc"
        fi
        if loader_is_valid "$file" "${source_phases[$index]}"; then
          block_status='migrated-local'
        else
          block_status='missing-loader'
        fi
      else
        if [[ "${candidate_phases[$match_index]}" != "${source_phases[$index]}" ]] \
          || ! target_block_position_is_valid \
            "${candidate_files[$match_index]}" \
            "${source_ids[$index]}" \
            "${source_phases[$index]}" \
            "${candidate_starts[$match_index]}" \
            "${candidate_ends[$match_index]}"; then
          block_status='phase-changed'
        else
          block_status='preserved-target'
        fi
      fi

      if [[ "$block_status" != missing-loader ]]; then
        bucket="${candidate_locations[$match_index]}:${source_phases[$index]}"
        if (( ${candidate_indices[$match_index]} < ${last_order[$bucket]:-0} )); then
          block_status='order-changed'
        else
          last_order[$bucket]="${candidate_indices[$match_index]}"
        fi
      fi
    elif [[ -n "${retired[$key]:-}" ]]; then
      block_status='approved-retired'
    else
      for (( candidate_index = 1; candidate_index <= ${#candidate_ids[@]}; candidate_index++ )); do
        if [[ "${candidate_ids[$candidate_index]}" == "${source_ids[$index]}" \
          && "${candidate_contents[$candidate_index]}" == "${source_contents[$index]}" ]]; then
          block_status='phase-changed'
          break
        elif [[ "${candidate_ids[$candidate_index]}" == "${source_ids[$index]}" ]]; then
          block_status='content-changed'
        fi
      done
    fi

    case "$block_status" in
      preserved-target|migrated-local)
        (( covered++ ))
        ;;
      approved-retired)
        (( retired_count++ ))
        ;;
      *)
        (( missing++ ))
        ;;
    esac
    print -r -- "- coverage-item: source=${source_labels[$index]} id=${source_ids[$index]} occurrence=${source_occurrences[$index]} phase=${source_phases[$index]} status=$block_status"
  done

  print -r -- "- functional-block-coverage: source=$source_total covered=$covered missing=$missing retired=$retired_count"
  if (( missing == 0 )); then
    print -r -- '- coverage: pass'
    return 0
  fi
  print -r -- '- coverage: fail'
  return 2
}

(( $# > 0 )) || { usage; exit 1; }
case "$1" in
  inventory) inventory "$@" ;;
  render-local) render_local "$@" ;;
  compare) compare_blocks "$@" ;;
  --help|-h) usage ;;
  *) usage; exit 1 ;;
esac
