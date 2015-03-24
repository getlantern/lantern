package yamlconf

import (
	"fmt"
	"os"
	"sync"
	"time"

	"github.com/getlantern/deepcopy"
	"github.com/getlantern/golog"
)

var (
	log = golog.LoggerFor("yamlconf")
)

// Config is the interface for configuration objects that provide the in-memory
// representation of yaml configuration managed by yamlconf.
type Config interface {
	GetVersion() int

	SetVersion(version int)

	ApplyDefaults()
}

// Manager exposes a facility for managing configuration a YAML configuration
// file. After creating a Manager, one must call the Start() method to start the
// necessary background processing.
//
// As the configuration is updated, the updated version of the config is made
// available via the Next() method. Configs are always copied, never updated in
// place.
//
// The config can be updated in several ways:
//
// 1. Programmatically - Clients can call the Manager's Update() method.
// 2. Updating the file on disk directly
// 3. Using the optional HTTP config server
// 4. Optionally specifying a custom polling mechanism (e.g. for fetching updates)
// from a server.
//
// When the file on disk is updated, Manager uses optimistic locking to make
// sure that manual updates to the file don't overwrite intervening programmatic
// updates. Specifically, the Config includes a Version field. Every time that
// a programmatic update is made, the Version field is incremented. If someone
// edits the file and then saves it, but there was an intervening programmatic
// update, the Version in the file will not match the Version in memory, and the
// file will be rejected and overwritten with the latest Version from memory.
//
// Programmatic updates (including ones via the HTTP config server and custom
// polling) are processed serialy. Since these operations are all defined as
// mutators that receive the current version of the config, the order of
// processing doesn't really matter.
//
// The optional HTTP config server provides an HTTP REST endpoint that allows
// making updates to portions of the config. The portion of the config is
// identified by the path. The allowed operations are POST (insert/update) and
// DELETE (delete), both of which expect a YAML fragment in their body.
//
// For example, given a config like this:
//
//   items:
//     a:
//       description: Item A
//       price: 55
//     b:
//       description: Item B
//       price: 23
//
// If applying the following sequence of calls:
//
//   POST /items/a "price: 56"
//   DELETE /items/b
//   POST /items/c "description: Item C\nprice:19"
//
// We would end up with the following configuration:
//
//   items:
//     a:
//       description: Item A
//       price: 56
//     c:
//       description: Item C
//       price: 19
//
//
type Manager struct {
	// FilePath: required, path to the config file on disk
	FilePath string

	// FilePollInterval: how frequently to poll the file for changes, defaults
	// to 1 second
	FilePollInterval time.Duration

	// ConfigServerAddr: optionally, specify an address at which to provide a
	// RESTFUL HTTP server for making config updates.
	ConfigServerAddr string

	// EmptyConfig: required, factor for new empty Configs
	EmptyConfig func() Config

	// OneTimeSetup: optional, provides the ability to perform one-time setup
	// on the configuration at start time (for example applying command-line
	// flags)
	OneTimeSetup func(cfg Config) error

	// CustomPoll: optionally, specify a custom polling function that returns
	// a mutator for applying the result of polling, the time to wait till the
	// next poll, and an error (if polling itself failed). This is useful for
	// example for fetching config updates from a remote server.
	CustomPoll func(currentCfg Config) (mutate func(cfg Config) error, waitTime time.Duration, err error)

	cfg       Config
	cfgMutex  sync.RWMutex
	fileInfo  os.FileInfo
	deltasCh  chan *delta
	nextCfgCh chan Config
}

type mutator func(cfg Config) error

// delta is an operation that changes to the configuration
type delta struct {
	mutate mutator
	errCh  chan error
}

// Next gets the next version of the Config, blocking until the config is
// updated.
func (m *Manager) Next() Config {
	return <-m.nextCfgCh
}

// Update updates the config by using the given mutator function.
func (m *Manager) Update(mutate func(cfg Config) error) error {
	errCh := make(chan error)
	m.deltasCh <- &delta{mutator(mutate), errCh}
	return <-errCh
}

// Start starts the Manager, returning the initial Config (i.e. what was on
// disk). If no config exists on disk, an empty config with ApplyDefaults() will
// be created and saved.
func (m *Manager) Start() (Config, error) {
	if m.EmptyConfig == nil {
		return nil, fmt.Errorf("EmptyConfig must be specified")
	}
	if m.FilePath == "" {
		return nil, fmt.Errorf("FilePath must be specified")
	}
	if m.FilePollInterval == 0 {
		m.FilePollInterval = 1 * time.Second
	}
	m.deltasCh = make(chan *delta)
	m.nextCfgCh = make(chan Config)

	err := m.loadFromDisk()
	if err != nil {
		// Problem reading config, assume that we need to save a new one
		cfg := m.EmptyConfig()
		cfg.ApplyDefaults()
		if m.OneTimeSetup != nil {
			err := m.OneTimeSetup(cfg)
			if err != nil {
				return nil, fmt.Errorf("Unable to perform one-time setup: %s", err)
			}
		}
		_, err = m.saveToDiskAndUpdate(cfg)
		if err != nil {
			return nil, err
		}
	} else {
		// Always save whatever we loaded, which will cause defaults to be
		// applied and formatting to be made consistent
		copied, err := m.copy(m.cfg)
		if m.OneTimeSetup != nil {
			err := m.OneTimeSetup(copied)
			if err != nil {
				return nil, fmt.Errorf("Unable to perform one-time setup: %s", err)
			}
		}
		if err == nil {
			_, err = m.saveToDiskAndUpdate(copied)
		}
		if err != nil {
			return nil, fmt.Errorf("Unable to perform initial update of config on disk: %s", err)
		}
	}

	go m.processUpdates()

	if m.CustomPoll != nil {
		go m.processCustomPolling()
	}

	if m.ConfigServerAddr != "" {
		err = m.startConfigServer()
		if err != nil {
			return nil, err
		}
	}

	return m.getCfg(), nil
}

func (m *Manager) processUpdates() {
	for {
		log.Trace("Waiting for next update")
		changed := false
		select {
		case delta := <-m.deltasCh:
			log.Trace("Apply delta")
			updated, err := m.copy(m.getCfg())
			err = delta.mutate(updated)
			if err != nil {
				delta.errCh <- err
				continue
			}
			changed, err = m.saveToDiskAndUpdate(updated)
			delta.errCh <- err
			if err != nil {
				continue
			}
		case <-time.After(m.FilePollInterval):
			log.Trace("Read update from disk")
			var err error
			changed, err = m.reloadFromDisk()
			if err != nil {
				log.Errorf("Unable to read updated config from disk: %s", err)
				continue
			}
		}

		if changed {
			log.Trace("Publish changed config")
			m.nextCfgCh <- m.cfg
		}
	}
}

func (m *Manager) processCustomPolling() {
	for {
		mutate, waitTime, err := m.CustomPoll(m.getCfg())
		if err != nil {
			log.Errorf("Custom polling failed: %s", err)
		} else {
			err = m.Update(mutate)
			if err != nil {
				log.Errorf("Unable to apply update from custom polling: %s", err)
			}
		}
		time.Sleep(waitTime)
	}
}

func (m *Manager) setCfg(cfg Config) {
	m.cfgMutex.Lock()
	defer m.cfgMutex.Unlock()
	m.cfg = cfg
}

func (m *Manager) getCfg() Config {
	m.cfgMutex.RLock()
	defer m.cfgMutex.RUnlock()
	return m.cfg
}

func (m *Manager) copy(orig Config) (copied Config, err error) {
	copied = m.EmptyConfig()
	err = deepcopy.Copy(copied, orig)
	return
}
