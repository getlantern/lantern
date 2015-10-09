package geolookup

import (
	"fmt"
	"math"
	"math/rand"
	"sync"
	"sync/atomic"
	"time"

	geo "github.com/getlantern/geolookup"
	"github.com/getlantern/golog"

	"github.com/getlantern/flashlight/pubsub"
	"github.com/getlantern/flashlight/ui"
	"github.com/getlantern/flashlight/util"
)

const (
	messageType = `GeoLookup`

	basePublishSeconds     = 30
	publishSecondsVariance = basePublishSeconds - 10
	retryWaitMillis        = 100
)

var (
	log = golog.LoggerFor("flashlight.geolookup")

	service  *ui.Service
	cfgMutex sync.Mutex
	country  = atomicString()
	ip       = atomicString()
	cf       = util.NewChainedAndFronted()
)

func atomicString() atomic.Value {
	var val atomic.Value
	val.Store("")
	return val
}

func GetIp() string {
	return ip.Load().(string)
}

func GetCountry() string {
	return country.Load().(string)
}

// Configure configures geolookup to use the given http.Client to perform
// lookups. geolookup runs in a continuous loop, periodically updating its
// location and publishing updates to any connected clients. We do this
// continually in order to detect when the computer's location has changed.
func Start() {
	// Avoid annoying checks for nil later.
	ip.Store("")
	country.Store("")

	if service == nil {
		err := registerService()
		if err != nil {
			log.Errorf("Unable to register service: %s", err)
			return
		}
		go write()
		go read()
		log.Debug("Running")
	}
}

func registerService() error {
	helloFn := func(write func(interface{}) error) error {
		country := GetCountry()
		if country == "" {
			log.Trace("No lastKnownCountry, not sending anything to client")
			return nil
		}
		log.Trace("Sending last known location to new client")
		return write(country)
	}

	var err error
	service, err = ui.Register(messageType, nil, helloFn)
	return err
}

func lookupIp() (string, string, error) {
	city, ip, err := geo.LookupIPWithClient("", cf)

	if err != nil {
		log.Errorf("Could not lookup IP %v", err)
		return "", "", err
	}
	return city.Country.IsoCode, ip, nil
}

func write() {
	consecutiveFailures := 0

	for {
		// Wait a random amount of time (to avoid looking too suspicious)
		// Note - rand was seeded with the startup time in flashlight.go
		n := rand.Intn(publishSecondsVariance)
		wait := time.Duration(basePublishSeconds-publishSecondsVariance/2+n) * time.Second

		log.Debugf("Waiting to get IP for %v seconds", wait)
		oldIp := GetIp()
		oldCountry := GetCountry()

		newCountry, newIp, err := lookupIp()
		if err == nil {
			consecutiveFailures = 0
			if newIp != oldIp {
				log.Debugf("IP changed from %v to %v", oldIp, newIp)
				ip.Store(newIp)
				pubsub.Pub(pubsub.IP, newIp)
			}
			// Always publish location, even if unchanged
			service.Out <- newCountry
		} else {
			msg := fmt.Sprintf("Unable to get current location: %s", err)
			// When retrying after a failure, wait a different amount of time
			retryWait := time.Duration(math.Pow(2, float64(consecutiveFailures))*float64(retryWaitMillis)) * time.Millisecond
			if retryWait < wait {
				log.Debug(msg)
				wait = retryWait
			} else {
				log.Error(msg)
			}
			log.Debugf("Waiting %v before retrying", wait)
			consecutiveFailures += 1
			// If available, publish last known location
			if oldCountry != "" {
				service.Out <- oldCountry
			}
		}

		time.Sleep(wait)
	}
}

func read() {
	for _ = range service.In {
		// Discard message, just in case any message is sent to this service.
	}
}
