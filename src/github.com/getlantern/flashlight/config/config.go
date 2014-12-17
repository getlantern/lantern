package config

import (
	"flag"
	"fmt"
	"io/ioutil"
	"os"
	"reflect"
	"time"

	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/log"
	"gopkg.in/getlantern/deepcopy.v1"
	"gopkg.in/getlantern/yaml.v1"
)

const (
	CF = "cloudflare"
)

type Config struct {
	CloudConfig    string
	CloudConfigCA  string
	Addr           string
	Portmap        int
	Role           string
	AdvertisedHost string
	StatsPeriod    time.Duration
	StatshubAddr   string
	InstanceId     string
	Country        string
	StatsAddr      string
	CpuProfile     string
	MemProfile     string
	Client         *client.ClientConfig
	filename       string
	lastFileInfo   os.FileInfo
}

var (
	// Flags
	configDir      = flag.String("configdir", "", "directory in which to store configuration, including flashlight.yaml (defaults to current directory)")
	cloudConfig    = flag.String("cloudconfig", "", "optional http(s) URL to a cloud-based source for configuration updates")
	cloudConfigCA  = flag.String("cloudconfigca", "", "optional PEM encoded certificate used to verify TLS connections to fetch cloudconfig")
	addr           = flag.String("addr", "", "ip:port on which to listen for requests. When running as a client proxy, we'll listen with http, when running as a server proxy we'll listen with https (required)")
	portmap        = flag.Int("portmap", 0, "try to map this port on the firewall to the port on which flashlight is listening, using UPnP or NAT-PMP. If mapping this port fails, flashlight will exit with status code 50")
	role           = flag.String("role", "", "either 'client' or 'server' (required)")
	advertisedHost = flag.String("server", "", "FQDN of flashlight server when running in server mode (required)")
	statsPeriod    = flag.Int("statsperiod", 0, "time in seconds to wait between reporting stats. If not specified, stats are not reported. If specified, statshub, instanceid and statsaddr must also be specified.")
	statshubAddr   = flag.String("statshub", "pure-journey-3547.herokuapp.com", "address of statshub server")
	instanceId     = flag.String("instanceid", "", "instanceId under which to report stats to statshub")
	country        = flag.String("country", "xx", "2 digit country code under which to report stats. Defaults to xx.")
	statsAddr      = flag.String("statsaddr", "", "host:port at which to make detailed stats available using server-sent events (optional)")
	cpuProfile     = flag.String("cpuprofile", "", "write cpu profile to given file")
	memProfile     = flag.String("memprofile", "", "write heap profile to given file")
)

// ApplyFlags updates this Config from any command-line flags that were passed
// in. ApplyFlags assumes that flag.Parse() has already been called.
func (orig *Config) ApplyFlags() *Config {
	updated := orig.deepCopy()
	updated.CloudConfig = *cloudConfig
	updated.CloudConfigCA = *cloudConfigCA
	updated.Addr = *addr
	updated.Portmap = *portmap
	updated.Role = *role
	updated.AdvertisedHost = *advertisedHost
	updated.StatsPeriod = time.Duration(*statsPeriod) * time.Second
	updated.StatshubAddr = *statshubAddr
	updated.InstanceId = *instanceId
	updated.Country = *country
	updated.StatsAddr = *statsAddr
	updated.CpuProfile = *cpuProfile
	updated.MemProfile = *memProfile
	updated.applyDefaults()
	return updated
}

// LoadFromDisk loads a Config from flashlight.yaml inside the configured
// configDir with default values populated as necessary. If the file couldn't be
// loaded for some reason, this function returns a new default Config. This
// function assumes that flag.Parse() has already been called.
func LoadFromDisk() (*Config, error) {
	filename := InConfigDir("flashlight.yaml")
	log.Debugf("Loading config from: %s", filename)

	cfg := &Config{filename: filename}
	fileInfo, err := os.Stat(filename)
	if err != nil {
		err = fmt.Errorf("Unable to stat config file %s: %s", filename, err)
	} else {
		cfg.lastFileInfo = fileInfo
		bytes, err := ioutil.ReadFile(filename)
		if err != nil {
			err = fmt.Errorf("Error reading config from %s: %s", filename, err)
		} else {
			err = yaml.Unmarshal(bytes, cfg)
			if err != nil {
				err = fmt.Errorf("Error unmarshaling config yaml from file %s: %s", filename, err)
			}
		}
	}
	cfg.applyDefaults()
	return cfg, err
}

