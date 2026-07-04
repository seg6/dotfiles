package ws

import (
	"bytes"
	"context"
	"os/exec"
	"strings"
)

type GitStatus struct {
	Changed   int
	Untracked int
	Conflicts int
	Err       string
}

func LoadGitStatus(ctx context.Context, projectPath string) GitStatus {
	command := exec.CommandContext(ctx, "git", "-C", projectPath, "status", "--porcelain=v1", "--untracked-files=normal")
	var output, stderr bytes.Buffer
	command.Stdout = &output
	command.Stderr = &stderr
	if err := command.Run(); err != nil {
		detail := strings.TrimSpace(stderr.String())
		if detail == "" {
			detail = err.Error()
		}
		return GitStatus{Err: detail}
	}

	return parseGitStatus(output.String())
}

func parseGitStatus(output string) GitStatus {
	var status GitStatus
	for _, line := range strings.Split(strings.TrimRight(output, "\n"), "\n") {
		if len(line) < 2 {
			continue
		}
		code := line[:2]
		switch {
		case code == "??":
			status.Untracked++
		case isConflictCode(code):
			status.Conflicts++
		default:
			status.Changed++
		}
	}
	return status
}

func isConflictCode(code string) bool {
	return code == "DD" || code == "AU" || code == "UD" || code == "UA" || code == "DU" || code == "AA" || code == "UU"
}
