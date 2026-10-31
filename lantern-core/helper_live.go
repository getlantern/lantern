package lanterncore

import (
	"context"
	"errors"
	"time"

	"github.com/getlantern/radiance/vpn"
)

// EventTypeHelperLive tells the app that the connected status of the friends
// this device helps changed, so it reads the helper view again. It carries no
// pairing IDs: the view does.
const EventTypeHelperLive EventType = "helper-live"

var errVPNOff = errors.New("vpn is off")

// listenHelperLive polls radiance's per-friend live status beside the relay
// snapshots and merges it into the helper engine's view.
func (lc *LanternCore) listenHelperLive() {
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()
	pollHelperLive(lc.ctx, ticker.C, lc.readHelperLive, lc.helpers.SetLive, lc.notifyFlutter)
}

// readHelperLive returns which pairings radiance reports connected, and an
// error while the VPN is off, when the app shows no live status.
func (lc *LanternCore) readHelperLive(ctx context.Context) (map[string]bool, error) {
	status, err := lc.client.VPNStatus(ctx)
	if err != nil {
		return nil, err
	}
	if status != vpn.Connected {
		return nil, errVPNOff
	}
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
