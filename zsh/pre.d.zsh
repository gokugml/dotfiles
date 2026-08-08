# shellcheck shell=zsh

# ==============================================================================
# 10-oh-my-zsh.zsh
# ==============================================================================

typeset -g ZSH="${ZSH:-$HOME/.oh-my-zsh}" # 功能=定位 Oh My Zsh checkout；最佳实践=rewrite；修改级别=一定要改；建议=保持普通变量且由安装器验证官方 origin；归属=public；验证=变量未 export 且目录可读
typeset -g ZSH_THEME="robbyrussell" # 功能=保留当前轻量主题；最佳实践=pass；修改级别=建议修改；建议=首期不引入第二套提示符；归属=public；验证=交互提示符可渲染
typeset -ga plugins
plugins=(git) # 功能=启用 OMZ 内置 Git 集成；最佳实践=pass；修改级别=建议修改；建议=随官方 OMZ 基线加载；归属=public；验证=Git 补全和内置 alias 可用
zstyle ':omz:update' mode auto # 功能=允许 shell 启动时检查 OMZ 更新；最佳实践=rewrite；修改级别=一定要改；建议=仅允许官方上游并保留离线降级；归属=public；验证=zstyle 查询返回 auto
zstyle ':omz:update' frequency 13 # 功能=限制 OMZ 更新检查频率；最佳实践=rewrite；修改级别=一定要改；建议=每十三天最多检查一次；归属=public；验证=zstyle 查询返回 13

# ==============================================================================
# 20-completion-policy.zsh
# ==============================================================================

typeset -U fpath FPATH # 功能=在 OMZ 执行 compinit 前唯一化补全搜索路径；最佳实践=rewrite；修改级别=一定要改；建议=所有 adapter 只添加 fpath 不自行 compinit；归属=public；验证=fpath 无重复且 compinit 仅由 OMZ 调用
