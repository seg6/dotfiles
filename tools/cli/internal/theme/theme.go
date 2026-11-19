package theme

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sort"
	"strconv"
	"strings"

	"github.com/BurntSushi/toml"
	"github.com/lucasb-eyer/go-colorful"
)

type Theme struct {
	ID        string            `toml:"-"`
	Name      string            `toml:"name"`
	Display   string            `toml:"display"`
	Mode      string            `toml:"mode"`
	Wallpaper string            `toml:"wallpaper,omitempty"`
	Colors    map[string]string `toml:"colors"`
	ANSI      map[string]string `toml:"ansi"`
}

func Run(args []string) {
	command := "apply"
	if len(args) > 0 && !strings.HasPrefix(args[0], "--") {
		command = args[0]
	}
	switch command {
	case "apply":
		applyTheme(repoRoot(), configHome(), !hasArg(args, "--no-reload"))
	case "reload":
		reloadLive()
	case "spotify":
		spotify(repoRoot(), configHome())
	default:
		fmt.Fprintln(os.Stderr, "usage: theme [apply] [--no-reload] | theme reload | theme spotify")
		os.Exit(2)
	}
}

func die(msg string) {
	fmt.Fprintln(os.Stderr, "theme: "+msg)
	os.Exit(1)
}

func repoRoot() string {
	for _, root := range []string{os.Getenv("DOTFILES_ROOT"), os.Getenv("DOTFILES_DIR")} {
		if validRoot(root) {
			return root
		}
	}

	root := strings.TrimSpace(readString(filepath.Join(configHome(), "dotfiles", "root")))
	if validRoot(root) {
		return root
	}
	die("cannot locate the dotfiles checkout; set DOTFILES_DIR")
	return ""
}

func validRoot(root string) bool {
	return root != "" && exists(filepath.Join(root, themeDir, "theme.toml"))
}

func configHome() string {
	if root := os.Getenv("XDG_CONFIG_HOME"); root != "" {
		return root
	}
	home, err := os.UserHomeDir()
	if err != nil {
		die(err.Error())
	}
	return filepath.Join(home, ".config")
}

func hasArg(args []string, arg string) bool {
	for _, candidate := range args {
		if candidate == arg {
			return true
		}
	}
	return false
}

const themeDir = "dotfiles/common/theme"

func loadTheme(root string) Theme {
	theme, err := readTheme(root, "folio")
	if err != nil {
		die(err.Error())
	}
	return theme
}

func readTheme(root, name string) (Theme, error) {
	path := filepath.Join(root, themeDir, "theme.toml")
	var theme Theme
	metadata, err := toml.DecodeFile(path, &theme)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return Theme{}, fmt.Errorf("unknown theme: %s", name)
		}
		return Theme{}, fmt.Errorf("read theme %s: %w", name, err)
	}
	if undecoded := metadata.Undecoded(); len(undecoded) > 0 {
		keys := make([]string, 0, len(undecoded))
		for _, key := range undecoded {
			keys = append(keys, key.String())
		}
		return Theme{}, fmt.Errorf("theme %s has unknown key(s): %s", name, strings.Join(keys, ", "))
	}
	theme.ID = name
	if theme.Colors == nil {
		theme.Colors = make(map[string]string)
	}
	if theme.ANSI == nil {
		theme.ANSI = make(map[string]string)
	}
	if theme.Wallpaper != "" && !filepath.IsAbs(theme.Wallpaper) {
		theme.Wallpaper = filepath.Join(filepath.Dir(path), theme.Wallpaper)
	}
	if err := validateTheme(theme); err != nil {
		return Theme{}, err
	}
	return theme, nil
}

func validateTheme(theme Theme) error {
	if strings.TrimSpace(theme.Name) == "" {
		return fmt.Errorf("theme %s is missing name", theme.ID)
	}
	if strings.TrimSpace(theme.Display) == "" {
		return fmt.Errorf("theme %s is missing display", theme.ID)
	}
	if theme.Mode != "dark" && theme.Mode != "light" {
		return fmt.Errorf("theme %s has invalid mode %q", theme.ID, theme.Mode)
	}

	required := []string{"bg", "bg_alt", "surface", "surface_alt", "fg", "dim", "accent", "red", "green", "yellow", "blue", "magenta", "cyan"}
	for _, key := range required {
		if theme.Colors[key] == "" {
			return fmt.Errorf("theme %s is missing colors.%s", theme.ID, key)
		}
	}
	for section, colors := range map[string]map[string]string{"colors": theme.Colors, "ansi": theme.ANSI} {
		for key, value := range colors {
			if !validHexColor(value) {
				return fmt.Errorf("theme %s has invalid %s.%s %q", theme.ID, section, key, value)
			}
		}
	}

	return nil
}

