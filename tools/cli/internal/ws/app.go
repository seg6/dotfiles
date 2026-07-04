package ws

import (
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

type CandidateState string

const (
	CandidateSession CandidateState = "session"
	CandidateProject CandidateState = "project"
)

type Candidate struct {
	State       CandidateState
	Namespace   string
	Name        string
	Branch      string
	Path        string
	SessionName string
	Windows     int
	LastUsed    time.Time
	Project     *Project
}

func (candidate Candidate) SearchValue() string {
	return fmt.Sprintf("%s %s %s %s", candidate.State, candidate.Namespace, candidate.Name, candidate.Branch)
}

func (candidate Candidate) Identity() string {
	if candidate.Project != nil {
		return candidate.Project.ID
	}
	return candidate.SessionName
}

type App struct {
	Config Config
	Tmux   Tmux
	Picker Picker
	State  *StateStore
	Stdout io.Writer
}

func NewApp() (*App, error) {
	config, err := ConfigFromEnv()
	if err != nil {
		return nil, err
	}
	return &App{
		Config: config,
		Tmux:   NewTmuxClient(config.InsideTmux, config.Session),
		Picker: NewBubblePicker(config.UI),
		State:  NewStateStore(config),
		Stdout: os.Stdout,
	}, nil
}

func (app *App) Run(ctx context.Context, args []string) error {
	if len(args) == 0 {
		return app.runWorkspace(ctx)
	}

	switch args[0] {
	case "kill":
		if len(args) != 1 {
			return errors.New("usage: ws kill")
		}
		return app.runKill(ctx)
	case "back":
		if len(args) > 2 {
			return errors.New("usage: ws back [tmux-client]")
		}
		client := ""
		if len(args) == 2 {
			client = args[1]
		}
		return app.Tmux.Back(ctx, client)
	case "scratchpad":
		if len(args) != 1 {
			return errors.New("usage: ws scratchpad")
		}
		return app.runScratchpad(ctx)
	case "doctor":
		if len(args) != 1 {
			return errors.New("usage: ws doctor")
		}
		return app.runDoctor(ctx)
	case "help", "-h", "--help":
		app.printUsage()
		return nil
	default:
		return fmt.Errorf("unknown command %q; run 'ws --help'", args[0])
	}
}

func (app *App) runWorkspace(ctx context.Context) error {
	candidates, err := app.candidates(ctx)
	if err != nil {
		return err
	}
	selected, ok, err := app.Picker.Choose(ctx, PickRequest{Mode: PickOpen, Candidates: candidates})
	if err != nil || !ok {
		return err
	}
	return app.activate(ctx, candidates[selected])
}

func (app *App) runKill(ctx context.Context) error {
	all, err := app.candidates(ctx)
	if err != nil {
		return err
	}
	var sessions []Candidate
	for _, candidate := range all {
		if candidate.State == CandidateSession {
			sessions = append(sessions, candidate)
		}
	}
	if len(sessions) == 0 {
		return nil
	}

	selected, ok, err := app.Picker.Choose(ctx, PickRequest{Mode: PickKill, Candidates: sessions})
	if err != nil || !ok {
		return err
	}
	target := sessions[selected].SessionName
	current, err := app.Tmux.Current(ctx)
	if err != nil {
		return err
	}
	if target == current {
		for _, session := range sessions {
			if session.SessionName != target {
				if err := app.Tmux.Switch(ctx, session.SessionName); err != nil {
					return err
				}
				break
			}
		}
	}
	return app.Tmux.Kill(ctx, target)
}

func (app *App) runScratchpad(ctx context.Context) error {
	if err := app.Tmux.EnsureScratchpad(ctx, app.Config.Home); err != nil {
		return err
	}
	return app.Tmux.Switch(ctx, scratchpadSession)
}

func (app *App) runDoctor(ctx context.Context) error {
	problems := 0
	if app.Config.Loaded {
		fmt.Fprintf(app.Stdout, "ok     %-14s %s\n", "config", app.Config.Path)
	} else {
		fmt.Fprintf(app.Stdout, "ok     %-14s defaults (%s not found)\n", "config", app.Config.Path)
	}
	for _, command := range configuredCommands(app.Config.Session) {
		path, err := exec.LookPath(command)
		if err != nil {
			fmt.Fprintf(app.Stdout, "error  %-14s not found\n", command)
			problems++
			continue
		}
		fmt.Fprintf(app.Stdout, "ok     %-14s %s\n", command, path)
	}

	projects, err := DiscoverProjects(app.Config.Workspace)
	if err != nil {
		fmt.Fprintf(app.Stdout, "error  workspace      %v\n", err)
		problems++
	} else {
		fmt.Fprintf(app.Stdout, "ok     workspace      %s (%d projects, depth %d)\n", app.Config.Workspace.Root, len(projects), app.Config.Workspace.MaxDepth)
	}

	if _, err := app.State.Load(); err != nil {
		fmt.Fprintf(app.Stdout, "error  state          %v\n", err)
		problems++
	} else {
		fmt.Fprintf(app.Stdout, "ok     state          %s\n", app.State.Path)
	}

	if _, err := app.Tmux.Sessions(ctx); err != nil {
		fmt.Fprintf(app.Stdout, "error  tmux-server    %v\n", err)
		problems++
	} else {
		fmt.Fprintln(app.Stdout, "ok     tmux-server    reachable or not running")
	}

	if problems > 0 {
		return fmt.Errorf("doctor found %d problem(s)", problems)
	}
	return nil
}

func (app *App) candidates(ctx context.Context) ([]Candidate, error) {
	projects, err := DiscoverProjects(app.Config.Workspace)
	if err != nil {
		return nil, err
	}
	state, err := app.State.Load()
	if err != nil {
		return nil, err
	}
	sessions, err := app.sessionsWithAdoption(ctx, projects)
	if err != nil {
		return nil, err
	}
	sortSessions(sessions)

	running := make(map[string]bool)
	candidates := make([]Candidate, 0, len(sessions)+len(projects))
	for _, session := range sessions {
		candidate := Candidate{
			State:       CandidateSession,
			Name:        session.Title,
			Path:        session.Path,
			SessionName: session.Name,
			Windows:     session.Windows,
		}
		if candidate.Name == "" {
			candidate.Name = session.Name
		}
		projectRoot := session.ProjectRoot
		if projectRoot == "" && (!session.Managed || session.Kind == "project") {
			projectRoot = session.Path
		}
		if project, ok := projectByPath(projects, projectRoot); ok {
			projectCopy := project
			candidate.Project = &projectCopy
			candidate.Namespace = project.Namespace
			candidate.Name = project.Name
			candidate.Branch = project.Branch
			candidate.Path = project.Path
			candidate.LastUsed = state.Recent[project.ID]
			running[project.ID] = true
		}
		candidates = append(candidates, candidate)
	}

	var dormant []Project
	for _, project := range projects {
		if !running[project.ID] {
			dormant = append(dormant, project)
		}
	}
	sort.SliceStable(dormant, func(i, j int) bool {
		left := state.Recent[dormant[i].ID]
		right := state.Recent[dormant[j].ID]
		if left.Equal(right) {
			return dormant[i].ID < dormant[j].ID
		}
		return left.After(right)
	})
	for _, project := range dormant {
		projectCopy := project
		candidates = append(candidates, Candidate{
			State:     CandidateProject,
			Namespace: project.Namespace,
			Name:      project.Name,
			Branch:    project.Branch,
			Path:      project.Path,
			LastUsed:  state.Recent[project.ID],
			Project:   &projectCopy,
		})
	}
	return candidates, nil
}

func configuredCommands(config SessionConfig) []string {
	commands := []string{"tmux", "git"}
	for _, window := range config.Windows {
		command := window.Command
		fields := strings.Fields(command)
		if len(fields) == 0 {
			continue
		}
		commands = append(commands, strings.Trim(fields[0], `"'`))
		for index, field := range fields[:len(fields)-1] {
			if field == "-c" || field == "-C" {
				commands = append(commands, strings.Trim(fields[index+1], `"'`))
			}
		}
	}

	seen := make(map[string]bool, len(commands))
	unique := commands[:0]
	for _, command := range commands {
		if command != "" && !seen[command] {
			seen[command] = true
			unique = append(unique, command)
		}
	}
	return unique
}

func (app *App) sessionsWithAdoption(ctx context.Context, projects []Project) ([]Session, error) {
	sessions, err := app.Tmux.Sessions(ctx)
	if err != nil {
		return nil, err
	}
	for index := range sessions {
		session := &sessions[index]
		if session.Managed && session.Kind != "project" {
			continue
		}
		root := session.ProjectRoot
		if root == "" {
			root = session.Path
		}
		project, ok := projectByPath(projects, root)
		if !ok {
			continue
		}
		if session.Managed && session.Kind == "project" && session.ProjectID == project.ID && filepath.Clean(session.ProjectRoot) == filepath.Clean(project.Path) && session.Title == project.Name {
			continue
		}
		if err := app.Tmux.AdoptProject(ctx, session.Name, project); err != nil {
			return nil, fmt.Errorf("adopt tmux session %s: %w", session.Name, err)
		}
		session.Managed = true
		session.Kind = "project"
		session.ProjectID = project.ID
		session.ProjectRoot = project.Path
		session.Title = project.Name
	}
	return sessions, nil
}

func (app *App) activate(ctx context.Context, candidate Candidate) error {
	if candidate.State == CandidateSession {
		if candidate.Project != nil {
			if err := app.State.Touch(candidate.Project.ID); err != nil {
				return err
			}
		}
		return app.Tmux.Switch(ctx, candidate.SessionName)
	}
	if candidate.Project == nil {
		return errors.New("selected project is missing project metadata")
	}
	sessions, err := app.Tmux.Sessions(ctx)
	if err != nil {
		return err
	}
	return app.openProject(ctx, *candidate.Project, sessions)
}

func (app *App) openProject(ctx context.Context, project Project, sessions []Session) error {
	for _, session := range sessions {
		root := session.ProjectRoot
		if root == "" && (!session.Managed || session.Kind == "project") {
			root = session.Path
		}
		if filepath.Clean(root) != filepath.Clean(project.Path) {
			continue
		}
		if !session.Managed || session.Kind != "project" || session.ProjectID != project.ID || filepath.Clean(session.ProjectRoot) != filepath.Clean(project.Path) || session.Title != project.Name {
			if err := app.Tmux.AdoptProject(ctx, session.Name, project); err != nil {
				return err
			}
		}
		if err := app.State.Touch(project.ID); err != nil {
			return err
		}
		return app.Tmux.Switch(ctx, session.Name)
	}

	name := availableSessionName(project, sessions)
	if err := app.Tmux.CreateProject(ctx, name, project); err != nil {
		return fmt.Errorf("create project session: %w", err)
	}
	if err := app.State.Touch(project.ID); err != nil {
		return err
	}
	return app.Tmux.Switch(ctx, name)
}

func availableSessionName(project Project, sessions []Session) string {
	used := make(map[string]bool, len(sessions))
	for _, session := range sessions {
		used[session.Name] = true
	}
	preferred := SessionName(project)
	if !used[preferred] {
		return preferred
	}
	for suffix := 2; ; suffix++ {
		candidate := fmt.Sprintf("%s-%d", preferred, suffix)
		if !used[candidate] {
			return candidate
		}
	}
}

func sortSessions(sessions []Session) {
	sort.SliceStable(sessions, func(i, j int) bool {
		if sessions[i].LastAttached == sessions[j].LastAttached {
			return sessions[i].Name < sessions[j].Name
		}
		return sessions[i].LastAttached > sessions[j].LastAttached
	})
}

func (app *App) printUsage() {
	fmt.Fprintln(app.Stdout, `usage: ws [command]

commands:
  ws                       open the workspace picker
  ws kill                  choose a session to kill
  ws back [tmux-client]    switch to the previous session
  ws scratchpad            switch to the persistent scratchpad
  ws doctor                validate the workspace environment`)
}
