package config

import (
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"time"

	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/proxied"
	"github.com/getlantern/golog"
	"github.com/getlantern/rot13"
	"github.com/getlantern/tarfs"
	"github.com/getlantern/yaml"
)

var (
	log = golog.LoggerFor("flashlight.config")

	// GlobalURLs are the chained and fronted URLs for fetching the global config.
	GlobalURLs = &ChainedFrontedURLs{
		Chained: "https://globalconfig.flashlightproxy.com/global.yaml.gz",
		Fronted: "https://d24ykmup0867cj.cloudfront.net/global.yaml.gz",
	}

	// GlobalStagingURLs are the chained and fronted URLs for fetching the global
	// config in a staging environment.
	GlobalStagingURLs = &ChainedFrontedURLs{
		Chained: "https://globalconfig.flashlightproxy.com/global.yaml.gz",
		Fronted: "https://d24ykmup0867cj.cloudfront.net/global.yaml.gz",
	}

	// The following are over HTTP because proxies do not forward X-Forwarded-For
	// with HTTPS and because we only support falling back to direct domain
	// fronting through the local proxy for HTTP.

	// ProxiesURLs are the chained and fronted URLs for fetching the per user
	// proxy config.
	ProxiesURLs = &ChainedFrontedURLs{
		Chained: "http://config.getiantem.org/proxies.yaml.gz",
		Fronted: "http://d2wi0vwulmtn99.cloudfront.net/proxies.yaml.gz",
	}

	// ProxiesStagingURLs are the chained and fronted URLs for fetching the per user
	// proxy config in a staging environment.
	ProxiesStagingURLs = &ChainedFrontedURLs{
		Chained: "http://config-staging.getiantem.org/proxies.yaml.gz",
		Fronted: "http://d33pfmbpauhmvd.cloudfront.net/proxies.yaml.gz",
	}
)

// Config is an interface for getting proxy data saved locally, embedded
// in the binary, or fetched over the network.
type Config interface {

	// Saved returns a yaml config from disk.
	Saved() (interface{}, error)

	// Embedded retrieves a yaml config embedded in the binary.
	Embedded([]byte, string) (interface{}, error)

	// Poll polls for new configs from a remote server and saves them to disk for
	// future runs.
	Poll(UserConfig, chan interface{}, *ChainedFrontedURLs, time.Duration)
}

type config struct {
	filePath  string
	obfuscate bool
	saveChan  chan interface{}
	factory   func() interface{}
}

// ChainedFrontedURLs contains a chained and a fronted URL for fetching a config.
type ChainedFrontedURLs struct {
	Chained string
	Fronted string
}

// NewConfig create a new ProxyConfig instance that saves and looks for
// saved data at the specified path.
func NewConfig(filePath string, obfuscate bool,
	factory func() interface{}) Config {
	pc := &config{
		filePath:  filePath,
		obfuscate: obfuscate,
		saveChan:  make(chan interface{}),
		factory:   factory,
	}

	// Start separate go routine that saves newly fetched proxies to disk.
	go pc.save()
	return pc
}

// PipeConfig creates a new config pipeline for reading a specified type of
// config onto a channel for processing by a dispatch function.
func PipeConfig(configDir string, flags map[string]interface{},
	name string, urls *ChainedFrontedURLs, userConfig UserConfig,
	factory func() interface{}, dispatch func(cfg interface{}),
	data []byte, sleep time.Duration) {

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
	conf := NewConfig(configPath, obfs, factory)

	if saved, proxyErr := conf.Saved(); proxyErr != nil {
		log.Debugf("Could not load stored config %v", proxyErr)
		if embedded, errr := conf.Embedded(data, name); errr != nil {
			log.Errorf("Could not load embedded config %v", errr)
		} else {
			configChan <- embedded
		}
	} else {
		configChan <- saved
	}
	go conf.Poll(userConfig, configChan, urls, sleep)
}

func obfuscate(flags map[string]interface{}) bool {
	return flags["readableconfig"] == nil || !flags["readableconfig"].(bool)
}

