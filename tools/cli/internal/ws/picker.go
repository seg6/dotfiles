package ws

import (
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"strings"
	"time"
	"unicode"

	"charm.land/bubbles/v2/textinput"
	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
)

type PickMode string

const (
	PickOpen PickMode = "open"
	PickKill PickMode = "kill"
)

type PickRequest struct {
	Mode       PickMode
	Candidates []Candidate
}

type Picker interface {
	Choose(context.Context, PickRequest) (int, bool, error)
}

type BubblePicker struct {
	Input      io.Reader
	Output     io.Writer
	LoadStatus func(context.Context, string) GitStatus
	Now        func() time.Time
	UI         UIConfig
}

func NewBubblePicker(ui UIConfig) *BubblePicker {
	return &BubblePicker{
		Input:      os.Stdin,
		Output:     os.Stdout,
		LoadStatus: LoadGitStatus,
		Now:        time.Now,
		UI:         ui,
	}
}

func (picker *BubblePicker) Choose(ctx context.Context, request PickRequest) (int, bool, error) {
	if len(request.Candidates) == 0 {
		return 0, false, nil
	}
	model := newPickerModel(ctx, request, picker.LoadStatus, picker.Now, picker.UI)
	result, err := tea.NewProgram(model,
		tea.WithContext(ctx),
		tea.WithInput(picker.Input),
		tea.WithOutput(picker.Output),
	).Run()
	if errors.Is(err, tea.ErrInterrupted) || errors.Is(err, context.Canceled) {
		return 0, false, nil
	}
	if err != nil {
		return 0, false, fmt.Errorf("run workspace interface: %w", err)
	}
	final, ok := result.(*pickerModel)
	if !ok || final.chosen < 0 || final.chosen >= len(request.Candidates) {
		return 0, false, nil
	}
	return final.chosen, true, nil
}

type gitStatusMsg struct {
	path       string
	generation uint64
	status     GitStatus
}

type pickerModel struct {
	ctx           context.Context
	request       PickRequest
	input         textinput.Model
	filtered      []int
	cursor        int
	offset        int
	width         int
	height        int
	chosen        int
	status        GitStatus
	statusPath    string
	statusBusy    bool
	generation    uint64
	loadStatus    func(context.Context, string) GitStatus
	now           func() time.Time
	ui            UIConfig
	dimStyle      lipgloss.Style
	sessionStyle  lipgloss.Style
	branchStyle   lipgloss.Style
	warningStyle  lipgloss.Style
	errorStyle    lipgloss.Style
	cleanStyle    lipgloss.Style
	selectedStyle lipgloss.Style
}

func newPickerModel(ctx context.Context, request PickRequest, loader func(context.Context, string) GitStatus, now func() time.Time, ui UIConfig) *pickerModel {
	if loader == nil {
		loader = LoadGitStatus
	}
	if now == nil {
		now = time.Now
	}
	input := textinput.New()
	input.Prompt = "filter: "
	input.Placeholder = "type to filter"
	styles := textinput.DefaultDarkStyles()
	styles.Focused.Prompt = lipgloss.NewStyle().Foreground(lipgloss.Color(ui.Colors.Accent)).Bold(true)
	styles.Focused.Placeholder = lipgloss.NewStyle().Foreground(lipgloss.Color(ui.Colors.Muted))
	styles.Focused.Text = lipgloss.NewStyle()
	styles.Cursor.Color = lipgloss.Color(ui.Colors.Accent)
	input.SetStyles(styles)

	model := &pickerModel{
		ctx:           ctx,
		request:       request,
		input:         input,
		width:         80,
		height:        24,
		chosen:        -1,
		loadStatus:    loader,
		now:           now,
		ui:            ui,
		dimStyle:      lipgloss.NewStyle().Foreground(lipgloss.Color(ui.Colors.Muted)),
		sessionStyle:  lipgloss.NewStyle().Foreground(lipgloss.Color(ui.Colors.Session)),
		branchStyle:   lipgloss.NewStyle().Foreground(lipgloss.Color(ui.Colors.Branch)),
		warningStyle:  lipgloss.NewStyle().Foreground(lipgloss.Color(ui.Colors.Warning)),
		errorStyle:    lipgloss.NewStyle().Foreground(lipgloss.Color(ui.Colors.Error)),
		cleanStyle:    lipgloss.NewStyle().Foreground(lipgloss.Color(ui.Colors.Session)),
		selectedStyle: lipgloss.NewStyle().Background(lipgloss.Color(ui.Colors.Accent)).Foreground(lipgloss.Color(ui.Colors.SelectedForeground)).Bold(true),
	}
	model.resizeInput(model.contentWidth())
	model.applyFilter()
	return model
}

func (model *pickerModel) Init() tea.Cmd {
	return tea.Batch(model.input.Focus(), model.loadSelectedStatus())
}

