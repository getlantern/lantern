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
	mu    sync.Mutex
	keys  map[string]helper.PairingKey
	fail  bool
	block chan struct{}
	calls []map[string]rhelper.PairingKey
	done  chan struct{}
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

func (f *fakePairingKeyIPC) PairingKeys() map[string]helper.PairingKey {
	f.mu.Lock()
	defer f.mu.Unlock()
	return maps.Clone(f.keys)
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
