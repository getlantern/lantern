package geolookup

import (
	"math"
	"time"

	"github.com/getlantern/eventual"
	geo "github.com/getlantern/geolookup"
	"github.com/getlantern/golog"

	"github.com/getlantern/flashlight/ops"
	"github.com/getlantern/flashlight/proxied"
)

var (
	log = golog.LoggerFor("flashlight.geolookup")

	refreshRequest = make(chan interface{}, 1)
	currentGeoInfo = eventual.NewValue()

	waitForProxyTimeout = 1 * time.Minute
	retryWaitMillis     = 100
	maxRetryWait        = 30 * time.Second
)

type geoInfo struct {
	ip   string
	city *geo.City
}

// GetIP gets the IP. If the IP hasn't been determined yet, waits up to the
// given timeout for an IP to become available.
func GetIP(timeout time.Duration) string {
	gi, ok := currentGeoInfo.Get(timeout)
	if !ok || gi == nil {
		return ""
	}
	return gi.(*geoInfo).ip
}

// GetCountry gets the country. If the country hasn't been determined yet, waits
// up to the given timeout for a country to become available.
func GetCountry(timeout time.Duration) string {
	gi, ok := currentGeoInfo.Get(timeout)
	if !ok || gi == nil {
		return ""
	}
	return gi.(*geoInfo).city.Country.IsoCode
}

// Refresh refreshes the geolookup information by calling the remote geolookup
// service. It will keep calling the service until it's able to determine an IP
// and country.
func Refresh() {
	select {
	case refreshRequest <- true:
		log.Debug("Requested refresh")
	default:
		log.Debug("Refresh already in progress")
	}
}

func init() {
	go run()
}

func run() {
	for _ = range refreshRequest {
		gi := lookup()
		log.Debug("Got new geolocation info")
		currentGeoInfo.Set(gi)
	}
}

func lookup() *geoInfo {
	consecutiveFailures := 0

	for {
		gi, err := doLookup()
		if err != nil {
			log.Debugf("Unable to get current location: %s", err)
			wait := time.Duration(math.Pow(2, float64(consecutiveFailures))*float64(retryWaitMillis)) * time.Millisecond
			if wait > maxRetryWait {
				wait = maxRetryWait
			}
			log.Debugf("Waiting %v before retrying", wait)
			time.Sleep(wait)
			consecutiveFailures++
		} else {
			log.Debugf("IP is %v", gi.ip)
			return gi
		}
	}
}

func doLookup() (*geoInfo, error) {
	op := ops.Begin("geolookup")
	defer op.End()
	city, ip, err := geo.LookupIP("", proxied.ParallelPreferChained())

	if err != nil {
		log.Errorf("Could not lookup IP %v", err)
		return nil, op.FailIf(err)
	}
	return &geoInfo{ip, city}, nil
}
