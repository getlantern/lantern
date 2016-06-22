package app

import (
	"encoding/base64"
	"encoding/json"
	"io/ioutil"
	"net/http"
	"path/filepath"
	"reflect"
	"sync"

	"code.google.com/p/go-uuid/uuid"

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
	httpClient *http.Client
	path       = filepath.Join(appdir.General("Lantern"), "settings.yaml")
	once       = &sync.Once{}
)

// Settings is a struct of all settings unique to this particular Lantern instance.
type Settings struct {
	muNotifiers     sync.RWMutex
	changeNotifiers map[string]func(interface{})

	m map[string]interface{}

	sync.RWMutex `json:"-" yaml:"-"`
}

func loadSettings(version, revisionDate, buildDate string) *Settings {
	return loadSettingsFrom(version, revisionDate, buildDate, path)
}

// loadSettings loads the initial settings at startup, either from disk or using defaults.
func loadSettingsFrom(version, revisionDate, buildDate, path string) *Settings {
	log.Debug("Loading settings")
	// Create default settings that may or may not be overridden from an existing file
	// on disk.
	sett := newSettings()
	set := sett.m

	// Use settings from disk if they're available.
	if bytes, err := ioutil.ReadFile(path); err != nil {
		log.Debugf("Could not read file %v", err)
	} else if err := yaml.Unmarshal(bytes, set); err != nil {
		log.Errorf("Could not load yaml %v", err)
		// Just keep going with the original settings not from disk.
	} else {
		log.Debugf("Loaded settings from %v", path)
	}

	// We always just set the device ID to the MAC address on the system. Note
	// this ignores what's on disk, if anything.
	set["deviceID"] = base64.StdEncoding.EncodeToString(uuid.NodeID())

	if sett.IsAutoLaunch() {
		launcher.CreateLaunchFile(true)
	}
	// always override below 3 attributes as they are not meant to be persisted across versions
	set["version"] = version
	set["buildDate"] = buildDate
	set["revisionDate"] = revisionDate

	// Only configure the UI once. This will typically be the case in the normal
	// application flow, but tests might call Load twice, for example, which we
	// want to allow.
	once.Do(func() {
		err := sett.start()
		if err != nil {
			log.Errorf("Unable to register settings service: %q", err)
			return
		}
		go sett.read(service.In, service.Out)
	})
	return sett
}

func newSettings() *Settings {
	set := make(map[string]interface{})
	var id int64
	set["userID"] = id
	set["autoReport"] = true
	set["autoLaunch"] = true
	set["proxyAll"] = false
	set["systemProxy"] = true
	set["language"] = ""
	return &Settings{
		m:               set,
		changeNotifiers: make(map[string]func(interface{})),
	}
}

// start the settings service that synchronizes Lantern's configuration with every UI client
func (s *Settings) start() error {
	var err error

	ui.PreferProxiedUI(s.GetSystemProxy())
	helloFn := func(write func(interface{}) error) error {
		log.Debugf("Sending Lantern settings to new client")
		s.Lock()
		defer s.Unlock()
		return write(s)
	}
	service, err = ui.Register(messageType, helloFn)
	return err
}

func (s *Settings) read(in <-chan interface{}, out chan<- interface{}) {
	log.Debugf("Start reading settings messages!!")
	for message := range in {
		log.Debugf("Read settings message %v", message)

		// We're using a map here because we want to know when the user sends a
		// false value.
		var data map[string]interface{}
		var decoded bool

		if data, decoded = (message).(map[string]interface{}); !decoded {
			continue
		}

		s.checkBool(data, "autoReport")
		s.checkBool(data, "proxyAll")
		s.checkBool(data, "autoLaunch")
		s.checkBool(data, "systemProxy")
		s.checkString(data, "language")
		s.checkNum(data, "userID")
		s.checkString(data, "userToken")

		out <- s
	}
}

func (s *Settings) checkBool(data map[string]interface{}, name string) {
	v, exist := data[name]
	if !exist {
		return
	}
	b, ok := v.(bool)
	if !ok {
		log.Errorf("Could not convert %v in %v", name, data)
		return
	}
	s.setVal(name, b)
}

func (s *Settings) checkNum(data map[string]interface{}, name string) {
	v, exist := data[name]
	if !exist {
		return
	}
	number, ok := v.(json.Number)
	if !ok {
		log.Errorf("Could not convert %v of type %v", name, reflect.TypeOf(v))
		return
	}
	bigint, err := number.Int64()
	if err != nil {
		log.Errorf("Could not get int64 value for %v with error %v", name, err)
		return
	}
	s.setVal(name, bigint)
}

