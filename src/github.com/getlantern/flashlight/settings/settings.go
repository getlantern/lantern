// service for exchanging current user settings with UI
package settings

import (
	"github.com/getlantern/flashlight/ui"
	"github.com/getlantern/golog"
)

const (
	messageType = `Settings`
)

var (
	log     = golog.LoggerFor("flashlight.settings")
	service *ui.Service
)

type Settings struct {
	Version   string
	BuildDate string
}

func Configure(version, buildDate string) {
	// base settings are always written
	baseSettings := &Settings{
		Version:   version,
		BuildDate: buildDate,
	}
	start(baseSettings)
}

func start(baseSettings *Settings) error {
	var err error
	helloFn := func(write func(interface{}) error) error {
		log.Debugf("Sending Lantern settings to new client")
		return write(baseSettings)
	}

	service, err = ui.Register(messageType, nil, helloFn)
	return err
}
