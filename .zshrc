
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
export ANDROID_HOME=/opt/android-sdk
export PATH=$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools
export PATH="~/.local/bin:$PATH"
  
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias aria2c='aria2c -s16 -x16'
alias gitupdateall="git pull && git submodule update --init --recursive --remote"
alias grep='grep --color'
alias ip='ip -color=auto'
alias less="less -R"
alias localnet='sudo arp-scan --localnet'
alias ls='ls --color=auto'
alias paru="paru --color=always"
alias public_ip6='curl --ipv6 ifconfig.me'
alias public_ip='curl --ipv4 ifconfig.me'
alias rm="rm --interactive=never"
alias suspend='systemctl suspend'
alias sync_status="watch -d grep -e Dirty: -e Writeback: /proc/meminfo"
alias tb="nc termbin.com 9999"
alias usb_writeback="watch -n 1 grep -e Dirty: -e Writeback: /proc/meminfo"
alias weather='curl -s "https://wttr.in/?m&format=%l:+%c+%t+(%f)"'
alias weather_f='curl -s "https://wttr.in/?format=%l:+%c+%t+(%f)"'
alias wg="sudo wg"
alias serial_connect="sudo screen /dev/ttyUSB0 9600"
alias bios='systemctl reboot --firmware-setup'
alias antigravity='antigravity --dangerously-skip-permissions'
alias ssh_tunnel='ssh -o ProxyCommand="cloudflared access ssh --hostname %h"' 

source ~/.zsh/rsync.zsh
fpath=(~/.zsh/completions $fpath)

# Quick public tunnel to a local port. Uses cloudflared (random *.trycloudflare.com) when
# installed, else Pinggy over plain ssh (free: 60 min per tunnel). Only the address and
# errors are shown; -v shows the provider's full output.
#   tunnel 8080            http on port 8080
#   tunnel http 3000       same, explicit
#   tunnel https 8443      local https server (cloudflared only)
#   tunnel ssh [port]      ssh (default 22); connect from the other side with the printed command
#   tunnel -p ...          force Pinggy     tunnel -c ...   force cloudflared
tunnel() {
    local provider verbose=0 proto=http port
    (( $+commands[cloudflared] )) && provider=cloudflared || provider=pinggy
    while [[ $1 == -* ]]; do
        case $1 in
            -p|--pinggy) provider=pinggy ;;
            -c|--cloudflared) provider=cloudflared ;;
            -v|--verbose) verbose=1 ;;
            *) echo "tunnel: unknown option $1" >&2; return 1 ;;
        esac
        shift
    done
    case $1 in
        http|https|ssh) proto=$1; shift ;;
    esac
    port=${1:-$([[ $proto == ssh ]] && echo 22)}
    if [[ -z $port ]]; then
        echo "usage: tunnel [-p|-c] [-v] [http|https|ssh] <port>   (ssh defaults to 22)" >&2
        return 1
    fi
    if [[ $provider == pinggy && $proto == https ]]; then
        echo "tunnel: https origins need cloudflared (Pinggy can't verify-skip a local cert)" >&2
        return 1
    fi

    # Throwaway random hosts: never record them (or Pinggy's relay) in known_hosts.
    local noknown=(-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no)
    local -a cmd
    if [[ $provider == cloudflared ]]; then
        cmd=(cloudflared tunnel --url "$proto://127.0.0.1:$port")
        [[ $proto == https ]] && cmd+=(--no-tls-verify)
    else
        cmd=(ssh -T -p 443 $noknown -o LogLevel=ERROR -o ServerAliveInterval=30 -o ExitOnForwardFailure=yes
             -R0:127.0.0.1:$port $([[ $proto == ssh ]] && echo tcp@)a.pinggy.io)
    fi

    local shown=0 line host tport
    print -P "%F{8}Opening $proto tunnel to 127.0.0.1:$port via $provider…%f"
    $cmd 2>&1 | while IFS= read -r line; do
        line=${line%$'\r'}
        (( verbose )) && print -r -- "$line"
        host= tport=
        if [[ $line =~ '(https://[a-z0-9-]+\.trycloudflare\.com)' ]]; then
            host=${match[1]#https://}
        elif [[ $line =~ '^https://([a-z0-9.-]+)$' && $line != *dashboard.pinggy.io* ]]; then
            host=${match[1]}
        elif [[ $line =~ '^tcp://([a-z0-9.-]+):([0-9]+)$' ]]; then
            host=${match[1]} tport=${match[2]}
        elif (( ! verbose )) && [[ $line == *' ERR '* || $line == *rror* || $line == *denied* || $line == *failed* ]]; then
            print -r -- "$line" >&2
        fi
        [[ -z $host ]] && continue
        (( shown++ )) && continue     # Pinggy lists several equivalent addresses; show the first
        print -P "%F{green}%BTunnel up:%b%f $proto → 127.0.0.1:$port  %F{8}(Ctrl-C to close)%f"
        if [[ $proto != ssh ]]; then
            print -r -- "  https://$host"
        elif [[ $provider == cloudflared ]]; then
            print -r -- "  ssh -o ProxyCommand=\"cloudflared access ssh --hostname %h\" ${noknown[*]} $USER@$host"
        else
            print -r -- "  ssh -p $tport ${noknown[*]} $USER@$host"
        fi
    done
}

disown_app() {
  for cmd in "$@"; do
    setsid sh -c "$cmd" >/dev/null 2>&1 < /dev/null &!; exit 
  done
}

source ~/.zsh/catppuccin_mocha-zsh-syntax-highlighting.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source <(fzf --zsh)

# --- vim keybinds, insert-mode-only (added; revert by uncommenting the next
# line and deleting everything down to the matching END marker below) ---
# bindkey -v
bindkey -v
# Escape normally switches viins -> vicmd (vi "normal mode"). Removing that
# binding means Esc does nothing special, so you never leave insert mode.
bindkey -M viins -r '^['
# Vim-flavored motions/edits mapped onto Alt (Meta) so hjkl stay free for
# typing text; all of these run without leaving insert mode.
bindkey -M viins '^[h' backward-char          # Alt-h
bindkey -M viins '^[l' forward-char           # Alt-l
bindkey -M viins '^[k' up-line-or-history     # Alt-k
bindkey -M viins '^[j' down-line-or-history   # Alt-j
bindkey -M viins '^[w' forward-word           # Alt-w
bindkey -M viins '^[b' backward-word          # Alt-b
bindkey -M viins '^[d' kill-word              # Alt-d
bindkey -M viins '^[0' beginning-of-line      # Alt-0
bindkey -M viins '^[$' end-of-line            # Alt-$
bindkey -M viins '^[x' vi-delete              # Alt-x (vi-style delete op)
# --- END vim keybinds, insert-mode-only ---
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
export PATH=~/dotfiles/bin:$PATH

export LIBVIRT_DEFAULT_URI="qemu:///system"



# The following lines were added by compinstall

zstyle ':completion:*' completer _complete _ignored _correct _approximate
zstyle :compinstall filename '/home/tobi/.zshrc'

autoload -Uz compinit
compinit
compdef _wg-dot wg-dot
compdef _vpn-dot vpn-dot
# End of lines added by compinstall



# Added by Antigravity CLI installer
export PATH="/home/tobi/.local/bin:$PATH"
