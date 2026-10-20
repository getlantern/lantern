package lanterncore

import (
	"context"
	"encoding/json"
	"time"

	"github.com/getlantern/radiance/unbounded"
)

func (lc *LanternCore) listenUnboundedSnapshots() {
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()
	pollUnboundedSnapshots(lc.ctx, ticker.C, lc.client.UnboundedSnapshot, lc.notifyFlutter)
}

func pollUnboundedSnapshots(ctx context.Context, ticks <-chan time.Time, read func(context.Context) (unbounded.Snapshot, error), notify func(string, string)) {
	pollSnapshots(ctx, ticks, read, notify, "unbounded-snapshot", "unbounded-unavailable")
}

// listenPeerSnapshots polls the bytes direct sharing has relayed, which the
// app folds the same way as Unbounded's. Unbounded's poller already reports
// when the backend is unreachable, so this one sends no unavailable event.
func (lc *LanternCore) listenPeerSnapshots() {
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()
	pollSnapshots(lc.ctx, ticker.C, lc.client.PeerRelaySnapshot, lc.notifyFlutter, "peer-snapshot", "")
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
