package ws

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestConfigFromEnvLoadsAndNormalizesTOML(t *testing.T) {
	home := t.TempDir()
	configHome := filepath.Join(home, "config")
	stateHome := filepath.Join(home, "state")
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", configHome)
	t.Setenv("XDG_STATE_HOME", stateHome)
	t.Setenv("TMUX", "socket,1,0")

	configPath := filepath.Join(configHome, "ws", "config.toml")
	if err := os.MkdirAll(filepath.Dir(configPath), 0o755); err != nil {
		t.Fatal(err)
	}
	data := []byte(`[workspace]
root = "~/code"
max_depth = 3
ignore = ["node_modules", "node_modules", "archive"]

[ui]
max_width = 72
side_padding = 4
column_gap = 5

[ui.colors]
accent = "#5f87ff"
muted = "8"

[[session.windows]]
index = 1
name = "code"
command = "nvim ."

[[session.windows]]
index = 7
name = "files"
command = "yazi"
`)
	if err := os.WriteFile(configPath, data, 0o600); err != nil {
		t.Fatal(err)
	}

	config, err := ConfigFromEnv()
	if err != nil {
		t.Fatal(err)
	}
	if !config.Loaded || config.Path != configPath || config.Workspace.Root != filepath.Join(home, "code") || config.Workspace.MaxDepth != 3 {
		t.Fatalf("workspace config = %#v", config)
	}
	if len(config.Workspace.Ignore) != 2 || config.UI.MaxWidth != 72 || config.UI.SidePadding != 4 || config.UI.ColumnGap != 5 || config.UI.Colors.Accent != "#5f87ff" {
		t.Fatalf("ui/discovery config = %#v", config)
	}
	if config.UI.Colors.Branch != "6" {
		t.Fatalf("omitted color did not retain default: %#v", config.UI.Colors)
	}
	if len(config.Session.Windows) != 2 || config.Session.Windows[0].Command != "nvim ." || config.Session.Windows[1].Command != "yazi" || config.Session.Windows[1].Index != 7 || !config.InsideTmux {
		t.Fatalf("session config = %#v", config)
	}
	if config.StateDir != filepath.Join(stateHome, "ws") {
		t.Fatalf("state dir = %q", config.StateDir)
	}
}

func TestConfigFromEnvRejectsUnknownKeys(t *testing.T) {
	home := t.TempDir()
	configHome := filepath.Join(home, "config")
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", configHome)

	configPath := filepath.Join(configHome, "ws", "config.toml")
	if err := os.MkdirAll(filepath.Dir(configPath), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(configPath, []byte("[ui]\nmax_wdith = 88\n"), 0o600); err != nil {
		t.Fatal(err)
	}

	_, err := ConfigFromEnv()
	if err == nil || !strings.Contains(err.Error(), "unknown key(s): ui.max_wdith") {
		t.Fatalf("error = %v", err)
	}
}

func TestConfigFromEnvUsesDefaultsWithoutFile(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, "missing-config"))

	config, err := ConfigFromEnv()
	if err != nil {
		t.Fatal(err)
	}
	if config.Loaded || config.Workspace.Root != filepath.Join(home, "workspace") || config.UI.MaxWidth != 88 || config.UI.ColumnGap != 3 || len(config.Session.Windows) != 2 || config.Session.Windows[1].Index != 9 {
		t.Fatalf("defaults = %#v", config)
	}
}

func TestConfigFromEnvUsesDotConfigWithoutXDGOverride(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", "")

	config, err := ConfigFromEnv()
	if err != nil {
		t.Fatal(err)
	}
	want := filepath.Join(home, ".config", "ws", "config.toml")
	if config.Path != want {
		t.Fatalf("config path = %q, want %q", config.Path, want)
	}
}

func TestConfigFromEnvRejectsRelativeXDGConfigHome(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	t.Setenv("XDG_CONFIG_HOME", "relative")

	_, err := ConfigFromEnv()
	if err == nil || !strings.Contains(err.Error(), "XDG_CONFIG_HOME must be absolute") {
		t.Fatalf("error = %v", err)
	}
}

func TestConfigValidationRejectsInvalidValues(t *testing.T) {
	config := defaultConfig(t.TempDir(), "config.toml", t.TempDir())
	config.UI.Colors.Accent = "blue"
	if err := config.normalizeAndValidate(); err == nil || !strings.Contains(err.Error(), "ui.colors.accent") {
		t.Fatalf("error = %v", err)
	}
}

func TestConfiguredCommandsFollowSessionCommands(t *testing.T) {
	commands := configuredCommands(SessionConfig{Windows: []WindowConfig{
		{Index: 1, Name: "editor", Command: `fish -C "hx ."`},
		{Index: 2, Name: "shell"},
		{Index: 9, Name: "files", Command: "yazi"},
	}})
	want := []string{"tmux", "git", "fish", "hx", "yazi"}
	if strings.Join(commands, ",") != strings.Join(want, ",") {
		t.Fatalf("commands = %v, want %v", commands, want)
	}
}
