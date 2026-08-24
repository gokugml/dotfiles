#!/bin/zsh

emulate -LR zsh
setopt NO_UNSET PIPE_FAIL
umask 077

readonly script_dir="${0:A:h}"
readonly checker="$script_dir/zsh-functional-blocks.zsh"
readonly test_root="$(mktemp -d /private/tmp/zsh-functional-blocks-test.XXXXXX)"
readonly source_profile="$test_root/source.zprofile"
readonly source_rc="$test_root/source.zshrc"
readonly target_profile="$test_root/target.zprofile"
readonly target_rc="$test_root/target.zshrc"
readonly integrations="$test_root/integrations.zsh"
readonly rendered_integrations="$test_root/rendered-integrations.zsh"

cleanup() {
  command rm -rf -- "$test_root"
}
trap cleanup EXIT HUP INT TERM

fail() {
  print -u2 -r -- "test-zsh-functional-blocks.zsh: $1"
  exit 1
}

{
  print -r -- '# Kiro CLI pre block. Keep at the top of this file.'
  print -r -- '[[ -r "$HOME/.kiro/shell/zprofile.pre.zsh" ]] && source "$HOME/.kiro/shell/zprofile.pre.zsh"'
  print
  print -r -- '# The next line updates PATH for the Google Cloud SDK.'
  print -r -- '[[ -r "$HOME/google-cloud-sdk/path.zsh.inc" ]] && source "$HOME/google-cloud-sdk/path.zsh.inc"'
  print
  print -r -- '# Kiro CLI post block. Keep at the bottom of this file.'
  print -r -- '[[ -r "$HOME/.kiro/shell/zprofile.post.zsh" ]] && source "$HOME/.kiro/shell/zprofile.post.zsh"'
} > "$source_profile"

{
  print -r -- '# Kiro CLI pre block. Keep at the top of this file.'
  print -r -- '[[ -r "$HOME/.kiro/shell/zshrc.pre.zsh" ]] && source "$HOME/.kiro/shell/zshrc.pre.zsh"'
  print
  print -r -- '# personal configuration'
  print -r -- 'source "$ZSH/oh-my-zsh.sh"'
  print
  print -r -- '# kimi-code'
  print -r -- 'export KIMI_LOCAL_TOKEN="fixture-comparison-secret"'
  print -r -- '[[ -r "$HOME/.kimi/kimi.zsh" ]] && source "$HOME/.kimi/kimi.zsh"'
  print
  print -r -- '# Kiro CLI post block. Keep at the bottom of this file.'
  print -r -- '[[ -r "$HOME/.kiro/shell/zshrc.post.zsh" ]] && source "$HOME/.kiro/shell/zshrc.post.zsh"'
} > "$source_rc"

{
  print -r -- '# dotfiles: local-integrations zprofile-pre'
  print -r -- 'if [[ -r "$HOME/.config/dotfiles/local/integrations.zsh" ]]; then'
  print -r -- '  DOTFILES_INTEGRATIONS_PHASE=zprofile-pre'
  print -r -- '  source "$HOME/.config/dotfiles/local/integrations.zsh"'
  print -r -- '  unset DOTFILES_INTEGRATIONS_PHASE'
  print -r -- 'fi'
  print
  print -r -- '# dotfiles: personal'
  print -r -- 'export PATH="/opt/homebrew/bin:$PATH"'
  print
  print -r -- '# dotfiles: local-integrations zprofile-post'
  print -r -- 'if [[ -r "$HOME/.config/dotfiles/local/integrations.zsh" ]]; then'
  print -r -- '  DOTFILES_INTEGRATIONS_PHASE=zprofile-post'
  print -r -- '  source "$HOME/.config/dotfiles/local/integrations.zsh"'
  print -r -- '  unset DOTFILES_INTEGRATIONS_PHASE'
  print -r -- 'fi'
} > "$target_profile"

{
  print -r -- '# dotfiles: local-integrations zshrc-pre'
  print -r -- 'if [[ -r "$HOME/.config/dotfiles/local/integrations.zsh" ]]; then'
  print -r -- '  DOTFILES_INTEGRATIONS_PHASE=zshrc-pre'
  print -r -- '  source "$HOME/.config/dotfiles/local/integrations.zsh"'
  print -r -- '  unset DOTFILES_INTEGRATIONS_PHASE'
  print -r -- 'fi'
  print
  print -r -- '# dotfiles: personal'
  print -r -- 'source "$ZSH/oh-my-zsh.sh"'
  print
  print -r -- '# dotfiles: local-integrations zshrc-post'
  print -r -- 'if [[ -r "$HOME/.config/dotfiles/local/integrations.zsh" ]]; then'
  print -r -- '  DOTFILES_INTEGRATIONS_PHASE=zshrc-post'
  print -r -- '  source "$HOME/.config/dotfiles/local/integrations.zsh"'
  print -r -- '  unset DOTFILES_INTEGRATIONS_PHASE'
  print -r -- 'fi'
} > "$target_rc"

