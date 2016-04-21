package config

import (
	"crypto/x509"
	"encoding/base64"
	"fmt"
	"io/ioutil"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"

	"code.google.com/p/go-uuid/uuid"

	"github.com/getlantern/appdir"
	"github.com/getlantern/detour"
	"github.com/getlantern/fronted"
	"github.com/getlantern/golog"
	"github.com/getlantern/keyman"
	"github.com/getlantern/proxiedsites"
	"github.com/getlantern/yaml"
	"github.com/getlantern/yamlconf"

	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/util"
)

const (
	cloudfront             = "cloudfront"
	DefaultUpdateServerURL = "https://update.getlantern.org"
)

var (
	log = golog.LoggerFor("flashlight.config")
	m   *yamlconf.Manager
	r   = regexp.MustCompile("\\d+\\.\\d+")
)

type Config struct {
	configDir       string
	Version         int
	CloudConfig     string
	CloudConfigCA   string
	CpuProfile      string
	MemProfile      string
	UpdateServerURL string
	Client          *client.ClientConfig
	ProxiedSites    *proxiedsites.Config // List of proxied site domains that get routed through Lantern rather than accessed directly
	TrustedCAs      []*CA
}

// Fetcher is an interface for fetching config updates.
type Fetcher interface {
	pollForConfig(ycfg yamlconf.Config, sticky bool) (mutate func(yamlconf.Config) error, waitTime time.Duration, err error)
}

// StartPolling starts the process of polling for new configuration files.
func StartPolling() {
	// Force detour to whitelist chained domain
	u, err := url.Parse(chainedCloudConfigURL)
	if err != nil {
		log.Fatalf("Unable to parse chained cloud config URL: %v", err)
	}
	detour.ForceWhitelist(u.Host)

	// No-op if already started.
	m.StartPolling()
}

// CA represents a certificate authority
type CA struct {
	CommonName string
	Cert       string // PEM-encoded
}

func exists(file string) (os.FileInfo, bool) {
	if fi, err := os.Stat(file); os.IsNotExist(err) {
		log.Debugf("File does not exist at %v", file)
		return fi, false
	} else {
		log.Debugf("File exists at %v", file)
		return fi, true
	}
}

// hasCustomChainedServer returns whether or not the config file at the specified
// path includes a custom chained server or not.
func hasCustomChainedServer(configPath, name string) bool {
	if !(strings.HasPrefix(name, "lantern") && strings.HasSuffix(name, ".yaml")) {
		log.Debugf("File name does not match")
		return false
	}
	bytes, err := ioutil.ReadFile(configPath)
	if err != nil {
		log.Errorf("Could not read file %v", err)
		return false
	}
	cfg := &Config{}
	err = yaml.Unmarshal(bytes, cfg)
	if err != nil {
		log.Errorf("Could not unmarshal config %v", err)
		return false
	}

	nc := len(cfg.Client.ChainedServers)

	log.Debugf("Found %v chained servers in config on disk", nc)
	for _, v := range cfg.Client.ChainedServers {
		log.Debugf("chained server: %v", v)
	}
	// The config will have more than one but fewer than 10 chained servers
	// if it has been given a custom config with a custom chained server
	// list
	return nc > 0 && nc < 10
}

func isGoodConfig(configPath string) bool {
	log.Debugf("Checking config path: %v", configPath)
	fi, exists := exists(configPath)
	return exists && hasCustomChainedServer(configPath, fi.Name())
}

func majorVersion(version string) string {
	return r.FindString(version)
}

