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
theme use folio           # Folio, with its own palette and picture
theme use overprint       # Overprint
theme layout folio        # keep the current palette, change the layout
theme use coast --layout folio
```

`theme use <name>` without `--layout` takes the theme's own layout, so a plain
palette returns to Overprint. Super+Space opens the launcher and Super+Shift+V
the clipboard history in both.

## Folio

A page. Two colors, bone on near-black, and one red that only ever means
something wants you. Two typefaces, both installed with the dotfiles: Departure
Mono for the small capitals in the margins, Newsreader for sentences. Windows
are a hairline: no title bars, no shadows, the one in focus has the brighter line.

The top margin is one line of small type:

- the program in focus and what it is showing;
- the desks, each named for what is on it. Click one to go there. A red dot means it wants attention;
- what is playing (click to pause, right click for the next track, middle for
  the last), the tray applications as words (left click activates, right click
  opens the application's own menu as a list), and the volume (scroll to
  change, click to mute, right click for the mixer).

The bottom margin has the city the clock is set to, the date and the time;
click either for the month, with week numbers. On the right is a switch that
keeps notifications quiet, letting only critical ones through. A notification
is written into that margin, with its actions and LATER beside it. It leaves on
its own; the pointer over it keeps it. Ones that left unseen, or were held back
while quiet, are counted there ("3 MISSED"); click the count to read them.

A desk with nothing open says the hour, the day and the place in one large
line, such as "It is twenty to one on a Wednesday in Berlin." Under it is a
short list, one fact to a line: what is ELSEWHERE, what is WAITING and for how
long, what is PLAYING, and how many notifications were MISSED. The names are
links: to the desk, to pause, to the list of what went by.
Along the foot of the page is a picture of nothing: a slow weather of dots
in the two colors, thick at the foot and gone before it reaches the words. It
flows faster while music plays, parts round the pointer and ripples when the
pointer moves. By night it thins, stars come out over it, and now and then one
falls; night is reckoned from the date and the latitude in
`~/.config/dotfiles/place`, or 50° north without one. Where there is no GPU
the theme's wallpaper stands in, dithered and still.

That is one of five things the empty desk can be. Super+` turns to the next
(Super+Shift+` back), as do the names at the foot of the page and
`desktop-menu view next|prev|NAME`; the choice is kept.

- **Orbit.** The other desks as bodies in orbit round this one: the desk used
  last is nearest, more windows make a larger body, and one that wants
  attention wears a red ring. Click one to go there; drag one onto another to
  move its windows in with the other's.
- **Dial.** The day as one instrument, midnight at the top. The outer ring is
  the hours with the daylight marked, the middle ring is which desk you were
  on and when, the inner ring is the track, and the red hand is now. Hover the
  middle ring to read a stretch and click to go to its desk; click the inner
  ring to move through the track; scroll to turn back to earlier days.
- **Numeral.** The desk's number as large as the page allows, with the
  weather inside it. It comes apart near the pointer.
- **Plate.** Rings from three places, crossing. The date decides where they
  are, so each day has its own. Drag a point to move a source; click for
  another.
- **Words.** The page described above; or, while a song plays whose words
  are known, the song: the line being sung in the middle of the page and the
  lines round it. Click a line to go to it. The words are looked up at
  lrclib.net by title and artist, and only while this view is on screen.

Dial and Orbit read a record the shell keeps of which desk was on screen, a
file a day under `~/.local/state/quickshell/`. Nothing else reads it and it
does not leave the machine. Without a GPU the empty desk is always Words.

Super+Space, Super+Tab, or a click on the empty page starts a request. Before
anything is typed it offers the windows, projects and applications used last.
Type and the page finishes the sentence; the answers are listed under it, each
run headed by what kind of thing it is:

- "Go to" a window that is open, "Resume" a `ws` project, "Open" an application;
- or say what to do: lock, sleep, quiet, loud, mute, pause, next, log out,
  restart, shut down (the last three ask for Enter a second time), or which
  view the empty desk should show;
- arithmetic after an equals sign, `=12*7`, is worked out, and Enter copies it;
- a bare number goes to that desk;
- Tab, or Super+Shift+V, turns the request to what you have copied.

Super+Escape locks the screen with the same page. It checks the password
against the `swaylock` PAM service. If the lock screen ever misbehaves,
`desktop-menu unlock` from a virtual terminal lets you back in.

`theme` writes the clock's city into the page. For
coordinates in the bottom margin, write them yourself; nothing is looked up:

```sh
echo "52.52 13.40" > ~/.config/dotfiles/place
```

`theme wallpaper picture.jpg --name harvest --layout folio` puts any image at
the foot of the page and takes the palette from it.

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
theme use coast --layout folio
theme use overprint   # the original
```

Make one from any image:

```sh
theme wallpaper ~/Pictures/wallpaper.jpg --name forest
theme wallpaper ~/Pictures/wallpaper.jpg --name forest --layout folio
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
