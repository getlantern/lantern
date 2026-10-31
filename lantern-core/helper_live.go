package lanterncore

import (
	"context"
	"time"
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
	pollHelperLive(lc.ctx, ticker.C, lc.readHelperLive, lc.helpers.SetLive, lc.notifyFlutter)
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
func pollHelperLive(ctx context.Context, ticks <-chan time.Time, read func(context.Context) (map[string]bool, error), set func(known bool, connected map[string]bool) bool, notify func(string, string)) {
	for {
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
