package ws

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"

	"github.com/BurntSushi/toml"
)

type WorkspaceConfig struct {
	Root     string   `toml:"root"`
	MaxDepth int      `toml:"max_depth"`
	Ignore   []string `toml:"ignore"`
}

type UIColors struct {
	Accent             string `toml:"accent"`
	Muted              string `toml:"muted"`
	Session            string `toml:"session"`
	Branch             string `toml:"branch"`
	Warning            string `toml:"warning"`
	Error              string `toml:"error"`
	SelectedForeground string `toml:"selected_foreground"`
}

type UIConfig struct {
	MaxWidth    int      `toml:"max_width"`
	SidePadding int      `toml:"side_padding"`
	ColumnGap   int      `toml:"column_gap"`
	Colors      UIColors `toml:"colors"`
}

type WindowConfig struct {
	Index   int    `toml:"index"`
	Name    string `toml:"name"`
	Command string `toml:"command"`
}

type SessionConfig struct {
	Windows []WindowConfig `toml:"windows"`
}

type Config struct {
	Workspace WorkspaceConfig `toml:"workspace"`
	UI        UIConfig        `toml:"ui"`
	Session   SessionConfig   `toml:"session"`

	Home       string `toml:"-"`
	Path       string `toml:"-"`
	Loaded     bool   `toml:"-"`
	StateDir   string `toml:"-"`
	InsideTmux bool   `toml:"-"`
}

func ConfigFromEnv() (Config, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return Config{}, fmt.Errorf("resolve home directory: %w", err)
	}
	configHome := os.Getenv("XDG_CONFIG_HOME")
	if configHome == "" {
		// Dotdrop installs the shared configuration below ~/.config on every
		// supported platform. os.UserConfigDir points at ~/Library/Application
		// Support on macOS, which would make ws silently ignore that file.
		configHome = filepath.Join(home, ".config")
	} else if !filepath.IsAbs(configHome) {
		return Config{}, fmt.Errorf("resolve config directory: XDG_CONFIG_HOME must be absolute")
	}
	configHome = filepath.Clean(configHome)
	stateHome := os.Getenv("XDG_STATE_HOME")
	if stateHome == "" {
		stateHome = filepath.Join(home, ".local", "state")
	}

	configPath := filepath.Join(configHome, "ws", "config.toml")
	config := defaultConfig(home, configPath, filepath.Join(stateHome, "ws"))
	metadata, err := toml.DecodeFile(configPath, &config)
	if err != nil && !os.IsNotExist(err) {
		return Config{}, fmt.Errorf("read config %s: %w", configPath, err)
	}
	if err == nil {
		config.Loaded = true
		if undecoded := metadata.Undecoded(); len(undecoded) > 0 {
			keys := make([]string, 0, len(undecoded))
			for _, key := range undecoded {
				keys = append(keys, key.String())
			}
			return Config{}, fmt.Errorf("read config %s: unknown key(s): %s", configPath, strings.Join(keys, ", "))
		}
	}

	if err := config.normalizeAndValidate(); err != nil {
		return Config{}, fmt.Errorf("read config %s: %w", configPath, err)
	}
	return config, nil
}

func defaultConfig(home, configPath, stateDir string) Config {
	return Config{
		Workspace: WorkspaceConfig{
			Root:     filepath.Join(home, "workspace"),
			MaxDepth: 4,
			Ignore:   []string{"node_modules", "target", "vendor"},
		},
		UI:         defaultUIConfig(),
		Session:    defaultSessionConfig(),
		Home:       home,
		Path:       configPath,
		StateDir:   filepath.Clean(stateDir),
		InsideTmux: os.Getenv("TMUX") != "",
	}
}

func defaultUIConfig() UIConfig {
	return UIConfig{
		MaxWidth:    88,
		SidePadding: 2,
		ColumnGap:   3,
		Colors: UIColors{
			Accent:             "4",
			Muted:              "8",
			Session:            "2",
			Branch:             "6",
			Warning:            "3",
			Error:              "1",
			SelectedForeground: "0",
		},
	}
}