func validHexColor(value string) bool {
	if len(value) != 7 || value[0] != '#' {
		return false
	}
	_, err := strconv.ParseUint(value[1:], 16, 24)
	return err == nil
}

func applyTheme(root, config string, shouldReload bool) {
	generateTheme(root, config, loadTheme(root))
	if shouldReload {
		reloadLive()
	}
}

func generateTheme(root, config string, theme Theme) {
	if runtime.GOOS == "linux" {
		generateSway(root, config, theme)
		generateGTK(config, theme)
		generateShell(root, config, theme)
	}
	generateKitty(config, theme, runtime.GOOS == "linux")
	// Sway reads the wallpaper from its generated theme; macOS is told on reload.
	write(filepath.Join(config, "dotfiles/wallpaper"), wallpaperPath(root, theme))
	generateHelix(config, theme)
	generateTmux(config, theme)
	generateWS(config, theme)
	if runtime.GOOS == "linux" {
		generateDesktop(root, config, theme)
	}
}

func c(theme Theme, key string) string {
	value := theme.Colors[key]
	if value == "" {
		die(theme.ID + " missing colors." + key)
	}
	return value
}

func role(theme Theme, key, fallback string) string {
	if value := theme.Colors[key]; value != "" {
		return value
	}
	if fallback == "ink" {
		return role(theme, "ink", "surface_alt")
	}
	return c(theme, fallback)
}

func ansi(theme Theme, key, fallback string) string {
	if value := theme.ANSI[key]; value != "" {
		return value
	}
	if fallback != "" {
		return fallback
	}
	return c(theme, key)
}

func generateShell(root, config string, theme Theme) {
	palette, err := json.MarshalIndent(theme.Colors, "", "  ")
	if err != nil {
		die(err.Error())
	}
	write(filepath.Join(config, "quickshell/folio/colors.json"), string(palette))
	write(filepath.Join(config, "quickshell/folio/who.json"), whoAndWhere(config))
	if wallpaper := wallpaperPath(root, theme); wallpaper != "" {
		if err := writePage(wallpaper, filepath.Join(config, "quickshell/folio/page.png"), c(theme, "bg"), c(theme, "fg")); err != nil {
			fmt.Fprintln(os.Stderr, "theme: page picture: "+err.Error())
		}
	}
	writeMode(filepath.Join(config, "dotfiles/lock"), "#!/bin/sh\nexec "+lockCommand(theme)+"\n", 0o755)
}

func generateSway(root, config string, theme Theme) {
	line := c(theme, "fg")
	if ink, err := colorful.Hex(c(theme, "fg")); err == nil {
		if paper, err := colorful.Hex(c(theme, "bg")); err == nil {
			line = ink.BlendLab(paper, 0.32).Clamped().Hex()
		}
	}
	write(filepath.Join(config, "sway/theme"), fmt.Sprintf(`set $bg %s
set $fg %s
set $surface %s
set $surface_alt %s
set $line %s
set $accent %s
set $dim %s
set $urgent %s

set $lock %s
set $nagstyle "background=%s; border=%s; border-bottom=%s; button-background=%s; text=%s; button-text=%s; message-padding=12; button-padding=8"
`, c(theme, "bg"), c(theme, "fg"), c(theme, "surface"), c(theme, "surface_alt"), line, c(theme, "accent"), c(theme, "dim"), c(theme, "red"), lockCommand(theme), c(theme, "surface"), c(theme, "red"), c(theme, "surface_alt"), c(theme, "bg"), c(theme, "fg"), c(theme, "fg")))
}

// wallpaperPath is the theme's wallpaper, or "" when it has none on disk.
func wallpaperPath(root string, theme Theme) string {
	wallpaper := theme.Wallpaper
	if wallpaper == "" || !exists(wallpaper) {
		return ""
	}
	return wallpaper
}

