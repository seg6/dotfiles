package theme

import (
	"bytes"
	"crypto/sha256"
	"fmt"
	"html/template"
	"io"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"unicode"

	"github.com/BurntSushi/toml"
	"github.com/lucasb-eyer/go-colorful"
)

func userThemeDir(config string) string { return filepath.Join(config, "dotfiles/themes") }

func paletteColor(l, c, h float64) colorful.Color {
	for c > .001 {
		value := colorful.OkLch(l, c, h)
		if value.IsValid() {
			return value
		}
		c *= .92
	}
	return colorful.OkLch(l, 0, h).Clamped()
}

func luminance(value colorful.Color) float64 {
	linear := func(v float64) float64 {
		if v <= .04045 {
			return v / 12.92
		}
		return math.Pow((v+.055)/1.055, 2.4)
	}
	return .2126*linear(value.R) + .7152*linear(value.G) + .0722*linear(value.B)
}

func contrast(a, b colorful.Color) float64 {
	x, y := luminance(a), luminance(b)
	if x < y {
		x, y = y, x
	}
	return (x + .05) / (y + .05)
}

func readable(value, background colorful.Color, minimum float64) colorful.Color {
	l, c, h := value.OkLch()
	for contrast(value, background) < minimum && l < 1 {
		l = math.Min(1, l+.005)
		value = paletteColor(l, c, h)
	}
	return value
}

type colorCluster struct {
	value  colorful.Color
	weight float64
}

// Deterministic weighted k-means in OKLab preserves both large color fields and
// smaller vivid details, without letting a single bright pixel dictate the UI.
func wallpaperClusters(samples []colorful.Color) []colorCluster {
	type bucket struct {
		r, g, b float64
		n       int
	}
	histogram := map[int]bucket{}
	for _, v := range samples {
		key := int(v.R*255)>>4<<8 | int(v.G*255)>>4<<4 | int(v.B*255)>>4
		b := histogram[key]
		b.r += v.R
		b.g += v.G
		b.b += v.B
		b.n++
		histogram[key] = b
	}
	keys := make([]int, 0, len(histogram))
	for key := range histogram {
		keys = append(keys, key)
	}
	sort.Ints(keys)
	type point struct {
		lab    [3]float64
		weight float64
	}
	points := make([]point, 0, len(keys))
	var centers [][3]float64
	first, largest := 0, 0
	for _, key := range keys {
		b := histogram[key]
		v := colorful.Color{R: b.r / float64(b.n), G: b.g / float64(b.n), B: b.b / float64(b.n)}
		l, a, c := v.OkLab()
		points = append(points, point{[3]float64{l, a, c}, float64(b.n)})
		if b.n > largest {
			first = len(points) - 1
			largest = b.n
		}
	}
	if len(points) == 0 {
		return []colorCluster{{colorful.Color{R: .2, G: .3, B: .4}, 1}}
	}
	centers = append(centers, points[first].lab)
	distance := func(a, b [3]float64) float64 {
		return math.Pow(a[0]-b[0], 2) + math.Pow(a[1]-b[1], 2) + math.Pow(a[2]-b[2], 2)
	}
	for len(centers) < min(12, len(points)) {
		best, score := 0, 0.0
		for i, p := range points {
			nearest := math.Inf(1)
			for _, c := range centers {
				nearest = math.Min(nearest, distance(p.lab, c))
			}
			if value := nearest * math.Sqrt(p.weight); value > score {
				best, score = i, value
			}
		}
		if score < 1e-10 {
			break
		}
		centers = append(centers, points[best].lab)
	}
	weights := make([]float64, len(centers))
	for iteration := 0; iteration < 12; iteration++ {
		sums := make([][3]float64, len(centers))
		clear(weights)
		for _, p := range points {
			nearest, best := math.Inf(1), 0
			for i, c := range centers {
				if d := distance(p.lab, c); d < nearest {
					nearest, best = d, i
				}
			}
			weights[best] += p.weight
			for axis := 0; axis < 3; axis++ {
				sums[best][axis] += p.lab[axis] * p.weight
			}
		}
		for i := range centers {
			if weights[i] > 0 {
				for axis := 0; axis < 3; axis++ {
					centers[i][axis] = sums[i][axis] / weights[i]
				}
			}
		}
	}
	result := make([]colorCluster, 0, len(centers))
	for i, c := range centers {
		if weights[i] > 0 {
			result = append(result, colorCluster{colorful.OkLab(c[0], c[1], c[2]).Clamped(), weights[i] / float64(len(samples))})
		}
	}
	return result
}

