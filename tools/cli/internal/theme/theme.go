package theme

import (
	"encoding/json"
	"errors"
	"fmt"
	"math/rand"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sort"
	"strconv"
	"strings"

	"github.com/BurntSushi/toml"
)

type Theme struct {
	ID        string            `toml:"-"`
	Name      string            `toml:"name"`
	Display   string            `toml:"display"`
	Mode      string            `toml:"mode"`
	Layout    string            `toml:"layout,omitempty"`
	Wallpaper string            `toml:"wallpaper,omitempty"`
	Colors    map[string]string `toml:"colors"`
	ANSI      map[string]string `toml:"ansi"`
	UI        map[string]any    `toml:"ui"`
}

func Run(args []string) {
	if len(args) < 1 {
		usage()
	}
	root := repoRoot()
	config := configHome()

	switch args[0] {
	case "wallpaper":
		if err := wallpaperCommand(root, config, args[1:]); err != nil {
			die(err.Error())
		}
	case "list":
		listThemes(root, config)
	case "current":
		currentTheme(root, config)
	case "use":
		if len(args) < 2 || strings.HasPrefix(args[1], "--") {
			die("usage: theme use <name> [--layout overprint|folio] [--no-reload]")
		}
		useTheme(root, config, args[1], argValue(args, "--layout"), !hasArg(args, "--no-reload"))
	case "layout":
		if len(args) < 2 || strings.HasPrefix(args[1], "--") {
			fmt.Println(storedLayout(config))
			return
		}
		name := selectedTheme(root, config)
		if name == "" {
			die("no current theme selected")
		}
		useTheme(root, config, name, args[1], !hasArg(args, "--no-reload"))
	case "apply":
		name := selectedTheme(root, config)
		if len(args) >= 2 && !strings.HasPrefix(args[1], "--") {
			name = args[1]
		}
		if name == "" {
			die("no current theme selected")
		}
		applyTheme(root, config, name, !hasArg(args, "--no-reload"))
	case "random":
		names := themeNames(root)
		if len(names) == 0 {
			die("no themes found")
		}
		useTheme(root, config, names[rand.Intn(len(names))], "", !hasArg(args, "--no-reload"))
	case "reload":
		reloadLive()
	default:
		usage()
	}
}

