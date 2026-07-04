package ws

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strconv"
	"strings"
)

const scratchpadSession = "scratchpad"

type Session struct {
	Name         string
	Path         string
	Managed      bool
	Kind         string
	ProjectID    string
	ProjectRoot  string
	Title        string
	Windows      int
	LastAttached int64
}

type Tmux interface {
	Sessions(context.Context) ([]Session, error)
	AdoptProject(context.Context, string, Project) error
	CreateProject(context.Context, string, Project) error
	EnsureScratchpad(context.Context, string) error
	Switch(context.Context, string) error
	Back(context.Context, string) error
	Kill(context.Context, string) error
	Current(context.Context) (string, error)
}

type TmuxClient struct {
	InsideTmux bool
	Session    SessionConfig
	BaseArgs   []string
	Stdin      io.Reader
	Stdout     io.Writer
	Stderr     io.Writer
}

func NewTmuxClient(insideTmux bool, session SessionConfig) *TmuxClient {
	return &TmuxClient{
		InsideTmux: insideTmux,
		Session:    session,
		Stdin:      os.Stdin,
		Stdout:     os.Stdout,
		Stderr:     os.Stderr,
	}
}

func (client *TmuxClient) Sessions(ctx context.Context) ([]Session, error) {
	const separator = "\x1f"
	format := strings.Join([]string{
		"#{session_name}",
		"#{session_path}",
		"#{@ws-managed}",
		"#{@ws-kind}",
		"#{@ws-project-id}",
		"#{@ws-project-root}",
		"#{@ws-title}",
		"#{session_windows}",
		"#{?session_last_attached,#{session_last_attached},#{session_created}}",
	}, separator)

	output, err := client.capture(ctx, "list-sessions", "-F", format)
	if err != nil {
		if isNoServerError(err) {
			return nil, nil
		}
		return nil, err
	}

	var sessions []Session
	for _, line := range strings.Split(strings.TrimSpace(output), "\n") {
		if line == "" {
			continue
		}
		fields := strings.Split(line, separator)
		if len(fields) != 9 {
			return nil, fmt.Errorf("parse tmux session record: expected 9 fields, got %d", len(fields))
		}
		windows, _ := strconv.Atoi(fields[7])
		lastAttached, _ := strconv.ParseInt(fields[8], 10, 64)
		sessions = append(sessions, Session{
			Name:         fields[0],
			Path:         fields[1],
			Managed:      fields[2] == "1",
			Kind:         fields[3],
			ProjectID:    fields[4],
			ProjectRoot:  fields[5],
			Title:        fields[6],
			Windows:      windows,
			LastAttached: lastAttached,
		})
	}
	return sessions, nil
}

func (client *TmuxClient) AdoptProject(ctx context.Context, name string, project Project) error {
	return client.tag(ctx, name, "project", project.ID, project.Path, project.Name)
}

func (client *TmuxClient) CreateProject(ctx context.Context, name string, project Project) error {
	windows := client.Session.Windows
	if len(windows) == 0 {
		return errors.New("create project session: no windows configured")
	}
	first := windows[0]
	args := []string{"new-session", "-d", "-s", name, "-c", project.Path, "-n", first.Name}
	if first.Command != "" {
		args = append(args, first.Command)
	}
	if err := client.run(ctx, args...); err != nil {
		return err
	}

	created := true
	defer func() {
		if created {
			_ = client.Kill(context.Background(), name)
		}
	}()

	createdIndex, err := client.capture(ctx, "display-message", "-p", "-t", name, "#{window_index}")
	if err != nil {
		return err
	}
	createdIndex = strings.TrimSpace(createdIndex)
	wantedIndex := strconv.Itoa(first.Index)
	if createdIndex != wantedIndex {
		if err := client.run(ctx, "move-window", "-s", name+":"+createdIndex, "-t", name+":"+wantedIndex); err != nil {
			return err
		}
	}

	if err := client.AdoptProject(ctx, name, project); err != nil {
		return err
	}
	for _, window := range windows[1:] {
		target := fmt.Sprintf("%s:%d", name, window.Index)
		args := []string{"new-window", "-t", target, "-c", project.Path, "-n", window.Name}
		if window.Command != "" {
			args = append(args, window.Command)
		}
		if err := client.run(ctx, args...); err != nil {
			return err
		}
	}
	if err := client.run(ctx, "select-window", "-t", fmt.Sprintf("%s:%d", name, first.Index)); err != nil {
		return err
	}

	created = false
	return nil
}

