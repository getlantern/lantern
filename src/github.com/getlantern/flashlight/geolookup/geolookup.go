package geolookup

import (
	"encoding/json"
	"fmt"
	"sync"
	"time"

	"github.com/getlantern/flashlight/ui"
	"github.com/getlantern/geolookup"
	"github.com/getlantern/golog"
)

const (
	messageType = `GeoLookup`

	sleepTime = time.Second * 10
)

var (
	log = golog.LoggerFor("geolookup-flashlight")

	service     *ui.Service
	lookupMutex sync.Mutex
	lookupData  *geolookup.City
)

func getUserGeolocationData() *geolookup.City {
	lookupMutex.Lock()
	defer lookupMutex.Unlock()

	var err error

	if lookupData != nil {
		// We already looked up IP's information.
		return lookupData
	}

	for {
		if !geolookup.UsesDefaultHTTPClient() {
			// Will look up only if we're using a proxy.
			lookupData, err = geolookup.LookupCity("")
			if err == nil {
				// We got what we wanted, no need to query for it again, let's exit.
				return lookupData
			}
		}
		// Sleep if the proxy is not ready yet of any error happened.
		time.Sleep(sleepTime)
	}

	// We should not be able to reach this point.
	panic("unreachable position")
}

// StartService initializes the geolocation websocket service.
func StartService() error {
	return start()
}

func start() (err error) {

	helloFn := func(write func([]byte) error) error {
		var b []byte
		var err error

		city := getUserGeolocationData()

		message := ui.Envelope{
			Type:    messageType,
			Message: city,
		}

		if b, err = json.Marshal(message); err != nil {
			return fmt.Errorf("Unable to marshal geolocation information: %q", err)
		}

		return write(b)
	}

	if service, err = ui.Register(messageType, helloFn); err != nil {
		return fmt.Errorf("Unable to register channel: %q", err)
	}

	go read()

	return nil
}

func read() {
	for _ = range service.In {
		// Discard message, just in case any message is sent to this service.
	}
}
