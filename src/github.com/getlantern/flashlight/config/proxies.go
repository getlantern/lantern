package config

import (
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"time"

	"github.com/getlantern/flashlight/proxied"
	"github.com/getlantern/rot13"
	"github.com/getlantern/tarfs"
	"github.com/getlantern/yaml"
)

// DynamicConfig is an interface for getting proxy data saved locally, embedded
// in the binary, or fetched over the network.
type DynamicConfig interface {
	Saved() (interface{}, error)
	Embedded() (interface{}, error)
	Poll(UserConfig, map[string]interface{}, chan interface{})
}

type config struct {
	filePath         string
	obfuscate        bool
	saveChan         chan interface{}
	remoteFileName   string
	embeddedFileName string
	factory          func() interface{}
}

// NewConfig create a new ProxyConfig instance that saves and looks for
// saved data at the specified path.
func NewConfig(filePath string, obfuscate bool, remoteFileName, embeddedFileName string,
	factory func() interface{}) DynamicConfig {
	pc := &config{
		filePath:         filePath,
		obfuscate:        obfuscate,
		saveChan:         make(chan interface{}),
		remoteFileName:   remoteFileName,
		embeddedFileName: embeddedFileName,
		factory:          factory,
	}

	// Start separate go routine that saves newly fetched proxies to disk.
	go pc.save()
	return pc
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

	return conf.unmarshall(bytes)
}

func (conf *config) Embedded() (interface{}, error) {
	fs, err := tarfs.New(embeddedProxies, "")
	if err != nil {
		log.Errorf("Could not read resources? %v", err)
		return nil, err
	}

	// Get the yaml file from either the local file system or from an
	// embedded resource, but ignore local file system files if they're
	// empty.
	bytes, err := fs.GetIgnoreLocalEmpty(conf.embeddedFileName)
	if err != nil {
		log.Errorf("Could not read embedded proxies %v", err)
		return nil, err
	}

	return conf.unmarshall(bytes)
}

func (conf *config) Poll(uc UserConfig, flags map[string]interface{}, proxyChan chan interface{}) {
	fetcher := newFetcher(uc, proxied.ParallelPreferChained(), flags, conf.remoteFileName)

	for {
		if bytes, err := fetcher.fetch(); err != nil {
			log.Errorf("Could not read fetched config %v", err)
		} else if servers, err := conf.unmarshall(bytes); err != nil {
			log.Errorf("Error fetching config: %v", err)
		} else {
			log.Debugf("Fetched config! %v", servers)

			// Push these to channels to avoid race conditions that might occur if
			// we did these on go routines, for example.
			proxyChan <- servers
			conf.saveChan <- servers
		}
		time.Sleep(1 * time.Minute)
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