func lockCommand(theme Theme) string {
	bg := hex(c(theme, "bg"))
	fg := hex(c(theme, "fg"))
	return strings.Join([]string{
		"swaylock -f",
		"--color " + bg,
		"--inside-color " + bg,
		"--ring-color " + hex(c(theme, "accent")),
		"--line-color " + bg,
		"--separator-color " + bg,
		"--inside-clear-color " + bg,
		"--ring-clear-color " + hex(c(theme, "yellow")),
		"--inside-ver-color " + bg,
		"--ring-ver-color " + hex(c(theme, "cyan")),
		"--inside-wrong-color " + bg,
		"--ring-wrong-color " + hex(c(theme, "red")),
		"--key-hl-color " + fg,
		"--bs-hl-color " + hex(c(theme, "red")),
		"--text-color " + fg,
		"--text-clear-color " + fg,
		"--text-ver-color " + fg,
		"--text-wrong-color " + fg,
	}, " ")
}

func generateGTK(config string, theme Theme) {
	content := fmt.Sprintf(`@define-color window_bg_color %s;
@define-color window_fg_color %s;
@define-color view_bg_color %s;
@define-color view_fg_color %s;
@define-color accent_color %s;
@define-color accent_bg_color %s;
@define-color accent_fg_color %s;
@define-color headerbar_bg_color %s;
@define-color headerbar_fg_color %s;
@define-color headerbar_border_color rgba(%s, 0.80);
@define-color headerbar_backdrop_color @window_bg_color;
@define-color headerbar_shade_color rgba(0, 0, 0, 0.20);
@define-color card_bg_color %s;
@define-color card_fg_color %s;
@define-color card_shade_color rgba(0, 0, 0, 0.20);
@define-color dialog_bg_color %s;
@define-color dialog_fg_color %s;
@define-color popover_bg_color %s;
@define-color popover_fg_color %s;
@define-color destructive_color %s;
@define-color destructive_bg_color %s;
@define-color destructive_fg_color %s;
@define-color success_color %s;
@define-color success_bg_color %s;
@define-color success_fg_color %s;
@define-color warning_color %s;
@define-color warning_bg_color %s;
@define-color warning_fg_color %s;
@define-color error_color %s;
@define-color error_bg_color %s;
@define-color error_fg_color %s;
@define-color shade_color rgba(0, 0, 0, 0.20);
@define-color scrollbar_outline_color rgba(%s, 0.50);
@define-color sidebar_bg_color %s;
@define-color sidebar_fg_color %s;
@define-color sidebar_backdrop_color %s;
@define-color sidebar_shade_color rgba(0, 0, 0, 0.20);
`, c(theme, "bg"), c(theme, "fg"), c(theme, "bg_alt"), c(theme, "fg"), c(theme, "accent"), c(theme, "accent"), c(theme, "bg"), c(theme, "surface"), c(theme, "fg"), rgb(c(theme, "surface_alt")), c(theme, "surface"), c(theme, "fg"), c(theme, "surface"), c(theme, "fg"), c(theme, "surface"), c(theme, "fg"), c(theme, "red"), c(theme, "red"), c(theme, "bg"), c(theme, "green"), c(theme, "green"), c(theme, "bg"), c(theme, "yellow"), c(theme, "yellow"), c(theme, "bg"), c(theme, "red"), ansi(theme, "bright_red", c(theme, "red")), c(theme, "bg"), rgb(c(theme, "surface_alt")), c(theme, "bg_alt"), c(theme, "fg"), c(theme, "bg_alt"))
	// GTK 3's legacy names and libadwaita's GTK 4 variables need both palettes.
	content += fmt.Sprintf(`
@define-color theme_bg_color %s;
@define-color theme_fg_color %s;
@define-color theme_base_color %s;
@define-color theme_text_color %s;
@define-color theme_selected_bg_color %s;
@define-color theme_selected_fg_color %s;
@define-color borders %s;
@define-color unfocused_borders %s;
`, c(theme, "bg"), c(theme, "fg"), c(theme, "bg_alt"), c(theme, "fg"), c(theme, "accent"), c(theme, "bg"), c(theme, "surface_alt"), c(theme, "surface"))
	header := c(theme, "surface")
	write(filepath.Join(config, "gtk-3.0/gtk.css"), content)
	modern := content + "\n/* libadwaita 1.6+ uses CSS custom properties. */\n:root {\n"
	values := map[string]string{
		"accent-bg-color": c(theme, "accent"), "accent-fg-color": c(theme, "bg"), "accent-color": c(theme, "accent"),
		"window-bg-color": c(theme, "bg"), "window-fg-color": c(theme, "fg"), "view-bg-color": c(theme, "bg_alt"), "view-fg-color": c(theme, "fg"),
		"headerbar-bg-color": header, "headerbar-fg-color": c(theme, "fg"), "headerbar-backdrop-color": header, "headerbar-border-color": c(theme, "surface_alt"),
		"sidebar-bg-color": c(theme, "bg_alt"), "sidebar-fg-color": c(theme, "fg"), "sidebar-backdrop-color": c(theme, "bg_alt"),
		"card-bg-color": c(theme, "surface"), "card-fg-color": c(theme, "fg"), "dialog-bg-color": c(theme, "surface"), "dialog-fg-color": c(theme, "fg"),
		"popover-bg-color": c(theme, "surface"), "popover-fg-color": c(theme, "fg"), "destructive-bg-color": c(theme, "red"), "destructive-fg-color": c(theme, "bg"),
		"success-bg-color": c(theme, "green"), "success-fg-color": c(theme, "bg"), "warning-bg-color": c(theme, "yellow"), "warning-fg-color": c(theme, "bg"), "error-bg-color": c(theme, "red"), "error-fg-color": c(theme, "bg"),
	}
	names := make([]string, 0, len(values))
	for name := range values {
		names = append(names, name)
	}
	sort.Strings(names)
	for _, name := range names {
		modern += "  --" + name + ": " + values[name] + ";\n"
	}
	modern += "}\n"
	write(filepath.Join(config, "gtk-4.0/gtk.css"), modern)
}

