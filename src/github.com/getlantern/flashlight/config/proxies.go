package config

import (
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"time"

	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/proxied"
	"github.com/getlantern/rot13"
	"github.com/getlantern/tarfs"
	"github.com/getlantern/yaml"
)

type proxies map[string]*client.ChainedServerInfo

// ProxyConfig is an interface for getting proxy data saved locally, embedded
// in the binary, or fetched over the network.
type ProxyConfig interface {
	SavedProxies() (proxies, error)
	EmbeddedProxies() (proxies, error)
	Poll(UserConfig, map[string]interface{}, chan map[string]*client.ChainedServerInfo)
}

type proxyConfig struct {
	filePath  string
	obfuscate bool
	saveChan  chan interface{}
}

// NewProxyConfig create a new ProxyConfig instance that saves and looks for
// saved data at the specified path.
func NewProxyConfig(filePath string, obfuscate bool) ProxyConfig {
	pc := &proxyConfig{
		filePath:  filePath,
		obfuscate: obfuscate,
		saveChan:  make(chan interface{}),
	}

	// Start separate go routine that saves newly fetched proxies to disk.
	go pc.save()
	return pc
}

func (pc *proxyConfig) SavedProxies() (proxies, error) {
	infile, err := os.Open(pc.filePath)
	if err != nil {
		return nil, fmt.Errorf("Unable to open config file %v for reading: %v", pc.filePath, err)
	}
	defer infile.Close()

	var in io.Reader = infile
	if pc.obfuscate {
		in = rot13.NewReader(infile)
	}

	bytes, err := ioutil.ReadAll(in)
	if err != nil {
		return nil, fmt.Errorf("Error reading config from %v: %v", pc.filePath, err)
	}

	return pc.unmarshall(bytes)
}

func (pc *proxyConfig) EmbeddedProxies() (proxies, error) {
	fs, err := tarfs.New(embeddedProxies, "")
	if err != nil {
		log.Errorf("Could not read resources? %v", err)
		return nil, err
	}

	// Get the yaml file from either the local file system or from an
	// embedded resource, but ignore local file system files if they're
	// empty.
	bytes, err := fs.GetIgnoreLocalEmpty("proxies.yaml")
	if err != nil {
		log.Errorf("Could not read embedded proxies %v", err)
		return nil, err
	}

	return pc.unmarshall(bytes)
}

func (pc *proxyConfig) Poll(uc UserConfig, flags map[string]interface{}, proxyChan chan map[string]*client.ChainedServerInfo) {
	fetcher := newFetcher(uc, proxied.ParallelPreferChained(), flags, "proxies.yaml.gz")

	for {
		if bytes, err := fetcher.fetch(); err != nil {
			log.Errorf("Could not read fetched proxies %v", err)
		} else if servers, err := pc.unmarshall(bytes); err != nil {
			log.Errorf("Error fetching proxies: %v", err)
		} else {
			log.Debugf("Fetched proxies! %v", servers)

			// Push these to channels to avoid race conditions that might occur if
			// we did these on go routines, for example.
			proxyChan <- servers
			pc.saveChan <- servers
		}
		time.Sleep(1 * time.Minute)
	}
}

func (pc *proxyConfig) unmarshall(bytes []byte) (proxies, error) {
	cfg := make(proxies)
	if err := yaml.Unmarshal(bytes, cfg); err != nil {
		return nil, fmt.Errorf("Error unmarshaling config yaml from %v: %v", string(bytes), err)
	}
	return cfg, nil
}

func (pc *proxyConfig) save() {
	for {
		in := <-pc.saveChan
		if err := pc.saveOne(in); err != nil {
			log.Errorf("Could not save %v, %v", in, err)
		}
	}
}

func (pc *proxyConfig) saveOne(in interface{}) error {
	bytes, err := yaml.Marshal(in)
	if err != nil {
		return fmt.Errorf("Unable to marshal config yaml: %v", err)
	}

	outfile, err := os.OpenFile(pc.filePath, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0644)
	if err != nil {
		return fmt.Errorf("Unable to open file %v for writing: %v", m.FilePath, err)
	}
	defer outfile.Close()

	var out io.Writer = outfile
	if pc.obfuscate {
		out = rot13.NewWriter(outfile)
	}
	_, err = out.Write(bytes)
	if err != nil {
		return fmt.Errorf("Unable to write yaml to file %v: %v", pc.filePath, err)
	}
	log.Debugf("Wrote file at %v", pc.filePath)
	return nil
}