func paletteFromSamples(samples []colorful.Color) map[string]string {
	clusters := wallpaperClusters(samples)
	accent := clusters[0].value
	score := -1.0
	for _, cluster := range clusters {
		l, c, _ := cluster.value.OkLch()
		value := math.Sqrt(cluster.weight) * math.Pow(c+.015, 1.6) * (.3 + l)
		if l < .18 || l > .96 {
			value *= .1
		}
		if value > score {
			score, accent = value, cluster.value
		}
	}
	_, chroma, hue := accent.OkLch()
	averageChroma := 0.0
	for _, cluster := range clusters {
		_, c, _ := cluster.value.OkLch()
		averageChroma += c * cluster.weight
	}
	colorScale := math.Min(1, averageChroma/.045)
	inkHue := hue
	if chroma < .02 && averageChroma < .012 {
		// Achromatic images have no meaningful hue. Do not invent one or
		// amplify barely visible grain into a saturated desktop palette.
		hue, inkHue, chroma, colorScale = 0, 0, 0, 0
	} else {
		best := -1.0
		for _, cluster := range clusters {
			l, c, h := cluster.value.OkLch()
			difference := math.Abs(h - hue)
			difference = math.Min(difference, 360-difference)
			if l < .7 && c > .025 && difference > 40 {
				if value := cluster.weight * (.85 - l); value > best {
					best, inkHue = value, h
				}
			}
		}
	}
	tone := func(l, c, h float64) colorful.Color { return paletteColor(l, c*colorScale, h) }
	bg := tone(.25, .025, inkHue)
	makeColor := func(l, c, h, minimum float64) string { return readable(tone(l, c, h), bg, minimum).Hex() }
	// Restrained semantic colors keep errors and syntax distinguishable even
	// when the wallpaper and the desktop's structural colors are monochrome.
	semantic := func(l, c, h float64) string {
		return readable(paletteColor(l, c*(.35+.65*colorScale), h), bg, 4.6).Hex()
	}
	result := map[string]string{
		"bg": bg.Hex(), "bg_alt": tone(.21, .024, inkHue).Hex(),
		"surface": tone(.32, .035, inkHue).Hex(), "surface_alt": tone(.40, .045, inkHue).Hex(),
		"fg": makeColor(.91, .025, hue, 7.1), "dim": makeColor(.70, .035, inkHue, 4.6),
		"accent": makeColor(.80, math.Min(.16, chroma*.85), hue, 7.1),
		"red":    semantic(.76, .13, 22), "green": semantic(.79, .11, 142),
		"yellow": semantic(.82, .12, 85), "blue": semantic(.78, .105, 260),
		"magenta": semantic(.78, .115, 325), "cyan": semantic(.79, .085, 192),
		"paper": tone(.87, .055, hue).Hex(), "ink": tone(.37, .04, inkHue).Hex(),
		"edge": tone(.50, .045, inkHue).Hex(), "active": tone(.43, .075, inkHue).Hex(),
		"desk":   tone(.74, math.Min(.12, chroma*.7), hue).Hex(),
		"header": tone(.44, .055, inkHue).Hex(), "shadow": tone(.36, .04, inkHue).Hex(),
		// Salon paints its wall in the picture's own shadow color.
		"wall": tone(.29, .06, inkHue).Hex(), "wall_light": tone(.37, .065, inkHue).Hex(), "wall_dark": tone(.19, .04, inkHue).Hex(),
	}
	fg, _ := colorful.Hex(result["fg"])
	header, _ := colorful.Hex(result["header"])
	result["header_fg"] = readable(fg, header, 4.6).Hex()
	result["header_dim"] = readable(tone(.80, .025, inkHue), header, 4.6).Hex()
	return result
}

