package lanterncore

import (
	"bytes"
	"context"
	"log/slog"
	"maps"
	"sync"
	"time"

	rhelper "github.com/getlantern/radiance/helper"

	"github.com/getlantern/lantern/lantern-core/helper"
)

// EventTypeHelperLive tells the app that the connected status of the friends
// this device helps changed, so it reads the helper view again. It carries no
// pairing IDs: the view does.
const EventTypeHelperLive EventType = "helper-live"

// listenHelperLive polls radiance's per-friend live status beside the relay
// snapshots and merges it into the helper engine's view. It polls whatever
// the VPN's state: a volunteer abroad typically shares with the VPN off, and
// sharing runs in radiance apart from the tunnel. The read starts nothing:
// on desktop and Android an IPC server that is not up just fails the read,
// and on Apple builds the client answers from its in-process backend, as it
// already does for the relay snapshot pollers polling at the same rate.
func (lc *LanternCore) listenHelperLive() {
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()
	pollHelperLive(lc.ctx, ticker.C, lc.pairingKeys.tick, lc.readHelperLive, lc.helpers.SetLive, lc.notifyFlutter)
}

// readHelperLive returns which pairings radiance reports connected. A
// pairing it leaves out is not connected.
func (lc *LanternCore) readHelperLive(ctx context.Context) (map[string]bool, error) {
	s, err := lc.client.HelperLive(ctx)
	if err != nil {
		return nil, err
	}
	connected := make(map[string]bool, len(s.Pairings))
	for _, p := range s.Pairings {
		connected[p.PairingID] = p.Connected
	}
	return connected, nil
}

// pollHelperLive reads live status on every tick and hands it to set, which
// reports whether the view changed; a failed read makes the status unknown.
// The app hears only of changes, and never a pairing ID. Nothing is logged.
// every runs first on each pass, whatever the read does.
func pollHelperLive(ctx context.Context, ticks <-chan time.Time, every func(), read func(context.Context) (map[string]bool, error), set func(known bool, connected map[string]bool) bool, notify func(string, string)) {
	for {
		every()
		requestCtx, cancel := context.WithTimeout(ctx, 3*time.Second)
		connected, err := read(requestCtx)
		cancel()
		if ctx.Err() != nil {
			return
		}
		if set(err == nil, connected) {
			notify(EventTypeHelperLive, "{}")
		}
		select {
		case <-ctx.Done():
			return
		case <-ticks:
		}
	}
}

const (
	// pairingKeyPushTimeout bounds one push of the pairing keys to radiance.
	pairingKeyPushTimeout = 5 * time.Second
	// pairingKeyRepushInterval is how often the keys are pushed again even
	// though nothing changed, so a backend that lost them gets them back
	// without any event saying so: a lanternd that restarted, or on Apple
	// builds a network extension that was killed, after which the IPC
	// client quietly answers from a fresh in-process fallback backend. The
	// push is a local IPC call and radiance ignores an identical set, so
	// it is cheap to do often.
	pairingKeyRepushInterval = 30 * time.Second
)

// pairingKeyPusher keeps radiance's copy of the helper pairing keys in step
// with the engine's. A push happens on its own goroutine, one at a time, and
// always sends what the engine holds when it starts, so a later set never
// loses to an earlier one. An empty set is pushed too, radiance then drops
// its copy, but only from an unlocked engine: a locked one's empty set
// means only that its state is unread, and pushing it would make radiance
// forget the friends, and maybe the selected server, of a VPN that lanternd
// kept up across an app restart. Nothing is pushed until the first unlock.
// Keys and pairing IDs are never logged.
//
// Methods on a nil pairingKeyPusher do nothing.
type pairingKeyPusher struct {
	ctx context.Context
	// keys returns the engine's keys and whether it is unlocked.
	keys func() (map[string]helper.PairingKey, bool)
	push func(context.Context, map[string]rhelper.PairingKey) error
	now  func() time.Time

	mu sync.Mutex
	// pushed is the set radiance last accepted, nil when it never accepted
	// one or the last push failed.
	pushed     map[string]helper.PairingKey
	lastPushed time.Time
	failing    bool
	running    bool
	// again asks the running push to go once more when it is done, because
	// keys may have changed meanwhile; againForce to go even if they match.
	again      bool
	againForce bool
}

