#!/bin/zsh

emulate -L zsh
setopt NO_UNSET PIPE_FAIL
umask 077

readonly script_dir="${0:A:h}"
readonly collector="$script_dir/collect-zsh-evidence.zsh"
readonly test_root="$(mktemp -d /private/tmp/zsh-evidence-test.XXXXXX)"
readonly fixture_home="$test_root/home"
readonly fixture_repo="$test_root/repo"
readonly fixture_repository_source="$fixture_repo/my_setup/zsh"
readonly report="$fixture_repo/tmp/zsh-evidence.md"

cleanup() {
  command rm -rf -- "$test_root"
}
trap cleanup EXIT HUP INT TERM

fail() {
  print -u2 -r -- "test-collect-zsh-evidence.zsh: $1"
  exit 1
}

assert_contains() {
  local expected="$1"
  grep -Fq -- "$expected" "$report" || fail "缺少预期证据：$expected"
}

assert_count() {
  local expected_count="$1"
  local expected_text="$2"
  local actual_count

  actual_count="$(grep -Fc -- "$expected_text" "$report" || true)"
  [[ "$actual_count" == "$expected_count" ]] \
    || fail "证据计数错误：$expected_text；预期 $expected_count，实际 $actual_count"
}

assert_absent() {
  local forbidden="$1"
  if grep -Fq -- "$forbidden" "$report"; then
    fail "报告泄露了禁止内容"
  fi
}

assert_text_contains() {
  local text="$1"
  local expected="$2"
  [[ "$text" == *"$expected"* ]] || fail "预检输出缺少：$expected"
}

mkdir -p -- \
  "$fixture_home/bin" \
  "$fixture_home/.nvm" \
  "$fixture_home/.oh-my-zsh" \
  "$fixture_repository_source" \
  "$fixture_repo"
touch -- \
  "$fixture_home/bin/pnpm" \
  "$fixture_home/.nvm/nvm.sh" \
  "$fixture_home/.nvm/bash_completion" \
  "$fixture_home/.oh-my-zsh/oh-my-zsh.sh"
chmod 700 "$fixture_home/bin/pnpm"

{
  print -r -- 'export PATH="$HOME/bin:$PATH"'
} > "$fixture_home/.zprofile"

{
  print -r -- 'export PATH="/usr/local/bin:$PATH"'
  print -r -- 'export PNPM_HOME="$HOME/bin/pnpm"'
  print -r -- 'export NVM_DIR="$HOME/.nvm"'
  print -r -- '[[ -s "$NVM_DIR/nvm.sh" ]] && \. "$NVM_DIR/nvm.sh"'
  print -r -- '[[ -s "$NVM_DIR/bash_completion" ]] && \. "$NVM_DIR/bash_completion"'
  print -r -- '[[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"'
  print -r -- 'export ACTIVE_API_KEY="fixture-active-secret"'
  print -r -- '# export OLD_ACCESS_TOKEN="fixture-commented-secret"'
  print -r -- 'fpath=("$HOME/.config/zsh/completions" "${fpath[@]}")'
  print -r -- 'source "$HOME/.oh-my-zsh/oh-my-zsh.sh"'
  print -r -- 'autoload -Uz compinit'
  print -r -- 'compinit'
  print -r -- 'export PROJECT_DIR="/Users/example/private"'
  print -r -- '# export ARCHFLAGS="-arch x86_64"'
} > "$fixture_home/.zshrc"

{
  print -r -- 'export PATH="$HOME/bin:$PATH"'
} > "$fixture_repository_source/zprofile"

{
  print -r -- 'export REPOSITORY_API_KEY="fixture-repository-secret"'
  print -r -- 'autoload -Uz compinit'
  print -r -- 'compinit'
} > "$fixture_repository_source/zshrc"

git -C "$fixture_repo" init -q
{
  print -r -- 'tmp/'
} > "$fixture_repo/.gitignore"

if (
  cd "$fixture_repo" || exit 1
  ZSH_ANALYSIS_TEST_HOME="$fixture_home" "$collector" >/dev/null 2>&1
); then
  fail '未显式选择来源时采集器不应成功'
fi

