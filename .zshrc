export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="daveverwer"

plugins=(
  git
  zsh-vi-mode
)

source $ZSH/oh-my-zsh.sh
source ~/.config/broot/launcher/bash/br

if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='nvim'
fi

export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$HOME/.poetry/bin:$PATH"
export PATH="$HOME/.local/share/neovim/bin:$PATH"

export PYTHONDONTWRITEBYTECODE=1
export SDL_VIDEO_X11_NET_WM_BYPASS_COMPOSITOR=0
export PYGAME_HIDE_SUPPORT_PROMPT=1
export DEBUGINFOD_URLS="https://debuginfod.archlinux.org"

alias n="./n.py"
alias nv="nvim"
alias nd="neovide"
alias lg="lazygit"
alias ipython="ipython --no-banner"
alias hexdump="hexdump -e '\"%08_ax  \" 8/1 \"%02x \" \"  \" 8/1 \"%02x \" \"\n\"'"

precmd() { rehash; }
export PATH=$PATH:~/.spicetify
