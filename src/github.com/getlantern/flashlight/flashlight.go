package flashlight

import (
	"fmt"

	"github.com/getlantern/golog"

	"github.com/getlantern/flashlight/config"
)

// While in development mode we probably would not want auto-updates to be
// applied. Using a big number here prevents such auto-updates without
// disabling the feature completely. The "make package-*" tool will take care
// of bumping this version number so you don't have to do it by hand.
const (
	DefaultPackageVersion = "9999.99.99"
	PackageVersion        = DefaultPackageVersion
)

var (
	log = golog.LoggerFor("flashlight")
)

func InitConfig(configDir string, stickyConfig bool, flagsAsMap map[string]interface{}) (*config.Config, chan *config.Config, chan error, error) {
	configUpdates := make(chan *config.Config)
	errorCh := make(chan error, 1)
	cfg, err := config.Init(PackageVersion, configDir, stickyConfig, flagsAsMap)
	if err != nil {
		return cfg, configUpdates, errorCh, fmt.Errorf("Unable to initialize configuration: %v", err)
	}

	go func() {
		err := config.Run(func(updated *config.Config) {
			configUpdates <- updated
		})
		if err != nil {
			errorCh <- err
		}
	}()

	return cfg, configUpdates, errorCh, nil
}
