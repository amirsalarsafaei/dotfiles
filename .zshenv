export PATH="$HOME/go/bin:/usr/local/lib:$HOME/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:$HOME/go/bin:/usr/local/go/bin:$PATH"
export GOPRIVATE="git.cafebazaar.ir,git.divar.cloud"
export GOPATH="$HOME/go"
export GOROOT="/usr/local/go"
export GOSUMDB='off'
export GONOPROXY=git.divar.cloud
export AWS_ENDPOINT=https://s3.thr1.sotoon.ir

export ZSH="$HOME/.oh-my-zsh"
export EDITOR="nvim"

export DOCKER_DEFAULT_PLATFORM=linux/amd64

export ZSH_DOTENV_PROMPT=false

#IDEs
export PATH="$HOME/clion-2023.3.4/bin:$HOME/GoLand-2023.3.6/bin:$HOME/pycharm-2023.3.5/bin:$HOME/WebStorm-2023.3/bin:$PATH"

#Brew
export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"

export NVM_DIR="$HOME/.nvm"

. "$HOME/.cargo/env"


#XDG
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_MUSIC_DIR="$HOME/Music"
export XDG_PICTURES_DIR="$HOME/Pictures"

alias zshconfig="nvim ~/.zshrc && exec zsh"
alias vim="nvim"
alias reload="exec zsh"
alias bat="batcat"
alias tele=telepresence
alias teleconn="telepresence connect"
alias telestat="telepresence status"
alias teleinter="telepresence intercept"
alias teleleave="telepresence leave"
alias telequit="telepresence quit"
alias teleuninstall="telepresence uninstall --agent"
alias telelist="telepresence list"
alias gitshort="git rev-parse --short=8 HEAD"
alias gitrecent="git for-each-ref --sort=-committerdate refs/heads/ --format='%(committerdate:short) %(refname:short)'"
alias pbcopy='xclip -selection clipboard'
alias pbpaste='xclip -selection clipboard -o'

# private configs
[[ ! -f ~/.zshrc.secret ]] || source ~/.zshrc.secret
