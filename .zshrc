autoload -Uz vcs_info
precmd() { vcs_info }

zstyle ':vcs_info:git:*' formats '%b '

setopt PROMPT_SUBST
PROMPT='%(!.%F{red}.%F{green})%n%f%F{white}@%f%F{cyan}%m%f %F{blue}%~%f %F{red}${vcs_info_msg_0_}%f$ '

[[ -r ~/.repos/znap/znap.zsh ]] ||
	git clone --depth 1 -- https://github.com/marlonrichert/zsh-snap.git ~/.repos/znap
source ~/.repos/znap/znap.zsh
znap source marlonrichert/zsh-autocomplete

export EDITOR=vim
export PF_ASCII="Catppuccin"
export PF_COL3=1
export PASTEL_COLOR_MODE=24bit

alias ls='ls --color=auto'
alias grep='grep --color'
alias ip='ip -color=auto'
alias public_ip='curl --ipv4 ifconfig.me'
alias public_ip6='curl --ipv6 ifconfig.me'
alias aria2c='aria2c -s16 -x16'
alias tb="nc termbin.com 9999"
alias wg="sudo wg"
alias less="less -R"
alias rm="rm --interactive=never"
alias sync_status="watch -d grep -e Dirty: -e Writeback: /proc/meminfo"
alias rsync_backup="rsync -aAXHv --exclude='/dev/*' --exclude='/proc/*' --exclude='/sys/*' --exclude='/tmp/*' --exclude='/run/*' --exclude='/mnt/*' --exclude='/media/*' --exclude='/lost+found/'"

source ~/.zsh/catppuccin_mocha-zsh-syntax-highlighting.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source <(fzf --zsh)

bindkey -v
bindkey ^R history-incremental-search-backward
bindkey ^S history-incremental-search-forward
bindkey "^I" menu-complete
bindkey "$terminfo[kcbt]" reverse-menu-complete

#History
export HISTFILE=~/.histfile
export HISTFILESIZE=1000000
export HISTSIZE=1000000
export SAVEHIST=1000000
setopt appendhistory

# bun completions
[ -s "/home/tobi/.bun/_bun" ] && source "/home/tobi/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
