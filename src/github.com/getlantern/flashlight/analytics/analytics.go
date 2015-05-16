package analytics

import (
	"net/http"
	"runtime"

	"github.com/getlantern/flashlight/config"
	"github.com/mitchellh/mapstructure"

	"github.com/getlantern/analytics"
	"github.com/getlantern/flashlight/ui"
	"github.com/getlantern/golog"
)

const (
	messageType = `Analytics`
)

var (
	log        = golog.LoggerFor("flashlight.analytics")
	service    *ui.Service
	withClient func(func(*http.Client))
	hostName   *string
	stopCh     chan bool
)

func Configure(cfg *config.Config, serverSession bool, wc func(func(*http.Client))) {

	withClient = wc

	sessionPayload := &analytics.Payload{
		HitType: analytics.EventType,
		Event: &analytics.Event{
			Category: "Session",
			Action:   "Start",
			Label:    runtime.GOOS,
		},
	}

	if cfg == nil {
		sessionEvent(sessionPayload)
		return
	}

	if cfg.InstanceId != "" {
		sessionPayload.ClientId = cfg.InstanceId
	}
	if cfg.Version != 0 {
		sessionPayload.ClientVersion = string(cfg.Version)
	}

	if serverSession {
		sessionPayload.Hostname = cfg.Server.RegisterAt
	} else {
		sessionPayload.Hostname = "localhost"
	}

	sessionEvent(sessionPayload)

	if !serverSession && cfg.AutoReport != nil && *cfg.AutoReport {
		err := StartService()
		if err != nil {
			log.Errorf("Error starting analytics service: %q", err)
		}
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
				uiEvent(&payload)
			}
		}
	}
}

func sessionEvent(payload *analytics.Payload) {
	withClient(func(c *http.Client) {
		analytics.SessionEvent(c, payload)
	})
}

func uiEvent(payload *analytics.Payload) {
	withClient(func(c *http.Client) {
		analytics.UIEvent(c, payload)
	})
}
