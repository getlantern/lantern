package config

import (
	"flag"
	"time"

	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/server"
	"github.com/getlantern/flashlight/statreporter"
)

var (
	configdir      = flag.String("configdir", "", "directory in which to store configuration, including flashlight.yaml (defaults to current directory)")
	configaddr     = flag.String("configaddr", "", "if specified, run an http-based configuration server at this address")
	cloudconfig    = flag.String("cloudconfig", "", "optional http(s) URL to a cloud-based source for configuration updates")
	cloudconfigca  = flag.String("cloudconfigca", "", "optional PEM encoded certificate used to verify TLS connections to fetch cloudconfig")
	addr           = flag.String("addr", "", "ip:port on which to listen for requests. When running as a client proxy, we'll listen with http, when running as a server proxy we'll listen with https (required)")
	unencrypted    = flag.Bool("unencrypted", false, "set to true to run server in unencrypted mode (no TLS)")
	role           = flag.String("role", "", "either 'client' or 'server' (required)")
	statsPeriod    = flag.Int("statsperiod", 0, "time in seconds to wait between reporting stats. If not specified, stats are not reported. If specified, statshub, instanceid and statsaddr must also be specified.")
	statshubAddr   = flag.String("statshub", "pure-journey-3547.herokuapp.com", "address of statshub server")
	instanceid     = flag.String("instanceid", "", "instanceId under which to report stats to statshub. If not specified, no stats are reported.")
	registerat     = flag.String("registerat", "", "base URL for peer DNS registry at which to register (e.g. https://peerscanner.getiantem.org)")
	statsaddr      = flag.String("statsaddr", "", "host:port at which to make detailed stats available using server-sent events (optional)")
	country        = flag.String("country", "xx", "2 digit country code under which to report stats. Defaults to xx.")
	cpuprofile     = flag.String("cpuprofile", "", "write cpu profile to given file")
	memprofile     = flag.String("memprofile", "", "write heap profile to given file")
	portmap        = flag.Int("portmap", 0, "try to map this port on the firewall to the port on which flashlight is listening, using UPnP or NAT-PMP. If mapping this port fails, flashlight will exit with status code 50")
	advertisedHost = flag.String("server", "", "FQDN of flashlight server when running in server mode (required)")
)

// applyFlags updates this Config from any command-line flags that were passed
// in. ApplyFlags assumes that flag.Parse() has already been called.
func (updated *Config) applyFlags() error {
	if updated.Client == nil {
		updated.Client = &client.ClientConfig{}
	}

	if updated.Server == nil {
		updated.Server = &server.ServerConfig{}
	}

	if updated.Stats == nil {
		updated.Stats = &statreporter.Config{}
	}

	// Visit all flags that have been set and copy to config
	flag.Visit(func(f *flag.Flag) {
		switch f.Name {
		// General
		case "cloudconfig":
			updated.CloudConfig = *cloudconfig
		case "cloudconfigca":
			updated.CloudConfigCA = *cloudconfigca
		case "addr":
			updated.Addr = *addr
		case "role":
			updated.Role = *role
		case "statsaddr":
			updated.StatsAddr = *statsaddr
		case "instanceid":
			updated.InstanceId = *instanceid
		case "country":
			updated.Country = *country

			// Stats
		case "statsperiod":
			updated.Stats.ReportingPeriod = time.Duration(*statsPeriod) * time.Second
		case "statshub":
			updated.Stats.StatshubAddr = *statshubAddr

		// Server
		case "portmap":
			updated.Server.Portmap = *portmap
		case "server":
			updated.Server.AdvertisedHost = *advertisedHost
		case "registerat":
			updated.Server.RegisterAt = *registerat
		}
	})

	// Settings that get set no matter what
	updated.CpuProfile = *cpuprofile
	updated.MemProfile = *memprofile
	updated.Server.Unencrypted = *unencrypted

	return nil
}
