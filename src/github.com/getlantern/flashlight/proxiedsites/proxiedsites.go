package proxiedsites

import (
	"encoding/json"
	"fmt"
	"net/http"
	"sync"

	"github.com/getlantern/golog"
	"github.com/getlantern/proxiedsites"

	"github.com/getlantern/flashlight/config"
	"github.com/getlantern/flashlight/ui"
)

const (
	messageType = `ProxiedSites`
)

var (
	log = golog.LoggerFor("flashlight.proxiedsites")

	service    *ui.Service
	PACURL     string
	startMutex sync.Mutex
)

func Configure(cfg *proxiedsites.Config) {
	delta := proxiedsites.Configure(cfg)
	startMutex.Lock()

	if service == nil {
		// Initializing service.
		if err := start(); err != nil {
			log.Errorf("Unable to register service: %q", err)
		}
	} else if delta != nil {
		// Sending delta.
		message := ui.Envelope{
			EnvelopeType: ui.EnvelopeType{messageType},
			Message:      delta,
		}
		b, err := json.Marshal(message)

		if err != nil {
			log.Errorf("Unable to publish delta to UI: %v", err)
		} else {
			service.Out <- b
		}
	}

	startMutex.Unlock()
}

func start() (err error) {
	newMessage := func() interface{} {
		return &proxiedsites.Delta{}
	}

	// Registering a websocket service.
	helloFn := func(write func(interface{}) error) error {
		return write(proxiedsites.ActiveDelta())
	}

	if service, err = ui.Register(messageType, newMessage, helloFn); err != nil {
		return fmt.Errorf("Unable to register channel: %q", err)
	}

	// Register the PAC handler
	PACURL = ui.Handle("/proxy_on.pac", http.HandlerFunc(proxiedsites.ServePAC))
	log.Debugf("Serving PAC file at %v", PACURL)

	// Initializing reader.
	go read()

	return nil
}

func read() {
	for msg := range service.In {
		config.Update(func(updated *config.Config) error {
			log.Debugf("Applying update from UI")
			updated.ProxiedSites.Delta.Merge(msg.(*proxiedsites.Delta))
			return nil
		})
	}
}
