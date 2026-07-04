package theme

import (
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
	ID      string                    `toml:"-"`
	Name    string                    `toml:"name"`
	Display string                    `toml:"display"`
	Mode    string                    `toml:"mode"`
	Colors  map[string]string         `toml:"colors"`
	ANSI    map[string]string         `toml:"ansi"`
	UI      map[string]any            `toml:"ui"`
	Apps    map[string]map[string]any `toml:"apps"`
}

func Run(args []string) {
	if len(args) < 1 {
		usage()
	}
	root := repoRoot()
	config := configHome()

	switch args[0] {
	case "list":
		listThemes(root, config)
	case "current":
		currentTheme(root, config)
	case "use":
		if len(args) < 2 {
			die("usage: theme use <name> [--no-reload]")
		}
		useTheme(root, config, args[1], !hasArg(args, "--no-reload"))
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
		useTheme(root, config, names[rand.Intn(len(names))], !hasArg(args, "--no-reload"))
	case "reload":
		reloadLive()
	default:
		usage()
	}
}

func usage() {
	fmt.Fprintln(os.Stderr, "usage: theme list|current|apply [name]|use <name>|random|reload")
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

func themeNames(root string) []string {
	entries, err := os.ReadDir(filepath.Join(root, "themes"))
	if err != nil {
		return nil
	}
	var names []string
	for _, entry := range entries {
		if entry.IsDir() && exists(filepath.Join(root, "themes", entry.Name(), "theme.toml")) {
			names = append(names, entry.Name())
		}
	}
	sort.Strings(names)
	return names
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
	if current != "" {
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
	path := filepath.Join(root, "themes", name, "theme.toml")
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
	if theme.Apps == nil {
		theme.Apps = make(map[string]map[string]any)
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

	for appName, values := range theme.Apps {
		for key, value := range values {
			switch {
			case appName == "helix" && key == "theme":
				if text, ok := value.(string); !ok || strings.TrimSpace(text) == "" {
					return fmt.Errorf("theme %s apps.helix.theme must be a non-empty string", theme.ID)
				}
			case appName == "mako" && key == "timeout":
				timeout, ok := integerValue(value)
				if !ok || timeout < 0 {
					return fmt.Errorf("theme %s apps.mako.timeout must be a non-negative integer", theme.ID)
				}
			default:
				return fmt.Errorf("theme %s has unknown app key apps.%s.%s", theme.ID, appName, key)
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

func useTheme(root, config, name string, shouldReload bool) {
	theme := loadTheme(root, name)
	generateTheme(root, config, theme)
	write(themeSelectionPath(config), name)
	finishTheme(name, shouldReload)
}

func applyTheme(root, config, name string, shouldReload bool) {
	theme := loadTheme(root, name)
	generateTheme(root, config, theme)
	finishTheme(name, shouldReload)
}

func generateTheme(root, config string, theme Theme) {
	if runtime.GOOS == "linux" {
		generateSway(config, theme)
		generateWaybar(config, theme)
		generateFuzzel(config, theme)
		generateMako(config, theme)
		generateGTK(config, theme)
	}
	generateKitty(root, config, theme)
	generateHelix(config, theme)
	generateTmux(config, theme)
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

func app(theme Theme, appName, key, fallback string) string {
	values := theme.Apps[appName]
	if values == nil {
		return fallback
	}
	switch value := values[key].(type) {
	case string:
		if value != "" {
			return value
		}
	case int64:
		return strconv.FormatInt(value, 10)
	case int:
		return strconv.Itoa(value)
	}
	return fallback
}

func generateSway(config string, theme Theme) {
	radius := uiInt(theme, "radius", 8)
	shadow := enable(uiBool(theme, "shadow", true))
	blur := enable(uiBool(theme, "blur", true))
	content := fmt.Sprintf(`output * bg %s solid_color

set $bg %s
set $fg %s
set $surface %s
set $accent %s
set $dim %s
set $urgent %s

set $lock %s
set $nagstyle "background=%s; border=%s; border-bottom=%s; button-background=%s; text=%s; button-text=%s; message-padding=12; button-padding=8"

client.focused          $accent   $surface    $fg     $accent     $accent
client.focused_inactive $dim      $bg         $dim    $dim        $dim
client.unfocused        $bg       $bg         $dim    $bg         $bg
client.urgent           $urgent   $surface    $fg     $urgent     $urgent

# Generated by theme use %s.
corner_radius %d
smart_corner_radius enable
shadows %s
shadows_on_csd %s
shadow_blur_radius 18
shadow_color #00000066
shadow_inactive_color #00000044
shadow_offset 0 6

blur %s
blur_radius 3
blur_passes 2
blur_noise 0.01
blur_brightness 0.82
blur_contrast 1.05
blur_saturation 0.95

layer_effects "notifications" shadows disable
layer_effects "notifications" blur disable
layer_effects "notifications" corner_radius %d
layer_effects "fuzzel" shadows %s
layer_effects "fuzzel" corner_radius %d
layer_effects "fuzzel" blur %s
`, c(theme, "bg"), c(theme, "bg"), c(theme, "fg"), c(theme, "surface"), c(theme, "accent"), c(theme, "dim"), c(theme, "red"), lockCommand(theme), c(theme, "surface"), c(theme, "red"), c(theme, "surface_alt"), c(theme, "bg"), c(theme, "fg"), c(theme, "fg"), theme.ID, radius, shadow, shadow, blur, radius, shadow, radius, blur)
	write(filepath.Join(config, "sway/theme"), content)
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

func generateWaybar(config string, theme Theme) {
	content := fmt.Sprintf(`@define-color background %s;
@define-color surface %s;
@define-color surface_alt %s;
@define-color foreground %s;
@define-color dim %s;
@define-color accent %s;
@define-color red %s;
@define-color green %s;
@define-color yellow %s;
@define-color blue %s;
@define-color magenta %s;
@define-color cyan %s;

@define-color background-alpha rgba(%s, 0.92);
@define-color surface-alpha rgba(%s, 0.58);
@define-color accent-alpha rgba(%s, 0.92);
`, c(theme, "bg"), c(theme, "surface"), c(theme, "surface_alt"), c(theme, "fg"), c(theme, "dim"), c(theme, "accent"), c(theme, "red"), c(theme, "green"), c(theme, "yellow"), c(theme, "blue"), c(theme, "magenta"), c(theme, "cyan"), rgb(c(theme, "bg")), rgb(c(theme, "surface")), rgb(c(theme, "accent")))
	write(filepath.Join(config, "waybar/colors.css"), content)
}

func generateFuzzel(config string, theme Theme) {
	radius := uiInt(theme, "radius", 8)
	content := fmt.Sprintf(`[colors]
background=%s
text=%s
match=%s
selection=%s
selection-text=%s
selection-match=%s
border=%s

[border]
radius=%d
selection-radius=%d
`, alpha(c(theme, "bg"), "ee"), alpha(c(theme, "fg"), "ff"), alpha(c(theme, "accent"), "ff"), alpha(c(theme, "surface"), "ff"), alpha(c(theme, "fg"), "ff"), alpha(c(theme, "accent"), "ff"), alpha(c(theme, "surface_alt"), "ff"), radius, max(radius-2, 0))
	write(filepath.Join(config, "fuzzel/colors.ini"), content)
}

func generateMako(config string, theme Theme) {
	radius := uiInt(theme, "radius", 8)
	content := fmt.Sprintf(`font=JetBrainsMono Nerd Font 11
width=360
height=120
margin=10
padding=12
border-size=1
border-radius=%d
icons=1
max-icon-size=48
default-timeout=%s
ignore-timeout=0
anchor=top-right
layer=overlay

background-color=%se6
text-color=%s
border-color=%s
progress-color=over %s

[urgency=low]
border-color=%s
default-timeout=3000

[urgency=normal]
border-color=%s

[urgency=high]
border-color=%s
default-timeout=0
`, radius, app(theme, "mako", "timeout", "6000"), c(theme, "surface"), c(theme, "fg"), c(theme, "surface_alt"), c(theme, "accent"), c(theme, "surface_alt"), c(theme, "accent"), c(theme, "red"))
	write(filepath.Join(config, "mako/config"), content)
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
	write(filepath.Join(config, "gtk-3.0/gtk.css"), content)
	write(filepath.Join(config, "gtk-4.0/gtk.css"), content)
}

func generateKitty(root, config string, theme Theme) {
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

active_tab_foreground   %s
active_tab_background   %s
inactive_tab_foreground %s
inactive_tab_background %s
`, c(theme, "bg"), c(theme, "fg"), ansi(theme, "cursor", c(theme, "accent")), ansi(theme, "selection", c(theme, "surface_alt")), c(theme, "fg"), ansi(theme, "black", c(theme, "bg_alt")), ansi(theme, "red", c(theme, "red")), ansi(theme, "green", c(theme, "green")), ansi(theme, "yellow", c(theme, "yellow")), ansi(theme, "blue", c(theme, "blue")), ansi(theme, "magenta", c(theme, "magenta")), ansi(theme, "cyan", c(theme, "cyan")), ansi(theme, "white", c(theme, "fg")), ansi(theme, "bright_black", c(theme, "dim")), ansi(theme, "bright_red", c(theme, "red")), ansi(theme, "bright_green", c(theme, "green")), ansi(theme, "bright_yellow", c(theme, "yellow")), ansi(theme, "bright_blue", c(theme, "blue")), ansi(theme, "bright_magenta", c(theme, "magenta")), ansi(theme, "bright_cyan", c(theme, "cyan")), ansi(theme, "bright_white", c(theme, "fg")), c(theme, "bg"), c(theme, "accent"), c(theme, "dim"), c(theme, "bg_alt"))
	write(target, content)
}

func generateHelix(config string, theme Theme) {
	hx := app(theme, "helix", "theme", "")
	if hx == "" {
		return
	}
	content := fmt.Sprintf(`inherits = %q

"ui.statusline" = { fg = "generated_status_fg", bg = "generated_status_bg" }
"ui.statusline.inactive" = { fg = "generated_status_dim", bg = "generated_status_bg" }
"ui.statusline.normal" = { fg = "generated_mode_normal", bg = "generated_mode_bg", modifiers = ["bold"] }
"ui.statusline.insert" = { fg = "generated_mode_insert", bg = "generated_mode_bg", modifiers = ["bold"] }
"ui.statusline.select" = { fg = "generated_mode_select", bg = "generated_mode_bg", modifiers = ["bold"] }

[palette]
generated_status_bg = %q
generated_status_fg = %q
generated_status_dim = %q
generated_mode_bg = %q
generated_mode_normal = %q
generated_mode_insert = %q
generated_mode_select = %q
`, hx, c(theme, "bg"), c(theme, "fg"), c(theme, "dim"), c(theme, "bg"), c(theme, "accent"), c(theme, "green"), c(theme, "magenta"))
	write(filepath.Join(config, "helix/themes/generated.toml"), content)
}

func generateTmux(config string, theme Theme) {
	content := fmt.Sprintf(`# Generated by theme use %s.
set -g @theme-popup-border "%s"

set -g status 2
set -g status-position bottom
set -g status-justify absolute-centre
set -g status-interval 5
set -g status-left-length 40
set -g status-right-length 30
set -g status-style "bg=%s,fg=%s"
set -g status-format[0] '#[fg=%s,bg=default]#{R:─,#{client_width}}'
set -g status-format[1] '#[align=left,range=left]#{T;=/#{status-left-length}:status-left}#[norange,list=on,align=#{status-justify}]#[list=left-marker]<#[list=right-marker]>#[list=on]#{W:#[range=window|#{window_index}]#{T:window-status-format}#[norange],#[range=window|#{window_index},list=focus]#{T:window-status-current-format}#[norange,list=on]}#[nolist,align=right,range=right]#{T;=/#{status-right-length}:status-right}#[norange]'
set -g status-left '#[fg=%s,bg=%s,bold] #{?@ws-title,#{@ws-title},#S} #[fg=%s,bg=%s,nobold] '
set -g status-right '#{?client_prefix,#[fg=%s,bg=%s,bold] PREFIX #[fg=%s,bg=%s,nobold],}#[fg=%s,bg=%s] %%H:%%M '

set -g window-status-separator "#[bg=%s] "
set -g window-status-format "#[fg=%s,bg=%s] #I #W "
set -g window-status-current-format "#[fg=%s,bg=%s,bold] #I #W "
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
		"default", c(theme, "fg"),
		c(theme, "surface_alt"),
		c(theme, "accent"), "default", c(theme, "fg"), "default",
		c(theme, "bg"), c(theme, "yellow"), c(theme, "fg"), "default", c(theme, "dim"), "default",
		"default",
		c(theme, "dim"), "default",
		c(theme, "accent"), "default",
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

func reloadLive() {
	var commands [][]string
	if runtime.GOOS == "linux" {
		commands = append(commands,
			[]string{"swaymsg", "reload"},
			[]string{"systemctl", "--user", "reload-or-restart", "waybar.service", "mako.service"},
		)
	}
	commands = append(commands, []string{"tmux", "source-file", filepath.Join(configHome(), "tmux", "tmux.conf")})
	for _, command := range commands {
		output, err := exec.Command(command[0], command[1:]...).CombinedOutput()
		if err == nil {
			continue
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

func exists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func hex(value string) string {
	return strings.TrimPrefix(value, "#")
}

func alpha(value, aa string) string {
	return hex(value) + aa
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

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}
