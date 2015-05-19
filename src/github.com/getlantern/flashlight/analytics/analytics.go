package analytics

import (
	"net/http"
	"runtime"
	"time"

	"github.com/getlantern/flashlight/config"
	"github.com/mitchellh/mapstructure"

	"github.com/getlantern/analytics"
	"github.com/getlantern/flashlight/ui"
	"github.com/getlantern/golog"
	"github.com/getlantern/waitforserver"
)

const (
	messageType = `Analytics`
)

var (
	log        = golog.LoggerFor("flashlight.analytics")
	service    *ui.Service
	httpClient *http.Client
	hostName   *string
	stopCh     chan bool
)

func Configure(newClient *http.Client, cfg *config.Config, proxyAddr string, version string) {

	httpClient = newClient

	SessionEvent(httpClient, cfg.Addr, version, "")

	if cfg.AutoReport != nil && *cfg.AutoReport {
		err := StartService()
		if err != nil {
			log.Errorf("Error starting analytics service: %q", err)
		}
	}
}

func SessionEvent(httpClient *http.Client, proxyAddr string, version string, trackingId string) {
	sessionPayload := &analytics.Payload{
		HitType:    analytics.EventType,
		TrackingId: trackingId,
		Hostname:   "localhost",
		Event: &analytics.Event{
			Category: "Session",
			Action:   "Start",
			Label:    runtime.GOOS,
		},
	}

	if version != "" {
		sessionPayload.CustomVars = map[string]string{
			"cd1": version,
		}
	}

	go func() {
		if err := waitforserver.WaitForServer("tcp", proxyAddr, 3*time.Second); err != nil {
			log.Error(err)
			return
		}
		analytics.SessionEvent(httpClient, sessionPayload)
	}()
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
				analytics.UIEvent(httpClient, &payload)
			}
		}
	}
}
