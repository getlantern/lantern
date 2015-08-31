package geolookup

import (
	"fmt"
	"math"
	"math/rand"
	"net/http"
	"net/http/httputil"
	"sync"
	"sync/atomic"
	"time"

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

	service  *ui.Service
	client   atomic.Value
	cfgMutex sync.Mutex
	country  = atomicString()
	ip       = atomicString()
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
func Configure(newClient *http.Client) {
	cfgMutex.Lock()
	defer cfgMutex.Unlock()

	// Avoid annoying checks for nil later.
	ip.Store("")
	country.Store("")

	client.Store(newClient)

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

func lookupIp(httpClient *http.Client) (string, string, error) {
	httpClient.Timeout = 60 * time.Second

	var err error
	var req *http.Request
	var resp *http.Response

	// Note this will typically be an HTTP client that uses direct domain fronting to
	// hit our server pool in the Netherlands.
	if req, err = http.NewRequest("HEAD", "http://nl.fallbacks.getiantem.org", nil); err != nil {
		return "", "", fmt.Errorf("Could not create request: %q", err)
	}

	if resp, err = httpClient.Do(req); err != nil {
		return "", "", fmt.Errorf("Could not get response from server: %q", err)
	}
	defer func() {
		if err := resp.Body.Close(); err != nil {
			log.Debugf("Unable to close reponse body: %v", err)
		}
	}()

	if resp.StatusCode != http.StatusOK {
		if full, err := httputil.DumpResponse(resp, true); err != nil {
			log.Errorf("Could not read full response %v", err)
		} else {
			log.Errorf("Unexpected response to geo IP lookup: %v", string(full))
		}
		return "", "", fmt.Errorf("Unexpected response status %d", resp.StatusCode)
	}

	ip := resp.Header.Get("Lantern-Ip")
	country := resp.Header.Get("Lantern-Country")

	log.Debugf("Got IP and country: %v, %v", ip, country)
	return country, ip, nil
}

func write() {
	consecutiveFailures := 0

	for {
		// Wait a random amount of time (to avoid looking too suspicious)
		// Note - rand was seeded with the startup time in flashlight.go
		n := rand.Intn(publishSecondsVariance)
		wait := time.Duration(basePublishSeconds-publishSecondsVariance/2+n) * time.Second

		oldIp := GetIp()
		oldCountry := GetCountry()

		newCountry, newIp, err := lookupIp(client.Load().(*http.Client))
		if err == nil {
			consecutiveFailures = 0
			if newIp != oldIp {
				log.Debugf("IP changed")
				ip.Store(newIp)
			}
			// Always publish location, even if unchanged
			pubsub.Pub(pubsub.IP, newIp)
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
