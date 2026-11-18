# dotfiles

```sh
curl -fsSL https://raw.githubusercontent.com/seg6/dotfiles/main/install | bash
```

Arch Linux (SwayFX) and macOS (AeroSpace). `install` fetches this repository and
runs `bootstrap`, which installs packages, places the dotfiles with Dotdrop,
builds the two Go tools, and generates the theme. Re-running it is safe.

## Layout

| Path | What it is |
| --- | --- |
| `dotfiles/config.yaml` | Dotdrop: which file goes where, grouped into profiles |
| `dotfiles/common` | Both systems: fish, git, ssh, Helix, Kitty, tmux, `ws` |
| `dotfiles/arch` | The Sway desktop: Sway, the Quickshell shells, Kitty's heading, systemd units |
| `dotfiles/macos` | AeroSpace, Karabiner |
| `dotfiles/workstation` | One machine: its outputs and autostarted applications |
| `dotfiles/config-root.yaml`, `dotfiles/system` | Files installed as root (a second Dotdrop config) |
| `packages/` | `arch`, `aur`, and `Brewfile`; `<hostname>.arch`, `<hostname>.aur`, and `Brewfile.<hostname>` add to them |
| `themes/` | The two layouts' own palettes, and wallpaper palettes for either |
| `tools/` | The `theme` and `ws` commands (`cli`), macOS preferences, Spotify helpers |
| `tests/` | See below |

Profiles build on each other: `common` → `arch` or `macos` → a machine. A machine
gets its own profile by adding one to `dotfiles/config.yaml` named after its hostname;
otherwise the system's profile is used. `dots` is Dotdrop with this checkout and
the installed profile filled in:

```sh
dots compare   # what differs from the repository
dots install   # install the profile
```

Files are copied, not linked, so an edit made under `~` is lost on the next
install unless it is brought back with `dots import` or made in the repository.

No colors are written in these files. Each program includes a file that `theme`
generates under `~/.config`, so one command recolors everything.

### macOS

macOS takes the shared shell, editor, terminal, and tmux setup, and the palette
for Kitty, Helix, tmux, and `ws`. Kitty keeps its own window layout there: the
larger type, padding, and heading strip belong to the Sway desktop. `theme use`
also sets the desktop picture. `tools/macos-defaults` holds the system preferences.

## Layouts

The Sway desktop comes in two layouts. A layout is the whole desktop: its shell,
window frames, spacing, and how Kitty, Helix, and tmux are dressed. Both need
`quickshell` 0.3.2 or newer.

```sh
theme use salon           # Salon, with its own palette and painting
theme use overprint       # Overprint
theme layout salon        # keep the current palette, change the layout
theme use coast --layout salon
```

`theme use <name>` without `--layout` takes the theme's own layout, so a plain
palette returns to Overprint. Super+Space opens the launcher and Super+Shift+V
the clipboard history in both.

## Salon

A gallery wall. There is no bar. Windows are the works hung on the wall: no
title bars, a gilt frame, a deep shadow. The one in focus has a picture light
over it and a bright frame; the rest are a shade dimmer. A wall with nothing on
it shows the theme's painting, framed and lit, with a museum label beside it.

The one thing always on screen is a brass plaque under the works, engraved with
the wall's number, the work that is lit, and the hour. Scroll over it for the
volume, right click to mute; the change is engraved for a moment in place of
the title. A red jewel in the brass means another wall wants attention.

Notifications arrive as cards slipped onto the wall in the lower corner. They
leave on their own; the pointer over one keeps it, and a click dismisses it.

Super+Tab, or a click on the plaque, opens the salon:

- Every wall is a framed picture of itself as it last looked, hung around the
  one you are on, each with a plaque saying what hangs there. Click one to walk
  to it, or press its number.
- Start typing and the catalogue answers with applications; Enter opens the
  entry that is inked in. Tab turns the catalogue to the clipboard history.
  Super+Space and Super+Shift+V open the salon on either.
- On the shelf below the rail: the clock (click it for the month, with week
  numbers) and tonight's moon; what is playing, with its controls; a brass push
  for each tray application (left click activates, right click opens its menu);
  the sound (click to mute, scroll to change, right click for the mixer); a push
  that keeps notifications quiet, letting only critical ones through; and the
  lights, which lock, sleep, log out, restart, or shut down. The last three ask
  for a second press.

The painting is the theme's wallpaper, and its label comes from the theme:

```toml
wallpaper = "wallpaper.jpg"

[art]
artist = "Vincent van Gogh"
life = "1853 – 1890"
title = "Wheatfield under Thunderclouds"
date = "1890"
medium = "oil on canvas"
```

