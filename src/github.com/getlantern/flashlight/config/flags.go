package config

import (
	"flag"
	"time"

	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/server"
	"github.com/getlantern/flashlight/statreporter"
	"github.com/getlantern/yaml"
)

var (
	configdir     = flag.String("configdir", "", "directory in which to store configuration, including flashlight.yaml (defaults to current directory)")
	configaddr    = flag.String("configaddr", "", "if specified, run an http-based configuration server at this address")
	cloudconfig   = flag.String("cloudconfig", "", "optional http(s) URL to a cloud-based source for configuration updates")
	cloudconfigca = flag.String("cloudconfigca", "", "optional PEM encoded certificate used to verify TLS connections to fetch cloudconfig")
	addr          = flag.String("addr", "", "ip:port on which to listen for requests. When running as a client proxy, we'll listen with http, when running as a server proxy we'll listen with https (required)")
	unencrypted   = flag.Bool("unencrypted", false, "set to true to run server in unencrypted mode (no TLS)")
	role          = flag.String("role", "", "either 'client' or 'server' (required)")
	statsPeriod   = flag.Int("statsperiod", 0, "time in seconds to wait between reporting stats. If not specified, stats are not reported. If specified, statshub, instanceid and statsaddr must also be specified.")
	statshubAddr  = flag.String("statshub", "pure-journey-3547.herokuapp.com", "address of statshub server")
	instanceid    = flag.String("instanceid", "", "instanceId under which to report stats to statshub. If not specified, no stats are reported.")
	statsaddr     = flag.String("statsaddr", "", "host:port at which to make detailed stats available using server-sent events (optional)")
	country       = flag.String("country", "xx", "2 digit country code under which to report stats. Defaults to xx.")
	cpuprofile    = flag.String("cpuprofile", "", "write cpu profile to given file")
	memprofile    = flag.String("memprofile", "", "write heap profile to given file")
	portmap       = flag.Int("portmap", 0, "try to map this port on the firewall to the port on which flashlight is listening, using UPnP or NAT-PMP. If mapping this port fails, flashlight will exit with status code 50")
	frontFQDNs    = flag.String("frontfqdns", "", "YAML string representing a map from the name of each front provider to a FQDN that will reach this particular server via that provider (e.g. '{cloudflare: fl-001.getiantem.org, cloudfront: blablabla.cloudfront.net}')")
	waddelladdr   = flag.String("waddelladdr", "", "if specified, connect to this waddell server and process NAT traversal requests inbound from waddell")
	waddellcert   = flag.String("waddellcert", "", "if specified, use this cert (PEM-encoded) to authenticate connections to waddell.  Otherwise, a default certificate is used.")
	registerat    = flag.String("registerat", "", "base URL for peer DNS registry at which to register (e.g. https://peerscanner.getiantem.org)")
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

	var visitErr error

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
		case "waddellcert":
			updated.WaddellCert = *waddellcert

			// Stats
		case "statsperiod":
			updated.Stats.ReportingPeriod = time.Duration(*statsPeriod) * time.Second
		case "statshub":
			updated.Stats.StatshubAddr = *statshubAddr

		// Server
		case "portmap":
			updated.Server.Portmap = *portmap
		case "frontfqdns":
			fqdns, err := parseFrontFQDNs(*frontFQDNs)
			if err == nil {
				updated.Server.FrontFQDNs = fqdns
			} else {
				visitErr = err
			}
		case "registerat":
			updated.Server.RegisterAt = *registerat
		case "waddelladdr":
			updated.Server.WaddellAddr = *waddelladdr
		}
	})
	if visitErr != nil {
		return visitErr
	}
	// Settings that get set no matter what
	updated.CpuProfile = *cpuprofile
	updated.MemProfile = *memprofile
	updated.Server.Unencrypted = *unencrypted

	return nil
}

func parseFrontFQDNs(frontFQDNs string) (map[string]string, error) {
	fqdns := map[string]string{}
	if err := yaml.Unmarshal([]byte(frontFQDNs), fqdns); err != nil {
		return nil, err
	}
	return fqdns, nil
}
