package theme

import (
	"encoding/json"
	"fmt"
	"image"
	"image/color"
	_ "image/jpeg"
	"image/png"
	"math"
	"os"
	"path/filepath"
	"strings"
)

const pageWidth, pageHeight = 640, 360

func pageTones(source image.Image) []float64 {
	bounds := source.Bounds()
	scale := math.Max(float64(pageWidth)/float64(bounds.Dx()), float64(pageHeight)/float64(bounds.Dy()))
	offsetX := (float64(bounds.Dx())*scale - pageWidth) / 2
	drop := 0.2 * pageHeight
	tones := make([]float64, pageWidth*pageHeight)
	for y := 0; y < pageHeight; y++ {
		strength := math.Min(1, math.Max(0, (float64(y)/pageHeight-0.58)/0.20))
		if strength == 0 {
			continue
		}
		for x := 0; x < pageWidth; x++ {
			x0, x1 := (float64(x)+offsetX)/scale, (float64(x)+1+offsetX)/scale
			y0, y1 := (float64(y)-drop)/scale, (float64(y)+1-drop)/scale
			var sum float64
			var count int
			for sy := int(y0); sy < int(math.Ceil(y1)); sy++ {
				for sx := int(x0); sx < int(math.Ceil(x1)); sx++ {
					if sx < 0 || sy < 0 || sx >= bounds.Dx() || sy >= bounds.Dy() {
						continue
					}
					r, g, b, _ := source.At(bounds.Min.X+sx, bounds.Min.Y+sy).RGBA()
					sum += (0.2126*float64(r) + 0.7152*float64(g) + 0.0722*float64(b)) / 65535
					count++
				}
			}
			if count == 0 {
				continue
			}
			tone := sum / float64(count)
			tone = 1 / (1 + math.Exp(-5*(tone-0.5)))
			tone = math.Pow(tone, 1.7) * 0.92
			tones[y*pageWidth+x] = tone * strength
		}
	}
	return tones
}

func ditherPage(tones []float64, paper, ink color.Color) *image.Paletted {
	page := image.NewPaletted(image.Rect(0, 0, pageWidth, pageHeight), color.Palette{paper, ink})
	work := append([]float64(nil), tones...)
	for y := 0; y < pageHeight; y++ {
		for x := 0; x < pageWidth; x++ {
			i := y*pageWidth + x
			var lit float64
			if work[i] >= 0.5 {
				lit = 1
				page.SetColorIndex(x, y, 1)
			}
			spare := work[i] - lit
			if x+1 < pageWidth {
				work[i+1] += spare * 7 / 16
			}
			if y+1 < pageHeight {
				if x > 0 {
					work[i+pageWidth-1] += spare * 3 / 16
				}
				work[i+pageWidth] += spare * 5 / 16
				if x+1 < pageWidth {
					work[i+pageWidth+1] += spare * 1 / 16
				}
			}
		}
	}
	return page
}

func hexColor(value string) color.Color {
	var r, g, b uint8
	fmt.Sscanf(value, "#%02x%02x%02x", &r, &g, &b)
	return color.RGBA{r, g, b, 255}
}

func writePage(wallpaper, target, paper, ink string) error {
	file, err := os.Open(wallpaper)
	if err != nil {
		return err
	}
	defer file.Close()
	source, _, err := image.Decode(file)
	if err != nil {
		return fmt.Errorf("%s: %w", filepath.Base(wallpaper), err)
	}
	if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
		return err
	}
	temporary, err := os.CreateTemp(filepath.Dir(target), ".page.*.png")
	if err != nil {
		return err
	}
	defer os.Remove(temporary.Name())
	if err := png.Encode(temporary, ditherPage(pageTones(source), hexColor(paper), hexColor(ink))); err != nil {
		temporary.Close()
		return err
	}
	if err := temporary.Close(); err != nil {
		return err
	}
	if err := os.Chmod(temporary.Name(), 0o644); err != nil {
		return err
	}
	return os.Rename(temporary.Name(), target)
}

func whoAndWhere(config string) string {
	who := map[string]string{}
	if zone, err := os.Readlink("/etc/localtime"); err == nil {
		if _, city, found := strings.Cut(zone, "zoneinfo/"); found {
			who["city"] = strings.ReplaceAll(filepath.Base(city), "_", " ")
			who["place"] = who["city"]
		}
	}
	if fields := strings.Fields(readString(filepath.Join(config, "dotfiles/place"))); len(fields) >= 2 {
		who["latitude"], who["longitude"] = fields[0], fields[1]
	}
	data, _ := json.MarshalIndent(who, "", "  ")
	return string(data)
}