func newPairingKeyPusher(ctx context.Context, keys func() (map[string]helper.PairingKey, bool), push func(context.Context, map[string]rhelper.PairingKey) error) *pairingKeyPusher {
	return &pairingKeyPusher{ctx: ctx, keys: keys, push: push, now: time.Now}
}

// changed pushes the keys if they differ from those radiance last accepted.
// It never waits on the push.
func (p *pairingKeyPusher) changed() {
	p.kick(false)
}

// tick pushes the keys again if the last push failed or the last accepted
// one is older than pairingKeyRepushInterval, else as changed does. It
// never waits on the push.
func (p *pairingKeyPusher) tick() {
	if p == nil {
		return
	}
	p.mu.Lock()
	force := p.failing || p.pushed == nil || p.now().Sub(p.lastPushed) >= pairingKeyRepushInterval
	p.mu.Unlock()
	p.kick(force)
}

// backendChanged forgets what radiance accepted and pushes the keys again.
// On Apple builds the IPC client answers from an in-process fallback backend
// while the network extension is down and switches to the extension once it
// is up, so keys the fallback accepted never reached the extension, and the
// reverse; on desktop a lanternd restart loses them too. The client does not
// say which backend answered, so this runs on the signals that the backend
// may have changed. It never waits on the push.
func (p *pairingKeyPusher) backendChanged() {
	if p == nil {
		return
	}
	p.mu.Lock()
	p.pushed = nil
	p.mu.Unlock()
	p.kick(true)
}

// repushPairingKeysOn runs p.backendChanged on every event subscribe
// delivers. Blocks until ctx is cancelled.
func repushPairingKeysOn[T any](ctx context.Context, subscribe func(context.Context, func(T)) error, p *pairingKeyPusher) {
	err := subscribe(ctx, func(T) { p.backendChanged() })
	if err != nil && ctx.Err() == nil {
		slog.Warn("Event stream for re-pushing helper pairing keys exited", "error", err)
	}
}

// listenVPNStatusForPairingKeys pushes the pairing keys again on every VPN
// status change: on Apple builds the network extension coming up or going
// down moves the IPC client between it and the in-process fallback backend.
func (lc *LanternCore) listenVPNStatusForPairingKeys() {
	repushPairingKeysOn(lc.ctx, lc.client.VPNStatusEvents, lc.pairingKeys)
}

func (p *pairingKeyPusher) kick(force bool) {
	if p == nil || p.ctx.Err() != nil {
		return
	}
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.running {
		p.again = true
		p.againForce = p.againForce || force
		return
	}
	keys, unlocked := p.keys()
	if !unlocked || (!force && p.pushed != nil && samePairingKeys(keys, p.pushed)) {
		return
	}
	p.running = true
	go p.run(keys)
}

func (p *pairingKeyPusher) run(keys map[string]helper.PairingKey) {
	for {
		ctx, cancel := context.WithTimeout(p.ctx, pairingKeyPushTimeout)
		err := p.push(ctx, toRadiancePairingKeys(keys))
		cancel()

		p.mu.Lock()
		if err != nil {
			if !p.failing && p.ctx.Err() == nil {
				// Only the error: never a key or a pairing ID.
				slog.Warn("Pushing helper pairing keys to radiance failed, will retry", "error", err)
			}
			p.failing = true
			p.pushed = nil
		} else {
			p.failing = false
			p.pushed = keys
			p.lastPushed = p.now()
		}
		if !p.again || p.ctx.Err() != nil {
			p.running = false
			p.mu.Unlock()
			return
		}
		force := p.againForce
		p.again, p.againForce = false, false
		var unlocked bool
		keys, unlocked = p.keys()
		if !unlocked || (!force && p.pushed != nil && samePairingKeys(keys, p.pushed)) {
			p.running = false
			p.mu.Unlock()
			return
		}
		p.mu.Unlock()
	}
}

func samePairingKeys(a, b map[string]helper.PairingKey) bool {
	return maps.EqualFunc(a, b, func(x, y helper.PairingKey) bool {
		return x.Role == y.Role && bytes.Equal(x.Key, y.Key)
	})
}

func toRadiancePairingKeys(keys map[string]helper.PairingKey) map[string]rhelper.PairingKey {
	out := make(map[string]rhelper.PairingKey, len(keys))
	for id, k := range keys {
		out[id] = rhelper.PairingKey{Key: k.Key, Role: k.Role}
	}
	return out
}
