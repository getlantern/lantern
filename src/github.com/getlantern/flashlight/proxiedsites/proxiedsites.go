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

var (
	log = golog.LoggerFor("proxiedsites-flashlight")

	uichannel  *ui.UIChannel
	startMutex sync.Mutex
)

func Configure(cfg *proxiedsites.Config) {
	delta := proxiedsites.Configure(cfg)
	startMutex.Lock()
	if uichannel == nil {
		start()
	} else if delta != nil {
		b, err := json.Marshal(delta)
		if err != nil {
			log.Errorf("Unable to publish delta to UI: %v", err)
		} else {
			uichannel.Out <- b
		}
	}
	startMutex.Unlock()
}

func start() {
	// Register the PAC handler
	url := ui.Handle("/proxy_on.pac", http.HandlerFunc(proxiedsites.ServePAC))
	log.Debugf("Serving PAC file at %v", url)

	// Establish a channel to the UI for sending and receiving updates
	uichannel = ui.NewChannel("/data", func(write func([]byte) error) error {
		b, err := json.Marshal(proxiedsites.ActiveDelta())
		if err != nil {
			return fmt.Errorf("Unable to marshal active delta to json: %v", err)
		}
		return write(b)
	})
	log.Debugf("Accepting proxiedsites websocket connections at %v", uichannel.URL)

	go read()
}

func read() {
	for b := range uichannel.In {
		delta := &proxiedsites.Delta{}
		err := json.Unmarshal(b, delta)
		if err != nil {
			log.Errorf("Unable to parse JSON update from browser: %v", err)
			continue
		}
		config.Update(func(updated *config.Config) error {
			log.Debugf("Applying update from UI")
			updated.ProxiedSites.Delta.Merge(delta)
			return nil
		})
	}
}