func usage() {
	fmt.Fprintln(os.Stderr, "usage: theme list|current|apply [name]|use <name> [--layout name]|layout [overprint|folio]|wallpaper <image> [--name name] [--layout name] [--preview]|random|reload")
	os.Exit(2)
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
	return root != "" && exists(filepath.Join(root, "themes"))
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

// argValue is the word after flag, or "" when the flag is absent.
func argValue(args []string, flag string) string {
	for i, candidate := range args[:max(len(args)-1, 0)] {
		if candidate == flag {
			return args[i+1]
		}
	}
	return ""
}

// A layout is a whole desktop: shell, window frames, spacing, and how each
// program is dressed. Any palette can be used with either.
var layouts = []string{"overprint", "folio"}

func validLayout(name string) bool {
	for _, layout := range layouts {
		if name == layout {
			return true
		}
	}
	return false
}

func layoutPath(config string) string { return filepath.Join(config, "dotfiles/layout") }

func storedLayout(config string) string {
	if layout := strings.TrimSpace(readString(layoutPath(config))); validLayout(layout) {
		return layout
	}
	return "overprint"
}

func folio(theme Theme) bool { return theme.Layout == "folio" }

// layoutName is the theme's layout; a theme that names none is Overprint.
func layoutName(theme Theme) string {
	if theme.Layout == "" {
		return "overprint"
	}
	return theme.Layout
}

func themeNames(root string) []string {
	names := map[string]bool{}
	for _, directory := range []string{filepath.Join(root, "themes"), userThemeDir(configHome())} {
		entries, err := os.ReadDir(directory)
		if err != nil {
			continue
		}
		for _, entry := range entries {
			if entry.IsDir() && exists(filepath.Join(directory, entry.Name(), "theme.toml")) {
				names[entry.Name()] = true
			}
		}
	}
	result := make([]string, 0, len(names))
	for name := range names {
		result = append(result, name)
	}
	sort.Strings(result)
	return result
}

func listThemes(root, config string) {
	current := selectedTheme(root, config)
	for _, name := range themeNames(root) {
		theme := loadTheme(root, name)
		marker := " "
		if current == name {
			marker = "*"
		}
		display := theme.Display
		if display == "" {
			display = theme.Name
		}
		fmt.Printf("%s %-22s %s\n", marker, name, display)
	}
}

func currentTheme(root, config string) {
	current := selectedTheme(root, config)
	if current == "" {
		current = "none"
	}
	fmt.Println(current)
}

func selectedTheme(root, config string) string {
	current := strings.TrimSpace(readString(themeSelectionPath(config)))
	if validThemeName(current) && (exists(filepath.Join(root, "themes", current, "theme.toml")) ||
		exists(filepath.Join(userThemeDir(config), current, "theme.toml"))) {
		return current
	}
	return strings.TrimSpace(readString(filepath.Join(root, "themes", "default")))
}

func themeSelectionPath(config string) string {
	return filepath.Join(config, "dotfiles", "theme")
}

func loadTheme(root, name string) Theme {
	theme, err := readTheme(root, name)
	if err != nil {
		die(err.Error())
	}
	return theme
}

func readTheme(root, name string) (Theme, error) {
	if !validThemeName(name) {
		return Theme{}, fmt.Errorf("invalid theme name: %s", name)
	}
	path := filepath.Join(root, "themes", name, "theme.toml")
	if !exists(path) {
		path = filepath.Join(userThemeDir(configHome()), name, "theme.toml")
	}
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
	if theme.UI == nil {
		theme.UI = make(map[string]any)
	}
	// A relative wallpaper belongs to the theme's own directory, so a saved
	// palette keeps working when its directory is moved into the repository.
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
	if theme.Layout != "" && !validLayout(theme.Layout) {
		return fmt.Errorf("theme %s layout must be one of %s", theme.ID, strings.Join(layouts, ", "))
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

	for key, value := range theme.UI {
		switch key {
		case "radius":
			radius, ok := integerValue(value)
			if !ok || radius < 0 || radius > 32 {
				return fmt.Errorf("theme %s ui.radius must be between 0 and 32", theme.ID)
			}
		case "shadow", "blur":
			if _, ok := value.(bool); !ok {
				return fmt.Errorf("theme %s ui.%s must be a boolean", theme.ID, key)
			}
		default:
			return fmt.Errorf("theme %s has unknown ui key %s", theme.ID, key)
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

func integerValue(value any) (int, bool) {
	switch value := value.(type) {
	case int64:
		return int(value), true
	case int:
		return value, true
	default:
		return 0, false
	}
}

// useTheme selects a theme. It takes the layout asked for, or the theme's own,
// so choosing a plain palette returns to Overprint.
func useTheme(root, config, name, layout string, shouldReload bool) {
	theme := loadTheme(root, name)
	if layout != "" {
		if !validLayout(layout) {
			die("unknown layout " + layout + "; choose " + strings.Join(layouts, " or "))
		}
		theme.Layout = layout
	}
	if theme.Layout == "" {
		theme.Layout = "overprint"
	}
	generateTheme(root, config, theme)
	write(themeSelectionPath(config), name)
	finishTheme(name, shouldReload)
}

// applyTheme regenerates files for a theme in the layout already in use.
func applyTheme(root, config, name string, shouldReload bool) {
	theme := loadTheme(root, name)
	if exists(layoutPath(config)) {
		theme.Layout = storedLayout(config)
	} else if theme.Layout == "" {
		theme.Layout = "overprint"
	}
	generateTheme(root, config, theme)
	finishTheme(name, shouldReload)
}

func generateTheme(root, config string, theme Theme) {
	if theme.Layout == "" {
		theme.Layout = "overprint"
	}
	// The other layout's shell is still running; the next reload replaces it,
	// and the new shell reframes the windows that are already open.
	if exists(layoutPath(config)) && storedLayout(config) != theme.Layout {
		write(filepath.Join(config, "dotfiles/layout-changed"), theme.Layout)
	}
	write(layoutPath(config), theme.Layout)
	if runtime.GOOS == "linux" {
		generateSway(root, config, theme)
		generateGTK(config, theme)
		generateShell(root, config, theme)
	}
	generateKitty(root, config, theme, runtime.GOOS == "linux")
	// Sway reads the wallpaper from its generated theme; macOS is told on reload.
	write(filepath.Join(config, "dotfiles/wallpaper"), wallpaperPath(root, theme))
	generateHelix(config, theme)
	generateTmux(config, theme)
	generateWS(config, theme)
	if runtime.GOOS == "linux" {
		generateDesktop(root, config, theme)
	}
}

func finishTheme(name string, shouldReload bool) {
	if shouldReload {
		reloadLive()
	}
	fmt.Println("theme: using " + name)
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

func uiInt(theme Theme, key string, fallback int) int {
	value, ok := integerValue(theme.UI[key])
	if !ok {
		return fallback
	}
	return value
}

func uiBool(theme Theme, key string, fallback bool) bool {
	value, ok := theme.UI[key].(bool)
	if !ok {
		return fallback
	}
	return value
}

func generateShell(root, config string, theme Theme) {
	palette, err := json.MarshalIndent(theme.Colors, "", "  ")
	if err != nil {
		die(err.Error())
	}
	write(filepath.Join(config, "quickshell", layoutName(theme), "colors.json"), string(palette))
	if folio(theme) {
		write(filepath.Join(config, "quickshell/folio/who.json"), whoAndWhere(config))
		// The picture at the foot of the page: the theme's wallpaper in two colors.
		if wallpaper := wallpaperPath(root, theme); wallpaper != "" {
			if err := writePage(wallpaper, filepath.Join(config, "quickshell/folio/page.png"), c(theme, "bg"), c(theme, "fg")); err != nil {
				fmt.Fprintln(os.Stderr, "theme: page picture: "+err.Error())
			}
		}
	}
	// The shell locks the screen with the same command Sway binds.
	writeMode(filepath.Join(config, "dotfiles/lock"), "#!/bin/sh\nexec "+lockCommand(theme)+"\n", 0o755)
}

func generateSway(root, config string, theme Theme) {
	shadow := enable(uiBool(theme, "shadow", true))
	header := role(theme, "header", "surface_alt")
	ink := role(theme, "shadow", "ink")
	content := fmt.Sprintf(`output * bg %s solid_color

set $bg %s
set $fg %s
set $surface %s
set $accent %s
set $dim %s
set $urgent %s

set $lock %s
set $nagstyle "background=%s; border=%s; border-bottom=%s; button-background=%s; text=%s; button-text=%s; message-padding=12; button-padding=8"

# Generated by theme use %s.
`, c(theme, "bg"), c(theme, "bg"), c(theme, "fg"), c(theme, "surface"), c(theme, "accent"), c(theme, "dim"), c(theme, "red"), lockCommand(theme), c(theme, "surface"), c(theme, "red"), c(theme, "surface_alt"), c(theme, "bg"), c(theme, "fg"), c(theme, "fg"), theme.ID)
	if folio(theme) {
		content += folioSway(theme)
	} else {
		content += fmt.Sprintf(`# Sway supplies the window headings; the shell keeps Kitty headings visible in both layouts.
default_border pixel 2
default_floating_border normal 2
title_align left
default_dim_inactive 0.0
animation_duration_ms 0
font pango:Fantasque Sans Mono 12
titlebar_padding 14 16
titlebar_border_thickness 2
titlebar_separator disable
client.focused          $accent   %s $fg  $accent $accent
client.focused_inactive $dim      %s $dim $dim    $dim
client.unfocused        $bg       %s $dim $bg     $bg
client.urgent           $urgent   $surface $fg $urgent $urgent

corner_radius %d
smart_corner_radius enable
shadows %s
shadows_on_csd %s
shadow_blur_radius 1
shadow_color %s75
shadow_inactive_color %s44
shadow_offset 8 8

blur %s
blur_radius 3
blur_passes 2
blur_noise 0.01
blur_brightness 0.82
blur_contrast 1.05
blur_saturation 0.95

layer_effects "overprint" shadows disable
layer_effects "overprint" blur disable
layer_effects "overprint" corner_radius 0
`, header, header, header, uiInt(theme, "radius", 0), shadow, shadow, ink, ink, enable(uiBool(theme, "blur", false)))
	}
	if wallpaper := wallpaperPath(root, theme); wallpaper != "" && !folio(theme) {
		content += fmt.Sprintf("\noutput * bg %s fill\n", strconv.Quote(wallpaper))
	}
	content += "\n"
	var reapply []string
	for _, gap := range []struct {
		side   string
		amount int
	}{{"inner", 48}, {"outer", 0}, {"left", -14}, {"right", 0}, {"top", 16}, {"bottom", 24}} {
		if folio(theme) {
			// The shell's two lines of small type reserve the top and bottom
			// margins themselves; the sides are plain margin.
			gap.amount = map[string]int{"inner": 12, "outer": 0, "left": 36, "right": 36}[gap.side]
		}
		content += fmt.Sprintf("gaps %s %d\n", gap.side, gap.amount)
		reapply = append(reapply, fmt.Sprintf("gaps %s all set %d", gap.side, gap.amount))
	}
	write(filepath.Join(config, "sway/theme"), content)
	// Sway's config defaults affect new workspaces; reload must update existing ones too.
	write(filepath.Join(config, "dotfiles/sway-gaps"), strings.Join(reapply, "; "))
}

// wallpaperPath is the theme's wallpaper, or "" when it has none on disk.
func wallpaperPath(root string, theme Theme) string {
	wallpaper := theme.Wallpaper
	if wallpaper == "" {
		wallpaper = filepath.Join(root, "themes", theme.ID, "wallpaper.png")
	}
	if !exists(wallpaper) {
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
	header := role(theme, "header", "surface_alt")
	if folio(theme) {
		header = c(theme, "surface")
	} else {
		content += fmt.Sprintf(`
window, dialog { background-color: @window_bg_color; color: @window_fg_color; }
headerbar, .titlebar { background: %s; color: %s; border-radius: 0; box-shadow: none; }
button, entry, spinbutton, dropdown, combobox, popover, menu, .card { border-radius: 2px; }
button:checked, button.suggested-action, selection, row:selected { background: @accent_bg_color; color: @accent_fg_color; }
entry:focus, button:focus { outline-color: @accent_color; }
.sidebar, sidebar { background-color: @sidebar_bg_color; }
view, textview text, treeview.view { background-color: @view_bg_color; color: @view_fg_color; }
`, header, c(theme, "fg"))
	}
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

// generateKitty writes the terminal palette. The larger type, padding, and
// heading strip belong to the Sway desktop, whose title bars they are sized
// against; elsewhere Kitty keeps its own layout and only takes the colors.
func generateKitty(root, config string, theme Theme, desktop bool) {
	override := filepath.Join(root, "themes", theme.ID, "kitty.conf")
	target := filepath.Join(config, "kitty/current-theme.conf")
	if exists(override) {
		data, err := os.ReadFile(override)
		if err != nil {
			die(err.Error())
		}
		write(target, string(data))
		return
	}
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
	if desktop && folio(theme) {
		content += folioKitty(theme)
	} else if desktop {
		header := role(theme, "header", "surface_alt")
		content += fmt.Sprintf(`
font_size 18.0
background_opacity 1.0
window_padding_width 16 16 0 16
window_title_bar_min_windows 0
tab_bar_style custom
tab_bar_min_tabs 2
hide_window_decorations no
tab_bar_edge top
tab_bar_align left
tab_bar_margin_width 0
tab_bar_margin_height 12 12
tab_bar_margin_color %s
tab_bar_background %s
active_tab_foreground %s
active_tab_background %s
inactive_tab_foreground %s
inactive_tab_background %s
active_tab_font_style normal
inactive_tab_font_style normal
	`, header, header, role(theme, "header_fg", "fg"), header, role(theme, "header_dim", "dim"), header)
	} else {
		content += fmt.Sprintf(`
active_tab_foreground   %s
active_tab_background   %s
inactive_tab_foreground %s
inactive_tab_background %s
`, c(theme, "bg"), c(theme, "accent"), c(theme, "dim"), c(theme, "bg_alt"))
	}
	write(target, content)
}

func generateTmux(config string, theme Theme) {
	if folio(theme) {
		write(filepath.Join(config, "tmux/theme.conf"), folioTmux(theme))
		return
	}
	ink := role(theme, "ink", "surface_alt")
	content := fmt.Sprintf(`# Generated by theme use %s.
set -g @theme-popup-border "%s"
set -g popup-border-style "fg=#{@theme-popup-border}"
set -g @theme-popup-lines single
set -g popup-border-lines single
set -g @theme-popup-bg "%s"
set -g @theme-popup-fg "%s"
set -g popup-style "bg=#{@theme-popup-bg},fg=#{@theme-popup-fg}"

# A cell-aligned offset shadow, with italic workspace indices.
set -g status 3
set -g set-titles-string '#{?@ws-title,#{@ws-title},#S}:#I:#W'
set -g status-position bottom
set -g status-justify absolute-centre
set -g status-interval 5
set -g status-left-length 40
set -g status-right-length 30
set -g status-style "bg=%s,fg=%s"
set -g status-format[0] '#[fg=%s,bg=default]#{R:─,#{client_width}}'
set -g status-format[1] '#[align=left,range=left]#{T;=/#{status-left-length}:status-left}#[norange,list=on,align=#{status-justify}]#[list=left-marker]<#[list=right-marker]>#[list=on]#{W:#[range=window|#{window_index}]#{T:window-status-format}#[norange],#[range=window|#{window_index},list=focus]#{T:window-status-current-format}#[norange,list=on]}#[nolist,align=right,range=right]#{T;=/#{status-right-length}:status-right}#[norange]'
set -g status-format[2] '#[list=on,align=absolute-centre]#[list=left-marker]<#[list=right-marker]>#[list=on]#{W:#[range=window|#{window_index}]#{T:@theme-shadow-window}#[norange],#[range=window|#{window_index},list=focus]#{T:@theme-shadow-current}#[norange,list=on]}#[nolist]'
set -g status-left '#[fg=%s,bg=default,bold] #{?@ws-title,#{@ws-title},#S} '
set -g status-right '#{?client_prefix,#[fg=%s,bg=%s,bold] PREFIX #[fg=%s,bg=%s,nobold],}#[fg=%s,bg=%s] %%H:%%M '

set -g window-status-separator "#[bg=%s] "
set -g window-status-format "#[fg=%s,bg=default,nobold] #[italics]#I#[noitalics] #W  "
set -g window-status-current-format "#[fg=%s,bg=%s,bold] #[italics]#I#[noitalics,nobold] #W #[fg=%s,bg=default]▄#[default]"
set -g @theme-shadow-window '#{R: ,#{e|+|:4,#{e|+|:#{n:window_index},#{w:window_name}}}}'
set -g @theme-shadow-current '#[fg=%s,bg=default] #{R:▀,#{e|+|:3,#{e|+|:#{n:window_index},#{w:window_name}}}}#[default]'
set -g window-status-last-style "fg=%s,bg=%s"
set -g window-status-activity-style "fg=%s,bg=%s"
set -g window-status-bell-style "fg=%s,bg=%s,bold"

set -g pane-border-lines single
set -g pane-border-style "fg=%s"
set -g pane-active-border-style "fg=%s"
set -g message-style "fg=%s,bg=%s,bold"
set -g message-command-style "fg=%s,bg=%s"
setw -g mode-style "fg=%s,bg=%s,bold"
set -g clock-mode-colour "%s"
`, theme.ID,
		c(theme, "surface_alt"),
		c(theme, "bg"), c(theme, "fg"),
		"default", c(theme, "fg"),
		c(theme, "surface_alt"),
		c(theme, "accent"),
		c(theme, "bg"), c(theme, "yellow"), c(theme, "fg"), "default", c(theme, "dim"), "default",
		"default",
		c(theme, "dim"),
		c(theme, "bg"), c(theme, "accent"), ink,
		ink,
		c(theme, "cyan"), "default",
		c(theme, "yellow"), "default",
		c(theme, "red"), "default",
		c(theme, "surface_alt"),
		c(theme, "accent"),
		c(theme, "bg"), c(theme, "accent"),
		c(theme, "fg"), c(theme, "surface"),
		c(theme, "fg"), c(theme, "surface_alt"),
		c(theme, "accent"),
	)
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
		if gaps := strings.TrimSpace(readString(filepath.Join(configHome(), "dotfiles/sway-gaps"))); gaps != "" {
			commands = append(commands, []string{"swaymsg", gaps})
		}
		// The shell watches its palette file, so it only needs starting after a
		// first install, or replacing when the layout changed.
		changed := filepath.Join(configHome(), "dotfiles/layout-changed")
		if exists(changed) {
			os.Remove(changed)
			commands = append(commands, []string{"systemctl", "--user", "restart", "desktop-shell.service"})
		} else {
			commands = append(commands, []string{"systemctl", "--user", "start", "desktop-shell.service"})
		}
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
	if _, err := exec.LookPath("spicetify"); err == nil && spotifyUsesOverprint(configHome()) {
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

func spotifyUsesOverprint(config string) bool {
	section := ""
	for _, line := range strings.Split(readString(filepath.Join(config, "spicetify/config-xpui.ini")), "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "[") && strings.HasSuffix(line, "]") {
			section = strings.TrimSpace(line[1 : len(line)-1])
			continue
		}
		key, value, ok := strings.Cut(line, "=")
		if ok && section == "Setting" && strings.TrimSpace(key) == "current_theme" {
			return strings.TrimSpace(value) == "Overprint"
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
