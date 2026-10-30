// Package helper is the device side of helper invites in the Lantern app. It
// creates and claims invites, shows the matching code, approves or rejects
// claims, ends pairings, and keeps the names of the people this device helps
// or is helped by.
//
// The invite secrets, the device key and the names live only in this
// package's state file, sealed with a key from the OS keystore that the app
// passes to "unlock". Requests to lantern-cloud go through Relay, to radiance,
// and carry only hashes, public keys and encrypted names. Nothing here logs.
package helper

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"io"
	"maps"
	"sync"
	"time"

	"golang.org/x/crypto/chacha20poly1305"
)

// InviteTTL is how long lantern-cloud keeps an invite. Local invites and
// claims older than this are forgotten, since they can no longer be decided.
const InviteTTL = 48 * time.Hour

// Relay sends one HelperService request through radiance. It returns
// lantern-cloud's status, its JSON body on a 2xx and its error text otherwise.
// An error means the request never got an answer.
type Relay func(ctx context.Context, op string, body []byte) (status int, resp []byte, errText string, err error)

// Activity is radiance's helper.Activity: today's sharing time and bytes.
type Activity struct {
	Day           string `json:"day"`
	ActiveSeconds int64  `json:"active_seconds"`
	RelayedBytes  uint64 `json:"relayed_bytes"`
}

// ActivityFunc reads today's Activity from radiance.
type ActivityFunc func(ctx context.Context) (Activity, error)

// Engine runs helper-invite operations for the UI, one at a time.
type Engine struct {
	dir        string
	relay      Relay
	activityFn ActivityFunc
	now        func() time.Time
	rand       io.Reader

	mu       sync.Mutex
	key      []byte
	st       state
	online   map[string]bool
	activity *Activity
	// reset is set when unlock found a state file the key could not open.
	reset bool
	// helpersPending is set when an op changed the pairings in which this
	// device is helped, and cleared by the refresh that reports it. An op
	// can change them and then fail, and the next refresh would otherwise
	// compare against the changed set and never say so. It is kept in
	// memory only: after a restart the app fetches its config anyway.
	helpersPending bool
	// newHelpingPending is set when an op found a new pairing this device
	// volunteers in, and cleared by the first view an op returns, which
	// reports it as new_helping. The op that found it can fail after
	// consuming the claim that found it, and only this flag still says so.
	// Memory only, like helpersPending.
	newHelpingPending bool
	// dirty is set when a save failed, so the state in memory holds changes
	// (a merged pairing, a consumed claim) the file does not. Every op
	// retries the save first.
	dirty bool
}

// NewEngine returns an engine that keeps its state in dir.
func NewEngine(dir string, relay Relay, activity ActivityFunc) *Engine {
	return &Engine{dir: dir, relay: relay, activityFn: activity, now: time.Now, rand: rand.Reader,
		online: map[string]bool{}}
}

// Call runs op with JSON args and returns its JSON result. Its errors are
// *Error.
func (e *Engine) Call(ctx context.Context, op string, args []byte) ([]byte, error) {
	e.mu.Lock()
	defer e.mu.Unlock()
	if len(args) == 0 || string(args) == "null" {
		args = []byte("{}")
	}
	if op == "unlock" {
		return e.unlock(args)
	}
	if e.key == nil {
		return nil, errCode(CodeLocked)
	}
	if e.dirty {
		_ = e.save()
	}
	var out any
	var err error
	helpersBefore := e.inviterPairings()
	switch op {
	case "view":
		out = e.view()
	case "refresh":
		out, err = e.refresh(ctx)
	case "create_invite":
		out, err = e.createInvite(ctx, args)
	case "decide":
		out, err = e.decide(ctx, args)
	case "forget_invite":
		out, err = e.forgetInvite(ctx, args)
	case "claim":
		out, err = e.claim(ctx, args)
	case "end_pairing":
		out, err = e.endPairing(ctx, args)
	case "end_all_helpers":
		out, err = e.endAllHelpers(ctx)
	case "rename_helper":
		out, err = e.renameHelper(args)
	default:
		return nil, errCode(CodeInternal)
	}
	if !maps.Equal(helpersBefore, e.inviterPairings()) {
		e.helpersPending = true
	}
	if err != nil {
		return nil, err
	}
	if v, ok := out.(View); ok {
		if op == "refresh" && e.helpersPending {
			v.HelpersChanged = true
			e.helpersPending = false
		}
		out = e.withNewHelping(v)
	}
	b, err := json.Marshal(out)
	if err != nil {
		return nil, errCode(CodeInternal)
	}
	return b, nil
}