// SaveToDisk saves this Config to the file from which it was loaded.
func (cfg *Config) SaveToDisk() error {
	bytes, err := yaml.Marshal(cfg)
	if err != nil {
		return fmt.Errorf("Unable to marshal config yaml: %s", err)
	}
	err = ioutil.WriteFile(cfg.filename, bytes, 0644)
	if err != nil {
		return fmt.Errorf("Unable to write config yaml to file %s: %s", cfg.filename, err)
	}
	cfg.lastFileInfo, err = os.Stat(cfg.filename)
	if err != nil {
		return fmt.Errorf("Unable to stat file %s: %s", cfg.filename, err)
	}
	return nil
}

// HasChangedOnDisk checks whether Config has changed on disk
func (cfg *Config) HasChangedOnDisk() bool {
	nextFileInfo, err := os.Stat(cfg.filename)
	if err != nil {
		return false
	}
	hasChanged := cfg.lastFileInfo == nil
	if !hasChanged {
		hasChanged = nextFileInfo.Size() != cfg.lastFileInfo.Size() || nextFileInfo.ModTime() != cfg.lastFileInfo.ModTime()
	}
	return hasChanged
}

// UpdatedFrom creates a new Config by merging the given yaml into this Config.
// Any servers in the updated yaml replace ones in the original Config and any
// masquerade sets in the updated yaml replace ones in the original Config.
func (orig *Config) UpdatedFrom(updateBytes []byte) (*Config, error) {
	origCopy := orig.deepCopy()
	updated := orig.deepCopy()
	err := yaml.Unmarshal(updateBytes, updated)
	if err != nil {
		return nil, fmt.Errorf("Unable to unmarshal YAML for update: %s", err)
	}
	// Need to de-duplicate servers, since yaml appends them
	servers := make(map[string]*client.ServerInfo)
	for _, server := range updated.Client.Servers {
		servers[server.Host] = server
	}
	updated.Client.Servers = make([]*client.ServerInfo, len(servers))
	i := 0
	for _, server := range servers {
		updated.Client.Servers[i] = server
		i = i + 1
	}
	origCopy.Client.SortServers()
	updated.Client.SortServers()
	if !reflect.DeepEqual(origCopy, updated) {
		log.Debugf("Saving updated")
		err = updated.SaveToDisk()
		if err != nil {
			return nil, err
		}
	}
	return updated, nil
}

func (cfg *Config) IsDownstream() bool {
	return cfg.Role == "client"
}

func (cfg *Config) IsUpstream() bool {
	return !cfg.IsDownstream()
}

// InConfigDir returns the path to the given filename inside of the configDir.
func InConfigDir(filename string) string {
	if *configDir == "" {
		return filename
	} else {
		if _, err := os.Stat(*configDir); err != nil {
			if os.IsNotExist(err) {
				// Create config dir
				if err := os.MkdirAll(*configDir, 0755); err != nil {
					log.Fatalf("Unable to create configDir at %s: %s", *configDir, err)
				}
			}
		}
		return fmt.Sprintf("%s%c%s", *configDir, os.PathSeparator, filename)
	}
}

// applyDefaults populates default values on a Config to make sure that we have
// a minimum viable config for running.  As new settings are added to
// flashlight, this function should be updated to provide sensible defaults for
// those settings.
func (cfg *Config) applyDefaults() {
	// Default country
	if cfg.Country == "" {
		cfg.Country = "xx"
	}

	// Make sure we always have a Client config
	if cfg.Client == nil {
		cfg.Client = &client.ClientConfig{}
	}

	// Make sure we always have at least one masquerade set
	if cfg.Client.MasqueradeSets == nil {
		cfg.Client.MasqueradeSets = make(map[string][]*client.Masquerade)
	}
	if len(cfg.Client.MasqueradeSets) == 0 {
		cfg.Client.MasqueradeSets[CF] = cloudflareMasquerades
	}

	// Make sure we always have at least one server
	if cfg.Client.Servers == nil {
		cfg.Client.Servers = make([]*client.ServerInfo, 0)
	}
	if len(cfg.Client.Servers) == 0 {
		cfg.Client.Servers = append(cfg.Client.Servers, &client.ServerInfo{
			Host:          "roundrobin.getiantem.org",
			Port:          443,
			MasqueradeSet: CF,
			QOS:           10,
			Weight:        1000000,
		})
	}

	// Make sure all servers have a QOS and Weight configured
	for _, server := range cfg.Client.Servers {
		if server.QOS == 0 {
			server.QOS = 5
		}
		if server.Weight == 0 {
			server.Weight = 100
		}
		if server.RedialAttempts == 0 {
			server.RedialAttempts = 2
		}
	}
}

func (cfg *Config) deepCopy() *Config {
	copy := &Config{}
	err := deepcopy.Copy(copy, cfg)
	if err != nil {
		panic(err)
	}
	copy.filename = cfg.filename
	copy.lastFileInfo = cfg.lastFileInfo
	return copy
}
