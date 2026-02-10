```bash
paru -S sway waybar fish foot tmux helix git lazygit
paru -S mako cliphist bemenu grim slurp swaylock swayidle zoxide
paru -S ttf-fantasque-sans-mono ttf-jetbrains-mono-nerd

stow fish sway waybar foot tmux helix git lazygit gtk

mkdir -p ~/.local/bin
ln -sf ~/.config/tmux/tmux.conf ~/.tmux.conf
ln -sf ~/.config/tmux/scripts/ws ~/.local/bin/ws
```