func (e *Engine) unlock(args []byte) ([]byte, error) {
	var a struct {
		Key string `json:"key"`
	}
	if json.Unmarshal(args, &a) != nil {
		return nil, errCode(CodeInternal)
	}
	key, err := base64.StdEncoding.DecodeString(a.Key)
	if err != nil || len(key) != chacha20poly1305.KeySize {
		return nil, errCode(CodeInternal)
	}
	e.key = key
	e.reset = false
	e.dirty = false
	if err := e.load(); err != nil {
		// Stay locked, so nothing saves over a file that could not be read
		// or moved aside.
		e.key = nil
		e.st = state{}
		return nil, err
	}
	v := e.withNewHelping(e.view())
	v.KeystoreReset = e.reset
	return json.Marshal(v)
}

// withNewHelping reports a pending new pairing to help in v, once.
func (e *Engine) withNewHelping(v View) View {
	if e.newHelpingPending {
		v.NewHelping = true
		e.newHelpingPending = false
	}
	return v
}

func (e *Engine) newID() string {
	b := make([]byte, 8)
	_, _ = io.ReadFull(e.rand, b)
	return hex.EncodeToString(b)
}

// post sends req to op and decodes a 2xx answer into resp.
func (e *Engine) post(ctx context.Context, op string, req, resp any) error {
	body, err := json.Marshal(req)
	if err != nil {
		return errCode(CodeInternal)
	}
	status, data, errText, err := e.relay(ctx, op, body)
	if err != nil {
		return errCode(CodeUnavailable)
	}
	if status < 200 || status >= 300 {
		return statusError(op, status, errText)
	}
	if resp != nil && len(data) > 0 && json.Unmarshal(data, resp) != nil {
		return errCode(CodeUnavailable)
	}
	return nil
}

// View is what the UI shows.
type View struct {
	Unlocked   bool          `json:"unlocked"`
	MyName     string        `json:"my_name"`
	Invites    []InviteView  `json:"invites"`
	Claims     []ClaimView   `json:"claims"`
	Helpers    []PairingView `json:"helpers"`
	Helping    []PairingView `json:"helping"`
	Activity   *Activity     `json:"activity,omitempty"`
	NewHelping bool          `json:"new_helping"`
	// HelpersChanged is set in refresh's answer when the pairings in which
	// this device is helped changed since the last refresh that said so
	// (in this refresh, or in an op that changed them and then failed), so
	// the app fetches the config that carries those helpers' routes.
	HelpersChanged bool `json:"helpers_changed,omitempty"`
	// KeystoreReset is set only in unlock's answer, when the old state could
	// not be opened and was kept as state.bin.bak.
	KeystoreReset bool `json:"keystore_reset,omitempty"`
}

type InviteView struct {
	ID            string `json:"id"`
	State         string `json:"state"`
	Link          string `json:"link,omitempty"`
	ExpiresUnix   int64  `json:"expires_unix"`
	Code          string `json:"code,omitempty"`
	VolunteerName string `json:"volunteer_name,omitempty"`
	InviterName   string `json:"inviter_name,omitempty"`
}

type ClaimView struct {
	ID          string `json:"id"`
	Code        string `json:"code"`
	ExpiresUnix int64  `json:"expires_unix"`
	// Provisional is a claim whose sending has not been confirmed, so the
	// inviter may not have it. It is retried by claiming its link again.
	Provisional bool `json:"provisional,omitempty"`
}

type PairingView struct {
	PairingID string `json:"pairing_id"`
	Name      string `json:"name"`
	Online    bool   `json:"online,omitempty"`
	SinceUnix int64  `json:"since_unix"`
}
