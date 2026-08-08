# shellcheck shell=zsh

# ==============================================================================
# 10-history.zsh
# ==============================================================================

typeset -g HISTFILE="$HOME/.local/state/zsh/history" # 功能=把历史放入 XDG 风格状态目录；最佳实践=rewrite；修改级别=一定要改；建议=与配置文件分离并限制权限；归属=public；验证=HISTFILE 指向 local-state
typeset -g HISTSIZE=50000 # 功能=保留较大的会话内历史窗口；最佳实践=pass；修改级别=建议修改；建议=大于落盘数量以支持去重；归属=public；验证=HISTSIZE 大于 SAVEHIST
typeset -g SAVEHIST=10000 # 功能=限制落盘历史数量；最佳实践=pass；修改级别=建议修改；建议=与性能和隐私边界平衡；归属=public；验证=新会话读取历史正常
if [[ ! -d "${HISTFILE:h}" ]]; then
  command mkdir -p -m 700 "${HISTFILE:h}" || return
fi
command chmod 700 "${HISTFILE:h}" 2>/dev/null
setopt APPEND_HISTORY EXTENDED_HISTORY HIST_EXPIRE_DUPS_FIRST HIST_IGNORE_ALL_DUPS HIST_IGNORE_DUPS HIST_IGNORE_SPACE HIST_NO_STORE
unsetopt SHARE_HISTORY INC_APPEND_HISTORY INC_APPEND_HISTORY_TIME # 功能=避免跨终端实时共享并减少敏感命令落盘；最佳实践=rewrite；修改级别=一定要改；建议=仅在 shell 退出时追加且启用去重；归属=public；验证=并发 fixture 不启用 SHARE_HISTORY

# ==============================================================================
# 20-tools.zsh
# ==============================================================================

if (( $+commands[mise] )) && [[ -z "${_DOTFILES_MISE_ACTIVATED:-}" ]]; then
  typeset -g _DOTFILES_MISE_ACTIVATED=1
  eval "$(mise activate zsh)" # 功能=激活固定版本的跨项目工具；最佳实践=replace；修改级别=一定要改；建议=替代 NVM 与直接 Bun/pnpm PATH；归属=public；验证=重复 source 只激活一次且 node-bun-pnpm 来源为 mise
fi

if (( $+commands[zoxide] )) && [[ -z "${_DOTFILES_ZOXIDE_ACTIVATED:-}" ]]; then
  typeset -g _DOTFILES_ZOXIDE_ACTIVATED=1
  eval "$(zoxide init zsh)" # 功能=提供智能目录跳转；最佳实践=replace；修改级别=一定要改；建议=迁移 autojump 数据后只激活一次 zoxide；归属=public；验证=zoxide 可跳转且 autojump 不再加载
fi

# ==============================================================================
# 30-bindings.zsh
# ==============================================================================

bindkey '^U' backward-kill-line # 功能=让 Ctrl-U 删除到行首；最佳实践=pass；修改级别=建议修改；建议=保留当前无外部依赖的交互键位；归属=public；验证=bindkey 查询返回 backward-kill-line