func (client *TmuxClient) EnsureScratchpad(ctx context.Context, home string) error {
	sessions, err := client.Sessions(ctx)
	if err != nil {
		return err
	}
	for _, session := range sessions {
		if session.Name == scratchpadSession {
			if session.Managed && session.Kind == "scratchpad" && session.Title == scratchpadSession {
				return nil
			}
			return client.tag(ctx, scratchpadSession, "scratchpad", "", "", scratchpadSession)
		}
	}

	if err := client.run(ctx, "new-session", "-d", "-s", scratchpadSession, "-c", home, "-n", scratchpadSession); err != nil {
		return err
	}
	if err := client.tag(ctx, scratchpadSession, "scratchpad", "", "", scratchpadSession); err != nil {
		_ = client.Kill(context.Background(), scratchpadSession)
		return err
	}
	return nil
}

func (client *TmuxClient) Switch(ctx context.Context, target string) error {
	if client.InsideTmux {
		return client.run(ctx, "switch-client", "-t", target)
	}
	return client.interactive(ctx, "attach-session", "-t", target)
}

func (client *TmuxClient) Back(ctx context.Context, tmuxClient string) error {
	args := []string{"switch-client"}
	if tmuxClient != "" {
		args = append(args, "-c", tmuxClient)
	}
	args = append(args, "-l")
	return client.run(ctx, args...)
}

func (client *TmuxClient) Kill(ctx context.Context, target string) error {
	return client.run(ctx, "kill-session", "-t", target)
}

func (client *TmuxClient) Current(ctx context.Context) (string, error) {
	if !client.InsideTmux {
		return "", nil
	}
	output, err := client.capture(ctx, "display-message", "-p", "#{session_name}")
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(output), nil
}

func (client *TmuxClient) tag(ctx context.Context, name, kind, projectID, projectRoot, title string) error {
	options := [][2]string{
		{"@ws-managed", "1"},
		{"@ws-kind", kind},
		{"@ws-project-id", projectID},
		{"@ws-project-root", projectRoot},
		{"@ws-title", title},
	}
	for _, option := range options {
		if err := client.run(ctx, "set-option", "-q", "-t", name, option[0], option[1]); err != nil {
			return err
		}
	}
	return nil
}

func (client *TmuxClient) capture(ctx context.Context, args ...string) (string, error) {
	command := exec.CommandContext(ctx, "tmux", append(client.BaseArgs, args...)...)
	var stdout, stderr bytes.Buffer
	command.Stdout = &stdout
	command.Stderr = &stderr
	if err := command.Run(); err != nil {
		return "", commandError(args, stderr.String(), err)
	}
	return stdout.String(), nil
}

func (client *TmuxClient) run(ctx context.Context, args ...string) error {
	command := exec.CommandContext(ctx, "tmux", append(client.BaseArgs, args...)...)
	var stderr bytes.Buffer
	command.Stdout = client.Stdout
	command.Stderr = &stderr
	if err := command.Run(); err != nil {
		return commandError(args, stderr.String(), err)
	}
	return nil
}

func (client *TmuxClient) interactive(ctx context.Context, args ...string) error {
	command := exec.CommandContext(ctx, "tmux", append(client.BaseArgs, args...)...)
	command.Stdin = client.Stdin
	command.Stdout = client.Stdout
	command.Stderr = client.Stderr
	if err := command.Run(); err != nil {
		return fmt.Errorf("tmux %s: %w", strings.Join(args, " "), err)
	}
	return nil
}

type tmuxCommandError struct {
	message string
	cause   error
}

func (err *tmuxCommandError) Error() string { return err.message }
func (err *tmuxCommandError) Unwrap() error { return err.cause }

func commandError(args []string, stderr string, cause error) error {
	detail := strings.TrimSpace(stderr)
	if detail == "" {
		detail = cause.Error()
	}
	return &tmuxCommandError{
		message: fmt.Sprintf("tmux %s: %s", strings.Join(args, " "), detail),
		cause:   cause,
	}
}

func isNoServerError(err error) bool {
	var commandErr *tmuxCommandError
	if !errors.As(err, &commandErr) {
		return false
	}
	return strings.Contains(commandErr.message, "no server running") ||
		strings.Contains(commandErr.message, "no sessions") ||
		strings.Contains(commandErr.message, "failed to connect to server") ||
		strings.Contains(commandErr.message, "error connecting to")
}
