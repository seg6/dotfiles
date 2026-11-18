# dotfiles

```sh
curl -fsSL https://raw.githubusercontent.com/seg6/dotfiles/main/install | bash
```

Overprint is a native SwayFX preset with a Quickshell rail, app and clipboard
launcher, notification popups, and matching Kitty, Helix, tmux, and GTK colors.
It requires `quickshell` (0.3.2 or newer); the other dependencies are already in
the Arch package list.

From this checkout, activate it with:

```sh
./tools/activate-overprint
```

The installer builds the theme CLI, installs the relevant dotfiles with Dotdrop
backups, and switches the running session. Existing Helix sessions reload
automatically. Super+Space opens apps, Super+Shift+V opens clipboard history.
The overlapping squares also open the launcher. Scroll over the volume number
to adjust it, right click to mute, or click to open the mixer. Tray icons support
their usual left, right, and middle clicks.
The tray uses matching line drawings for system and common app icons; other apps
use their initials. Workspace buttons appear for occupied workspaces and the
current workspace, including windows that float or use XWayland.
The launcher opens terminal applications in Kitty and finds user applications
under `~/.local/bin` and `~/.cargo/bin`, preserving desktop-entry arguments and
working directories.

The Teams for Linux launcher uses native Wayland and PipeWire capture. The Sway
session also passes `XDG_SESSION_TYPE` to the desktop services so apps opened from
the launcher can detect Wayland and use the screen-sharing portal. After updating
the session environment, restart the desktop shell and fully quit and reopen
Teams; closing its window leaves the old process running.

Overprint is the default. The old preset catalog has been removed; wallpaper
palettes are saved separately and appear alongside Overprint in `theme list`.

Give Overprint a new wallpaper and color scheme while keeping its layout:

```sh
theme wallpaper ~/Pictures/wallpaper.jpg --name forest
```

ImageMagick samples the image; the tool derives coordinated dark surfaces, paper,
ink, accents, and readable text colors. It updates SwayFX, the rail and launcher,
Kitty, Helix, tmux, the `ws` picker, GTK, folder icons, Helium, and Spotify.
Spacing, typography, title bars, and keybindings stay the same.
Monochrome wallpapers keep neutral UI colors. Colored wallpapers supply the
surface hues without an invented complementary hue; syntax and status colors
remain distinguishable, with saturation reduced for muted wallpapers.

To review an HTML preview before activating:

```sh
theme wallpaper ~/Pictures/wallpaper.jpg --name forest --preview
theme use forest
theme use overprint # restore the original
```

The command prints the preview's path. Saved palettes and original wallpaper
copies live in `~/.config/dotfiles/themes/`; `theme list` includes them. Omitting
`--name` generates one from the image filename and contents. ImageMagick is
included in `packages.arch`.

The desktop, Kitty, Helix, and tmux reload automatically. Reopen GTK applications
and Helium to load their new colors. For Spotify already configured with
Spicetify's Overprint theme, the command refreshes the patched colors without
restarting playback; reopen Spotify to load them. After a Spotify update, use
`tools/activate-overprint-spotify` again to patch the updated client.

Verification:

```sh
go -C tools/cli test ./...
node --test tests/*.test.cjs
python3 -m unittest discover -s tests -p 'test_*.py'
```

The native previews in `design-preview/native/` were captured from an isolated
headless SwayFX session running the actual shell, Kitty, Helix, and tmux.
Notification timeouts and clipboard restoration were also exercised on that
session's separate D-Bus and Wayland connections.

Overprint also generates GTK 3/4 colors, desktop font settings, an icon theme with
original amber folders over Papirus, a Helium theme, Spotify colors and CSS, and
the `ws` picker palette. UI controls use Adwaita Sans 12pt, system monospace uses
Fantasque Sans Mono 12pt, and terminals use Fantasque Sans Mono 18pt.

For the additional desktop assets, run `./tools/install-overprint-extras` before
`./tools/activate-overprint`. The extras installer verifies Arch package signatures
and the Spicetify release checksum, and installs everything under your user account.
The normal Arch package list includes `adw-gtk-theme` and `papirus-icon-theme`.

Helium loads the generated theme on its next launch; existing driver flags and
other extension paths are preserved. Theme files live under
`~/.config/dotfiles/browser-theme`. They can also be loaded through
`chrome://extensions` → **Load unpacked**. This styles the browser chrome and new
tab page; individual websites retain their own styles.

For Spotify installed by `spotify-launcher`, run
`./tools/activate-overprint-spotify`. It creates a Spicetify backup, applies the theme,
and restores playback state when restarting an active player. Run this again after
Spotify updates replace the patched files. Restore the original client with
`spicetify restore`. The tested client is Spotify 1.3.4.258 with Spicetify 2.45.3;
this exceeds Spicetify's published Linux compatibility range, so keep the backup.

Helix has no buffer line. Kitty's own tab strip appears when it has multiple tabs. Both tiled and floating Kitty windows
get a Sway title bar. The Overprint shell keeps the heading visible when windows
change between tiled and floating. tmux uses italic indices and a cell-sized offset shadow. The workspace
picker reads generated `~/.config/ws/theme.toml` without replacing project roots or
session commands from its user configuration.
