// Package localdiscovery provides a service for discovering Lantern instances
// in the local network
package localdiscovery

import (
	"sync"

	"github.com/getlantern/flashlight/ui"
	"github.com/getlantern/golog"
	"github.com/getlantern/multicast"
)

const (
	messageType = `localDiscovery`
)

var (
	log        = golog.LoggerFor("flashlight.localdiscovery")
	service    *ui.Service
	mc         *multicast.Multicast
	lastPeers  []multicast.PeerInfo
	peersMutex sync.Mutex
)

// Start begins the local Lantern discovery process
func Start(advertise bool, portToAdvertise string) {
	if service != nil {
		// Dev error: this service shouldn't be started unless stopped
		panic("The " + messageType + " service is already registered")
		return
	}

	var err error
	service, err = ui.Register(messageType, nil, func(write func(interface{}) error) error {
		// When connecting the UI we push the current peer list. For this reason, we need
		// to hold this list beyond the add/remove events.
		return write(buildPeersList())
	})
	if err != nil {
		log.Errorf("Unable to register Local Discovery service: %q", err)
		return
	}

	addOrRemoveCb := func(peer string, peersInfo []multicast.PeerInfo) {
		peersMutex.Lock()
		lastPeers = peersInfo
		peersMutex.Unlock()

		service.Out <- buildPeersList()
	}
	mc = multicast.JoinMulticast(addOrRemoveCb, addOrRemoveCb)

	if advertise {
		mc.SetPayload(portToAdvertise)
		mc.StartMulticast()
	}

	mc.ListenPeers()
}

// Stop quits the local Lantern discovery process
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
