package analytics

import (
	"net/http"

	"github.com/getlantern/flashlight/config"
	"github.com/getlantern/flashlight/pubsub"
	"github.com/mitchellh/mapstructure"

	"github.com/getlantern/analytics"
	"github.com/getlantern/flashlight/ui"
	"github.com/getlantern/golog"
)

const (
	messageType = `Analytics`
	TrackingId  = "UA-21815217-12"
)

var (
	log        = golog.LoggerFor("flashlight.analytics")
	service    *ui.Service
	httpClient *http.Client
	hostName   *string
	stopCh     chan bool
)

func Configure(cfg *config.Config, version string) {

	if cfg.AutoReport != nil && *cfg.AutoReport {
		pubsub.Sub(pubsub.IP, func(ip string) {
			log.Debugf("Got IP %v -- starting analytics", ip)
			analytics.Configure(ip, TrackingId, version, cfg.Addr)

			err := StartService()
			if err != nil {
				log.Errorf("Error starting analytics service: %q", err)
			}
		})
	}
}

// Used with clients to track user interaction with the UI
func StartService() error {

	var err error

	if service != nil {
		return nil
	}

	newMessage := func() interface{} {
		return &analytics.Payload{}
	}

	if service, err = ui.Register(messageType, newMessage, nil); err != nil {
		log.Errorf("Unable to register analytics service: %q", err)
		return err
	}

	stopCh = make(chan bool)

	// process analytics messages
	go read()

	return err
}

func StopService() {
	if service != nil && stopCh != nil {
		ui.Unregister(messageType)
		stopCh <- true
		service = nil
		log.Debug("Successfully stopped analytics service")
	}
}

func read() {

	for {
		select {
		case <-stopCh:
			return
		case msg := <-service.In:
			log.Debugf("New UI analytics message: %q", msg)
			var payload analytics.Payload
			if err := mapstructure.Decode(msg, &payload); err != nil {
				log.Errorf("Could not decode payload: %q", err)
			} else {
				// set to localhost on clients
				payload.Hostname = "localhost"
				payload.HitType = analytics.PageViewType
				// for now, the only analytics messages we are
				// currently receiving from the UI are initial page
				// views which indicate new UI sessions
				if status, err := analytics.SendRequest(&payload); err != nil {
					log.Debugf("Error sending analytics request: %v", err)
				} else {
					log.Tracef("Analytics request status: %v", status)
				}
			}
		}
	}
}
