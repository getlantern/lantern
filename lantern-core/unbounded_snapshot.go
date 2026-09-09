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
	unavailable := false
	for {
		requestCtx, cancel := context.WithTimeout(ctx, 3*time.Second)
		snapshot, err := read(requestCtx)
		cancel()
		if err == nil {
			unavailable = false
			if data, err := json.Marshal(snapshot); err == nil {
				notify("unbounded-snapshot", string(data))
			}
		}
		if err != nil && !unavailable && ctx.Err() == nil {
			unavailable = true
			notify("unbounded-unavailable", "{}")
		}
		select {
		case <-ctx.Done():
			return
		case <-ticks:
		}
	}
}
