package flashlight

import (
	"path/filepath"
	"sync"

	"github.com/getlantern/appdir"
	"github.com/getlantern/fronted"
	"github.com/getlantern/golog"

	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/config"
	"github.com/getlantern/flashlight/geolookup"
	"github.com/getlantern/flashlight/logging"
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
	beforeStart func() bool,
	afterStart func(),
	onConfigUpdate func(cfg *config.Config),
	userConfig config.UserConfig,
	onError func(err error),
	deviceID string) error {
	displayVersion()

	cl := client.NewClient(proxyAll)

	dispatch := func(cfg interface{}) {
		switch t := cfg.(type) {
		default:
			log.Errorf("Unexpected type: %T", t)
		case map[string]*client.ChainedServerInfo:
			cl.Configure(cfg.(map[string]*client.ChainedServerInfo), deviceID)
		case *config.Config:
			applyClientConfig(cl, cfg.(*config.Config), deviceID)
			onConfigUpdate(cfg.(*config.Config))
		}
	}

	proxyFactory := func() interface{} {
		return make(map[string]*client.ChainedServerInfo)
	}
	pipeConfig(configDir, flagsAsMap, "proxies.yaml", userConfig, proxyFactory, dispatch, config.EmbeddedProxies)

	globalFactory := func() interface{} {
		return &config.Config{}
	}
	pipeConfig(configDir, flagsAsMap, "global.yaml", userConfig, globalFactory, dispatch, config.Resources)

	proxied.SetProxyAddr(cl.Addr)

	if beforeStart() {
		log.Debug("Preparing to start client proxy")
		geolookup.Refresh()

		if socksProxyAddr != "" {
			go func() {
				log.Debug("Starting client SOCKS5 proxy")
				err := cl.ListenAndServeSOCKS5(socksProxyAddr)
				if err != nil {
					log.Errorf("Unable to start SOCKS5 proxy: %v", err)
				}
			}()
		}

		log.Debug("Starting client HTTP proxy")
		err := cl.ListenAndServeHTTP(httpProxyAddr, func() {
			log.Debug("Started client HTTP proxy")
			afterStart()
		})
		if err != nil {
			log.Errorf("Error starting client proxy: %v", err)
			onError(err)
		}
	}

	return nil
}

func pipeConfig(configDir string, flags map[string]interface{},
	name string, userConfig config.UserConfig,
	factory func() interface{}, dispatch func(cfg interface{}),
	data []byte) {

	configChan := make(chan interface{})

	go func() {
		for {
			cfg := <-configChan
			dispatch(cfg)
		}
	}()
	configPath, err := client.InConfigDir(configDir, name)
	if err != nil {
		log.Errorf("Could not get config path? %v", err)
	}

	obfs := obfuscate(flags)

	log.Debugf("Obfuscating %v", obfs)
	conf := config.NewConfig(configPath, obfs, name+".gz", name, factory)

	if cfg, proxyErr := conf.Saved(); proxyErr != nil {
		log.Debugf("Could not load stored config %v", proxyErr)
		if embedded, errr := conf.Embedded(); errr != nil {
			log.Errorf("Could not load embedded config %v", errr)
		} else {
			configChan <- embedded
		}
	} else {
		configChan <- cfg
	}
	go conf.Poll(userConfig, flags, configChan)
}

func obfuscate(flags map[string]interface{}) bool {
	return flags["readableconfig"] == nil || !flags["readableconfig"].(bool)
}

func applyClientConfig(client *client.Client, cfg *config.Config, deviceID string) {
	certs, err := cfg.GetTrustedCACerts()
	if err != nil {
		log.Errorf("Unable to get trusted ca certs, not configuring fronted: %s", err)
	} else {
		fronted.Configure(certs, cfg.Client.MasqueradeSets, filepath.Join(appdir.General("Lantern"), "masquerade_cache"))
	}
	logging.Configure(cfg.CloudConfigCA, deviceID, Version, RevisionDate, cfg.BordaReportInterval, cfg.BordaSamplePercentage)
}

func displayVersion() {
	log.Debugf("---- flashlight version: %s, release: %s, build revision date: %s ----", Version, PackageVersion, RevisionDate)
}
