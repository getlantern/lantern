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
	saved() (interface{}, error)

	// Embedded retrieves a yaml config embedded in the binary.
	embedded([]byte, string) (interface{}, error)

	// Poll polls for new configs from a remote server and saves them to disk for
	// future runs.
	poll(UserConfig, chan interface{}, *ChainedFrontedURLs, time.Duration)
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

// Options specifies the options to use for piping config data back to the
// dispatch processor function.
type Options struct {

	// SaveDir is the directory where we should save new configs and also look
	// for existing saved configs.
	SaveDir string

	// Obfuscate specifies whether or not to obfuscate the config on disk.
	Obfuscate bool

	// Name specifies the name of the config file both on disk and in the
	// embedded config that uses tarfs (the same in the interest of using
	// configuration by convention).
	Name string

	// URLs are the chaines and fronted URLs to use for fetching this config.
	URLs *ChainedFrontedURLs

	// UserConfig contains data for communicating the user details to upstream
	// servers in HTTP headers, such as the pro token.
	UserConfig UserConfig

	// YAMLTemplater is a factory method for generating structs that will be used
	// when unmarshalling yaml data.
	YAMLTemplater func() interface{}

	// Dispatch is essentially a callback function for processing retrieved
	// yaml configs.
	Dispatch func(cfg interface{})

	// EmbeddedData is the data for embedded configs, using tarfs.
	EmbeddedData []byte

	// Sleep the time to sleep between config fetches.
	Sleep time.Duration
}

// PipeConfig creates a new config pipeline for reading a specified type of
// config onto a channel for processing by a dispatch function. This will read
// configs in the following order:
//
// 1. Configs saved on disk, if any
// 2. Configs embedded in the binary according to the specified name, if any.
// 3. Configs fetched remotely, and those will be piped back over and over
//   again as the remote configs change (but only if they change).
func PipeConfig(opts *Options) {

	configChan := make(chan interface{})

	go func() {
		for {
			cfg := <-configChan
			opts.Dispatch(cfg)
		}
	}()
	configPath, err := client.InConfigDir(opts.SaveDir, opts.Name)
	if err != nil {
		log.Errorf("Could not get config path? %v", err)
	}

	log.Tracef("Obfuscating %v", opts.Obfuscate)
	conf := newConfig(configPath, opts.Obfuscate, opts.YAMLTemplater)

	if saved, proxyErr := conf.saved(); proxyErr != nil {
		log.Debugf("Could not load stored config %v", proxyErr)
		if embedded, errr := conf.embedded(opts.EmbeddedData, opts.Name); errr != nil {
			log.Errorf("Could not load embedded config %v", errr)
		} else {
			log.Debugf("Sending embedded config for %v", name)
			configChan <- embedded
		}
	} else {
		log.Debugf("Sending saved config for %v", name)
		configChan <- saved
	}

	// Now continually poll for new configs and pipe them back to the dispatch
	// function.
	go conf.poll(opts.UserConfig, configChan, opts.URLs, opts.Sleep)
}

// newConfig create a new ProxyConfig instance that saves and looks for
// saved data at the specified path.
func newConfig(filePath string, obfuscate bool,
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

func (conf *config) saved() (interface{}, error) {
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

	log.Tracef("Returning saved config at %v", conf.filePath)
	return conf.unmarshall(bytes)
}

func (conf *config) embedded(data []byte, fileName string) (interface{}, error) {
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

func (conf *config) poll(uc UserConfig,
	configChan chan interface{}, urls *ChainedFrontedURLs, sleep time.Duration) {
	fetcher := newFetcher(uc, proxied.ParallelPreferChained(), urls)

	for {
		if bytes, err := fetcher.fetch(); err != nil {
			log.Errorf("Could not read fetched config %v", err)
		} else if bytes == nil {
			// This is what fetcher returns for not-modified.
			log.Debug("Ignoring not modified response")
		} else if cfg, err := conf.unmarshall(bytes); err != nil {
			log.Errorf("Error fetching config: %v", err)
		} else {
			log.Debugf("Fetched config! %v", cfg)

			// Push these to channels to avoid race conditions that might occur if
			// we did these on go routines, for example.
			configChan <- cfg
			conf.saveChan <- cfg
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
