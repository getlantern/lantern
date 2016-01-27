package main

import "flag"

var (
	configdir     = flag.String("configdir", "", "directory in which to store configuration, including flashlight.yaml (defaults to current directory)")
	cloudconfig   = flag.String("cloudconfig", "", "optional http(s) URL to a cloud-based source for configuration updates")
	cloudconfigca = flag.String("cloudconfigca", "", "optional PEM encoded certificate used to verify TLS connections to fetch cloudconfig")
	instanceid    = flag.String("instanceid", "", "instanceId under which to report stats to statshub. If not specified, no stats are reported.")
	registerat    = flag.String("registerat", "", "base URL for peer DNS registry at which to register (e.g. https://peerscanner.getiantem.org)")
	country       = flag.String("country", "xx", "2 digit country code under which to report stats. Defaults to xx.")
	cpuprofile    = flag.String("cpuprofile", "", "write cpu profile to given file")
	memprofile    = flag.String("memprofile", "", "write heap profile to given file")
	uiaddr        = flag.String("uiaddr", "", "if specified, indicates host:port the UI HTTP server should be started on")
	proxyAll      = flag.Bool("proxyall", false, "set to true to proxy all traffic through Lantern network")
	stickyConfig  = flag.Bool("stickyconfig", false, "set to true to only use the local config file")
)

// flagsAsMap returns a map of all flags that were provided at runtime
func flagsAsMap() map[string]interface{} {
	flags := make(map[string]interface{})
	flag.Visit(func(f *flag.Flag) {
		flags[f.Name] = f.Value.(flag.Getter).Get()
	})
	// Some properties should always be included
	flags["cpuprofile"] = *cpuprofile
	flags["memprofile"] = *memprofile
	return flags
}
