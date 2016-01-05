package config

import (
	"compress/gzip"
	"crypto/x509"
	"fmt"
	"io/ioutil"
	"math/rand"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"sort"
	"strings"
	"time"

	"github.com/getlantern/appdir"
	"github.com/getlantern/fronted"
	"github.com/getlantern/golog"
	"github.com/getlantern/keyman"
	"github.com/getlantern/proxiedsites"
	"github.com/getlantern/yaml"
	"github.com/getlantern/yamlconf"

	chained "github.com/getlantern/flashlight/client/chained"
	clientconfig "github.com/getlantern/flashlight/client/config"
	cfronted "github.com/getlantern/flashlight/client/fronted"

	"github.com/getlantern/flashlight/server"
	"github.com/getlantern/flashlight/statreporter"
	"github.com/getlantern/flashlight/util"
)

var (
	chainedCloudConfigUrl = "http://config.getiantem.org/cloud.yaml.gz"
)

const (
	CloudConfigPollInterval = 1 * time.Minute
	cloudfront              = "cloudfront"
	etag                    = "X-Lantern-Etag"
	ifNoneMatch             = "X-Lantern-If-None-Match"

	// This is over HTTP because proxies do not forward X-Forwarded-For with HTTPS
	// and because we only support falling back to direct domain fronting through
	// the local proxy for HTTP.
	frontedCloudConfigUrl = "http://d2wi0vwulmtn99.cloudfront.net/cloud.yaml.gz"
)

var (
	log                 = golog.LoggerFor("flashlight.config")
	m                   *yamlconf.Manager
	lastCloudConfigETag = map[string]string{}
	r                   = regexp.MustCompile("\\d+\\.\\d+")
	// Request the config via either chained servers or direct fronted servers.
	cf      = util.NewChainedAndFronted()
	doneCfg = make(chan bool, 2)
)

type Config struct {
	Version       int
	CloudConfig   string
	CloudConfigCA string
	Addr          string
	Role          string
	CpuProfile    string
	MemProfile    string
	UIAddr        string // UI HTTP server address
	Stats         *statreporter.Config
	Server        *server.ServerConfig
	Client        *clientconfig.ClientConfig
	ProxiedSites  *proxiedsites.Config // List of proxied site domains that get routed through Lantern rather than accessed directly
	TrustedCAs    []*CA
}

func init() {
	if runtime.GOOS == "android" {
		chainedCloudConfigUrl = "http://config.getiantem.org/cloud-android.yaml.gz"
	} else {
		chainedCloudConfigUrl = "http://config.getiantem.org/cloud.yaml.gz"

	}
}

// StartPolling starts the process of polling for new configuration files.
func StartPolling() {
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

	log.Debugf("Found %v chained servers", nc)
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

// useGoodOldConfig is a one-time function for using older config files in the 2.x series.
// It returns true if the file specified by configPath is ready, false otherwise.
func useGoodOldConfig(configDir, configPath string) bool {
	// If we already have a config file with the latest name, use that one.
	// Otherwise, copy the most recent config file available.
	exists := isGoodConfig(configPath)
	if exists {
		log.Debugf("Using existing config")
		return true
	}

	files, err := ioutil.ReadDir(configDir)
	if err != nil {
		log.Errorf("Could not read config dir: %v", err)
		return false
	}

	for _, file := range files {
		if file.IsDir() {
			continue
		}
		name := file.Name()
		path := filepath.Join(configDir, name)
		if isGoodConfig(path) {
			// Just use the old config since configs in the 2.x series haven't changed.
			if err := os.Rename(path, configPath); err != nil {
				log.Errorf("Could not rename file from %v to %v: %v", path, configPath, err)
			} else {
				log.Debugf("Copied old config at %v to %v", path, configPath)
				return true
			}
		}
	}
	return false
}

// Init initializes the configuration system.
func Init(version string) (*Config, error) {
	file := "lantern-" + version + ".yaml"
	_, configPath, err := InConfigDir(file)
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
			log.Errorf("Could not load initial config file: %v", err)
			return nil, err
		}
	}

	m = &yamlconf.Manager{
		FilePath: configPath,
		EmptyConfig: func() yamlconf.Config {
			return &Config{}
		},
		PerSessionSetup: func(ycfg yamlconf.Config) error {
			cfg := ycfg.(*Config)
			return cfg.applyFlags()
		},
		CustomPoll: func(ycfg yamlconf.Config) (mutate func(yamlconf.Config) error, waitTime time.Duration, err error) {
			return pollForConfig(ycfg)
		},
	}
	initial, err := m.Init()

	var cfg *Config
	if err != nil {
		log.Errorf("Error initializing config: %v", err)
	} else {
		cfg = initial.(*Config)
	}
	log.Debugf("Returning config")
	return cfg, err
}

