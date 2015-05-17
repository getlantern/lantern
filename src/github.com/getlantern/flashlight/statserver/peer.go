package statserver

import (
	"math"
	"net/http"
	"sync/atomic"
	"time"

	"github.com/getlantern/geolookup"
)

var (
	publishInterval   = 10 * time.Second
	retryWaitTime     = 500 * time.Millisecond
	maxGeolocateTries = 10
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

func newPeer(ip string, pub publish) *Peer {
	peer := &Peer{
		IP:              ip,
		pub:             pub,
		lastReported:    time.Now(),
		atLastReporting: &Peer{},
	}
	*peer.atLastReporting = *peer
	go peer.run()
	return peer
}

func (peer *Peer) run() {
	err := peer.geolocate()

	if err != nil {
		log.Errorf("Unable to geolocate peer after %d attempts, stopping reporting. Last error was: %s", maxGeolocateTries, err)
		return
	}

	for {
		newActivity := peer.LastConnected != peer.atLastReporting.LastConnected
		if newActivity {
			// We have new activity, meaning that we will eventually need to
			// report a final update
			peer.reportedFinal = false
		}

		// Only report if there's been activity or we need to make our final report
		shouldReport := newActivity || !peer.reportedFinal
		if shouldReport {
			log.Tracef("%v reporting", peer.IP)

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
				log.Tracef("%v just reported its final update", peer.IP)
				peer.reportedFinal = true
			}
		}

		time.Sleep(publishInterval)
	}
}

func (peer *Peer) geolocate() error {
	var err error

	for i := 0; i < maxGeolocateTries; i++ {

		if i > 0 {
			// Maximum sleep time: 2^(maxGeolocateTries - 1) * retryWaitTime
			retryWait := time.Duration(math.Pow(2, float64(i)) * float64(retryWaitTime))
			log.Errorf("Failed geolocation attempt %d/%d,  waiting %v before retrying: %s", i, maxGeolocateTries-1, retryWait, err)
			time.Sleep(retryWait)
		}

		err = peer.doGeolocate()

		if err == nil {
			return nil
		}

	}

	return err
}

func (peer *Peer) doGeolocate() error {
	var geodata *geolookup.City
	var err error
	wc := withClient.Load().(func(func(*http.Client)))
	wc(func(c *http.Client) {
		geodata, err = geolookup.LookupIPWithClient(peer.IP, c)
	})

	if err != nil {
		return err
	}

	peer.Country = geodata.Country.IsoCode
	peer.Latitude = geodata.Location.Latitude
	peer.Longitude = geodata.Location.Longitude

	return nil
}

func (peer *Peer) onBytesReceived(bytes int64) {
	peer.LastConnected = time.Now()
	atomic.AddInt64(&peer.BytesUp, bytes)
}

func (peer *Peer) onBytesSent(bytes int64) {
	peer.LastConnected = time.Now()
	atomic.AddInt64(&peer.BytesDn, bytes)
}