preflight_output="$({
  cd "$fixture_repo" || exit 1
  ZSH_ANALYSIS_TEST_HOME="$fixture_home" \
    "$collector" --source live-home --files zprofile,zshrc --preflight
})" || fail 'live-home 预检失败'
assert_text_contains "$preflight_output" '- source-origin: live-home'
assert_text_contains "$preflight_output" '- selected-files: zprofile,zshrc'
assert_text_contains "$preflight_output" '- input-map: .zprofile <- .zprofile kind=file'
assert_text_contains "$preflight_output" '- report-written: no'
[[ ! -e "$report" ]] || fail '预检不得写入证据报告'

(
  cd "$fixture_repo" || exit 1
  PATH='/usr/local/bin:/usr/local/bin:/usr/bin:/bin' \
    ZSH_ANALYSIS_TEST_HOME="$fixture_home" \
    "$collector" --source live-home --files zprofile,zshrc >/dev/null
) || fail '采集器执行失败'

assert_contains '- source-origin: live-home'
assert_contains '- source-root-category: live-home'
assert_contains '- selected-files: zprofile,zshrc'
assert_contains '- source-input-name: .zprofile'
assert_contains '- collector-process-architecture:'
assert_contains '- startup-performance: not-measured'
assert_contains '- startup-files-sourced: no'
assert_contains '- intel-markers-active: 1'
assert_contains '- intel-markers-commented: 1'
assert_contains '- compinit-references-active: 2'
assert_contains '- compinit-calls-active: 1'
assert_contains 'name=ACTIVE_API_KEY scope=exported secret-like=yes'
assert_contains 'name=OLD_ACCESS_TOKEN scope=exported secret-like=yes'
assert_contains 'name=PNPM_HOME path-category=$HOME/<redacted> target-kind=file'
assert_count 1 'source-category: line 4 nvm-runtime'
assert_count 2 'nvm-completion'
assert_contains '- hardcoded-home: line 13 active=yes'
assert_contains '- duplicate-excess: 1'

assert_absent 'fixture-active-secret'
assert_absent 'fixture-commented-secret'
assert_absent '/Users/example/private'
assert_absent "$fixture_home"

preflight_output="$({
  cd "$fixture_repo" || exit 1
  ZSH_ANALYSIS_TEST_HOME="$fixture_home" \
    "$collector" --source repository --source-dir my_setup/zsh --files zprofile,zshrc --preflight
})" || fail 'repository 预检失败'
assert_text_contains "$preflight_output" '- source-origin: repository'
assert_text_contains "$preflight_output" '- source-root-category: current-repository'
assert_text_contains "$preflight_output" '- input-map: .zprofile <- zprofile kind=file'
assert_text_contains "$preflight_output" '- input-map: .zshrc <- zshrc kind=file'

(
  cd "$fixture_repo" || exit 1
  PATH='/usr/local/bin:/usr/local/bin:/usr/bin:/bin' \
    ZSH_ANALYSIS_TEST_HOME="$fixture_home" \
    "$collector" --source repository --source-dir my_setup/zsh --files zprofile,zshrc >/dev/null
) || fail 'repository 采集失败'

assert_contains '- source-origin: repository'
assert_contains '- source-root-category: current-repository'
assert_contains '- selected-files: zprofile,zshrc'
assert_contains '- source-input-name: zprofile'
assert_contains '- source-input-name: zshrc'
assert_contains 'name=REPOSITORY_API_KEY scope=exported secret-like=yes'
assert_absent 'fixture-repository-secret'
assert_absent '### .zshenv'
assert_absent "$fixture_repository_source"

touch "$fixture_repository_source/.zshrc"
if (
  cd "$fixture_repo" || exit 1
  ZSH_ANALYSIS_TEST_HOME="$fixture_home" \
    "$collector" --source repository --source-dir my_setup/zsh --files zshrc --preflight >/dev/null 2>&1
); then
  fail '同名点文件与非点文件并存时必须拒绝歧义'
fi
rm -f -- "$fixture_repository_source/.zshrc"

if (
  cd "$fixture_repo" || exit 1
  ZSH_ANALYSIS_TEST_HOME="$fixture_home" \
    "$collector" --source repository --source-dir "$fixture_home" --files zshrc --preflight >/dev/null 2>&1
); then
  fail 'repository 来源目录不得离开当前仓库'
fi

print -r -- 'test-collect-zsh-evidence.zsh: 通过'
