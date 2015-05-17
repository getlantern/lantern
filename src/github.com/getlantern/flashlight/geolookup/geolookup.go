package geolookup

import (
	"fmt"
	"math"
	"math/rand"
	"net/http"
	"reflect"
	"sync"
	"sync/atomic"
	"time"

	"github.com/getlantern/geolookup"
	"github.com/getlantern/golog"

	"github.com/getlantern/flashlight/pubsub"
	"github.com/getlantern/flashlight/ui"
)

const (
	messageType = `GeoLookup`

	basePublishSeconds     = 30
	publishSecondsVariance = basePublishSeconds - 10
	retryWaitMillis        = 100
)

var (
	log = golog.LoggerFor("flashlight.geolookup")

	service    *ui.Service
	withClient atomic.Value
	cfgMutex   sync.Mutex
	location   atomic.Value
)

func GetLocation() *geolookup.City {
	l := location.Load()
	if l == nil {
		return nil
	}
	return l.(*geolookup.City)
}

func GetCountry() string {
	loc := GetLocation()
	if loc == nil {
		return ""
	}
	return loc.Country.IsoCode
}

// Configure configures geolookup to use the given http.Client to perform
// lookups. geolookup runs in a continuous loop, periodically updating its
// location and publishing updates to any connected clients. We do this
// continually in order to detect when the computer's location has changed.
func Configure(wc func(func(*http.Client))) {
	cfgMutex.Lock()
	defer cfgMutex.Unlock()

	withClient.Store(wc)

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
		location := GetLocation()
		if location == nil {
			log.Trace("No lastKnownLocation, not sending anything to client")
			return nil
		}
		log.Trace("Sending last known location to new client")
		return write(location)
	}

	var err error
	service, err = ui.Register(messageType, nil, helloFn)
	return err
}

func write() {
	consecutiveFailures := 0

	for {
		// Wait a random amount of time (to avoid looking too suspicious)
		// Note - rand was seeded with the startup time in flashlight.go
		n := rand.Intn(publishSecondsVariance)
		wait := time.Duration(basePublishSeconds-publishSecondsVariance/2+n) * time.Second

		oldLocation := GetLocation()
		var newLocation *geolookup.City
		var err error
		wc := withClient.Load().(func(func(*http.Client)))
		wc(func(c *http.Client) {
			newLocation, err = geolookup.LookupIPWithClient("", c)
		})
		if err == nil {
			consecutiveFailures = 0
			if !reflect.DeepEqual(newLocation, oldLocation) {
				log.Debugf("Location changed")
				location.Store(newLocation)
				pubsub.Pub(pubsub.Location, newLocation)
			}
			// Always publish location, even if unchanged
			service.Out <- newLocation
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
			if oldLocation != nil {
				service.Out <- oldLocation
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