func (conf *config) Saved() (interface{}, error) {
	infile, err := os.Open(conf.filePath)
	if err != nil {
		return nil, fmt.Errorf("Unable to open config file %v for reading: %v", conf.filePath, err)
	}
	defer infile.Close()

	var in io.Reader = infile
	if conf.obfuscate {
		in = rot13.NewReader(infile)
	}

	bytes, err := ioutil.ReadAll(in)
	if err != nil {
		return nil, fmt.Errorf("Error reading config from %v: %v", conf.filePath, err)
	}

	log.Debugf("Returning saved config at %v", conf.filePath)
	return conf.unmarshall(bytes)
}

func (conf *config) Embedded(data []byte, fileName string) (interface{}, error) {
	fs, err := tarfs.New(data, "")
	if err != nil {
		log.Errorf("Could not read resources? %v", err)
		return nil, err
	}

	// Get the yaml file from either the local file system or from an
	// embedded resource, but ignore local file system files if they're
	// empty.
	bytes, err := fs.GetIgnoreLocalEmpty(fileName)
	if err != nil {
		log.Errorf("Could not read embedded proxies %v", err)
		return nil, err
	}

	return conf.unmarshall(bytes)
}

func (conf *config) Poll(uc UserConfig,
	proxyChan chan interface{}, urls *ChainedFrontedURLs, sleep time.Duration) {
	fetcher := newFetcher(uc, proxied.ParallelPreferChained(), urls)

	for {
		if bytes, err := fetcher.fetch(); err != nil {
			log.Errorf("Could not read fetched config %v", err)
		} else if bytes == nil {
			// This is what fetcher returns for not-modified.
			log.Debug("Ignoring not modified response")
		} else if servers, err := conf.unmarshall(bytes); err != nil {
			log.Errorf("Error fetching config: %v", err)
		} else {
			log.Debugf("Fetched config! %v", servers)

			// Push these to channels to avoid race conditions that might occur if
			// we did these on go routines, for example.
			proxyChan <- servers
			conf.saveChan <- servers
		}
		time.Sleep(sleep)
	}
}

func (conf *config) unmarshall(bytes []byte) (interface{}, error) {
	cfg := conf.factory()
	if err := yaml.Unmarshal(bytes, cfg); err != nil {
		return nil, fmt.Errorf("Error unmarshaling config yaml from %v: %v", string(bytes), err)
	}
	return cfg, nil
}

func (conf *config) save() {
	for {
		in := <-conf.saveChan
		if err := conf.saveOne(in); err != nil {
			log.Errorf("Could not save %v, %v", in, err)
		}
	}
}

func (conf *config) saveOne(in interface{}) error {
	bytes, err := yaml.Marshal(in)
	if err != nil {
		return fmt.Errorf("Unable to marshal config yaml: %v", err)
	}

	outfile, err := os.OpenFile(conf.filePath, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0644)
	if err != nil {
		return fmt.Errorf("Unable to open file %v for writing: %v", conf.filePath, err)
	}
	defer outfile.Close()

	var out io.Writer = outfile
	if conf.obfuscate {
		out = rot13.NewWriter(outfile)
	}
	_, err = out.Write(bytes)
	if err != nil {
		return fmt.Errorf("Unable to write yaml to file %v: %v", conf.filePath, err)
	}
	log.Debugf("Wrote file at %v", conf.filePath)
	return nil
}

// GetProxyURLs returns the proxy URLs to use depending on whether or not we're in
// staging.
func GetProxyURLs(staging bool) *ChainedFrontedURLs {
	if staging {
		log.Debug("Configuring for staging")
		return ProxiesStagingURLs
	}
	log.Debugf("Not configuring for staging.")
	return ProxiesURLs
}

// GetGlobalURLs returns the global URLs to use depending on whether or not we're in
// staging.
func GetGlobalURLs(staging bool) *ChainedFrontedURLs {
	if staging {
		log.Debug("Configuring for staging")
		return GlobalStagingURLs
	}
	log.Debugf("Not configuring for staging.")
	return GlobalURLs
}
