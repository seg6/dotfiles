package ws

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestTmuxSessionMetadataIntegration(t *testing.T) {
	if _, err := exec.LookPath("tmux"); err != nil {
		t.Skip("tmux is not installed")
	}

	ctx := context.Background()
	socket := tmuxTestSocket(t)
	client := NewTmuxClient(true, defaultSessionConfig())
	client.BaseArgs = []string{"-S", socket, "-f", "/dev/null"}
	defer func() { _ = client.run(ctx, "kill-server") }()

	projectPath := t.TempDir()
	project := Project{ID: "deep/meyer/example", Namespace: "deep/meyer", Name: "example", Path: projectPath, Branch: "main"}
	if err := client.run(ctx, "new-session", "-d", "-s", "manual", "-c", projectPath, "sleep", "30"); err != nil {
		t.Fatal(err)
	}
	if err := client.AdoptProject(ctx, "manual", project); err != nil {
		t.Fatal(err)
	}
	if err := client.EnsureScratchpad(ctx, t.TempDir()); err != nil {
		t.Fatal(err)
	}

	sessions, err := client.Sessions(ctx)
	if err != nil {
		t.Fatal(err)
	}
	byName := make(map[string]Session)
	for _, session := range sessions {
		byName[session.Name] = session
	}

	managed := byName["manual"]
	if !managed.Managed || managed.Kind != "project" || managed.ProjectID != project.ID || managed.ProjectRoot != projectPath || managed.Title != "example" || managed.Windows != 1 {
		t.Fatalf("project metadata = %+v", managed)
	}
	scratchpad := byName["scratchpad"]
	if !scratchpad.Managed || scratchpad.Kind != "scratchpad" || scratchpad.ProjectRoot != "" || scratchpad.Title != "scratchpad" {
		t.Fatalf("scratchpad metadata = %+v", scratchpad)
	}
}

func TestTmuxMissingServerIsEmpty(t *testing.T) {
	if _, err := exec.LookPath("tmux"); err != nil {
		t.Skip("tmux is not installed")
	}

	client := NewTmuxClient(true, defaultSessionConfig())
	client.BaseArgs = []string{"-S", tmuxTestSocket(t), "-f", "/dev/null"}
	sessions, err := client.Sessions(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if len(sessions) != 0 {
		t.Fatalf("sessions = %v, want none", sessions)
	}
}

func TestTmuxCreatesProjectLayout(t *testing.T) {
	if _, err := exec.LookPath("tmux"); err != nil {
		t.Skip("tmux is not installed")
	}

	ctx := context.Background()
	testDir := t.TempDir()
	socket := tmuxTestSocket(t)
	config := filepath.Join(testDir, "tmux.conf")
	if err := os.WriteFile(config, []byte("set -g base-index 1\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	session := SessionConfig{Windows: []WindowConfig{
		{Index: 2, Name: "code", Command: "sleep 30"},
		{Index: 3, Name: "shell"},
		{Index: 7, Name: "files", Command: "sleep 30"},
	}}
	client := NewTmuxClient(true, session)
	client.BaseArgs = []string{"-S", socket, "-f", config}
	defer func() { _ = client.run(ctx, "kill-server") }()

	project := Project{ID: "personal/dotfiles", Namespace: "personal", Name: "dotfiles", Path: t.TempDir(), Branch: "main"}
	name := SessionName(project)
	if err := client.CreateProject(ctx, name, project); err != nil {
		t.Fatal(err)
	}

	output, err := client.capture(ctx, "list-windows", "-t", name, "-F", "#{window_index}:#{window_name}")
	if err != nil {
		t.Fatal(err)
	}
	windows := strings.Fields(output)
	if len(windows) != 3 || windows[0] != "2:code" || windows[1] != "3:shell" || windows[2] != "7:files" {
		t.Fatalf("windows = %v, want [2:code 3:shell 7:files]", windows)
	}
	selected, err := client.capture(ctx, "display-message", "-p", "-t", name, "#{window_index}")
	if err != nil {
		t.Fatal(err)
	}
	if strings.TrimSpace(selected) != "2" {
		t.Fatalf("selected window = %q, want 2", selected)
	}
}

func tmuxTestSocket(t *testing.T) string {
	t.Helper()
	file, err := os.CreateTemp("", "ws-tmux-*.sock")
	if err != nil {
		t.Fatal(err)
	}
	path := file.Name()
	if err := file.Close(); err != nil {
		t.Fatal(err)
	}
	if err := os.Remove(path); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.Remove(path) })
	return path
}
