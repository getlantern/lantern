package helper

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"golang.org/x/crypto/chacha20poly1305"
)

const (
	stateFile = "state.bin"
	// stateAD binds the sealed state to its purpose.
	stateAD = "lantern-helper-state-v1"
)

// state is everything the engine keeps. It is sealed on disk with the key
// from the OS keystore, and never logged.
type state struct {
	V          int    `json:"v"`
	DeviceSeed []byte `json:"device_seed,omitempty"`
	// MyName is only the last name used, to prefill the next prompt. Each
	// invite and claim keeps its own.
	MyName   string     `json:"my_name,omitempty"`
	Invites  []*invite  `json:"invites,omitempty"`
	Claims   []*claim   `json:"claims,omitempty"`
	Pairings []*pairing `json:"pairings,omitempty"`
}

// invite is one this device created and has not seen decided. A cancelled
// invite is a tombstone: hidden from the UI, kept until it expires so that a
// late claim on it is rejected rather than left waiting.
type invite struct {
	ID      string    `json:"id"`
	Secret  []byte    `json:"secret"`
	Created time.Time `json:"created"`
	State   string    `json:"state"` // "pending", "claimed" or "cancelled"
	// InviterName is the name this user gave for this invite, sealed for the
	// volunteer at approval. Kept per invite: two invites can carry two names.
	InviterName   string `json:"inviter_name,omitempty"`
	VolunteerPub  []byte `json:"volunteer_pub,omitempty"`
	VolunteerName string `json:"volunteer_name,omitempty"`
	Code          string `json:"code,omitempty"`
}

// claim is an invite this device claimed and has not yet seen approved.
type claim struct {
	ID      string    `json:"id"`
	Secret  []byte    `json:"secret"`
	Created time.Time `json:"created"`
	Code    string    `json:"code"`
	// Name is the name this user gave the inviter with this claim.
	Name string `json:"name,omitempty"`
	// Provisional marks a claim saved before it was sent, whose answer has
	// not come back. Blob is the sealed name it sent, so a retry sends the
	// identical request with the device seed.
	Provisional bool   `json:"provisional,omitempty"`
	Blob        []byte `json:"blob,omitempty"`
}

// pairing is one this device is in. Role is this device's side.
type pairing struct {
	ID    string    `json:"id"`
	Role  string    `json:"role"`
	Name  string    `json:"name,omitempty"`
	Since time.Time `json:"since"`
	// InviteHash is the hash of the invite a volunteer pairing came from, so
	// re-opening that link is told apart from a link someone else used.
	// State only; empty for pairings saved before it was kept.
	InviteHash []byte `json:"invite_hash,omitempty"`
}

const (
	RoleInviter   = "inviter"
	RoleVolunteer = "volunteer"
)

// load reads the sealed state. A missing file is an empty state; any other
// read error fails, so the file is never overwritten. A file that does not
// open under the key means the keystore now returns another key (an OS
// reset, a restored backup): the file is moved to an unused state.bin.bak
// name, never replaced, the state starts empty, and unlock's answer says
// keystore_reset so the UI can tell the user. If it cannot be moved, load
// fails.
func (e *Engine) load() error {
	e.st = state{V: 1}
	path := filepath.Join(e.dir, stateFile)
	data, err := os.ReadFile(path)
	if errors.Is(err, fs.ErrNotExist) {
		return nil
	}
	if err != nil {
		return errCode(CodeInternal)
	}
	if st, ok := e.open(data); ok {
		e.st = st
		return nil
	}
	bak, err := unusedName(path + ".bak")
	if err != nil {
		return err
	}
	if err := os.Rename(path, bak); err != nil {
		return errCode(CodeInternal)
	}
	e.reset = true
	return nil
}

// unusedName returns base, or base.1, base.2 and so on, whichever is first
// free, so that an earlier backup is never overwritten.
func unusedName(base string) (string, error) {
	for n := 0; n < 1000; n++ {
		name := base
		if n > 0 {
			name = fmt.Sprintf("%s.%d", base, n)
		}
		_, err := os.Lstat(name)
		if errors.Is(err, fs.ErrNotExist) {
			return name, nil
		}
		if err != nil {
			return "", errCode(CodeInternal)
		}
	}
	return "", errCode(CodeInternal)
}

func (e *Engine) open(data []byte) (state, bool) {
	aead, err := chacha20poly1305.New(e.key)
	if err != nil || len(data) < chacha20poly1305.NonceSize+aead.Overhead() {
		return state{}, false
	}
	pt, err := aead.Open(nil, data[:chacha20poly1305.NonceSize], data[chacha20poly1305.NonceSize:], []byte(stateAD))
	if err != nil {
		return state{}, false
	}
	var st state
	if json.Unmarshal(pt, &st) != nil {
		return state{}, false
	}
	return st, true
}

// save seals the state and replaces the file atomically, owner-only.
func (e *Engine) save() error {
	pt, err := json.Marshal(e.st)
	if err != nil {
		return errCode(CodeInternal)
	}
	aead, err := chacha20poly1305.New(e.key)
	if err != nil {
		return errCode(CodeInternal)
	}
	nonce := make([]byte, chacha20poly1305.NonceSize)
	if _, err := io.ReadFull(e.rand, nonce); err != nil {
		return errCode(CodeInternal)
	}
	sealed := aead.Seal(nonce, nonce, pt, []byte(stateAD))
	if err := os.MkdirAll(e.dir, 0o700); err != nil {
		return errCode(CodeInternal)
	}
	if err := os.Chmod(e.dir, 0o700); err != nil {
		return errCode(CodeInternal)
	}
	tmp := filepath.Join(e.dir, stateFile+".tmp")
	if err := writeSynced(tmp, sealed); err != nil {
		_ = os.Remove(tmp)
		return errCode(CodeInternal)
	}
	if err := os.Rename(tmp, filepath.Join(e.dir, stateFile)); err != nil {
		return errCode(CodeInternal)
	}
	return nil
}

// writeSynced writes data to path, owner-only even if path already existed
// with wider permissions, and flushes it to disk before it is renamed.
func writeSynced(path string, data []byte) error {
	f, err := os.OpenFile(path, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0o600)
	if err != nil {
		return err
	}
	if err := f.Chmod(0o600); err != nil {
		f.Close()
		return err
	}
	if _, err := f.Write(data); err != nil {
		f.Close()
		return err
	}
	if err := f.Sync(); err != nil {
		f.Close()
		return err
	}
	return f.Close()
}

// int64JSON reads an int64 written as a JSON number or, as protojson writes
// it, a string.
type int64JSON int64

func (n *int64JSON) UnmarshalJSON(b []byte) error {
	s := strings.Trim(string(b), `"`)
	if s == "" || s == "null" {
		*n = 0
		return nil
	}
	v, err := strconv.ParseInt(s, 10, 64)
	if err != nil {
		return err
	}
	*n = int64JSON(v)
	return nil
}
