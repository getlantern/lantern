package geolookup

import (
	"fmt"
	"net/http"
	"sync"

	"github.com/getlantern/flashlight/ui"
	"github.com/getlantern/geolookup"
	"github.com/getlantern/golog"
)

const (
	messageType = `GeoLookup`

	maxRetries = 10
)

var (
	log = golog.LoggerFor("geolookup-flashlight")

	service     *ui.Service
	lookupMutex sync.Mutex
	lookupData  *geolookup.City
)

func getUserGeolocationData(client *http.Client) (*geolookup.City, error) {
	lookupMutex.Lock()
	defer lookupMutex.Unlock()

	if lookupData != nil {
		// We already looked up IP's information.
		return lookupData, nil
	}

	var err error
	for i := 0; i < maxRetries; i++ {
		// Will look up only if we're using a proxy.
		lookupData, err = geolookup.LookupCity("", client)
		if err == nil {
			// We got what we wanted, no need to query for it again, let's exit.
			return lookupData, nil
		}
	}

	return nil, fmt.Errorf("Unable to look up geolocation information in %d tries: %v", maxRetries, err)
}

// StartService initializes the geolocation websocket service using the given
// http.Client to do the lookups
func StartService(client *http.Client) (err error) {
	helloFn := func(write func(interface{}) error) error {
		city, err := getUserGeolocationData(client)
		if err != nil {
			return err
		}

		return write(city)
	}

	if service, err = ui.Register(messageType, nil, helloFn); err != nil {
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
