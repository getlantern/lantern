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

// deltaMessage is the struct of the message we're expecting from the client.
type deltaMessage struct {
	Delta proxiedsites.Delta `json:"Message"`
}

var (
	log = golog.LoggerFor("proxiedsites-flashlight")

	service *ui.Service

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
			Type:    messageType,
			Message: delta,
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

	// Registering a websocket service.
	helloFn := func(write func([]byte) error) error {

		// Hello message.
		message := ui.Envelope{
			Type:    messageType,
			Message: proxiedsites.ActiveDelta(),
		}

		b, err := json.Marshal(message)

		if err != nil {
			return fmt.Errorf("Unable to marshal active delta to json: %v", err)
		}

		return write(b)
	}

	if service, err = ui.Register(messageType, helloFn); err != nil {
		return fmt.Errorf("Unable to register channel: %q", err)
	}

	// Register the PAC handler
	url := ui.Handle("/proxy_on.pac", http.HandlerFunc(proxiedsites.ServePAC))
	log.Debugf("Serving PAC file at %v", url)

	// Initializing reader.
	go read()

	return nil
}

func read() {
	for b := range service.In {
		var message deltaMessage

		err := json.Unmarshal(b, &message)
		if err != nil {
			log.Errorf("Unable to parse JSON update from browser: %v", err)
			continue
		}

		config.Update(func(updated *config.Config) error {
			log.Debugf("Applying update from UI")
			updated.ProxiedSites.Delta.Merge(&message.Delta)
			return nil
		})
	}
}
