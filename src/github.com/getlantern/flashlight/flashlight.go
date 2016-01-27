package flashlight

import (
	"fmt"
	"sync"

	"github.com/getlantern/fronted"
	"github.com/getlantern/golog"

	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/config"
	"github.com/getlantern/flashlight/geolookup"
	"github.com/getlantern/flashlight/logging"
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

	Version      string
	RevisionDate string // The revision date and time that is associated with the version string.
	BuildDate    string // The actual date and time the binary was built.

	cfgMutex sync.Mutex
)

func init() {
	if PackageVersion != DefaultPackageVersion {
		// packageVersion has precedence over GIT revision. This will happen when
		// packing a version intended for release.
		Version = PackageVersion
	}

	if Version == "" {
		Version = "development"
	}

	if RevisionDate == "" {
		RevisionDate = "now"
	}
}

func Start(configDir string,
	stickyConfig bool,
	proxyAll func() bool,
	flagsAsMap map[string]interface{},
	beforeStart func(cfg *config.Config) bool,
	afterStart func(cfg *config.Config),
	onConfigUpdate func(cfg *config.Config),
	onError func(err error)) error {
	displayVersion()

	log.Debug("Initializing configuration")
	cfg, err := config.Init(PackageVersion, configDir, stickyConfig, flagsAsMap)
	if err != nil {
		return fmt.Errorf("Unable to initialize configuration: %v", err)
	}

	client := &client.Client{
		Addr:         cfg.Addr,
		ReadTimeout:  0, // don't timeout
		WriteTimeout: 0,
	}

	if beforeStart(cfg) {
		log.Debug("Preparing to start client proxy")
		geolookup.Refresh(cfg.Addr)
		cfgMutex.Lock()
		applyClientConfig(client, cfg, proxyAll)
		cfgMutex.Unlock()

		go func() {
			err := config.Run(func(updated *config.Config) {
				log.Debug("Applying updated configuration")
				cfgMutex.Lock()
				applyClientConfig(client, updated, proxyAll)
				onConfigUpdate(updated)
				cfgMutex.Unlock()
				log.Debug("Applied updated configuration")
			})
			if err != nil {
				onError(err)
			}
		}()

		log.Debug("Starting client proxy")
		err = client.ListenAndServe(func() {
			log.Debug("Started client proxy")
			// We finally tell the config package to start polling for new configurations.
			// This is the final step because the config polling itself uses the full
			// proxying capabilities of Lantern, so it needs everything to be properly
			// set up with at least an initial bootstrap config (on first run) to
			// complete successfully.
			config.StartPolling()
			afterStart(cfg)
		})
		if err != nil {
			log.Errorf("Error starting client proxy: %v", err)
			onError(err)
		}
	}

	return nil
}

func applyClientConfig(client *client.Client, cfg *config.Config, proxyAll func() bool) {
	certs, err := cfg.GetTrustedCACerts()
	if err != nil {
		log.Errorf("Unable to get trusted ca certs, not configuring fronted: %s", err)
	} else {
		fronted.Configure(certs, cfg.Client.MasqueradeSets)
	}
	logging.Configure(cfg.Addr, cfg.CloudConfigCA, cfg.Client.DeviceID,
		Version, RevisionDate)
	// Update client configuration and get the highest QOS dialer available.
	client.Configure(cfg.Client, proxyAll)
}

func displayVersion() {
	log.Debugf("---- flashlight version: %s, release: %s, build revision date: %s ----", Version, PackageVersion, RevisionDate)
}
