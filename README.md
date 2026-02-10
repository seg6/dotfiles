```bash
paru -S stow sway waybar fish foot tmux helix git
paru -S mako cliphist bemenu grim slurp swaylock swayidle zoxide
paru -S ttf-fantasque-sans-mono ttf-jetbrains-mono-nerd

brew install stow fish tmux helix git
brew install --cask nikitabobko/tap/aerospace
brew install --cask ghostty

stow -t ~ fish tmux helix git
stow -t ~ sway waybar foot gtk
stow -t ~ aerospace ghostty

mkdir -p ~/.local/bin
ln -sf ~/.config/tmux/tmux.conf ~/.tmux.conf
ln -sf ~/.config/tmux/scripts/ws ~/.local/bin/ws
```
