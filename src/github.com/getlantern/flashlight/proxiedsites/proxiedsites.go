package proxiedsites

import (
	"encoding/json"
	"fmt"
	"sync"
	"time"

	"github.com/getlantern/detour"
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

	if delta != nil {
		updateDetour(delta)
	}
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

func updateDetour(delta *proxiedsites.Delta) {
	// TODO: subscribe changes of geolookup and set country accordingly
	// safe to hardcode here as IR has all detection rules
	detour.SetCountry("IR")
	curWl := detour.DumpWhitelist()
	// for simplicity, detour matches whitelist using host:port string
	// so we add ports to each proxiedsites
	for _, v := range delta.Deletions {
		delete(curWl, v+":80")
		delete(curWl, v+":443")
	}
	for _, v := range delta.Additions {
		curWl[v+":80"] = time.Now()
		curWl[v+":443"] = time.Now()
	}
	detour.InitWhitelist(curWl)
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