// Init initializes the configuration system.
//
// version - the version of lantern
// stickyConfig - if true, we ignore cloud updates
// flags - map of flags (generally from command-line) that always get applied
//         to the config.
func Init(userConfig UserConfig, version string, configDir string, stickyConfig bool, flags map[string]interface{}) (*Config, error) {
	// Request the config via either chained servers or direct fronted servers.
	cf := util.NewChainedAndFronted(client.Addr)
	fetcher := NewFetcher(userConfig, cf)

	file := "lantern-" + version + ".yaml"
	_, configPath, err := inConfigDir(configDir, file)
	if err != nil {
		log.Errorf("Could not get config path? %v", err)
		return nil, err
	}
	run := isGoodConfig(configPath)
	if !run {
		// If this is our first run of this version of Lantern, use the embedded configuration
		// file and use it to download our custom config file on this first poll for our
		// config.
		if err := MakeInitialConfig(configPath); err != nil {
			return nil, err
		}
	}

	m = &yamlconf.Manager{
		FilePath: configPath,
		EmptyConfig: func() yamlconf.Config {
			return &Config{configDir: configDir}
		},
		PerSessionSetup: func(ycfg yamlconf.Config) error {
			cfg := ycfg.(*Config)
			return cfg.applyFlags(flags)
		},
		CustomPoll: func(ycfg yamlconf.Config) (mutate func(yamlconf.Config) error, waitTime time.Duration, err error) {
			return fetcher.pollForConfig(ycfg, stickyConfig)
		},
	}
	initial, err := m.Init()

	var cfg *Config
	if err != nil {
		log.Errorf("Error initializing config: %v", err)
	} else {
		cfg = initial.(*Config)
	}
	log.Debug("Returning config")
	return cfg, err
}

// Run runs the configuration system.
func Run(updateHandler func(updated *Config)) error {
	for {
		next := m.Next()
		nextCfg := next.(*Config)
		updateHandler(nextCfg)
	}
}

// Update updates the configuration using the given mutator function.
func Update(mutate func(cfg *Config) error) error {
	return m.Update(func(ycfg yamlconf.Config) error {
		return mutate(ycfg.(*Config))
	})
}

func inConfigDir(configDir string, filename string) (string, string, error) {
	cdir := configDir

	if cdir == "" {
		cdir = appdir.General("Lantern")
	}

	log.Debugf("Using config dir %v", cdir)
	if _, err := os.Stat(cdir); err != nil {
		if os.IsNotExist(err) {
			// Create config dir
			if err := os.MkdirAll(cdir, 0750); err != nil {
				return "", "", fmt.Errorf("Unable to create configdir at %s: %s", cdir, err)
			}
		}
	}

	return cdir, filepath.Join(cdir, filename), nil
}

