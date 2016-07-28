package main

import (
	"flag"
	"time"
)

var (
	addr                   = flag.String("addr", "", "ip:port on which to listen for requests. When running as a client proxy, we'll listen with http, when running as a server proxy we'll listen with https (required)")
	configdir              = flag.String("configdir", "", "directory in which to store configuration, including flashlight.yaml (defaults to current directory)")
	cloudconfig            = flag.String("cloudconfig", "", "optional http(s) URL to a cloud-based source for configuration updates")
	cloudconfigca          = flag.String("cloudconfigca", "", "optional PEM encoded certificate used to verify TLS connections to fetch cloudconfig")
	frontedconfig          = flag.String("frontedconfig", "", "optional http(s) URL to a cloud-based source for configuration updates")
	registerat             = flag.String("registerat", "", "base URL for peer DNS registry at which to register (e.g. https://peerscanner.getiantem.org)")
	country                = flag.String("country", "xx", "2 digit country code under which to report stats. Defaults to xx.")
	cpuprofile             = flag.String("cpuprofile", "", "write cpu profile to given file")
	memprofile             = flag.String("memprofile", "", "write heap profile to given file")
	uiaddr                 = flag.String("uiaddr", "127.0.0.1:16823", "if specified, indicates host:port the UI HTTP server should be started on")
	proxyAll               = flag.Bool("proxyall", false, "set to true to proxy all traffic through Lantern network")
	stickyConfig           = flag.Bool("stickyconfig", false, "set to true to only use the local config file")
	headless               = flag.Bool("headless", false, "if true, lantern will run with no ui")
	startup                = flag.Bool("startup", false, "if true, Lantern was automatically run on system startup")
	clearProxySettings     = flag.Bool("clear-proxy-settings", false, "if true, Lantern removes proxy settings from the system.")
	pprofAddr              = flag.String("pprofaddr", "", "pprof address to listen on, not activate pprof if empty")
	forceProxyAddr         = flag.String("force-proxy-addr", "", "if specified, force chained proxying to use this address instead of the configured one")
	forceAuthToken         = flag.String("force-auth-token", "", "if specified, force chained proxying to use this auth token instead of the configured one")
	readableconfig         = flag.Bool("readableconfig", false, "if specified, disables obfuscation of the config yaml so that it remains human readable")
	staging                = flag.Bool("staging", false, "if true, run Lantern against our staging infrastructure")
	bordaReportInterval    = flag.Duration("borda-report-interval", 5*time.Minute, "How frequently to report errors to borda. Set to 0 to disable reporting.")
	bordaSamplePercentage  = flag.Float64("borda-sample-percentage", 0.01, "The percentage of devices to report to Borda (0.01 = 1%)")
	logglySamplePercentage = flag.Float64("loggly-sample-percentage", 0.02, "The percentage of devices to report to Loggly (0.02 = 2%)")
	help                   = flag.Bool("help", false, "Get usage help")
)

// flagsAsMap returns a map of all flags that were provided at runtime
func flagsAsMap() map[string]interface{} {
	flags := make(map[string]interface{})
	flag.VisitAll(func(f *flag.Flag) {
		flags[f.Name] = f.Value.(flag.Getter).Get()
	})
	// Some properties should always be included
	flags["cpuprofile"] = *cpuprofile
	flags["memprofile"] = *memprofile
	return flags
}
