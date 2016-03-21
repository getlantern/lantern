package main

import (
	"fmt"
	"io/ioutil"
	"net/http"
	"path/filepath"
	"strconv"
	"sync"

	"github.com/getlantern/appdir"
	"github.com/getlantern/launcher"
	"github.com/getlantern/yaml"

	"github.com/getlantern/flashlight/ui"
)

const (
	messageType = `settings`
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
	DeviceID  string `json:"deviceID,omitempty"`
	UserID    int    `json:"userID,omitempty"`
	UserToken string `json:"userToken,omitempty"`

	AutoReport  bool `json:"autoReport"`
	AutoLaunch  bool `json:"autoLaunch"`
	ProxyAll    bool `json:"proxyAll"`
	SystemProxy bool `json:"systemProxy"`

	Version      string `json:"version" yaml:"-"`
	BuildDate    string `json:"buildDate" yaml:"-"`
	RevisionDate string `json:"revisionDate" yaml:"-"`

	sync.RWMutex `json:"-" yaml:"-"`
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

// start the settings service that synchronizes Lantern's configuration with every UI client
func (s *Settings) start() error {
	var err error

	ui.PreferProxiedUI(s.SystemProxy)
	helloFn := func(write func(interface{}) error) error {
		log.Debugf("Sending Lantern settings to new client")
		s.Lock()
		defer s.Unlock()
		return write(s)
	}
	service, err = ui.Register(messageType, nil, helloFn)
	return err
}

func (s *Settings) read() {
	log.Debugf("Reading settings messages!!")
	for message := range service.In {
		log.Debugf("Read settings message!! %v", message)

		// We're using a map here because we want to know when the user sends a
		// false value.
		var data map[string]interface{}
		var decoded bool

		if data, decoded = (message).(map[string]interface{}); !decoded {
			continue
		}

		var v, ok bool

		if v, ok = data["autoReport"].(bool); ok {
			s.SetAutoReport(v)
		}

		if v, ok = data["proxyAll"].(bool); ok {
			s.SetProxyAll(v)
		}

		if v, ok = data["autoLaunch"].(bool); ok {
			s.SetAutoLaunch(v)
		}

		if v, ok = data["systemProxy"].(bool); ok {
			s.SetSystemProxy(v)
		}

		if data["userID"] != nil {
			// This is unmarshaled into a float64, I'm am converting it to string and
			// then to float32 to catch the case when this is a float32.
			if id, err := strconv.Atoi(fmt.Sprintf("%v", data["userID"])); err == nil {
				s.SetUserID(id)
			}
		}

		if token, ok := data["token"].(string); ok {
			s.SetToken(token)
		}

		if deviceID, ok := data["deviceID"].(string); ok {
			s.SetDeviceID(deviceID)
		}

		service.Out <- s
	}
}

// Save saves settings to disk.
func (s *Settings) save() {
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
	defer s.unlockAndSave()
	s.ProxyAll = proxyAll
	// Cycle the PAC file so that browser picks up changes
	cyclePAC()
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
	defer s.unlockAndSave()
	s.AutoReport = auto
}

// SetAutoLaunch sets whether or not to auto-launch Lantern on system startup.
func (s *Settings) SetAutoLaunch(auto bool) {
	s.Lock()
	defer s.unlockAndSave()
	s.AutoLaunch = auto
	go launcher.CreateLaunchFile(auto)
}

// GetSystemProxy returns whether or not to set system proxy when lantern starts
func (s *Settings) GetSystemProxy() bool {
	s.RLock()
	defer s.RUnlock()
	return s.SystemProxy
}

// SetDeviceID sets the device ID
func (s *Settings) SetDeviceID(deviceID string) {
	s.Lock()
	defer s.unlockAndSave()
	s.DeviceID = deviceID
}

// SetToken sets the user token
func (s *Settings) SetToken(token string) {
	s.Lock()
	defer s.unlockAndSave()
	s.UserToken = token
}

// GetToken returns the user token
func (s *Settings) GetToken() string {
	s.RLock()
	defer s.RUnlock()
	return s.UserToken
}

// SetUserID sets the user ID
func (s *Settings) SetUserID(id int) {
	s.Lock()
	defer s.unlockAndSave()
	s.UserID = id
}

// GetUserID returns the user ID
func (s *Settings) GetUserID() int {
	s.RLock()
	defer s.RUnlock()
	return s.UserID
}

// SetSystemProxy sets whether or not to set system proxy when lantern starts
func (s *Settings) SetSystemProxy(enable bool) {
	s.Lock()
	defer s.unlockAndSave()
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
			service.Out <- map[string]string{"redirectTo": preferredUIAddr}
		}
	}
}

// unlockAndSave releases the lock on writing to settings and then saves settings.
func (s *Settings) unlockAndSave() {
	// Note locks in go aren't reentrant, so we need to unlock before save locks again.
	s.Unlock()
	s.save()
}
