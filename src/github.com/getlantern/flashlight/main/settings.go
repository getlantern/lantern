package main

import (
	"io/ioutil"
	"net/http"
	"path/filepath"
	"sync"

	"github.com/getlantern/appdir"
	"github.com/getlantern/launcher"
	"github.com/getlantern/yaml"

	"github.com/getlantern/flashlight/ui"
)

const (
	messageType = `Settings`
)

var (
	service    *ui.Service
	settings   *Settings
	httpClient *http.Client
	path       = filepath.Join(appdir.General("Lantern"), "settings.yaml")
	once       = &sync.Once{}
)

// Settings is a struct of all settings unique to this particular Lantern instance.
type Settings struct {
	Version      string
	BuildDate    string
	RevisionDate string
	AutoReport   bool
	AutoLaunch   bool
	ProxyAll     bool
	SystemProxy  bool

	sync.RWMutex
}

// Load loads the initial settings at startup, either from disk or using defaults.
func LoadSettings(version, revisionDate, buildDate string) *Settings {
	log.Debug("Loading settings")
	// Create default settings that may or may not be overridden from an existing file
	// on disk.
	settings = &Settings{
		AutoReport:  true,
		AutoLaunch:  true,
		ProxyAll:    false,
		SystemProxy: true,
	}

	// Use settings from disk if they're available.
	if bytes, err := ioutil.ReadFile(path); err != nil {
		log.Debugf("Could not read file %v", err)
	} else if err := yaml.Unmarshal(bytes, settings); err != nil {
		log.Errorf("Could not load yaml %v", err)
		// Just keep going with the original settings not from disk.
	} else {
		log.Debugf("Loaded settings from %v", path)
	}

	if settings.AutoLaunch {
		launcher.CreateLaunchFile(settings.AutoLaunch)
	}
	// always override below 3 attributes as they are not meant to be persisted across versions
	settings.Version = version
	settings.BuildDate = buildDate
	settings.RevisionDate = revisionDate

	// Only configure the UI once. This will typically be the case in the normal
	// application flow, but tests might call Load twice, for example, which we
	// want to allow.
	once.Do(func() {
		err := settings.start()
		if err != nil {
			log.Errorf("Unable to register settings service: %q", err)
			return
		}
		go settings.read()
	})
	return settings
}

type msg struct {
	Settings   *Settings
	RedirectTo string
}

// start the settings service that synchronizes Lantern's configuration with every UI client
func (s *Settings) start() error {
	var err error

	ui.PreferProxiedUI(s.SystemProxy)
	helloFn := func(write func(interface{}) error) error {
		log.Debugf("Sending Lantern settings to new client")
		s.Lock()
		defer s.Unlock()
		return write(&msg{Settings: s})
	}
	service, err = ui.Register(messageType, nil, helloFn)
	return err
}

func (s *Settings) read() {
	log.Debugf("Reading settings messages!!")
	for message := range service.In {
		log.Debugf("Read settings message!! %v", message)
		msg := (message).(map[string]interface{})

		if autoReport, ok := msg["autoReport"].(bool); ok {
			s.SetAutoReport(autoReport)
		} else if proxyAll, ok := msg["proxyAll"].(bool); ok {
			s.SetProxyAll(proxyAll)
		} else if autoLaunch, ok := msg["autoLaunch"].(bool); ok {
			s.SetAutoLaunch(autoLaunch)
		} else if systemProxy, ok := msg["systemProxy"].(bool); ok {
			log.Debugf("Setting system proxy")
			s.SetSystemProxy(systemProxy)
		}
	}
}

// Save saves settings to disk.
func (s *Settings) Save() {
	log.Debug("Saving settings")
	s.Lock()
	defer s.Unlock()
	if bytes, err := yaml.Marshal(s); err != nil {
		log.Errorf("Could not create yaml from settings %v", err)
	} else if err := ioutil.WriteFile(path, bytes, 0644); err != nil {
		log.Errorf("Could not write settings file %v", err)
	} else {
		log.Debugf("Saved settings to %s with contents %v", path, string(bytes))
	}
}

// GetProxyAll returns whether or not to proxy all traffic.
func (s *Settings) GetProxyAll() bool {
	s.RLock()
	defer s.RUnlock()
	return s.ProxyAll
}

// SetProxyAll sets whether or not to proxy all traffic.
func (s *Settings) SetProxyAll(proxyAll bool) {
	s.Lock()
	defer s.Unlock()
	s.ProxyAll = proxyAll
}

// IsAutoReport returns whether or not to auto-report debugging and analytics data.
func (s *Settings) IsAutoReport() bool {
	s.RLock()
	defer s.RUnlock()
	return s.AutoReport
}

// SetAutoReport sets whether or not to auto-report debugging and analytics data.
func (s *Settings) SetAutoReport(auto bool) {
	s.Lock()
	defer s.Unlock()
	s.AutoReport = auto
}

// SetAutoLaunch sets whether or not to auto-launch Lantern on system startup.
func (s *Settings) SetAutoLaunch(auto bool) {
	s.Lock()
	defer s.Unlock()
	s.AutoLaunch = auto
	go launcher.CreateLaunchFile(auto)
}

// GetSystemProxy returns whether or not to set system proxy when lantern starts
func (s *Settings) GetSystemProxy() bool {
	s.RLock()
	defer s.RUnlock()
	return s.SystemProxy
}

// SetSystemProxy sets whether or not to set system proxy when lantern starts
func (s *Settings) SetSystemProxy(enable bool) {
	s.Lock()
	defer s.Unlock()
	changed := enable != s.SystemProxy
	s.SystemProxy = enable
	if changed {
		if enable {
			pacOn()
		} else {
			pacOff()
		}
		preferredUIAddr, addrChanged := ui.PreferProxiedUI(enable)
		if !enable && addrChanged {
			log.Debugf("System proxying disabled, redirect UI to: %v", preferredUIAddr)
			service.Out <- &msg{RedirectTo: preferredUIAddr}
		}
	}
}
