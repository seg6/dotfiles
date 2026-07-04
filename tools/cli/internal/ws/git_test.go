package ws

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
)

func TestLoadGitStatusCountsWorkingTreeStates(t *testing.T) {
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("git is not installed")
	}
	repository := t.TempDir()
	runGit(t, repository, "init", "-q")
	runGit(t, repository, "config", "user.email", "ws@example.test")
	runGit(t, repository, "config", "user.name", "ws test")
	tracked := filepath.Join(repository, "tracked.txt")
	if err := os.WriteFile(tracked, []byte("first\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	runGit(t, repository, "add", "tracked.txt")
	runGit(t, repository, "commit", "-qm", "initial")
	if err := os.WriteFile(tracked, []byte("changed\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(repository, "new.txt"), []byte("new\n"), 0o600); err != nil {
		t.Fatal(err)
	}

	status := LoadGitStatus(context.Background(), repository)
	if status.Err != "" || status.Changed != 1 || status.Untracked != 1 || status.Conflicts != 0 {
		t.Fatalf("status = %#v", status)
	}
}

func TestLoadGitStatusReportsErrors(t *testing.T) {
	status := LoadGitStatus(context.Background(), t.TempDir())
	if status.Err == "" {
		t.Fatalf("status = %#v, want an error", status)
	}
}

func TestConflictCodes(t *testing.T) {
	for _, code := range []string{"DD", "AU", "UD", "UA", "DU", "AA", "UU"} {
		if !isConflictCode(code) {
			t.Fatalf("%s was not recognized as a conflict", code)
		}
	}
	for _, code := range []string{" M", "M ", "A ", "??"} {
		if isConflictCode(code) {
			t.Fatalf("%s was incorrectly recognized as a conflict", code)
		}
	}
}

func TestParseGitStatusReportsAllKinds(t *testing.T) {
	status := parseGitStatus(" M changed.txt\n?? new.txt\nUU conflict.txt\n")
	if status.Changed != 1 || status.Untracked != 1 || status.Conflicts != 1 {
		t.Fatalf("status = %#v", status)
	}
}

func runGit(t *testing.T, directory string, args ...string) {
	t.Helper()
	command := exec.Command("git", append([]string{"-C", directory}, args...)...)
	if output, err := command.CombinedOutput(); err != nil {
		t.Fatalf("git %v: %v: %s", args, err, output)
	}
}
