export  ZSH="$HOME/.oh-my-zsh"
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$HOME/.poetry/bin:$PATH"

export PYTHONDONTWRITEBYTECODE=1
export PYGAME_HIDE_SUPPORT_PROMPT=1
export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"

ZSH_THEME="daveverwer"

plugins=(
    git
)

alias rm="rmtrash"
alias rmdir="rmdirtrash"

alias premake="premake5"
alias ipython="ipython --no-banner"
alias hexdump="hexdump -e '\"%08_ax  \" 8/1 \"%02x \" \"  \" 8/1 \"%02x \" \"\n\"'"

alias osu="WINEPREFIX=~/.osu-wine WINEARCH=win32 wine /mnt/184EEA7B6E44F78F/osu\!/osu\!.exe"
alias mcosu="pkill warpd && cd .local/share/Steam/steamapps/common/McOsu && ./McEngine && cd ~ && warpd"

source $ZSH/oh-my-zsh.sh

precmd() { rehash; printf "\e[4 q"; }