func generateKitty(config string, theme Theme, desktop bool) {
	target := filepath.Join(config, "kitty/current-theme.conf")
	content := fmt.Sprintf(`background %s
foreground %s
cursor %s
selection_background %s
selection_foreground %s

color0 %s
color1 %s
color2 %s
color3 %s
color4 %s
color5 %s
color6 %s
color7 %s
color8 %s
color9 %s
color10 %s
color11 %s
color12 %s
color13 %s
color14 %s
color15 %s
`, c(theme, "bg"), c(theme, "fg"), ansi(theme, "cursor", c(theme, "accent")), ansi(theme, "selection", c(theme, "surface_alt")), c(theme, "fg"), ansi(theme, "black", c(theme, "bg_alt")), ansi(theme, "red", c(theme, "red")), ansi(theme, "green", c(theme, "green")), ansi(theme, "yellow", c(theme, "yellow")), ansi(theme, "blue", c(theme, "blue")), ansi(theme, "magenta", c(theme, "magenta")), ansi(theme, "cyan", c(theme, "cyan")), ansi(theme, "white", c(theme, "fg")), ansi(theme, "bright_black", c(theme, "dim")), ansi(theme, "bright_red", c(theme, "red")), ansi(theme, "bright_green", c(theme, "green")), ansi(theme, "bright_yellow", c(theme, "yellow")), ansi(theme, "bright_blue", c(theme, "blue")), ansi(theme, "bright_magenta", c(theme, "magenta")), ansi(theme, "bright_cyan", c(theme, "cyan")), ansi(theme, "bright_white", c(theme, "fg")))
	tabs := []string{c(theme, "bg"), c(theme, "accent"), c(theme, "dim"), c(theme, "bg_alt")}
	if desktop {
		tabs = []string{c(theme, "fg"), c(theme, "bg"), c(theme, "dim"), c(theme, "bg")}
	}
	content += fmt.Sprintf(`
active_tab_foreground %s
active_tab_background %s
inactive_tab_foreground %s
inactive_tab_background %s
`, tabs[0], tabs[1], tabs[2], tabs[3])
	write(target, content)
}

func generateTmux(config string, theme Theme) {
	content := ""
	for _, key := range []string{"bg", "fg", "dim", "red", "surface", "surface_alt"} {
		content += fmt.Sprintf("set -g @%s %q\n", key, c(theme, key))
	}
	write(filepath.Join(config, "tmux/theme.conf"), content)
}