func pollForConfig(currentCfg yamlconf.Config) (mutate func(yamlconf.Config) error, waitTime time.Duration, err error) {
	log.Debugf("Polling for config")
	// By default, do nothing
	mutate = func(ycfg yamlconf.Config) error {
		// do nothing
		return nil
	}
	cfg := currentCfg.(*Config)
	waitTime = cfg.cloudPollSleepTime()
	if cfg.CloudConfig == "" {
		log.Debugf("No cloud config URL!")
		// Config doesn't have a CloudConfig, just ignore
		return mutate, waitTime, nil
	}
	if *stickyConfig {
		log.Debugf("Not downloading remote config with sticky config flag set")
		return mutate, waitTime, nil
	}

	if bytes, err := fetchCloudConfig(chainedCloudConfigUrl); err == nil {
		// bytes will be nil if the config is unchanged (not modified)
		if bytes != nil {
			//log.Debugf("Downloaded config:\n %v", string(bytes))
			mutate = func(ycfg yamlconf.Config) error {
				log.Debugf("Merging cloud configuration")
				cfg := ycfg.(*Config)
				return cfg.updateFrom(bytes)
			}
		}
	} else {
		log.Errorf("Could not fetch cloud config %v", err)
		return mutate, waitTime, err
	}
	return mutate, waitTime, nil
}

// Run runs the configuration system.
func Run(updateHandler func(updated *Config)) error {
	for {
		select {
		case next := <-m.NextCh():
			nextCfg := next.(*Config)
			updateHandler(nextCfg)
		case <-doneCfg:
			log.Debugf("Closing config system")
			return nil
		}
	}
}

func Exit() {
	m.Exit()
	doneCfg <- true
}

// Update updates the configuration using the given mutator function.
func Update(mutate func(cfg *Config) error) error {
	return m.Update(func(ycfg yamlconf.Config) error {
		return mutate(ycfg.(*Config))
	})
}

