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

func Start(configDir string,
	stickyConfig bool,
	flagsAsMap map[string]interface{},
	onFirstConfig func(cfg *config.Config),
	onConfigUpdate func(cfg *config.Config),
	onError func(err error)) error {
	cfg, err := config.Init(PackageVersion, configDir, stickyConfig, flagsAsMap)
	if err != nil {
		return fmt.Errorf("Unable to initialize configuration: %v", err)
	}

	go func() {
		err := config.Run(func(updated *config.Config) {
			onConfigUpdate(updated)
		})
		if err != nil {
			onError(err)
		}
	}()

	onFirstConfig(cfg)

	return nil
}