func generateHelix(config string, theme Theme) {
	content := `"ui.background" = { bg = "bg" }
"ui.text" = "fg"
"ui.text.focus" = { fg = "accent", modifiers = ["bold"] }
"ui.text.inactive" = "dim"
"ui.gutter" = { bg = "bg" }
"ui.linenr" = "dim"
"ui.linenr.selected" = "accent"
"ui.cursor" = { fg = "bg", bg = "accent" }
"ui.cursor.match" = { bg = "surface_alt" }
"ui.cursorline.primary" = { bg = "surface" }
"ui.selection" = { bg = "surface_alt" }
"ui.statusline" = { fg = "fg", bg = "bg" }
"ui.statusline.inactive" = { fg = "dim", bg = "bg" }
"ui.statusline.normal" = { fg = "bg", bg = "accent", modifiers = ["bold"] }
"ui.statusline.insert" = { fg = "bg", bg = "green", modifiers = ["bold"] }
"ui.statusline.select" = { fg = "bg", bg = "magenta", modifiers = ["bold"] }
"ui.popup" = { fg = "fg", bg = "surface" }
"ui.popup.info" = { fg = "fg", bg = "surface" }
"ui.window" = "surface_alt"
"ui.help" = { fg = "fg", bg = "surface" }
"ui.menu" = { fg = "fg", bg = "surface" }
"ui.menu.selected" = { fg = "bg", bg = "accent", modifiers = ["bold"] }
"ui.menu.scroll" = { fg = "dim", bg = "surface" }
"ui.virtual" = "dim"
"ui.virtual.inlay-hint" = "dim"
"ui.virtual.jump-label" = { fg = "bg", bg = "magenta", modifiers = ["bold"] }
"comment" = { fg = "dim", modifiers = ["italic"] }
"keyword" = "magenta"
"keyword.control" = "magenta"
"operator" = "magenta"
"punctuation" = "fg"
"string" = "green"
"constant" = "accent"
"constant.builtin" = "accent"
"constant.numeric" = "red"
"type" = "cyan"
"type.builtin" = "cyan"
"function" = "accent"
"function.macro" = "magenta"
"variable" = "fg"
"variable.parameter" = "red"
"variable.builtin" = "cyan"
"constructor" = "accent"
"attribute" = "cyan"
"namespace" = "cyan"
"label" = "accent"
"special" = "magenta"
"markup.heading" = { fg = "accent", modifiers = ["bold"] }
"markup.bold" = { modifiers = ["bold"] }
"markup.italic" = { modifiers = ["italic"] }
"markup.link.url" = { fg = "cyan", modifiers = ["underlined"] }
"markup.link.text" = "magenta"
"markup.raw" = "green"
"markup.list" = "accent"
"diff.plus" = "green"
"diff.minus" = "red"
"diff.delta" = "accent"
"error" = "red"
"warning" = "yellow"
"info" = "cyan"
"hint" = "dim"
"diagnostic.error" = { underline = { color = "red", style = "curl" } }
"diagnostic.warning" = { underline = { color = "yellow", style = "curl" } }
"diagnostic.info" = { underline = { color = "cyan", style = "curl" } }
"diagnostic.hint" = { underline = { color = "dim", style = "curl" } }

[palette]
`
	keys := make([]string, 0, len(theme.Colors))
	for key := range theme.Colors {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	for _, key := range keys {
		content += fmt.Sprintf("%s = %q\n", key, theme.Colors[key])
	}
	write(filepath.Join(config, "helix/themes/generated.toml"), content)
}

func reloadLive() {
	var commands [][]string
	if runtime.GOOS == "linux" {
		commands = append(commands, []string{"swaymsg", "reload"})
		commands = append(commands, []string{"systemctl", "--user", "start", "desktop-shell.service"})
	}
	if runtime.GOOS == "linux" {
		if _, err := exec.LookPath("gsettings"); err == nil {
			var settings map[string]string
			if json.Unmarshal([]byte(readString(filepath.Join(configHome(), "dotfiles/desktop-settings.json"))), &settings) == nil {
				for key, value := range settings {
					if key != "cursor-size" {
						value = strconv.Quote(value)
					}
					commands = append(commands, []string{"gsettings", "set", "org.gnome.desktop.interface", key, value})
				}
			}
		}
	}
	if runtime.GOOS == "darwin" {
		if wallpaper := strings.TrimSpace(readString(filepath.Join(configHome(), "dotfiles/wallpaper"))); wallpaper != "" {
			commands = append(commands, []string{"osascript", "-e", "tell application \"System Events\" to tell every desktop to set picture to " + strconv.Quote(wallpaper)})
		}
	}
	commands = append(commands, []string{"tmux", "source-file", filepath.Join(configHome(), "tmux", "tmux.conf")})
	commands = append(commands, []string{"pkill", "-USR1", "-u", strconv.Itoa(os.Getuid()), "-x", "kitty"})
	commands = append(commands, []string{"pkill", "-USR1", "-u", strconv.Itoa(os.Getuid()), "-x", "hx"})
	if _, err := exec.LookPath("spicetify"); err == nil && spotifyUsesFolio(configHome()) {
		commands = append(commands, []string{"spicetify", "refresh", "--no-restart"})
	}
	for _, command := range commands {
		output, err := exec.Command(command[0], command[1:]...).CombinedOutput()
		if err == nil {
			if command[0] == "spicetify" {
				fmt.Println("Spotify colors refreshed; reopen Spotify to load them.")
			}
			continue
		}
		if command[0] == "pkill" {
			var status *exec.ExitError
			if errors.As(err, &status) && status.ExitCode() == 1 {
				continue
			}
		}

		detail := strings.TrimSpace(string(output))
		if command[0] == "tmux" && (strings.Contains(detail, "no server running") || strings.Contains(detail, "failed to connect")) {
			continue
		}
		if detail == "" {
			detail = err.Error()
		}
		fmt.Fprintf(os.Stderr, "theme: reload failed (%s): %s\n", strings.Join(command, " "), detail)
	}
}

func spotifyUsesFolio(config string) bool {
	section := ""
	for _, line := range strings.Split(readString(filepath.Join(config, "spicetify/config-xpui.ini")), "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "[") && strings.HasSuffix(line, "]") {
			section = strings.TrimSpace(line[1 : len(line)-1])
			continue
		}
		key, value, ok := strings.Cut(line, "=")
		if ok && section == "Setting" && strings.TrimSpace(key) == "current_theme" {
			return strings.TrimSpace(value) == "Folio"
		}
	}
	return false
}