func (s *Settings) checkString(data map[string]interface{}, name string) {
	v, exist := data[name]
	if !exist {
		return
	}
	str, ok := v.(string)
	if !ok {
		log.Errorf("Could not convert %v in %v", name, data)
		return
	}
	s.setVal(name, str)
}

// Save saves settings to disk.
func (s *Settings) save() {
	log.Trace("Saving settings")
	s.Lock()
	defer s.Unlock()
	if bytes, err := yaml.Marshal(s.m); err != nil {
		log.Errorf("Could not create yaml from settings %v", err)
	} else if err := ioutil.WriteFile(path, bytes, 0644); err != nil {
		log.Errorf("Could not write settings file %v", err)
	} else {
		log.Tracef("Saved settings to %s with contents %v", path, string(bytes))
	}
}

// GetProxyAll returns whether or not to proxy all traffic.
func (s *Settings) GetProxyAll() bool {
	return s.getBool("proxyAll")
}

// SetProxyAll sets whether or not to proxy all traffic.
func (s *Settings) SetProxyAll(proxyAll bool) {
	s.setVal("proxyAll", proxyAll)
	// Cycle the PAC file so that browser picks up changes
	cyclePAC()
}

// IsAutoReport returns whether or not to auto-report debugging and analytics data.
func (s *Settings) IsAutoReport() bool {
	return s.getBool("autoReport")
}

// SetAutoReport sets whether or not to auto-report debugging and analytics data.
func (s *Settings) SetAutoReport(auto bool) {
	s.setVal("autoReport", auto)
}

// SetAutoLaunch sets whether or not to auto-launch Lantern on system startup.
func (s *Settings) SetAutoLaunch(auto bool) {
	s.setVal("autoLaunch", auto)
	go launcher.CreateLaunchFile(auto)
}

// IsAutoLaunch returns whether or not to auto-report debugging and analytics data.
func (s *Settings) IsAutoLaunch() bool {
	return s.getBool("autoLaunch")
}

// SetLanguage sets the user language
func (s *Settings) SetLanguage(language string) {
	s.setVal("language", language)
}

// GetLanguage returns the user language
func (s *Settings) GetLanguage() string {
	return s.getString("language")
}

// SetDeviceID sets the device ID
func (s *Settings) SetDeviceID(deviceID string) {
	// Cannot set the device ID.
}

// GetDeviceID returns the unique ID of this device.
func (s *Settings) GetDeviceID() string {
	return s.getString("deviceID")
}

// SetToken sets the user token
func (s *Settings) SetToken(token string) {
	s.setVal("userToken", token)
}

// GetToken returns the user token
func (s *Settings) GetToken() string {
	return s.getString("userToken")
}

// SetUserID sets the user ID
func (s *Settings) SetUserID(id int64) {
	s.setVal("userID", id)
}

// GetUserID returns the user ID
func (s *Settings) GetUserID() int64 {
	return s.getInt64("userID")
}

// GetSystemProxy returns whether or not to set system proxy when lantern starts
func (s *Settings) GetSystemProxy() bool {
	return s.getBool("systemProxy")
}

// SetSystemProxy sets whether or not to set system proxy when lantern starts
func (s *Settings) SetSystemProxy(enable bool) {
	changed := enable != s.GetSystemProxy()

	s.setVal("systemProxy", enable)
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

func (s *Settings) getBool(name string) bool {
	s.RLock()
	defer s.RUnlock()
	return s.m[name].(bool)
}

func (s *Settings) getString(name string) string {
	s.RLock()
	defer s.RUnlock()
	return s.m[name].(string)
}

func (s *Settings) getInt64(name string) int64 {
	s.RLock()
	defer s.RUnlock()
	return s.m[name].(int64)
}

func (s *Settings) setVal(name string, val interface{}) {
	s.Lock()
	defer s.unlockAndSave()
	log.Debugf("Setting %v to %v in %v", name, val, s.m)
	s.m[name] = val
	s.onChange(name, val)
}

// OnChange sets a callback cb to get called when attr is changed from UI
func (s *Settings) OnChange(attr string, cb func(interface{})) {
	s.muNotifiers.Lock()
	s.changeNotifiers[attr] = cb
	s.muNotifiers.Unlock()
}

// onChange is called when attr is changed from UI
func (s *Settings) onChange(attr string, value interface{}) {
	s.muNotifiers.RLock()
	fn := s.changeNotifiers[attr]
	s.muNotifiers.RUnlock()
	if fn != nil {
		fn(value)
	}
}

// unlockAndSave releases the lock on writing to settings and then saves settings.
func (s *Settings) unlockAndSave() {
	// Note locks in go aren't reentrant, so we need to unlock before save locks again.
	s.Unlock()
	s.save()
}
