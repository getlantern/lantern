package proxiedsites

import (
	"sync"

	"github.com/getlantern/detour"
	"github.com/getlantern/golog"
	"github.com/getlantern/proxiedsites"
)

var (
	log = golog.LoggerFor("flashlight.proxiedsites")

	PACURL     string
	startMutex sync.Mutex
)

func Configure(cfg *proxiedsites.Config) {
	log.Debug("Configuring")

	delta := proxiedsites.Configure(cfg)
	startMutex.Lock()

	if delta != nil {
		updateDetour(delta)
	}
	startMutex.Unlock()
}

func updateDetour(delta *proxiedsites.Delta) {
	log.Debugf("Updating detour with %d additions and %d deletions", len(delta.Additions), len(delta.Deletions))

	// TODO: subscribe changes of geolookup and set country accordingly
	// safe to hardcode here as IR has all detection rules
	detour.SetCountry("IR")

	// for simplicity, detour matches whitelist using host:port string
	// so we add ports to each proxiedsites
	for _, v := range delta.Deletions {
		detour.RemoveFromWl(v + ":80")
		detour.RemoveFromWl(v + ":443")
	}
	for _, v := range delta.Additions {
		detour.AddToWl(v+":80", true)
		detour.AddToWl(v+":443", true)
	}
}
