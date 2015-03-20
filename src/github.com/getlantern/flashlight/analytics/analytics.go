package analytics

import (
	"github.com/mitchellh/mapstructure"

	"github.com/getlantern/analytics"
	"github.com/getlantern/flashlight/ui"
	"github.com/getlantern/golog"
)

const (
	messageType = `Analytics`
)

var (
	log = golog.LoggerFor("flashlight.analytics")

	service *ui.Service
)

func Start() (err error) {

	if service != nil {
		return
	}

	newMessage := func() interface{} {
		return &analytics.Payload{}
	}

	if service, err = ui.Register(messageType, newMessage, nil); err != nil {
		log.Errorf("Unable to register analytics service: %q", err)
		return err
	}

	// process analytics messages
	go read()

	return nil
}

func read() {

	for msg := range service.In {
		log.Debugf("New analytics message: %q", msg)
		var payload analytics.Payload
		if err := mapstructure.Decode(msg, &payload); err != nil {
			log.Errorf("Could not decode payload: %q", err)
		}
		analytics.SendRequest(nil, &payload)
	}
}
