package flashlight

import (
	"crypto/x509"
	"path/filepath"
	"sync"
	"time"

	"github.com/getlantern/appdir"
	"github.com/getlantern/fronted"
	"github.com/getlantern/golog"
	"github.com/getlantern/keyman"

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
	onConfigUpdate func(cfg *config.Global),
	userConfig config.UserConfig,
	onError func(err error),
	deviceID string) error {
	displayVersion()

	cl := client.NewClient(proxyAll)

	staging := isStaging(flagsAsMap)

	proxyFactory := func() interface{} {
		return make(map[string]*client.ChainedServerInfo)
	}

	proxyDispatch := func(conf interface{}) {
		// Don't love the straight cast here, but we're also the ones defining
		// the type in the factory method above.
		proxyMap := conf.(map[string]*client.ChainedServerInfo)
		log.Debugf("Applying proxy config with proxies: %v", proxyMap)
		cl.Configure(proxyMap, deviceID)
	}

	proxyURLs := config.GetProxyURLs(staging)
	config.PipeConfig(configDir, obfuscate(flagsAsMap), "proxies.yaml",
		checkOverrides(flagsAsMap, proxyURLs, "proxies.yaml.gz"), userConfig, proxyFactory,
		proxyDispatch, config.EmbeddedProxies, 1*time.Minute)

	globalFactory := func() interface{} {
		return &config.Global{}
	}

	globalDispatch := func(conf interface{}) {
		// Don't love the straight cast here, but we're also the ones defining
		// the type in the factory method above.
		cfg := conf.(*config.Global)
		log.Debugf("Applying global config")
		applyClientConfig(cl, cfg, deviceID)
		onConfigUpdate(cfg)
	}

	config.PipeConfig(configDir, obfuscate(flagsAsMap), "global.yaml",
		checkOverrides(flagsAsMap, config.GetGlobalURLs(staging), "global.yaml.gz"),
		userConfig, globalFactory,
		globalDispatch, config.GlobalConfig, 24*time.Hour)

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

func obfuscate(flags map[string]interface{}) bool {
	return flags["readableconfig"] == nil || !flags["readableconfig"].(bool)
}

func isStaging(flags map[string]interface{}) bool {
	if s, ok := flags["staging"].(bool); ok {
		return s
	}
	return false
}

func checkOverrides(flags map[string]interface{},
	urls *config.ChainedFrontedURLs, name string) *config.ChainedFrontedURLs {
	if s, ok := flags["cloudconfig"].(string); ok {
		if len(s) > 0 {
			log.Debugf("Overridding chained URL from the command line '%v'", s)
			urls.Chained = s + "/" + name
		}
	}
	if s, ok := flags["frontedconfig"].(string); ok {
		if len(s) > 0 {
			log.Debugf("Overridding fronted URL from the command line '%v'", s)
			urls.Fronted = s + "/" + name
		}
	}
	return urls
}

func applyClientConfig(client *client.Client, cfg *config.Global, deviceID string) {
	certs, err := getTrustedCACerts(cfg)
	if err != nil {
		log.Errorf("Unable to get trusted ca certs, not configuring fronted: %s", err)
	} else if cfg.Client != nil {
		fronted.Configure(certs, cfg.Client.MasqueradeSets, filepath.Join(appdir.General("Lantern"), "masquerade_cache"))
	}
	logging.Configure(cfg.CloudConfigCA, deviceID, Version, RevisionDate, cfg.BordaReportInterval, cfg.BordaSamplePercentage)
}

func getTrustedCACerts(cfg *config.Global) (pool *x509.CertPool, err error) {
	certs := make([]string, 0, len(cfg.TrustedCAs))
	for _, ca := range cfg.TrustedCAs {
		certs = append(certs, ca.Cert)
	}
	pool, err = keyman.PoolContainingCerts(certs...)
	if err != nil {
		log.Errorf("Could not create pool %v", err)
	}
	return
}

func displayVersion() {
	log.Debugf("---- flashlight version: %s, release: %s, build revision date: %s ----", Version, PackageVersion, RevisionDate)
}
