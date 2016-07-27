package config

import (
	"time"

	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/golog"
)

var (
	log = golog.LoggerFor("flashlight.config")

	// globalURLs are the chained and fronted URLs for fetching the global config.
	globalURLs = &chainedFrontedURLs{
		chained: "https://globalconfig.flashlightproxy.com/global.yaml.gz",
		fronted: "https://d24ykmup0867cj.cloudfront.net/global.yaml.gz",
	}

	// globalStagingURLs are the chained and fronted URLs for fetching the global
	// config in a staging environment.
	globalStagingURLs = &chainedFrontedURLs{
		chained: "https://globalconfig.flashlightproxy.com/global.yaml.gz",
		fronted: "https://d24ykmup0867cj.cloudfront.net/global.yaml.gz",
	}

	// The following are over HTTP because proxies do not forward X-Forwarded-For
	// with HTTPS and because we only support falling back to direct domain
	// fronting through the local proxy for HTTP.

	// proxiesURLs are the chained and fronted URLs for fetching the per user
	// proxy config.
	proxiesURLs = &chainedFrontedURLs{
		chained: "http://config.getiantem.org/proxies.yaml.gz",
		fronted: "http://d2wi0vwulmtn99.cloudfront.net/proxies.yaml.gz",
	}

	// proxiesStagingURLs are the chained and fronted URLs for fetching the per user
	// proxy config in a staging environment.
	proxiesStagingURLs = &chainedFrontedURLs{
		chained: "http://config-staging.getiantem.org/proxies.yaml.gz",
		fronted: "http://d33pfmbpauhmvd.cloudfront.net/proxies.yaml.gz",
	}
)

// Init initializes the config setup for both fetching per-user proxies as well
// as the global config.
func Init(configDir string, flagsAsMap map[string]interface{},
	userConfig UserConfig, proxiesDispatch func(interface{}),
	globalDispatch func(interface{})) {
	staging := isStaging(flagsAsMap)
	// These are the options for fetching the per-user proxy config.
	proxyOptions := &options{
		saveDir:    configDir,
		obfuscate:  obfuscate(flagsAsMap),
		name:       "proxies.yaml",
		urls:       checkOverrides(flagsAsMap, getProxyURLs(staging), "proxies.yaml.gz"),
		userConfig: userConfig,
		yamlTemplater: func() interface{} {
			return make(map[string]*client.ChainedServerInfo)
		},
		dispatch:     proxiesDispatch,
		embeddedData: EmbeddedProxies,
		sleep:        1 * time.Minute,
	}

	pipeConfig(proxyOptions)

	// These are the options for fetching the global config.
	globalOptions := &options{
		saveDir:    configDir,
		obfuscate:  obfuscate(flagsAsMap),
		name:       "global.yaml",
		urls:       checkOverrides(flagsAsMap, getGlobalURLs(staging), "global.yaml.gz"),
		userConfig: userConfig,
		yamlTemplater: func() interface{} {
			return &Global{}
		},
		dispatch:     globalDispatch,
		embeddedData: GlobalConfig,
		sleep:        24 * time.Hour,
	}

	pipeConfig(globalOptions)
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
	urls *chainedFrontedURLs, name string) *chainedFrontedURLs {
	if s, ok := flags["cloudconfig"].(string); ok {
		if len(s) > 0 {
			log.Debugf("Overridding chained URL from the command line '%v'", s)
			urls.chained = s + "/" + name
		}
	}
	if s, ok := flags["frontedconfig"].(string); ok {
		if len(s) > 0 {
			log.Debugf("Overridding fronted URL from the command line '%v'", s)
			urls.fronted = s + "/" + name
		}
	}
	return urls
}

// getProxyURLs returns the proxy URLs to use depending on whether or not
// we're in staging.
func getProxyURLs(staging bool) *chainedFrontedURLs {
	if staging {
		log.Debug("Configuring for staging")
		return proxiesStagingURLs
	}
	log.Debugf("Not configuring for staging.")
	return proxiesURLs
}

// getGlobalURLs returns the global URLs to use depending on whether or not
// we're in staging.
func getGlobalURLs(staging bool) *chainedFrontedURLs {
	if staging {
		log.Debug("Configuring for staging")
		return globalStagingURLs
	}
	log.Debugf("Not configuring for staging.")
	return globalURLs
}