// InConfigDir returns the path to the given filename inside of the configdir.
func InConfigDir(filename string) (string, string, error) {
	cdir := *configdir

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

// ApplyDefaults implements the method from interface yamlconf.Config
//
// ApplyDefaults populates default values on a Config to make sure that we have
// a minimum viable config for running.  As new settings are added to
// flashlight, this function should be updated to provide sensible defaults for
// those settings.
func (cfg *Config) ApplyDefaults() {
	if cfg.Role == "" {
		cfg.Role = "client"
	}

	if cfg.Addr == "" {
		cfg.Addr = "127.0.0.1:8787"
	}

	if cfg.UIAddr == "" {
		cfg.UIAddr = "127.0.0.1:16823"
	}

	if cfg.CloudConfig == "" {
		cfg.CloudConfig = chainedCloudConfigUrl
	}

	// Make sure we always have a stats config
	if cfg.Stats == nil {
		cfg.Stats = &statreporter.Config{}
	}

	if cfg.Stats.StatshubAddr == "" {
		cfg.Stats.StatshubAddr = *statshubAddr
	}

	if cfg.Client != nil && cfg.Role == "client" {
		cfg.applyClientDefaults()
	}

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

	// Make sure we always have at least one server
	if cfg.Client.FrontedServers == nil {
		cfg.Client.FrontedServers = make([]*cfronted.FrontedServerInfo, 0)
	}
	if len(cfg.Client.FrontedServers) == 0 && len(cfg.Client.ChainedServers) == 0 {
		cfg.Client.ChainedServers = make(map[string]*chained.ChainedServerInfo, len(fallbacks))
		for key, fb := range fallbacks {
			cfg.Client.ChainedServers[key] = fb
		}
	}

	// Make sure all servers have a QOS and Weight configured
	for _, server := range cfg.Client.FrontedServers {
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

	// Always make sure we have a map of ChainedServers
	if cfg.Client.ChainedServers == nil {
		cfg.Client.ChainedServers = make(map[string]*chained.ChainedServerInfo)
	}

	// Sort servers so that they're always in a predictable order
	cfg.Client.SortServers()

}

func (cfg *Config) IsDownstream() bool {
	return cfg.Role == "client"
}

func (cfg *Config) IsUpstream() bool {
	return !cfg.IsDownstream()
}

func (cfg Config) cloudPollSleepTime() time.Duration {
	return time.Duration((CloudConfigPollInterval.Nanoseconds() / 2) + rand.Int63n(CloudConfigPollInterval.Nanoseconds()))
}

func fetchCloudConfig(url string) ([]byte, error) {
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, fmt.Errorf("Unable to construct request for cloud config at %s: %s", url, err)
	}
	if lastCloudConfigETag[url] != "" {
		// Don't bother fetching if unchanged
		req.Header.Set(ifNoneMatch, lastCloudConfigETag[url])
	}

	req.Header.Set("Accept", "application/x-gzip")
	// Prevents intermediate nodes (domain-fronters) from caching the content
	req.Header.Set("Cache-Control", "no-cache")
	// Set the fronted URL to lookup the config in parallel using chained and domain fronted servers.
	req.Header.Set("Lantern-Fronted-URL", frontedCloudConfigUrl)

	// make sure to close the connection after reading the Body
	// this prevents the occasional EOFs errors we're seeing with
	// successive requests
	req.Close = true

	resp, err := cf.Do(req)
	if err != nil {
		return nil, fmt.Errorf("Unable to fetch cloud config at %s: %s", url, err)
	}
	defer func() {
		if err := resp.Body.Close(); err != nil {
			log.Debugf("Error closing response body: %v", err)
		}
	}()

	if resp.StatusCode == 304 {
		log.Debugf("Config unchanged in cloud")
		return nil, nil
	} else if resp.StatusCode != 200 {
		return nil, fmt.Errorf("Unexpected response status: %d", resp.StatusCode)
	}

	lastCloudConfigETag[url] = resp.Header.Get(etag)
	gzReader, err := gzip.NewReader(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("Unable to open gzip reader: %s", err)
	}
	log.Debugf("Fetched cloud config")
	return ioutil.ReadAll(gzReader)
}

// updateFrom creates a new Config by 'merging' the given yaml into this Config.
// The masquerade sets, the collections of servers, and the trusted CAs in the
// update yaml  completely replace the ones in the original Config.
func (updated *Config) updateFrom(updateBytes []byte) error {
	// XXX: does this need a mutex, along with everyone that uses the config?
	oldFrontedServers := updated.Client.FrontedServers
	oldChainedServers := updated.Client.ChainedServers
	oldMasqueradeSets := updated.Client.MasqueradeSets
	oldTrustedCAs := updated.TrustedCAs
	updated.Client.FrontedServers = []*cfronted.FrontedServerInfo{}
	updated.Client.ChainedServers = map[string]*chained.ChainedServerInfo{}
	updated.Client.MasqueradeSets = map[string][]*fronted.Masquerade{}
	updated.TrustedCAs = []*CA{}
	err := yaml.Unmarshal(updateBytes, updated)
	if err != nil {
		updated.Client.FrontedServers = oldFrontedServers
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
		for domain, _ := range wlDomains {
			updated.ProxiedSites.Cloud = append(updated.ProxiedSites.Cloud, domain)
		}
		sort.Strings(updated.ProxiedSites.Cloud)
	}
	return nil
}