`theme wallpaper picture.jpg --name harvest --layout salon` hangs any image and
takes the palette from it. The wall is painted the palette's `wall` color.

## Overprint

Overprint is print: flat paper and ink, square corners, hard offset shadows. A
Quickshell rail on the left, an app and clipboard launcher, notification popups,
and matching Kitty, Helix, tmux, and GTK colors.

Super+Space opens apps, Super+Shift+V opens clipboard history. The overlapping
squares also open the launcher. The launcher opens terminal applications in
Kitty and finds user applications under `~/.local/bin` and `~/.cargo/bin`,
preserving desktop-entry arguments and working directories.

On the rail:

- Workspace buttons appear for occupied workspaces and the current one,
  including windows that float or use XWayland.
- Applications in the tray keep their own icons, in an outlined box. The
  network, Bluetooth, audio, and VPN applets are drawn in the rail's line style
  below it. Hover any of them for its name. Left click activates, middle click
  is the secondary action, and right click opens the item's menu.
- Scroll over the volume to adjust it, right click to mute, click for the mixer.
- Hover the clock for the full date. Click it for a month calendar with week
  numbers: scroll or use the arrows to change month, click the heading for
  today. `qs ipc -c overprint call shell calendar` opens it from a key binding.

Helix has no buffer line. Kitty's own tab strip appears when it has multiple
tabs. Both tiled and floating Kitty windows get a Sway title bar, and the shell
keeps it when a window changes between the two. tmux uses italic indices and a
cell-sized offset shadow. The `ws` picker reads the generated
`~/.config/ws/theme.toml` without replacing the project roots or session
commands in its own configuration.

UI controls use Adwaita Sans 12pt, system monospace uses Fantasque Sans Mono
12pt, and terminals use Fantasque Sans Mono 18pt.

The Teams for Linux launcher uses native Wayland and PipeWire capture. The Sway
session passes `XDG_SESSION_TYPE` to the desktop services so apps opened from the
launcher can detect Wayland and use the screen-sharing portal. After changing the
session environment, restart the shell and fully quit and reopen Teams; closing
its window leaves the old process running.

## Palettes

The other entries in `themes/` are wallpaper palettes. They work in either layout:

```sh
theme list
theme use coast
theme use coast --layout salon
theme use overprint   # the original
```

Make one from any image:

```sh
theme wallpaper ~/Pictures/wallpaper.jpg --name forest
theme wallpaper ~/Pictures/wallpaper.jpg --name forest --layout salon
theme wallpaper ~/Pictures/wallpaper.jpg --name forest --preview   # HTML preview only
```

ImageMagick samples the image; the tool derives coordinated dark surfaces, paper,
ink, accents, and readable text colors. Spacing, typography, title bars, and
keybindings stay the same. Monochrome wallpapers keep neutral UI colors. Colored
wallpapers supply the surface hues without an invented complementary hue; syntax
and status colors remain distinguishable, with saturation reduced for muted
wallpapers.

A new palette and a copy of its wallpaper are saved in
`~/.config/dotfiles/themes/`. To keep one in this repository, move its directory
into `themes/` (the preview file is not needed). Omitting `--name` generates one
from the image's filename and contents.

A palette reaches SwayFX, the rail and launcher, Kitty, Helix, tmux, the `ws`
picker, GTK 3/4, an icon theme with folders in the accent color over Papirus,
Helium, and Spotify. The desktop, Kitty, Helix, and tmux reload at once. Reopen
GTK applications and Helium to load their new colors.

### Helium

Helium loads the generated theme on its next launch; existing driver flags and
other extension paths are preserved. The theme lives in
`~/.config/dotfiles/browser-theme` and can also be loaded through
`chrome://extensions` → **Load unpacked**. It styles the browser chrome and new
tab page; websites keep their own styles.

### Spotify

`./tools/install-overprint-extras` installs Spicetify under your user account,
after checking the release checksum. Then, for Spotify installed by
`spotify-launcher`:

```sh
./tools/activate-overprint-spotify
```

It creates a Spicetify backup, applies the theme, and restarts a running client,
restoring its playback state. Later palette changes refresh the patched colors
without restarting playback; reopen Spotify to load them. Run the script again
after a Spotify update replaces the patched files. `spicetify restore` returns
the original client. Last used with Spotify 1.3.8.620 and Spicetify 2.45.3, which
is beyond Spicetify's published Linux compatibility range, so keep the backup.

## Tests

```sh
go -C tools/cli test ./...
node --test tests/*.test.cjs
python3 -m unittest discover -s tests -p 'test_*.py'
```

The Python tests install the profiles into an empty home and start their own
headless SwayFX session with the actual shell, Kitty, tmux, and a tray
application, on separate D-Bus and Wayland connections.