func defaultSessionConfig() SessionConfig {
	return SessionConfig{
		Windows: []WindowConfig{
			{Index: 1, Name: "editor", Command: `fish -C "hx ."`},
			{Index: 9, Name: "files", Command: "felix"},
		},
	}
}

func (config *Config) normalizeAndValidate() error {
	if strings.TrimSpace(config.Workspace.Root) == "" {
		return fmt.Errorf("workspace.root must not be empty")
	}
	root, err := expandHome(config.Workspace.Root, config.Home)
	if err != nil {
		return fmt.Errorf("workspace.root: %w", err)
	}
	config.Workspace.Root = filepath.Clean(root)
	if config.Workspace.MaxDepth < 0 || config.Workspace.MaxDepth > 32 {
		return fmt.Errorf("workspace.max_depth must be between 0 and 32")
	}

	seen := make(map[string]bool, len(config.Workspace.Ignore))
	ignored := make([]string, 0, len(config.Workspace.Ignore))
	for _, name := range config.Workspace.Ignore {
		name = strings.TrimSpace(name)
		if name == "" || name == "." || name == ".." || filepath.Base(name) != name {
			return fmt.Errorf("workspace.ignore entries must be directory names, got %q", name)
		}
		if !seen[name] {
			seen[name] = true
			ignored = append(ignored, name)
		}
	}
	config.Workspace.Ignore = ignored

	if config.UI.MaxWidth < 40 || config.UI.MaxWidth > 240 {
		return fmt.Errorf("ui.max_width must be between 40 and 240")
	}
	if config.UI.SidePadding < 0 || config.UI.SidePadding > 20 {
		return fmt.Errorf("ui.side_padding must be between 0 and 20")
	}
	if config.UI.ColumnGap < 1 || config.UI.ColumnGap > 8 {
		return fmt.Errorf("ui.column_gap must be between 1 and 8")
	}
	colors := map[string]string{
		"accent":              config.UI.Colors.Accent,
		"muted":               config.UI.Colors.Muted,
		"session":             config.UI.Colors.Session,
		"branch":              config.UI.Colors.Branch,
		"warning":             config.UI.Colors.Warning,
		"error":               config.UI.Colors.Error,
		"selected_foreground": config.UI.Colors.SelectedForeground,
	}
	for name, value := range colors {
		if !validColor(value) {
			return fmt.Errorf("ui.colors.%s must be an ANSI color (0-255) or #RGB/#RRGGBB, got %q", name, value)
		}
	}

	if len(config.Session.Windows) == 0 {
		return fmt.Errorf("session.windows must contain at least one window")
	}
	sort.Slice(config.Session.Windows, func(i, j int) bool {
		return config.Session.Windows[i].Index < config.Session.Windows[j].Index
	})
	seenIndexes := make(map[int]bool, len(config.Session.Windows))
	for position := range config.Session.Windows {
		window := &config.Session.Windows[position]
		window.Name = strings.TrimSpace(window.Name)
		window.Command = strings.TrimSpace(window.Command)
		if window.Index < 1 || window.Index > 99 {
			return fmt.Errorf("session.windows[%d].index must be between 1 and 99", position)
		}
		if seenIndexes[window.Index] {
			return fmt.Errorf("session.windows contains duplicate index %d", window.Index)
		}
		seenIndexes[window.Index] = true
		if window.Name == "" {
			return fmt.Errorf("session.windows[%d].name must not be empty", position)
		}
	}
	return nil
}

func expandHome(value, home string) (string, error) {
	if value == "~" {
		return home, nil
	}
	if strings.HasPrefix(value, "~/") {
		return filepath.Join(home, strings.TrimPrefix(value, "~/")), nil
	}
	if strings.HasPrefix(value, "~") {
		return "", fmt.Errorf("only the current user's ~ prefix is supported")
	}
	if !filepath.IsAbs(value) {
		return filepath.Join(home, value), nil
	}
	return value, nil
}

func validColor(value string) bool {
	if len(value) == 4 || len(value) == 7 {
		if value[0] != '#' {
			return false
		}
		_, err := strconv.ParseUint(value[1:], 16, 24)
		return err == nil
	}
	number, err := strconv.Atoi(value)
	return err == nil && number >= 0 && number <= 255
}
