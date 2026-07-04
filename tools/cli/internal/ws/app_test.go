package ws

import (
	"bytes"
	"context"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"testing"
	"time"
)

type fakePicker struct {
	wantIdentity string
	wantMode     PickMode
}

func (picker fakePicker) Choose(_ context.Context, request PickRequest) (int, bool, error) {
	if picker.wantMode != "" && request.Mode != picker.wantMode {
		return 0, false, fmt.Errorf("picker mode = %q, want %q", request.Mode, picker.wantMode)
	}
	for index, candidate := range request.Candidates {
		if candidate.Identity() == picker.wantIdentity {
			return index, true, nil
		}
	}
	return 0, false, fmt.Errorf("picker did not find %q", picker.wantIdentity)
}

type fakeTmux struct {
	sessions       []Session
	current        string
	adopted        []string
	createdName    string
	createdProject Project
	scratchHome    string
	switched       []string
	backClient     string
	killed         []string
}

func (tmux *fakeTmux) Sessions(context.Context) ([]Session, error) {
	return slices.Clone(tmux.sessions), nil
}

func (tmux *fakeTmux) AdoptProject(_ context.Context, name string, project Project) error {
	tmux.adopted = append(tmux.adopted, name+"="+project.ID)
	return nil
}

func (tmux *fakeTmux) CreateProject(_ context.Context, name string, project Project) error {
	tmux.createdName = name
	tmux.createdProject = project
	tmux.sessions = append(tmux.sessions, Session{Name: name, ProjectID: project.ID, ProjectRoot: project.Path, Managed: true, Kind: "project", Title: project.Name})
	return nil
}

func (tmux *fakeTmux) EnsureScratchpad(_ context.Context, home string) error {
	tmux.scratchHome = home
	return nil
}

func (tmux *fakeTmux) Switch(_ context.Context, target string) error {
	tmux.switched = append(tmux.switched, target)
	return nil
}

func (tmux *fakeTmux) Back(_ context.Context, client string) error {
	tmux.backClient = client
	return nil
}

func (tmux *fakeTmux) Kill(_ context.Context, target string) error {
	tmux.killed = append(tmux.killed, target)
	return nil
}

func (tmux *fakeTmux) Current(context.Context) (string, error) { return tmux.current, nil }

func newTestApp(t *testing.T, tmux *fakeTmux, picker Picker) (*App, Project) {
	t.Helper()
	home := t.TempDir()
	workspace := filepath.Join(home, "workspace")
	projectPath := makeRepository(t, workspace, "personal/dotfiles", "ref: refs/heads/main")
	config := Config{
		Home:       home,
		Workspace:  WorkspaceConfig{Root: workspace, MaxDepth: 4},
		UI:         defaultUIConfig(),
		Session:    defaultSessionConfig(),
		StateDir:   filepath.Join(home, "state"),
		InsideTmux: true,
	}
	store := NewStateStore(config)
	store.Now = func() time.Time { return time.Date(2026, 8, 15, 18, 0, 0, 0, time.UTC) }
	project := Project{ID: "personal/dotfiles", Namespace: "personal", Name: "dotfiles", Path: projectPath, Branch: "main"}
	return &App{Config: config, Tmux: tmux, Picker: picker, State: store, Stdout: &bytes.Buffer{}}, project
}

func TestDefaultCommandCreatesProjectSessionAndUpdatesState(t *testing.T) {
	tmux := &fakeTmux{}
	app, project := newTestApp(t, tmux, fakePicker{wantIdentity: "personal/dotfiles", wantMode: PickOpen})

	if err := app.Run(context.Background(), nil); err != nil {
		t.Fatal(err)
	}
	if tmux.createdName != SessionName(project) || tmux.createdProject.ID != project.ID {
		t.Fatalf("created session = %q for %#v", tmux.createdName, tmux.createdProject)
	}
	if !slices.Equal(tmux.switched, []string{SessionName(project)}) {
		t.Fatalf("switched sessions = %v", tmux.switched)
	}
	state, err := app.State.Load()
	if err != nil {
		t.Fatal(err)
	}
	if state.Recent[project.ID].IsZero() {
		t.Fatal("project was not added to recent state")
	}
}

func TestCandidatesAdoptSessionByLiveProjectPath(t *testing.T) {
	tmux := &fakeTmux{}
	app, project := newTestApp(t, tmux, fakePicker{})
	tmux.sessions = []Session{{Name: "manual", Path: project.Path, Windows: 3}}

	candidates, err := app.candidates(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if !slices.Equal(tmux.adopted, []string{"manual=personal/dotfiles"}) {
		t.Fatalf("adopted sessions = %v", tmux.adopted)
	}
	if len(candidates) != 1 || candidates[0].State != CandidateSession || candidates[0].Namespace != "personal" || candidates[0].Name != "dotfiles" || candidates[0].Branch != "main" || candidates[0].Windows != 3 {
		t.Fatalf("candidate = %#v", candidates)
	}
}

func TestKillCurrentSwitchesToMostRecentFallback(t *testing.T) {
	tmux := &fakeTmux{
		current: "current",
		sessions: []Session{
			{Name: "fallback", Title: "fallback", LastAttached: 20},
			{Name: "current", Title: "current", LastAttached: 30},
		},
	}
	app, _ := newTestApp(t, tmux, fakePicker{wantIdentity: "current", wantMode: PickKill})

	if err := app.Run(context.Background(), []string{"kill"}); err != nil {
		t.Fatal(err)
	}
	if !slices.Equal(tmux.switched, []string{"fallback"}) {
		t.Fatalf("switched sessions = %v", tmux.switched)
	}
	if !slices.Equal(tmux.killed, []string{"current"}) {
		t.Fatalf("killed sessions = %v", tmux.killed)
	}
}

func TestScratchpadAndBackRemainExplicit(t *testing.T) {
	tmux := &fakeTmux{}
	app, _ := newTestApp(t, tmux, fakePicker{})

	if err := app.Run(context.Background(), []string{"scratchpad"}); err != nil {
		t.Fatal(err)
	}
	if err := app.Run(context.Background(), []string{"back", "$1"}); err != nil {
		t.Fatal(err)
	}
	if tmux.scratchHome != app.Config.Home || !slices.Equal(tmux.switched, []string{"scratchpad"}) || tmux.backClient != "$1" {
		t.Fatalf("scratch=%q switched=%v back=%q", tmux.scratchHome, tmux.switched, tmux.backClient)
	}
}

func TestLegacyCommandsAreRejected(t *testing.T) {
	app, _ := newTestApp(t, &fakeTmux{}, fakePicker{})
	for _, command := range []string{"pick", "open", "list"} {
		if err := app.Run(context.Background(), []string{command}); err == nil {
			t.Fatalf("%s unexpectedly succeeded", command)
		}
	}
}

func TestAvailableSessionNameHandlesCollision(t *testing.T) {
	project := Project{ID: "personal/dotfiles", Name: "dotfiles"}
	preferred := SessionName(project)
	sessions := []Session{{Name: preferred}, {Name: preferred + "-2"}}
	if got, want := availableSessionName(project, sessions), preferred+"-3"; got != want {
		t.Fatalf("availableSessionName() = %q, want %q", got, want)
	}
}

func TestProjectRepositoryFixtureExists(t *testing.T) {
	app, project := newTestApp(t, &fakeTmux{}, fakePicker{})
	if _, err := os.Stat(filepath.Join(app.Config.Workspace.Root, "personal", "dotfiles", ".git", "HEAD")); err != nil || project.Path == "" {
		t.Fatalf("fixture missing: %v", err)
	}
}
