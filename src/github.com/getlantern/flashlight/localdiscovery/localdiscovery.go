// Service for discovering Lantern instances in the local network
package localdiscovery

import (
	"sync"
	"time"

	"github.com/getlantern/flashlight/ui"
	"github.com/getlantern/golog"
	"github.com/getlantern/multicast"
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

func Start(advertise bool, portToAdvertise string) {
	if service != nil {
		// Dev error: this service shouldn't be started unless stopped
		panic("The " + messageType + " service is already registered")
		return
	}

	var err error
	service, err = ui.Register(messageType, nil, func(write func(interface{}) error) error {
		return write(buildPeersList())
	})
	if err != nil {
		log.Errorf("Unable to register Local Discovery service: %q", err)
		return
	}

	mc = multicast.JoinMulticast()

	mc.AddPeerCallback = func(peer string, peersInfo []multicast.PeerInfo) {
		peersMutex.Lock()
		lastPeers = peersInfo
		peersMutex.Unlock()

		service.Out <- buildPeersList()
	}
	mc.RemovePeerCallback = func(peer string, peersInfo []multicast.PeerInfo) {
		peersMutex.Lock()
		lastPeers = peersInfo
		peersMutex.Unlock()

		service.Out <- buildPeersList()
	}

	if advertise {
		mc.Payload = portToAdvertise
		mc.StartMulticast()
	}

	mc.ListenPeers()

	go func() {
		c := time.Tick(updatePeriod * time.Second)
		for range c {
			service.Out <- buildPeersList()
		}
	}()
}

func Stop() {
	ui.Unregister(messageType)
	service = nil
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
