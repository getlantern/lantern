package bandwidth

import (
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/getlantern/golog"
)

var (
	log = golog.LoggerFor("bandwidth")

	quota *Quota
	mutex sync.RWMutex

	epoch = time.Date(2016, 1, 1, 0, 0, 0, 0, time.UTC)

	// Updates is a channel on which one can receive updates to the Quota
	Updates = make(chan *Quota, 100)
)

// Quota encapsulates information about the user's bandwidth quota.
type Quota struct {
	MiBAllowed uint64    `json:"mibAllowed"`
	MiBUsed    uint64    `json:"mibUsed"`
	AsOf       time.Time `json:"asOf"`
}

// GetQuota gets the most up to date bandwidth quota information.
func GetQuota() *Quota {
	mutex.RLock()
	result := quota
	mutex.RUnlock()
	return result
}

// Track updates the bandwith quota information based on the XBQ header in
// the given response. The header is expected to follow this format:
//
// <used>/<allowed>/<asof>
//
// <used> is the string representation of a 64-bit unsigned integer
// <allowed> is the string representation of a 64-bit unsigned integer
// <asof> is the 64-bit signed integer representing seconds since a custom
// epoch (00:00:00 01/01/2016 UTC).
func Track(resp *http.Response) {
	xbq := resp.Header.Get("XBQ")
	if xbq == "" {
		log.Debugf("Response missing XBQ header, can't read bandwidth quota")
		return
	}
	// Remove the XBQ header to avoid leaking it to clients
	resp.Header.Del("XBQ")
	parts := strings.Split(xbq, "/")
	if len(parts) != 3 {
		log.Debugf("Malformed XBQ header %v, can't read bandwidth quota", xbq)
		return
	}
	used, err := strconv.ParseUint(parts[0], 10, 64)
	if err != nil {
		log.Debugf("Malformed XBQ header %v, can't parse used MiB: %v", err)
		return
	}
	allowed, err := strconv.ParseUint(parts[1], 10, 64)
	if err != nil {
		log.Debugf("Malformed XBQ header %v, can't parse allowed MiB: %v", err)
		return
	}
	asofInt, err := strconv.ParseInt(parts[2], 10, 64)
	if err != nil {
		log.Debugf("Malformed XBQ header %v, can't parse as of time: %v", err)
		return
	}
	asof := epoch.Add(time.Duration(asofInt) * time.Second)
	mutex.Lock()
	if quota == nil || quota.AsOf.Before(asof) {
		quota = &Quota{allowed, used, asof}
		select {
		case Updates <- quota:
			// update submitted
		default:
			// channel full, skip it
		}
	}
	mutex.Unlock()
}
