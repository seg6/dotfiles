package ws

import (
	"context"
	"strings"
	"testing"
	"time"

	tea "charm.land/bubbletea/v2"
)

func testCandidates() []Candidate {
	projectA := Project{ID: "meyer/services-dashboard", Namespace: "meyer", Name: "services-dashboard", Path: "/workspace/meyer/services-dashboard", Branch: "main"}
	projectB := Project{ID: "clients/meyer/platform/api", Namespace: "clients/meyer/platform", Name: "api", Path: "/workspace/clients/meyer/platform/api", Branch: "feature/auth"}
	return []Candidate{
		{State: CandidateSession, Namespace: projectA.Namespace, Name: projectA.Name, Path: projectA.Path, Branch: projectA.Branch, Project: &projectA, SessionName: "ws-services-dashboard-a", Windows: 3},
		{State: CandidateProject, Namespace: projectB.Namespace, Name: projectB.Name, Path: projectB.Path, Branch: projectB.Branch, Project: &projectB, LastUsed: time.Date(2026, 8, 14, 12, 0, 0, 0, time.UTC)},
	}
}

func TestPickerFiltersFuzzilyAndPreservesCandidateIdentity(t *testing.T) {
	model := newPickerModel(context.Background(), PickRequest{Mode: PickOpen, Candidates: testCandidates()}, func(context.Context, string) GitStatus { return GitStatus{} }, time.Now, defaultUIConfig())
	model.input.SetValue("cmp api")
	model.applyFilter()
	if len(model.filtered) != 1 || model.filtered[0] != 1 {
		t.Fatalf("filtered indexes = %v", model.filtered)
	}
	updated, _ := model.Update(tea.KeyPressMsg(tea.Key{Code: tea.KeyEnter}))
	final := updated.(*pickerModel)
	if final.chosen != 1 {
		t.Fatalf("chosen = %d, want 1", final.chosen)
	}
}

func TestPickerNavigationWrapsAndIgnoresStaleGitStatus(t *testing.T) {
	model := newPickerModel(context.Background(), PickRequest{Mode: PickOpen, Candidates: testCandidates()}, func(context.Context, string) GitStatus { return GitStatus{} }, time.Now, defaultUIConfig())
	model.generation = 4
	model.statusBusy = true
	updated, _ := model.Update(tea.KeyPressMsg(tea.Key{Code: tea.KeyUp}))
	model = updated.(*pickerModel)
	if model.cursor != 1 {
		t.Fatalf("cursor = %d, want 1", model.cursor)
	}
	currentGeneration := model.generation
	updated, _ = model.Update(gitStatusMsg{path: "/workspace/meyer/services-dashboard", generation: currentGeneration - 1, status: GitStatus{Changed: 99}})
	model = updated.(*pickerModel)
	if model.status.Changed != 0 || !model.statusBusy {
		t.Fatalf("stale status applied: %#v", model.status)
	}
}

func TestPickerRowsAlignAndNarrowLayoutKeepsCanonicalIdentity(t *testing.T) {
	model := newPickerModel(context.Background(), PickRequest{Mode: PickOpen, Candidates: testCandidates()}, nil, time.Now, defaultUIConfig())
	wide := model.widths(80)
	first := plainCandidateRow(testCandidates()[0], wide)
	second := plainCandidateRow(testCandidates()[1], wide)
	if len([]rune(first)) != len([]rune(second)) {
		t.Fatalf("row widths differ:\n%q\n%q", first, second)
	}
	if wide.project != len("services-dashboard") {
		t.Fatalf("project column width = %d, want intrinsic width %d", wide.project, len("services-dashboard"))
	}
	if wide.gap != 3 || !strings.Contains(first, "session   meyer") {
		t.Fatalf("configured column gap not applied: widths=%#v row=%q", wide, first)
	}

	narrow := model.widths(45)
	row := plainCandidateRow(testCandidates()[1], narrow)
	if narrow.wide || !strings.Contains(row, "clients/meyer/platform/api") {
		t.Fatalf("narrow row = %q, widths = %#v", row, narrow)
	}
}

func TestPickerViewUsesAlternateScreenAndAdaptsToResize(t *testing.T) {
	model := newPickerModel(context.Background(), PickRequest{Mode: PickKill, Candidates: testCandidates()[:1]}, nil, time.Now, defaultUIConfig())
	updated, _ := model.Update(tea.WindowSizeMsg{Width: 120, Height: 30})
	model = updated.(*pickerModel)
	view := model.View()
	firstLine := strings.SplitN(view.Content, "\n", 2)[0]
	if !view.AltScreen || model.visibleRows() != 21 || !strings.Contains(firstLine, "filter:") || !strings.Contains(firstLine, "1 session") || strings.Contains(firstLine, "workspace") || !strings.Contains(view.Content, "enter kill") {
		t.Fatalf("unexpected view: alt=%v rows=%d content=%q", view.AltScreen, model.visibleRows(), view.Content)
	}
	if model.contentWidth() != 88 || model.leftPadding() != 16 || !strings.HasPrefix(view.Content, strings.Repeat(" ", 16)) {
		t.Fatalf("layout is not centered: width=%d padding=%d content=%q", model.contentWidth(), model.leftPadding(), view.Content)
	}

	updated, _ = model.Update(tea.WindowSizeMsg{Width: 80, Height: 24})
	model = updated.(*pickerModel)
	if model.contentWidth() != 76 || model.leftPadding() != 2 {
		t.Fatalf("compact layout = width %d padding %d, want 76 and 2", model.contentWidth(), model.leftPadding())
	}
}

func TestPickerUsesConfiguredResponsiveWidth(t *testing.T) {
	ui := defaultUIConfig()
	ui.MaxWidth = 64
	ui.SidePadding = 5
	model := newPickerModel(context.Background(), PickRequest{Mode: PickOpen, Candidates: testCandidates()}, nil, time.Now, ui)

	updated, _ := model.Update(tea.WindowSizeMsg{Width: 100, Height: 24})
	model = updated.(*pickerModel)
	if model.contentWidth() != 64 || model.leftPadding() != 18 {
		t.Fatalf("wide layout = width %d padding %d", model.contentWidth(), model.leftPadding())
	}

	updated, _ = model.Update(tea.WindowSizeMsg{Width: 70, Height: 24})
	model = updated.(*pickerModel)
	if model.contentWidth() != 60 || model.leftPadding() != 5 {
		t.Fatalf("compact layout = width %d padding %d", model.contentWidth(), model.leftPadding())
	}
}

func TestRelativeTime(t *testing.T) {
	now := time.Date(2026, 8, 15, 18, 0, 0, 0, time.UTC)
	if got := relativeTime(now, now.Add(-49*time.Hour)); got != "2d ago" {
		t.Fatalf("relativeTime() = %q", got)
	}
}