func (model *pickerModel) Update(message tea.Msg) (tea.Model, tea.Cmd) {
	switch message := message.(type) {
	case tea.WindowSizeMsg:
		model.width = max(message.Width, 20)
		model.height = max(message.Height, 10)
		model.resizeInput(model.contentWidth())
		model.ensureVisible()
		return model, nil
	case gitStatusMsg:
		if message.generation == model.generation && message.path == model.selectedPath() {
			model.status = message.status
			model.statusPath = message.path
			model.statusBusy = false
		}
		return model, nil
	case tea.KeyPressMsg:
		switch message.String() {
		case "esc", "ctrl+c":
			return model, tea.Quit
		case "enter":
			if len(model.filtered) > 0 {
				model.chosen = model.filtered[model.cursor]
			}
			return model, tea.Quit
		case "up", "ctrl+k", "shift+tab":
			model.move(-1)
			return model, model.loadSelectedStatus()
		case "down", "ctrl+j", "tab":
			model.move(1)
			return model, model.loadSelectedStatus()
		case "pgup":
			model.move(-model.visibleRows())
			return model, model.loadSelectedStatus()
		case "pgdown":
			model.move(model.visibleRows())
			return model, model.loadSelectedStatus()
		case "ctrl+u":
			model.input.SetValue("")
			model.applyFilter()
			return model, model.loadSelectedStatus()
		}
	}

	previous := model.input.Value()
	updated, command := model.input.Update(message)
	model.input = updated
	if model.input.Value() != previous {
		model.applyFilter()
		return model, tea.Batch(command, model.loadSelectedStatus())
	}
	return model, command
}

func (model *pickerModel) View() tea.View {
	contentWidth := model.contentWidth()
	var lines []string
	lines = append(lines, model.renderHeader(contentWidth))
	lines = append(lines, "")
	lines = append(lines, model.renderTableHeader(contentWidth))

	end := min(model.offset+model.visibleRows(), len(model.filtered))
	for visibleIndex := model.offset; visibleIndex < end; visibleIndex++ {
		candidate := model.request.Candidates[model.filtered[visibleIndex]]
		row := model.renderRow(candidate, contentWidth, visibleIndex == model.cursor)
		lines = append(lines, row)
	}
	for len(lines) < 3+model.visibleRows() {
		lines = append(lines, "")
	}

	lines = append(lines, "")
	lines = append(lines, model.renderPath(contentWidth))
	lines = append(lines, model.renderDetails(contentWidth))
	lines = append(lines, "")
	lines = append(lines, model.dimStyle.Render(model.helpText()))

	prefix := strings.Repeat(" ", model.leftPadding())
	for index := range lines {
		lines[index] = prefix + lines[index]
	}
	view := tea.NewView(strings.Join(lines, "\n"))
	view.AltScreen = true
	view.WindowTitle = "workspace"
	return view
}

func (model *pickerModel) applyFilter() {
	query := model.input.Value()
	model.filtered = model.filtered[:0]
	for index, candidate := range model.request.Candidates {
		if fuzzyMatch(query, candidate.SearchValue()) {
			model.filtered = append(model.filtered, index)
		}
	}
	model.cursor = 0
	model.offset = 0
	model.status = GitStatus{}
	model.statusPath = ""
	model.statusBusy = false
}

func fuzzyMatch(query, value string) bool {
	for _, token := range strings.Fields(strings.ToLower(query)) {
		tokenRunes := []rune(token)
		position := 0
		for _, candidate := range strings.ToLower(value) {
			if position < len(tokenRunes) && candidate == tokenRunes[position] {
				position++
			}
		}
		if position != len(tokenRunes) {
			return false
		}
	}
	return true
}

func (model *pickerModel) move(delta int) {
	if len(model.filtered) == 0 {
		return
	}
	model.cursor = (model.cursor + delta) % len(model.filtered)
	if model.cursor < 0 {
		model.cursor += len(model.filtered)
	}
	model.ensureVisible()
}

func (model *pickerModel) ensureVisible() {
	rows := model.visibleRows()
	if model.cursor < model.offset {
		model.offset = model.cursor
	}
	if model.cursor >= model.offset+rows {
		model.offset = model.cursor - rows + 1
	}
	maximum := max(len(model.filtered)-rows, 0)
	model.offset = min(max(model.offset, 0), maximum)
}

func (model *pickerModel) selected() (Candidate, bool) {
	if len(model.filtered) == 0 || model.cursor < 0 || model.cursor >= len(model.filtered) {
		return Candidate{}, false
	}
	return model.request.Candidates[model.filtered[model.cursor]], true
}

func (model *pickerModel) selectedPath() string {
	candidate, ok := model.selected()
	if !ok || candidate.Project == nil {
		return ""
	}
	return candidate.Project.Path
}