{
  print -r -- '# dotfiles: generated local integrations v1'
  print -r -- 'case "${DOTFILES_INTEGRATIONS_PHASE:-}" in'
  print -r -- '  zprofile-pre)'
  print -r -- '# Kiro CLI pre block. Keep at the top of this file.'
  print -r -- '[[ -r "$HOME/.kiro/shell/zprofile.pre.zsh" ]] && source "$HOME/.kiro/shell/zprofile.pre.zsh"'
  print
  print -r -- '    ;;'
  print -r -- '  zprofile-post)'
  print -r -- '# The next line updates PATH for the Google Cloud SDK.'
  print -r -- '[[ -r "$HOME/google-cloud-sdk/path.zsh.inc" ]] && source "$HOME/google-cloud-sdk/path.zsh.inc"'
  print
  print -r -- '# Kiro CLI post block. Keep at the bottom of this file.'
  print -r -- '[[ -r "$HOME/.kiro/shell/zprofile.post.zsh" ]] && source "$HOME/.kiro/shell/zprofile.post.zsh"'
  print
  print -r -- '    ;;'
  print -r -- '  zshrc-pre)'
  print -r -- '# Kiro CLI pre block. Keep at the top of this file.'
  print -r -- '[[ -r "$HOME/.kiro/shell/zshrc.pre.zsh" ]] && source "$HOME/.kiro/shell/zshrc.pre.zsh"'
  print
  print -r -- '    ;;'
  print -r -- '  zshrc-post)'
  print -r -- '# kimi-code'
  print -r -- 'export KIMI_LOCAL_TOKEN="fixture-comparison-secret"'
  print -r -- '[[ -r "$HOME/.kimi/kimi.zsh" ]] && source "$HOME/.kimi/kimi.zsh"'
  print
  print -r -- '# Kiro CLI post block. Keep at the bottom of this file.'
  print -r -- '[[ -r "$HOME/.kiro/shell/zshrc.post.zsh" ]] && source "$HOME/.kiro/shell/zshrc.post.zsh"'
  print
  print -r -- '    ;;'
  print -r -- 'esac'
} > "$integrations"

output="$({
  /bin/zsh "$checker" compare \
    --source-zprofile "$source_profile" \
    --source-zshrc "$source_rc" \
    --target-zprofile "$target_profile" \
    --target-zshrc "$target_rc" \
    --integrations "$integrations"
})" || fail "完整迁移后的覆盖比较应通过：$output"

[[ "$output" == *'coverage: pass'* ]] || fail '覆盖比较未报告 pass'
[[ "$output" == *'covered=6 missing=0'* ]] || fail '覆盖计数错误'
[[ "$output" != *'fixture-comparison-secret'* ]] || fail '比较输出泄露了块内容'
[[ "$output" != *"$test_root"* ]] || fail '比较输出泄露了本机路径'

render_output="$(/bin/zsh "$checker" render-local \
  --source-zprofile "$source_profile" \
  --source-zshrc "$source_rc" \
  --output "$rendered_integrations")" || fail '本机 integrations 候选生成失败'
[[ "$render_output" == *'render-local: pass rendered=6 manual=0'* ]] \
  || fail '本机 integrations 候选生成计数错误'
[[ "$render_output" != *'fixture-comparison-secret'* ]] || fail '候选生成输出泄露了块内容'
[[ "$(stat -f '%Lp' "$rendered_integrations")" == 600 ]] || fail '候选权限不是 0600'
/bin/zsh -n "$rendered_integrations" || fail '候选 Zsh 语法失败'
/bin/zsh "$checker" compare \
  --source-zprofile "$source_profile" \
  --source-zshrc "$source_rc" \
  --target-zprofile "$target_profile" \
  --target-zshrc "$target_rc" \
  --integrations "$rendered_integrations" >/dev/null \
  || fail '自动生成的 integrations 候选未通过覆盖比较'

if /bin/zsh "$checker" compare \
  --source-zprofile "$source_profile" \
  --source-zshrc "$source_rc" \
  --target-zprofile "$source_rc" \
  --target-zshrc "$source_profile" >/dev/null 2>&1; then
  fail '源功能块被放入错误启动文件时覆盖比较必须失败'
fi

{
  print -r -- '# dotfiles: generated local integrations v1'
  print -r -- 'case "${DOTFILES_INTEGRATIONS_PHASE:-}" in'
  print -r -- '  zprofile-post)'
  print -r -- '# The next line updates PATH for the Google Cloud SDK.'
  print -r -- '[[ -r "$HOME/google-cloud-sdk/path.zsh.inc" ]] && source "$HOME/google-cloud-sdk/path.zsh.inc"'
  print -r -- '    ;;'
  print -r -- 'esac'
} > "$integrations"

if /bin/zsh "$checker" compare \
  --source-zprofile "$source_profile" \
  --source-zshrc "$source_rc" \
  --target-zprofile "$target_profile" \
  --target-zshrc "$target_rc" \
  --integrations "$integrations" >/dev/null 2>&1; then
  fail '缺少源功能块时覆盖比较必须失败'
fi

print -r -- 'test-zsh-functional-blocks.zsh: 通过'
