package geolookup

import (
	"math"
	"time"

	"github.com/getlantern/eventual"
	geo "github.com/getlantern/geolookup"
	"github.com/getlantern/golog"

	"github.com/getlantern/flashlight/util"
)

var (
	log = golog.LoggerFor("flashlight.geolookup")

	refreshRequest = make(chan eventual.Getter, 1)
	currentGeoInfo = eventual.NewValue()
	cf             util.HTTPFetcher

	retryWaitMillis = 100
	maxRetryWait    = 30 * time.Second
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
func Refresh(proxyAddrFN eventual.Getter) {
	select {
	case refreshRequest <- proxyAddrFN:
		log.Debug("Requested refresh")
	default:
		log.Debug("Refresh already in progress")
	}
}

func init() {
	go run()
}

func run() {
	for proxyAddr := range refreshRequest {
		gi := lookup(util.NewChainedAndFronted(proxyAddr))
		log.Debug("Got new geolocation info")
		currentGeoInfo.Set(gi)
	}
}

func lookup(cf util.HTTPFetcher) *geoInfo {
	consecutiveFailures := 0

	for {
		gi, err := doLookup(cf)
		if err != nil {
			log.Debugf("Unable to get current location: %s", err)
			wait := time.Duration(math.Pow(2, float64(consecutiveFailures))*float64(retryWaitMillis)) * time.Millisecond
			if wait > maxRetryWait {
				wait = maxRetryWait
			}
			log.Debugf("Waiting %v before retrying", wait)
			time.Sleep(wait)
			consecutiveFailures += 1
		} else {
			log.Debugf("IP is %v", gi.ip)
			return gi
		}
	}
}

func doLookup(cf util.HTTPFetcher) (*geoInfo, error) {
	city, ip, err := geo.LookupIPWithClient("", cf)

	if err != nil {
		log.Errorf("Could not lookup IP %v", err)
		return nil, err
	}
	return &geoInfo{ip, city}, nil
}