func (model *pickerModel) loadSelectedStatus() tea.Cmd {
	path := model.selectedPath()
	model.generation++
	generation := model.generation
	model.status = GitStatus{}
	model.statusPath = ""
	model.statusBusy = path != ""
	if path == "" {
		return nil
	}
	return func() tea.Msg {
		return gitStatusMsg{path: path, generation: generation, status: model.loadStatus(model.ctx, path)}
	}
}

func (model *pickerModel) contentWidth() int {
	available := max(model.width-(model.ui.SidePadding*2), 16)
	return min(available, model.ui.MaxWidth)
}

func (model *pickerModel) leftPadding() int {
	return max((model.width-model.contentWidth())/2, 0)
}

func (model *pickerModel) visibleRows() int {
	return max(model.height-9, 1)
}

func (model *pickerModel) renderHeader(width int) string {
	summary := model.headerSummary(width)
	input := model.input.View()
	if summary == "" {
		return input
	}
	space := max(width-lipgloss.Width(input)-lipgloss.Width(summary), 1)
	return input + strings.Repeat(" ", space) + model.dimStyle.Render(summary)
}

func (model *pickerModel) resizeInput(width int) {
	summary := model.headerSummary(width)
	reserved := lipgloss.Width(model.input.Prompt)
	if summary != "" {
		reserved += lipgloss.Width(summary) + 2
	}
	model.input.SetWidth(max(width-reserved, 8))
}

func (model *pickerModel) headerSummary(width int) string {
	sessions := 0
	projectIDs := make(map[string]struct{})
	for _, candidate := range model.request.Candidates {
		if candidate.State == CandidateSession {
			sessions++
		}
		if candidate.Project != nil {
			projectIDs[candidate.Project.ID] = struct{}{}
		}
	}
	sessionWord := "sessions"
	if sessions == 1 {
		sessionWord = "session"
	}
	projectWord := "projects"
	if len(projectIDs) == 1 {
		projectWord = "project"
	}
	summary := fmt.Sprintf("%d %s / %d %s", sessions, sessionWord, len(projectIDs), projectWord)
	if model.request.Mode == PickKill {
		summary = fmt.Sprintf("%d %s", sessions, sessionWord)
	}
	minimumInputWidth := lipgloss.Width(model.input.Prompt) + 8
	if minimumInputWidth+2+lipgloss.Width(summary) > width {
		return ""
	}
	return summary
}

type tableWidths struct {
	wide      bool
	state     int
	namespace int
	project   int
	branch    int
	gap       int
}

func (model *pickerModel) widths(width int) tableWidths {
	result := tableWidths{
		wide:      width >= 50,
		state:     len("session"),
		namespace: len("namespace"),
		project:   len("project"),
		branch:    len("branch"),
		gap:       model.ui.ColumnGap,
	}
	if !result.wide {
		result.project = max(width-result.state-result.gap, 8)
		return result
	}
	for _, index := range model.filtered {
		candidate := model.request.Candidates[index]
		result.namespace = max(result.namespace, lipgloss.Width(candidate.Namespace))
		result.project = max(result.project, lipgloss.Width(candidate.Name))
		result.branch = max(result.branch, lipgloss.Width(candidate.Branch))
	}
	result.namespace = min(result.namespace, 22)
	result.project = min(result.project, 32)
	result.branch = min(result.branch, 24)

	overflow := result.state + result.namespace + result.project + result.branch + (result.gap * 3) - width
	shrink := min(max(result.branch-6, 0), max(overflow, 0))
	result.branch -= shrink
	overflow -= shrink
	shrink = min(max(result.project-10, 0), max(overflow, 0))
	result.project -= shrink
	overflow -= shrink
	shrink = min(max(result.namespace-9, 0), max(overflow, 0))
	result.namespace -= shrink
	overflow -= shrink
	if overflow > 0 {
		result.wide = false
		result.project = max(width-result.state-result.gap, 8)
	}
	return result
}

func (model *pickerModel) renderTableHeader(width int) string {
	columns := model.widths(width)
	gap := strings.Repeat(" ", columns.gap)
	if !columns.wide {
		return model.dimStyle.Render(padRight("state", columns.state) + gap + padRight("project", columns.project))
	}
	return model.dimStyle.Render(
		padRight("state", columns.state) + gap +
			padRight("namespace", columns.namespace) + gap +
			padRight("project", columns.project) + gap +
			padRight("branch", columns.branch),
	)
}

