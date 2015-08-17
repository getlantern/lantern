package geolookup

import (
	"fmt"
	"io/ioutil"
	"math"
	"math/rand"
	"net/http"
	"sync"
	"sync/atomic"
	"time"

	"github.com/getlantern/enproxy"
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
	country  atomic.Value
	ip       atomic.Value
)

func GetIp() string {
	c := ip.Load()
	if c == nil {
		return ""
	}
	return c.(string)
}

func GetCountry() string {
	c := country.Load()
	if c == nil {
		return ""
	}
	return c.(string)
}

// Configure configures geolookup to use the given http.Client to perform
// lookups. geolookup runs in a continuous loop, periodically updating its
// location and publishing updates to any connected clients. We do this
// continually in order to detect when the computer's location has changed.
func Configure(newClient *http.Client) {
	cfgMutex.Lock()
	defer cfgMutex.Unlock()

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

	lookupURL := "http://nl.fallbacks.getiantem.org"

	if req, err = http.NewRequest("HEAD", lookupURL, nil); err != nil {
		return "", "", fmt.Errorf("Could not create request: %q", err)
	}

	// Enproxy returns an error if this isn't there.
	req.Header.Set(enproxy.X_ENPROXY_ID, "1")

	if resp, err = httpClient.Do(req); err != nil {
		return "", "", fmt.Errorf("Could not get response from server: %q", err)
	}
	defer func() {
		if err := resp.Body.Close(); err != nil {
			log.Debugf("Unable to close reponse body: %v", err)
		}
	}()

	if resp.StatusCode != http.StatusOK {
		body := "body unreadable"
		b, err := ioutil.ReadAll(resp.Body)
		if err == nil {
			body = string(b)
		}
		return "", "", fmt.Errorf("Unexpected response status %d: %v", resp.StatusCode, body)
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
		//newCountry, ip, err := geolookup.LookupIPWithClient("", client.Load().(*http.Client))
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