func sampleWallpaper(data []byte) ([]colorful.Color, error) {
	program, err := exec.LookPath("magick")
	if err != nil {
		return nil, fmt.Errorf("wallpaper colors need ImageMagick: install imagemagick")
	}
	command := exec.Command(program, "-limit", "memory", "64MiB", "-limit", "map", "128MiB", "-limit", "disk", "256MiB", "-[0]", "-auto-orient", "-colorspace", "sRGB", "-resize", "64x64!", "-alpha", "on", "-depth", "8", "rgba:-")
	command.Stdin = bytes.NewReader(data)
	var stderr bytes.Buffer
	command.Stderr = &stderr
	output, err := command.Output()
	if err != nil {
		return nil, fmt.Errorf("read wallpaper image: %s", strings.TrimSpace(stderr.String()))
	}
	if len(output) != 64*64*4 {
		return nil, fmt.Errorf("unexpected wallpaper sample size")
	}
	samples := make([]colorful.Color, 0, 4096)
	for i := 0; i < len(output); i += 4 {
		if output[i+3] >= 128 {
			samples = append(samples, colorful.Color{R: float64(output[i]) / 255, G: float64(output[i+1]) / 255, B: float64(output[i+2]) / 255})
		}
	}
	if len(samples) == 0 {
		return nil, fmt.Errorf("wallpaper has no visible pixels")
	}
	return samples, nil
}

func validThemeName(name string) bool {
	if name == "" || len(name) > 64 {
		return false
	}
	for i, c := range name {
		if !(c >= 'a' && c <= 'z' || c >= '0' && c <= '9' || i > 0 && (c == '-' || c == '_')) {
			return false
		}
	}
	return true
}

func wallpaperSlug(path string) string {
	stem := strings.TrimSuffix(filepath.Base(path), filepath.Ext(path))
	var result strings.Builder
	for _, c := range strings.ToLower(stem) {
		if c >= 'a' && c <= 'z' || c >= '0' && c <= '9' {
			result.WriteRune(c)
		} else if result.Len() > 0 && !strings.HasSuffix(result.String(), "-") {
			result.WriteByte('-')
		}
		if result.Len() >= 32 {
			break
		}
	}
	slug := strings.Trim(result.String(), "-")
	if slug == "" {
		return "image"
	}
	return slug
}

func createWallpaperTheme(root, config, path, name, layout string) (Theme, string, error) {
	if name != "" && !validThemeName(name) {
		return Theme{}, "", fmt.Errorf("theme name must use lowercase letters, numbers, hyphens or underscores")
	}
	if name != "" && exists(filepath.Join(root, "themes", name, "theme.toml")) {
		return Theme{}, "", fmt.Errorf("%s is a built-in theme; choose another name", name)
	}
	file, err := os.Open(path)
	if err != nil {
		return Theme{}, "", fmt.Errorf("open wallpaper: %w", err)
	}
	defer file.Close()
	info, err := file.Stat()
	if err != nil || !info.Mode().IsRegular() {
		return Theme{}, "", fmt.Errorf("wallpaper must be a regular image file")
	}
	data, err := io.ReadAll(io.LimitReader(file, 64*1024*1024+1))
	if err != nil {
		return Theme{}, "", err
	}
	if len(data) > 64*1024*1024 {
		return Theme{}, "", fmt.Errorf("wallpaper exceeds 64 MiB")
	}
	samples, err := sampleWallpaper(data)
	if err != nil {
		return Theme{}, "", err
	}
	digest := sha256.Sum256(data)
	if name == "" {
		name = fmt.Sprintf("wallpaper-%s-%x", wallpaperSlug(path), digest[:4])
	}
	theme, err := readTheme(root, "overprint")
	if err != nil {
		return Theme{}, "", err
	}
	theme.ID, theme.Name = name, name
	theme.Layout = layout
	if layout != "" {
		// Each layout has its own corners, shadows, and blur.
		base, err := readTheme(root, layout)
		if err != nil {
			return Theme{}, "", err
		}
		theme.UI = base.UI
	}
	words := strings.ReplaceAll(strings.ReplaceAll(name, "-", " "), "_", " ")
	runes := []rune(words)
	runes[0] = unicode.ToUpper(runes[0])
	theme.Display = string(runes)
	// The label beside the picture says what it was named, not whose palette it began as.
	theme.Art = nil
	if layout == "salon" {
		theme.Art = map[string]string{"title": theme.Display}
	}
	theme.Colors = paletteFromSamples(samples)
	theme.ANSI = map[string]string{"black": theme.Colors["bg_alt"], "white": theme.Colors["fg"], "bright_black": theme.Colors["dim"], "bright_white": theme.Colors["fg"], "cursor": theme.Colors["accent"], "selection": theme.Colors["surface_alt"]}
	bg, _ := colorful.Hex(theme.Colors["bg"])
	for _, key := range []string{"red", "green", "yellow", "blue", "magenta", "cyan"} {
		color, _ := colorful.Hex(theme.Colors[key])
		l, c, h := color.OkLch()
		theme.ANSI[key] = readable(paletteColor(l-.08, c, h), bg, 4.6).Hex()
		theme.ANSI["bright_"+key] = paletteColor(math.Min(.94, l+.07), c, h).Hex()
	}
	directory, err := filepath.Abs(filepath.Join(userThemeDir(config), name))
	if err != nil {
		return Theme{}, "", err
	}
	extension := strings.ToLower(filepath.Ext(path))
	if extension == "" || len(extension) > 8 {
		extension = ".img"
	}
	theme.Wallpaper = filepath.Join(directory, "wallpaper"+extension)
	if err := validateTheme(theme); err != nil {
		return Theme{}, "", err
	}
	if err = os.MkdirAll(directory, 0755); err != nil {
		return Theme{}, "", err
	}
	if err = os.WriteFile(theme.Wallpaper, data, 0644); err != nil {
		return Theme{}, "", err
	}
	var encoded bytes.Buffer
	saved := theme
	saved.Wallpaper = filepath.Base(theme.Wallpaper)
	if err = toml.NewEncoder(&encoded).Encode(saved); err != nil {
		return Theme{}, "", err
	}
	write(filepath.Join(directory, "theme.toml"), encoded.String())
	preview := filepath.Join(directory, "preview.html")
	if err = writeWallpaperPreview(preview, theme, filepath.Base(theme.Wallpaper)); err != nil {
		return Theme{}, "", err
	}
	return theme, preview, nil
}