func (model *pickerModel) renderRow(candidate Candidate, width int, selected bool) string {
	columns := model.widths(width)
	gap := strings.Repeat(" ", columns.gap)
	plain := plainCandidateRow(candidate, columns)
	if selected {
		return model.selectedStyle.Width(width).Render(plain)
	}

	state := padRight(string(candidate.State), columns.state)
	if candidate.State == CandidateSession {
		state = model.sessionStyle.Render(state)
	} else {
		state = model.dimStyle.Render(state)
	}
	if !columns.wide {
		return state + gap + truncate(padRight(candidateIdentity(candidate), columns.project), columns.project)
	}
	return state + gap +
		padRight(truncate(candidate.Namespace, columns.namespace), columns.namespace) + gap +
		padRight(truncate(candidate.Name, columns.project), columns.project) + gap +
		model.branchStyle.Render(padRight(truncate(candidate.Branch, columns.branch), columns.branch))
}

func plainCandidateRow(candidate Candidate, columns tableWidths) string {
	state := padRight(string(candidate.State), columns.state)
	gap := strings.Repeat(" ", columns.gap)
	if !columns.wide {
		return state + gap + padRight(truncate(candidateIdentity(candidate), columns.project), columns.project)
	}
	return state + gap +
		padRight(truncate(candidate.Namespace, columns.namespace), columns.namespace) + gap +
		padRight(truncate(candidate.Name, columns.project), columns.project) + gap +
		padRight(truncate(candidate.Branch, columns.branch), columns.branch)
}

func candidateIdentity(candidate Candidate) string {
	if candidate.Project != nil {
		return candidate.Project.ID
	}
	return candidate.Name
}

func (model *pickerModel) renderPath(width int) string {
	candidate, ok := model.selected()
	if !ok {
		return model.dimStyle.Render("no matches")
	}
	return model.dimStyle.Render(truncate(candidate.Path, width))
}

func (model *pickerModel) renderDetails(width int) string {
	candidate, ok := model.selected()
	if !ok {
		return ""
	}
	var parts []string
	if candidate.Branch != "" {
		parts = append(parts, model.branchStyle.Render("branch "+candidate.Branch))
	}
	if candidate.State == CandidateSession {
		word := "windows"
		if candidate.Windows == 1 {
			word = "window"
		}
		parts = append(parts, fmt.Sprintf("%d %s", candidate.Windows, word))
	} else if candidate.LastUsed.IsZero() {
		parts = append(parts, "never opened")
	} else {
		parts = append(parts, "last used "+relativeTime(model.now(), candidate.LastUsed))
	}

	if candidate.Project != nil {
		switch {
		case model.statusBusy:
			parts = append(parts, model.dimStyle.Render("checking status"))
		case model.statusPath != candidate.Project.Path:
		case model.status.Err != "":
			parts = append(parts, model.errorStyle.Render("git status unavailable"))
		case model.status.Conflicts == 0 && model.status.Changed == 0 && model.status.Untracked == 0:
			parts = append(parts, model.cleanStyle.Render("clean"))
		default:
			if model.status.Conflicts > 0 {
				parts = append(parts, model.errorStyle.Render(fmt.Sprintf("%d conflicts", model.status.Conflicts)))
			}
			if model.status.Changed > 0 {
				parts = append(parts, model.warningStyle.Render(fmt.Sprintf("%d changed", model.status.Changed)))
			}
			if model.status.Untracked > 0 {
				parts = append(parts, model.warningStyle.Render(fmt.Sprintf("%d untracked", model.status.Untracked)))
			}
		}
	}
	return lipgloss.NewStyle().MaxWidth(width).Render(strings.Join(parts, model.dimStyle.Render(" | ")))
}

func (model *pickerModel) helpText() string {
	action := "open"
	if model.request.Mode == PickKill {
		action = "kill"
	}
	return "enter " + action + "   arrows/ctrl-j/ctrl-k move   ctrl-u clear   esc close"
}

func relativeTime(now, value time.Time) string {
	duration := now.Sub(value)
	if duration < 0 {
		duration = 0
	}
	switch {
	case duration < time.Minute:
		return "just now"
	case duration < time.Hour:
		return fmt.Sprintf("%dm ago", int(duration.Minutes()))
	case duration < 24*time.Hour:
		return fmt.Sprintf("%dh ago", int(duration.Hours()))
	default:
		return fmt.Sprintf("%dd ago", int(duration.Hours()/24))
	}
}

func truncate(value string, width int) string {
	if width <= 0 {
		return ""
	}
	if lipgloss.Width(value) <= width {
		return value
	}
	if width == 1 {
		return "…"
	}
	var result strings.Builder
	used := 0
	for _, character := range value {
		characterWidth := 1
		if unicode.Is(unicode.Mn, character) {
			characterWidth = 0
		}
		if used+characterWidth > width-1 {
			break
		}
		result.WriteRune(character)
		used += characterWidth
	}
	return result.String() + "…"
}

func padRight(value string, width int) string {
	return value + strings.Repeat(" ", max(width-lipgloss.Width(value), 0))
}
