package ws

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"syscall"
	"time"
)

const stateVersion = 1

type State struct {
	Version int                  `json:"version"`
	Recent  map[string]time.Time `json:"recent"`
}

type StateStore struct {
	Path string
	Now  func() time.Time
}

func NewStateStore(config Config) *StateStore {
	return &StateStore{
		Path: filepath.Join(config.StateDir, "state.json"),
		Now:  time.Now,
	}
}

func (store *StateStore) Load() (State, error) {
	var state State
	err := store.withLock(syscall.LOCK_SH, func() error {
		var err error
		state, err = store.loadUnlocked()
		return err
	})
	return state, err
}

func (store *StateStore) Touch(projectID string) error {
	return store.withLock(syscall.LOCK_EX, func() error {
		state, err := store.loadUnlocked()
		if err != nil {
			return err
		}
		state.Recent[projectID] = store.Now().UTC()
		return store.writeUnlocked(state)
	})
}

func (store *StateStore) withLock(operation int, action func() error) error {
	if err := os.MkdirAll(filepath.Dir(store.Path), 0o700); err != nil {
		return fmt.Errorf("create state directory: %w", err)
	}

	lock, err := os.OpenFile(store.Path+".lock", os.O_CREATE|os.O_RDWR, 0o600)
	if err != nil {
		return fmt.Errorf("open state lock: %w", err)
	}
	defer lock.Close()

	if err := syscall.Flock(int(lock.Fd()), operation); err != nil {
		return fmt.Errorf("lock state: %w", err)
	}
	defer func() { _ = syscall.Flock(int(lock.Fd()), syscall.LOCK_UN) }()

	return action()
}

func (store *StateStore) loadUnlocked() (State, error) {
	state := State{Version: stateVersion, Recent: make(map[string]time.Time)}
	data, err := os.ReadFile(store.Path)
	if errors.Is(err, os.ErrNotExist) {
		return state, nil
	}
	if err != nil {
		return State{}, fmt.Errorf("read state: %w", err)
	}
	if err := json.Unmarshal(data, &state); err != nil {
		return State{}, fmt.Errorf("decode state: %w", err)
	}
	if state.Version != stateVersion {
		return State{}, fmt.Errorf("unsupported state version %d", state.Version)
	}
	if state.Recent == nil {
		state.Recent = make(map[string]time.Time)
	}
	return state, nil
}

func (store *StateStore) writeUnlocked(state State) error {
	state.Version = stateVersion
	data, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		return fmt.Errorf("encode state: %w", err)
	}
	data = append(data, '\n')

	temporary, err := os.CreateTemp(filepath.Dir(store.Path), ".state-*.json")
	if err != nil {
		return fmt.Errorf("create state temporary file: %w", err)
	}
	temporaryPath := temporary.Name()
	defer os.Remove(temporaryPath)

	if err := temporary.Chmod(0o600); err != nil {
		temporary.Close()
		return fmt.Errorf("set state permissions: %w", err)
	}
	if _, err := temporary.Write(data); err != nil {
		temporary.Close()
		return fmt.Errorf("write state: %w", err)
	}
	if err := temporary.Sync(); err != nil {
		temporary.Close()
		return fmt.Errorf("sync state: %w", err)
	}
	if err := temporary.Close(); err != nil {
		return fmt.Errorf("close state: %w", err)
	}
	if err := os.Rename(temporaryPath, store.Path); err != nil {
		return fmt.Errorf("replace state: %w", err)
	}
	return nil
}
