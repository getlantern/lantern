package lanterncore

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"maps"
	"slices"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	rhelper "github.com/getlantern/radiance/helper"
	"github.com/getlantern/radiance/vpn"

	"github.com/getlantern/lantern/lantern-core/helper"
)

func TestHelperCallAnswersJSONAndNeverARawError(t *testing.T) {
	relay := func(context.Context, string, []byte) (int, []byte, string, error) {
		return 200, []byte(`{"pairings":[]}`), "", nil
	}
	lc := &LanternCore{ctx: context.Background(), helpers: helper.NewEngine(t.TempDir(), relay, nil)}

	assert.JSONEq(t, `{"error":"locked"}`, lc.HelperCall("view", "{}"))
	key := base64.StdEncoding.EncodeToString([]byte(strings.Repeat("k", 32)))
	var v map[string]any
	require.NoError(t, json.Unmarshal([]byte(lc.HelperCall("unlock", `{"key":"`+key+`"}`)), &v))
	assert.Equal(t, true, v["unlocked"])
	var r map[string]any
	require.NoError(t, json.Unmarshal([]byte(lc.HelperCall("refresh", "")), &r))
	assert.NotContains(t, r, "error")
	assert.Equal(t, true, r["unlocked"])
	assert.JSONEq(t, `{"error":"internal"}`, lc.HelperCall("no-such-op", "{}"))
}

// fakePairingKeyIPC stands in for radiance's pairing-key endpoint.
type fakePairingKeyIPC struct {
	mu     sync.Mutex
	keys   map[string]helper.PairingKey
	locked bool
	fail   bool
	block  chan struct{}
	calls  []map[string]rhelper.PairingKey
	done   chan struct{}
}

func newFakePairingKeyIPC() *fakePairingKeyIPC {
	return &fakePairingKeyIPC{keys: map[string]helper.PairingKey{}, done: make(chan struct{}, 100)}
}

func (f *fakePairingKeyIPC) setKeys(keys map[string]helper.PairingKey) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.keys = keys
}

func (f *fakePairingKeyIPC) setFail(fail bool) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.fail = fail
}

func (f *fakePairingKeyIPC) setLocked(locked bool) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.locked = locked
}

func (f *fakePairingKeyIPC) PairingKeys() (map[string]helper.PairingKey, bool) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.locked {
		return map[string]helper.PairingKey{}, false
	}
	return maps.Clone(f.keys), true
}

