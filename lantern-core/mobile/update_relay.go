package mobile

import (
	"github.com/getlantern/lantern/lantern-core/updaterelay"
	"github.com/getlantern/lantern/lantern-core/utils"
)

// StartUpdateRelay returns a local feed URL without initializing the VPN core.
func StartUpdateRelay(cacheDir, feedURL string) (string, error) {
	return utils.RunOffCgoStack(func() (string, error) {
		return updaterelay.Start(cacheDir, feedURL)
	})
}

// StopUpdateRelay cancels downloads and releases the update transport.
func StopUpdateRelay() {
	_, _ = utils.RunOffCgoStack(func() (struct{}, error) {
		updaterelay.Stop()
		return struct{}{}, nil
	})
}
