// service for discovering Lantern instances in the local network
package localdiscovery

import (
	"github.com/getlantern/flashlight/ui"
	"github.com/getlantern/golog"
	"github.com/getlantern/multicast"
	"sync"
	"time"
)

const (
	messageType = `LocalDiscovery`
)

var (
	log           = golog.LoggerFor("flashlight.localdiscovery")
	service       *ui.Service
	mc            *multicast.Multicast
	lastPeers     []string
	peersMutex    sync.Mutex
)

func Start() {
	if service == nil {
		helloFn := func(write func(interface{}) error) error {
			log.Debugf("Sending local Lanterns list to the Lantern UI")
			return write(lastPeers)
		}
		var err error
		service, err = ui.Register(messageType, nil, helloFn)

		if err != nil {
			log.Errorf("Unable to register Local Discovery service: %q", err)
			return
		}
	}

	mc = multicast.JoinMulticast()

	mc.AddPeerCallback = func(peer string, allPeers []string) {
		peersMutex.Lock()
		lastPeers = allPeers
		peersMutex.Unlock()

		service.Out <- allPeers
	}
	mc.RemovePeerCallback = func(peer string, allPeers []string) {
		peersMutex.Lock()
		lastPeers = allPeers
		peersMutex.Unlock()

		service.Out <- allPeers
	}

	mc.StartMulticast()

	go func() {
		c := time.Tick(10 * time.Second)
		for range c {
			peersMutex.Lock()
			service.Out <- lastPeers
			peersMutex.Unlock()
		}
	}()
}

func Stop() {
	mc.LeaveMulticast()
}
