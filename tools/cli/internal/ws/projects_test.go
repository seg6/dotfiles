package ws

import (
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func makeRepository(t *testing.T, root, path, head string) string {
	t.Helper()
	projectPath := filepath.Join(root, filepath.FromSlash(path))
	gitPath := filepath.Join(projectPath, ".git")
	if err := os.MkdirAll(gitPath, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(gitPath, "HEAD"), []byte(head+"\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	return projectPath
}

func TestDiscoverProjectsFindsGitRootsAtAnyDepthAndPrunes(t *testing.T) {
	root := t.TempDir()
	makeRepository(t, root, "dotfiles", "ref: refs/heads/main")
	makeRepository(t, root, "personal/blog", "ref: refs/heads/redesign")
	makeRepository(t, root, "clients/meyer/platform/api", strings.Repeat("a", 40))
	makeRepository(t, root, "personal/blog/packages/nested", "ref: refs/heads/ignored")
	if err := os.MkdirAll(filepath.Join(root, "notes", "not-a-repository", "deep"), 0o755); err != nil {
		t.Fatal(err)
	}
	makeRepository(t, root, ".hidden/ignored", "ref: refs/heads/main")

	projects, err := DiscoverProjects(WorkspaceConfig{Root: root, MaxDepth: 4})
	if err != nil {
		t.Fatal(err)
	}
	var got []Project
	for _, project := range projects {
		project.Path = ""
		got = append(got, project)
	}
	want := []Project{
		{ID: "clients/meyer/platform/api", Namespace: "clients/meyer/platform", Name: "api", Branch: "detached@aaaaaaaa"},
		{ID: "dotfiles", Namespace: "", Name: "dotfiles", Branch: "main"},
		{ID: "personal/blog", Namespace: "personal", Name: "blog", Branch: "redesign"},
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("projects = %#v, want %#v", got, want)
	}
}

func TestDiscoverProjectsRecognizesGitWorktreeFile(t *testing.T) {
	root := t.TempDir()
	projectPath := filepath.Join(root, "worktrees", "feature")
	gitDirectory := filepath.Join(root, "git-data", "feature")
	if err := os.MkdirAll(gitDirectory, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(projectPath, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(projectPath, ".git"), []byte("gitdir: ../../git-data/feature\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(gitDirectory, "HEAD"), []byte("ref: refs/heads/feature/worktree\n"), 0o600); err != nil {
		t.Fatal(err)
	}

	projects, err := DiscoverProjects(WorkspaceConfig{Root: root, MaxDepth: 4})
	if err != nil {
		t.Fatal(err)
	}
	if len(projects) != 1 || projects[0].ID != "worktrees/feature" || projects[0].Branch != "feature/worktree" {
		t.Fatalf("projects = %#v", projects)
	}
}

func TestDiscoverProjectsSkipsDirectorySymlinks(t *testing.T) {
	root := t.TempDir()
	external := t.TempDir()
	makeRepository(t, external, "linked", "ref: refs/heads/main")
	if err := os.Symlink(filepath.Join(external, "linked"), filepath.Join(root, "linked")); err != nil {
		t.Fatal(err)
	}
	projects, err := DiscoverProjects(WorkspaceConfig{Root: root, MaxDepth: 4})
	if err != nil {
		t.Fatal(err)
	}
	if len(projects) != 0 {
		t.Fatalf("projects = %#v, want none", projects)
	}
}

func TestDiscoverProjectsHonorsDepthAndIgnoredDirectories(t *testing.T) {
	root := t.TempDir()
	makeRepository(t, root, "group/project", "ref: refs/heads/main")
	makeRepository(t, root, "group/deeper/project", "ref: refs/heads/main")
	makeRepository(t, root, "archive/ignored", "ref: refs/heads/main")

	projects, err := DiscoverProjects(WorkspaceConfig{Root: root, MaxDepth: 2, Ignore: []string{"archive"}})
	if err != nil {
		t.Fatal(err)
	}
	if len(projects) != 1 || projects[0].ID != "group/project" {
		t.Fatalf("projects = %#v", projects)
	}
}

func TestSessionNameIsReadableAndStable(t *testing.T) {
	project := Project{ID: "personal/my.app:api", Name: "my.app:api"}
	first := SessionName(project)
	second := SessionName(project)
	if first != second || !strings.HasPrefix(first, "ws-my-app-api-") || len(first) != len("ws-my-app-api-")+8 {
		t.Fatalf("SessionName() = %q then %q", first, second)
	}
}