func wallpaperCommand(root, config string, args []string) error {
	var path, name, layout string
	preview, reload := false, true
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--name":
			i++
			if i == len(args) {
				return fmt.Errorf("--name needs a theme name")
			}
			name = args[i]
		case "--layout":
			i++
			if i == len(args) || !validLayout(args[i]) {
				return fmt.Errorf("--layout needs one of %s", strings.Join(layouts, ", "))
			}
			layout = args[i]
		case "--preview":
			preview = true
		case "--no-reload":
			reload = false
		default:
			if strings.HasPrefix(args[i], "--") || path != "" {
				return fmt.Errorf("usage: theme wallpaper <image> [--name name] [--preview] [--no-reload]")
			}
			path = args[i]
		}
	}
	if path == "" {
		return fmt.Errorf("usage: theme wallpaper <image> [--name name] [--preview] [--no-reload]")
	}
	theme, report, err := createWallpaperTheme(root, config, path, name, layout)
	if err != nil {
		return err
	}
	if preview {
		fmt.Printf("Saved %s\nPreview: %s\nApply: theme use %s\n", theme.Display, report, theme.ID)
		return nil
	}
	useTheme(root, config, theme.ID, "", reload)
	fmt.Printf("Saved palette: %s\nReturn to the original: theme use overprint\n", theme.ID)
	return nil
}

func writeWallpaperPreview(path string, theme Theme, wallpaper string) error {
	// Values come from a validated hex palette; names and filenames stay escaped.
	css := ""
	keys := make([]string, 0, len(theme.Colors))
	for key := range theme.Colors {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	for _, key := range keys {
		css += "--" + key + ":" + theme.Colors[key] + ";"
	}
	data := struct {
		Name, ID, Wallpaper string
		PaletteCSS          template.CSS
		Colors              map[string]string
	}{theme.Display, theme.ID, wallpaper, template.CSS(css), theme.Colors}
	parsed, err := template.New("preview").Parse(wallpaperPreviewHTML)
	if err != nil {
		return err
	}
	var out bytes.Buffer
	if err = parsed.Execute(&out, data); err != nil {
		return err
	}
	write(path, out.String())
	return nil
}
