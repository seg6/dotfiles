package theme

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

func generateWS(config string, theme Theme) {
	content := fmt.Sprintf(`[ui.colors]
foreground = %q
accent = %q
muted = %q
session = %q
branch = %q
warning = %q
error = %q
selected_foreground = %q
`, c(theme, "fg"), c(theme, "accent"), c(theme, "dim"), c(theme, "green"), c(theme, "cyan"), c(theme, "yellow"), c(theme, "red"), c(theme, "bg"))
	write(filepath.Join(config, "ws/theme.toml"), content)
}

func generateDesktop(root, config string, theme Theme) {
	gtkTheme := "adw-gtk3-dark"
	scheme := "prefer-dark"
	if theme.Mode == "light" {
		gtkTheme = "adw-gtk3"
		scheme = "prefer-light"
	}
	settings := fmt.Sprintf(`[Settings]
gtk-theme-name=%s
gtk-icon-theme-name=Folio
gtk-font-name=Adwaita Sans 12
gtk-application-prefer-dark-theme=%d
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
`, gtkTheme, map[bool]int{true: 1, false: 0}[theme.Mode != "light"])
	for _, version := range []string{"gtk-3.0", "gtk-4.0"} {
		write(filepath.Join(config, version, "settings.ini"), settings)
	}
	desktop := map[string]string{"gtk-theme": gtkTheme, "icon-theme": "Folio", "font-name": "Adwaita Sans 12", "monospace-font-name": "Fantasque Sans Mono 12", "color-scheme": scheme, "cursor-theme": "Adwaita", "cursor-size": "24"}
	data, _ := json.MarshalIndent(desktop, "", "  ")
	write(filepath.Join(config, "dotfiles/desktop-settings.json"), string(data)+"\n")
	write(filepath.Join(config, "fontconfig/conf.d/60-folio.conf"), `<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
 <alias><family>sans-serif</family><prefer><family>Adwaita Sans</family><family>Noto Sans</family></prefer></alias>
 <alias><family>monospace</family><prefer><family>Fantasque Sans Mono</family><family>Noto Sans Mono</family></prefer></alias>
</fontconfig>
`)
	generateIcons(config, theme)
	generateBrowser(config, theme)
	generateSpotify(root, config, theme)
}

func generateIcons(config string, theme Theme) {
	dir := filepath.Join(config, "dotfiles/icons/Folio")
	write(filepath.Join(dir, "index.theme"), `[Icon Theme]
Name=Folio
Comment=Amber folders and Papirus desktop icons
Inherits=Papirus-Dark,Papirus,Adwaita,hicolor
Directories=scalable/places
[scalable/places]
Size=48
Type=Scalable
MinSize=16
MaxSize=256
Context=Places
`)
	// These are original vectors. Other application and symbolic icons inherit Papirus.
	ink := theme.Colors["ink"]
	if ink == "" {
		ink = c(theme, "surface_alt")
	}
	folder := fmt.Sprintf(`<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48"><path fill="%s" d="M6 11h14l4 5h19v27H6z"/><path fill="%s" d="M3 7h15l4 5h20v27H3z"/><path fill="%s" d="M3 17h39v3H3z" opacity=".32"/>%%s</svg>`, ink, c(theme, "accent"), c(theme, "bg"))
	variants := map[string]string{"folder": "", "user-home": `<path d="m15 29 7-6 7 6v8H15z"/>`, "folder-download": `<path d="M20 22h4v8h5l-7 7-7-7h5z"/>`, "folder-documents": `<path d="M17 22h11v14H17zm2 3v2h7v-2zm0 5v2h7v-2z" fill-rule="evenodd"/>`, "folder-music": `<path d="M24 21h5v4h-3v9a4 4 0 1 1-3-4v-9z"/>`, "folder-pictures": `<path d="M13 34 20 25l5 6 4-5 7 8z"/>`, "folder-videos": `<path d="m18 23 13 7-13 7z"/>`, "folder-desktop": `<path d="M13 22h20v12h-8v3h-4v-3h-8zm3 3v6h14v-6z" fill-rule="evenodd"/>`}
	for name, mark := range variants {
		if mark != "" {
			mark = `<g fill="` + c(theme, "bg") + `">` + mark + `</g>`
		}
		write(filepath.Join(dir, "scalable/places", name+".svg"), fmt.Sprintf(folder, mark))
	}
}

