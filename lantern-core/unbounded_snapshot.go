package lanterncore

import (
	"context"
	"encoding/json"
	"time"
)

func (lc *LanternCore) listenUnboundedSnapshots() {
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()
	for {
		ctx, cancel := context.WithTimeout(lc.ctx, 3*time.Second)
		snapshot, err := lc.client.UnboundedSnapshot(ctx)
		cancel()
		if err == nil {
			if data, err := json.Marshal(snapshot); err == nil {
				lc.notifyFlutter("unbounded-snapshot", string(data))
			}
		}
		if err != nil && lc.ctx.Err() == nil {
			lc.notifyFlutter("unbounded-unavailable", "{}")
		}
		select {
		case <-lc.ctx.Done():
			return
		case <-ticker.C:
		}
	}
}
