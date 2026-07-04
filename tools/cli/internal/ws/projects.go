package ws

import (
	"crypto/sha256"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"unicode"
)

type Project struct {
	ID        string
	Namespace string
	Name      string
	Path      string
	Branch    string
}

func DiscoverProjects(config WorkspaceConfig) ([]Project, error) {
	root := config.Root
	root, err := filepath.Abs(root)
	if err != nil {
		return nil, fmt.Errorf("resolve workspace root: %w", err)
	}
	info, err := os.Stat(root)
	if err != nil {
		return nil, fmt.Errorf("scan workspace root %s: %w", root, err)
	}
	if !info.IsDir() {
		return nil, fmt.Errorf("scan workspace root %s: not a directory", root)
	}

	ignored := make(map[string]bool, len(config.Ignore))
	for _, name := range config.Ignore {
		ignored[name] = true
	}

	var projects []Project
	var walk func(string, int) error
	walk = func(directory string, depth int) error {
		entries, err := os.ReadDir(directory)
		if err != nil {
			return fmt.Errorf("scan workspace directory %s: %w", directory, err)
		}
		for _, entry := range entries {
			if strings.HasPrefix(entry.Name(), ".") || ignored[entry.Name()] || entry.Type()&os.ModeSymlink != 0 || !entry.IsDir() {
				continue
			}

			nextDepth := depth + 1
			if config.MaxDepth > 0 && nextDepth > config.MaxDepth {
				continue
			}
			path := filepath.Join(directory, entry.Name())
			if isGitRoot(path) {
				project, err := projectFromPath(root, path)
				if err != nil {
					return err
				}
				projects = append(projects, project)
				continue
			}
			if err := walk(path, nextDepth); err != nil {
				return err
			}
		}
		return nil
	}

	if err := walk(root, 0); err != nil {
		return nil, err
	}
	sort.Slice(projects, func(i, j int) bool { return projects[i].ID < projects[j].ID })
	return projects, nil
}

func isGitRoot(path string) bool {
	info, err := os.Lstat(filepath.Join(path, ".git"))
	if err != nil {
		return false
	}
	return info.IsDir() || info.Mode().IsRegular()
}

func projectFromPath(root, path string) (Project, error) {
	relative, err := filepath.Rel(root, path)
	if err != nil {
		return Project{}, fmt.Errorf("resolve project path %s: %w", path, err)
	}
	id := filepath.ToSlash(relative)
	namespace := filepath.ToSlash(filepath.Dir(relative))
	if namespace == "." {
		namespace = ""
	}
	return Project{
		ID:        id,
		Namespace: namespace,
		Name:      filepath.Base(path),
		Path:      filepath.Clean(path),
		Branch:    readBranch(path),
	}, nil
}

func readBranch(projectPath string) string {
	gitPath := filepath.Join(projectPath, ".git")
	info, err := os.Lstat(gitPath)
	if err != nil {
		return ""
	}
	gitDirectory := gitPath
	if info.Mode().IsRegular() {
		data, err := os.ReadFile(gitPath)
		if err != nil {
			return ""
		}
		value := strings.TrimSpace(string(data))
		target, ok := strings.CutPrefix(value, "gitdir:")
		if !ok {
			return ""
		}
		gitDirectory = strings.TrimSpace(target)
		if !filepath.IsAbs(gitDirectory) {
			gitDirectory = filepath.Join(projectPath, gitDirectory)
		}
	}

	data, err := os.ReadFile(filepath.Join(gitDirectory, "HEAD"))
	if err != nil {
		return ""
	}
	head := strings.TrimSpace(string(data))
	if reference, ok := strings.CutPrefix(head, "ref: refs/heads/"); ok {
		return reference
	}
	if len(head) > 8 {
		head = head[:8]
	}
	if head == "" {
		return ""
	}
	return "detached@" + head
}

func SessionName(project Project) string {
	var builder strings.Builder
	lastDash := false
	for _, r := range strings.ToLower(project.Name) {
		if unicode.IsLetter(r) || unicode.IsDigit(r) {
			builder.WriteRune(r)
			lastDash = false
			continue
		}
		if !lastDash {
			builder.WriteByte('-')
			lastDash = true
		}
	}
	slug := strings.Trim(builder.String(), "-")
	if slug == "" {
		slug = "project"
	}
	if len(slug) > 32 {
		slug = strings.TrimRight(slug[:32], "-")
	}
	sum := sha256.Sum256([]byte(project.ID))
	return fmt.Sprintf("ws-%s-%x", slug, sum[:4])
}

func projectByPath(projects []Project, path string) (Project, bool) {
	clean := filepath.Clean(path)
	for _, project := range projects {
		if filepath.Clean(project.Path) == clean {
			return project, true
		}
	}
	return Project{}, false
}
