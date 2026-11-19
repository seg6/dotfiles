package theme

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"time"
)

const spicetifyVersion = "2.45.3"

func spotify(root, config string) {
	spotifyDir := filepath.Join(dataHome(), "spotify-launcher/install/usr/share/spotify")
	if !exists(filepath.Join(spotifyDir, "Apps")) {
		die("launch Spotify once first")
	}
	spice, err := exec.LookPath("spicetify")
	if err != nil {
		spice = installSpicetify()
	}
	if !exists(filepath.Join(config, "spicetify/Themes/Folio/user.css")) {
		generateSpotify(root, config, loadTheme(root))
	}

	running := spotifyRunning(spotifyDir)
	status := player("status")
	position := ""
	if status != "" {
		position = player("position")
	}
	run(spice, "config", "spotify_path", spotifyDir, "prefs_path", filepath.Join(config, "spotify/prefs"),
		"current_theme", "Folio", "color_scheme", "Folio", "inject_css", "1", "replace_colors", "1")
	run(spice, "backup", "apply", "--no-restart")
	if running || status != "" {
		exec.Command(spice, "restart").Run()
		if !waitForPlayer(10 * time.Second) {
			if launcher, err := exec.LookPath("spotify-launcher"); err == nil {
				command := exec.Command(launcher)
				command.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
				command.Start()
				waitForPlayer(30 * time.Second)
			}
		}
		if position != "" {
			player("position", position)
		}
		switch status {
		case "Playing":
			player("play")
		case "Paused":
			player("pause")
		}
	}
	fmt.Println("Spotify themed. Restore the original client with: spicetify restore")
}

func installSpicetify() string {
	var release struct {
		Assets []struct {
			Name   string `json:"name"`
			URL    string `json:"browser_download_url"`
			Digest string `json:"digest"`
		} `json:"assets"`
	}
	response, err := http.Get("https://api.github.com/repos/spicetify/cli/releases/tags/v" + spicetifyVersion)
	if err != nil {
		die(err.Error())
	}
	err = json.NewDecoder(response.Body).Decode(&release)
	response.Body.Close()
	if err != nil {
		die("spicetify release: " + err.Error())
	}
	name := "spicetify-" + spicetifyVersion + "-linux-amd64.tar.gz"
	var url, digest string
	for _, asset := range release.Assets {
		if asset.Name == name {
			url, digest = asset.URL, asset.Digest
		}
	}
	if url == "" {
		die("spicetify release has no " + name)
	}
	response, err = http.Get(url)
	if err != nil {
		die(err.Error())
	}
	archive, err := io.ReadAll(response.Body)
	response.Body.Close()
	if err != nil {
		die(err.Error())
	}
	sum := sha256.Sum256(archive)
	if fmt.Sprintf("sha256:%x", sum) != digest {
		die("spicetify release checksum mismatch")
	}

	vendor := filepath.Join(dataHome(), "dotfiles/spicetify")
	unpacked, err := gzip.NewReader(bytes.NewReader(archive))
	if err != nil {
		die(err.Error())
	}
	files := tar.NewReader(unpacked)
	for {
		header, err := files.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			die(err.Error())
		}
		target := filepath.Join(vendor, header.Name)
		if !strings.HasPrefix(target, vendor+string(os.PathSeparator)) {
			continue
		}
		switch header.Typeflag {
		case tar.TypeDir:
			os.MkdirAll(target, 0o755)
		case tar.TypeReg:
			os.MkdirAll(filepath.Dir(target), 0o755)
			file, err := os.OpenFile(target, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, os.FileMode(header.Mode)&0o755|0o644)
			if err != nil {
				die(err.Error())
			}
			_, err = io.Copy(file, files)
			file.Close()
			if err != nil {
				die(err.Error())
			}
		}
	}

	home, _ := os.UserHomeDir()
	link := filepath.Join(home, ".local/bin/spicetify")
	os.MkdirAll(filepath.Dir(link), 0o755)
	if info, err := os.Lstat(link); err == nil && info.Mode()&os.ModeSymlink != 0 {
		os.Remove(link)
	}
	if !exists(link) {
		if err := os.Symlink(filepath.Join(vendor, "spicetify"), link); err != nil {
			die(err.Error())
		}
	}
	fmt.Println("Installed Spicetify", spicetifyVersion)
	return link
}

func spotifyRunning(spotifyDir string) bool {
	entries, _ := os.ReadDir("/proc")
	for _, entry := range entries {
		if strings.Trim(entry.Name(), "0123456789") != "" {
			continue
		}
		exe, err := os.Readlink(filepath.Join("/proc", entry.Name(), "exe"))
		if err != nil || exe != filepath.Join(spotifyDir, "spotify") {
			continue
		}
		args := readString(filepath.Join("/proc", entry.Name(), "cmdline"))
		if !strings.Contains(args, "\x00--type=") && !strings.Contains(args, "\x00--monitor-self") {
			return true
		}
	}
	return false
}

func player(args ...string) string {
	output, err := exec.Command("playerctl", append([]string{"-p", "spotify"}, args...)...).Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(output))
}

func waitForPlayer(limit time.Duration) bool {
	for deadline := time.Now().Add(limit); time.Now().Before(deadline); {
		time.Sleep(100 * time.Millisecond)
		if player("status") != "" {
			return true
		}
	}
	return false
}

func run(name string, args ...string) {
	command := exec.Command(name, args...)
	command.Stdout, command.Stderr = os.Stdout, os.Stderr
	if err := command.Run(); err != nil {
		die(name + " " + args[0] + ": " + err.Error())
	}
}

func dataHome() string {
	if root := os.Getenv("XDG_DATA_HOME"); root != "" {
		return root
	}
	home, err := os.UserHomeDir()
	if err != nil {
		die(err.Error())
	}
	return filepath.Join(home, ".local/share")
}