func browserRGB(value string) []int {
	result := make([]int, 3)
	for i := range result {
		n, _ := strconv.ParseInt(value[1+i*2:3+i*2], 16, 32)
		result[i] = int(n)
	}
	return result
}

func generateBrowser(config string, theme Theme) {
	colors := map[string]string{"frame": c(theme, "bg_alt"), "frame_inactive": c(theme, "surface"), "toolbar": c(theme, "bg"), "tab_text": c(theme, "fg"), "tab_background_text": c(theme, "dim"), "bookmark_text": c(theme, "fg"), "ntp_background": c(theme, "bg"), "ntp_text": c(theme, "fg"), "ntp_link": c(theme, "accent"), "button_background": c(theme, "surface_alt"), "toolbar_button_icon": c(theme, "fg"), "omnibox_background": c(theme, "surface"), "omnibox_text": c(theme, "fg"), "tab_background_separator": c(theme, "surface_alt"), "toolbar_top_separator": c(theme, "accent"), "toolbar_bottom_separator": c(theme, "surface_alt")}
	rgbColors := map[string][]int{}
	for key, value := range colors {
		rgbColors[key] = browserRGB(value)
	}
	manifest := map[string]any{"manifest_version": 3, "name": "Folio", "version": "1.0.0", "description": "The Folio desktop palette.", "theme": map[string]any{"colors": rgbColors, "properties": map[string]int{"ntp_logo_alternate": 1}}}
	data, _ := json.MarshalIndent(manifest, "", "  ")
	write(filepath.Join(config, "dotfiles/browser-theme/manifest.json"), string(data)+"\n")
	// Chromium requires the local theme to be loaded at startup. Preserve existing
	// driver flags and extension paths in the user's launcher configuration.
	flagsPath := filepath.Join(config, "helium-browser-flags.conf")
	existing := readString(flagsPath)
	themePath := filepath.Join(config, "dotfiles/browser-theme")
	if !strings.Contains(existing, themePath) {
		lines := strings.Split(strings.TrimRight(existing, "\n"), "\n")
		found := false
		for i, line := range lines {
			if strings.HasPrefix(line, "--load-extension=") {
				lines[i] = line + "," + themePath
				found = true
				break
			}
		}
		if !found {
			lines = append(lines, "# Generated desktop theme.", "--load-extension="+themePath)
		}
		if existing != "" && !exists(flagsPath+".bak") {
			write(flagsPath+".bak", existing)
		}
		write(flagsPath, strings.Join(lines, "\n")+"\n")
	}
}

func generateSpotify(root, config string, theme Theme) {
	colors := map[string]string{"text": c(theme, "fg"), "subtext": c(theme, "dim"), "main": c(theme, "bg"), "sidebar": c(theme, "bg_alt"), "player": c(theme, "bg_alt"), "card": c(theme, "surface"), "shadow": c(theme, "surface_alt"), "selected-row": c(theme, "surface_alt"), "button": c(theme, "accent"), "button-active": c(theme, "yellow"), "button-disabled": c(theme, "surface_alt"), "tab-active": c(theme, "surface_alt"), "notification": c(theme, "surface"), "notification-error": c(theme, "red"), "misc": c(theme, "surface_alt")}
	content := "[Folio]\n"
	for key, value := range colors {
		content += key + " = " + strings.TrimPrefix(value, "#") + "\n"
	}
	write(filepath.Join(config, "spicetify/Themes/Folio/color.ini"), content)
	// The stylesheet names palette roles as {{role}}, so it follows any palette.
	data, err := os.ReadFile(filepath.Join(root, themeDir, "spotify.css"))
	if err != nil {
		die(err.Error())
	}
	css := strings.NewReplacer(
		"{{edge}}", role(theme, "edge", "surface_alt"), "{{ink}}", role(theme, "ink", "surface_alt"),
		"{{bg_alt}}", c(theme, "bg_alt"), "{{bg}}", c(theme, "bg"), "{{surface_alt}}", c(theme, "surface_alt"), "{{surface}}", c(theme, "surface"), "{{accent}}", c(theme, "accent"),
	).Replace(string(data))
	if strings.Contains(css, "{{") {
		die(themeDir + "/spotify.css names an unknown palette role")
	}
	write(filepath.Join(config, "spicetify/Themes/Folio/user.css"), css)
}