func enable(value bool) string {
	if value {
		return "enable"
	}
	return "disable"
}

func readString(path string) string {
	data, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return string(data)
}

func write(path, content string) {
	directory := filepath.Dir(path)
	if err := os.MkdirAll(directory, 0o755); err != nil {
		die(err.Error())
	}
	content = strings.TrimRight(content, "\n") + "\n"
	temporary, err := os.CreateTemp(directory, "."+filepath.Base(path)+".*")
	if err != nil {
		die(err.Error())
	}
	temporaryPath := temporary.Name()
	defer os.Remove(temporaryPath)
	if err := temporary.Chmod(0o644); err != nil {
		temporary.Close()
		die(err.Error())
	}
	if _, err := temporary.WriteString(content); err != nil {
		temporary.Close()
		die(err.Error())
	}
	if err := temporary.Sync(); err != nil {
		temporary.Close()
		die(err.Error())
	}
	if err := temporary.Close(); err != nil {
		die(err.Error())
	}
	if err := os.Rename(temporaryPath, path); err != nil {
		die(err.Error())
	}
}

func writeMode(path, content string, mode os.FileMode) {
	write(path, content)
	if err := os.Chmod(path, mode); err != nil {
		die(err.Error())
	}
}

func exists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func hex(value string) string {
	return strings.TrimPrefix(value, "#")
}

func rgb(value string) string {
	value = hex(value)
	if len(value) != 6 {
		return "0, 0, 0"
	}
	r, _ := strconv.ParseInt(value[0:2], 16, 64)
	g, _ := strconv.ParseInt(value[2:4], 16, 64)
	b, _ := strconv.ParseInt(value[4:6], 16, 64)
	return fmt.Sprintf("%d, %d, %d", r, g, b)
}
