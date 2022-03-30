export  ZSH="$HOME/.oh-my-zsh"
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$HOME/.poetry/bin:$PATH"

export PYTHONDONTWRITEBYTECODE=1
export PYGAME_HIDE_SUPPORT_PROMPT=1

ZSH_THEME="daveverwer"

plugins=(
    git
)

alias rm="rmtrash"
alias rmdir="rmdirtrash"

alias premake="premake5"
alias ipython="ipython --no-banner"
alias hexdump="hexdump -e '\"%08_ax  \" 8/1 \"%02x \" \"  \" 8/1 \"%02x \" \"\n\"'"

source $ZSH/oh-my-zsh.sh

precmd () { rehash; printf "\e[4 q"; }
