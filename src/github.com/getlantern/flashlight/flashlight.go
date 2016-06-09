package flashlight

import (
	"fmt"
	"path/filepath"
	"sync"

	"github.com/getlantern/appdir"
	"github.com/getlantern/fronted"
	"github.com/getlantern/golog"

	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/config"
	"github.com/getlantern/flashlight/geolookup"
	"github.com/getlantern/flashlight/logging"
	"github.com/getlantern/flashlight/pro"
	"github.com/getlantern/flashlight/proxied"
)

const (
	// DefaultPackageVersion is the default version of the package for auto-update
	// purposes. while in development mode we probably would not want auto-updates to be
	// applied. Using a big number here prevents such auto-updates without
	// disabling the feature completely. The "make package-*" tool will take care
	// of bumping this version number so you don't have to do it by hand.
	DefaultPackageVersion = "9999.99.99"
)

var (
	log = golog.LoggerFor("flashlight")

	// compileTimePackageVersion is set at compile-time for production builds
	compileTimePackageVersion string

	// PackageVersion is the version of the package to use depending on if we're
	// in development, production, etc.
	PackageVersion = bestPackageVersion()

	// Version is the version of Lantern we're running.
	Version string

	// RevisionDate is the date of the most recent code revision.
	RevisionDate string // The revision date and time that is associated with the version string.

	// BuildDate is the date the code was actually built.
	BuildDate string // The actual date and time the binary was built.

	cfgMutex sync.Mutex
)

func bestPackageVersion() string {
	if compileTimePackageVersion != "" {
		return compileTimePackageVersion
	}
	return DefaultPackageVersion
}

func init() {
	log.Debugf("****************************** Package Version: %v", PackageVersion)
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

// Run runs a client proxy. It blocks as long as the proxy is running.
func Run(httpProxyAddr string,
	socksProxyAddr string,
	configDir string,
	stickyConfig bool,
	proxyAll func() bool,
	flagsAsMap map[string]interface{},
	beforeStart func(cfg *config.Config) bool,
	afterStart func(cfg *config.Config),
	onConfigUpdate func(cfg *config.Config),
	userConfig config.UserConfig,
	onError func(err error),
	deviceID string) error {
	displayVersion()

	log.Debug("Initializing configuration")
	cfg, err := config.Init(userConfig, PackageVersion, configDir, stickyConfig, flagsAsMap)
	if err != nil {
		return fmt.Errorf("Unable to initialize configuration: %v", err)
	}

	client := client.NewClient(proxyAll)
	proxied.SetProxyAddr(client.Addr)

	if beforeStart(cfg) {
		log.Debug("Preparing to start client proxy")
		geolookup.Refresh()
		cfgMutex.Lock()
		applyClientConfig(client, cfg, deviceID)
		cfgMutex.Unlock()

		go func() {
			err := config.Run(func(updated *config.Config) {
				log.Debug("Applying updated configuration")
				cfgMutex.Lock()
				applyClientConfig(client, updated, deviceID)
				onConfigUpdate(updated)
				cfgMutex.Unlock()
				log.Debug("Applied updated configuration")
			})
			if err != nil {
				onError(err)
			}
		}()

		if socksProxyAddr != "" {
			go func() {
				log.Debug("Starting client SOCKS5 proxy")
				err = client.ListenAndServeSOCKS5(socksProxyAddr)
				if err != nil {
					log.Errorf("Unable to start SOCKS5 proxy: %v", err)
				}
			}()
		}

		log.Debug("Starting client HTTP proxy")
		err = client.ListenAndServeHTTP(httpProxyAddr, func() {
			log.Debug("Started client HTTP proxy")
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

func applyClientConfig(client *client.Client, cfg *config.Config, deviceID string) {
	certs, err := cfg.GetTrustedCACerts()
	if err != nil {
		log.Errorf("Unable to get trusted ca certs, not configuring fronted: %s", err)
	} else {
		fronted.Configure(certs, cfg.Client.MasqueradeSets, filepath.Join(appdir.General("Lantern"), "masquerade_cache"))
	}
<<<<<<< HEAD
	logging.Configure(cfg.CloudConfigCA, deviceID, Version, RevisionDate)
	pro.Configure(cfg.CloudConfigCA)
=======
	logging.Configure(cfg.CloudConfigCA, deviceID, Version, RevisionDate, cfg.BordaReportInterval, cfg.BordaSamplePercentage)
>>>>>>> devel
	// Update client configuration
	client.Configure(cfg.Client, deviceID)
}

func displayVersion() {
	log.Debugf("---- flashlight version: %s, release: %s, build revision date: %s ----", Version, PackageVersion, RevisionDate)
}