func (cfg *Config) GetTrustedCACerts() (pool *x509.CertPool, err error) {
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

// GetVersion implements the method from interface yamlconf.Config
func (cfg *Config) GetVersion() int {
	return cfg.Version
}

// SetVersion implements the method from interface yamlconf.Config
func (cfg *Config) SetVersion(version int) {
	cfg.Version = version
}

// applyFlags updates this Config from any command-line flags that were passed
// in.
func (updated *Config) applyFlags(flags map[string]interface{}) error {
	if updated.Client == nil {
		updated.Client = &client.ClientConfig{}
	}

	var visitErr error

	// Visit all flags that have been set and copy to config
	for key, value := range flags {
		switch key {
		// General
		case "cloudconfig":
			updated.CloudConfig = value.(string)
		case "cloudconfigca":
			updated.CloudConfigCA = value.(string)
		case "instanceid":
			updated.Client.DeviceID = value.(string)
		case "cpuprofile":
			updated.CpuProfile = value.(string)
		case "memprofile":
			updated.MemProfile = value.(string)
		}
	}
	if visitErr != nil {
		return visitErr
	}

	return nil
}

// ApplyDefaults implements the method from interface yamlconf.Config
//
// ApplyDefaults populates default values on a Config to make sure that we have
// a minimum viable config for running.  As new settings are added to
// flashlight, this function should be updated to provide sensible defaults for
// those settings.
func (cfg *Config) ApplyDefaults() {
	if cfg.UpdateServerURL == "" {
		cfg.UpdateServerURL = "https://update.getlantern.org"
	}

	if cfg.CloudConfig == "" {
		cfg.CloudConfig = chainedCloudConfigURL
	}

	if cfg.Client == nil {
		cfg.Client = &client.ClientConfig{}
	}

	cfg.applyClientDefaults()

	if cfg.ProxiedSites == nil {
		log.Debugf("Adding empty proxiedsites")
		cfg.ProxiedSites = &proxiedsites.Config{
			Delta: &proxiedsites.Delta{
				Additions: []string{},
				Deletions: []string{},
			},
			Cloud: []string{},
		}
	}

	if cfg.ProxiedSites.Cloud == nil || len(cfg.ProxiedSites.Cloud) == 0 {
		log.Debugf("Loading default cloud proxiedsites")
		cfg.ProxiedSites.Cloud = defaultProxiedSites
	}

	if cfg.TrustedCAs == nil || len(cfg.TrustedCAs) == 0 {
		cfg.TrustedCAs = defaultTrustedCAs
	}
}

func (cfg *Config) applyClientDefaults() {
	// Make sure we always have at least one masquerade set
	if cfg.Client.MasqueradeSets == nil {
		cfg.Client.MasqueradeSets = make(map[string][]*fronted.Masquerade)
	}
	if len(cfg.Client.MasqueradeSets) == 0 {
		cfg.Client.MasqueradeSets[cloudfront] = cloudfrontMasquerades
	}

	// Always make sure we have a map of ChainedServers
	if cfg.Client.ChainedServers == nil {
		cfg.Client.ChainedServers = make(map[string]*client.ChainedServerInfo)
	}

	// Make sure we always have at least one server
	if len(cfg.Client.ChainedServers) == 0 {
		cfg.Client.ChainedServers = make(map[string]*client.ChainedServerInfo, len(fallbacks))
		for key, fb := range fallbacks {
			cfg.Client.ChainedServers[key] = fb
		}
	}

	if cfg.Client.ProxiedCONNECTPorts == nil {
		cfg.Client.ProxiedCONNECTPorts = []int{
			// Standard HTTP(S) ports
			80, 443,
			// Common unprivileged HTTP(S) ports
			8080, 8443,
			// XMPP
			5222, 5223, 5224,
			// Android
			5228, 5229,
			// udpgw
			7300,
			// Google Hangouts TCP Ports (see https://support.google.com/a/answer/1279090?hl=en)
			19305, 19306, 19307, 19308, 19309,
		}
	}

	if cfg.Client.DeviceID == "" {
		// There is no true privacy or security in instance ID.  For that, we rely on
		// transport security.  Hashing MAC would buy us nothing, since the space of
		// MACs is trivially mapped, especially since the salt would be known
		cfg.Client.DeviceID = base64.StdEncoding.EncodeToString(uuid.NodeID())
	}

}

// updateFrom creates a new Config by 'merging' the given yaml into this Config.
// The masquerade sets, the collections of servers, and the trusted CAs in the
// update yaml  completely replace the ones in the original Config.
func (updated *Config) updateFrom(updateBytes []byte) error {
	// XXX: does this need a mutex, along with everyone that uses the config?
	oldDeviceID := updated.Client.DeviceID
	oldChainedServers := updated.Client.ChainedServers
	oldMasqueradeSets := updated.Client.MasqueradeSets
	oldTrustedCAs := updated.TrustedCAs
	updated.Client.ChainedServers = map[string]*client.ChainedServerInfo{}
	updated.Client.MasqueradeSets = map[string][]*fronted.Masquerade{}
	updated.TrustedCAs = []*CA{}
	err := yaml.Unmarshal(updateBytes, updated)
	if err != nil {
		updated.Client.ChainedServers = oldChainedServers
		updated.Client.MasqueradeSets = oldMasqueradeSets
		updated.TrustedCAs = oldTrustedCAs
		return fmt.Errorf("Unable to unmarshal YAML for update: %s", err)
	}
	// Deduplicate global proxiedsites
	if len(updated.ProxiedSites.Cloud) > 0 {
		wlDomains := make(map[string]bool)
		for _, domain := range updated.ProxiedSites.Cloud {
			wlDomains[domain] = true
		}
		updated.ProxiedSites.Cloud = make([]string, 0, len(wlDomains))
		for domain := range wlDomains {
			updated.ProxiedSites.Cloud = append(updated.ProxiedSites.Cloud, domain)
		}
		sort.Strings(updated.ProxiedSites.Cloud)
	}

	// Ignore DeviceID from yaml
	updated.Client.DeviceID = oldDeviceID
	return nil
}
