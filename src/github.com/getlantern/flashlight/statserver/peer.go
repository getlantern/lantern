package statserver

import (
	"fmt"
	"sync/atomic"
	"time"

	"github.com/getlantern/geolookup"
)

var (
	publishInterval = 10 * time.Second
)

// Peer represents information about a peer
type Peer struct {
	IP              string    `json:"peerid"`
	LastConnected   time.Time `json:"lastConnected"`
	BytesDn         int64     `json:"bytesDn"`
	BytesUp         int64     `json:"bytesUp"`
	BytesUpDn       int64     `json:"bytesUpDn"`
	BPSDn           int64     `json:"bpsDn"`
	BPSUp           int64     `json:"bpsUp"`
	BPSUpDn         int64     `json:"bpsUpDn"`
	Country         string    `json:"country"`
	Latitude        float64   `json:"lat"`
	Longitude       float64   `json:"lon"`
	pub             publish
	atLastReporting *Peer
	lastReported    time.Time
	reportedFinal   bool
}

// publish is a function to which a peer can publish itself
type publish func(peer *Peer)

func newPeer(ip string, pub publish) (*Peer, error) {
	peer := &Peer{
		IP:              ip,
		pub:             pub,
		lastReported:    time.Now(),
		atLastReporting: &Peer{},
	}
	*peer.atLastReporting = *peer
	err := peer.run()
	if err != nil {
		return nil, err
	}
	return peer, nil
}

func (peer *Peer) run() error {
	err := peer.geolocate()
	if err != nil {
		return err
	}
	go peer.publishPeriodically()
	return nil
}

func (peer *Peer) geolocate() error {

	if geolookup.UsesDefaultHTTPClient() {
		return fmt.Errorf("Geolocation service could not be consulted over a proxy yet.")
	}

	geodata, err := geolookup.LookupCity(peer.IP)
	if err != nil {
		return err
	}

	peer.Country = geodata.Country.IsoCode
	peer.Latitude = geodata.Location.Latitude
	peer.Longitude = geodata.Location.Longitude

	return nil
}

func (peer *Peer) publishPeriodically() {
	for {
		time.Sleep(publishInterval)
		newActivity := peer.LastConnected != peer.atLastReporting.LastConnected
		if newActivity {
			// We have new activity, meaning that we will eventually need to
			// report a final update
			peer.reportedFinal = false
		}
		// Only report if there's been activity or we need to make our final report
		shouldReport := newActivity || !peer.reportedFinal
		if shouldReport {
			// Calculate stats
			now := time.Now()
			peer.lastReported = now
			delta := peer.lastReported.Sub(peer.atLastReporting.lastReported).Seconds()
			peer.BytesUpDn = peer.BytesUp + peer.BytesDn
			peer.BPSDn = int64(float64(peer.BytesDn-peer.atLastReporting.BytesDn) / delta)
			peer.BPSUp = int64(float64(peer.BytesUp-peer.atLastReporting.BytesUp) / delta)
			peer.BPSUpDn = peer.BPSDn + peer.BPSUp

			// Remember copy of peer as last reported
			*peer.atLastReporting = *peer

			// Publish copy of peer
			peer.pub(peer.atLastReporting)

			if shouldReport && !newActivity {
				// We just reported our final update
				peer.reportedFinal = true
			}
		}
	}
}

func (peer *Peer) onBytesReceived(bytes int64) {
	peer.LastConnected = time.Now()
	atomic.AddInt64(&peer.BytesUp, bytes)
}

func (peer *Peer) onBytesSent(bytes int64) {
	peer.LastConnected = time.Now()
	atomic.AddInt64(&peer.BytesDn, bytes)
}
