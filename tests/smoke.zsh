#!/bin/zsh

emulate -LR zsh
setopt NO_UNSET PIPE_FAIL EXTENDED_GLOB NULL_GLOB
umask 077

readonly script_dir="${0:A:h}"
readonly repo_root="${script_dir:h}"
readonly mode="${1:-full}"
typeset -g SMOKE_TEST_ROOT=''

if (( $# > 1 )) || [[ "$mode" != full && "$mode" != --quick ]]; then
  print -u2 -- '用法：./tests/smoke.zsh [--quick]'
  exit 2
fi

fail() {
  print -u2 -- "smoke.zsh: $1"
  exit 1
}

cleanup_smoke() {
  if [[ -n "$SMOKE_TEST_ROOT" && -d "$SMOKE_TEST_ROOT" ]]; then
    command rm -rf -- "$SMOKE_TEST_ROOT"
  fi
}

assert_contains() {
  local file="$1"
  local text="$2"
  if ! grep -Fq -- "$text" "$file"; then
    sed 's/fixture-secret-value/<redacted>/g' "$file" >&2
    fail "缺少预期文本：$text"
  fi
}

assert_absent() {
  local file="$1"
  local text="$2"
  if grep -Fq -- "$text" "$file"; then
    fail "发现禁止文本：$text"
  fi
}

quick_checks() {
  local file output zh_sections en_sections skill_name legacy_term legacy_zh_term
  local -a repository_files shell_files markdown_files public_files plan_gate_files skill_interface_files

  repository_files=("${(@f)$(git -C "$repo_root" ls-files --cached --others --exclude-standard)}")
  (( ${#repository_files} > 0 )) || fail '无法列出仓库文件'

  legacy_term='com''pany'
  legacy_zh_term=$'\u516c\u53f8'
  if [[ "${(L)${(j:\n:)repository_files}}" == *"$legacy_term"* ]] \
    || grep -Eil "$legacy_term|$legacy_zh_term" \
      "${(@)repository_files/#/$repo_root/}" >/dev/null 2>&1; then
    fail '仓库仍包含旧共享层术语'
  fi

  for file in "${repository_files[@]}"; do
    case "$file" in
      *.sh|*.zsh) shell_files+=("$file") ;;
      *.md)
        [[ "$file" == legacy/* ]] || markdown_files+=("$file")
        ;;
    esac
    case "$file" in
      README.md|README.en.md|dump.sh|install.sh|my_setup/*|.githooks/*)
        public_files+=("$file")
        ;;
    esac
    case "$file" in
      .agents/skills/*/SKILL.md) plan_gate_files+=("$file") ;;
      .agents/skills/*/agents/openai.yaml) skill_interface_files+=("$file") ;;
    esac
  done

  for file in "${shell_files[@]}"; do
    /bin/zsh -n "$repo_root/$file" || fail "Zsh 语法失败：$file"
  done
  for file in "${markdown_files[@]}"; do
    if grep -nE '[[:blank:]]+$' "$repo_root/$file" >/dev/null 2>&1; then
      fail "Markdown 存在行尾空白：$file"
    fi
  done

  zh_sections="$(grep -Eo '<!-- section:[a-z-]+ -->' "$repo_root/README.md")"
  en_sections="$(grep -Eo '<!-- section:[a-z-]+ -->' "$repo_root/README.en.md")"
  [[ -n "$zh_sections" && "$zh_sections" == "$en_sections" ]] \
    || fail 'README 中英文 section 结构不一致'
  head -n 8 "$repo_root/README.md" | grep -Fq '(README.en.md)' \
    || fail '默认中文 README 靠前位置缺少英文文档链接'
  head -n 8 "$repo_root/README.en.md" | grep -Fq '(README.md)' \
    || fail '英文 README 靠前位置缺少中文文档链接'

  (( ${#plan_gate_files} > 0 )) || fail '仓库中未发现 Skill'
  plan_gate_files+=(
    '.agents/skills/install-sh-plan.md'
    '.agents/skills/stage-common-contract.md'
  )
  for file in "${plan_gate_files[@]}"; do
    grep -Fq '执行前计划门' "$repo_root/$file" \
      || fail "Skill 缺少执行前计划门：$file"
    grep -Fq '等待用户明确确认' "$repo_root/$file" \
      || fail "Skill 计划门缺少明确确认：$file"
  done

  (( ${#skill_interface_files} > 0 )) || fail '仓库中未发现 Skill UI 元数据'
  for file in "${skill_interface_files[@]}"; do
    skill_name="${file:h:h:t}"
    grep -Fq 'default_prompt:' "$repo_root/$file" \
      || fail "Skill UI 元数据缺少 default_prompt：$file"
    grep -Fq "\$$skill_name" "$repo_root/$file" \
      || fail "Skill 默认提示未引用自身 Skill：$file"
  done

  if grep -En 'AKIA[[:alnum:]]{16}|sk-[[:alnum:]_-]{20,}|BEGIN (RSA |OPENSSH )?PRIVATE KEY' \
    "${(@)public_files/#/$repo_root/}" >/dev/null 2>&1; then
    fail '公开文件命中密钥模式'
  fi
  if grep -Eil 'cutto|shared[.]internal' "${(@)public_files/#/$repo_root/}" >/dev/null 2>&1; then
    fail '公开能力文件命中共享标识'
  fi
  for file in "${public_files[@]}"; do
    [[ "$file" == dump.sh ]] && continue
    if grep -En '/Users/[^/<[:space:]]+' "$repo_root/$file" >/dev/null 2>&1; then
      fail "公开能力文件包含本机绝对 HOME 路径：$file"
    fi
  done
  for file in \
    "$repo_root/my_setup/zsh/zprofile" \
    "$repo_root/my_setup/zsh/zshrc" \
    "$repo_root/my_setup/zsh/.zprofile" \
    "$repo_root/my_setup/zsh/.zshrc"; do
    [[ -e "$file" ]] || continue
    if grep -En '/usr/local|arch[[:space:]]+-x86_64|Rosetta|ZDOTDIR' "$file" >/dev/null 2>&1; then
      fail "最终 Zsh 文件含禁止的 Intel/Rosetta/ZDOTDIR 标记：${file#$repo_root/}"
    fi
  done

  grep -Fq 'tmp/' "$repo_root/.gitignore" || fail 'tmp/ 未被 Git ignore'
  grep -Fq '不读取或分析 Zsh 启动文件' "$repo_root/.agents/skills/install-sh-plan.md" \
    || fail 'install.sh plan 未保留 dump/Zsh 分离边界'

  for file in \
    "$repo_root/my_setup/zsh/install.sh" \
    "$repo_root/my_setup/tooling/install.sh" \
    "$repo_root/my_setup/macos/install.sh"; do
    "$file" >/dev/null 2>&1 && fail "内部模块可被直接执行：${file#$repo_root/}"
  done

  print -- 'smoke.zsh --quick: 通过'
}

write_fake_tools() {
  local bin_dir="$1"

  command mkdir -p -- "$bin_dir"
  {
    print -r -- '#!/bin/zsh'
    print -r -- 'if [[ "$1" == --version ]]; then print -- "Homebrew 9.9.9-test"; exit 0; fi'
    print -r -- 'if [[ "$1" == --prefix ]]; then print -- /opt/homebrew; exit 0; fi'
    print -r -- 'if [[ "$1" == bundle ]]; then'
    print -r -- '  for arg in "$@"; do'
    print -r -- '    if [[ "$arg" == --file=* && "$*" == *" dump "* ]]; then'
    print -r -- '      target="${arg#--file=}"'
    print -r -- '      command mkdir -p -- "${target:h}"'
    print -r -- '      print -r -- '\''brew "ast-grep"'\'' > "$target"'
    print -r -- '    fi'
    print -r -- '  done'
    print -r -- '  exit 0'
    print -r -- 'fi'
    print -r -- 'if [[ "$*" == "list --formula -1" ]]; then print -- ast-grep; exit 0; fi'
    print -r -- 'if [[ "$*" == "list --cask -1" ]]; then exit 0; fi'
    print -r -- 'if [[ "$*" == "services list" ]]; then print -- "Name Status User File"; exit 0; fi'
    print -r -- 'if [[ "$1" == tap || "$1" == leaves ]]; then exit 0; fi'
    print -r -- 'exit 0'
  } > "$bin_dir/brew"

  {
    print -r -- '#!/bin/zsh'
    print -r -- 'if [[ "$1" == --version ]]; then print -- "2026.8.0-test"; fi'
    print -r -- 'exit 0'
  } > "$bin_dir/mise"

  {
    print -r -- '#!/bin/zsh'
    print -r -- 'if [[ "$1" == --version ]]; then print -- "uv 0.11.1-test"; exit 0; fi'
    print -r -- 'if [[ "$*" == *"python list"* ]]; then print -- "cpython-3.14.5-macos-aarch64-none"; fi'
    print -r -- 'exit 0'
  } > "$bin_dir/uv"

  chmod 700 "$bin_dir/brew" "$bin_dir/mise" "$bin_dir/uv"
}

write_fake_intel_brew() {
  local target="$1"
  {
    print -r -- '#!/bin/zsh'
    print -r -- 'case "$*" in'
    print -r -- '  "--prefix") print -- /usr/local ;;'
    print -r -- '  "list --formula -1") print -- ast-grep; print -- unknown-intel ;;'
    print -r -- '  "list --cask -1") print -- unknown-gui ;;'
    print -r -- '  "services list") print -- "Name Status User File" ;;'
    print -r -- '  uninstall*) print -r -- "$*" >> "$HOME/uninstall.log" ;;'
    print -r -- 'esac'
  } > "$target"
  chmod 700 "$target"
}

write_fixture_zsh() {
  local fixture_repo="$1"
  local plugin_revision="$2"
  local naming="${3:-plain}"
  local profile_name='zprofile'
  local rc_name='zshrc'

  if [[ "$naming" == dotted ]]; then
    profile_name='.zprofile'
    rc_name='.zshrc'
  elif [[ "$naming" != plain ]]; then
    fail "未知 Zsh fixture 命名：$naming"
  fi
  command rm -f -- \
    "$fixture_repo/my_setup/zsh/zprofile" \
    "$fixture_repo/my_setup/zsh/zshrc" \
    "$fixture_repo/my_setup/zsh/.zprofile" \
    "$fixture_repo/my_setup/zsh/.zshrc"
  {
    print -r -- '# Apple Silicon login environment.'
    print -r -- 'typeset -U path PATH'
    print -r -- 'path=(/usr/bin /bin /usr/sbin /sbin)'
    print -r -- 'export PATH'
  } > "$fixture_repo/my_setup/zsh/$profile_name"
  {
    print -r -- '# dotfiles: shared'
    print -r -- 'if [[ -n "${DOTFILES_SHARED_DIR:-}" && -r "$DOTFILES_SHARED_DIR/zsh/shared.zsh" ]]; then'
    print -r -- '  source "$DOTFILES_SHARED_DIR/zsh/shared.zsh"'
    print -r -- 'fi'
    print -r -- '# dotfiles: personal'
    print -r -- 'typeset -U path PATH'
    print -r -- '# dotfiles: plugin fixture-plugin'
    print -r -- 'source "$HOME/.local/share/dotfiles/plugins/fixture-plugin/plugin.zsh"'
    print -r -- '# dotfiles: local'
    print -r -- 'if [[ -r "$HOME/.config/dotfiles/local/parameters.zsh" ]]; then'
    print -r -- '  source "$HOME/.config/dotfiles/local/parameters.zsh"'
    print -r -- 'fi'
  } > "$fixture_repo/my_setup/zsh/$rc_name"
  {
    print -r -- '[[plugins]]'
    print -r -- 'name = "fixture-plugin"'
    print -r -- 'source = "https://example.invalid/personal.git"'
    print -r -- "revision = \"$plugin_revision\""
    print -r -- 'enabled = true'
    print -r -- 'load_order = 100'
  } > "$fixture_repo/my_setup/zsh/plugins.toml"
}

seed_fixture_plugin() {
  local fixture_home="$1"
  local plugin_dir="$fixture_home/.local/share/dotfiles/plugins/fixture-plugin"

  command mkdir -p -- "$plugin_dir"
  {
    print -r -- '# fixture plugin'
  } > "$plugin_dir/plugin.zsh"
  git -C "$plugin_dir" init -q
  git -C "$plugin_dir" add plugin.zsh
  git -C "$plugin_dir" \
    -c user.name=fixture \
    -c user.email=fixture@example.invalid \
    commit -q -m fixture
  git -C "$plugin_dir" remote add origin https://example.invalid/personal.git
  git -C "$plugin_dir" rev-parse HEAD
}

write_shared_fixture() {
  local shared_repo="$1"

  command mkdir -p -- \
    "$shared_repo/zsh" \
    "$shared_repo/macos" \
    "$shared_repo/tooling/mise" \
    "$shared_repo/tooling/uv"
  {
    print -r -- '# fixture shared file without secrets'
  } > "$shared_repo/zsh/shared.zsh"
  {
    print -r -- '[[plugins]]'
    print -r -- 'name = "fixture-plugin"'
    print -r -- 'source = "https://example.invalid/shared.git"'
    print -r -- 'revision = "2222222222222222222222222222222222222222"'
    print -r -- 'enabled = true'
    print -r -- 'load_order = 10'
  } > "$shared_repo/zsh/plugins.toml"
  {
    print -r -- 'brew "ast-grep"'
    print -r -- 'brew "gh"'
  } > "$shared_repo/macos/Brewfile"
  {
    print -r -- '[tools]'
    print -r -- 'node = "20.0.0"'
  } > "$shared_repo/tooling/mise/10-shared.toml"
  {
    print -r -- '3.14.5'
  } > "$shared_repo/tooling/uv/.python-versions"
  {
    print -r -- 'python-preference = "only-managed"'
    print -r -- 'python-downloads = "manual"'
  } > "$shared_repo/tooling/uv/uv.toml"
  git -C "$shared_repo" init -q
  git -C "$shared_repo" add .
}

run_full_checks() {
  local test_root fixture_repo fixture_home fixture_bin shared_repo dump_repo dump_home intel_brew
  local output default_output apply_output verify_output retire_output retire_apply_output
  local dotted_output ambiguous_output mixed_output profile_link_before rc_link_before
  local before_status after_status profile_backup_count rc_backup_count home_before home_after
  local plugin_revision

  test_root="$(mktemp -d /private/tmp/dotfiles-smoke.XXXXXX)" || fail '无法创建隔离测试目录'
  SMOKE_TEST_ROOT="$test_root"
  trap cleanup_smoke EXIT HUP INT TERM
  fixture_repo="$test_root/repo"
  fixture_home="$test_root/home"
  fixture_bin="$test_root/bin"
  shared_repo="$test_root/shared"
  intel_brew="$test_root/intel-brew"
  command mkdir -p -- "$fixture_repo" "$fixture_home" "$shared_repo"

  command cp -- "$repo_root/install.sh" "$repo_root/dump.sh" "$repo_root/.gitignore" "$fixture_repo/"
  command cp -R -- "$repo_root/my_setup" "$fixture_repo/"
  command mkdir -p -- "$fixture_repo/.githooks"
  command cp -- "$repo_root/.githooks/pre-commit" "$fixture_repo/.githooks/"
  chmod 700 "$fixture_repo/install.sh" "$fixture_repo/dump.sh" \
    "$fixture_repo/my_setup/zsh/install.sh" \
    "$fixture_repo/my_setup/tooling/install.sh" \
    "$fixture_repo/my_setup/macos/install.sh" \
    "$fixture_repo/.githooks/pre-commit"
  plugin_revision="$(seed_fixture_plugin "$fixture_home")" || fail '无法创建固定 revision 插件 fixture'
  write_fixture_zsh "$fixture_repo" "$plugin_revision" plain
  {
    print -r -- 'brew "ast-grep"'
  } > "$fixture_repo/my_setup/macos/Brewfile"
  git -C "$fixture_repo" init -q
  git -C "$fixture_repo" add .

  write_shared_fixture "$shared_repo"
  write_fake_tools "$fixture_bin"
  write_fake_intel_brew "$intel_brew"

  command mkdir -p -- "$fixture_home/.config/dotfiles/local"
  {
    print -r -- 'export FIXTURE_API_TOKEN="fixture-secret-value"' # gitleaks:allow
  } > "$fixture_home/.config/dotfiles/local/parameters.zsh"
  {
    print -r -- '# dotfiles: generated local integrations v1'
    print -r -- 'case "${DOTFILES_INTEGRATIONS_PHASE:-}" in'
    print -r -- '  zshrc-post) return 0 ;;'
    print -r -- 'esac'
  } > "$fixture_home/.config/dotfiles/local/integrations.zsh"
  chmod 755 "$fixture_home/.config/dotfiles/local"
  chmod 644 "$fixture_home/.config/dotfiles/local/parameters.zsh"
  chmod 644 "$fixture_home/.config/dotfiles/local/integrations.zsh"
  {
    print -r -- '# old rc'
  } > "$fixture_home/.zshrc"
  {
    print -r -- '# original profile target'
  } > "$fixture_home/original-profile"
  command ln -s -- "$fixture_home/original-profile" "$fixture_home/.zprofile"

  default_output="$test_root/default.out"
  (
    cd "$fixture_repo" || exit 1
    HOME="$fixture_home" \
      PATH="$fixture_bin:/usr/bin:/bin" \
      DOTFILES_INSTALL_TEST_MODE=1 \
      DOTFILES_SHARED_DIR="$shared_repo" \
      ./install.sh </dev/null > "$default_output" 2>&1
  ) || fail '默认 N 场景执行失败'
  assert_contains "$default_output" '仓库 Zsh 来源：无前置点（zprofile + zshrc）'
  assert_contains "$default_output" '已取消，未执行任何安装'
  assert_absent "$default_output" 'fixture-secret-value'
  [[ "$(readlink "$fixture_home/.zprofile")" == "$fixture_home/original-profile" ]] \
    || fail '默认 N 改动了旧 .zprofile'
  [[ ! -d "$fixture_home/.config/mise" ]] || fail '默认 N 创建了 tooling 配置'

  apply_output="$test_root/apply.out"
  (
    cd "$fixture_repo" || exit 1
    print -r -- y | HOME="$fixture_home" \
      PATH="$fixture_bin:/usr/bin:/bin" \
      DOTFILES_INSTALL_TEST_MODE=1 \
      DOTFILES_SHARED_DIR="$shared_repo" \
      ./install.sh > "$apply_output" 2>&1
  ) || {
    sed -n '1,280p' "$apply_output" >&2
    fail '隔离安装失败'
  }
  assert_absent "$apply_output" 'fixture-secret-value'
  [[ "$(readlink "$fixture_home/.zprofile")" == "$fixture_repo/my_setup/zsh/zprofile" ]] \
    || fail '.zprofile symlink 错误'
  [[ "$(readlink "$fixture_home/.zshrc")" == "$fixture_repo/my_setup/zsh/zshrc" ]] \
    || fail '.zshrc symlink 错误'
  profile_backup_count=("$fixture_home"/.zprofile.dotfiles-backup.*(N))
  rc_backup_count=("$fixture_home"/.zshrc.dotfiles-backup.*(N))
  (( ${#profile_backup_count} == 1 && ${#rc_backup_count} == 1 )) || fail 'Zsh 入口副本数量错误'
  [[ -L "$profile_backup_count[1]" \
    && "$(readlink "$profile_backup_count[1]")" == "$fixture_home/original-profile" ]] \
    || fail 'symlink 副本未保留目标'
  [[ "$(stat -f '%Lp' "$fixture_home/.config/dotfiles/local")" == 700 ]] \
    || fail 'local 目录权限不是 0700'
  [[ "$(stat -f '%Lp' "$fixture_home/.config/dotfiles/local/parameters.zsh")" == 600 ]] \
    || fail 'parameters.zsh 权限不是 0600'
  [[ "$(stat -f '%Lp' "$fixture_home/.config/dotfiles/local/integrations.zsh")" == 600 ]] \
    || fail 'integrations.zsh 权限不是 0600'
  [[ "$(git -C "$fixture_repo" config --local --get core.hooksPath)" == .githooks ]] \
    || fail '未配置受管 hooksPath'

  profile_backup_count=${#profile_backup_count}
  rc_backup_count=${#rc_backup_count}
  (
    cd "$fixture_repo" || exit 1
    print -r -- y | HOME="$fixture_home" \
      PATH="$fixture_bin:/usr/bin:/bin" \
      DOTFILES_INSTALL_TEST_MODE=1 \
      DOTFILES_SHARED_DIR="$shared_repo" \
      ./install.sh >/dev/null 2>&1
  ) || fail '第二次隔离安装失败'
  local -a profile_backups_after rc_backups_after
  profile_backups_after=("$fixture_home"/.zprofile.dotfiles-backup.*(N))
  rc_backups_after=("$fixture_home"/.zshrc.dotfiles-backup.*(N))
  (( ${#profile_backups_after} == profile_backup_count && ${#rc_backups_after} == rc_backup_count )) \
    || fail '第二次安装重复创建 Zsh 副本'

  verify_output="$test_root/verify.out"
  (
    cd "$fixture_repo" || exit 1
    HOME="$fixture_home" \
      PATH="$fixture_bin:/usr/bin:/bin" \
      DOTFILES_INSTALL_TEST_MODE=1 \
      DOTFILES_SHARED_DIR="$shared_repo" \
      ./install.sh verify > "$verify_output" 2>&1
  ) || {
    sed -n '1,260p' "$verify_output" >&2
    fail '隔离 verify 失败'
  }
  assert_contains "$verify_output" 'install.sh verify: 通过'
  assert_absent "$verify_output" 'fixture-secret-value'

  before_status="$(git -C "$fixture_repo" status --short)"
  retire_output="$test_root/retire.out"
  (
    cd "$fixture_repo" || exit 1
    HOME="$fixture_home" \
      PATH="$fixture_bin:/usr/bin:/bin" \
      DOTFILES_INSTALL_TEST_MODE=1 \
      DOTFILES_SHARED_DIR="$shared_repo" \
      DOTFILES_TEST_INTEL_BREW="$intel_brew" \
      ./install.sh retire > "$retire_output" 2>&1
  ) || {
    sed -n '1,280p' "$retire_output" >&2
    fail 'retire 只读预览失败'
  }
  after_status="$(git -C "$fixture_repo" status --short)"
  [[ "$before_status" == "$after_status" ]] || fail 'retire 预览修改了工作树'
  assert_contains "$retire_output" 'ast-grep：ARM 替代已验证'
  assert_contains "$retire_output" 'unknown-intel：不在已确认 ARM 期望中'
  assert_contains "$retire_output" 'cask:unknown-gui：GUI 应用与数据未知，保留'
  [[ ! -e "$fixture_home/uninstall.log" ]] || fail 'retire 预览执行了卸载'

  retire_apply_output="$test_root/retire-apply.out"
  if (
    cd "$fixture_repo" || exit 1
    HOME="$fixture_home" \
      PATH="$fixture_bin:/usr/bin:/bin" \
      DOTFILES_INSTALL_TEST_MODE=1 \
      DOTFILES_SHARED_DIR="$shared_repo" \
      DOTFILES_TEST_INTEL_BREW="$intel_brew" \
      ./install.sh retire --apply </dev/null > "$retire_apply_output" 2>&1
  ); then
    fail 'retire --apply 在非 TTY 中未阻断'
  fi
  assert_contains "$retire_apply_output" '必须在 stdin/stdout 均为真实 TTY'
  [[ ! -e "$fixture_home/uninstall.log" ]] || fail '非 TTY retire --apply 执行了卸载'

  command mv -- \
    "$fixture_repo/my_setup/zsh/zprofile" \
    "$fixture_repo/my_setup/zsh/.zprofile"
  command mv -- \
    "$fixture_repo/my_setup/zsh/zshrc" \
    "$fixture_repo/my_setup/zsh/.zshrc"
  dotted_output="$test_root/dotted.out"
  (
    cd "$fixture_repo" || exit 1
    print -r -- y | HOME="$fixture_home" \
      PATH="$fixture_bin:/usr/bin:/bin" \
      DOTFILES_INSTALL_TEST_MODE=1 \
      DOTFILES_SHARED_DIR="$shared_repo" \
      ./install.sh > "$dotted_output" 2>&1
  ) || {
    sed -n '1,280p' "$dotted_output" >&2
    fail '有前置点 Zsh 来源安装失败'
  }
  assert_contains "$dotted_output" '仓库 Zsh 来源：有前置点（.zprofile + .zshrc）'
  [[ "$(readlink "$fixture_home/.zprofile")" == "$fixture_repo/my_setup/zsh/.zprofile" ]] \
    || fail '有前置点 .zprofile symlink 错误'
  [[ "$(readlink "$fixture_home/.zshrc")" == "$fixture_repo/my_setup/zsh/.zshrc" ]] \
    || fail '有前置点 .zshrc symlink 错误'

  command cp -p -- \
    "$fixture_repo/my_setup/zsh/.zprofile" \
    "$fixture_repo/my_setup/zsh/zprofile"
  command cp -p -- \
    "$fixture_repo/my_setup/zsh/.zshrc" \
    "$fixture_repo/my_setup/zsh/zshrc"
  profile_link_before="$(readlink "$fixture_home/.zprofile")"
  rc_link_before="$(readlink "$fixture_home/.zshrc")"
  ambiguous_output="$test_root/ambiguous.out"
  if (
    cd "$fixture_repo" || exit 1
    HOME="$fixture_home" \
      PATH="$fixture_bin:/usr/bin:/bin" \
      DOTFILES_INSTALL_TEST_MODE=1 \
      DOTFILES_SHARED_DIR="$shared_repo" \
      ./install.sh </dev/null > "$ambiguous_output" 2>&1
  ); then
    fail '两套完整 Zsh 来源同时存在时未阻断'
  fi
  assert_contains "$ambiguous_output" '同时存在两套完整 Zsh 来源'
  assert_contains "$ambiguous_output" '摘要包含阻断项，未请求确认，也未执行写入'
  [[ "$(readlink "$fixture_home/.zprofile")" == "$profile_link_before" \
    && "$(readlink "$fixture_home/.zshrc")" == "$rc_link_before" ]] \
    || fail '来源歧义场景改动了 HOME Zsh 入口'

  command rm -f -- \
    "$fixture_repo/my_setup/zsh/zprofile" \
    "$fixture_repo/my_setup/zsh/.zshrc"
  mixed_output="$test_root/mixed.out"
  if (
    cd "$fixture_repo" || exit 1
    HOME="$fixture_home" \
      PATH="$fixture_bin:/usr/bin:/bin" \
      DOTFILES_INSTALL_TEST_MODE=1 \
      DOTFILES_SHARED_DIR="$shared_repo" \
      ./install.sh </dev/null > "$mixed_output" 2>&1
  ); then
    fail '混搭 Zsh 来源命名时未阻断'
  fi
  assert_contains "$mixed_output" 'Zsh 来源命名混搭或文件残缺'
  assert_contains "$mixed_output" '摘要包含阻断项，未请求确认，也未执行写入'
  [[ "$(readlink "$fixture_home/.zprofile")" == "$profile_link_before" \
    && "$(readlink "$fixture_home/.zshrc")" == "$rc_link_before" ]] \
    || fail '混搭来源场景改动了 HOME Zsh 入口'

  dump_repo="$test_root/dump-repo"
  dump_home="$test_root/dump-home"
  command mkdir -p -- "$dump_repo" "$dump_home"
  command cp -- "$repo_root/dump.sh" "$repo_root/.gitignore" "$dump_repo/"
  chmod 700 "$dump_repo/dump.sh"
  git -C "$dump_repo" init -q
  command mkdir -p -- "$dump_repo/tmp"
  {
    print -r -- 'unknown-content-must-survive'
  } > "$dump_repo/tmp/keep.me"
  {
    print -r -- 'home-marker'
  } > "$dump_home/marker"
  home_before="$(find "$dump_home" -mindepth 1 -print -exec stat -f '%Sp:%z:%N' {} \; | LC_ALL=C sort)"
  (
    cd "$dump_repo" || exit 1
    HOME="$dump_home" \
      PATH="$fixture_bin:/usr/bin:/bin" \
      DOTFILES_DUMP_TEST_MODE=1 \
      ./dump.sh >/dev/null
  ) || fail 'dump.sh 隔离只读测试失败'
  home_after="$(find "$dump_home" -mindepth 1 -print -exec stat -f '%Sp:%z:%N' {} \; | LC_ALL=C sort)"
  [[ "$home_before" == "$home_after" ]] || fail 'dump.sh 修改了隔离 HOME'
  [[ -f "$dump_repo/tmp/dump.md" ]] || fail 'dump.sh 未生成脱敏报告'
  [[ ! -d "$dump_repo/tmp/.runtime" ]] || fail 'dump.sh 未清理运行时目录'
  assert_contains "$dump_repo/tmp/keep.me" 'unknown-content-must-survive'

  "$repo_root/.agents/skills/analyze-zsh-configuration/scripts/test-collect-zsh-evidence.zsh" \
    >/dev/null || fail 'Zsh 脱敏证据采集测试失败'
  /bin/zsh "$repo_root/.agents/skills/analyze-zsh-configuration/scripts/test-zsh-functional-blocks.zsh" \
    >/dev/null || fail 'Zsh 功能块覆盖比较测试失败'

  print -- 'smoke.zsh: 通过'
}

quick_checks
[[ "$mode" == --quick ]] && exit 0
run_full_checks
