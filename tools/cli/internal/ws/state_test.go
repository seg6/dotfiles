package ws

import (
	"os"
	"path/filepath"
	"sync"
	"testing"
	"time"
)

func TestStatePersistsTouchesWithoutReadingLegacyHistory(t *testing.T) {
	root := t.TempDir()
	statePath := filepath.Join(root, "ws", "state.json")
	legacyPath := filepath.Join(root, "ws", "history.json")
	if err := os.MkdirAll(filepath.Dir(legacyPath), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(legacyPath, []byte(`{"version":1,"projects":{"legacy/project":{"last_used":"2020-01-01T00:00:00Z"}}}`), 0o600); err != nil {
		t.Fatal(err)
	}

	now := time.Date(2026, 8, 15, 18, 0, 0, 0, time.UTC)
	store := &StateStore{Path: statePath, Now: func() time.Time { return now }}
	if err := store.Touch("meyer/processor"); err != nil {
		t.Fatal(err)
	}
	state, err := store.Load()
	if err != nil {
		t.Fatal(err)
	}
	if len(state.Recent) != 1 || !state.Recent["meyer/processor"].Equal(now) {
		t.Fatalf("state = %#v", state)
	}
	if _, exists := state.Recent["legacy/project"]; exists {
		t.Fatal("legacy history was imported")
	}
}

func TestStateConcurrentTouchesDoNotLoseUpdates(t *testing.T) {
	store := &StateStore{Path: filepath.Join(t.TempDir(), "state.json"), Now: time.Now}
	const updates = 24
	var wait sync.WaitGroup
	errors := make(chan error, updates)
	for index := range updates {
		wait.Add(1)
		go func() {
			defer wait.Done()
			errors <- store.Touch("project/" + string(rune('a'+index)))
		}()
	}
	wait.Wait()
	close(errors)
	for err := range errors {
		if err != nil {
			t.Fatal(err)
		}
	}

	state, err := store.Load()
	if err != nil {
		t.Fatal(err)
	}
	if len(state.Recent) != updates {
		t.Fatalf("state contains %d projects, want %d", len(state.Recent), updates)
	}
}
