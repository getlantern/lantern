package lanterncore

import (
	"context"
	"encoding/json"
	"time"

	"github.com/getlantern/radiance/peer"
	"github.com/getlantern/radiance/unbounded"
)

func (lc *LanternCore) listenUnboundedSnapshots() {
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()
	pollUnboundedSnapshots(lc.ctx, ticker.C, lc.client.UnboundedSnapshot, lc.notifyFlutter)
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
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()
	pollPeerSnapshots(lc.ctx, ticker.C, lc.client.PeerRelaySnapshot, lc.notifyFlutter)
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
