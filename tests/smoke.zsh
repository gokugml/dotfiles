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
  if grep -En '^[[:space:]]*local .*([[:space:]]|^)path([=[:space:]]|$)' \
    "$repo_root/my_setup/macos/install.sh" \
    "$repo_root/my_setup/tooling/install.sh" \
    "$repo_root/my_setup/zsh/install.sh" >/dev/null 2>&1; then
    fail '安装模块不得声明会覆盖 PATH 的 Zsh 特殊参数 path'
  fi
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
    if grep -En 'arch[[:space:]]+-x86_64|Rosetta fallback|ZDOTDIR' "$file" >/dev/null 2>&1; then
      fail "最终 Zsh 文件含禁止的 Rosetta fallback/ZDOTDIR 标记：${file#$repo_root/}"
    fi
  done
  grep -Fq 'hw.optional.arm64' "$repo_root/my_setup/zsh/zprofile" \
    || fail '可移植 zprofile 未按原生硬件选择 Homebrew'
  grep -Fq '/opt/homebrew' "$repo_root/my_setup/zsh/zprofile" \
    || fail '可移植 zprofile 缺少 Apple Silicon 原生前缀'
  grep -Fq '/usr/local' "$repo_root/my_setup/zsh/zprofile" \
    || fail '可移植 zprofile 缺少 Intel 原生前缀'
  grep -Fq '不依赖 Stage 0、Stage 1、`zsh-repair-plan.md`' \
    "$repo_root/.agents/skills/stage-2-target-machine-configuration-and-software-migration/SKILL.md" \
    || fail 'Stage 2 Skill 仍未声明独立 checkout 输入'

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
  local brew_prefix="${2:-/opt/homebrew}"

  command mkdir -p -- "$bin_dir"
  {
    print -r -- '#!/bin/zsh'
    print -r -- 'if [[ "$1" == --version ]]; then print -- "Homebrew 9.9.9-test"; exit 0; fi'
    print -r -- "if [[ \"\$1\" == --prefix ]]; then print -- $brew_prefix; exit 0; fi"
    print -r -- 'if [[ "$1" == bundle ]]; then'
    print -r -- '  for arg in "$@"; do'
    print -r -- '    if [[ "$arg" == --file=* ]]; then'
    print -r -- '      target="${arg#--file=}"'
    print -r -- '      if [[ "$*" == *" dump "* ]]; then'
    print -r -- '        command mkdir -p -- "${target:h}"'
    print -r -- '        print -r -- '\''brew "ast-grep"'\'' > "$target"'
    print -r -- '      elif [[ -f "$target" ]] && grep -Fq -- '\''#'\'' "$target"; then'
    print -r -- '        print -u2 -- "effective Brewfile 不得保留说明注释"'
    print -r -- '        exit 65'
    print -r -- '      fi'
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
    print -r -- 'if [[ "$*" == *" where node@"* ]]; then print -r -- "$DOTFILES_TEST_MISE_NODE_PREFIX"; exit 0; fi'
    print -r -- 'if [[ "$*" == *" exec node@"*" -- npm install --global "* ]]; then'
    print -r -- '  prefix="$DOTFILES_TEST_MISE_NODE_PREFIX"'
    print -r -- '  command mkdir -p -- "$prefix/lib/node_modules" "$prefix/bin"'
    print -r -- '  typeset after_global=0 spec package package_dir binary'
    print -r -- '  for spec in "$@"; do'
    print -r -- '    if (( ! after_global )); then [[ "$spec" == --global ]] && after_global=1; continue; fi'
    print -r -- '    package="${spec%@latest}"'
    print -r -- '    package_dir="$prefix/lib/node_modules/$package"'
    print -r -- '    case "$package" in'
    print -r -- '      @google/gemini-cli) binary=gemini ;;'
    print -r -- '      @openai/codex) binary=codex ;;'
    print -r -- '      agent-browser) binary=agent-browser ;;'
    print -r -- '      playwright) binary=playwright ;;'
    print -r -- '      *) exit 64 ;;'
    print -r -- '    esac'
    print -r -- '    command mkdir -p -- "$package_dir"'
    print -r -- '    print -r -- "{\"name\":\"$package\",\"version\":\"99.0.0\",\"bin\":{\"$binary\":\"bin/$binary\"}}" > "$package_dir/package.json"'
    print -r -- '    print -r -- "#!/bin/zsh\nexit 0" > "$prefix/bin/$binary"'
    print -r -- '    chmod 700 "$prefix/bin/$binary"'
    print -r -- '  done'
    print -r -- '  exit 0'
    print -r -- 'fi'
    print -r -- 'if [[ "$*" == *" exec node@"*" -- node -e "* ]]; then exit 0; fi'
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

write_fixture_git() {
  local bin_dir="$1"
  local plugin_remote="$2"
  {
    print -r -- '#!/bin/zsh'
    print -r -- 'if [[ "$1" == clone ]]; then'
    print -r -- '  source_url="${@[-2]}"'
    print -r -- '  target="${@[-1]}"'
    print -r -- '  GIT_CONFIG_COUNT=2 \'
    print -r -- "    GIT_CONFIG_KEY_0='url.file://$plugin_remote.insteadOf' \\"
    print -r -- "    GIT_CONFIG_VALUE_0='https://example.invalid/personal.git' \\"
    print -r -- "    GIT_CONFIG_KEY_1='protocol.file.allow' \\"
    print -r -- "    GIT_CONFIG_VALUE_1='always' \\"
    print -r -- '    /usr/bin/git "$@" || exit 1'
    print -r -- '  /usr/bin/git -C "$target" remote set-url origin "$source_url"'
    print -r -- '  exit $?'
    print -r -- 'fi'
    print -r -- 'exec /usr/bin/git "$@"'
  } > "$bin_dir/git"
  chmod 700 "$bin_dir/git"
}

write_fake_intel_brew() {
  local target="$1"
  {
    print -r -- '#!/bin/zsh'
    print -r -- 'case "$*" in'
    print -r -- '  "--prefix") print -- /usr/local ;;'
    print -r -- '  "--prefix ast-grep") print -- /usr/local/opt/ast-grep ;;'
    print -r -- '  "--prefix unknown-intel") print -- /usr/local/opt/unknown-intel ;;'
    print -r -- '  "list --formula -1") print -- ast-grep; print -- unknown-intel ;;'
    print -r -- '  "list --versions --formula") print -- "ast-grep 1.0.0"; print -- "unknown-intel 2.0.0" ;;'
    print -r -- '  "list --cask -1") print -- unknown-gui ;;'
    print -r -- '  "list --versions --cask") print -- "unknown-gui 3.0.0" ;;'
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
    print -r -- '# dotfiles: local-regression-before-shared'
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
  local plugin_remote
  local output default_output apply_output verify_output handoff_output retire_output retire_apply_output
  local dotted_output ambiguous_output mixed_output profile_link_before rc_link_before
  local before_status after_status profile_backup_count rc_backup_count home_before home_after
  local plugin_revision handoff_file handoff_before handoff_after handoff_backup foreign_output cleanup_output
  local repo_state_output symlink_state_output external_state_dir
  local minimal_repo minimal_home minimal_bin minimal_output intel_home intel_bin intel_output
  local selective_home selective_prefix selective_output
  local invalid_skip_home invalid_skip_output declaration_backup
  local invalid_brew_output invalid_brew_backup
  local rosetta_home rosetta_output
  local hook_repo hook_custom_repo hook_output hook_target hook_before hook_after hook_conflict_output
  local hook_custom_output

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
  chmod 700 "$fixture_repo/install.sh" "$fixture_repo/dump.sh" \
    "$fixture_repo/my_setup/zsh/install.sh" \
    "$fixture_repo/my_setup/tooling/install.sh" \
    "$fixture_repo/my_setup/macos/install.sh"
  plugin_revision="$(seed_fixture_plugin "$fixture_home")" || fail '无法创建固定 revision 插件 fixture'
  plugin_remote="$test_root/plugin-remote.git"
  git clone --bare -- "$fixture_home/.local/share/dotfiles/plugins/fixture-plugin" \
    "$plugin_remote" >/dev/null 2>&1 || fail '无法创建插件远端 fixture'
  command rm -rf -- "$fixture_home/.local/share/dotfiles/plugins/fixture-plugin"
  write_fixture_zsh "$fixture_repo" "$plugin_revision" plain
  {
    print -r -- 'brew "ast-grep" # 提供 AST 结构化代码搜索与重构'
  } > "$fixture_repo/my_setup/macos/Brewfile"
  git -C "$fixture_repo" init -q
  git -C "$fixture_repo" add .

  write_shared_fixture "$shared_repo"
  write_fake_tools "$fixture_bin"
  write_fixture_git "$fixture_bin" "$plugin_remote"
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
  ) || {
    sed -n '1,280p' "$default_output" >&2
    fail '默认 N 场景执行失败'
  }
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
      DOTFILES_GLOBAL_CLI_SELECTION=all \
      DOTFILES_TEST_MISE_NODE_PREFIX="$fixture_home/.local/share/mise/installs/node/24.14.1" \
      DOTFILES_SHARED_DIR="$shared_repo" \
      ./install.sh > "$apply_output" 2>&1
  ) || {
    sed -n '1,280p' "$apply_output" >&2
    fail '隔离安装失败'
  }
  assert_absent "$apply_output" 'fixture-secret-value'
  assert_absent "$apply_output" 'parameter not set'
  assert_contains "$apply_output" '[可选全局 CLI 迁移]'
  assert_contains "$apply_output" 'npm via mise node@24.14.1 → @google/gemini-cli@latest'
  assert_contains "$apply_output" '✓ 可选全局 CLI 已安装到 mise Node npm prefix'
  [[ -x "$fixture_home/.local/share/mise/installs/node/24.14.1/bin/gemini" ]] \
    || fail 'Gemini 未安装到 mise Node prefix'
  [[ -x "$fixture_home/.local/share/mise/installs/node/24.14.1/bin/codex" ]] \
    || fail 'Codex 未安装到 mise Node prefix'
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
  [[ -z "$(git -C "$fixture_repo" config --get core.hooksPath 2>/dev/null)" ]] \
    || fail 'Stage 2 意外配置了 core.hooksPath'
  [[ ! -e "$fixture_repo/.git/hooks/pre-commit" ]] \
    || fail 'Stage 2 意外安装了默认 pre-commit hook'
  [[ "$(git -C "$fixture_home/.local/share/dotfiles/plugins/fixture-plugin" rev-parse HEAD)" \
    == "$plugin_revision" ]] || fail '首次 clone 未固定到声明 revision'
  [[ "$(git -C "$fixture_home/.local/share/dotfiles/plugins/fixture-plugin" remote get-url origin)" \
    == 'https://example.invalid/personal.git' ]] || fail '首次 clone 改写了声明 origin'
  [[ -z "$(git -C "$fixture_home/.local/share/dotfiles/plugins/fixture-plugin" status --porcelain)" ]] \
    || fail '首次 clone 固定 revision 后工作树不干净'

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

  handoff_file="$fixture_home/.local/state/dotfiles/intel_to_be_retired.tsv"
  handoff_output="$test_root/handoff.out"
  (
    cd "$fixture_repo" || exit 1
    HOME="$fixture_home" \
      PATH="$fixture_bin:/usr/bin:/bin" \
      DOTFILES_INSTALL_TEST_MODE=1 \
      DOTFILES_SHARED_DIR="$shared_repo" \
      DOTFILES_TEST_INTEL_BREW="$intel_brew" \
      ./install.sh verify > "$handoff_output" 2>&1
  ) || {
    sed -n '1,300p' "$handoff_output" >&2
    fail 'Intel 退役交接 verify 失败'
  }
  assert_contains "$handoff_output" 'A. 安装完整性：通过'
  assert_contains "$handoff_output" 'B. Intel 退役交接：通过'
  [[ -f "$handoff_file" && ! -L "$handoff_file" ]] || fail '未生成受管 Intel 退役交接文件'
  [[ "$(stat -f '%Lp' "${handoff_file:h}")" == 700 ]] || fail 'Intel 交接父目录权限不是 0700'
  [[ "$(stat -f '%Lp' "$handoff_file")" == 600 ]] || fail 'Intel 交接文件权限不是 0600'
  [[ "$(sed -n '1p' "$handoff_file")" == '# dotfiles-intel-retirement-handoff-v1' ]] \
    || fail 'Intel 交接文件缺少固定标记'
  [[ "$(sed -n '2p' "$handoff_file")" == $'kind\tmanager\tname\tversion\tpath\tarchitecture\treason' ]] \
    || fail 'Intel 交接 TSV schema 错误'
  grep -Fq $'formula\thomebrew\tast-grep\t1.0.0\t/usr/local/opt/ast-grep' "$handoff_file" \
    || {
      sed -n '1,80p' "$handoff_file" >&2
      fail 'Intel 交接缺少精确 formula 项'
    }
  grep -Fq $'cask\thomebrew\tunknown-gui\t3.0.0\t/usr/local/Caskroom/unknown-gui' "$handoff_file" \
    || fail 'Intel 交接缺少保留 cask 项'
  assert_absent "$handoff_file" 'fixture-secret-value'
  handoff_before="$(cksum "$handoff_file")"
  (
    cd "$fixture_repo" || exit 1
    HOME="$fixture_home" PATH="$fixture_bin:/usr/bin:/bin" \
      DOTFILES_INSTALL_TEST_MODE=1 DOTFILES_SHARED_DIR="$shared_repo" \
      DOTFILES_TEST_INTEL_BREW="$intel_brew" ./install.sh verify >/dev/null 2>&1
  ) || fail 'Intel 交接第二次 verify 失败'
  handoff_after="$(cksum "$handoff_file")"
  [[ "$handoff_before" == "$handoff_after" ]] || fail 'Intel 交接文件不是确定性稳定输出'

  repo_state_output="$test_root/repo-state.out"
  if (
    cd "$fixture_repo" || exit 1
    HOME="$fixture_home" PATH="$fixture_bin:/usr/bin:/bin" \
      XDG_STATE_HOME="$fixture_repo/.forbidden-state" \
      DOTFILES_INSTALL_TEST_MODE=1 DOTFILES_SHARED_DIR="$shared_repo" \
      DOTFILES_TEST_INTEL_BREW="$intel_brew" ./install.sh verify > "$repo_state_output" 2>&1
  ); then
    fail '安装器允许把 Intel 交接状态写入 public checkout'
  fi
  assert_contains "$repo_state_output" '状态目录不得位于 public checkout 内'
  [[ ! -e "$fixture_repo/.forbidden-state/dotfiles/intel_to_be_retired.tsv" ]] \
    || fail '阻断后仍在 public checkout 写入了 Intel 交接文件'

  handoff_backup="$test_root/known-handoff.tsv"
  command cp -p -- "$handoff_file" "$handoff_backup"
  print -r -- 'foreign-state-must-not-be-overwritten' > "$handoff_file"
  foreign_output="$test_root/foreign-handoff.out"
  if (
    cd "$fixture_repo" || exit 1
    HOME="$fixture_home" PATH="$fixture_bin:/usr/bin:/bin" \
      DOTFILES_INSTALL_TEST_MODE=1 DOTFILES_SHARED_DIR="$shared_repo" \
      DOTFILES_TEST_INTEL_BREW="$intel_brew" ./install.sh verify > "$foreign_output" 2>&1
  ); then
    fail '安装器覆盖了未知同名 Intel 交接文件'
  fi
  assert_contains "$foreign_output" '同名状态文件不属于安装器'
  command mv -f -- "$handoff_backup" "$handoff_file"

  cleanup_output="$test_root/handoff-cleanup.out"
  (
    cd "$fixture_repo" || exit 1
    HOME="$fixture_home" PATH="$fixture_bin:/usr/bin:/bin" \
      DOTFILES_INSTALL_TEST_MODE=1 DOTFILES_SHARED_DIR="$shared_repo" \
      ./install.sh verify > "$cleanup_output" 2>&1
  ) || fail '无 Intel 残留清理 verify 失败'
  [[ ! -e "$handoff_file" ]] || fail '无 Intel 残留时保留了旧交接文件'

  external_state_dir="$test_root/external-state"
  command mkdir -p -- "$external_state_dir"
  {
    print -r -- '# dotfiles-intel-retirement-handoff-v1'
    print -r -- $'kind\tmanager\tname\tversion\tpath\tarchitecture\treason'
  } > "$external_state_dir/intel_to_be_retired.tsv"
  command rmdir -- "${handoff_file:h}"
  command ln -s -- "$external_state_dir" "${handoff_file:h}"
  symlink_state_output="$test_root/symlink-state.out"
  if (
    cd "$fixture_repo" || exit 1
    HOME="$fixture_home" PATH="$fixture_bin:/usr/bin:/bin" \
      DOTFILES_INSTALL_TEST_MODE=1 DOTFILES_SHARED_DIR="$shared_repo" \
      ./install.sh verify > "$symlink_state_output" 2>&1
  ); then
    fail '安装器允许通过 symlink 状态目录清理 Intel 交接文件'
  fi
  assert_contains "$symlink_state_output" '状态目录不得是 symlink'
  [[ -f "$external_state_dir/intel_to_be_retired.tsv" ]] \
    || fail '安装器通过 symlink 状态目录删除了外部文件'
  command rm -f -- "${handoff_file:h}"
  command mkdir -p -- "${handoff_file:h}"

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

  minimal_repo="$test_root/minimal-repo"
  minimal_home="$test_root/minimal-home"
  minimal_bin="$test_root/minimal-bin"
  command mkdir -p -- "$minimal_repo/my_setup" "$minimal_home"
  command cp -- "$repo_root/install.sh" "$minimal_repo/"
  command cp -R -- "$repo_root/my_setup/macos" "$repo_root/my_setup/tooling" "$minimal_repo/my_setup/"
  chmod 700 "$minimal_repo/install.sh" \
    "$minimal_repo/my_setup/macos/install.sh" "$minimal_repo/my_setup/tooling/install.sh"
  {
    print -r -- 'brew "ast-grep" # 提供 AST 结构化代码搜索与重构'
    print -r -- 'brew "mise" # 管理固定版本 runtime'
    print -r -- 'brew "uv" # 管理 Python runtime'
    print -r -- 'cask "rectangle" # 使用快捷键管理窗口布局'
  } > "$minimal_repo/my_setup/macos/Brewfile"
  git -C "$minimal_repo" init -q
  git -C "$minimal_repo" add .
  write_fake_tools "$minimal_bin" /opt/homebrew

  minimal_output="$test_root/minimal-install.out"
  (
    cd "$minimal_repo" || exit 1
    print -r -- y | HOME="$minimal_home" PATH="$minimal_bin:/usr/bin:/bin" \
      DOTFILES_INSTALL_TEST_MODE=1 DOTFILES_TEST_NATIVE_ARCH=arm64 \
      DOTFILES_TEST_PROCESS_ARCH=arm64 ./install.sh > "$minimal_output" 2>&1
  ) || {
    sed -n '1,320p' "$minimal_output" >&2
    fail 'macOS+tooling 最小 checkout 安装失败'
  }
  assert_contains "$minimal_output" '模块：macOS=启用，tooling=启用，Zsh=未checkout'
  assert_contains "$minimal_output" '未 checkout，跳过 Zsh、plugin 与 HOME Zsh 入口'
  assert_contains "$minimal_output" 'A. 安装完整性：通过'
  assert_contains "$minimal_output" 'B. Intel 退役交接：通过'
  [[ -L "$minimal_home/.config/mise/conf.d/20-dotfiles-10-public.toml" ]] \
    || fail '最小 checkout 未建立 mise 配置 symlink'
  [[ -L "$minimal_home/.config/uv/uv.toml" ]] \
    || fail '最小 checkout 未建立 uv 配置 symlink'
  [[ ! -e "$minimal_home/.zprofile" && ! -e "$minimal_home/.zshrc" ]] \
    || fail '最小 checkout 意外创建 Zsh 入口'
  [[ ! -e "$minimal_home/.config/dotfiles/local" ]] \
    || fail '最小 checkout 意外创建 local Zsh 目录'
  [[ -z "$(git -C "$minimal_repo" config --get core.hooksPath 2>/dev/null)" ]] \
    || fail '最小 Stage 2 意外配置了 core.hooksPath'
  [[ ! -e "$minimal_home/.local/state/dotfiles/intel_to_be_retired.tsv" ]] \
    || fail '无 Intel 残留的最小 checkout 生成了交接文件'

  invalid_brew_output="$test_root/invalid-brew.out"
  invalid_brew_backup="$test_root/minimal-Brewfile"
  command cp -- "$minimal_repo/my_setup/macos/Brewfile" "$invalid_brew_backup"
  print -r -- 'brew "tree", restart_service: true # 不得执行动态参数' \
    >> "$minimal_repo/my_setup/macos/Brewfile"
  if (
    cd "$minimal_repo" || exit 1
    HOME="$minimal_home" PATH="$minimal_bin:/usr/bin:/bin" \
      DOTFILES_INSTALL_TEST_MODE=1 DOTFILES_TEST_NATIVE_ARCH=arm64 \
      DOTFILES_TEST_PROCESS_ARCH=arm64 ./install.sh </dev/null > "$invalid_brew_output" 2>&1
  ); then
    fail '带参数的 Brewfile 声明未在写入前阻断'
  fi
  command mv -f -- "$invalid_brew_backup" "$minimal_repo/my_setup/macos/Brewfile"
  assert_contains "$invalid_brew_output" 'Brewfile 不执行带参数或动态 Ruby 的声明'
  assert_contains "$invalid_brew_output" '摘要包含阻断项，未请求确认，也未执行写入'

  selective_home="$test_root/selective-home"
  selective_prefix="$selective_home/.local/share/mise/installs/node/24.14.1"
  selective_output="$test_root/selective-install.out"
  command mkdir -p -- "$selective_home"
  (
    cd "$minimal_repo" || exit 1
    print -r -- y | HOME="$selective_home" PATH="$minimal_bin:/usr/bin:/bin" \
      DOTFILES_INSTALL_TEST_MODE=1 DOTFILES_TEST_NATIVE_ARCH=arm64 \
      DOTFILES_TEST_PROCESS_ARCH=arm64 \
      DOTFILES_GLOBAL_CLI_SELECTION='@openai/codex,playwright' \
      DOTFILES_TEST_MISE_NODE_PREFIX="$selective_prefix" \
      ./install.sh > "$selective_output" 2>&1
  ) || {
    sed -n '1,320p' "$selective_output" >&2
    fail '可选全局 CLI 逐项选择安装失败'
  }
  assert_contains "$selective_output" '本机选择：2 / 4 项'
  assert_absent "$selective_output" 'parameter not set'
  [[ -x "$selective_prefix/bin/codex" && -x "$selective_prefix/bin/playwright" ]] \
    || fail '逐项选择的 CLI 未安装到 mise Node prefix'
  [[ ! -e "$selective_prefix/bin/gemini" && ! -e "$selective_prefix/bin/agent-browser" ]] \
    || fail '逐项选择意外安装了未选 CLI'

  invalid_skip_home="$test_root/invalid-skip-home"
  invalid_skip_output="$test_root/invalid-skip.out"
  declaration_backup="$test_root/global-cli-migration.toml"
  command mkdir -p -- "$invalid_skip_home"
  command cp -- "$minimal_repo/my_setup/tooling/global-cli-migration.toml" "$declaration_backup"
  print -r -- 'unexpected = "blocked"' >> "$minimal_repo/my_setup/tooling/global-cli-migration.toml"
  (
    cd "$minimal_repo" || exit 1
    print -r -- y | HOME="$invalid_skip_home" PATH="$minimal_bin:/usr/bin:/bin" \
      DOTFILES_INSTALL_TEST_MODE=1 DOTFILES_TEST_NATIVE_ARCH=arm64 \
      DOTFILES_TEST_PROCESS_ARCH=arm64 DOTFILES_GLOBAL_CLI_SELECTION=skip \
      ./install.sh > "$invalid_skip_output" 2>&1
  )
  local invalid_skip_status=$?
  command mv -f -- "$declaration_backup" "$minimal_repo/my_setup/tooling/global-cli-migration.toml"
  (( invalid_skip_status == 0 )) || {
    sed -n '1,320p' "$invalid_skip_output" >&2
    fail '无效可选声明在本机 skip 时阻断了基础 Stage 2'
  }
  assert_contains "$invalid_skip_output" '声明无效；本机已选择 skip，仅跳过可选全局 CLI'

  intel_home="$test_root/intel-home"
  intel_bin="$test_root/intel-bin"
  command mkdir -p -- "$intel_home"
  write_fake_tools "$intel_bin" /usr/local
  intel_output="$test_root/intel-install.out"
  (
    cd "$minimal_repo" || exit 1
    print -r -- y | HOME="$intel_home" PATH="$intel_bin:/usr/bin:/bin" \
      DOTFILES_INSTALL_TEST_MODE=1 DOTFILES_TEST_NATIVE_ARCH=x86_64 \
      DOTFILES_TEST_PROCESS_ARCH=x86_64 ./install.sh > "$intel_output" 2>&1
  ) || {
    sed -n '1,320p' "$intel_output" >&2
    fail 'Intel 原生目标隔离安装失败'
  }
  assert_contains "$intel_output" '/usr/local/bin/brew（prefix /usr/local）'
  assert_contains "$intel_output" 'target：/usr/local/Cellar/ast-grep'
  assert_contains "$intel_output" 'Intel Mac：不生成 Intel 退役交接，Stage 3 不适用'
  assert_contains "$intel_output" 'install.sh verify: 通过'
  [[ ! -e "$intel_home/.local/state/dotfiles/intel_to_be_retired.tsv" ]] \
    || fail 'Intel Mac 生成了 Intel 退役交接文件'

  rosetta_home="$test_root/rosetta-home"
  command mkdir -p -- "$rosetta_home"
  rosetta_output="$test_root/rosetta.out"
  if (
    cd "$minimal_repo" || exit 1
    HOME="$rosetta_home" PATH="$minimal_bin:/usr/bin:/bin" \
      DOTFILES_INSTALL_TEST_MODE=1 DOTFILES_TEST_NATIVE_ARCH=arm64 \
      DOTFILES_TEST_PROCESS_ARCH=x86_64 DOTFILES_TEST_TRANSLATED=1 \
      ./install.sh </dev/null > "$rosetta_output" 2>&1
  ); then
    fail 'Apple Silicon Rosetta 会话未在写入前阻断'
  fi
  assert_contains "$rosetta_output" '必须从原生 arm64 会话运行'
  assert_contains "$rosetta_output" '摘要包含阻断项，未请求确认，也未执行写入'
  [[ ! -e "$rosetta_home/.config/mise" ]] || fail 'Rosetta 阻断后仍写入 tooling'

  hook_repo="$test_root/hook-repo"
  hook_output="$test_root/hook-install.out"
  command mkdir -p -- "$hook_repo/.githooks"
  command cp -- "$repo_root/.githooks/install.sh" "$repo_root/.githooks/pre-commit" \
    "$hook_repo/.githooks/"
  chmod 700 "$hook_repo/.githooks/install.sh" "$hook_repo/.githooks/pre-commit"
  git -C "$hook_repo" init -q
  (
    cd "$hook_repo" || exit 1
    PATH="$fixture_bin:/usr/bin:/bin" ./.githooks/install.sh > "$hook_output" 2>&1
  ) || {
    sed -n '1,160p' "$hook_output" >&2
    fail '一次性默认 Git hook 安装失败'
  }
  hook_target="$hook_repo/.git/hooks/pre-commit"
  [[ -f "$hook_target" && ! -L "$hook_target" && -x "$hook_target" ]] \
    || fail '一次性命令未安装默认 .git/hooks/pre-commit'
  command head -n 2 "$hook_target" | grep -Fxq '# dotfiles-managed-pre-commit-v1' \
    || fail '默认 pre-commit 缺少受管标记'
  [[ -z "$(git -C "$hook_repo" config --get core.hooksPath 2>/dev/null)" ]] \
    || fail '一次性命令定义了 core.hooksPath'
  hook_before="$(cksum "$hook_target")"
  (
    cd "$hook_repo" || exit 1
    PATH="$fixture_bin:/usr/bin:/bin" ./.githooks/install.sh >/dev/null 2>&1
  ) || fail '一次性 Git hook 第二次安装失败'
  hook_after="$(cksum "$hook_target")"
  [[ "$hook_before" == "$hook_after" ]] || fail '一次性 Git hook 安装不是幂等输出'

  print -r -- 'unknown-hook-must-survive' > "$hook_target"
  chmod 700 "$hook_target"
  hook_before="$(cksum "$hook_target")"
  hook_conflict_output="$test_root/hook-conflict.out"
  if (
    cd "$hook_repo" || exit 1
    PATH="$fixture_bin:/usr/bin:/bin" ./.githooks/install.sh > "$hook_conflict_output" 2>&1
  ); then
    fail '一次性命令覆盖了未知默认 hook'
  fi
  assert_contains "$hook_conflict_output" '默认目标已存在且不属于本安装器'
  hook_after="$(cksum "$hook_target")"
  [[ "$hook_before" == "$hook_after" ]] || fail '未知默认 hook 在阻断后被修改'

  hook_custom_repo="$test_root/hook-custom-repo"
  hook_custom_output="$test_root/hook-custom.out"
  command mkdir -p -- "$hook_custom_repo/.githooks"
  command cp -- "$repo_root/.githooks/install.sh" "$repo_root/.githooks/pre-commit" \
    "$hook_custom_repo/.githooks/"
  chmod 700 "$hook_custom_repo/.githooks/install.sh" "$hook_custom_repo/.githooks/pre-commit"
  git -C "$hook_custom_repo" init -q
  git -C "$hook_custom_repo" config --local core.hooksPath custom-hooks
  if (
    cd "$hook_custom_repo" || exit 1
    PATH="$fixture_bin:/usr/bin:/bin" ./.githooks/install.sh > "$hook_custom_output" 2>&1
  ); then
    fail '一次性命令接受了自定义 core.hooksPath'
  fi
  assert_contains "$hook_custom_output" '检测到自定义 core.hooksPath=custom-hooks'
  [[ ! -e "$hook_custom_repo/.git/hooks/pre-commit" ]] \
    || fail '自定义 hooksPath 阻断后仍写入默认 hook'

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
