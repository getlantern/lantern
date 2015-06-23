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
	messageType  = `LocalDiscovery`
	updatePeriod = 10
)

var (
	log           = golog.LoggerFor("flashlight.localdiscovery")
	service       *ui.Service
	mc            *multicast.Multicast
	lastPeers     []multicast.PeerInfo
	peersMutex    sync.Mutex
)

func Start(portToAdvertise string) {
	if service == nil {
		helloFn := func(write func(interface{}) error) error {
			log.Debugf("Sending local Lanterns list to the Lantern UI")
			return write(buildPeersList())
		}
		var err error
		service, err = ui.Register(messageType, nil, helloFn)

		if err != nil {
			log.Errorf("Unable to register Local Discovery service: %q", err)
			return
		}
	}

	mc = multicast.JoinMulticast()

	mc.Payload = portToAdvertise
	mc.AddPeerCallback = func(peer string, peersInfo []multicast.PeerInfo) {
		peersMutex.Lock()
		lastPeers = peersInfo
		peersMutex.Unlock()

		service.Out <- peersInfo
	}
	mc.RemovePeerCallback = func(peer string, peersInfo []multicast.PeerInfo) {
		peersMutex.Lock()
		lastPeers = peersInfo
		peersMutex.Unlock()

		service.Out <- peersInfo
	}

	mc.StartMulticast()

	go func() {
		c := time.Tick(updatePeriod * time.Second)
		for range c {
			service.Out <- buildPeersList()
		}
	}()
}

func Stop() {
	mc.LeaveMulticast()
}

func buildPeersList() []string {
	peersList := make([]string, len(lastPeers))

	peersMutex.Lock()
	for i, peer := range lastPeers {
		peersList[i] = "http://" + peer.IP.String() + ":" + peer.Payload
	}
	peersMutex.Unlock()

	return peersList
}
