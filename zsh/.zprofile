# Apple Silicon login environment.
typeset -U path PATH
path=(/usr/bin /bin /usr/sbin /sbin)
[[ -d "$HOME/.local/bin" ]] && path=("$HOME/.local/bin" "${path[@]}")
[[ -d /opt/homebrew/sbin ]] && path=(/opt/homebrew/sbin "${path[@]}")
[[ -d /opt/homebrew/bin ]] && path=(/opt/homebrew/bin "${path[@]}")
export PATH

# >>> dotfiles: private profile configuration >>>
if [[ -r "$HOME/.config/dotfiles/company/zsh/profile.zsh" ]]; then
  source "$HOME/.config/dotfiles/company/zsh/profile.zsh" ||
    print -u2 -- "dotfiles: company profile.zsh 加载失败"
fi

if [[ -r "$HOME/.config/dotfiles/local/zsh/profile.zsh" ]]; then
  source "$HOME/.config/dotfiles/local/zsh/profile.zsh" ||
    print -u2 -- "dotfiles: local profile.zsh 加载失败"
fi
# <<< dotfiles: private profile configuration <<<
