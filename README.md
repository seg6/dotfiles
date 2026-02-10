```bash
paru -S stow sway waybar fish foot tmux helix git
paru -S mako cliphist bemenu grim slurp swaylock swayidle zoxide
paru -S ttf-fantasque-sans-mono ttf-jetbrains-mono-nerd

stow -t ~ fish sway waybar foot tmux helix git gtk

mkdir -p ~/.local/bin
ln -sf ~/.config/tmux/tmux.conf ~/.tmux.conf
ln -sf ~/.config/tmux/scripts/ws ~/.local/bin/ws
```
