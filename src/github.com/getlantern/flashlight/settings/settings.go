// service for exchanging current user settings with UI
package settings

import (
	"net/http"
	"sync"

	"github.com/getlantern/flashlight/analytics"
	"github.com/getlantern/flashlight/config"

	"github.com/getlantern/flashlight/ui"
	"github.com/getlantern/golog"
)

const (
	messageType = `Settings`
)

var (
	log          = golog.LoggerFor("flashlight.settings")
	service      *ui.Service
	cfgMutex     sync.Mutex
	baseSettings *Settings
	httpClient   *http.Client
)

type Settings struct {
	Version    string
	BuildDate  string
	AutoReport bool
	mutex      sync.RWMutex
}

func Configure(cfg *config.Config, version, buildDate string) {

	cfgMutex.Lock()
	defer cfgMutex.Unlock()

	// base settings are always written
	autoReport := *cfg.AutoReport
	baseSettings = &Settings{
		Version:    version,
		BuildDate:  buildDate,
		AutoReport: autoReport,
	}

	if service == nil {
		err := start(baseSettings)
		if err != nil {
			log.Errorf("Unable to register settings service: %q", err)
		}
	}
}

func start(baseSettings *Settings) error {
	var err error

	helloFn := func(write func(interface{}) error) error {
		log.Debugf("Sending Lantern settings to new client")
		baseSettings.mutex.RLock()
		settings := baseSettings
		baseSettings.mutex.RUnlock()
		return write(settings)
	}

	service, err = ui.Register(messageType, nil, helloFn)
	go read()
	return err
}

func read() {
	for msg := range service.In {
		settings := (msg).(map[string]interface{})
		config.Update(func(updated *config.Config) error {
			autoReport := settings["autoReport"].(bool)
			if autoReport {
				analytics.StartService()
			} else {
				analytics.StopService()
			}
			baseSettings.AutoReport = autoReport
			*updated.AutoReport = autoReport
			return nil
		})
	}
}