func (f *fakePairingKeyIPC) SetHelperPairingKeys(ctx context.Context, keys map[string]rhelper.PairingKey) error {
	defer func() { f.done <- struct{}{} }()
	f.mu.Lock()
	block := f.block
	f.mu.Unlock()
	if block != nil {
		select {
		case <-block:
		case <-ctx.Done():
			return ctx.Err()
		}
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	f.calls = append(f.calls, keys)
	if f.fail {
		return errors.New("503 backend not ready")
	}
	return nil
}

func (f *fakePairingKeyIPC) pushes() []map[string]rhelper.PairingKey {
	f.mu.Lock()
	defer f.mu.Unlock()
	return slices.Clone(f.calls)
}

// settle waits for n pushes to finish and for the pusher to go idle.
func (f *fakePairingKeyIPC) settle(t *testing.T, p *pairingKeyPusher, n int) {
	t.Helper()
	for range n {
		select {
		case <-f.done:
		case <-time.After(5 * time.Second):
			t.Fatal("push did not happen")
		}
	}
	require.Eventually(t, func() bool {
		p.mu.Lock()
		defer p.mu.Unlock()
		return !p.running
	}, 5*time.Second, time.Millisecond)
}

func (f *fakePairingKeyIPC) noMorePushes(t *testing.T) {
	t.Helper()
	select {
	case <-f.done:
		t.Fatal("unexpected push")
	case <-time.After(50 * time.Millisecond):
	}
}

func pairingKeyCore(t *testing.T, f *fakePairingKeyIPC) *LanternCore {
	relay := func(context.Context, string, []byte) (int, []byte, string, error) {
		return 200, []byte(`{"pairings":[]}`), "", nil
	}
	ctx, cancel := context.WithCancel(context.Background())
	t.Cleanup(cancel)
	return &LanternCore{
		ctx:         ctx,
		helpers:     helper.NewEngine(t.TempDir(), relay, nil),
		pairingKeys: newPairingKeyPusher(ctx, f.PairingKeys, f.SetHelperPairingKeys),
	}
}

var (
	pairingKeyA = bytes.Repeat([]byte{0xa}, 32)
	pairingKeyB = bytes.Repeat([]byte{0xb}, 32)
)

func TestPairingKeyChangePushesOnceAndUnchangedDoesNot(t *testing.T) {
	f := newFakePairingKeyIPC()
	lc := pairingKeyCore(t, f)

	lc.HelperCall("view", "{}")
	f.settle(t, lc.pairingKeys, 1)
	assert.Equal(t, []map[string]rhelper.PairingKey{{}}, f.pushes(), "the first call tells radiance there are none yet")

	lc.HelperCall("view", "{}")
	f.noMorePushes(t)

	f.setKeys(map[string]helper.PairingKey{"p1": {Key: pairingKeyA, Role: "inviter"}})
	lc.HelperCall("view", "{}")
	f.settle(t, lc.pairingKeys, 1)
	lc.HelperCall("view", "{}")
	f.noMorePushes(t)

	f.setKeys(map[string]helper.PairingKey{})
	lc.HelperCall("view", "{}")
	f.settle(t, lc.pairingKeys, 1)

	assert.Equal(t, []map[string]rhelper.PairingKey{
		{},
		{"p1": {Key: pairingKeyA, Role: "inviter"}},
		{},
	}, f.pushes(), "an empty set is pushed when the keys are gone")
}

func TestPairingKeyPushCarriesRoles(t *testing.T) {
	f := newFakePairingKeyIPC()
	f.setKeys(map[string]helper.PairingKey{
		"p1": {Key: pairingKeyA, Role: "inviter"},
		"p2": {Key: pairingKeyB, Role: "volunteer"},
	})
	lc := pairingKeyCore(t, f)
	lc.HelperCall("view", "{}")
	f.settle(t, lc.pairingKeys, 1)
	assert.Equal(t, []map[string]rhelper.PairingKey{{
		"p1": {Key: pairingKeyA, Role: "inviter"},
		"p2": {Key: pairingKeyB, Role: "volunteer"},
	}}, f.pushes())
}

func TestPairingKeyFailedPushIsRetriedByTheLiveLoop(t *testing.T) {
	f := newFakePairingKeyIPC()
	f.setKeys(map[string]helper.PairingKey{"p1": {Key: pairingKeyA, Role: "inviter"}})
	f.setFail(true)
	lc := pairingKeyCore(t, f)

	lc.HelperCall("view", "{}")
	f.settle(t, lc.pairingKeys, 1)

	// While radiance keeps failing, every pass of the live loop tries again.
	lc.pairingKeys.tick()
	f.settle(t, lc.pairingKeys, 1)

	f.setFail(false)
	lc.pairingKeys.tick()
	f.settle(t, lc.pairingKeys, 1)

	// Once it took, a pass with nothing changed pushes nothing.
	lc.pairingKeys.tick()
	f.noMorePushes(t)
	assert.Len(t, f.pushes(), 3)
	for _, p := range f.pushes() {
		assert.Equal(t, map[string]rhelper.PairingKey{"p1": {Key: pairingKeyA, Role: "inviter"}}, p)
	}
}

func TestPairingKeyLiveLoopRepushesAfterTheInterval(t *testing.T) {
	f := newFakePairingKeyIPC()
	lc := pairingKeyCore(t, f)
	now := time.Now()
	lc.pairingKeys.now = func() time.Time { return now }

	lc.pairingKeys.tick()
	f.settle(t, lc.pairingKeys, 1)
	now = now.Add(pairingKeyRepushInterval - time.Second)
	lc.pairingKeys.tick()
	f.noMorePushes(t)
	now = now.Add(time.Second)
	lc.pairingKeys.tick()
	f.settle(t, lc.pairingKeys, 1)
	assert.Len(t, f.pushes(), 2)
}

func TestPairingKeyHelperCallDoesNotWaitOnASlowPush(t *testing.T) {
	f := newFakePairingKeyIPC()
	f.block = make(chan struct{})
	lc := pairingKeyCore(t, f)

	returned := make(chan string, 1)
	go func() { returned <- lc.HelperCall("view", "{}") }()
	select {
	case out := <-returned:
		assert.JSONEq(t, `{"error":"locked"}`, out)
	case <-time.After(2 * time.Second):
		t.Fatal("HelperCall waited on the push")
	}

	// A change while that push hangs goes out once it finishes.
	f.setKeys(map[string]helper.PairingKey{"p1": {Key: pairingKeyA, Role: "volunteer"}})
	lc.HelperCall("view", "{}")
	close(f.block)
	f.settle(t, lc.pairingKeys, 2)
	assert.Equal(t, []map[string]rhelper.PairingKey{
		{},
		{"p1": {Key: pairingKeyA, Role: "volunteer"}},
	}, f.pushes())
}

func TestPairingKeyNilPusherIsHarmless(t *testing.T) {
	var p *pairingKeyPusher
	p.changed()
	p.tick()
}

func TestPairingKeyNothingIsPushedBeforeTheFirstUnlock(t *testing.T) {
	f := newFakePairingKeyIPC()
	relay := func(context.Context, string, []byte) (int, []byte, string, error) {
		return 200, []byte(`{"pairings":[]}`), "", nil
	}
	ctx, cancel := context.WithCancel(context.Background())
	t.Cleanup(cancel)
	engine := helper.NewEngine(t.TempDir(), relay, nil)
	lc := &LanternCore{
		ctx:         ctx,
		helpers:     engine,
		pairingKeys: newPairingKeyPusher(ctx, engine.UnlockedPairingKeys, f.SetHelperPairingKeys),
	}
	now := time.Now()
	lc.pairingKeys.now = func() time.Time { return now }

	// A locked engine's empty set is not "no pairings": the live loop, the
	// periodic repush and every op leave radiance's keys alone.
	assert.JSONEq(t, `{"error":"locked"}`, lc.HelperCall("view", "{}"))
	lc.pairingKeys.tick()
	now = now.Add(2 * pairingKeyRepushInterval)
	lc.pairingKeys.tick()
	lc.HelperCall("unlock", `{"key":"not base64"}`)
	f.noMorePushes(t)
	assert.Empty(t, f.pushes())

	key := base64.StdEncoding.EncodeToString([]byte(strings.Repeat("k", 32)))
	lc.HelperCall("unlock", `{"key":"`+key+`"}`)
	f.settle(t, lc.pairingKeys, 1)
	assert.Equal(t, []map[string]rhelper.PairingKey{{}}, f.pushes(), "once unlocked, an empty set is a real \"no pairings\"")
}

func TestPairingKeyLockedKeysWaitForTheUnlock(t *testing.T) {
	f := newFakePairingKeyIPC()
	f.setKeys(map[string]helper.PairingKey{"p1": {Key: pairingKeyA, Role: "inviter"}})
	f.setLocked(true)
	lc := pairingKeyCore(t, f)

	lc.HelperCall("view", "{}")
	lc.pairingKeys.tick()
	f.noMorePushes(t)

	f.setLocked(false)
	lc.HelperCall("view", "{}")
	f.settle(t, lc.pairingKeys, 1)
	assert.Equal(t, []map[string]rhelper.PairingKey{{"p1": {Key: pairingKeyA, Role: "inviter"}}}, f.pushes())
}

// TestPairingKeyBackendChangeRepushesTheSameKeys: on Apple builds a push can
// land in the in-process fallback backend, and the network extension that
// takes over next has none. A backend change pushes again though nothing
// changed.
func TestPairingKeyBackendChangeRepushesTheSameKeys(t *testing.T) {
	f := newFakePairingKeyIPC()
	want := map[string]helper.PairingKey{"p1": {Key: pairingKeyA, Role: "inviter"}}
	f.setKeys(want)
	lc := pairingKeyCore(t, f)

	lc.HelperCall("view", "{}")
	f.settle(t, lc.pairingKeys, 1)
	lc.pairingKeys.tick()
	f.noMorePushes(t)

	events := make(chan vpn.StatusUpdateEvent)
	go repushPairingKeysOn(lc.ctx, func(ctx context.Context, h func(vpn.StatusUpdateEvent)) error {
		for {
			select {
			case e := <-events:
				h(e)
			case <-ctx.Done():
				return ctx.Err()
			}
		}
	}, lc.pairingKeys)
	events <- vpn.StatusUpdateEvent{}
	f.settle(t, lc.pairingKeys, 1)
	assert.Len(t, f.pushes(), 2)
	assert.Equal(t, toRadiancePairingKeys(want), f.pushes()[1])
}

// TestPairingKeyBackendChangeDuringAPushPushesAgain: a push still on its way
// to the old backend when the backend changes is followed by one more.
func TestPairingKeyBackendChangeDuringAPushPushesAgain(t *testing.T) {
	f := newFakePairingKeyIPC()
	f.setKeys(map[string]helper.PairingKey{"p1": {Key: pairingKeyA, Role: "volunteer"}})
	f.block = make(chan struct{})
	lc := pairingKeyCore(t, f)

	lc.HelperCall("view", "{}")
	lc.pairingKeys.backendChanged()
	close(f.block)
	f.settle(t, lc.pairingKeys, 2)
	assert.Len(t, f.pushes(), 2)
}

// TestPairingKeyBackendChangeWhileLockedPushesNothing: the backend signals
// arrive from startup on, before any unlock.
func TestPairingKeyBackendChangeWhileLockedPushesNothing(t *testing.T) {
	f := newFakePairingKeyIPC()
	f.setLocked(true)
	lc := pairingKeyCore(t, f)
	lc.pairingKeys.backendChanged()
	f.noMorePushes(t)
	var p *pairingKeyPusher
	p.backendChanged()
}

// TestPairingKeyUnchangedKeysArePushedAgainEvery30Seconds: a backend can lose
// the keys with no event at all (an Apple network extension killed, after
// which the client answers from a fresh fallback backend), so the live loop
// pushes the same keys again every 30 seconds.
func TestPairingKeyUnchangedKeysArePushedAgainEvery30Seconds(t *testing.T) {
	require.Equal(t, 30*time.Second, pairingKeyRepushInterval)
	f := newFakePairingKeyIPC()
	want := map[string]helper.PairingKey{"p1": {Key: pairingKeyA, Role: "inviter"}}
	f.setKeys(want)
	lc := pairingKeyCore(t, f)
	now := time.Now()
	lc.pairingKeys.now = func() time.Time { return now }

	lc.HelperCall("view", "{}")
	f.settle(t, lc.pairingKeys, 1)
	for range 29 {
		now = now.Add(time.Second)
		lc.pairingKeys.tick()
	}
	f.noMorePushes(t)
	now = now.Add(time.Second)
	lc.pairingKeys.tick()
	f.settle(t, lc.pairingKeys, 1)
	require.Len(t, f.pushes(), 2)
	assert.Equal(t, f.pushes()[0], f.pushes()[1], "the same set again")
}
