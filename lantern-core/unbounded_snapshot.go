package lanterncore

import (
	"context"
	"encoding/json"
	"sync"
	"time"

	"github.com/getlantern/radiance/peer"
	"github.com/getlantern/radiance/unbounded"
)

const snapshotInterval = time.Second

// SetSnapshotPolling starts or stops the snapshot pollers. The app runs them
// only while it shows their stats: each tick wakes Go, the platform layer and
// Dart, which costs battery for nothing when no one is looking.
func (lc *LanternCore) SetSnapshotPolling(on bool) {
	lc.snapshotGate.set(on)
}

func (lc *LanternCore) listenUnboundedSnapshots() {
	lc.snapshotGate.run(lc.ctx, snapshotInterval, func(ctx context.Context, ticks <-chan time.Time) {
		pollUnboundedSnapshots(ctx, ticks, lc.client.UnboundedSnapshot, lc.notifyFlutter)
	})
}

// pollGate runs a poll loop only while it is open.
type pollGate struct {
	mu      sync.Mutex
	open    bool
	changed chan struct{} // closed on every change
}

func (g *pollGate) set(open bool) {
	g.mu.Lock()
	defer g.mu.Unlock()
	if g.open == open {
		return
	}
	g.open = open
	if g.changed != nil {
		close(g.changed)
	}
	g.changed = make(chan struct{})
}

func (g *pollGate) load() (bool, <-chan struct{}) {
	g.mu.Lock()
	defer g.mu.Unlock()
	if g.changed == nil {
		g.changed = make(chan struct{})
	}
	return g.open, g.changed
}

// run calls poll each time the gate opens, with a ticker and a context that
// is canceled when the gate closes. No ticker runs while it is closed.
func (g *pollGate) run(ctx context.Context, interval time.Duration, poll func(context.Context, <-chan time.Time)) {
	for {
		open, changed := g.load()
		if !open {
			select {
			case <-ctx.Done():
				return
			case <-changed:
				continue
			}
		}
		pollCtx, cancel := context.WithCancel(ctx)
		go func() {
			select {
			case <-changed:
			case <-pollCtx.Done():
			}
			cancel()
		}()
		ticker := time.NewTicker(interval)
		poll(pollCtx, ticker.C)
		ticker.Stop()
		cancel()
		if ctx.Err() != nil {
			return
		}
	}
}

func pollUnboundedSnapshots(ctx context.Context, ticks <-chan time.Time, read func(context.Context) (unbounded.Snapshot, error), notify func(string, string)) {
	pollSnapshots(ctx, ticks, withoutUnboundedPairings(read), notify, "unbounded-snapshot", "unbounded-unavailable")
}

// withoutUnboundedPairings clears each peerBytes entry's helper pairing: the
// app never shows which relayed traffic is a friend's, so pairing IDs do not
// reach it in snapshots.
func withoutUnboundedPairings(read func(context.Context) (unbounded.Snapshot, error)) func(context.Context) (unbounded.Snapshot, error) {
	return func(ctx context.Context) (unbounded.Snapshot, error) {
		s, err := read(ctx)
		for i := range s.PeerBytes {
			s.PeerBytes[i].Pairing = ""
		}
		return s, err
	}
}

// withoutPeerPairings is withoutUnboundedPairings for direct sharing.
func withoutPeerPairings(read func(context.Context) (peer.Snapshot, error)) func(context.Context) (peer.Snapshot, error) {
	return func(ctx context.Context) (peer.Snapshot, error) {
		s, err := read(ctx)
		for i := range s.PeerBytes {
			s.PeerBytes[i].Pairing = ""
		}
		return s, err
	}
}

// listenPeerSnapshots polls the bytes direct sharing has relayed, which the
// app folds the same way as Unbounded's. Unbounded's poller already reports
// when the backend is unreachable, so this one sends no unavailable event.
func (lc *LanternCore) listenPeerSnapshots() {
	lc.snapshotGate.run(lc.ctx, snapshotInterval, func(ctx context.Context, ticks <-chan time.Time) {
		pollPeerSnapshots(ctx, ticks, lc.client.PeerRelaySnapshot, lc.notifyFlutter)
	})
}

func pollPeerSnapshots(ctx context.Context, ticks <-chan time.Time, read func(context.Context) (peer.Snapshot, error), notify func(string, string)) {
	pollSnapshots(ctx, ticks, withoutPeerPairings(read), notify, "peer-snapshot", "")
}

// pollSnapshots reads a snapshot on every tick and sends it to Flutter as
// event. After a failed read it sends unavailable once, when set, until a read
// succeeds again.
func pollSnapshots[T any](ctx context.Context, ticks <-chan time.Time, read func(context.Context) (T, error), notify func(string, string), event, unavailable string) {
	reportedUnavailable := false
	for {
		requestCtx, cancel := context.WithTimeout(ctx, 3*time.Second)
		snapshot, err := read(requestCtx)
		cancel()
		if err == nil {
			reportedUnavailable = false
			if data, err := json.Marshal(snapshot); err == nil {
				notify(event, string(data))
			}
		}
		if err != nil && unavailable != "" && !reportedUnavailable && ctx.Err() == nil {
			reportedUnavailable = true
			notify(unavailable, "{}")
		}
		select {
		case <-ctx.Done():
			return
		case <-ticks:
		}
	}
}
