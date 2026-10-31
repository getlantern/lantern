package helper

import "maps"

// SetLive records which pairings radiance reports connected through this
// device right now, for the helping rows of every later view. With known
// false it records that nobody can say (radiance is not answering, or the
// VPN is off), and those rows carry no connected at all, as from a core that
// never had live status. A pairing missing from connected is not connected.
// It returns whether that changed anything a view shows. Pairing IDs are
// never logged.
//
// It takes its own lock, not the one ops hold, so a refresh waiting on
// lantern-cloud never delays it.
func (e *Engine) SetLive(known bool, connected map[string]bool) bool {
	now := map[string]bool{}
	if known {
		for id, c := range connected {
			if c {
				now[id] = true
			}
		}
	}
	e.liveMu.Lock()
	defer e.liveMu.Unlock()
	if e.liveKnown == known && maps.Equal(e.live, now) {
		return false
	}
	e.liveKnown = known
	e.live = now
	return true
}

// liveConnected is a helping row's connected value: nil while unknown.
func (e *Engine) liveConnected(pairingID string) *bool {
	e.liveMu.Lock()
	defer e.liveMu.Unlock()
	if !e.liveKnown {
		return nil
	}
	c := e.live[pairingID]
	return &c
}
